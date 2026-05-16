# Chapter 13: Video Streaming (YouTube / Netflix)

> **Chapter goal:** Design a video streaming platform — upload pipeline (transcoding), CDN distribution, adaptive bitrate streaming (HLS/DASH), and recommendation feed — handling 500 hours of video uploaded per minute.
> Code snippets compile: Rust 1.85+ (`rustc --edition 2024`), Java 17+ (`javac --release 17`).

---

## 1. Requirements & Constraints

### 1.1 Functional Requirements

A video streaming platform must handle two fundamentally different workloads: an ingest pipeline that accepts uploaded videos and transforms them into streamable formats, and a delivery system that serves billions of views with minimal buffering. The system must satisfy:

- **Video upload** — accept raw video files from creators. Issue upload confirmation within 5 seconds (before transcoding completes). Support large files (multi-GB) via chunked upload.
- **Transcoding** — convert raw video to multiple resolutions (360p, 720p, 1080p, 4K) and multiple codecs (H.264, H.265/HEVC) asynchronously after upload. HLS and DASH segmentation for adaptive streaming.
- **Adaptive bitrate streaming** — serve video segments to players that dynamically adjust quality based on measured network bandwidth, targeting < 2 seconds time-to-first-frame.
- **Search** — full-text search over video titles, descriptions, and tags. Results ranked by relevance and recency.
- **Recommendation feed** — personalized feed of recommended videos based on watch history, likes, and user similarity. Updated within minutes of new viewing activity.
- **View counting** — track view counts per video. Near-real-time updates acceptable (eventual consistency within 30 seconds).

### 1.2 Non-Functional Requirements

| Requirement | Target |
|---|---|
| Upload confirmation latency | < 5 seconds (raw upload, not transcoding) |
| Time to first frame (TTFF) | < 2 seconds |
| Streaming availability | 99.9% (< 8.7 hours/year) |
| Upload ingress rate | 500 hours of video per minute |
| Daily views | 1 billion |
| Storage | ~9 TB of new video per day (all resolutions) |
| CDN delivery | ~90 PB/day outbound bandwidth |

### 1.3 Scale Estimates

**Upload ingress:**

```
500 hours/min = 8.3 hours/sec of raw video
At 1 GB/hr (standard 1080p): 8.3 GB/sec raw ingress
```

**Storage (per day, new video):**

```
500 hrs/min × 60 min = 30,000 hrs/day of new video
Transcoded to 5 formats (360p, 720p, 1080p, 4K, audio-only)
Average across formats: ~500 MB/hr per format
30,000 hrs × 5 formats × 500 MB = 75 TB/day

Practical estimate (heavy compression, avg video ~1 GB/hr raw → 200 MB/hr per format):
30,000 hrs × 5 formats × 200 MB ≈ 30 TB/day
```

**CDN bandwidth:**

```
1B daily views × 3 min avg watch time × 500 KB/sec (720p average bitrate)
= 1B × 180 sec × 500,000 bytes
= 90,000 TB = 90 PB/day outbound
= 90 PB / 86,400 sec ≈ 1 TB/sec sustained CDN throughput
```

**Transcoding workers:**

```
1 min of 1080p video → ~10 min of GPU transcoding time
8.3 hrs/sec raw = 498 hrs/min = 29,880 minutes/min of video
At 10:1 transcoding ratio: need 298,800 minutes of compute per minute
= ~4,980 parallel workers each processing 1 min of video/min
```

This explains why YouTube and Netflix use cloud GPU clusters (AWS Elemental, Azure Media Services) with auto-scaling rather than fixed on-premise capacity.

---

## 2. High-Level Architecture

```
                    ┌──────────────────────────────────────────────────────────┐
                    │                   UPLOAD PIPELINE                        │
                    │                                                          │
   Creator ─────►  Upload Service  ────►  Raw S3 Bucket                       │
                    │  (chunked,           │                                   │
                    │   pre-signed URL)    │ S3 Event / Kafka: "video.uploaded"│
                    │                      ▼                                   │
                    │               Transcoding Queue (Kafka)                  │
                    │                      │                                   │
                    │         ┌────────────┼────────────┐                     │
                    │         ▼            ▼            ▼                     │
                    │    Worker 1     Worker 2     Worker N  (GPU auto-scale)  │
                    │         │            │            │                     │
                    │         └────────────┴────────────┘                     │
                    │                      │                                   │
                    │              Multi-format S3                             │
                    │        (video-id/360p/, 720p/, 1080p/, ...)              │
                    └──────────────────────┬───────────────────────────────────┘
                                           │
                    ┌──────────────────────▼───────────────────────────────────┐
                    │                  DELIVERY PIPELINE                       │
                    │                                                          │
                    │  Multi-format S3 ─► CDN Origin (Origin Shield)          │
                    │                            │                             │
                    │                    CDN Edge Nodes (200+ PoPs)            │
                    │                            │                             │
                    │                     Player (HLS/DASH)                   │
                    │                     1. Fetch master .m3u8               │
                    │                     2. Select quality variant            │
                    │                     3. Fetch segments (.ts / .fmp4)     │
                    │                     4. Adjust quality per bandwidth      │
                    └──────────────────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────────────────┐
                    │                   METADATA & DISCOVERY                   │
                    │                                                          │
                    │  Video metadata → MySQL (title, owner, status, counts)  │
                    │  Search index  → Elasticsearch (full-text, tags)        │
                    │  View events   → Kafka → ML Pipeline → Redis (feed)     │
                    └──────────────────────────────────────────────────────────┘
```

