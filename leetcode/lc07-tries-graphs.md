# LC-07: Tries & Graphs

> **Cookbook Philosophy:** Every problem includes a complete, runnable solution with passing tests. All examples target Rust 2024 edition (1.85+). The goal is understanding *why* Rust's ownership model shapes graph and trie code so differently from Java.

> **Java mental model:** In Java, a graph node is a class with a `List<Node> neighbors` field you mutate freely. In Rust, shared mutable references require `Rc<RefCell<T>>`, which is the source of most "why is this so verbose?" moments for graph problems. For grid-based problems, a `Vec<Vec<i32>>` with index arithmetic is usually cleaner — and Rust's bounds checking makes it safer than Java arrays.

---

## Problem Overview

| # | Problem | Difficulty | Blind75 | NeetCode150 |
|---|---------|-----------|---------|-------------|
| LC 208 | [Implement Trie](#1--implement-trie-lc-208) | Medium | ✓ | ✓ |
| LC 211 | [Add and Search Words](#2--add-and-search-words-lc-211) | Medium | ✓ | ✓ |
| LC 212 | [Word Search II](#3--word-search-ii-lc-212) | Hard | ✓ | ✓ |
| LC 200 | [Number of Islands](#4--number-of-islands-lc-200) | Medium | ✓ | ✓ |
| LC 133 | [Clone Graph](#5--clone-graph-lc-133) | Medium | ✓ | ✓ |
| LC 695 | [Max Area of Island](#6--max-area-of-island-lc-695) | Medium | — | ✓ |
| LC 417 | [Pacific Atlantic Water Flow](#7--pacific-atlantic-water-flow-lc-417) | Medium | ✓ | ✓ |
| LC 130 | [Surrounded Regions](#8--surrounded-regions-lc-130) | Medium | ✓ | ✓ |
| LC 994 | [Rotting Oranges](#9--rotting-oranges-lc-994) | Medium | — | ✓ |
| LC 286 | [Walls and Gates](#10--walls-and-gates-lc-286) | Medium | — | ✓ |
| LC 207 | [Course Schedule](#11--course-schedule-lc-207) | Medium | ✓ | ✓ |
| LC 210 | [Course Schedule II](#12--course-schedule-ii-lc-210) | Medium | ✓ | ✓ |
| LC 684 | [Redundant Connection](#13--redundant-connection-lc-684) | Medium | — | ✓ |
| LC 323 | [Number of Connected Components](#14--number-of-connected-components-lc-323) | Medium | ✓ | ✓ |
| LC 261 | [Graph Valid Tree](#15--graph-valid-tree-lc-261) | Medium | ✓ | ✓ |
| LC 127 | [Word Ladder](#16--word-ladder-lc-127) | Hard | ✓ | ✓ |

---

## Java → Rust Quick Reference for This Chapter

| Java idiom | Rust equivalent | Notes |
|-----------|----------------|-------|
| `Map<Character, TrieNode> children` | `[Option<Box<TrieNode>>; 26]` | Fixed array; index = `ch as usize - 'a' as usize` |
| `Queue<int[]> q = new LinkedList<>()` | `let mut q: VecDeque<(usize, usize)> = VecDeque::new()` | BFS for grid problems |
| `boolean[][] visited` | `vec![vec![false; cols]; rows]` | Heap-allocated 2-D bool grid |
| `Map<Integer, List<Integer>>` | `Vec<Vec<usize>>` adjacency list | Index nodes 0..n; avoids HashMap overhead |
| `node.neighbors` (mutable) | `node.borrow_mut().neighbors` | Via `Rc<RefCell<Node>>` |
| `parent[]` union-find array | `struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }` | See intro below |
| `new ArrayDeque<>()` for BFS | `VecDeque::new()` | From `std::collections::VecDeque` |

---

## Shared Data Structures

These types are defined once here and referenced by all solutions below.

### Trie Node (Array-based — primary)

```rust
/// Array-indexed children: children[0] = 'a', children[25] = 'z'.
/// Box<T> gives heap allocation; Option<Box<T>> is None for absent children.
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    is_end: bool,
}
```

**Why `[Option<Box<TrieNode>>; 26]` and not `HashMap<char, Box<TrieNode>>`?**

The array version is cache-friendly and O(1) per level. `Box<TrieNode>` heap-allocates each node individually (the node is too large to live inline in the parent). `[const { None }; 26]` (or `#[derive(Default)]`) initialises all 26 slots to `None`.

The HashMap alternative is `children: HashMap<char, Box<TrieNode>>` — cleaner for non-ASCII or sparse alphabets. Both are correct; the array form is idiomatic for LC problems constrained to `a-z`.

### Clone Graph Node

```rust
use std::rc::Rc;
use std::cell::RefCell;

#[derive(Debug)]
pub struct GraphNode {
    pub val: i32,
    pub neighbors: Vec<Rc<RefCell<GraphNode>>>,
}

impl GraphNode {
    pub fn new(val: i32) -> Self {
        GraphNode { val, neighbors: vec![] }
    }
}

pub type GNode = Rc<RefCell<GraphNode>>;
```

### Union-Find (DSU) with Path Compression and Rank

Used by problems 13, 14, and 15.

```rust
struct UnionFind {
    parent: Vec<usize>,
    rank:   Vec<usize>,
    count:  usize,        // number of disjoint components
}

impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind {
            parent: (0..n).collect(),
            rank:   vec![0; n],
            count:  n,
        }
    }

    /// Path-compressed find: flattens the tree toward the root.
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x {
            self.parent[x] = self.find(self.parent[x]);
        }
        self.parent[x]
    }

    /// Union by rank. Returns false if x and y are already in the same set.
    fn union(&mut self, x: usize, y: usize) -> bool {
        let rx = self.find(x);
        let ry = self.find(y);
        if rx == ry { return false; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => {
                self.parent[ry] = rx;
                self.rank[rx] += 1;
            }
        }
        self.count -= 1;
        true
    }
}
```

**Rust note:** Recursive `find` with path compression compiles fine because Rust allows recursive functions. The temporary `self.parent[x]` binding is needed: you cannot write `self.parent[x] = self.find(self.parent[x])` without the intermediate `let` because that would create two mutable borrows of `self` simultaneously. Use:

```rust
let p = self.parent[x];
self.parent[x] = self.find(p);
```

---

## Part 1 — Tries

---

## 1 — Implement Trie (LC #208)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Implement a prefix tree (trie) supporting three operations: `insert(word)`, `search(word)` (exact match), and `starts_with(prefix)` (prefix match).

### Key Insight

Walk character by character; at each level, index into `children` using `ch as usize - b'a' as usize`. For `insert`, create nodes on-demand with `get_or_insert_with(Box::default)`. For `search`, walk to the end and check `is_end`. For `starts_with`, walk without requiring `is_end`.

### Solution

```rust
#[derive(Default)]
struct TrieNode {
    children: [Option<Box<TrieNode>>; 26],
    is_end: bool,
}

struct Trie {
    root: Box<TrieNode>,
}

impl Trie {
    fn new() -> Self {
        Trie { root: Box::default() }
    }

    fn insert(&mut self, word: String) {
        let mut node = &mut *self.root;
        for ch in word.bytes() {
            let idx = (ch - b'a') as usize;
            node = node.children[idx].get_or_insert_with(Box::default);
        }
        node.is_end = true;
    }

    fn search(&self, word: String) -> bool {
        self.find_node(&word).map_or(false, |n| n.is_end)
    }

    fn starts_with(&self, prefix: String) -> bool {
        self.find_node(&prefix).is_some()
    }

    fn find_node<'a>(&'a self, s: &str) -> Option<&'a TrieNode> {
        let mut node = &*self.root;
        for ch in s.bytes() {
            let idx = (ch - b'a') as usize;
            node = node.children[idx].as_deref()?;
        }
        Some(node)
    }
}

#[cfg(test)]
mod tests_lc208 {
    use super::Trie;

    #[test]
    fn basic_ops() {
        let mut t = Trie::new();
        t.insert("apple".to_string());
        assert!(t.search("apple".to_string()));
        assert!(!t.search("app".to_string()));
        assert!(t.starts_with("app".to_string()));
        t.insert("app".to_string());
        assert!(t.search("app".to_string()));
    }

    #[test]
    fn prefix_only() {
        let mut t = Trie::new();
        t.insert("hello".to_string());
        assert!(t.starts_with("he".to_string()));
        assert!(!t.starts_with("world".to_string()));
    }

    #[test]
    fn empty_string() {
        let mut t = Trie::new();
        t.insert(String::new());
        assert!(t.search(String::new()));
        assert!(t.starts_with(String::new()));
    }
}
```

**Complexity:** O(m) per operation where m = word length. Space O(m·n) total for n words.

**Rust notes:** `get_or_insert_with(Box::default)` inserts a new default node only if the slot is `None`, then returns `&mut TrieNode`. The lifetime annotation `'a` on `find_node` ties the returned borrow to `&'a self` so the node reference stays valid. `as_deref()` converts `&Option<Box<T>>` to `Option<&T>` — exactly the coercion needed to peel one layer off.

---

## 2 — Add and Search Words (LC #211)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Design a data structure that supports adding words and searching for words with wildcards: `.` matches any single letter.

### Key Insight

Same trie structure as #208. For `search`, add a recursive DFS that at each `.` character tries all 26 children. Exact characters follow the normal trie path.

### Solution

```rust
#[derive(Default)]
struct WDTrieNode {
    children: [Option<Box<WDTrieNode>>; 26],
    is_end: bool,
}

struct WordDictionary {
    root: Box<WDTrieNode>,
}

impl WordDictionary {
    fn new() -> Self {
        WordDictionary { root: Box::default() }
    }

    fn add_word(&mut self, word: String) {
        let mut node = &mut *self.root;
        for ch in word.bytes() {
            let idx = (ch - b'a') as usize;
            node = node.children[idx].get_or_insert_with(Box::default);
        }
        node.is_end = true;
    }

    fn search(&self, word: String) -> bool {
        Self::dfs(&self.root, word.as_bytes())
    }

    fn dfs(node: &WDTrieNode, chars: &[u8]) -> bool {
        if chars.is_empty() {
            return node.is_end;
        }
        let (ch, rest) = (chars[0], &chars[1..]);
        if ch == b'.' {
            // Wildcard: try every existing child
            node.children.iter()
                .filter_map(|c| c.as_deref())
                .any(|child| Self::dfs(child, rest))
        } else {
            let idx = (ch - b'a') as usize;
            node.children[idx].as_deref()
                .map_or(false, |child| Self::dfs(child, rest))
        }
    }
}

#[cfg(test)]
mod tests_lc211 {
    use super::WordDictionary;

    #[test]
    fn wildcards() {
        let mut wd = WordDictionary::new();
        wd.add_word("bad".to_string());
        wd.add_word("dad".to_string());
        wd.add_word("mad".to_string());
        assert!(!wd.search("pad".to_string()));
        assert!(wd.search("bad".to_string()));
        assert!(wd.search(".ad".to_string()));
        assert!(wd.search("b..".to_string()));
    }

    #[test]
    fn no_match() {
        let mut wd = WordDictionary::new();
        wd.add_word("abc".to_string());
        assert!(!wd.search("xyz".to_string()));
        assert!(!wd.search("ab".to_string()));
        assert!(!wd.search("abcd".to_string()));
    }
}
```

**Complexity:** O(m) insert; O(m · 26^k) search worst case where k = number of wildcards. Space O(m·n).

**Rust notes:** Slicing bytes with `chars[0]` and `&chars[1..]` is idiomatic for recursive byte parsing. `filter_map(|c| c.as_deref())` strips the `Option<Box<_>>` wrapper in one step. Passing `&[u8]` avoids re-creating a `String` at each recursion level.

---

## 3 — Word Search II (LC #212)

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` character board and a list of words, return all words that can be found by a path of adjacent cells (horizontal/vertical, no cell reused in one path).

### Key Insight

Build a trie from the word list. DFS each board cell; at each step, check if the current board character leads to a trie child. If a trie node is marked `is_end`, collect the word. A `HashSet<String>` deduplicates repeated words.

### Solution

```rust
use std::collections::HashSet;

#[derive(Default)]
struct W2TrieNode {
    children: [Option<Box<W2TrieNode>>; 26],
    word: Option<String>,   // full word stored at terminal node
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_words(board: Vec<Vec<char>>, words: Vec<String>) -> Vec<String> {
        let rows = board.len();
        let cols = board[0].len();

        // Build trie
        let mut root = Box::<W2TrieNode>::default();
        for word in &words {
            let mut node = &mut *root;
            for ch in word.bytes() {
                let idx = (ch - b'a') as usize;
                node = node.children[idx].get_or_insert_with(Box::default);
            }
            node.word = Some(word.clone());
        }

        let mut result: HashSet<String> = HashSet::new();
        let mut visited = vec![vec![false; cols]; rows];

        for r in 0..rows {
            for c in 0..cols {
                Self::dfs(&board, &mut visited, r, c, &root, &mut result);
            }
        }

        result.into_iter().collect()
    }

    fn dfs(
        board: &Vec<Vec<char>>,
        visited: &mut Vec<Vec<bool>>,
        r: usize,
        c: usize,
        node: &W2TrieNode,
        result: &mut HashSet<String>,
    ) {
        let rows = board.len();
        let cols = board[0].len();

        if visited[r][c] { return; }
        let ch = board[r][c] as u8;
        let idx = (ch - b'a') as usize;
        let Some(child) = node.children[idx].as_ref() else { return; };

        if let Some(ref word) = child.word {
            result.insert(word.clone());
        }

        visited[r][c] = true;
        let dirs: [(i32, i32); 4] = [(-1, 0), (1, 0), (0, -1), (0, 1)];
        for (dr, dc) in dirs {
            let nr = r as i32 + dr;
            let nc = c as i32 + dc;
            if nr >= 0 && nr < rows as i32 && nc >= 0 && nc < cols as i32 {
                Self::dfs(board, visited, nr as usize, nc as usize, child, result);
            }
        }
        visited[r][c] = false;
    }
}

#[cfg(test)]
mod tests_lc212 {
    use super::Solution;

    fn sorted(mut v: Vec<String>) -> Vec<String> { v.sort(); v }

    #[test]
    fn basic() {
        let board = vec![
            vec!['o','a','a','n'],
            vec!['e','t','a','e'],
            vec!['i','h','k','r'],
            vec!['i','f','l','v'],
        ];
        let words = vec!["oath","pea","eat","rain"].iter().map(|s| s.to_string()).collect();
        assert_eq!(sorted(Solution::find_words(board, words)), vec!["eat", "oath"]);
    }

    #[test]
    fn no_matches() {
        let board = vec![vec!['a','b'],vec!['c','d']];
        let words = vec!["xyz".to_string()];
        assert!(Solution::find_words(board, words).is_empty());
    }

    #[test]
    fn single_cell() {
        let board = vec![vec!['a']];
        let words = vec!["a".to_string()];
        assert_eq!(Solution::find_words(board, words), vec!["a"]);
    }
}
```

**Complexity:** O(M · 4 · 3^(L-1)) DFS per cell where M = board cells, L = max word length. Trie build O(W·L). Space O(W·L) trie + O(L) stack.

**Rust notes:** `let Some(child) = ... else { return; }` is `let-else` syntax (stable since 1.65). Storing `word: Option<String>` in the trie node avoids reconstructing the word during DFS — the word is already there at the terminal. `visited` is reset after each DFS branch (`= false`) to enable other paths to reuse the cell.

---

## Part 2 — Graphs

---

## 4 — Number of Islands (LC #200)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` grid of `'1'` (land) and `'0'` (water), count the number of islands. An island is surrounded by water and formed by connecting adjacent land cells horizontally or vertically.

### Key Insight

Flood-fill: when a `'1'` is found, increment the counter and DFS to mark all connected land as visited (by flipping to `'0'`). This avoids a separate `visited` array.

### Solution

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn num_islands(mut grid: Vec<Vec<char>>) -> i32 {
        let rows = grid.len();
        let cols = grid[0].len();
        let mut count = 0;

        for r in 0..rows {
            for c in 0..cols {
                if grid[r][c] == '1' {
                    count += 1;
                    Self::dfs(&mut grid, r, c, rows, cols);
                }
            }
        }
        count
    }

    fn dfs(grid: &mut Vec<Vec<char>>, r: usize, c: usize, rows: usize, cols: usize) {
        if grid[r][c] != '1' { return; }
        grid[r][c] = '0';
        if r + 1 < rows { Self::dfs(grid, r + 1, c, rows, cols); }
        if c + 1 < cols { Self::dfs(grid, r, c + 1, rows, cols); }
        if r > 0        { Self::dfs(grid, r - 1, c, rows, cols); }
        if c > 0        { Self::dfs(grid, r, c - 1, rows, cols); }
    }
}

#[cfg(test)]
mod tests_lc200 {
    use super::Solution;

    fn g(rows: &[&str]) -> Vec<Vec<char>> {
        rows.iter().map(|r| r.chars().collect()).collect()
    }

    #[test]
    fn two_islands() {
        assert_eq!(Solution::num_islands(g(&["11000","11000","00100","00011"])), 3);
    }

    #[test]
    fn one_island() {
        assert_eq!(Solution::num_islands(g(&["11111","11011","11111"])), 1);
    }

    #[test]
    fn all_water() {
        assert_eq!(Solution::num_islands(g(&["000","000"])), 0);
    }
}
```

**Complexity:** O(m·n) time and space.

**Rust notes:** Bounds checks use `r + 1 < rows` instead of `r < rows - 1` because `rows` is `usize` and `rows - 1` underflows when `rows == 0`. Always add before comparing with `usize`. Flipping `'1'` to `'0'` in-place avoids allocating a visited array — acceptable when the grid can be mutated. LeetCode passes grids by value, so `mut grid` is fine.

---

## 5 — Clone Graph (LC #133)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given a reference to a node in a connected undirected graph, return a deep copy. Each node has a `val` (1–100, unique) and a list of neighbors.

### Key Insight

BFS from the start node. Use `HashMap<i32, GNode>` keyed by `val` to track already-cloned nodes. For each original node, create its clone on first visit, then wire up its neighbors.

### Solution

```rust
use std::collections::{HashMap, VecDeque};
use std::rc::Rc;
use std::cell::RefCell;

#[derive(Debug)]
pub struct GraphNode {
    pub val: i32,
    pub neighbors: Vec<Rc<RefCell<GraphNode>>>,
}
impl GraphNode {
    pub fn new(val: i32) -> Self { GraphNode { val, neighbors: vec![] } }
}
type GNode = Rc<RefCell<GraphNode>>;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn clone_graph(node: Option<GNode>) -> Option<GNode> {
        let start = node?;
        let mut cloned: HashMap<i32, GNode> = HashMap::new();
        let mut queue: VecDeque<GNode> = VecDeque::new();

        let root_val = start.borrow().val;
        let root_clone = Rc::new(RefCell::new(GraphNode::new(root_val)));
        cloned.insert(root_val, Rc::clone(&root_clone));
        queue.push_back(Rc::clone(&start));

        while let Some(orig) = queue.pop_front() {
            let orig_val = orig.borrow().val;
            let neighbors: Vec<GNode> = orig.borrow().neighbors.clone();

            for nbr in neighbors {
                let nbr_val = nbr.borrow().val;
                if !cloned.contains_key(&nbr_val) {
                    let new_node = Rc::new(RefCell::new(GraphNode::new(nbr_val)));
                    cloned.insert(nbr_val, Rc::clone(&new_node));
                    queue.push_back(Rc::clone(&nbr));
                }
                let nbr_clone = Rc::clone(cloned.get(&nbr_val).unwrap());
                cloned[&orig_val].borrow_mut().neighbors.push(nbr_clone);
            }
        }
        Some(root_clone)
    }
}

#[cfg(test)]
mod tests_lc133 {
    use super::*;

    fn build_graph(edges: &[(i32, i32)], n: i32) -> Vec<GNode> {
        let nodes: Vec<GNode> = (1..=n)
            .map(|v| Rc::new(RefCell::new(GraphNode::new(v))))
            .collect();
        for &(u, v) in edges {
            let nu = Rc::clone(&nodes[(u - 1) as usize]);
            let nv = Rc::clone(&nodes[(v - 1) as usize]);
            nodes[(u - 1) as usize].borrow_mut().neighbors.push(nv);
            nodes[(v - 1) as usize].borrow_mut().neighbors.push(nu);
        }
        nodes
    }

    #[test]
    fn four_node_cycle() {
        let nodes = build_graph(&[(1,2),(2,3),(3,4),(4,1),(1,3)], 4);
        let clone = Solution::clone_graph(Some(Rc::clone(&nodes[0]))).unwrap();
        // Cloned node 1 must have val 1 and 3 neighbors
        let clone_borrow = clone.borrow();
        assert_eq!(clone_borrow.val, 1);
        assert_eq!(clone_borrow.neighbors.len(), 3);
        // Must be a different allocation
        assert!(!Rc::ptr_eq(&clone, &nodes[0]));
    }

    #[test]
    fn single_node() {
        let node: GNode = Rc::new(RefCell::new(GraphNode::new(1)));
        let clone = Solution::clone_graph(Some(Rc::clone(&node))).unwrap();
        assert_eq!(clone.borrow().val, 1);
        assert!(clone.borrow().neighbors.is_empty());
    }
}
```

**Complexity:** O(V + E) time and space.

**Rust notes:** `.borrow().neighbors.clone()` on a `Vec<Rc<…>>` clones the `Vec` cheaply — each `Rc::clone` only bumps a reference count. The borrow ends before `borrow_mut()` is called on the same node. Keying by `val` (rather than by pointer) sidesteps `Rc::as_ptr` raw-pointer arithmetic.

---

## 6 — Max Area of Island (LC #695)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

Given an integer grid of `0`s and `1`s, return the maximum area of an island (number of connected `1` cells). Return `0` if no island exists.

### Key Insight

Same flood-fill as #200, but DFS returns the area count of the component.

### Solution

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn max_area_of_island(mut grid: Vec<Vec<i32>>) -> i32 {
        let rows = grid.len();
        let cols = grid[0].len();
        let mut max = 0;
        for r in 0..rows {
            for c in 0..cols {
                if grid[r][c] == 1 {
                    max = max.max(Self::dfs(&mut grid, r, c, rows, cols));
                }
            }
        }
        max
    }

    fn dfs(grid: &mut Vec<Vec<i32>>, r: usize, c: usize, rows: usize, cols: usize) -> i32 {
        if grid[r][c] != 1 { return 0; }
        grid[r][c] = 0;
        let mut area = 1;
        if r + 1 < rows { area += Self::dfs(grid, r + 1, c, rows, cols); }
        if c + 1 < cols { area += Self::dfs(grid, r, c + 1, rows, cols); }
        if r > 0        { area += Self::dfs(grid, r - 1, c, rows, cols); }
        if c > 0        { area += Self::dfs(grid, r, c - 1, rows, cols); }
        area
    }
}

#[cfg(test)]
mod tests_lc695 {
    use super::Solution;

    #[test]
    fn max_area() {
        let grid = vec![
            vec![0,0,1,0,0,0,0,1,0,0,0,0,0],
            vec![0,0,0,0,0,0,0,1,1,1,0,0,0],
            vec![0,1,1,0,1,0,0,0,0,0,0,0,0],
            vec![0,1,0,0,1,1,0,0,1,0,1,0,0],
            vec![0,1,0,0,1,1,0,0,1,1,1,0,0],
            vec![0,0,0,0,0,0,0,0,0,0,1,0,0],
            vec![0,0,0,0,0,0,0,1,1,1,0,0,0],
            vec![0,0,0,0,0,0,0,1,1,0,0,0,0],
        ];
        assert_eq!(Solution::max_area_of_island(grid), 6);
    }

    #[test]
    fn all_zeros() {
        assert_eq!(Solution::max_area_of_island(vec![vec![0,0],vec![0,0]]), 0);
    }
}
```

**Complexity:** O(m·n) time and space.

**Rust notes:** `max.max(...)` uses the `i32::max` method — cleaner than `if area > max { max = area }`. Both work; the method form is idiomatic.

---

## 7 — Pacific Atlantic Water Flow (LC #417)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` matrix of heights, water can flow to adjacent cells with equal or lower height. Return all cells that can flow to both the Pacific (top/left edges) and Atlantic (bottom/right edges) oceans.

### Key Insight

Reverse BFS: start from ocean borders and flow *uphill* (to cells with greater-or-equal height). Any cell reachable from both sets of borders is an answer.

### Solution

```rust
use std::collections::VecDeque;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn pacific_atlantic(heights: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        let rows = heights.len();
        let cols = heights[0].len();

        let mut pac = vec![vec![false; cols]; rows];
        let mut atl = vec![vec![false; cols]; rows];

        let mut pac_q: VecDeque<(usize, usize)> = VecDeque::new();
        let mut atl_q: VecDeque<(usize, usize)> = VecDeque::new();

        for r in 0..rows {
            pac_q.push_back((r, 0));         pac[r][0] = true;
            atl_q.push_back((r, cols - 1));  atl[r][cols - 1] = true;
        }
        for c in 0..cols {
            pac_q.push_back((0, c));         pac[0][c] = true;
            atl_q.push_back((rows - 1, c));  atl[rows - 1][c] = true;
        }

        Self::bfs(&heights, &mut pac_q, &mut pac, rows, cols);
        Self::bfs(&heights, &mut atl_q, &mut atl, rows, cols);

        let mut result = vec![];
        for r in 0..rows {
            for c in 0..cols {
                if pac[r][c] && atl[r][c] {
                    result.push(vec![r as i32, c as i32]);
                }
            }
        }
        result
    }

    fn bfs(
        h: &Vec<Vec<i32>>,
        q: &mut VecDeque<(usize, usize)>,
        visited: &mut Vec<Vec<bool>>,
        rows: usize,
        cols: usize,
    ) {
        let dirs: [(i32, i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
        while let Some((r, c)) = q.pop_front() {
            for (dr, dc) in dirs {
                let nr = r as i32 + dr;
                let nc = c as i32 + dc;
                if nr < 0 || nr >= rows as i32 || nc < 0 || nc >= cols as i32 { continue; }
                let (nr, nc) = (nr as usize, nc as usize);
                if !visited[nr][nc] && h[nr][nc] >= h[r][c] {
                    visited[nr][nc] = true;
                    q.push_back((nr, nc));
                }
            }
        }
    }
}

#[cfg(test)]
mod tests_lc417 {
    use super::Solution;

    fn sorted(mut v: Vec<Vec<i32>>) -> Vec<Vec<i32>> { v.sort(); v }

    #[test]
    fn example() {
        let heights = vec![
            vec![1,2,2,3,5],
            vec![3,2,3,4,4],
            vec![2,4,5,3,1],
            vec![6,7,1,4,5],
            vec![5,1,1,2,4],
        ];
        let got = sorted(Solution::pacific_atlantic(heights));
        let expected = sorted(vec![
            vec![0,4],vec![1,3],vec![1,4],vec![2,2],
            vec![3,0],vec![3,1],vec![4,0],
        ]);
        assert_eq!(got, expected);
    }

    #[test]
    fn single_cell() {
        assert_eq!(Solution::pacific_atlantic(vec![vec![1]]), vec![vec![0, 0]]);
    }
}
```

**Complexity:** O(m·n) time and space.

**Rust notes:** Two separate `visited` grids (`pac`, `atl`) are created with `vec![vec![false; cols]; rows]`. Passing them as `&mut Vec<Vec<bool>>` lets `bfs` mutate in-place. The `(i32, i32)` direction array avoids signed/unsigned conversion issues inside the loop — cast to `usize` only after the bounds check passes.

---

## 8 — Surrounded Regions (LC #130)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` board of `'X'` and `'O'`, capture all regions of `'O'` that are entirely surrounded by `'X'` (not connected to any border `'O'`). Replace captured `'O'` with `'X'`.

### Key Insight

Any `'O'` reachable from a border is safe. Mark safe cells as `'S'` via BFS/DFS from border `'O'`s. Then scan the entire board: `'O'` → `'X'`, `'S'` → `'O'`.

### Solution

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn solve(board: &mut Vec<Vec<char>>) {
        let rows = board.len();
        let cols = board[0].len();

        // Mark border-connected 'O' cells as 'S'
        for r in 0..rows {
            if board[r][0] == 'O'       { Self::dfs(board, r, 0, rows, cols); }
            if board[r][cols-1] == 'O'  { Self::dfs(board, r, cols-1, rows, cols); }
        }
        for c in 0..cols {
            if board[0][c] == 'O'       { Self::dfs(board, 0, c, rows, cols); }
            if board[rows-1][c] == 'O'  { Self::dfs(board, rows-1, c, rows, cols); }
        }

        // Convert: 'O' → 'X' (captured), 'S' → 'O' (safe)
        for r in 0..rows {
            for c in 0..cols {
                match board[r][c] {
                    'O' => board[r][c] = 'X',
                    'S' => board[r][c] = 'O',
                    _   => {}
                }
            }
        }
    }

    fn dfs(board: &mut Vec<Vec<char>>, r: usize, c: usize, rows: usize, cols: usize) {
        if board[r][c] != 'O' { return; }
        board[r][c] = 'S';
        if r + 1 < rows { Self::dfs(board, r + 1, c, rows, cols); }
        if c + 1 < cols { Self::dfs(board, r, c + 1, rows, cols); }
        if r > 0        { Self::dfs(board, r - 1, c, rows, cols); }
        if c > 0        { Self::dfs(board, r, c - 1, rows, cols); }
    }
}

#[cfg(test)]
mod tests_lc130 {
    use super::Solution;

    fn board(rows: &[&str]) -> Vec<Vec<char>> {
        rows.iter().map(|r| r.chars().collect()).collect()
    }
    fn to_str(b: &Vec<Vec<char>>) -> Vec<String> {
        b.iter().map(|r| r.iter().collect()).collect()
    }

    #[test]
    fn capture_middle() {
        let mut b = board(&["XXXX","XOOX","XXOX","XOXX"]);
        Solution::solve(&mut b);
        assert_eq!(to_str(&b), vec!["XXXX","XXXX","XXXX","XOXX"]);
    }

    #[test]
    fn no_capture() {
        let mut b = board(&["OO","OO"]);
        Solution::solve(&mut b);
        assert_eq!(to_str(&b), vec!["OO","OO"]);
    }
}
```

**Complexity:** O(m·n) time and space.

**Rust notes:** `solve` takes `&mut Vec<Vec<char>>` matching LeetCode's in-place mutation signature. The sentinel character `'S'` avoids a separate visited array. The `match` at the end is cleaner than nested `if`/`else if` for three-way character dispatch.

---

## 9 — Rotting Oranges (LC #994)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

A grid contains `0` (empty), `1` (fresh orange), `2` (rotten). Each minute, fresh oranges adjacent to rotten ones become rotten. Return the minimum minutes until no fresh oranges remain, or `-1` if impossible.

### Key Insight

Multi-source BFS: seed the queue with all initially rotten oranges and propagate one layer per minute. Track fresh orange count; decrement on each conversion.

### Solution

```rust
use std::collections::VecDeque;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn oranges_rotting(mut grid: Vec<Vec<i32>>) -> i32 {
        let rows = grid.len();
        let cols = grid[0].len();
        let mut q: VecDeque<(usize, usize)> = VecDeque::new();
        let mut fresh = 0;

        for r in 0..rows {
            for c in 0..cols {
                match grid[r][c] {
                    1 => fresh += 1,
                    2 => q.push_back((r, c)),
                    _ => {}
                }
            }
        }

        let dirs: [(i32, i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
        let mut minutes = 0;

        while !q.is_empty() && fresh > 0 {
            minutes += 1;
            for _ in 0..q.len() {
                let (r, c) = q.pop_front().unwrap();
                for (dr, dc) in dirs {
                    let nr = r as i32 + dr;
                    let nc = c as i32 + dc;
                    if nr < 0 || nr >= rows as i32 || nc < 0 || nc >= cols as i32 { continue; }
                    let (nr, nc) = (nr as usize, nc as usize);
                    if grid[nr][nc] == 1 {
                        grid[nr][nc] = 2;
                        fresh -= 1;
                        q.push_back((nr, nc));
                    }
                }
            }
        }

        if fresh > 0 { -1 } else { minutes }
    }
}

#[cfg(test)]
mod tests_lc994 {
    use super::Solution;

    #[test]
    fn two_minutes() {
        assert_eq!(Solution::oranges_rotting(vec![vec![2,1,1],vec![1,1,0],vec![0,1,1]]), 4);
    }

    #[test]
    fn impossible() {
        assert_eq!(Solution::oranges_rotting(vec![vec![2,1,1],vec![0,1,1],vec![1,0,1]]), -1);
    }

    #[test]
    fn no_fresh() {
        assert_eq!(Solution::oranges_rotting(vec![vec![0,2]]), 0);
    }
}
```

**Complexity:** O(m·n) time and space.

**Rust notes:** `for _ in 0..q.len()` captures the current BFS layer size before processing starts — adding new elements inside the loop doesn't affect this count because `q.len()` is evaluated once per outer iteration. This is the idiomatic Rust pattern for level-order BFS.

---

## 10 — Walls and Gates (LC #286)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

Fill each empty room in an `m × n` grid with its distance to the nearest gate. Grid values: `INF` (empty room), `-1` (wall/obstacle), `0` (gate).

### Key Insight

Multi-source BFS from all gates simultaneously. Each BFS step fills the next ring of rooms with distance + 1. Empty rooms unreachable from any gate keep their `INF` value.

### Solution

```rust
use std::collections::VecDeque;

const INF: i32 = i32::MAX;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn walls_and_gates(rooms: &mut Vec<Vec<i32>>) {
        let rows = rooms.len();
        let cols = rooms[0].len();
        let mut q: VecDeque<(usize, usize)> = VecDeque::new();

        // Seed all gates
        for r in 0..rows {
            for c in 0..cols {
                if rooms[r][c] == 0 { q.push_back((r, c)); }
            }
        }

        let dirs: [(i32, i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
        while let Some((r, c)) = q.pop_front() {
            for (dr, dc) in dirs {
                let nr = r as i32 + dr;
                let nc = c as i32 + dc;
                if nr < 0 || nr >= rows as i32 || nc < 0 || nc >= cols as i32 { continue; }
                let (nr, nc) = (nr as usize, nc as usize);
                if rooms[nr][nc] == INF {
                    rooms[nr][nc] = rooms[r][c] + 1;
                    q.push_back((nr, nc));
                }
            }
        }
    }
}

#[cfg(test)]
mod tests_lc286 {
    use super::{Solution, INF};

    #[test]
    fn basic() {
        let mut rooms = vec![
            vec![INF, -1, 0, INF],
            vec![INF, INF, INF, -1],
            vec![INF, -1, INF, -1],
            vec![0, -1, INF, INF],
        ];
        Solution::walls_and_gates(&mut rooms);
        assert_eq!(rooms, vec![
            vec![3, -1, 0, 1],
            vec![2,  2, 1, -1],
            vec![1, -1, 2, -1],
            vec![0, -1, 3,  4],
        ]);
    }

    #[test]
    fn no_gates() {
        let mut rooms = vec![vec![INF, INF], vec![INF, INF]];
        Solution::walls_and_gates(&mut rooms);
        // All rooms remain INF — no gates to propagate from
        assert!(rooms.iter().flatten().all(|&v| v == INF));
    }
}
```

**Complexity:** O(m·n) time and space.

**Rust notes:** `rooms[nr][nc] = rooms[r][c] + 1` — since `rooms[r][c]` is at most `INF - 1` when we propagate (we never enqueue walls), overflow is not a concern in practice. Using `rooms[r][c] + 1` is safe here; production code could use `.saturating_add(1)`.

---

## 11 — Course Schedule (LC #207)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` courses and a list of `[a, b]` prerequisites (must take `b` before `a`), determine if all courses can be finished (i.e., no cycle in the directed graph).

### Key Insight

Topological sort using Kahn's algorithm (BFS + in-degree). If all nodes are processed, no cycle exists. Alternatively, DFS with three colors (unvisited / visiting / visited) detects back edges.

### Solution

```rust
use std::collections::VecDeque;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn can_finish(num_courses: i32, prerequisites: Vec<Vec<i32>>) -> bool {
        let n = num_courses as usize;
        let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
        let mut indegree = vec![0usize; n];

        for prereq in &prerequisites {
            let (a, b) = (prereq[0] as usize, prereq[1] as usize);
            adj[b].push(a);
            indegree[a] += 1;
        }

        let mut q: VecDeque<usize> = (0..n).filter(|&i| indegree[i] == 0).collect();
        let mut processed = 0;

        while let Some(course) = q.pop_front() {
            processed += 1;
            for &next in &adj[course] {
                indegree[next] -= 1;
                if indegree[next] == 0 { q.push_back(next); }
            }
        }
        processed == n
    }
}

#[cfg(test)]
mod tests_lc207 {
    use super::Solution;

    #[test]
    fn possible() {
        assert!(Solution::can_finish(2, vec![vec![1, 0]]));
    }

    #[test]
    fn cycle() {
        assert!(!Solution::can_finish(2, vec![vec![1, 0], vec![0, 1]]));
    }

    #[test]
    fn no_prereqs() {
        assert!(Solution::can_finish(5, vec![]));
    }

    #[test]
    fn longer_chain() {
        assert!(Solution::can_finish(4, vec![vec![1,0],vec![2,1],vec![3,2]]));
    }
}
```

**Complexity:** O(V + E) time and space.

**Rust notes:** `(0..n).filter(|&i| indegree[i] == 0).collect::<VecDeque<usize>>()` seeds the BFS queue in one line using iterator chaining. The closure receives `&i` (a reference to `usize`) and the `&` in the pattern destructures it to `i: usize`. `indegree[next] -= 1` is safe because in-degree only reaches zero after all prerequisite edges are processed.

**Approach 2 — DFS with Three-Color Cycle Detection (O(V+E) time, O(V) space).** Mark each node as unvisited (0), currently on the DFS stack (1 — back edge would mean cycle), or fully processed (2). A back edge to a node still on the stack means a cycle exists.

```rust
#[allow(dead_code)]
struct Solution2;

impl Solution2 {
    pub fn can_finish(num_courses: i32, prerequisites: Vec<Vec<i32>>) -> bool {
        let n = num_courses as usize;
        let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
        for prereq in &prerequisites {
            adj[prereq[1] as usize].push(prereq[0] as usize);
        }
        // 0 = unvisited, 1 = on stack (visiting), 2 = done
        let mut color = vec![0u8; n];
        for start in 0..n {
            if color[start] == 0 && Self::has_cycle(&adj, start, &mut color) {
                return false;
            }
        }
        true
    }

    fn has_cycle(adj: &[Vec<usize>], node: usize, color: &mut Vec<u8>) -> bool {
        color[node] = 1; // mark as visiting
        for &next in &adj[node] {
            if color[next] == 1 { return true; }  // back edge → cycle
            if color[next] == 0 && Self::has_cycle(adj, next, color) { return true; }
        }
        color[node] = 2; // fully processed
        false
    }
}

#[cfg(test)]
mod tests_lc207_dfs {
    use super::Solution2;

    #[test]
    fn dfs_possible() {
        assert!(Solution2::can_finish(2, vec![vec![1, 0]]));
    }

    #[test]
    fn dfs_cycle() {
        assert!(!Solution2::can_finish(2, vec![vec![1, 0], vec![0, 1]]));
    }

    #[test]
    fn dfs_no_prereqs() {
        assert!(Solution2::can_finish(5, vec![]));
    }

    #[test]
    fn dfs_longer_chain() {
        assert!(Solution2::can_finish(4, vec![vec![1,0],vec![2,1],vec![3,2]]));
    }
}
```

> **Java vs Rust:** The DFS coloring is a direct translation — `u8` array in Rust, `int[]` or `byte[]` in Java. The `color[node] = 1` / `color[node] = 2` assignments and recursion structure are identical. Rust adds no meaningful overhead here; the difference is purely syntactic.

---

## 12 — Course Schedule II (LC #210)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Same as #207 but return the ordering in which courses should be taken. Return an empty vector if a cycle exists.

### Key Insight

Kahn's algorithm again — append each dequeued node to the result. The BFS order gives a valid topological ordering.

### Solution

```rust
use std::collections::VecDeque;

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_order(num_courses: i32, prerequisites: Vec<Vec<i32>>) -> Vec<i32> {
        let n = num_courses as usize;
        let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
        let mut indegree = vec![0usize; n];

        for prereq in &prerequisites {
            let (a, b) = (prereq[0] as usize, prereq[1] as usize);
            adj[b].push(a);
            indegree[a] += 1;
        }

        let mut q: VecDeque<usize> = (0..n).filter(|&i| indegree[i] == 0).collect();
        let mut order: Vec<i32> = Vec::with_capacity(n);

        while let Some(course) = q.pop_front() {
            order.push(course as i32);
            for &next in &adj[course] {
                indegree[next] -= 1;
                if indegree[next] == 0 { q.push_back(next); }
            }
        }

        if order.len() == n { order } else { vec![] }
    }
}

#[cfg(test)]
mod tests_lc210 {
    use super::Solution;

    /// Verify a topological order is valid for the given prerequisites.
    fn is_valid_topo(order: &[i32], n: usize, prereqs: &[Vec<i32>]) -> bool {
        if order.len() != n { return false; }
        let mut pos = vec![0usize; n];
        for (i, &c) in order.iter().enumerate() { pos[c as usize] = i; }
        prereqs.iter().all(|e| pos[e[1] as usize] < pos[e[0] as usize])
    }

    #[test]
    fn two_courses() {
        let prereqs = vec![vec![1, 0]];
        let order = Solution::find_order(2, prereqs.clone());
        assert!(is_valid_topo(&order, 2, &prereqs));
    }

    #[test]
    fn four_courses() {
        let prereqs = vec![vec![1,0],vec![2,0],vec![3,1],vec![3,2]];
        let order = Solution::find_order(4, prereqs.clone());
        assert!(is_valid_topo(&order, 4, &prereqs));
    }

    #[test]
    fn cycle_returns_empty() {
        let order = Solution::find_order(2, vec![vec![0,1],vec![1,0]]);
        assert!(order.is_empty());
    }
}
```

**Complexity:** O(V + E) time and space.

**Rust notes:** Topological orderings are not unique. Instead of `assert_eq!` against one hardcoded vector, the helper `is_valid_topo` builds a position map and verifies all prerequisites are satisfied — more robust and closer to how correctness should be checked in production.

---

## Part 3 — Union-Find Problems

---

## 13 — Redundant Connection (LC #684)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

Given a graph built from `n` nodes and `n` edges (one edge makes it not a tree), find the redundant edge — the last edge that creates a cycle.

### Key Insight

Process edges in order; use Union-Find. The first edge where both endpoints are already in the same component creates the cycle.

### Solution

```rust
// UnionFind defined in the chapter intro; reproduced here for self-contained compilation.
struct UnionFind {
    parent: Vec<usize>, rank: Vec<usize>, count: usize,
}
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    /// Returns false when x and y were already in the same component (cycle detected).
    fn union(&mut self, x: usize, y: usize) -> bool {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return false; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
        true
    }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_redundant_connection(edges: Vec<Vec<i32>>) -> Vec<i32> {
        let n = edges.len();
        let mut uf = UnionFind::new(n + 1);
        for edge in edges {
            let (u, v) = (edge[0] as usize, edge[1] as usize);
            if !uf.union(u, v) { return vec![u as i32, v as i32]; }
        }
        vec![]
    }
}

#[cfg(test)]
mod tests_lc684 {
    use super::Solution;

    #[test]
    fn triangle() {
        assert_eq!(
            Solution::find_redundant_connection(vec![vec![1,2],vec![1,3],vec![2,3]]),
            vec![2, 3]
        );
    }

    #[test]
    fn chain_plus_one() {
        assert_eq!(
            Solution::find_redundant_connection(vec![vec![1,2],vec![2,3],vec![3,4],vec![1,4],vec![1,5]]),
            vec![1, 4]
        );
    }
}
```

**Complexity:** O(n · α(n)) ≈ O(n) with path compression and union by rank. Space O(n).

**Rust notes:** The recursive `find` with path compression requires a two-step assignment. `self.parent[x] = self.find(self.parent[x])` is not valid because `self.parent[x]` would be borrowed twice. The correct pattern: `let p = self.parent[x]; self.parent[x] = self.find(p);`.

---

## 14 — Number of Connected Components (LC #323)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` nodes (0 to n-1) and a list of undirected edges, return the number of connected components.

### Key Insight

Union-Find: start with `n` components. Each successful union decrements the count by one. The final `count` is the answer.

### Solution

```rust
// Same UnionFind struct as problems 13 and 15; union() returns bool and decrements count.
struct UnionFind {
    parent: Vec<usize>, rank: Vec<usize>, count: usize,
}
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) -> bool {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return false; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
        true
    }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn count_components(n: i32, edges: Vec<Vec<i32>>) -> i32 {
        let mut uf = UnionFind::new(n as usize);
        for e in edges {
            uf.union(e[0] as usize, e[1] as usize);
        }
        uf.count as i32
    }
}

#[cfg(test)]
mod tests_lc323 {
    use super::Solution;

    #[test]
    fn two_components() {
        assert_eq!(Solution::count_components(5, vec![vec![0,1],vec![1,2],vec![3,4]]), 2);
    }

    #[test]
    fn one_component() {
        assert_eq!(Solution::count_components(5, vec![vec![0,1],vec![1,2],vec![2,3],vec![3,4]]), 1);
    }

    #[test]
    fn no_edges() {
        assert_eq!(Solution::count_components(4, vec![]), 4);
    }
}
```

**Complexity:** O(n · α(n)) time. Space O(n).

**Rust notes:** Embedding `count` in the `UnionFind` struct avoids scanning the parent array afterward. `count` is decremented only when a real union happens (roots differ). This is the cleanest way to track components.

---

## 15 — Graph Valid Tree (LC #261)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` nodes and a list of undirected edges, return `true` if the edges form a valid tree (connected, acyclic).

### Key Insight

A valid tree on `n` nodes has exactly `n - 1` edges and is fully connected. Check both conditions: `edges.len() == n - 1` and Union-Find gives exactly one component.

### Solution

```rust
// Same UnionFind struct as problems 13 and 14.
struct UnionFind {
    parent: Vec<usize>, rank: Vec<usize>, count: usize,
}
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) -> bool {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return false; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
        true
    }
}

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn valid_tree(n: i32, edges: Vec<Vec<i32>>) -> bool {
        let n = n as usize;
        if edges.len() != n.saturating_sub(1) { return false; }
        let mut uf = UnionFind::new(n);
        for e in &edges {
            if !uf.union(e[0] as usize, e[1] as usize) { return false; }
        }
        uf.count == 1
    }
}

#[cfg(test)]
mod tests_lc261 {
    use super::Solution;

    #[test]
    fn valid() {
        assert!(Solution::valid_tree(5, vec![vec![0,1],vec![0,2],vec![0,3],vec![1,4]]));
    }

    #[test]
    fn cycle() {
        assert!(!Solution::valid_tree(5, vec![vec![0,1],vec![1,2],vec![2,3],vec![1,3],vec![1,4]]));
    }

    #[test]
    fn single_node() {
        assert!(Solution::valid_tree(1, vec![]));
    }

    #[test]
    fn disconnected() {
        assert!(!Solution::valid_tree(4, vec![vec![0,1],vec![2,3]]));
    }
}
```

**Complexity:** O(n · α(n)) time. Space O(n).

**Rust notes:** The early exit `edges.len() != n - 1` would underflow when `n == 0` because `n` is `usize`. Use `n.saturating_sub(1)` to safely compute `n - 1` for unsigned integers. For `n == 1`, `saturating_sub(1)` returns `0`, and `edges.len() == 0` is the correct condition.

---

## 16 — Word Ladder (LC #127)

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `beginWord`, `endWord`, and a `wordList`, return the length of the shortest transformation sequence from `beginWord` to `endWord`, changing one letter at a time (each intermediate word must be in `wordList`). Return `0` if no such sequence exists.

### Key Insight

BFS on the implicit word graph. To avoid O(n²) neighbor detection, preprocess words into pattern buckets: `"hot"` maps to `"*ot"`, `"h*t"`, `"ho*"`. Each pattern groups words that differ by one letter at that position.

### Solution

```rust
use std::collections::{HashMap, HashSet, VecDeque};

#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn ladder_length(begin_word: String, end_word: String, word_list: Vec<String>) -> i32 {
        let word_set: HashSet<&str> = word_list.iter().map(|s| s.as_str()).collect();
        if !word_set.contains(end_word.as_str()) { return 0; }

        // Build pattern → [word] map
        let all_words: Vec<&str> = std::iter::once(begin_word.as_str())
            .chain(word_list.iter().map(|s| s.as_str()))
            .collect();

        let mut patterns: HashMap<String, Vec<&str>> = HashMap::new();
        for &word in &all_words {
            for i in 0..word.len() {
                let pattern = format!("{}*{}", &word[..i], &word[i+1..]);
                patterns.entry(pattern).or_default().push(word);
            }
        }

        let mut visited: HashSet<&str> = HashSet::new();
        let mut q: VecDeque<(&str, i32)> = VecDeque::new();
        q.push_back((begin_word.as_str(), 1));
        visited.insert(begin_word.as_str());

        while let Some((word, steps)) = q.pop_front() {
            if word == end_word.as_str() { return steps; }
            for i in 0..word.len() {
                let pattern = format!("{}*{}", &word[..i], &word[i+1..]);
                if let Some(neighbors) = patterns.get(&pattern) {
                    for &neighbor in neighbors {
                        if !visited.contains(neighbor) {
                            visited.insert(neighbor);
                            q.push_back((neighbor, steps + 1));
                        }
                    }
                }
            }
        }
        0
    }
}

#[cfg(test)]
mod tests_lc127 {
    use super::Solution;

    fn ws(v: &[&str]) -> Vec<String> { v.iter().map(|s| s.to_string()).collect() }

    #[test]
    fn classic() {
        assert_eq!(
            Solution::ladder_length("hit".to_string(), "cog".to_string(),
                ws(&["hot","dot","dog","lot","log","cog"])),
            5
        );
    }

    #[test]
    fn no_path() {
        assert_eq!(
            Solution::ladder_length("hit".to_string(), "cog".to_string(),
                ws(&["hot","dot","dog","lot","log"])),
            0
        );
    }

    #[test]
    fn one_step() {
        assert_eq!(
            Solution::ladder_length("a".to_string(), "b".to_string(), ws(&["b"])),
            2
        );
    }
}
```

**Complexity:** O(M² · N) where M = word length, N = word list size. Each word generates M patterns, each pattern lookup is O(M) string comparison. Space O(M² · N) for the pattern map.

**Rust notes:** `std::iter::once(begin_word.as_str()).chain(...)` prepends `beginWord` to the word list without mutation or a separate insert. String slicing `&word[..i]` is safe here because all words are ASCII (the problem constraint guarantees lowercase English letters). For non-ASCII, use `word.char_indices()` instead.

---

## 📝 Review Notes

*A third-person critical review written after drafting, covering fact-checking, code correctness, and completeness.*

### Review Summary

The chapter covers all sixteen required problems from the task specification: three trie problems (LC #208, #211, #212) and thirteen graph problems (LC #200, #133, #695, #417, #130, #994, #286, #207, #210, #684, #323, #261, #127). All `#[cfg(test)]` blocks include at least two test cases covering normal and edge inputs. Named structs (`Trie`, `WordDictionary`) are used for data-structure design problems; `struct Solution` is used for function-style problems — matching the precedent from lc03.

### Fact-Check: Trie Solutions

- **LC #208:** `get_or_insert_with(Box::default)` — `Box::default()` calls `TrieNode::default()` which derives `Default`, initialising `children` to `[None; 26]` and `is_end` to `false`. Confirmed valid. `as_deref()` on `Option<Box<T>>` yields `Option<&T>`. Confirmed.
- **LC #211:** `chars[0]` and `&chars[1..]` on `&[u8]` — valid slice indexing; panics only on empty slice, which is guarded by the `is_empty()` check at the top. Confirmed.
- **LC #212:** `let Some(child) = node.children[idx].as_ref() else { return; }` — let-else stable since Rust 1.65, within the 1.85+ target. `visited[r][c] = false` after DFS resets the cell for other paths. Confirmed correct.

### Fact-Check: Graph Solutions

- **LC #200 / #695 / #130:** `r + 1 < rows` instead of `r < rows - 1` — safe for `usize`; the latter underflows when `rows == 0`. Confirmed.
- **LC #133:** `.borrow().neighbors.clone()` — clones the `Vec<Rc<_>>`, bumping each `Rc` refcount. The borrow guard drops before `borrow_mut()` is called. Confirmed no double-borrow panic.
- **LC #417:** Two BFS passes with separate `visited` grids. The condition `h[nr][nc] >= h[r][c]` implements the reverse-flow semantics correctly. Confirmed.
- **LC #994:** `for _ in 0..q.len()` captures the layer size before new elements are appended. This is correct BFS level-by-level iteration. Confirmed.
- **LC #286:** `rooms[r][c] + 1` — since gates are `0` and rooms start at `INF`, the maximum propagated distance is `m + n - 2` which is far below `i32::MAX`. No overflow risk in practice. Confirmed.
- **LC #207 / #210:** Kahn's BFS with `indegree[next] -= 1` — `usize` subtraction is safe because `indegree` only reaches zero after the last prerequisite is processed (no underflow). Confirmed. `is_valid_topo` helper verifies ordering correctness without depending on a specific traversal order. Confirmed robust.
- **LC #684:** `let p = self.parent[x]; self.parent[x] = self.find(p)` — the two-step pattern avoids simultaneous mutable borrow of `self`. Confirmed required.
- **LC #261:** `n.saturating_sub(1)` — prevents `usize` underflow when `n == 0`. For `n == 1`, returns `0`, correctly requiring `edges.len() == 0`. Confirmed.
- **LC #127:** `format!("{}*{}", &word[..i], &word[i+1..])` — generates a wildcard pattern by replacing the i-th character. Slicing is safe for ASCII inputs (LC constraint). `std::iter::once(...).chain(...)` correctly prepends `beginWord`. Confirmed.

### Issues Table

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 1 | OK | LC #208: `[Option<Box<TrieNode>>; 26]` requires `Default` derive — present via `#[derive(Default)]` | Correct |
| 2 | OK | LC #212: W2TrieNode defined separately from LC #208/211 nodes to avoid name collision in the same file | Addressed with prefixed struct names |
| 3 | Fixed | LC #210: `is_valid_topo` was originally defined at module scope (dead code in non-test builds) | Moved inside `mod tests_lc210` |
| 4 | Fixed | LC #684/#323/#261: UnionFind redeclared three times with different names | Unified to single `UnionFind` struct per code block with `count` field and `union() -> bool` |
| 5 | OK | LC #210: Topological order is non-unique; `is_valid_topo` validates correctness without hardcoding one expected sequence | Correct approach |
| 6 | Low | LC #286: `rooms[r][c] + 1` could theoretically overflow if `INF == i32::MAX` and a gate is adjacent to a room that already has value `INF - 1`. In practice BFS only propagates to cells with value `INF`, so distance never reaches `i32::MAX`. | No fix needed; documented |
| 7 | OK | LC #130: `to_str` helper in tests uses `.iter().collect::<String>()` on `&Vec<char>` — `char` implements `FromIterator` for `String`. Confirmed. | Correct |
| 8 | OK | LC #127: `word_list.iter().map(|s| s.as_str())` borrows the input `Vec<String>` — lifetime of `&str` tied to `word_list` which outlives the function body. Confirmed valid. | Correct |
| 9 | Low | Line count: ~1660 lines — above the 900-1200 target. Justified by 16 problems (vs. ~9-14 in prior chapters), each with complete runnable tests, complexity analysis, and per-problem Rust notes. | Accepted |
