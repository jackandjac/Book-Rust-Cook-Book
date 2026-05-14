# Chapter LC-01 (Java): Arrays & Hashing

> Java solutions companion to [Rust Chapter LC-01](../leetcode/lc01-arrays-hashing.md).
> Java 17+ · All solutions verified correct.

---

## Problem Overview

| # | Problem | Difficulty | Blind75 | NeetCode150 |
|---|---------|-----------|---------|-------------|
| LC 217 | [Contains Duplicate](#lc-217--contains-duplicate) | Easy | ✓ | ✓ |
| LC 242 | [Valid Anagram](#lc-242--valid-anagram) | Easy | ✓ | ✓ |
| LC 1 | [Two Sum](#lc-1--two-sum) | Easy | ✓ | ✓ |
| LC 49 | [Group Anagrams](#lc-49--group-anagrams) | Medium | ✓ | ✓ |
| LC 347 | [Top K Frequent Elements](#lc-347--top-k-frequent-elements) | Medium | ✓ | ✓ |
| LC 238 | [Product of Array Except Self](#lc-238--product-of-array-except-self) | Medium | ✓ | ✓ |
| LC 36 | [Valid Sudoku](#lc-36--valid-sudoku) | Medium | ✓ | ✓ |
| LC 271 | [Encode and Decode Strings](#lc-271--encode-and-decode-strings) | Medium | ✓ | ✓ |
| LC 128 | [Longest Consecutive Sequence](#lc-128--longest-consecutive-sequence) | Medium | ✓ | ✓ |

---

## Java vs Rust Quick Reference

| Operation | Java | Rust |
|-----------|------|------|
| Hash map | `HashMap<K,V>` | `HashMap<K,V>` |
| Hash set | `HashSet<T>` | `HashSet<T>` |
| Map increment | `map.merge(k, 1, Integer::sum)` | `*map.entry(k).or_insert(0) += 1` |
| Default value | `map.getOrDefault(k, 0)` | `*map.entry(k).or_insert(0)` |
| Sorted array | `Arrays.sort(arr)` | `arr.sort()` / `arr.sort_unstable()` |
| Fixed-size array as map key | Must wrap: `String` or `List<Integer>` | Works natively: `[u8; 26]` implements `Hash` |
| Priority queue | `PriorityQueue` (min-heap by default) | `BinaryHeap` (max-heap by default) |
| Min-heap element | `PriorityQueue<>()` (natural order) | `BinaryHeap` + `Reverse<T>` |
| Set insert check | `!set.add(x)` returns `false` if present | `!set.insert(x)` returns `false` if present |
| String chars | `s.toCharArray()` | `s.as_bytes()` (ASCII) / `s.chars()` |
| Array fill | `Arrays.fill(arr, 0)` | `vec![0; n]` |

> **Key difference:** Java `int[]` uses identity-based `hashCode()` — two arrays with equal contents hash differently. Never use `int[]` as a `HashMap` key. Use a `String` fingerprint or `List<Integer>` instead. Rust `[u8; 26]` derives `Hash` structurally and works natively.

> **Assertion note:** All `main` methods below use explicit `if (!cond) throw new AssertionError("msg")` instead of Java's `assert` keyword, which requires the `-ea` JVM flag and is silently skipped otherwise.

---

## LC 217 — Contains Duplicate

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums`, return `true` if any value appears at least twice, and `false` if every element is distinct.

### Approach

Insert each number into a `HashSet`. `Set.add()` returns `false` if the element was already present — check that return value directly instead of calling `contains` first. This gives O(n) time and O(n) space.

**Alternative:** Sort and compare adjacent elements. O(n log n) time, O(1) extra space.

### Java Solution

```java
import java.util.HashSet;

class Solution {
    public boolean containsDuplicate(int[] nums) {
        var seen = new HashSet<Integer>();
        for (int n : nums) {
            if (!seen.add(n)) {   // add() returns false if already present
                return true;
            }
        }
        return false;
    }
}

class LC217Main {
    static void check(boolean actual, boolean expected, String label) {
        if (actual != expected)
            throw new AssertionError(label + ": expected " + expected + " got " + actual);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();
        check(s.containsDuplicate(new int[]{1, 2, 3, 1}),               true,  "has_duplicate");
        check(s.containsDuplicate(new int[]{1, 2, 3, 4}),               false, "all_unique");
        check(s.containsDuplicate(new int[]{1, 1, 1, 3, 3, 4, 3, 2}),  true,  "all_same");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| HashSet approach | O(n) | O(n) |
| Sort approach | O(n log n) | O(1) extra |

### Java Notes

- `Set.add()` returns `false` when the element is already present — same as Rust's `HashSet::insert`. Prefer checking the return value over calling `contains` then `add` (avoids double lookup).
- `var` (Java 10+) infers `HashSet<Integer>` from the right-hand side. Use it freely for locals to reduce verbosity.
- Java auto-boxes `int` to `Integer` for generic collections. For very large inputs this can pressure the GC; `IntStream` or a primitive hash structure (e.g., from Eclipse Collections) avoids it.

---

## LC 242 — Valid Anagram

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given two strings `s` and `t`, return `true` if `t` is an anagram of `s` — same characters with the same frequencies.

### Approach

Use an `int[26]` frequency array indexed by `c - 'a'`. Increment for each character in `s`, decrement for each in `t`. If any count is non-zero at the end, it is not an anagram. O(n) time, O(1) space (fixed 26-element array). For Unicode input, use `HashMap<Character, Integer>` instead.

### Java Solution

```java
import java.util.HashMap;

class Solution {
    // O(1) space — ASCII lowercase only
    public boolean isAnagram(String s, String t) {
        if (s.length() != t.length()) return false;

        var counts = new int[26];
        for (char c : s.toCharArray()) counts[c - 'a']++;
        for (char c : t.toCharArray()) counts[c - 'a']--;

        for (int v : counts) {
            if (v != 0) return false;
        }
        return true;
    }

    // Unicode-safe variant
    public boolean isAnagramUnicode(String s, String t) {
        if (s.length() != t.length()) return false;

        var map = new HashMap<Character, Integer>();
        for (char c : s.toCharArray()) map.merge(c, 1, Integer::sum);
        for (char c : t.toCharArray()) map.merge(c, -1, Integer::sum);

        return map.values().stream().allMatch(v -> v == 0);
    }
}

class LC242Main {
    static void check(boolean actual, boolean expected, String label) {
        if (actual != expected)
            throw new AssertionError(label + ": expected " + expected + " got " + actual);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();
        check(s.isAnagram("anagram", "nagaram"), true,  "valid_anagram");
        check(s.isAnagram("rat",     "car"),     false, "not_anagram");
        check(s.isAnagram("ab",      "abc"),     false, "diff_length");
        check(s.isAnagramUnicode("anagram", "nagaram"), true,  "unicode_valid");
        check(s.isAnagramUnicode("rat",     "car"),     false, "unicode_invalid");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Array approach | O(n) | O(1) — fixed 26 ints |
| HashMap approach | O(n) | O(k) — k unique chars |

### Java Notes

- `map.merge(key, 1, Integer::sum)` is the idiomatic Java increment. It is equivalent to `getOrDefault(key, 0) + 1` but performs a single lookup. Prefer it over `put(key, getOrDefault(key, 0) + 1)`.
- `s.toCharArray()` allocates — for performance-sensitive code, index with `s.charAt(i)` instead.
- Rust's `counts.iter().all(|&c| c == 0)` maps to `stream().allMatch(v -> v == 0)` in Java. The Java stream has slight overhead; a simple `for` loop is faster in practice.

---

## LC 1 — Two Sum

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums` and an integer `target`, return the indices of the two numbers that add up to `target`. Exactly one valid answer exists.

### Approach

One-pass HashMap. For each element, compute `complement = target - nums[i]`. If `complement` is already in the map, we found the pair. Insert the current number and its index after the lookup so a number can't pair with itself.

### Java Solution

```java
import java.util.Arrays;
import java.util.HashMap;

class Solution {
    public int[] twoSum(int[] nums, int target) {
        var seen = new HashMap<Integer, Integer>(); // value -> index

        for (int i = 0; i < nums.length; i++) {
            int complement = target - nums[i];
            if (seen.containsKey(complement)) {
                return new int[]{seen.get(complement), i};
            }
            seen.put(nums[i], i);
        }

        throw new IllegalArgumentException("No two-sum solution found");
    }
}

class LC1Main {
    static void check(int[] actual, int[] expected, String label) {
        if (!Arrays.equals(actual, expected))
            throw new AssertionError(label + ": expected " + Arrays.toString(expected)
                                     + " got " + Arrays.toString(actual));
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();
        check(s.twoSum(new int[]{2, 7, 11, 15}, 9), new int[]{0, 1}, "basic");
        check(s.twoSum(new int[]{3, 2, 4},       6), new int[]{1, 2}, "non_adjacent");
        check(s.twoSum(new int[]{3, 3},           6), new int[]{0, 1}, "same_element_twice");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| One-pass HashMap | O(n) | O(n) |

### Java Notes

- Inserting *after* the lookup is essential: it prevents `nums[i]` from pairing with itself. `[3, 3], target=6` correctly returns `[0, 1]` because index 0 is in the map when we process index 1.
- `seen.containsKey(complement)` + `seen.get(complement)` performs two lookups. For a slight optimization use `seen.getOrDefault(complement, -1)` with a sentinel, or pattern-match on `computeIfAbsent`. In practice the two-lookup form is clearest.
- Rust uses `unreachable!()` for the impossible branch. Java's equivalent is `throw new IllegalArgumentException(...)` or `throw new AssertionError(...)`.

---

## LC 49 — Group Anagrams

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an array of strings, group the anagrams together. Order of groups and order within groups does not matter.

### Approach

For each string, sort its characters to get a canonical key. Strings that are anagrams of each other produce the same sorted key. Group them in a `HashMap<String, List<String>>`.

**Why not `int[]` as key?** Java arrays use identity-based `hashCode()` — two `int[]` instances with equal contents hash to different buckets. Always use a `String` or `List<Integer>` as the key.

### Java Solution

```java
import java.util.*;

class Solution {
    public List<List<String>> groupAnagrams(String[] strs) {
        var map = new HashMap<String, List<String>>();

        for (String s : strs) {
            var chars = s.toCharArray();
            Arrays.sort(chars);
            var key = new String(chars);           // sorted chars → canonical key
            map.computeIfAbsent(key, k -> new ArrayList<>()).add(s);
        }

        return new ArrayList<>(map.values());
    }
}

class LC49Main {
    // Returns a new sorted copy — does NOT mutate the input.
    // Necessary because expected values use List.of() which is immutable.
    static List<List<String>> normalize(List<List<String>> groups) {
        var out = new ArrayList<List<String>>();
        for (var g : groups) {
            var inner = new ArrayList<>(g);
            Collections.sort(inner);
            out.add(inner);
        }
        out.sort(Comparator.comparing(g -> g.isEmpty() ? "" : g.get(0)));
        return out;
    }

    static void check(List<List<String>> actual, List<List<String>> expected, String label) {
        if (!normalize(actual).equals(normalize(expected)))
            throw new AssertionError(label + ": expected " + expected + " got " + actual);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();

        check(
            s.groupAnagrams(new String[]{"eat", "tea", "tan", "ate", "nat", "bat"}),
            List.of(List.of("ate", "eat", "tea"), List.of("bat"), List.of("nat", "tan")),
            "basic"
        );
        check(
            s.groupAnagrams(new String[]{""}),
            List.of(List.of("")),
            "single_empty"
        );
        check(
            s.groupAnagrams(new String[]{"a", "a", "a"}),
            List.of(List.of("a", "a", "a")),
            "all_same"
        );
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Sorted-string key | O(n · k log k) where k = avg string length | O(n · k) |
| Count-array key (String fingerprint) | O(n · k) | O(n · k) |

### Java Notes

- **Critical Java trap:** `int[]` uses reference equality for `hashCode()` and `equals()`. Using `new int[26]` as a `HashMap` key silently fails — every array hashes to a unique bucket. Rust's `[u8; 26]` implements `Hash` structurally, so this just works. In Java, build a `String` or `List<Integer>` key.
- `map.computeIfAbsent(key, k -> new ArrayList<>())` is the idiomatic one-liner for "get or create a list". It performs one lookup vs two for `containsKey` + `put`.
- `HashMap` iteration order is unspecified — sort both inner lists and the outer list before comparing in tests. The `normalize` helper does this.

---

## LC 347 — Top K Frequent Elements

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums` and an integer `k`, return the `k` most frequent elements in any order.

### Approach

**Bucket sort (O(n)):** Count frequencies with a `HashMap`. Then bucket sort: `buckets[i]` holds all numbers with frequency `i`. Scan from the highest bucket down, collecting until we have `k` elements.

**Alternative (min-heap, O(n log k)):** Use a `PriorityQueue` of size `k`. Java's `PriorityQueue` is a min-heap by default — poll the smallest when the heap exceeds size `k`, keeping only the top-k frequent elements.

### Java Solution

```java
import java.util.*;

class Solution {
    // O(n) bucket sort
    public int[] topKFrequent(int[] nums, int k) {
        var freq = new HashMap<Integer, Integer>();
        for (int n : nums) freq.merge(n, 1, Integer::sum);

        // buckets[i] = numbers with frequency i
        @SuppressWarnings("unchecked")
        var buckets = (List<Integer>[]) new List[nums.length + 1];
        for (int i = 0; i <= nums.length; i++) buckets[i] = new ArrayList<>();

        for (var entry : freq.entrySet()) {
            buckets[entry.getValue()].add(entry.getKey());
        }

        var result = new int[k];
        int idx = 0;
        for (int f = nums.length; f >= 1 && idx < k; f--) {
            for (int num : buckets[f]) {
                if (idx == k) break;
                result[idx++] = num;
            }
        }
        return result;
    }

    // O(n log k) min-heap alternative
    public int[] topKFrequentHeap(int[] nums, int k) {
        var freq = new HashMap<Integer, Integer>();
        for (int n : nums) freq.merge(n, 1, Integer::sum);

        // Min-heap ordered by frequency (natural order on Integer = min-heap)
        // Java PriorityQueue IS a min-heap by default — no Reverse wrapper needed
        var heap = new PriorityQueue<Integer>(Comparator.comparingInt(freq::get));
        for (int num : freq.keySet()) {
            heap.offer(num);
            if (heap.size() > k) heap.poll(); // evict least frequent
        }

        var result = new int[k];
        for (int i = k - 1; i >= 0; i--) result[i] = heap.poll();
        return result;
    }
}

class LC347Main {
    static int[] sorted(int[] arr) {
        var copy = arr.clone();
        Arrays.sort(copy);
        return copy;
    }

    static void check(int[] actual, int[] expected, String label) {
        if (!Arrays.equals(sorted(actual), sorted(expected)))
            throw new AssertionError(label + ": expected " + Arrays.toString(expected)
                                     + " got " + Arrays.toString(actual));
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();
        check(s.topKFrequent(new int[]{1, 1, 1, 2, 2, 3}, 2), new int[]{1, 2}, "bucket_basic");
        check(s.topKFrequent(new int[]{1}, 1),                new int[]{1},    "bucket_single");
        check(s.topKFrequentHeap(new int[]{1, 1, 1, 2, 2, 3}, 2), new int[]{1, 2}, "heap_basic");
        check(s.topKFrequentHeap(new int[]{1}, 1),                new int[]{1},    "heap_single");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Bucket sort | O(n) | O(n) |
| Min-heap | O(n log k) | O(n + k) |

### Java Notes

- **Heap direction is flipped vs Rust.** Rust's `BinaryHeap` is a max-heap; getting a min-heap requires `Reverse<T>`. Java's `PriorityQueue` is a min-heap by default — no wrapper needed. Supply a comparator `Comparator.comparingInt(freq::get)` to order by frequency.
- Generic array creation (`new List[n]`) requires an unchecked cast in Java. The `@SuppressWarnings("unchecked")` annotation suppresses the warning and is appropriate when the cast is provably safe.
- Sort results before comparing in tests — both `HashMap` and bucket-scan order are unspecified.

---

## LC 238 — Product of Array Except Self

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums`, return an array where `output[i]` is the product of all elements except `nums[i]`. Solve in O(n) time without division.

### Approach

Two-pass, O(1) extra space (output array excluded):
1. **Left pass:** `output[i]` = product of all elements to the left of `i`.
2. **Right pass:** Multiply `output[i]` by a running right product scanning right-to-left.

### Java Solution

```java
class Solution {
    public int[] productExceptSelf(int[] nums) {
        int n = nums.length;
        var output = new int[n];

        // Left pass: output[i] = product of nums[0..i-1]
        output[0] = 1;
        for (int i = 1; i < n; i++) {
            output[i] = output[i - 1] * nums[i - 1];
        }

        // Right pass: multiply in the suffix product
        int suffix = 1;
        for (int i = n - 1; i >= 0; i--) {
            output[i] *= suffix;
            suffix *= nums[i];
        }

        return output;
    }
}

class LC238Main {
    static void check(int[] actual, int[] expected, String label) {
        if (!java.util.Arrays.equals(actual, expected))
            throw new AssertionError(label + ": expected " + java.util.Arrays.toString(expected)
                                     + " got " + java.util.Arrays.toString(actual));
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();
        check(s.productExceptSelf(new int[]{1, 2, 3, 4}),     new int[]{24, 12, 8, 6},  "basic");
        check(s.productExceptSelf(new int[]{-1, 1, 0, -3, 3}), new int[]{0, 0, 9, 0, 0}, "with_zero");
        check(s.productExceptSelf(new int[]{3, 4}),            new int[]{4, 3},           "two_elements");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Two-pass | O(n) | O(1) extra (output array excluded) |

### Java Notes

- Integer overflow: for the LeetCode constraints (`-30 <= nums[i] <= 30`, at most 10^5 elements) products stay within `int` range. For unconstrained input, use `long`.
- The right-pass loop `for (int i = n - 1; i >= 0; i--)` is Java's idiomatic reverse loop. Rust uses `(0..n).rev()` — a cleaner expression but same semantics.
- No tricky aliasing: `output` is the only mutable array and `nums` is read-only, so this is straightforward in both Java and Rust.

---

## LC 36 — Valid Sudoku

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Determine if a 9×9 Sudoku board is valid: each row, each column, and each of the nine 3×3 boxes contains the digits 1–9 with no repeats. Empty cells contain `'.'`.

### Approach

Single pass over all 81 cells. Maintain three `boolean[9][9]` arrays — one for rows, one for columns, one for 3×3 boxes. For cell `(r, c)` with digit `d`, the box index is `(r / 3) * 3 + (c / 3)`.

### Java Solution

```java
class Solution {
    public boolean isValidSudoku(char[][] board) {
        boolean[][] rows  = new boolean[9][9];
        boolean[][] cols  = new boolean[9][9];
        boolean[][] boxes = new boolean[9][9];

        for (int r = 0; r < 9; r++) {
            for (int c = 0; c < 9; c++) {
                char ch = board[r][c];
                if (ch == '.') continue;

                int d       = ch - '1';              // '1'→0, '9'→8
                int boxIdx  = (r / 3) * 3 + (c / 3);

                if (rows[r][d] || cols[c][d] || boxes[boxIdx][d]) return false;

                rows[r][d]       = true;
                cols[c][d]       = true;
                boxes[boxIdx][d] = true;
            }
        }
        return true;
    }
}

class LC36Main {
    static char[][] board(String[] rows) {
        char[][] b = new char[9][9];
        for (int r = 0; r < 9; r++) b[r] = rows[r].toCharArray();
        return b;
    }

    static void check(boolean actual, boolean expected, String label) {
        if (actual != expected)
            throw new AssertionError(label + ": expected " + expected + " got " + actual);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();

        check(s.isValidSudoku(board(new String[]{
            "53..7....", "6..195...", ".98....6.",
            "8...6...3", "4..8.3..1", "7...2...6",
            ".6....28.", "...419..5", "....8..79"
        })), true, "valid_board");

        check(s.isValidSudoku(board(new String[]{
            "83..7....", "6..195...", ".98....6.",
            "8...6...3", "4..8.3..1", "7...2...6",
            ".6....28.", "...419..5", "....8..79"
        })), false, "invalid_row_dup");

        check(s.isValidSudoku(board(new String[]{
            "8......1.", "8......1.", ".........",
            ".........", ".........", ".........",
            ".........", ".........", "........."
        })), false, "invalid_col_dup");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Single pass | O(1) — board is always 81 cells | O(1) — fixed-size arrays |

### Java Notes

- `char[][] board` matches the LeetCode signature exactly. Rust uses `Vec<Vec<char>>` since fixed-size 2D Vecs are more common there.
- `ch - '1'` is char arithmetic in both languages. Java `char` subtraction produces an `int` directly; Rust requires a cast: `(ch as u8 - b'1') as usize`.
- Both `boolean[9][9]` (Java) and `[[bool; 9]; 9]` (Rust) live on the stack and are zero/false initialized automatically.

---

## LC 271 — Encode and Decode Strings

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Design an algorithm to encode a list of strings into a single string and decode it back. Strings may contain any characters including `'#'` and spaces.

### Approach

**Length-prefix encoding:** For each string, write `"{length}#{string}"`. During decode, read the length, skip the `#`, then slice exactly that many characters. This is unambiguous regardless of string content.

Example: `["foo", "bar#baz"]` → `"3#foo7#bar#baz"`

### Java Solution

```java
import java.util.ArrayList;
import java.util.List;

// LeetCode uses instance methods, not static
class Codec {
    public String encode(List<String> strs) {
        var sb = new StringBuilder();
        for (String s : strs) {
            sb.append(s.length()).append('#').append(s);
        }
        return sb.toString();
    }

    public List<String> decode(String s) {
        var result = new ArrayList<String>();
        int i = 0;
        while (i < s.length()) {
            int j = i;
            while (s.charAt(j) != '#') j++;          // find the '#'
            int len = Integer.parseInt(s.substring(i, j));
            result.add(s.substring(j + 1, j + 1 + len));
            i = j + 1 + len;
        }
        return result;
    }
}

class LC271Main {
    static void check(List<String> actual, List<String> expected, String label) {
        if (!actual.equals(expected))
            throw new AssertionError(label + ": expected " + expected + " got " + actual);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var codec = new Codec();

        var basic = List.of("lint", "code", "love", "you");
        check(codec.decode(codec.encode(basic)), basic, "roundtrip_basic");

        var withHash = List.of("foo", "bar#baz", "#");
        check(codec.decode(codec.encode(withHash)), withHash, "strings_with_hash");

        var withEmpty = List.of("", "hello", "");
        check(codec.decode(codec.encode(withEmpty)), withEmpty, "empty_strings");

        var emptyList = List.<String>of();
        check(codec.decode(codec.encode(emptyList)), emptyList, "empty_list");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Encode | O(n · k) — n strings of avg length k | O(n · k) |
| Decode | O(n · k) | O(n · k) |

### Java Notes

- LeetCode defines `encode` and `decode` as **instance methods** on `Codec`, not static. The Rust solution uses associated functions (`Codec::encode`), which are implicitly static-like. Keep the instance form for LeetCode compatibility.
- `StringBuilder.append` chains efficiently — avoid `String` concatenation in a loop; it creates O(n^2) intermediate strings.
- Rust's `std::str::from_utf8` is needed because byte slices aren't guaranteed to be valid UTF-8. Java `String.substring` always returns valid strings, so no such check is needed.
- The length-prefix scheme is unambiguous: even if the string starts with digits, the first `#` found while scanning from position `i` is always the delimiter, because we placed it there during encoding.

---

## LC 128 — Longest Consecutive Sequence

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an unsorted array of integers `nums`, return the length of the longest consecutive elements sequence. Must run in O(n) time.

### Approach

Load all numbers into a `HashSet`. For each number `n`, only start counting if `n - 1` is **not** in the set (i.e., `n` is the start of a sequence). Then walk upward counting `n+1, n+2, ...`. Each element is visited at most twice across the entire algorithm — O(n) total.

### Java Solution

```java
import java.util.HashSet;

class Solution {
    public int longestConsecutive(int[] nums) {
        var set = new HashSet<Integer>();
        for (int n : nums) set.add(n);

        int best = 0;
        for (int n : set) {
            if (set.contains(n - 1)) continue;  // not the start of a sequence

            int length = 1;
            while (set.contains(n + length)) length++;
            best = Math.max(best, length);
        }
        return best;
    }
}

class LC128Main {
    static void check(int actual, int expected, String label) {
        if (actual != expected)
            throw new AssertionError(label + ": expected " + expected + " got " + actual);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) {
        var s = new Solution();
        check(s.longestConsecutive(new int[]{100, 4, 200, 1, 3, 2}),      4, "basic");
        check(s.longestConsecutive(new int[]{0, 3, 7, 2, 5, 8, 4, 6, 0, 1}), 9, "all_consecutive");
        check(s.longestConsecutive(new int[]{}),                          0, "empty");
        check(s.longestConsecutive(new int[]{42}),                        1, "single");
        check(s.longestConsecutive(new int[]{1, 2, 2, 3}),                3, "duplicates");
    }
}
```

### Complexity

| | Time | Space |
|-|------|-------|
| HashSet approach | O(n) | O(n) |

### Java Notes

- Iterating `for (int n : set)` works correctly — `HashSet` is `Iterable`. Rust uses `for &n in &set` with explicit reference destructuring; Java's enhanced for loop handles unboxing from `Integer` to `int` automatically.
- `HashSet` deduplicates automatically, so `[1, 2, 2, 3]` behaves identically to `[1, 2, 3]`. This is correct — consecutive sequences are about values, not counts.
- `Math.max(best, length)` vs Rust's `best.max(length)` — same operation, different syntax. Rust's method form reads more fluently.
- Unlike Rust, Java's `set.contains(n - 1)` auto-boxes `n - 1` (an `int`) to `Integer`. This is invisible but adds allocation pressure in a tight loop. For very large inputs consider `IntOpenHashSet` from Eclipse Collections.

---

## Summary Table

| Problem | Java Key Type | Java Key Idiom | Rust Key |
|---------|--------------|----------------|----------|
| LC 217 | `HashSet<Integer>` | `!set.add(n)` | `HashSet<i32>`, `!set.insert(n)` |
| LC 242 | `int[26]` | `counts[c-'a']++` | `[i32; 26]`, same |
| LC 1 | `HashMap<Integer,Integer>` | `map.containsKey` + `map.get` | `HashMap<i32,usize>`, `map.get(&k)` |
| LC 49 | `HashMap<String,List<String>>` | Sorted-char `String` key | `HashMap<[u8;26],Vec<String>>` |
| LC 347 | `PriorityQueue` (min-heap) | Natural order | `BinaryHeap` + `Reverse` |
| LC 238 | `int[]` | Two-pass in-place | `Vec<i32>`, same |
| LC 36 | `boolean[9][9]` | `ch - '1'` | `[[bool;9];9]`, `ch as u8 - b'1'` |
| LC 271 | `StringBuilder` | `len + "#" + str` | `String::push_str` |
| LC 128 | `HashSet<Integer>` | `set.contains(n-1)` | `HashSet<i32>`, `set.contains(&(n-1))` |

---

## Checklist Before Submitting on LeetCode

- [ ] Remove the outer class wrapper and `main` method — LeetCode expects only the `Solution` or `Codec` class
- [ ] Check that imports are present (`java.util.*`)
- [ ] For LC 49, confirm you are NOT using `int[]` as a `HashMap` key
- [ ] For LC 347 heap variant, confirm the `PriorityQueue` comparator compares by **frequency**, not by value
- [ ] For LC 271, keep `encode`/`decode` as **instance methods**, not `static`

---

## 📝 Chapter Review Notes

*Third-person critical review of the solutions above. Issues are identified, rated, and fixed inline.*

### Fact-Check Table

| Problem | Correctness | Notes |
|---------|------------|-------|
| LC 217 — Contains Duplicate | OK | `Set.add()` returning `false` on duplicate is correct Java spec |
| LC 242 — Valid Anagram | OK | `int[26]` approach is O(1) space; `merge` idiom is correct |
| LC 1 — Two Sum | OK | Insert-after-lookup correctly handles `[3,3],target=6` |
| LC 49 — Group Anagrams | OK (fixed) | **Issue found and fixed:** original draft used `int[]` as key; replaced with sorted-string key |
| LC 347 — Top K Frequent | OK | Min-heap framing is correct for Java; bucket sort is O(n) |
| LC 238 — Product Except Self | Medium | Integer overflow possible for unconstrained input — noted |
| LC 36 — Valid Sudoku | OK | Box formula `(r/3)*3+(c/3)` and digit mapping `ch-'1'` are correct |
| LC 271 — Encode/Decode | OK | Instance methods match LeetCode signature; length-prefix is unambiguous |
| LC 128 — Longest Consecutive | OK | Auto-boxing overhead noted; algorithm is O(n) correct |

### Issues Found and Fixed

**Issue 1 — LC 49: `int[]` cannot be used as a `HashMap` key in Java (High)**

An early draft used `new int[26]` as the map key, matching the Rust `[u8; 26]` pattern. Java arrays use `Object.hashCode()` (identity-based), so two arrays with equal contents hash to different buckets, silently producing wrong results — every string would become its own group.

Fix: Use `new String(chars)` after `Arrays.sort(chars)` as the key. This is O(k log k) per string but produces a correct, structurally-equal key. A `List<Integer>` wrapper would also work but allocates more.

**Issue 2 — `assert` keyword requires `-ea` JVM flag (High)**

Java's `assert x : "msg"` is a no-op unless the JVM is started with `-ea` (enable assertions). A cookbook reader running `java LC217Main` with assertions disabled would see all tests silently pass even if the logic is wrong. Fixed throughout: all verification uses explicit `if (!cond) throw new AssertionError(...)`, which always executes.

**Issue 3 — LC 238: Integer overflow for unconstrained input (Medium)**

The two-pass product computation uses `int` arithmetic. For the LeetCode constraints (`-30 <= nums[i] <= 30`, length ≤ 10^5) this is safe — the maximum intermediate product is 30^2 = 900, well within `int`. For unconstrained input (e.g., large values), overflow is silent and produces wrong results. A production-quality solution would use `long`. Added a note in the Java Notes section; the code is correct for the given constraints.

**Issue 4 — LC 347 heap variant: comparator captured `freq` map by reference (Low)**

`Comparator.comparingInt(freq::get)` captures `freq` as a method reference. If `freq` were modified after the comparator is created, the heap ordering would become inconsistent. Here `freq` is final after construction and is never modified while the heap is active, so this is safe. Noted in review; no code change needed.

**Issue 5 — LC 271 encode/decode: LeetCode signature uses instance methods (Low)**

The Rust solution uses associated functions (`Codec::encode`) which are effectively static. LeetCode's Java scaffold defines `encode` and `decode` as instance methods. Fixed: the Java solution uses instance methods and the test instantiates `new Codec()`.

### Rust vs Java Teaching Moments

1. **Array-as-key:** Rust `[u8; 26]` works as a `HashMap` key because `Hash` is derived structurally. Java `int[]` silently fails because `hashCode()` is identity-based. This is the most dangerous silent footgun in this chapter.
2. **Heap direction:** Rust `BinaryHeap` = max-heap; needs `Reverse<T>` for min-heap. Java `PriorityQueue` = min-heap; no wrapper needed. Both can be surprising coming from the other language.
3. **Assert discipline:** Rust `#[test]` macros always run assertions. Java `assert` requires `-ea`. For standalone `main`-based tests, always use explicit `throw new AssertionError`.
4. **Entry API:** Rust `*map.entry(k).or_insert(0) += 1` has no direct Java equivalent. Use `map.merge(k, 1, Integer::sum)` — one lookup, correct semantics.
5. **Auto-boxing:** Java collections store `Integer`, not `int`. In tight inner loops (LC 128's `set.contains(n+length)`) this boxes on every call. Rust uses `i32` directly with no overhead.

---

*Java 17+ · Chapter LC-01 (Java) · Arrays & Hashing*
