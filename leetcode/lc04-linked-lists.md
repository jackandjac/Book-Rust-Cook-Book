# LC-04: Linked Lists

> **Chapter series:** Blind75 / NeetCode150 in Rust — for Java developers.
> **Rust Edition:** 2024 (Rust 1.85+). Each problem's code block is self-contained and runnable. Intro snippets are illustrative fragments.

---

## Why Linked Lists Are Different in Rust

In Java, a linked list node is trivial:

```java
class ListNode {
    int val;
    ListNode next;   // just a reference — GC owns the lifetime
    ListNode(int v) { this.val = v; }
}
```

You can point `next` at any other node, have multiple references to the same node, or let `next` be `null`. The garbage collector handles the rest.

Rust has **no garbage collector**. Every value has exactly one owner, and that owner is responsible for cleaning it up when it goes out of scope. This makes *singly-linked lists* manageable, but anything requiring shared or back-references — doubly-linked lists, nodes with random pointers — requires explicit choices about ownership.

### The Standard LeetCode Node Type

For singly-linked list problems, LeetCode's Rust scaffolding uses:

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}

impl ListNode {
    pub fn new(val: i32) -> Self {
        ListNode { val, next: None }
    }
}
```

Breaking this down for Java developers:

| Rust | Java analogy | Notes |
|------|-------------|-------|
| `Option<Box<ListNode>>` | `@Nullable ListNode` | `None` = null; `Some(box_node)` = non-null |
| `Box<ListNode>` | heap-allocated object | Rust's default — stack. `Box` forces heap. |
| Single `Option<Box<...>>` owner | GC reference | Only one place can *own* the next node at a time |

The `Option` wrapping gives you a null-safe `next` that the compiler forces you to handle. The `Box` allocates each node on the heap (like Java objects) and establishes single ownership.

### Two Essential Ownership Patterns

**Pattern 1: `take()` — move out of `Option`**

```rust
// cursor.next is Option<Box<ListNode>>
let child = cursor.next.take(); // moves Some(box) out; cursor.next is now None
```

`take()` replaces the `Option` with `None` and hands you ownership of the inner value. This is the key primitive for list manipulation — you cannot simply write `cursor.next = some_other_next` while holding a reference to `cursor.next`.

**Pattern 2: `while let` iteration**

```rust
let mut curr = head; // Option<Box<ListNode>>
while let Some(mut node) = curr {
    // node is Box<ListNode>, owned by this block
    curr = node.next.take(); // advance by moving next out
    // node dropped here — memory freed
}
```

This is the canonical Rust loop over a linked list. Each iteration, you *consume* the current node and take ownership of the next.

### When `Option<Box<ListNode>>` Is Not Enough

**LC #138 (Copy List with Random Pointer)** breaks the single-ownership model because the `random` pointer can alias any node in the list. We handle it with an index-based HashMap approach (map from old-node pointer address to new-node position), keeping the canonical node type for old nodes while building the result with a `Vec` for random-access by index.

**Doubly-linked lists** in safe Rust require `Rc<RefCell<Node>>` and are a multi-hour implementation challenge. **LC #146 (LRU Cache)** is solved here with a `HashMap` + counter approach, which is both correct and idiomatic for interview settings.

### A Note on Recursion

Several problems have elegant recursive forms (Reverse List, Merge Two Sorted). Rust does **not** guarantee tail-call optimization. For interview-scale inputs (~5,000 nodes), the call stack holds fine. For production at scale, prefer the iterative forms shown here.

### Shared Test Helpers

Every solution in this chapter uses these helpers. Define them once in your module:

```rust
fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}
```

---

## Problem 1 — Reverse Linked List (LC #206)

**Problem:** Given the head of a singly-linked list, reverse the list and return the new head.

**Example:** `1 → 2 → 3 → 4 → 5` → `5 → 4 → 3 → 2 → 1`

**Key insight:** Walk the list, detach each node from `curr`, and prepend it to `prev`. The ownership dance is: take `curr`, take `curr.next`, hang old `prev` off current node's `next`, current becomes new `prev`.

**Complexity:** O(n) time, O(1) space.

```rust
// ListNode and helpers are included here so this block compiles standalone.
// When combining problems into one file, define them once at the top.
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    pub fn new(val: i32) -> Self {
        ListNode { val, next: None }
    }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

pub fn reverse_list(mut head: Option<Box<ListNode>>) -> Option<Box<ListNode>> {
    let mut prev: Option<Box<ListNode>> = None;

    while let Some(mut curr) = head {
        // Step 1: detach curr.next — save it as the remainder of the original list
        let next = curr.next.take();   // curr.next is now None
        // Step 2: point curr backwards at prev
        curr.next = prev;
        // Step 3: curr becomes the new prev; move to next original node
        prev = Some(curr);
        head = next;
    }

    prev // prev is the new head (last original node)
}

#[cfg(test)]
mod tests_p206 {
    use super::*;

    #[test]
    fn example_five_nodes() {
        let input = to_list(vec![1, 2, 3, 4, 5]);
        assert_eq!(to_vec(reverse_list(input)), vec![5, 4, 3, 2, 1]);
    }

    #[test]
    fn two_nodes() {
        assert_eq!(to_vec(reverse_list(to_list(vec![1, 2]))), vec![2, 1]);
    }

    #[test]
    fn single_node() {
        assert_eq!(to_vec(reverse_list(to_list(vec![1]))), vec![1]);
    }

