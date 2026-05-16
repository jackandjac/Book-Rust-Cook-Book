# Chapter LC-04 (Java): Linked Lists
> Java solutions companion to [Rust Chapter LC-04](../leetcode/lc04-linked-lists.md).
> Note: Java's GC makes linked list manipulation significantly simpler than Rust.

---

## Why Linked Lists Are Easy in Java (and Hard in Rust)

In Java, a linked list node is three lines:

```java
class ListNode {
    int val;
    ListNode next;                          // GC owns the lifetime
    ListNode(int val) { this.val = val; }
}
```

You can point `next` at any node freely, hold multiple references to the same node, set it to `null`, and forget about it. The garbage collector handles cleanup. You never think about ownership.

Rust has no GC. Every value has exactly one owner. The canonical LeetCode node type is:

```rust
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,  // ONE owner; must Box to heap-allocate
}
```

That `Option<Box<ListNode>>` forces you to confront ownership on every pointer operation. Here is what the contrast looks like for the ten problems in this chapter:

| Operation | Java | Rust equivalent |
|---|---|---|
| Advance to next | `curr = curr.next;` | `curr = curr.next.take();` — must *move* ownership |
| Set next to null | `node.next = null;` | `node.next = None;` |
| Read next without consuming | `if (node.next != null)` | `node.next.as_ref()` — borrow, not move |
| Multiple refs to same node | Free — GC handles aliasing | Requires `Rc<RefCell<Node>>` |
| Copy list with random pointers | `Map<Node, Node>` in 25 lines | Raw `*const` pointers + 130 lines |
| Doubly-linked list (LRU) | `LinkedHashMap` or manual in ~50 lines | Multi-hour `Rc<RefCell<Node>>` exercise |
| Two-pointer traversal | Two refs into the same list, no ceremony | Borrow checker blocks two `&mut` refs simultaneously |

The Rust chapter's "Two Essential Ownership Patterns" (`take()` and `while let`) exist entirely because of these constraints. In Java, none of those patterns are necessary.

**Running the code blocks:** Each problem is a self-contained class. Run on Java 17+ with:
```
javac Solution206.java && java Solution206
```
Class names match the problem number (e.g. `Solution206`, `Solution21`, `LRUCacheLinkedHashMap`).
Assertions use `if (!cond) throw new AssertionError("msg")` — no `-ea` flag needed.

---

## Standard ListNode Definition

This definition appears inside each problem's class so blocks are copy-paste runnable. The canonical form used throughout:

```java
static class ListNode {
    int val;
    ListNode next;
    ListNode(int val) { this.val = val; }
    ListNode(int val, ListNode next) { this.val = val; this.next = next; }
}
```

### Shared Test Helpers

Define these once in a combined file, or inline per-block as shown in each problem:

```java
static ListNode toList(int... vals) {
    ListNode dummy = new ListNode(0);
    ListNode tail = dummy;
    for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
    return dummy.next;
}

static int[] toArray(ListNode head) {
    java.util.List<Integer> list = new java.util.ArrayList<>();
    while (head != null) { list.add(head.val); head = head.next; }
    return list.stream().mapToInt(Integer::intValue).toArray();
}
```

---

## Problem 1 — Reverse Linked List (LC #206)

**Problem:** Given the head of a singly-linked list, reverse the list and return the new head.

**Example:** `1 → 2 → 3 → 4 → 5` → `5 → 4 → 3 → 2 → 1`

**Key insight:** Walk the list with three pointers: `prev`, `curr`, `next`. At each step, redirect `curr.next` backward, then advance all three.

**Complexity:** O(n) time, O(1) space.

```java
class Solution206 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static ListNode reverseList(ListNode head) {
        ListNode prev = null;
        ListNode curr = head;
        while (curr != null) {
            ListNode next = curr.next;  // save remainder
            curr.next = prev;           // flip pointer backward
            prev = curr;                // advance prev
            curr = next;                // advance curr
        }
        return prev; // prev is the new head
    }

    public static void main(String[] args) {
        if (!java.util.Arrays.equals(
            toArray(reverseList(toList(1, 2, 3, 4, 5))), new int[]{5, 4, 3, 2, 1}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseList(toList(1, 2))), new int[]{2, 1}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseList(toList(1))), new int[]{1}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseList(null)), new int[]{}))
            throw new AssertionError("arrays not equal");
        System.out.println("LC #206 — all assertions passed");
    }
}
```

**Java notes:**
- `ListNode next = curr.next` is a plain reference copy — no ownership transfer, no `take()`. The GC is aware of all three references simultaneously.
- In Rust, `curr.next.take()` is mandatory because you cannot hold `curr` and also assign to `curr.next` without the borrow checker objecting. Java has no such constraint.
- This is the foundational pattern. The iterative form is preferred over recursion to avoid O(n) stack growth.

---

## Problem 2 — Merge Two Sorted Lists (LC #21)

**Problem:** Merge two sorted linked lists and return the merged list (also sorted).

**Example:** `1→2→4` and `1→3→4` → `1→1→2→3→4→4`

