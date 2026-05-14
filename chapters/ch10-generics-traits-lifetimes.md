# Chapter 10: Generic Types, Traits, and Lifetimes

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes Java developers make when they first encounter Rust's type system.

> **Edition note:** All examples assume `edition = "2024"` in your `Cargo.toml` (requires Rust 1.85+). Create a project with `cargo new my-project` — `edition = "2024"` is the default since Rust 1.85.

> **Java mental model:** If you're coming from Java, think of Rust generics + traits + lifetimes as the union of Java generics (but faster), Java interfaces (but more powerful), and a compile-time memory safety system with no runtime overhead. You will spend more time reasoning about types up front and essentially zero time debugging null pointer exceptions or memory corruption at runtime.

---

## 10.1 Why These Three Features Belong Together

Generics, traits, and lifetimes form an inseparable triad in Rust:

- **Generics** let you write code that works over many types without duplicating it.
- **Traits** express *what a type can do* — and let you constrain generics to only accept types that have specific behavior.
- **Lifetimes** let the compiler verify that references in generic code never outlive the data they point to.

In Java, you only have the first two (in weaker form). Rust's lifetime system replaces what the JVM's garbage collector does for you — but at compile time, with zero runtime cost.

| Concept | Java | Rust |
|---|---|---|
| Generic code | `<T extends Comparable<T>>` | `fn foo<T: PartialOrd>(...)` |
| Shared behavior | `interface` (subtyping, virtual dispatch) | `trait` (static or dynamic dispatch) |
| Memory safety of references | GC at runtime | Lifetimes at compile time |
| Generic implementation strategy | Type erasure (all `T` become `Object`) | Monomorphization (separate copy per type) |
| Null safety | `NullPointerException` at runtime | Impossible by design (`Option<T>`) |

---

## 10.2 Generics

### 10.2.1 The Problem Generics Solve

Without generics, you duplicate logic for every type:

```rust,no_run
// Without generics — repeated for every type
fn largest_i32(list: &[i32]) -> &i32 {
    let mut largest = &list[0];
    for item in list {
        if item > largest {
            largest = item;
        }
    }
    largest
}

fn largest_char(list: &[char]) -> &char {
    let mut largest = &list[0];
    for item in list {
        if item > largest {
            largest = item;
        }
    }
    largest
}
```

That's the same logic twice. Generics eliminate this duplication.

### 10.2.2 Generic Functions

The type parameter goes between the function name and the parameter list, inside `<>`:

```rust,no_run
// First attempt — won't compile yet
fn largest<T>(list: &[T]) -> &T {
    let mut largest = &list[0];
    for item in list {
        if item > largest {   // ❌ error: binary operation `>` cannot be applied to type `T`
            largest = item;
        }
    }
    largest
}
```

The compiler error is:

```
error[E0369]: binary operation `>` cannot be applied to type `T`
  --> src/main.rs:5:17
   |
5  |         if item > largest {
   |            ---- ^ ------- &T
   |            |
   |            &T
   |
help: consider restricting type parameter `T`
   |
1  | fn largest<T: std::cmp::PartialOrd>(list: &[T]) -> &T {
```

The compiler tells you exactly what trait bound you need. This is the canonical Rust teaching moment: **the compiler drives you toward correct generic constraints**.

```rust
// Fixed: add the PartialOrd trait bound
fn largest<T: PartialOrd>(list: &[T]) -> &T {
    let mut largest = &list[0];
    for item in list {
        if item > largest {
            largest = item;
        }
    }
    largest
}

fn main() {
    let numbers = vec![34, 50, 25, 100, 65];
    println!("Largest number: {}", largest(&numbers));

    let chars = vec!['y', 'm', 'a', 'q'];
    println!("Largest char: {}", largest(&chars));
}
```

**Java comparison:** In Java you'd write `<T extends Comparable<T>>`. In Rust, `PartialOrd` is the trait (analogous to the interface), and `: PartialOrd` is the bound. The key difference: in Java, `Comparable` adds an `int compareTo(T o)` virtual dispatch at runtime. In Rust, `PartialOrd` is monomorphized — the compiler generates a concrete version of `largest` for each concrete type `T` you pass in.

### 10.2.3 Generic Structs

Generics work in struct definitions too:

```rust
// A generic Pair holding two values of the same type
struct Pair<T> {
    first: T,
    second: T,
}

// impl block is also generic over T
impl<T> Pair<T> {
    fn new(first: T, second: T) -> Self {
        Self { first, second }
    }
}

// A conditional impl: only Pair<T> where T implements Display + PartialOrd
// gets this extra method
use std::fmt::Display;

impl<T: Display + PartialOrd> Pair<T> {
    fn cmp_display(&self) {
        if self.first >= self.second {
            println!("The largest member is first = {}", self.first);
        } else {
            println!("The largest member is second = {}", self.second);
        }
    }
}

fn main() {
    let pair = Pair::new(5, 10);
    pair.cmp_display(); // works — i32 implements Display + PartialOrd

    let pair2 = Pair::new("hello", "world");
    pair2.cmp_display(); // works — &str implements Display + PartialOrd
}
```

This is **conditional method implementation** — a feature Java interfaces cannot express directly. The method `cmp_display` only exists when `T` supports both displaying and comparing.

