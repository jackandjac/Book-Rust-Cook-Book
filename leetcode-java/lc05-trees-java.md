# LC-05: Trees — Binary Trees & BST (Java)

> **Companion chapter philosophy:** Every problem has a complete, runnable solution with a `main` test driver. All code targets Java 17+. Solutions use `class Solution { public ... }` — the LeetCode submission style. Tests use `throw new AssertionError(...)` — never the `assert` keyword (disabled at runtime without `-ea`) and never JUnit.

> **Java vs Rust — the ownership contrast:** In Java, `TreeNode` is a plain object with two nullable fields. Null *is* a valid child reference. You hand off a reference and keep using it — the garbage collector handles lifetime. In Rust, absent children are `Option<Rc<RefCell<TreeNode>>>`. Every field read requires `.borrow()`; every write requires `.borrow_mut()`; every child passed to a recursive call must be `.clone()`d first (bumping the reference count). The result is that a Java tree solution maps to roughly 3× more Rust characters — none of which changes the algorithm, all of which serve the ownership system. This chapter is where that contrast is most visible.

---

## Shared Helpers Reference

Every solution class in this chapter is **self-contained**: each embeds its own `TreeNode` inner class and the `buildTree` / `toLevelOrder` / `isSameTree` static helpers. This means you can copy any single Java block and compile it independently with `javac --release 17`.

The four helpers embedded in each class are:

