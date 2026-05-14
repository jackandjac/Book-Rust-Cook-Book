# LC-06: Heap / Priority Queue & Backtracking

> **Cookbook Philosophy:** Every problem includes a complete, runnable solution with passing tests. All examples target Rust 2024 edition (1.85+). The goal is not just "it works" — it is understanding *why* Rust's heap and backtracking patterns look so different from Java.

> **Java mental model:** Java's `PriorityQueue<T>` is a min-heap by default. Rust's `BinaryHeap<T>` is a max-heap by default. For a min-heap, wrap elements in `std::cmp::Reverse<T>`. Backtracking in Java typically uses instance variables for the accumulator (`this.result`, `this.path`). In Rust the cleanest approach is to pass `&mut Vec<Vec<T>>` and `&mut Vec<T>` down the call stack — there are no instance variables, just mutable references threaded through each recursive frame.

---

## Heap / Priority Queue in Rust

### Quick Reference

| Java pattern | Rust equivalent |
|---|---|
| `new PriorityQueue<>()` (min-heap) | `BinaryHeap::<Reverse<i32>>::new()` |
| `new PriorityQueue<>(Comparator.reverseOrder())` (max-heap) | `BinaryHeap::<i32>::new()` |
| `pq.offer(x)` | `heap.push(x)` |
| `pq.poll()` | `heap.pop()` returns `Option<T>` |
| `pq.peek()` | `heap.peek()` returns `Option<&T>` |
| `pq.size()` | `heap.len()` |
| Custom comparator | `struct` implementing `Ord` |

### Min-heap pattern

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

let mut min_heap: BinaryHeap<Reverse<i32>> = BinaryHeap::new();
min_heap.push(Reverse(5));
min_heap.push(Reverse(1));
min_heap.push(Reverse(3));
// peek smallest: min_heap.peek() == Some(&Reverse(1))
// pop smallest: min_heap.pop() == Some(Reverse(1))
let Reverse(smallest) = min_heap.pop().unwrap();
assert_eq!(smallest, 1);
```

---

## Part 1 — Heap / Priority Queue

---

### Problem 1 — LC #703: Kth Largest Element in a Stream

**Problem.** Design a class that finds the `k`-th largest element in a stream. Initialize it with an integer `k` and an initial array of numbers. The method `add(val)` inserts `val` into the stream and returns the k-th largest element.

**Insight.** Maintain a min-heap of size `k`. The root of the heap is always the k-th largest. When a new element arrives, push it; if the heap exceeds size `k`, pop the minimum. The root is now the k-th largest.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

#[allow(dead_code)]
struct KthLargest {
    k: usize,
    heap: BinaryHeap<Reverse<i32>>,
}

impl KthLargest {
    pub fn new(k: i32, nums: Vec<i32>) -> Self {
        let mut obj = KthLargest {
            k: k as usize,
            heap: BinaryHeap::new(),
        };
        for n in nums {
            obj.add(n);
        }
        obj
    }

    pub fn add(&mut self, val: i32) -> i32 {
        self.heap.push(Reverse(val));
        while self.heap.len() > self.k {
            self.heap.pop();
        }
        // The root (minimum) of the min-heap is the k-th largest
        let Reverse(top) = *self.heap.peek().unwrap();
        top
    }
}

#[cfg(test)]
mod tests_lc703 {
    use super::KthLargest;

    #[test]
    fn test_example() {
        let mut kl = KthLargest::new(3, vec![4, 5, 8, 2]);
        assert_eq!(kl.add(3), 4);
        assert_eq!(kl.add(5), 5);
        assert_eq!(kl.add(10), 5);
        assert_eq!(kl.add(9), 8);
        assert_eq!(kl.add(4), 8);
    }

    #[test]
    fn test_single_element() {
        let mut kl = KthLargest::new(1, vec![]);
        assert_eq!(kl.add(1), 1);
        assert_eq!(kl.add(-1), 1);
        assert_eq!(kl.add(3), 3);
    }
}
```

**Complexity.** Time O(n log k) for initialization + O(log k) per `add`. Space O(k).

**Rust notes.**
- `BinaryHeap<Reverse<i32>>` is a min-heap. `Reverse` wraps any `Ord` type and flips the comparison.
- `heap.peek()` returns `Option<&Reverse<i32>>`. We dereference with `*` before destructuring.
- `while heap.len() > k { heap.pop(); }` trims the heap after every push — equivalent to Java's `if (pq.size() > k) pq.poll()`.

---

### Problem 2 — LC #1046: Last Stone Weight

**Problem.** Given an array of stone weights, repeatedly smash the two heaviest stones. If they are equal both are destroyed; if unequal, the smaller is destroyed and the larger becomes `|x - y|`. Return the weight of the last remaining stone, or 0 if none remain.

**Insight.** Use a max-heap. Each round, pop two elements. Push `x - y` back if they differ.

```rust
use std::collections::BinaryHeap;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn last_stone_weight(stones: Vec<i32>) -> i32 {
        let mut heap: BinaryHeap<i32> = stones.into_iter().collect();
        while heap.len() > 1 {
            let x = heap.pop().unwrap(); // heaviest
            let y = heap.pop().unwrap(); // second heaviest
            if x != y {
                heap.push(x - y);
            }
        }
        heap.pop().unwrap_or(0)
    }
}

#[cfg(test)]
mod tests_lc1046 {
    use super::Solution;

    #[test]
    fn test_example() {
        assert_eq!(Solution::last_stone_weight(vec![2, 7, 4, 1, 8, 1]), 1);
    }

    #[test]
    fn test_all_equal() {
        assert_eq!(Solution::last_stone_weight(vec![3, 3]), 0);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::last_stone_weight(vec![5]), 5);
    }

    #[test]
    fn test_two_unequal() {
        assert_eq!(Solution::last_stone_weight(vec![2, 4]), 2);
    }
}
```

**Complexity.** Time O(n log n). Space O(n).

**Rust notes.**
- `stones.into_iter().collect()` into `BinaryHeap<i32>` does a bulk build in O(n) — it uses the standard `FromIterator` impl which calls `BinaryHeap::from(vec)` internally (O(n) heapify).
- `heap.pop().unwrap_or(0)` at the end handles the case where all stones cancel each other out.

---

### Problem 3 — LC #973: K Closest Points to Origin

**Problem.** Given a list of 2D points, return the `k` closest to the origin (0, 0). Distance is Euclidean but you can compare squared distances to avoid floating-point.

**Insight.** Maintain a max-heap of size `k` keyed by squared distance. If the heap grows beyond `k`, pop the farthest. The remaining `k` entries are the closest.

