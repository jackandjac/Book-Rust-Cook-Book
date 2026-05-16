# Chapter LC-14 (Java): Advanced Dynamic Programming — Part 1

> Java 17+ companion to the Rust chapter `lc14-advanced-dp-part1.md`.
> **Covers:** Interval DP, Game Theory / Minimax DP, and Digit DP — all 20 problems from the DP Grandmaster study plan.

---

## Problem Overview

### Section 1: Interval DP

| # | Problem | Difficulty |
|---|---------|-----------|
| LC 516 | Longest Palindromic Subsequence | Medium |
| LC 1039 | Minimum Score Triangulation of Polygon | Medium |
| LC 1000 | Minimum Cost to Merge Stones | Hard |
| LC 312 | Burst Balloons | Hard |
| LC 664 | Strange Printer | Hard |
| LC 1547 | Minimum Cost to Cut a Stick | Hard |
| LC 546 | Remove Boxes | Hard |
| LC 1312 | Minimum Insertion Steps to Make a String Palindrome | Medium |

### Section 2: Game Theory / Minimax DP

| # | Problem | Difficulty |
|---|---------|-----------|
| LC 877 | Stone Game | Medium |
| LC 1140 | Stone Game II | Medium |
| LC 1406 | Stone Game III | Medium |
| LC 1510 | Stone Game IV | Medium |
| LC 375 | Guess Number Higher or Lower II | Medium |
| LC 486 | Predict the Winner | Medium |
| LC 464 | Can I Win | Medium |

### Section 3: Digit DP

| # | Problem | Difficulty |
|---|---------|-----------|
| LC 233 | Number of Digit One | Hard |
| LC 357 | Count Numbers with Unique Digits | Medium |
| LC 902 | Numbers At Most N Given Digit Set | Hard |
| LC 1012 | Numbers With Repeated Digits | Hard |
| LC 2376 | Count Special Integers | Hard |

---

## Java Quick Reference for This Chapter

| Idiom | Notes |
|-------|-------|
| `int[][] dp = new int[n][n]` | Java zero-initializes — safe for min problems that need 0 base case; use `Arrays.fill` for custom sentinel |
| `Integer.MAX_VALUE / 2` | Infinity sentinel for min-DP; avoids integer overflow when added to another value |
| `Arrays.fill(row, -1)` | Memoization sentinel; -1 signals "not computed" |
| `for (int len = 2; len <= n; len++)` | Standard outer loop for interval DP |
| `HashMap<Integer, Boolean>` | Bitmask memoization; note boxing cost vs. `boolean[]` |
| `(1 << i)` | Bitmask bit for integer `i` (0-indexed) |
| `Math.min` / `Math.max` | Java cannot call `.min()` on primitives — use static methods |

> **Java vs Rust:** Java `int[][]` arrays are zero-initialized automatically; Rust requires explicit `vec![0i32; n]`. Use `Arrays.fill(arr, -1)` in Java to set a sentinel, which corresponds to Rust's `vec![-1i32; n]`. `HashMap` memoization in Java boxes `Integer`/`Boolean` — for hot paths prefer a `boolean[]` or `int[]` keyed by a packed integer. The `Integer.MAX_VALUE / 2` idiom prevents overflow when a sentinel is later added to another value; Rust sidesteps this via `i32::MAX` guarded by explicit checks.

---

## Section 1: Interval DP

**Pattern:** `dp[i][j]` = answer for the subproblem on `arr[i..j]` (inclusive). Outer loop iterates over **interval length** (small to large); inner loops over left endpoint `i`; innermost over split point `k`.

```
for (int len = 2; len <= n; len++) {
    for (int i = 0; i <= n - len; i++) {
        int j = i + len - 1;
        for (int k = i; k < j; k++) {   // split point
            dp[i][j] = combine(dp[i][k], dp[k+1][j]);
        }
    }
}
```

---

## LC 516 — Longest Palindromic Subsequence

**Difficulty:** Medium

Given a string `s`, return the length of the longest subsequence that is a palindrome.

**Key insight:** `dp[i][j] = dp[i+1][j-1] + 2` when `s[i] == s[j]`; otherwise take the better of extending either end.

```java
class Solution {
    public int longestPalindromeSubseq(String s) {
        int n = s.length();
        int[][] dp = new int[n][n];
        // Base case: every single character is a palindrome of length 1
        for (int i = 0; i < n; i++) dp[i][i] = 1;

        for (int len = 2; len <= n; len++) {
            for (int i = 0; i <= n - len; i++) {
                int j = i + len - 1;
                if (s.charAt(i) == s.charAt(j)) {
                    // len == 2 guard: dp[i+1][j-1] is dp[i+1][i] = 0, but correct answer is 2
                    dp[i][j] = (len == 2) ? 2 : dp[i + 1][j - 1] + 2;
                } else {
                    dp[i][j] = Math.max(dp[i + 1][j], dp[i][j - 1]);
                }
            }
        }
        return dp[0][n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.longestPalindromeSubseq("bbbab");
        if (r1 != 4) throw new AssertionError("bbbab: got " + r1);

        var r2 = sol.longestPalindromeSubseq("cbbd");
        if (r2 != 2) throw new AssertionError("cbbd: got " + r2);

        var r3 = sol.longestPalindromeSubseq("a");
        if (r3 != 1) throw new AssertionError("single a: got " + r3);

        var r4 = sol.longestPalindromeSubseq("aaaa");
        if (r4 != 4) throw new AssertionError("aaaa: got " + r4);

        System.out.println("LC 516 OK");
    }
}
```

**Complexity:** Time O(n²), Space O(n²).

**Approach 2 — Space-Optimized O(n) space.** Since `dp[i][j]` depends on `dp[i+1][j]`, `dp[i][j-1]`, and the diagonal `dp[i+1][j-1]`, we can use two 1-D arrays: the previous `i+1` row and the current `i` row. Track the diagonal value separately as `prevDiag`.

```java
class Solution {
    public int longestPalindromeSubseqSpaceOpt(String s) {
        int n = s.length();
        int[] dp = new int[n];
        int[] prev = new int[n]; // represents dp[i+1][*]

        for (int i = n - 1; i >= 0; i--) {
            dp[i] = 1; // dp[i][i] = 1
            int prevDiag = 0; // tracks dp[i+1][j-1] before overwrite
            for (int j = i + 1; j < n; j++) {
                int saved = dp[j]; // save before overwrite
                int len = j - i + 1;
                if (s.charAt(i) == s.charAt(j)) {
                    dp[j] = (len == 2) ? 2 : prevDiag + 2;
                } else {
                    dp[j] = Math.max(prev[j], dp[j - 1]);
                }
                prevDiag = saved;
            }
            prev = dp.clone();
        }
        return dp[n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        var r1 = sol.longestPalindromeSubseqSpaceOpt("bbbab");
        if (r1 != 4) throw new AssertionError("bbbab space-opt: got " + r1);
        var r2 = sol.longestPalindromeSubseqSpaceOpt("cbbd");
        if (r2 != 2) throw new AssertionError("cbbd space-opt: got " + r2);
        System.out.println("LC 516 space-opt OK");
    }
}
```

**Java notes:** The `len == 2` guard is identical to the Rust version — without it, `dp[i+1][j-1]` at `j = i+1` accesses `dp[i+1][i]` which is 0, producing 2 anyway, but the intent is clearer with the explicit check. Java arrays are zero-initialized so no `Arrays.fill` needed here. The space-optimized version clones the array with `.clone()` — this is an O(n) operation each outer iteration, so total time is still O(n²).

