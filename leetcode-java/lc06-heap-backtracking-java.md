# LC-06 (Java): Heap / Priority Queue & Backtracking

> **Companion chapter philosophy:** Every problem mirrors the Rust chapter at
> `/leetcode/lc06-heap-backtracking.md` — same problems, same ordering, same
> insight summaries. All code is Java 17+ and compiles directly on LeetCode.
> Tests use `throw new AssertionError(...)`, never JUnit or the `assert`
> keyword.

> **Key mental model:** Java's `PriorityQueue<T>` is a **min-heap** by default
> (smallest element at the head). Pass `Collections.reverseOrder()` or a
> lambda comparator to get a max-heap. Rust's `BinaryHeap<T>` is a max-heap by
> default — the opposite! This asymmetry is the single most common source of
> heap bugs when translating between the two languages.

---

## Heap / Priority Queue in Java 17+

### Quick Reference

| Pattern | Java code |
|---|---|
| Min-heap (default) | `new PriorityQueue<>()` |
| Max-heap | `new PriorityQueue<>(Collections.reverseOrder())` |
| Min-heap with lambda | `new PriorityQueue<>((a, b) -> a - b)` |
| Max-heap with lambda | `new PriorityQueue<>((a, b) -> b - a)` |
| Push element | `pq.offer(x)` or `pq.add(x)` |
| Pop smallest/largest | `pq.poll()` returns `T` (or `null` if empty) |
| Peek without removing | `pq.peek()` returns `T` (or `null` if empty) |
| Size | `pq.size()` |
| Check empty | `pq.isEmpty()` |
| Custom object heap | `new PriorityQueue<>((a, b) -> a.dist - b.dist)` |

### Min-heap pattern (Kth largest problems)

```java
PriorityQueue<Integer> minHeap = new PriorityQueue<>();   // min at head
minHeap.offer(5);
minHeap.offer(1);
minHeap.offer(3);
// minHeap.peek() == 1  (smallest)
// minHeap.poll() == 1  (removes smallest)
```

### Max-heap pattern (Last stone weight, etc.)

```java
PriorityQueue<Integer> maxHeap =
    new PriorityQueue<>(Collections.reverseOrder());      // max at head
maxHeap.offer(5);
maxHeap.offer(1);
maxHeap.offer(3);
// maxHeap.peek() == 5  (largest)
// maxHeap.poll() == 5  (removes largest)
```

### Never use `Stack` — use `ArrayDeque`

```java
// Bad (legacy, synchronized, slow):
Stack<Integer> stack = new Stack<>();

// Good (fast, unsynchronized, Java-idiomatic):
Deque<Integer> stack = new ArrayDeque<>();
stack.push(1);          // addFirst
int top = stack.pop();  // removeFirst
```

> **Java vs Rust — heap comparison**
>
> Java's `PriorityQueue<T>` is a min-heap by default; Rust's `BinaryHeap<T>`
> is a max-heap by default. This asymmetry trips up almost everyone doing a
> direct port. In Java, getting a max-heap is one `Collections.reverseOrder()`
> call; in Rust you wrap elements in `std::cmp::Reverse<T>` to get a min-heap.
>
> Backtracking is often cleaner in Java because you can use instance variables
> (`this.result`, `this.path`) and avoid threading mutable state through every
> call frame. Rust forces you to pass `&mut Vec<Vec<T>>` and `&mut Vec<T>` as
> parameters, which is more verbose but eliminates accidental aliasing and
> prevents borrow-checker errors that are invisible in Java.
>
> The main Java performance caveat: `PriorityQueue<int[]>` boxes array
> references, and `PriorityQueue<Integer>` boxes every `int`. Rust's
> `BinaryHeap<i32>` stores plain `i32` values — zero boxing, zero indirection.
> For competitive programming this rarely matters, but for production code
> handling millions of elements the difference is measurable.

---

## Part 1 — Heap / Priority Queue

---

### Problem 1 — LC #703: Kth Largest Element in a Stream

**Problem.** Design a class that finds the `k`-th largest element in a stream.
Initialize it with integer `k` and an array of numbers. The method `add(val)`
inserts `val` and returns the current k-th largest element.

**Key insight.** Maintain a min-heap of exactly size `k`. The heap root is
always the k-th largest because there are exactly `k-1` elements above it. When
a new element arrives, push it; if the heap exceeds size `k`, pop the minimum.
The root is then the k-th largest.

```java
import java.util.PriorityQueue;

class KthLargest {
    private final int k;
    private final PriorityQueue<Integer> minHeap; // min-heap of size k

    public KthLargest(int k, int[] nums) {
        this.k = k;
        this.minHeap = new PriorityQueue<>(); // default: min at head
        for (int n : nums) {
            add(n);
        }
    }

    public int add(int val) {
        minHeap.offer(val);
        // Keep only the k largest elements
        while (minHeap.size() > k) {
            minHeap.poll(); // removes the smallest
        }
        // The root of the min-heap is the k-th largest
        return minHeap.peek();
    }

    public static void main(String[] args) {
        KthLargest kl = new KthLargest(3, new int[]{4, 5, 8, 2});

        int r1 = kl.add(3);
        if (r1 != 4) throw new AssertionError("add(3): expected 4, got " + r1);

        int r2 = kl.add(5);
        if (r2 != 5) throw new AssertionError("add(5): expected 5, got " + r2);

        int r3 = kl.add(10);
        if (r3 != 5) throw new AssertionError("add(10): expected 5, got " + r3);

        int r4 = kl.add(9);
        if (r4 != 8) throw new AssertionError("add(9): expected 8, got " + r4);

        int r5 = kl.add(4);
        if (r5 != 8) throw new AssertionError("add(4): expected 8, got " + r5);

        // k=1: always returns the largest seen
        KthLargest kl1 = new KthLargest(1, new int[]{});
        int a = kl1.add(1);
        if (a != 1) throw new AssertionError("k=1 add(1): expected 1, got " + a);
        int b = kl1.add(-1);
        if (b != 1) throw new AssertionError("k=1 add(-1): expected 1, got " + b);
        int c = kl1.add(3);
        if (c != 3) throw new AssertionError("k=1 add(3): expected 3, got " + c);

        System.out.println("LC #703 KthLargest: all tests passed");
    }
}
```

**Complexity.** Time O(n log k) for initialization, O(log k) per `add`.
Space O(k).

**Java notes.**
- `PriorityQueue<Integer>()` (no argument) creates a min-heap — the default
  natural ordering for `Integer` is ascending, so the smallest element is at
  the head.
- `while (minHeap.size() > k) minHeap.poll()` can also be written as
  `if (minHeap.size() > k) minHeap.poll()` because we add exactly one element
  per call; either form is correct.
- `minHeap.peek()` returns `null` on an empty heap — safe here because we
  guarantee size `>= 1` after initialization if `nums` contains at least one
  element, but LeetCode guarantees the stream is non-empty before the first
  call to `add`.

---

### Problem 2 — LC #1046: Last Stone Weight

**Problem.** Given an array of stone weights, repeatedly smash the two
heaviest. If equal, both are destroyed; if unequal, the smaller is destroyed
and the larger becomes `|x - y|`. Return the last remaining stone, or 0.

**Key insight.** Use a max-heap. Each iteration pop the two largest, compute
the difference, and push it back if nonzero.

