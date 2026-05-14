# Chapter 8: Common Collections

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

## 8.1 Vectors (`Vec<T>`)

A `Vec<T>` is Rust's dynamically sized array — the equivalent of Java's `ArrayList<T>`. Elements are stored contiguously in heap memory, and the vector grows automatically when needed.

### Java comparison

| Java | Rust |
|------|------|
| `ArrayList<Integer>` | `Vec<i32>` |
| `list.add(x)` | `v.push(x)` |
| `list.get(i)` | `v[i]` (panics) or `v.get(i)` (returns `Option`) |
| `list.size()` | `v.len()` |
| `new ArrayList<>(32)` | `Vec::with_capacity(32)` |

### 8.1.1 Creating Vectors

```rust
fn main() {
    // Empty vector — type annotation required because there are no values to infer from.
    let mut v1: Vec<i32> = Vec::new();
    v1.push(1);

    // vec! macro — idiomatic for known initial values; Rust infers i32.
    let v2 = vec![1, 2, 3];

    // Pre-allocate capacity to avoid repeated reallocations.
    // Useful when you know the approximate final size.
    let mut v3: Vec<String> = Vec::with_capacity(100);
    v3.push(String::from("hello"));

    println!("v2 has {} elements", v2.len());
    println!("v3 capacity: {}, len: {}", v3.capacity(), v3.len());
}
```

### 8.1.2 push, pop, insert, remove, retain, truncate, clear

```rust
fn main() {
    let mut v = vec![10, 20, 30, 40, 50];

    // push — appends to the end; O(amortized 1).
    v.push(60);

    // pop — removes the last element; returns Option<T>.
    if let Some(last) = v.pop() {
        println!("popped: {last}"); // 60
    }

    // insert(index, value) — shifts elements right; O(n).
    v.insert(1, 99); // [10, 99, 20, 30, 40, 50]

    // remove(index) — shifts elements left; O(n).
    let removed = v.remove(1); // removes 99; back to [10, 20, 30, 40, 50]
    println!("removed: {removed}");

    // retain — keeps only elements matching the predicate.
    v.retain(|&x| x > 20); // [30, 40, 50]
    println!("after retain: {v:?}");

    // truncate — shortens to at most n elements; does not release memory.
    v.truncate(2); // [30, 40]
    println!("after truncate: {v:?}");

    // clear — removes all elements; equivalent to truncate(0).
    v.clear();
    println!("after clear, len: {}", v.len()); // 0
}
```

### 8.1.3 Accessing Elements: Indexing vs. `.get()`

Two ways to read a vector element, with very different failure modes:

```rust
fn main() {
    let v = vec![10, 20, 30, 40, 50];

    // Indexing — returns &T directly but panics on out-of-bounds.
    // Use when an invalid index is a programming bug that should crash.
    let third: &i32 = &v[2];
    println!("third = {third}"); // 30

    // get() — returns Option<&T>; never panics.
    // Use when the index comes from user input or external data.
    match v.get(2) {
        Some(val) => println!("get(2) = {val}"),
        None      => println!("index out of bounds"),
    }

    // Out-of-bounds comparison:
    // &v[100]    → panics at runtime  (thread 'main' panicked: index out of bounds)
    // v.get(100) → returns None       (no panic)
    println!("v.get(100) = {:?}", v.get(100)); // None
}
```

**Why the borrow checker matters here:** holding an immutable reference to a vector element prevents mutation of the vector until the reference is dropped. The following does NOT compile:

```rust
fn main() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];  // immutable borrow
    v.push(4);          // mutable borrow — ERROR
    println!("{first}");
}
// error[E0502]: cannot borrow `v` as mutable because it is also borrowed as immutable
//
// Reason: push() may reallocate heap memory, invalidating `first`.
// The borrow checker catches this at compile time. Java silently returns a stale
// reference after ArrayList resizes — Rust makes this impossible.
```

### 8.1.4 Iterating Over Vectors

```rust
fn main() {
    let mut v = vec![100, 32, 57];

    // Immutable iteration — borrows each element as &i32.
    for x in &v {
        println!("{x}");
    }

    // Mutable iteration — borrows each element as &mut i32.
    // Must dereference to modify the underlying value.
    for x in &mut v {
        *x += 10; // dereference operator (*) required
    }
    println!("after mutation: {v:?}"); // [110, 42, 67]

    // Consuming iteration — moves ownership of each element out of the vector.
    // The vector is no longer usable after this loop.
    let v2 = vec![1, 2, 3];
    for x in v2 {
        println!("consuming: {x}");
    }
    // v2 is dropped here — cannot use it again.
}
```

### 8.1.5 Sorting, dedup, binary_search, contains

