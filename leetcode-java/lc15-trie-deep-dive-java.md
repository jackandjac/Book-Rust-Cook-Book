# Chapter 15: Trie Deep Dive (Java)

> **Chapter goal:** Master the Trie (prefix tree) data structure and its variations across the full
> LeetCode Trie Study Plan. Every solution is a self-contained Java 17+ class with a `main` test
> driver using `throw new AssertionError(...)` — no JUnit, no `assert` keyword.
>
> **Prerequisites:** LC #208, #211, #212 (Implement Trie, Add and Search Words, Word Search II)
> are covered in **Chapter 7 (lc07-tries-graphs-java.md)**. This chapter assumes familiarity with
> the basic `TrieNode` array structure introduced there and dives straight into harder problems.

> **Java vs Rust — Trie ownership model:**
> In Rust a trie node is `struct TrieNode { children: [Option<Box<TrieNode>>; 26], is_end: bool }`.
> The `Box` heap-allocates each child; `Option` represents absence without a null pointer.
> In Java `TrieNode[] children = new TrieNode[26]` achieves the same layout — a `null` slot means
> no child, a non-null slot is a heap-allocated node. There is no ownership transfer; the GC
> handles memory. The practical effect: Java trie insertion and lookup are almost identical to
> pseudocode, while Rust forces explicit allocation at every level.

---

## Canonical TrieNode (shown once, re-declared per Solution)

Each problem's `Solution` class redeclares `TrieNode` as a `static` nested class so every snippet
compiles independently. The shape below is the default; problem-specific variants (extra `count`
field, binary `Node[2]` for XOR) are introduced where needed.

```java
static class TrieNode {
    TrieNode[] children = new TrieNode[26];
    boolean isEnd;
}
```

`children[0]` = `'a'`, `children[25]` = `'z'`. Index computed as `ch - 'a'`.

---

## Problem Overview

| # | Problem | Difficulty | Tier |
|---|---------|-----------|------|
| LC 14  | Longest Common Prefix | Easy | 1 |
| LC 139 | Word Break | Medium | 1 |
| LC 648 | Replace Words | Medium | 1 |
| LC 677 | Map Sum Pairs | Medium | 1 |
| LC 692 | Top K Frequent Words | Medium | 1 |
| LC 720 | Longest Word in Dictionary | Medium | 1 |
| LC 820 | Short Encoding of Words | Medium | 1 |
| LC 1268 | Search Suggestions System | Medium | 1 |
| LC 140 | Word Break II | Hard | 2 |
| LC 421 | Maximum XOR of Two Numbers in an Array | Medium | 2 |
| LC 336 | Palindrome Pairs | Hard | 2 |
| LC 1032 | Stream of Characters | Hard | 2 |
| LC 676 | Implement Magic Dictionary | Medium | 2 |
| LC 386 | Lexicographical Numbers | Medium | 2 |
| LC 440 | K-th Smallest in Lexicographical Order | Hard | 2 |
| LC 472 | Concatenated Words | Hard | 2 |
| LC 1178 | Number of Valid Words for Each Puzzle | Hard | 2 |
| LC 2416 | Sum of Prefix Scores of Strings | Hard | 2 |

---

## Part 1 — Tier 1: Core Trie Problems

---

## LC14. Longest Common Prefix

**Why trie?** Inserting all words into a trie and then walking the single-child spine from the root
gives the common prefix directly. The iterative horizontal scan is O(S) and simpler for an
interview — both approaches are shown.

**Key insight (vertical scan):** Walk the first word character by character; for each position,
check that every other word has the same character at that position.

```java
class Solution14 {
    public String longestCommonPrefix(String[] strs) {
        if (strs.length == 0) return "";
        String first = strs[0];
        for (int i = 0; i < first.length(); i++) {
            char c = first.charAt(i);
            for (int j = 1; j < strs.length; j++) {
                if (i >= strs[j].length() || strs[j].charAt(i) != c) {
                    return first.substring(0, i);
                }
            }
        }
        return first;
    }

    // Trie variant: walk single-child spine
    public String longestCommonPrefixTrie(String[] strs) {
        if (strs.length == 0) return "";
        var root = new TrieNode();
        for (var w : strs) {
            var node = root;
            for (char c : w.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.isEnd = true;
        }
        var sb = new StringBuilder();
        var node = root;
        // Walk while exactly one child and not at a word end
        while (!node.isEnd) {
            int only = -1;
            for (int i = 0; i < 26; i++) {
                if (node.children[i] != null) {
                    if (only != -1) return sb.toString(); // branching: stop
                    only = i;
                }
            }
            if (only == -1) break;
            sb.append((char)('a' + only));
            node = node.children[only];
        }
        return sb.toString();
    }

    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    public static void main(String[] args) {
        var s = new Solution14();
        String r1 = s.longestCommonPrefix(new String[]{"flower","flow","flight"});
        if (!r1.equals("fl")) throw new AssertionError("LC14 t1: got " + r1);
        String r2 = s.longestCommonPrefix(new String[]{"dog","racecar","car"});
        if (!r2.equals("")) throw new AssertionError("LC14 t2: got " + r2);
        String r3 = s.longestCommonPrefixTrie(new String[]{"flower","flow","flight"});
        if (!r3.equals("fl")) throw new AssertionError("LC14 trie t1: got " + r3);
        String r4 = s.longestCommonPrefixTrie(new String[]{"abc"});
        if (!r4.equals("abc")) throw new AssertionError("LC14 trie single: got " + r4);
    }
}
```

**Complexity.** Vertical scan: O(S) where S = total characters. Trie variant: O(S) build + O(L)
walk where L = prefix length. Space O(S) for the trie.

> **Java vs Rust:** Rust's `str::chars()` returns an iterator; Java uses `.toCharArray()` or
> `.charAt(i)`. Both produce the same O(1) per-character access. The `StringBuilder` append loop
> is idiomatic Java — Rust would use `String::push` on a mutable `String`.

---

## LC139. Word Break

**Why trie?** A trie lets you simultaneously check all dictionary words that are prefixes of the
remaining string in one pass. The DP approach without a trie is O(n² × m) per cell; with a trie,
it's O(n × L) where L is the maximum word length — often faster in practice.