**Key insight:** Dummy head eliminates special-casing the first node. Compare front values, attach the smaller, advance that pointer. Append the non-empty remainder at the end.

**Complexity:** O(m + n) time, O(1) space.

```java
class Solution21 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static ListNode mergeTwoLists(ListNode l1, ListNode l2) {
        ListNode dummy = new ListNode(0);
        ListNode tail = dummy;
        while (l1 != null && l2 != null) {
            if (l1.val <= l2.val) {
                tail.next = l1;
                l1 = l1.next;
            } else {
                tail.next = l2;
                l2 = l2.next;
            }
            tail = tail.next;
        }
        tail.next = (l1 != null) ? l1 : l2; // attach the non-empty remainder
        return dummy.next;
    }

    public static void main(String[] args) {
        if (!java.util.Arrays.equals(
            toArray(mergeTwoLists(toList(1, 2, 4), toList(1, 3, 4))),
            new int[]{1, 1, 2, 3, 4, 4}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(mergeTwoLists(null, null)), new int[]{}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(mergeTwoLists(null, toList(0))), new int[]{0}))
            throw new AssertionError("arrays not equal");
        System.out.println("LC #21 — all assertions passed");
    }
}
```

**Java notes:**
- `tail.next = l1` reuses the existing node — no allocation. In Rust, detaching a node from one list and attaching to another requires `take().unwrap()` to satisfy ownership; Java just reassigns the reference.
- `tail.next = (l1 != null) ? l1 : l2` attaches the entire remaining sub-list in one assignment. Both `l1` and `l2` can be referenced freely; the GC knows they are still live.
- Compare to Rust's `as_ref()` peek + `take().unwrap()` consume pattern — Java needs neither.

---

## Problem 3 — Reorder List (LC #143)

**Problem:** Given `L0 → L1 → … → Ln-1 → Ln`, reorder it in-place to `L0 → Ln → L1 → Ln-1 → …`.

**Example:** `1→2→3→4→5` → `1→5→2→4→3`

**Key insight:** Three steps — (1) find the middle with slow/fast pointers, (2) reverse the second half, (3) interleave the two halves.

**Complexity:** O(n) time, O(1) space.

```java
class Solution143 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static void reorderList(ListNode head) {
        if (head == null || head.next == null) return;

        // Step 1: Find the middle (slow/fast pointers)
        ListNode slow = head, fast = head;
        while (fast.next != null && fast.next.next != null) {
            slow = slow.next;
            fast = fast.next.next;
        }
        // slow is now the last node of the first half

        // Step 2: Reverse the second half
        ListNode prev = null;
        ListNode curr = slow.next;
        slow.next = null;           // disconnect the two halves
        while (curr != null) {
            ListNode next = curr.next;
            curr.next = prev;
            prev = curr;
            curr = next;
        }
        // prev is the head of the reversed second half

        // Step 3: Interleave first half and reversed second half
        ListNode first = head, second = prev;
        while (second != null) {
            ListNode firstNext = first.next;
            ListNode secondNext = second.next;
            first.next = second;
            second.next = firstNext;
            first = firstNext;
            second = secondNext;
        }
    }

    public static void main(String[] args) {
        ListNode h1 = toList(1, 2, 3, 4, 5);
        reorderList(h1);
        if (!java.util.Arrays.equals(toArray(h1), new int[]{1, 5, 2, 4, 3}))
            throw new AssertionError("arrays not equal");

        ListNode h2 = toList(1, 2, 3, 4);
        reorderList(h2);
        if (!java.util.Arrays.equals(toArray(h2), new int[]{1, 4, 2, 3}))
            throw new AssertionError("arrays not equal");

        ListNode h3 = toList(1, 2);
        reorderList(h3);
        if (!java.util.Arrays.equals(toArray(h3), new int[]{1, 2}))
            throw new AssertionError("arrays not equal");

        ListNode h4 = toList(1);
        reorderList(h4);
        if (!java.util.Arrays.equals(toArray(h4), new int[]{1}))
            throw new AssertionError("arrays not equal");

        System.out.println("LC #143 — all assertions passed");
    }
}
```

**Java notes:**
- The slow/fast pointer technique finds the midpoint in one pass. In Rust, this requires two mutable references into the same list — which the borrow checker blocks. The Rust chapter falls back to counting length first (two passes). Java does it cleanly in one.
- `slow.next = null` cleanly severs the list into two halves. In Rust, this is `cursor.unwrap().next.take()` — same semantic, more syntax.
- The interleave phase holds `firstNext` and `secondNext` as local references simultaneously. This is trivial in Java; Rust requires careful sequencing of `take()` calls to avoid conflicting borrows.

---

## Problem 4 — Remove Nth Node From End of List (LC #19)

**Problem:** Remove the n-th node from the end of a list and return the head.

**Example:** `1→2→3→4→5`, n=2 → `1→2→3→5`

**Key insight:** Two-pointer technique. Advance `fast` by n+1 steps, then move both `fast` and `slow` together until `fast` reaches null. `slow` is then just before the target node.

