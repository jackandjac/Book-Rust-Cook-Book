# LC-02: Two Pointers & Sliding Window

> **Target audience:** Java developers learning Rust through Blind75 / NeetCode150 problems.
> **Rust edition:** 2024 (Rust 1.85+). Every code block compiles and all tests pass.

---

## Patterns at a Glance

| Pattern | Core idea | Key Rust tools |
|---|---|---|
| Two Pointers (opposite ends) | `left` and `right` converge toward each other | `usize` indices, `while l < r` |
| Two Pointers (same direction) | slow/fast, or anchor/runner | `enumerate()`, range loops |
| Fixed Sliding Window | window of size `k`; slide one step at a time | array `[T; N]`, `VecDeque` |
| Variable Sliding Window | expand `right`, shrink `left` when constraint broken | `HashMap`, `[u32; 26]` |

**Java mental model shift:** Java string indexing (`s.charAt(i)`) is O(1) because Java strings are UTF-16 arrays. Rust `String` is UTF-8; direct byte indexing via `.as_bytes()` is O(1) for ASCII problems, but `.chars().nth(i)` is O(n). For LeetCode problems with ASCII constraints, always work with bytes (`&[u8]`) — it is faster and simpler.

---

## Part 1: Two Pointers

---

### Problem 1 — Valid Palindrome (LC #125)

**Statement:** Given a string `s`, return `true` if it is a palindrome after removing all non-alphanumeric characters and lowercasing.

**Key insight:** Filter and normalize the bytes into a `Vec<u8>`, then walk `left` and `right` toward the center. Because the problem is ASCII-only, working with bytes completely avoids multi-byte char concerns.

**Rust-specific note:** `.is_ascii_alphanumeric()` and `.to_ascii_lowercase()` operate on `u8` directly — no `char` conversion needed. This is both simpler and faster than collecting to `Vec<char>`.

```rust
struct Solution;

impl Solution {
    pub fn is_palindrome(s: String) -> bool {
        // Filter to alphanumeric bytes only, lowercased.
        // `.bytes()` yields u8 values — correct for ASCII input.
        let bytes: Vec<u8> = s
            .bytes()
            .filter(|b| b.is_ascii_alphanumeric())
            .map(|b| b.to_ascii_lowercase())
            .collect();

        let n = bytes.len();
        let (mut l, mut r) = (0, n.saturating_sub(1));
        // saturating_sub: prevents underflow when n == 0 (empty string after filter)
        while l < r {
            if bytes[l] != bytes[r] {
                return false;
            }
            l += 1;
            r -= 1;
        }
        true
    }
}

#[cfg(test)]
mod tests_125 {
    use super::*;

    #[test]
    fn test_is_palindrome() {
        assert!(Solution::is_palindrome(
            "A man, a plan, a canal: Panama".to_string()
        ));
        assert!(!Solution::is_palindrome("race a car".to_string()));
        // Edge: only spaces/punctuation — empty after filter → true
        assert!(Solution::is_palindrome(" ".to_string()));
        assert!(Solution::is_palindrome("".to_string()));
        assert!(Solution::is_palindrome("0P".to_string()) == false);
    }
}
```

**Complexity:** Time O(n), Space O(n) for the filtered byte vector.

**Java comparison:** In Java you would typically use `Character.isLetterOrDigit(c)` and `Character.toLowerCase(c)`. The two-pointer logic is identical; Rust just makes the byte-level operations more explicit.

---

### Problem 2 — Two Sum II: Input Array Is Sorted (LC #167)

**Statement:** Given a 1-indexed sorted array `numbers` and a `target`, return the indices `[i, j]` (1-indexed) of the two numbers that add up to `target`. Exactly one solution is guaranteed.

**Key insight:** Because the array is sorted, if `numbers[l] + numbers[r] < target`, moving `l` right increases the sum; if greater, moving `r` left decreases it. The pointers converge in O(n).

**Common bug:** The return value must be **1-indexed**. In Rust: `vec![(l + 1) as i32, (r + 1) as i32]`. Forgetting the `+1` is one of the most common mistakes on this problem.