- **`static class TreeNode`** — plain node with `val`, `left`, `right`.
- **`static TreeNode buildTree(Integer[] vals)`** — BFS-order level-array constructor (nulls for absent nodes).
- **`static List<Integer> toLevelOrder(TreeNode root)`** — BFS serializer with trailing-null stripping (used in test assertions).
- **`static boolean isSameTree(TreeNode p, TreeNode q)`** — structural equality (included only in classes whose `main` calls it directly; LC #100 and LC #572 omit it because those classes define their own `isSameTree` as an instance method).

> **Java vs Rust:** In Rust `buildTree` must wrap each created node in `Rc::new(RefCell::new(...))` and maintain a `VecDeque<Rc<RefCell<TreeNode>>>`. In Java the same function is plain Java — `new TreeNode(val)` and `ArrayDeque<TreeNode>`. There is no borrow counting, no interior-mutability ceremony.

---

## Problem 1 — Invert Binary Tree (LC #226)

**Difficulty:** Easy | **Pattern:** DFS postorder

### Problem Statement

Given the root of a binary tree, invert it (mirror it left-to-right) and return the root.

```
Input:  [4, 2, 7, 1, 3, 6, 9]
Output: [4, 7, 2, 9, 6, 3, 1]
```

### Key Insight

Recurse into both subtrees first (postorder), then swap the two child references of the current node. The swap is a single three-line temp swap — no auxiliary data structure needed.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    static List<Integer> toLevelOrder(TreeNode root) {
        List<Integer> res = new ArrayList<>();
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        while (!q.isEmpty()) {
            TreeNode n = q.poll();
            if (n == null) { res.add(null); }
            else { res.add(n.val); q.offer(n.left); q.offer(n.right); }
        }
        while (!res.isEmpty() && res.get(res.size()-1) == null) res.remove(res.size()-1);
        return res;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public TreeNode invertTree(TreeNode root) {
        if (root == null) return null;
        TreeNode left  = invertTree(root.left);
        TreeNode right = invertTree(root.right);
        root.left  = right;
        root.right = left;
        return root;
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // full tree: [4,2,7,1,3,6,9] → [4,7,2,9,6,3,1]
        TreeNode t1  = buildTree(new Integer[]{4, 2, 7, 1, 3, 6, 9});
        var got1     = toLevelOrder(s.invertTree(t1));
        var expected1 = Arrays.asList(4, 7, 2, 9, 6, 3, 1);
        if (!got1.equals(expected1))
            throw new AssertionError("invert full: expected " + expected1 + " got " + got1);

        // single node
        TreeNode t2 = buildTree(new Integer[]{1});
        var got2 = toLevelOrder(s.invertTree(t2));
        if (!got2.equals(Arrays.asList(1)))
            throw new AssertionError("invert single: got " + got2);

        // empty tree
        if (s.invertTree(null) != null)
            throw new AssertionError("invert empty: expected null");

        System.out.println("LC#226 Invert Binary Tree: all tests passed");
    }
}
```

**Complexity:** Time O(n) — visits every node once. Space O(h) — recursion stack depth equals tree height.

**Java notes:** The postorder pattern "recurse first, then use results" makes the swap clean: by the time `root.left = right` executes, both subtrees are already fully inverted. Java's nullable references make the base case a one-liner; Rust needs a full `match` on `Option`.

---

## Problem 2 — Maximum Depth of Binary Tree (LC #104)

**Difficulty:** Easy | **Pattern:** DFS, returns value bottom-up

### Problem Statement

Given the root of a binary tree, return its maximum depth: the number of nodes along the longest path from the root down to the farthest leaf. The empty tree has depth 0; a single-node tree has depth 1. Constraints: the number of nodes is in `[0, 10^4]` and node values are in `[-100, 100]`.

### Key Insight

The depth of a node is `1 + max(depth(left), depth(right))`. A null node contributes depth 0.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    static List<Integer> toLevelOrder(TreeNode root) {
        List<Integer> res = new ArrayList<>();
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        while (!q.isEmpty()) {
            TreeNode n = q.poll();
            if (n == null) { res.add(null); }
            else { res.add(n.val); q.offer(n.left); q.offer(n.right); }
        }
        while (!res.isEmpty() && res.get(res.size()-1) == null) res.remove(res.size()-1);
        return res;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public int maxDepth(TreeNode root) {
        if (root == null) return 0;
        return 1 + Math.max(maxDepth(root.left), maxDepth(root.right));
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // [3, 9, 20, null, null, 15, 7] → depth 3
        TreeNode t1 = buildTree(new Integer[]{3, 9, 20, null, null, 15, 7});
        int got1 = s.maxDepth(t1);
        if (got1 != 3)
            throw new AssertionError("maxDepth balanced: expected 3 got " + got1);

        // [1, 2] (left-skewed) → depth 2
        TreeNode t2 = buildTree(new Integer[]{1, 2});
        int got2 = s.maxDepth(t2);
        if (got2 != 2)
            throw new AssertionError("maxDepth left-skewed: expected 2 got " + got2);

        // empty
        if (s.maxDepth(null) != 0)
            throw new AssertionError("maxDepth empty: expected 0");

        System.out.println("LC#104 Maximum Depth: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** The entire algorithm is one line: `1 + Math.max(...)`. Rust's `match` on `Option` adds a structural wrapper, but the logic is identical. Java's `null` is conceptually `None`; `Math.max` maps to `.max()` on integers.

**Approach 2 — Iterative BFS (O(n) time, O(n) space).** Count the number of levels in a BFS traversal. Each level popped off the queue increments the depth. This avoids recursion entirely and is safe for very deep trees (no stack overflow risk). Space is O(w) where w is the maximum level width — O(n) for a complete tree.

```java
import java.util.*;

class Solution2 {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public int maxDepth(TreeNode root) {
        if (root == null) return 0;
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        int depth = 0;
        while (!q.isEmpty()) {
            int levelSize = q.size();
            depth++;
            for (int i = 0; i < levelSize; i++) {
                TreeNode node = q.poll();
                if (node.left  != null) q.offer(node.left);
                if (node.right != null) q.offer(node.right);
            }
        }
        return depth;
    }

    public static void main(String[] args) {
        var s = new Solution2();

        // [3,9,20,null,null,15,7] → depth 3
        if (s.maxDepth(buildTree(new Integer[]{3, 9, 20, null, null, 15, 7})) != 3)
            throw new AssertionError("BFS maxDepth: expected 3");

        if (s.maxDepth(buildTree(new Integer[]{1, 2})) != 2)
            throw new AssertionError("BFS left-skewed: expected 2");

        if (s.maxDepth(null) != 0)
            throw new AssertionError("BFS empty: expected 0");

        System.out.println("LC#104 Approach 2 (BFS): all tests passed");
    }
}
```

> **Java vs Rust:** The BFS approach maps cleanly to Java's `ArrayDeque`. In Rust, the BFS approach requires `VecDeque<Rc<RefCell<TreeNode>>>` and `.clone()` on each child — adding several lines of boilerplate that don't change the algorithm. For this problem the recursive DFS approach is idiomatic in both languages; BFS is shown here as a stack-overflow-safe alternative.

---

## Problem 3 — Diameter of Binary Tree (LC #543)

**Difficulty:** Easy | **Pattern:** DFS with instance-field accumulator

### Problem Statement

Return the length of the longest path between any two nodes in a binary tree. The path does not need to pass through the root.

### Key Insight

At each node, the longest path *through* that node has length `depth(left) + depth(right)`. A DFS helper computes depth while updating a running maximum as a side effect.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    private int maxDiameter = 0;    // accumulator — equivalent to &mut i32 in Rust

    public int diameterOfBinaryTree(TreeNode root) {
        maxDiameter = 0;            // reset for repeated calls in tests
        depth(root);
        return maxDiameter;
    }

    private int depth(TreeNode node) {
        if (node == null) return 0;
        int ld = depth(node.left);
        int rd = depth(node.right);
        maxDiameter = Math.max(maxDiameter, ld + rd);
        return 1 + Math.max(ld, rd);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // [1,2,3,4,5] → diameter 3 (path 4-2-1-3 or 5-2-1-3)
        TreeNode t1 = buildTree(new Integer[]{1, 2, 3, 4, 5});
        int got1 = s.diameterOfBinaryTree(t1);
        if (got1 != 3)
            throw new AssertionError("diameter basic: expected 3 got " + got1);

        // single node → 0
        if (s.diameterOfBinaryTree(buildTree(new Integer[]{1})) != 0)
            throw new AssertionError("diameter single: expected 0");

        // left chain 1→2→3 → diameter 2
        TreeNode t3 = buildTree(new Integer[]{1, 2, null, 3});
        int got3 = s.diameterOfBinaryTree(t3);
        if (got3 != 2)
            throw new AssertionError("diameter left-chain: expected 2 got " + got3);

        System.out.println("LC#543 Diameter: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** `private int maxDiameter` is cleaner than Rust's `&mut i32` threaded through recursive calls. Java instance fields are mutable by default and visible within the class — no lifetime or ownership annotations needed. Reset `maxDiameter = 0` before each call so the `Solution` object can be reused in tests.

---

## Problem 4 — Balanced Binary Tree (LC #110)

**Difficulty:** Easy | **Pattern:** DFS with sentinel return value

### Problem Statement

Given the root of a binary tree, determine if it is height-balanced: for every node in the tree, the height difference between its left and right subtrees is at most 1. An empty tree is considered balanced. Constraints: the number of nodes is in `[0, 5000]`, and node values are in `[-10^4, 10^4]`.

### Key Insight

Return the subtree height if balanced, or `-1` as a sentinel meaning "already unbalanced." This avoids a second pass over the tree.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public boolean isBalanced(TreeNode root) {
        return checkHeight(root) >= 0;
    }

    // Returns height >= 0 if subtree is balanced; -1 if unbalanced.
    private int checkHeight(TreeNode node) {
        if (node == null) return 0;
        int lh = checkHeight(node.left);
        if (lh < 0) return -1;                          // short-circuit
        int rh = checkHeight(node.right);
        if (rh < 0) return -1;
        if (Math.abs(lh - rh) > 1) return -1;
        return 1 + Math.max(lh, rh);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // balanced: [3,9,20,null,null,15,7]
        TreeNode t1 = buildTree(new Integer[]{3, 9, 20, null, null, 15, 7});
        if (!s.isBalanced(t1))
            throw new AssertionError("balanced_yes: expected true");

        // unbalanced: [1,2,2,3,3,null,null,4,4]
        TreeNode t2 = buildTree(new Integer[]{1, 2, 2, 3, 3, null, null, 4, 4});
        if (s.isBalanced(t2))
            throw new AssertionError("balanced_no: expected false");

        // empty tree is balanced
        if (!s.isBalanced(null))
            throw new AssertionError("balanced_empty: expected true");

        System.out.println("LC#110 Balanced Binary Tree: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** The `-1` sentinel keeps the return type as a plain `int`, avoiding a wrapper object. Rust enforces the same type in all match arms, which naturally pushes you toward the same design. In Java you could also use a `record` carrying `(boolean balanced, int height)` — clean but verbose for a one-liner helper.

---

## Problem 5 — Same Tree (LC #100)

**Difficulty:** Easy | **Pattern:** Simultaneous DFS on two trees

### Problem Statement

Given the roots of two binary trees `p` and `q`, return `true` if they are structurally identical and every corresponding node has the same value. Both shape and values must match exactly — a left child in one tree must be a left child in the other. Two empty trees are considered equal. Constraints: each tree has at most 100 nodes, and node values are in `[-10^4, 10^4]`.

### Key Insight

Four cases on the pair `(p, q)`: both null (equal); both non-null with same value (recurse); both non-null with different values (false); one null one non-null (false).

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // Note: no static isSameTree helper — this class defines it as a public instance method below.
    // ─────────────────────────────────────────────────────────────────────────

    public boolean isSameTree(TreeNode p, TreeNode q) {
        if (p == null && q == null) return true;
        if (p == null || q == null) return false;
        return p.val == q.val
            && isSameTree(p.left,  q.left)
            && isSameTree(p.right, q.right);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // identical [1,2,3] vs [1,2,3]
        if (!s.isSameTree(buildTree(new Integer[]{1, 2, 3}),
                          buildTree(new Integer[]{1, 2, 3})))
            throw new AssertionError("same_yes: expected true");

        // structural difference: [1,2] vs [1,null,2]
        if (s.isSameTree(buildTree(new Integer[]{1, 2}),
                         buildTree(new Integer[]{1, null, 2})))
            throw new AssertionError("same_no_structure: expected false");

        // value difference: [1,2,1] vs [1,1,2]
        if (s.isSameTree(buildTree(new Integer[]{1, 2, 1}),
                         buildTree(new Integer[]{1, 1, 2})))
            throw new AssertionError("same_no_value: expected false");

        // both empty
        if (!s.isSameTree(null, null))
            throw new AssertionError("same_both_empty: expected true");

        System.out.println("LC#100 Same Tree: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** In Rust the cleanest idiom is `match (p, q)` on a tuple of `Option`s, covering all four cases in one block. In Java, two consecutive null checks achieve the same result with less ceremony. Both approaches are exhaustive — the compiler can reason about Java's `if` chain, but not with the proof-level guarantees Rust's `match` provides.

---

## Problem 6 — Subtree of Another Tree (LC #572)

**Difficulty:** Easy | **Pattern:** DFS + same-tree check

### Problem Statement

Given the roots of two binary trees `root` and `subRoot`, return `true` if there exists a node in `root` such that the subtree rooted at that node is structurally identical to `subRoot` (same shape and values at every position). A subtree includes the node and all of its descendants. Constraints: `root` has 1–2000 nodes; `subRoot` has 1–1000 nodes; node values are in `[-10^4, 10^4]`.

### Key Insight

At each node of `root`, check `isSameTree(root, subRoot)`. If false, recurse into both children. This reuses the LC #100 logic directly.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // Note: no static isSameTree helper — this class defines it as a private method below.
    // ─────────────────────────────────────────────────────────────────────────

    public boolean isSubtree(TreeNode root, TreeNode subRoot) {
        if (root == null) return subRoot == null;
        if (isSameTree(root, subRoot)) return true;
        return isSubtree(root.left, subRoot) || isSubtree(root.right, subRoot);
    }

    private boolean isSameTree(TreeNode p, TreeNode q) {
        if (p == null && q == null) return true;
        if (p == null || q == null) return false;
        return p.val == q.val
            && isSameTree(p.left,  q.left)
            && isSameTree(p.right, q.right);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // [3,4,5,1,2] contains [4,1,2] as subtree
        TreeNode root1 = buildTree(new Integer[]{3, 4, 5, 1, 2});
        TreeNode sub1  = buildTree(new Integer[]{4, 1, 2});
        if (!s.isSubtree(root1, sub1))
            throw new AssertionError("subtree_yes: expected true");

        // [3,4,5,1,2,null,null,null,null,0] does NOT contain [4,1,2]
        // because the node under key 2 has an extra child
        TreeNode root2 = buildTree(new Integer[]{3, 4, 5, 1, 2, null, null, null, null, 0});
        TreeNode sub2  = buildTree(new Integer[]{4, 1, 2});
        if (s.isSubtree(root2, sub2))
            throw new AssertionError("subtree_no_extra: expected false");

        // same single-node tree
        if (!s.isSubtree(buildTree(new Integer[]{1}), buildTree(new Integer[]{1})))
            throw new AssertionError("subtree_same: expected true");

        System.out.println("LC#572 Subtree of Another Tree: all tests passed");
    }
}
```

**Complexity:** Time O(m × n) worst case where m and n are the tree sizes. Space O(max(h_root, h_sub)).

**Java notes:** In Rust, passing `sub_root.clone()` to two recursive branches is syntactically explicit — you need a cheap `Rc` refcount bump. In Java, passing the same reference to both recursive calls is free and implicit. This is a case where Rust's explicitness reveals a semantic choice that Java hides.

---

## Problem 7 — Lowest Common Ancestor of a BST (LC #235)

**Difficulty:** Medium | **Pattern:** Iterative BST navigation

### Problem Statement

Given a Binary Search Tree and two nodes `p` and `q` (both guaranteed to exist in the BST), return their lowest common ancestor (LCA) — the deepest node that is an ancestor of both `p` and `q`. A node is considered an ancestor of itself. Constraints: the BST has 2–10^5 nodes; all node values are unique; `p ≠ q`. The BST ordering property enables an O(h) iterative solution.

### Key Insight

BST ordering decides direction in O(1): if both `p.val` and `q.val` are less than `current.val`, the LCA is in the left subtree; if both are greater, it is in the right subtree; otherwise, `current` *is* the LCA. No recursion stack needed.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public TreeNode lowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
        TreeNode cur = root;
        while (cur != null) {
            if (p.val < cur.val && q.val < cur.val) {
                cur = cur.left;
            } else if (p.val > cur.val && q.val > cur.val) {
                cur = cur.right;
            } else {
                return cur;    // split point — cur is the LCA
            }
        }
        return null;           // unreachable given problem constraints
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        //       6
        //      / \
        //     2   8
        //    / \ / \
        //   0  4 7  9
        //     / \
        //    3   5
        TreeNode tree = buildTree(new Integer[]{6, 2, 8, 0, 4, 7, 9, null, null, 3, 5});

        // find actual node references by value
        TreeNode p1 = findNode(tree, 2);
        TreeNode q1 = findNode(tree, 8);
        TreeNode lca1 = s.lowestCommonAncestor(tree, p1, q1);
        if (lca1 == null || lca1.val != 6)
            throw new AssertionError("lca_split_at_root: expected 6 got "
                + (lca1 == null ? "null" : lca1.val));

        // p is ancestor of q
        TreeNode p2 = findNode(tree, 2);
        TreeNode q2 = findNode(tree, 4);
        TreeNode lca2 = s.lowestCommonAncestor(tree, p2, q2);
        if (lca2 == null || lca2.val != 2)
            throw new AssertionError("lca_ancestor: expected 2 got "
                + (lca2 == null ? "null" : lca2.val));

        System.out.println("LC#235 LCA of BST: all tests passed");
    }

    // Helper: BFS search for node with given value
    private static TreeNode findNode(TreeNode root, int val) {
        if (root == null) return null;
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        while (!q.isEmpty()) {
            TreeNode n = q.poll();
            if (n.val == val) return n;
            if (n.left  != null) q.offer(n.left);
            if (n.right != null) q.offer(n.right);
        }
        return null;
    }
}
```

**Complexity:** Time O(h), Space O(1) — fully iterative.

> **Java vs Rust:** In Rust the test for LC #235 had to construct separate single-node trees for `p` and `q` because threading actual node references from the built tree requires fighting lifetimes and `Rc` borrow rules. In Java, `findNode` simply traverses the same tree and returns the actual `TreeNode` reference — no cloning, no borrow guards, no `Rc::clone`. This is the clearest case in the chapter where Java's garbage-collected references outshine Rust's ownership model for tree problems.

---

## Problem 8 — Binary Tree Level Order Traversal (LC #102)

**Difficulty:** Medium | **Pattern:** BFS with level batching

### Problem Statement

Given the root of a binary tree, return all node values grouped by level from top to bottom, left to right within each level, as a `List<List<Integer>>`. The outer list has one entry per depth level; each inner list contains all values at that depth. An empty tree returns an empty list. Constraints: the number of nodes is in `[0, 2000]`, and node values are in `[-1000, 1000]`.

### Key Insight

BFS using `ArrayDeque`. At the start of each level, snapshot `queue.size()` — that is the number of nodes on this level. Process exactly that many nodes, collect their values, then enqueue their children.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public List<List<Integer>> levelOrder(TreeNode root) {
        List<List<Integer>> result = new ArrayList<>();
        if (root == null) return result;

        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);

        while (!q.isEmpty()) {
            int levelSize = q.size();               // snapshot before inner loop
            List<Integer> level = new ArrayList<>();
            for (int i = 0; i < levelSize; i++) {
                TreeNode node = q.poll();
                level.add(node.val);
                if (node.left  != null) q.offer(node.left);
                if (node.right != null) q.offer(node.right);
            }
            result.add(level);
        }
        return result;
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // [3,9,20,null,null,15,7] → [[3],[9,20],[15,7]]
        TreeNode t1 = buildTree(new Integer[]{3, 9, 20, null, null, 15, 7});
        var got1 = s.levelOrder(t1);
        var exp1 = List.of(List.of(3), List.of(9, 20), List.of(15, 7));
        if (!got1.equals(exp1))
            throw new AssertionError("levelOrder basic: expected " + exp1 + " got " + got1);

        // single node
        var got2 = s.levelOrder(buildTree(new Integer[]{1}));
        if (!got2.equals(List.of(List.of(1))))
            throw new AssertionError("levelOrder single: got " + got2);

        // empty
        if (!s.levelOrder(null).isEmpty())
            throw new AssertionError("levelOrder empty: expected []");

        System.out.println("LC#102 Level Order Traversal: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(n) — the queue holds at most one full level, which is O(n) for a complete tree.

**Java notes:** `ArrayDeque` does not accept `null` elements. Enqueue only non-null children (`if (node.left != null) q.offer(node.left)`). Never use `java.util.Stack` — it is a legacy class backed by `Vector` with synchronized methods. `ArrayDeque` is faster and preferred on LeetCode.

---

## Problem 9 — Binary Tree Right Side View (LC #199)

**Difficulty:** Medium | **Pattern:** BFS, record last node per level

### Problem Statement

Given the root of a binary tree, imagine standing on its right side and looking at the tree. Return the values of the nodes you can see, listed from top to bottom. Each level contributes exactly one visible node — the rightmost node at that depth. Constraints: the number of nodes is in `[0, 100]`, and node values are in `[-100, 100]`.

### Key Insight

BFS level order with the same level-batching trick as LC #102. The answer for each level is the value of the last node processed in that level's inner loop.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public List<Integer> rightSideView(TreeNode root) {
        List<Integer> result = new ArrayList<>();
        if (root == null) return result;

        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);

        while (!q.isEmpty()) {
            int levelSize = q.size();
            for (int i = 0; i < levelSize; i++) {
                TreeNode node = q.poll();
                if (i == levelSize - 1) result.add(node.val);   // rightmost
                if (node.left  != null) q.offer(node.left);
                if (node.right != null) q.offer(node.right);
            }
        }
        return result;
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        //     1
        //    / \
        //   2   3
        //    \   \
        //     5   4    → right view: [1, 3, 4]
        TreeNode t1 = buildTree(new Integer[]{1, 2, 3, null, 5, null, 4});
        var got1 = s.rightSideView(t1);
        if (!got1.equals(Arrays.asList(1, 3, 4)))
            throw new AssertionError("rightSide basic: expected [1,3,4] got " + got1);

        // left-only tree: [1,2] → [1, 2]
        var got2 = s.rightSideView(buildTree(new Integer[]{1, 2}));
        if (!got2.equals(Arrays.asList(1, 2)))
            throw new AssertionError("rightSide left-only: expected [1,2] got " + got2);

        // single node
        var got3 = s.rightSideView(buildTree(new Integer[]{1}));
        if (!got3.equals(Arrays.asList(1)))
            throw new AssertionError("rightSide single: got " + got3);

        System.out.println("LC#199 Right Side View: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(n).

**Java notes:** The `i == levelSize - 1` check is safe because `levelSize >= 1` is guaranteed — the outer `while (!q.isEmpty())` ensures at least one node per iteration. No off-by-one risk here, unlike Rust's `usize` subtraction where underflow is a concern if the invariant is not confirmed.

---

## Problem 10 — Count Good Nodes in Binary Tree (LC #1448)

**Difficulty:** Medium | **Pattern:** DFS with path maximum

### Problem Statement

A node `X` is "good" if on the path from the root to `X` there is no node with a value greater than `X.val`. Return the count of good nodes in the tree.

### Key Insight

DFS, threading the maximum value seen so far on the current root-to-node path. A node is good when its value is `>= maxSoFar`. The root is always good (`Integer.MIN_VALUE` is the initial maximum).

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public int goodNodes(TreeNode root) {
        return dfs(root, Integer.MIN_VALUE);
    }

    private int dfs(TreeNode node, int maxSoFar) {
        if (node == null) return 0;
        int isGood = (node.val >= maxSoFar) ? 1 : 0;
        int newMax = Math.max(maxSoFar, node.val);
        return isGood + dfs(node.left, newMax) + dfs(node.right, newMax);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        //         3
        //        / \
        //       1   4
        //      /   / \
        //     3   1   5
        // Good nodes: 3 (root), 3 (left-left), 4, 5 → count 4
        TreeNode t1 = buildTree(new Integer[]{3, 1, 4, 3, null, 1, 5});
        int got1 = s.goodNodes(t1);
        if (got1 != 4)
            throw new AssertionError("goodNodes basic: expected 4 got " + got1);

        // path 3→3→4→2: good nodes are 3,3,4 (2 < 4) → count 3
        TreeNode t2 = buildTree(new Integer[]{3, 3, null, 4, 2});
        int got2 = s.goodNodes(t2);
        if (got2 != 3)
            throw new AssertionError("goodNodes path: expected 3 got " + got2);

        // single node is always good
        if (s.goodNodes(buildTree(new Integer[]{1})) != 1)
            throw new AssertionError("goodNodes single: expected 1");

        System.out.println("LC#1448 Good Nodes: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** `Integer.MIN_VALUE` as the initial maximum ensures the root is always counted as good — any `int` value is `>= Integer.MIN_VALUE`. Rust uses `i32::MIN` with identical semantics. The pass-by-value `maxSoFar` parameter means each recursive call gets its own copy — no state to restore when backtracking, unlike an instance field that would require undo.

---

## Problem 11 — Validate Binary Search Tree (LC #98)

**Difficulty:** Medium | **Pattern:** DFS with range propagation

### Problem Statement

Given the root of a binary tree, determine if it is a valid Binary Search Tree: for every node, all values in its left subtree are strictly less than the node's value, and all values in its right subtree are strictly greater. Equality is not allowed. Constraints: the number of nodes is in `[1, 10^4]`, and node values are in `[-2^31, 2^31 - 1]` (the full `int` range). Using `Integer.MIN_VALUE` and `Integer.MAX_VALUE` as sentinels will fail for trees containing those boundary values — use `long` instead.

### Key Insight

Propagate valid `(min, max)` ranges downward. Initially unbounded. Tighten the upper bound when descending left; tighten the lower bound when descending right.

> **Common trap:** Using `Integer.MIN_VALUE` / `Integer.MAX_VALUE` as sentinel bounds fails for trees containing those values. Use `long` bounds (or `Long` with null for "unbounded") to handle the edge cases safely.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public boolean isValidBST(TreeNode root) {
        return validate(root, Long.MIN_VALUE, Long.MAX_VALUE);
    }

    private boolean validate(TreeNode node, long min, long max) {
        if (node == null) return true;
        long val = node.val;
        if (val <= min || val >= max) return false;
        return validate(node.left,  min, val)
            && validate(node.right, val, max);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // valid: [2,1,3]
        if (!s.isValidBST(buildTree(new Integer[]{2, 1, 3})))
            throw new AssertionError("valid_yes: expected true");

        // invalid: [5,1,4,null,null,3,6] — 4 < 5 so right child is wrong
        if (s.isValidBST(buildTree(new Integer[]{5, 1, 4, null, null, 3, 6})))
            throw new AssertionError("valid_no: expected false");

        // single node at Integer.MIN_VALUE — valid BST
        if (!s.isValidBST(buildTree(new Integer[]{Integer.MIN_VALUE})))
            throw new AssertionError("valid_min_boundary: expected true");

        // single node at Integer.MAX_VALUE — valid BST
        if (!s.isValidBST(buildTree(new Integer[]{Integer.MAX_VALUE})))
            throw new AssertionError("valid_max_boundary: expected true");

        // subtly invalid: [3,1,5,null,null,3,6] — 3 == 3 violates strict inequality
        if (s.isValidBST(buildTree(new Integer[]{3, 1, 5, null, null, 3, 6})))
            throw new AssertionError("valid_no_duplicate: expected false");

        System.out.println("LC#98 Validate BST: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** Casting `node.val` to `long` widens it before comparison. `Long.MIN_VALUE` and `Long.MAX_VALUE` serve as "unbounded" sentinels — any valid `int` node value falls strictly inside `(Long.MIN_VALUE, Long.MAX_VALUE)`. Rust uses `Option<i64>` with `None` meaning unbounded; Java's widened `long` sentinel is arguably cleaner for this problem.

---

## Problem 12 — Kth Smallest Element in a BST (LC #230)

**Difficulty:** Medium | **Pattern:** Inorder traversal with early exit

### Problem Statement

Given the root of a Binary Search Tree and an integer `k` (1-indexed), return the `k`th smallest value among all node values. The BST has between `k` and `10^4` nodes, and node values are in `[0, 10^4]`. You are guaranteed `k` is valid. BST inorder traversal visits nodes in ascending sorted order, making this problem a natural application of early-exit DFS.

### Key Insight

Inorder traversal of a BST visits nodes in ascending order. Count nodes as they are visited; return the value when the count reaches `k`.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    private int count  = 0;
    private int result = 0;

    public int kthSmallest(TreeNode root, int k) {
        count  = 0;     // reset for repeated calls
        result = 0;
        inorder(root, k);
        return result;
    }

    private void inorder(TreeNode node, int k) {
        if (node == null || count >= k) return;
        inorder(node.left, k);
        count++;
        if (count == k) { result = node.val; return; }
        inorder(node.right, k);
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // BST [3,1,4,null,2] → inorder: 1,2,3,4 → k=1 gives 1
        TreeNode t1 = buildTree(new Integer[]{3, 1, 4, null, 2});
        int got1 = s.kthSmallest(t1, 1);
        if (got1 != 1)
            throw new AssertionError("kth k=1: expected 1 got " + got1);

        // BST [5,3,6,2,4,null,null,1] → inorder: 1,2,3,4,5,6 → k=3 gives 3
        TreeNode t2 = buildTree(new Integer[]{5, 3, 6, 2, 4, null, null, 1});
        int got2 = s.kthSmallest(t2, 3);
        if (got2 != 3)
            throw new AssertionError("kth k=3: expected 3 got " + got2);

        // k equals tree size → last element
        TreeNode t3 = buildTree(new Integer[]{2, 1, 3});
        int got3 = s.kthSmallest(t3, 3);
        if (got3 != 3)
            throw new AssertionError("kth k=n: expected 3 got " + got3);

        System.out.println("LC#230 Kth Smallest BST: all tests passed");
    }
}
```

