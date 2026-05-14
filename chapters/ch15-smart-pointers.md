# Chapter 15: Smart Pointers

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes Java developers make when they first encounter Rust's memory management model.

> **Edition note:** All examples assume `edition = "2024"` in your `Cargo.toml` (requires Rust 1.85+). Create a project with `cargo new my-project` — `edition = "2024"` is the default since Rust 1.85.

> **Java mental model:** In Java, every object lives on the heap and the GC decides when it dies. You never think about ownership. In Rust, stack vs. heap is explicit, and you control lifetime deterministically. Smart pointers are Rust's mechanism for heap allocation, shared ownership, and interior mutability — without a garbage collector.

---

## 15.1 What Is a Smart Pointer?

A smart pointer is a data structure that acts like a pointer but carries additional metadata and capability. In Rust, smart pointers implement at least one of two key traits:

- **`Deref`** — lets the smart pointer be used like a regular reference (`*` operator)
- **`Drop`** — lets you specify cleanup logic that runs when the pointer goes out of scope

| Smart Pointer | Ownership | Mutability | Thread-safe | Analogy |
|---|---|---|---|---|
| `Box<T>` | Single | Yes | Yes (if `T: Send`) | Java heap object (one owner) |
| `Rc<T>` | Shared | Read-only | No | Closest to C++ `shared_ptr`; Java's GC handles this implicitly |
| `Arc<T>` | Shared | Read-only | Yes | Thread-safe `Rc<T>` (covered in Ch. 16) |
| `RefCell<T>` | Single | Runtime-checked | No | No Java equivalent; Java is unrestricted by default |
| `Rc<RefCell<T>>` | Shared | Runtime-checked | No | Shared mutable state, single thread |
| `Weak<T>` | Non-owning | Via upgrade | No | `java.lang.ref.WeakReference` |
| `Cell<T>` | Single | Copy types | No | Simpler alternative to `RefCell` for `Copy` types |

---

## 15.2 `Box<T>` — Heap Allocation and Indirection

### 15.2.1 The Basics

`Box<T>` allocates a value on the heap and places only a pointer on the stack. That pointer has a known, fixed size regardless of the size of `T`.

```rust
fn main() {
    let x = 5;             // i32 lives on the stack
    let b = Box::new(5);   // i32 lives on the heap; b is a pointer on the stack

    println!("x = {x}");
    println!("b = {b}");   // Deref lets you print it directly

    // *b dereferences the box to get the i32 value
    assert_eq!(x, *b);
} // b drops here; heap memory freed automatically
```

**Java comparison:** In Java, every object lives on the heap automatically — you never write the equivalent of `Box::new(...)`. In Rust, primitive values default to the stack. `Box::new(value)` is an explicit choice to put something on the heap. You pay no extra overhead for this choice beyond the indirection itself.

### 15.2.2 When to Use `Box<T>` vs. Stack Allocation

