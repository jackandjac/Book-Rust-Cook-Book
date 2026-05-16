# LC-14 Part 2: Tree DP, Bitmask DP, State Machine DP — Java 17+ Edition

> **Companion chapter to `lc14-advanced-dp-part2.md`.** Covers the same 19 problems
> in idiomatic Java 17+. Solutions use `class SolutionNNN { public ... }` with a
> `public static void main(String[] args)` test driver.  
> **No JUnit, no `assert` keyword** — all checks throw `AssertionError` with a
> descriptive message including the actual value.

---

## Problem Overview

| # | Problem | Section | Pattern | Difficulty |
|---|---------|---------|---------|-----------|
| LC 337  | House Robber III | Tree DP | Rob/skip post-order | Medium |
| LC 968  | Binary Tree Cameras | Tree DP | 3-state post-order | Hard |
| LC 124  | Binary Tree Maximum Path Sum | Tree DP | Arm contribution | Hard |
| LC 1372 | Longest ZigZag Path | Tree DP | Directional DFS | Medium |
| LC 2246 | Longest Path With Different Adjacent Characters | Tree DP | Top-2 child arms | Hard |
| LC 1519 | Nodes in Sub-Tree With Same Label | Tree DP | Count[26] aggregation | Medium |
| LC 526  | Beautiful Arrangement | Bitmask | Forward mask build | Medium |
| LC 1986 | Min Work Sessions to Finish Tasks | Bitmask | (sessions, rem) pair | Medium |
| LC 1494 | Parallel Courses II | Bitmask | Submask prereq check | Hard |
| LC 2305 | Fair Distribution of Cookies | Bitmask | k-round submask | Medium |
| LC 847  | Shortest Path Visiting All Nodes | BFS + Bitmask | Multi-source BFS | Hard |
| LC 1125 | Smallest Sufficient Team | Bitmask | long team encoding | Hard |
| LC 1434 | Number of Ways to Wear Different Hats | Bitmask | Hat-outer, clone prev | Hard |
| LC 943  | Find the Shortest Superstring | Bitmask TSP | Forward build + recon | Hard |
| LC 309  | Stock With Cooldown | State Machine | held/sold/rest | Medium |
| LC 188  | Stock k Transactions | State Machine | buy[k]/sell[k] | Hard |
| LC 123  | Stock 2 Transactions | State Machine | 4 scalars | Hard |
| LC 1911 | Maximum Alternating Subsequence Sum | State Machine | even/odd states | Medium |
| LC 2826 | Sorting Three Groups | State Machine | LIS on {1,2,3} | Medium |

> **Java vs Rust — global callout:** Java arrays are **zero-initialized** by default;
> Rust arrays and `Vec` are also zero-initialized via `vec![0; n]`, so the default
> base case is the same. The difference surfaces when you need a non-zero initial value:
> Java requires `Arrays.fill(arr, value)` explicitly; Rust uses `vec![value; n]` in
> the initialization expression. Use `Integer.MAX_VALUE / 2` (not `Integer.MAX_VALUE`)
> as infinity whenever the value will participate in addition — adding 1 to
> `Integer.MAX_VALUE` overflows to `Integer.MIN_VALUE`. HashMap memoization incurs
> boxing overhead (keys become `Integer` / `Long` objects); for tight loops prefer
> plain `int[]` or `long[]` DP tables indexed directly.

---

## Section 4: Tree DP

DP on tree structures. A DFS post-order pass computes subtree states bottom-up:
children are processed before the current node, so each node can aggregate its
children's results.

**Java pattern:** Binary-tree problems use LeetCode's standard `TreeNode` class
(shown once per problem for self-containment). For general trees (adjacency-list
input), build `List<Integer>[] children` with `new ArrayList[n]`.

---

### Problem 1 — LC #337: House Robber III

**Problem statement:** Houses are arranged in a binary tree. Adjacent nodes
(parent–child) cannot both be robbed. Return the maximum amount that can be stolen.

**Key insight:** Each node returns a pair `(robThis, skipThis)`. The pair is
encoded as `int[2]` to avoid object allocation overhead.

```
robThis  = node.val + skip_left + skip_right
skipThis = max(rob_left, skip_left) + max(rob_right, skip_right)
answer   = max(robRoot[0], robRoot[1])
```

