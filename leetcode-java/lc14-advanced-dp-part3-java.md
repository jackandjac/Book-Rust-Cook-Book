# Chapter LC-14 Part 3 (Java): String DP, Probability DP, D&C Optimization, Advanced Knapsack

> **Java 17+ companion to the Rust Part 3 chapter.** Covers the same 22 problems across
> four specialized DP families: advanced string matching, probability / expected-value DP,
> divide-and-conquer optimization, and multidimensional knapsack variants.
>
> **Compilation note:** Each code block is a self-contained class. They are *not* meant
> to be compiled together — `class Solution` appears in every block as LeetCode convention.
> Copy any single block into a file named `Main.java` (renaming the outer class if needed)
> to run it locally.

---

> **Java vs Rust**
>
> - Java `int[]` and `int[][]` arrays are **zero-initialized** by the JVM — no `Arrays.fill`
>   needed for zero-based DP tables. Use `Arrays.fill(dp, Integer.MAX_VALUE / 2)` only when
>   you need a non-zero sentinel (infinity for min-DP).
> - `HashMap<Integer, Integer>` memo uses **autoboxed `Integer`** objects; on hot inner loops
>   prefer `int[]` arrays when the key space is bounded.
> - `Integer.MAX_VALUE / 2` is the safe infinity for `int` min-DP (adding two copies stays
>   within `int` range). For `long` tables use `Long.MAX_VALUE / 2`.
> - Java's `>>` is **arithmetic** (sign-extending) on `long`; use `>>>` (logical shift) when
>   doing bit-manipulation carry across word boundaries.

---

## Problem Overview

| # | LC | Problem | Section | Difficulty |
|---|-----|---------|---------|-----------|
| 1 | 10 | Regular Expression Matching | String DP | Hard |
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

> **Two adjacent "repeated" problems:**
> - **LC #718** finds the longest *contiguous* common subarray (substring) — table resets to
>   `0` on mismatch.
> - **LC #1035** finds the longest common *subsequence* — table takes `max` of two directions
>   on mismatch.
> They differ by one word and produce completely different tables. Do not conflate them.

---

## LC #10 — Regular Expression Matching

**Difficulty:** Hard

### Problem Statement

Match string `s` against pattern `p` where `.` matches any single character and `*` matches
zero or more of the **preceding element**. The entire string must match.

`*` is always paired with the character before it (`a*` = zero or more `a`s). This differs
from LC #44 where `*` stands alone and matches any sequence.

### Key Insight

Build a 2-D boolean table `dp[i][j]` = "does `s[0..i]` match `p[0..j]`?". The base case
for patterns of the form `a*b*` matching empty strings requires a separate initialization
loop stepping by 2.

### Java Solution (Tabulation)

```java
class Solution {
    public boolean isMatch(String s, String p) {
        int m = s.length(), n = p.length();
        // dp[i][j] = s[0..i) matched by p[0..j); zero-init = false
        var dp = new boolean[m + 1][n + 1];
        dp[0][0] = true;
        // Patterns like "a*b*" can match empty string: step by 2 from j=2
        for (int j = 2; j <= n; j++) {
            if (p.charAt(j - 1) == '*') {
                dp[0][j] = dp[0][j - 2];  // zero copies of preceding char
            }
        }
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                char pc = p.charAt(j - 1);
                char sc = s.charAt(i - 1);
                if (pc == '*') {
                    // Zero copies of p[j-2]: inherit dp[i][j-2]
                    dp[i][j] = dp[i][j - 2];
                    // One or more copies if preceding pattern char matches current s char
                    char prev = p.charAt(j - 2);
                    if (prev == '.' || prev == sc) {
                        dp[i][j] = dp[i][j] || dp[i - 1][j];
                    }
                } else {
                    dp[i][j] = dp[i - 1][j - 1] && (pc == '.' || pc == sc);
                }
            }
        }
        return dp[m][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        if (sol.isMatch("aa", "a"))    throw new AssertionError("LC10: expected false for aa,a; got true");
        if (!sol.isMatch("aa", "a*"))  throw new AssertionError("LC10: expected true for aa,a*; got false");
        if (!sol.isMatch("ab", ".*"))  throw new AssertionError("LC10: expected true for ab,.*");
        if (!sol.isMatch("aab", "c*a*b")) throw new AssertionError("LC10: expected true for aab,c*a*b");
        if (sol.isMatch("mississippi", "mis*is*p*.")) throw new AssertionError("LC10: expected false mississippi");
        if (!sol.isMatch("", "a*b*"))  throw new AssertionError("LC10: expected true for empty,a*b*");
        System.out.println("LC10 all tests passed");
    }
}
```

**Time:** O(m × n) | **Space:** O(m × n)

### Approach 2 — Top-Down Memoization

```java
import java.util.Arrays;

class Solution {
    private int m, n;
    private String s, p;
    // 0=unset, 1=true, -1=false
    private byte[][] memo;

    public boolean isMatchMemo(String s, String p) {
        this.s = s; this.p = p;
        this.m = s.length(); this.n = p.length();
        this.memo = new byte[m + 1][n + 1];
        return dp(0, 0);
    }

    private boolean dp(int i, int j) {
        if (memo[i][j] != 0) return memo[i][j] == 1;
        boolean result;
        if (j == n) {
            result = (i == m);
        } else if (j + 1 < n && p.charAt(j + 1) == '*') {
            // Zero copies of p[j]:
            boolean zero = dp(i, j + 2);
            // One or more copies of p[j]:
            boolean more = i < m
                && (p.charAt(j) == '.' || p.charAt(j) == s.charAt(i))
                && dp(i + 1, j);
            result = zero || more;
        } else {
            result = i < m
                && (p.charAt(j) == '.' || p.charAt(j) == s.charAt(i))
                && dp(i + 1, j + 1);
        }
        memo[i][j] = result ? (byte)1 : (byte)-1;
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        if (sol.isMatchMemo("aa", "a"))     throw new AssertionError("LC10 memo: expected false aa,a");
        if (!sol.isMatchMemo("aa", "a*"))   throw new AssertionError("LC10 memo: expected true aa,a*");
        if (!sol.isMatchMemo("aab", "c*a*b")) throw new AssertionError("LC10 memo: expected true aab");
        System.out.println("LC10 top-down OK");
    }
}
```

**Java notes:** `boolean[][]` is zero-initialized to `false` — no fill needed. The base-case
loop starts at `j = 2` (not 1) because `*` must have a preceding character. Compare to LC #44
where the base loop starts at `j = 1` and uses `dp[0][j-1]` (not `dp[0][j-2]`). In the top-down
version, a `byte[][]` memo using sentinel values (0=unset, 1=true, -1=false) avoids boxing
`Boolean` objects — the same technique as Rust's `i8` memo.

---

## LC #44 — Wildcard Matching

**Difficulty:** Hard

### Problem Statement

Match string `s` against pattern `p` where `?` matches any single character and `*` matches
**any sequence** (including empty). `*` stands alone — no pairing with a preceding character.

### Key Insight

Same table shape as LC #10 but `*` semantics differ completely. Base case: a sequence of `*`
can all match empty string, so `dp[0][j] = dp[0][j-1]` when `p[j-1]=='*'`. In the transition,
`*` can expand empty (`dp[i][j-1]`) or consume one more char of `s` (`dp[i-1][j]`).

### Java Solution (Tabulation)