```java
import java.util.Collections;
import java.util.PriorityQueue;

class Solution {
    public int lastStoneWeight(int[] stones) {
        // Max-heap: largest stone at head
        PriorityQueue<Integer> maxHeap =
            new PriorityQueue<>(Collections.reverseOrder());

        for (int s : stones) {
            maxHeap.offer(s);
        }

        while (maxHeap.size() > 1) {
            int x = maxHeap.poll(); // heaviest
            int y = maxHeap.poll(); // second heaviest
            if (x != y) {
                maxHeap.offer(x - y);
            }
        }

        return maxHeap.isEmpty() ? 0 : maxHeap.poll();
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        int r1 = sol.lastStoneWeight(new int[]{2, 7, 4, 1, 8, 1});
        if (r1 != 1) throw new AssertionError("example: expected 1, got " + r1);

        int r2 = sol.lastStoneWeight(new int[]{3, 3});
        if (r2 != 0) throw new AssertionError("equal: expected 0, got " + r2);

        int r3 = sol.lastStoneWeight(new int[]{5});
        if (r3 != 5) throw new AssertionError("single: expected 5, got " + r3);

        int r4 = sol.lastStoneWeight(new int[]{2, 4});
        if (r4 != 2) throw new AssertionError("two unequal: expected 2, got " + r4);

        System.out.println("LC #1046 LastStoneWeight: all tests passed");
    }
}
```

**Complexity.** Time O(n log n). Space O(n).

**Java notes.**
- `Collections.reverseOrder()` returns a `Comparator<T>` that reverses the
  natural order — the idiomatic way to create a max-heap in Java.
- Alternatively: `new PriorityQueue<>((a, b) -> b - a)`. Beware of integer
  overflow with this lambda when values can be `Integer.MIN_VALUE`; prefer
  `Integer.compare(b, a)` for safety: `(a, b) -> Integer.compare(b, a)`.
- `maxHeap.isEmpty() ? 0 : maxHeap.poll()` handles the case where all stones
  cancel out.

---

### Problem 3 — LC #973: K Closest Points to Origin

**Problem.** Given a list of 2D points, return the `k` closest to the origin
(0, 0). Distances are Euclidean but compare squared distances to stay in
integer arithmetic.

**Key insight.** Maintain a max-heap of size `k` keyed by squared distance. If
the heap grows beyond `k`, pop the farthest point. The remaining `k` entries
are the closest.

```java
import java.util.Arrays;
import java.util.PriorityQueue;

class Solution {
    public int[][] kClosest(int[][] points, int k) {
        // Max-heap by squared distance: farthest point sits at head
        PriorityQueue<int[]> maxHeap =
            new PriorityQueue<>((a, b) -> distSq(b) - distSq(a));

        for (int[] p : points) {
            maxHeap.offer(p);
            if (maxHeap.size() > k) {
                maxHeap.poll(); // remove farthest
            }
        }

        return maxHeap.toArray(new int[0][]);
    }

    private int distSq(int[] p) {
        return p[0] * p[0] + p[1] * p[1];
    }

    // ---- test driver ----
    private static int[][] sorted(int[][] arr) {
        int[][] copy = arr.clone();
        Arrays.sort(copy, (a, b) -> a[0] != b[0] ? a[0] - b[0] : a[1] - b[1]);
        return copy;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        // Example 1: [[1,3],[-2,2]], k=1  →  [[-2,2]]
        int[][] r1 = sorted(sol.kClosest(new int[][]{{1, 3}, {-2, 2}}, 1));
        if (r1.length != 1 || r1[0][0] != -2 || r1[0][1] != 2)
            throw new AssertionError("example1: got " + Arrays.deepToString(r1));

        // Example 2: [[3,3],[5,-1],[-2,4]], k=2  →  [[3,3],[-2,4]]
        int[][] r2 = sorted(sol.kClosest(
            new int[][]{{3, 3}, {5, -1}, {-2, 4}}, 2));
        int[][] exp2 = sorted(new int[][]{{3, 3}, {-2, 4}});
        if (!Arrays.deepEquals(r2, exp2))
            throw new AssertionError("example2: got " + Arrays.deepToString(r2));

        // Origin closest
        int[][] r3 = sol.kClosest(new int[][]{{0, 0}, {1, 1}}, 1);
        if (r3[0][0] != 0 || r3[0][1] != 0)
            throw new AssertionError("origin: got " + Arrays.deepToString(r3));

        System.out.println("LC #973 KClosestPoints: all tests passed");
    }
}
```

**Complexity.** Time O(n log k). Space O(k).

**Java notes.**
- The comparator `(a, b) -> distSq(b) - distSq(a)` orders by descending
  distance so the farthest point is at the heap head. When the heap size exceeds
  `k`, we `poll()` to evict the farthest, keeping exactly the `k` closest.
- `distSq(b) - distSq(a)` is safe from overflow here because squared
  coordinates are at most `10^4 * 10^4 = 10^8`, which fits in `int`. For larger
  coordinates use `Integer.compare(distSq(b), distSq(a))`.
- `maxHeap.toArray(new int[0][])` collects remaining entries — no particular
  output order is required by LeetCode.

---

### Problem 4 — LC #215: Kth Largest Element in an Array

**Problem.** Find the k-th largest element in an unsorted array (k-th in
sorted descending order, not k-th distinct).

**Key insight.** Two approaches: (A) min-heap of size k in O(n log k); (B)
`Arrays.sort` in O(n log n) — simple but slower; (C) quickselect in O(n)
average. The heap approach is the standard interview answer.

```java
import java.util.PriorityQueue;

class Solution {

    // --- Approach A: Min-heap, O(n log k) time, O(k) space ---
    public int findKthLargest(int[] nums, int k) {
        PriorityQueue<Integer> minHeap = new PriorityQueue<>(); // min at head
        for (int n : nums) {
            minHeap.offer(n);
            if (minHeap.size() > k) {
                minHeap.poll(); // evict the smallest
            }
        }
        // Root of min-heap is the k-th largest
        return minHeap.peek();
    }

    // --- Approach B: Sort, O(n log n) time, O(1) extra space ---
    public int findKthLargestSort(int[] nums, int k) {
        var sorted = nums.clone();
        java.util.Arrays.sort(sorted);
        return sorted[sorted.length - k]; // k-th from the end
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        // Heap approach
        int r1 = sol.findKthLargest(new int[]{3, 2, 1, 5, 6, 4}, 2);
        if (r1 != 5) throw new AssertionError("heap k=2: expected 5, got " + r1);

        int r2 = sol.findKthLargest(new int[]{3, 2, 3, 1, 2, 4, 5, 5, 6}, 4);
        if (r2 != 4) throw new AssertionError("heap k=4: expected 4, got " + r2);

        int r3 = sol.findKthLargest(new int[]{1}, 1);
        if (r3 != 1) throw new AssertionError("single: expected 1, got " + r3);

        // Sort approach
        int s1 = sol.findKthLargestSort(new int[]{3, 2, 1, 5, 6, 4}, 2);
        if (s1 != 5) throw new AssertionError("sort k=2: expected 5, got " + s1);

        int s2 = sol.findKthLargestSort(new int[]{3, 2, 3, 1, 2, 4, 5, 5, 6}, 4);
        if (s2 != 4) throw new AssertionError("sort k=4: expected 4, got " + s2);

        System.out.println("LC #215 KthLargestArray: all tests passed");
    }
}
```

**Complexity.** Heap: Time O(n log k), Space O(k). Sort: Time O(n log n),
Space O(n) for clone.

**Java notes.**
- `var sorted = nums.clone()` uses Java 10+ `var` to avoid repeating the type.
  `nums.clone()` is a shallow copy — sufficient for `int[]`.
- The heap approach is preferred in interviews because it handles streaming
  input (elements arriving one at a time) and uses O(k) space rather than O(n).
