# Chapter 10: Notification System

> **Chapter goal:** Design a multi-channel notification system (push, email, SMS) handling 10M notifications/day with priority queues, rate limiting, deduplication, and user preference management.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A notification system is the connective tissue between an application and its users. Whether it is a one-time password, a shipping update, or a promotional discount, the system must reliably route each message to the right user on the right channel at the right time, without ever delivering the same message twice.

The system must satisfy the following functional requirements:

- **Multi-channel delivery** — send push notifications to iOS (APNs) and Android (FCM) devices, email via third-party SMTP relays (SendGrid, Amazon SES), and SMS via Twilio or equivalent. Each channel has a distinct third-party API, SLA, and cost model.
- **Scheduled delivery** — callers may request delivery at a future timestamp ("send this promotional email at 09:00 Monday in the user's local timezone"). The scheduler must handle millions of pending jobs without polling overhead.
- **Priority tiers** — messages are classified as `CRITICAL` (security alerts, order confirmations, OTPs), `TRANSACTIONAL` (shipping updates, receipts), or `MARKETING` (promotions, newsletters). Critical messages bypass rate limiting and marketing caps; marketing messages are subject to frequency caps to prevent user fatigue.
- **User opt-in / opt-out per channel** — each user maintains independent preferences for push, email, and SMS. The preference service must honor opt-outs within seconds; GDPR-compliant propagation must complete within 24 hours.
- **Deduplication** — if the same logical notification is submitted twice (due to producer retries), only one delivery attempt reaches the user. Dedup window is 24 hours.
- **Delivery receipts** — downstream workers emit delivery events (sent, delivered, bounced, opened) that feed analytics and allow re-engagement logic.
- **Template management** — notifications are created from versioned templates with variable substitution. Templates support localization by user locale and A/B testing variants.

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Push notification delivery latency | < 5 seconds end-to-end |
| Email / SMS delivery latency | < 30 seconds end-to-end |
| Overall delivery rate | 99.9% (at most 0.1% permanent failures) |
| Throughput — average | 10M notifications/day ≈ 116/sec |
| Throughput — peak campaign | 1M notifications/hour ≈ 278/sec |
| Availability of notification API | 99.9% uptime |
| User preference propagation | Opt-out honored within 30 seconds in cache; DB within 24 hours |

### 1.3 Scale Estimates

**Throughput breakdown:**

```
10M notifications/day ÷ 86,400 sec = ~116/sec average
1M notifications/hour ÷ 3,600 sec  = ~278/sec peak (campaign burst)
Channel split (estimated):  push 60% · email 30% · SMS 10%
```

**User preference storage:**

```
500M users × 3 channels × ~100 bytes/record = ~150 GB
Fits in MySQL with sharding on user_id; hot rows cached in Redis.
```

**Template storage:**

```
10,000 active templates × 10 locale variants × 2 KB/template ≈ 200 MB
Entirely in memory on API nodes after a warm-up load.
```

**Dedup key storage in Redis:**

```
At 278/sec peak × 86,400 sec/day = ~24M unique dedup keys/day (worst case)
Each key: ~120 bytes (key string + TTL metadata)
Total: ~2.9 GB Redis RAM for dedup — manageable on a single Redis node.
```

---

## 2. High-Level Architecture

```
   Calling Services
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ Service A│  │ Service B│  │ Service C│  (order svc, auth svc, marketing svc...)
   └────┬─────┘  └────┬─────┘  └────┬─────┘
        │              │              │
        └──────────────┴──────────────┘
                       │  REST / gRPC
                       ▼
          ┌────────────────────────────┐
          │   Notification Service API │  validate · dedup · pref-check · enqueue
          └────────────┬───────────────┘
                       │
          ┌────────────▼───────────────────────────────────────────┐
          │                    Apache Kafka                         │
          │  ┌─────────────────────┐  ┌──────────────────────────┐ │
          │  │notifications.critical│  │notifications.transactional│ │
          │  └──────────┬──────────┘  └────────────┬─────────────┘ │
          │  ┌──────────▼────────────────────────────────────────┐  │
          │  │         notifications.marketing                    │  │
          │  └───────────────────────┬───────────────────────────┘  │
          └──────────────────────────┼───────────────────────────────┘
                      ┌──────────────┼──────────────┐
                      ▼              ▼              ▼
              ┌────────────┐ ┌────────────┐ ┌────────────┐
              │ Push Worker│ │Email Worker│ │ SMS Worker │
              └─────┬──────┘ └─────┬──────┘ └─────┬──────┘
                    │              │              │
              ┌─────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
              │  APNs/FCM  │ │SendGrid/SES│ │   Twilio   │
              └────────────┘ └────────────┘ └────────────┘

   Supporting Services:
   ┌──────────────────────┐    ┌──────────────────────────────────┐
   │ User Preference Svc  │    │ Analytics Pipeline               │
   │  MySQL + Redis cache │    │  Kafka → ClickHouse → Grafana    │
   └──────────────────────┘    └──────────────────────────────────┘
```

