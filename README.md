# The Rust Cookbook for Java Developers

> A practical companion to [The Rust Programming Language](https://doc.rust-lang.org/book/) book, packed with runnable code examples, real-world patterns, and Java↔Rust comparisons.

**Rust Edition:** 2024 (default since Rust 1.85, Feb 2025)  
**Target audience:** Java developers transitioning to Rust  
**Approach:** Every topic from the official book — with more code, more examples, and honest reviews.

---

## How This Book Works

Each chapter:
1. **Mirrors the official book's structure** so you can read them in tandem
2. **Adds practical examples** the official book skips — real-world patterns, not just toy demos
3. **Includes Java comparisons** at every point where the mental model differs
4. **Ends with a critical review section** — third-person fact-checking of every claim and code example

---

## Table of Contents

| # | Chapter | Key Topics | File |
|---|---------|-----------|------|
| 1 | [Getting Started](chapters/ch01-getting-started.md) | rustup, rustc, Cargo, project setup, printing | ch01 |
| 2 | [Programming a Guessing Game](chapters/ch02-guessing-game.md) | Progressive project, rand, match, loop, Result | ch02 |
| 3 | [Common Programming Concepts](chapters/ch03-common-concepts.md) | Variables, types, functions, control flow | ch03 |
| 4 | [Understanding Ownership](chapters/ch04-ownership.md) | Ownership, borrowing, slices, String vs &str | ch04 |
| 5 | [Structs](chapters/ch05-structs.md) | Named/tuple/unit structs, methods, impl, derive | ch05 |
| 6 | [Enums and Pattern Matching](chapters/ch06-enums-patterns.md) | Enums with data, Option<T>, match, if let | ch06 |
| 7 | [Packages, Crates, and Modules](chapters/ch07-modules.md) | mod, pub, use, paths, file layout | ch07 |
| 8 | [Common Collections](chapters/ch08-collections.md) | Vec<T>, String, HashMap, BTreeMap, HashSet | ch08 |
| 9 | [Error Handling](chapters/ch09-error-handling.md) | panic!, Result, ?, custom errors, anyhow, thiserror | ch09 |
| 10 | [Generic Types, Traits, and Lifetimes](chapters/ch10-generics-traits-lifetimes.md) | Generics, trait bounds, impl Trait, dyn, lifetimes | ch10 |
| 11 | [Writing Automated Tests](chapters/ch11-testing.md) | #[test], assert!, integration tests, doc tests | ch11 |
| 12 | [An I/O Project: CLI Program](chapters/ch12-cli-project.md) | minigrep, env args, files, lib/main split, clap | ch12 |
| 13 | [Closures and Iterators](chapters/ch13-closures-iterators.md) | Fn/FnMut/FnOnce, map/filter/fold, custom Iterator | ch13 |
| 14 | [More About Cargo](chapters/ch14-cargo.md) | Profiles, publishing, workspaces, features, tools | ch14 |
| 15 | [Smart Pointers](chapters/ch15-smart-pointers.md) | Box, Deref, Drop, Rc, RefCell, Weak, Arc | ch15 |
| 16 | [Fearless Concurrency](chapters/ch16-concurrency.md) | Threads, channels, Mutex, Arc, atomics, Send/Sync | ch16 |
| 17 | [Async Programming](chapters/ch17-async.md) | async/await, tokio, spawn, join!, select!, streams | ch17 |
| 18 | [OOP Features](chapters/ch18-oop.md) | Traits vs inheritance, dyn Trait, design patterns | ch18 |
| 19 | [Patterns and Matching](chapters/ch19-patterns.md) | Destructuring, guards, @-bindings, if let chains | ch19 |
| 20 | [Advanced Features](chapters/ch20-advanced.md) | Unsafe, advanced traits, macros, fn pointers | ch20 |
| 21 | [Multithreaded Web Server](chapters/ch21-web-server.md) | TCP server, ThreadPool, graceful shutdown, tokio alt | ch21 |

---

## Learning Paths

### Complete Beginner (never used Rust)
Ch1 → Ch2 → Ch3 → Ch4 → Ch5 → Ch6 → Ch7 → Ch8 → Ch9 → Ch10 → Ch11

### Intermediate (knows Rust basics, wants practical patterns)
Ch7 → Ch9 → Ch10 → Ch13 → Ch15 → Ch16 → Ch17 → Ch18

### Concurrency and Async Focus
Ch16 → Ch17 → Ch21

### Building CLI Tools
Ch3 → Ch9 → Ch12 → Ch14

### Systems Programming
Ch4 → Ch15 → Ch16 → Ch20 → Ch21

---

## Quick Reference: Java → Rust Mental Model

| Java concept | Rust equivalent | Notes |
|---|---|---|
| `final` variable | `let` (immutable by default) | In Rust, mutability is opt-in with `let mut` |
| `null` | `Option<T>` | Compiler forces you to handle `None` |
| Checked exception | `Result<T, E>` | Propagate with `?` operator |
| `try/catch` | `match` on `Result` | Or `.unwrap_or()`, `anyhow` |
| Garbage collector | Ownership + Drop | Zero-cost, deterministic |
| `interface` | `trait` | Traits are more powerful (default impls, blanket impls) |
| `extends` | No direct equivalent | Use trait composition, `Box<dyn Trait>` |
| `synchronized` | `Mutex<T>`, `Arc<T>` | Data-centric, not method-centric |
| `volatile` | `AtomicBool`, `AtomicUsize` | Explicit ordering control |
| `abstract class` | Trait with default methods | |
| `instanceof` | `match` on enum / `Any::downcast_ref` | Enums are preferred |
| `ArrayList<T>` | `Vec<T>` | |
| `HashMap<K,V>` | `HashMap<K,V>` | Similar API |
| `Optional<T>` | `Option<T>` | Built into the language |
| `Stream<T>` | `impl Iterator<Item=T>` | Lazy, zero-cost |
| Lambda `x -> x+1` | Closure `\|x\| x + 1` | |
| `CompletableFuture` | `async fn` + `.await` | Needs a runtime (tokio) |
| `Thread` | `thread::spawn` | |
| `ExecutorService` | `ThreadPool` (manual) or rayon | |

---

## Setting Up Your Environment

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh

# Verify installation
rustc --version && cargo --version

# Essential tools
rustup component add clippy rustfmt rust-analyzer

# Create your first project
cargo new my_project
cd my_project
cargo run
```

### Recommended VS Code Extensions
- `rust-analyzer` — language server (auto-complete, error highlighting)
- `Even Better TOML` — Cargo.toml support
- `CodeLLDB` — debugger

### Recommended IntelliJ Plugin
- `Rust` plugin by JetBrains (IntelliJ IDEA / CLion)

---

## Key Cargo Commands Cheatsheet

```bash
cargo new <name>          # new binary project
cargo new <name> --lib    # new library project
cargo build               # debug build
cargo build --release     # release build (optimized)
cargo run                 # build + run
cargo run -- <args>       # pass args to your program
cargo test                # run all tests
cargo test <name>         # run tests matching name
cargo check               # type-check without compiling
cargo clippy              # linter (highly recommended)
cargo fmt                 # auto-format code
cargo doc --open          # build and view documentation
cargo add <crate>         # add a dependency
cargo tree                # visualize dependency tree
cargo update              # update dependencies
```

---

## About This Cookbook

This cookbook was written for Walmart developers transitioning from Java to Rust. Every chapter:

- Was drafted with reference to the official Rust book content
- Underwent a third-person critical review pass
- Had all code examples fact-checked
- Had all issues found during review documented and addressed

The official book ([doc.rust-lang.org/book](https://doc.rust-lang.org/book)) remains the authoritative reference. Use this cookbook alongside it for more examples and Java-oriented context.

---

---

## Part II: LeetCode Problem Solving in Rust

> Blind 75 · NeetCode 150 · LeetCode Study Plans — all solved in idiomatic Rust

### Why solve LeetCode in Rust?
- Rust's type system forces you to write correct solutions upfront
- The borrow checker eliminates entire classes of bugs (no null pointer in trees, no dangling slice)
- Zero-cost abstractions mean your iterator-based solutions are as fast as raw loops
- Excellent preparation for Rust systems programming roles

### LeetCode Chapter Overview

| # | Chapter | Problems Covered | Patterns | File |
|---|---------|-----------------|---------|------|
| LC-01 | [Arrays & Hashing](leetcode/lc01-arrays-hashing.md) | LC #217, #242, #1, #49, #347, #238, #36, #271, #128 | HashSet, HashMap entry API, bucket sort | lc01 |
| LC-02 | [Two Pointers & Sliding Window](leetcode/lc02-two-pointers-sliding-window.md) | LC #125, #167, #15, #11, #42, #121, #3, #424, #567, #76, #239 | Two-pointer, frequency map, VecDeque | lc02 |
| LC-03 | [Stack & Binary Search](leetcode/lc03-stack-binary-search.md) | LC #20, #155, #150, #22, #739, #853, #84, #704, #74, #875, #153, #33, #981, #4 | Vec as stack, monotonic stack, binary search templates | lc03 |
| LC-04 | [Linked Lists](leetcode/lc04-linked-lists.md) | LC #206, #21, #143, #19, #138, #2, #287, #146, #23, #25 | `Option<Box<ListNode>>`, Floyd's cycle, LRU | lc04 |
| LC-05 | [Trees](leetcode/lc05-trees.md) | LC #226, #104, #543, #110, #100, #572, #235, #102, #199, #1448, #98, #230, #105, #124, #297 | DFS/BFS, `Rc<RefCell<>>`, inorder/preorder | lc05 |
| LC-06 | [Heap & Backtracking](leetcode/lc06-heap-backtracking.md) | LC #703, #1046, #973, #215, #621, #355, #295, #78, #39, #40, #46, #90, #79, #131, #17, #51 | `BinaryHeap<Reverse<T>>`, backtrack push/pop | lc06 |
| LC-07 | [Tries & Graphs](leetcode/lc07-tries-graphs.md) | LC #208, #211, #212, #200, #133, #695, #417, #130, #994, #207, #210, #684, #323, #261, #127 | Trie nodes, BFS/DFS on grids, Union-Find | lc07 |
| LC-08 | [Dynamic Programming](leetcode/lc08-dynamic-programming.md) | LC #70, #746, #198, #213, #5, #647, #91, #322, #152, #139, #300, #416, #62, #1143, #309, #518, #494, #97, #329, #115, #72, #312, #10 | 1-D DP, 2-D DP, state + transition | lc08 |
| LC-09 | [Greedy, Intervals, Math & Bits](leetcode/lc09-greedy-intervals-math-bits.md) | LC #53, #55, #45, #134, #846, #1899, #763, #678, #57, #56, #435, #252, #253, #2285, #48, #54, #73, #202, #66, #50, #43, #2013, #136, #191, #338, #190, #268, #371, #7 | Kadane, interval sort/merge, XOR tricks | lc09 |
| LC-10 | [Binary Search Deep Dive](leetcode/lc10-binary-search-deep-dive.md) | LC #374, #702, #278, #69, #34, #154, #81, #162, #436, #1011, #410, #1552, #1283, #2064, #240, #378 | T1/T2/T3 templates, answer-space search | lc10 |
| LC-11 | [DFS Deep Dive](leetcode/lc11-dfs-deep-dive.md) | LC #200, #695, #733, #130, #417, #329, #323, #261, #207, #210, #797, #332, #113, #257, #129, #114, #79, #212, #301, #282 | 6 DFS templates, grid/graph/tree/backtrack | lc11 |
| LC-12 | [BFS Deep Dive](leetcode/lc12-bfs-deep-dive.md) | LC #102, #103, #111, #127, #126, #1306, #752, #994, #542, #1091, #909, #133, #1971, #1926, #1345, #815, #934, #675 | Level/multi-source/bidirectional BFS | lc12 |
| LC-13 | [Advanced Graphs](leetcode/lc13-advanced-graphs.md) | LC #743, #1631, #787, #778, #1334, #1514, #269, #444, #310, #1136, #547, #721, #684, #827, #990, #1584, #1168, #1192, #1976, #1129 | Dijkstra, Bellman-Ford, Floyd-Warshall, Kruskal, Prim, Tarjan | lc13 |
| LC-14a | [Advanced DP Part 1](leetcode/lc14-advanced-dp-part1.md) | LC #516, #1039, #1000, #312, #664, #1547, #546, #1312, #877, #1140, #1406, #1510, #375, #486, #464, #233, #357, #902, #1012, #2376 | Interval DP, Game Theory, Digit DP | lc14a |
| LC-14b | [Advanced DP Part 2](leetcode/lc14-advanced-dp-part2.md) | LC #337, #968, #124, #1372, #2246, #1519, #526, #1986, #1494, #2305, #847, #1125, #1434, #943, #309, #188, #123, #1911, #2826 | Tree DP, Bitmask DP, State Machine DP | lc14b |
| LC-14c | [Advanced DP Part 3](leetcode/lc14-advanced-dp-part3.md) | LC #10, #44, #1458, #1092, #1062, #718, #1035, #837, #688, #576, #1230, #808, #1278, #1335, #410, #813, #879, #956, #1049, #474, #1066, #1981 | String DP, Probability DP, D&C Optimization, Advanced Knapsack | lc14c |
| LC-14d | [Advanced DP Part 4](leetcode/lc14-advanced-dp-part4.md) | LC #1696, #1425, #2944, #862, #907, #2212, #1994, #2572, #329, #1857, #2050, #1697, #188, #2218, #2209, #2370, #2707, #2463, #2809, #3041 | Monotone Stack DP, SOS DP, DAG DP, Grandmaster Problems | lc14d |

### Problems by Difficulty

| Difficulty | Count | Chapters |
|---|---|---|
| Easy | ~55 | LC-01, LC-02, LC-03, LC-04, LC-05, LC-09, LC-10, LC-11, LC-12 |
| Medium | ~130 | All chapters |
| Hard | ~30 | LC-03 (#84, #4), LC-05 (#124, #297), LC-06 (#295, #51), LC-07 (#212, #127), LC-08 (#312, #10, #329, #72, #115), LC-09 (#2285), LC-10 (#410), LC-11 (#282, #301, #332), LC-12 (#126, #675), LC-13 (#1192, #827, #778) |

### Key Rust Patterns for Competitive Programming

```rust
// Min-heap (most common: top-K problems)
use std::collections::BinaryHeap;
use std::cmp::Reverse;
let mut min_heap: BinaryHeap<Reverse<i32>> = BinaryHeap::new();
min_heap.push(Reverse(5));
let min = min_heap.pop().unwrap().0;

// Frequency map with entry API
use std::collections::HashMap;
let mut freq: HashMap<i32, i32> = HashMap::new();
*freq.entry(val).or_insert(0) += 1;

// VecDeque as monotonic deque
use std::collections::VecDeque;
let mut deque: VecDeque<usize> = VecDeque::new();

// Binary search template (safe mid, no overflow)
let mid = left + (right - left) / 2;

// Overflow-safe integer ops
x.checked_add(y)         // Option<i32>
x.saturating_add(y)      // clamps to MAX
x.wrapping_add(y)        // wraps around

// Vec as stack
let mut stack: Vec<i32> = Vec::new();
stack.push(1);
let top = stack.last();       // peek (Option<&T>)
let popped = stack.pop();     // pop (Option<T>)

// Char operations
let bytes = s.as_bytes();     // for ASCII problems (fastest)
let chars: Vec<char> = s.chars().collect();  // for Unicode
```

### DFS / BFS / Graph Algorithm Quick Reference

```rust
// ── DFS on grid (recursive, in-place marking) ──────────────────────────
fn dfs(grid: &mut Vec<Vec<char>>, r: i32, c: i32) {
    let rows = grid.len() as i32;
    let cols = grid[0].len() as i32;
    if r < 0 || r >= rows || c < 0 || c >= cols { return; }
    if grid[r as usize][c as usize] != '1' { return; }
    grid[r as usize][c as usize] = '0';   // mark visited
    for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
        dfs(grid, r + dr, c + dc);
    }
}

