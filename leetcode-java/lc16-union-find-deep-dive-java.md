# Chapter 16: Union-Find (DSU) Deep Dive (Java)

> **Chapter goal:** Master Union-Find (Disjoint Set Union, DSU) patterns across 23 LeetCode problems.
> All code targets Java 17+. Each solution is self-contained with a `public static void main` driver.
> Tests use `throw new AssertionError("msg: got " + actual)` — no JUnit, no `assert` keyword.

> **Prerequisites:** LC #684 (Redundant Connection), LC #323 (Number of Connected Components),
> and LC #261 (Graph Valid Tree) are covered in **Chapter 7 (lc07-tries-graphs-java.md)** with the same
> UnionFind class. This chapter extends those foundations into advanced DSU applications.

> **Java vs Rust — DSU at a glance**
>
> In Rust, a DSU is a `struct UnionFind { parent: Vec<usize>, rank: Vec<usize> }` where indices are
> `usize` (never negative, no boxing). Java uses `int[]` arrays — same speed, but indices are `int`,
> and negative `int` values are valid (so always validate bounds in grid problems). Java's recursive
> `find()` with path compression rarely hits stack limits in practice because compressed trees are
> nearly flat. Rust's equivalent is a method on a struct; Java's is a method on a static inner class
> or top-level class depending on context.

---

## Canonical UnionFind Class

Every problem in this chapter uses the following class (shown once, referenced everywhere):

```java
import java.util.Arrays;

static class UnionFind {
    int[] parent, rank;
    int count;

    UnionFind(int n) {
        parent = new int[n];
        rank   = new int[n];
        count  = n;
        Arrays.fill(parent, -1);          // sentinel; overwritten immediately
        for (int i = 0; i < n; i++) parent[i] = i;
    }

    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);  // path compression
        return parent[x];
    }

    boolean union(int x, int y) {
        int px = find(x), py = find(y);
        if (px == py) return false;       // already connected
        if (rank[px] < rank[py]) { int t = px; px = py; py = t; }
        parent[py] = px;
        if (rank[px] == rank[py]) rank[px]++;
        count--;
        return true;
    }
}
```

`union` returns `true` when two previously-separate components are merged (useful for cycle detection
and counting merges). `count` tracks the current number of distinct components.

---

## Part 1 — Tier 1: Core DSU Patterns

---

## LC 128. Longest Consecutive Sequence

**Difficulty:** Medium | **Blind75:** ✓

**Problem.** Given an unsorted array of integers, return the length of the longest consecutive elements sequence. Must run in O(n).

**Key insight.** Map each value to a DSU node index. Union each value `v` with `v+1` if it exists. After all unions, the largest component size is the answer.

```java
import java.util.*;

class LC128 {
    static class UnionFind {
        int[] parent, rank, size;
        UnionFind(int n) {
            parent = new int[n]; rank = new int[n]; size = new int[n];
            for (int i = 0; i < n; i++) { parent[i] = i; size[i] = 1; }
        }
        int find(int x) { if (parent[x] != x) parent[x] = find(parent[x]); return parent[x]; }
        void union(int x, int y) {
            int px = find(x), py = find(y);
            if (px == py) return;
            if (rank[px] < rank[py]) { int t = px; px = py; py = t; }
            parent[py] = px; size[px] += size[py];
            if (rank[px] == rank[py]) rank[px]++;
        }
        int size(int x) { return size[find(x)]; }
    }

    public int longestConsecutive(int[] nums) {
        if (nums.length == 0) return 0;
        var indexMap = new HashMap<Integer, Integer>();
        int idx = 0;
        for (int n : nums) if (!indexMap.containsKey(n)) indexMap.put(n, idx++);

        var uf = new UnionFind(indexMap.size());
        for (int n : indexMap.keySet()) {
            if (indexMap.containsKey(n + 1))
                uf.union(indexMap.get(n), indexMap.get(n + 1));
        }

        int best = 0;
        for (int n : indexMap.keySet()) best = Math.max(best, uf.size(indexMap.get(n)));
        return best;
    }

    public static void main(String[] args) {
        var s = new LC128();
        int r1 = s.longestConsecutive(new int[]{100, 4, 200, 1, 3, 2});
        if (r1 != 4) throw new AssertionError("LC128 t1: got " + r1);
        int r2 = s.longestConsecutive(new int[]{0, 3, 7, 2, 5, 8, 4, 6, 0, 1});
        if (r2 != 9) throw new AssertionError("LC128 t2: got " + r2);
        int r3 = s.longestConsecutive(new int[]{});
        if (r3 != 0) throw new AssertionError("LC128 empty: got " + r3);
    }
}
```

**Complexity.** Time O(n α(n)) ≈ O(n), Space O(n).

> **Java vs Rust:** The `size` array tracks component sizes — Java adds a field; Rust would add a `size: Vec<usize>` field to the struct. The `HashMap` here boxes `Integer` keys; Rust uses `HashMap<i32, usize>` with no boxing cost.

---

## LC 200. Number of Islands

**Difficulty:** Medium | **Blind75:** ✓

**Problem.** Count the number of islands in a `'1'`/`'0'` grid.

> **Note:** Chapter 7 solves this with DFS. The DSU approach avoids recursion and treats the grid as a graph with a flat index `r * cols + c`.

```java
import java.util.Arrays;

class LC200 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n) { parent=new int[n]; rank=new int[n]; count=0;
            for(int i=0;i<n;i++) parent[i]=i; }
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
    }

    public int numIslands(char[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        var uf = new UnionFind(rows * cols);
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1') {
                    uf.count++;                          // each land cell starts as its own island
                    for (var d : dirs) {
                        int nr = r + d[0], nc = c + d[1];
                        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] == '1')
                            uf.union(r * cols + c, nr * cols + nc);
                    }
                }
            }
        }
        return uf.count;
    }

    public static void main(String[] args) {
        var s = new LC200();
        char[][] g1 = {
            {'1','1','0','0','0'},
            {'1','1','0','0','0'},
            {'0','0','1','0','0'},
            {'0','0','0','1','1'}
        };
        int r1 = s.numIslands(g1);
        if (r1 != 3) throw new AssertionError("LC200 t1: got " + r1);
    }
}
```

**Complexity.** Time O(m·n α(m·n)), Space O(m·n).

---

## LC 547. Number of Provinces

**Difficulty:** Medium | **Blind75:** ✓

**Problem.** Given an `n×n` adjacency matrix `isConnected`, return the number of provinces (connected components).

```java
import java.util.Arrays;

class LC547 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
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
        var s = new LC547();
        int r1 = s.findCircleNum(new int[][]{{1,1,0},{1,1,0},{0,0,1}});
        if (r1 != 2) throw new AssertionError("LC547 t1: got " + r1);
        int r2 = s.findCircleNum(new int[][]{{1,0,0},{0,1,0},{0,0,1}});
        if (r2 != 3) throw new AssertionError("LC547 t2: got " + r2);
    }
}
```

**Complexity.** Time O(n² α(n)), Space O(n).

