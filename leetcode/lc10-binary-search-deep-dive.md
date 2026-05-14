# LC-10: Binary Search — Deep Dive

> **Chapter goal:** Master every binary search variation that appears in LeetCode's Binary Search Study Plan.
> Every snippet is complete and compiles on Rust 1.85+ (2024 edition). Target audience: Java developers who know the
> algorithms and want the Rust idioms.

**Java quick-reference**

| Java pattern | Rust equivalent |
|---|---|
| `lo + (hi - lo) / 2` | `left + (right - left) / 2` (same overflow safety) |
| `while (lo <= hi)` | `while left <= right` (T1) or `while left < right` (T2) |
| `Arrays.binarySearch(arr, key)` | `slice.binary_search(&key)` — returns `Ok(idx)` or `Err(insert_pos)` |
| `Collections.binarySearch` on sorted list | `slice.partition_point(\|x\| *x < target)` |
| Checked cast: `(long) mid * mid` | `mid as i64 * mid as i64` |
| Index arithmetic: `int lo = 0` | Use `i32` for `left`/`right` to allow `-1` sentinels and avoid underflow |

---

## Binary Search Templates

Three templates cover every variation. Choose by what the problem guarantees and what you return.

### Template 1 — Classic: find an exact target

Use when the array has no duplicates (or you want any matching index) and you know when to terminate.

```rust
fn binary_search_t1(nums: &[i32], target: i32) -> i32 {
    let mut left = 0_i32;
    let mut right = nums.len() as i32 - 1;
    while left <= right {
        let mid = left + (right - left) / 2;
        match nums[mid as usize].cmp(&target) {
            std::cmp::Ordering::Equal => return mid,
            std::cmp::Ordering::Less => left = mid + 1,
            std::cmp::Ordering::Greater => right = mid - 1,
        }
    }
    -1 // not found
}
```

**Key invariant:** after the loop, `left > right`; the element is not present.

### Template 2 — Boundary: find the leftmost (or rightmost) position

Use when duplicates exist or you want the first/last index satisfying a predicate.
Half-open interval: `right` starts at `nums.len()` (one past the end).

```rust
// while left < right; right = mid when pred true, left = mid+1 otherwise
// Post-loop: left == right == first index where pred is true (or nums.len())
// Stdlib equivalent: slice.partition_point(|x| pred(x))
fn lower_bound<T, F: Fn(&T) -> bool>(nums: &[T], pred: F) -> usize {
    let (mut left, mut right) = (0_usize, nums.len());
    while left < right {
        let mid = left + (right - left) / 2;
        if pred(&nums[mid]) { right = mid; } else { left = mid + 1; }
    }
    left
}
```

### Template 3 — Binary search on the answer space

Use when you are NOT searching an array by index but instead searching an abstract monotone space
(e.g., "what is the smallest feasible speed?").

```rust
// lo and hi are values in the answer domain, not array indices.
// feasible(mid) returns true when mid satisfies the constraint.
fn binary_search_on_answer(lo: i64, hi: i64, feasible: impl Fn(i64) -> bool) -> i64 {
    let mut left = lo;
    let mut right = hi;
    while left < right {
        let mid = left + (right - left) / 2;
        if feasible(mid) {
            right = mid; // mid is feasible; search for something smaller
        } else {
            left = mid + 1;
        }
    }
    left // smallest feasible value
}
```

**Note on `usize` underflow:** `right - left` where both are `usize` panics in debug mode if `right < left`.
Always use `i32` or `i64` when your loop bounds might be negative or involve `-1` sentinels.

---

## Part 1 — Template 1: Classic Binary Search

---

### LC #704 — Binary Search (Brief Revisit)

The canonical template. Covered in Ch3; shown here for reference.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search(nums: Vec<i32>, target: i32) -> i32 {
        let mut left = 0_i32;
        let mut right = nums.len() as i32 - 1;
        while left <= right {
            let mid = left + (right - left) / 2;
            match nums[mid as usize].cmp(&target) {
                std::cmp::Ordering::Equal => return mid,
                std::cmp::Ordering::Less => left = mid + 1,
                std::cmp::Ordering::Greater => right = mid - 1,
            }
        }
        -1
    }
}

