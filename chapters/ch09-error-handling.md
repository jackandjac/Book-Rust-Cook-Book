# Chapter 9: Error Handling

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

## Java framing: two worlds, two philosophies

Java error handling rests on one idea: errors are objects that can be thrown up a call stack and caught wherever the developer chooses. Checked exceptions (`IOException`, `SQLException`) are part of method signatures and enforced by the compiler — but only at the signature level. You can always catch and swallow them. Unchecked exceptions (`RuntimeException` and its descendants) need no declaration at all, making them invisible until they explode in production.

Rust takes a different approach entirely. There is **no exception mechanism**. Instead, Rust provides two orthogonal tools:

| Situation | Rust mechanism | Java rough analog |
|---|---|---|
| Unrecoverable bug, violated invariant | `panic!` | `throw new Error(…)` / `assert` |
| Expected failure that callers should handle | `Result<T, E>` | `throws CheckedException` |

The crucial difference: `Result<T, E>` is a **value** in the return type. The compiler forces you to handle it — you cannot accidentally ignore a `Result` the way you can swallow an exception. If you do ignore it, `rustc` emits a `#[must_use]` warning (and `Result` is annotated `#[must_use]` in the standard library).

This chapter works through both tools exhaustively.

---

## 9.1 `panic!` — Unrecoverable Errors

### 9.1.1 What triggers a panic

A panic is the Rust equivalent of a fatal assertion failure. It is **not** an exception — you cannot catch it in normal application code and continue running. Three things cause panics:

```rust
fn main() {
    // 1. Explicit call to the panic! macro
    panic!("something has gone catastrophically wrong");
}
```

```rust
fn main() {
    // 2. Out-of-bounds index access
    let v = vec![1, 2, 3];
    println!("{}", v[99]); // panics: index out of bounds
}
```

```rust
fn main() {
    // 3. Calling unwrap() on None or an Err
    let x: Option<i32> = None;
    let _ = x.unwrap(); // panics: called `Option::unwrap()` on a `None` value
}
```

All three produce the same kind of output:

```
thread 'main' panicked at src/main.rs:3:5:
something has gone catastrophically wrong
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

The message tells you the exact file, line, and column. Note the hint at the end.

### 9.1.2 Debugging with `RUST_BACKTRACE`

In development, run with `RUST_BACKTRACE=1` to get a full stack trace:

```bash
# Show a stack trace on panic
RUST_BACKTRACE=1 cargo run

# Show an even more verbose trace (includes internal frames)
RUST_BACKTRACE=full cargo run
```

A typical backtrace output looks like:

```
thread 'main' panicked at src/main.rs:4:6:
index out of bounds: the len is 3 but the index is 99
stack backtrace:
   0: rust_begin_unwind
   1: core::panicking::panic_fmt
   2: core::slice::index::slice_index_usize_fail
   3: panic::main           <-- this is YOUR code; start reading here
             at src/main.rs:4:5
   4: core::ops::function::FnOnce::call_once
             at /rustc/.../library/core/src/ops/function.rs:250:5
```

**Read from the top down until you see a file path you recognize.** Everything above that line is Rust internals; everything at and below is your code path. Debug symbols must be present — always build with `cargo build` or `cargo run` (debug profile) when debugging panics. The `--release` flag strips symbols.

### 9.1.3 `panic = "unwind"` vs `panic = "abort"`

By default, a panic *unwinds* the stack: Rust walks back through every call frame, runs the `Drop` implementation on every live value, and then exits. This is correct behaviour — it means files get flushed, mutexes get released, and your cleanup code (the `Drop` trait, equivalent to Java's `finally` or `try-with-resources`) runs normally.

You can change this behaviour in `Cargo.toml`:

```toml
[package]
name    = "my-app"
version = "0.1.0"
edition = "2024"

# Unwind is the default — no need to write it unless being explicit:
[profile.dev]
panic = "unwind"

# For smaller release binaries, abort avoids the unwinding machinery:
[profile.release]
panic = "abort"
```

**With `panic = "abort"`:**
- The program terminates immediately; the OS reclaims memory.
- `Drop` destructors do **not** run on the unwound frames. If a value holds an open file handle, that file may not be flushed. If it holds a mutex, it stays locked.
- The resulting binary is smaller because the unwinding tables are not emitted.
- Use this for embedded targets or when binary size matters more than graceful cleanup.

> **Java comparison:** Java's `finally` blocks and `AutoCloseable.close()` always run when a `catch` block handles an exception. With `panic = "abort"` in Rust there is no equivalent — cleanup simply does not happen. With the default `unwind` mode, `Drop` gives you the same guarantee as `finally`.

### 9.1.4 `catch_unwind` — the escape hatch you should rarely use

`std::panic::catch_unwind` lets you intercept a panic and continue running:

```rust
use std::panic;

fn maybe_panics(x: i32) -> i32 {
    if x == 0 {
        panic!("zero is not allowed");
    }
    100 / x
}