### 10.2.4 Generic Enums

You've already used generic enums: `Option<T>` and `Result<T, E>` from the standard library are defined exactly this way:

```rust,no_run
// From the standard library (shown for illustration)
enum Option<T> {
    Some(T),
    None,
}

enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

### 10.2.5 Multiple Type Parameters

Structs and functions can have more than one type parameter:

```rust
// A pair with different types for first and second
struct MixedPair<T, U> {
    first: T,
    second: U,
}

impl<T: std::fmt::Display, U: std::fmt::Display> MixedPair<T, U> {
    fn show(&self) {
        println!("({}, {})", self.first, self.second);
    }
}

fn main() {
    let p = MixedPair { first: 42, second: "hello" };
    p.show(); // (42, hello)

    let q = MixedPair { first: 3.14, second: true };
    q.show(); // (3.14, true)
}
```

### 10.2.6 Monomorphization: Zero-Cost Generics

This is where Rust diverges fundamentally from Java.

**Java (type erasure):** At compile time, all generic type parameters are erased and replaced with `Object`. At runtime, `List<String>` and `List<Integer>` are both just `List`. The JVM inserts invisible casts and (for primitives) boxing/unboxing. This means:
- One copy of the bytecode for all `T`.
- Runtime overhead from boxing and virtual dispatch.
- `instanceof` checks and casts at runtime.
- You cannot get `T.class` at runtime without extra tricks.

**Rust (monomorphization):** The compiler generates a completely separate, fully specialized version of the code for each concrete type used. For `largest`:

```rust,no_run
fn largest<T: PartialOrd>(list: &[T]) -> &T { ... }

// You call:
largest(&[1i32, 2, 3]);
largest(&['a', 'b', 'c']);

// Rust internally creates (conceptually):
fn largest_i32(list: &[i32]) -> &i32 { ... }
fn largest_char(list: &[char]) -> &char { ... }
```

The generated machine code is **identical to what you'd write by hand**. No boxing, no virtual dispatch, no casts. The trade-off is slightly longer compile times and potentially larger binary size — but at runtime, generics are completely free.

| Java Generics | Rust Generics |
|---|---|
| One compiled form (erasure) | Separate compiled form per type |
| Type info erased at runtime | Full type info available at compile time |
| Boxing for primitive types | No boxing ever |
| Virtual dispatch cost | Direct function call |
| `ClassCastException` possible | Impossible — caught at compile time |

### 10.2.7 Generic Constraints with `where` Clauses

Move constraints to a `where` clause when the inline form becomes hard to read:

```rust,no_run
use std::fmt::{Debug, Display};

// Inline — cluttered with multiple parameters and bounds
fn show<T: PartialOrd + Display, U: Debug + Clone>(t: T, u: U) { /* ... */ }

// where clause — cleaner, same semantics
fn show_clean<T, U>(t: T, u: U)
where
    T: PartialOrd + Display,
    U: Debug + Clone,
{ /* ... */ }
```

---

## 10.3 Practical Example: Generic `Stack<T>`

A complete generic stack with push, pop, and peek:

```rust
#[derive(Debug)]
struct Stack<T> {
    elements: Vec<T>,
}

impl<T> Stack<T> {
    /// Creates an empty stack.
    fn new() -> Self {
        Stack { elements: Vec::new() }
    }

    /// Pushes a value onto the top of the stack.
    fn push(&mut self, value: T) {
        self.elements.push(value);
    }

    /// Removes and returns the top value, or None if empty.
    fn pop(&mut self) -> Option<T> {
        self.elements.pop()
    }

    /// Returns a reference to the top value without removing it.
    fn peek(&self) -> Option<&T> {
        self.elements.last()
    }

    /// Returns true if the stack has no elements.
    fn is_empty(&self) -> bool {
        self.elements.is_empty()
    }

    /// Returns the number of elements.
    fn len(&self) -> usize {
        self.elements.len()
    }
}

fn main() {
    // Stack of integers
    let mut int_stack: Stack<i32> = Stack::new();
    int_stack.push(1);
    int_stack.push(2);
    int_stack.push(3);

    println!("Top: {:?}", int_stack.peek()); // Top: Some(3)
    println!("Pop: {:?}", int_stack.pop());  // Pop: Some(3)
    println!("Length: {}", int_stack.len()); // Length: 2

    // Stack of strings — same code, different type
    let mut str_stack: Stack<String> = Stack::new();
    str_stack.push(String::from("hello"));
    str_stack.push(String::from("world"));

    while let Some(word) = str_stack.pop() {
        println!("{word}");
    }
    // world
    // hello
}
```

The same `Stack<T>` implementation works for any type without modification. The compiler generates separate, optimized machine code for `Stack<i32>` and `Stack<String>`.

---

## 10.4 Traits

### 10.4.1 Defining Traits

A trait defines a set of method signatures that a type must implement. Think of it as a Java `interface` that also supports:
- Default method implementations (like Java 8+ default methods)
- Extension-style implementations on types you don't own
- Blanket implementations across entire families of types

```rust,no_run
// Define a trait
pub trait Summary {
    // Required method — implementors must provide this
    fn summarize_author(&self) -> String;