#[cfg(test)]
mod tests_lc704 {
    use super::Solution;
    #[test]
    fn test_found() {
        assert_eq!(Solution::search(vec![-1, 0, 3, 5, 9, 12], 9), 4);
    }
    #[test]
    fn test_not_found() {
        assert_eq!(Solution::search(vec![-1, 0, 3, 5, 9, 12], 2), -1);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

---

### LC #374 — Guess Number Higher or Lower

**Problem.** `guess(num)` returns `-1` (num > pick), `1` (num < pick), or `0` (correct). Find the pick.

LeetCode injects `guess` as an extern; here we model it with a trait for testability.

```rust
trait GuessApi { fn guess(&self, num: i32) -> i32; }
struct MockGuess { pick: i32 }
impl GuessApi for MockGuess {
    fn guess(&self, num: i32) -> i32 {
        match num.cmp(&self.pick) {
            std::cmp::Ordering::Equal => 0,
            std::cmp::Ordering::Greater => -1,
            std::cmp::Ordering::Less => 1,
        }
    }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn guess_number<G: GuessApi>(n: i32, api: &G) -> i32 {
        let mut left = 1_i32;
        let mut right = n;
        while left <= right {
            let mid = left + (right - left) / 2;
            match api.guess(mid) {
                0 => return mid,
                -1 => right = mid - 1,
                _ => left = mid + 1,
            }
        }
        -1
    }
}

#[cfg(test)]
mod tests_lc374 {
    use super::{MockGuess, Solution};
    #[test]
    fn test_cases() {
        assert_eq!(Solution::guess_number(10, &MockGuess { pick: 6 }), 6);
        assert_eq!(Solution::guess_number(1, &MockGuess { pick: 1 }), 1);
        assert_eq!(Solution::guess_number(100, &MockGuess { pick: 100 }), 100);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- Modeling LeetCode's injected API with a trait lets tests pass any implementation — this is dependency injection the Rust way.
- `match api.guess(mid)` on `-1` / `1` / `0` maps perfectly to `match` arms.

---

### LC #702 — Search in a Sorted Array of Unknown Size

**Problem.** You have access to a sorted array via an `ArrayReader` interface; `reader.get(i)` returns
`2^31 - 1` (`i32::MAX`) for out-of-bounds indices. Find the index of `target`, or `-1`.

**Approach.** First, expand right exponentially until `reader.get(right) >= target`. Then run Template 1.

```rust
trait ArrayReader { fn get(&self, index: i32) -> i32; }
struct MockReader { data: Vec<i32> }
impl ArrayReader for MockReader {
    fn get(&self, index: i32) -> i32 {
        if index < 0 || index as usize >= self.data.len() { i32::MAX }
        else { self.data[index as usize] }
    }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search<R: ArrayReader>(reader: &R, target: i32) -> i32 {
        // Phase 1: exponential expansion to find right boundary
        let mut left = 0_i32;
        let mut right = 1_i32;
        while reader.get(right) < target { left = right; right *= 2; }
        // Phase 2: Template 1 in [left, right]
        while left <= right {
            let mid = left + (right - left) / 2;
            match reader.get(mid).cmp(&target) {
                std::cmp::Ordering::Equal => return mid,
                std::cmp::Ordering::Less => left = mid + 1,
                std::cmp::Ordering::Greater => right = mid - 1,
            }
        }
        -1
    }
}

#[cfg(test)]
mod tests_lc702 {
    use super::{MockReader, Solution};
    #[test]
    fn test_cases() {
        let r = MockReader { data: vec![-1, 0, 3, 5, 9, 12] };
        assert_eq!(Solution::search(&r, 9), 4);
        assert_eq!(Solution::search(&r, 2), -1);
        assert_eq!(Solution::search(&MockReader { data: vec![5] }, 5), 0);
    }
}
```

**Complexity.** Time O(log T) where T is the target's actual index, Space O(1).

**Rust notes.**
- `right *= 2` could overflow `i32` for absurdly large arrays; in practice LeetCode bounds prevent this, but in production use `i64`.
- `reader.get(mid).cmp(&target)` chains the comparison cleanly into the match.

---

### LC #278 — First Bad Version

**Problem.** You have `n` versions (1..=n). Version `k` is the first bad version; all after `k` are also bad.
API: `is_bad_version(version)`. Find `k` with minimal calls.

**Insight.** This is a "find first true" problem — Template 2 in disguise. But we can also solve it with
Template 1's loop by treating "first bad" as a left-boundary search.

```rust
trait VersionApi { fn is_bad_version(&self, v: i32) -> bool; }
struct MockVersion { first_bad: i32 }
impl VersionApi for MockVersion {
    fn is_bad_version(&self, v: i32) -> bool { v >= self.first_bad }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn first_bad_version<V: VersionApi>(n: i32, api: &V) -> i32 {
        let mut left = 1_i32;
        let mut right = n;
        while left < right {
            let mid = left + (right - left) / 2;
            if api.is_bad_version(mid) { right = mid; } else { left = mid + 1; }
        }
        left
    }
}

#[cfg(test)]
mod tests_lc278 {
    use super::{MockVersion, Solution};
    #[test]
    fn test_cases() {
        assert_eq!(Solution::first_bad_version(5, &MockVersion { first_bad: 4 }), 4);
        assert_eq!(Solution::first_bad_version(1, &MockVersion { first_bad: 1 }), 1);
        assert_eq!(Solution::first_bad_version(10, &MockVersion { first_bad: 1 }), 1);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.** `while left < right` with `right = mid` is Template 2: mid < right by integer division,
so `right` strictly decreases. Post-loop, `left == right` is the answer.

---

### LC #69 — Sqrt(x)

**Problem.** Compute `floor(sqrt(x))` for non-negative integer `x`, without using `sqrt()`.

**Overflow trap.** For `x` near `i32::MAX`, `mid * mid` overflows. Cast to `i64` before multiplying.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn my_sqrt(x: i32) -> i32 {
        if x < 2 {
            return x;
        }
        let x64 = x as i64;
        let mut left = 1_i64;
        let mut right = x64 / 2 + 1; // floor(sqrt(x)) <= x/2 for x >= 4
        while left < right {
            let mid = left + (right - left + 1) / 2; // round up to avoid infinite loop
            if mid * mid <= x64 {
                left = mid; // mid is a candidate; try higher
            } else {
                right = mid - 1;
            }
        }
        left as i32
    }
}

#[cfg(test)]
mod tests_lc69 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::my_sqrt(4), 2);
        assert_eq!(Solution::my_sqrt(8), 2);
        assert_eq!(Solution::my_sqrt(9), 3);
    }
    #[test]
    fn test_zero_one() {
        assert_eq!(Solution::my_sqrt(0), 0);
        assert_eq!(Solution::my_sqrt(1), 1);
    }
    #[test]
    fn test_large() {
        assert_eq!(Solution::my_sqrt(2147395599), 46339);
        assert_eq!(Solution::my_sqrt(i32::MAX), 46340);
    }
}
```

**Complexity.** Time O(log x), Space O(1).

**Rust notes.**
- `(right - left + 1) / 2` rounds the mid up. When searching for a *maximum* (`left = mid`), rounding down
  would leave `left == mid == right - 1` forever. Round up when you assign `left = mid`.
- `mid * mid <= x64` with both as `i64` is safe up to `9.2 × 10^18`.

---

## Part 2 — Template 2: Left/Right Boundary

---

### LC #34 — Find First and Last Position of Element in Sorted Array

**Problem.** Given a sorted array with possible duplicates and a target, return `[first, last]` indices.
Return `[-1, -1]` if not present.

**Approach.** Two separate binary searches: one for the left boundary, one for the right.
`partition_point` solves both.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search_range(nums: Vec<i32>, target: i32) -> Vec<i32> {
        if nums.is_empty() {
            return vec![-1, -1];
        }
        // left: first index where nums[i] >= target
        let left = nums.partition_point(|&x| x < target);
        if left == nums.len() || nums[left] != target {
            return vec![-1, -1];
        }
        // right: last index where nums[i] == target
        // = (first index where nums[i] > target) - 1
        let right = nums.partition_point(|&x| x <= target) - 1;
        vec![left as i32, right as i32]
    }
}

#[cfg(test)]
mod tests_lc34 {
    use super::Solution;
    #[test]
    fn test_range_and_miss() {
        assert_eq!(Solution::search_range(vec![5, 7, 7, 8, 8, 10], 8), vec![3, 4]);
        assert_eq!(Solution::search_range(vec![5, 7, 7, 8, 8, 10], 6), vec![-1, -1]);
        assert_eq!(Solution::search_range(vec![2, 2, 2], 2), vec![0, 2]);
    }
    #[test]
    fn test_empty() {
        assert_eq!(Solution::search_range(vec![], 0), vec![-1, -1]);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.** `partition_point(|&x| x < target)` = first index where `x >= target`.
`partition_point(|&x| x <= target) - 1` is safe because we confirmed `nums[left] == target`.

---

### LC #154 — Find Minimum in Rotated Sorted Array II (with Duplicates)

**Problem.** A sorted array was rotated an unknown number of times; it may contain duplicates.
Find the minimum element.

**Worst case.** Input `[1, 1, 1, 0, 1, 1]` — all-same arrays force O(n) in the worst case because
duplicates prevent eliminating half the search space. State this honestly.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_min(nums: Vec<i32>) -> i32 {
        let mut left = 0_usize;
        let mut right = nums.len() - 1;
        while left < right {
            let mid = left + (right - left) / 2;
            if nums[mid] > nums[right] {
                // min is in the right half (exclusive of mid)
                left = mid + 1;
            } else if nums[mid] < nums[right] {
                // mid could be the min; right half's right edge is too large
                right = mid;
            } else {
                // nums[mid] == nums[right]: can't tell; shrink right by 1
                right -= 1;
            }
        }
        nums[left]
    }
}

#[cfg(test)]
mod tests_lc154 {
    use super::Solution;
    #[test]
    fn test_no_rotation() {
        assert_eq!(Solution::find_min(vec![1, 2, 3]), 1);
    }
    #[test]
    fn test_cases() {
        assert_eq!(Solution::find_min(vec![3, 4, 5, 1, 2]), 1);
        assert_eq!(Solution::find_min(vec![2, 2, 2, 0, 1]), 0);
        assert_eq!(Solution::find_min(vec![1, 1, 1, 0, 1, 1, 1]), 0); // worst case
        assert_eq!(Solution::find_min(vec![2, 2, 2]), 2); // all same
    }
}
```