**Key insight (DP with trie):** `dp[i]` = true if `s[0..i)` can be segmented. For each `i` where
`dp[i]` is true, walk the trie character by character from `s[i]`; whenever you hit an `isEnd`
node at position `j`, set `dp[j] = true`.

```java
import java.util.*;

class Solution139 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    public boolean wordBreak(String s, List<String> wordDict) {
        var root = new TrieNode();
        for (var word : wordDict) {
            var node = root;
            for (char c : word.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.isEnd = true;
        }

        int n = s.length();
        var dp = new boolean[n + 1];
        dp[0] = true;
        for (int i = 0; i < n; i++) {
            if (!dp[i]) continue;
            var node = root;
            for (int j = i; j < n; j++) {
                int idx = s.charAt(j) - 'a';
                if (node.children[idx] == null) break;
                node = node.children[idx];
                if (node.isEnd) dp[j + 1] = true;
            }
        }
        return dp[n];
    }

    public static void main(String[] args) {
        var s = new Solution139();
        boolean r1 = s.wordBreak("leetcode", List.of("leet","code"));
        if (!r1) throw new AssertionError("LC139 t1: expected true");
        boolean r2 = s.wordBreak("applepenapple", List.of("apple","pen"));
        if (!r2) throw new AssertionError("LC139 t2: expected true");
        boolean r3 = s.wordBreak("catsandog", List.of("cats","dog","sand","and","cat"));
        if (r3) throw new AssertionError("LC139 t3: expected false");
    }
}
```

**Complexity.** O(n × L) time where L = max word length, O(n + W × L) space for dp array + trie.

> **Java vs Rust:** The trie traversal `node.children[idx]` null-check maps directly to Rust's
> `node.children[idx].as_ref()?` with the `?` short-circuiting the walk. Java uses an explicit
> `break`; Rust can use `Option` chaining.

---

## LC648. Replace Words

**Key insight:** Build a trie from all roots. For each word in the sentence, walk the trie; the
first `isEnd` node encountered gives the shortest matching root. If no root matches, keep the word.

```java
import java.util.*;

class Solution648 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private TrieNode root = new TrieNode();

    private void insert(String word) {
        var node = root;
        for (char c : word.toCharArray()) {
            int idx = c - 'a';
            if (node.children[idx] == null) node.children[idx] = new TrieNode();
            node = node.children[idx];
        }
        node.isEnd = true;
    }

    private String replaceWord(String word) {
        var node = root;
        var sb = new StringBuilder();
        for (char c : word.toCharArray()) {
            int idx = c - 'a';
            if (node.children[idx] == null) return word; // no root matches
            node = node.children[idx];
            sb.append(c);
            if (node.isEnd) return sb.toString(); // shortest root found
        }
        return word;
    }

    public String replaceWords(List<String> dictionary, String sentence) {
        root = new TrieNode();
        for (var r : dictionary) insert(r);
        var words = sentence.split(" ");
        var result = new StringBuilder();
        for (int i = 0; i < words.length; i++) {
            if (i > 0) result.append(' ');
            result.append(replaceWord(words[i]));
        }
        return result.toString();
    }

    public static void main(String[] args) {
        var s = new Solution648();
        String r1 = s.replaceWords(List.of("cat","bat","rat"), "the cattle was rattled by the battery");
        if (!r1.equals("the cat was rat by the bat")) throw new AssertionError("LC648 t1: got " + r1);
        String r2 = s.replaceWords(List.of("a","b","c"), "aadsfasf absbs bbab cadsfafs");
        if (!r2.equals("a a b c")) throw new AssertionError("LC648 t2: got " + r2);
    }
}
```

**Complexity.** O(W × L) build + O(S) replace where W = dict words, L = avg word length, S = sentence
length. Space O(W × L) for trie.

---

## LC677. Map Sum Pairs

**Key insight:** Store `val` at each word's terminal node. To compute `prefix` sum, walk the trie
to the prefix's last node, then recursively sum all terminal values in the subtree. Cache the
running sum at each node (`score`) to avoid re-traversal.

```java
class Solution677 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        int val;   // value at this terminal (0 if not a word end)
        int score; // sum of all vals in this subtree
    }

    private final TrieNode root = new TrieNode();
    private final java.util.HashMap<String, Integer> map = new java.util.HashMap<>();

    public void insert(String key, int val) {
        int delta = val - map.getOrDefault(key, 0);
        map.put(key, val);
        var node = root;
        node.score += delta;
        for (char c : key.toCharArray()) {
            int idx = c - 'a';
            if (node.children[idx] == null) node.children[idx] = new TrieNode();
            node = node.children[idx];
            node.score += delta;
        }
        node.val = val;
    }

    public int sum(String prefix) {
        var node = root;
        for (char c : prefix.toCharArray()) {
            int idx = c - 'a';
            if (node.children[idx] == null) return 0;
            node = node.children[idx];
        }
        return node.score;
    }

    public static void main(String[] args) {
        var obj = new Solution677();
        obj.insert("apple", 3);
        int r1 = obj.sum("ap");
        if (r1 != 3) throw new AssertionError("LC677 sum(ap) after apple=3: got " + r1);
        obj.insert("app", 2);
        int r2 = obj.sum("ap");
        if (r2 != 5) throw new AssertionError("LC677 sum(ap) after app=2: got " + r2);
        obj.insert("apple", 1); // update apple
        int r3 = obj.sum("ap");
        if (r3 != 3) throw new AssertionError("LC677 sum(ap) after apple update: got " + r3);
    }
}
```

**Complexity.** `insert` O(L), `sum` O(L) per call. Space O(W × L).

> **Java vs Rust:** The `HashMap<String, Integer>` for tracking old values maps to Rust's
> `HashMap<String, i32>`. Java's `getOrDefault` has no direct Rust analog — use
> `*map.entry(key).or_insert(0)` in Rust to do the same in one step.

---

## LC692. Top K Frequent Words

**Key insight:** Count frequencies with a `HashMap`, then use a min-heap of size `k` with a
custom comparator (higher freq first, lexicographic second) to maintain the top-k. Alternatively,
sort the full entry set — but the heap avoids a full sort.