```rust
fn main() {
    let mut v = vec![3, 1, 4, 1, 5, 9, 2, 6, 5, 3];

    // sort() — sorts in place using an efficient algorithm (pattern-defeating quicksort).
    v.sort();
    println!("sorted: {v:?}"); // [1, 1, 2, 3, 3, 4, 5, 5, 6, 9]

    // dedup() — removes CONSECUTIVE duplicates only; sort first for all-unique.
    v.dedup();
    println!("deduped: {v:?}"); // [1, 2, 3, 4, 5, 6, 9]

    // binary_search — requires sorted input; returns Ok(index) or Err(insert_pos).
    match v.binary_search(&5) {
        Ok(idx)  => println!("found 5 at index {idx}"),
        Err(pos) => println!("5 not found; would insert at {pos}"),
    }

    // contains — linear scan; no sort requirement.
    println!("contains 3: {}", v.contains(&3)); // true
    println!("contains 7: {}", v.contains(&7)); // false

    // sort_by and sort_by_key for custom ordering.
    let mut words = vec!["banana", "apple", "cherry", "date"];
    words.sort_by_key(|s| s.len()); // sort by string length
    println!("by length: {words:?}"); // ["date", "apple", "banana", "cherry"]
}
```

### 8.1.6 Vec as a Stack

```rust
fn main() {
    let mut stack: Vec<i32> = Vec::new();

    // push = push onto top
    stack.push(1);
    stack.push(2);
    stack.push(3);

    // pop = pop from top; returns Option<T>
    while let Some(top) = stack.pop() {
        println!("popped: {top}"); // 3, 2, 1
    }
}
```

### 8.1.7 Vec as a Queue — and Why VecDeque Is Better

Using `Vec` as a queue works but `remove(0)` is **O(n)** because every element shifts left. For true queue semantics, prefer `std::collections::VecDeque`.

```rust
use std::collections::VecDeque;

fn main() {
    let mut queue: VecDeque<&str> = VecDeque::new();

    // Enqueue at the back.
    queue.push_back("first");
    queue.push_back("second");
    queue.push_back("third");

    // Dequeue from the front — O(1) with VecDeque.
    while let Some(item) = queue.pop_front() {
        println!("dequeued: {item}");
    }
    // Output: first, second, third
}
```

### 8.1.8 Storing Multiple Types with Enums

Vectors are homogeneous — all elements must be the same type. Use an enum when you need to store different types in the same vector:

```rust
fn main() {
    #[derive(Debug)]
    enum Cell {
        Int(i64),
        Float(f64),
        Text(String),
        Empty,
    }

    let row: Vec<Cell> = vec![
        Cell::Int(42),
        Cell::Text(String::from("Rust")),
        Cell::Float(3.14),
        Cell::Empty,
    ];

    for cell in &row {
        match cell {
            Cell::Int(n)   => println!("int:   {n}"),
            Cell::Float(f) => println!("float: {f}"),
            Cell::Text(s)  => println!("text:  {s}"),
            Cell::Empty    => println!("(empty)"),
        }
    }
}
```

This pattern appears in spreadsheet parsers, configuration systems, and SQL result sets — anywhere a "row" has mixed column types.

---

## 8.2 Strings

Rust has two string types. Java developers frequently trip over which one to use and why.

### Java comparison

| Java | Rust | Notes |
|------|------|-------|
| `String` (immutable) | `&str` | Immutable, borrowed view of UTF-8 data |
| `StringBuilder` (mutable) | `String` | Owned, growable UTF-8 string on the heap |
| `String.length()` | `s.len()` | Returns **bytes**, not characters |
| `char` (UTF-16 unit) | `char` | Full Unicode scalar value (U+0000–U+10FFFF) |

**The key insight:** In Java, `String` is immutable but you typically pass it by value with garbage collection managing memory. In Rust, `String` is owned and mutable; `&str` is a borrowed, immutable reference (often a slice into a `String` or a string literal baked into the binary). When a function only needs to read a string, accept `&str` — it works for both `String` and `&str` via deref coercion.

### 8.2.1 Creating and Growing Strings

```rust
fn main() {
    // Empty owned string.
    let mut s1 = String::new();

    // From a string literal — both are equivalent.
    let s2 = String::from("hello");
    let s3 = "hello".to_string();

    // push_str — appends a &str slice; does NOT take ownership of its argument.
    s1.push_str("foo");
    let extra = "bar";
    s1.push_str(extra);
    println!("extra still usable: {extra}"); // "bar" still in scope

    // push — appends a single char.
    s1.push('!');
    println!("s1 = {s1}"); // "foobar!"

    // + operator — calls add(self, &str) -> String.
    // Takes ownership of the left operand; borrows the right.
    let s4 = s2 + " world"; // s2 is moved; s4 owns the result
    // s2 is no longer usable here.
    println!("s4 = {s4}");

    // format! — most readable for multi-part concatenation; borrows all arguments.
    let a = String::from("tic");
    let b = String::from("tac");
    let c = String::from("toe");
    let joined = format!("{a}-{b}-{c}"); // a, b, c still usable after this
    println!("joined = {joined}");
    println!("a = {a}, b = {b}, c = {c}"); // all still valid

    let _ = s3; // suppress unused warning
}
```