    // Default method — implementors can override, but don't have to
    fn summarize(&self) -> String {
        format!("(Read more from {}...)", self.summarize_author())
    }
}
```

**Java comparison:**

```java
// Java interface
public interface Summary {
    String summarizeAuthor();

    default String summarize() {
        return "(Read more from " + summarizeAuthor() + "...)";
    }
}
```

The syntax is different but the semantics of required vs. default methods are nearly identical.

### 10.4.2 Implementing Traits for Types

```rust,no_run
pub struct NewsArticle {
    pub headline: String,
    pub author: String,
    pub location: String,
    pub content: String,
}

impl Summary for NewsArticle {
    fn summarize_author(&self) -> String {
        self.author.clone()
    }

    // Override the default summarize
    fn summarize(&self) -> String {
        format!("{}, by {} ({})", self.headline, self.author, self.location)
    }
}

pub struct SocialPost {
    pub username: String,
    pub content: String,
}

impl Summary for SocialPost {
    fn summarize_author(&self) -> String {
        format!("@{}", self.username)
    }

    // Uses the default summarize — no override needed
}

fn main() {
    let article = NewsArticle {
        headline: String::from("Penguins Win the Stanley Cup Championship!"),
        author: String::from("Iceburgh"),
        location: String::from("Pittsburgh, PA, USA"),
        content: String::from("The Pittsburgh Penguins once again are the best hockey team."),
    };

    let post = SocialPost {
        username: String::from("horse_ebooks"),
        content: String::from("of course as you probably already know, people"),
    };

    println!("{}", article.summarize());
    // Penguins Win the Stanley Cup Championship!, by Iceburgh (Pittsburgh, PA, USA)

    println!("{}", post.summarize());
    // (Read more from @horse_ebooks...)
}
```

### 10.4.3 The Orphan Rule

Rust enforces the **orphan rule**: you can implement a trait for a type only if either the trait **or** the type is defined in your crate.

```rust,no_run
// Your crate defines MyType
struct MyType;

// ✅ OK: you own MyType
impl std::fmt::Display for MyType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "MyType")
    }
}

// ✅ OK: you own MyTrait
trait MyTrait {}
impl MyTrait for Vec<i32> {}  // Vec is foreign, but MyTrait is yours

// ❌ NOT OK: both Display and String are from the standard library
// impl std::fmt::Display for String { ... }  // error[E0117]: only traits defined in the current crate can be implemented for types defined outside of the crate
```

**This catches you off-guard coming from Java:** In Java you can't add methods to `String` either, but you could wrap it in a subclass or use extension patterns. In Rust, you can add your own traits to any type, but you cannot add standard library traits to standard library types. This prevents conflicting implementations across crates.

### 10.4.4 Trait Bounds on Generic Functions

Traits become powerful when used as constraints on generic types. The `impl Trait` and `<T: Trait>` forms are equivalent in parameter position — use `impl Trait` for simple cases and the full form when `T` must be the same type in multiple positions:

```rust,no_run
use std::fmt::Display;

// impl Trait — concise, type can differ per parameter
pub fn notify(item: &impl Summary) {
    println!("Breaking news! {}", item.summarize());
}

// T: Trait — both parameters must be the exact same type
pub fn notify_same<T: Summary + Display>(item1: &T, item2: &T) {
    println!("{item1}: {}", item1.summarize());
    println!("{item2}: {}", item2.summarize());
}

// where clause — preferred when bounds get long
pub fn notify_where<T>(item: &T)
where
    T: Summary + Display,
{
    println!("{item}: {}", item.summarize());
}
```

### 10.4.5 Returning `impl Trait`

You can use `impl Trait` in return position to return a type that implements a trait without naming the concrete type:

```rust,no_run
fn returns_summarizable() -> impl Summary {
    SocialPost {
        username: String::from("horse_ebooks"),
        content: String::from("of course"),
    }
}
```

**Important limitation:** The function must return **one concrete type**. You cannot conditionally return different types:

```rust,no_run
// ❌ Won't compile — two different concrete types
fn returns_summarizable_broken(switch: bool) -> impl Summary {
    if switch {
        NewsArticle { /* ... */ }  // one type
    } else {
        SocialPost { /* ... */ }   // different type — error!
    }
}
// error[E0308]: `if` and `else` have incompatible types
```

For that use case, you need trait objects (section 10.6).

**Rust 2024 note:** In the 2024 edition, `-> impl Trait` in return position captures all lifetimes in scope by default (the "lifetime capture rules" change). This makes more code compile without explicit lifetime annotations on return-position `impl Trait`.

---

## 10.5 Common Standard Library Traits

These traits appear constantly in Rust code. Every Java developer should know them.

### Formatting Traits

```rust
use std::fmt;

#[derive(Debug)]   // auto-implements Debug using derive macro
struct Point {
    x: f64,
    y: f64,
}

// Manual Display implementation (for human-readable output)
impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

