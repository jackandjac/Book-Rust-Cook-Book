# LC-10: Binary Search — Deep Dive (Java 17+)

> **Chapter goal:** Master every binary search variation in LeetCode's Binary Search Study Plan.
> Every snippet is self-contained and written for Java 17+. Each code block compiles independently;
> helper interfaces appear inside the same snippet that uses them.
> Target audience: Java developers who want to understand binary search patterns deeply.

**Rust quick-reference** (for readers coming from the Rust companion chapter)

| Rust pattern | Java equivalent |
|---|---|
| `left + (right - left) / 2` | `lo + (hi - lo) / 2` (same overflow safety) |
| `while left <= right` | `while (lo <= hi)` — Template 1 |
| `while left < right` | `while (lo < hi)` — Template 2 / 3 |
| `slice.binary_search(&key)` | `Arrays.binarySearch(arr, key)` — but see callout below |
| `slice.partition_point(\|x\| *x < target)` | No built-in; hand-roll lower-bound loop |
| `mid as i64 * mid as i64` | `(long) mid * mid` — always cast before multiplying |
| `usize` underflow (panic) | Java `int` never underflows silently; but `int * int` overflows silently |

> **Java vs Rust — Arrays.binarySearch vs manual roll**
>
> `Arrays.binarySearch(arr, key)` returns a **negative** value `(-(insertion_point) - 1)` when the
> key is absent. When the key is present with duplicates, it returns **any** matching index — there
> is no guarantee of first or last. For "find first position" and "find last position" problems
> (LC #34, and any duplicate-aware search), always write the loop manually.
>
> Rust's equivalent for left-bisect is `slice.partition_point(|x| *x < target)`, which always
> returns the first index where the predicate flips. Java has no standard library equivalent —
> you must hand-code the `while (lo < hi)` Template 2 loop.

---

## Binary Search Templates

Three templates cover every variation. Pick the template by what the problem guarantees and what you return.

### Template 1 — Classic: find an exact target

Use when the array has no duplicates (or any matching index is acceptable) and you know precisely when to stop.

```java
// Template 1: closed interval [lo, hi]
// Post-loop: lo > hi means the element is absent.
class Solution {
    public int binarySearchT1(int[] nums, int target) {
        int lo = 0, hi = nums.length - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] == target) return mid;
            else if (nums[mid] < target) lo = mid + 1;
            else hi = mid - 1;
        }
        return -1; // not found
    }

    public static void main(String[] args) {
        var s = new Solution();
        int r1 = s.binarySearchT1(new int[]{-1, 0, 3, 5, 9, 12}, 9);
        if (r1 != 4) throw new AssertionError("T1 found: got " + r1);
        int r2 = s.binarySearchT1(new int[]{-1, 0, 3, 5, 9, 12}, 2);
        if (r2 != -1) throw new AssertionError("T1 missing: got " + r2);
    }
}
```

**Key invariant:** after the loop, `lo > hi`; the element is not present.

### Template 2 — Boundary: find the leftmost (or rightmost) position

Use when duplicates exist or you want the first/last index satisfying a predicate.
Half-open interval: `hi` starts at `nums.length` (one past the end).

```java
// Template 2: half-open interval [lo, hi)
// while (lo < hi) — mid is always < hi, so hi = mid is safe.
// Post-loop: lo == hi == first index where predicate is true (or nums.length).
class Solution {
    // Lower bound: first index where nums[i] >= target
    public int lowerBound(int[] nums, int target) {
        int lo = 0, hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] < target) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    // Upper bound: first index where nums[i] > target
    public int upperBound(int[] nums, int target) {
        int lo = 0, hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] <= target) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    public static void main(String[] args) {
        var s = new Solution();
        int[] arr = {5, 7, 7, 8, 8, 10};
        int lb = s.lowerBound(arr, 8);
        if (lb != 3) throw new AssertionError("lowerBound 8: got " + lb);
        int ub = s.upperBound(arr, 8);
        if (ub != 5) throw new AssertionError("upperBound 8: got " + ub);
    }
}
```

### Template 3 — Binary search on the answer space

Use when you are NOT searching an array by index but searching an abstract monotone space
(e.g., "what is the smallest feasible speed?").

```java
// Template 3: lo and hi are values in the answer domain, not array indices.
// feasible(mid) returns true when mid satisfies the constraint.
// Minimize variant: find smallest feasible value.
// while (lo < hi) { long mid = lo + (hi - lo) / 2; if feasible: hi = mid; else lo = mid + 1; }
//
// Maximize variant: find largest feasible value.
// while (lo < hi) { long mid = lo + (hi - lo + 1) / 2;  // round UP to prevent infinite loop
//                   if feasible: lo = mid; else hi = mid - 1; }
```

---

## Part 1 — Template 1: Classic Binary Search

---

### LC #704 — Binary Search (Brief Revisit)

**Problem.** Given a sorted array of distinct integers and a target, return the index of the target or `-1` if not present.

**Key insight.** Textbook Template 1. The closed interval `[lo, hi]` shrinks on every iteration because we always update `lo = mid + 1` or `hi = mid - 1`.

```java
class Solution {
    public int search(int[] nums, int target) {
        int lo = 0, hi = nums.length - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] == target) return mid;
            else if (nums[mid] < target) lo = mid + 1;
            else hi = mid - 1;
        }
        return -1;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.search(new int[]{-1, 0, 3, 5, 9, 12}, 9);
        if (r1 != 4) throw new AssertionError("LC704 found: got " + r1);

        int r2 = s.search(new int[]{-1, 0, 3, 5, 9, 12}, 2);
        if (r2 != -1) throw new AssertionError("LC704 not-found: got " + r2);

        int r3 = s.search(new int[]{5}, 5);
        if (r3 != 0) throw new AssertionError("LC704 single: got " + r3);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java-specific notes.**
- `lo + (hi - lo) / 2` prevents the overflow that `(lo + hi) / 2` causes when both are near `Integer.MAX_VALUE`.
- `nums.length - 1` is safe even for empty arrays because the while condition `lo <= hi` would be `0 <= -1`, which is immediately false.

---

### LC #374 — Guess Number Higher or Lower

**Problem.** A secret number is picked in `[1, n]`. The API `guess(int num)` returns `-1` (your guess is too high), `1` (too low), or `0` (correct). Find the number.

**Key insight.** Template 1 with an API call replacing an array comparison. Each call eliminates half the remaining range.

```java
// LeetCode injects guess() as a native method. We model it with an interface for self-contained testing.
interface GuessApi {
    int guess(int num);
}

class Solution {
    public int guessNumber(int n, GuessApi api) {
        int lo = 1, hi = n;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            int result = api.guess(mid);
            if (result == 0) return mid;
            else if (result == -1) hi = mid - 1; // mid is too high
            else lo = mid + 1;                    // mid is too low
        }
        return -1;
    }

    public static void main(String[] args) {
        var s = new Solution();

        GuessApi pick6 = num -> Integer.compare(6, num);  // returns sign of (pick - num)
        int r1 = s.guessNumber(10, pick6);
        if (r1 != 6) throw new AssertionError("LC374 pick=6: got " + r1);

        GuessApi pick1 = num -> Integer.compare(1, num);
        int r2 = s.guessNumber(1, pick1);
        if (r2 != 1) throw new AssertionError("LC374 pick=1: got " + r2);

        GuessApi pick100 = num -> Integer.compare(100, num);
        int r3 = s.guessNumber(100, pick100);
        if (r3 != 100) throw new AssertionError("LC374 pick=100: got " + r3);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java-specific notes.**
- `Integer.compare(pick, num)` returns a negative/zero/positive int matching the `-1`/`0`/`1` convention. Using a lambda `num -> Integer.compare(pick, num)` avoids writing a full class.
- On LeetCode the method signature is `extends GuessGame` with a built-in `guess(int num)`. In an interview, a private field + lambda captures the intent cleanly.
- A `switch` expression over the three return values is possible but `if/else` is clearer here because the values (`-1`, `0`, `1`) are not enum constants.

---

### LC #702 — Search in a Sorted Array of Unknown Size

**Problem.** A sorted array is accessible only through `ArrayReader.get(int index)`, which returns `2^31 - 1` for out-of-bounds indices. Find the index of `target`, or `-1`.

**Key insight.** Phase 1: expand the right boundary exponentially until `reader.get(right) >= target`. Phase 2: run Template 1 in `[lo, hi]`.

```java
interface ArrayReader {
    int get(int index);
}

class Solution {
    public int search(ArrayReader reader, int target) {
        // Phase 1: exponential expansion
        int lo = 0, hi = 1;
        while (reader.get(hi) < target) {
            lo = hi;
            hi *= 2;
        }
        // Phase 2: Template 1 in [lo, hi]
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            int val = reader.get(mid);
            if (val == target) return mid;
            else if (val < target) lo = mid + 1;
            else hi = mid - 1;
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {-1, 0, 3, 5, 9, 12};
        ArrayReader reader = i -> (i < 0 || i >= data.length) ? Integer.MAX_VALUE : data[i];

        var s = new Solution();

        int r1 = s.search(reader, 9);
        if (r1 != 4) throw new AssertionError("LC702 found 9: got " + r1);

        int r2 = s.search(reader, 2);
        if (r2 != -1) throw new AssertionError("LC702 missing 2: got " + r2);

        ArrayReader single = i -> (i == 0) ? 5 : Integer.MAX_VALUE;
        int r3 = s.search(single, 5);
        if (r3 != 0) throw new AssertionError("LC702 single: got " + r3);
    }
}
```

**Complexity.** Time O(log T) where T is the target's actual index, Space O(1).

**Java-specific notes.**
- `hi *= 2` can overflow `int` for very large arrays. For production code, use `long` bounds. LeetCode constrains input so this is safe in contest problems.
- `Integer.MAX_VALUE` (the sentinel) is a concrete constant in Java — no cast required, unlike Rust's `i32::MAX`.

---

### LC #278 — First Bad Version

**Problem.** Versions `1..n` where version `k` is the first bad version; all versions `>= k` are bad. API: `isBadVersion(version)`. Find `k` with minimal calls.

**Key insight.** "Find the first true" is Template 2: shrink right to `mid` when bad, advance left past `mid` when good. Post-loop, `lo == hi` is the answer.

```java
interface VersionApi {
    boolean isBadVersion(int version);
}

class Solution {
    public int firstBadVersion(int n, VersionApi api) {
        int lo = 1, hi = n;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (api.isBadVersion(mid)) hi = mid;   // mid could be the first bad
            else lo = mid + 1;                       // mid is good; first bad is to the right
        }
        return lo;
    }

    public static void main(String[] args) {
        var s = new Solution();

        VersionApi firstBad4 = v -> v >= 4;
        int r1 = s.firstBadVersion(5, firstBad4);
        if (r1 != 4) throw new AssertionError("LC278 firstBad=4: got " + r1);

        VersionApi firstBad1 = v -> v >= 1;
        int r2 = s.firstBadVersion(1, firstBad1);
        if (r2 != 1) throw new AssertionError("LC278 n=1: got " + r2);

        int r3 = s.firstBadVersion(10, firstBad1);
        if (r3 != 1) throw new AssertionError("LC278 firstBad=1: got " + r3);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java-specific notes.**
- `while (lo < hi)` with `hi = mid` guarantees termination: since `mid = lo + (hi - lo) / 2` rounds down, `mid < hi` whenever `lo < hi`, so `hi` strictly decreases.
- Using `while (lo <= hi)` here would require an extra variable to track the last known bad version and risks an off-by-one.

---

### LC #69 — Sqrt(x)

**Problem.** Compute `floor(sqrt(x))` for non-negative integer `x`, without `Math.sqrt()`.

**Key insight.** Search for the largest integer `mid` where `mid * mid <= x`. Because we are **maximizing**, use the round-up mid form (`lo + (hi - lo + 1) / 2`) and assign `lo = mid`.

**Overflow warning.** For `x` near `Integer.MAX_VALUE`, `mid * mid` overflows `int`. Cast to `long` first.

```java
class Solution {
    public int mySqrt(int x) {
        if (x < 2) return x;
        long x64 = x;
        long lo = 1, hi = x64 / 2 + 1; // floor(sqrt(x)) <= x/2 for x >= 4
        while (lo < hi) {
            long mid = lo + (hi - lo + 1) / 2; // round UP — required when lo = mid
            if (mid * mid <= x64) lo = mid;     // mid is valid; try higher
            else hi = mid - 1;
        }
        return (int) lo;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.mySqrt(4);
        if (r1 != 2) throw new AssertionError("LC69 sqrt(4): got " + r1);

        int r2 = s.mySqrt(8);
        if (r2 != 2) throw new AssertionError("LC69 sqrt(8): got " + r2);

        int r3 = s.mySqrt(9);
        if (r3 != 3) throw new AssertionError("LC69 sqrt(9): got " + r3);

        int r4 = s.mySqrt(0);
        if (r4 != 0) throw new AssertionError("LC69 sqrt(0): got " + r4);

        int r5 = s.mySqrt(1);
        if (r5 != 1) throw new AssertionError("LC69 sqrt(1): got " + r5);

        int r6 = s.mySqrt(2147395599);
        if (r6 != 46339) throw new AssertionError("LC69 large: got " + r6);

        int r7 = s.mySqrt(Integer.MAX_VALUE);
        if (r7 != 46340) throw new AssertionError("LC69 MAX_VALUE: got " + r7);
    }
}
```

**Complexity.** Time O(log x), Space O(1).

**Java-specific notes.**
- `(hi - lo + 1) / 2` rounds mid up. If you use the round-down form with `lo = mid`, the loop stalls when `hi = lo + 1` because `mid` would always equal `lo`.
- `long` arithmetic is essential: `46341 * 46341 = 2,147,488,281` which exceeds `Integer.MAX_VALUE` (2,147,483,647). Without the cast, the comparison `mid * mid <= x64` would silently use a wrapped negative value in Java.

---

## Part 2 — Template 2: Left/Right Boundary

---

### LC #34 — Find First and Last Position of Element in Sorted Array

**Problem.** Given a sorted array with possible duplicates and a target, return `[first, last]` indices. Return `[-1, -1]` if absent.

**Key insight.** Two separate Template 2 binary searches: one lower-bound (first index where `nums[i] >= target`), one upper-bound (first index where `nums[i] > target`), then subtract one.

```java
class Solution {
    public int[] searchRange(int[] nums, int target) {
        if (nums.length == 0) return new int[]{-1, -1};

        int first = lowerBound(nums, target);
        if (first == nums.length || nums[first] != target) return new int[]{-1, -1};

        int last = upperBound(nums, target) - 1;
        return new int[]{first, last};
    }

    // First index where nums[i] >= target
    private int lowerBound(int[] nums, int target) {
        int lo = 0, hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] < target) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    // First index where nums[i] > target
    private int upperBound(int[] nums, int target) {
        int lo = 0, hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] <= target) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int[] r1 = s.searchRange(new int[]{5, 7, 7, 8, 8, 10}, 8);
        if (r1[0] != 3 || r1[1] != 4) throw new AssertionError("LC34 [8]: got [" + r1[0] + "," + r1[1] + "]");

        int[] r2 = s.searchRange(new int[]{5, 7, 7, 8, 8, 10}, 6);
        if (r2[0] != -1 || r2[1] != -1) throw new AssertionError("LC34 [6]: got [" + r2[0] + "," + r2[1] + "]");

        int[] r3 = s.searchRange(new int[]{2, 2, 2}, 2);
        if (r3[0] != 0 || r3[1] != 2) throw new AssertionError("LC34 all-same: got [" + r3[0] + "," + r3[1] + "]");

        int[] r4 = s.searchRange(new int[]{}, 0);
        if (r4[0] != -1 || r4[1] != -1) throw new AssertionError("LC34 empty: got [" + r4[0] + "," + r4[1] + "]");
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java-specific notes.**
- `upperBound(nums, target) - 1` is safe because `first < nums.length && nums[first] == target` guarantees at least one occurrence, so `upperBound` returns at least `first + 1 >= 1`.
- Do NOT use `Arrays.binarySearch` here — it returns an arbitrary index among duplicates, making first/last recovery impossible.

---

### LC #154 — Find Minimum in Rotated Sorted Array II (with Duplicates)

**Problem.** A sorted array was rotated an unknown number of times and may contain duplicates. Find the minimum element.

**Key insight.** Compare `nums[mid]` against `nums[hi]` (the stable right boundary) to determine which half is sorted. When `nums[mid] == nums[hi]`, we cannot determine which half contains the minimum, so shrink `hi` by 1.

**Worst-case warning.** An input like `[1, 1, 1, 0, 1, 1]` forces O(n) because duplicates prevent eliminating half the range on every step.

```java
class Solution {
    public int findMin(int[] nums) {
        int lo = 0, hi = nums.length - 1;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] > nums[hi]) {
                lo = mid + 1;   // minimum is in the right half (exclusive of mid)
            } else if (nums[mid] < nums[hi]) {
                hi = mid;       // mid could be the minimum
            } else {
                hi--;           // nums[mid] == nums[hi]: can't tell; safely shrink right
            }
        }
        return nums[lo];
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.findMin(new int[]{3, 4, 5, 1, 2});
        if (r1 != 1) throw new AssertionError("LC154 rotated: got " + r1);

        int r2 = s.findMin(new int[]{2, 2, 2, 0, 1});
        if (r2 != 0) throw new AssertionError("LC154 dup: got " + r2);

        int r3 = s.findMin(new int[]{1, 1, 1, 0, 1, 1, 1});
        if (r3 != 0) throw new AssertionError("LC154 worst-case: got " + r3);

        int r4 = s.findMin(new int[]{2, 2, 2});
        if (r4 != 2) throw new AssertionError("LC154 all-same: got " + r4);

        int r5 = s.findMin(new int[]{1, 2, 3});
        if (r5 != 1) throw new AssertionError("LC154 no-rotation: got " + r5);
    }
}
```

**Complexity.** Time O(log n) average, O(n) worst case (all duplicates). Space O(1).

**Java-specific notes.**
- Always compare against `nums[hi]`, not `nums[lo]`. The right boundary is stable after a rotation; the left boundary is ambiguous.
- `hi--` (not `hi = mid - 1`) because we only know `nums[hi]` is not uniquely the minimum — we cannot skip `mid`.

---

### LC #81 — Search in Rotated Sorted Array II

**Problem.** A rotated sorted array may contain duplicates. Return `true` if `target` is present.

**Key insight.** When `nums[lo] == nums[mid] == nums[hi]`, duplicates prevent determining which half is sorted — shrink both ends by 1. Otherwise, identify the sorted half and check if the target falls within it.

**Worst-case warning.** Same as LC #154 — all-duplicate inputs force O(n).

```java
class Solution {
    public boolean search(int[] nums, int target) {
        int lo = 0, hi = nums.length - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] == target) return true;

            int l = nums[lo], m = nums[mid], r = nums[hi];
            if (l == m && m == r) {
                // Duplicates obscure structure; shrink both ends safely
                lo++;
                hi--;
            } else if (l <= m) {
                // Left half [lo, mid] is sorted
                if (l <= target && target < m) hi = mid - 1;
                else lo = mid + 1;
            } else {
                // Right half [mid, hi] is sorted
                if (m < target && target <= r) lo = mid + 1;
                else hi = mid - 1;
            }
        }
        return false;
    }

    public static void main(String[] args) {
        var s = new Solution();

        boolean r1 = s.search(new int[]{2, 5, 6, 0, 0, 1, 2}, 0);
        if (!r1) throw new AssertionError("LC81 found 0: got false");

        boolean r2 = s.search(new int[]{2, 5, 6, 0, 0, 1, 2}, 3);
        if (r2) throw new AssertionError("LC81 missing 3: got true");

        boolean r3 = s.search(new int[]{1, 1, 1, 1, 1}, 0);
        if (r3) throw new AssertionError("LC81 all-dup missing: got true");

        boolean r4 = s.search(new int[]{1}, 1);
        if (!r4) throw new AssertionError("LC81 single: got false");
    }
}
```

**Complexity.** Time O(log n) average, O(n) worst case. Space O(1).

**Java-specific notes.**
- `int lo = 0, hi = nums.length - 1` uses `int` throughout. Java `int` cannot underflow (unlike Rust's `usize`), but the shrink `lo++; hi--` must still be safe — the `lo <= hi` guard ensures `hi >= lo >= 0` before shrinking.
- Extracting `l`, `m`, `r` as named `int` variables avoids repeated array indexing and makes the four branches legible at a glance.

---

### LC #162 — Find Peak Element

**Problem.** A peak satisfies `nums[i] > nums[i-1]` and `nums[i] > nums[i+1]`. Boundary elements treat out-of-bounds as `-∞`. Return any peak index. No two adjacent elements are equal.

**Key insight.** If `nums[mid] < nums[mid + 1]`, the slope is ascending — a peak exists to the right (or at `mid + 1`). Otherwise, a peak exists at or left of `mid`. This monotone predicate drives a Template 2 search.

```java
class Solution {
    public int findPeakElement(int[] nums) {
        int lo = 0, hi = nums.length - 1;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] < nums[mid + 1]) lo = mid + 1; // ascending slope; peak is right
            else hi = mid;                                 // descending slope; peak at mid or left
        }
        return lo;
    }

    private static boolean isPeak(int[] nums, int i) {
        return (i == 0 || nums[i] > nums[i - 1])
            && (i == nums.length - 1 || nums[i] > nums[i + 1]);
    }

    public static void main(String[] args) {
        var s = new Solution();

        int i1 = s.findPeakElement(new int[]{1, 2, 3, 1});
        if (!isPeak(new int[]{1, 2, 3, 1}, i1))
            throw new AssertionError("LC162 [1,2,3,1]: index " + i1 + " not a peak");

        int i2 = s.findPeakElement(new int[]{1, 2, 1, 3, 5, 6, 4});
        if (!isPeak(new int[]{1, 2, 1, 3, 5, 6, 4}, i2))
            throw new AssertionError("LC162 multi-peak: index " + i2 + " not a peak");

        int i3 = s.findPeakElement(new int[]{1});
        if (i3 != 0) throw new AssertionError("LC162 single: got " + i3);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java-specific notes.**
- `nums[mid + 1]` is always in bounds because `lo < hi` implies `mid < hi <= nums.length - 1`, so `mid + 1 <= nums.length - 1`.
- The problem guarantees no two adjacent elements are equal, so `nums[mid] < nums[mid + 1]` is a clean strict comparison — no tie-breaking needed.

---

### LC #436 — Find Right Interval

**Problem.** Given intervals, for each interval find the index of the interval with the smallest `start >= end_i`. Return `-1` if none exists.

**Key insight.** Collect `(start, originalIndex)` pairs, sort by `start`, then for each interval's `end`, binary-search (lower-bound) for the first `start >= end`.

```java
import java.util.Arrays;

class Solution {
    record IndexedStart(int start, int idx) {}

    public int[] findRightInterval(int[][] intervals) {
        int n = intervals.length;
        var starts = new IndexedStart[n];
        for (int i = 0; i < n; i++) {
            starts[i] = new IndexedStart(intervals[i][0], i);
        }
        Arrays.sort(starts, java.util.Comparator.comparingInt(IndexedStart::start));

        int[] result = new int[n];
        for (int i = 0; i < n; i++) {
            int end = intervals[i][1];
            // Lower bound: first index in starts where start >= end
            int lo = 0, hi = n;
            while (lo < hi) {
                int mid = lo + (hi - lo) / 2;
                if (starts[mid].start() < end) lo = mid + 1;
                else hi = mid;
            }
            result[i] = (lo < n) ? starts[lo].idx() : -1;
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int[] r1 = s.findRightInterval(new int[][]{{3,4},{2,3},{1,2}});
        int[] e1 = {-1, 0, 1};
        for (int i = 0; i < 3; i++)
            if (r1[i] != e1[i]) throw new AssertionError("LC436 t1[" + i + "]: got " + r1[i] + " exp " + e1[i]);

        int[] r2 = s.findRightInterval(new int[][]{{1,4},{2,3},{3,4}});
        int[] e2 = {-1, 2, -1};
        for (int i = 0; i < 3; i++)
            if (r2[i] != e2[i]) throw new AssertionError("LC436 t2[" + i + "]: got " + r2[i] + " exp " + e2[i]);
    }
}
```

**Complexity.** Time O(n log n), Space O(n).

**Java-specific notes.**
- `record IndexedStart(int start, int idx)` is Java 16+ (stable in 17). It generates `start()`, `idx()`, `equals`, `hashCode`, and `toString` automatically — a direct analog of Rust's tuple struct.
- `Comparator.comparingInt(IndexedStart::start)` is idiomatic Java 8+ and avoids a manual `Comparator` class.
- Java has no `partition_point`; the manual Template 2 lower-bound loop fills that role.

---

## Part 3 — Template 3: Binary Search on the Answer

The template: the answer domain is `[lo, hi]`; `feasible(mid)` is monotone (once true, always true for larger/smaller values depending on direction). Find the smallest or largest feasible value.

**Monotone predicate rule:**
- **Minimize**: `while (lo < hi)` + round-down mid + `hi = mid` / `lo = mid + 1`
- **Maximize**: `while (lo < hi)` + round-UP mid (`lo + (hi - lo + 1) / 2`) + `lo = mid` / `hi = mid - 1`

---

### LC #875 — Koko Eating Bananas

**Problem.** Koko eats at speed `k` bananas/hour. Each pile of `p` bananas takes `ceil(p / k)` hours. Find the minimum `k` such that she finishes all piles within `h` hours.

**Monotone predicate:** `canFinish(k)` = "total hours at speed k <= h". As `k` increases, `canFinish(k)` goes from false to true (monotone). Find the smallest `k` where it is true.

```java
class Solution {
    public int minEatingSpeed(int[] piles, int h) {
        long lo = 1, hi = 0;
        for (int p : piles) hi = Math.max(hi, p);

        while (lo < hi) {
            long mid = lo + (hi - lo) / 2;
            if (canFinish(piles, h, mid)) hi = mid;  // feasible; try slower
            else lo = mid + 1;
        }
        return (int) lo;
    }

    private boolean canFinish(int[] piles, int h, long speed) {
        long hours = 0;
        for (int p : piles) {
            hours += (p + speed - 1) / speed; // ceil(p / speed)
        }
        return hours <= h;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.minEatingSpeed(new int[]{3, 6, 7, 11}, 8);
        if (r1 != 4) throw new AssertionError("LC875 t1: got " + r1);

        int r2 = s.minEatingSpeed(new int[]{30, 11, 23, 4, 20}, 5);
        if (r2 != 30) throw new AssertionError("LC875 t2: got " + r2);

        int r3 = s.minEatingSpeed(new int[]{30, 11, 23, 4, 20}, 6);
        if (r3 != 23) throw new AssertionError("LC875 t3: got " + r3);

        int r4 = s.minEatingSpeed(new int[]{10}, 10);
        if (r4 != 1) throw new AssertionError("LC875 single slow: got " + r4);

        int r5 = s.minEatingSpeed(new int[]{10}, 1);
        if (r5 != 10) throw new AssertionError("LC875 single fast: got " + r5);
    }
}
```

**Complexity.** Time O(n log M) where M = max pile, Space O(1).

**Java-specific notes.**
- `(p + speed - 1) / speed` is integer ceiling division — no `Math.ceil` or `double` needed.
- The accumulator `hours` must be `long` because up to 10^4 piles each taking up to 10^4 hours sums to 10^8, which fits `int`, but LeetCode constraints allow pile values up to 10^9 with speed=1, giving a per-pile cost of 10^9 and a total that requires `long`.

---

### LC #1011 — Minimum Capacity to Ship Packages Within D Days

**Problem.** Ship `weights[i]` consecutively (order preserved) using a ship of capacity `C`. Find the minimum `C` to ship all packages within `d` days.

**Monotone predicate:** `canShip(C)` = "we can load packages greedily into days, never exceeding `C` per day, within `d` days total". As `C` increases, `canShip(C)` goes from false to true. Find the smallest true `C`.

```java
class Solution {
    public int shipWithinDays(int[] weights, int days) {
        long lo = 0, hi = 0;
        for (int w : weights) {
            lo = Math.max(lo, w); // must carry at least the heaviest single package
            hi += w;              // worst case: ship all in one day
        }

        while (lo < hi) {
            long mid = lo + (hi - lo) / 2;
            if (canShip(weights, days, mid)) hi = mid;
            else lo = mid + 1;
        }
        return (int) lo;
    }

    private boolean canShip(int[] weights, int days, long capacity) {
        int usedDays = 1;
        long load = 0;
        for (int w : weights) {
            if (load + w > capacity) {
                usedDays++;
                load = 0;
            }
            load += w;
        }
        return usedDays <= days;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.shipWithinDays(new int[]{1,2,3,4,5,6,7,8,9,10}, 5);
        if (r1 != 15) throw new AssertionError("LC1011 t1: got " + r1);

        int r2 = s.shipWithinDays(new int[]{3,2,2,4,1,4}, 3);
        if (r2 != 6) throw new AssertionError("LC1011 t2: got " + r2);
    }
}
```

**Complexity.** Time O(n log S) where S = sum of weights, Space O(1).

**Java-specific notes.**
- The lower bound is `max(weights)`, not `1`, because a single package cannot be split across days.
- `load + w > capacity` must use `long` on the left side; since `load` is already `long` the promotion is automatic, but be careful if you ever store `load` as `int`.
- `canShip` uses a greedy simulation: start a new day only when the next package would exceed capacity.

---

### LC #410 — Split Array Largest Sum

**Problem.** Split `nums` into exactly `k` non-empty subarrays. Minimize the largest subarray sum.

**Monotone predicate:** `canSplit(maxSum)` = "we can partition `nums` into at most `k` subarrays each with sum <= `maxSum`". As `maxSum` increases, `canSplit` goes from false to true.

**Overflow warning.** Up to 1000 elements each up to 10^8 means subarray sums can reach 10^11 — `long` is required.

```java
class Solution {
    public int splitArray(int[] nums, int k) {
        long lo = 0, hi = 0;
        for (int n : nums) {
            lo = Math.max(lo, n);
            hi += n;
        }

        while (lo < hi) {
            long mid = lo + (hi - lo) / 2;
            if (canSplit(nums, k, mid)) hi = mid;
            else lo = mid + 1;
        }
        return (int) lo;
    }

    private boolean canSplit(int[] nums, int k, long maxSum) {
        int parts = 1;
        long current = 0;
        for (int n : nums) {
            if (current + n > maxSum) {
                parts++;
                current = 0;
            }
            current += n;
        }
        return parts <= k;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.splitArray(new int[]{7, 2, 5, 10, 8}, 2);
        if (r1 != 18) throw new AssertionError("LC410 t1: got " + r1);

        int r2 = s.splitArray(new int[]{1, 2, 3, 4, 5}, 2);
        if (r2 != 9) throw new AssertionError("LC410 t2: got " + r2);

        int r3 = s.splitArray(new int[]{1, 4, 4}, 3);
        if (r3 != 4) throw new AssertionError("LC410 t3: got " + r3);
    }
}
```

**Complexity.** Time O(n log S) where S = sum of elements, Space O(1).

**Java-specific notes.**
- The greedy in `canSplit` is identical to LC #1011's `canShip` — both minimize a "max over groups" objective with the same simulation.
- `parts <= k` (not `< k`) — we need at most `k` parts, not strictly fewer.

---

### LC #1552 — Magnetic Force Between Two Balls

**Problem.** Place `m` balls in sorted `position` baskets to maximize the minimum magnetic force (minimum pairwise distance).

**Key insight — direction reversal.** We MAXIMIZE the minimum distance. So `feasible(mid)` = "can we place all `m` balls with pairwise distance >= `mid`?" Once `feasible` is true for some `mid`, it remains true for smaller values. We want the **largest** feasible `mid`.

Use the **maximize** form of Template 3: round-UP mid, `lo = mid`, `hi = mid - 1`.

```java
import java.util.Arrays;

class Solution {
    public int maxDistance(int[] position, int m) {
        Arrays.sort(position);
        int n = position.length;
        long lo = 1, hi = (long)(position[n - 1] - position[0]);

        while (lo < hi) {
            long mid = lo + (hi - lo + 1) / 2; // round UP — required when lo = mid
            if (canPlace(position, m, mid)) lo = mid;  // feasible; try larger gap
            else hi = mid - 1;
        }
        return (int) lo;
    }

    private boolean canPlace(int[] position, int m, long minDist) {
        int count = 1;
        long last = position[0];
        for (int i = 1; i < position.length; i++) {
            if (position[i] - last >= minDist) {
                count++;
                last = position[i];
            }
        }
        return count >= m;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.maxDistance(new int[]{1, 2, 3, 4, 7}, 3);
        if (r1 != 3) throw new AssertionError("LC1552 t1: got " + r1);

        int r2 = s.maxDistance(new int[]{5, 4, 3, 2, 1, 1000000000}, 2);
        if (r2 != 999999999) throw new AssertionError("LC1552 t2: got " + r2);

        int r3 = s.maxDistance(new int[]{1, 5, 9}, 2);
        if (r3 != 8) throw new AssertionError("LC1552 t3: got " + r3);
    }
}
```

**Complexity.** Time O(n log n + n log D) where D = position range, Space O(1).

**Java-specific notes.**
- `(hi - lo + 1) / 2` rounds mid up. Without the `+1`, when `hi = lo + 1`, mid would equal `lo` and the loop would stall because `lo = mid` would not advance `lo`.
- `long last = position[0]` and `position[i] - last` — since `position[i]` is `int` and `last` is `long`, the subtraction auto-promotes to `long`. This is correct for the comparison `>= minDist` which is also `long`.
- `(long)(position[n-1] - position[0])` — the subtraction happens in `int` first, but positions fit in `int` range per LeetCode constraints, so the cast is for safety and future-proofing.

---

### LC #1283 — Find the Smallest Divisor Given a Threshold

**Problem.** Find the smallest positive integer divisor `d` such that `sum(ceil(nums[i] / d)) <= threshold`.

**Monotone predicate:** as `d` increases, the sum decreases (monotone). Find the smallest `d` where the sum falls at or below threshold.

```java
class Solution {
    public int smallestDivisor(int[] nums, int threshold) {
        long lo = 1, hi = 0;
        for (int n : nums) hi = Math.max(hi, n);

        while (lo < hi) {
            long mid = lo + (hi - lo) / 2;
            long total = 0;
            for (int n : nums) {
                total += (n + mid - 1) / mid; // ceil(n / mid)
            }
            if (total <= threshold) hi = mid;
            else lo = mid + 1;
        }
        return (int) lo;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.smallestDivisor(new int[]{1, 2, 5, 9}, 6);
        if (r1 != 5) throw new AssertionError("LC1283 t1: got " + r1);

        int r2 = s.smallestDivisor(new int[]{44, 22, 33, 11, 100}, 5);
        if (r2 != 44) throw new AssertionError("LC1283 t2: got " + r2);

        int r3 = s.smallestDivisor(new int[]{2, 3, 5, 7, 11}, 11);
        if (r3 != 1) throw new AssertionError("LC1283 threshold==n: got " + r3);
    }
}
```

**Complexity.** Time O(n log M) where M = max element, Space O(1).

**Java-specific notes.**
- `(n + mid - 1) / mid` computes `ceil(n / mid)` using only integer arithmetic — identical to the Koko Eating Bananas ceiling formula.
- The upper bound for `hi` is `max(nums)` because at divisor = `max`, every `ceil(nums[i] / max)` is 1, giving a sum of `n <= threshold` (guaranteed by the problem).

---

### LC #2064 — Minimized Maximum of Products Distributed to Any Store

**Problem.** Distribute `quantities[i]` units of `n` distinct product types among `m` stores. Each store gets at most one product type. Minimize the maximum quantity assigned to any store.

**Monotone predicate:** `storesNeeded(x)` = sum of `ceil(q / x)` for each quantity. As `x` (max units per store) increases, `storesNeeded` decreases (monotone). Find the smallest `x` where `storesNeeded(x) <= n`.

```java
class Solution {
    public int minimizedMaximum(int n, int[] quantities) {
        long lo = 1, hi = 0;
        for (int q : quantities) hi = Math.max(hi, q);

        while (lo < hi) {
            long mid = lo + (hi - lo) / 2;
            long storesNeeded = 0;
            for (int q : quantities) {
                storesNeeded += (q + mid - 1) / mid; // ceil(q / mid)
            }
            if (storesNeeded <= n) hi = mid;  // feasible; try smaller max
            else lo = mid + 1;
        }
        return (int) lo;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.minimizedMaximum(6, new int[]{11, 6});
        if (r1 != 3) throw new AssertionError("LC2064 t1: got " + r1);

        int r2 = s.minimizedMaximum(7, new int[]{15, 10, 10});
        if (r2 != 5) throw new AssertionError("LC2064 t2: got " + r2);

        int r3 = s.minimizedMaximum(1, new int[]{10000});
        if (r3 != 10000) throw new AssertionError("LC2064 t3: got " + r3);

        int r4 = s.minimizedMaximum(4, new int[]{8, 4});
        if (r4 != 4) throw new AssertionError("LC2064 exact-split: got " + r4);
    }
}
```

**Complexity.** Time O(n log M) where M = max quantity, Space O(1).

**Java-specific notes.**
- This problem is structurally identical to LC #1283 and LC #875 — the same ceiling-divide pattern and the same Template 3 minimize search. Recognizing the shared structure is the key interview insight.

---

## Part 4 — 2D Binary Search

---

### LC #240 — Search a 2D Matrix II

**Problem.** An `m x n` matrix where each row is sorted left-to-right and each column is sorted top-to-bottom. Determine whether `target` is present.

**Note.** This is NOT a binary search problem. It uses **staircase elimination** (saddleback search), which achieves O(m + n) — strictly better than O(m log n) from binary-searching each row independently.

**Key insight.** Start at the top-right corner. If the current element is greater than target, move left (eliminate the column). If it is less, move down (eliminate the row). If equal, found.

```java
class Solution {
    public boolean searchMatrix(int[][] matrix, int target) {
        if (matrix.length == 0 || matrix[0].length == 0) return false;
        int row = 0, col = matrix[0].length - 1;
        while (row < matrix.length && col >= 0) {
            int val = matrix[row][col];
            if (val == target) return true;
            else if (val > target) col--;
            else row++;
        }
        return false;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int[][] m = {
            {1, 4, 7, 11, 15},
            {2, 5, 8, 12, 19},
            {3, 6, 9, 16, 22},
            {10,13,14,17,24},
            {18,21,23,26,30}
        };

        boolean r1 = s.searchMatrix(m, 5);
        if (!r1) throw new AssertionError("LC240 found 5: got false");

        boolean r2 = s.searchMatrix(m, 20);
        if (r2) throw new AssertionError("LC240 missing 20: got true");

        boolean r3 = s.searchMatrix(new int[][]{{5}}, 5);
        if (!r3) throw new AssertionError("LC240 single: got false");
    }
}
```

**Complexity.** Time O(m + n), Space O(1).

**Java-specific notes.**
- `col >= 0` is the termination condition when moving left off the matrix. Java `int` can go negative, making this a natural sentinel.
- `var` is not used here because `int[][]` is clear and explicit — use `var` where the type is verbose or inferred from construction.

---

### LC #378 — Kth Smallest Element in a Sorted Matrix

**Problem.** Given an `n x n` matrix where each row and column is sorted in ascending order, find the kth smallest element.

**Key insight.** Binary search on the **value domain** `[matrix[0][0], matrix[n-1][n-1]]`. For a candidate value `mid`, count how many elements are `<= mid` using a staircase walk from the bottom-left. Find the smallest value where count `>= k`.

**Why the answer exists in the matrix.** The search domain bounds are actual matrix values. The final `lo` equals the smallest value with count `>= k`. Since we cannot "land" between matrix values (count is step-function), `lo` must be a real matrix element.

```java
class Solution {
    public int kthSmallest(int[][] matrix, int k) {
        int n = matrix.length;
        long lo = matrix[0][0], hi = matrix[n - 1][n - 1];

        while (lo < hi) {
            long mid = lo + (hi - lo) / 2;
            long count = countLessOrEqual(matrix, mid, n);
            if (count >= k) hi = mid;   // enough elements <= mid; try smaller
            else lo = mid + 1;
        }
        return (int) lo;
    }

    // Count elements <= val using staircase from bottom-left
    private long countLessOrEqual(int[][] matrix, long val, int n) {
        long count = 0;
        int row = n - 1, col = 0;
        while (row >= 0 && col < n) {
            if (matrix[row][col] <= val) {
                count += row + 1; // all elements in this column from row 0..row are <= val
                col++;
            } else {
                row--;
            }
        }
        return count;
    }

    public static void main(String[] args) {
        var s = new Solution();

        int r1 = s.kthSmallest(new int[][]{{1,5,9},{10,11,13},{12,13,15}}, 8);
        if (r1 != 13) throw new AssertionError("LC378 k=8: got " + r1);

        int r2 = s.kthSmallest(new int[][]{{1}}, 1);
        if (r2 != 1) throw new AssertionError("LC378 single: got " + r2);

        int r3 = s.kthSmallest(new int[][]{{1,2},{3,4}}, 1);
        if (r3 != 1) throw new AssertionError("LC378 k=1: got " + r3);

        int r4 = s.kthSmallest(new int[][]{{1,2},{3,4}}, 4);
        if (r4 != 4) throw new AssertionError("LC378 k=4: got " + r4);
    }
}
```

**Complexity.** Time O(n log(max - min)), Space O(1).

**Java-specific notes.**
- `lo` and `hi` are `long` even though matrix values fit in `int`. This avoids potential overflow if `matrix[0][0]` is near `Integer.MIN_VALUE` and `matrix[n-1][n-1]` near `Integer.MAX_VALUE` (not possible given LeetCode constraints, but the `long` types make `lo + (hi - lo) / 2` provably safe).
- `count += row + 1` counts the entire column `col` from row 0 through `row` inclusive — all guaranteed `<= val` because columns are sorted top-to-bottom.

---

## Standard Library Reference

Java provides `Arrays.binarySearch` but it has two critical limitations for competitive programming:

| Method | Returns | Limitation |
|---|---|---|
| `Arrays.binarySearch(arr, key)` | index (if found) or `-(ins_point)-1` | arbitrary index among duplicates |
| `Arrays.binarySearch(arr, from, to, key)` | same, restricted range | same duplicate problem |
| `Collections.binarySearch(list, key)` | same semantics | requires `Comparable` or `Comparator` |

For precise boundary queries, always hand-roll:

```java
import java.util.Arrays;

class StdlibDemo {
    public static void main(String[] args) {
        int[] nums = {1, 3, 5, 7, 9};

        // Arrays.binarySearch: exact match, no duplicate guarantee
        int idx = Arrays.binarySearch(nums, 5);
        if (idx != 2) throw new AssertionError("binarySearch(5): got " + idx);

        // Not found: returns -(insertion_point) - 1
        int notFound = Arrays.binarySearch(nums, 4);
        if (notFound != -3) throw new AssertionError("binarySearch(4): got " + notFound);
        // Insertion point = 2, so result = -(2) - 1 = -3.

        // Manual lower bound (first index >= target)
        int target = 5;
        int lo = 0, hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] < target) lo = mid + 1;
            else hi = mid;
        }
        if (lo != 2) throw new AssertionError("lower_bound(5): got " + lo);

        // Manual upper bound (first index > target)
        lo = 0; hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] <= target) lo = mid + 1;
            else hi = mid;
        }
        if (lo != 3) throw new AssertionError("upper_bound(5): got " + lo);
    }
}
```

---

## Chapter Review — Template Summary

### When to Use Which Template

```
Is the search space an index into a sorted array?
  YES → Do duplicates / boundaries matter?
          YES → Template 2: while (lo < hi), hi = mid or lo = mid + 1
                            Implement lowerBound() and upperBound() manually.
          NO  → Template 1: while (lo <= hi), classic ±1 on both ends
  NO  → Search for an optimal value in an abstract domain
          → Template 3: while (lo < hi)
              Minimize: hi = mid, lo = mid + 1, round-DOWN mid
              Maximize: lo = mid, hi = mid - 1, round-UP mid
