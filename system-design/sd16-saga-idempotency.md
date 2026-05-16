# Chapter 16: Saga Pattern & Idempotency

> **Chapter goal:** Coordinate distributed transactions across microservices using the Saga pattern — choreography vs orchestration — with idempotency keys to safely handle retries without double-processing.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 The Distributed Transaction Problem

A monolith can wrap multiple database operations in a single ACID transaction: either all changes commit or all roll back. Microservices cannot do this. Each service owns its own database; cross-service transactions that span multiple databases require coordination protocols.

**Two-Phase Commit (2PC)** is the classical solution: a coordinator sends a "prepare" to all participants, waits for acknowledgments, then sends "commit." It provides strong consistency, but it has fatal weaknesses at microservice scale:

- **Blocking:** participants hold database locks during the prepare phase, blocking all other writes on those rows. At 10,000 transactions/second, seconds-long blocks cause cascading timeouts.
- **Coordinator SPOF:** if the coordinator crashes after "prepare" but before "commit," all participants are stuck holding locks indefinitely — the system is unavailable until the coordinator recovers.
- **Tight coupling:** all services must implement the 2PC protocol on the same network. A slow or unreachable participant blocks the entire transaction.

### 1.2 The Saga Solution

A Saga is a sequence of local transactions, each of which publishes a message or event that triggers the next step. If any step fails, the saga executes compensating transactions in reverse — semantic undos of completed steps.

**Example: e-commerce order saga**

| Step | Service | Action | Compensation |
|---|---|---|---|
| 1 | Inventory | Reserve items | Release reservation |
| 2 | Payment | Charge card | Refund payment |
| 3 | Shipping | Schedule shipment | Cancel shipment |
| 4 | Order | Confirm order | Cancel order |

If Payment (step 2) fails: Shipping has not run yet, so only step 1's compensation runs — releasing the inventory reservation. No locks were held during the coordination; each service committed its local transaction independently.

### 1.3 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Throughput | 10,000 orders/minute = ~167 orders/sec |
| Local transaction count | 4 steps × 167/sec = ~668 local transactions/sec |
| Saga state persistence | Durable (DB write per step transition) |
| Idempotency key TTL | 24 hours (Redis or DB) |
| Compensation latency | < 30 seconds for full compensation of a 4-step saga |
| Saga visibility | Every saga state change queryable for support/audit |

**Kafka event rate estimate:**

Each saga step in choreography emits one event on success and one compensating event on failure. At peak (happy path, no failures):

```
167 orders/sec × 4 steps × 1 event/step = 668 events/sec to Kafka
```

With 1 KB average event size:

```
668 events/sec × 1 KB = ~668 KB/sec = ~0.65 MB/sec Kafka write throughput
```

This is well within the capacity of a single Kafka broker (hundreds of MB/sec). Three brokers with replication factor 3 and four partitions per topic provides adequate headroom for 10× traffic growth with no re-architecture.

**Idempotency key store size:**

Each idempotency key entry is ~200 bytes (key string + response string + TTL metadata). At 668 operations/sec with 24-hour TTL:

```
668/sec × 86,400 sec × 200 bytes ≈ 11.5 GB
```

Redis with 12–16 GB of memory handles this comfortably with automatic TTL eviction.

---

## 2. Architecture

### 2.1 Choreography-Based Saga

In choreography, services react to events. There is no central orchestrator; each service knows what to do when it sees a certain event.

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                    Event Bus (Kafka)                             │
  └─────────┬──────────────┬──────────────┬──────────────┬──────────┘
            │              │              │              │
     OrderPlaced    InventoryReserved  PaymentCharged  ShippingArranged
            │              │              │              │
            ▼              ▼              ▼              ▼
      Inventory       Payment          Shipping         Order
      Service         Service          Service          Service
      (reserves)      (charges)        (schedules)      (confirms)
            │              │
            │  FAILURE PATH
            │              │
     InventoryReleased  PaymentFailed
            ▲              │
            └──────────────┘
        InventoryService listens PaymentFailed → releases reservation
