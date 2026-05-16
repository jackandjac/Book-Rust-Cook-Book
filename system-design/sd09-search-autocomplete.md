# Chapter 9: Search Autocomplete / Typeahead

> **Chapter goal:** Design a search autocomplete system serving 10B queries/day with sub-100ms suggestions — using Trie at scale, top-K frequency tracking, and tiered caching strategy.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).
> *Prerequisites: Chapter 15 (Trie Deep Dive in the LeetCode section)*

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

Search autocomplete — sometimes called typeahead — is the dropdown of suggested query completions that appears below a search bar as the user types. Google shows up to ten suggestions; mobile apps typically show five. The system must meet these functional requirements:

- **Prefix-based completion** — as the user types each character, return the top-5 query strings that begin with the characters typed so far. "app" returns ["apple", "application", "app store", "apple music", "appalachian trail"].
- **Popularity ranking** — suggestions are ordered by historical query frequency. "apple" (billion searches) ranks above "applejack spirits" (thousands of searches).
- **Near-real-time trending** — a query that suddenly spikes in volume (a breaking news event) should appear in suggestions within approximately one hour, not the next day.
- **Personalization** — recent queries by the current user are blended into the suggestions (30% weight), giving personal history priority over global popularity for matching prefixes.
- **Multi-language** — suggestions are language-specific. A user with locale `es-MX` sees Spanish completions; a user with `en-US` sees English completions.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| End-to-end latency (network + server) | < 100 ms p99 |
| Server-side suggestion latency | < 10 ms p99 |
| Query throughput | 10 B queries / day = 115,000 QPS |
| Daily active users | 500 M |
| Average query length | 5 characters (5 autocomplete requests per full query) |
| Suggestion freshness | Trending queries visible within 1 hour |
| Unique queries to index | ~10 M |

The most demanding constraint is the **10 ms server-side budget**. With 115,000 QPS hitting autocomplete servers and a 10 ms budget, each server must handle thousands of requests per second. The Trie must live entirely in memory; any disk access within the request path would break the latency target.

### 1.3 Scale Estimates

**Query volume:**
```
10 B full queries / day
Each query generates ~5 autocomplete requests (one per character typed)
Total autocomplete requests: 50 B / day = 578,000 QPS
After CDN (95% hit rate): origin sees 578,000 × 0.05 = ~29,000 QPS
```

**Trie size:**
```
10 M unique queries × average 20 characters = 200 M nodes (naive)
With path compression (Patricia Trie): ~50 M nodes
Per node: 1 char + children HashMap pointer + top-5 cache = ~200 bytes
Total Trie memory: 50 M × 200 bytes = ~10 GB
Fits on a single server with 64 GB RAM, with room for OS + JVM overhead
```

**Offline build frequency:**
```
Daily rebuild: read 7 days of query logs (~70 B events × 20 bytes = 1.4 TB)
Spark job duration: ~2 hours on a 100-node cluster
Result Trie size: ~10 GB serialized
Blue-green deploy: new Trie loaded while old Trie serves traffic
```

**Trending overlay:**
```
Last-hour query counts: Kafka → Flink aggregation → Redis sorted set
10 M unique queries × ~30 bytes per entry = 300 MB Redis
Update latency: Flink checkpoint interval = 30 seconds
```

**Infrastructure summary:**

The scale estimates reveal the system's two key leverage points. First, **the CDN is load-bearing infrastructure**, not an optional optimization. Without it, the autocomplete origin receives 578,000 QPS — requiring ~600 application server cores just to handle requests within the 10 ms budget. With a 95% CDN hit rate, the origin receives 29,000 QPS — manageable with 30 server cores with room for overhead. Second, **the Trie must fit in memory** — there is no path to 10 ms latency with any disk-backed data structure, because a single SSD seek takes ~100 µs and a full-page cache miss in a database takes 1–10 ms, consuming the entire latency budget before any application logic runs.

Bandwidth estimate for the autocomplete read path:
```
Origin traffic (post-CDN): 29,000 QPS
Average response size: 200 bytes (5 query strings × 40 chars)
Origin response bandwidth: 29,000 × 200 bytes = 5.8 MB/sec — trivial
Trie memory read bandwidth: 29,000 QPS × ~5 cache lines per lookup × 64 bytes = ~9 MB/sec
Well within L3 cache bandwidth (~100 GB/sec); Trie fits in L3 for the hot prefixes
```

---

## 2. High-Level Architecture

```
                         QUERY PATH (115K QPS)

  User types "app"
       │
       ▼
  Browser (debounce 50 ms: only send request after 50 ms pause)
       │
       ▼
  CDN Edge Cache
  Key: "ac:{lang}:{prefix}"  TTL: 5 min
  Hit rate: ~95% for prefixes ≤ 4 chars     ─── HIT ──► return top-5 JSON
       │ MISS
       ▼
  Autocomplete Server (in-memory Trie)
  ┌────────────────────────────────────────────────┐
  │  1. Trie.search("app") → global top-5         │
  │  2. Redis.zrevrange("trending:app", 0, 4)     │
  │  3. Redis.smembers("personal:{user_id}:app")  │
  │  4. Merge + re-rank → return top-5            │
  └────────────────────────────────────────────────┘


                       OFFLINE TRIE BUILD (daily)

  Query Logs (S3/HDFS, 7 days)
       │
       ▼
  Spark Job: count query frequency per (query, language)
       │
       ▼
  Trie Builder: insert queries sorted by freq desc → serialize Trie
       │
       ▼
  Object Store (S3): trie-{lang}-{date}.bin
       │
       ▼
  Autocomplete Servers: blue-green reload (load new Trie, swap pointer, GC old)


                       REAL-TIME TRENDING (1-hour lag)

  Search events ──► Kafka (search-events topic)
                         │
                    Flink aggregator
                    (tumbling 1-hour window, sliding every 30 sec)
                         │
                    Redis sorted set: "trending:{lang}:{prefix}"
                    score = query count in last hour
```

