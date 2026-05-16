# Chapter 1: Rate Limiter

> **Chapter goal:** Design and implement a production-grade rate limiter — token bucket, sliding window, and fixed window — with distributed coordination strategy.
> Code snippets are self-contained and compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A rate limiter is a traffic control mechanism that enforces a cap on how many requests a client — identified by user ID, IP address, API key, or endpoint — may make within a defined time window. When a client exceeds its quota the limiter returns HTTP **429 Too Many Requests** and stops the request from reaching the backend.

The system must satisfy the following functional requirements:

- **Per-identity limiting** — enforce limits keyed on user ID, IP address, API key, or any combination. The same infrastructure handles all three without redesign.
- **Multiple algorithms** — support token bucket, sliding window counter, and fixed window counter. Different APIs may require different burst characteristics.
- **Return 429 on excess** — denied requests receive HTTP 429 with `Retry-After` and `X-RateLimit-*` headers so clients can back off gracefully.
- **Distributed enforcement** — limits are shared across all API gateway nodes. A user exhausting their quota on node A is also blocked on node B.
- **Multiple rule sets** — operators configure different limits per endpoint, per tier (free vs paid), or per geographic region. Up to ~10 concurrent rule dimensions are expected initially.
- **Hot reload of rules** — rule changes take effect without restarting any process. Maximum propagation delay: 30 seconds.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Latency overhead per request | < 1 ms p99 (excluding network to Redis) |
| Availability of rate-limiter service | 99.99% (< 52 min/year downtime) |
| Horizontal scalability | Linear; adding nodes does not increase per-node load |
| Consistency model | Eventually consistent within a node's local window; strictly consistent for distributed enforcement via Redis |
| Durability of counters | Not required — a Redis restart resets counters; temporary excess traffic is acceptable |
| Observability | Emit per-rule allowed/denied counters, latency histograms to metrics pipeline |

### 1.3 Scale Estimates

| Dimension | Estimate |
|---|---|
| Total users | 10 million |
| Peak RPS across all endpoints | 100,000 |
| Average RPS per user | 0.01 (very sparse) |
| Active users in any 1-minute window | ~60,000 |
| Rate-limit rules configured | ~10 distinct rule sets |
| Redis key space | One key per (user, rule) pair; ~600,000 active keys at any instant |

**Storage per user — fixed window example:**

A fixed-window counter stores a single integer plus a TTL per (user, rule) key. Redis overhead per key (value + metadata) is approximately 64 bytes. With 60,000 active users and 10 rules, totaling ~600,000 active keys:

```
60,000 users × 10 rules × 64 bytes ≈ 38 MB
```

That fits comfortably in a single Redis node with gigabytes of RAM. Even at 10 million simultaneous active users the total is under 7 GB — well within a modest Redis cluster.

**Storage per user — sliding window log example:**

The sliding window log approach stores one timestamp per request in a sorted set or in-memory `VecDeque`. At 100 req/sec limit per user, each timestamp is 8 bytes:

```
100 timestamps × 8 bytes = 800 bytes per user per rule
60,000 users × 10 rules × 800 bytes ≈ 480 MB
```

This is 12× more than the counter approach and grows with the per-user request rate, making it unsuitable for high-burst tiers without bounding the log size.

**Request budget per node:**

With 100,000 RPS spread across 10 gateway nodes, each node handles ~10,000 RPS. The rate-limiter code path must complete in under 100 µs per request on average to leave headroom for the < 1 ms p99 budget (network RTT to Redis on a well-tuned local cluster is ~200–500 µs, so local in-process checks and Lua-based atomic Redis operations must be as fast as possible).

---

## 2. High-Level Architecture

```
                        ┌─────────────────────────────────────────────────────┐
                        │                API Gateway Cluster                  │
                        │                                                     │
   Client               │  ┌──────────┐   ┌──────────┐   ┌──────────┐       │
  ────────►  Load  ─────┼─►│  Node A  │   │  Node B  │   │  Node C  │       │
            Balancer     │  │          │   │          │   │          │       │
                        │  │ Rate     │   │ Rate     │   │ Rate     │       │
                        │  │ Limiter  │   │ Limiter  │   │ Limiter  │       │
                        │  │ (local   │   │ (local   │   │ (local   │       │
                        │  │  cache)  │   │  cache)  │   │  cache)  │       │
                        │  └────┬─────┘   └────┬─────┘   └────┬─────┘       │
                        │       │               │               │             │
                        └───────┼───────────────┼───────────────┼─────────────┘
                                │               │               │
                                └───────┬───────┘───────────────┘
                                        │  (Redis RESP3 protocol)
                                        ▼
                        ┌───────────────────────────────────┐
                        │         Redis Cluster             │
                        │  ┌──────────┐  ┌──────────┐      │
                        │  │ Shard 0  │  │ Shard 1  │ ...  │
                        │  │ counters │  │ counters │      │
                        │  └──────────┘  └──────────┘      │
                        └───────────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────────┐
                        │       Config Service              │
                        │  (rule definitions, TTLs,         │
                        │   algorithm per endpoint)         │
                        │   pushed to gateway nodes         │
                        │   via pub/sub or polling          │
                        └───────────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────────┐
                        │       Backend Services            │
                        │  (only receives allowed requests) │
                        └───────────────────────────────────┘
```