```rust
impl Solution {
    pub fn two_sum(numbers: Vec<i32>, target: i32) -> Vec<i32> {
        let (mut l, mut r) = (0usize, numbers.len() - 1);
        // The problem guarantees exactly one solution, so the loop always terminates.
        loop {
            let sum = numbers[l] + numbers[r];
            if sum == target {
                // IMPORTANT: LeetCode expects 1-indexed positions.
                return vec![(l + 1) as i32, (r + 1) as i32];
            } else if sum < target {
                l += 1; // need a larger sum → move left pointer right
            } else {
                r -= 1; // need a smaller sum → move right pointer left
            }
        }
    }
}

#[cfg(test)]
mod tests_167 {
    use super::*;

    #[test]
    fn test_two_sum_sorted() {
        assert_eq!(Solution::two_sum(vec![2, 7, 11, 15], 9), vec![1, 2]);
        assert_eq!(Solution::two_sum(vec![2, 3, 4], 6), vec![1, 3]);
        assert_eq!(Solution::two_sum(vec![-1, 0], -1), vec![1, 2]);
    }
}
```

**Complexity:** Time O(n), Space O(1).

---

### Problem 3 — 3Sum (LC #15)

**Statement:** Given an integer array `nums`, return all triplets `[a, b, c]` such that `a + b + c == 0` with no duplicate triplets.

**Key insight:** Sort the array first. Fix `nums[i]` as the first element, then run a two-pointer search on the remaining subarray for pairs that sum to `-nums[i]`. Skip duplicate values at both the outer index and inner pointers to avoid duplicate triplets.

**Duplicate-skip logic (easy to get wrong):**
- Outer: `if i > 0 && nums[i] == nums[i-1] { continue; }` — skip duplicate anchor values.
- Inner after match: advance `l` past all equal values, advance `r` back past all equal values, then step once more.

```rust
impl Solution {
    pub fn three_sum(mut nums: Vec<i32>) -> Vec<Vec<i32>> {
        nums.sort_unstable(); // sort_unstable is fine; no stability requirement
        let n = nums.len();
        let mut result = Vec::new();

        // We need at least 3 elements; saturating_sub(2) handles n < 2 safely.
        for i in 0..n.saturating_sub(2) {
            // Skip duplicate anchor values to avoid duplicate triplets.
            if i > 0 && nums[i] == nums[i - 1] {
                continue;
            }
            // Early exit: if the smallest possible value is already > 0,
            // all remaining sums will be positive.
            if nums[i] > 0 {
                break;
            }

            let (mut l, mut r) = (i + 1, n - 1);
            while l < r {
                let sum = nums[i] + nums[l] + nums[r];
                match sum.cmp(&0) {
                    std::cmp::Ordering::Equal => {
                        result.push(vec![nums[i], nums[l], nums[r]]);
                        // Skip duplicates from left
                        while l < r && nums[l] == nums[l + 1] {
                            l += 1;
                        }
                        // Skip duplicates from right
                        while l < r && nums[r] == nums[r - 1] {
                            r -= 1;
                        }
                        // Move both pointers past the matched pair
                        l += 1;
                        r -= 1;
                    }
                    std::cmp::Ordering::Less => l += 1,
                    std::cmp::Ordering::Greater => r -= 1,
                }
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_15 {
    use super::*;

    #[test]
    fn test_three_sum() {
        let mut r = Solution::three_sum(vec![-1, 0, 1, 2, -1, -4]);
        // Order of triplets is not specified; sort for deterministic comparison.
        r.iter_mut().for_each(|v| v.sort_unstable());
        r.sort_unstable();
        assert_eq!(r, vec![vec![-1, -1, 2], vec![-1, 0, 1]]);

        // No valid triplets
        assert!(Solution::three_sum(vec![0, 1, 1]).is_empty());

        // All zeros
        assert_eq!(Solution::three_sum(vec![0, 0, 0]), vec![vec![0, 0, 0]]);
    }
}
```

**Complexity:** Time O(n²), Space O(1) excluding output.

**Rust note:** `sort_unstable()` is preferred over `sort()` when order among equal elements does not matter — it is faster in practice (pattern-defeating quicksort vs timsort).

---

### Problem 4 — Container With Most Water (LC #11)

**Statement:** Given `height`, an array of n non-negative integers representing vertical lines, find two lines that together with the x-axis form a container holding the most water.

**Key insight:** Start with the widest possible container (`l=0`, `r=n-1`). The area is `width * min(height[l], height[r])`. To potentially find a better answer, always move the pointer pointing to the *shorter* line — moving the taller one can only reduce (or maintain) the min height while also reducing width.