### 8.2.2 Why Rust Strings Don't Support Direct Indexing

```rust
fn main() {
    let s = String::from("hello");
    // let h = s[0]; // COMPILE ERROR — not a runtime panic
    // error[E0277]: the type `str` cannot be indexed by `{integer}`
    //
    // Why? String is internally Vec<u8> storing UTF-8. A single byte index does
    // not map reliably to a character. For "Здравствуйте", each Cyrillic letter
    // is 2 bytes — s[0] would return byte 208, not 'З'.
    //
    // Rust forces you to be explicit about whether you want bytes, chars, or graphemes.

    let hello = "Здравствуйте";
    println!("byte length: {}", hello.len()); // 24 (2 bytes per Cyrillic letter)

    // String slicing — uses BYTE indices, not char indices.
    // Valid only if both bounds fall on character boundaries.
    let first_two_chars = &hello[0..4]; // OK: 4 bytes = 2 Cyrillic chars
    println!("first two chars: {first_two_chars}"); // "Зд"

    // &hello[0..1] would PANIC at runtime because byte 1 is not a char boundary.
}
```

### 8.2.3 Iterating Over Strings

```rust
fn main() {
    let s = "नमस्ते"; // Hindi word, 6 Unicode scalar values, 18 bytes

    // chars() — iterates over Unicode scalar values (char).
    // This is usually what you want for "characters".
    print!("chars: ");
    for c in s.chars() {
        print!("{c} "); // न म स ् त े
    }
    println!();

    // bytes() — iterates over raw UTF-8 bytes.
    // Use when working with byte-level protocols.
    let byte_count = s.bytes().count();
    println!("byte count: {byte_count}"); // 18

    // Grapheme clusters (what humans call "letters") require the
    // unicode-segmentation crate — not in std.
    // e.g.: unicode_segmentation::UnicodeSegmentation::graphemes(s, true)
    // gives ["न", "म", "स्", "ते"] — 4 grapheme clusters.
}
```

### 8.2.4 Key String Methods

```rust
fn main() {
    let s = String::from("  Hello, Rustaceans!  ");

    // Trimming
    let trimmed = s.trim();
    println!("trimmed: '{trimmed}'"); // 'Hello, Rustaceans!'
    println!("trim_start: '{}'", s.trim_start()); // 'Hello, Rustaceans!  '
    println!("trim_end: '{}'",   s.trim_end());   // '  Hello, Rustaceans!'

    // Searching
    println!("contains 'Rust': {}", s.contains("Rust"));
    println!("starts_with '  Hello': {}", s.starts_with("  Hello"));
    println!("ends_with '!  ': {}", s.ends_with("!  "));

    // Case conversion
    println!("uppercase: {}", s.to_uppercase());
    println!("lowercase: {}", s.to_lowercase());

    // Replace
    let r = s.replace("Rustaceans", "world");
    println!("replaced: '{r}'");

    // replacen — replace only the first n occurrences.
    let t = "aabbaabb".to_string();
    println!("replacen: {}", t.replacen("aa", "XX", 1)); // "XXbbaabb"

    // split and collect
    let csv = "one,two,three,four";
    let parts: Vec<&str> = csv.split(',').collect();
    println!("parts: {parts:?}");

    // splitn — at most n substrings.
    let two_parts: Vec<&str> = csv.splitn(2, ',').collect();
    println!("splitn(2): {two_parts:?}"); // ["one", "two,three,four"]

    // repeat
    let repeated = "ab".repeat(3);
    println!("repeated: {repeated}"); // "ababab"

    // len and is_empty (len is bytes, not chars)
    let empty = "";
    println!("empty.is_empty(): {}", empty.is_empty()); // true
    println!("'hello'.len(): {}", "hello".len()); // 5
}
```

### 8.2.5 Converting Between String Types

```rust
fn main() {
    // &str → String
    let owned: String = "hello".to_string();
    let owned2: String = String::from("hello");
    let owned3: String = "hello".to_owned(); // equivalent to to_string() for &str

    // String → &str (zero-cost; just borrows the data)
    let s = String::from("world");
    let slice: &str = &s;
    let slice2: &str = s.as_str();

    // Parsing: &str → numeric types.
    // Returns Result<T, E>; the type must be inferred or annotated.
    let n: i32 = "42".parse().expect("not a number");
    let f: f64 = "3.14".parse::<f64>().expect("not a float"); // turbofish syntax

    // Numeric → String
    let back = n.to_string();

    println!("{owned} {owned2} {owned3} {slice} {slice2}");
    println!("{n} {f} {back}");
}
```

---

## 8.3 Hash Maps

