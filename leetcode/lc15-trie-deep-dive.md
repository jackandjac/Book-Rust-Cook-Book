# Chapter 15: Trie Deep Dive

> **Chapter goal:** Master every Trie / Prefix Tree pattern that appears in LeetCode interviews.
> Every snippet is complete and compiles on Rust 1.85+ (2024 edition). Target audience: Java developers
> who already know the algorithms and want the Rust idioms.

> **Already covered in Chapter 7 (lc07):** LC #208 (Implement Trie), LC #211 (Design Add and Search
> Words), and LC #212 (Word Search II) are covered in full in lc07-tries-graphs.md — including the
> core `[Option<Box<TrieNode>>; 26]` data structure and the `get_or_insert_with` insertion idiom.
> This chapter builds on that foundation and covers the broader Trie problem family.

**Java quick-reference**

| Java pattern | Rust equivalent |
|---|---|
| `Map<Character, TrieNode> children = new HashMap<>()` | `HashMap<char, Box<TrieNode>>` or `[Option<Box<TrieNode>>; 26]` |
| `children.computeIfAbsent(c, k -> new TrieNode())` | `node.children[idx].get_or_insert_with(\|\| Box::new(TrieNode::default()))` |
| `children.containsKey(c)` | `node.children[idx].is_some()` |
| `children.get(c)` (nullable) | `node.children[idx].as_ref()` → `Option<&Box<TrieNode>>` |
| `node.count++` | `node.count += 1` |
| `PriorityQueue` (min-heap) | `BinaryHeap<Reverse<T>>` |
| `Collections.reverseOrder()` | `BinaryHeap<T>` (max-heap by default) |

---

## Core Trie Structure (Reference)

Two canonical node shapes. Choose by alphabet size and sparsity:

```rust
// Shape A — array-indexed, cache-friendly, O(1) child lookup (for a-z only)
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    is_end: bool,
    // add extra fields (count, value, …) as needed
}

// Shape B — HashMap, handles non-ASCII or sparse alphabets cleanly
struct TrieNodeMap {
    children: std::collections::HashMap<char, Box<TrieNodeMap>>,
    is_end: bool,
}

// Binary Trie — for XOR / bit problems (Shape A with 2 branches)
#[derive(Default)]
struct BitNode {
    children: [Option<Box<BitNode>>; 2],
}
```

**Key insertion idiom** (avoids borrow-checker fights):
```rust
fn insert(root: &mut TrieNode, word: &str) {
    let mut node = root;
    for c in word.bytes() {
        let idx = (c - b'a') as usize;
        node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
    }
    node.is_end = true;
}
```

`get_or_insert_with` is the single most important idiom: it inserts a default child if absent and
returns a mutable reference in one step — no separate `if let None` check needed.

---

## Theme 1 — Prefix Basics

---

## LC 14. Longest Common Prefix

**Problem.** Given an array of strings, find the longest common prefix shared by all strings.
Return `""` if no common prefix exists.

**Key insight.** The LCP of all strings is bounded by the shortest string. Scan character by character
across all strings simultaneously; stop at the first mismatch.

```rust
struct Solution;

impl Solution {
    pub fn longest_common_prefix(strs: Vec<String>) -> String {
        if strs.is_empty() {
            return String::new();
        }
        let first = strs[0].as_bytes();
        let mut len = first.len();
        for s in strs.iter().skip(1) {
            let sb = s.as_bytes();
            // Shrink len to the common prefix length with this string
            len = len.min(sb.len());
            while len > 0 && first[len - 1] != sb[len - 1] {
                len -= 1;
            }
        }
        strs[0][..len].to_string()
    }
}

#[cfg(test)]
mod tests_lc14 {
    struct Solution;
    impl Solution {
        pub fn longest_common_prefix(strs: Vec<String>) -> String {
            if strs.is_empty() { return String::new(); }
            let first = strs[0].as_bytes();
            let mut len = first.len();
            for s in strs.iter().skip(1) {
                let sb = s.as_bytes();
                len = len.min(sb.len());
                while len > 0 && first[len - 1] != sb[len - 1] { len -= 1; }
            }
            strs[0][..len].to_string()
        }
    }
    #[test]
    fn test_flower() {
        assert_eq!(
            Solution::longest_common_prefix(vec!["flower".into(), "flow".into(), "flight".into()]),
            "fl"
        );
    }
    #[test]
    fn test_no_prefix() {
        assert_eq!(
            Solution::longest_common_prefix(vec!["dog".into(), "racecar".into(), "car".into()]),
            ""
        );
    }
    #[test]
    fn test_single() {
        assert_eq!(Solution::longest_common_prefix(vec!["alone".into()]), "alone");
    }
    #[test]
    fn test_empty_string_in_list() {
        assert_eq!(Solution::longest_common_prefix(vec!["ab".into(), "".into()]), "");
    }
}
```

**Complexity.** Time O(S) where S is the total characters across all strings, Space O(1).

> **Java note.** Java developers often reach for `String.startsWith` in a loop. The byte-slice shrink
> approach avoids repeated prefix extraction allocations. In Rust, `strs[0][..len]` is a zero-copy
> slice of the first string — `.to_string()` only copies when returning the result.

---

## LC 648. Replace Words

**Problem.** Given a dictionary of root words and a sentence, replace each word in the sentence with
the shortest root from the dictionary that is a prefix of it. If no root applies, keep the original word.

**Key insight.** Insert all roots into a Trie. For each sentence word, walk the Trie and stop at the
first `is_end` node encountered — that is the shortest matching root.

```rust
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    is_end: bool,
}

struct Solution;

impl Solution {
    pub fn replace_words(dictionary: Vec<String>, sentence: String) -> String {
        // Build Trie from dictionary roots
        let mut root = TrieNode::default();
        for word in &dictionary {
            let mut node = &mut root;
            for c in word.bytes() {
                let idx = (c - b'a') as usize;
                node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
            }
            node.is_end = true;
        }

        // Replace each word in the sentence
        sentence
            .split_whitespace()
            .map(|word| Self::find_root(&root, word).unwrap_or(word))
            .collect::<Vec<_>>()
            .join(" ")
    }

    fn find_root<'a>(root: &TrieNode, word: &'a str) -> Option<&'a str> {
        let mut node = root;
        for (i, c) in word.bytes().enumerate() {
            let idx = (c - b'a') as usize;
            match node.children[idx].as_ref() {
                None => return None,        // no root prefix exists
                Some(child) => {
                    node = child;
                    if node.is_end {
                        return Some(&word[..=i]); // shortest matching root
                    }
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod tests_lc648 {
    #[derive(Default)]
    struct TrieNode {
        children: [Option<Box<TrieNode>>; 26],
        is_end: bool,
    }
    struct Solution;
    impl Solution {
        pub fn replace_words(dictionary: Vec<String>, sentence: String) -> String {
            let mut root = TrieNode::default();
            for word in &dictionary {
                let mut node = &mut root;
                for c in word.bytes() {
                    let idx = (c - b'a') as usize;
                    node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
                }
                node.is_end = true;
            }
            sentence.split_whitespace()
                .map(|word| Self::find_root(&root, word).unwrap_or(word))
                .collect::<Vec<_>>().join(" ")
        }
        fn find_root<'a>(root: &TrieNode, word: &'a str) -> Option<&'a str> {
            let mut node = root;
            for (i, c) in word.bytes().enumerate() {
                let idx = (c - b'a') as usize;
                match node.children[idx].as_ref() {
                    None => return None,
                    Some(child) => {
                        node = child;
                        if node.is_end { return Some(&word[..=i]); }
                    }
                }
            }
            None
        }
    }
    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::replace_words(
                vec!["cat".into(), "bat".into(), "rat".into()],
                "the cattle was rattled by the battery".into()
            ),
            "the cat was rat by the bat"
        );
    }
    #[test]
    fn test_no_match() {
        assert_eq!(
            Solution::replace_words(vec!["a".into()], "a aa aaa".into()),
            "a a a"
        );
    }
}
```

