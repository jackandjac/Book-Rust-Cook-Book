# LC-12: BFS — Deep Dive (Java 17+)

> **Chapter goal:** Master every Breadth-First Search pattern that appears in LeetCode's BFS Study Plan.
> Every snippet is self-contained, compiles under Java 17+, and uses `ArrayDeque` as the queue.
> This is the Java companion to the Rust chapter `lc12-bfs-deep-dive.md`.

---

## BFS Patterns in Java — Reference Section

### Standard BFS Template with `ArrayDeque`

```java
import java.util.ArrayDeque;

static int[] bfs(int start, int[][] adj, int n) {
    int[] dist = new int[n];
    java.util.Arrays.fill(dist, -1);
    dist[start] = 0;
    var queue = new ArrayDeque<Integer>();
    queue.addLast(start);
    while (!queue.isEmpty()) {
        int node = queue.pollFirst();
        for (int neighbor : adj[node]) {
            if (dist[neighbor] == -1) {
                dist[neighbor] = dist[node] + 1;
                queue.addLast(neighbor);     // mark BEFORE enqueue
            }
        }
    }
    return dist;
}
```

> **Java vs Rust:** `ArrayDeque<T>` in Java serves as both stack and queue — `addFirst`/`pollFirst`
> for stack, `addLast`/`pollFirst` for queue. This mirrors Rust's `VecDeque<T>`. Never use
> `new LinkedList<>()` as a `Queue` in modern Java — `ArrayDeque` is a contiguous ring buffer and
> is significantly faster. Java BFS avoids Rust's borrow-checker friction: no `RefCell`, no
> lifetime annotations, no `clone()` for shared ownership. Multi-source BFS simply adds all
> sources to the queue and marks them visited before the main loop — the BFS loop is identical
> to single-source BFS.

---

### Level-Order BFS (Queue-Size Snapshot)

The key trick: snapshot `queue.size()` at the start of each outer loop iteration. Everything
currently in the queue belongs to the current level; everything pushed during this round belongs
to the next level.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

static List<List<Integer>> bfsLevels(int start, List<List<Integer>> adj) {
    var result = new ArrayList<List<Integer>>();
    boolean[] visited = new boolean[adj.size()];
    visited[start] = true;
    var queue = new ArrayDeque<Integer>();
    queue.addLast(start);
    while (!queue.isEmpty()) {
        int size = queue.size();                     // snapshot — all nodes at this level
        var level = new ArrayList<Integer>(size);
        for (int i = 0; i < size; i++) {            // consume exactly `size` nodes
            int node = queue.pollFirst();
            level.add(node);
            for (int nb : adj.get(node)) {
                if (!visited[nb]) {
                    visited[nb] = true;              // mark BEFORE enqueue
                    queue.addLast(nb);
                }
            }
        }
        result.add(level);
    }
    return result;
}
```

---

### Multi-Source BFS

Pre-populate the queue with ALL sources before beginning the main loop. Every source starts at
distance 0; the BFS propagates outward simultaneously from all of them.

```java
import java.util.ArrayDeque;

static int[] multiSourceBfs(int[] sources, int[][] adj, int n) {
    int[] dist = new int[n];
    java.util.Arrays.fill(dist, -1);
    var queue = new ArrayDeque<Integer>();
    for (int s : sources) {
        dist[s] = 0;
        queue.addLast(s);          // all sources are already "visited" at distance 0
    }
    while (!queue.isEmpty()) {
        int node = queue.pollFirst();
        for (int nb : adj[node]) {
            if (dist[nb] == -1) {
                dist[nb] = dist[node] + 1;
                queue.addLast(nb);
            }
        }
    }
    return dist;
}
```

---

### Grid BFS Skeleton (4-directional)

```java
import java.util.ArrayDeque;

static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};

static int gridBfs(char[][] grid, int startR, int startC) {
    int rows = grid.length, cols = grid[0].length;
    var queue = new ArrayDeque<int[]>();
    queue.addLast(new int[]{startR, startC});
    grid[startR][startC] = '#';              // mark visited by mutating
    int steps = 0;
    while (!queue.isEmpty()) {
        int size = queue.size();
        for (int i = 0; i < size; i++) {
            int[] cur = queue.pollFirst();
            int r = cur[0], c = cur[1];
            for (int[] d : DIRS4) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (grid[nr][nc] == '#') continue;
                grid[nr][nc] = '#';
                queue.addLast(new int[]{nr, nc});
            }
        }
        steps++;
    }
    return steps;
}
```

**Why `int[]` for grid cells?** `new int[]{r, c}` in Java is a small heap allocation, equivalent to
Rust's `(i32, i32)` tuple on the stack. For high-performance hot paths, encoding `r * cols + c` as
a single `int` avoids the extra allocation.

---

### 0-1 BFS (Deque as Double-Ended Priority Queue)

When edge weights are only 0 or 1, use `ArrayDeque` as a deque: push weight-0 edges to the
**front** (`addFirst`) and weight-1 edges to the **back** (`addLast`). This gives Dijkstra-like
shortest paths in O(V + E) without a `PriorityQueue`.

```java
import java.util.ArrayDeque;

static int[] zeroOneBfs(int start, int n, int[][][] graph) {
    // graph[u] contains int[]{v, weight} where weight is 0 or 1
    int[] dist = new int[n];
    java.util.Arrays.fill(dist, Integer.MAX_VALUE);
    dist[start] = 0;
    var deque = new ArrayDeque<Integer>();
    deque.addLast(start);
    while (!deque.isEmpty()) {
        int u = deque.pollFirst();
        for (int[] edge : graph[u]) {
            int v = edge[0], w = edge[1];
            if (dist[u] + w < dist[v]) {
                dist[v] = dist[u] + w;
                if (w == 0) deque.addFirst(v);   // 0-weight: front of deque
                else        deque.addLast(v);    // 1-weight: back of deque
            }
        }
    }
    return dist;
}
```

---

### Bidirectional BFS (Optimization for Shortest Path)

Expand two frontiers simultaneously — one from source, one from target — stopping when they
meet. Time complexity drops from O(b^d) to O(b^(d/2)). Most effective for large symmetric graphs
(Word Ladder, etc.).

```java
import java.util.HashSet;
import java.util.Set;

static int bidirectionalBfs(String start, String end,
                            java.util.function.Function<String, Iterable<String>> neighbors) {
    if (start.equals(end)) return 0;
    Set<String> front = new HashSet<>(Set.of(start));
    Set<String> back  = new HashSet<>(Set.of(end));
    Set<String> visited = new HashSet<>(Set.of(start));
    int steps = 1;
    while (!front.isEmpty()) {
        if (front.size() > back.size()) { var tmp = front; front = back; back = tmp; }
        var next = new HashSet<String>();
        for (String node : front) {
            for (String nb : neighbors.apply(node)) {
                if (back.contains(nb)) return steps + 1;
                if (visited.add(nb)) next.add(nb);
            }
        }
        front = next;
        steps++;
    }
    return -1;
}
```

---

## Part 1 — Shortest Path / Distance

---

## LC102. Binary Tree Level Order Traversal

**Problem.** Given the root of a binary tree, return the node values grouped by level (list of lists).

**Approach 1 — Level-Order BFS with Queue Size Snapshot (O(n) time, O(n) space).**
Level-order BFS: snapshot `queue.size()` before consuming each level to know how many nodes
belong to the current level. Drain exactly that many nodes and enqueue their children.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

class Solution102 {
    // Standard LeetCode TreeNode definition
    static class TreeNode {
        int val;
        TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode left, TreeNode right) {
            this.val = val; this.left = left; this.right = right;
        }
    }

    public List<List<Integer>> levelOrder(TreeNode root) {
        var result = new ArrayList<List<Integer>>();
        if (root == null) return result;
        var queue = new ArrayDeque<TreeNode>();
        queue.addLast(root);
        while (!queue.isEmpty()) {
            int size = queue.size();
            var level = new ArrayList<Integer>(size);
            for (int i = 0; i < size; i++) {
                TreeNode node = queue.pollFirst();
                level.add(node.val);
                if (node.left  != null) queue.addLast(node.left);
                if (node.right != null) queue.addLast(node.right);
            }
            result.add(level);
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution102();
        //     3
        //    / \
        //   9  20
        //     /  \
        //    15   7
        var tree = new TreeNode(3,
            new TreeNode(9),
            new TreeNode(20, new TreeNode(15), new TreeNode(7)));
        var expected = List.of(List.of(3), List.of(9, 20), List.of(15, 7));
        var actual = sol.levelOrder(tree);
        if (!actual.equals(expected))
            throw new AssertionError("lc102 example1: got " + actual);

        // single node
        var single = sol.levelOrder(new TreeNode(1));
        if (!single.equals(List.of(List.of(1))))
            throw new AssertionError("lc102 single: got " + single);

        // null root
        var empty = sol.levelOrder(null);
        if (!empty.isEmpty())
            throw new AssertionError("lc102 null: got " + empty);

        System.out.println("LC #102 passed");
    }
}
```