**Approach 2 — DFS (O(n²) time, O(n) space).** Walk the adjacency matrix; for each unvisited node, increment the count and flood-fill all connected cities. Simpler to implement; preferred when you don't need incremental connectivity updates.

```java
class LC547DFS {
    public int findCircleNum(int[][] isConnected) {
        int n = isConnected.length;
        boolean[] visited = new boolean[n];
        int count = 0;
        for (int i = 0; i < n; i++) {
            if (!visited[i]) {
                count++;
                dfs(isConnected, visited, i);
            }
        }
        return count;
    }

    private void dfs(int[][] g, boolean[] visited, int node) {
        visited[node] = true;
        for (int next = 0; next < g.length; next++)
            if (g[node][next] == 1 && !visited[next])
                dfs(g, visited, next);
    }

    public static void main(String[] args) {
        var s = new LC547DFS();
        int r1 = s.findCircleNum(new int[][]{{1,1,0},{1,1,0},{0,0,1}});
        if (r1 != 2) throw new AssertionError("LC547DFS t1: got " + r1);
        int r2 = s.findCircleNum(new int[][]{{1,0,0},{0,1,0},{0,0,1}});
        if (r2 != 3) throw new AssertionError("LC547DFS t2: got " + r2);
        int r3 = s.findCircleNum(new int[][]{{1,1,1},{1,1,1},{1,1,1}});
        if (r3 != 1) throw new AssertionError("LC547DFS t3: got " + r3);
        System.out.println("LC547 DFS OK");
    }
}
```

---

## LC 695. Max Area of Island

**Difficulty:** Medium

**Problem.** Return the maximum area of an island (`'1'` = land) in a grid. Area = number of connected land cells.

> **Note:** Chapter 7 solves this with DFS. The DSU version tracks component sizes in a `size[]` array.

```java
import java.util.Arrays;

class LC695 {
    static class UnionFind {
        int[] parent, rank, size;
        UnionFind(int n){parent=new int[n];rank=new int[n];size=new int[n];
            Arrays.fill(size,1);for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        int union(int x,int y){int px=find(x),py=find(y);if(px==py)return size[px];
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;size[px]+=size[py];
            if(rank[px]==rank[py])rank[px]++;return size[px];}
    }

    public int maxAreaOfIsland(int[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        var uf = new UnionFind(rows * cols);
        int max = 0;
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 1) {
                    max = Math.max(max, 1);              // cell itself
                    for (var d : dirs) {
                        int nr = r+d[0], nc = c+d[1];
                        if (nr>=0&&nr<rows&&nc>=0&&nc<cols&&grid[nr][nc]==1)
                            max = Math.max(max, uf.union(r*cols+c, nr*cols+nc));
                    }
                }
            }
        }
        return max;
    }

    public static void main(String[] args) {
        var s = new LC695();
        int[][] g = {
            {0,0,1,0,0,0,0,1,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,1,0,0,0},
            {0,1,1,0,1,0,0,0,0,0,0,0,0},
            {0,1,0,0,1,1,0,0,1,0,1,0,0},
            {0,1,0,0,1,1,0,0,1,1,1,0,0},
            {0,0,0,0,0,0,0,0,0,0,1,0,0},
            {0,0,0,0,0,0,0,1,1,1,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0}
        };
        int r1 = s.maxAreaOfIsland(g);
        if (r1 != 6) throw new AssertionError("LC695 t1: got " + r1);
        int r2 = s.maxAreaOfIsland(new int[][]{{0,0,0,0,0,0,0,0}});
        if (r2 != 0) throw new AssertionError("LC695 all-water: got " + r2);
    }
}
```

**Complexity.** Time O(m·n α(m·n)), Space O(m·n).

---

## LC 721. Accounts Merge

**Difficulty:** Medium

**Problem.** Given accounts where each entry is `[name, email1, email2, ...]`, merge accounts sharing at least one email. Return merged accounts sorted.

**Key insight.** Assign each unique email an integer id. Union all emails within the same account. Group by root, then map back to sorted email lists.

```java
import java.util.*;

class LC721 {
    static class UnionFind {
        int[] parent, rank;
        UnionFind(int n){parent=new int[n];rank=new int[n];for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;}
    }

    public List<List<String>> accountsMerge(List<List<String>> accounts) {
        var emailIndex = new HashMap<String, Integer>();
        var emailOwner = new HashMap<String, String>();
        int id = 0;

        for (var account : accounts) {
            var name = account.get(0);
            for (int i = 1; i < account.size(); i++) {
                var email = account.get(i);
                if (!emailIndex.containsKey(email)) emailIndex.put(email, id++);
                emailOwner.put(email, name);
            }
        }

        var uf = new UnionFind(id);
        for (var account : accounts) {
            int first = emailIndex.get(account.get(1));
            for (int i = 2; i < account.size(); i++)
                uf.union(first, emailIndex.get(account.get(i)));
        }

        // Group emails by root
        var groups = new HashMap<Integer, List<String>>();
        for (var email : emailIndex.keySet()) {
            int root = uf.find(emailIndex.get(email));
            groups.computeIfAbsent(root, k -> new ArrayList<>()).add(email);
        }

        var result = new ArrayList<List<String>>();
        for (var entry : groups.entrySet()) {
            var emails = entry.getValue();
            Collections.sort(emails);
            var merged = new ArrayList<String>();
            merged.add(emailOwner.get(emails.get(0)));
            merged.addAll(emails);
            result.add(merged);
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new LC721();
        var accounts = List.of(
            List.of("John","johnsmith@mail.com","john_newyork@mail.com"),
            List.of("John","johnsmith@mail.com","john00@mail.com"),
            List.of("Mary","mary@mail.com"),
            List.of("John","johnnybravo@mail.com")
        );
        var result = s.accountsMerge(accounts);
        if (result.size() != 3) throw new AssertionError("LC721 t1 size: got " + result.size());
    }
}
```

**Complexity.** Time O(N·K·log(N·K)) where K = max emails per account (sort dominates), Space O(N·K).

---

## LC 827. Making A Large Island

**Difficulty:** Hard

**Problem.** You may flip at most one `0` to `1`. Return the size of the largest island after the flip.

**Key insight.** First label every island with a component id and record its size. Then for each `0` cell, tentatively sum the sizes of its distinct neighboring components plus 1.