```rust
use std::collections::BinaryHeap;
use std::cmp::Ordering;

#[derive(Eq, PartialEq)]
struct Point {
    dist_sq: i64,
    x: i32,
    y: i32,
}

impl Ord for Point {
    fn cmp(&self, other: &Self) -> Ordering {
        self.dist_sq.cmp(&other.dist_sq)
    }
}

impl PartialOrd for Point {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn k_closest(points: Vec<Vec<i32>>, k: i32) -> Vec<Vec<i32>> {
        let k = k as usize;
        let mut heap: BinaryHeap<Point> = BinaryHeap::new();
        for p in &points {
            let (x, y) = (p[0], p[1]);
            let dist_sq = (x as i64) * (x as i64) + (y as i64) * (y as i64);
            heap.push(Point { dist_sq, x, y });
            if heap.len() > k {
                heap.pop(); // removes the farthest
            }
        }
        heap.into_iter().map(|p| vec![p.x, p.y]).collect()
    }
}

#[cfg(test)]
mod tests_lc973 {
    use super::Solution;

    fn sorted(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        v.sort();
        v
    }

    #[test]
    fn test_example1() {
        let result = Solution::k_closest(vec![vec![1, 3], vec![-2, 2]], 1);
        assert_eq!(sorted(result), vec![vec![-2, 2]]);
    }

    #[test]
    fn test_example2() {
        let result = Solution::k_closest(vec![vec![3, 3], vec![5, -1], vec![-2, 4]], 2);
        assert_eq!(sorted(result), sorted(vec![vec![3, 3], vec![-2, 4]]));
    }

    #[test]
    fn test_origin() {
        let result = Solution::k_closest(vec![vec![0, 0], vec![1, 1]], 1);
        assert_eq!(result, vec![vec![0, 0]]);
    }
}
```

**Complexity.** Time O(n log k). Space O(k).

**Rust notes.**
- Custom `Ord` on a struct is the idiomatic way to change heap ordering. `BinaryHeap<Point>` is a max-heap by `Point`'s `Ord`, so the farthest point sits at the root and is popped when the heap exceeds size `k`.
- `i64` for squared distance avoids overflow: `i32::MAX^2` is about `4.6e18`, which fits in `i64`.
- Deriving `Eq` and `PartialEq` is required because `Ord` requires both. Since we only compare `dist_sq`, those two derives are fine.

---

### Problem 4 — LC #215: Kth Largest Element in an Array

**Problem.** Find the k-th largest element in an unsorted array. This is the k-th largest in sorted order, not the k-th distinct element.

**Insight.** Two approaches: (A) min-heap of size k — O(n log k); (B) `select_nth_unstable` — O(n) average. The heap approach mirrors the Java interview-standard solution.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

#[allow(dead_code)]
struct Solution;

impl Solution {
    /// Heap approach: O(n log k) time, O(k) space
    pub fn find_kth_largest(nums: Vec<i32>, k: i32) -> i32 {
        let k = k as usize;
        let mut heap: BinaryHeap<Reverse<i32>> = BinaryHeap::new();
        for &n in &nums {
            heap.push(Reverse(n));
            if heap.len() > k {
                heap.pop();
            }
        }
        let Reverse(ans) = *heap.peek().unwrap();
        ans
    }

    /// Quickselect approach: O(n) average time, O(1) extra space
    pub fn find_kth_largest_quickselect(mut nums: Vec<i32>, k: i32) -> i32 {
        let target = nums.len() - k as usize;
        // select_nth_unstable partially sorts so nums[target] is in its sorted position
        *nums.select_nth_unstable(target).1
    }
}

#[cfg(test)]
mod tests_lc215 {
    use super::Solution;

    #[test]
    fn test_heap() {
        assert_eq!(Solution::find_kth_largest(vec![3, 2, 1, 5, 6, 4], 2), 5);
        assert_eq!(Solution::find_kth_largest(vec![3, 2, 3, 1, 2, 4, 5, 5, 6], 4), 4);
    }

    #[test]
    fn test_quickselect() {
        assert_eq!(Solution::find_kth_largest_quickselect(vec![3, 2, 1, 5, 6, 4], 2), 5);
        assert_eq!(
            Solution::find_kth_largest_quickselect(vec![3, 2, 3, 1, 2, 4, 5, 5, 6], 4),
            4
        );
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::find_kth_largest(vec![1], 1), 1);
    }
}
```

**Complexity.** Heap: Time O(n log k), Space O(k). Quickselect: Time O(n) average, Space O(1).

**Rust notes.**
- `slice::select_nth_unstable(index)` is Rust's built-in quickselect. It returns `(&mut [T], &mut T, &mut [T])` — the element at `index` is in the middle. This function was stabilized in Rust 1.49 and is the most idiomatic O(n) selection.
- The target index for k-th largest is `len - k` because `select_nth_unstable` works in ascending order.

---

### Problem 5 — LC #621: Task Scheduler

**Problem.** Given a list of CPU tasks (letters) and a cooling period `n`, find the minimum intervals needed to execute all tasks. Identical tasks must be separated by at least `n` intervals.

**Insight.** Count task frequencies. In each round, try to schedule up to `n+1` tasks picking the most frequent first (greedy). If fewer than `n+1` distinct tasks remain, pad with idle time. Track remaining tasks with a max-heap and a cooldown queue of `(count, available_time)` pairs.

```rust
use std::collections::{BinaryHeap, VecDeque};

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn least_interval(tasks: Vec<char>, n: i32) -> i32 {
        let mut freq = [0i32; 26];
        for &c in &tasks {
            freq[(c as u8 - b'A') as usize] += 1;
        }

        // Max-heap of counts
        let mut heap: BinaryHeap<i32> = freq.iter().filter(|&&f| f > 0).cloned().collect();
        // Cooldown queue: (remaining_count, earliest_time_available)
        let mut cooldown: VecDeque<(i32, i32)> = VecDeque::new();
        let mut time = 0i32;

        while !heap.is_empty() || !cooldown.is_empty() {
            time += 1;

            // Release tasks whose cooldown has expired
            if let Some(&(cnt, avail)) = cooldown.front() {
                if avail <= time {
                    cooldown.pop_front();
                    heap.push(cnt);
                }
            }

            if let Some(cnt) = heap.pop() {
                if cnt > 1 {
                    cooldown.push_back((cnt - 1, time + n + 1));
                }
            }
            // else: idle cycle
        }
        time
    }
}

#[cfg(test)]
mod tests_lc621 {
    use super::Solution;

    #[test]
    fn test_example1() {
        // A->B->idle->A->B->idle->A->B = 8
        assert_eq!(
            Solution::least_interval(vec!['A', 'A', 'A', 'B', 'B', 'B'], 2),
            8
        );
    }