`HashMap<K, V>` stores key-value pairs with O(1) average lookup. It is not in the prelude — you must import it explicitly.

### Java comparison

| Java | Rust | Notes |
|------|------|-------|
| `HashMap<K,V>` | `HashMap<K,V>` | Default hasher differs (see below) |
| `TreeMap<K,V>` | `BTreeMap<K,V>` | Keys sorted, O(log n) ops |
| `HashSet<E>` | `HashSet<T>` | Set backed by a hash map |
| `TreeSet<E>` | `BTreeSet<T>` | Sorted set |
| `LinkedHashMap` | *(no std equivalent)* | See `indexmap` crate |
| `map.getOrDefault(k, v)` | `map.get(&k).copied().unwrap_or(v)` | |

**Default hasher:** Rust's `HashMap` uses SipHash, which is DoS-resistant but slower than Java's `Object.hashCode()`-based hashing. For performance-critical code where input is trusted, see `FxHashMap` (from the `rustc-hash` crate) — a drop-in replacement with faster hashing but no DoS protection.

### 8.3.1 Creating Hash Maps

```rust
use std::collections::HashMap;

fn main() {
    // Empty map built with insert calls.
    let mut scores: HashMap<String, u32> = HashMap::new();
    scores.insert(String::from("Alice"), 100);
    scores.insert(String::from("Bob"), 85);

    // From an array of tuples — available since Rust 1.56.
    let map = HashMap::from([
        ("one", 1),
        ("two", 2),
        ("three", 3),
    ]);
    println!("map: {map:?}");

    // From an iterator of (key, value) pairs using collect().
    let teams = vec!["Blue", "Red", "Green"];
    let initial_scores = vec![10u32, 20, 30];
    let team_scores: HashMap<_, _> = teams
        .into_iter()
        .zip(initial_scores.into_iter())
        .collect();
    println!("team scores: {team_scores:?}");
}
```

### 8.3.2 Accessing, Inserting, Removing

```rust
use std::collections::HashMap;

fn main() {
    let mut phonebook: HashMap<String, String> = HashMap::new();
    phonebook.insert(String::from("Alice"), String::from("555-1234"));
    phonebook.insert(String::from("Bob"),   String::from("555-5678"));

    // get — returns Option<&V>; use &key because get takes a borrow.
    let alice_number = phonebook.get("Alice"); // Option<&String>
    println!("Alice: {:?}", alice_number);

    // copied()/cloned() converts Option<&V> to Option<V> for Copy/Clone types.
    // For owned types like String, use cloned() or map(|s| s.clone()).
    let num: Option<String> = phonebook.get("Bob").cloned();
    println!("Bob: {:?}", num);

    // unwrap_or / unwrap_or_else for defaults.
    let carol = phonebook
        .get("Carol")
        .map(|s| s.as_str())
        .unwrap_or("unknown");
    println!("Carol: {carol}");

    // contains_key
    println!("has Alice: {}", phonebook.contains_key("Alice")); // true

    // remove — returns Option<V>
    let removed = phonebook.remove("Bob");
    println!("removed Bob: {:?}", removed);
    println!("len: {}", phonebook.len()); // 1

    // is_empty
    println!("is empty: {}", phonebook.is_empty()); // false
}
```

### 8.3.3 Ownership Rules in Hash Maps

```rust
use std::collections::HashMap;

fn main() {
    let key = String::from("color");
    let val = String::from("blue");

    let mut map = HashMap::new();
    map.insert(key, val);
    // key and val are MOVED into the map — cannot be used here.
    // println!("{key}"); // error: value borrowed after move

    // Copy types (i32, bool, etc.) are copied — originals remain usable.
    let k = 42i32;
    let v = 100i32;
    let mut m2: HashMap<i32, i32> = HashMap::new();
    m2.insert(k, v);
    println!("k = {k}, v = {v}"); // still valid

    // Inserting references: the references must outlive the map.
    let name = String::from("Alice");
    let mut m3: HashMap<&str, u32> = HashMap::new();
    m3.insert(&name, 42); // reference; name must stay alive while m3 exists
    println!("{m3:?}");
}
```

### 8.3.4 The Entry API

The Entry API elegantly handles "insert-if-absent" and "update-or-insert" patterns that require verbose null checks in Java.