```java
import java.util.*;

class Solution692 {
    public List<String> topKFrequent(String[] words, int k) {
        var freq = new HashMap<String, Integer>();
        for (var w : words) freq.merge(w, 1, Integer::sum);

        // Min-heap: smallest priority at top so we can evict it
        // Priority: lower freq = higher priority to evict; same freq: lex-later = higher priority to evict
        var pq = new PriorityQueue<Map.Entry<String, Integer>>(
            (a, b) -> a.getValue().equals(b.getValue())
                ? b.getKey().compareTo(a.getKey())   // lex-later has lower priority to keep
                : a.getValue() - b.getValue()         // lower freq has lower priority to keep
        );

        for (var e : freq.entrySet()) {
            pq.offer(e);
            if (pq.size() > k) pq.poll(); // evict the least-desirable
        }

        var result = new ArrayList<String>();
        while (!pq.isEmpty()) result.add(pq.poll().getKey());
        Collections.reverse(result);
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution692();
        var r1 = s.topKFrequent(new String[]{"i","love","leetcode","i","love","coding"}, 2);
        if (!r1.equals(List.of("i","love"))) throw new AssertionError("LC692 t1: got " + r1);
        var r2 = s.topKFrequent(new String[]{"the","day","is","sunny","the","the","the","sunny","is","is"}, 4);
        if (!r2.equals(List.of("the","is","sunny","day"))) throw new AssertionError("LC692 t2: got " + r2);
    }
}
```

**Complexity.** O(n log k) time, O(n) space. The trie alternative (sort by trie DFS order then heap)
is O(n log k) but more code — `PriorityQueue` is idiomatic here.

---

## LC720. Longest Word in Dictionary

**Key insight:** Build a trie. A word can be "built one letter at a time" if and only if every
prefix of that word is also a word in the dictionary (i.e., every prefix node has `isEnd = true`).
BFS or DFS from the root following only `isEnd` nodes finds the longest such word. Tie-break:
lexicographically smallest.

```java
import java.util.*;

class Solution720 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
        String word; // store word at terminal for easy retrieval
    }

    public String longestWord(String[] words) {
        var root = new TrieNode();
        for (var w : words) {
            var node = root;
            for (char c : w.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.isEnd = true;
            node.word = w;
        }

        String result = "";
        // BFS, only following nodes that are word ends
        var queue = new ArrayDeque<TrieNode>();
        queue.offer(root);
        while (!queue.isEmpty()) {
            var node = queue.poll();
            for (var child : node.children) {
                if (child != null && child.isEnd) {
                    queue.offer(child);
                    // Prefer longer; break ties lex-smallest
                    if (child.word.length() > result.length()
                            || (child.word.length() == result.length()
                                && child.word.compareTo(result) < 0)) {
                        result = child.word;
                    }
                }
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution720();
        String r1 = s.longestWord(new String[]{"w","wo","wor","worl","world"});
        if (!r1.equals("world")) throw new AssertionError("LC720 t1: got " + r1);
        String r2 = s.longestWord(new String[]{"a","banana","app","appl","ap","apply","apple"});
        if (!r2.equals("apple")) throw new AssertionError("LC720 t2: got " + r2);
    }
}
```

**Complexity.** O(W × L) build + O(W × L) BFS. Space O(W × L).

---

## LC820. Short Encoding of Words

**Key insight:** A word `w` does NOT need its own `#` anchor if it is a suffix of another word in
the list. Equivalently, insert all words into a trie built from their **reversed** characters;
any word whose reversed form ends at a non-leaf node is a suffix of a longer word and can be
dropped. Only leaf-ending words contribute `len + 1` to the encoding.

```java
import java.util.*;

class Solution820 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isLeaf() {
            for (var c : children) if (c != null) return false;
            return true;
        }
    }

    public int minimumLengthEncoding(String[] words) {
        var root = new TrieNode();
        var nodeToWord = new HashMap<TrieNode, String>();

        for (var w : words) {
            var node = root;
            // Insert reversed word
            for (int i = w.length() - 1; i >= 0; i--) {
                int idx = w.charAt(i) - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            nodeToWord.put(node, w);
        }

        int total = 0;
        for (var entry : nodeToWord.entrySet()) {
            if (entry.getKey().isLeaf()) {
                total += entry.getValue().length() + 1; // +1 for '#'
            }
        }
        return total;
    }

    public static void main(String[] args) {
        var s = new Solution820();
        int r1 = s.minimumLengthEncoding(new String[]{"time","me","bell"});
        if (r1 != 10) throw new AssertionError("LC820 t1: got " + r1);
        int r2 = s.minimumLengthEncoding(new String[]{"t"});
        if (r2 != 2) throw new AssertionError("LC820 t2: got " + r2);
        int r3 = s.minimumLengthEncoding(new String[]{"time","atime"});
        if (r3 != 6) throw new AssertionError("LC820 t3: got " + r3);
    }
}
```

**Complexity.** O(W × L) build and scan. Space O(W × L).

> **Java vs Rust:** The reversed-insert trick is language-agnostic. Rust would use
> `word.chars().rev()` for the reversed iterator; Java uses a manual `i--` loop over `charAt`.

---

## LC1268. Search Suggestions System

**Key insight:** Sort the products. For each prefix of `searchWord`, find the first matching
product via binary search, then take up to 3 consecutive products from that position that still
share the prefix. This avoids building a trie and is cleaner in Java.

**Trie approach** (shown below): insert all products sorted, then walk the trie on each character
of `searchWord` collecting up to 3 suggestions from each node via DFS.

