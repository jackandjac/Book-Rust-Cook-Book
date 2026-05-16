# LC-13: Advanced Graph Algorithms — Java 17+ Edition

> **Companion chapter to `lc13-advanced-graphs.md`.** Every problem from the Rust chapter is reproduced here in idiomatic Java 17+. Solutions use `class Solution { public ... }` with a `public static void main` test driver. No JUnit, no `assert` keyword — all checks use `throw new AssertionError("msg: got " + actual)`.

---

## Algorithm Reference Templates

### Dijkstra's Algorithm (Min-Heap)

```java
import java.util.*;

// PriorityQueue<int[]> is a min-heap on int[0] (distance).
// int[] entry = {dist, node}
static int[] dijkstra(List<int[]>[] graph, int src, int n) {
    int[] dist = new int[n];
    Arrays.fill(dist, Integer.MAX_VALUE);
    dist[src] = 0;
    // Comparator: smallest distance first (min-heap)
    PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
    pq.offer(new int[]{0, src});
    while (!pq.isEmpty()) {
        var top = pq.poll();
        int d = top[0], u = top[1];
        if (d > dist[u]) continue;          // stale entry — skip
        for (int[] e : graph[u]) {
            int v = e[0], w = e[1];
            if (dist[u] + w < dist[v]) {
                dist[v] = dist[u] + w;
                pq.offer(new int[]{dist[v], v});
            }
        }
    }
    return dist;
}
```

> **Java vs Rust:** Java's `PriorityQueue` is a **min-heap by default**; comparisons are transparent. Rust's `BinaryHeap` is a **max-heap** — you must wrap entries in `std::cmp::Reverse` to get min-heap behavior. In Java, `Comparator.comparingInt(a -> a[0])` handles ordering explicitly.

### Bellman-Ford Template

```java
static long[] bellmanFord(int[][] edges, int src, int n) {
    long[] dist = new long[n];
    Arrays.fill(dist, Long.MAX_VALUE / 2);
    dist[src] = 0;
    for (int round = 0; round < n - 1; round++) {
        long[] prev = dist.clone();          // snapshot — no same-round chaining
        for (int[] e : edges) {
            int u = e[0], v = e[1], w = e[2];
            if (prev[u] < Long.MAX_VALUE / 2) {
                dist[v] = Math.min(dist[v], prev[u] + w);
            }
        }
    }
    return dist;
}
```

### Floyd-Warshall Template

```java
static int[][] floydWarshall(int n, int[][] edges) {
    final int INF = Integer.MAX_VALUE / 2;   // half-MAX avoids overflow on addition
    int[][] dist = new int[n][n];
    for (int[] row : dist) Arrays.fill(row, INF);
    for (int i = 0; i < n; i++) dist[i][i] = 0;
    for (int[] e : edges) {
        dist[e[0]][e[1]] = e[2];
        dist[e[1]][e[0]] = e[2];             // omit for directed graphs
    }
    for (int k = 0; k < n; k++)
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                if (dist[i][k] < INF && dist[k][j] < INF)
                    dist[i][j] = Math.min(dist[i][j], dist[i][k] + dist[k][j]);
    return dist;
}
```

> **Java vs Rust:** Use `Integer.MAX_VALUE / 2` (not `Integer.MAX_VALUE`) as infinity so that `dist[i][k] + dist[k][j]` never overflows `int`. Rust uses `i32::MAX / 2` for the same reason.

### Topological Sort — Kahn's BFS (In-Degree)

```java
static int[] kahnTopo(int n, List<Integer>[] adj) {
    int[] inDeg = new int[n];
    for (int u = 0; u < n; u++)
        for (int v : adj[u]) inDeg[v]++;
    Queue<Integer> q = new ArrayDeque<>();
    for (int i = 0; i < n; i++)
        if (inDeg[i] == 0) q.offer(i);
    int[] order = new int[n];
    int idx = 0;
    while (!q.isEmpty()) {
        int u = q.poll();
        order[idx++] = u;
        for (int v : adj[u])
            if (--inDeg[v] == 0) q.offer(v);
    }
    return idx == n ? order : new int[0];   // empty = cycle detected
}
```

### Topological Sort — DFS Post-Order

```java
static int[] dfsTopo(int n, List<Integer>[] adj) {
    int[] state = new int[n];               // 0=unvisited 1=in-progress 2=done
    int[] order = new int[n];
    int[] idx = {n};                        // fill order from back
    boolean[] hasCycle = {false};
    for (int i = 0; i < n; i++)
        if (state[i] == 0)
            dfs(i, adj, state, order, idx, hasCycle);
    return hasCycle[0] ? new int[0] : order;
}

private static void dfs(int u, List<Integer>[] adj, int[] state,
                        int[] order, int[] idx, boolean[] hasCycle) {
    if (hasCycle[0]) return;
    state[u] = 1;
    for (int v : adj[u]) {
        if (state[v] == 1) { hasCycle[0] = true; return; }
        if (state[v] == 0) dfs(v, adj, state, order, idx, hasCycle);
    }
    state[u] = 2;
    order[--idx[0]] = u;
}
```

### Union-Find (Path Compression + Union by Rank)

```java
static class UnionFind {
    int[] parent, rank;
    int count;

    UnionFind(int n) {
        parent = new int[n]; rank = new int[n]; count = n;
        for (int i = 0; i < n; i++) parent[i] = i;
    }
    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }
    boolean union(int x, int y) {
        int rx = find(x), ry = find(y);
        if (rx == ry) return false;
        if (rank[rx] < rank[ry]) { int t = rx; rx = ry; ry = t; }
        parent[ry] = rx;
        if (rank[rx] == rank[ry]) rank[rx]++;
        count--;
        return true;
    }
    boolean connected(int x, int y) { return find(x) == find(y); }
}
```

> **Java vs Rust:** Java's `UnionFind` lives naturally as a static inner class. Rust uses a standalone `struct UnionFind` with `impl` blocks. Both express path compression the same way; Rust ownership rules prevent the `find` method from accidentally mutating unrelated state.

### Kruskal's MST

```java
static int kruskal(int n, int[][] edges) {
    Arrays.sort(edges, Comparator.comparingInt(a -> a[2]));
    var uf = new UnionFind(n);
    int total = 0;
    for (int[] e : edges)
        if (uf.union(e[0], e[1])) total += e[2];
    return total;
}
```

### Prim's MST

```java
static int prim(int n, List<int[]>[] graph) {
    boolean[] inMST = new boolean[n];
    PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
    pq.offer(new int[]{0, 0});
    int total = 0, count = 0;
    while (!pq.isEmpty() && count < n) {
        var top = pq.poll();
        int cost = top[0], u = top[1];
        if (inMST[u]) continue;
        inMST[u] = true;
        total += cost;
        count++;
        for (int[] e : graph[u])
            if (!inMST[e[0]]) pq.offer(new int[]{e[1], e[0]});
    }
    return total;
}
```

---

## Problem Overview

| # | Problem | Difficulty | Category |
|---|---------|-----------|----------|
| LC 743  | Network Delay Time | Medium | Dijkstra |
| LC 1631 | Path with Minimum Effort | Medium | Dijkstra on Grid |
| LC 787  | Cheapest Flights Within K Stops | Medium | Bellman-Ford |
| LC 778  | Swim in Rising Water | Hard | Dijkstra |
| LC 1334 | City With Smallest Neighbors | Medium | Floyd-Warshall |
| LC 1514 | Path with Maximum Probability | Medium | Dijkstra Max-Heap |
| LC 207  | Course Schedule | Medium | Kahn's Topo Sort |
| LC 210  | Course Schedule II | Medium | Kahn's Topo Sort |
| LC 269  | Alien Dictionary | Hard | Topo Sort |
| LC 444  | Sequence Reconstruction | Medium | Unique Topo Sort |
| LC 310  | Minimum Height Trees | Medium | Leaf Trimming |
| LC 1136 | Parallel Courses | Medium | Topo Sort + Depth |
| LC 547  | Number of Provinces | Medium | Union-Find |
| LC 721  | Accounts Merge | Medium | Union-Find + Strings |
| LC 684  | Redundant Connection | Medium | Union-Find Cycle |
| LC 827  | Making a Large Island | Hard | Union-Find + Grid |
| LC 990  | Satisfiability of Equality Equations | Medium | Union-Find on Chars |
| LC 1584 | Min Cost to Connect All Points | Medium | Prim's MST |
| LC 1168 | Optimize Water Distribution | Hard | MST + Virtual Node |
| LC 1192 | Critical Connections in a Network | Hard | Tarjan's Bridges |
| LC 1976 | Number of Ways to Arrive at Destination | Medium | Dijkstra + Count |
| LC 1129 | Shortest Path with Alternating Colors | Medium | BFS on Edge-Colored Graph |

---

## LC743. Network Delay Time

**Problem.** Directed weighted graph with `n` nodes. Signal sent from `k`. Return the minimum time for all nodes to receive it, or `-1` if any node is unreachable.