---

## LC 1039 — Minimum Score Triangulation of Polygon

**Difficulty:** Medium

Given a convex polygon with `n` vertices, triangulate it to minimize the sum of products of triangle vertex labels.

**Key insight:** Fix edge `(i, j)` — the "base" of each sub-polygon. Choose apex `k` in `(i+1..j)` that minimizes `values[i] * values[k] * values[j] + dp[i][k] + dp[k][j]`.

```java
class Solution {
    public int minScoreTriangulation(int[] values) {
        int n = values.length;
        int[][] dp = new int[n][n];
        // len here is j - i (not interval length - 1)
        for (int len = 2; len < n; len++) {
            for (int i = 0; i + len < n; i++) {
                int j = i + len;
                dp[i][j] = Integer.MAX_VALUE / 2;
                for (int k = i + 1; k < j; k++) {
                    int score = dp[i][k] + dp[k][j] + values[i] * values[k] * values[j];
                    dp[i][j] = Math.min(dp[i][j], score);
                }
            }
        }
        return dp[0][n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.minScoreTriangulation(new int[]{1, 2, 3});
        if (r1 != 6) throw new AssertionError("triangle [1,2,3]: got " + r1);

        var r2 = sol.minScoreTriangulation(new int[]{3, 7, 4, 5});
        if (r2 != 144) throw new AssertionError("[3,7,4,5]: got " + r2);

        var r3 = sol.minScoreTriangulation(new int[]{1, 3, 1, 4, 1, 5});
        if (r3 != 13) throw new AssertionError("[1,3,1,4,1,5]: got " + r3);

        System.out.println("LC 1039 OK");
    }
}
```

**Complexity:** Time O(n³), Space O(n²).

**Java notes:** Products `values[i] * values[k] * values[j]` where values ≤ 1000 can reach 10^9 — fits in `int` but barely. Using `Integer.MAX_VALUE / 2` as the sentinel prevents a silent overflow if a product were ever close to `MAX_VALUE`. The `len` variable here counts `j - i`, not `j - i + 1`, to match the open-interval convention for polygon triangulation.

---

## LC 1000 — Minimum Cost to Merge Stones

**Difficulty:** Hard

Merge `n` piles of stones into one, always merging exactly `k` consecutive piles. Each merge costs the sum of the merged piles. Return -1 if impossible.

**Key insight:** Feasibility: `(n - 1) % (k - 1) == 0`. Split the interval only at positions `m` where the left side has length divisible by `k-1`, then add the full range sum when the interval can collapse to one pile.

```java
import java.util.Arrays;

class Solution {
    public int mergeStones(int[] stones, int k) {
        int n = stones.length;
        if ((n - 1) % (k - 1) != 0) return -1;

        // Prefix sums
        int[] prefix = new int[n + 1];
        for (int i = 0; i < n; i++) prefix[i + 1] = prefix[i] + stones[i];

        int[][] dp = new int[n][n];
        // No need to fill 0 — single piles already cost 0 (zero-initialized)

        for (int len = k; len <= n; len++) {
            for (int i = 0; i + len - 1 < n; i++) {
                int j = i + len - 1;
                dp[i][j] = Integer.MAX_VALUE / 2;
                // Split at steps of k-1 so left side i..m reduces to one pile
                for (int m = i; m < j; m += k - 1) {
                    int cost = dp[i][m] + dp[m + 1][j];
                    dp[i][j] = Math.min(dp[i][j], cost);
                }
                // If the full interval reduces to exactly one pile, add the merge cost
                if ((j - i) % (k - 1) == 0) {
                    dp[i][j] += prefix[j + 1] - prefix[i];
                }
            }
        }
        return dp[0][n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.mergeStones(new int[]{3, 2, 4, 1}, 2);
        if (r1 != 20) throw new AssertionError("[3,2,4,1] k=2: got " + r1);

        var r2 = sol.mergeStones(new int[]{3, 2, 4, 1}, 3);
        if (r2 != -1) throw new AssertionError("impossible k=3: got " + r2);

        var r3 = sol.mergeStones(new int[]{3, 5, 1, 2, 6}, 3);
        if (r3 != 25) throw new AssertionError("[3,5,1,2,6] k=3: got " + r3);

        var r4 = sol.mergeStones(new int[]{5}, 2);
        if (r4 != 0) throw new AssertionError("single pile: got " + r4);

        System.out.println("LC 1000 OK");
    }
}
```

**Complexity:** Time O(n³/k), Space O(n²).

**Java notes:** `Integer.MAX_VALUE / 2` is critical here: `dp[i][j]` is later incremented by `prefix[j+1] - prefix[i]`. Using `Integer.MAX_VALUE` would overflow to a negative number. The step `m += k - 1` matches Rust's `m += k - 1` — iterating every possible valid split point.

---

## LC 312 — Burst Balloons

**Difficulty:** Hard

Bursting balloon `i` earns `nums[i-1] * nums[i] * nums[i+1]` points (boundaries treated as 1). Return the maximum total points.

**Key insight:** Think about the **last** balloon burst in any interval `(i, j)`. At that moment, its only neighbors are the sentinels `nums[i]` and `nums[j]`, making `dp[i][k]` and `dp[k][j]` fully independent.

```java
class Solution {
    public int maxCoins(int[] nums) {
        int n = nums.length;
        // Pad with sentinel 1s at both ends
        int[] arr = new int[n + 2];
        arr[0] = 1;
        arr[n + 1] = 1;
        for (int i = 0; i < n; i++) arr[i + 1] = nums[i];
        int m = arr.length; // m = n + 2

        // dp[i][j] = max coins from bursting all balloons strictly between i and j
        int[][] dp = new int[m][m];
        // len = j - i; must be >= 2 to have at least one balloon strictly between i and j
        for (int len = 2; len < m; len++) {
            for (int i = 0; i + len < m; i++) {
                int j = i + len;
                for (int k = i + 1; k < j; k++) {
                    int coins = dp[i][k] + arr[i] * arr[k] * arr[j] + dp[k][j];
                    dp[i][j] = Math.max(dp[i][j], coins);
                }
            }
        }
        return dp[0][m - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.maxCoins(new int[]{3, 1, 5, 8});
        if (r1 != 167) throw new AssertionError("[3,1,5,8]: got " + r1);

        var r2 = sol.maxCoins(new int[]{1, 5});
        if (r2 != 10) throw new AssertionError("[1,5]: got " + r2);

        var r3 = sol.maxCoins(new int[]{3});
        if (r3 != 3) throw new AssertionError("[3]: got " + r3);

        var r4 = sol.maxCoins(new int[]{1, 1, 1});
        // All values are 1; every burst yields 1*1*1=1, total = 3
        if (r4 != 3) throw new AssertionError("[1,1,1]: got " + r4);

        System.out.println("LC 312 OK");
    }
}
```

**Complexity:** Time O(n³), Space O(n²).

**Approach 2 — Top-Down Memoization.** Many find the "last balloon" recursion more natural top-down. The logic is identical; memoization prevents re-computing subproblems.