**Component responsibilities:**

| Component | Holds State? | Purpose |
|---|---|---|
| Load Balancer | No | Routes requests; unaware of rate limits |
| API Gateway Node | Yes (local rule cache, optional short-lived local counter) | Applies rate limit; calls Redis for distributed check |
| Redis Cluster | Yes (counters, TTLs) | Source of truth for distributed counters; enforces atomicity via Lua |
| Config Service | Yes (rule definitions) | Stores and broadcasts rate-limit rules; supports versioning and hot reload |
| Backend Services | Application state only | Never receives requests that exceed the rate limit |

**Request flow:**

1. Client sends request to Load Balancer.
2. Load Balancer forwards to an API Gateway Node (round-robin or least-connections).
3. Gateway Node reads the applicable rule from its local cache (updated by Config Service).
4. Gateway Node runs a Lua script on Redis to atomically increment the counter and check the limit.
5. If Redis returns "allowed", the request proceeds to Backend Services and the response includes `X-RateLimit-*` headers.
6. If Redis returns "denied", the gateway returns HTTP 429 immediately, without touching the backend.
7. Config Service periodically pushes updated rules via pub/sub; gateway nodes apply new rules within 30 seconds.

---

## 3. Component Deep-Dive

### 3.1 Token Bucket

The token bucket algorithm models a bucket that fills at a constant rate up to a maximum capacity. Each incoming request consumes one token. If the bucket has at least one token the request is allowed and that token is removed. If the bucket is empty the request is denied.

**Refill mechanics:** Rather than running a background goroutine or timer thread, the refill is computed lazily on every request. The implementation records the timestamp of the last refill and, on the next call to `is_allowed`, calculates how many tokens have accumulated since then based on the configured rate. This approach is lock-friendly — the only shared state is the token count and the last-refill timestamp, both of which can be updated atomically or under a lightweight mutex.

**Burst handling:** The bucket capacity acts as a burst ceiling. A user who has been idle for several seconds accumulates tokens up to the capacity cap, not beyond it. This makes token bucket ideal for endpoints that expect bursty but bounded traffic, such as a search endpoint where users may submit several queries rapidly after a period of inactivity.

**When to use:** Token bucket is the most forgiving algorithm for legitimate bursts. Choose it when your clients have heterogeneous access patterns and you want to allow short bursts without penalizing overall throughput. It is the dominant choice for public APIs (GitHub, Stripe, Twilio all use variants of it).

**Distributed consideration:** In a distributed deployment, the token state must live in Redis rather than in memory. Use a Lua script that reads the current token count and last-refill timestamp, calculates the new token count, subtracts one if allowed, and writes both values back — all in one atomic operation. Redis pipelines can batch the read and write to reduce round-trips.

### 3.2 Sliding Window Counter

The sliding window counter is a hybrid between an exact log and a coarse counter. The simplest form, the **sliding window log**, stores a timestamp for every request in the current window. On each new request the algorithm discards timestamps older than `now - window_duration`, then checks whether the remaining log length is below the limit. This gives mathematically exact enforcement with no boundary artifacts.

The downside of the pure log is memory: storing one timestamp per request per user can be prohibitive at high rates. The **sliding window counter hybrid** addresses this by dividing time into fixed buckets (e.g., 1-second sub-buckets within a 1-minute window) and keeping a count per bucket. The current window's rate is estimated as a weighted sum of the current and previous bucket counts. This trades a small amount of accuracy (~0.1% overcount at bucket boundaries) for dramatically reduced memory.

**Memory tradeoff:** For a 1-minute window at 100 req/sec, the pure log stores up to 6,000 timestamps × 8 bytes = 48 KB per user. The counter hybrid with 60 1-second buckets stores 60 × 4 bytes = 240 bytes per user — a 200× reduction.

**When to use:** Sliding window is the most accurate algorithm for enforcing "no more than N requests per window" without the boundary spike problem of fixed windows. It is preferred for billing-sensitive or abuse-prevention contexts. The counter hybrid is production-standard for high-traffic APIs at companies like Cloudflare and Figma.

### 3.3 Fixed Window Counter

The fixed window counter divides wall-clock time into non-overlapping windows (e.g., 00:00–01:00, 01:00–02:00). It maintains a single counter per (user, window) pair. Each request increments the counter; if the counter exceeds the limit the request is denied. At the start of a new window the counter resets to zero.

**Boundary spike problem:** The fundamental flaw is that a user can exhaust their quota at the very end of one window and immediately exhaust a fresh quota at the start of the next. In the worst case, a user issues `2 × limit` requests in a very short period straddling a window boundary. For a limit of 100 requests per minute, an adversary can send 100 requests at 00:59 and 100 more at 01:00, achieving 200 requests within two seconds.

