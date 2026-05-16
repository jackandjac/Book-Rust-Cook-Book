# Chapter 12: Load Balancing & API Gateway

> **Chapter goal:** Design a layer-4/layer-7 load balancing strategy with health checking, multiple balancing algorithms, and an API gateway handling auth, rate limiting, and routing for 500K RPS.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A load balancer distributes incoming requests across a pool of backend servers to maximize throughput, minimize latency, and prevent any single server from becoming overwhelmed. An API gateway sits logically in front of the load balancer and handles cross-cutting concerns — authentication, rate limiting, request transformation, SSL termination — before traffic ever reaches the backend.

The system must satisfy the following functional requirements:

- **Traffic distribution** — distribute requests across N backend servers using configurable algorithms (round robin, weighted round robin, least connections, IP hash, P2C).
- **Health checking** — continuously monitor backend health. Remove unhealthy backends from the pool automatically; re-add them after recovery.
- **Sticky sessions (optional)** — route requests from the same client to the same backend, using either IP hash or a cookie-based affinity header.
- **L7 routing** — route requests by URL path prefix, HTTP headers, or query parameters to different backend clusters (e.g., `/api/v1/search` → search cluster, `/api/v1/upload` → upload cluster).
- **API gateway features** — authentication (JWT validation, OAuth token introspection), rate limiting per user/IP/API key (see Chapter 1), request logging, distributed tracing header injection, response caching for idempotent requests, and basic protocol translation (gRPC ↔ REST).
- **SSL termination** — terminate TLS at the gateway tier; backend communication uses plain HTTP or mTLS on the internal network.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Added latency per request | < 5 ms p99 (including auth and rate-limit checks) |
| Availability | 99.999% (< 5 min/year downtime) |
| Peak throughput | 500,000 RPS |
| Backend failure handling | Remove failed backend within 3 consecutive health-check failures (~15 sec at 5-sec intervals) |
| Recovery | Re-add backend after 2 consecutive health-check successes (~10 sec) |
| Horizontal scalability | Load balancer tier scales linearly; adding LB nodes does not require backend changes |

### 1.3 Scale Estimates

| Dimension | Estimate |
|---|---|
| Total RPS | 500,000 |
| Backend clusters | 10 clusters × 50 servers each = 500 servers |
| Health check frequency | Every 5 seconds per server |
| Health checks per second (per LB node) | 500 servers / 5 sec = 100 checks/sec |
| Health checks per second (across 5 LB nodes) | 500 checks/sec total to each server |
| Concurrent connections per backend | 500K RPS / 500 servers × avg 10ms latency = 10 concurrent per server |
| LB node count | 5 nodes, each handling 100K RPS |

**Connection math:** With 500K RPS and average request latency of 10 ms:

```
Concurrent requests = RPS × latency = 500,000 × 0.01 = 5,000 concurrent
Per backend server  = 5,000 / 500  = 10 concurrent connections
```

Each LB node maintains an upstream connection pool to all 500 backends. With 10 connections per backend and 500 backends, each LB node manages up to 5,000 persistent connections — well within the limits of modern event-loop servers (tens of thousands of file descriptors).

---

## 2. High-Level Architecture

```
                         ┌────────────────────────────────────────────────────────┐
                         │               Client Requests                          │
                         └──────────────────────┬─────────────────────────────────┘
                                                │
                                         ┌──────▼──────┐
                                         │  GeoDNS /   │
                                         │  Anycast IP  │
                                         └──────┬──────┘
                                                │  (routes to nearest region)
                          ┌─────────────────────┼─────────────────────┐
                          │                     │                     │
                   ┌──────▼──────┐       ┌──────▼──────┐      ┌──────▼──────┐
                   │  Region: US │       │  Region: EU │      │  Region: AP │
                   │  L4 LB      │       │  L4 LB      │      │  L4 LB      │
                   │  (ECMP)     │       │  (ECMP)     │      │  (ECMP)     │
                   └──────┬──────┘       └─────────────┘      └─────────────┘
                          │  (L4: TCP/UDP routing by IP+port)
                   ┌──────▼──────────────────────────────────────────┐
                   │              L7 API Gateway Cluster              │
                   │                                                  │
                   │  ┌──────────────┐  ┌──────────────┐            │
                   │  │  Gateway A   │  │  Gateway B   │  ...       │
                   │  │  - JWT auth  │  │  - JWT auth  │            │
                   │  │  - Rate limit│  │  - Rate limit│            │
                   │  │  - Routing   │  │  - Routing   │            │
                   │  └──────┬───────┘  └──────┬───────┘            │
                   └─────────┼─────────────────┼────────────────────┘
                             │                 │
              ┌──────────────┼─────────────────┼──────────────┐
              │              │                 │              │
       ┌──────▼──────┐ ┌─────▼──────┐  ┌──────▼──────┐      │
       │  Service-A  │ │  Service-B │  │  Service-C  │      │
       │  50 servers │ │  30 servers│  │  20 servers │  ... │
       └─────────────┘ └────────────┘  └─────────────┘      │
                                                             │
                    ┌────────────────────────────────────────┘
                    │
             Health Check Loop:
             LB → GET /health → 200 OK → backend healthy
                             → timeout / 5xx → mark unhealthy
                             → 2× success after failure → re-add
```

