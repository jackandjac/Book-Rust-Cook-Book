# Chapter 15: Circuit Breaker, Retries & Observability

> **Chapter goal:** Implement the circuit breaker pattern, exponential backoff with jitter, bulkhead isolation, and the observability pillars (metrics, logs, traces) for production-grade resilience.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 The Cascading Failure Problem

A microservice system without circuit breakers is brittle in a specific way: a single slow downstream service can exhaust the thread pool (or async task queue) of every service that calls it, propagating failure upward until the entire system is unavailable. This is a cascading failure.

The sequence unfolds in seconds:

1. Service B slows down (database latency spike, GC pause, downstream overload).
2. Service A sends requests to B; they block waiting for B's response.
3. A's thread pool fills up — all threads are waiting on B.
4. New requests to A time out or queue, then fail.
5. Services C and D, which call A, begin to fail.
6. The entire call graph degrades within 10–30 seconds.

Without circuit breakers, the only recovery is for B to recover — and by then, A's queues may be so backed up that normal load causes sustained instability even after B is healthy.

### 1.2 Functional Requirements

- **Failure detection** — track failure rate or failure count over a rolling window per downstream dependency.
- **Fast fail** — once failure threshold is exceeded, reject calls immediately (HTTP 503) without sending them to the failing service.
- **Automatic recovery** — after a cool-down period, allow one test request through; if it succeeds, close the circuit and resume normal traffic.
- **Retry with backoff** — on retryable failures (5xx, timeout), retry with exponential backoff and random jitter, capped at a maximum wait time.
- **Bulkhead isolation** — separate resource pools (thread pools, connection pools) per downstream service so one slow dependency cannot starve calls to others.
- **Observability** — emit metrics (request rate, error rate, latency percentiles), structured logs, and distributed traces for every call.

### 1.3 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Circuit break decision latency | < 1 ms (in-memory state; no network call) |
| Recovery probe interval | 30 seconds after opening |
| Retry max attempts | 3 |
| Total retry window | ≤ 30 seconds (exponential backoff capped) |
| Observability overhead | < 2% CPU; < 1 MB/sec metrics egress per service |
| Log volume | < 10 GB/day per service instance at INFO level |

### 1.4 Scale Context

In a service mesh of 50 microservices where each service calls 3–5 others, a single 10-second latency spike on one leaf service creates a wave of thread pool exhaustion across 5–10 upstream services within 10 seconds if no circuit breakers are in place. With circuit breakers, the degraded service is isolated at its direct callers — upstream services fast-fail immediately and return cached or degraded responses rather than blocking.

---

## 2. Architecture

### 2.1 Circuit Breaker State Machine

```
                       failure rate > threshold
    ┌──────────────────────────────────────────────────┐
    │                                                  │
    ▼                                                  │
┌─────────┐   failure rate          ┌──────────┐      │
│ CLOSED  │ ─── exceeded ────────► │  OPEN    │      │
│(normal) │                         │(fast fail│      │
└─────────┘                         │ 30s timer│      │
    ▲                               └────┬─────┘      │
    │                                    │            │
    │                          timer     │            │
    │                          expires   │            │
    │                                    ▼            │
    │  success count              ┌────────────┐      │
    └─── >= threshold ────────── │ HALF_OPEN  │ ─────┘
                                  │(1 test req)│ failure
                                  └────────────┘
```

### 2.2 Bulkhead Pattern

```
Service A calls B, C, D:

WITHOUT bulkhead:                WITH bulkhead:
                                 ┌─────────────────────────────┐
  Shared thread pool             │  Thread pool B (size: 10)   │
  ┌───────────────────┐          │  Thread pool C (size: 10)   │
  │ T T T T T T T T T│          │  Thread pool D (size: 10)   │
  │ T T T T T T T T T│          └─────────────────────────────┘
  └───────────────────┘
  All waiting on B → starved      B slow → only B pool exhausted
  → C and D calls also fail       → C and D calls unaffected
```

### 2.3 Request Flow with All Patterns