**Complexity.** Time O(log n) average, O(n) worst case (all duplicates). Space O(1).

**Rust notes.** Compare `nums[mid]` vs `nums[right]` (not left); the right boundary is stable in a
rotated array. `right -= 1` on `usize` is safe: `left < right` guarantees `right >= 1`.

---

### LC #81 — Search in Rotated Sorted Array II

**Problem.** A rotated sorted array may contain duplicates. Return `true` if `target` is present.

**Worst case.** Same as LC #154 — duplicates force O(n).

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search(nums: Vec<i32>, target: i32) -> bool {
        // Use i32 indices to avoid usize underflow and the left==right infinite-loop
        // that arises when duplicates prevent both pointers from moving.
        let mut left = 0_i32;
        let mut right = nums.len() as i32 - 1;
        while left <= right {
            let mid = left + (right - left) / 2;
            if nums[mid as usize] == target {
                return true;
            }
            let (l, m, r) = (
                nums[left as usize],
                nums[mid as usize],
                nums[right as usize],
            );
            // When duplicates obscure which half is sorted, shrink both ends
            if l == m && m == r {
                left += 1;
                right -= 1;
            } else if l <= m {
                // Left half is sorted
                if l <= target && target < m {
                    right = mid - 1;
                } else {
                    left = mid + 1;
                }
            } else {
                // Right half is sorted
                if m < target && target <= r {
                    left = mid + 1;
                } else {
                    right = mid - 1;
                }
            }
        }
        false
    }
}