```java
import java.util.*;

class Solution337 {
    // Standard LeetCode TreeNode
    static class TreeNode {
        int val;
        TreeNode left, right;
        TreeNode(int v) { val = v; }
        TreeNode(int v, TreeNode l, TreeNode r) { val = v; left = l; right = r; }
    }

    public int rob(TreeNode root) {
        var res = dfs(root);
        return Math.max(res[0], res[1]);
    }

    // Returns int[]{robThis, skipThis}
    private int[] dfs(TreeNode node) {
        if (node == null) return new int[]{0, 0};
        var left  = dfs(node.left);
        var right = dfs(node.right);
        int robThis  = node.val + left[1] + right[1];
        int skipThis = Math.max(left[0], left[1]) + Math.max(right[0], right[1]);
        return new int[]{robThis, skipThis};
    }

    public static void main(String[] args) {
        var sol = new Solution337();

        // [3,2,3,null,3,null,1] -> 7
        var root1 = new TreeNode(3,
            new TreeNode(2, null, new TreeNode(3)),
            new TreeNode(3, null, new TreeNode(1)));
        int actual = sol.rob(root1);
        if (actual != 7) throw new AssertionError("test1: expected 7, got " + actual);

        // [3,4,5,1,3,null,1] -> 9
        var root2 = new TreeNode(3,
            new TreeNode(4, new TreeNode(1), new TreeNode(3)),
            new TreeNode(5, null, new TreeNode(1)));
        actual = sol.rob(root2);
        if (actual != 9) throw new AssertionError("test2: expected 9, got " + actual);

        System.out.println("LC 337 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(h) call stack.

> **Java vs Rust:** Rust returns a stack-allocated tuple `(i32, i32)` at zero cost.
> Java returns `new int[2]` which allocates on the heap; for n up to 10^4 nodes this
> is fine, but if allocation pressure matters, pass a reusable `int[]` parameter
> instead. `Arrays.fill` is not needed here — Java already zero-initializes `new int[2]`.

---

### Problem 2 — LC #968: Binary Tree Cameras

**Problem statement:** Install the minimum number of cameras in a binary tree so
every node is monitored. A camera monitors itself, its parent, and its children.

**Key insight:** Three-state DFS. Return value from each node:
- `0` — not covered (needs camera from parent)
- `1` — has a camera
- `2` — covered by a child camera, no camera here

Null nodes return `2` (treated as already covered). If root returns `0`, add one
more camera.

```java
class Solution968 {
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int v) { val = v; }
        TreeNode(int v, TreeNode l, TreeNode r) { val = v; left = l; right = r; }
    }

    private int cameras = 0;

    public int minCameraCover(TreeNode root) {
        cameras = 0;
        if (dfs(root) == 0) cameras++;   // root uncovered: place camera at root
        return cameras;
    }

    // Returns: 0=not_covered, 1=has_camera, 2=covered_no_camera
    private int dfs(TreeNode node) {
        if (node == null) return 2;      // absent node is already covered
        int ls = dfs(node.left);
        int rs = dfs(node.right);
        if (ls == 0 || rs == 0) { cameras++; return 1; }  // child uncovered → place here
        if (ls == 1 || rs == 1) return 2;                  // covered by child camera
        return 0;                                           // both covered, no camera nearby
    }

    public static void main(String[] args) {
        var sol = new Solution968();

        // [0,0,null,0,0] -> 1
        var root1 = new TreeNode(0,
            new TreeNode(0, new TreeNode(0), new TreeNode(0)),
            null);
        sol.cameras = 0;
        int actual = sol.minCameraCover(root1);
        if (actual != 1) throw new AssertionError("test1: expected 1, got " + actual);

        // [0,0,null,0,null,0,null,null,0] -> 2
        var root2 = new TreeNode(0,
            new TreeNode(0,
                new TreeNode(0, null,
                    new TreeNode(0, null, new TreeNode(0))),
                null),
            null);
        actual = sol.minCameraCover(root2);
        if (actual != 2) throw new AssertionError("test2: expected 2, got " + actual);

        System.out.println("LC 968 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(h).

> **Java vs Rust:** Rust passes `cameras: &mut i32` through recursion (functional
> style). Java uses an instance field `cameras` (object-state style). Both are valid;
> the Java approach is idiomatic since `Solution968` is instantiated per call. Reset
> `cameras = 0` at the top of the public method to avoid state leakage between test
> calls.

---

### Problem 3 — LC #124: Binary Tree Maximum Path Sum

**Problem statement:** A path in a binary tree visits each node at most once. Return
the maximum path sum. The path does not need to pass through the root.

**Key insight:** Each node returns the best single-arm gain going downward. The
global answer is updated with `node.val + left_arm + right_arm` (a path through the
current node). Clamp arms to 0 to discard negative contributions.

```java
class Solution124 {
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int v) { val = v; }
        TreeNode(int v, TreeNode l, TreeNode r) { val = v; left = l; right = r; }
    }

    private int ans;

    public int maxPathSum(TreeNode root) {
        ans = Integer.MIN_VALUE;
        dfs(root);
        return ans;
    }

    // Returns max single-arm contribution going downward from node
    private int dfs(TreeNode node) {
        if (node == null) return 0;
        int lv = Math.max(0, dfs(node.left));   // clamp: don't include negative arms
        int rv = Math.max(0, dfs(node.right));
        ans = Math.max(ans, node.val + lv + rv); // path passing through this node
        return node.val + Math.max(lv, rv);      // best single arm for parent
    }

    public static void main(String[] args) {
        var sol = new Solution124();

        // [1,2,3] -> 6
        int actual = sol.maxPathSum(new TreeNode(1, new TreeNode(2), new TreeNode(3)));
        if (actual != 6) throw new AssertionError("test1: expected 6, got " + actual);

        // [-10,9,20,null,null,15,7] -> 42
        actual = sol.maxPathSum(new TreeNode(-10,
            new TreeNode(9),
            new TreeNode(20, new TreeNode(15), new TreeNode(7))));
        if (actual != 42) throw new AssertionError("test2: expected 42, got " + actual);

        // Single negative node -> -3
        actual = sol.maxPathSum(new TreeNode(-3));
        if (actual != -3) throw new AssertionError("test3: expected -3, got " + actual);

        System.out.println("LC 124 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(h).

> **Java vs Rust:** `Integer.MIN_VALUE` as the initial `ans` handles all-negative
> trees (a single leaf is still a valid path). In Rust, `i32::MIN` serves the same
> role. Neither value participates in addition in this solution, so overflow is not
> a concern here.

---

### Problem 4 — LC #1372: Longest ZigZag Path in a Binary Tree

**Problem statement:** A ZigZag path alternates left and right turns. Return the
number of **edges** in the longest such path.

**Key insight:** DFS carries directional state. When continuing a ZigZag, follow the
opposite direction; when restarting, follow the same direction with length reset to 1.

```java
class Solution1372 {
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int v) { val = v; }
        TreeNode(int v, TreeNode l, TreeNode r) { val = v; left = l; right = r; }
    }

    private int ans = 0;

    public int longestZigZag(TreeNode root) {
        ans = 0;
        if (root != null) {
            dfs(root.left,  false, 1);  // went left from root
            dfs(root.right, true,  1);  // went right from root
        }
        return ans;
    }

    // wentRight: true if we arrived at this node by going right from its parent
    private void dfs(TreeNode node, boolean wentRight, int len) {
        if (node == null) return;
        ans = Math.max(ans, len);
        if (wentRight) {
            dfs(node.left,  false, len + 1); // continue zigzag: now go left
            dfs(node.right, true,  1);        // restart going right
        } else {
            dfs(node.right, true,  len + 1); // continue zigzag: now go right
            dfs(node.left,  false, 1);        // restart going left
        }
    }

    public static void main(String[] args) {
        var sol = new Solution1372();

        // Single node -> 0
        int actual = sol.longestZigZag(new TreeNode(1));
        if (actual != 0) throw new AssertionError("test1: expected 0, got " + actual);

        // root->right->left->right (3 edges)
        var n4   = new TreeNode(1);
        var n3   = new TreeNode(1); n3.right = n4;
        var n2   = new TreeNode(1); n2.left  = n3;
        var root = new TreeNode(1); root.right = n2;
        actual = sol.longestZigZag(root);
        if (actual != 3) throw new AssertionError("test2: expected 3, got " + actual);

        System.out.println("LC 1372 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(h).

> **Java vs Rust:** Rust uses a nested `fn dfs(...)` that receives `ans` as
> `&mut i32`. Java uses an instance field. Both are idiomatic. In Java 17+ you could
> also use a `int[]` single-element array to capture a mutable int inside a lambda,
> but the instance field approach is cleaner.

---

### Problem 5 — LC #2246: Longest Path With Different Adjacent Characters

**Problem statement:** Given a rooted tree encoded as a `parent` array plus a label
string, find the longest path where no two adjacent nodes share the same label.

**Key insight:** DFS returns the longest valid arm from each node downward. Keep
the top-2 distinct children arms (by label difference) and update the global answer
with `top1 + top2 + 1`.

```java
import java.util.*;

class Solution2246 {
    public int longestPath(int[] parent, String s) {
        int n = parent.length;
        List<Integer>[] children = new ArrayList[n];
        for (int i = 0; i < n; i++) children[i] = new ArrayList<>();
        for (int i = 1; i < n; i++) children[parent[i]].add(i);

        int[] ans = {1};
        dfs(0, children, s.toCharArray(), ans);
        return ans[0];
    }

    // Returns longest arm going downward from node
    private int dfs(int node, List<Integer>[] children, char[] s, int[] ans) {
        int top1 = 0, top2 = 0;  // top two valid child arms
        for (int child : children[node]) {
            int arm = dfs(child, children, s, ans);
            if (s[child] != s[node]) {   // label must differ to extend path
                if (arm > top1)      { top2 = top1; top1 = arm; }
                else if (arm > top2) { top2 = arm; }
            }
        }
        ans[0] = Math.max(ans[0], top1 + top2 + 1);
        return top1 + 1;
    }

    public static void main(String[] args) {
        var sol = new Solution2246();

        // parent=[-1,0,0,1,1,2], s="abacbe" -> 3
        int actual = sol.longestPath(new int[]{-1,0,0,1,1,2}, "abacbe");
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        // parent=[-1,0,0,0], s="aabc" -> 3
        actual = sol.longestPath(new int[]{-1,0,0,0}, "aabc");
        if (actual != 3) throw new AssertionError("test2: expected 3, got " + actual);

        // Single node -> 1
        actual = sol.longestPath(new int[]{-1}, "a");
        if (actual != 1) throw new AssertionError("test3: expected 1, got " + actual);

        System.out.println("LC 2246 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(n) for adjacency list and call stack.

> **Java vs Rust:** `int[] ans = {1}` is the canonical Java pattern for capturing a
> mutable int in a recursive helper (arrays are reference types; primitives are not).
> Rust passes `ans: &mut i32` directly. Both express the same idea; Java's `int[1]`
> is a slight syntactic friction compared to Rust's clean mutable reference.

---

### Problem 6 — LC #1519: Number of Nodes in the Sub-Tree With the Same Label

**Problem statement:** Given an undirected tree (edge list + label string), for each
node return the count of nodes in its subtree (including itself) with the same label.

**Key insight:** DFS accumulates a `int[26]` count of each label in the subtree.
After combining children, `ans[node] = cnt[label[node] - 'a']`.

```java
import java.util.*;

class Solution1519 {
    public int[] countSubTrees(int n, int[][] edges, String labels) {
        List<Integer>[] adj = new ArrayList[n];
        for (int i = 0; i < n; i++) adj[i] = new ArrayList<>();
        for (int[] e : edges) {
            adj[e[0]].add(e[1]);
            adj[e[1]].add(e[0]);
        }
        int[] ans = new int[n];
        dfs(0, -1, adj, labels.toCharArray(), ans);
        return ans;
    }

    // Returns int[26]: count of each label in the subtree rooted at node
    private int[] dfs(int node, int par, List<Integer>[] adj, char[] labels, int[] ans) {
        int[] cnt = new int[26];
        cnt[labels[node] - 'a'] = 1;
        for (int nb : adj[node]) {
            if (nb == par) continue;
            int[] sub = dfs(nb, node, adj, labels, ans);
            for (int i = 0; i < 26; i++) cnt[i] += sub[i];
        }
        ans[node] = cnt[labels[node] - 'a'];
        return cnt;
    }

    public static void main(String[] args) {
        var sol = new Solution1519();

        // n=7, edges as in example, labels="abaedcd" -> [2,1,1,1,1,1,1]
        int[][] edges1 = {{0,1},{0,2},{1,4},{1,5},{2,3},{2,6}};
        int[] actual = sol.countSubTrees(7, edges1, "abaedcd");
        int[] expected1 = {2,1,1,1,1,1,1};
        for (int i = 0; i < expected1.length; i++)
            if (actual[i] != expected1[i])
                throw new AssertionError("test1[" + i + "]: expected " + expected1[i] + ", got " + actual[i]);

        // n=4, path 0-1-2-3, labels="bbbb" -> [4,3,2,1]
        int[][] edges2 = {{0,1},{1,2},{2,3}};
        actual = sol.countSubTrees(4, edges2, "bbbb");
        int[] expected2 = {4,3,2,1};
        for (int i = 0; i < expected2.length; i++)
            if (actual[i] != expected2[i])
                throw new AssertionError("test2[" + i + "]: expected " + expected2[i] + ", got " + actual[i]);

        System.out.println("LC 1519 all tests passed");
    }
}
```

**Time:** O(26n) = O(n). **Space:** O(n).

> **Java vs Rust:** Rust returns `[i32; 26]` by value (stack-allocated, no heap).
> Java returns `new int[26]` which allocates n heap objects for n nodes. For n = 10^5
> this is ~2.5 MB of short-lived garbage — acceptable. If allocation matters, pass a
> reusable buffer as a parameter instead.

---

## Section 5: Bitmask DP

DP over subsets of a small set (n ≤ 20). State `dp[mask]` encodes some optimum
achieved for exactly the elements whose bits are set in `mask`.

**Key patterns in Java:**
- `Integer.bitCount(mask)` — popcount (maps to hardware POPCNT instruction via JIT).
- Submask iteration: `for (int sub = mask; sub > 0; sub = (sub - 1) & mask)` (also
  process `sub = 0` afterward if needed).
- `1 << i` produces an `int`; use `1L << i` when the mask can exceed 30 bits.
- `Integer.MAX_VALUE / 2` as infinity avoids overflow when adding 1 to a sentinel.

---

### Problem 7 — LC #526: Beautiful Arrangement

**Problem statement:** Count permutations of `1..n` where position `i` (1-indexed)
either divides or is divisible by the number placed there.

**Key insight:** `dp[mask]` = number of valid arrangements using the numbers in
`mask`. The next position to fill is `popcount(mask) + 1`.

**Memoization approach (top-down) — shown for contrast:**

```java
import java.util.*;

class Solution526Memo {
    private int n;
    private int[] memo;

    public int countArrangement(int n) {
        this.n = n;
        this.memo = new int[1 << n];
        Arrays.fill(memo, -1);
        return solve(0);
    }

    private int solve(int mask) {
        if (memo[mask] != -1) return memo[mask];
        int pos = Integer.bitCount(mask) + 1;  // next 1-indexed position to fill
        if (pos > n) return memo[mask] = 1;    // all positions filled
        int count = 0;
        for (int i = 0; i < n; i++) {
            if ((mask & (1 << i)) != 0) continue;
            int num = i + 1;
            if (num % pos == 0 || pos % num == 0)
                count += solve(mask | (1 << i));
        }
        return memo[mask] = count;
    }
}
```

**Tabulation approach (bottom-up) — preferred:**

```java
class Solution526 {
    public int countArrangement(int n) {
        int[] dp = new int[1 << n];
        dp[0] = 1;
        for (int mask = 0; mask < (1 << n); mask++) {
            int pos = Integer.bitCount(mask) + 1;  // next 1-indexed slot
            for (int i = 0; i < n; i++) {
                if ((mask & (1 << i)) != 0) continue;
                int num = i + 1;
                if (num % pos == 0 || pos % num == 0)
                    dp[mask | (1 << i)] += dp[mask];
            }
        }
        return dp[(1 << n) - 1];
    }

    public static void main(String[] args) {
        var sol = new Solution526();

        if (sol.countArrangement(1) != 1) throw new AssertionError("n=1: got " + sol.countArrangement(1));
        if (sol.countArrangement(2) != 2) throw new AssertionError("n=2: got " + sol.countArrangement(2));
        if (sol.countArrangement(3) != 3) throw new AssertionError("n=3: got " + sol.countArrangement(3));
        if (sol.countArrangement(4) != 8) throw new AssertionError("n=4: got " + sol.countArrangement(4));

        System.out.println("LC 526 all tests passed");
    }
}
```

**Time:** O(2^n * n). **Space:** O(2^n).

> **Java vs Rust:** `Integer.bitCount(mask)` is the Java equivalent of Rust's
> `mask.count_ones()` — both emit a single POPCNT instruction via JIT/compiler. Java
> arrays are zero-initialized so `dp[0] = 1` is the only explicit write needed before
> the loop. Rust must write `dp[0] = 1` too since `vec![0; n]` also zero-initializes.

**Approach 3 — Backtracking (no bitmask, for small n):**

When n is very small (≤ 6) or you need to enumerate the actual arrangements, classic backtracking with a `boolean[] used` array suffices. This is O(k^n) worst case but prunes aggressively.

```java
class Solution526BT {
    private int n;
    private boolean[] used;

    public int countArrangement(int n) {
        this.n = n;
        this.used = new boolean[n + 1];
        return bt(1);
    }

    private int bt(int pos) {
        if (pos > n) return 1;
        int count = 0;
        for (int num = 1; num <= n; num++) {
            if (!used[num] && (num % pos == 0 || pos % num == 0)) {
                used[num] = true;
                count += bt(pos + 1);
                used[num] = false;
            }
        }
        return count;
    }

    public static void main(String[] args) {
        var sol = new Solution526BT();
        if (sol.countArrangement(1) != 1) throw new AssertionError();
        if (sol.countArrangement(2) != 2) throw new AssertionError();
        if (sol.countArrangement(3) != 3) throw new AssertionError();
        if (sol.countArrangement(4) != 8) throw new AssertionError();
        System.out.println("LC 526 BT: all tests passed.");
    }
}
```

**When to use which:** Backtracking is simplest to write and easiest to verify. Bitmask DP is necessary for n > 12 or when you need all state counts simultaneously. The memoized top-down approach is a natural bridge between the two.

---

### Problem 8 — LC #1986: Minimum Number of Work Sessions to Finish the Tasks

**Problem statement:** Given task durations and a `sessionTime` limit, return the
minimum number of work sessions to complete all tasks (each task in exactly one session).

**Key insight:** `dp[mask]` stores `(minSessions, maxRemainingTime)`. Minimise
sessions first; on a tie, maximise remaining time in the last session (better packing).

```java
import java.util.*;

class Solution1986 {
    public int minSessions(int[] tasks, int sessionTime) {
        int n = tasks.length;
        int full = (1 << n) - 1;
        // dp[mask] = {sessions, remainingTimeInLastSession}; -1 = unreachable
        int[][] dp = new int[1 << n][2];
        for (int[] row : dp) Arrays.fill(row, -1);
        dp[0][0] = 1;
        dp[0][1] = sessionTime;  // 1 session open, full time available

        for (int mask = 0; mask <= full; mask++) {
            if (dp[mask][0] == -1) continue;
            int sess = dp[mask][0], rem = dp[mask][1];
            for (int i = 0; i < n; i++) {
                if ((mask & (1 << i)) != 0) continue;
                int t = tasks[i];
                int newMask = mask | (1 << i);
                int newSess, newRem;
                if (rem >= t) { newSess = sess;     newRem = rem - t;          }
                else          { newSess = sess + 1; newRem = sessionTime - t;  }
                // prefer fewer sessions; on tie prefer more remaining time
                if (dp[newMask][0] == -1
                        || newSess < dp[newMask][0]
                        || (newSess == dp[newMask][0] && newRem > dp[newMask][1])) {
                    dp[newMask][0] = newSess;
                    dp[newMask][1] = newRem;
                }
            }
        }
        return dp[full][0];
    }

    public static void main(String[] args) {
        var sol = new Solution1986();

        int actual = sol.minSessions(new int[]{1,2,3}, 3);
        if (actual != 2) throw new AssertionError("test1: expected 2, got " + actual);

        actual = sol.minSessions(new int[]{3,1,3,1,1}, 8);
        if (actual != 2) throw new AssertionError("test2: expected 2, got " + actual);

        System.out.println("LC 1986 all tests passed");
    }
}
```

**Time:** O(2^n * n). **Space:** O(2^n).

> **Java vs Rust:** Rust stores the pair as a tuple `(i32, i32)` in the dp Vec,
> which is stack-laid-out in the array. Java uses `int[1<<n][2]`, which is an array
> of `int[]` sub-arrays — one extra heap indirection per row. Using `-1` as the
> unreachable sentinel (instead of `Integer.MAX_VALUE`) avoids the overflow hazard
> when comparing `sess + 1`.

---

### Problem 9 — LC #1494: Parallel Courses II

**Problem statement:** `n` courses with prerequisite dependencies. Each semester
you can take at most `k` courses (prerequisites must be satisfied). Return the minimum
number of semesters to finish all courses.

**Key insight:** `dp[mask]` = min semesters to complete exactly the courses in
`mask`. For each state, compute `canTake` (courses whose prerequisites are all in
`mask`), then try every subset of `canTake` with at most `k` elements.

```java
import java.util.*;

class Solution1494 {
    public int minNumberOfSemesters(int n, int[][] relations, int k) {
        int[] prereq = new int[n];
        for (int[] r : relations) {
            int u = r[0] - 1, v = r[1] - 1;   // convert to 0-indexed
            prereq[v] |= (1 << u);
        }
        int full = (1 << n) - 1;
        int[] dp = new int[1 << n];
        Arrays.fill(dp, Integer.MAX_VALUE / 2);
        dp[0] = 0;

        for (int mask = 0; mask <= full; mask++) {
            if (dp[mask] == Integer.MAX_VALUE / 2) continue;
            // Build canTake: courses not in mask with all prerequisites in mask
            int canTake = 0;
            for (int i = 0; i < n; i++) {
                if ((mask & (1 << i)) == 0 && (prereq[i] & mask) == prereq[i])
                    canTake |= (1 << i);
            }
            // Enumerate all subsets of canTake with popcount <= k
            for (int sub = canTake; sub > 0; sub = (sub - 1) & canTake) {
                if (Integer.bitCount(sub) <= k) {
                    int newMask = mask | sub;
                    dp[newMask] = Math.min(dp[newMask], dp[mask] + 1);
                }
            }
        }
        return dp[full];
    }

    public static void main(String[] args) {
        var sol = new Solution1494();

        // n=4, relations=[[2,1],[3,1],[1,4]], k=2 -> 3
        int actual = sol.minNumberOfSemesters(4,
            new int[][]{{2,1},{3,1},{1,4}}, 2);
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        // n=5, k=2 -> 4
        actual = sol.minNumberOfSemesters(5,
            new int[][]{{2,1},{3,1},{4,1},{1,5}}, 2);
        if (actual != 4) throw new AssertionError("test2: expected 4, got " + actual);

        System.out.println("LC 1494 all tests passed");
    }
}
```

**Time:** O(3^n) — submask enumeration over all masks totals 3^n by identity
Σ C(n,k)·2^k = 3^n. **Space:** O(2^n).

> **Java vs Rust:** `Integer.MAX_VALUE / 2` is used here as infinity so that
> `dp[mask] + 1` does not overflow. The Rust version uses `i32::MAX` as the initial
> sentinel and guards with `if dp[mask] == i32::MAX { continue; }` — both are safe
> if guarded before arithmetic. `Arrays.fill(dp, Integer.MAX_VALUE / 2)` is the Java
> equivalent of `vec![i32::MAX; ...]` followed by explicit guarding.

---

### Problem 10 — LC #2305: Fair Distribution of Cookies

**Problem statement:** Distribute `n` cookie bags among `k` children. Unfairness =
max cookies any child gets. Return the minimum possible unfairness.

**Key insight:** Precompute `ssum[mask]` (total cookies in subset). Then
`dp[j][mask]` = min unfairness distributing exactly `mask` among `j` children.
Submask enumeration splits `mask` into one child's allocation and the remainder.

```java
import java.util.*;

class Solution2305 {
    public int distributeCookies(int[] cookies, int k) {
        int n = cookies.length;
        int full = (1 << n) - 1;

        // Precompute subset sums
        int[] ssum = new int[1 << n];
        for (int mask = 1; mask <= full; mask++) {
            int lsb = Integer.numberOfTrailingZeros(mask); // index of lowest set bit
            ssum[mask] = ssum[mask ^ (1 << lsb)] + cookies[lsb];
        }

        // dp[j][mask] = min unfairness assigning subset mask to j children
        int INF = Integer.MAX_VALUE / 2;
        int[][] dp = new int[k + 1][1 << n];
        for (int[] row : dp) Arrays.fill(row, INF);
        dp[0][0] = 0;

        for (int j = 1; j <= k; j++) {
            for (int mask = 0; mask <= full; mask++) {
                // Enumerate all subsets s of mask (the j-th child gets s)
                for (int sub = mask; sub > 0; sub = (sub - 1) & mask) {
                    if (dp[j-1][mask ^ sub] < INF) {
                        int val = Math.max(dp[j-1][mask ^ sub], ssum[sub]);
                        dp[j][mask] = Math.min(dp[j][mask], val);
                    }
                }
            }
        }
        return dp[k][full];
    }

    public static void main(String[] args) {
        var sol = new Solution2305();

        int actual = sol.distributeCookies(new int[]{8,15,10,20,8}, 2);
        if (actual != 31) throw new AssertionError("test1: expected 31, got " + actual);

        actual = sol.distributeCookies(new int[]{6,1,3,2,2,4,1,2}, 3);
        if (actual != 7) throw new AssertionError("test2: expected 7, got " + actual);

        System.out.println("LC 2305 all tests passed");
    }
}
```

**Time:** O(k * 3^n). **Space:** O(k * 2^n).

> **Java vs Rust:** `Integer.numberOfTrailingZeros(mask)` finds the lowest set bit
> index, equivalent to Rust's `mask.trailing_zeros()`. Both map to a single BSF/TZCNT
> CPU instruction. Rust uses `mask.wrapping_neg()` to compute `-mask` without overflow
> checks; Java does not need this because `int` overflow is defined (wrapping) and
> `Integer.numberOfTrailingZeros` is cleaner anyway.

---

### Problem 11 — LC #847: Shortest Path Visiting All Nodes

**Problem statement:** Undirected graph, find shortest path (in edges) that visits
every node at least once. You may start at any node and revisit nodes.

**Technique:** BFS on state `(currentNode, visitedMask)`. Multi-source: enqueue
all nodes simultaneously at distance 0.

```java
import java.util.*;

class Solution847 {
    public int shortestPathLength(int[][] graph) {
        int n = graph.length;
        int full = (1 << n) - 1;
        int[][] dist = new int[n][1 << n];
        for (int[] row : dist) Arrays.fill(row, Integer.MAX_VALUE);

        // BFS queue: {node, visitedMask}
        Deque<int[]> queue = new ArrayDeque<>();
        for (int i = 0; i < n; i++) {
            dist[i][1 << i] = 0;
            queue.offer(new int[]{i, 1 << i});
        }

        while (!queue.isEmpty()) {
            var cur = queue.poll();
            int node = cur[0], mask = cur[1];
            if (mask == full) return dist[node][mask];
            for (int nb : graph[node]) {
                int newMask = mask | (1 << nb);
                if (dist[nb][newMask] == Integer.MAX_VALUE) {
                    dist[nb][newMask] = dist[node][mask] + 1;
                    queue.offer(new int[]{nb, newMask});
                }
            }
        }
        return 0;  // unreachable (graph is connected by problem constraints)
    }

    public static void main(String[] args) {
        var sol = new Solution847();

        // Star graph: 0-1,0-2,0-3 -> 4
        int actual = sol.shortestPathLength(
            new int[][]{{1,2,3},{0},{0},{0}});
        if (actual != 4) throw new AssertionError("test1: expected 4, got " + actual);

        // 0-1-2, 1-4, 2-3, 2-4 -> 4
        actual = sol.shortestPathLength(
            new int[][]{{1},{0,2,4},{1,3,4},{2},{1,2}});
        if (actual != 4) throw new AssertionError("test2: expected 4, got " + actual);

        // Single node -> 0
        actual = sol.shortestPathLength(new int[][]{{}});
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        System.out.println("LC 847 all tests passed");
    }
}
```

**Time:** O(2^n * n). **Space:** O(2^n * n).

> **Java vs Rust:** `ArrayDeque` serves as both a stack and queue in Java
> (`offer`/`poll` = FIFO = BFS). Rust uses `VecDeque`. The `Integer.MAX_VALUE`
> sentinel is safe here because it is only compared against (never added to), so
> overflow cannot occur. The BFS optimality guarantee means the first time we reach
> `mask == full` is the shortest distance.

---

### Problem 12 — LC #1125: Smallest Sufficient Team

**Problem statement:** Given required skills and a list of people (each knowing some
skills), find the smallest team covering all required skills.

**Key insight:** `dp[mask]` = bitmask of team members (over people) covering skill
set `mask`. Use `long` to support up to 60 people. Minimise `Long.bitCount(dp[mask])`.

```java
import java.util.*;

class Solution1125 {
    public int[] smallestSufficientTeam(String[] reqSkills, List<List<String>> people) {
        int m = reqSkills.length;
        Map<String, Integer> skillIdx = new HashMap<>();
        for (int i = 0; i < m; i++) skillIdx.put(reqSkills[i], i);

        int p = people.size();
        int[] personMask = new int[p];
        for (int i = 0; i < p; i++)
            for (String skill : people.get(i))
                personMask[i] |= (1 << skillIdx.get(skill));

        int full = (1 << m) - 1;
        // dp[mask] = bitmask of people (as long) covering exactly skill mask
        long[] dp = new long[1 << m];
        Arrays.fill(dp, -1L);    // -1 = unreachable
        dp[0] = 0L;

        for (int mask = 0; mask <= full; mask++) {
            if (dp[mask] == -1L) continue;
            for (int j = 0; j < p; j++) {
                int newMask = mask | personMask[j];
                long candidate = dp[mask] | (1L << j);   // 1L << j, not 1 << j!
                if (dp[newMask] == -1L
                        || Long.bitCount(candidate) < Long.bitCount(dp[newMask]))
                    dp[newMask] = candidate;
            }
        }

        long team = dp[full];
        List<Integer> result = new ArrayList<>();
        for (int i = 0; i < p; i++)
            if ((team & (1L << i)) != 0) result.add(i);
        return result.stream().mapToInt(Integer::intValue).toArray();
    }

    public static void main(String[] args) {
        var sol = new Solution1125();

        // req=["java","nodejs","reactjs"], people=[["java"],["nodejs"],["nodejs","reactjs"]]
        // -> person 0 + person 2
        var result = sol.smallestSufficientTeam(
            new String[]{"java","nodejs","reactjs"},
            List.of(List.of("java"), List.of("nodejs"), List.of("nodejs","reactjs")));
        if (result.length != 2 || result[0] != 0 || result[1] != 2)
            throw new AssertionError("test1: expected [0,2], got " + Arrays.toString(result));

        System.out.println("LC 1125 all tests passed");
    }
}
```

**Time:** O(2^m * p) where m = skills ≤ 16, p = people ≤ 60. **Space:** O(2^m).

> **Java vs Rust:** Use `1L << j` (long literal), NOT `1 << j` (int literal).
> With `j` up to 59, `1 << j` silently overflows the `int` type in Java, producing
> wrong results for j ≥ 31. Rust uses `u64` naturally; the same pitfall exists if
> you write `1u32 << j` instead of `1u64 << j`. `Long.bitCount` is the Java equivalent
> of Rust's `u64::count_ones()` — both are O(1) hardware instructions.

---

### Problem 13 — LC #1434: Number of Ways to Wear Different Hats to Each Person

**Problem statement:** `n` people (n ≤ 10) and 40 hats. Each person has a preference
list. Count ways to assign each person a distinct hat they like. Return result mod 10^9+7.

**Key insight:** Iterate hats (outer). `dp[mask]` = ways to assign hats so far to
exactly the people in `mask`. Clone `dp` before each hat to ensure each hat is used
at most once (0-1 knapsack style).

```java
import java.util.*;

class Solution1434 {
    private static final int MOD = 1_000_000_007;

    public int numberWays(List<List<Integer>> hats) {
        int n = hats.size();
        int full = (1 << n) - 1;

        // Invert: hat -> list of people who like it
        List<Integer>[] hatToPeople = new ArrayList[41];
        for (int h = 0; h <= 40; h++) hatToPeople[h] = new ArrayList<>();
        for (int person = 0; person < n; person++)
            for (int hat : hats.get(person))
                hatToPeople[hat].add(person);

        long[] dp = new long[1 << n];
        dp[0] = 1L;

        for (int h = 1; h <= 40; h++) {
            if (hatToPeople[h].isEmpty()) continue;
            long[] prev = dp.clone();  // snapshot: hat h used at most once
            for (int mask = 0; mask <= full; mask++) {
                for (int person : hatToPeople[h]) {
                    if ((mask & (1 << person)) != 0) {
                        int prevMask = mask ^ (1 << person);
                        dp[mask] = (dp[mask] + prev[prevMask]) % MOD;
                    }
                }
            }
        }
        return (int) dp[full];
    }

    public static void main(String[] args) {
        var sol = new Solution1434();

        // 3 people: [3,4],[4,5],[5] -> only hat combo (3,4,5) -> 1
        int actual = sol.numberWays(List.of(
            List.of(3, 4), List.of(4, 5), List.of(5)));
        if (actual != 1) throw new AssertionError("test1: expected 1, got " + actual);

        // 2 people: [1,2],[1,2] -> (hat1,hat2) or (hat2,hat1) -> 2
        actual = sol.numberWays(List.of(List.of(1,2), List.of(1,2)));
        if (actual != 2) throw new AssertionError("test2: expected 2, got " + actual);

        // 3 people each with 1 unique hat -> 1
        actual = sol.numberWays(List.of(List.of(1), List.of(2), List.of(3)));
        if (actual != 1) throw new AssertionError("test3: expected 1, got " + actual);

        System.out.println("LC 1434 all tests passed");
    }
}
```

**Time:** O(40 * 2^n * n). **Space:** O(2^n) (n ≤ 10 so 2^10 = 1024 states).

> **Java vs Rust:** `dp.clone()` in Java is O(2^n) — a shallow array copy, fast.
> Rust's `dp.clone()` on a `Vec<u64>` is identical behaviour. The clone-then-read
> pattern enforces "use each hat at most once" without a separate dimension in the
> DP table. Java arrays are zero-initialized, so `dp[0] = 1L` is the only needed
> initialization; no `Arrays.fill` required for the rest.

---

### Problem 14 — LC #943: Find the Shortest Superstring (TSP Variant)

**Problem statement:** Find the shortest string containing each word as a substring.
Return any valid shortest superstring. Equivalent to shortest common superstring (TSP).

**Key insight:** Precompute `overlap[i][j]` = chars of `words[j]` skippable when
`words[i]` immediately precedes it. Maximize total overlap via DP, then reconstruct.

```java
import java.util.*;

class Solution943 {
    public String shortestSuperstring(String[] words) {
        int n = words.length;

        // Precompute pairwise overlaps
        int[][] ov = new int[n][n];
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++) {
                if (i == j) continue;
                String a = words[i], b = words[j];
                int maxLen = Math.min(a.length(), b.length());
                for (int k = maxLen; k >= 1; k--) {
                    if (a.endsWith(b.substring(0, k))) { ov[i][j] = k; break; }
                }
            }

        int full = (1 << n) - 1;
        // dp[mask][last] = max overlap; -1 = state not reachable
        int[][] dp  = new int[1 << n][n];
        int[][] par = new int[1 << n][n];
        for (int[] row : dp)  Arrays.fill(row, -1);
        for (int[] row : par) Arrays.fill(row, -1);
        for (int i = 0; i < n; i++) dp[1 << i][i] = 0;

        for (int mask = 1; mask <= full; mask++) {
            for (int last = 0; last < n; last++) {
                if (dp[mask][last] < 0) continue;
                if ((mask & (1 << last)) == 0) continue;
                for (int next = 0; next < n; next++) {
                    if ((mask & (1 << next)) != 0) continue;
                    int newMask = mask | (1 << next);
                    int val = dp[mask][last] + ov[last][next];
                    if (val > dp[newMask][next]) {
                        dp[newMask][next] = val;
                        par[newMask][next] = last;
                    }
                }
            }
        }

        // Find best ending word
        int bestLast = 0;
        for (int i = 1; i < n; i++)
            if (dp[full][i] > dp[full][bestLast]) bestLast = i;

        // Reconstruct order
        int[] order = new int[n];
        int idx = n - 1, mask = full, cur = bestLast;
        while (cur != -1) {
            order[idx--] = cur;
            int prev = par[mask][cur];
            mask ^= (1 << cur);
            cur = prev;
        }

        // Build superstring
        StringBuilder sb = new StringBuilder(words[order[0]]);
        for (int i = 1; i < n; i++)
            sb.append(words[order[i]].substring(ov[order[i-1]][order[i]]));
        return sb.toString();
    }

    public static void main(String[] args) {
        var sol = new Solution943();

        // ["alex","loves","leetcode"] -> no overlaps -> length 17
        String result = sol.shortestSuperstring(new String[]{"alex","loves","leetcode"});
        for (String w : new String[]{"alex","loves","leetcode"})
            if (!result.contains(w))
                throw new AssertionError("test1: '" + w + "' not in result '" + result + "'");
        if (result.length() != 17)
            throw new AssertionError("test1: expected length 17, got " + result.length() + " ('" + result + "')");

        // ["catg","ctaagt","gcta","ttca","atgcatc"] -> length 16
        result = sol.shortestSuperstring(new String[]{"catg","ctaagt","gcta","ttca","atgcatc"});
        for (String w : new String[]{"catg","ctaagt","gcta","ttca","atgcatc"})
            if (!result.contains(w))
                throw new AssertionError("test2: '" + w + "' not in result '" + result + "'");
        if (result.length() != 16)
            throw new AssertionError("test2: expected length 16, got " + result.length() + " ('" + result + "')");

        System.out.println("LC 943 all tests passed");
    }
}
```

**Time:** O(n^2 * 2^n). **Space:** O(n * 2^n).

> **Java vs Rust:** `String.endsWith(prefix)` is idiomatic Java for overlap detection.
> Rust slices directly: `a[a.len()-k..] == b[..k]`. `StringBuilder` avoids O(n^2)
> string concatenation. Using `-1` as sentinel (not `Integer.MIN_VALUE`) keeps
> comparisons simple and avoids overflow when computing `dp[mask][last] + ov[...]`.

---

## Section 6: State Machine DP

DP where the state includes an explicit **mode** or **phase**. Draw the state diagram
first — each arrow is a recurrence transition. Stock trading problems are canonical.

**Java pattern:** Name variables to match the state machine labels. Snapshot previous
values before updating (or update in the correct order) to prevent same-day pollution.

---

### Problem 15 — LC #309: Best Time to Buy and Sell Stock with Cooldown

**Problem statement:** After selling, you must wait one day (cooldown) before buying
again. Return the maximum profit.

**State machine:**

```
held  = holding stock       (can sell → sold)
sold  = just sold today     (must rest tomorrow)
rest  = not holding, cooled (can buy → held, or stay → rest)

held' = max(held, rest - price)
sold' = held + price
rest' = max(rest, sold)
```

```java
class Solution309 {
    public int maxProfit(int[] prices) {
        if (prices.length < 2) return 0;
        int held = -prices[0], sold = Integer.MIN_VALUE / 2, rest = 0;
        for (int i = 1; i < prices.length; i++) {
            int ph = held, ps = sold, pr = rest;
            held = Math.max(ph, pr - prices[i]);  // keep holding OR buy from rest
            sold = ph + prices[i];                 // sell what we hold
            rest = Math.max(pr, ps);               // idle OR come off cooldown
        }
        return Math.max(sold, rest);
    }

    public static void main(String[] args) {
        var sol = new Solution309();

        int actual = sol.maxProfit(new int[]{1,2,3,0,2});
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        actual = sol.maxProfit(new int[]{1});
        if (actual != 0) throw new AssertionError("test2: expected 0, got " + actual);

        actual = sol.maxProfit(new int[]{2,1,4});
        if (actual != 3) throw new AssertionError("test3: expected 3, got " + actual);

        System.out.println("LC 309 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(1).

> **Java vs Rust:** `Integer.MIN_VALUE / 2` is used for `sold`'s initial value so
> that `ph + prices[i]` on day 0 (when `ph = Integer.MIN_VALUE / 2`) does not
> overflow. Rust uses `i32::MIN` directly but applies `.max(...)` safely because
> Rust detects overflow in debug builds. In Java, integer overflow is silent, so
> use `Integer.MIN_VALUE / 2` whenever a value participates in addition before being
> assigned to a meaningful state.

---

### Problem 16 — LC #188: Best Time to Buy and Sell Stock IV

**Problem statement:** At most `k` transactions (1 buy + 1 sell = 1 transaction).
Return max profit.

**Key insight:** `buy[j]` = max profit after the j-th buy (holding). `sell[j]` =
max profit after the j-th sell (not holding). Iterate `j` in reverse to avoid
using the same price twice within one day.

```java
import java.util.*;

class Solution188 {
    public int maxProfit(int k, int[] prices) {
        int n = prices.length;
        if (n == 0 || k == 0) return 0;
        // If k is large enough, unlimited transactions
        if (k >= n / 2) {
            int profit = 0;
            for (int i = 1; i < n; i++) profit += Math.max(0, prices[i] - prices[i-1]);
            return profit;
        }
        int[] buy  = new int[k + 1];
        int[] sell = new int[k + 1];
        Arrays.fill(buy, Integer.MIN_VALUE / 2);
        // sell is already 0 (zero-initialized)

        for (int price : prices) {
            for (int j = k; j >= 1; j--) {
                sell[j] = Math.max(sell[j], buy[j]  + price);
                buy[j]  = Math.max(buy[j],  sell[j-1] - price);
            }
        }
        return sell[k];
    }

    public static void main(String[] args) {
        var sol = new Solution188();

        int actual = sol.maxProfit(2, new int[]{2,4,1});
        if (actual != 2) throw new AssertionError("test1: expected 2, got " + actual);

        actual = sol.maxProfit(2, new int[]{3,2,6,5,0,3});
        if (actual != 7) throw new AssertionError("test2: expected 7, got " + actual);

        actual = sol.maxProfit(0, new int[]{1,2,3});
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        actual = sol.maxProfit(1, new int[]{1,2});
        if (actual != 1) throw new AssertionError("test4: expected 1, got " + actual);

        System.out.println("LC 188 all tests passed");
    }
}
```

**Time:** O(n * k). **Space:** O(k).

> **Java vs Rust:** Java arrays are zero-initialized, so `sell` is correct without
> `Arrays.fill`. `buy` needs `Arrays.fill(buy, Integer.MIN_VALUE / 2)` because
> buying before any price must start at "negative infinity" — we haven't bought yet
> so the profit is unknown. Rust's `vec![i32::MIN; k+1]` expresses the same intent
> but the value is used only in `max(...)` comparisons before addition, so half-max
> is safer in Java. The `.rev()` inner loop in Rust maps to the `j` from `k` down
> to `1` loop in Java — prevents using the same price for both buy and sell in one
> iteration.

---

### Problem 17 — LC #123: Best Time to Buy and Sell Stock III

**Problem statement:** At most 2 transactions. Return max profit. Special case of
LC #188 with k=2, implemented with 4 scalar variables for clarity.

**State machine (4 named states):**

```
buy1  = max(buy1,        -price)
sell1 = max(sell1, buy1 + price)
buy2  = max(buy2,  sell1 - price)
sell2 = max(sell2, buy2 + price)
```

The sequential update order is intentional: `buy1` feeding `sell1` on the same day
yields zero profit for same-day round-trip (allowed by the problem).

```java
class Solution123 {
    public int maxProfit(int[] prices) {
        int buy1 = Integer.MIN_VALUE / 2, sell1 = 0;
        int buy2 = Integer.MIN_VALUE / 2, sell2 = 0;
        for (int price : prices) {
            buy1  = Math.max(buy1,  -price);
            sell1 = Math.max(sell1, buy1  + price);
            buy2  = Math.max(buy2,  sell1 - price);
            sell2 = Math.max(sell2, buy2  + price);
        }
        return sell2;
    }

    public static void main(String[] args) {
        var sol = new Solution123();

        int actual = sol.maxProfit(new int[]{3,3,5,0,0,3,1,4});
        if (actual != 6) throw new AssertionError("test1: expected 6, got " + actual);

        actual = sol.maxProfit(new int[]{1,2,3,4,5});
        if (actual != 4) throw new AssertionError("test2: expected 4, got " + actual);

        actual = sol.maxProfit(new int[]{7,6,4,3,1});
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        actual = sol.maxProfit(new int[]{1});
        if (actual != 0) throw new AssertionError("test4: expected 0, got " + actual);

        System.out.println("LC 123 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(1).

> **Java vs Rust:** No arrays needed — 4 scalars suffice. `Integer.MIN_VALUE / 2`
> for initial `buy1`/`buy2` prevents overflow when adding `price` to them on the
> first valid day. In Rust, `i32::MIN` works because the first operation is always
> `max(i32::MIN, -price)` which never triggers overflow. Java integer overflow is
> silent, making `Integer.MIN_VALUE / 2` the safer habit.

---

### Problem 18 — LC #1911: Maximum Alternating Subsequence Sum

**Problem statement:** An alternating subsequence alternates addition and subtraction
of selected elements (first element added, next subtracted, ...). Return maximum sum.

**State machine:**

```
even = max profit about to pick an even-indexed element (add it next)
odd  = max profit about to pick an odd-indexed element  (subtract it next)

For each x:
    newEven = max(even, odd + x)   // skip x OR add x after an odd pick
    newOdd  = max(odd,  even - x)  // skip x OR subtract x after an even pick
```

Return `even` — the best scenario where the last picked element was added.

```java
class Solution1911 {
    public long maxAlternatingSum(int[] nums) {
        long even = 0, odd = 0;
        for (int x : nums) {
            long newEven = Math.max(even, odd + x);
            long newOdd  = Math.max(odd,  even - x);
            even = newEven;
            odd  = newOdd;
        }
        return even;
    }

    public static void main(String[] args) {
        var sol = new Solution1911();

        long actual = sol.maxAlternatingSum(new int[]{4,2,5,3});
        if (actual != 7) throw new AssertionError("test1: expected 7, got " + actual);

        actual = sol.maxAlternatingSum(new int[]{5,6,7,8});
        if (actual != 8) throw new AssertionError("test2: expected 8, got " + actual);

        actual = sol.maxAlternatingSum(new int[]{6,2,1,2,4,5});
        if (actual != 10) throw new AssertionError("test3: expected 10, got " + actual);

        System.out.println("LC 1911 all tests passed");
    }
}
```

**Time:** O(n). **Space:** O(1).

> **Java vs Rust:** Return type is `long` / `i64` — the LeetCode signature requires
> this because sums can reach up to 10^5 * 10^5 = 10^10, which overflows `int`/`i32`.
> Snapshot `newEven` and `newOdd` before assigning back to `even`/`odd` — exactly
> the same as Rust's `let (ne, no) = (...)` pattern. Java `long` arithmetic uses no
> boxing.

---

### Problem 19 — LC #2826: Sorting Three Groups

**Problem statement:** Array with values only in `{1, 2, 3}`. Find the minimum
number of elements to **delete** so the remaining array is non-decreasing.

Equivalently: `n − LIS_length` where LIS is the longest non-decreasing subsequence
over values in `{1, 2, 3}`.

**State machine:** `dp[v]` = length of longest non-decreasing subsequence ending
with value `v`. Only 3 states; inner loop is constant time.

```java
class Solution2826 {
    public int minimumOperations(int[] nums) {
        int[] dp = new int[4];  // dp[1], dp[2], dp[3]; index 0 unused
        for (int x : nums) {
            // best LIS length we can extend to reach value x
            int best = 0;
            for (int v = 1; v <= x; v++) best = Math.max(best, dp[v]);
            dp[x] = Math.max(dp[x], best + 1);
        }
        return nums.length - Math.max(dp[1], Math.max(dp[2], dp[3]));
    }

    public static void main(String[] args) {
        var sol = new Solution2826();

        int actual = sol.minimumOperations(new int[]{2,1,3,2,1});
        if (actual != 3) throw new AssertionError("test1: expected 3, got " + actual);

        actual = sol.minimumOperations(new int[]{1,3,2,1,3,3});
        if (actual != 2) throw new AssertionError("test2: expected 2, got " + actual);

        actual = sol.minimumOperations(new int[]{2,2,2,2,3,3});
        if (actual != 0) throw new AssertionError("test3: expected 0, got " + actual);

        System.out.println("LC 2826 all tests passed");
    }
}
```

**Time:** O(n) (inner loop at most 3 steps). **Space:** O(1).

> **Java vs Rust:** `int[] dp = new int[4]` is zero-initialized — no `Arrays.fill`
> needed. Rust's `let mut dp = [0i32; 4]` is also zero-initialized. The `for v in
> 1..=x` in Rust maps to `for (int v = 1; v <= x; v++)` in Java. Both are bounded
> by 3, making this O(1) per element despite the nested loop appearance.

---

## Summary Table

| # | Problem | Pattern | Time | Space |
|---|---------|---------|------|-------|
| 337 | House Robber III | Rob/skip post-order | O(n) | O(h) |
| 968 | Binary Tree Cameras | 3-state post-order | O(n) | O(h) |
| 124 | Max Path Sum | Arm contribution | O(n) | O(h) |
| 1372 | Longest ZigZag | Directional DFS | O(n) | O(h) |
| 2246 | Longest Path Diff Adj | Top-2 child arms | O(n) | O(n) |
| 1519 | Subtree Same Label | Count[26] aggregation | O(26n) | O(n) |
| 526 | Beautiful Arrangement | Build mask forward | O(2^n·n) | O(2^n) |
| 1986 | Min Work Sessions | (sessions, rem) pair | O(2^n·n) | O(2^n) |
| 1494 | Parallel Courses II | Submask prereq check | O(3^n) | O(2^n) |
| 2305 | Fair Cookies | k-round submask | O(k·3^n) | O(k·2^n) |
| 847 | Visit All Nodes | Multi-source BFS | O(2^n·n) | O(2^n·n) |
| 1125 | Sufficient Team | long team encoding | O(2^m·p) | O(2^m) |
| 1434 | Hats to People | Hat-outer, clone prev | O(40·2^n·n) | O(2^n) |
| 943 | Shortest Superstring | Forward build + recon | O(n^2·2^n) | O(n·2^n) |
| 309 | Stock Cooldown | held/sold/rest | O(n) | O(1) |
| 188 | Stock k Transactions | buy[k]/sell[k] | O(nk) | O(k) |
| 123 | Stock 2 Transactions | 4 scalars | O(n) | O(1) |
| 1911 | Alternating Subseq Sum | even/odd states | O(n) | O(1) |
| 2826 | Sorting Three Groups | LIS on {1,2,3} | O(n) | O(1) |

---

## Key Java Patterns This Chapter

### Tree DP: return pair as int[2]

```java
private int[] dfs(TreeNode node) {
    if (node == null) return new int[]{0, 0};
    var left  = dfs(node.left);
    var right = dfs(node.right);
    int robThis  = node.val + left[1] + right[1];
    int skipThis = Math.max(left[0], left[1]) + Math.max(right[0], right[1]);
    return new int[]{robThis, skipThis};
}
```

### Bitmask: iterate all subsets of a mask

```java
for (int sub = mask; sub > 0; sub = (sub - 1) & mask) {
    // process sub as a subset of mask
}
// process sub == 0 here if needed
```

### State Machine: snapshot before updating

```java
int ph = held, ps = sold, pr = rest;  // snapshot
held = Math.max(ph, pr - price);
sold = ph + price;
rest = Math.max(pr, ps);
```

### Bitmask DP 0-1 knapsack (each item used at most once)

```java
long[] prev = dp.clone();  // snapshot at start of each item
for (int mask = 0; mask <= full; mask++) {
    for (int person : itemUsers) {
        if ((mask & (1 << person)) != 0) {
            dp[mask] = (dp[mask] + prev[mask ^ (1 << person)]) % MOD;
        }
    }
}
```

### Mutable accumulator in tree DFS

```java
// Option A: instance field (reset at method entry)
private int ans;

// Option B: single-element array (lambda/anonymous-class compatible)
int[] ans = {0};
dfs(root, ans);
```

---

## 📝 Chapter Review Notes

### Issue Tracker

| Issue | Severity | Fix Applied |
|-------|----------|-------------|
| `1 << j` (int) overflows for j ≥ 31 in LC #1125 team bitmask | High | Changed to `1L << j` throughout #1125 |
| `Integer.MIN_VALUE + price` overflows silently in state machine init (LC #309, #188, #123) | High | Used `Integer.MIN_VALUE / 2` for all buy/held initial values that participate in addition |
| `assert` keyword used instead of `AssertionError` throw | High | Never used `assert`; all checks use `throw new AssertionError("msg: got " + actual)` |
| LC #943 test checking string equality (multiple valid answers exist) | Medium | Tests check `result.contains(word)` + `result.length() == expected_len`, matching Rust chapter approach |
| `dp[newMask] > dp[mask] + 1` can overflow when `dp[newMask] = Integer.MAX_VALUE` | Medium | Used `Integer.MAX_VALUE / 2` as sentinel in LC #1494 with `Arrays.fill` |
| `cameras` instance field not reset between test calls in LC #968 | Medium | Added `cameras = 0` at top of `minCameraCover` method |
| LC #1986 sentinel: `Integer.MAX_VALUE` in `int[][]` could leak into addition | Low | Used `-1` as the unreachable sentinel and guarded before arithmetic |
| Missing base case test for single-node tree in LC #124 | Low | Added `new TreeNode(-3)` test verifying output = -3 |

### Third-Party Critical Review

**DP array sizes:** All arrays are sized `1 << n` (2^n states) or `(k+1) × (1<<n)`.
For n ≤ 15 this stays under 32K entries; for n = 20 (LC #1494, #1125) the 2^20 = 1M
entry array is ~4 MB — within LeetCode's memory limit. The `dist[n][1<<n]` in LC #847
is `n × 2^n` entries; at n = 12, that is 12 × 4096 = 49K entries, fine.

**Base cases:** LC #337 `null → new int[]{0,0}` is correct. LC #968 `null → 2`
(covered) is correct. LC #124 `null → 0` with arm-clamping `Math.max(0, ...)` is
correct. LC #526 `dp[0] = 1` (empty mask = 1 arrangement) is correct. LC #1434
`dp[0] = 1L` (empty assignment = 1 way) is correct. LC #309 initial `sold =
Integer.MIN_VALUE / 2` correctly represents "have never sold" so `rest = max(rest,
sold)` on day 0 stays 0.

**Transition formulas:** LC #337 verified: `robThis = val + left[1] + right[1]`,
`skipThis = max(left) + max(right)` — correct. LC #968 three-state logic matches
Rust chapter exactly. LC #526 `pos = Integer.bitCount(mask) + 1` matches the
1-indexed position logic. LC #1494 `canTake` correctly filters courses whose
prerequisite bitmask is fully contained in `mask` via `(prereq[i] & mask) == prereq[i]`.
LC #2305 `dp[j][mask ^ sub]` indexes the remainder after giving child `j` the
subset `sub` — matches Rust.

**No `assert` keyword:** Verified — every test assertion in this file uses
`throw new AssertionError(...)`.

**Test assertions catch wrong answers:** Every test compares against exact expected
values. LC #943 additionally verifies that every input word is a substring of the
output. LC #1519 verifies every element of the output array. LC #1125 verifies both
length and indices. The single-node negative tree test in LC #124 specifically catches
the bug of returning 0 instead of -3.

### What This Chapter Does Well

- **Safety around overflow:** Consistent use of `Integer.MIN_VALUE / 2` as the
  initial "negative infinity" for buy/held states. This eliminates a whole class of
  silent overflow bugs that plague Java DP implementations.
- **1L << j in #1125:** The `long` team bitmask is explicitly flagged in both code
  and the Java-vs-Rust callout, preventing a common 32-bit overflow mistake.
- **Instance field reset:** LC #968 resets `cameras = 0` at method entry, making the
  solution safe for multiple test calls on the same instance.
- **Memoization vs tabulation contrast (#526):** Showing both approaches side-by-side
  illustrates when top-down is more intuitive and when bottom-up is cleaner.
- **Sentinel choice in #1986:** Using `-1` instead of `Integer.MAX_VALUE` for the
  unreachable state avoids any possibility of overflow in the comparison logic.

### What Could Be Improved

- **General-tree problems (#2246, #1519) allocate a new array per DFS call** (`new
  int[26]`, `new ArrayList[n]`). A production implementation could pass a reusable
  buffer to reduce GC pressure for large inputs (n = 10^5).
- **LC #943 overlap precomputation** uses `String.endsWith()` in a triple-nested loop.
  For large inputs this is O(n^2 * L^2) preprocessing; KMP or Z-function would reduce
  it to O(n^2 * L). Acceptable for n ≤ 12 (LeetCode constraint) but worth noting.
- **LC #847 dist initialization** uses `Arrays.fill` per row in a loop. A single
  `int[][] dist = new int[n][1 << n]` with a manual loop is already what Java does —
  the fill could be skipped by using a `visited` boolean array instead, halving memory.
- **Switch expressions** (Java 17+) were not used because none of the 19 problems
  had a branching structure where a switch expression would be materially cleaner
  than `Math.max` chains or `if/else` — forcing a switch for LC #968's 3-state or
  LC #2826's 3-value `{1,2,3}` would add verbosity, not reduce it.