fn main() {
    let result = panic::catch_unwind(|| maybe_panics(0));
    match result {
        Ok(val)  => println!("Got: {val}"),
        Err(_)   => println!("Caught a panic, but we cannot know its type reliably"),
    }
}
```

**Do not use this for control flow.** `catch_unwind` exists for:
- Test harnesses (so one failing test does not crash the whole suite).
- FFI boundaries where a Rust panic must not cross into C code.
- Thread-pool executors that need to keep worker threads alive after a task panics.

It is **not** the Rust equivalent of `catch (Exception e)`. Idiomatic Rust never panics for expected conditions and never uses `catch_unwind` as a substitute for `Result`.

### 9.1.5 `panic!` is not exception handling — the key contrast

| | Java exceptions | Rust `panic!` |
|---|---|---|
| Can be caught? | Yes, with `try`/`catch` | Rarely, with `catch_unwind` |
| Carries structured data? | Yes — any `Throwable` object | Only a message string |
| Used for expected failures? | Yes (checked exceptions) | No — use `Result` |
| Propagation mechanism? | JVM unwinds the call stack | Rust unwinds (or aborts) |
| Type-safe at call site? | Only for checked exceptions | N/A — callers cannot inspect |
| Correct use case | Business logic error flows | Bugs and violated invariants |

The mental model: **`panic!` is for bugs**. If a function can fail for legitimate reasons (file not found, bad user input, network timeout), it should return `Result<T, E>`, not panic.

---

## 9.2 `Result<T, E>` — Recoverable Errors

### 9.2.1 The Result enum anatomy

`Result` is a standard-library enum with exactly two variants:

```rust
// This is defined in the standard library (simplified):
enum Result<T, E> {
    Ok(T),   // success — carries a value of type T
    Err(E),  // failure — carries an error of type E
}
```

Both `Ok` and `Err` are in scope everywhere without a `use` statement (they are part of the prelude). `T` and `E` are generic type parameters; every function that can fail chooses concrete types for them.

```rust
use std::fs::File;

fn main() {
    // File::open returns Result<File, std::io::Error>
    // T = File, E = std::io::Error
    let result: Result<File, std::io::Error> = File::open("hello.txt");
    println!("Is ok? {}", result.is_ok());
}
```

> **Java comparison:** The `Result<T, E>` return type is the compiler-enforced version of `throws IOException`. But unlike Java, the compiler also forces the *caller* to handle it — you cannot receive a `Result` and silently discard it without a lint warning.

### 9.2.2 Matching Result variants

The most explicit way to handle a `Result` is a `match` expression:

```rust
use std::fs::File;
use std::io::ErrorKind;

fn main() {
    let file_result = File::open("config.toml");

    let file = match file_result {
        Ok(f) => f,
        Err(e) => match e.kind() {
            ErrorKind::NotFound => {
                println!("config.toml not found, using defaults");
                return; // early return — no file handle needed
            }
            ErrorKind::PermissionDenied => {
                eprintln!("Cannot read config.toml: permission denied");
                std::process::exit(1);
            }
            other => {
                panic!("Unexpected IO error: {other:?}");
            }
        },
    };

    println!("Opened file: {:?}", file);
}
```

This nested `match` makes every case explicit. It is verbose, but it leaves no ambiguity.

### 9.2.3 Propagating errors with the `?` operator

Writing nested `match` arms for every function call is exhausting. The `?` operator automates the propagation pattern:

```rust
use std::fs::File;
use std::io::{self, Read};

// Without ?: verbose manual propagation
fn read_username_verbose() -> Result<String, io::Error> {
    let mut file = match File::open("username.txt") {
        Ok(f)  => f,
        Err(e) => return Err(e), // early return on error
    };

    let mut username = String::new();
    match file.read_to_string(&mut username) {
        Ok(_)  => Ok(username),
        Err(e) => Err(e),
    }
}

// With ?: identical logic, much less noise
fn read_username() -> Result<String, io::Error> {
    let mut file = File::open("username.txt")?;    // returns Err early if it fails
    let mut username = String::new();
    file.read_to_string(&mut username)?;            // same
    Ok(username)
}

fn main() {
    match read_username() {
        Ok(name) => println!("Hello, {name}!"),
        Err(e)   => eprintln!("Could not read username: {e}"),
    }
}
```

`?` does exactly two things:
1. If the value is `Ok(val)`, it unwraps and evaluates to `val`.
2. If the value is `Err(e)`, it calls `From::from(e)` to convert the error type (if needed) and immediately returns `Err(converted)` from the surrounding function.

> **Java comparison:** `?` is the Rust equivalent of a Java method that declares `throws IOException` and simply lets the exception propagate — but it is explicit at every call site (`?` must be written), so you always know which calls can fail. In Java, a `throws` declaration propagates invisibly through all callers until someone catches it.

### 9.2.4 The `?` operator and `From` trait conversion

The real power of `?` is automatic error type conversion via the `From` trait. If your function returns `Result<T, MyError>` and you `?` on a `Result<_, io::Error>`, Rust will call `MyError::from(io_error)` automatically — as long as you implement `From<io::Error> for MyError`.

```rust
use std::io;
use std::num::ParseIntError;
use std::fmt;

#[derive(Debug)]
enum AppError {
    Io(io::Error),
    Parse(ParseIntError),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppError::Io(e)    => write!(f, "I/O error: {e}"),
            AppError::Parse(e) => write!(f, "Parse error: {e}"),
        }
    }
}

// These From impls are what ? calls automatically
impl From<io::Error> for AppError {
    fn from(e: io::Error) -> Self {
        AppError::Io(e)
    }
}

impl From<ParseIntError> for AppError {
    fn from(e: ParseIntError) -> Self {
        AppError::Parse(e)
    }
}

fn read_count(path: &str) -> Result<i32, AppError> {
    let text = std::fs::read_to_string(path)?; // io::Error -> AppError::Io via From
    let n: i32 = text.trim().parse()?;         // ParseIntError -> AppError::Parse via From
    Ok(n)
}
```

> **Java comparison:** This is analogous to wrapping a `catch (IOException e) { throw new AppException(e); }` block — except `?` does it at every call site automatically, based on compile-time type information rather than runtime exception wrapping.

### 9.2.5 Chaining `?` calls

`?` can be chained on method calls. This reads naturally:

```rust
use std::fs;
use std::io;