```java
import java.util.*;

class LC827 {
    static class UnionFind {
        int[] parent, rank, size;
        UnionFind(int n){parent=new int[n];rank=new int[n];size=new int[n];
            Arrays.fill(size,1);for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;size[px]+=size[py];
            if(rank[px]==rank[py])rank[px]++;}
        int size(int x){return size[find(x)];}
    }

    public int largestIsland(int[][] grid) {
        int n = grid.length;
        var uf = new UnionFind(n * n);
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};

        // Step 1: union all land cells
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++)
                if (grid[r][c] == 1)
                    for (var d : dirs) {
                        int nr=r+d[0], nc=c+d[1];
                        if (nr>=0&&nr<n&&nc>=0&&nc<n&&grid[nr][nc]==1)
                            uf.union(r*n+c, nr*n+nc);
                    }

        // Step 2: for each 0 cell, try flipping it
        int best = 0;
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++)
                best = Math.max(best, uf.size(r*n+c)); // island with no flip

        for (int r = 0; r < n; r++) {
            for (int c = 0; c < n; c++) {
                if (grid[r][c] == 0) {
                    var seen = new HashSet<Integer>();
                    int total = 1;                       // the flipped cell itself
                    for (var d : dirs) {
                        int nr=r+d[0], nc=c+d[1];
                        if (nr>=0&&nr<n&&nc>=0&&nc<n&&grid[nr][nc]==1) {
                            int root = uf.find(nr*n+nc);
                            if (seen.add(root)) total += uf.size(nr*n+nc);
                        }
                    }
                    best = Math.max(best, total);
                }
            }
        }
        return best;
    }

    public static void main(String[] args) {
        var s = new LC827();
        int r1 = s.largestIsland(new int[][]{{1,0},{0,1}});
        if (r1 != 3) throw new AssertionError("LC827 t1: got " + r1);
        int r2 = s.largestIsland(new int[][]{{1,1},{1,0}});
        if (r2 != 4) throw new AssertionError("LC827 t2: got " + r2);
        int r3 = s.largestIsland(new int[][]{{1,1},{1,1}});
        if (r3 != 4) throw new AssertionError("LC827 all-land: got " + r3);
    }
}
```

**Complexity.** Time O(n² α(n²)), Space O(n²).

---

## LC 947. Most Stones Removed with Same Row or Column

**Difficulty:** Medium

**Problem.** Remove the maximum number of stones such that no removed stone is isolated (a stone can be removed if it shares a row or column with another stone). Return the max stones removed.

**Key insight.** Stones sharing a row or column belong to the same component. Answer = total stones − number of components. Union by coordinate: offset column indices by a large constant to avoid collision with row indices.

```java
import java.util.*;

class LC947 {
    static class UnionFind {
        Map<Integer,Integer> parent = new HashMap<>();
        int components = 0;
        int find(int x){
            parent.putIfAbsent(x, x);
            if(parent.get(x)!=x) parent.put(x, find(parent.get(x)));
            return parent.get(x);
        }
        void union(int x, int y){
            int px=find(x), py=find(y);
            if(px==py) return;
            parent.put(px, py);
            components--;
        }
        void add(int x){ if(!parent.containsKey(x)){parent.put(x,x);components++;} }
    }

    public int removeStones(int[][] stones) {
        var uf = new UnionFind();
        for (var stone : stones) {
            int row = stone[0], col = stone[1] + 10001; // offset to avoid collision
            uf.add(row); uf.add(col);
            uf.union(row, col);
        }
        return stones.length - uf.components;
    }

    public static void main(String[] args) {
        var s = new LC947();
        int r1 = s.removeStones(new int[][]{{0,0},{0,1},{1,0},{1,2},{2,1},{2,2}});
        if (r1 != 5) throw new AssertionError("LC947 t1: got " + r1);
        int r2 = s.removeStones(new int[][]{{0,0},{0,2},{1,1},{2,0},{2,2}});
        if (r2 != 3) throw new AssertionError("LC947 t2: got " + r2);
        int r3 = s.removeStones(new int[][]{{0,0}});
        if (r3 != 0) throw new AssertionError("LC947 single: got " + r3);
    }
}
```

**Complexity.** Time O(n α(n)), Space O(n).

> **Java vs Rust:** Using `HashMap<Integer, Integer>` for the parent map boxes every index. Rust uses a plain `HashMap<i32, i32>` without boxing. For large inputs, prefer a two-pass approach to assign dense integer ids to rows and columns, then use array-based DSU.

---

## LC 990. Satisfiability of Equality Equations

**Difficulty:** Medium

**Problem.** Given equations of form `"a==b"` or `"a!=b"`, return whether they are all satisfiable.

**Key insight.** Process all `==` equations first to union variable pairs. Then verify no `!=` equation has both sides in the same component.

```java
import java.util.Arrays;

class LC990 {
    static class UnionFind {
        int[] parent, rank;
        UnionFind(int n){parent=new int[n];rank=new int[n];for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;}
        boolean connected(int x,int y){return find(x)==find(y);}
    }

    public boolean equationsPossible(String[] equations) {
        var uf = new UnionFind(26);
        // Pass 1: process all == equations
        for (var eq : equations)
            if (eq.charAt(1) == '=')
                uf.union(eq.charAt(0)-'a', eq.charAt(3)-'a');
        // Pass 2: check != equations
        for (var eq : equations)
            if (eq.charAt(1) == '!' && uf.connected(eq.charAt(0)-'a', eq.charAt(3)-'a'))
                return false;
        return true;
    }

    public static void main(String[] args) {
        var s = new LC990();
        boolean r1 = s.equationsPossible(new String[]{"a==b","b!=a"});
        if (r1) throw new AssertionError("LC990 t1: expected false");
        boolean r2 = s.equationsPossible(new String[]{"b==a","a==b"});
        if (!r2) throw new AssertionError("LC990 t2: expected true");
        boolean r3 = s.equationsPossible(new String[]{"a==b","b==c","a==c"});
        if (!r3) throw new AssertionError("LC990 t3: expected true");
        boolean r4 = s.equationsPossible(new String[]{"a==b","b!=c","c==a"});
        if (r4) throw new AssertionError("LC990 t4: expected false");
    }
}
```

**Complexity.** Time O(n α(26)) = O(n), Space O(1) (fixed 26-node DSU).

---

## Part 2 — Tier 2: Advanced DSU Patterns

---

## LC 130. Surrounded Regions

**Difficulty:** Medium | **Blind75:** ✓

**Problem.** Flip all `'O'` cells that are fully surrounded by `'X'` to `'X'`. Border-connected `'O'` regions are never flipped.

**Key insight.** Add a virtual node `n` (the "border" component). Union every border `'O'` cell with node `n`. Then union interior `'O'` cells with their `'O'` neighbors. Any `'O'` not connected to node `n` gets flipped.

> **Note:** Chapter 7 solves this with DFS from the border. The DSU approach makes the "border-connected" invariant explicit via a virtual node.

```java
import java.util.Arrays;

class LC130 {
    static class UnionFind {
        int[] parent, rank;
        UnionFind(int n){parent=new int[n];rank=new int[n];for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;}
        boolean connected(int x,int y){return find(x)==find(y);}
    }

    public void solve(char[][] board) {
        int rows = board.length, cols = board[0].length;
        int border = rows * cols;          // virtual border node
        var uf = new UnionFind(rows * cols + 1);
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (board[r][c] == 'O') {
                    int id = r * cols + c;
                    if (r == 0 || r == rows-1 || c == 0 || c == cols-1)
                        uf.union(id, border);
                    for (var d : dirs) {
                        int nr=r+d[0], nc=c+d[1];
                        if (nr>=0&&nr<rows&&nc>=0&&nc<cols&&board[nr][nc]=='O')
                            uf.union(id, nr*cols+nc);
                    }
                }
            }
        }
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (board[r][c] == 'O' && !uf.connected(r*cols+c, border))
                    board[r][c] = 'X';
    }

    public static void main(String[] args) {
        var s = new LC130();
        char[][] board = {
            {'X','X','X','X'},
            {'X','O','O','X'},
            {'X','X','O','X'},
            {'X','O','X','X'}
        };
        s.solve(board);
        if (board[1][1] != 'X') throw new AssertionError("LC130 inner O not flipped");
        if (board[3][1] != 'O') throw new AssertionError("LC130 border O wrongly flipped");
    }
}
```