**L4 vs L7 placement rationale:**

- **L4 at the network edge** — The L4 layer (AWS NLB, Google Cloud Load Balancing) operates at wire speed using ECMP (Equal-Cost Multi-Path) routing. It sees only IP+port, has no HTTP knowledge, and can sustain millions of packets per second with microsecond overhead. Its job is to spread TCP connections evenly across the small cluster of L7 gateway nodes.
- **L7 close to application** — The L7 API gateway (Nginx, Envoy, HAProxy, AWS ALB) inspects HTTP headers and payloads. It performs auth, rate limiting, and path-based routing, which require parsing the request. This per-request CPU cost is acceptable because the L7 tier only handles 500K HTTP requests/sec, not millions of raw packets.

---

## 3. Component Deep-Dive

### 3.1 L4 vs L7 Load Balancing

**Layer 4 (Transport Layer)** load balancers operate on TCP and UDP streams. They see source/destination IP addresses and ports but have no visibility into the HTTP payload. Routing decisions are made entirely from network headers, which allows L4 devices to operate at line rate with hardware-accelerated forwarding. Modern cloud L4 load balancers (AWS Network Load Balancer, Google Cloud Network Load Balancer) can sustain tens of millions of connections per second with sub-millisecond added latency.

Because L4 balancers do not terminate the TCP connection — they forward the packet stream transparently — the backend server sees the original client IP. This makes L4 balancers ideal for protocols that require low latency or where the application does its own protocol framing (WebSockets, gRPC long streams, non-HTTP TCP services).

**Layer 7 (Application Layer)** load balancers terminate the client connection, inspect the HTTP request, and open a new (or reuse a pooled) connection to the backend. This two-connection model adds a small fixed overhead (one extra TCP handshake if no connection reuse) but unlocks a rich set of capabilities: routing by URL path, HTTP method, or headers; inserting or modifying headers (adding `X-Forwarded-For`, injecting trace IDs); rewriting request bodies; performing authentication; SSL termination (so backends only handle plain HTTP); and WebSocket upgrade handling.

AWS Application Load Balancer, Nginx, HAProxy, and Envoy are common L7 implementations. For the 500K RPS target, a cluster of 5–10 Nginx or Envoy nodes each handling 50–100K RPS provides comfortable headroom.

**When to use each:** Use L4 for TCP services that are not HTTP, for latency-critical paths where even 1 ms matters, or as the first hop to direct TCP connections toward a smaller L7 cluster. Use L7 when you need path-based routing, auth, rate limiting, header manipulation, or any feature that requires reading the HTTP request.

### 3.2 Balancing Algorithms

**Round Robin** cycles through the backend list in order, sending one request to each server before looping back. It is trivially simple (just a cursor modulo N) and distributes request counts evenly — but completely ignores server load. A slow server that takes 10× longer to respond will accumulate 10× as many in-flight requests as a fast one, because round robin keeps sending it the same share of new requests.

**Weighted Round Robin** assigns each backend a weight proportional to its capacity. A backend with weight 2 receives twice as many requests as one with weight 1. Weights are typically set based on server CPU cores or provisioned throughput. This is appropriate when the backend fleet is heterogeneous (e.g., some servers have more RAM or faster CPUs) but still ignores runtime load.

**Least Connections** routes each new request to the backend with the fewest active (in-flight) connections. The load balancer tracks a counter per backend, incrementing it when a request is dispatched and decrementing it when the response completes. This algorithm naturally adapts to variable request duration: a server processing a slow database query accumulates connections and receives fewer new ones until it catches up. Least connections outperforms round robin when request durations vary significantly.

**IP Hash** computes a hash of the client's IP address and maps it to a backend using modulo or consistent hashing. The same client IP always maps to the same backend, providing session affinity without cookies. The weakness is that many enterprise clients appear behind a single NAT gateway IP, sending all their traffic to one backend and defeating load distribution. Consistent hashing (mapping the hash ring) minimizes disruption when backends are added or removed.

**Random** picks a backend uniformly at random. Counter-intuitively, random performs nearly as well as round robin in expectation (by the law of large numbers) and avoids the "herd" synchronization effect where all nodes pick the same "next" backend at the same time.

