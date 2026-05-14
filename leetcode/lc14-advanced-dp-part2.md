# Chapter LC-14 Part 2: Tree DP, Bitmask DP, State Machine DP

> **Continued from Part 1.** This chapter covers three Grandmaster DP families:
> Tree DP (rerooting, subtree aggregation), Bitmask DP (2^n state spaces), and
> State Machine DP (explicit phase transitions). All solutions are Rust 2024 edition,
> no external crates, self-contained tests.

---

## Section 4: Tree DP

DP on tree structures. The core idea: a DFS post-order pass computes subtree states
bottom-up. The **rerooting** technique lets you compute rooted answers for every
possible root in O(n) by combining a downward and upward pass.

**Rust pattern:** All binary-tree problems use `Option<Rc<RefCell<TreeNode>>>`.
Always `.clone()` child references *before* recursing — never hold a `borrow()` guard
across a recursive call or you get a runtime panic.

---

### Problem 1 — LC #337: House Robber III

**Difficulty:** Medium

#### Problem Statement

A thief robs houses arranged in a binary tree. Adjacent nodes (parent-child) cannot
both be robbed. Return the maximum amount that can be stolen.

#### DP State + Recurrence

```
dfs(node) → (rob_this, skip_this)

rob_this  = node.val + skip_left + skip_right
skip_this = max(rob_left, skip_left) + max(rob_right, skip_right)
answer    = max(rob_root, skip_root)
```

#### Solution

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug, PartialEq, Eq)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<Rc<RefCell<TreeNode>>>,
    pub right: Option<Rc<RefCell<TreeNode>>>,
}
impl TreeNode {
    pub fn new(val: i32) -> Self { TreeNode { val, left: None, right: None } }
}
type TreeNodeRef = Option<Rc<RefCell<TreeNode>>>;

struct Solution;
impl Solution {
    pub fn rob(root: TreeNodeRef) -> i32 {
        let (rob, skip) = Self::dfs(&root);
        rob.max(skip)
    }
    // Returns (rob_this_node, skip_this_node)
    fn dfs(node: &TreeNodeRef) -> (i32, i32) {
        match node {
            None => (0, 0),
            Some(n) => {
                let left  = n.borrow().left.clone();
                let right = n.borrow().right.clone();
                let (lr, ls) = Self::dfs(&left);
                let (rr, rs) = Self::dfs(&right);
                let rob_cur  = n.borrow().val + ls + rs;
                let skip_cur = lr.max(ls) + rr.max(rs);
                (rob_cur, skip_cur)
            }
        }
    }
}

#[cfg(test)]
mod tests_337 {
    use super::*;
    use std::cell::RefCell;
    use std::rc::Rc;

    fn node(v: i32) -> TreeNodeRef { Some(Rc::new(RefCell::new(TreeNode::new(v)))) }
    fn wc(v: i32, l: TreeNodeRef, r: TreeNodeRef) -> TreeNodeRef {
        let n = Rc::new(RefCell::new(TreeNode::new(v)));
        n.borrow_mut().left = l;
        n.borrow_mut().right = r;
        Some(n)
    }

    #[test]
    fn test_rob3() {
        // [3,2,3,null,3,null,1] -> 7  (rob 3+3+1)
        let root = wc(3, wc(2, None, node(3)), wc(3, None, node(1)));
        assert_eq!(Solution::rob(root), 7);
        // [3,4,5,1,3,null,1] -> 9  (rob 4+5)
        let root2 = wc(3, wc(4, node(1), node(3)), wc(5, None, node(1)));
        assert_eq!(Solution::rob(root2), 9);
    }
}
```

**Complexity:** O(n) time, O(h) space (call stack).

**Rust note:** The `clone()` on child references is cheap — it increments the `Rc`
reference count, not the node data.

---

### Problem 2 — LC #968: Binary Tree Cameras

**Difficulty:** Hard

#### Problem Statement

Install the minimum number of cameras in a binary tree such that every node is
monitored. A camera at a node monitors itself, its parent, and its children.

#### DP State + Recurrence

Three node states returned from DFS:
- `0` — node is **not covered** (needs a camera from parent)
- `1` — node **has a camera**
- `2` — node is **covered** (by a child camera, no camera here)

```
if left == 0 OR right == 0:  place camera here → return 1
if left == 1 OR right == 1:  covered by child  → return 2
else:                         not covered       → return 0

Null nodes return 2 (treated as already covered).
If root returns 0: place one more camera at root.
```

#### Solution

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug, PartialEq, Eq)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<Rc<RefCell<TreeNode>>>,
    pub right: Option<Rc<RefCell<TreeNode>>>,
}
impl TreeNode {
    pub fn new(val: i32) -> Self { TreeNode { val, left: None, right: None } }
}
type TreeNodeRef = Option<Rc<RefCell<TreeNode>>>;

struct Solution;
impl Solution {
    pub fn min_camera_cover(root: TreeNodeRef) -> i32 {
        let mut cameras = 0i32;
        if Self::dfs(&root, &mut cameras) == 0 {
            cameras += 1; // root uncovered: add camera at root
        }
        cameras
    }
    // Returns: 0=not_covered, 1=has_camera, 2=covered_no_camera
    fn dfs(node: &TreeNodeRef, cameras: &mut i32) -> i32 {
        match node {
            None => 2, // absent node counts as covered
            Some(n) => {
                let l = n.borrow().left.clone();
                let r = n.borrow().right.clone();
                let ls = Self::dfs(&l, cameras);
                let rs = Self::dfs(&r, cameras);
                if ls == 0 || rs == 0 {
                    *cameras += 1;
                    return 1; // must place camera here
                }
                if ls == 1 || rs == 1 {
                    return 2; // covered by a child
                }
                0 // both children covered but no camera nearby
            }
        }
    }
}

#[cfg(test)]
mod tests_968 {
    use super::*;
    use std::cell::RefCell;
    use std::rc::Rc;

    fn node(v: i32) -> TreeNodeRef { Some(Rc::new(RefCell::new(TreeNode::new(v)))) }
    fn wc(v: i32, l: TreeNodeRef, r: TreeNodeRef) -> TreeNodeRef {
        let n = Rc::new(RefCell::new(TreeNode::new(v)));
        n.borrow_mut().left = l;
        n.borrow_mut().right = r;
        Some(n)
    }

    #[test]
    fn test_cameras() {
        // [0,0,null,0,0] -> 1
        let root = wc(0, wc(0, node(0), node(0)), None);
        assert_eq!(Solution::min_camera_cover(root), 1);
        // [0,0,null,0,null,0,null,null,0] -> 2
        let root2 = wc(0, wc(0, wc(0, None, wc(0, None, node(0))), None), None);
        assert_eq!(Solution::min_camera_cover(root2), 2);
    }
}
```