**Complexity.** Time O(D + S) where D = total dictionary chars, S = total sentence chars. Space O(D).

---

## LC 677. Map Sum Pairs

**Problem.** Implement a `MapSum` structure that supports two operations: `insert(key, val)` sets the
value for `key`, and `sum(prefix)` returns the sum of all values whose keys start with `prefix`.

**Key insight.** Store the value at the terminal node of each key. To compute a prefix sum, walk to
the prefix node in the Trie, then DFS/sum all values beneath it. Alternatively, store a running
prefix count at every node along the insertion path.

```rust
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    val: i32,  // non-zero only at end nodes
}

struct MapSum {
    root: TrieNode,
    // Track previously inserted keys to handle re-insertions correctly
    map: std::collections::HashMap<String, i32>,
}

impl MapSum {
    fn new() -> Self {
        MapSum { root: TrieNode::default(), map: std::collections::HashMap::new() }
    }

    fn insert(&mut self, key: String, val: i32) {
        // delta handles the case where key was previously inserted with a different value
        let delta = val - self.map.get(&key).copied().unwrap_or(0);
        self.map.insert(key.clone(), val);
        let mut node = &mut self.root;
        for c in key.bytes() {
            let idx = (c - b'a') as usize;
            node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
            node.val += delta; // accumulate prefix sum at every node along the path
        }
    }

    fn sum(&self, prefix: String) -> i32 {
        let mut node = &self.root;
        for c in prefix.bytes() {
            let idx = (c - b'a') as usize;
            match node.children[idx].as_ref() {
                None => return 0,
                Some(child) => node = child,
            }
        }
        node.val
    }
}

#[cfg(test)]
mod tests_lc677 {
    use std::collections::HashMap;
    #[derive(Default)]
    struct TrieNode { children: [Option<Box<TrieNode>>; 26], val: i32 }
    struct MapSum { root: TrieNode, map: HashMap<String, i32> }
    impl MapSum {
        fn new() -> Self { MapSum { root: TrieNode::default(), map: HashMap::new() } }
        fn insert(&mut self, key: String, val: i32) {
            let delta = val - self.map.get(&key).copied().unwrap_or(0);
            self.map.insert(key.clone(), val);
            let mut node = &mut self.root;
            for c in key.bytes() {
                let idx = (c - b'a') as usize;
                node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
                node.val += delta;
            }
        }
        fn sum(&self, prefix: String) -> i32 {
            let mut node = &self.root;
            for c in prefix.bytes() {
                let idx = (c - b'a') as usize;
                match node.children[idx].as_ref() {
                    None => return 0,
                    Some(child) => node = child,
                }
            }
            node.val
        }
    }
    #[test]
    fn test_basic() {
        let mut ms = MapSum::new();
        ms.insert("apple".into(), 3);
        assert_eq!(ms.sum("ap".into()), 3);
        ms.insert("app".into(), 2);
        assert_eq!(ms.sum("ap".into()), 5);
    }
    #[test]
    fn test_overwrite() {
        let mut ms = MapSum::new();
        ms.insert("aa".into(), 3);
        assert_eq!(ms.sum("a".into()), 3);
        ms.insert("aa".into(), 2); // overwrite, not add
        assert_eq!(ms.sum("a".into()), 2);
    }
}
```

**Complexity.** Insert O(k), Sum O(k) where k = key/prefix length. Space O(total inserted chars).

> **Java note.** The `delta` trick is the core correctness point. Without it, re-inserting a key with
> a new value would double-count the prefix sums along its path. Java developers often store only the
> terminal value and do a DFS to compute sums — that is O(alphabet^depth) per query. This approach
> makes Sum O(k) at the cost of O(k) extra work per Insert.

---

## LC 720. Longest Word in Dictionary

**Problem.** Given an array of strings, find the longest word that can be built one character at a
time from other words in the array. If there is a tie, return the lexicographically smallest word.

**Key insight.** Insert all words into a Trie. A word is "buildable" if and only if every prefix of
that word also exists in the dictionary — i.e., every node along the word's path is an `is_end` node.
BFS level by level to find the deepest valid node.

```rust
use std::collections::VecDeque;

#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    is_end: bool,
    word: String,
}

struct Solution;

impl Solution {
    pub fn longest_word(words: Vec<String>) -> String {
        let mut root = TrieNode::default();
        // Insert all words
        for word in &words {
            let mut node = &mut root;
            for c in word.bytes() {
                let idx = (c - b'a') as usize;
                node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
            }
            node.is_end = true;
            node.word = word.clone();
        }

        // BFS: only follow edges where is_end is true at the target node
        // Start: root's children that are is_end (single-char words exist)
        let mut result = String::new();
        let mut queue: VecDeque<&TrieNode> = VecDeque::new();
        // Push root children that are valid endpoints
        for child in root.children.iter().flatten() {
            if child.is_end {
                queue.push_back(child);
            }
        }

        while let Some(node) = queue.pop_front() {
            // node.word is longer, or same length but lexicographically smaller
            if node.word.len() > result.len()
                || (node.word.len() == result.len() && node.word < result)
            {
                result = node.word.clone();
            }
            for child in node.children.iter().flatten() {
                if child.is_end {
                    queue.push_back(child);
                }
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_lc720 {
    use std::collections::VecDeque;
    #[derive(Default)]
    struct TrieNode { children: [Option<Box<TrieNode>>; 26], is_end: bool, word: String }
    struct Solution;
    impl Solution {
        pub fn longest_word(words: Vec<String>) -> String {
            let mut root = TrieNode::default();
            for word in &words {
                let mut node = &mut root;
                for c in word.bytes() {
                    let idx = (c - b'a') as usize;
                    node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
                }
                node.is_end = true;
                node.word = word.clone();
            }
            let mut result = String::new();
            let mut queue: VecDeque<&TrieNode> = VecDeque::new();
            for child in root.children.iter().flatten() {
                if child.is_end { queue.push_back(child); }
            }
            while let Some(node) = queue.pop_front() {
                if node.word.len() > result.len()
                    || (node.word.len() == result.len() && node.word < result)
                {
                    result = node.word.clone();
                }
                for child in node.children.iter().flatten() {
                    if child.is_end { queue.push_back(child); }
                }
            }
            result
        }
    }
    #[test]
    fn test_world() {
        let mut words: Vec<String> = vec!["w","wo","wor","worl","world"].iter().map(|s| s.to_string()).collect();
        // Also add some noise
        words.push("a".into()); words.push("b".into());
        assert_eq!(Solution::longest_word(words), "world");
    }
    #[test]
    fn test_tie_lex() {
        // "apple" and "app" both buildable — "apple" wins (longer)
        // between "aba" and "abc" (equal len) — "aba" wins (lex smaller)
        let words: Vec<String> = vec!["a","ab","abc","aba"].iter().map(|s| s.to_string()).collect();
        assert_eq!(Solution::longest_word(words), "aba");
    }
    #[test]
    fn test_no_buildable() {
        let words: Vec<String> = vec!["xyz"].iter().map(|s| s.to_string()).collect();
        // "xyz" not buildable because "x", "xy" are absent
        assert_eq!(Solution::longest_word(words), "");
    }
}
```

**Complexity.** Time O(W) where W = total characters across all words. Space O(W).

---

## LC 820. Short Encoding of Words

**Problem.** A reference string encodes words by concatenating them with `#` separators. Given a list
of words, find the minimum length of any encoding. The encoding is valid if every word appears as a
suffix ending at a `#`.

