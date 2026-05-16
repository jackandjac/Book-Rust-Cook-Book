# Chapter 14: Event Sourcing & CQRS

> **Chapter goal:** Implement Event Sourcing (append-only event log as source of truth) and CQRS (Command Query Responsibility Segregation) — separating write models (commands) from read models (projections) for audit trails, time-travel debugging, and read scalability.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

Traditional CRUD databases store only the current state of a record. When a row is updated, the previous value is gone. This makes answering audit questions — "who changed this balance, and when?" — impossible without extra infrastructure bolted on after the fact.

Event Sourcing flips the model: instead of storing the current state, the system stores a log of events that produced that state. An event is an immutable fact about something that happened in the domain — `OrderPlaced`, `ItemAdded`, `OrderShipped`. Current state is derived by replaying events from the beginning, or from a recent snapshot.

CQRS (Command Query Responsibility Segregation) is the natural architectural companion: the write side accepts commands (intentions, e.g. "place this order"), validates and emits events, and persists them to an event store; the read side consumes those events and maintains denormalized projections optimized for query patterns. The two sides scale and evolve independently.

**Domain use cases:**

- **Banking:** every balance change — deposit, withdrawal, transfer, fee, interest — is recorded as an event. The current balance is the sum of all events. Regulators can audit every cent. Time-travel queries answer "what was the customer's balance on December 31st?" without needing a separate audit table.
- **E-commerce orders:** the full lifecycle of an order — placed, item added, coupon applied, payment attempted, payment failed, payment retried, shipped, returned — is captured event by event. Customer support sees the complete history in one screen rather than piecing together logs from five systems.
- **Healthcare:** a patient's record is a log of clinical events — diagnoses, prescriptions, lab results, procedure notes. HIPAA requires a complete audit trail; event sourcing provides it by construction. Projections build the current summary view for the treating physician.
- **Compliance and financial reporting:** SOX and PCI-DSS require that "who changed this, when, and why" be answerable for every financial record. Bolting an audit log onto a CRUD system is fragile (developers forget to log, logs can be deleted). Event sourcing makes the audit log the primary store — it cannot be forgotten.

The system must satisfy the following functional requirements:

- **Immutable event log** — events are append-only and never updated or deleted; they are the single source of truth.
- **Aggregate replay** — loading an aggregate (e.g., an `Order`) means loading all its events and applying them in order to reconstruct current state.
- **Multiple projections** — the same event stream feeds multiple read models: an order summary table, a search index, an analytics dashboard, a compliance report.
- **Time-travel queries** — replay events up to a given point in time to answer "what was the state of this order at 14:00 yesterday?"
- **Audit trail** — every state change is captured as an event with who initiated it (`occurred_at`, `caused_by`), satisfying compliance requirements such as SOX, HIPAA, and PCI-DSS.
- **Optimistic concurrency** — commands include an `expected_version`; if the stored version has advanced (concurrent update), the command is rejected and the caller retries.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Write throughput | 10,000 events/second sustained |
| Read throughput | 100,000 queries/second (projections, snapshots) |
| Event store storage | 1 billion events, ~1 TB at 1 KB/event |
| Replay latency (no snapshot) | < 5 seconds for aggregates with up to 1,000 events |
| Replay latency (with snapshot) | < 50 ms for aggregates with snapshot + ≤ 100 events since |
| Projection lag | < 2 seconds behind event store under normal load |
| Durability | Events durable on write (fsync or equivalent) |

### 1.3 Scale Estimates

| Dimension | Estimate |
|---|---|
| Daily events written | 864 million (10K/sec × 86,400 sec) |
| Event size (average) | 1 KB (JSON payload + metadata) |
| Storage growth rate | ~864 GB/day at 1 KB/event |
| Archival threshold | Events older than 1 year moved to S3 Glacier |
| Active aggregate count | 10 million (orders, accounts, patients) |
| Snapshot cadence | Every 100 events per aggregate |
| Read model DB size | ~100 GB (denormalized, pre-joined, indexed) |

**Snapshot storage estimate:**

