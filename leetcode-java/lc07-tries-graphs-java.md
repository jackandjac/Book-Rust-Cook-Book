# LC-07: Tries & Graphs — Java 17+ Edition

> **Cookbook Philosophy:** Every problem includes a complete, runnable solution with passing tests. All examples target Java 17+. The driver pattern uses `public static void main(String[] args)` with `throw new AssertionError("msg: got " + actual)` — no JUnit, no `assert` keyword.

> **Java vs Rust — Trie & Graph Mental Model:**
> In Java a `TrieNode` is a plain object with `TrieNode[] children = new TrieNode[26]` and object references take the place of Rust's `Option<Box<TrieNode>>`. There is no ownership to transfer: you just assign. For graphs, Java's `Map<Integer, List<Integer>>` or `List<List<Integer>>` adjacency lists replace Rust's index-based `Vec<Vec<usize>>`. Shared mutable graph nodes (`class Node { List<Node> neighbors }`) are trivially mutable in Java because the JVM's garbage collector handles aliased references; Rust forces you to reach for `Rc<RefCell<T>>` for the same pattern. The practical effect: Java graph code looks almost identical to pseudocode, while Rust graph code reveals the underlying ownership structure explicitly.

---

## Problem Overview

| # | Problem | Difficulty | Blind75 | NeetCode150 |
|---|---------|-----------|---------|-------------|
| LC 208 | [Implement Trie](#1-implement-trie-lc-208) | Medium | ✓ | ✓ |
| LC 211 | [Add and Search Words](#2-add-and-search-words-lc-211) | Medium | ✓ | ✓ |
| LC 212 | [Word Search II](#3-word-search-ii-lc-212) | Hard | ✓ | ✓ |
| LC 200 | [Number of Islands](#4-number-of-islands-lc-200) | Medium | ✓ | ✓ |
| LC 133 | [Clone Graph](#5-clone-graph-lc-133) | Medium | ✓ | ✓ |
| LC 695 | [Max Area of Island](#6-max-area-of-island-lc-695) | Medium | — | ✓ |
| LC 417 | [Pacific Atlantic Water Flow](#7-pacific-atlantic-water-flow-lc-417) | Medium | ✓ | ✓ |
| LC 130 | [Surrounded Regions](#8-surrounded-regions-lc-130) | Medium | ✓ | ✓ |
| LC 994 | [Rotting Oranges](#9-rotting-oranges-lc-994) | Medium | — | ✓ |
| LC 286 | [Walls and Gates](#10-walls-and-gates-lc-286) | Medium | — | ✓ |
| LC 207 | [Course Schedule](#11-course-schedule-lc-207) | Medium | ✓ | ✓ |
| LC 210 | [Course Schedule II](#12-course-schedule-ii-lc-210) | Medium | ✓ | ✓ |
| LC 684 | [Redundant Connection](#13-redundant-connection-lc-684) | Medium | — | ✓ |
| LC 323 | [Number of Connected Components](#14-number-of-connected-components-lc-323) | Medium | ✓ | ✓ |
| LC 261 | [Graph Valid Tree](#15-graph-valid-tree-lc-261) | Medium | ✓ | ✓ |
| LC 127 | [Word Ladder](#16-word-ladder-lc-127) | Hard | ✓ | ✓ |

---

## Shared Data Structures

These types appear across multiple solutions.

### Trie Node

```java
class TrieNode {
    TrieNode[] children = new TrieNode[26];
    boolean isEnd;
}
```

`children[0]` = `'a'`, `children[25]` = `'z'`. A `null` slot means no child for that letter.

### Union-Find (Path Compression + Union by Rank)

Used by problems 13, 14, and 15. Iterative `find` avoids stack overflow on large inputs.

```java
class UnionFind {
    private final int[] parent;
    private final int[] rank;
    private int count;

    UnionFind(int n) {
        parent = new int[n];
        rank   = new int[n];
        count  = n;
        for (int i = 0; i < n; i++) parent[i] = i;
    }

    /** Iterative path-compressed find. */
    int find(int x) {
        while (parent[x] != x) {
            parent[x] = parent[parent[x]]; // path halving
            x = parent[x];
        }
        return x;
    }

    /** Union by rank. Returns false when x and y are already connected. */
    boolean union(int x, int y) {
        int rx = find(x), ry = find(y);
        if (rx == ry) return false;
        if (rank[rx] < rank[ry])      parent[rx] = ry;
        else if (rank[rx] > rank[ry]) parent[ry] = rx;
        else { parent[ry] = rx; rank[rx]++; }
        count--;
        return true;
    }

    int count() { return count; }
}
```

---

## Part 1 — Tries

---

## 1. Implement Trie (LC #208)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Implement a prefix tree supporting `insert(word)`, `search(word)` (exact match), and `startsWith(prefix)` (prefix match).

### Key Insight

Walk character by character through `children` using `ch - 'a'` as the index. On `insert`, create missing nodes lazily. On `search`, walk to the end and check `isEnd`. On `startsWith`, walk without requiring `isEnd`.

### Solution

```java
class Trie {
    private static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private final TrieNode root = new TrieNode();

    public void insert(String word) {
        var node = root;
        for (char ch : word.toCharArray()) {
            int idx = ch - 'a';
            if (node.children[idx] == null) node.children[idx] = new TrieNode();
            node = node.children[idx];
        }
        node.isEnd = true;
    }

    public boolean search(String word) {
        var node = findNode(word);
        return node != null && node.isEnd;
    }

    public boolean startsWith(String prefix) {
        return findNode(prefix) != null;
    }

    private TrieNode findNode(String s) {
        var node = root;
        for (char ch : s.toCharArray()) {
            int idx = ch - 'a';
            if (node.children[idx] == null) return null;
            node = node.children[idx];
        }
        return node;
    }

    public static void main(String[] args) {
        var t = new Trie();
        t.insert("apple");

        if (!t.search("apple"))
            throw new AssertionError("search apple: expected true, got false");
        if (t.search("app"))
            throw new AssertionError("search app before insert: expected false, got true");
        if (!t.startsWith("app"))
            throw new AssertionError("startsWith app: expected true, got false");

        t.insert("app");
        if (!t.search("app"))
            throw new AssertionError("search app after insert: expected true, got false");

        // Empty string edge case
        var t2 = new Trie();
        t2.insert("");
        if (!t2.search(""))
            throw new AssertionError("search empty string: expected true");

        System.out.println("LC208 Implement Trie: all tests passed");
    }
}
```

**Time:** O(m) per operation where m = word length.  
**Space:** O(m·n) total for n words.

**Java notes:** `children` is a fixed `TrieNode[26]`; slots are `null` until created. `var node = root` uses Java 10+ local-variable type inference — the type is `TrieNode`, inferred from the right-hand side. `toCharArray()` is idiomatic for iterating characters in Java; alternatively use `word.charAt(i)` in an index loop.

---

## 2. Add and Search Words (LC #211)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Design a data structure that supports `addWord(word)` and `search(word)` where `.` in the search pattern matches any single letter.

### Key Insight

Same trie as #208. When `search` encounters `.`, recursively try all 26 non-null children. Exact characters follow the normal trie path.

### Solution

```java
class WordDictionary {
    private static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private final TrieNode root = new TrieNode();

    public void addWord(String word) {
        var node = root;
        for (char ch : word.toCharArray()) {
            int idx = ch - 'a';
            if (node.children[idx] == null) node.children[idx] = new TrieNode();
            node = node.children[idx];
        }
        node.isEnd = true;
    }

    public boolean search(String word) {
        return dfs(root, word, 0);
    }

    private boolean dfs(TrieNode node, String word, int i) {
        if (i == word.length()) return node.isEnd;
        char ch = word.charAt(i);
        if (ch == '.') {
            for (TrieNode child : node.children) {
                if (child != null && dfs(child, word, i + 1)) return true;
            }
            return false;
        }
        int idx = ch - 'a';
        return node.children[idx] != null && dfs(node.children[idx], word, i + 1);
    }

    public static void main(String[] args) {
        var wd = new WordDictionary();
        wd.addWord("bad");
        wd.addWord("dad");
        wd.addWord("mad");

        if (wd.search("pad"))
            throw new AssertionError("search pad: expected false, got true");
        if (!wd.search("bad"))
            throw new AssertionError("search bad: expected true, got false");
        if (!wd.search(".ad"))
            throw new AssertionError("search .ad: expected true, got false");
        if (!wd.search("b.."))
            throw new AssertionError("search b..: expected true, got false");

        // No match
        var wd2 = new WordDictionary();
        wd2.addWord("abc");
        if (wd2.search("xyz"))
            throw new AssertionError("search xyz: expected false");
        if (wd2.search("abcd"))
            throw new AssertionError("search abcd (too long): expected false");

        System.out.println("LC211 Add and Search Words: all tests passed");
    }
}
```

**Time:** O(m) insert; O(m · 26^k) search worst-case where k = number of wildcards.  
**Space:** O(m·n).

**Java notes:** The DFS passes the string and current index `i` rather than creating substrings at each level — this avoids O(m) allocations per recursion step. Iterating `node.children` directly (not through an index) is cleaner when checking all 26 slots.

---

## 3. Word Search II (LC #212)

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` character board and a list of words, return all words that can be found by a path of adjacent (horizontal/vertical) cells with no cell reused in a single path.

### Key Insight

Build a trie from the word list, storing the full word at terminal nodes. DFS each board cell, following trie edges. When a terminal node is reached, collect the word. Mark cells visited during DFS and unmark on backtrack. Use a `HashSet` to deduplicate.

### Solution

```java
import java.util.*;

class Solution {
    private static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        String word; // non-null at terminal nodes
    }

    private static final int[][] DIRS = {{-1,0},{1,0},{0,-1},{0,1}};

    public List<String> findWords(char[][] board, String[] words) {
        // Build trie
        var root = new TrieNode();
        for (String w : words) {
            var node = root;
            for (char ch : w.toCharArray()) {
                int idx = ch - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.word = w;
        }

        var result = new HashSet<String>();
        int rows = board.length, cols = board[0].length;

        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                dfs(board, r, c, root, result, rows, cols);

        return new ArrayList<>(result);
    }

    private void dfs(char[][] board, int r, int c, TrieNode node,
                     Set<String> result, int rows, int cols) {
        char ch = board[r][c];
        if (ch == '#') return; // visited marker
        int idx = ch - 'a';
        TrieNode next = node.children[idx];
        if (next == null) return;

        if (next.word != null) result.add(next.word);

        board[r][c] = '#'; // mark visited
        for (int[] d : DIRS) {
            int nr = r + d[0], nc = c + d[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols)
                dfs(board, nr, nc, next, result, rows, cols);
        }
        board[r][c] = ch; // restore
    }

    public static void main(String[] args) {
        var sol = new Solution();

        char[][] board = {
            {'o','a','a','n'},
            {'e','t','a','e'},
            {'i','h','k','r'},
            {'i','f','l','v'}
        };
        var got = sol.findWords(board, new String[]{"oath","pea","eat","rain"});
        Collections.sort(got);
        var expected = List.of("eat", "oath");
        if (!got.equals(expected))
            throw new AssertionError("findWords basic: expected " + expected + ", got " + got);

        // No match
        char[][] board2 = {{'a','b'},{'c','d'}};
        var got2 = sol.findWords(board2, new String[]{"xyz"});
        if (!got2.isEmpty())
            throw new AssertionError("findWords no match: expected [], got " + got2);

        // Single cell
        char[][] board3 = {{'a'}};
        var got3 = sol.findWords(board3, new String[]{"a"});
        if (!got3.equals(List.of("a")))
            throw new AssertionError("findWords single cell: expected [a], got " + got3);

        System.out.println("LC212 Word Search II: all tests passed");
    }
}
```

**Time:** O(M · 4 · 3^(L−1)) DFS where M = board cells, L = max word length. Trie build O(W·L).  
**Space:** O(W·L) trie + O(L) recursion stack.

**Java notes:** Marking visited cells with `'#'` (a character outside `'a'`–`'z'`) is compact; the sentinel check `if (ch == '#') return` stops revisiting. The `'#'` trick avoids a separate `boolean[][] visited` array. Storing `String word` at terminal trie nodes avoids reconstructing the word during DFS — the same pattern as the Rust version's `word: Option<String>`.

---

## Part 2 — Graphs

---

## 4. Number of Islands (LC #200)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` grid of `'1'` (land) and `'0'` (water), count the number of islands — connected regions of land.

### Key Insight

Flood-fill: when a `'1'` is found, increment the counter and DFS to sink all connected land to `'0'`. This avoids a separate visited array and runs in O(m·n).

### Solution

```java
class Solution {
    public int numIslands(char[][] grid) {
        int rows = grid.length, cols = grid[0].length;
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
        grid[r][c] = '0';
        dfs(grid, r + 1, c, rows, cols);
        dfs(grid, r - 1, c, rows, cols);
        dfs(grid, r, c + 1, rows, cols);
        dfs(grid, r, c - 1, rows, cols);
    }

    public static void main(String[] args) {
        var sol = new Solution();

        char[][] g1 = {
            {'1','1','0','0','0'},
            {'1','1','0','0','0'},
            {'0','0','1','0','0'},
            {'0','0','0','1','1'}
        };
        int got1 = sol.numIslands(g1);
        if (got1 != 3)
            throw new AssertionError("numIslands g1: expected 3, got " + got1);

        char[][] g2 = {
            {'1','1','1','1','0'},
            {'1','1','0','1','0'},
            {'1','1','0','0','0'},
            {'0','0','0','0','0'}
        };
        int got2 = sol.numIslands(g2);
        if (got2 != 1)
            throw new AssertionError("numIslands g2: expected 1, got " + got2);

        char[][] g3 = {{'0','0'},{'0','0'}};
        int got3 = sol.numIslands(g3);
        if (got3 != 0)
            throw new AssertionError("numIslands all water: expected 0, got " + got3);

        System.out.println("LC200 Number of Islands: all tests passed");
    }
}
```

**Time:** O(m·n). **Space:** O(m·n) recursion stack in worst case.

**Java notes:** Bounds checking at the top of `dfs` (`r < 0 || r >= rows || ...`) is cleaner than pre-checking before each recursive call. Java's stack can overflow on very large islands; an iterative BFS using `ArrayDeque<int[]>` is safer for production. The DFS version matches the LC constraint sizes (up to 300×300).

---

## 5. Clone Graph (LC #133)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given a reference to a node in a connected undirected graph, return a deep copy. Each node has `val` (1–100, unique) and a `List<Node> neighbors`.

### Key Insight

BFS from the start node. Use a `HashMap<Integer, Node>` keyed by `val` to track already-cloned nodes. For each original node, clone it on first visit, then wire its neighbors into the clone.

### Solution

```java
import java.util.*;

class Solution {
    // LeetCode's canonical Node definition
    static class Node {
        int val;
        List<Node> neighbors;
        Node(int val) { this.val = val; neighbors = new ArrayList<>(); }
    }

    public Node cloneGraph(Node node) {
        if (node == null) return null;
        var cloned = new HashMap<Integer, Node>();
        var queue = new ArrayDeque<Node>();

        cloned.put(node.val, new Node(node.val));
        queue.add(node);

        while (!queue.isEmpty()) {
            var orig = queue.poll();
            var clone = cloned.get(orig.val);
            for (var nbr : orig.neighbors) {
                if (!cloned.containsKey(nbr.val)) {
                    cloned.put(nbr.val, new Node(nbr.val));
                    queue.add(nbr);
                }
                clone.neighbors.add(cloned.get(nbr.val));
            }
        }
        return cloned.get(node.val);
    }

    public static void main(String[] args) {
        var sol = new Solution();

        // Build: 1 - 2 - 3 - 4 - 1 (cycle), plus 1-3
        Node n1 = new Node(1), n2 = new Node(2), n3 = new Node(3), n4 = new Node(4);
        n1.neighbors.addAll(List.of(n2, n4));
        n2.neighbors.addAll(List.of(n1, n3));
        n3.neighbors.addAll(List.of(n2, n4));
        n4.neighbors.addAll(List.of(n1, n3));

        Node clone = sol.cloneGraph(n1);
        if (clone == n1)
            throw new AssertionError("cloneGraph: clone must be a different object");
        if (clone.val != 1)
            throw new AssertionError("cloneGraph: clone.val expected 1, got " + clone.val);
        if (clone.neighbors.size() != 2)
            throw new AssertionError("cloneGraph: clone should have 2 neighbors, got " + clone.neighbors.size());

        // Single node, no neighbors
        Node single = new Node(1);
        Node singleClone = sol.cloneGraph(single);
        if (singleClone == single)
            throw new AssertionError("cloneGraph single: should be different object");
        if (!singleClone.neighbors.isEmpty())
            throw new AssertionError("cloneGraph single: should have no neighbors");

        System.out.println("LC133 Clone Graph: all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V) for the clone map and BFS queue.

**Java notes:** `ArrayDeque` is used instead of `LinkedList` as the BFS queue — it is faster (contiguous memory, no node allocation per element). Keying the clone map by `val` (unique per problem constraints) avoids identity-based map tricks. In Java this BFS is straightforward because `Node` is freely mutable — no `RefCell` or `Rc` needed.

---

## 6. Max Area of Island (LC #695)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

Given an integer grid of `0`s and `1`s, return the maximum area of any island (connected component of `1`s). Return `0` if no island exists.

### Key Insight

Same flood-fill as #200, but DFS returns the area of the component it sinks.

### Solution

```java
class Solution {
    public int maxAreaOfIsland(int[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        int max = 0;
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (grid[r][c] == 1)
                    max = Math.max(max, dfs(grid, r, c, rows, cols));
        return max;
    }

    private int dfs(int[][] grid, int r, int c, int rows, int cols) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] != 1) return 0;
        grid[r][c] = 0;
        return 1
            + dfs(grid, r + 1, c, rows, cols)
            + dfs(grid, r - 1, c, rows, cols)
            + dfs(grid, r, c + 1, rows, cols)
            + dfs(grid, r, c - 1, rows, cols);
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] grid = {
            {0,0,1,0,0,0,0,1,0,0,0,0,0},
            {0,0,0,0,0,0,0,1,1,1,0,0,0},
            {0,1,1,0,1,0,0,0,0,0,0,0,0},
            {0,1,0,0,1,1,0,0,1,0,1,0,0},
            {0,1,0,0,1,1,0,0,1,1,1,0,0},
            {0,0,0,0,0,0,0,0,0,0,1,0,0},
            {0,0,0,0,0,0,0,1,1,1,0,0,0},
            {0,0,0,0,0,0,0,1,1,0,0,0,0}
        };
        int got = sol.maxAreaOfIsland(grid);
        if (got != 6)
            throw new AssertionError("maxAreaOfIsland: expected 6, got " + got);

        int[][] allZero = {{0,0},{0,0}};
        int got2 = sol.maxAreaOfIsland(allZero);
        if (got2 != 0)
            throw new AssertionError("maxAreaOfIsland all zero: expected 0, got " + got2);

        System.out.println("LC695 Max Area of Island: all tests passed");
    }
}
```

**Time:** O(m·n). **Space:** O(m·n) recursion stack worst case.

**Java notes:** `Math.max(max, dfs(...))` is cleaner than an explicit `if`. The DFS return value propagates the area count up the call stack — each `return 1 + ...` aggregates all cells in the component.

---

## 7. Pacific Atlantic Water Flow (LC #417)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` matrix of non-negative heights, find all cells from which water can flow to both the Pacific Ocean (top and left edges) and the Atlantic Ocean (bottom and right edges). Water flows to adjacent cells with equal or lower height.

### Key Insight

Reverse BFS: start from the ocean borders and flow *uphill* (to cells with height ≥ current). Any cell reachable from both oceans is an answer.

### Solution

```java
import java.util.*;

class Solution {
    private static final int[][] DIRS = {{-1,0},{1,0},{0,-1},{0,1}};

    public List<List<Integer>> pacificAtlantic(int[][] heights) {
        int rows = heights.length, cols = heights[0].length;
        var pac = new boolean[rows][cols];
        var atl = new boolean[rows][cols];
        var pacQ = new ArrayDeque<int[]>();
        var atlQ = new ArrayDeque<int[]>();

        for (int r = 0; r < rows; r++) {
            pacQ.add(new int[]{r, 0});         pac[r][0] = true;
            atlQ.add(new int[]{r, cols - 1});  atl[r][cols - 1] = true;
        }
        for (int c = 0; c < cols; c++) {
            pacQ.add(new int[]{0, c});         pac[0][c] = true;
            atlQ.add(new int[]{rows - 1, c});  atl[rows - 1][c] = true;
        }

        bfs(heights, pacQ, pac, rows, cols);
        bfs(heights, atlQ, atl, rows, cols);

        var result = new ArrayList<List<Integer>>();
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (pac[r][c] && atl[r][c])
                    result.add(List.of(r, c));
        return result;
    }

    private void bfs(int[][] h, ArrayDeque<int[]> queue, boolean[][] visited,
                     int rows, int cols) {
        while (!queue.isEmpty()) {
            var cell = queue.poll();
            int r = cell[0], c = cell[1];
            for (int[] d : DIRS) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (!visited[nr][nc] && h[nr][nc] >= h[r][c]) {
                    visited[nr][nc] = true;
                    queue.add(new int[]{nr, nc});
                }
            }
        }
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] heights = {
            {1,2,2,3,5},
            {3,2,3,4,4},
            {2,4,5,3,1},
            {6,7,1,4,5},
            {5,1,1,2,4}
        };
        var got = sol.pacificAtlantic(heights);
        // Sort for stable comparison
        got.sort(Comparator.comparingInt((List<Integer> l) -> l.get(0))
                           .thenComparingInt(l -> l.get(1)));
        var expected = List.of(
            List.of(0,4), List.of(1,3), List.of(1,4),
            List.of(2,2), List.of(3,0), List.of(3,1), List.of(4,0)
        );
        if (!got.equals(expected))
            throw new AssertionError("pacificAtlantic: expected " + expected + ", got " + got);

        // Single cell
        var got2 = sol.pacificAtlantic(new int[][]{{1}});
        if (!got2.equals(List.of(List.of(0, 0))))
            throw new AssertionError("pacificAtlantic single cell: expected [[0,0]], got " + got2);

        System.out.println("LC417 Pacific Atlantic Water Flow: all tests passed");
    }
}
```

**Time:** O(m·n). **Space:** O(m·n) for the two visited grids and queues.

**Java notes:** `ArrayDeque<int[]>` avoids boxing integers — each `int[]` is a two-element array on the heap, but the deque itself does not autobox the primitive array reference. `List.of(r, c)` creates an immutable two-element list for the result, which is cleaner than `new ArrayList<>(Arrays.asList(r, c))`.

---

## 8. Surrounded Regions (LC #130)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given an `m × n` board of `'X'` and `'O'`, capture all `'O'` regions entirely surrounded by `'X'` — replacing them with `'X'`. Border-connected `'O'` cells are never captured.

### Key Insight

Mark all `'O'` cells reachable from any border as `'S'` (safe) via DFS. Then: remaining `'O'` → `'X'` (captured); `'S'` → `'O'` (restore safe cells).

### Solution

```java
class Solution {
    public void solve(char[][] board) {
        int rows = board.length, cols = board[0].length;

        // Mark border-connected 'O' as safe
        for (int r = 0; r < rows; r++) {
            if (board[r][0] == 'O')        dfs(board, r, 0, rows, cols);
            if (board[r][cols - 1] == 'O') dfs(board, r, cols - 1, rows, cols);
        }
        for (int c = 0; c < cols; c++) {
            if (board[0][c] == 'O')        dfs(board, 0, c, rows, cols);
            if (board[rows - 1][c] == 'O') dfs(board, rows - 1, c, rows, cols);
        }

        // Apply captures using switch expression
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
        dfs(board, r + 1, c, rows, cols);
        dfs(board, r - 1, c, rows, cols);
        dfs(board, r, c + 1, rows, cols);
        dfs(board, r, c - 1, rows, cols);
    }

    public static void main(String[] args) {
        var sol = new Solution();

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
        for (int r = 0; r < b1.length; r++)
            for (int c = 0; c < b1[0].length; c++)
                if (b1[r][c] != exp1[r][c])
                    throw new AssertionError("solve b1[" + r + "][" + c + "]: expected "
                        + exp1[r][c] + ", got " + b1[r][c]);

        // All border — nothing captured
        char[][] b2 = {{'O','O'},{'O','O'}};
        sol.solve(b2);
        for (int r = 0; r < 2; r++)
            for (int c = 0; c < 2; c++)
                if (b2[r][c] != 'O')
                    throw new AssertionError("solve b2: expected all O, got X at [" + r + "][" + c + "]");

        System.out.println("LC130 Surrounded Regions: all tests passed");
    }
}
```

**Time:** O(m·n). **Space:** O(m·n) recursion stack.

**Java notes:** The switch expression (Java 14+, standard in Java 17) is natural here for three-way character dispatch without fall-through: `switch (board[r][c]) { case 'O' -> 'X'; case 'S' -> 'O'; default -> board[r][c]; }`. The sentinel character `'S'` avoids allocating a separate visited grid.

---

## 9. Rotting Oranges (LC #994)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

A grid contains `0` (empty), `1` (fresh), `2` (rotten). Each minute, rotten oranges infect all adjacent fresh oranges. Return the minimum minutes until no fresh oranges remain, or `-1` if impossible.

### Key Insight

Multi-source BFS: seed the queue with all initially rotten oranges. Process one BFS level per minute. Track fresh count; decrement on each conversion. If fresh > 0 after BFS, return -1.

### Solution

```java
import java.util.*;

class Solution {
    public int orangesRotting(int[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        var queue = new ArrayDeque<int[]>();
        int fresh = 0;

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 2) queue.add(new int[]{r, c});
                else if (grid[r][c] == 1) fresh++;
            }
        }

        if (fresh == 0) return 0;

        int[][] dirs = {{-1,0},{1,0},{0,-1},{0,1}};
        int minutes = 0;

        while (!queue.isEmpty() && fresh > 0) {
            minutes++;
            int size = queue.size();
            for (int i = 0; i < size; i++) {
                var cell = queue.poll();
                int r = cell[0], c = cell[1];
                for (int[] d : dirs) {
                    int nr = r + d[0], nc = c + d[1];
                    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                    if (grid[nr][nc] == 1) {
                        grid[nr][nc] = 2;
                        fresh--;
                        queue.add(new int[]{nr, nc});
                    }
                }
            }
        }
        return fresh == 0 ? minutes : -1;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got1 = sol.orangesRotting(new int[][]{{2,1,1},{1,1,0},{0,1,1}});
        if (got1 != 4)
            throw new AssertionError("orangesRotting case1: expected 4, got " + got1);

        int got2 = sol.orangesRotting(new int[][]{{2,1,1},{0,1,1},{1,0,1}});
        if (got2 != -1)
            throw new AssertionError("orangesRotting impossible: expected -1, got " + got2);

        int got3 = sol.orangesRotting(new int[][]{{0,2}});
        if (got3 != 0)
            throw new AssertionError("orangesRotting no fresh: expected 0, got " + got3);

        System.out.println("LC994 Rotting Oranges: all tests passed");
    }
}
```

**Time:** O(m·n). **Space:** O(m·n) queue.

**Java notes:** `int size = queue.size()` captures the current BFS layer size before the inner loop starts. Elements added during the loop (next layer) are not counted, ensuring level-by-level processing. The `fresh == 0` early return skips unnecessary BFS when no fresh oranges exist from the start.

---

## 10. Walls and Gates (LC #286)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

Fill each empty room in an `m × n` grid with its shortest distance to the nearest gate. Grid sentinel values: `Integer.MAX_VALUE` (empty room), `-1` (wall), `0` (gate).

### Key Insight

Multi-source BFS from all gates simultaneously. Each BFS step propagates distance + 1 to adjacent empty rooms. Rooms unreachable from any gate retain `Integer.MAX_VALUE`.

### Solution

```java
import java.util.*;

class Solution {
    public void wallsAndGates(int[][] rooms) {
        int rows = rooms.length, cols = rooms[0].length;
        var queue = new ArrayDeque<int[]>();

        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (rooms[r][c] == 0) queue.add(new int[]{r, c});

        int[][] dirs = {{-1,0},{1,0},{0,-1},{0,1}};
        while (!queue.isEmpty()) {
            var cell = queue.poll();
            int r = cell[0], c = cell[1];
            for (int[] d : dirs) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (rooms[nr][nc] == Integer.MAX_VALUE) {
                    rooms[nr][nc] = rooms[r][c] + 1;
                    queue.add(new int[]{nr, nc});
                }
            }
        }
    }

    public static void main(String[] args) {
        var sol = new Solution();
        int INF = Integer.MAX_VALUE;

        int[][] rooms = {
            {INF, -1,   0, INF},
            {INF, INF, INF,  -1},
            {INF,  -1, INF,  -1},
            {  0,  -1, INF, INF}
        };
        sol.wallsAndGates(rooms);

        int[][] expected = {
            {3, -1, 0, 1},
            {2,  2, 1, -1},
            {1, -1, 2, -1},
            {0, -1, 3,  4}
        };
        for (int r = 0; r < rooms.length; r++)
            for (int c = 0; c < rooms[0].length; c++)
                if (rooms[r][c] != expected[r][c])
                    throw new AssertionError("wallsAndGates[" + r + "][" + c + "]: expected "
                        + expected[r][c] + ", got " + rooms[r][c]);

        // No gates: all rooms stay INF
        int[][] noGates = {{INF, INF},{INF, INF}};
        sol.wallsAndGates(noGates);
        for (int[] row : noGates)
            for (int v : row)
                if (v != INF)
                    throw new AssertionError("wallsAndGates no gates: room should remain INF, got " + v);

        System.out.println("LC286 Walls and Gates: all tests passed");
    }
}
```

**Time:** O(m·n). **Space:** O(m·n) queue.

**Java notes:** `Integer.MAX_VALUE` is LeetCode's official sentinel for this problem — do not define your own constant. `rooms[r][c] + 1` does not overflow here because the BFS only propagates to rooms with value `Integer.MAX_VALUE`; by the time a room is dequeued its value is `≤ m + n - 2`, well within `int` range.

---

## Part 3 — Topological Sort

---

## 11. Course Schedule (LC #207)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` courses and prerequisites `[a, b]` (take `b` before `a`), determine if all courses can be finished (no directed cycle exists).

### Key Insight

Kahn's algorithm (BFS topological sort): build in-degree array and adjacency list. Seed the queue with all zero-in-degree nodes. If the total processed count equals `n`, no cycle exists.

### Solution

```java
import java.util.*;

class Solution {
    public boolean canFinish(int numCourses, int[][] prerequisites) {
        var adj = new ArrayList<List<Integer>>(numCourses);
        for (int i = 0; i < numCourses; i++) adj.add(new ArrayList<>());
        var inDegree = new int[numCourses];

        for (int[] pre : prerequisites) {
            adj.get(pre[1]).add(pre[0]);
            inDegree[pre[0]]++;
        }

        var queue = new ArrayDeque<Integer>();
        for (int i = 0; i < numCourses; i++)
            if (inDegree[i] == 0) queue.add(i);

        int processed = 0;
        while (!queue.isEmpty()) {
            int course = queue.poll();
            processed++;
            for (int next : adj.get(course)) {
                if (--inDegree[next] == 0) queue.add(next);
            }
        }
        return processed == numCourses;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.canFinish(2, new int[][]{{1,0}}))
            throw new AssertionError("canFinish 2 courses: expected true");
        if (sol.canFinish(2, new int[][]{{1,0},{0,1}}))
            throw new AssertionError("canFinish cycle: expected false");
        if (!sol.canFinish(5, new int[][]{}))
            throw new AssertionError("canFinish no prereqs: expected true");
        if (!sol.canFinish(4, new int[][]{{1,0},{2,1},{3,2}}))
            throw new AssertionError("canFinish chain: expected true");

        System.out.println("LC207 Course Schedule: all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java notes:** `ArrayList<List<Integer>>` with pre-sized capacity avoids rehashing. `--inDegree[next] == 0` decrements in-place and checks in one expression. Using `ArrayDeque<Integer>` for the BFS queue auto-boxes `int` to `Integer` — acceptable here; for ultra-hot code, a library like Eclipse Collections provides primitive deques.

---

## 12. Course Schedule II (LC #210)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Same as #207 but return a valid course ordering. Return an empty array if a cycle exists.

### Key Insight

Same Kahn's BFS — append each dequeued node to the result list. If the result size equals `n`, return it; otherwise return an empty array.

### Solution

```java
import java.util.*;

class Solution {
    public int[] findOrder(int numCourses, int[][] prerequisites) {
        var adj = new ArrayList<List<Integer>>(numCourses);
        for (int i = 0; i < numCourses; i++) adj.add(new ArrayList<>());
        var inDegree = new int[numCourses];

        for (int[] pre : prerequisites) {
            adj.get(pre[1]).add(pre[0]);
            inDegree[pre[0]]++;
        }

        var queue = new ArrayDeque<Integer>();
        for (int i = 0; i < numCourses; i++)
            if (inDegree[i] == 0) queue.add(i);

        var order = new int[numCourses];
        int idx = 0;
        while (!queue.isEmpty()) {
            int course = queue.poll();
            order[idx++] = course;
            for (int next : adj.get(course))
                if (--inDegree[next] == 0) queue.add(next);
        }
        return idx == numCourses ? order : new int[0];
    }

    /** Returns true if the given order satisfies all prerequisites. */
    private static boolean isValidTopo(int[] order, int n, int[][] prereqs) {
        if (order.length != n) return false;
        var pos = new int[n];
        for (int i = 0; i < n; i++) pos[order[i]] = i;
        for (int[] p : prereqs)
            if (pos[p[1]] >= pos[p[0]]) return false;
        return true;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int[][] pre1 = {{1,0}};
        var ord1 = sol.findOrder(2, pre1);
        if (!isValidTopo(ord1, 2, pre1))
            throw new AssertionError("findOrder 2 courses: invalid order " + Arrays.toString(ord1));

        int[][] pre2 = {{1,0},{2,0},{3,1},{3,2}};
        var ord2 = sol.findOrder(4, pre2);
        if (!isValidTopo(ord2, 4, pre2))
            throw new AssertionError("findOrder 4 courses: invalid order " + Arrays.toString(ord2));

        var ord3 = sol.findOrder(2, new int[][]{{0,1},{1,0}});
        if (ord3.length != 0)
            throw new AssertionError("findOrder cycle: expected empty, got " + Arrays.toString(ord3));

        System.out.println("LC210 Course Schedule II: all tests passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

**Java notes:** Topological orderings are not unique; `isValidTopo` builds a position map and verifies each prerequisite `p[1]` appears before `p[0]` — robust regardless of which valid ordering the BFS produces. `Arrays.toString` is used in error messages for readable output.

---

## Part 4 — Union-Find Problems

---

## 13. Redundant Connection (LC #684)

**Difficulty:** Medium | **NeetCode150:** ✓

### Problem Statement

Given an undirected graph with `n` nodes and `n` edges (exactly one extra edge makes it not a tree), return the redundant edge — the last edge that creates a cycle.

### Key Insight

Process edges in order using Union-Find. The first edge where both endpoints are already connected creates the cycle — that is the redundant edge.

### Solution

```java
class Solution {
    static class UnionFind {
        private final int[] parent, rank;
        private int count;
        UnionFind(int n) {
            parent = new int[n]; rank = new int[n]; count = n;
            for (int i = 0; i < n; i++) parent[i] = i;
        }
        int find(int x) {
            while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
            return x;
        }
        boolean union(int x, int y) {
            int rx = find(x), ry = find(y);
            if (rx == ry) return false;
            if (rank[rx] < rank[ry])      parent[rx] = ry;
            else if (rank[rx] > rank[ry]) parent[ry] = rx;
            else { parent[ry] = rx; rank[rx]++; }
            count--;
            return true;
        }
    }

    public int[] findRedundantConnection(int[][] edges) {
        int n = edges.length;
        var uf = new UnionFind(n + 1);
        for (int[] e : edges)
            if (!uf.union(e[0], e[1])) return e;
        return new int[0];
    }

    public static void main(String[] args) {
        var sol = new Solution();

        var got1 = sol.findRedundantConnection(new int[][]{{1,2},{1,3},{2,3}});
        if (!Arrays.equals(got1, new int[]{2,3}))
            throw new AssertionError("redundant triangle: expected [2,3], got " + Arrays.toString(got1));

        var got2 = sol.findRedundantConnection(new int[][]{{1,2},{2,3},{3,4},{1,4},{1,5}});
        if (!Arrays.equals(got2, new int[]{1,4}))
            throw new AssertionError("redundant chain+1: expected [1,4], got " + Arrays.toString(got2));

        System.out.println("LC684 Redundant Connection: all tests passed");
    }
}
```

**Time:** O(n · α(n)) ≈ O(n). **Space:** O(n).

**Java notes:** Path halving (`parent[x] = parent[parent[x]]`) is used instead of full recursive path compression — it achieves the same amortized O(α(n)) complexity and is iterative, avoiding stack overflow. `Arrays.equals` compares `int[]` arrays by value (unlike `==` which compares references).

---

## 14. Number of Connected Components (LC #323)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` nodes (0 to n−1) and undirected edges, return the number of connected components.

### Key Insight

Union-Find starting with `n` components. Each successful `union` call decrements `count` by 1. The final `count` is the answer.

### Solution

```java
import java.util.Arrays;

class Solution {
    static class UnionFind {
        private final int[] parent, rank;
        private int count;
        UnionFind(int n) {
            parent = new int[n]; rank = new int[n]; count = n;
            for (int i = 0; i < n; i++) parent[i] = i;
        }
        int find(int x) {
            while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
            return x;
        }
        boolean union(int x, int y) {
            int rx = find(x), ry = find(y);
            if (rx == ry) return false;
            if (rank[rx] < rank[ry])      parent[rx] = ry;
            else if (rank[rx] > rank[ry]) parent[ry] = rx;
            else { parent[ry] = rx; rank[rx]++; }
            count--;
            return true;
        }
        int count() { return count; }
    }

    public int countComponents(int n, int[][] edges) {
        var uf = new UnionFind(n);
        for (int[] e : edges) uf.union(e[0], e[1]);
        return uf.count();
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got1 = sol.countComponents(5, new int[][]{{0,1},{1,2},{3,4}});
        if (got1 != 2)
            throw new AssertionError("countComponents: expected 2, got " + got1);

        int got2 = sol.countComponents(5, new int[][]{{0,1},{1,2},{2,3},{3,4}});
        if (got2 != 1)
            throw new AssertionError("countComponents fully connected: expected 1, got " + got2);

        int got3 = sol.countComponents(4, new int[][]{});
        if (got3 != 4)
            throw new AssertionError("countComponents no edges: expected 4, got " + got3);

        System.out.println("LC323 Number of Connected Components: all tests passed");
    }
}
```

**Time:** O(n · α(n)). **Space:** O(n).

**Java notes:** Tracking `count` inside `UnionFind` is cleaner than counting how many `union` calls return `true` externally. The `count()` accessor method exposes it read-only.

---

## 15. Graph Valid Tree (LC #261)

**Difficulty:** Medium | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `n` nodes and undirected edges, return `true` if the edges form a valid tree (connected and acyclic).

### Key Insight

A valid tree on `n` nodes requires exactly `n − 1` edges (necessary condition) and must be fully connected. Use Union-Find: any edge that would create a cycle means it is not a tree; if all `n − 1` edges merge distinct components, the result is one connected component.

### Solution

```java
class Solution {
    static class UnionFind {
        private final int[] parent, rank;
        private int count;
        UnionFind(int n) {
            parent = new int[n]; rank = new int[n]; count = n;
            for (int i = 0; i < n; i++) parent[i] = i;
        }
        int find(int x) {
            while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
            return x;
        }
        boolean union(int x, int y) {
            int rx = find(x), ry = find(y);
            if (rx == ry) return false;
            if (rank[rx] < rank[ry])      parent[rx] = ry;
            else if (rank[rx] > rank[ry]) parent[ry] = rx;
            else { parent[ry] = rx; rank[rx]++; }
            count--;
            return true;
        }
        int count() { return count; }
    }

    public boolean validTree(int n, int[][] edges) {
        if (edges.length != n - 1) return false;
        var uf = new UnionFind(n);
        for (int[] e : edges)
            if (!uf.union(e[0], e[1])) return false;
        return uf.count() == 1;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        if (!sol.validTree(5, new int[][]{{0,1},{0,2},{0,3},{1,4}}))
            throw new AssertionError("validTree valid: expected true");
        if (sol.validTree(5, new int[][]{{0,1},{1,2},{2,3},{1,3},{1,4}}))
            throw new AssertionError("validTree cycle: expected false");
        if (!sol.validTree(1, new int[][]{}))
            throw new AssertionError("validTree single node: expected true");
        if (sol.validTree(4, new int[][]{{0,1},{2,3}}))
            throw new AssertionError("validTree disconnected: expected false");

        System.out.println("LC261 Graph Valid Tree: all tests passed");
    }
}
```

**Time:** O(n · α(n)). **Space:** O(n).

**Java notes:** The early exit `edges.length != n - 1` works safely because `edges.length` and `n` are both `int` (no unsigned underflow issue unlike Rust's `usize`). For `n == 1`, `n - 1 == 0` and `edges.length == 0` is the correct check.

---

## 16. Word Ladder (LC #127)

**Difficulty:** Hard | **Blind75:** ✓ | **NeetCode150:** ✓

### Problem Statement

Given `beginWord`, `endWord`, and a `wordList`, return the length of the shortest transformation sequence from `beginWord` to `endWord` where each step changes exactly one letter and every intermediate word must exist in `wordList`. Return `0` if no sequence exists.

### Key Insight

BFS on the implicit word graph. Instead of O(n²) pairwise comparison, generate all one-letter variants of the current word (26 possibilities per position) and check membership in a `HashSet`. This is O(m · 26) per word, where m = word length.

### Solution

```java
import java.util.*;

class Solution {
    public int ladderLength(String beginWord, String endWord, List<String> wordList) {
        var wordSet = new HashSet<>(wordList);
        if (!wordSet.contains(endWord)) return 0;

        var queue = new ArrayDeque<String>();
        var visited = new HashSet<String>();
        queue.add(beginWord);
        visited.add(beginWord);
        int steps = 1;

        while (!queue.isEmpty()) {
            int size = queue.size();
            for (int i = 0; i < size; i++) {
                var word = queue.poll();
                if (word.equals(endWord)) return steps;
                var chars = word.toCharArray();
                for (int j = 0; j < chars.length; j++) {
                    char orig = chars[j];
                    for (char c = 'a'; c <= 'z'; c++) {
                        if (c == orig) continue;
                        chars[j] = c;
                        var next = new String(chars);
                        if (wordSet.contains(next) && !visited.contains(next)) {
                            visited.add(next);
                            queue.add(next);
                        }
                    }
                    chars[j] = orig; // restore
                }
            }
            steps++;
        }
        return 0;
    }

    public static void main(String[] args) {
        var sol = new Solution();

        int got1 = sol.ladderLength("hit", "cog",
            List.of("hot","dot","dog","lot","log","cog"));
        if (got1 != 5)
            throw new AssertionError("ladderLength classic: expected 5, got " + got1);

        int got2 = sol.ladderLength("hit", "cog",
            List.of("hot","dot","dog","lot","log"));
        if (got2 != 0)
            throw new AssertionError("ladderLength no path: expected 0, got " + got2);

        int got3 = sol.ladderLength("a", "b", List.of("b"));
        if (got3 != 2)
            throw new AssertionError("ladderLength one step: expected 2, got " + got3);

        System.out.println("LC127 Word Ladder: all tests passed");
    }
}
```

**Time:** O(m · 26 · n) where m = word length, n = word list size.  
**Space:** O(n · m) for the visited set and queue.

**Java notes:** Mutating `chars[j]` in place and restoring it is more efficient than `String.substring` concatenation at each position — it avoids `O(m)` allocations per character position. The `new String(chars)` call creates one string per candidate, which is unavoidable. BFS guarantees the first time `endWord` is dequeued it was reached by the shortest path.

---

## 📝 Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| Trie `children` array size | Verify | All trie nodes use `new TrieNode[26]` — confirmed in LC208, LC211, LC212 |
| UnionFind path compression | Verify | Iterative path halving used in `find`; union by rank in `union` — confirmed in LC684, LC323, LC261 |
| `visited` state isolation | Verify | All BFS/DFS allocate visited state locally per call; no static or shared mutable visited set |
| `assert` keyword | Verify | No `assert` keyword present; all checks use `if (!cond) throw new AssertionError(...)` |
| `LinkedList` as Queue | Verify | All BFS queues use `ArrayDeque`, never `LinkedList` |
| `Integer.MAX_VALUE` sentinel (LC286) | Low | Used directly per LC definition; no custom constant introduced |
| In-place grid mutation | Low | Problems 200, 695, 130 mutate the input grid (matching LC's accepted approach for grids passed by reference) — documented per problem |
| Switch expression (LC130) | Note | Used naturally for three-way char dispatch; requires Java 14+ standard switch expression, available in Java 17 |

### Third-Person Critical Review

**Trie children array:** Every `TrieNode` declaration in this chapter uses `TrieNode[] children = new TrieNode[26]`, which is exactly 26 slots indexed by `ch - 'a'`. No occurrence of size 256, `HashMap`, or `Map<Character, TrieNode>` appears.

**Union-Find path compression:** The `UnionFind.find` method in all three Union-Find problems (LC684, LC323, LC261) uses iterative path halving: `parent[x] = parent[parent[x]]` followed by `x = parent[x]`. This achieves the same amortized O(α(n)) complexity as full path compression and avoids recursion depth issues. The `union` method compares ranks and adjusts ranks only on ties — both conditions for union by rank are present.

**Visited state:** In LC200 (Number of Islands), LC695 (Max Area of Island), and LC130 (Surrounded Regions), cells are marked visited by mutating the grid in-place — `'1'` → `'0'` or `'O'` → `'S'`. In LC417 (Pacific Atlantic), two fresh `boolean[][]` arrays are allocated per call. In LC994 (Rotting Oranges), `grid[nr][nc] = 2` marks cells in the grid. In LC127 (Word Ladder), `visited` is a local `HashSet<String>` created per call. None of these use static fields or instance-level state that would carry over between LeetCode submissions.

**No `assert` keyword:** A search for the `assert` keyword across all solution code blocks in this chapter finds zero occurrences. All correctness checks use `if (!condition) throw new AssertionError("descriptive message: got " + actual)`.

### What This Chapter Does Well

- **Consistency in data structures:** `TrieNode[26]` is used throughout, `ArrayDeque` for all BFS queues, and a reusable `UnionFind` pattern with the same API across three problems.
- **Java 17+ idioms used where natural:** `var` for local type inference, switch expressions in LC130, `List.of(...)` for immutable list construction, and records were considered (the `int[]` two-element array is simpler for grid coordinates in this chapter).
- **Robust test validation:** LC210 uses `isValidTopo` rather than checking one hardcoded expected order — important because topological orderings are not unique. LC133 validates that the clone is a different object via `==` reference check.
- **Clear asymmetry between Trie and Union-Find problems:** The three Union-Find problems share nearly identical `UnionFind` inner classes, making the pattern explicit and easy to memorize.

### What Could Be Improved

- **Word Ladder alternative:** The pattern-bucket approach (Rust version) is asymptotically equivalent but avoids iterating 26 characters per position. For very long words it would be faster; the 26-character scan is simpler and sufficient for LC constraints.
- **Stack overflow risk in DFS-heavy problems:** LC200, LC695, and LC130 use recursive DFS which can overflow the JVM stack on grids approaching 300×300 with pathological island shapes. An iterative BFS or explicit stack would be production-safer but adds boilerplate. The recursive form is standard in LC submissions.
- **UnionFind duplication:** The `UnionFind` class is redeclared as a static inner class in each of the three problems (LC684, LC323, LC261) for self-contained snippets. In a real project, it would live in one shared class.
- **`int[]` vs record for BFS coordinates:** The chapter consistently uses `int[]` two-element arrays for `(row, col)` pairs. A `record Cell(int r, int c) {}` would be more readable but adds 1–2 lines per problem. Either is idiomatic Java 17; `int[]` was chosen for compactness.
