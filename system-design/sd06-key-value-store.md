# Chapter 6: Distributed Key-Value Store

> **Chapter goal:** Design a distributed KV store (like DynamoDB/Cassandra) combining consistent hashing (Ch 3), CAP tradeoffs (Ch 4), and Raft-based replication (Ch 5) — with LSM-tree storage engine internals.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).
> *Prerequisites: Chapters 3 (Consistent Hashing), 4 (CAP), 5 (Raft)*

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A distributed key-value store is a shared, fault-tolerant map from string keys to string values accessible by any node in a cluster. Clients interact through three primitive operations:

- **put(key, value)** — write or overwrite a key. If the key already exists, the new value replaces the old one.
- **get(key)** — return the current value for a key, or indicate that the key is absent (or deleted).
- **delete(key)** — logically remove a key by writing a *tombstone*; the entry is physically removed during later compaction.

Beyond the core API:

- **TTL support** — keys may carry an expiration timestamp. The store rejects reads of expired keys and removes them during compaction.
- **Range queries (optional)** — because storage is sorted (LSM-tree), efficient scans over lexicographic key ranges are possible; e.g., `scan("user:1000:", "user:2000:")`.
- **String keys and values** — UTF-8 encoded, maximum 256 bytes for keys and 1 MB for values.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Read latency | < 1 ms p99 |
| Write latency | < 5 ms p99 |
| Availability | 99.99% (≤ 52 minutes downtime per year) |
| Durability | No data loss after node failures (WAL + replication) |
| Horizontal scalability | Add nodes without downtime; rebalances automatically |
| Consistency model | Tunable: eventually consistent (AP) or strongly consistent (CP) |

### 1.3 Scale Estimates

| Dimension | Value |
|---|---|
| Write throughput | 10,000 writes/sec |
| Read throughput | 100,000 reads/sec |
| Average value size | 100 bytes |
| Total data | 10 TB |
| Number of nodes | 100 |
| Replication factor | 3 (N = 3) |

**Storage per node:**

With 10 TB total and N = 3 replication, the raw storage is 30 TB across 100 nodes:

```
30 TB / 100 nodes = 300 GB per node
```

At a typical 70% disk utilization target that requires ~430 GB usable storage per node, achievable with commodity NVMe drives.

**Write throughput breakdown:**

10,000 writes/sec with W = 2 quorum requires each write to reach 2 replicas:

```
10,000 writes/sec × 2 replica ACKs = 20,000 inter-node write operations/sec
```

Spread across 100 nodes, each node handles ~200 writes/sec on average — well within a single NVMe disk's sequential write capability (~200,000 IOPS for 4 KB pages).

**MemTable flush cadence:**

If each MemTable holds 32 MB before flushing:

```
10,000 writes/sec × 100 bytes/write = 1 MB/sec cluster-wide
With RF=3 each byte lands on 3 nodes → 3 MB/sec cluster write amplification
Per node (100 nodes): 3 MB/sec ÷ 100 = ~30 KB/sec ingested per node
→ flush every ~1,067 seconds (~18 min) → roughly 3 SSTable files per hour per node
```

---

## 2. High-Level Architecture

```
                         ┌──────────────────────────────────┐
        Client           │       Consistent Hash Ring        │
       ────────          │                                   │
       put/get/    ─────►│  Any node can act as Coordinator  │
       delete            │  Routes by key → top-N clockwise  │
                         └──────────────┬───────────────────┘
                                        │
                    ┌───────────────────┼────────────────────┐
                    │                   │                    │
                    ▼                   ▼                    ▼
           ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
           │   Node A     │   │   Node B     │   │   Node C     │
           │  (Replica 1) │   │  (Replica 2) │   │  (Replica 3) │
           │              │   │              │   │              │
           │  ┌────────┐  │   │  ┌────────┐  │   │  ┌────────┐  │
           │  │MemTable│  │   │  │MemTable│  │   │  │MemTable│  │
           │  └───┬────┘  │   │  └───┬────┘  │   │  └───┬────┘  │
           │      │ flush  │   │      │ flush  │   │      │ flush  │
           │  ┌───▼────┐  │   │  ┌───▼────┐  │   │  ┌───▼────┐  │
           │  │SSTable │  │   │  │SSTable │  │   │  │SSTable │  │
           │  │SSTable │  │   │  │SSTable │  │   │  │SSTable │  │
           │  └────────┘  │   │  └────────┘  │   │  └────────┘  │
           │  ┌────────┐  │   │  ┌────────┐  │   │  ┌────────┐  │
           │  │  WAL   │  │   │  │  WAL   │  │   │  │  WAL   │  │
           │  └────────┘  │   │  └────────┘  │   │  └────────┘  │
           │  ┌────────┐  │   │  ┌────────┐  │   │  ┌────────┐  │
           │  │ Bloom  │  │   │  │ Bloom  │  │   │  │ Bloom  │  │
           │  │ Filter │  │   │  │ Filter │  │   │  │ Filter │  │
           │  └────────┘  │   │  └────────┘  │   │  └────────┘  │
           └──────────────┘   └──────────────┘   └──────────────┘

  Write quorum: coordinator waits for W=2 ACKs from 3 replicas
  Read quorum:  coordinator collects R=2 responses, returns latest version
  R + W = 4 > N = 3  →  strong consistency guaranteed
```