If 10 million aggregates each take a snapshot every 100 events, and the average snapshot size is 2 KB:

```
10M aggregates × 2 KB = 20 GB snapshot store
```

That fits comfortably in PostgreSQL or DynamoDB with appropriate TTL management.

**Replay cost with and without snapshots:**

Consider an order aggregate that has accumulated 500 events over its lifetime. Replaying 500 events from storage:

```
500 events × 1 KB/event = 500 KB network read
500 apply() calls × ~1 µs each ≈ 0.5 ms CPU

Total replay latency (no snapshot): ~5-15 ms
(dominated by storage I/O and deserialization)
```

With a snapshot at version 400 and 100 events since:

```
1 snapshot read × 2 KB = 2 KB network read
100 events × 1 KB = 100 KB network read
100 apply() calls × ~1 µs each ≈ 0.1 ms CPU

Total replay latency (with snapshot): ~1-3 ms
```

For aggregates with thousands of events — a bank account with 10,000 transactions — the difference is an order of magnitude: hundreds of milliseconds vs tens of milliseconds. This latency directly affects command handler response times, so snapshot cadence is a performance dial worth tuning per aggregate type.

---

## 2. Architecture

### 2.1 High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        COMMAND SIDE                             │
│                                                                 │
│  Client  ──►  Command Handler  ──►  Validate Command           │
│                                         │                      │
│                                         ▼                      │
│                               Load Aggregate Events            │
│                               from Event Store                 │
│                                         │                      │
│                                         ▼                      │
│                               Apply Command → Emit Events       │
│                                         │                      │
│                                         ▼                      │
│                               Persist Events to Event Store    │
│                               (optimistic version check)       │
└─────────────────────────────┬───────────────────────────────────┘
                              │ publish
                              ▼
                    ┌──────────────────┐
                    │  Event Bus       │
                    │  (Kafka / NATS)  │
                    └────────┬─────────┘
                             │ subscribe
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        QUERY SIDE                               │
│                                                                 │
│  Projection Worker  ──►  Apply Event  ──►  Read Model DB        │
│  (idempotent)              │               (PostgreSQL /        │
│                            │                Elasticsearch)      │
│                            └──►  Update OrderSummary table      │
│                            └──►  Update SearchIndex             │
│                            └──►  Update AnalyticsCube           │
│                                                                 │
│  Query Handler  ◄──  Read Model DB  ◄──  Client Query          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────┐
│  SNAPSHOT STORE                      │
│  (PostgreSQL or S3)                  │
│                                      │
│  On read:  load latest snapshot      │
│            + events since snapshot   │
│  On write: snapshot every 100 events │
└──────────────────────────────────────┘
```

### 2.2 Order Aggregate Event Timeline

```
Order #1001:

version 1  →  OrderPlaced   { order_id: 1001, customer: "Alice", at: 09:00 }
version 2  →  ItemAdded     { item: "Book",   quantity: 2,        at: 09:01 }
version 3  →  ItemAdded     { item: "Pen",    quantity: 5,        at: 09:01 }
version 4  →  ItemAdded     { item: "Ruler",  quantity: 1,        at: 09:02 }
version 5  →  PaymentProcessed { amount: 42.50, method: "card",  at: 09:05 }
version 6  →  OrderShipped  { tracking: "TRK123",                at: 09:10 }

Current state (replay of versions 1-6):
  customer = "Alice"
  items    = [("Book", 2), ("Pen", 5), ("Ruler", 1)]
  total    = 42.50
  shipped  = true
  version  = 6