**Data flow summary:**

1. Creator uploads raw video via the Upload Service (chunked, pre-signed S3 URL for direct upload to S3). Upload Service writes metadata to MySQL and publishes a Kafka event.
2. A Transcoding Worker picks up the Kafka event, reads the raw video from S3, transcodes to all target resolutions and codec profiles, writes segments and HLS/DASH manifests to the multi-format S3 bucket, and updates the video status in MySQL to "ready."
3. On first playback, the CDN edge node fetches the master playlist and requested segments from the CDN origin (which proxies to S3 on cache miss). Subsequent requests are served from CDN edge cache.
4. The player fetches the master playlist, selects a quality variant based on its bandwidth estimate, and fetches individual segments in a loop. Each downloaded segment contributes a new bandwidth measurement, which the ABR controller uses to select the next segment's quality.

---

## 3. Component Deep-Dive

### 3.1 Video Upload Pipeline

Uploading large video files (multi-GB) over an unreliable network requires chunked upload with resumability. Two protocols are common: **TUS** (an open protocol for resumable uploads) and **S3 Multipart Upload**. Both divide the file into chunks (5–100 MB each), upload each chunk independently, and assemble them on the server side. If a connection drops after uploading 80% of the file, the upload resumes from the last committed chunk rather than starting over.

**Direct-to-S3 upload via pre-signed URLs** is the preferred architecture at scale. The Upload Service issues a pre-signed S3 URL (signed with short-lived credentials, valid for 1–12 hours) and returns it to the client. The client uploads directly to S3, bypassing the application servers entirely. This eliminates application-server bandwidth costs and removes the Upload Service from the critical path of the data transfer — it only handles metadata and event publication.

**Upload confirmation is issued after the raw upload completes, not after transcoding.** Transcoding is asynchronous and may take minutes for long videos. Creators receive immediate confirmation that their file was received; the video appears in their channel (with a "processing" status) within seconds. The UI displays a progress indicator as transcoding workers complete each resolution tier.

The Kafka event published after upload contains the video ID, S3 raw object key, creator ID, and upload timestamp. Transcoding workers consume this topic (consumer group `transcoder-workers`) with parallelism equal to the number of Kafka partitions. Each partition is processed by exactly one worker at a time, providing ordered, exactly-once delivery per video.

### 3.2 Transcoding

Transcoding converts raw video (typically H.264 or H.265 input from consumer devices) into multiple output profiles optimized for different network conditions and screen sizes. Each output profile is a combination of resolution, bitrate, and codec:

| Profile | Resolution | Target Bitrate | Codec |
|---|---|---|---|
| 360p | 640×360 | 500 Kbps | H.264 |
| 720p | 1280×720 | 2,500 Kbps | H.264 |
| 1080p | 1920×1080 | 5,000 Kbps | H.264 / H.265 |
| 4K | 3840×2160 | 15,000 Kbps | H.265 / VP9 |
| Audio only | — | 128 Kbps | AAC |

Each profile is segmented into fixed-duration chunks (6–10 seconds per segment). A 60-minute video at 6-second segments produces 600 segments per profile, or 3,000 segment files for 5 profiles.

Transcoding is CPU-intensive. One minute of 1080p video requires roughly 10 minutes of CPU/GPU time. Transcoding workers are deployed as stateless containers that auto-scale based on Kafka consumer lag — if the queue depth grows, the orchestrator (Kubernetes HPA or AWS Auto Scaling) spins up additional workers. Workers are spot/preemptible instances to reduce cost; job re-enqueue on worker failure ensures durability.

After transcoding, workers generate HLS manifests (a master `.m3u8` and a variant `.m3u8` per quality level) and upload all segments and manifests to the multi-format S3 bucket. The bucket policy sets `Cache-Control: max-age=31536000, immutable` on segment files (they never change) and a shorter TTL on manifests (which may be updated if segments are re-processed).

### 3.3 HLS (HTTP Live Streaming)