**Write path:**

1. Client sends `put(key, value)` to any node (the coordinator).
2. Coordinator hashes the key, finds the top-3 nodes clockwise on the ring.
3. Coordinator forwards the write to all 3 replicas in parallel.
4. Each replica appends to its WAL, then inserts into its MemTable.
5. Coordinator waits for W = 2 ACKs; on success, returns OK to the client.
6. The third replica (if it ACKed slowly) still applies the write asynchronously.

**Read path:**

1. Client sends `get(key)` to any node (the coordinator).
2. Coordinator forwards the read request to all 3 replicas.
3. Coordinator waits for R = 2 responses, picks the value with the highest version number.
4. If the two responses disagree (version conflict), the coordinator initiates read repair.

---

## 3. Component Deep-Dive

### 3.1 Consistent Hashing for Partitioning

The consistent hash ring maps the 64-bit key space (output of `SHA-256` truncated to 64 bits) onto a logical circle. Each physical node is placed at multiple points on the ring — *virtual nodes* (vnodes) — typically 150 virtual nodes per physical node. Vnodes smooth out the load distribution: with uniform random placement, the standard deviation of load across nodes shrinks from O(1/√N) to O(1/(√(150N))), a 12× improvement.

When a client issues `put("user:42:profile", ...)`, the coordinator hashes the key, finds its position on the ring, then walks clockwise to collect the first N = 3 distinct physical nodes. Those become the replica set for that key. Adding a new physical node to the cluster inserts its vnodes into the ring; only the keys between the new vnode positions and the next existing vnode move — roughly `(1/total_vnodes)` of total data migrates per new vnode, leaving all other keys undisturbed.

This is a direct application of the consistent hashing construction detailed in Chapter 3. The key addition here is that the coordinator uses the ring to select *multiple* replicas, not just one — it picks the top-N distinct physical nodes as it walks clockwise.

### 3.2 Replication Strategy

Each write is sent to all N = 3 replica nodes. The coordinator waits for W acknowledgments before declaring the write successful. The coordinator waits for R responses on a read and returns the value with the highest version.

The consistency guarantee follows from the *quorum overlap* principle: any write quorum (W nodes) and any read quorum (R nodes) must share at least one node, so a read always sees the most recent write. This holds when `R + W > N`. Common configurations:

| Configuration | Consistency | Availability | Write Latency | Read Latency |
|---|---|---|---|---|
| N=3, W=1, R=1 | Eventual | Highest (survives 2 failures) | Lowest | Lowest |
| N=3, W=2, R=2 | Strong | Medium (survives 1 failure) | Medium | Medium |
| N=3, W=3, R=1 | Strong | Lowest (any failure blocks writes) | Highest | Lowest |

DynamoDB defaults to eventually consistent reads (W=1, R=1) but offers a `ConsistentRead=true` flag (R=2 internally). This maps directly to the CAP tradeoff examined in Chapter 4: the AP configuration sacrifices consistency for availability during network partitions; the CP configuration does the reverse.

### 3.3 LSM-Tree Storage Engine

The Log-Structured Merge-Tree (LSM-tree) is the storage engine powering Apache Cassandra, RocksDB, LevelDB, and Google Bigtable. Its key insight is converting random writes (which are expensive on both spinning disks and SSDs due to seek overhead and write amplification) into sequential writes.

**Write path:**