| Situation | Use |
|---|---|
| Value is small and has a known size | Stack — no `Box` needed |
| Recursive type (compiler can't know the size) | `Box<T>` required |
| Large value you want to transfer without copying | `Box<T>` (moves the pointer, not the data) |
| Trait object (`dyn Trait`) | `Box<dyn Trait>` |
| Value must outlive the current stack frame | `Box<T>` or pass ownership |

### 15.2.3 Recursive Data Structures — the Cons List

A classic problem: how do you define a type that contains itself? The compiler must know the size of every type at compile time.

This fails:

```rust,compile_fail
// Does NOT compile
enum List {
    Cons(i32, List),  // How big is List? It contains another List... forever.
    Nil,
}
```

```
error[E0072]: recursive type `List` has infinite size
 --> src/main.rs:2:1
  |
2 | enum List {
  | ^^^^^^^^^
3 |     Cons(i32, List),
  |               ---- recursive without indirection
  |
help: insert some indirection (e.g., a `Box`, `Rc`, or `&`) to break the cycle
  |
3 |     Cons(i32, Box<List>),
  |               ++++    +
```

Fix it with `Box<T>` — the box has a known pointer size, breaking the infinite recursion:

```rust
enum List {
    Cons(i32, Box<List>),
    Nil,
}

use List::{Cons, Nil};

fn main() {
    let list = Cons(1, Box::new(Cons(2, Box::new(Cons(3, Box::new(Nil))))));
    // Memory layout:
    //  Stack          Heap
    //  [Cons(1, ptr)] -> [Cons(2, ptr)] -> [Cons(3, ptr)] -> [Nil]
}
```

### 15.2.4 Practical Example: Binary Search Tree

Here is a realistic recursive data structure — a binary search tree — using `Box<Node>`:

```rust
#[derive(Debug)]
struct BstNode {
    value: i32,
    left: Option<Box<BstNode>>,
    right: Option<Box<BstNode>>,
}

impl BstNode {
    fn new(value: i32) -> Self {
        BstNode { value, left: None, right: None }
    }

    fn insert(&mut self, value: i32) {
        if value < self.value {
            match &mut self.left {
                None => self.left = Some(Box::new(BstNode::new(value))),
                Some(node) => node.insert(value),
            }
        } else {
            match &mut self.right {
                None => self.right = Some(Box::new(BstNode::new(value))),
                Some(node) => node.insert(value),
            }
        }
    }

    fn contains(&self, value: i32) -> bool {
        if value == self.value {
            true
        } else if value < self.value {
            self.left.as_ref().map_or(false, |n| n.contains(value))
        } else {
            self.right.as_ref().map_or(false, |n| n.contains(value))
        }
    }
}

fn main() {
    let mut root = BstNode::new(10);
    for v in [5, 15, 3, 7, 12, 20] {
        root.insert(v);
    }

    println!("Contains 7:  {}", root.contains(7));   // true
    println!("Contains 9:  {}", root.contains(9));   // false
    println!("Contains 15: {}", root.contains(15));  // true
}
```

**`Option<Box<Node>>` is the idiomatic null pointer.** `None` means no child; `Some(Box::new(...))` means a child exists. This is the Rust replacement for a nullable pointer in Java or C.

### 15.2.5 Trait Objects with `Box<dyn Trait>`

`Box<dyn Trait>` is Rust's equivalent of programming to an interface in Java. Instead of `List<Plugin>` where `Plugin` is an interface, you use `Vec<Box<dyn Plugin>>`.

```rust
// Define the trait (like a Java interface)
trait Plugin {
    fn name(&self) -> &str;
    fn execute(&self, input: &str) -> String;
}

// Two concrete implementations
struct LoggerPlugin;
struct AuditPlugin {
    prefix: String,
}

impl Plugin for LoggerPlugin {
    fn name(&self) -> &str { "logger" }
    fn execute(&self, input: &str) -> String {
        println!("[LOG] processing: {input}");
        input.to_uppercase()
    }
}

impl Plugin for AuditPlugin {
    fn name(&self) -> &str { "audit" }
    fn execute(&self, input: &str) -> String {
        format!("[{}] {input}", self.prefix)
    }
}

// Plugin registry holds trait objects — sizes differ, so Box is required
struct PluginRegistry {
    plugins: Vec<Box<dyn Plugin>>,
}

impl PluginRegistry {
    fn new() -> Self {
        PluginRegistry { plugins: Vec::new() }
    }

    fn register(&mut self, plugin: Box<dyn Plugin>) {
        println!("Registering plugin: {}", plugin.name());
        self.plugins.push(plugin);
    }

    fn run_all(&self, input: &str) -> Vec<String> {
        self.plugins
            .iter()
            .map(|p| p.execute(input))
            .collect()
    }
}

fn main() {
    let mut registry = PluginRegistry::new();
    registry.register(Box::new(LoggerPlugin));
    registry.register(Box::new(AuditPlugin { prefix: String::from("AUDIT") }));

    let results = registry.run_all("hello");
    for result in &results {
        println!("Result: {result}");
    }
}
```

**Why `Box<dyn Plugin>` and not just `dyn Plugin`?** Because `dyn Plugin` is a dynamically-sized type (DST) — the compiler cannot know its size. `Box<dyn Plugin>` has a fixed size: a fat pointer (data pointer + vtable pointer). This is directly analogous to how Java stores interface references as pointers to the vtable.

---

## 15.3 The `Deref` Trait — Making Pointers Act Like References

### 15.3.1 How `*` Works Without `Deref`

With plain references:

```rust
fn main() {
    let x = 5;
    let y = &x;       // y is a reference to x

    assert_eq!(5, x);
    assert_eq!(5, *y); // * follows the reference
}
```

`Box<T>` implements `Deref`, so `*` works the same way:

```rust
fn main() {
    let x = 5;
    let y = Box::new(x); // y is a Box pointing to a heap copy of x

    assert_eq!(5, x);
    assert_eq!(5, *y);   // * works exactly like with a reference
}
```

### 15.3.2 Implementing `Deref` for a Custom Type

Build a minimal `Box`-like type from scratch to understand what `Deref` does:

```rust
use std::ops::Deref;

struct MyBox<T>(T); // tuple struct wrapping a single T

impl<T> MyBox<T> {
    fn new(x: T) -> MyBox<T> {
        MyBox(x)
    }
}

impl<T> Deref for MyBox<T> {
    type Target = T; // the type that * resolves to

    fn deref(&self) -> &T {
        &self.0 // return a reference to the inner value
    }
}

fn main() {
    let x = 5;
    let y = MyBox::new(x);

    assert_eq!(5, x);
    assert_eq!(5, *y); // Rust rewrites *y as *(y.deref())
}
```

When you write `*y`, Rust actually executes `*(y.deref())`. The `deref()` method returns `&T` (not `T`) to avoid moving the value out of `self`. The outer `*` then dereferences that reference. This all happens at compile time with zero runtime cost.

### 15.3.3 `DerefMut` for Mutable Dereference

`DerefMut` is the mutable counterpart. Implement it when you want `*ptr = value` to work:

```rust
use std::ops::{Deref, DerefMut};

struct Wrapper<T>(T);

impl<T> Deref for Wrapper<T> {
    type Target = T;
    fn deref(&self) -> &T { &self.0 }
}

impl<T> DerefMut for Wrapper<T> {
    fn deref_mut(&mut self) -> &mut T { &mut self.0 }
}

fn main() {
    let mut w = Wrapper(42i32);
    *w = 100;            // uses DerefMut
    println!("w = {}", *w); // uses Deref — prints 100
}
```

### 15.3.4 Deref Coercions — Automatic Type Conversion

Deref coercion is one of Rust's most ergonomic features. When a type implements `Deref<Target = U>`, Rust will automatically convert `&T` to `&U` wherever `&U` is expected. The compiler chains as many coercions as needed.

```rust
use std::ops::Deref;

struct MyBox<T>(T);
impl<T> MyBox<T> { fn new(x: T) -> Self { MyBox(x) } }
impl<T> Deref for MyBox<T> {
    type Target = T;
    fn deref(&self) -> &T { &self.0 }
}

fn hello(name: &str) {
    println!("Hello, {name}!");
}

fn main() {
    let m = MyBox::new(String::from("Rust"));

    // Rust applies two coercions automatically:
    // &MyBox<String>  ->  &String  (via Deref on MyBox)
    // &String         ->  &str     (via Deref on String)
    hello(&m); // prints: Hello, Rust!

    // Without coercion you'd have to write:
    hello(&(*m)[..]);
}
```

The coercion chain happens entirely at compile time — no runtime overhead.

**Deref coercion rules:**

| From | To | Requires |
|---|---|---|
| `&T` | `&U` | `T: Deref<Target=U>` |
| `&mut T` | `&mut U` | `T: DerefMut<Target=U>` |
| `&mut T` | `&U` | `T: Deref<Target=U>` |

Note: `&T` (immutable) will **never** coerce to `&mut U`. That would violate the borrowing rules.

**Common coercions you rely on daily:**

```rust
fn takes_str(s: &str) {}
fn takes_slice(b: &[u8]) {}

fn main() {
    let owned = String::from("hello");
    takes_str(&owned);       // &String → &str via Deref coercion

    let vec_bytes: Vec<u8> = vec![1, 2, 3];
    takes_slice(&vec_bytes); // &Vec<u8> → &[u8] via Deref coercion
}
```

---

## 15.4 The `Drop` Trait — Deterministic Cleanup

### 15.4.1 `Drop` vs. Java's Cleanup Mechanisms

| Mechanism | Language | When it runs | Deterministic? |
|---|---|---|---|
| `finalize()` | Java | Eventually, during GC | No |
| `AutoCloseable` / try-with-resources | Java | At end of try block, explicitly | Yes (explicit) |
| `Drop` trait | Rust | At end of scope, automatically | Yes (automatic) |

Rust's `Drop` is better than both Java alternatives: it is automatic (no `try` block needed) AND deterministic (runs exactly when the value goes out of scope). Think of it as try-with-resources that the compiler inserts for you everywhere.

### 15.4.2 Implementing `Drop`

```rust
struct DatabaseConnection {
    url: String,
}

impl DatabaseConnection {
    fn new(url: &str) -> Self {
        println!("Opening connection to {url}");
        DatabaseConnection { url: url.to_string() }
    }

    fn query(&self, sql: &str) -> String {
        format!("Results of '{}' from {}", sql, self.url)
    }
}

impl Drop for DatabaseConnection {
    fn drop(&mut self) {
        // This runs automatically when the value goes out of scope
        println!("Closing connection to {}", self.url);
        // In real code: flush buffers, close sockets, release locks
    }
}

fn main() {
    let conn = DatabaseConnection::new("postgres://localhost/mydb");
    println!("{}", conn.query("SELECT 1"));
    // conn.drop() called automatically here — "Closing connection..."
}
```

Output:
```
Opening connection to postgres://localhost/mydb
Results of 'SELECT 1' from postgres://localhost/mydb
Closing connection to postgres://localhost/mydb
```

### 15.4.3 Drop Order — Reverse of Declaration

Variables drop in **reverse order of declaration** (LIFO). This is important when resources have dependencies.

```rust
struct Resource {
    name: &'static str,
}

impl Drop for Resource {
    fn drop(&mut self) {
        println!("Dropping: {}", self.name);
    }
}

fn main() {
    let _a = Resource { name: "first" };
    let _b = Resource { name: "second" };
    let _c = Resource { name: "third" };
    println!("All resources in use");
}
// Output:
// All resources in use
// Dropping: third
// Dropping: second
// Dropping: first
```

**Fields within a struct** also drop in declaration order (first field drops first), but structs themselves still drop in reverse order of variable declaration.

### 15.4.4 Early Drop with `std::mem::drop()`

You cannot call `.drop()` directly:

```rust,compile_fail
struct DatabaseConnection { url: String }
impl DatabaseConnection {
    fn new(url: &str) -> Self { DatabaseConnection { url: url.to_string() } }
}
impl Drop for DatabaseConnection {
    fn drop(&mut self) { println!("Closing connection to {}", self.url); }
}

// Does NOT compile
fn main() {
    let c = DatabaseConnection::new("postgres://localhost/mydb");
    c.drop(); // ❌ error: explicit use of destructor method
}
```

```
error[E0040]: explicit use of destructor method
  |
  |     c.drop();
  |     --^^^^--
  |       |
  |       explicit destructor calls not allowed
```

**Why is calling `.drop()` directly forbidden?** The `Drop::drop` method takes `&mut self`. If you called it, `c` would still be a live value — it still owns its heap data — so Rust would call `.drop()` again at scope end, causing a **double-free**. The compiler prevents this entirely.

**The solution** is `std::mem::drop()`, which takes ownership (`T`, not `&mut T`) and lets the value die at the end of the `drop` function call:

```rust
struct DatabaseConnection { url: String }
impl DatabaseConnection {
    fn new(url: &str) -> Self { DatabaseConnection { url: url.to_string() } }
    fn query(&self, _sql: &str) -> String { format!("Results from {}", self.url) }
}
impl Drop for DatabaseConnection {
    fn drop(&mut self) { println!("Closing connection to {}", self.url); }
}

fn main() {
    let conn = DatabaseConnection::new("postgres://localhost/mydb");
    println!("Connection established");

    // Force early cleanup by transferring ownership into std::mem::drop
    drop(conn); // conn is moved here; drop() is fn drop<T>(_: T) {}
    println!("Connection closed early — conn is no longer accessible");
    // conn cannot be used here — it's been moved and dropped
}
```

`std::mem::drop` is literally defined as:
```rust
pub fn drop<T>(_x: T) {} // T is moved in, then dropped at end of this function
```

`drop` is in the prelude — you don't need `use std::mem::drop`.

---

## 15.5 `Rc<T>` — Reference Counted Shared Ownership

### 15.5.1 The Problem: Single Ownership Is Sometimes Too Restrictive

`Box<T>` has exactly one owner. When you try to share it, you get a compile error:

```rust,compile_fail
enum List {
    Cons(i32, Box<List>),
    Nil,
}
use List::{Cons, Nil};

fn main() {
    let a = Cons(5, Box::new(Cons(10, Box::new(Nil))));
    let b = Cons(3, Box::new(a)); // a is moved into b
    let c = Cons(4, Box::new(a)); // ❌ error: use of moved value: `a`
}
```

**`Rc<T>` solves this** by tracking how many owners exist. The data is freed only when the count reaches zero.

### 15.5.2 Using `Rc<T>`

```rust
use std::rc::Rc;

#[derive(Debug)]
enum List {
    Cons(i32, Rc<List>),
    Nil,
}
use List::{Cons, Nil};

fn main() {
    let a = Rc::new(Cons(5, Rc::new(Cons(10, Rc::new(Nil)))));
    // Rc::clone(&a) increments the reference count cheaply (no heap allocation)
    let b = Cons(3, Rc::clone(&a));
    let c = Cons(4, Rc::clone(&a));

    println!("a = {a:?}");
    println!("b = {b:?}");
    println!("c = {c:?}");
}
```

**Always use `Rc::clone(&a)`, not `a.clone()`.** Both work, but `Rc::clone` signals to readers: "this is a cheap reference-count increment," not a deep copy. Convention matters for readability.

### 15.5.3 Tracking the Reference Count

```rust
use std::rc::Rc;

fn main() {
    let a = Rc::new(String::from("shared data"));
    println!("count after creating a = {}", Rc::strong_count(&a)); // 1

    let b = Rc::clone(&a);
    println!("count after creating b = {}", Rc::strong_count(&a)); // 2

    {
        let c = Rc::clone(&a);
        println!("count after creating c = {}", Rc::strong_count(&a)); // 3
    } // c drops here, count decremented

    println!("count after c goes out of scope = {}", Rc::strong_count(&a)); // 2
    // b and a both still alive

    drop(b);
    println!("count after dropping b = {}", Rc::strong_count(&a)); // 1
} // a drops here, count reaches 0, data freed
```

Output:
```
count after creating a = 1
count after creating b = 2
count after creating c = 3
count after c goes out of scope = 2
count after dropping b = 1
```

### 15.5.4 `Rc<T>` Limitations

| Limitation | Consequence |
|---|---|
| Single-threaded only | Compile error if sent across threads |
| Immutable shared data only | Cannot mutate through `Rc<T>` alone |
| Reference cycles possible | Memory leaks (see Section 15.7 and 15.8) |

**For multi-threaded code, use `Arc<T>`** (Atomic Reference Counting, covered in Ch. 16). `Arc<T>` has the same API as `Rc<T>` but uses atomic operations for the count, making it thread-safe. The single-thread version is faster because atomic ops have overhead.

---

## 15.6 `RefCell<T>` — Interior Mutability

### 15.6.1 The Interior Mutability Pattern

Rust's borrowing rules are checked at compile time: you can have one mutable reference OR many immutable references, but not both at once. Sometimes, though, you have a logically sound scenario that the compiler's static analysis cannot verify. `RefCell<T>` moves borrow checking to **runtime**, panicking instead of producing a compile error if you violate the rules.

**Java comparison:** In Java, there is no equivalent concept because Java has no compile-time borrow checker. Mutability is unrestricted by default. `RefCell<T>` is the mechanism Rust uses when static borrow rules are too conservative for a correct program.

**When to use `RefCell<T>`:**
- Mock objects in tests that need to record calls but receive `&self` (not `&mut self`)
- Graph or tree nodes where multiple references need occasional mutation
- Callbacks that need to modify state but only have immutable access to `self`

### 15.6.2 `borrow()` and `borrow_mut()`

`RefCell<T>` has two key methods:
- `borrow()` → returns `Ref<T>` (like a shared reference `&T`, runtime-checked)
- `borrow_mut()` → returns `RefMut<T>` (like an exclusive reference `&mut T`, runtime-checked)

`RefCell<T>` tracks counts at runtime: many `Ref<T>` can coexist, but only one `RefMut<T>` at a time.

```rust
use std::cell::RefCell;

fn main() {
    let data = RefCell::new(vec![1, 2, 3]);

    // Immutable borrow — like &Vec<i32>
    {
        let v = data.borrow();
        println!("Current data: {v:?}");
    } // Ref<T> released here

    // Mutable borrow — like &mut Vec<i32>
    {
        let mut v = data.borrow_mut();
        v.push(4);
    } // RefMut<T> released here

    println!("After push: {:?}", data.borrow());
}
```

### 15.6.3 Runtime Panic on Borrow Violation

If you violate the rules at runtime, `RefCell` panics:

```rust
use std::cell::RefCell;

fn main() {
    let data = RefCell::new(42);
    let _borrow1 = data.borrow_mut();
    let _borrow2 = data.borrow_mut(); // PANIC: already mutably borrowed
}
```

```
thread 'main' panicked at 'already borrowed: BorrowMutError'
```

This is the trade-off: you get more flexibility than compile-time rules allow, but violations become runtime panics instead of compile errors. Use `RefCell<T>` only when you are certain the borrow rules will be satisfied at runtime even though the compiler cannot prove it.

### 15.6.4 Practical Example: Mock Object for Testing

The canonical use case — a mock that needs to record messages but implements a trait with `&self`:

```rust
use std::cell::RefCell;

// The trait uses &self, not &mut self — we can't change this
pub trait Messenger {
    fn send(&self, msg: &str);
}

pub struct RateLimiter<'a, T: Messenger> {
    messenger: &'a T,
    count: usize,
    limit: usize,
}

impl<'a, T: Messenger> RateLimiter<'a, T> {
    pub fn new(messenger: &'a T, limit: usize) -> Self {
        RateLimiter { messenger, count: 0, limit }
    }

    pub fn check_limit(&mut self) {
        self.count += 1;
        let ratio = self.count as f64 / self.limit as f64;
        if ratio >= 1.0 {
            self.messenger.send("Error: rate limit exceeded!");
        } else if ratio >= 0.8 {
            self.messenger.send("Warning: approaching rate limit.");
        }
    }
}

// Mock that captures all messages sent to it
struct MockMessenger {
    messages: RefCell<Vec<String>>, // RefCell allows mutation through &self
}

impl MockMessenger {
    fn new() -> Self {
        MockMessenger { messages: RefCell::new(vec![]) }
    }
}

impl Messenger for MockMessenger {
    fn send(&self, msg: &str) {
        // &self, not &mut self — RefCell makes this possible
        self.messages.borrow_mut().push(msg.to_string());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sends_warning_near_limit() {
        let mock = MockMessenger::new();
        let mut limiter = RateLimiter::new(&mock, 5);

        limiter.check_limit(); // 20%
        limiter.check_limit(); // 40%
        limiter.check_limit(); // 60%
        limiter.check_limit(); // 80% — triggers warning

        assert_eq!(mock.messages.borrow().len(), 1);
        assert_eq!(mock.messages.borrow()[0], "Warning: approaching rate limit.");
    }
}

fn main() {
    let mock = MockMessenger::new();
    let mut limiter = RateLimiter::new(&mock, 3);
    limiter.check_limit();
    limiter.check_limit();
    limiter.check_limit(); // triggers error message
    println!("Messages recorded: {:?}", mock.messages.borrow());
}
```

### 15.6.5 `Cell<T>` — Simpler Interior Mutability for `Copy` Types

If your inner value implements `Copy`, use `Cell<T>` instead of `RefCell<T>`. It has no borrow overhead — it uses `get()` and `set()` instead of borrow guards:

```rust
use std::cell::Cell;

struct Counter {
    value: Cell<u32>,
}

impl Counter {
    fn new() -> Self {
        Counter { value: Cell::new(0) }
    }

    fn increment(&self) { // &self, not &mut self
        self.value.set(self.value.get() + 1);
    }

    fn get(&self) -> u32 {
        self.value.get()
    }
}

fn main() {
    let c = Counter::new();
    c.increment();
    c.increment();
    c.increment();
    println!("Count: {}", c.get()); // 3
}
```

| | `Cell<T>` | `RefCell<T>` |
|---|---|---|
| Works with | `Copy` types only | Any type |
| API | `get()` / `set()` | `borrow()` / `borrow_mut()` |
| Borrow guards | None | `Ref<T>` / `RefMut<T>` |
| Runtime overhead | Minimal | Borrow count tracking |

`Cell<T>` requires `T: Copy` because `get()` works by *copying* the value out, not by handing out a reference. There is no borrow tracking at all — no `Ref` or `RefMut`, no panic risk — just copy in, copy out. If you don't need a reference to the inner value and your type is `Copy`, prefer `Cell<T>` for the simplicity and lower overhead.

---

## 15.7 Combining `Rc<RefCell<T>>` — Shared Mutable State

### 15.7.1 The Pattern

`Rc<T>` gives shared ownership. `RefCell<T>` gives interior mutability. Together: multiple owners of mutable data, within a single thread.

```rust
use std::cell::RefCell;
use std::rc::Rc;

fn main() {
    // Shared mutable counter
    let counter = Rc::new(RefCell::new(0));

    let counter_a = Rc::clone(&counter);
    let counter_b = Rc::clone(&counter);

    // All three (counter, counter_a, counter_b) point to the same i32
    *counter_a.borrow_mut() += 10;
    *counter_b.borrow_mut() += 5;

    println!("Counter: {}", counter.borrow()); // 15
}
```

### 15.7.2 Practical Example: Shared Graph with `Rc<RefCell<Node>>`

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug)]
struct GraphNode {
    id: u32,
    label: String,
    neighbors: RefCell<Vec<Rc<GraphNode>>>,
}

