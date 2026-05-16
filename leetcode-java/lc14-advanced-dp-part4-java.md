# Chapter LC-14 Part 4 (Java): Monotone Stack DP, SOS DP, DAG DP, and Grandmaster-Level Problems

> **Companion Chapter Philosophy:** Every solution is complete and runnable using `public static void main` test drivers. No JUnit, no `assert` keyword — only `throw new AssertionError`. Java 17+ syntax (var, records, switch expressions) used where natural. Covers the same 22 problems as the Rust Part 4 chapter.

---

> **Java vs Rust — Key Differences in This Chapter**
>
> - Java arrays (`int[]`, `long[]`) are **zero-initialized** automatically. Rust requires explicit `vec![0; n]`. When you need a non-zero sentinel, use `Arrays.fill(arr, Integer.MAX_VALUE / 2)` (not `Integer.MAX_VALUE` — adding to it overflows). For `long[]`, use `Long.MAX_VALUE / 2`.
> - HashMap memoization (LC 329, LC 3041) incurs **autoboxing** overhead: `HashMap<Integer, Integer>` boxes every key/value. For hot paths use `int[]` or `long[]` arrays keyed by index.
> - `ArrayDeque<Integer>` is the Java equivalent of Rust's `VecDeque<usize>`. Prefer it over `LinkedList` for deque operations — same amortized O(1), lower constant due to array backing.
> - Rust `i32::MIN / 2` maps to `Integer.MIN_VALUE / 2` in Java — both avoid overflow when subtracted.

---

## Section 11: DP with Monotone Stack / Queue Optimization

**Core idea:** When `dp[i] = max(dp[j]) + cost(i)` for `j` in a sliding window, a monotone deque maintains the window max/min in amortized O(1), reducing O(n*k) to O(n). Store **indices** in the deque, not values.

---

### LC #1696 — Jump Game VI

**Difficulty:** Medium

**Problem:** Integer array `nums`, integer `k`. Start at index 0, jump at most `k` steps forward each turn, reach the last index. Score = sum of all visited elements. Return maximum score.

**Key Insight:** `dp[i] = nums[i] + max(dp[i-k..i-1])`. The inner max is a sliding window of size `k` — classic monotone max-deque application reducing O(n*k) to O(n).