The Notification Service API is the single entry point. It performs validation (malformed request, unknown template), deduplication (Redis SETNX on the dedup key), preference lookup (Redis cache of user opt-in/opt-out), and finally enqueues the notification onto the appropriate Kafka topic. Workers downstream are stateless, horizontally scalable, and channel-specific — each worker group knows exactly which third-party API to call and applies that channel's retry and rate-limit logic independently.

**Request flow for a typical transactional notification:**

1. Calling service (e.g., Order Service) sends `POST /notifications` with `{ template_id, user_id, channel, reference_id, priority, variables }`.
2. The API node looks up the template from the in-memory template store; validates that all required `variables` keys are present; renders the body for the user's locale.
3. The API node computes `dedup_key = sha256(user_id || template_id || reference_id || channel || date)` and calls Redis `SET dedup_key "" EX 86400 NX`. If the key exists, the API returns `202 Accepted` without enqueuing.
4. The API node checks user preferences from the Redis preference cache. If the user has opted out of the requested channel, the API returns `202 Accepted` (not `4xx` — rejecting a notification with an error would cause the caller to retry indefinitely).
5. For non-critical notifications, the API checks the token bucket rate limiter. If the bucket is empty, the notification is dropped.
6. The notification is serialized and produced to the appropriate Kafka topic. The API returns `202 Accepted` to the caller.
7. A worker pod consumes the Kafka message, calls the channel-specific third-party API (APNs, SendGrid, Twilio), and emits a delivery event back to Kafka for analytics ingestion.

**Scaling the API tier:** At 278 req/sec peak, a single API pod handles the full load comfortably. However, availability requires at least 3 pods behind a load balancer. Each pod is stateless — all shared state (dedup keys, rate limit counters, preferences) lives in Redis and MySQL. The API pod keeps the template store in-process memory (reloaded from a database every 5 minutes), so template renders cost zero network round trips.

---

## 3. Component Deep-Dive

### 3.1 Multi-Channel Architecture

Each delivery channel has a fundamentally different cost, latency, and reliability profile. Push notifications are nearly free and deliver in seconds but require a registered device token; email is pennies per thousand messages but can be rejected as spam; SMS is expensive ($0.006–$0.05 per message) and reaches feature phones but carries regulatory obligations (TCPA in the US, GDPR in Europe). Treating all three channels as interchangeable would make it impossible to tune retry logic, throughput caps, and failure handling appropriately.

The architecture models each channel as a separate Kafka consumer group reading from a separate topic. This means the email worker's backlog never delays a push notification, and the SMS worker can be horizontally scaled independently based on cost constraints. Workers implement channel-specific retry logic: APNs allows up to 3 retries with exponential backoff; SMS is typically retried once and then dead-lettered (duplicate SMS messages are highly disruptive to users); email backends provide their own queuing so application-level retries are avoided.

### 3.2 Priority Queue Design

Marketing campaigns generate sudden load spikes: a single "flash sale" email blast to 10M users submits all 10M messages within minutes. Without priority isolation, this campaign would delay OTP and security alert delivery for hours.

The solution is three distinct Kafka topics rather than a single topic with a priority field:

| Topic | Contents | Consumer throughput cap |
|---|---|---|
| `notifications.critical` | Security alerts, OTPs, order confirmations | Uncapped; always drain first |
| `notifications.transactional` | Shipping updates, payment receipts | High cap (10,000/sec) |
| `notifications.marketing` | Promotions, newsletters, re-engagement | Capped (500/sec); subject to user daily limits) |

Each topic has its own consumer group. The critical consumer group runs with a very small number of partitions but high-priority CPU scheduling. The marketing consumer group scales out but its `max.poll.records` and inter-fetch delay are tuned conservatively to prevent one campaign from monopolizing broker resources.

Critical notifications bypass the user-level rate limiter entirely. A user should never miss a security alert because they received too many promotional emails earlier in the day.

### 3.3 User Preference Service

Every notification must be checked against the user's channel preferences before delivery. A user who has opted out of SMS must not receive a text message, even if the calling service explicitly requests one. The preference service is the authority for this decision.