    #[test]
    fn empty_list() {
        assert_eq!(to_vec(reverse_list(None)), vec![]);
    }
}
```

**Rust-specific notes:**
- `curr.next.take()` is the critical move. Without it, you'd hold a reference to `curr` while also trying to assign to `curr.next` — the borrow checker would reject this.
- `head = next` transfers ownership of the remainder of the list each iteration.
- This is the foundational pattern. Memorize it — it recurs throughout this chapter.

---

## Problem 2 — Merge Two Sorted Lists (LC #21)

**Problem:** Merge two sorted linked lists and return the merged list (also sorted).

**Example:** `1→2→4` and `1→3→4` → `1→1→2→3→4→4`

**Key insight:** Use a dummy head to avoid special-casing the first node. Compare the front values, take the smaller node, advance that list's pointer.

**Complexity:** O(m + n) time, O(1) space.

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    #[inline]
    fn new(val: i32) -> Self { ListNode { val, next: None } }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

pub fn merge_two_lists(
    mut l1: Option<Box<ListNode>>,
    mut l2: Option<Box<ListNode>>,
) -> Option<Box<ListNode>> {
    // Dummy head avoids special-casing the first assignment
    let mut dummy = Box::new(ListNode::new(0));
    let mut tail = &mut dummy;

    loop {
        match (l1.as_ref(), l2.as_ref()) {
            (None, _) => { tail.next = l2; break; }
            (_, None) => { tail.next = l1; break; }
            (Some(n1), Some(n2)) => {
                if n1.val <= n2.val {
                    // Take the front of l1, advance l1
                    let mut taken = l1.take().unwrap();
                    l1 = taken.next.take();
                    tail.next = Some(taken);
                } else {
                    let mut taken = l2.take().unwrap();
                    l2 = taken.next.take();
                    tail.next = Some(taken);
                }
                // Advance tail to the newly appended node
                tail = tail.next.as_mut().unwrap();
            }
        }
    }

    dummy.next
}

#[cfg(test)]
mod tests_p21 {
    use super::*;

    #[test]
    fn both_nonempty() {
        let l1 = to_list(vec![1, 2, 4]);
        let l2 = to_list(vec![1, 3, 4]);
        assert_eq!(to_vec(merge_two_lists(l1, l2)), vec![1, 1, 2, 3, 4, 4]);
    }

    #[test]
    fn both_empty() {
        assert_eq!(to_vec(merge_two_lists(None, None)), vec![]);
    }

    #[test]
    fn one_empty() {
        let l1 = to_list(vec![0]);
        assert_eq!(to_vec(merge_two_lists(None, l1)), vec![0]);
    }
}
```

**Rust-specific notes:**
- `tail` is a `&mut Box<ListNode>` — a mutable reference to the dummy node or the latest appended node. Advancing it requires reassigning after updating `tail.next`.
- `as_ref()` peeks inside the `Option` without consuming it; `.take().unwrap()` consumes it. This two-step lets you compare before committing.

---

## Problem 3 — Reorder List (LC #143)

**Problem:** Given `L0 → L1 → … → Ln-1 → Ln`, reorder it to `L0 → Ln → L1 → Ln-1 → L2 → Ln-2 → …`. Modify in place.

**Example:** `1→2→3→4→5` → `1→5→2→4→3`

**Key insight:** Three steps — (1) find the middle, (2) reverse the second half, (3) interleave the two halves.

**Complexity:** O(n) time, O(1) space.

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    #[inline]
    fn new(val: i32) -> Self { ListNode { val, next: None } }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

pub fn reorder_list(head: &mut Option<Box<ListNode>>) {
    // Count length
    let mut len = 0;
    let mut cur = head.as_ref();
    while let Some(node) = cur {
        len += 1;
        cur = node.next.as_ref();
    }
    if len <= 2 { return; }

    // Step 1: Split so first half has ceil(len/2) nodes.
    // The last node of the first half is at index (len-1)/2 (0-based from head).
    let split_at = (len - 1) / 2;
    let mut count = 0;
    let mut cursor = head.as_mut();
    while count < split_at {
        cursor = cursor.unwrap().next.as_mut();
        count += 1;
    }
    // Detach second half
    let mut second = cursor.unwrap().next.take();

    // Step 2: Reverse the second half
    let mut prev: Option<Box<ListNode>> = None;
    while let Some(mut node) = second {
        let next = node.next.take();
        node.next = prev;
        prev = Some(node);
        second = next;
    }
    let mut second = prev; // second half, reversed

    // Step 3: Interleave
    let mut first = head.as_mut();
    while second.is_some() && first.is_some() {
        let first_node = first.unwrap();
        let first_next = first_node.next.take();

        let mut sec_node = second.take().unwrap();
        let sec_next = sec_node.next.take();

        sec_node.next = first_next;
        first_node.next = Some(sec_node);

        // Advance first past the newly inserted second node
        first = first_node.next.as_mut().unwrap().next.as_mut();
        second = sec_next;
    }
}

#[cfg(test)]
mod tests_p143 {
    use super::*;

    #[test]
    fn five_nodes() {
        let mut head = to_list(vec![1, 2, 3, 4, 5]);
        reorder_list(&mut head);
        assert_eq!(to_vec(head), vec![1, 5, 2, 4, 3]);
    }

    #[test]
    fn four_nodes() {
        let mut head = to_list(vec![1, 2, 3, 4]);
        reorder_list(&mut head);
        assert_eq!(to_vec(head), vec![1, 4, 2, 3]);
    }

    #[test]
    fn two_nodes() {
        let mut head = to_list(vec![1, 2]);
        reorder_list(&mut head);
        assert_eq!(to_vec(head), vec![1, 2]);
    }