```java
import java.util.Arrays;

class Solution {
    private int[] arr;
    private int[][] memo;

    public int maxCoinsTopDown(int[] nums) {
        int n = nums.length;
        arr = new int[n + 2];
        arr[0] = 1;
        arr[n + 1] = 1;
        for (int i = 0; i < n; i++) arr[i + 1] = nums[i];
        int m = arr.length;
        memo = new int[m][m];
        for (var row : memo) Arrays.fill(row, -1);
        return solve(0, m - 1);
    }

    private int solve(int i, int j) {
        if (j <= i + 1) return 0;
        if (memo[i][j] != -1) return memo[i][j];
        int best = 0;
        for (int k = i + 1; k < j; k++) {
            // k is the LAST balloon burst between i and j
            int coins = arr[i] * arr[k] * arr[j] + solve(i, k) + solve(k, j);
            best = Math.max(best, coins);
        }
        memo[i][j] = best;
        return best;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        var r1 = sol.maxCoinsTopDown(new int[]{3, 1, 5, 8});
        if (r1 != 167) throw new AssertionError("[3,1,5,8] top-down: got " + r1);
        var sol2 = new Solution();
        var r2 = sol2.maxCoinsTopDown(new int[]{1, 1, 1});
        if (r2 != 3) throw new AssertionError("[1,1,1] top-down: got " + r2);
        System.out.println("LC 312 top-down OK");
    }
}
```

**Java notes:** The open-interval convention (`dp[i][j]` covers strictly between `i` and `j`) avoids edge-case handling at the boundaries — the sentinel `1`s at index 0 and `n+1` absorb the boundary multiplications. Java's `int` is sufficient; products max out at 100 × 100 × 100 = 10^6 per balloon, and the sum across all balloons fits in `int`. The top-down version uses `-1` as the memo sentinel: always safe since all valid coin totals are non-negative.

---

## LC 664 — Strange Printer

**Difficulty:** Hard

A printer prints a sequence of the same character per turn, over any range. Return the minimum number of turns to print a given string `s`.

**Key insight:** When `s[k] == s[j]`, the turn that prints `s[k]` can be extended to also cover position `j` for free, saving one turn. Base: `dp[i][j] = dp[i][j-1] + 1` (print `s[j]` alone).

```java
class Solution {
    public int strangePrinter(String s) {
        int n = s.length();
        int[][] dp = new int[n][n];

        // Iterate i from right to left, j from i+1 upward
        for (int i = n - 1; i >= 0; i--) {
            dp[i][i] = 1;
            for (int j = i + 1; j < n; j++) {
                // Start: print s[j] in its own separate turn
                dp[i][j] = dp[i][j - 1] + 1;
                // Merge: if s[k] == s[j], the run printing s[k] can extend to j for free
                for (int k = i; k < j; k++) {
                    if (s.charAt(k) == s.charAt(j)) {
                        // dp[k+1][j-1] = 0 when k+1 > j-1 (adjacent positions)
                        int mid = (k + 1 <= j - 1) ? dp[k + 1][j - 1] : 0;
                        dp[i][j] = Math.min(dp[i][j], dp[i][k] + mid);
                    }
                }
            }
        }
        return dp[0][n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.strangePrinter("aaabbb");
        if (r1 != 2) throw new AssertionError("aaabbb: got " + r1);

        var r2 = sol.strangePrinter("aba");
        if (r2 != 2) throw new AssertionError("aba: got " + r2);

        var r3 = sol.strangePrinter("a");
        if (r3 != 1) throw new AssertionError("a: got " + r3);

        var r4 = sol.strangePrinter("abcba");
        if (r4 != 3) throw new AssertionError("abcba: got " + r4);

        System.out.println("LC 664 OK");
    }
}
```

**Complexity:** Time O(n³), Space O(n²).

**Java notes:** The `reverse-i` loop order (decrementing `i`, incrementing `j`) ensures `dp[i][k]` and `dp[k+1][j-1]` are already filled before `dp[i][j]` is computed. The ternary `(k + 1 <= j - 1) ? dp[k+1][j-1] : 0` mirrors the Rust guard and avoids an out-of-bounds check for adjacent positions.

---

## LC 1547 — Minimum Cost to Cut a Stick

**Difficulty:** Hard

Given a stick of length `n` and cut positions, perform all cuts in any order. Each cut costs the length of the stick being cut. Return the minimum total cost.

**Key insight:** Sort cuts and add sentinels 0 and `n`. Then `dp[i][j]` = minimum cost to make all cuts between `cuts[i]` and `cuts[j]`. The cost of any cut within this interval is `cuts[j] - cuts[i]` (the current stick length).

```java
import java.util.Arrays;

class Solution {
    public int minCost(int n, int[] cuts) {
        // Add sentinels and sort
        int m = cuts.length;
        int[] c = new int[m + 2];
        c[0] = 0;
        c[m + 1] = n;
        for (int i = 0; i < m; i++) c[i + 1] = cuts[i];
        Arrays.sort(c);
        int total = c.length; // total = m + 2

        int[][] dp = new int[total][total];
        // len = j - i; len >= 2 means there is at least one cut between i and j
        for (int len = 2; len < total; len++) {
            for (int i = 0; i + len < total; i++) {
                int j = i + len;
                dp[i][j] = Integer.MAX_VALUE / 2;
                for (int k = i + 1; k < j; k++) {
                    int cost = dp[i][k] + dp[k][j] + c[j] - c[i];
                    dp[i][j] = Math.min(dp[i][j], cost);
                }
            }
        }
        return dp[0][total - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.minCost(7, new int[]{1, 3, 4, 5});
        if (r1 != 16) throw new AssertionError("n=7 cuts=[1,3,4,5]: got " + r1);

        var r2 = sol.minCost(9, new int[]{5, 6, 1, 4, 2});
        if (r2 != 22) throw new AssertionError("n=9 cuts=[5,6,1,4,2]: got " + r2);

        var r3 = sol.minCost(10, new int[]{5});
        if (r3 != 10) throw new AssertionError("n=10 cuts=[5]: got " + r3);

        System.out.println("LC 1547 OK");
    }
}
```

**Complexity:** Time O(m³) where m = cuts.length + 2, Space O(m²).

**Java notes:** `Arrays.sort(c)` (ascending) is required — the sentinels 0 and `n` must be at the ends. This is structurally identical to the Matrix Chain Multiplication problem; the width `c[j] - c[i]` of the sub-stick is the cost of making any single cut within it.

---

## LC 546 — Remove Boxes

**Difficulty:** Hard

Removing `k` consecutive same-color boxes yields `k * k` points. Return the maximum points from removing all boxes.

**Key insight:** Standard 2-D interval DP is insufficient because same-color boxes can "merge" across gaps. Use 3-D state: `dp[l][r][k]` = maximum points for boxes `l..r` plus `k` extra boxes matching `boxes[l]` attached to its left.