```

**Happy path:** `OrderPlaced` → `InventoryReserved` → `PaymentCharged` → `ShippingArranged` → `OrderConfirmed`

**Failure path:** `OrderPlaced` → `InventoryReserved` → `PaymentFailed` → `InventoryService` listens `PaymentFailed` → publishes `InventoryReleased`

### 2.2 Orchestration-Based Saga

In orchestration, a central `SagaOrchestrator` explicitly commands each service and handles failures.

```
                      ┌──────────────────────────┐
                      │    Saga Orchestrator      │
                      │   (state machine in DB)   │
                      └────────────┬─────────────┘
                                   │
             ┌─────────────────────┼───────────────────────┐
             │                     │                       │
             ▼                     ▼                       ▼
    InventoryService         PaymentService         ShippingService
    Reserve / Release        Charge / Refund         Schedule / Cancel

  Orchestrator state:
  PENDING → RUNNING(step=1) → RUNNING(step=2) → RUNNING(step=3)
          → RUNNING(step=4) → COMPLETED

  On failure at step 2:
  RUNNING(step=2) → COMPENSATING(step=1) → FAILED
```

---

## 3. Component Deep-Dive

### 3.1 Choreography vs Orchestration

**Choreography** is the decentralized approach. Each service subscribes to relevant events on the event bus (Kafka, RabbitMQ, NATS) and publishes its own events when done. Services do not call each other directly; they communicate entirely through events.

*Pros:* loose coupling — services are unaware of each other's existence; no SPOF — any service can restart independently without halting the saga; easy horizontal scaling — add more consumer instances.

*Cons:* the saga flow is implicit and distributed across all participating services; debugging a failed saga requires correlating events across multiple service logs; adding a new step in the saga requires modifying multiple services; hard to visualize the overall workflow without a dedicated trace.

**Orchestration** uses a dedicated saga orchestrator — a service or component that knows the full sequence of steps and drives execution. The orchestrator persists its state to a database at every step transition, making it resilient to crashes.

*Pros:* the full saga flow is visible in one place (the orchestrator's state machine); failures are centralized — the orchestrator decides what to compensate; easier to add steps without modifying existing services; straightforward saga status queries ("what step is this order on?").

*Cons:* the orchestrator is an additional component to build, deploy, and operate; it becomes a coupling point — all services must integrate with it; if the orchestrator is slow, it throttles all sagas.

**When to use which:** choreography is appropriate for simple sagas with 2–3 steps and teams that value loose coupling over visibility. Orchestration is appropriate for complex sagas with 4+ steps, strict audit requirements, or teams that need end-to-end saga visibility in a single dashboard.

### 3.2 Compensating Transactions

A compensating transaction is a business-level undo of a completed step. It is not a database rollback — the local transaction already committed. Compensation is a new, forward transaction that semantically reverses the effect.

**Examples:**
- "Reserve inventory" is compensated by "Release inventory reservation."
- "Charge payment" is compensated by "Issue refund."
- "Schedule shipment" is compensated by "Cancel shipment request" (if not yet shipped) or "Initiate return" (if already shipped).

**Design constraints:**

- **Every forward step must have a compensating step.** Before implementing a saga, define all compensations up front. A step without a compensation creates a saga that cannot be undone.
- **Compensations must be idempotent.** The compensation may be executed more than once (network retry, worker restart). Issuing a refund twice is a severe business error. Use idempotency keys on every compensation call.
- **Compensations are not guaranteed to run in order.** Design them to be commutative where possible: releasing inventory and canceling a shipment should not depend on each other.
- **Compensations may fail.** If the Payment service is down, the refund cannot be issued. Compensations must be retried until success. If a compensation cannot succeed after repeated retries, the saga enters a "stuck" state requiring human intervention.

### 3.3 Idempotency Keys

Idempotency ensures that calling an operation multiple times with the same input produces the same result as calling it once. This is essential in distributed systems where networks drop responses, causing callers to retry — potentially executing the same operation twice.

**Pattern:**
1. The client (or saga orchestrator) generates a unique idempotency key — typically a UUID derived from the saga ID and step name: `saga-{saga_id}-step-{step_name}`.
2. Before executing the operation, the server checks whether the key exists in an idempotency store (Redis, DynamoDB, or a DB table). If it does, return the cached response immediately — do not re-execute.
3. After executing the operation, store the result under the key with a TTL (24 hours).
4. On retry with the same key, return the cached response.

**Where to apply:**
- Payment API calls (double-charge is a P1 incident).
- Inventory reservation calls (double-reservation creates phantom stock).
- Email/SMS notifications (sending a confirmation twice is embarrassing).
- Every compensation call (double-refund, double-cancellation).

**Key format:** include enough context to be globally unique without being too fine-grained. `user_{user_id}_order_{order_id}_charge` is a good format for the payment step. Do not use just `order_{order_id}` — if the order is retried for different reasons (address update vs payment retry), the key must be distinct.

**Sequence diagram — idempotency key on retry:**

```
First request:
  Orchestrator  →  PaymentService: POST /charge  { idempotency-key: saga-42-charge }
  PaymentService: key not found in store → execute charge → $42.50 debited
  PaymentService: store { "saga-42-charge" → "charged:42.50" } with TTL 24h
  PaymentService  →  Orchestrator: 200 OK { charged: 42.50 }
  (response lost — network timeout)