**Mitigation strategies:**
- Use sliding window instead if the spike is unacceptable.
- Stagger window boundaries randomly per user so adversaries cannot time their bursts.
- Layer a token bucket on top to suppress instantaneous bursts regardless of window.
- Alert on anomalous request spikes at window boundaries in your metrics pipeline.

**When to use:** Fixed window is the cheapest algorithm — a single `INCR` + `EXPIRE` in Redis with no read before write. Use it where approximate enforcement is acceptable, the limit is high enough that the 2× boundary spike is tolerable, and you need maximum throughput from the rate-limiter code path itself.

### 3.4 Redis as Distributed Store

Redis is the standard distributed backing store for rate limiters because it is single-threaded (no write-write conflicts without Lua), supports atomic `INCR` with `EXPIRE`, provides sub-millisecond latency on the same LAN, and has native cluster mode for horizontal scaling.

**Lua scripts for atomicity:** Redis executes Lua scripts atomically — no other command can interleave with a running script. This is critical for the token bucket, where the read-modify-write of (tokens, last_refill) must be atomic. A sample Lua script for fixed-window:

```lua
local key   = KEYS[1]
local limit = tonumber(ARGV[1])
local ttl   = tonumber(ARGV[2])

local current = redis.call("INCR", key)
if current == 1 then
    redis.call("EXPIRE", key, ttl)
end
if current > limit then
    return 0  -- denied
end
return 1      -- allowed
```

This single script replaces a GET + conditional SET + EXPIRE race condition with one atomic operation.

**INCR + EXPIRE pattern:** For fixed window, the idiomatic Redis pattern is:
1. `INCR user:endpoint:window_id` — increment and get new value in one command.
2. If the returned value is 1 (first request in this window), set `EXPIRE` to the window duration. This avoids stale keys that never expire.
3. Compare the returned value to the limit.

Note that `INCR` followed by `EXPIRE` is a two-command sequence that is not atomic. The Lua wrapper above fixes this.

**Pipeline:** Redis pipelines batch multiple commands into a single network round-trip. For the sliding window log on Redis (using a sorted set: `ZADD`, `ZREMRANGEBYSCORE`, `ZCARD`, `EXPIRE`), pipeline the four commands together to reduce latency from 4 × RTT to 1 × RTT.

**Key design:** Use a structured key schema to avoid collisions and allow for efficient pattern-based management:

```
ratelimit:{user_id}:{rule_id}:{window_start_epoch}
```

Using Redis cluster hash tags (`{user_id}`) ensures all keys for a given user land on the same shard, enabling multi-key Lua scripts without cross-slot errors.

### 3.5 Rule Configuration Service

The Config Service is the control plane for rate-limit rules. It decouples rule management from enforcement and allows non-engineers to adjust limits without touching gateway code.

**Rule schema (example):**

```json
{
  "rule_id": "search-api-free-tier",
  "algorithm": "token_bucket",
  "limit": 10,
  "window_seconds": 60,
  "burst_capacity": 20,
  "key_extractor": "user_id",
  "endpoints": ["/api/v1/search"],
  "user_tiers": ["free"],
  "version": 42
}
```

**Hot reload:** Gateway nodes subscribe to a Redis pub/sub channel (`ratelimit.rule_updates`) or poll the Config Service REST endpoint every 10 seconds. On receiving an update, nodes replace their in-memory rule map with the new version. The swap is atomic from the perspective of in-flight requests: the node completes any in-progress limiter checks under the old rule before switching to the new one.

**Versioning:** Each rule carries a monotonically increasing `version`. If a node receives an update with a lower version than its current rule, it discards the update (handles out-of-order delivery from pub/sub). Nodes log version transitions for audit purposes.

**Consistency:** Rule propagation is eventually consistent. During the propagation window (up to 30 seconds), different gateway nodes may enforce slightly different limits. This is acceptable for rate limiting — a brief period where one node is stricter or more lenient than another does not constitute a correctness failure.

### 3.6 Client Headers

Well-designed rate limiters communicate their state to clients through response headers, enabling clients to implement adaptive backoff without guessing.

| Header | Meaning | Example |
|---|---|---|
| `X-RateLimit-Limit` | Maximum requests allowed in the current window | `100` |
| `X-RateLimit-Remaining` | Requests remaining in the current window | `34` |
| `X-RateLimit-Reset` | Unix timestamp (seconds) when the window resets | `1716854400` |
| `Retry-After` | Seconds to wait before retrying (on 429 responses only) | `17` |

**Implementation note:** `X-RateLimit-Remaining` and `X-RateLimit-Reset` should be computed from the authoritative Redis state returned by the Lua script, not approximated from a local counter. For token bucket, `Remaining` can be the floor of current tokens; `Reset` is the time at which one full token would be available given the current refill rate.