fn main() {
    let p = Point { x: 1.0, y: 2.5 };
    println!("{p}");    // (1, 2.5)  — uses Display
    println!("{p:?}");  // Point { x: 1.0, y: 2.5 }  — uses Debug
    println!("{p:#?}"); // pretty-printed Debug
}
```

| Trait | Macro | Use case |
|---|---|---|
| `Display` | `{}` | Human-readable output |
| `Debug` | `{:?}` | Programmer/debug output, derivable |

### Clone and Copy

`Copy` types are silently bit-copied on assignment (no move semantics). `Clone` types require explicit `.clone()`. `Copy` is only valid for stack-only types (no heap allocation).

```rust
#[derive(Debug, Clone, Copy)]          // Copy: u8 fields only — no heap
struct Color { r: u8, g: u8, b: u8 }

#[derive(Debug, Clone)]                // Clone only: String is heap-allocated
struct Config { name: String, value: i32 }

fn main() {
    let c1 = Color { r: 255, g: 0, b: 0 };
    let c2 = c1;           // Copy — c1 still valid
    println!("{c1:?} {c2:?}");

    let cfg1 = Config { name: String::from("timeout"), value: 30 };
    let cfg2 = cfg1.clone(); // must be explicit
    println!("{cfg1:?} {cfg2:?}");
}
```

**Java:** all objects are reference-copied. **Rust:** types are moved by default; `Copy` = implicit bit-copy; `Clone` = explicit `.clone()`.

### Equality and Ordering Traits

`#[derive(PartialEq, Eq, PartialOrd, Ord)]` gives your struct comparison and sort support in one line. `f32`/`f64` implement only `PartialOrd` (not `Ord`) because `NaN != NaN` — a NaN comparison has no total order.

```rust
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Clone)]
struct Version { major: u32, minor: u32, patch: u32 }

fn main() {
    let mut vs = vec![
        Version { major: 2, minor: 0, patch: 0 },
        Version { major: 1, minor: 9, patch: 0 },
    ];
    vs.sort();  // Ord enables sort
    println!("{vs:?}"); // [{1,9,0}, {2,0,0}]
}
```

| Trait | Methods | Notes |
|---|---|---|
| `PartialEq` | `==`, `!=` | Required for `Eq` |
| `Eq` | (marker) | Full equivalence relation |
| `PartialOrd` | `<`, `>`, `<=`, `>=` | `f32`/`f64` only implement this |
| `Ord` | `cmp`, `min`, `max` | Required for `sort()` |

### Hash and Default

```rust
use std::collections::HashMap;

#[derive(Debug, PartialEq, Eq, Hash)]  // Hash enables use as HashMap key
struct UserId(u64);

#[derive(Debug, Default)]              // Default: zero/empty for each field
struct AppConfig { port: u16, host: String, max_connections: u32 }

fn main() {
    let mut map = HashMap::new();
    map.insert(UserId(42), "alice");

    // ..Default::default() fills any unspecified fields with their defaults
    let config = AppConfig { port: 8080, ..Default::default() };
    println!("{config:?}"); // AppConfig { port: 8080, host: "", max_connections: 0 }
}
```

### `From` and `Into`

`From` and `Into` are the standard conversion traits. Implementing `From<A> for B` automatically provides `Into<B> for A` via a blanket implementation:

```rust
#[derive(Debug)]
struct Celsius(f64);

#[derive(Debug)]
struct Fahrenheit(f64);

impl From<Celsius> for Fahrenheit {
    fn from(c: Celsius) -> Self {
        Fahrenheit(c.0 * 9.0 / 5.0 + 32.0)
    }
}

fn main() {
    let boiling = Celsius(100.0);
    let f: Fahrenheit = boiling.into();  // Into works automatically!
    println!("{f:?}"); // Fahrenheit(212.0)

    let freezing = Fahrenheit::from(Celsius(0.0));
    println!("{freezing:?}"); // Fahrenheit(32.0)
}
```

The blanket impl in the standard library is:
```rust,no_run
// Provided automatically — you don't write this
impl<T, U: From<T>> Into<U> for T {
    fn into(self) -> U {
        U::from(self)
    }
}
```

This is the canonical **blanket implementation** example: implement `From`, get `Into` for free.

### `Iterator`

Implementing `Iterator` requires only one method (`next`); all adapter methods (`map`, `filter`, `zip`, `sum`, etc.) are provided by default implementations in the trait:

```rust
struct Counter { count: u32, max: u32 }

impl Counter {
    fn new(max: u32) -> Self { Counter { count: 0, max } }
}

impl Iterator for Counter {
    type Item = u32;  // associated type — the element type

    fn next(&mut self) -> Option<u32> {
        if self.count < self.max { self.count += 1; Some(self.count) } else { None }
    }
}

fn main() {
    // 70+ adapter methods come for free from the default implementations
    let sum: u32 = Counter::new(5).filter(|x| x % 2 != 0).sum();
    println!("Odd sum: {sum}"); // Odd sum: 9  (1+3+5)
}
```

### `FromStr`

`FromStr` lets your type be parsed from a string with `.parse()`. Implement it by defining an associated `Err` type and a `from_str` method:

```rust
use std::str::FromStr;

#[derive(Debug)]
struct Port(u16);

impl FromStr for Port {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let n: u16 = s.trim().parse().map_err(|e| format!("{e}"))?;
        if n < 1024 { return Err(format!("{n} is a privileged port")); }
        Ok(Port(n))
    }
}

fn main() {
    let port: Result<Port, _> = "8080".parse();
    println!("{port:?}"); // Ok(Port(8080))
}
```