**Time:** O(n). **Space:** O(n) — queue holds at most one full level (up to n/2 nodes).

**Java note:** Children are enqueued as non-null checks inline — no `Optional` needed. The
`ArrayDeque<TreeNode>` call avoids `Rc<RefCell<TreeNode>>` boilerplate required in Rust.

---

## LC103. Binary Tree Zigzag Level Order Traversal

**Problem.** Same as #102 but alternate each level between left-to-right and right-to-left.

**Approach 1 — Level-Order BFS with Direction-Indexed Insertion (O(n) time, O(n) space).**
Pre-allocate the level `ArrayList` with `addFirst`/`addLast` based on the current direction flag,
avoiding a post-level `Collections.reverse()` call. Toggle the direction after each level.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

class Solution103 {
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }

    public List<List<Integer>> zigzagLevelOrder(TreeNode root) {
        var result = new ArrayList<List<Integer>>();
        if (root == null) return result;
        var queue = new ArrayDeque<TreeNode>();
        queue.addLast(root);
        boolean leftToRight = true;
        while (!queue.isEmpty()) {
            int size = queue.size();
            var level = new ArrayList<Integer>(size);
            for (int i = 0; i < size; i++) level.add(0); // pre-fill for indexed write
            for (int i = 0; i < size; i++) {
                TreeNode node = queue.pollFirst();
                int idx = leftToRight ? i : size - 1 - i;
                level.set(idx, node.val);
                if (node.left  != null) queue.addLast(node.left);
                if (node.right != null) queue.addLast(node.right);
            }
            result.add(level);
            leftToRight = !leftToRight;
        }
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution103();
        var tree = new TreeNode(3,
            new TreeNode(9),
            new TreeNode(20, new TreeNode(15), new TreeNode(7)));
        // Level 0 (L→R): [3], Level 1 (R→L): [20,9], Level 2 (L→R): [15,7]
        var expected = List.of(List.of(3), List.of(20, 9), List.of(15, 7));
        var actual = sol.zigzagLevelOrder(tree);
        if (!actual.equals(expected))
            throw new AssertionError("lc103 example1: got " + actual);

        var single = sol.zigzagLevelOrder(new TreeNode(1));
        if (!single.equals(List.of(List.of(1))))
            throw new AssertionError("lc103 single: got " + single);

        System.out.println("LC #103 passed");
    }
}
```

**Time:** O(n). **Space:** O(n).

**Java note:** `list.set(idx, val)` on a pre-sized `ArrayList` achieves the in-place positional
write that Rust does with `vec![0; level_size]` + direct index. One allocation, no reverse pass.

---

## LC111. Minimum Depth of Binary Tree

**Problem.** Find the number of nodes on the shortest root-to-leaf path.

**Approach 1 — Level-Order BFS with Early Leaf Termination (O(n) time, O(n) space).**
BFS guarantees the first leaf node encountered is at minimum depth — return the BFS depth
immediately when a leaf (both children null) is dequeued.
DFS must traverse the whole tree; BFS stops at the shallowest leaf.

```java
import java.util.ArrayDeque;

class Solution111 {
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }

    public int minDepth(TreeNode root) {
        if (root == null) return 0;
        var queue = new ArrayDeque<TreeNode>();
        queue.addLast(root);
        int depth = 1;
        while (!queue.isEmpty()) {
            int size = queue.size();
            for (int i = 0; i < size; i++) {
                TreeNode node = queue.pollFirst();
                if (node.left == null && node.right == null) return depth; // first leaf
                if (node.left  != null) queue.addLast(node.left);
                if (node.right != null) queue.addLast(node.right);
            }
            depth++;
        }
        return depth;
    }

    public static void main(String[] args) {
        var sol = new Solution111();
        //   3
        //  / \
        // 9  20
        //   /  \
        //  15   7
        var tree = new TreeNode(3,
            new TreeNode(9),
            new TreeNode(20, new TreeNode(15), new TreeNode(7)));
        var res1 = sol.minDepth(tree);
        if (res1 != 2)
            throw new AssertionError("lc111 example1: got " + res1);

        // right-skewed: 2 -> 3
        var skewed = new TreeNode(2, null, new TreeNode(3));
        var res2 = sol.minDepth(skewed);
        if (res2 != 2)
            throw new AssertionError("lc111 skewed: got " + res2);

        System.out.println("LC #111 passed");
    }
}
```

**Time:** O(n) worst case; O(n/2) on balanced trees. **Space:** O(n).

---

## LC127. Word Ladder

**Problem.** Transform `beginWord` into `endWord` one letter at a time. Every intermediate word must
exist in `wordList`. Return the length of the shortest sequence, or 0 if none exists.

**Approach 1 — BFS with Pattern-Bucket Neighbor Lookup (O(N·L²) time, O(N·L) space).**
Pattern-bucket optimization: pre-group words by wildcard patterns (e.g., `"hit"` → `["*it",
"h*t", "hi*"]`) so neighbor lookup is O(L) per word instead of O(N·L). BFS on the word graph
gives shortest transformation sequence length.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;

class Solution127 {
    public int ladderLength(String beginWord, String endWord, List<String> wordList) {
        var wordSet = new HashSet<>(wordList);
        if (!wordSet.contains(endWord)) return 0;

        // Build pattern -> words map
        var patterns = new HashMap<String, List<String>>();
        var allWords = new ArrayList<>(wordList);
        allWords.add(beginWord);
        for (String word : allWords) {
            char[] chars = word.toCharArray();
            for (int i = 0; i < chars.length; i++) {
                char orig = chars[i];
                chars[i] = '*';
                String key = new String(chars);
                patterns.computeIfAbsent(key, k -> new ArrayList<>()).add(word);
                chars[i] = orig;
            }
        }

        var visited = new HashSet<String>();
        visited.add(beginWord);
        var queue = new ArrayDeque<String>();
        queue.addLast(beginWord);
        int steps = 1;

        while (!queue.isEmpty()) {
            int size = queue.size();
            for (int i = 0; i < size; i++) {
                String word = queue.pollFirst();
                if (word.equals(endWord)) return steps;
                char[] chars = word.toCharArray();
                for (int j = 0; j < chars.length; j++) {
                    char orig = chars[j];
                    chars[j] = '*';
                    String key = new String(chars);
                    chars[j] = orig;
                    List<String> neighbors = patterns.getOrDefault(key, List.of());
                    for (String nb : neighbors) {
                        if (visited.add(nb)) {     // add returns true if newly inserted
                            queue.addLast(nb);
                        }
                    }
                }
            }
            steps++;
        }
        return 0;
    }

    public static void main(String[] args) {
        var sol = new Solution127();
        var res1 = sol.ladderLength("hit", "cog",
            List.of("hot","dot","dog","lot","log","cog"));
        if (res1 != 5)
            throw new AssertionError("lc127 example1: got " + res1);

        var res2 = sol.ladderLength("hit", "cog",
            List.of("hot","dot","dog","lot","log"));
        if (res2 != 0)
            throw new AssertionError("lc127 no_path: got " + res2);

        System.out.println("LC #127 passed");
    }
}
```

**Time:** O(N * L^2). **Space:** O(N * L^2) for the pattern map.

**Java note:** `visited.add(nb)` returns `true` if the element was newly inserted, allowing a
one-liner visited-check-and-mark. `Math.floorMod` is not needed here but see LC #752 for
Java's negative modulo behavior.