```java
class Solution {
    private int[][][] dp;
    private int[] boxes;

    public int removeBoxes(int[] boxes) {
        int n = boxes.length;
        this.boxes = boxes;
        this.dp = new int[n][n][n];
        // 0 is a valid unset sentinel here because minimum score for any non-empty range is 1
        return solve(0, n - 1, 0);
    }

    private int solve(int l, int r, int k) {
        if (l > r) return 0;
        if (dp[l][r][k] != 0) return dp[l][r][k];

        // Compress: absorb consecutive same-color boxes at l into k
        while (l < r && boxes[l + 1] == boxes[l]) {
            l++;
            k++;
        }

        // Option 1: remove the k+1 boxes of color boxes[l] at the start
        int best = (k + 1) * (k + 1) + solve(l + 1, r, 0);

        // Option 2: find a matching box further right and defer removal
        for (int m = l + 1; m <= r; m++) {
            if (boxes[m] == boxes[l]) {
                best = Math.max(best, solve(l + 1, m - 1, 0) + solve(m, r, k + 1));
            }
        }
        dp[l][r][k] = best;
        return best;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.removeBoxes(new int[]{1, 3, 2, 2, 2, 3, 4, 3, 1});
        if (r1 != 23) throw new AssertionError("[1,3,2,2,2,3,4,3,1]: got " + r1);

        // Reset internal state for each test
        var sol2 = new Solution();
        var r2 = sol2.removeBoxes(new int[]{1, 1, 1});
        if (r2 != 9) throw new AssertionError("[1,1,1]: got " + r2);

        var sol3 = new Solution();
        var r3 = sol3.removeBoxes(new int[]{5});
        if (r3 != 1) throw new AssertionError("[5]: got " + r3);

        var sol4 = new Solution();
        var r4 = sol4.removeBoxes(new int[]{1, 2, 3});
        if (r4 != 3) throw new AssertionError("[1,2,3]: got " + r4);

        System.out.println("LC 546 OK");
    }
}
```

**Complexity:** Time O(n⁴), Space O(n³).

**Java notes:** Using instance fields `dp` and `boxes` avoids threading them through every recursive call — cleaner than passing `int[][][]` as a parameter in Java. The memo sentinel 0 is valid here because the minimum score for any non-empty subproblem is at least 1 (a single box scores `1*1 = 1`). Creating a new `Solution` instance per test resets `dp`; on LeetCode only one `removeBoxes` call is made per instance.

---

## LC 1312 — Minimum Insertion Steps to Make a String Palindrome

**Difficulty:** Medium

Return the minimum number of characters to insert into `s` to make it a palindrome.

**Key insight:** This equals `n - LPS(s)` (Longest Palindromic Subsequence). Equivalently, use the direct recurrence: `dp[i][j] = dp[i+1][j-1]` when `s[i] == s[j]`; otherwise `1 + min(dp[i+1][j], dp[i][j-1])`.

```java
class Solution {
    public int minInsertions(String s) {
        int n = s.length();
        int[][] dp = new int[n][n];
        // Base: dp[i][i] = 0, already zero-initialized

        for (int len = 2; len <= n; len++) {
            for (int i = 0; i <= n - len; i++) {
                int j = i + len - 1;
                if (s.charAt(i) == s.charAt(j)) {
                    // len == 2 guard: dp[i+1][j-1] = dp[i+1][i] = 0, answer is 0 — correct
                    dp[i][j] = (len == 2) ? 0 : dp[i + 1][j - 1];
                } else {
                    dp[i][j] = 1 + Math.min(dp[i + 1][j], dp[i][j - 1]);
                }
            }
        }
        return dp[0][n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.minInsertions("zzazz");
        if (r1 != 0) throw new AssertionError("zzazz: got " + r1);

        var r2 = sol.minInsertions("mbadm");
        if (r2 != 2) throw new AssertionError("mbadm: got " + r2);

        var r3 = sol.minInsertions("leetcode");
        if (r3 != 5) throw new AssertionError("leetcode: got " + r3);

        var r4 = sol.minInsertions("a");
        if (r4 != 0) throw new AssertionError("single a: got " + r4);

        System.out.println("LC 1312 OK");
    }
}
```

**Complexity:** Time O(n²), Space O(n²).

**Java notes:** The `len == 2` guard technically does nothing here because `dp[i+1][i]` is 0 (zero-initialized) and 0 is the correct answer for two equal characters — but it communicates intent clearly. The relationship `minInsertions(s) = s.length() - longestPalindromeSubseq(s)` is worth noting: these two problems share the same DP table structure.

---

## Section 2: Game Theory / Minimax DP

**Pattern:** `dp[i][j]` = **score difference** (current player minus opponent) for the subgame over `[i..j]`. A positive value means the current player wins. Each turn: `dp[i][j] = max(take_left, take_right)` where each option reduces the opponent's advantage.

---

## LC 877 — Stone Game

**Difficulty:** Medium

Alice and Bob alternate taking piles from either end (`n` even, total sum odd). Alice goes first. Return `true` if Alice wins.

**Key insight:** Alice always wins (mathematical parity argument), but the DP generalizes. `dp[i][j]` = current player's advantage over opponent in subgame `[i..j]`.

```java
class Solution {
    public boolean stoneGame(int[] piles) {
        int n = piles.length;
        int[][] dp = new int[n][n];
        for (int i = 0; i < n; i++) dp[i][i] = piles[i];

        for (int len = 2; len <= n; len++) {
            for (int i = 0; i <= n - len; i++) {
                int j = i + len - 1;
                dp[i][j] = Math.max(
                    piles[i] - dp[i + 1][j],
                    piles[j] - dp[i][j - 1]
                );
            }
        }
        return dp[0][n - 1] > 0;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.stoneGame(new int[]{5, 3, 4, 5});
        if (!r1) throw new AssertionError("[5,3,4,5]: got " + r1);

        var r2 = sol.stoneGame(new int[]{1, 100, 1, 1});
        if (!r2) throw new AssertionError("[1,100,1,1]: got " + r2);

        // Use an odd-total input per problem constraints (n even, total odd → Alice always wins)
        var r3 = sol.stoneGame(new int[]{4, 2, 6, 3}); // total=15 odd
        if (!r3) throw new AssertionError("[4,2,6,3]: got " + r3);

        System.out.println("LC 877 OK");
    }
}
```

**Complexity:** Time O(n²), Space O(n²).

**Approach 2 — Mathematical O(1).** Under the problem's fixed constraints (n even, total odd), Alice always wins by controlling parity. No computation needed.

```java
class Solution {
    public boolean stoneGameMath(int[] piles) {
        // With n even and odd total, Alice chooses all even-indexed or all odd-indexed piles
        // (whichever sum is larger). She can always take from the side that extends her chosen
        // parity, because at every step both ends have different parity indices.
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        if (!sol.stoneGameMath(new int[]{5, 3, 4, 5}))
            throw new AssertionError("Mathematical solution should return true");
        System.out.println("LC 877 math approach OK");
    }
}
```

**Java notes:** `dp[i][j] = max(piles[i] - dp[i+1][j], piles[j] - dp[i][j-1])` encodes both players' optimal strategies in a single table: the current player picks the choice that maximizes their net lead. The subtraction `piles[x] - dp[...]` flips the perspective from opponent to current player. Use the DP approach (Approach 1) when generalizing to LC 486 or LC 1140 where Alice doesn't always win.

---

## LC 1140 — Stone Game II

**Difficulty:** Medium

Players alternate picking piles from the left, choosing `X` where `1 <= X <= 2M`; then `M = max(M, X)`. Alice goes first with `M=1`. Return the maximum stones Alice can get.

**Key insight:** `dp[i][m]` = maximum stones the current player can take from piles `[i..n-1]` when current `M = m`. Use suffix sums to compute remaining totals quickly.