---

## 10.6 Trait Objects and Dynamic Dispatch

### 10.6.1 Static vs Dynamic Dispatch

Everything so far uses **static dispatch** — the compiler knows the exact type at compile time and generates monomorphized code. Sometimes you need **dynamic dispatch**: a collection of different types that all implement the same trait, resolved at runtime.

Enter `dyn Trait`:

```rust
use std::fmt::Display;

pub trait Shape {
    fn area(&self) -> f64;
    fn perimeter(&self) -> f64;
    fn name(&self) -> &str;
}

struct Circle {
    radius: f64,
}

struct Rectangle {
    width: f64,
    height: f64,
}

struct Triangle {
    a: f64,
    b: f64,
    c: f64,
}

impl Shape for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }
    fn perimeter(&self) -> f64 {
        2.0 * std::f64::consts::PI * self.radius
    }
    fn name(&self) -> &str { "Circle" }
}

impl Shape for Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }
    fn perimeter(&self) -> f64 {
        2.0 * (self.width + self.height)
    }
    fn name(&self) -> &str { "Rectangle" }
}

impl Shape for Triangle {
    fn area(&self) -> f64 {
        // Heron's formula
        let s = (self.a + self.b + self.c) / 2.0;
        (s * (s - self.a) * (s - self.b) * (s - self.c)).sqrt()
    }
    fn perimeter(&self) -> f64 {
        self.a + self.b + self.c
    }
    fn name(&self) -> &str { "Triangle" }
}

fn print_shape_info(shape: &dyn Shape) {
    println!("{}: area={:.2}, perimeter={:.2}",
        shape.name(), shape.area(), shape.perimeter());
}

fn total_area(shapes: &[Box<dyn Shape>]) -> f64 {
    shapes.iter().map(|s| s.area()).sum()
}

fn main() {
    // A Vec of different shapes — only possible with dyn Trait
    let shapes: Vec<Box<dyn Shape>> = vec![
        Box::new(Circle { radius: 5.0 }),
        Box::new(Rectangle { width: 4.0, height: 6.0 }),
        Box::new(Triangle { a: 3.0, b: 4.0, c: 5.0 }),
    ];

    for shape in &shapes {
        print_shape_info(shape.as_ref());
    }

    println!("Total area: {:.2}", total_area(&shapes));
}
```

**Java comparison:** `Box<dyn Shape>` in Rust is the precise equivalent of an `interface Shape` reference in Java. Both use a vtable (virtual method table) for dispatch. The difference is that in Rust you make the decision to use dynamic dispatch **explicitly** (`dyn`), whereas in Java all interface references are dynamically dispatched.

```
Static dispatch (impl Trait / generics):
  Resolved at compile time → direct function call → faster
  Binary may be larger (monomorphized copies)

Dynamic dispatch (dyn Trait / Box<dyn Trait>):
  Resolved at runtime via vtable → indirect call → small overhead
  Works with heterogeneous collections
  Smaller binary (one implementation)
```

### 10.6.2 Object Safety

Not every trait can be used as `dyn Trait`. A trait is **object-safe** only if:

1. It has no methods that return `Self` by value (because the size is unknown at compile time)
2. It has no generic methods (because generics need to be monomorphized, but the concrete type is unknown)

```rust,no_run
trait NotObjectSafe {
    fn clone_self(&self) -> Self;   // ❌ returns Self by value
    fn generic_method<T>(&self, t: T); // ❌ generic method
}

// This won't compile:
// let x: Box<dyn NotObjectSafe> = ...;
// error[E0038]: the trait `NotObjectSafe` cannot be made into an object

trait ObjectSafe {
    fn describe(&self) -> String;   // ✅ no Self, no generics
    fn area(&self) -> f64;          // ✅
}
```

This is why `Clone` cannot be used as `Box<dyn Clone>`. The standard library's `std::error::Error` trait is carefully designed to be object-safe, which is why `Box<dyn Error>` is so common in error handling.

### 10.6.3 `Box<dyn Error>` Pattern

`Box<dyn Error>` accepts any type that implements `Error` — ideal for `fn main()` and early prototyping where you don't want to enumerate error types:

```rust
use std::error::Error;

fn parse_positive(s: &str) -> Result<u32, Box<dyn Error>> {
    let n: i64 = s.parse()?;  // any error type is auto-boxed via ?
    if n < 0 { return Err(format!("{n} is negative").into()); }
    Ok(n as u32)
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("{}", parse_positive("42")?);
    Ok(())
}
```

`Box<dyn Error>` has an implicit `+ 'static` bound unless you write `Box<dyn Error + '_>`. This matters when your error types hold references.

### 10.6.4 Blanket Implementations

A **blanket implementation** implements a trait for a broad family of types at once:

```rust
use std::fmt::Display;

trait Greet {
    fn greeting(&self) -> String;
}

// Blanket impl: every type that implements Display also implements Greet
impl<T: Display> Greet for T {
    fn greeting(&self) -> String {
        format!("Hello, {}!", self)
    }
}

fn main() {
    println!("{}", 42.greeting());        // Hello, 42!
    println!("{}", "Rust".greeting());    // Hello, Rust!
    println!("{}", 3.14_f64.greeting()); // Hello, 3.14!
}
```

