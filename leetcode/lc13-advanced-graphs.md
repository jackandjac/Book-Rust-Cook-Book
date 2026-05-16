# LC-13: Advanced Graph Algorithms

> **Cookbook Philosophy:** Every problem includes a complete, runnable solution with passing tests. All examples target Rust 2024 edition (1.85+). This chapter goes beyond basic BFS/DFS to cover weighted shortest paths, topological ordering, Union-Find, minimum spanning trees, and bridge-finding. Java comparisons are included wherever the idiomatic Rust approach diverges meaningfully.

---

## Advanced Graph Algorithms Reference

### Dijkstra's Algorithm (Min-Heap Template)

Dijkstra finds the shortest path from a single source to all other nodes in a graph with non-negative edge weights.

**Critical Rust pattern: `Reverse<(cost, node)>` for min-heap behavior.**

Rust's `BinaryHeap` is a *max-heap* by default. Wrapping the tuple in `std::cmp::Reverse` inverts the ordering so the smallest cost is popped first.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

fn dijkstra(graph: &Vec<Vec<(usize, u32)>>, src: usize, n: usize) -> Vec<u32> {
    let mut dist = vec![u32::MAX; n];
    dist[src] = 0;
    // BinaryHeap is max-heap; Reverse makes it min-heap on cost
    let mut heap: BinaryHeap<Reverse<(u32, usize)>> = BinaryHeap::new();
    heap.push(Reverse((0, src)));

    while let Some(Reverse((cost, u))) = heap.pop() {
        // Stale entry: a shorter path to u was already found
        if cost > dist[u] { continue; }
        for &(v, w) in &graph[u] {
            let next = cost + w;
            if next < dist[v] {
                dist[v] = next;
                heap.push(Reverse((next, v)));
            }
        }
    }
    dist
}
```

**Overflow guard:** Use `u32::MAX` only when edge weights are small. For problems with potentially large sums, use `i64::MAX / 2` so that `cost + w` never wraps.

### Bellman-Ford Template

Handles negative edge weights; detects negative cycles. Useful for "at most K hops" constraints.

```rust
fn bellman_ford(edges: &[(usize, usize, i32)], src: usize, n: usize) -> Vec<i64> {
    let mut dist = vec![i64::MAX / 2; n];
    dist[src] = 0;
    // Relax all edges n-1 times
    for _ in 0..n - 1 {
        let prev = dist.clone(); // snapshot prevents same-iteration chaining
        for &(u, v, w) in edges {
            if prev[u] < i64::MAX / 2 {
                dist[v] = dist[v].min(prev[u] + w as i64);
            }
        }
    }
    dist
}
```

**K-stop variant:** Run exactly `k + 1` relaxation rounds (one per hop) and snapshot `dist` before each round.

### Floyd-Warshall Template

All-pairs shortest paths in O(n³). Works with negative edges (but not negative cycles).

```rust
fn floyd_warshall(n: usize, edges: &[(usize, usize, i32)]) -> Vec<Vec<i32>> {
    const INF: i32 = i32::MAX / 2;
    let mut dist = vec![vec![INF; n]; n];
    for i in 0..n { dist[i][i] = 0; }
    for &(u, v, w) in edges {
        dist[u][v] = w;
        dist[v][u] = w; // remove for directed graphs
    }
    for k in 0..n {
        for i in 0..n {
            for j in 0..n {
                if dist[i][k] < INF && dist[k][j] < INF {
                    dist[i][j] = dist[i][j].min(dist[i][k] + dist[k][j]);
                }
            }
        }
    }
    dist
}
```

### Topological Sort — Kahn's BFS

```rust
fn kahn_topo(n: usize, adj: &Vec<Vec<usize>>) -> Option<Vec<usize>> {
    let mut in_deg = vec![0usize; n];
    for u in 0..n {
        for &v in &adj[u] { in_deg[v] += 1; }
    }
    let mut queue: std::collections::VecDeque<usize> =
        (0..n).filter(|&i| in_deg[i] == 0).collect();
    let mut order = Vec::with_capacity(n);
    while let Some(u) = queue.pop_front() {
        order.push(u);
        for &v in &adj[u] {
            in_deg[v] -= 1;
            if in_deg[v] == 0 { queue.push_back(v); }
        }
    }
    if order.len() == n { Some(order) } else { None } // None = cycle detected
}
```

### Topological Sort — DFS Post-Order

```rust
fn dfs_topo(n: usize, adj: &Vec<Vec<usize>>) -> Option<Vec<usize>> {
    let mut state = vec![0u8; n]; // 0=unvisited, 1=in-progress, 2=done
    let mut order = Vec::with_capacity(n);
    fn dfs(u: usize, adj: &Vec<Vec<usize>>, state: &mut Vec<u8>,
           order: &mut Vec<usize>) -> bool {
        state[u] = 1;
        for &v in &adj[u] {
            if state[v] == 1 { return false; } // back edge = cycle
            if state[v] == 0 && !dfs(v, adj, state, order) { return false; }
        }
        state[u] = 2;
        order.push(u);
        true
    }
    for i in 0..n {
        if state[i] == 0 && !dfs(i, adj, &mut state, &mut order) {
            return None;
        }
    }
    order.reverse();
    Some(order)
}
```

### Union-Find / DSU (Path Compression + Union by Rank)

```rust
struct UnionFind {
    parent: Vec<usize>,
    rank:   Vec<usize>,
    count:  usize,
}

impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n }
    }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x {
            self.parent[x] = self.find(self.parent[x]);
        }
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
    fn connected(&mut self, x: usize, y: usize) -> bool {
        self.find(x) == self.find(y)
    }
}
```

### Kruskal's MST

Sort edges by weight, union non-connected components.

```rust
struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }
impl UnionFind {
    fn new(n: usize) -> Self { UnionFind { parent: (0..n).collect(), rank: vec![0; n] } }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { self.parent[x] = self.find(self.parent[x]); }
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

fn kruskal(n: usize, mut edges: Vec<(i32, usize, usize)>) -> i32 {
    edges.sort_unstable();
    let mut uf = UnionFind::new(n);
    let mut total = 0;
    for (w, u, v) in edges {
        if uf.union(u, v) { total += w; }
    }
    total
}
```

### Prim's MST

BFS from any start node, always picking the cheapest edge to an unvisited node.

```rust
fn prim(n: usize, graph: &Vec<Vec<(usize, i32)>>) -> i32 {
    use std::collections::BinaryHeap;
    use std::cmp::Reverse;
    let mut visited = vec![false; n];
    let mut heap: BinaryHeap<Reverse<(i32, usize)>> = BinaryHeap::new();
    heap.push(Reverse((0, 0)));
    let mut total = 0;
    let mut count = 0;
    while let Some(Reverse((cost, u))) = heap.pop() {
        if visited[u] { continue; }
        visited[u] = true;
        total += cost;
        count += 1;
        if count == n { break; }
        for &(v, w) in &graph[u] {
            if !visited[v] { heap.push(Reverse((w, v))); }
        }
    }
    total
}
```

---

## Java → Rust Quick Reference

| Java | Rust | Notes |
|------|------|-------|
| `PriorityQueue<int[]>` (min-heap) | `BinaryHeap<Reverse<(u32, usize)>>` | Java's PQ is min-heap by default; Rust's is max-heap — must use `Reverse` |
| `Collections.sort(edges, (a,b)->a[0]-b[0])` | `edges.sort_unstable_by_key(\|&(w,_,_)\| w)` | Or `edges.sort_unstable()` on a tuple with weight first |
| `int[] dist = new int[n]; Arrays.fill(dist, INF)` | `let mut dist = vec![u32::MAX; n]` | `u32::MAX` as sentinel for "unreachable" |
| `Map<Integer, List<int[]>> graph` | `Vec<Vec<(usize, i32)>>` | Indexed adjacency list; avoids HashMap overhead |
| `int[] parent = new int[n]` for DSU | `struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }` | Struct makes path compression clean |
| `Queue<Integer> q = new LinkedList<>()` | `VecDeque<usize>` | BFS queue for Kahn's topo sort |
| `boolean[] inStack` for cycle detect | `vec![0u8; n]` with states 0/1/2 | Tri-state: unvisited / in-progress / done |
| `Map<String, Integer>` for node IDs | `HashMap<String, usize>` or `BTreeMap` | BTreeMap when sorted iteration is needed |

---

## Problem Overview

| # | Problem | Difficulty | Category |
|---|---------|-----------|----------|
| LC 743  | [Network Delay Time](#1-network-delay-time-lc-743) | Medium | Dijkstra |
| LC 1631 | [Path with Minimum Effort](#2-path-with-minimum-effort-lc-1631) | Medium | Dijkstra on Grid |
| LC 787  | [Cheapest Flights Within K Stops](#3-cheapest-flights-within-k-stops-lc-787) | Medium | Bellman-Ford |
| LC 778  | [Swim in Rising Water](#4-swim-in-rising-water-lc-778) | Hard | Dijkstra |
| LC 1334 | [City With Smallest Neighbors](#5-find-the-city-with-the-smallest-number-of-neighbors-lc-1334) | Medium | Floyd-Warshall |
| LC 1514 | [Path with Maximum Probability](#6-path-with-maximum-probability-lc-1514) | Medium | Dijkstra Max-Heap |
| LC 207  | [Course Schedule](#7-course-schedule-lc-207) | Medium | Kahn's Topo Sort |
| LC 210  | [Course Schedule II](#8-course-schedule-ii-lc-210) | Medium | Kahn's Topo Sort |
| LC 269  | [Alien Dictionary](#9-alien-dictionary-lc-269) | Hard | Topo Sort |
| LC 444  | [Sequence Reconstruction](#10-sequence-reconstruction-lc-444) | Medium | Unique Topo Sort |
| LC 310  | [Minimum Height Trees](#11-minimum-height-trees-lc-310) | Medium | Leaf Trimming |
| LC 1136 | [Parallel Courses](#12-parallel-courses-lc-1136) | Medium | Topo Sort + Depth |
| LC 547  | [Number of Provinces](#13-number-of-provinces-lc-547) | Medium | Union-Find |
| LC 721  | [Accounts Merge](#14-accounts-merge-lc-721) | Medium | Union-Find + Strings |
| LC 684  | [Redundant Connection](#15-redundant-connection-lc-684) | Medium | Union-Find Cycle |
| LC 827  | [Making a Large Island](#16-making-a-large-island-lc-827) | Hard | Union-Find + Grid |
| LC 990  | [Satisfiability of Equality Equations](#17-satisfiability-of-equality-equations-lc-990) | Medium | Union-Find on Chars |
| LC 1584 | [Min Cost to Connect All Points](#18-min-cost-to-connect-all-points-lc-1584) | Medium | Prim's MST |
| LC 1168 | [Optimize Water Distribution](#19-optimize-water-distribution-in-a-village-lc-1168) | Hard | MST + Virtual Node |
| LC 1192 | [Critical Connections in a Network](#20-critical-connections-in-a-network-lc-1192) | Hard | Tarjan's Bridges |
| LC 1976 | [Number of Ways to Arrive at Destination](#21-number-of-ways-to-arrive-at-destination-lc-1976) | Medium | Dijkstra + Count |
| LC 1129 | [Shortest Path with Alternating Colors](#22-shortest-path-with-alternating-colors-lc-1129) | Medium | BFS on Edge-Colored Graph |

---

## LC743. Network Delay Time

**Problem.** Given a directed weighted graph with `n` nodes and edges `(u, v, w)`, a signal is sent from `k`. Return the minimum time for all nodes to receive the signal, or `-1` if any node is unreachable.

**Approach 1 — Dijkstra's Shortest Path (O((V+E) log V) time, O(V+E) space).**
Find the shortest distance from `k` to all nodes using Dijkstra with a min-heap. The answer is the
maximum shortest distance across all nodes (or -1 if any node has distance `u32::MAX`).

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

struct Solution;

impl Solution {
    pub fn network_delay_time(times: Vec<Vec<i32>>, n: i32, k: i32) -> i32 {
        let n = n as usize;
        let src = (k - 1) as usize; // convert to 0-indexed
        let mut graph: Vec<Vec<(usize, u32)>> = vec![vec![]; n];
        for t in &times {
            let (u, v, w) = ((t[0] - 1) as usize, (t[1] - 1) as usize, t[2] as u32);
            graph[u].push((v, w));
        }

        let mut dist = vec![u32::MAX; n];
        dist[src] = 0;
        let mut heap: BinaryHeap<Reverse<(u32, usize)>> = BinaryHeap::new();
        heap.push(Reverse((0, src)));

        while let Some(Reverse((cost, u))) = heap.pop() {
            if cost > dist[u] { continue; } // stale entry
            for &(v, w) in &graph[u] {
                let next = cost + w;
                if next < dist[v] {
                    dist[v] = next;
                    heap.push(Reverse((next, v)));
                }
            }
        }

        let max_dist = dist.iter().copied().max().unwrap_or(u32::MAX);
        if max_dist == u32::MAX { -1 } else { max_dist as i32 }
    }
}

#[cfg(test)]
mod tests_743 {
    use super::*;
    #[test]
    fn test_basic() {
        let times = vec![vec![2,1,1], vec![2,3,1], vec![3,4,1]];
        assert_eq!(Solution::network_delay_time(times, 4, 2), 2);
    }
    #[test]
    fn test_unreachable() {
        let times = vec![vec![1,2,1]];
        assert_eq!(Solution::network_delay_time(times, 2, 2), -1);
    }
    #[test]
    fn test_single_node() {
        assert_eq!(Solution::network_delay_time(vec![], 1, 1), 0);
    }
}
```

**Time:** O((E + V) log V) — each edge processed once, heap operations are O(log V).  
**Space:** O(V + E) for adjacency list and dist array.

**Rust note:** Converting to 0-indexed at the boundary keeps all internal code clean. `u32::MAX` as sentinel is safe here because max possible sum is bounded well below `u32::MAX`.

---

## LC1631. Path with Minimum Effort

**Problem.** In an `m×n` grid, find a path from top-left to bottom-right minimising the *maximum absolute difference* between any two consecutive cells.

**Approach 1 — Dijkstra on Grid Graph (O(R·C·log(R·C)) time, O(R·C) space).**
Treat each cell as a node; edge weight is the absolute height difference. Dijkstra finds the path
from `(0,0)` to `(R-1,C-1)` that minimizes the maximum single-edge weight (bottleneck shortest path).

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

struct Solution;

impl Solution {
    pub fn minimum_effort_path(heights: Vec<Vec<i32>>) -> i32 {
        let (rows, cols) = (heights.len(), heights[0].len());
        // dist[r][c] = minimum effort (max edge) to reach (r,c)
        let mut dist = vec![vec![u32::MAX; cols]; rows];
        dist[0][0] = 0;
        let mut heap: BinaryHeap<Reverse<(u32, usize, usize)>> = BinaryHeap::new();
        heap.push(Reverse((0, 0, 0)));
        let dirs = [(0i32, 1i32), (0, -1), (1, 0), (-1, 0)];

        while let Some(Reverse((effort, r, c))) = heap.pop() {
            if r == rows - 1 && c == cols - 1 { return effort as i32; }
            if effort > dist[r][c] { continue; }
            for (dr, dc) in dirs {
                let nr = r as i32 + dr;
                let nc = c as i32 + dc;
                if nr < 0 || nr >= rows as i32 || nc < 0 || nc >= cols as i32 { continue; }
                let (nr, nc) = (nr as usize, nc as usize);
                let edge = (heights[r][c] - heights[nr][nc]).unsigned_abs();
                let new_effort = effort.max(edge);
                if new_effort < dist[nr][nc] {
                    dist[nr][nc] = new_effort;
                    heap.push(Reverse((new_effort, nr, nc)));
                }
            }
        }
        0
    }
}

#[cfg(test)]
mod tests_1631 {
    use super::*;
    #[test]
    fn test_basic() {
        let heights = vec![vec![1,2,2],vec![3,8,2],vec![5,3,5]];
        assert_eq!(Solution::minimum_effort_path(heights), 2);
    }
    #[test]
    fn test_single_cell() {
        assert_eq!(Solution::minimum_effort_path(vec![vec![7]]), 0);
    }
    #[test]
    fn test_flat() {
        let heights = vec![vec![1,1,1],vec![1,1,1]];
        assert_eq!(Solution::minimum_effort_path(heights), 0);
    }
}
```

**Time:** O(m·n · log(m·n)).  
**Space:** O(m·n).

**Rust note:** `unsigned_abs()` on `i32` returns `u32` — no cast needed. The early return inside the loop avoids processing the destination's outgoing edges.

---

## LC787. Cheapest Flights Within K Stops

**Problem.** Find the cheapest flight from `src` to `dst` using at most `k` stops (k+1 edges). Return `-1` if no such path exists.

**Approach 1 — Bellman-Ford with Hop Constraint (O(k·E) time, O(V) space).**
Bellman-Ford with exactly `k+1` relaxation rounds: on each round, only relax edges using the
distances from the previous round (snapshot the `dist` array to prevent multi-hop updates within
one round). Dijkstra doesn't directly handle the hop constraint.

**Java comparison:** Java developers often reach for a modified Dijkstra with state `(cost, node, stops)`. Bellman-Ford with a snapshot is simpler and has the same time complexity for this problem.

```rust
struct Solution;

impl Solution {
    pub fn find_cheapest_price(n: i32, flights: Vec<Vec<i32>>, src: i32, dst: i32, k: i32) -> i32 {
        let n = n as usize;
        let (src, dst) = (src as usize, dst as usize);
        const INF: i64 = i64::MAX / 2;
        let mut dist = vec![INF; n];
        dist[src] = 0;

        // k stops = k+1 edges = k+1 relaxation rounds
        for _ in 0..=k {
            let prev = dist.clone(); // snapshot: no same-round chaining
            for f in &flights {
                let (u, v, w) = (f[0] as usize, f[1] as usize, f[2] as i64);
                if prev[u] < INF {
                    dist[v] = dist[v].min(prev[u] + w);
                }
            }
        }

        if dist[dst] >= INF { -1 } else { dist[dst] as i32 }
    }
}