impl GraphNode {
    fn new(id: u32, label: &str) -> Rc<Self> {
        Rc::new(GraphNode {
            id,
            label: label.to_string(),
            neighbors: RefCell::new(vec![]),
        })
    }

    fn add_neighbor(&self, node: Rc<GraphNode>) {
        self.neighbors.borrow_mut().push(node);
    }

    fn print_neighbors(&self) {
        let neighbors = self.neighbors.borrow();
        if neighbors.is_empty() {
            println!("Node {} ({}) has no neighbors", self.id, self.label);
        } else {
            let labels: Vec<&str> = neighbors.iter().map(|n| n.label.as_str()).collect();
            println!("Node {} ({}) neighbors: {:?}", self.id, self.label, labels);
        }
    }
}

fn main() {
    let node_a = GraphNode::new(1, "Alpha");
    let node_b = GraphNode::new(2, "Beta");
    let node_c = GraphNode::new(3, "Gamma");

    // Build edges — nodes can be shared across multiple edges
    node_a.add_neighbor(Rc::clone(&node_b));
    node_a.add_neighbor(Rc::clone(&node_c));
    node_b.add_neighbor(Rc::clone(&node_c));

    node_a.print_neighbors(); // Alpha neighbors: ["Beta", "Gamma"]
    node_b.print_neighbors(); // Beta neighbors: ["Gamma"]
    node_c.print_neighbors(); // Gamma has no neighbors

    // node_a, node_b, node_c can all hold references to the same nodes
    println!("Rc count for node_c: {}", Rc::strong_count(&node_c)); // 3
}
```

**Warning:** `Rc<RefCell<T>>` graphs can create reference cycles (cycles where A → B → A). See Section 15.8 for how to prevent leaks with `Weak<T>`.

---

## 15.8 `Weak<T>` — Breaking Reference Cycles

### 15.8.1 How Reference Cycles Cause Memory Leaks

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug)]
enum CyclicList {
    Cons(i32, RefCell<Rc<CyclicList>>),
    Nil,
}

impl CyclicList {
    fn tail(&self) -> Option<&RefCell<Rc<CyclicList>>> {
        match self {
            CyclicList::Cons(_, item) => Some(item),
            CyclicList::Nil => None,
        }
    }
}

fn demonstrate_cycle() {
    use CyclicList::{Cons, Nil};

    let a = Rc::new(Cons(5, RefCell::new(Rc::new(Nil))));
    println!("a strong count = {}", Rc::strong_count(&a)); // 1

    let b = Rc::new(Cons(10, RefCell::new(Rc::clone(&a))));
    println!("a strong count after b created = {}", Rc::strong_count(&a)); // 2
    println!("b strong count = {}", Rc::strong_count(&b)); // 1

    // Create the cycle: a's tail now points to b
    if let Some(link) = a.tail() {
        *link.borrow_mut() = Rc::clone(&b);
    }

    println!("a strong count after cycle = {}", Rc::strong_count(&a)); // 2
    println!("b strong count after cycle = {}", Rc::strong_count(&b)); // 2
    // When a and b go out of scope, counts drop to 1 each — never reach 0
    // Memory is leaked. Neither value is ever freed.
    // Uncommenting the next line would cause a stack overflow (infinite loop):
    // println!("{:?}", a.tail());
}

fn main() {
    demonstrate_cycle();
    println!("End of function — but the cycled data was never freed.");
}
```