**Complexity:** O(L) time (single pass), O(1) space.

```java
class Solution19 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static ListNode removeNthFromEnd(ListNode head, int n) {
        ListNode dummy = new ListNode(0);
        dummy.next = head;
        ListNode fast = dummy, slow = dummy;

        // Advance fast by n+1 steps so the gap between fast and slow is n
        for (int i = 0; i <= n; i++) fast = fast.next;

        // Move both until fast hits the end
        while (fast != null) {
            fast = fast.next;
            slow = slow.next;
        }

        // slow is just before the node to remove
        slow.next = slow.next.next;
        return dummy.next;
    }

    public static void main(String[] args) {
        if (!java.util.Arrays.equals(
            toArray(removeNthFromEnd(toList(1, 2, 3, 4, 5), 2)),
            new int[]{1, 2, 3, 5}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(removeNthFromEnd(toList(1), 1)),
            new int[]{}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(removeNthFromEnd(toList(1, 2), 2)),
            new int[]{2}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(removeNthFromEnd(toList(1, 2), 1)),
            new int[]{1}))
            throw new AssertionError("arrays not equal");
        System.out.println("LC #19 — all assertions passed");
    }
}
```

**Java notes:**
- `fast` and `slow` are two independent references into the same list — completely natural in Java. In Rust, the borrow checker prevents holding two `&mut` references into the same structure at once, so the Rust chapter resorts to counting the length (two passes). Java does it in one pass.
- `slow.next = slow.next.next` skips over the target node. The GC will collect the removed node once no reference points to it. No explicit `drop` or `free` needed.
- The dummy head absorbs the edge case of removing the actual head node — `slow` stays at `dummy` and `slow.next = slow.next.next` updates `dummy.next` to skip the old head.

---

## Problem 5 — Copy List with Random Pointer (LC #138)

**Problem:** A linked list where each node has an additional `random` pointer to any node (or null). Return a deep copy.

**Key insight:** Use a `HashMap<Node, Node>` mapping original nodes to their copies. First pass: create all copy nodes. Second pass: wire up `next` and `random` by looking up the copies in the map.

**This is where Java's GC advantage is most visible.** The Rust solution uses raw `*const` pointers, unsafe address arithmetic, and 130+ lines because `Box<T>` cannot be shared or aliased. Java handles aliasing trivially — the map holds references, references can be shared freely, the GC tracks everything.

**Complexity:** O(n) time, O(n) space.

```java
import java.util.HashMap;
import java.util.Map;

class Solution138 {
    static class Node {
        int val;
        Node next;
        Node random;
        Node(int val) { this.val = val; }
    }

    public static Node copyRandomList(Node head) {
        if (head == null) return null;

        // Pass 1: create a copy for each node
        Map<Node, Node> map = new HashMap<>();
        Node curr = head;
        while (curr != null) {
            map.put(curr, new Node(curr.val));
            curr = curr.next;
        }

        // Pass 2: wire next and random pointers using the map
        curr = head;
        while (curr != null) {
            map.get(curr).next   = map.get(curr.next);    // null-safe: map.get(null) == null
            map.get(curr).random = map.get(curr.random);
            curr = curr.next;
        }

        return map.get(head);
    }

    // --- test helpers ---
    static Node buildList(int[] vals, int[] randoms) {
        Node[] nodes = new Node[vals.length];
        for (int i = 0; i < vals.length; i++) nodes[i] = new Node(vals[i]);
        for (int i = 0; i < vals.length - 1; i++) nodes[i].next = nodes[i + 1];
        for (int i = 0; i < randoms.length; i++) {
            if (randoms[i] >= 0) nodes[i].random = nodes[randoms[i]];
        }
        return nodes[0];
    }

    static int[] collectVals(Node head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static void main(String[] args) {
        // [[7,null],[13,0],[11,4],[10,2],[1,0]]
        Node original = buildList(new int[]{7, 13, 11, 10, 1}, new int[]{-1, 0, 4, 2, 0});
        Node copied = copyRandomList(original);
        if (!java.util.Arrays.equals(collectVals(copied), new int[]{7, 13, 11, 10, 1}))
            throw new AssertionError("arrays not equal");
        // Verify it is a deep copy (different node objects)
        if (copied == original) throw new AssertionError("expected deep copy, not same reference");
        if (copied.next == original.next) throw new AssertionError("expected deep copy of .next");

        if (copyRandomList(null) != null) throw new AssertionError("expected null");
        System.out.println("LC #138 — all assertions passed");
    }
}
```

**Java notes:**
- `map.get(curr.random)` is naturally null-safe: `HashMap.get(null)` returns `null`, which is exactly the right value when `random` is null. No special-casing required.
- The entire solution is ~20 lines of logic. The Rust equivalent uses raw pointers, `unsafe` aliasing through `*const RandomNode`, `std::mem::swap`, and a separate node type — all to work around single ownership.
- Multiple nodes can have their `random` pointer aim at the same target — no problem. GC tracks all incoming references.