**RFC compliance:** `Retry-After` is defined in RFC 7231. Some clients (including many HTTP libraries) parse it automatically and handle 429 retry logic transparently. Always include both `Retry-After` (seconds) and `X-RateLimit-Reset` (epoch) for maximum compatibility.

---

## 4. Key Algorithms & Data Structures

### 4.1 Rust Implementation

The Rust implementation uses `std` only — no external crates. All three algorithms share a single `RateLimiter` struct with an `Algorithm` enum for dispatch. State mutation happens through `&mut self`, which models the single-threaded or mutex-protected use case. For multi-threaded production use, wrap in `Arc<Mutex<RateLimiter>>` (see Section 7).

```rust
use std::collections::VecDeque;
use std::time::{Duration, Instant};
use std::thread;

// ── Algorithm selector ────────────────────────────────────────────────────────
#[allow(dead_code)]
enum Algorithm {
    TokenBucket,
    SlidingWindow,
    FixedWindow,
}

// ── Per-algorithm state ───────────────────────────────────────────────────────
struct RateLimiter {
    algorithm: Algorithm,
    limit: u32,
    window: Duration,
    // Token Bucket fields
    tokens: f64,
    last_refill: Instant,
    // Sliding Window fields
    log: VecDeque<Instant>,
    // Fixed Window fields
    counter: u32,
    window_start: Instant,
}

impl RateLimiter {
    fn new(algorithm: Algorithm, limit: u32, window: Duration) -> Self {
        let now = Instant::now();
        RateLimiter {
            algorithm,
            limit,
            window,
            // Token Bucket: start full
            tokens: limit as f64,
            last_refill: now,
            // Sliding Window: empty log
            log: VecDeque::new(),
            // Fixed Window: counter at zero
            counter: 0,
            window_start: now,
        }
    }

    fn is_allowed(&mut self) -> bool {
        let now = Instant::now();
        match self.algorithm {
            Algorithm::TokenBucket => {
                // Refill tokens based on elapsed time
                let elapsed = now.duration_since(self.last_refill).as_secs_f64();
                let refill_rate = self.limit as f64 / self.window.as_secs_f64();
                self.tokens = (self.tokens + elapsed * refill_rate).min(self.limit as f64);
                self.last_refill = now;

                if self.tokens >= 1.0 {
                    self.tokens -= 1.0;
                    true
                } else {
                    false
                }
            }
            Algorithm::SlidingWindow => {
                // Evict entries outside the window first, then check
                let cutoff = now - self.window;
                while let Some(&front) = self.log.front() {
                    if front <= cutoff {
                        self.log.pop_front();
                    } else {
                        break;
                    }
                }
                if self.log.len() < self.limit as usize {
                    self.log.push_back(now);
                    true
                } else {
                    false
                }
            }
            Algorithm::FixedWindow => {
                // Roll the window if expired
                if now.duration_since(self.window_start) >= self.window {
                    self.window_start = now;
                    self.counter = 0;
                }
                if self.counter < self.limit {
                    self.counter += 1;
                    true
                } else {
                    false
                }
            }
        }
    }
}

fn main() {
    // ── Token Bucket: 5 tokens per 200ms window, burst of 5 ──────────────────
    let mut tb = RateLimiter::new(
        Algorithm::TokenBucket,
        5,
        Duration::from_millis(200),
    );
    // Burst: all 5 tokens consumed immediately
    let mut allowed = 0u32;
    for _ in 0..5 {
        if tb.is_allowed() { allowed += 1; }
    }
    assert!(allowed == 5, "TokenBucket burst: expected 5 allowed, got {}", allowed);
    // 6th request denied — bucket empty
    assert!(!tb.is_allowed(), "TokenBucket: 6th request should be denied");
    // Wait for refill (window=200ms → rate=25 tokens/sec; 250ms → ~6 tokens)
    thread::sleep(Duration::from_millis(250));
    assert!(tb.is_allowed(), "TokenBucket: request after refill should be allowed");
    println!("TokenBucket: PASS");

    // ── Sliding Window: 3 requests per 200ms window ───────────────────────────
    let mut sw = RateLimiter::new(
        Algorithm::SlidingWindow,
        3,
        Duration::from_millis(200),
    );
    assert!(sw.is_allowed(),  "SlidingWindow req1 should be allowed");
    assert!(sw.is_allowed(),  "SlidingWindow req2 should be allowed");
    assert!(sw.is_allowed(),  "SlidingWindow req3 should be allowed");
    assert!(!sw.is_allowed(), "SlidingWindow req4 should be denied");
    // Wait for window to expire; all timestamps slide out
    thread::sleep(Duration::from_millis(250));
    assert!(sw.is_allowed(), "SlidingWindow req after window should be allowed");
    println!("SlidingWindow: PASS");

    // ── Fixed Window: 3 requests per 200ms — boundary spike demonstration ─────
    let mut fw = RateLimiter::new(
        Algorithm::FixedWindow,
        3,
        Duration::from_millis(200),
    );
    // Exhaust window 1
    let mut w1 = 0u32;
    for _ in 0..3 {
        if fw.is_allowed() { w1 += 1; }
    }
    assert!(w1 == 3, "FixedWindow window1: expected 3, got {}", w1);
    assert!(!fw.is_allowed(), "FixedWindow: 4th request in window1 should be denied");
    // Cross the window boundary
    thread::sleep(Duration::from_millis(250));
    // Exhaust window 2 — spike: 6 requests succeeded near the boundary
    let mut w2 = 0u32;
    for _ in 0..3 {
        if fw.is_allowed() { w2 += 1; }
    }
    assert!(w2 == 3, "FixedWindow window2: expected 3, got {}", w2);
    // Spike confirmed: 2 × limit requests succeeded in roughly one window's worth of time
    assert!(w1 + w2 == 6, "FixedWindow boundary spike: expected 6, got {}", w1 + w2);
    println!("FixedWindow boundary spike demonstrated (w1={}, w2={}): PASS", w1, w2);

    println!("All tests PASSED");
}
```