HLS is Apple's adaptive streaming protocol, now a de facto standard supported by all major browsers and mobile platforms. It uses plain HTTP for delivery, making it compatible with any CDN.

**Master playlist (`.m3u8`)** lists all available quality variants:

```
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360
https://cdn.example.com/video/abc123/360p/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
https://cdn.example.com/video/abc123/720p/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
https://cdn.example.com/video/abc123/1080p/index.m3u8
```

**Variant playlist** lists the segment files for a specific quality:

```
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
seg000.ts
#EXTINF:6.0,
seg001.ts
...
#EXT-X-ENDLIST
```

**Segments** are short `.ts` (MPEG-TS container) or `.fmp4` (fragmented MP4) files containing encoded video and audio. Segment files are immutable — once uploaded, they never change. CDN cache TTL can be set to one year.

**Player behavior:** The player fetches the master playlist once, selects a variant based on its initial bandwidth estimate, and then enters a loop: fetch the variant playlist to find the next segment URL, download the segment, decode and render it, and measure download throughput to update its bandwidth estimate.

### 3.4 Adaptive Bitrate (ABR)

The ABR controller lives in the video player and makes real-time quality decisions based on measured network conditions. Its goal is to maximize quality without causing rebuffering (empty buffer = playback stall).

**Bandwidth estimation** uses a moving average of recent segment download throughputs. The denominator is the actual download time; the numerator is the segment file size in kilobits. The moving average window (typically 5–10 segments) smooths out transient fluctuations while responding to sustained changes.

**Quality selection** uses a conservative safety margin: the player selects the highest quality whose required bitrate is at or below 80% of the estimated available bandwidth. This 20% headroom absorbs measurement noise and prevents oscillation — repeatedly switching up then immediately back down as bandwidth fluctuates near a quality threshold.

**Buffer management** is the secondary constraint. The player maintains a playback buffer (typically 15–30 seconds ahead of the current playback position). If the buffer is healthy (> 15 seconds), the controller is free to upgrade quality. If the buffer is below a panic threshold (< 5 seconds), it forces the lowest quality regardless of measured bandwidth to fill the buffer as fast as possible.

**Initial quality selection:** The player starts at the lowest quality (360p) to ensure playback begins quickly. After the first few segments are buffered and bandwidth is estimated, it ramps up to the appropriate quality. Starting low and ramping up produces better user experience than starting high and then buffering.

**DASH vs HLS:** DASH (Dynamic Adaptive Streaming over HTTP) is the MPEG standard equivalent to HLS, used on Android and most non-Apple platforms. The manifest format is XML-based (`MPD` instead of `.m3u8`), but the delivery mechanism and ABR logic are identical. A production platform serves both formats from the same segment files using different manifests.

### 3.5 CDN Architecture

The CDN is the most important scaling component for video delivery. Without it, serving 90 PB/day from a central origin would require millions of dollars in egress bandwidth and would deliver unacceptable latency to distant users.

**Edge nodes (Points of Presence, PoPs)** are distributed across 200+ global locations. When a player requests a video segment, the request is routed to the nearest PoP via GeoDNS or Anycast. If the PoP has the segment cached, it is served immediately with no origin involvement. The cache hit rate for popular videos approaches 100% — once the first viewer triggers a cache fill, all subsequent viewers in the same PoP are served from cache.

**Cache TTL:** Segment files are immutable and can be cached for up to one year (`Cache-Control: max-age=31536000, immutable`). Master playlists and variant playlists are updated when new quality levels are added; their TTL is shorter (minutes to hours). The CDN differentiates based on URL pattern.

**Origin shield (mid-tier cache):** Between CDN edge nodes and the S3 origin sits an origin shield — a regional CDN layer that aggregates cache misses from many edge nodes into a single origin-facing request. Without an origin shield, a new viral video might generate 1,000 simultaneous cache-miss requests (one from each PoP) to S3. With an origin shield, all 1,000 misses from edge nodes collapse into one miss at the shield, which makes a single request to S3.

**Long-tail content:** The top 1% of videos (by view count) account for roughly 90% of bandwidth and can be aggressively pre-cached. The bottom 99% of videos (the "long tail") have very low view counts and may not be cached at edge nodes at all — they are served directly from origin. A smart CDN routing policy can send long-tail requests directly to the origin shield rather than the nearest edge PoP, saving the cost of filling edge caches with rarely-requested content.

**CDN pre-warming:** For scheduled high-traffic events (sports finals, movie premieres, software launches), the platform can pre-push content to edge caches before the event starts. This prevents the "thundering herd" of simultaneous cache-miss requests at event start time.

### 3.6 View Counting

Naive view counting — incrementing a database column on every view request — cannot sustain 10,000+ QPS on a single video without specialized infrastructure.