**Power of Two Choices (P2C)** — also called Least Response Time — picks two backends at random, queries their current load (active connections or response time), and routes to the better one. P2C provides near-optimal load distribution (comparable to the global minimum, provably within a constant factor) while requiring only O(1) work per request. It is particularly effective at avoiding slow servers: if one of the two randomly chosen backends is slow, the comparison immediately routes to the other one.

### 3.3 Health Checking

**Passive health checking** infers backend health from observed traffic. When a backend returns a 5xx response or the connection times out, the load balancer records a failure. After a configurable threshold of consecutive failures (e.g., 3), the backend is removed from the pool. Passive checking has zero overhead — no extra requests — but is reactive: the load balancer only discovers a failure when real user traffic hits the broken backend.

**Active health checking** sends periodic synthetic probe requests to each backend's `/health` endpoint (or any configured path). The probe is a lightweight HTTP GET; a `200 OK` response within a timeout (e.g., 2 seconds) is considered healthy. Active checking catches failures before user traffic hits them. The health check interval (5 seconds in our design) and failure/recovery thresholds determine how quickly the system reacts to failures and false positives.

**Failure and recovery thresholds** prevent thrashing. A backend is marked unhealthy after 3 consecutive failures (15 seconds of bad health), and re-added after 2 consecutive successes (10 seconds of confirmed recovery). This hysteresis prevents a backend that is briefly slow from rapidly toggling in and out of the pool.

**Circuit breaker integration** extends passive health checking with a state machine. In the CLOSED state, requests flow normally. After N failures in a window, the circuit transitions to OPEN and all requests to that backend are rejected immediately (without attempting connection) with a fallback response. After a configured timeout, it enters HALF-OPEN: one probe request is allowed through. If it succeeds, the circuit closes; if it fails, the circuit stays open. Circuit breakers prevent the "thundering herd" problem where a slow backend accumulates thousands of queued connections from a busy LB.

### 3.4 API Gateway Pattern

The API gateway is the single entry point for all client-facing traffic. It handles concerns that are common to every API endpoint, allowing backend services to focus purely on business logic.

**Authentication** — the gateway validates JWT tokens (checking signature, expiry, and issuer) or introspects OAuth tokens against the auth service. Only valid, unexpired tokens with the required scopes are forwarded to backends. Invalid requests are rejected at the gateway with `401 Unauthorized`, never reaching backend services.

**Authorization** — after authentication, the gateway checks RBAC (Role-Based Access Control) permissions. A user authenticated as `role:viewer` cannot reach endpoints that require `role:admin`. Authorization rules are loaded from a policy store (often a Redis cache backed by a database) and cached per token to avoid repeated lookups.

**Rate limiting** — per-user and per-IP rate limits are enforced at the gateway using the algorithms described in Chapter 1 (token bucket for burst, sliding window for strict per-minute limits). The gateway returns `429 Too Many Requests` with `Retry-After` headers when a client exceeds its quota.

**Request logging and distributed tracing** — every request receives a unique trace ID (generated or forwarded from the `X-Request-Id` header). The gateway logs the trace ID, client identity, path, response code, and latency. It injects the trace ID into the request as `X-Trace-Id` before forwarding to backends, enabling correlated logs across all services.

**Response caching** — for idempotent GET requests that are expensive to compute (e.g., static user profiles, product catalog), the gateway caches responses in Redis with a short TTL (seconds to minutes). Cache keys are derived from the normalized URL and relevant headers (e.g., `Accept-Language`).

**Protocol translation** — some backend services expose gRPC interfaces. The gateway translates incoming REST/JSON requests to gRPC protobuf calls and converts responses back to JSON. This allows mobile and browser clients to use REST while backend services use efficient binary protocols internally.

### 3.5 Sticky Sessions

Session affinity (sticky sessions) routes every request from a given client to the same backend server. This is necessary for stateful applications that store session state in memory on the server (e.g., traditional web applications, WebSocket connections that maintain per-connection state).

**IP hash** is the simplest method: hash the client IP and map it to a backend. The problem is NAT: enterprise networks, mobile carriers, and ISPs proxy millions of users behind a small number of public IPs. A carrier-grade NAT gateway may appear as a single IP to the load balancer, routing all of its users to the same backend and creating a severe hot spot.

**Cookie-based affinity** avoids the NAT problem. On the first request, the load balancer sets a short-lived cookie (e.g., `SERVERID=backend-3; Path=/; Max-Age=3600`) in the response. Subsequent requests from the same browser include this cookie, and the load balancer parses it to route to the identified backend. This works correctly even behind NAT because each browser maintains its own cookie jar.

**Consistent hashing on session token** is appropriate for API clients. The client's API key or session token (present in every request header) is hashed to a position on a virtual ring. Each backend owns a range of the ring. Adding or removing a backend invalidates only 1/N of the sessions (where N is the number of backends), rather than all sessions as with simple modulo hashing.

