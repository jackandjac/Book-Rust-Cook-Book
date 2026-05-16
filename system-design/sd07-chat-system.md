# Chapter 7: Chat System (WhatsApp / Slack)

> **Chapter goal:** Design a real-time chat system supporting 1:1 and group messaging, online presence, message ordering, and at-least-once delivery — with WebSocket connection management and message fan-out strategies.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A chat system allows users to exchange text messages in real time. The key operations are:

- **1:1 messaging** — a user sends a message to exactly one other user. The message must be delivered even if the recipient is temporarily offline.
- **Group chat** — a user sends a message to a conversation with up to 500 members. All online members receive the message in real time; offline members receive it on next login.
- **Message history** — clients can retrieve the last 30 days of messages for any conversation they belong to.
- **Online/offline presence** — clients can see whether a contact is currently online.
- **Message delivery receipts** — each message transitions through three states: *sent* (server acknowledged), *delivered* (recipient device acknowledged), and *read* (recipient opened the conversation).
- **Media support** — images, video, and files are out of scope for this chapter. Focus is on text messaging.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Message delivery latency | < 100 ms end-to-end |
| Message durability | Zero message loss after server ACK |
| Message ordering | Ordered within a conversation |
| Availability | 99.99% |
| Daily active users (DAU) | 50 million |
| Messages per user per day | 100 |

### 1.3 Scale Estimates

| Dimension | Value |
|---|---|
| Messages per day | 50M users × 100 messages = 5 billion |
| Peak messages/sec | 5B / 86,400 s × 3 (peak factor) ≈ 173,000/sec |
| Concurrent WebSocket connections | 50 million (one per active user) |
| Average message size | 100 bytes |
| Storage per day | 5B × 100 bytes = 500 GB/day |
| Storage for 30-day history | 500 GB × 30 = 15 TB/month |

**WebSocket connection budget:**

A WebSocket connection consumes approximately 10–50 KB of kernel and application memory. With 50M concurrent connections spread across a fleet of WebSocket servers:

```
50M connections / 50K connections per server = 1,000 WebSocket servers
```

Each server handles 50,000 persistent connections — achievable with an async I/O event loop (Tokio in Rust, Netty or Virtual Threads in Java).

**Message throughput breakdown:**

At 173,000 messages/sec with an average group size of 5 members, the fan-out service delivers:

```
173,000 messages/sec × 5 recipients = 865,000 delivery events/sec
```

These delivery events are writes to recipient WebSocket connections or offline message queues.

**Kafka partition sizing:**

Each Kafka partition can sustain approximately 10–50 MB/sec of throughput. With messages averaging 100 bytes and a peak of 173,000 messages/sec:

```
173,000 msg/sec × 100 bytes = 17.3 MB/sec total
17.3 MB/sec / 10 MB/sec per partition = 2 partitions minimum
```

In practice, production deployments use 64–256 partitions to allow fine-grained consumer parallelism (one fan-out consumer thread per partition). More partitions also allow per-conversation ordering to be enforced without coordination — messages for the same conversation always land on the same partition when partitioned by `conversation_id`.

**Storage cost breakdown:**

Cassandra stores each message row with clustering key overhead (~20 bytes) on top of the payload:

```
5B messages/day × (100 bytes payload + 20 bytes overhead) = 600 GB/day raw
× 3 replication factor = 1.8 TB/day across the cluster
× 30 days retention = 54 TB total cluster storage for message history
```

At $0.02/GB/month for NVMe storage, the message history store costs approximately $1,100/month — dominated by the replication factor. Enabling Cassandra's built-in compression (LZ4) on the `content` column typically achieves 2–4× compression on English text, halving the effective storage cost.

---

## 2. High-Level Architecture