1. The write is appended to the Write-Ahead Log (WAL) on disk — a sequential append, very fast.
2. The write is inserted into the MemTable — an in-memory sorted map (a red-black tree or skip list). The MemTable serves all reads for recently written keys at O(log n) cost.
3. When the MemTable reaches a configured size threshold (e.g., 32 MB), it is flushed to disk as an immutable *SSTable* (Sorted String Table) file. Flushing is sequential I/O. The MemTable is then replaced with a new empty one.

**Read path:**

1. Check the MemTable first. If the key is present (including as a tombstone), return immediately.
2. If not in the MemTable, iterate through SSTables from newest to oldest. For each SSTable, check its Bloom filter; if the filter says "definitely absent," skip the file. If the filter says "possibly present," do a binary search within the SSTable's index, then seek to the data block and read.
3. Return the first (newest) live value found, or "not found" if only tombstones or nothing is found.

**Compaction:**

Over time, many SSTables accumulate on disk. Each SSTable may contain stale versions of the same key (superseded by later writes). Compaction merges multiple SSTables into one, discarding obsolete versions and expired tombstones. The result is fewer, larger SSTables and reduced read amplification (fewer files to check per get). Two strategies:

- **Size-tiered compaction (Cassandra default):** group SSTables of similar size and merge each group. Simple, low write amplification, but high space amplification (two copies during merge).
- **Leveled compaction (RocksDB default):** SSTables are organized into levels; L0 accepts flushes, L1+ have size limits. Each level's SSTables are non-overlapping in key space, so a read touches at most one SSTable per level. Lower read amplification at the cost of higher write amplification.

**Why LSM beats B-tree for write-heavy workloads:**

A B-tree node update on a 4 KB page requires a random I/O write even if only 8 bytes changed. SSDs wear from random small writes. LSM converts all writes to sequential appends: the WAL append is O(1) and sequential; SSTable flush is a large sequential write. For a workload of 10,000 writes/sec at 100 bytes each, LSM generates ~1 MB/sec of sequential writes; a B-tree would generate ~10,000 random 4 KB page writes per second — a 40× difference in write I/O pattern aggressiveness.

### 3.4 Write-Ahead Log (WAL)

Before any write touches the MemTable, it is durably recorded in the WAL — an append-only file on disk. If the node crashes and the MemTable (which lives only in RAM) is lost, the node replays the WAL from the last checkpoint to reconstruct the MemTable exactly as it was.

**WAL record format:**

```
[ seq_num: u64 | op_type: u8 | key_len: u32 | key: [u8] | val_len: u32 | val: [u8] ]
```

- `seq_num` — monotonically increasing per node; used to detect duplicates during replay and to establish write ordering.
- `op_type` — 0 = PUT, 1 = DELETE (tombstone write), 2 = BEGIN_CHECKPOINT.
- `val_len` is 0 for DELETE operations.

**fsync policy:**

The fsync (or fdatasync) system call forces the OS page cache to write through to stable storage. Three policy options:

| Policy | Durability | Latency Impact |
|---|---|---|
| fsync per write | Strongest (no data loss on crash) | +1–5 ms per write |
| fsync per batch (group commit) | Strong (lose at most one batch) | +0.1–0.5 ms per write average |
| No fsync (OS-managed) | Weakest (up to ~30 s of data loss) | Minimal overhead |

Production deployments typically use group commit: writes are batched for 1–2 ms, then a single fsync flushes the entire batch. This amortizes the fsync cost across many writes without sacrificing durability beyond the batch window.

**Checkpoint and WAL truncation:**

After a MemTable is flushed to SSTable and the SSTable is durably written, all WAL records up to that flush point can be deleted. The node writes a checkpoint record to the WAL noting the SSTable's sequence number boundary. On crash recovery, replay starts from the most recent checkpoint, not from the beginning of the WAL.

### 3.5 Bloom Filter

A Bloom filter is a probabilistic data structure that answers "is this key definitely absent from this SSTable?" in O(k) time using a bit array of m bits and k independent hash functions. It has no false negatives — if the filter says "absent," the key is truly absent. It has a bounded false positive rate — it may sometimes say "possibly present" for keys that are actually absent, causing an unnecessary disk read.

**Mechanics:**

- **Insert:** hash the key with each of the k functions; set those k bits to 1.
- **Lookup:** hash the key with each of the k functions; if all k bits are 1, return "possibly present"; if any bit is 0, return "definitely absent."