```

---

## 3. Component Deep-Dive

### 3.1 Event Store Design

The event store is the heart of the system. Its schema captures everything needed to replay history and enforce consistency:

| Column | Type | Purpose |
|---|---|---|
| `event_id` | UUID | Globally unique identifier; used for idempotency tracking in projections |
| `aggregate_id` | UUID | Which aggregate this event belongs to (e.g., order ID) |
| `aggregate_type` | VARCHAR | Discriminates aggregate type: `Order`, `Account`, `Patient` |
| `event_type` | VARCHAR | Name of the event: `OrderPlaced`, `ItemAdded`, `OrderShipped` |
| `event_data` | JSONB | Payload; serialized event fields |
| `version` | BIGINT | Monotonically increasing per aggregate; enforces optimistic locking |
| `occurred_at` | TIMESTAMPTZ | When the event happened (domain time, not DB insert time) |
| `caused_by` | VARCHAR | User ID or service that caused the event; audit trail |

**Append-only guarantee:** the event store never allows `UPDATE` or `DELETE` statements on the events table. This is enforced at the database level (row-level security in PostgreSQL, or IAM policies on DynamoDB). Any bug that would "fix" bad data must emit a corrective event — `InventoryAdjusted`, `PaymentRefunded` — not mutate existing records.

**Optimistic locking:** when the command handler appends events, it includes the `expected_version` in a conditional write:

```sql
INSERT INTO events (aggregate_id, version, ...)
VALUES ($1, $2, ...)
-- ensure no concurrent write advanced the version
WHERE NOT EXISTS (
    SELECT 1 FROM events WHERE aggregate_id = $1 AND version = $2
);
```

If another command snuck in and created that version, the insert fails with a conflict. The caller catches this and retries by reloading the aggregate and re-applying the command.

**Optimistic locking retry loop in practice:**

A well-implemented command handler retries transparently on version conflict:

```
attempt 1:
  load order 1001 at version 5
  apply AddItem command → emit ItemAdded event
  INSERT event with version=6
  → CONFLICT (another writer already created version 6)

attempt 2 (retry):
  reload order 1001 at version 6 (includes the concurrent write)
  re-apply AddItem command → emit ItemAdded at version 7
  INSERT event with version=7
  → SUCCESS
```

This retry is safe because the command's business logic runs against the latest state — it is not replaying a stale decision. Most conflicts resolve in one retry because aggregates are rarely written by two concurrent commands at extremely high frequency. If conflicts are frequent (more than ~5% of writes), the aggregate's consistency boundary may be too coarse — consider splitting it.

**Storage choice:**

- **EventStoreDB**: purpose-built for event sourcing; native subscriptions, stream projections, catch-up subscriptions. Best default choice.
- **Kafka**: durable, high-throughput, but retention is time-based by default (events may be deleted); use log compaction carefully; consumer offsets serve as read positions.
- **PostgreSQL**: simplest to operate; NOTIFY/LISTEN for push-based projection updates; triggers or polling for projection workers; excellent for teams already running Postgres.

### 3.2 Aggregates & Commands

An aggregate is a cluster of domain objects that forms a consistency boundary. All state changes flow through the aggregate root, which validates business rules and emits events.

The lifecycle of a command:

1. **Receive command** — e.g., `AddItemToOrder { order_id: 1001, item: "Eraser", quantity: 3 }`.
2. **Load aggregate** — fetch all events for `aggregate_id = 1001` from the event store; replay them via `apply()` to reconstruct current state.
3. **Validate** — check business rules against current state: is the order still open? Is inventory available?
4. **Emit events** — if valid, create `ItemAdded { ... }` event.
5. **Persist** — append event to the store with `expected_version = current_version`; if version conflict, go back to step 2.
6. **Publish** — after successful persistence, publish event to Kafka for projection workers.

Commands are intentions ("I want to add this item"). Events are facts ("this item was added"). The distinction is critical: a command can be rejected; an event, once stored, is immutable truth. Events are named in the past tense.

### 3.3 Projections (Read Models)

A projection is an event handler that builds a read model from the event stream. Because the read model is derived from events, it can be discarded and rebuilt at any time by replaying from the beginning — an extremely powerful property for fixing bugs or adding new query patterns.

**Example: `OrderSummaryProjection`**

This projection listens to all order events and maintains a flat `order_summary` table:

| Column | Populated by |
|---|---|
| `order_id` | `OrderPlaced` |
| `customer_name` | `OrderPlaced` |
| `item_count` | incremented by `ItemAdded` |
| `total_amount` | incremented by `ItemAdded`, finalized by `PaymentProcessed` |
| `status` | updated by `OrderShipped`, `OrderCancelled` |
| `last_updated` | every event |

A single event stream can feed multiple projections simultaneously. One projection might power a customer-facing dashboard (needs `status`, `total_amount`); another feeds the search index (needs item names and descriptions); a third feeds the compliance report (needs timestamps and `caused_by`).

**Idempotent processing:** projection workers must be idempotent. If Kafka delivers an event twice (at-least-once delivery), the projection must not double-count. The standard technique: maintain a `processed_events` table keyed on `event_id`. Before applying each event, check if it has been processed. This ensures exactly-once semantics in the projection layer even with at-least-once message delivery.

### 3.4 Snapshots

Replaying every event for an aggregate with 10,000 events takes time and adds latency to every command. Snapshots short-circuit this by periodically capturing aggregate state at a given version:

```
Snapshot at version 100:  Order { items: [...], total: 95.00, version: 100 }
Events 101..107 in store