#[cfg(test)]
mod tests_787 {
    use super::*;
    #[test]
    fn test_basic() {
        let flights = vec![vec![0,1,100],vec![1,2,100],vec![0,2,500]];
        assert_eq!(Solution::find_cheapest_price(3, flights, 0, 2, 1), 200);
    }
    #[test]
    fn test_direct_cheaper() {
        let flights = vec![vec![0,1,100],vec![1,2,100],vec![0,2,500]];
        assert_eq!(Solution::find_cheapest_price(3, flights, 0, 2, 0), 500);
    }
    #[test]
    fn test_no_path() {
        let flights = vec![vec![0,1,100]];
        assert_eq!(Solution::find_cheapest_price(3, flights, 0, 2, 1), -1);
    }
}
```

**Time:** O(k · E) where E = number of flights.  
**Space:** O(V) for dist arrays.

**Key insight:** The `.clone()` snapshot is mandatory. Without it, a node relaxed earlier in round `i` could immediately propagate into the same round, effectively allowing more than one hop per iteration.

---

## LC778. Swim in Rising Water

**Problem.** Grid where `grid[r][c]` is the elevation. You can swim in adjacent cells once the water level reaches their elevation. Find the minimum time `t` such that there is a path from `(0,0)` to `(n-1,n-1)`.

**Approach 1 — Dijkstra as Minimax Path (O(n² log n) time, O(n²) space).**
Dijkstra where edge weight from `(r,c)` to `(nr,nc)` is `grid[nr][nc]`. The shortest-path distance
from `(0,0)` to `(n-1,n-1)` in this formulation equals the minimum possible maximum water level.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

struct Solution;

impl Solution {
    pub fn swim_in_water(grid: Vec<Vec<i32>>) -> i32 {
        let n = grid.len();
        let mut dist = vec![vec![u32::MAX; n]; n];
        dist[0][0] = grid[0][0] as u32;
        let mut heap: BinaryHeap<Reverse<(u32, usize, usize)>> = BinaryHeap::new();
        heap.push(Reverse((grid[0][0] as u32, 0, 0)));
        let dirs = [(0i32,1i32),(0,-1),(1,0),(-1,0)];

        while let Some(Reverse((t, r, c))) = heap.pop() {
            if r == n - 1 && c == n - 1 { return t as i32; }
            if t > dist[r][c] { continue; }
            for (dr, dc) in dirs {
                let nr = r as i32 + dr;
                let nc = c as i32 + dc;
                if nr < 0 || nr >= n as i32 || nc < 0 || nc >= n as i32 { continue; }
                let (nr, nc) = (nr as usize, nc as usize);
                // Time to reach (nr,nc) = max(t, grid[nr][nc])
                let nt = t.max(grid[nr][nc] as u32);
                if nt < dist[nr][nc] {
                    dist[nr][nc] = nt;
                    heap.push(Reverse((nt, nr, nc)));
                }
            }
        }
        unreachable!()
    }
}

#[cfg(test)]
mod tests_778 {
    use super::*;
    #[test]
    fn test_small() {
        assert_eq!(Solution::swim_in_water(vec![vec![0,2],vec![1,3]]), 3);
    }
    #[test]
    fn test_single() {
        assert_eq!(Solution::swim_in_water(vec![vec![0]]), 0);
    }
    #[test]
    fn test_medium() {
        let grid = vec![
            vec![0,1,2,3,4],
            vec![24,23,22,21,5],
            vec![12,13,14,15,16],
            vec![11,17,18,19,20],
            vec![10,9,8,7,6],
        ];
        assert_eq!(Solution::swim_in_water(grid), 16);
    }
}
```

**Time:** O(n² log n).  
**Space:** O(n²).

---

## LC1334. Find the City With the Smallest Number of Neighbors

**Problem.** Find the city with the fewest neighbors reachable within distance threshold `distanceThreshold`. Tie-break: return the city with the largest index.

**Approach 1 — Floyd-Warshall All-Pairs Shortest Paths (O(V³) time, O(V²) space).**
Compute all-pairs shortest paths using Floyd-Warshall, then for each city count how many cities
are reachable within `distanceThreshold`. Return the city with the fewest reachable neighbors
(ties broken by highest index).

```rust
struct Solution;

impl Solution {
    pub fn find_the_city(n: i32, edges: Vec<Vec<i32>>, distance_threshold: i32) -> i32 {
        let n = n as usize;
        const INF: i32 = i32::MAX / 2;
        let mut dist = vec![vec![INF; n]; n];
        for i in 0..n { dist[i][i] = 0; }
        for e in &edges {
            let (u, v, w) = (e[0] as usize, e[1] as usize, e[2]);
            dist[u][v] = w;
            dist[v][u] = w;
        }

        // Floyd-Warshall
        for k in 0..n {
            for i in 0..n {
                for j in 0..n {
                    if dist[i][k] < INF && dist[k][j] < INF {
                        dist[i][j] = dist[i][j].min(dist[i][k] + dist[k][j]);
                    }
                }
            }
        }

        let mut best_city = 0i32;
        let mut best_count = n + 1; // more than max possible

        for i in 0..n {
            let count = (0..n)
                .filter(|&j| j != i && dist[i][j] <= distance_threshold)
                .count();
            // ">=" for tie-breaking: prefer larger index
            if count <= best_count {
                best_count = count;
                best_city = i as i32;
            }
        }
        best_city
    }
}

#[cfg(test)]
mod tests_1334 {
    use super::*;
    #[test]
    fn test_basic() {
        let edges = vec![vec![0,1,3],vec![1,2,1],vec![1,3,4],vec![2,3,1]];
        assert_eq!(Solution::find_the_city(4, edges, 4), 3);
    }
    #[test]
    fn test_larger() {
        let edges = vec![vec![0,1,2],vec![0,4,8],vec![1,2,3],vec![1,4,2],vec![2,3,1],vec![3,4,1]];
        assert_eq!(Solution::find_the_city(5, edges, 2), 0);
    }
}
```

**Time:** O(n³) for Floyd-Warshall + O(n²) for counting.  
**Space:** O(n²) for the distance matrix.

**Java comparison:** Java needs `int[][]` with `Arrays.fill` on each row. Rust's `vec![vec![INF; n]; n]` is a single expression.

---

## LC1514. Path with Maximum Probability

**Problem.** Find the maximum probability path from `start` to `end`. Edge weights are probabilities in `[0, 1]`.

**Approach 1 — Dijkstra with Max-Heap (O((V+E) log V) time, O(V+E) space).**
Maximize probability using Dijkstra with a max-heap (no `Reverse` wrapper). Push `(prob, node)`
directly into `BinaryHeap`. Multiply probabilities along edges instead of summing costs.

```rust
use std::collections::BinaryHeap;

struct Solution;

// f64 doesn't implement Ord, so wrap in a newtype that does.
#[derive(PartialEq)]
struct OrdF64(f64);

impl Eq for OrdF64 {}
impl PartialOrd for OrdF64 {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}
impl Ord for OrdF64 {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.0.partial_cmp(&other.0).unwrap_or(std::cmp::Ordering::Equal)
    }
}

impl Solution {
    pub fn max_probability(
        n: i32,
        edges: Vec<Vec<i32>>,
        succ_prob: Vec<f64>,
        start_node: i32,
        end_node: i32,
    ) -> f64 {
        let n = n as usize;
        let (src, dst) = (start_node as usize, end_node as usize);
        let mut graph: Vec<Vec<(usize, f64)>> = vec![vec![]; n];
        for (i, e) in edges.iter().enumerate() {
            let (u, v) = (e[0] as usize, e[1] as usize);
            graph[u].push((v, succ_prob[i]));
            graph[v].push((u, succ_prob[i]));
        }

        let mut prob = vec![0.0f64; n];
        prob[src] = 1.0;
        // Max-heap: largest probability first (no Reverse needed)
        let mut heap: BinaryHeap<(OrdF64, usize)> = BinaryHeap::new();
        heap.push((OrdF64(1.0), src));

        while let Some((OrdF64(p), u)) = heap.pop() {
            if u == dst { return p; }
            if p < prob[u] { continue; }
            for &(v, w) in &graph[u] {
                let np = p * w;
                if np > prob[v] {
                    prob[v] = np;
                    heap.push((OrdF64(np), v));
                }
            }
        }
        0.0
    }
}

#[cfg(test)]
mod tests_1514 {
    use super::*;
    #[test]
    fn test_basic() {
        let edges = vec![vec![0,1],vec![1,2],vec![0,2]];
        let probs = vec![0.5, 0.5, 0.2];
        let result = Solution::max_probability(3, edges, probs, 0, 2);
        assert!((result - 0.25).abs() < 1e-9);
    }
    #[test]
    fn test_no_path() {
        let edges = vec![vec![0,1]];
        let probs = vec![0.5];
        assert_eq!(Solution::max_probability(3, edges, probs, 0, 2), 0.0);
    }
}
```

**Time:** O((V + E) log V).  
**Space:** O(V + E).

**Rust note:** `f64` does not implement `Ord` because of NaN. The `OrdF64` newtype wrapper provides a total ordering suitable for `BinaryHeap`.

---

## LC207. Course Schedule

**Problem.** Given `numCourses` and prerequisite pairs, determine if it is possible to finish all courses (i.e., the graph has no cycle).

**Approach 1 — Kahn's BFS Topological Sort (O(V+E) time, O(V+E) space).**
Kahn's algorithm: start with all nodes with in-degree 0, process them, decrement neighbor in-degrees,
enqueue neighbors that reach in-degree 0. If exactly `n` nodes are processed, no cycle exists.