**Key insight.** A word needs its own `#` only if it is NOT a suffix of another word. Build a suffix
Trie (or equivalently, reverse all words and build a prefix Trie, then count leaf nodes' lengths).

```rust
struct Solution;

impl Solution {
    pub fn minimum_length_encoding(words: Vec<String>) -> i32 {
        use std::collections::HashSet;
        // Dedup first — duplicate words share the same encoding slot
        let word_set: HashSet<&str> = words.iter().map(|s| s.as_str()).collect();

        // A word contributes to the encoding only if none of its proper suffixes are also words.
        // Equivalently: for each word, try removing every proper suffix from the set.
        // Any word that remains in the set after all removals must be in the encoding.
        let mut unique: HashSet<&str> = word_set.clone();
        for word in &word_set {
            // Remove all proper suffixes of word from the unique set
            for i in 1..word.len() {
                unique.remove(&word[i..]);
            }
        }
        // Each surviving word contributes (len + 1) for the '#' terminator
        unique.iter().map(|w| w.len() as i32 + 1).sum()
    }
}

#[cfg(test)]
mod tests_lc820 {
    struct Solution;
    impl Solution {
        pub fn minimum_length_encoding(words: Vec<String>) -> i32 {
            use std::collections::HashSet;
            let word_set: HashSet<&str> = words.iter().map(|s| s.as_str()).collect();
            let mut unique: HashSet<&str> = word_set.clone();
            for word in &word_set {
                for i in 1..word.len() { unique.remove(&word[i..]); }
            }
            unique.iter().map(|w| w.len() as i32 + 1).sum()
        }
    }
    #[test]
    fn test_basic() {
        // "time#bell#" length 10; "time" and "bell" share no suffix relationship
        assert_eq!(Solution::minimum_length_encoding(vec!["time".into(), "me".into(), "bell".into()]), 10);
    }
    #[test]
    fn test_subset_suffix() {
        // "me" is a suffix of "time"; only "time" and "bell" needed → "time#bell#" = 10
        assert_eq!(Solution::minimum_length_encoding(vec!["time".into(), "me".into()]), 5);
    }
    #[test]
    fn test_single_word() {
        assert_eq!(Solution::minimum_length_encoding(vec!["abc".into()]), 4);
    }
    #[test]
    fn test_duplicates() {
        assert_eq!(Solution::minimum_length_encoding(vec!["me".into(), "me".into()]), 3);
    }
}
```

**Complexity.** Time O(W^2) for suffix removal (W = total chars), Space O(W).

> **Trie variant.** You can also reverse every word and insert into a Trie; leaf nodes represent words
> with no other word as a proper suffix. The HashSet approach above is simpler and idiomatic Rust.

---

## Theme 2 — Autocomplete & Ranking

---

## LC 1268. Search Suggestions System

**Problem.** Given a list of products and a search word, after each character typed, return the three
lexicographically smallest products that have the typed prefix. Return a list of lists.

**Key insight.** Sort products lexicographically. For each prefix, binary search to find the insertion
point, then take up to three consecutive products matching the prefix. The Trie approach works too but
sorting + binary search is simpler in Rust.

```rust
struct Solution;

impl Solution {
    pub fn suggested_products(mut products: Vec<String>, search_word: String) -> Vec<Vec<String>> {
        products.sort_unstable();
        let mut result = Vec::new();

        for i in 1..=search_word.len() {
            let prefix = &search_word[..i];
            // Find first product >= prefix using partition_point
            let start = products.partition_point(|p| p.as_str() < prefix);
            let mut suggestions = Vec::new();
            for j in start..products.len().min(start + 3) {
                if products[j].starts_with(prefix) {
                    suggestions.push(products[j].clone());
                } else {
                    break; // products are sorted; no further matches
                }
            }
            result.push(suggestions);
        }
        result
    }
}

#[cfg(test)]
mod tests_lc1268 {
    struct Solution;
    impl Solution {
        pub fn suggested_products(mut products: Vec<String>, search_word: String) -> Vec<Vec<String>> {
            products.sort_unstable();
            let mut result = Vec::new();
            for i in 1..=search_word.len() {
                let prefix = &search_word[..i];
                let start = products.partition_point(|p| p.as_str() < prefix);
                let mut suggestions = Vec::new();
                for j in start..products.len().min(start + 3) {
                    if products[j].starts_with(prefix) { suggestions.push(products[j].clone()); }
                    else { break; }
                }
                result.push(suggestions);
            }
            result
        }
    }
    #[test]
    fn test_basic() {
        let result = Solution::suggested_products(
            vec!["mobile".into(),"mouse".into(),"moneypot".into(),"monitor".into(),"mousepad".into()],
            "mouse".into()
        );
        assert_eq!(result[0], vec!["mobile","moneypot","monitor"]);
        assert_eq!(result[3], vec!["mouse","mousepad"]);
        assert_eq!(result[4], vec!["mouse","mousepad"]);
    }
    #[test]
    fn test_no_match() {
        let result = Solution::suggested_products(vec!["abc".into()], "xyz".into());
        assert!(result.iter().all(|v| v.is_empty()));
    }
}
```

**Complexity.** Time O(P log P + S * (log P + 3)) where P = products count, S = search_word length.

---

## LC 692. Top K Frequent Words

**Problem.** Given an array of strings and an integer `k`, return the `k` most frequent words sorted
by frequency (descending). Break ties lexicographically.

**Key insight.** Count frequencies with a HashMap. Collect all `(count, word)` pairs, sort by
descending frequency with lexicographic tie-breaking, and take the first `k`.

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn top_k_frequent(words: Vec<String>, k: i32) -> Vec<String> {
        let mut freq: HashMap<String, i32> = HashMap::new();
        for w in &words {
            *freq.entry(w.clone()).or_insert(0) += 1;
        }
        // Collect (count, word) pairs and sort: descending freq, then ascending lex for ties
        let mut entries: Vec<(i32, String)> = freq.into_iter().map(|(w, c)| (c, w)).collect();
        entries.sort_unstable_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
        entries.into_iter().take(k as usize).map(|(_, w)| w).collect()
    }
}

#[cfg(test)]
mod tests_lc692 {
    use std::collections::HashMap;

    struct Solution;
    impl Solution {
        pub fn top_k_frequent(words: Vec<String>, k: i32) -> Vec<String> {
            let mut freq: HashMap<String, i32> = HashMap::new();
            for w in &words { *freq.entry(w.clone()).or_insert(0) += 1; }
            let mut entries: Vec<(i32, String)> = freq.into_iter().map(|(w, c)| (c, w)).collect();
            entries.sort_unstable_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
            entries.into_iter().take(k as usize).map(|(_, w)| w).collect()
        }
    }

    #[test]
    fn test_basic() {
        let result = Solution::top_k_frequent(
            vec!["i","love","leetcode","i","love","coding"].iter().map(|s| s.to_string()).collect(),
            2
        );
        assert_eq!(result, vec!["i", "love"]);
    }
    #[test]
    fn test_tie_lex() {
        let result = Solution::top_k_frequent(
            vec!["the","day","is","sunny","the","the","the","sunny","is","is"].iter().map(|s| s.to_string()).collect(),
            4
        );
        assert_eq!(result, vec!["the", "is", "sunny", "day"]);
    }
}
```

**Complexity.** Time O(N log N) where N = unique words. Space O(N).

> **Java note.** Java developers use `PriorityQueue` with a custom `Comparator`. Rust's `BinaryHeap`
> is a max-heap by default; wrap values in `Reverse<T>` to simulate a min-heap. The cleaner approach
> in the test module uses a full sort — idiomatic for small output sizes.

---

## Theme 3 — DP + Trie

---

## LC 139. Word Break

**Problem.** Given a string `s` and a dictionary `wordDict`, return `true` if `s` can be segmented
into a space-separated sequence of one or more dictionary words.

**Key insight.** DP: `dp[i]` = true if `s[0..i]` can be segmented. For each position `i`, try all
dictionary words ending at `i`. A Trie is a natural fit to enumerate possible word ends efficiently,
but a HashSet works cleanly for this problem.

```rust
use std::collections::HashSet;

struct Solution;