    #[test]
    fn single_node() {
        let mut head = to_list(vec![1]);
        reorder_list(&mut head);
        assert_eq!(to_vec(head), vec![1]);
    }
}
```

**Rust-specific notes:**
- The three-phase approach (find mid → reverse → interleave) maps closely to the Java version conceptually, but each phase must be careful about who owns what node at each moment.
- `cursor.unwrap().next.take()` is the key "detach" operation that splits the list without copying.
- Walking `first` through two `.next` hops in one expression (`first_node.next.as_mut().unwrap().next.as_mut()`) is a common pattern to skip the just-inserted node.

---

## Problem 4 — Remove Nth Node From End of List (LC #19)

**Problem:** Remove the n-th node from the end of a list and return the head.

**Example:** `1→2→3→4→5`, n=2 → `1→2→3→5`

**Key insight:** Two-pointer technique: advance the fast pointer n+1 steps ahead, then move both until fast reaches the end. The slow pointer then sits just before the node to remove.

**Complexity:** O(L) time (one pass), O(1) space.

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    #[inline]
    fn new(val: i32) -> Self { ListNode { val, next: None } }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

pub fn remove_nth_from_end(head: Option<Box<ListNode>>, n: i32) -> Option<Box<ListNode>> {
    // Dummy head simplifies removing the actual head node
    let mut dummy = Box::new(ListNode::new(0));
    dummy.next = head;

    // We need two raw-pointer style indirect references.
    // Strategy: collect raw pointers to advance independently.
    // Safer Rust: use length-based approach.

    // Count length
    let mut len = 0;
    let mut cur = dummy.next.as_ref();
    while let Some(node) = cur {
        len += 1;
        cur = node.next.as_ref();
    }

    // The node to remove is at position (len - n) from the front (0-indexed from dummy)
    let steps_to_prev = len - n as usize;

    let mut cursor = &mut dummy;
    for _ in 0..steps_to_prev {
        cursor = cursor.next.as_mut().unwrap();
    }

    // Remove the next node
    let removed = cursor.next.take().unwrap();
    cursor.next = removed.next;

    dummy.next
}

#[cfg(test)]
mod tests_p19 {
    use super::*;

    #[test]
    fn remove_second_from_end() {
        let head = to_list(vec![1, 2, 3, 4, 5]);
        assert_eq!(to_vec(remove_nth_from_end(head, 2)), vec![1, 2, 3, 5]);
    }

    #[test]
    fn remove_only_node() {
        let head = to_list(vec![1]);
        assert_eq!(to_vec(remove_nth_from_end(head, 1)), vec![]);
    }

    #[test]
    fn remove_head() {
        let head = to_list(vec![1, 2]);
        assert_eq!(to_vec(remove_nth_from_end(head, 2)), vec![2]);
    }

    #[test]
    fn remove_tail() {
        let head = to_list(vec![1, 2]);
        assert_eq!(to_vec(remove_nth_from_end(head, 1)), vec![1]);
    }
}
```

**Rust-specific notes:**
- The true two-pointer approach (advancing two `&mut` references simultaneously into the same list) is rejected by the borrow checker — you cannot hold two mutable references into the same structure at once.
- The length-counting approach (two passes, both immutable) sidesteps this and is O(n) — same asymptotic complexity, perfectly fine for interviews.
- The dummy head pattern ensures that removing the actual head node is handled uniformly, without a special `if` branch.

---

## Problem 5 — Copy List with Random Pointer (LC #138)

**Problem:** A linked list node has an extra `random` pointer that points to any node in the list (or null). Deep-copy the list.

**Key insight:** Build new nodes indexed by position. Map each old node's address to its copy's position using a `HashMap`. Then make a second pass to wire up random pointers by index lookup.

**Why this problem is different:** The `random` pointer creates aliasing — multiple nodes can point to the same target. `Box<T>` enforces single ownership and cannot be shared. Rather than switching the entire node type to `Rc<RefCell<Node>>` (which is correct but verbose), we use an **index-based** approach that keeps ownership simple:

1. Walk the list once to build a `Vec` of new nodes and a map from old-node address to new-node index.
2. Walk again to wire `next` and `random` using indices.

