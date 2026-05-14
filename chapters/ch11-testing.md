# Chapter 11: Writing Automated Tests

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

## JUnit vs. Rust's Built-in Test System — At a Glance

Java developers invest heavily in JUnit 5, Mockito, AssertJ, and build-plugin configuration. Rust ships everything you need in the standard toolchain — no dependencies required for the vast majority of test scenarios.

| JUnit 5 / Java                        | Rust equivalent                                  |
|---------------------------------------|--------------------------------------------------|
| `@Test`                               | `#[test]`                                        |
| `assertEquals(expected, actual)`      | `assert_eq!(left, right)`                        |
| `assertNotEquals(a, b)`               | `assert_ne!(a, b)`                               |
| `assertTrue(cond)`                    | `assert!(cond)`                                  |
| `assertThrows(Type.class, () -> ...)` | `#[should_panic]` or test a `Result`             |
| `@Disabled`                           | `#[ignore]`                                      |
| `@ParameterizedTest` + `@ValueSource` | Table-driven test (plain loop or array)          |
| `@BeforeEach` / `@AfterEach`          | Helper function called at top of each test       |
| Integration tests (Maven `src/it`)    | `tests/` directory (Cargo integration tests)     |
| `/** @link ... */ @see`               | Doc tests in `/// # Examples` fenced blocks      |
| Mockito                               | Trait objects + manual fakes (or `mockall` crate)|
| JUnit Platform / Maven Surefire       | `cargo test` — zero configuration               |

The single most important difference: **there is no framework to install or configure.** Add `#[test]` to a function, run `cargo test`, done.

---

## 11.1 The `#[test]` Attribute — Your First Test

### Anatomy of a test function

```rust,no_run
// src/lib.rs

pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;     // pull in everything from the outer module

    #[test]
    fn two_plus_two_equals_four() {
        assert_eq!(add(2, 2), 4);
    }
}
```

Run with:

```bash
cargo test
```

Output:

```
running 1 test
test tests::two_plus_two_equals_four ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

**Key rules:**
- A test function must have the signature `fn name()` (no parameters, returns `()` or `Result`).
- Placing tests inside `#[cfg(test)] mod tests { ... }` is the canonical idiom. The `cfg(test)` attribute tells the compiler to compile this block only during `cargo test`, keeping production binaries lean.
- `use super::*;` is needed because `tests` is a child module; `super` refers to the parent module where the production code lives.

**Java comparison:** In JUnit you place tests in a separate class (often in `src/test/java`). In Rust the idiomatic approach is to keep unit tests *in the same file as the code they test*, inside a `cfg(test)` module. This collapses the source/test file split for unit tests.

---

## 11.2 Assertion Macros

### `assert!` — boolean condition

```rust,no_run
#[test]
fn assert_basic() {
    let v = vec![1, 2, 3];
    assert!(!v.is_empty());
    assert!(v.len() == 3);
}
```

### `assert_eq!` and `assert_ne!`

```rust,no_run
#[test]
fn assert_eq_and_ne() {
    let result = 2 + 2;
    assert_eq!(result, 4);     // passes
    assert_ne!(result, 5);     // passes — result is not 5
}
```

`assert_eq!` and `assert_ne!` print both values on failure, which makes debugging much easier than a bare `assert!`.

**Note:** The arguments to `assert_eq!` do not have fixed "expected/actual" roles — either order compiles. By convention, write `assert_eq!(actual, expected)` for consistency, though the output labels them `left` and `right`, not `expected` and `actual`.

**Java comparison:** JUnit's `assertEquals(expected, actual)` has a fixed order with a specific semantic. In Rust neither position is semantically privileged, but the convention is `assert_eq!(computed_value, expected_value)`.

### Custom failure messages

All three macros accept an optional format string after the required arguments:

```rust,no_run
#[test]
fn custom_message() {
    let name = "Ferris";
    assert!(
        name.starts_with('F'),
        "Expected name to start with 'F', got: '{}'",
        name
    );

    let x = compute_something();
    assert_eq!(
        x, 42,
        "compute_something() returned {} but we expected 42",
        x
    );
}

fn compute_something() -> i32 { 99 } // deliberately wrong for illustration
```

The format string uses `{}` placeholders — the same syntax as `println!`. This is equivalent to JUnit 5's `assertEquals(42, x, "message here")`.

---

## 11.3 Testing Panicking Code — `#[should_panic]`

### Basic usage

```rust,no_run
pub fn divide(a: i32, b: i32) -> i32 {
    if b == 0 {
        panic!("division by zero");
    }
    a / b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[should_panic]
    fn divide_by_zero_panics() {
        divide(10, 0);
    }
}
```

This test *passes* if `divide(10, 0)` panics. It *fails* if no panic occurs.

