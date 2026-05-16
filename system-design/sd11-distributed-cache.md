# Chapter 11: Distributed Cache (Redis / Memcached)

> **Chapter goal:** Design a distributed caching layer — cache eviction policies, consistency strategies, cache stampede prevention, and Redis Cluster internals — handling 1M read QPS with < 1ms p99 latency.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A distributed cache sits between the application tier and the database, absorbing repetitive reads that would otherwise saturate database connections and add hundreds of milliseconds of latency per request. The cache is explicitly not the source of truth — data loss on a cache node failure is acceptable because the database is authoritative.

The system must satisfy the following functional requirements:

- **Get / Set / Delete with TTL** — arbitrary key-value pairs with per-key time-to-live expiry. TTLs range from seconds (session tokens) to days (user profile data).
- **Cache-aside and write-through patterns** — support both: (a) the application manages cache population on miss (cache-aside), and (b) writes update the cache and the database atomically (write-through).
- **Eviction policies** — when memory is full, evict keys according to a configurable policy: LRU (Least Recently Used), LFU (Least Frequently Used), or TTL-based expiry.
- **Distributed with consistent hashing** — keys are sharded across multiple cache nodes; adding or removing a node minimizes key redistribution.
- **Cache warming** — after a node restart or a new deployment, proactively populate the cache with hot keys from the database before the first user request arrives.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Read latency | < 1 ms p99 |
| Write latency | < 2 ms p99 |
| Read QPS | 1M reads/sec |
| Availability | 99.99% (< 52 min/year) |
| Data durability | Not required; cache miss falls back to DB |
| Hit rate target | > 90% (each cache miss = one DB query) |

### 1.3 Scale Estimates

**Throughput and node sizing:**

```
1M reads/sec ÷ 10 nodes = 100K reads/sec per node
Redis single-threaded event loop: ~200K ops/sec per core
→ Each node handles 100K reads/sec comfortably at ~50% utilization
```

**Memory sizing:**

```
32 GB RAM per node × 10 nodes = 320 GB total
Average value size: 1 KB
Maximum cached entries: 320 GB ÷ 1 KB = ~320M entries
At 90% hit rate: 90% of reads served from cache → 10% × 1M = 100K DB reads/sec
100K DB reads/sec requires a database fleet sized for that write + read load
```

**Key space:**

```
Assume 50M active users × 5 cached objects/user = 250M hot keys
At 1 KB average value + ~100 bytes key/metadata overhead = 1.1 KB/entry
250M entries × 1.1 KB ≈ 275 GB → fits within 320 GB with 15% headroom
```

**Latency budget breakdown for a cache hit at p99:**

```
Application → TCP stack (loopback or LAN)           ~10 µs
Cache client: hash key, select node, connection pool   ~5 µs
Redis server: single-threaded event loop, GET command ~50 µs
Wire serialization + response deserialize            ~20 µs
Cache client → application layer                      ~5 µs
Total (optimistic LAN):                             ~90 µs
Total (cross-AZ, 0.5 ms RTT):                      ~600 µs

P99 target: < 1 ms = 1,000 µs → both scenarios fit with headroom.
```

The L1 in-process cache eliminates the network hop entirely for hot keys, bringing latency to < 1 µs (L1 cache lookup is a hash table access in process memory). The 1 ms p99 budget applies to the L2 Redis tier — the L1 tier is typically an order of magnitude faster.

**Connection pool sizing:**

```
1M QPS ÷ 10 app nodes = 100K QPS per app node
Each Redis command: ~100 µs round trip
100K commands/sec × 100 µs = 10 connections at 100% utilization
Safety factor: 5× → 50 connections per app node per Redis primary
10 app nodes × 50 conns × 3 primaries = 1,500 total connections
Redis max connections default: 10,000 → well within limits
```

---

## 2. High-Level Architecture

```
   Application Servers (stateless, horizontally scaled)
   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │  App A   │   │  App B   │   │  App C   │
   └────┬─────┘   └────┬─────┘   └────┬─────┘
        │               │               │
        └───────────────┴───────────────┘
                        │
             ┌──────────▼──────────────────┐
             │   Cache Client Library       │
             │  · Consistent hashing        │
             │  · Connection pool (50/node) │
             │  · Local L1 (Caffeine/moka)  │
             └──────────┬──────────────────┘
                        │
   ┌────────────────────▼────────────────────────────┐
   │               Redis Cluster (6 nodes)            │
   │                                                  │
   │   Primary-1          Primary-2         Primary-3 │
   │  [slots 0-5460]  [slots 5461-10922] [10923-16383]│
   │       │                  │                  │    │
   │  Replica-1          Replica-2          Replica-3 │
   └──────────────────────────────────────────────────┘

   Write Path:
   ┌──────────┐    ┌───────────┐    ┌───────────┐
   │ App Write│───►│  Database │───►│ Invalidate│
   └──────────┘    └───────────┘    │   Cache   │
                                    └───────────┘

   Monitoring:
   Cache metrics → Prometheus → Grafana
   (hit rate, eviction rate, memory usage, latency histograms)
```