**In-memory aggregation:** Each API server maintains an in-memory counter per video ID (a `HashMap<video_id, count>`). Every view event increments the local counter. A background thread flushes all counters to a central store (Redis `INCRBY`) every 30 seconds and resets the local counters. This reduces the Redis write rate from 10,000 QPS to (number of API servers) / 30 seconds — orders of magnitude lower.

**Redis as the near-real-time store:** Redis `INCRBY` is atomic and sub-millisecond. It serves as the source of truth for live view counts displayed on the platform. The Redis counter for each video is seeded from the database on first access and updated by the periodic flush.

**Database as the durable store:** A separate batch job reads Redis counters every few minutes and updates the persistent database (MySQL or DynamoDB). The database count may lag by a few minutes but is durable and used for analytics, creator dashboards, and monetization.

**Fraud filtering:** Raw view events must be filtered for bots and repeated views. Common strategies include: deduplicate by (user_id, video_id) within a 24-hour window (using a Bloom filter to check if the view was already counted, since the Bloom filter's false-positive rate is acceptable for view counting); rate-limit views per IP; and apply ML-based fraud scoring to view events in the Kafka pipeline before they reach the counter.

### 3.7 Content Moderation

Uploaded videos must be screened for policy violations (explicit content, copyright infringement, hate speech) before being made publicly accessible.

**Automated screening** runs as a stage in the transcoding pipeline. After raw upload but before the video is marked "ready," it passes through:
- **Visual content classifier** — a CNN-based model detects explicit imagery (nudity, violence, disturbing content) per frame. Videos that exceed a confidence threshold are sent to human review.
- **Audio analysis** — speech-to-text transcription feeds a text classifier for hate speech and harmful content.
- **Copyright fingerprinting (Content ID)** — the video's audio and visual content is compared against a database of fingerprints from rights holders. Matches trigger either takedown or monetization (ad insertion for the rights holder).

**Manual review queue:** Videos flagged by automated classifiers, or reported by users after publication, enter a moderation queue. Human moderators review and take action (approve, remove, age-restrict). SLA for review is typically 24–48 hours for flagged-before-publish content, and faster for reported live content.

**Holding period:** New creator accounts may have their first videos held in a "pending review" state for 24 hours before publication, reducing the window for policy violations to reach viewers.

---

## 4. Key Algorithms & Data Structures

### 4.1 Rust Implementation

The Rust implementation models an Adaptive Bitrate (ABR) controller. `Quality` is an enum with an associated `required_bandwidth_kbps` method. The controller tracks a sliding window of bandwidth samples and selects the highest quality whose required bandwidth is at or below 80% of the measured average.

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
enum Quality { Q360p, Q720p, Q1080p, Q4K }

impl Quality {
    fn required_bandwidth_kbps(self) -> u32 {
        match self {
            Quality::Q360p  =>   500,
            Quality::Q720p  =>  2500,
            Quality::Q1080p =>  5000,
            Quality::Q4K    => 15000,
        }
    }

    fn name(self) -> &'static str {
        match self {
            Quality::Q360p  => "360p",
            Quality::Q720p  => "720p",
            Quality::Q1080p => "1080p",
            Quality::Q4K    => "4K",
        }
    }

    // All quality levels in descending order (best first).
    fn all_descending() -> [Quality; 4] {
        [Quality::Q4K, Quality::Q1080p, Quality::Q720p, Quality::Q360p]
    }
}

struct ABRController {
    current_quality: Quality,
    bandwidth_samples: Vec<u32>, // kbps measurements
    sample_window: usize,
}

impl ABRController {
    fn new() -> Self {
        ABRController {
            current_quality: Quality::Q360p,
            bandwidth_samples: Vec::new(),
            sample_window: 5,
        }
    }

    fn record_bandwidth(&mut self, kbps: u32) {
        self.bandwidth_samples.push(kbps);
        if self.bandwidth_samples.len() > self.sample_window {
            self.bandwidth_samples.remove(0);
        }
    }

    fn avg_bandwidth(&self) -> u32 {
        if self.bandwidth_samples.is_empty() { return 0; }
        let sum: u32 = self.bandwidth_samples.iter().sum();
        sum / self.bandwidth_samples.len() as u32
    }

    // Select highest quality where required_bw <= 80% of avg_bandwidth.
    fn select_quality(&mut self) -> Quality {
        let available = self.avg_bandwidth() * 80 / 100;
        for q in Quality::all_descending() {
            if q.required_bandwidth_kbps() <= available {
                self.current_quality = q;
                return q;
            }
        }
        // No quality fits → stay at lowest
        self.current_quality = Quality::Q360p;
        Quality::Q360p
    }
}