**Key design notes:**

- `Algorithm::TokenBucket` uses lazy refill: elapsed seconds × (limit / window_seconds) gives tokens accumulated since last call. Capped at `limit` to bound burst.
- `Algorithm::SlidingWindow` evicts stale entries *before* checking the count, ensuring the log never grows beyond `limit` entries.
- `Algorithm::FixedWindow` resets the entire counter when `now - window_start >= window`. The boundary spike is not a bug here — the test *asserts* that `w1 + w2 == 6` to confirm the known limitation.
- `Duration::as_secs_f64()` is used for float-precision elapsed time computation — available in `std` since Rust 1.38.

### 4.2 Java Implementation

The Java implementation mirrors the Rust one. A single `RateLimiter` class with an inner `Algorithm` enum. Timestamps use `System.nanoTime()` (monotonic, suitable for duration measurement). `ArrayDeque<Long>` stores nanosecond timestamps for the sliding window log. The `isAllowed()` method is `synchronized` to be safe for multi-threaded callers without requiring `java.util.concurrent`.

```java
import java.util.ArrayDeque;

public class RateLimiter {

    enum Algorithm { TOKEN_BUCKET, SLIDING_WINDOW, FIXED_WINDOW }

    // ── Shared state per limiter instance ─────────────────────────────────────
    private final Algorithm algorithm;
    private final int limit;
    private final long windowNanos;

    // Token Bucket fields
    private double tokens;
    private long lastRefillNanos;

    // Sliding Window fields
    private final ArrayDeque<Long> log;

    // Fixed Window fields
    private int counter;
    private long windowStartNanos;

    public RateLimiter(Algorithm algorithm, int limit, long windowNanos) {
        this.algorithm       = algorithm;
        this.limit           = limit;
        this.windowNanos     = windowNanos;
        // Token Bucket: start full
        this.tokens          = limit;
        this.lastRefillNanos = System.nanoTime();
        // Sliding Window
        this.log             = new ArrayDeque<>();
        // Fixed Window
        this.counter         = 0;
        this.windowStartNanos = System.nanoTime();
    }

    public synchronized boolean isAllowed() {
        long now = System.nanoTime();
        switch (algorithm) {
            case TOKEN_BUCKET: {
                double elapsed    = (now - lastRefillNanos) / 1_000_000_000.0;
                double refillRate = (double) limit / (windowNanos / 1_000_000_000.0);
                tokens = Math.min(tokens + elapsed * refillRate, limit);
                lastRefillNanos = now;
                if (tokens >= 1.0) {
                    tokens -= 1.0;
                    return true;
                }
                return false;
            }
            case SLIDING_WINDOW: {
                long cutoff = now - windowNanos;
                while (!log.isEmpty() && log.peekFirst() <= cutoff) {
                    log.removeFirst();
                }
                if (log.size() < limit) {
                    log.addLast(now);
                    return true;
                }
                return false;
            }
            case FIXED_WINDOW: {
                if (now - windowStartNanos >= windowNanos) {
                    windowStartNanos = now;
                    counter = 0;
                }
                if (counter < limit) {
                    counter++;
                    return true;
                }
                return false;
            }
            default:
                throw new IllegalStateException("Unknown algorithm");
        }
    }

    // ── Assertion helper (no assert keyword) ──────────────────────────────────
    private static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError(msg);
    }

    public static void main(String[] args) throws InterruptedException {
        long window = 200_000_000L; // 200 ms in nanoseconds

        // ── Token Bucket: limit=5, window=200ms ───────────────────────────────
        RateLimiter tb = new RateLimiter(Algorithm.TOKEN_BUCKET, 5, window);
        int allowed = 0;
        for (int i = 0; i < 5; i++) {
            if (tb.isAllowed()) allowed++;
        }
        check(allowed == 5, "TokenBucket burst: expected 5, got " + allowed);
        check(!tb.isAllowed(), "TokenBucket: 6th request should be denied");
        Thread.sleep(250);
        check(tb.isAllowed(), "TokenBucket: request after refill should be allowed");
        System.out.println("TokenBucket: PASS");

        // ── Sliding Window: limit=3, window=200ms ─────────────────────────────
        RateLimiter sw = new RateLimiter(Algorithm.SLIDING_WINDOW, 3, window);
        check(sw.isAllowed(),  "SlidingWindow req1 should be allowed");
        check(sw.isAllowed(),  "SlidingWindow req2 should be allowed");
        check(sw.isAllowed(),  "SlidingWindow req3 should be allowed");
        check(!sw.isAllowed(), "SlidingWindow req4 should be denied");
        Thread.sleep(250);
        check(sw.isAllowed(), "SlidingWindow req after window should be allowed");
        System.out.println("SlidingWindow: PASS");

        // ── Fixed Window: limit=3, window=200ms — boundary spike ──────────────
        RateLimiter fw = new RateLimiter(Algorithm.FIXED_WINDOW, 3, window);
        int w1 = 0;
        for (int i = 0; i < 3; i++) {
            if (fw.isAllowed()) w1++;
        }
        check(w1 == 3, "FixedWindow window1: expected 3, got " + w1);
        check(!fw.isAllowed(), "FixedWindow: 4th request in window1 should be denied");
        Thread.sleep(250);
        int w2 = 0;
        for (int i = 0; i < 3; i++) {
            if (fw.isAllowed()) w2++;
        }
        check(w2 == 3, "FixedWindow window2: expected 3, got " + w2);
        // Spike: 6 requests succeeded across a boundary in ~250 ms
        check(w1 + w2 == 6,
              "FixedWindow boundary spike: expected 6, got " + (w1 + w2));
        System.out.println("FixedWindow boundary spike demonstrated (w1=" + w1
                           + ", w2=" + w2 + "): PASS");

        System.out.println("All tests PASSED");
    }
}
```