**Complexity:** Time O(h + k), Space O(h).

**Java notes:** `private int count` and `result` as instance fields replace Rust's `&mut i32` pattern. The early-exit guard `if (count >= k) return` prunes the entire remaining subtree. Reset both fields at the top of `kthSmallest` so the object can be safely reused across test invocations — a real LeetCode submission creates a fresh `Solution` each time, but test drivers may reuse the same instance.

**Approach 2 — Iterative Inorder with Explicit Stack (O(h + k) time, O(h) space).** Use an `ArrayDeque` as an explicit stack to simulate the recursive inorder traversal without recursion. Push left children until hitting null, then pop and count, then move to the right child. This is production-safe for large trees and avoids deep recursion.

```java
import java.util.*;

class Solution2 {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    public int kthSmallest(TreeNode root, int k) {
        Deque<TreeNode> stack = new ArrayDeque<>();
        TreeNode cur = root;
        int count = 0;
        while (cur != null || !stack.isEmpty()) {
            // push all left children
            while (cur != null) { stack.push(cur); cur = cur.left; }
            cur = stack.pop();          // visit in-order node
            if (++count == k) return cur.val;
            cur = cur.right;            // move to right subtree
        }
        throw new IllegalStateException("k out of range");
    }

    public static void main(String[] args) {
        var s = new Solution2();

        // BST [3,1,4,null,2] → k=1 gives 1
        if (s.kthSmallest(buildTree(new Integer[]{3, 1, 4, null, 2}), 1) != 1)
            throw new AssertionError("iterative kth k=1: expected 1");

        // BST [5,3,6,2,4,null,null,1] → k=3 gives 3
        if (s.kthSmallest(buildTree(new Integer[]{5, 3, 6, 2, 4, null, null, 1}), 3) != 3)
            throw new AssertionError("iterative kth k=3: expected 3");

        // k equals tree size
        if (s.kthSmallest(buildTree(new Integer[]{2, 1, 3}), 3) != 3)
            throw new AssertionError("iterative kth k=n: expected 3");

        System.out.println("LC#230 Approach 2 (iterative inorder): all tests passed");
    }
}
```