The architecture separates concerns cleanly: the offline pipeline handles high-quality, high-coverage suggestions; the real-time pipeline handles trending spikes; the CDN absorbs the vast majority of traffic before it reaches origin.

Three independent subsystems contribute to each autocomplete response, and their failure modes are isolated from each other:

- **Offline Trie (primary)** — built daily from 7-day query log aggregate; provides stable, high-accuracy global suggestions; failure means serving yesterday's Trie (acceptable degradation).
- **Trending overlay (secondary)** — Redis sorted sets updated every 30 seconds from Flink; provides recency for viral queries; failure means trending queries may not appear for up to 1 hour until the Trie is rebuilt (acceptable given the 1-hour freshness SLO).
- **Personalization (tertiary)** — per-user Redis sets; provides personal query history blending; failure means returning only global suggestions (the user sees exactly what a logged-out user would see — acceptable, not noticeable to most users).

This graceful degradation hierarchy means the system always returns at least the global top-K even if the secondary and tertiary systems are unavailable.

---

## 3. Component Deep-Dive

### 3.1 Trie Data Structure at Scale

A standard Trie stores characters at each edge (or node), with children organized in a map or array. The naive implementation requires O(prefix_length + subtree_size) time to find all completions for a prefix, because it must traverse the entire subtree to collect and rank matching queries. At 10 M unique queries, this traversal could touch millions of nodes — far too slow for a 10 ms budget.

The key insight that makes autocomplete Tries practical at scale is caching the **top-K results at each node**. Each Trie node stores not just its character and children, but a pre-computed list of the top-K (query, frequency) pairs among all queries that pass through it. When a user types "app", the system navigates to the 'a' → 'p' → 'p' node in O(3) steps and reads its cached top-K list directly — no subtree traversal needed. Read time is exactly O(prefix_length), regardless of how many matching queries exist.

This pre-computation transforms the read path from O(subtree_size) to O(L), where L is the prefix length. For a 5-character prefix, the Trie lookup is 5 pointer dereferences. At 10 ms budget, a server can comfortably handle thousands of such lookups per second from a single-threaded hot path with the Trie fully in L3 cache.

### 3.2 Top-K Cache at Each Node

The top-K cache at each Trie node is built bottom-up during the offline Trie construction. After all queries are inserted, a post-order traversal propagates top-K lists upward: a node's top-K list is the top-K merge of all its children's top-K lists plus the node's own query (if the node represents a complete query).

During the online insert path used in this chapter's implementation, the top-K is maintained incrementally: when a new query with frequency `f` is inserted, the insert function walks the path character by character and at each node upserts the `(query, frequency)` pair into the node's top-K list. "Upsert" means update the frequency if the query already exists, or add a new entry if it does not. After each upsert, the list is sorted descending by frequency and truncated to K entries. This approach is O(L × K log K) per insert — acceptable for an offline batch builder processing 10 M queries.

The memory cost of storing top-5 at each node is significant. Each entry holds a query string reference and a 4-byte integer. A Trie node for "ap" might store ["apple", "application", "app store", "applejack", "apply"]. At 50 M nodes × 5 entries × ~30 bytes per entry, the top-K cache alone consumes 7.5 GB. This is the dominant cost of the Trie in memory and must be budgeted carefully.

### 3.3 Offline Trie Build Pipeline

The daily Trie build is a batch job that runs after midnight when query log files for the previous day are available in object storage. The pipeline proceeds in four steps.

First, a Spark job reads the last 7 days of query logs and computes the frequency of each `(query, language)` pair. The 7-day window smooths over day-of-week variation (Sunday queries for sports vs Monday queries for work topics). Output is a sorted file: one row per unique query, sorted descending by frequency.

Second, the Trie Builder process reads this file and inserts queries in frequency-descending order. Inserting in this order means that when a node's top-K list fills up, subsequent lower-frequency insertions are immediately discarded at each ancestor node, avoiding unnecessary memory churn.

Third, the completed Trie is serialized to a binary format optimized for memory-mapped loading. Each node is written in breadth-first order so that related nodes are physically adjacent in memory, improving cache locality during lookup. The serialization format stores each node as a fixed-size header (node character + top-K count + children count) followed by the top-K entries and then the child offsets, allowing deserialization by direct casting from the mmap region without copying — the Trie is immediately ready to serve once the OS has mapped the file into the process address space, without waiting for all 10 GB to be read from disk.

Fourth, the serialized Trie is uploaded to object storage and the autocomplete servers perform a blue-green reload: each server downloads the new Trie file, loads it into a separate memory region, swaps the serving pointer atomically, and then garbage-collects the old Trie. The swap takes under 1 second; no requests are dropped during the transition.

### 3.4 Real-Time Trending Adjustments

The offline Trie is rebuilt daily, which means a query that goes viral at 2pm will not appear in the Trie until the next day's rebuild. To cover this gap, a real-time trending overlay provides fresh suggestions for recently popular queries.

Every search event is published to a Kafka topic. A Flink streaming job consumes these events and maintains a sliding count of query frequencies over a 1-hour window with a 30-second update interval. The output is a Redis sorted set per language per prefix: `trending:{lang}:{prefix}`. The score is the query count in the last hour. Only the top-100 trending queries are stored per prefix to bound memory usage.

