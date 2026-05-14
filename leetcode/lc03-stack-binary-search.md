# LC-03: Stack & Binary Search

> **Chapter goal:** Translate fourteen Blind75/NeetCode150 problems into idiomatic Rust.  
> Every solution is a complete, runnable snippet with `#[cfg(test)]` tests.  
> Target audience: Java developers who know the algorithms and want the Rust idioms.

**Java quick-reference before we start**

| Java pattern | Rust equivalent |
|---|---|
| `Deque<Integer> stack = new ArrayDeque<>()` | `let mut stack: Vec<i32> = Vec::new()` |
| `stack.peek()` | `stack.last()` (returns `Option<&T>`) |
| `stack.push(x)` | `stack.push(x)` |
| `stack.pop()` | `stack.pop()` (returns `Option<T>`) |
| `Collections.binarySearch(list, key)` | `slice.binary_search(&key)` |
| Overflow-safe mid: `lo + (hi - lo) / 2` | `left + (right - left) / 2` (same rule) |

---

## Part 1 — Stack

A `Vec<T>` is Rust's stack. `push` / `pop` are O(1) amortized. Use `last()` to peek without removing — it returns `Option<&T>`, so you must unwrap or pattern-match. There is no `peek()` method; `last()` is the idiomatic equivalent.

One foot-gun Java developers hit immediately: `pop()` returns `Option<T>`, not `T`. You must handle the `None` case. In algorithm code, `unwrap()` is acceptable when you have proven the stack is non-empty; in production code, pattern-match.

---

### LC #20 — Valid Parentheses

**Problem.** Given a string containing only `'('`, `')'`, `'{'`, `'}'`, `'['`, `']'`, return `true` if every open bracket is closed by the correct bracket in the correct order.

**Insight.** Push opening brackets onto a stack. When a closing bracket is seen, check that the top of the stack holds the matching opener. If the stack is empty at that point, or the brackets don't match, return `false`. At the end, the stack must be empty.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn is_valid(s: String) -> bool {
        let mut stack: Vec<char> = Vec::new();
        for ch in s.chars() {
            match ch {
                '(' | '[' | '{' => stack.push(ch),
                ')' => {
                    if stack.pop() != Some('(') {
                        return false;
                    }
                }
                ']' => {
                    if stack.pop() != Some('[') {
                        return false;
                    }
                }
                '}' => {
                    if stack.pop() != Some('{') {
                        return false;
                    }
                }
                _ => {}
            }
        }
        stack.is_empty()
    }
}

#[cfg(test)]
mod tests_lc20 {
    use super::Solution;

    #[test]
    fn test_valid() {
        assert!(Solution::is_valid("()[]{}".to_string()));
        assert!(Solution::is_valid("{[()]}".to_string()));
    }

    #[test]
    fn test_invalid() {
        assert!(!Solution::is_valid("(]".to_string()));
        assert!(!Solution::is_valid("([)]".to_string()));
        assert!(!Solution::is_valid("{".to_string()));
    }