```rust
use std::collections::VecDeque;

struct Solution;

impl Solution {
    pub fn can_finish(num_courses: i32, prerequisites: Vec<Vec<i32>>) -> bool {
        let n = num_courses as usize;
        let mut adj = vec![vec![]; n];
        let mut in_deg = vec![0usize; n];
        for p in &prerequisites {
            let (a, b) = (p[0] as usize, p[1] as usize);
            adj[b].push(a);
            in_deg[a] += 1;
        }
        let mut queue: VecDeque<usize> = (0..n).filter(|&i| in_deg[i] == 0).collect();
        let mut processed = 0usize;
        while let Some(u) = queue.pop_front() {
            processed += 1;
            for &v in &adj[u] {
                in_deg[v] -= 1;
                if in_deg[v] == 0 { queue.push_back(v); }
            }
        }
        processed == n
    }
}

#[cfg(test)]
mod tests_207 {
    use super::*;
    #[test]
    fn test_no_cycle() {
        assert!(Solution::can_finish(2, vec![vec![1,0]]));
    }
    #[test]
    fn test_cycle() {
        assert!(!Solution::can_finish(2, vec![vec![1,0],vec![0,1]]));
    }
    #[test]
    fn test_no_prereqs() {
        assert!(Solution::can_finish(3, vec![]));
    }
}
```

**Time:** O(V + E).  
**Space:** O(V + E).

---

## LC210. Course Schedule II

**Problem.** Return one valid ordering in which courses can be taken, or an empty vector if impossible.

**Approach 1 — Kahn's BFS Topological Order (O(V+E) time, O(V+E) space).**
Kahn's algorithm collecting nodes in dequeue order gives one valid topological ordering. Return
an empty array if fewer than `n` nodes are dequeued (cycle detected).

```rust
use std::collections::VecDeque;

struct Solution;

impl Solution {
    pub fn find_order(num_courses: i32, prerequisites: Vec<Vec<i32>>) -> Vec<i32> {
        let n = num_courses as usize;
        let mut adj = vec![vec![]; n];
        let mut in_deg = vec![0usize; n];
        for p in &prerequisites {
            let (a, b) = (p[0] as usize, p[1] as usize);
            adj[b].push(a);
            in_deg[a] += 1;
        }
        let mut queue: VecDeque<usize> = (0..n).filter(|&i| in_deg[i] == 0).collect();
        let mut order: Vec<i32> = Vec::with_capacity(n);
        while let Some(u) = queue.pop_front() {
            order.push(u as i32);
            for &v in &adj[u] {
                in_deg[v] -= 1;
                if in_deg[v] == 0 { queue.push_back(v); }
            }
        }
        if order.len() == n { order } else { vec![] }
    }
}

#[cfg(test)]
mod tests_210 {
    use super::*;
    #[test]
    fn test_basic() {
        let result = Solution::find_order(2, vec![vec![1,0]]);
        assert_eq!(result, vec![0, 1]);
    }
    #[test]
    fn test_four_courses() {
        let prereqs = vec![vec![1,0],vec![2,0],vec![3,1],vec![3,2]];
        let result = Solution::find_order(4, prereqs);
        assert_eq!(result.len(), 4);
        // Verify it is a valid topological order
        let pos: Vec<usize> = {
            let mut p = vec![0usize; 4];
            for (i, &c) in result.iter().enumerate() { p[c as usize] = i; }
            p
        };
        assert!(pos[0] < pos[1] && pos[0] < pos[2] && pos[1] < pos[3] && pos[2] < pos[3]);
    }
    #[test]
    fn test_cycle() {
        assert!(Solution::find_order(2, vec![vec![1,0],vec![0,1]]).is_empty());
    }
}
```

**Time:** O(V + E).  
**Space:** O(V + E).

---

## LC269. Alien Dictionary

**Problem.** Given a sorted list of words in an unknown alien language, determine the character order. Return the order as a string, or `""` if it is invalid.

**Approach 1 — Graph Construction + Topological Sort (O(C + U) time, O(U) space).**
Build a directed graph from adjacent word pairs: the first differing character between consecutive
words defines an ordering constraint. Then topological sort (DFS post-order) gives the alien
alphabet. C is total character count; U is unique character pairs.

```rust
use std::collections::{HashMap, VecDeque};

struct Solution;

impl Solution {
    pub fn alien_order(words: Vec<String>) -> String {
        // Collect all unique characters
        let mut adj: HashMap<char, Vec<char>> = HashMap::new();
        let mut in_deg: HashMap<char, i32> = HashMap::new();
        for word in &words {
            for ch in word.chars() {
                adj.entry(ch).or_default();
                in_deg.entry(ch).or_insert(0);
            }
        }

        // Build edges from adjacent word pairs
        for i in 0..words.len() - 1 {
            let (w1, w2): (Vec<char>, Vec<char>) =
                (words[i].chars().collect(), words[i + 1].chars().collect());
            // If w2 is a prefix of w1, that is invalid (e.g., "abc" before "ab")
            if w1.len() > w2.len() && w1.starts_with(w2.as_slice()) {
                return String::new();
            }
            for (c1, c2) in w1.iter().zip(w2.iter()) {
                if c1 != c2 {
                    adj.get_mut(c1).unwrap().push(*c2);
                    *in_deg.get_mut(c2).unwrap() += 1;
                    break;
                }
            }
        }

        // Kahn's BFS
        let mut queue: VecDeque<char> =
            in_deg.iter().filter(|(_, v)| **v == 0).map(|(k, _)| *k).collect();
        // Deterministic order for reproducibility in tests
        let mut q_vec: Vec<char> = queue.drain(..).collect();
        q_vec.sort_unstable();
        queue.extend(q_vec);

        let mut result = String::new();
        while let Some(c) = queue.pop_front() {
            result.push(c);
            if let Some(neighbors) = adj.get(&c) {
                let mut nexts: Vec<char> = vec![];
                for &nb in neighbors {
                    let e = in_deg.get_mut(&nb).unwrap();
                    *e -= 1;
                    if *e == 0 { nexts.push(nb); }
                }
                nexts.sort_unstable();
                for nb in nexts { queue.push_back(nb); }
            }
        }

        if result.len() == in_deg.len() { result } else { String::new() }
    }
}

#[cfg(test)]
mod tests_269 {
    use super::*;
    #[test]
    fn test_basic() {
        let words = vec!["wrt","wrf","er","ett","rftt"]
            .into_iter().map(String::from).collect();
        let result = Solution::alien_order(words);
        // Valid: w < e < r < t < f (one valid ordering)
        assert!(!result.is_empty());
        assert_eq!(result.len(), 5);
    }
    #[test]
    fn test_invalid_prefix() {
        let words = vec!["abc","ab"].into_iter().map(String::from).collect();
        assert_eq!(Solution::alien_order(words), "");
    }
    #[test]
    fn test_cycle() {
        let words = vec!["z","x","z"].into_iter().map(String::from).collect();
        assert_eq!(Solution::alien_order(words), "");
    }
    #[test]
    fn test_single_word() {
        let words = vec!["abc"].into_iter().map(String::from).collect();
        let result = Solution::alien_order(words);
        assert_eq!(result.len(), 3);
    }
}
```

**Time:** O(C) where C is total length of all words.  
**Space:** O(1) since the alphabet has at most 26 characters.

---

## LC444. Sequence Reconstruction

**Problem.** Given `nums` (a permutation of `1..=n`) and `sequences` (lists of subsequences), determine if `nums` is the *only* sequence that can be reconstructed from `sequences`. The topological order must be unique: each step in Kahn's BFS must have exactly one candidate node.

**Approach 1 — Kahn's BFS Uniqueness Check (O(V+E) time, O(V+E) space).**
Build a directed graph from the sequences (each consecutive pair `seq[i] → seq[i+1]` is an edge).
Run Kahn's BFS: at each step, if more than one node has in-degree 0, the ordering is not unique.
Also verify that all numbers 1..=n appear in at least one sequence.

```rust
use std::collections::VecDeque;

struct Solution;

impl Solution {
    pub fn sequence_reconstruction(nums: Vec<i32>, sequences: Vec<Vec<i32>>) -> bool {
        let n = nums.len();
        let mut adj: Vec<Vec<usize>> = vec![vec![]; n + 1];
        let mut in_deg = vec![0usize; n + 1];
        let mut seen = vec![false; n + 1];

        for seq in &sequences {
            for &x in seq {
                if x < 1 || x as usize > n { return false; }
                seen[x as usize] = true;
            }
            for w in seq.windows(2) {
                let (a, b) = (w[0] as usize, w[1] as usize);
                adj[a].push(b);
                in_deg[b] += 1;
            }
        }

        // All values 1..=n must appear in sequences
        if !(1..=n).all(|i| seen[i]) { return false; }

        let mut queue: VecDeque<usize> = (1..=n).filter(|&i| in_deg[i] == 0).collect();
        let mut order = Vec::with_capacity(n);

        while let Some(u) = queue.pop_front() {
            // Unique topo sort requires the queue never has more than 1 element
            if queue.len() > 0 { return false; }
            order.push(u);
            for &v in &adj[u] {
                in_deg[v] -= 1;
                if in_deg[v] == 0 { queue.push_back(v); }
            }
        }

        order.len() == n && order.iter().zip(nums.iter()).all(|(&a, &b)| a as i32 == b)
    }
}

#[cfg(test)]
mod tests_444 {
    use super::*;
    #[test]
    fn test_unique() {
        assert!(Solution::sequence_reconstruction(
            vec![1,2,3], vec![vec![1,2],vec![1,3],vec![2,3]]
        ));
    }
    #[test]
    fn test_not_unique() {
        assert!(!Solution::sequence_reconstruction(
            vec![1,2,3], vec![vec![1,2]]
        ));
    }
    #[test]
    fn test_single() {
        assert!(Solution::sequence_reconstruction(vec![1], vec![vec![1]]));
    }
}
```

