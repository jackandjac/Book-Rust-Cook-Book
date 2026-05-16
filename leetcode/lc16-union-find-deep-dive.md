# Chapter 16: Union-Find (DSU) Deep Dive

> **Chapter goal:** Master Union-Find / Disjoint Set Union (DSU) in every interview-relevant form.
> Every code block is self-contained and compiles with `rustc` on Rust 1.85+ (2024 edition).
> Audience: Java developers who know the algorithm and want the Rust idioms.

**Note on problems already covered.** LC #684 (Redundant Connection), #323 (Number of Connected
Components), and #261 (Graph Valid Tree) appear in **Chapter 7 (lc07-tries-graphs.md)** under
"Part 3 — Union-Find Problems." They are not repeated here. Chapter 7 also contains the first
DSU implementation reference; the canonical template below is an expanded version of it.

**Java quick-reference**

| Java pattern | Rust equivalent |
|---|---|
| `int[] parent = new int[n]` | `parent: Vec<usize>` |
| Recursive path compression with index capture | `let p = self.parent[x]; self.parent[x] = self.find(p);` (two-step to satisfy borrow checker) |
| `HashMap<String, Integer>` for string-keyed DSU | `HashMap<String, usize>` as id table; DSU over `usize` ids |
| `float[]` weights for weighted DSU | `weight: Vec<f64>` — multiply on path compress, divide on union |
| `DSU` as inner class in Java | `struct UnionFind` at module level; pass `&mut uf` to helper fns |
| `n` after unions = component count | `uf.count` field decremented in `union` |

---

## Canonical DSU Template

The two variants below cover 95% of problems. Inline a tailored copy (with `size`, `weight`, etc.)
when a problem needs it — each problem section calls out what changed.

### Standard DSU (path compression + union by rank)

```rust
struct UnionFind {
    parent: Vec<usize>,
    rank:   Vec<usize>,
    count:  usize, // number of disjoint components
}

impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind {
            parent: (0..n).collect(),
            rank:   vec![0; n],
            count:  n,
        }
    }

    // Path compression: flatten tree toward root.
    // Two-step assignment avoids simultaneous mutable borrows of self.
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x {
            let p = self.parent[x];
            self.parent[x] = self.find(p);
        }
        self.parent[x]
    }

    // Union by rank. Returns true if the two sets were distinct (merge happened).
    fn union(&mut self, x: usize, y: usize) -> bool {
        let rx = self.find(x);
        let ry = self.find(y);
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

fn main() {
    let mut uf = UnionFind::new(5);
    assert!(uf.union(0, 1));
    assert!(uf.union(1, 2));
    assert!(!uf.union(0, 2)); // already connected
    assert_eq!(uf.count, 3);  // components: {0,1,2}, {3}, {4}
    assert_eq!(uf.find(0), uf.find(2));
}
```

### DSU with component size (needed for LC #695, #827)

```rust
struct UnionFindSized {
    parent: Vec<usize>,
    rank:   Vec<usize>,
    size:   Vec<usize>, // size of each component (valid at root)
}

impl UnionFindSized {
    fn new(n: usize) -> Self {
        UnionFindSized {
            parent: (0..n).collect(),
            rank:   vec![0; n],
            size:   vec![1; n],
        }
    }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x {
            let p = self.parent[x];
            self.parent[x] = self.find(p);
        }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) -> usize {
        let rx = self.find(x);
        let ry = self.find(y);
        if rx == ry { return self.size[rx]; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => { self.parent[rx] = ry; self.size[ry] += self.size[rx]; return self.size[ry]; }
            std::cmp::Ordering::Greater => { self.parent[ry] = rx; self.size[rx] += self.size[ry]; return self.size[rx]; }
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; self.size[rx] += self.size[ry]; return self.size[rx]; }
        }
    }
}

fn main() {
    let mut uf = UnionFindSized::new(4);
    assert_eq!(uf.union(0, 1), 2);
    assert_eq!(uf.union(0, 2), 3);
}
```

---

## Part 1 — Basic DSU

---

## LC547. Number of Provinces

**Problem.** Given an `n x n` adjacency matrix `is_connected` where `is_connected[i][j] == 1` means
cities `i` and `j` are directly connected, return the total number of provinces (connected components).

**Key insight.** Straightforward DSU application: iterate the upper triangle of the matrix, call
`union(i, j)` for each `1` entry, return `uf.count`.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
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
        self.count -= 1; true
    }
}

struct Solution;
impl Solution {
    pub fn find_circle_num(is_connected: Vec<Vec<i32>>) -> i32 {
        let n = is_connected.len();
        let mut uf = UnionFind::new(n);
        for i in 0..n {
            for j in (i + 1)..n {
                if is_connected[i][j] == 1 { uf.union(i, j); }
            }
        }
        uf.count as i32
    }
}

fn main() {
    assert_eq!(Solution::find_circle_num(vec![vec![1,1,0],vec![1,1,0],vec![0,0,1]]), 2);
    assert_eq!(Solution::find_circle_num(vec![vec![1,0,0],vec![0,1,0],vec![0,0,1]]), 3);
}
```

**Complexity.** Time O(n²·α(n)), Space O(n). α is the inverse Ackermann — effectively O(1).

> **Java comparison.** In Java you'd write `int[] parent = new int[n]` and loop to initialize.
> In Rust, `(0..n).collect()` is idiomatic and doesn't require a separate loop.

**Approach 2 — DFS (O(n²) time, O(n) space).** The adjacency-matrix graph can be traversed with a plain DFS instead. Count the number of DFS invocations that start on an unvisited node — each invocation discovers one complete province. This is conceptually simpler and avoids the DSU implementation; the DSU is preferred when you need incremental updates or cycle detection.

```rust
struct SolutionDFS;

impl SolutionDFS {
    pub fn find_circle_num(is_connected: Vec<Vec<i32>>) -> i32 {
        let n = is_connected.len();
        let mut visited = vec![false; n];
        let mut count = 0;

        for start in 0..n {
            if !visited[start] {
                count += 1;
                Self::dfs(&is_connected, start, &mut visited);
            }
        }
        count
    }

    fn dfs(g: &Vec<Vec<i32>>, node: usize, visited: &mut Vec<bool>) {
        visited[node] = true;
        for next in 0..g.len() {
            if g[node][next] == 1 && !visited[next] {
                Self::dfs(g, next, visited);
            }
        }
    }
}

fn main() {
    assert_eq!(SolutionDFS::find_circle_num(vec![vec![1,1,0],vec![1,1,0],vec![0,0,1]]), 2);
    assert_eq!(SolutionDFS::find_circle_num(vec![vec![1,0,0],vec![0,1,0],vec![0,0,1]]), 3);
    assert_eq!(SolutionDFS::find_circle_num(vec![vec![1,1,1],vec![1,1,1],vec![1,1,1]]), 1);
    println!("LC547 DFS OK");
}
```

**When to use which:** DSU shines when you add edges incrementally (online queries) or need to detect cycles; DFS is simpler for a single static adjacency matrix.

---

## LC990. Satisfiability of Equality Equations

**Problem.** Given a list of equations like `"a==b"` and `"b!=c"`, return `true` if all equations
can be satisfied simultaneously.

**Key insight.** Two-pass: first union all `==` pairs, then check every `!=` pair — if the two
variables share the same root, return `false`.

```rust
struct UnionFind { parent: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect() } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx != ry { self.parent[rx] = ry; }
    }
}

struct Solution;
impl Solution {
    pub fn equations_possible(equations: Vec<String>) -> bool {
        let mut uf = UnionFind::new(26);
        let idx = |c: u8| (c - b'a') as usize;
        // Pass 1: union all == pairs
        for eq in &equations {
            let b = eq.as_bytes();
            if b[1] == b'=' { uf.union(idx(b[0]), idx(b[3])); }
        }
        // Pass 2: check != pairs
        for eq in &equations {
            let b = eq.as_bytes();
            if b[1] == b'!' && uf.find(idx(b[0])) == uf.find(idx(b[3])) {
                return false;
            }
        }
        true
    }
}

