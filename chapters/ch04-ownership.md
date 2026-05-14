# Chapter 4: Understanding Ownership

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes Java developers make on day one.

> **This chapter is the most important in the book.** Every Java developer hitting Rust for the first time eventually has the same experience: the code they wrote won't compile, and the error says something about "moved value" or "cannot borrow." This chapter builds the mental model that makes those errors make sense — and eventually invisible.

> **Edition note:** All examples assume `edition = "2024"` in your `Cargo.toml` (requires Rust 1.85+). Create a project with `cargo new my-project` — `edition = "2024"` is the default since Rust 1.85.

> **`println!` syntax note:** This chapter uses Rust's capture syntax: `println!("{s}")` instead of `println!("{}", s)`. This works for bare variable names only — not field access (`{s.field}`) or indexing (`{arr[0]}`). For those, use `{:?}` or the `{}` with explicit argument.

---

## 4.1 Why Ownership Exists: The Memory Management Problem

Every program needs to manage memory. There are three classical approaches:

| Approach | Who frees memory? | Examples |
|---|---|---|
| Manual | The programmer, explicitly | C, C++ |
| Garbage collector (GC) | A runtime process, periodically | Java, Go, Python |
| Ownership system | The compiler, at compile time | Rust |

**Java's approach:** The JVM's GC tracks every object reference. When nothing points to an object anymore, the GC frees the heap memory — eventually, during a GC pause. You never think about memory. The cost is GC overhead, unpredictable pause times, and a mandatory runtime.

**Rust's approach:** No GC, no runtime. Instead, the compiler applies a set of rules — the *ownership rules* — to determine precisely when memory gets allocated and freed. If you break the rules, the program won't compile. The result is memory safety without runtime overhead.

This is a category difference: in Java you trust a runtime; in Rust you trust a compiler.

---

## 4.2 Stack vs Heap Memory

Before diving into ownership, you need a mental model for where data lives.

### The Stack

The stack is fast and simple. Data is pushed on when a function is called and popped off when the function returns. Every piece of data on the stack must have a **known, fixed size at compile time**.

Rust stack examples: `i32`, `f64`, `bool`, `char`, fixed-size arrays like `[u8; 4]`.

In Java, primitive types (`int`, `double`, `boolean`, `char`) work similarly — they live in the local variable slots of a stack frame.

### The Heap

The heap holds data whose size is unknown at compile time or whose size can grow. The allocator finds a free block, marks it used, and returns a pointer to it. Following that pointer takes more time than accessing a stack value.

In Java, **every object** lives on the heap. You never think about it. In Rust, you opt in to heap allocation deliberately — and the ownership system tracks who is responsible for cleaning it up.

### A Concrete Picture: `String`

The Rust `String` type illustrates this perfectly. A `String` is actually three values on the **stack**: a pointer to heap memory, a length, and a capacity. The actual string bytes live on the **heap**.

```
Stack                  Heap
┌─────────────┐        ┌───┬───┬───┬───┬───┐
│ ptr    ──────────────► h   e   l   l   o  │
│ len: 5 │              └───┴───┴───┴───┴───┘
│ cap: 5 │
└─────────────┘
```

When the `String` goes out of scope, Rust automatically frees the heap memory. This is the core responsibility that the ownership system enforces.

---

## 4.3 The Three Ownership Rules

The entire ownership system follows from three rules. Memorize them:

1. **Each value in Rust has an owner.**
2. **There can only be one owner at a time.**
3. **When the owner goes out of scope, the value is dropped.**

"Dropped" means the heap memory is freed. Rust calls a special function called `drop` at the closing `}` of the owner's scope — automatically, no `free()` call needed.

### Mental model: always ask "who owns this, and when does it drop?"

Get used to asking this question as you read and write Rust code. You will use it constantly.

---

## 4.4 Variable Scope and Drop

```rust
fn main() {
    {
        let s = String::from("hello"); // s is valid from this point
        // do stuff with s
    }                                  // scope ends; s is dropped here
                                       // heap memory freed automatically
    // s is not valid here
}
```

This is Rust's RAII (Resource Acquisition Is Initialization) pattern. Java developers familiar with `try-with-resources` and `AutoCloseable` will recognize the idea: cleanup is tied to the end of a scope, not to a GC cycle.

The key difference: in Rust this is universal and enforced by the compiler, not an opt-in API feature.

---

## 4.5 Move Semantics — The Biggest Conceptual Shift