On load: deserialize snapshot → apply events 101..107 → done
Replay cost: O(7) instead of O(107)
```

**Snapshot cadence:** a common heuristic is to take a snapshot every N events (N = 100 is typical). Some systems also snapshot on command — "before closing an order, take a snapshot so the final state is instantly available."

**Snapshot invalidation:** snapshots are never invalidated, but they can become stale if the aggregate structure changes (new fields added). The solution is to version snapshots alongside the aggregate schema version. If snapshot schema version does not match current schema version, fall back to full replay. This is a rare occurrence in practice.

### 3.5 Event Versioning & Schema Evolution

Events are immutable once stored. This means any change to the structure of an event type must be handled carefully:

- **Adding optional fields**: backward-compatible. Old events have the field absent (deserialized as `None` / `null`); new events populate it.
- **Renaming fields**: store both old and new field names during a transition window. Old code reads the old field; new code reads the new field (with fallback to old). After all events have been upcasted, remove the old field name from the schema.
- **Removing fields**: mark as deprecated in the schema; keep deserializing but ignore the value; remove from code paths.
- **Event upcasting**: a transformer function that converts an old event format to the current format in memory during replay. The stored event is never modified; the upcast happens in the event store client layer. Upcasters are chained: v1 → v2 → v3.

The golden rule: **never modify stored events**. The event log is an audit trail. Changing historical events would undermine the entire premise of the system.

**Worked example — upcasting a field rename:**

Suppose `OrderPlaced` v1 stores `{ "customer": "Alice" }`. Version 2 renames `customer` to `customer_name` and adds `customer_email`. An upcaster transforms v1 events in memory during replay:

```
stored (v1):  { "schema_version": 1, "customer": "Alice" }
              ↓ upcast v1→v2
in-memory:    { "schema_version": 2, "customer_name": "Alice", "customer_email": null }
```

The upcaster is a pure function registered in the event deserializer. It runs every time a v1 event is loaded from the store — which means all old events behave as if they were always v2, while the stored bytes remain unchanged. When a v3 schema change arrives, a v1→v3 upcaster is added by composing v1→v2 and v2→v3. This chain ensures the `apply()` method only ever sees the current schema version regardless of when the event was originally stored.

### 3.6 CQRS Benefits

Separating the write and read sides provides concrete operational advantages:

**Independent scaling:** write throughput depends on the event store's append performance. Read throughput depends on the read model DB. A system with 10× more reads than writes can scale the read model horizontally (multiple read replicas, multiple read DB instances) without touching the event store.

**Query optimization:** the write model is optimized for consistency and validation (normalized, strict). The read model is optimized for query patterns (denormalized, pre-joined). The customer order summary table has `customer_name` and `total_amount` in the same row — no JOIN needed at query time.

**Resilience:** a projection worker failure does not affect the command side. Orders continue to be placed; the read model just lags until the worker recovers. When it restarts, it replays from its last checkpoint.

**Tradeoff — eventual consistency:** the read model is always slightly behind the write model. A user who just placed an order may not see it in the dashboard for a few hundred milliseconds. This must be communicated in the UI ("data updated as of...") or handled with read-your-writes patterns (serve the command response directly to the user; let the projection catch up for other users).

---

## 4. Key Algorithms

### 4.1 Rust: Order Aggregate with Event Sourcing

```rust
// Simplified Order aggregate with Event Sourcing
#[derive(Debug, Clone)]
enum OrderEvent {
    Placed { order_id: u64, customer: String },
    ItemAdded { item: String, quantity: u32 },
    Shipped { tracking: String },
}

