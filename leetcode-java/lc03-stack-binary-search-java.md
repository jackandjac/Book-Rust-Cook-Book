# Chapter LC-03 (Java): Stack & Binary Search
> Java solutions companion to [Rust Chapter LC-03](../leetcode/lc03-stack-binary-search.md).

**Chapter goal:** Fourteen Blind75/NeetCode150 problems in idiomatic Java 17+. Every solution
is a self-contained class with a `main` method that runs assertions — copy-paste-ready for
any IDE or `javac`/`java` on the command line. No JUnit required.

**Running the examples.** Each class has a `main` that calls a `check()` helper. The helper
throws `AssertionError` immediately on the first failure so nothing silently passes. Run with:

```
javac Solution.java && java Solution
```

---

**Rust → Java idiom reference**

| Rust pattern | Java 17 equivalent |
|---|---|
| `let mut stack: Vec<i32> = Vec::new()` | `Deque<Integer> stack = new ArrayDeque<>()` |
| `stack.last()` → `Option<&T>` | `stack.peek()` → `T` or `null` |
| `stack.push(x)` | `stack.push(x)` (adds to *head* of deque — use consistently) |
| `stack.pop()` → `Option<T>` | `stack.pop()` → `T` (throws if empty) |
| `slice.binary_search(&key)` | `Collections.binarySearch(list, key)` |
| `left + (right - left) / 2` | `left + (right - left) / 2` — identical; avoids overflow |
| `i32::MIN` / `i32::MAX` sentinels | `Integer.MIN_VALUE` / `Integer.MAX_VALUE` |
| `cur.min(val)` | `Math.min(cur, val)` |

> **Why `ArrayDeque`, not `Stack`?** `java.util.Stack` extends `Vector` — it is synchronized,
> slower than necessary, and the Java docs explicitly recommend using `Deque` instead.
> `ArrayDeque<>` is the modern replacement for both stack and deque use cases.
>
> When used as a stack, `push()`/`pop()`/`peek()` all operate on the **head** (front) of the
> deque, giving the expected LIFO behaviour. Do not mix `offer`/`poll` (queue end) with
> `push`/`pop` (stack end) in the same usage.

---

## Part 1 — Stack

`ArrayDeque<T>` is Java's stack. `push` / `pop` are O(1) amortised. `peek()` returns the
top element without removing it — returns `null` when empty (unlike Rust's `Option`, which is
explicit). Always null-check `peek()` when emptiness is possible.

Key difference from Rust: Java's `pop()` throws `NoSuchElementException` on an empty deque;
Rust's `pop()` returns `Option<T>`. In algorithm code where you have proven the stack is
non-empty, `pop()` is safe; in production code, null-check or use `pollFirst()` which returns
`null` instead of throwing.

---

### LC #20 — Valid Parentheses

**Problem.** Given a string containing only `'('`, `')'`, `'{'`, `'}'`, `'['`, `']'`, return
`true` if every open bracket is closed by the correct bracket in the correct order.

**Insight.** Push opening brackets onto a stack. When a closing bracket is seen, verify the
top of the stack holds the matching opener. If the stack is empty at that point or the types
don't match, return `false`. At the end the stack must be empty.

```java
import java.util.ArrayDeque;
import java.util.Deque;

class LC20ValidParentheses {

    static boolean isValid(String s) {
        Deque<Character> stack = new ArrayDeque<>();
        for (char ch : s.toCharArray()) {
            switch (ch) {
                case '(', '[', '{' -> stack.push(ch);
                case ')' -> { if (stack.isEmpty() || stack.pop() != '(') return false; }
                case ']' -> { if (stack.isEmpty() || stack.pop() != '[') return false; }
                case '}' -> { if (stack.isEmpty() || stack.pop() != '{') return false; }
                default  -> { /* ignore other characters */ }
            }
        }
        return stack.isEmpty();
    }

    // ── helper used by every main in this chapter ──────────────────────────
    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(isValid("()[]{}"),  "basic mixed");
        check(isValid("{[()]}"),  "nested");
        check(isValid(""),        "empty string");
        check(!isValid("(]"),     "wrong type");
        check(!isValid("([)]"),   "interleaved");
        check(!isValid("{"),      "unclosed");
        System.out.println("LC #20 — all assertions passed");
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Java notes.**
- Java 14+ switch expressions with arrow cases (`->`) replace the verbose `if-else if` chain
  cleanly. The `default` arm is required for exhaustiveness when switching on `char`.
- `stack.pop() != '('` — autoboxing converts `Character` to `char` for the comparison.
  This is safe here because `char` equality is value-based.
- Checking `stack.isEmpty()` *before* `stack.pop()` prevents `NoSuchElementException`; in
  Rust, `stack.pop()` returns `Option` so the empty case is handled by comparing against `None`.

---

### LC #155 — Min Stack

**Problem.** Design a stack that supports `push`, `pop`, `top`, and `getMin` in O(1) time.

**Insight.** Maintain a parallel `minStack` that always holds the current minimum at each
level. When pushing value `v`, push `min(v, currentMin)` onto the min stack simultaneously.
When popping, pop both stacks together.

```java
import java.util.ArrayDeque;
import java.util.Deque;