### Pinning down the panic message

Use `expected = "..."` to require that the panic message **contains** a specific substring (substring match, not equality):

```rust,no_run
#[test]
#[should_panic(expected = "division by zero")]
fn divide_by_zero_correct_message() {
    divide(10, 0);
    // passes: panic message contains "division by zero"
}

#[test]
#[should_panic(expected = "overflow")]
fn divide_by_zero_wrong_expected() {
    divide(10, 0);
    // FAILS: panic message is "division by zero", not "overflow"
}
```

**Important:** `expected = "..."` is a **substring** match, not an exact match. If the panic message is `"division by zero: 0 is not allowed"`, then `expected = "division by zero"` still passes.

**Java comparison:** In JUnit 5 you use `assertThrows(ArithmeticException.class, () -> divide(10, 0))` and then inspect the returned exception. Rust's `#[should_panic]` is simpler but less precise — you cannot inspect the panic value. For richer assertions use a `Result`-returning test (see §11.4).

---

## 11.4 Tests That Return `Result<(), E>`

Using `?` inside tests is idiomatic for functions that can fail:

```rust,no_run
use std::num::ParseIntError;

fn parse_port(s: &str) -> Result<u16, ParseIntError> {
    let n: u16 = s.parse()?;
    Ok(n)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_port_parses() -> Result<(), ParseIntError> {
        let port = parse_port("8080")?;
        assert_eq!(port, 8080);
        Ok(())
    }

    #[test]
    fn invalid_port_returns_err() {
        // Test that the error path works — do NOT use ? here,
        // because we *want* to inspect the Err.
        let result = parse_port("not_a_number");
        assert!(result.is_err());
    }
}
```

**Rules for `Result`-returning tests:**
- The return type must implement `std::fmt::Debug` (the error type needs `Debug`).
- When a `?` propagates an `Err`, the test fails and prints the error.
- You **cannot** combine `#[should_panic]` with `Result`-returning tests.

**Java comparison:** JUnit 5 lets you declare `throws Exception` on test methods; the test fails if the exception propagates. This is exactly analogous to Rust's `-> Result<(), E>` + `?`.

---

## 11.5 `#[ignore]` — Skipping Slow Tests

Mark expensive or environment-dependent tests with `#[ignore]`:

```rust,no_run
#[test]
#[ignore]
fn slow_integration_against_real_database() {
    // Takes 30 seconds — skip in normal CI runs
    let result = call_real_database();
    assert!(result.is_ok());
}
```

```bash
cargo test                      # ignored tests are skipped
cargo test -- --ignored         # run ONLY ignored tests
cargo test -- --include-ignored # run ALL tests, including ignored
```

**Java comparison:** `@Disabled` in JUnit 5. Rust's `#[ignore]` is identical in intent but is built into the language, not a JUnit annotation.

---

## 11.6 Controlling How Tests Run

### Running all tests

```bash
cargo test
```

By default, `cargo test` runs tests in parallel across multiple threads and captures stdout so output does not clutter the test report.

### Running a single test by exact name

```bash
cargo test tests::two_plus_two_equals_four
```

### Running tests matching a substring pattern

`cargo test <pattern>` runs every test whose full name *contains* the pattern (substring match):

```bash
cargo test add       # runs add_two, add_negative, add_overflow, …
cargo test divide    # runs all tests with "divide" in their name
```

### Showing `println!` output — `--nocapture`

By default, output from passing tests is suppressed. Use `--nocapture` to see it:

```bash
cargo test -- --nocapture
```

Note the `--` separator: options **before** `--` go to `cargo test`; options **after** `--` go to the test binary itself.

### Running tests sequentially — `--test-threads`

When tests share external state (a file, a database, a global variable), parallel execution causes races. Force sequential execution with:

```bash
cargo test -- --test-threads=1
```

Note: the flag is `--test-threads` (plural, with an `=`). A common mistake is writing `--test-thread` (singular) — that will silently be ignored, and tests will still run in parallel.

### Running ignored tests

```bash
cargo test -- --ignored          # only ignored tests
cargo test -- --include-ignored  # all tests, including ignored
```

### Measuring test performance

`cargo test` prints pass/fail timing for each test in recent Rust versions. For nightly toolchains, `--report-time` gives more granular timing:

```bash
cargo +nightly test -- -Z unstable-options --report-time
```

For serious benchmarking, use the `criterion` crate rather than the built-in `#[bench]` attribute (which remains nightly-only). Add to `Cargo.toml`:

```toml
[dev-dependencies]
criterion = "0.5"
```

Then create `benches/my_bench.rs` following the criterion documentation. `cargo bench` runs all benchmarks. This is out of scope for this chapter but worth knowing exists.