**Approach 1 — Dijkstra's Shortest Path (O((V+E) log V) time, O(V+E) space).**
Dijkstra from `k`; the answer is the maximum of all shortest distances to other nodes. Java's
`PriorityQueue<int[]>` with `Comparator.comparingInt(a -> a[0])` gives a min-heap by distance.
Return -1 if any distance remains `Integer.MAX_VALUE` (unreachable).

```java
import java.util.*;

class Solution743 {
    public int networkDelayTime(int[][] times, int n, int k) {
        List<int[]>[] graph = new ArrayList[n + 1];
        for (int i = 1; i <= n; i++) graph[i] = new ArrayList<>();
        for (int[] t : times) graph[t[0]].add(new int[]{t[1], t[2]});

        int[] dist = new int[n + 1];
        Arrays.fill(dist, Integer.MAX_VALUE);
        dist[k] = 0;

        // min-heap: {distance, node}
        PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
        pq.offer(new int[]{0, k});

        while (!pq.isEmpty()) {
            var top = pq.poll();
            int d = top[0], u = top[1];
            if (d > dist[u]) continue;         // stale entry
            for (int[] e : graph[u]) {
                int v = e[0], w = e[1];
                if (dist[u] + w < dist[v]) {
                    dist[v] = dist[u] + w;
                    pq.offer(new int[]{dist[v], v});
                }
            }
        }

        int max = 0;
        for (int i = 1; i <= n; i++) {
            if (dist[i] == Integer.MAX_VALUE) return -1;
            max = Math.max(max, dist[i]);
        }
        return max;
    }

    public static void main(String[] args) {
        var sol = new Solution743();

        int actual = sol.networkDelayTime(new int[][]{{2,1,1},{2,3,1},{3,4,1}}, 4, 2);
        if (actual != 2) throw new AssertionError("test1: expected 2, got " + actual);

        actual = sol.networkDelayTime(new int[][]{{1,2,1}}, 2, 2);
        if (actual != -1) throw new AssertionError("test2: expected -1, got " + actual);

        actual = sol.networkDelayTime(new int[][]{}, 1, 1);
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        System.out.println("LC 743 all tests passed");
    }
}
```

**Time:** O((E + V) log V). **Space:** O(V + E).

**Java note:** Nodes are 1-indexed on LeetCode; allocate `dist[n+1]` and skip index 0. Use `var` for the polled array to reduce verbosity.

---

## LC1631. Path with Minimum Effort

**Problem.** `m×n` grid. Find path top-left to bottom-right minimising the *maximum absolute difference* between consecutive cells.

**Approach 1 — Dijkstra as Bottleneck Shortest Path (O(R·C·log(R·C)) time, O(R·C) space).**
Dijkstra where the edge weight between adjacent cells is `|h[r1][c1] - h[r2][c2]|` and the
path cost is the running maximum (not sum). The `PriorityQueue` is keyed by this max effort.

```java
import java.util.*;

class Solution1631 {
    public int minimumEffortPath(int[][] heights) {
        int rows = heights.length, cols = heights[0].length;
        int[][] dist = new int[rows][cols];
        for (int[] row : dist) Arrays.fill(row, Integer.MAX_VALUE);
        dist[0][0] = 0;

        // {effort, row, col}
        PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
        pq.offer(new int[]{0, 0, 0});
        int[][] dirs = {{0,1},{0,-1},{1,0},{-1,0}};

        while (!pq.isEmpty()) {
            var top = pq.poll();
            int effort = top[0], r = top[1], c = top[2];
            if (r == rows - 1 && c == cols - 1) return effort;
            if (effort > dist[r][c]) continue;  // stale entry
            for (int[] d : dirs) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                int edge = Math.abs(heights[r][c] - heights[nr][nc]);
                int newEffort = Math.max(effort, edge);
                if (newEffort < dist[nr][nc]) {
                    dist[nr][nc] = newEffort;
                    pq.offer(new int[]{newEffort, nr, nc});
                }
            }
        }
        return 0;
    }

    public static void main(String[] args) {
        var sol = new Solution1631();

        int actual = sol.minimumEffortPath(new int[][]{{1,2,2},{3,8,2},{5,3,5}});
        if (actual != 2) throw new AssertionError("test1: expected 2, got " + actual);

        actual = sol.minimumEffortPath(new int[][]{{7}});
        if (actual != 0) throw new AssertionError("test2: expected 0, got " + actual);

        actual = sol.minimumEffortPath(new int[][]{{1,1,1},{1,1,1}});
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        System.out.println("LC 1631 all tests passed");
    }
}
```

**Time:** O(m·n · log(m·n)). **Space:** O(m·n).

**Java note:** Early return from inside the loop is safe here — once the destination is popped it carries the optimal effort.

---

## LC787. Cheapest Flights Within K Stops

**Problem.** Cheapest flight from `src` to `dst` using at most `k` stops. Return `-1` if no path exists.

**Approach 1 — Bellman-Ford with Snapshot Clone (O(k·E) time, O(V) space).**
Bellman-Ford with exactly `k+1` relaxation rounds. Clone the distance array before each round
(`int[] prev = dist.clone()`) to prevent within-round chaining — otherwise a multi-hop path
could be relaxed in a single round, violating the `k`-stop constraint.

```java
import java.util.*;

class Solution787 {
    public int findCheapestPrice(int n, int[][] flights, int src, int dst, int k) {
        long[] dist = new long[n];
        Arrays.fill(dist, Long.MAX_VALUE / 2);
        dist[src] = 0;

        // k stops = k+1 edges = k+1 relaxation rounds
        for (int round = 0; round <= k; round++) {
            long[] prev = dist.clone();           // snapshot prevents same-round chaining
            for (int[] f : flights) {
                int u = f[0], v = f[1], w = f[2];
                if (prev[u] < Long.MAX_VALUE / 2)
                    dist[v] = Math.min(dist[v], prev[u] + w);
            }
        }

        return dist[dst] >= Long.MAX_VALUE / 2 ? -1 : (int) dist[dst];
    }

    public static void main(String[] args) {
        var sol = new Solution787();
        int[][] flights = {{0,1,100},{1,2,100},{0,2,500}};

        int actual = sol.findCheapestPrice(3, flights, 0, 2, 1);
        if (actual != 200) throw new AssertionError("test1: expected 200, got " + actual);

        actual = sol.findCheapestPrice(3, flights, 0, 2, 0);
        if (actual != 500) throw new AssertionError("test2: expected 500, got " + actual);

        actual = sol.findCheapestPrice(3, new int[][]{{0,1,100}}, 0, 2, 1);
        if (actual != -1) throw new AssertionError("test3: expected -1, got " + actual);

        System.out.println("LC 787 all tests passed");
    }
}
```

**Time:** O(k · E). **Space:** O(V).

**Java note:** Use `long` for distances. `Long.MAX_VALUE / 2` as infinity avoids overflow when computing `prev[u] + w`. The `.clone()` on a `long[]` performs a shallow copy of primitives, which is exactly what is needed.

---

## LC778. Swim in Rising Water

**Problem.** Grid where `grid[r][c]` is elevation. Find minimum time `t` so a path from `(0,0)` to `(n-1,n-1)` exists where every cell on the path has elevation <= `t`.

**Approach 1 — Dijkstra as Minimax Path (O(n² log n) time, O(n²) space).**
Dijkstra where the cost to reach a cell is `max(cost_so_far, grid[nr][nc])`. The shortest-path
distance from `(0,0)` to `(n-1,n-1)` equals the minimum possible peak water level on any path.

```java
import java.util.*;

class Solution778 {
    public int swimInWater(int[][] grid) {
        int n = grid.length;
        int[][] dist = new int[n][n];
        for (int[] row : dist) Arrays.fill(row, Integer.MAX_VALUE);
        dist[0][0] = grid[0][0];

        // {time, row, col}
        PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
        pq.offer(new int[]{grid[0][0], 0, 0});
        int[][] dirs = {{0,1},{0,-1},{1,0},{-1,0}};

        while (!pq.isEmpty()) {
            var top = pq.poll();
            int t = top[0], r = top[1], c = top[2];
            if (r == n - 1 && c == n - 1) return t;
            if (t > dist[r][c]) continue;          // stale entry
            for (int[] d : dirs) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
                int nt = Math.max(t, grid[nr][nc]);
                if (nt < dist[nr][nc]) {
                    dist[nr][nc] = nt;
                    pq.offer(new int[]{nt, nr, nc});
                }
            }
        }
        return -1; // unreachable in valid input
    }

    public static void main(String[] args) {
        var sol = new Solution778();

        int actual = sol.swimInWater(new int[][]{{0,2},{1,3}});
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        actual = sol.swimInWater(new int[][]{{0}});
        if (actual != 0) throw new AssertionError("test2: expected 0, got " + actual);

        int[][] grid = {{0,1,2,3,4},{24,23,22,21,5},{12,13,14,15,16},{11,17,18,19,20},{10,9,8,7,6}};
        actual = sol.swimInWater(grid);
        if (actual != 16) throw new AssertionError("test3: expected 16, got " + actual);

        System.out.println("LC 778 all tests passed");
    }
}
```

