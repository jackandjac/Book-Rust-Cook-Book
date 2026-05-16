# Chapter 2: URL Shortener (TinyURL)

> **Chapter goal:** Design a URL shortening service handling 100M URLs, 10K writes/sec, 100K reads/sec — with Base62 encoding, consistent hashing for storage, and cache-heavy read path.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

A URL shortener is one of the most instructive system design problems: it is simple enough to state in one sentence but complex enough to exercise every major design discipline — ID generation, distributed caching, database sharding, asynchronous pipelines, and failure mode analysis. Services like TinyURL (2002), bit.ly (2008), and t.co (Twitter, 2011) handle billions of redirects per day. This chapter designs a production-grade equivalent.

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A URL shortener maps arbitrary long URLs to compact identifiers — short codes — and then redirects visitors back to the original URL. The system must satisfy:

- **Shorten URL** — accept a long URL and return a 7-character short code (e.g., `https://short.ly/baaaaab`).
- **Redirect** — given a short code, look up the original URL and issue an HTTP redirect (301 or 302).
- **Custom aliases** — allow users to request a specific short code (e.g., `/my-brand`) subject to availability and rate limits.
- **Expiry / TTL** — each URL can carry an optional expiry timestamp; expired short codes return 410 Gone.
- **Analytics** — track click counts per short code; counts are eventually consistent (no strict transactional requirement).

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Redirect latency | < 10 ms p99 end-to-end |
| Write latency (shorten) | < 50 ms p99 |
| Availability | 99.99% (< 52 min/year downtime) |
| Access pattern | Write-once / read-many; reads dominate at 10:1 ratio |
| Durability | URLs must survive server restarts; stored in replicated DB |
| Analytics accuracy | Eventual consistency acceptable; count lag < 30 s |

### 1.3 Scale Estimates

| Dimension | Estimate |
|---|---|
| Total URLs stored | 100 million |
| Write rate | 10,000 URLs/sec |
| Read (redirect) rate | 100,000 req/sec |
| Average URL size | 500 bytes (long URL + metadata) |
| Total storage | 100M × 500 B = **50 GB** |
| Cache working set | Top 20% URLs serve 80% of traffic (Pareto) |
| Cache entries | 20M × 200 B (short code + long URL) = **4 GB** |
| Short code space | 62^7 = **3.52 trillion** unique codes |

**Writes per day:** 10,000/sec × 86,400 sec = 864 million writes/day — the system would exhaust the 7-char space after ~11 years of writing at this rate (62^7 ÷ 864M/day ÷ 365 ≈ 11.2 years). In practice the Snowflake counter resets periodically and IDs are recycled after expiry, so the effective horizon is much longer.

**Reads per second per API server:** assuming 10 API nodes, each handles 10,000 reads/sec. With 80% served from cache, only 2,000 reads/sec per node reach the database.

**Network bandwidth:**
- Inbound (shorten): 10K writes/sec × 2 KB average long URL = ~20 MB/s — negligible.
- Outbound (redirect): 100K reads/sec × 200 B average response = ~20 MB/s — also negligible. The bottleneck is compute (cache lookups, DB queries) not bandwidth.

**Peak-to-average ratio:** assume 3× peak multiplier during business hours. The system must sustain 300K reads/sec at peak without degradation. Redis handles this easily (1M+ ops/sec per node); the DB read replicas are the constraint to size carefully.

---

## 2. High-Level Architecture

```
                              ┌────────────────────────────────────────────────────┐
                              │                  API Server Cluster                │
Client ──► CDN / Edge   ─────►│                                                    │
           Cache              │  ┌───────────┐  ┌───────────┐  ┌───────────┐      │
           (long TTL          │  │  Node A   │  │  Node B   │  │  Node C   │      │
           for 301s)          │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘      │
                              └────────│───────────────│───────────────│────────────┘
                                       │               │               │
                    ┌──────────────────┼───────────────┼───────────────┘
                    │                  │               │
                    ▼                  ▼               ▼
            ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
            │  Redis Cache │  │  Short Code  │  │  Analytics   │
            │  (4 GB hot   │  │  Generator   │  │  Queue       │
            │   set, LRU)  │  │  (Snowflake- │  │  (Kafka)     │
            └──────┬───────┘  │  like ID)    │  └──────┬───────┘
                   │          └──────┬───────┘         │
                   │                 │                  ▼
                   ▼                 ▼          ┌──────────────┐
            ┌──────────────────────────────┐    │  Analytics   │
            │  URL Database (Sharded)      │    │  Consumer    │
            │  MySQL / Postgres            │    │  → ClickDB   │
            │  Sharded by short_code hash  │    │  (ClickHouse │
            └──────────────────────────────┘    │   / DynamoDB)│
                                                └──────────────┘
```

