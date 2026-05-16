# Chapter 3: Consistent Hashing

> **Chapter goal:** Understand consistent hashing — the ring, virtual nodes, replication — and implement a complete consistent hash ring used internally by distributed caches, KV stores, and load balancers.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

**When does this come up?** Any system that shards data across multiple storage nodes — a distributed cache, a key-value store, a sharded database, or an application-level load balancer — needs a strategy for mapping keys to nodes. Consistent hashing is the default answer in any interview context where the cluster can grow or shrink.

Consistent hashing is the foundational algorithm behind Dynamo, Cassandra, Redis Cluster, and virtually every distributed key-value store built in the last two decades. It solves a deceptively simple problem: how do you assign keys to servers such that adding or removing one server moves as few keys as possible?

First described by Karger et al. at MIT in 1997 ("Consistent Hashing and Random Trees: Distributed Caching Protocols for Relieving Hot Spots on the World Wide Web"), it was developed to efficiently handle content-addressable web caches — a problem that is structurally identical to distributed KV storage. The algorithm is now so ubiquitous that understanding it is a prerequisite for any distributed systems engineering role.

---

## 1. Requirements & Constraints

### 1.1 The Problem with Naive Modulo Hashing

The simplest partition strategy is `server = hash(key) % N`, where N is the number of servers. This works correctly for a fixed cluster but behaves catastrophically when N changes:

- **Add one server (N → N+1):** every key's server assignment changes (since `hash(key) % N` ≠ `hash(key) % (N+1)` for almost all keys). In a 10-server cluster, roughly 10/11 ≈ 91% of all keys must be moved.
- **Remove one server (N → N-1):** similarly, 9/10 = 90% of keys move.

For a cache, every moved key is a cache miss — a thundering herd against the backing store. For a KV store, every moved key requires data migration between nodes. Both scenarios are operationally catastrophic.

**Informal proof:** with N servers and modulo hashing, after adding server N+1, only keys `k` where `hash(k) mod N == hash(k) mod (N+1)` stay on the same server. By the Chinese Remainder Theorem, this fraction is approximately 1/(N+1). So (N/(N+1)) ≈ N/N+1 of all keys move.