Retry (30 seconds later):
  Orchestrator  →  PaymentService: POST /charge  { idempotency-key: saga-42-charge }
  PaymentService: key FOUND in store → return cached response immediately
  PaymentService  →  Orchestrator: 200 OK { charged: 42.50 }  [no charge executed]

Result: customer charged exactly once; orchestrator correctly advances to next step.
```

Without the idempotency key, the retry would charge the customer a second time — a P1 incident requiring manual refund and customer communication.

### 3.4 Saga State Machine

The orchestrated saga maintains an explicit state machine, persisted to the database at every transition:

| State | Meaning |
|---|---|
| `PENDING` | Saga created but not yet started |
| `RUNNING` | Actively executing a forward step |
| `COMPLETED` | All steps succeeded |
| `COMPENSATING` | A step failed; running compensations backward |
| `FAILED` | All compensations complete; saga did not succeed |
| `STUCK` | A compensation failed and cannot be retried automatically |

State persistence ensures that orchestrator crashes are recoverable. On restart, the orchestrator loads all sagas in `RUNNING` or `COMPENSATING` state and resumes from the last known step. Combined with idempotency keys on every step, re-executing a step that already succeeded is safe.

### 3.5 Failure Scenarios

**Step failure:** the current forward step fails (service unavailable, business rule violation). The orchestrator transitions to `COMPENSATING` and begins executing compensations in reverse order — from the last successfully completed step backward.

**Compensation failure:** the compensation call returns an error. The orchestrator retries with exponential backoff. After N retries, the saga transitions to `STUCK` and an alert fires. A human operator investigates and manually triggers the compensation or escalates to a customer support workflow.

**Idempotency on compensation:** compensations must carry their own idempotency keys. A compensation may be retried dozens of times before the downstream service recovers. Each retry must be idempotent.

**Timeout:** each forward step has a deadline (e.g., 30 seconds). If the step does not complete within the deadline — because the service is slow or the event was lost — the orchestrator treats it as a failure and begins compensation. Timeouts prevent sagas from waiting indefinitely.

### 3.6 Outbox Pattern

A common correctness bug in event-driven systems: a service processes a command, updates its database, then tries to publish an event to Kafka. If the process crashes between the DB commit and the Kafka publish, the event is lost. Downstream services never learn that the step completed, and the saga stalls.

The Outbox pattern solves this with a single database transaction:

```sql
BEGIN;
  -- 1. Apply the business change
  UPDATE inventory SET reserved = reserved + 5 WHERE item_id = 42;
  -- 2. Write the event to the outbox table (same transaction)
  INSERT INTO outbox (event_id, event_type, payload)
  VALUES (gen_random_uuid(), 'InventoryReserved', '{"item_id": 42, "qty": 5}');
COMMIT;
```

A separate "relay" process (or the Debezium CDC connector) reads from the `outbox` table and publishes events to Kafka. If the relay crashes after publishing but before marking the event as sent, it republishes — which is why downstream consumers must be idempotent. The outbox provides **at-least-once** delivery with **local ACID** guarantee: the event will always be published if the DB transaction committed.

**Relay implementation options:**

- **Polling relay:** a background thread queries `SELECT * FROM outbox WHERE published = false ORDER BY created_at LIMIT 100` every 500ms, publishes to Kafka, then marks rows as published. Simple to implement; adds polling load to the DB; introduces up to 500ms relay latency. Adequate for most applications.

- **CDC with Debezium:** a Change Data Capture connector (Debezium) tails the PostgreSQL WAL (Write-Ahead Log) or MySQL binlog in real time. Every `INSERT INTO outbox` appears as a CDC event within milliseconds, without polling. Debezium publishes to Kafka directly. Advantages: near-zero latency, no polling load, works even if the relay service is restarted mid-batch. Disadvantages: requires the DB to expose its replication slot or binlog, adds operational complexity (Kafka Connect cluster, connector configuration, schema registry). For sagas where step latency matters (customer-facing orders), CDC is worth the investment.

**Scale note:** at 167 orders/second with 4 saga steps, each step emitting 2 events (one for the action, one for the completion acknowledgment), the outbox produces:

```
167 orders/sec × 4 steps × 2 events = 1,336 outbox rows/sec
```

PostgreSQL easily handles this insert rate. The outbox table needs periodic cleanup of `published = true` rows older than 24 hours to prevent unbounded growth.

---

## 4. Key Algorithms

### 4.1 Rust: Saga Orchestrator

```rust
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
enum SagaStep { ReserveInventory, ChargePayment, ArrangeShipping, ConfirmOrder }

