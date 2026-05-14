# Chapter LC-01: Arrays & Hashing

> **Cookbook Philosophy:** LeetCode problems distilled for Java developers learning Rust. Every solution is self-contained and runnable with `rustc --test <file>` or inside a Cargo project. Focus is on idiomatic Rust — not just "making it work," but showing Rust's actual strengths.

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

## Java → Rust Quick Reference for This Chapter

| Java idiom | Rust equivalent | Notes |
|-----------|----------------|-------|
| `new HashSet<>()` | `HashSet::new()` | `use std::collections::HashSet` |
| `new HashMap<>()` | `HashMap::new()` | `use std::collections::HashMap` |
| `map.getOrDefault(k, 0)` | `*map.entry(k).or_insert(0)` | Entry API returns `&mut V` — you must dereference |
| `map.get(k) != null` | `map.contains_key(&k)` | |
| `set.contains(x)` | `set.contains(&x)` | Rust takes a borrow |
| `Collections.sort(list)` | `list.sort()` or `list.sort_unstable()` | `sort_unstable` is faster, same complexity |
| `s.charAt(i) - 'a'` | `(b - b'a') as usize` on `s.as_bytes()[i]` | ASCII arithmetic; use `.as_bytes()` for ASCII |
| `Arrays.fill(arr, 0)` | `vec![0; n]` or `[0i32; 26]` | Rust initializes arrays and vecs |
| `list.size()` | `vec.len()` | Returns `usize`, not `int` |

---

## LC 217 — Contains Duplicate

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums`, return `true` if any value appears **at least twice**, and `false` if every element is distinct.

### Approach

Insert each number into a `HashSet`. If the insert fails (element already present), a duplicate exists. The `HashSet::insert` method returns `false` if the value was already in the set — we use that directly.

**Alternative:** Sort and compare adjacent elements. O(n log n) time, O(1) extra space. Less idiomatic but useful if space is constrained.

### Rust Solution

```rust
use std::collections::HashSet;

struct Solution;

impl Solution {
    pub fn contains_duplicate(nums: Vec<i32>) -> bool {
        let mut seen = HashSet::new();
        for n in nums {
            // insert() returns false if the value was already present
            if !seen.insert(n) {
                return true;
            }
        }
        false
    }