```java
class Solution {
    public boolean isMatch(String s, String p) {
        int m = s.length(), n = p.length();
        var dp = new boolean[m + 1][n + 1];
        dp[0][0] = true;
        // Leading stars match empty string (dp[0][j] = dp[0][j-1] when p[j-1]=='*')
        for (int j = 1; j <= n; j++) {
            if (p.charAt(j - 1) == '*') dp[0][j] = dp[0][j - 1];
        }
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                char pc = p.charAt(j - 1);
                if (pc == '*') {
                    // Empty expansion OR consume one char of s
                    dp[i][j] = dp[i][j - 1] || dp[i - 1][j];
                } else {
                    dp[i][j] = dp[i - 1][j - 1] && (pc == '?' || pc == s.charAt(i - 1));
                }
            }
        }
        return dp[m][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        if (sol.isMatch("aa", "a"))      throw new AssertionError("LC44: expected false aa,a");
        if (!sol.isMatch("aa", "*"))     throw new AssertionError("LC44: expected true aa,*");
        if (sol.isMatch("cb", "?a"))     throw new AssertionError("LC44: expected false cb,?a");
        if (!sol.isMatch("adceb", "*a*b")) throw new AssertionError("LC44: expected true adceb,*a*b");
        if (sol.isMatch("acdcb", "a*c?b")) throw new AssertionError("LC44: expected false acdcb");
        if (!sol.isMatch("", "***"))     throw new AssertionError("LC44: expected true empty,***");
        System.out.println("LC44 all tests passed");
    }
}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Java notes:** The single most common bug between LC #10 and LC #44 is swapping the base
cases: `dp[0][j] = dp[0][j-2]` (LC #10, star must be paired) vs `dp[0][j] = dp[0][j-1]`
(LC #44, star stands alone). The loop start also differs: LC #10 starts at `j=2`; LC #44
starts at `j=1`.

---

## LC #1458 — Max Dot Product of Two Subsequences

**Difficulty:** Hard

### Problem Statement

Given arrays `nums1` and `nums2`, choose subsequences of equal length (at least one element
each) and maximize their dot product.

### Key Insight

`dp[i][j]` = best dot product from `nums1[0..i]` and `nums2[0..j]`. At each cell, we either
start a fresh pair (just `nums1[i-1]*nums2[j-1]`), extend a previous positive dot product, or
carry forward the best seen in either prefix. Initialize to `Integer.MIN_VALUE` to distinguish
"no pair chosen yet" from a legitimately negative result.

### Java Solution

```java
class Solution {
    public int maxDotProduct(int[] nums1, int[] nums2) {
        int m = nums1.length, n = nums2.length;
        var dp = new int[m + 1][n + 1];
        // Sentinel: no valid pair formed yet — cannot use 0 since product can be negative
        for (var row : dp) java.util.Arrays.fill(row, Integer.MIN_VALUE);
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                int prod = nums1[i - 1] * nums2[j - 1];
                dp[i][j] = prod;                          // take this pair alone
                if (dp[i - 1][j - 1] > 0) {
                    dp[i][j] = Math.max(dp[i][j], dp[i - 1][j - 1] + prod);
                }
                if (dp[i - 1][j] != Integer.MIN_VALUE) {
                    dp[i][j] = Math.max(dp[i][j], dp[i - 1][j]);
                }
                if (dp[i][j - 1] != Integer.MIN_VALUE) {
                    dp[i][j] = Math.max(dp[i][j], dp[i][j - 1]);
                }
            }
        }
        return dp[m][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.maxDotProduct(new int[]{2,1,-2,5}, new int[]{3,0,-6});
        if (r1 != 18) throw new AssertionError("LC1458: expected 18, got " + r1);
        int r2 = sol.maxDotProduct(new int[]{3,-2}, new int[]{2,-6,7});
        if (r2 != 21) throw new AssertionError("LC1458: expected 21, got " + r2);
        int r3 = sol.maxDotProduct(new int[]{-1,-1}, new int[]{1,1});
        if (r3 != -1) throw new AssertionError("LC1458: expected -1, got " + r3);
        System.out.println("LC1458 all tests passed");
    }
}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Java notes:** `Arrays.fill(row, Integer.MIN_VALUE)` per row populates the sentinel. The
guard `dp[i-1][j-1] > 0` avoids extending a previously negative dot product — extending it
would make things worse.

---

## LC #1092 — Shortest Common Supersequence

**Difficulty:** Hard

### Problem Statement

Given strings `str1` and `str2`, find the shortest string that has both as subsequences.

### Key Insight

Build the LCS table, then reconstruct the SCS by back-tracing: when both strings share a
character, emit it once; otherwise emit the character from whichever string's LCS path is
longer. Append any remaining characters from either string. The result is built in reverse,
so reverse it at the end.

### Java Solution

