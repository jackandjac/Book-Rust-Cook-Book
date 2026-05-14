# Chapter LC-09: Greedy, Intervals, Math & Geometry, Bit Manipulation

> **Chapter goal:** Twenty-nine Blind75/NeetCode150 problems across four domains. Every solution is a complete, runnable snippet with `#[cfg(test)]` tests.
> Target audience: Java developers who know the algorithms and want the Rust idioms.

**Java quick-reference before we start**

| Java pattern | Rust equivalent |
|---|---|
| `x & y`, `x \| y`, `x ^ y`, `~x` | `x & y`, `x \| y`, `x ^ y`, `!x` |
| `x << n`, `x >> n` | `x << n`, `x >> n` |
| `Integer.bitCount(x)` | `x.count_ones()` |
| `Integer.reverse(x)` | `x.reverse_bits()` |
| `Math.pow(x, n)` | custom fast-power (no overflow-safe built-in for integers) |
| `Collections.sort(list, comparator)` | `list.sort_by(\|a, b\| ...)` |
| `list.get(i)` | `list[i]` or `list.get(i)` (returns `Option`) |
| Checked multiply | `x.checked_mul(y)` → `Option<i32>` |
| `Integer.MAX_VALUE` | `i32::MAX` |

---

## Problem Overview

| # | Problem | Difficulty | Domain |
|---|---------|-----------|--------|
| LC 53 | Maximum Subarray | Medium | Greedy |
| LC 55 | Jump Game | Medium | Greedy |
| LC 45 | Jump Game II | Medium | Greedy |
| LC 134 | Gas Station | Medium | Greedy |
| LC 846 | Hand of Straights | Medium | Greedy |
| LC 1899 | Merge Triplets to Form Target | Medium | Greedy |
| LC 763 | Partition Labels | Medium | Greedy |
| LC 678 | Valid Parenthesis String | Medium | Greedy |
| LC 57 | Insert Interval | Medium | Intervals |
| LC 56 | Merge Intervals | Medium | Intervals |
| LC 435 | Non-Overlapping Intervals | Medium | Intervals |
| LC 252 | Meeting Rooms | Easy | Intervals |
| LC 253 | Meeting Rooms II | Medium | Intervals |
| LC 2285 | Minimum Interval to Include Each Query | Hard | Intervals |
| LC 48 | Rotate Image | Medium | Math & Geometry |
| LC 54 | Spiral Matrix | Medium | Math & Geometry |
| LC 73 | Set Matrix Zeroes | Medium | Math & Geometry |
| LC 202 | Happy Number | Easy | Math & Geometry |
| LC 66 | Plus One | Easy | Math & Geometry |
| LC 50 | Pow(x, n) | Medium | Math & Geometry |
| LC 43 | Multiply Strings | Medium | Math & Geometry |
| LC 2013 | Detect Squares | Medium | Math & Geometry |
| LC 136 | Single Number | Easy | Bit Manipulation |
| LC 191 | Number of 1 Bits | Easy | Bit Manipulation |
| LC 338 | Counting Bits | Easy | Bit Manipulation |
| LC 190 | Reverse Bits | Easy | Bit Manipulation |
| LC 268 | Missing Number | Easy | Bit Manipulation |
| LC 371 | Sum of Two Integers | Medium | Bit Manipulation |
| LC 7 | Reverse Integer | Medium | Bit Manipulation |

---

## Part 1 — Greedy

---

### LC #53 — Maximum Subarray

**Problem.** Given an integer array `nums`, find the contiguous subarray with the largest sum and return that sum.

**Insight (Kadane's algorithm).** Maintain a running sum. At each element, decide whether to extend the current subarray or start fresh. If `current_sum + num < num`, drop the prefix and start at `num`. Track the global max throughout.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn max_sub_array(nums: Vec<i32>) -> i32 {
        let mut max_sum = nums[0];
        let mut cur = nums[0];
        for &n in &nums[1..] {
            // Extend or restart
            cur = n.max(cur + n);
            max_sum = max_sum.max(cur);
        }
        max_sum
    }
}

#[cfg(test)]
mod tests_lc53 {
    use super::Solution;

    #[test]
    fn test_mixed() {
        assert_eq!(Solution::max_sub_array(vec![-2, 1, -3, 4, -1, 2, 1, -5, 4]), 6);
    }

    #[test]
    fn test_all_negative() {
        assert_eq!(Solution::max_sub_array(vec![-1]), -1);
        assert_eq!(Solution::max_sub_array(vec![-3, -2, -1]), -1);
    }

    #[test]
    fn test_single_positive() {
        assert_eq!(Solution::max_sub_array(vec![5, 4, -1, 7, 8]), 23);
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Rust notes.**
- `i32::max` is a method on the primitive — `a.max(b)` is cleaner than `std::cmp::max(a, b)` for primitives.
- Indexing `&nums[1..]` borrows a slice starting at index 1. No `subList()` gymnastics.

---

### LC #55 — Jump Game

**Problem.** You are at index 0 in an array where `nums[i]` is the max jump from position `i`. Return `true` if you can reach the last index.

**Insight.** Track the furthest reachable index. Iterate left to right; if current index exceeds the reach, it's unreachable. Update reach at each step.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn can_jump(nums: Vec<i32>) -> bool {
        let mut reach = 0usize;
        for (i, &jump) in nums.iter().enumerate() {
            if i > reach {
                return false;
            }
            reach = reach.max(i + jump as usize);
        }
        true
    }
}

#[cfg(test)]
mod tests_lc55 {
    use super::Solution;

    #[test]
    fn test_reachable() {
        assert!(Solution::can_jump(vec![2, 3, 1, 1, 4]));
    }

    #[test]
    fn test_unreachable() {
        assert!(!Solution::can_jump(vec![3, 2, 1, 0, 4]));
    }