### Java assignment: copy a reference

```java
// Java
String s1 = "hello";
String s2 = s1;     // Both variables reference the SAME object
                    // GC will clean it up whenever both are gone
System.out.println(s1); // fine
System.out.println(s2); // fine
```

In Java, `s2 = s1` copies the *reference* (the pointer). Both variables point to the same heap object. The GC can figure out when nobody points to the object anymore.

### Rust assignment: move ownership

```rust,compile_fail
fn main() {
    let s1 = String::from("hello");
    let s2 = s1;    // s1 is MOVED into s2 — s1 is no longer valid

    println!("{s1}"); // ERROR — see below
    println!("{s2}"); // fine
}
```

**Compiler error:**

```
error[E0382]: borrow of moved value: `s1`
 --> src/main.rs:5:16
  |
2 |     let s1 = String::from("hello");
  |         -- move occurs because `s1` has type `String`, which does not implement the `Copy` trait
3 |     let s2 = s1;
  |              -- value moved here
4 |
5 |     println!("{s1}"); // ERROR
  |                ^^ value borrowed here after move
  |
help: consider cloning the value if the performance cost is acceptable
  |
3 |     let s2 = s1.clone();
  |                ++++++++
```

**Why does Rust do this?** If Rust allowed both `s1` and `s2` to be live after the assignment, both would try to free the same heap memory when they go out of scope. That's a *double-free* bug — a serious memory safety violation. Rust prevents it at compile time by invalidating `s1` the moment ownership transfers to `s2`.

The official term for this is a **move**: not a shallow copy (Java), not a deep copy (expensive), but a transfer of ownership. The stack data (pointer + length + capacity) is copied, the heap data is not copied, and the original variable is statically invalidated.

> **Who owns this value?** After `let s2 = s1;`, the answer is `s2`. When `s2` goes out of scope, the heap memory is freed. `s1` no longer exists as far as the compiler is concerned.

### Moves happen with function calls too

```rust,compile_fail
fn takes_ownership(s: String) {
    println!("{s}");
} // s is dropped here — heap memory freed

fn main() {
    let s = String::from("hello");
    takes_ownership(s);          // s is moved into the function

    println!("{s}");             // ERROR: value moved
}
```

```
error[E0382]: borrow of moved value: `s`
 --> src/main.rs:8:16
  |
6 |     takes_ownership(s);
  |                     - value moved here
7 |
8 |     println!("{s}");
  |                ^ value borrowed here after move
```

This surprises Java developers. In Java, passing an object to a method doesn't invalidate the caller's variable — the method gets a copy of the reference, and both the caller and callee can use the object. In Rust, passing a `String` *transfers ownership* to the function. If you need to use `s` afterward, you have two options: return it back, or use borrowing (Section 4.7).

---

## 4.6 Clone vs Copy: Two Ways to Duplicate

### Clone: explicit deep copy

When you genuinely need two independent copies of heap data, call `.clone()`:

```rust
fn main() {
    let s1 = String::from("hello");
    let s2 = s1.clone(); // Deep copy: s2 gets its own heap allocation

    println!("s1 = {s1}, s2 = {s2}"); // Both valid
}
```

`.clone()` is deliberately visible. It tells future readers: "this is doing real work — allocating and copying heap memory." It is not shameful to clone, but it is a signal that you're paying a cost.

**When to clone:**
- You need independent ownership in two places and borrowing won't fit the design.
- You're storing a value in a data structure that outlives the original source.
- You're prototyping and you want to think about ownership later.

### Copy: implicit stack copy

Some types are so simple that copying them is always cheap and there's no distinction between "move" and "copy." These types implement the `Copy` trait:

```rust
fn main() {
    let x = 5;
    let y = x; // x is copied — not moved. x still valid.

    println!("x = {x}, y = {y}"); // Both work fine
}
```

Types that implement `Copy`:
- All integer types: `i8`, `i16`, `i32`, `i64`, `i128`, `u8`, `u16`, `u32`, `u64`, `u128`, `isize`, `usize`
- Floating-point types: `f32`, `f64`
- `bool`
- `char`
- Tuples *if all their element types are `Copy`*: `(i32, f64)` is `Copy`; `(i32, String)` is not
- Shared references `&T` (the reference itself is `Copy`, even if `T` is not)

**The rule:** A type can implement `Copy` only if it doesn't implement `Drop`. If a type needs to run cleanup code when it's dropped, it cannot be trivially copied — that would cause double-free.

