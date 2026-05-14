# Chapter LC-02 (Java): Two Pointers & Sliding Window
> Java solutions companion to [Rust Chapter LC-02](../leetcode/lc02-two-pointers-sliding-window.md).

---

## Patterns at a Glance

| Pattern | Core idea | Key Java tools |
|---|---|---|
| Two Pointers (opposite ends) | `left` and `right` converge toward each other | `int` indices, `while (l < r)` |
| Two Pointers (same direction) | slow/fast, or anchor/runner | standard `for` with two index vars |
| Fixed Sliding Window | window of size `k`; slide one step at a time | `int[26]`, `Arrays.equals()` |
| Variable Sliding Window | expand `right`, shrink `left` when constraint broken | `Map<Character,Integer>`, `int[128]` |

**Java vs Rust — string indexing:** Java strings are UTF-16 arrays, so `s.charAt(i)` is O(1). Rust `String` is UTF-8; `s.as_bytes()[i]` is O(1) for ASCII, but `s.chars().nth(i)` is O(n). For ASCII LeetCode problems both languages are equally fast at character access — but the *type* differs: Java `charAt` returns a `char` (UTF-16 code unit), Rust `.as_bytes()[i]` returns a `u8`. In Java use `Character.isLetterOrDigit(c)` and `Character.toLowerCase(c)` where Rust uses `.is_ascii_alphanumeric()` and `.to_ascii_lowercase()` directly on the byte.

**Assertion note:** All `main` methods use `if (!cond) throw new AssertionError("msg")` rather than `assert cond`. Java `assert` is disabled by default (requires `java -ea`) and would silently pass everything. The `throw` form always runs and is safe to paste directly into any Java 17 environment.

---

## Part 1: Two Pointers

---

### Problem 1 — Valid Palindrome (LC #125)

**Statement:** Given a string `s`, return `true` if it is a palindrome after removing all non-alphanumeric characters and lowercasing.

**Key insight:** Use two pointers starting at both ends. Skip non-alphanumeric characters in the loop rather than building a filtered copy. This keeps space O(1) and requires no `StringBuilder`.

**Java vs Rust:** Rust filters to a `Vec<u8>` then walks indices; Java can skip characters inline with `Character.isLetterOrDigit(c)`. Both are O(n) time. `String.charAt(i)` is O(1) in Java (UTF-16 array), matching Rust's `s.as_bytes()[i]`.