    #[test]
    fn test_single() {
        assert!(Solution::can_jump(vec![0]));
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Rust notes.**
- `nums.iter().enumerate()` yields `(usize, &i32)` pairs — equivalent to a Java index loop but ownership-safe.
- Casting `jump as usize` is explicit; Rust never silently widens signed → unsigned.

---

### LC #45 — Jump Game II

**Problem.** Same setup as Jump Game. Return the **minimum number of jumps** to reach the last index (guaranteed reachable).

**Insight.** Greedy BFS: treat each jump as a "level." Track the current window end and furthest reach. When you hit the window end, increment jumps and advance the window.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn jump(nums: Vec<i32>) -> i32 {
        let n = nums.len();
        let mut jumps = 0;
        let mut cur_end = 0;
        let mut farthest = 0;
        for i in 0..n - 1 {
            farthest = farthest.max(i + nums[i] as usize);
            if i == cur_end {
                jumps += 1;
                cur_end = farthest;
            }
        }
        jumps
    }
}

#[cfg(test)]
mod tests_lc45 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(Solution::jump(vec![2, 3, 1, 1, 4]), 2);
    }

    #[test]
    fn test_greedy() {
        assert_eq!(Solution::jump(vec![2, 3, 0, 1, 4]), 2);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::jump(vec![0]), 0);
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Rust notes.**
- `0..n - 1` is a half-open range, equivalent to `for (int i = 0; i < n - 1; i++)`. We stop one early to avoid overshooting.

---

### LC #134 — Gas Station

**Problem.** Given `gas[i]` (gas available) and `cost[i]` (gas to reach next station), find the starting station index for a complete circuit, or -1 if none exists.

**Insight.** If total gas >= total cost, a solution exists. Greedily pick the start: iterate, accumulate `tank`. When `tank < 0`, reset start to next station and reset tank. The candidate at the end is the answer.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn can_complete_circuit(gas: Vec<i32>, cost: Vec<i32>) -> i32 {
        let (mut total, mut tank, mut start) = (0, 0, 0);
        for i in 0..gas.len() {
            let diff = gas[i] - cost[i];
            total += diff;
            tank += diff;
            if tank < 0 {
                start = i + 1;
                tank = 0;
            }
        }
        if total < 0 { -1 } else { start as i32 }
    }
}

#[cfg(test)]
mod tests_lc134 {
    use super::Solution;

    #[test]
    fn test_valid() {
        assert_eq!(Solution::can_complete_circuit(vec![1, 2, 3, 4, 5], vec![3, 4, 5, 1, 2]), 3);
    }

    #[test]
    fn test_no_solution() {
        assert_eq!(Solution::can_complete_circuit(vec![2, 3, 4], vec![3, 4, 3]), -1);
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Rust notes.**
- Tuple destructuring in `let (mut total, mut tank, mut start) = (0, 0, 0)` initializes multiple `mut` variables cleanly.

---

### LC #846 — Hand of Straights

**Problem.** Given a hand of cards and group size `group_size`, determine if all cards can be arranged into groups of consecutive values.

**Insight.** Count frequencies. Process keys in sorted order. For each key with count > 0, consume `group_size` consecutive keys. If any key is missing, return false.

```rust
#[allow(dead_code)]
struct Solution;

use std::collections::BTreeMap;

impl Solution {
    pub fn is_n_straight_hand(hand: Vec<i32>, group_size: i32) -> bool {
        if hand.len() % group_size as usize != 0 {
            return false;
        }
        let mut count: BTreeMap<i32, i32> = BTreeMap::new();
        for card in hand {
            *count.entry(card).or_insert(0) += 1;
        }
        // BTreeMap iterates in sorted key order
        let keys: Vec<i32> = count.keys().cloned().collect();
        for key in keys {
            let freq = *count.get(&key).unwrap_or(&0);
            if freq == 0 {
                continue;
            }
            for offset in 0..group_size {
                let entry = count.entry(key + offset).or_insert(0);
                if *entry < freq {
                    return false;
                }
                *entry -= freq;
            }
        }
        true
    }
}

#[cfg(test)]
mod tests_lc846 {
    use super::Solution;

    #[test]
    fn test_valid_hand() {
        assert!(Solution::is_n_straight_hand(vec![1, 2, 3, 6, 2, 3, 4, 7, 8], 3));
    }

    #[test]
    fn test_invalid_hand() {
        assert!(!Solution::is_n_straight_hand(vec![1, 2, 3, 4, 5], 4));
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Rust notes.**
- `BTreeMap` keeps keys sorted — no explicit sort step needed, unlike Java's `TreeMap` sorting trick.
- `count.entry(key).or_insert(0)` is the idiomatic frequency-count pattern.

---

### LC #1899 — Merge Triplets to Form Target Triplet

**Problem.** Given a list of triplets and a target triplet, determine if you can select a subset of triplets and take the element-wise max to equal the target.

**Insight.** Ignore triplets containing any value exceeding the target (they would corrupt the result). Among the remaining, check if the element-wise max equals the target.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn merge_triplets(triplets: Vec<Vec<i32>>, target: Vec<i32>) -> bool {
        let (ta, tb, tc) = (target[0], target[1], target[2]);
        let (mut a, mut b, mut c) = (0, 0, 0);
        for t in &triplets {
            if t[0] > ta || t[1] > tb || t[2] > tc {
                continue;
            }
            a = a.max(t[0]);
            b = b.max(t[1]);
            c = c.max(t[2]);
        }
        a == ta && b == tb && c == tc
    }
}

#[cfg(test)]
mod tests_lc1899 {
    use super::Solution;

    #[test]
    fn test_possible() {
        assert!(Solution::merge_triplets(
            vec![vec![2,5,3], vec![1,8,4], vec![1,7,5]],
            vec![2,7,5]
        ));
    }

    #[test]
    fn test_impossible() {
        assert!(!Solution::merge_triplets(
            vec![vec![3,4,5], vec![4,5,6]],
            vec![3,2,5]
        ));
    }
}
```

**Complexity.** Time O(n), Space O(1).

---

### LC #763 — Partition Labels

**Problem.** Partition string `s` into as many parts as possible such that each letter appears in at most one part. Return the sizes of those parts.

**Insight.** Record the last occurrence of each character. Iterate through the string: the end of the current partition is the max last-occurrence seen so far. When `i == end`, a partition boundary is found.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn partition_labels(s: String) -> Vec<i32> {
        let bytes = s.as_bytes();
        let mut last = [0usize; 26];
        for (i, &b) in bytes.iter().enumerate() {
            last[(b - b'a') as usize] = i;
        }
        let mut result = Vec::new();
        let (mut start, mut end) = (0, 0);
        for (i, &b) in bytes.iter().enumerate() {
            end = end.max(last[(b - b'a') as usize]);
            if i == end {
                result.push((end - start + 1) as i32);
                start = i + 1;
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_lc763 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::partition_labels("ababcbacadefegdehijhklij".to_string()),
            vec![9, 7, 8]
        );
    }

    #[test]
    fn test_single_chars() {
        assert_eq!(Solution::partition_labels("eccbbbbdec".to_string()), vec![10]);
    }
}
```

**Complexity.** Time O(n), Space O(1) (26-element fixed array).

**Rust notes.**
- `b'a'` is a byte literal — equivalent to `(int)'a'` in Java but typed as `u8`.
- A fixed `[0usize; 26]` avoids `HashMap` overhead for ASCII problems.

---

### LC #678 — Valid Parenthesis String

**Problem.** Given a string with `'('`, `')'`, and `'*'` (wildcard: empty/`(`/`)`), return `true` if the string can be valid.

**Insight.** Track the range `[lo, hi]` of possible open-parenthesis counts. `'('` increments both, `')'` decrements both, `'*'` widens the range. If `hi < 0` at any point it's invalid. At the end, `lo == 0` means balance is achievable.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn check_valid_string(s: String) -> bool {
        let (mut lo, mut hi) = (0i32, 0i32);
        for ch in s.chars() {
            match ch {
                '(' => { lo += 1; hi += 1; }
                ')' => { lo -= 1; hi -= 1; }
                '*' => { lo -= 1; hi += 1; }
                _ => {}
            }
            if hi < 0 { return false; }
            lo = lo.max(0); // lo cannot go negative
        }
        lo == 0
    }
}

#[cfg(test)]
mod tests_lc678 {
    use super::Solution;

    #[test]
    fn test_valid() {
        assert!(Solution::check_valid_string("(*))".to_string()));
        assert!(Solution::check_valid_string("(*".to_string()));
        assert!(Solution::check_valid_string("()".to_string()));
    }

    #[test]
    fn test_invalid() {
        assert!(!Solution::check_valid_string(")".to_string()));
    }
}
```

**Complexity.** Time O(n), Space O(1).

---

## Part 2 — Intervals

---

### LC #57 — Insert Interval

**Problem.** Given a sorted non-overlapping list of intervals and a new interval, insert it (merging overlaps) and return the updated list.

**Insight.** Three phases: collect intervals that end before the new one starts; merge all overlapping intervals; collect the rest.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn insert(intervals: Vec<Vec<i32>>, new_interval: Vec<i32>) -> Vec<Vec<i32>> {
        let mut result: Vec<Vec<i32>> = Vec::new();
        let mut i = 0;
        let n = intervals.len();
        let (mut ns, mut ne) = (new_interval[0], new_interval[1]);

        // Phase 1: add intervals entirely before new_interval
        while i < n && intervals[i][1] < ns {
            result.push(intervals[i].clone());
            i += 1;
        }
        // Phase 2: merge overlapping intervals
        while i < n && intervals[i][0] <= ne {
            ns = ns.min(intervals[i][0]);
            ne = ne.max(intervals[i][1]);
            i += 1;
        }
        result.push(vec![ns, ne]);
        // Phase 3: add remaining intervals
        while i < n {
            result.push(intervals[i].clone());
            i += 1;
        }
        result
    }
}

#[cfg(test)]
mod tests_lc57 {
    use super::Solution;