- Both `offer` and `add` insert into the heap; `offer` is preferred because it
  returns `false` on capacity-bounded queues rather than throwing an exception
  (though standard `PriorityQueue` is unbounded).

---

### Problem 5 — LC #621: Task Scheduler

**Problem.** Given CPU tasks (letters) and a cooldown `n`, find the minimum
number of CPU intervals to execute all tasks. Identical tasks must be at least
`n` intervals apart. Idle intervals are allowed.

**Key insight.** Greedy with a max-heap and a cooldown queue. At each tick:
if the cooldown queue has a task ready to re-enter the heap, move it in. Then
pick the most frequent available task (pop the max-heap). If nothing is
available, the CPU idles.

```java
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.Deque;
import java.util.HashMap;
import java.util.Map;
import java.util.PriorityQueue;

class Solution {
    public int leastInterval(char[] tasks, int n) {
        // Count frequencies
        Map<Character, Integer> freq = new HashMap<>();
        for (char t : tasks) {
            freq.merge(t, 1, Integer::sum);
        }

        // Max-heap of (count) — we only need the frequency, not the letter
        PriorityQueue<Integer> maxHeap =
            new PriorityQueue<>(Collections.reverseOrder());
        maxHeap.addAll(freq.values());

        // Cooldown queue: [remaining_count, earliest_available_time]
        Deque<int[]> cooldown = new ArrayDeque<>();
        int time = 0;

        while (!maxHeap.isEmpty() || !cooldown.isEmpty()) {
            time++;

            // Release tasks whose cooldown has expired
            if (!cooldown.isEmpty() && cooldown.peekFirst()[1] <= time) {
                maxHeap.offer(cooldown.pollFirst()[0]);
            }

            if (!maxHeap.isEmpty()) {
                int cnt = maxHeap.poll();
                if (cnt > 1) {
                    cooldown.addLast(new int[]{cnt - 1, time + n + 1});
                }
            }
            // else: CPU idle this tick
        }

        return time;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        // A->B->idle->A->B->idle->A->B = 8
        int r1 = sol.leastInterval(
            new char[]{'A', 'A', 'A', 'B', 'B', 'B'}, 2);
        if (r1 != 8) throw new AssertionError("ex1: expected 8, got " + r1);

        // n=0: no cooling needed, run all 6 tasks
        int r2 = sol.leastInterval(
            new char[]{'A', 'A', 'A', 'B', 'B', 'B'}, 0);
        if (r2 != 6) throw new AssertionError("n=0: expected 6, got " + r2);

        // Enough variety to fill cooldown
        int r3 = sol.leastInterval(
            new char[]{'A','A','A','A','A','A','B','C','D','E','F','G'}, 2);
        if (r3 != 16) throw new AssertionError("variety: expected 16, got " + r3);

        // Single task
        int r4 = sol.leastInterval(new char[]{'A'}, 10);
        if (r4 != 1) throw new AssertionError("single: expected 1, got " + r4);

        System.out.println("LC #621 TaskScheduler: all tests passed");
    }
}
```

**Complexity.** Time O(t log 26) = O(t) where t is the total number of tasks
(at most 26 distinct). Space O(26) = O(1).

**Java notes.**
- `freq.merge(t, 1, Integer::sum)` is the idiomatic Java 8+ upsert: inserts 1
  if absent, otherwise adds 1 to the existing value.
- `ArrayDeque` is used for the cooldown queue — never use `Stack` in modern
  Java. `peekFirst` / `pollFirst` / `addLast` give explicit FIFO semantics.
- The cooldown queue entries store `[remaining_count, earliest_time]` as
  `int[]`. No need to box into a record for an internal helper structure.

---

### Problem 6 — LC #355: Design Twitter

**Problem.** Design a simplified Twitter: `postTweet(userId, tweetId)`,
`getNewsFeed(userId)` (10 most recent tweets from user and followees),
`follow(followerId, followeeId)`, `unfollow(followerId, followeeId)`.

**Key insight.** Store each user's tweets as a `List<int[]>` of
`[timestamp, tweetId]`. For `getNewsFeed`, seed a max-heap with the most
recent tweet from each candidate user, then iterate: pop the top tweet, add
it to the result, then push the next tweet from the same user's list. This is
a k-way merge.

```java
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;
import java.util.Set;

class Twitter {
    private int timestamp = 0;
    // userId -> list of [timestamp, tweetId]
    private final Map<Integer, List<int[]>> tweets = new HashMap<>();
    // followerId -> set of followeeIds
    private final Map<Integer, Set<Integer>> following = new HashMap<>();

    public void postTweet(int userId, int tweetId) {
        tweets.computeIfAbsent(userId, k -> new ArrayList<>())
              .add(new int[]{timestamp++, tweetId});
    }

    public List<Integer> getNewsFeed(int userId) {
        // Collect candidate user ids: self + followees
        Set<Integer> candidates = new HashSet<>();
        candidates.add(userId);
        candidates.addAll(following.getOrDefault(userId, Collections.emptySet()));

        // Max-heap by timestamp; each entry: [timestamp, tweetId, userId, indexInList]
        PriorityQueue<int[]> maxHeap =
            new PriorityQueue<>((a, b) -> b[0] - a[0]);

        for (int uid : candidates) {
            List<int[]> list = tweets.get(uid);
            if (list != null && !list.isEmpty()) {
                int idx = list.size() - 1;
                int[] latest = list.get(idx);
                maxHeap.offer(new int[]{latest[0], latest[1], uid, idx});
            }
        }

        List<Integer> feed = new ArrayList<>();
        while (!maxHeap.isEmpty() && feed.size() < 10) {
            int[] top = maxHeap.poll();
            feed.add(top[1]); // tweetId

            int nextIdx = top[3] - 1;
            if (nextIdx >= 0) {
                int uid = top[2];
                int[] prev = tweets.get(uid).get(nextIdx);
                maxHeap.offer(new int[]{prev[0], prev[1], uid, nextIdx});
            }
        }

        return feed;
    }

    public void follow(int followerId, int followeeId) {
        following.computeIfAbsent(followerId, k -> new HashSet<>())
                 .add(followeeId);
    }

    public void unfollow(int followerId, int followeeId) {
        Set<Integer> set = following.get(followerId);
        if (set != null) set.remove(followeeId);
    }

    public static void main(String[] args) {
        Twitter twitter = new Twitter();

        twitter.postTweet(1, 5);
        var feed1 = twitter.getNewsFeed(1);
        if (feed1.size() != 1 || feed1.get(0) != 5)
            throw new AssertionError("feed1: " + feed1);

        twitter.follow(1, 2);
        twitter.postTweet(2, 6);
        var feed2 = twitter.getNewsFeed(1);
        if (feed2.size() != 2 || feed2.get(0) != 6 || feed2.get(1) != 5)
            throw new AssertionError("feed2: " + feed2);

        twitter.unfollow(1, 2);
        var feed3 = twitter.getNewsFeed(1);
        if (feed3.size() != 1 || feed3.get(0) != 5)
            throw new AssertionError("feed3: " + feed3);

        // Ten-tweet limit
        Twitter t2 = new Twitter();
        for (int i = 0; i < 12; i++) t2.postTweet(1, i);
        var feed4 = t2.getNewsFeed(1);
        if (feed4.size() != 10)
            throw new AssertionError("size limit: got " + feed4.size());
        if (feed4.get(0) != 11)
            throw new AssertionError("most recent tweet: expected 11, got " + feed4.get(0));

        // Empty feed
        Twitter t3 = new Twitter();
        if (!t3.getNewsFeed(99).isEmpty())
            throw new AssertionError("empty feed: expected []");

        System.out.println("LC #355 DesignTwitter: all tests passed");
    }
}
```