**Downside:** Sticky sessions defeat the primary goal of load balancing. If one backend is assigned to a disproportionately popular client (e.g., a large enterprise making 90% of all API calls), that backend becomes a hot spot regardless of what the load balancer does. For this reason, stateless application design — where any backend can serve any request — is strongly preferred.

### 3.6 Connection Pooling and Keep-Alive

Without connection pooling, the load balancer opens a fresh TCP connection to a backend for every request. At 500K RPS, this would require 500,000 TCP handshakes per second, each consuming ~1 ms of latency and CPU on both sides.

**Upstream keep-alive** maintains a pool of persistent HTTP/1.1 or HTTP/2 connections from the LB to each backend. When a request completes, the connection is returned to the pool rather than closed. The next request from any client can reuse it immediately. HTTP/2 multiplexes many concurrent requests over a single TCP connection, reducing the pool size further.

**Pool sizing:** The optimal pool size per backend is `max_concurrent_requests / max_concurrency_per_connection`. For HTTP/1.1 with pipelining, allow one in-flight request per connection, so the pool size equals the expected concurrent requests to that backend (roughly 10 per backend from our earlier calculation). For HTTP/2, one connection per backend often suffices.

**Client-side keep-alive** — the gateway also maintains persistent connections from clients, avoiding per-request handshakes for browser or API clients that make multiple calls in quick succession.

### 3.7 Geographic Load Balancing (GeoDNS)

At global scale, a single load balancer cluster is insufficient because network latency from distant clients (e.g., a Tokyo user hitting a US-East cluster) can dominate request latency. Geographic load balancing routes each client to the nearest regional cluster.

**GeoDNS** maps a DNS name (e.g., `api.example.com`) to different IP addresses based on the client's geographic location (determined from the resolver's IP). A Tokyo client resolves `api.example.com` to the AP-region IP; a London client resolves to the EU-region IP. DNS TTL is set to 60 seconds, so if a region fails, clients reroute within 1 minute.

**Anycast** is an alternative to GeoDNS. The same IP address is announced from multiple network locations via BGP. BGP routing naturally sends each client's packets to the nearest announcement point (PoP). Anycast is faster to fail over than GeoDNS (BGP convergence is seconds, not TTL-bounded) and requires no DNS tricks. Cloudflare and AWS Global Accelerator use Anycast.

**Failover:** If a regional cluster goes down, the failover path depends on the mechanism. GeoDNS requires the DNS operator to remove the unhealthy IP (manually or via health-checked DNS, as offered by AWS Route 53); clients reroute after TTL expiry (~60 seconds). Anycast failover is handled automatically by BGP as the unhealthy node stops announcing the prefix.

---

## 4. Key Algorithms & Data Structures

### 4.1 Rust Implementation

The Rust implementation uses `std` only. Three load balancing algorithms share a single `LoadBalancer` struct. Unhealthy backends are tracked with a `healthy` flag on the `Backend` struct. Round robin advances a cursor and skips unhealthy entries; least connections scans healthy backends for the minimum `active_connections`.