**Key design decisions:**

- **Stateless API servers** — any node can handle any request; state lives in Redis and the DB. Statelessness makes horizontal scaling trivial: add nodes, update the load balancer, done.
- **Centralized unique ID generator** — a small cluster of ID-generator nodes produces globally unique, monotonically increasing IDs using a Snowflake-like scheme. This decouples ID generation from URL storage.
- **Redis as read-through cache** — the cache-aside pattern keeps the read path fast (< 1 ms for cache hits) without application-level complexity.
- **Kafka for analytics** — click events are written to Kafka fire-and-forget so the redirect path is never blocked by analytics writes.
- **CDN / Edge cache for 301s** — if the service issues 301 Permanent redirects, the CDN can cache the redirect response at the edge. Subsequent requests for the same short code never reach the API servers. This is the most effective latency optimization available — a round trip to the nearest CDN edge node is typically 5–30 ms globally, versus 50–200 ms to the origin data center.

**Request lifecycle (write path — shorten URL):**

```
1. Client POST /shorten  {long_url, custom_alias?, ttl?}
2. API server validates URL format, checks custom alias availability
3. ID Generator → Snowflake ID → encode Base62 → short_code
4. DB INSERT INTO urls (id, short_code, long_url, ...)
5. Response: 201 Created  {short_code: "baaaaab", short_url: "https://short.ly/baaaaab"}
```

**Request lifecycle (read path — redirect):**

```
1. Client GET /baaaaab
2. CDN edge: cache hit → 301 redirect served from edge (0 ms to origin)
   CDN edge: miss → forward to API server
3. API server: Redis GET url:baaaaab → cache hit → 302 redirect (< 2 ms total)
   API server: Redis miss → DB SELECT WHERE short_code='baaaaab'
               → SET url:baaaaab in Redis with TTL → 302 redirect
4. Async: publish click event to Kafka (fire-and-forget)
```

---

## 3. Component Deep-Dive

### 3.1 Short Code Generation

The short code is a **Base62-encoded integer**. Base62 uses the alphabet `a–z A–Z 0–9` (62 symbols). A 7-character Base62 string can represent 62^7 = 3,521,614,606,208 unique values — roughly 3.5 trillion — enough to outlast any realistic growth projection.

Choosing Base62 over Base64 is deliberate: Base64 adds `+` and `/` characters that require URL percent-encoding (`%2B`, `%2F`), making short URLs visually noisy and error-prone when copied. Base62 uses only alphanumeric characters and is safe in any URL context without encoding.

**Three approaches:**

| Approach | Mechanism | Pros | Cons |
|---|---|---|---|
| **Snowflake ID → Base62** | 64-bit ID from timestamp + datacenter + sequence | Distributed-safe, sortable, no collision | Needs a coordination service |
| **UUID → Base62** | 128-bit random UUID, truncate to 62 chars | Truly distributed, no coordination | Truncated UUID has collision risk; not sortable |
| **Counter → Base62** | Global atomic counter in Redis or Zookeeper | Simple, guaranteed unique | SPOF if counter service fails; reveals scale |

The recommended approach is **Snowflake-style ID → Base62**. The 64-bit Snowflake layout is: `[timestamp_ms: 41 bits][datacenter_id: 5 bits][worker_id: 5 bits][sequence: 12 bits]`. This gives 4096 IDs/ms/worker before waiting for the next millisecond — well above the 10K/sec requirement.

**Offset trick:** Starting the counter at 62^6 (56,800,235,584) ensures every encoded ID is at minimum 7 characters, giving all users consistently formatted short codes.

**Clock skew:** The Snowflake generator must handle the case where the system clock moves backward (NTP correction). The standard approach is to wait until the clock catches up to the last-seen timestamp before issuing new IDs. For large backward jumps (> 5 ms), the generator should return an error and let the caller retry — brief write latency is preferable to duplicate IDs.

### 3.2 Database Schema