---

## 11.7 A Complete `Calculator` Example

This is the flagship example for this chapter. It demonstrates every assertion macro, `should_panic`, `Result`-based tests, ignored tests, and custom failure messages in one cohesive struct.

```rust,no_run
// src/lib.rs

/// A simple calculator that returns Results instead of panicking.
#[derive(Debug, Default)]
pub struct Calculator {
    pub history: Vec<String>,
}

#[derive(Debug, PartialEq)]
pub enum CalcError {
    DivisionByZero,
    Overflow,
    NegativeSqrt,
}

impl std::fmt::Display for CalcError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CalcError::DivisionByZero => write!(f, "division by zero"),
            CalcError::Overflow       => write!(f, "arithmetic overflow"),
            CalcError::NegativeSqrt   => write!(f, "sqrt of negative number"),
        }
    }
}

impl Calculator {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add(&mut self, a: i64, b: i64) -> Result<i64, CalcError> {
        let result = a.checked_add(b).ok_or(CalcError::Overflow)?;
        self.history.push(format!("{a} + {b} = {result}"));
        Ok(result)
    }

    pub fn subtract(&mut self, a: i64, b: i64) -> Result<i64, CalcError> {
        let result = a.checked_sub(b).ok_or(CalcError::Overflow)?;
        self.history.push(format!("{a} - {b} = {result}"));
        Ok(result)
    }

    pub fn divide(&mut self, a: i64, b: i64) -> Result<i64, CalcError> {
        if b == 0 {
            return Err(CalcError::DivisionByZero);
        }
        let result = a.checked_div(b).ok_or(CalcError::Overflow)?;
        self.history.push(format!("{a} / {b} = {result}"));
        Ok(result)
    }

    pub fn sqrt(&mut self, a: f64) -> Result<f64, CalcError> {
        if a < 0.0 {
            return Err(CalcError::NegativeSqrt);
        }
        let result = a.sqrt();
        self.history.push(format!("sqrt({a}) = {result}"));
        Ok(result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── basic assertions ────────────────────────────────────────────

    #[test]
    fn add_positive_numbers() {
        let mut calc = Calculator::new();
        assert_eq!(calc.add(2, 3).unwrap(), 5);
    }

    #[test]
    fn add_records_history() {
        let mut calc = Calculator::new();
        calc.add(10, 20).unwrap();
        assert_eq!(calc.history.len(), 1);
        // Prefer an exact match over contains("30") — "130" also contains "30".
        assert_eq!(
            calc.history[0], "10 + 20 = 30",
            "unexpected history entry: '{}'",
            calc.history[0]
        );
    }

    #[test]
    fn subtract_can_go_negative() {
        let mut calc = Calculator::new();
        let result = calc.subtract(3, 10).unwrap();
        assert_eq!(result, -7, "3 - 10 should be -7, got {}", result);
    }

    // ── testing error paths ─────────────────────────────────────────

    #[test]
    fn divide_by_zero_returns_err() {
        let mut calc = Calculator::new();
        let err = calc.divide(10, 0).unwrap_err();
        assert_eq!(err, CalcError::DivisionByZero);
    }

    #[test]
    fn sqrt_negative_returns_err() {
        let mut calc = Calculator::new();
        assert!(matches!(
            calc.sqrt(-1.0),
            Err(CalcError::NegativeSqrt)
        ));
    }

    // ── Result-returning test with ? ────────────────────────────────

    #[test]
    fn chain_operations_with_question_mark() -> Result<(), CalcError> {
        let mut calc = Calculator::new();
        let a = calc.add(100, 50)?;        // 150
        let b = calc.divide(a, 3)?;        // 50
        let c = calc.subtract(b, 20)?;     // 30
        assert_eq!(c, 30);
        Ok(())
    }

    // ── overflow detection ──────────────────────────────────────────

    #[test]
    fn add_overflow_returns_err() {
        let mut calc = Calculator::new();
        let result = calc.add(i64::MAX, 1);
        assert_eq!(result, Err(CalcError::Overflow));
    }

    // ── ignored slow test ───────────────────────────────────────────

    #[test]
    #[ignore = "slow: calls external pricing API"]
    fn fetch_live_exchange_rate() {
        // Would make a real HTTP request — skip in normal CI
        unimplemented!()
    }
}
```

---

## 11.8 Test Organization

### Unit tests — same file, `#[cfg(test)]` module

As shown above, the standard pattern is a `tests` module at the bottom of each source file annotated with `#[cfg(test)]`. This ensures:

1. Test code is compiled only when running `cargo test`.
2. Test helpers do not inflate the production binary.
3. Tests live next to the code they verify — easy to find.