**False positive rate formula:**

For a filter with m bits, k hash functions, and n inserted keys:

```
FP rate = (1 - e^(-kn/m))^k
```

With k = 2 and a target FP rate of 1%, solving:

```
(1 - e^(-2n/m))^2 < 0.01
→ m/n ≥ 9.6 bits per key  (≈ 10 bits/key rule of thumb)
```

For a 10 million key SSTable, that is 10 MB of Bloom filter stored in RAM — a modest cost for eliminating ~99% of unnecessary disk reads.

**SSTable-level usage:**

Each SSTable file has a corresponding in-memory Bloom filter loaded when the file is opened. On a read, before seeking into any SSTable, the read path checks the filter. With 99% accuracy, on a cold read (key not in MemTable), only 1 in 100 SSTables produces a false positive disk read. This dramatically reduces read amplification.

### 3.6 Versioning and Vector Clocks

In an AP configuration (W=1, R=1), two coordinators can write the same key concurrently without either seeing the other's write. These *concurrent writes* produce *sibling values* — two versions with no causal relationship. The store must detect and surface conflicts rather than silently dropping one write.

Each value carries a *version vector* — a map from node ID to logical clock: `{A: 3, B: 1}` means node A has written 3 times and node B once. On write, the coordinator increments its own entry. On read, if two replicas return values whose version vectors are incomparable (neither dominates the other), the values are siblings. The store returns both to the client; the client (or a background merge process) resolves the conflict and writes back the merged value — this is Amazon Dynamo's *last-write-wins or client-merge* model.

The *last-write-wins* (LWW) strategy is simpler: keep the value with the highest wall-clock timestamp. But LWW silently discards concurrent writes that arrive in the wrong order due to clock skew — a dangerous choice for financial or inventory data. Vector clocks detect the conflict explicitly and let the application decide.

This connects directly to Chapter 4's discussion of the CAP theorem: vector clocks are the mechanism by which an AP system remains aware of divergence without sacrificing availability.

### 3.7 Gossip Protocol for Membership

Nodes discover each other and share cluster state via a gossip protocol (also called epidemic dissemination). Gossip avoids the single-point-of-failure of a centralized membership server while ensuring all nodes converge on a consistent view of the cluster within O(log N) rounds.

**Mechanics:**

- Each node maintains a membership list: `{ node_id → (address, heartbeat_counter, timestamp) }`.
- Every second, each node randomly selects 3 peers and sends its full membership list.
- Upon receiving a list, a node merges it with its own: for each peer, keep the entry with the higher heartbeat counter.
- A node is marked *suspect* if its heartbeat counter has not increased in T_failure seconds (typically 10–30 seconds). After a further T_cleanup period without recovery, it is marked *dead* and removed.

**Convergence:** With a fanout of 3 peers per round and N = 100 nodes, information propagates to all nodes in roughly log₃(100) ≈ 4.2 rounds — under 5 seconds for a 1-second gossip interval.

**Failure detection:** Gossip-based failure detection is eventually consistent — a node must be unresponsive for multiple gossip rounds before it is declared dead. This prevents false positives from transient network hiccups. Cassandra's `phi accrual failure detector` extends this with a continuous suspicion score rather than a binary alive/dead flag, adapting to varying network latency.

---

## 4. Key Algorithms & Data Structures

### 4.1 Rust Implementation

The Rust snippet implements a `MemTable` backed by `BTreeMap<String, Option<String>>` (sorted, O(log n) operations) and a `BloomFilter` with two hash functions built from `std::collections::hash_map::DefaultHasher`. A `None` value represents a tombstone (deleted key). Both structures are `std`-only.