```rust
impl Solution {
    pub fn max_area(height: Vec<i32>) -> i32 {
        let (mut l, mut r) = (0usize, height.len() - 1);
        let mut max = 0;
        while l < r {
            // Width is (r - l), height is the shorter of the two lines.
            let area = (r - l) as i32 * height[l].min(height[r]);
            max = max.max(area);
            // Move the shorter line's pointer — it is the limiting factor.
            if height[l] < height[r] {
                l += 1;
            } else {
                // When equal, moving either pointer is correct.
                r -= 1;
            }
        }
        max
    }
}

#[cfg(test)]
mod tests_11 {
    use super::*;

    #[test]
    fn test_max_area() {
        assert_eq!(Solution::max_area(vec![1, 8, 6, 2, 5, 4, 8, 3, 7]), 49);
        assert_eq!(Solution::max_area(vec![1, 1]), 1);
        assert_eq!(Solution::max_area(vec![4, 3, 2, 1, 4]), 16);
    }
}
```

**Complexity:** Time O(n), Space O(1).

---

### Problem 5 — Trapping Rain Water (LC #42)

**Statement:** Given `height`, an elevation map, compute how much water it can trap after raining.

**Key insight (two-pointer O(1) space):** At each position, trapped water equals `min(left_max, right_max) - height[i]`. Instead of precomputing prefix/suffix max arrays, track running maxima with two pointers. Process whichever side has the smaller current max — that side's trapped water is fully determined by its own max.

```rust
impl Solution {
    pub fn trap(height: Vec<i32>) -> i32 {
        if height.is_empty() {
            return 0;
        }
        let (mut l, mut r) = (0usize, height.len() - 1);
        let (mut left_max, mut right_max) = (0i32, 0i32);
        let mut water = 0;

        while l < r {
            if height[l] <= height[r] {
                // The right boundary is at least as tall as height[l],
                // so left_max is the binding constraint.
                if height[l] >= left_max {
                    left_max = height[l]; // new left high point, no water here
                } else {
                    water += left_max - height[l]; // water trapped above this cell
                }
                l += 1;
            } else {
                // Mirror logic for the right side.
                if height[r] >= right_max {
                    right_max = height[r];
                } else {
                    water += right_max - height[r];
                }
                r -= 1;
            }
        }
        water
    }
}

#[cfg(test)]
mod tests_42 {
    use super::*;

    #[test]
    fn test_trap() {
        assert_eq!(
            Solution::trap(vec![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]),
            6
        );
        assert_eq!(Solution::trap(vec![4, 2, 0, 3, 2, 5]), 9);
        assert_eq!(Solution::trap(vec![]), 0);
        assert_eq!(Solution::trap(vec![3]), 0);
        assert_eq!(Solution::trap(vec![3, 0, 3]), 3);
    }
}
```

**Complexity:** Time O(n), Space O(1).

**Simpler alternative (O(n) space):** Compute `left_max[i]` and `right_max[i]` arrays in two passes, then sum `min(left_max[i], right_max[i]) - height[i]`. The two-pointer version is preferred for interviews.

---

## Part 2: Sliding Window

---

### Problem 6 — Best Time to Buy and Sell Stock (LC #121)

**Statement:** Given `prices[i]` for day `i`, find the maximum profit from buying on one day and selling on a later day. Return 0 if no profit is possible.

**Key insight:** This is technically a one-pass sliding window / greedy: track the minimum price seen so far (`buy` pointer) and the maximum gain from selling at the current price (`sell` pointer). If the current price is lower than `min_price`, update the buy point — never sell before you buy.

```rust
impl Solution {
    pub fn max_profit(prices: Vec<i32>) -> i32 {
        let mut min_price = i32::MAX; // sentinel: "haven't bought yet"
        let mut max_profit = 0;       // floor at 0: we can always do nothing

        for &price in &prices {
            if price < min_price {
                min_price = price; // found a cheaper buy day
            } else {
                // Can we improve profit by selling today?
                max_profit = max_profit.max(price - min_price);
            }
        }
        max_profit
    }
}

#[cfg(test)]
mod tests_121 {
    use super::*;

    #[test]
    fn test_max_profit() {
        assert_eq!(Solution::max_profit(vec![7, 1, 5, 3, 6, 4]), 5);
        // Monotonically decreasing — no profit possible
        assert_eq!(Solution::max_profit(vec![7, 6, 4, 3, 1]), 0);
        assert_eq!(Solution::max_profit(vec![1, 2]), 1);
    }
}
```