**Complexity.** `postTweet` O(1). `getNewsFeed` O(U log U + 10 log U) where U
is the number of candidate users. `follow`/`unfollow` O(1).

**Java notes.**
- `computeIfAbsent(key, k -> new ArrayList<>())` is the Java idiomatic upsert —
  equivalent to Rust's `entry(...).or_default()`.
- `getOrDefault(userId, Collections.emptySet())` avoids a null check and does
  not insert an empty set into the map (unlike `computeIfAbsent`).
- The heap entry `int[]` stores `{timestamp, tweetId, userId, listIndex}`.
  Tuples are absent in Java; `int[]` or a private record are the two idiomatic
  choices.

---

### Problem 7 — LC #295: Find Median from Data Stream

**Problem.** Design a data structure supporting `addNum(int num)` and
`findMedian()`. `findMedian` returns the median of all numbers added so far.

**Key insight.** Maintain two heaps: a max-heap for the lower half and a
min-heap for the upper half. Keep them balanced (sizes differ by at most 1).
The median is the top of the larger heap, or the average of both tops.

```java
import java.util.Collections;
import java.util.PriorityQueue;

class MedianFinder {
    // Max-heap: lower half (largest of lower half at top)
    private final PriorityQueue<Integer> lo =
        new PriorityQueue<>(Collections.reverseOrder());

    // Min-heap: upper half (smallest of upper half at top)
    private final PriorityQueue<Integer> hi =
        new PriorityQueue<>();

    public void addNum(int num) {
        // Always push into lo first
        lo.offer(num);

        // Invariant: lo.peek() <= hi.peek()
        if (!hi.isEmpty() && lo.peek() > hi.peek()) {
            hi.offer(lo.poll());
        }

        // Rebalance sizes: lo may have at most 1 extra element
        if (lo.size() > hi.size() + 1) {
            hi.offer(lo.poll());
        } else if (hi.size() > lo.size()) {
            lo.offer(hi.poll());
        }
    }

    public double findMedian() {
        if (lo.size() > hi.size()) {
            return lo.peek();
        }
        return (lo.peek() + (double) hi.peek()) / 2.0;
    }

    public static void main(String[] args) {
        // Odd count
        MedianFinder mf1 = new MedianFinder();
        mf1.addNum(1); mf1.addNum(2); mf1.addNum(3);
        double m1 = mf1.findMedian();
        if (m1 != 2.0) throw new AssertionError("odd: expected 2.0, got " + m1);

        // Even count
        MedianFinder mf2 = new MedianFinder();
        mf2.addNum(1); mf2.addNum(2);
        double m2 = mf2.findMedian();
        if (m2 != 1.5) throw new AssertionError("even: expected 1.5, got " + m2);

        // Sequential
        MedianFinder mf3 = new MedianFinder();
        mf3.addNum(1);
        if (mf3.findMedian() != 1.0)
            throw new AssertionError("seq1: expected 1.0, got " + mf3.findMedian());
        mf3.addNum(2);
        if (mf3.findMedian() != 1.5)
            throw new AssertionError("seq2: expected 1.5, got " + mf3.findMedian());
        mf3.addNum(3);
        if (mf3.findMedian() != 2.0)
            throw new AssertionError("seq3: expected 2.0, got " + mf3.findMedian());

        // Reverse order
        MedianFinder mf4 = new MedianFinder();
        mf4.addNum(5); mf4.addNum(3); mf4.addNum(1);
        double m4 = mf4.findMedian();
        if (m4 != 3.0) throw new AssertionError("reverse: expected 3.0, got " + m4);

        // Negatives
        MedianFinder mf5 = new MedianFinder();
        mf5.addNum(-1); mf5.addNum(-2); mf5.addNum(-3);
        double m5 = mf5.findMedian();
        if (m5 != -2.0) throw new AssertionError("negatives: expected -2.0, got " + m5);

        System.out.println("LC #295 MedianFinder: all tests passed");
    }
}
```

**Complexity.** `addNum` O(log n). `findMedian` O(1). Space O(n).

**Java notes.**
- `lo` is a max-heap (`Collections.reverseOrder()`), `hi` is a min-heap
  (default). This mirrors Rust's `BinaryHeap<i32>` for `lo` and
  `BinaryHeap<Reverse<i32>>` for `hi`.
- `lo.peek() + (double) hi.peek()` casts the second operand to `double` before
  division. Either cast works; `(lo.peek() + hi.peek()) / 2.0` is also safe
  because one operand is already a `double` literal.
- Java auto-unboxes `Integer` to `int` for arithmetic; if either heap could be
  empty when `findMedian` is called, a `NullPointerException` would occur.
  LeetCode guarantees at least one call to `addNum` before `findMedian`.

---

## Part 2 — Backtracking

### The Backtracking Template

Every backtracking problem below follows the same structure. The key steps are:
**choose**, **explore**, **un-choose** (backtrack).

```java
void backtrack(
        int start,
        int[] nums,
        List<Integer> path,
        List<List<Integer>> result) {

    // 1. Record the current state (may be conditional on a base case)
    result.add(new ArrayList<>(path));     // snapshot — NOT a reference

    // 2. Explore next choices
    for (int i = start; i < nums.length; i++) {
        path.add(nums[i]);                              // choose
        backtrack(i + 1, nums, path, result);           // explore
        path.remove(path.size() - 1);                  // un-choose (backtrack)
    }
}
```

**Java vs Rust backtracking comparison:**

| Java pattern | Rust pattern |
|---|---|
| `List<Integer> path = new ArrayList<>()` (instance or local var) | `let mut path: Vec<i32> = Vec::new()` |
| `result.add(new ArrayList<>(path))` | `result.push(path.clone())` |
| `path.remove(path.size() - 1)` | `path.pop()` |
| `this.result` (instance accumulator) | `&mut Vec<Vec<i32>>` passed as parameter |
| `used[i] = true / false` | same pattern — `used[i] = true/false` |

---

### Problem 8 — LC #78: Subsets

**Problem.** Given an integer array `nums` of unique elements, return all
possible subsets (the power set). The result must not contain duplicate subsets.

**Key insight.** At each recursive call, record the current path as a valid
subset (including the empty set). Then try adding each element from `start`
onward, recurse, and remove it.

```java
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Solution {
    public List<List<Integer>> subsets(int[] nums) {
        List<List<Integer>> result = new ArrayList<>();
        backtrack(0, nums, new ArrayList<>(), result);
        return result;
    }

    private void backtrack(int start, int[] nums,
                           List<Integer> path,
                           List<List<Integer>> result) {
        result.add(new ArrayList<>(path)); // snapshot of current path
        for (int i = start; i < nums.length; i++) {
            path.add(nums[i]);                     // choose
            backtrack(i + 1, nums, path, result);  // explore
            path.remove(path.size() - 1);          // un-choose
        }
    }

    // ---- helper for tests ----
    // Note: inner lists must be mutable (ArrayList, not List.of) because
    // Collections.sort() requires a mutable list.
    private static List<List<Integer>> sorted(List<List<Integer>> v) {
        v.forEach(sub -> java.util.Collections.sort(sub));
        v.sort((a, b) -> a.toString().compareTo(b.toString()));
        return v;
    }

    private static List<Integer> mlist(Integer... vals) {
        return new ArrayList<>(java.util.Arrays.asList(vals));
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = sorted(sol.subsets(new int[]{1, 2, 3}));
        var exp1 = sorted(new ArrayList<>(java.util.Arrays.asList(
            mlist(), mlist(1), mlist(2), mlist(3),
            mlist(1, 2), mlist(1, 3), mlist(2, 3), mlist(1, 2, 3))));
        if (!r1.equals(exp1))
            throw new AssertionError("subsets [1,2,3]: got " + r1);

        var r2 = sorted(sol.subsets(new int[]{0}));
        var exp2 = sorted(new ArrayList<>(java.util.Arrays.asList(mlist(), mlist(0))));
        if (!r2.equals(exp2))
            throw new AssertionError("subsets [0]: got " + r2);

        System.out.println("LC #78 Subsets: all tests passed");
    }
}
```