**Time:** O(n² log n). **Space:** O(n²).

**Java note:** Pattern is identical to LC 1631 but the cost function is `max` instead of `|diff|`. The stale-entry check `if (t > dist[r][c]) continue` is essential — without it the heap may process millions of outdated entries on large grids.

---

## LC1334. Find the City With the Smallest Number of Neighbors

**Problem.** Find the city with fewest reachable neighbors within `distanceThreshold`. Tie-break: largest index.

**Approach 1 — Floyd-Warshall All-Pairs Shortest Paths (O(V³) time, O(V²) space).**
Floyd-Warshall for all-pairs shortest paths, then count cities reachable within `distanceThreshold`
for each city. Return the city with the fewest reachable neighbors (ties broken by highest index).

```java
import java.util.*;

class Solution1334 {
    public int findTheCity(int n, int[][] edges, int distanceThreshold) {
        final int INF = Integer.MAX_VALUE / 2;   // half-MAX avoids overflow
        int[][] dist = new int[n][n];
        for (int[] row : dist) Arrays.fill(row, INF);
        for (int i = 0; i < n; i++) dist[i][i] = 0;
        for (int[] e : edges) {
            dist[e[0]][e[1]] = e[2];
            dist[e[1]][e[0]] = e[2];
        }

        // Floyd-Warshall
        for (int k = 0; k < n; k++)
            for (int i = 0; i < n; i++)
                for (int j = 0; j < n; j++)
                    if (dist[i][k] < INF && dist[k][j] < INF)
                        dist[i][j] = Math.min(dist[i][j], dist[i][k] + dist[k][j]);

        int bestCity = 0, bestCount = n + 1;
        for (int i = 0; i < n; i++) {
            int count = 0;
            for (int j = 0; j < n; j++)
                if (j != i && dist[i][j] <= distanceThreshold) count++;
            // >= for tie-breaking: prefer larger index
            if (count <= bestCount) {
                bestCount = count;
                bestCity = i;
            }
        }
        return bestCity;
    }

    public static void main(String[] args) {
        var sol = new Solution1334();

        int actual = sol.findTheCity(4, new int[][]{{0,1,3},{1,2,1},{1,3,4},{2,3,1}}, 4);
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        actual = sol.findTheCity(5, new int[][]{{0,1,2},{0,4,8},{1,2,3},{1,4,2},{2,3,1},{3,4,1}}, 2);
        if (actual != 0) throw new AssertionError("test2: expected 0, got " + actual);

        System.out.println("LC 1334 all tests passed");
    }
}
```

**Time:** O(n³). **Space:** O(n²).

**Java note:** `Integer.MAX_VALUE / 2` is the standard Java idiom for "infinity in an int matrix" — division by 2 ensures `INF + INF` does not overflow. The guard `dist[i][k] < INF && dist[k][j] < INF` is still required.

---

## LC1514. Path with Maximum Probability

**Problem.** Find the maximum probability path from `start` to `end`. Edge weights are probabilities in `[0,1]`.

**Approach 1 — Dijkstra with Max-Heap (O((V+E) log V) time, O(V+E) space).**
Maximize probability using Dijkstra with a max-heap. Java's default `PriorityQueue` is a min-heap,
so use `(a, b) -> Double.compare(b[0], a[0])` to invert ordering. Multiply probabilities along
edges instead of summing costs.

```java
import java.util.*;

class Solution1514 {
    public double maxProbability(int n, int[][] edges, double[] succProb,
                                 int startNode, int endNode) {
        List<double[]>[] graph = new ArrayList[n];
        for (int i = 0; i < n; i++) graph[i] = new ArrayList<>();
        for (int i = 0; i < edges.length; i++) {
            int u = edges[i][0], v = edges[i][1];
            double p = succProb[i];
            graph[u].add(new double[]{v, p});
            graph[v].add(new double[]{u, p});
        }

        double[] prob = new double[n];
        prob[startNode] = 1.0;
        // max-heap: largest probability first
        PriorityQueue<double[]> pq = new PriorityQueue<>((a, b) -> Double.compare(b[0], a[0]));
        pq.offer(new double[]{1.0, startNode});

        while (!pq.isEmpty()) {
            var top = pq.poll();
            double p = top[0];
            int u = (int) top[1];
            if (u == endNode) return p;
            if (p < prob[u]) continue;          // stale entry
            for (double[] e : graph[u]) {
                int v = (int) e[0];
                double np = p * e[1];
                if (np > prob[v]) {
                    prob[v] = np;
                    pq.offer(new double[]{np, v});
                }
            }
        }
        return 0.0;
    }

    public static void main(String[] args) {
        var sol = new Solution1514();

        double actual = sol.maxProbability(3, new int[][]{{0,1},{1,2},{0,2}},
                                           new double[]{0.5,0.5,0.2}, 0, 2);
        if (Math.abs(actual - 0.25) > 1e-9)
            throw new AssertionError("test1: expected ~0.25, got " + actual);

        actual = sol.maxProbability(3, new int[][]{{0,1}}, new double[]{0.5}, 0, 2);
        if (actual != 0.0) throw new AssertionError("test2: expected 0.0, got " + actual);

        System.out.println("LC 1514 all tests passed");
    }
}
```

**Time:** O((V + E) log V). **Space:** O(V + E).

> **Java vs Rust:** Java can use `PriorityQueue<double[]>` with `(a,b) -> Double.compare(b[0], a[0])` for a max-heap directly. Rust's `BinaryHeap<f64>` is blocked because `f64` does not implement `Ord` (due to NaN), requiring an `OrdF64` newtype wrapper with a manual `Ord` impl. Java's `Double.compare` handles NaN gracefully per its contract.

---

## LC207. Course Schedule

**Problem.** Given `numCourses` and prerequisite pairs, determine if all courses can be finished (no cycle).

**Approach 1 — Kahn's BFS Cycle Detection (O(V+E) time, O(V+E) space).**
Kahn's BFS topological sort: if the total processed node count equals `n`, the graph is a DAG
(no cycle). Otherwise a cycle exists and not all courses can be finished.

```java
import java.util.*;

class Solution207 {
    public boolean canFinish(int numCourses, int[][] prerequisites) {
        List<Integer>[] adj = new ArrayList[numCourses];
        int[] inDeg = new int[numCourses];
        for (int i = 0; i < numCourses; i++) adj[i] = new ArrayList<>();
        for (int[] p : prerequisites) {
            adj[p[1]].add(p[0]);
            inDeg[p[0]]++;
        }
        Queue<Integer> q = new ArrayDeque<>();
        for (int i = 0; i < numCourses; i++)
            if (inDeg[i] == 0) q.offer(i);
        int processed = 0;
        while (!q.isEmpty()) {
            int u = q.poll();
            processed++;
            for (int v : adj[u])
                if (--inDeg[v] == 0) q.offer(v);
        }
        return processed == numCourses;
    }

    public static void main(String[] args) {
        var sol = new Solution207();

        boolean actual = sol.canFinish(2, new int[][]{{1,0}});
        if (!actual) throw new AssertionError("test1: expected true, got false");

        actual = sol.canFinish(2, new int[][]{{1,0},{0,1}});
        if (actual) throw new AssertionError("test2: expected false, got true");

        actual = sol.canFinish(3, new int[][]{});
        if (!actual) throw new AssertionError("test3: expected true, got false");

        System.out.println("LC 207 all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java note:** `ArrayDeque` is preferred over `LinkedList` as a `Queue` — it avoids boxing overhead and has better cache performance.

---

## LC210. Course Schedule II

**Problem.** Return a valid course ordering, or an empty array if a cycle exists.

**Approach 1 — Kahn's BFS Topological Order (O(V+E) time, O(V+E) space).**
Kahn's BFS collecting nodes in dequeue order gives one valid topological ordering. Return an
empty array if fewer than `n` nodes are dequeued (cycle detected).

```java
import java.util.*;

class Solution210 {
    public int[] findOrder(int numCourses, int[][] prerequisites) {
        List<Integer>[] adj = new ArrayList[numCourses];
        int[] inDeg = new int[numCourses];
        for (int i = 0; i < numCourses; i++) adj[i] = new ArrayList<>();
        for (int[] p : prerequisites) {
            adj[p[1]].add(p[0]);
            inDeg[p[0]]++;
        }
        Queue<Integer> q = new ArrayDeque<>();
        for (int i = 0; i < numCourses; i++)
            if (inDeg[i] == 0) q.offer(i);
        int[] order = new int[numCourses];
        int idx = 0;
        while (!q.isEmpty()) {
            int u = q.poll();
            order[idx++] = u;
            for (int v : adj[u])
                if (--inDeg[v] == 0) q.offer(v);
        }
        return idx == numCourses ? order : new int[0];
    }