```sql
CREATE TABLE urls (
    id          BIGINT          NOT NULL,
    short_code  VARCHAR(8)      NOT NULL,
    long_url    TEXT            NOT NULL,
    user_id     BIGINT,
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMP,
    click_count BIGINT          NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_short_code (short_code)
);
```

**Sharding strategy:** The table is sharded horizontally by `short_code` hash across N MySQL shards. The `idx_short_code` index is local to each shard. All reads (redirects) supply the short code, so a single shard lookup is deterministic: `shard = fnv32(short_code) % num_shards`.

`click_count` is updated asynchronously by the analytics consumer — it is never incremented on the redirect path.

**Index considerations:** The `UNIQUE INDEX` on `short_code` is the most accessed index and must fit in the buffer pool. At 100M rows, with 8 bytes per index entry plus B-tree overhead, the index is approximately 2–3 GB — small enough to keep entirely in memory on modern hardware.

**Soft deletes:** Rather than `DELETE` rows when a URL expires or is user-deleted, add a `deleted_at TIMESTAMP` column and filter in queries. This preserves audit history and avoids index churn from physical deletes.

### 3.3 Redirect Flow

Two HTTP redirect status codes are in play:

| Code | Name | Browser behaviour | Analytics impact |
|---|---|---|---|
| **301** | Permanent Redirect | Browser caches the redirect — future visits skip the server entirely | Click counts undercount; good for CDN caching |
| **302** | Temporary (Found) | Browser always hits the server to re-check | Accurate click counts; higher server load |

**When to use 301:** Static branded links where accuracy of analytics is less important than latency. The CDN can also cache the 301 response, effectively making the redirect free at scale.

**When to use 302:** Any link where analytics matter (marketing campaigns, A/B tests, expiry enforcement). The redirect hits the API server every time, recording a click event.

Many production systems default to 302 and offer 301 as a premium option for power users who want edge-cached redirects.

### 3.4 Redis Cache

The cache is the single most impactful latency optimization in the system. Without it, every redirect incurs a cross-network DB query (5–20 ms); with it, 80% of traffic is served in under 1 ms from local memory.

The cache uses a **cache-aside** (lazy loading) pattern:

1. Incoming request supplies `short_code`.
2. API server checks Redis key `url:{short_code}`.
3. **Cache hit** — return `long_url` from Redis and respond with redirect. Typical path < 1 ms.
4. **Cache miss** — query the DB shard, store result in Redis with TTL, then respond.

**TTL policy:** `TTL = min(url.expires_at − now, 24h)`. URLs with no expiry get a 24-hour TTL; expired URLs are not cached (a 410 response is returned without caching).

**Eviction:** Redis is configured with `maxmemory-policy allkeys-lru`. Given a 4 GB budget for 20M entries (≈ 200 bytes each), eviction is rare for the hot working set.

**Key format:** `url:{short_code}` → `long_url` (plain string value; no JSON overhead needed for the redirect fast path).

**Cache warming:** On service startup, pre-populate Redis with the top-N most-clicked URLs from the analytics DB. This avoids a cold-cache thundering herd the first time a freshly deployed node begins serving traffic. The top-N list can be pre-computed offline (e.g., a daily batch job) and written to Redis by the deployment pipeline.

### 3.5 Custom Aliases

Custom aliases share the same `short_code` namespace as system-generated codes. This means:

- Before accepting a custom alias, the system checks that the code is not already taken (a `SELECT` on `idx_short_code`).
- Custom aliases are **reserved** on the same `urls` table; no separate table avoids cross-table consistency problems.
- **Rate limiting:** alias creation is rate-limited per user (e.g., 10 custom aliases/day) to prevent enumeration attacks.
- **Profanity / brand protection filter:** a block-list of reserved codes (profanity, competitor brand names, system reserved paths like `api`, `admin`, `health`) is checked before insertion.

Collision resolution: if the requested alias is taken, the API returns HTTP 409 Conflict. The client is responsible for choosing an alternative.

**Alias length policy:** Custom aliases are allowed up to 32 characters (VARCHAR(32)), but the system-generated short codes are always 7 characters. This means clients can distinguish system codes from custom aliases by length. Custom aliases are stored in the same `urls` table — the `short_code` column simply holds the alias string verbatim.

**Namespace exhaustion attack:** A malicious user could systematically register all 7-character Base62 codes (3.5 trillion — not realistic) or all English words (more feasible). Mitigation: enforce per-user alias creation limits, charge credits for custom aliases, and maintain an allowlist of approved namespace prefixes for enterprise users.