#[cfg(test)]
mod tests_lc81 {
    use super::Solution;
    #[test]
    fn test_cases() {
        assert!(Solution::search(vec![2, 5, 6, 0, 0, 1, 2], 0));
        assert!(!Solution::search(vec![2, 5, 6, 0, 0, 1, 2], 3));
        // all-duplicates corner case: must not infinite-loop
        assert!(!Solution::search(vec![1, 1, 1, 1, 1], 0));
        assert!(Solution::search(vec![1], 1));
    }
}
```

**Complexity.** Time O(log n) average, O(n) worst case. Space O(1).

**Rust notes.**
- `i32` indices throughout: when `left == right` and both point to a non-target duplicate, the `left += 1; right -= 1` shrink would fail to terminate with `usize` (right would wrap around). With `i32`, `right < left` naturally exits the `while left <= right` loop.
- Extracting `l`, `m`, `r` as named variables avoids repeated `nums[left as usize]` casts and makes the logic readable.

---

### LC #162 — Find Peak Element

**Problem.** A peak is where `nums[i] > nums[i-1]` and `nums[i] > nums[i+1]`. Find any peak index.
`nums[-1]` and `nums[n]` are `-∞`. Array has no two adjacent equal elements.

**Insight.** If `nums[mid] < nums[mid+1]`, the right side has a peak; otherwise the left side (or `mid`)
does. This is a Template 2 binary search on a monotone predicate.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_peak_element(nums: Vec<i32>) -> i32 {
        let mut left = 0_usize;
        let mut right = nums.len() - 1;
        while left < right {
            let mid = left + (right - left) / 2;
            if nums[mid] < nums[mid + 1] {
                left = mid + 1; // ascending slope; peak is to the right
            } else {
                right = mid; // descending slope; peak is at mid or left
            }
        }
        left as i32
    }
}

#[cfg(test)]
mod tests_lc162 {
    use super::Solution;
    fn is_peak(nums: &[i32], i: usize) -> bool {
        (i == 0 || nums[i] > nums[i - 1])
            && (i == nums.len() - 1 || nums[i] > nums[i + 1])
    }
    #[test]
    fn test_peaks() {
        let idx = Solution::find_peak_element(vec![1, 2, 3, 1]) as usize;
        assert!(is_peak(&[1, 2, 3, 1], idx));
        let idx2 = Solution::find_peak_element(vec![1, 2, 1, 3, 5, 6, 4]) as usize;
        assert!(is_peak(&[1, 2, 1, 3, 5, 6, 4], idx2));
        assert_eq!(Solution::find_peak_element(vec![1]), 0);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- `nums[mid + 1]` is always safe because `left < right` ensures `mid < right <= nums.len() - 1`,
  so `mid + 1 <= nums.len() - 1`.

---

### LC #436 — Find Right Interval

**Problem.** Given intervals, for each interval find the index of the interval with the smallest
`start >= end_i`. Return `-1` if none.

**Approach.** Collect `(start, original_index)` pairs, sort by start, then for each interval's end
use `partition_point` to find the leftmost start >= end.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_right_interval(intervals: Vec<Vec<i32>>) -> Vec<i32> {
        let n = intervals.len();
        // Build (start, original_index) and sort by start
        let mut starts: Vec<(i32, usize)> = intervals
            .iter()
            .enumerate()
            .map(|(i, iv)| (iv[0], i))
            .collect();
        starts.sort_unstable_by_key(|&(s, _)| s);

        intervals
            .iter()
            .map(|iv| {
                let end = iv[1];
                // Find first start >= end
                let pos = starts.partition_point(|&(s, _)| s < end);
                if pos < n {
                    starts[pos].1 as i32
                } else {
                    -1
                }
            })
            .collect()
    }
}

#[cfg(test)]
mod tests_lc436 {
    use super::Solution;
    #[test]
    fn test_cases() {
        // [[3,4],[2,3],[1,2]] → [-1, 0, 1]
        assert_eq!(
            Solution::find_right_interval(vec![vec![3,4], vec![2,3], vec![1,2]]),
            vec![-1, 0, 1]
        );
        // [[1,4],[2,3],[3,4]] → [-1, 2, -1]
        assert_eq!(
            Solution::find_right_interval(vec![vec![1,4], vec![2,3], vec![3,4]]),
            vec![-1, 2, -1]
        );
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Rust notes.**
- `sort_unstable_by_key` is faster than `sort_by_key` when stability is not needed.
- `partition_point(|&(s, _)| s < end)` pattern-matches the tuple element inside the closure.
- Because `starts` is sorted by `s`, `partition_point` correctly finds the first `s >= end`.

---

## Part 3 — Template 3: Binary Search on the Answer

The template: the answer domain is `[lo, hi]`; `feasible(mid)` is monotone (once true, always true).
Find the smallest (or largest) feasible value.

---

### LC #875 — Koko Eating Bananas

**Problem.** Koko eats bananas at speed `k` bananas/hour. She has `h` hours. Each pile takes
`ceil(pile / k)` hours. Find the minimum `k` such that she finishes all piles within `h` hours.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn min_eating_speed(piles: Vec<i32>, h: i32) -> i32 {
        let &max_pile = piles.iter().max().unwrap();
        let mut left = 1_i64;
        let mut right = max_pile as i64;
        while left < right {
            let mid = left + (right - left) / 2;
            let hours: i64 = piles
                .iter()
                .map(|&p| (p as i64 + mid - 1) / mid) // ceil(p / mid)
                .sum();
            if hours <= h as i64 {
                right = mid; // feasible; try slower
            } else {
                left = mid + 1;
            }
        }
        left as i32
    }
}

#[cfg(test)]
mod tests_lc875 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::min_eating_speed(vec![3, 6, 7, 11], 8), 4);
        assert_eq!(Solution::min_eating_speed(vec![30, 11, 23, 4, 20], 5), 30);
        assert_eq!(Solution::min_eating_speed(vec![30, 11, 23, 4, 20], 6), 23);
    }
    #[test]
    fn test_single_pile() {
        assert_eq!(Solution::min_eating_speed(vec![10], 10), 1);
        assert_eq!(Solution::min_eating_speed(vec![10], 1), 10);
    }
}
```