    public static void main(String[] args) {
        var sol = new Solution210();

        int[] actual = sol.findOrder(2, new int[][]{{1,0}});
        if (!Arrays.equals(actual, new int[]{0, 1}))
            throw new AssertionError("test1: got " + Arrays.toString(actual));

        actual = sol.findOrder(4, new int[][]{{1,0},{2,0},{3,1},{3,2}});
        if (actual.length != 4)
            throw new AssertionError("test2: expected length 4, got " + actual.length);

        actual = sol.findOrder(2, new int[][]{{0,1},{1,0}});
        if (actual.length != 0)
            throw new AssertionError("test3: expected empty, got " + Arrays.toString(actual));

        System.out.println("LC 210 all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java note:** Returning `new int[0]` (empty array) for cycle detection matches the LeetCode contract and avoids null.

---

## LC269. Alien Dictionary

**Problem.** Given a sorted list of alien-language words, determine the character ordering. Return `""` if invalid.

**Approach 1 — Graph Construction + Kahn's BFS Topological Sort (O(C + U) time, O(U) space).**
Extract ordering constraints by comparing adjacent word pairs at the first differing character.
Run Kahn's BFS on the 26-character graph. Return `""` if a cycle is detected or if a longer
word precedes a prefix word (invalid input).

```java
import java.util.*;

class Solution269 {
    public String alienOrder(String[] words) {
        Map<Character, Set<Character>> adj = new HashMap<>();
        Map<Character, Integer> inDeg = new HashMap<>();

        // Initialize all characters
        for (String word : words)
            for (char c : word.toCharArray()) {
                adj.putIfAbsent(c, new HashSet<>());
                inDeg.putIfAbsent(c, 0);
            }

        // Build edges from adjacent word pairs
        for (int i = 0; i < words.length - 1; i++) {
            String w1 = words[i], w2 = words[i + 1];
            int minLen = Math.min(w1.length(), w2.length());
            // If w2 is a proper prefix of w1, the ordering is invalid
            if (w1.length() > w2.length() && w1.startsWith(w2)) return "";
            for (int j = 0; j < minLen; j++) {
                char c1 = w1.charAt(j), c2 = w2.charAt(j);
                if (c1 != c2) {
                    if (adj.get(c1).add(c2))
                        inDeg.put(c2, inDeg.get(c2) + 1);
                    break;
                }
            }
        }

        // Kahn's BFS — use TreeMap/sorted queue for deterministic output
        Queue<Character> q = new PriorityQueue<>();
        for (var entry : inDeg.entrySet())
            if (entry.getValue() == 0) q.offer(entry.getKey());

        StringBuilder sb = new StringBuilder();
        while (!q.isEmpty()) {
            char c = q.poll();
            sb.append(c);
            for (char nb : adj.get(c)) {
                inDeg.put(nb, inDeg.get(nb) - 1);
                if (inDeg.get(nb) == 0) q.offer(nb);
            }
        }
        return sb.length() == inDeg.size() ? sb.toString() : "";
    }

    public static void main(String[] args) {
        var sol = new Solution269();

        String actual = sol.alienOrder(new String[]{"wrt","wrf","er","ett","rftt"});
        if (actual.isEmpty() || actual.length() != 5)
            throw new AssertionError("test1: expected 5-char result, got: " + actual);

        actual = sol.alienOrder(new String[]{"abc","ab"});
        if (!actual.isEmpty())
            throw new AssertionError("test2: expected empty, got: " + actual);

        actual = sol.alienOrder(new String[]{"z","x","z"});
        if (!actual.isEmpty())
            throw new AssertionError("test3: expected empty (cycle), got: " + actual);

        System.out.println("LC 269 all tests passed");
    }
}
```

**Time:** O(C) where C is total length of all words. **Space:** O(1) — at most 26 characters.

**Java note:** Using `PriorityQueue<Character>` (natural ordering) for the BFS queue produces lexicographically deterministic output, which is useful for tests. `Set<Character>` in the adjacency map prevents duplicate edges from inflating in-degrees.

---

## LC444. Sequence Reconstruction

**Problem.** Determine if `nums` is the *only* sequence reconstructible from `sequences`. Requires a unique topological ordering.

**Approach 1 — Kahn's BFS with Uniqueness Check (O(V+E) time, O(V+E) space).**
Kahn's BFS uniqueness check: at each step, if more than one node has in-degree 0, there are
multiple valid orderings, so `nums` is not the unique reconstruction. Also verify all `1..=n`
appear in at least one sequence.

```java
import java.util.*;

class Solution444 {
    public boolean sequenceReconstruction(int[] nums, int[][] sequences) {
        int n = nums.length;
        List<Integer>[] adj = new ArrayList[n + 1];
        int[] inDeg = new int[n + 1];
        boolean[] seen = new boolean[n + 1];
        for (int i = 1; i <= n; i++) adj[i] = new ArrayList<>();

        for (int[] seq : sequences) {
            for (int x : seq) {
                if (x < 1 || x > n) return false;
                seen[x] = true;
            }
            for (int i = 0; i < seq.length - 1; i++) {
                int a = seq[i], b = seq[i + 1];
                adj[a].add(b);
                inDeg[b]++;
            }
        }

        // All values 1..n must appear
        for (int i = 1; i <= n; i++) if (!seen[i]) return false;

        Queue<Integer> q = new ArrayDeque<>();
        for (int i = 1; i <= n; i++)
            if (inDeg[i] == 0) q.offer(i);

        int[] order = new int[n];
        int idx = 0;
        while (!q.isEmpty()) {
            if (q.size() > 1) return false;  // ambiguous — not unique
            int u = q.poll();
            order[idx++] = u;
            for (int v : adj[u])
                if (--inDeg[v] == 0) q.offer(v);
        }

        if (idx != n) return false;
        for (int i = 0; i < n; i++)
            if (order[i] != nums[i]) return false;
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution444();

        boolean actual = sol.sequenceReconstruction(new int[]{1,2,3},
            new int[][]{{1,2},{1,3},{2,3}});
        if (!actual) throw new AssertionError("test1: expected true, got false");

        actual = sol.sequenceReconstruction(new int[]{1,2,3}, new int[][]{{1,2}});
        if (actual) throw new AssertionError("test2: expected false, got true");

        actual = sol.sequenceReconstruction(new int[]{1}, new int[][]{{1}});
        if (!actual) throw new AssertionError("test3: expected true, got false");

        System.out.println("LC 444 all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java note:** The `q.size() > 1` check must occur *before* polling, not after — by the time the node is polled the queue may have grown from later insertions that should not be counted yet.

---

## LC310. Minimum Height Trees

**Problem.** Find all tree roots that minimize the tree height. Returns at most 2 roots.

**Approach 1 — Iterative Leaf Pruning (O(V+E) time, O(V+E) space).**
Iteratively remove all current leaf nodes (degree 1) until at most 2 nodes remain — these are
the MHT roots. This is equivalent to BFS topological sort inward from the periphery.

```java
import java.util.*;

class Solution310 {
    public List<Integer> findMinHeightTrees(int n, int[][] edges) {
        if (n == 1) return List.of(0);
        if (n == 2) return List.of(0, 1);

        List<Integer>[] adj = new ArrayList[n];
        int[] degree = new int[n];
        for (int i = 0; i < n; i++) adj[i] = new ArrayList<>();
        for (int[] e : edges) {
            adj[e[0]].add(e[1]);
            adj[e[1]].add(e[0]);
            degree[e[0]]++;
            degree[e[1]]++;
        }

        List<Integer> leaves = new ArrayList<>();
        for (int i = 0; i < n; i++)
            if (degree[i] == 1) leaves.add(i);

        int remaining = n;
        while (remaining > 2) {
            remaining -= leaves.size();
            List<Integer> newLeaves = new ArrayList<>();
            for (int leaf : leaves) {
                for (int nb : adj[leaf]) {
                    if (--degree[nb] == 1) newLeaves.add(nb);
                }
            }
            leaves = newLeaves;
        }
        return leaves;
    }

    public static void main(String[] args) {
        var sol = new Solution310();

        var actual = sol.findMinHeightTrees(4, new int[][]{{1,0},{1,2},{1,3}});
        if (!actual.equals(List.of(1)))
            throw new AssertionError("test1: expected [1], got " + actual);

        actual = sol.findMinHeightTrees(6,
            new int[][]{{3,0},{3,1},{3,2},{3,4},{5,4}});
        var sorted = new ArrayList<>(actual);
        Collections.sort(sorted);
        if (!sorted.equals(List.of(3, 4)))
            throw new AssertionError("test2: expected [3,4], got " + sorted);

        actual = sol.findMinHeightTrees(1, new int[][]{});
        if (!actual.equals(List.of(0)))
            throw new AssertionError("test3: expected [0], got " + actual);

        System.out.println("LC 310 all tests passed");
    }
}
```

**Time:** O(V). **Space:** O(V + E).

**Java note:** Returning `leaves` directly after the loop avoids the common bug of trying to collect nodes by filtering `adj.isEmpty()` — pruned nodes have empty adjacency lists but are not the centroids.

---

## LC1136. Parallel Courses

**Problem.** `n` courses with prerequisite pairs. Return minimum semesters needed, or `-1` if a cycle exists.

**Approach 1 — Kahn's BFS with Depth Tracking (O(V+E) time, O(V+E) space).**
Kahn's BFS tracking the maximum depth (semester) for each node: `depth[v] = max(depth[u]+1)` for
all prerequisite edges `u→v`. Answer is the maximum depth. Return -1 if a cycle exists.

```java
import java.util.*;

class Solution1136 {
    public int minimumSemesters(int n, int[][] relations) {
        List<Integer>[] adj = new ArrayList[n + 1];
        int[] inDeg = new int[n + 1];
        int[] depth = new int[n + 1];
        for (int i = 1; i <= n; i++) { adj[i] = new ArrayList<>(); depth[i] = 1; }
        for (int[] r : relations) {
            adj[r[0]].add(r[1]);
            inDeg[r[1]]++;
        }

        Queue<Integer> q = new ArrayDeque<>();
        for (int i = 1; i <= n; i++)
            if (inDeg[i] == 0) q.offer(i);

        int processed = 0;
        while (!q.isEmpty()) {
            int u = q.poll();
            processed++;
            for (int v : adj[u]) {
                depth[v] = Math.max(depth[v], depth[u] + 1);
                if (--inDeg[v] == 0) q.offer(v);
            }
        }

        if (processed < n) return -1;
        int max = 0;
        for (int i = 1; i <= n; i++) max = Math.max(max, depth[i]);
        return max;
    }

    public static void main(String[] args) {
        var sol = new Solution1136();

        int actual = sol.minimumSemesters(3, new int[][]{{1,3},{2,3}});
        if (actual != 2) throw new AssertionError("test1: expected 2, got " + actual);

        actual = sol.minimumSemesters(3, new int[][]{{1,2},{2,3}});
        if (actual != 3) throw new AssertionError("test2: expected 3, got " + actual);

        actual = sol.minimumSemesters(3, new int[][]{{1,2},{2,3},{3,1}});
        if (actual != -1) throw new AssertionError("test3: expected -1, got " + actual);

        System.out.println("LC 1136 all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java note:** Nodes are 1-indexed here; allocate arrays of size `n+1`. The `depth` array starts at 1 (each course takes at least 1 semester with no prerequisites).

---

## LC547. Number of Provinces

**Problem.** Given an `n×n` adjacency matrix, count connected components.

**Approach 1 — Union-Find with Path Compression and Union by Rank (O(E·α(V)) time, O(V) space).**
Union-Find: union every connected pair. The number of provinces equals the remaining component
count (`uf.count`) after all unions.

```java
import java.util.*;

class Solution547 {
    static class UnionFind {
        int[] parent, rank;
        int count;
        UnionFind(int n) {
            parent = new int[n]; rank = new int[n]; count = n;
            for (int i = 0; i < n; i++) parent[i] = i;
        }
        int find(int x) {
            if (parent[x] != x) parent[x] = find(parent[x]);
            return parent[x];
        }
        void union(int x, int y) {
            int rx = find(x), ry = find(y);
            if (rx == ry) return;
            if (rank[rx] < rank[ry]) { int t = rx; rx = ry; ry = t; }
            parent[ry] = rx;
            if (rank[rx] == rank[ry]) rank[rx]++;
            count--;
        }
    }

    public int findCircleNum(int[][] isConnected) {
        int n = isConnected.length;
        var uf = new UnionFind(n);
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                if (isConnected[i][j] == 1) uf.union(i, j);
        return uf.count;
    }

    public static void main(String[] args) {
        var sol = new Solution547();

        int actual = sol.findCircleNum(new int[][]{{1,1,0},{1,1,0},{0,0,1}});
        if (actual != 2) throw new AssertionError("test1: expected 2, got " + actual);

        actual = sol.findCircleNum(new int[][]{{1,0,0},{0,1,0},{0,0,1}});
        if (actual != 3) throw new AssertionError("test2: expected 3, got " + actual);

        actual = sol.findCircleNum(new int[][]{{1,1},{1,1}});
        if (actual != 1) throw new AssertionError("test3: expected 1, got " + actual);

        System.out.println("LC 547 all tests passed");
    }
}
```

**Time:** O(n² · α(n)). **Space:** O(n).

**Java note:** Declaring `UnionFind` as a `static` inner class avoids holding a reference to the outer `Solution547` instance, which is important when the solution object is long-lived.

---

## LC721. Accounts Merge

**Problem.** Merge accounts sharing at least one email. Return sorted merged accounts.

**Approach 1 — Union-Find with Email String Keys (O(E·α(E) + E log E) time, O(E) space).**
Union-Find: map each email string to an integer index via a `HashMap`. Union all emails within
the same account. Group all emails by their root index, sort alphabetically, and prepend the
account name. The sort dominates the complexity.

```java
import java.util.*;

class Solution721 {
    public List<List<String>> accountsMerge(List<List<String>> accounts) {
        Map<String, Integer> emailId = new HashMap<>();
        Map<String, String> emailName = new HashMap<>();
        int[] parent = new int[10001];
        Arrays.fill(parent, -1);
        int id = 0;

        // Assign IDs and initialize parent
        for (var acc : accounts) {
            String name = acc.get(0);
            for (int i = 1; i < acc.size(); i++) {
                String email = acc.get(i);
                if (!emailId.containsKey(email)) {
                    emailId.put(email, id);
                    parent[id] = id;
                    id++;
                }
                emailName.putIfAbsent(email, name);
            }
        }

        // Union emails in the same account
        for (var acc : accounts) {
            int first = emailId.get(acc.get(1));
            for (int i = 2; i < acc.size(); i++) {
                int eid = emailId.get(acc.get(i));
                int ra = find(parent, first), rb = find(parent, eid);
                if (ra != rb) parent[ra] = rb;
            }
        }

        // Group by root
        Map<Integer, List<String>> groups = new HashMap<>();
        for (var entry : emailId.entrySet()) {
            int root = find(parent, entry.getValue());
            groups.computeIfAbsent(root, k -> new ArrayList<>()).add(entry.getKey());
        }

        List<List<String>> result = new ArrayList<>();
        for (var group : groups.values()) {
            Collections.sort(group);
            List<String> acc = new ArrayList<>();
            acc.add(emailName.get(group.get(0)));
            acc.addAll(group);
            result.add(acc);
        }
        result.sort(Comparator.comparing(a -> a.get(0)));
        return result;
    }

    private int find(int[] parent, int x) {
        while (parent[x] != x) {
            parent[x] = parent[parent[x]]; // path halving
            x = parent[x];
        }
        return x;
    }

    public static void main(String[] args) {
        var sol = new Solution721();
        var accounts = List.of(
            List.of("John","johnsmith@mail.com","john_newyork@mail.com"),
            List.of("John","johnsmith@mail.com","john00@mail.com"),
            List.of("Mary","mary@mail.com"),
            List.of("John","johnnybravo@mail.com")
        );
        var result = sol.accountsMerge(accounts);
        if (result.size() != 3)
            throw new AssertionError("test1: expected 3 merged accounts, got " + result.size());
        boolean foundMerged = result.stream().anyMatch(a -> a.get(0).equals("John") && a.size() == 4);
        if (!foundMerged)
            throw new AssertionError("test1: could not find merged John account with 3 emails");

        var accounts2 = List.of(List.of("Alice","a@a.com"), List.of("Bob","b@b.com"));
        var result2 = sol.accountsMerge(accounts2);
        if (result2.size() != 2)
            throw new AssertionError("test2: expected 2, got " + result2.size());

        System.out.println("LC 721 all tests passed");
    }
}
```

**Time:** O(A · E · α(A·E)). **Space:** O(A · E).

**Java note:** Path halving (`parent[x] = parent[parent[x]]`) is used in the iterative `find` to avoid `StackOverflowError` on large inputs. This is simpler than full path compression and achieves the same amortized complexity.

---

## LC684. Redundant Connection

**Problem.** Undirected tree with one extra edge. Find the redundant edge that creates a cycle.

**Approach 1 — Union-Find Edge Processing (O(E·α(V)) time, O(V) space).**
Process edges in order: for each edge `(u, v)`, attempt to union them. The first edge where both
endpoints are already in the same component is the redundant connection.

```java
import java.util.*;

class Solution684 {
    int[] parent, rank;

    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }

    boolean union(int x, int y) {
        int rx = find(x), ry = find(y);
        if (rx == ry) return false;
        if (rank[rx] < rank[ry]) { int t = rx; rx = ry; ry = t; }
        parent[ry] = rx;
        if (rank[rx] == rank[ry]) rank[rx]++;
        return true;
    }

    public int[] findRedundantConnection(int[][] edges) {
        int n = edges.length;
        parent = new int[n + 1]; rank = new int[n + 1];
        for (int i = 1; i <= n; i++) parent[i] = i;
        for (int[] e : edges)
            if (!union(e[0], e[1])) return e;
        return new int[0];
    }

    public static void main(String[] args) {
        var sol = new Solution684();

        int[] actual = sol.findRedundantConnection(new int[][]{{1,2},{1,3},{2,3}});
        if (!Arrays.equals(actual, new int[]{2,3}))
            throw new AssertionError("test1: expected [2,3], got " + Arrays.toString(actual));

        sol = new Solution684();
        actual = sol.findRedundantConnection(new int[][]{{1,2},{2,3},{3,4},{1,4},{1,5}});
        if (!Arrays.equals(actual, new int[]{1,4}))
            throw new AssertionError("test2: expected [1,4], got " + Arrays.toString(actual));

        System.out.println("LC 684 all tests passed");
    }
}
```

**Time:** O(E · α(V)). **Space:** O(V).

**Java note:** Instance fields `parent` and `rank` are reset in `findRedundantConnection`, so each test needs a fresh `Solution684` instance.

---

## LC827. Making a Large Island

**Problem.** In an `n×n` binary grid, flip at most one `0` to `1` and find the largest island.

**Approach 1 — Union-Find Island Labeling + 0-Cell Expansion (O(R·C·α(R·C)) time, O(R·C) space).**
Union-Find labels and sizes each existing island. For each `0` cell, collect the set of distinct
neighboring island roots, sum their sizes, add 1 (the flipped cell), and track the maximum.

```java
import java.util.*;

class Solution827 {
    int[] parent, size;

    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }

    void union(int x, int y) {
        int rx = find(x), ry = find(y);
        if (rx == ry) return;
        if (size[rx] < size[ry]) { int t = rx; rx = ry; ry = t; }
        parent[ry] = rx;
        size[rx] += size[ry];
    }

    public int largestIsland(int[][] grid) {
        int n = grid.length;
        parent = new int[n * n]; size = new int[n * n];
        for (int i = 0; i < n * n; i++) { parent[i] = i; size[i] = 1; }

        int[][] dirs2 = {{0,1},{1,0}};
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++)
                if (grid[r][c] == 1)
                    for (int[] d : dirs2) {
                        int nr = r + d[0], nc = c + d[1];
                        if (nr < n && nc < n && grid[nr][nc] == 1)
                            union(r * n + c, nr * n + nc);
                    }

        int ans = 0;
        boolean anyZero = false;
        int[][] dirs4 = {{0,1},{0,-1},{1,0},{-1,0}};
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++)
                if (grid[r][c] == 0) {
                    anyZero = true;
                    Set<Integer> seen = new HashSet<>();
                    int total = 1;
                    for (int[] d : dirs4) {
                        int nr = r + d[0], nc = c + d[1];
                        if (nr < 0 || nr >= n || nc < 0 || nc >= n || grid[nr][nc] == 0) continue;
                        int root = find(nr * n + nc);
                        if (seen.add(root)) total += size[root];
                    }
                    ans = Math.max(ans, total);
                }

        if (!anyZero) return n * n;
        // Also consider not flipping any zero — best existing island
        for (int i = 0; i < n * n; i++)
            if (find(i) == i) ans = Math.max(ans, size[i]);
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution827();

        int actual = sol.largestIsland(new int[][]{{1,0},{0,1}});
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        sol = new Solution827();
        actual = sol.largestIsland(new int[][]{{1,1},{1,1}});
        if (actual != 4) throw new AssertionError("test2: expected 4, got " + actual);

        sol = new Solution827();
        actual = sol.largestIsland(new int[][]{{0,0},{0,0}});
        if (actual != 1) throw new AssertionError("test3: expected 1, got " + actual);

        System.out.println("LC 827 all tests passed");
    }
}
```

**Time:** O(n² · α(n²)). **Space:** O(n²).

**Java note:** Each test needs a fresh instance (resets `parent`/`size`). The `find` call inside the zero-cell loop correctly identifies component roots even after multiple union operations.

---

## LC990. Satisfiability of Equality Equations

**Problem.** Given equations `"a==b"` and `"a!=b"`, determine if all can be satisfied simultaneously.

**Approach 1 — Union-Find Two-Pass (O(E·α(V)) time, O(V) space).**
Two-pass: first union all `==` equation variable pairs. Then verify all `!=` equations —
if either variable pair shares the same root, the constraint is contradicted; return false.

```java
import java.util.*;

class Solution990 {
    int[] parent = new int[26];

    Solution990() { for (int i = 0; i < 26; i++) parent[i] = i; }

    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }

    public boolean equationsPossible(String[] equations) {
        // Pass 1: union all equal variables
        for (String eq : equations) {
            if (eq.charAt(1) == '=') {
                int a = eq.charAt(0) - 'a', b = eq.charAt(3) - 'a';
                int ra = find(a), rb = find(b);
                if (ra != rb) parent[ra] = rb;
            }
        }
        // Pass 2: check no != pair is in the same component
        for (String eq : equations) {
            if (eq.charAt(1) == '!') {
                int a = eq.charAt(0) - 'a', b = eq.charAt(3) - 'a';
                if (find(a) == find(b)) return false;
            }
        }
        return true;
    }

    public static void main(String[] args) {
        boolean actual = new Solution990().equationsPossible(new String[]{"a==b","b!=c","b==c"});
        if (actual) throw new AssertionError("test1: expected false, got true");

        actual = new Solution990().equationsPossible(new String[]{"a==b","b==c","a==c"});
        if (!actual) throw new AssertionError("test2: expected true, got false");

        actual = new Solution990().equationsPossible(new String[]{"a!=a"});
        if (actual) throw new AssertionError("test3: expected false, got true");

        System.out.println("LC 990 all tests passed");
    }
}
```

**Time:** O(n · α(26)) = O(n). **Space:** O(1) — alphabet fixed at 26.

**Java note:** `eq.charAt(1) == '='` distinguishes `==` from `!=` correctly (`==` has `=` at index 1; `!=` has `!` at index 1). Each test creates a fresh instance to reset the `parent` array.

---

## LC1584. Min Cost to Connect All Points

**Problem.** Given `n` points, connect all with minimum total Manhattan distance.

**Approach 1 — Prim's MST (O(V²) time, O(V) space).**
Prim's MST: maintain a `minCost[]` array of cheapest known edge from any visited node to each
unvisited node. Greedily pick the unvisited node with minimum `minCost` and update neighbors.
Manhattan distance is the edge weight between any two points.

```java
import java.util.*;

class Solution1584 {
    public int minCostConnectPoints(int[][] points) {
        int n = points.length;
        if (n == 1) return 0;

        boolean[] inMST = new boolean[n];
        int[] minEdge = new int[n];
        Arrays.fill(minEdge, Integer.MAX_VALUE);
        minEdge[0] = 0;

        // {cost, pointIndex}
        PriorityQueue<int[]> pq = new PriorityQueue<>(Comparator.comparingInt(a -> a[0]));
        pq.offer(new int[]{0, 0});
        int total = 0;

        while (!pq.isEmpty()) {
            var top = pq.poll();
            int cost = top[0], u = top[1];
            if (inMST[u]) continue;            // stale entry
            inMST[u] = true;
            total += cost;
            for (int v = 0; v < n; v++) {
                if (!inMST[v]) {
                    int d = Math.abs(points[u][0] - points[v][0])
                          + Math.abs(points[u][1] - points[v][1]);
                    if (d < minEdge[v]) {
                        minEdge[v] = d;
                        pq.offer(new int[]{d, v});
                    }
                }
            }
        }
        return total;
    }

    public static void main(String[] args) {
        var sol = new Solution1584();

        int actual = sol.minCostConnectPoints(new int[][]{{0,0},{2,2},{3,10},{5,2},{7,0}});
        if (actual != 20) throw new AssertionError("test1: expected 20, got " + actual);

        actual = sol.minCostConnectPoints(new int[][]{{0,0},{1,1}});
        if (actual != 2) throw new AssertionError("test2: expected 2, got " + actual);

        actual = sol.minCostConnectPoints(new int[][]{{0,0}});
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        System.out.println("LC 1584 all tests passed");
    }
}
```

**Time:** O(n² log n). **Space:** O(n).

**Java note:** The `inMST[u]` guard after `pq.poll()` serves the same role as the stale-entry check in Dijkstra — a node may be re-added to the heap with a cheaper cost, and the older entry must be discarded.

---

## LC1168. Optimize Water Distribution in a Village

**Problem.** Build wells or lay pipes to supply water to all `n` houses at minimum cost.

**Approach 1 — Kruskal's MST with Virtual Node (O(E log E) time, O(V+E) space).**
Add a virtual node 0 as the water source: connect each house `i` to node 0 with edge weight
`wells[i-1]`. Run Kruskal's MST on all edges (pipe edges + well edges). The MST cost is the
minimum total cost to supply water to all houses.

```java
import java.util.*;

class Solution1168 {
    int[] parent;

    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }

    public int minCostToSupplyWater(int n, int[] wells, int[][] pipes) {
        // Collect all edges; virtual node = 0
        List<int[]> edges = new ArrayList<>();
        for (int i = 0; i < wells.length; i++)
            edges.add(new int[]{wells[i], 0, i + 1});
        for (int[] p : pipes)
            edges.add(new int[]{p[2], p[0], p[1]});
        edges.sort(Comparator.comparingInt(a -> a[0]));

        parent = new int[n + 1];
        for (int i = 0; i <= n; i++) parent[i] = i;

        int total = 0, components = n + 1;
        for (int[] e : edges) {
            int ru = find(e[1]), rv = find(e[2]);
            if (ru != rv) {
                parent[ru] = rv;
                total += e[0];
                if (--components == 1) break;
            }
        }
        return total;
    }

    public static void main(String[] args) {
        var sol = new Solution1168();

        int actual = sol.minCostToSupplyWater(3, new int[]{1,2,2},
            new int[][]{{1,2,1},{2,3,1}});
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        sol = new Solution1168();
        actual = sol.minCostToSupplyWater(1, new int[]{5}, new int[][]{});
        if (actual != 5) throw new AssertionError("test2: expected 5, got " + actual);

        sol = new Solution1168();
        actual = sol.minCostToSupplyWater(3, new int[]{1,1,1},
            new int[][]{{1,2,100},{2,3,100}});
        if (actual != 3) throw new AssertionError("test3: expected 3, got " + actual);

        System.out.println("LC 1168 all tests passed");
    }
}
```

**Time:** O(E log E). **Space:** O(V + E).

**Java note:** Each test needs a fresh instance to reset `parent`. The virtual-node trick converts the mixed "well or pipe" decision into a pure MST problem with no special casing.

---

## LC1192. Critical Connections in a Network

**Problem.** Find all edges whose removal disconnects the graph (bridges).

**Approach 1 — Tarjan's Bridge-Finding DFS (O(V+E) time, O(V+E) space).**
DFS tracking `disc[u]` (discovery time) and `low[u]` (minimum discovery time reachable from
u's subtree via back edges). An edge `(u, v)` is a bridge if `low[v] > disc[u]` — no back
edge in v's subtree reaches u or an ancestor of u.

```java
import java.util.*;

class Solution1192 {
    int timer = 0;
    int[] disc, low;
    List<Integer>[] adj;
    List<List<Integer>> bridges;

    public List<List<Integer>> criticalConnections(int n, List<List<Integer>> connections) {
        adj = new ArrayList[n];
        for (int i = 0; i < n; i++) adj[i] = new ArrayList<>();
        for (var c : connections) {
            adj[c.get(0)].add(c.get(1));
            adj[c.get(1)].add(c.get(0));
        }

        disc = new int[n]; low = new int[n];
        Arrays.fill(disc, -1);
        bridges = new ArrayList<>();

        for (int i = 0; i < n; i++)
            if (disc[i] == -1) dfs(i, -1);

        return bridges;
    }

    private void dfs(int u, int parent) {
        disc[u] = low[u] = timer++;
        for (int v : adj[u]) {
            if (disc[v] == -1) {
                // Tree edge
                dfs(v, u);
                low[u] = Math.min(low[u], low[v]);
                if (low[v] > disc[u])              // bridge condition
                    bridges.add(List.of(u, v));
            } else if (v != parent) {
                // Back edge — not the edge we arrived on
                low[u] = Math.min(low[u], disc[v]);
            }
        }
    }

    public static void main(String[] args) {
        var sol = new Solution1192();
        var connections = List.of(List.of(0,1),List.of(1,2),List.of(2,0),List.of(1,3));
        var result = sol.criticalConnections(4, connections);
        // Normalize and check
        var sorted = new ArrayList<List<Integer>>();
        for (var e : result) { var s = new ArrayList<>(e); Collections.sort(s); sorted.add(s); }
        sorted.sort(Comparator.comparingInt(e -> e.get(0)));
        if (!sorted.equals(List.of(List.of(1,3))))
            throw new AssertionError("test1: expected [[1,3]], got " + sorted);

        sol = new Solution1192();
        var connections2 = List.of(List.of(0,1),List.of(1,2));
        var result2 = sol.criticalConnections(3, connections2);
        var sorted2 = new ArrayList<List<Integer>>();
        for (var e : result2) { var s = new ArrayList<>(e); Collections.sort(s); sorted2.add(s); }
        sorted2.sort(Comparator.comparingInt(e -> e.get(0)));
        if (!sorted2.equals(List.of(List.of(0,1),List.of(1,2))))
            throw new AssertionError("test2: expected [[0,1],[1,2]], got " + sorted2);

        sol = new Solution1192();
        var connections3 = List.of(List.of(0,1),List.of(1,2),List.of(0,2));
        var result3 = sol.criticalConnections(3, connections3);
        if (!result3.isEmpty())
            throw new AssertionError("test3: expected empty, got " + result3);

        System.out.println("LC 1192 all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java note:** `disc[v] == -1` serves as "unvisited" sentinel (Rust uses `usize::MAX`). The `v != parent` guard prevents treating the incoming tree edge as a back-edge — critical for correctness. For multigraphs with parallel edges, pass the edge index instead of parent node to handle them correctly.

---

## LC1976. Number of Ways to Arrive at Destination

**Problem.** Count the number of shortest paths from node `0` to node `n-1`. Answer modulo `10^9 + 7`.

**Approach 1 — Dijkstra with Path Count (O((V+E) log V) time, O(V+E) space).**
Dijkstra extended with a `ways[]` array. When a strictly shorter path to `v` is found, reset
`ways[v] = ways[u]`. When an equal-length path is found, add `ways[v] += ways[u]`.
Answer: `ways[n-1] mod 10^9+7`.

```java
import java.util.*;

class Solution1976 {
    public int countPaths(int n, int[][] roads) {
        final long MOD = 1_000_000_007L;
        List<long[]>[] graph = new ArrayList[n];
        for (int i = 0; i < n; i++) graph[i] = new ArrayList<>();
        for (int[] r : roads) {
            graph[r[0]].add(new long[]{r[1], r[2]});
            graph[r[1]].add(new long[]{r[0], r[2]});
        }

        long[] dist = new long[n];
        long[] ways = new long[n];
        Arrays.fill(dist, Long.MAX_VALUE);
        dist[0] = 0; ways[0] = 1;

        // {distance, node}
        PriorityQueue<long[]> pq = new PriorityQueue<>(Comparator.comparingLong(a -> a[0]));
        pq.offer(new long[]{0, 0});

        while (!pq.isEmpty()) {
            var top = pq.poll();
            long d = top[0]; int u = (int) top[1];
            if (d > dist[u]) continue;             // stale entry
            for (long[] e : graph[u]) {
                int v = (int) e[0]; long w = e[1];
                long nd = d + w;
                if (nd < dist[v]) {
                    dist[v] = nd;
                    ways[v] = ways[u];
                    pq.offer(new long[]{nd, v});
                } else if (nd == dist[v]) {
                    ways[v] = (ways[v] + ways[u]) % MOD;
                }
            }
        }
        return (int) ways[n - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution1976();

        int actual = sol.countPaths(7, new int[][]{
            {0,6,7},{0,1,2},{1,2,3},{1,3,3},{6,3,3},
            {3,5,1},{6,5,1},{2,5,1},{0,4,5},{4,6,2}
        });
        if (actual != 4) throw new AssertionError("test1: expected 4, got " + actual);

        actual = sol.countPaths(2, new int[][]{{0,1,1}});
        if (actual != 1) throw new AssertionError("test2: expected 1, got " + actual);

        actual = sol.countPaths(3, new int[][]{{0,1,1},{1,2,1},{0,2,2}});
        if (actual != 2) throw new AssertionError("test3: expected 2, got " + actual);

        System.out.println("LC 1976 all tests passed");
    }
}
```

**Time:** O((V + E) log V). **Space:** O(V + E).

**Java note:** Use `long` arrays for both `dist` and `ways` to avoid overflow. `ways[v]` is updated even on the `nd == dist[v]` branch — the stale-entry check only skips node-expansion, not the equal-distance accumulation. Cast the node index back from `long` when using it as an array index.

---

## LC1129. Shortest Path with Alternating Colors

**Problem.** Graph with red and blue edges. Find shortest path from node `0` to every other node using alternating colors. Return `-1` for unreachable nodes.

**Approach 1 — BFS on (Node, Color) State Space (O(V+E) time, O(V+E) space).**
BFS on the expanded state `(node, lastColor)`: from each state, only traverse edges of the
opposite color. Return the BFS depth when any state with `node = target` is first dequeued.

```java
import java.util.*;

class Solution1129 {
    public int[] shortestAlternatingPaths(int n, int[][] redEdges, int[][] blueEdges) {
        // adj[u] = list of {v, color}: 0=red, 1=blue
        List<int[]>[] adj = new ArrayList[n];
        for (int i = 0; i < n; i++) adj[i] = new ArrayList<>();
        for (int[] e : redEdges)  adj[e[0]].add(new int[]{e[1], 0});
        for (int[] e : blueEdges) adj[e[0]].add(new int[]{e[1], 1});

        // dist[node][color] = shortest steps arriving at node via edge of that color
        int[][] dist = new int[n][2];
        for (int[] row : dist) Arrays.fill(row, Integer.MAX_VALUE);
        dist[0][0] = 0; dist[0][1] = 0;

        // State: {node, color}, BFS guarantees shortest path
        Queue<int[]> q = new ArrayDeque<>();
        q.offer(new int[]{0, 0, 0}); // {node, arrivalColor, steps}
        q.offer(new int[]{0, 1, 0});

        while (!q.isEmpty()) {
            var top = q.poll();
            int u = top[0], color = top[1], steps = top[2];
            int nextColor = 1 - color;
            for (int[] e : adj[u]) {
                int v = e[0], ec = e[1];
                if (ec == nextColor && dist[v][ec] == Integer.MAX_VALUE) {
                    dist[v][ec] = steps + 1;
                    q.offer(new int[]{v, ec, steps + 1});
                }
            }
        }

        int[] ans = new int[n];
        for (int i = 0; i < n; i++) {
            int best = Math.min(dist[i][0], dist[i][1]);
            ans[i] = best == Integer.MAX_VALUE ? -1 : best;
        }
        return ans;
    }

    public static void main(String[] args) {
        var sol = new Solution1129();

        int[] actual = sol.shortestAlternatingPaths(3,
            new int[][]{{0,1},{1,2}}, new int[][]{});
        if (!Arrays.equals(actual, new int[]{0,1,-1}))
            throw new AssertionError("test1: expected [0,1,-1], got " + Arrays.toString(actual));

        actual = sol.shortestAlternatingPaths(3,
            new int[][]{{0,1}}, new int[][]{{2,1}});
        if (!Arrays.equals(actual, new int[]{0,1,-1}))
            throw new AssertionError("test2: expected [0,1,-1], got " + Arrays.toString(actual));

        actual = sol.shortestAlternatingPaths(3,
            new int[][]{{0,1},{0,2}}, new int[][]{{1,0}});
        if (!Arrays.equals(actual, new int[]{0,1,1}))
            throw new AssertionError("test3: expected [0,1,1], got " + Arrays.toString(actual));

        System.out.println("LC 1129 all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java note:** The `dist[v][ec] == Integer.MAX_VALUE` guard ensures each `(node, color)` state is enqueued at most once — equivalent to a visited check. Initializing both `dist[0][0]` and `dist[0][1]` to 0 and enqueuing both starting states handles the case where the first edge can be either color.

---

> **Java vs Rust — Summary Callout**
>
> | Concern | Java | Rust |
> |---------|------|------|
> | Min-heap for Dijkstra | `PriorityQueue` with `Comparator.comparingInt(a -> a[0])` — min-heap by default | `BinaryHeap<Reverse<(u32, usize)>>` — must wrap in `Reverse` to invert max-heap |
> | Max-heap for probabilities | `PriorityQueue` with `(a,b) -> Double.compare(b[0], a[0])` | `BinaryHeap<(OrdF64, usize)>` — requires `OrdF64` newtype because `f64` lacks `Ord` |
> | Infinity in Floyd-Warshall | `Integer.MAX_VALUE / 2` — half-MAX prevents `a + b` overflow | `i32::MAX / 2` — identical idiom; Rust also uses `u32::MAX` when overflow is impossible |
> | Graph adjacency | `List<int[]>[]` or `List<long[]>[]` | `Vec<Vec<(usize, u32)>>` — index-based, avoids HashMap overhead |
> | Union-Find struct | `static class UnionFind` or instance fields | `struct UnionFind` with `impl` block; ownership enforced by borrow checker |
> | Recursive DFS state | Instance fields or method parameters | Explicit `&mut` parameters — no implicit shared state |
> | Stale-entry skip | `if (d > dist[u]) continue;` | `if cost > dist[u] { continue; }` — identical logic |

---

## Chapter Review Notes

### Issue / Severity / Fix Applied Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| Dijkstra processes stale heap entries, causing incorrect distances | High | Every Dijkstra solution (LC 743, 1631, 778, 1514, 1584, 1976) contains `if (d > dist[u]) continue;` immediately after `pq.poll()` |
| Floyd-Warshall: `dist[i][k] + dist[k][j]` overflows `int` when using `Integer.MAX_VALUE` | High | All Floyd-Warshall code uses `final int INF = Integer.MAX_VALUE / 2` and guards `if (dist[i][k] < INF && dist[k][j] < INF)` |
| Bellman-Ford same-round chaining: relaxing edges in one pass can chain multiple hops | High | LC 787 clones the distance array before each round (`long[] prev = dist.clone()`) and reads only from `prev` |
| Tarjan's back-edge parent confusion: treating tree-edge back as a back-edge inflates `low` values and misses bridges | High | LC 1192 DFS checks `v != parent` before updating `low[u]` from a back-edge |
| Topological sort cycle handling: Kahn's must return empty result when not all nodes are processed | High | LC 207, 210, 1136, and 444 all check `processed == n` or `idx == n` and return an empty/error result on cycle |
| LC 310 final collection: filtering by `adj.isEmpty()` would incorrectly exclude centroids after pruning | High | Fixed by returning `leaves` directly after the `remaining > 2` loop — `leaves` always holds the centroids |
| `assert` keyword is disabled by default in Java; tests using `assert x == y` silently pass when wrong | Critical | No `assert` keyword is used anywhere; all checks use `if (actual != expected) throw new AssertionError(...)` |
| `Long.MAX_VALUE` used as Bellman-Ford infinity: `prev[u] + w` overflows `long` when `prev[u]` is `Long.MAX_VALUE` | Medium | `Long.MAX_VALUE / 2` used as infinity — addition of any realistic weight stays well within `long` bounds |
| LC 721 Accounts Merge: recursive `find` can overflow stack on pathological inputs | Medium | Iterative `find` with path halving (`parent[x] = parent[parent[x]]`) used instead of recursion |
| LC 1976 `ways` counter: updating `ways[v]` for equal-distance paths must not be gated on the stale-entry check | Medium | The `nd == dist[v]` branch runs *after* the stale check and operates on outgoing edges, which is correct — `ways[v]` is updated whenever a same-length path is found, regardless of whether `u` is "fresh" |
| LC 1192 multigraph: `v != parent` check is incorrect when there are parallel edges | Low | Noted in Java note; fix requires tracking edge index rather than parent node — acceptable for LeetCode inputs which guarantee simple graphs |

### What This Chapter Does Well

The chapter applies the Dijkstra stale-entry guard consistently across all six heap-based problems, which is the single most common source of incorrect implementations in contest settings. The Floyd-Warshall `Integer.MAX_VALUE / 2` idiom is used correctly throughout, and the guard against adding two large values is always present. Bellman-Ford's snapshot clone is clearly motivated. Tarjan's bridge algorithm correctly distinguishes tree edges from back-edges via the `parent` parameter. The Union-Find implementation uses path compression and union-by-rank together, giving nearly-O(1) per operation. The `assert` keyword is absent; all test assertions use `throw new AssertionError(...)` which fires unconditionally regardless of JVM flags.

The Java-vs-Rust callouts address the most practically significant differences: the min/max heap polarity reversal, the `f64`/`Ord` friction in Rust vs Java's `Double.compare`, and the `Integer.MAX_VALUE / 2` infinity idiom that mirrors Rust's `i32::MAX / 2`. These are the points most likely to trip a developer switching between the two languages on graph problems.

### What Could Be Improved

Tarjan's SCC (Kosaraju's algorithm) is mentioned in the task specification but does not appear as a standalone LeetCode problem in this chapter — the Rust source chapter covers only LC 1192 (bridges, not SCC). A reference template for Kosaraju's two-pass DFS would add value for readers who need SCC without requiring an additional LeetCode problem to host it.

The `find` method in several solutions (LC 684, 1168, 827) uses instance fields, requiring callers to create fresh instances between tests. A cleaner approach passes the `parent` array as a parameter, matching the Rust pattern of `fn find(parent: &mut Vec<usize>, x: usize)`. This would eliminate the "fresh instance per test" requirement and make the function reusable without side effects.

LC 1192's Tarjan implementation uses a recursive DFS that could overflow the Java call stack on inputs with `n` up to `10^5` and a linear chain topology. An iterative DFS using an explicit stack would be more robust, though the recursive version is simpler to read and matches the Rust reference.

For LC 721, a full union-by-rank in addition to path halving would tighten the worst-case bound, but path halving alone achieves the same amortized complexity for realistic LeetCode inputs.