fn first_line_trimmed(path: &str) -> Result<String, io::Error> {
    // Read whole file, split on newlines, grab first line, trim whitespace
    let content = fs::read_to_string(path)?;
    let first = content
        .lines()
        .next()
        .unwrap_or("")
        .trim()
        .to_string();
    Ok(first)
}
```

Each `?` in a chain is an independent propagation point. If `read_to_string` fails, the function returns immediately with that error; if it succeeds, execution continues.

### 9.2.6 Shortcuts: `unwrap`, `expect`, and the `unwrap_or*` family

Sometimes you want to extract the value from a `Result` without a full `match`. The standard library provides several methods:

```rust
use std::fs;

fn demo() {
    // unwrap(): panic if Err, return value if Ok
    // Use only in tests or when you are 100% certain it succeeds
    let text = fs::read_to_string("guaranteed-to-exist.txt").unwrap();

    // expect(): same as unwrap() but panics with YOUR message
    // Prefer this over unwrap() in production code when you must panic
    let text = fs::read_to_string("config.toml")
        .expect("config.toml must be present in the working directory");

    // unwrap_or(): return a fallback value if Err
    let text = fs::read_to_string("optional.txt")
        .unwrap_or_else(|_| String::from("(no file found)"));

    // unwrap_or_else(): compute the fallback lazily (avoids computing it when Ok)
    let text = fs::read_to_string("optional.txt")
        .unwrap_or_else(|e| {
            eprintln!("Warning: could not read optional.txt: {e}");
            String::new()
        });

    // unwrap_or_default(): use the type's Default impl (empty String, 0, false, etc.)
    let text: String = fs::read_to_string("optional.txt").unwrap_or_default();
}
```

> **Guideline:** Use `expect()` with a message that describes **why** the value must be present (not what went wrong). Example: `.expect("CARGO_MANIFEST_DIR is always set by cargo")`. This makes panics self-documenting. Reserve `unwrap()` for tests and throwaway scripts.

### 9.2.7 `map`, `map_err`, and `and_then` on Result

`Result` is a functor — you can transform the value inside without unwrapping it:

```rust
use std::num::ParseIntError;

fn parse_doubled(s: &str) -> Result<i32, ParseIntError> {
    // map() transforms the Ok value, passes Err through unchanged
    s.parse::<i32>().map(|n| n * 2)
}

fn parse_positive(s: &str) -> Result<u32, String> {
    // map_err() transforms the Err value, passes Ok through unchanged
    s.parse::<i32>()
        .map_err(|e| format!("could not parse '{s}': {e}"))
        .and_then(|n| {
            // and_then() (flatMap in Java streams) applies a function that itself
            // returns a Result — useful for chaining fallible operations
            if n >= 0 {
                Ok(n as u32)
            } else {
                Err(format!("expected non-negative, got {n}"))
            }
        })
}

fn main() {
    println!("{:?}", parse_doubled("21"));     // Ok(42)
    println!("{:?}", parse_doubled("abc"));    // Err(ParseIntError { kind: InvalidDigit })
    println!("{:?}", parse_positive("5"));     // Ok(5)
    println!("{:?}", parse_positive("-3"));    // Err("expected non-negative, got -3")
    println!("{:?}", parse_positive("xyz"));   // Err("could not parse 'xyz': ...")
}
```

> **Java comparison:** `map()` corresponds to `Optional.map()`; `and_then()` corresponds to `Optional.flatMap()`. Java streams have no direct `Result`-style equivalent because Java uses exceptions for errors instead of return values.

### 9.2.8 Collecting Results: `Iterator::collect::<Result<Vec<_>, _>>()`

A common pattern: you have an iterator of operations that might fail, and you want either a `Vec` of all successes or the first error. The `collect()` method handles this:

```rust
fn parse_all(inputs: &[&str]) -> Result<Vec<i32>, std::num::ParseIntError> {
    // collect() into Result<Vec<_>, _> short-circuits on the first Err
    // If ANY element fails, the whole collect() returns Err immediately
    inputs.iter().map(|s| s.parse::<i32>()).collect()
}

fn main() {
    let good = ["1", "2", "3", "42"];
    let bad  = ["1", "oops", "3"];

    println!("{:?}", parse_all(&good)); // Ok([1, 2, 3, 42])
    println!("{:?}", parse_all(&bad));  // Err(ParseIntError { kind: InvalidDigit })
}
```

**Key behaviour:** `collect::<Result<Vec<_>, _>>()` short-circuits — it stops iterating on the first `Err`. If you want all errors (not just the first), you must collect into `Vec<Result<_,_>>` and process it yourself.

```rust
fn parse_all_errors(inputs: &[&str]) -> Vec<Result<i32, std::num::ParseIntError>> {
    // Keep going even on errors — collect every result
    inputs.iter().map(|s| s.parse::<i32>()).collect()
}
```

### 9.2.9 `?` in `main`

`main` can return `Result<(), E>` using `?` directly:

```rust
use std::fs;
use std::io;

fn main() -> Result<(), io::Error> {
    let content = fs::read_to_string("input.txt")?;
    println!("File has {} bytes", content.len());
    Ok(())
}
```

If `main` returns `Err`, the program exits with a non-zero exit code and prints the error using `Debug` formatting (not `Display`). This is intentional — it gives you the raw error detail. For user-facing CLIs, prefer handling the error yourself so you can use `Display` and control the exit code explicitly.

For accepting any error type, use `Box<dyn std::error::Error>`:

```rust
use std::error::Error;
use std::fs;