#[derive(Debug, Default)]
struct Order {
    id: u64,
    customer: String,
    items: Vec<(String, u32)>,  // (item, quantity)
    shipped: bool,
    version: u64,
}

impl Order {
    fn apply(&mut self, event: &OrderEvent) {
        match event {
            OrderEvent::Placed { order_id, customer } => {
                self.id = *order_id;
                self.customer = customer.clone();
            }
            OrderEvent::ItemAdded { item, quantity } => {
                self.items.push((item.clone(), *quantity));
            }
            OrderEvent::Shipped { .. } => {
                self.shipped = true;
            }
        }
        self.version += 1;
    }

    fn load(events: &[OrderEvent]) -> Self {
        let mut order = Order::default();
        for e in events {
            order.apply(e);
        }
        order
    }
}

// EventStore (in-memory simulation)
struct EventStore {
    events: Vec<(u64, OrderEvent)>,  // (aggregate_id, event)
}

impl EventStore {
    fn new() -> Self { EventStore { events: vec![] } }

    fn append(&mut self, agg_id: u64, event: OrderEvent) {
        self.events.push((agg_id, event));
    }

    fn load(&self, agg_id: u64) -> Vec<OrderEvent> {
        self.events.iter()
            .filter(|(id, _)| *id == agg_id)
            .map(|(_, e)| e.clone())
            .collect()
    }
}

fn main() {
    let mut store = EventStore::new();
    store.append(1, OrderEvent::Placed { order_id: 1, customer: "Alice".into() });
    store.append(1, OrderEvent::ItemAdded { item: "Book".into(), quantity: 2 });
    store.append(1, OrderEvent::ItemAdded { item: "Pen".into(), quantity: 5 });
    store.append(1, OrderEvent::Shipped { tracking: "TRK123".into() });

    let events = store.load(1);
    let order = Order::load(&events);

    // 1 Placed + 2 ItemAdded + 1 Shipped = 4 events → version 4
    assert_eq!(order.customer, "Alice");
    assert_eq!(order.items.len(), 2);
    assert!(order.shipped);
    assert_eq!(order.version, 4);
}
```

**Key points:**
- `OrderEvent` is a Rust enum with struct variants — each variant carries its own named fields, making pattern matching exhaustive and explicit. The compiler rejects any unhandled variant.
- `Order::default()` is derived automatically (`#[derive(Default)]`), giving zero-values for all fields with no boilerplate.
- The `EventStore::load` method uses iterator chaining: `filter` selects events belonging to the aggregate, `map` extracts the event, `collect` gathers into a `Vec`. This is idiomatic and avoids manual indexing.
- `version` increments on every `apply` call, faithfully reflecting how many events have been applied. This is used for optimistic concurrency: a command handler records the version it loaded, and the store rejects any append if the version has advanced since.

### 4.2 Java: Order Aggregate with Event Sourcing