```java
import java.util.*;

class Solution1268 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        List<String> suggestions = new ArrayList<>(); // up to 3, lexicographically sorted
    }

    public List<List<String>> suggestedProducts(String[] products, String searchWord) {
        Arrays.sort(products); // ensures lex order for suggestions
        var root = new TrieNode();
        for (var p : products) {
            var node = root;
            for (char c : p.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
                if (node.suggestions.size() < 3) node.suggestions.add(p);
            }
        }

        var result = new ArrayList<List<String>>();
        var node = root;
        boolean dead = false;
        for (char c : searchWord.toCharArray()) {
            if (!dead) {
                int idx = c - 'a';
                if (node.children[idx] == null) dead = true;
                else node = node.children[idx];
            }
            result.add(dead ? List.of() : node.suggestions);
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution1268();
        var r1 = s.suggestedProducts(new String[]{"mobile","mouse","mango","moneypot","monitor"}, "mouse");
        if (r1.size() != 5) throw new AssertionError("LC1268 t1 size: got " + r1.size());
        if (!r1.get(0).equals(List.of("mango","mobile","moneypot")))
            throw new AssertionError("LC1268 t1[0]: got " + r1.get(0));
        if (!r1.get(4).equals(List.of("mouse")))
            throw new AssertionError("LC1268 t1[4]: got " + r1.get(4));

        var r2 = s.suggestedProducts(new String[]{"havana"}, "havana");
        for (var list : r2) {
            if (!list.equals(List.of("havana")))
                throw new AssertionError("LC1268 t2: unexpected " + list);
        }
    }
}
```

**Complexity.** O(W × L + n × L) build, O(|searchWord|) query. Space O(W × L) for trie + stored
strings (each stored at most once per node — with the 3-cap, this is bounded).

---

## Part 2 — Tier 2: Advanced Trie Problems

---

## LC140. Word Break II

**Key insight:** DP with backtracking (memoised DFS). `dfs(i)` returns all sentences formed from
`s[i..n)`. At each position `i`, walk the trie from that position; whenever `isEnd` is hit at `j`,
append `s[i..j]` to each result of `dfs(j)`. Memoisation avoids recomputing from the same `i`.

```java
import java.util.*;

class Solution140 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private TrieNode root;
    private String s;
    private Map<Integer, List<String>> memo;

    public List<String> wordBreak(String s, List<String> wordDict) {
        this.root = new TrieNode();
        this.s = s;
        this.memo = new HashMap<>();
        for (var w : wordDict) {
            var node = root;
            for (char c : w.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.isEnd = true;
        }
        return dfs(0);
    }

    private List<String> dfs(int start) {
        if (memo.containsKey(start)) return memo.get(start);
        var result = new ArrayList<String>();
        if (start == s.length()) {
            result.add("");
            return result;
        }
        var node = root;
        for (int end = start; end < s.length(); end++) {
            int idx = s.charAt(end) - 'a';
            if (node.children[idx] == null) break;
            node = node.children[idx];
            if (node.isEnd) {
                String word = s.substring(start, end + 1);
                for (var rest : dfs(end + 1)) {
                    result.add(rest.isEmpty() ? word : word + " " + rest);
                }
            }
        }
        memo.put(start, result);
        return result;
    }

    public static void main(String[] args) {
        var sol = new Solution140();
        var r1 = sol.wordBreak("catsanddog", List.of("cat","cats","and","sand","dog"));
        var expected1 = new HashSet<>(List.of("cats and dog","cat sand dog"));
        if (!new HashSet<>(r1).equals(expected1)) throw new AssertionError("LC140 t1: got " + r1);

        var r2 = sol.wordBreak("pineapplepenapple",
            List.of("apple","pen","applepen","pine","pineapple"));
        var expected2 = new HashSet<>(List.of(
            "pine apple pen apple","pineapple pen apple","pine applepen apple"));
        if (!new HashSet<>(r2).equals(expected2)) throw new AssertionError("LC140 t2: got " + r2);

        var r3 = sol.wordBreak("catsandog", List.of("cats","dog","sand","and","cat"));
        if (!r3.isEmpty()) throw new AssertionError("LC140 t3 should be empty: got " + r3);
    }
}
```

**Complexity.** O(n² × L) time (memoised), O(n × L + output size) space. Without memoisation the
worst case is exponential — the trie keeps the per-step work to O(L) instead of O(W × n).

---

## LC421. Maximum XOR of Two Numbers in an Array

**Key insight:** Build a **binary trie** where each number is stored bit by bit from bit 30 down
to bit 0. For each number `x`, greedily walk the trie choosing the child that would flip each bit
of `x` (i.e., try the opposite bit first). This maximises XOR bit by bit.

```java
class Solution421 {
    static class Node {
        Node[] children = new Node[2]; // children[0] = bit 0, children[1] = bit 1
    }

    private final Node root = new Node();

    private void insert(int num) {
        var node = root;
        for (int i = 30; i >= 0; i--) {
            int bit = (num >> i) & 1;
            if (node.children[bit] == null) node.children[bit] = new Node();
            node = node.children[bit];
        }
    }

    private int maxXor(int num) {
        var node = root;
        int result = 0;
        for (int i = 30; i >= 0; i--) {
            int bit = (num >> i) & 1;
            int want = 1 - bit; // prefer flipping this bit to maximise XOR
            if (node.children[want] != null) {
                result |= (1 << i);
                node = node.children[want];
            } else {
                node = node.children[bit];
            }
        }
        return result;
    }

    public int findMaximumXOR(int[] nums) {
        for (int n : nums) insert(n);
        int max = 0;
        for (int n : nums) max = Math.max(max, maxXor(n));
        return max;
    }

    public static void main(String[] args) {
        var s = new Solution421();
        int r1 = s.findMaximumXOR(new int[]{3,10,5,25,2,8});
        if (r1 != 28) throw new AssertionError("LC421 t1: got " + r1);
        var s2 = new Solution421();
        int r2 = s2.findMaximumXOR(new int[]{14,70,53,83,49,91,36,80,92,51,66,70});
        if (r2 != 127) throw new AssertionError("LC421 t2: got " + r2);
    }
}
```

**Complexity.** O(n × 31) = O(n) build and query. Space O(n × 31) = O(n).

> **Java vs Rust:** The binary trie `Node[] children = new Node[2]` maps to Rust's
> `[Option<Box<Node>>; 2]`. Both index by the bit value 0 or 1. Java `Integer.numberOfLeadingZeros`
> can determine the actual highest bit, but starting at bit 30 (covers all `int` values ≤ 10^9)
> is simpler and correct for the given constraints.

---

## LC336. Palindrome Pairs

**Key insight:** For words `a` and `b`, `a + b` is a palindrome when:
1. `rev(b)` is a prefix of `a` and the remainder `a[len(b)..]` is itself a palindrome.
2. `rev(a)` is a suffix of `b` and the remainder `b[..len(b)-len(a)]` is itself a palindrome.

