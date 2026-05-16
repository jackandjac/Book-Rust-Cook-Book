# Chapter LC-08: Dynamic Programming

> **Cookbook Philosophy:** LeetCode problems distilled for Java developers learning Rust. Every solution is self-contained and runnable with `rustc --test <file>` or inside a Cargo project. Focus is on idiomatic Rust — not just "making it work," but showing Rust's actual strengths.

---

## Problem Overview

### 1-D Dynamic Programming

| # | Problem | Difficulty | Blind75 | NeetCode150 |
|---|---------|-----------|---------|-------------|
| LC 70 | [Climbing Stairs](#lc-70--climbing-stairs) | Easy | ✓ | ✓ |
| LC 746 | [Min Cost Climbing Stairs](#lc-746--min-cost-climbing-stairs) | Easy | ✓ | ✓ |
| LC 198 | [House Robber](#lc-198--house-robber) | Medium | ✓ | ✓ |
| LC 213 | [House Robber II](#lc-213--house-robber-ii) | Medium | ✓ | ✓ |
| LC 5 | [Longest Palindromic Substring](#lc-5--longest-palindromic-substring) | Medium | ✓ | ✓ |
| LC 647 | [Palindromic Substrings](#lc-647--palindromic-substrings) | Medium | ✓ | ✓ |
| LC 91 | [Decode Ways](#lc-91--decode-ways) | Medium | ✓ | ✓ |
| LC 322 | [Coin Change](#lc-322--coin-change) | Medium | ✓ | ✓ |
| LC 152 | [Maximum Product Subarray](#lc-152--maximum-product-subarray) | Medium | ✓ | ✓ |
| LC 139 | [Word Break](#lc-139--word-break) | Medium | ✓ | ✓ |
| LC 300 | [Longest Increasing Subsequence](#lc-300--longest-increasing-subsequence) | Medium | ✓ | ✓ |
| LC 416 | [Partition Equal Subset Sum](#lc-416--partition-equal-subset-sum) | Medium | ✓ | ✓ |

### 2-D Dynamic Programming

| # | Problem | Difficulty | Blind75 | NeetCode150 |
|---|---------|-----------|---------|-------------|
| LC 62 | [Unique Paths](#lc-62--unique-paths) | Medium | ✓ | ✓ |
| LC 1143 | [Longest Common Subsequence](#lc-1143--longest-common-subsequence) | Medium | ✓ | ✓ |
| LC 309 | [Best Time to Buy and Sell Stock with Cooldown](#lc-309--best-time-to-buy-and-sell-stock-with-cooldown) | Medium | ✓ | ✓ |
| LC 518 | [Coin Change II](#lc-518--coin-change-ii) | Medium | ✓ | ✓ |
| LC 494 | [Target Sum](#lc-494--target-sum) | Medium | ✓ | ✓ |
| LC 97 | [Interleaving String](#lc-97--interleaving-string) | Medium | ✓ | ✓ |
| LC 329 | [Longest Increasing Path in a Matrix](#lc-329--longest-increasing-path-in-a-matrix) | Hard | ✓ | ✓ |
| LC 115 | [Distinct Subsequences](#lc-115--distinct-subsequences) | Hard | ✓ | ✓ |
| LC 72 | [Edit Distance](#lc-72--edit-distance) | Medium | ✓ | ✓ |
| LC 312 | [Burst Balloons](#lc-312--burst-balloons) | Hard | ✓ | ✓ |
| LC 10 | [Regular Expression Matching](#lc-10--regular-expression-matching) | Hard | ✓ | ✓ |

---

## Java → Rust Quick Reference for This Chapter

| Java idiom | Rust equivalent | Notes |
|-----------|----------------|-------|
| `int[] dp = new int[n]` | `let mut dp = vec![0i32; n]` | `i32` for small counts; `i64` to avoid overflow |
| `int[][] dp = new int[m][n]` | `vec![vec![0i32; n]; m]` | Row-major; inner vec is one row |
| `Arrays.fill(dp, Integer.MAX_VALUE)` | `vec![i32::MAX; n]` | Use `i32::MAX` or `i64::MAX` |
| `Math.min(a, b)` | `a.min(b)` or `std::cmp::min(a, b)` | Method syntax works on primitives |
| `Math.max(a, b)` | `a.max(b)` or `std::cmp::max(a, b)` | Same |
| `s.charAt(i)` | `s.as_bytes()[i]` | For ASCII; returns `u8` |
| `s.substring(i, j)` | `&s[i..j]` | Byte slice; safe only on char boundaries |
| `dp[i-1]` inside a loop starting at 0 | Start loop at `1`, or use `.get(i-1)` | Underflow panics in debug, wraps in release |
| Checked arithmetic | `a.checked_add(b)` | Returns `Option<T>`; use when overflow is possible |

---

## 1-D Dynamic Programming

---

## LC 70 — Climbing Stairs

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

You are climbing a staircase with `n` steps. Each time you can climb 1 or 2 steps. In how many distinct ways can you reach the top?

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = number of distinct ways to reach step `i` |
| **Base cases** | `dp[0] = 1`, `dp[1] = 1` |
| **Transition** | `dp[i] = dp[i-1] + dp[i-2]` |
| **Answer** | `dp[n]` |

This is exactly the Fibonacci sequence shifted by one. Because each state only depends on the previous two, we can space-optimize to O(1).

### Rust Solution

```rust
struct Solution;

impl Solution {
    // O(n) time, O(1) space — rolling variables
    pub fn climb_stairs(n: i32) -> i32 {
        if n <= 2 {
            return n;
        }
        let (mut prev2, mut prev1) = (1i32, 2i32);
        for _ in 3..=n {
            let cur = prev1 + prev2;
            prev2 = prev1;
            prev1 = cur;
        }
        prev1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_base_cases() {
        assert_eq!(Solution::climb_stairs(1), 1);
        assert_eq!(Solution::climb_stairs(2), 2);
    }

    #[test]
    fn test_small() {
        assert_eq!(Solution::climb_stairs(3), 3);
        assert_eq!(Solution::climb_stairs(4), 5);
        assert_eq!(Solution::climb_stairs(5), 8);
    }

    #[test]
    fn test_larger() {
        assert_eq!(Solution::climb_stairs(10), 89);
        assert_eq!(Solution::climb_stairs(45), 1836311903);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Rolling variables | O(n) | O(1) |

### Rust Notes

- Tuple destructuring `(mut prev2, mut prev1) = (1, 2)` allows simultaneous initialization — cleaner than two separate `let` statements.
- `3..=n` is an inclusive range; `3..n` would miss the last step.

---

## LC 746 — Min Cost Climbing Stairs

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an array `cost` where `cost[i]` is the cost of stepping on stair `i`, you can start from index 0 or 1. After paying `cost[i]` you may climb 1 or 2 steps. Find the minimum cost to reach the top (one step past the last index).

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = minimum cost to reach step `i` |
| **Base cases** | `dp[0] = cost[0]`, `dp[1] = cost[1]` |
| **Transition** | `dp[i] = cost[i] + min(dp[i-1], dp[i-2])` |
| **Answer** | `min(dp[n-1], dp[n-2])` |

### Rust Solution

```rust
use std::cmp::min;

struct Solution;

impl Solution {
    pub fn min_cost_climbing_stairs(cost: Vec<i32>) -> i32 {
        let n = cost.len();
        // Space-optimized: track only the last two costs
        let (mut a, mut b) = (cost[0], cost[1]);
        for i in 2..n {
            let cur = cost[i] + min(a, b);
            a = b;
            b = cur;
        }
        min(a, b)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::min_cost_climbing_stairs(vec![10, 15, 20]), 15);
    }

    #[test]
    fn test_example2() {
        assert_eq!(
            Solution::min_cost_climbing_stairs(vec![1, 100, 1, 1, 1, 100, 1, 1, 100, 1]),
            6
        );
    }

    #[test]
    fn test_two_steps() {
        assert_eq!(Solution::min_cost_climbing_stairs(vec![0, 0]), 0);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Rolling variables | O(n) | O(1) |

### Rust Notes

- `std::cmp::min` is brought in with `use`; alternatively use the method `a.min(b)` directly on primitive integers.
- Array indexing `cost[0]` panics on empty input — LeetCode guarantees `n >= 2`.

---

## LC 198 — House Robber

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an array `nums` of non-negative integers representing the money in each house, return the maximum amount you can rob without robbing two adjacent houses.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = max money robbing houses `0..=i` |
| **Base cases** | `dp[0] = nums[0]`, `dp[1] = max(nums[0], nums[1])` |
| **Transition** | `dp[i] = max(dp[i-1], dp[i-2] + nums[i])` |
| **Answer** | `dp[n-1]` |

The choice at each house: skip it (take `dp[i-1]`) or rob it (take `dp[i-2] + nums[i]`).

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn rob(nums: Vec<i32>) -> i32 {
        let n = nums.len();
        if n == 1 {
            return nums[0];
        }
        let (mut prev2, mut prev1) = (nums[0], nums[0].max(nums[1]));
        for i in 2..n {
            let cur = prev1.max(prev2 + nums[i]);
            prev2 = prev1;
            prev1 = cur;
        }
        prev1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::rob(vec![1, 2, 3, 1]), 4);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::rob(vec![2, 7, 9, 3, 1]), 12);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::rob(vec![5]), 5);
    }

    #[test]
    fn test_two() {
        assert_eq!(Solution::rob(vec![2, 1]), 2);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Rolling variables | O(n) | O(1) |

### Rust Notes

- `.max()` is a method on all `Ord` primitives — prefer it over `std::cmp::max` for chaining.
- The `if n == 1` guard prevents indexing `nums[1]` on a single-element slice.

---

## LC 213 — House Robber II

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Same as House Robber, but the houses are arranged in a circle — the first and last house are adjacent. Return the maximum amount you can rob.

### DP Design

A circular constraint means you cannot rob both `nums[0]` and `nums[n-1]`. The solution is to run the linear House Robber twice:
1. Over `nums[0..n-1]` (exclude last house)
2. Over `nums[1..n]` (exclude first house)

Return the maximum of the two runs.

| | Value |
|-|-------|
| **State** | Same as LC 198 applied on a subarray |
| **Answer** | `max(rob_linear(nums[0..n-1]), rob_linear(nums[1..n]))` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn rob(nums: Vec<i32>) -> i32 {
        let n = nums.len();
        if n == 1 {
            return nums[0];
        }
        if n == 2 {
            return nums[0].max(nums[1]);
        }
        Self::rob_range(&nums, 0, n - 1).max(Self::rob_range(&nums, 1, n))
    }

    // Rob houses in nums[start..end] (half-open range)
    fn rob_range(nums: &[i32], start: usize, end: usize) -> i32 {
        let slice = &nums[start..end];
        let (mut prev2, mut prev1) = (slice[0], slice[0].max(slice[1]));
        for i in 2..slice.len() {
            let cur = prev1.max(prev2 + slice[i]);
            prev2 = prev1;
            prev1 = cur;
        }
        prev1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::rob(vec![2, 3, 2]), 3);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::rob(vec![1, 2, 3, 1]), 4);
    }

    #[test]
    fn test_example3() {
        assert_eq!(Solution::rob(vec![1, 2, 3]), 3);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::rob(vec![5]), 5);
    }

    #[test]
    fn test_two() {
        assert_eq!(Solution::rob(vec![2, 1]), 2);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Two linear passes | O(n) | O(1) |

### Rust Notes

- Slices (`&[i32]`) let `rob_range` borrow any contiguous subrange without copying — pass `&nums[0..n-1]` or just use explicit `start`/`end` indices as shown.
- Passing `&[i32]` (slice reference) instead of `&Vec<i32>` is idiomatic Rust; slices are more general and avoid an extra level of indirection.

---

## LC 5 — Longest Palindromic Substring

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given a string `s`, return the longest palindromic substring.

### DP Design

**Expand-around-center** approach (O(n) space, simpler than the full 2-D DP table):

For each center position (single character or between two characters), expand outward as long as the characters match. Track the longest palindrome found.

| | Value |
|-|-------|
| **State** | `(start, max_len)` of best palindrome found so far |
| **Transition** | Expand `[l, r]` while `s[l] == s[r]` |
| **Answer** | `s[start..start+max_len]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn longest_palindrome(s: String) -> String {
        let b = s.as_bytes();
        let n = b.len();
        let (mut best_start, mut best_len) = (0usize, 1usize);

        let mut expand = |mut l: usize, mut r: usize| {
            // l uses wrapping arithmetic to handle l == 0 underflow
            while r < n && b[l] == b[r] {
                if r - l + 1 > best_len {
                    best_len = r - l + 1;
                    best_start = l;
                }
                if l == 0 {
                    break;
                }
                l -= 1;
                r += 1;
            }
        };

        for i in 0..n {
            expand(i, i);           // odd-length centers
            if i + 1 < n {
                expand(i, i + 1);   // even-length centers
            }
        }

        s[best_start..best_start + best_len].to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        let result = Solution::longest_palindrome("babad".to_string());
        assert!(result == "bab" || result == "aba");
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::longest_palindrome("cbbd".to_string()), "bb");
    }

    #[test]
    fn test_single_char() {
        assert_eq!(Solution::longest_palindrome("a".to_string()), "a");
    }

    #[test]
    fn test_all_same() {
        assert_eq!(Solution::longest_palindrome("aaaa".to_string()), "aaaa");
    }

    #[test]
    fn test_even_palindrome() {
        assert_eq!(Solution::longest_palindrome("abccba".to_string()), "abccba");
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Expand-around-center | O(n²) | O(1) |
| Manacher's algorithm | O(n) | O(n) |

### Rust Notes

- Closures can capture mutable variables from the enclosing scope with `|..| { ... }`. Here `expand` captures `best_start` and `best_len` mutably.
- `.as_bytes()` gives `&[u8]` — byte indexing is safe for ASCII and avoids `char` boundary issues.
- `usize` subtraction can panic on underflow; the `if l == 0 { break; }` guard prevents `l -= 1` from wrapping.

---

## LC 647 — Palindromic Substrings

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given a string `s`, return the number of palindromic substrings it contains.

### DP Design

Same expand-around-center technique as LC 5 — count every palindrome found during expansion.

| | Value |
|-|-------|
| **State** | `count` of palindromes found |
| **Transition** | Expand from each center; increment `count` per valid palindrome |
| **Answer** | `count` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn count_substrings(s: String) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        let mut count = 0i32;

        let mut expand = |mut l: usize, mut r: usize| {
            while r < n && b[l] == b[r] {
                count += 1;
                if l == 0 {
                    break;
                }
                l -= 1;
                r += 1;
            }
        };

        for i in 0..n {
            expand(i, i);
            if i + 1 < n {
                expand(i, i + 1);
            }
        }

        count
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::count_substrings("abc".to_string()), 3);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::count_substrings("aaa".to_string()), 6);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::count_substrings("a".to_string()), 1);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Expand-around-center | O(n²) | O(1) |

### Rust Notes

- Mutable closures that capture a counter are common in Rust for in-place accumulation. The closure borrows `count` mutably and `b`/`n` immutably — Rust enforces these are non-overlapping.

---

## LC 91 — Decode Ways

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

A message is encoded as a non-empty string of digits where `'A' → 1`, ..., `'Z' → 26`. Return the number of ways to decode it. `'0'` alone is invalid; leading zeros in a two-digit group are invalid.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = number of ways to decode `s[0..i]` |
| **Base cases** | `dp[0] = 1` (empty prefix), `dp[1] = 1` if `s[0] != '0'` else `0` |
| **Transition** | One-digit decode: if `s[i-1] != '0'`, add `dp[i-1]`. Two-digit decode: if `s[i-2..i]` is `"10"..="26"`, add `dp[i-2]` |
| **Answer** | `dp[n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn num_decodings(s: String) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        // dp[i] = ways to decode s[0..i]
        let mut dp = vec![0i32; n + 1];
        dp[0] = 1;
        dp[1] = if b[0] != b'0' { 1 } else { 0 };

        for i in 2..=n {
            // Single-digit decode of s[i-1]
            if b[i - 1] != b'0' {
                dp[i] += dp[i - 1];
            }
            // Two-digit decode of s[i-2..i]
            let two_digit = (b[i - 2] - b'0') * 10 + (b[i - 1] - b'0');
            if two_digit >= 10 && two_digit <= 26 {
                dp[i] += dp[i - 2];
            }
        }

        dp[n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::num_decodings("12".to_string()), 2); // "AB" or "L"
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::num_decodings("226".to_string()), 3); // "BZ","VF","BBF"
    }

    #[test]
    fn test_leading_zero() {
        assert_eq!(Solution::num_decodings("06".to_string()), 0);
    }

    #[test]
    fn test_zero_in_middle() {
        assert_eq!(Solution::num_decodings("10".to_string()), 1);
    }

    #[test]
    fn test_all_ones() {
        assert_eq!(Solution::num_decodings("1111".to_string()), 5);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Bottom-up DP | O(n) | O(n) |
| Rolling two vars | O(n) | O(1) |

### Rust Notes

- `b'0'` is a byte literal for the ASCII character `'0'`. Subtracting `b'0'` from a digit byte yields the numeric value as `u8`.
- Arithmetic on `u8` can overflow — here values are bounded to `0..=9`, so multiplication by 10 and addition stay within `u8` range safely.

---

## LC 322 — Coin Change

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given coin denominations `coins` and a target `amount`, return the fewest number of coins needed to make the amount. Return `-1` if it is not possible.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = minimum coins to make amount `i` |
| **Base cases** | `dp[0] = 0`; all others initialized to `amount + 1` (sentinel "infinity") |
| **Transition** | For each coin `c`: `dp[i] = min(dp[i], dp[i - c] + 1)` if `i >= c` |
| **Answer** | `dp[amount]` if `< amount + 1`, else `-1` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn coin_change(coins: Vec<i32>, amount: i32) -> i32 {
        let amount = amount as usize;
        let inf = amount + 1;
        let mut dp = vec![inf; amount + 1];
        dp[0] = 0;

        for i in 1..=amount {
            for &coin in &coins {
                let coin = coin as usize;
                if coin <= i {
                    dp[i] = dp[i].min(dp[i - coin] + 1);
                }
            }
        }

        if dp[amount] < inf { dp[amount] as i32 } else { -1 }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::coin_change(vec![1, 2, 5], 11), 3); // 5+5+1
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::coin_change(vec![2], 3), -1);
    }

    #[test]
    fn test_zero_amount() {
        assert_eq!(Solution::coin_change(vec![1], 0), 0);
    }

    #[test]
    fn test_single_coin_exact() {
        assert_eq!(Solution::coin_change(vec![5], 5), 1);
    }

    #[test]
    fn test_large() {
        assert_eq!(Solution::coin_change(vec![1, 2, 5], 100), 20);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Bottom-up DP | O(amount × |coins|) | O(amount) |

### Rust Notes

- Using `amount + 1` as the sentinel avoids `i32::MAX` and prevents overflow when doing `dp[i-c] + 1`.
- `&coin` in `for &coin in &coins` destructures the reference, giving `coin: i32` directly — equivalent to `for coin in coins.iter() { let coin = *coin; ... }` but more concise.

---

## LC 152 — Maximum Product Subarray

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums`, find the contiguous subarray with the largest product and return that product.

### DP Design

Track both the maximum and minimum products ending at each position (minimum matters because two negatives multiply to a positive).

| | Value |
|-|-------|
| **State** | `(cur_max, cur_min)` = max/min product of subarray ending at index `i` |
| **Base cases** | `cur_max = cur_min = nums[0]` |
| **Transition** | `new_max = max(nums[i], cur_max * nums[i], cur_min * nums[i])` |
| **Answer** | Running `global_max` updated each iteration |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn max_product(nums: Vec<i32>) -> i32 {
        let (mut cur_max, mut cur_min) = (nums[0], nums[0]);
        let mut global_max = nums[0];

        for &n in &nums[1..] {
            // All three candidates for new max/min
            let candidates = [n, cur_max * n, cur_min * n];
            let new_max = *candidates.iter().max().unwrap();
            let new_min = *candidates.iter().min().unwrap();
            cur_max = new_max;
            cur_min = new_min;
            global_max = global_max.max(cur_max);
        }

        global_max
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::max_product(vec![2, 3, -2, 4]), 6);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::max_product(vec![-2, 0, -1]), 0);
    }

    #[test]
    fn test_all_negative() {
        assert_eq!(Solution::max_product(vec![-2, -3, -4]), 12);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::max_product(vec![-3]), -3);
    }

    #[test]
    fn test_with_zero() {
        assert_eq!(Solution::max_product(vec![0, 2]), 2);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Single pass | O(n) | O(1) |

### Rust Notes

- Array literal `[n, cur_max * n, cur_min * n]` lives on the stack. Calling `.iter().max()` on it returns `Option<&i32>`, so `unwrap()` is safe (the array is always non-empty) and `*` dereferences the reference.
- `nums[1..]` is a slice skipping the first element — no index arithmetic needed.

---

## LC 139 — Word Break

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given a string `s` and a dictionary `word_dict`, return `true` if `s` can be segmented into one or more dictionary words.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = `true` if `s[0..i]` can be segmented |
| **Base cases** | `dp[0] = true` (empty string) |
| **Transition** | `dp[i] = true` if any `j < i` where `dp[j]` is `true` and `s[j..i]` is in the dictionary |
| **Answer** | `dp[n]` |

### Rust Solution

```rust
use std::collections::HashSet;

struct Solution;

impl Solution {
    pub fn word_break(s: String, word_dict: Vec<String>) -> bool {
        let dict: HashSet<&str> = word_dict.iter().map(|w| w.as_str()).collect();
        let n = s.len();
        let mut dp = vec![false; n + 1];
        dp[0] = true;

        for i in 1..=n {
            for j in 0..i {
                if dp[j] && dict.contains(&s[j..i]) {
                    dp[i] = true;
                    break;
                }
            }
        }

        dp[n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(
            Solution::word_break(
                "leetcode".to_string(),
                vec!["leet".to_string(), "code".to_string()]
            ),
            true
        );
    }

    #[test]
    fn test_example2() {
        assert_eq!(
            Solution::word_break(
                "applepenapple".to_string(),
                vec!["apple".to_string(), "pen".to_string()]
            ),
            true
        );
    }

    #[test]
    fn test_false_case() {
        assert_eq!(
            Solution::word_break(
                "catsandog".to_string(),
                vec!["cats".to_string(), "dog".to_string(), "sand".to_string(), "and".to_string(), "cat".to_string()]
            ),
            false
        );
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| O(n² × w) where w = avg word length | O(n²) | O(n + dict size) |

### Rust Notes

- `dict.contains(&s[j..i])` — the `HashSet<&str>` lookup takes a `&&str`, but Rust's `Borrow` trait allows `contains` to accept `&str` via `&&str` coercion automatically.
- Storing `&str` references into the set avoids cloning; the `word_dict` Vec outlives the `dict` set.

---

## LC 300 — Longest Increasing Subsequence

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums`, return the length of the longest strictly increasing subsequence.

### DP Design

**O(n²) DP approach:**

| | Value |
|-|-------|
| **State** | `dp[i]` = length of LIS ending at index `i` |
| **Base cases** | `dp[i] = 1` for all `i` |
| **Transition** | `dp[i] = max(dp[j] + 1)` for all `j < i` where `nums[j] < nums[i]` |
| **Answer** | `max(dp)` |

**O(n log n) patience sorting approach** is shown as an alternative.

### Rust Solution

```rust
struct Solution;

impl Solution {
    // O(n^2) DP
    pub fn length_of_lis(nums: Vec<i32>) -> i32 {
        let n = nums.len();
        let mut dp = vec![1i32; n];

        for i in 1..n {
            for j in 0..i {
                if nums[j] < nums[i] {
                    dp[i] = dp[i].max(dp[j] + 1);
                }
            }
        }

        *dp.iter().max().unwrap()
    }

    // O(n log n) patience sort / binary search
    pub fn length_of_lis_fast(nums: Vec<i32>) -> i32 {
        let mut tails: Vec<i32> = Vec::new(); // tails[i] = smallest tail of IS of length i+1
        for &n in &nums {
            // Binary search for leftmost tail >= n
            let pos = tails.partition_point(|&t| t < n);
            if pos == tails.len() {
                tails.push(n);
            } else {
                tails[pos] = n;
            }
        }
        tails.len() as i32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::length_of_lis(vec![10, 9, 2, 5, 3, 7, 101, 18]), 4);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::length_of_lis(vec![0, 1, 0, 3, 2, 3]), 4);
    }

    #[test]
    fn test_all_same() {
        assert_eq!(Solution::length_of_lis(vec![7, 7, 7, 7]), 1);
    }

    #[test]
    fn test_fast_example1() {
        assert_eq!(Solution::length_of_lis_fast(vec![10, 9, 2, 5, 3, 7, 101, 18]), 4);
    }

    #[test]
    fn test_fast_example2() {
        assert_eq!(Solution::length_of_lis_fast(vec![0, 1, 0, 3, 2, 3]), 4);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| O(n²) DP | O(n²) | O(n) |
| O(n log n) patience sort | O(n log n) | O(n) |

### Rust Notes

- `Vec::partition_point` (stable since Rust 1.52) performs a binary search returning the first index where the predicate is false — a clean replacement for `binary_search` in this pattern.
- `*dp.iter().max().unwrap()` — `.max()` on an iterator returns `Option<&i32>`; unwrap and deref give the `i32`.

---

## LC 416 — Partition Equal Subset Sum

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given a non-empty array `nums` of positive integers, determine if it can be partitioned into two subsets with equal sum.

### DP Design

This is a 0/1 knapsack problem. If the total sum is odd, return false immediately. Otherwise, find if any subset sums to `total / 2`.

| | Value |
|-|-------|
| **State** | `dp[j]` = `true` if sum `j` is achievable from the numbers processed so far |
| **Base cases** | `dp[0] = true` |
| **Transition** | For each number `n`, iterate `j` from `target` down to `n`: `dp[j] \|= dp[j - n]` |
| **Answer** | `dp[target]` |

Iterating backwards prevents using a number more than once (0/1 knapsack).

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn can_partition(nums: Vec<i32>) -> bool {
        let total: i32 = nums.iter().sum();
        if total % 2 != 0 {
            return false;
        }
        let target = (total / 2) as usize;
        let mut dp = vec![false; target + 1];
        dp[0] = true;

        for &n in &nums {
            let n = n as usize;
            // Traverse backwards to avoid reusing the same element
            for j in (n..=target).rev() {
                dp[j] = dp[j] || dp[j - n];
            }
            if dp[target] {
                return true; // Early exit
            }
        }

        dp[target]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::can_partition(vec![1, 5, 11, 5]), true);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::can_partition(vec![1, 2, 3, 5]), false);
    }

    #[test]
    fn test_odd_sum() {
        assert_eq!(Solution::can_partition(vec![1, 1, 1]), false);
    }

    #[test]
    fn test_two_equal() {
        assert_eq!(Solution::can_partition(vec![3, 3]), true);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 1-D 0/1 knapsack | O(n × target) | O(target) |

### Rust Notes

- `(n..=target).rev()` produces a reversed inclusive range — iterating backwards is idiomatic and avoids the need for a 2-D DP table.
- `nums.iter().sum()` infers `i32` from the element type; the return type annotation is not needed thanks to type inference from `total % 2`.

---

## 2-D Dynamic Programming

---

## LC 62 — Unique Paths

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

A robot starts at the top-left of an `m × n` grid and can only move right or down. How many unique paths are there to reach the bottom-right corner?

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = number of paths to cell `(i, j)` |
| **Base cases** | `dp[0][j] = 1` (top row), `dp[i][0] = 1` (left column) |
| **Transition** | `dp[i][j] = dp[i-1][j] + dp[i][j-1]` |
| **Answer** | `dp[m-1][n-1]` |

Space-optimized to a single row using a rolling array.

### Rust Solution

```rust
struct Solution;

impl Solution {
    // Space-optimized: O(n) space
    pub fn unique_paths(m: i32, n: i32) -> i32 {
        let (m, n) = (m as usize, n as usize);
        let mut dp = vec![1i32; n]; // top row is all 1s

        for _ in 1..m {
            for j in 1..n {
                dp[j] += dp[j - 1]; // dp[j] holds "from above", dp[j-1] "from left"
            }
        }

        dp[n - 1]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::unique_paths(3, 7), 28);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::unique_paths(3, 2), 3);
    }

    #[test]
    fn test_single_row() {
        assert_eq!(Solution::unique_paths(1, 5), 1);
    }

    #[test]
    fn test_single_col() {
        assert_eq!(Solution::unique_paths(5, 1), 1);
    }

    #[test]
    fn test_square() {
        assert_eq!(Solution::unique_paths(3, 3), 6);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 2-D DP | O(m × n) | O(m × n) |
| Rolling row | O(m × n) | O(n) |

### Rust Notes

- `vec![1i32; n]` initializes all elements to `1`, handling the base case of the top row in one line.
- The rolling-row trick: before the inner loop, `dp[j]` holds the value from the row above; after the update it holds the current row's value.

---

## LC 1143 — Longest Common Subsequence

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given strings `text1` and `text2`, return the length of their longest common subsequence. A subsequence does not need to be contiguous.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = LCS length of `text1[0..i]` and `text2[0..j]` |
| **Base cases** | `dp[0][j] = 0`, `dp[i][0] = 0` |
| **Transition** | If `text1[i-1] == text2[j-1]`: `dp[i][j] = dp[i-1][j-1] + 1`; else `dp[i][j] = max(dp[i-1][j], dp[i][j-1])` |
| **Answer** | `dp[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn longest_common_subsequence(text1: String, text2: String) -> i32 {
        let a = text1.as_bytes();
        let b = text2.as_bytes();
        let (m, n) = (a.len(), b.len());
        // dp[i][j]: LCS of text1[0..i] and text2[0..j]
        let mut dp = vec![vec![0i32; n + 1]; m + 1];

        for i in 1..=m {
            for j in 1..=n {
                dp[i][j] = if a[i - 1] == b[j - 1] {
                    dp[i - 1][j - 1] + 1
                } else {
                    dp[i - 1][j].max(dp[i][j - 1])
                };
            }
        }

        dp[m][n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(
            Solution::longest_common_subsequence("abcde".to_string(), "ace".to_string()),
            3
        );
    }

    #[test]
    fn test_example2() {
        assert_eq!(
            Solution::longest_common_subsequence("abc".to_string(), "abc".to_string()),
            3
        );
    }

    #[test]
    fn test_no_common() {
        assert_eq!(
            Solution::longest_common_subsequence("abc".to_string(), "def".to_string()),
            0
        );
    }

    #[test]
    fn test_one_char() {
        assert_eq!(
            Solution::longest_common_subsequence("a".to_string(), "a".to_string()),
            1
        );
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 2-D DP | O(m × n) | O(m × n) |
| Rolling row | O(m × n) | O(n) |

### Rust Notes

- `vec![vec![0i32; n + 1]; m + 1]` creates a `(m+1) × (n+1)` table with the +1 padding for the base case row/column, avoiding index-off-by-one guards.
- `if/else` expressions in Rust return values — the body of the `dp[i][j] = if ... { } else { }` is a single expression, not a statement.

---

## LC 309 — Best Time to Buy and Sell Stock with Cooldown

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

You may buy and sell stocks multiple times, but after selling you must wait one day (cooldown). You may not hold more than one share at a time. Find the maximum profit.

### DP Design

Three states per day:

| State | Meaning |
|-------|---------|
| `held` | Max profit when holding a stock |
| `sold` | Max profit on the day you just sold |
| `rest` | Max profit during cooldown or idle |

**Transitions:**
- `held' = max(held, rest - price)` — keep holding, or buy from rest state
- `sold' = held + price` — sell today
- `rest' = max(rest, sold)` — stay idle or come off cooldown

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn max_profit(prices: Vec<i32>) -> i32 {
        let (mut held, mut sold, mut rest) = (i32::MIN, 0, 0);

        for price in prices {
            let prev_sold = sold;
            sold = held + price;
            held = held.max(rest - price);
            rest = rest.max(prev_sold);
        }

        sold.max(rest)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::max_profit(vec![1, 2, 3, 0, 2]), 3);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::max_profit(vec![1]), 0);
    }

    #[test]
    fn test_decreasing() {
        assert_eq!(Solution::max_profit(vec![5, 4, 3, 2, 1]), 0);
    }

    #[test]
    fn test_two_prices() {
        assert_eq!(Solution::max_profit(vec![1, 2]), 1);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| State machine DP | O(n) | O(1) |

### Rust Notes

- `i32::MIN` as the initial `held` value represents "impossible" (you cannot hold a stock you haven't bought). `sold = held + price` on day 1 gives a large-negative value that never wins the final `max`, so it is harmless. Because LeetCode guarantees `price >= 1`, `i32::MIN + price` does not overflow (it yields at most `i32::MIN + 1`). For extra safety in general contexts, initialize `held = -prices[0]` and loop from index 1.
- `prev_sold` captures `sold` before it is overwritten — order of updates matters when reusing variables.

---

## LC 518 — Coin Change II

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given coin denominations and a target `amount`, return the number of distinct combinations of coins that sum to `amount`. Each coin can be used an unlimited number of times.

### DP Design

This is an unbounded knapsack problem. Iterate coins in the outer loop to count combinations (not permutations).

| | Value |
|-|-------|
| **State** | `dp[j]` = number of ways to make amount `j` |
| **Base cases** | `dp[0] = 1` |
| **Transition** | For each coin `c`, for `j` from `c` to `amount`: `dp[j] += dp[j - c]` |
| **Answer** | `dp[amount]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn change(amount: i32, coins: Vec<i32>) -> i32 {
        let amount = amount as usize;
        let mut dp = vec![0i32; amount + 1];
        dp[0] = 1;

        for &coin in &coins {
            let coin = coin as usize;
            for j in coin..=amount {
                dp[j] += dp[j - coin];
            }
        }

        dp[amount]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::change(5, vec![1, 2, 5]), 4);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::change(3, vec![2]), 0);
    }

    #[test]
    fn test_zero_amount() {
        assert_eq!(Solution::change(0, vec![1, 2, 3]), 1);
    }

    #[test]
    fn test_single_coin() {
        assert_eq!(Solution::change(10, vec![10]), 1);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Unbounded knapsack | O(amount × |coins|) | O(amount) |

### Rust Notes

- Outer loop over coins ensures each combination is counted once (not as permutations). Swapping the loop order would count `[1,2]` and `[2,1]` separately.
- Iterating forwards (not backwards) allows reuse of the same coin — this distinguishes unbounded from 0/1 knapsack.

---

## LC 494 — Target Sum

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an array `nums` and an integer `target`, assign `+` or `-` to each element. Return the number of ways to reach `target`.

### DP Design

Use a `HashMap` from current sum to number of ways. Avoids the complexity of offset-indexing into a fixed array.

| | Value |
|-|-------|
| **State** | `counts: HashMap<i32, i32>` mapping achievable sum → ways |
| **Base cases** | `counts = {0: 1}` |
| **Transition** | For each number, update all sums by ±n |
| **Answer** | `counts.get(&target).copied().unwrap_or(0)` |

### Rust Solution

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn find_target_sum_ways(nums: Vec<i32>, target: i32) -> i32 {
        let mut counts: HashMap<i32, i32> = HashMap::new();
        counts.insert(0, 1);

        for &n in &nums {
            let mut next: HashMap<i32, i32> = HashMap::new();
            for (&sum, &ways) in &counts {
                *next.entry(sum + n).or_insert(0) += ways;
                *next.entry(sum - n).or_insert(0) += ways;
            }
            counts = next;
        }

        counts.get(&target).copied().unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::find_target_sum_ways(vec![1, 1, 1, 1, 1], 3), 5);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::find_target_sum_ways(vec![1], 1), 1);
    }

    #[test]
    fn test_no_ways() {
        assert_eq!(Solution::find_target_sum_ways(vec![1], 2), 0);
    }

    #[test]
    fn test_zero_target() {
        assert_eq!(Solution::find_target_sum_ways(vec![1, 2, 3], 0), 2);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| HashMap DP | O(n × distinct sums) | O(distinct sums) |

### Rust Notes

- `.copied()` on `Option<&i32>` converts to `Option<i32>` — cleaner than `cloned()` for `Copy` types.
- The Entry API `*next.entry(key).or_insert(0) += ways` is the idiomatic way to accumulate counts without a redundant `contains_key` check.

---

## LC 97 — Interleaving String

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given strings `s1`, `s2`, and `s3`, determine if `s3` is formed by interleaving `s1` and `s2`.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = can `s3[0..i+j]` be formed by interleaving `s1[0..i]` and `s2[0..j]` |
| **Base cases** | `dp[0][0] = true` |
| **Transition** | `dp[i][j] = (dp[i-1][j] && s1[i-1] == s3[i+j-1]) || (dp[i][j-1] && s2[j-1] == s3[i+j-1])` |
| **Answer** | `dp[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn is_interleave(s1: String, s2: String, s3: String) -> bool {
        let (a, b, c) = (s1.as_bytes(), s2.as_bytes(), s3.as_bytes());
        let (m, n) = (a.len(), b.len());
        if m + n != c.len() {
            return false;
        }
        // Rolling 1-D DP over s2 dimension
        let mut dp = vec![false; n + 1];
        dp[0] = true;

        // Initialize first row: using only s2 to match s3 prefix
        for j in 1..=n {
            dp[j] = dp[j - 1] && b[j - 1] == c[j - 1];
        }

        for i in 1..=m {
            // Update dp[0]: using only s1 to match s3 prefix
            dp[0] = dp[0] && a[i - 1] == c[i - 1];
            for j in 1..=n {
                dp[j] = (dp[j] && a[i - 1] == c[i + j - 1])
                    || (dp[j - 1] && b[j - 1] == c[i + j - 1]);
            }
        }

        dp[n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(
            Solution::is_interleave("aabcc".to_string(), "dbbca".to_string(), "aadbbcbcac".to_string()),
            true
        );
    }

    #[test]
    fn test_example2() {
        assert_eq!(
            Solution::is_interleave("aabcc".to_string(), "dbbca".to_string(), "aadbbbaccc".to_string()),
            false
        );
    }

    #[test]
    fn test_empty_strings() {
        assert_eq!(
            Solution::is_interleave("".to_string(), "".to_string(), "".to_string()),
            true
        );
    }

    #[test]
    fn test_one_empty() {
        assert_eq!(
            Solution::is_interleave("ab".to_string(), "".to_string(), "ab".to_string()),
            true
        );
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 2-D DP | O(m × n) | O(m × n) |
| Rolling row | O(m × n) | O(n) |

### Rust Notes

- Rolling a 2-D DP to 1-D requires carefully updating `dp[0]` at the start of each outer iteration before the inner loop runs.
- `&&` short-circuits: `dp[j-1] && b[j-1] == c[i+j-1]` avoids the comparison if `dp[j-1]` is already `false`.

---

## LC 329 — Longest Increasing Path in a Matrix

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` integer matrix, find the length of the longest increasing path. From each cell you can move in four directions, but you cannot move diagonally or revisit cells.

### DP Design

Memoized DFS (top-down DP). The DAG property (strictly increasing means no cycles) guarantees termination.

| | Value |
|-|-------|
| **State** | `memo[i][j]` = length of longest increasing path starting at `(i, j)` |
| **Base cases** | Computed on return from DFS leaves |
| **Transition** | `memo[i][j] = 1 + max(dfs(neighbor))` for valid neighbors with larger value |
| **Answer** | `max over all (i, j) of memo[i][j]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn longest_increasing_path(matrix: Vec<Vec<i32>>) -> i32 {
        let m = matrix.len();
        let n = matrix[0].len();
        let mut memo = vec![vec![0i32; n]; m];
        let mut best = 0;

        for i in 0..m {
            for j in 0..n {
                let path = Self::dfs(&matrix, &mut memo, i, j, m, n);
                best = best.max(path);
            }
        }

        best
    }

    fn dfs(
        matrix: &Vec<Vec<i32>>,
        memo: &mut Vec<Vec<i32>>,
        r: usize,
        c: usize,
        m: usize,
        n: usize,
    ) -> i32 {
        if memo[r][c] != 0 {
            return memo[r][c];
        }
        let dirs: [(i32, i32); 4] = [(-1, 0), (1, 0), (0, -1), (0, 1)];
        let mut best = 1i32;

        for (dr, dc) in dirs {
            let nr = r as i32 + dr;
            let nc = c as i32 + dc;
            if nr >= 0 && nr < m as i32 && nc >= 0 && nc < n as i32 {
                let (nr, nc) = (nr as usize, nc as usize);
                if matrix[nr][nc] > matrix[r][c] {
                    let path = 1 + Self::dfs(matrix, memo, nr, nc, m, n);
                    best = best.max(path);
                }
            }
        }

        memo[r][c] = best;
        best
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(
            Solution::longest_increasing_path(vec![vec![9, 9, 4], vec![6, 6, 8], vec![2, 1, 1]]),
            4
        );
    }

    #[test]
    fn test_example2() {
        assert_eq!(
            Solution::longest_increasing_path(vec![vec![3, 4, 5], vec![3, 2, 6], vec![2, 2, 1]]),
            4
        );
    }

    #[test]
    fn test_single_cell() {
        assert_eq!(Solution::longest_increasing_path(vec![vec![1]]), 1);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Memoized DFS | O(m × n) | O(m × n) |

### Rust Notes

- `memo[r][c] != 0` is the memoization guard — works because any valid path has length >= 1, so 0 reliably signals "not yet computed."
- Checking bounds via `i32` arithmetic and then casting back to `usize` is the idiomatic pattern for grid neighbor traversal in Rust, avoiding the underflow pitfall of `usize` subtraction.

---

## LC 115 — Distinct Subsequences

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given strings `s` and `t`, return the number of distinct subsequences of `s` that equal `t`. The answer fits in a 32-bit integer.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = number of ways to form `t[0..j]` from `s[0..i]` |
| **Base cases** | `dp[i][0] = 1` for all `i` (empty `t` matched in one way) |
| **Transition** | If `s[i-1] == t[j-1]`: `dp[i][j] = dp[i-1][j-1] + dp[i-1][j]`; else `dp[i][j] = dp[i-1][j]` |
| **Answer** | `dp[m][n]` |

Use `u64` to avoid overflow for large inputs.

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn num_distinct(s: String, t: String) -> i32 {
        let (sa, ta) = (s.as_bytes(), t.as_bytes());
        let (m, n) = (sa.len(), ta.len());
        // Rolling 1-D DP: dp[j] = ways to form t[0..j] from s[0..i]
        let mut dp = vec![0u64; n + 1];
        dp[0] = 1;

        for i in 1..=m {
            // Traverse right-to-left to avoid using s[i-1] multiple times
            for j in (1..=n.min(i)).rev() {
                if sa[i - 1] == ta[j - 1] {
                    dp[j] += dp[j - 1];
                }
            }
        }

        dp[n] as i32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::num_distinct("rabbbit".to_string(), "rabbit".to_string()), 3);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::num_distinct("babgbag".to_string(), "bag".to_string()), 5);
    }

    #[test]
    fn test_empty_t() {
        assert_eq!(Solution::num_distinct("abc".to_string(), "".to_string()), 1);
    }

    #[test]
    fn test_no_match() {
        assert_eq!(Solution::num_distinct("abc".to_string(), "d".to_string()), 0);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Rolling 1-D DP | O(m × n) | O(n) |

### Rust Notes

- `n.min(i)` caps the inner loop: you cannot match more of `t` than characters processed so far.
- `u64` prevents overflow; the problem guarantees the answer fits in `i32`, so the final cast is safe.

---

## LC 72 — Edit Distance

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given strings `word1` and `word2`, return the minimum number of operations (insert, delete, replace) to convert `word1` to `word2`.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = edit distance between `word1[0..i]` and `word2[0..j]` |
| **Base cases** | `dp[i][0] = i`, `dp[0][j] = j` |
| **Transition** | If `word1[i-1] == word2[j-1]`: `dp[i][j] = dp[i-1][j-1]`; else `dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])` (delete, insert, replace) |
| **Answer** | `dp[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn min_distance(word1: String, word2: String) -> i32 {
        let (a, b) = (word1.as_bytes(), word2.as_bytes());
        let (m, n) = (a.len(), b.len());
        // dp[j] = edit distance for word1[0..i] and word2[0..j]
        let mut dp: Vec<i32> = (0..=n as i32).collect();

        for i in 1..=m {
            let mut prev = dp[0]; // dp[i-1][j-1] diagonal
            dp[0] = i as i32;    // base case: delete all of word1[0..i]
            for j in 1..=n {
                let temp = dp[j];
                dp[j] = if a[i - 1] == b[j - 1] {
                    prev
                } else {
                    1 + prev.min(dp[j]).min(dp[j - 1])
                    //         ^replace  ^delete  ^insert
                };
                prev = temp;
            }
        }

        dp[n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::min_distance("horse".to_string(), "ros".to_string()), 3);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::min_distance("intention".to_string(), "execution".to_string()), 5);
    }

    #[test]
    fn test_empty_word1() {
        assert_eq!(Solution::min_distance("".to_string(), "abc".to_string()), 3);
    }

    #[test]
    fn test_empty_word2() {
        assert_eq!(Solution::min_distance("abc".to_string(), "".to_string()), 3);
    }

    #[test]
    fn test_equal() {
        assert_eq!(Solution::min_distance("abc".to_string(), "abc".to_string()), 0);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 2-D DP | O(m × n) | O(m × n) |
| Rolling row | O(m × n) | O(n) |

### Rust Notes

- `(0..=n as i32).collect()` initializes the base-case row in one line — equivalent to `[0, 1, 2, ..., n]`.
- The rolling-row pattern requires `prev` to track the diagonal element `dp[i-1][j-1]` before it is overwritten.

---

## LC 312 — Burst Balloons

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` balloons with values in array `nums`, bursting balloon `i` yields `nums[i-1] * nums[i] * nums[i+1]` coins (out-of-bounds treated as 1). Return the maximum coins from bursting all balloons.

### DP Design

Think in reverse: instead of "which balloon to burst first," ask "which balloon to burst **last** in the range `(l, r)`."

| | Value |
|-|-------|
| **State** | `dp[l][r]` = max coins from bursting all balloons in the open range `(l, r)` (boundary balloons `l` and `r` are **not** burst) |
| **Base cases** | `dp[l][r] = 0` when `r - l < 2` (no balloons inside) |
| **Transition** | For each `k` in `(l, r)` as the **last** to burst: `dp[l][r] = max(dp[l][k] + nums[l]*nums[k]*nums[r] + dp[k][r])` |
| **Answer** | `dp[0][n+1]` (padded with sentinel 1s) |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn max_coins(nums: Vec<i32>) -> i32 {
        // Pad with 1s on both sides
        let mut padded = vec![1i32];
        padded.extend_from_slice(&nums);
        padded.push(1);
        let n = padded.len(); // n = nums.len() + 2

        // dp[l][r] = max coins bursting all balloons in open interval (l, r)
        let mut dp = vec![vec![0i32; n]; n];

        // Iterate over all window lengths from 2 upward
        for len in 2..n {
            for l in 0..n - len {
                let r = l + len;
                for k in l + 1..r {
                    let coins = padded[l] * padded[k] * padded[r];
                    dp[l][r] = dp[l][r].max(dp[l][k] + coins + dp[k][r]);
                }
            }
        }

        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::max_coins(vec![3, 1, 5, 8]), 167);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::max_coins(vec![1, 5]), 10);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::max_coins(vec![5]), 5);
    }

    #[test]
    fn test_all_ones() {
        assert_eq!(Solution::max_coins(vec![1, 1, 1]), 3);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n³) | O(n²) |

### Rust Notes

- `extend_from_slice` appends elements from a slice into a `Vec` — more efficient than repeated `.push()` in a loop.
- Iterating over `len` (window size) rather than `l` and `r` directly ensures all subproblems `dp[l][k]` and `dp[k][r]` are already solved when computing `dp[l][r]`.

---

## LC 10 — Regular Expression Matching

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Implement regular expression matching with `.` (matches any character) and `*` (matches zero or more of the preceding element). Return `true` if the pattern `p` matches the entire string `s`.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = does `s[0..i]` match `p[0..j]`? |
| **Base cases** | `dp[0][0] = true`; `dp[0][j] = true` if `p[j-1] == '*'` and `dp[0][j-2]` |
| **Transition** | If `p[j-1] == '*'`: `dp[i][j] = dp[i][j-2]` (zero occurrences) `|| (dp[i-1][j] && (p[j-2] == '.' || p[j-2] == s[i-1]))` (one+ occurrences); else: `dp[i][j] = dp[i-1][j-1] && (p[j-1] == '.' || p[j-1] == s[i-1])` |
| **Answer** | `dp[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn is_match(s: String, p: String) -> bool {
        let (sb, pb) = (s.as_bytes(), p.as_bytes());
        let (m, n) = (sb.len(), pb.len());
        let mut dp = vec![vec![false; n + 1]; m + 1];
        dp[0][0] = true;

        // Base case: patterns like a*, a*b*, a*b*c* can match empty string
        for j in 2..=n {
            if pb[j - 1] == b'*' {
                dp[0][j] = dp[0][j - 2];
            }
        }

        for i in 1..=m {
            for j in 1..=n {
                if pb[j - 1] == b'*' {
                    // Zero occurrences of pb[j-2]
                    dp[i][j] = dp[i][j - 2];
                    // One or more occurrences: preceding char matches s[i-1]
                    if pb[j - 2] == b'.' || pb[j - 2] == sb[i - 1] {
                        dp[i][j] = dp[i][j] || dp[i - 1][j];
                    }
                } else {
                    dp[i][j] = dp[i - 1][j - 1]
                        && (pb[j - 1] == b'.' || pb[j - 1] == sb[i - 1]);
                }
            }
        }

        dp[m][n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example1() {
        assert_eq!(Solution::is_match("aa".to_string(), "a".to_string()), false);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::is_match("aa".to_string(), "a*".to_string()), true);
    }

    #[test]
    fn test_example3() {
        assert_eq!(Solution::is_match("ab".to_string(), ".*".to_string()), true);
    }

    #[test]
    fn test_dot_star() {
        assert_eq!(Solution::is_match("aab".to_string(), "c*a*b".to_string()), true);
    }

    #[test]
    fn test_empty_match() {
        assert_eq!(Solution::is_match("".to_string(), "a*b*c*".to_string()), true);
    }

    #[test]
    fn test_no_match() {
        assert_eq!(Solution::is_match("mississippi".to_string(), "mis*is*p*.".to_string()), false);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 2-D DP | O(m × n) | O(m × n) |

### Rust Notes

- `b'*'` and `b'.'` are byte literals — comparing `u8` values against them avoids converting to `char`.
- The `||` short-circuit means the second branch of the `*` case only evaluates when the first is false, which matches the logical intent (zero occurrences OR one-or-more).

---

## 📝 Review Notes

### DP Pattern Summary Table

| Pattern | Problems | Key Insight | Rust Idiom |
|---------|----------|-------------|------------|
| **Fibonacci / Linear recurrence** | Climbing Stairs, Min Cost Climbing Stairs, House Robber | Each state depends only on 1–2 prior states; use rolling variables | `let (mut a, mut b) = (v0, v1)` |
| **Circular constraint** | House Robber II | Run linear DP twice on `[0..n-1]` and `[1..n]`; take max | Pass `&[i32]` slice to a helper |
| **Expand-around-center** | Longest Palindromic Substring, Palindromic Substrings | 2n-1 centers, expand while equal; avoids O(n²) space table | Mutable closure capturing `&[u8]` |
| **Unbounded knapsack** | Coin Change (min), Coin Change II (count) | Outer: amount; inner: coins. Or outer: coins; inner: amount forward for combinations | `vec![inf; amount+1]`; sentinel `amount+1` not `i32::MAX` |
| **0/1 Knapsack** | Partition Equal Subset Sum, Distinct Subsequences | Traverse inner loop backwards to prevent reuse | `(n..=target).rev()` |
| **LCS / Edit Distance** | Longest Common Subsequence, Edit Distance | 2-D table with +1 padding; roll to O(n) with diagonal tracking | `let mut prev = dp[0]` before inner loop |
| **State machine DP** | Stock with Cooldown | Encode mutually exclusive states (held/sold/rest); update in dependency order | Parallel variable update with `prev_sold` |
| **Interval DP** | Burst Balloons | Think "last to burst" in a range; iterate by window length | Outer loop over `len`, inner over `l` |
| **Memoized DFS (top-down)** | Longest Increasing Path in Matrix, Word Break | DAG structure guarantees no infinite recursion; cache in a 2-D array | `if memo[r][c] != 0 { return }` |
| **String matching DP** | Decode Ways, Interleaving String, Regex Matching | Careful base-case initialization of `dp[0][j]`; iterate by `i` then `j` | `as_bytes()` for O(1) byte access |

### Common Rust Pitfalls in DP

**usize underflow**
```
// WRONG — panics in debug if i == 0
dp[i - 1]  // when i: usize

// RIGHT — start loop at 1, or guard explicitly
for i in 1..n { ... dp[i-1] ... }
```

**Overflow with sentinels**
```
// WRONG — dp[i-c] + 1 overflows if dp[i-c] == i32::MAX
let mut dp = vec![i32::MAX; n];

// RIGHT — use amount+1 as sentinel; it can never be a real answer
let mut dp = vec![amount + 1; n];
```

**Rolling 2-D DP direction**
```
// 0/1 knapsack (each item once): iterate BACKWARDS
for j in (coin..=target).rev() { dp[j] += dp[j - coin]; }

// Unbounded knapsack (items reusable): iterate FORWARDS
for j in coin..=target { dp[j] += dp[j - coin]; }
```

**Diagonal element in rolling Edit Distance**
```
// Must capture dp[i-1][j-1] BEFORE updating dp[j]
let prev = dp[j];   // save diagonal
dp[j] = ...;        // update
// prev becomes next iteration's diagonal
```

### Complexity Reference

| Problem | Time | Space (optimized) |
|---------|------|-------------------|
| Climbing Stairs | O(n) | O(1) |
| Min Cost Climbing Stairs | O(n) | O(1) |
| House Robber | O(n) | O(1) |
| House Robber II | O(n) | O(1) |
| Longest Palindromic Substring | O(n²) | O(1) |
| Palindromic Substrings | O(n²) | O(1) |
| Decode Ways | O(n) | O(1) |
| Coin Change | O(n × A) | O(A) |
| Maximum Product Subarray | O(n) | O(1) |
| Word Break | O(n² × w) | O(n) |
| Longest Increasing Subsequence | O(n log n) | O(n) |
| Partition Equal Subset Sum | O(n × S) | O(S) |
| Unique Paths | O(m × n) | O(n) |
| Longest Common Subsequence | O(m × n) | O(n) |
| Stock with Cooldown | O(n) | O(1) |
| Coin Change II | O(n × A) | O(A) |
| Target Sum | O(n × S) | O(S) |
| Interleaving String | O(m × n) | O(n) |
| Longest Increasing Path | O(m × n) | O(m × n) |
| Distinct Subsequences | O(m × n) | O(n) |
| Edit Distance | O(m × n) | O(n) |
| Burst Balloons | O(n³) | O(n²) |
| Regular Expression Matching | O(m × n) | O(m × n) |

> **A** = amount, **S** = target sum, **w** = average word length