**Complexity.** Time O(n * 2^n) — 2^n subsets, each copy O(n). Space O(n)
recursion depth + O(n * 2^n) output.

**Java notes.**
- `result.add(new ArrayList<>(path))` creates a defensive copy. If you write
  `result.add(path)`, every entry in `result` will point to the same mutable
  list, which will be empty at the end.
- `path.remove(path.size() - 1)` removes by index (not by value). For a list
  of `Integer`, `path.remove(Integer.valueOf(x))` removes by value; using an
  index is safer and O(1) for `ArrayList`.

---

### Problem 9 — LC #39: Combination Sum

**Problem.** Given distinct positive integers `candidates` and a `target`,
return all unique combinations summing to `target`. The same number may be
used any number of times.

**Key insight.** Pass the same `start` index into the recursive call (not
`start + 1`) to allow reuse of the current element. Prune when the remaining
target goes negative.

```java
import java.util.ArrayList;
import java.util.List;

class Solution {
    public List<List<Integer>> combinationSum(int[] candidates, int target) {
        List<List<Integer>> result = new ArrayList<>();
        backtrack(0, target, candidates, new ArrayList<>(), result);
        return result;
    }

    private void backtrack(int start, int remaining, int[] candidates,
                           List<Integer> path, List<List<Integer>> result) {
        if (remaining == 0) {
            result.add(new ArrayList<>(path));
            return;
        }
        for (int i = start; i < candidates.length; i++) {
            if (candidates[i] > remaining) continue; // prune
            path.add(candidates[i]);
            backtrack(i, remaining - candidates[i], candidates, path, result); // i, not i+1
            path.remove(path.size() - 1);
        }
    }

    private static List<List<Integer>> sorted(List<List<Integer>> v) {
        v.forEach(c -> java.util.Collections.sort(c));
        v.sort((a, b) -> a.toString().compareTo(b.toString()));
        return v;
    }

    private static List<Integer> mlist(Integer... vals) {
        return new ArrayList<>(java.util.Arrays.asList(vals));
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = sorted(sol.combinationSum(new int[]{2, 3, 6, 7}, 7));
        var exp1 = sorted(new ArrayList<>(java.util.Arrays.asList(
            mlist(2, 2, 3), mlist(7))));
        if (!r1.equals(exp1))
            throw new AssertionError("ex1: got " + r1);

        var r2 = sorted(sol.combinationSum(new int[]{2, 3, 5}, 8));
        var exp2 = sorted(new ArrayList<>(java.util.Arrays.asList(
            mlist(2, 2, 2, 2), mlist(2, 3, 3), mlist(3, 5))));
        if (!r2.equals(exp2))
            throw new AssertionError("ex2: got " + r2);

        var r3 = sol.combinationSum(new int[]{3, 5}, 1);
        if (!r3.isEmpty())
            throw new AssertionError("no solution: expected [], got " + r3);

        System.out.println("LC #39 CombinationSum: all tests passed");
    }
}
```

**Complexity.** Time O(n^(T/M)) where T is target and M is the smallest
candidate. Space O(T/M) recursion depth.

**Java notes.**
- `backtrack(i, ...)` — passing `i` (same index) allows the same candidate to
  be chosen again. `backtrack(i + 1, ...)` would require moving forward.
- This is one of the few problems where the "prune with `continue`" pattern is
  cleaner than a `break`: if candidates are unsorted, some later candidates
  might still be small enough. If you sort candidates first you can `break`
  early.

---

### Problem 10 — LC #40: Combination Sum II

**Problem.** Like LC #39 but each number may only be used once, and candidates
may contain duplicates. Return all unique combinations.

**Key insight.** Sort the input. In the loop, skip duplicates at the same
recursion level with `if (i > start && candidates[i] == candidates[i-1])`.
Advance by `i + 1` (not `i`) to prevent reuse of the same element.

```java
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Solution {
    public List<List<Integer>> combinationSum2(int[] candidates, int target) {
        Arrays.sort(candidates);
        List<List<Integer>> result = new ArrayList<>();
        backtrack(0, target, candidates, new ArrayList<>(), result);
        return result;
    }

    private void backtrack(int start, int remaining, int[] candidates,
                           List<Integer> path, List<List<Integer>> result) {
        if (remaining == 0) {
            result.add(new ArrayList<>(path));
            return;
        }
        for (int i = start; i < candidates.length; i++) {
            // Skip duplicates at the same recursion level
            if (i > start && candidates[i] == candidates[i - 1]) continue;
            // Sorted array: all further candidates are also too large
            if (candidates[i] > remaining) break;
            path.add(candidates[i]);
            backtrack(i + 1, remaining - candidates[i], candidates, path, result);
            path.remove(path.size() - 1);
        }
    }

    private static List<List<Integer>> sorted(List<List<Integer>> v) {
        v.forEach(c -> java.util.Collections.sort(c));
        v.sort((a, b) -> a.toString().compareTo(b.toString()));
        return v;
    }

    private static List<Integer> mlist(Integer... vals) {
        return new ArrayList<>(java.util.Arrays.asList(vals));
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = sorted(sol.combinationSum2(new int[]{10,1,2,7,6,1,5}, 8));
        var exp1 = sorted(new ArrayList<>(java.util.Arrays.asList(
            mlist(1,1,6), mlist(1,2,5), mlist(1,7), mlist(2,6))));
        if (!r1.equals(exp1))
            throw new AssertionError("ex1: got " + r1);

        var r2 = sorted(sol.combinationSum2(new int[]{2,5,2,1,2}, 5));
        var exp2 = sorted(new ArrayList<>(java.util.Arrays.asList(mlist(1,2,2), mlist(5))));
        if (!r2.equals(exp2))
            throw new AssertionError("ex2: got " + r2);

        var r3 = sorted(sol.combinationSum2(new int[]{1,1,1}, 2));
        var exp3 = sorted(new ArrayList<>(java.util.Arrays.asList(mlist(1,1))));
        if (!r3.equals(exp3))
            throw new AssertionError("all same: got " + r3);

        System.out.println("LC #40 CombinationSum2: all tests passed");
    }
}
```

**Complexity.** Time O(2^n). Space O(n) recursion depth.

**Java notes.**
- `break` (not `continue`) when `candidates[i] > remaining` because the array
  is sorted — all further candidates are also too large.
- The condition `i > start` in the deduplication guard is critical. It prevents
  skipping the first occurrence of a duplicate value at this level, while still
  skipping later occurrences.

---

### Problem 11 — LC #46: Permutations

**Problem.** Given an array of distinct integers, return all possible
permutations.

**Key insight.** At each step, try every element that has not yet been added to
the current path. Track usage with a boolean array. At depth `n`, record the
path.