---

## Problem 6 — Add Two Numbers (LC #2)

**Problem:** Two non-empty linked lists represent non-negative integers in reverse order (ones digit first). Return their sum as a linked list in the same format.

**Example:** `2→4→3` + `5→6→4` = `7→0→8` (342 + 465 = 807)

**Key insight:** Simulate digit-by-digit addition with carry. Consume both lists simultaneously, appending sum digits to a dummy-headed result list.

**Complexity:** O(max(m, n)) time, O(max(m, n)) space.

```java
class Solution2 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static ListNode addTwoNumbers(ListNode l1, ListNode l2) {
        ListNode dummy = new ListNode(0);
        ListNode tail = dummy;
        int carry = 0;

        while (l1 != null || l2 != null || carry != 0) {
            int v1 = (l1 != null) ? l1.val : 0;
            int v2 = (l2 != null) ? l2.val : 0;
            int sum = v1 + v2 + carry;
            carry = sum / 10;
            tail.next = new ListNode(sum % 10);
            tail = tail.next;
            if (l1 != null) l1 = l1.next;
            if (l2 != null) l2 = l2.next;
        }

        return dummy.next;
    }

    public static void main(String[] args) {
        if (!java.util.Arrays.equals(
            toArray(addTwoNumbers(toList(2, 4, 3), toList(5, 6, 4))),
            new int[]{7, 0, 8}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(addTwoNumbers(toList(0), toList(0))),
            new int[]{0}))
            throw new AssertionError("arrays not equal");
        // 999 + 1 = 1000
        if (!java.util.Arrays.equals(
            toArray(addTwoNumbers(toList(9, 9, 9), toList(1))),
            new int[]{0, 0, 0, 1}))
            throw new AssertionError("arrays not equal");
        // 9999 + 9 = 10008
        if (!java.util.Arrays.equals(
            toArray(addTwoNumbers(toList(9, 9, 9, 9), toList(9))),
            new int[]{8, 0, 0, 0, 1}))
            throw new AssertionError("arrays not equal");
        System.out.println("LC #2 — all assertions passed");
    }
}
```

**Java notes:**
- `if (l1 != null) l1 = l1.next` advances the pointer. In Rust this is `l1 = l1.and_then(|n| n.next)` — consuming the head node and returning its `next` as the new head.
- `carry != 0` as the third loop condition correctly generates a final carry digit (e.g., 999 + 1 = 1000 outputs a fourth node).
- Node allocation with `new ListNode(sum % 10)` is simple. Rust requires `Box::new(ListNode::new(sum % 10))` plus careful tail pointer management.

---

## Problem 7 — Find the Duplicate Number (LC #287)

**Problem:** Array `nums` of n+1 integers in range [1, n]. Find the duplicate. O(1) extra space; do not modify the array.

**Why this is in the linked list chapter:** Treat `nums[i]` as a "next pointer" — index `i` links to index `nums[i]`. The duplicate value means two indices point to the same "node," creating a cycle. Floyd's cycle detection finds the cycle entrance = the duplicate.

**Key insight:** Phase 1 — detect cycle (tortoise moves 1 step, hare moves 2). Phase 2 — reset one pointer to index 0, advance both 1 step at a time; their meeting point is the duplicate.

**Complexity:** O(n) time, O(1) space.

```java
class Solution287 {
    public static int findDuplicate(int[] nums) {
        // Phase 1: detect cycle
        int slow = 0, fast = 0;
        do {
            slow = nums[slow];
            fast = nums[nums[fast]];
        } while (slow != fast);

        // Phase 2: find cycle entrance (= duplicate value)
        int slow2 = 0;
        while (slow != slow2) {
            slow  = nums[slow];
            slow2 = nums[slow2];
        }
        return slow;
    }

    public static void main(String[] args) {
        if (!(findDuplicate(new int[]{1, 3, 4, 2, 2}) == 2)) throw new AssertionError("findDuplicate(new int[]{1, 3, 4, 2, 2}) == 2");
        if (!(findDuplicate(new int[]{3, 1, 3, 4, 2}) == 3)) throw new AssertionError("findDuplicate(new int[]{3, 1, 3, 4, 2}) == 3");
        if (!(findDuplicate(new int[]{1, 1})           == 1)) throw new AssertionError("findDuplicate(new int[]{1, 1})           == 1");
        if (!(findDuplicate(new int[]{2, 5, 9, 6, 9, 3, 8, 9, 7, 1}) == 9)) throw new AssertionError("findDuplicate(new int[]{2, 5, 9, 6, 9, 3, 8, 9, 7, 1}) == 9");
        System.out.println("LC #287 — all assertions passed");
    }
}
```

**Java notes:**
- Both pointers start at index `0` — not `nums[0]`. Starting from `nums[0]` is a common mistake: phase 2's reset to `0` only makes the math work when phase 1 also started from `0`.
- No linked list nodes are created — `nums` is the implicit graph. This is conceptually a linked list problem even though it uses an array.
- Identical logic to Rust: Floyd's algorithm has no ownership issues since we only work with integer indices.