    #[test]
    fn test_overlap_merge() {
        assert_eq!(
            Solution::insert(vec![vec![1,3], vec![6,9]], vec![2,5]),
            vec![vec![1,5], vec![6,9]]
        );
    }

    #[test]
    fn test_multi_merge() {
        assert_eq!(
            Solution::insert(vec![vec![1,2], vec![3,5], vec![6,7], vec![8,10], vec![12,16]], vec![4,8]),
            vec![vec![1,2], vec![3,10], vec![12,16]]
        );
    }

    #[test]
    fn test_empty() {
        assert_eq!(Solution::insert(vec![], vec![5,7]), vec![vec![5,7]]);
    }
}
```

**Complexity.** Time O(n), Space O(n).

---

### LC #56 — Merge Intervals

**Problem.** Given a list of intervals, merge all overlapping intervals and return the result.

**Insight.** Sort by start. Iterate; if the current interval's start <= last merged interval's end, merge. Otherwise push as new.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn merge(mut intervals: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        intervals.sort_by_key(|iv| iv[0]);
        let mut merged: Vec<Vec<i32>> = Vec::new();
        for iv in intervals {
            if let Some(last) = merged.last_mut() {
                if iv[0] <= last[1] {
                    last[1] = last[1].max(iv[1]);
                    continue;
                }
            }
            merged.push(iv);
        }
        merged
    }
}

#[cfg(test)]
mod tests_lc56 {
    use super::Solution;

    #[test]
    fn test_overlapping() {
        assert_eq!(
            Solution::merge(vec![vec![1,3], vec![2,6], vec![8,10], vec![15,18]]),
            vec![vec![1,6], vec![8,10], vec![15,18]]
        );
    }

    #[test]
    fn test_touching() {
        assert_eq!(
            Solution::merge(vec![vec![1,4], vec![4,5]]),
            vec![vec![1,5]]
        );
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Rust notes.**
- `merged.last_mut()` returns `Option<&mut Vec<i32>>` — modify in place without re-indexing.
- `sort_by_key` is cleaner than `sort_by` when the key is a simple projection.

---

### LC #435 — Non-Overlapping Intervals

**Problem.** Find the minimum number of intervals to remove to make the rest non-overlapping.

**Insight.** Sort by end time. Greedily keep an interval if it doesn't overlap the last kept one. Count removals.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn erase_overlap_intervals(mut intervals: Vec<Vec<i32>>) -> i32 {
        intervals.sort_by_key(|iv| iv[1]);
        let mut removed = 0;
        let mut prev_end = i32::MIN;
        for iv in &intervals {
            if iv[0] >= prev_end {
                prev_end = iv[1];
            } else {
                removed += 1;
            }
        }
        removed
    }
}

#[cfg(test)]
mod tests_lc435 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::erase_overlap_intervals(vec![vec![1,2], vec![2,3], vec![3,4], vec![1,3]]),
            1
        );
    }

    #[test]
    fn test_all_overlap() {
        assert_eq!(
            Solution::erase_overlap_intervals(vec![vec![1,2], vec![1,2], vec![1,2]]),
            2
        );
    }

    #[test]
    fn test_no_overlap() {
        assert_eq!(
            Solution::erase_overlap_intervals(vec![vec![1,2], vec![2,3]]),
            0
        );
    }
}
```

**Complexity.** Time O(n log n), Space O(1) extra.

---

### LC #252 — Meeting Rooms

**Problem.** Given a list of meeting time intervals, determine if a person can attend all meetings (no overlaps).

**Insight.** Sort by start. Check each adjacent pair for overlap.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn can_attend_meetings(mut intervals: Vec<Vec<i32>>) -> bool {
        intervals.sort_by_key(|iv| iv[0]);
        for w in intervals.windows(2) {
            // w[0] ends after w[1] starts → overlap
            if w[0][1] > w[1][0] {
                return false;
            }
        }
        true
    }
}