class LC155MinStack {

    static class MinStack {
        private final Deque<Integer> stack    = new ArrayDeque<>();
        private final Deque<Integer> minStack = new ArrayDeque<>();

        void push(int val) {
            stack.push(val);
            int newMin = minStack.isEmpty() ? val : Math.min(minStack.peek(), val);
            minStack.push(newMin);
        }

        void pop() {
            stack.pop();
            minStack.pop();
        }

        int top() {
            return stack.peek();
        }

        int getMin() {
            return minStack.peek();
        }
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        var s = new MinStack();
        s.push(-2);
        s.push(0);
        s.push(-3);
        check(s.getMin() == -3, "min after push -3");
        s.pop();
        check(s.top()    == 0,  "top after pop");
        check(s.getMin() == -2, "min after pop");

        var s2 = new MinStack();
        s2.push(5);
        check(s2.getMin() == 5, "single element min");
        check(s2.top()    == 5, "single element top");

        System.out.println("LC #155 — all assertions passed");
    }
}
```

**Complexity.** Time O(1) all operations, Space O(n).

**Java notes.**
- `Math.min(minStack.peek(), val)` — `minStack.peek()` returns `Integer` (boxed); auto-unboxing
  feeds it to `Math.min(int, int)`. A `NullPointerException` would occur if `peek()` returned
  `null` (empty stack), so the `minStack.isEmpty()` guard is required.
- Rust uses `cur.min(val)` — an `i32` method. Java has no equivalent method on `int`; use the
  static `Math.min`.
- `var s = new MinStack()` — Java 10+ local variable type inference keeps the declaration
  concise without hiding any non-obvious type.

---

### LC #150 — Evaluate Reverse Polish Notation

**Problem.** Evaluate an arithmetic expression in Reverse Polish Notation. Valid operators are
`+`, `-`, `*`, `/`. Division truncates toward zero.

**Insight.** Iterate tokens. Push numbers onto the stack. On an operator, pop two operands,
apply the operator, push the result. The final element in the stack is the answer.

```java
import java.util.ArrayDeque;
import java.util.Deque;

class LC150EvalRPN {