**Complexity.** Time O(n log M) where M = max pile, Space O(1).

**Rust notes.**
- `(p as i64 + mid - 1) / mid` is integer ceiling division without `f64`.
- Sum is `i64` to avoid overflow when many large piles are present.

---

### LC #1011 — Minimum Capacity to Ship Packages Within D Days

**Problem.** Ship `weights[i]` consecutively (order preserved). Find the minimum ship capacity
to ship all packages within `d` days.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn ship_within_days(weights: Vec<i32>, days: i32) -> i32 {
        let sum: i64 = weights.iter().map(|&w| w as i64).sum();
        let max_w = *weights.iter().max().unwrap() as i64;
        let mut left = max_w; // capacity must carry at least the heaviest package
        let mut right = sum;  // worst case: one day for all
        while left < right {
            let mid = left + (right - left) / 2;
            if Self::can_ship(&weights, days as i64, mid) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }
        left as i32
    }

    fn can_ship(weights: &[i32], days: i64, capacity: i64) -> bool {
        let mut used_days = 1_i64;
        let mut load = 0_i64;
        for &w in weights {
            if load + w as i64 > capacity {
                used_days += 1;
                load = 0;
            }
            load += w as i64;
        }
        used_days <= days
    }
}

#[cfg(test)]
mod tests_lc1011 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::ship_within_days(vec![1,2,3,4,5,6,7,8,9,10], 5), 15);
        assert_eq!(Solution::ship_within_days(vec![3,2,2,4,1,4], 3), 6);
    }
}
```

**Complexity.** Time O(n log S) where S = sum of weights, Space O(1).

**Rust notes.**
- The lower bound is `max_w` not `1`, because a single package can't be split.
- `can_ship` simulates a greedy day-packing; we start a new day when the current load would exceed capacity.

---

### LC #410 — Split Array Largest Sum

**Problem.** Split `nums` into exactly `k` non-empty subarrays. Minimize the largest subarray sum.

**Overflow warning.** Subarray sums of `nums[i]` up to `10^8` with up to `1000` elements can reach
`10^11` — must use `i64`.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn split_array(nums: Vec<i32>, k: i32) -> i32 {
        let sum: i64 = nums.iter().map(|&n| n as i64).sum();
        let max_n = *nums.iter().max().unwrap() as i64;
        let mut left = max_n;
        let mut right = sum;
        while left < right {
            let mid = left + (right - left) / 2;
            if Self::can_split(&nums, k as i64, mid) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }
        left as i32
    }

    fn can_split(nums: &[i32], k: i64, max_sum: i64) -> bool {
        let mut parts = 1_i64;
        let mut current = 0_i64;
        for &n in nums {
            if current + n as i64 > max_sum {
                parts += 1;
                current = 0;
            }
            current += n as i64;
        }
        parts <= k
    }
}

#[cfg(test)]
mod tests_lc410 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::split_array(vec![7, 2, 5, 10, 8], 2), 18);
        assert_eq!(Solution::split_array(vec![1, 2, 3, 4, 5], 2), 9);
    }
    #[test]
    fn test_single_split() {
        assert_eq!(Solution::split_array(vec![1, 4, 4], 3), 4);
    }
}
```