#[cfg(test)]
mod tests_lc252 {
    use super::Solution;

    #[test]
    fn test_no_conflict() {
        assert!(Solution::can_attend_meetings(vec![vec![0,30], vec![35,50]]));
        assert!(Solution::can_attend_meetings(vec![]));
    }

    #[test]
    fn test_conflict() {
        assert!(!Solution::can_attend_meetings(vec![vec![0,30], vec![5,10], vec![15,20]]));
    }
}
```

**Complexity.** Time O(n log n), Space O(1) extra.

**Rust notes.**
- `.windows(2)` provides overlapping slices of length 2 — the cleanest way to compare adjacent pairs, no index arithmetic needed.

---

### LC #253 — Meeting Rooms II

**Problem.** Given meeting intervals, return the minimum number of conference rooms required.

**Insight.** Separate start and end times, sort each, and use a two-pointer sweep. When a meeting starts before the earliest-ending meeting finishes, allocate a new room; otherwise reuse the room that just freed up.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn min_meeting_rooms(intervals: Vec<Vec<i32>>) -> i32 {
        let mut starts: Vec<i32> = intervals.iter().map(|iv| iv[0]).collect();
        let mut ends: Vec<i32> = intervals.iter().map(|iv| iv[1]).collect();
        starts.sort_unstable();
        ends.sort_unstable();

        let (mut rooms, mut end_ptr) = (0, 0);
        for s in &starts {
            if *s >= ends[end_ptr] {
                end_ptr += 1; // a room freed up
            } else {
                rooms += 1; // need a new room
            }
        }
        rooms
    }
}

#[cfg(test)]
mod tests_lc253 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::min_meeting_rooms(vec![vec![0,30], vec![5,10], vec![15,20]]),
            2
        );
    }

    #[test]
    fn test_no_overlap() {
        assert_eq!(
            Solution::min_meeting_rooms(vec![vec![7,10], vec![2,4]]),
            1
        );
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

---

### LC #2285 — Minimum Interval to Include Each Query

**Problem.** Given intervals and queries, for each query return the size of the smallest interval containing the query value, or -1 if none.

**Insight.** Sort intervals by start and queries by value. Use a min-heap (by interval size) to track active intervals. For each query, push all intervals whose start <= query, then pop invalid intervals (end < query). The heap top is the answer.

```rust
#[allow(dead_code)]
struct Solution;

use std::collections::BinaryHeap;
use std::cmp::Reverse;