// ── BFS on grid (VecDeque, level-aware) ────────────────────────────────
use std::collections::VecDeque;
const DIRS: [(i32,i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
let mut queue: VecDeque<(i32,i32)> = VecDeque::new();
let mut dist = vec![vec![i32::MAX; cols]; rows];
dist[sr][sc] = 0;
queue.push_back((sr as i32, sc as i32));
while let Some((r, c)) = queue.pop_front() {
    for (dr, dc) in DIRS {
        let nr = r + dr; let nc = c + dc;
        if nr < 0 || nr >= rows as i32 || nc < 0 || nc >= cols as i32 { continue; }
        let (nr, nc) = (nr as usize, nc as usize);
        if dist[nr][nc] == i32::MAX {
            dist[nr][nc] = dist[r as usize][c as usize] + 1;
            queue.push_back((nr as i32, nc as i32));
        }
    }
}

// ── Dijkstra (min-heap, weighted graph) ────────────────────────────────
use std::collections::BinaryHeap;
use std::cmp::Reverse;
let mut dist = vec![u64::MAX; n];
let mut heap: BinaryHeap<Reverse<(u64, usize)>> = BinaryHeap::new();
dist[src] = 0;
heap.push(Reverse((0, src)));
while let Some(Reverse((cost, u))) = heap.pop() {
    if cost > dist[u] { continue; }   // stale entry
    for &(v, w) in &adj[u] {
        let next = cost + w;
        if next < dist[v] { dist[v] = next; heap.push(Reverse((next, v))); }
    }
}

// ── Union-Find (path compression + union by rank) ──────────────────────
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
impl UnionFind {
    fn new(n: usize) -> Self { Self { parent: (0..n).collect(), rank: vec![0;n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { self.parent[x] = self.find(self.parent[x]); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) -> bool {
        let (px, py) = (self.find(x), self.find(y));
        if px == py { return false; }
        match self.rank[px].cmp(&self.rank[py]) {
            std::cmp::Ordering::Less => self.parent[px] = py,
            std::cmp::Ordering::Greater => self.parent[py] = px,
            std::cmp::Ordering::Equal => { self.parent[py] = px; self.rank[px] += 1; }
        }
        self.count -= 1; true
    }
}
```

### LeetCode Node Types in Rust

```rust
// Linked List (as used on LeetCode)
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}

// Binary Tree (as used on LeetCode)
use std::rc::Rc;
use std::cell::RefCell;
#[derive(Debug, PartialEq, Eq)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<Rc<RefCell<TreeNode>>>,
    pub right: Option<Rc<RefCell<TreeNode>>>,
}
```

---

## Part III: LeetCode Problem Solving in Java

> Same problems as Part II — Java 17+ solutions for side-by-side comparison

### Why the Java companion chapters?

For teams migrating Java → Rust, seeing the same algorithm expressed in both languages is the fastest path to fluency. Each Java chapter:
- Solves **the same problems** as its Rust counterpart
- Uses **Java 17+ idioms** (records, var, switch expressions)
- Highlights **where Java and Rust diverge** (ownership, generics, heap direction)
- Follows the same **critical review rules** (third-person review, no bare `assert`, `throw new AssertionError`)

### Java Chapter Overview

| # | Chapter | Problems Covered | Key Java Patterns | File |
|---|---------|-----------------|------------------|------|
| JLC-01 | [Arrays & Hashing (Java)](leetcode-java/lc01-arrays-hashing-java.md) | LC #217, #242, #1, #49, #347, #238, #36, #271, #128 | `HashMap`, sorted-string key for anagrams, `LinkedHashMap` | jlc01 |
| JLC-02 | [Two Pointers & Sliding Window (Java)](leetcode-java/lc02-two-pointers-sliding-window-java.md) | LC #125, #167, #15, #11, #42, #121, #3, #424, #567, #76, #239 | `ArrayDeque` as sliding window deque, Integer boxing trap | jlc02 |
| JLC-03 | [Stack & Binary Search (Java)](leetcode-java/lc03-stack-binary-search-java.md) | LC #20, #155, #150, #22, #739, #853, #84, #704, #74, #875, #153, #33, #981, #4 | `Deque<T> = new ArrayDeque<>()`, Java 17 records for TimeMap | jlc03 |
| JLC-04 | [Linked Lists (Java)](leetcode-java/lc04-linked-lists-java.md) | LC #206, #21, #143, #19, #138, #2, #287, #146, #23, #25 | `LinkedHashMap` for LRU, `PriorityQueue<ListNode>` for merge-k | jlc04 |
| JLC-05 | [Trees (Java)](leetcode-java/lc05-trees-java.md) | LC #226, #104, #543, #110, #100, #572, #235, #102, #199, #1448, #98, #230, #105, #124, #297 | `TreeNode` helpers, `ArrayDeque` BFS, simple object refs vs `Rc<RefCell<>>` | jlc05 |
| JLC-06 | [Heap & Backtracking (Java)](leetcode-java/lc06-heap-backtracking-java.md) | LC #703, #1046, #973, #215, #621, #355, #295, #78, #39, #40, #46, #90, #79, #131, #17, #51 | `PriorityQueue` min/max, `Collections.reverseOrder()`, backtrack `remove()` | jlc06 |
| JLC-07 | [Tries & Graphs (Java)](leetcode-java/lc07-tries-graphs-java.md) | LC #208, #211, #212, #200, #133, #695, #417, #130, #994, #207, #210, #684, #323, #261, #127 | `TrieNode[26]`, `UnionFind` with path compression, `ArrayDeque` BFS | jlc07 |
| JLC-08 | [Dynamic Programming (Java)](leetcode-java/lc08-dynamic-programming-java.md) | LC #70, #746, #198, #213, #5, #647, #91, #322, #152, #139, #300, #416, #62, #1143, #309, #518, #494, #97, #329, #115, #72, #312, #10 | `int[]` / `long[]` dp, `HashMap` memo, `record` as memo key | jlc08 |
| JLC-09 | [Greedy, Intervals, Math & Bits (Java)](leetcode-java/lc09-greedy-intervals-math-bits-java.md) | LC #53, #55, #45, #134, #846, #1899, #763, #678, #57, #56, #435, #252, #253, #2285, #48, #54, #73, #202, #66, #50, #43, #2013, #136, #191, #338, #190, #268, #371, #7 | `Integer.compare` in sort, `Integer.bitCount()`, `>>>` unsigned shift | jlc09 |
| JLC-10 | [Binary Search Deep Dive (Java)](leetcode-java/lc10-binary-search-deep-dive-java.md) | LC #704, #374, #702, #278, #69, #34, #154, #81, #162, #436, #875, #1011, #410, #1552, #1283, #2064, #240, #378 | `lo + (hi-lo)/2` overflow-safe mid, answer-space BS, `record` for index | jlc10 |
| JLC-11 | [DFS Deep Dive (Java)](leetcode-java/lc11-dfs-deep-dive-java.md) | LC #200, #695, #733, #130, #417, #329, #323, #261, #207, #210, #797, #332, #113, #257, #129, #114, #79, #212, #301, #282 | `ArrayDeque` iterative DFS, board restore, `static class TreeNode` | jlc11 |
| JLC-12 | [BFS Deep Dive (Java)](leetcode-java/lc12-bfs-deep-dive-java.md) | LC #102, #103, #111, #127, #126, #1306, #752, #994, #542, #1091, #909, #133, #1971, #1926, #1345, #815, #934, #675 | `ArrayDeque` queue/deque, mark-at-enqueue, level-order snapshot | jlc12 |
| JLC-13 | [Advanced Graphs (Java)](leetcode-java/lc13-advanced-graphs-java.md) | LC #743, #1631, #787, #778, #1334, #1514, #269, #444, #310, #1136, #547, #721, #684, #827, #990, #1584, #1168, #1192, #1976, #1129 | Dijkstra `PriorityQueue`, `MAX_VALUE/2` infinity, Kahn's + DFS topo | jlc13 |
| JLC-14a | [Advanced DP Part 1 (Java)](leetcode-java/lc14-advanced-dp-part1-java.md) | LC #516, #1039, #1000, #312, #664, #1547, #546, #1312, #877, #1140, #1406, #1510, #375, #486, #464, #233, #357, #902, #1012, #2376 | Interval DP, Game Theory DP, Digit DP with `long` | jlc14a |
| JLC-14b | [Advanced DP Part 2 (Java)](leetcode-java/lc14-advanced-dp-part2-java.md) | LC #337, #968, #124, #1372, #2246, #1519, #526, #1986, #1494, #2305, #847, #1125, #1434, #943, #309, #188, #123, #1911, #2826 | Tree DP (`int[2]`), `1L<<j` bitmask, State Machine DP | jlc14b |
| JLC-14c | [Advanced DP Part 3 (Java)](leetcode-java/lc14-advanced-dp-part3-java.md) | LC #10, #44, #1458, #1092, #1062, #718, #1035, #837, #688, #576, #1230, #808, #1278, #1335, #410, #813, #879, #956, #1049, #474, #1066, #1981 | String DP, Probability `double[][]`, D&C Optimization | jlc14c |
| JLC-14d | [Advanced DP Part 4 (Java)](leetcode-java/lc14-advanced-dp-part4-java.md) | LC #1696, #1425, #2944, #862, #907, #2212, #1994, #2572, #329, #1857, #2050, #1697, #188, #2218, #2209, #2370, #2707, #2463, #2809, #3041 | Monotone Deque DP, SOS/Bitmask DP, DAG DP, Grandmaster Problems | jlc14d |

### Java Quick Reference: LeetCode Patterns

```java
// Min-heap (default PriorityQueue)
PriorityQueue<Integer> minHeap = new PriorityQueue<>();

// Max-heap
PriorityQueue<Integer> maxHeap = new PriorityQueue<>(Collections.reverseOrder());

// Heap of arrays (by first element, ascending)
PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));

// ArrayDeque as stack (never use Stack class)
Deque<Integer> stack = new ArrayDeque<>();
stack.push(1);          // addFirst
int top = stack.peek(); // peekFirst
int val = stack.pop();  // removeFirst

// ArrayDeque as queue
Deque<Integer> queue = new ArrayDeque<>();
queue.offer(1);         // addLast
int front = queue.poll(); // removeFirst

// Binary search — overflow-safe mid
int lo = 0, hi = n - 1;
while (lo <= hi) {
    int mid = lo + (hi - lo) / 2;
    if (check(mid)) hi = mid - 1;
    else lo = mid + 1;
}

// Frequency map
Map<Integer, Integer> freq = new HashMap<>();
freq.merge(val, 1, Integer::sum);

// Sorted intervals
Arrays.sort(intervals, (a, b) -> Integer.compare(a[0], b[0]));

// Bit operations
Integer.bitCount(n)               // count set bits
Integer.numberOfTrailingZeros(n)  // index of lowest set bit
n & (n - 1)                       // clear lowest set bit
n >>> 1                           // unsigned right shift (important!)
```

### Java vs Rust: Key Algorithm Differences

| Topic | Java | Rust |
|-------|------|------|
| Heap direction | `PriorityQueue` = **min-heap** | `BinaryHeap` = **max-heap** |
| Max-heap | `Collections.reverseOrder()` | `BinaryHeap<T>` directly |
| Min-heap | Default | `BinaryHeap<Reverse<T>>` |
| Stack | `Deque<T> = new ArrayDeque<>()` | `Vec<T>` |
| Queue | `Deque<T> = new ArrayDeque<>()` | `VecDeque<T>` |
| Tree nodes | Simple `TreeNode left, right` | `Option<Rc<RefCell<TreeNode>>>` |
| Linked lists | Simple `ListNode next` | `Option<Box<ListNode>>` |
| Unsigned shift | `>>>` operator | All shift on unsigned types |
| Overflow | Silent (use `Math.addExact` or `long`) | Debug panic, release wrap |
| HashMap key | Any object with `hashCode`/`equals` | Must implement `Hash + Eq` |
| Infinity sentinel | `Integer.MAX_VALUE / 2` | `i32::MAX / 2` or `u64::MAX` |

---

*Rust 2024 Edition · Java 17+ · Rust 1.85+ · May 2026*