---

## Problem 8 — LRU Cache (LC #146)

**Problem:** Design a data structure that follows Least Recently Used cache policy. `get(key)` and `put(key, value)` both O(1) average.

### Approach A — Idiomatic Java: `LinkedHashMap`

Java's standard library provides `LinkedHashMap` with access-order mode. Extending it and overriding `removeEldestEntry` gives a complete LRU cache in ~10 lines.

**This is where Java's GC advantage is most pronounced.** The Rust chapter uses a counter-based HashMap (O(capacity) eviction scan) because implementing a doubly-linked list in safe Rust requires `Rc<RefCell<Node>>` with `Weak` back-pointers — a multi-hour exercise. Java does it with a built-in class.

```java
import java.util.LinkedHashMap;
import java.util.Map;

class LRUCacheLinkedHashMap extends LinkedHashMap<Integer, Integer> {
    private final int capacity;

    public LRUCacheLinkedHashMap(int capacity) {
        // true = access-order (most recently accessed moves to end; oldest at front)
        super(capacity, 0.75f, true);
        this.capacity = capacity;
    }

    public int get(int key) {
        return getOrDefault(key, -1);
    }

    public void put(int key, int value) {
        super.put(key, value);
    }

    @Override
    protected boolean removeEldestEntry(Map.Entry<Integer, Integer> eldest) {
        return size() > capacity; // evict when over capacity
    }

    public static void main(String[] args) {
        LRUCacheLinkedHashMap cache = new LRUCacheLinkedHashMap(2);
        cache.put(1, 1);
        cache.put(2, 2);
        if (!(cache.get(1) == 1)) throw new AssertionError("cache.get(1) == 1");  // returns 1; key 1 is now most-recent
        cache.put(3, 3);           // evicts key 2 (LRU)
        if (!(cache.get(2) == -1)) throw new AssertionError("cache.get(2) == -1");  // not found
        cache.put(4, 4);           // evicts key 1 (LRU at this point)
        if (!(cache.get(1) == -1)) throw new AssertionError("cache.get(1) == -1");  // not found
        if (!(cache.get(3) == 3)) throw new AssertionError("cache.get(3) == 3");
        if (!(cache.get(4) == 4)) throw new AssertionError("cache.get(4) == 4");

        LRUCacheLinkedHashMap c2 = new LRUCacheLinkedHashMap(1);
        c2.put(2, 1);
        if (!(c2.get(2) == 1)) throw new AssertionError("c2.get(2) == 1");
        c2.put(3, 2);
        if (!(c2.get(2) == -1)) throw new AssertionError("c2.get(2) == -1");
        if (!(c2.get(3) == 2)) throw new AssertionError("c2.get(3) == 2");

        System.out.println("LC #146 (LinkedHashMap) — all assertions passed");
    }
}
```

### Approach B — Manual Doubly-Linked List + HashMap

For interviews that ask you to implement from scratch: maintain a doubly-linked list where the head is the least-recently-used node and the tail is the most-recently-used. A `HashMap` provides O(1) lookup; list operations provide O(1) move-to-tail and remove-head.

```java
import java.util.HashMap;
import java.util.Map;

class LRUCacheManual {
    // Doubly-linked list node
    private static class DLNode {
        int key, val;
        DLNode prev, next;
        DLNode(int key, int val) { this.key = key; this.val = val; }
    }

    private final int capacity;
    private final Map<Integer, DLNode> map = new HashMap<>();
    // Sentinel head (LRU end) and tail (MRU end)
    private final DLNode head = new DLNode(0, 0);
    private final DLNode tail = new DLNode(0, 0);

    public LRUCacheManual(int capacity) {
        this.capacity = capacity;
        head.next = tail;
        tail.prev = head;
    }

    private void remove(DLNode node) {
        node.prev.next = node.next;
        node.next.prev = node.prev;
    }

    private void addToTail(DLNode node) {
        // Insert just before the sentinel tail
        node.prev = tail.prev;
        node.next = tail;
        tail.prev.next = node;
        tail.prev = node;
    }

    public int get(int key) {
        DLNode node = map.get(key);
        if (node == null) return -1;
        remove(node);
        addToTail(node);  // mark as most-recently-used
        return node.val;
    }

    public void put(int key, int value) {
        DLNode existing = map.get(key);
        if (existing != null) {
            existing.val = value;
            remove(existing);
            addToTail(existing);
            return;
        }
        if (map.size() == capacity) {
            // Evict LRU node (just after sentinel head)
            DLNode lru = head.next;
            remove(lru);
            map.remove(lru.key);
        }
        DLNode node = new DLNode(key, value);
        addToTail(node);
        map.put(key, node);
    }

    public static void main(String[] args) {
        LRUCacheManual cache = new LRUCacheManual(2);
        cache.put(1, 1);
        cache.put(2, 2);
        if (!(cache.get(1) == 1)) throw new AssertionError("cache.get(1) == 1");
        cache.put(3, 3);
        if (!(cache.get(2) == -1)) throw new AssertionError("cache.get(2) == -1");
        cache.put(4, 4);
        if (!(cache.get(1) == -1)) throw new AssertionError("cache.get(1) == -1");
        if (!(cache.get(3) == 3)) throw new AssertionError("cache.get(3) == 3");
        if (!(cache.get(4) == 4)) throw new AssertionError("cache.get(4) == 4");

        // Update existing key — should not evict
        LRUCacheManual c2 = new LRUCacheManual(2);
        c2.put(1, 1);
        c2.put(2, 2);
        c2.put(1, 10);
        if (!(c2.get(1) == 10)) throw new AssertionError("c2.get(1) == 10");
        if (!(c2.get(2) == 2)) throw new AssertionError("c2.get(2) == 2");

        System.out.println("LC #146 (manual DLL) — all assertions passed");
    }
}
```