```
Client Request
      │
      ▼
┌─────────────────────────────────────────────────────┐
│  Service A                                          │
│                                                     │
│  Inject Trace-ID ──► Structured Log (INFO: start)  │
│       │                                             │
│       ▼                                             │
│  Emit Metric: request_total++                       │
│       │                                             │
│       ▼                                             │
│  Circuit Breaker Check ──► OPEN? → return 503       │
│       │ CLOSED / HALF_OPEN                          │
│       ▼                                             │
│  Bulkhead: acquire slot in B's thread pool          │
│       │                                             │
│       ▼                                             │
│  Call Service B (with timeout: 5s)                  │
│       │                                             │
│  ┌────┴──────────────────────────────────────┐      │
│  │ Retry loop (max 3, exponential + jitter) │      │
│  └───────────────────────────────────────────┘      │
│       │                                             │
│  Emit Metric: latency histogram, error_total        │
│  Structured Log (WARN: retry, ERROR: failure)       │
│  Export Trace Span to Jaeger                        │
└─────────────────────────────────────────────────────┘
```

---

## 3. Component Deep-Dive

### 3.1 Circuit Breaker State Machine

The circuit breaker tracks the health of a single downstream dependency using a state machine with three states:

**CLOSED** is the normal operating state. Requests pass through. A rolling window (e.g., the last 10 requests, or the last 10 seconds of requests) tracks the failure rate. When the failure rate exceeds the threshold — e.g., 50% of the last 10 requests failed — the circuit transitions to OPEN.

**OPEN** is the fast-fail state. All calls to the downstream dependency are rejected immediately with a "circuit open" error — no network call is made. The caller returns HTTP 503 or a fallback response. A timer starts (typically 30 seconds). This gives the failing service time to recover without being hammered by traffic.

**HALF_OPEN** is the recovery probe state. After the timer expires, the circuit allows exactly one request through. If that request succeeds, the circuit closes and normal traffic resumes. If it fails, the circuit returns to OPEN and restarts the timer. Multiple callers arriving during HALF_OPEN must wait or fast-fail — only one probe is allowed at a time to prevent a recovering service from being overwhelmed.

**Counting strategies:**

- **Count-based:** track the last N requests in a ring buffer. Simple to implement; sensitive to burst patterns (one bad second opens the circuit for the next 9).
- **Time-window:** track failures in a rolling time window (e.g., last 10 seconds). More representative of current service health; requires a sliding window data structure or decay function.

### 3.2 Retry with Exponential Backoff + Jitter

Naive retry (retry immediately on failure) causes a thundering herd: if a service fails for 1 second and all callers retry at the same time after the failure, they create a traffic spike on the recovering service, potentially causing it to fail again.

**Exponential backoff:** wait `base × 2^attempt` milliseconds between retries. The wait grows: 100ms, 200ms, 400ms, 800ms. This gives the service increasing time to recover and reduces retry pressure over time.

**Jitter:** add a random offset of ±50% to the backoff wait. Without jitter, all callers waiting the same duration resume simultaneously — a synchronized retry storm. With jitter, they spread out across a window. This is sometimes called "full jitter" or "decorrelated jitter."

**Policy:**
- Retry only on retryable errors: 5xx (server error), timeout. Do not retry 4xx (client error — the request will keep failing).
- Maximum 3 retries.
- Cap total wait at 30 seconds regardless of formula.
- On final failure, propagate the error to the caller and record it in the circuit breaker's failure count.

### 3.3 Bulkhead Pattern

The bulkhead pattern takes its name from ship compartments: flooding one compartment does not sink the ship. Applied to software: each downstream dependency gets its own bounded resource pool.

**Thread pool bulkhead:** maintain a separate `ThreadPoolExecutor` per downstream dependency. If service B's pool (10 threads) is exhausted, calls to B queue or fail fast — but service C's pool (also 10 threads) is unaffected. Without bulkheads, a shared pool of 100 threads can be exhausted entirely by slow B calls, leaving no threads for C and D.

**Semaphore bulkhead:** for async/reactive systems without dedicated threads, use a semaphore per dependency. Each call acquires a permit; the semaphore limits concurrent in-flight calls. If the semaphore is exhausted (all permits taken), the call fails fast rather than queueing.

**Sizing:** estimate maximum concurrent calls to each dependency. If B handles 50 req/sec and average latency is 200ms, max concurrent calls = 50 × 0.2 = 10. Size the pool at 10–15 (adding headroom for latency spikes). A pool that is too large provides no isolation; too small causes unnecessary rejections.