impl Solution {
    pub fn min_interval(mut intervals: Vec<Vec<i32>>, queries: Vec<i32>) -> Vec<i32> {
        intervals.sort_by_key(|iv| iv[0]);

        // Pair each query with its original index so we can restore order
        let mut indexed_queries: Vec<(i32, usize)> = queries.iter().cloned()
            .enumerate()
            .map(|(i, q)| (q, i))
            .collect();
        indexed_queries.sort_by_key(|&(q, _)| q);

        // min-heap of (size, end)
        let mut heap: BinaryHeap<Reverse<(i32, i32)>> = BinaryHeap::new();
        let mut result = vec![-1i32; queries.len()];
        let mut iv_idx = 0;

        for (q, orig_idx) in indexed_queries {
            // Push all intervals starting at or before q
            while iv_idx < intervals.len() && intervals[iv_idx][0] <= q {
                let size = intervals[iv_idx][1] - intervals[iv_idx][0] + 1;
                heap.push(Reverse((size, intervals[iv_idx][1])));
                iv_idx += 1;
            }
            // Pop expired intervals (end < q)
            while let Some(&Reverse((_, end))) = heap.peek() {
                if end < q {
                    heap.pop();
                } else {
                    break;
                }
            }
            if let Some(&Reverse((size, _))) = heap.peek() {
                result[orig_idx] = size;
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_lc2285 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::min_interval(vec![vec![1,4], vec![2,4], vec![3,6], vec![4,4]], vec![2,3,4,5]),
            vec![3, 3, 1, 4]
        );
    }

    #[test]
    fn test_no_match() {
        assert_eq!(
            Solution::min_interval(vec![vec![2,3], vec![2,5], vec![1,8], vec![20,25]], vec![2,19,22]),
            vec![2, -1, 6]
        );
    }
}
```

**Complexity.** Time O((n + q) log n), Space O(n + q).

**Rust notes.**
- `BinaryHeap` is a max-heap. Wrap values in `Reverse(...)` to get min-heap behavior — the direct Rust equivalent of Java's `PriorityQueue` with a reversed comparator.

---

## Part 3 — Math & Geometry

---

### LC #48 — Rotate Image

**Problem.** Rotate an n x n matrix 90 degrees clockwise **in place**.

**Insight.** Two-step: (1) transpose — swap `matrix[i][j]` and `matrix[j][i]`; (2) reverse each row.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn rotate(matrix: &mut Vec<Vec<i32>>) {
        let n = matrix.len();
        // Step 1: transpose
        for i in 0..n {
            for j in i + 1..n {
                let tmp = matrix[i][j];
                matrix[i][j] = matrix[j][i];
                matrix[j][i] = tmp;
            }
        }
        // Step 2: reverse each row
        for row in matrix.iter_mut() {
            row.reverse();
        }
    }
}

#[cfg(test)]
mod tests_lc48 {
    use super::Solution;

    #[test]
    fn test_3x3() {
        let mut m = vec![vec![1,2,3], vec![4,5,6], vec![7,8,9]];
        Solution::rotate(&mut m);
        assert_eq!(m, vec![vec![7,4,1], vec![8,5,2], vec![9,6,3]]);
    }

    #[test]
    fn test_4x4() {
        let mut m = vec![
            vec![5,1,9,11], vec![2,4,8,10], vec![13,3,6,7], vec![15,14,12,16]
        ];
        Solution::rotate(&mut m);
        assert_eq!(m, vec![
            vec![15,13,2,5], vec![14,3,4,1], vec![12,6,8,9], vec![16,7,10,11]
        ]);
    }
}
```

**Complexity.** Time O(n²), Space O(1).

**Rust notes.**
- Two-index in-place swap without a borrow conflict: use a temporary variable `tmp`. Rust's borrow checker disallows `let tmp = &matrix[i][j]` while also writing `matrix[j][i]`, so the copy-to-`tmp` pattern is required for non-`Copy` types (here `i32` is `Copy`, but the pattern is the same).
- `row.reverse()` is an in-place slice method.

---

### LC #54 — Spiral Matrix

**Problem.** Given an m × n matrix, return all elements in spiral (clockwise) order.

**Insight.** Maintain four boundaries: `top`, `bottom`, `left`, `right`. Peel off one layer at a time, shrinking boundaries inward.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn spiral_order(matrix: Vec<Vec<i32>>) -> Vec<i32> {
        let (mut top, mut bottom) = (0i32, matrix.len() as i32 - 1);
        let (mut left, mut right) = (0i32, matrix[0].len() as i32 - 1);
        let mut result = Vec::new();

        while top <= bottom && left <= right {
            for col in left..=right {
                result.push(matrix[top as usize][col as usize]);
            }
            top += 1;
            for row in top..=bottom {
                result.push(matrix[row as usize][right as usize]);
            }
            right -= 1;
            if top <= bottom {
                for col in (left..=right).rev() {
                    result.push(matrix[bottom as usize][col as usize]);
                }
                bottom -= 1;
            }
            if left <= right {
                for row in (top..=bottom).rev() {
                    result.push(matrix[row as usize][left as usize]);
                }
                left += 1;
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_lc54 {
    use super::Solution;

    #[test]
    fn test_3x3() {
        assert_eq!(
            Solution::spiral_order(vec![vec![1,2,3], vec![4,5,6], vec![7,8,9]]),
            vec![1,2,3,6,9,8,7,4,5]
        );
    }

    #[test]
    fn test_3x4() {
        assert_eq!(
            Solution::spiral_order(vec![vec![1,2,3,4], vec![5,6,7,8], vec![9,10,11,12]]),
            vec![1,2,3,4,8,12,11,10,9,5,6,7]
        );
    }
}
```

**Complexity.** Time O(m × n), Space O(1) extra.

---

### LC #73 — Set Matrix Zeroes

**Problem.** If `matrix[i][j] == 0`, set the entire row `i` and column `j` to zero, in place.

**Insight.** Use the first row and first column as markers to avoid extra space. Check whether the first row/column themselves contain a zero before using them as markers.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn set_zeroes(matrix: &mut Vec<Vec<i32>>) {
        let (m, n) = (matrix.len(), matrix[0].len());
        let first_row_zero = matrix[0].iter().any(|&v| v == 0);
        let first_col_zero = matrix.iter().any(|row| row[0] == 0);

        // Use row 0 and col 0 as flags for rows/cols 1..
        for i in 1..m {
            for j in 1..n {
                if matrix[i][j] == 0 {
                    matrix[i][0] = 0;
                    matrix[0][j] = 0;
                }
            }
        }
        for i in 1..m {
            for j in 1..n {
                if matrix[i][0] == 0 || matrix[0][j] == 0 {
                    matrix[i][j] = 0;
                }
            }
        }
        if first_row_zero {
            for j in 0..n { matrix[0][j] = 0; }
        }
        if first_col_zero {
            for i in 0..m { matrix[i][0] = 0; }
        }
    }
}

#[cfg(test)]
mod tests_lc73 {
    use super::Solution;

    #[test]
    fn test_basic() {
        let mut m = vec![vec![1,1,1], vec![1,0,1], vec![1,1,1]];
        Solution::set_zeroes(&mut m);
        assert_eq!(m, vec![vec![1,0,1], vec![0,0,0], vec![1,0,1]]);
    }

    #[test]
    fn test_corner() {
        let mut m = vec![vec![0,1,2,0], vec![3,4,5,2], vec![1,3,1,5]];
        Solution::set_zeroes(&mut m);
        assert_eq!(m, vec![vec![0,0,0,0], vec![0,4,5,0], vec![0,3,1,0]]);
    }
}
```

**Complexity.** Time O(m × n), Space O(1).

---

### LC #202 — Happy Number

**Problem.** A happy number eventually reaches 1 by repeatedly summing the squares of its digits. Return `true` if `n` is happy.

**Insight.** Use Floyd's cycle detection (slow/fast pointers) to detect loops without a HashSet.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    fn next(mut n: i32) -> i32 {
        let mut sum = 0;
        while n > 0 {
            let d = n % 10;
            sum += d * d;
            n /= 10;
        }
        sum
    }

    pub fn is_happy(n: i32) -> bool {
        let (mut slow, mut fast) = (n, Self::next(n));
        while fast != 1 && slow != fast {
            slow = Self::next(slow);
            fast = Self::next(Self::next(fast));
        }
        fast == 1
    }
}

#[cfg(test)]
mod tests_lc202 {
    use super::Solution;

    #[test]
    fn test_happy() {
        assert!(Solution::is_happy(19));
        assert!(Solution::is_happy(1));
    }

    #[test]
    fn test_not_happy() {
        assert!(!Solution::is_happy(2));
    }
}
```

**Complexity.** Time O(log n) per step, O(log n) steps, Space O(1).

---

### LC #66 — Plus One

**Problem.** Given a non-empty array representing a non-negative integer (most significant digit first), increment by one.

**Insight.** Iterate from the right. If a digit is less than 9, increment and return. If 9, set to 0 and carry. If we exit the loop, prepend a 1.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn plus_one(mut digits: Vec<i32>) -> Vec<i32> {
        for d in digits.iter_mut().rev() {
            if *d < 9 {
                *d += 1;
                return digits;
            }
            *d = 0;
        }
        // All digits were 9 → need a leading 1
        digits.insert(0, 1);
        digits
    }
}

#[cfg(test)]
mod tests_lc66 {
    use super::Solution;

    #[test]
    fn test_no_carry() {
        assert_eq!(Solution::plus_one(vec![1, 2, 3]), vec![1, 2, 4]);
    }

    #[test]
    fn test_carry_chain() {
        assert_eq!(Solution::plus_one(vec![9, 9, 9]), vec![1, 0, 0, 0]);
    }

    #[test]
    fn test_single_digit() {
        assert_eq!(Solution::plus_one(vec![9]), vec![1, 0]);
    }
}
```

**Complexity.** Time O(n), Space O(1) extra (O(n) on all-9 carry).

**Rust notes.**
- `iter_mut().rev()` gives mutable references in reverse — modify in place without indexing.
- `digits.insert(0, 1)` shifts the vector right by one; O(n) but only needed on the all-9 case.

---

### LC #50 — Pow(x, n)

**Problem.** Implement `pow(x, n)` for floating-point `x` and integer `n` (including negative `n`).

**Insight.** Fast exponentiation (binary exponentiation): halve the exponent at each step. For negative `n`, compute `pow(1/x, -n)`. Handle `i32::MIN` via `i64` to avoid overflow on negation.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn my_pow(x: f64, n: i32) -> f64 {
        let mut base = x;
        let mut exp = n as i64; // use i64 to handle i32::MIN negation safely
        if exp < 0 {
            base = 1.0 / base;
            exp = -exp;
        }
        let mut result = 1.0f64;
        while exp > 0 {
            if exp % 2 == 1 {
                result *= base;
            }
            base *= base;
            exp /= 2;
        }
        result
    }
}

#[cfg(test)]
mod tests_lc50 {
    use super::Solution;