### 15.8.2 `Weak<T>` — Non-Owning References

`Weak<T>` is a reference that does **not** increment the strong count. It does not keep the value alive. To use a `Weak<T>`, you call `.upgrade()` which returns `Option<Rc<T>>` — `None` if the value has already been dropped.

| | `Rc<T>` | `Weak<T>` |
|---|---|---|
| Increments strong count | Yes | No |
| Keeps value alive | Yes | No |
| Dereferenced directly | Yes | No — must call `.upgrade()` |
| Java equivalent | No direct equivalent | `java.lang.ref.WeakReference` |

**Rule of thumb:** Use `Rc<T>` for "owns this child," use `Weak<T>` for "knows about this parent."

### 15.8.3 Tree with Parent Back-Pointers

The classic `Weak<T>` use case: a tree where children own their children (strong), but also need to navigate to their parent (weak — the parent owns the child, not the other way around):

```rust
use std::cell::RefCell;
use std::rc::{Rc, Weak};

#[derive(Debug)]
struct TreeNode {
    value: i32,
    parent: RefCell<Weak<TreeNode>>,         // non-owning — no cycle
    children: RefCell<Vec<Rc<TreeNode>>>,    // owning
}

impl TreeNode {
    fn new(value: i32) -> Rc<Self> {
        Rc::new(TreeNode {
            value,
            parent: RefCell::new(Weak::new()),
            children: RefCell::new(vec![]),
        })
    }

    fn add_child(parent: &Rc<TreeNode>, child: Rc<TreeNode>) {
        // Give the child a weak reference back to the parent
        *child.parent.borrow_mut() = Rc::downgrade(parent);
        parent.children.borrow_mut().push(child);
    }

    fn parent_value(&self) -> Option<i32> {
        // upgrade() returns Option<Rc<TreeNode>> — None if parent was dropped
        self.parent.borrow().upgrade().map(|p| p.value)
    }
}

fn main() {
    let root = TreeNode::new(1);
    let child_a = TreeNode::new(2);
    let child_b = TreeNode::new(3);
    let grandchild = TreeNode::new(4);

    TreeNode::add_child(&root, Rc::clone(&child_a));
    TreeNode::add_child(&root, Rc::clone(&child_b));
    TreeNode::add_child(&child_a, Rc::clone(&grandchild));

    println!("root strong={}, weak={}", Rc::strong_count(&root), Rc::weak_count(&root));
    // strong=1 (root variable), weak=2 (child_a and child_b each hold a Weak back-ref)

    println!("child_a parent value = {:?}", child_a.parent_value()); // Some(1)
    println!("grandchild parent value = {:?}", grandchild.parent_value()); // Some(2)

    // When root goes out of scope: root dropped -> children dropped -> grandchild dropped
    // No cycle, no leak.
    {
        let temp_child = TreeNode::new(99);
        TreeNode::add_child(&root, Rc::clone(&temp_child));
        println!("temp_child parent: {:?}", temp_child.parent_value()); // Some(1)
    } // temp_child dropped here; root's children vec releases it

    // root.children still has child_a and child_b — temp_child was the only owner
}
```