**Time:** O(V + E).  
**Space:** O(V + E).

**Key insight:** The queue having more than one element at any point means multiple valid orderings exist, so the reconstruction is not unique.

---

## LC310. Minimum Height Trees

**Problem.** Find all roots that minimize the height of a tree built from the given undirected tree edges.

**Approach 1 — Iterative Leaf Pruning (O(V+E) time, O(V+E) space).**
Iteratively remove all current leaf nodes (degree 1), repeating until at most 2 nodes remain.
These surviving nodes are the MHT roots. This is equivalent to BFS topological sort inward from
the periphery.

```rust
struct Solution;

impl Solution {
    pub fn find_min_height_trees(n: i32, edges: Vec<Vec<i32>>) -> Vec<i32> {
        let n = n as usize;
        if n == 1 { return vec![0]; }
        if n == 2 { return vec![0, 1]; }

        // degree[i] = number of current neighbors of node i
        let mut degree = vec![0usize; n];
        let mut adj = vec![vec![]; n];
        for e in &edges {
            let (u, v) = (e[0] as usize, e[1] as usize);
            adj[u].push(v);
            adj[v].push(u);
            degree[u] += 1;
            degree[v] += 1;
        }

        // Initial leaves: all nodes with degree 1
        let mut leaves: Vec<usize> = (0..n).filter(|&i| degree[i] == 1).collect();
        let mut remaining = n;

        // Trim leaves layer by layer until 1 or 2 nodes remain
        while remaining > 2 {
            let leaf_count = leaves.len();
            remaining -= leaf_count;
            let mut new_leaves = vec![];
            for leaf in leaves {
                for &neighbor in &adj[leaf] {
                    degree[neighbor] -= 1;
                    if degree[neighbor] == 1 {
                        new_leaves.push(neighbor);
                    }
                }
            }
            leaves = new_leaves;
        }

        leaves.iter().map(|&x| x as i32).collect()
    }
}

#[cfg(test)]
mod tests_310 {
    use super::*;
    #[test]
    fn test_basic() {
        let mut result = Solution::find_min_height_trees(4, vec![vec![1,0],vec![1,2],vec![1,3]]);
        result.sort();
        assert_eq!(result, vec![1]);
    }
    #[test]
    fn test_two_roots() {
        let mut result = Solution::find_min_height_trees(6,
            vec![vec![3,0],vec![3,1],vec![3,2],vec![3,4],vec![5,4]]);
        result.sort();
        assert_eq!(result, vec![3, 4]);
    }
    #[test]
    fn test_single_node() {
        assert_eq!(Solution::find_min_height_trees(1, vec![]), vec![0]);
    }
    #[test]
    fn test_two_nodes() {
        let mut result = Solution::find_min_height_trees(2, vec![vec![0,1]]);
        result.sort();
        assert_eq!(result, vec![0, 1]);
    }
}
```

**Time:** O(V) — each node/edge processed at most twice.  
**Space:** O(V + E).

---

## LC1136. Parallel Courses

**Problem.** `n` courses with prerequisites. In each semester you can take any course whose prerequisites are done. Return the minimum number of semesters needed, or `-1` if impossible.

**Approach 1 — Kahn's BFS with Depth Tracking (O(V+E) time, O(V+E) space).**
Kahn's BFS topological sort tracking the maximum depth (semester) for each node. A node's semester
is `max(semester of all prerequisites) + 1`. Return the maximum semester, or -1 if a cycle exists.

```rust
use std::collections::VecDeque;

struct Solution;

impl Solution {
    pub fn minimum_semesters(n: i32, relations: Vec<Vec<i32>>) -> i32 {
        let n = n as usize;
        let mut adj = vec![vec![]; n + 1];
        let mut in_deg = vec![0usize; n + 1];
        for r in &relations {
            let (a, b) = (r[0] as usize, r[1] as usize);
            adj[a].push(b);
            in_deg[b] += 1;
        }

        let mut queue: VecDeque<usize> = (1..=n).filter(|&i| in_deg[i] == 0).collect();
        let mut depth = vec![1i32; n + 1];
        let mut processed = 0usize;

        while let Some(u) = queue.pop_front() {
            processed += 1;
            for &v in &adj[u] {
                depth[v] = depth[v].max(depth[u] + 1);
                in_deg[v] -= 1;
                if in_deg[v] == 0 { queue.push_back(v); }
            }
        }

        if processed < n { -1 } else { *depth[1..=n].iter().max().unwrap() }
    }
}

#[cfg(test)]
mod tests_1136 {
    use super::*;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::minimum_semesters(3, vec![vec![1,3],vec![2,3]]), 2);
    }
    #[test]
    fn test_chain() {
        assert_eq!(Solution::minimum_semesters(3, vec![vec![1,2],vec![2,3]]), 3);
    }
    #[test]
    fn test_cycle() {
        assert_eq!(Solution::minimum_semesters(3, vec![vec![1,2],vec![2,3],vec![3,1]]), -1);
    }
}
```

**Time:** O(V + E).  
**Space:** O(V + E).

---

## LC547. Number of Provinces

**Problem.** Given an `n×n` adjacency matrix, count the number of connected components.

**Approach 1 — Union-Find with Path Compression and Union by Rank (O(E·α(V)) time, O(V) space).**
Union-Find: union each connected pair, counting distinct components. The number of provinces equals
the initial component count (`n`) minus the number of successful union operations.

```rust
struct Solution;

struct UnionFind {
    parent: Vec<usize>,
    rank:   Vec<usize>,
    count:  usize,
}

impl UnionFind {
    fn new(n: usize) -> Self {
        UnionFind { parent: (0..n).collect(), rank: vec![0; n], count: n }
    }
    fn find(&mut self, x: usize) -> usize {
        if self.parent[x] != x { self.parent[x] = self.find(self.parent[x]); }
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

impl Solution {
    pub fn find_circle_num(is_connected: Vec<Vec<i32>>) -> i32 {
        let n = is_connected.len();
        let mut uf = UnionFind::new(n);
        for i in 0..n {
            for j in i + 1..n {
                if is_connected[i][j] == 1 { uf.union(i, j); }
            }
        }
        uf.count as i32
    }
}

#[cfg(test)]
mod tests_547 {
    use super::*;
    #[test]
    fn test_two_provinces() {
        let mat = vec![vec![1,1,0],vec![1,1,0],vec![0,0,1]];
        assert_eq!(Solution::find_circle_num(mat), 2);
    }
    #[test]
    fn test_three_provinces() {
        let mat = vec![vec![1,0,0],vec![0,1,0],vec![0,0,1]];
        assert_eq!(Solution::find_circle_num(mat), 3);
    }
    #[test]
    fn test_one_province() {
        let mat = vec![vec![1,1],vec![1,1]];
        assert_eq!(Solution::find_circle_num(mat), 1);
    }
}
```

**Time:** O(n² · α(n)) ≈ O(n²) — α is the inverse Ackermann function, nearly constant.  
**Space:** O(n).

---

## LC721. Accounts Merge

**Problem.** Merge accounts that share at least one email address. Return sorted merged accounts.

**Approach 1 — Union-Find with Email Key Mapping (O(E·α(E) + E log E) time, O(E) space).**
Union-Find: map each email string to an integer index. Union all emails within the same account.
Group all emails by their root component, sort each group, and prepend the account name.