#[derive(Debug, Clone, PartialEq)]
enum SagaStatus { Pending, Running, Completed, Compensating, Failed }

#[derive(Debug, Clone)]
struct SagaInstance {
    id: u64,
    current_step: usize,
    steps: Vec<SagaStep>,
    status: SagaStatus,
    compensated_steps: Vec<SagaStep>,  // stack of completed steps (for compensation)
}

struct SagaOrchestrator {
    sagas: HashMap<u64, SagaInstance>,
    idempotency_store: HashMap<String, String>,  // key → cached response
}

impl SagaOrchestrator {
    fn new() -> Self {
        SagaOrchestrator {
            sagas: HashMap::new(),
            idempotency_store: HashMap::new(),
        }
    }

    fn start_saga(&mut self, id: u64) -> &SagaInstance {
        let saga = SagaInstance {
            id,
            current_step: 0,
            steps: vec![
                SagaStep::ReserveInventory,
                SagaStep::ChargePayment,
                SagaStep::ArrangeShipping,
                SagaStep::ConfirmOrder,
            ],
            status: SagaStatus::Running,
            compensated_steps: vec![],
        };
        self.sagas.insert(id, saga);
        self.sagas.get(&id).unwrap()
    }

    // Forward step succeeded: record it and advance
    fn step_success(&mut self, id: u64) {
        if let Some(saga) = self.sagas.get_mut(&id) {
            let step = saga.steps[saga.current_step].clone();
            saga.compensated_steps.push(step);  // push onto compensation stack
            saga.current_step += 1;
            if saga.current_step == saga.steps.len() {
                saga.status = SagaStatus::Completed;
            }
        }
    }

    // Forward step failed: begin compensation
    fn step_failure(&mut self, id: u64) {
        if let Some(saga) = self.sagas.get_mut(&id) {
            saga.status = SagaStatus::Compensating;
        }
    }

    // Compensate last successful step; transition to Failed when done
    fn compensate_next(&mut self, id: u64) {
        if let Some(saga) = self.sagas.get_mut(&id) {
            saga.compensated_steps.pop();  // compensate top-of-stack (most recent)
            if saga.compensated_steps.is_empty() {
                saga.status = SagaStatus::Failed;
            }
        }
    }

    fn check_idempotent(&self, key: &str) -> Option<&str> {
        self.idempotency_store.get(key).map(|s| s.as_str())
    }

    fn store_idempotent(&mut self, key: String, response: String) {
        self.idempotency_store.insert(key, response);
    }
}

fn main() {
    let mut orch = SagaOrchestrator::new();
    orch.start_saga(1);

    // Happy path: all 4 steps succeed
    orch.step_success(1); // ReserveInventory → pushed to compensation stack
    orch.step_success(1); // ChargePayment
    orch.step_success(1); // ArrangeShipping
    orch.step_success(1); // ConfirmOrder → current_step == steps.len() → Completed
    assert_eq!(orch.sagas[&1].status, SagaStatus::Completed);

    // Failure path: step 1 succeeds, step 2 fails → compensate step 1
    orch.start_saga(2);
    orch.step_success(2); // ReserveInventory done (on compensation stack)
    orch.step_failure(2); // ChargePayment fails → Compensating
    assert_eq!(orch.sagas[&2].status, SagaStatus::Compensating);
    orch.compensate_next(2); // pops ReserveInventory → stack empty → Failed
    assert_eq!(orch.sagas[&2].status, SagaStatus::Failed);

    // Idempotency store
    orch.store_idempotent("key-abc".into(), "order-created".into());
    assert_eq!(orch.check_idempotent("key-abc"), Some("order-created"));
    assert_eq!(orch.check_idempotent("key-xyz"), None);
}
```

**Key points:**
- `compensated_steps` acts as a stack (LIFO) of completed forward steps. `step_success` pushes the completed step onto the stack; `compensate_next` pops the most recent step and compensates it. This naturally implements reverse-order compensation.
- Pattern: `if let Some(saga) = self.sagas.get_mut(&id)` — a combined presence check and mutable borrow. If the saga does not exist, the function silently returns. In production, this should return a `Result<(), SagaError>`.
- `SagaStep` variants have no payloads in this simplified model. In production, each step carries its own data (inventory item IDs, payment amount, shipping address) needed to execute the compensation.
- The idempotency store is a `HashMap<String, String>`. Production uses Redis with TTL: `SET key value EX 86400 NX` — set only if not exists, expire after 24 hours.

### 4.2 Java: Saga Orchestrator

```java
import java.util.*;