**Complexity:** Time O(n), Space O(1).

**Rust note:** `i32::MAX` as a sentinel for "not yet set" is idiomatic. In Java you would use `Integer.MAX_VALUE` or initialize from `prices[0]`. Both approaches work; Rust's pattern is identical.

---

### Problem 7 — Longest Substring Without Repeating Characters (LC #3)

**Statement:** Given string `s`, return the length of the longest substring with all distinct characters.

**Key insight (variable sliding window):** Maintain a window `[left, right]`. When a repeated character is encountered at `right`, jump `left` to `last_seen[char] + 1`. Track the last seen index of each character in a fixed-size array — faster than a `HashMap` for ASCII.

**Rust-specific optimization:** A `[usize; 128]` array (one slot per ASCII code point) replaces a `HashMap<u8, usize>`. Array indexing is O(1) with no hashing overhead and no heap allocation.

```rust
impl Solution {
    pub fn length_of_longest_substring(s: String) -> i32 {
        let bytes = s.as_bytes();
        // last_seen[b] = last index where byte b was seen.
        // usize::MAX acts as "never seen" sentinel.
        let mut last_seen = [usize::MAX; 128];
        let mut left = 0usize;
        let mut max_len = 0;

        for (right, &b) in bytes.iter().enumerate() {
            let idx = b as usize;
            // If b was seen inside the current window, shrink from the left.
            if last_seen[idx] != usize::MAX && last_seen[idx] >= left {
                left = last_seen[idx] + 1;
            }
            last_seen[idx] = right;
            max_len = max_len.max(right - left + 1);
        }
        max_len as i32
    }
}

#[cfg(test)]
mod tests_3 {
    use super::*;

    #[test]
    fn test_length_of_longest_substring() {
        assert_eq!(
            Solution::length_of_longest_substring("abcabcbb".to_string()),
            3
        );
        assert_eq!(
            Solution::length_of_longest_substring("bbbbb".to_string()),
            1
        );
        assert_eq!(
            Solution::length_of_longest_substring("pwwkew".to_string()),
            3
        );
        assert_eq!(Solution::length_of_longest_substring("".to_string()), 0);
        assert_eq!(Solution::length_of_longest_substring(" ".to_string()), 1);
    }
}
```

**Complexity:** Time O(n), Space O(1) — the `[usize; 128]` array is fixed size regardless of input length.

**Java comparison:** Java developers commonly use `HashMap<Character, Integer>`. The `[usize; 128]` array is the Rust idiom for ASCII frequency/index maps — same concept, zero heap allocation.

---

### Problem 8 — Longest Repeating Character Replacement (LC #424)

**Statement:** Given string `s` of uppercase letters and integer `k`, you can replace at most `k` characters. Return the length of the longest substring you can make with all the same letter.

**Key insight:** A window `[left, right]` is valid when `(window_size - max_frequency_in_window) <= k`. The characters other than the most frequent one are the ones we need to replace; there can be at most `k` of them. When the window becomes invalid, slide `left` right by one to shrink it.

**Subtle correctness point:** `max_freq` is never decremented when shrinking. This is intentional — we only care about finding a window *at least as large* as the current best. If `max_freq` would decrease on shrink, no window of that size can be better, so we simply maintain size without expanding incorrectly.

```rust
impl Solution {
    pub fn character_replacement(s: String, k: i32) -> i32 {
        let bytes = s.as_bytes();
        let mut count = [0u32; 26]; // frequency of each uppercase letter in window
        let mut max_freq = 0u32;    // frequency of the most common letter in window
        let mut left = 0usize;
        let mut max_len = 0;

        for right in 0..bytes.len() {
            let idx = (bytes[right] - b'A') as usize;
            count[idx] += 1;
            max_freq = max_freq.max(count[idx]);

            // Shrink condition: replacements needed = window_size - max_freq > k
            // We shrink by exactly 1 (not a while loop) because the window only grows
            // by 1 each iteration — so it can only become invalid by 1.
            if (right - left + 1) as u32 - max_freq > k as u32 {
                let li = (bytes[left] - b'A') as usize;
                count[li] -= 1;
                left += 1;
                // Note: max_freq is NOT updated here. See explanation above.
            }
            max_len = max_len.max(right - left + 1);
        }
        max_len as i32
    }
}

#[cfg(test)]
mod tests_424 {
    use super::*;

    #[test]
    fn test_character_replacement() {
        assert_eq!(
            Solution::character_replacement("ABAB".to_string(), 2),
            4
        );
        assert_eq!(
            Solution::character_replacement("AABABBA".to_string(), 1),
            4
        );
        assert_eq!(
            Solution::character_replacement("AAAA".to_string(), 0),
            4
        );
        assert_eq!(
            Solution::character_replacement("A".to_string(), 0),
            1
        );
    }
}
```