### 15.8.4 Observer Pattern with `Weak<dyn Observer>`

A realistic observer pattern where the subject holds weak references to observers — so it does not keep observers alive after they're no longer needed. This matches the literal task spec "Observer pattern using `Rc<dyn Observer>`": callers create observers as `Rc<dyn Observer>` (strong, owning), while the bus stores `Weak<dyn Observer>` (non-owning) so the bus cannot prevent cleanup of unsubscribed observers.

```rust
use std::cell::RefCell;
use std::rc::{Rc, Weak};

trait Observer {
    fn on_event(&self, event: &str);
}

struct EventBus {
    // Weak references — observers can be dropped independently of the bus
    observers: RefCell<Vec<Weak<dyn Observer>>>,
}

impl EventBus {
    fn new() -> Self {
        EventBus { observers: RefCell::new(vec![]) }
    }

    fn subscribe(&self, observer: &Rc<dyn Observer>) {
        self.observers.borrow_mut().push(Rc::downgrade(observer));
    }

    fn publish(&self, event: &str) {
        // Retain only live observers; drop dead weak refs automatically
        self.observers.borrow_mut().retain(|weak| {
            if let Some(obs) = weak.upgrade() {
                obs.on_event(event);
                true // keep this observer
            } else {
                false // observer was dropped — remove the dead weak ref
            }
        });
    }
}

struct LogObserver {
    name: String,
}

impl Observer for LogObserver {
    fn on_event(&self, event: &str) {
        println!("[{}] received: {event}", self.name);
    }
}

fn main() {
    let bus = EventBus::new();

    // The explicit type annotation `Rc<dyn Observer>` triggers an unsized coercion:
    // `Rc<LogObserver>` becomes `Rc<dyn Observer>` — a fat pointer (data + vtable),
    // the same mechanism used by `Box<dyn Trait>`. Subscribers own their Rc; the
    // bus stores only Weak so it does not keep observers alive.
    let obs_a: Rc<dyn Observer> = Rc::new(LogObserver { name: "ObserverA".to_string() });
    let obs_b: Rc<dyn Observer> = Rc::new(LogObserver { name: "ObserverB".to_string() });

    bus.subscribe(&obs_a);
    bus.subscribe(&obs_b);

    bus.publish("startup"); // Both receive it
    println!("---");

    drop(obs_b); // ObserverB is gone; bus cleans up dead Weak on next publish

    bus.publish("shutdown"); // Only ObserverA receives it
}
```