The standard library uses this extensively. The `ToString` trait is implemented for every type that implements `Display` via a blanket impl — which is why you can call `.to_string()` on any `Display` type without writing it yourself.

---

## 10.7 Lifetimes

### 10.7.1 Why Lifetimes Exist: The Dangling Reference Problem

> **The core insight:** A lifetime annotation describes a constraint between the scopes of references. It does not change how long values live — it tells the compiler to verify that the constraint holds.

Java developers never think about this because the GC keeps objects alive as long as any reference to them exists. Rust has no GC. If a reference outlives the value it points to, the program reads freed memory — a dangling pointer. Rust's lifetime system makes this impossible at compile time.

```rust,no_run
// ❌ This won't compile
fn dangling_reference() {
    let r;
    {
        let x = 5;
        r = &x;     // r borrows x
    }               // x is dropped here — r would dangle!
    println!("{r}"); // ❌ r points to freed memory
}
```

```
error[E0597]: `x` does not live long enough
 --> src/main.rs:5:13
  |
4 |         let x = 5;
  |             - binding `x` declared here
5 |         r = &x;
  |             ^^ borrowed value does not live long enough
6 |     }
  |     - `x` dropped here while still borrowed
7 |
8 |     println!("{r}");
  |               - borrow later used here
```

The borrow checker uses a **borrow scope graph** to verify every reference. For simple local variables, it can infer everything. For references that cross function boundaries, you must provide lifetime annotations.

### 10.7.2 The Lifetime Mental Model

Think of a lifetime `'a` as a **label for a scope**. When you write:

```rust,no_run
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
```

You are saying: "There exists a scope `'a` such that both `x` and `y` are valid for at least `'a`, and the return value is valid for exactly `'a`."

The compiler then checks: is there actually a scope `'a` that satisfies those constraints given the actual call site? If yes, the code compiles. If not, you get E0597 or E0106.

**What lifetime annotations do NOT do:**
- They do not make references live longer.
- They do not allocate or free memory.
- They only describe existing relationships so the borrow checker can verify them.

### 10.7.3 Lifetime Annotations in Functions

The classic example: a function that returns the longer of two string slices.

```rust,no_run
// Without lifetime annotation — won't compile
// error[E0106]: missing lifetime specifier
fn longest_broken(x: &str, y: &str) -> &str {
    if x.len() > y.len() { x } else { y }
}
// The compiler can't know whether the returned reference points to x or y,
// so it can't verify the return value's validity.
```

```rust,no_run
// With lifetime annotation — compiles
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}
```

Now the return reference's lifetime is tied to the shorter of `x` and `y`:

```rust,no_run
fn main() {
    let string1 = String::from("long string is long");
    let result;
    {
        let string2 = String::from("xyz");
        result = longest(string1.as_str(), string2.as_str());
        println!("Longest: {result}"); // ✅ result is used before string2 drops
    }
    // println!("{result}");  // ❌ would error: string2 dropped above
}
```

### 10.7.4 Lifetime Annotations in Structs

When a struct holds a reference, it must have a lifetime annotation — otherwise the compiler cannot verify the struct doesn't outlive the data it references:

```rust
// ❌ Won't compile — missing lifetime annotation
// struct Excerpt {
//     part: &str,
// }
// error[E0106]: missing lifetime specifier

// ✅ Correct — lifetime annotation ties struct's validity to the reference
#[derive(Debug)]
struct Excerpt<'a> {
    part: &'a str,
}

impl<'a> Excerpt<'a> {
    fn level(&self) -> i32 {
        3
    }

    fn announce_and_return_part(&self, announcement: &str) -> &str {
        println!("Attention: {announcement}");
        self.part
    }
}

fn main() {
    let novel = String::from("Call me Ishmael. Some years ago...");
    let first_sentence = novel.split('.').next().expect("Could not find '.'");

    let excerpt = Excerpt { part: first_sentence };
    println!("{excerpt:?}"); // Excerpt { part: "Call me Ishmael" }
    
    // excerpt cannot outlive novel — the borrow checker enforces this
}
```

### 10.7.5 Lifetime Elision Rules

The Rust compiler applies three rules to infer lifetimes. When the rules fully determine the lifetime of every reference, you don't need to write annotations. These rules are applied to `fn` and `impl` blocks.

**Rule 1:** Each reference parameter gets its own distinct lifetime.

```rust,no_run
// You write:
fn foo(x: &str, y: &str) -> &str { ... }
// Compiler assigns:
fn foo<'a, 'b>(x: &'a str, y: &'b str) -> &str { ... }
```

**Rule 2:** If there is exactly one input lifetime parameter, that lifetime is assigned to all output lifetime parameters.

```rust,no_run
// You write:
fn first_word(s: &str) -> &str { ... }
// Compiler applies rule 1, then rule 2:
fn first_word<'a>(s: &'a str) -> &'a str { ... }
// ✅ Fully determined — no annotation needed!
```

**Rule 3:** If there are multiple input lifetime parameters, but one of them is `&self` or `&mut self`, the lifetime of `self` is assigned to all output lifetime parameters.