The preference schema in MySQL:

```
user_preference (
    user_id      BIGINT,
    channel      ENUM('push', 'email', 'sms'),
    enabled      BOOLEAN,
    quiet_start  TINYINT,   -- hour 0-23 in user's timezone
    quiet_end    TINYINT,
    timezone     VARCHAR(64),
    updated_at   TIMESTAMP,
    PRIMARY KEY (user_id, channel)
)
```

The full preference table for 500M users × 3 channels = 1.5B rows is approximately 150 GB — too large to hot-query on every notification. Redis provides a cache-aside layer: on a cache miss, the API node fetches the preference row from MySQL, caches it in Redis with a 5-minute TTL, and serves subsequent reads from cache. A preference update (user opts out) immediately invalidates the Redis key so propagation happens within the next cache population cycle. For GDPR compliance, the system guarantees that a preference change is fully propagated — meaning no new notification will use a stale preference — within 24 hours of the update, and typically within 5 minutes.

### 3.4 Deduplication

Producer retries are a fundamental property of distributed systems. When a calling service submits a notification but its network connection drops before receiving the acknowledgment, it retries. Without deduplication, the user would receive the same OTP twice — confusing and potentially a security issue.

The deduplication key is a deterministic hash of the fields that identify a unique notification intent:

```
dedup_key = hash(user_id, template_id, reference_id, channel, calendar_date)
```

The `reference_id` is an opaque identifier the caller provides (e.g., `order_id` for a shipping notification). The `calendar_date` component limits the dedup window to a single day, preventing a daily digest from being suppressed forever if the same template is legitimately re-sent the next day.

Before enqueueing, the API node calls `SET dedup_key "" EX 86400 NX` (Redis SETNX semantics). If the key already exists, the notification is dropped and the caller receives a `202 Accepted` (idempotent — from the caller's perspective the notification was accepted, it just will not be re-sent). If the Redis SETNX returns success, the notification is enqueued and the key is written with a 24-hour TTL. The SETNX operation is atomic, so concurrent duplicate submissions from multiple API nodes are handled correctly.

When Redis is unavailable, the fallback policy differs by priority: critical notifications are allowed through without dedup (at-least-once delivery is preferred over possible omission); marketing notifications are held until Redis recovers (duplicate marketing messages are worse than a brief delay).

### 3.5 APNs / FCM Integration

Apple Push Notification service (APNs) and Firebase Cloud Messaging (FCM) are the two push channels, together covering the global smartphone market. Both use HTTP/2 multiplexing, which allows the push worker to open a persistent connection and send hundreds of requests in parallel without the overhead of per-request TLS handshakes.

**APNs specifics:** Authentication uses either a certificate (valid for 1 year) or a JWT token (valid for 1 hour, must be refreshed). The push worker maintains a token refresh loop. When APNs returns a `410 Gone` response for a device token, it means the app was uninstalled — the worker must immediately delete that token from the device token table and must not retry. Failure to clean stale tokens wastes throughput and can trigger APNs rate limits.

**FCM specifics:** FCM tokens also expire or are rotated when the app reinstalls. The `collapse_key` parameter allows FCM to replace a pending notification with a newer one of the same type (e.g., a new balance update replaces a stale one while the phone is offline). The batch send API accepts up to 500 device tokens per request, which the push worker exploits to amortize HTTP/2 overhead across hundreds of deliveries per round trip.

### 3.6 Rate Limiting per User

Even for channels where delivery is free and instantaneous, unbounded notification frequency degrades the user experience and increases unsubscribe rates. The system enforces two layers of per-user rate limiting:

1. **Per-hour cap** — every user is limited to a maximum of 10 notifications per channel per hour, implemented as a token bucket in Redis. Tokens refill at a rate of 10 per hour. Critical notifications are exempt from this cap.
2. **Daily marketing cap** — each user may receive at most 3 marketing notifications per day across all channels combined. This is checked before enqueueing and stored as a daily counter in Redis with a TTL aligned to midnight in the user's local timezone.

The token bucket for the hourly cap is a simple Redis key with a count and a TTL. The Lua script atomically reads, decrements, and writes the counter in a single Redis round trip, preventing races where two concurrent notifications each read count=1 and both proceed despite only one token being available.

**Redis Lua script for token bucket (hourly cap):**

```lua
local key    = KEYS[1]          -- e.g. "ratelimit:user:42:push:2026-05-16:13"
local limit  = tonumber(ARGV[1]) -- e.g. 10
local ttl    = tonumber(ARGV[2]) -- seconds until the next hour boundary

local count = redis.call("GET", key)
if count == false then
    redis.call("SET", key, 1, "EX", ttl)
    return 1   -- allowed; first request in this window
end
count = tonumber(count)
if count >= limit then
    return 0   -- rejected
end
redis.call("INCR", key)
return 1        -- allowed
```

The key includes the user ID, channel, date, and hour component so that the bucket automatically resets as the clock advances to a new hour. The TTL is set to the number of seconds remaining until the next hour boundary — ensuring the counter key expires naturally without a separate cleanup process.

**Quiet hours enforcement:** The preference service stores a `quiet_start` and `quiet_end` hour for each user. Non-critical notifications submitted during the user's quiet hours are either dropped immediately or re-scheduled to deliver at the next allowed window (e.g., 09:00 in the user's timezone). The choice between drop and re-schedule is configurable per notification type: marketing notifications are dropped (users do not want to receive a "sale ends in 2 hours" email at midnight), while transactional notifications (shipping update) are typically re-scheduled for delivery at the first permitted minute.