```rust
use std::collections::HashMap;

// A different node type required for this problem
#[derive(Debug)]
pub struct RandomNode {
    pub val: i32,
    pub next: Option<Box<RandomNode>>,
    pub random: Option<*const RandomNode>, // raw pointer — read-only alias
}

impl RandomNode {
    pub fn new(val: i32) -> Self {
        RandomNode { val, next: None, random: None }
    }
}

/// Index-based deep copy. Returns the new list head.
pub fn copy_random_list(head: Option<Box<RandomNode>>) -> Option<Box<RandomNode>> {
    if head.is_none() { return None; }

    // Pass 1: collect (val, random_ptr) for each node in order;
    //         record the address-to-index mapping.
    let mut vals: Vec<i32> = Vec::new();
    let mut random_indices: Vec<Option<usize>> = Vec::new();
    // Map old node address → index in vals
    let mut addr_to_idx: HashMap<usize, usize> = HashMap::new();

    // First sub-pass: record addresses and vals
    let mut cur = head.as_ref();
    let mut idx = 0;
    while let Some(node) = cur {
        addr_to_idx.insert(node.as_ref() as *const RandomNode as usize, idx);
        vals.push(node.val);
        idx += 1;
        cur = node.next.as_ref();
    }

    // Second sub-pass: resolve random pointers to indices
    cur = head.as_ref();
    while let Some(node) = cur {
        let rand_idx = node.random.map(|ptr| {
            let addr = ptr as usize;
            *addr_to_idx.get(&addr).unwrap()
        });
        random_indices.push(rand_idx);
        cur = node.next.as_ref();
    }

    // Pass 2: build the new list from the back so we can link next pointers
    let n = vals.len();
    // Build nodes in a Vec first (random-access needed for random pointers)
    let mut new_nodes: Vec<Box<RandomNode>> = vals
        .iter()
        .map(|&v| Box::new(RandomNode::new(v)))
        .collect();

    // Wire random pointers (using raw pointers to the new nodes)
    // We need two passes: first set random, then link next.
    // Collect raw ptrs before linking (linking would move the boxes).
    let ptrs: Vec<*const RandomNode> = new_nodes
        .iter()
        .map(|b| b.as_ref() as *const RandomNode)
        .collect();

    for (i, node) in new_nodes.iter_mut().enumerate() {
        node.random = random_indices[i].map(|ri| ptrs[ri]);
    }

    // Link next pointers from back to front
    let mut next: Option<Box<RandomNode>> = None;
    for i in (0..n).rev() {
        new_nodes[i].next = next;
        // Can't move out of indexed Vec directly — use swap trick
        let mut placeholder = Box::new(RandomNode::new(0));
        std::mem::swap(&mut new_nodes[i], &mut placeholder);
        next = Some(placeholder);
    }

    next
}

#[cfg(test)]
mod tests_p138 {
    use super::*;

    fn build_random_list(vals: &[i32], randoms: &[Option<usize>]) -> Option<Box<RandomNode>> {
        let n = vals.len();
        let mut nodes: Vec<Box<RandomNode>> = vals.iter().map(|&v| Box::new(RandomNode::new(v))).collect();
        // collect raw pointers before linking
        let ptrs: Vec<*const RandomNode> = nodes.iter().map(|b| b.as_ref() as *const RandomNode).collect();
        for (i, node) in nodes.iter_mut().enumerate() {
            node.random = randoms[i].map(|ri| ptrs[ri]);
        }
        let mut next = None;
        for i in (0..n).rev() {
            nodes[i].next = next;
            let mut tmp = Box::new(RandomNode::new(0));
            std::mem::swap(&mut nodes[i], &mut tmp);
            next = Some(tmp);
        }
        next
    }

    fn collect_vals(head: &Option<Box<RandomNode>>) -> Vec<i32> {
        let mut v = Vec::new();
        let mut cur = head.as_ref();
        while let Some(n) = cur { v.push(n.val); cur = n.next.as_ref(); }
        v
    }

    #[test]
    fn basic_copy() {
        // [[7,null],[13,0],[11,4],[10,2],[1,0]]
        let original = build_random_list(
            &[7, 13, 11, 10, 1],
            &[None, Some(0), Some(4), Some(2), Some(0)],
        );
        let copied = copy_random_list(original);
        assert_eq!(collect_vals(&copied), vec![7, 13, 11, 10, 1]);
    }

    #[test]
    fn single_node_no_random() {
        let original = build_random_list(&[1], &[None]);
        let copied = copy_random_list(original);
        assert_eq!(collect_vals(&copied), vec![1]);
    }

    #[test]
    fn empty_list() {
        assert!(copy_random_list(None).is_none());
    }
}
```

**Rust-specific notes:**
- `Option<*const RandomNode>` uses a raw pointer for the `random` field. This is `unsafe` territory in principle, but since we only read through it (not dereference dangerously) and we ensure the pointed-to nodes outlive the pointers during our passes, this is safe in practice for this algorithm.
- The alternative — `Option<Rc<RefCell<RandomNode>>>` — is idiomatic safe Rust but involves significantly more boilerplate. For interview contexts the index/pointer approach is pragmatic.
- This problem does **not** use `Option<Box<ListNode>>` — it demonstrates that the canonical LeetCode node type has limits.

---

## Problem 6 — Add Two Numbers (LC #2)

**Problem:** Two non-empty linked lists represent non-negative integers stored in **reverse order** (ones digit first). Add the two numbers and return the sum as a linked list in the same format.

**Example:** `2→4→3` + `5→6→4` = `7→0→8` (342 + 465 = 807)

**Key insight:** Simulate digit-by-digit addition with a carry. Consume both lists simultaneously, appending sum digits to a result list built with a dummy head.

**Complexity:** O(max(m, n)) time, O(max(m, n)) space.

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    #[inline]
    fn new(val: i32) -> Self { ListNode { val, next: None } }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

pub fn add_two_numbers(
    mut l1: Option<Box<ListNode>>,
    mut l2: Option<Box<ListNode>>,
) -> Option<Box<ListNode>> {
    let mut dummy = Box::new(ListNode::new(0));
    let mut tail = &mut dummy;
    let mut carry = 0i32;

    while l1.is_some() || l2.is_some() || carry != 0 {
        let v1 = if let Some(ref node) = l1 { node.val } else { 0 };
        let v2 = if let Some(ref node) = l2 { node.val } else { 0 };

        let sum = v1 + v2 + carry;
        carry = sum / 10;

        tail.next = Some(Box::new(ListNode::new(sum % 10)));
        tail = tail.next.as_mut().unwrap();

        l1 = l1.and_then(|n| n.next);
        l2 = l2.and_then(|n| n.next);
    }

    dummy.next
}

#[cfg(test)]
mod tests_p2 {
    use super::*;

    #[test]
    fn example_342_plus_465() {
        let l1 = to_list(vec![2, 4, 3]);
        let l2 = to_list(vec![5, 6, 4]);
        assert_eq!(to_vec(add_two_numbers(l1, l2)), vec![7, 0, 8]);
    }

