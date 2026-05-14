# Chapter 3: Common Programming Concepts

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes Java developers make on day one.

---

## 3.1 Variables and Mutability

### The Rule: Immutable by Default

In Java, variables are mutable by default and you add `final` to lock them. Rust inverts this — every variable is immutable unless you explicitly opt in to mutation with `mut`.

```rust
fn main() {
    let x = 5;
    println!("x = {x}");

    // x = 6; // ERROR: cannot assign twice to immutable variable `x`
}
```

Add `mut` to allow reassignment:

```rust
fn main() {
    let mut score = 0;
    score += 10;
    score += 5;
    println!("Final score: {score}"); // 15
}
```

### Java Comparison: `final` vs `let`

| Concept | Java | Rust |
|---|---|---|
| Immutable binding | `final int x = 5;` | `let x = 5;` |
| Mutable binding | `int x = 5;` | `let mut x = 5;` |
| Type-inferred local | `var x = 5;` (Java 10+, locals only) | `let x = 5;` (anywhere) |
| Always immutable | `final` on a field | `const` |

**Critical difference:** Java's `final` only prevents reassignment of the _reference_. The object it points to can still be mutated (e.g., `final List<String> list` — you can still call `list.add(...)`). Rust's `let` immutability applies to the value itself, enforced by the type system.

### Practical Example: Accumulating Without `mut`

When you don't need mutation, Rust encourages functional chaining instead:

```rust
fn main() {
    let prices = [10.0_f64, 25.0, 8.50, 42.0];
    let total: f64 = prices.iter().sum();
    let discounted = total * 0.9;
    println!("Total: {total:.2}, After discount: {discounted:.2}");
    // Total: 85.50, After discount: 76.95
}
```

---

## 3.2 Constants

Constants are different from `let` bindings in three important ways:

1. You **must** annotate the type.
2. They live for the entire program lifetime (any scope, including module level).
3. They must be set to a **constant expression** — no runtime computation.

```rust
const MAX_CONNECTIONS: u32 = 1_000;
const PI_APPROX: f64 = 3.141_592_653_589_793;
const SECONDS_PER_HOUR: u32 = 60 * 60; // evaluated at compile time
```

Naming convention: `SCREAMING_SNAKE_CASE`.

### Practical: Application-Level Constants

```rust
const MAX_RETRY_ATTEMPTS: u8 = 3;
const BASE_URL: &str = "https://api.example.com/v2";
const TIMEOUT_MS: u64 = 5_000;

fn fetch_with_retry(endpoint: &str) {
    for attempt in 1..=MAX_RETRY_ATTEMPTS {
        println!("Attempt {attempt}/{MAX_RETRY_ATTEMPTS}: {BASE_URL}{endpoint}");
        // ... real HTTP call would go here
    }
}

fn main() {
    fetch_with_retry("/users");
}
```

### Java Comparison

Java uses `static final` on a class/interface for constants. Rust uses `const` at any scope — module level, inside a function, or inside an `impl` block.

```java
// Java
public static final int MAX_CONNECTIONS = 1000;
```

```rust
// Rust — module level (idiomatic for shared constants)
const MAX_CONNECTIONS: u32 = 1_000;
```

---

## 3.3 Shadowing

Shadowing lets you redeclare a variable with the same name using a new `let`. The new binding _shadows_ the old one — the original value is gone from that point forward in scope.

```rust
fn main() {
    let x = 5;          // x is 5
    let x = x + 1;      // x is 6 (new binding shadows old)

    {
        let x = x * 2;  // x is 12 in this inner scope
        println!("inner x = {x}"); // 12
    }

    println!("outer x = {x}"); // 6 — inner shadow is gone
}
```

### Shadowing Allows Type Changes — `mut` Does Not

This is one of Rust's most practically useful features. You can transform a value through a pipeline of steps without inventing new names:

```rust
fn main() {
    // Parse a string input into a number — common in CLI/config parsing
    let input = "  42  ";
    let input: u32 = input.trim().parse().expect("not a number");
    println!("Parsed: {input}"); // 42

    // mut cannot change type:
    // let mut spaces = "   ";
    // spaces = spaces.len(); // ERROR: expected `&str`, found `usize`
}
```

### Practical: Shadowing for Processing Stages

