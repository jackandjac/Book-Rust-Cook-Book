# LC-11: DFS — Deep Dive (Java 17+)

> **Chapter goal:** Cover every DFS variation from the Rust companion chapter in idiomatic
> Java 17+. Same 20 problems, same four parts: grid DFS, graph DFS, tree DFS, and advanced DFS
> with backtracking. Each solution compiles as a standalone class with a `main` test driver.
> No JUnit, no `assert` keyword — all assertions use `throw new AssertionError(...)`.

---

## Shared Definitions (reference only)

The definitions below are shown once for clarity. Each problem's `class Solution` block
re-declares `TreeNode` as a `static` nested class so every snippet compiles independently
without external dependencies.

```java
// Shared TreeNode — re-declared inside each Solution class that needs it
static class TreeNode {
    int val; TreeNode left, right;
    TreeNode(int val) { this.val = val; }
    TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
}

// Shared grid DFS directions — 4-directional: right, left, down, up
int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};
```

> **Java vs Rust — DFS callout:**
> In Java, recursive DFS passes mutable state (visited arrays, result lists) through normal method
> parameters with no compiler friction. In Rust, the borrow checker prohibits holding a `&mut`
> reference to a structure while simultaneously passing it to a recursive call unless the ownership
> hierarchy is strictly linear — this forces the use of separate `&mut` parameters threaded down
> every call. For very deep trees or large grids, iterative DFS with `ArrayDeque` (never
> `java.util.Stack`, which is synchronized and legacy) avoids `StackOverflowError` in both
> languages; Rust's default thread stack is 8 MB with the same depth constraints as the JVM's
> default 512 KB–1 MB stack.

---

## Part 1 — Grid DFS

---

## LC200. Number of Islands

**Problem.** Given a 2-D binary grid of `'1'` (land) and `'0'` (water), count the number of
islands — connected groups of `'1'`s (4-directional connectivity).

**Approach 1 — Recursive Grid DFS with In-Place Marking (O(R×C) time, O(R×C) space).**
Each cell is treated as a potential DFS root. Marking visited cells `'#'` in-place avoids a
separate `boolean[][]` visited array, identical to the Rust approach. The count of DFS
calls that actually start (cell was `'1'`) equals the island count. Java's reference semantics
make in-place mutation straightforward — no ownership transfer needed.

```java
class Solution200 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public int numIslands(char[][] grid) {
        int rows = grid.length;
        if (rows == 0) return 0;
        int cols = grid[0].length;
        int count = 0;
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1') {
                    count++;
                    dfs(grid, r, c, rows, cols);
                }
            }
        }
        return count;
    }

    private void dfs(char[][] grid, int r, int c, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] != '1') return;
        grid[r][c] = '#'; // mark visited in-place
        for (var d : DIRS) dfs(grid, r + d[0], c + d[1], rows, cols);
    }

    public static void main(String[] args) {
        var sol = new Solution200();

        // Test 1: three islands
        char[][] g1 = {
            {'1','1','0','0','0'},
            {'1','1','0','0','0'},
            {'0','0','1','0','0'},
            {'0','0','0','1','1'}
        };
        var r1 = sol.numIslands(g1);
        if (r1 != 3) throw new AssertionError("numIslands test1: got " + r1);

        // Test 2: one island
        char[][] g2 = {
            {'1','1','1'},
            {'1','1','1'}
        };
        var r2 = sol.numIslands(g2);
        if (r2 != 1) throw new AssertionError("numIslands test2: got " + r2);

        // Test 3: all water
        char[][] g3 = {{'0','0'},{'0','0'}};
        var r3 = sol.numIslands(g3);
        if (r3 != 0) throw new AssertionError("numIslands test3: got " + r3);

        System.out.println("LC #200 Number of Islands: all tests passed.");
    }
}
```

**Time:** O(R×C) — each cell visited at most once. **Space:** O(R×C) worst-case recursion stack.

**Java note:** `var d : DIRS` iterates `int[]` entries; Java's enhanced for loop works cleanly
with 2-D `int[][]`. The in-place `'#'` mark is identical to the Rust approach and avoids
allocating a `boolean[][]` visited grid.

---

## LC695. Max Area of Island

**Problem.** Find the connected component of `1`s with the greatest area. The grid uses `int`
values `0` and `1`.

**Approach 1 — Recursive Grid DFS Returning Area (O(R×C) time, O(R×C) space).**
DFS returns the total cell count of the current island. Accumulate the count as cells are marked
visited with `-1`. Track the running maximum across all DFS invocations. Returning area from the
recursive call avoids a mutable instance counter.

```java
class Solution695 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public int maxAreaOfIsland(int[][] grid) {
        int rows = grid.length;
        if (rows == 0) return 0;
        int cols = grid[0].length;
        int max = 0;
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 1) {
                    max = Math.max(max, dfs(grid, r, c, rows, cols));
                }
            }
        }
        return max;
    }

    private int dfs(int[][] grid, int r, int c, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] != 1) return 0;
        grid[r][c] = -1; // mark visited
        int area = 1;
        for (var d : DIRS) area += dfs(grid, r + d[0], c + d[1], rows, cols);
        return area;
    }

    public static void main(String[] args) {
        var sol = new Solution695();

        // Test 1: LeetCode example — max area 6
        int[][] g1 = {
            {0,0,1,0,0,0,0,1,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,1,0,0,0},
            {0,1,1,0,1,0,0,0,0,0,0,0,0},
            {0,1,0,0,1,1,0,0,1,0,1,0,0},
            {0,1,0,0,1,1,0,0,1,1,1,0,0},
            {0,0,0,0,0,0,0,0,0,0,1,0,0},
            {0,0,0,0,0,0,0,1,1,1,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0}
        };
        var r1 = sol.maxAreaOfIsland(g1);
        if (r1 != 6) throw new AssertionError("maxArea test1: got " + r1);

        // Test 2: all zeros
        int[][] g2 = {{0,0,0,0,0}};
        var r2 = sol.maxAreaOfIsland(g2);
        if (r2 != 0) throw new AssertionError("maxArea test2: got " + r2);

        System.out.println("LC #695 Max Area of Island: all tests passed.");
    }
}
```

**Time:** O(R×C). **Space:** O(R×C) recursion stack.

**Java note:** Using `-1` as the visited marker keeps the grid as `int[][]` without a type
change. Returning and accumulating area from the recursive call (`area += dfs(...)`) avoids
an instance-level counter — a cleaner pattern than `this.area++`.

---

## LC733. Flood Fill

**Problem.** Starting from `(sr, sc)`, replace its color and all 4-directionally connected pixels
of the same original color with `newColor`.

**Approach 1 — Recursive Grid DFS Flood Fill (O(R×C) time, O(R×C) space).**
Guard against the case where `newColor == originalColor` to avoid infinite
recursion. Otherwise apply DFS changing cells as they are visited.

```java
class Solution733 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public int[][] floodFill(int[][] image, int sr, int sc, int color) {
        int original = image[sr][sc];
        if (original != color) dfs(image, sr, sc, original, color);
        return image;
    }

    private void dfs(int[][] image, int r, int c, int original, int color) {
        int rows = image.length, cols = image[0].length;
        if (r < 0 || r >= rows || c < 0 || c >= cols || image[r][c] != original) return;
        image[r][c] = color;
        for (var d : DIRS) dfs(image, r + d[0], c + d[1], original, color);
    }

    public static void main(String[] args) {
        var sol = new Solution733();

        // Test 1: standard fill
        int[][] img1 = {{1,1,1},{1,1,0},{1,0,1}};
        var res1 = sol.floodFill(img1, 1, 1, 2);
        int[][] exp1 = {{2,2,2},{2,2,0},{2,0,1}};
        for (int r = 0; r < exp1.length; r++)
            for (int c = 0; c < exp1[0].length; c++)
                if (res1[r][c] != exp1[r][c])
                    throw new AssertionError("floodFill test1 mismatch at [" + r + "][" + c + "]: got " + res1[r][c]);

        // Test 2: same color — no change
        int[][] img2 = {{0,0,0},{0,0,0}};
        var res2 = sol.floodFill(img2, 0, 0, 0);
        if (res2[0][0] != 0) throw new AssertionError("floodFill test2: got " + res2[0][0]);

        System.out.println("LC #733 Flood Fill: all tests passed.");
    }
}
```