The Cache Client library is embedded in each application server. It uses consistent hashing to deterministically map a key to a Redis primary node without a proxy hop. Each node in the cluster maintains a connection pool of ~50 persistent connections to each Redis primary; connection pool reuse eliminates TCP handshake overhead and is critical for achieving sub-millisecond p99 latency.

A lightweight L1 cache (Caffeine in Java, `moka` in Rust) in each application process holds the hottest keys in process memory. A read served from L1 completes in ~100 nanoseconds rather than ~500 microseconds for a Redis round trip. L1 is bounded (e.g., 1,000 entries, 1-second TTL) to prevent stale data from accumulating.

**Read path (cache-aside with L1 + L2):**

```
1. Check L1 (in-process Caffeine/moka) → hit → return value (~100 ns)
2. Check L2 (Redis Cluster via consistent hash) → hit → populate L1 → return (~500 µs)
3. DB fallback → populate L2 (SET key value EX ttl) → populate L1 → return (~5 ms)
```

**Write path (cache-aside — delete on write):**

```
1. Write to database (primary)
2. DELETE key from Redis (not update — avoids stale-write races)
3. Invalidate L1 entry (or let it expire via short TTL)
```

The write path intentionally does not set the new value in the cache — it deletes the key and lets the next read re-populate it from the database. This eliminates the race condition where two concurrent writes each attempt to SET the cache and one writes a stale value after the other has already committed a newer value. The delete-on-write pattern is safe because the database is always the authoritative source.

**Consistent hashing ring:** The client library maintains a hash ring with virtual nodes (150 virtual nodes per physical node by default). When a Redis node is added or removed, only ~1/N of the keys need to be remapped (where N is the number of physical nodes), minimizing the cold-miss burst during cluster rebalancing. The ring is stored in the client's memory and refreshed from a configuration service every 30 seconds.

---

## 3. Component Deep-Dive

### 3.1 LRU vs LFU Eviction

When memory is full, the cache must decide which key to evict. The two dominant policies reflect different assumptions about access patterns.