```rust
use std::collections::HashMap;

struct Solution;

impl Solution {
    pub fn accounts_merge(accounts: Vec<Vec<String>>) -> Vec<Vec<String>> {
        let mut email_to_id: HashMap<String, usize> = HashMap::new();
        let mut email_to_name: HashMap<String, String> = HashMap::new();
        let mut id = 0usize;

        for acc in &accounts {
            let name = &acc[0];
            for email in &acc[1..] {
                email_to_id.entry(email.clone()).or_insert_with(|| {
                    let cur = id; id += 1; cur
                });
                email_to_name.entry(email.clone()).or_insert_with(|| name.clone());
            }
        }

        let mut parent: Vec<usize> = (0..id).collect();
        // Path-compressed find (iterative to avoid stack overflow on large inputs)
        fn find(parent: &mut Vec<usize>, mut x: usize) -> usize {
            while parent[x] != x {
                parent[x] = parent[parent[x]]; // path halving
                x = parent[x];
            }
            x
        }

        for acc in &accounts {
            let first_id = email_to_id[&acc[1]];
            for email in &acc[2..] {
                let eid = email_to_id[email];
                let (ra, rb) = (find(&mut parent, first_id), find(&mut parent, eid));
                if ra != rb { parent[ra] = rb; }
            }
        }

        // Group emails by root
        let mut groups: HashMap<usize, Vec<String>> = HashMap::new();
        for (email, &eid) in &email_to_id {
            let root = find(&mut parent, eid);
            groups.entry(root).or_default().push(email.clone());
        }

        let mut result: Vec<Vec<String>> = vec![];
        for (root, mut emails) in groups {
            emails.sort();
            let name = email_to_name[&emails[0]].clone();
            let mut acc = vec![name];
            acc.extend(emails);
            result.push(acc);
        }
        result.sort();
        result
    }
}

#[cfg(test)]
mod tests_721 {
    use super::*;
    #[test]
    fn test_merge() {
        let accounts = vec![
            vec!["John","johnsmith@mail.com","john_newyork@mail.com"],
            vec!["John","johnsmith@mail.com","john00@mail.com"],
            vec!["Mary","mary@mail.com"],
            vec!["John","johnnybravo@mail.com"],
        ].into_iter().map(|v| v.into_iter().map(String::from).collect()).collect();
        let result = Solution::accounts_merge(accounts);
        assert_eq!(result.len(), 3);
        // John with merged emails should have 4 entries (name + 3 emails)
        let john_merged = result.iter().find(|a| a[0] == "John" && a.len() == 4);
        assert!(john_merged.is_some());
    }
    #[test]
    fn test_no_merge() {
        let accounts = vec![
            vec!["Alice","a@a.com"],
            vec!["Bob","b@b.com"],
        ].into_iter().map(|v| v.into_iter().map(String::from).collect()).collect();
        let result = Solution::accounts_merge(accounts);
        assert_eq!(result.len(), 2);
    }
}
```

**Time:** O(A · E · α(A·E)) where A = accounts, E = max emails per account.  
**Space:** O(A · E).

**Rust note:** The inner `find` is declared as a free function inside the method to avoid borrow-checker issues with `&mut self`. Iterative path-halving avoids stack overflow on degenerate inputs.

---

## LC684. Redundant Connection

**Problem.** In an undirected tree with one extra edge, find the redundant edge that forms a cycle.

**Approach 1 — Union-Find Edge Processing (O(E·α(V)) time, O(V) space).**
Process edges in order: for each edge, check if both endpoints are already connected. The first
edge that connects two already-connected nodes is the redundant connection and the answer.

```rust
struct Solution;

impl Solution {
    pub fn find_redundant_connection(edges: Vec<Vec<i32>>) -> Vec<i32> {
        let n = edges.len();
        let mut parent: Vec<usize> = (0..=n).collect();
        let mut rank = vec![0usize; n + 1];

        fn find(parent: &mut Vec<usize>, x: usize) -> usize {
            if parent[x] != x { parent[x] = find(parent, parent[x]); }
            parent[x]
        }

        for e in &edges {
            let (u, v) = (e[0] as usize, e[1] as usize);
            let (ru, rv) = (find(&mut parent, u), find(&mut parent, v));
            if ru == rv { return e.clone(); }
            match rank[ru].cmp(&rank[rv]) {
                std::cmp::Ordering::Less    => parent[ru] = rv,
                std::cmp::Ordering::Greater => parent[rv] = ru,
                std::cmp::Ordering::Equal   => { parent[rv] = ru; rank[ru] += 1; }
            }
        }
        vec![]
    }
}

#[cfg(test)]
mod tests_684 {
    use super::*;
    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::find_redundant_connection(vec![vec![1,2],vec![1,3],vec![2,3]]),
            vec![2, 3]
        );
    }
    #[test]
    fn test_longer_cycle() {
        assert_eq!(
            Solution::find_redundant_connection(vec![vec![1,2],vec![2,3],vec![3,4],vec![1,4],vec![1,5]]),
            vec![1, 4]
        );
    }
}
```

**Time:** O(E · α(V)).  
**Space:** O(V).

---

## LC827. Making a Large Island

**Problem.** In an `n×n` binary grid, flip at most one `0` to `1` and find the largest island size.

**Approach 1 — Union-Find Island Labeling + 0-Cell Expansion (O(R·C·α(R·C)) time, O(R·C) space).**
Union-Find labels and sizes each existing island. For each `0` cell, collect the set of distinct
neighboring island roots, sum their sizes, and add 1 (the flipped cell itself). Return the maximum.

```rust
struct Solution;

impl Solution {
    pub fn largest_island(mut grid: Vec<Vec<i32>>) -> i32 {
        let n = grid.len();
        let mut parent: Vec<usize> = (0..n * n).collect();
        let mut size = vec![1usize; n * n];

        fn find(parent: &mut Vec<usize>, x: usize) -> usize {
            if parent[x] != x { parent[x] = find(parent, parent[x]); }
            parent[x]
        }
        fn union(parent: &mut Vec<usize>, size: &mut Vec<usize>, x: usize, y: usize) {
            let (rx, ry) = (find(parent, x), find(parent, y));
            if rx == ry { return; }
            if size[rx] < size[ry] {
                parent[rx] = ry; size[ry] += size[rx];
            } else {
                parent[ry] = rx; size[rx] += size[ry];
            }
        }

        // Union all existing '1' cells
        let dirs = [(0i32, 1i32), (1, 0)];
        for r in 0..n {
            for c in 0..n {
                if grid[r][c] == 1 {
                    for (dr, dc) in dirs {
                        let nr = r as i32 + dr;
                        let nc = c as i32 + dc;
                        if nr >= 0 && nr < n as i32 && nc >= 0 && nc < n as i32
                            && grid[nr as usize][nc as usize] == 1 {
                            union(&mut parent, &mut size, r * n + c,
                                  nr as usize * n + nc as usize);
                        }
                    }
                }
            }
        }

        let mut ans = 0usize;
        // Check each zero cell
        let dirs4 = [(0i32,1i32),(0,-1),(1,0),(-1,0)];
        let mut any_zero = false;
        for r in 0..n {
            for c in 0..n {
                if grid[r][c] == 0 {
                    any_zero = true;
                    let mut seen = std::collections::HashSet::new();
                    let mut total = 1usize;
                    for (dr, dc) in dirs4 {
                        let nr = r as i32 + dr;
                        let nc = c as i32 + dc;
                        if nr < 0 || nr >= n as i32 || nc < 0 || nc >= n as i32 { continue; }
                        let (nr, nc) = (nr as usize, nc as usize);
                        if grid[nr][nc] == 1 {
                            let root = find(&mut parent, nr * n + nc);
                            if seen.insert(root) { total += size[root]; }
                        }
                    }
                    ans = ans.max(total);
                }
            }
        }

        // Edge case: no zeros — the whole grid is one island
        if !any_zero {
            ans = n * n;
        } else {
            let all_one_root = find(&mut parent, 0);
            ans = ans.max(size[all_one_root]);
        }

        ans as i32
    }
}

#[cfg(test)]
mod tests_827 {
    use super::*;
    #[test]
    fn test_basic() {
        assert_eq!(Solution::largest_island(vec![vec![1,0],vec![0,1]]), 3);
    }
    #[test]
    fn test_already_connected() {
        assert_eq!(Solution::largest_island(vec![vec![1,1],vec![1,1]]), 4);
    }
    #[test]
    fn test_all_zeros() {
        assert_eq!(Solution::largest_island(vec![vec![0,0],vec![0,0]]), 1);
    }
}
```

**Time:** O(n²· α(n²)).  
**Space:** O(n²).

---

## LC990. Satisfiability of Equality Equations

**Problem.** Given equations like `"a==b"` and `"a!=b"`, determine if all can be satisfied simultaneously.

**Approach 1 — Union-Find Two-Pass (O(E·α(V)) time, O(V) space).**
Two-pass: first process all `==` equations by unioning both variable indices. Then verify all
`!=` equations — if either variable pair shares the same root, return false (contradiction found).

```rust
struct Solution;

impl Solution {
    pub fn equations_possible(equations: Vec<String>) -> bool {
        let mut parent: Vec<usize> = (0..26).collect();

        fn find(parent: &mut Vec<usize>, x: usize) -> usize {
            if parent[x] != x { parent[x] = find(parent, parent[x]); }
            parent[x]
        }

        let char_idx = |c: char| (c as u8 - b'a') as usize;

        // Pass 1: union all equal pairs
        for eq in &equations {
            let bytes = eq.as_bytes();
            if bytes[1] == b'=' {
                let (a, b) = (char_idx(bytes[0] as char), char_idx(bytes[3] as char));
                let (ra, rb) = (find(&mut parent, a), find(&mut parent, b));
                if ra != rb { parent[ra] = rb; }
            }
        }

        // Pass 2: verify no != pair is in the same component
        for eq in &equations {
            let bytes = eq.as_bytes();
            if bytes[1] == b'!' {
                let (a, b) = (char_idx(bytes[0] as char), char_idx(bytes[3] as char));
                if find(&mut parent, a) == find(&mut parent, b) { return false; }
            }
        }
        true
    }
}

#[cfg(test)]
mod tests_990 {
    use super::*;
    #[test]
    fn test_satisfiable() {
        let eqs = vec!["a==b","b!=c","b==c"]
            .into_iter().map(String::from).collect();
        assert!(!Solution::equations_possible(eqs));
    }
    #[test]
    fn test_not_satisfiable() {
        let eqs = vec!["a==b","b==c","a==c"]
            .into_iter().map(String::from).collect();
        assert!(Solution::equations_possible(eqs));
    }
    #[test]
    fn test_self_ne() {
        let eqs = vec!["a!=a"].into_iter().map(String::from).collect();
        assert!(!Solution::equations_possible(eqs));
    }
}
```