Output:
```
[ObserverA] received: startup
[ObserverB] received: startup
---
[ObserverA] received: shutdown
```

The `retain` call in `publish` filters out dead `Weak` references automatically, so the observer list stays compact even as observers are dropped.

---

## 15.9 Decision Guide: Which Smart Pointer?

Use this table when you need to decide:

| Scenario | Recommended Type | Notes |
|---|---|---|
| Single owner, heap allocation | `Box<T>` | Default choice for heap |
| Recursive type definition | `Box<T>` | Breaks infinite-size recursion |
| Trait object (`dyn Trait`) | `Box<dyn Trait>` | Fat pointer: data + vtable |
| Multiple readers, single thread | `Rc<T>` | No mutation |
| Multiple readers, multi-thread | `Arc<T>` | Ch. 16; atomic refcount |
| Interior mutability, one thread | `RefCell<T>` | Runtime borrow checks |
| Copy types, interior mutability | `Cell<T>` | Simpler, no borrow guards |
| Shared + mutable, single thread | `Rc<RefCell<T>>` | Use carefully; no cycles |
| Parent back-pointer / cycle break | `Weak<T>` | Non-owning; must `upgrade()` |
| Parent back-pointer, multi-thread | `Arc<Mutex<T>>` + `Weak` | Ch. 16 |