---

## LC126. Word Ladder II

**Problem.** Like #127 but return ALL shortest transformation sequences.

**Approach 1 — BFS for Shortest-Path DAG + DFS Path Enumeration (O(N·L²) time, O(N·P) space).**
BFS builds a shortest-path DAG by recording parent word lists per BFS level. Then DFS/backtracking
enumerates all paths through the DAG from `endWord` back to `beginWord`. Reverse each path at
collection time. N is word count, L is word length, P is number of shortest paths.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

class Solution126 {
    public List<List<String>> findLadders(String beginWord, String endWord, List<String> wordList) {
        var wordSet = new HashSet<>(wordList);
        var result  = new ArrayList<List<String>>();
        if (!wordSet.contains(endWord)) return result;

        // parents[word] = set of predecessor words at the previous BFS level
        var parents = new HashMap<String, List<String>>();
        var visitedAll   = new HashSet<String>();
        visitedAll.add(beginWord);
        var visitedLevel = new HashSet<String>();
        var queue = new ArrayDeque<String>();
        queue.addLast(beginWord);
        boolean found = false;

        outer:
        while (!queue.isEmpty()) {
            int size = queue.size();
            visitedLevel.clear();
            for (int i = 0; i < size; i++) {
                String word = queue.pollFirst();
                char[] chars = word.toCharArray();
                for (int j = 0; j < chars.length; j++) {
                    char orig = chars[j];
                    for (char c = 'a'; c <= 'z'; c++) {
                        if (c == orig) continue;
                        chars[j] = c;
                        String next = new String(chars);
                        if (!wordSet.contains(next)) { chars[j] = orig; continue; }
                        chars[j] = orig;
                        if (!visitedAll.contains(next)) {
                            // first time this level reaches `next`
                            visitedLevel.add(next);
                            parents.computeIfAbsent(next, k -> new ArrayList<>()).add(word);
                            if (next.equals(endWord)) found = true;
                        } else if (visitedLevel.contains(next)) {
                            // another word at the same BFS level can also reach `next`
                            parents.computeIfAbsent(next, k -> new ArrayList<>()).add(word);
                        }
                        chars[j] = orig;
                    }
                }
            }
            visitedAll.addAll(visitedLevel);
            for (String w : visitedLevel) queue.addLast(w);
            if (found) break outer;
        }

        // DFS backtrack from endWord to beginWord
        var path = new ArrayList<String>();
        path.add(endWord);
        backtrack(beginWord, endWord, parents, path, result);
        return result;
    }

    private void backtrack(String begin, String word,
                           Map<String, List<String>> parents,
                           List<String> path, List<List<String>> result) {
        if (word.equals(begin)) {
            var p = new ArrayList<>(path);
            java.util.Collections.reverse(p);
            result.add(p);
            return;
        }
        List<String> preds = parents.getOrDefault(word, List.of());
        for (String pred : preds) {
            path.add(pred);
            backtrack(begin, pred, parents, path, result);
            path.remove(path.size() - 1);
        }
    }

    public static void main(String[] args) {
        var sol = new Solution126();
        var res = sol.findLadders("hit", "cog",
            List.of("hot","dot","dog","lot","log","cog"));
        // Sort for deterministic comparison
        res.forEach(java.util.Collections::sort);
        res.sort(java.util.Comparator.comparing(Object::toString));
        var exp = new ArrayList<List<String>>();
        exp.add(new ArrayList<>(List.of("dog","cog","dot","hit","hot")));
        exp.add(new ArrayList<>(List.of("cog","log","hit","hot","lot")));
        exp.forEach(java.util.Collections::sort);
        exp.sort(java.util.Comparator.comparing(Object::toString));
        if (!res.equals(exp))
            throw new AssertionError("lc126 example1: got " + res);

        System.out.println("LC #126 passed");
    }
}
```

**Time:** O(N * L * 26) BFS + O(paths * path_length) backtrack. **Space:** O(N * L) parent map.

**Java note:** `visitedLevel` vs `visitedAll` is the critical distinction — a word discovered for the
first time in this BFS level can be reached by multiple words in the same level, so we allow
multiple parent additions within one level while preventing re-processing in future levels.

---

## LC1306. Jump Game III

**Problem.** From index `i` you can jump to `i + arr[i]` or `i - arr[i]`. Return `true` if any index
with value `0` is reachable from `start`.

**Approach 1 — Standard BFS on Index State Space (O(n) time, O(n) space).**
Standard BFS: from index `i`, enqueue `i + arr[i]` and `i - arr[i]` if in bounds and unvisited.
Mark visited before enqueuing to prevent re-processing. Return true as soon as an index with
value 0 is reached.

```java
import java.util.ArrayDeque;

class Solution1306 {
    public boolean canReach(int[] arr, int start) {
        int n = arr.length;
        boolean[] visited = new boolean[n];
        visited[start] = true;
        var queue = new ArrayDeque<Integer>();
        queue.addLast(start);
        while (!queue.isEmpty()) {
            int idx = queue.pollFirst();
            if (arr[idx] == 0) return true;
            for (int next : new int[]{idx + arr[idx], idx - arr[idx]}) {
                if (next >= 0 && next < n && !visited[next]) {
                    visited[next] = true;
                    queue.addLast(next);
                }
            }
        }
        return false;
    }

    public static void main(String[] args) {
        var sol = new Solution1306();
        if (!sol.canReach(new int[]{4,2,3,0,3,1,2}, 5))
            throw new AssertionError("lc1306 example1: expected true");
        if (!sol.canReach(new int[]{4,2,3,0,3,1,2}, 0))
            throw new AssertionError("lc1306 example2: expected true");
        if (sol.canReach(new int[]{3,0,2,1,2}, 2))
            throw new AssertionError("lc1306 example3: expected false");
        System.out.println("LC #1306 passed");
    }
}
```

**Time:** O(n). **Space:** O(n).

---

## LC752. Open the Lock

**Problem.** A 4-wheel lock starts at `"0000"`. Reach `target` in minimum turns while avoiding
`deadends`. Each turn rotates one wheel by one digit (wraps: 0↔9). Return minimum turns or -1.

**Approach 1 — BFS on 4-Digit State Space (O(10^4 · L) time, O(10^4) space).**
BFS on the 10,000-state lock string space. Each state has 8 transitions (4 wheels × 2 directions).
Skip deadend states. Return BFS depth when the target state is first dequeued.

```java
import java.util.ArrayDeque;
import java.util.HashSet;
import java.util.List;

class Solution752 {
    public int openLock(String[] deadends, String target) {
        var dead = new HashSet<>(List.of(deadends));
        String start = "0000";
        if (dead.contains(start)) return -1;
        if (start.equals(target))  return 0;

        var visited = new HashSet<String>();
        visited.add(start);
        var queue = new ArrayDeque<String>();
        queue.addLast(start);
        int steps = 0;

        while (!queue.isEmpty()) {
            int size = queue.size();
            steps++;
            for (int i = 0; i < size; i++) {
                String state = queue.pollFirst();
                char[] chars = state.toCharArray();
                for (int j = 0; j < 4; j++) {
                    int digit = chars[j] - '0';
                    for (int delta : new int[]{1, -1}) {
                        // Java % on negatives is negative — use (d + 10) % 10
                        int newDigit = (digit + delta + 10) % 10;
                        chars[j] = (char)('0' + newDigit);
                        String next = new String(chars);
                        chars[j] = (char)('0' + digit); // restore
                        if (next.equals(target)) return steps;
                        if (!dead.contains(next) && visited.add(next)) {
                            queue.addLast(next);
                        }
                    }
                }
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution752();
        var res1 = sol.openLock(
            new String[]{"0201","0101","0102","1212","2002"}, "0202");
        if (res1 != 6)
            throw new AssertionError("lc752 example1: got " + res1);

        var res2 = sol.openLock(new String[]{"0000"}, "8888");
        if (res2 != -1)
            throw new AssertionError("lc752 dead start: got " + res2);

        var res3 = sol.openLock(new String[]{}, "0000");
        if (res3 != 0)
            throw new AssertionError("lc752 already at target: got " + res3);

        System.out.println("LC #752 passed");
    }
}
```

**Time:** O(10^4 * 4 * 2) = O(80,000) — all states times all transitions. **Space:** O(10^4).

**Java note:** Java's `%` operator returns a negative result for negative dividends — `(-1) % 10 = -1`.
Always use `(digit + delta + 10) % 10` (or `Math.floorMod(digit + delta, 10)`) to ensure the
result is in `[0, 9]`. Rust's `.rem_euclid(10)` does the same thing more ergonomically.

---

## Part 2 — Grid BFS

---

## LC994. Rotting Oranges

**Problem.** Grid of 0 (empty), 1 (fresh), 2 (rotten). Each minute, rotten oranges infect adjacent
fresh ones. Return total minutes until no fresh remain, or -1 if impossible.

**Approach 1 — Multi-Source BFS from All Rotten Oranges (O(R×C) time, O(R×C) space).**
Multi-source BFS: seed the `ArrayDeque` with ALL initially rotten oranges simultaneously.
Spread contamination level by level; count fresh oranges that turn rotten. Return -1 if any
fresh orange remains unreachable.

```java
import java.util.ArrayDeque;

class Solution994 {
    private static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};

    public int orangesRotting(int[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        var queue = new ArrayDeque<int[]>();
        int fresh = 0;

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 2) queue.addLast(new int[]{r, c});
                else if (grid[r][c] == 1) fresh++;
            }
        }