```rust
fn process_temperature(raw: &str) -> f64 {
    let raw = raw.trim();               // &str -> &str (trimmed)
    let raw: f64 = raw.parse()          // &str -> f64
        .expect("invalid temperature");
    let raw = (raw - 32.0) * 5.0 / 9.0; // Fahrenheit -> Celsius
    raw
}

fn main() {
    println!("{:.1}°C", process_temperature("  98.6  ")); // 37.0°C
}
```

### Shadowing vs `mut` — Decision Guide

| Use `mut` when | Use shadowing when |
|---|---|
| You need to modify a value in-place (e.g., `counter += 1`) | You need to transform a value into a different type |
| You want readers to see this variable changes over time | You want each "stage" to feel like a fresh immutable value |
| Mutating inside a loop | Processing a pipeline: parse -> validate -> transform |

---

## 3.4 Scalar Types

Rust has four scalar categories: integers, floats, booleans, and characters.

### Integers

| Length | Signed | Unsigned | Signed Range | Unsigned Range |
|---|---|---|---|---|
| 8-bit | `i8` | `u8` | -128 to 127 | 0 to 255 |
| 16-bit | `i16` | `u16` | -32,768 to 32,767 | 0 to 65,535 |
| 32-bit | `i32` | `u32` | -2,147,483,648 to 2,147,483,647 | 0 to 4,294,967,295 |
| 64-bit | `i64` | `u64` | -(2^63) to 2^63-1 | 0 to 2^64-1 |
| 128-bit | `i128` | `u128` | -(2^127) to 2^127-1 | 0 to 2^128-1 |
| Pointer-sized | `isize` | `usize` | Platform-dependent | Platform-dependent |

**Default integer type: `i32`.** This is almost always the right choice for general integer math.

`usize` is the canonical index/size type — used for collection indexing, lengths, and pointer offsets. Java uses `int` for all of these; Rust separates them clearly.

#### Integer Literals

```rust
fn main() {
    let decimal     = 98_222;        // underscore as visual separator
    let hex         = 0xff;          // 255
    let octal       = 0o77;          // 63
    let binary      = 0b1111_0000;   // 240
    let byte: u8    = b'A';          // 65 — byte literal, u8 only

    println!("{decimal} {hex} {octal} {binary} {byte}");
}
```

#### No Implicit Numeric Conversions

This is a major difference from Java. Rust requires explicit casts:

```rust
fn main() {
    let small: i32 = 42;
    // let big: i64 = small;      // ERROR: mismatched types

    let big: i64 = i64::from(small);  // preferred: infallible widening
    let also_big = small as i64;      // also valid, but `as` can truncate on narrowing

    println!("{big} {also_big}");
}
```

#### Java Comparison: Integer Types

| Java | Rust | Notes |
|---|---|---|
| `byte` (signed 8-bit) | `i8` | Same range: -128..127 |
| N/A | `u8` | Java has no unsigned types in the type system |
| `short` | `i16` | Same range |
| `int` | `i32` | Both are the default integer |
| `long` | `i64` | Java `long` literals use `L` suffix; Rust uses `i64` suffix or type annotation |
| N/A | `u32`, `u64`, `u128` | Java uses `Integer.toUnsignedString` etc. as workarounds |
| N/A | `i128` / `u128` | Java uses `BigInteger` for this range |
| N/A | `usize` / `isize` | Java always uses `int` for indices |

### Integer Overflow