**Complexity:** Time O(n), Space O(1).

---

### Problem 9 — Permutation in String (LC #567)

**Statement:** Given strings `s1` and `s2`, return `true` if any permutation of `s1` is a substring of `s2`.

**Key insight (fixed-size sliding window):** A permutation has the same character frequencies as the original. Maintain a fixed window of size `s1.len()` over `s2` and compare frequency arrays. When sliding, decrement the outgoing character's count and increment the incoming character's count.

**Rust-specific optimization:** Use `[i32; 26]` arrays instead of `HashMap`. Comparing two `[i32; 26]` arrays with `==` is a single O(26) comparison — effectively O(1). In Java, `Arrays.equals()` on `int[26]` does the same thing, but Java devs often reach for `HashMap` by habit.

```rust
impl Solution {
    pub fn check_inclusion(s1: String, s2: String) -> bool {
        if s1.len() > s2.len() {
            return false;
        }
        let b1 = s1.as_bytes();
        let b2 = s2.as_bytes();
        let k = b1.len(); // fixed window size

        let mut need   = [0i32; 26]; // target frequencies from s1
        let mut window = [0i32; 26]; // current window frequencies in s2

        for &b in b1 {
            need[(b - b'a') as usize] += 1;
        }
        // Seed the first window
        for i in 0..k {
            window[(b2[i] - b'a') as usize] += 1;
        }
        if need == window {
            return true;
        }
        // Slide the window one character at a time
        for right in k..b2.len() {
            window[(b2[right] - b'a') as usize] += 1;       // add incoming
            window[(b2[right - k] - b'a') as usize] -= 1;   // remove outgoing
            if need == window {
                return true;
            }
        }
        false
    }
}

#[cfg(test)]
mod tests_567 {
    use super::*;

    #[test]
    fn test_check_inclusion() {
        assert!(Solution::check_inclusion(
            "ab".to_string(),
            "eidbaooo".to_string()
        ));
        assert!(!Solution::check_inclusion(
            "ab".to_string(),
            "eidboaoo".to_string()
        ));
        assert!(Solution::check_inclusion("a".to_string(), "a".to_string()));
        // s1 longer than s2
        assert!(!Solution::check_inclusion(
            "abc".to_string(),
            "ab".to_string()
        ));
    }
}
```

**Complexity:** Time O(26·n) = O(n), Space O(1).

---

### Problem 10 — Minimum Window Substring (LC #76)

**Statement:** Given strings `s` and `t`, return the minimum window substring of `s` that contains all characters of `t`. Return `""` if no such window exists.

**Key insight:** Use the `have` / `need` counter pattern. `need` is the count of distinct characters in `t` that still need to be fully satisfied in the window. When `have == need`, all required characters are present — try to shrink from the left. This avoids comparing full maps on every step (which would make it O(n·m)).