    #[test]
    fn both_zero() {
        assert_eq!(to_vec(add_two_numbers(to_list(vec![0]), to_list(vec![0]))), vec![0]);
    }

    #[test]
    fn carry_propagation() {
        // 999 + 1 = 1000
        let l1 = to_list(vec![9, 9, 9]);
        let l2 = to_list(vec![1]);
        assert_eq!(to_vec(add_two_numbers(l1, l2)), vec![0, 0, 0, 1]);
    }

    #[test]
    fn different_lengths() {
        // 9999 + 9 = 10008
        let l1 = to_list(vec![9, 9, 9, 9]);
        let l2 = to_list(vec![9]);
        assert_eq!(to_vec(add_two_numbers(l1, l2)), vec![8, 0, 0, 0, 1]);
    }
}
```

**Rust-specific notes:**
- `l1.and_then(|n| n.next)` consumes the current node and returns `n.next` (or `None`). This is the idiomatic way to advance ownership in a list without a separate `take()` step.
- `if let Some(ref node) = l1` borrows the head without consuming it, letting us read `node.val` while keeping ownership in `l1`.

---

## Problem 7 — Find the Duplicate Number (LC #287)

**Problem:** Given an array `nums` of n+1 integers in range [1, n], find the one duplicate. Must use O(1) extra space and not modify the array.

**Why this is in the linked list chapter:** Think of `nums[i]` as a "next pointer" — index `i` links to index `nums[i]`. Since a value repeats, two indices point to the same "node," creating a cycle. Floyd's cycle detection (tortoise and hare) finds the cycle entrance, which is the duplicate.

**Key insight:** Phase 1 — detect cycle (tortoise/hare). Phase 2 — find cycle entrance (reset one pointer to start, advance both one step at a time until they meet; meeting point = duplicate).

**Complexity:** O(n) time, O(1) space.

```rust
pub fn find_duplicate(nums: Vec<i32>) -> i32 {
    // Treat nums[i] as a "next pointer": index i → index nums[i].
    // A duplicate value means two indices point to the same index → cycle.
    // Floyd's cycle detection finds the cycle entrance = duplicate value.
    //
    // Both pointers start at index 0 so that phase-2 reset to 0 is
    // consistent with the cycle-entrance identity: the two pointers meet
    // exactly at the entrance (the duplicate value) in phase 2.
    let mut slow = 0usize;
    let mut fast = 0usize;

    // Phase 1: find the meeting point inside the cycle.
    loop {
        slow = nums[slow] as usize;
        fast = nums[nums[fast] as usize] as usize;
        if slow == fast { break; }
    }

    // Phase 2: reset one pointer to index 0; advance both by one step.
    // They meet at the cycle entrance = the duplicate value.
    let mut slow2 = 0usize;
    while slow != slow2 {
        slow  = nums[slow]  as usize;
        slow2 = nums[slow2] as usize;
    }

    slow as i32
}

#[cfg(test)]
mod tests_p287 {
    use super::*;

    #[test]
    fn example_1() {
        assert_eq!(find_duplicate(vec![1, 3, 4, 2, 2]), 2);
    }

    #[test]
    fn example_2() {
        assert_eq!(find_duplicate(vec![3, 1, 3, 4, 2]), 3);
    }

    #[test]
    fn duplicate_is_one() {
        assert_eq!(find_duplicate(vec![1, 1]), 1);
    }

    #[test]
    fn duplicate_at_end() {
        assert_eq!(find_duplicate(vec![2, 5, 9, 6, 9, 3, 8, 9, 7, 1]), 9);
    }
}
```

**Rust-specific notes:**
- No linked list nodes are created — `nums` itself is the implicit graph. Indexing is standard `usize`; cast carefully from `i32`.
- Both pointers start from index `0` — not `nums[0]`. Starting from `nums[0]` is a common error: phase-2's reset to `0` is only valid when phase-1 also began at `0`.
- Rust's bounds-checked indexing (`nums[slow]`) will panic if `slow` goes out of range, which cannot happen given valid LeetCode input (all values in [1, n]).
- This is a "linked list problem" conceptually, not structurally. The same Floyd's algorithm that finds cycles in `Option<Box<ListNode>>` chains applies here.

---

## Problem 8 — LRU Cache (LC #146)

**Problem:** Design a data structure that follows the Least Recently Used cache policy. Implement `get(key)` and `put(key, value)`, both O(1) average.

**Why not a doubly-linked list:** A true O(1) LRU in Java uses a `LinkedHashMap`. In Rust, building a doubly-linked list in safe code requires `Rc<RefCell<Node>>` and careful `Weak` back-pointers — a multi-hour exercise. For interviews, a `HashMap` with a logical-timestamp (counter) achieves correct eviction with O(1) amortized `get`/`put` (O(capacity) worst-case eviction scan, but this is acceptable for typical interview constraints).

**Key insight:** Store `(value, last_used_time)` in a `HashMap`. On `get`/`put`, update the timestamp. On capacity overflow, find and evict the entry with the smallest timestamp using a linear scan over the map.

**Complexity:** O(1) average for get/put (O(capacity) eviction scan); O(capacity) space.

```rust
use std::collections::HashMap;

pub struct LRUCache {
    cap: usize,
    time: u64,
    map: HashMap<i32, (i32, u64)>, // key -> (value, last_used)
}

impl LRUCache {
    pub fn new(capacity: i32) -> Self {
        LRUCache {
            cap: capacity as usize,
            time: 0,
            map: HashMap::with_capacity(capacity as usize),
        }
    }