**Complexity:** O(n) time, O(h) space.

**Rust note:** Passing `cameras: &mut i32` through recursion is the idiomatic Rust
alternative to a class-level mutable field in Java.

---

### Problem 3 — LC #124: Binary Tree Maximum Path Sum

**Difficulty:** Hard

#### Problem Statement

A **path** in a binary tree is any sequence of nodes where each pair of adjacent
nodes has an edge, visiting each node at most once. Return the maximum path sum.
The path does not need to pass through the root.

#### DP State + Recurrence

```
dfs(node) → max single-arm gain from this node downward

arm = max(0, left_arm, right_arm)   (clamp negatives to 0)
candidate_path = node.val + left_arm + right_arm   (passes through node)
answer = max over all nodes of candidate_path
```

#### Solution

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug, PartialEq, Eq)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<Rc<RefCell<TreeNode>>>,
    pub right: Option<Rc<RefCell<TreeNode>>>,
}
impl TreeNode {
    pub fn new(val: i32) -> Self { TreeNode { val, left: None, right: None } }
}
type TreeNodeRef = Option<Rc<RefCell<TreeNode>>>;

struct Solution;
impl Solution {
    pub fn max_path_sum(root: TreeNodeRef) -> i32 {
        let mut ans = i32::MIN;
        Self::dfs(&root, &mut ans);
        ans
    }
    // Returns max single-arm contribution going downward from this node
    fn dfs(node: &TreeNodeRef, ans: &mut i32) -> i32 {
        match node {
            None => 0,
            Some(n) => {
                let l = n.borrow().left.clone();
                let r = n.borrow().right.clone();
                let lv = Self::dfs(&l, ans).max(0); // clamp: don't include negative arms
                let rv = Self::dfs(&r, ans).max(0);
                let val = n.borrow().val;
                *ans = (*ans).max(val + lv + rv);   // path through this node
                val + lv.max(rv)                    // best single arm for parent
            }
        }
    }
}

#[cfg(test)]
mod tests_124 {
    use super::*;
    use std::cell::RefCell;
    use std::rc::Rc;

    fn node(v: i32) -> TreeNodeRef { Some(Rc::new(RefCell::new(TreeNode::new(v)))) }
    fn wc(v: i32, l: TreeNodeRef, r: TreeNodeRef) -> TreeNodeRef {
        let n = Rc::new(RefCell::new(TreeNode::new(v)));
        n.borrow_mut().left = l;
        n.borrow_mut().right = r;
        Some(n)
    }

    #[test]
    fn test_max_path() {
        // [1,2,3] -> 6
        assert_eq!(Solution::max_path_sum(wc(1, node(2), node(3))), 6);
        // [-10,9,20,null,null,15,7] -> 42
        assert_eq!(Solution::max_path_sum(wc(-10, node(9), wc(20, node(15), node(7)))), 42);
    }
}
```

**Complexity:** O(n) time, O(h) space.

**Rust note:** `i32::MIN` as the initial `ans` handles trees with all-negative values
(a single node is still a valid path).

---

### Problem 4 — LC #1372: Longest ZigZag Path in a Binary Tree

**Difficulty:** Medium

#### Problem Statement

A ZigZag path alternates direction (left, right, left, ... or right, left, right, ...).
Return the **number of edges** in the longest such path.

#### DP State + Recurrence

DFS with directional state:

```
dfs(node, came_from_right, length):
    update ans with length
    if came_from_right:
        continue zigzag → go left (length+1)
        restart          → go right (length=1)
    else:
        continue zigzag → go right (length+1)
        restart          → go left  (length=1)
```

#### Solution

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug, PartialEq, Eq)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<Rc<RefCell<TreeNode>>>,
    pub right: Option<Rc<RefCell<TreeNode>>>,
}
impl TreeNode {
    pub fn new(val: i32) -> Self { TreeNode { val, left: None, right: None } }
}
type TreeNodeRef = Option<Rc<RefCell<TreeNode>>>;

struct Solution;
impl Solution {
    pub fn longest_zig_zag(root: TreeNodeRef) -> i32 {
        let mut ans = 0i32;
        fn dfs(node: &TreeNodeRef, went_right: bool, len: i32, ans: &mut i32) {
            if let Some(n) = node {
                *ans = (*ans).max(len);
                let l = n.borrow().left.clone();
                let r = n.borrow().right.clone();
                if went_right {
                    dfs(&l, false, len + 1, ans); // continue zigzag: go left
                    dfs(&r, true,  1,       ans); // restart going right
                } else {
                    dfs(&r, true,  len + 1, ans); // continue zigzag: go right
                    dfs(&l, false, 1,       ans); // restart going left
                }
            }
        }
        if let Some(n) = &root {
            let l = n.borrow().left.clone();
            let r = n.borrow().right.clone();
            dfs(&l, false, 1, &mut ans); // start by going left from root
            dfs(&r, true,  1, &mut ans); // start by going right from root
        }
        ans
    }
}

#[cfg(test)]
mod tests_1372 {
    use super::*;
    use std::cell::RefCell;
    use std::rc::Rc;

    fn node(v: i32) -> TreeNodeRef { Some(Rc::new(RefCell::new(TreeNode::new(v)))) }

    #[test]
    fn test_zigzag() {
        assert_eq!(Solution::longest_zig_zag(node(1)), 0); // single node
        // Build: root ->right->left->right (3 edges)
        let n4 = node(1);
        let n3 = Rc::new(RefCell::new(TreeNode::new(1)));
        n3.borrow_mut().right = n4;
        let n2 = Rc::new(RefCell::new(TreeNode::new(1)));
        n2.borrow_mut().left = Some(n3);
        let root = Rc::new(RefCell::new(TreeNode::new(1)));
        root.borrow_mut().right = Some(n2);
        assert_eq!(Solution::longest_zig_zag(Some(root)), 3);
    }
}
```

**Complexity:** O(n) time, O(h) space.

**Rust note:** A nested `fn` (not a closure) captures no environment, so `ans` is
passed explicitly as `&mut i32`. This is idiomatic when the helper needs mutation but
closures would create borrow conflicts.

---

### Problem 5 — LC #2246: Longest Path With Different Adjacent Characters

**Difficulty:** Hard

#### Problem Statement

Given a tree with `n` nodes (parent array + label string), find the longest path
where no two adjacent nodes share the same label.

**Input type:** `parent: Vec<i32>, s: String` — this is a **general tree**, not a
binary tree. No `TreeNode` needed.

#### DP State + Recurrence

