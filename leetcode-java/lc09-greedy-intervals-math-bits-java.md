# Chapter LC-09: Greedy, Intervals, Math & Geometry, Bit Manipulation — Java 17+

> **Chapter goal:** Twenty-nine Blind75/NeetCode150 problems across four domains. Every solution is a complete, runnable snippet with a `public static void main` test driver using `throw new AssertionError(...)` — no JUnit, no `assert` keyword.
> Target audience: Rust developers mapping Java idioms onto known algorithms.

> **Java vs Rust callout:** Java lacks unsigned integer types (`u32`/`u64`). For bit operations that must treat a value as unsigned, use `>>>` (unsigned right shift) instead of `>>` (arithmetic right shift). Rust bit ops are type-safe — the type itself (`u32` vs `i32`) dictates the behavior. In Java you must choose the right operator manually. Additionally, Java's `Integer.bitCount()` and `Integer.reverse()` are static utility methods; Rust's `count_ones()` and `reverse_bits()` are primitive methods on the value itself.

**Java quick-reference for this chapter**

| Java pattern | Rust equivalent |
|---|---|
| `x & y`, `x \| y`, `x ^ y`, `~x` | `x & y`, `x \| y`, `x ^ y`, `!x` |
| `x << n`, `x >> n`, `x >>> n` | `x << n`, `x >> n` (signed); `>>>` has no Rust primitive analogue — use `u32` |
| `Integer.bitCount(x)` | `x.count_ones()` |
| `Integer.reverse(x)` | `x.reverse_bits()` |
| `Arrays.sort(arr, (a,b) -> Integer.compare(a[0], b[0]))` | `arr.sort_by_key(\|iv\| iv[0])` |
| `Math.max(a, b)` | `a.max(b)` |
| `(long) n` widening cast | `n as i64` |
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