**Complexity.** Time O(m·n α(m·n)), Space O(m·n).

---

## LC 305. Number of Islands II

**Difficulty:** Hard

**Problem.** Start with an `m×n` all-water grid. Process `k` `addLand(r, c)` operations. After each, return the current number of islands.

**Key insight.** Online DSU: initialize all cells as water (parent = -1). When adding land, create a new node, union with neighboring land cells, record count after each union.

```java
import java.util.*;

class LC305 {
    int[] parent, rank;
    int count;
    int cols;

    void init(int m, int n) {
        cols = n;
        parent = new int[m * n];
        rank   = new int[m * n];
        Arrays.fill(parent, -1);   // -1 = water
        count = 0;
    }

    int find(int x) {
        if (parent[x] != x) parent[x] = find(parent[x]);
        return parent[x];
    }

    void union(int x, int y) {
        int px = find(x), py = find(y);
        if (px == py) return;
        if (rank[px] < rank[py]) { int t=px; px=py; py=t; }
        parent[py] = px;
        if (rank[px] == rank[py]) rank[px]++;
        count--;
    }

    public List<Integer> numIslands2(int m, int n, int[][] positions) {
        init(m, n);
        var result = new ArrayList<Integer>();
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};

        for (var pos : positions) {
            int r = pos[0], c = pos[1], id = r * cols + c;
            if (parent[id] != -1) {          // duplicate addLand — skip
                result.add(count);
                continue;
            }
            parent[id] = id;                 // create new land node
            count++;
            for (var d : dirs) {
                int nr=r+d[0], nc=c+d[1];
                if (nr>=0&&nr<m&&nc>=0&&nc<n&&parent[nr*cols+nc]!=-1)
                    union(id, nr*cols+nc);
            }
            result.add(count);
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new LC305();
        var r1 = s.numIslands2(3, 3, new int[][]{{0,0},{0,1},{1,2},{2,1}});
        if (!r1.equals(List.of(1,1,2,3))) throw new AssertionError("LC305 t1: got " + r1);
        var r2 = s.numIslands2(1, 1, new int[][]{{0,0}});
        if (!r2.equals(List.of(1))) throw new AssertionError("LC305 t2: got " + r2);
    }
}
```

**Complexity.** Time O(k α(m·n)), Space O(m·n).

---

## LC 399. Evaluate Division

**Difficulty:** Medium

**Problem.** Given equations `A/B = k`, answer queries of the form `C/D`. Return `-1` if a query cannot be answered.

**Key insight.** Weighted DSU where `weight[x]` = value of `x / root(x)`. Finding the ratio `A/B = weight[A] / weight[B]` when they share the same root. Path compression must also update the weight.

```java
import java.util.*;

class LC399 {
    // Weighted DSU — weight[x] = x / root(x)
    int[] parent;
    double[] weight;

    int find(int x) {
        if (parent[x] != x) {
            int root = find(parent[x]);
            weight[x] *= weight[parent[x]];   // accumulate weight along path
            parent[x] = root;
        }
        return parent[x];
    }

    void union(int x, int y, double ratio) { // ratio = x / y
        int px = find(x), py = find(y);
        if (px == py) return;
        // weight[x] = x/px, weight[y] = y/py
        // We want px/py = (x/px) / (y/py) * ratio... wait:
        // ratio = x/y => x = ratio * y => px * weight[x] = ratio * (py * weight[y])
        // px / py = (ratio * weight[y]) / weight[x]
        parent[px] = py;
        weight[px] = ratio * weight[y] / weight[x];
    }

    public double[] calcEquation(List<List<String>> equations,
                                  double[] values,
                                  List<List<String>> queries) {
        var index = new HashMap<String, Integer>();
        int id = 0;
        for (var eq : equations) {
            if (!index.containsKey(eq.get(0))) index.put(eq.get(0), id++);
            if (!index.containsKey(eq.get(1))) index.put(eq.get(1), id++);
        }

        parent = new int[id]; weight = new double[id];
        for (int i = 0; i < id; i++) { parent[i] = i; weight[i] = 1.0; }

        for (int i = 0; i < equations.size(); i++) {
            int u = index.get(equations.get(i).get(0));
            int v = index.get(equations.get(i).get(1));
            union(u, v, values[i]);
        }

        var result = new double[queries.size()];
        for (int i = 0; i < queries.size(); i++) {
            var a = queries.get(i).get(0);
            var b = queries.get(i).get(1);
            if (!index.containsKey(a) || !index.containsKey(b)) { result[i] = -1; continue; }
            int pa = find(index.get(a)), pb = find(index.get(b));
            if (pa != pb) { result[i] = -1; continue; }
            result[i] = weight[index.get(a)] / weight[index.get(b)];
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new LC399();
        var eqs = List.of(List.of("a","b"), List.of("b","c"));
        double[] vals = {2.0, 3.0};
        var qs = List.of(List.of("a","c"), List.of("b","a"), List.of("a","e"), List.of("a","a"), List.of("x","x"));
        double[] res = s.calcEquation(eqs, vals, qs);
        if (Math.abs(res[0] - 6.0) > 1e-5) throw new AssertionError("LC399 a/c: got " + res[0]);
        if (Math.abs(res[1] - 0.5) > 1e-5) throw new AssertionError("LC399 b/a: got " + res[1]);
        if (res[2] != -1.0) throw new AssertionError("LC399 a/e: expected -1, got " + res[2]);
    }
}
```

**Complexity.** Time O((E + Q) α(V)), Space O(V).

> **Java vs Rust:** The weighted `double[]` alongside `int[]` parent is straightforward in Java. In Rust, you'd store `(usize, f64)` pairs or use a struct with two `Vec`s — same concept, explicit ownership.

---

## LC 765. Couples Holding Hands

**Difficulty:** Hard

**Problem.** `2n` people sit in `n` pairs of seats. Couple pairs are `(0,1), (2,3), ...`. Return the minimum number of swaps so every couple sits together.

**Key insight.** Each seat pair forms a node: seat pair `i` = node `i/2`. For each bench (two adjacent seats), union the couple-ids of the two occupants. Answer = n (pairs) − number of connected components after all unions. A connected component of size k needs exactly k−1 swaps to consolidate all couples.