```
dfs(node) → longest valid arm starting at this node going downward

For each child c where s[c] != s[node]:
    collect the arm length = dfs(c)

Keep top-2 valid arms (top2[0] >= top2[1]).
path through node = top2[0] + top2[1] + 1
return top2[0] + 1  (single arm for parent)
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn longest_path(parent: Vec<i32>, s: String) -> i32 {
        let n = parent.len();
        let s = s.as_bytes();
        let mut children: Vec<Vec<usize>> = vec![vec![]; n];
        for i in 1..n {
            children[parent[i] as usize].push(i);
        }
        let mut ans = 1i32;
        Self::dfs(0, &children, s, &mut ans);
        ans
    }

    // Returns longest arm going downward from `node`
    fn dfs(node: usize, children: &[Vec<usize>], s: &[u8], ans: &mut i32) -> i32 {
        let mut top2 = [0i32; 2]; // top two valid child arms
        for &c in &children[node] {
            let arm = Self::dfs(c, children, s, ans);
            if s[c] != s[node] {
                // can extend path through this child
                if arm > top2[0] { top2[1] = top2[0]; top2[0] = arm; }
                else if arm > top2[1] { top2[1] = arm; }
            }
        }
        *ans = (*ans).max(top2[0] + top2[1] + 1);
        top2[0] + 1
    }
}

#[cfg(test)]
mod tests_2246 {
    use super::*;

    #[test]
    fn test_longest_path() {
        // parent=[-1,0,0,1,1,2], s="abacbe" -> 3
        assert_eq!(Solution::longest_path(vec![-1,0,0,1,1,2], "abacbe".to_string()), 3);
        // parent=[-1,0,0,0], s="aabc" -> 3
        assert_eq!(Solution::longest_path(vec![-1,0,0,0], "aabc".to_string()), 3);
    }
}
```

**Complexity:** O(n) time, O(n) space.

**Rust note:** `s.as_bytes()` returns `&[u8]`, making single-char comparison with
`!=` fast and avoiding UTF-8 decoding overhead.

---

### Problem 6 — LC #1519: Number of Nodes in the Sub-Tree With the Same Label

**Difficulty:** Medium

#### Problem Statement

Given an undirected tree with `n` nodes (edge list + label string), for each node
return the count of nodes in its subtree (including itself) with the same label.

**Input type:** `n: i32, edges: Vec<Vec<i32>>, labels: String` — general tree via
adjacency list.

#### DP State + Recurrence

```
dfs(node, parent) → [i32; 26]  (count of each label in this subtree)

Accumulate child counts, then:
ans[node] = cnt[(label[node] - 'a') as usize]
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn count_sub_tree_nums_with_same_label(
        n: i32, edges: Vec<Vec<i32>>, labels: String,
    ) -> Vec<i32> {
        let n = n as usize;
        let s = labels.as_bytes();
        let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
        for e in &edges {
            let (u, v) = (e[0] as usize, e[1] as usize);
            adj[u].push(v);
            adj[v].push(u);
        }
        let mut ans = vec![0i32; n];
        Self::dfs(0, usize::MAX, &adj, s, &mut ans);
        ans
    }

    fn dfs(node: usize, par: usize, adj: &[Vec<usize>],
           s: &[u8], ans: &mut Vec<i32>) -> [i32; 26] {
        let mut cnt = [0i32; 26];
        cnt[(s[node] - b'a') as usize] = 1;
        for &nb in &adj[node] {
            if nb == par { continue; }
            let sub = Self::dfs(nb, node, adj, s, ans);
            for i in 0..26 { cnt[i] += sub[i]; }
        }
        ans[node] = cnt[(s[node] - b'a') as usize];
        cnt
    }
}

#[cfg(test)]
mod tests_1519 {
    use super::*;

    #[test]
    fn test_subtree_labels() {
        let edges = vec![vec![0,1],vec![0,2],vec![1,4],vec![1,5],vec![2,3],vec![2,6]];
        assert_eq!(
            Solution::count_sub_tree_nums_with_same_label(7, edges, "abaedcd".to_string()),
            vec![2, 1, 1, 1, 1, 1, 1]
        );
        let edges2 = vec![vec![0,1],vec![1,2],vec![2,3]];
        assert_eq!(
            Solution::count_sub_tree_nums_with_same_label(4, edges2, "bbbb".to_string()),
            vec![4, 3, 2, 1]
        );
    }
}
```

**Complexity:** O(26n) = O(n) time, O(n) space.

**Rust note:** Returning `[i32; 26]` by value from a recursive function is fine —
Rust can stack-allocate it and the optimizer will elide copies when possible.

---

## Section 5: Bitmask DP

DP over subsets of a small set (n ≤ 20 typically). State `dp[mask]` represents some
optimum achieved for exactly the elements whose bits are set in `mask`.

**State space:** `1 << n` states, often iterated with `for mask in 0..(1 << n)`.

**Submask iteration (canonical pattern):**

```rust
// Iterate all non-empty submasks of `mask`
let mut sub = mask;
while sub > 0 {
    // process sub
    sub = (sub - 1) & mask; // strips lowest set bit, staying within mask
}
// If you need the empty submask too, process it after the loop.
```

---

### Problem 7 — LC #526: Beautiful Arrangement

**Difficulty:** Medium

#### Problem Statement

Count permutations of `1..=n` where position `i` (1-indexed) either divides or is
divisible by the number placed there.

#### DP State + Recurrence

```
dp[mask] = number of valid arrangements using the numbers whose bits are set in mask.
position  = popcount(mask)   (1-indexed: next slot to fill)

for each unset bit i in mask:
    if (i+1) % pos == 0 OR pos % (i+1) == 0:
        dp[mask | (1<<i)] += dp[mask]
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn count_arrangement(n: i32) -> i32 {
        let n = n as usize;
        let mut dp = vec![0i32; 1 << n];
        dp[0] = 1;
        for mask in 0..(1usize << n) {
            let pos = mask.count_ones() as usize + 1; // next 1-indexed position
            for i in 0..n {
                if mask & (1 << i) != 0 { continue; }
                let num = i + 1;
                if num % pos == 0 || pos % num == 0 {
                    dp[mask | (1 << i)] += dp[mask];
                }
            }
        }
        dp[(1 << n) - 1]
    }
}

#[cfg(test)]
mod tests_526 {
    use super::*;

    #[test]
    fn test_beautiful() {
        assert_eq!(Solution::count_arrangement(1), 1);
        assert_eq!(Solution::count_arrangement(2), 2);
        assert_eq!(Solution::count_arrangement(3), 3);
        assert_eq!(Solution::count_arrangement(4), 8);
    }
}
```

**Complexity:** O(2^n * n) time, O(2^n) space.

**Rust note:** `mask.count_ones()` is a single CPU instruction (`POPCNT`). Use it
freely — it does not require a loop.

---

### Problem 8 — LC #1986: Minimum Number of Work Sessions to Finish the Tasks

**Difficulty:** Medium

#### Problem Statement

Given `tasks[i]` (task duration) and `session_time` (max time per session), return
the minimum number of work sessions needed to finish all tasks (each task in exactly
one session).