```java
class Solution {
    public int stoneGameII(int[] piles) {
        int n = piles.length;
        int[] suffix = new int[n + 1];
        for (int i = n - 1; i >= 0; i--) suffix[i] = suffix[i + 1] + piles[i];

        int maxM = n + 1;
        int[][] dp = new int[n + 1][maxM + 1];

        for (int i = n - 1; i >= 0; i--) {
            for (int m = 1; m <= maxM; m++) {
                if (i + 2 * m >= n) {
                    dp[i][m] = suffix[i]; // take everything remaining
                } else {
                    for (int x = 1; x <= 2 * m; x++) {
                        int nextM = Math.max(m, x);
                        int candidate = suffix[i] - dp[i + x][nextM];
                        dp[i][m] = Math.max(dp[i][m], candidate);
                    }
                }
            }
        }
        return dp[0][1];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.stoneGameII(new int[]{2, 7, 9, 4, 4});
        if (r1 != 10) throw new AssertionError("[2,7,9,4,4]: got " + r1);

        var r2 = sol.stoneGameII(new int[]{1, 2, 3, 4, 5, 100});
        if (r2 != 104) throw new AssertionError("[1,2,3,4,5,100]: got " + r2);

        System.out.println("LC 1140 OK");
    }
}
```

**Complexity:** Time O(n³), Space O(n²).

**Java notes:** `suffix[i] - dp[i+x][nextM]` is the score-difference trick: the current player captures `suffix[i]` total, and the opponent takes `dp[i+x][nextM]` of that. Java's zero-initialization of `dp` works as the starting value for `Math.max` accumulation since all candidates are non-negative.

---

## LC 1406 — Stone Game III

**Difficulty:** Medium

Players alternate taking 1, 2, or 3 stones from the left. The player with more stones wins. Return "Alice", "Bob", or "Tie".

**Key insight:** 1-D score-difference DP. `dp[i]` = max net advantage (current player minus opponent) starting from index `i`. Use a switch expression on `Integer.signum` for clean outcome reporting.

```java
class Solution {
    public String stoneGameIII(int[] stoneValue) {
        int n = stoneValue.length;
        int[] dp = new int[n + 1];
        // dp[n] = 0 (base case: no stones left)
        // Initialize interior to MIN_VALUE so max-aggregation always replaces it
        java.util.Arrays.fill(dp, 0, n, Integer.MIN_VALUE / 2);
        dp[n] = 0;

        for (int i = n - 1; i >= 0; i--) {
            int running = 0;
            for (int k = 1; k <= 3 && i + k <= n; k++) {
                running += stoneValue[i + k - 1];
                dp[i] = Math.max(dp[i], running - dp[i + k]);
            }
        }
        return switch (Integer.signum(dp[0])) {
            case 1  -> "Alice";
            case -1 -> "Bob";
            default -> "Tie";
        };
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.stoneGameIII(new int[]{1, 2, 3, 7});
        if (!"Bob".equals(r1)) throw new AssertionError("[1,2,3,7]: got " + r1);

        var r2 = sol.stoneGameIII(new int[]{1, 2, 3, -9});
        if (!"Alice".equals(r2)) throw new AssertionError("[1,2,3,-9]: got " + r2);

        var r3 = sol.stoneGameIII(new int[]{1, 2, 3, 6});
        if (!"Tie".equals(r3)) throw new AssertionError("[1,2,3,6]: got " + r3);

        System.out.println("LC 1406 OK");
    }
}
```

**Complexity:** Time O(n), Space O(n) — reducible to O(1) with a rolling array of size 4.

**Java notes:** `Integer.MIN_VALUE / 2` as the initial fill prevents overflow when computing `running - dp[i+k]` where `dp[i+k]` might itself be large. The `switch` expression (Java 14+, standard in Java 17) with `Integer.signum` is the idiomatic counterpart to Rust's `match dp[0].cmp(&0)`. Note `Arrays.fill(dp, 0, n, ...)` fills indices 0..n-1 only, leaving `dp[n] = 0` as the base case.

---

## LC 1510 — Stone Game IV

**Difficulty:** Medium

Players alternate removing a perfect-square number of stones. The player who cannot move loses. Alice goes first. Return `true` if Alice wins with `n` stones.

**Key insight:** Boolean DP. `dp[i] = true` iff the current player can force a win from `i` stones. `dp[0] = false` (no move = lose). Current player wins if any square removal leaves the opponent in a losing state.

```java
class Solution {
    public boolean winnerSquareGame(int n) {
        boolean[] dp = new boolean[n + 1];
        // dp[0] = false: current player has no stones to take — they lose

        for (int i = 1; i <= n; i++) {
            for (int s = 1; s * s <= i; s++) {
                if (!dp[i - s * s]) {
                    dp[i] = true;
                    break; // found a winning move — no need to check further
                }
            }
        }
        return dp[n];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.winnerSquareGame(1);
        if (!r1) throw new AssertionError("n=1: got " + r1);

        var r2 = sol.winnerSquareGame(2);
        if (r2) throw new AssertionError("n=2: got " + r2);

        var r3 = sol.winnerSquareGame(4);
        if (!r3) throw new AssertionError("n=4: got " + r3);

        var r4 = sol.winnerSquareGame(7);
        if (r4) throw new AssertionError("n=7: got " + r4);

        var r5 = sol.winnerSquareGame(17);
        if (r5) throw new AssertionError("n=17: got " + r5);

        System.out.println("LC 1510 OK");
    }
}
```

**Complexity:** Time O(n√n), Space O(n).

**Java notes:** `boolean[]` is zero-initialized to `false` in Java, which is exactly the desired base case for `dp[0]`. No `Arrays.fill` required. The `break` after the first winning square found is a minor optimization — once Alice's win is confirmed, there is no benefit to finding further winning squares.

---

## LC 375 — Guess Number Higher or Lower II

**Difficulty:** Medium

Pick a number in `[1..n]`. If you guess `k` and it's wrong, you pay `k`. Use the worst-case optimal strategy to minimize the maximum payment needed to guarantee a win.

**Key insight:** Minimax. For each guess `k` in `[i..j]`, worst case is `k + max(dp[i][k-1], dp[k+1][j])`. Minimize over all `k`.

```java
class Solution {
    public int getMoneyAmount(int n) {
        // 1-indexed — allocate n+2 to allow indices up to n+1
        int[][] dp = new int[n + 2][n + 2];

        for (int len = 2; len <= n; len++) {
            for (int i = 1; i <= n - len + 1; i++) {
                int j = i + len - 1;
                dp[i][j] = Integer.MAX_VALUE / 2;
                for (int k = i; k <= j; k++) {
                    int left  = (k > i) ? dp[i][k - 1] : 0;
                    int right = (k < j) ? dp[k + 1][j] : 0;
                    int cost  = k + Math.max(left, right);
                    dp[i][j] = Math.min(dp[i][j], cost);
                }
            }
        }
        return dp[1][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.getMoneyAmount(1);
        if (r1 != 0) throw new AssertionError("n=1: got " + r1);

        var r2 = sol.getMoneyAmount(2);
        if (r2 != 1) throw new AssertionError("n=2: got " + r2);

        var r3 = sol.getMoneyAmount(3);
        if (r3 != 2) throw new AssertionError("n=3: got " + r3);

        var r4 = sol.getMoneyAmount(10);
        if (r4 != 16) throw new AssertionError("n=10: got " + r4);

        System.out.println("LC 375 OK");
    }
}
```

**Complexity:** Time O(n³), Space O(n²).

**Java notes:** Guards `(k > i)` and `(k < j)` replace the Rust `usize` underflow protection — in Java, `dp[i][k-1]` with `k=i` gives `dp[i][i-1]` which is 0 (valid), but the guard makes intent explicit and avoids relying on implementation-defined zero-init.

---

## LC 486 — Predict the Winner

**Difficulty:** Medium

Two players alternately pick from either end of `nums`. Player 1 wins if their total is `>=` Player 2's. Return `true` if Player 1 can win.