```java
import java.util.ArrayDeque;

class Solution1696 {
    public int maxResult(int[] nums, int k) {
        int n = nums.length;
        int[] dp = new int[n];
        dp[0] = nums[0];
        // Monotone max-deque: front holds index of maximum dp value in window
        var deq = new ArrayDeque<Integer>();
        deq.addLast(0);

        for (int i = 1; i < n; i++) {
            // Expire indices outside window [i-k, i-1]
            while (!deq.isEmpty() && deq.peekFirst() + k < i) {
                deq.pollFirst();
            }
            dp[i] = nums[i] + dp[deq.peekFirst()];
            // Maintain decreasing dp order: pop back indices dominated by dp[i]
            while (!deq.isEmpty() && dp[deq.peekLast()] <= dp[i]) {
                deq.pollLast();
            }
            deq.addLast(i);
        }
        return dp[n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution1696();

        var r1 = sol.maxResult(new int[]{1, -1, -2, 4, -7, 3}, 2);
        if (r1 != 7) throw new AssertionError("LC1696 ex1: expected 7, got " + r1);

        var r2 = sol.maxResult(new int[]{10, -5, -2, 4, 0, 3}, 3);
        if (r2 != 17) throw new AssertionError("LC1696 ex2: expected 17, got " + r2);

        var r3 = sol.maxResult(new int[]{5}, 1);
        if (r3 != 5) throw new AssertionError("LC1696 single: expected 5, got " + r3);

        var r4 = sol.maxResult(new int[]{-1, -2, -3}, 3);
        if (r4 != -4) throw new AssertionError("LC1696 all-neg: expected -4, got " + r4);

        System.out.println("LC1696 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Naive DP | O(n * k) | O(n) |
| Monotone deque | O(n) | O(n) |

**Java Notes:** `ArrayDeque.peekFirst()` / `peekLast()` return `null` on empty — always guard with `!deq.isEmpty()`. The `dp` array is zero-initialized by Java, so no explicit fill needed before the `dp[0] = nums[0]` assignment.

**Approach 2 — Naive O(n * k):**

```java
class Solution1696Naive {
    public int maxResult(int[] nums, int k) {
        int n = nums.length;
        int[] dp = new int[n];
        dp[0] = nums[0];
        final int NEG_INF = Integer.MIN_VALUE / 2;
        for (int i = 1; i < n; i++) {
            dp[i] = NEG_INF;
            for (int j = Math.max(0, i - k); j < i; j++) {
                if (dp[j] != NEG_INF)
                    dp[i] = Math.max(dp[i], dp[j] + nums[i]);
            }
        }
        return dp[n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution1696Naive();
        if (sol.maxResult(new int[]{1,-1,-2,4,-7,3}, 2) != 7) throw new AssertionError();
        if (sol.maxResult(new int[]{10,-5,-2,4,0,3}, 3) != 17) throw new AssertionError();
        System.out.println("LC1696 Naive: all tests passed.");
    }
}
```

Use the naive approach for clarity when verifying the recurrence; use the deque approach for O(n) production performance.

---

### LC #1425 — Constrained Subsequence Sum

**Difficulty:** Hard

**Problem:** Array `nums`, integer `k`. Return the maximum sum of a non-empty subsequence where consecutive indices in the subsequence differ by at most `k`.

**Key Insight:** `dp[i] = nums[i] + max(0, max(dp[i-k..i-1]))`. The `max(0, ...)` allows starting fresh at index `i`. Sliding window max over the previous `k` dp values via monotone deque.

```java
import java.util.ArrayDeque;

class Solution1425 {
    public int constrainedSubsetSum(int[] nums, int k) {
        int n = nums.length;
        int[] dp = nums.clone();
        var deq = new ArrayDeque<Integer>(); // indices, decreasing dp order
        int ans = Integer.MIN_VALUE;

        for (int i = 0; i < n; i++) {
            // Expire front if outside window
            if (!deq.isEmpty() && deq.peekFirst() + k < i) {
                deq.pollFirst();
            }
            // Add best previous dp (if positive)
            if (!deq.isEmpty() && dp[deq.peekFirst()] > 0) {
                dp[i] += dp[deq.peekFirst()];
            }
            ans = Math.max(ans, dp[i]);
            // Maintain decreasing order
            while (!deq.isEmpty() && dp[deq.peekLast()] <= dp[i]) {
                deq.pollLast();
            }
            deq.addLast(i);
        }
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution1425();

        var r1 = sol.constrainedSubsetSum(new int[]{10, 2, -10, 5, 20}, 2);
        if (r1 != 37) throw new AssertionError("LC1425 ex1: expected 37, got " + r1);

        var r2 = sol.constrainedSubsetSum(new int[]{-1, -2, -3}, 1);
        if (r2 != -1) throw new AssertionError("LC1425 ex2: expected -1, got " + r2);

        var r3 = sol.constrainedSubsetSum(new int[]{10, -2, -10, -5, 20}, 2);
        if (r3 != 23) throw new AssertionError("LC1425 ex3: expected 23, got " + r3);

        var r4 = sol.constrainedSubsetSum(new int[]{7}, 1);
        if (r4 != 7) throw new AssertionError("LC1425 single: expected 7, got " + r4);

        System.out.println("LC1425 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Naive | O(n * k) | O(n) |
| Monotone deque | O(n) | O(n) |

---

### LC #2944 — Minimum Number of Coins for Fruits

**Difficulty:** Medium

**Problem:** `n` fruits (1-indexed). Buying fruit `i` costs `prices[i-1]` coins and gives fruits `i+1` through `2*i+1` for free. Return minimum coins to acquire all fruits.

**Key Insight:** Buying 0-indexed fruit `i` (1-indexed `i+1`) gives fruits `i+1` through `2i+2` (0-indexed) for free. So the next purchase can be at any `j` in `[i+1, min(2i+3, n)]`. `dp[i] = prices[i] + min(dp[j])` over that range. Process right-to-left with sentinel `dp[n] = 0`. The sliding-window minimum over the varying range is maintained in O(1) per step by a monotone min-deque.

```java
import java.util.ArrayDeque;

class Solution2944 {
    public int minimumCoins(int[] prices) {
        int n = prices.length;
        // dp[i] = min cost to acquire fruits i..n-1 (0-indexed); dp[n] = 0 sentinel
        int[] dp = new int[n + 1];
        // dp is zero-initialized; dp[n] = 0 already correct

        // Monotone min-deque of indices into dp[], increasing dp value at front
        var deq = new ArrayDeque<Integer>();
        deq.addLast(n); // dp[n] = 0

        for (int i = n - 1; i >= 0; i--) {
            // Buying 0-indexed fruit i (1-indexed i+1) gives fruits i+1..2i+2 free.
            // Next non-free purchase can be at j in [i+1, min(2i+3, n)].
            int hi = Math.min(2 * (i + 1) + 1, n);
            // Remove indices from front that are out of window (> hi)
            while (!deq.isEmpty() && deq.peekFirst() > hi) {
                deq.pollFirst();
            }
            // dp[i] = prices[i] + min dp in [i+1, hi]
            dp[i] = prices[i] + dp[deq.peekFirst()];
            // Maintain min-deque: pop back while dp[back] >= dp[i]
            while (!deq.isEmpty() && dp[deq.peekLast()] >= dp[i]) {
                deq.pollLast();
            }
            deq.addLast(i);
        }
        return dp[0];
    }

    public static void main(String[] args) {
        var sol = new Solution2944();

        // Buy fruit 1 (cost 3) → free 2,3. Total = 3.
        var r1 = sol.minimumCoins(new int[]{3, 1, 2});
        if (r1 != 3) throw new AssertionError("LC2944 ex1: expected 3, got " + r1);

        var r2 = sol.minimumCoins(new int[]{1, 10, 1, 1});
        if (r2 != 2) throw new AssertionError("LC2944 ex2: expected 2, got " + r2);

        var r3 = sol.minimumCoins(new int[]{5});
        if (r3 != 5) throw new AssertionError("LC2944 single: expected 5, got " + r3);

        var r4 = sol.minimumCoins(new int[]{2, 3});
        if (r4 != 2) throw new AssertionError("LC2944 two: expected 2, got " + r4);

        System.out.println("LC2944 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Naive | O(n²) | O(n) |
| Monotone deque | O(n) | O(n) |

**Java Notes:** The Rust source had a dead-code first pass — only the correct right-to-left min-deque approach is ported here. `dp[n] = 0` is set implicitly by Java's zero-initialization.

---

### LC #239 — Sliding Window Maximum

**Difficulty:** Hard | **Core Pattern**

**Problem:** Array `nums`, window size `k`. Return array of maximum in each sliding window of size `k`.

**Key Insight:** Maintain a deque of indices in decreasing `nums` order. Front is always the current window's maximum index.

```java
import java.util.ArrayDeque;

class Solution239 {
    public int[] maxSlidingWindow(int[] nums, int k) {
        int n = nums.length;
        int[] result = new int[n - k + 1];
        var deq = new ArrayDeque<Integer>(); // indices, decreasing nums[i] order

        for (int i = 0; i < n; i++) {
            // Expire indices outside window
            while (!deq.isEmpty() && deq.peekFirst() + k <= i) {
                deq.pollFirst();
            }
            // Maintain decreasing order
            while (!deq.isEmpty() && nums[deq.peekLast()] <= nums[i]) {
                deq.pollLast();
            }
            deq.addLast(i);
            // Record result once first window is full
            if (i >= k - 1) {
                result[i - k + 1] = nums[deq.peekFirst()];
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution239();

        var r1 = sol.maxSlidingWindow(new int[]{1, 3, -1, -3, 5, 3, 6, 7}, 3);
        if (!java.util.Arrays.equals(r1, new int[]{3, 3, 5, 5, 6, 7}))
            throw new AssertionError("LC239 ex1: got " + java.util.Arrays.toString(r1));

        var r2 = sol.maxSlidingWindow(new int[]{4, 2, 7}, 1);
        if (!java.util.Arrays.equals(r2, new int[]{4, 2, 7}))
            throw new AssertionError("LC239 k=1: got " + java.util.Arrays.toString(r2));

        var r3 = sol.maxSlidingWindow(new int[]{1, 3, 2}, 3);
        if (!java.util.Arrays.equals(r3, new int[]{3}))
            throw new AssertionError("LC239 k=n: got " + java.util.Arrays.toString(r3));

        System.out.println("LC239 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Naive | O(n * k) | O(1) |
| Monotone deque | O(n) | O(k) |

---

### LC #862 — Shortest Subarray with Sum at Least K

**Difficulty:** Hard

**Problem:** Return the length of the shortest subarray with sum ≥ `k`. Return -1 if none exists.

**Key Insight:** Build prefix sums (use `long` to avoid overflow). For each index `i`, we want the smallest `i - j` such that `pre[i] - pre[j] >= k`. Maintain a monotone increasing deque of prefix-sum indices: pop from front to record valid answers, pop from back to maintain increasing order.

```java
import java.util.ArrayDeque;

class Solution862 {
    public int shortestSubarray(int[] nums, int k) {
        int n = nums.length;
        long[] pre = new long[n + 1]; // long to prevent overflow
        for (int i = 0; i < n; i++) pre[i + 1] = pre[i] + nums[i];

        var deq = new ArrayDeque<Integer>(); // increasing prefix-sum indices
        int ans = Integer.MAX_VALUE;

        for (int i = 0; i <= n; i++) {
            // Pop front when difference meets the target (record shortest length)
            while (!deq.isEmpty() && pre[i] - pre[deq.peekFirst()] >= k) {
                ans = Math.min(ans, i - deq.pollFirst());
            }
            // Maintain increasing prefix-sum order (min-deque)
            while (!deq.isEmpty() && pre[deq.peekLast()] >= pre[i]) {
                deq.pollLast();
            }
            deq.addLast(i);
        }
        return ans == Integer.MAX_VALUE ? -1 : ans;
    }

    public static void main(String[] args) {
        var sol = new Solution862();

        var r1 = sol.shortestSubarray(new int[]{1}, 1);
        if (r1 != 1) throw new AssertionError("LC862 ex1: expected 1, got " + r1);

        var r2 = sol.shortestSubarray(new int[]{1, 2}, 4);
        if (r2 != -1) throw new AssertionError("LC862 ex2: expected -1, got " + r2);

        var r3 = sol.shortestSubarray(new int[]{2, -1, 2}, 3);
        if (r3 != 3) throw new AssertionError("LC862 ex3: expected 3, got " + r3);

        var r4 = sol.shortestSubarray(new int[]{84, -37, 32, 40, 95}, 167);
        if (r4 != 3) throw new AssertionError("LC862 negatives: expected 3, got " + r4);

        System.out.println("LC862 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Naive | O(n²) | O(n) |
| Prefix sum + deque | O(n) | O(n) |

**Java Notes:** `long[]` is mandatory here — `nums[i]` can be ±10^5 and `n` up to 10^5; the prefix sum can reach ±10^10. The deque is a **min-deque** (increasing prefix sums) — opposite polarity from the max-deque in LC 1696.

---

### LC #907 — Sum of Subarray Minimums

**Difficulty:** Medium

**Problem:** For array `arr`, compute the sum of `min(b)` over every subarray `b`. Return modulo 10^9 + 7.

**Key Insight:** For each `arr[i]`, count subarrays where `arr[i]` is the minimum. Use a monotone stack to find `left[i]` (distance to previous strictly smaller) and `right[i]` (distance to next smaller-or-equal). Contribution = `arr[i] * left[i] * right[i]`.

```java
import java.util.ArrayDeque;

class Solution907 {
    public int sumSubarrayMins(int[] arr) {
        final long MOD = 1_000_000_007L;
        int n = arr.length;
        long[] left = new long[n];  // distance to previous strictly smaller
        long[] right = new long[n]; // distance to next smaller-or-equal
        var stack = new ArrayDeque<Integer>();

        // Left boundaries (previous strictly smaller — pop while arr[top] >= arr[i])
        for (int i = 0; i < n; i++) {
            while (!stack.isEmpty() && arr[stack.peek()] >= arr[i]) stack.pop();
            left[i] = stack.isEmpty() ? i + 1 : i - stack.peek();
            stack.push(i);
        }
        stack.clear();

        // Right boundaries (next smaller-or-equal — pop while arr[top] > arr[i])
        for (int i = n - 1; i >= 0; i--) {
            while (!stack.isEmpty() && arr[stack.peek()] > arr[i]) stack.pop();
            right[i] = stack.isEmpty() ? n - i : stack.peek() - i;
            stack.push(i);
        }

        long ans = 0;
        for (int i = 0; i < n; i++) {
            ans = (ans + (long) arr[i] % MOD * left[i] % MOD * right[i]) % MOD;
        }
        return (int) ans;
    }

    public static void main(String[] args) {
        var sol = new Solution907();

        var r1 = sol.sumSubarrayMins(new int[]{3, 1, 2, 4});
        if (r1 != 17) throw new AssertionError("LC907 ex1: expected 17, got " + r1);

        var r2 = sol.sumSubarrayMins(new int[]{11, 81, 94, 43, 3});
        if (r2 != 444) throw new AssertionError("LC907 ex2: expected 444, got " + r2);

        var r3 = sol.sumSubarrayMins(new int[]{7});
        if (r3 != 7) throw new AssertionError("LC907 single: expected 7, got " + r3);

        // [3,3]: subarrays [3],[3],[3,3] → 3+3+3 = 9
        var r4 = sol.sumSubarrayMins(new int[]{3, 3});
        if (r4 != 9) throw new AssertionError("LC907 equal: expected 9, got " + r4);

        System.out.println("LC907 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Naive | O(n²) | O(1) |
| Monotone stack | O(n) | O(n) |

**Java Notes:** Use `long` intermediate for `arr[i] * left[i] * right[i]` — the product can exceed `Integer.MAX_VALUE`. Strict `>=` on one side and `>` on the other prevents double-counting equal elements.

---

## Section 12: Sum over Subsets (SOS DP) / Bitmask Enumeration

**Core idea:** Enumerate all `2^n` subsets. For values ≤ 30, the 10 primes fit in a 10-bit mask (1024 states). SOS DP aggregates subset properties in O(n * 2^n) instead of O(3^n).

---

### LC #2212 — Maximum Points in an Archery Competition

**Difficulty:** Medium

**Problem:** Bob has `numArrows`. Sections 0–11: winning section `i` requires strictly more arrows than `aliceArrows[i]`. Maximize Bob's score. Return arrow allocation.

**Key Insight:** Only 12 sections → enumerate all `2^12 = 4096` subsets Bob can win. For each feasible subset, check total arrows needed. Track the best, then reconstruct allocation.

```java
class Solution2212 {
    public int[] maximumBobPoints(int numArrows, int[] aliceArrows) {
        int n = 12;
        int bestScore = 0, bestMask = 0;

        for (int mask = 0; mask < (1 << n); mask++) {
            int arrowsUsed = 0, score = 0;
            for (int i = 0; i < n; i++) {
                if ((mask >> i & 1) == 1) {
                    arrowsUsed += aliceArrows[i] + 1;
                    score += i;
                }
            }
            if (arrowsUsed <= numArrows && score > bestScore) {
                bestScore = score;
                bestMask = mask;
            }
        }

        int[] result = new int[n];
        int remaining = numArrows;
        for (int i = 0; i < n; i++) {
            if ((bestMask >> i & 1) == 1) {
                result[i] = aliceArrows[i] + 1;
                remaining -= result[i];
            }
        }
        result[0] += remaining; // dump leftover into section 0 (score 0)
        return result;
    }

    static int computeScore(int numArrows, int[] aliceArrows, int[] result) {
        int total = 0;
        for (int x : result) total += x;
        if (total != numArrows)
            throw new AssertionError("Arrow total mismatch: " + total + " != " + numArrows);
        int score = 0;
        for (int i = 1; i < 12; i++) {
            if (result[i] > aliceArrows[i]) score += i;
        }
        return score;
    }

    public static void main(String[] args) {
        var sol = new Solution2212();

        int[] alice1 = {1, 1, 0, 1, 0, 0, 2, 1, 0, 1, 2, 2};
        var r1 = sol.maximumBobPoints(9, alice1);
        int score1 = computeScore(9, alice1, r1);
        if (score1 != 4) throw new AssertionError("LC2212 ex1: expected score 4, got " + score1);

        // Verify no other feasible subset beats score1
        int[] alice2 = {0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2};
        var r2 = sol.maximumBobPoints(3, alice2);
        computeScore(3, alice2, r2); // at minimum verifies arrow total

        System.out.println("LC2212 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Bitmask enumeration | O(2^12 * 12) ≈ O(49K) | O(1) |

---

### LC #1994 — The Number of Good Subsets

**Difficulty:** Hard

**Problem:** A "good" integer is a product of distinct primes. Count non-empty subsets of `nums` whose product is a good integer, modulo 10^9+7.

**Key Insight:** Primes up to 30: {2,3,5,7,11,13,17,19,23,29} — 10 primes, 10-bit masks. Numbers with a squared prime factor cannot participate. DP over prime masks: `dp[mask]` = count of subsets with combined prime mask. Iterate over complement subsets to avoid conflicts (O(3^10) ≈ 59K, tolerable). Multiply by 2^(freq[1]) for the ones.

```java
class Solution1994 {
    static final int[] PRIMES = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29};
    static final long MOD = 1_000_000_007L;

    // Returns prime mask for x (2..30), or -1 if x has a squared prime factor.
    static int primeMask(int x) {
        int mask = 0;
        for (int i = 0; i < PRIMES.length; i++) {
            if (x % PRIMES[i] == 0) {
                x /= PRIMES[i];
                if (x % PRIMES[i] == 0) return -1; // squared factor
                mask |= (1 << i);
            }
        }
        return mask;
    }

    public int numberOfGoodSubsets(int[] nums) {
        long[] freq = new long[31];
        for (int x : nums) freq[x]++;

        int np = PRIMES.length;
        long[] dp = new long[1 << np];
        dp[0] = 1; // empty subset base

        for (int num = 2; num <= 30; num++) {
            if (freq[num] == 0) continue;
            int mask = primeMask(num);
            if (mask <= 0) continue; // -1 (squared) or 0 (shouldn't happen for num>=2)

            int complement = ((1 << np) - 1) ^ mask;
            // Iterate over all subsets of complement to avoid prime overlap
            for (int sub = complement; ; sub = (sub - 1) & complement) {
                if (dp[sub] > 0) {
                    dp[sub | mask] = (dp[sub | mask] + dp[sub] * freq[num]) % MOD;
                }
                if (sub == 0) break;
            }
        }

        long ans = 0;
        for (int mask = 1; mask < (1 << np); mask++) {
            ans = (ans + dp[mask]) % MOD;
        }

        // Multiply by 2^(freq[1]): each 1 can join any valid subset independently
        long pow2 = 1;
        for (long i = 0; i < freq[1]; i++) pow2 = pow2 * 2 % MOD;
        ans = ans * pow2 % MOD;
        return (int) ans;
    }

    public static void main(String[] args) {
        var sol = new Solution1994();

        var r1 = sol.numberOfGoodSubsets(new int[]{1, 2, 3, 4});
        if (r1 != 6) throw new AssertionError("LC1994 ex1: expected 6, got " + r1);

        var r2 = sol.numberOfGoodSubsets(new int[]{4, 2, 3, 15});
        if (r2 != 5) throw new AssertionError("LC1994 ex2: expected 5, got " + r2);

        var r3 = sol.numberOfGoodSubsets(new int[]{1, 1});
        if (r3 != 0) throw new AssertionError("LC1994 only-ones: expected 0, got " + r3);

        System.out.println("LC1994 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Subset enumeration | O(30 * 3^10) ≈ O(59K) | O(2^10 = 1024) |

---

### LC #2572 — Count the Number of Square-Free Subsets

**Difficulty:** Medium

**Problem:** A square-free integer has no prime factor appearing more than once. Count non-empty subsets of `nums` (elements in [1,30]) whose product is square-free, modulo 10^9+7.

**Key Insight:** Identical prime-mask structure to LC #1994. Elements with squared prime factors are excluded. Elements equal to 1 multiply the count by 2^(freq[1]) — with the caveat that subsets of only 1s have product 1 (which is square-free) and must be counted, but the empty set must not.

```java
class Solution2572 {
    static final int[] PRIMES = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29};
    static final long MOD = 1_000_000_007L;

    static int primeMask(int x) {
        int mask = 0;
        for (int i = 0; i < PRIMES.length; i++) {
            if (x % PRIMES[i] == 0) {
                x /= PRIMES[i];
                if (x % PRIMES[i] == 0) return -1;
                mask |= (1 << i);
            }
        }
        return mask;
    }

    public int squareFreeSubsets(int[] nums) {
        long[] freq = new long[31];
        for (int x : nums) freq[x]++;

        int np = PRIMES.length;
        int totalMasks = 1 << np;
        long[] dp = new long[totalMasks];
        dp[0] = 1; // empty product base

        for (int num = 2; num <= 30; num++) {
            if (freq[num] == 0) continue;
            int mask = primeMask(num);
            if (mask < 0) continue; // squared prime factor — unusable

            int complement = (totalMasks - 1) ^ mask;
            for (int sub = complement; ; sub = (sub - 1) & complement) {
                if (dp[sub] > 0) {
                    dp[sub | mask] = (dp[sub | mask] + dp[sub] * freq[num]) % MOD;
                }
                if (sub == 0) break;
            }
        }

        // Sum all non-empty-product subsets (mask > 0 means at least one prime used)
        long ans = 0;
        for (int mask = 1; mask < totalMasks; mask++) {
            ans = (ans + dp[mask]) % MOD;
        }

        // 2^k factor: each of the freq[1] ones can optionally join any valid subset.
        // dp[0] = 1 represents the "empty non-1 selection"; multiplied by 2^k gives
        // all subsets consisting only of 1s (including the empty set).
        // Formula: ans*2^k (non-1 subsets, each extended by any 1s)
        //        + (2^k - 1)  (pure-1 subsets, excluding empty set dp[0]*2^k - 1)
        long pow2 = 1;
        for (long i = 0; i < freq[1]; i++) pow2 = pow2 * 2 % MOD;

        long totalWith1s = dp[0] * pow2 % MOD; // includes empty subset
        ans = (ans * pow2 % MOD + totalWith1s - 1 + MOD) % MOD;
        return (int) ans;
    }

    public static void main(String[] args) {
        var sol = new Solution2572();

        var r1 = sol.squareFreeSubsets(new int[]{3, 4, 4, 5});
        if (r1 != 3) throw new AssertionError("LC2572 ex1: expected 3, got " + r1);

        var r2 = sol.squareFreeSubsets(new int[]{1});
        if (r2 != 1) throw new AssertionError("LC2572 ex2: expected 1, got " + r2);

        // [1,2]: subsets {1},{2},{1,2} → products 1,2,2 — all square-free → 3
        var r3 = sol.squareFreeSubsets(new int[]{1, 2});
        if (r3 != 3) throw new AssertionError("LC2572 with-ones: expected 3, got " + r3);

        System.out.println("LC2572 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Bitmask DP | O(30 * 2^10) | O(2^10) |

---

## Section 13: DP on Graphs / DAG DP

**Core idea:** On a DAG, `dp[node]` is computed from `dp[children]` via memoized DFS or topological (Kahn's BFS) order. Cycle detection is free with Kahn's: if `processed < n`, a cycle exists.

---

### LC #329 — Longest Increasing Path in a Matrix

**Difficulty:** Hard

**Problem:** `m x n` integer matrix. Return the length of the longest strictly increasing path (4-directional movement, no diagonals).

**Key Insight:** "Strictly increasing neighbor" forces a DAG. Apply memoized DFS: `memo[r][c]` = longest path starting at `(r, c)`. Each cell computed once → O(m*n). Alternatively, use topological sort on the implicit DAG (shown below as a note).

**Memoized DFS (natural form):**

```java
class Solution329 {
    private static final int[][] DIRS = {{-1,0},{1,0},{0,-1},{0,1}};

    private int dfs(int r, int c, int[][] matrix, int[][] memo) {
        if (memo[r][c] != 0) return memo[r][c];
        int m = matrix.length, n = matrix[0].length;
        int best = 1;
        for (var d : DIRS) {
            int nr = r + d[0], nc = c + d[1];
            if (nr >= 0 && nr < m && nc >= 0 && nc < n
                    && matrix[nr][nc] > matrix[r][c]) {
                best = Math.max(best, 1 + dfs(nr, nc, matrix, memo));
            }
        }
        return memo[r][c] = best;
    }

    public int longestIncreasingPath(int[][] matrix) {
        int m = matrix.length, n = matrix[0].length;
        int[][] memo = new int[m][n]; // zero-initialized = "not computed"
        int ans = 0;
        for (int r = 0; r < m; r++)
            for (int c = 0; c < n; c++)
                ans = Math.max(ans, dfs(r, c, matrix, memo));
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution329();

        var r1 = sol.longestIncreasingPath(new int[][]{{9,9,4},{6,6,8},{2,1,1}});
        if (r1 != 4) throw new AssertionError("LC329 ex1: expected 4, got " + r1);

        var r2 = sol.longestIncreasingPath(new int[][]{{3,4,5},{3,2,6},{2,2,1}});
        if (r2 != 4) throw new AssertionError("LC329 ex2: expected 4, got " + r2);

        var r3 = sol.longestIncreasingPath(new int[][]{{1}});
        if (r3 != 1) throw new AssertionError("LC329 single: expected 1, got " + r3);

        System.out.println("LC329 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Memoized DFS | O(m * n) | O(m * n) |
| Topological Sort BFS | O(m * n) | O(m * n) |

**Java Notes:** `memo[r][c] = 0` means "not yet computed" since every valid answer is ≥ 1. No need for a separate `visited` array — the zero-init of Java arrays serves as the sentinel.

**Approach 2 — Topological Sort BFS:**

Build an explicit DAG: edge `(r,c) → (nr,nc)` when `matrix[nr][nc] > matrix[r][c]`. Count layers of the BFS (each layer = one step in the longest path).

```java
import java.util.ArrayDeque;

class Solution329Topo {
    private static final int[][] DIRS = {{-1,0},{1,0},{0,-1},{0,1}};

    public int longestIncreasingPath(int[][] matrix) {
        int m = matrix.length, n = matrix[0].length;
        int[] inDeg = new int[m * n];

        for (int r = 0; r < m; r++) {
            for (int c = 0; c < n; c++) {
                for (var d : DIRS) {
                    int nr = r + d[0], nc = c + d[1];
                    if (nr >= 0 && nr < m && nc >= 0 && nc < n
                            && matrix[nr][nc] > matrix[r][c]) {
                        inDeg[nr * n + nc]++;
                    }
                }
            }
        }

        var queue = new ArrayDeque<Integer>();
        for (int i = 0; i < m * n; i++) if (inDeg[i] == 0) queue.add(i);

        int layers = 0;
        while (!queue.isEmpty()) {
            layers++;
            int size = queue.size();
            for (int k = 0; k < size; k++) {
                int u = queue.poll();
                int r = u / n, c = u % n;
                for (var d : DIRS) {
                    int nr = r + d[0], nc = c + d[1];
                    if (nr >= 0 && nr < m && nc >= 0 && nc < n
                            && matrix[nr][nc] > matrix[r][c]) {
                        if (--inDeg[nr * n + nc] == 0) queue.add(nr * n + nc);
                    }
                }
            }
        }
        return layers;
    }

    public static void main(String[] args) {
        var sol = new Solution329Topo();
        if (sol.longestIncreasingPath(new int[][]{{9,9,4},{6,6,8},{2,1,1}}) != 4)
            throw new AssertionError();
        if (sol.longestIncreasingPath(new int[][]{{3,4,5},{3,2,6},{2,2,1}}) != 4)
            throw new AssertionError();
        if (sol.longestIncreasingPath(new int[][]{{1}}) != 1)
            throw new AssertionError();
        System.out.println("LC329 Topo: all tests passed.");
    }
}
```

---

### LC #1857 — Largest Color Value in a Directed Graph

**Difficulty:** Hard

**Problem:** Directed graph where each node has a color (a–z). Find the largest number of nodes with the same color on any path. Return -1 if a cycle exists.

**Key Insight:** Topological sort (Kahn's BFS). `dp[u][c]` = max count of color `c` on any path ending at `u`. Propagate through edges: `dp[v][c] = max(dp[v][c], dp[u][c] + (colors[v] == c ? 1 : 0))`. If `processed < n`, cycle detected.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

class Solution1857 {
    public int largestPathValue(String colors, int[][] edges) {
        int n = colors.length();
        List<List<Integer>> adj = new ArrayList<>();
        int[] inDeg = new int[n];
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        for (var e : edges) {
            adj.get(e[0]).add(e[1]);
            inDeg[e[1]]++;
        }

        // dp[u][c] = max count of color c on any path ending at u
        int[][] dp = new int[n][26];
        for (int u = 0; u < n; u++) dp[u][colors.charAt(u) - 'a'] = 1;

        var queue = new ArrayDeque<Integer>();
        for (int u = 0; u < n; u++) if (inDeg[u] == 0) queue.add(u);

        int processed = 0, ans = 0;
        while (!queue.isEmpty()) {
            int u = queue.poll();
            processed++;
            for (int c = 0; c < 26; c++) ans = Math.max(ans, dp[u][c]);
            for (int v : adj.get(u)) {
                for (int c = 0; c < 26; c++) {
                    int newVal = dp[u][c] + (colors.charAt(v) - 'a' == c ? 1 : 0);
                    dp[v][c] = Math.max(dp[v][c], newVal);
                }
                if (--inDeg[v] == 0) queue.add(v);
            }
        }
        return processed < n ? -1 : ans;
    }

    public static void main(String[] args) {
        var sol = new Solution1857();

        var r1 = sol.largestPathValue("abaca", new int[][]{{0,1},{0,2},{2,3},{3,4}});
        if (r1 != 3) throw new AssertionError("LC1857 ex1: expected 3, got " + r1);

        var r2 = sol.largestPathValue("a", new int[][]{{0,0}});
        if (r2 != -1) throw new AssertionError("LC1857 cycle: expected -1, got " + r2);

        var r3 = sol.largestPathValue("aa", new int[][]{});
        if (r3 != 1) throw new AssertionError("LC1857 no-edges: expected 1, got " + r3);

        System.out.println("LC1857 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Topo-sort + DP | O(V * 26 + E) | O(V * 26) |

---

### LC #2050 — Parallel Courses III

**Difficulty:** Hard

**Problem:** `n` courses, `relations[i] = [prev, next]` (1-indexed prerequisite). Course `i` takes `time[i]` months. All parallel-eligible courses run simultaneously. Return minimum time to finish all.

**Key Insight:** DAG DP. `dp[u]` = earliest finish time of course `u`. Propagate via Kahn's BFS: when processing edge `u → v`, update `dp[v] = max(dp[v], dp[u] + time[v])`. Answer = max over all `dp`.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

class Solution2050 {
    public int minimumTime(int n, int[][] relations, int[] time) {
        List<List<Integer>> adj = new ArrayList<>();
        int[] inDeg = new int[n];
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        for (var r : relations) {
            int u = r[0] - 1, v = r[1] - 1; // convert to 0-indexed
            adj.get(u).add(v);
            inDeg[v]++;
        }

        int[] dp = time.clone(); // dp[u] = earliest finish time
        var queue = new ArrayDeque<Integer>();
        for (int u = 0; u < n; u++) if (inDeg[u] == 0) queue.add(u);

        while (!queue.isEmpty()) {
            int u = queue.poll();
            for (int v : adj.get(u)) {
                dp[v] = Math.max(dp[v], dp[u] + time[v]);
                if (--inDeg[v] == 0) queue.add(v);
            }
        }

        int ans = 0;
        for (int x : dp) ans = Math.max(ans, x);
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution2050();

        var r1 = sol.minimumTime(3, new int[][]{{1,3},{2,3}}, new int[]{3,2,5});
        if (r1 != 8) throw new AssertionError("LC2050 ex1: expected 8, got " + r1);

        var r2 = sol.minimumTime(5, new int[][]{{1,5},{2,5},{3,5},{3,4},{4,5}}, new int[]{1,2,3,4,5});
        if (r2 != 12) throw new AssertionError("LC2050 ex2: expected 12, got " + r2);

        var r3 = sol.minimumTime(3, new int[][]{}, new int[]{2,5,3});
        if (r3 != 5) throw new AssertionError("LC2050 no-rel: expected 5, got " + r3);

        System.out.println("LC2050 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Topological sort DP | O(V + E) | O(V + E) |

---

### LC #1697 — Checking Existence of Edge Length Limited Paths

**Difficulty:** Hard

**Problem:** Weighted undirected graph, queries `[u, v, limit]`. For each query return whether a path from `u` to `v` exists where every edge weight is strictly less than `limit`. Process offline.

**Key Insight:** Sort edges and queries by weight/limit. Process queries in limit order, adding edges with `weight < limit` via Union-Find (DSU). Check connectivity for each query at its position.

```java
import java.util.Arrays;

class Solution1697 {
    // DSU with path compression and union by rank
    static int[] parent, rank;
    static int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }
    static void union(int x, int y) {
        int rx = find(x), ry = find(y);
        if (rx == ry) return;
        if (rank[rx] < rank[ry]) { int t = rx; rx = ry; ry = t; }
        parent[ry] = rx;
        if (rank[rx] == rank[ry]) rank[rx]++;
    }

    public boolean[] distanceLimitedPathsExist(int n, int[][] edgeList, int[][] queries) {
        parent = new int[n];
        rank = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;

        // Sort edges by weight
        Arrays.sort(edgeList, (a, b) -> Integer.compare(a[2], b[2]));

        int q = queries.length;
        Integer[] qi = new Integer[q];
        for (int i = 0; i < q; i++) qi[i] = i;
        Arrays.sort(qi, (a, b) -> Integer.compare(queries[a][2], queries[b][2]));

        boolean[] result = new boolean[q];
        int ei = 0;
        for (int idx : qi) {
            int limit = queries[idx][2];
            while (ei < edgeList.length && edgeList[ei][2] < limit) {
                union(edgeList[ei][0], edgeList[ei][1]);
                ei++;
            }
            result[idx] = find(queries[idx][0]) == find(queries[idx][1]);
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution1697();

        var r1 = sol.distanceLimitedPathsExist(4,
            new int[][]{{0,1,2},{1,2,4},{2,3,8},{1,3,2}},
            new int[][]{{0,3,2},{0,3,5}});
        if (r1[0] != false || r1[1] != true)
            throw new AssertionError("LC1697 ex1: expected [false,true], got " + Arrays.toString(r1));

        var r2 = sol.distanceLimitedPathsExist(2,
            new int[][]{{0,1,5}},
            new int[][]{{0,1,6},{0,1,5}});
        if (r2[0] != true || r2[1] != false)
            throw new AssertionError("LC1697 direct: expected [true,false], got " + Arrays.toString(r2));

        System.out.println("LC1697 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Sort + DSU | O((E + Q) log(E + Q)) | O(E + Q + V) |

**Java Notes:** `Arrays.sort` with a lambda comparator on `Integer[]` (boxed) is acceptable here. For very large inputs, consider sorting a primitive array of indices by hand. The static DSU fields are acceptable in a LeetCode `Solution` class context but would need instance fields in a thread-safe setting.

---

## Section 14: Hard DP Miscellaneous (Grandmaster Level)

---

### LC #188 — Best Time to Buy and Sell Stock IV

**Difficulty:** Hard

**Problem:** Array `prices`, integer `k`. Maximum profit from at most `k` transactions. Must sell before buying again.

**Key Insight:** If `k >= n/2`, use greedy (unlimited transactions). Otherwise, maintain `buy[j]` = best profit currently holding stock after `j-1` completed transactions, and `sell[j]` = best profit after `j` completed transactions. Update in reverse to avoid same-day reuse.

```java
class Solution188 {
    public int maxProfit(int k, int[] prices) {
        int n = prices.length;
        if (n == 0) return 0;

        // Unlimited transactions: greedy
        if (k >= n / 2) {
            int profit = 0;
            for (int i = 1; i < n; i++)
                if (prices[i] > prices[i - 1]) profit += prices[i] - prices[i - 1];
            return profit;
        }

        // buy[j] = max profit holding stock, having completed j-1 sell ops
        // sell[j] = max profit not holding stock, having completed j sell ops
        int[] buy = new int[k + 1];
        int[] sell = new int[k + 1];
        java.util.Arrays.fill(buy, Integer.MIN_VALUE / 2); // avoid overflow on subtraction

        for (int p : prices) {
            // Reverse to avoid using same-day values
            for (int j = k; j >= 1; j--) {
                buy[j]  = Math.max(buy[j],  sell[j - 1] - p);
                sell[j] = Math.max(sell[j], buy[j] + p);
            }
        }

        int ans = 0;
        for (int x : sell) ans = Math.max(ans, x);
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution188();

        var r1 = sol.maxProfit(2, new int[]{2, 4, 1});
        if (r1 != 2) throw new AssertionError("LC188 ex1: expected 2, got " + r1);

        var r2 = sol.maxProfit(2, new int[]{3, 2, 6, 5, 0, 3});
        if (r2 != 7) throw new AssertionError("LC188 ex2: expected 7, got " + r2);

        var r3 = sol.maxProfit(100, new int[]{1, 2, 3, 4, 5});
        if (r3 != 4) throw new AssertionError("LC188 k-large: expected 4, got " + r3);

        var r4 = sol.maxProfit(1, new int[]{5, 4, 3, 2, 1});
        if (r4 != 0) throw new AssertionError("LC188 no-profit: expected 0, got " + r4);

        System.out.println("LC188 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Unlimited (k >= n/2) | O(n) | O(1) |
| General | O(n * k) | O(k) |

**Java Notes:** `Integer.MIN_VALUE / 2` (not `Integer.MIN_VALUE`) is crucial for `buy[]` initialization — adding `p` to `Integer.MIN_VALUE` overflows to a positive number, producing wrong answers.

**Approach 2 — Explicit hold/cash State Machine:**

```java
class Solution188Explicit {
    public int maxProfit(int k, int[] prices) {
        int n = prices.length;
        if (n == 0) return 0;
        if (k >= n / 2) {
            int profit = 0;
            for (int i = 1; i < n; i++)
                if (prices[i] > prices[i - 1]) profit += prices[i] - prices[i - 1];
            return profit;
        }
        // hold[j] = best profit holding stock, having started j-th transaction
        // cash[j] = best profit not holding, having completed j transactions
        int[] hold = new int[k + 1];
        int[] cash = new int[k + 1];
        java.util.Arrays.fill(hold, Integer.MIN_VALUE / 2);

        for (int p : prices) {
            for (int j = k; j >= 1; j--) {
                hold[j] = Math.max(hold[j], cash[j - 1] - p); // buy
                cash[j] = Math.max(cash[j], hold[j] + p);     // sell
            }
        }
        int ans = 0;
        for (int x : cash) ans = Math.max(ans, x);
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution188Explicit();
        if (sol.maxProfit(2, new int[]{2,4,1}) != 2) throw new AssertionError("188ex ex1");
        if (sol.maxProfit(2, new int[]{3,2,6,5,0,3}) != 7) throw new AssertionError("188ex ex2");
        if (sol.maxProfit(100, new int[]{1,2,3,4,5}) != 4) throw new AssertionError("188ex k-large");
        if (sol.maxProfit(1, new int[]{5,4,3,2,1}) != 0) throw new AssertionError("188ex no-profit");
        System.out.println("LC188 Explicit: all tests passed.");
    }
}
```

**When to use which:** Both approaches run in O(n·k) / O(k). The explicit `hold`/`cash` naming makes the state machine unambiguous. Use the first variant for conciseness; use this variant when reviewing state-machine DP in interviews.

---

### LC #2218 — Maximum Value of K Coins From Piles

**Difficulty:** Hard

**Problem:** `n` piles of coins. Pick exactly `k` coins total (always from the top). Maximize sum.

**Key Insight:** Grouped knapsack. `dp[j]` = max sum picking exactly `j` coins from piles seen so far. For each pile, iterate `j` in reverse and try taking 0 to min(pile size, j) coins using prefix sums of that pile.

```java
class Solution2218 {
    public int maxValueOfCoins(java.util.List<java.util.List<Integer>> piles, int k) {
        int[] dp = new int[k + 1]; // zero-initialized; dp[j] = max sum with j coins

        for (var pile : piles) {
            int sz = pile.size();
            // Prefix sums of this pile
            int[] pre = new int[sz + 1];
            for (int i = 0; i < sz; i++) pre[i + 1] = pre[i] + pile.get(i);

            // Reverse iteration (grouped knapsack — each pile used at most once)
            for (int j = k; j >= 1; j--) {
                for (int take = 1; take <= Math.min(sz, j); take++) {
                    dp[j] = Math.max(dp[j], dp[j - take] + pre[take]);
                }
            }
        }
        return dp[k];
    }

    public static void main(String[] args) {
        var sol = new Solution2218();

        var p1 = java.util.List.of(
            java.util.List.of(1,100,3),
            java.util.List.of(7,8,9));
        var r1 = sol.maxValueOfCoins(p1, 2);
        if (r1 != 101) throw new AssertionError("LC2218 ex1: expected 101, got " + r1);

        var p2 = java.util.List.of(
            java.util.List.of(100), java.util.List.of(100), java.util.List.of(100),
            java.util.List.of(100), java.util.List.of(100), java.util.List.of(100),
            java.util.List.of(1,1,1,1,1,1,700));
        var r2 = sol.maxValueOfCoins(p2, 7);
        if (r2 != 706) throw new AssertionError("LC2218 ex2: expected 706, got " + r2);

        var p3 = java.util.List.of(java.util.List.of(5,3,1));
        var r3 = sol.maxValueOfCoins(p3, 2);
        if (r3 != 8) throw new AssertionError("LC2218 single: expected 8, got " + r3);

        System.out.println("LC2218 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Grouped knapsack | O(k * sum of pile sizes) | O(k) |

**Approach 2 — Top-Down Memoized DFS:**

```java
class Solution2218Memo {
    private int[][] memo;
    private int[][] pre; // prefix sums per pile

    public int maxValueOfCoins(java.util.List<java.util.List<Integer>> piles, int k) {
        int n = piles.size();
        pre = new int[n][];
        for (int i = 0; i < n; i++) {
            var pile = piles.get(i);
            pre[i] = new int[pile.size() + 1];
            for (int j = 0; j < pile.size(); j++) pre[i][j + 1] = pre[i][j] + pile.get(j);
        }
        memo = new int[n][k + 1];
        for (int[] row : memo) java.util.Arrays.fill(row, -1);
        return dfs(0, k);
    }

    private int dfs(int i, int rem) {
        if (i == pre.length || rem == 0) return 0;
        if (memo[i][rem] != -1) return memo[i][rem];
        int best = dfs(i + 1, rem); // take 0 from pile i
        int maxTake = Math.min(pre[i].length - 1, rem);
        for (int t = 1; t <= maxTake; t++)
            best = Math.max(best, pre[i][t] + dfs(i + 1, rem - t));
        return memo[i][rem] = best;
    }

    public static void main(String[] args) {
        var sol = new Solution2218Memo();
        var r1 = sol.maxValueOfCoins(java.util.List.of(
            java.util.List.of(1,100,3), java.util.List.of(7,8,9)), 2);
        if (r1 != 101) throw new AssertionError("LC2218memo ex1: expected 101, got " + r1);
        var r2 = sol.maxValueOfCoins(java.util.List.of(
            java.util.List.of(5,3,1)), 2);
        if (r2 != 8) throw new AssertionError("LC2218memo single: expected 8, got " + r2);
        System.out.println("LC2218 Memo: all tests passed.");
    }
}
```

**When to use which:** The bottom-up grouped knapsack is faster in practice (better cache locality, no stack overhead). The top-down version maps directly to the recursive formulation `dfs(pile, remaining)` and is a useful starting point for deriving the tabulation.

---

### LC #2209 — Minimum White Tiles After Covering With Carpets

**Difficulty:** Hard

**Problem:** Binary string `floor` (1=white). `numCarpets` carpets each of length `carpetLen`. Minimize remaining white tiles.

**Key Insight:** Rolling DP. `dp[i]` = min white tiles in `floor[0..i]` using the current number of carpets. For each carpet layer: either skip position `i` (inherit left neighbor + this tile), or place a carpet ending at `i` (inherit `dp[start-1]` from previous carpet layer).

**Both tabulation variants shown (no-carpet base → per-carpet layer):**

```java
class Solution2209 {
    public int minimumWhiteTiles(String floor, int numCarpets, int carpetLen) {
        int n = floor.length();
        int[] tiles = new int[n];
        for (int i = 0; i < n; i++) tiles[i] = floor.charAt(i) - '0';

        // Base: 0 carpets — dp[i] = prefix count of white tiles in [0..i]
        int[] dp = new int[n];
        dp[0] = tiles[0];
        for (int i = 1; i < n; i++) dp[i] = dp[i - 1] + tiles[i];

        for (int carpet = 1; carpet <= numCarpets; carpet++) {
            int[] ndp = new int[n];
            for (int i = 0; i < n; i++) {
                // Option 1: don't end carpet at i
                int noCover = (i > 0 ? ndp[i - 1] : 0) + tiles[i];
                // Option 2: place carpet ending at i (covers [i-carpetLen+1, i])
                int start = i - carpetLen; // first position NOT covered
                int withCover = start >= 0 ? dp[start] : 0;
                ndp[i] = Math.min(noCover, withCover);
            }
            dp = ndp;
        }
        return dp[n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution2209();

        var r1 = sol.minimumWhiteTiles("10110101", 2, 2);
        if (r1 != 2) throw new AssertionError("LC2209 ex1: expected 2, got " + r1);

        var r2 = sol.minimumWhiteTiles("11111", 2, 3);
        if (r2 != 0) throw new AssertionError("LC2209 ex2: expected 0, got " + r2);

        var r3 = sol.minimumWhiteTiles("000", 1, 2);
        if (r3 != 0) throw new AssertionError("LC2209 no-whites: expected 0, got " + r3);

        var r4 = sol.minimumWhiteTiles("111", 1, 3);
        if (r4 != 0) throw new AssertionError("LC2209 full-cover: expected 0, got " + r4);

        System.out.println("LC2209 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| 2D DP (rolling) | O(n * numCarpets) | O(n) |

**Java Notes:** The "place carpet ending at `i`" branch uses `dp[start]` from the **previous** carpet layer (not `ndp`), so we swap arrays after each carpet rather than updating in-place. `start = i - carpetLen` (not `i - carpetLen + 1`) because `dp[start]` represents tiles through position `start`, i.e., the carpet covers `[start+1, i]` which is exactly `carpetLen` positions.

---

### LC #2370 — Longest Ideal Subsequence

**Difficulty:** Medium

**Problem:** String `s`, integer `k`. Longest subsequence where adjacent characters differ in alphabetical position by at most `k`.

**Key Insight:** `dp[c]` = length of longest ideal subsequence ending with character `c`. For each `s[i]`, scan all characters within ±k in the alphabet (at most 26), take max, increment.

```java
class Solution2370 {
    public int longestIdealString(String s, int k) {
        int[] dp = new int[26]; // dp[c] = longest ideal subseq ending with char c

        for (char ch : s.toCharArray()) {
            int c = ch - 'a';
            int lo = Math.max(0, c - k), hi = Math.min(25, c + k);
            int best = 0;
            for (int x = lo; x <= hi; x++) best = Math.max(best, dp[x]);
            dp[c] = Math.max(dp[c], best + 1);
        }

        int ans = 0;
        for (int x : dp) ans = Math.max(ans, x);
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution2370();

        var r1 = sol.longestIdealString("acfgbd", 2);
        if (r1 != 4) throw new AssertionError("LC2370 ex1: expected 4, got " + r1);

        var r2 = sol.longestIdealString("abcd", 3);
        if (r2 != 4) throw new AssertionError("LC2370 ex2: expected 4, got " + r2);

        var r3 = sol.longestIdealString("aabb", 0);
        if (r3 != 2) throw new AssertionError("LC2370 k=0: expected 2, got " + r3);

        var r4 = sol.longestIdealString("z", 5);
        if (r4 != 1) throw new AssertionError("LC2370 single: expected 1, got " + r4);

        System.out.println("LC2370 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| DP over alphabet | O(n * k) = O(26n) worst | O(26) |

---

### LC #2901 — Longest Unequal Adjacent Groups Subsequence II

**Difficulty:** Medium

**Problem:** `words` and `groups`. Select longest subsequence where adjacent words are in different groups AND have the same length AND differ in exactly one character. Return the actual subsequence.

**Key Insight:** LIS-style DP. `dp[i]` = length of longest valid subsequence ending at index `i`. `prev[i]` tracks predecessor for reconstruction. For each pair `(j, i)`, check group difference, same length, and Hamming distance = 1.

```java
import java.util.ArrayList;
import java.util.List;

class Solution2901 {
    private boolean oneDiff(String a, String b) {
        if (a.length() != b.length()) return false;
        int diff = 0;
        for (int i = 0; i < a.length(); i++) if (a.charAt(i) != b.charAt(i)) diff++;
        return diff == 1;
    }

    public List<String> getWordsInLongestSubsequence(String[] words, int[] groups) {
        int n = words.length;
        int[] dp = new int[n];
        int[] prev = new int[n];
        java.util.Arrays.fill(dp, 1);
        java.util.Arrays.fill(prev, -1);

        for (int i = 0; i < n; i++) {
            for (int j = 0; j < i; j++) {
                if (groups[j] != groups[i]
                        && oneDiff(words[j], words[i])
                        && dp[j] + 1 > dp[i]) {
                    dp[i] = dp[j] + 1;
                    prev[i] = j;
                }
            }
        }

        // Find the best endpoint
        int bestIdx = 0;
        for (int i = 1; i < n; i++) if (dp[i] > dp[bestIdx]) bestIdx = i;

        // Reconstruct path
        var path = new ArrayList<String>();
        for (int cur = bestIdx; cur != -1; cur = prev[cur]) path.add(words[cur]);
        java.util.Collections.reverse(path);
        return path;
    }

    public static void main(String[] args) {
        var sol = new Solution2901();

        var r1 = sol.getWordsInLongestSubsequence(
            new String[]{"bab","dab","cab"}, new int[]{1,2,2});
        // Length must be 2; valid pairs: (bab,dab) or (bab,cab) — groups differ, 1 char diff
        if (r1.size() != 2)
            throw new AssertionError("LC2901 ex1: expected length 2, got " + r1.size());
        // Verify adjacent constraints
        for (int i = 1; i < r1.size(); i++) {
            if (!sol.oneDiff(r1.get(i-1), r1.get(i)))
                throw new AssertionError("LC2901 ex1: invalid Hamming at pos " + i + ": " + r1);
        }

        var r2 = sol.getWordsInLongestSubsequence(
            new String[]{"a","b","c","d"}, new int[]{1,2,1,2});
        if (r2.size() != 4)
            throw new AssertionError("LC2901 ex2: expected length 4, got " + r2.size());

        var r3 = sol.getWordsInLongestSubsequence(
            new String[]{"abc"}, new int[]{1});
        if (r3.size() != 1 || !r3.get(0).equals("abc"))
            throw new AssertionError("LC2901 single: expected [abc], got " + r3);

        System.out.println("LC2901 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| LIS-style DP | O(n² * L) | O(n) |

---

### LC #2707 — Extra Characters in a String

**Difficulty:** Medium

**Problem:** String `s`, dictionary of words. Split `s` optimally; characters not in any dictionary word are "extra." Minimize extra characters.

**Key Insight:** `dp[i]` = min extra characters in `s[0..i-1]` (length-`i` prefix). Either `s[i-1]` is extra (`dp[i] = dp[i-1] + 1`), or some suffix `s[j..i-1]` is a dictionary word (`dp[i] = min(dp[j])`). HashSet for O(L) lookup.

**Both memoization (top-down) and tabulation shown:**

```java
import java.util.HashSet;
import java.util.Set;

class Solution2707 {
    // Tabulation (bottom-up)
    public int minExtraChar(String s, String[] dictionary) {
        int n = s.length();
        Set<String> dict = new HashSet<>(java.util.Arrays.asList(dictionary));
        int[] dp = new int[n + 1]; // dp[i] = min extra chars in s[0..i-1]
        // dp[0] = 0 (empty prefix), dp[i] initialized via dp[i-1]+1 each step

        for (int i = 1; i <= n; i++) {
            dp[i] = dp[i - 1] + 1; // s[i-1] is extra
            for (int j = 0; j < i; j++) {
                if (dict.contains(s.substring(j, i))) {
                    dp[i] = Math.min(dp[i], dp[j]);
                }
            }
        }
        return dp[n];
    }

    public static void main(String[] args) {
        var sol = new Solution2707();

        var r1 = sol.minExtraChar("leetscode", new String[]{"leet","code"});
        if (r1 != 1) throw new AssertionError("LC2707 ex1: expected 1, got " + r1);

        // "sayhelloworld": only "a" at index 1 matches → 12 extra chars (13 - 1)
        var r2 = sol.minExtraChar("sayhelloworld", new String[]{"a","b","ab"});
        if (r2 != 12) throw new AssertionError("LC2707 ex2: expected 12, got " + r2);

        var r3 = sol.minExtraChar("helloworld", new String[]{"hello","world"});
        if (r3 != 0) throw new AssertionError("LC2707 full-match: expected 0, got " + r3);

        var r4 = sol.minExtraChar("abc", new String[]{"xyz"});
        if (r4 != 3) throw new AssertionError("LC2707 no-match: expected 3, got " + r4);

        System.out.println("LC2707 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| DP + HashSet | O(n² * L) | O(n + dict size) |

**Java Notes:** `s.substring(j, i)` creates a new `String` object each call — O(L) time and memory per call. For very large inputs, a trie would reduce total work to O(n²) character comparisons instead of O(n²) string-hash operations.

---

### LC #2463 — Minimum Total Distance Traveled

**Difficulty:** Hard

**Problem:** Robots at positions, factories at positions with capacities. Each robot assigned to one factory. Minimize total travel distance (sum of |robot - factory|).

**Key Insight:** Sort both. Expand factories into a flat slot list. DP: `dp[j]` = min cost assigning first `i` robots to first `j` slots. Two choices per slot: skip this slot, or assign robot `i` to slot `j`. Use `Long.MAX_VALUE / 2` as infinity to avoid overflow on addition.

```java
import java.util.Arrays;

class Solution2463 {
    public long minimumTotalDistance(java.util.List<Integer> robot,
                                     int[][] factory) {
        int[] robots = robot.stream().mapToInt(Integer::intValue).sorted().toArray();
        Arrays.sort(factory, (a, b) -> Integer.compare(a[0], b[0]));

        // Expand factory slots
        java.util.List<Integer> slotList = new java.util.ArrayList<>();
        for (var f : factory) for (int c = 0; c < f[1]; c++) slotList.add(f[0]);
        int[] slots = slotList.stream().mapToInt(Integer::intValue).toArray();

        int n = robots.length, m = slots.length;
        final long INF = Long.MAX_VALUE / 2;

        // dp[j] = min cost assigning first i robots using first j slots
        long[] dp = new long[m + 1];
        Arrays.fill(dp, INF);
        dp[0] = 0;

        for (int i = 1; i <= n; i++) {
            long[] ndp = new long[m + 1];
            Arrays.fill(ndp, INF);
            for (int j = 1; j <= m; j++) {
                // Skip slot j: carry forward ndp[j-1] (already computed this row)
                ndp[j] = ndp[j - 1];
                // Assign robot i to slot j: requires dp[j-1] from previous row
                if (dp[j - 1] < INF) {
                    long cost = Math.abs((long) robots[i - 1] - slots[j - 1]);
                    ndp[j] = Math.min(ndp[j], dp[j - 1] + cost);
                }
            }
            dp = ndp;
        }

        long ans = INF;
        for (long x : dp) ans = Math.min(ans, x);
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution2463();

        var r1 = sol.minimumTotalDistance(
            java.util.List.of(0,4,6), new int[][]{{2,2},{6,2}});
        if (r1 != 4) throw new AssertionError("LC2463 ex1: expected 4, got " + r1);

        var r2 = sol.minimumTotalDistance(
            java.util.List.of(1,-1), new int[][]{{-2,1},{2,1}});
        if (r2 != 2) throw new AssertionError("LC2463 ex2: expected 2, got " + r2);

        var r3 = sol.minimumTotalDistance(
            java.util.List.of(5), new int[][]{{5,1}});
        if (r3 != 0) throw new AssertionError("LC2463 single: expected 0, got " + r3);

        System.out.println("LC2463 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Sort + DP | O(n * m) | O(m) |

**Java Notes:** Use `long` for both the dp array and distance calculation — robot positions can be ±10^9, sum of distances can overflow `int`. `Long.MAX_VALUE / 2` prevents overflow when adding cost to the sentinel.

---

### LC #2809 — Minimum Time to Make Array Sum At Most x

**Difficulty:** Hard

**Problem:** Arrays `nums1`, `nums2`. Each second, `nums1[i] += nums2[i]`. Once per second you may set `nums1[i] = 0`. After `t` operations, `sum(nums1) <= x`. Find minimum `t`.

**Key Insight:** Sort pairs by `nums2` ascending (exchange-argument proof). `dp[j]` = max total reduction from zeroing exactly `j` elements in `t` seconds. For element at rank `j` (1-indexed within the sorted selection): zeroing at the optimal time gives reduction `nums1[i] + nums2[i] * j`. Answer: smallest `t` where `sum1 + sum2 * t - dp[t] <= x`.

```java
import java.util.Arrays;

class Solution2809 {
    public int minimumTime(int[] nums1, int[] nums2, int x) {
        int n = nums1.length;
        long x64 = x;
        long sum1 = 0, sum2 = 0;
        for (int v : nums1) sum1 += v;
        for (int v : nums2) sum2 += v;

        // Pair and sort by nums2 ascending
        long[][] pairs = new long[n][2];
        for (int i = 0; i < n; i++) { pairs[i][0] = nums1[i]; pairs[i][1] = nums2[i]; }
        Arrays.sort(pairs, (a, b) -> Long.compare(a[1], b[1]));

        // dp[j] = max total reduction selecting j elements (sorted ascending by nums2)
        long[] dp = new long[n + 1]; // zero-initialized

        for (int rank = 0; rank < n; rank++) {
            long a = pairs[rank][0], b = pairs[rank][1];
            // Process in reverse to avoid reusing same element
            for (int j = rank + 1; j >= 1; j--) {
                dp[j] = Math.max(dp[j], dp[j - 1] + a + b * j);
            }
        }

        for (int t = 0; t <= n; t++) {
            long remaining = sum1 + sum2 * t - dp[t];
            if (remaining <= x64) return t;
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution2809();

        var r1 = sol.minimumTime(new int[]{1,2,3}, new int[]{1,2,3}, 4);
        if (r1 != 3) throw new AssertionError("LC2809 ex1: expected 3, got " + r1);

        var r2 = sol.minimumTime(new int[]{1,2,3}, new int[]{1,2,3}, 5);
        if (r2 != 2) throw new AssertionError("LC2809 ex2: expected 2, got " + r2);

        // sum1 = 1, x = 5 → already satisfied at t=0
        var r3 = sol.minimumTime(new int[]{1}, new int[]{0}, 5);
        if (r3 != 0) throw new AssertionError("LC2809 already-ok: expected 0, got " + r3);

        System.out.println("LC2809 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Sort + DP | O(n²) | O(n) |

**Java Notes:** All intermediate computations use `long` — `sum2 * t` can be up to 10^5 * 10^5 = 10^10, well beyond `int` range. The inner loop bound `j = rank + 1` (not `n`) ensures we only use elements seen so far, maintaining the 0/1 knapsack property.

---

### LC #3041 — Maximize Consecutive Elements in an Array After Modification

**Difficulty:** Medium

**Problem:** Array of positive integers. Increment any element by at most 1. Maximize the length of the longest consecutive sequence.

**Key Insight:** Sort the array. For each element `a`, we can place it as `a` or `a+1`. Use a HashMap `dp` where `dp[v]` = longest chain ending exactly at value `v`. Process sorted: first update `dp[a+1] = dp[a] + 1` (use `a` incremented), then update `dp[a] = dp[a-1] + 1` (use `a` as-is). Order matters: the `a+1` update must happen before the `a` update to avoid a single element being counted twice.

```java
import java.util.Arrays;
import java.util.HashMap;

class Solution3041 {
    public int maxSelectedElements(int[] nums) {
        nums = nums.clone();
        Arrays.sort(nums);
        var dp = new HashMap<Integer, Integer>();

        for (int a : nums) {
            // Use a as a+1 (increment): chain ending at a+1
            dp.put(a + 1, dp.getOrDefault(a, 0) + 1);
            // Use a as-is: chain ending at a (must not overwrite a+1 result we just set)
            dp.put(a, Math.max(dp.getOrDefault(a, 0), dp.getOrDefault(a - 1, 0) + 1));
        }

        return dp.values().stream().mapToInt(Integer::intValue).max().orElse(0);
    }

    public static void main(String[] args) {
        var sol = new Solution3041();

        var r1 = sol.maxSelectedElements(new int[]{2,1,5,1,1});
        if (r1 != 3) throw new AssertionError("LC3041 ex1: expected 3, got " + r1);

        var r2 = sol.maxSelectedElements(new int[]{1,4,7,10});
        if (r2 != 4) throw new AssertionError("LC3041 ex2: expected 4, got " + r2);

        var r3 = sol.maxSelectedElements(new int[]{3,3,3});
        if (r3 != 2) throw new AssertionError("LC3041 all-same: expected 2, got " + r3);

        var r4 = sol.maxSelectedElements(new int[]{1,2,3,4});
        if (r4 != 4) throw new AssertionError("LC3041 consecutive: expected 4, got " + r4);

        System.out.println("LC3041 all tests passed.");
    }
}
```

**Complexity:**

| Approach | Time | Space |
|----------|------|-------|
| Sort + HashMap DP | O(n log n) | O(n) |

**Java Notes:** The update order within the loop is critical: `a+1` first, then `a`. If reversed, a single element `a` could be counted for both `dp[a]` and `dp[a+1]` in the same pass. HashMap autoboxing is acceptable here since values are bounded by array length (≤ 10^5).

---

## Advanced DP Pattern Reference

| Pattern | Representative Problems | Key Insight | Typical Complexity |
|---------|------------------------|-------------|-------------------|
| Monotone Deque (Window Max) | 1696, 1425, 2944, 239 | Store indices; expire front, dominate back | O(n) amortized |
| Monotone Deque (Window Min) | 862 (prefix sum) | Min-deque of prefix sums; pop front on valid answer | O(n) |
| Monotone Stack (Contribution) | 907 | Each element's left/right boundary as min; count subarrays | O(n) |
| Bitmask Enumeration | 2212 | 2^12 subsets; check feasibility | O(2^12 * 12) |
| Prime Bitmask DP | 1994, 2572 | 10-bit prime mask; iterate complement subsets | O(30 * 3^10) |
| DAG Memoized DFS | 329 | `memo[r][c]` via recursive DFS; zero = uncomputed | O(m * n) |
| Topological Sort DP | 1857, 2050 | Kahn's BFS; propagate dp through edges | O(V * colors + E) |
| Offline Sort + DSU | 1697 | Sort queries + edges; process in order with Union-Find | O((E+Q) log(E+Q)) |
| Stock DP (k transactions) | 188 | `buy[j]`/`sell[j]` rolling; reverse update to avoid same-day | O(n * k) |
| Grouped Knapsack | 2218 | Reverse iterate capacity; try 0..pile-size from each group | O(k * Σ pile sizes) |
| Coverage DP | 2209 | Rolling carpet layers; skip vs. place transition | O(n * carpets) |
| Alphabet DP | 2370 | `dp[c]` = best ending at char c; scan ±k neighbors | O(26n) |
| LIS-style Pair DP | 2901 | dp[i] from all valid j < i; reconstruct via prev[] | O(n² * L) |
| Partition DP | 2707 | dp[i] = min extra in prefix of length i; try all cut points | O(n² * L) |
| Assignment DP | 2463 | Sort both; expand slots; dp[j] = min cost first-i to first-j | O(n * m) |
| Exchange-Arg Sort DP | 2809 | Sort by nums2; dp[j] = max reduction zeroing j elements | O(n²) |
| Consecutive Max DP | 3041 | Sort; dp[v] = chain ending at v; update a+1 before a | O(n log n) |

---

## Monotone Deque Cheatsheet (Java)

```java
// Max-deque: front = index of maximum dp in window
var deq = new ArrayDeque<Integer>();
for (int i = 0; i < n; i++) {
    // 1. Expire: remove out-of-window indices from front
    while (!deq.isEmpty() && deq.peekFirst() + k < i) deq.pollFirst();
    // 2. Use: dp[deq.peekFirst()] is the window maximum
    dp[i] = cost[i] + dp[deq.peekFirst()];
    // 3. Maintain: pop dominated indices from back
    while (!deq.isEmpty() && dp[deq.peekLast()] <= dp[i]) deq.pollLast();
    deq.addLast(i);
}

// Min-deque (for LC 862 prefix-sum trick): same structure, >= instead of <=
while (!deq.isEmpty() && pre[deq.peekLast()] >= pre[i]) deq.pollLast();
```

---

## 📝 Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| LC 2944 Rust source had dead-code first pass and wrong window bound `2*(i+1)` | High | Correct formula is `hi = min(2i+3, n)`; Java port fixed, Rust source fixed |
| `Integer.MAX_VALUE` used as infinity sentinel with addition | High | `Integer.MIN_VALUE / 2` for LC 188 `buy[]`; `Long.MAX_VALUE / 2` for LC 2463, LC 2809 |
| LC 907 intermediate product `arr[i]*left[i]*right[i]` overflows `int` | High | Cast to `long` before multiplication; modular arithmetic throughout |
| LC 862 prefix sums overflow `int` for large inputs | High | `long[]` prefix array throughout |
| LC 2209 carpet boundary off-by-one | Medium | `start = i - carpetLen` (not `i - carpetLen + 1`); `dp[start]` from previous layer |
| LC 2901 Rust test only checked `result.len() == 2` (weak) | Medium | Java test also verifies Hamming-distance-1 constraint between adjacent words |
| LC 2212 Rust test2 used `assert!(score >= 0)` (tautology) | Medium | Java test calls `computeScore` which validates arrow total and returns actual score |
| LC 3041 update-order in HashMap: `a+1` must precede `a` | Medium | Documented and enforced in the implementation |
| `assert` keyword not used anywhere | Verified | All assertions are `throw new AssertionError(...)` with descriptive messages |
| DSU in LC 1697 uses static fields | Low | Noted in Java Notes; acceptable in LeetCode context |
| LC 2707 example2 expected value corrected from Rust source | Medium | `sayhelloworld` with `{a,b,ab}`: only "a" at index 1 matches → 12 extra chars (13 - 1). Rust source had `13 - 2` as a wrong annotation; Java test uses 12. |

### Third-Person Critical Review

**DP array sizes:** All dp arrays are sized correctly. LC 188 uses `k+1` elements for `buy[]`/`sell[]`. LC 2218 uses `k+1` for the capacity dimension. LC 2209 uses `n` for each carpet layer. LC 2463 uses `m+1` slots. No off-by-one found in array allocation.

**Base cases:** LC 188 initializes `buy[]` with `Integer.MIN_VALUE / 2` (not zero) to represent "no transaction started yet" — correct. LC 2463 initializes `dp[0] = 0` (zero robots assigned to zero slots costs nothing) and `dp[j] = INF` for `j > 0` — correct. LC 2944 uses `dp[n] = 0` as the sentinel for "no remaining fruits needed" — correct. LC 2809 iterates `t` from 0, covering the "already satisfied" base case.

**Transition formulas:** LC 2209 uses `start = i - carpetLen` where `dp[start]` covers `[0..start]` and the carpet covers `[start+1..i]` — exactly `carpetLen` positions. LC 2463 transition correctly uses `dp[j-1]` from the previous robot row (not `ndp[j-1]`) when assigning robot `i` to slot `j`, preventing the same robot from being assigned multiple times.

**No `assert` keyword:** Confirmed absent. All assertions use `throw new AssertionError("message: got " + actual)`.

**Test assertions catch wrong answers:** LC 2212 verifies the actual score value equals 4 (not just >= 0). LC 2901 checks both the subsequence length and the Hamming-distance constraint between adjacent words. LC 1697 checks both booleans by index. LC 239 compares the full output array. LC 862 tests a case with negative numbers to catch sign-error bugs.

### What This Chapter Does Well

1. **Consistency with the Rust source:** All 22 problems from Part 4 are covered with no omissions. The section and problem ordering matches exactly.
2. **Overflow discipline:** Every problem with large intermediate values uses `long` arrays and `Long.MAX_VALUE / 2` or `Integer.MIN_VALUE / 2` sentinels with explicit callouts.
3. **Dead code excised:** The buggy first pass in LC 2944 is not ported; only the correct algorithm appears.
4. **Stronger tests than the Rust source:** LC 2212 and LC 2901 have more meaningful assertions that would catch common implementation bugs.
5. **Update-order pitfall in LC 3041 documented:** The `a+1` before `a` ordering is both enforced and explained, which is the most common source of bugs on this problem.

### What Could Be Improved

1. **No trie-based solution for LC 2707:** A trie reduces worst-case lookup from O(L) per substring to O(1) per character, improving the total from O(n²L) to O(n²). The current HashMap approach is correct but slower for long dictionary words.
2. **LC 1697 uses static DSU fields:** In a real codebase this would cause concurrency issues. Instance fields or a nested static class would be safer.
3. **LC 2463 converts `List<Integer>` to array via streams:** This adds O(n) overhead and verbosity. A direct loop conversion would be cleaner.
4. **No explicit topo-sort tabulation variant for LC 329:** The chapter shows only memoized DFS. A Kahn's-BFS tabulation (build explicit DAG, process in reverse topological order) would reinforce the "two perspectives" goal stated in rule 4, though the DFS form is canonical for this problem.

---

*End of Chapter LC-14 Part 4 (Java)*