    pub fn get(&mut self, key: i32) -> i32 {
        self.time += 1;
        let t = self.time;
        if let Some(entry) = self.map.get_mut(&key) {
            entry.1 = t;
            entry.0
        } else {
            -1
        }
    }

    pub fn put(&mut self, key: i32, value: i32) {
        self.time += 1;
        let t = self.time;
        if self.map.contains_key(&key) {
            self.map.insert(key, (value, t));
            return;
        }
        if self.map.len() == self.cap {
            // Evict the entry with the smallest timestamp
            let lru_key = *self
                .map
                .iter()
                .min_by_key(|(_, v)| v.1)
                .unwrap()
                .0;
            self.map.remove(&lru_key);
        }
        self.map.insert(key, (value, t));
    }
}

#[cfg(test)]
mod tests_p146 {
    use super::*;

    #[test]
    fn lc_example() {
        let mut cache = LRUCache::new(2);
        cache.put(1, 1);
        cache.put(2, 2);
        assert_eq!(cache.get(1), 1);  // returns 1
        cache.put(3, 3);              // evicts key 2 (LRU)
        assert_eq!(cache.get(2), -1); // not found
        cache.put(4, 4);              // evicts key 1 (LRU, since 1 was accessed before 3)
        assert_eq!(cache.get(1), -1); // not found
        assert_eq!(cache.get(3), 3);  // returns 3
        assert_eq!(cache.get(4), 4);  // returns 4
    }

    #[test]
    fn capacity_one() {
        let mut cache = LRUCache::new(1);
        cache.put(2, 1);
        assert_eq!(cache.get(2), 1);
        cache.put(3, 2);
        assert_eq!(cache.get(2), -1);
        assert_eq!(cache.get(3), 2);
    }

    #[test]
    fn update_existing_key() {
        let mut cache = LRUCache::new(2);
        cache.put(1, 1);
        cache.put(2, 2);
        cache.put(1, 10); // update — does not evict
        assert_eq!(cache.get(1), 10);
        assert_eq!(cache.get(2), 2);
    }
}
```

**Rust-specific notes:**
- `self.map.iter().min_by_key(...)` borrows the map immutably to find the LRU key. The `.0` at the end dereferences the key reference from the iterator.
- `self.time` overflows after 2^64 operations — for competitive programming this is irrelevant; for production, use `u128` or a different eviction policy.
- Java's `LinkedHashMap(cap, 0.75f, true)` gives true O(1) LRU. If you need that in Rust, the [`lru` crate](https://crates.io/crates/lru) provides it.

---

## Problem 9 — Merge K Sorted Lists (LC #23)

**Problem:** Merge k sorted linked lists into one sorted linked list.

**Key insight:** Use a min-heap (`BinaryHeap` with `Reverse`). Push the head of each list into the heap, then repeatedly pop the minimum, append it to the result, and push that node's next.

**Complexity:** O(N log k) time where N = total nodes, k = number of lists; O(k) heap space.

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    #[inline]
    fn new(val: i32) -> Self { ListNode { val, next: None } }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

use std::cmp::Ordering;
use std::collections::BinaryHeap;

// BinaryHeap is a max-heap. Wrap in Reverse for min-heap behaviour.
// We also need Ord for Box<ListNode>. Define a newtype.
struct NodeWrapper(Box<ListNode>);

impl PartialEq for NodeWrapper {
    fn eq(&self, other: &Self) -> bool { self.0.val == other.0.val }
}
impl Eq for NodeWrapper {}

impl PartialOrd for NodeWrapper {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> { Some(self.cmp(other)) }
}

// Max-heap by default; we want min — so reverse the comparison.
impl Ord for NodeWrapper {
    fn cmp(&self, other: &Self) -> Ordering {
        // Reversed so BinaryHeap acts as a min-heap
        other.0.val.cmp(&self.0.val)
    }
}

pub fn merge_k_lists(lists: Vec<Option<Box<ListNode>>>) -> Option<Box<ListNode>> {
    let mut heap = BinaryHeap::new();

    // Seed the heap with the head of each non-empty list
    for list in lists {
        if let Some(node) = list {
            heap.push(NodeWrapper(node));
        }
    }

    let mut dummy = Box::new(ListNode::new(0));
    let mut tail = &mut dummy;

    while let Some(NodeWrapper(mut node)) = heap.pop() {
        // Take next before appending node (would lose access after move)
        let next = node.next.take();
        tail.next = Some(node);
        tail = tail.next.as_mut().unwrap();

        if let Some(next_node) = next {
            heap.push(NodeWrapper(next_node));
        }
    }

    dummy.next
}

#[cfg(test)]
mod tests_p23 {
    use super::*;

    #[test]
    fn three_lists() {
        let lists = vec![
            to_list(vec![1, 4, 5]),
            to_list(vec![1, 3, 4]),
            to_list(vec![2, 6]),
        ];
        assert_eq!(to_vec(merge_k_lists(lists)), vec![1, 1, 2, 3, 4, 4, 5, 6]);
    }

    #[test]
    fn empty_input() {
        assert_eq!(to_vec(merge_k_lists(vec![])), vec![]);
    }

    #[test]
    fn all_empty_lists() {
        assert_eq!(to_vec(merge_k_lists(vec![None, None])), vec![]);
    }

    #[test]
    fn single_list() {
        assert_eq!(to_vec(merge_k_lists(vec![to_list(vec![1, 2, 3])])), vec![1, 2, 3]);
    }
}
```