```rust
use std::collections::HashMap;

fn main() {
    let mut scores: HashMap<&str, u32> = HashMap::new();

    // or_insert — inserts value only if key is absent; returns &mut V either way.
    scores.entry("Alice").or_insert(50);
    scores.entry("Alice").or_insert(99); // no-op: Alice already exists
    println!("Alice: {}", scores["Alice"]); // 50

    // or_insert_with — takes a closure; only called when the key is absent.
    // Prefer over or_insert(expensive_fn()) to avoid computing the default eagerly.
    scores.entry("Bob").or_insert_with(|| 10 * 3);
    println!("Bob: {}", scores["Bob"]); // 30

    // and_modify — modifies an existing entry before or_insert runs.
    scores
        .entry("Alice")
        .and_modify(|v| *v += 10) // Alice exists: +10
        .or_insert(0);
    println!("Alice after modify: {}", scores["Alice"]); // 60

    // Classic word-frequency pattern using entry.
    let text = "hello world hello rust world hello";
    let mut freq: HashMap<&str, u32> = HashMap::new();
    for word in text.split_whitespace() {
        let count = freq.entry(word).or_insert(0);
        *count += 1; // dereference the &mut u32 to increment
    }
    println!("frequencies: {freq:?}");
}
```

### 8.3.5 Iterating Over a Hash Map

```rust
use std::collections::HashMap;

fn main() {
    let map = HashMap::from([
        ("one",   1u32),
        ("two",   2),
        ("three", 3),
    ]);

    // Iterate over key-value pairs (order is not guaranteed).
    for (k, v) in &map {
        println!("{k} = {v}");
    }

    // Collect just the keys or just the values.
    let mut keys: Vec<&&str> = map.keys().collect();
    keys.sort(); // sort for deterministic output
    println!("keys: {keys:?}");
}
```

### 8.3.6 BTreeMap, HashSet, and BTreeSet

```rust
use std::collections::{BTreeMap, BTreeSet, HashSet};

fn main() {
    // BTreeMap — keys always in sorted order (≈ Java's TreeMap).
    let mut btree: BTreeMap<&str, i32> = BTreeMap::new();
    btree.insert("banana", 3);
    btree.insert("apple",  1);
    btree.insert("cherry", 2);
    for (k, v) in &btree {
        println!("{k}: {v}"); // printed in alphabetical order
    }

    // HashSet — unique values, no ordering (≈ Java's HashSet).
    let mut set: HashSet<i32> = HashSet::new();
    set.insert(1);
    set.insert(2);
    set.insert(2); // duplicate — ignored
    println!("set contains 2: {}", set.contains(&2));
    println!("set len: {}", set.len()); // 2

    // BTreeSet — unique values, sorted order (≈ Java's TreeSet).
    let mut bset: BTreeSet<&str> = BTreeSet::new();
    bset.insert("rust");
    bset.insert("java");
    bset.insert("python");
    for lang in &bset {
        print!("{lang} "); // java python rust (sorted)
    }
    println!();
}
```

---

## 8.4 Practical Examples

### 8.4.1 Word Frequency Counter

```rust
use std::collections::HashMap;

fn word_frequency(text: &str) -> HashMap<String, usize> {
    let mut freq: HashMap<String, usize> = HashMap::new();
    for word in text.split_whitespace() {
        // Normalize: lowercase and strip leading/trailing punctuation.
        let clean: String = word
            .to_lowercase()
            .chars()
            .filter(|c| c.is_alphabetic())
            .collect();
        if !clean.is_empty() {
            *freq.entry(clean).or_insert(0) += 1;
        }
    }
    freq
}

fn main() {
    let text = "To be or not to be, that is the question. To be!";
    let freq = word_frequency(text);

    // Sort by frequency descending for display.
    let mut sorted: Vec<(String, usize)> = freq.into_iter().collect();
    sorted.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));

    println!("Word frequencies:");
    for (word, count) in &sorted {
        println!("  {word}: {count}");
    }
}
```

### 8.4.2 Phone Book — `HashMap<String, Vec<String>>`

A contact can have multiple phone numbers. This demonstrates using `Vec` as the value type in a `HashMap`.

```rust
use std::collections::HashMap;

struct PhoneBook {
    entries: HashMap<String, Vec<String>>,
}

impl PhoneBook {
    fn new() -> Self {
        PhoneBook { entries: HashMap::new() }
    }

    fn add(&mut self, name: &str, number: &str) {
        self.entries
            .entry(name.to_string())
            .or_insert_with(Vec::new)
            .push(number.to_string());
    }

    fn lookup(&self, name: &str) -> Option<&Vec<String>> {
        self.entries.get(name)
    }

    fn remove_contact(&mut self, name: &str) -> bool {
        self.entries.remove(name).is_some()
    }
}

fn main() {
    let mut book = PhoneBook::new();
    book.add("Alice", "555-1234");
    book.add("Alice", "555-9999"); // Alice has two numbers
    book.add("Bob",   "555-5678");

    match book.lookup("Alice") {
        Some(numbers) => println!("Alice: {numbers:?}"),
        None          => println!("Alice not found"),
    }

    book.remove_contact("Bob");
    println!("Bob removed: {}", book.lookup("Bob").is_none());
}
```

### 8.4.3 CSV-Like Row Parser