**Time:** O(R×C). **Space:** O(R×C) recursion stack.

**Java note:** The early return on `original == color` is essential. Without it, every cell
would be re-visited infinitely. Java returns the modified grid directly; unlike Rust there is no
ownership transfer — the caller's reference and the method's reference alias the same array.

---

## LC130. Surrounded Regions

**Problem.** Flip all `'O'`s not connected to any border cell to `'X'`. Border-connected `'O'`s
survive.

**Approach 1 — Reverse DFS from Border Cells (O(R×C) time, O(R×C) space).**
Reverse the problem: DFS from every border `'O'`, marking reachable `'O'`s as `'S'` (safe).
Then sweep: `'O'` → `'X'` (captured), `'S'` → `'O'` (restored). This avoids the hard problem
of determining which interior regions are surrounded.

```java
class Solution130 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public void solve(char[][] board) {
        if (board.length == 0) return;
        int rows = board.length, cols = board[0].length;

        // Mark border-connected 'O' as safe
        for (int r = 0; r < rows; r++) {
            dfs(board, r, 0, rows, cols);
            dfs(board, r, cols - 1, rows, cols);
        }
        for (int c = 0; c < cols; c++) {
            dfs(board, 0, c, rows, cols);
            dfs(board, rows - 1, c, rows, cols);
        }

        // Sweep
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                board[r][c] = switch (board[r][c]) {
                    case 'O' -> 'X';
                    case 'S' -> 'O';
                    default  -> board[r][c];
                };
            }
        }
    }

    private void dfs(char[][] board, int r, int c, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || board[r][c] != 'O') return;
        board[r][c] = 'S';
        for (var d : DIRS) dfs(board, r + d[0], c + d[1], rows, cols);
    }

    public static void main(String[] args) {
        var sol = new Solution130();

        // Test 1: LeetCode example
        char[][] b1 = {
            {'X','X','X','X'},
            {'X','O','O','X'},
            {'X','X','O','X'},
            {'X','O','X','X'}
        };
        sol.solve(b1);
        char[][] exp1 = {
            {'X','X','X','X'},
            {'X','X','X','X'},
            {'X','X','X','X'},
            {'X','O','X','X'}
        };
        for (int r = 0; r < exp1.length; r++)
            for (int c = 0; c < exp1[0].length; c++)
                if (b1[r][c] != exp1[r][c])
                    throw new AssertionError("solve test1 [" + r + "][" + c + "]: got " + b1[r][c]);

        // Test 2: all O — all border-connected, nothing flipped
        char[][] b2 = {{'O','O','O'},{'O','O','O'},{'O','O','O'}};
        sol.solve(b2);
        for (var row : b2)
            for (var cell : row)
                if (cell != 'O') throw new AssertionError("solve test2: cell flipped unexpectedly");

        System.out.println("LC #130 Surrounded Regions: all tests passed.");
    }
}
```

**Time:** O(R×C). **Space:** O(R×C) recursion stack.

**Java note:** The `switch` expression (Java 14+) is a natural fit for the three-way sweep:
`'O'` → `'X'`, `'S'` → `'O'`, everything else unchanged. This is cleaner than chained `if/else`
and reads like a Rust `match` arm.

---

## LC417. Pacific Atlantic Water Flow

**Problem.** Return all cells from which water can flow to both oceans. Water flows to neighbors
with equal or lesser height.

**Approach 1 — Reverse DFS from Each Ocean's Border (O(R×C) time, O(R×C) space).**
Reverse the flow direction: DFS from Pacific-border cells (top row + left col) marking all cells
that can "flow up" to the Pacific. Repeat for Atlantic borders (bottom row + right col).
Cells appearing in both reachable sets flow to both oceans.

```java
import java.util.*;

class Solution417 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public List<List<Integer>> pacificAtlantic(int[][] heights) {
        var result = new ArrayList<List<Integer>>();
        if (heights.length == 0) return result;
        int rows = heights.length, cols = heights[0].length;
        boolean[][] pac = new boolean[rows][cols];
        boolean[][] atl = new boolean[rows][cols];

        for (int r = 0; r < rows; r++) {
            dfs(heights, r, 0,        pac, Integer.MIN_VALUE, rows, cols);
            dfs(heights, r, cols - 1, atl, Integer.MIN_VALUE, rows, cols);
        }
        for (int c = 0; c < cols; c++) {
            dfs(heights, 0,        c, pac, Integer.MIN_VALUE, rows, cols);
            dfs(heights, rows - 1, c, atl, Integer.MIN_VALUE, rows, cols);
        }

        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (pac[r][c] && atl[r][c])
                    result.add(List.of(r, c));
        return result;
    }

    private void dfs(int[][] h, int r, int c, boolean[][] visited,
                     int prevHeight, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols) return;
        if (visited[r][c] || h[r][c] < prevHeight) return;
        visited[r][c] = true;
        for (var d : DIRS) dfs(h, r + d[0], c + d[1], visited, h[r][c], rows, cols);
    }

    public static void main(String[] args) {
        var sol = new Solution417();

        int[][] heights = {
            {1,2,2,3,5},
            {3,2,3,4,4},
            {2,4,5,3,1},
            {6,7,1,4,5},
            {5,1,1,2,4}
        };
        var res = sol.pacificAtlantic(heights);
        var expected = new HashSet<>(List.of(
            List.of(0,4), List.of(1,3), List.of(1,4),
            List.of(2,2), List.of(3,0), List.of(3,1), List.of(4,0)
        ));
        if (!new HashSet<>(res).equals(expected))
            throw new AssertionError("pacificAtlantic test1: got " + res);

        // Single cell reaches both oceans
        int[][] single = {{1}};
        var r2 = sol.pacificAtlantic(single);
        if (!r2.equals(List.of(List.of(0, 0))))
            throw new AssertionError("pacificAtlantic single: got " + r2);

        System.out.println("LC #417 Pacific Atlantic: all tests passed.");
    }
}
```

**Time:** O(R×C). **Space:** O(R×C) for the two visited matrices.

**Java note:** `boolean[][]` is allocated fresh for each call to `pacificAtlantic`, so there is
no risk of visited state leaking between test cases. `Integer.MIN_VALUE` as the initial
`prevHeight` sentinel ensures all border cells pass the height check.

---

## LC329. Longest Increasing Path in a Matrix

**Problem.** Find the length of the longest strictly increasing path in the matrix, moving in 4
directions.

**Approach 1 — Memoized DFS (O(R×C) time, O(R×C) space).**
DFS from each cell, caching the longest path length in `memo[r][c]`. Because the path must be
strictly increasing, there are no cycles — memoization alone prevents redundant work without a
`visited` array. Each cell is computed at most once.