#### DP State + Recurrence

```
dp[mask] = (min_sessions, max_remaining_time)
           minimize sessions first, then maximize remaining time (greedy packing)

For each unfinished task i not in mask:
    if remaining >= tasks[i]:  same session, remaining -= tasks[i]
    else:                      new session,  remaining = session_time - tasks[i]
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn min_sessions(tasks: Vec<i32>, session_time: i32) -> i32 {
        let n = tasks.len();
        let full = (1usize << n) - 1;
        // (sessions, remaining_time_in_last_session)
        let mut dp: Vec<(i32, i32)> = vec![(i32::MAX, 0); 1 << n];
        dp[0] = (1, session_time); // 1 session, full time available

        for mask in 0..=full {
            let (sess, rem) = dp[mask];
            if sess == i32::MAX { continue; }
            for i in 0..n {
                if mask & (1 << i) != 0 { continue; }
                let t = tasks[i];
                let new_mask = mask | (1 << i);
                let new_state = if rem >= t {
                    (sess, rem - t)
                } else {
                    (sess + 1, session_time - t)
                };
                let cur = dp[new_mask];
                // prefer fewer sessions; on tie, more remaining time = better packing
                if new_state.0 < cur.0 || (new_state.0 == cur.0 && new_state.1 > cur.1) {
                    dp[new_mask] = new_state;
                }
            }
        }
        dp[full].0
    }
}

#[cfg(test)]
mod tests_1986 {
    use super::*;

    #[test]
    fn test_min_sessions() {
        assert_eq!(Solution::min_sessions(vec![1, 2, 3], 3), 2);
        assert_eq!(Solution::min_sessions(vec![3, 1, 3, 1, 1], 8), 2);
    }
}
```

**Complexity:** O(2^n * n) time, O(2^n) space.

**Rust note:** Storing a tuple `(i32, i32)` per state is cleaner than two separate
arrays and avoids index drift bugs.

---

### Problem 9 — LC #1494: Parallel Courses II

**Difficulty:** Hard

#### Problem Statement

There are `n` courses with prerequisite dependencies. Each semester you can take at
most `k` courses (all prerequisites must be done). Return the minimum number of
semesters to finish all courses.

#### DP State + Recurrence

```
dp[mask] = min semesters to complete exactly the courses in mask

For each mask:
    can_take = courses not in mask whose prerequisites ⊆ mask
    For each subset s of can_take with |s| <= k:
        dp[mask | s] = min(dp[mask | s], dp[mask] + 1)

Submask iteration: while sub > 0 { use sub; sub = (sub-1) & can_take; }
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn min_number_of_semesters(n: i32, relations: Vec<Vec<i32>>, k: i32) -> i32 {
        let n = n as usize;
        let k = k as usize;
        let mut prereq = vec![0usize; n];
        for r in &relations {
            let (u, v) = (r[0] as usize - 1, r[1] as usize - 1);
            prereq[v] |= 1 << u;
        }
        let full = (1usize << n) - 1;
        let mut dp = vec![i32::MAX; 1 << n];
        dp[0] = 0;

        for mask in 0..=full {
            if dp[mask] == i32::MAX { continue; }
            // Courses available this semester
            let mut can_take = 0usize;
            for i in 0..n {
                if mask & (1 << i) == 0 && (prereq[i] & mask) == prereq[i] {
                    can_take |= 1 << i;
                }
            }
            // Iterate all subsets of can_take with popcount <= k
            let mut sub = can_take;
            loop {
                if sub.count_ones() as usize <= k {
                    let new_mask = mask | sub;
                    if dp[new_mask] > dp[mask] + 1 {
                        dp[new_mask] = dp[mask] + 1;
                    }
                }
                if sub == 0 { break; }
                sub = (sub - 1) & can_take;
            }
        }
        dp[full]
    }
}

#[cfg(test)]
mod tests_1494 {
    use super::*;

    #[test]
    fn test_parallel_courses() {
        assert_eq!(
            Solution::min_number_of_semesters(4, vec![vec![2,1],vec![3,1],vec![1,4]], 2),
            3
        );
        assert_eq!(
            Solution::min_number_of_semesters(5, vec![vec![2,1],vec![3,1],vec![4,1],vec![1,5]], 2),
            4
        );
    }
}
```

**Complexity:** O(3^n) time (submask enumeration), O(2^n) space.

**Rust note:** The submask loop `sub = (sub - 1) & can_take` enumerates all
2^|can_take| subsets in O(2^|can_take|) — over all masks, total work is O(3^n)
by the identity Σ C(n,k)·2^k = 3^n.

---

### Problem 10 — LC #2305: Fair Distribution of Cookies

**Difficulty:** Medium

#### Problem Statement

Distribute `n` cookie bags among `k` children. The **unfairness** is the maximum
cookies any child receives. Return the minimum possible unfairness.

#### DP State + Recurrence

```
ssum[mask] = total cookies in subset mask (precomputed in O(2^n))

dp[j][mask] = min unfairness distributing subset mask among j children

dp[j][mask] = min over all submasks s of mask:
                max(dp[j-1][mask ^ s], ssum[s])
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn distribute_cookies(cookies: Vec<i32>, k: i32) -> i32 {
        let n = cookies.len();
        let k = k as usize;
        // Precompute subset sums
        let mut ssum = vec![0i32; 1 << n];
        for mask in 1..(1usize << n) {
            let lsb = mask & mask.wrapping_neg();
            let i = lsb.trailing_zeros() as usize;
            ssum[mask] = ssum[mask ^ lsb] + cookies[i];
        }
        let full = (1usize << n) - 1;
        let mut dp = vec![vec![i32::MAX; 1 << n]; k + 1];
        dp[0][0] = 0;

        for j in 1..=k {
            for mask in 0..=full {
                let mut sub = mask;
                loop {
                    if dp[j-1][mask ^ sub] != i32::MAX {
                        let val = dp[j-1][mask ^ sub].max(ssum[sub]);
                        if val < dp[j][mask] { dp[j][mask] = val; }
                    }
                    if sub == 0 { break; }
                    sub = (sub - 1) & mask;
                }
            }
        }
        dp[k][full]
    }
}

#[cfg(test)]
mod tests_2305 {
    use super::*;

    #[test]
    fn test_fair_cookies() {
        assert_eq!(Solution::distribute_cookies(vec![8,15,10,20,8], 2), 31);
        assert_eq!(Solution::distribute_cookies(vec![6,1,3,2,2,4,1,2], 3), 7);
    }
}
```

**Complexity:** O(k * 3^n) time, O(k * 2^n) space.

**Rust note:** `mask.wrapping_neg()` computes two's complement negation without
overflow checks, equivalent to `-(mask as i64) as usize` but cleaner.
`trailing_zeros()` finds the lowest set bit index in one instruction.