```rust
fn parse_row(line: &str, delimiter: char) -> Vec<String> {
    line.split(delimiter)
        .map(|field| field.trim().to_string())
        .collect()
}

fn parse_csv(input: &str) -> Vec<Vec<String>> {
    input
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| parse_row(line, ','))
        .collect()
}

fn main() {
    let data = "
name,   age, city
Alice,   30, New York
Bob  ,   25, London
Carol,   35, Tokyo
";

    let rows = parse_csv(data);

    // First row is the header.
    if let Some((header, records)) = rows.split_first() {
        println!("Columns: {header:?}");
        for record in records {
            // Zip headers with values for a named-field view.
            let named: Vec<(&str, &str)> = header
                .iter()
                .map(|h| h.as_str())
                .zip(record.iter().map(|v| v.as_str()))
                .collect();
            println!("{named:?}");
        }
    }
}
```

### 8.4.4 Simple In-Memory Key-Value Store

```rust
use std::collections::HashMap;

pub struct KvStore {
    data: HashMap<String, String>,
}

impl KvStore {
    pub fn new() -> Self {
        KvStore { data: HashMap::new() }
    }

    pub fn set(&mut self, key: impl Into<String>, value: impl Into<String>) {
        self.data.insert(key.into(), value.into());
    }

    pub fn get(&self, key: &str) -> Option<&str> {
        self.data.get(key).map(|s| s.as_str())
    }

    pub fn delete(&mut self, key: &str) -> bool {
        self.data.remove(key).is_some()
    }

    pub fn exists(&self, key: &str) -> bool {
        self.data.contains_key(key)
    }

    pub fn keys(&self) -> Vec<&str> {
        let mut ks: Vec<&str> = self.data.keys().map(|s| s.as_str()).collect();
        ks.sort();
        ks
    }

    pub fn len(&self) -> usize {
        self.data.len()
    }

    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }
}

fn main() {
    let mut store = KvStore::new();
    store.set("host", "localhost");
    store.set("port", "8080");
    store.set("debug", "true");

    println!("host = {:?}", store.get("host"));
    println!("exists 'port': {}", store.exists("port"));
    println!("all keys: {:?}", store.keys());

    store.delete("debug");
    println!("len after delete: {}", store.len()); // 2
    println!("exists 'debug': {}", store.exists("debug")); // false
}
```

### 8.4.5 String Manipulation: Reversing Words and Caesar Cipher

```rust
/// Reverses the order of words in a sentence.
/// "hello world" → "world hello"
fn reverse_words(s: &str) -> String {
    s.split_whitespace()
        .rev()
        .collect::<Vec<&str>>()
        .join(" ")
}

/// Applies a Caesar cipher shift to ASCII alphabetic characters.
/// Preserves case; leaves non-alphabetic characters unchanged.
fn caesar_cipher(text: &str, shift: u8) -> String {
    text.chars()
        .map(|c| {
            if c.is_ascii_alphabetic() {
                let base = if c.is_ascii_uppercase() { b'A' } else { b'a' };
                // Cast to u8, shift within the 26-letter alphabet, cast back to char.
                let shifted = (c as u8 - base + shift) % 26 + base;
                shifted as char
            } else {
                c // leave spaces, punctuation, digits unchanged
            }
        })
        .collect()
}

fn main() {
    // Reversing words
    let sentence = "the quick brown fox";
    println!("original:  {sentence}");
    println!("reversed:  {}", reverse_words(sentence)); // "fox brown quick the"

    // Caesar cipher — shift of 13 is ROT13 (self-inverse).
    let message  = "Hello, World!";
    let encoded  = caesar_cipher(message, 13);
    let decoded  = caesar_cipher(&encoded, 13);
    println!("\noriginal:  {message}");
    println!("ROT13:     {encoded}"); // "Uryyb, Jbeyq!"
    println!("decoded:   {decoded}"); // "Hello, World!"

    // Shift of 3 (classical Caesar).
    let secret = caesar_cipher("Attack at dawn", 3);
    println!("\nshift-3 encoded: {secret}"); // "Dwwdfn dw gdzq"
}
```

---

## 8.5 Common Pitfalls

### Pitfall 1: Indexing a String — Compile Error, Not Runtime Panic

```rust
fn main() {
    let s = String::from("hello");
    // let c = s[0]; // Does NOT compile.
    // error[E0277]: the type `str` cannot be indexed by `{integer}`
    //
    // The RUNTIME panic happens with byte-range slicing on a non-boundary:
    // let bad = &s[0..1]; // panics only if byte 1 is not a char boundary.
    //
    // Correct ways to get the first character:
    let first_char  = s.chars().next();
    let first_byte  = s.bytes().next();
    println!("{first_char:?} {first_byte:?}"); // Some('h') Some(104)
}
```

### Pitfall 2: `dedup()` Only Removes Consecutive Duplicates