impl Solution {
    pub fn word_break(s: String, word_dict: Vec<String>) -> bool {
        let dict: HashSet<&str> = word_dict.iter().map(|w| w.as_str()).collect();
        let max_len = word_dict.iter().map(|w| w.len()).max().unwrap_or(0);
        let n = s.len();
        let sb = s.as_bytes();
        let mut dp = vec![false; n + 1];
        dp[0] = true; // empty prefix is always valid

        for i in 1..=n {
            // Only try starting positions j where dp[j] is true
            for j in i.saturating_sub(max_len)..i {
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
mod tests_lc139 {
    use std::collections::HashSet;
    struct Solution;
    impl Solution {
        pub fn word_break(s: String, word_dict: Vec<String>) -> bool {
            let dict: HashSet<&str> = word_dict.iter().map(|w| w.as_str()).collect();
            let max_len = word_dict.iter().map(|w| w.len()).max().unwrap_or(0);
            let n = s.len();
            let mut dp = vec![false; n + 1];
            dp[0] = true;
            for i in 1..=n {
                for j in i.saturating_sub(max_len)..i {
                    if dp[j] && dict.contains(&s[j..i]) { dp[i] = true; break; }
                }
            }
            dp[n]
        }
    }
    #[test]
    fn test_leetcode() {
        assert!(Solution::word_break("leetcode".into(), vec!["leet".into(), "code".into()]));
    }
    #[test]
    fn test_applepenapple() {
        assert!(Solution::word_break(
            "applepenapple".into(),
            vec!["apple".into(), "pen".into()]
        ));
    }
    #[test]
    fn test_catsandog() {
        assert!(!Solution::word_break(
            "catsandog".into(),
            vec!["cats".into(), "dog".into(), "sand".into(), "and".into(), "cat".into()]
        ));
    }
}
```

**Complexity.** Time O(n * max_word_len), Space O(n).

---

## LC 140. Word Break II

**Problem.** Same as LC 139, but return all possible segmentations as sentences.

**Key insight.** Backtracking with memoization. Memoize by start index: for each position, store all
possible sentence suffixes. Build results bottom-up or top-down with `HashMap<usize, Vec<String>>`.

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn word_break(s: String, word_dict: Vec<String>) -> Vec<String> {
        use std::collections::HashSet;
        let dict: HashSet<&str> = word_dict.iter().map(|s| s.as_str()).collect();
        let mut memo: HashMap<usize, Vec<String>> = HashMap::new();
        Self::backtrack(s.as_bytes(), 0, &dict, &mut memo);
        memo.remove(&0).unwrap_or_default()
    }

    fn backtrack<'a>(
        s: &[u8],
        start: usize,
        dict: &std::collections::HashSet<&str>,
        memo: &'a mut HashMap<usize, Vec<String>>,
    ) -> &'a Vec<String> {
        if memo.contains_key(&start) {
            return memo.get(&start).unwrap();
        }
        let mut results = Vec::new();
        if start == s.len() {
            results.push(String::new()); // base: empty suffix
        } else {
            for end in start + 1..=s.len() {
                let word = std::str::from_utf8(&s[start..end]).unwrap();
                if dict.contains(word) {
                    // recurse — must not hold borrow into memo while recursing
                    Self::backtrack(s, end, dict, memo);
                    let suffixes = memo.get(&end).unwrap().clone();
                    for suffix in suffixes {
                        if suffix.is_empty() {
                            results.push(word.to_string());
                        } else {
                            results.push(format!("{} {}", word, suffix));
                        }
                    }
                }
            }
        }
        memo.insert(start, results);
        memo.get(&start).unwrap()
    }
}

#[cfg(test)]
mod tests_lc140 {
    use std::collections::HashMap;
    struct Solution;
    impl Solution {
        pub fn word_break(s: String, word_dict: Vec<String>) -> Vec<String> {
            use std::collections::HashSet;
            let dict: HashSet<&str> = word_dict.iter().map(|s| s.as_str()).collect();
            let mut memo: HashMap<usize, Vec<String>> = HashMap::new();
            Self::bt(s.as_bytes(), 0, &dict, &mut memo);
            memo.remove(&0).unwrap_or_default()
        }
        fn bt<'a>(s: &[u8], start: usize, dict: &std::collections::HashSet<&str>,
            memo: &'a mut HashMap<usize, Vec<String>>) -> &'a Vec<String> {
            if memo.contains_key(&start) { return memo.get(&start).unwrap(); }
            let mut results = Vec::new();
            if start == s.len() { results.push(String::new()); }
            else {
                for end in start + 1..=s.len() {
                    let word = std::str::from_utf8(&s[start..end]).unwrap();
                    if dict.contains(word) {
                        Self::bt(s, end, dict, memo);
                        let suffixes = memo.get(&end).unwrap().clone();
                        for suf in suffixes {
                            results.push(if suf.is_empty() { word.to_string() }
                                         else { format!("{} {}", word, suf) });
                        }
                    }
                }
            }
            memo.insert(start, results);
            memo.get(&start).unwrap()
        }
    }
    #[test]
    fn test_catsanddog() {
        let mut result = Solution::word_break(
            "catsanddog".into(),
            vec!["cat".into(), "cats".into(), "and".into(), "sand".into(), "dog".into()]
        );
        result.sort();
        assert_eq!(result, vec!["cat sand dog", "cats and dog"]);
    }
    #[test]
    fn test_pineapple() {
        let mut result = Solution::word_break(
            "pineapplepenapple".into(),
            vec!["apple".into(), "pen".into(), "applepen".into(), "pine".into(), "pineapple".into()]
        );
        result.sort();
        let mut expected = vec!["pine apple pen apple", "pineapple pen apple", "pine applepen apple"];
        expected.sort();
        assert_eq!(result, expected);
    }
}
```

**Complexity.** Time O(n^2 * 2^n) worst case (exponential output), Space O(n * 2^n).

> **Rust borrow-checker note.** The recursion clones the `suffixes` vec before mutating `memo` with
> `insert`. This is intentional: holding an immutable borrow into `memo` while also calling
> `memo.insert` (which takes `&mut memo`) is a compile error. The `clone()` breaks the borrow.
> Java developers can simply call the recursive method and read the returned list — Rust's ownership
> rules require explicit cloning here.

---

## LC 472. Concatenated Words

**Problem.** Given a list of words, find all words that can be formed by concatenating at least two
shorter words in the list.

**Key insight.** Word Break (LC 139) applied to each word, using the remaining words as the dictionary.
Sort by length so shorter words are available when processing longer ones.

```rust
use std::collections::HashSet;

struct Solution;

impl Solution {
    pub fn find_all_concatenated_words_in_a_dict(words: Vec<String>) -> Vec<String> {
        let dict: HashSet<&str> = words.iter().map(|s| s.as_str()).collect();
        let mut result = Vec::new();

        for word in &words {
            if word.is_empty() {
                continue;
            }
            // Word break: can word be formed by >= 2 parts each in dict (excluding word itself)?
            if Self::can_form(word.as_bytes(), &dict, 0, 0, word.as_str()) {
                result.push(word.clone());
            }
        }
        result
    }

    fn can_form(s: &[u8], dict: &HashSet<&str>, start: usize, count: usize, original: &str) -> bool {
        if start == s.len() {
            return count >= 2; // must use at least 2 words
        }
        for end in start + 1..=s.len() {
            let piece = std::str::from_utf8(&s[start..end]).unwrap();
            // Don't let the word use itself as a component
            if piece != original && dict.contains(piece) {
                if Self::can_form(s, dict, end, count + 1, original) {
                    return true;
                }
            }
        }
        false
    }
}

#[cfg(test)]
mod tests_lc472 {
    use std::collections::HashSet;
    struct Solution;
    impl Solution {
        pub fn find_all_concatenated_words_in_a_dict(words: Vec<String>) -> Vec<String> {
            let dict: HashSet<&str> = words.iter().map(|s| s.as_str()).collect();
            let mut result = Vec::new();
            for word in &words {
                if word.is_empty() { continue; }
                if Self::can_form(word.as_bytes(), &dict, 0, 0, word.as_str()) {
                    result.push(word.clone());
                }
            }
            result
        }
        fn can_form(s: &[u8], dict: &HashSet<&str>, start: usize, count: usize, orig: &str) -> bool {
            if start == s.len() { return count >= 2; }
            for end in start + 1..=s.len() {
                let piece = std::str::from_utf8(&s[start..end]).unwrap();
                if piece != orig && dict.contains(piece) {
                    if Self::can_form(s, dict, end, count + 1, orig) { return true; }
                }
            }
            false
        }
    }
    #[test]
    fn test_basic() {
        let mut result = Solution::find_all_concatenated_words_in_a_dict(
            vec!["cat".into(),"cats".into(),"catsdogcats".into(),"dog".into(),"dogcatsdog".into(),"hippopotamuses".into(),"rat".into(),"ratcatdogcat".into()]
        );
        result.sort();
        assert_eq!(result, vec!["catsdogcats","dogcatsdog","ratcatdogcat"]);
    }
    #[test]
    fn test_empty_and_short() {
        let result = Solution::find_all_concatenated_words_in_a_dict(
            vec!["".into(), "a".into(), "b".into(), "ab".into()]
        );
        assert!(result.contains(&"ab".to_string()));
    }
}
```

**Complexity.** Time O(W * N * L) where W = word count, N = max word length, L = dict lookup. Space O(W * L).

---

## Theme 4 — Advanced Trie Structures

---

## LC 421. Maximum XOR of Two Numbers in an Array

**Problem.** Given an integer array `nums`, return the maximum XOR of any two elements.

**Key insight.** Insert all numbers into a binary Trie (bit by bit from MSB to LSB). For each number,
greedily traverse the opposite bit at each level to maximize XOR.

```rust
#[derive(Default)]
struct BitNode {
    children: [Option<Box<BitNode>>; 2],
}

struct Solution;

impl Solution {
    pub fn find_maximum_xor(nums: Vec<i32>) -> i32 {
        let mut root = BitNode::default();

        // Insert all numbers into binary trie (bits 31 down to 0)
        for &n in &nums {
            let mut node = &mut root;
            for bit in (0..32).rev() {
                let b = ((n >> bit) & 1) as usize;
                node = node.children[b].get_or_insert_with(|| Box::new(BitNode::default()));
            }
        }

        // For each number, find its best XOR partner
        let mut max_xor = 0;
        for &n in &nums {
            let mut node = &root;
            let mut cur_xor = 0;
            for bit in (0..32).rev() {
                let b = ((n >> bit) & 1) as usize;
                let want = 1 - b; // we want the opposite bit to maximize XOR
                if node.children[want].is_some() {
                    cur_xor |= 1 << bit;
                    node = node.children[want].as_ref().unwrap();
                } else {
                    node = node.children[b].as_ref().unwrap();
                }
            }
            max_xor = max_xor.max(cur_xor);
        }
        max_xor
    }
}

#[cfg(test)]
mod tests_lc421 {
    #[derive(Default)]
    struct BitNode { children: [Option<Box<BitNode>>; 2] }
    struct Solution;
    impl Solution {
        pub fn find_maximum_xor(nums: Vec<i32>) -> i32 {
            let mut root = BitNode::default();
            for &n in &nums {
                let mut node = &mut root;
                for bit in (0..32).rev() {
                    let b = ((n >> bit) & 1) as usize;
                    node = node.children[b].get_or_insert_with(|| Box::new(BitNode::default()));
                }
            }
            let mut max_xor = 0;
            for &n in &nums {
                let mut node = &root;
                let mut cur_xor = 0;
                for bit in (0..32).rev() {
                    let b = ((n >> bit) & 1) as usize;
                    let want = 1 - b;
                    if node.children[want].is_some() {
                        cur_xor |= 1 << bit;
                        node = node.children[want].as_ref().unwrap();
                    } else {
                        node = node.children[b].as_ref().unwrap();
                    }
                }
                max_xor = max_xor.max(cur_xor);
            }
            max_xor
        }
    }
    #[test]
    fn test_basic() {
        assert_eq!(Solution::find_maximum_xor(vec![3, 10, 5, 25, 2, 8]), 28);
    }
    #[test]
    fn test_two_elements() {
        assert_eq!(Solution::find_maximum_xor(vec![0, 1]), 1);
    }
    #[test]
    fn test_all_same() {
        assert_eq!(Solution::find_maximum_xor(vec![7, 7, 7]), 0);
    }
    #[test]
    fn test_large() {
        assert_eq!(Solution::find_maximum_xor(vec![14, 70, 53, 83, 49, 91, 36, 80, 92, 51, 66, 70]), 127);
    }
}
```

**Complexity.** Time O(N * 32) = O(N), Space O(N * 32) = O(N).

> **Java note.** Java developers implement this identically with a two-child array node. The Rust
> version uses the same `get_or_insert_with` insertion idiom as a regular Trie. The key difference
> is that you always have exactly 2 children, and you greedily pick the opposite bit.

---

## LC 676. Implement Magic Dictionary

**Problem.** Build a dictionary. Support `search(word)` that returns `true` if the word, with exactly
one character replaced, matches any word in the dictionary.

**Key insight.** For each position in the query word, try all 26 possible replacement characters and
check if the resulting word is in the dictionary. Use a HashSet for O(L) lookup per attempt.

```rust
use std::collections::HashSet;

struct MagicDictionary {
    words: HashSet<String>,
}

impl MagicDictionary {
    fn new() -> Self {
        MagicDictionary { words: HashSet::new() }
    }

    fn build_dict(&mut self, dictionary: Vec<String>) {
        self.words = dictionary.into_iter().collect();
    }

    fn search(&self, search_word: String) -> bool {
        let mut chars: Vec<u8> = search_word.into_bytes();
        let n = chars.len();
        for i in 0..n {
            let original = chars[i];
            for c in b'a'..=b'z' {
                if c == original {
                    continue;
                }
                chars[i] = c;
                let candidate = std::str::from_utf8(&chars).unwrap();
                if self.words.contains(candidate) {
                    return true;
                }
            }
            chars[i] = original; // restore
        }
        false
    }
}

#[cfg(test)]
mod tests_lc676 {
    use std::collections::HashSet;
    struct MagicDictionary { words: HashSet<String> }
    impl MagicDictionary {
        fn new() -> Self { MagicDictionary { words: HashSet::new() } }
        fn build_dict(&mut self, dictionary: Vec<String>) { self.words = dictionary.into_iter().collect(); }
        fn search(&self, search_word: String) -> bool {
            let mut chars: Vec<u8> = search_word.into_bytes();
            let n = chars.len();
            for i in 0..n {
                let orig = chars[i];
                for c in b'a'..=b'z' {
                    if c == orig { continue; }
                    chars[i] = c;
                    if self.words.contains(std::str::from_utf8(&chars).unwrap()) { return true; }
                }
                chars[i] = orig;
            }
            false
        }
    }
    #[test]
    fn test_basic() {
        let mut md = MagicDictionary::new();
        md.build_dict(vec!["hello".into(), "leetcode".into()]);
        assert!(!md.search("hello".into())); // exact match not counted (0 replacements)
        assert!(md.search("hhllo".into()));  // h→e at pos 1 → "hello"
        assert!(!md.search("ball".into()));
        assert!(md.search("leetcede".into())); // one replacement
    }
}
```

**Complexity.** Build O(W), Search O(L * 26) = O(L) where L = word length.

---

## LC 2416. Sum of Prefix Scores of Strings

**Problem.** Given a string array `words`, for each word `words[i]`, compute the sum of scores of
all prefixes. The score of a prefix is the count of words that start with that prefix.

**Key insight.** Insert all words into a Trie, incrementing a counter at each node along the path.
For each word, sum the counters along its path.

```rust
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    count: i32,  // number of words passing through this node
}

struct Solution;

impl Solution {
    pub fn sum_prefix_scores(words: Vec<String>) -> Vec<i32> {
        let mut root = TrieNode::default();

        // Build trie with pass-through counts
        for word in &words {
            let mut node = &mut root;
            for c in word.bytes() {
                let idx = (c - b'a') as usize;
                node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
                node.count += 1;
            }
        }

        // For each word, walk the trie and sum counts
        words.iter().map(|word| {
            let mut node = &root;
            let mut score = 0;
            for c in word.bytes() {
                let idx = (c - b'a') as usize;
                node = node.children[idx].as_ref().unwrap();
                score += node.count;
            }
            score
        }).collect()
    }
}

#[cfg(test)]
mod tests_lc2416 {
    #[derive(Default)]
    struct TrieNode { children: [Option<Box<TrieNode>>; 26], count: i32 }
    struct Solution;
    impl Solution {
        pub fn sum_prefix_scores(words: Vec<String>) -> Vec<i32> {
            let mut root = TrieNode::default();
            for word in &words {
                let mut node = &mut root;
                for c in word.bytes() {
                    let idx = (c - b'a') as usize;
                    node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
                    node.count += 1;
                }
            }
            words.iter().map(|word| {
                let mut node = &root;
                let mut score = 0;
                for c in word.bytes() {
                    let idx = (c - b'a') as usize;
                    node = node.children[idx].as_ref().unwrap();
                    score += node.count;
                }
                score
            }).collect()
        }
    }
    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::sum_prefix_scores(vec!["abc".into(), "ab".into(), "bc".into(), "b".into()]),
            vec![5, 4, 3, 2]
        );
    }
    #[test]
    fn test_single() {
        assert_eq!(Solution::sum_prefix_scores(vec!["alone".into()]), vec![5]);
    }
    #[test]
    fn test_all_same_prefix() {
        // "a", "ab", "abc": prefix "a" passes 3, "ab" passes 2, "abc" passes 1
        assert_eq!(
            Solution::sum_prefix_scores(vec!["a".into(), "ab".into(), "abc".into()]),
            vec![3, 5, 6]
        );
    }
}
```

**Complexity.** Time O(W * L), Space O(W * L) where W = word count, L = average word length.

---

## Theme 5 — Lexicographic Order (Digit Trie)

---

## LC 386. Lexicographical Numbers

**Problem.** Given an integer `n`, return all integers in `[1, n]` in lexicographical order.

**Key insight.** Imagine a 10-ary Trie where each digit 1-9 starts a root. A DFS over this
conceptual trie (without building it explicitly) visits numbers in lexicographic order.

```rust
struct Solution;

impl Solution {
    pub fn lexical_order(n: i32) -> Vec<i32> {
        let mut result = Vec::with_capacity(n as usize);
        let mut cur = 1_i32;
        while result.len() < n as usize {
            result.push(cur);
            if cur * 10 <= n {
                cur *= 10; // go deeper in the digit trie
            } else {
                // Can't go deeper; go to next sibling or backtrack
                while cur % 10 == 9 || cur + 1 > n {
                    cur /= 10; // backtrack to parent
                }
                cur += 1; // next sibling
            }
        }
        result
    }
}

#[cfg(test)]
mod tests_lc386 {
    struct Solution;
    impl Solution {
        pub fn lexical_order(n: i32) -> Vec<i32> {
            let mut result = Vec::with_capacity(n as usize);
            let mut cur = 1_i32;
            while result.len() < n as usize {
                result.push(cur);
                if cur * 10 <= n { cur *= 10; }
                else {
                    while cur % 10 == 9 || cur + 1 > n { cur /= 10; }
                    cur += 1;
                }
            }
            result
        }
    }
    #[test]
    fn test_n13() {
        assert_eq!(Solution::lexical_order(13),
            vec![1,10,11,12,13,2,3,4,5,6,7,8,9]);
    }
    #[test]
    fn test_n2() {
        assert_eq!(Solution::lexical_order(2), vec![1, 2]);
    }
    #[test]
    fn test_n1() {
        assert_eq!(Solution::lexical_order(1), vec![1]);
    }
}
```

**Complexity.** Time O(N), Space O(1) auxiliary (output excluded).

---

## LC 440. K-th Smallest in Lexicographical Order

**Problem.** Given integers `n` and `k`, find the `k`-th smallest integer in `[1, n]` in
lexicographical order.

**Key insight.** Count how many numbers are in the subtree rooted at `cur` (i.e., have `cur` as a
prefix). If the subtree has >= k numbers, descend into it (go to `cur * 10`). Otherwise, skip the
entire subtree and move to the next sibling (`cur + 1`).

```rust
struct Solution;

impl Solution {
    pub fn find_kth_number(n: i32, k: i32) -> i32 {
        let n = n as i64;
        let mut cur = 1_i64;
        let mut k = k as i64 - 1; // we've already "used" cur=1

        while k > 0 {
            let steps = Self::count_steps(n, cur, cur + 1);
            if steps <= k {
                k -= steps;
                cur += 1; // skip this subtree entirely
            } else {
                k -= 1;
                cur *= 10; // descend into the subtree
            }
        }
        cur as i32
    }

    // Count numbers in [1, n] whose lexicographic representation starts with `cur`
    // (i.e., numbers in the subtree [cur, next) at all depths)
    fn count_steps(n: i64, cur: i64, next: i64) -> i64 {
        let mut steps = 0_i64;
        let mut cur = cur;
        let mut next = next;
        while cur <= n {
            steps += next.min(n + 1) - cur;
            cur *= 10;
            next *= 10;
        }
        steps
    }
}

#[cfg(test)]
mod tests_lc440 {
    struct Solution;
    impl Solution {
        pub fn find_kth_number(n: i32, k: i32) -> i32 {
            let n = n as i64;
            let mut cur = 1_i64;
            let mut k = k as i64 - 1;
            while k > 0 {
                let steps = Self::count_steps(n, cur, cur + 1);
                if steps <= k { k -= steps; cur += 1; }
                else { k -= 1; cur *= 10; }
            }
            cur as i32
        }
        fn count_steps(n: i64, cur: i64, next: i64) -> i64 {
            let mut steps = 0_i64;
            let (mut c, mut nx) = (cur, next);
            while c <= n { steps += nx.min(n + 1) - c; c *= 10; nx *= 10; }
            steps
        }
    }
    #[test]
    fn test_n13_k2() {
        // Lex order: 1,10,11,12,13,2,3,4,5,6,7,8,9 → 2nd = 10
        assert_eq!(Solution::find_kth_number(13, 2), 10);
    }
    #[test]
    fn test_n1_k1() {
        assert_eq!(Solution::find_kth_number(1, 1), 1);
    }
    #[test]
    fn test_n100_k10() {
        assert_eq!(Solution::find_kth_number(100, 10), 17);
    }
}
```

**Complexity.** Time O(log^2 N), Space O(1).

---

## Theme 6 — Hard Trie Problems

---

## LC 1032. Stream of Characters

**Problem.** Given a list of query strings (a dictionary), implement a `StreamChecker` that reads
characters one at a time. After each character, return `true` if the suffix of all characters read
so far ends with any word in the dictionary.

**Key insight.** Insert reversed words into a Trie. Maintain a buffer of recent characters. After
each character, check if any suffix of the buffer (read backwards from the current character)
matches a Trie path ending at an `is_end` node. Maintain a set of "active" Trie nodes to avoid
re-scanning the full buffer each time.

```rust
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    is_end: bool,
}

struct StreamChecker {
    root: TrieNode,
    // Active nodes: Trie nodes we're currently tracking (one per ongoing suffix match attempt)
    active: Vec<*const TrieNode>,
}

impl StreamChecker {
    fn new(words: Vec<String>) -> Self {
        let mut root = TrieNode::default();
        // Insert each word reversed
        for word in &words {
            let mut node = &mut root;
            for c in word.bytes().rev() {
                let idx = (c - b'a') as usize;
                node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
            }
            node.is_end = true;
        }
        StreamChecker { root, active: Vec::new() }
    }

    fn query(&mut self, letter: char) -> bool {
        let idx = (letter as u8 - b'a') as usize;
        let root_ptr: *const TrieNode = &self.root;
        let mut next_active = Vec::new();
        let mut found = false;

        // Always start a new match attempt from the root for this character
        // (root represents the empty suffix; we advance it by one character below)
        let candidates: std::iter::Chain<std::iter::Once<*const TrieNode>, std::vec::IntoIter<*const TrieNode>> =
            std::iter::once(root_ptr).chain(self.active.drain(..));

        for node_ptr in candidates {
            let node = unsafe { &*node_ptr };
            if let Some(child) = node.children[idx].as_ref() {
                if child.is_end {
                    found = true;
                }
                next_active.push(child.as_ref() as *const TrieNode);
            }
        }
        self.active = next_active;
        found
    }
}

#[cfg(test)]
mod tests_lc1032 {
    #[derive(Default)]
    struct TrieNode { children: [Option<Box<TrieNode>>; 26], is_end: bool }
    struct StreamChecker { root: TrieNode, active: Vec<*const TrieNode> }
    impl StreamChecker {
        fn new(words: Vec<String>) -> Self {
            let mut root = TrieNode::default();
            for word in &words {
                let mut node = &mut root;
                for c in word.bytes().rev() {
                    let idx = (c - b'a') as usize;
                    node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
                }
                node.is_end = true;
            }
            StreamChecker { root, active: Vec::new() }
        }
        fn query(&mut self, letter: char) -> bool {
            let idx = (letter as u8 - b'a') as usize;
            let root_ptr: *const TrieNode = &self.root;
            let mut next_active = Vec::new();
            let mut found = false;
            let prev = std::mem::take(&mut self.active);
            for node_ptr in std::iter::once(root_ptr).chain(prev.into_iter()) {
                let node = unsafe { &*node_ptr };
                if let Some(child) = node.children[idx].as_ref() {
                    if child.is_end { found = true; }
                    next_active.push(child.as_ref() as *const TrieNode);
                }
            }
            self.active = next_active;
            found
        }
    }
    #[test]
    fn test_basic() {
        let mut sc = StreamChecker::new(vec!["cd".into(), "f".into(), "kl".into()]);
        // Stream: a b c d e f k l
        assert!(!sc.query('a'));
        assert!(!sc.query('b'));
        assert!(!sc.query('c'));
        assert!(sc.query('d'));  // "cd" matches
        assert!(!sc.query('e'));
        assert!(sc.query('f'));  // "f" matches
        assert!(!sc.query('k'));
        assert!(sc.query('l'));  // "kl" matches
    }
}
```

**Complexity.** Build O(W * L). Query amortized O(|active| + alphabet) per call where |active| <= total dictionary chars.

> **Rust unsafe note.** The raw pointer `*const TrieNode` is used to store references into the Trie
> without fighting the borrow checker's aliasing rules. The safety contract: the Trie lives for the
> lifetime of `StreamChecker` and is never mutated after construction. In production Rust, you would
> use arena allocation (e.g., the `typed-arena` crate) to avoid `unsafe`. For LeetCode, this pattern
> is acceptable.

---

## LC 336. Palindrome Pairs

**Problem.** Given a list of unique words, find all pairs `[i, j]` such that `words[i] + words[j]`
is a palindrome.

**Key insight.** For each word W, we need a complement C such that `W + C` is a palindrome.
The HashMap approach is cleaner than a Trie in Rust for this problem. For each word W:
- For each prefix split `W = W[0..k] + W[k..]`: if `W[0..k]` is a palindrome, check if `reverse(W[k..])` exists in the dictionary.
- For each suffix split `W = W[0..k] + W[k..]`: if `W[k..]` is a palindrome, check if `reverse(W[0..k])` exists.

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn palindrome_pairs(words: Vec<String>) -> Vec<Vec<i32>> {
        let word_map: HashMap<&str, i32> = words.iter().enumerate().map(|(i, w)| (w.as_str(), i as i32)).collect();
        let mut result = Vec::new();

        for (i, word) in words.iter().enumerate() {
            let n = word.len();
            let wb = word.as_bytes();

            for k in 0..=n {
                // Case 1: prefix is palindrome → look for reverse(suffix) before word[i]
                if Self::is_palindrome(wb, 0, k.saturating_sub(1)) {
                    let rev_suffix: String = wb[k..].iter().rev().map(|&c| c as char).collect();
                    if let Some(&j) = word_map.get(rev_suffix.as_str()) {
                        if j != i as i32 {
                            result.push(vec![j, i as i32]);
                        }
                    }
                }
                // Case 2: suffix is palindrome → look for reverse(prefix) after word[i]
                // Avoid double-counting the k==n case which is covered above
                if k < n && Self::is_palindrome(wb, k, n - 1) {
                    let rev_prefix: String = wb[..k].iter().rev().map(|&c| c as char).collect();
                    if let Some(&j) = word_map.get(rev_prefix.as_str()) {
                        if j != i as i32 {
                            result.push(vec![i as i32, j]);
                        }
                    }
                }
            }
        }
        // Dedup (same pair can appear twice from symmetric splits)
        result.sort_unstable();
        result.dedup();
        result
    }

    fn is_palindrome(b: &[u8], lo: usize, hi: usize) -> bool {
        if hi < lo { return true; } // empty range
        let mut l = lo;
        let mut r = hi;
        while l < r {
            if b[l] != b[r] { return false; }
            l += 1;
            r -= 1;
        }
        true
    }
}

#[cfg(test)]
mod tests_lc336 {
    use std::collections::HashMap;
    struct Solution;
    impl Solution {
        fn is_palindrome(b: &[u8], lo: usize, hi: usize) -> bool {
            if hi < lo { return true; }
            let (mut l, mut r) = (lo, hi);
            while l < r { if b[l] != b[r] { return false; } l += 1; r -= 1; }
            true
        }
        pub fn palindrome_pairs(words: Vec<String>) -> Vec<Vec<i32>> {
            let word_map: HashMap<&str, i32> = words.iter().enumerate().map(|(i, w)| (w.as_str(), i as i32)).collect();
            let mut result = Vec::new();
            for (i, word) in words.iter().enumerate() {
                let n = word.len();
                let wb = word.as_bytes();
                for k in 0..=n {
                    if Self::is_palindrome(wb, 0, k.saturating_sub(1)) {
                        let rev_suf: String = wb[k..].iter().rev().map(|&c| c as char).collect();
                        if let Some(&j) = word_map.get(rev_suf.as_str()) {
                            if j != i as i32 { result.push(vec![j, i as i32]); }
                        }
                    }
                    if k < n && Self::is_palindrome(wb, k, n - 1) {
                        let rev_pre: String = wb[..k].iter().rev().map(|&c| c as char).collect();
                        if let Some(&j) = word_map.get(rev_pre.as_str()) {
                            if j != i as i32 { result.push(vec![i as i32, j]); }
                        }
                    }
                }
            }
            result.sort_unstable();
            result.dedup();
            result
        }
    }
    #[test]
    fn test_basic() {
        let mut result = Solution::palindrome_pairs(
            vec!["abcd".into(), "dcba".into(), "lls".into(), "s".into(), "sssll".into()]
        );
        result.sort();
        let mut expected = vec![vec![0,1], vec![1,0], vec![3,2], vec![2,4]];
        expected.sort();
        assert_eq!(result, expected);
    }
    #[test]
    fn test_empty_string() {
        // "" + "a" and "a" + "" are both palindromes
        let mut result = Solution::palindrome_pairs(vec!["a".into(), "".into()]);
        result.sort();
        assert_eq!(result, vec![vec![0,1], vec![1,0]]);
    }
}
```

**Complexity.** Time O(W * L^2) where L = max word length. Space O(W * L).

> **Design note.** A Trie-based approach for this problem exists (insert reversed words, then for
> each word's split, traverse the reversed-word Trie). In Rust, the HashMap approach is substantially
> simpler and equally efficient for the constraints given. Java developers should also prefer HashMap
> here — the Trie adds complexity without asymptotic gain.

---

## LC 1178. Number of Valid Words for Each Puzzle

**Problem.** Given `words` and `puzzles`, for each puzzle, count the words where every letter in the
word is in the puzzle AND the puzzle's first letter is in the word.

**Key insight.** Represent each word as a bitmask of the letters it contains. For each puzzle
(also bitmask), enumerate all subsets of the puzzle's bitmask that include the first letter, and
count how many word bitmasks match.

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn find_num_of_valid_words(words: Vec<String>, puzzles: Vec<String>) -> Vec<i32> {
        // Count frequency of each word's bitmask
        let mut freq: HashMap<u32, i32> = HashMap::new();
        for word in &words {
            let mask = word.bytes().fold(0u32, |acc, c| acc | (1 << (c - b'a')));
            *freq.entry(mask).or_insert(0) += 1;
        }

        puzzles.iter().map(|puzzle| {
            let pb = puzzle.as_bytes();
            let first_bit = 1u32 << (pb[0] - b'a');
            let puzzle_mask = pb.iter().fold(0u32, |acc, &c| acc | (1 << (c - b'a')));

            // Enumerate all subsets of puzzle_mask that include first_bit
            let mut count = 0;
            let mut sub = puzzle_mask;
            loop {
                if sub & first_bit != 0 {
                    count += freq.get(&sub).copied().unwrap_or(0);
                }
                if sub == 0 { break; }
                // Standard subset enumeration trick
                sub = (sub - 1) & puzzle_mask;
            }
            count
        }).collect()
    }
}

#[cfg(test)]
mod tests_lc1178 {
    use std::collections::HashMap;
    struct Solution;
    impl Solution {
        pub fn find_num_of_valid_words(words: Vec<String>, puzzles: Vec<String>) -> Vec<i32> {
            let mut freq: HashMap<u32, i32> = HashMap::new();
            for word in &words {
                let mask = word.bytes().fold(0u32, |acc, c| acc | (1 << (c - b'a')));
                *freq.entry(mask).or_insert(0) += 1;
            }
            puzzles.iter().map(|puzzle| {
                let pb = puzzle.as_bytes();
                let first_bit = 1u32 << (pb[0] - b'a');
                let puzzle_mask = pb.iter().fold(0u32, |acc, &c| acc | (1 << (c - b'a')));
                let mut count = 0;
                let mut sub = puzzle_mask;
                loop {
                    if sub & first_bit != 0 { count += freq.get(&sub).copied().unwrap_or(0); }
                    if sub == 0 { break; }
                    sub = (sub - 1) & puzzle_mask;
                }
                count
            }).collect()
        }
    }
    #[test]
    fn test_basic() {
        let result = Solution::find_num_of_valid_words(
            vec!["aaaa".into(),"asas".into(),"able".into(),"ability".into(),"actt".into(),"actor".into(),"access".into()],
            vec!["aboveyz".into(),"abrodyz".into(),"abslute".into(),"absolutely".into(),"acttbyz".into()]
        );
        assert_eq!(result, vec![1, 1, 3, 4, 0]);
    }
    #[test]
    fn test_no_matches() {
        let result = Solution::find_num_of_valid_words(
            vec!["apple".into()],
            vec!["xyz".into()]
        );
        assert_eq!(result, vec![0]);
    }
}
```

**Complexity.** Time O(W * L_w + P * 2^7) = O(W * L_w + P * 128) since puzzles are at most 7 chars.
Space O(W).

> **Note on the "Trie" classification.** LC 1178 is tagged "Trie" on LeetCode but the canonical
> efficient solution is a bitmask-subset enumeration over a frequency map. A true Trie approach
> exists but offers no advantage here — puzzles have at most 7 characters (2^7 = 128 subsets).
> Always match the data structure to the problem constraints.

---

## Patterns & Tips

### When to Use Each Trie Shape

| Shape | Best for | Trade-offs |
|---|---|---|
| `[Option<Box<TrieNode>>; 26]` | ASCII lowercase, cache-friendly | 26 × 8 bytes per node even if sparse |
| `HashMap<char, Box<TrieNode>>` | Non-ASCII, large alphabets, sparse trees | HashMap overhead per node |
| `[Option<Box<BitNode>>; 2]` | XOR maximization, bit queries | Always exactly 32-64 levels deep |
| Bitmask + HashMap | Set-membership queries, puzzle problems | Not a real Trie; use when chars <= ~20 |

### The `get_or_insert_with` Pattern

This is the most important idiom for Trie insertion in Rust:

```rust
node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
```

- Returns `&mut TrieNode` pointing into the (possibly newly created) child.
- One expression replaces `if None { insert } else { get_mut }` — cleaner and borrow-safe.
- The equivalent Java pattern is `computeIfAbsent(c, k -> new TrieNode())`.

### Borrow-Checker Patterns in Trie Code

**Walking (immutable):** Use `as_ref()` to get `Option<&Box<TrieNode>>`, then dereference:
```rust
let mut node = &root;
for c in word.bytes() {
    let idx = (c - b'a') as usize;
    match node.children[idx].as_ref() {
        None => return false,
        Some(child) => node = child,
    }
}
```

**Inserting (mutable):** Use `get_or_insert_with` — the compiler can prove the loop variable
`node` is re-bound to a shorter-lived reference on each iteration:
```rust
let mut node = &mut root;
for c in word.bytes() {
    let idx = (c - b'a') as usize;
    node = node.children[idx].get_or_insert_with(|| Box::new(TrieNode::default()));
}
```

**Why not a `while` loop?** The for loop over bytes naturally satisfies the borrow checker's
NLL (Non-Lexical Lifetime) rules. A `while` loop with manual index arithmetic can confuse
the borrow checker in older editions.

### Java vs. Rust: Key Differences

| Concern | Java | Rust |
|---|---|---|
| Null children | `null` reference | `Option<Box<TrieNode>>` — enforces null check at type level |
| Node creation | `new TrieNode()` (GC managed) | `Box::new(TrieNode::default())` (heap, drop when out of scope) |
| Shared Trie during search | Multiple readers fine | `&TrieNode` references (shared borrow); no `Rc` needed if read-only |
| Mutable + immutable in search | Java has no restriction | Rust: separate the build phase (mut) from query phase (&) |
| Default initialization | Constructor zeros fields | `#[derive(Default)]` + `Default` impl generates `[None; 26]` |

### Common Interview Patterns

1. **Prefix counting:** Increment a counter at each node during insert (LC 677, LC 2416).
2. **Suffix Trie:** Reverse words before insertion to detect suffix relationships (LC 820, LC 1032).
3. **Binary Trie:** 32-bit integers as paths; greedy XOR maximization by choosing the opposite bit (LC 421).
4. **DP + Trie:** Walk the Trie during DP transitions to avoid O(W) dictionary scan per state (LC 139, LC 472).
5. **Subset enumeration beats Trie:** When alphabet is small (≤ 20 chars), bitmask + HashMap outperforms a real Trie (LC 1178).
6. **Conceptual Trie / DFS:** Lexicographic order problems can be solved with digit-Trie DFS without allocating nodes (LC 386, LC 440).

### Complexity Quick Reference

| Problem | Time | Space | Key technique |
|---|---|---|---|
| LC 14 | O(S) | O(1) | Shrink prefix length |
| LC 139 | O(n * L) | O(n) | DP + HashSet |
| LC 140 | O(n^2 * 2^n) worst | O(n) memo | Backtrack + memo |
| LC 386 | O(N) | O(1) | DFS on digit Trie |
| LC 421 | O(N * 32) | O(N * 32) | Binary Trie |
| LC 440 | O(log^2 N) | O(1) | Subtree counting |
| LC 472 | O(W * N * L) | O(W * L) | Word break per word |
| LC 648 | O(D + S) | O(D) | Trie prefix match |
| LC 676 | O(L * 26) | O(W) | Brute-force replace |
| LC 677 | O(k) insert+query | O(total chars) | Prefix sum at nodes |
| LC 692 | O(N log N) | O(N) | Sort + collect |
| LC 720 | O(W) | O(W) | BFS on Trie |
| LC 820 | O(W^2) | O(W) | Suffix removal |
| LC 1032 | O(W * L) build | O(active) query | Reverse Trie + active set |
| LC 1178 | O(W * L + P * 128) | O(W) | Bitmask subset enum |
| LC 1268 | O(P log P + S log P) | O(1) | Sort + partition_point |
| LC 2416 | O(W * L) | O(W * L) | Pass-through counts |
| LC 336 | O(W * L^2) | O(W * L) | HashMap + split |