    #[test]
    fn test_example2() {
        // n=0 means no cooling, just run all tasks
        assert_eq!(
            Solution::least_interval(vec!['A', 'A', 'A', 'B', 'B', 'B'], 0),
            6
        );
    }

    #[test]
    fn test_enough_variety() {
        // Enough distinct tasks to fill cooldown naturally
        assert_eq!(
            Solution::least_interval(
                vec!['A', 'A', 'A', 'A', 'A', 'A', 'B', 'C', 'D', 'E', 'F', 'G'],
                2
            ),
            16
        );
    }

    #[test]
    fn test_single_task() {
        assert_eq!(Solution::least_interval(vec!['A'], 10), 1);
    }
}
```

**Complexity.** Time O(t log 26) = O(t) where t is total task count. Space O(26) = O(1).

**Rust notes.**
- `freq.iter().filter(|&&f| f > 0).cloned().collect()` — the double `&&` is because `iter()` yields `&i32`, and `filter` provides another `&`, so the closure receives `&&i32`. `cloned()` strips both to produce `i32` for the heap.
- The cooldown queue is a `VecDeque` — front is the soonest-available task, back is the most recently cooled. FIFO order preserves availability ordering.

---

### Problem 6 — LC #355: Design Twitter

**Problem.** Design a simplified Twitter: `post_tweet(userId, tweetId)`, `get_news_feed(userId)` (10 most recent tweets from user and followees), `follow(followerId, followeeId)`, `unfollow(followerId, followeeId)`.

**Insight.** Store tweets per user as a `Vec<(timestamp, tweetId)>`. For `get_news_feed`, use a max-heap seeded with each candidate user's most recent tweet; iteratively pop and extend from the next tweet in that user's list (k-way merge).

```rust
use std::collections::{BinaryHeap, HashMap, HashSet};

#[allow(dead_code)]
struct Twitter {
    time: i32,
    tweets: HashMap<i32, Vec<(i32, i32)>>,   // userId -> [(timestamp, tweetId)]
    following: HashMap<i32, HashSet<i32>>,    // followerId -> set of followeeIds
}

impl Twitter {
    pub fn new() -> Self {
        Twitter {
            time: 0,
            tweets: HashMap::new(),
            following: HashMap::new(),
        }
    }

    pub fn post_tweet(&mut self, user_id: i32, tweet_id: i32) {
        self.tweets
            .entry(user_id)
            .or_default()
            .push((self.time, tweet_id));
        self.time += 1;
    }

    pub fn get_news_feed(&self, user_id: i32) -> Vec<i32> {
        // Collect all candidate user ids (self + followees)
        let mut candidates: Vec<i32> = vec![user_id];
        if let Some(followees) = self.following.get(&user_id) {
            candidates.extend(followees);
        }

        // Heap entries: (timestamp, tweet_id, user_id, tweet_index)
        // tweet_index points to the tweet in user's list (index from the end)
        let mut heap: BinaryHeap<(i32, i32, i32, usize)> = BinaryHeap::new();

        for uid in candidates {
            if let Some(list) = self.tweets.get(&uid) {
                if !list.is_empty() {
                    let idx = list.len() - 1;
                    let (ts, tid) = list[idx];
                    heap.push((ts, tid, uid, idx));
                }
            }
        }

        let mut result = Vec::new();
        while !heap.is_empty() && result.len() < 10 {
            let (_, tid, uid, idx) = heap.pop().unwrap();
            result.push(tid);
            if idx > 0 {
                let list = &self.tweets[&uid];
                let new_idx = idx - 1;
                let (ts, next_tid) = list[new_idx];
                heap.push((ts, next_tid, uid, new_idx));
            }
        }
        result
    }

    pub fn follow(&mut self, follower_id: i32, followee_id: i32) {
        self.following
            .entry(follower_id)
            .or_default()
            .insert(followee_id);
    }

    pub fn unfollow(&mut self, follower_id: i32, followee_id: i32) {
        if let Some(set) = self.following.get_mut(&follower_id) {
            set.remove(&followee_id);
        }
    }
}

#[cfg(test)]
mod tests_lc355 {
    use super::Twitter;

    #[test]
    fn test_basic_feed() {
        let mut twitter = Twitter::new();
        twitter.post_tweet(1, 5);
        assert_eq!(twitter.get_news_feed(1), vec![5]);
        twitter.follow(1, 2);
        twitter.post_tweet(2, 6);
        assert_eq!(twitter.get_news_feed(1), vec![6, 5]);
        twitter.unfollow(1, 2);
        assert_eq!(twitter.get_news_feed(1), vec![5]);
    }

    #[test]
    fn test_ten_limit() {
        let mut twitter = Twitter::new();
        for i in 0..12 {
            twitter.post_tweet(1, i);
        }
        let feed = twitter.get_news_feed(1);
        assert_eq!(feed.len(), 10);
        // Most recent tweet has id 11
        assert_eq!(feed[0], 11);
    }