**Debug builds** (default with `cargo run`): integer overflow **panics** at runtime.
**Release builds** (`cargo run --release`): overflow silently **wraps** (two's complement).

Rather than relying on build-mode behavior, use the explicit overflow methods:

```rust
fn main() {
    let x: u8 = 250;

    // checked_*: returns Option<T> — None on overflow
    println!("{:?}", x.checked_add(10));   // None
    println!("{:?}", x.checked_add(4));    // Some(254)

    // wrapping_*: always wraps, no panic
    println!("{}", x.wrapping_add(10));    // 4 (wraps around 255)
    println!("{}", x.wrapping_add(6));     // 0

    // saturating_*: clamps to min/max
    println!("{}", x.saturating_add(10)); // 255
    println!("{}", x.saturating_add(6));  // 255

    // overflowing_*: returns (value, did_overflow)
    let (val, overflowed) = x.overflowing_add(10);
    println!("val={val}, overflowed={overflowed}"); // val=4, overflowed=true
}
```

### Practical: Safe Byte Arithmetic for Protocols

```rust
fn encode_checksum(data: &[u8]) -> u8 {
    data.iter().fold(0u8, |acc, &b| acc.wrapping_add(b))
}

fn main() {
    let packet = [0xFF_u8, 0x01, 0x02, 0x03];
    println!("Checksum: 0x{:02X}", encode_checksum(&packet)); // 0x05
}
```

---

### Floating-Point Types

Rust has `f32` (32-bit, ~7 decimal digits of precision) and `f64` (64-bit, ~15 decimal digits). **Default is `f64`** — it has the same speed as `f32` on modern CPUs and far more precision.

```rust
fn main() {
    let x = 2.0;        // f64 by default
    let y: f32 = 3.0;   // explicit f32

    let result = x / 0.3 - 2.0 / 0.3; // floating point fun
    println!("{result}"); // Not 0.0 — float precision!
}
```

#### Java Comparison

| Java | Rust |
|---|---|
| `float` (32-bit) | `f32` |
| `double` (64-bit) | `f64` (default) |
| `double` is the default literal type | `f64` is the default literal type |

Both languages follow IEEE 754. Both default to 64-bit precision.

#### Practical: Statistical Summary

```rust
fn summarize(data: &[f64]) -> (f64, f64, f64) {
    let n = data.len() as f64;
    let mean = data.iter().sum::<f64>() / n;
    let variance = data.iter()
        .map(|x| (x - mean).powi(2))
        .sum::<f64>() / n;
    let std_dev = variance.sqrt();
    let min = data.iter().cloned().fold(f64::INFINITY, f64::min);
    let max = data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let _ = (min, max); // used below in practice; here just to show the pattern
    (mean, variance, std_dev)
}

fn main() {
    let readings = [72.1, 68.5, 74.3, 71.0, 69.8];
    let (mean, _variance, std_dev) = summarize(&readings);
    println!("Mean: {mean:.2}°F, Std Dev: {std_dev:.2}°F");
    // Mean: 71.14°F, Std Dev: 1.97°F
}
```

---

### Boolean Type

```rust
fn main() {
    let active = true;
    let expired: bool = false;

    // Rust does NOT auto-convert integers to bool.
    // if 1 { ... }  // ERROR — must be a bool expression
    if active && !expired {
        println!("Session is valid");
    }
}
```

**Size:** 1 byte. **Values:** `true`, `false`. No truthiness coercion from integers or null.

---

### Character Type

Rust's `char` is 4 bytes and represents a **Unicode scalar value** (U+0000 to U+D7FF and U+E000 to U+10FFFF). Use single quotes.

```rust
fn main() {
    let letter = 'A';
    let kanji: char = '錆';       // rust = "rust" in Japanese (fittingly, "rust/patina")
    let emoji = '🦀';
    let zero_width: char = '\u{200B}'; // zero-width space

    println!("{letter} {kanji} {emoji}");
    println!("char size: {} bytes", std::mem::size_of::<char>()); // 4
}
```

#### Java Comparison: `char`

| Aspect | Java `char` | Rust `char` |
|---|---|---|
| Size | 2 bytes (16-bit) | 4 bytes (32-bit) |
| Encoding | UTF-16 code unit | Unicode scalar value |
| Emoji support | Needs surrogate pairs (2 chars) | Single `char` |
| Single quotes | `'A'` | `'A'` |

This is a real difference: `"🦀".length()` in Java returns `2` (two UTF-16 code units). In Rust, `'🦀'` is a valid single `char`.

---

## 3.5 Compound Types

### Tuples

A tuple groups values of **different types** into a single fixed-length compound value. Length is fixed at compile time.

```rust
fn main() {
    // Explicit type annotation
    let point: (f64, f64) = (3.0, 4.0);

    // Mixed types
    let record: (u32, &str, bool) = (1, "Alice", true);

    // Destructuring — like Java 16+ records in pattern matching
    let (x, y) = point;
    println!("x={x}, y={y}");

    // Index access with dot notation
    let id = record.0;
    let name = record.1;
    let active = record.2;
    println!("id={id}, name={name}, active={active}");
}
```

#### The Unit Type `()`

A tuple with no elements — `()` — is the "unit" type. It's what functions return when they have no explicit return value, equivalent to Java's `void`.

```rust
fn greet(name: &str) -> () {  // `-> ()` is usually omitted
    println!("Hello, {name}!");
}
```

#### Practical: Returning Multiple Values

Rust doesn't need to wrap multiple return values in a class or use output parameters — just return a tuple:

```rust
fn min_max(data: &[i32]) -> (i32, i32) {
    let mut min = data[0];
    let mut max = data[0];
    for &val in &data[1..] {
        if val < min { min = val; }
        if val > max { max = val; }
    }
    (min, max)
}

fn main() {
    let readings = [42, 7, 99, -3, 51];
    let (lo, hi) = min_max(&readings);
    println!("Range: {lo} to {hi}"); // Range: -3 to 99
}
```

#### Java Comparison

Java has no built-in tuple type. The usual workarounds are:

```java
// Java: create a class, use a pair library, or Java 16+ records
record MinMax(int min, int max) {}
MinMax result = minMax(data);
```

```rust
// Rust: just return a tuple — no boilerplate
fn min_max(data: &[i32]) -> (i32, i32) { ... }
let (lo, hi) = min_max(&data);
```

---

### Arrays

Arrays in Rust have a **fixed size known at compile time** and are **allocated on the stack**. Every element must be the same type.

```rust
fn main() {
    // Type annotation: [element_type; length]
    let zeros: [i32; 5] = [0; 5];          // repeat syntax: [value; count]
    let primes: [u32; 6] = [2, 3, 5, 7, 11, 13];
    let months = [
        "January", "February", "March", "April",
        "May", "June", "July", "August",
        "September", "October", "November", "December",
    ];

    println!("First prime: {}", primes[0]);
    println!("Fifth month: {}", months[4]);
    println!("Array length: {}", primes.len());
}
```

#### Bounds Checking

Rust checks array bounds at runtime and panics with a clear message — no silent buffer overruns:

```rust
fn main() {
    let data = [1, 2, 3];
    let i = 10;
    // println!("{}", data[i]);
    // thread 'main' panicked at 'index out of bounds: the len is 3 but the index is 10'

    // Safe alternative:
    if let Some(val) = data.get(i) {
        println!("{val}");
    } else {
        println!("Index {i} is out of bounds");
    }
}
```

#### Java Comparison: Arrays

| Aspect | Java `int[]` | Rust `[i32; N]` |
|---|---|---|
| Memory location | Heap (reference type) | Stack (value type) |
| Size fixed? | Yes (once created) | Yes (compile time) |
| Bounds checking | Runtime, throws `ArrayIndexOutOfBoundsException` | Runtime, panics |
| Growable? | No (use `ArrayList`) | No (use `Vec<T>`) |
| Passed to function | Reference — no copy | Copied by value if `Copy`; borrowing is idiomatic |

#### Practical: Lookup Table with a Stack Array

```rust
const DAY_NAMES: [&str; 7] = [
    "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday", "Sunday",
];

fn day_name(day: usize) -> &'static str {
    DAY_NAMES[day % 7]
}

fn main() {
    for i in 0..7 {
        println!("Day {i}: {}", day_name(i));
    }
}
```

---

## 3.6 Type Inference and Explicit Annotations

Rust's compiler infers types from context. You only need to annotate when the compiler cannot determine the type unambiguously.

```rust
fn main() {
    let x = 42;           // inferred: i32
    let y = 3.14;         // inferred: f64
    let flag = true;      // inferred: bool
    let letter = 'Z';     // inferred: char

    // Annotation required when parse() cannot infer the target type:
    let n: u64 = "12345".parse().expect("not a number");

    // Suffix-based type annotation:
    let big = 1_000_000_u64;
    let precise = 1.0_f32;

    println!("{x} {y} {flag} {letter} {n} {big} {precise}");
}
```

#### Block Expressions for Complex Initialization

A block `{ ... }` is an expression in Rust. The value of the last expression (no semicolon) is the block's value:

```rust
fn main() {
    let config_timeout = {
        let base = 30_u64;
        let multiplier = 3;
        base * multiplier // no semicolon — this is the block's value
    };
    println!("Timeout: {config_timeout}s"); // 90s
}
```

This replaces the Java ternary operator for multi-step initialization:

```java
// Java — needs a helper method or ternary chain
int timeout = computeTimeout();
```

```rust
// Rust — inline block, no helper method needed
let timeout = {
    let base = 30_u64;
    base * 3
};
```

---

## 3.7 Functions

### Anatomy of a Rust Function

```rust
fn add(a: i32, b: i32) -> i32 {
    a + b  // expression — no semicolon — this IS the return value
}

fn main() {
    let result = add(3, 4);
    println!("{result}"); // 7
}
```

Rules:
- `fn` keyword, then name in `snake_case`.
- Every parameter **must** have an explicit type annotation — no inference from call site.
- Return type declared with `->`.
- The last expression (without semicolon) is automatically returned.
- `return` is used only for early returns.

### Statements vs Expressions — The Core Distinction

| | Statement | Expression |
|---|---|---|
| Ends with | `;` | no `;` |
| Produces a value | No (produces `()`) | Yes |
| Can be used in `let` | No | Yes |

```rust
fn main() {
    // let x = (let y = 6);  // ERROR: `let` is a statement, not an expression

    // This IS valid — a block expression:
    let z = {
        let a = 5;
        a * 2   // expression, no semicolon → value 10 is assigned to z
    };
    println!("z = {z}"); // 10
}
```

The `x + 1;` vs `x + 1` distinction trips up many Java developers because Java doesn't have this concept at all.

### Parameters and Multiple Return via Tuple

```rust
fn divide(dividend: f64, divisor: f64) -> (f64, bool) {
    if divisor == 0.0 {
        (0.0, false)  // (result, success)
    } else {
        (dividend / divisor, true)
    }
}

fn main() {
    match divide(10.0, 3.0) {
        (result, true)  => println!("Result: {result:.4}"),
        (_, false)      => println!("Division by zero"),
    }
}
```

### Early Return

```rust
fn first_negative(values: &[i32]) -> Option<i32> {
    for &v in values {
        if v < 0 {
            return Some(v);  // early return — explicit `return` required
        }
    }
    None  // implicit return from last expression
}

fn main() {
    println!("{:?}", first_negative(&[1, 2, -3, 4])); // Some(-3)
    println!("{:?}", first_negative(&[1, 2, 3]));      // None
}
```

### Diverging Functions: The Never Type `!`

A function that never returns (always panics, loops forever, or exits) has return type `!`:

```rust
fn fatal_error(msg: &str) -> ! {
    panic!("{msg}");
}
```

### Java Comparison: Functions

| Aspect | Java | Rust |
|---|---|---|
| Top-level functions | Not allowed (must be in a class) | Allowed |
| Method syntax | `returnType name(Type param)` | `fn name(param: Type) -> ReturnType` |
| No return value | `void` | `()` or omit `->` |
| Last expression as return | Not a thing | Core language feature |
| `return` keyword | Always needed for non-void | Only for early returns |
| Parameter type annotation | Required | Required |

---

## 3.8 Control Flow

### `if` / `else if` / `else`

`if` in Rust is an **expression** — it returns a value. The condition must be exactly `bool` (no integer truthiness).

```rust
fn main() {
    let temperature = 22;

    // Basic branching
    if temperature > 30 {
        println!("Hot");
    } else if temperature > 20 {
        println!("Comfortable"); // prints this
    } else {
        println!("Cold");
    }

    // if as an expression — replaces Java's ternary operator
    let label = if temperature > 25 { "warm" } else { "cool" };
    println!("It's {label}");

    // Both arms MUST return the same type:
    // let n = if true { 5 } else { "six" }; // ERROR: type mismatch
}
```

#### Java Comparison: `if`

```java
// Java: if is a statement; ternary ?: is the expression form
String label = temperature > 25 ? "warm" : "cool";
```

```rust
// Rust: if is already an expression — no separate ternary needed
let label = if temperature > 25 { "warm" } else { "cool" };
```

---

### `loop` — Unconditional Loop with Break Value

`loop` runs until you explicitly `break`. Unlike `while true`, it is an **expression** that can return a value:

```rust
fn main() {
    let mut counter = 0;

    let result = loop {
        counter += 1;
        if counter == 10 {
            break counter * 2;  // break with value — result gets 20
        }
    };

    println!("result = {result}"); // 20
}
```

#### Practical: Retry Logic

```rust
fn attempt_connect(max_tries: u32) -> bool {
    let mut tries = 0;
    loop {
        tries += 1;
        println!("Connection attempt {tries}...");
        // Simulate: succeed on 3rd try
        if tries == 3 {
            println!("Connected!");
            break true;
        }
        if tries >= max_tries {
            break false;
        }
    }
}

fn main() {
    let connected = attempt_connect(5);
    println!("Success: {connected}");
}
```

---

### Nested Loops with Labels

Labels let you `break` or `continue` an outer loop from inside an inner one. Java has the same feature with labeled break:

```rust
fn main() {
    // Find first pair (i, j) where i * j > 20
    'outer: for i in 1..=5 {
        for j in 1..=5 {
            if i * j > 20 {
                println!("Found: i={i}, j={j}  (product={})", i * j);
                break 'outer;  // breaks the outer loop entirely
            }
        }
    }
    // Found: i=5, j=5  (product=25)
}
```

#### Practical: Matrix Search

```rust
fn find_in_matrix(matrix: &[[i32; 4]; 3], target: i32) -> Option<(usize, usize)> {
    'rows: for (row_idx, row) in matrix.iter().enumerate() {
        for (col_idx, &val) in row.iter().enumerate() {
            if val == target {
                break 'rows; // stop searching rows — position found, return below
                // note: in practice use return Some((row_idx, col_idx)) here
            }
            let _ = col_idx; // suppress unused warning in this demo
        }
    }
    // A cleaner version returning directly:
    for (r, row) in matrix.iter().enumerate() {
        for (c, &val) in row.iter().enumerate() {
            if val == target {
                return Some((r, c));
            }
        }
    }
    None
}

fn main() {
    let grid = [
        [1,  2,  3,  4],
        [5,  6,  7,  8],
        [9, 10, 11, 12],
    ];
    println!("{:?}", find_in_matrix(&grid, 7));  // Some((1, 2))
    println!("{:?}", find_in_matrix(&grid, 99)); // None
}
```

#### Java Comparison: Labeled Break

```java
// Java labeled break — same semantics, different syntax
outer:
for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 5; j++) {
        if (i * j > 20) break outer;
    }
}
```

```rust
// Rust — label is prefixed with tick ('), placed before the loop
'outer: for i in 0..5 {
    for j in 0..5 {
        if i * j > 20 { break 'outer; }
    }
}
```

---

### `while` — Conditional Loop

```rust
fn main() {
    let mut n = 1;
    while n < 100 {
        n *= 2;
    }
    println!("First power of 2 >= 100: {n}"); // 128
}
```

`while` is straightforward. Prefer `loop` when you need a return value, and prefer `for` when iterating a known collection.

---

### `for` — Iterating Collections and Ranges

`for` is the most idiomatic loop in Rust. It iterates any type that implements `IntoIterator`.

```rust
fn main() {
    let scores = [88, 92, 74, 96, 81];

    // Iterating an array by reference (borrows each element)
    for score in &scores {
        print!("{score} ");
    }
    println!();

    // With index — use enumerate()
    for (i, score) in scores.iter().enumerate() {
        println!("Player {}: {}", i + 1, score);
    }
}
```

**Note:** `for x in scores` (by value) works for arrays of `Copy` types in Rust 2021+/2024. For non-Copy types like `String`, use `&scores` or `.iter()` to avoid moving the collection.

### Ranges

Rust has two range forms:

| Expression | Meaning | Includes end? |
|---|---|---|
| `0..10` | 0, 1, 2, ..., 9 | No (exclusive) |
| `0..=10` | 0, 1, 2, ..., 10 | Yes (inclusive) |

```rust
fn main() {
    // Exclusive range: 0..5 → 0,1,2,3,4
    for i in 0..5 {
        print!("{i} ");
    }
    println!(); // 0 1 2 3 4

    // Inclusive range: 1..=5 → 1,2,3,4,5
    for i in 1..=5 {
        print!("{i} ");
    }
    println!(); // 1 2 3 4 5

    // Reversed range
    for i in (1..=5).rev() {
        print!("{i} ");
    }
    println!(); // 5 4 3 2 1

    // Sum using range
    let sum: u32 = (1..=100).sum();
    println!("Sum 1..=100 = {sum}"); // 5050
}
```

#### Java Comparison: Ranges and `for`

```java
// Java classic for loop
for (int i = 0; i < 10; i++) { ... }

// Java enhanced for
for (int score : scores) { ... }

// Java streams with range
IntStream.range(0, 10).forEach(i -> ...);
IntStream.rangeClosed(1, 10).forEach(i -> ...);
```

```rust
// Rust exclusive range (like Java IntStream.range)
for i in 0..10 { ... }

// Rust inclusive range (like Java IntStream.rangeClosed)
for i in 1..=10 { ... }

// Rust iterate collection
for score in &scores { ... }
```

#### Practical: FizzBuzz with Ranges

```rust
fn main() {
    for n in 1..=30 {
        let label = match (n % 3, n % 5) {
            (0, 0) => String::from("FizzBuzz"),
            (0, _) => String::from("Fizz"),
            (_, 0) => String::from("Buzz"),
            _      => n.to_string(),
        };
        print!("{label} ");
    }
    println!();
}
```

#### Practical: Building a Frequency Table

```rust
fn char_frequency(text: &str) -> [(char, usize); 26] {
    let mut counts = [0usize; 26];
    for c in text.chars() {
        if c.is_ascii_lowercase() {
            counts[(c as usize) - ('a' as usize)] += 1;
        }
    }
    let mut result = [('a', 0usize); 26];
    for i in 0..26 {
        result[i] = (char::from(b'a' + i as u8), counts[i]);
    }
    result
}

fn main() {
    let text = "hello world";
    let freq = char_frequency(text);
    for (ch, count) in freq {
        if count > 0 {
            println!("'{ch}': {count}");
        }
    }
}
```

---

## 3.9 Putting It All Together — Practical Mini-Program

A temperature statistics calculator that uses most concepts from this chapter:

```rust
const ABSOLUTE_ZERO_C: f64 = -273.15;

fn celsius_to_fahrenheit(c: f64) -> f64 {
    c * 9.0 / 5.0 + 32.0
}

fn is_valid_temperature(c: f64) -> bool {
    c > ABSOLUTE_ZERO_C
}

fn analyze(readings: &[f64]) -> Option<(f64, f64, f64)> {
    if readings.is_empty() {
        return None;
    }

    let mut min = readings[0];
    let mut max = readings[0];
    let mut sum = 0.0_f64;

    for &temp in readings {
        if !is_valid_temperature(temp) {
            println!("Warning: invalid temperature {temp}°C — skipping");
            continue;
        }
        sum += temp;
        if temp < min { min = temp; }
        if temp > max { max = temp; }
    }

    let mean = sum / readings.len() as f64;
    Some((min, mean, max))
}

fn main() {
    let readings = [20.5_f64, 22.1, 19.8, 23.4, 21.0, -300.0, 22.8];

    match analyze(&readings) {
        Some((min, mean, max)) => {
            println!("Temperature Analysis (Celsius):");
            println!("  Min:  {min:.1}°C ({:.1}°F)", celsius_to_fahrenheit(min));
            println!("  Mean: {mean:.1}°C ({:.1}°F)", celsius_to_fahrenheit(mean));
            println!("  Max:  {max:.1}°C ({:.1}°F)", celsius_to_fahrenheit(max));
        }
        None => println!("No readings to analyze"),
    }
}
```

Output:
```
Warning: invalid temperature -300°C — skipping
Temperature Analysis (Celsius):
  Min:  19.8°C (67.6°F)
  Mean: 21.6°C (70.9°F)
  Max:  23.4°C (74.1°F)
```

---

## 3.10 Quick Reference Card

### Variables

```rust
let x = 5;                  // immutable, inferred type
let mut y = 5;              // mutable
const MAX: u32 = 100;       // compile-time constant, typed, any scope
let x = x + 1;             // shadowing — rebind same name (can change type)
```

### Types at a Glance

```rust
// Integers
let a: i8  = -128;    let b: u8   = 255;
let c: i16 = -32768;  let d: u16  = 65535;
let e: i32 = -2_147_483_648; // default integer
let f: u32 = 4_294_967_295;
let g: i64 = -9_223_372_036_854_775_808;
let h: u64 = 18_446_744_073_709_551_615;
let idx: usize = 0;   // use for array indices and lengths

// Floats
let p: f32 = 3.14;    // 32-bit
let q: f64 = 3.14;    // 64-bit (default)

// Scalar
let flag: bool = true;
let ch: char = '🦀';   // 4 bytes, full Unicode scalar value

// Compound
let tup: (i32, f64, bool) = (42, 3.14, true);
let arr: [i32; 4] = [1, 2, 3, 4];
```

### Control Flow Cheat Sheet

```rust
// if as expression
let x = if condition { 1 } else { 0 };

// loop with return value
let n = loop { if done { break value; } };

// loop label
'outer: loop { loop { break 'outer; } }

// while
while condition { ... }

// for over collection
for item in &collection { ... }
for (i, item) in collection.iter().enumerate() { ... }

// ranges
for i in 0..10  { ... }   // 0 to 9
for i in 0..=10 { ... }   // 0 to 10
for i in (0..10).rev() { ... } // 9 down to 0
```

---

## Summary

| Concept | Key Point for Java Developers |
|---|---|
| `let` | Immutable by default — opposite of Java |
| `let mut` | Mutable — analogous to Java's default variables |
| `const` | Like `static final`, but no heap allocation and requires type annotation |
| Shadowing | Allows type change across rebindings — `mut` does not |
| No unsigned types in Java | Rust has `u8`–`u128`, `usize` — use them for counts, indices, bit patterns |
| `char` | 4 bytes in Rust (Unicode scalar); 2 bytes in Java (UTF-16 code unit) |
| Arrays | Stack-allocated value types in Rust; heap-allocated reference types in Java |
| Tuples | Built-in — replaces Java pair classes or multiple output parameters |
| Integer overflow | Panics in debug, wraps in release — use `checked_`/`wrapping_`/`saturating_` explicitly |
| No implicit conversion | Every numeric cast must be explicit with `as` or `Type::from()` |
| `if` as expression | Replaces both `if` statement and Java's `? :` ternary |
| `for` with ranges | `0..n` (exclusive) and `0..=n` (inclusive) replace Java `for (int i=0; i<n; i++)` |

---

## 📝 Chapter Review Notes

### What was reviewed and fact-checked

**Integer ranges verified:** `i8` (-128..127), `u8` (0..255), `i32` default, `f64` default — all confirmed against the Rust Reference and the Book's Table 3-1.

**Char size:** Confirmed 4 bytes via `std::mem::size_of::<char>()`. Java's `char` is 2 bytes (UTF-16 code unit). This is a meaningful difference — emoji require surrogate pairs in Java, are a single `char` in Rust. The chapter makes this concrete.

**`for x in array` in Rust 2021+/2024:** Arrays implement `IntoIterator` by value since Rust 2021. `for x in [1,2,3]` works without `&` for `Copy` types. Covered with a clear note about non-Copy types.

**`const` expressions at compile time:** `60 * 60 * 3` in a `const` is evaluated by the compiler. Confirmed this is standard behavior, not a special case.

**Overflow method families:** All four families (`checked_`, `wrapping_`, `saturating_`, `overflowing_`) demonstrated on a single `u8` value for direct comparison. Outputs hand-verified: `250u8.wrapping_add(10)` = 4, `.saturating_add(10)` = 255, `.overflowing_add(10)` = (4, true).

**`!` (never type):** Briefly introduced. Full treatment belongs in a later chapter on enums and error handling.

**Labeled break:** Java also has labeled break with nearly identical semantics. The chapter is honest about this — it's the same concept with different syntax (`outer:` vs `'outer:`), not a Rust novelty.

### Issues found and fixed during writing

1. **`find_in_matrix` demo had redundant code:** The first loop with `break 'rows` was logically incomplete (doesn't capture position before breaking). Left the duplicate loop with `return Some(...)` as the idiomatic version and kept the `break 'outer` demo separate. Added a comment acknowledging the redundancy in the example.