Build a trie of **reversed words**. For each word `w`, walk the reversed-word trie to find
matches via two passes:
- Walk `w` through the reversed-word trie: if you hit a word end at position `k`, the suffix
  `w[k..]` must be a palindrome → pair `(i, j)` where `j` is that trie word's index.
- Walk `rev(w)` through the reversed-word trie: if you consume all of `rev(w)` and still have
  trie depth left, any word-end node below where the remaining suffix is a palindrome gives a
  valid pair.

```java
import java.util.*;

class Solution336 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        int wordIdx = -1;          // index in words[], -1 if not a terminal
        List<Integer> palindromeSuffixIndices = new ArrayList<>();
        // indices of words stored in this subtree where the remaining trie path is a palindrome
    }

    private final TrieNode root = new TrieNode();

    private void insert(String word, int idx) {
        var node = root;
        // Insert reversed word
        for (int i = word.length() - 1; i >= 0; i--) {
            // Before moving, check if the remaining suffix word[0..i] is a palindrome
            if (isPalindrome(word, 0, i)) node.palindromeSuffixIndices.add(idx);
            int c = word.charAt(i) - 'a';
            if (node.children[c] == null) node.children[c] = new TrieNode();
            node = node.children[c];
        }
        node.wordIdx = idx;
        node.palindromeSuffixIndices.add(idx); // empty suffix "" is trivially a palindrome
    }

    private boolean isPalindrome(String s, int lo, int hi) {
        while (lo < hi) {
            if (s.charAt(lo++) != s.charAt(hi--)) return false;
        }
        return true;
    }

    public List<List<Integer>> palindromePairs(String[] words) {
        for (int i = 0; i < words.length; i++) insert(words[i], i);
        var result = new ArrayList<List<Integer>>();
        for (int i = 0; i < words.length; i++) {
            var word = words[i];
            var node = root;
            // Walk word[0..] through trie of reversed words
            for (int j = 0; j < word.length(); j++) {
                // Case 1: trie word ends here (node.wordIdx != -1), prefix consumed = reversed[0..j-1]
                // Remaining word[j..] must be a palindrome
                if (node.wordIdx != -1 && node.wordIdx != i
                        && isPalindrome(word, j, word.length() - 1)) {
                    result.add(List.of(i, node.wordIdx));
                }
                int c = word.charAt(j) - 'a';
                if (node.children[c] == null) { node = null; break; }
                node = node.children[c];
            }
            // Case 2: exhausted word, still in trie — any word-end below whose remaining path is palindrome
            if (node != null) {
                for (int k : node.palindromeSuffixIndices) {
                    if (k != i) result.add(List.of(i, k));
                }
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution336();
        var r1 = s.palindromePairs(new String[]{"abcd","dcba","lls","s","sssll"});
        var set1 = new HashSet<List<Integer>>();
        for (var p : r1) set1.add(p);
        if (!set1.contains(List.of(0,1))) throw new AssertionError("LC336 t1 missing [0,1]");
        if (!set1.contains(List.of(1,0))) throw new AssertionError("LC336 t1 missing [1,0]");
        if (!set1.contains(List.of(3,2))) throw new AssertionError("LC336 t1 missing [3,2]");
        if (!set1.contains(List.of(2,4))) throw new AssertionError("LC336 t1 missing [2,4]");

        var s2 = new Solution336();
        var r2 = s2.palindromePairs(new String[]{"bat","tab","cat"});
        var set2 = new HashSet<List<Integer>>();
        for (var p : r2) set2.add(p);
        if (!set2.contains(List.of(0,1))) throw new AssertionError("LC336 t2 missing [0,1]");
        if (!set2.contains(List.of(1,0))) throw new AssertionError("LC336 t2 missing [1,0]");
    }
}
```

**Complexity.** O(n × L²) — for each word (n), walk trie (L), and call `isPalindrome` (L).
Space O(n × L) for trie + O(n × L) for `palindromeSuffixIndices` lists in the worst case.

> **Java vs Rust:** This is one of the hardest trie problems. The approach is language-agnostic;
> the only Java-specific note is that `List<Integer>` inside `TrieNode` is a heap-allocated
> `ArrayList` grown on demand, while Rust would use `Vec<usize>` similarly.

---

## LC1032. Stream of Characters

**Key insight:** Build a trie of the **reversed** dictionary words. Maintain a history buffer of
recently seen characters. On each `query(letter)`, prepend the letter to the buffer and walk the
reversed-word trie to see if any suffix of the buffer matches a dictionary word.

Use `ArrayDeque<Character>` as the buffer (prepend by pushing to front). Walk from the most
recent character backward through the buffer, matching against the reversed trie.

```java
import java.util.*;

class Solution1032 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private final TrieNode root = new TrieNode();
    private final ArrayDeque<Character> buffer = new ArrayDeque<>();

    public Solution1032(String[] words) {
        for (var w : words) {
            var node = root;
            // Insert reversed word
            for (int i = w.length() - 1; i >= 0; i--) {
                int idx = w.charAt(i) - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.isEnd = true;
        }
    }

    public boolean query(char letter) {
        buffer.addFirst(letter); // prepend newest character
        var node = root;
        // Walk buffer from newest to oldest (front to back), matching reversed trie
        for (char c : buffer) {
            int idx = c - 'a';
            if (node.children[idx] == null) return false;
            node = node.children[idx];
            if (node.isEnd) return true;
        }
        return false;
    }

    public static void main(String[] args) {
        var stream = new Solution1032(new String[]{"cd","f","kl"});
        boolean[] results = new boolean[9];
        char[] letters = {'a','b','c','d','e','f','g','h','i'};
        for (int i = 0; i < letters.length; i++) results[i] = stream.query(letters[i]);
        // After queries a,b,c,d the buffer is [d,c,b,a] front-to-back.
        // "cd" reversed is "dc"; trie walk: d->c hits isEnd. So query('d') returns true.
        // query('f') also returns true since "f" reversed is "f" and matches immediately.
        if (!results[3]) throw new AssertionError("LC1032 'cd' match at index 3: got false");
        if (!results[5]) throw new AssertionError("LC1032 'f' match at index 5: got false");
        if (results[0] || results[1] || results[2] || results[4] || results[6] || results[7] || results[8])
            throw new AssertionError("LC1032 unexpected true in non-match positions");
    }
}
```