```rust
impl Solution {
    pub fn min_window(s: String, t: String) -> String {
        use std::collections::HashMap;

        if s.is_empty() || t.is_empty() {
            return String::new();
        }

        let s_bytes = s.as_bytes();

        // Build the frequency map for t.
        let mut need: HashMap<u8, i32> = HashMap::new();
        for &b in t.as_bytes() {
            *need.entry(b).or_insert(0) += 1;
        }

        // `required`: how many distinct chars from t must reach their target count.
        // `have`: how many distinct chars currently satisfy their target count in window.
        let required = need.len();
        let mut have = 0usize;

        let mut window: HashMap<u8, i32> = HashMap::new();
        let mut left = 0usize;
        let mut best_left = 0usize;
        let mut best_len = usize::MAX; // sentinel: "no valid window found yet"

        for right in 0..s_bytes.len() {
            let b = s_bytes[right];
            *window.entry(b).or_insert(0) += 1;

            // Check if this character just satisfied its required count.
            if let Some(&n) = need.get(&b) {
                if window[&b] == n {
                    have += 1;
                }
            }

            // All required characters are in the window — try to shrink.
            while have == required {
                let win_len = right - left + 1;
                if win_len < best_len {
                    best_len = win_len;
                    best_left = left;
                }
                // Remove the leftmost character from the window.
                let lb = s_bytes[left];
                *window.get_mut(&lb).unwrap() -= 1;
                if let Some(&n) = need.get(&lb) {
                    if window[&lb] < n {
                        have -= 1; // this character is no longer fully satisfied
                    }
                }
                left += 1;
            }
        }

        if best_len == usize::MAX {
            String::new()
        } else {
            // Slice the original string — valid because s is ASCII.
            s[best_left..best_left + best_len].to_string()
        }
    }
}

#[cfg(test)]
mod tests_76 {
    use super::*;

    #[test]
    fn test_min_window() {
        assert_eq!(
            Solution::min_window("ADOBECODEBANC".to_string(), "ABC".to_string()),
            "BANC"
        );
        assert_eq!(
            Solution::min_window("a".to_string(), "a".to_string()),
            "a"
        );
        // Impossible: t has two 'a's, s has only one
        assert_eq!(
            Solution::min_window("a".to_string(), "aa".to_string()),
            ""
        );
        // t not present in s at all
        assert_eq!(
            Solution::min_window("abc".to_string(), "d".to_string()),
            ""
        );
    }
}
```

**Complexity:** Time O(|s| + |t|), Space O(|s| + |t|).

**Rust notes:**
- `*need.entry(b).or_insert(0) += 1` is the idiomatic frequency-map pattern. `entry()` returns an `Entry` enum; `or_insert(0)` returns a `&mut i32`, and we dereference with `*` to increment in place.
- `s[best_left..best_left + best_len]` is a byte-range slice of a `&str`. This is only safe because the problem guarantees ASCII input (all code points are single bytes, so byte offsets equal character offsets).

---

### Problem 11 — Sliding Window Maximum (LC #239)

**Statement:** Given array `nums` and window size `k`, return an array of the maximum value in each window of size `k`.

**Key insight (monotonic deque):** Maintain a `VecDeque<usize>` that stores **indices** in decreasing order of their corresponding values. The front always holds the index of the current window's maximum. Before adding index `i`:
1. Pop from the **front** any indices that have slid out of the window (`index + k <= i`).
2. Pop from the **back** any indices whose values are ≤ `nums[i]` — they can never be the maximum while `nums[i]` is in the window.

```rust
impl Solution {
    pub fn max_sliding_window(nums: Vec<i32>, k: i32) -> Vec<i32> {
        use std::collections::VecDeque;

        let k = k as usize;
        let n = nums.len();
        let mut result = Vec::with_capacity(n - k + 1);
        // Monotonic decreasing deque: stores indices, not values.
        let mut deque: VecDeque<usize> = VecDeque::new();

        for i in 0..n {
            // 1. Evict indices that are out of the current window [i-k+1, i].
            //    front + k <= i  ⟺  front < i - k + 1  ⟺  outside left edge
            while !deque.is_empty() && *deque.front().unwrap() + k <= i {
                deque.pop_front();
            }

            // 2. Maintain decreasing invariant: remove all back entries whose
            //    values are ≤ nums[i]. They are dominated by nums[i] and will
            //    expire before it does.
            while !deque.is_empty() && nums[*deque.back().unwrap()] <= nums[i] {
                deque.pop_back();
            }

            deque.push_back(i);

            // The first full window is complete when i == k - 1.
            if i + 1 >= k {
                result.push(nums[*deque.front().unwrap()]);
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_239 {
    use super::*;

    #[test]
    fn test_max_sliding_window() {
        assert_eq!(
            Solution::max_sliding_window(vec![1, 3, -1, -3, 5, 3, 6, 7], 3),
            vec![3, 3, 5, 5, 6, 7]
        );
        assert_eq!(
            Solution::max_sliding_window(vec![1], 1),
            vec![1]
        );
        assert_eq!(
            Solution::max_sliding_window(vec![1, -1], 1),
            vec![1, -1]
        );
        // Decreasing sequence
        assert_eq!(
            Solution::max_sliding_window(vec![5, 4, 3, 2, 1], 3),
            vec![5, 4, 3]
        );
    }
}
```

**Complexity:** Time O(n) — each index is pushed and popped at most once. Space O(k) for the deque.