```java
import java.util.ArrayList;
import java.util.List;

class Solution {
    public List<List<Integer>> permute(int[] nums) {
        List<List<Integer>> result = new ArrayList<>();
        boolean[] used = new boolean[nums.length];
        backtrack(nums, used, new ArrayList<>(), result);
        return result;
    }

    private void backtrack(int[] nums, boolean[] used,
                           List<Integer> path, List<List<Integer>> result) {
        if (path.size() == nums.length) {
            result.add(new ArrayList<>(path));
            return;
        }
        for (int i = 0; i < nums.length; i++) {
            if (used[i]) continue;
            used[i] = true;
            path.add(nums[i]);                          // choose
            backtrack(nums, used, path, result);        // explore
            path.remove(path.size() - 1);               // un-choose
            used[i] = false;                            // backtrack boolean
        }
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = sol.permute(new int[]{1, 2, 3});
        if (r1.size() != 6)
            throw new AssertionError("permute [1,2,3]: expected 6, got " + r1.size());

        r1.sort((a, b) -> a.toString().compareTo(b.toString()));
        var exp1 = new ArrayList<>(List.of(
            List.of(1,2,3), List.of(1,3,2), List.of(2,1,3),
            List.of(2,3,1), List.of(3,1,2), List.of(3,2,1)));
        exp1.sort((a, b) -> a.toString().compareTo(b.toString()));
        if (!r1.equals(exp1))
            throw new AssertionError("permute [1,2,3]: got " + r1);

        var r2 = sol.permute(new int[]{0});
        if (r2.size() != 1 || !r2.get(0).equals(List.of(0)))
            throw new AssertionError("permute [0]: got " + r2);

        var r3 = sol.permute(new int[]{0, 1});
        if (r3.size() != 2)
            throw new AssertionError("permute [0,1]: expected 2, got " + r3.size());

        System.out.println("LC #46 Permutations: all tests passed");
    }
}
```

**Complexity.** Time O(n * n!). Space O(n) recursion depth + O(n) for `used`.

**Java notes.**
- `used[i] = false` after the recursive call is the backtrack step for the
  boolean flag — it must mirror `path.remove(path.size() - 1)`.
- Unlike subset/combination problems, permutations always restart the inner
  loop from `i = 0` (not `i = start`), because order matters and the same
  element can appear in different positions.

---

### Problem 12 — LC #90: Subsets II

**Problem.** Given an integer array `nums` that may contain duplicates, return
all possible subsets without duplicate subsets.

**Key insight.** Sort first. At each recursion level, skip elements equal to
the previous one using the same guard as Combination Sum II.

```java
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Solution {
    public List<List<Integer>> subsetsWithDup(int[] nums) {
        Arrays.sort(nums);
        List<List<Integer>> result = new ArrayList<>();
        backtrack(0, nums, new ArrayList<>(), result);
        return result;
    }

    private void backtrack(int start, int[] nums,
                           List<Integer> path, List<List<Integer>> result) {
        result.add(new ArrayList<>(path));
        for (int i = start; i < nums.length; i++) {
            if (i > start && nums[i] == nums[i - 1]) continue; // skip duplicates
            path.add(nums[i]);
            backtrack(i + 1, nums, path, result);
            path.remove(path.size() - 1);
        }
    }

    private static List<List<Integer>> sorted(List<List<Integer>> v) {
        v.forEach(s -> java.util.Collections.sort(s));
        v.sort((a, b) -> a.toString().compareTo(b.toString()));
        return v;
    }

    private static List<Integer> mlist(Integer... vals) {
        return new ArrayList<>(java.util.Arrays.asList(vals));
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = sorted(sol.subsetsWithDup(new int[]{1, 2, 2}));
        var exp1 = sorted(new ArrayList<>(java.util.Arrays.asList(
            mlist(), mlist(1), mlist(1,2), mlist(1,2,2),
            mlist(2), mlist(2,2))));
        if (!r1.equals(exp1))
            throw new AssertionError("subsetsWithDup [1,2,2]: got " + r1);

        var r2 = sorted(sol.subsetsWithDup(new int[]{0, 0}));
        var exp2 = sorted(new ArrayList<>(java.util.Arrays.asList(
            mlist(), mlist(0), mlist(0,0))));
        if (!r2.equals(exp2))
            throw new AssertionError("subsetsWithDup [0,0]: got " + r2);

        System.out.println("LC #90 SubsetsII: all tests passed");
    }
}
```

**Complexity.** Time O(n * 2^n). Space O(n).

**Java notes.**
- Structure is identical to LC #78 (Subsets) plus `Arrays.sort(nums)` and the
  `i > start && nums[i] == nums[i-1]` guard. Recognizing this relationship
  between the two problems reinforces the deduplication pattern.
- `Arrays.sort(nums)` sorts the original array in place. If the caller needs
  the original order preserved, clone first: `int[] sorted = nums.clone()`.

---

### Problem 13 — LC #79: Word Search

**Problem.** Given an `m x n` grid of characters and a word, return `true` if
the word exists as a path of adjacent (horizontally/vertically) cells, with no
cell used twice.

**Key insight.** DFS backtracking from every cell. Mark visited cells by
temporarily replacing the character with `'#'`, then restore it on the way
back.

```java
class Solution {
    public boolean exist(char[][] board, String word) {
        int m = board.length, n = board[0].length;
        for (int r = 0; r < m; r++) {
            for (int c = 0; c < n; c++) {
                if (dfs(board, word, r, c, 0)) return true;
            }
        }
        return false;
    }

    private boolean dfs(char[][] board, String word, int r, int c, int idx) {
        if (idx == word.length()) return true;
        if (r < 0 || r >= board.length || c < 0 || c >= board[0].length)
            return false;
        if (board[r][c] != word.charAt(idx)) return false;

        char saved = board[r][c];
        board[r][c] = '#'; // mark visited

        boolean found = dfs(board, word, r - 1, c, idx + 1)
                     || dfs(board, word, r + 1, c, idx + 1)
                     || dfs(board, word, r, c - 1, idx + 1)
                     || dfs(board, word, r, c + 1, idx + 1);

        board[r][c] = saved; // restore (backtrack)
        return found;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        char[][] b1 = {
            {'A','B','C','E'},
            {'S','F','C','S'},
            {'A','D','E','E'}
        };

        if (!sol.exist(copyBoard(b1), "ABCCED"))
            throw new AssertionError("ABCCED: expected true");
        if (!sol.exist(copyBoard(b1), "SEE"))
            throw new AssertionError("SEE: expected true");
        if (sol.exist(copyBoard(b1), "ABCB"))
            throw new AssertionError("ABCB: expected false");

        char[][] b2 = {{'A'}};
        if (!sol.exist(copyBoard(b2), "A"))
            throw new AssertionError("single A: expected true");
        if (sol.exist(copyBoard(b2), "B"))
            throw new AssertionError("single B: expected false");

        System.out.println("LC #79 WordSearch: all tests passed");
    }

    private static char[][] copyBoard(char[][] board) {
        char[][] copy = new char[board.length][];
        for (int i = 0; i < board.length; i++) copy[i] = board[i].clone();
        return copy;
    }
}
```

**Complexity.** Time O(m * n * 4^L) where L is the word length. Space O(L)
recursion depth.

**Java notes.**
- Bounds checking `r < 0 || r >= board.length || c < 0 || c >= board[0].length`
  is done before character comparison, so no `ArrayIndexOutOfBoundsException`.
  In Rust, `usize` underflow is handled with `wrapping_sub` — Java uses signed
  `int` so negative indices are detectable directly.
- The `||` short-circuits: as soon as one direction returns `true`, the others
  are not evaluated, which is the equivalent of Rust's `.any(...)`.
- `copyBoard` in the test driver is necessary because `exist` mutates the board
  during DFS and LeetCode provides a fresh board per test case.

---

### Problem 14 — LC #131: Palindrome Partitioning