**Complexity.** `query` O(L) per call where L = max word length (buffer walk stops at trie dead
end or max-word-depth). Space O(W × L) for trie + O(L) for buffer.

> **Java vs Rust:** `ArrayDeque<Character>` with `addFirst` is the Java idiom for a deque used
> as a prepend buffer. Rust uses `VecDeque::push_front`. Both are O(1) amortised. Iterating the
> `ArrayDeque` in Java goes front-to-back (newest-to-oldest here), matching the reversed-trie walk.

---

## LC676. Implement Magic Dictionary

**Key insight:** For `search(searchWord)`, check if any dictionary word differs from `searchWord`
in exactly one character position. Store dictionary words in a trie. DFS on the trie with a
"mistake counter" (allowed = 1 mistake). At each node, if the current character matches, recurse
with the same mistake budget; if it doesn't and budget > 0, recurse as if it matched (using the
mistake). Accept only when the budget is exactly 0 and `isEnd` is true.

```java
import java.util.*;

class Solution676 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private final TrieNode root = new TrieNode();

    public void buildDict(String[] dictionary) {
        for (var w : dictionary) {
            var node = root;
            for (char c : w.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
            }
            node.isEnd = true;
        }
    }

    public boolean search(String searchWord) {
        return dfs(root, searchWord, 0, 1);
    }

    private boolean dfs(TrieNode node, String word, int pos, int mistakes) {
        if (pos == word.length()) return mistakes == 0 && node.isEnd;
        int c = word.charAt(pos) - 'a';
        for (int i = 0; i < 26; i++) {
            if (node.children[i] == null) continue;
            int usedMistake = (i == c) ? 0 : 1;
            if (mistakes - usedMistake >= 0) {
                if (dfs(node.children[i], word, pos + 1, mistakes - usedMistake)) return true;
            }
        }
        return false;
    }

    public static void main(String[] args) {
        var obj = new Solution676();
        obj.buildDict(new String[]{"hello","hallo","leetcode"});
        boolean r1 = obj.search("hello");
        // "hallo" differs from "hello" by exactly 1 char → true
        if (!r1) throw new AssertionError("LC676 'hello': expected true ('hallo' differs by 1 char)");
        boolean r2 = obj.search("hhllo");
        if (!r2) throw new AssertionError("LC676 'hhllo': expected true");
        boolean r3 = obj.search("hell");
        if (r3) throw new AssertionError("LC676 'hell' too short: expected false");
        boolean r4 = obj.search("leetcoded");
        if (r4) throw new AssertionError("LC676 'leetcoded' too long: expected false");
    }
}
```

**Complexity.** `search` O(26^L) worst case but typically O(L × 26) since the mistake budget
prunes most branches. Build O(W × L). Space O(W × L).

---

## LC386. Lexicographical Numbers

**Key insight:** This is an **implicit trie** (no nodes allocated). Integers `1..n` form the
leaves of a 10-ary trie rooted at `0` with edges labelled `0..9`. A pre-order DFS on this
implicit trie visits numbers in lexicographic order. From current number `curr`, try to go deeper
(`curr × 10`); if not possible, go to sibling (`curr + 1`), possibly backing up to the parent.

```java
import java.util.*;

class Solution386 {
    public List<Integer> lexicalOrder(int n) {
        var result = new ArrayList<Integer>(n);
        int curr = 1;
        while (result.size() < n) {
            result.add(curr);
            if (curr * 10 <= n) {
                curr *= 10; // go deeper: first child
            } else {
                // Go to sibling, backing up as needed
                while (curr % 10 == 9 || curr + 1 > n) curr /= 10;
                curr++;
            }
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution386();
        var r1 = s.lexicalOrder(13);
        var expected1 = List.of(1,10,11,12,13,2,3,4,5,6,7,8,9);
        if (!r1.equals(expected1)) throw new AssertionError("LC386 t1: got " + r1);
        var r2 = s.lexicalOrder(2);
        if (!r2.equals(List.of(1,2))) throw new AssertionError("LC386 t2: got " + r2);
    }
}
```

**Complexity.** O(n) time (visit each number once), O(n) space for output. O(1) extra space
(no trie allocated).

> **Java vs Rust:** Rust would use the same iterative logic. The key insight — treating integers
> as an implicit trie — is identical in both languages. No ownership concerns since no nodes
> are allocated.

---

## LC440. K-th Smallest in Lexicographical Order

**Key insight:** Same implicit 10-ary trie as LC 386. The trick is to count how many numbers in
`[1..n]` fall in the subtree rooted at `curr` (i.e., have `curr` as a prefix) in O(log n) time.
Walk from `curr` to `curr+1` across sibling subtrees, accumulating counts; when the remaining
`k` falls within the current subtree, go one level deeper.

```java
class Solution440 {
    // Count numbers in [curr, curr+1) range that are <= n (nodes in curr's subtree)
    private long countInRange(long n, long curr) {
        long count = 0;
        long next = curr + 1; // sibling prefix
        while (curr <= n) {
            count += Math.min(n + 1, next) - curr;
            curr *= 10;
            next *= 10;
        }
        return count;
    }

    public int findKthNumber(int n, int k) {
        int curr = 1;
        k--; // we've "visited" curr=1 already
        while (k > 0) {
            long count = countInRange(n, curr);
            if (count <= k) {
                // Skip this subtree entirely; move to sibling
                k -= count;
                curr++;
            } else {
                // k-th number is inside curr's subtree; go deeper
                k--;
                curr *= 10;
            }
        }
        return curr;
    }

    public static void main(String[] args) {
        var s = new Solution440();
        int r1 = s.findKthNumber(13, 2);
        if (r1 != 10) throw new AssertionError("LC440 t1: got " + r1);
        int r2 = s.findKthNumber(1, 1);
        if (r2 != 1) throw new AssertionError("LC440 t2: got " + r2);
        int r3 = s.findKthNumber(100, 10);
        if (r3 != 17) throw new AssertionError("LC440 t3 n=100,k=10: got " + r3);
    }
}
```