```java
import java.util.Arrays;

class LC765 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
    }

    public int minSwapsCouples(int[] row) {
        int n = row.length / 2;        // number of couples = number of seat pairs
        var uf = new UnionFind(n);
        for (int i = 0; i < row.length; i += 2) {
            int c1 = row[i] / 2;       // couple id of left person
            int c2 = row[i + 1] / 2;   // couple id of right person
            uf.union(c1, c2);
        }
        // Each component of size k needs k-1 swaps; total = n - components
        return n - uf.count;
    }

    public static void main(String[] args) {
        var s = new LC765();
        int r1 = s.minSwapsCouples(new int[]{0,2,1,3});
        if (r1 != 1) throw new AssertionError("LC765 t1: got " + r1);
        int r2 = s.minSwapsCouples(new int[]{3,2,0,1});
        if (r2 != 0) throw new AssertionError("LC765 t2: got " + r2);
        int r3 = s.minSwapsCouples(new int[]{5,4,2,6,3,1,0,7});
        if (r3 != 2) throw new AssertionError("LC765 t3: got " + r3);
    }
}
```

**Complexity.** Time O(n α(n)), Space O(n).

---

## LC 803. Bricks Falling When Hit

**Difficulty:** Hard

**Problem.** Start with a brick grid. Process `hits[]` — each removes a brick. A brick falls if, after removal, it is no longer connected (directly or via other bricks) to the top row. Return the number of bricks that fall for each hit.

**Key insight.** Reverse time: start from the final state (all hits applied) and add bricks back in reverse. When adding a brick, union it with its neighbors. A brick is stable if it is connected to a virtual "ceiling" node. After adding a brick, `stableAfter - stableBefore - 1` bricks newly fall (the -1 excludes the added brick itself).

```java
import java.util.*;

class LC803 {
    int[] parent, rank, size;
    int n, cols, ceiling;

    void init(int rows, int c) {
        cols = c;
        ceiling = rows * c;   // virtual ceiling node
        parent = new int[rows * c + 1];
        rank   = new int[rows * c + 1];
        size   = new int[rows * c + 1];
        Arrays.fill(size, 1);
        for (int i = 0; i <= rows * c; i++) parent[i] = i;
    }

    int find(int x) { if(parent[x]!=x)parent[x]=find(parent[x]); return parent[x]; }

    void union(int x, int y) {
        int px=find(x), py=find(y); if(px==py)return;
        if(rank[px]<rank[py]){int t=px;px=py;py=t;}
        parent[py]=px; size[px]+=size[py];
        if(rank[px]==rank[py])rank[px]++;
    }

    int stableCount() { return size[find(ceiling)]; }

    public int[] hitBricks(int[][] grid, int[][] hits) {
        int rows = grid.length, cols2 = grid[0].length;
        init(rows, cols2);
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};

        // Clone grid and remove all hit bricks
        var g = new int[rows][cols2];
        for (int r = 0; r < rows; r++) g[r] = Arrays.copyOf(grid[r], cols2);
        for (var h : hits) g[h[0]][h[1]] = 0;

        // Build initial DSU from final state
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols2; c++)
                if (g[r][c] == 1) {
                    int id = r * cols2 + c;
                    if (r == 0) union(id, ceiling);
                    if (r > 0 && g[r-1][c] == 1) union(id, (r-1)*cols2+c);
                    if (c > 0 && g[r][c-1] == 1) union(id, r*cols2+c-1);
                }

        var result = new int[hits.length];
        // Reverse hits
        for (int i = hits.length - 1; i >= 0; i--) {
            int r = hits[i][0], c = hits[i][1];
            if (grid[r][c] == 0) { result[i] = 0; continue; } // was already empty

            int before = stableCount();
            int id = r * cols2 + c;
            g[r][c] = 1;
            if (r == 0) union(id, ceiling);
            for (var d : dirs) {
                int nr=r+d[0], nc=c+d[1];
                if (nr>=0&&nr<rows&&nc>=0&&nc<cols2&&g[nr][nc]==1)
                    union(id, nr*cols2+nc);
            }
            int after = stableCount();
            result[i] = Math.max(0, after - before - 1);
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new LC803();
        int[] r1 = s.hitBricks(new int[][]{{1,0,0,0},{1,1,1,0}}, new int[][]{{1,0}});
        if (r1[0] != 2) throw new AssertionError("LC803 t1: got " + r1[0]);
        int[] r2 = s.hitBricks(new int[][]{{1,0,0,0},{1,1,0,0}}, new int[][]{{1,1},{1,0}});
        if (r2[0] != 0 || r2[1] != 0) throw new AssertionError("LC803 t2: got " + Arrays.toString(r2));
    }
}
```

**Complexity.** Time O((m·n + k) α(m·n)), Space O(m·n).

---

## LC 839. Similar String Groups

**Difficulty:** Hard

**Problem.** Two strings are similar if they are identical or differ in exactly two positions (which can be swapped). Find the number of connected components (groups) of similar strings.

```java
import java.util.Arrays;

class LC839 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;}
    }

    boolean similar(String a, String b) {
        int diff = 0;
        for (int i = 0; i < a.length(); i++)
            if (a.charAt(i) != b.charAt(i) && ++diff > 2) return false;
        return diff == 0 || diff == 2;
    }

    public int numSimilarGroups(String[] strs) {
        int n = strs.length;
        var uf = new UnionFind(n);
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                if (similar(strs[i], strs[j])) uf.union(i, j);
        return uf.count;
    }

    public static void main(String[] args) {
        var s = new LC839();
        int r1 = s.numSimilarGroups(new String[]{"tars","rats","arts","star"});
        if (r1 != 2) throw new AssertionError("LC839 t1: got " + r1);
        int r2 = s.numSimilarGroups(new String[]{"omv","ovm"});
        if (r2 != 1) throw new AssertionError("LC839 t2: got " + r2);
    }
}
```

**Complexity.** Time O(n² · L · α(n)) where L = string length, Space O(n).

---

## LC 952. Largest Component Size by Common Factor

**Difficulty:** Hard

**Problem.** Union integers that share a common factor > 1. Return the size of the largest component.

**Key insight.** For each number, factorize it and union the number with each prime factor (using the prime as a virtual node). This avoids O(n²) pairwise comparisons. Count component sizes by tallying actual numbers per root (not `size[]`, which counts virtual factor nodes too).

```java
import java.util.*;

class LC952 {
    static class UnionFind {
        int[] parent, rank;
        UnionFind(int n){parent=new int[n];rank=new int[n];for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;}
    }

    public int largestComponentSize(int[] nums) {
        int maxVal = 0;
        for (int n : nums) maxVal = Math.max(maxVal, n);
        var uf = new UnionFind(maxVal + 1);

        for (int n : nums) {
            for (int f = 2; (long) f * f <= n; f++) {
                if (n % f == 0) {
                    uf.union(n, f);
                    uf.union(n, n / f);
                }
            }
        }
        // Count only original numbers per root (virtual factor nodes must not be counted)
        var countByRoot = new HashMap<Integer, Integer>();
        int best = 0;
        for (int n : nums) {
            int root = uf.find(n);
            int cnt = countByRoot.merge(root, 1, Integer::sum);
            best = Math.max(best, cnt);
        }
        return best;
    }

    public static void main(String[] args) {
        var s = new LC952();
        int r1 = s.largestComponentSize(new int[]{4,6,15,35});
        if (r1 != 4) throw new AssertionError("LC952 t1: got " + r1);
        int r2 = s.largestComponentSize(new int[]{20,50,9,63});
        if (r2 != 2) throw new AssertionError("LC952 t2: got " + r2);
        int r3 = s.largestComponentSize(new int[]{2,3,6,7,4,12,21,39});
        if (r3 != 8) throw new AssertionError("LC952 t3: got " + r3);
    }
}
```