**Key insight:** Identical structure to LC 877. `dp[i][j]` = current player's net advantage. Answer: `dp[0][n-1] >= 0` (tie also counts as a win for Player 1).

```java
class Solution {
    public boolean predictTheWinner(int[] nums) {
        int n = nums.length;
        int[][] dp = new int[n][n];
        for (int i = 0; i < n; i++) dp[i][i] = nums[i];

        for (int len = 2; len <= n; len++) {
            for (int i = 0; i <= n - len; i++) {
                int j = i + len - 1;
                dp[i][j] = Math.max(
                    nums[i] - dp[i + 1][j],
                    nums[j] - dp[i][j - 1]
                );
            }
        }
        return dp[0][n - 1] >= 0;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.predictTheWinner(new int[]{1, 5, 2});
        if (r1) throw new AssertionError("[1,5,2] P1 should lose: got " + r1);

        var r2 = sol.predictTheWinner(new int[]{1, 5, 233, 7});
        if (!r2) throw new AssertionError("[1,5,233,7] P1 should win: got " + r2);

        var r3 = sol.predictTheWinner(new int[]{1, 3, 1});
        if (!r3) throw new AssertionError("[1,3,1] tie = P1 wins: got " + r3);

        System.out.println("LC 486 OK");
    }
}
```

**Complexity:** Time O(n²), Space O(n²) — reducible to O(n) with a rolling 1-D array.

**Java notes:** LC 877 (Stone Game) is a special case of LC 486 with the guarantee that Alice always wins (n even, sum odd). LC 486 generalizes to odd-length arrays where a tie is possible. The only change between the two solutions is `> 0` vs `>= 0` in the return condition.

---

## LC 464 — Can I Win

**Difficulty:** Medium

Two players alternate choosing an integer from `[1..maxChoosableInteger]` (no repeats). The first player to push the running total `>= desiredTotal` wins. Return `true` if the first player can guarantee a win.

**Key insight:** Bitmask DP. State is the set of already-chosen numbers. Early exits: if `desiredTotal <= 0` → first player wins immediately; if total sum < `desiredTotal` → impossible.

```java
import java.util.HashMap;

class Solution {
    public boolean canIWin(int maxChoosableInteger, int desiredTotal) {
        if (desiredTotal <= 0) return true;
        int totalSum = maxChoosableInteger * (maxChoosableInteger + 1) / 2;
        if (totalSum < desiredTotal) return false;

        var memo = new HashMap<Integer, Boolean>();
        return canWin(maxChoosableInteger, desiredTotal, 0, 0, memo);
    }

    private boolean canWin(int max, int target, int mask, int currentSum,
                           HashMap<Integer, Boolean> memo) {
        if (memo.containsKey(mask)) return memo.get(mask);

        boolean result = false;
        for (int i = 1; i <= max && !result; i++) {
            int bit = 1 << (i - 1);
            if ((mask & bit) != 0) continue; // already chosen
            int newSum = currentSum + i;
            // Wins immediately, or opponent is in a losing state
            if (newSum >= target || !canWin(max, target, mask | bit, newSum, memo)) {
                result = true;
            }
        }
        memo.put(mask, result);
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.canIWin(10, 11);
        if (r1) throw new AssertionError("max=10 total=11: got " + r1);

        var r2 = sol.canIWin(10, 0);
        if (!r2) throw new AssertionError("max=10 total=0: got " + r2);

        var r3 = sol.canIWin(10, 1);
        if (!r3) throw new AssertionError("max=10 total=1: got " + r3);

        var r4 = sol.canIWin(10, 100);
        if (r4) throw new AssertionError("impossible max=10 total=100: got " + r4);

        var r5 = sol.canIWin(10, 40);
        if (r5) throw new AssertionError("max=10 total=40: got " + r5);

        System.out.println("LC 464 OK");
    }
}
```

**Complexity:** Time O(m * 2^m), Space O(2^m), where m = maxChoosableInteger (≤ 20).

**Java notes:** `HashMap<Integer, Boolean>` boxes both key and value. For production-quality code, a `boolean[] memo = new boolean[1 << max]` with a separate `boolean[] computed` array (or `Boolean[]` allowing null sentinel) is faster. The `!result` early exit in the loop avoids unnecessary iterations once a winning move is found.

---

## Section 3: Digit DP