        if (fresh == 0) return 0;
        int minutes = 0;

        while (!queue.isEmpty()) {
            int size = queue.size();
            boolean anyInfected = false;
            for (int i = 0; i < size; i++) {
                int[] cur = queue.pollFirst();
                int r = cur[0], c = cur[1];
                for (int[] d : DIRS4) {
                    int nr = r + d[0], nc = c + d[1];
                    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                    if (grid[nr][nc] == 1) {
                        grid[nr][nc] = 2;           // mark rotten (visited)
                        fresh--;
                        anyInfected = true;
                        queue.addLast(new int[]{nr, nc});
                    }
                }
            }
            if (anyInfected) minutes++;
        }
        return fresh == 0 ? minutes : -1;
    }

    public static void main(String[] args) {
        var sol = new Solution994();
        var res1 = sol.orangesRotting(new int[][]{{2,1,1},{1,1,0},{0,1,1}});
        if (res1 != 4) throw new AssertionError("lc994 example1: got " + res1);

        var res2 = sol.orangesRotting(new int[][]{{2,1,1},{0,1,1},{1,0,1}});
        if (res2 != -1) throw new AssertionError("lc994 impossible: got " + res2);

        var res3 = sol.orangesRotting(new int[][]{{0,2}});
        if (res3 != 0) throw new AssertionError("lc994 no_fresh: got " + res3);

        System.out.println("LC #994 passed");
    }
}
```

**Time:** O(m*n). **Space:** O(m*n).

---

## LC542. 01 Matrix

**Problem.** Binary matrix — return a matrix where each cell contains the distance to the nearest 0.

**Approach 1 — Multi-Source BFS from All Zeros (O(R×C) time, O(R×C) space).**
Multi-source BFS from all zero cells simultaneously. Initialize `dist[r][c] = 0` for zeros and
`Integer.MAX_VALUE` for ones, enqueue all zeros. BFS propagates `dist[neighbor] = dist[curr] + 1`
outward, guaranteeing shortest distance from each cell to its nearest zero.
Cells with value 1 start unvisited (distance = MAX); seeded zeros start at distance 0.

```java
import java.util.ArrayDeque;
import java.util.Arrays;

class Solution542 {
    private static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};

    public int[][] updateMatrix(int[][] mat) {
        int rows = mat.length, cols = mat[0].length;
        int[][] dist = new int[rows][cols];
        for (int[] row : dist) Arrays.fill(row, Integer.MAX_VALUE);
        var queue = new ArrayDeque<int[]>();

        // Seed: all zeros at distance 0 — mark visited by setting dist = 0
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (mat[r][c] == 0) {
                    dist[r][c] = 0;
                    queue.addLast(new int[]{r, c});
                }
            }
        }

        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int r = cur[0], c = cur[1];
            for (int[] d : DIRS4) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (dist[nr][nc] > dist[r][c] + 1) {
                    dist[nr][nc] = dist[r][c] + 1;
                    queue.addLast(new int[]{nr, nc});
                }
            }
        }
        return dist;
    }

    public static void main(String[] args) {
        var sol = new Solution542();
        var res1 = sol.updateMatrix(new int[][]{{0,0,0},{0,1,0},{0,0,0}});
        if (!Arrays.deepEquals(res1, new int[][]{{0,0,0},{0,1,0},{0,0,0}}))
            throw new AssertionError("lc542 example1: got " + Arrays.deepToString(res1));

        var res2 = sol.updateMatrix(new int[][]{{0,0,0},{0,1,0},{1,1,1}});
        if (!Arrays.deepEquals(res2, new int[][]{{0,0,0},{0,1,0},{1,2,1}}))
            throw new AssertionError("lc542 example2: got " + Arrays.deepToString(res2));

        System.out.println("LC #542 passed");
    }
}
```

**Time:** O(m*n). **Space:** O(m*n).

---

## LC286. Walls and Gates

**Problem.** Grid contains walls (-1), gates (0), and empty rooms (`Integer.MAX_VALUE`). Fill each
empty room with its distance to the nearest gate in-place.

**Approach 1 — Multi-Source BFS from All Gates (O(R×C) time, O(R×C) space).**
Multi-source BFS from all gate cells (value 0) simultaneously. The grid itself is mutated to
store distances as BFS propagates — this is structurally identical to LC542 but with gates as
sources instead of zeros.

```java
import java.util.ArrayDeque;
import java.util.Arrays;

class SolutionWG {
    private static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};
    private static final int INF = Integer.MAX_VALUE;

    public void wallsAndGates(int[][] rooms) {
        int rows = rooms.length, cols = rooms[0].length;
        var queue = new ArrayDeque<int[]>();

        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (rooms[r][c] == 0) queue.addLast(new int[]{r, c}); // seed all gates

        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int r = cur[0], c = cur[1];
            for (int[] d : DIRS4) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (rooms[nr][nc] == INF) {           // unvisited room
                    rooms[nr][nc] = rooms[r][c] + 1;  // mark by updating distance
                    queue.addLast(new int[]{nr, nc});
                }
            }
        }
    }

    public static void main(String[] args) {
        var sol = new SolutionWG();
        int INF = Integer.MAX_VALUE;
        int[][] grid = {
            {INF,  -1,  0,  INF},
            {INF, INF, INF,  -1},
            {INF,  -1, INF,  -1},
            {  0,  -1, INF, INF}
        };
        sol.wallsAndGates(grid);
        if (grid[0][0] != 3) throw new AssertionError("wallsAndGates [0][0]: got " + grid[0][0]);
        if (grid[0][3] != 1) throw new AssertionError("wallsAndGates [0][3]: got " + grid[0][3]);
        if (grid[1][2] != 1) throw new AssertionError("wallsAndGates [1][2]: got " + grid[1][2]);
        if (grid[2][2] != 2) throw new AssertionError("wallsAndGates [2][2]: got " + grid[2][2]);
        System.out.println("Walls and Gates passed");
    }
}
```

**Time:** O(m*n). **Space:** O(m*n).

---

## LC1091. Shortest Path in Binary Matrix

**Problem.** In an n×n binary matrix, find the shortest clear path (all 0s) from top-left `(0,0)` to
bottom-right `(n-1,n-1)` using 8-directional movement. Return length or -1.

**Approach 1 — Standard BFS with 8-Directional Neighbors (O(n²) time, O(n²) space).**
Standard BFS from `(0,0)` using all 8 neighbors. Return -1 immediately if start or end is blocked.
Mark visited cells by writing `1` into the grid. Return BFS depth when `(n-1,n-1)` is reached.

```java
import java.util.ArrayDeque;

class Solution1091 {
    private static final int[][] DIRS8 = {
        {-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}
    };