**Complexity.** Time O(n · sqrt(maxVal) · α(maxVal)), Space O(maxVal).

---

## LC 959. Regions Cut By Slashes

**Difficulty:** Medium

**Problem.** A grid of `'/'`, `'\\'`, and `' '` characters. Count the number of regions.

**Key insight.** Split each cell into 4 triangles: 0=top, 1=right, 2=bottom, 3=left. A `' '` unites all 4 triangles in the cell. A `'/'` unites top+left and bottom+right. A `'\\'` unites top+right and bottom+left. Adjacent cells share an edge: right neighbor's left triangle (3) = current cell's right triangle (1), etc.

```java
import java.util.Arrays;

class LC959 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;}
    }

    public int regionsBySlashes(String[] grid) {
        int n = grid.length;
        // 4 triangles per cell: index(r,c,t) = (r*n+c)*4 + t
        // t: 0=top, 1=right, 2=bottom, 3=left
        var uf = new UnionFind(n * n * 4);

        for (int r = 0; r < n; r++) {
            for (int c = 0; c < n; c++) {
                int base = (r * n + c) * 4;
                char ch = grid[r].charAt(c);
                // Union within cell
                if (ch == '/') {
                    uf.union(base + 0, base + 3); // top + left
                    uf.union(base + 1, base + 2); // right + bottom
                } else if (ch == '\\') {
                    uf.union(base + 0, base + 1); // top + right
                    uf.union(base + 2, base + 3); // bottom + left
                } else {
                    uf.union(base + 0, base + 1);
                    uf.union(base + 1, base + 2);
                    uf.union(base + 2, base + 3);
                }
                // Union with right neighbor: current right (1) = neighbor left (3)
                if (c + 1 < n) uf.union(base + 1, (r * n + c + 1) * 4 + 3);
                // Union with bottom neighbor: current bottom (2) = neighbor top (0)
                if (r + 1 < n) uf.union(base + 2, ((r + 1) * n + c) * 4 + 0);
            }
        }
        return uf.count;
    }

    public static void main(String[] args) {
        var s = new LC959();
        int r1 = s.regionsBySlashes(new String[]{" /","/ "});
        if (r1 != 2) throw new AssertionError("LC959 t1: got " + r1);
        int r2 = s.regionsBySlashes(new String[]{" /","  "});
        if (r2 != 1) throw new AssertionError("LC959 t2: got " + r2);
        int r3 = s.regionsBySlashes(new String[]{"\\/","/\\"});
        if (r3 != 4) throw new AssertionError("LC959 t3: got " + r3);
    }
}
```

**Complexity.** Time O(n² α(n²)), Space O(n²).

---

## LC 1101. The Earliest Moment When Everyone Become Friends

**Difficulty:** Medium

**Problem.** Given friendship events `[timestamp, personA, personB]` sorted by time, return the earliest time when all `n` people are in one connected component. Return -1 if impossible.

```java
import java.util.Arrays;

class LC1101 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
    }

    public int earliestAcq(int[][] logs, int n) {
        Arrays.sort(logs, (a, b) -> a[0] - b[0]);
        var uf = new UnionFind(n);
        for (var log : logs) {
            uf.union(log[1], log[2]);
            if (uf.count == 1) return log[0];
        }
        return -1;
    }

    public static void main(String[] args) {
        var s = new LC1101();
        int[][] logs = {{20190101,0,1},{20190104,3,4},{20190107,2,3},
                        {20190211,1,5},{20190224,2,4},{20190301,0,3},{20190312,1,2},{20190322,4,5}};
        int r1 = s.earliestAcq(logs, 6);
        if (r1 != 20190301) throw new AssertionError("LC1101 t1: got " + r1);
    }
}
```

**Complexity.** Time O(k log k + k α(n)), Space O(n).

---

## LC 1202. Smallest String With Swaps

**Difficulty:** Medium

**Problem.** Given pairs of indices that can be freely swapped, return the lexicographically smallest string achievable.

**Key insight.** Characters at indices in the same component can be rearranged in any order. For each component, sort the characters and place them back in sorted order at the sorted index positions.

```java
import java.util.*;

class LC1202 {
    static class UnionFind {
        int[] parent, rank;
        UnionFind(int n){parent=new int[n];rank=new int[n];for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;}
    }

    public String smallestStringWithSwaps(String s, List<List<Integer>> pairs) {
        int n = s.length();
        var uf = new UnionFind(n);
        for (var pair : pairs) uf.union(pair.get(0), pair.get(1));

        // Group indices by root
        var groups = new HashMap<Integer, List<Integer>>();
        for (int i = 0; i < n; i++)
            groups.computeIfAbsent(uf.find(i), k -> new ArrayList<>()).add(i);

        var chars = s.toCharArray();
        for (var indices : groups.values()) {
            var sortedIdx = new ArrayList<>(indices);
            Collections.sort(sortedIdx);
            var sortedChars = new char[sortedIdx.size()];
            for (int i = 0; i < sortedIdx.size(); i++) sortedChars[i] = chars[sortedIdx.get(i)];
            Arrays.sort(sortedChars);
            for (int i = 0; i < sortedIdx.size(); i++) chars[sortedIdx.get(i)] = sortedChars[i];
        }
        return new String(chars);
    }

    public static void main(String[] args) {
        var s = new LC1202();
        String r1 = s.smallestStringWithSwaps("dcab", List.of(List.of(0,3), List.of(1,2)));
        if (!r1.equals("bacd")) throw new AssertionError("LC1202 t1: got " + r1);
        String r2 = s.smallestStringWithSwaps("dcab", List.of(List.of(0,3), List.of(1,2), List.of(0,2)));
        if (!r2.equals("abcd")) throw new AssertionError("LC1202 t2: got " + r2);
    }
}
```

**Complexity.** Time O((n + p) α(n) + n log n), Space O(n).

---

## LC 1319. Number of Operations to Make Network Connected

**Difficulty:** Medium

**Problem.** Given `n` computers and cable connections (may have redundant cables), return the minimum number of cables to reconnect the network, or -1 if impossible.

**Key insight.** Count redundant edges (union returns false) = extra cables available. Count connected components after all unions. Need `components - 1` cables. Return -1 if extras < components - 1.

```java
import java.util.Arrays;

class LC1319 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
    }

    public int makeConnected(int n, int[][] connections) {
        var uf = new UnionFind(n);
        int extras = 0;
        for (var c : connections)
            if (!uf.union(c[0], c[1])) extras++;
        int needed = uf.count - 1;
        return extras >= needed ? needed : -1;
    }

    public static void main(String[] args) {
        var s = new LC1319();
        int r1 = s.makeConnected(4, new int[][]{{0,1},{0,2},{1,2}});
        if (r1 != 1) throw new AssertionError("LC1319 t1: got " + r1);
        int r2 = s.makeConnected(6, new int[][]{{0,1},{0,2},{0,3},{1,2}});
        if (r2 != -1) throw new AssertionError("LC1319 t2: got " + r2);
        int r3 = s.makeConnected(5, new int[][]{{0,1},{0,2},{3,4},{2,3}});
        if (r3 != 0) throw new AssertionError("LC1319 t3: got " + r3);
    }
}
```