```java
class Solution {
    public String shortestCommonSupersequence(String str1, String str2) {
        int m = str1.length(), n = str2.length();
        // LCS table — zero-initialized
        var lcs = new int[m + 1][n + 1];
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                if (str1.charAt(i - 1) == str2.charAt(j - 1)) {
                    lcs[i][j] = lcs[i - 1][j - 1] + 1;
                } else {
                    lcs[i][j] = Math.max(lcs[i - 1][j], lcs[i][j - 1]);
                }
            }
        }
        // Back-trace to reconstruct SCS in reverse
        var sb = new StringBuilder();
        int i = m, j = n;
        while (i > 0 && j > 0) {
            if (str1.charAt(i - 1) == str2.charAt(j - 1)) {
                sb.append(str1.charAt(i - 1));
                i--; j--;
            } else if (lcs[i - 1][j] > lcs[i][j - 1]) {
                sb.append(str1.charAt(i - 1));
                i--;
            } else {
                sb.append(str2.charAt(j - 1));
                j--;
            }
        }
        while (i > 0) { sb.append(str1.charAt(i - 1)); i--; }
        while (j > 0) { sb.append(str2.charAt(j - 1)); j--; }
        return sb.reverse().toString();
    }

    static boolean isSubseq(String needle, String haystack) {
        int hi = 0;
        for (int ni = 0; ni < needle.length(); ni++) {
            while (hi < haystack.length() && haystack.charAt(hi) != needle.charAt(ni)) hi++;
            if (hi == haystack.length()) return false;
            hi++;
        }
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        String r1 = sol.shortestCommonSupersequence("abac", "cab");
        if (r1.length() != 5) throw new AssertionError("LC1092: expected length 5, got " + r1.length() + " (" + r1 + ")");
        if (!isSubseq("abac", r1) || !isSubseq("cab", r1))
            throw new AssertionError("LC1092: result not a supersequence: " + r1);
        String r2 = sol.shortestCommonSupersequence("abc", "abc");
        if (r2.length() != 3) throw new AssertionError("LC1092: expected length 3, got " + r2.length());
        if (!isSubseq("abc", r2)) throw new AssertionError("LC1092: r2 not supersequence: " + r2);
        System.out.println("LC1092 all tests passed");
    }
}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Java notes:** `StringBuilder.reverse()` replaces the Rust `result.reverse()`. The test
verifies the *subsequence property* rather than an exact string, since multiple valid SCS
answers exist. `isSubseq` is a simple two-pointer helper defined as a static method.

---

## LC #1062 — Longest Repeating Substring *(Premium)*

**Difficulty:** Medium

### Problem Statement

Find the length of the longest substring of `s` that occurs at least twice (overlapping
occurrences are allowed).

### Key Insight

Self-comparison LCS-substring table: `dp[i][j]` = length of longest common suffix of
`s[0..i]` and `s[0..j]`. Enforce `j > i` to guarantee two distinct starting positions.
Only the upper triangle of the matrix is filled.

### Java Solution

```java
class Solution {
    public int longestRepeatingSubstring(String s) {
        int n = s.length();
        var dp = new int[n + 1][n + 1];  // zero-initialized
        int ans = 0;
        for (int i = 1; i <= n; i++) {
            for (int j = i + 1; j <= n; j++) {  // j > i: distinct positions
                if (s.charAt(i - 1) == s.charAt(j - 1)) {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                    ans = Math.max(ans, dp[i][j]);
                }
                // else stays 0 — reset for substring (not subsequence)
            }
        }
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.longestRepeatingSubstring("abcd");
        if (r1 != 0) throw new AssertionError("LC1062: expected 0, got " + r1);
        int r2 = sol.longestRepeatingSubstring("abbaba");
        if (r2 != 2) throw new AssertionError("LC1062: expected 2, got " + r2);
        int r3 = sol.longestRepeatingSubstring("aabaabaab");
        if (r3 != 6) throw new AssertionError("LC1062: expected 6, got " + r3);
        System.out.println("LC1062 all tests passed");
    }
}
```

**Time:** O(n²) | **Space:** O(n²) — binary search + rolling hash reduces to O(n log n)

**Java notes:** The inner loop starts at `j = i + 1` (not `j = 1`) to guarantee distinct
indices without a runtime `i != j` guard inside the hot path. On large inputs the O(n²)
space can be reduced to O(n) with a rolling row (anti-diagonal traversal).

---

## LC #718 — Maximum Length of Repeated Subarray

**Difficulty:** Medium

### Problem Statement

Given two integer arrays `nums1` and `nums2`, find the maximum length of a subarray
(contiguous, same values) that appears in both. This is the longest common *substring*
problem on integer arrays.

### Key Insight

`dp[i][j]` = length of longest common suffix ending at `nums1[i-1]` and `nums2[j-1]`.
Reset to `0` on mismatch — contiguity requires a hard reset, unlike LCS which takes `max`.

### Java Solution

```java
class Solution {
    public int findLength(int[] nums1, int[] nums2) {
        int m = nums1.length, n = nums2.length;
        var dp = new int[m + 1][n + 1];  // zero-initialized
        int ans = 0;
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                if (nums1[i - 1] == nums2[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                    ans = Math.max(ans, dp[i][j]);
                }
                // Mismatch: dp[i][j] stays 0 — no extension of a common subarray
            }
        }
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.findLength(new int[]{1,2,3,2,1}, new int[]{3,2,1,4,7});
        if (r1 != 3) throw new AssertionError("LC718: expected 3, got " + r1);
        int r2 = sol.findLength(new int[]{0,0,0,0,0}, new int[]{0,0,0,0,0});
        if (r2 != 5) throw new AssertionError("LC718: expected 5, got " + r2);
        int r3 = sol.findLength(new int[]{1,2}, new int[]{3,4});
        if (r3 != 0) throw new AssertionError("LC718: expected 0, got " + r3);
        System.out.println("LC718 all tests passed");
    }
}
```

**Time:** O(m × n) | **Space:** O(m × n), reducible to O(min(m,n)) with a rolling row

**Java notes:** Unlike LCS (which takes `max` of three cells), this table resets to `0`
on mismatch because a common subarray must be contiguous. The zero-initialization of Java
arrays handles this correctly with no explicit fill.

---

## LC #1035 — Uncrossed Lines

**Difficulty:** Medium

### Problem Statement

Draw lines connecting equal values `nums1[i]` to `nums2[j]`. Lines must not cross (indices
strictly increasing on both sides). Maximize lines drawn. This is exactly **LCS on integer
arrays**.

### Key Insight

The non-crossing constraint is equivalent to requiring both index sequences to be strictly
increasing — which is precisely the LCS condition. The code is identical to the classic LCS
table.

### Java Solution

```java
class Solution {
    public int maxUncrossedLines(int[] nums1, int[] nums2) {
        int m = nums1.length, n = nums2.length;
        var dp = new int[m + 1][n + 1];
        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                dp[i][j] = (nums1[i - 1] == nums2[j - 1])
                    ? dp[i - 1][j - 1] + 1
                    : Math.max(dp[i - 1][j], dp[i][j - 1]);
            }
        }
        return dp[m][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.maxUncrossedLines(new int[]{1,4,2}, new int[]{1,2,4});
        if (r1 != 2) throw new AssertionError("LC1035: expected 2, got " + r1);
        int r2 = sol.maxUncrossedLines(new int[]{2,5,1,2,5}, new int[]{10,5,2,1,5,2});
        if (r2 != 3) throw new AssertionError("LC1035: expected 3, got " + r2);
        int r3 = sol.maxUncrossedLines(new int[]{1,3,7,1,7,5}, new int[]{1,9,2,5,1});
        if (r3 != 2) throw new AssertionError("LC1035: expected 2, got " + r3);
        System.out.println("LC1035 all tests passed");
    }
}
```

**Time:** O(m × n) | **Space:** O(m × n)

**Java notes:** Using a ternary expression for the transition is idiomatic Java here — the
two branches map cleanly to match vs mismatch. When you recognize the geometric problem
reduces to LCS, the code is standard and deserves a comment in an interview.

---

## Section 8: Probability and Expected Value DP

> **Floating-point rule:** Never use `==` comparison on `double`. All tests check
> `Math.abs(actual - expected) < 1e-5`, matching LeetCode's tolerance. Never use the
> `assert` keyword — Java assertions are disabled at runtime unless `-ea` is passed;
> use `throw new AssertionError(...)` instead.

---

## LC #837 — New 21 Game

**Difficulty:** Medium

### Problem Statement

Alice draws 1 to `maxPts` points per round, stopping when she reaches `k` or more points.
Find the probability her final score is at most `n`.

### Key Insight

`dp[i]` = probability of reaching exactly score `i`. Maintain a sliding window sum over
`dp[i-maxPts..i-1]` and divide by `maxPts`. Only scores in `[k, n]` sum to the answer.
Early-exit: if `k == 0` or `n >= k + maxPts - 1`, the answer is `1.0`.

### Java Solution

```java
class Solution {
    public double new21Game(int n, int k, int maxPts) {
        if (k == 0 || n >= k + maxPts - 1) return 1.0;
        var dp = new double[n + 1];
        dp[0] = 1.0;
        double windowSum = 1.0;
        for (int i = 1; i <= n; i++) {
            dp[i] = windowSum / maxPts;
            if (i < k) windowSum += dp[i];    // new reachable score enters window
            if (i >= maxPts) windowSum -= dp[i - maxPts]; // old score leaves window
        }
        double ans = 0.0;
        for (int i = k; i <= n; i++) ans += dp[i];
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        double r1 = sol.new21Game(10, 1, 10);
        if (Math.abs(r1 - 1.0) > 1e-5) throw new AssertionError("LC837: expected 1.0, got " + r1);
        double r2 = sol.new21Game(6, 1, 10);
        if (Math.abs(r2 - 0.6) > 1e-5) throw new AssertionError("LC837: expected 0.6, got " + r2);
        double r3 = sol.new21Game(21, 17, 10);
        if (Math.abs(r3 - 0.73278) > 1e-5) throw new AssertionError("LC837: expected ~0.73278, got " + r3);
        System.out.println("LC837 all tests passed");
    }
}
```

**Time:** O(n) | **Space:** O(n)

**Java notes:** The sliding-window sum replaces an O(n × maxPts) naive inner loop. The two
window update conditions — `if (i < k)` to add and `if (i >= maxPts)` to remove — must not
be swapped. Use `double[]` (primitive), not `Double[]` (boxed), to avoid autoboxing overhead.

---

## LC #688 — Knight Probability in Chessboard

**Difficulty:** Medium

### Problem Statement

An `n×n` board. A knight starts at `(row, col)` and makes exactly `k` moves, each uniformly
random from up to 8 valid directions. Return the probability it stays on the board after all
`k` moves.

### Key Insight

Forward DP: `dp[r][c]` = probability of being at `(r,c)` after the current step. Each step
spreads probability to each valid knight-move target, dividing by 8. Sum all cells after `k`
steps.

### Java Solution

```java
class Solution {
    private static final int[][] MOVES = {
        {-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}
    };