### 3.6 Analytics Pipeline

Click events must not block the redirect response. The architecture is:

1. **Fire-and-forget publish:** the API server publishes `{short_code, timestamp, referrer, user_agent}` to a Kafka topic (`url.clicks`) with `acks=1` (no blocking for full replication).
2. **Kafka consumer group:** consumers read from `url.clicks`, batch events per short code, and upsert aggregated counts into ClickDB every 10 seconds.
3. **ClickDB:** ClickHouse (for high-write analytical workloads) or DynamoDB (for simpler ops). Stores per-day counts; total count is the sum of day-level rows.
4. **Consistency:** click counts in the `urls.click_count` column are updated by the consumer, not by the API server. Count lag is at most one consumer flush interval (≈ 10 s).

This decouples the latency-sensitive redirect path from the throughput-sensitive analytics path entirely.

**Backpressure handling:** If Kafka is slow to accept (consumer lag spiking, broker overloaded), the API server must not block. Configure the Kafka producer with `max.block.ms=100` so the `send()` call times out quickly. On timeout, log the dropped click event as a metric — it is better to undercount clicks than to increase redirect latency. At 100K redirects/sec with very rare Kafka timeouts, the count error is statistically negligible.

---

## 4. Key Algorithms

### 4.1 Rust — Base62 Encoder/Decoder + Short Code Generator

```rust
// Base62 encoder/decoder + collision-resistant ID generator
// Uses: a counter + ID_OFFSET to guarantee 7-char output
// Compile: rustc --edition 2024 sd02_url_shortener.rs
use std::collections::HashMap;

const BASE62_CHARS: &[u8] =
    b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const BASE: u64 = 62;
// 62^6 = 56_800_235_584; any id >= this value encodes to >= 7 chars.
const ID_OFFSET: u64 = 56_800_235_584;

fn encode_base62(id: u64) -> String {
    if id == 0 {
        return "a".to_string();
    }
    let mut n = id;
    let mut chars = Vec::new();
    while n > 0 {
        chars.push(BASE62_CHARS[(n % BASE) as usize]);
        n /= BASE;
    }
    chars.reverse();
    String::from_utf8(chars).expect("valid ascii")
}

fn decode_base62(s: &str) -> u64 {
    s.bytes().fold(0u64, |acc, b| {
        let digit = match b {
            b'a'..=b'z' => (b - b'a') as u64,
            b'A'..=b'Z' => (b - b'A') as u64 + 26,
            b'0'..=b'9' => (b - b'0') as u64 + 52,
            _ => panic!("invalid base62 char: {}", b as char),
        };
        acc * BASE + digit
    })
}

/// Generates a 7-character short code by advancing a counter past ID_OFFSET.
/// In production the counter would be a globally-coordinated Snowflake ID.
fn generate_short_code(counter: &mut u64) -> String {
    *counter += 1;
    let id = ID_OFFSET + *counter;
    let code = encode_base62(id);
    // Pad with leading 'a' (digit 0) if under 7 chars; truncate if over.
    if code.len() < 7 {
        format!("{:a>7}", code)
    } else {
        code[..7].to_string()
    }
}

fn main() {
    // Round-trip: encode then decode must recover original value.
    for &n in &[0u64, 1, 61, 62, 3_521_614_606_207u64] {
        let encoded = encode_base62(n);
        let decoded = decode_base62(&encoded);
        if decoded != n {
            panic!("round-trip failed for {}: encoded='{}', decoded={}", n, encoded, decoded);
        }
    }
    println!("round-trip: OK");

    // All generated codes must be exactly 7 characters.
    let mut counter: u64 = 0;
    for _ in 0..5 {
        let code = generate_short_code(&mut counter);
        if code.len() != 7 {
            panic!("expected 7-char code, got '{}' (len={})", code, code.len());
        }
    }
    println!("length=7: OK");

    // Uniqueness: 100 consecutive calls must produce 100 distinct codes.
    let mut counter2: u64 = 0;
    let mut seen: HashMap<String, u64> = HashMap::new();
    for i in 0..100u64 {
        let code = generate_short_code(&mut counter2);
        if let Some(prev) = seen.get(&code) {
            panic!("collision: code '{}' at call {} and {}", code, prev, i);
        }
        seen.insert(code, i);
    }
    println!("uniqueness (100 calls): OK");

    // Sample output.
    let mut demo: u64 = 0;
    let samples: Vec<String> = (0..5).map(|_| generate_short_code(&mut demo)).collect();
    println!("sample codes: {:?}", samples);
}
```