---

### Problem 11 — LC #847: Shortest Path Visiting All Nodes (BFS + Bitmask)

**Difficulty:** Hard

#### Problem Statement

Given an undirected graph, find the shortest path (in edges) that visits every node
at least once. You may start at any node and revisit nodes.

**Technique:** BFS on the state `(current_node, visited_mask)`.

#### DP State + Recurrence

```
state   = (node, visited_mask)
dist[node][mask] = min edges to reach `node` with exactly `mask` visited

Initialize: dist[i][1<<i] = 0 for all i (start anywhere)
BFS: from (node, mask), move to neighbor nb:
     new_mask = mask | (1 << nb)
     if dist[nb][new_mask] == MAX: enqueue, dist[nb][new_mask] = dist[node][mask] + 1
```

#### Solution

```rust
use std::collections::VecDeque;

struct Solution;
impl Solution {
    pub fn shortest_path_length(graph: Vec<Vec<i32>>) -> i32 {
        let n = graph.len();
        let full = (1 << n) - 1;
        let mut dist = vec![vec![i32::MAX; 1 << n]; n];
        let mut q: VecDeque<(usize, usize)> = VecDeque::new();

        // Start BFS from every node simultaneously
        for i in 0..n {
            dist[i][1 << i] = 0;
            q.push_back((i, 1 << i));
        }
        while let Some((node, mask)) = q.pop_front() {
            if mask == full { return dist[node][mask]; }
            for &nb in &graph[node] {
                let nb = nb as usize;
                let new_mask = mask | (1 << nb);
                if dist[nb][new_mask] == i32::MAX {
                    dist[nb][new_mask] = dist[node][mask] + 1;
                    q.push_back((nb, new_mask));
                }
            }
        }
        0
    }
}

#[cfg(test)]
mod tests_847 {
    use super::*;

    #[test]
    fn test_visit_all_nodes() {
        // Star graph: 0-1, 0-2, 0-3 -> answer 4 (1->0->2->0->3 or similar)
        assert_eq!(
            Solution::shortest_path_length(vec![vec![1,2,3],vec![0],vec![0],vec![0]]),
            4
        );
        // 0-1-2, 1-4, 2-3, 2-4 -> answer 4
        assert_eq!(
            Solution::shortest_path_length(
                vec![vec![1],vec![0,2,4],vec![1,3,4],vec![2],vec![1,2]]
            ),
            4
        );
    }
}
```

**Complexity:** O(2^n * n) time and space.

**Rust note:** Multi-source BFS (all starts enqueued simultaneously) ensures the first
time `mask == full` is reached it is the shortest path — classic BFS optimality.

---

### Problem 12 — LC #1125: Smallest Sufficient Team

**Difficulty:** Hard

#### Problem Statement

Given required skills and a list of people (each knowing some skills), find the
smallest team covering all required skills. Return any valid team.

#### DP State + Recurrence

```
skill_mask[i] = bitmask of skills person i has
dp[mask] = bitmask of team members (over people) covering exactly skill set `mask`

For each mask, try adding person j:
    new_mask = mask | skill_mask[j]
    if team for new_mask is larger: update dp[new_mask] = dp[mask] | (1<<j)
```

#### Solution

```rust
use std::collections::HashMap;

struct Solution;
impl Solution {
    pub fn smallest_sufficient_team(
        req_skills: Vec<String>,
        people: Vec<Vec<String>>,
    ) -> Vec<i32> {
        let m = req_skills.len();
        let skill_idx: HashMap<&str, usize> = req_skills.iter()
            .enumerate().map(|(i, s)| (s.as_str(), i)).collect();

        let person_mask: Vec<usize> = people.iter().map(|skills| {
            skills.iter().fold(0, |acc, s| acc | (1 << skill_idx[s.as_str()]))
        }).collect();

        let full = (1usize << m) - 1;
        // dp[mask] = bitmask over people (u64 supports up to 60 people per constraints)
        let mut dp = vec![u64::MAX; 1 << m];
        dp[0] = 0;

        for mask in 0..=full {
            if dp[mask] == u64::MAX { continue; }
            for (j, &pm) in person_mask.iter().enumerate() {
                let new_mask = mask | pm;
                let candidate = dp[mask] | (1u64 << j);
                if dp[new_mask] == u64::MAX
                    || candidate.count_ones() < dp[new_mask].count_ones()
                {
                    dp[new_mask] = candidate;
                }
            }
        }

        (0..people.len())
            .filter(|&i| dp[full] & (1u64 << i) != 0)
            .map(|i| i as i32)
            .collect()
    }
}

#[cfg(test)]
mod tests_1125 {
    use super::*;

    #[test]
    fn test_sufficient_team() {
        let req = vec!["java","nodejs","reactjs"]
            .iter().map(|s| s.to_string()).collect();
        let people = vec![
            vec!["java"], vec!["nodejs"], vec!["nodejs","reactjs"],
        ].iter().map(|p| p.iter().map(|s| s.to_string()).collect()).collect();
        // person 0 (java) + person 2 (nodejs+reactjs) -> [0, 2]
        assert_eq!(Solution::smallest_sufficient_team(req, people), vec![0, 2]);
    }
}
```

**Complexity:** O(2^m * p) time, O(2^m) space (m = skill count ≤ 16, p = people ≤ 60).

**Rust note:** Using `u64` to encode team membership as a bitmask is idiomatic when
the set size is bounded and small (≤ 64). `.count_ones()` compares team sizes in O(1).

---

### Problem 13 — LC #1434: Number of Ways to Wear Different Hats to Each Person

**Difficulty:** Hard

#### Problem Statement

There are `n` people (n ≤ 10) and 40 hats. Each person has a preference list.
Count the number of ways to assign each person a distinct hat they like.

**Key insight:** Iterate hats (outer), maintain `dp[person_mask]` = ways to assign
hats 1..h to exactly the people in `person_mask`. Cloning `dp` each hat round ensures
each hat is used at most once (0-1 knapsack style).

#### DP State + Recurrence