At read time, the autocomplete server executes two lookups in parallel: the in-memory Trie lookup and a Redis `ZREVRANGE trending:{lang}:{prefix} 0 4` call. The results are merged by score (using the query's frequency from the Trie for known queries, and its trend count for unknown-to-Trie queries), and the final top-5 is returned. If a trending query is already in the Trie, its Trie frequency is used rather than the trend count to avoid volatile ordering; if the query is not yet in the Trie, the trend count serves as its score with a configurable boost multiplier (e.g., 1.5×) to help it surface.

The Redis sorted set for trending has a practical challenge: the prefix space is large. An English-language trending system must maintain sets for all prefixes up to length 5 (the maximum that most users type before selecting a suggestion). With 26 characters and lengths 1–5, that is 26 + 676 + 17,576 + 456,976 + 11,881,376 ≈ 12.4 M potential prefix sets. Maintaining a separate sorted set for each prefix is infeasible. The solution is to maintain trending sets only for the top-K trending query strings themselves — not per prefix. The autocomplete server, on receiving a request for prefix "earthq", performs a prefix scan over the trending set to find matching queries: `ZRANGEBYLEX trending:{lang}:all "[earthq" "[earthq\xff"`. This is an O(log N + M) operation where M is the number of matching trending queries. Since the trending set holds at most 10,000 queries, the scan is fast. The tradeoff vs the per-prefix approach is slightly higher server-side computation, offset by dramatically lower Redis memory usage.

### 3.5 Tiered Caching

The latency and throughput targets are achievable only with aggressive caching at every layer.

**L1: Browser cache.** The browser caches autocomplete responses for 5 minutes by prefix. If the user types "app", deletes to "ap", and re-types "app" within 5 minutes, no network request is made. This reduces repeated-character traffic by ~20% on average.

**L2: CDN edge cache.** The CDN caches responses keyed on `{language}:{prefix}`. Popular prefixes with 1-4 characters ("th", "go", "ho", "wh") are queried billions of times per day and almost never change minute-to-minute. A 5-minute TTL at the CDN achieves a 95%+ cache hit rate for prefixes up to 4 characters, reducing origin QPS from 578,000 to ~29,000. The CDN cache key does not include the user ID, ensuring that personalized suggestions are never cached at the CDN level — only the global top-5 is CDN-cached.

**L3: Autocomplete server in-memory Trie.** The Trie itself is the L3 cache. Lookups complete in under 1 ms. No disk access occurs in the happy path. The Trie is read-only between daily rebuilds, so no locking is required; multiple threads can read it concurrently without synchronization.

The three cache tiers have complementary properties. The browser cache has the lowest latency (0 ms — no network) but the smallest hit rate (only the user's exact recent keystrokes). The CDN cache has near-zero latency for the end user (~5–20 ms to the nearest edge node) and the highest population-wide hit rate (~95%). The in-memory Trie has deterministic sub-millisecond latency but requires a network round-trip from the client to the CDN and from the CDN to the origin (~10–50 ms depending on geography). By stacking these tiers, the system achieves a composite p99 latency of < 100 ms in virtually all cases: CDN hits serve in < 20 ms; origin hits serve in < 60 ms (CDN RTT + 10 ms server latency).

### 3.6 Personalization

Global frequency rankings are excellent for popular queries but poor for power users with specific interests. A user who frequently searches for Rust programming topics wants "rust enum" to appear when they type "rust", not "rustic farmhouse decor".

Personalization blends the global Trie results (70%) with the user's personal query history (30%). The personal history is stored as a Redis hash `personal:{user_id}` mapping query string to a recency score (a decaying count: `score += 1` on each search, `score *= 0.95` daily). At read time, the autocomplete server fetches the personal history entries that match the current prefix and blends them with the global results using a weighted sum of scores.

To protect user privacy, query terms in the personal history Redis store are stored as SHA-256 hashes of the normalized query, and the plaintext query is stored only on the client side (in browser local storage). The server matches prefixes against hashes using a client-provided list of candidate hash prefixes. This design prevents the server from knowing what any individual user has searched for while still supporting personalized completions.

### 3.7 Multi-Language Support

A single global Trie would conflate queries from all languages, causing English completions to dominate for shared prefixes ("ma" could be Spanish "manzana" or English "marvel"). The system maintains a separate Trie per language, built from the same offline pipeline but filtered by detected query language.

Language detection uses the user's locale (from the `Accept-Language` header) as the primary signal, falling back to character-set detection for queries containing non-ASCII characters. The autocomplete server loads Tries for the top-20 languages (covering 99% of query volume) into memory; less common languages are served from a single "other" Trie built from all remaining queries. Unicode normalization (lowercasing + accent stripping using NFKD decomposition) is applied before indexing so that "café" and "cafe" map to the same Trie prefix, and a diacritic-insensitive search returns completions for both.

### 3.8 Query Logging and Frequency Aggregation

Accurate frequency counts are the foundation of the autocomplete ranking. Every query submitted through the search bar is logged with its language, timestamp, and (optionally) a session ID. The logging pipeline must be both high-throughput and loss-tolerant: a dropped log event does not corrupt the system, it merely makes the frequency count for one query slightly lower than reality.

The logging path is: client sends a query → search backend processes it → a fire-and-forget `LoggingService.log(query, lang, ts)` call publishes the event to Kafka. The call is non-blocking; if Kafka is unavailable, the log event is silently dropped (using a bounded in-memory buffer with a short drain timeout). This keeps search latency unaffected by logging infrastructure issues.

The Spark aggregation job reads from Kafka compacted logs stored in HDFS or S3 (via a Kafka-to-S3 connector). It computes frequencies over a 7-day sliding window using a simple `GROUP BY (query, lang) COUNT(*)` operation. The output is a tab-separated file sorted by `lang, freq DESC, query` — the sort order that makes Trie construction efficient, as described in Section 3.3.

A subtlety in the aggregation: bot traffic and spam queries (automated searches, SEO scraping) inflate frequency counts for low-value queries. The aggregation job applies a bot-detection filter — any `(session_id, lang)` pair that generates more than 50 queries per minute is flagged and excluded from the frequency count. This filter prevents adversarial actors from gaming the autocomplete system by repeatedly searching for their brand name.

### 3.9 Autocomplete Query Scoring and Blending

The final ranking presented to the user is not simply the top-K by raw frequency. Several adjustments are applied at serve time to produce a more useful ordering:

**Recency boost**: a query's raw frequency score is multiplied by a decay factor based on how recently it was popular. A query that was searched 10,000 times last year but only 100 times last month receives a lower adjusted score than a query with 5,000 searches this month. The decay formula mirrors EdgeRank's time decay: `adjusted_score = raw_freq × (1 + recent_fraction)`, where `recent_fraction` is the fraction of the query's last-7-day count relative to its last-90-day count. A high `recent_fraction` indicates the query is trending upward.

**Prefix specificity bonus**: longer completions that exactly match the typed prefix more specifically receive a small bonus. If the user types "app" and "app" is itself a valid query (not just a prefix), "app" ranks above "application" even if "application" has higher raw frequency — because the user may be searching for the exact word "app". This is implemented as a configurable bonus (e.g., 1.1× multiplier) applied when `query == prefix`.

**Safe search filtering**: queries flagged by a content safety classifier (adult content, hate speech, dangerous information) are excluded from the autocomplete results or sandboxed to logged-in adult users who have opted out of safe search. The safe-search flag is a field in the Trie's per-query metadata and is checked at zero additional cost during the top-K lookup.

---

## 4. Key Algorithms

The two snippets below implement a Trie that stores top-K completions at every node, enabling O(prefix_length) lookups with no subtree traversal at read time. The data structures mirror each other: both define a `TrieNode` containing a children map and a sorted top-K list, and both implement the same `upsert_top_k` / `insert` / `search` interface.

The critical correctness property is that `insert("apple", 100)` must update the top-K list at the root node and every ancestor node on the path to "apple", not just the terminal 'e' node. This ensures that `search("a")` returns completions for all queries beginning with "a", not just those ending exactly at the 'a' node. The upsert operation must also handle duplicates: if "apple" is inserted twice with different frequencies, the second insert updates the frequency in-place rather than adding a second entry.

A secondary correctness property governs the `search("")` (empty prefix) case: navigating an empty prefix visits zero characters, so the function returns the root node's top-K list directly. After inserting all five test queries, the root's top-K (k=3) contains the three globally highest-frequency queries: banana(300), app(200), application(150).

### 4.1 Rust: Autocomplete Trie with Top-K Cache

```rust
use std::collections::HashMap;

struct TrieNode {
    children: HashMap<char, TrieNode>,
    // top_k: sorted descending by frequency, max size = k
    top_k: Vec<(String, u32)>,
}

impl TrieNode {
    fn new() -> Self {
        TrieNode {
            children: HashMap::new(),
            top_k: Vec::new(),
        }
    }

    /// Upsert (query, freq) into this node's top_k list, maintain sorted order,
    /// truncate to `k`. Returns true if the list changed.
    fn upsert_top_k(&mut self, query: &str, freq: u32, k: usize) {
        if let Some(entry) = self.top_k.iter_mut().find(|(q, _)| q == query) {
            entry.1 = freq;
        } else {
            self.top_k.push((query.to_string(), freq));
        }
        // Sort descending by frequency.
        self.top_k.sort_unstable_by(|a, b| b.1.cmp(&a.1));
        // Truncate to k entries.
        self.top_k.truncate(k);
    }
}

struct AutocompleteTrie {
    root: TrieNode,
    k: usize,
}

impl AutocompleteTrie {
    fn new(k: usize) -> Self {
        AutocompleteTrie {
            root: TrieNode::new(),
            k,
        }
    }

    /// Insert a query with its frequency. Updates top_k at every node
    /// along the path from root to the terminal node.
    fn insert(&mut self, query: &str, freq: u32) {
        let k = self.k;
        // Update root's top_k first.
        self.root.upsert_top_k(query, freq, k);
        // Walk the path, updating each node's top_k.
        let mut node = &mut self.root;
        for ch in query.chars() {
            node = node.children.entry(ch).or_insert_with(TrieNode::new);
            node.upsert_top_k(query, freq, k);
        }
    }

    /// Return the top-k completions for the given prefix.
    /// Empty prefix returns the global top-k (from root).
    fn search(&self, prefix: &str) -> Vec<(String, u32)> {
        let mut node = &self.root;
        for ch in prefix.chars() {
            match node.children.get(&ch) {
                Some(child) => node = child,
                None => return Vec::new(),
            }
        }
        node.top_k.clone()
    }
}

fn main() {
    let mut trie = AutocompleteTrie::new(3);
    trie.insert("apple", 100);
    trie.insert("app", 200);
    trie.insert("application", 150);
    trie.insert("apply", 80);
    trie.insert("banana", 300);

    // "app" prefix: expect top-3 among apple(100), app(200), application(150), apply(80)
    // = [app(200), application(150), apple(100)]
    let results = trie.search("app");
    assert_eq!(results[0].0, "app");
    assert_eq!(results[0].1, 200);
    assert_eq!(results.len(), 3);

    // "b" prefix: only banana
    let results2 = trie.search("b");
    assert_eq!(results2[0].0, "banana");

    // Empty prefix: global top-3 = banana(300), app(200), application(150)
    let all = trie.search("");
    assert_eq!(all[0].0, "banana");

    println!("Autocomplete trie test passed.");
    println!("search(\"app\"): {:?}", trie.search("app"));
    println!("search(\"\"):    {:?}", trie.search(""));
}
```

### 4.2 Java: Autocomplete Trie with Top-K Cache

```java
import java.util.*;

public class AutocompleteTrie {

    private record Entry(String query, int freq) {}

    private static class TrieNode {
        final Map<Character, TrieNode> children = new HashMap<>();
        // top_k sorted descending by freq, max size k
        final List<Entry> topK = new ArrayList<>();
    }

    private final TrieNode root = new TrieNode();
    private final int k;

    public AutocompleteTrie(int k) {
        this.k = k;
    }

    /** Upsert (query, freq) into a node's topK list; keep sorted desc, truncate to k. */
    private void upsertTopK(TrieNode node, String query, int freq) {
        // Update existing entry if present.
        for (int i = 0; i < node.topK.size(); i++) {
            if (node.topK.get(i).query().equals(query)) {
                node.topK.set(i, new Entry(query, freq));
                node.topK.sort((a, b) -> Integer.compare(b.freq(), a.freq()));
                return;
            }
        }
        // New entry.
        node.topK.add(new Entry(query, freq));
        node.topK.sort((a, b) -> Integer.compare(b.freq(), a.freq()));
        if (node.topK.size() > k) {
            node.topK.remove(node.topK.size() - 1);
        }
    }

    /** Insert query with freq; update top-k at root and every node along the path. */
    public void insert(String query, int freq) {
        upsertTopK(root, query, freq);
        TrieNode node = root;
        for (char ch : query.toCharArray()) {
            node.children.putIfAbsent(ch, new TrieNode());
            node = node.children.get(ch);
            upsertTopK(node, query, freq);
        }
    }

    /**
     * Return top-k query strings for the given prefix.
     * Empty prefix returns the global top-k.
     */
    public List<String> search(String prefix) {
        TrieNode node = root;
        for (char ch : prefix.toCharArray()) {
            node = node.children.get(ch);
            if (node == null) return Collections.emptyList();
        }
        List<String> result = new ArrayList<>(node.topK.size());
        for (Entry e : node.topK) {
            result.add(e.query());
        }
        return result;
    }

    // Helper: replaces assert keyword.
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError("FAIL: " + message);
    }

    public static void main(String[] args) {
        AutocompleteTrie trie = new AutocompleteTrie(3);
        trie.insert("apple", 100);
        trie.insert("app", 200);
        trie.insert("application", 150);
        trie.insert("apply", 80);
        trie.insert("banana", 300);

        // "app" prefix: top-3 = [app(200), application(150), apple(100)]
        List<String> results = trie.search("app");
        check(results.size() == 3, "app search should return 3 results");
        check(results.get(0).equals("app"), "app should rank first for prefix 'app'");
        check(results.get(1).equals("application"), "application should rank second");
        check(results.get(2).equals("apple"), "apple should rank third");

        // "b" prefix: only banana
        List<String> results2 = trie.search("b");
        check(!results2.isEmpty(), "b search should return results");
        check(results2.get(0).equals("banana"), "banana should rank first for prefix 'b'");

        // Empty prefix: global top-3 = banana(300), app(200), application(150)
        List<String> all = trie.search("");
        check(!all.isEmpty(), "empty prefix should return results");
        check(all.get(0).equals("banana"), "banana should rank first globally");

        System.out.println("Autocomplete trie test passed.");
        System.out.println("search(\"app\"): " + trie.search("app"));
        System.out.println("search(\"\"):    " + trie.search(""));
    }
}
```

---

## 5. Tradeoffs

The central tension in autocomplete design is **read latency vs freshness**. Aggressive pre-computation (offline Trie, top-K cache at each node, CDN caching) delivers sub-millisecond lookups but introduces 24-hour staleness for the base index. Real-time overlays (trending Redis sorted sets) restore freshness at the cost of added complexity and an extra Redis round-trip per request. The table below compares the three primary backend approaches at a high level before diving into the specifics.

### 5.1 Autocomplete Backend Comparison

| Dimension | Trie with top-K cache | Inverted Index (Elasticsearch) | Redis Sorted Sets |
|---|---|---|---|
| Read latency | O(prefix_length) ≈ 1 ms in-memory | 10–50 ms (disk + shard fan-out) | O(log N) ≈ 1–5 ms |
| Write / update complexity | High — rebuild ancestor chain on each insert | Low — single document upsert | Low — ZADD |
| Memory footprint | ~10 GB for 10 M queries with top-5 cache | ~50–100 GB (inverted index + source) | ~300 MB for top-K per prefix |
| Prefix matching quality | Exact prefix only | Full-text (substring, fuzzy, typos) | Exact prefix (ZRANGEBYLEX) |
| Real-time updates | Requires Trie rebuild or trending overlay | Native (near-real-time index) | Native (ZADD immediately visible) |
| Horizontal scalability | Read-replicated (copy Trie to each server) | Sharded natively | Sharded by prefix hash |
| Best for | Exact-prefix suggestions at ultra-low latency | Search with typo-tolerance and relevance | Small query sets with frequent updates |

### 5.2 Storing Top-K at Each Node vs Lazy Traversal

The top-K-at-each-node approach uses more memory (7.5 GB for the cache alone) but delivers O(prefix_length) read time. The alternative — lazy traversal — stores nothing extra per node and finds completions by doing a DFS from the prefix node, collecting all matching queries and sorting them. For a prefix like "a" that matches millions of queries, lazy traversal would take seconds. For a rare prefix like "xyloph" that matches three queries, lazy traversal finishes in microseconds.

The top-K cache is the right default for an autocomplete system because the common prefixes (short, popular) are exactly the ones with the most matching queries — the case where lazy traversal performs worst. The cache ensures that the most-queried prefixes are also the fastest to serve.

An optimization for memory-constrained deployments is to store top-K only at nodes above a depth threshold (e.g., depth ≤ 4) and use lazy traversal for deeper nodes. Nodes at depth 5 and below match fewer queries (very specific prefixes), so lazy traversal is fast there, and the memory savings from removing deep-node caches can be substantial.

A third approach — used by some production systems — is to avoid a Trie entirely for the offline index and instead use a **prefix-sorted inverted list**: all 10 M queries are stored in sorted order in a flat array. A binary search on the prefix finds the start of the matching range; a scan from that position collects the next N queries alphabetically, which are then scored by frequency and the top-5 returned. This approach has excellent cache locality (sequential memory access), no per-node overhead, and supports both prefix lookup and range queries. The cost is that it does not store pre-ranked top-K: the full scoring and sorting must happen at read time over all alphabetical matches. For dense prefix ranges (the prefix "a" returns millions of queries), this scan is too slow. For sparse ranges (5+ character prefixes), it is competitive with or faster than the Trie.

### 5.3 Whole-Word vs Prefix-Any (Substring) Matching

Standard Trie autocomplete supports only prefix matching: "app" returns queries starting with "app". It cannot return "happy" in response to "app" even though "app" is a substring.

Substring (infix) matching is achievable by inserting each query into the Trie once for every suffix position. "apple" is inserted as "apple", "pple", "ple", "le", "e". This multiplies Trie size by average query length (~5×), from 10 GB to 50 GB — feasible but expensive. The tradeoff is not worth it for most search engines where users expect prefix matching, but is valuable for code search or document search where users may type the middle of a function name.

### 5.4 CDN Cacheability and Cache Key Design

Autocomplete is unusually CDN-friendly because the cache key is simply the `{language}:{prefix}` string — a small, finite set. The 26-character English alphabet means there are 26 + 676 + 17,576 = ~18,000 prefix combinations for lengths 1–3. With a 5-minute TTL, the CDN needs to store only 18,000 × (average response size 200 bytes) = 3.6 MB of cached data per edge node to achieve full coverage of all 1-3 character English prefixes. This is negligible compared to typical CDN edge node memory.

Personalized suggestions cannot be CDN-cached (they contain user-specific data). The architecture separates the CDN-cached global top-5 from the personalized blend, which is always computed origin-side and returned with `Cache-Control: private, no-store`. The client-side JavaScript merges the two: it fetches the global top-5 from CDN and the personal suggestions from a separate `/personalized` endpoint, then displays the merged top-5. This separation lets the CDN absorb 95% of the traffic while still delivering personalized results for every user.

One subtlety in CDN cache key design is **case normalization**. A user typing "App" and a user typing "app" should receive the same global suggestions, but if the CDN key is the raw prefix string, these would be two separate cache entries — halving the effective hit rate for mixed-case inputs. The solution is to normalize the prefix to lowercase in the client-side JavaScript before constructing the CDN request URL. Normalization must happen consistently across all clients (web, iOS, Android) and match the normalization applied when building the Trie. A mismatch — for example, the iOS app not normalizing but the Trie being built on lowercase-normalized queries — would cause the CDN to return a miss and the autocomplete server to return no results for capitalized prefixes.

---

## 6. Failure Modes

Autocomplete systems have a gentle failure profile: a degraded or stale response is far better than an error. A user who sees slightly outdated suggestions still gets a useful experience; a user who sees a spinner or error message abandons the search box entirely. This drives a philosophy of "always return something" — even if that something is yesterday's Trie, an empty trending overlay, or global suggestions without personalization.

### 6.1 Trie Rebuild Failure

**Scenario:** The daily Spark job fails at 3 AM due to an executor OOM error on an anomalously large query log. The Trie is not rebuilt. By morning, the autocomplete servers are still serving the previous day's Trie, which is now 48 hours stale instead of 24 hours stale.

**Detection:** Trie build pipeline monitoring alerts if no new Trie is published to object storage by 6 AM. On-call is paged.

**Mitigation:** The system maintains a rolling window of the last 3 successfully built Tries in object storage (`trie-{lang}-{date}.bin`). On startup, autocomplete servers load the most recent available Trie. If the current day's build fails, the previous day's Trie continues to serve with only marginally degraded suggestion quality. The Spark job retries automatically three times before alerting; it is also idempotent so a manual re-run is safe. Critical path: the trending overlay (Redis sorted set) is unaffected by Trie build failure and continues to surface new viral queries within 1 hour regardless.

### 6.2 Memory Exhaustion from Trie Growth

**Scenario:** A marketing campaign generates 500,000 unique new query strings over a single day (e.g., "[brand name] + [product variant]"). The Trie grows beyond its memory budget, triggering OOM on the autocomplete servers. The processes crash; the CDN's origin-miss traffic hits a depleted origin pool and latency spikes to seconds.

**Detection:** Autocomplete server memory usage exceeds 80% of available RAM; JVM GC pause time exceeds 500 ms; process heap metrics alert.

**Mitigation:** The Trie build pipeline enforces a minimum frequency threshold before inserting a query. Only queries with frequency ≥ 10 in the 7-day window are included. This alone eliminates 80–90% of unique query strings (the long tail), which are typos, highly personal queries, or one-off noise. With the threshold, Trie size is bounded at ~10 M qualifying queries even as total query volume grows. The threshold is tunable: raising it from 10 to 50 reduces the Trie by another 30% at the cost of losing suggestions for moderately rare queries. A Trie size budget (e.g., max 8 GB serialized) is enforced in the build pipeline; if the threshold at 10 would produce a Trie larger than 8 GB, the threshold is automatically raised until the budget is met.

### 6.3 Trending Spike for Viral Query

**Scenario:** A major news event causes "earthquake california" to spike from 100 searches/day to 10 M searches/hour. The offline Trie from last night does not contain this query (it had < 10 searches/day and was below the frequency threshold). Users typing "earthq" see no relevant autocomplete suggestion for the first few minutes.

**Detection:** Not strictly a failure — a known limitation. The trending overlay is the designed mitigation.

**Mitigation:** The Flink streaming job picks up the spike within 30 seconds (its checkpoint interval). The Redis sorted set `trending:en:earthq` is updated with the new query's score within 1 minute. By the time the story is trending, autocomplete servers are already blending this query into results. The 1-hour lag in the requirement refers to worst-case freshness; in practice, trending queries appear within 1–5 minutes. A separate "breaking news" feed can inject queries into the trending overlay with a priority boost flag, reducing the lag to under 30 seconds for the highest-priority events.

### 6.4 Prefix Explosion for Ultra-Common Prefixes

**Scenario:** The prefix "the" matches 2 M unique queries in English. Lazy traversal from the "the" node would take seconds. A new engineer removes the top-K node cache as a "memory optimization" during a refactor, not understanding its purpose.

**Detection:** Autocomplete latency for any prefix ≤ 3 characters spikes from < 1 ms to > 1 second; alarms fire immediately.

**Mitigation:** The architectural defense is the top-K cache: with pre-computed top-5 at the "the" node, the lookup is O(3) regardless of how many queries match. This must be preserved. Operationally, the Trie's cache coverage is tested in the build pipeline: a post-build validation script queries the Trie for the 1,000 most common English prefixes and asserts that each returns exactly K results with latency < 1 ms. This test would have caught the hypothetical refactor before deployment. A canary deployment process (10% traffic to new Trie before full rollout) provides a final safety net: latency metrics on the canary fleet would have spiked, triggering automatic rollback.

### 6.5 CDN Cache Poisoning via Malformed Prefix

**Scenario:** A malicious actor sends a crafted autocomplete request with a prefix containing a null byte, Unicode surrogate characters, or a very long string (10,000 characters). The autocomplete server normalizes the prefix to lowercase and queries the Trie, returning an empty result. The CDN caches this response at the key `ac:en:{malicious_prefix}` with a 5-minute TTL. For the next 5 minutes, any real user who types those characters (unlikely, but possible) gets a cached empty response. More seriously, if the malicious prefix matches a CDN cache eviction pattern, legitimate cached responses may be displaced.

**Detection:** CDN cache entry count for a given language grows beyond expected bounds (normal English has ~18,000 prefix combinations up to length 3; an attacker can generate millions of unique malformed prefixes). Cache hit rate for common prefixes drops; origin traffic rises.

**Mitigation:** Apply strict input validation at the autocomplete server before any CDN interaction: (1) reject prefixes longer than 100 characters with HTTP 400, (2) normalize Unicode using NFKD and strip non-printable characters, (3) reject prefixes containing characters outside the expected character set for the detected language. Use a cache key that includes a hash of the validated prefix rather than the raw prefix, preventing cache key injection. Additionally, set a `Vary: Accept-Language` header and ensure the CDN only caches responses with HTTP 200 status — so malformed-prefix 400 responses are never cached at the CDN layer.

### 6.6 Trie Server Cold Start Latency

**Scenario:** An autocomplete server is added to the fleet during a traffic spike (auto-scaling event). The new server must download the 10 GB Trie from object storage before it can serve any requests. This download takes 60–90 seconds on a typical cloud internal network. During this time, the load balancer may route traffic to the new server (which returns errors), or the server may be excluded from the pool until healthy — delaying the capacity increase.

**Detection:** Auto-scaling policy triggers a scale-out event; new instances take 90+ seconds to become healthy (readiness probe fails until Trie is loaded); existing instances see increased load during the cold start period.

**Mitigation:** Three strategies. First, use a **readiness probe** that fails until the Trie is fully loaded and the server is ready to handle requests — the load balancer will not route traffic to the new instance until it passes. This is already the standard Kubernetes pattern. Second, pre-bake the most recent Trie into the server AMI (machine image) or Docker image during the weekly build. Cold starts then require only loading the baked-in Trie from local disk (~10 seconds) rather than downloading from object storage. The daily delta update (which the baked image lacks) is fetched as a small incremental file (<100 MB). Third, use **Trie sharding**: instead of each server holding all languages, assign language shards to servers (server group A serves English + Spanish, group B serves all others). Each server's Trie is 500 MB–2 GB rather than 10 GB, reducing cold start time proportionally.

---

## 7. Java vs Rust: Language Comparison

The Trie implementation exposes several interesting language-level contrasts: how each language handles recursive data structures, unboxed vs boxed primitive keys, deterministic vs GC-managed memory reclamation, and sorting stability. Each of these has practical implications for a system with 50 M Trie nodes and daily full rebuilds.

### HashMap Key Types: `char` vs `Character`

Rust's `HashMap<char, TrieNode>` uses `char` as a key directly. Rust's `char` is a 4-byte Unicode scalar value stored inline in the hash map's entry structure; there is no heap allocation for the key. Hashing a `char` is hashing a `u32` — a single operation.

Java's `HashMap<Character, TrieNode>` must use the boxed `Character` wrapper class because Java generics do not support primitive types. Each `Character` key is a separately heap-allocated object (16-byte header + 2-byte `char` value, padded to 24 bytes). For a Trie with 50 M nodes averaging 5 children each, the children map keys alone consume 50 M × 5 × 24 bytes = 6 GB in Java vs approximately 50 M × 5 × 4 bytes = 1 GB in Rust. This is a significant practical difference for a memory-sensitive data structure like a Trie.

### Recursive Struct: `Box<TrieNode>` vs `HashMap`

A Trie node conceptually contains its children — a recursive type. Rust requires that recursive types have a known size at compile time. For an array-indexed implementation (children as `[Option<Box<TrieNode>>; 26]`), each child pointer must be `Box<TrieNode>` because the `TrieNode` type cannot contain itself by value (infinite size). However, for the `HashMap<char, TrieNode>` approach used in this chapter, Rust also requires `Box` — the `HashMap` internally heap-allocates its entries, so the recursion is broken by the heap allocation. This is why `HashMap<char, TrieNode>` (not `Box<TrieNode>`) compiles: the children are owned by the map's internal heap storage, and the map itself is a fixed-size struct on the parent node.

In Java, this is not a concern — all objects are heap-allocated by default, and a field of type `TrieNode` in Java is always a reference (pointer) to a heap-allocated object. Java's automatic reference semantics mean that recursive types require no special annotation. The Rust programmer's need to reason about ownership and heap placement is absent in Java, at the cost of losing control over allocation patterns.

### Garbage Collection vs Deterministic Drop on Trie Rebuild

The daily Trie rebuild creates a significant allocation event: a new 10 GB Trie is built in memory while the old 10 GB Trie is still serving traffic. Peak memory usage reaches 20 GB. After the atomic pointer swap, the old Trie is no longer reachable.

In Java, the old Trie's 50 M nodes become garbage simultaneously. The JVM's garbage collector (G1 or ZGC) must identify and reclaim them, potentially causing GC pauses of hundreds of milliseconds to seconds during the collection phase — even with modern concurrent collectors. A GC pause during the Trie swap would cause autocomplete latency spikes visible to users. The mitigation is to use ZGC (which has sub-millisecond pause goals) and to trigger an explicit `System.gc()` hint after the swap during a low-traffic window.

In Rust, dropping the old Trie is deterministic: `drop(old_trie)` recursively frees each node in a predictable order. The drop is synchronous and single-threaded, which means it blocks the thread performing the swap for the duration of the drop (potentially hundreds of milliseconds for 50 M nodes). The Rust solution is to spawn the drop on a background thread: `std::thread::spawn(move || drop(old_trie))`, keeping the serving thread unblocked. Unlike Java's GC, the Rust drop is entirely predictable in timing and does not affect other threads' allocations.

### Enum-Based vs HashMap-Based Children

An alternative Trie implementation uses an array of 26 optional children (one per lowercase ASCII letter) instead of a `HashMap`. In Rust, this is `children: [Option<Box<TrieNode>>; 26]` — a fixed-size array on the stack (well, on the heap since it's inside a `Box`), with O(1) child lookup by character index (`ch as usize - 'a' as usize`). This avoids all hashing overhead and is more cache-friendly for dense subtrees (common short prefixes like "th", "an", "in").

Java does not have an ergonomic equivalent for stack-allocated fixed arrays inside objects. An `Object[]` array of 26 elements stores 26 references (each 4 or 8 bytes with compressed oops) plus per-element boxing overhead for each `TrieNode`. A `TrieNode[]` of length 26 stores 26 null-or-reference values, which is the Java equivalent — clean and efficient. Both approaches yield O(1) child lookup; Java's version pays pointer-indirection per access but avoids hashing overhead. For ASCII-only autocomplete, the array approach is preferable to `HashMap` in both languages; for full Unicode, `HashMap` is necessary since the 26-entry array does not cover the full Unicode character space.

### Immutability and Concurrent Read Safety

The offline Trie is built once and then read-only during its serving lifetime. In Rust, a `&AutocompleteTrie` reference can be shared across as many threads as needed with no synchronization, because the borrow checker proves the reference cannot be used to mutate the Trie. Wrapping the Trie in an `Arc<AutocompleteTrie>` allows multiple threads to hold a reference-counted pointer to the same Trie, with the `Arc` providing safe shared ownership. The serving pointer swap — replacing the old Trie with a new one — is done with `Arc::swap` (or an `ArcSwap` from the `arc-swap` crate in production) which is atomic at the pointer level.

In Java, making the Trie read-only requires discipline rather than type-system enforcement: you must document that `TrieNode.children` and `TrieNode.topK` must not be modified after construction, and wrap the serving Trie in a `volatile AutocompleteTrie trieRef` field that is written atomically when the new Trie is ready. The `volatile` keyword ensures all threads see the updated reference immediately (happens-before relationship). There is no equivalent of Rust's compile-time immutability proof; a future engineer can still call `node.topK.add(...)` on a serving Trie without any compiler warning. Making `topK` and `children` `final` fields prevents reassignment but not mutation of the collection contents. True immutability in Java requires returning unmodifiable views (`Collections.unmodifiableList(topK)`) from accessor methods, which adds indirection overhead.

### `sort_unstable_by` vs `sort_by`

The Rust snippet's `upsert_top_k` method calls `sort_unstable_by` rather than `sort_by`. For `Vec<(String, u32)>` sorted by the `u32` frequency field, stability (preserving the relative order of equal-frequency entries) is irrelevant — any total order that puts higher frequencies first is correct. `sort_unstable_by` is faster than `sort_by` in practice because it uses pattern-defeating quicksort rather than timsort, avoiding the memory overhead of timsort's merge phase for small arrays. For the top-K list, which has at most K elements (K = 3 to 10 in typical use), the practical difference is small, but `sort_unstable_by` signals correct intent: stability is not a requirement here.

Java's `List.sort(Comparator)` always uses a stable sort (adapted timsort). There is no `sortUnstable` equivalent in the standard library. For short lists (< 64 elements), Java's timsort degrades to insertion sort, which is stable and fast for nearly-sorted data — an appropriate choice since the top-K list is already mostly sorted after the first few inserts.

---

## Key Takeaways

- **Trie with top-K at each node** enables O(prefix_length) lookup regardless of how many queries match. This pre-computation is the fundamental insight that makes autocomplete fast at scale.
- **Hybrid offline + real-time architecture**: offline Trie (daily batch) handles coverage and accuracy; Redis trending sorted sets handle freshness for viral queries within 1 hour.
- **CDN is load-bearing**: a 95% CDN hit rate reduces origin QPS from 578K to ~29K. Without it, the server fleet must be 20× larger.
- **Minimum frequency threshold** bounds Trie size. Only queries with frequency ≥ 10 in 7 days are indexed; this eliminates 80–90% of unique query strings.
- **Rust `HashMap<char, TrieNode>`** stores keys inline (4 bytes/char, no heap allocation). Java `HashMap<Character, TrieNode>` boxes each key (24 bytes/character). For 50 M nodes × 5 children, this is 1 GB vs 6 GB for children keys alone.
- **Deterministic Rust drop** of the old Trie on rebuild requires spawning a background thread to avoid blocking the serving path. Java's GC handles reclamation concurrently but with unpredictable pause times; use ZGC for sub-millisecond GC pauses.
- **`sort_unstable_by` in Rust** is the correct choice for the top-K list: stability is not required, and avoiding timsort's merge phase saves memory on short lists.