```
src/
├── lib.rs          ← production code + #[cfg(test)] mod tests { … }
├── calculator.rs   ← more production code
└── parser.rs       ← more production code
```

### Testing private functions

Unlike Java (where you need package-private access or reflection to test private methods), Rust's module system allows child modules to access items from their parent module that are not `pub`. The `#[cfg(test)] mod tests` block is a child module, so it can call private functions directly:

```rust,no_run
// src/lib.rs

fn private_helper(x: u32) -> u32 {
    x * x + 1
}

pub fn public_api(x: u32) -> u32 {
    private_helper(x) - 1
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_private_helper_directly() {
        // This works! private_helper is accessible from child modules.
        assert_eq!(private_helper(3), 10);   // 3*3 + 1 = 10
        assert_eq!(private_helper(0), 1);
    }
}
```

**Java comparison:** Java requires private methods to be tested indirectly through the public API, or via reflection (error-prone) or package-private visibility hacks. Rust makes this a non-issue — child modules inherit parent visibility.

### Integration tests — the `tests/` directory

Integration tests live in a separate top-level `tests/` directory. Each `.rs` file in `tests/` is compiled as its own crate that links against your library. This mirrors how an external user of your API would call it — only public items are accessible.

```
my_project/
├── Cargo.toml
├── src/
│   └── lib.rs
└── tests/
    ├── calculator_integration.rs
    └── common/
        └── mod.rs          ← shared test helpers
```

```rust,no_run
// tests/calculator_integration.rs
use my_project::Calculator;

#[test]
fn full_calculation_workflow() {
    let mut calc = Calculator::new();
    let result = calc.add(10, 5).unwrap();
    assert_eq!(result, 15);

    let divided = calc.divide(result, 3).unwrap();
    assert_eq!(divided, 5);
}
```

Run only integration tests:

```bash
cargo test --test calculator_integration
```

### Shared helpers for integration tests

To share utility functions across multiple integration test files, place them in `tests/common/mod.rs` (not `tests/common.rs` — the latter would be treated as its own test suite):

```rust,no_run
// tests/common/mod.rs

use my_project::Calculator;

pub fn fresh_calc_with_initial_add() -> Calculator {
    let mut calc = Calculator::new();
    calc.add(0, 0).unwrap();   // prime the history with one entry
    calc
}
```

```rust,no_run
// tests/calculator_integration.rs
mod common;   // declare the module

#[test]
fn history_starts_with_one_entry() {
    let calc = common::fresh_calc_with_initial_add();
    assert_eq!(calc.history.len(), 1);
}
```

**Java comparison:** JUnit test base classes or `@BeforeEach` setup methods. Rust uses plain functions — less magic, same result.

---

## 11.9 Doc Tests

Rust's documentation comments support embedded runnable examples. Any triple-backtick Rust block inside a `///` comment is compiled and executed as a test:

```rust,no_run
// In src/lib.rs — doc comment on the real Calculator::divide method:

impl Calculator {
    /// Divides `a` by `b`, returning an error on division by zero.
    ///
    /// # Examples
    ///
    /// ```
    /// use my_project::Calculator;
    ///
    /// let mut calc = Calculator::new();
    /// assert_eq!(calc.divide(10, 2).unwrap(), 5);
    /// ```
    ///
    /// Attempting to divide by zero returns an error:
    ///
    /// ```
    /// use my_project::Calculator;
    ///
    /// let mut calc = Calculator::new();
    /// assert!(calc.divide(10, 0).is_err());
    /// ```
    pub fn divide(&mut self, a: i64, b: i64) -> Result<i64, CalcError> {
        // … implementation …
        todo!()
    }
}
```

Run doc tests specifically:

```bash
cargo test --doc
```

Doc tests serve double duty: they verify examples in the docs stay correct, and they act as usage documentation for API consumers. If you update the function signature without updating the doc example, `cargo test --doc` will catch the mismatch.

**Java comparison:** JavaDoc `@code` tags are not compiled or tested. Rust doc tests are — this is a significant quality advantage.

### Hiding boilerplate in doc tests

Prefix a line with `# ` (hash + space) to include it in the compiled test without showing it in rendered documentation:

```rust,no_run
/// ```
/// # use my_project::Calculator;
/// # let mut calc = Calculator::new();
/// let result = calc.add(3, 4).unwrap();
/// assert_eq!(result, 7);
/// ```
```

The `# use my_project::Calculator;` and `# let mut calc = Calculator::new();` lines compile but are hidden in HTML docs, keeping examples focused.

---

## 11.10 Test Fixtures and File I/O — the `tempfile` Crate

Tests that write to disk should use a temporary directory that is cleaned up automatically. The `tempfile` crate is the standard tool.

Add to `Cargo.toml`:

```toml
[dev-dependencies]
tempfile = "3"
```