```
  Mobile / Web Client
  ┌──────────────────┐
  │   User Device    │◄──────────────── Push Notifications ◄────┐
  └────────┬─────────┘                  (APNS / FCM)            │
           │ WebSocket                                           │
           ▼                                                     │
  ┌──────────────────┐     ┌──────────────────────────────────┐  │
  │  WebSocket Server│────►│        Message Service           │  │
  │  (stateful;      │     │  (validates, sequences, stores)  │  │
  │   1 conn/client) │     └──────────────┬───────────────────┘  │
  └──────────────────┘                    │                      │
                                          ▼                      │
                               ┌─────────────────────┐          │
                               │   Kafka Message Bus  │          │
                               │   (topic per shard)  │          │
                               └──────────┬──────────┘          │
                                          │                      │
                                          ▼                      │
                               ┌─────────────────────┐          │
                               │   Fan-out Service    │──────────┘
                               │  (online: push WS    │
                               │   offline: queue)    │
                               └──────────┬──────────┘
                                          │
                          ┌───────────────┼────────────────────┐
                          ▼               ▼                    ▼
               ┌─────────────────┐  ┌──────────┐   ┌──────────────────┐
               │ Message DB      │  │  Redis   │   │  Offline Queue   │
               │ (Cassandra,     │  │ Presence │   │  (Cassandra,     │
               │  history +      │  │ user_id→ │   │   user_id PK,    │
               │  offline msgs)  │  │ server   │   │   TTL 30 days)   │
               └─────────────────┘  └──────────┘   └──────────────────┘
```

**Message flow (happy path — recipient online):**

1. Sender's client sends `{conversation_id, message, client_seq}` over WebSocket.
2. WebSocket Server validates and forwards to Message Service.
3. Message Service assigns a server-side sequence number, persists to Cassandra, publishes to Kafka.
4. Fan-out Service consumes from Kafka, looks up all conversation members.
5. For each online recipient: look up `user_id → server_id` in Redis, forward message to that WebSocket Server.
6. Recipient WebSocket Server pushes the message over the recipient's open WebSocket.
7. Recipient device sends a delivery ACK; the receipt flows back to the sender's WebSocket.

**Message flow (recipient offline):**

Steps 1–4 are identical. At step 5, the Fan-out Service finds no active server for the recipient. It writes the message to the Offline Queue in Cassandra and triggers a push notification via APNS/FCM. On reconnect, the client pulls from the Offline Queue and sends delivery ACKs.

---

## 3. Component Deep-Dive

### 3.1 WebSocket vs HTTP Long Polling vs SSE

Three transport options exist for real-time server-to-client message delivery:

**HTTP Long Polling:** The client sends an HTTP request; the server holds it open until a message is available, then responds. The client immediately sends another request. Every message requires a full HTTP request/response cycle — including headers (500+ bytes each way) and TCP connection reuse overhead. Latency is acceptable but bandwidth waste is high. Best for environments where WebSocket is blocked by firewalls or proxies.

**Server-Sent Events (SSE):** A single HTTP connection streams events from server to client. Client-to-server communication still requires separate HTTP requests. SSE is unidirectional — good for notification feeds, but chat requires bidirectional communication (delivery receipts, typing indicators, read receipts must flow from client to server in real time). SSE forces a hybrid approach: SSE for downlink, REST for uplink. This complicates the server routing problem.

**WebSocket:** A single TCP connection carries full-duplex, framed messages in both directions after an HTTP Upgrade handshake. Frame overhead is 2–10 bytes (vs 500+ bytes for HTTP headers). The connection is persistent — no reconnection latency per message. WhatsApp, Slack, and Discord all use WebSocket as the primary transport. The tradeoff is statefulness: the WebSocket server must track which connection belongs to which user.

### 3.2 Connection Management and Routing

WebSocket servers are inherently stateful. When a user connects, a single WebSocket server owns that connection for the session duration. Sending a message to a user means knowing which WebSocket server currently holds their connection.

**Connection registry:** On connect, each WebSocket Server writes a mapping `user_id → server_id` to Redis with a short TTL (refreshed while the connection is alive). On disconnect, the entry is deleted or allowed to expire. This registry is the routing table for the fan-out service.

**Message routing:**

```
Fan-out Service:
1. Receive delivery event: (user_id, message)
2. Redis GET presence:{user_id} → server_id (or nil if offline)
3. If server_id found: forward message to WebSocket Server [server_id] via internal RPC
4. If nil: write to Offline Queue; trigger push notification
```

**WebSocket Server failover:** If a WebSocket Server crashes, all ~50,000 connections on it drop. Clients detect the disconnect within seconds (TCP keepalive or WebSocket ping/pong) and reconnect to any available server. The new server writes the updated `user_id → server_id` mapping. In-flight messages that were forwarded to the crashed server's internal RPC queue are retried by the fan-out service (Kafka consumer reprocesses unACKed events).

### 3.3 Message Ordering

Messages within a conversation must arrive in order, even when produced by different senders or when the network reorders packets.