```

| Template | Condition | Mid rounding | Post-loop meaning |
|---|---|---|---|
| T1 — exact match | `lo <= hi` | round down | element absent if loop exits |
| T2 — left boundary | `lo < hi` | round down | `lo == hi` is the boundary |
| T3 — minimize answer | `lo < hi` | round down | `lo` is smallest feasible |
| T3 — maximize answer | `lo < hi` | **round UP** | `lo` is largest feasible |

---

## 📝 Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|---|---|---|
| `mid * mid` overflow in LC #69 | Critical | All arithmetic cast to `long` before multiplication |
| Round-up mid omitted in maximize search (LC #1552) | Critical | `lo + (hi - lo + 1) / 2` used; clearly labeled with inline comment |
| Subarray sum overflow in LC #410, #1011 | High | Accumulator is `long`; loop variables typed accordingly |
| Ceiling-divide sum overflow in LC #875, #1283, #2064 | High | Sum accumulator typed `long` throughout |
| `assert` keyword used instead of throw | High | Zero uses of `assert`; every check uses `throw new AssertionError(...)` |
| `(lo + hi) / 2` overflow form | High | All mid computations use `lo + (hi - lo) / 2` or `lo + (hi - lo + 1) / 2` |
| `Arrays.binarySearch` used for boundary queries | Medium | Not used; all boundary searches use manual Template 2 loops |
| `hi--` vs `hi = mid - 1` distinction in LC #154 | Medium | `hi--` used correctly; comment explains why `hi = mid - 1` would skip too much |

---

### Third-Person Critical Review

**Mid overflow prevention.** The reviewer examined every `mid` computation across all 18 problems. No instance of `(lo + hi) / 2` or `(left + right) / 2` was found. All computations use either `lo + (hi - lo) / 2` (round-down, used in T1, T2, and T3-minimize) or `lo + (hi - lo + 1) / 2` (round-up, used in T3-maximize for LC #1552 and LC #69). This is consistent and correct.

**Loop invariants and off-by-one.** The chapter uses three distinct while conditions that must not be mixed:
- `while (lo <= hi)` — Template 1 only (LC #704, #374, #702). Post-loop `lo > hi`.
- `while (lo < hi)` — Template 2 (LC #278, #34, #154, #162, #436) and Template 3 (all answer-space problems). Post-loop `lo == hi`.

A reviewer spot-checking LC #278 confirms: `hi = mid` with round-down mid guarantees `hi` strictly decreases because `mid < hi` always holds when `lo < hi`. Spot-checking LC #1552 confirms: `lo = mid` with round-up mid guarantees `lo` strictly increases because `mid > lo` always holds when `lo < hi` and round-up is used. No off-by-one was found.

**`assert` keyword.** The `assert` keyword does not appear in any code block. Every test uses `throw new AssertionError("message: got " + actual)`, which is always evaluated regardless of JVM assertion flags (unlike `assert`, which requires `-ea`).

**`long` usage.** The reviewer checked all problems where overflow is a concern:
- LC #69: `long x64 = x`, `long lo = 1`, `long hi`, `mid * mid` — all `long`. Correct.
- LC #875, #1283, #2064: ceiling-divide sum accumulator is `long`. Correct.
- LC #1011, #410: subarray sum accumulator is `long`; `maxSum` / `capacity` parameters are `long`. Correct.
- LC #1552: position range computed as `long`; `minDist` parameter is `long`. Correct.
- LC #378: value-domain bounds are `long`; `count` return type is `long`. Correct.

**`switch` expressions.** The chapter avoids Java 17 preview-only `switch` pattern matching (which became stable in Java 21). Arrow-form `switch` over `enum` or `int` constants is available in Java 17, but none of the problems naturally call for it — `if/else` chains on comparison results are shorter and clearer. This is a conscious choice, not an oversight.

**Java 17+ features used.** `var` appears in main drivers where the inferred type is obvious. `record IndexedStart(int start, int idx)` in LC #436 demonstrates Java 16+ (stable in 17) record classes. No features beyond Java 17 are used.

---

### What This Chapter Does Well

1. **Consistent templates.** The three binary search templates are stated once, precisely, and then applied without variation. Every problem's code follows the exact template form — no ad-hoc variants that introduce subtle bugs.

2. **Overflow discipline.** Every problem with a squaring or large-sum risk explicitly uses `long` with a comment explaining why. The LC #69 discussion of why `(long) mid * mid` is required is particularly clear.

3. **Round-up mid discipline.** The maximize Template 3 variant (LC #1552, LC #69 sqrt) explicitly marks `+ 1` in the mid formula and explains the infinite-loop risk without it. This is the single most common binary search bug in interviews.

4. **Self-contained snippets.** Every code block compiles independently — helper interfaces (`GuessApi`, `ArrayReader`, `VersionApi`) appear in the same snippet as their users. No cross-block dependencies.

5. **Honest complexity.** LC #154 and #81 both state "O(log n) average, O(n) worst case (all duplicates)" rather than the common but incorrect "O(log n)" claim.

6. **Java vs Rust callout.** The opening section accurately describes `Arrays.binarySearch`'s limitations for duplicate-aware searches, the absence of `partition_point` in Java, and the `long` vs `int * int` overflow difference.

---

### What Could Be Improved

1. **No 2D binary search for LC #74 (Search a 2D Matrix I).** LC #74 (the simpler variant where the entire matrix is globally sorted) is not covered. A reader who encounters it after reading this chapter would benefit from the explicit "flatten index" technique: `mid = lo + (hi - lo) / 2; row = mid / n; col = mid % n`.

2. **`canShip` and `canSplit` are structurally identical.** The chapter could add a short callout noting that LC #875, #1011, and #410 all share the same "greedy grouping" simulation inside `feasible`. Recognizing the pattern family in an interview is as important as the binary search shell.

3. **No discussion of `TreeMap.ceilingKey` / `TreeMap.floorKey`.** For interval and "next greater" problems in practice, Java's `TreeMap.ceilingKey(key)` performs a balanced-BST search equivalent to a manual lower-bound. Mentioning this as an alternative for LC #436 would connect the chapter to real Java library usage.

4. **Test drivers stop at happy paths for some problems.** LC #81 and #154 cover the all-duplicates worst-case input in their tests, but LC #702 does not test a target at index 0 (where the exponential expansion starts at `hi = 1`). Adding `reader.get(0) == target` as a test case would close that gap.