```
dp[mask] = ways to assign hats so far to people in mask

For each hat h:
    new_dp = dp.clone()
    for each person p who likes hat h:
        if mask has bit p set:
            new_dp[mask] += dp[mask ^ (1<<p)]
    dp = new_dp
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn number_ways(hats: Vec<Vec<i32>>) -> i32 {
        const MOD: u64 = 1_000_000_007;
        let n = hats.len();
        let full = (1usize << n) - 1;

        // Invert: hat -> list of people who like it
        let mut hat_to_people: Vec<Vec<usize>> = vec![vec![]; 41];
        for (person, likes) in hats.iter().enumerate() {
            for &h in likes {
                hat_to_people[h as usize].push(person);
            }
        }

        let mut dp = vec![0u64; 1 << n];
        dp[0] = 1;

        for h in 1..=40usize {
            if hat_to_people[h].is_empty() { continue; }
            let prev = dp.clone(); // snapshot: hat h used at most once
            for mask in 0..=full {
                for &p in &hat_to_people[h] {
                    if mask & (1 << p) != 0 {
                        let prev_mask = mask ^ (1 << p);
                        dp[mask] = (dp[mask] + prev[prev_mask]) % MOD;
                    }
                }
            }
        }
        dp[full] as i32
    }
}

#[cfg(test)]
mod tests_1434 {
    use super::*;

    #[test]
    fn test_hats() {
        // 3 people: [3,4],[4,5],[5] -> only (3,4,5) works -> 1
        assert_eq!(Solution::number_ways(vec![vec![3,4],vec![4,5],vec![5]]), 1);
        // 2 people: [1,2],[1,2] -> (1,2) or (2,1) -> 2
        assert_eq!(Solution::number_ways(vec![vec![1,2],vec![1,2]]), 2);
        // 3 people each with exactly 1 unique hat -> 1
        assert_eq!(Solution::number_ways(vec![vec![1],vec![2],vec![3]]), 1);
    }
}
```

**Complexity:** O(40 * 2^n * n) time, O(2^n) space (n ≤ 10 so 2^10 = 1024 states).

**Rust note:** `dp.clone()` is O(2^n) = O(1024) per hat — negligible. This is the
cleanest way to implement "use each item at most once" in bitmask DP.

---

### Problem 14 — LC #943: Find the Shortest Superstring (TSP Variant)

**Difficulty:** Hard

#### Problem Statement

Given an array of words, find the shortest string that contains each word as a
substring. Return any shortest superstring. This is the classic Shortest Common
Superstring problem, equivalent to TSP.

#### DP State + Recurrence

```
overlap[i][j] = chars of words[j] skippable if words[i] immediately precedes it
dp[mask][last] = max total overlap when mask words used, last word = `last`

For each (mask, last) where dp[mask][last] >= 0:
    for next not in mask:
        dp[mask|(1<<next)][next] = max(..., dp[mask][last] + overlap[last][next])
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn shortest_superstring(words: Vec<String>) -> String {
        let n = words.len();
        // Precompute pairwise overlaps
        let mut ov = vec![vec![0usize; n]; n];
        for i in 0..n {
            for j in 0..n {
                if i == j { continue; }
                let a = words[i].as_bytes();
                let b = words[j].as_bytes();
                for k in (1..=a.len().min(b.len())).rev() {
                    if a[a.len()-k..] == b[..k] { ov[i][j] = k; break; }
                }
            }
        }
        let full = (1usize << n) - 1;
        // dp[mask][last] = max overlap; -1 = state not reachable
        let mut dp  = vec![vec![-1i64; n]; 1 << n];
        let mut par = vec![vec![-1i32; n]; 1 << n];
        for i in 0..n { dp[1 << i][i] = 0; } // single-word seeds

        for mask in 1..=full {
            for last in 0..n {
                if dp[mask][last] < 0 { continue; }
                if mask & (1 << last) == 0 { continue; }
                for next in 0..n {
                    if mask & (1 << next) != 0 { continue; }
                    let new_mask = mask | (1 << next);
                    let val = dp[mask][last] + ov[last][next] as i64;
                    if val > dp[new_mask][next] {
                        dp[new_mask][next] = val;
                        par[new_mask][next] = last as i32;
                    }
                }
            }
        }
        // Find best ending word
        let best_last = (0..n).max_by_key(|&i| dp[full][i]).unwrap();
        // Reconstruct order
        let mut order = Vec::new();
        let mut mask = full;
        let mut cur = best_last;
        loop {
            order.push(cur);
            let p = par[mask][cur];
            if p < 0 { break; }
            mask ^= 1 << cur;
            cur = p as usize;
        }
        order.reverse();
        // Build superstring
        let mut result = words[order[0]].clone();
        for k in 1..order.len() {
            result.push_str(&words[order[k]][ov[order[k-1]][order[k]]..]);
        }
        result
    }
}

#[cfg(test)]
mod tests_943 {
    use super::*;

    fn check(words: Vec<&str>, expected_len: usize) {
        let ws: Vec<String> = words.iter().map(|s| s.to_string()).collect();
        let result = Solution::shortest_superstring(ws.clone());
        for w in &ws {
            assert!(result.contains(w.as_str()), "{} not in result '{}'", w, result);
        }
        assert_eq!(result.len(), expected_len, "got: {}", result);
    }

    #[test]
    fn test_superstring() {
        // ["alex","loves","leetcode"] -> no overlaps -> 4+5+8 = 17
        check(vec!["alex","loves","leetcode"], 17);
        // ["catg","ctaagt","gcta","ttca","atgcatc"] -> optimal overlap -> 16
        check(vec!["catg","ctaagt","gcta","ttca","atgcatc"], 16);
    }
}
```

**Complexity:** O(n^2 * 2^n) time, O(n * 2^n) space.

**Rust note:** Using `-1i64` as a sentinel distinguishes "unreachable state" from
"zero overlap." The `par` array stores parent indices for path reconstruction — the
same technique as Dijkstra path reconstruction.

---

## Section 6: State Machine DP

DP where the state includes an explicit **mode** or **phase**. Transitions represent
allowed phase changes. Stock trading problems are the canonical example.

**Template:** define named variables for each state, update them simultaneously
each day using the *previous day's* values (or equivalently, update in the right
order so future states don't pollute past ones).

---

### Problem 15 — LC #309: Best Time to Buy and Sell Stock with Cooldown

**Difficulty:** Medium

#### State Machine

```
         sell
  held --------> sold
   ^               |
   |  rest         | cooldown (1 day)
   <--- rest <-----+
        ^
        | rest stays rest
        |
```

```
States:
  held  = holding stock       (can sell → sold)
  sold  = just sold           (mandatory: must rest tomorrow)
  rest  = not holding, rested (can buy → held, or stay → rest)

Transitions:
  held' = max(held, rest - price)   // keep holding OR buy from rest
  sold' = held + price              // sell what we hold
  rest' = max(rest, sold)           // idle or come off cooldown
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn max_profit(prices: Vec<i32>) -> i32 {
        if prices.len() < 2 { return 0; }
        let (mut held, mut sold, mut rest) = (-prices[0], i32::MIN, 0);
        for i in 1..prices.len() {
            let (ph, ps, pr) = (held, sold, rest);
            held = ph.max(pr - prices[i]); // keep holding OR buy
            sold = ph + prices[i];          // sell
            rest = pr.max(ps);              // idle OR come off cooldown
        }
        sold.max(rest)
    }
}

#[cfg(test)]
mod tests_309 {
    use super::*;

    #[test]
    fn test_cooldown() {
        assert_eq!(Solution::max_profit(vec![1,2,3,0,2]), 3);
        assert_eq!(Solution::max_profit(vec![1]), 0);
        assert_eq!(Solution::max_profit(vec![2,1,4]), 3);
    }
}
```