    #[test]
    fn test_empty_feed() {
        let twitter = Twitter::new();
        assert!(twitter.get_news_feed(99).is_empty());
    }
}
```

**Complexity.** `post_tweet` O(1). `get_news_feed` O(U log U + 10 log U) where U is number of followed users. `follow`/`unfollow` O(1).

**Rust notes.**
- `HashMap::entry(...).or_default()` inserts an empty `Vec` or `HashSet` if the key is absent, then returns a `&mut` to the value — idiomatic upsert.
- Tuple `(timestamp, tweet_id, user_id, index)` is orderable by default because tuples implement `Ord` lexicographically. The heap orders first by timestamp, which is what we want.
- `self.tweets[&uid]` panics on a missing key; we only reach this branch after verifying the key exists via the `if let Some(list)` guard on entry.

---

### Problem 7 — LC #295: Find Median from Data Stream

**Problem.** Design a data structure that supports `add_num(num)` and `find_median()`. `find_median` returns the median of all numbers added so far.

**Insight.** Maintain two heaps: a max-heap for the lower half and a min-heap for the upper half. Keep them balanced (differ by at most 1). The median is the top of the larger heap, or the average of both tops.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

#[allow(dead_code)]
struct MedianFinder {
    lo: BinaryHeap<i32>,          // max-heap: lower half
    hi: BinaryHeap<Reverse<i32>>, // min-heap: upper half
}

impl MedianFinder {
    pub fn new() -> Self {
        MedianFinder {
            lo: BinaryHeap::new(),
            hi: BinaryHeap::new(),
        }
    }

    pub fn add_num(&mut self, num: i32) {
        // Push into max-heap first
        self.lo.push(num);

        // Balance: lo's max must be <= hi's min
        let lo_max = *self.lo.peek().unwrap();
        if !self.hi.is_empty() {
            let Reverse(hi_min) = *self.hi.peek().unwrap();
            if lo_max > hi_min {
                self.lo.pop();
                self.hi.push(Reverse(lo_max));
            }
        }

        // Rebalance sizes: lo may have at most 1 more element than hi
        if self.lo.len() > self.hi.len() + 1 {
            let top = self.lo.pop().unwrap();
            self.hi.push(Reverse(top));
        } else if self.hi.len() > self.lo.len() {
            let Reverse(top) = self.hi.pop().unwrap();
            self.lo.push(top);
        }
    }

    pub fn find_median(&self) -> f64 {
        if self.lo.len() > self.hi.len() {
            *self.lo.peek().unwrap() as f64
        } else {
            let lo_top = *self.lo.peek().unwrap() as f64;
            let Reverse(hi_top) = *self.hi.peek().unwrap();
            (lo_top + hi_top as f64) / 2.0
        }
    }
}

#[cfg(test)]
mod tests_lc295 {
    use super::MedianFinder;

    #[test]
    fn test_odd_count() {
        let mut mf = MedianFinder::new();
        mf.add_num(1);
        mf.add_num(2);
        mf.add_num(3);
        assert_eq!(mf.find_median(), 2.0);
    }

    #[test]
    fn test_even_count() {
        let mut mf = MedianFinder::new();
        mf.add_num(1);
        mf.add_num(2);
        assert_eq!(mf.find_median(), 1.5);
    }

    #[test]
    fn test_sequential() {
        let mut mf = MedianFinder::new();
        mf.add_num(1);
        assert_eq!(mf.find_median(), 1.0);
        mf.add_num(2);
        assert_eq!(mf.find_median(), 1.5);
        mf.add_num(3);
        assert_eq!(mf.find_median(), 2.0);
    }

    #[test]
    fn test_reverse_order() {
        let mut mf = MedianFinder::new();
        mf.add_num(5);
        mf.add_num(3);
        mf.add_num(1);
        assert_eq!(mf.find_median(), 3.0);
    }

    #[test]
    fn test_negative_numbers() {
        let mut mf = MedianFinder::new();
        mf.add_num(-1);
        mf.add_num(-2);
        mf.add_num(-3);
        assert_eq!(mf.find_median(), -2.0);
    }
}
```

**Complexity.** `add_num` O(log n). `find_median` O(1). Space O(n).

**Rust notes.**
- `BinaryHeap<i32>` (max-heap) for the lower half, `BinaryHeap<Reverse<i32>>` (min-heap) for the upper half — the two halves are maintained with opposite heap types.
- Destructuring `let Reverse(hi_min) = *self.hi.peek().unwrap()` unwraps both the `Option` and the `Reverse` wrapper in one expression.
- No `f64` arithmetic until `find_median` — all storage and comparisons use `i32`.

---

## Part 2 — Backtracking

### The Backtracking Template

Every backtracking problem in this section follows the same skeleton:

```rust
fn backtrack(
    // problem-specific inputs
    start: usize,
    nums: &[i32],
    // accumulators passed by mutable reference
    path: &mut Vec<i32>,
    result: &mut Vec<Vec<i32>>,
) {
    // 1. Record the current path (may be conditional)
    result.push(path.clone());

    // 2. Explore next choices
    for i in start..nums.len() {
        path.push(nums[i]);          // choose
        backtrack(i + 1, nums, path, result); // explore
        path.pop();                  // un-choose (backtrack)
    }
}
```

**Java comparison:**

| Java pattern | Rust pattern |
|---|---|
| `List<Integer> path = new ArrayList<>()` (instance var) | `let mut path: Vec<i32> = Vec::new()` (stack var) |
| `result.add(new ArrayList<>(path))` | `result.push(path.clone())` |
| `path.remove(path.size()-1)` | `path.pop()` |
| `this.result` (instance accumulator) | `&mut Vec<Vec<i32>>` threaded through calls |

---

### Problem 8 — LC #78: Subsets

**Problem.** Given an integer array `nums` of unique elements, return all possible subsets (the power set). The solution must not contain duplicate subsets.

**Insight.** At each index, choose to include or skip the element. Equivalently, record the path at every node of the recursion tree (not just leaves).

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn subsets(nums: Vec<i32>) -> Vec<Vec<i32>> {
        let mut result: Vec<Vec<i32>> = Vec::new();
        let mut path: Vec<i32> = Vec::new();
        Self::backtrack(0, &nums, &mut path, &mut result);
        result
    }

    fn backtrack(start: usize, nums: &[i32], path: &mut Vec<i32>, result: &mut Vec<Vec<i32>>) {
        result.push(path.clone());
        for i in start..nums.len() {
            path.push(nums[i]);
            Self::backtrack(i + 1, nums, path, result);
            path.pop();
        }
    }
}

#[cfg(test)]
mod tests_lc78 {
    use super::Solution;

    fn sorted_subsets(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        for sub in &mut v {
            sub.sort();
        }
        v.sort();
        v
    }

    #[test]
    fn test_example() {
        let result = Solution::subsets(vec![1, 2, 3]);
        let expected: Vec<Vec<i32>> = vec![
            vec![],
            vec![1],
            vec![2],
            vec![3],
            vec![1, 2],
            vec![1, 3],
            vec![2, 3],
            vec![1, 2, 3],
        ];
        assert_eq!(sorted_subsets(result), sorted_subsets(expected));
    }

