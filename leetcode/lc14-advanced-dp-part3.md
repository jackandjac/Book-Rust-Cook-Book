# Chapter LC-14 Part 3: String DP, Probability DP, D&C Optimization, Advanced Knapsack

> **Part 3 of the Advanced DP (Grandmaster) series.** This chapter covers four
> specialized DP families: advanced string matching, probability / expected-value
> DP, divide-and-conquer optimization, and multidimensional knapsack variants.
> Every code block is self-contained and compiles with `rustc --test`.

---

## Problem Overview

| # | LC | Problem | Section | Difficulty |
|---|-----|---------|---------|-----------|
| 1 | 10 | Regular Expression Matching (clean state table) | String DP | Hard |
| 2 | 44 | Wildcard Matching | String DP | Hard |
| 3 | 1458 | Max Dot Product of Two Subsequences | String DP | Hard |
| 4 | 1092 | Shortest Common Supersequence | String DP | Hard |
| 5 | 1062 | Longest Repeating Substring *(Premium)* | String DP | Medium |
| 6 | 718 | Maximum Length of Repeated Subarray | String DP | Medium |
| 7 | 1035 | Uncrossed Lines | String DP | Medium |
| 8 | 837 | New 21 Game | Probability DP | Medium |
| 9 | 688 | Knight Probability in Chessboard | Probability DP | Medium |
| 10 | 576 | Out of Boundary Paths | Probability DP | Medium |
| 11 | 1230 | Toss Strange Coins | Probability DP | Medium |
| 12 | 808 | Soup Servings | Probability DP | Medium |
| 13 | 1278 | Palindrome Partitioning III | D&C Opt. | Hard |
| 14 | 1335 | Minimum Difficulty of a Job Schedule | D&C Opt. | Hard |
| 15 | 410 | Split Array Largest Sum (DP + D&C) | D&C Opt. | Hard |
| 16 | 813 | Largest Sum of Averages | D&C Opt. | Medium |
| 17 | 879 | Profitable Schemes | Adv. Knapsack | Hard |
| 18 | 956 | Tallest Billboard | Adv. Knapsack | Hard |
| 19 | 1049 | Last Stone Weight II | Adv. Knapsack | Medium |
| 20 | 474 | Ones and Zeroes | Adv. Knapsack | Medium |
| 21 | 1066 | Campus Bikes II *(Premium)* | Adv. Knapsack | Hard |
| 22 | 1981 | Minimize Difference Between Target and Chosen Elements | Adv. Knapsack | Hard |

---

## Section 7: DP on Strings (Advanced)

> **Key distinction — two adjacent "repeated" problems:**
> - **LC #718** finds the longest *contiguous* common subarray (substring).
> - **LC #1035** finds the longest common *subsequence* (elements need not be contiguous).
> They differ by one word and produce different tables — do not conflate them.

---

## LC #10 — Regular Expression Matching (Clean State Table Revisit)

**Difficulty:** Hard | Previously solved in LC-08 with 2-D DP.

### Problem Statement

Match string `s` against pattern `p` where `.` matches any single character and
`*` matches zero or more of the **preceding** element. The entire string must match.