public class SagaPattern {

    static void check(boolean cond, String msg) {
        if (!cond) throw new RuntimeException("Assertion failed: " + msg);
    }

    enum SagaStep { RESERVE_INVENTORY, CHARGE_PAYMENT, ARRANGE_SHIPPING, CONFIRM_ORDER }
    enum SagaStatus { PENDING, RUNNING, COMPLETED, COMPENSATING, FAILED }

    static class SagaInstance {
        long id;
        int currentStep;
        List<SagaStep> steps;
        SagaStatus status;
        List<SagaStep> compensatedSteps = new ArrayList<>();

        SagaInstance(long id) {
            this.id = id;
            this.steps = List.of(SagaStep.values());
            this.status = SagaStatus.RUNNING;
            this.currentStep = 0;
        }
    }

    static class SagaOrchestrator {
        private final Map<Long, SagaInstance> sagas = new HashMap<>();
        private final Map<String, String> idempotencyStore = new HashMap<>();

        SagaInstance startSaga(long id) {
            SagaInstance saga = new SagaInstance(id);
            sagas.put(id, saga);
            return saga;
        }

        void stepSuccess(long id) {
            SagaInstance saga = sagas.get(id);
            if (saga == null) return;
            SagaStep step = saga.steps.get(saga.currentStep);
            saga.compensatedSteps.add(step);
            saga.currentStep++;
            if (saga.currentStep == saga.steps.size()) {
                saga.status = SagaStatus.COMPLETED;
            }
        }

        void stepFailure(long id) {
            SagaInstance saga = sagas.get(id);
            if (saga == null) return;
            saga.status = SagaStatus.COMPENSATING;
        }

        void compensateNext(long id) {
            SagaInstance saga = sagas.get(id);
            if (saga == null) return;
            if (!saga.compensatedSteps.isEmpty()) {
                saga.compensatedSteps.remove(saga.compensatedSteps.size() - 1);
            }
            if (saga.compensatedSteps.isEmpty()) {
                saga.status = SagaStatus.FAILED;
            }
        }

        String checkIdempotent(String key) {
            return idempotencyStore.get(key);  // null if not found
        }

        void storeIdempotent(String key, String response) {
            idempotencyStore.put(key, response);
        }
    }

