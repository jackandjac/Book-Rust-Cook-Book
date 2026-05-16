# Book 4: System Design — Table of Contents

## Design Decisions
- **Single bilingual Book 4** (`SYSTEM_DESIGN.pdf`): each chapter contains both Rust and Java snippets side-by-side.
- `system-design-java/` directory not used — all content lives in `system-design/`.
- Scope: Interview SD + Distributed Systems Theory + Production Patterns.

---

### Chapter Template (every chapter must follow this structure)

```
# Chapter N: <Title>

> **Chapter goal:** <1-sentence goal>
> Code snippets are self-contained and compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).
> Each snippet demonstrates the core algorithm or data structure — not the full distributed system.

## 1. Requirements & Constraints
### 1.1 Functional Requirements
### 1.2 Non-Functional Requirements
### 1.3 Scale Estimates (back-of-envelope math — QPS, storage, bandwidth)

## 2. High-Level Architecture
(ASCII box-and-arrow diagram + numbered component list)

## 3. Component Deep-Dive
(One H3 per major component — prose + tradeoff notes, NO compilation requirement here)

## 4. Key Algorithms & Data Structures
### 4.1 Rust Implementation
```rust
// Self-contained, compiles with `rustc --edition 2024`
// Includes fn main() with assertions
```
### 4.2 Java Implementation
```java
// Self-contained, compiles with `javac --release 17`
// Includes public static void main with assertions
```

## 5. Tradeoffs & Alternatives

## 6. Failure Modes & Mitigations

## 7. Java vs Rust
> **Java vs Rust:** <comparison of how each language approaches the core algorithm>
```

### Code Snippet Rules (HARD CONSTRAINTS)
- Rust: `std` only, no external crates. Must compile: `rustc --edition 2024 snippet.rs`
- Java: `java.util.*` only, no external packages. Must compile: `javac --release 17 Snippet.java`
- Java: NO `assert` keyword (use `if (!cond) throw new AssertionError(...)`), NO `Stack` (use `ArrayDeque`)
- Java: Every class has `public static void main(String[] args)`
- Rust: Every snippet ends with `fn main()` with assertions
- Max ~80 lines per snippet; split into multiple named snippets if more needed
- Section 3 (Component Deep-Dive) is prose ONLY — no compilation requirement

### Draft → Review → Revise Protocol
1. **Draft agent**: Write full chapter following template
2. **Review agent**: Checks template compliance, math, snippet compilation (paste into rustc/javac), chapter overlap, tradeoffs completeness
3. **Revise agent**: Applies all review findings, marks state "complete"

---

### Chapter List

| # | File | Title | Domain |
|---|------|-------|--------|
| sd01 | sd01-rate-limiter.md | Rate Limiter | Interview SD |
| sd02 | sd02-url-shortener.md | URL Shortener / TinyURL | Interview SD |
| sd03 | sd03-consistent-hashing.md | Consistent Hashing | Distributed Theory |
| sd04 | sd04-cap-theorem.md | CAP Theorem & Consistency Models | Distributed Theory |
| sd05 | sd05-raft-consensus.md | Raft Consensus & Leader Election | Distributed Theory |
| sd06 | sd06-key-value-store.md | Distributed Key-Value Store (uses sd03–sd05) | Interview SD + Theory |
| sd07 | sd07-chat-system.md | Chat System (WebSocket, message ordering) | Interview SD |
| sd08 | sd08-news-feed.md | News Feed (fan-out, ranking) | Interview SD |
| sd09 | sd09-search-autocomplete.md | Search Autocomplete / Typeahead (Trie at scale) | Interview SD |
| sd10 | sd10-notification-system.md | Notification System (push/pull, fan-out) | Interview SD |
| sd11 | sd11-distributed-cache.md | Distributed Cache (eviction, consistency) | Interview SD + Production |
| sd12 | sd12-load-balancing.md | Load Balancing & API Gateway | Interview SD |
| sd13 | sd13-video-streaming.md | Video Streaming (CDN, chunking, adaptive bitrate) | Interview SD |
| sd14 | sd14-event-sourcing-cqrs.md | Event Sourcing & CQRS | Production Patterns |
| sd15 | sd15-circuit-breaker.md | Circuit Breaker, Retries & Observability | Production Patterns |
| sd16 | sd16-saga-idempotency.md | Saga Pattern & Idempotency | Production Patterns |

Total: 16 chapters in `system-design/` → one `SYSTEM_DESIGN.pdf`

---

### Chapter Dependency Order
Chapters are written and reviewed in this order to avoid forward references:
1. sd01, sd02 — independent interview problems
2. sd03 (Consistent Hashing) — foundational theory
3. sd04 (CAP), sd05 (Raft) — theory
4. sd06 (KV Store) — references sd03, sd04, sd05
5. sd07–sd13 — independent interview problems (may reference sd03, sd11)
6. sd14–sd16 — production patterns (reference sd07–sd13 examples)