**Rust-specific notes:**
- `BinaryHeap` is a **max-heap**. To get min-heap behavior, reverse the `Ord` comparison inside `NodeWrapper`. This is the standard Rust idiom (alternative: wrap each value in `std::cmp::Reverse`).
- `Box<ListNode>` does not implement `Ord` by default — even with `#[derive(PartialOrd, Ord)]` it would compare all fields including `next`, which is wrong. The `NodeWrapper` newtype gives us a clean comparison on `val` only.
- Java's `PriorityQueue` is also a min-heap by default. The inversion is the key conceptual difference.

---

## Problem 10 — Reverse Nodes in K-Group (LC #25)

**Problem:** Reverse the nodes of the list k at a time. If the number of nodes remaining is fewer than k, leave them as-is. Return the modified list.

**Example:** `1→2→3→4→5`, k=2 → `2→1→4→3→5`; k=3 → `3→2→1→4→5`

**Key insight:** (1) Check that at least k nodes remain. (2) Detach exactly k nodes from the head. (3) Reverse that k-node chunk. (4) Recursively (or iteratively) process the rest. (5) Reattach.

**Complexity:** O(n) time, O(n/k) stack space for recursion (O(1) for iterative).

```rust
#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}
impl ListNode {
    #[inline]
    fn new(val: i32) -> Self { ListNode { val, next: None } }
}

fn to_list(vals: Vec<i32>) -> Option<Box<ListNode>> {
    let mut head = None;
    for &v in vals.iter().rev() {
        let mut node = Box::new(ListNode::new(v));
        node.next = head;
        head = Some(node);
    }
    head
}

fn to_vec(mut head: Option<Box<ListNode>>) -> Vec<i32> {
    let mut result = Vec::new();
    while let Some(node) = head {
        result.push(node.val);
        head = node.next;
    }
    result
}

/// Detaches the first k nodes from `head`. Returns (chunk, remainder).
/// Returns (None, original_head) if fewer than k nodes exist.
fn take_k(
    mut head: Option<Box<ListNode>>,
    k: usize,
) -> (Option<Box<ListNode>>, Option<Box<ListNode>>) {
    // Count to verify we have k nodes
    let mut count = 0;
    let mut cur = head.as_ref();
    while let Some(node) = cur {
        count += 1;
        if count == k { break; }
        cur = node.next.as_ref();
    }
    if count < k {
        return (None, head); // fewer than k — return unchanged
    }

    // Detach first k nodes
    let mut chunk_head = None;
    for _ in 0..k {
        let mut node = head.take().unwrap();
        head = node.next.take();
        // Prepend to chunk (reverses as we go — we'll reverse the chunk below)
        node.next = chunk_head;
        chunk_head = Some(node);
    }
    // chunk_head is now the reversed k-chunk; head is the remainder.
    // But we want the chunk unreversed (we'll reverse it in the caller),
    // so reverse it back first.
    let mut unreversed = None;
    while let Some(mut node) = chunk_head {
        let next = node.next.take();
        node.next = unreversed;
        unreversed = Some(node);
        chunk_head = next;
    }
    (unreversed, head)
}

/// Reverse a list of exactly k nodes. The caller guarantees length == k.
fn reverse_k(mut head: Option<Box<ListNode>>) -> Option<Box<ListNode>> {
    let mut prev = None;
    while let Some(mut node) = head {
        let next = node.next.take();
        node.next = prev;
        prev = Some(node);
        head = next;
    }
    prev
}

pub fn reverse_k_group(head: Option<Box<ListNode>>, k: i32) -> Option<Box<ListNode>> {
    let k = k as usize;
    let mut dummy = Box::new(ListNode::new(0));
    let mut tail = &mut dummy;
    let mut remaining = head;

    loop {
        let (chunk, rest) = take_k(remaining, k);
        match chunk {
            None => {
                // Fewer than k nodes left — attach unchanged remainder
                tail.next = rest;
                break;
            }
            Some(chunk_head) => {
                let reversed = reverse_k(Some(chunk_head));
                tail.next = reversed;
                // Advance tail to the end of the just-appended reversed chunk
                for _ in 0..k {
                    if tail.next.is_some() {
                        tail = tail.next.as_mut().unwrap();
                    }
                }
                remaining = rest;
            }
        }
    }

    dummy.next
}

#[cfg(test)]
mod tests_p25 {
    use super::*;

    #[test]
    fn k2_five_nodes() {
        assert_eq!(
            to_vec(reverse_k_group(to_list(vec![1, 2, 3, 4, 5]), 2)),
            vec![2, 1, 4, 3, 5]
        );
    }

    #[test]
    fn k3_five_nodes() {
        assert_eq!(
            to_vec(reverse_k_group(to_list(vec![1, 2, 3, 4, 5]), 3)),
            vec![3, 2, 1, 4, 5]
        );
    }

    #[test]
    fn k1_identity() {
        assert_eq!(
            to_vec(reverse_k_group(to_list(vec![1, 2, 3]), 1)),
            vec![1, 2, 3]
        );
    }

    #[test]
    fn k_equals_length() {
        assert_eq!(
            to_vec(reverse_k_group(to_list(vec![1, 2, 3]), 3)),
            vec![3, 2, 1]
        );
    }

    #[test]
    fn single_node() {
        assert_eq!(
            to_vec(reverse_k_group(to_list(vec![1]), 1)),
            vec![1]
        );
    }
}
```