**LRU (Least Recently Used)** evicts the key that was accessed furthest in the past. This is optimal for workloads with temporal locality — recently accessed data is likely to be accessed again soon. LRU is the default Redis eviction policy (`allkeys-lru`). Its weakness is scan resistance: a full table scan of the cache (e.g., a batch job reading every user's profile) pushes every key to the front of the LRU queue, evicting genuinely hot data in favor of keys touched exactly once by the scan.

**LFU (Least Frequently Used)** evicts the key accessed least often over a time window. It handles scan workloads better — scan keys have low frequency and are evicted quickly. Redis 4.0+ implements an approximated LFU using a Morris counter (a probabilistic frequency counter stored in 8 bits per key), making it memory-efficient. The tradeoff: frequency counters are decayed over time to allow infrequently accessed keys whose access pattern has changed to become eviction candidates; tuning the decay factor requires traffic analysis.

**Practical guideline:** use LRU for transactional workloads with recency bias (social feeds, session caches), use LFU for content caches with a well-defined hot set (product catalog, media metadata) where a minority of items receive the overwhelming majority of reads.

**Redis eviction policy cheat-sheet:**

| Policy | Applies to | Behavior |
|---|---|---|
| `noeviction` | All keys | Returns OOM error; never evicts |
| `allkeys-lru` | All keys | Evict LRU key (recommended default) |
| `allkeys-lfu` | All keys | Evict LFU key |
| `volatile-lru` | Keys with TTL | Evict LRU among TTL-keyed entries only |
| `volatile-lfu` | Keys with TTL | Evict LFU among TTL-keyed entries only |
| `volatile-ttl` | Keys with TTL | Evict key with shortest remaining TTL |
| `allkeys-random` | All keys | Evict random key |

The `volatile-*` policies are useful when only a subset of keys have TTLs and the remaining keys must never be evicted (e.g., configuration values stored permanently alongside cached transient data). The `allkeys-lru` policy is the safest general-purpose choice because it never returns an error — it always finds something to evict.

### 3.2 Cache Consistency Strategies

The relationship between the cache and the database is the most important architectural decision, and it is governed by whether reads or writes dominate and how much staleness is acceptable.

| Strategy | Write path | Read path | Consistency | Data loss risk | Complexity |
|---|---|---|---|---|---|
| Cache-aside (lazy) | Write DB, delete cache key | Read cache; on miss, read DB then set cache | Eventual | None (DB is always up-to-date) | Low |
| Write-through | Write cache then DB (sync) | Read cache; guaranteed hit after first write | Strong | None | Medium |
| Write-behind (write-back) | Write cache; async flush to DB | Read cache | Weak | Cache failure = data loss | High |
| Read-through | Read cache; cache fetches DB on miss | Transparent to app | Eventual | None | Medium |

**Cache-aside** is the most common pattern. The application reads from the cache; on a miss, it reads from the database and populates the cache. On a write, it updates the database and **deletes** (not updates) the cache key. Deleting on write is safer than updating because an in-flight read might race with the delete-and-set sequence and write a stale value back into the cache. Deletion avoids that race: the next read will re-populate the cache from the freshly written database row.

**Write-through** adds latency to writes (both cache and DB must confirm) but ensures the cache is always warm. It is well-suited for read-heavy data that changes infrequently (user profile, product catalog).

**Write-behind** maximizes write throughput at the cost of durability — a cache node failure before the async flush loses buffered writes. It is appropriate only for non-critical counts (view counters, "likes") where approximate values are acceptable.

**Consistency pitfall — the "double write" race:** In cache-aside with delete-on-write, there is a narrow race window:

```
Thread A (read):  cache miss → read DB (old value) → [Thread B writes, deletes cache] → SET cache (stale old value)
```

This race can leave a stale value in cache for up to TTL seconds. To close the window, use a short TTL (e.g., 60 seconds) for frequently updated data, or implement a version counter: store `(value, version)` in the cache and only SET if `version > current_cached_version`. The version is obtained from the database row's updated timestamp or a monotonic counter column.

### 3.3 Cache Stampede (Thundering Herd) Prevention

A cache stampede occurs when a highly popular key expires simultaneously and thousands of application servers all detect the miss and race to fetch the data from the database. If the key was cached because the underlying DB query is expensive (e.g., a complex aggregation taking 500ms), thousands of concurrent 500ms DB queries arrive at once, overwhelming the database.

Four mitigation strategies, from simplest to most sophisticated:

1. **Mutex lock (cache locking):** When the cache miss is detected, the first request acquires a Redis lock (`SET lock:key "" EX 5 NX`). Subsequent requests that miss on the same key see the lock and either wait briefly or return a stale value. The lock holder fetches from DB, repopulates the cache, and releases the lock.

2. **Probabilistic Early Expiration (PER):** Before the TTL expires, with a small probability (proportional to how close the key is to expiry), pre-emptively refresh the cache. The probability formula is `exp(-(remaining_ttl / beta) * random())`. This amortizes the refresh cost over a window before expiry rather than concentrating it at the exact expiry moment.

3. **Background refresh:** Cache entries are served past their TTL for a grace period while a background task asynchronously refreshes the value. The application always gets a value (possibly stale for a few seconds) and never experiences the miss-induced latency spike.

4. **Jitter in TTL:** Set TTL to `base_ttl + random(0, jitter_range)`. This spreads expiries of concurrently cached keys over a time window, reducing the probability that many popular keys expire simultaneously.

In production, strategies 3 and 4 are combined: serve stale-while-revalidate for hot keys, and apply TTL jitter to batch-loaded keys from campaign cache warming.

**Measuring stampede impact:** Monitor the ratio of cache miss rate to DB query rate. Under normal operation the ratio should be 1:1 (every miss triggers exactly one DB query). A stampede shows up as a miss rate spike where the DB query rate is 100× the miss rate — every miss is triggering hundreds of concurrent DB reads for the same key. Set an alert on `db_queries / cache_misses > 5` over a 30-second window as an early stampede indicator.

### 3.4 Redis Cluster Internals

Redis Cluster distributes data using a fixed hash space of 16,384 slots. Every key is assigned to a slot by `CRC16(key) % 16384`. Slots are partitioned across primary nodes — with 3 primaries, each holds approximately 5,461 slots.

Key operational properties:

- **Cross-slot operations are forbidden.** `MGET key1 key2` fails if `key1` and `key2` hash to different slots. The solution is hash tags: `{user:42}:profile` and `{user:42}:settings` both hash the `user:42` portion, guaranteeing the same slot. Applications must use hash tags for keys that must be accessed together.
- **Replication is asynchronous.** After a primary writes a key, the replica receives the update asynchronously. In a network partition where a primary fails before replication, the promoted replica may be missing recent writes — a known, accepted tradeoff (strong consistency requires Raft/Paxos at the expense of latency).
- **Automatic failover.** When a primary fails to respond within the cluster timeout (default 10 seconds), the cluster elects a replacement primary from the available replicas via a majority vote. During those 10 seconds, keys on the failed primary return errors.
- **Resharding with MIGRATE.** When adding a new node, the cluster moves slots one key at a time using the `MIGRATE` command. Online resharding (no downtime) is supported but causes brief latency spikes during key migration. Schedule resharding during off-peak hours.

**Slot assignment math:** With 16,384 slots across 3 primaries:

```
Primary-1: slots 0     – 5,460   (5,461 slots)
Primary-2: slots 5,461 – 10,921  (5,461 slots)
Primary-3: slots 10,922– 16,383  (5,462 slots)
```

Adding a 4th primary moves ~4,096 slots from each existing primary (25% of each). With 320M cached entries, moving 25% ≈ 80M keys triggers 80M MIGRATE commands — each completing in microseconds on the Redis side but generating significant network traffic. The resharding job should be rate-limited to ~100K migrations/sec to avoid saturating the inter-node network during a production resize operation.

### 3.5 Hotspot Key Problem

Consistent hashing distributes keys evenly in the average case, but popular keys ("celebrity profile", "trending product") receive orders of magnitude more traffic than average keys. All reads for `user:12345:profile` route to the same Redis primary node, creating a single-node bottleneck regardless of cluster size.

Three complementary mitigations:

1. **L1 in-process cache (Caffeine/moka):** Hot keys are served from process memory on the application server without ever reaching Redis. A 1,000-entry Caffeine cache with a 1-second TTL can absorb 99%+ of reads for a key that receives 100K reads/sec, reducing Redis load to ~100 reads/sec (1 repopulation per second per application pod).

2. **Key suffix sharding:** Store the hot key in `N` sharded copies: `user:{id}:profile:0` through `user:{id}:profile:9`. On read, select a random shard. This spreads reads across 10 different hash slots (potentially 10 different Redis nodes) at the cost of requiring coordinated invalidation (delete all 10 shards on write). Use only when L1 caching is insufficient.

3. **CDN for read-only hot data:** Product images, public profiles, and catalog pages are served from a CDN edge node (Cloudflare, Fastly), bypassing both Redis and the application tier entirely. CDN cache-hit latency is < 10ms globally.

### 3.6 Cache Warming

A cold cache after a restart or a new deployment causes a miss storm: every request falls through to the database until the cache warms up organically. For a system with a 90% target hit rate, a cold start with 1M read QPS means 1M DB reads/sec initially — likely exceeding database capacity.

Three warming strategies:

1. **Eager warming (preload):** Before serving traffic, the cache-warming job reads the top N most-accessed keys from the database (identified from analytics logs) and populates the cache. The service is put in a "warming" state and only starts receiving traffic after hit rate exceeds a threshold (e.g., 80%).

2. **Lazy warming (on-demand):** No pre-population; the cache fills as organic traffic arrives. Acceptable for systems where DB can sustain the cold-start load for the 10–30 minutes the cache takes to warm.

3. **Predictive warming (ML-based):** A model trained on historical traffic patterns predicts which keys will be hot in the next hour and proactively warms them. Used by large-scale systems where the hot key set changes predictably (e.g., product catalog warms before a scheduled sale event).

In practice, eager warming is combined with rate limiting on the warming job to avoid overloading the database during the fill phase — populate at most 10K keys/sec regardless of cache capacity.

### 3.7 Serialization Format

Redis stores values as byte arrays. The application is responsible for serializing objects to bytes on write and deserializing on read. Format choice significantly affects cache memory efficiency and throughput.

| Format | Encoding style | Typical size (1KB object) | Schema evolution | Parse speed |
|---|---|---|---|---|
| JSON | Text | 1,000–1,200 bytes | Easy (additive fields) | Slow (string parsing) |
| MessagePack | Binary JSON | 600–800 bytes | Easy (same schema as JSON) | Fast |
| Protocol Buffers | Binary + schema | 300–500 bytes | Strict (schema file required) | Very fast |
| Compressed JSON | gzip(JSON) | 200–400 bytes | Easy | Slow (decompression overhead) |

For values larger than 1 KB, applying gzip compression before storing in Redis reduces memory usage by 50–70% and reduces network bandwidth between the cache client and Redis. The CPU cost of compression/decompression is typically less than 50 microseconds for 1–10 KB values on modern hardware, well within the 1ms latency budget.

Values larger than 1 MB should not be stored in Redis — they block the single-threaded Redis event loop during serialization. Store large blobs in object storage (Amazon S3, GCS) and cache only the URL or a metadata record in Redis.

---

## 4. Key Algorithms

### 4.1 Rust — LRU Cache with Index-Based Doubly-Linked List

The classic LRU implementation pairs a hash map (O(1) key lookup) with a doubly-linked list (O(1) move-to-front on access, O(1) evict-tail on capacity overflow). Rust prohibits self-referential pointer structures, so the linked list is implemented using array indices into pre-allocated parallel `Vec`s — avoiding unsafe code while retaining full O(1) complexity.

```rust
use std::collections::HashMap;

// LRU Cache: index-based doubly-linked list + HashMap
// Slots 0 = dummy head, 1 = dummy tail, 2..=capacity+1 = data nodes.
struct LRUCache {
    capacity: usize,
    map: HashMap<i32, usize>, // key -> node index
    keys: Vec<i32>,
    vals: Vec<i32>,
    prev: Vec<usize>,
    next: Vec<usize>,
    head: usize, // dummy head (index 0)
    tail: usize, // dummy tail (index 1)
    size: usize,
    free: Vec<usize>, // available slot indices
}

impl LRUCache {
    fn new(capacity: usize) -> Self {
        let total = capacity + 2;
        let mut cache = LRUCache {
            capacity,
            map: HashMap::new(),
            keys: vec![0i32; total],
            vals: vec![0i32; total],
            prev: vec![0usize; total],
            next: vec![0usize; total],
            head: 0,
            tail: 1,
            size: 0,
            free: (2..total).collect(),
        };
        cache.next[0] = 1; // head -> tail
        cache.prev[1] = 0; // tail <- head
        cache
    }

    fn remove_node(&mut self, idx: usize) {
        let p = self.prev[idx];
        let n = self.next[idx];
        self.next[p] = n;
        self.prev[n] = p;
    }

    fn insert_after_head(&mut self, idx: usize) {
        let after = self.next[self.head];
        self.next[self.head] = idx;
        self.prev[idx] = self.head;
        self.next[idx] = after;
        self.prev[after] = idx;
    }

    fn get(&mut self, key: i32) -> i32 {
        if let Some(&idx) = self.map.get(&key) {
            self.remove_node(idx);
            self.insert_after_head(idx);
            self.vals[idx]
        } else {
            -1
        }
    }

    fn put(&mut self, key: i32, value: i32) {
        if let Some(&idx) = self.map.get(&key) {
            self.vals[idx] = value;
            self.remove_node(idx);
            self.insert_after_head(idx);
        } else {
            if self.size == self.capacity {
                let lru_idx = self.prev[self.tail];
                let lru_key = self.keys[lru_idx];
                self.remove_node(lru_idx);
                self.map.remove(&lru_key);
                self.free.push(lru_idx);
                self.size -= 1;
            }
            let idx = self.free.pop().expect("free list has slots");
            self.keys[idx] = key;
            self.vals[idx] = value;
            self.insert_after_head(idx);
            self.map.insert(key, idx);
            self.size += 1;
        }
    }
}

fn main() {
    let mut cache = LRUCache::new(3);
    cache.put(1, 10);
    cache.put(2, 20);
    cache.put(3, 30);
    assert_eq!(cache.get(1), 10); // 1 becomes MRU; order: 1, 3, 2
    cache.put(4, 40);             // evicts LRU = 2
    assert_eq!(cache.get(2), -1); // evicted
    assert_eq!(cache.get(3), 30); // still present
    assert_eq!(cache.get(4), 40); // present

    // Update existing key does not change capacity
    cache.put(3, 300);
    assert_eq!(cache.get(3), 300);

    // Capacity = 1 edge case
    let mut tiny = LRUCache::new(1);
    tiny.put(1, 1);
    tiny.put(2, 2); // evicts 1
    assert_eq!(tiny.get(1), -1);
    assert_eq!(tiny.get(2), 2);

    println!("All assertions passed.");
}
```

**Key design points:**
- Pre-allocating `capacity + 2` slots at construction eliminates runtime allocation during normal operation. Index 0 is the sentinel head; index 1 is the sentinel tail; indices 2 through `capacity+1` are data slots managed via the free list.
- `remove_node` and `insert_after_head` are O(1) pointer-manipulation operations involving only array index writes — no heap allocation, no iteration.
- The free list (`Vec<usize>`) tracks available data slots. On eviction, the freed index is pushed back onto the free list for reuse by the next insert. The free list never grows beyond its initial size of `capacity` entries.
- `HashMap::get` returns an immutable reference; storing the copied `usize` index before calling mutable list operations avoids borrow checker conflicts with the self-referential map.

### 4.2 Java — LRU Cache with LinkedHashMap

Java's standard library provides `LinkedHashMap` with `accessOrder=true`, which maintains entries in access order and provides a `removeEldestEntry` hook invoked after each `put`. This makes an LRU cache a four-line implementation — the entire complexity is encapsulated inside the JDK.

```java
import java.util.*;

public class LRUCache {
    private final int capacity;
    private final LinkedHashMap<Integer, Integer> cache;

    public LRUCache(int capacity) {
        this.capacity = capacity;
        // accessOrder=true: get() moves the accessed entry to the iteration tail (MRU end)
        this.cache = new LinkedHashMap<>(capacity, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<Integer, Integer> eldest) {
                return size() > LRUCache.this.capacity;
            }
        };
    }

    public int get(int key) {
        return cache.getOrDefault(key, -1);
    }

    public void put(int key, int value) {
        cache.put(key, value);
    }

    static void check(boolean cond, String msg) {
        if (!cond) throw new RuntimeException("Assertion failed: " + msg);
    }

    public static void main(String[] args) {
        LRUCache cache = new LRUCache(3);
        cache.put(1, 10);
        cache.put(2, 20);
        cache.put(3, 30);
        check(cache.get(1) == 10, "get(1) returns 10"); // 1 is now MRU
        cache.put(4, 40);                               // evicts LRU = 2
        check(cache.get(2) == -1, "2 is evicted");
        check(cache.get(3) == 30, "3 still present");
        check(cache.get(4) == 40, "4 present");

        cache.put(3, 300);
        check(cache.get(3) == 300, "updated value for key 3");

        // Capacity = 1 edge case
        LRUCache tiny = new LRUCache(1);
        tiny.put(1, 1);
        tiny.put(2, 2); // evicts 1
        check(tiny.get(1) == -1, "key 1 evicted");
        check(tiny.get(2) == 2, "key 2 present");

        System.out.println("All checks passed.");
    }
}
```

**Key design points:**
- `LinkedHashMap(capacity, 0.75f, true)` — the third argument `accessOrder=true` switches iteration order from insertion order to access order. `get()` internally calls `afterNodeAccess()`, moving the entry to the end (most recently used). `removeEldestEntry` is called by `put()` after insertion, and evicts the head entry (least recently used) when size exceeds capacity.
- `removeEldestEntry` references `LRUCache.this.capacity` to access the enclosing instance's field — a standard Java anonymous class pattern.
- **Not thread-safe.** `LinkedHashMap` is single-threaded. In a real cache client, wrap with `Collections.synchronizedMap()` or use `ConcurrentHashMap` with a separate `ConcurrentLinkedDeque` for ordering (at higher implementation cost). Caffeine's `LocalCache` uses a striped lock approach for better concurrency.

### 4.3 Observability and Key Metrics

A cache system without observability is a black box — you discover problems only when the database falls over. The following metrics should be collected per Redis node and per cluster, scraped by Prometheus, and visualized in Grafana.

**Hit rate** is the primary health metric: `hit_rate = keyspace_hits / (keyspace_hits + keyspace_misses)`. A drop from 90% to 80% means the database receives 100% more read load than it did before the change. Alert when hit rate drops more than 5 percentage points in a 5-minute window.

**Eviction rate** (`evicted_keys` counter in `INFO stats`) should be near zero in normal operation. Non-zero evictions indicate the cache is under memory pressure. Alert when the eviction rate exceeds 1% of the hit rate over a 5-minute rolling window.

**Memory utilization** (`used_memory / maxmemory`) should be tracked continuously. Alert at 75% to allow capacity planning time before evictions begin affecting the hit rate.

**Replication lag** (`INFO replication` → `master_repl_offset - slave_repl_offset`) should be near zero. Alert when replica lag exceeds 1 second, which indicates network congestion or a replica that is falling behind under write load.

**Command latency** — Redis exposes per-command latency via `LATENCY HISTORY command`. P99 latency for GET and SET should be < 200 µs on a lightly loaded node; alert at > 500 µs.

**Key distribution** — in a Redis Cluster, monitor per-slot memory usage. An uneven key distribution (one slot holding 10× the average) suggests hotspot keys that need suffix sharding or L1 caching.

```
# Prometheus scrape config for Redis metrics (redis_exporter)
scrape_configs:
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-primary-1:9121', 'redis-primary-2:9121', 'redis-primary-3:9121']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

---

## 5. Tradeoffs

### 5.1 Cache Consistency Strategy Comparison

| Strategy | Consistency | Write latency | Miss rate at cold start | Data loss risk | Implementation complexity |
|---|---|---|---|---|---|
| Cache-aside | Eventual (TTL-bounded) | Low (DB only) | High (fills lazily) | None | Low |
| Write-through | Strong | Higher (DB + cache) | Low (always warm) | None | Medium |
| Write-behind | Weak | Very low (cache only) | Low (always warm) | High (cache failure) | High |
| Read-through | Eventual | Low | Low (cache fetches DB) | None | Medium |

Cache-aside with delete-on-write is the pragmatic default for most applications. Write-through is justified when read performance is critical and write latency is acceptable. Write-behind should be reserved for non-durable, high-write counters where approximate values are acceptable.

### 5.2 Eviction Policy Comparison

| Policy | Scan resistance | Frequency tracking | Implementation | Hit rate for hot/cold data |
|---|---|---|---|---|
| LRU | Poor | None | O(1) doubly-linked list | Good for temporal locality |
| LFU | Good | Yes (decayed) | O(log n) or approximated | Better for stable hot set |
| FIFO | Poor | None | O(1) queue | Poor overall |
| Random | None | None | O(1) | Surprisingly acceptable for uniform access |
| TTL-based | None | None | O(1) lazy or O(log n) heap | Forces freshness, ignores access pattern |

Redis exposes `maxmemory-policy` to select the eviction strategy. The `volatile-*` variants only evict keys with a TTL set; `allkeys-*` variants can evict any key. For a general-purpose cache where all keys should be evictable, `allkeys-lru` or `allkeys-lfu` is appropriate.

### 5.3 Redis vs Memcached

| Dimension | Redis | Memcached |
|---|---|---|
| Data structures | Strings, hashes, lists, sets, sorted sets, streams | Strings only |
| Persistence | RDB snapshots + AOF log (optional) | None |
| Clustering | Built-in Redis Cluster (16K slots) | Client-side sharding only |
| Replication | Primary-replica with automatic failover | None (no native replication) |
| Throughput | ~200K ops/sec single-threaded | ~1M ops/sec multi-threaded |
| Memory efficiency | Slightly higher overhead (data structures) | Lower overhead (flat storage) |
| Use case | Session cache, pub/sub, leaderboards, queues | Pure high-throughput string cache |

Memcached's multi-threaded architecture gives it higher raw get/set throughput for simple string values. However, Redis Cluster provides native horizontal scaling, replication, and persistence — making Redis the default choice for new systems. Memcached's superior raw throughput matters only at extreme scales (> 10M QPS) where Redis Cluster's single-threaded per-shard throughput is the bottleneck.

**When to choose Memcached:** If the workload is purely high-throughput string get/set with no need for data structures, persistence, pub/sub, or replication, Memcached's multi-threaded architecture can serve ~5× more ops/sec per node at the same hardware cost. A CDN edge cache or a token cache that only needs simple set/get/delete at extreme throughput is a legitimate Memcached use case. In the 1M QPS scenario described in this chapter, Redis Cluster (10 nodes × 200K ops/sec/node = 2M ops/sec headroom) is adequate without Memcached.

---

## 6. Failure Modes

### 6.1 Cache Node Failure

When a Redis primary node fails, consistent hashing means only the keys assigned to that node's slots will miss — all other keys continue to hit their respective primaries. Without a replica, those misses fall through to the database for the duration of the outage (minutes to hours if manual intervention is needed).

Redis Cluster with one replica per primary provides automatic failover. When the primary fails to respond, the cluster detects the failure after the `cluster-node-timeout` (default 10 seconds) and promotes the replica. During those 10 seconds, reads to the affected slots return errors. Applications must handle Redis errors gracefully (catch-and-fallback to database, log the event, increment the "cache miss on error" metric). After promotion, the replica takes over all reads and writes for those slots. A new replica should be added immediately to restore redundancy.

**Mitigation:** Set `cluster-node-timeout` to 5 seconds for faster failover. Use `WAIT` command after writes to ensure replication before acknowledging writes when data durability matters. Monitor replica lag as a key metric — replica lag > 1 second before a primary failure increases the window of data loss after promotion.

### 6.2 Memory Exhaustion

When Redis memory approaches `maxmemory`, the eviction policy activates. If the workload contains many keys the policy considers equally evictable (e.g., all keys have been accessed recently in an LRU cache), Redis may evict keys that are actually frequently needed, sharply degrading the hit rate.

A sudden drop in hit rate from 95% to 70% means 300K extra DB reads/sec for a 1M QPS system — potentially cascading into a database overload incident.

**Mitigation:** Alert at 75% memory utilization (not 100%) to allow time to add nodes or increase memory. Set `maxmemory-policy allkeys-lru` rather than `noeviction` — with `noeviction`, Redis returns errors on new writes when memory is full, which is far more disruptive. Monitor the eviction rate metric (`evicted_keys` in `INFO stats`): evictions should be near zero during normal operation.

### 6.3 Cache Penetration

Cache penetration occurs when an attacker (or a misconfigured client) queries keys that do not exist in the cache or the database. Every such request is a guaranteed cache miss, passes through to the database, and returns nothing — performing a full DB read for zero cache value. At 1M QPS, even 1% penetration queries = 10K unnecessary DB reads/sec.

**Mitigation:** (a) Cache null results with a short TTL (e.g., 60 seconds). A key that doesn't exist in the DB is cached as a sentinel null value, so subsequent reads for the same non-existent key are served from the cache. (b) Use a Bloom filter in the cache client: before querying the cache or the DB, check whether the key could exist in the Bloom filter. The filter has zero false negatives (if the key is in the DB, the filter always says "possible") and a small false positive rate (~1%). Queries for keys the filter declares impossible are short-circuited immediately. (c) Rate limit per-key miss counts: if the same key misses 100 times in 10 seconds, block subsequent reads for that key for 60 seconds.

### 6.4 Storing Large Values

Redis processes requests in a single-threaded event loop. Fetching, serializing, or transmitting a 10 MB value blocks all other commands waiting in the queue for the duration of that one large-value operation. At 1M QPS, even a 5ms blockage per large-value request introduces measurable latency spikes across the entire cluster.

**Mitigation:** Enforce a maximum value size in the cache client (e.g., 1 MB). Values larger than the threshold are stored in object storage (Amazon S3, GCS) and the cache stores only the URL or a metadata record. The application fetches the URL from the cache, then fetches the blob from the CDN-fronted object storage — adding one extra hop but avoiding Redis blockage. Alternatively, break large values into chunks: store `key:chunk:0`, `key:chunk:1`, etc., and reassemble client-side. Chunking allows parallel retrieval but adds reassembly complexity.

### 6.5 Split-Brain During Network Partition

In a Redis Cluster, a network partition that isolates a primary from the majority of the cluster can cause a split-brain scenario: the isolated primary continues accepting writes from application servers that can still reach it, while the majority cluster promotes a replica and also accepts writes. When the partition heals, the two diverging write streams must be reconciled — but Redis does not support conflict resolution. The replica-promoted primary's writes win; the isolated primary's writes during the partition are lost.

**Mitigation:** Configure `min-replicas-to-write 1` and `min-replicas-max-lag 10` on each Redis primary. These settings cause the primary to stop accepting writes if it cannot replicate to at least one replica within 10 seconds — effectively causing the isolated primary to self-isolate rather than accepting writes that will be lost. For writes where loss is unacceptable, use the database as the write target (cache-aside) and treat Redis as a best-effort read cache only. This architectural choice — making Redis a pure read cache with the DB as the authoritative write target — eliminates split-brain write loss at the cost of requiring a DB write for every mutation.

---

## 7. Java vs Rust Callout

**Standard library LRU vs manual implementation:** Java's `LinkedHashMap(accessOrder=true)` is a production-grade LRU cache in four lines of constructor code — the doubly-linked list maintenance, access-order bookkeeping, and `removeEldestEntry` eviction hook are all implemented and tested inside the JDK. Rust's `std` provides no equivalent; implementing an LRU cache correctly without `unsafe` requires the index-based trick shown in this chapter (parallel `Vec`s with a free list) or reaching for an external crate (`lru`, `lru-cache`). The Rust implementation is significantly more code for the same logical structure, but it gives complete control over the memory layout.

**`removeEldestEntry` hook vs explicit eviction logic:** Java's hook is invoked automatically inside `LinkedHashMap.put()` after the new entry is added. This is elegant but hidden; a developer reading `cache.put(key, value)` must know to look for the anonymous class override to understand eviction behavior. Rust's `put` method makes eviction explicit — the `if self.size == self.capacity` branch is visible at the call site, making the behavior obvious during code review.

**Memory: boxing vs primitives:** Java's `LinkedHashMap<Integer, Integer>` boxes each key and value into `Integer` objects (16 bytes of heap overhead each) on top of the map entry's own overhead (~48 bytes per entry). For a 1M-entry cache, that is ~80 MB of boxing overhead alone. Rust's `HashMap<i32, usize>` stores keys and values as plain 4-byte and 8-byte integers within the map's contiguous allocation — zero boxing. In a real Java system this is addressed with `Int2IntOpenHashMap` (fastutil) at the cost of adding a library dependency; no such workaround is needed in Rust.

**GC pauses during eviction storms:** When memory is full and the LRU cache evicts aggressively, Java's garbage collector must collect the evicted `Integer` and `Map.Entry` objects. Under sustained high eviction rates (e.g., 100K evictions/sec), minor GC pauses can extend from sub-millisecond to 2–5ms, directly violating the < 1ms p99 target. Rust's ownership system deallocates evicted entries deterministically — dropping an evicted entry is a single stack operation with predictable, bounded latency. For latency-sensitive caches in Java, object pooling or off-heap storage is the mitigation; in Rust, the problem does not arise.

**Concurrency model:** The Rust `LRUCache` takes `&mut self` for both `get` and `put`, enforcing single-owner exclusive access at compile time. In a multi-threaded context this would require wrapping in `Mutex<LRUCache>` — expensive under contention. The `moka` crate (Rust's Caffeine equivalent) uses a concurrent segment-based design that avoids global locking. Java's `LinkedHashMap` is not thread-safe and requires `Collections.synchronizedMap()` for thread safety, but true high-concurrency caches in Java use Caffeine's `Cache<K, V>` with a W-TinyLFU eviction policy and lock-striping for near-lock-free concurrent access.

**Index-based list vs pointer-based list:** The Rust implementation's index-based doubly-linked list (parallel `Vec`s of `usize` indices) is a common pattern in Rust systems code when pointer-based data structures would require `unsafe`. The tradeoff compared to a raw-pointer implementation: (a) cache locality is similar since both approaches allocate nodes in a contiguous region; (b) the index representation is 8 bytes (usize on 64-bit) per pointer field, compared to 8 bytes for a raw pointer — no space penalty; (c) the Vec bounds-checking adds one bounds check per index dereference in debug builds (elided in release builds if the compiler proves the bounds are safe). In production Rust, the `lru` crate on crates.io uses this same index-based technique in a well-tested form.

**Capacity and growth:** Rust's `Vec`-backed implementation pre-allocates all node slots at construction time (`capacity + 2`). This means `put` never allocates new heap memory — it pops from the free list. Java's `LinkedHashMap` allocates a new `Map.Entry` node on the heap for each `put`. Under a steady-state workload where puts and evictions balance, Java's GC continuously collects the evicted entries — creating allocation pressure proportional to the eviction rate. At 100K puts/sec with 100K evictions/sec, the allocation pressure is 100K `Map.Entry` objects/sec (~4.8 MB/sec of short-lived objects). This fits comfortably in Java's young generation GC, but contributes to GC pause frequency. Rust's pre-allocated pool eliminates this allocation/deallocation cycle entirely.

**Summary — choosing the right tool:**
- For a general-purpose L2 cache at 1M QPS: Redis Cluster (allkeys-lru, 10 nodes with replicas) behind a client library with consistent hashing and an L1 Caffeine/moka process cache.
- For an in-process L1 cache in Java: Caffeine's `AsyncLoadingCache` with a W-TinyLFU policy — do not use `LinkedHashMap` in a real production L1 cache; it is not concurrent and uses more memory than necessary.
- For an in-process L1 cache in Rust: the `moka` crate or a custom `Mutex<LRUCache>` with the index-based implementation shown here, depending on whether external dependencies are permitted.
- For the interview whiteboard: the index-based Rust LRU and Java's `LinkedHashMap` LRU both demonstrate full understanding of the data structure. Being able to explain why Rust requires the index trick — and what the Java hook is actually doing inside `LinkedHashMap.put()` — differentiates a candidate who understands the implementation from one who has only memorized the API.