    #[test]
    fn test_positive_exp() {
        let result = Solution::my_pow(2.0, 10);
        assert!((result - 1024.0).abs() < 1e-9);
    }

    #[test]
    fn test_negative_exp() {
        let result = Solution::my_pow(2.0, -2);
        assert!((result - 0.25).abs() < 1e-9);
    }

    #[test]
    fn test_zero_exp() {
        assert_eq!(Solution::my_pow(5.0, 0), 1.0);
    }

    #[test]
    fn test_min_exp() {
        // Should not panic on i32::MIN
        let _ = Solution::my_pow(1.0, i32::MIN);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- `n as i64` prevents overflow when negating `i32::MIN` (which has no positive counterpart as `i32`).
- No `checked_mul` needed here since `f64` operations don't overflow to panic.

---

### LC #43 — Multiply Strings

**Problem.** Given two non-negative integers `num1` and `num2` represented as strings, return their product as a string. Do not use built-in BigInteger or direct number conversion.

**Insight.** Elementary school multiplication: digits at positions `i` and `j` contribute to positions `i + j` and `i + j + 1` in the result array.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn multiply(num1: String, num2: String) -> String {
        let b1 = num1.as_bytes();
        let b2 = num2.as_bytes();
        let (m, n) = (b1.len(), b2.len());
        let mut pos = vec![0u32; m + n];

        for i in (0..m).rev() {
            for j in (0..n).rev() {
                let mul = ((b1[i] - b'0') as u32) * ((b2[j] - b'0') as u32);
                let (p1, p2) = (i + j, i + j + 1);
                let sum = mul + pos[p2];
                pos[p2] = sum % 10;
                pos[p1] += sum / 10;
            }
        }

        let result: String = pos.iter()
            .skip_while(|&&d| d == 0)
            .map(|&d| (b'0' + d as u8) as char)
            .collect();

        if result.is_empty() { "0".to_string() } else { result }
    }
}

#[cfg(test)]
mod tests_lc43 {
    use super::Solution;

    #[test]
    fn test_small() {
        assert_eq!(Solution::multiply("2".to_string(), "3".to_string()), "6");
    }

    #[test]
    fn test_multi_digit() {
        assert_eq!(Solution::multiply("123".to_string(), "456".to_string()), "56088");
    }

    #[test]
    fn test_zero() {
        assert_eq!(Solution::multiply("0".to_string(), "12345".to_string()), "0");
    }
}
```

**Complexity.** Time O(m × n), Space O(m + n).

---

### LC #2013 — Detect Squares

**Problem.** Design a data structure that: (1) adds points, (2) given a query point, counts the number of axis-aligned squares that can be formed with the query point as one corner.

**Insight.** For query point `(px, py)`: for each point `(x, py)` with the same y-coordinate, attempt to form a square with side `|px - x|`. Check both `(px, py + d)`, `(x, py + d)` and `(px, py - d)`, `(x, py - d)`.

```rust
#[allow(dead_code)]
use std::collections::HashMap;

struct DetectSquares {
    // point -> count
    point_count: HashMap<(i32, i32), i32>,
    // x -> list of y values (with duplicates counted via point_count)
    x_to_ys: HashMap<i32, Vec<i32>>,
}

impl DetectSquares {
    fn new() -> Self {
        DetectSquares {
            point_count: HashMap::new(),
            x_to_ys: HashMap::new(),
        }
    }

    fn add(&mut self, point: Vec<i32>) {
        let (x, y) = (point[0], point[1]);
        *self.point_count.entry((x, y)).or_insert(0) += 1;
        self.x_to_ys.entry(x).or_default().push(y);
    }

    fn count(&self, point: Vec<i32>) -> i32 {
        let (px, py) = (point[0], point[1]);
        let mut ans = 0i32;
        if let Some(ys) = self.x_to_ys.get(&px) {
            for &y in ys {
                if y == py { continue; }
                let d = y - py; // signed side length
                // Check if the other two corners exist
                let cnt_diag = *self.point_count.get(&(px + d, py)).unwrap_or(&0);
                let cnt_same = *self.point_count.get(&(px + d, y)).unwrap_or(&0);
                ans += cnt_diag * cnt_same;
                let cnt_diag2 = *self.point_count.get(&(px - d, py)).unwrap_or(&0);
                let cnt_same2 = *self.point_count.get(&(px - d, y)).unwrap_or(&0);
                ans += cnt_diag2 * cnt_same2;
            }
        }
        ans
    }
}

#[cfg(test)]
mod tests_lc2013 {
    use super::DetectSquares;