> **Java vs Rust:** In Rust the iterative inorder requires `VecDeque<Rc<RefCell<TreeNode>>>` as the stack, with `.clone()` calls at each push. In Java the same stack is `Deque<TreeNode>` with `stack.push(cur)` — three words vs twelve. The iterative approach is more useful in Java (where deep trees risk `StackOverflowError`); Rust's compiled recursion typically handles deeper stacks without issue.

---

## Problem 13 — Construct Binary Tree from Preorder and Inorder Traversal (LC #105)

**Difficulty:** Medium | **Pattern:** Divide-and-conquer with index map

### Problem Statement

Given the `preorder` and `inorder` traversal arrays of a binary tree with `n` distinct values, construct and return the original tree. The first element of `preorder` is always the root; its position in `inorder` splits the tree into left and right subtrees. Constraints: `1 ≤ n ≤ 3000`, all values are unique and fit in `int`, and both arrays are valid traversals of the same tree.

### Key Insight

The first element of `preorder` is always the root. Find that value in `inorder` — everything to its left is the left subtree, everything to the right is the right subtree. Use a `HashMap` for O(1) inorder index lookups. Thread a `preIdx` cursor through recursion instead of slicing arrays.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    // buildTree(Integer[]) builds from BFS level-order array (test helper)
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    static List<Integer> toLevelOrder(TreeNode root) {
        List<Integer> res = new ArrayList<>();
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        while (!q.isEmpty()) {
            TreeNode n = q.poll();
            if (n == null) { res.add(null); }
            else { res.add(n.val); q.offer(n.left); q.offer(n.right); }
        }
        while (!res.isEmpty() && res.get(res.size()-1) == null) res.remove(res.size()-1);
        return res;
    }
    // ─────────────────────────────────────────────────────────────────────────

    private int[] preIdx = {0};     // mutable cursor — equivalent to &mut usize in Rust
    private Map<Integer, Integer> inMap;

    // buildTree(int[], int[]) reconstructs a tree from preorder + inorder arrays (the LeetCode solution)
    // Distinct from the static buildTree(Integer[]) helper above — Java allows overloads on param type.
    public TreeNode buildTree(int[] preorder, int[] inorder) {
        preIdx[0] = 0;
        inMap = new HashMap<>();
        for (int i = 0; i < inorder.length; i++) inMap.put(inorder[i], i);
        return build(preorder, 0, inorder.length);
    }

    private TreeNode build(int[] preorder, int inStart, int inEnd) {
        if (inStart >= inEnd || preIdx[0] >= preorder.length) return null;
        int rootVal = preorder[preIdx[0]++];
        int inMid   = inMap.get(rootVal);
        TreeNode node = new TreeNode(rootVal);
        node.left  = build(preorder, inStart, inMid);      // left subtree
        node.right = build(preorder, inMid + 1, inEnd);    // right subtree
        return node;
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        // preorder [3,9,20,15,7], inorder [9,3,15,20,7] → [3,9,20,null,null,15,7]
        TreeNode t1 = s.buildTree(
            new int[]{3, 9, 20, 15, 7},
            new int[]{9, 3, 15, 20, 7}
        );
        var got1 = toLevelOrder(t1);
        var exp1 = Arrays.asList(3, 9, 20, null, null, 15, 7);
        if (!got1.equals(exp1))
            throw new AssertionError("buildTree basic: expected " + exp1 + " got " + got1);

        // single element
        TreeNode t2 = s.buildTree(new int[]{-1}, new int[]{-1});
        if (t2 == null || t2.val != -1)
            throw new AssertionError("buildTree single: expected -1");

        System.out.println("LC#105 Build Tree from Traversals: all tests passed");
    }
}
```

**Complexity:** Time O(n) — one HashMap lookup per node. Space O(n) for the map.

**Java notes:** `int[] preIdx = {0}` is the canonical Java workaround for a mutable-int cursor visible to nested lambdas and inner methods. Rust uses `&mut usize` passed explicitly. An `AtomicInteger` would also work but adds overhead. An instance field (`private int preIdx`) is equally clean for non-lambda use as shown here. The `HashMap` is built once and shared (read-only) across all recursive calls — Rust permits the same pattern because immutable shared borrows can coexist.

---

## Problem 14 — Binary Tree Maximum Path Sum (LC #124)

**Difficulty:** Hard | **Pattern:** DFS, global max with local gain

### Problem Statement

A path in a binary tree connects any two nodes with a sequence of edges (no node repeated). The path does not need to pass through the root. Return the maximum path sum.

### Key Insight

At each node, the longest path *through* that node is `node.val + max(0, leftGain) + max(0, rightGain)`. The helper returns the best single-arm gain for the parent; the global maximum captures the best arch seen at any node. Negative gains are discarded by clamping to 0.

### Solution

```java
import java.util.*;