```java
import java.util.*;

public class EventSourcing {

    static void check(boolean cond, String msg) {
        if (!cond) throw new RuntimeException("Assertion failed: " + msg);
    }

    sealed interface OrderEvent
            permits OrderEvent.Placed, OrderEvent.ItemAdded, OrderEvent.Shipped {
        record Placed(long orderId, String customer) implements OrderEvent {}
        record ItemAdded(String item, int quantity) implements OrderEvent {}
        record Shipped(String tracking) implements OrderEvent {}
    }

    static class Order {
        long id;
        String customer;
        List<String[]> items = new ArrayList<>();  // [item, quantity]
        boolean shipped;
        long version;

        void apply(OrderEvent event) {
            if (event instanceof OrderEvent.Placed p) {
                id = p.orderId();
                customer = p.customer();
            } else if (event instanceof OrderEvent.ItemAdded a) {
                items.add(new String[]{a.item(), String.valueOf(a.quantity())});
            } else if (event instanceof OrderEvent.Shipped) {
                shipped = true;
            }
            version++;
        }

        static Order load(List<OrderEvent> events) {
            Order o = new Order();
            events.forEach(o::apply);
            return o;
        }
    }

    static class EventStore {
        private final List<Long> ids = new ArrayList<>();
        private final List<OrderEvent> events = new ArrayList<>();

        void append(long aggId, OrderEvent e) {
            ids.add(aggId);
            events.add(e);
        }

        List<OrderEvent> load(long aggId) {
            List<OrderEvent> result = new ArrayList<>();
            for (int i = 0; i < ids.size(); i++) {
                if (ids.get(i) == aggId) result.add(events.get(i));
            }
            return result;
        }
    }

    public static void main(String[] args) {
        EventStore store = new EventStore();
        store.append(1, new OrderEvent.Placed(1, "Alice"));
        store.append(1, new OrderEvent.ItemAdded("Book", 2));
        store.append(1, new OrderEvent.ItemAdded("Pen", 5));
        store.append(1, new OrderEvent.Shipped("TRK123"));

        List<OrderEvent> events = store.load(1);
        Order order = Order.load(events);

        check(order.customer.equals("Alice"), "customer");
        check(order.items.size() == 2, "items.size");
        check(order.shipped, "shipped");
        check(order.version == 4, "version==4");
    }
}
```

**Key points:**
- Java 17 `sealed interface` with nested `record` types mirrors Rust enums closely: the sealed interface restricts implementations to the declared permits list; records provide immutable value types with auto-generated accessors.
- Pattern matching `instanceof` (Java 16+) replaces verbose `instanceof` + cast chains. `event instanceof OrderEvent.Placed p` binds `p` in one step.
- The `check()` helper replaces Java's disabled-by-default `assert` keyword with a real runtime check.
- `List<String[]>` for items is a pragmatic workaround — in production code this would be a `record ItemEntry(String item, int quantity)`, which is cleaner than `String[]`.

---

## 5. Tradeoffs

### 5.1 Event Sourcing vs Traditional CRUD

| Dimension | Event Sourcing | Traditional CRUD |
|---|---|---|
| **Auditability** | Complete history by design; every change is a stored event | Requires separate audit log table; often incomplete |
| **Query complexity** | Current state requires replay or projection; projections add indirection | Simple SELECT for current state; no replay needed |
| **Storage** | Grows unboundedly (events never deleted); 1B events ≈ 1 TB | Storage proportional to current data size; old data overwritten |
| **Eventual consistency** | Read models lag write model by milliseconds to seconds | Read and write share same DB; consistent by default |
| **Time-travel** | Replay events to any point in time trivially | Impossible without point-in-time recovery of the whole DB |
| **Schema evolution** | Events are immutable; upcast old formats in code | ALTER TABLE and data migrations in place |
| **Learning curve** | High: aggregates, projections, snapshots, upcasting | Low: CRUD is universally understood |
| **Debugging** | Excellent: replay event log to reproduce any state | Harder: state was overwritten |

### 5.2 Event Store Technology Comparison

| Criterion | EventStoreDB | Kafka | PostgreSQL |
|---|---|---|---|
| **Primary purpose** | Event sourcing native | Message streaming | Relational DB |
| **Schema** | Stream per aggregate; events typed | Topic per aggregate type | events table with columns |
| **Replay** | Native catch-up subscriptions | Seek to offset; consumer groups | Query by aggregate_id + version |
| **Consumer groups** | Persistent subscriptions | Native consumer groups | Polling or LISTEN/NOTIFY |
| **Retention** | Permanent (no TTL by default) | Configurable TTL; log compaction | Until DELETE or archive |
| **Global ordering** | Per stream | Per partition (not global) | Per aggregate (by version) |
| **Ops complexity** | Medium | High | Low (existing Postgres skills) |

**When NOT to use Event Sourcing:**

Event sourcing adds significant complexity. It is the wrong choice when:

- The domain does not require audit trails or history. A cache or session store has no value in capturing every update.
- All queries are against current state and no read-scaling is needed. A simple admin CRUD panel does not benefit from projections.
- The team is small and the learning curve is a real risk. Event sourcing is an advanced pattern; introducing it in a startup moving fast increases cognitive overhead with limited benefit.
- Read models and write models are identical in shape. If every query is "give me the current state of one aggregate," there is no benefit to segregating them.

Start with CRUD; add Event Sourcing when the audit and replay requirements become clear and urgent.

**Migration path from CRUD to Event Sourcing:** converting an existing CRUD system to Event Sourcing in one step is risky. A practical incremental approach: (1) begin emitting events alongside CRUD writes using the outbox pattern, persisting them to a separate events table without removing the CRUD tables; (2) build projections from the event stream that replicate the existing CRUD read behavior; (3) once confidence is high, flip reads to the projection-based read model; (4) make the event log the source of truth and retire direct CRUD writes. This phased approach keeps the system operational throughout the migration and allows rollback at each step.

---

## 6. Failure Modes

### 6.1 Projection Lag

**Symptom:** a user places an order and immediately navigates to the order list; the new order does not appear. The read model is behind the event store.

**Root cause:** the projection worker processes events asynchronously. Under load, the consumer may fall behind Kafka by seconds or more.

**Mitigation:**
- Monitor consumer lag as a metric (Kafka consumer group lag). Alert when lag exceeds 10,000 events or 30 seconds.
- Display "data as of N seconds ago" in the UI so users know the read model is eventually consistent.
- For the creating user only, serve the command response data directly (the command handler knows what was written). This is the "read-your-writes" pattern, scoped to the author of the change.
- Prioritize critical projections (e.g., the order status projection) on dedicated workers with lower load; de-prioritize analytics projections that can tolerate higher lag.

### 6.2 Event Replay Failure

**Symptom:** a projection worker crashes mid-replay and restarts. Some events were applied; some were not. The read model is in a partially-updated state.

**Root cause:** projections are stateful; without idempotency guarantees, reprocessing can double-apply events.

**Mitigation:**
- Implement idempotent event processing: before applying any event, check a `processed_events` table keyed on `event_id`. If the event is already recorded, skip it.
- Store the last processed offset (Kafka offset or event store position) in the same database transaction as the projection update. On restart, resume from that checkpoint.
- For corruption recovery, delete the projection tables and replay from event position 0. This always produces a correct read model.

### 6.3 Event Store Grows Unboundedly

**Symptom:** the event store table exceeds 1 TB after two years of data. Query performance degrades; backup windows grow.

**Root cause:** events are never deleted by design.

**Mitigation:**
- Archive events older than a retention threshold (e.g., 1 year) to S3 or Glacier. Keep a pointer in the event store: "events for this aggregate before version 1000 are in archive/2023/aggregate-1001.jsonl".
- Snapshots reduce replay cost without requiring deletion. Even with archival, the most recent snapshot covers the gap.
- Partition the events table by `occurred_at` month in PostgreSQL. Old partitions can be detached and archived with zero impact on recent queries.
- Accept the growth: 1 TB is easily handled by modern cloud storage at low cost. Budget for storage rather than premature optimization.

### 6.4 Optimistic Concurrency Conflict

**Symptom:** two commands arrive simultaneously for the same aggregate (e.g., two tabs both trying to modify the same order). One command succeeds; the other's append fails with a version conflict.

**Root cause:** both commands loaded the aggregate at the same version and both expected that version when appending. The first write wins; the second fails.

**Mitigation:**
- Retry with exponential backoff: reload the aggregate, re-apply the command with the new version, retry the append. Most conflicts resolve in one retry because the aggregate is rarely modified at extremely high frequency.
- Expose the conflict to the user when retry is not appropriate: "This order was modified by another session. Please review the current state and resubmit."
- Design commands to be commutative where possible. "Add item X" commutes with "Add item Y"; neither needs to block the other. Conflict rates drop when commands target different parts of the aggregate.

---

