# Chapter 1: Getting Started

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

## 1.1 Installing Rust

### Install via rustup (recommended)

```bash
# Linux / macOS
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh

# Windows: download and run rustup-init.exe from https://rustup.rs
```

After installation, open a new terminal and verify:

```bash
rustc --version
# rustc 1.85.0 (2024 edition baseline)  ← your version will differ

cargo --version
# cargo 1.85.0 (2025-02-xx)   ← your version will differ

rustup --version
# rustup 1.27.x
```

### Keeping Rust up to date

```bash
rustup update          # update all installed toolchains
rustup show            # list installed toolchains and active one
rustup default stable  # set stable as the default toolchain
```

### Installing nightly (needed for some experimental features)

```bash
rustup toolchain install nightly
rustup override set nightly   # use nightly only in the current directory
rustup override set stable    # revert
```

### macOS: install the C linker (required)

```bash
xcode-select --install
```

### Linux: install build essentials

```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y build-essential

# Fedora/RHEL
sudo dnf group install "Development Tools"
```

### Accessing offline documentation

```bash
rustup doc           # opens the full standard library docs in your browser
rustup doc --book    # opens The Rust Programming Language book
rustup doc --std     # opens std lib reference
```

---

## 1.2 Hello, World!

### Bare compiler — no Cargo

```rust
// src: hello_world/main.rs
fn main() {
    println!("Hello, world!");
}
```

```bash
rustc main.rs        # produces ./main (Linux/macOS) or main.exe (Windows)
./main               # Hello, world!
```

### Key points about `main`

```rust
fn main() {
    // 1. `fn` declares a function
    // 2. `main` is the program entry point — it takes no parameters by default
    // 3. The body is enclosed in curly braces {}
    // 4. println! is a MACRO (note the !), not a function
    println!("Hello, world!");
    // 5. Every statement ends with a semicolon ;
}
```

### Printing various types

```rust
fn main() {
    // String literals
    println!("Hello, world!");

    // Variables with {}
    let name = "Alice";
    let age = 30;
    println!("Name: {}, Age: {}", name, age);

    // Named arguments (Rust 1.58+)
    println!("Name: {name}, Age: {age}");

    // Debug output with {:?}
    let numbers = vec![1, 2, 3];
    println!("Numbers: {:?}", numbers);

    // Pretty-printed debug with {:#?}
    println!("Numbers:\n{:#?}", numbers);

    // Padding and alignment
    println!("{:>10}", "right");     //      right
    println!("{:<10}", "left");      // left
    println!("{:^10}", "center");    //   center
    println!("{:0>5}", 42);          // 00042

    // Floating point precision
    let pi = std::f64::consts::PI;
    println!("Pi = {:.4}", pi);      // Pi = 3.1416

    // Print without newline
    print!("no newline here ");
    print!("same line\n");

    // Print to stderr
    eprintln!("Error: something went wrong");
}
```

### Using `format!` to build strings

```rust
fn main() {
    let greeting = format!("Hello, {}!", "Rustacean");
    println!("{}", greeting);  // Hello, Rustacean!

    // Useful for building strings from parts
    let items = vec!["apple", "banana", "cherry"];
    let list = items.join(", ");
    let msg = format!("Items: [{}]", list);
    println!("{}", msg);  // Items: [apple, banana, cherry]
}
```

---

## 1.3 Hello, Cargo!

Cargo is Rust's build system and package manager. You should almost always use it.

### Creating a new project

```bash
cargo new hello_cargo        # binary project (creates src/main.rs)
cargo new my_lib --lib       # library project (creates src/lib.rs)
cargo init                   # initialize Cargo in the current directory
```

### Project layout

```
hello_cargo/
├── Cargo.toml       ← project manifest
├── Cargo.lock       ← exact dependency versions (auto-generated)
├── src/
│   └── main.rs      ← entry point
└── .gitignore       ← auto-generated
```

### Cargo.toml anatomy

```toml
[package]
name = "hello_cargo"
version = "0.1.0"
edition = "2024"        # Rust edition: 2015, 2018, 2021, 2024 (use 2024 for new projects)
authors = ["Your Name <you@example.com>"]
description = "A brief description of the project"

[dependencies]
# External crates go here, e.g.:
# rand = "0.8"

[dev-dependencies]
# Dependencies only used in tests, e.g.:
# pretty_assertions = "1"

[[bin]]
# Optional: configure binary targets
# name = "my-bin"
# path = "src/main.rs"
```

### Essential Cargo commands

```bash
cargo build                  # compile (debug mode, unoptimized)
cargo build --release        # compile with optimizations
cargo run                    # build + run in one step
cargo run -- arg1 arg2       # run with command-line arguments
cargo check                  # type-check without producing a binary (fast!)
cargo test                   # compile and run tests
cargo test -- --nocapture    # run tests showing stdout output
cargo clean                  # delete the target/ directory
cargo doc                    # generate HTML documentation
cargo doc --open             # generate and open documentation in browser
cargo update                 # update dependencies to latest compatible versions
```

### A more realistic Cargo.toml with dependencies

```toml
[package]
name = "my_app"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
anyhow = "1"
thiserror = "1"

[dev-dependencies]
assert_cmd = "2"
predicates = "2"
tempfile = "3"

[profile.release]
opt-level = 3
lto = true            # link-time optimization
codegen-units = 1     # better optimization, slower compile

[profile.dev]
opt-level = 0
debug = true
```