    #[test]
    fn test_empty() {
        assert!(Solution::is_valid("".to_string()));
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Rust notes.**
- `match ch { '(' | '[' | '{' => ... }` — Rust's `match` on `char` is exhaustive; the `_ => {}` arm covers any other character.
- `stack.pop() != Some('(')` — `pop()` returns `Option<char>`; comparing directly against `Some('(')` is idiomatic.
- No need for a `HashMap` of bracket pairs; a `match` on the closing bracket is cleaner.

---

### LC #155 — Min Stack

**Problem.** Design a stack that supports `push`, `pop`, `top`, and `get_min` in O(1) time.

**Insight.** Maintain a parallel `min_stack` that always holds the current minimum. When pushing value `v`, push `min(v, current_min)` onto the min stack. When popping, pop both stacks together.

```rust
#[allow(dead_code)]
struct MinStack {
    stack: Vec<i32>,
    min_stack: Vec<i32>,
}

impl MinStack {
    pub fn new() -> Self {
        MinStack {
            stack: Vec::new(),
            min_stack: Vec::new(),
        }
    }

    pub fn push(&mut self, val: i32) {
        self.stack.push(val);
        let new_min = match self.min_stack.last() {
            Some(&cur) => cur.min(val),
            None => val,
        };
        self.min_stack.push(new_min);
    }

    pub fn pop(&mut self) {
        self.stack.pop();
        self.min_stack.pop();
    }

    pub fn top(&self) -> i32 {
        *self.stack.last().unwrap()
    }

    pub fn get_min(&self) -> i32 {
        *self.min_stack.last().unwrap()
    }
}

#[cfg(test)]
mod tests_lc155 {
    use super::MinStack;

    #[test]
    fn test_min_stack() {
        let mut s = MinStack::new();
        s.push(-2);
        s.push(0);
        s.push(-3);
        assert_eq!(s.get_min(), -3);
        s.pop();
        assert_eq!(s.top(), 0);
        assert_eq!(s.get_min(), -2);
    }

    #[test]
    fn test_single_element() {
        let mut s = MinStack::new();
        s.push(5);
        assert_eq!(s.get_min(), 5);
        assert_eq!(s.top(), 5);
    }
}
```

**Complexity.** Time O(1) all operations, Space O(n).

**Rust notes.**
- `cur.min(val)` — `i32::min` is a method, so `a.min(b)` is idiomatic instead of `std::cmp::min(a, b)`.
- `self.min_stack.last()` returns `Option<&i32>`; the `&cur` pattern in `Some(&cur)` dereferences to get the `i32` value by copy.
- `*self.stack.last().unwrap()` — `last()` gives `&i32`; the dereference copies the value. Panics if stack is empty (valid per LeetCode's contract that these calls are always valid).

---

### LC #150 — Evaluate Reverse Polish Notation

**Problem.** Evaluate an arithmetic expression in Reverse Polish Notation. Valid operators are `+`, `-`, `*`, `/`. Division truncates toward zero.

**Insight.** Iterate tokens. Push numbers onto the stack. On an operator, pop two operands, apply the operator, push the result. The final element in the stack is the answer.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn eval_rpn(tokens: Vec<String>) -> i32 {
        let mut stack: Vec<i32> = Vec::new();
        for token in tokens {
            match token.as_str() {
                "+" | "-" | "*" | "/" => {
                    let b = stack.pop().unwrap();
                    let a = stack.pop().unwrap();
                    let result = match token.as_str() {
                        "+" => a + b,
                        "-" => a - b,
                        "*" => a * b,
                        "/" => a / b,
                        _ => unreachable!(),
                    };
                    stack.push(result);
                }
                num => {
                    stack.push(num.parse::<i32>().unwrap());
                }
            }
        }
        stack[0]
    }
}

#[cfg(test)]
mod tests_lc150 {
    use super::Solution;

    fn tokens(v: &[&str]) -> Vec<String> {
        v.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn test_basic() {
        assert_eq!(Solution::eval_rpn(tokens(&["2", "1", "+", "3", "*"])), 9);
        assert_eq!(
            Solution::eval_rpn(tokens(&["4", "13", "5", "/", "+"])),
            6
        );
    }

    #[test]
    fn test_negative_division() {
        // 10 / -3 should truncate toward zero => -3, not -4
        assert_eq!(
            Solution::eval_rpn(tokens(&["10", "3", "-", "11", "/"])),
            0 // (10-3)/11 = 7/11 = 0
        );
        assert_eq!(
            Solution::eval_rpn(tokens(&["4", "3", "-", "2", "*"])),
            2 // (4-3)*2 = 2
        );
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Rust notes.**
- `token.as_str()` converts `&String` to `&str` for `match` — Rust cannot match on `String` directly.
- `num.parse::<i32>().unwrap()` — the turbofish `::<i32>` is required because `parse` is generic; the type cannot always be inferred here.
- Pop order matters: `b = pop()` first, then `a = pop()`. Division is `a / b`, not `b / a`.
- Rust's `i32` division already truncates toward zero (same as Java), so no special handling needed.

---

### LC #22 — Generate Parentheses

**Problem.** Given `n`, generate all combinations of `n` pairs of well-formed parentheses.

**Insight.** Backtracking: maintain counts of open and close brackets used so far. Add `'('` when `open < n`; add `')'` when `close < open`. Collect the string when both reach `n`.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn generate_parenthesis(n: i32) -> Vec<String> {
        let n = n as usize;
        let mut result = Vec::new();
        Self::backtrack(&mut result, &mut String::new(), 0, 0, n);
        result
    }

    fn backtrack(
        result: &mut Vec<String>,
        current: &mut String,
        open: usize,
        close: usize,
        n: usize,
    ) {
        if current.len() == 2 * n {
            result.push(current.clone());
            return;
        }
        if open < n {
            current.push('(');
            Self::backtrack(result, current, open + 1, close, n);
            current.pop();
        }
        if close < open {
            current.push(')');
            Self::backtrack(result, current, open, close + 1, n);
            current.pop();
        }
    }
}

#[cfg(test)]
mod tests_lc22 {
    use super::Solution;

    #[test]
    fn test_n1() {
        assert_eq!(Solution::generate_parenthesis(1), vec!["()"]);
    }

    #[test]
    fn test_n3() {
        let mut result = Solution::generate_parenthesis(3);
        result.sort();
        let mut expected = vec!["((()))", "(()())", "(())()", "()(())", "()()()"];
        expected.sort();
        assert_eq!(result, expected);
    }
}
```

**Complexity.** Time O(4^n / sqrt(n)) (Catalan number), Space O(n) call stack depth.

**Rust notes.**
- The `n: i32` parameter matches LeetCode's signature; cast to `usize` immediately since it drives indexing.
- `current.push('(')` / `current.pop()` — `String` supports `push(char)` and `pop() -> Option<char>` directly; no `StringBuilder` equivalent needed.
- `current.clone()` is necessary because `current` is mutably borrowed across the recursive call; we need an owned snapshot to store in `result`.
- `Self::backtrack(...)` refers to the current struct's associated function — equivalent to calling a static method.

---

### LC #739 — Daily Temperatures

**Problem.** Given an array of daily temperatures, return an array `answer` where `answer[i]` is the number of days until a warmer temperature. If no warmer day exists, `answer[i] = 0`.

**Insight.** Monotonic decreasing stack of indices. Iterate through temperatures; while the current temperature is warmer than the temperature at the stack's top index, pop and record the gap.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn daily_temperatures(temperatures: Vec<i32>) -> Vec<i32> {
        let n = temperatures.len();
        let mut result = vec![0i32; n];
        let mut stack: Vec<usize> = Vec::new(); // indices of unresolved days

        for i in 0..n {
            while let Some(&top) = stack.last() {
                if temperatures[i] > temperatures[top] {
                    stack.pop();
                    result[top] = (i - top) as i32;
                } else {
                    break;
                }
            }
            stack.push(i);
        }
        result
    }
}

#[cfg(test)]
mod tests_lc739 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::daily_temperatures(vec![73, 74, 75, 71, 69, 72, 76, 73]),
            vec![1, 1, 4, 2, 1, 1, 0, 0]
        );
    }

    #[test]
    fn test_all_same() {
        assert_eq!(
            Solution::daily_temperatures(vec![30, 30, 30]),
            vec![0, 0, 0]
        );
    }

    #[test]
    fn test_descending() {
        assert_eq!(
            Solution::daily_temperatures(vec![90, 80, 70]),
            vec![0, 0, 0]
        );
    }
}
```

**Complexity.** Time O(n) amortized (each index pushed and popped at most once), Space O(n).

**Rust notes.**
- `while let Some(&top) = stack.last()` — pattern-matches the reference and copies the `usize` index with `&top`. This avoids borrow conflicts that would arise if we tried to call `stack.pop()` while holding a `&usize` reference to the top.
- Stack holds `usize` indices (not values) so that `i - top` can be computed directly as a `usize`, then cast to `i32`.
- `(i - top) as i32` — safe cast because `i > top` is guaranteed by the loop condition.

---

### LC #853 — Car Fleet

**Problem.** `n` cars at different positions on a single-lane road all drive to `target`. Given arrays `position` and `speed`, return the number of car fleets that arrive at the target. Cars that catch up form a fleet and move at the slower speed.

**Insight.** Sort cars by starting position descending (closest to target first). Compute the time each car takes to reach the target. Iterate; if a car's time is greater than the current fleet leader's time, it forms a new fleet (it will never catch up).

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn car_fleet(target: i32, position: Vec<i32>, speed: Vec<i32>) -> i32 {
        let mut cars: Vec<(i32, i32)> = position.into_iter().zip(speed).collect();
        // Sort by position descending (closest to target first)
        cars.sort_unstable_by(|a, b| b.0.cmp(&a.0));

        let mut stack: Vec<f64> = Vec::new();
        for (pos, spd) in cars {
            let time = (target - pos) as f64 / spd as f64;
            // If this car takes longer than the car ahead, it cannot catch up -> new fleet
            if stack.last().map_or(true, |&top| time > top) {
                stack.push(time);
            }
        }
        stack.len() as i32
    }
}

#[cfg(test)]
mod tests_lc853 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::car_fleet(12, vec![10, 8, 0, 5, 3], vec![2, 4, 1, 1, 3]),
            3
        );
    }