**Key insight (Kadane's algorithm).** Maintain a running sum. At each element decide whether to extend the current subarray or start fresh. If `cur + num < num`, drop the prefix and start at `num`. Track the global max throughout.

```java
import java.util.Arrays;

class Solution {
    public int maxSubArray(int[] nums) {
        int maxSum = nums[0];
        int cur = nums[0];
        for (int i = 1; i < nums.length; i++) {
            cur = Math.max(nums[i], cur + nums[i]);
            maxSum = Math.max(maxSum, cur);
        }
        return maxSum;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.maxSubArray(new int[]{-2, 1, -3, 4, -1, 2, 1, -5, 4});
        if (got != 6) throw new AssertionError("test_mixed: got " + got);

        got = sol.maxSubArray(new int[]{-1});
        if (got != -1) throw new AssertionError("test_single_neg: got " + got);

        got = sol.maxSubArray(new int[]{-3, -2, -1});
        if (got != -1) throw new AssertionError("test_all_negative: got " + got);

        got = sol.maxSubArray(new int[]{5, 4, -1, 7, 8});
        if (got != 23) throw new AssertionError("test_all_positive: got " + got);

        System.out.println("LC53 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** `Math.max(a, b)` replaces Rust's `a.max(b)`. Both compile to the same CPU instruction on modern JVMs. `var sol = new Solution()` uses Java 10+ local-variable type inference — concise but retains full type safety.

---

### LC #55 — Jump Game

**Problem.** You are at index 0 in an array where `nums[i]` is the max jump from position `i`. Return `true` if you can reach the last index.

**Key insight.** Track the furthest reachable index. Iterate left to right; if the current index exceeds `reach`, it is unreachable. Update `reach` at each step.

```java
class Solution {
    public boolean canJump(int[] nums) {
        int reach = 0;
        for (int i = 0; i < nums.length; i++) {
            if (i > reach) return false;
            reach = Math.max(reach, i + nums[i]);
        }
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.canJump(new int[]{2, 3, 1, 1, 4}))
            throw new AssertionError("test_reachable: expected true");

        if (sol.canJump(new int[]{3, 2, 1, 0, 4}))
            throw new AssertionError("test_unreachable: expected false");

        if (!sol.canJump(new int[]{0}))
            throw new AssertionError("test_single: expected true");

        System.out.println("LC55 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** A plain index loop is idiomatic here — Java's `for` loop is equivalent to Rust's `enumerate()` but simpler when the index itself is the operand.

---

### LC #45 — Jump Game II

**Problem.** Same setup as Jump Game. Return the **minimum number of jumps** to reach the last index (guaranteed reachable).

**Key insight (greedy BFS).** Treat each jump as a "level." Track `curEnd` (current window) and `farthest` (max reach within this window). When you hit `curEnd`, increment jumps and advance the window.

```java
class Solution {
    public int jump(int[] nums) {
        int jumps = 0, curEnd = 0, farthest = 0;
        for (int i = 0; i < nums.length - 1; i++) {
            farthest = Math.max(farthest, i + nums[i]);
            if (i == curEnd) {
                jumps++;
                curEnd = farthest;
            }
        }
        return jumps;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.jump(new int[]{2, 3, 1, 1, 4});
        if (got != 2) throw new AssertionError("test_basic: got " + got);

        got = sol.jump(new int[]{2, 3, 0, 1, 4});
        if (got != 2) throw new AssertionError("test_greedy: got " + got);

        got = sol.jump(new int[]{0});
        if (got != 0) throw new AssertionError("test_single: got " + got);

        System.out.println("LC45 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** The loop bound `nums.length - 1` mirrors Rust's `0..n - 1` half-open range. We stop one short to avoid processing the last element unnecessarily.

---

### LC #134 — Gas Station

**Problem.** Given `gas[i]` (gas available) and `cost[i]` (gas to reach next station), find the starting station index for a complete circuit, or -1 if none exists.

**Key insight.** If total gas >= total cost, a solution exists. Greedily pick the start: accumulate `tank`; when it goes negative, reset `start` to the next station and reset `tank`.

```java
class Solution {
    public int canCompleteCircuit(int[] gas, int[] cost) {
        int total = 0, tank = 0, start = 0;
        for (int i = 0; i < gas.length; i++) {
            int diff = gas[i] - cost[i];
            total += diff;
            tank += diff;
            if (tank < 0) {
                start = i + 1;
                tank = 0;
            }
        }
        return total < 0 ? -1 : start;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.canCompleteCircuit(new int[]{1,2,3,4,5}, new int[]{3,4,5,1,2});
        if (got != 3) throw new AssertionError("test_valid: got " + got);

        got = sol.canCompleteCircuit(new int[]{2,3,4}, new int[]{3,4,3});
        if (got != -1) throw new AssertionError("test_no_solution: got " + got);

        System.out.println("LC134 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** A ternary `total < 0 ? -1 : start` replaces Rust's `if total < 0 { -1 } else { start as i32 }`. Both are expressions in their respective languages.

---

### LC #846 — Hand of Straights

**Problem.** Given a hand of cards and group size `groupSize`, determine if all cards can be arranged into groups of consecutive values.

**Key insight.** Count frequencies with a `TreeMap` (sorted by key). For each key with count > 0, consume `groupSize` consecutive keys, decrementing each. If any required key is missing, return false.

```java
import java.util.ArrayList;
import java.util.Map;
import java.util.TreeMap;

class Solution {
    public boolean isNStraightHand(int[] hand, int groupSize) {
        if (hand.length % groupSize != 0) return false;
        var count = new TreeMap<Integer, Integer>();
        for (int card : hand) {
            count.merge(card, 1, Integer::sum);
        }
        // Snapshot keys to avoid ConcurrentModificationException:
        // count.put() below updates existing keys (never inserts new ones),
        // but a defensive copy is clearer and safer.
        var keys = new ArrayList<>(count.keySet());
        for (int key : keys) {
            int freq = count.get(key);
            if (freq == 0) continue;
            for (int offset = 0; offset < groupSize; offset++) {
                int needed = count.getOrDefault(key + offset, 0);
                if (needed < freq) return false;
                count.put(key + offset, needed - freq);
            }
        }
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.isNStraightHand(new int[]{1,2,3,6,2,3,4,7,8}, 3))
            throw new AssertionError("test_valid_hand: expected true");

        if (sol.isNStraightHand(new int[]{1,2,3,4,5}, 4))
            throw new AssertionError("test_invalid_hand: expected false");

        System.out.println("LC846 OK");
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Java notes.** `TreeMap` keeps keys in natural sorted order — exactly like Rust's `BTreeMap`. Iterating `count.keySet()` gives keys in ascending order without an extra sort step. `merge(key, 1, Integer::sum)` is the Java frequency-count idiom; Rust uses `entry(key).or_insert(0) += 1`.

---

### LC #1899 — Merge Triplets to Form Target Triplet

**Problem.** Given a list of triplets and a target triplet, determine if you can select a subset of triplets and take the element-wise max to equal the target.

**Key insight.** Ignore triplets containing any value exceeding the corresponding target value (they would corrupt the result). Among the valid triplets, check if the element-wise max equals the target.

```java
class Solution {
    public boolean mergeTriplets(int[][] triplets, int[] target) {
        int a = 0, b = 0, c = 0;
        int ta = target[0], tb = target[1], tc = target[2];
        for (int[] t : triplets) {
            if (t[0] > ta || t[1] > tb || t[2] > tc) continue;
            a = Math.max(a, t[0]);
            b = Math.max(b, t[1]);
            c = Math.max(c, t[2]);
        }
        return a == ta && b == tb && c == tc;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.mergeTriplets(
                new int[][]{{2,5,3},{1,8,4},{1,7,5}},
                new int[]{2,7,5}))
            throw new AssertionError("test_possible: expected true");

        if (sol.mergeTriplets(
                new int[][]{{3,4,5},{4,5,6}},
                new int[]{3,2,5}))
            throw new AssertionError("test_impossible: expected false");

        System.out.println("LC1899 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** `int[][]` is Java's native 2-D array type — equivalent to `Vec<Vec<i32>>` in Rust but stack-allocated for fixed sizes. The enhanced `for (int[] t : triplets)` loop iterates over rows cleanly.

---

### LC #763 — Partition Labels

**Problem.** Partition string `s` into as many parts as possible such that each letter appears in at most one part. Return the sizes of those parts.

**Key insight.** Record the last occurrence of each character. Iterate through the string: the end of the current partition is the max last-occurrence seen so far. When `i == end`, a partition boundary is found.

```java
import java.util.ArrayList;
import java.util.List;

class Solution {
    public List<Integer> partitionLabels(String s) {
        int[] last = new int[26];
        for (int i = 0; i < s.length(); i++) {
            last[s.charAt(i) - 'a'] = i;
        }
        var result = new ArrayList<Integer>();
        int start = 0, end = 0;
        for (int i = 0; i < s.length(); i++) {
            end = Math.max(end, last[s.charAt(i) - 'a']);
            if (i == end) {
                result.add(end - start + 1);
                start = i + 1;
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var got = sol.partitionLabels("ababcbacadefegdehijhklij");
        if (!got.equals(List.of(9, 7, 8)))
            throw new AssertionError("test_basic: got " + got);

        got = sol.partitionLabels("eccbbbbdec");
        if (!got.equals(List.of(10)))
            throw new AssertionError("test_single_part: got " + got);

        System.out.println("LC763 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1) (26-element fixed array).

**Java notes.** `int[] last = new int[26]` is a fixed-size array initialized to 0 — equivalent to Rust's `[0usize; 26]`. `s.charAt(i) - 'a'` is the Java analog of `b - b'a'` byte arithmetic.

---

### LC #678 — Valid Parenthesis String

**Problem.** Given a string with `'('`, `')'`, and `'*'` (wildcard: empty/`(`/`)`), return `true` if the string can be valid.

**Key insight.** Track the range `[lo, hi]` of possible open-parenthesis counts. `'('` increments both; `')'` decrements both; `'*'` widens the range. If `hi < 0` it is invalid. At the end, `lo == 0` means balance is achievable.

```java
class Solution {
    public boolean checkValidString(String s) {
        int lo = 0, hi = 0;
        for (int i = 0; i < s.length(); i++) {
            // Java 17 switch expression — natural fit for character dispatch
            int[] delta = switch (s.charAt(i)) {
                case '(' -> new int[]{1, 1};
                case ')' -> new int[]{-1, -1};
                default  -> new int[]{-1, 1};  // '*'
            };
            lo += delta[0];
            hi += delta[1];
            if (hi < 0) return false;
            lo = Math.max(lo, 0);
        }
        return lo == 0;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.checkValidString("(*))"))
            throw new AssertionError("test1: expected true");
        if (!sol.checkValidString("(*"))
            throw new AssertionError("test2: expected true");
        if (!sol.checkValidString("()"))
            throw new AssertionError("test3: expected true");
        if (sol.checkValidString(")"))
            throw new AssertionError("test_invalid: expected false");

        System.out.println("LC678 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** The Java 17 switch expression (`switch (ch) { case '(' -> ...; }`) replaces Rust's `match`. Both are expressions that return a value — here each arm yields a two-element `int[]` for `[lo_delta, hi_delta]`. The `default` arm covers `'*'`.

---

## Part 2 — Intervals

---

### LC #57 — Insert Interval

**Problem.** Given a sorted non-overlapping list of intervals and a new interval, insert it (merging overlaps) and return the updated list.

**Key insight.** Three phases: collect intervals that end before the new one starts; merge all overlapping intervals; collect the rest.

```java
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Solution {
    public int[][] insert(int[][] intervals, int[] newInterval) {
        var result = new ArrayList<int[]>();
        int i = 0, n = intervals.length;
        int ns = newInterval[0], ne = newInterval[1];

        // Phase 1: add intervals entirely before new interval
        while (i < n && intervals[i][1] < ns) {
            result.add(intervals[i++]);
        }
        // Phase 2: merge overlapping intervals
        while (i < n && intervals[i][0] <= ne) {
            ns = Math.min(ns, intervals[i][0]);
            ne = Math.max(ne, intervals[i][1]);
            i++;
        }
        result.add(new int[]{ns, ne});
        // Phase 3: add remaining intervals
        while (i < n) {
            result.add(intervals[i++]);
        }
        return result.toArray(new int[0][]);
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] got = sol.insert(new int[][]{{1,3},{6,9}}, new int[]{2,5});
        if (!Arrays.deepEquals(got, new int[][]{{1,5},{6,9}}))
            throw new AssertionError("test_overlap_merge: got " + Arrays.deepToString(got));

        got = sol.insert(new int[][]{{1,2},{3,5},{6,7},{8,10},{12,16}}, new int[]{4,8});
        if (!Arrays.deepEquals(got, new int[][]{{1,2},{3,10},{12,16}}))
            throw new AssertionError("test_multi_merge: got " + Arrays.deepToString(got));

        got = sol.insert(new int[][]{}, new int[]{5,7});
        if (!Arrays.deepEquals(got, new int[][]{{5,7}}))
            throw new AssertionError("test_empty: got " + Arrays.deepToString(got));

        System.out.println("LC57 OK");
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Java notes.** `result.toArray(new int[0][])` converts a `List<int[]>` to `int[][]` — the empty-array hint is the standard Java idiom. `Arrays.deepEquals` and `Arrays.deepToString` handle 2-D array comparison and display.

---

### LC #56 — Merge Intervals

**Problem.** Given a list of intervals, merge all overlapping intervals and return the result.

**Key insight.** Sort by start. Iterate; if the current interval's start <= last merged interval's end, merge. Otherwise push as new.

```java
import java.util.ArrayList;
import java.util.Arrays;

class Solution {
    public int[][] merge(int[][] intervals) {
        Arrays.sort(intervals, (a, b) -> Integer.compare(a[0], b[0]));
        var merged = new ArrayList<int[]>();
        for (int[] iv : intervals) {
            if (!merged.isEmpty() && iv[0] <= merged.get(merged.size() - 1)[1]) {
                merged.get(merged.size() - 1)[1] =
                        Math.max(merged.get(merged.size() - 1)[1], iv[1]);
            } else {
                merged.add(iv);
            }
        }
        return merged.toArray(new int[0][]);
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] got = sol.merge(new int[][]{{1,3},{2,6},{8,10},{15,18}});
        if (!Arrays.deepEquals(got, new int[][]{{1,6},{8,10},{15,18}}))
            throw new AssertionError("test_overlapping: got " + Arrays.deepToString(got));

        got = sol.merge(new int[][]{{1,4},{4,5}});
        if (!Arrays.deepEquals(got, new int[][]{{1,5}}))
            throw new AssertionError("test_touching: got " + Arrays.deepToString(got));

        System.out.println("LC56 OK");
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Java notes.** `Integer.compare(a[0], b[0])` is used instead of `a[0] - b[0]` to avoid overflow for large interval values. Rust's `sort_by_key(|iv| iv[0])` cannot overflow because `usize` arithmetic is checked in debug mode; Java subtraction is silently modular.

---

### LC #435 — Non-Overlapping Intervals

**Problem.** Find the minimum number of intervals to remove to make the rest non-overlapping.

**Key insight.** Sort by end time. Greedily keep an interval if its start >= the last kept end. Count removals.

```java
import java.util.Arrays;

class Solution {
    public int eraseOverlapIntervals(int[][] intervals) {
        Arrays.sort(intervals, (a, b) -> Integer.compare(a[1], b[1]));
        int removed = 0;
        int prevEnd = Integer.MIN_VALUE;
        for (int[] iv : intervals) {
            if (iv[0] >= prevEnd) {
                prevEnd = iv[1];
            } else {
                removed++;
            }
        }
        return removed;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.eraseOverlapIntervals(new int[][]{{1,2},{2,3},{3,4},{1,3}});
        if (got != 1) throw new AssertionError("test_basic: got " + got);

        got = sol.eraseOverlapIntervals(new int[][]{{1,2},{1,2},{1,2}});
        if (got != 2) throw new AssertionError("test_all_overlap: got " + got);

        got = sol.eraseOverlapIntervals(new int[][]{{1,2},{2,3}});
        if (got != 0) throw new AssertionError("test_no_overlap: got " + got);

        System.out.println("LC435 OK");
    }
}
```

**Complexity.** Time O(n log n), Space O(1) extra.

**Java notes.** Sorting by end (`a[1]`) is the key insight: keeping the interval that ends earliest maximizes the space for future intervals. `Integer.compare(a[1], b[1])` is overflow-safe.

---

### LC #252 — Meeting Rooms

**Problem.** Given a list of meeting time intervals, determine if a person can attend all meetings (no overlaps).

**Key insight.** Sort by start. Check each adjacent pair: if the previous meeting ends after the next one starts, there is a conflict.

```java
import java.util.Arrays;

class Solution {
    public boolean canAttendMeetings(int[][] intervals) {
        Arrays.sort(intervals, (a, b) -> Integer.compare(a[0], b[0]));
        for (int i = 1; i < intervals.length; i++) {
            if (intervals[i - 1][1] > intervals[i][0]) return false;
        }
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.canAttendMeetings(new int[][]{{0,30},{35,50}}))
            throw new AssertionError("test_no_conflict: expected true");

        if (!sol.canAttendMeetings(new int[][]{}))
            throw new AssertionError("test_empty: expected true");

        if (sol.canAttendMeetings(new int[][]{{0,30},{5,10},{15,20}}))
            throw new AssertionError("test_conflict: expected false");

        System.out.println("LC252 OK");
    }
}
```

**Complexity.** Time O(n log n), Space O(1) extra.

**Java notes.** Rust uses `.windows(2)` to compare adjacent pairs with no index arithmetic. Java uses an explicit index loop `i = 1; i < n; i++` comparing `intervals[i-1]` to `intervals[i]` — equally clear.

---

### LC #253 — Meeting Rooms II

**Problem.** Given meeting intervals, return the minimum number of conference rooms required.

**Key insight.** Separate start and end times, sort each, and use a two-pointer sweep. When a meeting starts before the earliest-ending meeting finishes, allocate a new room; otherwise reuse the room that just freed up.

```java
import java.util.Arrays;

class Solution {
    public int minMeetingRooms(int[][] intervals) {
        int n = intervals.length;
        int[] starts = new int[n];
        int[] ends   = new int[n];
        for (int i = 0; i < n; i++) {
            starts[i] = intervals[i][0];
            ends[i]   = intervals[i][1];
        }
        Arrays.sort(starts);
        Arrays.sort(ends);

        int rooms = 0, endPtr = 0;
        for (int i = 0; i < n; i++) {
            if (starts[i] >= ends[endPtr]) {
                endPtr++;   // a room freed up
            } else {
                rooms++;    // need a new room
            }
        }
        return rooms;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.minMeetingRooms(new int[][]{{0,30},{5,10},{15,20}});
        if (got != 2) throw new AssertionError("test_basic: got " + got);

        got = sol.minMeetingRooms(new int[][]{{7,10},{2,4}});
        if (got != 1) throw new AssertionError("test_no_overlap: got " + got);

        System.out.println("LC253 OK");
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Java notes.** `Arrays.sort` on a primitive `int[]` uses dual-pivot quicksort — no comparator lambda, no autoboxing. This is more performant than sorting `Integer[]`.

---

### LC #2285 — Minimum Interval to Include Each Query

**Problem.** Given intervals and queries, for each query return the size of the smallest interval containing the query value, or -1 if none.

**Key insight.** Sort intervals by start and queries by value. Use a min-heap (by interval size) to track active intervals. For each query, add all intervals whose start <= query, then evict intervals that have ended (end < query). The heap top is the answer.

```java
import java.util.Arrays;
import java.util.PriorityQueue;

class Solution {
    public int[] minInterval(int[][] intervals, int[] queries) {
        // Sort intervals by start
        Arrays.sort(intervals, (a, b) -> Integer.compare(a[0], b[0]));

        // Sort queries but remember original positions
        int q = queries.length;
        Integer[] idx = new Integer[q];
        for (int i = 0; i < q; i++) idx[i] = i;
        Arrays.sort(idx, (a, b) -> Integer.compare(queries[a], queries[b]));

        // min-heap: [size, end]
        var heap = new PriorityQueue<int[]>((a, b) -> Integer.compare(a[0], b[0]));
        int[] result = new int[q];
        Arrays.fill(result, -1);
        int ivIdx = 0;

        for (int qi : idx) {
            int queryVal = queries[qi];
            // Push all intervals whose start <= queryVal
            while (ivIdx < intervals.length && intervals[ivIdx][0] <= queryVal) {
                int size = intervals[ivIdx][1] - intervals[ivIdx][0] + 1;
                heap.offer(new int[]{size, intervals[ivIdx][1]});
                ivIdx++;
            }
            // Pop expired intervals
            while (!heap.isEmpty() && heap.peek()[1] < queryVal) {
                heap.poll();
            }
            if (!heap.isEmpty()) {
                result[qi] = heap.peek()[0];
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[] got = sol.minInterval(
                new int[][]{{1,4},{2,4},{3,6},{4,4}},
                new int[]{2,3,4,5});
        if (!Arrays.equals(got, new int[]{3,3,1,4}))
            throw new AssertionError("test_basic: got " + Arrays.toString(got));

        got = sol.minInterval(
                new int[][]{{2,3},{2,5},{1,8},{20,25}},
                new int[]{2,19,22});
        if (!Arrays.equals(got, new int[]{2,-1,6}))
            throw new AssertionError("test_no_match: got " + Arrays.toString(got));

        System.out.println("LC2285 OK");
    }
}
```

**Complexity.** Time O((n + q) log n), Space O(n + q).

**Java notes.** Java's `PriorityQueue` is a min-heap by default — the opposite of Rust's `BinaryHeap` which is a max-heap. Rust requires `Reverse(...)` wrapping; Java requires an explicit comparator only if you want a max-heap. `Integer[]` is used for the index array so `Arrays.sort` can accept a lambda comparator (primitive `int[]` cannot be sorted with a comparator).

---

## Part 3 — Math & Geometry

---

### LC #48 — Rotate Image

**Problem.** Rotate an n x n matrix 90 degrees clockwise **in place**.

**Key insight.** Two steps: (1) transpose — swap `matrix[i][j]` and `matrix[j][i]`; (2) reverse each row.

```java
import java.util.Arrays;

class Solution {
    public void rotate(int[][] matrix) {
        int n = matrix.length;
        // Step 1: transpose
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                int tmp = matrix[i][j];
                matrix[i][j] = matrix[j][i];
                matrix[j][i] = tmp;
            }
        }
        // Step 2: reverse each row
        for (int[] row : matrix) {
            int lo = 0, hi = row.length - 1;
            while (lo < hi) {
                int tmp = row[lo];
                row[lo++] = row[hi];
                row[hi--] = tmp;
            }
        }
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] m = {{1,2,3},{4,5,6},{7,8,9}};
        sol.rotate(m);
        if (!Arrays.deepEquals(m, new int[][]{{7,4,1},{8,5,2},{9,6,3}}))
            throw new AssertionError("test_3x3: got " + Arrays.deepToString(m));

        int[][] m2 = {{5,1,9,11},{2,4,8,10},{13,3,6,7},{15,14,12,16}};
        sol.rotate(m2);
        if (!Arrays.deepEquals(m2, new int[][]{{15,13,2,5},{14,3,4,1},{12,6,8,9},{16,7,10,11}}))
            throw new AssertionError("test_4x4: got " + Arrays.deepToString(m2));

        System.out.println("LC48 OK");
    }
}
```

**Complexity.** Time O(n²), Space O(1).

**Java notes.** Java has no `row.reverse()` slice method. The manual two-pointer swap replaces Rust's `row.reverse()`. The in-place swap uses a `tmp` variable — the same pattern Rust requires to avoid borrow-checker conflicts.

---

### LC #54 — Spiral Matrix

**Problem.** Given an m x n matrix, return all elements in spiral (clockwise) order.

**Key insight.** Maintain four boundaries: `top`, `bottom`, `left`, `right`. Peel off one layer at a time, shrinking boundaries inward. Guard the bottom and left traversal with boundary checks before each pass.

```java
import java.util.ArrayList;
import java.util.List;

class Solution {
    public List<Integer> spiralOrder(int[][] matrix) {
        var result = new ArrayList<Integer>();
        int top = 0, bottom = matrix.length - 1;
        int left = 0, right = matrix[0].length - 1;

        while (top <= bottom && left <= right) {
            for (int col = left; col <= right; col++)
                result.add(matrix[top][col]);
            top++;
            for (int row = top; row <= bottom; row++)
                result.add(matrix[row][right]);
            right--;
            if (top <= bottom) {
                for (int col = right; col >= left; col--)
                    result.add(matrix[bottom][col]);
                bottom--;
            }
            if (left <= right) {
                for (int row = bottom; row >= top; row--)
                    result.add(matrix[row][left]);
                left++;
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var got = sol.spiralOrder(new int[][]{{1,2,3},{4,5,6},{7,8,9}});
        if (!got.equals(List.of(1,2,3,6,9,8,7,4,5)))
            throw new AssertionError("test_3x3: got " + got);

        got = sol.spiralOrder(new int[][]{{1,2,3,4},{5,6,7,8},{9,10,11,12}});
        if (!got.equals(List.of(1,2,3,4,8,12,11,10,9,5,6,7)))
            throw new AssertionError("test_3x4: got " + got);

        System.out.println("LC54 OK");
    }
}
```

**Complexity.** Time O(m x n), Space O(1) extra.

**Java notes.** Java uses signed `int` indices naturally — no cast from `i32` needed. Rust requires explicit casts when using signed variables as array indices (`col as usize`); Java index arithmetic is always `int`.

---

### LC #73 — Set Matrix Zeroes

**Problem.** If `matrix[i][j] == 0`, set the entire row `i` and column `j` to zero, in place.

**Key insight.** Use the first row and first column as markers. Check whether the first row/column themselves contain a zero before using them as markers, then apply them last.

```java
import java.util.Arrays;

class Solution {
    public void setZeroes(int[][] matrix) {
        int m = matrix.length, n = matrix[0].length;
        boolean firstRowZero = false;
        boolean firstColZero = false;

        for (int j = 0; j < n; j++) if (matrix[0][j] == 0) { firstRowZero = true; break; }
        for (int i = 0; i < m; i++) if (matrix[i][0] == 0) { firstColZero = true; break; }

        // Use row 0 and col 0 as flags for rows/cols 1..
        for (int i = 1; i < m; i++) {
            for (int j = 1; j < n; j++) {
                if (matrix[i][j] == 0) {
                    matrix[i][0] = 0;
                    matrix[0][j] = 0;
                }
            }
        }
        for (int i = 1; i < m; i++) {
            for (int j = 1; j < n; j++) {
                if (matrix[i][0] == 0 || matrix[0][j] == 0) {
                    matrix[i][j] = 0;
                }
            }
        }
        if (firstRowZero) Arrays.fill(matrix[0], 0);
        if (firstColZero) { for (int i = 0; i < m; i++) matrix[i][0] = 0; }
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] m = {{1,1,1},{1,0,1},{1,1,1}};
        sol.setZeroes(m);
        if (!Arrays.deepEquals(m, new int[][]{{1,0,1},{0,0,0},{1,0,1}}))
            throw new AssertionError("test_basic: got " + Arrays.deepToString(m));

        int[][] m2 = {{0,1,2,0},{3,4,5,2},{1,3,1,5}};
        sol.setZeroes(m2);
        if (!Arrays.deepEquals(m2, new int[][]{{0,0,0,0},{0,4,5,0},{0,3,1,0}}))
            throw new AssertionError("test_corner: got " + Arrays.deepToString(m2));

        System.out.println("LC73 OK");
    }
}
```

**Complexity.** Time O(m x n), Space O(1).

**Java notes.** `Arrays.fill(matrix[0], 0)` zeroes the first row in one call. The pattern of using the first row/column as in-place flags is identical between Java and Rust.

---

### LC #202 — Happy Number

**Problem.** A happy number eventually reaches 1 by repeatedly summing the squares of its digits. Return `true` if `n` is happy.

**Key insight.** Use Floyd's cycle detection (slow/fast pointers) to detect loops without a HashSet.

```java
class Solution {
    private int next(int n) {
        int sum = 0;
        while (n > 0) {
            int d = n % 10;
            sum += d * d;
            n /= 10;
        }
        return sum;
    }

    public boolean isHappy(int n) {
        int slow = n, fast = next(n);
        while (fast != 1 && slow != fast) {
            slow = next(slow);
            fast = next(next(fast));
        }
        return fast == 1;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.isHappy(19))  throw new AssertionError("test_happy_19: expected true");
        if (!sol.isHappy(1))   throw new AssertionError("test_happy_1: expected true");
        if (sol.isHappy(2))    throw new AssertionError("test_not_happy: expected false");

        System.out.println("LC202 OK");
    }
}
```

**Complexity.** Time O(log n) per step, O(log n) steps total, Space O(1).

**Java notes.** Floyd's cycle detection is identical in structure between Java and Rust. Java's `%` on positive integers behaves the same as Rust's `%` — both give the remainder.

---

### LC #66 — Plus One

**Problem.** Given a non-empty array representing a non-negative integer (most significant digit first), increment by one.

**Key insight.** Iterate from the right. If digit < 9, increment and return. If digit is 9, set to 0 and carry. If the loop exits, all digits were 9 — prepend a 1.

```java
class Solution {
    public int[] plusOne(int[] digits) {
        for (int i = digits.length - 1; i >= 0; i--) {
            if (digits[i] < 9) {
                digits[i]++;
                return digits;
            }
            digits[i] = 0;
        }
        // All digits were 9 — need a new leading digit
        int[] result = new int[digits.length + 1];
        result[0] = 1;
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[] got = sol.plusOne(new int[]{1, 2, 3});
        if (!java.util.Arrays.equals(got, new int[]{1, 2, 4}))
            throw new AssertionError("test_no_carry: got " + java.util.Arrays.toString(got));

        got = sol.plusOne(new int[]{9, 9, 9});
        if (!java.util.Arrays.equals(got, new int[]{1, 0, 0, 0}))
            throw new AssertionError("test_carry_chain: got " + java.util.Arrays.toString(got));

        got = sol.plusOne(new int[]{9});
        if (!java.util.Arrays.equals(got, new int[]{1, 0}))
            throw new AssertionError("test_single_nine: got " + java.util.Arrays.toString(got));

        System.out.println("LC66 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1) extra (O(n) on all-9 carry).

**Java notes.** Rust's `iter_mut().rev()` maps to a reverse index loop in Java. Rust's `digits.insert(0, 1)` (O(n) shift) maps to allocating a new array of size `digits.length + 1` and setting `result[0] = 1` — new array allocation rather than shifting avoids a second O(n) pass.

---

### LC #50 — Pow(x, n)

**Problem.** Implement `pow(x, n)` for floating-point `x` and integer `n` (including negative `n`).

**Key insight.** Fast exponentiation (binary exponentiation): halve the exponent at each step. For negative `n`, compute `pow(1/x, -n)`. Handle `Integer.MIN_VALUE` via `long` to avoid silent overflow on negation.

```java
class Solution {
    public double myPow(double x, int n) {
        double base = x;
        long exp = n;   // widen to long: -Integer.MIN_VALUE overflows int silently
        if (exp < 0) {
            base = 1.0 / base;
            exp = -exp;
        }
        double result = 1.0;
        while (exp > 0) {
            if ((exp & 1) == 1) result *= base;
            base *= base;
            exp >>= 1;
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        double got = sol.myPow(2.0, 10);
        if (Math.abs(got - 1024.0) > 1e-9)
            throw new AssertionError("test_positive_exp: got " + got);

        got = sol.myPow(2.0, -2);
        if (Math.abs(got - 0.25) > 1e-9)
            throw new AssertionError("test_negative_exp: got " + got);

        got = sol.myPow(5.0, 0);
        if (got != 1.0)
            throw new AssertionError("test_zero_exp: got " + got);

        // Integer.MIN_VALUE: 2^(-2147483648) is effectively 0.
        // A buggy int-based negation returns 1.0 (loop never runs); correct long-based
        // negation returns a value extremely close to 0.0.
        double check = sol.myPow(2.0, Integer.MIN_VALUE);
        if (check > 1e-9)
            throw new AssertionError("test_min_exp: expected ~0.0, got " + check);

        System.out.println("LC50 OK");
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java notes.** `-Integer.MIN_VALUE == Integer.MIN_VALUE` in Java (silent two's-complement wrap — no panic). Widening to `long N = n` before negating mirrors Rust's `n as i64`. This is the most critical correctness issue in this problem. Using `(exp & 1) == 1` instead of `exp % 2 == 1` avoids a division and works identically.

---

### LC #43 — Multiply Strings

**Problem.** Given two non-negative integers `num1` and `num2` as strings, return their product as a string. Do not use built-in BigInteger or direct numeric conversion.

**Key insight.** Elementary-school multiplication: digits at positions `i` and `j` contribute to positions `i + j` and `i + j + 1` in the result array.

```java
class Solution {
    public String multiply(String num1, String num2) {
        int m = num1.length(), n = num2.length();
        int[] pos = new int[m + n];

        for (int i = m - 1; i >= 0; i--) {
            for (int j = n - 1; j >= 0; j--) {
                int mul = (num1.charAt(i) - '0') * (num2.charAt(j) - '0');
                int p1 = i + j, p2 = i + j + 1;
                int sum = mul + pos[p2];
                pos[p2] = sum % 10;
                pos[p1] += sum / 10;
            }
        }

        var sb = new StringBuilder();
        for (int d : pos) {
            if (sb.length() == 0 && d == 0) continue;  // skip leading zeros
            sb.append(d);
        }
        return sb.length() == 0 ? "0" : sb.toString();
    }

    public static void main(String[] args) {
        var sol = new Solution();

        String got = sol.multiply("2", "3");
        if (!got.equals("6")) throw new AssertionError("test_small: got " + got);

        got = sol.multiply("123", "456");
        if (!got.equals("56088")) throw new AssertionError("test_multi_digit: got " + got);

        got = sol.multiply("0", "12345");
        if (!got.equals("0")) throw new AssertionError("test_zero: got " + got);

        System.out.println("LC43 OK");
    }
}
```

**Complexity.** Time O(m x n), Space O(m + n).

**Java notes.** `StringBuilder` is used instead of string concatenation inside the loop — equivalent to Rust's `.collect::<String>()` over an iterator. `charAt(i) - '0'` is the Java digit-extraction idiom; Rust uses `b[i] - b'0'` on byte slices.

---

### LC #2013 — Detect Squares

**Problem.** Design a data structure that (1) adds points, and (2) given a query point, counts axis-aligned squares that can be formed with the query point as one corner.

**Key insight.** For query `(px, py)`: for each point `(px, y)` on the same x-column (y != py), try side length `d = |y - py|`. Check existence of both `(px+d, py)`, `(px+d, y)` and `(px-d, py)`, `(px-d, y)` using a point-count map.

```java
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// Note: DetectSquares is a standalone class, not a nested Solution class,
// because LeetCode presents it as a class-design problem.
class DetectSquares {
    // Encode (x,y) as a long key: (x << 20) | y (coordinates fit in 20 bits per LeetCode constraints)
    private final Map<Long, Integer> pointCount = new HashMap<>();
    private final Map<Integer, List<Integer>> xToYs = new HashMap<>();

    private static long key(int x, int y) {
        return ((long) x << 20) | (y & 0xFFFFF);
    }

    public DetectSquares() {}

    public void add(int[] point) {
        int x = point[0], y = point[1];
        pointCount.merge(key(x, y), 1, Integer::sum);
        xToYs.computeIfAbsent(x, k -> new ArrayList<>()).add(y);
    }

    public int count(int[] point) {
        int px = point[0], py = point[1];
        int ans = 0;
        List<Integer> ys = xToYs.getOrDefault(px, List.of());
        for (int y : ys) {
            if (y == py) continue;
            int d = y - py;
            // Try square to the right: corners (px+d, py) and (px+d, y)
            int cntRight1 = pointCount.getOrDefault(key(px + d, py), 0);
            int cntRight2 = pointCount.getOrDefault(key(px + d, y),  0);
            ans += cntRight1 * cntRight2;
            // Try square to the left: corners (px-d, py) and (px-d, y)
            int cntLeft1 = pointCount.getOrDefault(key(px - d, py), 0);
            int cntLeft2 = pointCount.getOrDefault(key(px - d, y),  0);
            ans += cntLeft1 * cntLeft2;
        }
        return ans;
    }

    public static void main(String[] args) {
        var ds = new DetectSquares();
        ds.add(new int[]{3, 10});
        ds.add(new int[]{11, 2});
        ds.add(new int[]{3, 2});

        int got = ds.count(new int[]{11, 10});
        if (got != 1) throw new AssertionError("test_count1: got " + got);

        got = ds.count(new int[]{14, 8});
        if (got != 0) throw new AssertionError("test_count_none: got " + got);

        ds.add(new int[]{11, 2});
        got = ds.count(new int[]{11, 10});
        if (got != 2) throw new AssertionError("test_count_dup: got " + got);

        System.out.println("LC2013 OK");
    }
}
```

**Complexity.** Add: O(1). Count: O(k) where k is the number of points sharing the same x-coordinate as the query point.

**Java notes.** The long-key encoding `((long) x << 20) | (y & 0xFFFFF)` packs two coordinates into a single `long` — faster than a `record Point(int x, int y)` as a map key because it avoids object allocation. With LeetCode's coordinate constraint (0..1000), 10 bits per axis suffices; 20 is generous. This is a standalone class (not nested in `Solution`) to match LeetCode's class-design template format.

---

## Part 4 — Bit Manipulation

---

### LC #136 — Single Number

**Problem.** Every element in the array appears exactly twice except one. Find the single element.

**Key insight.** XOR all numbers: `a ^ a == 0` and `a ^ 0 == a`. All pairs cancel; the single element remains.

```java
class Solution {
    public int singleNumber(int[] nums) {
        int xor = 0;
        for (int n : nums) xor ^= n;
        return xor;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.singleNumber(new int[]{2, 2, 1});
        if (got != 1) throw new AssertionError("test_basic: got " + got);

        got = sol.singleNumber(new int[]{4, 1, 2, 1, 2});
        if (got != 4) throw new AssertionError("test_longer: got " + got);

        System.out.println("LC136 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** Rust's `fold(0, |acc, &n| acc ^ n)` maps to a plain `for` loop accumulator in Java. Both produce identical machine code. XOR on signed `int` in Java behaves identically to XOR on unsigned `u32` in Rust for these cancellation patterns.

---

### LC #191 — Number of 1 Bits

**Problem.** Return the number of `1` bits in the unsigned 32-bit representation of `n`.

**Key insight.** Use `Integer.bitCount()` for the built-in approach, or Brian Kernighan's trick: `n &= n - 1` clears the lowest set bit.

```java
class Solution {
    public int hammingWeight(int n) {
        return Integer.bitCount(n);
    }

    // Manual approach with Brian Kernighan's bit trick
    public int hammingWeightManual(int n) {
        int count = 0;
        while (n != 0) {
            n &= (n - 1);   // clear lowest set bit
            count++;
        }
        return count;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.hammingWeight(0b00000000000000000000000010110100);
        if (got != 4) throw new AssertionError("test_builtin: got " + got);

        got = sol.hammingWeight(0xFFFFFFFF);  // all 1s as int (negative in signed)
        if (got != 32) throw new AssertionError("test_all_ones: got " + got);

        got = sol.hammingWeightManual(11);
        if (got != 3) throw new AssertionError("test_manual_11: got " + got);

        got = sol.hammingWeightManual(128);
        if (got != 1) throw new AssertionError("test_manual_128: got " + got);

        System.out.println("LC191 OK");
    }
}
```

**Complexity.** `Integer.bitCount`: O(1) (single CPU instruction `POPCNT`). Manual: O(k) where k is the number of set bits.

**Java notes.** `Integer.bitCount(n)` is the Java equivalent of Rust's `n.count_ones()`. Java's `int` is signed, but `bitCount` counts all 32 bits including the sign bit — the correct behavior for this problem. LeetCode's Java signature uses `int n` even though the problem says "unsigned 32-bit."

---

### LC #338 — Counting Bits

**Problem.** Return an array `ans` where `ans[i]` is the number of `1` bits in `i`, for `0 <= i <= n`.

**Key insight (DP).** `bits[i] = bits[i >> 1] + (i & 1)`. The count of 1-bits in `i` equals the count in `i` right-shifted by 1, plus the last bit.

```java
class Solution {
    public int[] countBits(int n) {
        int[] dp = new int[n + 1];
        for (int i = 1; i <= n; i++) {
            dp[i] = dp[i >> 1] + (i & 1);
        }
        return dp;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[] got = sol.countBits(2);
        if (!java.util.Arrays.equals(got, new int[]{0, 1, 1}))
            throw new AssertionError("test_2: got " + java.util.Arrays.toString(got));

        got = sol.countBits(5);
        if (!java.util.Arrays.equals(got, new int[]{0, 1, 1, 2, 1, 2}))
            throw new AssertionError("test_5: got " + java.util.Arrays.toString(got));

        System.out.println("LC338 OK");
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Java notes.** `i >> 1` is an arithmetic right shift — for non-negative `i` it is identical to unsigned right shift `i >>> 1`. Since `i` is always non-negative here, either works; `>>` is conventional.

---

### LC #190 — Reverse Bits

**Problem.** Reverse the bits of a 32-bit unsigned integer.

**Key insight.** Use `Integer.reverse()` for the built-in approach, or shift bits out one at a time into the result using `>>>` (unsigned right shift) for correctness with the sign bit.

```java
class Solution {
    public int reverseBits(int n) {
        return Integer.reverse(n);
    }

    // Manual approach — uses >>> to treat n as unsigned
    public int reverseBitsManual(int n) {
        int result = 0;
        for (int i = 0; i < 32; i++) {
            result = (result << 1) | (n & 1);
            n >>>= 1;   // unsigned right shift: fills with 0, not sign bit
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.reverseBits(0b00000010100101000001111010011100);
        int want = 0b00111001011110000010100101000000;
        if (got != want)
            throw new AssertionError("test_builtin: got " + Integer.toBinaryString(got));

        got = sol.reverseBitsManual(43261596);
        if (got != 964176192)
            throw new AssertionError("test_manual: got " + got);

        // Test with a value whose top bit is set (would matter for >> vs >>>)
        int topBitSet = 0x80000001;  // binary: 1000...0001
        int builtIn = sol.reverseBits(topBitSet);
        int manual  = sol.reverseBitsManual(topBitSet);
        if (builtIn != manual)
            throw new AssertionError("test_sign_bit: builtin=" + builtIn + " manual=" + manual);

        System.out.println("LC190 OK");
    }
}
```

**Complexity.** `Integer.reverse`: O(1). Manual: O(32) = O(1).

**Java notes.** This is the canonical place where `>>>` matters. Using `n >>= 1` (arithmetic shift) would fill the vacated bit with the sign bit when `n` is negative — corrupting the result. `n >>>= 1` always fills with 0, treating `n` as unsigned. Rust uses `u32` to make the type carry the intent; Java uses the `>>>` operator explicitly. `Integer.reverse(n)` (not `reverseBits`) is the Java standard-library method.

---

### LC #268 — Missing Number

**Problem.** Given an array of `n` distinct numbers in range `[0, n]`, return the missing number.

**Key insight.** XOR all indices `0..n` and all array values. The missing number is the one that doesn't pair and cancel.

```java
class Solution {
    public int missingNumber(int[] nums) {
        int n = nums.length;
        int xor = n;
        for (int i = 0; i < n; i++) {
            xor ^= i ^ nums[i];
        }
        return xor;
    }

    // Gauss sum alternative
    public int missingNumberSum(int[] nums) {
        int n = nums.length;
        int expected = n * (n + 1) / 2;
        int actual = 0;
        for (int v : nums) actual += v;
        return expected - actual;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.missingNumber(new int[]{3, 0, 1});
        if (got != 2) throw new AssertionError("test_xor_1: got " + got);

        got = sol.missingNumber(new int[]{0, 1});
        if (got != 2) throw new AssertionError("test_xor_2: got " + got);

        got = sol.missingNumber(new int[]{9,6,4,2,3,5,7,0,1});
        if (got != 8) throw new AssertionError("test_xor_large: got " + got);

        got = sol.missingNumberSum(new int[]{3, 0, 1});
        if (got != 2) throw new AssertionError("test_sum: got " + got);

        System.out.println("LC268 OK");
    }
}
```

**Complexity.** Time O(n), Space O(1).

**Java notes.** The Gauss sum formula `n*(n+1)/2` fits in `int` for LeetCode's constraint (`n <= 10^4`), so no `long` cast is needed here. For larger n one would use `(long) n * (n + 1) / 2`.

---

### LC #371 — Sum of Two Integers

**Problem.** Return the sum of two integers without using `+` or `-`.

**Key insight.** Simulate binary addition: XOR computes the sum without carry; AND + left-shift computes the carry. Repeat until carry is zero.

```java
class Solution {
    public int getSum(int a, int b) {
        while (b != 0) {
            int carry = (a & b) << 1;
            a ^= b;
            b = carry;
        }
        return a;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.getSum(1, 2);
        if (got != 3) throw new AssertionError("test_1_2: got " + got);

        got = sol.getSum(2, 3);
        if (got != 5) throw new AssertionError("test_2_3: got " + got);

        got = sol.getSum(-1, 1);
        if (got != 0) throw new AssertionError("test_neg_1: got " + got);

        got = sol.getSum(-3, -2);
        if (got != -5) throw new AssertionError("test_neg_both: got " + got);

        System.out.println("LC371 OK");
    }
}
```

**Complexity.** Time O(1) (at most 32 iterations for 32-bit ints), Space O(1).

**Java notes.** Bit operations on signed `int` in Java behave identically to Rust for this pattern — XOR and AND on two's-complement integers produce the same bits regardless of sign interpretation. No `>>>` is needed because we are only ever left-shifting the carry.

---

### LC #7 — Reverse Integer

**Problem.** Given a signed 32-bit integer, return the integer with its digits reversed. Return 0 if the reversed integer overflows `[Integer.MIN_VALUE, Integer.MAX_VALUE]`.

**Key insight.** Build the result in `long`, check for overflow before returning. Pop digits with `% 10` and push with `* 10`.

```java
class Solution {
    public int reverse(int x) {
        long result = 0;
        while (x != 0) {
            result = result * 10 + x % 10;
            x /= 10;
            if (result > Integer.MAX_VALUE || result < Integer.MIN_VALUE) return 0;
        }
        return (int) result;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got = sol.reverse(123);
        if (got != 321) throw new AssertionError("test_positive: got " + got);

        got = sol.reverse(-123);
        if (got != -321) throw new AssertionError("test_negative: got " + got);

        got = sol.reverse(120);
        if (got != 21) throw new AssertionError("test_trailing_zero: got " + got);

        got = sol.reverse(1534236469);
        if (got != 0) throw new AssertionError("test_overflow: got " + got);

        System.out.println("LC7 OK");
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java notes.** Java has no `checked_mul`/`checked_add`. The idiomatic LeetCode approach is to accumulate into a `long` and compare against `Integer.MAX_VALUE` / `Integer.MIN_VALUE`. Rust's `checked_mul(...).and_then(|v| v.checked_add(...))` returns `Option<i32>` — more type-safe but Java's `long` approach is equally correct. Java's `%` on negative numbers returns a negative remainder (same sign as dividend), which is the correct behavior here.

---

## Appendix — Running All Tests

To verify all solutions compile and pass, copy each class into its own file and run:

```bash
# Compile and run each solution
javac Solution.java && java Solution
javac DetectSquares.java && java DetectSquares
```

Or combine multiple solutions into one file with renamed classes for quick smoke-testing.

---

## Notes — Java vs Rust Cross-Reference

| Pattern | Java | Rust |
|---------|------|------|
| Unsigned right shift | `x >>> n` | Use `u32` type — `>>` is always unsigned |
| Count set bits | `Integer.bitCount(x)` | `x.count_ones()` |
| Reverse bits | `Integer.reverse(x)` | `x.reverse_bits()` |
| Min-heap | `new PriorityQueue<>()` (default) | `BinaryHeap` with `Reverse(...)` wrapper |
| Max-heap | `new PriorityQueue<>(Collections.reverseOrder())` | `BinaryHeap` (default) |
| Overflow-safe mul | Cast to `long` first | `x.checked_mul(y)` returns `Option<i32>` |
| Sorted map | `TreeMap<K,V>` | `BTreeMap<K,V>` |
| Merge map entry | `map.merge(key, 1, Integer::sum)` | `*map.entry(k).or_insert(0) += 1` |
| Interval sort | `Arrays.sort(a, (x,y) -> Integer.compare(x[0],y[0]))` | `a.sort_by_key(\|iv\| iv[0])` |
| 2-D array print | `Arrays.deepToString(arr)` | `{:?}` on `Vec<Vec<i32>>` |
| Frequency count | `map.merge(k, 1, Integer::sum)` | `*map.entry(k).or_insert(0) += 1` |

---

## Notes — Greedy Patterns

| Pattern | Problems | Key Idea |
|---------|----------|----------|
| Running max/min | Maximum Subarray, Jump Game | Extend or reset at each step |
| Window-end tracking | Jump Game II | BFS-level greedy with window boundaries |
| Global feasibility + local greed | Gas Station | If total gas >= cost, a valid start exists |
| Sorted frequency map | Hand of Straights | `TreeMap` gives free sorted iteration |
| Interval shrinking | Partition Labels | Last-occurrence map determines partition boundaries |
| Range tracking | Valid Parenthesis String | Track `[lo, hi]` range instead of exact count |

---

## Notes — Intervals Sorting Convention

Always decide which endpoint to sort by:
- Sort by **start**: Insert Interval, Merge Intervals, Meeting Rooms, Minimum Interval to Include Each Query
- Sort by **end**: Non-Overlapping Intervals (maximizes kept intervals by finishing earliest)
- Separate sort starts/ends: Meeting Rooms II (two-pointer sweep on decoupled arrays)

Use `Integer.compare(a[0], b[0])` — never `a[0] - b[0]`. Subtraction-based comparators overflow silently for large negative values.

---

## Notes — Bit Manipulation Cheat Sheet

| Operation | Java | Rust |
|-----------|------|------|
| Count set bits | `Integer.bitCount(n)` | `n.count_ones()` |
| Reverse bits | `Integer.reverse(n)` | `n.reverse_bits()` |
| Clear lowest set bit | `n &= (n - 1)` | `n &= n - 1` (same) |
| Unsigned right shift | `n >>> k` | Use `u32`: `n >> k` |
| Overflow-safe pow | `long exp = n; if (exp < 0) exp = -exp;` | `let exp = n as i64; if exp < 0 { exp = -exp; }` |
| XOR reduction | `for (int v : arr) xor ^= v;` | `arr.iter().fold(0, \|acc, &n\| acc ^ n)` |

---

## Notes — Math & Geometry Tricks

| Technique | Problem | Java tool |
|-----------|---------|-----------|
| Transpose + reverse rows | Rotate Image | Manual two-pointer row swap |
| Four-boundary peel | Spiral Matrix | Signed int bounds, check before each direction |
| In-place flagging | Set Matrix Zeroes | First row/column as markers |
| Floyd cycle detection | Happy Number | Two-pointer, O(1) space |
| Binary exponentiation | Pow(x, n) | `long exp` to avoid `MIN_VALUE` trap |
| Grade-school multiply | Multiply Strings | `pos[i+j]`, `pos[i+j+1]` accumulator |
| Point-count map | Detect Squares | Long-encoded key for O(1) lookup |

---

## Notes — Common Java Pitfalls in This Chapter

1. **`PriorityQueue` is a min-heap.** Java's `PriorityQueue` defaults to natural ordering (min-heap) — the opposite of Rust's `BinaryHeap` which defaults to max-heap. For a max-heap in Java use `Collections.reverseOrder()` comparator.

2. **`>>>` vs `>>`.** For Reverse Bits, use `n >>>= 1` (unsigned) not `n >>= 1` (arithmetic) in the manual loop — arithmetic shift fills the vacated bit with the sign bit, corrupting the result for negative inputs.

3. **`Integer.MIN_VALUE` negation overflows silently.** In Pow(x, n), `-Integer.MIN_VALUE == Integer.MIN_VALUE` in Java with no exception thrown. Always widen to `long` before negating: `long exp = n; if (exp < 0) exp = -exp;`.

4. **Subtraction comparators overflow.** `(a, b) -> a[0] - b[0]` overflows when `a[0]` is very negative and `b[0]` is very positive. Always use `Integer.compare(a[0], b[0])`.

5. **`int[]` vs `Integer[]` for sort lambdas.** `Arrays.sort(int[], Comparator)` does not exist — `int[]` cannot accept a comparator. Use `Integer[]` when you need lambda comparators, or sort a copy of indices.

6. **`Arrays.deepEquals` for 2-D arrays.** `==` and `.equals()` do not compare array contents. Use `Arrays.equals` for `int[]` and `Arrays.deepEquals` for `int[][]`.

---

## Notes — Records and var in This Chapter

Java 17+ features used:
- `var sol = new Solution()` — local-variable type inference throughout test drivers.
- `var heap = new PriorityQueue<int[]>(...)` — avoids repeating the generic type.
- Switch expression in LC 678 — `switch (ch) { case '(' -> ...; }` as an expression.
- `List.of(...)` — immutable list literals for expected-value comparisons in test drivers.

Records were considered for LC 2013 (`record Point(int x, int y)`) but the long-key encoding was chosen for O(1) map operations without object allocation overhead.

---

## Notes — Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| Subtraction-based interval comparators overflow for large negative values | High | All comparators use `Integer.compare(a[i], b[i])` — verified in LC 56, 435, 252, 2285 |
| `Integer.MIN_VALUE` negation silent wrap in LC 50 | High | Widened to `long exp = n` before negating — verified |
| LC 7 overflow without `long` catch | High | Result built in `long`, checked against `Integer.MAX_VALUE` / `Integer.MIN_VALUE` before cast |
| `n >>= 1` (arithmetic) instead of `n >>>= 1` (unsigned) in LC 190 manual loop | High | Used `n >>>= 1` in manual version; added test with top-bit-set input |
| `assert` keyword usage (disabled by default in JVM) | High | No `assert` keyword appears anywhere — all checks use `throw new AssertionError(...)` |
| LC 2013 nested inside `Solution` class (wrong LeetCode template) | Medium | `DetectSquares` is a standalone top-level class with its own `main` |
| `Integer[]` required for index-sort lambda in LC 2285 | Medium | `Integer[] idx` used for index array; comparator applied correctly |
| `Arrays.deepEquals` not used for 2-D array comparison | Medium | `Arrays.deepEquals` used for `int[][]`, `Arrays.equals` for `int[]` |

### Third-Person Critical Review

**Comparator correctness.** Every interval sort comparator in this chapter uses `Integer.compare(a[k], b[k])` rather than subtraction. This is the safest practice for general LeetCode interview code: LeetCode interval values can span negative ranges in edge cases, and subtraction-based comparators silently produce wrong orderings. The review confirms no subtraction comparator exists in any `Arrays.sort` lambda in this chapter.

**`Integer.MIN_VALUE` handling.** LC 50 correctly widens `n` to `long` before negation. The test driver includes a `myPow(1.0, Integer.MIN_VALUE)` case that would produce the wrong answer with a naive `int` negation.

**Unsigned shift in LC 190.** The manual `reverseBitsManual` implementation uses `n >>>= 1`, and the test driver includes a value with the top bit set (`0x80000001`) to explicitly verify the built-in and manual versions agree. This catches the `>>` vs `>>>` error.

**Overflow in LC 7.** The reverse-integer solution accumulates into `long` and checks bounds on every iteration — correct and idiomatic for Java. An alternative is to check before the multiply (`if (result > Integer.MAX_VALUE / 10) return 0`) which avoids the `long` entirely, but the `long` approach is clearer and equally correct.

**No `assert` keyword.** A grep of the chapter confirms all test assertions use `throw new AssertionError("msg: got " + actual)` exclusively. The JVM `assert` keyword requires `-ea` flag to activate and is silently skipped otherwise, making it unsuitable for self-contained test drivers.

**LC 2013 class design.** `DetectSquares` is correctly implemented as a standalone top-level class matching LeetCode's template for class-design problems. The long-key encoding correctly handles the coordinate range (0..1000) without collision.

### What This Chapter Does Well

- Every comparator uses `Integer.compare` — no subtraction overflow risk anywhere.
- Java 17+ features (`var`, switch expressions, `List.of`) are used where they add clarity, not forced everywhere.
- The `>>>` vs `>>` distinction is explained, demonstrated, and tested with a sign-bit edge case.
- `Integer.MIN_VALUE` negation trap in LC 50 is identified, fixed, and tested.
- The `DetectSquares` class uses a long-key map that avoids `record` object allocation overhead while remaining readable.
- Test drivers use `Arrays.toString`, `Arrays.deepToString`, and `.toString()` in error messages so failures are self-describing.

### What Could Be Improved

- LC 43 (Multiply Strings) uses `int[]` for the digit accumulator. For very long inputs (`m + n > Integer.MAX_VALUE`) a `long[]` would be safer, though LeetCode's constraints make this moot in practice.
- LC 2285 uses `Integer[]` for the index array to enable lambda sorting — this incurs autoboxing overhead. A custom index sort with a raw comparator function (e.g., using `Arrays.sort` on `int[]` with a manual comparison method) would be faster at scale.
- The `DetectSquares` `xToYs` map accumulates duplicate y-values without deduplication. The `pointCount` map handles multiplicity correctly, but iterating over duplicate y entries in `count()` performs redundant work. Storing `Set<Integer>` of distinct y values and using `pointCount` for frequencies would be cleaner.
- LC 50 could also check `base == 0.0` early (return 0.0 for `pow(0, negative)`), though LeetCode's constraints exclude that case.