fn main() {
    assert!(Solution::equations_possible(vec!["a==b".to_string(),"b==c".to_string(),"a==c".to_string()]));
    assert!(!Solution::equations_possible(vec!["a==b".to_string(),"b!=c".to_string(),"c==a".to_string()]));
    assert!(Solution::equations_possible(vec!["a!=b".to_string(),"b!=a".to_string()]));
}
```

**Complexity.** Time O(26·α(26)) ≈ O(1), Space O(26) = O(1).

---

## LC128. Longest Consecutive Sequence

**Problem.** Given an unsorted array of integers, find the length of the longest consecutive elements
sequence. Must run in O(n).

**Key insight.** Use a `HashSet`. For each number `n`, if `n-1` is NOT in the set, `n` starts a new
streak. Walk forward counting `n+1`, `n+2`, … updating the max. DSU is an alternative; the HashSet
approach is simpler and O(n).

```rust
use std::collections::HashSet;

struct Solution;
impl Solution {
    pub fn longest_consecutive(nums: Vec<i32>) -> i32 {
        let set: HashSet<i32> = nums.into_iter().collect();
        let mut best = 0;
        for &n in &set {
            if !set.contains(&(n - 1)) { // n is a sequence start
                let mut len = 1;
                while set.contains(&(n + len as i32)) { len += 1; }
                best = best.max(len);
            }
        }
        best
    }
}

fn main() {
    assert_eq!(Solution::longest_consecutive(vec![100,4,200,1,3,2]), 4);
    assert_eq!(Solution::longest_consecutive(vec![0,3,7,2,5,8,4,6,0,1]), 9);
    assert_eq!(Solution::longest_consecutive(vec![]), 0);
}
```

**Complexity.** Time O(n), Space O(n).

> **Java comparison.** In Java you'd use `HashSet<Integer>`. The `contains(&(n - 1))` call in Rust
> takes `&i32`, which matches the stored `i32` — no explicit boxing needed unlike Java's autoboxing.

---

## Part 2 — Grid DSU

---

## LC200. Number of Islands

**Problem.** Given an `m x n` grid of `'1'` (land) and `'0'` (water), return the number of islands.
An island is a group of `'1'`s connected horizontally or vertically.

**Key insight.** Flatten the grid to a 1-D index: cell `(r, c)` → `r * cols + c`. Union each `'1'`
cell with its `'1'` neighbors. The answer is the number of components that sit on a `'1'` cell.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: 0 } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
    }
}

struct Solution;
impl Solution {
    pub fn num_islands(grid: Vec<Vec<char>>) -> i32 {
        if grid.is_empty() { return 0; }
        let (rows, cols) = (grid.len(), grid[0].len());
        let mut uf = UnionFind::new(rows * cols);
        for r in 0..rows {
            for c in 0..cols {
                if grid[r][c] == '1' {
                    uf.count += 1;
                    let id = r * cols + c;
                    if r > 0 && grid[r-1][c] == '1' { uf.union(id, (r-1)*cols+c); }
                    if c > 0 && grid[r][c-1] == '1' { uf.union(id, r*cols+(c-1)); }
                }
            }
        }
        uf.count as i32
    }
}

fn main() {
    let g1 = vec![
        vec!['1','1','1','1','0'],
        vec!['1','1','0','1','0'],
        vec!['1','1','0','0','0'],
        vec!['0','0','0','0','0'],
    ];
    assert_eq!(Solution::num_islands(g1), 1);
    let g2 = vec![
        vec!['1','1','0','0','0'],
        vec!['1','1','0','0','0'],
        vec!['0','0','1','0','0'],
        vec!['0','0','0','1','1'],
    ];
    assert_eq!(Solution::num_islands(g2), 3);
}
```

**Complexity.** Time O(m·n·α(m·n)), Space O(m·n).

> **Java comparison.** Java DSU typically uses `int[] parent`; Rust uses `Vec<usize>`. Note `count`
> starts at `0` and increments when a `'1'` cell is discovered — this avoids counting water cells.

---

## LC695. Max Area of Island

**Problem.** Same grid as LC #200 but return the maximum area of an island (number of `'1'` cells in
the largest connected component). Return `0` if no island exists.

**Key insight.** Use `UnionFindSized` — the `size` field tracked at each root gives the component
area. After all unions, scan for the largest `size` among `'1'` cells.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, size: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind { parent: (0..n).collect(), rank: vec![0; n], size: vec![1; n] }
    }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => { self.parent[rx] = ry; self.size[ry] += self.size[rx]; }
            std::cmp::Ordering::Greater => { self.parent[ry] = rx; self.size[rx] += self.size[ry]; }
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; self.size[rx] += self.size[ry]; }
        }
    }
}

struct Solution;
impl Solution {
    pub fn max_area_of_island(grid: Vec<Vec<i32>>) -> i32 {
        if grid.is_empty() { return 0; }
        let (rows, cols) = (grid.len(), grid[0].len());
        let mut uf = UnionFind::new(rows * cols);
        for r in 0..rows {
            for c in 0..cols {
                if grid[r][c] == 1 {
                    let id = r * cols + c;
                    if r > 0 && grid[r-1][c] == 1 { uf.union(id, (r-1)*cols+c); }
                    if c > 0 && grid[r][c-1] == 1 { uf.union(id, r*cols+(c-1)); }
                }
            }
        }
        let mut best = 0;
        for r in 0..rows {
            for c in 0..cols {
                if grid[r][c] == 1 {
                    let root = uf.find(r * cols + c);
                    best = best.max(uf.size[root]);
                }
            }
        }
        best as i32
    }
}

fn main() {
    let g = vec![
        vec![0,0,1,0,0,0,0,1,0,0,0,0,0],
        vec![0,0,0,0,0,0,0,1,1,1,0,0,0],
        vec![0,1,1,0,1,0,0,0,0,0,0,0,0],
        vec![0,1,0,0,1,1,0,0,1,0,1,0,0],
        vec![0,1,0,0,1,1,0,0,1,1,1,0,0],
        vec![0,0,0,0,0,0,0,0,0,0,1,0,0],
        vec![0,0,0,0,0,0,0,1,1,1,0,0,0],
        vec![0,0,0,0,0,0,0,1,1,0,0,0,0],
    ];
    assert_eq!(Solution::max_area_of_island(g), 6);
    assert_eq!(Solution::max_area_of_island(vec![vec![0,0,0,0,0,0,0,0]]), 0);
}
```

**Complexity.** Time O(m·n·α(m·n)), Space O(m·n).

---

## LC130. Surrounded Regions

**Problem.** Given an `m x n` board of `'X'` and `'O'`, capture all regions of `'O'` surrounded by
`'X'` on all four sides. Flip captured `'O'` to `'X'`; `'O'`s on or connected to the border stay.

**Key insight.** Use a **virtual boundary node** (index `m*n`). Union every border `'O'` and every
`'O'` adjacent to a border-connected `'O'` with this virtual node. After all unions, any `'O'` not
in the same component as the virtual node is surrounded — flip it to `'X'`.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
    }
    fn connected(&mut self, x: usize, y: usize) -> bool { self.find(x) == self.find(y) }
}

struct Solution;
impl Solution {
    pub fn solve(board: &mut Vec<Vec<char>>) {
        if board.is_empty() { return; }
        let (rows, cols) = (board.len(), board[0].len());
        let boundary = rows * cols; // virtual node
        let mut uf = UnionFind::new(boundary + 1);
        let id = |r: usize, c: usize| r * cols + c;
        for r in 0..rows {
            for c in 0..cols {
                if board[r][c] == 'O' {
                    let cur = id(r, c);
                    if r == 0 || r == rows-1 || c == 0 || c == cols-1 {
                        uf.union(cur, boundary);
                    }
                    if r > 0 && board[r-1][c] == 'O' { uf.union(cur, id(r-1, c)); }
                    if c > 0 && board[r][c-1] == 'O' { uf.union(cur, id(r, c-1)); }
                }
            }
        }
        for r in 0..rows {
            for c in 0..cols {
                if board[r][c] == 'O' && !uf.connected(id(r, c), boundary) {
                    board[r][c] = 'X';
                }
            }
        }
    }
}

fn main() {
    let mut board = vec![
        vec!['X','X','X','X'],
        vec!['X','O','O','X'],
        vec!['X','X','O','X'],
        vec!['X','O','X','X'],
    ];
    Solution::solve(&mut board);
    assert_eq!(board[1][1], 'X');
    assert_eq!(board[3][1], 'O'); // border-connected, not flipped
}
```