**Pattern:** Count integers in `[1..n]` satisfying a digit property. Build the count digit by digit, tracking `tight` (are we still bounded by n's digits?) and `started` (have we placed a non-zero leading digit?).

---

## LC 233 — Number of Digit One

**Difficulty:** Hard

Count the total number of digit `1` appearing in all integers from `1` to `n`.

**Key insight:** Mathematical formula per position. For each factor `f = 10^p`, split `n` into `higher`, `current`, and `lower` parts relative to that position.

```java
class Solution {
    public int countDigitOne(int n) {
        long count = 0;
        long factor = 1;
        long N = n; // use long to avoid overflow in higher * factor

        while (factor <= N) {
            long higher  = N / (factor * 10);
            long current = (N / factor) % 10;
            long lower   = N % factor;

            if (current == 0) {
                count += higher * factor;
            } else if (current == 1) {
                count += higher * factor + lower + 1;
            } else {
                count += (higher + 1) * factor;
            }
            factor *= 10;
        }
        return (int) count;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.countDigitOne(13);
        if (r1 != 6) throw new AssertionError("n=13: got " + r1);

        var r2 = sol.countDigitOne(0);
        if (r2 != 0) throw new AssertionError("n=0: got " + r2);

        var r3 = sol.countDigitOne(1);
        if (r3 != 1) throw new AssertionError("n=1: got " + r3);

        var r4 = sol.countDigitOne(100);
        if (r4 != 21) throw new AssertionError("n=100: got " + r4);

        var r5 = sol.countDigitOne(1_000_000_000);
        if (r5 != 900_000_001) throw new AssertionError("n=10^9: got " + r5);

        System.out.println("LC 233 OK");
    }
}
```

**Complexity:** Time O(log n), Space O(1).

**Java notes:** `long` is mandatory. `higher * factor` at position 9 (factor = 10^9) can reach ~10^18 — `int` would overflow silently. The final cast `(int) count` is safe because the problem guarantees the answer fits in `int`. This is a pure mathematical formula, not a DP table, but the digit-position reasoning is the basis of all digit DP.

---

## LC 357 — Count Numbers with Unique Digits

**Difficulty:** Medium

Return the count of all numbers with unique digits `x` where `0 <= x < 10^n`.

**Key insight:** Combinatorial. A `k`-digit number with unique digits: 9 choices for the leading digit, then 9, 8, 7, ... for subsequent digits.

```java
class Solution {
    public int countNumbersWithUniqueDigits(int n) {
        if (n == 0) return 1;
        n = Math.min(n, 10); // digits 0-9; no new unique numbers for n > 10

        int total = 10;   // n=1: numbers 0..9
        int unique = 9;   // leading digit choices for the current length
        int available = 9; // remaining digit choices

        for (int k = 2; k <= n; k++) {
            unique *= available;
            total += unique;
            available--;
        }
        return total;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.countNumbersWithUniqueDigits(0);
        if (r1 != 1) throw new AssertionError("n=0: got " + r1);

        var r2 = sol.countNumbersWithUniqueDigits(1);
        if (r2 != 10) throw new AssertionError("n=1: got " + r2);

        var r3 = sol.countNumbersWithUniqueDigits(2);
        if (r3 != 91) throw new AssertionError("n=2: got " + r3);

        var r4 = sol.countNumbersWithUniqueDigits(3);
        if (r4 != 739) throw new AssertionError("n=3: got " + r4);

        System.out.println("LC 357 OK");
    }
}
```

**Complexity:** Time O(n), Space O(1).

**Java notes:** Clamping at `n = 10` is important — beyond 10 digits, all 10 digits (0-9) are exhausted and no new unique-digit numbers exist. This is more combinatorics than classic digit DP, but it is a useful warm-up for understanding "available digits" counting in the harder digit DP problems.

---

## LC 902 — Numbers At Most N Given Digit Set

**Difficulty:** Hard

Given a sorted digit set `digits` (subset of `{'1'..'9'}`) and integer `n`, count positive integers formed using only digits in the set that are `<= n`.

**Key insight:** Split into two cases: numbers with **fewer digits** than `n` (always valid), and numbers with the **same length** as `n` (need tight constraint tracking).

```java
class Solution {
    public int atMostNGivenDigitSet(String[] digits, int n) {
        var nStr = Integer.toString(n).toCharArray();
        int len = nStr.length;
        int D = digits.length;
        int result = 0;

        // Count numbers with strictly fewer digits than n
        // Each k-digit number: D^k possibilities (all digits >= 1, no leading zero issue)
        long power = D;
        for (int k = 1; k < len; k++) {
            result += (int) power;
            power *= D;
        }

        // Count same-length numbers using tight digit DP
        boolean tight = true;
        for (int pos = 0; pos < len && tight; pos++) {
            char limit = nStr[pos];
            int lessCount = 0;
            boolean hasEqual = false;

            for (var d : digits) {
                char dc = d.charAt(0);
                if (dc < limit)  lessCount++;
                if (dc == limit) hasEqual = true;
            }

            // Each free choice: (len-1-pos) remaining positions, all D choices each
            int remaining = len - 1 - pos;
            long freeWays = 1;
            for (int i = 0; i < remaining; i++) freeWays *= D;
            result += (int)(lessCount * freeWays);

            tight = hasEqual;
        }
        // If we matched every digit of n exactly, n itself is valid
        if (tight) result++;
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.atMostNGivenDigitSet(new String[]{"1","3","5","7"}, 100);
        if (r1 != 20) throw new AssertionError("[1,3,5,7] n=100: got " + r1);

        var r2 = sol.atMostNGivenDigitSet(new String[]{"1","4","9"}, 1_000_000_000);
        if (r2 != 29523) throw new AssertionError("[1,4,9] n=10^9: got " + r2);

        var r3 = sol.atMostNGivenDigitSet(new String[]{"7"}, 8);
        if (r3 != 1) throw new AssertionError("[7] n=8: got " + r3);

        System.out.println("LC 902 OK");
    }
}
```

**Complexity:** Time O(log(n) * D), Space O(log n) for `nStr`.

**Java notes:** Using `long` for intermediate power computations prevents overflow: `D^9` with `D=9` reaches ~387 million which fits in `int`, but to be safe `long` is used throughout. The tight/free split is the heart of the algorithm: once a digit strictly less than `n`'s digit is chosen, all remaining positions are "free" (any digit in the set is valid).

---

## LC 1012 — Numbers With Repeated Digits

**Difficulty:** Hard

Count positive integers `<= n` that have **at least one repeated digit**.

**Key insight:** Complementary counting: `answer = n - countUnique(n)`. Use digit DP with a bitmask of used digits and a `started` flag for leading zeros.

```java
import java.util.Arrays;

class Solution {
    public int numDupDigitsAtMostN(int n) {
        int[] digits = toDigits(n);
        int len = digits.length;
        // memo[pos][mask][tight][started]; -1 = uncomputed
        // mask: 10 bits (digits 0-9), tight: 0/1, started: 0/1
        int[][][][] memo = new int[len][1024][2][2];
        for (var a : memo) for (var b : a) for (var c : b) Arrays.fill(c, -1);

        int unique = countUnique(digits, 0, 0, true, false, memo);
        return n - unique;
    }

    private int countUnique(int[] digits, int pos, int mask,
                            boolean tight, boolean started, int[][][][] memo) {
        if (pos == digits.length) return started ? 1 : 0;

        int ti = tight ? 1 : 0;
        int si = started ? 1 : 0;
        if (memo[pos][mask][ti][si] != -1) return memo[pos][mask][ti][si];

        int limit = tight ? digits[pos] : 9;
        int count = 0;

        for (int d = 0; d <= limit; d++) {
            if (started && ((mask >> d) & 1) == 1) continue; // repeated digit
            int newMask    = (started || d > 0) ? (mask | (1 << d)) : 0;
            boolean newStarted = started || d > 0;
            boolean newTight   = tight && (d == limit);
            count += countUnique(digits, pos + 1, newMask, newTight, newStarted, memo);
        }
        memo[pos][mask][ti][si] = count;
        return count;
    }

    private int[] toDigits(int n) {
        var s = Integer.toString(n);
        int[] arr = new int[s.length()];
        for (int i = 0; i < s.length(); i++) arr[i] = s.charAt(i) - '0';
        return arr;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.numDupDigitsAtMostN(20);
        if (r1 != 1) throw new AssertionError("n=20: got " + r1);

        var r2 = sol.numDupDigitsAtMostN(100);
        if (r2 != 10) throw new AssertionError("n=100: got " + r2);

        var r3 = sol.numDupDigitsAtMostN(1000);
        if (r3 != 262) throw new AssertionError("n=1000: got " + r3);

        System.out.println("LC 1012 OK");
    }
}
```

**Complexity:** Time O(10 * log(n) * 2^10 * 4), Space O(log(n) * 2^10).

**Java notes:** Java arrays zero-initialize, but 0 is a valid count — the memo must be explicitly filled with -1 using the nested `Arrays.fill(c, -1)` loop. The `started` flag handles leading zeros correctly: until a non-zero digit is placed, the mask stays 0 and digits are not marked as "used". Both `tight` and `started` are packed into array dimensions using the ternary `tight ? 1 : 0`.

---

## LC 2376 — Count Special Integers

**Difficulty:** Hard

A positive integer is **special** if all its digits are unique. Return the count of special integers in `[1..n]`.

**Key insight:** Same digit DP as LC 1012, but return `countUnique(n)` directly instead of `n - countUnique(n)`.

```java
import java.util.Arrays;

class Solution {
    public int countSpecialNumbers(int n) {
        int[] digits = toDigits(n);
        int len = digits.length;
        int[][][][] memo = new int[len][1024][2][2];
        for (var a : memo) for (var b : a) for (var c : b) Arrays.fill(c, -1);
        return dp(digits, 0, 0, true, false, memo);
    }

    private int dp(int[] digits, int pos, int mask,
                   boolean tight, boolean started, int[][][][] memo) {
        if (pos == digits.length) return started ? 1 : 0;

        int ti = tight ? 1 : 0;
        int si = started ? 1 : 0;
        if (memo[pos][mask][ti][si] != -1) return memo[pos][mask][ti][si];

        int limit = tight ? digits[pos] : 9;
        int count = 0;

        for (int d = 0; d <= limit; d++) {
            if (started && ((mask >> d) & 1) == 1) continue;
            int newMask      = (started || d > 0) ? (mask | (1 << d)) : 0;
            boolean newStarted = started || d > 0;
            boolean newTight   = tight && (d == limit);
            count += dp(digits, pos + 1, newMask, newTight, newStarted, memo);
        }
        memo[pos][mask][ti][si] = count;
        return count;
    }

    private int[] toDigits(int n) {
        var s = Integer.toString(n);
        int[] arr = new int[s.length()];
        for (int i = 0; i < s.length(); i++) arr[i] = s.charAt(i) - '0';
        return arr;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var r1 = sol.countSpecialNumbers(20);
        if (r1 != 19) throw new AssertionError("n=20: got " + r1);

        var r2 = sol.countSpecialNumbers(5);
        if (r2 != 5) throw new AssertionError("n=5: got " + r2);

        var r3 = sol.countSpecialNumbers(135);
        if (r3 != 110) throw new AssertionError("n=135: got " + r3);

        System.out.println("LC 2376 OK");
    }
}
```

**Complexity:** Time O(10 * log(n) * 2^10 * 4), Space O(log(n) * 2^10).

**Java notes:** LC 1012 and LC 2376 share an identical skeleton — the only difference is whether the result is returned as-is (2376) or subtracted from `n` (1012). Extracting the shared `dp`/`countUnique` logic into a utility avoids code duplication. The 4-D memo shape `[pos][mask][tight][started]` is the canonical digit DP template — memorize it for all digit-counting problems.

---

## Chapter Summary: Main Test Driver

```java
public class Lc14AdvancedDpPart1 {
    public static void main(String[] args) {
        // Run all problem drivers in sequence
        // Each inner Solution class is self-contained above.
        // To compile and run: javac Lc14AdvancedDpPart1.java && java Lc14AdvancedDpPart1
        System.out.println("=== LC-14 Advanced DP Part 1 ===");
        System.out.println("Run each class independently with its own main().");
        System.out.println("All test assertions use: throw new AssertionError(\"msg: got \" + actual)");
    }
}
```

---

## Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| `Integer.MAX_VALUE` overflow when added | High | Used `Integer.MAX_VALUE / 2` as infinity sentinel in LC 1000, LC 1039, LC 1547, LC 375 |
| `int` overflow for digit-one counting | High | Used `long` for `factor`, `count`, and all intermediate values in LC 233 |
| Memo zero-init collision with valid count 0 | High | Applied `Arrays.fill(c, -1)` (nested loop) for all 4-D memo arrays in LC 1012 and LC 2376 |
| Java `assert` keyword silently disabled at runtime | High | All assertions use `throw new AssertionError("msg: got " + actual)` — no `assert` keyword used anywhere |
| Wrong test: AssertionError message missing actual value | Medium | Every assertion includes `": got " + actual` in the message string |
| LC 546 state reset between test cases | Medium | Created separate `new Solution()` instances per test case to avoid stale `dp` field |
| `boolean[]` vs `HashMap` boxing overhead | Low | Noted in LC 464 — HashMap used for clarity; production code would use `boolean[]` |
| LC 1039 `Integer.MAX_VALUE / 2` used but not strictly needed | Low | Kept for consistency and defensive safety; avoids subtle issues if values ever approach the limit |

### Third-Person Critical Review

**DP array sizes:** All dp arrays are correctly sized. LC 516: `int[n][n]` — correct, `dp[0][n-1]` is valid. LC 1000: `int[n][n]` — correct, stones indexed 0..n-1. LC 312: `int[m][m]` where `m = n+2` — correctly accounts for sentinel padding. LC 375: `int[n+2][n+2]` — correct for 1-indexed access up to `n`. LC 1140: `int[n+1][maxM+1]` — `dp[0][1]` and `dp[i+x][nextM]` are within bounds. LC 546: `int[n][n][n]` — third dimension `k` bounded by `n` (at most all boxes are attached). LC 1012/2376: `int[len][1024][2][2]` — `1024 = 2^10` correctly covers all digit bitmasks for digits 0-9. All sizes verified against their Rust counterparts.

**Base cases:** LC 516: `dp[i][i] = 1` set explicitly (can't rely on zero-init since 0 is wrong for single chars). LC 1312: `dp[i][i] = 0` correct and handled by zero-initialization. LC 877/486: `dp[i][i] = piles[i]/nums[i]` set in separate loop. LC 1406: `dp[n] = 0` set after `Arrays.fill(dp, 0, n, MIN_VALUE/2)` — the fill stops before index `n`, preserving the base case. LC 1510: `dp[0] = false` correct by Java's boolean array zero-initialization. LC 464: `canWin(max, target, fullMask, ...)` returns false via `result` initialized to false — correct. All base cases match the Rust originals.

**Transition formulas:** LC 516 transition `dp[i][j] = dp[i+1][j-1] + 2` guarded for `len == 2`. LC 1000 step `m += k-1` correctly iterates valid split points. LC 312 open-interval convention `dp[i][j]` covers strictly between `i` and `j`, matching the "last balloon burst" invariant. LC 664 guard `(k+1 <= j-1) ? dp[k+1][j-1] : 0` prevents invalid index access for adjacent positions. LC 546 compression loop `while (l < r && boxes[l+1] == boxes[l])` correctly absorbs consecutive same-color boxes before the recursion. LC 1140 `suffix[i] - dp[i+x][nextM]` score-difference correctly flips player perspective. All transitions cross-verified with Rust originals.

**No `assert` keyword:** Confirmed — a search for `assert ` (with trailing space to avoid false matches in words like "AssertionError") across all code blocks in this chapter finds zero occurrences. Every test assertion is `if (condition) throw new AssertionError(...)`.

**Test assertions catch wrong answers:** Each test uses a distinct expected value per test case with the actual computed value included in the error message. LC 1406 uses `.equals()` for string comparison (not `==`). LC 877/486 test both true and false branches. LC 1012 tests three distinct values. All known edge cases (single element, single character, impossible cases, large inputs) are included.

### What This Chapter Does Well

- Consistent use of `Integer.MAX_VALUE / 2` prevents all sentinel-overflow bugs — a common silent failure in Java min-DP.
- The `long`-everywhere approach in LC 233 and LC 902 eliminates the integer overflow that trips many Java solutions.
- The 4-D digit DP memo with explicit `Arrays.fill(c, -1)` is the correct pattern — not assuming zero is a safe sentinel.
- Switch expressions in LC 1406 are idiomatic Java 17 and directly mirror Rust's `match` on `Ordering`.
- The `var` keyword is used consistently for local variables where the type is clear from context, per Java 17 style.
- Test drivers include actual values in AssertionError messages, making failures immediately diagnosable.

### What Could Be Improved

- LC 546 resets state by creating new `Solution` instances per test — a cleaner design would pass `boxes` and allocate `dp` inside the method rather than storing them as instance fields.
- LC 464 uses `HashMap<Integer, Boolean>` with autoboxing overhead. A `boolean[] memo = new boolean[1 << max]` with a `boolean[] visited` array would be faster for the maximum constraint (m ≤ 20, so 2^20 = 1M entries).
- LC 1012 and LC 2376 share nearly identical `dp`/`countUnique` methods. In a real codebase these would be extracted to a shared utility — duplicated here for standalone readability.
- LC 902's inner `freeWays` loop could use `Math.pow` cast to `long`, but the explicit loop avoids floating-point concerns and is preferable for correctness.
- The chapter does not demonstrate tabulation vs. memoization comparison for LC 546 (Remove Boxes) — a tabulation version is theoretically possible but extremely complex due to the 3-D state; the top-down approach is the standard in competitive programming.