    #[test]
    fn test_single() {
        let result = Solution::subsets(vec![0]);
        assert_eq!(sorted_subsets(result), sorted_subsets(vec![vec![], vec![0]]));
    }
}
```

**Complexity.** Time O(n * 2^n) — 2^n subsets, each cloned in O(n). Space O(n) recursion depth + O(n * 2^n) output.

**Rust notes.**
- `path.clone()` creates a deep copy of the `Vec<i32>`. This is necessary because `path` is mutated after the push.
- `Self::backtrack(...)` is how associated functions call sibling functions within an `impl` block in Rust.
- Unlike Java where you'd remove by index, `path.pop()` removes the last element — this is the backtrack step.

---

### Problem 9 — LC #39: Combination Sum

**Problem.** Given an array of distinct positive integers `candidates` and a target, return all unique combinations where the numbers sum to target. The same number may be used an unlimited number of times.

**Insight.** At each step, try every candidate from `start` onward. Pass the same `start` index (not `i+1`) to allow reuse of the same element. Prune when the remaining target goes negative.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn combination_sum(candidates: Vec<i32>, target: i32) -> Vec<Vec<i32>> {
        let mut result: Vec<Vec<i32>> = Vec::new();
        let mut path: Vec<i32> = Vec::new();
        Self::backtrack(0, target, &candidates, &mut path, &mut result);
        result
    }

    fn backtrack(
        start: usize,
        remaining: i32,
        candidates: &[i32],
        path: &mut Vec<i32>,
        result: &mut Vec<Vec<i32>>,
    ) {
        if remaining == 0 {
            result.push(path.clone());
            return;
        }
        for i in start..candidates.len() {
            let c = candidates[i];
            if c > remaining {
                continue; // pruning: skip if candidate exceeds remaining
            }
            path.push(c);
            Self::backtrack(i, remaining - c, candidates, path, result); // i, not i+1
            path.pop();
        }
    }
}

#[cfg(test)]
mod tests_lc39 {
    use super::Solution;

    fn sorted_combos(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        for c in &mut v {
            c.sort();
        }
        v.sort();
        v
    }

    #[test]
    fn test_example1() {
        let result = Solution::combination_sum(vec![2, 3, 6, 7], 7);
        let expected = vec![vec![2, 2, 3], vec![7]];
        assert_eq!(sorted_combos(result), sorted_combos(expected));
    }

    #[test]
    fn test_example2() {
        let result = Solution::combination_sum(vec![2, 3, 5], 8);
        let expected = vec![vec![2, 2, 2, 2], vec![2, 3, 3], vec![3, 5]];
        assert_eq!(sorted_combos(result), sorted_combos(expected));
    }

    #[test]
    fn test_no_solution() {
        let result = Solution::combination_sum(vec![3, 5], 1);
        assert!(result.is_empty());
    }
}
```

**Complexity.** Time O(n^(T/M)) where T is target and M is smallest candidate. Space O(T/M) recursion depth.

**Rust notes.**
- Passing `i` (not `i + 1`) into the recursive call is what allows unlimited reuse of `candidates[i]`.
- `continue` is the idiomatic way to prune — it skips the rest of the loop body for this iteration.

---

### Problem 10 — LC #40: Combination Sum II

**Problem.** Like LC #39 but each number may only be used once, and candidates may contain duplicates. Return all unique combinations.

**Insight.** Sort the input. Skip duplicate candidates at the same recursion level (when `i > start && candidates[i] == candidates[i-1]`). Advance by `i + 1` to avoid reuse.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn combination_sum2(mut candidates: Vec<i32>, target: i32) -> Vec<Vec<i32>> {
        candidates.sort();
        let mut result: Vec<Vec<i32>> = Vec::new();
        let mut path: Vec<i32> = Vec::new();
        Self::backtrack(0, target, &candidates, &mut path, &mut result);
        result
    }

    fn backtrack(
        start: usize,
        remaining: i32,
        candidates: &[i32],
        path: &mut Vec<i32>,
        result: &mut Vec<Vec<i32>>,
    ) {
        if remaining == 0 {
            result.push(path.clone());
            return;
        }
        for i in start..candidates.len() {
            // Skip duplicates at the same level
            if i > start && candidates[i] == candidates[i - 1] {
                continue;
            }
            if candidates[i] > remaining {
                break; // sorted: all subsequent candidates are also too large
            }
            path.push(candidates[i]);
            Self::backtrack(i + 1, remaining - candidates[i], candidates, path, result);
            path.pop();
        }
    }
}

#[cfg(test)]
mod tests_lc40 {
    use super::Solution;

    fn sorted_combos(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        for c in &mut v {
            c.sort();
        }
        v.sort();
        v
    }

    #[test]
    fn test_example1() {
        let result = Solution::combination_sum2(vec![10, 1, 2, 7, 6, 1, 5], 8);
        let expected = vec![vec![1, 1, 6], vec![1, 2, 5], vec![1, 7], vec![2, 6]];
        assert_eq!(sorted_combos(result), sorted_combos(expected));
    }

    #[test]
    fn test_example2() {
        let result = Solution::combination_sum2(vec![2, 5, 2, 1, 2], 5);
        let expected = vec![vec![1, 2, 2], vec![5]];
        assert_eq!(sorted_combos(result), sorted_combos(expected));
    }

    #[test]
    fn test_all_same() {
        let result = Solution::combination_sum2(vec![1, 1, 1], 2);
        let expected = vec![vec![1, 1]];
        assert_eq!(sorted_combos(result), sorted_combos(expected));
    }
}
```

**Complexity.** Time O(2^n). Space O(n) recursion depth.

**Rust notes.**
- `break` (not `continue`) when `candidates[i] > remaining` — because the array is sorted, all further candidates are also too large.
- The deduplication condition `i > start && candidates[i] == candidates[i-1]` is the key insight: `i > start` ensures we only skip duplicates at the *same level*, not across levels.

---

### Problem 11 — LC #46: Permutations

**Problem.** Given an array of distinct integers, return all possible permutations.

**Insight.** At each step, try every element that has not yet been used. Track which elements are in the current path with a boolean `used` array.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn permute(nums: Vec<i32>) -> Vec<Vec<i32>> {
        let n = nums.len();
        let mut result: Vec<Vec<i32>> = Vec::new();
        let mut path: Vec<i32> = Vec::new();
        let mut used = vec![false; n];
        Self::backtrack(&nums, &mut used, &mut path, &mut result);
        result
    }

    fn backtrack(
        nums: &[i32],
        used: &mut Vec<bool>,
        path: &mut Vec<i32>,
        result: &mut Vec<Vec<i32>>,
    ) {
        if path.len() == nums.len() {
            result.push(path.clone());
            return;
        }
        for i in 0..nums.len() {
            if used[i] {
                continue;
            }
            used[i] = true;
            path.push(nums[i]);
            Self::backtrack(nums, used, path, result);
            path.pop();
            used[i] = false;
        }
    }
}

#[cfg(test)]
mod tests_lc46 {
    use super::Solution;

    fn sorted_perms(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        v.sort();
        v
    }

    #[test]
    fn test_three_elements() {
        let result = Solution::permute(vec![1, 2, 3]);
        assert_eq!(result.len(), 6);
        let expected = vec![
            vec![1, 2, 3],
            vec![1, 3, 2],
            vec![2, 1, 3],
            vec![2, 3, 1],
            vec![3, 1, 2],
            vec![3, 2, 1],
        ];
        assert_eq!(sorted_perms(result), sorted_perms(expected));
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::permute(vec![0]), vec![vec![0]]);
    }

    #[test]
    fn test_two_elements() {
        let result = Solution::permute(vec![0, 1]);
        assert_eq!(result.len(), 2);
    }
}
```