```java
class Solution {
    public boolean isPalindrome(String s) {
        int l = 0, r = s.length() - 1;
        while (l < r) {
            // Skip non-alphanumeric from the left
            while (l < r && !Character.isLetterOrDigit(s.charAt(l))) l++;
            // Skip non-alphanumeric from the right
            while (l < r && !Character.isLetterOrDigit(s.charAt(r))) r--;
            if (Character.toLowerCase(s.charAt(l)) != Character.toLowerCase(s.charAt(r))) {
                return false;
            }
            l++;
            r--;
        }
        return true;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (!sol.isPalindrome("A man, a plan, a canal: Panama"))
            throw new AssertionError("Expected true for Panama");
        if (sol.isPalindrome("race a car"))
            throw new AssertionError("Expected false for 'race a car'");
        if (!sol.isPalindrome(" "))
            throw new AssertionError("Expected true for single space");
        if (!sol.isPalindrome(""))
            throw new AssertionError("Expected true for empty string");
        if (sol.isPalindrome("0P"))
            throw new AssertionError("Expected false for '0P'");
        System.out.println("LC #125 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1).

**Java note:** `Character.isLetterOrDigit(c)` handles letters and digits in one call — no need for separate `isLetter`/`isDigit` checks. Rust uses `.is_ascii_alphanumeric()` on a `u8`, which is the byte-level equivalent. In Java the inline skip approach is more idiomatic than collecting to a `StringBuilder` first.

---

### Problem 2 — Two Sum II: Input Array Is Sorted (LC #167)

**Statement:** Given a 1-indexed sorted array `numbers` and a `target`, return the indices `[i, j]` (1-indexed) of the two numbers that add up to `target`. Exactly one solution is guaranteed.

**Key insight:** Because the array is sorted, `numbers[l] + numbers[r] < target` means move `l` right (increase the sum); `> target` means move `r` left (decrease the sum). Converges in O(n).

**Common bug:** The return must be **1-indexed**: `new int[]{l + 1, r + 1}`. Forgetting the `+1` is the most frequent wrong answer on this problem in both Java and Rust.

```java
class Solution {
    public int[] twoSum(int[] numbers, int target) {
        int l = 0, r = numbers.length - 1;
        // Guaranteed exactly one solution; loop always terminates.
        while (l < r) {
            int sum = numbers[l] + numbers[r];
            if (sum == target) {
                return new int[]{l + 1, r + 1}; // 1-indexed
            } else if (sum < target) {
                l++;
            } else {
                r--;
            }
        }
        throw new AssertionError("No solution found — violates problem guarantee");
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        int[] r1 = sol.twoSum(new int[]{2, 7, 11, 15}, 9);
        if (r1[0] != 1 || r1[1] != 2)
            throw new AssertionError("Expected [1,2], got " + r1[0] + "," + r1[1]);
        int[] r2 = sol.twoSum(new int[]{2, 3, 4}, 6);
        if (r2[0] != 1 || r2[1] != 3)
            throw new AssertionError("Expected [1,3]");
        int[] r3 = sol.twoSum(new int[]{-1, 0}, -1);
        if (r3[0] != 1 || r3[1] != 2)
            throw new AssertionError("Expected [1,2]");
        System.out.println("LC #167 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1).

---

### Problem 3 — 3Sum (LC #15)

**Statement:** Given an integer array `nums`, return all triplets `[a, b, c]` such that `a + b + c == 0` with no duplicate triplets.

**Key insight:** Sort first. Fix `nums[i]` as the anchor, then use two pointers on the remaining subarray. Skip duplicate anchor values and duplicate inner values after each match to avoid duplicate triplets in the result.

**Duplicate-skip logic (easy to get wrong):**
- Outer: `if (i > 0 && nums[i] == nums[i-1]) continue;`
- Inner after match: advance `l` and `r` past duplicate values, then step one more.

```java
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

class Solution {
    public List<List<Integer>> threeSum(int[] nums) {
        Arrays.sort(nums);
        List<List<Integer>> result = new ArrayList<>();
        int n = nums.length;

        for (int i = 0; i < n - 2; i++) {
            // Skip duplicate anchor values
            if (i > 0 && nums[i] == nums[i - 1]) continue;
            // Early exit: sorted array, anchor > 0 means all remaining sums > 0
            if (nums[i] > 0) break;

            int l = i + 1, r = n - 1;
            while (l < r) {
                int sum = nums[i] + nums[l] + nums[r];
                if (sum == 0) {
                    result.add(Arrays.asList(nums[i], nums[l], nums[r]));
                    // Skip duplicates from left and right
                    while (l < r && nums[l] == nums[l + 1]) l++;
                    while (l < r && nums[r] == nums[r - 1]) r--;
                    l++;
                    r--;
                } else if (sum < 0) {
                    l++;
                } else {
                    r--;
                }
            }
        }
        return result;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        List<List<Integer>> r1 = sol.threeSum(new int[]{-1, 0, 1, 2, -1, -4});
        // Sort each triplet and the list for deterministic comparison
        r1.forEach(t -> ((List<Integer>)t).sort(null));
        r1.sort((a, b) -> { for (int i = 0; i < 3; i++) { int c = a.get(i).compareTo(b.get(i)); if (c != 0) return c; } return 0; });
        if (r1.size() != 2)
            throw new AssertionError("Expected 2 triplets, got " + r1.size());
        if (!r1.get(0).equals(Arrays.asList(-1, -1, 2)))
            throw new AssertionError("Expected [-1,-1,2]");
        if (!r1.get(1).equals(Arrays.asList(-1, 0, 1)))
            throw new AssertionError("Expected [-1,0,1]");

        if (!sol.threeSum(new int[]{0, 1, 1}).isEmpty())
            throw new AssertionError("Expected empty for [0,1,1]");
        List<List<Integer>> r3 = sol.threeSum(new int[]{0, 0, 0});
        if (r3.size() != 1 || !r3.get(0).equals(Arrays.asList(0, 0, 0)))
            throw new AssertionError("Expected [[0,0,0]]");
        System.out.println("LC #15 all tests passed.");
    }
}
```

**Complexity:** Time O(n²), Space O(1) excluding output.

**Java note:** `Arrays.sort(int[])` uses dual-pivot quicksort — not stable, but stability is irrelevant here (Rust uses `sort_unstable()` for the same reason).

---

### Problem 4 — Container With Most Water (LC #11)

**Statement:** Given `height`, find two lines forming a container that holds the most water.

**Key insight:** Start widest (`l=0`, `r=n-1`). Area is `width * min(height[l], height[r])`. Always move the pointer at the shorter line — only that move can possibly find a taller bounding line.

```java
class Solution {
    public int maxArea(int[] height) {
        int l = 0, r = height.length - 1;
        int max = 0;
        while (l < r) {
            int area = (r - l) * Math.min(height[l], height[r]);
            max = Math.max(max, area);
            if (height[l] < height[r]) {
                l++;
            } else {
                r--; // when equal, moving either pointer is correct
            }
        }
        return max;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (sol.maxArea(new int[]{1, 8, 6, 2, 5, 4, 8, 3, 7}) != 49)
            throw new AssertionError("Expected 49");
        if (sol.maxArea(new int[]{1, 1}) != 1)
            throw new AssertionError("Expected 1");
        if (sol.maxArea(new int[]{4, 3, 2, 1, 4}) != 16)
            throw new AssertionError("Expected 16");
        System.out.println("LC #11 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1).

---

### Problem 5 — Trapping Rain Water (LC #42)

**Statement:** Given an elevation map `height`, compute how much water it traps after raining.

**Key insight (two-pointer O(1) space):** Water at position `i` is `min(left_max, right_max) - height[i]`. Track running maxima with two pointers. When `height[l] <= height[r]`, the right wall is tall enough — `left_max` is the binding constraint, so process the left side.

```java
class Solution {
    public int trap(int[] height) {
        if (height.length == 0) return 0;
        int l = 0, r = height.length - 1;
        int leftMax = 0, rightMax = 0;
        int water = 0;
        while (l < r) {
            if (height[l] <= height[r]) {
                if (height[l] >= leftMax) {
                    leftMax = height[l]; // new high point, no water here
                } else {
                    water += leftMax - height[l];
                }
                l++;
            } else {
                if (height[r] >= rightMax) {
                    rightMax = height[r];
                } else {
                    water += rightMax - height[r];
                }
                r--;
            }
        }
        return water;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (sol.trap(new int[]{0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1}) != 6)
            throw new AssertionError("Expected 6");
        if (sol.trap(new int[]{4, 2, 0, 3, 2, 5}) != 9)
            throw new AssertionError("Expected 9");
        if (sol.trap(new int[]{}) != 0)
            throw new AssertionError("Expected 0 for empty");
        if (sol.trap(new int[]{3}) != 0)
            throw new AssertionError("Expected 0 for single element");
        if (sol.trap(new int[]{3, 0, 3}) != 3)
            throw new AssertionError("Expected 3");
        System.out.println("LC #42 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1).

**Java note:** Unlike Rust, Java `int[]` does not underflow — `height.length - 1` on an empty array returns `-1`, not a panic. The explicit `length == 0` guard is still good practice for clarity.

---

## Part 2: Sliding Window

---

### Problem 6 — Best Time to Buy and Sell Stock (LC #121)

**Statement:** Given `prices[i]`, find the maximum profit from one buy-low/sell-high transaction. Return 0 if no profit is possible.

**Key insight:** One pass: track the minimum price seen so far and update maximum profit at each step. If current price is below `minPrice`, update the buy point. Never "sell" before "buying" (sell must come after buy in time).

```java
class Solution {
    public int maxProfit(int[] prices) {
        int minPrice = Integer.MAX_VALUE; // sentinel: "haven't bought yet"
        int maxProfit = 0;               // floor at 0: doing nothing is always valid
        for (int price : prices) {
            if (price < minPrice) {
                minPrice = price;
            } else {
                maxProfit = Math.max(maxProfit, price - minPrice);
            }
        }
        return maxProfit;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (sol.maxProfit(new int[]{7, 1, 5, 3, 6, 4}) != 5)
            throw new AssertionError("Expected 5");
        if (sol.maxProfit(new int[]{7, 6, 4, 3, 1}) != 0)
            throw new AssertionError("Expected 0 for decreasing prices");
        if (sol.maxProfit(new int[]{1, 2}) != 1)
            throw new AssertionError("Expected 1");
        System.out.println("LC #121 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1).

**Java vs Rust:** `Integer.MAX_VALUE` matches Rust's `i32::MAX` exactly — same sentinel pattern. `Math.max` replaces `.max()` method on primitives. The logic is otherwise identical.

---

### Problem 7 — Longest Substring Without Repeating Characters (LC #3)

**Statement:** Given string `s`, return the length of the longest substring with all distinct characters.

**Key insight (variable sliding window):** Track the last-seen index of each character in an `int[128]` array (all ASCII). When a repeat is found inside the current window, jump `left` to `lastSeen[c] + 1`. No `HashMap` needed.

**Java vs Rust:** Rust uses `[usize; 128]` with `usize::MAX` as a "never seen" sentinel. In Java, initialize the array to `-1` (an invalid index) to mean "never seen" — cleaner than `Integer.MAX_VALUE` here. `s.charAt(i)` is O(1) (same as `s.as_bytes()[i]` in Rust for ASCII).

```java
class Solution {
    public int lengthOfLongestSubstring(String s) {
        int[] lastSeen = new int[128];
        java.util.Arrays.fill(lastSeen, -1); // -1 = "never seen"
        int left = 0, maxLen = 0;

        for (int right = 0; right < s.length(); right++) {
            int c = s.charAt(right);
            // If c was seen inside the current window, shrink from the left
            if (lastSeen[c] >= left) {
                left = lastSeen[c] + 1;
            }
            lastSeen[c] = right;
            maxLen = Math.max(maxLen, right - left + 1);
        }
        return maxLen;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (sol.lengthOfLongestSubstring("abcabcbb") != 3)
            throw new AssertionError("Expected 3 for 'abcabcbb'");
        if (sol.lengthOfLongestSubstring("bbbbb") != 1)
            throw new AssertionError("Expected 1 for 'bbbbb'");
        if (sol.lengthOfLongestSubstring("pwwkew") != 3)
            throw new AssertionError("Expected 3 for 'pwwkew'");
        if (sol.lengthOfLongestSubstring("") != 0)
            throw new AssertionError("Expected 0 for empty string");
        if (sol.lengthOfLongestSubstring(" ") != 1)
            throw new AssertionError("Expected 1 for single space");
        System.out.println("LC #3 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1) — `int[128]` is fixed-size regardless of input.

**Java note:** Java developers often default to `HashMap<Character, Integer>`. The `int[128]` array is preferred for ASCII problems — same O(1) lookup, zero boxing overhead, and simpler initialization. This directly mirrors Rust's `[usize; 128]` approach.

---

### Problem 8 — Longest Repeating Character Replacement (LC #424)

**Statement:** Given uppercase-letter string `s` and integer `k`, you may replace at most `k` characters. Return the length of the longest all-same-letter substring achievable.

**Key insight:** A window `[left, right]` is valid when `(window_size - maxFreq) <= k`. The non-dominant characters are the ones we replace; there can be at most `k` of them. When the window becomes invalid, slide `left` by one.

**Subtle point:** `maxFreq` is never decremented when shrinking. We only care about windows at least as large as the current best. This is the `if` (not `while`) shrink — the window size is non-decreasing.

```java
class Solution {
    public int characterReplacement(String s, int k) {
        int[] count = new int[26]; // frequency of each letter in current window
        int maxFreq = 0;
        int left = 0, maxLen = 0;

        for (int right = 0; right < s.length(); right++) {
            int idx = s.charAt(right) - 'A';
            count[idx]++;
            maxFreq = Math.max(maxFreq, count[idx]);

            // Shrink by 1 if window is invalid (never a while loop here)
            if ((right - left + 1) - maxFreq > k) {
                count[s.charAt(left) - 'A']--;
                left++;
                // maxFreq is intentionally NOT updated here
            }
            maxLen = Math.max(maxLen, right - left + 1);
        }
        return maxLen;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (sol.characterReplacement("ABAB", 2) != 4)
            throw new AssertionError("Expected 4 for ABAB k=2");
        if (sol.characterReplacement("AABABBA", 1) != 4)
            throw new AssertionError("Expected 4 for AABABBA k=1");
        if (sol.characterReplacement("AAAA", 0) != 4)
            throw new AssertionError("Expected 4 for AAAA k=0");
        if (sol.characterReplacement("A", 0) != 1)
            throw new AssertionError("Expected 1 for A k=0");
        System.out.println("LC #424 all tests passed.");
    }
}
```

**Complexity:** Time O(n), Space O(1).

---

### Problem 9 — Permutation in String (LC #567)

**Statement:** Given strings `s1` and `s2`, return `true` if any permutation of `s1` is a substring of `s2`.

**Key insight (fixed sliding window):** A permutation has the same character frequencies. Maintain a fixed window of size `s1.length()` over `s2` and compare `int[26]` frequency arrays with `Arrays.equals()` — an O(26) = O(1) comparison.

**Java vs Rust:** Both use `int[26]` / `[i32; 26]` with `Arrays.equals()` / `==` for comparison. This avoids the common (but slower) `HashMap` approach. Calling `Arrays.equals` on a 26-element array is effectively constant time.

```java
import java.util.Arrays;

class Solution {
    public boolean checkInclusion(String s1, String s2) {
        if (s1.length() > s2.length()) return false;
        int k = s1.length();
        int[] need   = new int[26];
        int[] window = new int[26];

        for (char c : s1.toCharArray()) need[c - 'a']++;
        // Seed the first window
        for (int i = 0; i < k; i++) window[s2.charAt(i) - 'a']++;
        if (Arrays.equals(need, window)) return true;

        // Slide the window
        for (int right = k; right < s2.length(); right++) {
            window[s2.charAt(right) - 'a']++;          // add incoming character
            window[s2.charAt(right - k) - 'a']--;      // remove outgoing character
            if (Arrays.equals(need, window)) return true;
        }
        return false;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        if (!sol.checkInclusion("ab", "eidbaooo"))
            throw new AssertionError("Expected true for ab in eidbaooo");
        if (sol.checkInclusion("ab", "eidboaoo"))
            throw new AssertionError("Expected false for ab in eidboaoo");
        if (!sol.checkInclusion("a", "a"))
            throw new AssertionError("Expected true for a in a");
        if (sol.checkInclusion("abc", "ab"))
            throw new AssertionError("Expected false when s1 longer than s2");
        System.out.println("LC #567 all tests passed.");
    }
}
```

**Complexity:** Time O(26·n) = O(n), Space O(1).

---

### Problem 10 — Minimum Window Substring (LC #76)

**Statement:** Given strings `s` and `t`, return the minimum window substring of `s` containing all characters of `t`. Return `""` if none exists.

**Key insight:** Track `have` (how many distinct chars from `t` are currently satisfied) and `required` (total distinct chars in `t`). When `have == required`, all chars are covered — try to shrink from the left. This avoids comparing full maps each step.

**Java boxing trap:** `Map<Character, Integer>` values are `Integer` objects. Use `getOrDefault(c, 0)` to avoid `NullPointerException`. When comparing window count to need count — use `.equals()`, not `==`. Auto-boxing caches integers only up to 127; `==` on boxed `Integer > 127` compares references, not values, and silently gives wrong answers.

```java
import java.util.HashMap;
import java.util.Map;

class Solution {
    public String minWindow(String s, String t) {
        if (s.isEmpty() || t.isEmpty()) return "";

        Map<Character, Integer> need = new HashMap<>();
        for (char c : t.toCharArray()) need.merge(c, 1, Integer::sum);

        int required = need.size();
        int have = 0;
        Map<Character, Integer> window = new HashMap<>();
        int left = 0, bestLeft = 0, bestLen = Integer.MAX_VALUE;

        for (int right = 0; right < s.length(); right++) {
            char b = s.charAt(right);
            window.merge(b, 1, Integer::sum);

            // Check if this character just satisfied its required count
            if (need.containsKey(b) && window.get(b).equals(need.get(b))) {
                have++;
            }

            // All required characters present — try to shrink
            while (have == required) {
                int winLen = right - left + 1;
                if (winLen < bestLen) {
                    bestLen = winLen;
                    bestLeft = left;
                }
                char lb = s.charAt(left);
                window.merge(lb, -1, Integer::sum);
                if (need.containsKey(lb) && window.get(lb) < need.get(lb)) {
                    have--;
                }
                left++;
            }
        }
        return bestLen == Integer.MAX_VALUE ? "" : s.substring(bestLeft, bestLeft + bestLen);
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        String r1 = sol.minWindow("ADOBECODEBANC", "ABC");
        if (!r1.equals("BANC"))
            throw new AssertionError("Expected BANC, got " + r1);
        String r2 = sol.minWindow("a", "a");
        if (!r2.equals("a"))
            throw new AssertionError("Expected a");
        String r3 = sol.minWindow("a", "aa");
        if (!r3.equals(""))
            throw new AssertionError("Expected empty for impossible case");
        String r4 = sol.minWindow("abc", "d");
        if (!r4.equals(""))
            throw new AssertionError("Expected empty when t not in s");
        System.out.println("LC #76 all tests passed.");
    }
}
```

**Complexity:** Time O(|s| + |t|), Space O(|s| + |t|).

**Java vs Rust:**
- `map.merge(key, 1, Integer::sum)` is the modern Java 8+ idiom for frequency maps — cleaner than `put(key, getOrDefault(key, 0) + 1)`. Rust's equivalent is `*map.entry(b).or_insert(0) += 1`.
- `s.substring(bestLeft, bestLeft + bestLen)` creates a new `String` object (O(n)). Rust's `s[best_left..best_left + best_len].to_string()` is identical semantically.
- **Boxing trap:** `window.get(b).equals(need.get(b))` uses `.equals()` not `==`. For `Integer` values above 127, `==` compares object references, not values. Rust does not have this problem because integer comparison always uses value semantics.

---

### Problem 11 — Sliding Window Maximum (LC #239)

**Statement:** Given array `nums` and window size `k`, return the maximum value in each window of size `k`.

**Key insight (monotonic deque):** Use `Deque<Integer>` (via `ArrayDeque`) storing **indices** in decreasing order of their values. The front is always the current window maximum. Before adding index `i`: (1) evict front indices outside the window; (2) evict back indices whose values are ≤ `nums[i]` — they are dominated and will expire before `i`.

**Java note:** Use `ArrayDeque<Integer>` — not `Stack` (legacy, synchronized) and not `LinkedList` (extra memory). `ArrayDeque` provides O(1) `peekFirst`, `peekLast`, `pollFirst`, `pollLast`, `offerLast`.

```java
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

class Solution {
    public int[] maxSlidingWindow(int[] nums, int k) {
        int n = nums.length;
        int[] result = new int[n - k + 1];
        // Monotonic decreasing deque: stores indices, values decrease front→back
        Deque<Integer> deque = new ArrayDeque<>();

        for (int i = 0; i < n; i++) {
            // 1. Evict indices outside the current window [i-k+1, i]
            while (!deque.isEmpty() && deque.peekFirst() + k <= i) {
                deque.pollFirst();
            }
            // 2. Maintain decreasing invariant: remove dominated back entries
            while (!deque.isEmpty() && nums[deque.peekLast()] <= nums[i]) {
                deque.pollLast();
            }
            deque.offerLast(i);

            // Record result once the first full window is formed
            if (i >= k - 1) {
                result[i - k + 1] = nums[deque.peekFirst()];
            }
        }
        return result;
    }

    public static void main(String[] args) {
        Solution sol = new Solution();
        int[] r1 = sol.maxSlidingWindow(new int[]{1, 3, -1, -3, 5, 3, 6, 7}, 3);
        if (!Arrays.equals(r1, new int[]{3, 3, 5, 5, 6, 7}))
            throw new AssertionError("Expected [3,3,5,5,6,7]");
        int[] r2 = sol.maxSlidingWindow(new int[]{1}, 1);
        if (!Arrays.equals(r2, new int[]{1}))
            throw new AssertionError("Expected [1]");
        int[] r3 = sol.maxSlidingWindow(new int[]{1, -1}, 1);
        if (!Arrays.equals(r3, new int[]{1, -1}))
            throw new AssertionError("Expected [1,-1]");
        int[] r4 = sol.maxSlidingWindow(new int[]{5, 4, 3, 2, 1}, 3);
        if (!Arrays.equals(r4, new int[]{5, 4, 3}))
            throw new AssertionError("Expected [5,4,3]");
        System.out.println("LC #239 all tests passed.");
    }
}
```

**Complexity:** Time O(n) — each index is enqueued and dequeued at most once. Space O(k) for the deque.

**Java vs Rust:**
- `ArrayDeque<Integer>` maps directly to Rust's `VecDeque<usize>`. Both are O(1) at both ends.
- Java `Deque` interface method names: `offerLast`/`pollLast`/`peekLast` for the back; `pollFirst`/`peekFirst` for the front. Rust uses `push_back`/`pop_back`/`back` and `pop_front`/`front`.
- The deque stores **indices**, not values — identical design choice in both languages. Storing values instead of indices is a classic bug because you lose the ability to check if an entry is still inside the window.

---

## Complexity Summary

| # | Problem | Time | Space | Pattern |
|---|---------|------|-------|---------|
| 125 | Valid Palindrome | O(n) | O(1) | Two Pointers |
| 167 | Two Sum II | O(n) | O(1) | Two Pointers |
| 15 | 3Sum | O(n²) | O(1) | Two Pointers + Sort |
| 11 | Container With Most Water | O(n) | O(1) | Two Pointers |
| 42 | Trapping Rain Water | O(n) | O(1) | Two Pointers |
| 121 | Best Time to Buy/Sell Stock | O(n) | O(1) | Sliding Window (greedy) |
| 3 | Longest Substring No Repeat | O(n) | O(1) | Variable Sliding Window |
| 424 | Longest Repeating Replacement | O(n) | O(1) | Variable Sliding Window |
| 567 | Permutation in String | O(n) | O(1) | Fixed Sliding Window |
| 76 | Minimum Window Substring | O(n) | O(n) | Variable Sliding Window |
| 239 | Sliding Window Maximum | O(n) | O(k) | Monotonic Deque |

> **Note on LC #125 space:** The Java version uses two in-place pointers with no auxiliary buffer — O(1). The Rust chapter's solution allocates a `Vec<u8>` of filtered bytes for O(n) space. The Java inline-skip approach is more space-efficient.

---

## Java Patterns Reference

### `int[26]` frequency array (preferred over `HashMap` for lowercase a–z)

```java
int[] freq = new int[26];
for (char c : s.toCharArray()) freq[c - 'a']++;

// Compare two windows in O(26) = O(1):
if (Arrays.equals(freq1, freq2)) { /* match */ }
```

### `int[128]` for full ASCII (all printable characters)

```java
int[] lastSeen = new int[128];
Arrays.fill(lastSeen, -1);  // -1 = "never seen" sentinel
// Index with: lastSeen[s.charAt(i)]
```

### `Map.merge` for frequency maps (Java 8+, cleaner than getOrDefault)

```java
Map<Character, Integer> freq = new HashMap<>();
for (char c : t.toCharArray()) freq.merge(c, 1, Integer::sum);
// Decrement: freq.merge(c, -1, Integer::sum);
```

### `ArrayDeque` as a monotonic deque

```java
Deque<Integer> deque = new ArrayDeque<>();  // stores indices

// Add index i, maintaining decreasing value order:
while (!deque.isEmpty() && nums[deque.peekLast()] <= nums[i])
    deque.pollLast();
deque.offerLast(i);

// Query current max:
int maxVal = nums[deque.peekFirst()];

// Evict stale front (outside window of size k):
if (!deque.isEmpty() && deque.peekFirst() + k <= i)
    deque.pollFirst();
```

### Two-pointer template

```java
int l = 0, r = arr.length - 1;
while (l < r) {
    // process arr[l], arr[r]
    if (/* need larger sum */) l++;
    else r--;
}
```

### Variable sliding window template

```java
int left = 0, maxLen = 0;
// state: int[26] or Map<Character, Integer>
for (int right = 0; right < s.length(); right++) {
    // 1. Expand: add s.charAt(right) to state
    // 2. Shrink: while window invalid
    while (/* window invalid */) {
        // remove s.charAt(left) from state
        left++;
    }
    // 3. Update answer
    maxLen = Math.max(maxLen, right - left + 1);
}
```

---

## 📝 Chapter Review Notes

### Critical Review

**LC #125 — Valid Palindrome**
The Java solution uses in-place two-pointer skipping (O(1) space), which is more efficient than the Rust solution's `Vec<u8>` of filtered bytes (O(n) space). Both are correct. `Character.isLetterOrDigit(c)` is the idiomatic Java equivalent of Rust's `.is_ascii_alphanumeric()` on a `u8`. For Unicode input, `isLetterOrDigit` covers more code points than the ASCII-only Rust method — but LeetCode's constraint is ASCII only, so both are equivalent here.

**LC #167 — Two Sum II**
The `throw new AssertionError(...)` at the bottom of the loop body is correct defensive programming. The problem guarantees one solution, so the code never reaches it — but it documents the invariant. The 1-indexed return (`l + 1`, `r + 1`) is the most common source of wrong answers.

**LC #15 — 3Sum**
The early `break` when `nums[i] > 0` is valid after sorting — all remaining anchors are also positive, making a zero sum impossible. The inner duplicate-skip `while` loops are bounds-safe: `l < r` ensures `l + 1 <= r`, so `nums[l + 1]` is always in range.

**LC #42 — Trapping Rain Water**
The two-pointer correctness argument: when `height[l] <= height[r]`, there exists a right wall at least as tall as `height[l]`, so `left_max` fully determines trapped water at `l`. The guard `if (height.length == 0) return 0` is important — without it, accessing `height.length - 1` on an empty array gives `-1`, and the `while (l < r)` condition (`0 < -1`) is false, so the method would return 0 anyway. The guard is still good defensive style.

**LC #121 — Best Time to Buy and Sell Stock**
`Integer.MAX_VALUE` as `minPrice` sentinel is safe: `prices` are non-negative per constraints, so `price - minPrice` can never overflow when `minPrice <= price`. For a length-1 array, the `else` branch never executes and `maxProfit` correctly stays at 0.

**LC #3 — Longest Substring Without Repeating Characters**
The `-1` sentinel (vs Rust's `usize::MAX`) is cleaner in Java: the condition `lastSeen[c] >= left` naturally handles `-1` because `left >= 0 > -1` always. No special-case needed. The `int[128]` covers all ASCII code points 0–127 correctly.

**LC #424 — Longest Repeating Character Replacement**
The `if` (not `while`) shrink is intentional and correct: since we expand by exactly 1 per iteration and shrink by at most 1, the window size is monotonically non-decreasing. `maxFreq` is not decremented on shrink — this correctly tracks the best frequency seen so far, not the current window's frequency.

**LC #567 — Permutation in String**
`Arrays.equals(need, window)` on `int[26]` is O(26) = O(1) in practice. This avoids iterating over a `HashMap` for every position. First window is seeded before the slide loop to avoid a special case inside the loop — same as the Rust version.

**LC #76 — Minimum Window Substring**
`have` counts distinct characters whose window frequency has reached the required count, not total character count. For `t = "AAB"`, `required = 2` (two distinct chars: A and B), and `have` reaches 2 when both 'A' (count ≥ 2) and 'B' (count ≥ 1) are satisfied. Using `.equals()` (not `==`) when comparing `Integer` objects is critical for correctness — autoboxing caches only [-128, 127].

**LC #239 — Sliding Window Maximum**
The eviction condition `deque.peekFirst() + k <= i` correctly detects that the front index is outside window `[i-k+1, i]`. The back-eviction uses `<=` (not `<`): if the incoming value equals the back value, evict the older one — it expires sooner and can never be the max while the newer equal value is in the window. `ArrayDeque` is the correct choice over `LinkedList` (more memory) or `Stack` (legacy, synchronized).

---

### Fact-Check Table

| Problem | Claim | Verdict | Note |
|---------|-------|---------|------|
| LC #125 | In-place Java skip is O(1) space | Correct | Rust version is O(n); Java avoids the filtered `Vec<u8>` |
| LC #125 | `Character.isLetterOrDigit` ≡ Rust `.is_ascii_alphanumeric()` for ASCII input | Correct | Java's method also covers non-ASCII letters; irrelevant for LeetCode's ASCII constraint |
| LC #167 | Return must be 1-indexed | Correct | `l + 1`, `r + 1`; most common wrong-answer cause |
| LC #15 | `nums[i] > 0` early break is safe | Correct | After sort, all remaining anchors are positive; no zero-sum possible |
| LC #42 | `height[l] <= height[r]` → left_max is binding | Correct | Right wall guarantees at least `height[l]` height; left_max fully determines water at `l` |
| LC #121 | `Integer.MAX_VALUE` sentinel avoids overflow | Correct | Prices are non-negative; `price - minPrice` is always non-negative when branch executes |
| LC #3 | `lastSeen[c] >= left` correctly handles `-1` sentinel | Correct | `left >= 0 > -1` always; no special case needed |
| LC #424 | `if` not `while` for shrink is intentional | Correct | Window size is non-decreasing; at most 1 shrink per expansion |
| LC #424 | `maxFreq` not decremented on shrink | Correct | Tracks best-ever frequency; allows non-decreasing window size optimization |
| LC #567 | `Arrays.equals(int[26], int[26])` is O(1) | Correct | O(26) comparisons; effectively constant time |
| LC #76 | `window.get(b).equals(need.get(b))` not `==` | Correct | Integer autoboxing cache ends at 127; `==` is unsafe for values > 127 |
| LC #76 | `have` counts distinct chars satisfied, not total | Correct | `t = "AAB"` → `required = 2`; have counts A and B each separately |
| LC #239 | Back-eviction uses `<=` not `<` | Correct | Equal-value older index expires sooner; evict to keep the newer one |
| LC #239 | `ArrayDeque` preferred over `LinkedList`/`Stack` | Correct | No synchronization overhead; contiguous memory; standard recommendation |
| LC #239 | Deque stores indices, not values | Correct | Storing values loses window-expiry check ability; classic bug |