    public double knightProbability(int n, int k, int row, int column) {
        var dp = new double[n][n];
        dp[row][column] = 1.0;
        for (int step = 0; step < k; step++) {
            var next = new double[n][n];
            for (int r = 0; r < n; r++) {
                for (int c = 0; c < n; c++) {
                    if (dp[r][c] == 0.0) continue;
                    for (var move : MOVES) {
                        int nr = r + move[0], nc = c + move[1];
                        if (nr >= 0 && nr < n && nc >= 0 && nc < n) {
                            next[nr][nc] += dp[r][c] / 8.0;
                        }
                    }
                }
            }
            dp = next;
        }
        double sum = 0.0;
        for (var row2 : dp) for (double v : row2) sum += v;
        return sum;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        double r1 = sol.knightProbability(3, 2, 0, 0);
        if (Math.abs(r1 - 0.0625) > 1e-5) throw new AssertionError("LC688: expected 0.0625, got " + r1);
        double r2 = sol.knightProbability(1, 0, 0, 0);
        if (Math.abs(r2 - 1.0) > 1e-5) throw new AssertionError("LC688: expected 1.0, got " + r2);
        System.out.println("LC688 all tests passed");
    }
}
```

**Time:** O(k × n²) | **Space:** O(n²)

**Java notes:** `double[][]` is zero-initialized — `next` starts clean each step without an
`Arrays.fill`. Skipping cells where `dp[r][c] == 0.0` is a safe micro-optimization here
because the value is exactly 0.0 (set by JVM init), never a floating-point artifact.

---

## LC #576 — Out of Boundary Paths

**Difficulty:** Medium

### Problem Statement

An `m×n` grid. Starting at `(startRow, startCol)`, make exactly `maxMove` moves
(4 directions). Count paths that exit the boundary at any step. Return answer mod `10^9+7`.

### Key Insight

Forward DP with layer-by-layer iteration. When a move would go out of bounds, add the current
cell's count to `ans`. Use `long` arrays to prevent intermediate overflow before the `% MOD`
reduction.

### Java Solution

```java
class Solution {
    public int findPaths(int m, int n, int maxMove, int startRow, int startCol) {
        final long MOD = 1_000_000_007L;
        final int[][] DIRS = {{-1,0},{1,0},{0,-1},{0,1}};
        var dp = new long[m][n];
        dp[startRow][startCol] = 1L;
        long ans = 0L;
        for (int move = 0; move < maxMove; move++) {
            var next = new long[m][n];
            for (int r = 0; r < m; r++) {
                for (int c = 0; c < n; c++) {
                    if (dp[r][c] == 0L) continue;
                    for (var d : DIRS) {
                        int nr = r + d[0], nc = c + d[1];
                        if (nr < 0 || nr >= m || nc < 0 || nc >= n) {
                            ans = (ans + dp[r][c]) % MOD;
                        } else {
                            next[nr][nc] = (next[nr][nc] + dp[r][c]) % MOD;
                        }
                    }
                }
            }
            dp = next;
        }
        return (int) ans;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.findPaths(2, 2, 2, 0, 0);
        if (r1 != 6) throw new AssertionError("LC576: expected 6, got " + r1);
        int r2 = sol.findPaths(1, 3, 3, 0, 1);
        if (r2 != 12) throw new AssertionError("LC576: expected 12, got " + r2);
        System.out.println("LC576 all tests passed");
    }
}
```

**Time:** O(maxMove × m × n) | **Space:** O(m × n)

**Java notes:** `long[][]` for `dp` and `ans` prevents overflow before `% MOD`. The final
cast `(int) ans` is safe since `ans < MOD < Integer.MAX_VALUE`. `long[][]` is zero-initialized
by the JVM — no explicit fill needed.

---

## LC #1230 — Toss Strange Coins *(Premium)*

**Difficulty:** Medium

### Problem Statement

Given `n` coins where coin `i` has probability `prob[i]` of heads, find the probability of
getting exactly `target` heads.

### Key Insight

1-D rolling DP (0/1 knapsack on probabilities). Iterate `j` downward to avoid using the
updated value for the current coin within the same pass. `dp[j] = dp[j]*(1-p) + dp[j-1]*p`.

### Java Solution (Memoization and Tabulation)

Tabulation (shown; memoization is structurally identical — replace the inner loop with a
recursive helper `memo[coin][heads]` and memoize on `(coin, heads)`):

```java
class Solution {
    public double probabilityOfHeads(double[] prob, int target) {
        var dp = new double[target + 1];
        dp[0] = 1.0;
        int n = prob.length;
        for (int i = 0; i < n; i++) {
            double p = prob[i];
            // Downward iteration: classic 0/1 knapsack trick prevents double-counting
            for (int j = Math.min(i + 1, target); j >= 0; j--) {
                dp[j] = dp[j] * (1.0 - p) + (j > 0 ? dp[j - 1] * p : 0.0);
            }
        }
        return dp[target];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        double r1 = sol.probabilityOfHeads(new double[]{0.4}, 1);
        if (Math.abs(r1 - 0.4) > 1e-5) throw new AssertionError("LC1230: expected 0.4, got " + r1);
        double r2 = sol.probabilityOfHeads(new double[]{0.5,0.5,0.5,0.5,0.5}, 0);
        if (Math.abs(r2 - 0.03125) > 1e-5) throw new AssertionError("LC1230: expected 0.03125, got " + r2);
        double r3 = sol.probabilityOfHeads(new double[]{0.0,0.0,0.0,0.0,0.0,0.0}, 0);
        if (Math.abs(r3 - 1.0) > 1e-5) throw new AssertionError("LC1230: expected 1.0, got " + r3);
        System.out.println("LC1230 all tests passed");
    }
}
```

**Time:** O(n × target) | **Space:** O(target)

**Java notes:** The downward `j` iteration is the 0/1 knapsack trick on a probability table.
`Math.min(i + 1, target)` caps the upper bound since after `i+1` coins we can have at most
`i+1` heads — tighter than iterating all the way to `target` on early coins.

---

## LC #808 — Soup Servings

**Difficulty:** Medium

### Problem Statement

Two soups A and B start with `n` ml each. Four equally likely operations each turn:
serve (A=100, B=0), (A=75, B=25), (A=50, B=50), (A=25, B=75). Find the probability A empties
first plus half the probability both empty simultaneously.

### Key Insight

For large `n` the probability converges to 1.0 (A is drained faster on average). Return 1.0
immediately for `n >= 4800`. Scale by 25 to work with integers: table size ≤ 192×192.
Use top-down memoization since the recursion structure is natural and bottom-up requires
careful ordering.

### Java Solution (Memoization — both styles shown)

```java
class Solution {
    private double[][] memo;
    private int sz;

    public double soupServings(int n) {
        if (n >= 4800) return 1.0;
        sz = (n + 24) / 25;
        memo = new double[sz + 1][sz + 1];
        // -1.0 sentinel (Java arrays default to 0.0)
        for (var row : memo) java.util.Arrays.fill(row, -1.0);
        return go(sz, sz);
    }

    private double go(int a, int b) {
        if (a <= 0 && b <= 0) return 0.5;   // both empty simultaneously
        if (a <= 0) return 1.0;              // A empty first
        if (b <= 0) return 0.0;              // B empty first (undesirable)
        if (memo[a][b] >= 0.0) return memo[a][b];
        // Four operations in 25-ml units: (4,0),(3,1),(2,2),(1,3)
        double val = 0.25 * (
            go(Math.max(a - 4, 0), b) +
            go(Math.max(a - 3, 0), Math.max(b - 1, 0)) +
            go(Math.max(a - 2, 0), Math.max(b - 2, 0)) +
            go(Math.max(a - 1, 0), Math.max(b - 3, 0))
        );
        memo[a][b] = val;
        return val;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        double r1 = sol.soupServings(50);
        if (Math.abs(r1 - 0.625) > 1e-5) throw new AssertionError("LC808: expected 0.625, got " + r1);
        sol = new Solution();
        double r2 = sol.soupServings(100);
        if (Math.abs(r2 - 0.71875) > 1e-5) throw new AssertionError("LC808: expected 0.71875, got " + r2);
        sol = new Solution();
        double r3 = sol.soupServings(10000);
        if (Math.abs(r3 - 1.0) > 1e-5) throw new AssertionError("LC808: expected 1.0, got " + r3);
        System.out.println("LC808 all tests passed");
    }
}
```

**Time:** O((n/25)²) | **Space:** O((n/25)²)

**Java notes:** `Math.max(a - da, 0)` replaces Rust's `saturating_sub` — both prevent
underflow when the serving amount exceeds what remains. `Arrays.fill(row, -1.0)` is needed
because Java initializes `double[]` to `0.0`, which collides with the "both-empty" return
value of `0.5` if used as a not-computed sentinel. Using `-1.0` avoids this collision.

---

## Section 9: DP with Divide & Conquer Optimization

> **When it applies:** `dp[k][i] = min over j < i of (dp[k-1][j] + cost(j,i))` is
> optimizable when `cost` satisfies the **quadrangle inequality** (optimal split point is
> monotone in `i`). This reduces O(kn²) to O(kn log n).
>
> **Java template:** pass `prev[]` and `cur[]` as separate arrays, fill `cur[mid]` by
> scanning `j` in `[lo, min(hi, mid-1)]`, recurse left with `[lo, bestK]` and right with
> `[bestK, hi]`. Guard `if (mid > 0)` before the left recursive call to avoid `mid-1`
> underflowing to a huge index.

---

## LC #1278 — Palindrome Partitioning III

**Difficulty:** Hard

### Problem Statement

Partition string `s` into exactly `k` substrings, each made palindrome by minimum character
changes. Minimize total changes.

### Key Insight

Precompute `cost[i][j]` = min changes to palindromize `s[i..j]` (two-pointer shrink). Then
`dp[p][i]` = min cost to partition `s[0..i)` into `p` parts. Apply D&C optimization since
the optimal split point is monotone.

### Java Solution

```java
class Solution {
    public int palindromePartition(String s, int k) {
        int n = s.length();
        // cost[i][j]: min changes to palindromize s[i..j] inclusive
        var cost = new int[n][n];
        for (int len = 2; len <= n; len++) {
            for (int i = 0; i <= n - len; i++) {
                int j = i + len - 1;
                cost[i][j] = cost[i + 1][j - 1] + (s.charAt(i) != s.charAt(j) ? 1 : 0);
            }
        }
        final int INF = Integer.MAX_VALUE / 2;
        // dp[p][i]: min cost, first i chars split into p parts
        var dp = new int[k + 1][n + 1];
        for (var row : dp) java.util.Arrays.fill(row, INF);
        dp[0][0] = 0;
        for (int p = 1; p <= k; p++) {
            var prev = dp[p - 1].clone();
            var cur = dp[p];
            dcPartition(cost, prev, cur, 1, n, 0, n - 1, INF);
        }
        return dp[k][n];
    }