**Complexity.** Time O(n log S), Space O(1).

---

### LC #1552 — Magnetic Force Between Two Balls

**Problem.** Place `m` balls in `position` (sorted) baskets to maximize the minimum magnetic force
(minimum distance between any two balls).

**Key reversal.** We maximize the minimum, so `feasible(mid)` asks: "can we place all balls with
pairwise distance >= mid?" Search the largest mid where this is true by finding the last feasible
value.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn max_distance(mut position: Vec<i32>, m: i32) -> i32 {
        position.sort_unstable();
        let n = position.len();
        let mut left = 1_i64;
        let mut right = (position[n - 1] - position[0]) as i64;
        while left < right {
            // Round up to search the largest feasible gap
            let mid = left + (right - left + 1) / 2;
            if Self::can_place(&position, m as i64, mid) {
                left = mid; // feasible; try larger gap
            } else {
                right = mid - 1;
            }
        }
        left as i32
    }

    fn can_place(position: &[i32], m: i64, min_dist: i64) -> bool {
        let mut count = 1_i64;
        let mut last = position[0] as i64;
        for &pos in position.iter().skip(1) {
            if pos as i64 - last >= min_dist {
                count += 1;
                last = pos as i64;
            }
        }
        count >= m
    }
}

#[cfg(test)]
mod tests_lc1552 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::max_distance(vec![1, 2, 3, 4, 7], 3), 3);
        assert_eq!(Solution::max_distance(vec![5, 4, 3, 2, 1, 1000000000], 2), 999999999);
    }
    #[test]
    fn test_two_balls() {
        assert_eq!(Solution::max_distance(vec![1, 5, 9], 2), 8);
    }
}
```

**Complexity.** Time O(n log n + n log D) where D = position range, Space O(1).

**Rust notes.**
- When maximizing, use `right = mid - 1` and `left = mid` (with round-up mid) instead of the minimize pattern.
- `(right - left + 1) / 2` rounds the mid up, preventing infinite loops when `left = mid`.

---

### LC #1283 — Find the Smallest Divisor Given a Threshold

**Problem.** Find the smallest positive integer divisor `d` such that `sum(ceil(nums[i] / d)) <= threshold`.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn smallest_divisor(nums: Vec<i32>, threshold: i32) -> i32 {
        let mut left = 1_i64;
        let mut right = *nums.iter().max().unwrap() as i64;
        while left < right {
            let mid = left + (right - left) / 2;
            let total: i64 = nums
                .iter()
                .map(|&n| (n as i64 + mid - 1) / mid)
                .sum();
            if total <= threshold as i64 {
                right = mid;
            } else {
                left = mid + 1;
            }
        }
        left as i32
    }
}

#[cfg(test)]
mod tests_lc1283 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::smallest_divisor(vec![1, 2, 5, 9], 6), 5);
        assert_eq!(Solution::smallest_divisor(vec![44, 22, 33, 11, 100], 5), 44);
    }
    #[test]
    fn test_threshold_equals_n() {
        // divisor = max(nums) always works when threshold >= n
        assert_eq!(Solution::smallest_divisor(vec![2, 3, 5, 7, 11], 11), 1);
    }
}
```

**Complexity.** Time O(n log M) where M = max element, Space O(1).

---

### LC #2064 — Minimized Maximum of Products Distributed to Any Store