```rust
#[allow(dead_code)]
#[derive(Debug, Clone)]
struct Backend {
    id: usize,
    address: String,
    weight: u32,
    active_connections: u32,
    healthy: bool,
}

struct LoadBalancer {
    backends: Vec<Backend>,
    round_robin_idx: usize,
}

impl LoadBalancer {
    fn new(backends: Vec<Backend>) -> Self {
        LoadBalancer { backends, round_robin_idx: 0 }
    }

    // Advance cursor, skip unhealthy. Returns backend index.
    fn round_robin(&mut self) -> Option<usize> {
        let n = self.backends.len();
        for _ in 0..n {
            let idx = self.round_robin_idx % n;
            self.round_robin_idx += 1;
            if self.backends[idx].healthy {
                return Some(idx);
            }
        }
        None
    }

    // Weighted round robin: each backend receives weight-many slots.
    #[allow(dead_code)]
    fn weighted_round_robin(&mut self) -> Option<usize> {
        let total: u32 = self.backends.iter()
            .filter(|b| b.healthy)
            .map(|b| b.weight)
            .sum();
        if total == 0 { return None; }
        let slot = self.round_robin_idx as u32 % total;
        self.round_robin_idx += 1;
        let mut cumulative = 0u32;
        for (i, b) in self.backends.iter().enumerate() {
            if !b.healthy { continue; }
            cumulative += b.weight;
            if slot < cumulative {
                return Some(i);
            }
        }
        None
    }

    // Route to the healthy backend with the fewest active connections.
    fn least_connections(&self) -> Option<usize> {
        self.backends.iter().enumerate()
            .filter(|(_, b)| b.healthy)
            .min_by_key(|(_, b)| b.active_connections)
            .map(|(i, _)| i)
    }

    fn mark_unhealthy(&mut self, idx: usize) {
        self.backends[idx].healthy = false;
    }

    fn mark_healthy(&mut self, idx: usize) {
        self.backends[idx].healthy = true;
    }
}

fn main() {
    let backends = vec![
        Backend { id: 0, address: "s0".into(), weight: 1, active_connections: 5, healthy: true },
        Backend { id: 1, address: "s1".into(), weight: 2, active_connections: 2, healthy: true },
        Backend { id: 2, address: "s2".into(), weight: 1, active_connections: 8, healthy: false },
    ];
    let mut lb = LoadBalancer::new(backends);

    // Round robin: cursor starts at 0
    // idx=0 → healthy s0 → return 0
    // idx=1 → healthy s1 → return 1
    // idx=2 → unhealthy s2, skip; idx=3→0 → healthy s0 → return 0
    let r1 = lb.round_robin().unwrap();
    let r2 = lb.round_robin().unwrap();
    let r3 = lb.round_robin().unwrap();
    assert_eq!(r1, 0, "rr first should be s0");
    assert_eq!(r2, 1, "rr second should be s1");
    assert_eq!(r3, 0, "rr third should wrap to s0, skipping s2");

    // Unhealthy backend (s2, idx=2) must never be chosen
    assert_ne!(r1, 2);
    assert_ne!(r2, 2);
    assert_ne!(r3, 2);

    // Least connections: s0=5, s1=2 (healthy), s2=8 (unhealthy, excluded)
    // minimum among healthy is s1 with 2 connections
    let lc = lb.least_connections().unwrap();
    assert_eq!(lc, 1, "least_connections should pick s1 (2 connections)");

    // After marking s1 unhealthy, only s0 is healthy
    lb.mark_unhealthy(1);
    let lc2 = lb.least_connections().unwrap();
    assert_eq!(lc2, 0, "with s1 unhealthy, s0 should be chosen");

    // Re-add s1
    lb.mark_healthy(1);
    let lc3 = lb.least_connections().unwrap();
    assert_eq!(lc3, 1, "after recovery, s1 (2 conn) beats s0 (5 conn)");

    println!("All load balancer tests PASSED");
}
```

**Key design notes:**

- `round_robin` loops up to `n` times (not just once), which correctly handles the case where multiple backends are unhealthy and the cursor must skip several slots to find a healthy one. If all backends are unhealthy, it returns `None` after exhausting all slots.
- `weighted_round_robin` computes the total weight of healthy backends and maps the cursor position to a backend using cumulative weights. This correctly biases the distribution toward higher-weight backends.
- `least_connections` uses `min_by_key` on an iterator over healthy backends — idiomatic Rust, O(N) scan, which is acceptable for pools of hundreds of backends.
- Mutation of backend health uses direct index access (`self.backends[idx].healthy = false`), which Rust's borrow checker permits because no other reference to `backends` is held during the mutation.

### 4.2 Java Implementation

The Java implementation mirrors the Rust one. `Backend` is a `record` for immutability; `mark_healthy`/`mark_unhealthy` replace the element in the `ArrayList` using the `withHealthy` wither. `Optional<Integer>` replaces `Option<usize>`.