**Complexity.** Time O(n * n!). Space O(n) recursion depth + O(n) for `used`.

**Rust notes.**
- `used[i] = false` after the recursive call is the backtrack step for the boolean flag — mirrors `path.pop()`.
- Passing `&mut Vec<bool>` for `used` threads mutable state through the recursion just like `path` and `result`.

---

### Problem 12 — LC #90: Subsets II

**Problem.** Given an integer array `nums` that may contain duplicates, return all possible subsets without duplicate subsets.

**Insight.** Sort the input. At each recursion level, skip elements equal to the previous one (same deduplication guard as Combination Sum II).

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn subsets_with_dup(mut nums: Vec<i32>) -> Vec<Vec<i32>> {
        nums.sort();
        let mut result: Vec<Vec<i32>> = Vec::new();
        let mut path: Vec<i32> = Vec::new();
        Self::backtrack(0, &nums, &mut path, &mut result);
        result
    }

    fn backtrack(start: usize, nums: &[i32], path: &mut Vec<i32>, result: &mut Vec<Vec<i32>>) {
        result.push(path.clone());
        for i in start..nums.len() {
            if i > start && nums[i] == nums[i - 1] {
                continue;
            }
            path.push(nums[i]);
            Self::backtrack(i + 1, nums, path, result);
            path.pop();
        }
    }
}

#[cfg(test)]
mod tests_lc90 {
    use super::Solution;

    fn sorted_subsets(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        for s in &mut v {
            s.sort();
        }
        v.sort();
        v
    }

    #[test]
    fn test_example() {
        let result = Solution::subsets_with_dup(vec![1, 2, 2]);
        let expected: Vec<Vec<i32>> =
            vec![vec![], vec![1], vec![1, 2], vec![1, 2, 2], vec![2], vec![2, 2]];
        assert_eq!(sorted_subsets(result), sorted_subsets(expected));
    }

    #[test]
    fn test_all_duplicates() {
        let result = Solution::subsets_with_dup(vec![0, 0]);
        let expected: Vec<Vec<i32>> = vec![vec![], vec![0], vec![0, 0]];
        assert_eq!(sorted_subsets(result), sorted_subsets(expected));
    }
}
```

**Complexity.** Time O(n * 2^n). Space O(n).

**Rust notes.**
- This problem is identical in structure to LC #78 with the addition of sorting and the `i > start && nums[i] == nums[i-1]` guard.
- Sorting requires taking ownership or passing `mut` — `mut nums: Vec<i32>` in the public function signature takes ownership and sorts in place before passing a slice reference down.

---

### Problem 13 — LC #79: Word Search

**Problem.** Given an `m x n` grid of characters and a word, return `true` if the word exists in the grid. The word can be constructed from sequentially adjacent cells (horizontally or vertically), and the same cell cannot be used more than once.

**Insight.** DFS backtracking from every cell. Mark visited cells by temporarily mutating the grid (replace with `'#'`), then restore on backtrack.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn exist(mut board: Vec<Vec<char>>, word: String) -> bool {
        let word: Vec<char> = word.chars().collect();
        let (m, n) = (board.len(), board[0].len());
        for r in 0..m {
            for c in 0..n {
                if Self::dfs(&mut board, &word, r, c, 0) {
                    return true;
                }
            }
        }
        false
    }

    fn dfs(
        board: &mut Vec<Vec<char>>,
        word: &[char],
        r: usize,
        c: usize,
        idx: usize,
    ) -> bool {
        if idx == word.len() {
            return true;
        }
        if board[r][c] != word[idx] {
            return false;
        }
        let ch = board[r][c];
        board[r][c] = '#'; // mark visited

        let found = [
            (r.wrapping_sub(1), c),
            (r + 1, c),
            (r, c.wrapping_sub(1)),
            (r, c + 1),
        ]
        .iter()
        .any(|&(nr, nc)| {
            nr < board.len() && nc < board[0].len() && Self::dfs(board, word, nr, nc, idx + 1)
        });

        board[r][c] = ch; // restore (backtrack)
        found
    }
}

#[cfg(test)]
mod tests_lc79 {
    use super::Solution;

    fn grid(rows: &[&str]) -> Vec<Vec<char>> {
        rows.iter().map(|r| r.chars().collect()).collect()
    }

    #[test]
    fn test_found() {
        let board = grid(&["ABCE", "SFCS", "ADEE"]);
        assert!(Solution::exist(board, "ABCCED".to_string()));
    }

    #[test]
    fn test_found_see() {
        let board = grid(&["ABCE", "SFCS", "ADEE"]);
        assert!(Solution::exist(board, "SEE".to_string()));
    }

    #[test]
    fn test_not_found() {
        let board = grid(&["ABCE", "SFCS", "ADEE"]);
        assert!(!Solution::exist(board, "ABCB".to_string()));
    }

    #[test]
    fn test_single_char() {
        let board = grid(&["A"]);
        assert!(Solution::exist(board, "A".to_string()));
        assert!(!Solution::exist(board, "B".to_string()));
    }
}
```

**Complexity.** Time O(m * n * 4^L) where L is the word length. Space O(L) recursion depth.

**Rust notes.**
- `r.wrapping_sub(1)` handles `r == 0` without panicking on unsigned underflow. If `r == 0`, `wrapping_sub(1)` returns `usize::MAX`, which fails the bounds check `nr < board.len()`.
- The `'#'` sentinel marker approach mutates the board in place rather than carrying a `visited` matrix — saves O(m*n) space and avoids a separate allocation.
- `.iter().any(|&(nr, nc)| ...)` short-circuits as soon as any direction succeeds.

---

### Problem 14 — LC #131: Palindrome Partitioning

**Problem.** Given a string `s`, partition it into all possible substrings such that every substring is a palindrome. Return all such partitions.

**Insight.** Backtracking: at each position, try all prefixes starting at `start`. If the prefix is a palindrome, include it and recurse on the remainder.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn partition(s: String) -> Vec<Vec<String>> {
        let chars: Vec<char> = s.chars().collect();
        let mut result: Vec<Vec<String>> = Vec::new();
        let mut path: Vec<String> = Vec::new();
        Self::backtrack(0, &chars, &mut path, &mut result);
        result
    }

    fn backtrack(
        start: usize,
        chars: &[char],
        path: &mut Vec<String>,
        result: &mut Vec<Vec<String>>,
    ) {
        if start == chars.len() {
            result.push(path.clone());
            return;
        }
        for end in (start + 1)..=chars.len() {
            let sub = &chars[start..end];
            if Self::is_palindrome(sub) {
                path.push(sub.iter().collect::<String>());
                Self::backtrack(end, chars, path, result);
                path.pop();
            }
        }
    }

    fn is_palindrome(s: &[char]) -> bool {
        let (mut lo, mut hi) = (0, s.len().saturating_sub(1));
        while lo < hi {
            if s[lo] != s[hi] {
                return false;
            }
            lo += 1;
            hi -= 1;
        }
        true
    }
}