**When pool is full:** fail fast (throw `BulkheadFullException`) rather than queueing indefinitely. An unbounded queue defeats the purpose of the bulkhead by allowing thread starvation of other work.

### 3.4 Timeout Hierarchy

Every layer of the call stack needs its own timeout. Missing any level creates a resource leak or an unbounded wait. The timeouts form a strict hierarchy where each layer's timeout is shorter than the next:

```
Connect timeout (1s) < Read timeout (5s) < Circuit breaker window (10s)
  < Retry total budget (30s) < User-facing request timeout (60s)
```

- **Connect timeout (1s):** maximum time to establish a TCP connection. Prevents hanging on unreachable hosts.
- **Read timeout (5s):** maximum time to receive the full response after connecting. Prevents hanging on a server that accepted the connection but stopped responding.
- **Circuit breaker window (10s):** the rolling window over which failures are counted. Should be longer than the read timeout so a single slow request is counted before the window closes.
- **Retry total budget (30s):** the maximum total time including all retry attempts and backoff waits. Prevents the retry loop from running indefinitely.
- **User-facing timeout (60s):** the maximum time the end user will wait. Must be longer than the retry budget to allow all retries to complete before the top-level timeout fires.

### 3.5 Observability: Metrics

The RED method provides three foundational metrics for every service endpoint:

- **Rate:** requests per second. Tracks traffic volume; alert on unexpected drops (traffic stopped flowing — a routing problem) or spikes (abuse, runaway retry storm).
- **Errors:** error rate as a percentage of total requests. Alert when error rate exceeds 5% for more than 2 consecutive minutes — this triggers PagerDuty.
- **Duration:** latency at p50, p95, and p99. p50 is the median experience; p99 is the worst 1% — a common SLA boundary. Alert when p99 exceeds 2× the normal baseline.

**Circuit breaker state transitions** are also emitted as metrics: `circuit_breaker_state_change{dependency="service-b", from="closed", to="open"}`. This makes dashboards show exactly when and how often circuits are opening.

**Export pipeline:** services emit metrics using the Prometheus exposition format. A Prometheus scraper collects them every 15 seconds. Grafana dashboards visualize them. PagerDuty alerts fire from Grafana alert rules. The entire pipeline adds < 2% CPU overhead on the emitting service.

### 3.6 Observability: Distributed Tracing

A single user request traverses 5–10 services. Without tracing, correlating logs across services to reconstruct a request's journey requires matching timestamps across log files — error-prone and slow.

**Trace propagation:** every inbound request is assigned a `trace_id` (UUID). This ID is injected into the HTTP headers using the W3C `traceparent` format: `traceparent: 00-{trace_id}-{span_id}-{flags}`. Every downstream call propagates this header. Every service that creates a child span records: service name, operation name, start time, duration, status, and the parent `span_id`.

**Sampling:** recording every request at full fidelity in production is expensive. Head-based sampling at 1% means 1 in 100 requests is fully traced. For error investigations, use tail-based sampling: sample 100% of requests that resulted in errors, 0.1% of successful requests. This provides full fidelity for failures without the volume cost.

**Export:** spans are exported to Jaeger or Zipkin (both open-source) or to commercial backends (Datadog APM, Honeycomb). The trace viewer shows the full request waterfall: which service was slow, where retries occurred, which span held the circuit breaker open.

**Combining circuit breaker state with traces:** annotate the trace span with circuit breaker state at the time of the call: `cb.state=CLOSED`, `cb.state=OPEN`, `cb.attempts=2`. When a circuit opens on a trace, this annotation is visible immediately in the trace viewer, making root-cause analysis a 30-second exercise rather than a 30-minute log search. Libraries like Resilience4j provide built-in OpenTelemetry hooks for this annotation.

### 3.7 Observability: Structured Logging

Structured logs are JSON objects rather than free-text strings. Instead of:

```
2026-05-16 09:00:01 ERROR Failed to call service-b after 3 retries
```

A structured log looks like:

```json
{
  "timestamp": "2026-05-16T09:00:01.234Z",
  "level": "ERROR",
  "service": "order-service",
  "trace_id": "a1b2c3d4e5f6...",
  "span_id": "f1e2d3c4...",
  "message": "call failed after retries",
  "dependency": "service-b",
  "attempts": 3,
  "last_error": "timeout after 5000ms",
  "circuit_state": "open"
}
```

JSON logs enable field-based filtering in Elasticsearch, Splunk, or CloudWatch Logs: `dependency:"service-b" AND level:ERROR` instantly surfaces all errors from that dependency across all service instances.

**Log level strategy:**
- `DEBUG`: verbose; only in local development. Log every request, every retry attempt.
- `INFO`: production. Log service start/stop, significant business events (order placed, payment processed), circuit breaker state changes.
- `WARN`: degraded but recoverable. Log retries, circuit half-open probes, high latency warnings.
- `ERROR`: failures requiring attention. Log circuit opens, unrecoverable errors, exhausted retries.

Avoid logging in the hot path at DEBUG in production — even if the log level filters it out, the string formatting overhead at > 100K req/sec is measurable.

---

## 4. Key Algorithms

### 4.1 Rust: Circuit Breaker

```rust
use std::time::{Duration, Instant};

#[derive(Debug, PartialEq)]
enum CircuitState { Closed, Open, HalfOpen }

struct CircuitBreaker {
    state: CircuitState,
    failure_count: u32,
    success_count: u32,
    failure_threshold: u32,   // failures before opening
    success_threshold: u32,   // successes in HalfOpen to close
    open_duration: Duration,  // how long to stay Open
    last_opened: Option<Instant>,
    total_requests: u32,
    window_size: u32,         // request window for failure rate
}

impl CircuitBreaker {
    fn new(failure_threshold: u32, success_threshold: u32, open_secs: u64) -> Self {
        CircuitBreaker {
            state: CircuitState::Closed,
            failure_count: 0,
            success_count: 0,
            failure_threshold,
            success_threshold,
            open_duration: Duration::from_secs(open_secs),
            last_opened: None,
            total_requests: 0,
            window_size: 10,
        }
    }

    fn call<F: FnOnce() -> Result<(), String>>(&mut self, f: F) -> Result<(), String> {
        self.total_requests += 1;
        match self.state {
            CircuitState::Open => {
                let expired = self.last_opened
                    .map(|t| t.elapsed() >= self.open_duration)
                    .unwrap_or(false);
                if !expired {
                    return Err("circuit open".into());
                }
                // Timer expired: probe with one request
                self.state = CircuitState::HalfOpen;
                self.success_count = 0;
                self.failure_count = 0;
                self.probe(f)
            }
            CircuitState::HalfOpen => self.probe(f),
            CircuitState::Closed => {
                match f() {
                    Ok(_) => { self.failure_count = 0; Ok(()) }
                    Err(e) => {
                        self.failure_count += 1;
                        if self.failure_count >= self.failure_threshold {
                            self.state = CircuitState::Open;
                            self.last_opened = Some(Instant::now());
                        }
                        Err(e)
                    }
                }
            }
        }
    }

    fn probe<F: FnOnce() -> Result<(), String>>(&mut self, f: F) -> Result<(), String> {
        match f() {
            Ok(_) => {
                self.success_count += 1;
                if self.success_count >= self.success_threshold {
                    self.state = CircuitState::Closed;
                    self.failure_count = 0;
                    self.success_count = 0;
                }
                Ok(())
            }
            Err(e) => {
                self.state = CircuitState::Open;
                self.last_opened = Some(Instant::now());
                self.failure_count = 0;
                self.success_count = 0;
                Err(e)
            }
        }
    }

    fn state(&self) -> &CircuitState { &self.state }
}

// Exponential backoff with deterministic jitter (no rand dependency)
fn backoff_ms(attempt: u32) -> u64 {
    let base: u64 = 100 * (1u64 << attempt.min(6)); // cap exponent at 6 → max 6400ms
    // Pseudo-random jitter: deterministic for tests, spreads retries in production
    let jitter = if base > 0 { (attempt as u64 * 1337 + 42) % base } else { 0 };
    base + jitter
}

fn main() {
    let mut cb = CircuitBreaker::new(3, 2, 30);

    // 3 failures → circuit opens
    for _ in 0..3 {
        let _ = cb.call(|| Err("service down".into()));
    }
    assert_eq!(cb.state(), &CircuitState::Open);

    // While open: fast fail (no network call)
    let result = cb.call(|| Ok(()));
    assert!(result.is_err());

    // Backoff: attempt 0 → base=100, jitter=42 → 142ms ≥ 100
    assert!(backoff_ms(0) >= 100);
    // attempt 1 → base=200, jitter=1379%200=179 → 379ms ≥ 200
    assert!(backoff_ms(1) >= 200);
}
```