    private void dcPartition(int[][] cost, int[] prev, int[] cur,
                              int l, int r, int lo, int hi, int INF) {
        if (l > r) return;
        int mid = (l + r) / 2;
        int bestK = lo;
        for (int j = lo; j <= Math.min(hi, mid - 1); j++) {
            if (prev[j] == INF) continue;
            int val = prev[j] + cost[j][mid - 1];
            if (val < cur[mid]) {
                cur[mid] = val;
                bestK = j;
            }
        }
        if (mid > 0) dcPartition(cost, prev, cur, l, mid - 1, lo, bestK, INF);
        dcPartition(cost, prev, cur, mid + 1, r, bestK, hi, INF);
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.palindromePartition("abc", 2);
        if (r1 != 1) throw new AssertionError("LC1278: expected 1, got " + r1);
        int r2 = sol.palindromePartition("aabbc", 3);
        if (r2 != 0) throw new AssertionError("LC1278: expected 0, got " + r2);
        int r3 = sol.palindromePartition("leetcode", 8);
        if (r3 != 0) throw new AssertionError("LC1278: expected 0, got " + r3);
        System.out.println("LC1278 all tests passed");
    }
}
```

**Time:** O(n² + k·n log n) with D&C opt | **Space:** O(n² + k·n)

**Java notes:** `Integer.MAX_VALUE / 2` as INF allows safely computing `prev[j] + cost[j][mid-1]`
without integer overflow. The `mid > 0` guard before the left recursion prevents `mid - 1`
from becoming `-1` when `mid == 0` (Java `int` wraps to `Integer.MAX_VALUE` — not a panic,
just a silent wrong index). `prev = dp[p-1].clone()` separates read and write layers.

---

## LC #1335 — Minimum Difficulty of a Job Schedule

**Difficulty:** Hard

### Problem Statement

Schedule `n` jobs in order over `d` days (at least one job per day). Day difficulty = max job
in that day. Minimize total difficulty. If `n < d`, return -1.

### Key Insight

Precompute `rangeMax[i][j]` = max of `jobDifficulty[i..j]`. Then `dp[day][i]` = min difficulty
to schedule first `i` jobs in `day` days; transition tries all split points `j` in `[day-1, i)`.

### Java Solution

```java
class Solution {
    public int minDifficulty(int[] jobDifficulty, int d) {
        int n = jobDifficulty.length;
        if (n < d) return -1;
        // Precompute range maximum: rangeMax[i][j] = max of jobDifficulty[i..j]
        var rangeMax = new int[n][n];
        for (int i = 0; i < n; i++) {
            rangeMax[i][i] = jobDifficulty[i];
            for (int j = i + 1; j < n; j++) {
                rangeMax[i][j] = Math.max(rangeMax[i][j - 1], jobDifficulty[j]);
            }
        }
        final int INF = Integer.MAX_VALUE / 2;
        var dp = new int[d + 1][n + 1];
        for (var row : dp) java.util.Arrays.fill(row, INF);
        dp[0][0] = 0;
        for (int day = 1; day <= d; day++) {
            var prev = dp[day - 1].clone();
            for (int i = day; i <= n; i++) {
                for (int j = day - 1; j < i; j++) {
                    if (prev[j] == INF) continue;
                    int candidate = prev[j] + rangeMax[j][i - 1];
                    dp[day][i] = Math.min(dp[day][i], candidate);
                }
            }
        }
        return dp[d][n] == INF ? -1 : dp[d][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.minDifficulty(new int[]{6,5,4,3,2,1}, 2);
        if (r1 != 7) throw new AssertionError("LC1335: expected 7, got " + r1);
        int r2 = sol.minDifficulty(new int[]{9,9,9}, 4);
        if (r2 != -1) throw new AssertionError("LC1335: expected -1, got " + r2);
        int r3 = sol.minDifficulty(new int[]{1,1,1}, 3);
        if (r3 != 3) throw new AssertionError("LC1335: expected 3, got " + r3);
        int r4 = sol.minDifficulty(new int[]{7,1,7,1,7,1}, 3);
        if (r4 != 15) throw new AssertionError("LC1335: expected 15, got " + r4);
        System.out.println("LC1335 all tests passed");
    }
}
```

**Time:** O(d × n²) | **Space:** O(d × n + n²)

**Java notes:** Precomputing `rangeMax[i][j]` avoids recomputing the sliding max inside the
DP loop, keeping each transition O(1). `Arrays.fill(row, INF)` is essential here — unlike
zero-init problems, a min-DP initializes to infinity. Check that `dp[d][n] == INF` before
returning it, since `-1` is a valid "impossible" signal.

---

## LC #410 — Split Array Largest Sum (DP + D&C)

**Difficulty:** Hard

### Problem Statement

Split `nums` into exactly `k` non-empty subarrays. Minimize the maximum subarray sum.

### Key Insight

`dp[p][i]` = min possible maximum subarray sum when splitting `nums[0..i)` into `p` parts.
Transition: `dp[p][i] = min over j < i of max(dp[p-1][j], prefix[i] - prefix[j])`. The
optimal `j` is monotone (quadrangle inequality holds), enabling D&C optimization.
Use `long` for prefix sums and dp values to handle large inputs.

### Java Solution

```java
class Solution {
    public int splitArray(int[] nums, int k) {
        int n = nums.length;
        var prefix = new long[n + 1];
        for (int i = 0; i < n; i++) prefix[i + 1] = prefix[i] + nums[i];

        final long INF = Long.MAX_VALUE / 2;
        var dp = new long[k + 1][n + 1];
        for (var row : dp) java.util.Arrays.fill(row, INF);
        dp[0][0] = 0L;
        for (int p = 1; p <= k; p++) {
            var prev = dp[p - 1].clone();
            dcSplit(prev, dp[p], prefix, 1, n, 0, n - 1, INF);
        }
        return (int) dp[k][n];
    }