**Key points:**
- `ID_OFFSET = 62^6` guarantees all generated IDs encode to at least 7 characters. Without the offset, the first ID encodes to `"b"` (1 character), growing slowly to 7 chars only after 62^6 URLs — a confusing user experience.
- The `decode_base62` function is the exact inverse; `encode → decode` is a round-trip identity. This property is essential for testing and for any admin tool that needs to recover the numeric ID from a short code (e.g., to find the DB row without a full index scan).
- `HashMap` for the uniqueness check ensures O(1) average collision detection. In production the equivalent is the `UNIQUE INDEX` on `short_code` in the database — a DB-level constraint that fires on the second writer, not the application.
- `u64` wrapping arithmetic is safe: with a 64-bit counter starting at 56 billion, overflow would require generating 1.8 × 10^19 URLs — roughly 58 million years at the 10K writes/sec design rate.
- The `generate_short_code` function's truncation to 7 characters (`code[..7]`) is safe because `ID_OFFSET + 1` encodes to exactly 7 characters, and the counter cannot produce an 8-character code until `ID_OFFSET + 62^7` — 3.5 trillion URLs later.

### 4.2 Java — Base62 Encoder/Decoder + Short Code Generator

```java
import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;

public class UrlShortener {
    private static final String BASE62_CHARS =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    private static final long BASE = 62L;
    // 62^6 = 56_800_235_584L; any id >= this encodes to >= 7 chars.
    private static final long ID_OFFSET = 56_800_235_584L;

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static String encodeBase62(long id) {
        if (id == 0) return "a";
        StringBuilder sb = new StringBuilder();
        long n = id;
        while (n > 0) {
            sb.append(BASE62_CHARS.charAt((int)(n % BASE)));
            n /= BASE;
        }
        return sb.reverse().toString();
    }

    public static long decodeBase62(String s) {
        long result = 0;
        for (char c : s.toCharArray()) {
            int digit;
            if (c >= 'a' && c <= 'z') {
                digit = c - 'a';
            } else if (c >= 'A' && c <= 'Z') {
                digit = c - 'A' + 26;
            } else if (c >= '0' && c <= '9') {
                digit = c - '0' + 52;
            } else {
                throw new IllegalArgumentException("Invalid base62 char: " + c);
            }
            result = result * BASE + digit;
        }
        return result;
    }

    /**
     * Generates a 7-character short code. counter[0] is a mutable long.
     * In production this would be a Snowflake-style globally-coordinated ID.
     */
    public static String generateShortCode(long[] counter) {
        counter[0]++;
        long id = ID_OFFSET + counter[0];
        String code = encodeBase62(id);
        if (code.length() < 7) {
            // Pad with leading 'a' (digit 0) to reach 7 chars.
            StringBuilder sb = new StringBuilder();
            for (int i = code.length(); i < 7; i++) sb.append('a');
            sb.append(code);
            return sb.toString();
        }
        return code.substring(0, 7);
    }

    public static void main(String[] args) {
        // Round-trip test.
        long[] roundTripCases = {0L, 1L, 61L, 62L, 3_521_614_606_207L};
        for (long n : roundTripCases) {
            String encoded = encodeBase62(n);
            long decoded = decodeBase62(encoded);
            check(decoded == n,
                "Round-trip failed for " + n + ": encoded='" + encoded
                + "', decoded=" + decoded);
        }
        System.out.println("round-trip: OK");

        // All generated codes must be exactly 7 characters.
        long[] counter = {0L};
        for (int i = 0; i < 5; i++) {
            String code = generateShortCode(counter);
            check(code.length() == 7,
                "Expected 7-char code, got '" + code + "' (len=" + code.length() + ")");
        }
        System.out.println("length=7: OK");

        // Uniqueness: 100 consecutive calls produce 100 distinct codes.
        long[] counter2 = {0L};
        HashMap<String, Integer> seen = new HashMap<>();
        for (int i = 0; i < 100; i++) {
            String code = generateShortCode(counter2);
            check(!seen.containsKey(code),
                "Collision: code '" + code + "' at call " + seen.get(code) + " and " + i);
            seen.put(code, i);
        }
        System.out.println("uniqueness (100 calls): OK");

        // Sample output.
        long[] demo = {0L};
        List<String> samples = new ArrayList<>();
        for (int i = 0; i < 5; i++) samples.add(generateShortCode(demo));
        System.out.println("sample codes: " + samples);
    }
}
```