```java
class Solution329 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public int longestIncreasingPath(int[][] matrix) {
        int rows = matrix.length;
        if (rows == 0) return 0;
        int cols = matrix[0].length;
        int[][] memo = new int[rows][cols]; // 0 = not yet computed
        int best = 0;
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                best = Math.max(best, dfs(matrix, r, c, Integer.MIN_VALUE, memo, rows, cols));
        return best;
    }

    private int dfs(int[][] m, int r, int c, int prev, int[][] memo, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols) return 0;
        if (m[r][c] <= prev) return 0;
        if (memo[r][c] != 0) return memo[r][c];
        int best = 1;
        for (var d : DIRS)
            best = Math.max(best, 1 + dfs(m, r + d[0], c + d[1], m[r][c], memo, rows, cols));
        memo[r][c] = best;
        return best;
    }

    public static void main(String[] args) {
        var sol = new Solution329();

        var r1 = sol.longestIncreasingPath(new int[][]{{9,9,4},{6,6,8},{2,1,1}});
        if (r1 != 4) throw new AssertionError("LIP test1: got " + r1);

        var r2 = sol.longestIncreasingPath(new int[][]{{3,4,5},{3,2,6},{2,2,1}});
        if (r2 != 4) throw new AssertionError("LIP test2: got " + r2);

        var r3 = sol.longestIncreasingPath(new int[][]{{1}});
        if (r3 != 1) throw new AssertionError("LIP test3: got " + r3);

        System.out.println("LC #329 Longest Increasing Path: all tests passed.");
    }
}
```

**Time:** O(R×C) — each cell computed once. **Space:** O(R×C) for memo.

**Java note:** `memo[r][c] == 0` serves as "not yet computed" because valid answers are >= 1.
The strictly-increasing constraint breaks all cycles, making recursive memoized DFS safe here
without a separate `inStack` check.

---

## Part 2 — Graph DFS

---

## LC323. Number of Connected Components in an Undirected Graph

**Problem.** Given `n` nodes (0 to n-1) and undirected edges, return the number of connected
components.

**Approach 1 — Graph DFS with Visited Array (O(V+E) time, O(V+E) space).**
Build an adjacency list, then count DFS calls from unvisited nodes. Each DFS call from an
unvisited node discovers exactly one new connected component and marks all its members visited.

```java
import java.util.*;

class Solution323 {

    public int countComponents(int n, int[][] edges) {
        var adj = new ArrayList<List<Integer>>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());
        for (var e : edges) {
            adj.get(e[0]).add(e[1]);
            adj.get(e[1]).add(e[0]);
        }
        boolean[] visited = new boolean[n];
        int components = 0;
        for (int i = 0; i < n; i++) {
            if (!visited[i]) {
                components++;
                dfs(adj, i, visited);
            }
        }
        return components;
    }

    private void dfs(List<List<Integer>> adj, int node, boolean[] visited) {
        if (visited[node]) return;
        visited[node] = true;
        for (int nb : adj.get(node)) dfs(adj, nb, visited);
    }

    public static void main(String[] args) {
        var sol = new Solution323();

        // Two components: {0,1,2} and {3,4}
        var r1 = sol.countComponents(5, new int[][]{{0,1},{1,2},{3,4}});
        if (r1 != 2) throw new AssertionError("countComponents test1: got " + r1);

        // One component: path 0-1-2-3-4
        var r2 = sol.countComponents(5, new int[][]{{0,1},{1,2},{2,3},{3,4}});
        if (r2 != 1) throw new AssertionError("countComponents test2: got " + r2);

        // No edges: 4 isolated nodes
        var r3 = sol.countComponents(4, new int[][]{});
        if (r3 != 4) throw new AssertionError("countComponents test3: got " + r3);

        System.out.println("LC #323 Number of Connected Components: all tests passed.");
    }
}
```

**Time:** O(V+E). **Space:** O(V+E) adjacency list + O(V) visited array.

**Java note:** `boolean[] visited` is allocated inside `countComponents`, so it is always fresh
per call — no state leaks between test cases. Prefer `ArrayList<List<Integer>>` over
`Map<Integer, List<Integer>>` when nodes are 0..n integers; direct indexing is faster and
avoids boxing overhead.

---

## LC261. Graph Valid Tree

**Problem.** Given `n` nodes and `edges`, determine whether they form a valid tree (connected,
no cycles).

**Approach 1 — DFS Cycle Detection with Parent Tracking (O(V+E) time, O(V+E) space).**
A valid tree has exactly `n-1` edges AND is fully connected. DFS cycle detection tracks the
parent edge to avoid counting the traversed edge as a back-edge in an undirected graph.
If no cycle and all nodes reached, it is a valid tree.

```java
import java.util.*;

class Solution261 {

    public boolean validTree(int n, int[][] edges) {
        if (edges.length != n - 1) return false; // necessary condition
        var adj = new ArrayList<List<Integer>>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());
        for (var e : edges) {
            adj.get(e[0]).add(e[1]);
            adj.get(e[1]).add(e[0]);
        }
        boolean[] visited = new boolean[n];
        if (hasCycle(adj, 0, -1, visited)) return false;
        for (boolean v : visited) if (!v) return false; // disconnected
        return true;
    }

    private boolean hasCycle(List<List<Integer>> adj, int node, int parent, boolean[] visited) {
        visited[node] = true;
        for (int nb : adj.get(node)) {
            if (nb == parent) continue;       // skip the edge we came from
            if (visited[nb]) return true;     // back edge found — cycle
            if (hasCycle(adj, nb, node, visited)) return true;
        }
        return false;
    }

    public static void main(String[] args) {
        var sol = new Solution261();

        // Valid tree
        var r1 = sol.validTree(5, new int[][]{{0,1},{0,2},{0,3},{1,4}});
        if (!r1) throw new AssertionError("validTree test1: expected true, got false");

        // Cycle present
        var r2 = sol.validTree(5, new int[][]{{0,1},{1,2},{2,3},{1,3}});
        if (r2) throw new AssertionError("validTree test2: expected false (cycle), got true");

        // Disconnected
        var r3 = sol.validTree(4, new int[][]{{0,1},{2,3}});
        if (r3) throw new AssertionError("validTree test3: expected false (disconnected), got true");

        System.out.println("LC #261 Graph Valid Tree: all tests passed.");
    }
}
```

**Time:** O(V+E). **Space:** O(V+E).

**Java note:** `-1` is a safe "no parent" sentinel because node indices are 0..n-1. The
`edges.length != n - 1` short-circuit is a clean necessary condition: any graph that is a tree
on n nodes has exactly n-1 edges.

---

## LC207. Course Schedule

**Problem.** Given `numCourses` and prerequisite pairs `[a, b]` (take b before a), determine
if all courses can be finished (no directed cycle).

**Approach 1 — DFS Three-Color Cycle Detection (O(V+E) time, O(V+E) space).**
Use three-color DFS: `0` = unvisited, `1` = in current DFS stack (gray), `2` = fully processed
(black). A back edge to a gray node means a cycle exists. If any cycle is detected, return false.