**Problem.** Distribute `quantities[i]` units of `n` distinct product types among `m` stores (each store
gets at most one product type). Minimize the maximum quantity assigned to any store.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn minimized_maximum(n: i32, quantities: Vec<i32>) -> i32 {
        let mut left = 1_i64;
        let mut right = *quantities.iter().max().unwrap() as i64;
        while left < right {
            let mid = left + (right - left) / 2;
            // How many stores needed if each gets at most mid units of a type?
            let stores_needed: i64 = quantities
                .iter()
                .map(|&q| (q as i64 + mid - 1) / mid) // ceil(q / mid)
                .sum();
            if stores_needed <= n as i64 {
                right = mid; // feasible; try smaller max
            } else {
                left = mid + 1;
            }
        }
        left as i32
    }
}

#[cfg(test)]
mod tests_lc2064 {
    use super::Solution;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::minimized_maximum(6, vec![11, 6]), 3);
        assert_eq!(Solution::minimized_maximum(7, vec![15, 10, 10]), 5);
        assert_eq!(Solution::minimized_maximum(1, vec![10000]), 10000);
    }
    #[test]
    fn test_exact_split() {
        // 4 stores, quantities [8,4] → min max = 4 (8→2 stores, 4→1 store, 1 extra)
        assert_eq!(Solution::minimized_maximum(4, vec![8, 4]), 4);
    }
}
```

**Complexity.** Time O(n log M), Space O(1).

---

## Part 4 — 2D Binary Search

---

### LC #240 — Search a 2D Matrix II

**Problem.** An `m x n` matrix where each row is sorted left-to-right and each column top-to-bottom.
Find whether `target` is present.

**Note.** This is NOT a binary search problem. It uses staircase elimination (saddleback search),
which is a neighbor of binary search in the pattern family. Binary search on each row would be
O(m log n) — the staircase method achieves O(m + n).

**Approach.** Start at top-right. If current > target, move left. If current < target, move down.
If equal, found.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search_matrix(matrix: Vec<Vec<i32>>, target: i32) -> bool {
        if matrix.is_empty() || matrix[0].is_empty() {
            return false;
        }
        let m = matrix.len() as i32;
        let n = matrix[0].len() as i32;
        let mut row = 0_i32;
        let mut col = n - 1;
        while row < m && col >= 0 {
            match matrix[row as usize][col as usize].cmp(&target) {
                std::cmp::Ordering::Equal => return true,
                std::cmp::Ordering::Greater => col -= 1,
                std::cmp::Ordering::Less => row += 1,
            }
        }
        false
    }
}

#[cfg(test)]
mod tests_lc240 {
    use super::Solution;
    #[test]
    fn test_cases() {
        let m = vec![
            vec![1,4,7,11,15], vec![2,5,8,12,19], vec![3,6,9,16,22],
            vec![10,13,14,17,24], vec![18,21,23,26,30],
        ];
        assert!(Solution::search_matrix(m.clone(), 5));
        assert!(!Solution::search_matrix(m, 20));
        assert!(Solution::search_matrix(vec![vec![5]], 5));
    }
}
```

**Complexity.** Time O(m + n), Space O(1).

**Rust notes.**
- `col` is `i32` to allow `col -= 1` reaching `-1` as the termination condition.
- `matrix[row as usize][col as usize]` — cast to `usize` only at access time, after the bounds check.

---

### LC #378 — Kth Smallest Element in a Sorted Matrix

**Problem.** Given an `n x n` matrix where each row and column is sorted, find the kth smallest element.

**Approach.** Binary search on value (Template 3). For a candidate value `mid`, count how many
elements are `<= mid` using the staircase method. Find the smallest value where count `>= k`.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn kth_smallest(matrix: Vec<Vec<i32>>, k: i32) -> i32 {
        let n = matrix.len();
        let mut left = matrix[0][0] as i64;
        let mut right = matrix[n - 1][n - 1] as i64;
        while left < right {
            let mid = left + (right - left) / 2;
            let count = Self::count_le(&matrix, mid, n);
            if count >= k as i64 {
                right = mid; // there are enough elements <= mid; try smaller
            } else {
                left = mid + 1;
            }
        }
        left as i32
    }

    // Count elements <= val using staircase from bottom-left
    fn count_le(matrix: &[Vec<i32>], val: i64, n: usize) -> i64 {
        let mut count = 0_i64;
        let mut row = (n - 1) as i32;
        let mut col = 0_i32;
        while row >= 0 && (col as usize) < n {
            if matrix[row as usize][col as usize] as i64 <= val {
                count += row as i64 + 1; // all elements in this column up to row are <= val
                col += 1;
            } else {
                row -= 1;
            }
        }
        count
    }
}