### Pattern: temporary directory fixture

```rust,no_run
// src/lib.rs

use std::path::Path;
use std::fs;

pub fn write_report(dir: &Path, name: &str, content: &str) -> std::io::Result<()> {
    let path = dir.join(format!("{name}.txt"));
    fs::write(path, content)
}

pub fn report_exists(dir: &Path, name: &str) -> bool {
    dir.join(format!("{name}.txt")).exists()
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn setup_temp_dir() -> TempDir {
        // TempDir deletes the directory when it is dropped
        tempfile::tempdir().expect("failed to create temp dir")
    }

    #[test]
    fn write_creates_file() {
        let dir = setup_temp_dir();
        write_report(dir.path(), "summary", "hello world").unwrap();
        assert!(report_exists(dir.path(), "summary"));
    }

    #[test]
    fn missing_report_returns_false() {
        let dir = setup_temp_dir();
        assert!(!report_exists(dir.path(), "nonexistent"));
    }

    #[test]
    fn write_content_is_correct() -> std::io::Result<()> {
        let dir = setup_temp_dir();
        write_report(dir.path(), "data", "42\n")?;
        let content = std::fs::read_to_string(dir.path().join("data.txt"))?;
        assert_eq!(content, "42\n");
        Ok(())
    }
}
```

`TempDir` implements `Drop` — the directory and all its contents are removed when the value goes out of scope, even if the test panics. This is the Rust equivalent of JUnit's `@TempDir` annotation.

---

## 11.11 Table-Driven Tests (Rust's Parametrized Tests)

Rust has no built-in parametrized test runner like JUnit's `@ParameterizedTest`. The idiomatic substitute is a table-driven loop inside a single test:

```rust,no_run
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_table_driven() {
        // (a, b, expected)
        let cases: &[(i64, i64, i64)] = &[
            (0,  0,  0),
            (1,  1,  2),
            (-1, 1,  0),
            (i64::MAX - 1, 1, i64::MAX),
            (100, -200, -100),
        ];

        let mut calc = Calculator::new();
        for &(a, b, expected) in cases {
            let result = calc.add(a, b)
                .unwrap_or_else(|e| panic!("add({a}, {b}) failed: {e}"));
            assert_eq!(
                result, expected,
                "add({a}, {b}) = {result}, expected {expected}"
            );
        }
    }

    #[test]
    fn divide_error_cases() {
        let error_cases: &[(i64, i64)] = &[
            (1, 0),
            (100, 0),
            (-5, 0),
        ];

        let mut calc = Calculator::new();
        for &(a, b) in error_cases {
            assert!(
                calc.divide(a, b).is_err(),
                "divide({a}, {b}) should have returned Err"
            );
        }
    }
}
```

**Limitation vs. JUnit:** All subtable iterations run inside a single named test. If one iteration fails, the whole test fails and subsequent iterations do not run. For independent parametrized failures, consider the `rstest` crate, which provides a procedural-macro approach similar to JUnit 5's `@ParameterizedTest`.

---

## 11.12 Integration Test for a CLI Command

Testing a binary (not a library) means spawning a child process and checking its output. The `std::process::Command` API handles this cleanly.

```rust,no_run
// tests/cli_test.rs

use std::process::Command;

/// Helper: run the binary and return (exit_code, stdout, stderr)
fn run_bin(args: &[&str]) -> (i32, String, String) {
    let output = Command::new(env!("CARGO_BIN_EXE_my_tool"))
        .args(args)
        .output()
        .expect("failed to run binary");

    let code   = output.status.code().unwrap_or(-1);
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    (code, stdout, stderr)
}

#[test]
fn help_flag_exits_zero() {
    let (code, stdout, _stderr) = run_bin(&["--help"]);
    assert_eq!(code, 0, "expected exit code 0 for --help");
    assert!(stdout.contains("Usage"), "expected 'Usage' in help output");
}

#[test]
fn unknown_flag_exits_nonzero() {
    let (code, _stdout, stderr) = run_bin(&["--definitely-not-a-flag"]);
    assert_ne!(code, 0);
    assert!(!stderr.is_empty());
}
```

`env!("CARGO_BIN_EXE_my_tool")` expands to the path of the compiled binary at compile time. Replace `my_tool` with the binary name declared in `Cargo.toml` under `[[bin]]`.

**Java comparison:** In Java you typically test CLIs with Apache Commons Exec, ProcessBuilder, or a framework like Picocli's built-in test support. Rust's standard library is sufficient for most CLI integration tests.

---

## 11.13 Testing Async Code — Brief Overview

Async tests require a runtime to drive the `Future` to completion. The most common approach uses `tokio`:

Add to `Cargo.toml`:

```toml
[dev-dependencies]
tokio = { version = "1", features = ["rt", "macros"] }
```

```rust,no_run
// src/lib.rs

pub async fn fetch_greeting(name: &str) -> String {
    // In real code this might call an HTTP API
    format!("Hello, {name}!")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn greeting_contains_name() {
        let msg = fetch_greeting("Ferris").await;
        assert!(msg.contains("Ferris"), "got: {msg}");
    }

    #[tokio::test]
    async fn greeting_is_not_empty() {
        let msg = fetch_greeting("").await;
        assert!(!msg.is_empty());
    }
}
```

`#[tokio::test]` is a procedural macro that wraps the async function in a `tokio::runtime::Runtime::block_on` call. The `macros` feature in Tokio's `Cargo.toml` entry is required; omitting it produces a confusing compile error.

For the `async-std` runtime, the equivalent is `#[async_std::test]` from the `async-std` crate.

**Java comparison:** JUnit 5's `@Test` works directly with `CompletableFuture` only if you block on it. For proper async testing in Java (Project Loom, reactive frameworks) you need additional infrastructure. Rust's async test story is similarly opt-in.

---

## 11.14 Advanced Patterns

### Testing error cases with `matches!`

The `matches!` macro tests a value against a pattern without binding — useful for enum variants with data you don't care about:

```rust,no_run
#[test]
fn sqrt_negative_is_correct_variant() {
    let mut calc = Calculator::new();
    let result = calc.sqrt(-4.0);
    assert!(matches!(result, Err(CalcError::NegativeSqrt)));
}
```

### `assert_matches!` — nightly only

The standard library's `assert_matches!` macro (in `std::assert_matches`) is cleaner but requires nightly Rust:

```rust,no_run
// Requires: #![feature(assert_matches)] and a nightly toolchain
#![feature(assert_matches)]
use std::assert_matches::assert_matches;

#[test]
fn nightly_assert_matches() {
    let x: Option<i32> = Some(42);
    assert_matches!(x, Some(n) if n > 0);
}
```

**Stable workaround:** Use `matches!` inside `assert!`, or the `assert_matches` crate (third-party, stable):

```toml
[dev-dependencies]
assert_matches = "1.5"
```

```rust,no_run
use assert_matches::assert_matches;

#[test]
fn stable_assert_matches() {
    let x: Option<i32> = Some(42);
    assert_matches!(x, Some(n) if n > 0);
}
```

### Mocking patterns — contrast with Java Mockito

Rust has no bytecode runtime, so Mockito-style runtime mock injection is impossible. The Rust approach uses trait objects and manual test doubles:

```rust,no_run
// production code
pub trait EmailSender {
    fn send(&self, to: &str, body: &str) -> Result<(), String>;
}

pub struct NotificationService<S: EmailSender> {
    sender: S,
}

impl<S: EmailSender> NotificationService<S> {
    pub fn new(sender: S) -> Self { Self { sender } }

    pub fn sender(&self) -> &S { &self.sender }

    pub fn notify_user(&self, email: &str) -> Result<(), String> {
        self.sender.send(email, "You have a notification!")
    }
}

// test double — defined in test code only
#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    struct SpySender {
        calls: RefCell<Vec<String>>,  // interior mutability for &self
    }

    impl SpySender {
        fn new() -> Self { Self { calls: RefCell::new(vec![]) } }
        fn call_count(&self) -> usize { self.calls.borrow().len() }
    }

    impl EmailSender for SpySender {
        fn send(&self, to: &str, _body: &str) -> Result<(), String> {
            self.calls.borrow_mut().push(to.to_string());
            Ok(())
        }
    }

    #[test]
    fn notify_calls_sender_once() {
        let spy = SpySender::new();
        let svc = NotificationService::new(spy);
        svc.notify_user("alice@example.com").unwrap();
        // Access the spy through the getter — no ownership transfer needed
        assert_eq!(svc.sender().call_count(), 1);
    }

    #[test]
    fn notify_propagates_sender_error() {
        struct FailSender;
        impl EmailSender for FailSender {
            fn send(&self, _to: &str, _body: &str) -> Result<(), String> {
                Err("SMTP connection refused".to_string())
            }
        }

        let svc = NotificationService::new(FailSender);
        let result = svc.notify_user("bob@example.com");
        assert!(result.is_err());
    }
}
```

For richer mock generation (argument matchers, call count assertions, return value sequences), the `mockall` crate provides procedural macros similar to Mockito:

```toml
[dev-dependencies]
mockall = "0.13"
```