```rust
fn main() {
    let mut v = vec![1, 2, 1, 3, 2];

    // Without sorting — dedup only removes adjacent duplicates.
    v.dedup();
    println!("without sort: {v:?}"); // [1, 2, 1, 3, 2] — NOT fully deduped

    let mut v2 = vec![1, 2, 1, 3, 2];
    v2.sort();
    v2.dedup();
    println!("with sort:    {v2:?}"); // [1, 2, 3] — fully deduped
}
```

### Pitfall 3: `binary_search()` Requires a Sorted Vec

```rust
fn main() {
    let unsorted = vec![3, 1, 4, 1, 5, 9];
    // binary_search on unsorted data gives wrong results (undefined behavior in logic).
    // The call doesn't panic, but the answer is meaningless.
    println!("unsorted result: {:?}", unsorted.binary_search(&5)); // could be Err

    let mut sorted = unsorted.clone();
    sorted.sort();
    println!("sorted result: {:?}", sorted.binary_search(&5)); // Ok(some_index)
}
```

### Pitfall 4: HashMap Ownership Moves on Insert

```rust
use std::collections::HashMap;

fn main() {
    let key = String::from("name");
    let val = String::from("Alice");
    let mut map = HashMap::new();
    map.insert(key, val);

    // These are compile errors — key and val were moved into the map:
    // println!("{key}"); // error: value used after move
    // println!("{val}"); // error: value used after move

    // If you need to keep the originals, clone before inserting.
    let key2 = String::from("name2");
    let val2 = String::from("Bob");
    map.insert(key2.clone(), val2.clone());
    println!("key2 = {key2}, val2 = {val2}"); // both still usable
}
```

### Pitfall 5: Mutating a Vec While Holding a Reference to It

```rust
fn main() {
    let mut v = vec![1, 2, 3];
    // Attempting to push while an element reference is live fails to compile:
    // let first = &v[0];
    // v.push(4);           // error[E0502]
    // println!("{first}"); // borrow used here

    // Fix: either drop the reference before mutating, or avoid holding it.
    let first_val = v[0]; // copy the value (i32 is Copy) instead of borrowing
    v.push(4);
    println!("first_val = {first_val}, v = {v:?}");
}
```

### Pitfall 6: Using `Vec::remove(0)` as a Queue

```rust
fn main() {
    // Vec::remove(0) is O(n) — every element shifts left.
    // Fine for small vecs, bad for large ones.
    let mut v = vec![1, 2, 3, 4, 5];
    let front = v.remove(0); // O(n) operation
    println!("front: {front}, remaining: {v:?}");

    // Prefer VecDeque for queue semantics:
    // use std::collections::VecDeque;
    // let mut dq = VecDeque::from([1, 2, 3, 4, 5]);
    // let front = dq.pop_front(); // O(1)
}
```

---

## Quick Reference Card

```
Collections cheat sheet (Rust 2024 edition)
─────────────────────────────────────────────────────────────────
Vec<T>
  Create:     Vec::new()  |  vec![a, b, c]  |  Vec::with_capacity(n)
  Modify:     push(x)  pop()  insert(i, x)  remove(i)  retain(|x| …)
  Access:     v[i]   (panic)  |  v.get(i)   (Option<&T>)
  Iterate:    &v   |  &mut v   |  v  (consuming)
  Ops:        sort()  dedup()  binary_search(&x)  contains(&x)  truncate(n)
  Stack:      push / pop
  Queue:      use VecDeque (pop_front O(1)) — avoid Vec::remove(0)

String / &str
  &str        Borrowed, immutable slice; string literals are &'static str
  String      Owned, growable; lives on the heap
  Create:     String::new()  |  String::from("…")  |  "…".to_string()
  Grow:       push_str(&str)  |  push(char)  |  s + &t  |  format!("…")
  Slice:      &s[byte..byte]  — must be on char boundaries!
  No index:   s[i] does NOT compile; use s.chars().nth(i) for char access
  Chars:      s.chars()  →  Iterator<Item=char>
  Bytes:      s.bytes()  →  Iterator<Item=u8>
  Methods:    trim  starts_with  ends_with  contains  split  replace  repeat
  Convert:    "42".parse::<i32>()  |  42.to_string()  |  s.as_str()

HashMap<K, V>         (use std::collections::HashMap)
  Create:     HashMap::new()  |  HashMap::from([…])  |  iter.collect()
  Modify:     insert(k, v)  remove(&k)  get(&k)  get_mut(&k)
  Entry API:  entry(k).or_insert(v)
              entry(k).or_insert_with(|| …)
              entry(k).and_modify(|v| …).or_insert(v)
  Iterate:    for (k, v) in &map
  Key rules:  String keys are MOVED into the map on insert

BTreeMap  → sorted keys (O log n)   ≈ Java TreeMap
HashSet   → unique elements          ≈ Java HashSet
BTreeSet  → unique + sorted          ≈ Java TreeSet
FxHashMap → faster hashing (rustc-hash crate), no DoS protection
```

---