fn main() {
    // Test 1: mixed bandwidth samples
    // avg(400+600+800+3000+4000) = 8800/5 = 1760 kbps
    // 80% of 1760 = 1408 kbps
    // Q4K needs 15000 > 1408, Q1080p needs 5000 > 1408,
    // Q720p needs 2500 > 1408, Q360p needs 500 <= 1408 → select Q360p
    let mut abr = ABRController::new();
    for kbps in [400u32, 600, 800, 3000, 4000] {
        abr.record_bandwidth(kbps);
    }
    let q = abr.select_quality();
    assert_eq!(q, Quality::Q360p,
        "avg=1760, 80%=1408: only Q360p(500) fits; got {}", q.name());

    // Test 2: consistently high bandwidth
    // avg(6500 × 5) = 6500 kbps
    // 80% of 6500 = 5200 kbps
    // Q4K needs 15000 > 5200, Q1080p needs 5000 <= 5200 → select Q1080p
    let mut abr2 = ABRController::new();
    for _ in 0..5 {
        abr2.record_bandwidth(6500);
    }
    let q2 = abr2.select_quality();
    assert_eq!(q2, Quality::Q1080p,
        "avg=6500, 80%=5200: Q1080p(5000) fits, Q4K(15000) does not; got {}", q2.name());

    // Test 3: all samples below lowest quality threshold
    // avg(100 × 5) = 100, 80% = 80 kbps; no quality fits → Q360p (fallback)
    let mut abr3 = ABRController::new();
    for _ in 0..5 {
        abr3.record_bandwidth(100);
    }
    let q3 = abr3.select_quality();
    assert_eq!(q3, Quality::Q360p, "very low bandwidth should fall back to Q360p");

    println!("All ABR controller tests PASSED");
}
```

**Key design notes:**

- `Quality::all_descending()` returns qualities from best to worst. `select_quality` iterates this array and returns the first quality whose required bandwidth fits within the available budget. Iterating best-first ensures the highest feasible quality is selected.
- Integer arithmetic `avg * 80 / 100` is used instead of floating point to avoid rounding surprises in assertion comparisons.
- `record_bandwidth` uses `Vec::remove(0)` to evict the oldest sample, which is O(N) but acceptable for a window size of 5. For larger windows, `VecDeque` with `pop_front` would be O(1).
- The fallback case (no quality fits) returns `Q360p` unconditionally, ensuring the player always has a quality selected even on very low bandwidth connections.

### 4.2 Java Implementation

The Java implementation mirrors the Rust one. `Quality` is a Java enum with a constructor field for `requiredBandwidthKbps`. `ArrayDeque<Integer>` implements the sliding window. `selectQuality` iterates quality values in descending order.

```java
import java.util.*;

public class VideoStreaming {

    enum Quality {
        Q4K(15000), Q1080P(5000), Q720P(2500), Q360P(500);

        final int requiredBandwidthKbps;
        Quality(int bw) { this.requiredBandwidthKbps = bw; }
    }

    static class ABRController {
        private Quality currentQuality = Quality.Q360P;
        private final Deque<Integer> samples = new ArrayDeque<>();
        private final int sampleWindow;

        ABRController(int sampleWindow) {
            this.sampleWindow = sampleWindow;
        }

        void recordBandwidth(int kbps) {
            samples.addLast(kbps);
            if (samples.size() > sampleWindow) {
                samples.removeFirst();
            }
        }

        int avgBandwidth() {
            if (samples.isEmpty()) return 0;
            int sum = 0;
            for (int s : samples) sum += s;
            return sum / samples.size();
        }

        // Select highest quality where required_bw <= 80% of avg_bandwidth.
        // Quality enum is declared best-first (Q4K, Q1080P, Q720P, Q360P).
        Quality selectQuality() {
            int available = avgBandwidth() * 80 / 100;
            for (Quality q : Quality.values()) {
                if (q.requiredBandwidthKbps <= available) {
                    currentQuality = q;
                    return q;
                }
            }
            currentQuality = Quality.Q360P;
            return Quality.Q360P;
        }
    }