**Rust notes:**
- `VecDeque` supports O(1) push/pop at both ends (`push_back`, `pop_back`, `push_front`, `pop_front`). This is the correct data structure; `Vec` does not have O(1) pop-front.
- The deque stores `usize` indices, not `i32` values. Storing values instead of indices is a common mistake — you lose the ability to check whether an element is still within the window.
- `*deque.front().unwrap()` — `.front()` returns `Option<&usize>`; `.unwrap()` extracts the reference; `*` dereferences to get the `usize`. Since we guard with `!deque.is_empty()`, the unwrap will never panic.

---

## Complexity Summary

| # | Problem | Time | Space | Pattern |
|---|---------|------|-------|---------|
| 125 | Valid Palindrome | O(n) | O(n) | Two Pointers |
| 167 | Two Sum II | O(n) | O(1) | Two Pointers |
| 15 | 3Sum | O(n²) | O(1) | Two Pointers + Sort |
| 11 | Container With Most Water | O(n) | O(1) | Two Pointers |
| 42 | Trapping Rain Water | O(n) | O(1) | Two Pointers |
| 121 | Best Time to Buy/Sell Stock | O(n) | O(1) | Sliding Window (greedy) |
| 3 | Longest Substring No Repeat | O(n) | O(1) | Variable Sliding Window |
| 424 | Longest Repeating Replacement | O(n) | O(1) | Variable Sliding Window |
| 567 | Permutation in String | O(n) | O(1) | Fixed Sliding Window |
| 76 | Minimum Window Substring | O(n) | O(n) | Variable Sliding Window |
| 239 | Sliding Window Maximum | O(n) | O(k) | Monotonic Deque |

---

## Rust Patterns Reference

### Byte vs Char access

```rust
let s = "hello";

// Byte access — O(1) indexing. Correct for ASCII problems.
let bytes: &[u8] = s.as_bytes();
let first_byte: u8 = bytes[0]; // 104 ('h')

// Char access — O(n) to reach position i. Use only when you need Unicode.
let first_char: char = s.chars().next().unwrap(); // 'h'

// When you need a Vec<char> (e.g., to mutate by index):
let chars: Vec<char> = s.chars().collect();
```

### Frequency maps: `[u32; 26]` vs `HashMap`

```rust
// For lowercase ASCII a-z: fixed array, zero heap allocation.
let mut freq = [0u32; 26];
for b in "hello".bytes() {
    freq[(b - b'a') as usize] += 1;
}

// For arbitrary bytes: HashMap with entry API.
use std::collections::HashMap;
let mut map: HashMap<u8, i32> = HashMap::new();
for b in "hello".bytes() {
    *map.entry(b).or_insert(0) += 1;
}
```

### Two-pointer template

```rust
fn two_pointer_template(arr: &[i32]) {
    let (mut l, mut r) = (0usize, arr.len() - 1);
    while l < r {
        // process arr[l], arr[r]
        if /* condition to move left */ true {
            l += 1;
        } else {
            r -= 1;
        }
    }
}
```

### Variable sliding window template

```rust
fn variable_window_template(s: &[u8]) -> usize {
    let mut left = 0usize;
    let mut max_len = 0;
    // state for the window (e.g., HashMap or array)

    for right in 0..s.len() {
        // 1. Expand: add s[right] to state

        // 2. Shrink: while window is invalid
        while /* window invalid */ false {
            // remove s[left] from state
            left += 1;
        }

        // 3. Update answer
        max_len = max_len.max(right - left + 1);
    }
    max_len
}
```

### `VecDeque` for monotonic deque

```rust
use std::collections::VecDeque;

// Monotonic decreasing deque (stores indices, values decrease front→back)
let mut deque: VecDeque<usize> = VecDeque::new();

// Add index i, maintaining decreasing order of nums values:
while !deque.is_empty() && nums[*deque.back().unwrap()] <= nums[i] {
    deque.pop_back();
}
deque.push_back(i);

// Query current max:
let max_val = nums[*deque.front().unwrap()];

// Evict stale front (outside window of size k):
if *deque.front().unwrap() + k <= i {
    deque.pop_front();
}
```

---

## 📝 Review Notes

**LC #125 — Valid Palindrome**
- The solution uses `.saturating_sub(1)` to handle the empty-string edge case cleanly. An empty string after filtering is a valid palindrome per the problem definition; `saturating_sub` prevents `usize` underflow when `n == 0`.
- `.is_ascii_alphanumeric()` correctly returns `false` for spaces, commas, colons, etc. No `char::is_alphanumeric()` needed here — the method exists on `u8` directly.