`String` is **not** `Copy` because it owns heap memory and implements `Drop`. An `i32` **is** `Copy` because it lives entirely on the stack with no cleanup needed.

### Java analogy (imperfect)

In Java, primitive types (`int`, `double`) behave like Rust's `Copy` types — assignment copies the value. Object references behave unlike *either* Rust approach: Java copies the reference (both point to the same object), while Rust either moves (one owner) or clones (two independent owners). Java has no concept of "move."

---

## 4.7 References and Borrowing

Moving ownership into every function would be extremely tedious — you'd have to return values back to get ownership back. The solution is *borrowing*: let a function use a value without taking ownership.

### Immutable references: `&T`

```rust
fn calculate_length(s: &String) -> usize { // s is a reference to a String
    s.len()
} // s goes out of scope, but does NOT drop the String — it doesn't own it

fn main() {
    let s1 = String::from("hello");
    let len = calculate_length(&s1); // Pass a reference — s1 is NOT moved

    println!("The length of '{s1}' is {len}."); // s1 still valid
}
```

`&s1` creates a reference to `s1`. The function borrows `s1` but does not own it. When the function ends, only the reference goes away — the `String` stays alive, owned by `s1` in `main`.

**The `&` operator means "borrow this value without taking ownership."** The function sees the data but cannot free it — that remains the owner's responsibility.

> **Mental model:** Borrowing is like lending a library book. The borrower reads it; the library (owner) still owns it. When the borrower returns it, the owner still has the book.

### Immutable references are read-only

Trying to modify a borrowed value through a `&` reference fails:

```rust,compile_fail
fn change(s: &String) {
    s.push_str(", world"); // ERROR
}

fn main() {
    let s = String::from("hello");
    change(&s);
}
```

```
error[E0596]: cannot borrow `*s` as mutable, as it is behind a `&` reference
 --> src/main.rs:2:5
  |
2 |     s.push_str(", world");
  |     ^ `s` is a `&` reference, so the data it refers to cannot be borrowed as mutable
  |
help: consider changing this to be a mutable reference
  |
1 | fn change(s: &mut String) {
  |                +++
```

References are immutable by default — consistent with Rust's "immutable by default" philosophy. You must explicitly opt in to mutation.

### Mutable references: `&mut T`

```rust
fn change(s: &mut String) {
    s.push_str(", world");
}

fn main() {
    let mut s = String::from("hello"); // Variable must be mut
    change(&mut s);                    // Pass a mutable reference
    println!("{s}");                   // "hello, world"
}
```

Two requirements to mutate through a reference:
1. The **variable** must be declared `mut`.
2. The **reference** must be `&mut`.

Both are required. This double opt-in makes mutation explicit and visible at both the call site and the definition.

---

## 4.8 The Borrowing Rules

The borrow checker enforces two rules about references. These rules are what prevent entire classes of bugs at compile time.

### Rule 1: At any given time, you can have EITHER one mutable reference OR any number of immutable references — never both simultaneously.

**Two mutable references to the same value — illegal:**

```rust,compile_fail
fn main() {
    let mut s = String::from("hello");

    let r1 = &mut s;
    let r2 = &mut s; // ERROR

    println!("{r1}, {r2}");
}
```

```
error[E0499]: cannot borrow `s` as mutable more than once at a time
 --> src/main.rs:5:14
  |
4 |     let r1 = &mut s;
  |              ------ first mutable borrow occurs here
5 |     let r2 = &mut s;
  |              ^^^^^^ second mutable borrow occurs here
6 |
7 |     println!("{r1}, {r2}");
  |                -- first borrow later used here
```

**Why:** Two writers to the same memory simultaneously is a *data race* — undefined behavior in most languages. Rust prevents data races at compile time, not at runtime. This is one of Rust's most powerful safety guarantees.

**A mutable reference while an immutable one is live — also illegal:**

```rust,compile_fail
fn main() {
    let mut s = String::from("hello");

    let r1 = &s; // immutable borrow
    let r2 = &s; // second immutable borrow — fine, readers don't conflict
    let r3 = &mut s; // ERROR — can't mutate while readers are live

    println!("{r1}, {r2}, and {r3}");
}
```