#[cfg(test)]
mod tests_lc378 {
    use super::Solution;
    #[test]
    fn test_basic() {
        let matrix = vec![vec![1, 5, 9], vec![10, 11, 13], vec![12, 13, 15]];
        assert_eq!(Solution::kth_smallest(matrix, 8), 13);
    }
    #[test]
    fn test_single() {
        assert_eq!(Solution::kth_smallest(vec![vec![1]], 1), 1);
    }
    #[test]
    fn test_k_1() {
        let matrix = vec![vec![1, 2], vec![3, 4]];
        assert_eq!(Solution::kth_smallest(matrix.clone(), 1), 1);
        assert_eq!(Solution::kth_smallest(matrix, 4), 4);
    }
}
```

**Complexity.** Time O(n log(max - min)), Space O(1).

**Rust notes.**
- We search the *value domain* `[matrix[0][0], matrix[n-1][n-1]]`, not index space.
- The final `left` is guaranteed to be an element that actually appears in the matrix because we
  search for the smallest value with `count >= k`, and both boundaries are real matrix values.

---

## Stdlib Reference

Four slice methods cover binary search without a hand-rolled loop:

| Method | Returns | Use when |
|---|---|---|
| `slice.binary_search(&key)` | `Ok(idx)` or `Err(insert_pos)` | exact match, no custom ordering |
| `slice.binary_search_by(\|x\| ...)` | same | custom comparator (e.g., `f64`, struct field) |
| `slice.binary_search_by_key(&k, \|x\| ...)` | same | search `Vec<(K,V)>` by extracted key |
| `slice.partition_point(\|x\| pred(x))` | `usize` | first index where pred flips — replaces T2 entirely |

```rust
#[cfg(test)]
mod tests_stdlib {
    #[test]
    fn test_stdlib_methods() {
        let nums = vec![1_i32, 3, 5, 7, 9];
        assert_eq!(nums.binary_search(&5), Ok(2));
        assert_eq!(nums.binary_search(&4), Err(2)); // insertion point
        assert_eq!(nums.partition_point(|&x| x < 5), 2); // first index >= 5

        // binary_search_by_key on a struct-like tuple
        let mut records = vec![("Alice", 30_i32), ("Bob", 25), ("Charlie", 35)];
        records.sort_by_key(|&(_, age)| age);
        assert!(records.binary_search_by_key(&30, |&(_, age)| age).is_ok());
    }
}
```

---

## Review Notes

### When to Use Which Template

```
Is the search space an index into a sorted array?
  YES → Do duplicates make first/last position matter?
          YES → Template 2: while left < right, right = mid or left = mid + 1
                Shortcut: slice.partition_point(|x| pred(x))
          NO  → Template 1: while left <= right, classic ±1 on both ends
  NO  → Search for an optimal value in an abstract domain (answer space)
          → Template 3: while left < right
              Minimize: right = mid, left = mid + 1, round-down mid
              Maximize: left = mid, right = mid - 1, round-UP mid
```

| Template | Condition | Mid rounding | Post-loop meaning |
|---|---|---|---|
| T1 — exact match | `left <= right` | round down | element absent if loop exits |
| T2 — left boundary | `left < right` | round down | `left == right` is the boundary |
| T3 — minimize answer | `left < right` | round down | `left` is smallest feasible |
| T3 — maximize answer | `left < right` | **round up** | `left` is largest feasible |

### Rust-Specific Pitfalls

**1. `usize` underflow.** `right = mid - 1` panics in debug when `mid == 0` and `right` is `usize`.
Fix: use `i32` for index variables; cast to `usize` only at array-access sites.

**2. `i32 * i32` overflow.** Squaring large `i32` values wraps silently in release mode, panics in debug.
Fix: cast to `i64` first — `mid as i64 * mid as i64`. (LC #69, any similar squaring.)

**3. Infinite loop when maximizing.** With `left = mid` and round-down mid, `left` never advances when
`right == left + 1`. Fix: round mid up with `left + (right - left + 1) / 2`. (LC #1552, LC #69.)

**4. Off-by-one on open vs. closed intervals.** T1 uses closed `[left, right]` → `right` starts at
`len - 1`. T2 uses half-open `[left, right)` → `right` starts at `len` (or exclusive bound).
Mixing these produces missed elements or off-by-one results.

**5. Duplicate-induced O(n).** LC #81 and LC #154 are O(log n) on average but O(n) worst case when
the shrink rule reduces the window by only 1 element per step. Never advertise these as O(log n).

### Java-to-Rust Translation Card

| Java | Rust | Gotcha |
|---|---|---|
| `int mid = lo + (hi - lo) / 2` | `let mid = left + (right - left) / 2` | Same formula |
| `(long) mid * mid` | `mid as i64 * mid as i64` | Always cast before multiply |
| `int lo = 0, hi = n - 1` | `let mut left = 0_i32; let mut right = n as i32 - 1` | Use `i32` not `usize` |
| `Collections.binarySearch(list, key)` | `slice.binary_search(&key)` | Returns `Result`, not index |
| Custom comparator `Arrays.binarySearch` | `slice.binary_search_by(\|x\| ...)` | Closure not `Comparator` |
| "first element >= x" | `slice.partition_point(\|&v\| v < x)` | Built-in Template 2 |
| `Math.ceil((double) a / b)` | `(a + b - 1) / b` (integers) | No float needed |