    // Iterator one-liner for comparison
    pub fn contains_duplicate_iter(nums: Vec<i32>) -> bool {
        let len = nums.len();
        let unique: HashSet<i32> = nums.into_iter().collect();
        unique.len() < len
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_has_duplicate() {
        assert_eq!(Solution::contains_duplicate(vec![1, 2, 3, 1]), true);
    }

    #[test]
    fn test_all_unique() {
        assert_eq!(Solution::contains_duplicate(vec![1, 2, 3, 4]), false);
    }

    #[test]
    fn test_all_same() {
        assert_eq!(Solution::contains_duplicate(vec![1, 1, 1, 3, 3, 4, 3, 2, 4, 2]), true);
    }

    #[test]
    fn test_iter_variant() {
        assert_eq!(Solution::contains_duplicate_iter(vec![1, 2, 3, 1]), true);
        assert_eq!(Solution::contains_duplicate_iter(vec![1, 2, 3, 4]), false);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| HashSet approach | O(n) | O(n) |
| Sort approach | O(n log n) | O(1) extra |

### Rust Notes

- `HashSet::insert` returns `bool` — Java's `Set.add` does the same, but Java developers often forget and use `contains` first. In Rust, check the return value.
- `into_iter()` consumes the `Vec` (moves ownership). Use `iter()` if you need the `Vec` afterward.
- The type is inferred from the `Vec<i32>` input; `HashSet::new()` needs no type annotation here.

---

## LC 242 — Valid Anagram

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given two strings `s` and `t`, return `true` if `t` is an anagram of `s` (contains exactly the same characters with the same frequencies).

### Approach

Use a `[i32; 26]` frequency array indexed by `c - 'a'`. Increment for each character in `s`, decrement for each in `t`. If any count is non-zero at the end, it's not an anagram. This works only for lowercase ASCII — use a `HashMap<char, i32>` for Unicode input.

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn is_anagram(s: String, t: String) -> bool {
        if s.len() != t.len() {
            return false;
        }

        let mut counts = [0i32; 26];

        // s.as_bytes() yields &[u8] — safe for ASCII lowercase
        for b in s.as_bytes() {
            counts[(b - b'a') as usize] += 1;
        }
        for b in t.as_bytes() {
            counts[(b - b'a') as usize] -= 1;
        }

        counts.iter().all(|&c| c == 0)
    }

    // Unicode-safe variant using HashMap
    pub fn is_anagram_unicode(s: String, t: String) -> bool {
        use std::collections::HashMap;

        if s.chars().count() != t.chars().count() {
            return false;
        }

        let mut counts: HashMap<char, i32> = HashMap::new();
        for c in s.chars() {
            *counts.entry(c).or_insert(0) += 1;
        }
        for c in t.chars() {
            *counts.entry(c).or_insert(0) -= 1;
        }
        counts.values().all(|&v| v == 0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_anagram() {
        assert_eq!(Solution::is_anagram("anagram".to_string(), "nagaram".to_string()), true);
    }

    #[test]
    fn test_not_anagram() {
        assert_eq!(Solution::is_anagram("rat".to_string(), "car".to_string()), false);
    }

    #[test]
    fn test_different_lengths() {
        assert_eq!(Solution::is_anagram("ab".to_string(), "abc".to_string()), false);
    }

    #[test]
    fn test_unicode_variant() {
        assert_eq!(Solution::is_anagram_unicode("anagram".to_string(), "nagaram".to_string()), true);
        assert_eq!(Solution::is_anagram_unicode("rat".to_string(), "car".to_string()), false);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Array approach | O(n) | O(1) — fixed 26-element array |
| HashMap approach | O(n) | O(k) — k = unique characters |

### Rust Notes

- `s.as_bytes()` is O(1) and returns `&[u8]` — correct for ASCII. Do **not** index a `&str` with `s[i]`; Rust panics on non-ASCII boundaries.
- `b - b'a'` is `u8` arithmetic. Cast to `usize` immediately for array indexing: `(b - b'a') as usize`.
- The entry API pattern `*counts.entry(c).or_insert(0) += 1` is the canonical HashMap increment. The dereference `*` is required because `entry().or_insert()` returns `&mut V`.
- `counts.iter().all(|&c| c == 0)` — the `&c` destructures the `&&i32` reference from iterating over a `&[i32]` slice reference. Without `&c`, `c` would be `&i32` and the comparison `c == 0` would fail to compile.

---

## LC 1 — Two Sum

**Difficulty:** Easy | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums` and an integer `target`, return the **indices** of the two numbers that add up to `target`. Exactly one valid answer exists.

### Approach

As we iterate, store each number and its index in a `HashMap<i32, usize>`. For each element, check if `target - element` is already in the map. If so, we found the pair in one pass.

### Rust Solution

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn two_sum(nums: Vec<i32>, target: i32) -> Vec<i32> {
        let mut seen: HashMap<i32, usize> = HashMap::new();

        for (i, &num) in nums.iter().enumerate() {
            let complement = target - num;
            if let Some(&j) = seen.get(&complement) {
                // Return as Vec<i32> to match LeetCode signature
                return vec![j as i32, i as i32];
            }
            seen.insert(num, i);
        }

        // Problem guarantees exactly one solution; unreachable in practice
        unreachable!("no two sum solution found")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        assert_eq!(Solution::two_sum(vec![2, 7, 11, 15], 9), vec![0, 1]);
    }

    #[test]
    fn test_non_adjacent() {
        assert_eq!(Solution::two_sum(vec![3, 2, 4], 6), vec![1, 2]);
    }

    #[test]
    fn test_same_element_twice() {
        assert_eq!(Solution::two_sum(vec![3, 3], 6), vec![0, 1]);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| One-pass HashMap | O(n) | O(n) |

### Rust Notes

- `nums.iter().enumerate()` yields `(usize, &i32)`. The pattern `(i, &num)` destructures the reference: `i` is `usize`, `num` is `i32`.
- `seen.get(&complement)` takes a **reference**. In Java you'd call `seen.get(complement)` — in Rust the standard collections take `&K`. The `&` is easy to forget.
- `if let Some(&j) = seen.get(&complement)` — the `&j` inside `Some` destructures the `&usize` returned by `get`, giving us `j: usize` directly.
- Return type is `Vec<i32>` to match LeetCode. The `j as i32` cast is required because `j` is `usize`. Rust does not implicitly convert numeric types.
- Using `unreachable!()` is cleaner than `panic!("...")` and signals intent to both the compiler and reader.

---

## LC 49 — Group Anagrams

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an array of strings, group the anagrams together. The order of groups and the order within each group does not matter.

### Approach

For each string, compute a canonical key — either a sorted version of its characters or a `[u8; 26]` character-frequency fingerprint. Use the key to group strings into a `HashMap`. The `[u8; 26]` key avoids allocating a sorted `String` per entry and is directly hashable.

### Rust Solution

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn group_anagrams(strs: Vec<String>) -> Vec<Vec<String>> {
        let mut map: HashMap<[u8; 26], Vec<String>> = HashMap::new();

        for s in strs {
            let mut key = [0u8; 26];
            for b in s.as_bytes() {
                key[(b - b'a') as usize] += 1;
            }
            map.entry(key).or_insert_with(Vec::new).push(s);
        }

        map.into_values().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn normalized(mut groups: Vec<Vec<String>>) -> Vec<Vec<String>> {
        for g in &mut groups {
            g.sort();
        }
        groups.sort();
        groups
    }

    #[test]
    fn test_basic() {
        let input = vec![
            "eat".to_string(), "tea".to_string(), "tan".to_string(),
            "ate".to_string(), "nat".to_string(), "bat".to_string(),
        ];
        let result = Solution::group_anagrams(input);
        let expected = vec![
            vec!["ate".to_string(), "eat".to_string(), "tea".to_string()],
            vec!["bat".to_string()],
            vec!["nat".to_string(), "tan".to_string()],
        ];
        assert_eq!(normalized(result), normalized(expected));
    }

    #[test]
    fn test_single_empty_string() {
        let result = Solution::group_anagrams(vec!["".to_string()]);
        assert_eq!(result, vec![vec!["".to_string()]]);
    }

    #[test]
    fn test_all_same() {
        let input = vec!["a".to_string(), "a".to_string(), "a".to_string()];
        let result = Solution::group_anagrams(input);
        assert_eq!(result, vec![vec!["a".to_string(), "a".to_string(), "a".to_string()]]);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| `[u8; 26]` key approach | O(n · k) where k = avg string length | O(n · k) |
| Sorted-string key | O(n · k log k) | O(n · k) |

### Rust Notes

- `[u8; 26]` implements `Hash`, `Eq`, and `PartialEq` automatically — it can be used directly as a `HashMap` key. A `Vec<u8>` would also work but is heap-allocated.
- `map.into_values().collect()` consumes the map and collects only the values (the `Vec<String>` groups). `map.values()` would yield references.
- **Test order is nondeterministic.** HashMap iteration order is unspecified, and LeetCode accepts any order. The `normalized` helper sorts both inner groups and the outer group for stable comparison in tests. Without this, the test would be flaky.
- `or_insert_with(Vec::new)` is preferred over `or_insert(Vec::new())` when the default value is expensive to construct — the closure is only called when the key is absent. Here `Vec::new()` is cheap, but the pattern is worth learning.

---

## LC 347 — Top K Frequent Elements

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums` and an integer `k`, return the `k` most frequent elements. The answer can be returned in any order.

### Approach

**Bucket sort (O(n)):** After counting frequencies, bucket sort by frequency using an array of length `n + 1`. Index `i` holds all numbers that appear exactly `i` times. Scan from highest bucket to lowest, collecting elements until we have `k`. This is optimal — O(n) vs O(n log n) for a heap.

**Alternative (heap):** Use a `BinaryHeap` with `std::cmp::Reverse` for a min-heap. O(n log k) time, simpler code.

### Rust Solution

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    // O(n) bucket sort approach
    pub fn top_k_frequent(nums: Vec<i32>, k: i32) -> Vec<i32> {
        let n = nums.len();
        let mut freq_map: HashMap<i32, usize> = HashMap::new();
        for &num in &nums {
            *freq_map.entry(num).or_insert(0) += 1;
        }

        // buckets[i] = list of numbers with frequency i
        let mut buckets: Vec<Vec<i32>> = vec![vec![]; n + 1];
        for (&num, &freq) in &freq_map {
            buckets[freq].push(num);
        }

        let mut result = Vec::with_capacity(k as usize);
        // Scan from highest frequency down
        for freq in (1..=n).rev() {
            for &num in &buckets[freq] {
                result.push(num);
                if result.len() == k as usize {
                    return result;
                }
            }
        }

        result
    }

    // O(n log k) heap approach — simpler, good for large k
    pub fn top_k_frequent_heap(nums: Vec<i32>, k: i32) -> Vec<i32> {
        use std::cmp::Reverse;
        use std::collections::BinaryHeap;

        let mut freq_map: HashMap<i32, i32> = HashMap::new();
        for &num in &nums {
            *freq_map.entry(num).or_insert(0) += 1;
        }

        // Min-heap of (frequency, number) — Reverse makes BinaryHeap a min-heap
        let mut heap: BinaryHeap<Reverse<(i32, i32)>> = BinaryHeap::new();
        for (&num, &freq) in &freq_map {
            heap.push(Reverse((freq, num)));
            if heap.len() > k as usize {
                heap.pop(); // evict least frequent
            }
        }

        heap.into_iter().map(|Reverse((_, num))| num).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sorted(mut v: Vec<i32>) -> Vec<i32> {
        v.sort();
        v
    }

    #[test]
    fn test_basic() {
        let result = Solution::top_k_frequent(vec![1, 1, 1, 2, 2, 3], 2);
        assert_eq!(sorted(result), vec![1, 2]);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::top_k_frequent(vec![1], 1), vec![1]);
    }

    #[test]
    fn test_heap_basic() {
        let result = Solution::top_k_frequent_heap(vec![1, 1, 1, 2, 2, 3], 2);
        assert_eq!(sorted(result), vec![1, 2]);
    }

    #[test]
    fn test_heap_single() {
        let result = Solution::top_k_frequent_heap(vec![1], 1);
        assert_eq!(sorted(result), vec![1]);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Bucket sort | O(n) | O(n) |
| Heap (k size) | O(n log k) | O(n + k) |

### Rust Notes

- `k` is `i32` in the LeetCode signature. You need `k as usize` when using it as a collection length. This explicit cast is required — Rust never promotes `i32` to `usize` automatically.
- `BinaryHeap` is a **max-heap** by default. Wrap values in `std::cmp::Reverse` to get a min-heap. This is cleaner than implementing a custom `Ord`.
- **Test ordering is nondeterministic.** Sort both `result` and `expected` before comparing when the answer order is unspecified. The `sorted` helper does this.
- `*freq_map.entry(num).or_insert(0) += 1` — the leading `*` dereferences the `&mut V` returned by `or_insert`. Without it you'd get a type error: can't add `{integer}` to `&mut usize`.

---

## LC 238 — Product of Array Except Self

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an integer array `nums`, return an array `output` where `output[i]` is the product of all elements of `nums` except `nums[i]`. Solve in O(n) time without using division.

### Approach

Two-pass, O(1) extra space (the output array is not counted):
1. **Left pass:** `output[i]` = product of all elements to the **left** of `i`.
2. **Right pass:** Multiply `output[i]` by a running right product that accumulates from the right.

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn product_except_self(nums: Vec<i32>) -> Vec<i32> {
        let n = nums.len();
        let mut output = vec![1i32; n];

        // Left pass: output[i] holds product of nums[0..i]
        let mut prefix = 1i32;
        for i in 0..n {
            output[i] = prefix;
            prefix *= nums[i];
        }

        // Right pass: multiply in the suffix product from the right
        let mut suffix = 1i32;
        for i in (0..n).rev() {
            output[i] *= suffix;
            suffix *= nums[i];
        }

        output
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::product_except_self(vec![1, 2, 3, 4]),
            vec![24, 12, 8, 6]
        );
    }

    #[test]
    fn test_with_zero() {
        assert_eq!(
            Solution::product_except_self(vec![-1, 1, 0, -3, 3]),
            vec![0, 0, 9, 0, 0]
        );
    }

    #[test]
    fn test_two_elements() {
        assert_eq!(Solution::product_except_self(vec![3, 4]), vec![4, 3]);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Two-pass | O(n) | O(1) extra (output array doesn't count) |

### Rust Notes

- `vec![1i32; n]` creates a `Vec<i32>` of length `n` with all elements set to `1`. The type suffix `i32` on the literal disambiguates the element type.
- `(0..n).rev()` reverses a range. Java would use `for (int i = n - 1; i >= 0; i--)`. Rust ranges are more flexible — reverse with `.rev()` rather than rewriting the bounds.
- No borrowing issues here: `nums` is read-only (we have it as `Vec<i32>` by value), and `output` is the only mutable collection. This problem is a good introduction to Rust because there are no tricky ownership situations.

---

## LC 36 — Valid Sudoku

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Determine if a 9×9 Sudoku board is valid. A board is valid if: each row contains digits 1–9 with no repeats, each column contains digits 1–9 with no repeats, and each of the nine 3×3 sub-boxes contains digits 1–9 with no repeats. Cells may contain `'.'` for empty.

### Approach

Single pass over all 81 cells. Maintain three `[[bool; 9]; 9]` seen-arrays — one for rows, one for columns, one for 3×3 boxes. For cell `(r, c)` with digit `d`, check and set `rows[r][d]`, `cols[c][d]`, `boxes[box_idx][d]`. The box index is `(r / 3) * 3 + (c / 3)`.

### Rust Solution

```rust
struct Solution;

impl Solution {
    pub fn is_valid_sudoku(board: Vec<Vec<char>>) -> bool {
        let mut rows  = [[false; 9]; 9];
        let mut cols  = [[false; 9]; 9];
        let mut boxes = [[false; 9]; 9];

        for r in 0..9 {
            for c in 0..9 {
                let ch = board[r][c];
                if ch == '.' {
                    continue;
                }

                // '1' → 0, '2' → 1, ... '9' → 8
                let d = (ch as u8 - b'1') as usize;
                let box_idx = (r / 3) * 3 + (c / 3);

                if rows[r][d] || cols[c][d] || boxes[box_idx][d] {
                    return false;
                }

                rows[r][d]       = true;
                cols[c][d]       = true;
                boxes[box_idx][d] = true;
            }
        }

        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn board(rows: &[&str]) -> Vec<Vec<char>> {
        rows.iter().map(|r| r.chars().collect()).collect()
    }

    #[test]
    fn test_valid_board() {
        let b = board(&[
            "53..7....",
            "6..195...",
            ".98....6.",
            "8...6...3",
            "4..8.3..1",
            "7...2...6",
            ".6....28.",
            "...419..5",
            "....8..79",
        ]);
        assert_eq!(Solution::is_valid_sudoku(b), true);
    }

    #[test]
    fn test_invalid_row_duplicate() {
        let b = board(&[
            "83..7....",
            "6..195...",
            ".98....6.",
            "8...6...3",
            "4..8.3..1",
            "7...2...6",
            ".6....28.",
            "...419..5",
            "....8..79",
        ]);
        assert_eq!(Solution::is_valid_sudoku(b), false);
    }

    #[test]
    fn test_invalid_col_duplicate() {
        // Column 0 has two 8s
        let b = board(&[
            "8......1.",
            "8......1.",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
        ]);
        assert_eq!(Solution::is_valid_sudoku(b), false);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Single pass | O(1) — board is always 81 cells | O(1) — fixed-size arrays |

### Rust Notes

- `[[bool; 9]; 9]` is a fixed-size 2D array on the stack. Java would use `boolean[][]`. Rust initializes it with `[[false; 9]; 9]` — the inner `[false; 9]` is copied nine times.
- `ch as u8` converts a `char` to its ASCII byte value. Subtracting `b'1'` (the byte value of `'1'`) gives the 0-based digit index. This is cleaner than `ch.to_digit(10).unwrap() - 1`.
- The `board` helper in tests uses two chained `map` calls: the outer iterates over `&[&str]` rows, the inner calls `.chars().collect()` on each. This is idiomatic Rust for building nested collections.

---

## LC 271 — Encode and Decode Strings

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Design an algorithm to serialize a list of strings into a single string (encode), and then deserialize it back (decode). The strings may contain any characters including `'#'` and spaces.

### Approach

**Length-prefix encoding:** For each string, write `"{length}#{string}"`. The `#` is a delimiter between the length and the content. During decode, read the length, skip past `#`, then slice exactly that many bytes. This is unambiguous regardless of string content.

Example: `["foo","bar#baz"]` → `"3#foo7#bar#baz"`

### Rust Solution

```rust
struct Codec;

impl Codec {
    pub fn encode(strs: Vec<String>) -> String {
        let mut encoded = String::new();
        for s in &strs {
            encoded.push_str(&format!("{}#{}", s.len(), s));
        }
        encoded
    }

    pub fn decode(s: String) -> Vec<String> {
        let mut result = Vec::new();
        let bytes = s.as_bytes();
        let mut i = 0;

        while i < bytes.len() {
            // Find the '#' delimiter
            let mut j = i;
            while bytes[j] != b'#' {
                j += 1;
            }
            // Parse the length from bytes[i..j]
            let len: usize = std::str::from_utf8(&bytes[i..j])
                .unwrap()
                .parse()
                .unwrap();
            // Extract the string: bytes[j+1 .. j+1+len]
            let word = std::str::from_utf8(&bytes[j + 1..j + 1 + len])
                .unwrap()
                .to_string();
            result.push(word);
            i = j + 1 + len;
        }

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roundtrip_basic() {
        let input = vec!["lint".to_string(), "code".to_string(), "love".to_string(), "you".to_string()];
        let encoded = Codec::encode(input.clone());
        let decoded = Codec::decode(encoded);
        assert_eq!(decoded, input);
    }

    #[test]
    fn test_strings_with_hash() {
        let input = vec!["foo".to_string(), "bar#baz".to_string(), "#".to_string()];
        let encoded = Codec::encode(input.clone());
        let decoded = Codec::decode(encoded);
        assert_eq!(decoded, input);
    }

    #[test]
    fn test_empty_string_in_list() {
        let input = vec!["".to_string(), "hello".to_string(), "".to_string()];
        let encoded = Codec::encode(input.clone());
        let decoded = Codec::decode(encoded);
        assert_eq!(decoded, input);
    }

    #[test]
    fn test_empty_list() {
        let input: Vec<String> = vec![];
        let encoded = Codec::encode(input.clone());
        let decoded = Codec::decode(encoded);
        assert_eq!(decoded, input);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| Encode | O(n · k) — n strings of avg length k | O(n · k) |
| Decode | O(n · k) | O(n · k) |

### Rust Notes

- This problem uses `Codec` (not `Solution`) because it has two associated functions with no shared state.
- `s.as_bytes()` for byte-level scanning is idiomatic. Rust strings are valid UTF-8, but for ASCII-compatible protocols like this length-prefix scheme, byte manipulation is correct and fast.
- `std::str::from_utf8(&bytes[i..j])` re-interprets a byte slice as a `&str`. It returns `Result` because not all byte sequences are valid UTF-8 — `.unwrap()` is acceptable here since we're reconstructing strings we originally encoded.
- String slicing in Rust (`&s[i..j]`) panics on non-UTF-8 character boundaries. By working with `bytes` and using `from_utf8`, we avoid that trap entirely.
- `input.clone()` in tests is needed because `Codec::encode` takes `Vec<String>` by value (ownership), so `input` would be moved. Cloning preserves it for the final `assert_eq!`.

---

## LC 128 — Longest Consecutive Sequence

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an unsorted array of integers `nums`, return the length of the longest consecutive elements sequence (e.g., `[100, 4, 200, 1, 3, 2]` → `4`, from `[1, 2, 3, 4]`). Must run in O(n) time.

### Approach

Load all numbers into a `HashSet`. Iterate over each number `n`. Only start counting a sequence if `n - 1` is **not** in the set (meaning `n` is the start of a sequence). Then count upward: check `n+1`, `n+2`, etc. This ensures each sequence is counted exactly once — every element is visited at most twice across the entire algorithm.

### Rust Solution

```rust
use std::collections::HashSet;

struct Solution;

impl Solution {
    pub fn longest_consecutive(nums: Vec<i32>) -> i32 {
        let set: HashSet<i32> = nums.into_iter().collect();
        let mut best = 0i32;

        for &n in &set {
            // Only start a sequence at its beginning
            if set.contains(&(n - 1)) {
                continue;
            }

            let mut length = 1i32;
            while set.contains(&(n + length)) {
                length += 1;
            }
            best = best.max(length);
        }

        best
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        assert_eq!(Solution::longest_consecutive(vec![100, 4, 200, 1, 3, 2]), 4);
    }

    #[test]
    fn test_all_consecutive() {
        assert_eq!(Solution::longest_consecutive(vec![0, 3, 7, 2, 5, 8, 4, 6, 0, 1]), 9);
    }

    #[test]
    fn test_empty() {
        assert_eq!(Solution::longest_consecutive(vec![]), 0);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::longest_consecutive(vec![42]), 1);
    }

    #[test]
    fn test_duplicates() {
        assert_eq!(Solution::longest_consecutive(vec![1, 2, 2, 3]), 3);
    }
}

fn main() {}
```

### Complexity

| | Time | Space |
|-|------|-------|
| HashSet approach | O(n) | O(n) |

### Rust Notes

- `nums.into_iter().collect()` moves the `Vec` into a `HashSet`. After this line, `nums` is no longer usable — it has been consumed. This is an important ownership difference from Java.
- We iterate `for &n in &set` — iterating over `&set` yields `&i32` references. The `&n` pattern destructures the reference so `n` is `i32`. Without the `&`, `n` would be `&i32` and `n - 1` would require `*n - 1`.
- `set.contains(&(n - 1))` — the argument must be a reference: `&(n - 1)`. Parentheses are needed because `&n - 1` would be parsed differently.
- Return type is `i32` (not `usize`) to match the LeetCode signature. `best.max(length)` works because `i32` implements `Ord`.
- **Correctness with duplicates:** `HashSet` deduplicates automatically, so `[1, 2, 2, 3]` behaves identically to `[1, 2, 3]`. This is the right behavior — consecutive sequences are about values, not counts.

---

## Review Notes

### Correctness verification

**LC 217 (Contains Duplicate):** `HashSet::insert` returning `bool` is correct — it returns `true` on successful insert, `false` if the value was already present. Logic is correct.

**LC 242 (Valid Anagram):** Array approach is O(1) space, correct for lowercase ASCII. The `counts.iter().all(|&c| c == 0)` pattern is idiomatic and correct — `iter()` on `[i32; 26]` yields `&i32`, so `|&c|` destructures to `i32`.

**LC 1 (Two Sum):** Inserting *after* checking handles the case where the same index can't be used twice (`[3, 3], target=6` correctly returns `[0, 1]`).

**LC 49 (Group Anagrams):** The `[u8; 26]` key is a fixed-size array and implements `Hash` + `Eq` in Rust's standard library. Tests use a `normalized` helper to sort both levels before comparison — this is essential because `HashMap::into_values()` has no guaranteed order.

**LC 347 (Top K Frequent):** The bucket sort correctly handles `k as usize` conversion. The heap alternative correctly uses `std::cmp::Reverse` for a min-heap. Tests sort results before comparison. Edge case: when `k == nums.len()`, the bucket scan returns all elements, which is correct.

**LC 238 (Product Except Self):** The two-pass approach is well-known and correct. Left pass stores prefix products; right pass multiplies in suffix products using a scalar. Handles zeros correctly — verified by the `test_with_zero` case.

**LC 36 (Valid Sudoku):** Box index formula `(r / 3) * 3 + (c / 3)` gives 0–8 for the nine 3×3 boxes. Digit index `ch as u8 - b'1'` gives 0–8 for digits 1–9. Both are correct.

**LC 271 (Encode/Decode):** The length-prefix format `"{len}#{content}"` is unambiguous even when strings contain `#` or digits, because we always parse the exact number of bytes specified by `len`. All four edge cases are tested: empty list, empty strings, strings with `#`, and normal strings.

**LC 128 (Longest Consecutive):** The "only count from sequence starts" optimization ensures O(n) amortized complexity. The `n + length` probe is correct because `length` starts at `1` and increments — equivalent to checking `n+1, n+2, ...` in order.

### Rust-specific issues to watch for

1. **Entry API dereference.** `*map.entry(k).or_insert(0) += 1` — the `*` is mandatory. Beginners frequently omit it and get a confusing type error.
2. **`k as usize` casts.** LeetCode passes `k: i32`; all Rust collection lengths are `usize`. Always cast explicitly.
3. **HashMap iteration order.** Never `assert_eq!` a `HashMap`-derived collection against a literal without sorting first. This will cause intermittent CI failures.
4. **`into_iter()` vs `iter()`.** `into_iter()` consumes the collection (moves ownership). Use `iter()` if you need the collection afterward.
5. **`as_bytes()` for ASCII.** Indexing a `&str` with `s[i]` panics on multi-byte characters. Use `s.as_bytes()` for ASCII-only operations, or `s.chars()` for Unicode-aware iteration.
6. **`contains` takes a reference.** `set.contains(&x)`, `map.contains_key(&k)` — Rust collections take `&K`, not `K` by value.
7. **`unreachable!()` for guaranteed branches.** When the problem statement guarantees a solution exists, `unreachable!()` is cleaner than a dummy return value and signals intent clearly to the compiler and reader.

---

*Rust 2024 Edition · Rust 1.85+ · Chapter LC-01 · Arrays & Hashing*