class Solution {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    // ─────────────────────────────────────────────────────────────────────────

    private int globalMax;

    public int maxPathSum(TreeNode root) {
        globalMax = Integer.MIN_VALUE;
        gain(root);
        return globalMax;
    }

    // Returns the best single-arm gain from this node downward.
    private int gain(TreeNode node) {
        if (node == null) return 0;
        int lg = Math.max(0, gain(node.left));
        int rg = Math.max(0, gain(node.right));
        globalMax = Math.max(globalMax, node.val + lg + rg);   // arch through this node
        return node.val + Math.max(lg, rg);                    // best single arm
    }

    public static void main(String[] args) {
        Solution s = new Solution();

        //   1
        //  / \
        // 2   3    → path 2+1+3 = 6
        int got1 = s.maxPathSum(buildTree(new Integer[]{1, 2, 3}));
        if (got1 != 6)
            throw new AssertionError("maxPath simple: expected 6 got " + got1);

        //    -10
        //    /  \
        //   9   20
        //       / \
        //      15   7   → 15+20+7 = 42
        int got2 = s.maxPathSum(buildTree(new Integer[]{-10, 9, 20, null, null, 15, 7}));
        if (got2 != 42)
            throw new AssertionError("maxPath complex: expected 42 got " + got2);

        // all-negative: must pick the single least-negative node
        int got3 = s.maxPathSum(buildTree(new Integer[]{-3}));
        if (got3 != -3)
            throw new AssertionError("maxPath all_negative: expected -3 got " + got3);

        // two-node: [-2,-1] → path is just -1 (right child alone) but
        // root is -2; best single node is -1
        int got4 = s.maxPathSum(buildTree(new Integer[]{-2, null, -1}));
        if (got4 != -1)
            throw new AssertionError("maxPath two_negative: expected -1 got " + got4);

        System.out.println("LC#124 Max Path Sum: all tests passed");
    }
}
```

**Complexity:** Time O(n), Space O(h).

**Java notes:** `Integer.MIN_VALUE` initializes `globalMax` correctly for all-negative trees — any single node value will update it. `Math.max(0, gain(child))` is the key idiom: negative subtrees contribute nothing, so they are silently discarded. Rust's `.max(0)` is syntactically identical, reflecting how closely this algorithm translates between languages.

---

## Problem 15 — Serialize and Deserialize Binary Tree (LC #297)

**Difficulty:** Hard | **Pattern:** Preorder with null sentinels

### Problem Statement

Design an algorithm to serialize a binary tree to a string and deserialize the string back to the original tree structure. The algorithm must handle arbitrary shapes including unbalanced trees, single nodes, and empty trees.

### Key Insight

Preorder traversal with sentinel `"N"` for null nodes uniquely encodes any binary tree. Deserialization replays the preorder token sequence with a mutable index cursor, reconstructing the tree in the same top-down order.

### Solution

```java
import java.util.*;