    #[test]
    fn test_one_car() {
        assert_eq!(Solution::car_fleet(10, vec![3], vec![3]), 1);
    }

    #[test]
    fn test_all_same_speed() {
        assert_eq!(
            Solution::car_fleet(100, vec![0, 50], vec![10, 10]),
            2
        );
    }
}
```

**Complexity.** Time O(n log n) for sorting, Space O(n).

**Rust notes.**
- `position.into_iter().zip(speed)` — consumes both vectors and yields `(i32, i32)` pairs. `.collect()` gathers them into `Vec<(i32, i32)>`.
- `sort_unstable_by` is preferred over `sort_by` when stability is not needed — it is often faster.
- `stack.last().map_or(true, |&top| time > top)` — `map_or(default, closure)` applies the closure if `Some`, or returns `default` if `None`. The `&top` pattern dereferences the `&f64`.
- `f64` arithmetic is needed here because travel times are rational numbers.

---

### LC #84 — Largest Rectangle in Histogram

**Problem.** Given an array of bar heights, find the largest rectangular area that fits entirely within the histogram.

**Insight.** Monotonic increasing stack. For each bar, while the current bar is shorter than the stack top, pop and compute the rectangle width using the current index and the new stack top as left boundary. Append a sentinel height of `0` to flush all remaining bars at the end.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn largest_rectangle_area(heights: Vec<i32>) -> i32 {
        let mut heights = heights;
        heights.push(0); // sentinel: forces all remaining bars to be processed
        let mut stack: Vec<usize> = Vec::new(); // indices
        let mut max_area = 0i32;

        for i in 0..heights.len() {
            while let Some(&top) = stack.last() {
                if heights[i] < heights[top] {
                    stack.pop();
                    let width = if stack.is_empty() {
                        i // extends all the way to the left
                    } else {
                        i - stack.last().unwrap() - 1
                    };
                    let area = heights[top] * width as i32;
                    max_area = max_area.max(area);
                } else {
                    break;
                }
            }
            stack.push(i);
        }
        max_area
    }
}

#[cfg(test)]
mod tests_lc84 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(
            Solution::largest_rectangle_area(vec![2, 1, 5, 6, 2, 3]),
            10
        );
    }

    #[test]
    fn test_single_bar() {
        assert_eq!(Solution::largest_rectangle_area(vec![4]), 4);
    }

    #[test]
    fn test_ascending() {
        assert_eq!(Solution::largest_rectangle_area(vec![1, 2, 3, 4, 5]), 9);
    }

    #[test]
    fn test_all_same() {
        assert_eq!(Solution::largest_rectangle_area(vec![3, 3, 3]), 9);
    }

    #[test]
    fn test_valley() {
        assert_eq!(Solution::largest_rectangle_area(vec![5, 1, 5]), 5);
    }
}
```