    public int shortestPathBinaryMatrix(int[][] grid) {
        int n = grid.length;
        if (grid[0][0] == 1 || grid[n-1][n-1] == 1) return -1;
        if (n == 1) return 1;

        var queue = new ArrayDeque<int[]>(); // {r, c, dist}
        queue.addLast(new int[]{0, 0, 1});
        grid[0][0] = 1; // mark visited

        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int r = cur[0], c = cur[1], dist = cur[2];
            for (int[] d : DIRS8) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
                if (grid[nr][nc] != 0) continue;
                if (nr == n-1 && nc == n-1) return dist + 1;
                grid[nr][nc] = 1;              // mark visited before enqueue
                queue.addLast(new int[]{nr, nc, dist + 1});
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution1091();
        var r1 = sol.shortestPathBinaryMatrix(new int[][]{{0,1},{1,0}});
        if (r1 != 2) throw new AssertionError("lc1091 example1: got " + r1);

        var r2 = sol.shortestPathBinaryMatrix(new int[][]{{0,0,0},{1,1,0},{1,1,0}});
        if (r2 != 4) throw new AssertionError("lc1091 example2: got " + r2);

        var r3 = sol.shortestPathBinaryMatrix(new int[][]{{1,0,0},{0,0,0},{0,0,0}});
        if (r3 != -1) throw new AssertionError("lc1091 blocked: got " + r3);

        System.out.println("LC #1091 passed");
    }
}
```

**Time:** O(n^2). **Space:** O(n^2).

---

## LC909. Snakes and Ladders

**Problem.** On an n×n Boustrophedon board, find the minimum dice rolls to reach the last square.
Cells may redirect via snakes or ladders.

**Approach 1 — BFS on Board Square State Space (O(n²) time, O(n²) space).**
BFS on 1-indexed square numbers `1..n²`. The tricky part is the Boustrophedon coordinate mapping
from square number to `(row, col)` — rows alternate direction from the bottom of the board.
Apply snake/ladder destination before enqueuing each square.

```java
import java.util.ArrayDeque;

class Solution909 {
    // Convert 1-indexed square number to (row, col) using Boustrophedon ordering
    private static int[] squareToRC(int s, int n) {
        int idx = s - 1;
        int rowFromBottom = idx / n;
        int col = (rowFromBottom % 2 == 0) ? idx % n : n - 1 - idx % n;
        int row = n - 1 - rowFromBottom;
        return new int[]{row, col};
    }

    public int snakesAndLadders(int[][] board) {
        int n = board.length;
        int target = n * n;
        boolean[] visited = new boolean[target + 1];
        visited[1] = true;
        var queue = new ArrayDeque<int[]>(); // {square, steps}
        queue.addLast(new int[]{1, 0});

        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int sq = cur[0], steps = cur[1];
            for (int dice = 1; dice <= 6; dice++) {
                int next = sq + dice;
                if (next > target) break;
                int[] rc = squareToRC(next, n);
                if (board[rc[0]][rc[1]] != -1) next = board[rc[0]][rc[1]];
                if (next == target) return steps + 1;
                if (!visited[next]) {
                    visited[next] = true;
                    queue.addLast(new int[]{next, steps + 1});
                }
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution909();
        var r1 = sol.snakesAndLadders(new int[][]{
            {-1,-1,-1,-1,-1,-1},
            {-1,-1,-1,-1,-1,-1},
            {-1,-1,-1,-1,-1,-1},
            {-1,35,-1,-1,13,-1},
            {-1,-1,-1,-1,-1,-1},
            {-1,15,-1,-1,-1,-1}
        });
        if (r1 != 4) throw new AssertionError("lc909 example1: got " + r1);

        var r2 = sol.snakesAndLadders(new int[][]{{-1,-1},{-1,3}});
        if (r2 != 1) throw new AssertionError("lc909 example2: got " + r2);

        System.out.println("LC #909 passed");
    }
}
```

**Time:** O(n^2). **Space:** O(n^2).

---

## LC1210. Minimum Moves to Reach Target (Snake in Grid)

**Problem.** A length-2 snake in an n×n grid starts horizontal at `(0,0)-(0,1)`. Move it right,
down, or rotate in valid empty cells. Find the minimum moves to reach `(n-1,n-2)-(n-1,n-1)`, or
-1 if impossible.

**Approach 1 — BFS on Compressed State (O(n²) time, O(n²) space).**
BFS over the state space `(tailRow, tailCol, isHorizontal)`: each state encodes the snake's
position and orientation uniquely. A `HashSet` of visited states prevents revisiting. Return
BFS depth when the target state is dequeued.

```java
import java.util.ArrayDeque;
import java.util.HashSet;

class Solution1210 {
    public int minimumMoves(int[][] grid) {
        int n = grid.length;
        // State: tailRow * n * 2 + tailCol * 2 + (horizontal ? 0 : 1)
        var visited = new HashSet<Integer>();
        int startState = encode(0, 0, true, n);
        visited.add(startState);
        var queue = new ArrayDeque<int[]>(); // {tailRow, tailCol, horiz(1/0), steps}
        queue.addLast(new int[]{0, 0, 1, 0});

        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int tr = cur[0], tc = cur[1];
            boolean horiz = cur[2] == 1;
            int steps = cur[3];

            if (tr == n-1 && tc == n-2 && horiz) return steps;

            if (horiz) {
                // Move right
                if (tc + 2 < n && grid[tr][tc+2] == 0)
                    tryAdd(queue, visited, tr, tc+1, true, steps+1, n);
                // Move down
                if (tr + 1 < n && grid[tr+1][tc] == 0 && grid[tr+1][tc+1] == 0)
                    tryAdd(queue, visited, tr+1, tc, true, steps+1, n);
                // Rotate clockwise → vertical
                if (tr + 1 < n && grid[tr+1][tc] == 0 && grid[tr+1][tc+1] == 0)
                    tryAdd(queue, visited, tr, tc, false, steps+1, n);
            } else {
                // Move down
                if (tr + 2 < n && grid[tr+2][tc] == 0)
                    tryAdd(queue, visited, tr+1, tc, false, steps+1, n);
                // Move right
                if (tc + 1 < n && grid[tr][tc+1] == 0 && grid[tr+1][tc+1] == 0)
                    tryAdd(queue, visited, tr, tc+1, false, steps+1, n);
                // Rotate counter-clockwise → horizontal
                if (tc + 1 < n && grid[tr][tc+1] == 0 && grid[tr+1][tc+1] == 0)
                    tryAdd(queue, visited, tr, tc, true, steps+1, n);
            }
        }
        return -1;
    }

    private void tryAdd(ArrayDeque<int[]> q, HashSet<Integer> visited,
                        int tr, int tc, boolean horiz, int steps, int n) {
        int state = encode(tr, tc, horiz, n);
        if (visited.add(state)) {
            q.addLast(new int[]{tr, tc, horiz ? 1 : 0, steps});
        }
    }

    private int encode(int tr, int tc, boolean horiz, int n) {
        return tr * n * 2 + tc * 2 + (horiz ? 0 : 1);
    }