class Codec {
    // ── tree helpers ──────────────────────────────────────────────────────────
    static class TreeNode {
        int val; TreeNode left, right;
        TreeNode(int val) { this.val = val; }
        TreeNode(int val, TreeNode l, TreeNode r) { this.val = val; left = l; right = r; }
    }
    static TreeNode buildTree(Integer[] v) {
        if (v == null || v.length == 0 || v[0] == null) return null;
        TreeNode root = new TreeNode(v[0]);
        Deque<TreeNode> q = new ArrayDeque<>();
        q.offer(root);
        for (int i = 1; i < v.length; ) {
            TreeNode n = q.poll();
            if (i < v.length && v[i] != null) { n.left  = new TreeNode(v[i]); q.offer(n.left);  } i++;
            if (i < v.length && v[i] != null) { n.right = new TreeNode(v[i]); q.offer(n.right); } i++;
        }
        return root;
    }
    static boolean isSameTree(TreeNode p, TreeNode q) {
        if (p == null && q == null) return true;
        if (p == null || q == null) return false;
        return p.val == q.val && isSameTree(p.left, q.left) && isSameTree(p.right, q.right);
    }
    // ─────────────────────────────────────────────────────────────────────────

    // Serialize: preorder traversal, comma-separated, "N" for null.
    // Example: [1,2,3] → "1,2,N,N,3,N,N"
    public String serialize(TreeNode root) {
        StringBuilder sb = new StringBuilder();
        serHelper(root, sb);
        if (sb.length() > 0 && sb.charAt(sb.length() - 1) == ',')
            sb.deleteCharAt(sb.length() - 1);   // trim trailing comma
        return sb.toString();
    }