```java
import java.util.*;

public class LoadBalancer {

    record Backend(int id, String address, int weight, int activeConnections, boolean healthy) {
        Backend withHealthy(boolean h) {
            return new Backend(id, address, weight, activeConnections, h);
        }
    }

    private final List<Backend> backends;
    private int rrIndex = 0;

    public LoadBalancer(List<Backend> backends) {
        this.backends = new ArrayList<>(backends);
    }

    // Advance cursor, skip unhealthy. Returns backend index.
    public Optional<Integer> roundRobin() {
        int n = backends.size();
        for (int attempt = 0; attempt < n; attempt++) {
            int idx = rrIndex % n;
            rrIndex++;
            if (backends.get(idx).healthy()) {
                return Optional.of(idx);
            }
        }
        return Optional.empty();
    }

    // Weighted round robin: each backend receives weight-many slots.
    public Optional<Integer> weightedRoundRobin() {
        int total = backends.stream()
            .filter(Backend::healthy)
            .mapToInt(Backend::weight)
            .sum();
        if (total == 0) return Optional.empty();
        int slot = rrIndex % total;
        rrIndex++;
        int cumulative = 0;
        for (int i = 0; i < backends.size(); i++) {
            Backend b = backends.get(i);
            if (!b.healthy()) continue;
            cumulative += b.weight();
            if (slot < cumulative) return Optional.of(i);
        }
        return Optional.empty();
    }

    // Route to the healthy backend with the fewest active connections.
    public Optional<Integer> leastConnections() {
        int bestIdx = -1;
        int bestConn = Integer.MAX_VALUE;
        for (int i = 0; i < backends.size(); i++) {
            Backend b = backends.get(i);
            if (b.healthy() && b.activeConnections() < bestConn) {
                bestConn = b.activeConnections();
                bestIdx = i;
            }
        }
        return bestIdx >= 0 ? Optional.of(bestIdx) : Optional.empty();
    }

    public void markUnhealthy(int idx) {
        backends.set(idx, backends.get(idx).withHealthy(false));
    }

    public void markHealthy(int idx) {
        backends.set(idx, backends.get(idx).withHealthy(true));
    }

    // Assertion helper (no assert keyword per book conventions)
    private static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError(msg);
    }

    public static void main(String[] args) {
        List<Backend> pool = List.of(
            new Backend(0, "s0", 1, 5, true),
            new Backend(1, "s1", 2, 2, true),
            new Backend(2, "s2", 1, 8, false)
        );
        LoadBalancer lb = new LoadBalancer(pool);

        // Round robin: s2 is unhealthy, must be skipped
        int r1 = lb.roundRobin().orElseThrow();
        int r2 = lb.roundRobin().orElseThrow();
        int r3 = lb.roundRobin().orElseThrow();
        check(r1 == 0, "rr first should be s0 (idx 0), got " + r1);
        check(r2 == 1, "rr second should be s1 (idx 1), got " + r2);
        check(r3 == 0, "rr third should wrap to s0, got " + r3);
        check(r1 != 2 && r2 != 2 && r3 != 2, "unhealthy s2 must never be chosen");

        // Least connections: s0=5, s1=2 (healthy), s2=8 (unhealthy)
        int lc = lb.leastConnections().orElseThrow();
        check(lc == 1, "least_connections should pick s1 (idx 1, 2 conn), got " + lc);

        // Mark s1 unhealthy; only s0 remains
        lb.markUnhealthy(1);
        int lc2 = lb.leastConnections().orElseThrow();
        check(lc2 == 0, "with s1 unhealthy, s0 (idx 0) should be chosen, got " + lc2);

        // Recover s1
        lb.markHealthy(1);
        int lc3 = lb.leastConnections().orElseThrow();
        check(lc3 == 1, "after recovery s1 (2 conn) beats s0 (5 conn), got " + lc3);

        System.out.println("All load balancer tests PASSED");
    }
}
```

**Key design notes:**

- `record Backend(...)` is Java 16+ syntax; the `--release 17` target supports it. Records are immutable by design; `withHealthy` constructs a new record, and `backends.set(idx, ...)` replaces the element in the `ArrayList`.
- The constructor wraps the input in `new ArrayList<>(backends)` so that `backends.set()` is supported even when the caller passes `List.of(...)` (which is immutable).
- `Optional<Integer>` is used instead of returning -1 or null, matching the book's idiom of making the absence of a value explicit in the type signature.

---

## 5. Tradeoffs

### 5.1 Algorithm Comparison

| Algorithm | Simplicity | Load Balance Quality | Sticky | Overhead | Best For |
|---|---|---|---|---|---|
| Round Robin | High | Good (even counts) | No | O(1) | Homogeneous servers, short requests |
| Weighted RR | Medium | Good (capacity-aware) | No | O(1) | Heterogeneous server capacities |
| Least Connections | Medium | Excellent (adapts to load) | No | O(N) scan | Variable-length requests (APIs, DB queries) |
| IP Hash | Medium | Poor (NAT collapses IPs) | Yes (by IP) | O(1) | Stateful apps, when sticky is required |
| P2C (Power of Two) | Medium | Excellent (near-optimal) | No | O(1) | High-RPS, heterogeneous backends, avoids slow outliers |

**When to use P2C over Least Connections:** Least connections requires a global scan (O(N) per request) which is fine for a few hundred backends but becomes a bottleneck at thousands. P2C samples only 2 backends, making it O(1) while achieving near-optimal distribution.

### 5.2 L4 vs L7

| Dimension | L4 | L7 |
|---|---|---|
| Throughput | Millions of packets/sec (hardware speed) | Hundreds of thousands of req/sec (software) |
| Latency added | < 100 µs | 1–5 ms (parsing, auth, rate limit) |
| Routing intelligence | IP+port only | URL path, headers, cookies, body |
| SSL termination | No (pass-through) | Yes |
| Protocol support | Any TCP/UDP | HTTP/1.1, HTTP/2, WebSocket, gRPC |
| Use case | Edge distribution, non-HTTP services | API gateway, auth, rate limiting, routing |

### 5.3 Software vs Hardware Load Balancers

**Nginx / HAProxy** — open-source, software load balancers. Nginx is primarily a web server/reverse proxy with load balancing added; HAProxy is purpose-built for high-availability load balancing with more granular health check and ACL configuration. Both handle hundreds of thousands of RPS on commodity hardware. Deployable anywhere; no vendor lock-in.