**Per-conversation sequence numbers:** The Message Service assigns a monotonically increasing sequence number to every message in a conversation. For a conversation with ID `conv-42`, messages are numbered 1, 2, 3, … globally for that conversation. A Redis counter (`INCR conv:42:seq`) provides atomic incrementing at low latency.

**Cassandra storage schema:**

```
CREATE TABLE messages (
    conversation_id TEXT,
    message_id      BIGINT,      -- sequence number
    sender_id       TEXT,
    content         TEXT,
    sent_at         TIMESTAMP,
    PRIMARY KEY (conversation_id, message_id)
) WITH CLUSTERING ORDER BY (message_id ASC);
```

The `(conversation_id, message_id)` composite primary key ensures all messages for a conversation land on the same Cassandra partition (and replicas). Range queries for history fetch — `WHERE conversation_id = ? AND message_id > ?` — hit a single partition with sequential I/O. The clustering order keeps messages sorted on disk, making `LIMIT`-based pagination efficient.

**Client-side ordering:** Clients display messages ordered by `message_id` (server-assigned). If two messages arrive out of order over the network (due to WebSocket connection recovery), the client buffers and reorders before display. This is robust against the brief disorder that can occur during reconnection.

**Sequence number capacity:** A `BIGINT` sequence number (64-bit signed integer, max ~9.2 × 10¹⁸) is effectively inexhaustible. Even at 10,000 messages per second per conversation — an extreme group chat — the counter would take:

```
9.2 × 10¹⁸ / 10,000 msg/sec = 9.2 × 10¹⁴ seconds ≈ 29 million years
```

A 32-bit counter (max ~4.3 billion) would exhaust in:

```
4.3 × 10⁹ / 10,000 msg/sec = 430,000 seconds ≈ 5 days
```

Use 64-bit. The Redis `INCR` command operates on 64-bit integers natively.

**Multi-device ordering:** When the same user is logged in on two devices simultaneously (phone and laptop), both devices send messages with their own client-assigned temporary IDs. The server re-assigns the canonical `message_id` on receipt. Both devices subscribe to the conversation's message stream and replace the temporary ID with the server ID upon receiving the server broadcast — ensuring both devices display messages in the same canonical order.

### 3.4 Fan-Out for Group Chat

When a user sends a message to a 500-member group, the fan-out service must deliver it to all 500 members. Two pure strategies and one hybrid:

**Push model (write amplification):** On each message, write one delivery event per group member to their individual delivery queue. For a 500-member group: 1 message write + 500 delivery writes = 501 writes per message. At 173,000 messages/sec with average group size 5, total writes are 868,000/sec — manageable. But for a 500-member group sending 1 message: 500 writes in one request. For large groups this dominates storage write throughput.

**Pull model (read amplification):** Write the message once to the conversation store. Members poll for new messages on reconnect or periodically. No fan-out writes, but polling latency makes this unsuitable for real-time delivery. Used for message history retrieval (the history endpoint), not for live delivery.

**Hybrid model (WhatsApp/Slack approach):** For small groups (< 100 members): push fan-out — acceptable write amplification. For large groups (100–500 members): write the message once, fan out lazily. Online members are notified via a lightweight "new message" event (containing only `conversation_id` and `message_id`, not the full payload); they fetch the full message from Cassandra on demand. Offline members receive a push notification pointing to the conversation; on reconnect, they pull from history. This caps per-message write amplification at ~100 delivery events for any group size.

### 3.5 Message Delivery Receipts

Each message transitions through three receipt states that flow as separate events back through the system:

**Sent:** The Message Service has persisted the message and published it to Kafka. The server sends an ACK to the sender's WebSocket containing the server-assigned `message_id`. The sender device marks the message as "sent" (single checkmark in WhatsApp).

**Delivered:** The recipient's WebSocket Server has pushed the message to the recipient's device, and the device has ACKed at the transport level. The device sends a `{message_id, status=delivered}` receipt over its WebSocket. The receipt flows back through the system to the sender's WebSocket Server, which pushes the "delivered" state update to the sender (double checkmark).

**Read:** The recipient opens the conversation. The device sends a `{conversation_id, last_read_message_id, status=read}` receipt. This flows back to the sender (double blue checkmark). Storing read receipts as `last_read_message_id` per user per conversation (rather than per-message) reduces storage from O(messages × members) to O(members).

**Storage for receipts:** A `receipt` table keyed on `(conversation_id, user_id)` stores `last_delivered_message_id` and `last_read_message_id`. Updates are in-place (Cassandra `UPDATE`), not appends — constant storage per user per conversation.