fn main() -> Result<(), Box<dyn Error>> {
    let content = fs::read_to_string("input.txt")?;
    let count: i32 = content.trim().parse()?; // ParseIntError, different from io::Error
    println!("Count is {count}");
    Ok(())
}
```

---

## 9.3 Custom Error Types

### 9.3.1 Defining a custom error enum

For library crates, you want callers to be able to match on specific failure modes. A custom error enum achieves this:

```rust
use std::fmt;
use std::io;
use std::num::ParseIntError;

/// Errors that can occur when parsing a configuration file.
#[derive(Debug)]
pub enum ConfigError {
    /// The file could not be opened or read.
    Io(io::Error),
    /// A value in the file could not be parsed as an integer.
    InvalidInteger { field: String, source: ParseIntError },
    /// A required field is absent from the file.
    MissingField(String),
    /// A field value is out of the accepted range.
    OutOfRange { field: String, value: i64, min: i64, max: i64 },
}
```

### 9.3.2 Implementing `fmt::Display` and `std::error::Error`

For your error type to participate in the Rust error ecosystem, implement two traits:

```rust
// Display is shown to end users — make it human-readable
impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::Io(e) => write!(f, "could not read configuration file: {e}"),
            ConfigError::InvalidInteger { field, source } => {
                write!(f, "field '{field}' is not a valid integer: {source}")
            }
            ConfigError::MissingField(name) => {
                write!(f, "required field '{name}' is missing")
            }
            ConfigError::OutOfRange { field, value, min, max } => {
                write!(f, "field '{field}' value {value} is outside [{min}, {max}]")
            }
        }
    }
}

// std::error::Error gives access to the error chain (source())
impl std::error::Error for ConfigError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            ConfigError::Io(e)                            => Some(e),
            ConfigError::InvalidInteger { source, .. }   => Some(source),
            ConfigError::MissingField(_)                  => None,
            ConfigError::OutOfRange { .. }                => None,
        }
    }
}

// From impls enable the ? operator to convert errors automatically
impl From<io::Error> for ConfigError {
    fn from(e: io::Error) -> Self {
        ConfigError::Io(e)
    }
}
```

> **Java comparison:** Implementing `source()` is analogous to passing a `cause` to a Java exception constructor: `new MyException("message", cause)`. Java's `Throwable.getCause()` traverses the chain; Rust's `Error::source()` does the same.

### 9.3.3 Using the `thiserror` crate

Writing `Display`, `Error`, and `From` impls by hand is mechanical. The `thiserror` crate (version 2.x as of 2025) generates them via derive macros:

```toml
# Cargo.toml
[package]
name    = "my-lib"
version = "0.1.0"
edition = "2024"

[dependencies]
thiserror = "2"
```

```rust
use thiserror::Error;
use std::io;
use std::num::ParseIntError;