> **`*` semantics here:** `*` is paired with the character before it (`a*` = zero
> or more `a`s). This differs from LC #44 where `*` stands alone.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = `s[0..i]` fully matched by `p[0..j]` |
| **Base** | `dp[0][0] = true`; `dp[0][j] = dp[0][j-2]` when `p[j-1]=='*'` |
| **`p[j-1] != '*'`** | `dp[i][j] = dp[i-1][j-1] && (p[j-1]=='.' \|\| p[j-1]==s[i-1])` |
| **`p[j-1] == '*'`** | zero copies: `dp[i][j-2]`; one+ copies: `dp[i-1][j] && char_match` |
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
        // Patterns like a* a*b* can match empty string
        for j in 2..=n {
            if pb[j - 1] == b'*' {
                dp[0][j] = dp[0][j - 2];
            }
        }
        for i in 1..=m {
            for j in 1..=n {
                if pb[j - 1] == b'*' {
                    dp[i][j] = dp[i][j - 2];  // zero copies
                    if pb[j - 2] == b'.' || pb[j - 2] == sb[i - 1] {
                        dp[i][j] = dp[i][j] || dp[i - 1][j];  // one+ copies
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
    fn test_regex() {
        assert!(!Solution::is_match("aa".into(), "a".into()));
        assert!(Solution::is_match("aa".into(), "a*".into()));
        assert!(Solution::is_match("ab".into(), ".*".into()));
        assert!(Solution::is_match("aab".into(), "c*a*b".into()));
        assert!(!Solution::is_match("mississippi".into(), "mis*is*p*.".into()));
        assert!(Solution::is_match("".into(), "a*b*".into()));
    }
}

fn main() {}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Rust notes:** `b'*'` and `b'.'` are byte literals (`u8`), avoiding a `char` cast.
The `||` short-circuit on the `*` branch mirrors the two-case logic cleanly.

---

## LC #44 — Wildcard Matching

**Difficulty:** Hard

### Problem Statement

Match string `s` against pattern `p` where `?` matches any single character and
`*` matches **any sequence** of characters (including empty). The entire string must match.

> **`*` semantics here:** `*` stands alone and can expand to anything. No pairing
> with a preceding character — fundamentally different from LC #10.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = `s[0..i]` fully matched by `p[0..j]` |
| **Base** | `dp[0][0] = true`; `dp[0][j] = dp[0][j-1]` when `p[j-1]=='*'` |
| **`p[j-1] == '*'`** | `dp[i][j-1]` (empty) `\|\| dp[i-1][j]` (consume one more char) |
| **otherwise** | `dp[i-1][j-1] && (p[j-1]=='?' \|\| p[j-1]==s[i-1])` |
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
        // Leading stars match empty string
        for j in 1..=n {
            if pb[j - 1] == b'*' {
                dp[0][j] = dp[0][j - 1];
            }
        }
        for i in 1..=m {
            for j in 1..=n {
                if pb[j - 1] == b'*' {
                    // Empty expansion OR consume one char of s
                    dp[i][j] = dp[i][j - 1] || dp[i - 1][j];
                } else {
                    dp[i][j] = dp[i - 1][j - 1]
                        && (pb[j - 1] == b'?' || pb[j - 1] == sb[i - 1]);
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
    fn test_wildcard() {
        assert!(!Solution::is_match("aa".into(), "a".into()));
        assert!(Solution::is_match("aa".into(), "*".into()));
        assert!(!Solution::is_match("cb".into(), "?a".into()));
        assert!(Solution::is_match("adceb".into(), "*a*b".into()));
        assert!(!Solution::is_match("acdcb".into(), "a*c?b".into()));
        assert!(Solution::is_match("".into(), "***".into()));
    }
}

fn main() {}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Rust notes:** The base-case loop for `*` differs from LC #10: here `dp[0][j] =
dp[0][j-1]` (chain of stars); in LC #10 `dp[0][j] = dp[0][j-2]` (star must be
paired). Mixing these up is the most common bug between the two problems.

---

## LC #1458 — Max Dot Product of Two Subsequences

**Difficulty:** Hard

### Problem Statement

Given arrays `nums1` and `nums2`, choose (possibly empty) subsequences with equal
length and maximize the dot product. At least one element must be chosen.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = max dot product using `nums1[0..i]` and `nums2[0..j]` |
| **Base** | `dp[i][j] = nums1[i-1]*nums2[j-1]` minimum (take the one forced pair) |
| **Transition** | `dp[i][j] = max(nums1[i-1]*nums2[j-1], max(0,dp[i-1][j-1])+nums1[i-1]*nums2[j-1], dp[i-1][j], dp[i][j-1])` |
| **Answer** | `dp[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn max_dot_product(nums1: Vec<i32>, nums2: Vec<i32>) -> i32 {
        let (m, n) = (nums1.len(), nums2.len());
        // dp[i][j]: best dot product from nums1[0..i], nums2[0..j]
        let mut dp = vec![vec![i32::MIN; n + 1]; m + 1];
        for i in 1..=m {
            for j in 1..=n {
                let prod = nums1[i - 1] * nums2[j - 1];
                dp[i][j] = prod;
                if dp[i - 1][j - 1] > 0 {
                    dp[i][j] = dp[i][j].max(dp[i - 1][j - 1] + prod);
                }
                if dp[i - 1][j] != i32::MIN {
                    dp[i][j] = dp[i][j].max(dp[i - 1][j]);
                }
                if dp[i][j - 1] != i32::MIN {
                    dp[i][j] = dp[i][j].max(dp[i][j - 1]);
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
    fn test_dot_product() {
        assert_eq!(Solution::max_dot_product(vec![2,1,-2,5], vec![3,0,-6]), 18);
        assert_eq!(Solution::max_dot_product(vec![3,-2], vec![2,-6,7]), 21);
        assert_eq!(Solution::max_dot_product(vec![-1,-1], vec![1,1]), -1);
    }
}

fn main() {}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Rust notes:** `i32::MIN` as sentinel avoids conflating "no pair chosen yet" with a
legitimately negative dot product. The guard `dp[i-1][j-1] > 0` ensures we only
extend a previous pair when doing so is beneficial.

---

## LC #1092 — Shortest Common Supersequence

**Difficulty:** Hard

### Problem Statement

Given strings `str1` and `str2`, find the shortest string that has both as subsequences.

### DP Design

Build LCS table, then reconstruct the supersequence by walking back through the
LCS trace, interleaving characters from both strings.

| | Value |
|-|-------|
| **State** | `lcs[i][j]` = length of LCS of `str1[0..i]` and `str2[0..j]` |
| **Transition** | equal chars: `lcs[i-1][j-1]+1`; else `max(lcs[i-1][j], lcs[i][j-1])` |
| **Answer** | reconstruct via back-trace; result length = `m+n-lcs[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn shortest_common_supersequence(str1: String, str2: String) -> String {
        let (s, t) = (str1.as_bytes(), str2.as_bytes());
        let (m, n) = (s.len(), t.len());
        // Build LCS table
        let mut lcs = vec![vec![0usize; n + 1]; m + 1];
        for i in 1..=m {
            for j in 1..=n {
                lcs[i][j] = if s[i-1] == t[j-1] {
                    lcs[i-1][j-1] + 1
                } else {
                    lcs[i-1][j].max(lcs[i][j-1])
                };
            }
        }
        // Reconstruct by back-tracing
        let mut result = Vec::new();
        let (mut i, mut j) = (m, n);
        while i > 0 && j > 0 {
            if s[i-1] == t[j-1] {
                result.push(s[i-1]);
                i -= 1; j -= 1;
            } else if lcs[i-1][j] > lcs[i][j-1] {
                result.push(s[i-1]);
                i -= 1;
            } else {
                result.push(t[j-1]);
                j -= 1;
            }
        }
        while i > 0 { result.push(s[i-1]); i -= 1; }
        while j > 0 { result.push(t[j-1]); j -= 1; }
        result.reverse();
        String::from_utf8(result).unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_scs_length() {
        // Multiple valid answers exist; verify length = m+n-lcs
        let r = Solution::shortest_common_supersequence("abac".into(), "cab".into());
        assert_eq!(r.len(), 5);  // e.g. "cabac"
        let r2 = Solution::shortest_common_supersequence("abc".into(), "abc".into());
        assert_eq!(r2.len(), 3);
    }
    #[test]
    fn test_scs_is_supersequence() {
        fn is_subseq(needle: &str, haystack: &str) -> bool {
            let mut it = haystack.chars();
            needle.chars().all(|c| it.any(|h| h == c))
        }
        let s = "abac".to_string();
        let t = "cab".to_string();
        let r = Solution::shortest_common_supersequence(s.clone(), t.clone());
        assert!(is_subseq(&s, &r));
        assert!(is_subseq(&t, &r));
    }
}

fn main() {}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Rust notes:** Back-tracing builds the answer in reverse; `result.reverse()` at the
end is cleaner than using a `VecDeque`. The test validates the SCS property rather
than an exact string, since multiple valid answers exist.

---

## LC #1062 — Longest Repeating Substring *(Premium)*

**Difficulty:** Medium *(LeetCode Premium — standard DP approach shown)*

### Problem Statement

Find the length of the longest substring of `s` that occurs at least twice (the
two occurrences may overlap).

### DP Design

Classic "longest common substring" DP on `s` with itself, forbidding the diagonal
(same index) to ensure two distinct occurrences.

| | Value |
|-|-------|
| **State** | `dp[i][j]` = length of longest common suffix of `s[0..i]` and `s[0..j]` |
| **Transition** | `s[i-1]==s[j-1] && i!=j`: `dp[i-1][j-1]+1`; else `0` |
| **Answer** | global maximum over all `dp[i][j]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn longest_repeating_substring(s: String) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        let mut dp = vec![vec![0i32; n + 1]; n + 1];
        let mut ans = 0i32;
        for i in 1..=n {
            for j in (i + 1)..=n {   // j > i enforces distinct positions
                if b[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                    ans = ans.max(dp[i][j]);
                }
            }
        }
        ans
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_repeating() {
        assert_eq!(Solution::longest_repeating_substring("abcd".into()), 0);
        assert_eq!(Solution::longest_repeating_substring("abbaba".into()), 2);
        assert_eq!(Solution::longest_repeating_substring("aabaabaab".into()), 6);
    }
}

fn main() {}
```

**Time:** O(n²) | **Space:** O(n²) — binary search + rolling hash reduces to O(n log n)

**Rust notes:** The inner loop starts at `j = i+1` to guarantee distinct indices,
avoiding a separate `i != j` guard inside the hot path.

---

## LC #718 — Maximum Length of Repeated Subarray

**Difficulty:** Medium

### Problem Statement

Given two integer arrays `nums1` and `nums2`, find the maximum length of a subarray
that appears in **both** (contiguous, same values). This is longest common *substring*
on integer arrays.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[i][j]` = length of longest common suffix ending at `nums1[i-1]`, `nums2[j-1]` |
| **Transition** | `nums1[i-1]==nums2[j-1]`: `dp[i-1][j-1]+1`; else `0` |
| **Answer** | global maximum |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn find_length(nums1: Vec<i32>, nums2: Vec<i32>) -> i32 {
        let (m, n) = (nums1.len(), nums2.len());
        let mut dp = vec![vec![0i32; n + 1]; m + 1];
        let mut ans = 0;
        for i in 1..=m {
            for j in 1..=n {
                if nums1[i - 1] == nums2[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                    ans = ans.max(dp[i][j]);
                }
                // else dp[i][j] stays 0 — no extension possible
            }
        }
        ans
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_repeated_subarray() {
        assert_eq!(Solution::find_length(vec![1,2,3,2,1], vec![3,2,1,4,7]), 3);
        assert_eq!(Solution::find_length(vec![0,0,0,0,0], vec![0,0,0,0,0]), 5);
        assert_eq!(Solution::find_length(vec![1,2], vec![3,4]), 0);
    }
}

fn main() {}
```

**Time:** O(m × n) | **Space:** O(m × n), reducible to O(min(m,n)) with rolling row

**Rust notes:** Unlike LCS (`max` of three cells), this table resets to `0` on
mismatch because a common subarray must be contiguous.

---

## LC #1035 — Uncrossed Lines

**Difficulty:** Medium

### Problem Statement

Draw lines connecting equal values `nums1[i]` to `nums2[j]`. Lines must not cross
(indices must be strictly increasing on both sides). Maximize number of lines drawn.
This is exactly **Longest Common Subsequence** on integer arrays.

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn max_uncrossed_lines(nums1: Vec<i32>, nums2: Vec<i32>) -> i32 {
        let (m, n) = (nums1.len(), nums2.len());
        let mut dp = vec![vec![0i32; n + 1]; m + 1];
        for i in 1..=m {
            for j in 1..=n {
                dp[i][j] = if nums1[i-1] == nums2[j-1] {
                    dp[i-1][j-1] + 1
                } else {
                    dp[i-1][j].max(dp[i][j-1])
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
    fn test_uncrossed() {
        assert_eq!(Solution::max_uncrossed_lines(vec![1,4,2], vec![1,2,4]), 2);
        assert_eq!(Solution::max_uncrossed_lines(vec![2,5,1,2,5], vec![10,5,2,1,5,2]), 3);
        assert_eq!(Solution::max_uncrossed_lines(vec![1,3,7,1,7,5], vec![1,9,2,5,1]), 2);
    }
}

fn main() {}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Rust notes:** When you recognize the geometric interpretation reduces to LCS, the
code is identical to LC #1143. The key insight deserves a comment in an interview.

---

## Section 8: Probability and Expected Value DP

> **Floating-point rule:** Never use `assert_eq!` on `f64`. All tests check
> `(actual - expected).abs() < 1e-5`, matching LeetCode's tolerance.

---

## LC #837 — New 21 Game

**Difficulty:** Medium

### Problem Statement

Alice scores points by drawing 1 to `maxPts` each round, stopping at `n` points or
more. What is the probability her final score is `<= k+maxPts-1` — i.e. at most `n`
total — when she stops at `k` or more?

Constraints: `0 <= k <= n <= 10^4`, `1 <= maxPts <= 10^4`.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[x]` = probability of reaching exactly score `x` |
| **Base** | `dp[0] = 1.0` |
| **Transition** | `dp[i] = window_sum / maxPts` where `window_sum = sum(dp[i-maxPts..i])` |
| **Sliding window** | maintain `window_sum` in O(1) by adding `dp[i-1]` and removing `dp[i-1-maxPts]` |
| **Answer** | sum of `dp[k..=n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn new21_game(n: i32, k: i32, max_pts: i32) -> f64 {
        let (n, k, w) = (n as usize, k as usize, max_pts as usize);
        if k == 0 || n >= k + w - 1 {
            return 1.0;
        }
        let mut dp = vec![0.0f64; n + 1];
        dp[0] = 1.0;
        let mut window_sum = 1.0f64;
        for i in 1..=n {
            // Sliding-window average over the last w values
            dp[i] = window_sum / w as f64;
            if i < k {
                window_sum += dp[i];           // new score enters window
            }
            if i >= w {
                window_sum -= dp[i - w];       // old score leaves window
            }
        }
        dp[k..=n].iter().sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn close(a: f64, b: f64) -> bool { (a - b).abs() < 1e-5 }
    #[test]
    fn test_new21() {
        assert!(close(Solution::new21_game(10, 1, 10), 1.0));
        assert!(close(Solution::new21_game(6, 1, 10), 0.6));
        assert!(close(Solution::new21_game(21, 17, 10), 0.73278));
    }
}

fn main() {}
```

**Time:** O(n) | **Space:** O(n)

**Rust notes:** The sliding-window sum replaces the naive O(n × maxPts) inner loop.
`dp[k..=n].iter().sum()` is idiomatic; the range is inclusive of `n`.

---

## LC #688 — Knight Probability in Chessboard

**Difficulty:** Medium

### Problem Statement

An `n×n` chessboard. A knight starts at `(row, col)` and makes exactly `k` moves,
each chosen uniformly at random from up to 8 valid moves. What is the probability it
stays on the board after all `k` moves?

### DP Design

| | Value |
|-|-------|
| **State** | `dp[r][c]` = probability of being at `(r,c)` after current step |
| **Transition** | for each cell add `dp[r][c]/8` to each of the 8 knight-move targets |
| **Answer** | sum all `dp[r][c]` after `k` steps |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn knight_probability(n: i32, k: i32, row: i32, column: i32) -> f64 {
        let n = n as usize;
        let moves: [(i32,i32); 8] = [(-2,-1),(-2,1),(-1,-2),(-1,2),
                                      (1,-2),(1,2),(2,-1),(2,1)];
        let mut dp = vec![vec![0.0f64; n]; n];
        dp[row as usize][column as usize] = 1.0;
        for _ in 0..k {
            let mut next = vec![vec![0.0f64; n]; n];
            for r in 0..n {
                for c in 0..n {
                    if dp[r][c] == 0.0 { continue; }
                    for &(dr, dc) in &moves {
                        let (nr, nc) = (r as i32 + dr, c as i32 + dc);
                        if nr >= 0 && nr < n as i32 && nc >= 0 && nc < n as i32 {
                            next[nr as usize][nc as usize] += dp[r][c] / 8.0;
                        }
                    }
                }
            }
            dp = next;
        }
        dp.iter().flat_map(|row| row.iter()).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn close(a: f64, b: f64) -> bool { (a - b).abs() < 1e-5 }
    #[test]
    fn test_knight_prob() {
        assert!(close(Solution::knight_probability(3, 2, 0, 0), 0.0625));
        assert!(close(Solution::knight_probability(1, 0, 0, 0), 1.0));
    }
}

fn main() {}
```

**Time:** O(k × n²) | **Space:** O(n²)

**Rust notes:** `flat_map(|row| row.iter()).sum()` flattens the 2-D grid into one
iterator — a clean alternative to a nested sum loop.

---

## LC #576 — Out of Boundary Paths

**Difficulty:** Medium

### Problem Statement

An `m×n` grid. Starting at `(startRow, startCol)`, make exactly `maxMove` moves
(up/down/left/right). Count paths that leave the boundary at any step. Return answer
modulo `10^9 + 7`.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[r][c]` = number of active paths at `(r,c)` after current move |
| **Transition** | for each neighbor: if out-of-bounds, add to `ans`; else accumulate into `next` |
| **Answer** | running `ans` summing all boundary-exits |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn find_paths(m: i32, n: i32, max_move: i32, start_row: i32, start_col: i32) -> i32 {
        const MOD: u64 = 1_000_000_007;
        let (m, n) = (m as usize, n as usize);
        let dirs: [(i32,i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
        let mut dp = vec![vec![0u64; n]; m];
        dp[start_row as usize][start_col as usize] = 1;
        let mut ans: u64 = 0;
        for _ in 0..max_move {
            let mut next = vec![vec![0u64; n]; m];
            for r in 0..m {
                for c in 0..n {
                    if dp[r][c] == 0 { continue; }
                    for &(dr, dc) in &dirs {
                        let (nr, nc) = (r as i32 + dr, c as i32 + dc);
                        if nr < 0 || nr >= m as i32 || nc < 0 || nc >= n as i32 {
                            ans = (ans + dp[r][c]) % MOD;
                        } else {
                            next[nr as usize][nc as usize] =
                                (next[nr as usize][nc as usize] + dp[r][c]) % MOD;
                        }
                    }
                }
            }
            dp = next;
        }
        ans as i32
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_out_of_boundary() {
        assert_eq!(Solution::find_paths(2, 2, 2, 0, 0), 6);
        assert_eq!(Solution::find_paths(1, 3, 3, 0, 1), 12);
    }
}

fn main() {}
```

**Time:** O(maxMove × m × n) | **Space:** O(m × n)

**Rust notes:** Using `u64` for `dp` and `ans` prevents intermediate overflow before
the `% MOD` reduction. Final cast to `i32` is safe since the result is `< MOD < i32::MAX`.

---

## LC #1230 — Toss Strange Coins

**Difficulty:** Medium *(LeetCode Premium)*

### Problem Statement

Given `n` coins where coin `i` has probability `prob[i]` of heads, find the
probability of getting exactly `target` heads total.

### DP Design

1-D rolling DP; process each coin in-place, iterating `j` downward (classic 0/1
knapsack update).

| | Value |
|-|-------|
| **State** | `dp[j]` = probability of exactly `j` heads after processing current coins |
| **Base** | `dp[0] = 1.0` |
| **Transition** | `dp[j] = dp[j]*(1-p) + dp[j-1]*p` (tails or heads) |
| **Answer** | `dp[target]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn probability_of_heads(prob: Vec<f64>, target: i32) -> f64 {
        let target = target as usize;
        let n = prob.len();
        let mut dp = vec![0.0f64; target + 1];
        dp[0] = 1.0;
        for i in 0..n {
            // Iterate downward to avoid using updated values within the same coin
            for j in (0..=target.min(i + 1)).rev() {
                dp[j] = dp[j] * (1.0 - prob[i])
                    + if j > 0 { dp[j - 1] * prob[i] } else { 0.0 };
            }
        }
        dp[target]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn close(a: f64, b: f64) -> bool { (a - b).abs() < 1e-5 }
    #[test]
    fn test_toss_coins() {
        assert!(close(Solution::probability_of_heads(vec![0.4], 1), 0.4));
        assert!(close(Solution::probability_of_heads(vec![0.5, 0.5, 0.5, 0.5, 0.5], 0), 0.03125));
        assert!(close(
            Solution::probability_of_heads(vec![0.0,0.0,0.0,0.0,0.0,0.0], 0),
            1.0
        ));
    }
}

fn main() {}
```

**Time:** O(n × target) | **Space:** O(target)

**Rust notes:** The downward `j` iteration is the 0/1 knapsack trick on a probability
table — same structural pattern as `Vec<bool>` subset sum, just with `f64` values.

---

## LC #808 — Soup Servings

**Difficulty:** Medium

### Problem Statement

Two soups A and B, each with `n` ml. Four equally likely operations serve
(A=100,B=0), (A=75,B=25), (A=50,B=50), (A=25,B=75) ml per step. Find the
probability that A runs out first plus half the probability both run out simultaneously.

### DP Design

For large `n` the probability converges to 1.0 (A is drained faster). Short-circuit
at `n >= 4800` to return `1.0` immediately.

Scale by 25 to work with integer indices: `n = ceil(n/25)`, table size ≤ 192×192.

| | Value |
|-|-------|
| **State** | `dp[a][b]` = probability of reaching state `(a, b)` ml remaining |
| **Base** | `dp[0][0] += 0.5`, `dp[0][b>0] = 1.0` (A empty first) |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn soup_servings(n: i32) -> f64 {
        // For large n, answer converges to 1.0 within 1e-5 tolerance
        if n >= 4800 { return 1.0; }
        // Scale: each unit = 25 ml; work with integer indices
        let m = ((n + 24) / 25) as usize;
        // memo[a][b] = P(A runs out before B) + 0.5*P(both run out simultaneously)
        let mut memo = vec![vec![-1.0f64; m + 1]; m + 1];
        Self::go(m, m, &mut memo)
    }

    fn go(a: usize, b: usize, memo: &mut Vec<Vec<f64>>) -> f64 {
        if a == 0 && b == 0 { return 0.5; }  // both empty simultaneously
        if a == 0 { return 1.0; }             // A empty first
        if b == 0 { return 0.0; }             // B empty first (bad for us)
        if memo[a][b] >= 0.0 { return memo[a][b]; }
        // Four operations, each with prob 0.25; amounts in 25-ml units
        let ops: [(usize, usize); 4] = [(4,0),(3,1),(2,2),(1,3)];
        let val = ops.iter().map(|&(da, db)| {
            Self::go(a.saturating_sub(da), b.saturating_sub(db), memo)
        }).sum::<f64>() * 0.25;
        memo[a][b] = val;
        val
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn close(a: f64, b: f64) -> bool { (a - b).abs() < 1e-5 }
    #[test]
    fn test_soup() {
        assert!(close(Solution::soup_servings(50), 0.625));
        assert!(close(Solution::soup_servings(100), 0.71875));
        assert!(close(Solution::soup_servings(10000), 1.0));
    }
}

fn main() {}
```

**Time:** O((n/25)²) | **Space:** O((n/25)²)

**Rust notes:** `saturating_sub` prevents underflow when the subtraction would go
negative — essential here since `a` and `b` are `usize`. The `n >= 4800` early return
is not a micro-optimization; without it the recursion explores a huge table for large
inputs and the answer is indistinguishable from 1.0 anyway.

---

## Section 9: DP with Divide & Conquer Optimization

> **When it applies:** The DP recurrence `dp[k][i] = min over j<i of (dp[k-1][j] + cost(j,i))`
> is optimizable when `cost` satisfies the **quadrangle inequality** (optimal split
> point is monotone in `i`). This reduces O(n³) → O(n² log n) or O(n²).
>
> **Template:**
> ```
> fn dc(dp: &mut Vec<f64>, prev: &[f64], cost: &dyn Fn(usize,usize)->f64,
>        l: usize, r: usize, lo: usize, hi: usize) {
>     if l > r { return; }
>     let mid = (l + r) / 2;
>     let mut best_k = lo;
>     for k in lo..=hi.min(mid) {
>         let v = prev[k] + cost(k, mid);
>         if v < dp[mid] { dp[mid] = v; best_k = k; }
>     }
>     dc(dp, prev, cost, l, mid.wrapping_sub(1), lo, best_k);
>     dc(dp, prev, cost, mid + 1, r, best_k, hi);
> }
> ```

---

## LC #1278 — Palindrome Partitioning III

**Difficulty:** Hard

### Problem Statement

Partition string `s` into exactly `k` substrings, each of which can be made a
palindrome by changing the minimum number of characters. Minimize total changes.

### DP Design

Precompute `cost[i][j]` = minimum changes to make `s[i..=j]` a palindrome.
Then apply D&C-optimized DP.

| | Value |
|-|-------|
| **State** | `dp[p][i]` = min cost to partition `s[0..i]` into `p` parts |
| **Transition** | `dp[p][i] = min over j of dp[p-1][j] + cost[j][i-1]` |
| **Opt. split** | monotone → D&C optimization applies |
| **Answer** | `dp[k][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn palindrome_partition(s: String, k: i32) -> i32 {
        let b = s.as_bytes();
        let n = b.len();
        let k = k as usize;
        // cost[i][j]: min changes to palindromize s[i..=j]
        let mut cost = vec![vec![0i32; n]; n];
        for len in 2..=n {
            for i in 0..=(n - len) {
                let j = i + len - 1;
                cost[i][j] = cost[i+1][j-1] + if b[i] != b[j] { 1 } else { 0 };
            }
        }
        const INF: i32 = i32::MAX / 2;
        // dp[p][i]: min cost, first i chars, p partitions (1-indexed parts)
        let mut dp = vec![vec![INF; n + 1]; k + 1];
        dp[0][0] = 0;
        for p in 1..=k {
            // D&C optimization over split points
            let prev = dp[p-1].clone();
            let cur = &mut dp[p];
            Self::dc(&cost, &prev, cur, 1, n, 0, n - 1);
        }
        dp[k][n]
    }

    fn dc(cost: &[Vec<i32>], prev: &[i32], cur: &mut [i32],
          l: usize, r: usize, lo: usize, hi: usize) {
        if l > r { return; }
        let mid = (l + r) / 2;
        let mut best_k = lo;
        for j in lo..=hi.min(mid - 1) {
            if prev[j] == i32::MAX / 2 { continue; }
            let val = prev[j] + cost[j][mid - 1];
            if val < cur[mid] {
                cur[mid] = val;
                best_k = j;
            }
        }
        if mid > 0 {
            Self::dc(cost, prev, cur, l, mid - 1, lo, best_k);
        }
        Self::dc(cost, prev, cur, mid + 1, r, best_k, hi);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_palindrome_partition() {
        assert_eq!(Solution::palindrome_partition("abc".into(), 2), 1);
        assert_eq!(Solution::palindrome_partition("aabbc".into(), 3), 0);
        assert_eq!(Solution::palindrome_partition("leetcode".into(), 8), 0);
    }
}

fn main() {}
```

**Time:** O(n² + k·n log n) with D&C opt | **Space:** O(n² + k·n)

**Rust notes:** The D&C helper borrows `prev` immutably and `cur` mutably — Rust's
borrow checker enforces this split naturally via the layer-by-layer `dp[p-1].clone()`
pattern. Passing slices rather than indices keeps the signature tight.

---

## LC #1335 — Minimum Difficulty of a Job Schedule

**Difficulty:** Hard

### Problem Statement

Schedule `n` jobs in `d` days. Jobs must be done in order; each day at least one job.
Day difficulty = maximum job difficulty in that day. Minimize total difficulty across
all days.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[day][i]` = min difficulty to schedule first `i` jobs in `day` days |
| **Transition** | `dp[d][i] = min over j<i of dp[d-1][j] + max(job[j..i])` |
| **Constraint** | `n >= d`, else return `-1` |
| **Answer** | `dp[d][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn min_difficulty(job_difficulty: Vec<i32>, d: i32) -> i32 {
        let n = job_difficulty.len();
        let d = d as usize;
        if n < d { return -1; }
        const INF: i32 = i32::MAX / 2;
        // Precompute range max: range_max[i][j] = max of job_difficulty[i..=j]
        let mut range_max = vec![vec![0i32; n]; n];
        for i in 0..n {
            range_max[i][i] = job_difficulty[i];
            for j in (i+1)..n {
                range_max[i][j] = range_max[i][j-1].max(job_difficulty[j]);
            }
        }
        let mut dp = vec![vec![INF; n + 1]; d + 1];
        dp[0][0] = 0;
        for day in 1..=d {
            let prev = dp[day-1].clone();
            for i in day..=n {
                for j in (day-1)..i {
                    if prev[j] == INF { continue; }
                    let candidate = prev[j] + range_max[j][i-1];
                    dp[day][i] = dp[day][i].min(candidate);
                }
            }
        }
        if dp[d][n] == INF { -1 } else { dp[d][n] }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_job_schedule() {
        assert_eq!(Solution::min_difficulty(vec![6,5,4,3,2,1], 2), 7);
        assert_eq!(Solution::min_difficulty(vec![9,9,9], 4), -1);
        assert_eq!(Solution::min_difficulty(vec![1,1,1], 3), 3);
        assert_eq!(Solution::min_difficulty(vec![7,1,7,1,7,1], 3), 15);
    }
}

fn main() {}
```

**Time:** O(d × n²) | **Space:** O(d × n + n²)

**Rust notes:** Precomputing `range_max[i][j]` avoids recomputing the sliding maximum
in the DP inner loop, keeping each transition O(1). The monotone-split property holds,
enabling D&C optimization — left as an extension for the reader.

---

## LC #410 — Split Array Largest Sum (DP + D&C Alternative)

**Difficulty:** Hard *(Binary search version in LC-10; this shows the DP + D&C approach)*

### Problem Statement

Split `nums` into exactly `k` non-empty subarrays. Minimize the maximum subarray sum.

### DP Design with D&C Optimization

The transition `dp[p][i] = min over j<i of max(dp[p-1][j], prefix[i]-prefix[j])`
has a monotone optimal split — the D&C approach makes this O(n² log n).

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn split_array(nums: Vec<i32>, k: i32) -> i32 {
        let n = nums.len();
        let k = k as usize;
        // Prefix sums (i64 to avoid overflow with large values)
        let mut prefix = vec![0i64; n + 1];
        for i in 0..n {
            prefix[i + 1] = prefix[i] + nums[i] as i64;
        }
        // segment_max(j, i) = max sum of subarray nums[j..i]
        let seg_max = |j: usize, i: usize| -> i64 { prefix[i] - prefix[j] };
        const INF: i64 = i64::MAX / 2;
        let mut dp = vec![vec![INF; n + 1]; k + 1];
        dp[0][0] = 0;
        for p in 1..=k {
            let prev = dp[p-1].clone();
            let cur = &mut dp[p];
            Self::dc_split(&prev, cur, &seg_max, 1, n, 0, n - 1);
        }
        dp[k][n] as i32
    }

    fn dc_split(
        prev: &[i64], cur: &mut [i64],
        cost: &dyn Fn(usize, usize) -> i64,
        l: usize, r: usize, lo: usize, hi: usize,
    ) {
        if l > r { return; }
        let mid = (l + r) / 2;
        let mut best_k = lo;
        for j in lo..=hi.min(mid - 1) {
            if prev[j] >= i64::MAX / 2 { continue; }
            // Objective: minimize max(prev[j], cost(j, mid))
            let val = prev[j].max(cost(j, mid));
            if val < cur[mid] {
                cur[mid] = val;
                best_k = j;
            }
        }
        if mid > 0 {
            Self::dc_split(prev, cur, cost, l, mid - 1, lo, best_k);
        }
        Self::dc_split(prev, cur, cost, mid + 1, r, best_k, hi);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_split_array() {
        assert_eq!(Solution::split_array(vec![7,2,5,10,8], 2), 18);
        assert_eq!(Solution::split_array(vec![1,2,3,4,5], 2), 9);
        assert_eq!(Solution::split_array(vec![1,4,4], 3), 4);
    }
}

fn main() {}
```

**Time:** O(k × n log n) with D&C | **Space:** O(k × n)

**Rust notes:** The D&C recursion passes closures via `&dyn Fn(...)` — the dynamic
dispatch cost is negligible versus the algorithmic gain. Compare with the O(k × n log n)
binary-search approach in LC-10: both are asymptotically equivalent but the DP+D&C
form generalizes to problems where binary search on the answer is not applicable.

---

## LC #813 — Largest Sum of Averages

**Difficulty:** Medium

### Problem Statement

Partition array `nums` into at most `k` groups (contiguous). Maximize the sum of
averages of each group.

### DP Design

| | Value |
|-|-------|
| **State** | `dp[p][i]` = max sum of averages, first `i` elements in `p` groups |
| **Transition** | `dp[p][i] = max over j<i of dp[p-1][j] + avg(nums[j..i])` |
| **Answer** | `dp[k][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn largest_sum_of_averages(nums: Vec<i32>, k: i32) -> f64 {
        let n = nums.len();
        let k = k as usize;
        let mut prefix = vec![0.0f64; n + 1];
        for i in 0..n {
            prefix[i + 1] = prefix[i] + nums[i] as f64;
        }
        let avg = |l: usize, r: usize| -> f64 {
            (prefix[r] - prefix[l]) / (r - l) as f64
        };
        // dp[i] = best sum of averages for nums[0..i] with current # groups
        let mut dp: Vec<f64> = (0..=n).map(|i| if i == 0 { 0.0 } else { avg(0, i) }).collect();
        for _ in 1..k {
            let prev = dp.clone();
            for i in 1..=n {
                dp[i] = (0..i).map(|j| prev[j] + avg(j, i))
                    .fold(f64::NEG_INFINITY, f64::max);
            }
        }
        dp[n]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn close(a: f64, b: f64) -> bool { (a - b).abs() < 1e-5 }
    #[test]
    fn test_largest_avg() {
        assert!(close(Solution::largest_sum_of_averages(vec![9,1,2,3,9], 3), 20.0));
        assert!(close(Solution::largest_sum_of_averages(vec![1,2,3,4,5,6,7], 4), 20.5));
    }
}

fn main() {}
```

**Time:** O(k × n²) | **Space:** O(n)

**Rust notes:** `(0..i).map(...).fold(f64::NEG_INFINITY, f64::max)` is idiomatic
for a max-fold over an iterator. Using `f64::max` as the fold function (not a closure)
is a small Rust nicety. The 1-D rolling array avoids allocating a full `k×n` table.

---

## Section 10: Advanced Knapsack Variants

---

## LC #879 — Profitable Schemes

**Difficulty:** Hard

### Problem Statement

`n` gang members, `minProfit` target. Each crime requires `group[i]` members and
yields `profit[i]`. Count schemes where total members ≤ `n` and profit ≥ `minProfit`.
Return modulo `10^9 + 7`.

### DP Design

2-D knapsack: one dimension for members used, one for profit achieved (capped at
`minProfit` to avoid unbounded profit axis).

| | Value |
|-|-------|
| **State** | `dp[g][p]` = number of schemes using exactly `g` members and at least `p` profit |
| **Base** | `dp[0][0] = 1` |
| **Transition** | for each crime `(gi, pi)`: iterate `g` down from `n`, `p` down from `minProfit` |
| **Answer** | `sum(dp[g][minProfit] for g in 0..=n)` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn profitable_schemes(n: i32, min_profit: i32, group: Vec<i32>, profit: Vec<i32>) -> i32 {
        const MOD: u64 = 1_000_000_007;
        let (n, mp) = (n as usize, min_profit as usize);
        // dp[g][p] = # schemes using g members, profit capped at mp
        let mut dp = vec![vec![0u64; mp + 1]; n + 1];
        dp[0][0] = 1;
        for i in 0..group.len() {
            let (gi, pi) = (group[i] as usize, profit[i] as usize);
            // Reverse iteration: classic 0/1 knapsack
            for g in (0..=n).rev() {
                if g < gi { continue; }
                for p in (0..=mp).rev() {
                    let new_p = (p + pi).min(mp);  // cap profit at minProfit
                    dp[g][new_p] = (dp[g][new_p] + dp[g - gi][p]) % MOD;
                }
            }
        }
        dp.iter().map(|row| row[mp]).fold(0u64, |a, b| (a + b) % MOD) as i32
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_profitable() {
        assert_eq!(Solution::profitable_schemes(5, 3, vec![2,2], vec![2,3]), 2);
        assert_eq!(Solution::profitable_schemes(10, 5, vec![2,3,5], vec![6,7,8]), 7);
    }
}

fn main() {}
```

**Time:** O(K × n × minProfit) | **Space:** O(n × minProfit) where K = crimes count

**Rust notes:** Capping `new_p = (p + pi).min(mp)` collapses all "surplus profit"
states into the `mp` bucket — this is the key trick that bounds the profit dimension.

---

## LC #956 — Tallest Billboard

**Difficulty:** Hard

### Problem Statement

Given rods of various lengths, partition them into two groups (possibly skipping some)
such that both groups have equal total length. Maximize that total length.

### DP Design

HashMap-on-difference: `dp[diff]` = maximum sum of the *taller* side when the
difference between the two sides is `diff`.

| | Value |
|-|-------|
| **State** | `dp[d]` = max height of taller leg when `taller - shorter = d` |
| **Transition** | add rod to taller, shorter, or skip |
| **Answer** | `dp[0]` (both legs equal) |

### Rust Solution

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn tallest_billboard(rods: Vec<i32>) -> i32 {
        // dp[diff] = max height of the taller side given (taller - shorter == diff)
        let mut dp: HashMap<i32, i32> = HashMap::new();
        dp.insert(0, 0);
        for &r in &rods {
            let snapshot: Vec<(i32,i32)> = dp.iter().map(|(&k,&v)| (k,v)).collect();
            for (diff, tall) in snapshot {
                // Option 1: add rod to taller side
                let e1 = dp.entry(diff + r).or_insert(0);
                *e1 = (*e1).max(tall + r);
                // Option 2: add rod to shorter side
                let new_diff = (diff - r).abs();
                let new_tall = if diff >= r { tall } else { tall + r - diff };
                let e2 = dp.entry(new_diff).or_insert(0);
                *e2 = (*e2).max(new_tall);
                // Option 3: skip — dp[diff] already holds `tall`
            }
        }
        dp[&0]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_billboard() {
        assert_eq!(Solution::tallest_billboard(vec![1,2,3,6]), 6);
        assert_eq!(Solution::tallest_billboard(vec![1,2,3,4,5,6]), 10);
        assert_eq!(Solution::tallest_billboard(vec![1,2]), 0);
    }
}

fn main() {}
```

**Time:** O(n × sum) | **Space:** O(sum)

**Rust notes:** `snapshot` collects a copy of the map before iterating to avoid
mutating while reading — Rust's borrow checker requires this explicitly (no silent
ConcurrentModificationException; it simply won't compile otherwise).

---

## LC #1049 — Last Stone Weight II

**Difficulty:** Medium

### Problem Statement

Smash stones pairwise; result is `|a - b|`. What is the minimum possible final
stone weight? Equivalent to: partition stones into two groups minimizing `|S1 - S2|`,
where `S1 + S2 = total`. Find the subset sum closest to `total / 2`.

### DP Design

Standard 0/1 knapsack reachability, target = `total / 2`.

| | Value |
|-|-------|
| **State** | `dp[j]` = `true` if subset sum `j` is reachable |
| **Answer** | `total - 2 * max reachable j <= total/2` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn last_stone_weight_ii(stones: Vec<i32>) -> i32 {
        let total: i32 = stones.iter().sum();
        let half = (total / 2) as usize;
        let mut dp = vec![false; half + 1];
        dp[0] = true;
        for &s in &stones {
            for j in (0..=half).rev() {
                if dp[j] {
                    let nj = j + s as usize;
                    if nj <= half { dp[nj] = true; }
                }
            }
        }
        // Find the largest reachable sum <= half
        let best = (0..=half).rev().find(|&j| dp[j]).unwrap_or(0) as i32;
        total - 2 * best
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_last_stone() {
        assert_eq!(Solution::last_stone_weight_ii(vec![2,7,4,1,8,1]), 1);
        assert_eq!(Solution::last_stone_weight_ii(vec![31,26,33,21,40]), 5);
        assert_eq!(Solution::last_stone_weight_ii(vec![1,1]), 0);
    }
}

fn main() {}
```

**Time:** O(n × total) | **Space:** O(total)

**Rust notes:** `.rev().find(|&j| dp[j])` is idiomatic for "largest true index" —
a clean alternative to a backwards `for` loop with a manual `break`.

---

## LC #474 — Ones and Zeroes

**Difficulty:** Medium

### Problem Statement

Given an array of binary strings `strs`, find the largest subset where the total
number of `'0'`s ≤ `m` and total `'1'`s ≤ `n`.

### DP Design

2-D 0/1 knapsack: dimensions are `(zeros_budget, ones_budget)`.

| | Value |
|-|-------|
| **State** | `dp[z][o]` = max strings using ≤ `z` zeros, ≤ `o` ones |
| **Transition** | iterate `z` and `o` downward; `dp[z][o] = max(dp[z][o], 1 + dp[z-cnt0][o-cnt1])` |
| **Answer** | `dp[m][n]` |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn find_max_form(strs: Vec<String>, m: i32, n: i32) -> i32 {
        let (m, n) = (m as usize, n as usize);
        let mut dp = vec![vec![0i32; n + 1]; m + 1];
        for s in &strs {
            let zeros = s.bytes().filter(|&b| b == b'0').count();
            let ones = s.len() - zeros;
            for z in (zeros..=m).rev() {
                for o in (ones..=n).rev() {
                    dp[z][o] = dp[z][o].max(1 + dp[z - zeros][o - ones]);
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
    fn test_ones_zeroes() {
        assert_eq!(Solution::find_max_form(
            vec!["10".into(),"0001".into(),"111001".into(),"1".into(),"0".into()], 5, 3), 4);
        assert_eq!(Solution::find_max_form(
            vec!["10".into(),"0".into(),"1".into()], 1, 1), 2);
    }
}

fn main() {}
```

**Time:** O(|strs| × m × n) | **Space:** O(m × n)

**Rust notes:** `s.bytes().filter(|&b| b == b'0').count()` counts zeros without
allocating; `s.len() - zeros` gives ones since the string is binary.

---

## LC #1066 — Campus Bikes II *(Premium)*

**Difficulty:** Hard

### Problem Statement

Assign `n` workers to `n` out of `m` bikes (m ≥ n), one bike per worker, minimizing
total Manhattan distance. Workers assigned in order 0..n-1; `mask` tracks which bikes
are taken.

### DP Design

Bitmask DP over the set of bikes already assigned.

| | Value |
|-|-------|
| **State** | `dp[mask]` = min total distance when the set of bikes in `mask` are assigned |
| **Worker index** | `mask.count_ones()` = number of bikes assigned = index of next worker |
| **Transition** | `dp[mask \| (1<<b)] = min(dp[mask] + dist(worker, b))` for each unset bit `b` |
| **Answer** | `min(dp[mask])` for all masks with exactly `n` bits set |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn assign_bikes(workers: Vec<Vec<i32>>, bikes: Vec<Vec<i32>>) -> i32 {
        let (n, m) = (workers.len(), bikes.len());
        let total = 1usize << m;
        const INF: i32 = i32::MAX / 2;
        let mut dp = vec![INF; total];
        dp[0] = 0;
        let dist = |w: usize, b: usize| -> i32 {
            (workers[w][0] - bikes[b][0]).abs() + (workers[w][1] - bikes[b][1]).abs()
        };
        let mut ans = INF;
        for mask in 0..total {
            if dp[mask] == INF { continue; }
            let worker = mask.count_ones() as usize;
            if worker == n {
                ans = ans.min(dp[mask]);
                continue;
            }
            for b in 0..m {
                if mask & (1 << b) == 0 {
                    let next = mask | (1 << b);
                    dp[next] = dp[next].min(dp[mask] + dist(worker, b));
                }
            }
        }
        ans
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_campus_bikes() {
        assert_eq!(Solution::assign_bikes(
            vec![vec![0,0],vec![2,1]], vec![vec![1,2],vec![3,3]]), 6);
        assert_eq!(Solution::assign_bikes(
            vec![vec![0,0],vec![1,1],vec![2,0]],
            vec![vec![1,0],vec![2,2],vec![2,1]]), 4);
    }
}

fn main() {}
```

**Time:** O(2^m × m) | **Space:** O(2^m)

**Rust notes:** `mask.count_ones()` (a CPU popcount instruction) gives the worker
index directly — the mask encodes both the set of bikes taken and the number of
workers assigned. This avoids a separate "current worker" dimension.

---

## LC #1981 — Minimize the Difference Between Target and Chosen Elements

**Difficulty:** Hard

### Problem Statement

Given an `m×n` matrix, choose exactly one element from each row to minimize
`|chosen_sum - target|`.

### DP Design with Bitset Optimization

Represent reachable sums as a bitset (`Vec<u64>`) and use bit-shift + OR to
update. Each row transitions: `reachable |= (reachable << val)` for each value
in the row.

| | Value |
|-|-------|
| **State** | `bits[k >> 6] & (1 << (k & 63))` = whether sum `k` is reachable |
| **Transition** | for each element `v` in row: `new_bits |= (bits << v)` |
| **Answer** | scan from `target` outward to find closest reachable sum |

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn minimize_the_difference(mat: Vec<Vec<i32>>, target: i32) -> i32 {
        let target = target as usize;
        let m = mat.len();
        let n = mat[0].len();
        // Max possible sum: pick largest in each row
        let max_sum: usize = mat.iter()
            .map(|row| *row.iter().max().unwrap() as usize)
            .sum();
        // We only care about sums up to max(target, max_sum)
        let cap = max_sum + 1;
        let words = (cap + 63) / 64;
        // Bitset as Vec<u64>: bit k is set if sum k is reachable
        let mut bits = vec![0u64; words];
        bits[0] = 1;  // sum 0 is reachable before picking any row
        for row in &mat {
            let mut next = vec![0u64; words];
            for &val in row {
                let v = val as usize;
                // Shift bits left by v positions and OR into next
                let word_shift = v / 64;
                let bit_shift = v % 64;
                for w in 0..words {
                    let src_w = if w >= word_shift { w - word_shift } else { continue };
                    next[w] |= bits[src_w] << bit_shift;
                    if bit_shift > 0 && src_w > 0 {
                        next[w] |= bits[src_w - 1] >> (64 - bit_shift);
                    }
                }
            }
            bits = next;
        }
        // Scan ascending: track best diff seen so far; stop at first sum >= target
        // (sums beyond target only increase the diff, so first hit is optimal above)
        let mut best = i32::MAX;
        for k in 0..cap {
            if bits[k / 64] & (1u64 << (k % 64)) != 0 {
                let diff = (k as i32 - target as i32).abs();
                if diff < best { best = diff; }
                if k >= target { break; }
            }
        }
        best
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_minimize_diff() {
        assert_eq!(Solution::minimize_the_difference(
            vec![vec![1,2,3],vec![4,5,6],vec![7,8,9]], 13), 0);
        assert_eq!(Solution::minimize_the_difference(
            vec![vec![1],vec![2],vec![3]], 100), 94);
        assert_eq!(Solution::minimize_the_difference(
            vec![vec![1,2,9,8,7]], 6), 1);
    }
}

fn main() {}
```

**Time:** O(m × n × max_sum / 64) | **Space:** O(max_sum / 64)

**Rust notes:** The bitset is `Vec<u64>` — 64 reachability bits per word. The shift
operation crosses word boundaries with the `bits[src_w - 1] >> (64 - bit_shift)`
carry. This is the "bitset DP" technique that gives a 64× speedup over `HashSet<i32>`
or `Vec<bool>` for dense reachability problems.

---

## 📝 Part 3 Review Notes

### Summary

This chapter covers 22 advanced DP problems across four specialized families. Each
family introduces a distinct technique that extends beyond the standard 1-D/2-D DP
covered in LC-08.

### Key Techniques per Section

| Section | Core Technique | Canonical Problem |
|---------|---------------|------------------|
| String DP | LCS/LCS-substring variants; `*` semantics differ by problem | LC #10 vs #44 |
| Probability DP | `f64` rolling DP; sliding-window sums; `saturating_sub` | LC #837, #808 |
| D&C Optimization | Monotone split point; recurse on `[l,mid-1]` and `[mid+1,r]` | LC #1278 |
| Advanced Knapsack | 2-D knapsack; bitmask DP; `Vec<u64>` bitset | LC #879, #1066, #1981 |

### Fact-Check Table

| Issue | Severity | Resolution |
|-------|----------|-----------|
| LC #10 `*` and LC #44 `*` have different semantics — copy-paste between them is a correctness bug | High | Documented prominently; base-case loop differs (`j-2` vs `j-1`) |
| LC #808 answer converges to 1.0 for large `n` — without `n >= 4800` early return, memo table explodes | High | `if n >= 4800 { return 1.0; }` guard applied; threshold noted explicitly |
| `f64` DP tests must not use `assert_eq!` — floating-point equality is unreliable | High | All probability tests use `(a-b).abs() < 1e-5` |
| LC #837 naive O(n × maxPts) DP TLEs on LeetCode — sliding-window sum reduces to O(n) | Medium | Sliding-window `window_sum` maintained in O(1) per step |
| LC #956 the accepted approach is HashMap-on-difference DP, not literal meet-in-middle | Medium | Implemented with `HashMap<i32,i32>`; meet-in-middle noted as conceptual frame |
| `usize` subtraction panics on underflow in debug mode — `saturating_sub` required for LC #808 ops | High | `a.saturating_sub(da)` used throughout soup DP |
| D&C optimization requires monotone optimal split (quadrangle inequality) — applying it to arbitrary cost functions is incorrect | High | Template shown with LC #1278 where quadrangle inequality holds; LC #1335 noted as candidate |
| LC #1981 bitset shift must handle cross-word carry with `bits[src_w-1] >> (64 - bit_shift)` | High | Carry term present; guarded by `if bit_shift > 0 && src_w > 0` |
| LC #1066 bitmask DP worker index = `mask.count_ones()` — only valid when iterating masks in ascending order | Medium | `for mask in 0..total` guarantees ascending order; count_ones correct |
| LC #879 profit dimension must be capped at `minProfit` — `(p + pi).min(mp)` collapses surplus profit states | High | `.min(mp)` cap applied in transition |
| LC #718 resets to `0` on mismatch (common subARRAY); LC #1035 takes max of two directions (LCS) — adjacent problems with opposite table update rules | Medium | Distinction called out explicitly in Section 7 header and per-problem notes |
| LC #1092 SCS reconstruction produces one valid answer; tests verify the subsequence property, not exact string equality | Medium | `is_subseq` helper in test validates structural correctness |