**Key differences from Rust:**
- `long[]` counter simulates a mutable out-parameter (Java has no `&mut`). The `counter[0]++` idiom is idiomatic for this pattern in Java; a `AtomicLong` would be the production choice for thread-safety.
- `StringBuilder.reverse()` eliminates the manual `chars.reverse()` step needed in Rust. Java's `StringBuilder` mutates in place; Rust's `Vec<u8>` is equivalent but explicit.
- The `check()` helper replaces `assert` (disabled by default in Java) with a hard `AssertionError`. Java's `assert` keyword requires the JVM flag `-ea` to have any effect — a footgun that has caused many developers to ship code they believed was protected by assertions.
- `long` in Java is always signed. The decode loop multiplies `result * BASE` repeatedly; for inputs near `Long.MAX_VALUE / 62`, this could overflow. In practice the 7-char limit on short codes means the maximum decodeable value is 62^7 - 1 ≈ 3.5 × 10^12, well within `long`'s range (9.2 × 10^18). Rust's `u64` makes unsigned semantics explicit.

---

## 5. Tradeoffs

### 5.1 Short Code Generation Strategy

| Strategy | Uniqueness | Predictability | Collision Risk | Distributed-friendly | Sortable |
|---|---|---|---|---|---|
| **Snowflake ID → Base62** | Guaranteed | Low (timestamp-based) | None | Yes (worker IDs) | Yes |
| **UUID → Base62** | High | None | Negligible (128-bit) | Yes (no coordination) | No |
| **Counter → Base62** | Guaranteed | High (sequential) | None | No (central state) | Yes |
| **Hash (MD5/SHA) → Base62** | High (truncated) | None | Small but non-zero | Yes | No |

**Snowflake ID** is the best fit for this system: it is distributed-safe, collision-free, and the timestamp component makes IDs loosely sortable by creation time (useful for debugging and range scans).

**UUID** works if you are comfortable with the complexity of truncation. Truncating a 128-bit UUID to 7 Base62 chars reduces the space to 62^7 = 3.5 trillion, giving a birthday-problem collision at ~1.87 million URLs (for 1% collision probability) — far too low for 100M URLs.

**Counter** is the simplest but introduces a single point of failure. Flickr-style ticket servers (two alternating counters: one on even IDs, one on odd IDs) partially mitigate this.

### 5.2 Redirect Type: 301 vs 302

| Aspect | 301 Permanent | 302 Temporary |
|---|---|---|
| Browser caches | Yes — future visits bypass server | No — every visit hits server |
| CDN cacheable | Yes | Generally no |
| Click accuracy | Undercounts (cached visits invisible) | Accurate (every visit recorded) |
| Server load | Lower after first visit | Higher (every redirect hits API) |
| TTL / expiry enforcement | Unreliable (client may use cached redirect) | Reliable |

**Recommendation:** default to 302; expose 301 as a user-selectable option with a clear warning that analytics will be incomplete.

### 5.3 DB Sharding: Hash vs Range

| Strategy | Hot-key risk | Range scans | Rebalancing cost |
|---|---|---|---|
| **Hash-based** (FNV/MD5 mod N) | Low | Impossible | High (full resharding) |
| **Range-based** | High (sequential IDs cluster) | Easy | Low (split one shard) |
| **Consistent hashing** | Low | Hard | Low (move 1/N of keys) |

For this write-heavy workload, **consistent hashing** is preferred: adding a shard moves only keys that previously mapped to the new shard's predecessor, not 100% of the data.

### 5.4 Redis vs No Cache

Without Redis, 100K reads/sec hit the DB directly. Even with 10 shards that is 10K reads/sec per shard — achievable, but with higher latency (5–20 ms for a DB query vs < 1 ms for Redis). With cache serving 80% of traffic, DB load drops to 20K reads/sec total — a 5× reduction that also reduces tail latency significantly.

The 4 GB cache fits comfortably in a single Redis instance and can be replicated for high availability.