### 3.7 Scheduled Delivery

Many notifications have a delivery time that is not "now". A promotional email timed to arrive at 09:00 on a Monday in the user's local timezone, or a reminder that fires 24 hours before a flight departure, must be stored and re-activated at the appropriate moment.

The scheduler stores pending notifications in a MySQL table:

```
scheduled_notification (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    deliver_at    DATETIME,   -- UTC scheduled delivery time
    payload       JSON,       -- full notification request
    status        ENUM('pending', 'fired', 'cancelled'),
    INDEX idx_deliver_at (deliver_at, status)
)
```

A scheduler service polls this table every second for rows where `deliver_at <= NOW() AND status = 'pending'`. It atomically updates `status = 'fired'` using an optimistic-lock `WHERE status = 'pending'` clause to prevent concurrent scheduler pods from double-firing. Once fired, the payload is submitted to the Notification Service API exactly as if the caller had just sent it — the normal deduplication, preference-check, and Kafka-enqueue flow applies.

For millions of scheduled notifications, polling every second with an indexed `deliver_at` query scans only the narrow time window that is due — typically < 1,000 rows per second, well within MySQL's capacity. At extreme scale (10M+ pending scheduled notifications), the scheduler table is sharded by `deliver_at` day, and only the current day's shard is actively polled.

### 3.8 Template Engine

Hardcoding notification text in service code makes localization, legal review, and A/B testing impractical. Templates decouple message content from delivery logic.

A template is a versioned record with a locale-keyed body:

```json
{
  "template_id": "order_shipped_v3",
  "locale_bodies": {
    "en-US": "Your order {{order_id}} has shipped to {{address}}. Expected: {{eta}}.",
    "es-MX": "Tu pedido {{order_id}} ha sido enviado a {{address}}. Llegada estimada: {{eta}}."
  }
}
```

At send time, the API node selects the body for the user's locale (falling back to `en-US` if the locale is unavailable), replaces `{{variable}}` placeholders with caller-supplied values, and stores the rendered text in the Kafka message. Workers never access templates directly — they receive fully rendered messages, keeping workers stateless.

A/B testing is supported by assigning the user to a variant (based on a hash of `user_id % num_variants`) and selecting the corresponding template version. Variant assignment is stable: the same user always sees the same variant, ensuring experiment integrity.

Template versioning follows a simple convention: `order_shipped_v1`, `order_shipped_v2`. The calling service explicitly specifies the template ID in the notification request, so templates are never silently upgraded for in-flight notification requests. Old template versions are archived (not deleted) so that delivery receipt events referencing an old template ID can still be resolved.

**Template validation at registration time:** When a new template is uploaded, the system validates that every `{{variable}}` placeholder is documented in the template metadata. If the calling service submits a notification that is missing a required variable, the API rejects the request synchronously with a `400 Bad Request` rather than silently rendering a broken template to the user. This contract — validate early, render late — prevents malformed messages from reaching users at scale.

### 3.9 Analytics and Delivery Receipts

Each delivery worker emits structured events to a dedicated Kafka topic (`notification.events`) after every send attempt:

```json
{
  "event_type": "delivered",
  "notification_id": "n1",
  "user_id": 42,
  "channel": "push",
  "template_id": "order_shipped_v3",
  "sent_at": "2026-05-16T13:22:05Z",
  "delivered_at": "2026-05-16T13:22:06Z",
  "provider": "fcm"
}
```