### 3.6 Presence System

The presence system answers: "Is user X currently online?" It is read heavily (every contact list view, every conversation open) and must be eventually consistent — a few seconds of stale presence is acceptable.

**Client heartbeat:** Each connected client sends a WebSocket ping (or application-level heartbeat) every 5 seconds. The WebSocket Server receives the heartbeat and writes to Redis:

```
SET presence:{user_id} {server_id} EX 10
```

The key expires in 10 seconds. If the client disconnects or loses connectivity, the heartbeat stops, and the key expires naturally within 10 seconds — marking the user offline without requiring an explicit disconnect event.

**Reading presence:** A single `GET presence:{user_id}` returns the server_id (online) or nil (offline). This is a single Redis round-trip per user.

**Scaling presence reads for group chat:** For a 500-member group, showing presence for all members requires 500 Redis lookups. Pipelining batches these into one network round-trip:

```
PIPELINE:
  GET presence:user_1
  GET presence:user_2
  ...
  GET presence:user_500
→ one RTT, 500 results
```

Alternatively, a presence cache on the application server stores the group's member presence for 5 seconds, reducing Redis load for popular groups.

**Grace period:** Because heartbeats travel over a network that may experience transient packet loss, a single missed heartbeat should not mark a user offline. The 10-second TTL provides a 5-second grace period beyond the 5-second heartbeat interval. Client reconnect logic uses exponential backoff starting at 1 second, so typical recovery happens within 2–3 seconds.

**Redis memory for presence:** Each Redis key `presence:{user_id}` stores a short server ID string (e.g., `ws-server-042`, ~15 bytes) plus key overhead (~55 bytes per key in Redis 7). With 50M concurrent online users:

```
50M keys × (55 bytes overhead + 15 bytes value) = 50M × 70 bytes = 3.5 GB
```

A single Redis node with 8 GB RAM handles the full online presence set with headroom. For redundancy, a Redis Cluster with 3 primary shards (one per third of the user ID space) and 3 replicas provides both horizontal scaling and failure tolerance. At 173,000 heartbeat writes/sec (one per online user per 5-second interval, spread over time), each shard handles ~29,000 SET operations/sec — well within Redis's 100,000+ commands/sec throughput ceiling.

### 3.7 Offline Message Delivery

When a user is offline, messages destined for them are written to an offline message queue in Cassandra, partitioned by `user_id`. On reconnect:

1. The WebSocket Server detects the new connection and updates the presence registry.
2. The client sends its last-seen `message_id` per conversation.
3. The Message Service queries Cassandra for all messages newer than the client's watermark across all conversations the user belongs to.
4. The messages are streamed to the client over the WebSocket. The client sends delivery ACKs.
5. After ACK, offline queue entries are deleted (or marked delivered with a TTL).

**Push notifications as a reconnect trigger:** For iOS and Android, the app may be suspended and cannot maintain a WebSocket. The Fan-out Service sends a silent push notification via APNS (Apple) or FCM (Google) when a new message arrives for an offline user. The OS wakes the app in the background; the app opens a WebSocket and pulls pending messages. This is the mechanism used by WhatsApp, Signal, and Slack — the push notification carries no message content (privacy), only a trigger to reconnect.

**TTL for offline queue:** Messages that have not been delivered within 30 days are dropped (Cassandra TTL). This bounds storage and handles users who uninstall the app without logging out.

**Pull watermark on reconnect:** Storing a single `(user_id, conversation_id) → last_delivered_message_id` watermark in a `watermarks` table enables efficient catch-up. The reconnect query becomes:

```
SELECT * FROM messages
WHERE conversation_id = ? AND message_id > ?
LIMIT 200
```

One query per conversation the user belongs to. For a user in 20 conversations, reconnect pulls at most 20 Cassandra queries — all served from a single partition each, completing in < 10 ms per query on a well-provisioned cluster. The client renders messages as each batch arrives, giving a progressive loading experience rather than waiting for all conversations to synchronize before showing any content.

---

## 4. Key Algorithms & Data Structures

### 4.1 Rust Implementation

The Rust snippet implements a `ConversationSeq` (per-conversation monotonic sequence counter backed by a `HashMap`) and a `PresenceTracker` (simulates Redis TTL using `Instant` and a configurable TTL `Duration`). Both use `std` only, with `std::thread::sleep` for the TTL expiry test.