**Key points:**
- The state machine is encoded directly in Rust's `match` with three arms: `Open`, `HalfOpen`, `Closed`. The compiler guarantees all states are handled.
- The `probe` helper extracts the HALF_OPEN request logic, called both from the `Open` arm (after timer expiry) and the `HalfOpen` arm directly. This avoids duplicated code.
- `FnOnce() -> Result<(), String>` is the most general closure type: the closure is called exactly once (one network attempt), captures any owned data, and returns a `Result`. This makes the circuit breaker generic over any callable.
- `Instant::elapsed()` uses the monotonic clock — immune to system time adjustments. `Duration::from_secs(open_secs)` is compared to `elapsed()` without converting to wall time, making the implementation robust.
- `backoff_ms` uses bit-shifting (`1u64 << attempt.min(6)`) instead of floating-point `pow` — exact and fast. Capping the exponent at 6 caps the base at 6,400ms (6.4 seconds); with jitter, total wait stays well under 30 seconds for 3 retries.

### 4.2 Java: Circuit Breaker

```java
import java.util.function.Supplier;

public class CircuitBreaker {

    static void check(boolean cond, String msg) {
        if (!cond) throw new RuntimeException("Assertion failed: " + msg);
    }

    enum State { CLOSED, OPEN, HALF_OPEN }

    private State state = State.CLOSED;
    private int failureCount = 0;
    private int successCount = 0;
    private final int failureThreshold;
    private final int successThreshold;
    private final long openDurationMs;
    private long lastOpenedMs = 0;

    public CircuitBreaker(int failureThreshold, int successThreshold, long openDurationMs) {
        this.failureThreshold = failureThreshold;
        this.successThreshold = successThreshold;
        this.openDurationMs = openDurationMs;
    }

    public <T> T call(Supplier<T> supplier) throws Exception {
        if (state == State.OPEN) {
            long elapsed = System.currentTimeMillis() - lastOpenedMs;
            if (elapsed < openDurationMs) {
                throw new Exception("circuit open");
            }
            // Timer expired: transition to HALF_OPEN
            state = State.HALF_OPEN;
            successCount = 0;
            failureCount = 0;
        }

        if (state == State.HALF_OPEN) {
            return probe(supplier);
        }

        // CLOSED
        try {
            T result = supplier.get();
            failureCount = 0;
            return result;
        } catch (Exception e) {
            failureCount++;
            if (failureCount >= failureThreshold) {
                state = State.OPEN;
                lastOpenedMs = System.currentTimeMillis();
            }
            throw e;
        }
    }

    private <T> T probe(Supplier<T> supplier) throws Exception {
        try {
            T result = supplier.get();
            successCount++;
            if (successCount >= successThreshold) {
                state = State.CLOSED;
                failureCount = 0;
                successCount = 0;
            }
            return result;
        } catch (Exception e) {
            state = State.OPEN;
            lastOpenedMs = System.currentTimeMillis();
            failureCount = 0;
            successCount = 0;
            throw e;
        }
    }

    public State getState() { return state; }

    public static long backoffMs(int attempt) {
        long base = 100L * (1L << Math.min(attempt, 6));
        long jitter = base > 0 ? ((long) attempt * 1337 + 42) % base : 0;
        return base + jitter;
    }

    public static void main(String[] args) {
        CircuitBreaker cb = new CircuitBreaker(3, 2, 30_000);

        // 3 failures → circuit opens
        for (int i = 0; i < 3; i++) {
            try {
                cb.call(() -> { throw new RuntimeException("service down"); });
            } catch (Exception ignored) {}
        }
        check(cb.getState() == State.OPEN, "state should be OPEN after 3 failures");

        // While open: fast fail
        boolean caughtOpen = false;
        try {
            cb.call(() -> "ok");
        } catch (Exception e) {
            caughtOpen = true;
        }
        check(caughtOpen, "should throw circuit open exception");

        check(backoffMs(0) >= 100, "backoff attempt 0 >= 100ms");
        check(backoffMs(1) >= 200, "backoff attempt 1 >= 200ms");
    }
}
```