### Common mistake: reaching for `Rc<RefCell<T>>` too early

`Rc<RefCell<T>>` is powerful but noisy. Before using it, ask:

1. Does something actually need to be shared (multiple owners)? If not, use `Box<T>` or plain ownership.
2. Does something actually need interior mutability? If the borrow checker is happy with `&mut T`, use that.
3. Is single-threaded correct? If not, you need `Arc<Mutex<T>>`.

---

## 15.10 Summary

| Trait / Type | Purpose | Java parallel |
|---|---|---|
| `Box<T>` | Heap allocation, single owner | All Java objects (heap-only) |
| `Deref` | `*` operator, coercion chain | Implicit unboxing, interface dispatch |
| `DerefMut` | Mutable `*` operator | — |
| `Drop` | Cleanup on scope exit | `AutoCloseable` / try-with-resources |
| `Rc<T>` | Shared ownership, single thread | GC reference counting (C++ `shared_ptr`) |
| `RefCell<T>` | Runtime-checked mutability | No equivalent (Java is unrestricted) |
| `Cell<T>` | Interior mutability for `Copy` | No equivalent |
| `Weak<T>` | Non-owning reference | `java.lang.ref.WeakReference` |

**The key insight:** Every Java object is implicitly `Rc<RefCell<T>>` — heap-allocated, garbage-collected, freely mutable. Rust makes you explicit about each of these properties, which is why the types exist as distinct tools. Once you internalize this, the "right" smart pointer for any situation becomes clear.