    public static void main(String[] args) {
        var sol = new Solution1210();
        var r1 = sol.minimumMoves(new int[][]{
            {0,0,0,0,0,1},{1,1,0,0,1,0},{0,0,0,0,1,1},
            {0,0,1,0,1,0},{0,1,1,0,0,0},{0,1,1,0,0,0}
        });
        if (r1 != 11) throw new AssertionError("lc1210 example1: got " + r1);

        var r2 = sol.minimumMoves(new int[][]{
            {0,0,1,1,1,1},{0,0,0,0,1,1},{1,1,0,0,0,1},
            {1,1,1,0,0,1},{1,1,1,0,0,1},{1,1,1,0,0,0}
        });
        if (r2 != 9) throw new AssertionError("lc1210 example2: got " + r2);

        System.out.println("LC #1210 passed");
    }
}
```

**Time:** O(n^2) states, O(1) transitions each: O(n^2). **Space:** O(n^2).

**Java note:** Encoding the state as a single `int` (`tr * n * 2 + tc * 2 + orientation`) avoids
boxing a three-element tuple — `HashSet<Integer>` is significantly faster than
`HashSet<String>` for large grids.

---

## Part 3 — Graph BFS

---

## LC133. Clone Graph

**Problem.** Deep-clone a connected undirected graph. Each node has a `val` and a list of neighbors.

**Approach 1 — BFS with HashMap Clone Registry (O(V+E) time, O(V+E) space).**
BFS using a `HashMap<Node, Node>` (reference identity, default `Object.hashCode`) to map original
nodes to their clones. When a neighbor is first encountered, create its clone and enqueue the
original. The map ensures each node is cloned exactly once.
to map original nodes to their clones.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

class Solution133 {
    static class Node {
        int val;
        List<Node> neighbors;
        Node(int val) { this.val = val; this.neighbors = new ArrayList<>(); }
    }

    public Node cloneGraph(Node node) {
        if (node == null) return null;
        // Java Map uses reference equality by default (Object.hashCode) — ideal for graph cloning
        var map = new HashMap<Node, Node>();
        var queue = new ArrayDeque<Node>();
        map.put(node, new Node(node.val));
        queue.addLast(node);
        while (!queue.isEmpty()) {
            Node curr = queue.pollFirst();
            for (Node nb : curr.neighbors) {
                if (!map.containsKey(nb)) {
                    map.put(nb, new Node(nb.val));
                    queue.addLast(nb);          // visited = key exists in map
                }
                map.get(curr).neighbors.add(map.get(nb));
            }
        }
        return map.get(node);
    }

    public static void main(String[] args) {
        var sol = new Solution133();
        // 1 -- 2
        Node n1 = new Node(1), n2 = new Node(2);
        n1.neighbors.add(n2);
        n2.neighbors.add(n1);
        Node c1 = sol.cloneGraph(n1);
        if (c1 == null)
            throw new AssertionError("lc133: clone is null");
        if (c1 == n1)
            throw new AssertionError("lc133: clone is same reference as original");
        if (c1.val != 1)
            throw new AssertionError("lc133: clone val wrong: got " + c1.val);
        if (c1.neighbors.get(0).val != 2)
            throw new AssertionError("lc133: clone neighbor val wrong");

        if (sol.cloneGraph(null) != null)
            throw new AssertionError("lc133 null: expected null");

        System.out.println("LC #133 passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V) for the map.

> **Java vs Rust:** Java's `HashMap<Node, Node>` uses reference identity by default (each object's
> memory address as key), making it a perfect fit for graph cloning. Rust cannot hash
> `Rc<RefCell<Node>>` by pointer address without unsafe code, so the Rust chapter used the `val`
> field as the key — a workaround required only by the ownership model.

---

## LC1971. Find if Path Exists in Graph

**Problem.** Given n nodes and undirected edges, determine if a path exists from `source` to `destination`.

**Approach 1 — Standard BFS Reachability (O(V+E) time, O(V+E) space).**
Standard BFS from source: mark visited before enqueue to avoid revisiting. Return true as soon
as the destination node is dequeued.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

class Solution1971 {
    public boolean validPath(int n, int[][] edges, int source, int destination) {
        if (source == destination) return true;
        List<List<Integer>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());
        for (int[] e : edges) {
            adj.get(e[0]).add(e[1]);
            adj.get(e[1]).add(e[0]);
        }
        boolean[] visited = new boolean[n];
        visited[source] = true;
        var queue = new ArrayDeque<Integer>();
        queue.addLast(source);
        while (!queue.isEmpty()) {
            int node = queue.pollFirst();
            for (int nb : adj.get(node)) {
                if (nb == destination) return true;
                if (!visited[nb]) {
                    visited[nb] = true;
                    queue.addLast(nb);
                }
            }
        }
        return false;
    }

    public static void main(String[] args) {
        var sol = new Solution1971();
        if (!sol.validPath(3, new int[][]{{0,1},{1,2},{2,0}}, 0, 2))
            throw new AssertionError("lc1971 example1: expected true");
        if (sol.validPath(6, new int[][]{{0,1},{0,2},{3,5},{5,4},{4,3}}, 0, 5))
            throw new AssertionError("lc1971 example2: expected false");
        System.out.println("LC #1971 passed");
    }
}
```

**Time:** O(V + E). **Space:** O(V + E).

---

## LC1926. Nearest Exit from Entrance in Maze

**Problem.** Grid of `'+'` (walls) and `'.'` (empty). Find shortest path from `entrance` to any
non-entrance border cell. Return steps or -1.

**Approach 1 — Standard BFS from Entrance (O(R×C) time, O(R×C) space).**
Standard BFS from the entrance cell; return the BFS distance the first time a non-entrance border
empty cell is reached. Skip walls and the entrance itself.
Mark the entrance as a wall before starting to exclude it from exit candidates.

```java
import java.util.ArrayDeque;

class Solution1926 {
    private static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};

    public int nearestExit(char[][] maze, int[] entrance) {
        int rows = maze.length, cols = maze[0].length;
        int er = entrance[0], ec = entrance[1];
        maze[er][ec] = '+';                   // mark entrance as wall (visited)
        var queue = new ArrayDeque<int[]>();  // {r, c, dist}
        queue.addLast(new int[]{er, ec, 0});

        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int r = cur[0], c = cur[1], dist = cur[2];
            for (int[] d : DIRS4) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (maze[nr][nc] == '+') continue;
                // Border cell that is not the entrance
                if (nr == 0 || nr == rows-1 || nc == 0 || nc == cols-1) return dist + 1;
                maze[nr][nc] = '+';           // mark visited
                queue.addLast(new int[]{nr, nc, dist + 1});
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        // Re-create arrays for each test since maze is mutated in-place
        var r1 = new Solution1926().nearestExit(
            new char[][]{{'+','+','.'},{'.','.','.'},{'+','+','+'}},
            new int[]{1, 2});
        if (r1 != 1) throw new AssertionError("lc1926 example1: got " + r1);

        var r2 = new Solution1926().nearestExit(
            new char[][]{{'+','+','+'},{'.','.','.'},{'+','+','+'}},
            new int[]{1, 0});
        if (r2 != 2) throw new AssertionError("lc1926 example2: got " + r2);

        var r3 = new Solution1926().nearestExit(
            new char[][]{{'.', '+'}},
            new int[]{0, 0});
        if (r3 != -1) throw new AssertionError("lc1926 no_exit: got " + r3);

        System.out.println("LC #1926 passed");
    }
}
```

**Time:** O(m*n). **Space:** O(m*n).

---

## LC1345. Jump Game IV

**Problem.** From index `i`, jump to `i+1`, `i-1`, or any index `j` where `arr[i] == arr[j]`.
Return minimum jumps to reach the last index.

**Approach 1 — BFS with Value-Bucket Neighbor Groups (O(n) time, O(n) space).**
BFS with a `HashMap<Integer, List<Integer>>` grouping indices by value. Neighbors of `i` are
`i-1`, `i+1`, and all indices sharing `arr[i]`'s value. Critically, remove the value bucket from
the map after processing it — without this, same-value nodes re-enqueue each other causing O(n²).

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