```rust
use std::collections::BTreeMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

// ── MemTable: in-memory sorted write buffer ───────────────────────────────────
struct MemTable {
    data: BTreeMap<String, Option<String>>,
    size: usize,
}

impl MemTable {
    fn new() -> Self {
        MemTable {
            data: BTreeMap::new(),
            size: 0,
        }
    }

    fn put(&mut self, key: String, value: String) {
        self.size += key.len() + value.len();
        self.data.insert(key, Some(value));
    }

    /// Mark a key as deleted by storing a tombstone (None).
    fn delete(&mut self, key: String) {
        self.size += key.len();
        self.data.insert(key, None);
    }

    /// Returns Some(&str) if key is present and not deleted; None otherwise.
    fn get(&self, key: &str) -> Option<&str> {
        match self.data.get(key) {
            Some(Some(v)) => Some(v.as_str()),
            _ => None,
        }
    }

    fn should_flush(&self, max_size: usize) -> bool {
        self.size >= max_size
    }

    /// Produce sorted (key, value) pairs for SSTable flush.
    /// None value means the key is deleted (tombstone).
    fn to_sstable(&self) -> Vec<(String, Option<String>)> {
        self.data
            .iter()
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect()
    }
}

// ── BloomFilter: bit-array with 2 hash functions ──────────────────────────────
struct BloomFilter {
    bits: Vec<bool>,
    size: usize,
}

impl BloomFilter {
    fn new(size: usize) -> Self {
        BloomFilter {
            bits: vec![false; size],
            size,
        }
    }

    fn hash1(&self, key: &str) -> usize {
        let mut h = DefaultHasher::new();
        key.hash(&mut h);
        (h.finish() as usize) % self.size
    }

    fn hash2(&self, key: &str) -> usize {
        let mut h = DefaultHasher::new();
        // Different seed for independence
        0xdeadbeef_u64.hash(&mut h);
        key.hash(&mut h);
        (h.finish() as usize) % self.size
    }

    fn insert(&mut self, key: &str) {
        let i1 = self.hash1(key);
        let i2 = self.hash2(key);
        self.bits[i1] = true;
        self.bits[i2] = true;
    }

    fn may_contain(&self, key: &str) -> bool {
        let i1 = self.hash1(key);
        let i2 = self.hash2(key);
        self.bits[i1] && self.bits[i2]
    }
}

fn main() {
    // ── MemTable tests ────────────────────────────────────────────────────────
    let mut mem = MemTable::new();

    mem.put("alpha".to_string(), "1".to_string());
    mem.put("beta".to_string(),  "2".to_string());
    mem.put("gamma".to_string(), "3".to_string());

    assert!(mem.get("alpha") == Some("1"), "alpha should be 1");
    assert!(mem.get("beta")  == Some("2"), "beta should be 2");
    assert!(mem.get("gamma") == Some("3"), "gamma should be 3");
    assert!(mem.get("delta").is_none(),    "delta should be absent");

    // Delete beta (tombstone)
    mem.delete("beta".to_string());
    assert!(mem.get("beta").is_none(), "beta tombstone: should return None");

    // Flush check
    assert!(!mem.should_flush(10_000), "small table should not flush");
    assert!(mem.should_flush(1),        "threshold=1 should trigger flush");

    // SSTable: sorted, 3 entries, tombstone preserved
    let sstable = mem.to_sstable();
    assert!(sstable.len() == 3,            "SSTable should have 3 entries");
    assert!(sstable[0].0 == "alpha",       "first entry should be alpha");
    assert!(sstable[1].0 == "beta",        "second entry should be beta");
    assert!(sstable[1].1.is_none(),        "beta entry should be tombstone");
    assert!(sstable[2].0 == "gamma",       "third entry should be gamma");

    println!("MemTable tests passed.");

    // ── BloomFilter tests ─────────────────────────────────────────────────────
    // 2048-bit filter, k=2, n=100 keys → FP rate ≈ 0.9% (well under 10%)
    let mut bf = BloomFilter::new(2048);
    let n = 100usize;
    let keys: Vec<String> = (0..n).map(|i| format!("key:{}", i)).collect();

    for k in &keys { bf.insert(k); }

    // No false negatives: every inserted key must return may_contain = true
    for k in &keys {
        assert!(bf.may_contain(k), "inserted key {} must be found", k);
    }

    // Measure FP rate on 1000 non-inserted keys
    let mut fp = 0usize;
    let trials = 1000usize;
    for i in 0..trials {
        if bf.may_contain(&format!("nonexistent:{}", i)) { fp += 1; }
    }
    let fp_rate = fp as f64 / trials as f64;
    assert!(fp_rate < 0.10, "FP rate {} too high", fp_rate);

    println!("BloomFilter FP rate: {:.2}%", fp_rate * 100.0);
    println!("BloomFilter tests passed.");
}
```

### 4.2 Java Implementation

The Java snippet mirrors the Rust structure. `TreeMap<String, String>` provides sorted O(log n) operations; a `null` value represents a tombstone. `BloomFilter` uses two independent polynomial-hash functions over the key's `hashCode()`.