**Complexity.** Time O(m·n·α(m·n)), Space O(m·n).

---

## LC827. Making A Large Island

**Problem.** Given an `n x n` binary grid, you may change at most one `0` to `1`. Return the size of
the largest island after the change.

**Key insight.** Two passes. Pass 1: label each `'1'`-island with a component id and record its size.
Pass 2: for each `0`, sum the sizes of its distinct neighboring components + 1; track the maximum.
Handle the edge case where there are no `0`s (the entire grid is already one island).

```rust
use std::collections::HashSet;

struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, size: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind { parent: (0..n).collect(), rank: vec![0; n], size: vec![1; n] }
    }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => { self.parent[rx] = ry; self.size[ry] += self.size[rx]; }
            std::cmp::Ordering::Greater => { self.parent[ry] = rx; self.size[rx] += self.size[ry]; }
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; self.size[rx] += self.size[ry]; }
        }
    }
}

struct Solution;
impl Solution {
    pub fn largest_island(grid: Vec<Vec<i32>>) -> i32 {
        let n = grid.len();
        let mut uf = UnionFind::new(n * n);
        let id = |r: usize, c: usize| r * n + c;
        // Pass 1: build islands
        for r in 0..n {
            for c in 0..n {
                if grid[r][c] == 1 {
                    if r > 0 && grid[r-1][c] == 1 { uf.union(id(r, c), id(r-1, c)); }
                    if c > 0 && grid[r][c-1] == 1 { uf.union(id(r, c), id(r, c-1)); }
                }
            }
        }
        let dirs: [(i32, i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
        let mut best = 0;
        let mut has_zero = false;
        // Pass 2: try flipping each 0
        for r in 0..n {
            for c in 0..n {
                if grid[r][c] == 0 {
                    has_zero = true;
                    let mut seen: HashSet<usize> = HashSet::new();
                    let mut gain = 1usize;
                    for &(dr, dc) in &dirs {
                        let nr = r as i32 + dr;
                        let nc = c as i32 + dc;
                        if nr >= 0 && nr < n as i32 && nc >= 0 && nc < n as i32 {
                            let nr = nr as usize; let nc = nc as usize;
                            if grid[nr][nc] == 1 {
                                let root = uf.find(id(nr, nc));
                                if seen.insert(root) { gain += uf.size[root]; }
                            }
                        }
                    }
                    best = best.max(gain);
                }
            }
        }
        if !has_zero {
            // entire grid is land
            best = n * n;
        }
        best as i32
    }
}

fn main() {
    assert_eq!(Solution::largest_island(vec![vec![1,0],vec![0,1]]), 3);
    assert_eq!(Solution::largest_island(vec![vec![1,1],vec![1,0]]), 4);
    assert_eq!(Solution::largest_island(vec![vec![1,1],vec![1,1]]), 4);
}
```

**Complexity.** Time O(n²·α(n²)), Space O(n²).

---

## LC1559. Detect Cycles in 2D Grid

**Problem.** Given a 2D grid of characters, return `true` if any cycle exists where all cells in the
cycle contain the same character. A cycle must be of length 4 or more (no trivial 2-cell back-edges).

**Key insight.** Iterate cells left-to-right, top-to-bottom. For each cell, look left and up. If the
neighbor has the same character and is already in the same component, a cycle exists. The ordering
guarantees we never revisit an already-processed back-edge as a "new" union.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
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
        true
    }
}

struct Solution;
impl Solution {
    pub fn contains_cycle(grid: Vec<Vec<char>>) -> bool {
        let (rows, cols) = (grid.len(), grid[0].len());
        let mut uf = UnionFind::new(rows * cols);
        let id = |r: usize, c: usize| r * cols + c;
        for r in 0..rows {
            for c in 0..cols {
                let ch = grid[r][c];
                if r > 0 && grid[r-1][c] == ch {
                    if !uf.union(id(r, c), id(r-1, c)) { return true; }
                }
                if c > 0 && grid[r][c-1] == ch {
                    if !uf.union(id(r, c), id(r, c-1)) { return true; }
                }
            }
        }
        false
    }
}

fn main() {
    let g1 = vec![vec!['a','a','a','a'],vec!['a','b','b','a'],vec!['a','b','b','a'],vec!['a','a','a','a']];
    assert!(Solution::contains_cycle(g1));
    let g2 = vec![vec!['c','c','c','a'],vec!['c','d','c','c'],vec!['c','c','e','c'],vec!['f','c','c','c']];
    assert!(Solution::contains_cycle(g2));
    let g3 = vec![vec!['a','b','b'],vec!['b','z','b'],vec!['b','b','a']];
    assert!(!Solution::contains_cycle(g3));
}
```

**Complexity.** Time O(m·n·α(m·n)), Space O(m·n).

---

## LC959. Regions Cut By Slashes

**Problem.** An `n x n` grid of `' '`, `'/'`, and `'\'` characters. Each cell is subdivided into
4 triangles (top=0, right=1, bottom=2, left=3). Return the number of regions.

**Key insight.** Each cell contributes 4 triangles. Slash `'/'` splits top-right from bottom-left;
backslash `'\'` splits top-left from bottom-right. Adjacent cells' triangles that touch must be
unioned. Count remaining components.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
    }
}

struct Solution;
impl Solution {
    pub fn regions_by_slashes(grid: Vec<String>) -> i32 {
        let n = grid.len();
        // Each cell (r,c) → 4 nodes: r*n*4 + c*4 + triangle
        // triangle: 0=top, 1=right, 2=bottom, 3=left
        let mut uf = UnionFind::new(n * n * 4);
        let node = |r: usize, c: usize, t: usize| (r * n + c) * 4 + t;
        for r in 0..n {
            let row: Vec<u8> = grid[r].bytes().collect();
            for c in 0..n {
                let ch = row[c];
                // Within-cell unions based on slash type
                match ch {
                    b'/' => {
                        uf.union(node(r,c,0), node(r,c,3)); // top-left half
                        uf.union(node(r,c,1), node(r,c,2)); // bottom-right half
                    }
                    b'\\' => {
                        uf.union(node(r,c,0), node(r,c,1)); // top-right half
                        uf.union(node(r,c,2), node(r,c,3)); // bottom-left half
                    }
                    _ => {
                        uf.union(node(r,c,0), node(r,c,1));
                        uf.union(node(r,c,1), node(r,c,2));
                        uf.union(node(r,c,2), node(r,c,3));
                    }
                }
                // Cross-cell unions: right neighbor and bottom neighbor
                if c + 1 < n { uf.union(node(r,c,1), node(r,c+1,3)); }
                if r + 1 < n { uf.union(node(r,c,2), node(r+1,c,0)); }
            }
        }
        uf.count as i32
    }
}

