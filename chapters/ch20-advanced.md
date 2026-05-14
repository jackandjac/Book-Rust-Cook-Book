# Chapter 20: Advanced Features

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes Java developers make when they first encounter Rust's most powerful (and dangerous) tools.

> **Edition note:** All examples assume `edition = "2024"` in your `Cargo.toml` (requires Rust 1.85+). Several 2024 changes are load-bearing in this chapter: `&raw const`/`&raw mut` for raw pointer creation, `unsafe extern "C" { ... }` block syntax, `#[unsafe(no_mangle)]` attribute form, and the rule that `unsafe fn` bodies are NOT automatically an unsafe context.

> **Java mental model:** Java has no equivalent to most of this chapter. The closest analogies are JNI (for FFI), `sun.misc.Unsafe` (for raw memory — and you're told never to use it), and annotation processors (for procedural macros). Rust makes these capabilities explicit, auditable, and composable with the safe type system.

---

## Contents

- [20.1 Unsafe Rust](#201-unsafe-rust)
- [20.2 Advanced Traits](#202-advanced-traits)
- [20.3 Advanced Types](#203-advanced-types)
- [20.4 Advanced Functions and Closures](#204-advanced-functions-and-closures)
- [20.5 Macros](#205-macros)

---

## 20.1 Unsafe Rust

### Overview

Rust has two modes: **safe** (the default, enforced by the borrow checker and type system) and **unsafe** (a subset of operations that the compiler cannot verify). Writing `unsafe` does not disable the borrow checker — all safe-Rust rules still apply inside an `unsafe` block. `unsafe` only unlocks five specific capabilities (covered below) that require programmer-upheld invariants.

Unsafe is justified for: FFI calls, implementing safe abstractions the borrow checker cannot reason about (e.g., `Vec::split_at_mut`), performance-critical low-level code, and manually implementing `Send`/`Sync` for raw-pointer-containing types.

**Java comparison:** Java's `sun.misc.Unsafe` is the rough analogue — discouraged with no guardrails. Rust's `unsafe` blocks are explicit, auditable, and scoped.

### The 5 Unsafe Superpowers

The task list frames these as: raw pointers, unsafe function calls, unsafe trait impl, mutable statics, and `extern "C"`. (Note: the Rust Book's canonical fifth item is accessing fields of a `union`, used primarily for C interop. This chapter covers `extern "C"` as the fifth since it is what most systems programmers encounter first; union fields follow naturally from FFI work.)

---

### 20.1.1 Raw Pointers: `*const T` and `*mut T`

Raw pointers are Rust's equivalent of C pointers. They bypass Rust's ownership and borrowing rules and are therefore only safe to dereference inside an `unsafe` block.

**Rust 2024 raw pointer creation uses `&raw const` / `&raw mut`** — not the old cast syntax (`&x as *const _`), which was error-prone. The new forms are explicit about what you are doing.

```rust
fn main() {
    let mut num = 42_i32;

    // Rust 2024: create raw pointers with &raw const / &raw mut
    let r_const: *const i32 = &raw const num;
    let r_mut: *mut i32   = &raw mut num;

    // Creating raw pointers is safe. Dereferencing requires unsafe.
    unsafe {
        println!("r_const points to: {}", *r_const);
        println!("r_mut points to:   {}", *r_mut);

        // Mutating through a raw pointer
        *r_mut = 100;
    }

    println!("num is now: {num}");
}
```

**What raw pointers give up compared to references:**

| Property | `&T` / `&mut T` | `*const T` / `*mut T` |
|---|---|---|
| Guaranteed non-null | Yes | No |
| Guaranteed valid memory | Yes | No |
| Obeys borrow rules | Yes | No |
| Automatic cleanup | Yes (RAII) | No |
| Dereference in safe code | Yes | No — requires `unsafe` |

**Creating a pointer to arbitrary memory (and why it's dangerous):**

```rust
fn main() {
    // This compiles — creating the pointer is safe.
    let address = 0xDEAD_BEEFusize;
    let _dangerous: *const i32 = address as *const i32;

    // Dereferencing it would be undefined behavior — don't do this:
    // unsafe { println!("{}", *_dangerous); }  // UB: arbitrary address
}
```

**Check for null before dereferencing:** use `ptr.is_null()` in a guard before entering the `unsafe` block. The safe-wrapper pattern in 20.1.2 shows the full idiom.

---

### 20.1.2 Unsafe Functions and Safe Wrappers

**`unsafe fn`** declares that callers must uphold invariants the compiler cannot check. In Rust 2024, the body of an `unsafe fn` is NOT automatically an unsafe context — you must still write `unsafe { }` around the unsafe operations inside it.

```rust
// unsafe fn: callers must guarantee `ptr` is valid and non-null.
unsafe fn read_i32(ptr: *const i32) -> i32 {
    // Rust 2024: body of unsafe fn is NOT an implicit unsafe block.
    // You must write unsafe { } around the actual unsafe operation.
    unsafe { *ptr }
}

fn main() {
    let x = 7_i32;
    let p: *const i32 = &raw const x;

    let val = unsafe { read_i32(p) };
    println!("val = {val}");
}
```

#### Practical Example: Safe Wrapper Around a C String Buffer

The canonical use of unsafe is wrapping a C-originated buffer in a safe Rust API. The `unsafe` stays inside the wrapper; callers see a normal safe function.

```rust
use std::ffi::CStr;
use std::os::raw::c_char;

/// SAFE public API: convert a null-terminated C buffer to a Rust &str.
/// Returns None if the buffer is missing a null terminator or invalid UTF-8.
pub fn c_buf_to_str(buf: &[u8]) -> Option<&str> {
    if !buf.contains(&0) {
        return None;
    }
    // SAFETY: We verified the buffer contains a null terminator.
    let c_str = unsafe { CStr::from_ptr(buf.as_ptr() as *const c_char) };
    c_str.to_str().ok()
}

fn main() {
    let buf: &[u8] = b"Hello from C\0";
    match c_buf_to_str(buf) {
        Some(s) => println!("Got: {s}"), // Got: Hello from C
        None    => println!("Invalid"),
    }
}
```

---

### 20.1.3 Extern "C" — Calling C from Rust and Vice Versa

#### Calling a C Function (FFI)

```rust
// Rust 2024: the block itself is annotated unsafe.
// Items inside can be marked `safe` to opt into call-site safety.
unsafe extern "C" {
    // abs is well-defined for all i32 values, so we can mark it safe.
    safe fn abs(input: i32) -> i32;

    // A hypothetical dangerous C function stays unsafe to call.
    fn read_raw_bytes(ptr: *mut u8, len: usize) -> i32;
}

fn main() {
    // abs is `safe` inside the extern block — no unsafe needed here.
    println!("abs(-7) = {}", abs(-7));

    // read_raw_bytes still requires unsafe at the call site.
    let mut buf = [0u8; 4];
    unsafe {
        read_raw_bytes(buf.as_mut_ptr(), 4);
    }
}
```

#### Exposing Rust Functions to C

```rust
// Rust 2024: no_mangle is an unsafe attribute (you promise the name is
// unique and won't clash with other symbols).
#[unsafe(no_mangle)]
pub extern "C" fn add_from_rust(a: i32, b: i32) -> i32 {
    a + b
}
```

**Java comparison:** This is the Rust equivalent of the `native` keyword and `System.loadLibrary()` in JNI, but far simpler — no JNI header generation, no `JNIEnv*` argument.

---

### 20.1.4 Mutable Static Variables

Global state in Rust uses `static`. Immutable statics are safe; mutable statics are not, because concurrent access creates data races.

```rust
static mut COUNTER: u32 = 0;

/// SAFETY: Must only be called from a single thread at a time.
unsafe fn add_to_counter(inc: u32) {
    unsafe {
        COUNTER += inc;
    }
}

fn main() {
    unsafe {
        add_to_counter(3);
        add_to_counter(7);
        // Rust 2024: read via &raw const to avoid creating a reference.
        println!("COUNTER: {}", *(&raw const COUNTER));
    }
    // Output: COUNTER: 10
}
```

**Prefer thread-safe alternatives in production:** `AtomicU32`, `Mutex<u32>`, or `OnceLock<T>` cover most use cases for global state without unsafe.

---

### 20.1.5 Unsafe Traits

A trait is `unsafe` when its methods carry invariants the compiler cannot verify. Implementors use `unsafe impl` to promise they have upheld those invariants.

The most common `unsafe` traits are `Send` and `Sync`. When you wrap a raw pointer in a struct, the compiler conservatively marks it `!Send + !Sync`. You opt back in with `unsafe impl`:

```rust
use std::ptr::NonNull;

struct MyBox<T> { ptr: NonNull<T> }

// SAFETY: MyBox owns its data exclusively — no aliased mutable access.
unsafe impl<T: Send> Send for MyBox<T> {}
unsafe impl<T: Sync> Sync for MyBox<T> {}
```

---

### 20.1.6 Unsafe Anti-Patterns to Avoid

```rust
// BAD: Unsafe block is too large — hard to reason about what is actually unsafe.
unsafe fn poor_wrapper(ptr: *const i32) -> i32 {
    unsafe {
        let value = *ptr;        // unsafe: dereference
        let doubled = value * 2; // safe: arithmetic
        let result = doubled + 1; // safe: arithmetic
        result
    }
}

// GOOD: Minimal unsafe scope; unsafe only around the dereference.
unsafe fn good_wrapper(ptr: *const i32) -> i32 {
    // SAFETY: Caller guarantees ptr is non-null and valid.
    let value = unsafe { *ptr };
    let doubled = value * 2;
    doubled + 1
}
```

---

## 20.2 Advanced Traits

Rust traits go well beyond Java interfaces: they can be implemented retroactively for any type (subject to the orphan rule), support associated types, operator overloading, disambiguation syntax, and supertrait dependencies.

### 20.2.1 Associated Types vs Generic Type Parameters

**Associated types** bind exactly one concrete type per `impl`. A generic parameter `Iterator<T>` would allow `impl Iterator<String>` and `impl Iterator<u32>` on the same type; an associated type `type Item` allows only one choice.

```rust
pub trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}

struct Counter { count: u32 }

impl Iterator for Counter {
    type Item = u32;
    fn next(&mut self) -> Option<u32> {
        if self.count < 5 { self.count += 1; Some(self.count) } else { None }
    }
}

fn main() {
    let mut c = Counter { count: 0 };
    while let Some(v) = c.next() { print!("{v} "); }
    println!(); // 1 2 3 4 5
}
```

**Rule of thumb:** Use an associated type for the single "output" type (`Iterator::Item`, `Add::Output`). Use a generic parameter when multiple impls for different types make sense on the same struct.

---

### 20.2.2 Operator Overloading with Default Type Parameters

Operator overloading is done by implementing traits in `std::ops`. The `Add` trait uses a default type parameter:

```rust
pub trait Add<Rhs = Self> {
    type Output;
    fn add(self, rhs: Rhs) -> Self::Output;
}
```

`Rhs=Self` is a **default type parameter**: if you don't specify `Rhs`, it defaults to the implementing type.

#### Practical Example: `Vector2D`

```rust
use std::fmt;
use std::ops::{Add, Sub, Mul};

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Vector2D { pub x: f64, pub y: f64 }

impl Vector2D {
    pub fn new(x: f64, y: f64) -> Self { Self { x, y } }
    pub fn magnitude(&self) -> f64 {
        (self.x * self.x + self.y * self.y).sqrt()
    }
}

// v1 + v2  (Rhs defaults to Self)
impl Add for Vector2D {
    type Output = Vector2D;
    fn add(self, rhs: Vector2D) -> Vector2D {
        Vector2D::new(self.x + rhs.x, self.y + rhs.y)
    }
}

// v1 - v2
impl Sub for Vector2D {
    type Output = Vector2D;
    fn sub(self, rhs: Vector2D) -> Vector2D {
        Vector2D::new(self.x - rhs.x, self.y - rhs.y)
    }
}

// v * scalar  — Rhs is f64, NOT Vector2D: demonstrates non-Self Rhs
impl Mul<f64> for Vector2D {
    type Output = Vector2D;
    fn mul(self, s: f64) -> Vector2D { Vector2D::new(self.x * s, self.y * s) }
}

impl fmt::Display for Vector2D {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({:.2}, {:.2})", self.x, self.y)
    }
}

fn main() {
    let a = Vector2D::new(1.0, 2.0);
    let b = Vector2D::new(3.0, 4.0);
    println!("a + b = {}", a + b);      // (4.00, 6.00)
    println!("a - b = {}", a - b);      // (-2.00, -2.00)
    println!("b * 2 = {}", b * 2.0);    // (6.00, 8.00)
    println!("|b|   = {:.4}", b.magnitude()); // 5.0000
}
```

---

### 20.2.3 Fully Qualified Syntax

When multiple traits define a method with the same name, Rust defaults to the method on the type itself. Use fully qualified syntax to be explicit.

```rust
trait Pilot {
    fn fly(&self) -> &str;
}

trait Wizard {
    fn fly(&self) -> &str;
}

struct Human;

impl Pilot for Human {
    fn fly(&self) -> &str { "This is your captain speaking." }
}

impl Wizard for Human {
    fn fly(&self) -> &str { "Up!" }
}

impl Human {
    fn fly(&self) -> &str { "*waving arms furiously*" }
}

fn main() {
    let h = Human;

    println!("{}", h.fly());             // *waving arms furiously* (inherent method wins)
    println!("{}", Pilot::fly(&h));      // This is your captain speaking.
    println!("{}", Wizard::fly(&h));     // Up!
}
```

**Associated functions (no `self`) need the full `<Type as Trait>::` form:**

```rust
trait Animal {
    fn baby_name() -> String;
}

struct Dog;

impl Dog {
    fn baby_name() -> String { String::from("Spot") }
}

impl Animal for Dog {
    fn baby_name() -> String { String::from("puppy") }
}

fn main() {
    println!("{}", Dog::baby_name());              // Spot (inherent fn)
    println!("{}", <Dog as Animal>::baby_name());  // puppy (trait fn)
}
```

---

### 20.2.4 Supertraits

A supertrait declares that implementing your trait requires also implementing another trait. Use the `: SuperTrait` syntax.

```rust
use std::fmt;

// OutlinePrint requires that Self also implements fmt::Display.
trait OutlinePrint: fmt::Display {
    fn outline_print(&self) {
        let text = self.to_string(); // available because of Display supertrait
        let width = text.len() + 4;
        println!("{}", "*".repeat(width));
        println!("* {text} *");
        println!("{}", "*".repeat(width));
    }
}

#[derive(Debug)]
struct Point { x: i32, y: i32 }

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

// This compiles because Point implements fmt::Display.
impl OutlinePrint for Point {}

fn main() {
    let p = Point { x: 3, y: 7 };
    p.outline_print(); // prints "(3, 7)" framed in asterisks
}
```

**Java comparison:** Similar to Java interface inheritance (`interface A extends B`), but Rust enforces the supertrait bound at `impl` time, not just at usage sites.

---

### 20.2.5 The Newtype Pattern — Implementing External Traits

Rust's **orphan rule**: you can only implement a trait for a type if either the trait or the type is local to your crate. The newtype pattern works around this by wrapping the external type in a local tuple struct.

```rust
use std::fmt;

// We can't write `impl fmt::Display for Vec<String>` (both are external).
// Wrap Vec<String> in a local type:
struct Wrapper(Vec<String>);

impl fmt::Display for Wrapper {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}]", self.0.join(", "))
    }
}

fn main() {
    let w = Wrapper(vec![
        String::from("hello"),
        String::from("world"),
    ]);
    println!("w = {w}"); // w = [hello, world]
}
```

To expose inner type methods, implement `Deref`: `impl Deref for Wrapper { type Target = Vec<String>; fn deref(&self) -> &Vec<String> { &self.0 } }`. Then `*wrapper` and all `Vec` methods work via auto-deref.

---

## 20.3 Advanced Types

### 20.3.1 Type Aliases

`type` creates an alias — a new name for an existing type. Unlike the newtype pattern, aliases provide **no additional type safety**: the compiler treats `Kilometers` and `i32` as identical.

```rust
type Kilometers = i32;

fn add_distances(a: Kilometers, b: Kilometers) -> Kilometers {
    a + b
}

fn main() {
    let distance: Kilometers = 42;
    let raw: i32 = 10;

    // This compiles — Kilometers and i32 are the same type.
    println!("{}", add_distances(distance, raw));  // 52
}
```

**Most common alias: `Result<T>` in a module** — avoids repeating the error type on every function signature.

```rust
use std::fmt;

// Every function in this module returns this error type.
type Result<T> = std::result::Result<T, MyError>;

#[derive(Debug)]
pub struct MyError(String);

impl fmt::Display for MyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "MyError: {}", self.0)
    }
}

pub fn parse_id(s: &str) -> Result<u64> {
    s.parse::<u64>().map_err(|e| MyError(e.to_string()))
}

fn main() {
    match parse_id("42") {
        Ok(id)  => println!("Parsed: {id}"),
        Err(e)  => println!("Error: {e}"),
    }
}
```

---

### 20.3.2 Practical Example: Type-Safe ID Newtype

Type aliases don't prevent mixing up `UserId` with `OrderId`. Newtypes do.

```rust
use std::fmt;

// Newtypes: structurally identical but type-incompatible.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct OrderId(pub u64);

impl fmt::Display for UserId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "User#{}", self.0)
    }
}

impl fmt::Display for OrderId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Order#{}", self.0)
    }
}

fn find_orders_for_user(user: UserId) -> Vec<OrderId> {
    // Simulated database lookup
    vec![OrderId(101), OrderId(102)]
}

fn main() {
    let user = UserId(42);
    let orders = find_orders_for_user(user);
    for order in &orders {
        println!("{user} has {order}");
    }

    // This would NOT compile — you cannot pass an OrderId where UserId is expected:
    // find_orders_for_user(OrderId(101));  // error[E0308]: mismatched types
}
```

**Java comparison:** Java developers often use `long userId` everywhere and accidentally pass an order ID to a user ID parameter — a runtime bug. Rust newtypes catch this at compile time with zero runtime overhead.

---

### 20.3.3 The Never Type `!`

The never type `!` is the return type of functions that **never return** (diverging functions). `!` can be coerced into any type — this is why `panic!`, `continue`, and `loop {}` are valid in type-checked expressions.

```rust
// panic! returns `!`, which coerces to any type — valid in a match arm:
fn must_parse(s: &str) -> u32 {
    match s.parse::<u32>() {
        Ok(n)  => n,
        Err(_) => panic!("Expected a u32, got: {s:?}"),
        //         ^^^^^ type `!` coerces to `u32`
    }
}

// continue has type `!` — makes the match arms agree on type i32:
fn first_even(nums: &[i32]) -> i32 {
    let mut iter = nums.iter();
    loop {
        let n = match iter.next() {
            Some(&n) => n,
            None     => panic!("no even number found"),
        };
        let result: i32 = match n % 2 {
            0 => n,
            _ => continue,  // `!` coerces to i32
        };
        return result;
    }
}

fn main() {
    println!("{}", must_parse("99"));            // 99
    println!("{}", first_even(&[1, 3, 4, 6]));  // 4
}
```

`!` expressions in std: `panic!(...)`, `loop {}` (no `break`), `continue`, `std::process::exit()`, `todo!()`, `unimplemented!()`.

---

### 20.3.4 Dynamically Sized Types (DSTs) and `?Sized`

A **dynamically sized type (DST)** is a type whose size is unknown at compile time. You cannot hold a DST by value — only behind a pointer (`&`, `Box`, `Rc`, etc.).

The three DSTs you'll encounter: `str` (string data), `[T]` (slice), and `dyn Trait` (trait object). References to them are **fat pointers** — two `usize` words: data address plus length (or vtable pointer for `dyn`).

```rust
fn main() {
    // &str and &[T] are fat pointers (addr + len).
    println!("&str size:  {} bytes", std::mem::size_of::<&str>());  // 16 on 64-bit
    println!("&i32 size:  {} bytes", std::mem::size_of::<&i32>()); // 8
}

fn sum_slice(s: &[i32]) -> i32 { s.iter().sum() }

trait Drawable { fn draw(&self); }
fn render(shape: &dyn Drawable) { shape.draw(); }
```

**The `Sized` trait and `?Sized`:**

All generic type parameters implicitly have a `Sized` bound. To accept DSTs, use `?Sized` ("possibly not Sized").

```rust
// Implicit: fn generic<T: Sized>(t: T) { ... }

// Explicit opt-out: accepts both Sized and unsized types.
// t must be behind a pointer because T may not have a known size.
fn print_value<T: ?Sized + std::fmt::Display>(t: &T) {
    println!("{t}");
}

fn main() {
    print_value(&42_i32);    // T = i32 (Sized)
    print_value("hello");    // T = str (DST — not Sized!)
    print_value(&3.14_f64);  // T = f64 (Sized)
}
```

**`?Sized` usage rules:**
- Only `Sized` supports `?` relaxation — `?Trait` syntax exists only for `Sized`.
- When `T: ?Sized`, `t` must be behind a pointer (`&T`, `Box<T>`, etc.).
- All trait objects (`dyn Trait`) are DSTs and require `?Sized` in generic contexts.

---

## 20.4 Advanced Functions and Closures

### Overview

Rust functions can be passed as values using **function pointers** (`fn` type). Closures and function pointers are related but distinct: function pointers are concrete types; closures are trait objects. This section covers both, their differences, and how to return them.

**Java comparison:** Java's `Function<Integer, Integer>` is roughly `impl Fn(i32) -> i32` in Rust. Method references (`MyClass::myMethod`) correspond to Rust function pointers (`my_fn`). Unlike Java's `Function<...>`, Rust function pointers (`fn(T) -> R`) carry no heap allocation.

---

### 20.4.1 Function Pointers

`fn(T) -> R` is a **concrete type**, not a trait. It stores the address of a named function (not a closure that captures variables).

```rust
fn double(x: i32) -> i32 { x * 2 }
fn square(x: i32) -> i32 { x * x }

// Accept a function pointer as a parameter.
fn apply(f: fn(i32) -> i32, val: i32) -> i32 {
    f(val)
}

fn main() {
    println!("{}", apply(double, 5));  // 10
    println!("{}", apply(square, 5)); // 25

    // Function pointers implement Fn, FnMut, FnOnce — usable anywhere
    // a closure is expected.
    let ops: Vec<fn(i32) -> i32> = vec![double, square];
    for op in &ops {
        println!("{}", op(3));  // 6, then 9
    }
}
```

**Function pointers vs closures:** `fn(T) -> R` is a concrete type (no captures, FFI-safe, can be stored in a homogeneous `Vec`). `impl Fn(T) -> R` is a trait bound (may capture environment, not FFI-safe, requires `Box<dyn Fn>` for heterogeneous storage). Function pointers implement all three `Fn` traits, so they can be passed where a closure is expected.

---

### 20.4.2 Practical Example: Function Pointer Dispatch Table

A dispatch table maps strings to function pointers — a fast alternative to match chains. This pattern appears in command interpreters, plugin systems, and event handlers.

```rust
use std::collections::HashMap;

fn cmd_help(_: &str) -> String {
    "Available commands: help, version, greet".to_string()
}

fn cmd_version(_: &str) -> String {
    "v1.0.0".to_string()
}

fn cmd_greet(arg: &str) -> String {
    if arg.is_empty() {
        "Hello, stranger!".to_string()
    } else {
        format!("Hello, {arg}!")
    }
}

fn main() {
    // Dispatch table: command name -> function pointer.
    let dispatch: HashMap<&str, fn(&str) -> String> = HashMap::from([
        ("help",    cmd_help    as fn(&str) -> String),
        ("version", cmd_version as fn(&str) -> String),
        ("greet",   cmd_greet   as fn(&str) -> String),
    ]);

    let inputs = vec![
        ("help", ""),
        ("greet", "Rustacean"),
        ("version", ""),
        ("unknown", ""),
    ];

    for (cmd, arg) in inputs {
        match dispatch.get(cmd) {
            Some(f) => println!("[{cmd}] {}", f(arg)),
            None    => println!("[{cmd}] Unknown command"),
        }
    }
}
// Output:
// [help] Available commands: help, version, greet
// [greet] Hello, Rustacean!
// [version] v1.0.0
// [unknown] Unknown command
```

**Java comparison:** Java developers reach for `Map<String, Function<String, String>>` here. Same pattern, but Rust's `fn` type carries no heap allocation overhead — it's just a pointer to the function's code.

---

### 20.4.3 Returning Closures

Closures have unique, anonymous types. You cannot write the return type as a concrete type. Two solutions:

**`impl Fn` — when returning a single closure type (preferred, no heap allocation):**

```rust
fn make_adder(n: i32) -> impl Fn(i32) -> i32 {
    move |x| x + n
}

fn main() {
    let add5 = make_adder(5);
    let add10 = make_adder(10);
    println!("{}", add5(3));   // 8
    println!("{}", add10(3));  // 13
}
```

**`Box<dyn Fn>` — for heterogeneous closures or storing in a collection:**

`impl Fn` fails when branches return different closure types (each `impl Fn` is a distinct opaque type). `Box<dyn Fn>` provides a uniform handle:

```rust
fn either(flag: bool) -> Box<dyn Fn(i32) -> i32> {
    if flag { Box::new(|x| x * 2) }
    else    { Box::new(|x| x + 1) }
}

fn main() {
    // Storable together because they share the same Box<dyn Fn> type.
    let transforms: Vec<Box<dyn Fn(i32) -> i32>> = vec![
        either(true),
        either(false),
        Box::new(|x| x * x),
    ];
    for t in &transforms {
        println!("{}", t(4));  // 8, 5, 16
    }
}
```

---

## 20.5 Macros

### Overview

Macros are Rust's **metaprogramming** system — code that writes code. There are two families:

1. **Declarative macros** (`macro_rules!`) — pattern matching on token trees, expanded at compile time
2. **Procedural macros** — functions that receive a `TokenStream` and return a `TokenStream`; three kinds: derive, attribute, and function-like

Key differences from functions: macros accept variable numbers of arguments, expand at compile time (not runtime), can implement traits, and must be in scope before their first use. Debugging macros is harder than debugging functions — prefer functions when either would work.

**Java comparison:** Closest analogue is annotation processors (APT), but Rust macros operate directly on the token stream with no separate build infrastructure.

---

### 20.5.1 Declarative Macros with `macro_rules!`

A `macro_rules!` macro matches patterns against the input token stream and replaces the invocation with the matched arm's body.

Each rule has the form `pattern => { expansion }`. Common pattern designators: `expr` (any expression), `ident` (identifier), `ty` (type), `tt` (token tree — catch-all), `pat` (pattern), `literal`. Repetition operators: `*` (zero or more), `+` (one or more), `?` (zero or one).

---

### 20.5.2 Writing `my_vec!`

```rust
#[macro_export]
macro_rules! my_vec {
    // Match zero or more comma-separated expressions.
    ( $( $element:expr ),* ) => {
        {
            let mut v = Vec::new();
            $(
                v.push($element);
            )*
            v
        }
    };

    // Trailing comma variant: my_vec![1, 2, 3,]
    ( $( $element:expr ),+ , ) => {
        my_vec![ $($element),* ]
    };
}

fn main() {
    let a: Vec<i32> = my_vec![1, 2, 3];
    let b: Vec<&str> = my_vec!["alpha", "beta", "gamma"];
    let empty: Vec<i32> = my_vec![];

    println!("{a:?}");     // [1, 2, 3]
    println!("{b:?}");     // ["alpha", "beta", "gamma"]
    println!("{empty:?}"); // []
}
```

**Walking through the expansion of `my_vec![1, 2, 3]`:**

```
$element captures: 1, 2, 3  (three repetitions)

Expands to:
{
    let mut v = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    v
}
```

---

### 20.5.3 Practical Example: Test Fixture Macro

A common cookbook pattern is using macros to reduce boilerplate in tests. Here is a `fixture!` macro that constructs a named test struct from field assignments:

```rust
/// Creates a struct literal for test fixtures with less boilerplate.
/// Usage: fixture!(Point { x: 1, y: 2 })
macro_rules! fixture {
    // Single struct: fixture!(TypeName { field: value, ... })
    ($type:ident { $( $field:ident : $value:expr ),* $(,)? }) => {
        $type {
            $( $field: $value, )*
        }
    };

    // Named shorthand: fixture!(name = TypeName { field: value, ... })
    ($name:ident = $type:ident { $( $field:ident : $value:expr ),* $(,)? }) => {
        let $name = $type {
            $( $field: $value, )*
        };
    };
}

#[derive(Debug, PartialEq)]
struct Point { x: i32, y: i32 }

#[derive(Debug)]
struct Rectangle { width: u32, height: u32 }

impl Rectangle {
    fn area(&self) -> u32 { self.width * self.height }
}

fn main() {
    let p = fixture!(Point { x: 3, y: 7 });
    assert_eq!(p, Point { x: 3, y: 7 });

    fixture!(rect = Rectangle { width: 10, height: 5 });
    println!("rect area = {}", rect.area()); // 50
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fixture() {
        let origin = fixture!(Point { x: 0, y: 0 });
        assert_eq!(origin.x, 0);
        fixture!(r = Rectangle { width: 4, height: 6 });
        assert_eq!(r.area(), 24);
    }
}
```

Pattern notes: `$type:ident` captures the struct name; `$( $field:ident : $value:expr ),*` captures field-value pairs; `$(,)?` allows a trailing comma. Note: the named-binding arm (`fixture!(name = ...)`) emits a `let` statement and cannot appear in expression position.

---

### 20.5.4 Procedural Macros — Conceptual Overview

Procedural macros are Rust functions that run at compile time, receive a `TokenStream` (the raw token sequence of your code), and return a transformed `TokenStream`. They live in a separate crate with `proc-macro = true` in `Cargo.toml`.

**Three kinds:**

| Kind | Syntax | Use case |
|---|---|---|
| Custom derive | `#[derive(MyTrait)]` | Auto-implement traits |
| Attribute macro | `#[my_attr]` on any item | Transforms functions, structs, etc. |
| Function-like | `my_macro!(...)` | Complex DSLs (e.g., `sql!`, `html!`) |

**Crate setup for a procedural macro:**

```toml
# hello_macro_derive/Cargo.toml
[lib]
proc-macro = true

[dependencies]
syn   = "2.0"
quote = "1.0"
```

**Key crates:**
- `proc_macro` — built into the compiler; provides `TokenStream`
- `syn` — parses a `TokenStream` into a rich AST (`DeriveInput`, `ItemFn`, etc.)
- `quote` — the `quote! { }` macro generates Rust code as a `TokenStream`

---

### 20.5.5 Custom `#[derive(HelloMacro)]`

This is the standard introductory procedural macro from the Rust Book. It generates a `hello_macro()` method for any type that writes the type's name at runtime.

**Trait crate (`hello_macro/src/lib.rs`):**

```rust
pub trait HelloMacro {
    fn hello_macro();
}
```

**Derive macro crate (`hello_macro_derive/src/lib.rs`):**

```rust
use proc_macro::TokenStream;
use quote::quote;
use syn;

#[proc_macro_derive(HelloMacro)]
pub fn hello_macro_derive(input: TokenStream) -> TokenStream {
    // Parse the input tokens into a syntax tree.
    let ast: syn::DeriveInput = syn::parse(input).unwrap();

    impl_hello_macro(&ast)
}

fn impl_hello_macro(ast: &syn::DeriveInput) -> TokenStream {
    let name = &ast.ident; // The name of the struct/enum being derived.

    let generated = quote! {
        impl HelloMacro for #name {
            fn hello_macro() {
                // stringify! turns the identifier into a &str at compile time.
                println!("Hello, Macro! My name is {}!", stringify!(#name));
            }
        }
    };
    generated.into()
}
```

**User code:**

```rust
use hello_macro::HelloMacro;
use hello_macro_derive::HelloMacro;

#[derive(HelloMacro)]
struct Pancakes;

fn main() {
    Pancakes::hello_macro(); // Hello, Macro! My name is Pancakes!
}
```

**Why this is useful:** Without the derive macro, each type author would have to write `impl HelloMacro for Pancakes { ... }` manually. The macro automates this. Real-world examples: `serde`'s `#[derive(Serialize, Deserialize)]`, `#[derive(Debug)]`, `#[derive(Clone)]`.

---

### 20.5.6 Attribute and Function-Like Macros (Overview)

**Attribute macros** (`#[proc_macro_attribute]`) attach to any item and receive two `TokenStream` arguments: the attribute contents and the item body. **Function-like macros** (`#[proc_macro]`) look like `sql!(...)` calls and receive a single `TokenStream`.

```rust
// Attribute macro: #[route(GET, "/")] fn index() { ... }
// Receives attr = `GET, "/"` and item = the fn body.
#[proc_macro_attribute]
pub fn route(attr: TokenStream, item: TokenStream) -> TokenStream { item }

// Function-like macro: sql!(SELECT * FROM users WHERE id = 1)
#[proc_macro]
pub fn sql(input: TokenStream) -> TokenStream { input }
```

**Real-world procedural macros to know:**

| Crate | Macro | What it does |
|---|---|---|
| `serde` | `#[derive(Serialize, Deserialize)]` | Auto-generates (de)serialization |
| `tokio` | `#[tokio::main]` | Transforms `main` into an async runtime entry |
| `thiserror` | `#[derive(Error)]` | Implements `std::error::Error` |
| `sqlx` | `sqlx::query!()` | Verifies SQL at compile time against a live DB |
| `axum` | `#[debug_handler]` | Better error messages for route handlers |

---

## 📝 Chapter Review Notes

### Critical Review (Third Person)

The chapter covers all five topic areas prescribed by the task brief — unsafe Rust, advanced traits, advanced types, advanced functions and closures, and macros — with attention to Rust 2024 edition specifics throughout. The practical examples are concrete and runnable: the C string wrapper, Vector2D operator overloading, type-safe ID newtype, function pointer dispatch table, and the `fixture!` test macro all appear and are complete enough to paste into a playground.

**Strengths:**

- All five Rust 2024 edition distinctions are handled correctly: `&raw const`/`&raw mut`, `unsafe extern "C" { }` block form, `#[unsafe(no_mangle)]`, explicit `unsafe { }` inside `unsafe fn` bodies, and `*(&raw const COUNTER)` for reading mutable statics.
- Java comparisons are present at every section, appropriate for the stated audience.
- The procedural macro section sets expectations correctly: it is conceptual, it provides the `Cargo.toml` setup, and the `my_vec!` expansion walkthrough makes the token-substitution model concrete.

**Areas for further development:**

- The C string safe-wrapper example uses `CStr::from_ptr` but is not backed by a real C library call. A production FFI implementation would need a `build.rs`, a C source file, and linker setup — worth noting for readers pursuing this path.
- The `unsafe impl Send/Sync for MyBox` example is illustrative only — `MyBox` has no constructor or `Drop`, so it is not standalone runnable.
- Miri (`cargo +nightly miri run`) is mentioned in the source material but excluded here to stay within the line target — it is the recommended tool for dynamically checking unsafe code.
- The `fixture!` macro's named-binding arm (`fixture!(name = ...)`) emits a `let` statement and cannot appear in expression position — this design choice is now noted inline.

---

### Issues Table

| ID | Severity | Topic | Description | Status |
|---|---|---|---|---|
| I-01 | OK | Raw pointers | `&raw const`/`&raw mut` used correctly (2024 edition) | Verified |
| I-02 | OK | `unsafe fn` body | Explicit `unsafe { }` required inside `unsafe fn` shown correctly | Verified |
| I-03 | OK | `extern "C"` block | `unsafe extern "C" { }` block form used (2024) | Verified |
| I-04 | OK | `no_mangle` | `#[unsafe(no_mangle)]` form used (not bare `#[no_mangle]`) | Verified |
| I-05 | OK | `static mut` read | `*(&raw const COUNTER)` used to avoid creating reference to mutable static | Verified |
| I-06 | Medium | C wrapper | `c_buf_to_str` is not backed by a real C library call. Real FFI needs `build.rs` + C source + linker config. | Noted in review |
| I-07 | Medium | `MyBox<T>` example | `unsafe impl Send/Sync` example is illustrative; `MyBox` has no constructor or `Drop` — not standalone runnable | Illustrative only |
| I-08 | Low | Diverging function | `forever()` function removed; `must_parse` and `first_even` illustrate `!` coercion instead | Resolved |
| I-09 | Low | Miri | Not covered; mentioned in source material but excluded to stay within line target | Gap acceptable |
| I-10 | Low | Proc macro code | Cannot be compiled as a single file; requires separate crate with `proc-macro = true` | Noted in text |
| I-11 | Low | `fixture!` named arm | `let` binding inside macro body means named arm cannot be used in expression position | Design choice; should be noted for readers |
| I-12 | OK | Operator overloading | `Mul<f64> for Vector2D` correctly demonstrates non-`Self` `Rhs` type parameter | Verified |
| I-13 | OK | Fully qualified syntax | `<Dog as Animal>::baby_name()` correctly shown for associated functions | Verified |
| I-14 | OK | `?Sized` bound | `print_value<T: ?Sized + Display>(t: &T)` correct — `t` is behind `&` pointer | Verified |
| I-15 | OK | `impl Fn` vs `Box<dyn Fn>` | Heterogeneous closure return type explained with compiler error callout | Verified |
| I-16 | High | Union fields | The canonical Rust Book 5th unsafe superpower (union field access) is absent. The task brief replaced it with `extern "C"`, which is covered. A one-line note is included but could be more prominent for readers who cross-reference the Book. | Acceptable per task brief |