```rust
use std::collections::HashMap;
use std::time::{Duration, Instant};
use std::thread;

// ── ConversationSeq: per-conversation message sequence numbers ────────────────
struct ConversationSeq {
    next_seq: HashMap<String, u64>,
}

impl ConversationSeq {
    fn new() -> Self {
        ConversationSeq {
            next_seq: HashMap::new(),
        }
    }

    /// Return and increment the next sequence number for this conversation.
    fn next(&mut self, conversation_id: &str) -> u64 {
        let entry = self.next_seq.entry(conversation_id.to_string()).or_insert(0);
        let seq = *entry;
        *entry += 1;
        seq
    }
}

// ── PresenceTracker: simulates Redis TTL-based online/offline detection ────────
struct PresenceTracker {
    last_seen: HashMap<String, Instant>,
    ttl: Duration,
}

impl PresenceTracker {
    fn new(ttl_millis: u64) -> Self {
        PresenceTracker {
            last_seen: HashMap::new(),
            ttl: Duration::from_millis(ttl_millis),
        }
    }

    fn heartbeat(&mut self, user_id: &str) {
        self.last_seen.insert(user_id.to_string(), Instant::now());
    }

    fn is_online(&self, user_id: &str) -> bool {
        match self.last_seen.get(user_id) {
            Some(&last) => last.elapsed() < self.ttl,
            None => false,
        }
    }

    fn online_count(&self) -> usize {
        self.last_seen
            .values()
            .filter(|&&last| last.elapsed() < self.ttl)
            .count()
    }
}

fn main() {
    // ── Sequence number tests ─────────────────────────────────────────────────
    let mut seq = ConversationSeq::new();

    // Same conversation gets 0, 1, 2
    assert!(seq.next("conv-A") == 0, "conv-A first seq should be 0");
    assert!(seq.next("conv-A") == 1, "conv-A second seq should be 1");
    assert!(seq.next("conv-A") == 2, "conv-A third seq should be 2");

    // Different conversation has its own counter, starting at 0
    assert!(seq.next("conv-B") == 0, "conv-B first seq should be 0");
    assert!(seq.next("conv-B") == 1, "conv-B second seq should be 1");

    // conv-A continues independently
    assert!(seq.next("conv-A") == 3, "conv-A fourth seq should be 3");

    println!("ConversationSeq tests passed.");

    // ── Presence tests (TTL = 80ms) ───────────────────────────────────────────
    let mut presence = PresenceTracker::new(80);

    presence.heartbeat("alice");
    presence.heartbeat("bob");

    assert!(presence.is_online("alice"),   "alice should be online after heartbeat");
    assert!(presence.is_online("bob"),     "bob should be online after heartbeat");
    assert!(!presence.is_online("carol"),  "carol never heartbeated, should be offline");
    assert!(presence.online_count() == 2,  "online count should be 2");

    // Wait for TTL to expire
    thread::sleep(Duration::from_millis(100));

    assert!(!presence.is_online("alice"),  "alice should be offline after TTL");
    assert!(!presence.is_online("bob"),    "bob should be offline after TTL");
    assert!(presence.online_count() == 0,  "online count should be 0 after TTL");

    // Heartbeat brings alice back online
    presence.heartbeat("alice");
    assert!(presence.is_online("alice"),   "alice should be online after new heartbeat");
    assert!(presence.online_count() == 1,  "online count should be 1");

    println!("PresenceTracker tests passed.");
}
```

### 4.2 Java Implementation

The Java snippet mirrors the Rust structure. `ConversationSeq` uses `HashMap<String, Long>` with `getOrDefault` for the atomic-increment simulation. `PresenceTracker` uses `System.nanoTime()` (monotonic, immune to wall-clock adjustments) for TTL comparisons.