Possible `event_type` values: `sent` (submitted to provider), `delivered` (provider confirmed receipt by device), `bounced` (email hard bounce), `opened` (email pixel or push open callback), `failed` (all retries exhausted). These events are consumed by an analytics Flink job and written to ClickHouse, where product teams query delivery rates, bounce rates, and open rates by template, channel, and user segment.

**Delivery funnel metrics to monitor:**
- Enqueue rate (messages produced to Kafka) — should match API throughput
- Dispatch rate (messages successfully sent to provider) — should be close to enqueue rate; gap indicates worker lag or throttling
- Delivery rate (provider-confirmed delivery) — channel-dependent: push ~95%, email ~85%, SMS ~98%
- Open rate (user-opened) — push ~20%, email ~15%

Alerting thresholds: if the gap between enqueue rate and dispatch rate exceeds 5 minutes of backlog, page on-call. If the delivery rate for any channel drops below 90% over a 5-minute window, investigate provider outage or token invalidation storm.

---

## 4. Key Algorithms

### 4.1 Rust — Priority Dispatch with Deduplication and Rate Limiting

The snippet models a local `NotificationDispatcher` that enforces deduplication (based on an idempotency key with a configurable TTL) and a per-user daily cap (bypassed for critical priority). This mirrors the in-process logic executed by the Notification Service API node before writing to Kafka.

```rust
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
enum Priority {
    Marketing = 0,
    Transactional = 1,
    Critical = 2,
}

#[derive(Debug, Clone)]
struct Notification {
    id: String,
    user_id: u64,
    channel: String,
    priority: Priority,
    template: String,
    dedup_key: String,
}

struct NotificationDispatcher {
    sent_keys: HashMap<String, Instant>, // dedup_key -> sent_at
    dedup_ttl: Duration,
    counters: HashMap<u64, u32>, // user_id -> sent count today
    daily_limit: u32,
}

impl NotificationDispatcher {
    fn new(dedup_ttl_secs: u64, daily_limit: u32) -> Self {
        NotificationDispatcher {
            sent_keys: HashMap::new(),
            dedup_ttl: Duration::from_secs(dedup_ttl_secs),
            counters: HashMap::new(),
            daily_limit,
        }
    }

    fn dispatch(&mut self, notif: &Notification) -> Result<(), String> {
        // 1. Deduplication check
        if let Some(&sent_at) = self.sent_keys.get(&notif.dedup_key) {
            if sent_at.elapsed() < self.dedup_ttl {
                return Err(format!(
                    "duplicate: dedup_key '{}' already seen within TTL",
                    notif.dedup_key
                ));
            }
        }

        // 2. Daily rate limit (Critical bypasses this check)
        if notif.priority != Priority::Critical {
            let count = self.counters.entry(notif.user_id).or_insert(0);
            if *count >= self.daily_limit {
                return Err(format!(
                    "rate_limited: user {} hit daily limit of {}",
                    notif.user_id, self.daily_limit
                ));
            }
            *count += 1;
        }

        // 3. Record dedup key as successfully dispatched
        self.sent_keys.insert(notif.dedup_key.clone(), Instant::now());
        Ok(())
    }

    fn clean_expired(&mut self) {
        let ttl = self.dedup_ttl;
        self.sent_keys.retain(|_, sent_at| sent_at.elapsed() < ttl);
    }
}

fn main() {
    let mut dispatcher = NotificationDispatcher::new(86400, 3);

    let notif_a = Notification {
        id: "n1".to_string(),
        user_id: 42,
        channel: "push".to_string(),
        priority: Priority::Transactional,
        template: "Your order has shipped".to_string(),
        dedup_key: "42:tmpl1:ref1:push:2026-05-16".to_string(),
    };

    // First dispatch succeeds
    assert!(dispatcher.dispatch(&notif_a).is_ok());

    // Duplicate dispatch (same dedup_key) is rejected
    assert!(dispatcher.dispatch(&notif_a).is_err());

    // Daily limit: 3 marketing notifications succeed, 4th is rejected
    let mut last_result = Ok(());
    for i in 0..4u32 {
        let marketing = Notification {
            id: format!("m{}", i),
            user_id: 99,
            channel: "email".to_string(),
            priority: Priority::Marketing,
            template: "Sale!".to_string(),
            dedup_key: format!("99:promo:ref{}:email:2026-05-16", i),
        };
        last_result = dispatcher.dispatch(&marketing);
    }
    assert!(last_result.is_err()); // 4th is over the daily limit

    // Critical priority bypasses the daily limit entirely
    let critical = Notification {
        id: "c1".to_string(),
        user_id: 99,
        channel: "push".to_string(),
        priority: Priority::Critical,
        template: "Security alert".to_string(),
        dedup_key: "99:sec:ref1:push:2026-05-16".to_string(),
    };
    assert!(dispatcher.dispatch(&critical).is_ok());

    // Derived Ord: Critical > Transactional > Marketing
    assert!(Priority::Critical > Priority::Transactional);
    assert!(Priority::Transactional > Priority::Marketing);

    dispatcher.clean_expired();
    println!("All assertions passed.");
}
```