fn main() {
    assert_eq!(Solution::regions_by_slashes(vec![" /".to_string(),"/ ".to_string()]), 2);
    assert_eq!(Solution::regions_by_slashes(vec![" /".to_string(),"  ".to_string()]), 1);
    assert_eq!(Solution::regions_by_slashes(vec!["/\\".to_string(),"\\/".to_string()]), 5);
}
```

**Complexity.** Time O(n²·α(n²)), Space O(n²).

---

## Part 3 — String-Key DSU

---

## LC721. Accounts Merge

**Problem.** Each account is `[name, email1, email2, ...]`. Merge accounts that share an email.
Return merged accounts sorted; each account's emails sorted; name first.

**Key insight.** Map every email to an integer id. For each account, union all email ids with the
first email's id. Then group email ids by root component and output sorted lists.

```rust
use std::collections::HashMap;

struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
    }
}

struct Solution;
impl Solution {
    pub fn accounts_merge(accounts: Vec<Vec<String>>) -> Vec<Vec<String>> {
        let mut email_to_id: HashMap<String, usize> = HashMap::new();
        let mut email_to_name: HashMap<String, String> = HashMap::new();
        let mut id = 0usize;
        // Assign ids
        for account in &accounts {
            let name = &account[0];
            for email in account.iter().skip(1) {
                if !email_to_id.contains_key(email) {
                    email_to_id.insert(email.clone(), id);
                    email_to_name.insert(email.clone(), name.clone());
                    id += 1;
                }
            }
        }
        let mut uf = UnionFind::new(id);
        // Union emails within each account
        for account in &accounts {
            let first_id = email_to_id[&account[1]];
            for email in account.iter().skip(2) {
                uf.union(first_id, email_to_id[email]);
            }
        }
        // Group emails by root
        let mut root_to_emails: HashMap<usize, Vec<String>> = HashMap::new();
        for (email, &eid) in &email_to_id {
            root_to_emails
                .entry(uf.find(eid))
                .or_default()
                .push(email.clone());
        }
        let mut result: Vec<Vec<String>> = root_to_emails
            .values_mut()
            .map(|emails| {
                emails.sort_unstable();
                let name = email_to_name[&emails[0]].clone();
                let mut v = vec![name];
                v.extend(emails.iter().cloned());
                v
            })
            .collect();
        result.sort_unstable_by(|a, b| a[0].cmp(&b[0]).then(a[1].cmp(&b[1])));
        result
    }
}

fn main() {
    let accounts = vec![
        vec!["John","johnsmith@mail.com","john_newyork@mail.com"].iter().map(|s| s.to_string()).collect::<Vec<_>>(),
        vec!["John","johnsmith@mail.com","john00@mail.com"].iter().map(|s| s.to_string()).collect::<Vec<_>>(),
        vec!["Mary","mary@mail.com"].iter().map(|s| s.to_string()).collect::<Vec<_>>(),
        vec!["John","johnnybravo@mail.com"].iter().map(|s| s.to_string()).collect::<Vec<_>>(),
    ];
    let merged = Solution::accounts_merge(accounts);
    // The two John accounts with shared email should merge
    assert!(merged.iter().any(|a| a.len() == 4 && a[0] == "John"));
    assert_eq!(merged.len(), 3);
}
```

**Complexity.** Time O(E·α(E)·log E) where E = total emails, Space O(E).

> **Java comparison.** Java's `Map<String, Integer>` maps to `HashMap<String, usize>`. In Rust
> `or_default()` on a `HashMap` entry is the idiomatic equivalent of Java's
> `computeIfAbsent(key, k -> new ArrayList<>())`.

---

## LC839. Similar String Groups

**Problem.** Two strings are similar if they are equal or differ in exactly 2 positions (and swapping
those two characters makes them identical). Given a list of strings, return the number of similar
groups (connected components of the similarity relation).

**Key insight.** For each pair `(i, j)`, check similarity in O(|word|). Union if similar. The answer
is the number of remaining components.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
    }
}

struct Solution;
impl Solution {
    fn similar(a: &[u8], b: &[u8]) -> bool {
        let diffs: Vec<usize> = (0..a.len()).filter(|&i| a[i] != b[i]).collect();
        diffs.is_empty() || (diffs.len() == 2 && a[diffs[0]] == b[diffs[1]] && a[diffs[1]] == b[diffs[0]])
    }

    pub fn num_similar_groups(strs: Vec<String>) -> i32 {
        let n = strs.len();
        let bytes: Vec<&[u8]> = strs.iter().map(|s| s.as_bytes()).collect();
        let mut uf = UnionFind::new(n);
        for i in 0..n {
            for j in (i+1)..n {
                if Self::similar(bytes[i], bytes[j]) { uf.union(i, j); }
            }
        }
        uf.count as i32
    }
}

fn main() {
    let strs = vec!["tars","rats","arts","star"].iter().map(|s| s.to_string()).collect();
    assert_eq!(Solution::num_similar_groups(strs), 2);
    let strs2 = vec!["omv","ovm"].iter().map(|s| s.to_string()).collect();
    assert_eq!(Solution::num_similar_groups(strs2), 1);
}
```

**Complexity.** Time O(n²·L·α(n)) where L = word length, Space O(n).

---

## Part 4 — Weighted DSU

---

## LC399. Evaluate Division

**Problem.** Given equations like `A/B = k` and queries like `C/D = ?`, return the answers.
Return `-1.0` if a query is not computable.

**Key insight.** Weighted DSU where `weight[x]` stores the ratio `x / root(x)`. On `find`, path
compression multiplies weights along the path. On `union(x, y, ratio)`, set the parent's weight so
the ratio is consistent.

```rust
use std::collections::HashMap;

struct UnionFind {
    parent: Vec<usize>,
    weight: Vec<f64>, // weight[x] = value(x) / value(root(x))
}

impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind { parent: (0..n).collect(), weight: vec![1.0; n] }
    }
    // Returns (root, accumulated_weight = x / root)
    fn find(&mut self, x: usize) -> (usize, f64) {
        if self.parent[x] == x { return (x, 1.0); }
        let p = self.parent[x];
        let (root, pw) = self.find(p);
        self.parent[x] = root;
        self.weight[x] *= pw; // x/root = x/p * p/root
        (root, self.weight[x])
    }
    // Union with ratio: value(x) / value(y) = ratio
    fn union(&mut self, x: usize, y: usize, ratio: f64) {
        let (rx, wx) = self.find(x); // wx = x / rx
        let (ry, wy) = self.find(y); // wy = y / ry
        if rx == ry { return; }
        // We want: rx / ry = (x/wx) / (y/wy) * ratio = wy/wx * ratio
        self.parent[rx] = ry;
        self.weight[rx] = wy / wx * ratio;
    }
    fn query(&mut self, x: usize, y: usize) -> f64 {
        let (rx, wx) = self.find(x);
        let (ry, wy) = self.find(y);
        if rx != ry { return -1.0; }
        wx / wy // x/root ÷ y/root = x/y
    }
}

struct Solution;
impl Solution {
    pub fn calc_equation(
        equations: Vec<Vec<String>>,
        values: Vec<f64>,
        queries: Vec<Vec<String>>,
    ) -> Vec<f64> {
        let mut id_map: HashMap<String, usize> = HashMap::new();
        let mut next_id = 0usize;
        let mut get_id = |s: &str, map: &mut HashMap<String, usize>| {
            if !map.contains_key(s) { map.insert(s.to_string(), next_id); next_id += 1; }
            map[s]
        };
        // Assign ids
        for eq in &equations {
            get_id(&eq[0], &mut id_map);
            get_id(&eq[1], &mut id_map);
        }
        let n = next_id;
        let mut uf = UnionFind::new(n);
        for (eq, &val) in equations.iter().zip(values.iter()) {
            let a = id_map[&eq[0]];
            let b = id_map[&eq[1]];
            uf.union(a, b, val);
        }
        queries
            .iter()
            .map(|q| {
                match (id_map.get(&q[0]), id_map.get(&q[1])) {
                    (Some(&a), Some(&b)) => uf.query(a, b),
                    _ => -1.0,
                }
            })
            .collect()
    }
}

fn main() {
    let eqs = vec![vec!["a","b"],vec!["b","c"]].into_iter()
        .map(|v| v.iter().map(|s| s.to_string()).collect()).collect();
    let vals = vec![2.0, 3.0];
    let queries = vec![vec!["a","c"],vec!["b","a"],vec!["a","e"],vec!["a","a"],vec!["x","x"]]
        .into_iter().map(|v| v.iter().map(|s| s.to_string()).collect()).collect();
    let res = Solution::calc_equation(eqs, vals, queries);
    assert!((res[0] - 6.0).abs() < 1e-9);
    assert!((res[1] - 0.5).abs() < 1e-9);
    assert!((res[2] - (-1.0)).abs() < 1e-9);
    assert!((res[3] - 1.0).abs() < 1e-9);
    assert!((res[4] - (-1.0)).abs() < 1e-9);
}
```