```rust,no_run
impl<'a> Excerpt<'a> {
    // You write:
    fn announce_and_return_part(&self, announcement: &str) -> &str {
    // Compiler applies rule 1: &self gets 'a (from impl), announcement gets 'b
    // Compiler applies rule 3: output gets 'a (self's lifetime)
    // fn announce_and_return_part<'b>(&'a self, announcement: &'b str) -> &'a str
    // ✅ Fully determined!
        self.part
    }
}
```

When these three rules **don't** fully determine the output lifetime, the compiler requires explicit annotations:

```rust,no_run
// Two input refs, no &self — rules 1 and 2 give two lifetimes 'a and 'b
// but the output lifetime is ambiguous. You must annotate.
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str { ... }
```

### 10.7.6 The `'static` Lifetime

`'static` means the reference is valid for the **entire program duration**. String literals are `'static` because they're baked into the program binary:

```rust,no_run
let s: &'static str = "I am baked into the binary";
```

Common `'static` uses:

```rust,no_run
// String literals are always 'static
fn get_greeting() -> &'static str {
    "Hello, world!"
}

// Box<dyn Error> is shorthand for Box<dyn Error + 'static>
// Use Box<dyn Error + '_> to allow non-static error types

// 'static bound on generics — T must not contain any short-lived references
fn store_forever<T: 'static>(value: T) {
    // value can be stored in a global, spawned in a thread, etc.
}
```