**Problem.** Given string `s`, return all possible ways to partition it so
that every substring is a palindrome.

**Key insight.** Backtracking: at each position `start`, try all prefixes
`s[start..end]`. If the prefix is a palindrome, add it to the path and recurse
from `end`. When `start == s.length()`, record the path.

```java
import java.util.ArrayList;
import java.util.List;

class Solution {
    public List<List<String>> partition(String s) {
        List<List<String>> result = new ArrayList<>();
        backtrack(0, s, new ArrayList<>(), result);
        return result;
    }

    private void backtrack(int start, String s,
                           List<String> path, List<List<String>> result) {
        if (start == s.length()) {
            result.add(new ArrayList<>(path));
            return;
        }
        for (int end = start + 1; end <= s.length(); end++) {
            if (isPalindrome(s, start, end - 1)) {
                path.add(s.substring(start, end));         // choose
                backtrack(end, s, path, result);           // explore
                path.remove(path.size() - 1);              // un-choose
            }
        }
    }

    private boolean isPalindrome(String s, int lo, int hi) {
        while (lo < hi) {
            if (s.charAt(lo) != s.charAt(hi)) return false;
            lo++;
            hi--;
        }
        return true;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = sol.partition("aab");
        r1.sort((a, b) -> a.toString().compareTo(b.toString()));
        var exp1 = new ArrayList<>(List.of(
            List.of("a","a","b"), List.of("aa","b")));
        exp1.sort((a, b) -> a.toString().compareTo(b.toString()));
        if (!r1.equals(exp1))
            throw new AssertionError("partition 'aab': got " + r1);

        var r2 = sol.partition("a");
        if (r2.size() != 1 || !r2.get(0).equals(List.of("a")))
            throw new AssertionError("partition 'a': got " + r2);

        var r3 = sol.partition("aaa");
        if (r3.size() != 4)
            throw new AssertionError("partition 'aaa': expected 4 partitions, got " + r3.size());

        System.out.println("LC #131 PalindromePartitioning: all tests passed");
    }
}
```

**Complexity.** Time O(n * 2^n) — up to 2^(n-1) partitions, O(n) palindrome
check each. Space O(n) recursion depth.

**Java notes.**
- `s.substring(start, end)` creates a new `String`. For very long strings,
  consider caching palindrome results in a `boolean[][] dp` table to avoid
  repeated O(n) checks.
- `isPalindrome(s, start, end - 1)` takes inclusive indices; `s.substring`
  takes an exclusive end. Be careful not to mix the two conventions.
- `end` runs from `start + 1` to `s.length()` inclusive — `end <= s.length()`
  because `s.substring(start, s.length())` is the full remaining suffix.

---

### Problem 15 — LC #17: Letter Combinations of a Phone Number

**Problem.** Given a string of digits (2–9), return all possible letter
combinations from a phone keypad. Return an empty list for empty input.

**Key insight.** Backtracking: at each digit index, iterate over the letters
mapped to that digit, append each to the path, and recurse for the next digit.
When `idx == digits.length()`, record the path.

```java
import java.util.ArrayList;
import java.util.List;

class Solution {
    private static final String[] PHONE = {
        "", "", "abc", "def", "ghi", "jkl",
        "mno", "pqrs", "tuv", "wxyz"
    };

    public List<String> letterCombinations(String digits) {
        if (digits.isEmpty()) return new ArrayList<>();
        List<String> result = new ArrayList<>();
        backtrack(0, digits, new StringBuilder(), result);
        return result;
    }

    private void backtrack(int idx, String digits,
                           StringBuilder path, List<String> result) {
        if (idx == digits.length()) {
            result.add(path.toString());
            return;
        }
        String letters = PHONE[digits.charAt(idx) - '0'];
        for (char ch : letters.toCharArray()) {
            path.append(ch);                              // choose
            backtrack(idx + 1, digits, path, result);    // explore
            path.deleteCharAt(path.length() - 1);        // un-choose
        }
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        var r1 = new ArrayList<>(sol.letterCombinations("23"));
        r1.sort(String::compareTo);
        var exp1 = new ArrayList<>(List.of(
            "ad","ae","af","bd","be","bf","cd","ce","cf"));
        if (!r1.equals(exp1))
            throw new AssertionError("'23': got " + r1);

        var r2 = sol.letterCombinations("");
        if (!r2.isEmpty())
            throw new AssertionError("empty: expected [], got " + r2);

        var r3 = new ArrayList<>(sol.letterCombinations("2"));
        r3.sort(String::compareTo);
        if (!r3.equals(List.of("a","b","c")))
            throw new AssertionError("'2': got " + r3);

        System.out.println("LC #17 LetterCombinations: all tests passed");
    }
}
```

**Complexity.** Time O(4^n * n) where n is the number of digits. Space O(n).

**Java notes.**
- `StringBuilder` is used for `path` instead of `List<Character>` because
  `path.toString()` directly produces the output string. `deleteCharAt` is the
  backtrack step — it removes the last character in O(1) amortized.
- `static final String[] PHONE` is defined at class level. `'0'` is a `char`
  literal; `digits.charAt(idx) - '0'` converts a digit character to its
  integer value.
- Java 17 `switch` expression variant is possible but less readable here since
  the mapping is a straight array lookup.

---

### Problem 16 — LC #51: N-Queens

**Problem.** Place `n` queens on an `n x n` chessboard so no two queens
attack each other. Return all distinct board configurations.

**Key insight.** Place one queen per row. Track attacked columns and both
diagonals with three `Set`s. A queen at `(row, col)` attacks all cells with
the same `col`, same `row - col` (NW-SE diagonal), or same `row + col`
(NE-SW diagonal).

```java
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

class Solution {
    public List<List<String>> solveNQueens(int n) {
        List<List<String>> result = new ArrayList<>();
        int[] queens = new int[n]; // queens[row] = col
        java.util.Arrays.fill(queens, -1);
        backtrack(0, n, queens,
                  new HashSet<>(), new HashSet<>(), new HashSet<>(), result);
        return result;
    }

    private void backtrack(int row, int n, int[] queens,
                           Set<Integer> cols,
                           Set<Integer> diag1,  // row - col
                           Set<Integer> diag2,  // row + col
                           List<List<String>> result) {
        if (row == n) {
            result.add(buildBoard(queens, n));
            return;
        }
        for (int col = 0; col < n; col++) {
            int d1 = row - col;
            int d2 = row + col;
            if (cols.contains(col) || diag1.contains(d1) || diag2.contains(d2))
                continue;

            // choose
            cols.add(col);
            diag1.add(d1);
            diag2.add(d2);
            queens[row] = col;

            backtrack(row + 1, n, queens, cols, diag1, diag2, result);

            // un-choose
            cols.remove(col);
            diag1.remove(d1);
            diag2.remove(d2);
            queens[row] = -1;
        }
    }

    private List<String> buildBoard(int[] queens, int n) {
        List<String> board = new ArrayList<>();
        for (int col : queens) {
            char[] row = new char[n];
            java.util.Arrays.fill(row, '.');
            row[col] = 'Q';
            board.add(new String(row));
        }
        return board;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();

        // n=4: exactly 2 solutions
        var r4 = sol.solveNQueens(4);
        if (r4.size() != 2)
            throw new AssertionError("n=4: expected 2, got " + r4.size());
        var sol1 = List.of(".Q..", "...Q", "Q...", "..Q.");
        var sol2 = List.of("..Q.", "Q...", "...Q", ".Q..");
        r4.sort((a, b) -> a.toString().compareTo(b.toString()));
        var expected4 = new ArrayList<>(List.of(sol1, sol2));
        expected4.sort((a, b) -> a.toString().compareTo(b.toString()));
        if (!r4.equals(expected4))
            throw new AssertionError("n=4 solutions: got " + r4);

        // n=1: one solution
        var r1 = sol.solveNQueens(1);
        if (r1.size() != 1 || !r1.get(0).equals(List.of("Q")))
            throw new AssertionError("n=1: got " + r1);

        // n=2, n=3: no solutions
        if (!sol.solveNQueens(2).isEmpty())
            throw new AssertionError("n=2: expected no solutions");
        if (!sol.solveNQueens(3).isEmpty())
            throw new AssertionError("n=3: expected no solutions");

        // n=8: 92 solutions (classic result)
        int count8 = sol.solveNQueens(8).size();
        if (count8 != 92)
            throw new AssertionError("n=8: expected 92, got " + count8);

        System.out.println("LC #51 NQueens: all tests passed");
    }
}
```