```rust,no_run
use mockall::automock;

#[automock]
pub trait EmailSender {
    fn send(&self, to: &str, body: &str) -> Result<(), String>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[test]
    fn uses_mockall() {
        let mut mock = MockEmailSender::new();
        mock.expect_send()
            .with(eq("alice@example.com"), always())
            .times(1)
            .returning(|_, _| Ok(()));

        let svc = NotificationService::new(mock);
        svc.notify_user("alice@example.com").unwrap();
        // mockall asserts the expectation automatically on Drop
    }
}
```

**Java comparison:** Mockito works through runtime bytecode manipulation — no production code changes needed. Rust's approach requires the production code to be written against a trait (interface). This constraint is generally a positive: it forces dependency injection at the design level. The `mockall` crate provides the expectation API; the trait requirement is non-negotiable.

### Property-based testing — `proptest` preview

Property-based tests generate random inputs and assert invariants rather than testing specific values. The `proptest` crate is the standard choice:

```toml
[dev-dependencies]
proptest = "1"
```

```rust,no_run
use proptest::prelude::*;

proptest! {
    #[test]
    fn add_is_commutative(a in -1000i64..=1000, b in -1000i64..=1000) {
        let mut calc = Calculator::new();
        // Commutativity: a + b == b + a (when neither overflows)
        let ab = calc.add(a, b);
        let ba = calc.add(b, a);
        prop_assert_eq!(ab, ba);
    }

    #[test]
    fn sqrt_non_negative_result(a in 0.0f64..10_000.0) {
        let mut calc = Calculator::new();
        let result = calc.sqrt(a).unwrap();
        prop_assert!(result >= 0.0);
    }
}
```

`proptest!` generates 256 random inputs by default and shrinks failing cases to the smallest counterexample. This is equivalent to Java's `jqwik` library.

---

## 11.15 Structuring a Real Project's Tests

Here is the full recommended layout for a non-trivial Rust library:

```
my_lib/
├── Cargo.toml
├── src/
│   ├── lib.rs              ← public API; unit tests at bottom
│   ├── calculator.rs       ← Calculator struct; unit tests at bottom
│   └── parser.rs           ← expression parser; unit tests at bottom
├── tests/
│   ├── common/
│   │   └── mod.rs          ← shared helpers, NOT a test suite itself
│   ├── calculator_e2e.rs   ← integration tests for Calculator
│   └── cli.rs              ← CLI binary integration tests
└── benches/
    └── calc_bench.rs       ← criterion benchmarks (not tests)
```

**Rule of thumb:**
- Unit tests belong in the source file, in `#[cfg(test)] mod tests`.
- Integration tests belong in `tests/`, one file per feature area.
- Benchmarks belong in `benches/`.
- Doc tests belong in `///` comments on public items.
- All four categories run when you call `cargo test` (except benchmarks, which require `cargo bench`).

---

## 11.16 Quick Reference

### Assertion macros

| Macro                               | Passes when                              |
|-------------------------------------|------------------------------------------|
| `assert!(expr)`                     | `expr` is `true`                         |
| `assert_eq!(a, b)`                  | `a == b` (`PartialEq` required)          |
| `assert_ne!(a, b)`                  | `a != b`                                 |
| `assert!(matches!(v, Pat))`         | `v` matches pattern `Pat` (stable)       |
| `assert_matches!(v, Pat)` (nightly) | `v` matches pattern `Pat` with guards    |

All macros accept a trailing format string: `assert_eq!(a, b, "ctx: {}", info)`.

### Attributes

| Attribute                         | Effect                                                |
|-----------------------------------|-------------------------------------------------------|
| `#[test]`                         | Marks a function as a test                            |
| `#[cfg(test)]`                    | Compiles the block only during `cargo test`           |
| `#[should_panic]`                 | Test passes if the body panics                        |
| `#[should_panic(expected = "…")]` | Test passes if panic message contains `"…"`           |
| `#[ignore]`                       | Skip the test unless `--ignored` is passed            |
| `#[ignore = "reason"]`            | Same, with a human-readable reason                    |

### `cargo test` command reference

| Command                                          | Effect                                     |
|--------------------------------------------------|--------------------------------------------|
| `cargo test`                                     | Run all tests in parallel                  |
| `cargo test <name>`                              | Run tests whose name contains `<name>`     |
| `cargo test -- --nocapture`                      | Show `println!` from passing tests         |
| `cargo test -- --test-threads=1`                 | Run tests sequentially                     |
| `cargo test -- --ignored`                        | Run only `#[ignore]`d tests                |
| `cargo test -- --include-ignored`                | Run all tests including `#[ignore]`d       |
| `cargo test --doc`                               | Run only doc tests                         |
| `cargo test --test <filename>`                   | Run one integration test file              |
| `cargo test --lib`                               | Run only unit tests (lib tests)            |

---

## 📝 Chapter Review Notes