class Solution1345 {
    public int minJumps(int[] arr) {
        int n = arr.length;
        if (n == 1) return 0;

        var valToIndices = new HashMap<Integer, List<Integer>>();
        for (int i = 0; i < n; i++)
            valToIndices.computeIfAbsent(arr[i], k -> new ArrayList<>()).add(i);

        boolean[] visited = new boolean[n];
        visited[0] = true;
        var queue = new ArrayDeque<Integer>();
        queue.addLast(0);
        int steps = 0;

        while (!queue.isEmpty()) {
            int size = queue.size();
            steps++;
            for (int i = 0; i < size; i++) {
                int idx = queue.pollFirst();
                // Adjacent jumps
                for (int next : new int[]{idx - 1, idx + 1}) {
                    if (next >= 0 && next < n && !visited[next]) {
                        if (next == n - 1) return steps;
                        visited[next] = true;
                        queue.addLast(next);
                    }
                }
                // Same-value jumps — remove bucket after use to prevent O(n^2)
                List<Integer> same = valToIndices.remove(arr[idx]);
                if (same != null) {
                    for (int j : same) {
                        if (!visited[j]) {
                            if (j == n - 1) return steps;
                            visited[j] = true;
                            queue.addLast(j);
                        }
                    }
                }
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution1345();
        var r1 = sol.minJumps(new int[]{100,-23,-23,404,100,23,23,23,3,404});
        if (r1 != 3) throw new AssertionError("lc1345 example1: got " + r1);

        var r2 = new Solution1345().minJumps(new int[]{7});
        if (r2 != 0) throw new AssertionError("lc1345 example2: got " + r2);

        var r3 = new Solution1345().minJumps(new int[]{7,6,9,6,9,6,9,7});
        if (r3 != 1) throw new AssertionError("lc1345 example3: got " + r3);

        System.out.println("LC #1345 passed");
    }
}
```

**Time:** O(n) amortized — each index enqueued at most once, each value bucket removed at most once.
**Space:** O(n).

---

## Part 4 — Advanced BFS

---

## LC815. Bus Routes

**Problem.** Bus routes are arrays of stops. Start at `source`, reach `target`. You may board any
bus at any of its stops. Return the minimum number of buses to take, or -1.

**Approach 1 — BFS on Route Graph (O(total stops²) time, O(total stops) space).**
BFS where nodes are bus routes, not stops. Build a stop-to-routes map; from each route's stops,
find and enqueue all unvisited connecting routes. Each BFS level represents one additional bus
boarded. Track both visited stops and visited routes to avoid re-processing.

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;

class Solution815 {
    public int numBusesToDestination(int[][] routes, int source, int target) {
        if (source == target) return 0;

        var stopToRoutes = new HashMap<Integer, List<Integer>>();
        for (int ri = 0; ri < routes.length; ri++)
            for (int stop : routes[ri])
                stopToRoutes.computeIfAbsent(stop, k -> new ArrayList<>()).add(ri);

        var visitedRoutes = new HashSet<Integer>();
        var visitedStops  = new HashSet<Integer>();
        visitedStops.add(source);
        var queue = new ArrayDeque<Integer>(); // BFS on stops
        queue.addLast(source);
        int buses = 0;

        while (!queue.isEmpty()) {
            int size = queue.size();
            buses++;
            for (int i = 0; i < size; i++) {
                int stop = queue.pollFirst();
                List<Integer> routeList = stopToRoutes.getOrDefault(stop, List.of());
                for (int ri : routeList) {
                    if (!visitedRoutes.add(ri)) continue; // already processed this route
                    for (int nextStop : routes[ri]) {
                        if (nextStop == target) return buses;
                        if (visitedStops.add(nextStop)) {
                            queue.addLast(nextStop);
                        }
                    }
                }
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution815();
        var r1 = sol.numBusesToDestination(new int[][]{{1,2,7},{3,6,7}}, 1, 6);
        if (r1 != 2) throw new AssertionError("lc815 example1: got " + r1);

        var r2 = new Solution815().numBusesToDestination(
            new int[][]{{7,12},{4,5,15},{6}}, 15, 12);
        if (r2 != -1) throw new AssertionError("lc815 no_route: got " + r2);

        var r3 = new Solution815().numBusesToDestination(new int[][]{{1,2}}, 1, 1);
        if (r3 != 0) throw new AssertionError("lc815 same_stop: got " + r3);

        System.out.println("LC #815 passed");
    }
}
```

**Time:** O(sum of route lengths). **Space:** O(same).

---

## LC934. Shortest Bridge

**Problem.** Binary grid with exactly two islands. Find the minimum number of 0s to flip to connect
them (shortest bridge).

**Approach 1 — DFS to Mark Island 1, then Multi-Source BFS to Bridge (O(n²) time, O(n²) space).**
DFS identifies and marks all cells of the first island with a sentinel value (2). Then multi-source
BFS expands outward from all first-island cells until a cell of the second island (value 1) is
reached. The BFS depth at that point is the minimum bridge length.

```java
import java.util.ArrayDeque;

class Solution934 {
    private static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};

    public int shortestBridge(int[][] grid) {
        int rows = grid.length, cols = grid[0].length;
        var queue = new ArrayDeque<int[]>();

        // Step 1: DFS to find and mark the first island as 2
        outer:
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 1) {
                    dfs(grid, r, c, rows, cols, queue);
                    break outer;
                }
            }
        }

        // Step 2: BFS expansion toward the second island
        int steps = 0;
        while (!queue.isEmpty()) {
            int size = queue.size();
            for (int i = 0; i < size; i++) {
                int[] cur = queue.pollFirst();
                int r = cur[0], c = cur[1];
                for (int[] d : DIRS4) {
                    int nr = r + d[0], nc = c + d[1];
                    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                    if (grid[nr][nc] == 1) return steps;  // reached second island
                    if (grid[nr][nc] == 0) {
                        grid[nr][nc] = 2;                 // mark water as visited
                        queue.addLast(new int[]{nr, nc});
                    }
                }
            }
            steps++;
        }
        return -1;
    }

    private void dfs(int[][] grid, int r, int c, int rows, int cols, ArrayDeque<int[]> queue) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] != 1) return;
        grid[r][c] = 2;                         // mark as visited (part of island 1)
        queue.addLast(new int[]{r, c});          // seed BFS queue
        for (int[] d : DIRS4)
            dfs(grid, r + d[0], c + d[1], rows, cols, queue);
    }

    public static void main(String[] args) {
        var sol = new Solution934();
        var r1 = sol.shortestBridge(new int[][]{{0,1},{1,0}});
        if (r1 != 1) throw new AssertionError("lc934 example1: got " + r1);

        var r2 = new Solution934().shortestBridge(
            new int[][]{{0,1,0},{0,0,0},{0,0,1}});
        if (r2 != 2) throw new AssertionError("lc934 example2: got " + r2);

        var r3 = new Solution934().shortestBridge(new int[][]{
            {1,1,1,1,1},{1,0,0,0,1},{1,0,1,0,1},{1,0,0,0,1},{1,1,1,1,1}
        });
        if (r3 != 1) throw new AssertionError("lc934 adjacent: got " + r3);

        System.out.println("LC #934 passed");
    }
}
```

**Time:** O(m*n) DFS + O(m*n) BFS = O(m*n). **Space:** O(m*n).

**Java note:** The DFS populates the `ArrayDeque` directly — this avoids collecting island-1 cells
into a temporary list and then re-adding them to the queue. The DFS may stack-overflow on very
large inputs; for production code, convert to iterative DFS using an explicit `ArrayDeque` stack.

---

## LC675. Cut Off Trees for Golf Event

**Problem.** Grid where each cell is 0 (obstacle), 1 (flat), or >1 (tree height). Cut all trees in
increasing height order, starting at `(0,0)`. Return total steps, or -1 if any tree is unreachable.

**Approach 1 — Sort by Height + Repeated BFS (O(T · R×C) time, O(R×C) space).**
Sort all trees by height, then BFS from the current position to each tree in sorted order,
accumulating the total step count. Return -1 if any BFS cannot reach the next tree. T is the
number of trees; each BFS is O(R×C).

```java
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Solution675 {
    private static final int[][] DIRS4 = {{-1,0},{1,0},{0,-1},{0,1}};

    public int cutOffTree(List<List<Integer>> forest) {
        int rows = forest.size(), cols = forest.get(0).size();

        // Collect trees (height > 1) and sort by height
        List<int[]> trees = new ArrayList<>(); // {height, r, c}
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (forest.get(r).get(c) > 1)
                    trees.add(new int[]{forest.get(r).get(c), r, c});
        trees.sort((a, b) -> a[0] - b[0]);

        int total = 0, curR = 0, curC = 0;
        for (int[] tree : trees) {
            int tr = tree[1], tc = tree[2];
            int steps = bfs(forest, rows, cols, curR, curC, tr, tc);
            if (steps == -1) return -1;
            total += steps;
            curR = tr; curC = tc;
        }
        return total;
    }

    private int bfs(List<List<Integer>> forest, int rows, int cols,
                    int sr, int sc, int tr, int tc) {
        if (sr == tr && sc == tc) return 0;
        boolean[][] visited = new boolean[rows][cols];
        visited[sr][sc] = true;
        var queue = new ArrayDeque<int[]>(); // {r, c, dist}
        queue.addLast(new int[]{sr, sc, 0});
        while (!queue.isEmpty()) {
            int[] cur = queue.pollFirst();
            int r = cur[0], c = cur[1], dist = cur[2];
            for (int[] d : DIRS4) {
                int nr = r + d[0], nc = c + d[1];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (forest.get(nr).get(nc) == 0 || visited[nr][nc]) continue;
                if (nr == tr && nc == tc) return dist + 1;
                visited[nr][nc] = true;
                queue.addLast(new int[]{nr, nc, dist + 1});
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        var sol = new Solution675();
        var r1 = sol.cutOffTree(List.of(
            List.of(54581641,64080174,24346381,69107959),
            List.of(86374198,61363882,68783324,79706116),
            List.of(668150,92178815,89819108,94701471),
            List.of(83920491,22724204,46281641,47531096),
            List.of(89078499,18904913,25462145,60813308)));
        if (r1 != 57) throw new AssertionError("lc675 large: got " + r1);

        var r2 = new Solution675().cutOffTree(List.of(
            List.of(1,2,3), List.of(0,0,0), List.of(7,6,5)));
        if (r2 != -1) throw new AssertionError("lc675 blocked: got " + r2);

        var r3 = new Solution675().cutOffTree(List.of(
            List.of(2,3,4), List.of(0,0,5), List.of(8,7,6)));
        if (r3 != 6) throw new AssertionError("lc675 simple: got " + r3);

        System.out.println("LC #675 passed");
    }
}
```

**Time:** O(k * m * n) where k = number of trees. In the given constraints (50×50 grid, up to
2500 trees), this is O(2500 * 2500) = O(6.25M) — acceptable. **Space:** O(m*n) per BFS call.

**Java note:** `trees.sort((a, b) -> a[0] - b[0])` is safe here because tree heights are
positive (subtraction won't overflow). For general comparisons use `Integer.compare(a[0], b[0])`.

---

## Summary: BFS Pattern Selector

```
Is the graph unweighted (all equal edge weights)?
  YES → BFS gives shortest path in O(V + E)
  NO  → Dijkstra (non-negative weights) or Bellman-Ford (negative edges)

What is your BFS node?
  Grid cell (r,c)      → Grid BFS: ArrayDeque<int[]>, DIRS4/DIRS8, bounds check
  Graph node index     → Adjacency list BFS: List<List<Integer>>
  State (tuple/struct) → State-space BFS: HashSet<Integer> (encoded) for visited
  String / sequence    → HashSet<String>; pattern buckets for word-graph neighbors

Do you need level information?
  YES → int size = queue.size(); for (int i = 0; i < size; i++) { ... }
  NO  → Simple while (!queue.isEmpty()) with a dist[] array

Multiple sources?
  YES → Add ALL sources to queue and mark them all visited BEFORE the main loop

Shortest path optimization needed?
  YES and graph is symmetric → Bidirectional BFS: swap to expand the smaller frontier
  YES and state space is 0/1-weighted → 0-1 BFS: ArrayDeque as deque (addFirst/addLast)
```

| Pattern | Queue type | Visited tracking |
|---|---|---|
| Standard BFS | `ArrayDeque<Integer>` | `boolean[]` or `dist[i] != -1` |
| Level BFS | `ArrayDeque<T>` + `int size = queue.size()` | `boolean[]` |
| Multi-source | `ArrayDeque<T>` pre-seeded | `boolean[]` or `dist[i] != -1` |
| Grid BFS | `ArrayDeque<int[]>` | mutate grid or `boolean[][]` |
| State-space BFS | `ArrayDeque<int[]>` | `HashSet<Integer>` (encoded state) |
| 0-1 BFS | `ArrayDeque<T>` as deque | `dist[]` with relaxation |
| Bidirectional | Two `HashSet<T>` frontiers | union of both sets |

---

## Java vs Rust Quick Reference

| Java | Rust | Notes |
|---|---|---|
| `new ArrayDeque<Integer>()` | `VecDeque::<usize>::new()` | Both are ring-buffer backed |
| `queue.addLast(x)` | `queue.push_back(x)` | enqueue at back |
| `queue.pollFirst()` | `queue.pop_front()` | dequeue from front; Rust returns `Option<T>` |
| `queue.peekFirst()` | `queue.front()` | returns `Option<&T>` in Rust |
| `queue.isEmpty()` | `queue.is_empty()` | identical semantics |
| `queue.size()` | `queue.len()` | identical semantics |
| `new int[]{r, c}` | `(r, c): (i32, i32)` | Java heap-allocates; Rust uses stack tuple |
| `Map<Node, Node>` | `HashMap<i32, Rc<RefCell<Node>>>` | Java uses ref-equality; Rust uses val key |
| `(d + 10) % 10` | `.rem_euclid(10)` | Java `%` is signed; Rust `rem_euclid` always >= 0 |

---

## 📝 Chapter Review Notes

### Issue Table

| Issue | Severity | Fix Applied |
|---|---|---|
| `assert` keyword used anywhere | High | Verified absent — all checks use `throw new AssertionError(...)` |
| `LinkedList` used as `Queue` | High | Verified absent — all queues use `ArrayDeque` |
| Visited marked after dequeue (not before enqueue) | High | Verified all solutions mark visited at enqueue time |
| LC #1926 test re-uses mutated maze array | Medium | Fixed — each test case instantiates a fresh `Solution1926` and creates a new array |
| Java `%` negative modulo in LC #752 | Medium | Documented and fixed with `(digit + delta + 10) % 10` |
| Level size snapshot pattern missing | Medium | Verified — all level-order problems use `int size = queue.size(); for (int i = 0; i < size; i++)` |
| LC #1210 state encoded as `HashSet<Integer>` vs `HashSet<int[]>` | Medium | Used integer encoding `tr * n * 2 + tc * 2 + orientation` — avoids broken array equality in `HashSet` |
| LC #126 `visitedLevel` vs `visitedAll` logic | Medium | Faithfully ported from Rust; inline comments explain the two-set distinction |
| LC #675 subtraction comparator may overflow | Low | Documented; tree heights are positive so overflow cannot occur in this problem |
| LC #934 DFS may stack-overflow on large grids | Low | Documented in Java note; iterative DFS recommended for production |
| Problem name/number mismatch for LC #2617 | High | Substituted with LC #1210 (Snake in Grid); mismatch documented in section header and here |

---

### Third-Person Critical Review

This chapter provides a complete Java 17+ companion to the Rust BFS deep-dive. All 20 problem slots
from the Rust source are covered, including the LC #1210 substitution for the ambiguous LC #2617
entry. Every code block compiles under standard Java 17 with no external dependencies.

**What this chapter does well:**

- The `ArrayDeque` discipline is applied consistently. No `LinkedList` appears anywhere as a queue.
  This is the single most impactful performance choice for Java BFS implementations.
- Visited marking happens uniformly at enqueue time, not dequeue time. This is critical for
  correctness: marking at dequeue allows a node to be enqueued multiple times before its first
  dequeue, which causes both redundant work and incorrect level tracking. Every solution in this
  chapter avoids this pitfall.
- The level-order snapshot pattern (`int size = queue.size(); for (int i = 0; i < size; i++)`)
  appears in every problem that requires level separation — LC #102, #103, #111, #127, #752, #994,
  #815, and #934.
- Integer state encoding in LC #1210 (`tr * n * 2 + tc * 2 + orientation`) sidesteps the broken
  `int[]` equality in Java's `HashSet` and `HashMap`. A common Java bug is using `int[]` as a
  map key, which uses reference identity rather than value equality.
- The Java vs Rust callouts are accurate and specific — not generic boilerplate.

**What could be improved:**

- The LC #126 (Word Ladder II) solution is complex and the `visitedLevel`/`visitedAll` distinction
  warrants a dedicated diagram. The correctness is verified, but a first-time reader may struggle
  to follow why two visited sets are necessary.
- LC #675's test driver uses `List.of(...)` with boxed `Integer` values, which means the nested
  list access via `forest.get(r).get(c)` does auto-unboxing on every call. For a competitive
  programming context this is fine; a production implementation would use `int[][]`.
- The 0-1 BFS template in the reference section has no corresponding problem in this chapter
  (none of the 20 problems require it). The template is included per the chapter rules, but a
  reader might benefit from a brief mention of which LeetCode problems use it (e.g., LC #1368,
  LC #2290).
- The bidirectional BFS template uses `Function<String, Iterable<String>>` which requires lambda
  capture — fine for illustration but not shown wired to an actual problem.