```java
import java.util.*;

public class KVStore {

    // ── MemTable: in-memory sorted write buffer ───────────────────────────────
    static class MemTable {
        // null value = tombstone (deleted)
        private final TreeMap<String, String> data = new TreeMap<>();
        private int size = 0;

        void put(String key, String value) {
            size += key.length() + value.length();
            data.put(key, value);
        }

        /** Store null as tombstone to mark the key as deleted. */
        void delete(String key) {
            size += key.length();
            data.put(key, null);
        }

        /** Returns null if the key is deleted (tombstone) or absent. */
        String get(String key) {
            if (!data.containsKey(key)) return null;
            return data.get(key); // may be null (tombstone)
        }

        boolean shouldFlush(int maxSize) {
            return size >= maxSize;
        }

        /** Sorted entries for SSTable flush; null value = tombstone. */
        List<Map.Entry<String, String>> toSSTable() {
            return new ArrayList<>(data.entrySet());
        }
    }

    // ── BloomFilter: bit-array with 2 hash functions ──────────────────────────
    static class BloomFilter {
        private final boolean[] bits;
        private final int size;

        BloomFilter(int size) {
            this.size = size;
            this.bits = new boolean[size];
        }

        private int hash1(String key) {
            int h = key.hashCode();
            h ^= (h >>> 16);
            return Math.abs(h % size);
        }

        private int hash2(String key) {
            int h = key.hashCode() * 0x9e3779b9;
            h ^= (h >>> 16);
            return Math.abs(h % size);
        }

        void insert(String key) {
            bits[hash1(key)] = true;
            bits[hash2(key)] = true;
        }

        boolean mayContain(String key) {
            return bits[hash1(key)] && bits[hash2(key)];
        }
    }

    public static void main(String[] args) {
        // ── MemTable tests ────────────────────────────────────────────────────
        MemTable mem = new MemTable();
        mem.put("alpha", "1");
        mem.put("beta",  "2");
        mem.put("gamma", "3");

        if (!"1".equals(mem.get("alpha"))) throw new RuntimeException("alpha should be 1");
        if (!"2".equals(mem.get("beta")))  throw new RuntimeException("beta should be 2");
        if (!"3".equals(mem.get("gamma"))) throw new RuntimeException("gamma should be 3");
        if (mem.get("delta") != null)      throw new RuntimeException("delta should be absent");

        mem.delete("beta");
        if (mem.get("beta") != null)       throw new RuntimeException("beta tombstone should return null");

        if (mem.shouldFlush(10_000))       throw new RuntimeException("small table should not flush");
        if (!mem.shouldFlush(1))           throw new RuntimeException("threshold=1 should trigger flush");

        List<Map.Entry<String, String>> ss = mem.toSSTable();
        if (ss.size() != 3)                       throw new RuntimeException("SSTable should have 3 entries");
        if (!"alpha".equals(ss.get(0).getKey()))  throw new RuntimeException("first entry should be alpha");
        if (!"beta".equals(ss.get(1).getKey()))   throw new RuntimeException("second entry should be beta");
        if (ss.get(1).getValue() != null)         throw new RuntimeException("beta should be tombstone");
        if (!"gamma".equals(ss.get(2).getKey()))  throw new RuntimeException("third entry should be gamma");

        System.out.println("MemTable tests passed.");

        // ── BloomFilter tests ─────────────────────────────────────────────────
        BloomFilter bf = new BloomFilter(2048);
        int n = 100;
        List<String> keys = new ArrayList<>();
        for (int i = 0; i < n; i++) keys.add("key:" + i);
        for (String k : keys)       bf.insert(k);

        for (String k : keys) {
            if (!bf.mayContain(k))
                throw new RuntimeException("inserted key missing: " + k);
        }

        int fp = 0;
        int trials = 1000;
        for (int i = 0; i < trials; i++) {
            if (bf.mayContain("nonexistent:" + i)) fp++;
        }
        double fpRate = (double) fp / trials;
        if (fpRate >= 0.10)
            throw new RuntimeException("FP rate too high: " + fpRate);

        System.out.printf("BloomFilter FP rate: %.2f%%%n", fpRate * 100);
        System.out.println("BloomFilter tests passed.");
    }
}
```

---

## 5. Tradeoffs

### 5.1 Storage Engine: LSM-Tree vs B-Tree