    // Assertion helper (no assert keyword per book conventions)
    private static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError(msg);
    }

    public static void main(String[] args) {
        // Test 1: mixed bandwidth
        // avg(400+600+800+3000+4000)/5 = 1760; 80% = 1408
        // Q4K(15000)>1408, Q1080P(5000)>1408, Q720P(2500)>1408, Q360P(500)<=1408
        ABRController abr = new ABRController(5);
        for (int kbps : new int[]{400, 600, 800, 3000, 4000}) {
            abr.recordBandwidth(kbps);
        }
        Quality q = abr.selectQuality();
        check(q == Quality.Q360P,
            "avg=1760, 80%=1408: only Q360P fits; got " + q);

        // Test 2: high bandwidth
        // avg(6500×5)=6500; 80%=5200
        // Q4K(15000)>5200, Q1080P(5000)<=5200 → Q1080P
        ABRController abr2 = new ABRController(5);
        for (int i = 0; i < 5; i++) abr2.recordBandwidth(6500);
        Quality q2 = abr2.selectQuality();
        check(q2 == Quality.Q1080P,
            "avg=6500, 80%=5200: Q1080P fits, Q4K does not; got " + q2);

        // Test 3: very low bandwidth → fallback Q360P
        ABRController abr3 = new ABRController(5);
        for (int i = 0; i < 5; i++) abr3.recordBandwidth(100);
        Quality q3 = abr3.selectQuality();
        check(q3 == Quality.Q360P,
            "very low bandwidth should fall back to Q360P; got " + q3);

        System.out.println("All ABR controller tests PASSED");
    }
}
```

**Key design notes:**

- The `Quality` enum is declared in **descending** order (`Q4K, Q1080P, Q720P, Q360P`), so `Quality.values()` returns qualities best-first. `selectQuality` iterates this array and returns the first quality that fits — no sorting required.
- `ArrayDeque<Integer>` is used for the sliding window. `addLast`/`removeFirst` are O(1), making this more efficient than `ArrayList.remove(0)` for large windows.
- `avgBandwidth` uses `int sum` computed with a for-each loop. Java's `streams().mapToInt().average()` would also work but returns `OptionalDouble`, requiring unwrapping — the explicit loop is cleaner here.
- `samples.size()` is compared to `sampleWindow` using `>` rather than `>=`, which means the window holds exactly `sampleWindow` elements after the trim.

---

## 5. Tradeoffs

### 5.1 Streaming Protocol Comparison

| Protocol | Latency | DRM Support | Platform Support | CDN Cacheability | Use Cases |
|---|---|---|---|---|---|
| HLS | 6–30 sec (segment-based) | FairPlay (Apple) | All browsers, iOS, Android | Excellent (HTTP segments) | On-demand, live streams, Apple ecosystem |
| DASH | 6–30 sec (segment-based) | Widevine (Google), PlayReady | Android, browsers (not iOS natively) | Excellent (HTTP segments) | On-demand, premium content (Netflix, YouTube) |
| RTMP | < 1 sec | None (legacy) | Flash (deprecated), OBS ingest | Poor (streaming protocol) | Live ingest from OBS/streaming software to origin |
| WebRTC | < 100 ms | None | All browsers | None (peer-to-peer) | Live interactive streaming (Twitch low-latency, video calls) |
| LL-HLS / LL-DASH | 1–3 sec | Same as HLS/DASH | Growing | Good (partial segments) | Sports, live events, low-latency live streaming |

**Which to choose:** For on-demand video (Netflix, YouTube), DASH or HLS provides excellent CDN cacheability and broad DRM support. For ultra-low latency live streams (sports, gaming), LL-HLS or WebRTC is appropriate. RTMP remains the standard ingest protocol from streaming software to the origin (many encoders support only RTMP for push), even though the delivery format is HLS or DASH.

### 5.2 Transcoding: Cloud GPU vs On-Premise

**Cloud GPU transcoding (AWS Elemental, Azure Media Services, Google Transcoder API)** scales elastically with upload volume. There is no capital expenditure on GPU hardware; cost is purely variable (per-minute of transcoded video). Auto-scaling handles the 10× spike in uploads after a major event. Managed services handle codec updates, GPU driver maintenance, and hardware failures. The trade-off is cost: cloud GPU is expensive at scale (~$0.01–0.05 per minute of transcoded video), and vendor lock-in is high.

**On-premise GPU transcoding** has high capital expenditure (GPU servers cost $20K–$200K each) but lower marginal cost at sustained high volume. Large platforms (YouTube, Netflix) run their own transcoding infrastructure precisely because their volume is large enough that the break-even point with cloud GPU is reached quickly. On-premise also enables custom codec implementations and tighter integration with proprietary systems.

### 5.3 CDN Strategy: Single CDN vs Multi-CDN

**Single CDN** (e.g., Cloudflare only) is simpler to operate — one configuration, one contract, one set of metrics. Cache hit rates are higher because all traffic from a given PoP hits the same cache. The risk is a CDN provider outage: in 2021, a Fastly outage took down a significant fraction of the internet for ~1 hour.

**Multi-CDN** (Netflix Open Connect + commercial CDN; YouTube's global CDN + Akamai fallback) routes traffic across multiple providers based on performance measurements, cost, and availability. If one CDN's PoP is unhealthy, traffic shifts to another. The trade-off is complexity: different configurations, billing, and debugging across multiple CDNs, and lower cache hit rates per CDN (traffic is split, so each CDN's cache is less warm).

**Netflix Open Connect:** Netflix operates its own CDN appliances ("Open Connect Boxes") installed in ISP data centers. An ISP hosting a Netflix appliance receives popular titles pre-loaded onto local storage; user requests are served from the ISP's own network, bypassing CDN egress entirely. This dramatically reduces CDN costs for Netflix and improves quality for ISP customers. Other platforms (YouTube, Amazon) operate similar private CDN infrastructure at scale.

### 5.4 Storage Tiering

Video content follows a strong long-tail access pattern: newly uploaded and trending videos receive most views within the first 30–90 days; older content receives dramatically fewer requests. Storage tiering exploits this pattern:

| Tier | Storage Class | Cost | Access Time | Use Case |
|---|---|---|---|---|
| Hot | S3 Standard | High | Milliseconds | Videos < 90 days old, trending content |
| Warm | S3 Standard-IA | Medium | Milliseconds | Videos 90 days–2 years old |
| Cold | S3 Glacier Instant | Low | Milliseconds | Videos > 2 years, rarely accessed |
| Archive | S3 Glacier Deep Archive | Very low | Hours | Deleted videos retained for legal hold |

S3 Lifecycle Policies automate tier transitions: after 90 days, move to Standard-IA; after 2 years, move to Glacier Instant Retrieval. If a cold-tier video suddenly goes viral (reshared on social media), the CDN cache miss fetches it from Glacier Instant Retrieval (still milliseconds, just higher per-request cost) and warms the CDN cache.

---

## 6. Failure Modes & Mitigations

### 6.1 Transcoding Worker Failure

**Problem:** A transcoding worker picks a job from the Kafka queue, begins processing a 4-hour video, and crashes halfway through. The partially written output (incomplete segment files) is now in S3, and the job has been consumed from Kafka but not completed.

**Mitigation — At-least-once processing with idempotent writes:** Kafka consumer offset is committed only after the transcoding job is fully complete (all segments and manifests written to S3, database status updated). If the worker crashes mid-job, the offset is not committed; Kafka redelivers the job to another worker. The new worker may find partially written output in S3 — it overwrites it completely (idempotent). Segment files are written under deterministic key names (`video-id/720p/seg000.ts`), so reprocessing produces the same output at the same keys.

**Mitigation — Job timeout:** If a worker holds a Kafka message for longer than a configured timeout (e.g., 30 minutes for a short video), Kafka reassigns it to another worker (session timeout). This handles hung workers that don't crash cleanly.

### 6.2 CDN PoP Failure

**Problem:** A CDN PoP goes offline (hardware failure, network partition). Players in that geographic region cannot fetch video segments.

**Mitigation — Automatic BGP/GeoDNS rerouting:** When a PoP fails, the CDN's health monitoring withdraws its BGP announcement (Anycast) or removes it from GeoDNS responses. Player requests are automatically rerouted to the next nearest PoP. Rerouting happens within seconds for Anycast (BGP convergence) or up to the DNS TTL (60 seconds) for GeoDNS.

**Mitigation — Player buffer absorption:** The player maintains a 15–30 second buffer of pre-downloaded segments. During the brief rerouting window (seconds), the buffer continues playing without interruption. Users may notice a brief quality drop as the ABR controller conservatively selects lower quality from the new PoP until bandwidth is re-estimated.

**Mitigation — Multi-CDN failover:** If the outage is CDN-wide (not just one PoP), multi-CDN routing (see Section 5.3) redirects traffic to a secondary CDN provider within seconds.

### 6.3 Origin Overload During CDN Miss Storm

**Problem:** A video goes viral — a celebrity tweets a link, and 10 million viewers click within the same minute. CDN edge nodes in all 200 PoPs receive simultaneous cache misses (the video was not pre-cached). Each PoP generates a cache-miss request to the origin. 200 simultaneous requests for every segment of a 60-minute video at 5 formats = 200 × 600 × 5 = 600,000 requests to S3 in seconds.

**Mitigation — Origin shield collapse:** The origin shield (mid-tier cache) collapses the 200 edge-node misses into a single origin-facing request per segment. Without the origin shield, the S3 origin faces 200× the load; with it, the origin faces 1× the load for each unique segment. The shield fills from S3 and serves the remaining 199 edge-node misses from its own cache.

**Mitigation — CDN pre-warming:** For predictable traffic spikes (sports finals, product launches, scheduled premieres), the platform pre-pushes content to CDN edge caches before the event. Many CDN providers offer an "invalidation and pre-warm" API that pushes specified assets to specified PoPs.

**Mitigation — S3 request rate auto-scaling:** S3 automatically scales to handle high request rates, but it takes a few minutes to ramp up for a new key prefix. Distributing segments across multiple S3 key prefixes (sharding by video-id hash) ensures the load is spread across many S3 partitions from the start.

### 6.4 Slow Transcoding Queue (Upload Surge)

**Problem:** A major breaking news event causes a 10× spike in video uploads in the same time window. The transcoding Kafka queue backs up; new uploads are stuck in "processing" status for hours instead of minutes. Creators and news organizations are frustrated.

**Mitigation — Worker auto-scaling on queue lag:** Kubernetes HPA (Horizontal Pod Autoscaler) or AWS Auto Scaling monitors the Kafka consumer group lag (messages in queue minus messages processed). When lag exceeds a threshold (e.g., 1,000 pending jobs), new worker pods are launched. On cloud GPU spot instances, scaling from 50 to 500 workers can happen in under 5 minutes.

**Mitigation — Priority queue:** Transcoding jobs are published to multiple Kafka topics: `transcode-high` (verified news organizations, paid creators, short clips < 5 minutes) and `transcode-standard` (all other uploads). Workers are allocated proportionally: 70% consume from `transcode-high`, 30% from `transcode-standard`. During a surge, high-priority creators' videos are processed first.

**Mitigation — Progressive availability:** The transcoding pipeline publishes video availability incrementally. As soon as the 360p transcode is complete (fastest), the video is marked viewable at 360p. 720p and 1080p become available as those transcodes complete. Creators and viewers can watch the video before full processing is finished.

---

## 7. Java vs Rust: Language Comparison

This chapter illustrates several language-level differences in implementing the ABR controller.

**Rust `enum` with `impl` vs Java `enum` with constructor fields**

Rust enums are algebraic data types that can carry data and implement methods. `impl Quality { fn required_bandwidth_kbps(self) -> u32 { match self { ... } } }` is idiomatic: the method is associated with the type, and `match` must cover every variant (exhaustiveness is enforced at compile time). Adding a new quality level without updating the `match` arm is a compile error.

Java enums are classes with a fixed set of instances. The constructor field approach (`Quality(int bw) { this.requiredBandwidthKbps = bw; }`) stores data directly in the enum constant, avoiding a separate method body. Java 17 `switch` expressions are exhaustive for sealed interfaces and enums, but only when the switch covers all cases without a `default`; adding a `default` arm suppresses exhaustiveness checking. Both approaches are safe; the Rust version is marginally harder to extend incorrectly.

**`ArrayDeque<Integer>` vs `VecDeque<u32>`**

Both data structures are double-ended queues backed by a ring buffer, supporting O(1) push and pop from either end. The key difference is boxing: `ArrayDeque<Integer>` stores boxed `Integer` objects (heap-allocated), while `VecDeque<u32>` stores `u32` values inline in the ring buffer (no heap allocation per element). For a window of 5 samples this is irrelevant, but at 10,000 samples/sec across millions of concurrent streams, Java's boxing overhead is measurable. Java's `ArrayDeque<int[]>` workaround (using a primitive array of size 1) is ugly; for performance-critical Java, `int[]` with manual head/tail pointers is preferred.

**Match exhaustiveness vs switch expressions**

Rust's `match` is exhaustive by default — every possible enum variant must be handled. The compiler catches missing cases. Java's `switch` expressions (Java 14+) are exhaustive for enums when all constants are listed without a `default` arm. In the Java implementation, `Quality.values()` iterates all enum constants, so the for-each loop implicitly covers all cases. However, this is not checked by the compiler the same way Rust `match` is — a developer could add a new `Quality` constant and forget to verify that `selectQuality` still behaves correctly.

**`Integer` boxing vs `u32` primitives**

Java generics (`Deque<Integer>`, `Optional<Integer>`) cannot use primitive types — all generic type parameters must be reference types. Every `int` entering a `Deque<Integer>` is auto-boxed to a heap-allocated `Integer` object; every element read from the deque is unboxed. Rust generics have no such restriction: `VecDeque<u32>` stores primitive `u32` values inline. For high-throughput code, Java's boxing overhead can be eliminated using specialized primitive collections (Eclipse Collections, FastUtil) at the cost of additional dependencies.

**Sliding window: `Vec::remove(0)` vs `ArrayDeque.removeFirst()`**

The Rust implementation uses `Vec::remove(0)` to evict the oldest sample, which is O(N) because it shifts all elements left. For a window of 5, this is negligible, but a note in the code points to `VecDeque` as the O(1) alternative. The Java implementation correctly uses `ArrayDeque.removeFirst()`, which is O(1) — the ring buffer's head pointer advances without moving data. This is an instance where the Java standard library provides a better default than the Rust implementation as written; idiomatic Rust would use `VecDeque<u32>` from the start.

---

*End of Chapter 13.*