**Complexity.** Time O((E+Q)·α(V)), Space O(V) where V = unique variables.

> **Java comparison.** Java would need a `double[]` for weights alongside `int[]` for parents.
> In Rust, two `Vec` fields in the same struct are natural. The borrow checker prevents calling
> `self.find()` while mutably borrowing `self.parent[x]` — the two-step `let (root, pw) = self.find(p);`
> pattern releases the borrow before the assignment.

---

## Part 5 — Virtual Node DSU

---

## LC947. Most Stones Removed with Same Row or Column

**Problem.** Stones on a 2D plane; a stone can be removed if another stone shares its row or column.
Return the maximum number of stones that can be removed.

**Key insight.** All stones in the same connected component (same row or column chain) can be reduced
to 1. Answer = `total_stones - components`. Map rows and columns to virtual nodes: row `r` → id `r`,
column `c` → id `n + c` (where `n` is a large offset beyond row ids). Union each stone's row-id with
its column-id.

```rust
use std::collections::{HashMap, HashSet};

struct UnionFind { parent: HashMap<usize, usize> }
impl UnionFind {
    fn new() -> Self { UnionFind { parent: HashMap::new() } }
    fn find(&mut self, x: usize) -> usize {
        let p = *self.parent.entry(x).or_insert(x);
        if p == x { return x; }
        let root = self.find(p);
        self.parent.insert(x, root);
        root
    }
    fn union(&mut self, x: usize, y: usize) {
        let rx = self.find(x);
        let ry = self.find(y);
        if rx != ry { self.parent.insert(rx, ry); }
    }
}

struct Solution;
impl Solution {
    pub fn remove_stones(stones: Vec<Vec<i32>>) -> i32 {
        let mut uf = UnionFind::new();
        let offset = 10001usize; // rows 0..10000, cols offset by 10001
        for stone in &stones {
            let r = stone[0] as usize;
            let c = stone[1] as usize + offset;
            uf.union(r, c);
        }
        // Count distinct roots among stone nodes
        let roots: HashSet<usize> = stones.iter()
            .map(|s| uf.find(s[0] as usize))
            .collect();
        (stones.len() - roots.len()) as i32
    }
}

fn main() {
    assert_eq!(Solution::remove_stones(vec![vec![0,0],vec![0,1],vec![1,0],vec![1,2],vec![2,1],vec![2,2]]), 5);
    assert_eq!(Solution::remove_stones(vec![vec![0,0],vec![0,2],vec![1,1],vec![2,0],vec![2,2]]), 3);
    assert_eq!(Solution::remove_stones(vec![vec![0,0]]), 0);
}
```

**Complexity.** Time O(N·α(N)), Space O(N + max_coord).

---

## LC765. Couples Holding Hands

**Problem.** `2n` people sit in `n` couples of seats (indices `0-1`, `2-3`, …). A couple is
`(2k, 2k+1)` for any `k`. Return the minimum number of swaps so every couple sits together.

**Key insight.** Each pair of seats is a "node." Model as a DSU over n seats-pairs. For each sofa
`i`, the two people sitting there belong to couples `p[0]/2` and `p[1]/2`. Union those two couple-ids.
Each cycle of length `k` in the union graph needs `k-1` swaps. Answer = `n - #components`.

```rust
struct UnionFind { parent: Vec<usize>, count: usize }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        self.parent[rx] = ry;
        self.count -= 1;
    }
}

struct Solution;
impl Solution {
    pub fn min_swaps_couples(row: Vec<i32>) -> i32 {
        let n = row.len() / 2;
        let mut uf = UnionFind::new(n);
        for i in 0..n {
            let a = row[2*i] as usize / 2;
            let b = row[2*i+1] as usize / 2;
            uf.union(a, b);
        }
        (n - uf.count) as i32
    }
}

fn main() {
    assert_eq!(Solution::min_swaps_couples(vec![0,2,1,3]), 1);
    assert_eq!(Solution::min_swaps_couples(vec![3,2,0,1]), 0);
    assert_eq!(Solution::min_swaps_couples(vec![5,4,2,6,3,1,0,7]), 2);
}
```

**Complexity.** Time O(n·α(n)), Space O(n).

> **Java comparison.** The key insight `person / 2 = couple_id` maps directly in both languages.
> In Java you'd write `row[2*i] / 2`. In Rust, integer division of `usize` is identical — no cast needed.

---

## Part 6 — MST / Kruskal-style DSU

---

## LC1584. Min Cost to Connect All Points

**Problem.** Given `n` points on a 2D plane, connect all points with minimum total Manhattan distance.
Return the minimum spanning tree cost.

**Key insight.** Kruskal's algorithm: generate all `n*(n-1)/2` edges with their costs, sort ascending,
greedily add edges that connect two different components.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
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
        true
    }
}

struct Solution;
impl Solution {
    pub fn min_cost_connect_points(points: Vec<Vec<i32>>) -> i32 {
        let n = points.len();
        let mut edges: Vec<(i32, usize, usize)> = Vec::new();
        for i in 0..n {
            for j in (i+1)..n {
                let cost = (points[i][0] - points[j][0]).abs() + (points[i][1] - points[j][1]).abs();
                edges.push((cost, i, j));
            }
        }
        edges.sort_unstable_by_key(|&(c, _, _)| c);
        let mut uf = UnionFind::new(n);
        let mut total = 0;
        let mut edges_used = 0;
        for (cost, u, v) in edges {
            if uf.union(u, v) {
                total += cost;
                edges_used += 1;
                if edges_used == n - 1 { break; }
            }
        }
        total
    }
}

fn main() {
    assert_eq!(Solution::min_cost_connect_points(vec![vec![0,0],vec![2,2],vec![3,10],vec![5,2],vec![7,0]]), 20);
    assert_eq!(Solution::min_cost_connect_points(vec![vec![3,12],vec![-2,5],vec![-4,1]]), 18);
    assert_eq!(Solution::min_cost_connect_points(vec![vec![0,0],vec![1,1],vec![1,0],vec![0,1]]), 3);
}
```

**Complexity.** Time O(n²·log n), Space O(n²).

---

## LC1101. Earliest Moment Everyone Becomes Friends

**Problem.** `n` people, `0..n-1`. Given `logs[i] = [timestamp, x, y]` (sorted), find the earliest
timestamp at which all people are in one connected component. Return `-1` if impossible.

**Key insight.** Process logs in timestamp order; union `x` and `y`. Stop when `uf.count == 1`.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
        self.count -= 1;
    }
}

struct Solution;
impl Solution {
    pub fn earliest_acq(mut logs: Vec<Vec<i32>>, n: i32) -> i32 {
        logs.sort_unstable_by_key(|l| l[0]);
        let mut uf = UnionFind::new(n as usize);
        for log in logs {
            uf.union(log[1] as usize, log[2] as usize);
            if uf.count == 1 { return log[0]; }
        }
        -1
    }
}

fn main() {
    let logs = vec![
        vec![20190101,0,1],vec![20190104,3,4],vec![20190107,2,3],
        vec![20190211,1,5],vec![20190224,2,4],vec![20190301,0,3],
        vec![20190312,1,2],vec![20190322,4,5],
    ];
    assert_eq!(Solution::earliest_acq(logs, 6), 20190301);
}
```