| Dimension | LSM-Tree | B-Tree |
|---|---|---|
| **Write amplification** | Low (1× sequential write to WAL; compaction amortized) | High (random page writes; worst case 2× per update on split) |
| **Read amplification** | Higher without Bloom filters (check multiple SSTables) | Lower (O(log n) pages for any key) |
| **Space amplification** | Higher (stale versions live until compaction; ~1.1–3×) | Lower (in-place update; ~1.0–1.3×) |
| **Crash recovery** | WAL replay — can be slow for large MemTable | WAL replay — fast (B-tree pages on disk are always consistent) |
| **Write latency** | Low p99 (WAL append + MemTable insert = µs) | Variable (page split can cause cascading writes) |
| **Range scan** | Efficient (SSTables are sorted; merge-scan across levels) | Efficient (B-tree leaves are linked) |
| **Best for** | Write-heavy, time-series, event logs | Read-heavy, mixed OLTP workloads |

Real-world choices: Cassandra, HBase, RocksDB, LevelDB → LSM. PostgreSQL, MySQL InnoDB, SQLite → B-tree. DynamoDB uses a proprietary variant closer to B-tree for its storage layer but LSM-like semantics at the service boundary.

### 5.2 Replication Configuration Tradeoffs

| Config | Consistency | Availability | Write Latency | Read Latency | Use Case |
|---|---|---|---|---|---|
| N=3, W=1, R=1 | Eventual | Survives 2 node failures | Lowest (fire-and-forget) | Lowest | Social feeds, caches, telemetry |
| N=3, W=2, R=2 | Strong | Survives 1 node failure | Medium | Medium | User profiles, inventory |
| N=3, W=3, R=1 | Strong | Survives 0 write-path failures | Highest (sync all replicas) | Lowest | Financial ledgers, critical config |

**Real-world system choices:**

- **DynamoDB:** Default is eventually consistent (W=1, R=1). `ConsistentRead=true` enables strong reads (R=2 internally). Write path is always W=2 or W=3 internally for durability.
- **Cassandra:** Fully tunable via `CONSISTENCY LEVEL` per query. `QUORUM` maps to W=⌈N/2⌉+1, R=⌈N/2⌉+1 for strong consistency.
- **Bigtable/Spanner:** CP by design. Single-leader replication with Paxos/TrueTime. No tunable consistency; always strongly consistent. Sacrifices availability during leader failover (typically < 30 seconds).

---

## 6. Failure Modes & Mitigations

### 6.1 Node Failure Mid-Write (Hinted Handoff)

**Scenario:** A coordinator attempts to write to Replicas A, B, C. Replica C is down. The coordinator collects W = 2 ACKs from A and B and returns success to the client. Replica C misses the write.

**Problem:** When C recovers, it has a stale view of that key.

**Mitigation — Hinted Handoff:** The coordinator writes the failed update to a local "hints" store: a small persistent log of `(target_node, key, value, seq_num)`. When Replica C rejoins the cluster (detected via gossip), the coordinator (or any node holding the hint) replays the hint. The hint is then deleted. Hints have a TTL: if C is down for more than, say, 3 hours, the hint is dropped and C must be repaired via *anti-entropy* (Merkle-tree-based full reconciliation).

### 6.2 Compaction I/O Spike

**Scenario:** Compaction runs on the same disk as live reads and writes. During a large merge of 10 SSTables, disk throughput is saturated. Read latency spikes from sub-millisecond to tens of milliseconds.

**Mitigations:**
- **Rate-limit compaction I/O:** Configure a maximum compaction throughput (e.g., 64 MB/s) using OS-level I/O throttling or a software token bucket over disk reads/writes.
- **Tiered compaction scheduling:** Run compaction during off-peak hours or when read load is below a threshold, monitored by a background controller.
- **Dedicated compaction disk:** Store SSTables across two physical disks — one for incoming flushes and reads, one for compaction output — eliminating read/write contention.
- **Leveled compaction:** Inherently produces smaller, more frequent compaction jobs rather than one large infrequent one, smoothing I/O over time.

### 6.3 Clock Skew with Last-Write-Wins

**Scenario:** Node A has a wall clock 200 ms ahead of Node B. Client 1 writes `key=foo, value=X` via Node A at wall time T+200. Client 2 writes `key=foo, value=Y` via Node B at wall time T+210 (10 ms later in real time, but smaller wall-clock timestamp after accounting for skew). With LWW, the store keeps X (the earlier wall timestamp), silently discarding Y.