**Key design notes:**

- `System.nanoTime()` returns a monotonic nanosecond clock. It is not wall-clock time and must not be used for `X-RateLimit-Reset` (use `System.currentTimeMillis()` for that in production).
- `ArrayDeque<Long>` is used for the sliding window log. `peekFirst()` + `removeFirst()` drain the oldest timestamps. Never use `Stack` — it extends `Vector` and is thread-unsafe by a different mechanism than expected.
- `isAllowed()` is `synchronized` on the instance. This is sufficient for single-instance, multi-threaded use. For concurrent access from a thread pool, prefer a `ReentrantLock` or `LongAdder`-based approach (see Section 7).
- `Thread.sleep(long)` declares `InterruptedException`. `main` propagates it with `throws InterruptedException`.
- The `assert` keyword is deliberately avoided. The `check()` helper throws `AssertionError` unconditionally regardless of whether the JVM was started with `-ea`.

---

## 5. Tradeoffs & Alternatives

### 5.1 Algorithm Comparison

| Algorithm | Memory per User | Accuracy | Burst Handling | Distributed Complexity |
|---|---|---|---|---|
| Token Bucket | O(1) — 2 values (tokens, timestamp) | High — continuous refill, no window artifacts | Excellent — burst up to bucket capacity | Medium — Lua script for atomic read-modify-write of two fields |
| Sliding Window Log | O(requests in window) — up to N timestamps | Exact — no boundary artifacts | Fair — no burst allowance beyond limit | High — sorted set in Redis; ZADD + ZREMRANGEBYSCORE + ZCARD pipeline |
| Sliding Window Counter (hybrid) | O(buckets) — constant for a given window/bucket size | Very high — ~0.1% error at bucket boundaries | Fair — no burst allowance | Low-Medium — one counter per bucket; simple INCR |
| Fixed Window Counter | O(1) — 1 counter per window | Low — boundary spike up to 2× limit | Poor — no burst concept; hard cutoff | Low — single INCR + EXPIRE; Lua for atomicity |

### 5.2 Leaky Bucket

The leaky bucket algorithm is conceptually similar to token bucket but from the opposite direction: requests enter a queue (the "bucket") and are processed at a fixed output rate, regardless of how fast they arrive. Excess requests are dropped or queued.

**Why it is not implemented here:** Leaky bucket enforces a strictly constant output rate, which is useful for smoothing traffic to a downstream service (e.g., an SMS gateway that can handle exactly 10 msgs/sec). However, for API rate limiting — where the goal is to cap the *number of requests from a client*, not smooth the output rate — token bucket is a strictly better model. Leaky bucket adds queue management complexity (what to do with queued requests that time out), provides no burst allowance, and is harder to distribute correctly. All major API platforms use token bucket or sliding window variants, not leaky bucket.

### 5.3 Redis vs In-Memory