### Critical review and fact-check

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | `#[test]` attribute | Verified | Stable since Rust 1.0; no changes in Rust 2024 edition. |
| 2 | `assert_eq!` argument order | Clarified | No fixed expected/actual semantic; convention documented. |
| 3 | `#[should_panic(expected = "…")]` is substring match | Verified | The Rust book confirms substring matching, not equality. Important gotcha not always understood. |
| 4 | `--test-threads=1` plural spelling | Corrected | The task description contained a typo (`--test-thread=1`). The correct flag is `--test-threads=1`. Verified against `cargo test -- --help`. |
| 5 | `assert_matches!` is nightly-only | Verified | `std::assert_matches` stabilization is pending as of Rust 1.85/2024 edition. Stable workaround shown with the `assert_matches` crate (version 1.5). |
| 6 | `tokio::test` feature requirement | Documented | The `macros` feature (and often `rt` or `rt-multi-thread`) must be declared in `Cargo.toml`. Omitting `macros` gives an unhelpful "use of undeclared crate" error. |
| 7 | `env!("CARGO_BIN_EXE_name")` | Verified | Stable Cargo feature for integration tests of binaries. The string must match the binary name in `[[bin]]` in `Cargo.toml`. |
| 8 | Doc tests: `# ` prefix hides lines | Verified | The `# ` (hash-space) prefix in doc test fences is compiled but hidden in rendered HTML. Standard idiom. |
| 9 | `tests/common/mod.rs` vs `tests/common.rs` | Clarified | Using `tests/common.rs` causes Cargo to treat it as a test suite itself and run it (printing "0 tests" or picking up stray items). Using `tests/common/mod.rs` avoids this. |
| 10 | `#[bench]` is nightly-only | Verified | Built-in benchmarking is nightly-only. The `criterion` crate is the stable alternative. `cargo bench` triggers criterion runs. |
| 11 | `mockall` crate version | Current | Version 0.13 is the latest stable release at time of writing (May 2026). Pin `"0.13"` rather than `"*"` in `Cargo.toml`. |
| 12 | `proptest` crate | Preview only | Version 1.x is stable. The `proptest!` macro generates 256 test cases by default (configurable via `ProptestConfig`). This chapter only previews it — a full proptest chapter could stand alone. |
| 13 | Java mocking comparison accuracy | Honest caveat | The statement "Mockito works through runtime bytecode manipulation" is accurate. The Rust trait-based approach genuinely requires more design discipline. This is not a neutral difference — Java's runtime mocking is more ergonomic for legacy codebases. |
| 14 | Rust 2024 edition impact on tests | Minimal | The 2024 edition does not change the test system. The `cargo test` runner, `#[test]` attribute, and all macros are edition-independent. |
| 15 | `TempDir` drop behavior on panic | Verified | `tempfile::TempDir` uses `Drop` which runs even on unwind panics (unless the process aborts). Safe for test cleanup. |

### Post-draft corrections

| Fix | Description |
|-----|-------------|
| `notify_calls_sender_once` | Original draft had no assertions — the test would have passed even if `notify_user` did nothing. Fixed by adding a `sender()` getter to `NotificationService` and asserting `svc.sender().call_count() == 1`. |
| `add_records_history` | Original used `assert!(history[0].contains("30"))` — fragile because "130" also contains "30". Changed to `assert_eq!(history[0], "10 + 20 = 30")`. |
| Doc test on dead function | Original attached the `/// # Examples` doc comment to a placeholder `divide_doc_example()` function. Fixed to show the comment on the real `Calculator::divide` method. |

### Line budget

This chapter is approximately 1155 lines against a 700-900 target (roughly 28% over). The overage comes from the comprehensive `Calculator` example (§11.7), the mocking section with two complete code blocks (trait-object spy + `mockall`), and the full quick-reference tables. Suggested cuts if the chapter needs trimming: remove the `mockall` block and keep only the trait-object example; condense the CLI test to a single function; drop the proptest preview (defer to a dedicated chapter).

### Known simplifications / out-of-scope items

- **`rstest` crate** (parametrized tests with individual test names per case) was mentioned but not fully demonstrated. It deserves its own section in an advanced testing chapter.
- **`wiremock` crate** (HTTP server mocking) was intentionally omitted; it belongs in an HTTP/networking chapter.
- **`insta` crate** (snapshot testing) is popular for testing complex output strings. Not covered.
- **Mutation testing** (`cargo-mutants`) was omitted. It is an emerging practice in the Rust ecosystem.
- **Code coverage** (`cargo llvm-cov` or `cargo tarpaulin`) was not covered. Coverage tooling deserves a dedicated section.
- **`#[test_case]` from `test-case` crate** provides table-driven tests with distinct test names — a better parametrized story than the manual loop shown in §11.11 for many use cases.