**Mitigations:**
- **Hybrid Logical Clocks (HLC):** Each timestamp is a pair `(physical_time, logical_counter)`. Physical time is bounded by NTP drift; the logical counter advances on causally related events. HLC timestamps are partially ordered: causally related events are always correctly ordered, and concurrent events differ only in the logical component.
- **Vector clocks:** Detect concurrent writes as siblings (Section 3.6) rather than silently discarding one.
- **Enforce NTP discipline:** Require cluster nodes to maintain clock skew < 5 ms via `chronyd` or AWS Time Sync Service; alert and refuse writes if a node drifts beyond tolerance.

### 6.4 Hotspot Key

**Scenario:** A single key — say, a celebrity user's follower count — receives 50,000 writes/sec. All writes hash to the same three replica nodes. Those nodes become CPU and I/O bottlenecks while all other nodes are idle.

**Mitigations:**
- **Read replicas:** Add dedicated read replicas for hot keys. Writes still go to the primary replicas; reads fan out to all replicas.
- **Application-level caching:** Serve hot-key reads from an in-process or Redis cache. Writes invalidate the cache but the write rate is much lower than the read rate for most celebrity-style workloads.
- **Key salting:** Shard the hot key by appending a random suffix (`user:42:count#0` through `user:42:count#9`), distributing writes across 10× more partitions. Reads must merge across shards, adding a scatter-gather step.
- **Rate limiting on write path:** Detect hot keys in real time (count per key per second) and throttle excess writes, returning 429 to the client. Pairs naturally with Chapter 1's rate limiter design.

---

## 7. Java vs Rust

### MemTable Data Structure

Both languages use the same O(log n) sorted-map data structure. `BTreeMap<String, Option<String>>` in Rust and `TreeMap<String, String>` in Java both maintain keys in lexicographic order and support O(log n) get, put, and range iteration. The semantic difference lies in null handling: Java uses `null` as the tombstone value, which is untyped and can cause `NullPointerException` if a caller forgets to check. Rust's `Option<String>` encodes the tombstone at the type level — the compiler forces every call site to handle the `None` case, eliminating a class of runtime errors entirely.

### Object Overhead and Memory Layout

A Java `TreeMap.Entry` object carries 5 pointer-sized fields (key, value, left child, right child, parent) plus object header overhead: approximately 40–56 bytes per entry on a 64-bit JVM. For a MemTable holding 320,000 entries (32 MB at 100 bytes/entry), the tree node overhead alone is ~14–18 MB — nearly doubling the memory footprint.

Rust's `BTreeMap` stores entries in page-sized B-tree nodes (typically 512 bytes per node, holding ~11 entries each). There are no per-entry heap allocations beyond the key and value strings themselves. Memory layout is cache-friendly: neighboring keys in the sort order are on the same or adjacent cache lines. For the same 320,000 entries, Rust's overhead is roughly 2–3 MB — 5–7× more memory-efficient.

### LSM Compaction and GC Pressure

Compaction in Java is CPU-intensive: merging SSTables reads millions of `String` objects from disk, creates new `String` objects for the output, then discards the input objects. This generates significant GC pressure on the JVM heap. With G1GC, a compaction of four 8 GB SSTables can trigger several hundred-millisecond stop-the-world pauses for old-generation collection. Engineers at Cassandra mitigate this with off-heap storage (`sun.misc.Unsafe` or `ByteBuffer.allocateDirect`) for hot paths, but this bypasses GC at the cost of manual memory management complexity.

Rust compaction has no GC pauses by design. `String` values are freed immediately when they go out of scope via `Drop`, with no runtime overhead and no stop-the-world events. The compaction loop processes millions of entries with deterministic memory usage and predictable latency — a significant operational advantage for p99 and p999 latency targets.

### Bloom Filter Hashing

Both implementations use two hash functions derived from the key's hash code. Java's `String.hashCode()` is defined by the language spec (polynomial sum with multiplier 31), making it deterministic and portable. Rust's `DefaultHasher` uses a randomized SipHash-1-3 seed per process, so hash values differ between runs — appropriate for Bloom filters (which are ephemeral and not persisted to disk) but unsuitable for persistent storage keys that must hash consistently across restarts. A production Rust implementation would use a deterministic hash like `FxHasher` or `AHash` for SSTable-level Bloom filters.