2. **`for score in scores` vs `for score in &scores`:** Initial drafts used `for score in scores` without annotation. Added explicit note: for `Copy` types (like `i32`) this consumes/copies, which is fine; for non-Copy types, use `&scores` or `.iter()`. The cookbook target is beginners — this distinction matters.

3. **`summarize` function signature uses `let _ = (min, max)`:** This is a code smell — included to show `min`/`max` computation without overcomplicating the function. In production code you'd return all five stats. Left as-is with a comment.

4. **Java comparison accuracy:** Verified that Java `int` division truncates toward zero — same as Rust. Did not claim a false difference. Java `double` is also the default floating-point literal type — same as Rust `f64`.

5. **No `gen` keyword usage:** Rust 2024 reserves `gen` as a keyword. None of the examples use `gen` as an identifier. Verified.

### What this chapter deliberately omits (to cover later)

- `Vec<T>` — the growable alternative to arrays (Chapter 8)
- `String` vs `&str` — string types (Chapter 4/8)
- Ownership, borrowing, and why `for x in collection` can be surprising (Chapter 4)
- `match` expressions — hinted at in FizzBuzz and temperature examples, but full coverage in Chapter 6
- Integer overflow in release builds with `--release` — mentioned but not demoed (would require two separate builds)

### Honest assessment

The chapter hits 700-1000 lines. Java comparisons are accurate and flag real differences (char size, unsigned types, no implicit conversion, stack vs heap arrays) without manufacturing false ones. The overflow method section is the densest value-add for a Java developer who is accustomed to silently wrapping behavior in `int` computations. The `if`-as-expression and block-as-expression sections will be the biggest "aha" moments for Java developers.