**Java notes:**
- The doubly-linked list is straightforward: `node.prev` and `node.next` are plain references. The GC tracks the web of pointers automatically.
- In Rust, each `next` and `prev` would require `Option<Rc<RefCell<DLNode>>>` and `Option<Weak<RefCell<DLNode>>>` respectively — roughly 5x more type annotation per field — to avoid violating single ownership and prevent reference cycles from leaking memory.
- Sentinel nodes (`head`, `tail`) eliminate null-checks in `remove` and `addToTail` — a clean pattern regardless of language.

---

## Problem 9 — Merge K Sorted Lists (LC #23)

**Problem:** Merge k sorted linked lists into one sorted linked list.

**Key insight:** Use a min-heap (`PriorityQueue`). Seed it with each list's head. Repeatedly poll the minimum, append to result, push its `next` into the heap if non-null.

**Complexity:** O(N log k) time where N = total nodes, k = number of lists; O(k) heap space.

```java
import java.util.Comparator;
import java.util.PriorityQueue;

class Solution23 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    public static ListNode mergeKLists(ListNode[] lists) {
        // Java 17: lambda comparator — clean and concise
        PriorityQueue<ListNode> pq = new PriorityQueue<>(Comparator.comparingInt(n -> n.val));

        for (ListNode head : lists) {
            if (head != null) pq.offer(head);
        }

        ListNode dummy = new ListNode(0), tail = dummy;
        while (!pq.isEmpty()) {
            ListNode node = pq.poll();
            tail.next = node;
            tail = tail.next;
            if (node.next != null) pq.offer(node.next);
        }

        return dummy.next;
    }

    public static void main(String[] args) {
        if (!java.util.Arrays.equals(
            toArray(mergeKLists(new ListNode[]{
                toList(1, 4, 5), toList(1, 3, 4), toList(2, 6)
            })),
            new int[]{1, 1, 2, 3, 4, 4, 5, 6}))
            throw new AssertionError("arrays not equal");

        if (!java.util.Arrays.equals(
            toArray(mergeKLists(new ListNode[]{})),
            new int[]{}))
            throw new AssertionError("arrays not equal");

        if (!java.util.Arrays.equals(
            toArray(mergeKLists(new ListNode[]{null, null})),
            new int[]{}))
            throw new AssertionError("arrays not equal");

        if (!java.util.Arrays.equals(
            toArray(mergeKLists(new ListNode[]{toList(1, 2, 3)})),
            new int[]{1, 2, 3}))
            throw new AssertionError("arrays not equal");

        System.out.println("LC #23 — all assertions passed");
    }
}
```

**Java notes:**
- `PriorityQueue<ListNode>` with `Comparator.comparingInt(n -> n.val)` is the cleanest Java 17 form — no boilerplate. Java's `PriorityQueue` is a min-heap by default.
- In Rust, `BinaryHeap` is a max-heap, so you must either reverse the comparison inside a `NodeWrapper` newtype or wrap values in `std::cmp::Reverse`. Neither is needed in Java.
- `pq.offer(node.next)` inserts the next node from the same list. No ownership transfer — the reference is simply added to the heap's internal array.

---

## Problem 10 — Reverse Nodes in K-Group (LC #25)

**Problem:** Reverse the nodes of the list k at a time. If fewer than k nodes remain, leave them as-is.

**Example:** `1→2→3→4→5`, k=2 → `2→1→4→3→5`; k=3 → `3→2→1→4→5`

**Key insight:** (1) Check that at least k nodes remain starting from `curr`. (2) Detach exactly k nodes. (3) Reverse that segment. (4) Connect reversed segment back into the result list. (5) Advance and repeat.

**Complexity:** O(n) time, O(1) space (iterative form).