    #[test]
    fn test_basic() {
        let mut ds = DetectSquares::new();
        ds.add(vec![3, 10]);
        ds.add(vec![11, 2]);
        ds.add(vec![3, 2]);
        assert_eq!(ds.count(vec![11, 10]), 1);
        assert_eq!(ds.count(vec![14, 8]), 0);
        ds.add(vec![11, 2]);
        assert_eq!(ds.count(vec![11, 10]), 2);
    }
}
```

**Complexity.** Add: O(1). Count: O(n) where n is points on the same x-column.

---

## Part 4 — Bit Manipulation

---

### LC #136 — Single Number

**Problem.** Every element in the array appears exactly twice except one. Find the single element.

**Insight.** XOR all numbers: `a ^ a == 0` and `a ^ 0 == a`. All pairs cancel; the single element remains.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn single_number(nums: Vec<i32>) -> i32 {
        nums.iter().fold(0, |acc, &n| acc ^ n)
    }
}

#[cfg(test)]
mod tests_lc136 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(Solution::single_number(vec![2, 2, 1]), 1);
    }

    #[test]
    fn test_longer() {
        assert_eq!(Solution::single_number(vec![4, 1, 2, 1, 2]), 4);
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Rust notes.**
- `fold(0, |acc, &n| acc ^ n)` — functional XOR reduction. `fold` is Rust's `reduce` with an initial value, equivalent to Java's `IntStream.reduce(0, (a, b) -> a ^ b)`.

---

### LC #191 — Number of 1 Bits

**Problem.** Return the number of `1` bits in the unsigned 32-bit representation of `n`.

**Insight.** Use the built-in `count_ones()` method, or Brian Kernighan's trick: `n &= n - 1` clears the lowest set bit.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn hamming_weight(n: u32) -> i32 {
        n.count_ones() as i32
    }

    // Manual approach with Brian Kernighan's bit trick
    pub fn hamming_weight_manual(mut n: u32) -> i32 {
        let mut count = 0;
        while n != 0 {
            n &= n - 1; // clear lowest set bit
            count += 1;
        }
        count
    }
}

#[cfg(test)]
mod tests_lc191 {
    use super::Solution;

    #[test]
    fn test_built_in() {
        assert_eq!(Solution::hamming_weight(0b00000000000000000000000010110100), 4); // 11 → 3
        assert_eq!(Solution::hamming_weight(u32::MAX), 32);
    }

    #[test]
    fn test_manual() {
        assert_eq!(Solution::hamming_weight_manual(11), 3);
        assert_eq!(Solution::hamming_weight_manual(128), 1);
    }
}
```

**Complexity.** `count_ones`: O(1). Manual: O(k) where k is the number of set bits.

**Rust notes.**
- `count_ones()` is a primitive method in Rust — it maps to a single CPU instruction (`POPCNT`) on modern hardware.
- Java's `Integer.bitCount(n)` is the equivalent.

---

### LC #338 — Counting Bits

**Problem.** Return an array `ans` where `ans[i]` is the number of `1` bits in `i`, for `0 <= i <= n`.

**Insight.** Dynamic programming: `bits[i] = bits[i >> 1] + (i & 1)`. The number of 1-bits in `i` equals the bits in `i` right-shifted by 1, plus the last bit.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn count_bits(n: i32) -> Vec<i32> {
        let n = n as usize;
        let mut dp = vec![0i32; n + 1];
        for i in 1..=n {
            dp[i] = dp[i >> 1] + (i as i32 & 1);
        }
        dp
    }
}

#[cfg(test)]
mod tests_lc338 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(Solution::count_bits(2), vec![0, 1, 1]);
        assert_eq!(Solution::count_bits(5), vec![0, 1, 1, 2, 1, 2]);
    }
}
```

**Complexity.** Time O(n), Space O(n).

---

### LC #190 — Reverse Bits

**Problem.** Reverse the bits of a 32-bit unsigned integer.

**Insight.** Use the built-in `reverse_bits()`, or shift bits out one at a time into the result.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn reverse_bits(x: u32) -> u32 {
        x.reverse_bits()
    }

    // Manual approach
    pub fn reverse_bits_manual(mut x: u32) -> u32 {
        let mut result = 0u32;
        for _ in 0..32 {
            result = (result << 1) | (x & 1);
            x >>= 1;
        }
        result
    }
}

#[cfg(test)]
mod tests_lc190 {
    use super::Solution;

    #[test]
    fn test_built_in() {
        assert_eq!(Solution::reverse_bits(0b00000010100101000001111010011100), 0b00111001011110000010100101000000);
    }

    #[test]
    fn test_manual() {
        assert_eq!(Solution::reverse_bits_manual(43261596), 964176192);
    }
}
```

**Complexity.** `reverse_bits`: O(1). Manual: O(32) = O(1).

**Rust notes.**
- `reverse_bits()` on `u32` is a direct primitive method — no Java equivalent exists without `Integer.reverse()` which operates on signed ints.

---

### LC #268 — Missing Number

**Problem.** Given an array of `n` distinct numbers in range `[0, n]`, return the missing number.

**Insight.** XOR all indices and all values. The missing number is the one that doesn't cancel.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn missing_number(nums: Vec<i32>) -> i32 {
        let n = nums.len() as i32;
        let mut xor = n; // start with n since we XOR indices 0..n-1
        for (i, &v) in nums.iter().enumerate() {
            xor ^= (i as i32) ^ v;
        }
        xor
    }

    // Gauss sum alternative
    pub fn missing_number_sum(nums: Vec<i32>) -> i32 {
        let n = nums.len() as i32;
        let expected = n * (n + 1) / 2;
        let actual: i32 = nums.iter().sum();
        expected - actual
    }
}

#[cfg(test)]
mod tests_lc268 {
    use super::Solution;

    #[test]
    fn test_xor() {
        assert_eq!(Solution::missing_number(vec![3, 0, 1]), 2);
        assert_eq!(Solution::missing_number(vec![0, 1]), 2);
        assert_eq!(Solution::missing_number(vec![9,6,4,2,3,5,7,0,1]), 8);
    }