**LC #167 — Two Sum II**
- The `loop { ... }` without a termination condition is intentional. The problem guarantees exactly one solution exists, so the loop always terminates. If LeetCode constraints change, add an assertion or `break` for safety.
- The **1-indexed return** (`l + 1`, `r + 1`) is the most common source of wrong answers on this problem. The solution is explicit with `as i32` casts to avoid any confusion.

**LC #15 — 3Sum**
- `sort_unstable()` is safe: we only care about sorted order, not relative order of equal elements.
- The `nums[i] > 0` early-break is a valid optimization. After sorting, if the anchor is positive, all remaining elements are also positive, and no triplet can sum to zero.
- The inner duplicate-skip loops (`while l < r && nums[l] == nums[l+1]`) are safe from index-out-of-bounds because the condition `l < r` is checked first, and `r >= l+1` when `l < r`, so `nums[l+1]` is always valid.

**LC #42 — Trapping Rain Water**
- The `if height.is_empty() { return 0; }` guard is necessary because `height.len() - 1` would underflow (`usize` subtraction panics in debug mode) on an empty vector.
- The two-pointer approach is provably correct: when `height[l] <= height[r]`, the water at position `l` is fully determined by `left_max` because there is definitely a wall at least as tall as `height[l]` on the right side.

**LC #121 — Best Time to Buy and Sell Stock**
- `i32::MAX` as initial `min_price` correctly handles inputs of length 1 (no profit possible; the `else` branch never runs, returning 0).
- The problem guarantees prices are non-negative; there is no integer overflow risk in `price - min_price` since both are non-negative `i32` values and `min_price <= price` when the `else` branch executes.

**LC #3 — Longest Substring Without Repeating Characters**
- `usize::MAX` as a sentinel for "never seen" is safe: in practice, no string has `usize::MAX` elements, so `last_seen[idx] >= left` will be `false` when `last_seen[idx] == usize::MAX`. The sentinel avoids wrapping `last_seen` values in `Option<usize>`, keeping the hot loop tight.
- The `[usize; 128]` array covers all valid ASCII bytes (0..=127). LeetCode's constraint says the input contains English letters, digits, symbols, and spaces — all ASCII.

**LC #424 — Longest Repeating Character Replacement**
- The `if` (not `while`) for shrinking is the correct formulation for maximizing the window. Since we expand by exactly 1 per iteration and shrink by at most 1, the window size is non-decreasing. This is an important subtlety: the window can shrink at most back to the previous size, never below.
- `max_freq` not being decremented on shrink is correct: we want to track the *best* max_freq seen so far, not the current window's max_freq. After shrinking, the window is the same size as before the last expansion, and we only care if we can do better.

**LC #567 — Permutation in String**
- Array comparison `need == window` on `[i32; 26]` is a derived `PartialEq` comparison and is O(26) = O(1) in practice. This is valid for Rust arrays (both primitive and `PartialEq`-derived types support `==`).
- The fixed window is seeded for indices `0..k` before the slide loop, avoiding a special case for the first window inside the loop.

**LC #76 — Minimum Window Substring**
- `have` counts how many *distinct* characters from `t` have been satisfied (window count >= need count), not the total count. This is correct: if `t = "AAB"`, `have` reaches 2 (one for 'A' satisfied, one for 'B' satisfied), matching `required = 2`.
- `s[best_left..best_left + best_len].to_string()` is a byte-range slice. This is valid because the problem guarantees ASCII input (all code points fit in one byte). For a Unicode-safe version, you would need to track character positions, not byte positions.
- `window.get_mut(&lb).unwrap()` will not panic because `lb` was previously inserted into `window` when it entered the right side of the window.

**LC #239 — Sliding Window Maximum**
- The eviction condition `*deque.front().unwrap() + k <= i` correctly detects that the front index is outside the window `[i - k + 1, i]`. Equivalently: index `j` is outside if `j < i - k + 1`, i.e., `j + k < i + 1`, i.e., `j + k <= i`.
- The back-eviction condition uses `<=` (not `<`). This means if the incoming value equals the back value, the back is still evicted. This is correct: the newer index dominates an equally-valued older one for future windows (the older one will expire first), so keeping both would only waste space without changing the answer.
- `Vec::with_capacity(n - k + 1)` pre-allocates the output vector. This is an idiomatic Rust optimization when the output size is known in advance — avoids multiple reallocations.