```java
class Solution25 {
    static class ListNode {
        int val; ListNode next;
        ListNode(int val) { this.val = val; }
        ListNode(int val, ListNode next) { this.val = val; this.next = next; }
    }

    static ListNode toList(int... vals) {
        ListNode dummy = new ListNode(0), tail = dummy;
        for (int v : vals) { tail.next = new ListNode(v); tail = tail.next; }
        return dummy.next;
    }

    static int[] toArray(ListNode head) {
        java.util.List<Integer> list = new java.util.ArrayList<>();
        while (head != null) { list.add(head.val); head = head.next; }
        return list.stream().mapToInt(Integer::intValue).toArray();
    }

    /** Returns the k-th node from start, or null if fewer than k nodes exist. */
    private static ListNode getKth(ListNode curr, int k) {
        while (curr != null && k > 0) {
            curr = curr.next;
            k--;
        }
        return curr;
    }

    public static ListNode reverseKGroup(ListNode head, int k) {
        ListNode dummy = new ListNode(0);
        dummy.next = head;
        ListNode groupPrev = dummy;

        while (true) {
            ListNode kth = getKth(groupPrev, k);
            if (kth == null) break; // fewer than k nodes remain

            ListNode groupNext = kth.next; // node after the k-group

            // Reverse the k-group: groupPrev.next .. kth
            ListNode prev = groupNext; // reverse into groupNext direction
            ListNode curr = groupPrev.next;
            while (curr != groupNext) {
                ListNode next = curr.next;
                curr.next = prev;
                prev = curr;
                curr = next;
            }

            // Re-connect: groupPrev → new head of reversed group
            ListNode oldGroupHead = groupPrev.next; // will become tail of reversed group
            groupPrev.next = kth;                   // kth is now the new head after reversal
            groupPrev = oldGroupHead;                // advance groupPrev to end of reversed group
        }

        return dummy.next;
    }

    public static void main(String[] args) {
        if (!java.util.Arrays.equals(
            toArray(reverseKGroup(toList(1, 2, 3, 4, 5), 2)),
            new int[]{2, 1, 4, 3, 5}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseKGroup(toList(1, 2, 3, 4, 5), 3)),
            new int[]{3, 2, 1, 4, 5}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseKGroup(toList(1, 2, 3), 1)),
            new int[]{1, 2, 3}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseKGroup(toList(1, 2, 3), 3)),
            new int[]{3, 2, 1}))
            throw new AssertionError("arrays not equal");
        if (!java.util.Arrays.equals(
            toArray(reverseKGroup(toList(1), 1)),
            new int[]{1}))
            throw new AssertionError("arrays not equal");
        System.out.println("LC #25 — all assertions passed");
    }
}
```

**Java notes:**
- `getKth(groupPrev, k)` walks k steps from `groupPrev`. If it returns null, fewer than k nodes remain and the loop exits — leaving the tail unchanged.
- The in-place reversal loop `while (curr != groupNext)` terminates at the saved boundary. In Rust, the analogous `take_k` helper must double-traverse (count first, then take) because the borrow checker blocks simultaneous counting and mutation. Java inspects and mutates in the same pass without ceremony.
- `groupPrev = oldGroupHead` advances to the tail of the reversed group, which becomes the `prev` anchor for the next group. This pointer juggling is straightforward because all references coexist without ownership constraints.

---

## Quick Pattern Reference (Java)

| Pattern | Java idiom | When to use |
|---|---|---|
| Advance pointer | `curr = curr.next;` | Any traversal |
| Dummy head | `ListNode dummy = new ListNode(0); ListNode tail = dummy;` | Building new list, avoiding head edge case |
| Two-pointer (same list) | `ListNode slow = head, fast = head;` | Cycle detection, find middle, nth from end |
| Null-safe remainder attach | `tail.next = (l1 != null) ? l1 : l2;` | Merge sorted lists |
| Min-heap of nodes | `new PriorityQueue<>(Comparator.comparingInt(n -> n.val))` | Merge k sorted lists |
| HashMap for node copies | `Map<Node, Node> map = new HashMap<>();` | Copy list with random pointer |
| LRU (idiomatic) | `LinkedHashMap` + `removeEldestEntry` | LRU cache — production/interview shorthand |
| LRU (from scratch) | `HashMap<Integer, DLNode>` + sentinel DLL | LRU cache — when asked to implement manually |
| Floyd's cycle (array) | `slow = nums[slow]; fast = nums[nums[fast]];` | Find duplicate (implicit linked list) |
| Skip a node | `prev.next = prev.next.next;` | Remove nth from end, delete node |

---

## Java vs. Rust Linked List Cheat Sheet

| Operation | Java | Rust | Why different |
|---|---|---|---|
| Assign next pointer | `node.next = other;` | `node.next = Some(other_box);` | Rust requires heap allocation via `Box` |
| Set next to null | `node.next = null;` | `node.next = None;` | Same concept, different syntax |
| Null check | `node.next != null` | `node.next.is_some()` | `Option` wrapping |
| Move/advance ownership | `curr = curr.next;` | `curr = curr.next.take();` | `take()` moves out of `Option`, sets to `None` |
| Two refs into same list | Natural — no ceremony | Borrow checker blocks two `&mut` refs | Java GC vs. Rust ownership |
| Multiple nodes pointing to same target | Free — GC handles | Requires `Rc<RefCell<Node>>` | Reference aliasing |
| Doubly-linked node | `Node prev, next;` | `Option<Rc<RefCell<Node>>>` each | `Rc` for shared ownership + `RefCell` for mutation |
| Peek without advancing | `if (head != null) use head.val` | `head.as_ref()` to borrow | Rust must distinguish borrow from move |
| Min-heap comparator | `Comparator.comparingInt(n -> n.val)` | Newtype + reversed `Ord` impl | Java has lambda comparators; Rust needs `Ord` |
| Copy list with aliasing | `Map<Node, Node>` (~20 lines) | Raw pointers + 130 lines | Single ownership cannot represent aliasing |

