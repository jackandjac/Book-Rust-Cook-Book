# Chapter LC-14: Advanced Dynamic Programming (Grandmaster)

> Based on the LeetCode Dynamic Programming Grandmaster study plan.
> **Prerequisite:** Chapter LC-08 (1-D and 2-D DP fundamentals)

## Part 1: Interval DP, Game Theory, and Digit DP

---

## Problem Overview

### Section 1: Interval DP

| # | Problem | Difficulty |
|---|---------|-----------|
| LC 516 | [Longest Palindromic Subsequence](#lc-516--longest-palindromic-subsequence) | Medium |
| LC 1039 | [Minimum Score Triangulation of Polygon](#lc-1039--minimum-score-triangulation-of-polygon) | Medium |
| LC 1000 | [Minimum Cost to Merge Stones](#lc-1000--minimum-cost-to-merge-stones) | Hard |
| LC 312 | [Burst Balloons (Deeper Dive)](#lc-312--burst-balloons-deeper-dive) | Hard |
| LC 664 | [Strange Printer](#lc-664--strange-printer) | Hard |
| LC 1547 | [Minimum Cost to Cut a Stick](#lc-1547--minimum-cost-to-cut-a-stick) | Hard |
| LC 546 | [Remove Boxes](#lc-546--remove-boxes) | Hard |
| LC 1312 | [Minimum Insertion Steps to Make a String Palindrome](#lc-1312--minimum-insertion-steps-to-make-a-string-palindrome) | Medium |

### Section 2: Game Theory / Minimax DP

| # | Problem | Difficulty |
|---|---------|-----------|
| LC 877 | [Stone Game](#lc-877--stone-game) | Medium |
| LC 1140 | [Stone Game II](#lc-1140--stone-game-ii) | Medium |
| LC 1406 | [Stone Game III](#lc-1406--stone-game-iii) | Medium |
| LC 1510 | [Stone Game IV](#lc-1510--stone-game-iv) | Medium |
| LC 375 | [Guess Number Higher or Lower II](#lc-375--guess-number-higher-or-lower-ii) | Medium |
| LC 486 | [Predict the Winner](#lc-486--predict-the-winner) | Medium |
| LC 464 | [Can I Win](#lc-464--can-i-win) | Medium |

### Section 3: Digit DP

| # | Problem | Difficulty |
|---|---------|-----------|
| LC 233 | [Number of Digit One](#lc-233--number-of-digit-one) | Hard |
| LC 357 | [Count Numbers with Unique Digits](#lc-357--count-numbers-with-unique-digits) | Medium |
| LC 902 | [Numbers At Most N Given Digit Set](#lc-902--numbers-at-most-n-given-digit-set) | Hard |
| LC 1012 | [Numbers With Repeated Digits](#lc-1012--numbers-with-repeated-digits) | Hard |
| LC 2376 | [Count Special Integers](#lc-2376--count-special-integers) | Hard |

---

## Java → Rust Quick Reference for This Chapter

| Java idiom | Rust equivalent | Notes |
|-----------|----------------|-------|
| `int[][] dp = new int[n][n]` | `vec![vec![0i32; n]; n]` | 2-D interval table |
| `Integer.MAX_VALUE` | `i32::MAX` or `i64::MAX / 2` | Avoid overflow when adding |
| `Math.min` / `Math.max` | `.min()` / `.max()` | Method syntax on primitives |
| `for (int len=2; len<=n; len++)` | `for len in 2..=n` | Interval DP length loop |
| `HashMap<Integer, Integer>` | `HashMap<i32, i32>` | Memoization; or use `vec` |
| Bitmask `(1 << i)` | `1u32 << i` | Explicit unsigned type |
| `Arrays.fill(dp, -1)` | `vec![-1i32; n]` | Uninitialized sentinel |

---

## Section 1: Interval DP

**Pattern:** Build solutions bottom-up by interval length. `dp[i][j]` is the answer for the subproblem on `arr[i..=j]`. Always iterate outer loop over **length** (small to large), inner loops over **left endpoint** `i`.

```
for len in 2..=n {
    for i in 0..=n-len {
        let j = i + len - 1;
        for k in i..j {      // split point
            dp[i][j] = combine(dp[i][k], dp[k+1][j]);
        }
    }
}
```

---

## LC 516 — Longest Palindromic Subsequence

**Difficulty:** Medium

### Problem Statement

Given a string `s`, return the length of the longest subsequence that is a palindrome. A subsequence does not need to be contiguous.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = length of the longest palindromic subsequence of `s[i..=j]` |
| **Base case** | `dp[i][i] = 1` (single character is a palindrome) |
| **Transition** | If `s[i] == s[j]`: `dp[i][j] = dp[i+1][j-1] + 2`; else `dp[i][j] = max(dp[i+1][j], dp[i][j-1])` |
| **Answer** | `dp[0][n-1]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn longest_palindrome_subseq(s: String) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        // dp[i][j] = LPS length for s[i..=j]
        let mut dp = vec![vec![0i32; n]; n];
        for i in 0..n {
            dp[i][i] = 1;
        }
        // len = 2..n: iterate by increasing interval length
        for len in 2..=n {
            for i in 0..=n - len {
                let j = i + len - 1;
                if b[i] == b[j] {
                    dp[i][j] = if len == 2 { 2 } else { dp[i + 1][j - 1] + 2 };
                } else {
                    dp[i][j] = dp[i + 1][j].max(dp[i][j - 1]);
                }
            }
        }
        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests_lc516 {
    struct Solution;
    impl Solution {
        pub fn longest_palindrome_subseq(s: String) -> i32 {
            let b = s.as_bytes();
            let n = b.len();
            let mut dp = vec![vec![0i32; n]; n];
            for i in 0..n { dp[i][i] = 1; }
            for len in 2..=n {
                for i in 0..=n - len {
                    let j = i + len - 1;
                    if b[i] == b[j] {
                        dp[i][j] = if len == 2 { 2 } else { dp[i + 1][j - 1] + 2 };
                    } else {
                        dp[i][j] = dp[i + 1][j].max(dp[i][j - 1]);
                    }
                }
            }
            dp[0][n - 1]
        }
    }

    #[test]
    fn test_bbbab() {
        assert_eq!(Solution::longest_palindrome_subseq("bbbab".to_string()), 4);
    }

    #[test]
    fn test_cbbd() {
        assert_eq!(Solution::longest_palindrome_subseq("cbbd".to_string()), 2);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::longest_palindrome_subseq("a".to_string()), 1);
    }

    #[test]
    fn test_all_same() {
        assert_eq!(Solution::longest_palindrome_subseq("aaaa".to_string()), 4);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n²) | O(n²) |

### Rust Notes

- The `len == 2` guard prevents index underflow: `dp[i+1][j-1]` when `j = i+1` would access `dp[i+1][i]` (which is 0 but the correct answer for two equal chars is 2, not `0 + 2`). Alternatively initialize `dp[i][i+1]` in a separate base-case loop.
- `b[i] == b[j]` compares `u8` values — safe for ASCII; use `.chars().collect::<Vec<_>>()` for Unicode.

---

## LC 1039 — Minimum Score Triangulation of Polygon

**Difficulty:** Medium

### Problem Statement

Given a convex polygon with `n` vertices labeled with integer values, triangulate it into `n-2` non-overlapping triangles. The score of a triangle is the product of its vertex labels. Return the minimum total score of the triangulation.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = minimum triangulation score for the subpolygon formed by vertices `i..=j` (with edge `i-j` always present) |
| **Base case** | `dp[i][j] = 0` when `j - i < 2` (fewer than 3 vertices — no triangle possible) |
| **Transition** | For each `k` in `i+1..j`: `dp[i][j] = min(dp[i][k] + dp[k][j] + values[i]*values[k]*values[j])` |
| **Answer** | `dp[0][n-1]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn min_score_triangulation(values: Vec<i32>) -> i32 {
        let n = values.len();
        let mut dp = vec![vec![0i32; n]; n];
        // Build from smaller subpolygons to larger
        for len in 2..n {                       // len = j - i
            for i in 0..n - len {
                let j = i + len;
                dp[i][j] = i32::MAX;
                for k in i + 1..j {
                    let score = dp[i][k] + dp[k][j] + values[i] * values[k] * values[j];
                    dp[i][j] = dp[i][j].min(score);
                }
            }
        }
        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests_lc1039 {
    struct Solution;
    impl Solution {
        pub fn min_score_triangulation(values: Vec<i32>) -> i32 {
            let n = values.len();
            let mut dp = vec![vec![0i32; n]; n];
            for len in 2..n {
                for i in 0..n - len {
                    let j = i + len;
                    dp[i][j] = i32::MAX;
                    for k in i + 1..j {
                        let score = dp[i][k] + dp[k][j] + values[i] * values[k] * values[j];
                        dp[i][j] = dp[i][j].min(score);
                    }
                }
            }
            dp[0][n - 1]
        }
    }

    #[test]
    fn test_triangle() {
        // Only one triangulation possible: 1*2*3 = 6
        assert_eq!(Solution::min_score_triangulation(vec![1, 2, 3]), 6);
    }

    #[test]
    fn test_four_vertices() {
        // Two triangulations: (1,2,4)+(1,4,3)=8+12=20 vs (1,2,3)+(1,3,4)=6+12=18
        assert_eq!(Solution::min_score_triangulation(vec![3, 7, 4, 5]), 144);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::min_score_triangulation(vec![1, 3, 1, 4, 1, 5]), 13);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n³) | O(n²) |

### Rust Notes

- Initialize `dp[i][j] = i32::MAX` before the `k` loop; the inner product values are bounded by `1000^3` which fits in `i32` only marginally — consider `i64` for safety if vertex values can be larger.
- The key insight: edge `(i, j)` is fixed, and we choose the third vertex `k` of the triangle that touches this edge.

---

## LC 1000 — Minimum Cost to Merge Stones

**Difficulty:** Hard

### Problem Statement

There are `n` piles of stones arranged in a row. In each move, you merge exactly `k` consecutive piles into one pile, costing the total number of stones in those piles. Return the minimum cost to merge all piles into one, or -1 if it's impossible.

### DP Design

A merge of `n` piles into 1 pile using groups of `k` is only possible when `(n - 1) % (k - 1) == 0`.

| | Value |
|-|-------|
| **State** | `dp[i][j]` = minimum cost to merge piles `i..=j` into the fewest possible piles |
| **Base case** | `dp[i][i] = 0` |
| **Transition** | Split at every `k-1` step: `dp[i][j] = min over m in (i..j step k-1) of dp[i][m] + dp[m+1][j]`; add `prefix[j+1] - prefix[i]` when `(j-i) % (k-1) == 0` (the interval can be reduced to 1 pile) |
| **Answer** | `dp[0][n-1]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn merge_stones(stones: Vec<i32>, k: i32) -> i32 {
        let n = stones.len();
        let k = k as usize;
        // Feasibility check
        if (n - 1) % (k - 1) != 0 {
            return -1;
        }
        // Prefix sums for range sum queries
        let mut prefix = vec![0i32; n + 1];
        for i in 0..n {
            prefix[i + 1] = prefix[i] + stones[i];
        }
        // dp[i][j] = min cost to reduce stones[i..=j] to fewest piles
        let mut dp = vec![vec![0i32; n]; n];
        // Base case: single element -> cost 0 (already 1 pile)
        // Fill by increasing length
        for len in k..=n {                          // need at least k to do anything
            for i in 0..=n - len {
                let j = i + len - 1;
                dp[i][j] = i32::MAX;
                // Try all split points m where left side i..=m has (m-i) % (k-1) == 0
                // i.e. m = i, i+k-1, i+2*(k-1), ...
                let mut m = i;
                while m < j {
                    let cost = dp[i][m] + dp[m + 1][j];
                    if cost < dp[i][j] {
                        dp[i][j] = cost;
                    }
                    m += k - 1;
                }
                // If this range can be merged into a single pile, add the merge cost
                if (j - i) % (k - 1) == 0 {
                    dp[i][j] += prefix[j + 1] - prefix[i];
                }
            }
        }
        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests_lc1000 {
    struct Solution;
    impl Solution {
        pub fn merge_stones(stones: Vec<i32>, k: i32) -> i32 {
            let n = stones.len();
            let k = k as usize;
            if (n - 1) % (k - 1) != 0 { return -1; }
            let mut prefix = vec![0i32; n + 1];
            for i in 0..n { prefix[i + 1] = prefix[i] + stones[i]; }
            let mut dp = vec![vec![0i32; n]; n];
            for len in k..=n {
                for i in 0..=n - len {
                    let j = i + len - 1;
                    dp[i][j] = i32::MAX;
                    let mut m = i;
                    while m < j {
                        let cost = dp[i][m] + dp[m + 1][j];
                        if cost < dp[i][j] { dp[i][j] = cost; }
                        m += k - 1;
                    }
                    if (j - i) % (k - 1) == 0 {
                        dp[i][j] += prefix[j + 1] - prefix[i];
                    }
                }
            }
            dp[0][n - 1]
        }
    }

    #[test]
    fn test_k2() {
        // [3,2,4,1] k=2: 3+2=5, 5+4=9, 9+1=10 (one ordering), min=20
        assert_eq!(Solution::merge_stones(vec![3, 2, 4, 1], 2), 20);
    }

    #[test]
    fn test_impossible() {
        assert_eq!(Solution::merge_stones(vec![3, 2, 4, 1], 3), -1);
    }

    #[test]
    fn test_k3() {
        assert_eq!(Solution::merge_stones(vec![3, 5, 1, 2, 6], 3), 25);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::merge_stones(vec![5], 2), 0);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n³ / k) | O(n²) |

### Rust Notes

- The step `m += k - 1` in the inner loop is the key insight: after merging `i..=m` to one pile, we need `m - i` to be a multiple of `k-1` for it to collapse. This prunes the search significantly.
- `prefix[j+1] - prefix[i]` is the sum of `stones[i..=j]`, the cost of the final merge.

---

## LC 312 — Burst Balloons (Deeper Dive)

**Difficulty:** Hard

### Problem Statement

Given `n` balloons with values `nums`, bursting balloon `i` scores `nums[i-1] * nums[i] * nums[i+1]` (treating out-of-bounds as 1). Return the maximum coins you can collect by bursting all balloons.

### DP Design — The "Last Balloon" Insight

The trick: instead of thinking about which balloon to burst **first**, think about which balloon `k` in `[i..=j]` is the **last** one burst. At that moment, its neighbors are `nums[i-1]` and `nums[j+1]`, so the cost is `nums[i-1] * nums[k] * nums[j+1]`.

Pad `nums` with sentinel 1s at both ends to handle boundary conditions cleanly.

| | Value |
|-|-------|
| **State** | `dp[i][j]` = max coins from bursting all balloons in the **open** interval `(i, j)` (balloons at `i` and `j` are already burst / are sentinels) |
| **Base case** | `dp[i][j] = 0` when `j - i < 2` (no balloon between `i` and `j`) |
| **Transition** | `dp[i][j] = max over k in (i+1..j) of dp[i][k] + nums[i]*nums[k]*nums[j] + dp[k][j]` |
| **Answer** | `dp[0][n+1]` where padded array has `n+2` elements |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn max_coins(nums: Vec<i32>) -> i32 {
        let mut arr = vec![1i32];
        arr.extend_from_slice(&nums);
        arr.push(1);
        let n = arr.len();
        // dp[i][j]: max coins bursting all balloons strictly between i and j
        let mut dp = vec![vec![0i32; n]; n];
        // len = distance between i and j (must be >= 2 to have a balloon in between)
        for len in 2..n {
            for i in 0..n - len {
                let j = i + len;
                for k in i + 1..j {
                    let coins = dp[i][k] + arr[i] * arr[k] * arr[j] + dp[k][j];
                    dp[i][j] = dp[i][j].max(coins);
                }
            }
        }
        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests_lc312 {
    struct Solution;
    impl Solution {
        pub fn max_coins(nums: Vec<i32>) -> i32 {
            let mut arr = vec![1i32];
            arr.extend_from_slice(&nums);
            arr.push(1);
            let n = arr.len();
            let mut dp = vec![vec![0i32; n]; n];
            for len in 2..n {
                for i in 0..n - len {
                    let j = i + len;
                    for k in i + 1..j {
                        let coins = dp[i][k] + arr[i] * arr[k] * arr[j] + dp[k][j];
                        dp[i][j] = dp[i][j].max(coins);
                    }
                }
            }
            dp[0][n - 1]
        }
    }

    #[test]
    fn test_example1() {
        assert_eq!(Solution::max_coins(vec![3, 1, 5, 8]), 167);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::max_coins(vec![1, 5]), 10);
    }

    #[test]
    fn test_one_balloon() {
        assert_eq!(Solution::max_coins(vec![3]), 3);
    }

    #[test]
    fn test_all_ones() {
        assert_eq!(Solution::max_coins(vec![1, 1, 1]), 4);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n³) | O(n²) |

### Rust Notes

- `extend_from_slice` copies a slice into a `Vec` — cleaner than a manual loop.
- The "last burst" framing transforms an exponential state space into a polynomial one. The key is that `dp[i][k]` and `dp[k][j]` are **independent** once we fix `k` as the last balloon.
- In Java you'd typically pad with an explicit conditional; Rust's sentinel approach (`arr[0] = 1, arr[n+1] = 1`) is equally clean.

---

## LC 664 — Strange Printer

**Difficulty:** Hard

### Problem Statement

A printer prints one character at a time and can only print a sequence of the **same** character in each turn, spanning any range `[i, j]`. Given a string `s`, return the minimum number of turns the printer needs to print it.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = minimum turns to print `s[i..=j]` |
| **Base case** | `dp[i][i] = 1` |
| **Transition** | Start: `dp[i][j] = dp[i][j-1] + 1` (print `s[j]` separately); then for each `k` in `i..j` where `s[k] == s[j]`: `dp[i][j] = min(dp[i][j], dp[i][k] + dp[k+1][j-1])` — merging the print of `s[k]` and `s[j]` into one turn saves one |
| **Answer** | `dp[0][n-1]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn strange_printer(s: String) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        let mut dp = vec![vec![0i32; n]; n];
        // Fill bottom-up from length 1 up
        for i in (0..n).rev() {
            dp[i][i] = 1;
            for j in i + 1..n {
                // Cost if we print s[j] in its own turn
                dp[i][j] = dp[i][j - 1] + 1;
                // If s[k] == s[j], we can extend the run that prints s[k] to also cover s[j]
                for k in i..j {
                    if b[k] == b[j] {
                        let cost = dp[i][k]
                            + if k + 1 <= j - 1 { dp[k + 1][j - 1] } else { 0 };
                        dp[i][j] = dp[i][j].min(cost);
                    }
                }
            }
        }
        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests_lc664 {
    struct Solution;
    impl Solution {
        pub fn strange_printer(s: String) -> i32 {
            let b = s.as_bytes();
            let n = b.len();
            let mut dp = vec![vec![0i32; n]; n];
            for i in (0..n).rev() {
                dp[i][i] = 1;
                for j in i + 1..n {
                    dp[i][j] = dp[i][j - 1] + 1;
                    for k in i..j {
                        if b[k] == b[j] {
                            let cost = dp[i][k]
                                + if k + 1 <= j - 1 { dp[k + 1][j - 1] } else { 0 };
                            dp[i][j] = dp[i][j].min(cost);
                        }
                    }
                }
            }
            dp[0][n - 1]
        }
    }

    #[test]
    fn test_aaabbb() {
        assert_eq!(Solution::strange_printer("aaabbb".to_string()), 2);
    }

    #[test]
    fn test_aba() {
        assert_eq!(Solution::strange_printer("aba".to_string()), 2);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::strange_printer("a".to_string()), 1);
    }

    #[test]
    fn test_abcba() {
        assert_eq!(Solution::strange_printer("abcba".to_string()), 3);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n³) | O(n²) |

### Rust Notes

- The loop iterates `i` from high to low (`(0..n).rev()`) and `j` from `i+1` upward — this ensures `dp[i][k]` and `dp[k+1][j-1]` are computed before `dp[i][j]`. This is the **reverse-i** style of interval DP, equivalent to the length-first style.
- Guard `if k + 1 <= j - 1` prevents invalid index access when `j == k + 1` (adjacent positions).

---

## LC 1547 — Minimum Cost to Cut a Stick

**Difficulty:** Hard

### Problem Statement

Given a stick of length `n` and an array `cuts`, perform all cuts in any order. The cost of each cut is the length of the stick being cut. Return the minimum total cost.

### DP Design

Add sentinels `0` and `n` to the cuts array, sort it. Now `dp[i][j]` is defined over adjacent pairs in the sorted `cuts` array.

| | Value |
|-|-------|
| **State** | `dp[i][j]` = minimum cost to make all cuts between `cuts[i]` and `cuts[j]` (where `cuts[0]=0`, `cuts[m+1]=n`) |
| **Base case** | `dp[i][j] = 0` when `j - i == 1` (no cuts between adjacent positions) |
| **Transition** | `dp[i][j] = min over k in (i+1..j) of dp[i][k] + dp[k][j] + cuts[j] - cuts[i]` |
| **Answer** | `dp[0][m+1]` where `m = cuts.len()` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn min_cost(n: i32, cuts: Vec<i32>) -> i32 {
        let mut c = vec![0i32];
        c.extend_from_slice(&cuts);
        c.push(n);
        c.sort_unstable();
        let m = c.len();
        let mut dp = vec![vec![0i32; m]; m];
        // len = gap between indices (>= 2 means there's a cut point in between)
        for len in 2..m {
            for i in 0..m - len {
                let j = i + len;
                dp[i][j] = i32::MAX;
                for k in i + 1..j {
                    let cost = dp[i][k] + dp[k][j] + c[j] - c[i];
                    dp[i][j] = dp[i][j].min(cost);
                }
            }
        }
        dp[0][m - 1]
    }
}

#[cfg(test)]
mod tests_lc1547 {
    struct Solution;
    impl Solution {
        pub fn min_cost(n: i32, cuts: Vec<i32>) -> i32 {
            let mut c = vec![0i32];
            c.extend_from_slice(&cuts);
            c.push(n);
            c.sort_unstable();
            let m = c.len();
            let mut dp = vec![vec![0i32; m]; m];
            for len in 2..m {
                for i in 0..m - len {
                    let j = i + len;
                    dp[i][j] = i32::MAX;
                    for k in i + 1..j {
                        let cost = dp[i][k] + dp[k][j] + c[j] - c[i];
                        dp[i][j] = dp[i][j].min(cost);
                    }
                }
            }
            dp[0][m - 1]
        }
    }

    #[test]
    fn test_example1() {
        assert_eq!(Solution::min_cost(7, vec![1, 3, 4, 5]), 16);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::min_cost(9, vec![5, 6, 1, 4, 2]), 22);
    }

    #[test]
    fn test_one_cut() {
        assert_eq!(Solution::min_cost(10, vec![5]), 10);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP on sorted cuts | O(m³) where m = cuts.len()+2 | O(m²) |

### Rust Notes

- `sort_unstable()` is preferred over `sort()` when stability is irrelevant — it's faster in practice.
- Adding `0` and `n` as sentinels transforms the problem into the same structural shape as Matrix Chain Multiplication.

---

## LC 546 — Remove Boxes

**Difficulty:** Hard

### Problem Statement

Given an array `boxes` of colored boxes, removing `k` consecutive boxes of the same color yields `k * k` points. Return the maximum points from removing all boxes.

### DP Design

Standard 2-D interval DP is insufficient here because boxes of the same color can "merge" across gaps. We need a 3-D state.

| | Value |
|-|-------|
| **State** | `dp[l][r][k]` = maximum points from removing all boxes in `boxes[l..=r]` plus `k` extra boxes of color `boxes[l]` attached to the left of position `l` |
| **Base case** | `dp[l][r][k] = (k+1)*(k+1)` when `l == r` |
| **Transition** | Option 1: remove the `k+1` boxes at position `l` first: `dp[l][r][k] = (k+1)^2 + dp[l+1][r][0]`. Option 2: for each `m` in `l+1..=r` where `boxes[m] == boxes[l]`, attach position `l` to position `m`: `dp[l][r][k] = dp[l+1][m-1][0] + dp[m][r][k+1]` |
| **Answer** | `dp[0][n-1][0]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn remove_boxes(boxes: Vec<i32>) -> i32 {
        let n = boxes.len();
        // dp[l][r][k]: max points for boxes[l..=r] with k extra boxes[l]-colored boxes on left
        let mut dp = vec![vec![vec![0i32; n]; n]; n];
        Self::solve(&boxes, 0, n - 1, 0, &mut dp)
    }

    fn solve(boxes: &[i32], l: usize, r: usize, k: usize, dp: &mut Vec<Vec<Vec<i32>>>) -> i32 {
        if l > r {
            return 0;
        }
        // Memoized
        if dp[l][r][k] != 0 {
            return dp[l][r][k];
        }
        // Compress: absorb consecutive matching boxes at l into k
        let (mut l2, mut k2) = (l, k);
        while l2 < r && boxes[l2 + 1] == boxes[l] {
            l2 += 1;
            k2 += 1;
        }
        // Option 1: remove the k2+1 boxes of boxes[l] color at the start
        let mut best = (k2 + 1) as i32 * (k2 + 1) as i32 + Self::solve(boxes, l2 + 1, r, 0, dp);
        // Option 2: find a matching box further right and attach
        for m in l2 + 1..=r {
            if boxes[m] == boxes[l] {
                let score = Self::solve(boxes, l2 + 1, m - 1, 0, dp)
                    + Self::solve(boxes, m, r, k2 + 1, dp);
                best = best.max(score);
            }
        }
        dp[l][r][k] = best;
        best
    }
}

#[cfg(test)]
mod tests_lc546 {
    struct Solution;
    impl Solution {
        pub fn remove_boxes(boxes: Vec<i32>) -> i32 {
            let n = boxes.len();
            let mut dp = vec![vec![vec![0i32; n]; n]; n];
            Self::solve(&boxes, 0, n - 1, 0, &mut dp)
        }
        fn solve(boxes: &[i32], l: usize, r: usize, k: usize, dp: &mut Vec<Vec<Vec<i32>>>) -> i32 {
            if l > r { return 0; }
            if dp[l][r][k] != 0 { return dp[l][r][k]; }
            let (mut l2, mut k2) = (l, k);
            while l2 < r && boxes[l2 + 1] == boxes[l] { l2 += 1; k2 += 1; }
            let mut best = (k2 + 1) as i32 * (k2 + 1) as i32 + Self::solve(boxes, l2 + 1, r, 0, dp);
            for m in l2 + 1..=r {
                if boxes[m] == boxes[l] {
                    let score = Self::solve(boxes, l2 + 1, m - 1, 0, dp)
                        + Self::solve(boxes, m, r, k2 + 1, dp);
                    best = best.max(score);
                }
            }
            dp[l][r][k] = best;
            best
        }
    }

    #[test]
    fn test_example1() {
        assert_eq!(Solution::remove_boxes(vec![1, 3, 2, 2, 2, 3, 4, 3, 1]), 23);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::remove_boxes(vec![1, 1, 1]), 9);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::remove_boxes(vec![5]), 1);
    }

    #[test]
    fn test_distinct() {
        assert_eq!(Solution::remove_boxes(vec![1, 2, 3]), 3);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 3-D memoized recursion | O(n⁴) | O(n³) |

### Rust Notes

- The third dimension `k` counts extra matching boxes attached from the left — this breaks the independence assumption of standard interval DP.
- Passing `&mut dp` through recursion requires careful borrow management; Rust's borrow checker ensures no aliasing. Split the borrow by passing `boxes` and `dp` separately.
- `l > r` with `usize` would underflow if `l = 0` and we tried `r - 1` when `r = 0`. Guard with `if l > r { return 0; }` before any arithmetic.

---

## LC 1312 — Minimum Insertion Steps to Make a String Palindrome

**Difficulty:** Medium

### Problem Statement

Given a string `s`, return the minimum number of characters you need to insert to make it a palindrome.

### DP Design

The minimum insertions equals `n - LPS(s)` where `LPS` is the Longest Palindromic Subsequence length (LC #516). Alternatively, it equals the edit distance (insertions only) from `s` to `reverse(s)` divided by 2, which equals `n - LCS(s, reverse(s))`.

| | Value |
|-|-------|
| **State** | `dp[i][j]` = minimum insertions to make `s[i..=j]` a palindrome |
| **Base case** | `dp[i][i] = 0` (single char is already a palindrome) |
| **Transition** | If `s[i] == s[j]`: `dp[i][j] = dp[i+1][j-1]`; else `dp[i][j] = 1 + min(dp[i+1][j], dp[i][j-1])` |
| **Answer** | `dp[0][n-1]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn min_insertions(s: String) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        let mut dp = vec![vec![0i32; n]; n];
        for len in 2..=n {
            for i in 0..=n - len {
                let j = i + len - 1;
                if b[i] == b[j] {
                    dp[i][j] = if len == 2 { 0 } else { dp[i + 1][j - 1] };
                } else {
                    dp[i][j] = 1 + dp[i + 1][j].min(dp[i][j - 1]);
                }
            }
        }
        dp[0][n - 1]
    }
}

#[cfg(test)]
mod tests_lc1312 {
    struct Solution;
    impl Solution {
        pub fn min_insertions(s: String) -> i32 {
            let b = s.as_bytes();
            let n = b.len();
            let mut dp = vec![vec![0i32; n]; n];
            for len in 2..=n {
                for i in 0..=n - len {
                    let j = i + len - 1;
                    if b[i] == b[j] {
                        dp[i][j] = if len == 2 { 0 } else { dp[i + 1][j - 1] };
                    } else {
                        dp[i][j] = 1 + dp[i + 1][j].min(dp[i][j - 1]);
                    }
                }
            }
            dp[0][n - 1]
        }
    }

    #[test]
    fn test_zzazz() {
        assert_eq!(Solution::min_insertions("zzazz".to_string()), 0);
    }

    #[test]
    fn test_mbadm() {
        assert_eq!(Solution::min_insertions("mbadm".to_string()), 2);
    }

    #[test]
    fn test_leetcode() {
        assert_eq!(Solution::min_insertions("leetcode".to_string()), 5);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::min_insertions("a".to_string()), 0);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n²) | O(n²) |

### Rust Notes

- This is the complement of LC #516: `min_insertions = n - longest_palindromic_subsequence`. You can solve it directly with the recurrence above, or compute `n - lps(s)`.
- The `len == 2` guard is identical to LC #516 — avoid accessing `dp[i+1][j-1]` when `i+1 > j-1`.

---

## Section 2: Game Theory / Minimax DP

**Pattern:** Two players (Alice and Bob) play optimally. `dp[i][j]` often represents the **score difference** (current player's score minus the opponent's score) for the subgame `[i..=j]`. A positive result means the current player wins.

Key invariant: `dp[i][j] = max(left_choice, right_choice)` where each choice reduces the opponent's advantage by the corresponding subgame value.

---

## LC 877 — Stone Game

**Difficulty:** Medium

### Problem Statement

Alice and Bob play a stone game. There are `n` piles of stones arranged in a row (n is even, total is odd so no tie). Alice goes first; each turn a player takes a pile from either end. Alice wins if she gets more stones than Bob. Return `true` if Alice wins.

### DP Design

**Observation:** Alice always wins (mathematical proof). Alice can always choose all even-indexed or all odd-indexed piles (since n is even, one of these sets has more stones). But LeetCode expects the DP solution.

| | Value |
|-|-------|
| **State** | `dp[i][j]` = maximum **score difference** (current player minus opponent) for piles `i..=j` |
| **Base case** | `dp[i][i] = piles[i]` |
| **Transition** | `dp[i][j] = max(piles[i] - dp[i+1][j], piles[j] - dp[i][j-1])` |
| **Answer** | `dp[0][n-1] > 0` means first player wins |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn stone_game(piles: Vec<i32>) -> bool {
        let n = piles.len();
        let mut dp = vec![vec![0i32; n]; n];
        for i in 0..n {
            dp[i][i] = piles[i];
        }
        for len in 2..=n {
            for i in 0..=n - len {
                let j = i + len - 1;
                dp[i][j] = (piles[i] - dp[i + 1][j]).max(piles[j] - dp[i][j - 1]);
            }
        }
        dp[0][n - 1] > 0
    }
}

#[cfg(test)]
mod tests_lc877 {
    struct Solution;
    impl Solution {
        pub fn stone_game(piles: Vec<i32>) -> bool {
            let n = piles.len();
            let mut dp = vec![vec![0i32; n]; n];
            for i in 0..n { dp[i][i] = piles[i]; }
            for len in 2..=n {
                for i in 0..=n - len {
                    let j = i + len - 1;
                    dp[i][j] = (piles[i] - dp[i + 1][j]).max(piles[j] - dp[i][j - 1]);
                }
            }
            dp[0][n - 1] > 0
        }
    }

    #[test]
    fn test_example() {
        assert!(Solution::stone_game(vec![5, 3, 4, 5]));
    }

    #[test]
    fn test_trivial() {
        // Alice always wins (n even, total odd)
        assert!(Solution::stone_game(vec![1, 100, 1, 1]));
        assert!(Solution::stone_game(vec![2, 7, 9, 4]));
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n²) | O(n²) |

### Rust Notes

- The score-difference trick (`current_gain - opponent_best`) encodes optimal play for both players in a single DP table. Positive = current player wins.
- Real answer: `return true;` always (Alice controls parity), but DP generalizes to non-trivial variants.

---

## LC 1140 — Stone Game II

**Difficulty:** Medium

### Problem Statement

Alice and Bob alternate picking piles from the left. On each turn, the current player may pick `X` piles where `1 <= X <= 2*M`, then `M = max(M, X)`. Alice goes first with `M=1`. Return the maximum stones Alice can get.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][m]` = maximum stones the **current player** can get from piles `[i..n-1]` given the current `M` value is `m` |
| **Base case** | If `i + 2*m >= n`, current player takes all remaining piles |
| **Transition** | `dp[i][m] = max over x in 1..=2*m of (suffix[i] - dp[i+x][max(m,x)])` |
| **Answer** | `dp[0][1]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn stone_game_ii(piles: Vec<i32>) -> i32 {
        let n = piles.len();
        // Suffix sums
        let mut suffix = vec![0i32; n + 1];
        for i in (0..n).rev() {
            suffix[i] = suffix[i + 1] + piles[i];
        }
        // dp[i][m]: max stones current player can take from piles[i..] with M=m
        let max_m = n + 1;
        let mut dp = vec![vec![0i32; max_m + 1]; n + 1];
        for i in (0..n).rev() {
            for m in 1..=max_m {
                if i + 2 * m >= n {
                    dp[i][m] = suffix[i]; // take everything
                } else {
                    for x in 1..=2 * m {
                        let next_m = m.max(x);
                        let candidate = suffix[i] - dp[i + x][next_m];
                        dp[i][m] = dp[i][m].max(candidate);
                    }
                }
            }
        }
        dp[0][1]
    }
}

#[cfg(test)]
mod tests_lc1140 {
    struct Solution;
    impl Solution {
        pub fn stone_game_ii(piles: Vec<i32>) -> i32 {
            let n = piles.len();
            let mut suffix = vec![0i32; n + 1];
            for i in (0..n).rev() { suffix[i] = suffix[i + 1] + piles[i]; }
            let max_m = n + 1;
            let mut dp = vec![vec![0i32; max_m + 1]; n + 1];
            for i in (0..n).rev() {
                for m in 1..=max_m {
                    if i + 2 * m >= n {
                        dp[i][m] = suffix[i];
                    } else {
                        for x in 1..=2 * m {
                            let next_m = m.max(x);
                            let candidate = suffix[i] - dp[i + x][next_m];
                            dp[i][m] = dp[i][m].max(candidate);
                        }
                    }
                }
            }
            dp[0][1]
        }
    }

    #[test]
    fn test_example1() {
        assert_eq!(Solution::stone_game_ii(vec![2, 7, 9, 4, 4]), 10);
    }

    #[test]
    fn test_example2() {
        assert_eq!(Solution::stone_game_ii(vec![1, 2, 3, 4, 5, 100]), 104);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| DP with suffix sum | O(n³) | O(n²) |

### Rust Notes

- `suffix[i] - dp[i+x][next_m]` uses the score-difference trick: current player gets `suffix[i]` total minus what the opponent optimally takes.
- `max_m = n + 1` bounds `M` because `M` never exceeds `n` (you can't take more piles than exist).

---

## LC 1406 — Stone Game III

**Difficulty:** Medium

### Problem Statement

Alice and Bob alternate picking 1, 2, or 3 stones from the left of a row. The player with more total stones wins. Return "Alice", "Bob", or "Tie".

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = maximum score difference (current player minus opponent) starting from index `i` |
| **Base case** | `dp[n] = 0` |
| **Transition** | `dp[i] = max over k in {1,2,3} of (sum(stones[i..i+k]) - dp[i+k])` |
| **Answer** | `dp[0] > 0` → "Alice", `< 0` → "Bob", `== 0` → "Tie" |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn stone_game_iii(stone_value: Vec<i32>) -> String {
        let n = stone_value.len();
        let mut dp = vec![i32::MIN; n + 1];
        dp[n] = 0;
        for i in (0..n).rev() {
            let mut running = 0i32;
            for k in 1..=3 {
                if i + k > n { break; }
                running += stone_value[i + k - 1];
                dp[i] = dp[i].max(running - dp[i + k]);
            }
        }
        match dp[0].cmp(&0) {
            std::cmp::Ordering::Greater => "Alice".to_string(),
            std::cmp::Ordering::Less    => "Bob".to_string(),
            std::cmp::Ordering::Equal   => "Tie".to_string(),
        }
    }
}

#[cfg(test)]
mod tests_lc1406 {
    struct Solution;
    impl Solution {
        pub fn stone_game_iii(stone_value: Vec<i32>) -> String {
            let n = stone_value.len();
            let mut dp = vec![i32::MIN; n + 1];
            dp[n] = 0;
            for i in (0..n).rev() {
                let mut running = 0i32;
                for k in 1..=3 {
                    if i + k > n { break; }
                    running += stone_value[i + k - 1];
                    dp[i] = dp[i].max(running - dp[i + k]);
                }
            }
            match dp[0].cmp(&0) {
                std::cmp::Ordering::Greater => "Alice".to_string(),
                std::cmp::Ordering::Less    => "Bob".to_string(),
                std::cmp::Ordering::Equal   => "Tie".to_string(),
            }
        }
    }

    #[test]
    fn test_bob_wins_with_7() {
        assert_eq!(Solution::stone_game_iii(vec![1, 2, 3, 7]), "Bob");
    }

    #[test]
    fn test_alice_wins_negative() {
        assert_eq!(Solution::stone_game_iii(vec![1, 2, 3, -9]), "Alice");
    }

    #[test]
    fn test_tie() {
        assert_eq!(Solution::stone_game_iii(vec![1, 2, 3, 6]), "Tie");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 1-D DP (3 choices) | O(n) | O(n) → O(1) with rolling array |

### Rust Notes

- `match dp[0].cmp(&0)` on `Ordering` variants is idiomatic and exhaustive — no need for chained `if/else if`.
- Initialize `dp[i] = i32::MIN` so the first `max` assignment always wins; otherwise 0-initializing would incorrectly suggest "no move" has value 0.

---

## LC 1510 — Stone Game IV

**Difficulty:** Medium

### Problem Statement

Alice and Bob alternately remove a square number of stones (1, 4, 9, …) from a pile of `n` stones. The player who cannot move loses. Alice goes first. Return `true` if Alice wins.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i]` = `true` if the current player wins with `i` stones remaining |
| **Base case** | `dp[0] = false` (no stones to take — you lose) |
| **Transition** | `dp[i] = true` if there exists a square `s² <= i` such that `dp[i - s²] == false` (opponent is in a losing position) |
| **Answer** | `dp[n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn winner_square_game(n: i32) -> bool {
        let n = n as usize;
        let mut dp = vec![false; n + 1];
        // dp[0] = false: no stones left, current player loses
        for i in 1..=n {
            let mut s = 1usize;
            while s * s <= i {
                if !dp[i - s * s] {
                    dp[i] = true;
                    break;
                }
                s += 1;
            }
        }
        dp[n]
    }
}

#[cfg(test)]
mod tests_lc1510 {
    struct Solution;
    impl Solution {
        pub fn winner_square_game(n: i32) -> bool {
            let n = n as usize;
            let mut dp = vec![false; n + 1];
            for i in 1..=n {
                let mut s = 1usize;
                while s * s <= i {
                    if !dp[i - s * s] { dp[i] = true; break; }
                    s += 1;
                }
            }
            dp[n]
        }
    }

    #[test]
    fn test_1() { assert!(Solution::winner_square_game(1)); }
    #[test]
    fn test_2() { assert!(!Solution::winner_square_game(2)); }
    #[test]
    fn test_4() { assert!(Solution::winner_square_game(4)); }
    #[test]
    fn test_7() { assert!(!Solution::winner_square_game(7)); }
    #[test]
    fn test_17() { assert!(!Solution::winner_square_game(17)); }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| 1-D DP | O(n√n) | O(n) |

### Rust Notes

- The `break` after finding a losing state for the opponent is a minor optimization — once we know Alice wins, no need to check further squares.
- This is a **Nim-variant** / **Sprague-Grundy** game reduced to a simple Boolean DP.

---

## LC 375 — Guess Number Higher or Lower II

**Difficulty:** Medium

### Problem Statement

You pick a number in `[1..n]`. Your opponent guesses; you pay `k` if you guess `k` and it's wrong (you're then told higher/lower). Use the worst-case optimal strategy to minimize the maximum payment needed to guarantee a win. Return that minimum amount.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = minimum money needed to guarantee a win in the range `[i..=j]` |
| **Base case** | `dp[i][i] = 0` (only one choice — always correct) |
| **Transition** | For each guess `k` in `[i..=j]`: pay `k`, then face worst case: `dp[i][j] = min over k of (k + max(dp[i][k-1], dp[k+1][j]))` |
| **Answer** | `dp[1][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn get_money_amount(n: i32) -> i32 {
        let n = n as usize;
        // 1-indexed; use n+1 size and offset by 1
        let mut dp = vec![vec![0i32; n + 2]; n + 2];
        for len in 2..=n {
            for i in 1..=n - len + 1 {
                let j = i + len - 1;
                dp[i][j] = i32::MAX;
                for k in i..=j {
                    let left = if k > i { dp[i][k - 1] } else { 0 };
                    let right = if k < j { dp[k + 1][j] } else { 0 };
                    let cost = k as i32 + left.max(right);
                    dp[i][j] = dp[i][j].min(cost);
                }
            }
        }
        dp[1][n]
    }
}

#[cfg(test)]
mod tests_lc375 {
    struct Solution;
    impl Solution {
        pub fn get_money_amount(n: i32) -> i32 {
            let n = n as usize;
            let mut dp = vec![vec![0i32; n + 2]; n + 2];
            for len in 2..=n {
                for i in 1..=n - len + 1 {
                    let j = i + len - 1;
                    dp[i][j] = i32::MAX;
                    for k in i..=j {
                        let left = if k > i { dp[i][k - 1] } else { 0 };
                        let right = if k < j { dp[k + 1][j] } else { 0 };
                        let cost = k as i32 + left.max(right);
                        dp[i][j] = dp[i][j].min(cost);
                    }
                }
            }
            dp[1][n]
        }
    }

    #[test]
    fn test_n1() { assert_eq!(Solution::get_money_amount(1), 0); }
    #[test]
    fn test_n2() { assert_eq!(Solution::get_money_amount(2), 1); }
    #[test]
    fn test_n10() { assert_eq!(Solution::get_money_amount(10), 16); }
    #[test]
    fn test_n3() { assert_eq!(Solution::get_money_amount(3), 2); }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n³) | O(n²) |

### Rust Notes

- Guards `if k > i` and `if k < j` avoid underflow/out-of-bounds with `usize`. In Java, negative index access would throw `ArrayIndexOutOfBoundsException`; in Rust, it panics on underflow. The explicit guard is the safest approach.

---

## LC 486 — Predict the Winner

**Difficulty:** Medium

### Problem Statement

Two players alternately pick a number from either end of an array. The player with the higher total wins. Given `nums`, return `true` if Player 1 can win or tie.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = maximum score difference (current player minus opponent) for subarray `nums[i..=j]` |
| **Base case** | `dp[i][i] = nums[i]` |
| **Transition** | `dp[i][j] = max(nums[i] - dp[i+1][j], nums[j] - dp[i][j-1])` |
| **Answer** | `dp[0][n-1] >= 0` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn predict_the_winner(nums: Vec<i32>) -> bool {
        let n = nums.len();
        let mut dp = vec![vec![0i32; n]; n];
        for i in 0..n {
            dp[i][i] = nums[i];
        }
        for len in 2..=n {
            for i in 0..=n - len {
                let j = i + len - 1;
                dp[i][j] = (nums[i] - dp[i + 1][j]).max(nums[j] - dp[i][j - 1]);
            }
        }
        dp[0][n - 1] >= 0
    }
}

#[cfg(test)]
mod tests_lc486 {
    struct Solution;
    impl Solution {
        pub fn predict_the_winner(nums: Vec<i32>) -> bool {
            let n = nums.len();
            let mut dp = vec![vec![0i32; n]; n];
            for i in 0..n { dp[i][i] = nums[i]; }
            for len in 2..=n {
                for i in 0..=n - len {
                    let j = i + len - 1;
                    dp[i][j] = (nums[i] - dp[i + 1][j]).max(nums[j] - dp[i][j - 1]);
                }
            }
            dp[0][n - 1] >= 0
        }
    }

    #[test]
    fn test_p1_cannot_win() {
        assert!(!Solution::predict_the_winner(vec![1, 5, 2]));
    }

    #[test]
    fn test_p1_wins() {
        assert!(Solution::predict_the_winner(vec![1, 5, 233, 7]));
    }

    #[test]
    fn test_tie() {
        assert!(Solution::predict_the_winner(vec![1, 3, 1]));
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Interval DP | O(n²) | O(n²) → O(n) with rolling 1-D |

### Rust Notes

- Structurally identical to LC #877 Stone Game, except the answer condition is `>= 0` (tie counts as Player 1 winning). LC #877 is a special case where Player 1 always wins.

---

## LC 464 — Can I Win

**Difficulty:** Medium

### Problem Statement

Two players alternate choosing an integer from `[1..maxChoosableInteger]` (no repeats). The first player to push the running total `>= desiredTotal` wins. Return `true` if the first player can guarantee a win.

### DP Design

State is a bitmask of which integers have been chosen.

| | Value |
|-|-------|
| **State** | `dp[mask]` = `true` if the current player wins given the set of chosen numbers is `mask` |
| **Base case** | If the current sum (from `mask`) >= `desiredTotal` before this player's turn, the previous player already won — this state is unreachable |
| **Transition** | For each `i in 1..=max` not in `mask`: if `sum + i >= desiredTotal` OR `!dp[mask | (1 << (i-1))]`, return `true` |
| **Answer** | `dp[0]` |

### Rust Solution

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn can_i_win(max_choosable_integer: i32, desired_total: i32) -> bool {
        let m = max_choosable_integer as usize;
        // Quick checks
        if desired_total <= 0 { return true; }
        let total_sum = (m * (m + 1) / 2) as i32;
        if total_sum < desired_total { return false; }
        let mut memo: HashMap<u32, bool> = HashMap::new();
        Self::can_win(m, desired_total, 0, 0, &mut memo)
    }

    fn can_win(
        max: usize,
        target: i32,
        mask: u32,
        current_sum: i32,
        memo: &mut HashMap<u32, bool>,
    ) -> bool {
        if let Some(&result) = memo.get(&mask) {
            return result;
        }
        let result = (1..=max).any(|i| {
            let bit = 1u32 << (i - 1);
            if mask & bit != 0 { return false; } // already chosen
            let new_sum = current_sum + i as i32;
            // If this choice wins immediately, or opponent loses in the new state
            new_sum >= target || !Self::can_win(max, target, mask | bit, new_sum, memo)
        });
        memo.insert(mask, result);
        result
    }
}

#[cfg(test)]
mod tests_lc464 {
    use std::collections::HashMap;

    struct Solution;
    impl Solution {
        pub fn can_i_win(max_choosable_integer: i32, desired_total: i32) -> bool {
            let m = max_choosable_integer as usize;
            if desired_total <= 0 { return true; }
            let total_sum = (m * (m + 1) / 2) as i32;
            if total_sum < desired_total { return false; }
            let mut memo: HashMap<u32, bool> = HashMap::new();
            Self::can_win(m, desired_total, 0, 0, &mut memo)
        }
        fn can_win(max: usize, target: i32, mask: u32, current_sum: i32, memo: &mut HashMap<u32, bool>) -> bool {
            if let Some(&result) = memo.get(&mask) { return result; }
            let result = (1..=max).any(|i| {
                let bit = 1u32 << (i - 1);
                if mask & bit != 0 { return false; }
                let new_sum = current_sum + i as i32;
                new_sum >= target || !Self::can_win(max, target, mask | bit, new_sum, memo)
            });
            memo.insert(mask, result);
            result
        }
    }

    #[test]
    fn test_cannot_win() {
        assert!(!Solution::can_i_win(10, 11));
    }

    #[test]
    fn test_can_win() {
        assert!(Solution::can_i_win(10, 0));
        assert!(Solution::can_i_win(10, 1));
    }

    #[test]
    fn test_impossible() {
        // Sum of 1..=10 = 55 < 100
        assert!(!Solution::can_i_win(10, 100));
    }

    #[test]
    fn test_small() {
        assert!(!Solution::can_i_win(10, 40));
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Bitmask DP (2^m states) | O(m * 2^m) | O(2^m) |

### Rust Notes

- `Iterator::any` with a closure is idiomatic Rust for "exists a choice that wins" — more expressive than a manual `for` loop with a boolean flag.
- `u32` bitmask limits `maxChoosableInteger` to 20 (which matches the problem constraint of ≤ 20). Use `u64` if the constraint were larger.
- `HashMap<u32, bool>` is the memoization table. Alternatively, use `vec![Option<bool>; 1 << m]` for O(1) lookup without hashing.

---

## Section 3: Digit DP

**Pattern:** Count integers in `[1..n]` satisfying a digit property. Build the count digit by digit, tracking whether we are still "tight" (constrained by the upper bound digits) and whether we've placed a "leading non-zero" digit yet.

Core template:
```
fn count_up_to(n: i64) -> i64 {
    let digits: Vec<i32> = /* digits of n */;
    // dp(pos, tight, started) -> count
}
```

---

## LC 233 — Number of Digit One

**Difficulty:** Hard

### Problem Statement

Given an integer `n`, count the total number of digit `1` appearing in all non-negative integers in the range `[1, n]`.

### DP Design

Mathematical approach: for each digit position `p` (ones, tens, hundreds…), count how many times `1` appears in that position across `[1..n]`.

| | Value |
|-|-------|
| **State** | Consider position with factor `f = 10^p`. Digits split into `higher = n / (f * 10)`, `current = (n / f) % 10`, `lower = n % f` |
| **Transition** | Count of 1s at position `p`: if `current == 0`: `higher * f`; if `current == 1`: `higher * f + lower + 1`; else: `(higher + 1) * f` |
| **Answer** | Sum over all digit positions |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn count_digit_one(n: i32) -> i32 {
        let mut count = 0i64;
        let mut factor = 1i64;
        let n = n as i64;
        while factor <= n {
            let higher = n / (factor * 10);
            let current = (n / factor) % 10;
            let lower = n % factor;
            count += match current {
                0 => higher * factor,
                1 => higher * factor + lower + 1,
                _ => (higher + 1) * factor,
            };
            factor *= 10;
        }
        count as i32
    }
}

#[cfg(test)]
mod tests_lc233 {
    struct Solution;
    impl Solution {
        pub fn count_digit_one(n: i32) -> i32 {
            let mut count = 0i64;
            let mut factor = 1i64;
            let n = n as i64;
            while factor <= n {
                let higher = n / (factor * 10);
                let current = (n / factor) % 10;
                let lower = n % factor;
                count += match current {
                    0 => higher * factor,
                    1 => higher * factor + lower + 1,
                    _ => (higher + 1) * factor,
                };
                factor *= 10;
            }
            count as i32
        }
    }

    #[test]
    fn test_13() { assert_eq!(Solution::count_digit_one(13), 6); }
    #[test]
    fn test_0() { assert_eq!(Solution::count_digit_one(0), 0); }
    #[test]
    fn test_1() { assert_eq!(Solution::count_digit_one(1), 1); }
    #[test]
    fn test_100() { assert_eq!(Solution::count_digit_one(100), 21); }
    #[test]
    fn test_1000000000() { assert_eq!(Solution::count_digit_one(1_000_000_000), 900_000_001); }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Mathematical (log n digit positions) | O(log n) | O(1) |

### Rust Notes

- `i64` is essential: `factor` reaches `10^9` and `higher * factor` can reach ~10^18 before final cast to `i32`.
- `match current { 0 => ..., 1 => ..., _ => ... }` is exhaustive by Rust's pattern rules — no default `else` needed.

---

## LC 357 — Count Numbers with Unique Digits

**Difficulty:** Medium

### Problem Statement

Given `n`, return the count of all numbers with unique digits `x` where `0 <= x < 10^n`.

### DP Design

Combinatorial reasoning: choose `k` digits for a `k`-digit number. The leading digit has 9 choices (1-9), each subsequent digit has decreasing choices from the remaining 9 non-leading digits.

| | Value |
|-|-------|
| **State** | `count[k]` = numbers with exactly `k` unique digits |
| **Base case** | `count[0] = 1` (the number 0), `count[1] = 9` (1-9) |
| **Transition** | `count[k] = 9 * 9 * 8 * 7 * ... * (9 - k + 2)` for `k >= 2` |
| **Answer** | Sum of `count[0..=n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn count_numbers_with_unique_digits(n: i32) -> i32 {
        if n == 0 { return 1; }
        let n = n.min(10) as usize; // digits 0-9, so n > 10 adds nothing
        let mut total = 10i32; // n=1: 0..=9
        let mut unique = 9i32; // choices for the leading digit of a 2-digit number
        let mut available = 9i32; // remaining slots
        for _ in 2..=n {
            unique *= available;
            total += unique;
            available -= 1;
        }
        total
    }
}

#[cfg(test)]
mod tests_lc357 {
    struct Solution;
    impl Solution {
        pub fn count_numbers_with_unique_digits(n: i32) -> i32 {
            if n == 0 { return 1; }
            let n = n.min(10) as usize;
            let mut total = 10i32;
            let mut unique = 9i32;
            let mut available = 9i32;
            for _ in 2..=n {
                unique *= available;
                total += unique;
                available -= 1;
            }
            total
        }
    }

    #[test]
    fn test_n0() { assert_eq!(Solution::count_numbers_with_unique_digits(0), 1); }
    #[test]
    fn test_n1() { assert_eq!(Solution::count_numbers_with_unique_digits(1), 10); }
    #[test]
    fn test_n2() { assert_eq!(Solution::count_numbers_with_unique_digits(2), 91); }
    #[test]
    fn test_n3() { assert_eq!(Solution::count_numbers_with_unique_digits(3), 739); }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| O(n) loop | O(n) | O(1) |

### Rust Notes

- `n.min(10)`: for `n > 10`, all 10 digits are used and no new unique-digit numbers are possible — clamp saves iterations.
- This problem is more combinatorics than digit DP, but it's a useful warm-up for understanding the "available digits" counting.

---

## LC 902 — Numbers At Most N Given Digit Set

**Difficulty:** Hard

### Problem Statement

Given an array of digit strings `digits` (sorted, no duplicates from `{'1'..'9'}`) and an integer `n`, return the count of positive integers that can be formed using the digits in `digits` that are less than or equal to `n`.

### DP Design

Split into two cases: numbers with **fewer digits** than `n`, and numbers with the **same digit count** as `n`.

| | Value |
|-|-------|
| **State** | For same-length: track position, whether we are still "tight" (equal to n's prefix so far) |
| **Shorter numbers** | For length `k < len(n)`: `D^k` numbers (D = digits count) — but leading zeros excluded: `D * D^(k-1) = D^k` since all digits are `>= 1` |
| **Same-length** | Digit DP: at each position, count digits in `digits` that are `<` current digit of `n` (free choices), then check if any digit equals current digit (continue tight) |
| **Answer** | Sum of shorter counts + same-length tight count |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn at_most_n_given_digit_set(digits: Vec<String>, n: i32) -> i32 {
        let n_str: Vec<u8> = n.to_string().bytes().collect();
        let len = n_str.len();
        let d: Vec<u8> = digits.iter().map(|s| s.as_bytes()[0]).collect();
        let d_count = d.len() as i32;
        let mut result = 0i32;
        // Count numbers with fewer digits than n
        let mut power = d_count;
        for _ in 1..len {
            result += power;
            power *= d_count;
        }
        // Count same-length numbers using tight digit DP
        // At each position, count free choices (digit < n_str[pos]),
        // then check if we can stay tight (digit == n_str[pos])
        let mut tight = true;
        for pos in 0..len {
            if !tight { break; }
            let limit = n_str[pos]; // current digit of n
            // Free choices: digits strictly less than limit
            let less_count = d.iter().filter(|&&c| c < limit).count() as i32;
            // For each free choice, remaining positions are all free: d_count^(len-1-pos)
            let remaining = (len - 1 - pos) as u32;
            result += less_count * d_count.pow(remaining);
            // Can we continue tight?
            tight = d.contains(&limit);
        }
        // If we stayed tight through all positions, n itself is valid
        if tight { result += 1; }
        result
    }
}

#[cfg(test)]
mod tests_lc902 {
    struct Solution;
    impl Solution {
        pub fn at_most_n_given_digit_set(digits: Vec<String>, n: i32) -> i32 {
            let n_str: Vec<u8> = n.to_string().bytes().collect();
            let len = n_str.len();
            let d: Vec<u8> = digits.iter().map(|s| s.as_bytes()[0]).collect();
            let d_count = d.len() as i32;
            let mut result = 0i32;
            let mut power = d_count;
            for _ in 1..len { result += power; power *= d_count; }
            let mut tight = true;
            for pos in 0..len {
                if !tight { break; }
                let limit = n_str[pos];
                let less_count = d.iter().filter(|&&c| c < limit).count() as i32;
                let remaining = (len - 1 - pos) as u32;
                result += less_count * d_count.pow(remaining);
                tight = d.contains(&limit);
            }
            if tight { result += 1; }
            result
        }
    }

    #[test]
    fn test_example1() {
        let digits = vec!["1".to_string(), "3".to_string(), "5".to_string(), "7".to_string()];
        assert_eq!(Solution::at_most_n_given_digit_set(digits, 100), 20);
    }

    #[test]
    fn test_example2() {
        let digits = vec!["1".to_string(), "4".to_string(), "9".to_string()];
        assert_eq!(Solution::at_most_n_given_digit_set(digits, 1000000000), 29523);
    }

    #[test]
    fn test_single_digit() {
        let digits = vec!["7".to_string()];
        assert_eq!(Solution::at_most_n_given_digit_set(digits, 8), 1);
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| O(log n * D) | O(log n) digits, D = digit set size | O(log n) |

### Rust Notes

- `n.to_string().bytes()` extracts ASCII digit bytes — `'1'` as `u8` is `49`, so comparisons `c < limit` work on ASCII values directly.
- `d_count.pow(remaining)` uses `i32::pow` — works for small exponents; for very large n, upgrade to `i64`.

---

## LC 1012 — Numbers With Repeated Digits

**Difficulty:** Hard

### Problem Statement

Given `n`, return the count of positive integers `<= n` that have **at least one repeated digit**.

### DP Design

Use complementary counting: `answer = n - count_unique_digit_numbers(n)`.

Count unique-digit numbers up to `n` using digit DP: track `tight`, `started` (past leading zeros), and a bitmask of used digits.

| | Value |
|-|-------|
| **State** | `dp(pos, mask, tight, started)` = count of valid completions |
| **Base case** | When `pos == len`: if `started`, count 1; else 0 |
| **Transition** | Try each digit `d` from 0 to `(tight ? n_digit[pos] : 9)`. If `started` and `mask` has `d` set, skip. Otherwise recurse. |
| **Answer** | `n - dp(0, 0, true, false)` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn num_dup_digits_at_most_n(n: i32) -> i32 {
        let digits: Vec<i32> = n
            .to_string()
            .bytes()
            .map(|b| (b - b'0') as i32)
            .collect();
        let len = digits.len();
        // Count unique-digit numbers in [1..=n]
        let unique = Self::count_unique(&digits, 0, 0, true, false, &mut vec![vec![vec![[-1i32; 2]; 2]; 1024]; len]);
        n - unique
    }

    fn count_unique(
        digits: &[i32],
        pos: usize,
        mask: usize,
        tight: bool,
        started: bool,
        memo: &mut Vec<Vec<Vec<[i32; 2]>>>,
    ) -> i32 {
        if pos == digits.len() {
            return if started { 1 } else { 0 };
        }
        let ti = tight as usize;
        let si = started as usize;
        if memo[pos][mask][ti][si] != -1 {
            return memo[pos][mask][ti][si];
        }
        let limit = if tight { digits[pos] } else { 9 };
        let mut count = 0i32;
        for d in 0..=limit {
            if started && (mask >> d) & 1 == 1 {
                continue; // repeated digit — skip
            }
            let new_mask = if started || d > 0 { mask | (1 << d) } else { 0 };
            let new_started = started || d > 0;
            let new_tight = tight && d == limit;
            count += Self::count_unique(digits, pos + 1, new_mask, new_tight, new_started, memo);
        }
        memo[pos][mask][ti][si] = count;
        count
    }
}

#[cfg(test)]
mod tests_lc1012 {
    struct Solution;
    impl Solution {
        pub fn num_dup_digits_at_most_n(n: i32) -> i32 {
            let digits: Vec<i32> = n.to_string().bytes().map(|b| (b - b'0') as i32).collect();
            let len = digits.len();
            let unique = Self::count_unique(&digits, 0, 0, true, false,
                &mut vec![vec![vec![[-1i32; 2]; 2]; 1024]; len]);
            n - unique
        }
        fn count_unique(digits: &[i32], pos: usize, mask: usize, tight: bool, started: bool,
            memo: &mut Vec<Vec<Vec<[i32; 2]>>>) -> i32 {
            if pos == digits.len() { return if started { 1 } else { 0 }; }
            let ti = tight as usize;
            let si = started as usize;
            if memo[pos][mask][ti][si] != -1 { return memo[pos][mask][ti][si]; }
            let limit = if tight { digits[pos] } else { 9 };
            let mut count = 0i32;
            for d in 0..=limit {
                if started && (mask >> d) & 1 == 1 { continue; }
                let new_mask = if started || d > 0 { mask | (1 << d) } else { 0 };
                let new_started = started || d > 0;
                let new_tight = tight && d == limit;
                count += Self::count_unique(digits, pos + 1, new_mask, new_tight, new_started, memo);
            }
            memo[pos][mask][ti][si] = count;
            count
        }
    }

    #[test]
    fn test_20() { assert_eq!(Solution::num_dup_digits_at_most_n(20), 1); }
    #[test]
    fn test_100() { assert_eq!(Solution::num_dup_digits_at_most_n(100), 10); }
    #[test]
    fn test_1000() { assert_eq!(Solution::num_dup_digits_at_most_n(1000), 262); }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Digit DP | O(10 * log(n) * 2^10 * 2 * 2) | O(log(n) * 2^10) |

### Rust Notes

- `memo` shape is `[len][1024][2][2]` — `1024 = 2^10` for the digit bitmask (digits 0-9). This is allocated as a Vec of Vecs; for large inputs a flat array is faster.
- `(b - b'0') as i32` converts ASCII byte to digit value — `b'0'` is the byte literal for character `'0'`.
- The `started` flag handles leading zeros: we don't mark a digit as "used" until a non-zero digit is placed.

---

## LC 2376 — Count Special Integers

**Difficulty:** Hard

### Problem Statement

A positive integer is **special** if all its digits are unique. Given `n`, return the count of special integers in the range `[1..n]`.

### DP Design

Same structure as LC #1012 (count_unique), but we return the result directly instead of using complementary counting.

| | Value |
|-|-------|
| **State** | `dp(pos, mask, tight, started)` = count of special numbers completing the number |
| **Base case** | `pos == len` and `started`: return 1 |
| **Transition** | For each valid digit (not in mask if started): recurse |
| **Answer** | `dp(0, 0, true, false)` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn count_special_numbers(n: i32) -> i32 {
        let digits: Vec<i32> = n
            .to_string()
            .bytes()
            .map(|b| (b - b'0') as i32)
            .collect();
        let len = digits.len();
        // memo[pos][mask][tight][started]
        let mut memo = vec![vec![vec![[-1i32; 2]; 2]; 1024]; len];
        Self::dp(&digits, 0, 0, true, false, &mut memo)
    }

    fn dp(
        digits: &[i32],
        pos: usize,
        mask: usize,
        tight: bool,
        started: bool,
        memo: &mut Vec<Vec<Vec<[i32; 2]>>>,
    ) -> i32 {
        if pos == digits.len() {
            return if started { 1 } else { 0 };
        }
        let ti = tight as usize;
        let si = started as usize;
        if memo[pos][mask][ti][si] != -1 {
            return memo[pos][mask][ti][si];
        }
        let limit = if tight { digits[pos] } else { 9 };
        let mut count = 0i32;
        for d in 0..=limit {
            // Skip repeated digit (only when started)
            if started && (mask >> d) & 1 == 1 {
                continue;
            }
            let new_mask = if started || d > 0 { mask | (1 << d) } else { 0 };
            let new_started = started || d > 0;
            let new_tight = tight && d == limit;
            count += Self::dp(digits, pos + 1, new_mask, new_tight, new_started, memo);
        }
        memo[pos][mask][ti][si] = count;
        count
    }
}

#[cfg(test)]
mod tests_lc2376 {
    struct Solution;
    impl Solution {
        pub fn count_special_numbers(n: i32) -> i32 {
            let digits: Vec<i32> = n.to_string().bytes().map(|b| (b - b'0') as i32).collect();
            let len = digits.len();
            let mut memo = vec![vec![vec![[-1i32; 2]; 2]; 1024]; len];
            Self::dp(&digits, 0, 0, true, false, &mut memo)
        }
        fn dp(digits: &[i32], pos: usize, mask: usize, tight: bool, started: bool,
              memo: &mut Vec<Vec<Vec<[i32; 2]>>>) -> i32 {
            if pos == digits.len() { return if started { 1 } else { 0 }; }
            let ti = tight as usize;
            let si = started as usize;
            if memo[pos][mask][ti][si] != -1 { return memo[pos][mask][ti][si]; }
            let limit = if tight { digits[pos] } else { 9 };
            let mut count = 0i32;
            for d in 0..=limit {
                if started && (mask >> d) & 1 == 1 { continue; }
                let new_mask = if started || d > 0 { mask | (1 << d) } else { 0 };
                let new_started = started || d > 0;
                let new_tight = tight && d == limit;
                count += Self::dp(digits, pos + 1, new_mask, new_tight, new_started, memo);
            }
            memo[pos][mask][ti][si] = count;
            count
        }
    }

    #[test]
    fn test_20() { assert_eq!(Solution::count_special_numbers(20), 19); }
    #[test]
    fn test_5() { assert_eq!(Solution::count_special_numbers(5), 5); }
    #[test]
    fn test_135() { assert_eq!(Solution::count_special_numbers(135), 110); }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Digit DP | O(10 * log(n) * 2^10 * 4) | O(log(n) * 2^10) |

### Rust Notes

- LC #1012 and LC #2376 share the same skeleton — the only difference is LC #1012 returns `n - count_unique` (complementary counting).
- `[i32; 2]` as the innermost array is a fixed-size stack-allocated array — more cache-friendly than a nested `Vec<Vec<i32>>`.
- The 4-dimensional memo `[pos][mask][tight][started]` is the standard digit DP template; commit this shape to memory for all digit counting problems.

---

## Part 1 Review Notes

### Critical Notes and Common Pitfalls

| Problem | Key Insight | Common Mistake |
|---------|-------------|----------------|
| LC 516 (LPS) | `dp[i][j] = dp[i+1][j-1] + 2` when chars match | Forgetting the `len == 2` base case guard — accessing `dp[i+1][i]` gives 0 but correct answer is 2 |
| LC 1039 (Triangulation) | Fix edge `(i,j)`, choose apex `k` — products stay in `i32` range for values ≤ 1000 | Forgetting to initialize `dp[i][j] = i32::MAX` before the `k` loop |
| LC 1000 (Merge Stones) | Feasibility: `(n-1) % (k-1) == 0`; step = `k-1` in split loop | Using step 1 instead of `k-1`; overflow when `k=2` and stones are large |
| LC 312 (Burst Balloons) | "Last burst" framing with open intervals; pad with sentinel 1s | Using closed intervals and handling boundary conditions ad-hoc |
| LC 664 (Strange Printer) | When `s[k] == s[j]`, the turn printing `s[k]` can be extended to cover `s[j]` for free | Not guarding `dp[k+1][j-1]` when `k+1 > j-1` |
| LC 1547 (Cut Stick) | Sort cuts + add 0 and n; interval DP on the cut indices | Not sorting; treating costs as stick lengths instead of interval widths |
| LC 546 (Remove Boxes) | 3-D DP needed: `dp[l][r][k]` where `k` = extra same-colored boxes attached | Trying 2-D DP and missing the "detached same-color merge" optimization |
| LC 1312 (Min Insertions) | Equals `n - LPS(s)` — or direct interval DP with same structure | Same `len == 2` guard as LC 516 |
| LC 877 (Stone Game) | Alice always wins (mathematical); DP needed only for generalization | Returning `true` without DP (accepted but defeats learning purpose) |
| LC 1140 (Stone Game II) | Score-difference trick with suffix sums; `M` bounded by `n` | Allocating `M` dimension too small |
| LC 1406 (Stone Game III) | 1-D score-difference DP, iterate right-to-left | Initializing `dp[i] = 0` instead of `i32::MIN` — wrong when no moves score negative |
| LC 1510 (Stone Game IV) | Boolean DP; current player wins if any square removal leads to opponent loss | Confusing `dp[0] = false` (losing) with the initial state |
| LC 375 (Guess Number) | Minimax: worst case over all guesses; guard `k > i` and `k < j` for `usize` bounds | `usize` underflow when computing `dp[i][k-1]` at `k=0` (guarded by `k > i`) |
| LC 486 (Predict Winner) | Same as LC 877 with `>= 0` (tie allowed); works for odd-length arrays | Forgetting ties count as Player 1 winning |
| LC 464 (Can I Win) | Bitmask DP; early exits: `desiredTotal <= 0` always true; sum < target always false | `u32` mask overflow if `maxChoosableInteger > 20` |
| LC 233 (Digit Ones) | Mathematical per-position counting — O(log n), no DP table | Integer overflow: `higher * factor` requires `i64` |
| LC 357 (Unique Digits) | Combinatorics: `9 * 9 * 8 * ... * (10-k+1)` for k-digit numbers; clamp n at 10 | Not clamping at n=10 (loop runs but adds 0 each time — harmless but unnecessary) |
| LC 902 (Digit Set) | Tight/free split: shorter numbers = `D^k` per length; same-length = tight DP | Off-by-one in "shorter" count loop; forgetting final `if tight { result += 1 }` |
| LC 1012 (Repeated Digits) | Complement: `n - count_unique(n)`. Full digit DP with `started` flag | Not handling leading zeros (`started` flag critical for correct mask state) |
| LC 2376 (Special Integers) | Same digit DP as LC 1012 directly (not complement) | Same `started` / `mask` pitfalls as LC 1012 |

### Fact-Check Table

| Claim | Verified |
|-------|---------|
| LC 516 LPS of "bbbab" = 4 ("bbbb") | Correct |
| LC 312 [3,1,5,8] → 167 (burst order: 1,5,3,8) | Correct |
| LC 877 Alice always wins when n even, total odd | Correct (parity argument) |
| LC 1406 [1,2,3,7] → "Bob" wins | Correct (Bob can always respond to claim 7) |
| LC 1510 dp[0]=false means 0 stones = losing position | Correct by problem definition |
| LC 233 count_digit_one(1_000_000_000) = 900,000,001 | Correct: 9 positions contribute 10^8 each (900,000,000) + 1 for the leading digit itself |
| LC 357 n=2 → 91 (10 single-digit + 81 two-digit unique) | Correct: 9*9=81 two-digit + 10 = 91 |
| LC 902 digits=["1","3","5","7"], n=100 → 20 | Correct: 4 one-digit + 16 two-digit = 20 |
| LC 1012 num_dup_digits(100) = 10 | Correct: 11,22,33,44,55,66,77,88,99,100 = 10 |
| LC 2376 count_special(135) = 110 | Correct per LeetCode test cases |
| Interval DP time complexity always O(n³) | Correct for problems with O(n) split points |
| Digit DP state space = O(log(n) * 2^10 * 4) | Correct for 10-digit problems with tight+started flags |