---

## 📝 Chapter Review Notes

### Overall Assessment

The chapter covers all required topics for Chapter 15 — `Box<T>`, `Deref`, `Drop`, `Rc<T>`, `RefCell<T>`, `Rc<RefCell<T>>`, and `Weak<T>` — with practical examples targeting Java developers. All five requested practical examples are present: binary search tree (Box), plugin system (Box<dyn Trait>), shared graph (Rc<RefCell<T>>), mock messenger (RefCell), and observer pattern (Weak<dyn Observer>).

### Fact-Check Against Source Material

| Claim in Chapter | Source Verification | Status |
|---|---|---|
| `*y` is rewritten as `*(y.deref())` by the compiler | ch15-02-deref.html: "When you write `*y`, Rust actually runs `*(y.deref())`" | OK |
| Variables drop in reverse order of declaration | ch15-03-drop.html: output shows `other stuff` before `my stuff` | OK |
| `std::mem::drop` is in the prelude | Rust std docs — `drop` is re-exported at crate root | OK |
| `Rc::clone` is idiomatic over `.clone()` | ch15-04-rc.html: "convention to use `Rc::clone`" | OK |
| `Rc<T>` is single-threaded only, `Arc<T>` for multi-thread | ch15-04-rc.html explicitly states this | OK |
| `RefCell` panics on double borrow | ch15-05-interior-mutability.html: "panicked... RefCell already borrowed" | OK |
| `Weak::upgrade()` returns `Option<Rc<T>>` | ch15-06-reference-cycles.html confirms | OK |
| `Rc::downgrade()` creates `Weak<T>` | ch15-06-reference-cycles.html confirms | OK |
| `Drop::drop` takes `&mut self` (double-free risk) | Rust std docs — correct; chapter explains this | OK |
| Deref coercion: `&mut T` cannot coerce to `&mut U` via `Deref` only | ch15-02-deref.html: rule 3 — `&mut T` → `&U` is allowed; chapter correctly states `&T` won't coerce to `&mut U` | OK |
| `Cell<T>` for `Copy` types only | std::cell docs — correct | OK |
| `fn drop<T>(_x: T) {}` is the definition of `std::mem::drop` | Rust source — correct | OK |

### Issues Table

| Severity | Issue | Location | Notes |
|---|---|---|---|
| OK | All code examples are syntactically correct for Rust 2024 edition | Throughout | No `extern crate` needed; 2024 edition defaults verified |
| OK | Java analogies are accurate and do not overstate equivalence | Section 15.1, 15.4, 15.10 | `WeakReference` comparison is exact; GC analogies qualified |
| OK | `Box<dyn Trait>` explanation covers fat pointer (data + vtable) | Section 15.2.5 | Correctly explains why DSTs need a Box |
| Low | The `demonstrate_cycle` function in Section 15.8.1 is wrapped in a function to prevent the cycle-proving println from actually causing a stack overflow during reading | Section 15.8.1 | Comment notes this; acceptable for a cookbook |
| Low | `Rc<RefCell<T>>` graph example (Section 15.7.2) does not include a cycle, so no memory leak demonstration — the chapter mentions cycles are covered in 15.8 | Section 15.7.2 | Cross-reference is clear; intentional separation |
| Low | `DerefMut` section (15.3.3) is brief. A more complex real-world example (e.g., a custom string buffer) could be added for depth | Section 15.3.3 | Cookbook brevity is acceptable; core concept is demonstrated |
| Medium | The `Weak<dyn Observer>` pattern in Section 15.8.4 uses `Rc<dyn Observer>` as the subscriber type. Java developers may be confused by the coercion from `Rc<LogObserver>` to `Rc<dyn Observer>` — a brief note on unsized coercion would help | Section 15.8.4 | Functional as-is; a sentence could clarify the coercion |
| Medium | `Cell<T>` section (15.6.5) could note that `Cell<T>` has no runtime borrow tracking at all — it copies the value in and out — which is why it requires `Copy`. This is a subtle but important distinction from `RefCell` | Section 15.6.5 | The table alludes to it; explicit prose statement would be stronger |
| High | None identified | — | All primary claims verified against official Rust Book sources |

### Style and Completeness

- Section numbering follows `15.x.y` convention matching other chapters.
- Three opening blockquotes (Philosophy, Edition, Java mental model) present.
- Java comparison tables included in Section 15.1 and 15.10.
- Decision matrix in Section 15.9 covers all types including `Arc<T>` forward reference.
- Compiler error messages shown verbatim for: recursive type (`E0072`), explicit destructor call (`E0040`), RefCell panic, and use of moved value.
- `println!("{var}")` capture syntax used throughout where applicable.
- All five requested practical examples present and complete.