**Key design points:**
- `Priority` derives `Ord` with variant declaration order matching the numeric discriminants, so `Critical > Transactional > Marketing` without writing a custom comparator.
- `Instant::elapsed()` measures wall-clock time without requiring a mutable reference — a clean fit for the dedup TTL check.
- `HashMap::entry(...).or_insert(0)` initialises the counter on first use and returns a mutable reference in one step.
- `clean_expired` is called periodically (e.g., every 5 minutes) to reclaim memory from TTL-expired dedup keys.

### 4.2 Java — Priority Dispatch with Deduplication and Rate Limiting

```java
import java.util.*;

public class NotificationSystem {

    enum Priority { MARKETING, TRANSACTIONAL, CRITICAL }

    record Notification(String id, long userId, String channel,
                        Priority priority, String template, String dedupKey) {}

    static class NotificationDispatcher {
        private final Map<String, Long> sentKeys = new HashMap<>(); // dedupKey -> nanos
        private final long dedupTtlNanos;
        private final Map<Long, Integer> counters = new HashMap<>(); // userId -> count
        private final int dailyLimit;

        NotificationDispatcher(long dedupTtlMillis, int dailyLimit) {
            this.dedupTtlNanos = dedupTtlMillis * 1_000_000L;
            this.dailyLimit = dailyLimit;
        }

        // Returns null on success; returns an error message string on failure.
        String dispatch(Notification n) {
            long now = System.nanoTime();

            // 1. Deduplication check
            Long sentAt = sentKeys.get(n.dedupKey());
            if (sentAt != null && (now - sentAt) < dedupTtlNanos) {
                return "duplicate: dedupKey '" + n.dedupKey() + "' seen within TTL";
            }

            // 2. Daily rate limit (CRITICAL bypasses)
            if (n.priority() != Priority.CRITICAL) {
                int count = counters.getOrDefault(n.userId(), 0);
                if (count >= dailyLimit) {
                    return "rate_limited: user " + n.userId()
                            + " hit daily limit of " + dailyLimit;
                }
                counters.put(n.userId(), count + 1);
            }

            // 3. Record dedup key
            sentKeys.put(n.dedupKey(), now);
            return null; // success
        }

        void cleanExpired() {
            long now = System.nanoTime();
            sentKeys.entrySet().removeIf(e -> (now - e.getValue()) >= dedupTtlNanos);
        }
    }

    static void check(boolean cond, String msg) {
        if (!cond) throw new RuntimeException("Assertion failed: " + msg);
    }

    public static void main(String[] args) {
        NotificationDispatcher dispatcher =
                new NotificationDispatcher(86_400_000L, 3);

        Notification notifA = new Notification(
                "n1", 42L, "push", Priority.TRANSACTIONAL,
                "Your order has shipped", "42:tmpl1:ref1:push:2026-05-16");

        check(dispatcher.dispatch(notifA) == null, "first dispatch succeeds");
        check(dispatcher.dispatch(notifA) != null, "duplicate is rejected");

        String lastResult = null;
        for (int i = 0; i < 4; i++) {
            Notification m = new Notification(
                    "m" + i, 99L, "email", Priority.MARKETING,
                    "Sale!", "99:promo:ref" + i + ":email:2026-05-16");
            lastResult = dispatcher.dispatch(m);
        }
        check(lastResult != null, "4th marketing notif is rate-limited");

        Notification critical = new Notification(
                "c1", 99L, "push", Priority.CRITICAL,
                "Security alert", "99:sec:ref1:push:2026-05-16");
        check(dispatcher.dispatch(critical) == null, "critical bypasses daily limit");

        check(Priority.CRITICAL.ordinal() > Priority.TRANSACTIONAL.ordinal(),
              "CRITICAL > TRANSACTIONAL");
        check(Priority.TRANSACTIONAL.ordinal() > Priority.MARKETING.ordinal(),
              "TRANSACTIONAL > MARKETING");

        dispatcher.cleanExpired();
        System.out.println("All checks passed.");
    }
}
```