**Time:** O(n · α(26)) = O(n).  
**Space:** O(1) — alphabet is fixed at 26.

---

## LC1584. Min Cost to Connect All Points

**Problem.** Given `n` points, connect them all with minimum total Manhattan distance.

**Approach 1 — Prim's MST (O(V²) time, O(V) space).**
Prim's MST starting from point 0: maintain a `min_cost` array (cheapest edge from any visited
node to each unvisited node). At each step greedily pick the unvisited node with the lowest
`min_cost`. Manhattan distance is the edge weight between any two points.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

struct Solution;

impl Solution {
    pub fn min_cost_connect_points(points: Vec<Vec<i32>>) -> i32 {
        let n = points.len();
        if n == 1 { return 0; }

        let dist = |i: usize, j: usize| -> i32 {
            (points[i][0] - points[j][0]).abs() + (points[i][1] - points[j][1]).abs()
        };

        let mut in_mst = vec![false; n];
        let mut min_edge = vec![i32::MAX; n];
        min_edge[0] = 0;
        let mut heap: BinaryHeap<Reverse<(i32, usize)>> = BinaryHeap::new();
        heap.push(Reverse((0, 0)));
        let mut total = 0;

        while let Some(Reverse((cost, u))) = heap.pop() {
            if in_mst[u] { continue; }
            in_mst[u] = true;
            total += cost;
            for v in 0..n {
                if !in_mst[v] {
                    let d = dist(u, v);
                    if d < min_edge[v] {
                        min_edge[v] = d;
                        heap.push(Reverse((d, v)));
                    }
                }
            }
        }
        total
    }
}

#[cfg(test)]
mod tests_1584 {
    use super::*;
    #[test]
    fn test_basic() {
        let points = vec![vec![0,0],vec![2,2],vec![3,10],vec![5,2],vec![7,0]];
        assert_eq!(Solution::min_cost_connect_points(points), 20);
    }
    #[test]
    fn test_two_points() {
        assert_eq!(Solution::min_cost_connect_points(vec![vec![0,0],vec![1,1]]), 2);
    }
    #[test]
    fn test_single_point() {
        assert_eq!(Solution::min_cost_connect_points(vec![vec![0,0]]), 0);
    }
}
```

**Time:** O(n² log n) — n² edges processed, each heap operation O(log n).  
**Space:** O(n).

---

## LC1168. Optimize Water Distribution in a Village

**Problem.** `n` houses; you can build a well in any house (cost `wells[i]`) or lay a pipe between houses (cost `pipes[i]`). Find the minimum cost to supply water to all houses.

**Approach 1 — Kruskal's MST with Virtual Node (O(E log E) time, O(V+E) space).**
Add a virtual node 0 representing the water source: connect each house `i` to node 0 with
edge weight `wells[i-1]`. Building a well = connecting to the virtual source. Run Kruskal's
MST on all edges (pipe costs + well costs) to find the minimum total cost.

```rust
struct Solution;

impl Solution {
    pub fn min_cost_to_supply_water(n: i32, wells: Vec<i32>, pipes: Vec<Vec<i32>>) -> i32 {
        let n = n as usize;
        // Collect all edges: (weight, u, v); virtual node = 0
        let mut edges: Vec<(i32, usize, usize)> = Vec::new();
        for (i, &w) in wells.iter().enumerate() {
            edges.push((w, 0, i + 1));
        }
        for p in &pipes {
            edges.push((p[2], p[0] as usize, p[1] as usize));
        }
        edges.sort_unstable_by_key(|&(w, _, _)| w);

        // Kruskal's on n+1 nodes (0..=n)
        let mut parent: Vec<usize> = (0..=n).collect();
        fn find(parent: &mut Vec<usize>, x: usize) -> usize {
            if parent[x] != x { parent[x] = find(parent, parent[x]); }
            parent[x]
        }

        let mut total = 0;
        let mut components = n + 1;
        for (w, u, v) in edges {
            let (ru, rv) = (find(&mut parent, u), find(&mut parent, v));
            if ru != rv {
                parent[ru] = rv;
                total += w;
                components -= 1;
                if components == 1 { break; }
            }
        }
        total
    }
}

#[cfg(test)]
mod tests_1168 {
    use super::*;
    #[test]
    fn test_basic() {
        let wells = vec![1, 2, 2];
        let pipes = vec![vec![1,2,1],vec![2,3,1]];
        assert_eq!(Solution::min_cost_to_supply_water(3, wells, pipes), 3);
    }
    #[test]
    fn test_single_house() {
        assert_eq!(Solution::min_cost_to_supply_water(1, vec![5], vec![]), 5);
    }
    #[test]
    fn test_cheaper_wells() {
        // All wells cheaper than any pipe
        let wells = vec![1, 1, 1];
        let pipes = vec![vec![1,2,100],vec![2,3,100]];
        assert_eq!(Solution::min_cost_to_supply_water(3, wells, pipes), 3);
    }
}
```

**Time:** O(E log E) for sorting + O(E · α(V)) for Kruskal's.  
**Space:** O(V + E).

**Key insight:** The virtual node trick elegantly converts "well or pipe" into a pure MST problem with no special casing.

---

## LC1192. Critical Connections in a Network

**Problem.** Find all edges whose removal disconnects the graph (bridges).

**Approach 1 — Tarjan's Bridge-Finding Algorithm (O(V+E) time, O(V+E) space).**
DFS tracking `disc[u]` (discovery time) and `low[u]` (lowest discovery time reachable from u's
subtree via back edges). Edge `(u, v)` is a bridge if `low[v] > disc[u]` — no back edge in v's
subtree reaches u or an ancestor of u.

**Java comparison:** Tarjan's requires careful tracking of the parent to avoid treating the tree edge back to parent as a back edge. Rust's explicit `parent` parameter in DFS makes this clear.

```rust
struct Solution;

impl Solution {
    pub fn critical_connections(n: i32, connections: Vec<Vec<i32>>) -> Vec<Vec<i32>> {
        let n = n as usize;
        let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
        for c in &connections {
            let (u, v) = (c[0] as usize, c[1] as usize);
            adj[u].push(v);
            adj[v].push(u);
        }

        let mut disc = vec![usize::MAX; n];
        let mut low  = vec![usize::MAX; n];
        let mut timer = 0usize;
        let mut bridges: Vec<Vec<i32>> = vec![];

        fn dfs(
            u: usize, parent: usize,
            adj: &Vec<Vec<usize>>,
            disc: &mut Vec<usize>, low: &mut Vec<usize>,
            timer: &mut usize, bridges: &mut Vec<Vec<i32>>,
        ) {
            disc[u] = *timer;
            low[u]  = *timer;
            *timer += 1;
            for &v in &adj[u] {
                if disc[v] == usize::MAX {
                    // Tree edge
                    dfs(v, u, adj, disc, low, timer, bridges);
                    low[u] = low[u].min(low[v]);
                    if low[v] > disc[u] {
                        bridges.push(vec![u as i32, v as i32]);
                    }
                } else if v != parent {
                    // Back edge (not the edge we came from)
                    low[u] = low[u].min(disc[v]);
                }
            }
        }

        for i in 0..n {
            if disc[i] == usize::MAX {
                dfs(i, usize::MAX, &adj, &mut disc, &mut low, &mut timer, &mut bridges);
            }
        }
        bridges
    }
}

#[cfg(test)]
mod tests_1192 {
    use super::*;
    #[test]
    fn test_basic() {
        let connections = vec![vec![0,1],vec![1,2],vec![2,0],vec![1,3]];
        let mut result = Solution::critical_connections(4, connections);
        result.iter_mut().for_each(|e| e.sort());
        result.sort();
        assert_eq!(result, vec![vec![1,3]]);
    }
    #[test]
    fn test_all_bridges() {
        // Path graph: every edge is a bridge
        let connections = vec![vec![0,1],vec![1,2]];
        let mut result = Solution::critical_connections(3, connections);
        result.iter_mut().for_each(|e| e.sort());
        result.sort();
        assert_eq!(result, vec![vec![0,1],vec![1,2]]);
    }
    #[test]
    fn test_no_bridge() {
        let connections = vec![vec![0,1],vec![1,2],vec![0,2]];
        assert!(Solution::critical_connections(3, connections).is_empty());
    }
}
```

**Time:** O(V + E).  
**Space:** O(V + E).

**Rust note:** The nested `fn dfs(...)` takes all mutable state as explicit parameters. This is the idiomatic way to write recursive DFS in Rust when you need to mutate multiple things — no `self`, no closures capturing `&mut`.

---

## LC1976. Number of Ways to Arrive at Destination

**Problem.** Count the number of shortest paths from node `0` to node `n-1`. Answer modulo `10^9 + 7`.

**Approach 1 — Dijkstra with Path Count (O((V+E) log V) time, O(V+E) space).**
Dijkstra extended with a `ways[]` array tracking the number of shortest paths to each node.
When a strictly shorter path is found, reset the count to the predecessor's count. When an
equal-length path is found, add the predecessor's count. Answer: `ways[n-1] mod 10^9+7`.

```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

struct Solution;