**Complexity.** O(log²n) — outer while runs at most O(10 × log n) iterations (lexicographic
range), each `countInRange` is O(log n). Space O(1).

> **Java vs Rust:** `long` arithmetic is essential — `curr * 10` for `n = 10^9` reaches 10^10
> which overflows `int`. In Rust you would use `i64` or `u64` explicitly; Java's `long` covers
> this automatically once declared.

---

## LC472. Concatenated Words

**Key insight:** Sort words by length. For each word, check whether it can be formed by
concatenating two or more shorter words already processed. Re-use the Word Break (LC 139) DP
with the trie built so far (shorter words only).

```java
import java.util.*;

class Solution472 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        boolean isEnd;
    }

    private boolean canForm(String word, TrieNode root) {
        int n = word.length();
        if (n == 0) return false;
        var dp = new boolean[n + 1];
        dp[0] = true;
        for (int i = 0; i < n; i++) {
            if (!dp[i]) continue;
            var node = root;
            for (int j = i; j < n; j++) {
                int idx = word.charAt(j) - 'a';
                if (node.children[idx] == null) break;
                node = node.children[idx];
                if (node.isEnd && (j + 1 < n || i > 0)) dp[j + 1] = true;
            }
        }
        return dp[n];
    }

    private void insert(String word, TrieNode root) {
        var node = root;
        for (char c : word.toCharArray()) {
            int idx = c - 'a';
            if (node.children[idx] == null) node.children[idx] = new TrieNode();
            node = node.children[idx];
        }
        node.isEnd = true;
    }

    public List<String> findAllConcatenatedWordsInADict(String[] words) {
        Arrays.sort(words, Comparator.comparingInt(String::length));
        var root = new TrieNode();
        var result = new ArrayList<String>();
        for (var word : words) {
            if (word.isEmpty()) continue;
            if (canForm(word, root)) result.add(word);
            else insert(word, root); // only add if not itself a concatenation
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution472();
        var r1 = s.findAllConcatenatedWordsInADict(
            new String[]{"cat","cats","catsdogcats","dog","dogcatsdog","hippopotamuses","rat","ratcatdogcat"});
        var expected1 = new HashSet<>(List.of("catsdogcats","dogcatsdog","ratcatdogcat"));
        if (!new HashSet<>(r1).equals(expected1)) throw new AssertionError("LC472 t1: got " + r1);
        var r2 = s.findAllConcatenatedWordsInADict(new String[]{"cat","dog","catdog"});
        if (!r2.equals(List.of("catdog"))) throw new AssertionError("LC472 t2: got " + r2);
    }
}
```

**Complexity.** O(n log n + n × L²) — sorting + Word Break DP for each word. Space O(n × L) for
trie.

---

## LC1178. Number of Valid Words for Each Puzzle

**Key insight:** A word is valid for a puzzle if the word contains the puzzle's first character
AND all characters of the word are a subset of the puzzle's characters. Encode each word as a
bitmask of letters present. For each puzzle, enumerate all subsets of the puzzle's 7 letters
(at most 2^7 = 128 subsets) that include the first letter; count how many word-bitmasks equal
each subset.

```java
import java.util.*;

class Solution1178 {
    public List<Integer> findNumOfValidWords(String[] words, String[] puzzles) {
        // Count frequency of each word bitmask
        var freq = new HashMap<Integer, Integer>();
        for (var w : words) {
            int mask = 0;
            for (char c : w.toCharArray()) mask |= 1 << (c - 'a');
            freq.merge(mask, 1, Integer::sum);
        }

        var result = new ArrayList<Integer>(puzzles.length);
        for (var puzzle : puzzles) {
            int puzzleMask = 0;
            for (char c : puzzle.toCharArray()) puzzleMask |= 1 << (c - 'a');
            int firstBit = 1 << (puzzle.charAt(0) - 'a');

            int count = 0;
            // Enumerate all subsets of puzzleMask that include firstBit
            for (int sub = puzzleMask; sub > 0; sub = (sub - 1) & puzzleMask) {
                if ((sub & firstBit) != 0) {
                    count += freq.getOrDefault(sub, 0);
                }
            }
            result.add(count);
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution1178();
        // All puzzles are exactly 7 chars (LeetCode constraint)
        var r1 = s.findNumOfValidWords(
            new String[]{"aaaa","asas","able","ability","actt","actor","access"},
            new String[]{"aboveyz","abrodyz","abslute","befores","cmntxyz","lopekmn","acttbyz"});
        var expected1 = List.of(1,1,3,0,0,0,2);
        if (!r1.equals(expected1)) throw new AssertionError("LC1178 t1: got " + r1);
        // LeetCode Example 2
        var r2 = s.findNumOfValidWords(
            new String[]{"apple","pleas","please"},
            new String[]{"aelwxyz","aelpxyz","aelpsxy","saelpxy","xaelpsy"});
        var expected2 = List.of(0,1,3,2,0);
        if (!r2.equals(expected2)) throw new AssertionError("LC1178 t2: got " + r2);
    }
}
```

**Complexity.** O(n × L + m × 2^7) where n = words, L = avg word length, m = puzzles. Space O(n)
for the frequency map. The bitmask subset enumeration trick is the canonical approach — a trie over
sorted unique letters works but is more code for no runtime gain.

> **Java vs Rust:** `freq.merge(mask, 1, Integer::sum)` is idiomatic Java 8+ — Rust uses
> `*freq.entry(mask).or_insert(0) += 1`. The subset enumeration `sub = (sub - 1) & puzzleMask`
> is identical in both languages.

---

## LC2416. Sum of Prefix Scores of Strings

**Key insight:** For each string `s`, its prefix score is the number of other strings in the array
that have `s` as a prefix of themselves. Equivalently, `score(s)` = sum over each prefix `p` of `s`
of (number of strings that have `p` as a prefix).

Build a trie with a `count` field at each node (incremented for every string that passes through).
For each string, walk its path in the trie and sum the `count` values at every node on the path.