**Complexity.** Time O(E·log E + E·α(N)), Space O(N).

---

## LC1319. Number of Operations to Make Network Connected

**Problem.** `n` computers, `connections[i] = [a, b]`. Each operation: remove a cable, reconnect two
disconnected parts. Return the minimum operations, or `-1` if impossible.

**Key insight.** You need at least `n-1` cables to connect `n` nodes. Count the number of "extra"
cables (edges that don't reduce component count). To connect `k` components you need `k-1` moves.
If extras < `k-1`, return `-1`.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
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
        self.count -= 1; true
    }
}

struct Solution;
impl Solution {
    pub fn make_connected(n: i32, connections: Vec<Vec<i32>>) -> i32 {
        let mut uf = UnionFind::new(n as usize);
        let mut extras = 0;
        for c in &connections {
            if !uf.union(c[0] as usize, c[1] as usize) { extras += 1; }
        }
        let needed = uf.count - 1;
        if extras < needed { -1 } else { needed as i32 }
    }
}

fn main() {
    assert_eq!(Solution::make_connected(4, vec![vec![0,1],vec![0,2],vec![1,2]]), 1);
    assert_eq!(Solution::make_connected(6, vec![vec![0,1],vec![0,2],vec![0,3],vec![1,2],vec![1,3]]), 2);
    assert_eq!(Solution::make_connected(6, vec![vec![0,1],vec![0,2],vec![0,3],vec![1,2]]), -1);
}
```

**Complexity.** Time O(E·α(N)), Space O(N).

---

## LC1202. Smallest String With Swaps

**Problem.** Given a string `s` and pairs of indices you can swap (any number of times), return the
lexicographically smallest string possible.

**Key insight.** Swapping within a connected component is unrestricted — you can rearrange characters
in a component arbitrarily. DSU to find components, sort characters within each component, write them
back in sorted order at sorted positions.

```rust
use std::collections::HashMap;

struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
    }
}

struct Solution;
impl Solution {
    pub fn smallest_string_with_swaps(s: String, pairs: Vec<Vec<i32>>) -> String {
        let n = s.len();
        let bytes: Vec<u8> = s.into_bytes();
        let mut uf = UnionFind::new(n);
        for p in &pairs { uf.union(p[0] as usize, p[1] as usize); }
        // Group indices by root
        let mut groups: HashMap<usize, Vec<usize>> = HashMap::new();
        for i in 0..n { groups.entry(uf.find(i)).or_default().push(i); }
        let mut result = bytes.clone();
        for indices in groups.values() {
            let mut idx_sorted = indices.clone();
            idx_sorted.sort_unstable();
            let mut chars: Vec<u8> = idx_sorted.iter().map(|&i| bytes[i]).collect();
            chars.sort_unstable();
            for (&pos, &ch) in idx_sorted.iter().zip(chars.iter()) {
                result[pos] = ch;
            }
        }
        String::from_utf8(result).unwrap()
    }
}

fn main() {
    assert_eq!(
        Solution::smallest_string_with_swaps("dcab".to_string(), vec![vec![0,3],vec![1,2]]),
        "bacd"
    );
    assert_eq!(
        Solution::smallest_string_with_swaps("dcab".to_string(), vec![vec![0,3],vec![1,2],vec![0,2]]),
        "abcd"
    );
    assert_eq!(
        Solution::smallest_string_with_swaps("cba".to_string(), vec![vec![0,1],vec![1,2]]),
        "abc"
    );
}
```

**Complexity.** Time O((N + P)·α(N) + N·log N), Space O(N).

---

## LC952. Largest Component Size by Common Factor

**Problem.** Given an array of positive integers, group values that share a common factor > 1 (directly
or transitively). Return the size of the largest such group.

**Key insight.** For each number, factorize it. Union the number with each of its prime factors (using
the prime as a virtual node). After all unions, find the largest component. Use an array-based DSU
indexed up to `max_val + 1` to include prime-factor nodes.

```rust
struct UnionFind { parent: Vec<usize>, size: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), size: vec![1; n] } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        if self.size[rx] < self.size[ry] { self.parent[rx] = ry; self.size[ry] += self.size[rx]; }
        else { self.parent[ry] = rx; self.size[rx] += self.size[ry]; }
    }
}

struct Solution;
impl Solution {
    pub fn largest_component_size(nums: Vec<i32>) -> i32 {
        let max_val = *nums.iter().max().unwrap() as usize;
        let mut uf = UnionFind::new(max_val + 1);
        for &n in &nums {
            let n = n as usize;
            let mut x = n;
            let mut f = 2usize;
            while f * f <= x {
                if x % f == 0 {
                    uf.union(n, f);
                    while x % f == 0 { x /= f; }
                }
                f += 1;
            }
            if x > 1 { uf.union(n, x); }
        }
        // Only count roots of actual numbers (not prime-factor virtual nodes)
        let mut comp_size: std::collections::HashMap<usize, usize> = std::collections::HashMap::new();
        let mut best = 0;
        for &n in &nums {
            let root = uf.find(n as usize);
            let cnt = comp_size.entry(root).or_insert(0);
            *cnt += 1;
            best = best.max(*cnt);
        }
        best as i32
    }
}

fn main() {
    assert_eq!(Solution::largest_component_size(vec![4,6,15,35]), 4);
    assert_eq!(Solution::largest_component_size(vec![20,50,9,63]), 2);
    assert_eq!(Solution::largest_component_size(vec![2,3,6,7,4,12,21,39]), 8);
}
```

**Complexity.** Time O(N·sqrt(max_val)·α(max_val)), Space O(max_val).

---

## Part 7 — Online / Reverse-Time DSU

---

## LC305. Number of Islands II

**Problem.** An `m x n` grid starts all water. Given a list of positions, add land one at a time.
After each addition, return the number of islands.

**Key insight.** Online DSU: start with 0 islands. For each new land cell, increment count, then
union with existing land neighbors (decrementing count per successful union).

```rust
struct UnionFind { parent: Vec<i32>, rank: Vec<usize>, count: i32 }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: vec![-1; n], rank: vec![0; n], count: 0 } }
    fn find(&mut self, x: usize) -> usize {
        // parent[x] < 0 → not yet land (sentinel); parent[x] == x → root
        if self.parent[x] < 0 || self.parent[x] as usize == x { return x; }
        let p = self.parent[x] as usize;
        let root = self.find(p);
        self.parent[x] = root as i32;
        root
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry as i32,
            std::cmp::Ordering::Greater => self.parent[ry] = rx as i32,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx as i32; self.rank[rx] += 1; }
        }
        self.count -= 1;
    }
}

struct Solution;
impl Solution {
    pub fn num_islands2(m: i32, n: i32, positions: Vec<Vec<i32>>) -> Vec<i32> {
        let (m, n) = (m as usize, n as usize);
        let mut uf = UnionFind::new(m * n);
        let mut result = Vec::new();
        let dirs: [(i32,i32); 4] = [(-1,0),(1,0),(0,-1),(0,1)];
        for pos in &positions {
            let (r, c) = (pos[0] as usize, pos[1] as usize);
            let id = r * n + c;
            if uf.parent[id] == -1 { // newly added land
                uf.parent[id] = id as i32;
                uf.count += 1;
                for &(dr, dc) in &dirs {
                    let nr = r as i32 + dr;
                    let nc = c as i32 + dc;
                    if nr >= 0 && nr < m as i32 && nc >= 0 && nc < n as i32 {
                        let nid = nr as usize * n + nc as usize;
                        if uf.parent[nid] >= 0 { uf.union(id, nid); }
                    }
                }
            }
            result.push(uf.count);
        }
        result
    }
}