#[derive(Debug, Error)]
pub enum ConfigError {
    // #[error("...")] generates the Display impl
    // {0} refers to the first field (like format! positional args)
    #[error("could not read configuration file: {0}")]
    Io(#[from] io::Error), // #[from] generates From<io::Error> for ConfigError

    #[error("field '{field}' is not a valid integer: {source}")]
    InvalidInteger {
        field: String,
        #[source]  // marks this as the error source (implements source())
        source: ParseIntError,
    },

    #[error("required field '{0}' is missing")]
    MissingField(String),

    #[error("field '{field}' value {value} is outside [{min}, {max}]")]
    OutOfRange {
        field: String,
        value: i64,
        min: i64,
        max: i64,
    },
}

// Usage is identical to the manual version — ? still works
fn load_port(text: &str) -> Result<u16, ConfigError> {
    let raw: i64 = text.trim()
        .parse::<i64>()
        .map_err(|e| ConfigError::InvalidInteger {
            field: "port".into(),
            source: e.to_string().parse::<i64>().unwrap_err(), // illustrative only
            // In practice you'd use a ParseIntError directly
        })?;
    if !(1..=65535).contains(&raw) {
        return Err(ConfigError::OutOfRange {
            field: "port".into(),
            value: raw,
            min: 1,
            max: 65535,
        });
    }
    Ok(raw as u16)
}
```

`thiserror` is the right choice for **library crates** where callers need to match on error variants.

### 9.3.4 Using `anyhow` for application error handling

For **application (binary) crates** — CLIs, services, scripts — you rarely need callers to match on specific error variants. You just want errors to propagate and print nicely. The `anyhow` crate is built for this:

```toml
# Cargo.toml
[package]
name    = "my-app"
version = "0.1.0"
edition = "2024"

[dependencies]
anyhow  = "1"
```

```rust
use anyhow::{Context, Result};
use std::fs;

// anyhow::Result<T> is a type alias for Result<T, anyhow::Error>
// anyhow::Error can hold any error type that implements std::error::Error
fn parse_config(path: &str) -> Result<u16> {
    let text = fs::read_to_string(path)
        .with_context(|| format!("failed to read config file at '{path}'"))?;

    let port: u16 = text.trim()
        .parse()
        .with_context(|| format!("port value in '{path}' is not a valid u16"))?;

    Ok(port)
}

fn main() -> Result<()> {
    let port = parse_config("config.txt")?;
    println!("Listening on port {port}");
    Ok(())
}
```

`anyhow::Context::with_context()` wraps an error with additional information — like Java's `new IOException("while reading config", cause)`, but composed at each call site. When printed (with `{:?}`), the full chain of context messages is shown:

```
Error: failed to read config file at 'config.txt'

Caused by:
    No such file or directory (os error 2)
```

### 9.3.5 When to use which approach

| Approach | Use when |
|---|---|
| Manual `Display` + `Error` + `From` | You need full control; no extra dependencies |
| `thiserror` | Library crate; callers must match error variants |
| `anyhow` | Application/binary crate; you want easy propagation + context |
| `Box<dyn Error>` | Quick scripts, `main()`, or when you do not care about type |

**Never use `anyhow` in a library crate's public API.** `anyhow::Error` is opaque — callers cannot inspect the variant. Use `thiserror`-derived enums in library APIs and `anyhow` only in application code.

### 9.3.6 `Box<dyn Error>` — the simple catch-all

Before reaching for `anyhow`, you can use `Box<dyn std::error::Error>` as a quick erasure type:

```rust
use std::error::Error;
use std::fs;

fn read_and_parse(path: &str) -> Result<i32, Box<dyn Error>> {
    let text = fs::read_to_string(path)?;    // io::Error — coerced to Box<dyn Error>
    let n: i32 = text.trim().parse()?;       // ParseIntError — same coercion
    Ok(n)
}
```

For multi-threaded code, you need `Box<dyn Error + Send + Sync + 'static>` so the error can be sent across thread boundaries:

```rust
use std::error::Error;

type ThreadSafeError = Box<dyn Error + Send + Sync + 'static>;

fn fallible_worker() -> Result<(), ThreadSafeError> {
    // This can be sent to another thread, stored in Arc, etc.
    Ok(())
}
```

The downside of `Box<dyn Error>`: the caller loses the ability to inspect the concrete error type. Downcasting is possible but awkward. `anyhow` is a more ergonomic wrapper around the same idea.

---

## 9.4 Error Handling Patterns

### 9.4.1 Early return with `?`

This is the most idiomatic Rust pattern. Write the happy path as if nothing can fail; the `?` operators handle the exits:

```rust
use std::io;
use std::fs;

fn process_file(path: &str) -> Result<usize, io::Error> {
    let contents = fs::read_to_string(path)?;  // exit if missing
    let trimmed  = contents.trim();
    let lines    = trimmed.lines().count();
    // ... more processing
    Ok(lines)
}
```

Compare the equivalent in Java:

```java
// Java: exception propagates implicitly — no visible markers at call sites
public int processFile(String path) throws IOException {
    String contents = Files.readString(Path.of(path));
    return contents.trim().lines().count();
}
```

In Rust, every fallible call has a `?` marker. In Java, the same calls look identical to infallible ones. Rust's approach makes error paths auditable.

### 9.4.2 Converting `Option` to `Result` with `.ok_or()`

`?` only works on `Result` (or `Option` in an `Option`-returning function). To bridge the two:

```rust
fn get_env_port() -> Result<u16, String> {
    // std::env::var returns Result<String, VarError>
    let val = std::env::var("PORT")
        .map_err(|_| String::from("PORT environment variable is not set"))?;

    // String::parse returns Result, ok — ? works directly
    val.parse::<u16>()
        .map_err(|_| format!("PORT value '{val}' is not a valid port number"))
}

fn find_first_digit(s: &str) -> Result<char, &'static str> {
    // Iterator::find returns Option<char>
    // .ok_or() converts None -> Err, Some(v) -> Ok(v)
    s.chars()
        .find(|c| c.is_ascii_digit())
        .ok_or("no digit found in input")
}

fn main() {
    println!("{:?}", find_first_digit("abc123")); // Ok('1')
    println!("{:?}", find_first_digit("abcdef")); // Err("no digit found in input")
}
```

Use `.ok_or(err)` for a static error value and `.ok_or_else(|| compute_err())` for lazily computed errors (avoids computing the error when the `Option` is `Some`).

### 9.4.3 Error context with `.context()` (anyhow)

When propagating errors with `?`, the original error often lacks context about *what the program was doing* when it failed. `anyhow`'s `.context()` wraps each error with a message that threads through the source chain:

```rust
use anyhow::{Context, Result};

fn read_user_id(path: &str) -> Result<u64> {
    let text = std::fs::read_to_string(path)
        .with_context(|| format!("reading user file at '{path}'"))?;

    text.trim()
        .parse::<u64>()
        .with_context(|| format!("parsing user ID from content of '{path}'"))
}

fn load_user_profile(user_file: &str) -> Result<String> {
    let id = read_user_id(user_file)
        .context("loading user profile")?;
    Ok(format!("User #{id}"))
}

fn main() {
    if let Err(e) = load_user_profile("user.dat") {
        // anyhow's Debug output shows the full error chain
        eprintln!("Error: {e:?}");
        // Output:
        // Error: loading user profile
        //
        // Caused by:
        //     0: reading user file at 'user.dat'
        //     1: No such file or directory (os error 2)
    }
}
```

### 9.4.4 When to panic vs return `Result`

Follow this decision tree:

```
Is this a bug that should never happen if the code is correct?
  YES → panic! (or use expect() with a descriptive message)
  NO  → Is failure an expected, recoverable condition?
          YES → return Result<T, E>
          NO  → Is this prototype/test/example code?
                  YES → unwrap() is acceptable
                  NO  → return Result<T, E>
```

Concretely:

**Use `panic!` when:**
- A contract is violated (function preconditions broken by the caller).
- A hardcoded value fails to parse (compile-time logic error).
- You are writing tests (`assert!`, `unwrap()` in `#[test]` functions).
- You are writing examples or prototypes.

**Return `Result` when:**
- Dealing with user input, file I/O, network operations.
- Writing library code (let the caller decide how to handle failure).
- Failure is an expected part of normal program operation.

```rust
// PANIC is right here — the IP is hardcoded and must be valid
use std::net::IpAddr;
fn localhost() -> IpAddr {
    "127.0.0.1".parse().expect("127.0.0.1 is always a valid IP address")
}

// RESULT is right here — user-supplied data may be invalid
fn parse_user_ip(input: &str) -> Result<IpAddr, std::net::AddrParseError> {
    input.parse()
}
```

---

## 9.5 Practical Examples

### 9.5.1 File parser with custom error type

A realistic CSV-like parser that handles missing files, malformed lines, and validation failures:

```rust
// Cargo.toml dependency: thiserror = "2"
use thiserror::Error;
use std::io;
use std::num::ParseIntError;
use std::path::Path;

#[derive(Debug, Error)]
pub enum ParseError {
    #[error("cannot open '{path}': {source}")]
    FileOpen {
        path: String,
        #[source]
        source: io::Error,
    },

    #[error("line {line}: expected 'name,age' format, got '{content}'")]
    BadFormat { line: usize, content: String },

    #[error("line {line}: age is not a number: {source}")]
    InvalidAge {
        line: usize,
        #[source]
        source: ParseIntError,
    },

    #[error("line {line}: age {age} must be between 0 and 150")]
    AgeOutOfRange { line: usize, age: i64 },
}

#[derive(Debug)]
pub struct Person {
    pub name: String,
    pub age: u8,
}

pub fn parse_people_file(path: &str) -> Result<Vec<Person>, ParseError> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| ParseError::FileOpen {
            path: path.to_string(),
            source: e,
        })?;

    let mut people = Vec::new();

    for (idx, line) in content.lines().enumerate() {
        let line_num = idx + 1;
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue; // skip blank lines and comments
        }

        let mut parts = line.splitn(2, ',');
        let name = parts
            .next()
            .ok_or_else(|| ParseError::BadFormat {
                line: line_num,
                content: line.to_string(),
            })?
            .trim()
            .to_string();

        let age_str = parts
            .next()
            .ok_or_else(|| ParseError::BadFormat {
                line: line_num,
                content: line.to_string(),
            })?
            .trim();

        let age_raw: i64 = age_str
            .parse()
            .map_err(|e| ParseError::InvalidAge { line: line_num, source: e })?;

        if !(0..=150).contains(&age_raw) {
            return Err(ParseError::AgeOutOfRange { line: line_num, age: age_raw });
        }

        people.push(Person { name, age: age_raw as u8 });
    }

    Ok(people)
}

fn main() {
    match parse_people_file("people.csv") {
        Ok(people) => {
            for p in &people {
                println!("{}: age {}", p.name, p.age);
            }
        }
        Err(e) => {
            eprintln!("Parse failed: {e}");
            // Access the underlying cause if present:
            if let Some(src) = std::error::Error::source(&e) {
                eprintln!("  Caused by: {src}");
            }
            std::process::exit(1);
        }
    }
}
```

### 9.5.2 Multi-step error propagation with `anyhow`

Simulating a multi-step workflow (authenticate, fetch resource, decode response) with `anyhow` context layering:

```rust
// Cargo.toml dependency: anyhow = "1"
use anyhow::{bail, Context, Result};

// Simulated types for illustration
struct AuthToken(String);
struct RawResponse(String);
#[derive(Debug)]
struct UserRecord { id: u64, name: String }

fn authenticate(username: &str, password: &str) -> Result<AuthToken> {
    if password.is_empty() {
        bail!("password must not be empty for user '{username}'");
    }
    // In reality: HTTP call, token parsing, etc.
    Ok(AuthToken(format!("token-for-{username}")))
}

fn fetch_user(token: &AuthToken, user_id: u64) -> Result<RawResponse> {
    if user_id == 0 {
        bail!("user_id 0 is reserved and cannot be fetched");
    }
    // In reality: HTTP GET /users/{id} with Authorization header
    Ok(RawResponse(format!("{{\"id\":{user_id},\"name\":\"Alice\"}}")))
}

fn decode_user(raw: RawResponse) -> Result<UserRecord> {
    // Simulate a parse — in practice you would use serde_json
    let s = raw.0;
    let id_start  = s.find("\"id\":").context("missing 'id' field")? + 5;
    let id_end    = s[id_start..].find(',').context("malformed id field")? + id_start;
    let id: u64   = s[id_start..id_end].parse().context("id is not a number")?;

    let name_start = s.find("\"name\":\"").context("missing 'name' field")? + 8;
    let name_end   = s[name_start..].find('"').context("unclosed name string")? + name_start;
    let name       = s[name_start..name_end].to_string();

    Ok(UserRecord { id, name })
}

fn get_user_profile(username: &str, password: &str, user_id: u64) -> Result<UserRecord> {
    let token = authenticate(username, password)
        .with_context(|| format!("authenticating as '{username}'"))?;

    let raw = fetch_user(&token, user_id)
        .with_context(|| format!("fetching user {user_id}"))?;

    let record = decode_user(raw)
        .context("decoding user response")?;

    Ok(record)
}

fn main() {
    match get_user_profile("alice", "secret", 42) {
        Ok(user)  => println!("Loaded user: {:?}", user),
        Err(e)    => eprintln!("Failed: {e:?}"), // shows full context chain
    }

    // Trigger an error to see context layering:
    match get_user_profile("bob", "", 42) {
        Ok(_)     => {}
        Err(e)    => eprintln!("Expected error: {e:?}"),
        // Output: authenticating as 'bob': password must not be empty for user 'bob'
    }
}
```

### 9.5.3 A robust CLI that handles errors gracefully

A CLI that reads from a file, processes data, and exits with the right exit code — without panicking on user errors:

```rust
// Cargo.toml dependency: anyhow = "1"
use anyhow::{Context, Result};
use std::path::PathBuf;

fn run(input_path: &PathBuf) -> Result<()> {
    let content = std::fs::read_to_string(input_path)
        .with_context(|| format!("reading input file '{}'", input_path.display()))?;

    let numbers: Vec<i64> = content
        .lines()
        .enumerate()
        .filter(|(_, line)| !line.trim().is_empty())
        .map(|(i, line)| {
            line.trim()
                .parse::<i64>()
                .with_context(|| format!("line {}: '{}' is not an integer", i + 1, line.trim()))
        })
        .collect::<Result<Vec<_>>>()?; // short-circuits on first parse error

    if numbers.is_empty() {
        anyhow::bail!("input file contains no numbers");
    }

    let sum: i64 = numbers.iter().sum();
    let avg = sum as f64 / numbers.len() as f64;

    println!("Count : {}", numbers.len());
    println!("Sum   : {sum}");
    println!("Average: {avg:.2}");

    Ok(())
}

fn main() {
    // Parse args manually (use clap for real CLIs)
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <input-file>", args[0]);
        std::process::exit(2); // exit code 2 = usage error
    }

    let input_path = PathBuf::from(&args[1]);

    if let Err(e) = run(&input_path) {
        // Display the full error chain to stderr (not stdout)
        eprintln!("Error: {e:#}"); // {:#} = compact chain format in anyhow
        std::process::exit(1);    // exit code 1 = runtime error
    }
}
```

Key CLI error-handling practices demonstrated here:
- All business logic is in `run()` which returns `Result<()>`.
- `main()` only handles exit codes and error display.
- Errors go to `stderr` (`eprintln!`), normal output goes to `stdout` (`println!`).
- Exit code 1 for runtime errors, 2 for usage errors — follows Unix convention.
- `{e:#}` (alternate format) gives a compact single-line chain; `{e:?}` gives full debug output.

### 9.5.4 A custom error type for a library crate

A complete library-style module with a non-exhaustive error enum (allows adding variants without breaking callers):

```rust
// src/lib.rs — a hypothetical key-value store library
// Cargo.toml dependency: thiserror = "2"

use thiserror::Error;
use std::collections::HashMap;

/// Errors returned by the key-value store.
///
/// This enum is non-exhaustive: future versions of the library may add
/// new variants. Callers must include a wildcard arm when matching.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum StoreError {
    #[error("key '{0}' does not exist")]
    NotFound(String),

    #[error("key '{0}' exceeds maximum length of 256 bytes")]
    KeyTooLong(String),

    #[error("value size {0} bytes exceeds the 1 MB limit")]
    ValueTooLarge(usize),

    #[error("store is read-only")]
    ReadOnly,

    #[error("serialization error: {0}")]
    Serialization(String),
}

pub struct KvStore {
    data: HashMap<String, Vec<u8>>,
    read_only: bool,
}

impl KvStore {
    pub fn new() -> Self {
        KvStore { data: HashMap::new(), read_only: false }
    }

    pub fn new_read_only(data: HashMap<String, Vec<u8>>) -> Self {
        KvStore { data, read_only: true }
    }

    pub fn get(&self, key: &str) -> Result<&[u8], StoreError> {
        self.data
            .get(key)
            .map(|v| v.as_slice())
            .ok_or_else(|| StoreError::NotFound(key.to_string()))
    }

    pub fn set(&mut self, key: &str, value: Vec<u8>) -> Result<(), StoreError> {
        if self.read_only {
            return Err(StoreError::ReadOnly);
        }
        if key.len() > 256 {
            return Err(StoreError::KeyTooLong(key.to_string()));
        }
        const ONE_MB: usize = 1024 * 1024;
        if value.len() > ONE_MB {
            return Err(StoreError::ValueTooLarge(value.len()));
        }
        self.data.insert(key.to_string(), value);
        Ok(())
    }
}

// Example usage (in a calling crate or integration test):
fn demo() {
    let mut store = KvStore::new();

    match store.set("greeting", b"hello".to_vec()) {
        Ok(())  => println!("Stored"),
        Err(StoreError::ReadOnly) => eprintln!("Store is read-only"),
        Err(StoreError::KeyTooLong(k)) => eprintln!("Key too long: {k}"),
        Err(e)  => eprintln!("Other error: {e}"), // wildcard required by #[non_exhaustive]
    }

    match store.get("greeting") {
        Ok(val)  => println!("Got: {:?}", val),
        Err(StoreError::NotFound(k)) => eprintln!("Key not found: {k}"),
        Err(e)   => eprintln!("Error: {e}"),
    }
}
```

`#[non_exhaustive]` is a critical library-design tool: it lets you add new variants in a minor version without breaking downstream `match` expressions.

---

## 9.6 Quick Reference

### Result methods at a glance

| Method | Input | Output | Notes |
|---|---|---|---|
| `.is_ok()` | `Result<T,E>` | `bool` | True if Ok |
| `.is_err()` | `Result<T,E>` | `bool` | True if Err |
| `.unwrap()` | `Result<T,E>` | `T` | Panics on Err |
| `.expect(msg)` | `Result<T,E>` | `T` | Panics with msg on Err |
| `.unwrap_or(v)` | `Result<T,E>` | `T` | Returns v on Err |
| `.unwrap_or_else(f)` | `Result<T,E>` | `T` | Calls f(err) on Err |
| `.unwrap_or_default()` | `Result<T,E>` | `T` | Calls T::default() on Err |
| `.ok()` | `Result<T,E>` | `Option<T>` | Discards error |
| `.err()` | `Result<T,E>` | `Option<E>` | Discards value |
| `.map(f)` | `Result<T,E>` | `Result<U,E>` | Transforms Ok value |
| `.map_err(f)` | `Result<T,E>` | `Result<T,F>` | Transforms Err value |
| `.and_then(f)` | `Result<T,E>` | `Result<U,E>` | Flatmap on Ok |
| `.or_else(f)` | `Result<T,E>` | `Result<T,F>` | Flatmap on Err |

### Choosing your error strategy

```
Is this a library crate?
  YES → Use thiserror, expose typed error enums, impl std::error::Error
  NO (binary/app) → Use anyhow for easy propagation + context

Do callers need to match on error variants?
  YES → Typed enum (thiserror or manual)
  NO  → anyhow::Error or Box<dyn Error>

Is it a prototype or test?
  YES → unwrap() / expect() is fine
```

---

## 📝 Chapter Review Notes

### Critical Review and Fact-Check

The code examples in this chapter were written for Rust 2024 edition (stabilized in Rust 1.85, February 2025). The following issues table captures tradeoffs, potential confusion points, and verifiable facts.

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | `thiserror` version | **Verify on publish** | This chapter specifies `thiserror = "2"` (2.x API). The derive syntax for common cases is identical to 1.x. If readers are using an older lockfile with `thiserror = "1"`, the code still compiles — confirm latest version at crates.io/crates/thiserror before publishing. |
| 2 | `anyhow` version | **Current** | `anyhow = "1"` is correct as of May 2026. The API has been stable for years. |
| 3 | `panic = "abort"` and `Drop` | **Critical accuracy point** | Section 9.1.3 correctly states that `Drop` does not run with `panic = "abort"`. This is a common source of resource leak bugs. Java developers must internalize this — Java's `finally` always runs (even with unchecked exceptions); Rust's `Drop` does not run on abort. |
| 4 | `catch_unwind` completeness | **Intentionally limited** | The chapter deliberately discourages `catch_unwind` for control flow. The full caveat is that `catch_unwind` is also unsound across FFI boundaries in some configurations, and that panicking in a `catch_unwind` closure that itself holds a `Mutex` guard may poison the mutex. These advanced topics are left for a threading chapter. |
| 5 | `collect::<Result<Vec<_>,_>>()` short-circuits | **Accurate** | The Rust standard library's `FromIterator` impl for `Result<Vec<T>, E>` does short-circuit on first `Err`. This is guaranteed by the trait contract. |
| 6 | `main() -> Result<()>` uses Debug, not Display | **Accurate** | When `main` returns `Err(e)`, the runtime prints `e` with `{:?}` (Debug). For user-facing output, the CLI example (9.5.3) correctly shows how to intercept and format with Display before calling `process::exit`. |
| 7 | `Box<dyn Error + Send + Sync + 'static>` | **Accurate** | Standard `Box<dyn Error>` is neither `Send` nor `Sync`. This matters for `anyhow` internals (it wraps `Box<dyn Error + Send + Sync + 'static>`), and for errors stored in `Arc` or sent across thread channels. |
| 8 | `#[non_exhaustive]` library pattern | **Best practice** | Correct and important for library design. Java developers may recognise this as analogous to `sealed` interfaces (introduced in Java 17) but used in reverse — `#[non_exhaustive]` *prevents* exhaustive matching by external crates, preserving the library's ability to extend the enum. |
| 9 | `?` operator requires `From` impl | **Accurate** | The `?` operator desugars to `Err(From::from(e))`. If no `From` impl exists between the error type returned by the called function and the error type in the current function's return type, the compiler emits a type error. This is the most common beginner mistake when first using `?` with custom error types. |
| 10 | `anyhow` in library public APIs | **Anti-pattern flagged** | Section 9.3.5 explicitly warns against using `anyhow` in library crates. This is a genuine community consensus — `anyhow::Error` is opaque and forces downstream users to downcast or discard type information. |
| 11 | Rust 2024 edition specifics | **Minimal impact on this chapter** | The 2024 edition changes (disjoint capture in closures, `if let` temp scoping, `impl Trait` lifetime changes) do not materially affect error-handling code. All examples compile identically under 2021 and 2024 editions. Specify `edition = "2024"` in all `Cargo.toml` snippets to stay current. |
| 12 | `decode_user` example in 9.5.2 | **Simplified intentionally** | The JSON parsing in the web-request example uses manual string searching to avoid a `serde_json` dependency. In production code, always use `serde_json`. The example is pedagogically valid but the approach is not production-ready. A comment in the code notes this. |

### Known Gaps (out of scope for this chapter)

- `std::panic::set_hook` and custom panic handlers (relevant for embedded and server deployments).
- Error handling in `async` Rust with `tokio`/`async-std` (covered in the async chapter).
- `?` in closures — `?` cannot be used inside `||` closures; you must use `match` or `.and_then()` instead. This is a common beginner frustration not covered in depth here.
- `anyhow::Error::downcast_ref::<T>()` for inspecting the underlying concrete type.