**Complexity:** O(n) time, O(1) space.

**Rust note:** Snapshotting `(ph, ps, pr)` before updates is the Rust idiom for
simultaneous state transitions — no temporary variables needed for individual fields.

---

### Problem 16 — LC #188: Best Time to Buy and Sell Stock IV

**Difficulty:** Hard

#### Problem Statement

At most `k` transactions (buy + sell = 1 transaction). Return max profit.

#### State Machine (k transactions)

```
buy[j]  = max profit after the j-th buy  (holding after j buys)
sell[j] = max profit after the j-th sell (not holding after j sells)

buy[j]  = max(buy[j],  sell[j-1] - price)
sell[j] = max(sell[j], buy[j]    + price)

Process j from k down to 1 to avoid using the same price twice.
Special case: if k >= n/2, unlimited transactions (every profitable day).
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn max_profit(k: i32, prices: Vec<i32>) -> i32 {
        let n = prices.len();
        let k = k as usize;
        if n == 0 || k == 0 { return 0; }
        // Unlimited transactions when k is large enough
        if k >= n / 2 {
            return prices.windows(2).map(|w| (w[1] - w[0]).max(0)).sum();
        }
        let mut buy  = vec![i32::MIN; k + 1];
        let mut sell = vec![0i32;     k + 1];
        for &p in &prices {
            for j in (1..=k).rev() {
                sell[j] = sell[j].max(buy[j] + p);
                buy[j]  = buy[j].max(sell[j-1] - p);
            }
        }
        *sell.last().unwrap()
    }
}

#[cfg(test)]
mod tests_188 {
    use super::*;

    #[test]
    fn test_k_transactions() {
        assert_eq!(Solution::max_profit(2, vec![2,4,1]), 2);
        assert_eq!(Solution::max_profit(2, vec![3,2,6,5,0,3]), 7);
        assert_eq!(Solution::max_profit(0, vec![1,2,3]), 0);
        assert_eq!(Solution::max_profit(1, vec![1,2]), 1);
    }
}
```

**Complexity:** O(n * k) time, O(k) space.

**Rust note:** `prices.windows(2)` yields overlapping pairs `[a, b]` — elegant
for "consecutive difference" problems. The `.rev()` inner loop prevents double-use
of the same price within one day (same as 0-1 knapsack).

---

### Problem 17 — LC #123: Best Time to Buy and Sell Stock III

**Difficulty:** Hard

#### Problem Statement

At most 2 transactions. Return max profit. Special case of LC #188 with k=2.

#### State Machine (exactly 4 states)

```
     buy1 → sell1 → buy2 → sell2
     (after 1st buy) (after 1st sell) (after 2nd buy) (after 2nd sell)

buy1  = max(buy1,        -price)          // first buy
sell1 = max(sell1, buy1 + price)          // first sell
buy2  = max(buy2,  sell1 - price)         // second buy
sell2 = max(sell2, buy2 + price)          // second sell
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn max_profit(prices: Vec<i32>) -> i32 {
        let (mut buy1, mut sell1, mut buy2, mut sell2) =
            (i32::MIN, 0, i32::MIN, 0);
        for &p in &prices {
            buy1  = buy1.max(-p);
            sell1 = sell1.max(buy1 + p);
            buy2  = buy2.max(sell1 - p);
            sell2 = sell2.max(buy2 + p);
        }
        sell2
    }
}

#[cfg(test)]
mod tests_123 {
    use super::*;

    #[test]
    fn test_two_transactions() {
        assert_eq!(Solution::max_profit(vec![3,3,5,0,0,3,1,4]), 6);
        assert_eq!(Solution::max_profit(vec![1,2,3,4,5]), 4);
        assert_eq!(Solution::max_profit(vec![7,6,4,3,1]), 0);
        assert_eq!(Solution::max_profit(vec![1]), 0);
    }
}
```

**Complexity:** O(n) time, O(1) space.

**Rust note:** No arrays needed — 4 scalar variables suffice. The sequential update
order (`buy1` before `sell1` before `buy2` before `sell2`) is safe because each day's
`buy1` result is immediately usable for `sell1` of the same day (allowed: buying and
selling on the same day counts as 0 profit).

---

### Problem 18 — LC #1911: Maximum Alternating Subsequence Sum

**Difficulty:** Medium

#### Problem Statement

An **alternating subsequence** alternates addition and subtraction of selected
elements (first element added, second subtracted, ...). Return the maximum such sum.

#### State Machine

```
even = max profit when we're about to pick an even-indexed element (add it)
odd  = max profit when we're about to pick an odd-indexed element  (subtract it)

For each x in nums:
    new_even = max(even, odd + x)   // skip x (stay at even) OR pick x after an odd pick
    new_odd  = max(odd,  even - x)  // skip x (stay at odd)  OR pick x after an even pick
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn max_alternating_sum(nums: Vec<i32>) -> i64 {
        let (mut even, mut odd) = (0i64, 0i64);
        for &x in &nums {
            let x = x as i64;
            let ne = even.max(odd + x);
            let no = odd.max(even - x);
            even = ne;
            odd  = no;
        }
        even
    }
}

#[cfg(test)]
mod tests_1911 {
    use super::*;

    #[test]
    fn test_alternating_sum() {
        assert_eq!(Solution::max_alternating_sum(vec![4,2,5,3]), 7);
        assert_eq!(Solution::max_alternating_sum(vec![5,6,7,8]), 8);
        assert_eq!(Solution::max_alternating_sum(vec![6,2,1,2,4,5]), 10);
    }
}
```

**Complexity:** O(n) time, O(1) space.

**Rust note:** Snapshot `ne` and `no` before assigning back to `even`/`odd` to
avoid using updated values within the same step. Returning `i64` matches the
LeetCode signature and avoids overflow with large inputs.

---

### Problem 19 — LC #2826: Sorting Three Groups

**Difficulty:** Medium

#### Problem Statement

Given an array with values only in `{1, 2, 3}`, find the minimum number of elements
to **delete** so that the remaining array is non-decreasing.

Equivalently: find the **longest non-decreasing subsequence** (values from {1,2,3}),
then answer = n − LIS_length.

#### State Machine

```
dp[v] = length of longest non-decreasing subsequence ending with value v (v ∈ {1,2,3})

For each x in nums:
    dp[x] = max(dp[1..=x]) + 1
```

#### Solution