## 📝 Chapter Review Notes

*The following is a third-person critical review of this chapter, written after drafting, covering fact-checking, code correctness, and completeness.*

### Review Summary

The chapter covers all required topics from the task specification: Vec creation/mutation/iteration/sorting/patterns, String/&str duality, string methods, HashMap creation/access/ownership/entry API, BTreeMap/HashSet/BTreeSet comparisons, FxHashMap mention, and all five practical examples (word frequency counter, phone book, CSV row parser, in-memory KV store, reversing words + Caesar cipher).

### Fact-Check: Vectors

- `Vec::with_capacity(n)` allocates capacity but does not set len; confirmed correct — `len()` would return 0 until elements are pushed.
- `dedup()` operates on consecutive duplicates only; the pitfall section makes this explicit. Confirmed.
- `binary_search()` returns `Ok(index)` if found, `Err(insertion_point)` if not. Both branches shown. Confirmed.
- Mutable reference to vector element prevents `push` from compiling — this is the borrow checker rule, explained with the correct error code (E0502). Confirmed.
- `Vec::remove(0)` is O(n) due to element shifting; VecDeque::pop_front is O(1). Confirmed.

### Fact-Check: Strings

- `s[0]` on a String is a **compile error** (E0277), not a runtime panic. The chapter is precise about this. Correct.
- `&s[0..1]` on a multi-byte character boundary is a **runtime panic**, not a compile error. Correct.
- `chars()` yields Unicode scalar values (`char`), not grapheme clusters. Grapheme clusters require the `unicode-segmentation` crate. Stated accurately.
- `String` is UTF-8 encoded `Vec<u8>` internally; `len()` returns bytes, not characters. Correct.
- `push_str()` takes `&str` and does not take ownership of its argument — demonstrated explicitly with a "still usable after" test. Correct.
- `+` operator on String takes ownership of the left-hand side (moves it into `add(self, &str)`). Chapter warns about this. Correct.
- `to_owned()` on `&str` is equivalent to `to_string()` for string slices. Correct.

### Fact-Check: Hash Maps

- `HashMap::from([…])` syntax is available since Rust 1.56. Confirmed; Rust 2024 edition is well past that.
- `entry().or_insert()` returns `&mut V`; must dereference with `*` to mutate. Shown correctly in the word-frequency example.
- `or_insert_with(|| …)` vs `or_insert(expensive())`: the closure form avoids evaluating the default when the key already exists. Stated correctly.
- Owned `String` keys are moved into the map on `insert`; the original variable is invalid afterward. Confirmed and demonstrated in Pitfall 4.
- `BTreeMap` gives sorted iteration; `HashMap` does not guarantee order. Correct.
- FxHashMap mentioned as a third-party crate (no code example that would fail without adding the dependency). Appropriate scope.

### Fact-Check: Practical Examples

- Word frequency: `chars().filter(|c| c.is_alphabetic()).collect::<String>()` compiles correctly — `collect()` can gather `char` into `String`. Confirmed.
- Caesar cipher: `(c as u8 - base + shift) % 26 + base` arithmetic is correct for ASCII rotation. `shift` is `u8`; no overflow risk for shift values < 26. Confirmed.
- `split_first()` on a `Vec<Vec<String>>` returns `Option<(&Vec<String>, &[Vec<String>])>`. Used correctly with pattern destructuring. Confirmed.
- KvStore: `impl Into<String>` for `set()` parameters allows both `&str` and `String` callers. Correct.

### Issues Table

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 1 | OK | `s[0]` described as compile error (E0277), not runtime panic | Correct distinction |
| 2 | High | Early draft used `or_insert(Vec::new())` — allocates a Vec even when key exists | Fixed: changed to `or_insert_with(Vec::new)` (closure, lazy) |
| 3 | Medium | Caesar cipher initially used `i32` arithmetic — risk of sign issues | Fixed: uses `u8` throughout with `% 26` modular arithmetic |
| 4 | Medium | `dedup()` pitfall initially showed sorted result without explaining WHY sort is needed first | Fixed: explicit "only removes adjacent duplicates" explanation |
| 5 | Low | `split_first()` returns a slice `&[Vec<String>]` for the tail, not `Vec<Vec<String>>` — iteration still works with `for record in records` | Confirmed correct |
| 6 | Low | `HashMap::from([…])` — noted the 1.56 minimum version in review; fine for Rust 2024 target | No issue |
| 7 | OK | `VecDeque` recommendation for queue usage — correct O(1) vs O(n) claim | Correct |
| 8 | Low | Line count: ~980 lines — within the 800–1000 target range | Within budget |
| 9 | OK | All five required practical examples present: word freq, phone book, CSV parser, KV store, string manipulation (reverse + Caesar) | Complete |
| 10 | OK | Java comparisons present in all three major sections (Vec, String, HashMap) with explicit tables | Complete |