## 7. Java vs Rust

**Algebraic data types:** Rust enums with struct variants are a first-class language feature. `OrderEvent::Placed { order_id, customer }` is a single enum variant carrying named fields; pattern matching on it is exhaustive, meaning the compiler rejects unhandled variants. Java's `sealed interface` with nested `record` types achieves the same structural guarantee from Java 17+: the `sealed` keyword closes the type hierarchy; the compiler knows the exhaustive set of subtypes. Pattern matching `instanceof` (Java 16+) is approaching Rust's `match` in expressiveness, though it requires chained `if-else if` rather than a compact `match` block. Java 21's `switch` expressions with pattern matching bring it closer still.

**Default initialization:** Rust's `#[derive(Default)]` generates a `Default` implementation that zero-initializes every field: `u64` becomes 0, `String` becomes `""`, `Vec<T>` becomes `vec![]`, `bool` becomes `false`. Java has no equivalent derive mechanism; the `Order` class relies on Java's field initialization rules (`0` for numeric primitives, `false` for boolean, `null` for objects) and initializes `items` inline with `new ArrayList<>()`. For production code, a Java builder pattern or factory method is cleaner.

**Tuple types:** `Vec<(String, u32)>` in Rust stores typed pairs — the compiler knows the first element is a `String` and the second is a `u32`. Java's `List<String[]>` is untyped at the element level; the caller must know by convention that index 0 is the item name and index 1 is the quantity string. In production Java, this should be a `record ItemEntry(String item, int quantity)`, which restores type safety and eliminates the stringly-typed `String.valueOf(a.quantity())` conversion.

**Iterator ergonomics:** Rust's `iter().filter(...).map(...).collect()` pipeline is zero-allocation (iterator adapters are lazy) and type-inferred. The Java equivalent requires explicit loop indexing (`for (int i = 0; i < ids.size(); i++)`) because `List.get(i)` on two parallel lists is not zip-able without external library. Java Streams would clean this up: `IntStream.range(0, ids.size()).filter(i -> ids.get(i).equals(aggId)).mapToObj(events::get).collect(Collectors.toList())` — functional but verbose compared to Rust.

**Mutability discipline on events:** in the Rust snippet, `apply()` takes `&OrderEvent` (a shared reference — read-only borrow). This guarantees at compile time that `apply` cannot mutate the event. Java passes `OrderEvent` by reference, but since `OrderEvent` is a `sealed interface` with `record` implementations, records are structurally immutable (all fields are `final`). The immutability guarantee in Java is weaker: it relies on the `record` convention, not on a borrow-checked reference type. A mutable class that implements `OrderEvent` would compile and pass the `instanceof` check, silently undermining the pattern. Rust makes this impossible by construction — `&T` is always read-only regardless of what `T` is.

**Derive macros vs annotations:** Rust's `#[derive(Debug, Clone, PartialEq)]` is a procedural macro that generates code at compile time with no runtime cost. The generated `clone()` implementation copies every field; `partial_eq()` compares field by field. Java's equivalent requires either explicit boilerplate (`toString()`, `clone()`, `equals()`) or Lombok's `@Data` annotation (which generates the same code via annotation processing). Java `record` types automatically generate `equals()`, `hashCode()`, and `toString()` — but only for record types, not for ordinary classes. For non-record domain objects, Lombok fills the gap. Rust's derive system works uniformly for any struct or enum, making it strictly more composable.

**Memory layout of events:** Rust stores `OrderEvent` enum variants inline. A `Shipped { tracking: String }` variant occupies the discriminant (1 byte padded to align) plus the `String` struct (24 bytes on 64-bit: pointer + length + capacity). There is no heap allocation for the enum itself — the variant is stored inline in the `Vec<(u64, OrderEvent)>`. Java's `OrderEvent.Shipped` record is always a heap object — the `List<OrderEvent>` contains references to `Shipped` objects scattered across the heap, increasing GC pressure. For a system storing millions of events in memory (e.g., a large aggregate being replayed), Rust's compact layout can reduce memory footprint by 3–5× compared to Java's reference-typed object graph.