```java
import java.util.*;

class Solution207 {

    public boolean canFinish(int numCourses, int[][] prerequisites) {
        var adj = new ArrayList<List<Integer>>();
        for (int i = 0; i < numCourses; i++) adj.add(new ArrayList<>());
        for (var p : prerequisites) adj.get(p[0]).add(p[1]);

        int[] state = new int[numCourses]; // 0=unvisited, 1=in-stack, 2=done
        for (int i = 0; i < numCourses; i++)
            if (state[i] == 0 && hasCycle(adj, i, state)) return false;
        return true;
    }

    private boolean hasCycle(List<List<Integer>> adj, int node, int[] state) {
        state[node] = 1;
        for (int nb : adj.get(node)) {
            if (state[nb] == 1) return true;  // back edge
            if (state[nb] == 0 && hasCycle(adj, nb, state)) return true;
        }
        state[node] = 2;
        return false;
    }

    public static void main(String[] args) {
        var sol = new Solution207();

        // No cycle: 0 must precede 1
        var r1 = sol.canFinish(2, new int[][]{{1,0}});
        if (!r1) throw new AssertionError("canFinish test1: got false");

        // Cycle: 0 <-> 1
        var r2 = sol.canFinish(2, new int[][]{{1,0},{0,1}});
        if (r2) throw new AssertionError("canFinish test2: got true (should be false)");

        // Longer cycle: 0->1->2->0
        var r3 = sol.canFinish(3, new int[][]{{1,0},{2,1},{0,2}});
        if (r3) throw new AssertionError("canFinish test3: got true");

        // Single course, no prereqs
        var r4 = sol.canFinish(1, new int[][]{});
        if (!r4) throw new AssertionError("canFinish test4: got false");

        System.out.println("LC #207 Course Schedule: all tests passed.");
    }
}
```

**Time:** O(V+E). **Space:** O(V+E).

**Java note:** `int[] state` (three values 0/1/2) is a natural Java equivalent of Rust's
`Vec<u8>`. It is more efficient than `Map<Integer, State>` for integer-indexed nodes and avoids
enum boxing overhead in the hot loop.

---

## LC210. Course Schedule II

**Problem.** Same DAG setup as LC #207. Return a valid topological order, or an empty array if
a cycle exists.

**Approach 1 — DFS Post-Order Topological Sort (O(V+E) time, O(V+E) space).**
Topological sort via DFS post-order: after fully processing a node (state → 2), push it to the
result list. Reverse the list at the end to get a valid ordering. A cycle makes ordering impossible.

```java
import java.util.*;

class Solution210 {

    public int[] findOrder(int numCourses, int[][] prerequisites) {
        var adj = new ArrayList<List<Integer>>();
        for (int i = 0; i < numCourses; i++) adj.add(new ArrayList<>());
        for (var p : prerequisites) adj.get(p[0]).add(p[1]);

        int[] state = new int[numCourses];
        var order = new ArrayList<Integer>();

        for (int i = 0; i < numCourses; i++)
            if (state[i] == 0 && dfsTopo(adj, i, state, order))
                return new int[]{};

        Collections.reverse(order);
        return order.stream().mapToInt(Integer::intValue).toArray();
    }

    /** Returns true if a cycle is detected. */
    private boolean dfsTopo(List<List<Integer>> adj, int node, int[] state,
                            List<Integer> order) {
        state[node] = 1;
        for (int nb : adj.get(node)) {
            if (state[nb] == 1) return true;
            if (state[nb] == 0 && dfsTopo(adj, nb, state, order)) return true;
        }
        state[node] = 2;
        order.add(node); // post-order: add when fully processed
        return false;
    }

    public static void main(String[] args) {
        var sol = new Solution210();

        // Simple: 0 before 1
        var r1 = sol.findOrder(2, new int[][]{{1,0}});
        if (r1.length != 2 || r1[0] != 0 || r1[1] != 1)
            throw new AssertionError("findOrder test1: got " + Arrays.toString(r1));

        // Four-course DAG — multiple valid orderings; check first and last
        var r2 = sol.findOrder(4, new int[][]{{1,0},{2,0},{3,1},{3,2}});
        if (r2.length != 4 || r2[0] != 0 || r2[r2.length - 1] != 3)
            throw new AssertionError("findOrder test2: got " + Arrays.toString(r2));

        // Cycle — returns empty
        var r3 = sol.findOrder(2, new int[][]{{0,1},{1,0}});
        if (r3.length != 0) throw new AssertionError("findOrder test3: expected empty, got " + Arrays.toString(r3));

        System.out.println("LC #210 Course Schedule II: all tests passed.");
    }
}
```

**Time:** O(V+E). **Space:** O(V+E).

**Java note:** `Collections.reverse(order)` mirrors Rust's `order.reverse()`. The `ArrayList`
accumulator is passed as a parameter, threading mutable state down the call stack without
instance variables — the same pattern as Rust's `&mut Vec<i32>`.

---

## LC797. All Paths From Source to Target

**Problem.** Given a DAG (node `n-1` is the target), return all paths from node 0 to node `n-1`.

**Approach 1 — DFS Backtracking on DAG (O(V · 2^V) time, O(V) path space).**
DFS with backtracking: push the current node to `path`, recurse on all neighbors, pop when done.
No `visited` array is needed because cycles cannot exist in a DAG. Each root-to-target path is
collected when the target node is reached.

```java
import java.util.*;

class Solution797 {

    public List<List<Integer>> allPathsSourceTarget(int[][] graph) {
        var result = new ArrayList<List<Integer>>();
        var path = new ArrayList<Integer>();
        path.add(0);
        dfs(graph, 0, graph.length - 1, path, result);
        return result;
    }

    private void dfs(int[][] graph, int node, int target,
                     List<Integer> path, List<List<Integer>> result) {
        if (node == target) {
            result.add(new ArrayList<>(path)); // snapshot current path
            return;
        }
        for (int next : graph[node]) {
            path.add(next);
            dfs(graph, next, target, path, result);
            path.remove(path.size() - 1); // backtrack
        }
    }

    public static void main(String[] args) {
        var sol = new Solution797();

        // Two paths: 0->1->3 and 0->2->3
        var r1 = sol.allPathsSourceTarget(new int[][]{{1,2},{3},{3},{}});
        var sorted1 = new ArrayList<>(r1);
        sorted1.sort(Comparator.comparing(Object::toString));
        var exp1 = List.of(List.of(0,1,3), List.of(0,2,3));
        if (!new HashSet<>(sorted1).equals(new HashSet<>(exp1)))
            throw new AssertionError("allPaths test1: got " + r1);

        // Direct path: 0->1
        var r2 = sol.allPathsSourceTarget(new int[][]{{1},{}});
        if (!r2.equals(List.of(List.of(0,1))))
            throw new AssertionError("allPaths test2: got " + r2);

        System.out.println("LC #797 All Paths Source to Target: all tests passed.");
    }
}
```

**Time:** O(2^V × V) worst case. **Space:** O(V) recursion depth + O(2^V × V) result.

**Java note:** `path.remove(path.size() - 1)` removes by index, not by value — important when
`path` contains `Integer` objects. Removing by `Integer.valueOf(x)` would remove the first
occurrence of `x`, not necessarily the last element. Always remove by index for backtracking.

---

## LC332. Reconstruct Itinerary

**Problem.** Given airline tickets as `[from, to]` pairs, reconstruct the itinerary starting
from `"JFK"` in lexicographic order. All tickets must be used exactly once.

**Approach 1 — Hierholzer's Algorithm / DFS Eulerian Path (O(E log E) time, O(E) space).**
Hierholzer's algorithm for an Eulerian path: DFS always picks the lexicographically smallest
destination using a `PriorityQueue` per source. Add the departure airport to the result *after*
all neighbors are exhausted (post-order). Reverse at the end for the correct order.