    public static void main(String[] args) {
        SagaOrchestrator orch = new SagaOrchestrator();
        orch.startSaga(1L);

        // Happy path
        orch.stepSuccess(1L);
        orch.stepSuccess(1L);
        orch.stepSuccess(1L);
        orch.stepSuccess(1L);
        check(orch.sagas.get(1L).status == SagaStatus.COMPLETED, "saga1 COMPLETED");

        // Failure path
        orch.startSaga(2L);
        orch.stepSuccess(2L);
        orch.stepFailure(2L);
        check(orch.sagas.get(2L).status == SagaStatus.COMPENSATING, "saga2 COMPENSATING");
        orch.compensateNext(2L);
        check(orch.sagas.get(2L).status == SagaStatus.FAILED, "saga2 FAILED");

        // Idempotency
        orch.storeIdempotent("key-abc", "order-created");
        check("order-created".equals(orch.checkIdempotent("key-abc")), "idempotent found");
        check(orch.checkIdempotent("key-xyz") == null, "idempotent null");
    }
}
```

**Key points:**
- `List.of(SagaStep.values())` creates an immutable `List<SagaStep>` from the enum's `values()` array. `values()` returns `SagaStep[]`; `List.of` accepts a vararg `T...` and correctly handles an array argument, producing `[RESERVE_INVENTORY, CHARGE_PAYMENT, ARRANGE_SHIPPING, CONFIRM_ORDER]`. The result is immutable — any `add()` throws `UnsupportedOperationException`. This immutability is appropriate: the step list for a saga should not change after creation.
- `compensatedSteps.remove(saga.compensatedSteps.size() - 1)` simulates stack `pop()` on an `ArrayList`. `Stack` is not used (it extends `Vector`, which is synchronized and deprecated for new code). `ArrayDeque` would be more semantic (`addLast`/`removeLast`), but `ArrayList` is simpler for this illustrative case.
- `Map.get()` returns `null` if the key is absent — used directly in `checkIdempotent`. The null return communicates "not found" without an `Optional` wrapper. In production, `Optional.ofNullable(idempotencyStore.get(key))` is more explicit.
- Enum comparison uses `==` (identity equality on enum singletons), not `.equals()`. This is idiomatic and correct for Java enums.

---

## 5. Tradeoffs

### 5.1 Saga Variants vs 2PC

| Dimension | Choreography Saga | Orchestration Saga | Two-Phase Commit |
|---|---|---|---|
| **Coupling** | Loose — services know only events | Medium — services know orchestrator's API | Tight — all participants implement 2PC protocol |
| **SPOF** | None | Orchestrator (mitigated by HA clustering) | Coordinator (mitigated by clustering, but complex) |
| **Visibility** | Low — flow distributed across services | High — orchestrator is the single source of saga state | High — coordinator tracks all participant votes |
| **Scalability** | High — event-driven, async | High — async, but orchestrator is a chokepoint at extreme scale | Low — blocking locks during prepare phase |
| **Failure handling** | Distributed — each service handles its compensation trigger | Centralized — orchestrator manages compensation sequence | Automatic — coordinator drives abort on prepare failure |
| **Consistency** | Eventual — compensations are async | Eventual — compensations are async | Strong — atomicity guaranteed across all participants |
| **Operational complexity** | Medium — need to track event flows across services | Medium — need to operate orchestrator service | High — 2PC driver, recovery protocol, distributed lock manager |

### 5.2 Saga Overhead

Sagas introduce complexity that pure CRUD or 2PC does not have:

**Compensation design burden:** every operation must have a compensation. For some operations, compensation is impossible or meaningless — you cannot "un-send" an email, "un-fire" a webhook, or "un-launch" a batch job. These operations must be handled with "best effort" compensations (send a cancellation email, call the webhook with a cancel payload) and accepted as ultimately not fully reversible.

**Eventual consistency window:** during the gap between forward steps, the system is in an intermediate state. Inventory is reserved but payment is not yet charged. Another user's concurrent read of inventory sees reduced availability before the order completes or compensates. Business processes must tolerate this window.

**Saga sprawl:** as the number of saga steps grows, the choreography event topology becomes difficult to understand. A 10-step saga with 3 possible failure points at each step creates a complex web of event handlers. Orchestration helps here, but even the orchestrator's state machine grows in complexity.

**When 2PC is acceptable:** 2PC remains appropriate for systems where services share the same database (XA transactions), for very small services with co-located stores (same datacenter, same DB cluster), and for systems where strong consistency is a hard requirement and throughput is modest (< 1,000 transactions/sec). For payment settlement within a single bank's infrastructure, 2PC is commonly used.

**Saga coordinator frameworks:** several open-source frameworks implement the orchestrated saga pattern to avoid building the state machine from scratch. Temporal (formerly Cadence) is the most mature option — sagas are expressed as deterministic workflows in Go or Java, with the framework providing durable execution, retries, timeouts, and activity history. Axon Framework (Java) provides saga support integrated with event sourcing and CQRS. Both replace the hand-rolled `SagaOrchestrator` in this chapter with a higher-level DSL. The trade-off: a framework dependency and its operational complexity (Temporal requires a cluster of services) in exchange for eliminating idempotency boilerplate, state persistence code, and retry logic.

### 5.3 Temporal Coupling in Choreography

In choreography, a downstream service must be running and subscribed to consume an event for the saga to advance. If the Shipping service is down, `PaymentCharged` events pile up in Kafka, and orders wait in a "payment charged, not shipped" state. The system is "eventually available" — it will process those events when Shipping recovers.

This is usually acceptable (Kafka retains events durably), but the saga has a "maximum step timeout" after which it begins compensation. The timeout must be tuned: too short, and normal Shipping delays trigger unnecessary compensations; too long, and customers wait in limbo.

**Event ordering in choreography:** Kafka guarantees ordering only within a partition. If all saga events for the same order are published to the same partition (keyed by `order_id`), ordering is preserved. If events fan out to different topics with different partition keys, a downstream service may receive `PaymentCharged` before `InventoryReserved` — violating the expected sequence. Design: always use `order_id` as the partition key for all saga events belonging to the same aggregate, and route them through a single Kafka topic or co-partitioned topics to preserve per-order ordering.

---

## 6. Failure Modes

### 6.1 Compensation Failure

**Symptom:** a 4-step saga completes steps 1–3 but fails at step 4. The orchestrator begins compensation: step 3's compensation (cancel shipment) succeeds; step 2's compensation (refund payment) fails because the Payment service is down. The saga is stuck in `COMPENSATING` at step 2.

**Root cause:** the Payment service is unavailable — a transient or extended outage.

**Mitigation:**
- Retry compensations with exponential backoff and a maximum retry limit per attempt cycle. Resume on orchestrator restart.
- After N failed attempts, move the saga to `STUCK` status and emit a high-priority alert. A human operator or automated escalation process must manually trigger the compensation when the service recovers.
- Maintain a human review queue: a dashboard showing all `STUCK` sagas with the last error, attempt count, and affected customer. Support agents can trigger manual refunds using internal tooling.
- Design compensation endpoints to be idempotent so that any number of retries is safe.

### 6.2 Duplicate Event Processing

**Symptom:** Kafka delivers `PaymentCharged` twice to the Shipping service (at-least-once delivery semantics). The Shipping service schedules two shipments for the same order.

**Root cause:** at-least-once delivery guarantees that events will be delivered at least once, but not exactly once. Network failures between Kafka and the consumer can cause re-delivery.

**Mitigation:**
- Check the `event_id` (or idempotency key) before processing every event. If the event has already been processed (recorded in a `processed_events` table), skip it and acknowledge the message.
- Acknowledge the Kafka message after the processing transaction commits — not before. This ensures that if the service crashes between processing and acknowledging, the event is re-delivered and the idempotency check prevents double-processing.
- Use Kafka's transactional producer to combine the consumer offset commit and the business DB write in a single atomic operation (Kafka's exactly-once semantics, available since Kafka 0.11). This is complex to set up but eliminates the need for a separate `processed_events` table.

### 6.3 Saga State Loss

**Symptom:** the saga orchestrator's database fails mid-saga. When it recovers, it has lost the state of 50 in-flight sagas. It does not know which step each saga was on or which steps completed.

**Root cause:** database crash without durable write, or the state was held in memory only.

**Mitigation:**
- Persist every saga state transition to a durable database before executing the transition. The orchestrator must not advance its in-memory state machine faster than its database commits.
- Use Event Sourcing for the orchestrator's own state: each transition is an event (`SagaStepSucceeded`, `SagaStepFailed`, `SagaCompensating`). On restart, replay the event log to reconstruct in-flight saga states. This makes the orchestrator's own state fully auditable and recoverable.
- Pair with idempotency on every step: even if the orchestrator replays a step that already succeeded, the step's idempotency key prevents double execution.

### 6.4 Timeout Cascade

**Symptom:** step 1 (Reserve Inventory) times out at the orchestrator's deadline (30 seconds). The orchestrator concludes that step 1 failed and does not push it to the compensation stack. Compensation begins — but step 1 actually succeeded (the timeout was a network delay, not a service failure). The order now has reserved inventory that is never released.

**Root cause:** the timeout fired before the response arrived. The step was completed at the service, but the orchestrator did not record the success.

**Mitigation:**
- On timeout, do not immediately assume failure. Instead, query the step's status: "Did the Inventory service successfully reserve for order 42?" Each service must expose a query endpoint for its step status.
- Apply idempotency on forward steps: if the orchestrator retries step 1 after a timeout and step 1 already succeeded, the idempotency key returns the cached success response — safe to retry.
- Use a "two-phase check" pattern: after timeout, query step status → if succeeded, advance; if failed or unknown, begin compensation. This adds latency to the timeout handling path but prevents phantom reservations.

---

## 7. Java vs Rust

**Enum expressiveness:** Rust enums encode algebraic data types — each variant can carry different data. `SagaStep::ChargePayment { amount: Decimal, card_token: String }` is a valid Rust enum variant. Java enums are simpler: each variant is a singleton of the enum class. Java 17's `sealed interface` with nested `record` types bridges this gap for sum types, but Java's `enum` itself cannot carry per-variant fields beyond what is stored in the enum constant's constructor. For the saga step data model, Rust would use a `SagaStep` enum with struct variants carrying step-specific data; Java would use a sealed interface hierarchy.

**Exhaustive matching:** Rust's `match` on an enum is exhaustive by default — adding a new `SagaStep` variant to the enum causes a compile error in every unupdated `match`. Java's `switch` on an enum (not a sealed interface) is not exhaustive: a missing case compiles silently and falls through to the `default` (or does nothing in `switch` expressions). Java 21's pattern `switch` with sealed types is exhaustive, but standard `enum switch` is not. Production Java code should always include `default -> throw new IllegalStateException(...)`.

**Boxing overhead:** `HashMap<u64, SagaInstance>` in Rust stores `u64` keys directly — no boxing, no heap allocation for the key. Java's `Map<Long, SagaInstance>` boxes every `long` key into a `Long` heap object. For a map with 10 million saga entries, this is 160+ MB in object headers and pointer overhead that Rust simply does not pay. For most applications this is acceptable; for memory-critical saga stores, consider a primitive-keyed map library (Eclipse Collections, Koloboke).

**Immutability semantics:** `List.of(SagaStep.values())` produces an unmodifiable `List<SagaStep>` in Java — any structural modification throws `UnsupportedOperationException` at runtime. Rust's `vec![]` produces a mutable `Vec<T>` by default; immutability is enforced at the variable level (`let steps = vec![...]` cannot be passed to a function expecting `&mut Vec<T>`). Rust enforces mutability boundaries at compile time through the borrow checker; Java relies on runtime exceptions for immutability violations. This means Java bugs like accidentally modifying a "read-only" list surface only during testing or production, not at compile time.

**Sealed + record for rich domain modeling:** Java's combination of `sealed interface` + `record` types (both stable since Java 17) provides a powerful tool for domain modeling that approaches Rust's enum richness. A `sealed interface SagaEvent` with `record StepSucceeded(long sagaId, SagaStep step)`, `record StepFailed(long sagaId, SagaStep step, String reason)` — used with pattern matching `instanceof` or Java 21's `switch` — provides exhaustive, type-safe dispatch. This is the recommended approach for production saga event types in Java, and it is the closest Java comes to Rust enum expressiveness.

**HashMap null semantics:** in the Rust snippet, `self.sagas.get(&id)` returns `Option<&SagaInstance>` — it is impossible to confuse a missing entry with a present-but-null entry; `None` is structurally distinct from `Some(value)`. Java's `Map.get(key)` returns `null` for both "key absent" and "key present with null value." A `HashMap<Long, SagaInstance>` that accidentally has a `null` value for saga ID 5 is indistinguishable from a missing saga at the API level — `sagas.get(5L) == null` is true in both cases. Production Java code should use `Optional.ofNullable(sagas.get(id)).ifPresent(saga -> ...)` or enforce the `Map` never contains null values. Rust's `Option` type makes the distinction structural and compiler-enforced: `HashMap::insert(key, None)` does not compile because the value type is `SagaInstance` (not `Option<SagaInstance>`).

**Saga state serialization:** the Rust `SagaInstance` struct derives `Debug` and `Clone`, but persistence to a database requires serialization (JSON via `serde`, or binary via `bincode`). Rust's `serde` ecosystem makes this explicit: add `#[derive(Serialize, Deserialize)]` and call `serde_json::to_string(&saga)`. Java's `SagaInstance` can be serialized to JSON via Jackson's `ObjectMapper` with zero annotations for simple field types. Both ecosystems support serialization, but Rust's derive-based approach is more composable — adding a new field automatically includes it in serialization without separate annotation. Java's Jackson also auto-serializes new fields, but requires explicit `@JsonIgnore` to exclude sensitive fields — easy to forget, potentially leaking internal data.

**Error handling in step execution:** in a production Rust implementation, `step_success` and `step_failure` would return `Result<(), SagaError>` rather than silently returning when the saga ID is not found. The caller is forced to handle the error case — either log it, return a 404, or create a new saga. Java's equivalent returning `void` (or `null`) silently discards the "saga not found" case, which can mask orchestrator bugs where sagas are started on one instance and executed on another. Rust's `Result` propagation, combined with the `?` operator, makes the missing-saga path explicit and impossible to accidentally ignore.

**Summary:** the Saga pattern trades strong consistency for availability and loose coupling. Getting it right requires three non-negotiable building blocks — idempotent forward steps, idempotent compensations, and durable saga state. With these three properties in place, the system can tolerate any combination of service failures, network partitions, and orchestrator restarts without producing inconsistent data. Without any one of them, subtle double-processing bugs or stuck sagas are inevitable under production load.

Of the three, idempotency is the most commonly underestimated. Developers focus on the happy path — the forward saga succeeds — and skip idempotency key infrastructure because "retries are rare." Under sustained traffic at 167 orders/sec over days, at-least-once delivery means retries are not rare; they are guaranteed. Build idempotency first.