fn main() {
    assert_eq!(
        Solution::num_islands2(3, 3, vec![vec![0,0],vec![0,1],vec![1,2],vec![2,1]]),
        vec![1,1,2,3]
    );
    assert_eq!(
        Solution::num_islands2(1, 1, vec![vec![0,0]]),
        vec![1]
    );
}
```

**Complexity.** Time O(K·α(m·n)) where K = number of positions, Space O(m·n).

---

## LC803. Bricks Falling When Hit

**Problem.** A `m x n` binary grid of bricks. Bricks connected (directly or indirectly) to the top
row are stable; others fall. Given hits on bricks, return how many bricks fall per hit.

**Key insight.** Reverse-time DSU. Process hits backwards: "add" bricks back one at a time. A brick
added at `(r, c)` is roof-connected if `r == 0` or any neighbor is roof-connected. Count the gain in
roof-connected bricks per step minus 1 (the re-added brick itself doesn't "fall"). Use a virtual roof
node (index `m*n`).

```rust
// LC803 uses size-based balancing (not rank) because we need component sizes.
struct UnionFind { parent: Vec<usize>, size: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind { parent: (0..n).collect(), size: vec![1; n] }
    }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        if self.size[rx] < self.size[ry] {
            self.parent[rx] = ry; self.size[ry] += self.size[rx];
        } else {
            self.parent[ry] = rx; self.size[rx] += self.size[ry];
        }
    }
    fn roof_size(&mut self, roof: usize) -> usize {
        let r = self.find(roof);
        self.size[r] - 1 // subtract the virtual roof node itself
    }
}

struct Solution;
impl Solution {
    pub fn hit_bricks(mut grid: Vec<Vec<i32>>, hits: Vec<Vec<i32>>) -> Vec<i32> {
        let (rows, cols) = (grid.len(), grid[0].len());
        let roof = rows * cols; // virtual roof node
        let id = |r: usize, c: usize| r * cols + c;
        let dirs: [(i32,i32);4] = [(-1,0),(1,0),(0,-1),(0,1)];

        // Mark all hit cells as 0 (to be restored in reverse)
        for h in &hits { grid[h[0] as usize][h[1] as usize] -= 1; }

        let mut uf = UnionFind::new(roof + 1);

        // Build initial DSU from non-hit cells
        for r in 0..rows {
            for c in 0..cols {
                if grid[r][c] == 1 {
                    if r == 0 { uf.union(id(r, c), roof); }
                    if r > 0 && grid[r-1][c] == 1 { uf.union(id(r, c), id(r-1, c)); }
                    if c > 0 && grid[r][c-1] == 1 { uf.union(id(r, c), id(r, c-1)); }
                }
            }
        }

        let mut result = vec![0i32; hits.len()];
        // Process hits in reverse
        for i in (0..hits.len()).rev() {
            let r = hits[i][0] as usize;
            let c = hits[i][1] as usize;
            grid[r][c] += 1;
            if grid[r][c] != 1 { continue; } // was never a brick or not actually hit

            let before = uf.roof_size(roof);
            if r == 0 { uf.union(id(r, c), roof); }
            for &(dr, dc) in &dirs {
                let nr = r as i32 + dr; let nc = c as i32 + dc;
                if nr >= 0 && nr < rows as i32 && nc >= 0 && nc < cols as i32 {
                    let (nr, nc) = (nr as usize, nc as usize);
                    if grid[nr][nc] == 1 { uf.union(id(r, c), id(nr, nc)); }
                }
            }
            let after = uf.roof_size(roof);
            // Bricks that fell = gained roof-connected bricks minus the re-added brick itself
            result[i] = 0.max(after as i32 - before as i32 - 1);
        }
        result
    }
}

fn main() {
    assert_eq!(
        Solution::hit_bricks(vec![vec![1,0,0,0],vec![1,1,1,0]], vec![vec![1,0]]),
        vec![2]
    );
    assert_eq!(
        Solution::hit_bricks(vec![vec![1,0,0,0],vec![1,1,0,0]], vec![vec![1,1],vec![1,0]]),
        vec![0,0]
    );
}
```

**Complexity.** Time O((m·n + K)·α(m·n)), Space O(m·n).

> **Java comparison.** The reverse-time pattern (process destructive events backwards, simulating
> additions) has no standard Java library idiom. In Rust, `(0..hits.len()).rev()` iterates indices
> in reverse without allocating. `0.max(x)` is idiomatic for clamping to zero.

---

## Part 8 — Binary Search + DSU

---

## LC1970. Last Day Where You Can Still Cross

**Problem.** A `row x col` grid. On day `d`, cell `cells[d-1]` becomes water. Return the last day you
can walk from top to bottom (any path of land cells, 4-directional).

**Key insight.** Binary search on day `d`. For a given `d`, all cells in `cells[0..d]` are water;
the rest are land. Check connectivity from top row to bottom row using DSU with two virtual nodes:
`top` and `bottom`.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { let p = self.parent[x]; self.parent[x] = self.find(p); }
        self.parent[x]
    }
    fn union(&mut self, x: usize, y: usize) {
        let (rx, ry) = (self.find(x), self.find(y));
        if rx == ry { return; }
        match self.rank[rx].cmp(&self.rank[ry]) {
            std::cmp::Ordering::Less    => self.parent[rx] = ry,
            std::cmp::Ordering::Greater => self.parent[ry] = rx,
            std::cmp::Ordering::Equal   => { self.parent[ry] = rx; self.rank[rx] += 1; }
        }
    }
    fn connected(&mut self, x: usize, y: usize) -> bool { self.find(x) == self.find(y) }
}

struct Solution;
impl Solution {
    pub fn latest_day_to_cross(row: i32, col: i32, cells: Vec<Vec<i32>>) -> i32 {
        let (rows, cols) = (row as usize, col as usize);
        let top = rows * cols;
        let bottom = top + 1;
        let id = |r: usize, c: usize| r * cols + c;
        let dirs: [(i32,i32);4] = [(-1,0),(1,0),(0,-1),(0,1)];

        let can_cross = |day: usize| -> bool {
            let mut flooded = vec![vec![false; cols]; rows];
            for i in 0..day { flooded[cells[i][0] as usize - 1][cells[i][1] as usize - 1] = true; }
            let mut uf = UnionFind::new(top + 2);
            for r in 0..rows {
                for c in 0..cols {
                    if !flooded[r][c] {
                        if r == 0 { uf.union(id(r, c), top); }
                        if r == rows - 1 { uf.union(id(r, c), bottom); }
                        for &(dr, dc) in &dirs {
                            let nr = r as i32 + dr; let nc = c as i32 + dc;
                            if nr >= 0 && nr < rows as i32 && nc >= 0 && nc < cols as i32 {
                                let (nr, nc) = (nr as usize, nc as usize);
                                if !flooded[nr][nc] { uf.union(id(r, c), id(nr, nc)); }
                            }
                        }
                    }
                }
            }
            uf.connected(top, bottom)
        };

        let mut lo = 1usize;
        let mut hi = cells.len();
        while lo < hi {
            let mid = lo + (hi - lo + 1) / 2;
            if can_cross(mid) { lo = mid; } else { hi = mid - 1; }
        }
        lo as i32
    }
}

fn main() {
    assert_eq!(Solution::latest_day_to_cross(2, 2, vec![vec![1,1],vec![2,1],vec![1,2],vec![2,2]]), 2);
    assert_eq!(Solution::latest_day_to_cross(2, 2, vec![vec![1,1],vec![1,2],vec![2,1],vec![2,2]]), 1);
    assert_eq!(Solution::latest_day_to_cross(3, 3, vec![vec![1,2],vec![2,1],vec![3,3],vec![2,2],vec![1,1],vec![1,3],vec![2,3],vec![3,2],vec![3,1]]), 3);
}
```