    #[test]
    fn test_sum() {
        assert_eq!(Solution::missing_number_sum(vec![3, 0, 1]), 2);
    }
}
```

**Complexity.** Time O(n), Space O(1).

---

### LC #371 — Sum of Two Integers

**Problem.** Return the sum of two integers without using `+` or `-`.

**Insight.** Simulate binary addition: XOR computes the sum without carry; AND + left-shift computes the carry. Repeat until carry is zero.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn get_sum(mut a: i32, mut b: i32) -> i32 {
        while b != 0 {
            let carry = (a & b) << 1;
            a ^= b;
            b = carry;
        }
        a
    }
}

#[cfg(test)]
mod tests_lc371 {
    use super::Solution;

    #[test]
    fn test_positive() {
        assert_eq!(Solution::get_sum(1, 2), 3);
        assert_eq!(Solution::get_sum(2, 3), 5);
    }

    #[test]
    fn test_negative() {
        assert_eq!(Solution::get_sum(-1, 1), 0);
        assert_eq!(Solution::get_sum(-3, -2), -5);
    }
}
```

**Complexity.** Time O(1) (at most 32 iterations for 32-bit ints), Space O(1).

**Rust notes.**
- Rust's integer arithmetic wraps in release mode and panics on overflow in debug mode. Since we're doing bitwise operations only (no actual `+`), there is no overflow risk here.
- In Java, bit operations on `int` behave identically.

---

### LC #7 — Reverse Integer

**Problem.** Given a signed 32-bit integer, return the integer with its digits reversed. Return 0 if the reversed integer overflows.

**Insight.** Pop digits with `% 10` and push onto result with `* 10`. Use `checked_mul` and `checked_add` to detect overflow without branching on `i64`.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn reverse(mut x: i32) -> i32 {
        let mut result: i32 = 0;
        while x != 0 {
            let digit = x % 10;
            x /= 10;
            result = match result.checked_mul(10).and_then(|v| v.checked_add(digit)) {
                Some(v) => v,
                None => return 0,
            };
        }
        result
    }
}

#[cfg(test)]
mod tests_lc7 {
    use super::Solution;

    #[test]
    fn test_positive() {
        assert_eq!(Solution::reverse(123), 321);
    }

    #[test]
    fn test_negative() {
        assert_eq!(Solution::reverse(-123), -321);
    }

    #[test]
    fn test_trailing_zero() {
        assert_eq!(Solution::reverse(120), 21);
    }

    #[test]
    fn test_overflow() {
        assert_eq!(Solution::reverse(1534236469), 0);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- `checked_mul` and `checked_add` return `Option<i32>` — `None` on overflow. Chaining with `and_then` lets us handle both overflow cases with one `match`.
- In Java, the standard approach casts to `long` and compares against `Integer.MAX_VALUE`. The `checked_*` approach is more idiomatic in Rust and avoids a wider type.

---

## Review Notes

### Greedy Patterns

| Pattern | Problems | Key Idea |
|---------|----------|----------|
| Running max/min | Maximum Subarray, Jump Game | Extend or reset at each step |
| Window end tracking | Jump Game II | BFS-level greedy with window boundaries |
| Global feasibility + local greed | Gas Station | If total gas >= cost, a valid start exists |
| Sorted frequency map | Hand of Straights | `BTreeMap` gives free sorted iteration |
| Interval shrinking | Partition Labels | Last-occurrence map determines partition boundaries |
| Range tracking | Valid Parenthesis String | Track `[lo, hi]` range instead of exact count |

### Intervals Sorting Convention

Always decide **which endpoint to sort by**:
- Sort by **start**: Insert Interval, Merge Intervals, Meeting Rooms
- Sort by **end**: Non-Overlapping Intervals (maximizes kept intervals by finishing earliest)
- Separate sort starts/ends: Meeting Rooms II (two-pointer sweep)

### Math & Geometry Tricks

| Technique | Problem | Rust tool |
|-----------|---------|-----------|
| Transpose + reverse rows | Rotate Image | `row.reverse()` in-place |
| Four-boundary peel | Spiral Matrix | Signed bounds, check before each direction |
| In-place flagging | Set Matrix Zeroes | First row/column as markers |
| Floyd cycle detection | Happy Number | Pointer-based, O(1) space |
| Binary exponentiation | Pow(x, n) | `i64` for exponent to avoid `i32::MIN` trap |
| Grade-school multiply | Multiply Strings | `pos[i+j]`, `pos[i+j+1]` accumulator |

### Bit Manipulation Cheat Sheet

| Operation | Java | Rust |
|-----------|------|------|
| Count set bits | `Integer.bitCount(n)` | `n.count_ones()` |
| Reverse bits | `Integer.reverse(n)` | `n.reverse_bits()` |
| Clear lowest set bit | `n &= n - 1` | `n &= n - 1` (same) |
| Overflow-safe multiply | cast to `long` | `n.checked_mul(m)` → `Option<i32>` |
| XOR all elements | `IntStream.reduce(0, (a,b)->a^b)` | `iter().fold(0, \|acc, &n\| acc ^ n)` |

### Common Rust Foot-Guns in This Chapter

1. **`BinaryHeap` is a max-heap.** Wrap with `Reverse(...)` for min-heap behavior. Java's `PriorityQueue` defaults to min-heap — the opposite.

2. **Signed vs. unsigned bit operations.** `i32::reverse_bits()` exists but LeetCode's "Reverse Bits" problem uses `u32`. Be explicit about the type — Rust will not silently transmute.

3. **`i32::MIN` negation overflows.** In `Pow(x, n)`, cast `n` to `i64` before negating. `-i32::MIN` as `i32` panics in debug mode.

4. **`Vec::insert(0, v)` is O(n).** In Plus One, this only triggers on the all-9 case, so it's fine. Prefer front-insertion-free algorithms when performance matters.

5. **Range bounds.** `0..n - 1` panics if `n == 0` (because `usize` underflows). Guard with `if n == 0 { return ... }` when the input can be empty.

6. **`iter_mut().rev()` for in-place right-to-left mutation.** There is no `for (int i = n-1; i >= 0; i--)` in idiomatic Rust; use iterator adapters instead.