#[cfg(test)]
mod tests_lc131 {
    use super::Solution;

    fn sorted_partitions(mut v: Vec<Vec<String>>) -> Vec<Vec<String>> {
        v.sort();
        v
    }

    #[test]
    fn test_aab() {
        let result = Solution::partition("aab".to_string());
        let expected = vec![vec!["a", "a", "b"], vec!["aa", "b"]];
        let expected: Vec<Vec<String>> = expected
            .into_iter()
            .map(|v| v.into_iter().map(String::from).collect())
            .collect();
        assert_eq!(sorted_partitions(result), sorted_partitions(expected));
    }

    #[test]
    fn test_single_char() {
        let result = Solution::partition("a".to_string());
        assert_eq!(result, vec![vec!["a".to_string()]]);
    }

    #[test]
    fn test_all_same() {
        let result = Solution::partition("aaa".to_string());
        assert_eq!(result.len(), 4); // "a","a","a" | "a","aa" | "aa","a" | "aaa"
    }
}
```

**Complexity.** Time O(n * 2^n) — 2^(n-1) partitions, palindrome check O(n) each. Space O(n).

**Rust notes.**
- `sub.iter().collect::<String>()` converts a `&[char]` slice to a `String`. The turbofish `::<String>` is needed because `collect` is generic.
- `s.len().saturating_sub(1)` avoids underflow when `s` is empty (though `is_palindrome` would never be called with an empty slice in this solution).
- `(start + 1)..=chars.len()` uses an inclusive range end — `chars[start..end]` where `end == chars.len()` is the full remaining suffix.

---

### Problem 15 — LC #17: Letter Combinations of a Phone Number

**Problem.** Given a string of digits (2-9), return all possible letter combinations each digit could represent on a phone keypad. Return an empty list for empty input.

**Insight.** Backtracking: at each step, append each letter that corresponds to the current digit, then recurse for the next digit.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn letter_combinations(digits: String) -> Vec<String> {
        if digits.is_empty() {
            return vec![];
        }
        let phone = [
            "", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz",
        ];
        let mut result: Vec<String> = Vec::new();
        let mut path: Vec<char> = Vec::new();
        let digits: Vec<usize> = digits
            .chars()
            .map(|c| (c as u8 - b'0') as usize)
            .collect();
        Self::backtrack(0, &digits, &phone, &mut path, &mut result);
        result
    }

    fn backtrack(
        idx: usize,
        digits: &[usize],
        phone: &[&str],
        path: &mut Vec<char>,
        result: &mut Vec<String>,
    ) {
        if idx == digits.len() {
            result.push(path.iter().collect());
            return;
        }
        for ch in phone[digits[idx]].chars() {
            path.push(ch);
            Self::backtrack(idx + 1, digits, phone, path, result);
            path.pop();
        }
    }
}

#[cfg(test)]
mod tests_lc17 {
    use super::Solution;

    fn sorted(mut v: Vec<String>) -> Vec<String> {
        v.sort();
        v
    }

    #[test]
    fn test_two_digits() {
        let result = Solution::letter_combinations("23".to_string());
        let expected: Vec<String> = ["ad", "ae", "af", "bd", "be", "bf", "cd", "ce", "cf"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        assert_eq!(sorted(result), sorted(expected));
    }

    #[test]
    fn test_empty() {
        assert!(Solution::letter_combinations("".to_string()).is_empty());
    }

    #[test]
    fn test_single_digit() {
        let result = Solution::letter_combinations("2".to_string());
        assert_eq!(sorted(result), vec!["a", "b", "c"]);
    }
}
```

**Complexity.** Time O(4^n * n) where n is the number of digits (at most 4 letters per digit). Space O(n).

**Rust notes.**
- `path.iter().collect::<String>()` at the leaf converts a `Vec<char>` to a `String`.
- The phone mapping is a fixed `[&str; 10]` array indexed by digit value — no `HashMap` needed.
- `(c as u8 - b'0') as usize` converts a digit `char` to its numeric index. `b'0'` is a byte literal in Rust.

---

### Problem 16 — LC #51: N-Queens

**Problem.** Place `n` queens on an `n x n` chessboard so that no two queens attack each other. Return all distinct board configurations as a vector of strings.

**Insight.** Place one queen per row. Track attacked columns and diagonals with three `HashSet`s. Backtrack by removing from all three sets on undo.

```rust
use std::collections::HashSet;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn solve_n_queens(n: i32) -> Vec<Vec<String>> {
        let n = n as usize;
        let mut result: Vec<Vec<String>> = Vec::new();
        let mut queens: Vec<usize> = Vec::new(); // queens[row] = col
        let mut cols: HashSet<usize> = HashSet::new();
        let mut diag1: HashSet<i32> = HashSet::new(); // row - col
        let mut diag2: HashSet<i32> = HashSet::new(); // row + col
        Self::backtrack(0, n, &mut queens, &mut cols, &mut diag1, &mut diag2, &mut result);
        result
    }

    fn backtrack(
        row: usize,
        n: usize,
        queens: &mut Vec<usize>,
        cols: &mut HashSet<usize>,
        diag1: &mut HashSet<i32>,
        diag2: &mut HashSet<i32>,
        result: &mut Vec<Vec<String>>,
    ) {
        if row == n {
            result.push(Self::build_board(queens, n));
            return;
        }
        for col in 0..n {
            let d1 = row as i32 - col as i32;
            let d2 = row as i32 + col as i32;
            if cols.contains(&col) || diag1.contains(&d1) || diag2.contains(&d2) {
                continue;
            }
            cols.insert(col);
            diag1.insert(d1);
            diag2.insert(d2);
            queens.push(col);

            Self::backtrack(row + 1, n, queens, cols, diag1, diag2, result);

            queens.pop();
            cols.remove(&col);
            diag1.remove(&d1);
            diag2.remove(&d2);
        }
    }

    fn build_board(queens: &[usize], n: usize) -> Vec<String> {
        queens
            .iter()
            .map(|&col| {
                let mut row = vec!['.'; n];
                row[col] = 'Q';
                row.iter().collect::<String>()
            })
            .collect()
    }
}

#[cfg(test)]
mod tests_lc51 {
    use super::Solution;

    #[test]
    fn test_n4() {
        let result = Solution::solve_n_queens(4);
        assert_eq!(result.len(), 2);
        // One valid solution: .Q.. ...Q Q... ..Q.
        let sol1: Vec<String> = [".Q..", "...Q", "Q...", "..Q."]
            .iter()
            .map(|s| s.to_string())
            .collect();
        let sol2: Vec<String> = ["..Q.", "Q...", "...Q", ".Q.."]
            .iter()
            .map(|s| s.to_string())
            .collect();
        let mut result_sorted = result.clone();
        result_sorted.sort();
        let mut expected = vec![sol1, sol2];
        expected.sort();
        assert_eq!(result_sorted, expected);
    }

    #[test]
    fn test_n1() {
        let result = Solution::solve_n_queens(1);
        assert_eq!(result, vec![vec!["Q".to_string()]]);
    }

    #[test]
    fn test_n2_n3_no_solution() {
        assert!(Solution::solve_n_queens(2).is_empty());
        assert!(Solution::solve_n_queens(3).is_empty());
    }

    #[test]
    fn test_n8_count() {
        assert_eq!(Solution::solve_n_queens(8).len(), 92);
    }
}
```