**Redis Cluster vs single node:** A single Redis primary with one replica handles this load easily (Redis is single-threaded for commands but handles 1M+ simple get/set ops/sec). A Redis Cluster (16384 hash slots, minimum 3 primary nodes) is warranted only if the cache working set exceeds the RAM of a single node (e.g., > 256 GB). At 4 GB, single-node Redis is the right choice — avoid the added operational complexity of a cluster until you need it.

### 5.5 Analytics: Synchronous vs Asynchronous

Counting clicks synchronously — incrementing `click_count` in the same DB transaction as the redirect — is tempting for simplicity but breaks the latency budget:

- One DB write per redirect × 100K redirects/sec = 100K additional DB writes/sec — this saturates MySQL long before the read capacity.
- Write amplification: each increment causes a B-tree page split and WAL entry, slowing down reads on the same table.

The async Kafka approach trades strict consistency for throughput. Click counts lag by at most one consumer batch interval (10 s) — acceptable for every known analytics use case in URL shortening (daily/hourly reports, campaign dashboards).

---

## 6. Failure Modes

### 6.1 Short Code Collision

**Risk:** Two concurrent requests generate the same short code before either is written to the DB.

**Mitigation:** The `UNIQUE INDEX idx_short_code` on the DB table makes the second writer receive a duplicate-key error, triggering a retry with the next ID. With Snowflake IDs this is impossible by construction (each worker maintains a monotonic sequence within its allocated ID space). With counter-based or UUID approaches, the retry path must be explicitly coded.

**Birthday problem math:** For hash-based codes (truncated random), the probability of at least one collision among N codes of length L (Base62) is approximately:

```
P(collision) ≈ 1 - e^(−N² / (2 × 62^L))
For L=7, 62^7 ≈ 3.52 × 10^12
For N=100M URLs: P ≈ 1 - e^(−10^16 / (7 × 10^12)) ≈ 1 - e^(−1430) ≈ 100%
```

This confirms that random hash truncation to 7 chars fails badly at 100M scale — you **must** use a guaranteed-unique ID scheme (Snowflake or counter).

### 6.2 DB Shard Hotspot

**Risk:** A viral URL's reads all hit the same shard (since short code → shard is deterministic). One shard saturates while others are idle.

**Mitigation:**
1. **Read replicas per shard** — route reads to replicas, writes to primary. Scales reads independently.
2. **Redis absorbs hot reads** — a viral URL will be in cache; its shard sees minimal load.
3. **Consistent hashing within shard range** — if shard imbalance persists, split the hot shard; consistent hashing ensures only its key range migrates.

### 6.3 Cache Thundering Herd

**Risk:** A popular short code expires from cache simultaneously. Hundreds of concurrent requests all miss cache and simultaneously query the DB.

**Mitigation:**

- **Mutex lock per key:** the first thread to detect a cache miss acquires a per-key lock, fetches from DB, populates cache. Other threads wait on the lock. Reduces DB fan-out from N requests to 1. The lock is an in-process `Mutex<HashMap<ShortCode, Pending>>` — not a Redis distributed lock — to avoid adding a round trip.
- **Probabilistic early expiry (PER):** recalculate whether to refresh the cache before the TTL expires, with a probability that increases as TTL approaches zero. Described by Vattani et al. (2015). Prevents the hard thundering herd by spreading out refresh requests in time.
- **Staggered TTLs:** add random jitter to TTLs on cache write (e.g., base TTL ± 10%). This prevents batch-loaded cache entries — such as those written during cache warming — from all expiring at the same instant. For 1 million entries warmed at service start, a ±10% jitter on a 24h TTL spreads expirations across a 4.8-hour window instead of a single second.

### 6.4 Malicious URL Abuse

**Risk:** Bad actors shorten malware distribution URLs, phishing pages, or CSAM links. The service becomes an unwitting accomplice in attack campaigns — and is blacklisted by spam filters, breaking all legitimate links too.

**Mitigation:**

