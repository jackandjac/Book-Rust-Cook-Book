# Chapter 8: News Feed (Twitter / Instagram)

> **Chapter goal:** Design a social media news feed with fan-out-on-write vs fan-out-on-read strategies, feed ranking (EdgeRank/engagement score), and cache management for 500M users.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A news feed is the central surface of any social platform. When a user opens Twitter, Instagram, or Facebook, they see a curated stream of posts from people they follow. Building that stream at scale is one of the canonical distributed systems problems, touching storage, caching, messaging queues, and machine-learning ranking simultaneously.

The system must provide the following functional capabilities:

- **Follow and unfollow** — a user can follow or unfollow another user in real time. The feed must reflect the change within a bounded window (30 seconds for unfollow visibility is acceptable).
- **Post content** — users publish posts (text, images, video references). A post is created once and never mutated, only soft-deleted.
- **View feed** — a user sees a ranked or chronological stream of recent posts from everyone they follow. The feed returns in a single page of 20–50 items; infinite scroll loads additional pages.
- **Like, comment, share** — engagement actions are recorded and influence future feed ranking. Counts are displayed on each post (eventual consistency is acceptable; a post that shows 999 likes when the true count is 1000 is tolerable).

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Feed load latency | < 200 ms p99 end-to-end |
| Write latency (post creation) | < 500 ms p99 to confirm to the user |
| Availability | 99.99% for feed read path |
| Consistency | Eventual for feed contents; eventual for like counts |
| Daily active users | 200 M out of 500 M total |
| Post throughput | 1 M posts / day = ~12 posts / sec sustained |
| Feed read throughput | 10 M requests / sec (peak) |
| Celebrity threshold | Users with > 1 M followers treated as celebrities |

The most important constraint is **latency asymmetry**: reads vastly outnumber writes (10 M reads/sec vs 12 writes/sec), so the system is optimized for fast reads at the cost of more complex write paths.

### 1.3 Scale Estimates

**Posts:**
```
1 M posts / day ÷ 86,400 sec = ~12 posts / sec
Peak: assume 3× average = ~36 posts / sec
Post size: 1 KB text + metadata → 1 GB / day → 365 GB / year
```

**Fan-out write amplification:**
```
Average user: 200 followers → 200 cache writes per post
Celebrity (Justin Bieber): 100 M followers → 100 M cache writes per post
At 12 posts/sec from celebrities: potentially 1.2 B cache writes/sec (must be avoided)
```

**Feed cache storage:**
```
500 M users × 500 post_ids per feed × 8 bytes per post_id = 2 TB
Use Redis cluster; 1 TB per shard with two shards covers it comfortably
```

**Follow graph:**
```
500 M users × 200 average follows = 100 B follow edges
Each edge: 8 bytes follower_id + 8 bytes followee_id = 16 bytes → 1.6 TB on disk
In MySQL: 100 B rows; partition by follower_id for fast fan-out lookup
```

**Infrastructure summary:**

The scale estimates reveal two critical design constraints. First, **read dominates write by 800,000×**: at 10 M reads/sec vs 12 writes/sec, every design decision must optimize the read path even at significant cost to write complexity. Second, **write amplification is the central problem**: a naive push-to-all model fails catastrophically for celebrities while a naive pull-everything model fails for high-follow-count readers. All subsequent design decisions flow from these two observations.

Bandwidth estimate for the feed read path:
```
10 M feed reads/sec × 20 post IDs returned × 8 bytes/ID = 1.6 GB/sec from Redis
Plus post metadata fetches: 10 M reads/sec × 20 posts × 1 KB = 200 GB/sec from Post DB
CDN absorbs ~80% of metadata reads (posts are immutable and cacheable)
Effective Post DB load: 200 GB/sec × 0.20 = 40 GB/sec → requires ~40 database shards at 1 GB/sec each
```

---

## 2. High-Level Architecture

```
                          POST PATH
  User ──► Post Service ──► Kafka (post-events topic)
                                │
                         Fan-out Service
                        ┌───────┴────────┐
                   (regular user)   (celebrity)
                        │                │
              Redis Feed Cache     Timeline DB only
              feed:{user_id}       (pull at read time)
              LPUSH post_id
              LTRIM 0 499


                          READ PATH

  User ──► Feed Service
               │
       ┌───────┴──────────────────────┐
  Feed Cache (Redis)          Ranking Service
  feed:{user_id} → 500 ids       │
  + celebrity pull (on-the-fly)  │ ML score: affinity × weight × time_decay
       └──────────────────────────┘
               │
          Sorted top-20 posts returned to user


                      FOLLOW GRAPH SERVICE

  follow/unfollow ──► MySQL follows table
                  ──► Redis followers:{user_id} set (invalidated on change)


                        OFFLINE RANKING SIGNALS

  Kafka (engagement events) ──► Flink aggregator ──► User affinity scores (Redis)
```

The key insight is the **split between write and read paths**. On the write side, Kafka decouples the Post Service from the Fan-out Service so that a single post creation never blocks the API response. On the read side, the Feed Service is optimized to serve from Redis cache alone in the common case, performing a database query only on a cache miss.

The architecture has four asynchronous data flows running in parallel, each on its own Kafka topic:

- **post-events** — drives fan-out and Timeline DB writes
- **engagement-events** — drives affinity score updates in Redis and like/comment counts in Cassandra
- **follow-events** — drives follow graph updates in MySQL and Redis Set invalidation
- **notification-requests** — drives push notifications to APNs/FCM

Isolating these flows onto separate Kafka topics prevents a spike in one domain (e.g., an engagement event flood after a viral post) from starving another domain (e.g., new post fan-out). Each topic has independent consumer groups, partition counts, and retention policies sized for its specific workload.

---

## 3. Component Deep-Dive

### 3.1 Fan-out-on-Write (Push Model)

When a user publishes a post, the Post Service emits a message to Kafka. A pool of Fan-out Service workers consume those events and, for each post, look up the author's follower list from the Follow Graph Service. They then write the new `post_id` to the front of every follower's feed cache using Redis `LPUSH`, and trim the list to the last 500 entries with `LTRIM`.

The push model makes feed reads O(1): a user's feed is simply reading their Redis list. The tradeoff is write amplification. For an average user with 200 followers, one post creates 200 Redis writes — a manageable cost at 12 posts/sec (2400 writes/sec). For a celebrity with 100 M followers, one post would require 100 M Redis writes, easily overwhelming the system.