**Key design points:**
- `record Notification(...)` provides a compact, immutable value type without boilerplate — a Java 16+ feature, fully available under `--release 17`.
- `String dispatch(...)` returning `null` on success is an explicit design choice avoiding checked exceptions; callers must null-check the return value, which is self-documenting in the calling code.
- `System.nanoTime()` is used instead of `System.currentTimeMillis()` because it is monotonic and not subject to wall-clock adjustments (NTP leap seconds, DST). The TTL is stored in nanos accordingly.
- `Long` boxing in `Map<String, Long>` adds ~16 bytes per entry compared to a primitive `long`. In production this map would be replaced with a purpose-built off-heap structure or Redis.
- No `java.time.*` is imported — TTLs are expressed as raw `long` milliseconds, keeping all imports within `java.util.*`.

---

## 5. Tradeoffs

### 5.1 Channel Comparison

| Dimension | Push (APNs/FCM) | Email | SMS |
|---|---|---|---|
| Cost per message | ~$0 (platform free) | ~$0.0001 | ~$0.006–$0.05 |
| Delivery latency | < 5 seconds | 5–30 seconds | 5–60 seconds |
| Reliability | High (if token valid) | Medium (spam filters) | Very high |
| Deliverability risk | Token expiry, uninstall | Spam, bounce, ISP block | Carrier filtering |
| User opt-out rate | Low (silent/badge modes) | Medium (unsubscribe links) | Low (sticky) |
| Best use case | App-engaged users | Rich content, receipts | OTPs, alerts, uninstalled users |

### 5.2 Kafka vs RabbitMQ for Notification Queue

| Dimension | Kafka | RabbitMQ |
|---|---|---|
| Message retention | Days to weeks; consumers replay | Until ACK; no replay |
| Throughput | 1M+ msg/sec per cluster | ~50K msg/sec per queue |
| Consumer model | Pull; multiple independent groups | Push; competing consumers |
| Priority queues | Separate topics per priority | Native priority queues (0–255) |
| Operational complexity | Higher (ZooKeeper / KRaft) | Lower |
| Best fit | Campaign-scale bursts, analytics | Low-volume, strict FIFO, direct ACK |

For a 10M/day notification system, Kafka wins on throughput and replay capability (replaying failed deliveries during an incident without data loss). RabbitMQ's native priority queue is appealing for small systems but saturates under campaign load.

### 5.3 At-Least-Once vs Exactly-Once Delivery

Kafka guarantees at-least-once delivery by default: a message is retried until the consumer successfully commits its offset. Exactly-once semantics (Kafka transactions + idempotent producers) add latency and operational complexity.

The right model depends on message type:

- **OTPs / security alerts** — exactly-once is critical; a duplicate "suspicious login" alert causes panic. Implement with deduplication on the consumer side (idempotent delivery via dedup_key), not Kafka transactions.
- **Marketing emails** — at-least-once with dedup is acceptable and far simpler.
- **SMS** — at-least-once with strong consumer dedup; duplicate SMS is the most disruptive failure mode.

In practice, at-least-once + application-level deduplication (as shown in the code) achieves exactly-once user experience without the overhead of Kafka transactions.

### 5.4 Dedup Window Size

A 24-hour dedup window handles the most common scenario (producer retries within minutes) while still allowing the same logical notification to be re-sent the following day (e.g., a daily digest). Longer windows (7 days) risk suppressing legitimate re-sends; shorter windows (1 hour) risk letting duplicates through on producer crashes with long restart cycles. The window should be tunable per template type.

---

## 6. Failure Modes

### 6.1 APNs Token Invalidation

When a user uninstalls the app, APNs marks the device token as invalid. On the next push attempt, APNs returns HTTP `410 Gone` with an `unregistered` reason. The push worker must immediately delete this token from the device token table and must not retry the delivery to that token.

Failure to clean stale tokens compounds over time: a 100M-user app with 10% annual churn accumulates 10M dead tokens per year. Each delivery attempt to a dead token wastes throughput and contributes to APNs rate-limit budget consumption. More seriously, if the same physical device gets a new device token assigned to a new user, continuing to target the old token is a privacy violation.

**Mitigation:** The push worker handles `410` responses inline during the send loop, queues a token-delete event to a dedicated Kafka topic, and a background worker purges tokens from MySQL asynchronously. The main send path is never blocked by the database write.

### 6.2 Kafka Consumer Lag During Marketing Campaigns