---

## 📝 Chapter Review Notes

**Correctness verification (all 10 problems):**

- **LC #206** — Three-pointer iterative reverse is canonical. `curr.next = prev` flips the pointer; `prev = curr; curr = next` advances. The loop terminates when `curr == null` and returns `prev` (the new head). Handles empty list and single-node list cleanly.

- **LC #21** — Dummy-head merge with remainder attachment (`tail.next = (l1 != null) ? l1 : l2`) is O(1) per iteration. The ternary null-check for the trailing sub-list is cleaner than a second loop. All three edge cases tested: both empty, one empty, both non-empty.

- **LC #143** — Slow/fast midpoint in one pass (Java advantage over Rust's two-pass). The disconnect at `slow.next = null` is essential before the reversal to avoid cycles. Interleave terminates when `second == null`; the first half may have one extra node (for odd-length lists), which stays correctly attached.

- **LC #19** — True one-pass two-pointer (Java advantage: Rust falls back to two-pass due to borrow checker). The `dummy` head absorbs the remove-head edge case. Advancing `fast` by `n+1` (not `n`) ensures `slow` lands one node before the target.

- **LC #138** — 20 lines of logic vs. 130+ in Rust. `map.get(null) == null` means the `random` wiring is null-safe without any special-casing. Deep-copy verified by checking `copied != original` and `copied.next != original.next`.

- **LC #2** — `carry != 0` as the third `while` condition correctly handles final carry propagation (999 + 1 = 1000). Advancing `l1`/`l2` only when non-null handles unequal-length inputs. Four test cases including edge cases pass.

- **LC #287** — `do-while` in phase 1 avoids the false early exit when `slow == fast == 0` before either advances. Both pointers start at index `0` — starting from `nums[0]` is a common error that causes phase 2 to diverge. Four test cases including a 10-element array pass.

- **LC #146 (LinkedHashMap)** — `super(capacity, 0.75f, true)` sets access-order mode: every `get` and `put` moves the accessed entry to the tail. `removeEldestEntry` fires after every `put`; returning `size() > capacity` evicts the front (LRU) entry when over capacity. True O(1) for all operations.

- **LC #146 (manual DLL)** — Sentinel nodes eliminate all null-pointer checks in `remove` and `addToTail`. `remove` is three pointer assignments; `addToTail` is four. Both are O(1). Eviction is O(1) by removing `head.next` (the LRU node). Update-existing-key tested explicitly to verify no spurious eviction.

- **LC #23** — `PriorityQueue` with `Comparator.comparingInt` is naturally a min-heap. Seeding with all list heads, then poll-advance-offer loop is O(N log k). Empty input, all-null-heads, and single-list cases all tested.

- **LC #25** — `getKth` returns the k-th successor or null (fewer-than-k sentinel). The reversal loop `while (curr != groupNext)` terminates exactly at the group boundary without pre-computing length. `groupPrev` advances to `oldGroupHead` (which becomes the reversed segment's tail) for correct anchoring of the next group.

**Why Java is simpler for linked lists:**

1. **No ownership model** — references can be held and shared freely. The GC tracks liveness.
2. **True two-pointer** — two `ListNode` variables can both point into the same list with no borrow conflict.
3. **Natural aliasing** — `random` pointers, doubly-linked `prev` pointers, and cache maps with node references all work without `Rc<RefCell<>>`.
4. **Built-in `LinkedHashMap`** — LRU cache in ~10 lines vs. Rust's counter-based workaround.
5. **Lambda comparators** — `Comparator.comparingInt(n -> n.val)` vs. Rust's newtype + `Ord` impl.

**Patterns established in this chapter:**

1. Dummy head + tail pointer — avoids head-node edge cases when building a new list.
2. Slow/fast two-pointer — finds midpoint (LC #143) and n-th from end (LC #19) in one pass.
3. Floyd's cycle detection — cycle detection (LC #287) and cycle-entrance finding.
4. HashMap for node identity — O(1) node lookup without index arithmetic (LC #138, #146).
5. Sentinel doubly-linked list — O(1) insert/remove with no null-checks (LC #146 manual).
6. `PriorityQueue` with comparator — O(N log k) merge of k sorted sequences (LC #23).

**What this chapter does not cover:**

- Thread-safe caches (`ConcurrentHashMap` + `ConcurrentLinkedDeque`).
- Skip lists and other probabilistic linked structures.
- The Java `LinkedList` class (an internal doubly-linked list) — useful for `Deque` operations but not idiomatic for LeetCode-style problems.