**Key points:**
- `Supplier<T>` is a `java.util.function` functional interface (one abstract method: `T get()`). It is the Java equivalent of `FnOnce() -> T`. Because `Supplier.get()` does not declare checked exceptions, the lambda must wrap checked exceptions in `RuntimeException`. The `call()` method signature uses `throws Exception` to allow unchecked and checked exceptions from the supplier.
- `System.currentTimeMillis()` is the wall clock — subject to NTP adjustments. For interval measurement, `System.nanoTime()` is preferred (monotonic), but requires converting to milliseconds explicitly: `(System.nanoTime() - lastOpened) / 1_000_000L`. The example uses milliseconds for clarity; production code should use `nanoTime`.
- The Java `switch` on enum (Java 17 `switch` expressions with `->`) would be cleaner than `if (state == State.OPEN)` chains for the state machine. The `switch` approach is explored in the Java vs Rust section.
- `Math.min(attempt, 6)` caps the bit shift to prevent overflow on large attempt counts — equivalent to Rust's `attempt.min(6)`.

---

## 5. Tradeoffs

### 5.1 Circuit Breaker vs Alternatives

| Dimension | No Circuit Breaker | Timeout Only | Circuit Breaker |
|---|---|---|---|
| **Failure isolation** | None — cascade propagates | Partial — limits per-request wait | Strong — downstream failures contained at caller |
| **Cascade prevention** | No | No — threads still block until timeout | Yes — fast fail prevents thread pool exhaustion |
| **Recovery time** | Manual intervention or service restart | Eventual (timeouts free threads) | Automatic — HALF_OPEN probe at configured interval |
| **Complexity** | Low | Low | Medium — state machine, metrics, tuning |
| **False positives** | N/A | N/A | Yes — transient spike can open circuit unnecessarily |
| **Fallback support** | None | Caller must handle timeout | Explicit — return cached/default response on open |

### 5.2 Library Comparison

| Library | Language | Window type | Bulkhead | Metrics | Status |
|---|---|---|---|---|---|
| **Hystrix** | Java | Count-based | Thread pool & Semaphore | Hystrix dashboard | Deprecated (2018) |
| **Resilience4j** | Java | Count-based or time-based | Thread pool & Semaphore | Micrometer integration | Active |
| **Polly** | .NET | Count-based or time-based | Bulkhead policy | OpenTelemetry | Active |
| **go-circuit-breaker** | Go | Count-based | Manual | Manual | Community |
| **Custom (this chapter)** | Rust / Java | Count-based | External thread pool | Manual | Illustrative |

**Resilience4j** is the recommended library for Java production systems. It provides count-based and time-window circuit breakers, rate limiters, bulkheads, and retry policies — all with Micrometer metrics integration and Spring Boot autoconfiguration. The custom implementation in this chapter illustrates the internals; use Resilience4j for production.

### 5.3 Count-Based vs Time-Window Failure Tracking

**Count-based:** track the last N requests. Simple ring buffer. Problem: the window "forgets" the past proportionally to new requests. If 10 failures occurred 1,000 requests ago, the count is zero even though the failures were recent.

**Time-window (sliding):** track all requests within the last T seconds. More accurate picture of current health. Problem: requires a timestamp-indexed data structure (sorted set or ring buffer with timestamps). Memory usage proportional to request rate × window size.

**Recommendation:** use time-window for production systems with variable request rates. Count-based is simpler for systems with uniform request rates and makes testing easier.

### 5.4 Proactive vs Reactive Circuit Breaking

The circuit breakers described in this chapter are **reactive**: they detect failures by observing in-band request outcomes (5xx responses, timeouts). The circuit opens only after failures have already occurred — meaning some requests have already experienced errors before the circuit trips.

**Proactive circuit breaking** opens the circuit before failures occur, based on health signals from outside the request path:

- **Control-plane health signals:** a service mesh (Istio, Linkerd) monitors dependency health via sidecar proxies. If service B reports itself unhealthy (liveness probe fails, resource exhaustion detected), the control plane can preemptively mark B's circuit as OPEN in all callers' circuit breakers before any in-band failure is observed.
- **Outlier ejection:** load balancers (Envoy, HAProxy) track per-instance error rates across the cluster. A single backend pod that is returning 50% errors is "ejected" (removed from the load balancing pool) after a configurable threshold, before a circuit breaker in the application layer sees enough failures to trip. This is sometimes called "passive health checking" at the infrastructure layer.
- **Dependency health advertisement:** services actively publish their own degradation signals — "I am operating at reduced capacity" or "my upstream database is slow, expect elevated latency" — to a control plane or service registry. Callers subscribe to these signals and preemptively open circuits or reduce request rates.

**Tradeoffs:** proactive approaches require more infrastructure (service mesh, health advertisement protocol) and introduce false positives (a service may report degraded but still serve most requests correctly). Reactive approaches have zero false positives (the circuit only opens on observed failures) but allow some requests to fail before the circuit trips. In practice, production systems use both: reactive circuit breakers in the application layer as the last line of defense, combined with infrastructure-level outlier ejection as a faster, coarser preventive measure.

---

## 6. Failure Modes

### 6.1 Circuit Opens on Transient Spike

**Symptom:** a 1-second spike in errors (one GC pause on service B) causes the circuit to open for 30 seconds, blocking all traffic to B even after B has recovered.

**Root cause:** count-based circuit breakers with small windows open on short bursts. A count-based window of 10 requests where 6 fail in 1 second exceeds a 50% threshold — even if B is fine for the remaining 29 seconds.

**Mitigation:**
- Require a minimum request count before evaluating the threshold (e.g., at least 20 requests in the window). This prevents a single batch of failures in a low-traffic window from opening the circuit.
- Use percentage-based thresholds (50% error rate) rather than absolute counts. This adapts to traffic variability.
- Set a shorter open duration (15 seconds instead of 30) to reduce the penalty for false positives. More frequent probes increase the chance of catching recovery quickly.

### 6.2 Half-Open Thundering Herd

**Symptom:** 1,000 callers are blocked by an OPEN circuit. The timer expires. All 1,000 simultaneously enter HALF_OPEN and send probe requests to service B — which was just starting to recover. The burst overwhelms B, causing it to fail again.

**Root cause:** naive HALF_OPEN implementations allow all waiters through when the timer expires rather than a single probe.

**Mitigation:**
- Allow exactly one request through in HALF_OPEN. All other concurrent callers either fast-fail or block briefly while the probe completes. Use an atomic boolean flag or a semaphore with capacity 1.
- Only transition back to CLOSED after `success_threshold` consecutive successes in HALF_OPEN (e.g., 2). This provides more signal before resuming full traffic.
- Gradually ramp traffic after CLOSED: send 10% of traffic for 10 seconds, then 50%, then 100%. This is "slow start" or "canary reopening." Not implemented in the snippet; handled by traffic-shaping layers.

### 6.3 Missing Trace Correlation

**Symptom:** an error occurs in service D, which was called by C, which was called by B, which was called by A. The logs in service D show an error, but there is no way to identify which user request caused it — every service logs its own request identifiers independently.

**Root cause:** the `trace_id` was not propagated from A → B → C → D. Each service generated its own unrelated ID.

**Mitigation:**
- Enforce trace propagation at the framework level (HTTP interceptor, gRPC middleware, Kafka consumer interceptor). No individual developer should need to manually propagate headers.
- Add integration tests that verify trace headers are present on all outbound calls. Fail the build if trace propagation is missing.
- Run end-to-end tracing smoke tests in staging before every release.

### 6.4 Log Volume Explosion

**Symptom:** a single service instance produces 1 TB/day of logs. Log storage costs spike; search latency in Elasticsearch exceeds 10 seconds; log shipping creates back-pressure on the service.

**Root cause:** DEBUG or INFO logging in hot paths (e.g., every cache lookup, every Redis call at 100K req/sec) with un-sampled structured logs.