**Rust-specific notes:**
- `take_k` borrows-then-consumes: it first counts by immutable reference (to check k-availability) then consumes by taking ownership. This two-step is required because you cannot hold a mutable reference and count simultaneously in a single pass without more complex bookkeeping.
- The iterative approach here avoids the stack growth of a recursive solution. A recursive form is shorter but uses O(n/k) stack frames — for k=1 on a long list, that risks stack overflow.
- Advancing `tail` by a fixed `k` steps after appending is O(k) per group — total across all groups is O(n).

---

## Quick Pattern Reference

| Pattern | Code skeleton | When to use |
|---|---|---|
| Consume + advance | `while let Some(mut n) = head { head = n.next.take(); }` | Any list traversal that modifies |
| Peek without consuming | `head.as_ref()` / `head.as_mut()` | Comparison, length counting |
| Dummy head | `let mut dummy = Box::new(ListNode::new(0)); let mut tail = &mut dummy;` | Building new list, avoiding head-edge-case |
| Split list | `cursor.next.take()` | Midpoint split, k-group split |
| Advance mutable tail | `tail = tail.next.as_mut().unwrap();` | Appending to result list |
| Min-heap from nodes | `BinaryHeap` + newtype `Ord` + reversed comparison | Merge k lists |
| Implicit linked list | Array indices as pointers | Floyd's cycle on an array (#287) |

---

## Java vs. Rust Linked List Cheat Sheet

| Java | Rust | Notes |
|------|------|-------|
| `node.next = other` | `node.next = Some(Box::new(...))` or `node.next = other_option` | Must satisfy ownership |
| `node.next = null` | `node.next = None` | |
| `node.next != null` | `node.next.is_some()` | |
| `ListNode tmp = node.next` | `let tmp = node.next.take()` | `take()` moves out, sets to `None` |
| Multiple refs to same node | Requires `Rc<RefCell<...>>` | GC handles in Java automatically |
| `new ListNode(val)` | `Box::new(ListNode::new(val))` | Explicit heap allocation |
| Null-safe access `?.next` | `node.as_ref().and_then(\|n\| n.next.as_ref())` | |
| Traverse with `for` loop | `while let Some(node) = head` | `for` not directly applicable |

---

## 📝 Review Notes

**Correctness verification (all 10 problems):**

- **LC #206** — Three-pointer iterative reverse is canonical and correct. The `take()` + reassign loop matches the invariant `prev → reversed so far`, `head → unreversed remainder`.

- **LC #21** — Dummy-head merge is the standard approach. The `as_ref()` peek to compare values before consuming with `take().unwrap()` is the correct two-step that satisfies the borrow checker.

- **LC #143** — Length-count-then-split is O(n) with two passes (one count, one split). Split position is `(len-1)/2` steps from the head, giving the first half `ceil(len/2)` nodes — this ensures odd-length lists keep the middle node in the first half and the interleave loop terminates without dropping nodes. The interleave `while` guard checks `second.is_some() && first.is_some()` to handle the case where the first half is exhausted before the second. All four test cases pass.

- **LC #19** — Two-pass (count + advance by `len - n` steps) sidesteps the borrow checker limitation on simultaneous mutable references. Result is O(n) — same complexity class as the true one-pass two-pointer but requires two traversals. This is the right trade-off in safe Rust.

- **LC #138** — Uses raw `*const RandomNode` pointers to represent aliasing, which is the practical interview approach. Full safe-Rust implementation would use `Rc<RefCell<RandomNode>>` — correct but ~3x the code. The raw-pointer version here dereferences nothing unsafely; it only stores addresses as `usize` keys in a `HashMap`. It does store raw pointers in the `random` field — these remain valid for the lifetime of the test since we don't free any nodes during address lookup.

- **LC #2** — Carry-propagation loop with `and_then(|n| n.next)` for advancing is idiomatic. The `|| carry != 0` condition in the loop guard correctly handles a final carry digit (e.g., 999 + 1 = 1000).

- **LC #287** — Both phase-1 and phase-2 pointers are initialized to index 0 (not `nums[0]`). Initializing to `nums[0]` is a common mistake: phase-2's reset to index 0 is only valid when phase-1 also started from index 0. Using `nums[0]` as the start causes phase 2 to diverge rather than converge on the duplicate. All four tests — including `[1,3,4,2,2]`, `[3,1,3,4,2]`, `[1,1]`, and a 10-element case — verified by running the compiled binary.

- **LC #146** — Counter-based LRU has O(capacity) eviction worst case. For interview purposes with typical constraints (≤ 3000 operations, capacity ≤ 3000) this is fine. For production, use the [`lru` crate](https://crates.io/crates/lru) or implement with `std::collections::LinkedList` + `HashMap`.

- **LC #23** — `NodeWrapper` with reversed `Ord` gives correct min-heap behavior. Comparing only on `val` (not `next`) is essential — including `next` in the comparison would give non-deterministic ordering.

- **LC #25** — `take_k` double-traverses (count then take). The `reverse_k` helper reuses the exact same pattern as #206. Iterative group-by-group is O(n) total.

**Ownership patterns established in this chapter:**

1. `take()` to move out of `Option<Box<T>>` — used in every problem
2. `as_ref()` / `as_mut()` to borrow without consuming — used for counting and peeking
3. Dummy head to unify head-insert with body-insert
4. Length-first approach when two simultaneous `&mut` borrows would conflict
5. Newtype wrapper to attach custom `Ord` to external types

**What this chapter does not cover:**

- Doubly-linked lists in safe Rust (`Rc<RefCell<Node>>` + `Weak`) — see Chapter 15 (Smart Pointers) for the underlying primitives
- Async-safe linked structures — out of scope for LeetCode-style problems
- The `unsafe` approach to linked lists (raw `*mut` pointers) — see Chapter 20 (Advanced Features)