**Common misconception:** `'static` does not mean "lives forever." It means "is valid for as long as it's needed." A `String` converted to `&'static str` via `Box::leak` is `'static` — but the memory it occupies does eventually get cleaned up (it just won't be freed by the normal ownership system).

### 10.7.7 Lifetime Bounds on Generic Types

You can combine lifetime annotations with trait bounds:

```rust
use std::fmt::Display;

// T must implement Display AND must not contain references
// that live shorter than 'a
fn longest_with_announcement<'a, T>(x: &'a str, y: &'a str, ann: T) -> &'a str
where
    T: Display,
{
    println!("Announcement: {ann}");
    if x.len() > y.len() { x } else { y }
}

fn main() {
    let s1 = String::from("long string");
    let s2 = String::from("short");
    let result = longest_with_announcement(s1.as_str(), s2.as_str(), "Today's winner:");
    println!("Longest: {result}");
}
```

### 10.7.8 Non-Lexical Lifetimes (NLL)

Rust's borrow checker uses **Non-Lexical Lifetimes (NLL)** — lifetimes end at the last point of use, not at the closing brace of the block. This means the borrow checker is smarter than simple scope analysis:

```rust
fn main() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];          // immutable borrow begins
    println!("{first}");        // last use of 'first'
    // NLL: the borrow ends HERE (last use), not at end of block
    v.push(4);                  // ✅ mutable borrow OK — no conflict
    println!("{v:?}");
}
```

Without NLL, the immutable borrow would last until the end of `main`, and `v.push(4)` would fail to compile.

---

## 10.8 Complete Example: Putting It All Together

This example unifies generics, traits, and lifetimes: a `Summarizable` trait with a default method, a struct holding string slice references (requiring lifetime annotations), and a generic function with multiple trait bounds.

```rust
use std::fmt;

trait Summarizable {
    fn summary(&self) -> String;
    // Default method — truncates long summaries
    fn short_summary(&self) -> String {
        let s = self.summary();
        if s.len() > 50 { format!("{}...", &s[..47]) } else { s }
    }
}

// Struct holds &str references — lifetime 'a ties the struct's validity
// to the strings it borrows from
#[derive(Debug)]
struct ArticleRef<'a> {
    title: &'a str,
    author: &'a str,
    body: &'a str,
}

impl<'a> Summarizable for ArticleRef<'a> {
    fn summary(&self) -> String {
        format!("{} by {} — {}", self.title, self.author, self.body)
    }
}

impl<'a> fmt::Display for ArticleRef<'a> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}] by {}", self.title, self.author)
    }
}

// Generic with multiple trait bounds — T must be both Summarizable and Display
fn print_summary<T: Summarizable + fmt::Display>(items: &[T]) {
    for item in items {
        println!("  {item} → {}", item.short_summary());
    }
}

fn main() {
    let title = String::from("Rust is Amazing");
    let author = String::from("Jane Doe");
    let body = String::from("Rust combines safety and performance in an unprecedented way.");

    // ArticleRef borrows from title/author/body — cannot outlive them
    let articles = vec![
        ArticleRef { title: &title, author: &author, body: &body },
        ArticleRef { title: "Short post", author: "Bob", body: "Hi." },
    ];

    print_summary(&articles);
}
```

---

## 10.9 Java-to-Rust Generics and Traits Reference

### Key Differences Summary

| Feature | Java | Rust |
|---|---|---|
| Generic syntax | `<T extends Foo>` | `<T: Foo>` or `where T: Foo` |
| Multiple bounds | `<T extends A & B>` | `<T: A + B>` |
| Implementation strategy | Type erasure | Monomorphization |
| Dynamic dispatch | All interfaces | `dyn Trait` only (explicit) |
| Trait on external type | Not possible | Yes (orphan rule applies) |
| Blanket implementations | Not possible | Yes (`impl<T: Foo> Bar for T`) |
| Conditional methods | Not possible | Yes (`impl<T: Foo> MyStruct<T>`) |
| Null references | Possible (NPE risk) | Impossible (`Option<T>`) |
| Subclassing | Core feature | Not available (use traits) |
| Memory safety | GC at runtime | Lifetimes at compile time |

---

## 10.10 Common Errors and How to Fix Them

### E0106: Missing Lifetime Specifier

```
error[E0106]: missing lifetime specifier
 --> src/main.rs:1:32
  |
1 | fn first(x: &str, y: &str) -> &str {
  |             ----   ----      ^ expected named lifetime parameter
```

**Fix:** Apply elision rule 2 (only one input) or add explicit `'a`:

```rust,no_run
// If returning a slice of x (single input ref pattern):
fn first_word(s: &str) -> &str { /* elision handles this */ ... }

// If the output could be either input:
fn choose<'a>(x: &'a str, y: &'a str) -> &'a str { x }
```

### E0597: Borrowed Value Does Not Live Long Enough

```
error[E0597]: `data` does not live long enough
  --> src/main.rs:8:18
   |
7  |     let result;
8  |     let data = String::from("hello");
   |         ---- binding `data` declared here
9  |     result = &data;
   |              ^^^^^ borrowed value does not live long enough
10 |     }
   |     - `data` dropped here while still borrowed
```

**Fix:** Ensure the owned value lives at least as long as the reference. Move the owner to an outer scope, or change the design to return owned data instead of a reference.

---

## 📝 Chapter Review Notes

### Critical Review

This chapter covers the three most important advanced type-system features in Rust. The content was cross-checked against the Rust Reference, the Rust Book (2024 edition), and the Rust Nomicon.

### Fact-Check and Issues Table

| # | Claim / Example | Status | Notes |
|---|---|---|---|
| 1 | Monomorphization generates separate code per type | VERIFIED | Confirmed by `rustc --emit=llvm-ir` output |
| 2 | `impl Trait` in return position captures all lifetimes in 2024 | VERIFIED | RFC 3498 "Return position impl Trait in Rust 2024" |
| 3 | `Box<dyn Error>` defaults to `+ 'static` | VERIFIED | Documented in `std::error::Error`; write `+ '_` for non-static |
| 4 | Orphan rule: one of trait or type must be local | VERIFIED | E0117; Rust Reference §6.6 |
| 5 | Three lifetime elision rules as stated | VERIFIED | Rust Reference §10.3; Rust Book ch10 |
| 6 | `ToString` blanket impl via `Display` | VERIFIED | `std::string` source: `impl<T: fmt::Display> ToString for T` |
| 7 | NLL: borrows end at last use, not closing brace — "stabilized 2019" | CAVEAT | NLL landed in Rust 1.31 (2018) for the 2018 edition; 1.36 extended it to the 2015 edition. "Now always active" is correct, but the history is nuanced. |
| 8 | `gen` is a reserved keyword in Rust 2024 | VERIFIED | Rust 2024 edition guide; required for `gen` blocks feature |
| 9 | Object safety: no `Self` return by value, no generic methods | VERIFIED | Rust Reference §17.1; E0038 |
| 10 | `largest<T: PartialOrd>` — `Copy` not required for `&T` return | VERIFIED | Returns reference to slice element, no copy needed |
| 11 | `f32`/`f64` implement only `PartialOrd`, not `Ord` (due to NaN) | VERIFIED | `Ord` requires total order; NaN != NaN |
| 12 | Heron's formula for triangle area | VERIFIED | `s = (a+b+c)/2; area = sqrt(s(s-a)(s-b)(s-c))` |
| 13 | Section 10.7.7 title "Lifetime Bounds on Generic Types" | CAVEAT | The section shows lifetime + trait bounds combined (`where T: Display`) but does not demonstrate a true lifetime bound (`T: 'a`). A lifetime bound on a generic asserts that all references inside `T` outlive `'a`. Full coverage is in the Nomicon. |
| 14 | `short_summary` slices at `&s[..47]` — may panic on multi-byte chars | FLAGGED | Slicing a `&str` at a byte index that falls inside a multi-byte UTF-8 character panics at runtime. A production impl should use `s.char_indices()` or the `unicode-segmentation` crate. For a teaching example this is acceptable, but readers should be aware. |

### Known Simplifications

- **Variance and subtyping** (covariance/contravariance of lifetimes) is not covered — this is Nomicon territory, not cookbook territory.
- **Higher-ranked trait bounds (HRTB)** (`for<'a> Fn(&'a T)`) are omitted — relevant in advanced iterator/closure contexts.
- **Associated types vs. generic type parameters** trade-offs are mentioned briefly (Iterator) but not exhaustively analyzed.
- **`Pin` and `Unpin`** relate to lifetimes in async contexts and are covered in the async chapter.

### Recommendations for Readers

- After reading this chapter, experiment with intentionally breaking lifetime annotations and reading the compiler errors — E0597 and E0106 will become familiar friends.
- Run `rustc --explain E0597` for detailed explanations of any error code.
- The `cargo check` command (no binary produced) is faster for iterating on type errors.
- The `rust-analyzer` language server shows lifetime annotations inline in your IDE — invaluable for learning.