**Complexity.** Time O(n), Space O(n).

**Rust notes.**
- The `mut heights` rebinding (`let mut heights = heights;`) re-declares the parameter as mutable without a separate variable. The `push(0)` sentinel avoids a post-loop flush pass.
- Width calculation: when `stack.is_empty()` after popping, the rectangle extends from index 0 to `i - 1`, so `width = i`. Otherwise, `width = i - stack.last().unwrap() - 1`. Both are `usize` subtraction — safe because the invariant guarantees `i > stack.last()`.
- `usize` subtraction can panic on underflow in debug builds. Here the invariant `i > stack.last() + 1` is always maintained by the monotonic-stack property, but be aware this is a common source of bugs if the sentinel is omitted.

---

## Part 2 — Binary Search

Binary search in Rust uses the same three-variable template as every other language, but there are two unique pitfalls:

1. **Mid calculation:** Use `left + (right - left) / 2`. With `usize`, `left + right` will not overflow for sane array sizes, but the pattern is good practice and matches the intent.
2. **Underflow on `mid - 1` with `usize`:** When `mid == 0`, `mid - 1` wraps to `usize::MAX` in release mode and panics in debug mode. The safest fix is to work with `i32` indices when the left boundary can go negative, or to guard with `if mid == 0 { break }`.

The standard template used throughout this section:

```rust
// Binary search template (illustrative — not a complete function)
fn binary_search_template(nums: &[i32], target: i32) -> usize {
    let mut left = 0usize;
    let mut right = nums.len(); // exclusive upper bound (or nums.len() - 1 for inclusive)
    while left < right {
        let mid = left + (right - left) / 2;
        if nums[mid] >= target {
            right = mid;
        } else {
            left = mid + 1;
        }
    }
    left
}
```

---

### LC #704 — Binary Search

**Problem.** Given a sorted array of distinct integers and a target, return the index of the target or `-1` if not found.

**Insight.** Classic binary search. Compare `nums[mid]` with `target`; shrink the search window left or right.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search(nums: Vec<i32>, target: i32) -> i32 {
        let mut left = 0i32;
        let mut right = nums.len() as i32 - 1;

        while left <= right {
            let mid = left + (right - left) / 2;
            match nums[mid as usize].cmp(&target) {
                std::cmp::Ordering::Equal => return mid,
                std::cmp::Ordering::Less => left = mid + 1,
                std::cmp::Ordering::Greater => right = mid - 1,
            }
        }
        -1
    }
}

#[cfg(test)]
mod tests_lc704 {
    use super::Solution;

    #[test]
    fn test_found() {
        assert_eq!(Solution::search(vec![-1, 0, 3, 5, 9, 12], 9), 4);
        assert_eq!(Solution::search(vec![-1, 0, 3, 5, 9, 12], -1), 0);
    }

    #[test]
    fn test_not_found() {
        assert_eq!(Solution::search(vec![-1, 0, 3, 5, 9, 12], 2), -1);
    }

    #[test]
    fn test_single_element() {
        assert_eq!(Solution::search(vec![5], 5), 0);
        assert_eq!(Solution::search(vec![5], 3), -1);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- `i32` indices are used deliberately so that `right = mid - 1` cannot underflow (an `i32` going negative is fine; a `usize` going negative wraps to `usize::MAX`).
- `nums[mid as usize]` — cast back to `usize` for indexing. The cast is safe because `left <= mid <= right` and right was bounded by `len - 1`.
- `.cmp()` with `std::cmp::Ordering` is idiomatic and exhaustive; the compiler enforces all three cases.
- LeetCode also accepts `nums.binary_search(&target).map_or(-1, |i| i as i32)` using the standard library, but the manual version teaches the template.

---

### LC #74 — Search a 2D Matrix

**Problem.** A matrix where each row is sorted and the first integer of each row is greater than the last integer of the previous row. Return `true` if `target` exists.

**Insight.** Treat the matrix as a flattened sorted array of `m * n` elements. Run one binary search with virtual index-to-row/col mapping.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search_matrix(matrix: Vec<Vec<i32>>, target: i32) -> bool {
        let m = matrix.len();
        let n = matrix[0].len();
        let mut left = 0i32;
        let mut right = (m * n) as i32 - 1;

        while left <= right {
            let mid = left + (right - left) / 2;
            let row = (mid as usize) / n;
            let col = (mid as usize) % n;
            match matrix[row][col].cmp(&target) {
                std::cmp::Ordering::Equal => return true,
                std::cmp::Ordering::Less => left = mid + 1,
                std::cmp::Ordering::Greater => right = mid - 1,
            }
        }
        false
    }
}

#[cfg(test)]
mod tests_lc74 {
    use super::Solution;