```java
import java.util.*;

public class ChatSystem {

    // ── ConversationSeq: per-conversation message sequence numbers ────────────
    static class ConversationSeq {
        private final Map<String, Long> nextSeq = new HashMap<>();

        /** Return and increment the next sequence number for this conversation. */
        long next(String conversationId) {
            long current = nextSeq.getOrDefault(conversationId, 0L);
            nextSeq.put(conversationId, current + 1);
            return current;
        }
    }

    // ── PresenceTracker: simulates Redis TTL via System.nanoTime() ────────────
    static class PresenceTracker {
        private final Map<String, Long> lastSeen = new HashMap<>(); // nanos
        private final long ttlNanos;

        PresenceTracker(long ttlMillis) {
            this.ttlNanos = ttlMillis * 1_000_000L;
        }

        void heartbeat(String userId) {
            lastSeen.put(userId, System.nanoTime());
        }

        boolean isOnline(String userId) {
            Long last = lastSeen.get(userId);
            if (last == null) return false;
            return (System.nanoTime() - last) < ttlNanos;
        }

        long onlineCount() {
            long now = System.nanoTime();
            return lastSeen.values().stream()
                    .filter(last -> (now - last) < ttlNanos)
                    .count();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        // ── ConversationSeq tests ─────────────────────────────────────────────
        ConversationSeq seq = new ConversationSeq();

        if (seq.next("conv-A") != 0) throw new RuntimeException("conv-A first seq should be 0");
        if (seq.next("conv-A") != 1) throw new RuntimeException("conv-A second seq should be 1");
        if (seq.next("conv-A") != 2) throw new RuntimeException("conv-A third seq should be 2");

        if (seq.next("conv-B") != 0) throw new RuntimeException("conv-B first seq should be 0");
        if (seq.next("conv-B") != 1) throw new RuntimeException("conv-B second seq should be 1");

        if (seq.next("conv-A") != 3) throw new RuntimeException("conv-A fourth seq should be 3");

        System.out.println("ConversationSeq tests passed.");

        // ── PresenceTracker tests (TTL = 80ms) ────────────────────────────────
        PresenceTracker presence = new PresenceTracker(80);

        presence.heartbeat("alice");
        presence.heartbeat("bob");

        if (!presence.isOnline("alice"))   throw new RuntimeException("alice should be online");
        if (!presence.isOnline("bob"))     throw new RuntimeException("bob should be online");
        if (presence.isOnline("carol"))    throw new RuntimeException("carol never heartbeated");
        if (presence.onlineCount() != 2)   throw new RuntimeException("online count should be 2");

        Thread.sleep(100);

        if (presence.isOnline("alice"))    throw new RuntimeException("alice should be offline after TTL");
        if (presence.isOnline("bob"))      throw new RuntimeException("bob should be offline after TTL");
        if (presence.onlineCount() != 0)   throw new RuntimeException("online count should be 0 after TTL");

        presence.heartbeat("alice");
        if (!presence.isOnline("alice"))   throw new RuntimeException("alice should be online after heartbeat");
        if (presence.onlineCount() != 1)   throw new RuntimeException("online count should be 1");

        System.out.println("PresenceTracker tests passed.");
    }
}
```

---

## 5. Tradeoffs

### 5.1 Fan-Out Strategy Comparison

| Dimension | Push Fan-out | Pull Fan-out | Hybrid |
|---|---|---|---|
| **Write amplification** | High (1 write per member) | None (1 write) | Bounded (push for small groups, 1 write for large) |
| **Read amplification** | None (pre-written) | High (each member reads) | Low (online members get notified; only offline members pull) |
| **Delivery latency** | Lowest (pre-delivered) | Highest (poll interval) | Low for online users; pull for offline |
| **Implementation complexity** | Low | Low | High (threshold logic, two code paths) |
| **Best for** | Small groups (< 100) | History retrieval | Production systems with mixed group sizes |

### 5.2 Message Storage: Cassandra vs MySQL

| Dimension | Cassandra | MySQL |
|---|---|---|
| **Write throughput** | Very high (LSM-tree, no joins) | Moderate (B-tree, ACID overhead) |
| **Range queries** | Efficient (clustering key sort) | Efficient (B-tree index scan) |
| **Schema flexibility** | High (wide rows, TTL per row) | Low (rigid schema, ALTER TABLE costly) |
| **Horizontal scaling** | Native (consistent hashing, no master) | Difficult (sharding is manual) |
| **Consistency** | Tunable (eventual to strong) | Strong (ACID) |
| **Best for** | High-write, append-only, time-series (chat messages) | Transactional, relational (user accounts, payment) |

### 5.3 WebSocket Server Statefulness vs Stateless API

WebSocket servers hold connection state (socket file descriptor, user identity, session keys) that cannot be trivially replicated across servers. This is the fundamental difference from REST API servers, which are stateless and can be load-balanced freely. The routing indirection through Redis (`user_id → server_id`) is the standard mitigation — it externalizes the state lookup so any server can route to the correct WebSocket server.