A flash sale targeting 10M users submits all 10M messages to `notifications.marketing` within minutes. If the email worker can send 500 emails/sec, processing 10M messages takes ~5.5 hours — meaning the last users receive the "24-hour flash sale" email 5 hours late.

**Mitigation:** (a) Horizontally scale the email worker fleet before the campaign (pre-warm). (b) Separate the campaign-blast topic from regular transactional email so the blast backlog does not delay password-reset emails. (c) Use Kafka consumer group metrics (consumer lag per partition) to trigger autoscaling — alert when lag exceeds 100K messages and spin up additional consumer pods via Kubernetes HPA.

### 6.3 Dedup Redis Unavailable

If the Redis cluster hosting dedup keys goes down, the API node cannot check whether a notification is a duplicate. The fallback policy is priority-dependent:

- **Critical notifications** — allow-send without dedup. A duplicate security alert is annoying; a missed security alert is dangerous.
- **Transactional notifications** — allow-send with logging; downstream dedup logic in the worker provides a second line of defense.
- **Marketing notifications** — hold (reject with a retriable error) until Redis recovers. The cost of a duplicate promotional email (user unsubscribes, spam complaint) is higher than a short delay.

Redis Sentinel or Redis Cluster provides automatic failover within ~10 seconds, limiting exposure. The API node should also implement a local in-memory dedup cache (bounded, 5-minute TTL) as a degraded fallback during the Redis failover window.

### 6.4 Email Bounce Storm

Sending bulk email to a list that contains many invalid addresses (old accounts, typos, purchased lists) triggers a cascade: recipients' mail servers reject the messages, generating hard bounces. ISPs track the bounce rate of the sending IP and domain. A bounce rate above 2% results in the sender domain being blocklisted, causing all future emails — including transactional ones — to be rejected as spam.

**Mitigation:** (a) Maintain a suppression list: any address that bounces twice is permanently suppressed before retry. (b) Warm new IP addresses gradually — start with 1,000 emails/day and double weekly until reaching full volume; ISPs reward new senders that establish a good reputation before bulk sending. (c) Monitor bounce rate in real time via the email provider's webhook (SendGrid Event Webhook); trigger an automatic circuit breaker that pauses sends if the bounce rate crosses 1.5%.

---

## 7. Java vs Rust Callout

**Error signaling:** Rust's `Result<(), String>` type makes it impossible to ignore dispatch failures — callers must pattern-match or propagate the error. Java's `String dispatch(...)` returning `null` on success is a convention-based contract: callers who fail to null-check the return value silently discard errors. Rust's type system enforces correctness at compile time; Java relies on code review and documentation.

**Enum ordering:** Rust's `derive(Ord)` assigns ordering by the variant's declaration position in the source file. Since `Marketing = 0, Transactional = 1, Critical = 2` are declared in ascending order, `Priority::Critical > Priority::Marketing` holds without any custom comparator. In Java, `enum` values do not implement `Comparable<Priority>` — `Priority.CRITICAL.ordinal()` returns the declaration index, so ordinal-based comparison works but requires explicit `.ordinal()` calls. For type-safe comparison in Java, a `Comparator<Priority>` or a custom `rank()` method is the idiomatic approach.

**Duration representation:** Rust's `std::time::Duration` is a first-class struct with sub-nanosecond precision, constructed via `Duration::from_secs()`, `from_millis()`, etc. Java's `java.time.Duration` is equivalent in expressiveness — but `java.time` is outside `java.util.*`. This chapter's Java code avoids the import constraint by storing the TTL as a raw `long` in nanoseconds, which is the approach taken in many high-performance Java caching libraries where the boxing overhead of `Duration` objects is undesirable.

**HashMap boxing overhead:** Rust's `HashMap<u64, u32>` stores keys and values as plain 8-byte and 4-byte integers on the heap allocation for the table — no boxing. Java's `HashMap<Long, Integer>` boxes each `Long` key to a 16-byte heap object and each `Integer` value to a 16-byte heap object, multiplying memory usage by roughly 4–6× compared to primitive storage. For a counter map with 500M users, this difference is ~8 GB (Rust primitives) vs ~48 GB (Java boxed). Production Java code uses `it.unimi.dsi.fastutil.longs.Long2IntOpenHashMap` or similar primitive-specialized collections to recover this overhead.

**Ownership and mutability:** `dispatcher.dispatch(&notif)` borrows the notification immutably while mutably borrowing the dispatcher — the borrow checker verifies no aliasing at compile time. In Java, concurrent callers could race on the shared `HashMap` — the class is not thread-safe and would require `ConcurrentHashMap` or external synchronization in a real multi-threaded API node.