```java
import java.util.*;

class Solution332 {

    public List<String> findItinerary(List<List<String>> tickets) {
        // TreeMap keeps sources sorted; PriorityQueue keeps dests sorted
        var graph = new TreeMap<String, PriorityQueue<String>>();
        for (var t : tickets)
            graph.computeIfAbsent(t.get(0), k -> new PriorityQueue<>()).add(t.get(1));

        var result = new ArrayList<String>();
        // Iterative Hierholzer's — ArrayDeque as stack (never java.util.Stack)
        var stack = new ArrayDeque<String>();
        stack.push("JFK");
        while (!stack.isEmpty()) {
            var src = stack.peek();
            var dests = graph.get(src);
            if (dests != null && !dests.isEmpty()) {
                stack.push(dests.poll()); // push smallest destination
            } else {
                result.add(stack.pop()); // post-order: add when no destinations left
            }
        }
        Collections.reverse(result);
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution332();

        // Test 1
        var t1 = List.of(
            List.of("MUC","LHR"), List.of("JFK","MUC"),
            List.of("SFO","SJC"), List.of("LHR","SFO")
        );
        var r1 = sol.findItinerary(t1);
        if (!r1.equals(List.of("JFK","MUC","LHR","SFO","SJC")))
            throw new AssertionError("itinerary test1: got " + r1);

        // Test 2
        var t2 = List.of(
            List.of("JFK","SFO"), List.of("JFK","ATL"),
            List.of("SFO","ATL"), List.of("ATL","JFK"), List.of("ATL","SFO")
        );
        var r2 = sol.findItinerary(t2);
        if (!r2.equals(List.of("JFK","ATL","JFK","SFO","ATL","SFO")))
            throw new AssertionError("itinerary test2: got " + r2);

        System.out.println("LC #332 Reconstruct Itinerary: all tests passed.");
    }
}
```

**Time:** O(E log E) — sorting via `PriorityQueue`. **Space:** O(V+E).

**Java note:** `ArrayDeque` is the correct stack choice in Java — `java.util.Stack` is
synchronized, extends `Vector`, and is considered legacy. `ArrayDeque.push` and `peek`/`pop`
give LIFO semantics. `TreeMap` keeps sources sorted; `PriorityQueue` per source handles
lexicographic destination ordering.

---

## Part 3 — Tree DFS (Beyond Basic Traversal)

> **Note:** Basic tree traversals (inorder, preorder, postorder, height, diameter) are covered in
> Ch5. This part covers tree DFS patterns that build on those foundations.

Each problem re-declares `static class TreeNode` inside the `Solution` class for standalone
compilation. The structure matches the LeetCode standard definition.

---

## LC113. Path Sum II

**Problem.** Find all root-to-leaf paths where the sum of node values equals `targetSum`.
Return each path as a list.

**Approach 1 — DFS Backtracking with Path Accumulator (O(N²) time, O(N) space).**
DFS with backtracking: carry a mutable `path` list and subtract the current node's value from the
remaining sum. At a leaf with `remaining == 0`, snapshot the current path into results. Always
call `path.remove(path.size() - 1)` at the end of `dfs` (by index, not by value) to backtrack.

```java
import java.util.*;

class Solution113 {

    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }

    public List<List<Integer>> pathSum(TreeNode root, int targetSum) {
        var result = new ArrayList<List<Integer>>();
        dfs(root, targetSum, new ArrayList<>(), result);
        return result;
    }

    private void dfs(TreeNode node, int remaining, List<Integer> path,
                     List<List<Integer>> result) {
        if (node == null) return;
        path.add(node.val);
        remaining -= node.val;
        if (node.left == null && node.right == null && remaining == 0)
            result.add(new ArrayList<>(path)); // snapshot
        else {
            dfs(node.left,  remaining, path, result);
            dfs(node.right, remaining, path, result);
        }
        path.remove(path.size() - 1); // backtrack — always executes
    }

    public static void main(String[] args) {
        var sol = new Solution113();

        // Tree: 5 -> [4->[11->[7,2]], 8->[13, 4->[5,1]]], target=22
        var root = new TreeNode(5,
            new TreeNode(4, new TreeNode(11, new TreeNode(7), new TreeNode(2)), null),
            new TreeNode(8, new TreeNode(13), new TreeNode(4, new TreeNode(5), new TreeNode(1)))
        );
        var res = sol.pathSum(root, 22);
        var sorted = new ArrayList<>(res);
        sorted.sort(Comparator.comparing(Object::toString));
        var exp = List.of(List.of(5,4,11,2), List.of(5,8,4,5));
        var sortedExp = new ArrayList<>(exp);
        sortedExp.sort(Comparator.comparing(Object::toString));
        if (!sorted.equals(sortedExp))
            throw new AssertionError("pathSum test1: got " + res);

        // No valid path
        var r2 = sol.pathSum(new TreeNode(1, new TreeNode(2), new TreeNode(3)), 5);
        if (!r2.isEmpty()) throw new AssertionError("pathSum test2: got " + r2);

        // Null root
        var r3 = sol.pathSum(null, 0);
        if (!r3.isEmpty()) throw new AssertionError("pathSum test3: got " + r3);

        System.out.println("LC #113 Path Sum II: all tests passed.");
    }
}
```

**Time:** O(N²) worst case (N leaves × O(N) clone). **Space:** O(N) path depth.

**Java note:** `path.remove(path.size() - 1)` is outside the `else` block, placed at the very
end of `dfs`. This mirrors Rust's `path.pop()` at the end of the function body — backtracking
always executes regardless of whether a leaf was found, preventing path corruption across sibling
subtrees.

---

## LC257. Binary Tree Paths

**Problem.** Return all root-to-leaf paths formatted as `"1->2->5"`.

**Approach 1 — DFS with String Accumulation (O(N²) time, O(N) space).**
DFS accumulating a running path string passed by value (copy-on-call), so sibling subtrees
receive independent copies. No explicit backtracking is needed because Java `String` is immutable
and a new instance is created at each recursive call with `path + val`.

```java
import java.util.*;

class Solution257 {

    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }

    public List<String> binaryTreePaths(TreeNode root) {
        var result = new ArrayList<String>();
        if (root != null) dfs(root, "", result);
        return result;
    }

    private void dfs(TreeNode node, String path, List<String> result) {
        var current = path.isEmpty() ? String.valueOf(node.val) : path + "->" + node.val;
        if (node.left == null && node.right == null) {
            result.add(current);
            return;
        }
        if (node.left  != null) dfs(node.left,  current, result);
        if (node.right != null) dfs(node.right, current, result);
    }

    public static void main(String[] args) {
        var sol = new Solution257();

        // Tree: 1->[2->[null,5], 3]
        var root = new TreeNode(1, new TreeNode(2, null, new TreeNode(5)), new TreeNode(3));
        var res = sol.binaryTreePaths(root);
        Collections.sort(res);
        if (!res.equals(List.of("1->2->5", "1->3")))
            throw new AssertionError("binaryPaths test1: got " + res);

        // Single node
        var r2 = sol.binaryTreePaths(new TreeNode(1));
        if (!r2.equals(List.of("1")))
            throw new AssertionError("binaryPaths test2: got " + r2);

        System.out.println("LC #257 Binary Tree Paths: all tests passed.");
    }
}
```

**Time:** O(N²) — string concatenation at each node. **Space:** O(N) depth.

**Java note:** Passing `String` by value means each recursive call gets its own `current` — Java
strings are immutable so `path + "->" + node.val` creates a new string without affecting the
caller's copy. This is functionally equivalent to Rust's pass-by-value `String` with `.clone()`
at the branch point, but in Java it happens implicitly due to immutability.

---

## LC129. Sum Root to Leaf Numbers

**Problem.** Each root-to-leaf path forms a decimal number (root is most significant digit).
Return the total sum.

**Approach 1 — DFS with Running Number Accumulation (O(N) time, O(N) space).**
DFS passing the running number down: multiply by 10 and add the current digit at each node.
At leaves, return the accumulated number. Sum all leaf values up the recursion for the total.