```rust
struct Solution;
impl Solution {
    pub fn minimum_operations(nums: Vec<i32>) -> i32 {
        let mut dp = [0i32; 4]; // dp[1], dp[2], dp[3]; dp[0] unused
        for &x in &nums {
            let x = x as usize;
            let best = (1..=x).map(|j| dp[j]).max().unwrap_or(0);
            dp[x] = dp[x].max(best + 1);
        }
        nums.len() as i32 - dp[1].max(dp[2]).max(dp[3])
    }
}

#[cfg(test)]
mod tests_2826 {
    use super::*;

    #[test]
    fn test_sorting_groups() {
        assert_eq!(Solution::minimum_operations(vec![2,1,3,2,1]), 3);
        assert_eq!(Solution::minimum_operations(vec![1,3,2,1,3,3]), 2);
        assert_eq!(Solution::minimum_operations(vec![2,2,2,2,3,3]), 0);
    }
}
```

**Complexity:** O(n) time (inner loop is at most 3 steps), O(1) space.

**Rust note:** `(1..=x).map(|j| dp[j]).max()` returns `Option<i32>` — use
`.unwrap_or(0)` for the x=1 base case where the range is `1..=1` (non-empty, so
`max()` always returns `Some`). The range is bounded by 3, making this O(1) per step.

---

## Summary Table

| # | Problem | Section | Pattern | Time | Space |
|---|---------|---------|---------|------|-------|
| 337 | House Robber III | Tree DP | Rob/skip post-order | O(n) | O(h) |
| 968 | Binary Tree Cameras | Tree DP | 3-state post-order | O(n) | O(h) |
| 124 | Max Path Sum | Tree DP | Arm contribution | O(n) | O(h) |
| 1372 | Longest ZigZag | Tree DP | Directional DFS | O(n) | O(h) |
| 2246 | Longest Path Diff Adj | Tree DP | Top-2 child arms | O(n) | O(n) |
| 1519 | Subtree Same Label | Tree DP | Count[26] aggregation | O(26n) | O(n) |
| 526 | Beautiful Arrangement | Bitmask | Build mask forward | O(2^n·n) | O(2^n) |
| 1986 | Min Work Sessions | Bitmask | (sessions, rem) pair | O(2^n·n) | O(2^n) |
| 1494 | Parallel Courses II | Bitmask | Submask prereq check | O(3^n) | O(2^n) |
| 2305 | Fair Cookies | Bitmask | k-round submask | O(k·3^n) | O(k·2^n) |
| 847 | Visit All Nodes | BFS+Bitmask | Multi-source BFS | O(2^n·n) | O(2^n·n) |
| 1125 | Sufficient Team | Bitmask | u64 team encoding | O(2^m·p) | O(2^m) |
| 1434 | Hats to People | Bitmask | Hat-outer, clone prev | O(40·2^n·n) | O(2^n) |
| 943 | Shortest Superstring | Bitmask TSP | Forward build + recon | O(n^2·2^n) | O(n·2^n) |
| 309 | Stock Cooldown | State Machine | held/sold/rest | O(n) | O(1) |
| 188 | Stock k Transactions | State Machine | buy[k]/sell[k] | O(nk) | O(k) |
| 123 | Stock 2 Transactions | State Machine | 4 scalars | O(n) | O(1) |
| 1911 | Alternating Subseq Sum | State Machine | even/odd states | O(n) | O(1) |
| 2826 | Sorting Three Groups | State Machine | LIS on {1,2,3} | O(n) | O(1) |

---

## Key Rust Patterns This Chapter

### Tree DP: clone before recursing

```rust
let left  = n.borrow().left.clone();  // Rc refcount bump — O(1)
let right = n.borrow().right.clone();
let lv = Self::dfs(&left, ans);       // borrow guard is gone
let rv = Self::dfs(&right, ans);
// NEVER: Self::dfs(&n.borrow().left.clone(), ans)  ← holds borrow guard
```

### Bitmask: iterate subsets of a mask

```rust
let mut sub = mask;
loop {
    // process `sub` as a subset of `mask`
    if sub == 0 { break; }
    sub = (sub - 1) & mask; // enumerate all non-empty subsets
}
```

### State Machine: snapshot before updating

```rust
let (ph, ps, pr) = (held, sold, rest); // snapshot
held = ph.max(pr - price);
sold = ph + price;
rest = pr.max(ps);
```

### Bitmask DP 0-1 knapsack (use item at most once)

```rust
let prev = dp.clone(); // snapshot at start of each item
for mask in 0..=full {
    for &p in &item_users {
        if mask & (1 << p) != 0 {
            dp[mask] = (dp[mask] + prev[mask ^ (1 << p)]) % MOD;
        }
    }
}
```

---

## 📝 Part 2 Review Notes

### Tree DP Principles

- **Post-order always**: compute children before the current node.
- **Return type encodes subtree state**: `(rob, skip)` for #337, `i32` state for
  #968, `[i32; 26]` for #1519. Design the return type to carry exactly what the
  parent needs.
- **General trees** (#2246, #1519) use adjacency lists, not `TreeNode`. No need for
  `Rc<RefCell<>>` boilerplate — simpler `Vec<Vec<usize>>` children.
- **Rerooting** (not covered here but natural extension): run two DFS passes to
  compute answers for all possible roots in O(n).

### Bitmask DP Principles

- State space is `1 << n`. Keep n ≤ 20 for memory, ≤ 15-18 for time.
- **Forward building** (iterate mask, extend by one element) is cleaner than
  backward for most problems.
- **Submask enumeration** `sub = (sub-1) & mask` is O(3^n) total — use when you
  need to try all ways to split a mask into two parts.
- For "use item once" (e.g., #1434): clone `dp` before processing each item, read
  from the clone, write to the original.
- **Path reconstruction** requires a `parent` array alongside `dp`. Initialize with
  a sentinel (`-1` or `None`) to mark chain starts.

### State Machine DP Principles

- Draw the state diagram first. Every arrow is a recurrence transition.
- **Snapshot the previous day's values** before updating. The order of updates
  matters: left-to-right in LC #123 is fine because `buy1` feeding `sell1` on the
  same day yields zero-profit same-day round trip.
- For k-transaction problems with large k: use the unlimited-transactions shortcut
  (`prices.windows(2)` sum of positive deltas).
- **Return type matters**: #1911 returns `i64` to avoid overflow — check LeetCode
  signature carefully.

### Common Rust Gotchas in This Chapter

| Gotcha | Fix |
|--------|-----|
| `borrow()` held across recursive call | Always `.clone()` the child ref first |
| `u32::MAX + 1` overflows in debug mode | Use `i32::MAX / 2` or saturating arithmetic |
| `usize` subtraction underflow | Use `wrapping_neg()` or guard with `if sub == 0` |
| Wrong test expectations for bitmask problems | Brute-force verify small inputs |
| `Option::max()` on empty iterator | `.unwrap_or(0)` default |