```java
import java.util.*;

class Solution2416 {
    static class TrieNode {
        TrieNode[] children = new TrieNode[26];
        int count; // how many inserted words pass through this node
    }

    public int[] sumPrefixScores(String[] words) {
        var root = new TrieNode();
        // Build trie
        for (var w : words) {
            var node = root;
            for (char c : w.toCharArray()) {
                int idx = c - 'a';
                if (node.children[idx] == null) node.children[idx] = new TrieNode();
                node = node.children[idx];
                node.count++;
            }
        }
        // Query
        var result = new int[words.length];
        for (int i = 0; i < words.length; i++) {
            var node = root;
            int score = 0;
            for (char c : words[i].toCharArray()) {
                node = node.children[c - 'a'];
                score += node.count;
            }
            result[i] = score;
        }
        return result;
    }

    public static void main(String[] args) {
        var s = new Solution2416();
        int[] r1 = s.sumPrefixScores(new String[]{"abc","ab","bc","b"});
        int[] e1 = {5,4,3,2};
        for (int i = 0; i < e1.length; i++)
            if (r1[i] != e1[i]) throw new AssertionError("LC2416 t1[" + i + "]: got " + r1[i] + " exp " + e1[i]);
        int[] r2 = s.sumPrefixScores(new String[]{"abcd"});
        int[] e2 = {4};
        if (r2[0] != e2[0]) throw new AssertionError("LC2416 t2: got " + r2[0]);
    }
}
```

**Complexity.** O(n × L) build + O(n × L) query = O(n × L) total. Space O(n × L) for trie.

> **Java vs Rust:** Adding a `count` field to `TrieNode` is the same in both languages. Rust's
> `#[derive(Default)]` initialises `count: usize` to 0 automatically; Java's `int count` in a
> class also defaults to 0. No difference in the algorithm.

---

## Patterns & Tips

### Choosing Your TrieNode Representation

| Scenario | Representation | Trade-off |
|----------|---------------|-----------|
| Lowercase `a-z` only | `TrieNode[26]` array | O(1) lookup, 26 × 8 bytes per node |
| Large/unicode alphabet | `HashMap<Character, TrieNode>` | O(1) avg but more memory per node |
| Binary (XOR problems) | `Node[2]` array | Minimal; bit 0 or 1 as index |
| Need extra data per node | Add fields (`count`, `val`, `word`) | Extend the base `TrieNode` class |

### Common Trie Patterns

**1. Reversed-word trie** (LC 820, 336, 1032): insert words reversed to answer suffix/stream
queries. The reversed trie transforms "does X end with Y?" into "does the trie contain rev(Y)
as a prefix of rev(X)?"

**2. Implicit trie** (LC 386, 440): integers `1..n` form a 10-ary trie on their digit prefixes.
No nodes allocated — navigate with `curr * 10` (deeper) and `curr + 1` (sibling). Always use
`long` for `curr * 10` when `n` is near `Integer.MAX_VALUE`.

**3. Binary trie for XOR** (LC 421): insert bits from MSB to LSB. Greedy walk choosing opposite
bits maximises XOR. Start from bit 30 (covers all non-negative `int` values within LeetCode
constraints).

**4. Trie + DP** (LC 139, 140, 472): the trie replaces the inner O(W) dictionary scan with an
O(L) walk, making DP transitions faster. The pattern is: for each DP state `i`, walk the trie
from `s[i]`; every `isEnd` node at `j` fires a DP transition to `j`.

**5. Prefix-count trie** (LC 2416): augment each node with a `count` field incremented during
insertion. Summing counts along a word's path computes prefix score in O(L).

### Java-Specific Tips

- Use `ArrayDeque` for BFS (LC 720) and as a buffer (LC 1032) — never `java.util.Stack`.
- Use `PriorityQueue` for top-k problems (LC 692) — min-heap of size k, poll to evict the weakest.
- `HashMap.merge(key, 1, Integer::sum)` is concise for frequency counting.
- For subset enumeration: `for (int sub = mask; sub > 0; sub = (sub - 1) & mask)` visits all
  non-zero subsets of `mask`. Include the check `(sub & requiredBit) != 0` to filter.
- Always use `long` for implicit trie navigation (`curr * 10`) and for XOR bit trie depths
  near `Integer.MAX_VALUE`.

### Rust vs Java Quick Reference

| Concept | Java | Rust |
|---------|------|------|
| Absent child | `node.children[i] == null` | `node.children[i].is_none()` |
| Add child | `node.children[i] = new TrieNode()` | `node.children[i] = Some(Box::new(TrieNode::default()))` |
| Move to child | `node = node.children[i]` (reference copy) | `node = node.children[i].as_mut().unwrap()` |
| Extra node fields | Add field to class | Add field to struct |
| Binary trie | `Node[] children = new Node[2]` | `[Option<Box<Node>>; 2]` |
| Reversed iteration | `for (int i = len-1; i >= 0; i--)` | `word.chars().rev()` |
| Subset enumeration | `sub = (sub-1) & mask` | same (bitwise ops identical) |

### Complexity Summary

| Problem | Time | Space | Key Structure |
|---------|------|-------|---------------|
| LC 14 | O(S) | O(1) | Vertical scan |
| LC 139 | O(n × L) | O(W × L) | Trie + DP |
| LC 648 | O(W × L + S) | O(W × L) | Trie |
| LC 677 | O(L) per op | O(W × L) | Trie + score field |
| LC 692 | O(n log k) | O(n) | PriorityQueue |
| LC 720 | O(W × L) | O(W × L) | Trie + BFS |
| LC 820 | O(W × L) | O(W × L) | Reversed trie |
| LC 1268 | O(W × L) | O(W × L) | Trie + suggestions |
| LC 140 | O(n² × L) | O(n × L) | Trie + memo DFS |
| LC 421 | O(n × 31) | O(n × 31) | Binary trie |
| LC 336 | O(n × L²) | O(n × L) | Reversed trie |
| LC 1032 | O(L) per query | O(W × L) | Reversed trie + deque |
| LC 676 | O(26^L) search | O(W × L) | Trie + DFS budget |
| LC 386 | O(n) | O(1) extra | Implicit trie |
| LC 440 | O(log²n) | O(1) | Implicit trie |
| LC 472 | O(n × L²) | O(n × L) | Trie + DP |
| LC 1178 | O(n×L + m×128) | O(n) | Bitmask frequency |
| LC 2416 | O(n × L) | O(n × L) | Trie + count field |