**Envoy** — a modern proxy built for service mesh use cases. Written in C++, it supports HTTP/2 and gRPC natively, has first-class distributed tracing integration (Zipkin, Jaeger), and is the data plane for Istio. Configuration is dynamic via the xDS API, enabling zero-downtime routing changes. Preferred in Kubernetes environments.

**AWS ALB / NLB** — managed cloud load balancers. Zero operational burden (no servers to patch); integrated with AWS IAM, WAF, ACM for SSL certificates, and CloudWatch for metrics. ALB is L7 (HTTP/HTTPS/WebSocket); NLB is L4 (TCP/UDP) with ultra-low latency. Trade flexibility for simplicity.

**Hardware LBs (F5 BIG-IP)** — dedicated appliances with FPGA-accelerated packet processing, capable of sustaining millions of connections per second. Extremely expensive ($100K–$1M per appliance), complex to configure, and typically used only in financial services or telecom where sub-microsecond latency is required and cloud is not an option.

---

## 6. Failure Modes & Mitigations

### 6.1 Load Balancer as Single Point of Failure

**Problem:** If the load balancer itself goes down, all traffic to all backends fails. At 500K RPS, even a 10-second outage drops 5 million requests.

**Mitigation — Active-Passive HA with Virtual IP (VRRP):** Deploy a primary LB and a hot standby. Both nodes share a Virtual IP (VIP) that clients connect to. The primary broadcasts VRRP keepalives to the standby. If the primary fails to send keepalives for 1–2 seconds, the standby takes ownership of the VIP and announces it via gratuitous ARP. Failover completes in 1–3 seconds. Active-active pairs (both nodes handling traffic, both monitoring each other) reduce failover time further.

**Mitigation — DNS-based failover:** Health-checked DNS (AWS Route 53 with health checks, or Cloudflare) removes unhealthy LB IPs from DNS responses. Combined with a low TTL (60 seconds), clients fail over within about 1 minute. Appropriate as a secondary failover mechanism, not primary (1 minute of downtime violates 99.999% SLA).

### 6.2 Slow Backend Accumulating Connections

**Problem:** A backend that responds slowly (due to GC pauses, lock contention, or a slow database query) accumulates in-flight connections. Round robin or weighted round robin keeps sending new requests to it at the same rate as healthy backends, compounding the problem. Eventually, the slow backend's connection queue fills, requests time out, and errors cascade.

**Mitigation — Timeouts:** Configure per-request upstream timeouts (e.g., 5 seconds). When a backend does not respond within the timeout, the LB returns an error to the client and decrements the active-connection count. This prevents indefinite queue growth.

**Mitigation — P2C algorithm:** By comparing two randomly sampled backends, P2C naturally avoids routing to the slow outlier. If one of the two selected backends is slow (high active connections), P2C routes to the other. The slow backend receives exponentially fewer new requests and drains.

**Mitigation — Adaptive concurrency limits:** The LB tracks the P99 response time per backend. If a backend's P99 exceeds a threshold (e.g., 2× the cluster average), the LB reduces the max concurrent requests it sends to that backend (shed load before the queue fills).

### 6.3 Health Check False Positive

**Problem:** A backend returns `200 OK` on `/health` but is severely degraded — CPU saturated at 99%, or a critical internal dependency (the database) is unreachable. The LB believes the backend is healthy and continues routing traffic to it. Users experience failures or extreme latency even though the backend is "healthy."

**Mitigation — Rich health check responses:** The `/health` endpoint should check internal dependencies and return a degraded status (HTTP 200 with `{"status":"degraded"}`, or HTTP 503) when the backend cannot serve traffic. The LB should treat 503 as unhealthy.

**Mitigation — Canary probes:** Periodically route real synthetic test requests (not just health pings) through the backend and measure their response time and correctness. A backend that passes `/health` but fails real requests is removed from the pool.

**Mitigation — SLO-based ejection (Outlier Detection):** Envoy's outlier detection tracks 5xx rates and latency percentiles per backend. A backend that generates 5xx errors above a configurable threshold (e.g., 50% of requests in the last 30 seconds) is ejected from the pool regardless of `/health` status.

### 6.4 SSL Certificate Expiry

**Problem:** The API gateway performs SSL termination. If the TLS certificate expires, all HTTPS traffic fails immediately with an SSL handshake error. This is a silent risk — the system works fine until midnight on the expiry date, then fails completely.