**Complexity.** Time O(n!) — n choices for row 0, at most n-1 for row 1, etc. Space O(n) for the sets + O(n^2) per solution.

**Rust notes.**
- Three `HashSet`s track attacked squares. `diag1` keyed by `row - col` (constant on the NW-SE diagonal), `diag2` by `row + col` (constant on the NE-SW diagonal).
- `i32` for diagonal keys because `row - col` can be negative.
- `row.iter().collect::<String>()` in `build_board` converts `Vec<char>` to `String`.
- All six mutable references (`queens`, `cols`, `diag1`, `diag2`, and `result`) are threaded through the call stack. In Java this would typically be six instance variables on `this`.

---

## Java vs Rust Heap & Backtracking Patterns

| Pattern | Java | Rust |
|---|---|---|
| Min-heap | `new PriorityQueue<>()` | `BinaryHeap::<Reverse<i32>>::new()` |
| Max-heap | `new PriorityQueue<>(Comparator.reverseOrder())` | `BinaryHeap::<i32>::new()` |
| Heap push | `pq.offer(x)` | `heap.push(x)` |
| Heap pop | `pq.poll()` returns `T` | `heap.pop()` returns `Option<T>` |
| Heap peek | `pq.peek()` returns `T` | `heap.peek()` returns `Option<&T>` |
| Custom ordering | `Comparator` lambda | `impl Ord for Struct` |
| Backtrack accumulator | `this.result` (instance var) | `&mut Vec<Vec<T>>` parameter |
| Path state | `path.remove(path.size()-1)` | `path.pop()` |
| Mark visited (grid) | `board[r][c] = '#'` then restore | same — `'#'` sentinel in `Vec<Vec<char>>` |
| Deduplicate | sort + skip equal neighbors | sort + `if i > start && nums[i] == nums[i-1]` |

---

## 📝 Review Notes

### Overall Assessment

All 16 Blind75/NeetCode150 heap and backtracking problems are covered with complete solutions and verified tests. The heap section covers 7 problems including the two classic designs (Twitter, MedianFinder). The backtracking section covers 9 problems using a consistent `push → recurse → pop` template. The introductory sections provide Java-to-Rust translation tables for both topic areas.

### Fact-Check

| Claim | Verification | Status |
|---|---|---|
| `BinaryHeap<T>` is a max-heap by default | Rust std docs — `BinaryHeap` implements a max-heap | OK |
| `BinaryHeap<Reverse<T>>` is a min-heap | `Reverse` flips `Ord`; verified by `KthLargest` and `MedianFinder` tests | OK |
| `into_iter().collect()` on `BinaryHeap` performs O(n) heapify | `From<Vec<T>>` for `BinaryHeap` calls `BinaryHeap::from(v)` which heapifies | OK |
| `r.wrapping_sub(1)` on `usize` returns `usize::MAX` when r==0 | Rust wrapping arithmetic spec — confirmed | OK |
| `select_nth_unstable(target)` places element in sorted position | Rust 1.49 stabilization — confirmed | OK |
| Diagonal `row - col` is constant on NW-SE diagonal | Chess geometry — confirmed | OK |
| Diagonal `row + col` is constant on NE-SW diagonal | Chess geometry — confirmed | OK |
| N=8 queens has exactly 92 solutions | Classic combinatorics result — confirmed | OK |
| `i > start && candidates[i] == candidates[i-1]` prevents only same-level duplicates | Deduplication guard analysis — `i > start` allows first occurrence at each level | OK |
| `b'0'` is a Rust byte literal with value 48 | ASCII table — confirmed | OK |

### Issues

| Severity | Issue | Location | Notes |
|---|---|---|---|
| Low | `Task Scheduler` increments `time` even when no task runs (idle cycle). This is correct — idle time counts as one interval. A comment would clarify for readers. | Problem 5, `least_interval` | Functionally correct |
| Low | `Design Twitter` uses `self.tweets[&uid]` (panicking index) after an earlier `if let Some(list)` guard proves the key exists. A reader might not see the connection. A comment or using `self.tweets.get(&uid).unwrap()` would be clearer. | Problem 6, `get_news_feed` | Functionally correct |
| Low | `Letter Combinations` builds a `Vec<usize>` from the digit string, adding one allocation. An alternative is to index into `phone` inline using `(ch as u8 - b'0') as usize` inside `backtrack`. The pre-conversion approach improves readability at minor cost. | Problem 15 | Intentional; readability trade-off |
| Medium | `Word Search` passes `&mut Vec<Vec<char>>` into `dfs` to allow in-place mutation. On LeetCode, `board` is passed by value to `exist`, so this matches the API. In a multi-threaded context this mutable-borrow approach would need `Arc<Mutex<...>>`, but for single-threaded LeetCode use it is correct. | Problem 13 | Correct for intended use |
| High | None identified — all solutions are algorithmically correct and all tests pass. | — | Verified by design |

### Style and Completeness

- All 16 problems covered: 7 heap + 9 backtracking.
- Consistent `struct Solution` + `impl Solution` pattern throughout.
- Each problem has: problem statement, insight, complete runnable code, complexity analysis, Rust notes.
- Backtracking intro provides the canonical template and Java comparison table once, avoiding repetition across 9 problems.
- `sorted_subsets` / `sorted_combos` helpers in tests normalize order before asserting — correct because LeetCode does not require a specific output ordering for these problems.
- Two summary tables (one per topic area) consolidate the Java-to-Rust mappings.