- **Safe Browsing API check at write time:** before persisting a new URL, query Google Safe Browsing (or Cloudflare's feed) with the destination URL. Reject URLs flagged as malicious. Latency cost: 10–50 ms per write — acceptable for the write path (target: < 50 ms p99).
- **Async re-scanning:** Safe Browsing lists update continuously. A background job re-scans stored URLs on a daily schedule, marking and redirecting flagged URLs to a warning page.
- **Abuse reporting:** provide a `POST /report/{short_code}` endpoint. After N independent reports (e.g., 3), soft-delete the URL pending manual review.
- **Rate limits on anonymous writes:** unauthenticated users can create at most 10 short URLs per hour per IP. Authenticated users get 10,000/hour. This makes bulk abuse economically costly.

### 6.5 ID Generator Service SPOF

**Risk:** The Snowflake generator service crashes — all writes block.

**Mitigation:**

- Run N generator nodes with **non-overlapping ID ranges** (Flickr ticket server approach): node 1 auto-increments by step N starting at 1, node 2 starts at 2, etc.
- Clients round-robin across generators. Failure of one generator is transparent because the others continue from their own sequences.
- Zookeeper or etcd can coordinate worker-ID assignment, preventing two nodes from claiming the same worker ID after a restart.
- **Pre-allocated ID blocks:** each API server can request a block of 10,000 IDs from the generator in a single call, caching them locally. This reduces generator RPC calls by 10,000× and allows the API server to continue generating IDs for several seconds even if the generator is temporarily unreachable. The trade-off: if the API server crashes, the unused IDs in its local block are wasted — a gap in the ID sequence. Gaps do not matter here because short codes are Base62-encoded IDs, not sequential user-visible numbers.

---

## 7. Java vs Rust

| Aspect | Java | Rust |
|---|---|---|
| **String formatting** | `String.format("%s-%d", server, i)` or `StringBuilder` | `format!("{}-{}", server, i)` — zero-cost at runtime when inlined |
| **HashMap** | `java.util.HashMap<K,V>` — boxing required for primitives | `std::collections::HashMap<K,V>` — no boxing; `u64` stored inline |
| **u64 overflow** | `long` silently wraps (two's complement) | Debug build panics on overflow; release build wraps — catches bugs in development |
| **Cache miss handling** | `Optional<String>` or `null` return from `Map.get()` | `Option<&str>` — must be explicitly handled; compiler enforces it |
| **Mutable reference** | Pass `long[]` as a workaround for mutable `long` | Native `&mut u64` — borrow checker ensures no aliasing |
| **Immutable string slices** | `String` vs `String` (always heap-allocated) | `&str` (borrowed slice, zero-copy) vs `String` (owned heap) — distinction explicit in type system |
| **Error handling** | `IllegalArgumentException` thrown and caught | `panic!` in prototypes; `Result<T, E>` in production Rust |

The most important practical difference: Rust's borrow checker forces the programmer to be explicit about whether a function borrows or owns its data. In the `generate_short_code` function, `&mut u64` makes it obvious the counter is mutated in place. Java's `long[]` hack achieves the same effect with no type-system enforcement — a team convention rather than a compiler guarantee.

Rust's `u64` overflow protection in debug mode is also a meaningful difference: the ID_OFFSET + counter addition would panic in debug before silently wrapping and generating a duplicate code, catching a latent bug during development that Java would mask until production.

**Production implications:** In a real URL shortener service, the Rust version's `Option<&str>` return from cache lookup forces the caller to handle the miss case at compile time. A Java developer can accidentally use the `null` result from `Map.get()` without a null check — a NullPointerException in production. Rust's type system eliminates this entire class of bug. This is not a theoretical difference: null-related bugs account for a measurable fraction of production incidents in Java services, and the cost of their elimination in Rust is the upfront verbosity of `if let Some(v) = ...` or `.unwrap_or_else(...)`.

---

## Summary

The table below consolidates every design decision in one place for quick reference during interview discussion.

| Design decision | Choice | Rationale |
|---|---|---|
| Short code length | 7 chars (Base62) | 3.5 trillion codes, URL-safe alphabet |
| ID generation | Snowflake-like (timestamp + worker + seq) | Distributed-safe, collision-free, sortable |
| Storage engine | MySQL / Postgres sharded | ACID, mature tooling, schema flexibility |
| Sharding key | `short_code` hash | Deterministic shard routing, even distribution |
| Cache | Redis (cache-aside, LRU, 4 GB) | 80% cache hit rate, < 1 ms redirect fast path |
| Redirect type | 302 default, 301 optional | Accurate analytics by default; edge caching opt-in |
| Analytics | Kafka → ClickDB (async) | Non-blocking redirect path, eventual consistency |
| Failure isolation | Read replicas, consistent hashing, PER cache | No single point of failure in read path |
| Abuse prevention | Safe Browsing API + rate limiting + soft deletes | Block malicious URLs without data loss |