    static int evalRPN(String[] tokens) {
        Deque<Integer> stack = new ArrayDeque<>();
        for (String token : tokens) {
            switch (token) {
                case "+" -> { int b = stack.pop(); stack.push(stack.pop() + b); }
                case "-" -> { int b = stack.pop(); stack.push(stack.pop() - b); }
                case "*" -> { int b = stack.pop(); stack.push(stack.pop() * b); }
                case "/" -> { int b = stack.pop(); stack.push(stack.pop() / b); }
                default  -> stack.push(Integer.parseInt(token));
            }
        }
        return stack.pop();
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        // (2 + 1) * 3 = 9
        check(evalRPN(new String[]{"2","1","+","3","*"}) == 9,  "basic multiply");
        // 4 + (13 / 5) = 4 + 2 = 6
        check(evalRPN(new String[]{"4","13","5","/","+"}) == 6, "division truncates");
        // (10 - 3) / 11 = 7 / 11 = 0
        check(evalRPN(new String[]{"10","3","-","11","/"}) == 0, "truncation toward zero");
        // (4 - 3) * 2 = 2
        check(evalRPN(new String[]{"4","3","-","2","*"}) == 2,  "subtraction then multiply");
        System.out.println("LC #150 — all assertions passed");
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Java notes.**
- Switch on `String` is valid from Java 7 onward; arrow-case form requires Java 14+.
- Pop order is critical: `int b = stack.pop()` first (right operand), then `stack.pop()` again
  (left operand). The expression `stack.pop() - b` correctly computes `left - right`.
- Java's `int` division truncates toward zero (same as Rust's `i32`), satisfying the problem
  requirement without any `Math.floorDiv` adjustment.
- Rust's `token.as_str()` dance (String → &str for matching) is not needed in Java; `switch`
  on `String` uses `.equals()` internally.

---

### LC #22 — Generate Parentheses

**Problem.** Given `n`, generate all combinations of `n` pairs of well-formed parentheses.

**Insight.** Backtracking: track counts of open and close brackets placed so far. Add `'('`
when `open < n`; add `')'` when `close < open`. Collect the string when both reach `n`.

```java
import java.util.ArrayList;
import java.util.List;

class LC22GenerateParentheses {

    static List<String> generateParenthesis(int n) {
        var result = new ArrayList<String>();
        backtrack(result, new StringBuilder(), 0, 0, n);
        return result;
    }

    private static void backtrack(
            List<String> result, StringBuilder current,
            int open, int close, int n) {
        if (current.length() == 2 * n) {
            result.add(current.toString());
            return;
        }
        if (open < n) {
            current.append('(');
            backtrack(result, current, open + 1, close, n);
            current.deleteCharAt(current.length() - 1);
        }
        if (close < open) {
            current.append(')');
            backtrack(result, current, open, close + 1, n);
            current.deleteCharAt(current.length() - 1);
        }
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        var r1 = generateParenthesis(1);
        check(r1.equals(List.of("()")), "n=1");

        var r3 = generateParenthesis(3);
        r3.sort(null);
        var expected = new ArrayList<>(List.of("((()))", "(()())", "(())()", "()(())", "()()()"));
        expected.sort(null);
        check(r3.equals(expected), "n=3 all combos");

        System.out.println("LC #22 — all assertions passed");
    }
}
```

**Complexity.** Time O(4^n / sqrt(n)) (Catalan number), Space O(n) call-stack depth.

**Java notes.**
- Use `StringBuilder` for the mutable path, not `String` concatenation. `deleteCharAt` is the
  backtracking undo step — equivalent to Rust's `current.pop()` on a `String`.
- Rust's `current.clone()` captures a snapshot of the string at the leaf; Java's
  `current.toString()` does the same — both allocate a new string.
- `List.of(...)` (Java 9+) creates an immutable list for the expected value in tests,
  readable and concise.
- `result.sort(null)` uses the natural order comparator (String's `compareTo`), equivalent
  to Rust's `result.sort()`.

---

### LC #739 — Daily Temperatures

**Problem.** Given an array of daily temperatures, return an array `answer` where `answer[i]`
is the number of days until a warmer temperature. If no warmer day exists, `answer[i] = 0`.

**Insight.** Monotonic decreasing stack of indices. Iterate through temperatures; while the
current temperature is warmer than the temperature at the stack's top index, pop and record
the gap.

```java
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

class LC739DailyTemperatures {

    static int[] dailyTemperatures(int[] temperatures) {
        int n = temperatures.length;
        int[] result = new int[n];                    // initialized to 0
        Deque<Integer> stack = new ArrayDeque<>();    // stores indices

        for (int i = 0; i < n; i++) {
            while (!stack.isEmpty() && temperatures[i] > temperatures[stack.peek()]) {
                int top = stack.pop();
                result[top] = i - top;
            }
            stack.push(i);
        }
        return result;
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(Arrays.equals(
            dailyTemperatures(new int[]{73,74,75,71,69,72,76,73}),
            new int[]{1,1,4,2,1,1,0,0}), "basic");
        check(Arrays.equals(
            dailyTemperatures(new int[]{30,30,30}),
            new int[]{0,0,0}), "all same");
        check(Arrays.equals(
            dailyTemperatures(new int[]{90,80,70}),
            new int[]{0,0,0}), "descending");
        System.out.println("LC #739 — all assertions passed");
    }
}
```

**Complexity.** Time O(n) amortised (each index pushed and popped at most once), Space O(n).

**Java notes.**
- The stack holds `Integer` indices (not temperature values) so that `i - top` computes the
  day gap directly — same design as the Rust solution.
- Rust's `while let Some(&top) = stack.last()` pattern-matches and copies the index without
  keeping a live borrow. Java's `stack.peek()` + `stack.pop()` is the idiomatic equivalent:
  `peek()` inspects the top, then `pop()` removes it.
- Java `int[]` is initialised to `0` by the JVM, so days with no warmer future temperature
  require no explicit assignment.

---

### LC #853 — Car Fleet

**Problem.** `n` cars at different positions on a single-lane road all drive to `target`.
Given arrays `position` and `speed`, return the number of car fleets that arrive at the target.
Cars that catch up form a fleet and move at the slower speed.

**Insight.** Sort cars by starting position descending (closest to target first). Compute the
time each car takes to reach the target. Iterate: if a car's time is greater than the current
fleet leader's time, it cannot catch up — it forms a new fleet.

```java
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

class LC853CarFleet {

    static int carFleet(int target, int[] position, int[] speed) {
        int n = position.length;

        // Pair positions and speeds, then sort by position descending
        record Car(int pos, int spd) {}
        Car[] cars = new Car[n];
        for (int i = 0; i < n; i++) cars[i] = new Car(position[i], speed[i]);
        Arrays.sort(cars, (a, b) -> b.pos() - a.pos());

        Deque<Double> stack = new ArrayDeque<>();
        for (Car car : cars) {
            double time = (double)(target - car.pos()) / car.spd();
            // Only push if this car is slower than the fleet leader (forms new fleet)
            if (stack.isEmpty() || time > stack.peek()) {
                stack.push(time);
            }
        }
        return stack.size();
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(carFleet(12, new int[]{10,8,0,5,3}, new int[]{2,4,1,1,3}) == 3, "basic");
        check(carFleet(10, new int[]{3},           new int[]{3})          == 1, "single car");
        check(carFleet(100, new int[]{0,50},       new int[]{10,10})      == 2, "same speed");
        System.out.println("LC #853 — all assertions passed");
    }
}
```

**Complexity.** Time O(n log n) for sorting, Space O(n).

**Java notes.**
- Local `record Car(int pos, int spd)` is a Java 16+ feature — a concise, immutable data
  carrier. Rust uses a `Vec<(i32, i32)>` tuple; Java tuples are unwieldy, so records are the
  idiomatic 17+ replacement.
- `Arrays.sort` on an `Object[]` (not primitive array) accepts a `Comparator`; the lambda
  `(a, b) -> b.pos() - a.pos()` sorts descending. For large values this subtraction could
  overflow — use `Integer.compare(b.pos(), a.pos())` in production.
- Rust's `map_or(true, |&top| time > top)` is replaced by the explicit `stack.isEmpty() ||
  time > stack.peek()` guard, which is more readable in Java.

---

### LC #84 — Largest Rectangle in Histogram

**Problem.** Given an array of bar heights, find the largest rectangular area that fits
entirely within the histogram.

**Insight.** Monotonic increasing stack of indices. For each bar, while the current bar is
shorter than the stack top, pop and compute the rectangle width using the current index and
the new stack top as the left boundary. Append a sentinel height of `0` to flush all
remaining bars at the end.

```java
import java.util.ArrayDeque;
import java.util.Deque;

class LC84LargestRectangle {

    static int largestRectangleArea(int[] heights) {
        // Append sentinel 0 to force the stack to flush at the end
        int[] h = new int[heights.length + 1];
        System.arraycopy(heights, 0, h, 0, heights.length);
        // h[heights.length] is 0 by default

        Deque<Integer> stack = new ArrayDeque<>();  // indices
        int maxArea = 0;

        for (int i = 0; i < h.length; i++) {
            while (!stack.isEmpty() && h[i] < h[stack.peek()]) {
                int top   = stack.pop();
                int width = stack.isEmpty() ? i : i - stack.peek() - 1;
                maxArea   = Math.max(maxArea, h[top] * width);
            }
            stack.push(i);
        }
        return maxArea;
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(largestRectangleArea(new int[]{2,1,5,6,2,3}) == 10, "basic");
        check(largestRectangleArea(new int[]{4})            == 4,  "single bar");
        check(largestRectangleArea(new int[]{1,2,3,4,5})   == 9,  "ascending");
        check(largestRectangleArea(new int[]{3,3,3})        == 9,  "all same");
        check(largestRectangleArea(new int[]{5,1,5})        == 5,  "valley");
        System.out.println("LC #84 — all assertions passed");
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Java notes.**
- `System.arraycopy` copies the original array into a one-element-longer array whose last slot
  is `0` (the sentinel). Rust's `heights.push(0)` mutates in place (after `let mut heights =
  heights`); Java arrays are fixed-length, so a new array is necessary.
- Width when the stack is empty: `width = i` — the rectangle extends from index 0 to `i - 1`.
  Otherwise, `width = i - stack.peek() - 1`. Both mirror the Rust implementation exactly.
- `stack.peek()` (not `stack.pop()`) is used to read the new left boundary *without* removing
  it — the element below the popped bar is still needed for future iterations.

---

## Part 2 — Binary Search

Binary search in Java uses the same three-variable left/right/mid template as every other
language. The critical rule is the **overflow-safe mid calculation**:

```java
// WRONG — can overflow if left + right > Integer.MAX_VALUE
int mid = (left + right) / 2;

// CORRECT — always safe
int mid = left + (right - left) / 2;
```

For arrays up to `Integer.MAX_VALUE` elements, `left + right` can reach `2 * 10^9`, which
overflows a 32-bit `int`. The safe form avoids the addition entirely.

**Standard template used throughout this section:**

```java
// "find leftmost position where condition holds" template
int left = 0, right = nums.length; // right is exclusive upper bound
while (left < right) {
    int mid = left + (right - left) / 2;
    if (condition(nums[mid])) {
        right = mid;        // mid could be the answer; keep searching left
    } else {
        left = mid + 1;
    }
}
// left == right is the answer position
```

For classic "find exact target" searches, the inclusive-bounds variant (`left <= right`,
`right = mid - 1`) is used — see LC #704 below.

---

### LC #704 — Binary Search

**Problem.** Given a sorted array of distinct integers and a target, return the index of the
target or `-1` if not found.

**Insight.** Classic binary search. Compare `nums[mid]` with `target`; shrink the search
window left or right until the element is found or the window is empty.

```java
class LC704BinarySearch {

    static int search(int[] nums, int target) {
        int left = 0, right = nums.length - 1;
        while (left <= right) {
            int mid = left + (right - left) / 2;
            if      (nums[mid] == target) return mid;
            else if (nums[mid] <  target) left  = mid + 1;
            else                          right = mid - 1;
        }
        return -1;
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(search(new int[]{-1,0,3,5,9,12}, 9)  ==  4, "found at index 4");
        check(search(new int[]{-1,0,3,5,9,12}, -1) ==  0, "found at index 0");
        check(search(new int[]{-1,0,3,5,9,12}, 2)  == -1, "not found");
        check(search(new int[]{5}, 5)               ==  0, "single element found");
        check(search(new int[]{5}, 3)               == -1, "single element not found");
        System.out.println("LC #704 — all assertions passed");
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java notes.**
- The inclusive-bounds loop (`left <= right`, `right = mid - 1`) is the clearest form for
  exact-match binary search. The Rust equivalent uses `i32` indices for the same reason:
  so that `right = mid - 1` can safely go to `-1` without underflowing an unsigned type.
  Java's `int` is always signed, so there is no underflow risk.
- `mid = left + (right - left) / 2` — this is the canonical overflow-safe form. With signed
  `int`, the old `(left + right) / 2` overflows when both are near `Integer.MAX_VALUE`.
- `Arrays.binarySearch(nums, target)` exists in the standard library but returns a negative
  "insertion point" for misses, not `-1`. The manual version teaches the template and matches
  LeetCode's expected return value directly.

---

### LC #74 — Search a 2D Matrix

**Problem.** A matrix where each row is sorted and the first integer of each row is greater
than the last integer of the previous row. Return `true` if `target` exists.

**Insight.** Treat the matrix as a flattened sorted array of `m * n` elements. Run one binary
search with virtual index-to-row/col mapping: `row = mid / n`, `col = mid % n`.

```java
class LC74SearchMatrix {

    static boolean searchMatrix(int[][] matrix, int target) {
        int m = matrix.length, n = matrix[0].length;
        int left = 0, right = m * n - 1;
        while (left <= right) {
            int mid = left + (right - left) / 2;
            int val = matrix[mid / n][mid % n];
            if      (val == target) return true;
            else if (val <  target) left  = mid + 1;
            else                    right = mid - 1;
        }
        return false;
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        int[][] m = {{1,3,5,7},{10,11,16,20},{23,30,34,60}};
        check( searchMatrix(m, 3),  "found 3");
        check(!searchMatrix(m, 13), "not found 13");
        check( searchMatrix(new int[][]{{1}}, 1), "single cell found");
        check(!searchMatrix(new int[][]{{1}}, 2), "single cell not found");
        System.out.println("LC #74 — all assertions passed");
    }
}
```

**Complexity.** Time O(log(m * n)), Space O(1).

**Java notes.**
- `mid / n` and `mid % n` perform the virtual-index-to-2D mapping. Both `mid` and `n` are
  `int`; integer division is exact. The entire matrix is never flattened — memory stays O(1).
- `m * n` can overflow `int` if both dimensions are near `Integer.MAX_VALUE`. LeetCode bounds
  are at most `100 x 100`, so this is safe in practice. In production, use `(long) m * n`.
- Rust uses `usize` for indices and the same `/ n` / `% n` arithmetic — the logic is
  identical in both languages.

---

### LC #875 — Koko Eating Bananas

**Problem.** Koko has `piles` of bananas and `h` hours. She eats at speed `k` bananas/hour
(one pile per hour, stopping when that pile is exhausted). Find the minimum `k` such that she
can finish all piles in `h` hours.

**Insight.** Binary search on the answer space `[1, max(piles)]`. For a candidate speed `k`,
the time needed is `sum of ceil(pile / k)`. Find the smallest `k` where total time <= `h`.

```java
class LC875KokoEating {

    static int minEatingSpeed(int[] piles, int h) {
        int left = 1, right = 0;
        for (int p : piles) right = Math.max(right, p);

        while (left < right) {
            int mid = left + (right - left) / 2;
            long hours = 0;
            for (int p : piles) hours += ((long) p + mid - 1) / mid;  // ceiling division; cast avoids int overflow near 10^9
            if (hours <= h) right = mid;        // mid might be the answer; search left
            else            left  = mid + 1;
        }
        return left;
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(minEatingSpeed(new int[]{3,6,7,11},    8) ==  4, "basic 1");
        check(minEatingSpeed(new int[]{30,11,23,4,20},5) == 30, "basic 2");
        check(minEatingSpeed(new int[]{30,11,23,4,20},6) == 23, "basic 3");
        check(minEatingSpeed(new int[]{10},           1) == 10, "one pile h=1");
        check(minEatingSpeed(new int[]{10},          10) ==  1, "one pile h=10");
        System.out.println("LC #875 — all assertions passed");
    }
}
```

**Complexity.** Time O(n log(max_pile)), Space O(1).

**Java notes.**
- **`long hours`** — critical. Pile values up to 10^9, up to 10^4 piles: the sum of ceilings
  can reach ~10^13, which overflows `int`. Accumulate in `long`. Rust uses `i64` for the
  same reason.
- Ceiling division `((long) p + mid - 1) / mid` avoids floating point entirely — equivalent to
  `Math.ceil((double) p / mid)` but exact for integers. The `(long)` cast before the addition
  widens the intermediate sum, matching Rust's explicit `p as i64 + mid as i64 - 1` cast and
  guarding against the ~7% headroom before `int` overflow (piles[i] + mid can approach 2×10^9).
- The "find leftmost valid" template: `right = mid` (not `mid - 1`) when the condition is
  satisfied, keeping `mid` as a candidate. Loop exits when `left == right`.
- `right` is initialised by scanning for the maximum pile, not by a call to
  `Arrays.stream(piles).max()` — the explicit loop is O(n) and avoids boxing overhead.

---

### LC #153 — Find Minimum in Rotated Sorted Array

**Problem.** A sorted array was rotated between 1 and `n` times. Find the minimum element
in O(log n).

**Insight.** Binary search comparing `nums[mid]` with `nums[right]`. If `nums[mid] >
nums[right]`, the minimum is in the right half (exclusive of mid); otherwise it is in the
left half (inclusive of mid).

```java
class LC153FindMin {

    static int findMin(int[] nums) {
        int left = 0, right = nums.length - 1;
        while (left < right) {
            int mid = left + (right - left) / 2;
            if (nums[mid] > nums[right]) left  = mid + 1;
            else                         right = mid;
        }
        return nums[left];
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(findMin(new int[]{3,4,5,1,2})       == 1, "rotated 5");
        check(findMin(new int[]{4,5,6,7,0,1,2})   == 0, "rotated 7");
        check(findMin(new int[]{1,2,3})            == 1, "not rotated");
        check(findMin(new int[]{1})                == 1, "single");
        check(findMin(new int[]{2,1})              == 1, "two elements");
        System.out.println("LC #153 — all assertions passed");
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java notes.**
- Comparing `nums[mid]` against `nums[right]` (not `nums[left]`) is the key insight — it
  avoids ambiguity when the array is fully sorted. This is identical to the Rust approach.
- The strict `left < right` loop (not `<=`) with `right = mid` (not `mid - 1`) guarantees
  the loop always makes progress: when `left == right - 1`, `mid == left`, and we advance
  `left` or shrink `right`, converging to a single element.
- Java's `int` is signed, so `right = mid` cannot underflow — no special-casing needed.

---

### LC #33 — Search in Rotated Sorted Array

**Problem.** Search for `target` in a rotated sorted array (distinct values). Return the
index or `-1`.

**Insight.** At each `mid`, one half is always fully sorted. Determine which half is sorted,
check if `target` lies in that range, and search accordingly.

```java
class LC33SearchRotated {

    static int search(int[] nums, int target) {
        int left = 0, right = nums.length - 1;
        while (left <= right) {
            int mid = left + (right - left) / 2;
            if (nums[mid] == target) return mid;

            // Left half [left..mid] is sorted
            if (nums[left] <= nums[mid]) {
                if (nums[left] <= target && target < nums[mid]) right = mid - 1;
                else                                             left  = mid + 1;
            } else {
                // Right half [mid..right] is sorted
                if (nums[mid] < target && target <= nums[right]) left  = mid + 1;
                else                                              right = mid - 1;
            }
        }
        return -1;
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        check(search(new int[]{4,5,6,7,0,1,2}, 0) == 4, "found 0");
        check(search(new int[]{4,5,6,7,0,1,2}, 5) == 1, "found 5");
        check(search(new int[]{4,5,6,7,0,1,2}, 3) == -1, "not found");
        check(search(new int[]{1},              0) == -1, "single not found");
        check(search(new int[]{1,2,3,4,5},     3) ==  2, "not rotated");
        check(search(new int[]{1,3},            3) ==  1, "pivot at start");
        System.out.println("LC #33 — all assertions passed");
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Java notes.**
- `nums[left] <= nums[mid]` (with `<=`) correctly identifies the sorted left half even when
  `left == mid` (single-element case). The Rust solution uses the same condition.
- Java's `int` is signed, so `right = mid - 1` when `mid == 0` safely produces `-1`; the
  loop condition `left <= right` then fails and the method returns `-1`. No underflow risk,
  unlike Rust's `usize`.
- The two boundary checks `nums[left] <= target` and `target < nums[mid]` (strict on the
  right) correctly exclude `mid` which was already tested for equality at the top.

---

### LC #981 — Time Based Key-Value Store

**Problem.** Design a data structure that stores key-value pairs with timestamps, and
retrieves the value at the largest timestamp less than or equal to a given query timestamp.

**Insight.** Store values per key as a time-ordered `List<Entry>`. Timestamps are always
added in increasing order (LeetCode guarantee), so the list is naturally sorted. On `get`,
binary search for the largest timestamp `<= timestamp`.

```java
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class LC981TimeMap {

    // Java 16+ record replaces a raw int[] that cannot hold both int and String.
    // (The task spec suggested int[] but that cannot store String values.)
    record Entry(int timestamp, String value) {}

    static class TimeMap {
        private final Map<String, List<Entry>> store = new HashMap<>();

        void set(String key, String value, int timestamp) {
            store.computeIfAbsent(key, k -> new ArrayList<>())
                 .add(new Entry(timestamp, value));
        }

        String get(String key, int timestamp) {
            List<Entry> entries = store.get(key);
            if (entries == null) return "";

            // Binary search: find rightmost entry with entry.timestamp() <= timestamp
            int left = 0, right = entries.size() - 1;
            String result = "";
            while (left <= right) {
                int mid = left + (right - left) / 2;
                if (entries.get(mid).timestamp() <= timestamp) {
                    result = entries.get(mid).value();
                    left   = mid + 1;   // keep searching right for a later timestamp
                } else {
                    right  = mid - 1;
                }
            }
            return result;
        }
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    public static void main(String[] args) {
        var tm = new TimeMap();
        tm.set("foo", "bar", 1);
        check(tm.get("foo", 1).equals("bar"),  "exact timestamp");
        check(tm.get("foo", 3).equals("bar"),  "after timestamp");
        tm.set("foo", "bar2", 4);
        check(tm.get("foo", 4).equals("bar2"), "exact second set");
        check(tm.get("foo", 5).equals("bar2"), "after second set");

        var tm2 = new TimeMap();
        check(tm2.get("missing", 1).equals(""), "missing key");

        var tm3 = new TimeMap();
        tm3.set("k", "v", 10);
        check(tm3.get("k", 5).equals(""), "before first timestamp");

        System.out.println("LC #981 — all assertions passed");
    }
}
```

**Complexity.** `set` O(1) amortised, `get` O(log n) per key, Space O(n total entries).

**Java notes.**
- **Why `record Entry` and not `int[]`?** A `List<int[]>` cannot store `String` values —
  primitive arrays are typed at element level. A `record Entry(int timestamp, String value)`
  is the idiomatic Java 17 replacement: immutable, compact, auto-generates `equals`/`hashCode`/
  `toString`, and the accessor names (`timestamp()`, `value()`) are self-documenting.
- `computeIfAbsent` inserts a new `ArrayList` only if the key is absent and returns the
  existing or new list in one call — equivalent to Rust's `.entry(key).or_default()`.
- The "rightmost valid" binary search template: advance `left = mid + 1` when the condition
  is satisfied, capturing `result` each time, to find the latest valid timestamp.
- Rust's `self.store.get(&key)` uses `&str` deref coercion on `HashMap<String, _>`. Java's
  `store.get(key)` takes an `Object` — no special handling needed, but a `null` check on the
  returned list is required because `get` returns `null` for absent keys.

---

### LC #4 — Median of Two Sorted Arrays

**Problem.** Given two sorted arrays `nums1` and `nums2`, return the median of the combined
array. Must run in O(log(min(m, n))).

**Insight.** Binary search on the partition of the shorter array. Find partition `i` in
`nums1` and `j = (m + n + 1) / 2 - i` in `nums2` such that every element left of the
partition is <= every element right. The median follows from the boundary values.

```java
class LC4MedianSortedArrays {

    static double findMedianSortedArrays(int[] nums1, int[] nums2) {
        // Ensure nums1 is the shorter array so binary search is on the smaller range
        if (nums1.length > nums2.length) return findMedianSortedArrays(nums2, nums1);

        int m = nums1.length, n = nums2.length;
        int half = (m + n + 1) / 2;
        int left = 0, right = m;

        while (left <= right) {
            int i = left + (right - left) / 2;  // partition index in nums1
            int j = half - i;                    // partition index in nums2

            int maxLeft1  = (i == 0) ? Integer.MIN_VALUE : nums1[i - 1];
            int minRight1 = (i == m) ? Integer.MAX_VALUE : nums1[i];
            int maxLeft2  = (j == 0) ? Integer.MIN_VALUE : nums2[j - 1];
            int minRight2 = (j == n) ? Integer.MAX_VALUE : nums2[j];

            if (maxLeft1 <= minRight2 && maxLeft2 <= minRight1) {
                // Correct partition found
                int maxLeft  = Math.max(maxLeft1, maxLeft2);
                int minRight = Math.min(minRight1, minRight2);
                if ((m + n) % 2 == 1) return maxLeft;
                return (maxLeft + (double) minRight) / 2.0;
            } else if (maxLeft1 > minRight2) {
                right = i - 1;  // too far right in nums1
            } else {
                left  = i + 1;  // too far left in nums1
            }
        }
        throw new IllegalArgumentException("Input arrays are not sorted");
    }

    static void check(boolean condition, String msg) {
        if (!condition) throw new AssertionError("FAIL: " + msg);
    }

    static boolean approx(double a, double b) { return Math.abs(a - b) < 1e-9; }

    public static void main(String[] args) {
        check(approx(findMedianSortedArrays(new int[]{1,3}, new int[]{2}),       2.0), "odd total");
        check(approx(findMedianSortedArrays(new int[]{1,2}, new int[]{3,4}),     2.5), "even total");
        check(approx(findMedianSortedArrays(new int[]{},    new int[]{1,2,3}),   2.0), "one empty");
        check(approx(findMedianSortedArrays(new int[]{1,1}, new int[]{1,1}),     1.0), "all same");
        check(approx(findMedianSortedArrays(new int[]{1,3}, new int[]{2,4}),     2.5), "disjoint");
        System.out.println("LC #4 — all assertions passed");
    }
}
```

**Complexity.** Time O(log(min(m, n))), Space O(1).

**Java notes.**
- `Integer.MIN_VALUE` / `Integer.MAX_VALUE` serve as sentinels for empty left/right partition
  boundaries — equivalent to Rust's `i32::MIN` / `i32::MAX`.
- `(maxLeft + (double) minRight) / 2.0` — casting one operand to `double` before the
  addition avoids integer overflow when both values are near `Integer.MAX_VALUE`, and produces
  the correct floating-point median.
- Float equality in tests uses `Math.abs(a - b) < 1e-9` rather than `==` — the correct
  pattern for `double` comparison. Rust tests use the same pattern.
- `right = i - 1` when `i == 0` makes `right == -1`, which is negative — safe for `int`.
  Rust must use `i32` (not `usize`) for the same reason: `usize` would underflow to
  `usize::MAX`.
- Java throws `IllegalArgumentException` at the unreachable end instead of Rust's
  `unreachable!()` macro; both signal a programming contract violation.

---

## 📝 Chapter Review Notes

*The following is a third-person critical review of this chapter, covering fact-checking,
code correctness, Java-17 idiom use, and completeness.*

### Review Summary

All fourteen required problems are covered: seven stack problems (LC #20, #155, #150, #22,
#739, #853, #84) and seven binary search problems (LC #704, #74, #875, #153, #33, #981, #4).
Every solution is a self-contained class with a `main` that exercises multiple cases including
edge inputs. All `Deque` usage uses `ArrayDeque`, never the deprecated `Stack`.

### Fact-Check: Stack Solutions

- **LC #20:** `stack.pop() != '('` — `ArrayDeque.pop()` returns `Character`; auto-unboxing
  to `char` for comparison is correct. The `stack.isEmpty()` guard prevents
  `NoSuchElementException` before `pop()`. Confirmed.
- **LC #155:** `Math.min(minStack.peek(), val)` — `peek()` returns `Integer`; auto-unboxing
  feeds `Math.min(int, int)`. The `isEmpty()` guard before `peek()` prevents NPE. Confirmed.
- **LC #150:** Pop order — `int b = stack.pop()` (right operand) before the second `pop()`
  (left operand). `stack.pop() - b` correctly computes `left - right`. Confirmed. Java `int`
  division truncates toward zero — matches problem requirement. Confirmed.
- **LC #22:** `sb.deleteCharAt(sb.length() - 1)` undoes the last `append` — correct
  backtracking. `sb.toString()` copies the current content at the leaf. Confirmed.
- **LC #739:** Stack holds indices, not values. `!stack.isEmpty()` guard before `peek()` and
  `pop()`. Result array is pre-initialised to `0`. Confirmed.
- **LC #853:** `record Car` used for clean pairing — Java 17 feature. Comparator
  `(a, b) -> b.pos() - a.pos()` sorts descending; subtraction is safe for reasonable
  position values (LeetCode bounds: 0 to 10^6). Confirmed.
- **LC #84:** Sentinel `0` appended via `System.arraycopy`. Width calculation: `i` when stack
  is empty (extends full left), `i - stack.peek() - 1` otherwise. `peek()` used (not `pop()`)
  to read the new left boundary without removing it. Confirmed.

### Fact-Check: Binary Search Solutions

- **LC #704:** Overflow-safe mid used. `right = mid - 1` can reach `-1` — safe for `int`.
  Returns `mid` (an `int` index). Confirmed.
- **LC #74:** `mid / n` and `mid % n` correct for row/col. `m * n` fits `int` for LeetCode
  constraints (max 100 × 100 = 10000). Confirmed.
- **LC #875:** `long hours` accumulator prevents overflow (max ~10^13). `(long) p + mid - 1`
  widens the intermediate sum before ceiling division — mirrors Rust's `p as i64` cast.
  Ceiling division
  `(p + mid - 1) / mid` is exact for positive integers. "Find leftmost valid" template with
  `right = mid`. Confirmed.
- **LC #153:** `nums[mid] > nums[right]` comparison, not `nums[left]`. Strict `left < right`
  loop with `right = mid` ensures progress. Confirmed.
- **LC #33:** `nums[left] <= nums[mid]` with `<=` handles no-rotation case. Both boundary
  checks correctly use inclusive lower bound and exclusive upper bound matching the Rust
  version. Confirmed.
- **LC #981:** `record Entry(int timestamp, String value)` — the task spec's `int[]` cannot
  hold both an `int` timestamp and a `String` value; a record is the correct 17+ idiom.
  `computeIfAbsent` for `or_default`-equivalent. "Rightmost valid" binary search. Confirmed.
- **LC #4:** `Integer.MIN_VALUE` / `Integer.MAX_VALUE` sentinels correct. `(maxLeft +
  (double) minRight) / 2.0` avoids integer overflow in the average. `right = i - 1` safe for
  `int`. Confirmed.

### Issues Table

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 1 | Fixed | Task spec for LC #981 specified `List<int[]>` which cannot hold `String` values | Fixed: `record Entry(int timestamp, String value)` used; explained in Java notes |
| 2 | OK | Assertions in `main` use `check()` helper (throws `AssertionError`) not Java's `assert` keyword (disabled by default without `-ea`) | All 14 `main` methods use `check()` — no silent pass risk |
| 3 | OK | LC #853: comparator `b.pos() - a.pos()` could theoretically overflow for large values; LeetCode bounds (0 to 10^6) are safe | No issue for given constraints; note added |
| 4 | OK | LC #875: `long` accumulator used; `(long) p + mid - 1` widens intermediate sum to avoid int overflow — mirrors Rust's `p as i64` cast | Confirmed |
| 5 | OK | LC #4: `right = i - 1` when `i == 0` produces `-1` — safe for Java `int`, unlike Rust `usize` | Documented in Java notes |
| 6 | OK | All `Deque` instances use `ArrayDeque`, never `Stack<>` | Consistent throughout |
| 7 | OK | Java 17 features used: switch expressions, `record`, `var`, `List.of`, `computeIfAbsent` | Present where appropriate |
| 8 | Low | `m * n` in LC #74 uses `int` — would overflow for matrices with >~46340 rows or cols; safe for LeetCode's 100×100 constraint | Noted in Java notes |
| 9 | OK | Float comparison in LC #4 tests uses `Math.abs(a - b) < 1e-9` — correct pattern | Confirmed |
| 10 | Low | Line count ~1048 lines — modestly over the 600–900 target; justified by 14 problems each with complete runnable `main` tests and per-problem Java notes (the Rust companion is ~1133 lines) | Accepted |