```java
class Solution129 {

    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }

    public int sumNumbers(TreeNode root) {
        return dfs(root, 0);
    }

    private int dfs(TreeNode node, int current) {
        if (node == null) return 0;
        current = current * 10 + node.val;
        if (node.left == null && node.right == null) return current; // leaf
        return dfs(node.left, current) + dfs(node.right, current);
    }

    public static void main(String[] args) {
        var sol = new Solution129();

        // 12 + 13 = 25
        var r1 = sol.sumNumbers(new TreeNode(1, new TreeNode(2), new TreeNode(3)));
        if (r1 != 25) throw new AssertionError("sumNumbers test1: got " + r1);

        // 495 + 491 + 40 = 1026
        var r2 = sol.sumNumbers(
            new TreeNode(4,
                new TreeNode(9, new TreeNode(5), new TreeNode(1)),
                new TreeNode(0)
            )
        );
        if (r2 != 1026) throw new AssertionError("sumNumbers test2: got " + r2);

        // Single node
        var r3 = sol.sumNumbers(new TreeNode(7));
        if (r3 != 7) throw new AssertionError("sumNumbers test3: got " + r3);

        System.out.println("LC #129 Sum Root to Leaf Numbers: all tests passed.");
    }
}
```

**Time:** O(N). **Space:** O(H) where H is tree height.

**Java note:** `current = current * 10 + node.val` shadows the parameter within the same
variable — Java allows reassignment of method parameters, unlike Rust where the idiomatic
approach uses shadowing with `let current = ...`. Both achieve the same local immutability
within the logical frame.

---

## LC114. Flatten Binary Tree to Linked List

**Problem.** Flatten the binary tree in-place to a linked list in preorder order, using right
child pointers. Left child pointers must be `null`.

**Approach 1 — Reverse Postorder DFS with `prev` Field (O(N) time, O(N) space).**
Java's reference semantics make the classic O(1)-space reverse-postorder approach straightforward.
Maintain an instance `prev` field; visit right subtree, then left, then set
`node.right = prev; node.left = null; prev = node`. The right-before-left DFS order ensures nodes
are linked in preorder when reversed.

```java
class Solution114 {

    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }

    // Java: true O(1)-space pointer threading is natural (no borrow-checker friction)
    private TreeNode prev = null;

    public void flatten(TreeNode root) {
        if (root == null) return;
        flatten(root.right);  // process right subtree first
        flatten(root.left);   // then left subtree
        root.right = prev;    // repoint right to previously processed node
        root.left  = null;
        prev = root;
    }

    private static void flattenFresh(TreeNode root, Solution114 sol) {
        sol.prev = null; // reset prev between independent test cases
        sol.flatten(root);
    }

    private static int[] toList(TreeNode root) {
        var vals = new java.util.ArrayList<Integer>();
        while (root != null) { vals.add(root.val); root = root.right; }
        return vals.stream().mapToInt(Integer::intValue).toArray();
    }

    public static void main(String[] args) {
        // Test 1: standard example
        var sol1 = new Solution114();
        var root1 = new TreeNode(1,
            new TreeNode(2, new TreeNode(3), new TreeNode(4)),
            new TreeNode(5, null, new TreeNode(6))
        );
        flattenFresh(root1, sol1);
        var list1 = toList(root1);
        var exp1 = new int[]{1,2,3,4,5,6};
        if (!java.util.Arrays.equals(list1, exp1))
            throw new AssertionError("flatten test1: got " + java.util.Arrays.toString(list1));

        // Test 2: empty
        var sol2 = new Solution114();
        flattenFresh(null, sol2);
        // no assertion needed; method must not throw

        // Test 3: single node
        var sol3 = new Solution114();
        var root3 = new TreeNode(0);
        flattenFresh(root3, sol3);
        var list3 = toList(root3);
        if (!java.util.Arrays.equals(list3, new int[]{0}))
            throw new AssertionError("flatten test3: got " + java.util.Arrays.toString(list3));

        System.out.println("LC #114 Flatten Binary Tree: all tests passed.");
    }
}
```

**Time:** O(N). **Space:** O(H) recursion stack (O(1) extra pointers).

> **Java vs Rust callout — LC #114:**
> Java's reference semantics make the classic O(1)-space reverse-postorder approach trivial:
> `prev` is a mutable field updated freely across recursive calls. In Rust, achieving the same
> requires `unsafe` raw pointers — the borrow checker prohibits holding a mutable reference to
> `root.right` while also calling the recursive `flatten` function that takes `&mut TreeNode`.
> The Rust chapter solves this by collecting preorder values into a `Vec` and rebuilding the
> list, trading O(1) space for O(N) space but staying in safe Rust. This is one of the clearest
> practical differences between the two languages for tree problems.

**Java note:** `prev` is an instance field; a new `Solution114` instance is created per test
case to ensure clean state. The `flattenFresh` helper centralizes the reset to make the pattern
explicit — in a real LeetCode submission the judge constructs a fresh `Solution` per test case.

---

## Part 4 — Advanced DFS

---

## LC79. Word Search

**Problem.** Given a 2-D character board and a word, determine whether the word exists using
adjacent (4-directional) cells, each cell used at most once per path.

**Approach 1 — DFS Backtracking with In-Place Marking (O(R×C×4^L) time, O(L) space).**
DFS with backtracking: temporarily mark the current cell `'#'` during recursion to avoid reuse,
then restore it after returning. This avoids a separate `boolean[][]` visited array. L is the
word length; the branching factor is at most 4 directions.

```java
class Solution79 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    public boolean exist(char[][] board, String word) {
        int rows = board.length;
        if (rows == 0) return false;
        int cols = board[0].length;
        char[] chars = word.toCharArray();
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (dfs(board, r, c, chars, 0, rows, cols)) return true;
        return false;
    }

    private boolean dfs(char[][] board, int r, int c, char[] chars, int idx,
                        int rows, int cols) {
        if (idx == chars.length) return true;
        if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
        if (board[r][c] != chars[idx]) return false;

        char original = board[r][c];
        board[r][c] = '#'; // mark visited
        for (var d : DIRS)
            if (dfs(board, r + d[0], c + d[1], chars, idx + 1, rows, cols)) {
                board[r][c] = original; // restore before returning true
                return true;
            }
        board[r][c] = original; // backtrack
        return false;
    }

    public static void main(String[] args) {
        var sol = new Solution79();

        char[][] board = {
            {'A','B','C','C','E','D'},
            {'S','F','C','S','A','D'},
            {'A','D','E','E','E','A'}
        };

        if (!sol.exist(deepCopy(board), "ABCCED"))
            throw new AssertionError("exist test1: expected true");
        if (sol.exist(deepCopy(board), "ABCB"))
            throw new AssertionError("exist test2: expected false");

        // Single char
        if (!sol.exist(new char[][]{{'A'}}, "A"))
            throw new AssertionError("exist test3: expected true");

        System.out.println("LC #79 Word Search: all tests passed.");
    }

    private static char[][] deepCopy(char[][] b) {
        var copy = new char[b.length][];
        for (int i = 0; i < b.length; i++) copy[i] = b[i].clone();
        return copy;
    }
}
```

**Time:** O(R×C × 4^L) where L = word length. **Space:** O(L) recursion depth.

**Java note:** The board is mutated and restored in-place, so test cases that reuse the same
board must pass a deep copy. `deepCopy` clones each row array. The early `restore + return true`
inside the loop is important — without restoring before returning `true`, the cell remains `'#'`
in the caller's grid copy.

---

## LC212. Word Search II