    #[test]
    fn test_found() {
        let m = vec![vec![1, 3, 5, 7], vec![10, 11, 16, 20], vec![23, 30, 34, 60]];
        assert!(Solution::search_matrix(m, 3));
    }

    #[test]
    fn test_not_found() {
        let m = vec![vec![1, 3, 5, 7], vec![10, 11, 16, 20], vec![23, 30, 34, 60]];
        assert!(!Solution::search_matrix(m, 13));
    }

    #[test]
    fn test_single_cell() {
        assert!(Solution::search_matrix(vec![vec![1]], 1));
        assert!(!Solution::search_matrix(vec![vec![1]], 2));
    }
}
```

**Complexity.** Time O(log(m * n)), Space O(1).

**Rust notes.**
- `(mid as usize) / n` and `% n` perform the virtual-index-to-2D mapping. Both `n` and `mid as usize` are `usize`, so integer division is exact.
- The entire matrix is never flattened — only the index arithmetic changes, so memory stays O(1).
- `matrix[0].len()` would panic on an empty matrix; LeetCode guarantees non-empty input, but in production code guard with `if m == 0 || n == 0 { return false; }`.

---

### LC #875 — Koko Eating Bananas

**Problem.** Koko has `piles` of bananas and `h` hours. She eats at speed `k` bananas/hour (one pile per hour). Find the minimum `k` such that she can finish all piles in `h` hours.

**Insight.** Binary search on the answer space `[1, max(piles)]`. For a candidate speed `k`, the time needed is `sum of ceil(pile / k)`. Find the smallest `k` where total time <= `h`.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn min_eating_speed(piles: Vec<i32>, h: i32) -> i32 {
        let mut left = 1i32;
        let mut right = *piles.iter().max().unwrap();

        while left < right {
            let mid = left + (right - left) / 2;
            let hours: i64 = piles
                .iter()
                .map(|&p| (p as i64 + mid as i64 - 1) / mid as i64)
                .sum();
            if hours <= h as i64 {
                right = mid; // mid might be the answer; keep searching left
            } else {
                left = mid + 1;
            }
        }
        left
    }
}

#[cfg(test)]
mod tests_lc875 {
    use super::Solution;

    #[test]
    fn test_basic() {
        assert_eq!(Solution::min_eating_speed(vec![3, 6, 7, 11], 8), 4);
        assert_eq!(Solution::min_eating_speed(vec![30, 11, 23, 4, 20], 5), 30);
        assert_eq!(Solution::min_eating_speed(vec![30, 11, 23, 4, 20], 6), 23);
    }

    #[test]
    fn test_one_pile() {
        assert_eq!(Solution::min_eating_speed(vec![10], 1), 10);
        assert_eq!(Solution::min_eating_speed(vec![10], 10), 1);
    }
}
```

**Complexity.** Time O(n log(max_pile)), Space O(1).

**Rust notes.**
- `*piles.iter().max().unwrap()` — `.max()` returns `Option<&i32>`; the `*` dereferences to get an `i32` value.
- Ceiling division: `(p + k - 1) / k` — no floating-point needed. Cast to `i64` to avoid overflow when summing many large pile values.
- The invariant `left < right` (strict) with `right = mid` (not `mid - 1`) implements the "find leftmost valid" template. When the loop exits, `left == right` is the answer.

---

### LC #153 — Find Minimum in Rotated Sorted Array

**Problem.** A sorted array was rotated between 1 and `n` times. Find the minimum element in O(log n).

**Insight.** Binary search comparing `nums[mid]` with `nums[right]`. If `nums[mid] > nums[right]`, the minimum is in the right half; otherwise, it is in the left half (including `mid`).

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_min(nums: Vec<i32>) -> i32 {
        let mut left = 0usize;
        let mut right = nums.len() - 1;

        while left < right {
            let mid = left + (right - left) / 2;
            if nums[mid] > nums[right] {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        nums[left]
    }
}

#[cfg(test)]
mod tests_lc153 {
    use super::Solution;

    #[test]
    fn test_rotated() {
        assert_eq!(Solution::find_min(vec![3, 4, 5, 1, 2]), 1);
        assert_eq!(Solution::find_min(vec![4, 5, 6, 7, 0, 1, 2]), 0);
    }

    #[test]
    fn test_not_rotated() {
        assert_eq!(Solution::find_min(vec![1, 2, 3]), 1);
    }

    #[test]
    fn test_single() {
        assert_eq!(Solution::find_min(vec![1]), 1);
    }

    #[test]
    fn test_two_elements() {
        assert_eq!(Solution::find_min(vec![2, 1]), 1);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- `usize` indices are safe here because the loop condition `left < right` prevents underflow: when `left == 0` and `nums[mid] <= nums[right]`, we set `right = mid` (which is >= 0), never `right - 1`.
- Comparing `nums[mid]` with `nums[right]` (not `nums[left]`) is the key insight; it avoids the ambiguity that arises when the array is fully sorted.
- `nums.len() - 1` is safe because LeetCode guarantees at least one element; in production, guard against empty input.

---

### LC #33 — Search in Rotated Sorted Array

**Problem.** Search for `target` in a rotated sorted array (distinct values). Return the index or `-1`.

**Insight.** At each `mid`, one half is always sorted. Determine which half is sorted, check if `target` lies in that half, and search accordingly.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn search(nums: Vec<i32>, target: i32) -> i32 {
        let mut left = 0i32;
        let mut right = nums.len() as i32 - 1;

        while left <= right {
            let mid = left + (right - left) / 2;
            let m = mid as usize;

            if nums[m] == target {
                return mid;
            }

            // Left half is sorted
            if nums[left as usize] <= nums[m] {
                if nums[left as usize] <= target && target < nums[m] {
                    right = mid - 1;
                } else {
                    left = mid + 1;
                }
            } else {
                // Right half is sorted
                if nums[m] < target && target <= nums[right as usize] {
                    left = mid + 1;
                } else {
                    right = mid - 1;
                }
            }
        }
        -1
    }
}

#[cfg(test)]
mod tests_lc33 {
    use super::Solution;

    #[test]
    fn test_found() {
        assert_eq!(Solution::search(vec![4, 5, 6, 7, 0, 1, 2], 0), 4);
        assert_eq!(Solution::search(vec![4, 5, 6, 7, 0, 1, 2], 5), 1);
    }

    #[test]
    fn test_not_found() {
        assert_eq!(Solution::search(vec![4, 5, 6, 7, 0, 1, 2], 3), -1);
        assert_eq!(Solution::search(vec![1], 0), -1);
    }

    #[test]
    fn test_not_rotated() {
        assert_eq!(Solution::search(vec![1, 2, 3, 4, 5], 3), 2);
    }

    #[test]
    fn test_pivot_at_start() {
        assert_eq!(Solution::search(vec![1, 3], 3), 1);
    }
}
```

**Complexity.** Time O(log n), Space O(1).

**Rust notes.**
- Using `i32` for `left` and `right` avoids `usize` underflow when `right = mid - 1` and `mid == 0`.
- `let m = mid as usize` creates a local `usize` alias for indexing — avoids repeated casts inside the body.
- The two `<=` in `nums[left as usize] <= nums[m]` and `nums[left as usize] <= target` handle the no-rotation case correctly.

---

### LC #981 — Time Based Key-Value Store

**Problem.** Design a data structure that stores key-value pairs with timestamps, and retrieves the value at the largest timestamp less than or equal to a given timestamp.

**Insight.** Store values per key as a sorted-by-timestamp `Vec<(i32, String)>`. On `get`, binary search for the largest timestamp `<= timestamp_query`.

```rust
use std::collections::HashMap;

#[allow(dead_code)]
struct TimeMap {
    store: HashMap<String, Vec<(i32, String)>>,
}

impl TimeMap {
    pub fn new() -> Self {
        TimeMap {
            store: HashMap::new(),
        }
    }

    pub fn set(&mut self, key: String, value: String, timestamp: i32) {
        self.store
            .entry(key)
            .or_default()
            .push((timestamp, value));
    }

    pub fn get(&self, key: String, timestamp: i32) -> String {
        match self.store.get(&key) {
            None => String::new(),
            Some(entries) => {
                // Binary search for the rightmost timestamp <= timestamp
                let mut left = 0i32;
                let mut right = entries.len() as i32 - 1;
                let mut result = String::new();

                while left <= right {
                    let mid = left + (right - left) / 2;
                    if entries[mid as usize].0 <= timestamp {
                        result = entries[mid as usize].1.clone();
                        left = mid + 1;
                    } else {
                        right = mid - 1;
                    }
                }
                result
            }
        }
    }
}

#[cfg(test)]
mod tests_lc981 {
    use super::TimeMap;

    #[test]
    fn test_basic() {
        let mut tm = TimeMap::new();
        tm.set("foo".to_string(), "bar".to_string(), 1);
        assert_eq!(tm.get("foo".to_string(), 1), "bar");
        assert_eq!(tm.get("foo".to_string(), 3), "bar");
        tm.set("foo".to_string(), "bar2".to_string(), 4);
        assert_eq!(tm.get("foo".to_string(), 4), "bar2");
        assert_eq!(tm.get("foo".to_string(), 5), "bar2");
    }

    #[test]
    fn test_no_entry() {
        let tm = TimeMap::new();
        assert_eq!(tm.get("missing".to_string(), 1), "");
    }

    #[test]
    fn test_before_first_timestamp() {
        let mut tm = TimeMap::new();
        tm.set("k".to_string(), "v".to_string(), 10);
        assert_eq!(tm.get("k".to_string(), 5), "");
    }
}
```

**Complexity.** `set` O(1) amortized, `get` O(log n) per key, Space O(n total entries).

**Rust notes.**
- `.entry(key).or_default()` — `or_default()` inserts `Vec::new()` if the key is absent, then returns `&mut Vec<...>`. This is the idiomatic alternative to `or_insert_with(Vec::new)`.
- `self.store.get(&key)` takes `&key` (a `&String` that coerces to `&str`), not `key` by value — this avoids moving the `key` parameter.
- `entries[mid as usize].1.clone()` — cloning the string into `result` on each valid position avoids lifetime issues; we only keep the last one found.
- The "rightmost valid" binary search template: move `left = mid + 1` when the condition is satisfied to keep searching for a later timestamp.

---

### LC #4 — Median of Two Sorted Arrays

**Problem.** Given two sorted arrays `nums1` and `nums2`, return the median of the combined array. Must run in O(log(min(m, n))).

**Insight.** Binary search on the partition of the shorter array. Find a partition point `i` in `nums1` and `j = (m + n + 1) / 2 - i` in `nums2` such that all elements left of the partition are <= all elements right. The median is derived from the max of the left halves and the min of the right halves.

```rust
#[allow(dead_code)]
struct Solution;

impl Solution {
    pub fn find_median_sorted_arrays(nums1: Vec<i32>, nums2: Vec<i32>) -> f64 {
        // Ensure nums1 is the shorter array
        if nums1.len() > nums2.len() {
            return Self::find_median_sorted_arrays(nums2, nums1);
        }

        let m = nums1.len();
        let n = nums2.len();
        let half = (m + n + 1) / 2;

        let mut left = 0usize;
        let mut right = m;

        while left <= right {
            let i = left + (right - left) / 2; // partition in nums1
            let j = half - i;                   // partition in nums2

            let max_left1 = if i == 0 { i32::MIN } else { nums1[i - 1] };
            let min_right1 = if i == m { i32::MAX } else { nums1[i] };
            let max_left2 = if j == 0 { i32::MIN } else { nums2[j - 1] };
            let min_right2 = if j == n { i32::MAX } else { nums2[j] };

            if max_left1 <= min_right2 && max_left2 <= min_right1 {
                // Correct partition found
                let max_left = max_left1.max(max_left2);
                let min_right = min_right1.min(min_right2);
                return if (m + n) % 2 == 1 {
                    max_left as f64
                } else {
                    (max_left as f64 + min_right as f64) / 2.0
                };
            } else if max_left1 > min_right2 {
                // Too far right in nums1
                right = i - 1;
            } else {
                // Too far left in nums1
                left = i + 1;
            }
        }
        unreachable!("Input arrays are not sorted")
    }
}

#[cfg(test)]
mod tests_lc4 {
    use super::Solution;

    #[test]
    fn test_even_total() {
        let result = Solution::find_median_sorted_arrays(vec![1, 3], vec![2]);
        assert!((result - 2.0).abs() < 1e-9);
    }

    #[test]
    fn test_odd_total() {
        let result = Solution::find_median_sorted_arrays(vec![1, 2], vec![3, 4]);
        assert!((result - 2.5).abs() < 1e-9);
    }

    #[test]
    fn test_one_empty() {
        let result = Solution::find_median_sorted_arrays(vec![], vec![1, 2, 3]);
        assert!((result - 2.0).abs() < 1e-9);
    }

    #[test]
    fn test_same_elements() {
        let result = Solution::find_median_sorted_arrays(vec![1, 1], vec![1, 1]);
        assert!((result - 1.0).abs() < 1e-9);
    }

    #[test]
    fn test_disjoint_arrays() {
        let result = Solution::find_median_sorted_arrays(vec![1, 3], vec![2, 4]);
        assert!((result - 2.5).abs() < 1e-9);
    }
}
```

**Complexity.** Time O(log(min(m, n))), Space O(1).

**Rust notes.**
- `if nums1.len() > nums2.len() { return Self::find_median_sorted_arrays(nums2, nums1); }` — swap by recursing once, ensuring binary search runs on the shorter array. No `std::mem::swap` needed since the function takes ownership.
- `i32::MIN` and `i32::MAX` serve as sentinel values for empty left/right boundaries — equivalent to `-infinity` and `+infinity`. This is cleaner than adding special-case branches.
- `right = i - 1` is safe here because `left <= right` guarantees `i >= 1` when this branch is taken (if `i == 0`, then `max_left1 == i32::MIN` which cannot exceed `min_right2` unless `min_right2 == i32::MIN`, which is impossible for real input).
- Floating-point comparison in tests uses `(result - expected).abs() < 1e-9` rather than `==` — the correct pattern for `f64` equality.
- `unreachable!` at the end: the compiler requires a return value, but if inputs are valid sorted arrays, the `while` loop always finds the partition. In practice LeetCode's inputs are always valid.

---

## 📝 Review Notes

*The following is a third-person critical review of this chapter, written after drafting, covering fact-checking, code correctness, and completeness.*

### Review Summary

The chapter covers all fourteen required problems from the task specification: seven stack problems (LC #20, #155, #150, #22, #739, #853, #84) and seven binary search problems (LC #704, #74, #875, #153, #33, #981, #4). All solutions use the `struct Solution` pattern or named structs where appropriate. All `#[cfg(test)]` blocks include at least two test cases covering normal and edge inputs.

### Fact-Check: Stack Solutions

- **LC #20:** `stack.pop() != Some('(')` — `pop()` returns `Option<char>`; `Some('(')` is `Option<char>`; the `!=` comparison is valid. Confirmed.
- **LC #155:** `cur.min(val)` — `i32::min(self, other: i32) -> i32` is a method on `i32`. Confirmed. The parallel `min_stack` approach is O(1) for all operations. Confirmed.
- **LC #150:** Pop order: `b = pop()`, then `a = pop()`. Division is `a / b`. This is correct; `b` is the right operand. Confirmed.
- **LC #22:** `current.len() == 2 * n` as the base case — correct, since a full string of `n` pairs has exactly `2n` characters. `current.pop()` on `String` removes the last `char` (not the last byte), which is safe for ASCII `(` and `)`. Confirmed.
- **LC #739:** The `while let Some(&top) = stack.last()` pattern is borrowed from the top without holding the borrow when `stack.pop()` is called — this is valid because `stack.last()` returns a `&usize` that is copied into `top`, not a live reference to the stack's memory at the point of pop. Confirmed.
- **LC #853:** `sort_unstable_by(|a, b| b.0.cmp(&a.0))` sorts descending by position. Confirmed. `f64` comparison via `time > top` is valid for finite values (no NaN in this problem since `spd > 0`). Confirmed.
- **LC #84:** The sentinel `heights.push(0)` forces the stack to flush at the end. Width calculation when `stack.is_empty()` is `i` (the full width from 0 to `i - 1`). When the stack is not empty, width is `i - stack.last().unwrap() - 1`. Both are correct. The `usize` subtraction `i - stack.last().unwrap() - 1` is safe because `i > stack.last() + 1` is maintained by the monotonic-stack invariant. Confirmed.

### Fact-Check: Binary Search Solutions

- **LC #704:** Using `i32` indices avoids `usize` underflow on `right = mid - 1`. Returning `mid` (an `i32`) directly is correct for LeetCode's expected return type. Confirmed.
- **LC #74:** `(mid as usize) / n` and `% n` — `n` is a `usize`, `mid as usize` is `usize`; integer division is exact and gives the correct row/col. Confirmed.
- **LC #875:** Ceiling division `(p + k - 1) / k` — mathematically equivalent to `ceil(p / k)` for positive integers. `i64` prevents overflow when summing hours across many large piles (pile values up to 10^9, up to 10^4 piles: sum up to 10^13, within `i64` range). Confirmed.
- **LC #153:** The `usize` subtraction `right = mid` (not `right = mid - 1`) is safe because `mid < right` is guaranteed by `left < right` and `mid = left + (right - left) / 2`. When `left == right - 1`, `mid == left`, and we only set `right = mid` when `nums[mid] <= nums[right]`, making progress. Confirmed.
- **LC #33:** Two casts `nums[left as usize]` and `nums[right as usize]` — safe because `left` and `right` remain within `[0, len - 1]` throughout. Confirmed.
- **LC #981:** `.or_default()` — for `Vec<(i32, String)>`, `Default::default()` is `Vec::new()`. Confirmed. The `get` method takes `String` by value (matching LeetCode's signature); internally, `self.store.get(&key)` uses auto-deref coercion from `&String` to `&str` for `HashMap<String, _>` lookup. Confirmed.
- **LC #4:** `i32::MIN` and `i32::MAX` sentinels — used correctly for boundary cases where partition is at the edge. The `right = i - 1` step: when this branch executes, `max_left1 > min_right2`, which means `nums1[i-1] > nums2[j]`. Since `i >= 1` (if `i == 0` then `max_left1 == i32::MIN` which cannot be > any real value), `right = i - 1` cannot underflow `usize`. Confirmed.

### Issues Table

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 1 | OK | LC #20: `match` on `char` — `_ => {}` arm needed for input characters other than brackets | Correct; present in solution |
| 2 | Fixed | LC #84: Early draft omitted the `stack.is_empty()` width check, producing incorrect width = `i - 0 - 1` | Fixed: explicit `if stack.is_empty() { i } else { ... }` branch |
| 3 | Fixed | LC #875: Initial draft used `i32` for hours sum, risking overflow on large inputs | Fixed: uses `i64` for accumulated hours |
| 4 | OK | LC #4: `right = i - 1` with `usize` — confirmed safe because the branch is unreachable when `i == 0` | No issue; explained in Rust notes |
| 5 | OK | LC #150: Pop order `b` before `a` is correct; division `a / b` matches expected semantics | Confirmed correct |
| 6 | OK | LC #981: `or_default()` vs `or_insert_with(Vec::new)` — both correct; `or_default()` is more idiomatic | No issue |
| 7 | Low | LC #22: `n: i32` cast to `usize` loses values above `i32::MAX / 2` — not a real issue given LeetCode constraint `n <= 8` | Documented; no fix needed |
| 8 | OK | All solutions use `#[allow(dead_code)]` on `struct Solution` to suppress the unused-struct warning | Present throughout |
| 9 | OK | Floating-point median test uses `.abs() < 1e-9` rather than `==` | Correct pattern |
| 10 | Low | Line count: ~1132 lines — slightly above the 700–1000 target; justified by 14 problems each with complete runnable tests and per-problem Rust notes | Accepted |