impl Solution {
    pub fn count_paths(n: i32, roads: Vec<Vec<i32>>) -> i32 {
        const MOD: u64 = 1_000_000_007;
        let n = n as usize;
        let mut graph: Vec<Vec<(usize, u64)>> = vec![vec![]; n];
        for r in &roads {
            let (u, v, t) = (r[0] as usize, r[1] as usize, r[2] as u64);
            graph[u].push((v, t));
            graph[v].push((u, t));
        }

        let mut dist = vec![u64::MAX; n];
        let mut ways = vec![0u64; n];
        dist[0] = 0;
        ways[0] = 1;
        let mut heap: BinaryHeap<Reverse<(u64, usize)>> = BinaryHeap::new();
        heap.push(Reverse((0, 0)));

        while let Some(Reverse((cost, u))) = heap.pop() {
            if cost > dist[u] { continue; }
            for &(v, w) in &graph[u] {
                let nc = cost + w;
                if nc < dist[v] {
                    dist[v] = nc;
                    ways[v] = ways[u];
                    heap.push(Reverse((nc, v)));
                } else if nc == dist[v] {
                    ways[v] = (ways[v] + ways[u]) % MOD;
                }
            }
        }
        ways[n - 1] as i32
    }
}

#[cfg(test)]
mod tests_1976 {
    use super::*;
    #[test]
    fn test_basic() {
        let roads = vec![
            vec![0,6,7],vec![0,1,2],vec![1,2,3],vec![1,3,3],vec![6,3,3],
            vec![3,5,1],vec![6,5,1],vec![2,5,1],vec![0,4,5],vec![4,6,2],
        ];
        assert_eq!(Solution::count_paths(7, roads), 4);
    }
    #[test]
    fn test_single_path() {
        assert_eq!(Solution::count_paths(2, vec![vec![0,1,1]]), 1);
    }
    #[test]
    fn test_two_equal_paths() {
        let roads = vec![vec![0,1,1],vec![1,2,1],vec![0,2,2]];
        assert_eq!(Solution::count_paths(3, roads), 2);
    }
}
```

**Time:** O((V + E) log V).  
**Space:** O(V + E).

**Rust note:** Using `u64` for distances avoids overflow when accumulating costs. The `ways` update must happen even for stale-cost entries if `nc == dist[v]` — but since we skip on `cost > dist[u]`, we only process each node's outgoing edges once per truly-shortest-path arrival.

---

## LC1129. Shortest Path with Alternating Colors

**Problem.** In a graph with red and blue edges, find the shortest path from node `0` to every other node using alternating edge colors. Return `-1` for unreachable nodes.

**Approach 1 — BFS on (Node, Color) State Space (O(V+E) time, O(V+E) space).**
BFS on the expanded state `(node, last_color)`. From each state, only traverse edges of the
opposite color. The BFS depth when any state with `node = target` is first dequeued is the
shortest path length with alternating colors.

```rust
use std::collections::VecDeque;

struct Solution;

impl Solution {
    pub fn shortest_alternating_paths(
        n: i32,
        red_edges: Vec<Vec<i32>>,
        blue_edges: Vec<Vec<i32>>,
    ) -> Vec<i32> {
        let n = n as usize;
        // adj[u] = list of (v, color): 0=red, 1=blue
        let mut adj: Vec<Vec<(usize, usize)>> = vec![vec![]; n];
        for e in &red_edges  { adj[e[0] as usize].push((e[1] as usize, 0)); }
        for e in &blue_edges { adj[e[0] as usize].push((e[1] as usize, 1)); }

        // dist[node][color] = shortest steps arriving at node via edge of `color`
        let mut dist = vec![[i32::MAX; 2]; n];
        dist[0][0] = 0;
        dist[0][1] = 0;

        // State: (node, last_color_used); start with both colors as valid first move
        let mut queue: VecDeque<(usize, usize, i32)> = VecDeque::new();
        queue.push_back((0, 0, 0)); // arrived at 0 via "red"
        queue.push_back((0, 1, 0)); // arrived at 0 via "blue"

        while let Some((u, color, steps)) = queue.pop_front() {
            let next_color = 1 - color;
            for &(v, ec) in &adj[u] {
                if ec == next_color && dist[v][ec] == i32::MAX {
                    dist[v][ec] = steps + 1;
                    queue.push_back((v, ec, steps + 1));
                }
            }
        }

        (0..n)
            .map(|i| {
                let best = dist[i][0].min(dist[i][1]);
                if best == i32::MAX { -1 } else { best }
            })
            .collect()
    }
}

#[cfg(test)]
mod tests_1129 {
    use super::*;
    #[test]
    fn test_basic() {
        let result = Solution::shortest_alternating_paths(
            3, vec![vec![0,1],vec![1,2]], vec![]
        );
        assert_eq!(result, vec![0, 1, -1]);
    }
    #[test]
    fn test_alternating() {
        let result = Solution::shortest_alternating_paths(
            3, vec![vec![0,1]], vec![vec![2,1]]
        );
        assert_eq!(result, vec![0, 1, -1]);
    }
    #[test]
    fn test_both_colors() {
        let result = Solution::shortest_alternating_paths(
            3, vec![vec![0,1],vec![0,2]], vec![vec![1,0]]
        );
        assert_eq!(result, vec![0, 1, 1]);
    }
}
```

**Time:** O(V + E) — each `(node, color)` state visited at most once.  
**Space:** O(V + E).

**Key insight:** Expanding state to `(node, last_color)` doubles the state space but enables standard BFS. This is the general technique for "constrained traversal" problems where the valid moves depend on how you arrived.

---

## 📝 Chapter Review Notes

### Critical Review

This chapter covers 22 advanced graph problems across six major algorithm categories. The solutions are idiomatic Rust 2024 and handle the key ergonomic friction points between Java and Rust graph code.

**Strengths:**
- The `Reverse<(cost, node)>` min-heap pattern is consistently applied across all Dijkstra problems and clearly explained in the reference section.
- The `OrdF64` newtype in LC #1514 correctly addresses Rust's refusal to implement `Ord` for `f64` — a genuine pitfall for developers accustomed to Java's `Double.compare`.
- Tarjan's algorithm (LC #1192) uses the idiomatic nested-`fn` pattern rather than closures, avoiding borrow-checker conflicts with multiple `&mut` borrows.
- The virtual node trick in LC #1168 is a clean reduction that avoids special-casing well vs. pipe decisions.
- Bellman-Ford's snapshot clone (LC #787) is explicitly motivated — without it the algorithm silently over-relaxes within a single round.

**Potential issues and observations:**

- **LC #310 edge case:** The filter `!adj[i].is_empty() || n == 1` after pruning collects the remaining nodes. Nodes fully stripped of neighbors but still in the tree (when `remaining == 2`) are handled by the `remaining > 2` loop exit. The logic is correct but the final collection step could be cleaner with an explicit `leaves` return.
- **LC #14 (Accounts Merge):** Using a free function `find` inside the method avoids borrow issues, but the lack of union-by-rank means worst-case path length is O(n). Path halving mitigates this in practice.
- **LC #9 (Alien Dictionary):** The BFS queue is explicitly sorted to produce deterministic output for testing. On LeetCode, any valid topological order is accepted; the sort is not required for correctness.
- **LC #21 (Number of Ways):** The `ways` update for equal-cost paths must not be gated on `cost > dist[u]` — the current code correctly updates `ways[v]` even when the current node's cost is not stale, because the stale check only skips the node's outgoing edges.

### Fact-Check Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| `f64` not `Ord` — max-heap for probabilities requires newtype wrapper | High | `OrdF64` newtype with manual `Ord` impl in LC #1514 |
| Bellman-Ford must snapshot `dist` before each round to prevent same-round chaining | High | `let prev = dist.clone()` before inner loop in LC #787 |
| `u32::MAX + w` can overflow — use `i64::MAX / 2` for large-weight problems | Medium | `i64::MAX / 2` used in LC #787; `u32::MAX` safe for LC #743 (weights ≤ 100) |
| Tarjan's must distinguish `parent` edge from genuine back edge | High | `v != parent` guard in DFS in LC #1192 |
| Union-Find `find` inside `impl Solution` methods causes borrow issues | Medium | Nested free `fn find(parent: &mut Vec<usize>, ...)` pattern used throughout |
| Floyd-Warshall overflow: `dist[i][k] + dist[k][j]` can overflow `i32` | High | Guard `if dist[i][k] < INF && dist[k][j] < INF` applied in LC #1334 and LC #1334 reference template |
| `BinaryHeap` is max-heap — min-heap requires `Reverse<T>` | High | Documented in reference section and applied to all Dijkstra solutions |
| Alien Dictionary — `start_with` on `Vec<char>` requires slice comparison | Medium | `w1.starts_with(w2.as_slice())` correctly compares `Vec<char>` prefixes |
| LC #310 final collection via `(0..n).filter(!adj[i].is_empty())` is incorrect — leaf nodes stripped during pruning have empty adj sets and are falsely excluded | High | Fixed: return `leaves` directly after the loop; `leaves` always holds the centroid(s) after pruning |
| Modular arithmetic in LC #1976 must use `u64` to prevent `i32` overflow on `ways` accumulation | Medium | `ways: Vec<u64>` and `MOD: u64` used; final cast to `i32` is safe since result < MOD |