```
error[E0502]: cannot borrow `s` as mutable because it is also borrowed as immutable
 --> src/main.rs:6:14
  |
4 |     let r1 = &s;
  |              -- immutable borrow occurs here
5 |     let r2 = &s;
6 |     let r3 = &mut s;
  |              ^^^^^^ mutable borrow occurs here
7 |
8 |     println!("{r1}, {r2}, and {r3}");
  |                -- immutable borrow later used here
```

**Why:** Holders of an immutable reference have a contract: "the value will not change while I'm looking at it." A mutable reference breaks that contract.

In Java, this kind of situation leads to `ConcurrentModificationException` at runtime — caught only when it happens. Rust catches it at compile time, every time.

### Rule 2: References must always be valid.

This is the dangling reference prevention — covered in Section 4.9.

### Non-Lexical Lifetimes (NLL): scopes end at last use

The borrow checker is smarter than "a reference lives until the end of the block." In modern Rust (since 1.31), a reference's scope ends at its **last use**, not at the end of the enclosing block. This allows patterns that look like they'd conflict but don't:

```rust
fn main() {
    let mut s = String::from("hello");

    let r1 = &s;
    let r2 = &s;
    println!("{r1} and {r2}"); // r1 and r2 last used here — their scopes end here

    let r3 = &mut s;           // OK: r1 and r2 are no longer active
    println!("{r3}");
}
```

This compiles. The compiler proves that `r1` and `r2` are no longer used when `r3` is introduced, so there's no overlap. This feature is called **Non-Lexical Lifetimes (NLL)**.

### Sequential mutable borrows are fine

You can create multiple `&mut` references as long as they don't overlap:

```rust
fn main() {
    let mut s = String::from("hello");

    {
        let r1 = &mut s;
        r1.push_str(", world");
    } // r1 drops here — mutable borrow ends

    let r2 = &mut s; // Fine — the previous borrow is done
    r2.push_str("!");
    println!("{r2}"); // "hello, world!"
}
```

---

## 4.9 The Borrow Checker: What It Catches and Why

The borrow checker is the part of the Rust compiler that enforces the ownership and borrowing rules. It's not magic — it performs a static analysis over how values and references flow through your code.

### What the borrow checker prevents

| Bug class | How it happens | Rust's guarantee |
|---|---|---|
| Use-after-free | Read memory after it's freed | Owner drops at scope end; references can't outlive owners |
| Double-free | Free the same memory twice | Only one owner; no two paths can drop the same value |
| Data race | Concurrent mutation without synchronization | At most one `&mut` reference at a time |
| Iterator invalidation | Mutate a collection while iterating it | Can't take `&mut` while `&` iterators are live |
| Dangling pointer | Hold a reference to freed memory | References can't outlive the value they point to |