A concrete example: a 10-node Memcached cluster uses modulo hashing. A new node is added to handle growing load. Suddenly, 9/10 = 90% of all cached objects are on the "wrong" node. Every request becomes a cache miss. The origin database — already under stress (that's why you added a cache node) — is now slammed by 10× its normal read traffic. This is the outage that motivated consistent hashing in real-world deployments.

### 1.2 Consistent Hashing Promise


Consistent hashing guarantees:

- **Adding 1 server** remaps only N / (total_servers + 1) keys on average.
- **Removing 1 server** remaps only N / total_servers keys on average.

For 1M keys across 10 servers, removing one server moves ~100K keys — not 900K. The remaining 900K keys are undisturbed.

### 1.3 Virtual Nodes

A naive consistent hash ring with 3 physical servers places each server at one point on the ring. The hash function distributes those three points non-uniformly: one server might own 60% of the ring, another 25%, another 15%. This imbalance means unequal load.

**Virtual nodes (VNodes):** each physical server is assigned V positions on the ring instead of one. With V=150, server A has positions `{A-0, A-1, ..., A-149}` distributed around the ring. The law of large numbers ensures that the aggregate arc length owned by each server converges to 1/N as V increases.

| V (virtual nodes) | Std dev of server load |
|---|---|
| 1 | ~40% |
| 10 | ~12% |
| 50 | ~5% |
| 150 | ~3% |

V=150 is the value used by Apache Cassandra in production. The trade-off: the in-memory ring data structure grows to N×V entries. At N=100 servers and V=150, that is 15,000 entries — negligible memory cost.

### 1.4 Scale Context


| Dimension | Example |
|---|---|
| Keys | 1 million |
| Servers | 10 |
| Keys per server (ideal) | 100K |
| Keys moved on 1 node removal | ~100K (10%) |
| VNodes per server | 150 |
| Ring size | 10 × 150 = 1,500 entries |
| Ring lookup cost | O(log(N×V)) = O(log 1,500) ≈ 11 comparisons |

---

## 2. High-Level Architecture

### 2.1 The Ring

The ring is the integer space `[0, 2^32)` (or `[0, 2^64)` for 64-bit hashes) arranged conceptually as a circle where the maximum value wraps back to 0.

```
                              0
                          ┌───┴───┐
              4,294,967,295       1
             /                     \
          A-7                       B-3
         /                           \
      A-2                             C-9
     /                                 \
    C-1           RING                 B-7
     \                                 /
      B-1                           A-5
         \                         /
          C-4                   C-6
             \                 /
              A-0 ─────────B-5
                    2^31
```

Each label `X-N` is a virtual node: physical server X at ring position N.

**Key assignment:** to find the server responsible for a key, compute `hash(key)` to get a ring position, then walk **clockwise** to the first virtual node. That virtual node's physical server owns the key.

**Wrap-around:** if the key's hash is larger than every virtual node on the ring, the key belongs to the virtual node at the minimum ring position (the ring wraps).

**Efficient implementation:** walking clockwise literally (iterating ring positions one by one) is O(N×V) per lookup. The correct implementation uses a sorted data structure — a `BTreeMap` in Rust or a `TreeMap` in Java — where "find the first position ≥ pos" is a single binary search: O(log(N×V)). At N=100, V=150: O(log 15,000) ≈ 14 comparisons.

### 2.2 Adding a Node

When server D joins, it is assigned V virtual node positions distributed around the ring. For each new virtual node position `p`:

- Find the clockwise predecessor of `p` (call it `p_prev`).
- Keys that were previously assigned to `p_prev`'s successor and now fall between `p_prev` and `p` migrate to server D.

Only the keys in those arcs migrate. All other keys are completely undisturbed.

```
Before adding D:          After adding D:
  ...A-7 ... B-3 ...        ...A-7 ... D-2 ... B-3 ...
  Keys in [A-7, B-3)          Keys in [A-7, D-2) stay on A
  owned by server B            Keys in [D-2, B-3) migrate to D
```

### 2.3 Removing a Node

When server E is removed, each of its virtual node positions `p` is deleted. The keys that were assigned to `p` now belong to `p`'s clockwise successor (the next remaining virtual node). Data migration: E's keys flow to the next node, not to all nodes.

### 2.4 Replication

For fault tolerance, each key is stored on R servers (R = replication factor). After finding the primary node via clockwise lookup, walk clockwise R-1 more steps to find the replica nodes. Reads can be served by any replica; writes are acknowledged by a quorum (R/2 + 1 nodes).

```
Key k → primary node P → replica 1 (next clockwise) → replica 2 (next after that)
```

If P fails, replica 1 becomes the new primary — no re-hashing required.

**Quorum reads and writes:** with replication factor R=3, a common configuration is `W=2` (quorum write: 2 of 3 replicas must acknowledge), `R=2` (quorum read: read from 2 of 3 replicas and take the latest version). This gives strong consistency for reads: `W + R > R` guarantees the read set overlaps the write set. Dynamo uses configurable W and R for tunable consistency.

---

## 3. Component Deep-Dive

### 3.1 The Hash Ring

The ring is implemented as a **sorted map** from ring position (integer) to server name. The sorted order enables O(log N) clockwise lookup via binary search: "find the smallest position ≥ key_hash."

**Hash function choice:** the ring requires a deterministic, uniformly distributed hash. Options:

| Hash | Distribution | Speed | Collision safety |
|---|---|---|---|
| SHA-256 (truncated to 32 bits) | Excellent | Moderate | Cryptographic |
| FNV-1a 32-bit | Good | Very fast | Non-cryptographic |
| Murmur3 32-bit | Excellent | Very fast | Non-cryptographic |
| Java `hashCode()` / Rust `DefaultHasher` | Poor (not stable across runs) | Fast | Avoid for rings |

**Critical note:** Rust's `std::collections::hash_map::DefaultHasher` is explicitly not stable across Rust versions or processes — do not use it for a consistent hash ring, which must produce the same positions every time a node restarts. FNV-1a is 5 lines of code and has no such instability.

### 3.2 Virtual Nodes

Without virtual nodes, a 3-server ring has 3 positions. The probability that those 3 positions are clustered is non-trivial — hash functions do not guarantee uniform spacing of a small number of points.

With V=150 virtual nodes, each server contributes 150 independent hash values. The central limit theorem ensures the standard deviation of load per server approaches 1/sqrt(V) × (load per VNode). At V=150, variance is small enough for production use.

**Naming convention for VNode positions:** the position for virtual node `i` of server `s` is `hash(s + "-" + i)`. The format is deterministic: the same server name and index always produce the same ring position, so nodes can be re-added after a restart without confusion.

**Ring size in memory:** with N=100 servers and V=150 VNodes each, the ring has 15,000 entries. Each entry is a (u32, String) pair — approximately 50 bytes — totaling ~750 KB. A `BTreeMap` with 15,000 entries has a height of log2(15,000) ≈ 14 levels; a lookup traverses at most 14 comparisons.

### 3.3 Replication

Walk clockwise N_replicas steps from the primary virtual node. The replication walk must deduplicate physical servers — if server A has many consecutive virtual nodes, the walk might assign all replicas to A. The correct implementation collects distinct physical server names until N_replicas unique servers are found.

This is the standard behavior in Cassandra (token range + rack awareness) and Dynamo (preference list with distinct physical nodes). For the simplified implementation in section 4, we use N=1 (primary only) and note where replication deduplication would be added.

### 3.4 Data Migration on Node Add/Remove

**Node join:**

```
For each virtual node position p assigned to new server D:
    predecessor_pos = largest ring position < p
    successor_pos   = smallest ring position > p (this was previously responsible for the arc)
    migrate keys in (predecessor_pos, p] from successor_server to D
```

In practice, this migration is coordinated by the cluster manager (e.g., Cassandra's gossip protocol, Dynamo's ring state propagation via DynamoDB's control plane). The application layer reads from both the old and new node during migration and resolves conflicts using vector clocks or last-write-wins timestamps.

**Node leave:**

```
For each virtual node position p of departing server E:
    successor = clockwise successor of p
    migrate keys in (predecessor(p), p] to successor_server
```

If E leaves gracefully (planned decommission), migration happens before the node goes offline — no data is lost. If E fails (crash), the replica nodes already hold the data and are promoted.

### 3.5 Real-World Usage

**Amazon Dynamo (2007):** the paper that popularized consistent hashing for KV stores. Uses virtual nodes (called "tokens") plus vector clocks for conflict resolution and "sloppy quorum" for availability during network partitions.

**Apache Cassandra:** uses a token ring where each node owns one or more token ranges. Cassandra uses virtual nodes by default (num_tokens=256 per node in recent versions). Replication is rack-aware: replicas are placed on nodes in different racks/AZs.

**Redis Cluster:** uses a fixed-ring variant with exactly 16,384 hash slots. Each server owns a contiguous range of slots. The mapping is: `slot = CRC16(key) mod 16384`. This is conceptually consistent hashing but with a fixed number of slots rather than a continuous ring. Adding a node means reassigning some slot ranges to it.

### 3.6 Hash Slot Variant (Redis Cluster)

Redis Cluster's 16,384-slot approach trades the flexible ring for operational simplicity:

- **Why 16,384?** Small enough to fit the slot map in a gossip heartbeat (16,384 bits = 2 KB). Large enough that 1,000 nodes each own ~16 slots with room to spare.
- **Slot assignment:** contiguous ranges (e.g., slots 0–5460 on node A, 5461–10922 on node B, 10923–16383 on node C). Range-based assignment makes it easy to see which node owns a slot.
- **Key to slot:** `HASH_SLOT = CRC16(key) mod 16384`. If a key contains a `{tag}`, only the tag is hashed — this allows multi-key operations on the same slot.
- **Adding a node:** move a subset of slot ranges to the new node (Redis CLUSTER SETSLOT + MIGRATE commands). Keys in moved slots are physically transferred. Unlike consistent hashing, you must manually decide which ranges move.

The consistent hash ring (BTreeMap approach) is strictly more general and lower-maintenance than the slot approach, but the slot approach's fixed topology is easier to reason about for small clusters.

**Hash tags for multi-key operations:** Redis requires that all keys in a multi-key command (MSET, MGET, transactions) reside on the same slot. Hash tags (`{tag}`) force related keys to the same slot: `{user:123}:profile` and `{user:123}:sessions` both hash on `user:123`, landing on the same slot. This is a Redis-specific workaround for the atomicity limitation of the slot model; a ring-based store with application-level transactions does not need this.

---

## 4. Key Algorithms

### 4.1 Rust — Consistent Hash Ring with BTreeMap

```rust
// Consistent hash ring using FNV-1a 32-bit hash and BTreeMap
// Compile: rustc --edition 2024 sd03_consistent_hashing.rs
use std::collections::BTreeMap;

struct ConsistentHashRing {
    ring: BTreeMap<u32, String>, // position -> server name
    virtual_nodes: usize,
}

impl ConsistentHashRing {
    fn new(virtual_nodes: usize) -> Self {
        ConsistentHashRing { ring: BTreeMap::new(), virtual_nodes }
    }

    /// FNV-1a 32-bit hash — deterministic, no external crates.
    /// Combines server name and virtual node index to produce a ring position.
    fn hash(s: &str, idx: usize) -> u32 {
        let key = format!("{}-{}", s, idx);
        let mut h: u32 = 2_166_136_261; // FNV offset basis
        for b in key.bytes() {
            h ^= b as u32;
            h = h.wrapping_mul(16_777_619); // FNV prime
        }
        h
    }

    fn add_server(&mut self, server: &str) {
        for i in 0..self.virtual_nodes {
            let pos = Self::hash(server, i);
            self.ring.insert(pos, server.to_string());
        }
    }

    fn remove_server(&mut self, server: &str) {
        for i in 0..self.virtual_nodes {
            let pos = Self::hash(server, i);
            self.ring.remove(&pos);
        }
    }

    /// Clockwise lookup: find the first ring position >= key_hash;
    /// wrap to the minimum position when key_hash exceeds all ring positions.
    fn get_server(&self, key: &str) -> Option<&str> {
        if self.ring.is_empty() {
            return None;
        }
        let pos = Self::hash(key, 0);
        self.ring
            .range(pos..)           // all positions >= pos
            .next()                 // first (smallest) among them
            .or_else(|| self.ring.iter().next()) // wrap-around
            .map(|(_, v)| v.as_str())
    }
}

fn main() {
    let mut ring = ConsistentHashRing::new(10);
    ring.add_server("server-A");
    ring.add_server("server-B");
    ring.add_server("server-C");

    // Test 1: 100 keys distribute across all 3 servers.
    let keys: Vec<String> = (0..100).map(|i| format!("key-{}", i)).collect();
    let mut dist: std::collections::HashMap<&str, usize> = std::collections::HashMap::new();
    for k in &keys {
        let srv = ring.get_server(k).expect("ring must return a server");
        *dist.entry(srv).or_insert(0) += 1;
    }
    if dist.len() != 3 {
        panic!("expected 3 servers in distribution, got {}: {:?}", dist.len(), dist);
    }
    println!("distribution across 3 servers: {:?}", dist);

    // Test 2: adding server-D migrates some keys.
    let before: Vec<(String, String)> = keys
        .iter()
        .map(|k| (k.clone(), ring.get_server(k).unwrap().to_string()))
        .collect();
    ring.add_server("server-D");
    let migrated = before.iter()
        .filter(|(k, old)| ring.get_server(k).unwrap() != old.as_str())
        .count();
    if migrated == 0 {
        panic!("no keys migrated after adding server-D");
    }
    println!("keys migrated after adding server-D: {}", migrated);

    // Test 3: removing server-A redirects its keys to successors.
    ring.add_server("server-A"); // restore 4-server state
    let before2: Vec<(String, String)> = keys
        .iter()
        .map(|k| (k.clone(), ring.get_server(k).unwrap().to_string()))
        .collect();
    let on_a = before2.iter().filter(|(_, s)| s == "server-A").count();
    ring.remove_server("server-A");
    let mut redirected = 0usize;
    for (k, old_srv) in &before2 {
        if old_srv == "server-A" {
            let new_srv = ring.get_server(k.as_str()).unwrap();
            if new_srv == "server-A" {
                panic!("key '{}' still maps to removed server-A", k);
            }
            redirected += 1;
        }
    }
    if redirected != on_a {
        panic!("expected {} redirected keys, got {}", on_a, redirected);
    }
    println!("after removing server-A: {} keys redirected to successors: OK", redirected);
}
```

**Key points:**
- `BTreeMap::range(pos..)` returns an iterator of all entries with key ≥ `pos`, in ascending order. `.next()` gives the first — the clockwise successor. This is O(log N) due to B-tree structure.
- The `.or_else(|| self.ring.iter().next())` handles ring wrap-around: if `pos` is larger than every entry in the ring, `range(pos..)` yields nothing, and we fall back to the minimum entry.
- FNV-1a is deterministic across Rust versions (unlike `DefaultHasher`), making it safe for use in a persistent ring whose positions must match after a process restart.
- `wrapping_mul` prevents integer overflow panic in debug mode — FNV multiplication intentionally overflows as part of the hash mixing.

### 4.2 Java — Consistent Hash Ring with TreeMap

```java
import java.util.*;

public class ConsistentHashRing {
    private final TreeMap<Long, String> ring = new TreeMap<>();
    private final int virtualNodes;

    public ConsistentHashRing(int virtualNodes) {
        this.virtualNodes = virtualNodes;
    }

    /**
     * Polynomial hash with Murmur3-style finalizer for good avalanche effect.
     * Deterministic across JVM runs (no reliance on Object.hashCode()).
     * Returns non-negative long for TreeMap ordering.
     */
    private long hash(String s) {
        long h = 0L;
        for (byte b : s.getBytes()) {
            h = h * 31L + (b & 0xFFL);
        }
        // Murmur3 64-bit finalizer mix
        h ^= (h >>> 33);
        h *= 0xff51afd7ed558ccdL;
        h ^= (h >>> 33);
        h *= 0xc4ceb9fe1a85ec53L;
        h ^= (h >>> 33);
        return h & Long.MAX_VALUE; // ensure non-negative
    }

    public void addServer(String server) {
        for (int i = 0; i < virtualNodes; i++) {
            long pos = hash(server + "-" + i);
            ring.put(pos, server);
        }
    }

    public void removeServer(String server) {
        for (int i = 0; i < virtualNodes; i++) {
            long pos = hash(server + "-" + i);
            ring.remove(pos);
        }
    }

    /**
     * Clockwise lookup using TreeMap.ceilingEntry().
     * Falls back to firstEntry() for ring wrap-around.
     * Returns null if ring is empty.
     */
    public String getServer(String key) {
        if (ring.isEmpty()) return null;
        long pos = hash(key);
        Map.Entry<Long, String> entry = ring.ceilingEntry(pos);
        if (entry == null) entry = ring.firstEntry(); // wrap around
        return entry.getValue();
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        ConsistentHashRing ring = new ConsistentHashRing(10);
        ring.addServer("server-A");
        ring.addServer("server-B");
        ring.addServer("server-C");

        // Test 1: 100 keys distribute across all 3 servers.
        List<String> keys = new ArrayList<>();
        for (int i = 0; i < 100; i++) keys.add("key-" + i);

        Map<String, Integer> dist = new HashMap<>();
        for (String k : keys) {
            String srv = ring.getServer(k);
            dist.merge(srv, 1, Integer::sum);
        }
        check(dist.size() == 3,
            "Expected 3 servers in distribution, got " + dist.size() + ": " + dist);
        System.out.println("distribution across 3 servers: " + dist);

        // Test 2: adding server-D migrates some keys.
        Map<String, String> before = new HashMap<>();
        for (String k : keys) before.put(k, ring.getServer(k));
        ring.addServer("server-D");
        int migrated = 0;
        for (String k : keys) {
            if (!ring.getServer(k).equals(before.get(k))) migrated++;
        }
        check(migrated > 0, "No keys migrated after adding server-D");
        System.out.println("keys migrated after adding server-D: " + migrated);

        // Test 3: removing server-A redirects its keys to successors.
        ring.addServer("server-A"); // restore 4-server state
        Map<String, String> before2 = new HashMap<>();
        for (String k : keys) before2.put(k, ring.getServer(k));
        long onA = before2.values().stream().filter("server-A"::equals).count();
        ring.removeServer("server-A");
        int redirected = 0;
        for (String k : keys) {
            if ("server-A".equals(before2.get(k))) {
                String newSrv = ring.getServer(k);
                check(!"server-A".equals(newSrv),
                    "Key '" + k + "' still maps to removed server-A");
                redirected++;
            }
        }
        check(redirected == (int) onA,
            "Expected " + onA + " redirected keys, got " + redirected);
        System.out.println("after removing server-A: " + redirected
            + " keys redirected to successors: OK");
    }
}
```

**Key points:**
- `TreeMap.ceilingEntry(pos)` returns the entry with the smallest key ≥ `pos` — the Java equivalent of Rust's `BTreeMap::range(pos..).next()`. Both are O(log N).
- The hash function uses a polynomial accumulation followed by Murmur3 finalizer mixing. The finalizer's three XOR-shift-multiply rounds ensure that nearby strings produce well-separated positions — critical for the ring's load balance.
- `h & Long.MAX_VALUE` masks the sign bit, ensuring all positions are non-negative longs. This avoids surprising behavior in `TreeMap` ordering (Java's `long` comparison is signed).
- `dist.merge(srv, 1, Integer::sum)` is the idiomatic Java 8+ way to count occurrences — equivalent to Rust's `*dist.entry(srv).or_insert(0) += 1`.

---

## 5. Tradeoffs

### 5.1 Partitioning Strategy Comparison

| Strategy | Data moved on resize | Load balance | Hotspot risk | Implementation complexity |
|---|---|---|---|---|
| **Consistent hashing (ring)** | ~1/N fraction of keys | Good with VNodes | Low | Medium |
| **Modulo hashing** (hash % N) | Nearly all keys | Perfect (by design) | Low | Very low |
| **Range-based** (sorted key ranges) | Only affected range | Uneven if data skewed | High (sequential keys cluster) | Medium |
| **Hash slots** (Redis, 16384 fixed) | Moved slot range only | Good | Low | Low (fixed topology) |

Consistent hashing wins when the cluster size changes frequently. Modulo hashing wins when the cluster is static and all keys are equivalent. Range-based partitioning wins when range scans are required (e.g., SQL databases — Spanner uses range-based sharding).

### 5.2 Choosing V (Virtual Node Count)

The choice of V is a trade-off between:

- **Higher V → better load balance** (standard deviation of ring arc length per server decreases as O(1/√V)).
- **Higher V → larger ring data structure** (N × V entries in the BTreeMap/TreeMap).
- **Higher V → slower node add/remove** (must insert/delete V entries per operation; at V=150 and N=100 servers, a remove deletes 150 entries from a 15,000-entry tree).

V=150 (Cassandra's default) is the established production sweet spot. V=10 (used in this chapter's snippets) is sufficient for demonstration but would show 12% load standard deviation in production.

**When to increase V:** if you operate a heterogeneous cluster where some nodes have 2× the RAM/CPU of others, assign them 2V virtual nodes instead of V. This proportionally increases their arc length on the ring, giving them ~2× the key share. Consistent hashing with heterogeneous VNode counts is a clean way to handle mixed-hardware clusters without code changes to the routing layer.

### 5.3 SHA-256 vs FNV for Ring Positions

| Property | SHA-256 (truncated 32-bit) | FNV-1a 32-bit |
|---|---|---|
| Distribution quality | Excellent (cryptographic) | Good |
| Speed | ~100 MB/s (software) | ~1 GB/s |
| Code size | Large (requires crypto lib or 200+ lines) | 5 lines |
| Stability across implementations | Yes (standardized) | Yes (fixed constants) |
| Attack resistance | High | None |

For a consistent hash ring there is no security requirement on the hash — only uniformity and determinism. FNV-1a is the pragmatic choice: fast, simple, and sufficient.

### 5.4 Jump Consistent Hashing (Google, 2014)

Lamping and Veach (Google, 2014) published "A Fast, Minimal Memory, Consistent Hash Algorithm" — often called Jump Consistent Hash:

```python
def jump_hash(key: int, num_buckets: int) -> int:
    b, j = -1, 0
    while j < num_buckets:
        b = j
        key = key * 2862933555777941757 + 1
        j = int((b + 1) * (1 << 31) / ((key >> 33) + 1))
    return b
```

- **O(log N) time, O(1) space** — the entire ring is implicit; no data structure is needed.
- **Perfect balance** — each bucket receives exactly 1/N of keys (deterministic, not probabilistic).
- **Limitation:** only supports adding buckets at the end; arbitrary removal is not supported. This makes it suitable for stateless load balancing (a client can always look up the current number of buckets) but not for KV stores where nodes leave in arbitrary order.

The ring-based approach in this chapter (BTreeMap/TreeMap) supports arbitrary add/remove — the operationally correct choice for distributed storage.

---

## 6. Failure Modes

### 6.1 Node Join Storm

**Risk:** A large cluster bootstraps or recovers from a partition — many nodes join simultaneously. Each join triggers a data migration of 1/N keys. With 100 nodes joining at once, migration traffic can saturate the network.

**Mitigation:**

- **Staggered joins:** the cluster manager (Cassandra's bootstrapping, Dynamo's ring state machine) adds nodes one at a time, waiting for migration to complete before the next join.
- **Throttled streaming:** migration is rate-limited (Cassandra's `stream_throughput_outbound_megabits_per_sec`). During heavy streaming, read traffic is served from the old replica; consistency drops to eventual.
- **Bootstrap token assignment:** new nodes are assigned token positions that minimize migration. Cassandra's `num_tokens` allocator tries to pick positions that equalize load while minimizing movement.

### 6.2 VNode Imbalance (Hash Clustering)

**Risk:** For a small cluster with a poor hash function, the V hash values for one server cluster in one region of the ring. This server then owns a disproportionate arc length regardless of V.

**Example:** with a bad hash and V=3, server A's positions might be {1000, 1001, 1002} — all adjacent. It effectively owns one arc rather than three small ones.

**Mitigation:**

- Use a high-quality hash function (FNV-1a, Murmur3) that avalanches — small input differences produce large output differences.
- **Deterministic token placement (Cassandra 3.0+):** rather than random VNode positions, Cassandra uses an algorithm that explicitly places tokens to equalize arc lengths. This provides perfect balance regardless of hash quality.
- For temporary imbalance: monitor per-node key count or storage usage and rebalance by moving individual VNode tokens to less-loaded regions.

### 6.3 Hot Key

**Risk:** A single key receives far more traffic than the ring distributes (e.g., a viral social media post, a high-traffic product SKU). The ring assigns it to one server; that server saturates while others are idle.

**Mitigation:**

The consistent hash ring routes based on key identity — it cannot solve single-key hotspots. Solutions operate above the ring:

- **Application-level caching:** cache the hot key's value in a local in-process cache (e.g., a `HashMap` with a small fixed capacity). The ring is bypassed for the cached value entirely.
- **Read replicas:** write to the primary node; fan out reads across multiple replicas. Works for immutable or infrequently updated keys.
- **Key sharding:** append a random suffix to the key (`key#0`, `key#1`, ..., `key#R`). Distribute reads uniformly across R virtual keys, merge results at read time. Used by DynamoDB for hot partition mitigation.
- **Detect and alert:** instrument per-key request rates and alert when any key exceeds a threshold (e.g., 10× the average). This gives the operator time to apply mitigation before the node fails.

**The fundamental insight:** the consistent hash ring solves the *routing* problem (which node owns this key) but not the *load* problem (what if one key is disproportionately popular). These are orthogonal concerns. The ring gives you N-way distribution for N distinct keys; for a single key that is hotter than N nodes combined, no routing algorithm helps — caching above the ring is the only solution.

---

## 7. Java vs Rust

| Aspect | Java | Rust |
|---|---|---|
| **Sorted map** | `TreeMap<Long, String>` | `BTreeMap<u32, String>` |
| **Clockwise lookup** | `ceilingEntry(pos)` — returns `Map.Entry` or null | `range(pos..).next()` — returns `Option<(&u32, &String)>` |
| **Wrap-around** | `if (entry == null) entry = ring.firstEntry()` | `.or_else(\|\| ring.iter().next())` — null cannot compile |
| **Key type** | `Long` (boxed) — TreeMap requires object keys | `u32` (unboxed) — BTreeMap stores primitives inline |
| **Null safety** | `getServer()` returns `null` for empty ring; caller must check | Returns `Option<&str>`; calling code cannot ignore a None |
| **Server name** | `String` (heap-allocated always) | `String` (owned heap) or `&str` (borrowed slice, zero-copy) |
| **Hash stability** | `String.hashCode()` is stable per JLS, but never use it for rings — returns `int`, poor distribution | `DefaultHasher` is not stable; always use explicit FNV or similar |
| **Insertion** | `ring.put(pos, server)` — O(log N), boxed key | `ring.insert(pos, server.to_string())` — O(log N), unboxed key |

**The O(log N) lookup equivalence** is worth noting: both `TreeMap.ceilingEntry()` and `BTreeMap::range().next()` achieve the clockwise lookup in O(log(N×V)) time. For a 15,000-entry ring, that is ~14 comparisons — negligible even at millions of lookups per second.

**The null vs Option difference** is the most consequential for correctness. In the Java implementation, `getServer()` returns `null` for an empty ring. Every call site in production code must check for null — and if one site forgets, a `NullPointerException` surfaces under the rare condition of an empty ring during cluster maintenance. Rust's `Option<&str>` makes that check mandatory at the call site.

**Ownership and the ring data structure:** in Rust, the ring's `BTreeMap<u32, String>` owns the server name strings. The `get_server()` method returns `Option<&str>` — a borrowed reference into the BTreeMap's storage. This zero-copy return is only possible because Rust's lifetime system guarantees the returned reference does not outlive the ring. Java always returns a `String` reference (which may be the same interned object, but the caller cannot know that).

**Performance implications:** Java's `TreeMap` uses `Long` (boxed) keys, adding indirection and GC pressure for every insert and lookup. For a small ring (< 15,000 entries) this is imperceptible, but at very high lookup rates (millions/sec in a proxy tier), Rust's `BTreeMap<u32, String>` avoids one heap allocation per lookup. In practice, the ring lookup cost is dominated by the B-tree traversal (10-15 comparisons), not the key boxing — so the practical difference is negligible except at extreme scale.

---

## Summary

The table below summarises every design decision covered in this chapter.

| Design decision | Choice | Rationale |
|---|---|---|
| Ring representation | BTreeMap / TreeMap (sorted map) | O(log N) clockwise lookup via range query |
| Virtual nodes (V) | 150 per server (production); 10 in this chapter | Balances load distribution vs. memory/ops cost |
| Hash function | FNV-1a (Rust) / Murmur3 finalizer (Java) | Fast, deterministic, good avalanche — no stdlib instability |
| Wrap-around | First entry fallback | Closes the ring at position 2^32 |
| Replication | Walk clockwise N-1 steps, deduplicate physical nodes | Fault tolerance without re-hashing |
| Node join | Staggered, throttled streaming | Prevents network saturation during scale-out |
| Hot key mitigation | Application-level cache above the ring | Ring-level routing cannot solve single-key traffic spikes |
| Redis variant | 16,384 fixed hash slots (CRC16 mod 16384) | Operationally simpler for small clusters with manual control |
| Heterogeneous nodes | Assign proportional VNode count | Larger nodes get more arc length; no routing code changes required |
| Jump consistent hash | O(1) space, O(log N) time | Best for static or append-only cluster topologies |