**Complexity.** Time O((n + E) α(n)), Space O(n).

---

## LC 1489. Find Critical and Pseudo-Critical Edges in MST

**Difficulty:** Hard

**Problem.** Given a weighted undirected graph, find which edges are critical (removing them increases MST weight) and pseudo-critical (appear in some but not all MSTs).

**Key insight.** Compute base MST weight with Kruskal. For each edge e:
- **Critical**: MST without e has higher weight or disconnects graph.
- **Pseudo-critical**: forcing e into the MST yields same weight as base MST.

```java
import java.util.*;

class LC1489 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
    }

    // Returns {total MST weight, components remaining} running Kruskal
    // skipIdx: skip this edge index (-1 = skip none)
    // forceIdx: force this edge first (-1 = force none)
    int[] kruskal(int[][] edges, int n, int skipIdx, int forceIdx) {
        var uf = new UnionFind(n);
        int weight = 0;
        if (forceIdx >= 0) {
            uf.union(edges[forceIdx][0], edges[forceIdx][1]);
            weight += edges[forceIdx][2];
        }
        for (int i = 0; i < edges.length; i++) {
            if (i == skipIdx) continue;
            if (uf.union(edges[i][0], edges[i][1])) weight += edges[i][2];
        }
        return new int[]{weight, uf.count};
    }

    public List<List<Integer>> findCriticalAndPseudoCriticalEdges(int n, int[][] edges) {
        // Attach original indices, sort by weight
        int m = edges.length;
        var indexed = new int[m][4];
        for (int i = 0; i < m; i++) {
            indexed[i][0] = edges[i][0]; indexed[i][1] = edges[i][1];
            indexed[i][2] = edges[i][2]; indexed[i][3] = i;
        }
        Arrays.sort(indexed, Comparator.comparingInt(e -> e[2]));

        var base = kruskal(indexed, n, -1, -1);
        int baseMST = base[0];

        var critical = new ArrayList<Integer>();
        var pseudo   = new ArrayList<Integer>();

        for (int i = 0; i < m; i++) {
            // Test critical: skip edge i
            var skip = kruskal(indexed, n, i, -1);
            if (skip[1] > 1 || skip[0] > baseMST) {
                critical.add(indexed[i][3]);
                continue;
            }
            // Test pseudo-critical: force edge i
            var forced = kruskal(indexed, n, -1, i);
            if (forced[0] == baseMST) pseudo.add(indexed[i][3]);
        }
        return List.of(critical, pseudo);
    }

    public static void main(String[] args) {
        var s = new LC1489();
        var r1 = s.findCriticalAndPseudoCriticalEdges(5,
            new int[][]{{0,1,1},{1,2,1},{2,3,2},{0,3,2},{0,4,3},{3,4,3},{1,4,6}});
        if (!r1.get(0).equals(List.of(0,1))) throw new AssertionError("LC1489 t1 critical: " + r1.get(0));
        if (!r1.get(1).equals(List.of(2,3,4,5))) throw new AssertionError("LC1489 t1 pseudo: " + r1.get(1));
    }
}
```

**Complexity.** Time O(m² α(n)) where m = number of edges, Space O(n + m).

---

## LC 1559. Detect Cycles in 2D Grid

**Difficulty:** Medium

**Problem.** Given a character grid, detect if any cycle of the same character exists (length ≥ 4, no revisiting the same cell back-to-back).

```java
import java.util.Arrays;

class LC1559 {
    static class UnionFind {
        int[] parent, rank;
        UnionFind(int n){parent=new int[n];rank=new int[n];for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;return true;}
    }

    public boolean containsCycle(char[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        var uf = new UnionFind(rows * cols);
        // Only check right and down to avoid processing each edge twice
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (c + 1 < cols && grid[r][c] == grid[r][c+1])
                    if (!uf.union(r*cols+c, r*cols+c+1)) return true;
                if (r + 1 < rows && grid[r][c] == grid[r+1][c])
                    if (!uf.union(r*cols+c, (r+1)*cols+c)) return true;
            }
        }
        return false;
    }

    public static void main(String[] args) {
        var s = new LC1559();
        boolean r1 = s.containsCycle(new char[][]{
            {'a','a','a','a'},{'a','b','b','a'},{'a','b','b','a'},{'a','a','a','a'}});
        if (!r1) throw new AssertionError("LC1559 t1: expected true");
        boolean r2 = s.containsCycle(new char[][]{
            {'c','c','c','a'},{'c','d','c','c'},{'c','c','e','c'},{'f','c','c','c'}});
        if (!r2) throw new AssertionError("LC1559 t2: expected true");
        boolean r3 = s.containsCycle(new char[][]{
            {'a','b','b'},{'b','z','b'},{'b','b','a'}});
        if (r3) throw new AssertionError("LC1559 t3: expected false");
    }
}
```

**Complexity.** Time O(m·n α(m·n)), Space O(m·n).

---

## LC 1584. Min Cost to Connect All Points

**Difficulty:** Medium

**Problem.** Given points in a 2D plane, find the minimum cost to connect all points where cost = Manhattan distance. This is a minimum spanning tree problem.

**Key insight.** Generate all edges, sort by Manhattan distance, run Kruskal's algorithm. Stop when `n-1` edges have been added.

```java
import java.util.*;

class LC1584 {
    static class UnionFind {
        int[] parent, rank; int count;
        UnionFind(int n){parent=new int[n];rank=new int[n];count=n;
            for(int i=0;i<n;i++)parent[i]=i;}
        int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
        boolean union(int x,int y){int px=find(x),py=find(y);if(px==py)return false;
            if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;
            if(rank[px]==rank[py])rank[px]++;count--;return true;}
    }

    public int minCostConnectPoints(int[][] points) {
        int n = points.length;
        // Build all edges: O(n^2)
        var edges = new ArrayList<int[]>();
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++) {
                int dist = Math.abs(points[i][0]-points[j][0]) + Math.abs(points[i][1]-points[j][1]);
                edges.add(new int[]{dist, i, j});
            }
        edges.sort(Comparator.comparingInt(e -> e[0]));

        var uf = new UnionFind(n);
        int cost = 0, added = 0;
        for (var e : edges) {
            if (uf.union(e[1], e[2])) {
                cost += e[0];
                if (++added == n - 1) break;
            }
        }
        return cost;
    }

    public static void main(String[] args) {
        var s = new LC1584();
        int r1 = s.minCostConnectPoints(new int[][]{{0,0},{2,2},{3,10},{5,2},{7,0}});
        if (r1 != 20) throw new AssertionError("LC1584 t1: got " + r1);
        int r2 = s.minCostConnectPoints(new int[][]{{3,12},{-2,5},{-4,1}});
        if (r2 != 18) throw new AssertionError("LC1584 t2: got " + r2);
    }
}
```