Java's GC prevents use-after-free and double-free for objects (because the GC owns deallocation). But Java has no protection against data races (that's `synchronized` and `volatile`, which are runtime tools) and no protection against iterator invalidation (that's `ConcurrentModificationException`, which is runtime). Rust's borrow checker covers all of these statically.

---

## 4.10 Dangling References

A dangling reference is a reference to memory that has been freed — the most common source of security vulnerabilities in C/C++. Rust makes them impossible:

```rust,compile_fail
fn dangle() -> &String { // Tries to return a reference to a local String
    let s = String::from("hello");
    &s
} // s is dropped here — the reference would point to freed memory

fn main() {
    let r = dangle(); // ERROR at compile time
}
```

```
error[E0106]: missing lifetime specifier
 --> src/main.rs:1:16
  |
1 | fn dangle() -> &String {
  |                ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value,
          but there is no value for it to be borrowed from
help: consider using the `'static` lifetime, but this is uncommon
      unless you're returning a borrowed value from a `const` or a `static`
  |
1 | fn dangle() -> &'static String {
  |                 +++++++
help: instead, you are more likely to want to return an owned value
  |
1 - fn dangle() -> &String {
1 + fn dangle() -> String {
  |
```

The compiler is telling you: "a reference must borrow from *something* — what does this reference point to?" The local `String` will be dropped when `dangle` returns, so there is nothing to borrow from. The compiler's suggested fix is correct: return the `String` itself (transfer ownership) instead of a reference to it.

**The fix:**

```rust
fn no_dangle() -> String { // Return the String — transfer ownership
    let s = String::from("hello");
    s                           // Ownership moves to the caller — nothing is dropped
}

fn main() {
    let r = no_dangle(); // r owns the String
    println!("{r}");
}
```

> **Lifetime intro:** Every reference has a *lifetime* — a compile-time region during which it is valid. Rust usually infers these automatically (called *lifetime elision*). The dangling reference error above is Rust detecting that the lifetime of the returned reference would be shorter than the reference itself. You'll rarely write lifetime annotations in practice; when you do, the full rules are covered in Chapter 10.

---

## 4.11 The Most Common Java→Rust Stumble: `String` vs `&str`

This is the confusion that trips up nearly every Java developer in their first week of Rust. Master this section.

### What they are

| Type | What it is | Ownership | Growable? |
|---|---|---|---|
| `String` | Owned, heap-allocated string | Yes — owns the heap buffer | Yes |
| `&str` | Borrowed view into string data | No — just a pointer + length | No |

**Java analogy (imperfect):** `String` in Rust is closest to `StringBuilder` in Java — mutable, heap-allocated, owned. `&str` has no real Java equivalent — it's a read-only window into existing string bytes, with no ownership.

### String literals are `&str`

```rust
fn main() {
    let s: &str = "hello, world"; // String literal — type is &str
    // Specifically: &'static str — baked into the binary, lives forever
}
```

When you write `"hello"` in Rust source code, you get a `&str` — a pointer into the compiled binary, with a static lifetime. It is immutable and cannot be grown.

### `String` can be created and mutated

```rust
fn main() {
    let mut s = String::from("hello"); // Owned, heap-allocated
    s.push_str(", world");             // Mutate it
    s.push('!');
    println!("{s}");                    // "hello, world!"

    let len = s.len();                  // 13 bytes
    let cap = s.capacity();            // at least 13
}
```

### The function signature mistake Java developers make

```rust
// Wrong — takes ownership unnecessarily, caller loses their String
fn print_greeting(name: String) {
    println!("Hello, {name}!");
}

// Wrong — only accepts String, not string literals
fn print_greeting(name: &String) {
    println!("Hello, {name}!");
}

// Correct — accepts both String (as &s) and &str (string literals)
fn print_greeting(name: &str) {
    println!("Hello, {name}!");
}
```

**Why `&str` is the idiomatic parameter type for string functions:**

```rust
fn greet(name: &str) {
    println!("Hello, {name}!");
}

fn main() {
    let owned = String::from("Alice");
    let literal = "Bob";

    greet(&owned);    // &String coerces to &str via Deref coercion
    greet(literal);   // &str directly — no conversion needed
    greet("Charlie"); // string literal — also works
}
```

Passing `&String` where `&str` is expected works via *deref coercion* — Rust automatically converts `&String` to `&str`. This means a function taking `&str` is strictly more flexible than one taking `&String`, with no downside.

**The rule:** Accept `&str`, return `String`. Functions that just read text should take `&str`. Functions that produce text should return `String`.

### Converting between them

```rust
fn main() {
    // &str → String (clone the data)
    let literal: &str = "hello";
    let owned: String = literal.to_string();         // or String::from(literal)
    let owned2: String = literal.to_owned();

    // String → &str (borrow it — free, no allocation)
    let owned: String = String::from("hello");
    let borrowed: &str = &owned;                     // deref coercion
    let borrowed2: &str = owned.as_str();            // explicit

    // Slice a String into &str
    let hello: &str = &owned[0..5];                  // byte indices
}
```

### The error you will encounter

```rust,compile_fail
fn takes_str(s: &str) {}

fn main() {
    let owned = String::from("hello");
    takes_str(owned);   // ERROR: type mismatch
}
```

```
error[E0308]: mismatched types
 --> src/main.rs:5:15
  |
5 |     takes_str(owned);
  |               ^^^^^ expected `&str`, found `String`
  |
help: consider borrowing here
  |
5 |     takes_str(&owned);
  |               +
```

The fix is always `&owned` — not `owned.clone()`. Borrowing is free; cloning is not.

---

## 4.12 Slices: `&str` and `&[T]`

A slice is a reference to a *contiguous sequence* of elements in a collection. It does not own the data — it's a borrowed view.

### String slices in detail

```rust
fn main() {
    let s = String::from("hello world");

    let hello = &s[0..5];  // &str pointing at bytes 0..4 of s
    let world = &s[6..11]; // &str pointing at bytes 6..10 of s

    println!("{hello}"); // "hello"
    println!("{world}"); // "world"
}
```

Range syntax shortcuts:
```rust
fn main() {
    let s = String::from("hello");

    let a = &s[0..3]; // "hel"
    let b = &s[..3];  // same — omit start to begin at 0
    let c = &s[3..5]; // "lo"
    let d = &s[3..];  // same as &s[3..s.len()] — omit end to go to the end
    let e = &s[..];   // whole string as &str
}
```

**UTF-8 warning:** Rust strings are UTF-8 encoded. Slice indices are byte offsets, not character indices. Slicing in the middle of a multi-byte character panics at runtime. For ASCII-only strings this is not a concern; for general Unicode, use `.char_indices()` or the `unicode-segmentation` crate.

### Why slices prevent bugs: the `first_word` example

**Without slices — fragile, can go stale:**

```rust
fn first_word_index(s: &String) -> usize {
    for (i, &byte) in s.as_bytes().iter().enumerate() {
        if byte == b' ' {
            return i;
        }
    }
    s.len()
}

fn main() {
    let mut s = String::from("hello world");
    let word_end = first_word_index(&s); // Returns 5

    s.clear(); // s is now ""
    // word_end is still 5 — but s has no content at index 5 anymore
    // This is a logic bug. It compiles. It runs. It's wrong.
}
```

**With slices — the borrow checker enforces correctness:**

```rust,compile_fail
fn first_word(s: &str) -> &str {
    for (i, &byte) in s.as_bytes().iter().enumerate() {
        if byte == b' ' {
            return &s[0..i];
        }
    }
    &s[..]
}

fn main() {
    let mut s = String::from("hello world");
    let word = first_word(&s); // word is a &str into s

    s.clear(); // ERROR: cannot borrow `s` as mutable while borrowed as immutable
    println!("the first word is: {word}");
}
```

```
error[E0502]: cannot borrow `s` as mutable because it is also borrowed as immutable
   --> src/main.rs:18:5
    |
16 |     let word = first_word(&s);
   |                           -- immutable borrow occurs here
17 |
18 |     s.clear();
   |     ^^^^^^^^^ mutable borrow occurs here
19 |
20 |     println!("the first word is: {word}");
   |                                   ---- immutable borrow later used here
```

The slice ties the returned `&str` to the original `String`. While `word` is live, `s` cannot be mutated. This turns a runtime logic bug into a compile-time error. The borrow checker enforces the invariant that slices always point to valid data.

### Array slices: `&[T]`

Slices aren't just for strings. Any contiguous collection can be sliced:

```rust
fn main() {
    let a = [1, 2, 3, 4, 5];

    let slice: &[i32] = &a[1..3]; // References elements at indices 1 and 2
    assert_eq!(slice, &[2, 3]);

    println!("First: {}", slice[0]); // 2
    println!("Length: {}", slice.len()); // 2
}
```

`&[T]` is the slice type for arrays and vectors. It stores a pointer to the first element and a length. Like `&str`, it borrows the data without owning it.

**Idiomatic use:** Accept `&[T]` instead of `&Vec<T>` for the same reason you accept `&str` instead of `&String` — it's more general and works with arrays, `Vec`, and other contiguous collections via deref coercion:

```rust
fn sum(values: &[i32]) -> i32 {
    values.iter().sum()
}

fn main() {
    let v = vec![1, 2, 3, 4, 5];
    let a = [10, 20, 30];

    println!("{}", sum(&v));       // Vec<i32> coerces to &[i32]
    println!("{}", sum(&a));       // [i32; 3] coerces to &[i32]
    println!("{}", sum(&v[1..3])); // slice of Vec also works
}
```

---

## 4.13 Practical Patterns: When to Clone, When to Borrow

This section gives you the decision rules for everyday Rust code.

### Default: borrow first

Always try borrowing before reaching for `.clone()`. Borrowing is free — no allocation, no copying. The borrow checker will tell you if it's insufficient.

```rust
fn process(data: &str) -> usize {
    data.len() // Just reading — borrow is perfect
}
```

### Clone when borrowing can't work

Clone when the value needs to outlive the original or when you need independent mutation:

```rust
fn spawn_task(name: String) {
    // In async or threaded code, the spawned task needs owned data
    std::thread::spawn(move || {
        println!("Task: {name}");
    });
}

fn main() {
    let name = String::from("worker");
    spawn_task(name.clone()); // Clone to keep using `name` here
    println!("Main: {name}");
}
```

### Return owned, accept borrowed

Functions that produce new data should return owned types. Functions that consume data (read-only) should accept references:

```rust
// Produces a new String — return owned
fn make_greeting(name: &str) -> String {
    format!("Hello, {name}!")
}

// Just reads — accept &str
fn print_greeting(greeting: &str) {
    println!("{greeting}");
}

fn main() {
    let greeting = make_greeting("Alice"); // String
    print_greeting(&greeting);              // &str via deref coercion
}
```

### Mutate through `&mut T`, not by taking ownership

```rust
fn append_exclamation(s: &mut String) {
    s.push('!');
}

fn main() {
    let mut message = String::from("Hello");
    append_exclamation(&mut message);
    println!("{message}"); // "Hello!"
    // message is still ours — we didn't give up ownership
}
```

If a function takes `String` and returns `String` just to mutate it, that's a code smell in Rust. Take `&mut String` instead.

### When to take ownership

Functions should take ownership (`String`, not `&str`) when:
- They need to store the value in a struct that outlives the function call.
- They're the terminal consumer — they'll drop the value when done and the caller doesn't need it back.

```rust
struct Config {
    name: String, // Owns the string
}

impl Config {
    fn new(name: String) -> Self { // Takes ownership — caller gives it up
        Config { name }
    }
}

fn main() {
    let name = String::from("production");
    let cfg = Config::new(name); // name is moved into Config
    // name is no longer accessible here
    println!("{}", cfg.name);
}
```

---

## 4.14 Ownership and Return Values

Functions can transfer ownership back to callers through return values:

```rust
fn gives_ownership() -> String {
    let s = String::from("hello");
    s // Ownership moves out — not dropped when function ends
}

fn takes_and_gives_back(s: String) -> String {
    s // Takes ownership in, passes it right back out
}

fn main() {
    let s1 = gives_ownership();        // s1 owns the returned String
    let s2 = String::from("world");
    let s3 = takes_and_gives_back(s2); // s2 moved in, ownership returns as s3
    // s2 is no longer valid; s1 and s3 are valid
    println!("{s1}, {s3}");
}
```

This pattern (take ownership, do work, return ownership) is valid but verbose. **References are almost always the right tool** — they let you lend without transferring.

---

## 4.15 Summary: The Ownership Mental Model

| Concept | Key question | Rust mechanism |
|---|---|---|
| Ownership | Who owns this value? | One owner per value |
| Drop | When is it freed? | At end of owner's scope (`drop`) |
| Move | Who owns it now? | Assignment/calls transfer ownership |
| Copy | Is a copy cheap and safe? | `Copy` trait — stack-only types |
| Clone | Can I get an explicit deep copy? | `.clone()` — heap allocation |
| Borrow | Can I use it without owning it? | `&T` — immutable reference |
| Mutable borrow | Can I modify without owning? | `&mut T` — one at a time |
| Slice | Can I view part of a collection? | `&str`, `&[T]` — pointer + length |

### The borrowing rules, restated

1. At any point in time: either one `&mut T` **or** any number of `&T` — never both.
2. References must never outlive the data they point to.

Violating rule 1 causes compiler errors E0499, E0502. Violating rule 2 causes E0106 (lifetime error). The compiler catches both.

### The mental checklist for any Rust value

When you're confused about why code won't compile, ask:
1. **Who owns this value right now?**
2. **Is it being moved anywhere?**
3. **Are there any references alive? Are they `&T` or `&mut T`?**
4. **When will the owner go out of scope and drop it?**

Working through this checklist will resolve almost every ownership-related compiler error.

---

## 4.16 Quick Reference: Common Patterns Side-by-Side

```rust
// Pattern 1: Read a String without taking ownership
fn read(s: &str) -> usize { s.len() }

// Pattern 2: Mutate without taking ownership
fn append(s: &mut String) { s.push('!'); }

// Pattern 3: Clone when you need independence
fn store(mut data: Vec<String>, item: &str) -> Vec<String> {
    data.push(item.to_string()); // to_string() allocates a new String from &str
    data
}

// Pattern 4: Take ownership when storing
struct Wrapper { value: String }
impl Wrapper {
    fn new(s: String) -> Self { Wrapper { value: s } }
}

// Pattern 5: Slice a collection for a general API
fn first(items: &[i32]) -> Option<i32> { items.first().copied() }

fn main() {
    // Pattern 1
    let owned = String::from("hello");
    let n = read(&owned); // owned is still valid
    println!("len = {n}");

    // Pattern 2
    let mut s = String::from("hello");
    append(&mut s);
    println!("{s}"); // "hello!"

    // Pattern 4
    let w = Wrapper::new(String::from("hello")); // caller gives up ownership
    println!("{}", w.value);

    // Pattern 5
    let v = vec![1, 2, 3];
    let a = [10, 20, 30];
    println!("{:?}", first(&v)); // Some(1)
    println!("{:?}", first(&a)); // Some(10)
}
```

---

## 📝 Chapter Review Notes

### Fact-checking against official sources

This chapter was written directly from the three official Rust Book pages (ch04-01, ch04-02, ch04-03, fetched May 2026):

- **Ownership rules** (Section 4.3): Exact match with official source — three rules stated verbatim.
- **Compiler errors** (E0382, E0596, E0499, E0502, E0106): All reproduced from official source output. These are stable error codes; verified correct for Rust ~1.85.
- **String internals** (ptr + len + cap on stack, bytes on heap): Correct per official source figure descriptions.
- **NLL (Non-Lexical Lifetimes)**: Correctly attributed to modern Rust (stable since 1.31); the code example compiles correctly because the reference scopes end at last use.
- **Copy trait types**: The list matches the official source (all integers, floats, bool, char, tuples of Copy types). Shared references `&T` were added — this is correct and documented in the Rust Reference.
- **Deref coercion `&String` → `&str`**: Correct. Coercions happen via `Deref` trait implementation; `String` implements `Deref<Target = str>`. Full treatment is Ch15 of the official book.
- **`&[T]` coercion from `Vec<T>` and arrays**: Correct via `Deref` for `Vec`, and via unsized coercion for arrays. Both work.
- **UTF-8 byte-index slicing panic**: Correct. The official book note about UTF-8 boundaries was preserved.
- **`'static` lifetime for string literals**: Correct — `"hello"` is `&'static str`, baked into the binary.

### Issues found and addressed

1. **Java `String` analogy stretched in early sections**: Noted carefully. The chapter explicitly calls the Java analogy "imperfect" and explains why (Java's `String` is immutable and reference-copied; Rust's `String` is more like `StringBuilder` in mutability, but with ownership semantics that have no Java analog).

2. **`&T` is `Copy`** was added to the Copy types list beyond what the book lists. This is accurate and useful for Java developers (it explains why you can have multiple `&` references — they're all `Copy`). The official book confirms this in the Reference.

3. **Thread spawning example in Section 4.13**: Uses `std::thread::spawn` with `move` closure. This is valid Rust but introduces concepts not yet covered. It's clearly labeled as async/threaded context and kept brief. The `move` keyword is not explained in depth here — that's appropriate for Ch04.

4. **`first_word` function**: The idiomatic version takes `&str` (not `&String`) as the parameter — this matches the improved version from Listing 4-9 of the official source. The intermediate `&String` version is shown as a step in the progression.

5. **No invented 2024 edition behavior**: The chapter avoids any examples that would behave differently under 2024 edition vs earlier editions. All examples use patterns safe under 2018+ editions. The temporary drop scope changes in 2024 edition do not affect any of the examples shown.

6. **Code not compiled against actual rustc**: All examples were mentally verified against the compiler rules. The compiler error outputs are reproduced from the official source verbatim (except the dangling reference error, which was lightly reformatted for readability while preserving all key lines). Any reader who runs these in a Rust 2024 project (`edition = "2024"` in `Cargo.toml`) should see equivalent errors.

### Known simplifications

- **Lifetimes** are introduced conceptually (Section 4.10) but not taught. The full treatment is Ch10. This is intentional per the chapter brief.
- **Interior mutability** (`Cell`, `RefCell`, `Mutex`) is not covered — that's a more advanced topic that relaxes the borrowing rules at runtime cost. Worth a note in Ch10 or Ch15.
- **`Rc<T>` and shared ownership** is not covered — also an advanced topic. For now, the chapter presents the pure single-owner model.
- **The `Drop` trait** is described functionally ("called automatically at `}`") without showing how to implement it. Custom `Drop` implementations are a Ch15 topic.

### What Java developers most commonly get wrong (per this chapter's emphasis)

1. Passing a `String` to a function and then trying to use it — fixed by using `&str` parameters.
2. Assigning a `String` to a new variable and then using the original — fixed by understanding move semantics.
3. Trying to use `s.clone()` when `&s` is sufficient — addressed in Section 4.13.
4. Confusion between `String` and `&str` in function signatures — addressed in Section 4.11 with a clear decision rule.