**Complexity.** Time O(row·col·log(row·col)·α(row·col)), Space O(row·col).

---

## LC1489. Find Critical and Pseudo-Critical Edges in MST

**Problem.** Find all critical edges (removing them increases MST weight or disconnects the graph)
and all pseudo-critical edges (included in some but not all MSTs) in the given weighted undirected graph.

**Key insight.** Run baseline Kruskal. For each edge `i`:
- **Critical:** skip edge `i`, run Kruskal on remaining edges. If MST weight increases or graph disconnects, edge `i` is critical.
- **Pseudo-critical (and not critical):** force edge `i` first (union its endpoints, add its weight), run Kruskal on remaining edges. If total MST weight equals baseline, it is pseudo-critical.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize>, count: usize }
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
        self.count -= 1; true
    }
}

struct Solution;
impl Solution {
    pub fn find_critical_and_pseudo_critical_edges(n: i32, edges: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        let n = n as usize;
        // Augment edges with original index
        let mut indexed: Vec<(i32, usize, usize, usize)> = edges
            .iter().enumerate()
            .map(|(i, e)| (e[2], e[0] as usize, e[1] as usize, i))
            .collect();
        indexed.sort_unstable_by_key(|&(w,_,_,_)| w);

        // Run Kruskal, optionally skipping one edge or forcing one edge first.
        // Returns (MST weight, component count after Kruskal).
        let kruskal = |skip: Option<usize>, force: Option<usize>| -> (i64, usize) {
            let mut uf = UnionFind::new(n);
            let mut weight = 0i64;
            if let Some(fi) = force {
                let (w, u, v, _) = indexed[fi];
                uf.union(u, v);
                weight += w as i64;
            }
            for (idx, &(w, u, v, _)) in indexed.iter().enumerate() {
                if Some(idx) == skip { continue; }
                if uf.union(u, v) { weight += w as i64; }
            }
            (weight, uf.count)
        };

        let (base_weight, _) = kruskal(None, None);
        let mut critical = Vec::new();
        let mut pseudo = Vec::new();

        for i in 0..indexed.len() {
            let orig = indexed[i].3;
            // Critical check: skip edge i
            let (w, comps) = kruskal(Some(i), None);
            if comps > 1 || w > base_weight {
                critical.push(orig as i32);
                continue;
            }
            // Pseudo-critical check: force edge i
            let (w2, _) = kruskal(None, Some(i));
            if w2 == base_weight { pseudo.push(orig as i32); }
        }
        vec![critical, pseudo]
    }
}

fn main() {
    // Example: n=4, edges=[[0,1,1],[1,2,1],[0,2,1],[0,3,1]]
    // Node 3 only reachable via edge 3 → critical. Edges 0,1,2 form a triangle;
    // any two connect {0,1,2}, so all three are pseudo-critical.
    let e1 = vec![vec![0,1,1],vec![1,2,1],vec![0,2,1],vec![0,3,1]];
    let res = Solution::find_critical_and_pseudo_critical_edges(4, e1);
    let mut crit = res[0].clone(); crit.sort_unstable();
    let mut pseudo = res[1].clone(); pseudo.sort_unstable();
    assert_eq!(crit, vec![3]);
    assert_eq!(pseudo, vec![0, 1, 2]);
}
```

**Complexity.** Time O(E² · α(V)), Space O(V).

---

## Patterns & Tips

### Choosing the Right DSU Variant

| Problem type | DSU variant | Key addition |
|---|---|---|
| Basic connectivity | Standard (parent + rank) | `count` field |
| Max/min component area | + `size[]` at root | `size[rx] += size[ry]` in `union` |
| Ratio / weighted edges | + `weight[]` | Multiply weights on path compress |
| String/coordinate keys | HashMap-based or offset ids | Map string → `usize` before creating DSU |
| Border-safe regions | Virtual boundary node at index `n` | Union border cells with virtual node |
| Row+column grouping (#947) | Virtual row/col nodes | Row `r` = id `r`; col `c` = id `n+c` |
| Online (add-only) operations | Standard DSU, `count` starts 0 | Use sentinel `parent[x] = -1` for "not yet land" |
| Reverse-time (remove → add) | Standard DSU | Process events backwards; virtual top/bottom nodes |
| MST via Kruskal | Standard DSU | Sort edges by weight; stop after `n-1` merges |

### Path Compression: Rust Borrow Checker Gotcha

Recursive path compression requires capturing the parent before the recursive call:

```rust
// DOES NOT COMPILE — two mutable borrows of self:
// self.parent[x] = self.find(self.parent[x]);

// CORRECT — release borrow before recursive call:
fn find(&mut self, x: usize) -> usize {
    if self.parent[x] != x {
        let p = self.parent[x];          // capture parent index
        self.parent[x] = self.find(p);   // now only one borrow active
    }
    self.parent[x]
}
```

Iterative path compression (path halving) is a valid alternative that avoids deep recursion on degenerate inputs:

```rust
// Path halving: on each step, make x point to its grandparent.
// Amortized equivalent to full path compression; avoids recursion entirely.
fn find_iterative(&mut self, mut x: usize) -> usize {
    while self.parent[x] != x {
        let gp = self.parent[self.parent[x]]; // grandparent
        self.parent[x] = gp;                  // point x directly to grandparent
        x = gp;
    }
    x
}
```

### Virtual Node Pattern

Use virtual nodes when the problem has a "super-node" (boundary, roof, top/bottom):

```
real nodes:  0 .. n*m - 1
virtual top: n*m
virtual bot: n*m + 1
DSU size:    n*m + 2
```

Union all top-row land cells with virtual top; all bottom-row with virtual bottom. Query `connected(top, bottom)`.

### Kruskal Checklist

1. Sort edges by weight (ascending for MST).
2. Iterate; `union(u, v)` — if returns `true` (new merge), add weight to total.
3. Stop early when `n-1` edges have been added (all nodes connected).
4. If fewer than `n-1` edges added, graph is disconnected.

### Java-to-Rust Translation Card

| Java | Rust | Note |
|---|---|---|
| `int[] parent = new int[n]` | `parent: Vec<usize>` | `(0..n).collect()` initializes |
| `int find(int x) { ... }` | `fn find(&mut self, x: usize) -> usize` | `&mut self` for path compression |
| `Map<String,Integer> emailId` | `HashMap<String, usize>` | `.or_insert(next_id)` for auto-assign |
| `double[] weight` | `weight: Vec<f64>` | Multiply on path compress, divide on union |
| `count--` in union | `self.count -= 1;` | Guard with `if rx != ry` |
| `Math.max(0, after - before - 1)` | `0.max(after as i32 - before as i32 - 1)` | Method call style, no cast-wrapping needed |
| Reverse loop `for (int i = n-1; i >= 0; i--)` | `for i in (0..n).rev()` | No off-by-one risk |
| `Arrays.sort(edges, (a, b) -> a[2] - b[2])` | `edges.sort_unstable_by_key(\|e\| e[2])` | `sort_unstable_by_key` is faster when stable sort is not needed |

### Complexity Reference

| Problem | Time | Space |
|---|---|---|
| Basic DSU (find/union) | O(α(n)) per op | O(n) |
| Grid DSU (m×n) | O(m·n·α(m·n)) | O(m·n) |
| Accounts Merge (E emails) | O(E·α(E)·log E) | O(E) |
| Kruskal MST (V nodes, E edges) | O(E·log E + E·α(V)) | O(V) |
| LC #952 (max val M) | O(N·√M·α(M)) | O(M) |
| LC #1489 (E edges) | O(E²·α(V)) | O(V) |
| LC #1970 (row×col grid) | O(row·col·log(row·col)·α(row·col)) | O(row·col) |