**Mitigation:**
- Sample INFO logs in the hot path: log 1 in 1,000 requests at INFO; log all errors at ERROR. Use a log sampler that tracks the sampling decision alongside the trace-id.
- Structured logging enables efficient server-side filtering — even if shipped, only pull what you need at query time. But prefer not shipping unnecessary logs at all.
- Set log retention policy: keep ERROR logs for 90 days; INFO logs for 7 days; DEBUG logs not in production at all.
- Use async log appenders (e.g., Logback's `AsyncAppender`) to prevent log I/O from blocking the request thread.

---

## 7. Java vs Rust

**Error propagation philosophy:** Rust uses `Result<T, E>` as the primary error type. Errors are values that must be handled — the compiler rejects silently ignoring a `Result`. The `?` operator propagates errors up the call stack explicitly. Java uses exceptions: `throw`, `catch`, checked vs unchecked. Checked exceptions require the caller to declare or catch them; unchecked `RuntimeException` can propagate silently. This leads to swallowed exceptions (`catch (Exception e) {}`), which are a significant source of hard-to-debug production issues. Rust's model makes errors impossible to ignore without explicit acknowledgment (`let _ = ...`), making error paths more visible.

**Closure types:** Rust's `FnOnce() -> Result<(), String>` is a closure type that is consumed (called once) and returns a `Result`. The compiler infers the concrete closure type from usage; it is a zero-cost abstraction (no heap allocation for simple closures). Java's `Supplier<T>` is a functional interface with a single abstract method `T get()`. Lambdas are syntactic sugar for anonymous classes — the JVM may allocate a heap object for each lambda (though the JIT often eliminates this). Java's `Supplier` does not declare checked exceptions, which forces checked exceptions into `RuntimeException` wrappers inside lambdas — a common friction point.

**Monotonic clock:** `std::time::Instant` in Rust is always monotonic — it never goes backward, even if the system clock is adjusted. `Instant::elapsed()` returns a `Duration` directly. Java's `System.currentTimeMillis()` uses the wall clock and can go backward (NTP correction, VM migration). For elapsed-time measurement in Java, `System.nanoTime()` is the correct choice — it is guaranteed monotonic within a JVM instance. Converting nanos to millis: `(System.nanoTime() - start) / 1_000_000L`. The Java snippet uses `currentTimeMillis` for readability; production code should use `nanoTime`.

**Enum pattern matching:** Rust's `match` on an enum is exhaustive — every variant must be covered. Adding a new variant to `CircuitState` forces updating every `match` in the codebase, preventing silent bugs. Java's `switch` on enum (Java 14+ expressions, Java 21 pattern switch) is becoming exhaustive with the `sealed` + `switch` combination: if the switch does not cover all cases of a sealed type, the compiler emits a warning (Java 21) or error (with `--enable-preview`). For `enum` (not sealed interface), Java's switch is not exhaustive by default — a missing case compiles silently. The safe pattern: add a `default` branch that `throw`s `IllegalStateException("unexpected state: " + state)`.

**Ownership and state mutation:** the `CircuitBreaker` struct in Rust takes `&mut self` on `call()` — a mutable reference that the borrow checker guarantees is exclusive. No other thread can read or write the circuit breaker while a call is in progress without explicit synchronization (wrapping in `Arc<Mutex<CircuitBreaker>>`). Java's `CircuitBreaker` class has no such compile-time guarantee — `failureCount` and `state` could be read by a thread while being written by another, producing a data race. Production Java circuit breaker implementations use `AtomicInteger` for `failureCount` and `AtomicReference<State>` for `state`, or synchronize the `call()` method. Rust exposes the concurrency bug at compile time; Java exposes it at runtime (or in load testing).

**Generic type parameters:** `fn call<F: FnOnce() -> Result<(), String>>` is a monomorphized generic — the compiler generates a specialized version of `call` for each distinct closure type at compile time. No virtual dispatch, no heap allocation, no boxing. Java's `<T> T call(Supplier<T> supplier)` is a reified generic at the call site but erased to `Object` in the bytecode — the JVM uses type erasure, so the actual type is lost at runtime. The JIT may devirtualize the `Supplier.get()` call if only one implementation is seen at a call site, but this is not guaranteed. For a hot path called millions of times per second (the circuit breaker `call()` method), the Rust version has consistently lower and more predictable overhead.