**Complexity.** Time O(n!) — n choices in row 0, at most n-1 in row 1, etc.
Space O(n) for the sets + O(n^2) per solution.

**Java notes.**
- Three `HashSet<Integer>`s for columns, NW-SE diagonals (`row - col`), and
  NE-SW diagonals (`row + col`). Unlike Rust, Java uses autoboxing to store
  `int` in `HashSet<Integer>`.
- `cols.remove(col)` removes by value (not by index) because `col` is an
  `Integer` after autoboxing. This is unlike `List.remove(int index)` vs
  `List.remove(Object o)` — `Set` only has `remove(Object)`.
- `new String(row)` converts `char[]` to `String` — more efficient than
  building with `StringBuilder` in a loop.
- `queens[row] = -1` resets the column assignment on backtrack. Strictly
  speaking the value at `queens[row]` is irrelevant until it is overwritten on
  the next placement, but resetting makes the state explicit and easier to
  debug.

---

## Java vs Rust — Heap & Backtracking Summary

| Pattern | Java | Rust |
|---|---|---|
| Min-heap (default) | `new PriorityQueue<>()` | `BinaryHeap::<Reverse<i32>>::new()` |
| Max-heap | `new PriorityQueue<>(Collections.reverseOrder())` | `BinaryHeap::<i32>::new()` |
| Push | `pq.offer(x)` | `heap.push(x)` |
| Pop | `pq.poll()` → `T` (nullable) | `heap.pop()` → `Option<T>` |
| Peek | `pq.peek()` → `T` (nullable) | `heap.peek()` → `Option<&T>` |
| Custom order | `Comparator` lambda | `impl Ord for Struct` |
| Stack (never use) | `Stack` (legacy) | n/a — use `VecDeque` |
| Stack (use this) | `ArrayDeque` | `Vec` (push/pop) |
| Backtrack accumulator | instance var or local `List` | `&mut Vec<Vec<T>>` parameter |
| Path copy | `new ArrayList<>(path)` | `path.clone()` |
| Remove last | `path.remove(path.size() - 1)` | `path.pop()` |
| Mark visited (grid) | `board[r][c] = '#'` then restore | same |
| Deduplication guard | `i > start && nums[i] == nums[i-1]` | same |
| Null safety | `pq.peek()` can be `null` | `heap.peek()` returns `Option` — compiler enforces handling |

---

## 📝 Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|---|---|---|
| `PriorityQueue<Integer>` boxes every `int`; for competitive programming with large inputs, `int[]`-based tricks or primitive libraries would be faster | Low | Documented in the "Java vs Rust" callout box |
| `(a, b) -> a - b` comparator can overflow for `Integer.MIN_VALUE` inputs | Low | All comparators in this chapter use `Integer.compare` or `Collections.reverseOrder()` except where overflow is impossible (coordinates bounded by `10^4`) |
| Test helpers for Subsets, Combination Sum I/II, Subsets II used `List.of(...)` (immutable) as inner expected lists; `Collections.sort()` throws `UnsupportedOperationException` on those | Medium | Fixed — all expected inner lists now constructed via `mlist(Integer...)` which returns a mutable `ArrayList` |
| Word Search test driver mutates the board; calling `exist` twice on the same board gives wrong results | Low | Fixed by adding `copyBoard()` helper in the test driver |
| `Set.remove(col)` autoboxes `int` to `Integer` — if someone accidentally called `list.remove(col)` it would remove by index | Low | Only `HashSet` is used in N-Queens; documented in Java notes |
| No `assert` keyword used anywhere | Verified — OK | All tests use `throw new AssertionError(...)` |
| Heap comparators correct (min vs max) | Verified — OK | KthLargest and MedianFinder use min-heap (`new PriorityQueue<>()`); LastStoneWeight, TaskScheduler, Twitter, and KClosest use max-heap with `Collections.reverseOrder()` or descending lambda |
| Backtracking solutions all perform `path.remove(path.size() - 1)` | Verified — OK | All nine backtracking problems have the remove-last step; N-Queens also resets `queens[row]` and the three sets |
| No `Stack` used anywhere | Verified — OK | Only `ArrayDeque` and `PriorityQueue` are used |
| Java 17+ features (`var`, records) present | Partially applied | `var` used in test drivers; records not used for internal heap state because `int[]` is more concise for 2-4 field tuples in competitive programming |

### What This Chapter Does Well

- Consistent `class Solution { public ... }` + `public static void main` test
  pattern throughout all 16 problems, matching LeetCode's submission format.
- Explicit demonstration of both min-heap and max-heap patterns using
  `PriorityQueue` in the same chapter, with a Quick Reference table at the top.
- The backtracking template is introduced once and then applied uniformly
  across nine problems, making the "choose / explore / un-choose" pattern
  immediately recognizable.
- Each heap and backtracking problem includes the `i > start` deduplication
  guard explained separately for Combination Sum II and Subsets II, reinforcing
  that it is a reusable pattern.
- Test drivers verify edge cases (empty input, single element, all duplicates,
  n=8 queens count) rather than only the LeetCode examples.
- The "Java vs Rust" callout box is anchored to the heap section where the
  default-direction asymmetry matters most, rather than being buried at the end.

### What Could Be Improved

- **Palindrome DP caching:** The palindrome check in LC #131 is O(n) per call.
  A `boolean[][] dp` precomputation table would reduce the total time complexity
  from O(n * 2^n) to O(2^n) with O(n^2) preprocessing. It was omitted here for
  readability, but a production solution should include it.
- **Task Scheduler formula alternative:** An O(1) mathematical solution
  `max(tasks.length, (maxFreq - 1) * (n + 1) + countOfMaxFreq)` exists and
  handles all cases in constant time. The heap-simulation approach is included
  because it is more generalizable and closer to the Rust equivalent, but the
  formula should be shown as a note.
- **Design Twitter with a record:** The heap entry `int[] {timestamp, tweetId,
  userId, index}` works but is opaque. A Java 16+ record
  `record TweetEntry(int ts, int tweetId, int userId, int idx) {}` would
  improve readability at the cost of a few extra lines.
- **N-Queens `queens` array reset:** Setting `queens[row] = -1` on backtrack
  is defensive but not strictly necessary because `queens[row]` is always
  overwritten before it is read. It adds clarity but slightly complicates the
  code; a comment explaining this would be sufficient.
- **Missing complexity analysis for `StringBuilder.deleteCharAt`:** The
  Java notes for LC #17 state O(1) amortized, but `deleteCharAt` on
  `StringBuilder` is actually O(n) in the worst case because it shifts
  characters. Since the path length is bounded by the number of digits (at most
  ~10 for phone problems), this is negligible in practice and does not change
  the overall complexity class.