**Complexity.** Time O(n² log n), Space O(n²).

> **Java vs Rust:** `edges.sort(Comparator.comparingInt(e -> e[0]))` — Java's lambda comparator. Rust uses `.sort_by_key(|e| e[0])` or `.sort_unstable_by_key(...)`. Both are clean; Rust's `sort_unstable` avoids allocating a merge-sort buffer.

---

## LC 1970. Last Day Where You Can Still Cross

**Difficulty:** Hard

**Problem.** A grid of cells is flooded day by day. On day `d`, cell `cells[d-1]` becomes water. Return the last day you can walk from top row to bottom row (stepping only on land cells).

**Key insight.** Reverse time: start from the final state (all water) and add land cells back from day `k` down to day `1`. Use virtual nodes for "top" and "bottom" rows. The answer is the first day (in reverse) when top and bottom become connected.

```java
import java.util.*;

class LC1970 {
    int[] parent, rank, sz;

    void init(int n) {
        parent=new int[n]; rank=new int[n]; sz=new int[n];
        Arrays.fill(sz,1); for(int i=0;i<n;i++) parent[i]=i;
    }
    int find(int x){if(parent[x]!=x)parent[x]=find(parent[x]);return parent[x];}
    void union(int x,int y){int px=find(x),py=find(y);if(px==py)return;
        if(rank[px]<rank[py]){int t=px;px=py;py=t;}parent[py]=px;sz[px]+=sz[py];
        if(rank[px]==rank[py])rank[px]++;}
    boolean connected(int x,int y){return find(x)==find(y);}

    public int latestDayToCross(int row, int col, int[][] cells) {
        // nodes: row*col grid cells + virtual top (row*col) + virtual bottom (row*col+1)
        int top = row * col, bottom = row * col + 1;
        init(row * col + 2);
        int[][] dirs = {{0,1},{1,0},{0,-1},{-1,0}};

        // Start with all water; mark land cells in reverse
        var isLand = new boolean[row][col];

        for (int day = cells.length - 1; day >= 0; day--) {
            int r = cells[day][0] - 1, c = cells[day][1] - 1;
            isLand[r][c] = true;
            int id = r * col + c;
            // Connect to virtual nodes
            if (r == 0)       union(id, top);
            if (r == row - 1) union(id, bottom);
            // Connect to neighboring land cells
            for (var d : dirs) {
                int nr=r+d[0], nc=c+d[1];
                if (nr>=0&&nr<row&&nc>=0&&nc<col&&isLand[nr][nc])
                    union(id, nr*col+nc);
            }
            if (connected(top, bottom)) return day; // day is 0-indexed here; cells are 1-indexed
        }
        return 0;
    }

    public static void main(String[] args) {
        var s = new LC1970();
        int r1 = s.latestDayToCross(2, 2, new int[][]{{1,1},{2,1},{1,2},{2,2}});
        if (r1 != 2) throw new AssertionError("LC1970 t1: got " + r1);
        int r2 = s.latestDayToCross(2, 2, new int[][]{{1,1},{1,2},{2,1},{2,2}});
        if (r2 != 1) throw new AssertionError("LC1970 t2: got " + r2);
        int r3 = s.latestDayToCross(3, 3, new int[][]{{1,2},{2,1},{3,3},{2,2},{1,1},{1,3},{2,3},{3,2},{3,1}});
        if (r3 != 3) throw new AssertionError("LC1970 t3: got " + r3);
    }
}
```

**Complexity.** Time O(m·n α(m·n)) where m = row, n = col, Space O(m·n).

---

## Patterns & Tips

### DSU Pattern Taxonomy

| Pattern | Key Technique | Representative Problems |
|---|---|---|
| Basic component counting | `count` field in DSU | LC 547, LC 323 (lc07), LC 1319 |
| Grid flattening | `id = r * cols + c` | LC 200, LC 695, LC 827, LC 959, LC 1970 |
| Virtual node | Extra node for "boundary" | LC 130 (border), LC 803 (ceiling), LC 1970 (top/bottom) |
| Reverse time (offline) | Process in reverse, union = add | LC 803, LC 1970, LC 305 |
| Coordinate compression | Map strings/coords to int ids | LC 721, LC 947 |
| Weighted DSU | `weight[]` alongside `parent[]` | LC 399 |
| Factor-based union | Union with prime factors | LC 952 |
| Triangle subdivision | 4 triangles per cell | LC 959 |
| Kruskal MST | Sort edges, union until n-1 | LC 1584, LC 1489 |
| Two-pass (== then !=) | Process equality before inequality | LC 990 |

### When to Reach for DSU

Use DSU when you need to:
1. Track connected components dynamically (especially with online `union` operations)
2. Detect cycles in an undirected graph (edge whose endpoints are already connected = cycle)
3. Merge groups and answer "are X and Y in the same group?" queries efficiently
4. Reverse a destructive process (removal → addition in reverse) to use online unions
5. Build a minimum spanning tree (Kruskal's algorithm)

Prefer BFS/DFS over DSU when:
- You need the actual path between nodes (DSU only answers connectivity)
- The graph is directed (DSU is inherently undirected)
- Component structure must be traversed, not just counted

### Java Implementation Checklist

- **Path compression** in `find()` flattens the tree; recursive form is idiomatic and safe for LeetCode constraints.
- **Union by rank** (or size) prevents degenerate O(n) chains. Always include it.
- **`count` field**: initialize to `n`; decrement in `union` only when merging distinct components.
- **Grid index**: `r * cols + c` — keep `cols` as a local variable or field; never use `rows` by mistake.
- **Virtual nodes**: allocate DSU with size `n + k` where `k` = number of virtual nodes. Index virtual nodes at positions `n`, `n+1`, etc.
- **Online vs offline**: for "add operations", use online DSU (LC 305, LC 1970). For "remove operations", reverse to additions.
- **Weighted DSU**: update `weight[x] *= weight[parent[x]]` during path compression before updating `parent[x]`.

### Java vs Rust — DSU Summary

| Aspect | Java | Rust |
|---|---|---|
| Parent array | `int[] parent` — can hold negative values (use carefully) | `Vec<usize>` — non-negative by type |
| Recursion limit | JVM default ~500-1000 frames; safe for compressed DSU | No stack limit issue with iterative find |
| Boxing overhead | `HashMap<Integer,Integer>` boxes keys | `HashMap<i32, i32>` — no boxing |
| Struct fields | Add `int[] size`, `int count` freely | Add `size: Vec<usize>`, `count: usize` to struct |
| Lifetime/ownership | GC handles aliased references freely | Struct owns its `Vec`s; pass `&mut UnionFind` |
| Static inner class | `static class UnionFind { ... }` inside outer class | Standalone `struct` + `impl` block |

> **Weighted DSU in Rust** requires the same recursive path compression trick with an explicit `weight` `Vec<f64>` — there is no language-level difference, just `f64` vs Java's `double`.