| Dimension | Redis | In-Memory (per node) |
|---|---|---|
| Distributed consistency | Yes — all nodes share one counter | No — each node has its own counter |
| Latency | +200–500 µs per request (LAN RTT) | < 1 µs |
| Failure impact | Redis outage affects all enforcement | Node failure only affects that node |
| Simplicity | Requires Lua scripts, key design | Trivial — just a HashMap |
| Use case | Multi-node production deployments | Single-node or prototype |

A common hybrid is to maintain a **local short-interval counter** (e.g., last 100ms) in memory and only hit Redis once per local-window expiry. This amortizes Redis RTT across many requests while maintaining distributed accuracy within a bounded error (the local window duration). The tradeoff is that a user can briefly exceed the global limit by up to `local_window_duration × rate` across multiple nodes before the global counter catches up.

### 5.4 Per-IP vs Per-User vs Per-Endpoint Rules

| Granularity | Pros | Cons |
|---|---|---|
| Per-IP | Simple; no auth required; blocks unauthenticated abuse | NAT/proxy IPs share limits; VPN users appear as one IP |
| Per-User (API key) | Fair per-customer limits; survives IP changes | Requires authenticated requests; API key leaks share limits |
| Per-Endpoint | Protect expensive endpoints independently | Requires more rules; users can shift load to other endpoints |
| Composite (User + Endpoint) | Maximum precision | More Redis keys; more complex rule evaluation |

Production systems typically layer all three: a per-IP limit at the network edge (CDN or WAF), a per-user limit at the API gateway, and per-endpoint overrides for expensive operations. The Config Service makes this layering manageable by allowing rules to specify multiple `key_extractor` dimensions.

---

## 6. Failure Modes & Mitigations

### 6.1 Redis Unavailable

**Symptom:** Rate-limiter Lua scripts time out or return connection errors. Without a counter store, the gateway cannot enforce distributed limits.

**Fail-open strategy:** Allow all requests through when Redis is unreachable. This prevents a Redis outage from causing a customer-facing service outage. The risk is that abusive clients can temporarily bypass rate limits. This is the correct default for most APIs where availability outweighs the abuse risk.

**Fail-closed strategy:** Deny all requests when Redis is unreachable. This protects backend services from overload at the cost of rejecting legitimate traffic. Use for financial, security-critical, or metered endpoints where allowing excess traffic is worse than a brief outage.

**Local fallback limiter:** Implement a local in-memory rate limiter (token bucket or fixed window) as a fallback. When Redis is unreachable, apply the local limiter with a more permissive limit (e.g., 5× the normal limit) to absorb some traffic while preventing the worst abuse. Expose a metric for "operating in degraded mode" so on-call engineers are alerted immediately.

**Circuit breaker:** Wrap Redis calls in a circuit breaker. If the error rate for Redis calls exceeds a threshold (e.g., 10% over 10 seconds), trip the breaker and switch to the local fallback. Periodically probe Redis to detect recovery and close the circuit.

### 6.2 Clock Drift Across Nodes

**Symptom:** Different gateway nodes have slightly different wall-clock times. A fixed window keyed on `floor(now / window_seconds)` may evaluate differently on different nodes at window boundaries, causing some nodes to reset their window 100–200 ms earlier or later than others. For token bucket, drift causes inconsistent refill timing.

**Mitigation — Redis server time:** Use Redis's `TIME` command to get the authoritative server time. Include `TIME` at the beginning of every Lua script and use the returned seconds/microseconds for all window computations. This eliminates inter-node drift because all nodes delegate timekeeping to the same Redis server (or shard leader in cluster mode).

**Mitigation — NTP:** Ensure all nodes run `ntpd` or `chronyd` synchronized to the same NTP stratum-1 source. Modern cloud providers (AWS, GCP, Azure) offer hypervisor-level clock sync that keeps drift under 1 ms. This is necessary regardless because many other distributed systems (logs, traces, distributed locks) depend on synchronized clocks.

**Mitigation — monotonic clocks for local state:** Never use wall-clock time (e.g., `System.currentTimeMillis()` in Java, `SystemTime::now()` in Rust) for duration measurement within a single process. Use monotonic clocks (`System.nanoTime()`, `Instant::now()`) which are immune to NTP adjustments and leap-second corrections.

### 6.3 Hot Key Problem

**Symptom:** A single high-traffic Redis key (e.g., a rate-limit counter for a shared API key used by millions of users) becomes a throughput bottleneck. Redis is single-threaded per shard, so one hot key can saturate a shard's CPU even when other shards are idle.

**Mitigation — per-node counters with periodic sync:** Each gateway node maintains a local counter increment since the last sync. Every 100ms (configurable), each node adds its local delta to the Redis key using `INCRBY` and reads the new global total. Between syncs, local enforcement uses `local_count + last_known_global`. The tradeoff is that enforcement lags by up to one sync interval, but the Redis write rate drops from N × RPS to N × (1 / sync_interval).

**Mitigation — sharded counters (cell-based rate limiting):** Split one Redis key into K shards: `ratelimit:user:shard:0`, `ratelimit:user:shard:1`, ... Each request increments a randomly selected shard. To check the total, sum all K shards. This distributes writes across K Redis keys (and potentially K cluster shards), but requires a read of K keys to check the total — typically done as a pipeline read.