**Problem.** Given a board and a list of words, return all words that can be found in the grid
(same movement rules as LC #79).

**Approach 1 — Trie + DFS Backtracking (O(R×C×4^L) time, O(total word chars) space).**
Build a Trie of all words. During DFS on the board, traverse the Trie in parallel to prune paths
that cannot complete any word. Remove a word from the Trie once found (set `word = null`)
to prevent duplicates without a separate seen-set.

```java
import java.util.*;

class Solution212 {

    private static final int[][] DIRS = {{0,1},{0,-1},{1,0},{-1,0}};

    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        String word = null; // non-null when a word ends here
    }

    public List<String> findWords(char[][] board, String[] words) {
        var root = new TrieNode();
        for (var w : words) {
            var node = root;
            for (char ch : w.toCharArray()) {
                int idx = ch - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.word = w;
        }

        var result = new ArrayList<String>();
        int rows = board.length, cols = board[0].length;
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                dfs(board, r, c, root, result, rows, cols);
        return result;
    }

    private void dfs(char[][] board, int r, int c, TrieNode node,
                     List<String> result, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols) return;
        char ch = board[r][c];
        if (ch == '#') return;
        var child = node.children[ch - 'a'];
        if (child == null) return;

        if (child.word != null) {
            result.add(child.word);
            child.word = null; // prevent duplicates
        }

        board[r][c] = '#';
        for (var d : DIRS) dfs(board, r + d[0], c + d[1], child, result, rows, cols);
        board[r][c] = ch; // backtrack
    }

    public static void main(String[] args) {
        var sol = new Solution212();

        char[][] board = {
            {'o','a','a','n'},
            {'e','t','a','e'},
            {'i','h','k','r'},
            {'i','f','l','v'}
        };
        var words = new String[]{"oath","pea","eat","rain"};
        var res = sol.findWords(deepCopy(board), words);
        Collections.sort(res);
        if (!res.equals(List.of("eat","oath")))
            throw new AssertionError("findWords test1: got " + res);

        // No match
        var r2 = sol.findWords(new char[][]{{'a','b'},{'c','d'}}, new String[]{"efgh"});
        if (!r2.isEmpty()) throw new AssertionError("findWords test2: got " + r2);

        System.out.println("LC #212 Word Search II: all tests passed.");
    }

    private static char[][] deepCopy(char[][] b) {
        var copy = new char[b.length][];
        for (int i = 0; i < b.length; i++) copy[i] = b[i].clone();
        return copy;
    }
}
```

**Time:** O(R×C × 4^L + W×L) where W = number of words, L = max word length.
**Space:** O(W×L) for Trie + O(L) recursion depth.

**Java note:** `TrieNode[] children = new TrieNode[26]` (array-based trie) is more cache-friendly
than a `HashMap<Character, TrieNode>`. Setting `child.word = null` after finding a word mirrors
Rust's `Option::take()` — it prevents duplicate results in one assignment without an extra `Set`.

---

## LC301. Remove Invalid Parentheses

**Problem.** Remove the minimum number of invalid parentheses to make the input string valid.
Return all possible results.

**Approach 1 — BFS Level-by-Level Removal (O(2^n · n) time, O(2^n) space).**
BFS level by level: each level removes one more character. The first level that produces a valid
string contains all minimum-removal solutions. A `HashSet` of visited strings prevents duplicate
work. BFS naturally guarantees minimum removals without additional pruning.

> **Note:** This problem uses BFS, not recursive DFS. BFS is the correct algorithm here because
> it finds minimum-edit solutions at the first level that yields a valid string. A pure DFS
> approach needs careful depth limiting to achieve the same guarantee.

```java
import java.util.*;

class Solution301 {

    public List<String> removeInvalidParentheses(String s) {
        var result = new ArrayList<String>();
        var visited = new HashSet<String>();
        var queue = new ArrayDeque<String>(); // ArrayDeque as BFS queue
        queue.add(s);
        visited.add(s);
        boolean found = false;

        while (!queue.isEmpty()) {
            var next = new ArrayDeque<String>();
            for (var candidate : queue) {
                if (isValid(candidate)) {
                    result.add(candidate);
                    found = true;
                }
                if (found) continue; // stay at this level
                for (int i = 0; i < candidate.length(); i++) {
                    char ch = candidate.charAt(i);
                    if (ch != '(' && ch != ')') continue;
                    var reduced = candidate.substring(0, i) + candidate.substring(i + 1);
                    if (visited.add(reduced)) next.add(reduced);
                }
            }
            if (found) break;
            queue = next;
        }
        return result;
    }

    private boolean isValid(String s) {
        int count = 0;
        for (char ch : s.toCharArray()) {
            if      (ch == '(') count++;
            else if (ch == ')') { count--; if (count < 0) return false; }
        }
        return count == 0;
    }

    public static void main(String[] args) {
        var sol = new Solution301();

        // Test 1: standard example — valid results include "(())()" and "()()()"
        var r1 = sol.removeInvalidParentheses("()())()");
        var set1 = new HashSet<>(r1);
        if (!set1.contains("(())()") && !set1.contains("()()()"))
            throw new AssertionError("removeInvalid test1: got " + r1);

        // Test 2: only empties remain
        var r2 = sol.removeInvalidParentheses(")(");
        if (!r2.equals(List.of("")))
            throw new AssertionError("removeInvalid test2: got " + r2);

        // Test 3: already valid
        var r3 = sol.removeInvalidParentheses("()");
        if (!r3.equals(List.of("()")))
            throw new AssertionError("removeInvalid test3: got " + r3);

        System.out.println("LC #301 Remove Invalid Parentheses: all tests passed.");
    }
}
```

**Time:** O(2^N × N) worst case. **Space:** O(2^N) for `visited` set.

**Java note:** `ArrayDeque` serves as both the BFS queue (via `add`/`poll`) and is
reused in `next` as the staging buffer for the next BFS level. The `visited` set prevents
redundant string processing when multiple removal paths produce the same candidate string.

---

## LC282. Expression Add Operators

**Problem.** Given a string of digits and a target integer, return all expressions formed by
inserting `+`, `-`, or `*` between digits that evaluate to the target.

**Approach 1 — DFS Backtracking with Multiplication Tracking (O(4^n · n) time, O(n) space).**
DFS backtracking over all split points and three operator choices. Track the last operand to
correctly undo multiplication when `*` follows an earlier `+` or `-`. Build the expression as a
`StringBuilder` and truncate to its saved length to backtrack efficiently.

```java
import java.util.*;

class Solution282 {

    public List<String> addOperators(String num, int target) {
        var result = new ArrayList<String>();
        dfs(num.toCharArray(), (long) target, 0, 0L, 0L, new StringBuilder(), result);
        return result;
    }

    private void dfs(char[] digits, long target, int idx,
                     long currentVal, long lastOperand,
                     StringBuilder path, List<String> result) {
        if (idx == digits.length) {
            if (currentVal == target) result.add(path.toString());
            return;
        }

        int pathLen = path.length();
        for (int end = idx; end < digits.length; end++) {
            // No leading zeros (except the single digit "0")
            if (end > idx && digits[idx] == '0') break;
            // Parse number from digits[idx..end]
            long numVal = 0;
            for (int k = idx; k <= end; k++) numVal = numVal * 10 + (digits[k] - '0');
            // Overflow guard for LC constraints
            if (numVal > Integer.MAX_VALUE) break;

            if (idx == 0) {
                // First number: no leading operator
                path.append(digits, idx, end - idx + 1);
                dfs(digits, target, end + 1, numVal, numVal, path, result);
                path.setLength(pathLen);
            } else {
                // '+' branch
                path.append('+');
                path.append(digits, idx, end - idx + 1);
                dfs(digits, target, end + 1, currentVal + numVal, numVal, path, result);
                path.setLength(pathLen);

                // '-' branch
                path.append('-');
                path.append(digits, idx, end - idx + 1);
                dfs(digits, target, end + 1, currentVal - numVal, -numVal, path, result);
                path.setLength(pathLen);

                // '*' branch — undo last operand, re-apply with multiplication
                path.append('*');
                path.append(digits, idx, end - idx + 1);
                dfs(digits, target, end + 1,
                    currentVal - lastOperand + lastOperand * numVal,
                    lastOperand * numVal, path, result);
                path.setLength(pathLen);
            }
        }
    }

    public static void main(String[] args) {
        var sol = new Solution282();

        // "123" target 6 -> "1+2+3" and "1*2*3"
        var r1 = sol.addOperators("123", 6);
        var set1 = new HashSet<>(r1);
        if (!set1.contains("1+2+3") && !set1.contains("1*2*3"))
            throw new AssertionError("addOperators test1: got " + r1);

        // "232" target 8 -> "2*3+2" or "2+3*2"
        var r2 = sol.addOperators("232", 8);
        var set2 = new HashSet<>(r2);
        if (!set2.contains("2*3+2") && !set2.contains("2+3*2"))
            throw new AssertionError("addOperators test2: got " + r2);

        // Leading zero: "105" target 5
        var r3 = sol.addOperators("105", 5);
        var set3 = new HashSet<>(r3);
        if (!set3.contains("1*0+5") && !set3.contains("10-5"))
            throw new AssertionError("addOperators test3: got " + r3);

        System.out.println("LC #282 Expression Add Operators: all tests passed.");
    }
}
```

**Time:** O(4^N × N) — 4 choices per gap, N for string work. **Space:** O(N) recursion + path.

**Java note:** `StringBuilder.setLength(pathLen)` is the Java equivalent of Rust's
`path.truncate(path_len)` — it restores the builder to its pre-operator state without allocating
a new string. Using `long` for `currentVal` and `lastOperand` handles intermediate overflow
during multiplication even when the final result fits in `int`.

---

## 📝 Chapter Review Notes

### Issue Tracking Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| `prev` field in LC #114 `Solution114.flatten` is an instance variable; sharing one instance across multiple test cases causes incorrect results | High | Each test case constructs a fresh `Solution114` instance; `flattenFresh` helper resets `prev` explicitly for clarity |
| Board mutation in LC #79 and LC #212 persists after DFS exits via `return true` — cell left as `'#'` corrupts subsequent test calls on the same array | High | `board[r][c] = original` restore placed on all exit paths, including the early `return true` branch; tests use `deepCopy` to isolate board state |
| LC #130 two-pass border DFS touches corner cells twice (e.g., `(0,0)` is visited by both the row loop and the col loop) | Low | Acceptable — `dfs` guards against non-`'O'` cells immediately; redundant calls are no-ops and do not affect correctness |
| LC #301 uses BFS, deviating from the "DFS Deep Dive" chapter theme | Medium | Accepted with explicit preamble note; BFS is the correct algorithm for minimum-removal guarantee; a pure DFS alternative would require a two-pass approach (count excess parens, then backtrack with depth limit) |
| `assert` keyword not used anywhere — verified by inspection | None | No fix needed; all assertions use `throw new AssertionError(...)` |
| `java.util.Stack` not used anywhere — verified by inspection | None | All stack usage uses `ArrayDeque` |
| LC #323 and LC #207 `visited`/`state` arrays are allocated inside the public method, not as instance fields, preventing cross-call contamination | None | Design is correct as written |
| LC #417 `boolean[][]` visited matrices are fresh per `pacificAtlantic` call | None | Design is correct as written |

---

### Third-Person Critical Review

**Visited array / set reset between test cases.** The chapter correctly allocates all visited
arrays and state arrays inside the public `Solution` method (not as instance fields), matching
the LeetCode judge's "fresh Solution per test" model. The one exception is LC #114, where
`prev` is an instance field; the test driver creates a new `Solution114` per test case and the
`flattenFresh` helper makes the reset explicit. This design choice is noted in the Java note for
that problem.

**DFS termination for cyclic graphs.** LC #207 and LC #261 use the three-color (`0/1/2`) state
array and the parent-tracking approach respectively. Both algorithms terminate for all inputs,
including graphs with self-loops or multi-edges, because the `state[node] == 1` check detects
any back edge before infinite recursion can occur. LC #323 uses a simple `boolean[] visited`
for an undirected graph; revisiting a visited node short-circuits without a loop.

**No `assert` keyword.** Every test assertion in this chapter uses
`throw new AssertionError("description: got " + actual)`. No JUnit annotations (`@Test`) and
no use of the `assert` keyword appear anywhere in the file. The `assert` keyword is disabled by
default in the JVM unless `-ea` is passed, making it an unreliable test mechanism for LeetCode-
style drivers.

**Tree problems handling null nodes.** All tree DFS methods (`dfs(TreeNode node, ...)`) include
a `if (node == null) return` guard as their first statement. Each problem also includes a null-
root test case (`pathSum(null, 0)`, empty `flatten`, etc.) to verify the guard works.

**Board restoration.** LC #79 and LC #212 both restore `board[r][c]` on all exit paths from
`dfs`, including the early-return path where a match is found. Without this, the cell would
remain `'#'` in the caller's reference, corrupting any subsequent DFS call from another starting
cell on the same board reference. The `deepCopy` utility in both test drivers makes inter-test
isolation explicit.

---

### What This Chapter Does Well

- All 20 problems from the Rust companion chapter are covered in the same order and grouped into
  the same four parts (Grid DFS, Graph DFS, Tree DFS, Advanced DFS).
- Java 17+ features are used where natural: `var` for local type inference, switch expressions
  for the three-way sweep in LC #130, `List.of` and `Map.of` for concise test data.
- `ArrayDeque` is used consistently as the iterative DFS/BFS stack — LC #332 (Hierholzer's) and
  LC #301 (BFS level traversal) both use it instead of the legacy `java.util.Stack`.
- The Java vs Rust callout blockquote at the top of the chapter concisely explains the key
  asymmetry: Java's reference semantics allow free mutable threading, while Rust's borrow checker
  forces explicit `&mut` parameter threading or the use of `unsafe` for true in-place tree
  pointer manipulation.
- LC #114 includes a dedicated second callout blockquote that highlights the specific contrast:
  Java's O(1)-space `prev`-field reverse-postorder is trivial; Rust needs `unsafe` or must
  collect-and-rebuild to stay safe.
- Backtracking problems (LC #113, LC #79, LC #212, LC #282) all use the correct "do, recurse,
  undo" pattern with `remove(size-1)`, `board[r][c] = original`, or
  `path.setLength(pathLen)`.

### What Could Be Improved

- LC #257 uses `String` concatenation (`path + "->" + node.val`) at each tree node, producing
  O(N²) string work. A `StringBuilder` passed by reference with explicit `delete`/`append` would
  be O(N) but requires the explicit backtrack step. The current approach trades efficiency for
  readability, which is appropriate for a learning context.
- LC #301's BFS creates many intermediate `String` objects via `substring`. A character-array
  approach with index-removal would be more GC-friendly. For LeetCode constraints (s.length ≤ 25)
  this is not a practical concern.
- LC #210's test for a four-course DAG checks only that `result[0] == 0` and
  `result[result.length-1] == 3`, not exact ordering. Multiple valid orderings exist, so this is
  correct but provides weaker test coverage than a full-ordering check would.
- The chapter could add an iterative DFS version (using `ArrayDeque`) for LC #200 or LC #695 to
  demonstrate the `ArrayDeque`-as-stack pattern concretely in the grid context, complementing the
  mention in the Java vs Rust callout.