**Redis for presence vs purpose-built presence service:** Redis is appropriate for presence at up to ~100M users (with a Redis Cluster of 10–20 nodes). Beyond that scale (Twitter, WeChat), companies build dedicated presence microservices that shard presence state by user ID range, use in-memory hashmaps for O(1) lookup, and publish presence changes to subscribers via pub/sub — decoupling the read path from the TTL-update write path.

---

## 6. Failure Modes & Mitigations

### 6.1 WebSocket Server Crash (At-Least-Once Delivery)

**Scenario:** A WebSocket Server holding 50,000 connections crashes. All connections drop simultaneously. The fan-out service has forwarded 200 in-flight messages to that server's internal RPC queue. Those messages are lost from the RPC layer.

**Mitigations:**
- **At-least-once delivery via client retry:** Each client assigns a unique `idempotency_key` (UUID) to outbound messages. On reconnect, the client resubmits any messages that did not receive a server ACK. The Message Service deduplicates by `idempotency_key` (stored in a Redis set with a short TTL), storing the response and returning it on duplicate submission without reprocessing.
- **Kafka redelivery:** The fan-out service consumes from Kafka. Kafka offsets are committed only after the delivery to the WebSocket Server succeeds. If the WebSocket Server is down, the fan-out service retries the delivery to a new server (after the client reconnects and updates the presence registry). Messages are not lost; they are redelivered once the recipient reconnects.

### 6.2 Kafka Consumer Lag (Fan-Out Delay)

**Scenario:** The fan-out service falls behind on Kafka consumption. Messages are produced at 173,000/sec but consumed at only 120,000/sec. The consumer lag grows, increasing message delivery latency.

**Problem:** This is a delay, not a message loss — Kafka retains messages until the consumer group commits its offsets (or until the configured retention period expires).

**Mitigations:**
- **Horizontal scaling:** Kafka topics are partitioned. Adding more fan-out service instances allows parallel consumption, linearly increasing throughput.
- **Consumer lag monitoring:** Alert when lag exceeds a threshold (e.g., 10,000 messages or 500 ms of lag). Scale out preemptively.
- **Back-pressure to senders:** If lag grows beyond a critical threshold, the Message Service can apply back-pressure to WebSocket Servers (rate limiting on message acceptance) to protect downstream consumers.

### 6.3 Presence False Negatives (Network Hiccup)

**Scenario:** A mobile user on a flaky Wi-Fi connection misses two consecutive heartbeat intervals (10 seconds total). The Redis TTL for `presence:{user_id}` expires. The user appears offline to all contacts, even though they are still connected.

**Impact:** Messages sent during this window go to the offline queue and trigger push notifications, rather than being delivered instantly over the open WebSocket.

**Mitigations:**
- **Grace period:** The TTL (10 seconds) is intentionally 2× the heartbeat interval (5 seconds), providing one full interval of grace against a single missed heartbeat.
- **Client reconnect with exponential backoff:** If the WebSocket connection drops, the client reconnects with backoff starting at 1 second. Typically reconnected within 2–5 seconds.
- **Adaptive TTL:** Measure rolling heartbeat jitter per user; if a user's network consistently delivers heartbeats every 6–7 seconds (due to mobile radio power management), set their TTL to 15 seconds instead of 10. This reduces false negatives for known-flaky connections.

### 6.4 Hot User Problem (Celebrity / Broadcast)

**Scenario:** A verified celebrity account joins 2,000 group chats with 500 members each. Every message sent in any of those 2,000 groups triggers a delivery attempt to the celebrity's inbox. At modest group activity, the celebrity receives 50,000 delivery events per second — all routed to the same two or three fan-out consumer partitions (because Kafka partitions by conversation_id, and all messages in those groups land on nearby partitions).

**Mitigations:**
- **Cap fan-out per write:** For groups where a user is marked as a "celebrity" (high-follower count), skip immediate fan-out to that user. Instead, write a single pointer (conversation_id, message_id) to the celebrity's "pending conversations" queue. When the celebrity actively views a conversation, pull the messages on demand.
- **Eventual fan-out with batching:** Batch delivery events for high-volume recipients: instead of one delivery attempt per message, batch all new messages for that user across all groups and deliver in a single batch every 1 second. Reduces fan-out throughput by a factor of 50–100 for celebrity users.
- **Separate consumer topology:** Route delivery events for high-volume users to a dedicated Kafka consumer group with more partitions, isolating their processing from normal-user delivery.

---

## 7. Java vs Rust

### Async WebSocket Servers: Tokio vs Netty / Virtual Threads