**Mitigation — local short-window pre-check:** Before calling Redis, check a local per-node counter for the last short interval (e.g., 50ms). If the local counter alone exceeds `limit / num_nodes × headroom_factor`, deny immediately without calling Redis. This adds a slight first-pass filter that prevents local request storms from becoming Redis storms.

### 6.4 Config Service Unavailable

**Symptom:** Gateway nodes cannot fetch updated rate-limit rules. Nodes may be starting fresh (no cached rules) or running with rules that are becoming stale.

**Mitigation — cached rules with TTL:** Each gateway node caches the last successfully fetched rule set in memory with a TTL of 5 minutes. If the Config Service is unreachable, the node continues operating with its cached rules. After the TTL expires, the node logs a warning and continues with the last-known-good rules rather than failing open or closed.

**Mitigation — baked-in defaults:** Package a set of conservative default rules into the gateway binary. If the node starts with no cached rules and cannot reach the Config Service, it applies the defaults. Defaults should be more restrictive than production rules to prevent abuse during bootstrap.

**Mitigation — resilient Config Service:** Deploy the Config Service with multiple replicas behind a load balancer. Store rules in a replicated data store (e.g., etcd, Consul, or a read replica of the primary database). Use health checks and readiness probes so the load balancer removes unhealthy instances automatically. For maximum resilience, cache rules in Redis itself — nodes can fall back to reading from Redis even if the Config Service HTTP endpoint is down.

---

## 7. Java vs Rust

> **Java vs Rust:** Both languages implement all three rate-limit algorithms with similar correctness, but they diverge sharply when it comes to concurrent production use, memory safety guarantees, and integration with async runtimes.
>
> **Concurrent counter updates:** Java provides `AtomicLong` and `LongAdder` in `java.util.concurrent.atomic`. `LongAdder` is specifically optimized for high-contention increment scenarios — it maintains per-CPU cells and only aggregates on read, making it significantly faster than `AtomicLong.incrementAndGet()` under heavy write contention. In Rust, `std::sync::atomic::AtomicU64` with `fetch_add(1, Ordering::Relaxed)` is the equivalent for simple counters. Rust's memory ordering system is more explicit — the programmer must choose between `Relaxed`, `Acquire`, `Release`, and `SeqCst` — but this forces correct reasoning about visibility guarantees rather than leaving them implicit.
>
> **Mutex and shared ownership:** In Java, `synchronized` on an instance method acquires the object's intrinsic monitor. It is simple but coarse-grained and not composable — you cannot lock two objects in a defined order without careful code review. In Rust, `Arc<Mutex<RateLimiter>>` makes shared ownership explicit at the type level: you cannot access the `RateLimiter` state without holding the mutex guard, and the borrow checker enforces this at compile time. There is no way to accidentally read `tokens` without holding the lock in Rust; in Java, forgetting `synchronized` is a silent data race. For production rate limiters, Rust's model eliminates an entire class of concurrency bugs before the code ships.
>
> **Concurrent collections:** Java's `ConcurrentHashMap` provides thread-safe, high-concurrency key-value storage with segment-level locking. It is mature and well-tuned for the JVM. The nearest Rust equivalent in production use is `DashMap` from the `dashmap` crate — but this chapter restricts to `std` only. Within `std`, `HashMap` behind a `Mutex` or `RwLock` is the baseline. For read-heavy rule caches (many readers, rare writes), `Arc<RwLock<HashMap<...>>>` outperforms `Mutex<HashMap<...>>` in the same way `ConcurrentHashMap`'s read paths outperform a fully synchronized `HashMap` in Java.
>
> **Async integration:** Java rate limiters in production typically run within a servlet filter or Spring `HandlerInterceptor` on a thread-pool executor. The `synchronized` keyword works correctly in this model. Moving to reactive Java (Project Reactor, WebFlux) requires replacing `synchronized` with reactive primitives (`Mono`, `Semaphore`, reactor-extra's `ConcurrentHashMapRateLimiter`). In Rust, async is first-class via Tokio. A production Rust rate limiter would use `tokio::sync::Mutex` (which yields the task rather than blocking the OS thread during contention) and expose an `async fn is_allowed(&self) -> bool` that awaits the Redis round-trip without blocking the Tokio thread pool. The async-native model allows a single Tokio worker to handle tens of thousands of concurrent rate-limit checks efficiently, whereas a Java thread-pool model requires one OS thread per concurrent check — a meaningful memory and context-switch overhead at 100K RPS.
>
> **Summary:** For a prototype or team with strong Java expertise, Java's `synchronized` + `ArrayDeque` implementation is clear and correct. For a high-throughput production rate limiter expected to handle 100K+ RPS on a small number of cores, Rust's compile-time safety guarantees, async-native Tokio integration, and predictable low-level performance make it the stronger foundation.