    private void serHelper(TreeNode node, StringBuilder sb) {
        if (node == null) { sb.append("N,"); return; }
        sb.append(node.val).append(',');
        serHelper(node.left,  sb);
        serHelper(node.right, sb);
    }

    // Deserialize: replay preorder tokens; "N" means null.
    public TreeNode deserialize(String data) {
        if (data == null || data.isEmpty()) return null;
        String[] tokens = data.split(",");
        int[] cursor = {0};
        return desHelper(tokens, cursor);
    }

    private TreeNode desHelper(String[] tokens, int[] cursor) {
        if (cursor[0] >= tokens.length) return null;
        String token = tokens[cursor[0]++];
        if ("N".equals(token)) return null;
        TreeNode node = new TreeNode(Integer.parseInt(token));
        node.left  = desHelper(tokens, cursor);
        node.right = desHelper(tokens, cursor);
        return node;
    }

    public static void main(String[] args) {
        Codec codec = new Codec();

        // general tree
        TreeNode t1  = buildTree(new Integer[]{1, 2, 3, null, null, 4, 5});
        String data1 = codec.serialize(t1);
        TreeNode r1  = codec.deserialize(data1);
        if (!isSameTree(t1, r1))
            throw new AssertionError("codec roundtrip: trees differ after roundtrip; data=" + data1);

        // empty tree
        String dataEmpty = codec.serialize(null);
        TreeNode rEmpty  = codec.deserialize(dataEmpty);
        if (rEmpty != null)
            throw new AssertionError("codec empty: expected null got non-null");

        // single node
        TreeNode t3  = buildTree(new Integer[]{42});
        TreeNode r3  = codec.deserialize(codec.serialize(t3));
        if (r3 == null || r3.val != 42)
            throw new AssertionError("codec single: expected 42 got " + (r3 == null ? "null" : r3.val));

        // left-skewed: 1→2→3
        TreeNode t4  = buildTree(new Integer[]{1, 2, null, 3});
        TreeNode r4  = codec.deserialize(codec.serialize(t4));
        if (!isSameTree(t4, r4))
            throw new AssertionError("codec left-skewed: mismatch after roundtrip");

        // negative values
        TreeNode t5  = buildTree(new Integer[]{-1, -2, -3});
        TreeNode r5  = codec.deserialize(codec.serialize(t5));
        if (!isSameTree(t5, r5))
            throw new AssertionError("codec negatives: mismatch after roundtrip");

        System.out.println("LC#297 Serialize/Deserialize: all tests passed");
    }
}
```

**Complexity:** Time O(n) serialize and O(n) deserialize. Space O(n) for the token array and O(h) recursion stack.

**Java notes:** `int[] cursor = {0}` is the Java idiom for a mutable integer shared across recursion calls — identical in role to Rust's `&mut usize`. An alternative is to wrap tokens in an `ArrayDeque<String>` and `poll()` from the front, which avoids the array-index cursor entirely and is arguably more readable. The `StringBuilder` approach in serialization avoids repeated string concatenation, keeping the effective complexity O(n) rather than O(n²).

---

## Patterns Summary

| Pattern | Problems | When to use |
|---|---|---|
| Simple DFS returning a value | #226, #104, #100 | Structure or aggregate, no accumulated side-effect needed |
| DFS with instance-field accumulator | #543, #1448, #124, #230 | Must track a running max/count alongside the recursive return value |
| DFS with range propagation | #98, #1448 | Validity check requiring ancestor context |
| BFS level batching | #102, #199 | Level-by-level output; width-oriented problems |
| Iterative BST navigation | #235 | Ordered BST search — O(h), O(1) space |
| Divide and conquer + index map | #105 | Reconstruction from two traversals |
| Preorder with sentinels | #297 | Serialization requiring exact shape reconstruction |

---

## Java vs Rust — Tree Patterns Comparison

> **Key contrast:** Java trees are plain object graphs managed by a garbage collector. Rust trees use `Option<Rc<RefCell<TreeNode>>>` — three nested types whose purpose is to replicate Java's nullable, heap-allocated, mutably-shared object. Every `.borrow()`, `.borrow_mut()`, and `.clone()` call in the Rust chapter is mechanical overhead that Java eliminates. The algorithm in every problem below is identical in both languages; only the plumbing differs.

| Operation | Java | Rust |
|---|---|---|
| Null check | `if (node == null)` | `match node { None => ..., Some(n) => ... }` |
| Read child | `node.left` | `node.borrow().left.clone()` |
| Write child | `node.left = x` | `node.borrow_mut().left = Some(x)` |
| Mutable accumulator | `private int field` | `&mut i32` threaded through recursive calls |
| New node | `new TreeNode(val)` | `Rc::new(RefCell::new(TreeNode::new(val)))` |
| Queue for BFS | `Deque<TreeNode>` | `VecDeque<Rc<RefCell<TreeNode>>>` |
| Pass actual tree ref | trivial | requires `Rc::clone` or fighting lifetimes |
| Mutable index cursor | `int[] cursor = {0}` | `&mut usize` |

---

## 📝 Chapter Review Notes

### Issue Audit Table

| Issue | Severity | Fix Applied |
|---|---|---|
| `assert` keyword usage | Critical | Audited all 15 solutions — zero instances of bare `assert x` found. All checks use `throw new AssertionError(...)`. |
| `Stack` class usage | High | Not used anywhere. All BFS uses `ArrayDeque`. |
| `null` enqueued into `ArrayDeque` | High | Every child enqueue is guarded: `if (node.left != null) q.offer(node.left)`. ArrayDeque would throw `NullPointerException` on null offer. |
| LC #235 test uses fabricated p/q nodes (Rust problem) | Medium | Fixed in Java version: `findNode` traverses the actual tree to obtain real node references. Java vs Rust callout added to explain why. |
| LC #230 accumulator reset | Medium | `count = 0; result = 0` reset at top of `kthSmallest` so the instance can be reused across test calls without stale state. |
| LC #14 all-negative two-node test | Low | Added test `[-2, null, -1]` → expected -1 to confirm negative-subtree pruning works when the root is not the answer. |
| LC #297 empty-string deserialization | Low | Guarded `if (data == null || data.isEmpty()) return null` before split. Without this, `"".split(",")` returns `[""]`, and `desHelper` would attempt `Integer.parseInt("N")` incorrectly. |
| LC #98 duplicate-value boundary | Low | Added test `[3,1,5,null,null,3,6]` (where right child value equals root value) to confirm strict inequality is enforced. |
| `buildTree` method overloading | Low | LC #105's `Solution.buildTree(int[], int[])` is a distinct overload from the static `buildTree(Integer[])` helper — Java resolves by parameter type. Both names can coexist; no rename needed. |
| `toLevelOrder` handling of null root | Low | `q.offer(root)` with `root == null` adds null to the queue. The `if (node == null)` branch handles it, producing an empty list after stripping trailing nulls. Verified: `toLevelOrder(null)` returns `[]`. |

### What This Chapter Does Well

1. **Mutable accumulator consistency.** Problems 3, 10, 12, and 14 all use `private int` instance fields with explicit resets — a coherent pattern across all DFS-with-side-effect problems.

2. **No legacy Java collections.** `ArrayDeque` throughout, `HashMap` with `var` where the generic type is verbose. No `Stack`, no `Hashtable`, no `Vector`.

3. **Real `findNode` in LC #235.** Unlike the Rust chapter which had to use fabricated single-node trees for `p` and `q`, the Java test correctly locates actual subtree node references. This both validates the solution more faithfully and illustrates the Java-vs-Rust ownership contrast concretely.

4. **Long bounds in LC #98.** The `long min/max` approach with widening cast sidesteps the `Integer.MIN_VALUE`/`Integer.MAX_VALUE` boundary failure that trips up a majority of BST validation submissions. Both boundary test cases are included.

5. **Complete test coverage for hard problems.** LC #124 has four test cases (simple, complex, all-negative single-node, all-negative two-node); LC #297 has five (general, empty, single, left-skewed, negative values). Each test targets a distinct failure mode.

### What Could Be Improved

1. **No iterative DFS variants.** Every DFS solution is recursive. For very deep trees (depth > ~10,000 on a skewed tree), Java's default stack size causes `StackOverflowError`. An iterative inorder traversal using `ArrayDeque` as an explicit stack would be a production-safe alternative for LC #230 in particular, and a worthwhile addition to the chapter.

2. **No `record` usage despite Java 17+ target.** The chapter includes `var` but misses an opportunity to demonstrate `record` for the DFS-with-multiple-returns pattern. For example, LC #110's `checkHeight` could return `record HeightResult(boolean balanced, int height)` instead of the `-1` sentinel, making the invariant explicit. This was a design trade-off — the sentinel matches the Rust chapter's approach and is concise — but a record-based version as an "alternative approach" callout would add pedagogic value.

3. **Self-contained embedding adds boilerplate.** Each class embeds ~15 lines of helper code. This is intentional — every block compiles independently — but it means the helper code appears 15 times in the chapter. For a printed or PDFed book this is slightly verbose; for a reader who copy-pastes one class to a file, it is essential.

4. **LC #105 method naming.** The public method is `buildTree(int[], int[])` — the standard LeetCode signature. It coexists with the static `buildTree(Integer[])` test-helper as a Java overload; the compiler resolves them by parameter type (primitive `int[]` vs boxed `Integer[]`) with no ambiguity.