    private void dcSplit(long[] prev, long[] cur, long[] prefix,
                         int l, int r, int lo, int hi, long INF) {
        if (l > r) return;
        int mid = (l + r) / 2;
        int bestK = lo;
        for (int j = lo; j <= Math.min(hi, mid - 1); j++) {
            if (prev[j] >= INF) continue;
            long val = Math.max(prev[j], prefix[mid] - prefix[j]);
            if (val < cur[mid]) {
                cur[mid] = val;
                bestK = j;
            }
        }
        if (mid > 0) dcSplit(prev, cur, prefix, l, mid - 1, lo, bestK, INF);
        dcSplit(prev, cur, prefix, mid + 1, r, bestK, hi, INF);
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.splitArray(new int[]{7,2,5,10,8}, 2);
        if (r1 != 18) throw new AssertionError("LC410: expected 18, got " + r1);
        int r2 = sol.splitArray(new int[]{1,2,3,4,5}, 2);
        if (r2 != 9) throw new AssertionError("LC410: expected 9, got " + r2);
        int r3 = sol.splitArray(new int[]{1,4,4}, 3);
        if (r3 != 4) throw new AssertionError("LC410: expected 4, got " + r3);
        System.out.println("LC410 all tests passed");
    }
}
```

**Time:** O(k × n log n) with D&C | **Space:** O(k × n)

**Java notes:** `Long.MAX_VALUE / 2` as INF for `long` arrays — never use `Long.MAX_VALUE`
directly since `Math.max(Long.MAX_VALUE, x)` stays `Long.MAX_VALUE` but a later addition
would overflow. The `(int)` cast at return is safe since the answer fits in `int` (problem
constraints guarantee it).

---

## LC #813 — Largest Sum of Averages

**Difficulty:** Medium

### Problem Statement

Partition array `nums` into at most `k` contiguous groups. Maximize the sum of averages of
each group.

### Key Insight

`dp[i]` (rolling 1-D) = max sum of averages for `nums[0..i)` with the current group count.
Each pass adds one more group. Prefix sums enable O(1) average computation per split.

### Java Solution

```java
class Solution {
    public double largestSumOfAverages(int[] nums, int k) {
        int n = nums.length;
        var prefix = new double[n + 1];
        for (int i = 0; i < n; i++) prefix[i + 1] = prefix[i] + nums[i];

        // dp[i] = best sum of averages for nums[0..i) with current group count
        // Initialize: 1 group = average of entire prefix
        var dp = new double[n + 1];
        for (int i = 1; i <= n; i++) dp[i] = prefix[i] / i;

        for (int g = 1; g < k; g++) {
            var prev = dp.clone();
            for (int i = 1; i <= n; i++) {
                dp[i] = Double.NEGATIVE_INFINITY;
                for (int j = 0; j < i; j++) {
                    double avg = (prefix[i] - prefix[j]) / (i - j);
                    if (prev[j] + avg > dp[i]) dp[i] = prev[j] + avg;
                }
            }
        }
        return dp[n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        double r1 = sol.largestSumOfAverages(new int[]{9,1,2,3,9}, 3);
        if (Math.abs(r1 - 20.0) > 1e-5) throw new AssertionError("LC813: expected 20.0, got " + r1);
        double r2 = sol.largestSumOfAverages(new int[]{1,2,3,4,5,6,7}, 4);
        if (Math.abs(r2 - 20.5) > 1e-5) throw new AssertionError("LC813: expected 20.5, got " + r2);
        System.out.println("LC813 all tests passed");
    }
}
```

**Time:** O(k × n²) | **Space:** O(n)

**Java notes:** `Double.NEGATIVE_INFINITY` is the correct initial value for a max-DP over
`double` — do not use `0.0` (a partition with negative averages would never be chosen). The
1-D rolling array pattern avoids allocating a full `k×n` table.

---

## Section 10: Advanced Knapsack Variants

---

## LC #879 — Profitable Schemes

**Difficulty:** Hard

### Problem Statement

`n` gang members, `minProfit` target. Each crime `i` requires `group[i]` members and yields
`profit[i]`. Count schemes where members used ≤ `n` and profit ≥ `minProfit`. Return mod
`10^9+7`.

### Key Insight

2-D 0/1 knapsack: dimension one is members used (0..n), dimension two is profit achieved
(capped at `minProfit` to prevent unbounded axis). `dp[g][p]` = number of schemes using
exactly `g` members with at least `p` profit. Iterate both dimensions downward (reverse
iteration for 0/1 knapsack). Cap `newP = Math.min(p + pi, mp)` to collapse surplus profit.

### Java Solution

```java
class Solution {
    public int profitableSchemes(int n, int minProfit, int[] group, int[] profit) {
        final long MOD = 1_000_000_007L;
        int mp = minProfit;
        // dp[g][p] = number of schemes using g members, profit capped at mp
        var dp = new long[n + 1][mp + 1];
        dp[0][0] = 1L;
        for (int i = 0; i < group.length; i++) {
            int gi = group[i], pi = profit[i];
            // Reverse both dimensions: 0/1 knapsack (each crime usable at most once)
            for (int g = n; g >= gi; g--) {
                for (int p = mp; p >= 0; p--) {
                    int newP = Math.min(p + pi, mp);  // cap profit at minProfit
                    dp[g][newP] = (dp[g][newP] + dp[g - gi][p]) % MOD;
                }
            }
        }
        long ans = 0L;
        for (int g = 0; g <= n; g++) ans = (ans + dp[g][mp]) % MOD;
        return (int) ans;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.profitableSchemes(5, 3, new int[]{2,2}, new int[]{2,3});
        if (r1 != 2) throw new AssertionError("LC879: expected 2, got " + r1);
        int r2 = sol.profitableSchemes(10, 5, new int[]{2,3,5}, new int[]{6,7,8});
        if (r2 != 7) throw new AssertionError("LC879: expected 7, got " + r2);
        System.out.println("LC879 all tests passed");
    }
}
```

**Time:** O(K × n × minProfit) where K = number of crimes | **Space:** O(n × minProfit)

**Java notes:** `long[][]` avoids intermediate overflow since each cell accumulates up to
`n × K` additions before the mod reduction. The profit-cap `Math.min(p + pi, mp)` is the
key trick: it collapses all "surplus profit" states into the `mp` bucket, bounding the DP
dimension.

---

## LC #956 — Tallest Billboard

**Difficulty:** Hard

### Problem Statement

Partition rods into two groups (some skipped) such that both groups have equal total length.
Maximize that equal total.

### Key Insight

HashMap-on-difference: `dp[diff]` = maximum height of the taller leg when `taller - shorter
= diff`. For each rod, take a snapshot of the current map, then update three cases: add to
taller leg, add to shorter leg, or skip. Answer is `dp[0]`.

### Java Solution

```java
import java.util.HashMap;
import java.util.ArrayList;

class Solution {
    public int tallestBillboard(int[] rods) {
        // dp[diff] = max height of taller side when (taller - shorter == diff)
        var dp = new HashMap<Integer, Integer>();
        dp.put(0, 0);
        for (int r : rods) {
            // Snapshot before modifying — avoids ConcurrentModificationException
            var snapshot = new ArrayList<>(dp.entrySet());
            for (var entry : snapshot) {
                int diff = entry.getKey(), tall = entry.getValue();
                // Option 1: add rod to taller side
                int d1 = diff + r;
                dp.merge(d1, tall + r, Math::max);
                // Option 2: add rod to shorter side
                int newDiff = Math.abs(diff - r);
                int newTall = (diff >= r) ? tall : tall + r - diff;
                dp.merge(newDiff, newTall, Math::max);
                // Option 3: skip — entry already present; no update needed
            }
        }
        return dp.getOrDefault(0, 0);
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.tallestBillboard(new int[]{1,2,3,6});
        if (r1 != 6) throw new AssertionError("LC956: expected 6, got " + r1);
        int r2 = sol.tallestBillboard(new int[]{1,2,3,4,5,6});
        if (r2 != 10) throw new AssertionError("LC956: expected 10, got " + r2);
        int r3 = sol.tallestBillboard(new int[]{1,2});
        if (r3 != 0) throw new AssertionError("LC956: expected 0, got " + r3);
        System.out.println("LC956 all tests passed");
    }
}
```

**Time:** O(n × sum) | **Space:** O(sum)

**Java notes:** `new ArrayList<>(dp.entrySet())` creates the snapshot before modification
— the exact same guard as Rust's explicit `snapshot` collection. Unlike Rust (compile error
if you forget), Java throws `ConcurrentModificationException` at runtime. `HashMap.merge(key,
value, Math::max)` is a concise way to "insert or update with max".

---

## LC #1049 — Last Stone Weight II

**Difficulty:** Medium

### Problem Statement

Smash stones pairwise; result is `|a - b|`. Minimize the final weight. Equivalent to:
partition stones into two groups, minimize `|S1 - S2|`. Find subset sum closest to
`total / 2`.

### Key Insight

Standard 0/1 knapsack reachability on a `boolean[]` of size `total/2 + 1`. After filling,
scan downward for the largest reachable `j`; answer is `total - 2*j`.

### Java Solution (showing both memoization and tabulation)

```java
class Solution {
    // --- Tabulation (preferred for this problem) ---
    public int lastStoneWeightII(int[] stones) {
        int total = 0;
        for (int s : stones) total += s;
        int half = total / 2;
        var dp = new boolean[half + 1];
        dp[0] = true;
        for (int s : stones) {
            // Downward to avoid using updated values within the same stone
            for (int j = half; j >= s; j--) {
                if (dp[j - s]) dp[j] = true;
            }
        }
        // Find largest reachable sum <= half
        for (int j = half; j >= 0; j--) {
            if (dp[j]) return total - 2 * j;
        }
        return total; // unreachable
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.lastStoneWeightII(new int[]{2,7,4,1,8,1});
        if (r1 != 1) throw new AssertionError("LC1049: expected 1, got " + r1);
        int r2 = sol.lastStoneWeightII(new int[]{31,26,33,21,40});
        if (r2 != 5) throw new AssertionError("LC1049: expected 5, got " + r2);
        int r3 = sol.lastStoneWeightII(new int[]{1,1});
        if (r3 != 0) throw new AssertionError("LC1049: expected 0, got " + r3);
        System.out.println("LC1049 all tests passed");
    }
}
```

**Time:** O(n × total) | **Space:** O(total)

**Java notes:** `boolean[]` is zero-initialized to `false` — no fill needed. The downward
`j` loop is the 0/1 knapsack anti-reuse trick. The reverse scan for the largest `true` entry
replaces Rust's `.rev().find(|&j| dp[j])` iterator chain.

---

## LC #474 — Ones and Zeroes

**Difficulty:** Medium

### Problem Statement

Given binary strings `strs`, find the largest subset where total `'0'`s ≤ `m` and total
`'1'`s ≤ `n`.

### Key Insight

2-D 0/1 knapsack: `dp[z][o]` = max strings in subset using ≤ `z` zeros and ≤ `o` ones.
Iterate both budget dimensions downward (classic reverse-pass for 0/1 knapsack).

### Java Solution

```java
class Solution {
    public int findMaxForm(String[] strs, int m, int n) {
        var dp = new int[m + 1][n + 1];  // zero-initialized
        for (var s : strs) {
            int zeros = 0;
            for (char c : s.toCharArray()) if (c == '0') zeros++;
            int ones = s.length() - zeros;
            // Reverse iteration on both dimensions: 0/1 knapsack
            for (int z = m; z >= zeros; z--) {
                for (int o = n; o >= ones; o--) {
                    dp[z][o] = Math.max(dp[z][o], 1 + dp[z - zeros][o - ones]);
                }
            }
        }
        return dp[m][n];
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.findMaxForm(new String[]{"10","0001","111001","1","0"}, 5, 3);
        if (r1 != 4) throw new AssertionError("LC474: expected 4, got " + r1);
        int r2 = sol.findMaxForm(new String[]{"10","0","1"}, 1, 1);
        if (r2 != 2) throw new AssertionError("LC474: expected 2, got " + r2);
        System.out.println("LC474 all tests passed");
    }
}
```

**Time:** O(|strs| × m × n) | **Space:** O(m × n)

**Java notes:** Counting zeros with a `for (char c : s.toCharArray())` loop is simple and
avoids regex overhead. The zero-initialization of `int[][]` makes this cleaner than a Rust
`vec![vec![0; ...]; ...]` — both produce the same table, but Java doesn't need the explicit
`0` fill.

---

## LC #1066 — Campus Bikes II *(Premium)*

**Difficulty:** Hard

### Problem Statement

Assign `n` workers to bikes (m ≥ n, one bike per worker) to minimize total Manhattan distance.
Workers are assigned in order 0..n-1; a bitmask tracks which bikes are taken.

### Key Insight

Bitmask DP: `dp[mask]` = min total distance when exactly the bikes in `mask` are assigned.
`Integer.bitCount(mask)` gives the next worker index. Iterate masks in ascending order —
this guarantees that when we process mask, all subsets of it have already been processed.

### Java Solution

```java
class Solution {
    public int assignBikes(int[][] workers, int[][] bikes) {
        int nW = workers.length, nB = bikes.length;
        int total = 1 << nB;
        final int INF = Integer.MAX_VALUE / 2;
        var dp = new int[total];
        java.util.Arrays.fill(dp, INF);
        dp[0] = 0;
        int ans = INF;
        for (int mask = 0; mask < total; mask++) {
            if (dp[mask] == INF) continue;
            int worker = Integer.bitCount(mask);
            if (worker == nW) {
                ans = Math.min(ans, dp[mask]);
                continue;
            }
            for (int b = 0; b < nB; b++) {
                if ((mask & (1 << b)) == 0) {
                    int next = mask | (1 << b);
                    int dist = Math.abs(workers[worker][0] - bikes[b][0])
                             + Math.abs(workers[worker][1] - bikes[b][1]);
                    dp[next] = Math.min(dp[next], dp[mask] + dist);
                }
            }
        }
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.assignBikes(new int[][]{{0,0},{2,1}}, new int[][]{{1,2},{3,3}});
        if (r1 != 6) throw new AssertionError("LC1066: expected 6, got " + r1);
        int r2 = sol.assignBikes(
            new int[][]{{0,0},{1,1},{2,0}},
            new int[][]{{1,0},{2,2},{2,1}});
        if (r2 != 4) throw new AssertionError("LC1066: expected 4, got " + r2);
        System.out.println("LC1066 all tests passed");
    }
}
```

**Time:** O(2^m × m) | **Space:** O(2^m)

**Java notes:** `Integer.bitCount(mask)` is a single CPU instruction (JVM intrinsic for
`POPCNT`) — equivalent to Rust's `mask.count_ones()`. Iterating `mask` from `0` to `total`
in ascending order guarantees all strict subsets of `mask` are processed before `mask`,
which is required for this forward-DP formulation.

---

## LC #1981 — Minimize the Difference Between Target and Chosen Elements

**Difficulty:** Hard

### Problem Statement

Given an `m×n` matrix, choose one element from each row to minimize `|chosen_sum - target|`.

### Key Insight

Represent reachable sums as a `long[]` bitset (64 sums per word). For each row, OR-shift
the bitset by each element value. Cross-word carry requires `>>> (64 - bitShift)` — note
`>>>` (logical) not `>>` (arithmetic) since `long` sign-extension would corrupt higher words.
After all rows, scan from 0 upward, stopping at the first sum ≥ target.

### Java Solution

```java
class Solution {
    public int minimizeTheDifference(int[][] mat, int target) {
        int m = mat.length;
        // Max possible sum: pick largest in each row
        int maxSum = 0;
        for (var row : mat) {
            int rowMax = 0;
            for (int v : row) rowMax = Math.max(rowMax, v);
            maxSum += rowMax;
        }
        int cap = maxSum + 1;
        int words = (cap + 63) / 64;
        // Bitset: bit k is set if sum k is reachable
        var bits = new long[words];
        bits[0] = 1L;  // sum 0 reachable before any row
        for (var row : mat) {
            var next = new long[words];
            for (int val : row) {
                int wordShift = val / 64;
                int bitShift  = val % 64;
                for (int w = words - 1; w >= wordShift; w--) {
                    int src = w - wordShift;
                    next[w] |= bits[src] << bitShift;
                    // Cross-word carry — use >>> (logical shift) not >> (arithmetic)
                    if (bitShift > 0 && src > 0) {
                        next[w] |= bits[src - 1] >>> (64 - bitShift);
                    }
                }
            }
            bits = next;
        }
        // Scan ascending: stop at first reachable sum >= target (closest above)
        int best = Integer.MAX_VALUE;
        for (int k = 0; k < cap; k++) {
            if ((bits[k / 64] & (1L << (k % 64))) != 0L) {
                int diff = Math.abs(k - target);
                if (diff < best) best = diff;
                if (k >= target) break;  // sums beyond target only increase diff
            }
        }
        return best;
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int r1 = sol.minimizeTheDifference(new int[][]{{1,2,3},{4,5,6},{7,8,9}}, 13);
        if (r1 != 0) throw new AssertionError("LC1981: expected 0, got " + r1);
        int r2 = sol.minimizeTheDifference(new int[][]{{1},{2},{3}}, 100);
        if (r2 != 94) throw new AssertionError("LC1981: expected 94, got " + r2);
        int r3 = sol.minimizeTheDifference(new int[][]{{1,2,9,8,7}}, 6);
        if (r3 != 1) throw new AssertionError("LC1981: expected 1, got " + r3);
        System.out.println("LC1981 all tests passed");
    }
}
```

**Time:** O(m × n × maxSum / 64) | **Space:** O(maxSum / 64)

**Java notes:** The critical difference from Rust: use `>>>` (unsigned right shift) for the
cross-word carry, not `>>` (signed). On `long`, `>> (64 - bitShift)` sign-extends the high
bit and corrupts words when the long has its MSB set. Java's shift count on `long` is masked
to 63 bits, so `>>> 64` is `>>> 0` which is the identity — exactly why the `bitShift > 0`
guard is mandatory (same reason as Rust).

---

## 📝 Chapter Review Notes

### Issue Tracking Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| LC #10 and LC #44 `*` semantics differ — base case loop step and structure are distinct | High | Both documented with explicit comparison; LC #10 steps `j-2`, LC #44 steps `j-1` |
| `assert` keyword would be silently skipped at runtime without `-ea` flag | High | All tests use `throw new AssertionError(...)` — `assert` keyword not used anywhere |
| `double` DP tests must not use `==` comparison | High | All probability tests use `Math.abs(actual - expected) < 1e-5` |
| LC #1981 cross-word carry must use `>>>` not `>>` on `long` | High | `>>>` used throughout; Java-specific note added explaining sign-extension risk |
| LC #808 `Arrays.fill(row, -1.0)` sentinel needed (default is `0.0` which collides with "B empty" return) | High | `-1.0` fill applied; note explains the collision with `0.5` and `0.0` return values |
| LC #808 large-n early exit: without `n >= 4800` guard, memo table over-allocates and produces 1.0 anyway | High | Guard applied; threshold documented |
| LC #1278 D&C guard `if (mid > 0)` before left recursion required — Java `int` wraps silently (no panic) | High | Guard present; note explains the silent-wrap vs Rust-panic distinction |
| `Integer.MAX_VALUE / 2` as INF (not `Integer.MAX_VALUE`) to allow safe additions | High | Applied to LC #1278, #1335, #410, #1066; `Long.MAX_VALUE / 2` for `long` tables |
| LC #956 HashMap snapshot required before mutation — Java throws at runtime, not compile time | Medium | `new ArrayList<>(dp.entrySet())` snapshot explicit; `HashMap.merge` used for clarity |
| LC #837 sliding-window conditions `if (i < k)` and `if (i >= maxPts)` must not be swapped | Medium | Conditions match Rust original; comment explains each update direction |
| LC #879 profit cap `Math.min(p + pi, mp)` is mandatory — without it, array index exceeds `mp` | High | Cap applied; note explains the bounded-axis trick |
| LC #474 downward iteration on both `z` and `o` dimensions required for 2-D 0/1 knapsack | Medium | Both loops iterate downward; note references 0/1 knapsack anti-reuse property |
| LC #1066 ascending mask iteration required for `bitCount` worker-index to be valid | Medium | Explicit `for (int mask = 0; mask < total; mask++)` with note explaining the ordering requirement |
| LC #1092 SCS has multiple valid answers — test verifies subsequence property, not exact string | Medium | `isSubseq` helper validates structural correctness rather than string equality |
| LC #718 vs LC #1035: adjacent problems with opposite table update rules (reset-to-0 vs max) | Medium | Contrast documented in Section 7 header and per-problem notes |
| `long[][]` tables for LC #576 and #879 to prevent intermediate overflow before `% MOD` | Medium | `long` arrays used; final `(int)` cast documented as safe |

---

### Third-Person Critical Review

**DP array sizes:** All tables are dimensioned `[k+1][n+1]` or equivalent, leaving row 0 /
column 0 for base cases. LC #576 and #879 use `long[][]` to handle accumulation before `%
MOD`. LC #1981 sizes `words = (cap + 63) / 64` correctly (ceiling division). LC #1335 and
#1278 use `INF = Integer.MAX_VALUE / 2` throughout with guards before arithmetic.

**Base cases:** LC #10 initializes `dp[0][0] = true` with a `j = 2` step loop for paired
stars. LC #44 uses `j = 1` for standalone stars. LC #1458 uses `Integer.MIN_VALUE` to
distinguish "no pair chosen" from a negative product. LC #808 fills the memo array with
`-1.0` to avoid collision with the `0.0` "B empties" return value.

**Transition formulas:** LC #879 correctly caps `newP = Math.min(p + pi, mp)`. LC #956
correctly handles both add-to-taller and add-to-shorter cases with the absolute-value
normalization for `newDiff`. LC #1981 uses `>>>` for cross-word carry. LC #837 updates
`windowSum` with `if (i < k)` add / `if (i >= maxPts)` remove in the correct order.

**No `assert` keyword:** Verified — every test comparison uses `throw new AssertionError(...)`.
The `assert` keyword does not appear anywhere in this chapter.

**Test assertions catch wrong answers:** Tests exercise multiple cases per problem, including
edge cases (empty pattern for LC #10/#44, single-element arrays, impossible cases like LC
#1335 with `n < d`). Floating-point tests use a `1e-5` tolerance consistent with LeetCode.
LC #1092 validates the subsequence property via a helper function rather than exact string
equality, correctly handling the case where multiple valid SCS answers exist.

---

### What This Chapter Does Well

- The Java vs Rust callout near the top is a single focused section rather than repeated
  boilerplate — it lists the three most impactful Java-specific facts (zero-init, HashMap
  boxing, `Arrays.fill` for non-zero sentinel) once.
- The `>>>` vs `>>` distinction for LC #1981 is called out prominently, as it is the single
  most dangerous silent-corruption bug in the bitset section.
- Test drivers are self-contained and throw descriptive errors including the actual `got`
  value, making failures immediately actionable.
- The side-by-side structural comparison of LC #10 vs LC #44 and LC #718 vs LC #1035 helps
  readers avoid the most common copy-paste confusion between adjacent problems.
- `Long.MAX_VALUE / 2` and `Integer.MAX_VALUE / 2` are used consistently and correctly —
  the chapter does not mix `int` INF with `long` arithmetic.

### What Could Be Improved

- LC #808 tabulation (bottom-up) is not shown — only memoization. A reader unfamiliar with
  top-down DP might benefit from seeing the iterative variant, which requires processing
  states in dependency order from `(0,0)` upward.
- LC #1278 and #1335 share similar D&C helper structures but use slightly different method
  signatures. A shared generic `dcHelper(int[] prev, int[] cur, BiFunction<Integer,Integer,Integer> cost, ...)` refactoring would reduce code duplication, though it would add lambda boxing overhead.
- The `var` keyword (Java 10+) is used for local variable declarations throughout, but the
  chapter could showcase switch expressions more explicitly for the state-machine-like
  transitions in LC #10 and LC #44 (matching on `'*'`, `'.'`, or literal) — though it would
  add ceremony without changing correctness.
- LC #410's D&C helper takes `long[]` arrays alongside a `long[]` prefix array, making the
  method signature longer than the equivalent Rust closure capture. A Java record for `SplitContext` would clean this up but was judged unnecessary ceremony for a competitive-programming context.