### Adding and removing dependencies via CLI

```bash
cargo add serde --features derive    # add serde with the derive feature
cargo add tokio@1.28 --features full # add a specific version
cargo remove serde                   # remove a dependency
```

### Working with existing projects

```bash
git clone https://github.com/some/project
cd project
cargo build        # Cargo reads Cargo.lock for reproducible builds
cargo test         # run the test suite
```

### Understanding debug vs. release builds

```rust
// This code compiles differently in debug vs. release
fn main() {
    // In debug: integer overflow panics at runtime
    // In release: integer overflow wraps (two's complement)
    // Use explicit methods to be safe in both:
    let x: u8 = 200u8;
    let y: u8 = 100u8;
    
    // Safe addition — returns None on overflow
    match x.checked_add(y) {
        Some(result) => println!("Sum: {}", result),
        None => println!("Overflow!"),  // This prints: Overflow!
    }

    // Wrapping addition — always wraps
    let wrapped = x.wrapping_add(y);
    println!("Wrapped: {}", wrapped);  // 44

    // Saturating addition — clamps to max/min
    let saturated = x.saturating_add(y);
    println!("Saturated: {}", saturated);  // 255
}
```

### Cargo workspace — managing multiple related crates

```bash
# In your project root, create Cargo.toml:
```

```toml
# Cargo.toml (workspace root)
[workspace]
members = [
    "core",
    "cli",
    "server",
]
resolver = "2"
```

```bash
cargo new core --lib
cargo new cli
cargo new server

# Now build everything at once:
cargo build --workspace

# Run a specific member:
cargo run -p cli
```

---

## 1.4 Practical: Your First Real Program

Let's write something more useful than "Hello, world!" — a program that reads a name from the command line and greets the user.

```rust
// src/main.rs
use std::env;

fn main() {
    // Collect command-line arguments into a Vec<String>
    let args: Vec<String> = env::args().collect();

    // args[0] is always the program name
    let name = if args.len() > 1 {
        &args[1]
    } else {
        "world"
    };

    println!("Hello, {}!", name);
}
```

```bash
cargo run                   # Hello, world!
cargo run -- Alice          # Hello, Alice!
cargo run -- "Rust User"    # Hello, Rust User!
```

### A program that reads from stdin

```rust
use std::io;
use std::io::BufRead;

fn main() {
    let stdin = io::stdin();
    println!("Enter lines (Ctrl+D / Ctrl+Z to stop):");

    let mut count = 0;
    for line in stdin.lock().lines() {
        match line {
            Ok(text) => {
                count += 1;
                println!("Line {}: {}", count, text);
            }
            Err(e) => {
                eprintln!("Error reading line: {}", e);
                break;
            }
        }
    }

    println!("Total lines: {}", count);
}
```

---

## Review & Self-Check

| Concept | Quick test |
|---------|-----------|
| `rustc` vs `cargo` | Can you compile a file with `rustc` directly? When would you choose that over `cargo`? |
| `println!` vs `print!` | What's the difference? What about `eprintln!`? |
| Debug format | What does `{:?}` do differently than `{}`? |
| Cargo manifest | What is the purpose of `Cargo.lock`? Should you commit it? |
| Build profiles | What's the difference between `cargo build` and `cargo build --release`? |

---

## Common Pitfalls

```rust
fn main() {
    // ❌ WRONG: trying to use {} with a type that doesn't implement Display
    let v = vec![1, 2, 3];
    // println!("{}", v);  // compile error!

    // ✅ CORRECT: use debug format {:?}
    println!("{:?}", v);

    // ❌ WRONG: forgetting the semicolon on a statement
    // let x = 5
    // println!("{}", x);  // compile error

    // ✅ CORRECT
    let x = 5;
    println!("{}", x);

    // ❌ WRONG: println is a macro, not a function — don't omit the !
    // println("Hello");  // compile error

    // ✅ CORRECT
    println!("Hello");
}
```

---

---

## 📝 Chapter Review Notes

*This section records the third-person critical review performed after drafting, and the revisions made in response.*

### Issues Found & Fixed

| # | Issue | Severity | Fix Applied |
|---|-------|----------|-------------|
| 1 | Version numbers showed `rustc 1.78.0` — stale (current is 1.85+, Rust 2024 edition ships with 1.85) | Medium | Updated version comments to reflect 2025 reality |
| 2 | `edition = "2021"` in Cargo.toml example — as of Feb 2025 (Rust 1.85), `2024` is the default edition | High | Updated all `edition` references to `"2024"` |
| 3 | `cargo add` syntax is correct for current Cargo versions — verified no issue | OK | No change needed |
| 4 | `[[bin]]` example is syntactically valid TOML — verified | OK | No change needed |

### What This Chapter Does Well
- Dense practical examples beyond the official book
- Covers cross-platform installation variations
- Shows `format!` and alignment formatting often missing from intro chapters
- Demonstrates debug vs. release build differences with integer overflow

### What Could Be Improved (future editions)
- Could add `cargo fmt` and `cargo clippy` introductions — they're essential day-one tools
- The workspace section, while useful, may be too advanced for Ch1 readers
- Could show a `.cargo/config.toml` for setting a default target

---

*Next: [Chapter 2 — Programming a Guessing Game](ch02-guessing-game.md)*