**Mitigation — Automated renewal (Let's Encrypt + certbot):** Let's Encrypt issues 90-day certificates. Certbot (or its equivalent in cloud environments — AWS Certificate Manager, cert-manager in Kubernetes) renews certificates automatically when they are within 30 days of expiry. Renewed certificates are hot-reloaded into Nginx/Envoy without restarting.

**Mitigation — Monitoring and alerting:** Track certificate expiry dates as a metric. Alert at 30 days, 14 days, and 7 days before expiry. Never allow a certificate to expire unnoticed.

**Mitigation — Certificate rotation runbook:** Even with automation, document the manual renewal process. If automation fails, the on-call engineer must be able to renew the certificate manually within minutes.

### 6.5 Thundering Herd on Backend Restart

**Problem:** A backend server crashes and is removed from the pool. After the failure is resolved, it restarts and passes two consecutive health checks — the load balancer re-adds it to the active pool. All load balancer nodes now immediately route a full share of traffic to the recovering backend simultaneously. But the backend's internal caches (in-process object caches, JVM JIT compilation) are cold; its connection pools to the database are not yet established; and its thread pools are idle. The sudden surge of traffic causes the newly restarted backend to immediately become overloaded, potentially crashing again or triggering a cascade where the extra load spills onto neighboring backends.

**Mitigation — Slow-start (gradual ramp):** Most L7 load balancers (Nginx, HAProxy, Envoy) support a slow-start mode for newly added backends. Instead of immediately receiving a full share of traffic, the backend's effective weight starts at a small fraction (e.g., 10%) of its target weight and increases linearly over a configurable warm-up period (30–120 seconds). HAProxy calls this `slow-start`; Envoy calls it `slow_start_config`. During warm-up, the backend receives enough traffic to fill its caches and establish database connections without being overwhelmed.

**Mitigation — Capacity-aware onboarding:** The health check recovery condition can be extended beyond simple `/health` polling. Before the backend is re-added, the load balancer waits until the backend's self-reported readiness probe (`/ready`) returns `200 OK`, indicating that the application has completed its initialization (cache warm-up, connection pool establishment, JIT compilation of hot paths). Kubernetes uses exactly this model: the `livenessProbe` checks that the process is alive, while the `readinessProbe` checks that the process is ready to serve traffic. Only when the readiness probe passes does Kubernetes add the pod to the `Service` endpoint set.

---

## 7. Java vs Rust: Language Comparison

This chapter illustrates several points where Java and Rust make different trade-offs in expressing the same algorithm.

**`Optional<Integer>` vs `Option<usize>`**

Both languages model "no result" without null pointers. Rust's `Option<usize>` is a zero-cost enum — the compiler eliminates the wrapper entirely in release builds when it can prove no null check is needed. Java's `Optional<Integer>` is a heap-allocated wrapper object; `Integer` itself is a boxed primitive (another heap allocation). For a high-throughput load balancer called millions of times per second, this double allocation in Java is measurable. In performance-critical Java, the idiom of returning `-1` as a sentinel (sacrificing type safety) is often preferred for inner loops, though `Optional` is cleaner for API boundaries.

**`record` immutability vs Rust structs**

Java `record` enforces immutability of its components at the language level — all fields are final, no setters are generated. Updating a backend's health requires constructing a new record and calling `List.set()`. This is a functional style: safe for concurrent reads (no synchronization needed to read the record fields) but less cache-friendly than mutating a field in place. Rust structs are mutable by default when the binding is `mut`; `self.backends[idx].healthy = false` is a direct in-place mutation, which is more cache-efficient. Rust's ownership system ensures no other code is concurrently reading the mutated backend.

**`ArrayList` vs `Vec`**

Both are dynamically sized contiguous arrays backed by heap memory with amortized O(1) append. The key difference is that `Vec<Backend>` stores `Backend` structs inline (value semantics), while `ArrayList<Backend>` stores references to heap-allocated `Backend` objects (since Java records are objects). The Rust `Vec` is therefore more cache-friendly for iteration: all `Backend` data is packed together in memory, reducing cache misses when scanning backends for `least_connections`.

**Iterator chaining**

Rust's `self.backends.iter().filter(|(_, b)| b.healthy).min_by_key(...)` and Java's `backends.stream().filter(Backend::healthy).min(Comparator.comparingInt(...))` are equivalent in expressiveness. Rust's iterators are zero-cost abstractions compiled to the same machine code as an explicit loop; Java streams incur slight overhead from lambda capture and intermediate object allocation (mitigated by JIT after warmup).

**Mutation with borrow rules**

In the Rust implementation, `mark_unhealthy` takes `&mut self` and directly mutates `self.backends[idx].healthy`. The borrow checker ensures that no other `&Backend` reference is live at the point of mutation — if `least_connections` were called and its returned reference held across a `mark_unhealthy` call, the code would not compile. In Java, `markUnhealthy` calls `backends.set(idx, ...)`, which replaces the reference in the `ArrayList`. Any existing reference to the old `Backend` record remains valid (pointing to the now-stale object), since Java has no ownership semantics — a potential source of subtle bugs in concurrent code if the stale reference is used without re-reading from the list.

---

*End of Chapter 12.*