Rust's Tokio runtime multiplexes millions of async tasks over a thread pool sized to the CPU count (typically 8–32 threads). Each WebSocket connection is an async task with a tiny per-task overhead (~1 KB of stack for a suspended future). At 50,000 connections per server, Tokio's overhead is ~50 MB of task state — comfortable within a server with 16 GB RAM. Context switches between tasks happen at `await` points and never touch the OS scheduler: Tokio tasks are green threads. This enables extremely high connection density with predictable latency.

Java's traditional thread-per-connection model collapses above ~10,000 connections (each OS thread consumes 512 KB–2 MB of stack). Production Java chat servers use Netty, which implements an event loop (similar to Tokio) using NIO selectors. Java 21's Virtual Threads (Project Loom) provide a third option: lightweight OS-thread abstractions that look like regular threads but are multiplexed by the JVM, similar to Tokio tasks. Virtual Threads achieve comparable connection density to Tokio but require Java 21+ and are most natural when the blocking I/O model fits (e.g., blocking database calls become non-blocking automatically). For CPU-bound fan-out operations, Netty's explicit event loop model may still outperform Virtual Threads due to lower scheduling overhead.

### Shared State: `Arc<Mutex<HashMap>>` vs `ConcurrentHashMap`

The presence tracker and routing table are shared across threads on both platforms.

In Rust, sharing mutable state across threads requires explicit ownership. The standard pattern is `Arc<Mutex<HashMap<String, String>>>`. `Arc` (atomic reference counting) allows multiple threads to hold a reference; `Mutex` enforces exclusive access during writes. The Rust compiler refuses to compile code that accesses the inner `HashMap` without locking the `Mutex` — data races are impossible at compile time. The downside is that a single `Mutex` serializes all concurrent reads, even though reads are safe to parallelize. `RwLock<HashMap>` allows multiple concurrent readers with exclusive writers and is the idiomatic choice for read-heavy presence lookups.

Java's `ConcurrentHashMap` provides lock-striping: the map is internally divided into 16 (or more) segments, each with its own lock. Concurrent reads are lock-free (using `volatile` reads and CAS operations). Concurrent writes to different buckets proceed in parallel. This gives better concurrent throughput than a global `RwLock` for high-contention workloads, but the safety guarantee is weaker: Java does not prevent you from iterating the map while another thread modifies it (you get a weakly consistent view), whereas Rust's type system prevents this class of bug entirely.

### Data Race Prevention

The deepest difference is not runtime performance — it is the compile-time guarantee. Rust's ownership and borrowing rules make data races a compile error. A thread that holds a reference to shared data cannot simultaneously hold a mutable reference; the compiler enforces this across all call sites. Java's `ConcurrentHashMap`, `synchronized` blocks, and `volatile` fields all express intent but cannot prevent a developer from accessing a non-concurrent `HashMap` from two threads without synchronization — the error surfaces only at runtime as a data corruption or `ConcurrentModificationException`.

For a chat system where correctness of message delivery and presence state is critical, Rust's compile-time guarantees eliminate an entire category of production incidents. Java teams compensate with static analysis tools (Error Prone, FindBugs/SpotBugs), code review discipline, and extensive concurrency testing — all of which are valuable but none of which match the unconditional compile-time safety of the Rust borrow checker.

### Summary Comparison

| Dimension | Rust | Java |
|---|---|---|
| **Async model** | Tokio (green threads, zero-cost futures) | Netty (NIO) or Virtual Threads (Java 21+) |
| **Connections per server** | 100K+ (1 KB/task) | 50K+ with Netty; 100K+ with Virtual Threads |
| **Shared-state safety** | Compile-time (borrow checker) | Runtime (discipline + tools) |
| **Presence map** | `Arc<RwLock<HashMap>>` | `ConcurrentHashMap` |
| **Memory per connection** | ~1–2 KB async task overhead | ~5–10 KB Netty channel context |
| **GC pauses** | None | Minor GC every few seconds; rare major GC |
| **Ecosystem maturity for chat** | Growing (Tokio-tungstenite) | Mature (Netty, Spring WebFlux) |

Both stacks are production-viable for a 50M DAU chat system. The choice is driven by team familiarity, existing infrastructure, and operational priorities. Where maximum connection density and predictable tail latency are non-negotiable (financial trading, real-time multiplayer), Rust's deterministic memory model has a decisive edge. Where rapid feature iteration and a large developer talent pool matter more, Java's mature ecosystem and Virtual Threads close most of the performance gap.