The push model also introduces a temporal lag: the fan-out for a popular (but non-celebrity) post with 100,000 followers takes a few seconds to propagate through the Kafka consumer pool. This is acceptable given the eventual consistency requirement.

A common optimization for the push model is **conditional push**: the Fan-out Service skips writing to the Redis feed of a follower who has not been active in the past 7 days. An inactive follower's feed is rebuilt from Cassandra on their next login anyway (cache miss path), so the push write is wasted. Conditional push reduces the total fan-out write rate by approximately 30–40% (the fraction of followers who are inactive at any given time), significantly reducing Redis write pressure without affecting the experience of active users. Inactive status is determined by checking a separate Redis set `active_users` (a bloom filter or exact set updated on each app open) before the push write.

### 3.2 Fan-out-on-Read (Pull Model)

In the pull model, no writes happen to follower caches when a user posts. Instead, when User A requests their feed, the Feed Service fetches the recent post IDs from every person A follows — potentially 1,000 followees — and merges them at read time.

The pull model eliminates write amplification entirely: a celebrity post creates exactly one write (to the author's own timeline). The cost is read amplification: each feed load requires O(followees) concurrent fetches and a merge operation. For a user following 1,000 accounts, this is 1,000 small Redis or database reads per feed load. At 10 M reads/sec, this would create 10 B backend lookups/sec — completely infeasible.

The pull model is therefore used only for celebrity accounts where write amplification would be worse than read amplification. Even so, "pull" for celebrities does not mean "slow": a celebrity's recent post list is cached in Redis, not fetched from disk, making the pull latency comparable to a cache read.

An important subtlety is that "pull at read time" does not mean making database calls at read time. Even for celebrity accounts, the celebrity's own timeline is cached in Redis as a Sorted Set keyed by `timeline:{celebrity_id}` with post timestamp as the score. The Feed Service performs `ZREVRANGE timeline:{celebrity_id} 0 99` — a single O(log N + 100) Redis call — to get the celebrity's last 100 posts. The pull is therefore from Redis, not from Cassandra or MySQL, and completes in < 5 ms per celebrity. The fan-out-on-read terminology refers to the fan-out computation being deferred to read time, not to the data source being a slow backing store.

### 3.3 Hybrid Strategy

The production approach, used by Facebook and Twitter, is a hybrid that combines both models based on follower count. Regular users (fewer than 1 M followers) use push: their posts are fanned out immediately to all followers' feed caches. Celebrity users (more than 1 M followers) use pull: their posts are written only to their own timeline, not fanned out.

At read time, the Feed Service performs two lookups in parallel:

1. Read the user's pre-built feed cache from Redis (contains pushed posts from regular followees).
2. For each celebrity the user follows, fetch the last N posts from that celebrity's timeline.

These two result sets are merged, deduplicated, scored, and the top 20 are returned. Because most users follow only a handful of celebrities, the incremental read cost of the celebrity pull is low — typically 3–10 additional lookups per feed load.

This hybrid strategy caps write amplification at ~1 M writes per celebrity post (impossible to push further) while keeping read amplification at a small constant for the celebrity portion.

One operational challenge of the hybrid model is the **celebrity threshold boundary**. An account that crosses the 1 M follower threshold triggers a mode switch: their future posts are no longer pushed to followers' caches. However, posts that were pushed before the threshold crossing remain in followers' caches. This creates a brief period of inconsistency where some followers see the author's old posts (from the pushed cache) interleaved with new posts (from the celebrity pull) in a non-obvious way. The system handles this by keeping a `last_pushed_post_id` timestamp per author; the Feed Service pulls celebrity posts with ID > `last_pushed_post_id` to avoid showing the same posts twice.

### 3.4 Feed Storage in Redis

Each user's feed is stored as a Redis List keyed by `feed:{user_id}`. The list holds `post_id` values as 64-bit integers serialized as strings. New posts are prepended with `LPUSH`, maintaining reverse-chronological order. `LTRIM 0 499` keeps the list at most 500 entries, preventing unbounded growth.

A Redis List is the right choice here because the access pattern is always sequential from the front: return the first 20 entries, then the next 20 on scroll. Sorted sets (`ZADD` with `score = timestamp`) would add ~40 bytes of overhead per entry for the score and are only needed if re-ranking by non-insertion-order criteria — an optimization left for later.

TTL is set to 30 days on each list. Inactive users whose feeds expire will experience a cache miss on next login. The Fan-out Service uses the `OBJECT ENCODING` command (or `EXISTS`) to avoid writing to expired feeds during fan-out — there is no point pushing to a feed that will be rebuilt from scratch anyway.

The Redis cluster is sized for the hot working set: at any moment, roughly 200 M daily active users have warm feeds. At 500 entries × 8 bytes = 4 KB per user, the total working set is 800 GB — roughly four 256-GB Redis shards.

Redis key distribution is important for cluster performance. With four shards, the key `feed:{user_id}` is distributed by the hash slot of `user_id` (CRC16 mod 16384, then mapped to a shard). In the common case, 25% of keys land on each shard, distributing read and write load evenly. A Redis Cluster (as opposed to a single replicated Redis instance) is required at this scale; Cluster mode supports automatic resharding and rolling shard additions without downtime, critical for handling user growth.

### 3.5 Feed Ranking

After the Feed Service retrieves the raw post list from cache and the celebrity pull results, it passes them to the Ranking Service for scoring. The ranking model is inspired by Facebook's EdgeRank and extends it with machine-learned signals.

The core scoring formula has three components:

- **Affinity (u_e)** — how often User A has interacted (likes, comments, profile views) with the post's author. High affinity boosts the post. Affinity scores are precomputed by a Flink streaming job reading engagement events from Kafka and stored as `affinity:{viewer_id}:{author_id}` in Redis.
- **Weight (w_e)** — the type of action the post has received: `likes × 0.6 + comments × 0.3 + shares × 0.1`. Shares are weighted lowest to avoid viral amplification of low-quality content.
- **Time decay (d_e)** — a denominator that grows with the age of the post. A post two hours old scores roughly half as high as a post one hour old. The formula `1.0 + age_hours` is simple and avoids the expensive exponential decay function.

The final score for a post is: `score = affinity × (0.6 × likes + 0.3 × comments) / (1.0 + age_hours)`. Posts are sorted descending by score and the top 20 are returned. This runs entirely in memory on the Feed Service host; no additional database round-trip is required beyond the Redis affinity lookups.

The affinity score between two users is updated incrementally by the Flink streaming job. When User A likes a post by Author B, the Flink job applies the update: `affinity[A][B] = affinity[A][B] × 0.99 + 0.01` (exponential moving average with a slow decay factor). This means that a single like from an otherwise disengaged user gives a small affinity bump, while consistent engagement over time builds a high affinity score that significantly boosts that author's posts. Daily, a batch job also applies a uniform decay of 0.95× to all affinity scores, ensuring that past engagement does not permanently dominate over recent behavior. Users who change their interests (stop engaging with a category of content) will see the affinity decay to near-zero over 2–4 weeks.

### 3.6 Follow Graph

The follow graph is the backbone of fan-out. Two representations are maintained in parallel:

**Redis** holds `followers:{user_id}` as a Set containing all follower user IDs. The Fan-out Service uses `SMEMBERS followers:{author_id}` to get the fan-out list for a regular user. For authors with fewer than ~50,000 followers, this is a single Redis call returning a few hundred kilobytes.

**MySQL** is the backing store with a `follows` table `(follower_id BIGINT, followee_id BIGINT, created_at TIMESTAMP)` partitioned by `follower_id`. It handles queries like "give me all accounts that User A follows" (used when rebuilding a cache miss feed). An index on `(followee_id, follower_id)` supports reverse lookups for fan-out.

On unfollow, the row is deleted from MySQL and the member is removed from the Redis Set. The Redis Set is the source of truth for fan-out; MySQL is for durability and bulk rebuilds. A short TTL (1 hour) on the Redis set ensures stale follow relationships from cache inconsistency heal automatically.

The follow graph is one of the few data structures where read performance is critical in both directions simultaneously. **Forward lookup** ("who does User A follow?") is needed during cache rebuild: the Feed Service follows all followees to fetch their recent posts. **Reverse lookup** ("who follows Author B?") is needed during fan-out: the Fan-out Service must write to every follower's feed cache. The MySQL table supports both with two indexes: the primary key on `(follower_id, followee_id)` for forward lookup and a secondary index on `(followee_id, follower_id)` for reverse lookup. For celebrities with 1 M+ followers, the reverse-lookup index scan returns 1 M+ rows — even reading these row IDs takes hundreds of milliseconds from MySQL. This is why celebrities bypass the Redis follower Set entirely and use the pull model: the fan-out list is never materialized for celebrities in the hot path.

### 3.7 Read Amplification at Scale

A user following 1,000 accounts, each of whom posted 5 times in the last hour, generates a merge of up to 5,000 post IDs at read time — even before the celebrity pull. The feed cache pre-aggregates this: the Redis list already contains the merged, pre-sorted stream, so the Feed Service reads one list rather than 1,000.

The amplification challenge re-emerges only at cache miss time. When a user's feed cache expires (after 30 days of inactivity), the system must rebuild it. The Feed Rebuilder service fetches the last 500 posts from each followee's timeline (from Cassandra, the backing Timeline DB), merges them, scores them, and writes the result into Redis. This is an expensive operation (up to 1,000 Cassandra reads) but happens at most once per inactive user per month.

To prevent a thundering herd of rebuild requests on Redis restart, the Feed Rebuilder uses a probabilistic early expiration strategy: caches are scheduled for rebuild slightly before expiry rather than exactly at expiry, spreading the load.

### 3.8 Post Storage and Media Service

The news feed returns references to posts, not the post content itself. A separate **Post Storage** service is responsible for storing and retrieving the actual post data — text, metadata, and links to media objects.

Post metadata (author ID, timestamp, like count, comment count, privacy setting) is stored in a relational database (MySQL or PostgreSQL) sharded by `post_id`. Because posts are immutable after creation, the schema is append-only and requires no complex transaction logic. Read performance is excellent: a batch read of 20 post IDs (one page of feed) is a single `SELECT ... WHERE id IN (...)` query that hits the primary key index on each shard, completing in under 5 ms.

Media objects (images, video thumbnails, short clips) are stored in object storage (S3 or equivalent). The Post Service stores only the object key in MySQL; the Feed Service returns the object key to the client, which constructs a CDN URL directly: `https://cdn.example.com/{object_key}?width=640`. Video transcoding and image resizing happen asynchronously: when a user uploads a photo, the Post Service stores the original in object storage and publishes a `media-processing` Kafka event. The transcoder produces multiple resolutions (thumbnail, medium, HD) within 5–30 seconds and updates the post metadata once complete. This async design ensures post creation returns to the user in under 500 ms even for large uploads, while media becomes visible at full quality shortly after.

Like counts and comment counts are stored in a separate **Engagement Store** — a Redis hash keyed by `post:{post_id}` with fields `likes` and `comments`. These fields are incremented atomically with `HINCRBY` on each like or comment event, making the counts eventually consistent with no single point of failure. The backing store for likes is a Cassandra table `(post_id, user_id, liked_at)` that supports "has this user liked this post?" queries in O(1). On cache eviction, likes and comments are recomputed from Cassandra and re-cached in Redis.

### 3.9 Notification and Push Delivery

Creating a post and populating the feed are write-path operations, but surfacing that content to users often requires a **push notification** — an alert that wakes the user's device when someone they follow posts new content or when one of their posts receives engagement.

Notifications flow through a separate pipeline to avoid coupling latency-sensitive fan-out with delivery to potentially offline devices. The Fan-out Service emits a `notification-request` event to a dedicated Kafka topic alongside the Redis feed update. A **Notification Service** consumes these events and decides whether to send a push notification based on user preferences (muted accounts, notification frequency caps), device reachability (whether the user has an active session), and notification fatigue heuristics (do not send the 50th like notification if the user has not opened the app in 3 days).

The Notification Service routes to the appropriate push delivery platform: APNs (Apple) or FCM (Firebase/Google). Both are third-party APIs with their own delivery guarantees and rate limits. To handle failures gracefully, notifications are persisted in a notification inbox table (MySQL, keyed by `user_id`) before dispatch. If a device is offline, the notification remains in the inbox; the next time the user opens the app, the client fetches pending inbox notifications via a REST API rather than relying on the push delivery having succeeded. This inbox-first design guarantees that no notification is permanently lost, even if the push delivery fails due to a device being offline, a network outage, or an APNs/FCM service disruption.

Notification throughput is substantial. At 500 M users with an average of 200 follows and 12 posts/sec globally, roughly 12 × 200 = 2,400 notification candidates are generated per second. After applying the notification preference filters and fatigue heuristics, perhaps 20% are actually sent: 480 push notifications per second. APNs and FCM both support batch delivery APIs that handle this volume easily; the per-notification cost is the MySQL inbox write (500 writes/sec) and the APNs/FCM HTTP call (500 requests/sec). Both are well within the capacity of a small Notification Service cluster (3–5 nodes).

---

## 4. Key Algorithms

The two snippets below implement the feed ranking algorithm described in Section 3.5. Both use the same EdgeRank-inspired scoring formula — `score = affinity × (0.6×likes + 0.3×comments) / (1.0 + age_hours)` — and return the top-K posts sorted by score descending. The key implementation challenge in Rust is that `f64` does not implement `Ord` (because of `NaN`), so `BinaryHeap<ScoredPost>` requires manually implementing all four comparison traits using `total_cmp`. The Java version avoids this entirely by sorting a mutable `ArrayList` with a `Comparator` that uses `Double.compare`, which provides a correct total order over all `double` values including `NaN` and infinity.

Both snippets use a fixed `now = 100_000` (seconds since an arbitrary epoch) and construct posts with timestamps relative to `now`, ensuring the test is deterministic and produces the same ranking on every run regardless of wall-clock time.

### 4.1 Rust: Feed Ranking

```rust
use std::collections::{BinaryHeap, HashMap};
use std::cmp::Ordering;

#[derive(Debug, Clone)]
struct Post {
    id: u64,
    author_id: u64,
    timestamp: u64,
    likes: u32,
    comments: u32,
}

#[derive(Debug, Clone)]
struct ScoredPost {
    score: f64,
    post: Post,
}

// f64 does not implement Eq or Ord; hand-roll using total_cmp.
impl PartialEq for ScoredPost {
    fn eq(&self, other: &Self) -> bool {
        self.score.total_cmp(&other.score) == Ordering::Equal
    }
}

impl Eq for ScoredPost {}

impl PartialOrd for ScoredPost {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for ScoredPost {
    fn cmp(&self, other: &Self) -> Ordering {
        self.score.total_cmp(&other.score)
    }
}

/// Score a single post.
/// score = affinity * (0.6*likes + 0.3*comments) / (1.0 + age_hours)
fn score_post(post: &Post, affinity: f64, now: u64) -> f64 {
    let age_hours = (now.saturating_sub(post.timestamp)) as f64 / 3600.0;
    let engagement = 0.6 * post.likes as f64 + 0.3 * post.comments as f64;
    affinity * engagement / (1.0 + age_hours)
}

/// Rank posts by score descending and return the top `k`.
fn rank_feed(
    posts: Vec<Post>,
    user_affinities: &HashMap<u64, f64>,
    now: u64,
    k: usize,
) -> Vec<Post> {
    let mut heap = BinaryHeap::new();
    for post in posts {
        let affinity = *user_affinities.get(&post.author_id).unwrap_or(&0.1);
        let score = score_post(&post, affinity, now);
        heap.push(ScoredPost { score, post });
    }
    heap.into_sorted_vec()
        .into_iter()
        .rev()
        .take(k)
        .map(|sp| sp.post)
        .collect()
}

fn main() {
    // Fixed "now" for determinism: 100_000 seconds epoch.
    let now: u64 = 100_000;

    let posts = vec![
        // Author 1: high affinity (0.9), very recent, medium likes
        Post { id: 1, author_id: 1, timestamp: now - 60,    likes: 50,  comments: 10 },
        // Author 2: low affinity (0.2), recent, very high likes
        Post { id: 2, author_id: 2, timestamp: now - 120,   likes: 500, comments: 200 },
        // Author 1: high affinity, older post
        Post { id: 3, author_id: 1, timestamp: now - 7200,  likes: 100, comments: 30 },
        // Author 3: medium affinity (0.5), very recent, low likes
        Post { id: 4, author_id: 3, timestamp: now - 30,    likes: 5,   comments: 2 },
        // Author 2: low affinity, old post
        Post { id: 5, author_id: 2, timestamp: now - 14400, likes: 800, comments: 100 },
    ];

    let mut affinities = HashMap::new();
    affinities.insert(1u64, 0.9_f64);
    affinities.insert(2u64, 0.2_f64);
    affinities.insert(3u64, 0.5_f64);

    let ranked = rank_feed(posts, &affinities, now, 3);

    // Verify we got 3 results.
    assert_eq!(ranked.len(), 3);

    // Post 2 (author 2, very high likes/comments, low affinity but huge engagement) vs
    // Post 1 (author 1, high affinity, recent, medium engagement).
    // score(post1) = 0.9 * (0.6*50 + 0.3*10) / (1 + 60/3600)
    //              = 0.9 * (30 + 3)     / 1.0167 ≈ 0.9 * 33 / 1.017 ≈ 29.2
    // score(post2) = 0.2 * (0.6*500 + 0.3*200) / (1 + 120/3600)
    //              = 0.2 * (300 + 60)  / 1.033 ≈ 0.2 * 360 / 1.033 ≈ 69.7
    // Post 2 ranks first despite lower affinity because engagement dominates.
    assert_eq!(ranked[0].id, 2);
    // Post 1 ranks second.
    assert_eq!(ranked[1].id, 1);

    println!("Feed ranking test passed.");
    for (i, p) in ranked.iter().enumerate() {
        println!("  Rank {}: post_id={} author={}", i + 1, p.id, p.author_id);
    }
}
```

### 4.2 Java: Feed Ranking

```java
import java.util.*;

public class NewsFeed {

    record Post(long id, long authorId, long timestamp, int likes, int comments) {}

    // Helper: replaces assert keyword (not allowed).
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError("FAIL: " + message);
    }

    /**
     * Score a post using the EdgeRank-inspired formula:
     *   score = affinity * (0.6*likes + 0.3*comments) / (1.0 + age_hours)
     */
    private static double scorePost(Post post, double affinity, long now) {
        double ageHours = Math.max(0, now - post.timestamp()) / 3600.0;
        double engagement = 0.6 * post.likes() + 0.3 * post.comments();
        return affinity * engagement / (1.0 + ageHours);
    }

    /**
     * Rank posts by score descending and return the top k.
     * Uses a sort with a custom Comparator — clearer than a min-heap for small K.
     */
    static List<Post> rankFeed(List<Post> posts,
                               Map<Long, Double> userAffinities,
                               long now,
                               int k) {
        List<Post> sorted = new ArrayList<>(posts);
        sorted.sort((a, b) -> {
            double scoreA = scorePost(a, userAffinities.getOrDefault(a.authorId(), 0.1), now);
            double scoreB = scorePost(b, userAffinities.getOrDefault(b.authorId(), 0.1), now);
            // Descending: higher score first.
            return Double.compare(scoreB, scoreA);
        });
        return sorted.subList(0, Math.min(k, sorted.size()));
    }

    public static void main(String[] args) {
        // Fixed "now" for determinism: 100_000 seconds epoch.
        long now = 100_000L;

        List<Post> posts = List.of(
            // Author 1: high affinity, very recent, medium engagement
            new Post(1L, 1L, now - 60,    50,  10),
            // Author 2: low affinity, recent, very high engagement
            new Post(2L, 2L, now - 120,   500, 200),
            // Author 1: high affinity, older post
            new Post(3L, 1L, now - 7200,  100, 30),
            // Author 3: medium affinity, very recent, low engagement
            new Post(4L, 3L, now - 30,    5,   2),
            // Author 2: low affinity, old post, very high raw engagement
            new Post(5L, 2L, now - 14400, 800, 100)
        );

        Map<Long, Double> affinities = new HashMap<>();
        affinities.put(1L, 0.9);
        affinities.put(2L, 0.2);
        affinities.put(3L, 0.5);

        List<Post> ranked = rankFeed(posts, affinities, now, 3);

        check(ranked.size() == 3, "Should return exactly 3 posts");
        // Post 2 has highest score: low affinity but dominant engagement.
        check(ranked.get(0).id() == 2L, "Post 2 should rank first");
        // Post 1 ranks second: high affinity, very recent, decent engagement.
        check(ranked.get(1).id() == 1L, "Post 1 should rank second");

        System.out.println("Feed ranking test passed.");
        for (int i = 0; i < ranked.size(); i++) {
            Post p = ranked.get(i);
            System.out.printf("  Rank %d: post_id=%d author=%d%n",
                              i + 1, p.id(), p.authorId());
        }
    }
}
```

---

## 5. Tradeoffs

Each major architectural decision in this system involves a tradeoff between write amplification, read amplification, consistency, and operational complexity. The following subsections analyze the most important choices and when to deviate from the recommended defaults.

### 5.1 Fan-out Strategy Comparison

| Dimension | Fan-out-on-Write (Push) | Fan-out-on-Read (Pull) | Hybrid |
|---|---|---|---|
| Write amplification | High — O(followers) writes per post | None — 1 write per post | Low — O(followers) only for regular users |
| Read amplification | None — O(1) feed read from cache | High — O(followees) reads per feed load | Low — O(1) for pushed posts + O(celebrities_followed) pull |
| Celebrity handling | Catastrophic — 100 M writes | Natural | Celebrity routed to pull automatically |
| Feed freshness | Near-real-time (seconds lag from Kafka) | Real-time | Near-real-time for regular; real-time for celebrity |
| Implementation complexity | Moderate | Low | High — merge logic, threshold routing |
| Best for | Platforms where users have moderate follower counts | Platforms with heavily skewed follower distributions | Large-scale social networks with both types |

The hybrid model is the right default for a 500 M user platform. Start with the push model during early growth (when no users are celebrities) and introduce the celebrity routing only when the first high-follower accounts begin to appear. The threshold at which celebrity routing becomes necessary is not fixed at 1 M followers — it depends on your fan-out write budget. A rough formula: `celebrity_threshold = redis_write_budget / (posts_per_sec × fraction_celebrity_posters)`. If your Redis cluster can sustain 200,000 writes/sec, you post at 12 posts/sec, and 0.001% of users are potential celebrities, then each celebrity post must generate no more than `200,000 / (12 × 0.00001 × total_users_in_millions)` writes — tune the threshold to stay within budget.

### 5.2 Redis List vs Sorted Set for Feed Storage

A Redis **List** (`LPUSH` / `LRANGE`) stores post IDs in insertion order. It is O(1) to prepend and O(N) to read a range, where N is the number of items returned. It does not support random access by time or score; to re-rank, the Feed Service must read all 500 IDs and sort them in memory.

A Redis **Sorted Set** (`ZADD score member` / `ZREVRANGE`) stores post IDs with a floating-point score (typically the post's Unix timestamp). This allows slicing by time range with `ZRANGEBYSCORE` and supports O(log N) ranked inserts. The cost is ~40 bytes of overhead per entry vs ~8 bytes for a list entry — roughly 5× the memory footprint for the same number of posts.

The List is preferred at this scale because re-ranking happens on a small working set (20 items out of 500) after the Feed Service has already fetched the data. The sorted set overhead of 5× memory (from 800 GB to 4 TB) is not justified when the list approach already supports the access pattern.

There is one scenario where the sorted set is worth the cost: if the feed must support features like "show only posts from the last 24 hours" or "show posts I haven't seen yet" (by tracking a high-water mark timestamp). In those cases, `ZRANGEBYSCORE feed:{user_id} (last_seen_ts +inf` is a single Redis call that returns exactly the right slice, whereas a List implementation would require reading the entire list and filtering client-side. Teams building advanced feed features (read receipts, time-filtered views) should budget for the sorted set's memory cost from the start rather than migrating later, when the data model change would require rebuilding all 500 M user feeds.

### 5.3 MySQL vs Cassandra for the Timeline (Backing Store)

The **Timeline DB** stores every post ever made by a user, used for cache rebuilds and long-tail history queries. Two options dominate:

**MySQL** is mature, supports strong consistency, and handles up to ~1 B rows per table on a well-sharded cluster. The schema is simple: `(user_id, post_id, created_at)` partitioned by `user_id`. Read for cache rebuild is a single range scan: `SELECT post_id FROM timeline WHERE user_id = ? ORDER BY created_at DESC LIMIT 500`. The challenge is write throughput at 12 posts/sec sustained with large fan-out.

**Cassandra** is optimized for write-heavy, wide-column workloads. The `timeline` table has `user_id` as the partition key and `post_id` as the clustering key sorted descending. A cache rebuild read retrieves the latest 500 posts with a single partition scan. Cassandra scales horizontally without sharding complexity and handles 100,000 writes/sec per cluster without performance degradation. The cost is eventual consistency (replication lag of ~100 ms) and a more complex operational model.

For a system at 500 M users where the Timeline DB is write-heavy (fan-out writes flood it during spikes), Cassandra is the better choice. The eventual consistency of Cassandra is acceptable because the Timeline DB is only consulted on cache miss — a rare cold path — and the feed is already eventually consistent by design.

Cassandra's data model for the timeline is particularly well-suited because the access pattern is almost exclusively "give me the N most recent posts from user X" — a single-partition range scan that Cassandra handles in a single round-trip regardless of how many total posts user X has created. Contrast this with MySQL, where a table of 100 B rows partitioned by `user_id` requires careful key design to avoid hot partitions (a user who posts 10,000 times has a very wide partition in MySQL's InnoDB, causing index leaf splits during writes). Cassandra's compaction strategy (TWCS — Time Window Compaction Strategy) is specifically designed for time-series append-only workloads, keeping older data in separate SSTables that are compacted independently, without interfering with hot recent data.

### 5.4 Chronological vs Ranked Feed

Chronological feeds are simple to implement (sorted by `created_at` descending), transparent to users ("I see everything, in order"), and have zero ML infrastructure cost. They were the original design of Twitter and Instagram.

Ranked feeds use an ML model to surface the posts most likely to drive engagement. They increase time-on-platform metrics significantly (Facebook reported a ~35% increase in engagement after switching). The cost is opacity (users cannot predict which posts they will see), higher infrastructure cost (Ranking Service, affinity store, model training pipeline), and potential filter-bubble effects.

Most production systems today offer ranked feeds by default with a user toggle to switch to chronological order. The architecture supports both: the Feed Service simply skips the Ranking Service call when chronological mode is selected for a user.

A hybrid approach that many platforms settle on is **candidate generation + re-ranking**: the Feed Service first fetches the 500 most recent posts from the user's follows (the chronological candidate pool) and then runs the ranking model over just those 500 candidates. This bounds the ranking model's input size to a manageable constant and preserves recency as a hard pre-filter — posts older than 7 days never enter the candidate pool, preventing the ranking model from resurfacing old viral content indefinitely. The result is a feed that feels "fresh and relevant" rather than either purely chronological or purely engagement-maximizing.

---

## 6. Failure Modes

News feed systems are resilient by design: the feed is eventually consistent, and users tolerate a few seconds of lag between a post being published and appearing in followers' feeds. This tolerance gives engineers significant latitude to degrade gracefully under failures. The following failure modes cover the most likely production incidents and their mitigations.

### 6.1 Fan-out Queue Backup

**Scenario:** A major celebrity (100 M followers) posts content at peak hours. Even with celebrity routing to the pull model, a misconfiguration or threshold bug causes the fan-out service to attempt pushing to all 100 M followers. Kafka consumers fall behind; the `post-events` topic accumulates millions of unprocessed messages. Users receive stale feeds hours after new posts.

**Detection:** Kafka consumer group lag metric exceeds 100,000 messages; fan-out service CPU and Redis write rate spike; feed freshness SLO (posts visible within 5 seconds) is breached.

**Mitigation:** The primary defense is correct celebrity routing at the Fan-out Service — any author with follower count > 1 M is routed to the pull model, verified on each event. A secondary defense is a Kafka dead-letter queue: fan-out tasks that fail after 3 retries are moved to a DLQ and a separate worker processes them at lower priority (ensuring eventual delivery without blocking the main queue). Kafka partitioning by `author_id % num_partitions` ensures that one author's storm does not block other authors' fan-out tasks.

**Capacity planning:** A well-designed system pre-calculates the maximum fan-out write rate. With 12 posts/sec from regular users (average 200 followers) and assuming 1% of users qualify as high-influence (up to 1 M followers), the maximum sustained fan-out write rate is `12 × 0.99 × 200 + 12 × 0.01 × 1,000,000 = ~122,400 writes/sec`. Redis can handle several million writes/sec on a moderately sized cluster, so the headroom is comfortable. The celebrity threshold of 1 M followers is chosen specifically to keep the maximum fan-out write rate under 150,000 writes/sec, which fits within a budget of 4 Redis shards with room to spare.

### 6.2 Feed Cache Miss Storm

**Scenario:** The Redis cluster undergoes a rolling restart after a firmware upgrade. All 200 M active user feed caches are lost simultaneously. When users open the app, every feed load is a cache miss, falling through to the Timeline DB (Cassandra). Cassandra receives 10 M queries/sec instead of its normal ~100 K/sec and is overwhelmed. Feed latency spikes from 200 ms to 10+ seconds.

**Detection:** Redis `keyspace_hits` drops to zero; Cassandra read latency p99 exceeds 5 s; Feed Service error rate rises above 1%.

**Mitigation:** Three layers of defense. First, the Feed Service applies a **circuit breaker** on Cassandra: after 5% error rate, the breaker opens and the Feed Service returns a stale feed from the last successful response cached locally for 60 seconds. Second, the Feed Rebuilder has a **rate limit** on simultaneous rebuild requests (e.g., 50,000 concurrent rebuilds), so the Cassandra load ramp is controlled. Third, the system maintains a **warm-up procedure** after Redis restart: the Feed Rebuilder service has a priority queue of recently active users and proactively rebuilds the most active 10 M feeds before they are requested, spreading the work over 30 minutes rather than facing it reactively.

### 6.3 Follow Graph Stale After Unfollow

**Scenario:** User A unfollows Celebrity B. MySQL is updated immediately. However, the Redis Set `followers:{celebrity_b}` still contains User A because the cache invalidation message was dropped due to a network partition. For the next hour (until TTL expiry), posts from Celebrity B continue to appear in User A's feed.

**Detection:** Reported by user ("I unfollowed them but still see their posts"). Metrics: compare MySQL follow counts with Redis set sizes for a sample of users; divergence > 2% triggers an alert.

**Mitigation:** On unfollow, the Follow Graph Service sends an invalidation event to a dedicated Kafka topic. The Fan-out Service consumes these events and immediately calls `SREM followers:{author_id} {follower_id}`. The TTL on the Redis Set provides a safety net: even if the invalidation message is lost, the Redis key expires in 1 hour and is rebuilt from MySQL on the next fan-out lookup. For the feed itself, the Feed Service can optionally filter the user's feed list against a lightweight bloom filter of "recently unfollowed author IDs" to avoid showing posts from just-unfollowed users before the cache heals.

### 6.4 Ranking Service Failure

**Scenario:** The Ranking Service's ML model server crashes due to an out-of-memory error triggered by an unusually large batch of feed ranking requests. Feed loads that were completing in 180 ms now hang waiting for the ranking response with a 2-second timeout.

**Detection:** Ranking Service error rate > 1%; Feed Service p99 latency exceeds 500 ms; on-call alert fires.

**Mitigation:** The Feed Service treats the Ranking Service as optional. Every feed load is wrapped in a try/catch with a 200 ms timeout. If the Ranking Service does not respond within the timeout, the Feed Service falls back to **chronological ordering** — returning the 500 pre-fetched post IDs sorted by `post_id` descending (a proxy for creation time, since IDs are time-ordered snowflake IDs). The degraded feed is still useful; users see recent posts, just not ranked. The fallback activates automatically with no manual intervention, and a metric `feed.ranking.fallback.rate` is emitted to track how often it is triggered.

**Model versioning and rollback:** The Ranking Service supports loading multiple model versions simultaneously and routing traffic by percentage (e.g., 95% to stable v12, 5% to experimental v13). If v13 produces OOM errors or degraded engagement metrics, the traffic split is adjusted to 0% v13 without restarting any process. Model artifact versioning is managed in object storage; the Ranking Service polls for new versions every 5 minutes and loads them into a staging slot before swapping. This blue-green model deploy strategy means that a bad model can be rolled back by reverting the pointer in the config store, with full effect within 5 minutes, rather than requiring a code deployment.

### 6.5 Like Count Consistency Bug

**Scenario:** A post receives 1,000 likes in rapid succession. The like counter in Redis (`HINCRBY post:{post_id} likes 1`) increments correctly in memory, but an async flush of like counts to MySQL fails silently due to a network partition. When Redis evicts the key (or restarts), the like count is rebuilt from MySQL — which shows 950 instead of 1,000. The 50 missing likes are permanently lost from the persistent store.

**Detection:** Periodic reconciliation job compares Redis like counts with MySQL like event counts for a sample of recent posts; divergence > 5 likes on any post with > 100 likes triggers an alert.

**Mitigation:** Likes are sourced from the append-only Cassandra likes table (`post_id, user_id, liked_at`) as the authoritative store, not from the MySQL counter. The Redis counter is a cache of a `SELECT COUNT(*) FROM likes WHERE post_id = ?` aggregate, rebuilt from Cassandra on cache miss. Duplicate like prevention is enforced by the Cassandra primary key `(post_id, user_id)` — attempting to insert a like from the same user twice results in an idempotent upsert rather than a duplicate row. This design makes the like count eventually consistent and bounded by the Cassandra replication lag (~100 ms), with no permanent data loss.

---

## 7. Java vs Rust: Language Comparison

This section analyzes the language-level tradeoffs that emerge when implementing news-feed components in Rust vs Java. The algorithms are identical; the differences are in type safety guarantees, memory layout, heap behavior, and the pitfalls unique to each language's standard library.

### `record` vs struct

Java's `record Post(long id, ...)` generates a canonical constructor, accessors, `equals`, `hashCode`, and `toString` via reflection-based deserialization at class-load time. At runtime, records behave as ordinary final classes; the reflection overhead is a one-time cost at class initialization, not per-instance. However, records are heap-allocated and carry Java object overhead (~16 bytes header + padding to 8-byte alignment), meaning a `Post` with five fields occupies roughly 56 bytes on the heap rather than the ~40 bytes of raw field data.

Rust's `struct Post { id: u64, ... }` is zero-cost: it has no header, no vtable, and is laid out exactly as its fields dictate (typically with alignment padding). A `Post` with the same five fields occupies 28 bytes in a contiguous array. More importantly, `Vec<Post>` stores posts in a single heap allocation with cache-friendly contiguous layout, while `ArrayList<Post>` in Java stores pointers to individually heap-allocated `Post` objects — a significant difference for sorting workloads where random memory access patterns dominate.

### `BinaryHeap` vs `PriorityQueue`

Rust's `std::collections::BinaryHeap` is a **max-heap** by default: the element with the greatest `Ord` value is at the top. To extract in descending order, push all elements and call `into_sorted_vec()` (which returns ascending) then reverse, or repeatedly `pop()`.

Java's `java.util.PriorityQueue` is a **min-heap** by default: the smallest element is at the front. To get a max-heap behavior for ranking, you must supply a reversed comparator: `new PriorityQueue<>(Comparator.comparingDouble(e -> -score))`. A common mistake is forgetting the negation, resulting in the worst posts being returned first. For the small K case in this chapter, a `List.sort` with a descending comparator is clearer and avoids the min/max-heap confusion entirely.

### `f64` NaN Ordering: `total_cmp` vs `Double.compare`

Standard `f64` comparison (`<`, `>`, `==`) in both languages is IEEE 754 partial order: `NaN != NaN` and `NaN` is unordered with respect to any other value. In Rust, because `f64` does not implement `Ord`, you cannot accidentally use it in a `BinaryHeap` without explicitly opting into a total order. The `total_cmp` method (stable since Rust 1.62) provides a deterministic total order where `-NaN < -Infinity < ... < +Infinity < +NaN`. This is the safe choice for sorting.

In Java, `Double.compare(a, b)` also implements total order consistent with `Double.compareTo`, placing `NaN` above positive infinity. However, using raw `double` in a `Comparator` with the `-` trick (`(a, b) -> (int)(scoreB - scoreA)`) is a notorious bug: floating-point subtraction can overflow to `-Infinity` or produce `NaN`, which `(int)` casts to `0` or `Integer.MIN_VALUE`, silently corrupting the sort order. Always use `Double.compare(scoreB, scoreA)` in Java comparators, as shown in the chapter snippet.

### Concurrent Feed Access

In a production Feed Service, multiple threads handle concurrent requests. In Java, `ArrayList<Post>` and `HashMap<Long, Double>` are not thread-safe; the feed ranking code in this chapter assumes per-request isolation (each request creates new objects). In a concurrent setting, the affinity map would be stored in a `ConcurrentHashMap<Long, Double>` accessed by reference from a thread-local or request-scoped context. The ranking result (`List<Post>`) is created fresh per request and never shared, so no synchronization is needed for the output.

In Rust, the borrow checker enforces this isolation at compile time. The `rank_feed` function takes `posts: Vec<Post>` by value (ownership transfer) and `user_affinities: &HashMap<u64, f64>` by shared reference. If `user_affinities` were wrapped in an `Arc<RwLock<HashMap<...>>>` for concurrent access, the caller would call `affinities.read().unwrap()` to get a `RwLockReadGuard` and pass that as the reference argument. The Rust type system prevents passing a `&HashMap` obtained from a `RwLockReadGuard` after the guard is dropped — a class of use-after-free bug that Java's concurrent collections handle at runtime (via `ConcurrentModificationException`) rather than at compile time.

### Snowflake IDs and Time-Ordered Post IDs

Both snippets use `u64` / `long` for `post_id`. In production social systems, post IDs are typically **Snowflake IDs** — 64-bit integers composed of: timestamp (41 bits, milliseconds since epoch), datacenter ID (5 bits), machine ID (5 bits), and sequence number (12 bits). Snowflake IDs are time-monotonic: a higher post ID always means a later post, so `ORDER BY post_id DESC` is equivalent to `ORDER BY created_at DESC` without a separate timestamp column.

In Rust, a `u64` Snowflake ID is stored with zero overhead — no boxing, no null pointer, no header. An array of 500 `u64` Snowflake IDs (one feed page) occupies exactly 4,000 bytes, fitting in 63 cache lines. In Java, a `long[]` array of 500 Snowflake IDs occupies the same 4,000 bytes for the data, plus 16 bytes of array header — nearly identical. Using `Long[]` (boxed) instead of `long[]` would balloon to 500 × 16 bytes (object headers) + 500 × 8 bytes (pointers) + 8 bytes (array header) = 12,008 bytes. This is the classic Java performance pitfall: always use primitive arrays (`long[]`, `int[]`) rather than boxed arrays (`Long[]`, `Integer[]`) for numeric data in hot paths.

Snowflake ID generation is a coordination problem: each machine ID must be unique within the cluster to avoid ID collisions. In practice, Snowflake ID generators are deployed as a small cluster of ID generation services (or as a library that registers machine IDs from ZooKeeper on startup). In Rust, the ID generator is typically a thread-local struct that pre-allocates a block of sequence numbers and issues IDs without any locking until the block is exhausted (at which point it acquires a new block). In Java, `AtomicLong` provides the sequence counter, and `ThreadLocal<SnowflakeGenerator>` avoids contention between threads. The two approaches are functionally equivalent; the Rust version benefits from the compiler's guarantee that the `ThreadLocal` data is not accidentally shared across threads without synchronization.

### Sorting Stability and Feed Determinism

The Rust snippet uses `heap.into_sorted_vec().into_iter().rev()` to extract posts in descending score order. For posts with equal scores (e.g., two posts that both score exactly 0.0 because their affinity is 0 and likes/comments are 0), `BinaryHeap`'s extraction order for ties is implementation-defined — there is no guarantee about which tied element pops first. This is acceptable for feed ranking because truly equal scores are rare in practice (scores are floating-point and rarely exactly equal), and ties among zero-engagement posts do not matter to users.

In Java, `List.sort` is stable: equal-scoring posts retain their original order in the input list, which in this chapter is the insertion order (post 1, post 2, ...). This provides deterministic output for testing purposes — the same input always produces the same ranking. For production use, where equal scores should ideally be broken by post ID (higher ID = more recent = preferred), both languages should add a secondary sort key: in Rust, `.then_by(|a, b| a.post.id.cmp(&b.post.id).reverse())` and in Java, `.thenComparingLong(p -> -p.id())`.

---

## Key Takeaways

- **Fan-out-on-write** is O(1) for reads but catastrophically expensive for celebrities. The hybrid model (push for regular users, pull for celebrities) is the production standard.
- **Feed ranking** uses EdgeRank: affinity × engagement weight / time decay. The formula runs in-memory on the Feed Service; only affinity lookups hit Redis.
- **Feed cache** is a Redis List per user, capped at 500 entries with LPUSH + LTRIM. TTL 30 days; inactive users' feeds are rebuilt from Cassandra on next login.
- **Follow graph** is maintained in Redis Sets (hot path) and MySQL (backing store). Celebrity fan-out bypasses the Redis Set entirely.
- **Notification pipeline** is decoupled from fan-out via a separate Kafka topic. An inbox table in MySQL ensures no notification is permanently lost.
- **Rust `f64` sorting** requires hand-rolling `Eq + Ord` with `total_cmp`. Java's `Double.compare` handles NaN correctly; never use `(int)(a - b)` in comparators.
- **Snowflake IDs** make `ORDER BY post_id DESC` equivalent to chronological order. Use `long[]` not `Long[]` in Java for numeric feed ID arrays.
- **Cassandra (TWCS)** is preferred over MySQL for the Timeline DB: it handles the write-heavy fan-out write load without hot-partition issues, and TWCS compaction is purpose-built for time-series append-only data.
- **Conditional push** (skip writing to inactive followers' feeds) reduces Redis write pressure by 30–40% with no user-visible impact. Inactive status is tracked in a Redis bloom filter updated on each app open.
- **Rust's borrow checker** prevents sharing affinity data across threads without explicit synchronization. Java's `ConcurrentHashMap` provides the runtime equivalent but requires the developer to reason about thread safety without compiler assistance.
- **Ranked vs chronological** is a product decision, not an infrastructure one. The architecture supports both by making the Ranking Service optional in the Feed Service's request pipeline.
