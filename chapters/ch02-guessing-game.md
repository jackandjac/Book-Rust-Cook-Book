# Chapter 2: Programming a Guessing Game

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

This chapter is a progressive walkthrough. You will build one program — a number-guessing game — and grow it step by step. Along the way you will meet the key language features that appear in nearly every Rust program you will ever write.

**By the end of this chapter you will understand:**

- `use` — importing names from the standard library and external crates
- `let` vs `let mut` — Rust's default-immutable variable model
- `String` vs `&str` — the two string types Java developers always trip over
- `match` — exhaustive pattern matching (no accidental fall-through)
- `Result<T, E>` — error handling without exceptions
- `loop` / `break` — Rust's infinite-loop construct
- Variable shadowing — reusing a name with a different type in the same scope
- External crates — adding `rand` as a dependency and using it

---

## 2.1 Setting Up the Project

```bash
cargo new guessing_game
cd guessing_game
```

Cargo creates:

```
guessing_game/
├── Cargo.toml
└── src/
    └── main.rs
```

Open `Cargo.toml`. It should look like this:

```toml
[package]
name = "guessing_game"
version = "0.1.0"
edition = "2024"

[dependencies]
```

> **Java parallel:** This is your `pom.xml` or `build.gradle`. `[dependencies]` is where you declare third-party libraries (called *crates* in Rust).

---

## 2.2 Version 1 — Read a Guess from the User

Start with the absolute minimum: ask for a number, read it, print it back.

```rust
// src/main.rs  —  v1: read a guess
use std::io;

fn main() {
    println!("Guess the number!");
    println!("Please input your guess:");

    let mut guess = String::new();

    io::stdin()
        .read_line(&mut guess)
        .expect("Failed to read line");

    println!("You guessed: {guess}");
}
```

```bash
cargo run
# Guess the number!
# Please input your guess:
# 42
# You guessed: 42
```

### Breaking it down line by line

#### `use std::io;`

```rust,no_run
use std::io;
```

This brings the `io` module from the standard library into scope so you can write `io::stdin()` instead of `std::io::stdin()`.

> **Java parallel:** Like `import java.util.Scanner;`. Rust doesn't auto-import anything beyond a small *prelude* (a handful of the most common types). Everything else requires an explicit `use`.

The Rust prelude includes things like `Vec`, `String`, `Option`, `Result`, and `println!` — but `io::stdin` is not in it.

#### `let mut guess = String::new();`

```rust,no_run
let mut guess = String::new();
```

Two things are happening here that differ from Java:

| Concept | Java | Rust |
|---------|------|------|
| Declare a variable | `String guess = new StringBuilder().toString();` | `let guess = String::new();` |
| Make it mutable | All variables are mutable by default | Must opt-in with `mut` |
| Default value | `null` (reference, can be null) | `String::new()` (heap-allocated, empty, never null) |

`String::new()` is an *associated function* (Rust's term for a static factory method) that creates a new, empty `String` on the heap.

Why does `guess` need `mut`? Because `read_line` will modify it. Without `mut`, the compiler refuses:

```rust,no_run
// ❌ WRONG — Rust won't compile this
let guess = String::new();
io::stdin().read_line(&mut guess).expect("...");
// error[E0596]: cannot borrow `guess` as mutable, as it is not declared as mutable
```

```rust,no_run
// ✅ CORRECT
let mut guess = String::new();
io::stdin().read_line(&mut guess).expect("...");
```

#### `io::stdin().read_line(&mut guess)`

```rust,no_run
io::stdin()
    .read_line(&mut guess)
    .expect("Failed to read line");
```

`io::stdin()` returns a handle to standard input. Calling `.read_line(&mut guess)` appends the user's input (including the newline character `\n`) to `guess`.

The `&mut guess` is a *mutable reference* — you are lending `read_line` permission to modify `guess` without giving up ownership of it. This is the borrow checker in action. You'll explore ownership and borrowing in depth in Chapter 4; for now just know that `&mut` means "a mutable loan."

`.read_line` returns `io::Result<usize>` — the number of bytes read. `Result` is an enum:

```rust,no_run
// Simplified definition (not the actual source)
enum Result<T, E> {
    Ok(T),   // success — carries a value of type T
    Err(E),  // failure — carries an error of type E
}
```

`.expect("Failed to read line")` handles the result: if it's `Ok`, it unwraps the value; if it's `Err`, it panics with the message you provided.

> **Java parallel:** `Result` is Rust's alternative to checked exceptions. Instead of `throws IOException`, the error is carried in the return value and you are forced to handle it (or explicitly ignore it). `.expect()` is the "crash if it failed" shortcut — fine for prototyping, replaced by proper error handling later.

#### `println!("You guessed: {guess}")`

The `{guess}` syntax (inline variable capture, since Rust 1.58) inserts the value of `guess` directly into the string. It is equivalent to `println!("You guessed: {}", guess)`.

---

## 2.3 Version 2 — Generate a Secret Number

To generate a random number we need an external crate. Edit `Cargo.toml`:

```toml
[package]
name = "guessing_game"
version = "0.1.0"
edition = "2024"

[dependencies]
rand = "0.10"
```

```bash
cargo build
# Cargo downloads rand and its dependencies, then compiles everything
```

> **Java parallel:** Like adding a Maven dependency. Cargo reads `Cargo.lock` to pin exact versions, just like Maven's lock files or Gradle's dependency lock. You can also run `cargo add rand` from the CLI to add a dependency without editing `Cargo.toml` by hand.

Now update `src/main.rs`:

```rust,no_run
// src/main.rs  —  v2: generate a secret number and compare
use std::io;
use std::cmp::Ordering;
use rand;

fn main() {
    let secret_number: u32 = rand::random_range(1..=100);

    println!("Guess the number! (between 1 and 100)");
    println!("Please input your guess:");

    let mut guess = String::new();

    io::stdin()
        .read_line(&mut guess)
        .expect("Failed to read line");

    // Convert the String to a u32 — more on error handling in v3
    let guess: u32 = guess.trim().parse().expect("Please type a number!");

    println!("You guessed: {guess}");

    match guess.cmp(&secret_number) {
        Ordering::Less    => println!("Too small!"),
        Ordering::Greater => println!("Too big!"),
        Ordering::Equal   => println!("You win!"),
    }
}
```

```bash
cargo run
# Guess the number! (between 1 and 100)
# Please input your guess:
# 50
# You guessed: 50
# Too big!
```

### What's new in v2

#### `rand::random_range(1..=100)`

```rust,no_run
let secret_number: u32 = rand::random_range(1..=100);
```

`rand::random_range` is a top-level function that generates a random value in the given range using the thread-local RNG. The `1..=100` is a *range literal* — a closed range from 1 to 100 inclusive (both endpoints included). The open-ended variant `1..100` would cover 1 to 99.

> **Note on rand versions:** rand 0.10 (current as of 2026) provides `rand::random_range` as a standalone function. Older code using rand 0.8 used `rand::thread_rng().gen_range(1..=100)` with `use rand::Rng;`. If you encounter that pattern in tutorials, it is pre-0.9 code.

The type annotation `: u32` tells Rust which integer type to generate. Without it, the compiler cannot infer the type from `random_range` alone and will report an error.

#### `use std::cmp::Ordering`

`Ordering` is an enum with three variants: `Less`, `Greater`, `Equal`. It is returned by the `.cmp()` method, which is available on any type that implements `PartialOrd`.

#### Variable Shadowing: `let guess: u32 = guess.trim().parse()...`

```rust,no_run
let mut guess = String::new();   // guess is a String
// ... read_line fills guess ...
let guess: u32 = guess.trim().parse().expect("Please type a number!");
// guess is now a u32 — same name, different type!
```

You declared `guess` twice — the second `let` *shadows* the first. The new binding has a completely different type (`u32` instead of `String`). This is intentional and idiomatic in Rust for type conversions.

> **Java parallel:** This is NOT possible in Java. In Java, once you declare `String guess`, you cannot redeclare `guess` as an `int` in the same scope. In Rust, shadowing is a feature. It avoids having to invent names like `guess_str` and `guess_num`.

Why call `.trim()`? Because `read_line` appends a `\n` (or `\r\n` on Windows) to the string. Without trimming, `"42\n".parse::<u32>()` fails.

#### `match guess.cmp(&secret_number)`

```rust,no_run
match guess.cmp(&secret_number) {
    Ordering::Less    => println!("Too small!"),
    Ordering::Greater => println!("Too big!"),
    Ordering::Equal   => println!("You win!"),
}
```

`match` is like a `switch` statement but with two critical differences:

1. **Exhaustive** — the compiler rejects code that does not cover all possible variants. There is no accidental fall-through to a default case.
2. **Each arm is an expression** — the arms can return values (explored later).

`.cmp(&secret_number)` compares `guess` to `secret_number` and returns an `Ordering`. Note `&secret_number` — you pass a reference because `.cmp` borrows the value for comparison.

---

## 2.4 Version 3 — Loop Until Correct

The game should keep asking until the player wins. Replace the single-shot comparison with a `loop`:

```rust,no_run
// src/main.rs  —  v3: loop until the player wins
use std::io;
use std::cmp::Ordering;
use rand;

fn main() {
    let secret_number: u32 = rand::random_range(1..=100);

    println!("Guess the number! (between 1 and 100)");

    loop {
        println!("Please input your guess:");

        let mut guess = String::new();

        io::stdin()
            .read_line(&mut guess)
            .expect("Failed to read line");

        let guess: u32 = guess.trim().parse().expect("Please type a number!");

        println!("You guessed: {guess}");

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("You win!");
                break;
            }
        }
    }
}
```

`loop` creates an infinite loop. `break` exits it. This is Rust's idiomatic equivalent of `while (true) { ... break; }`.

> **Java parallel:** `loop { ... break; }` is functionally identical to `while(true) { ... break; }`. Rust has `while` too, but `loop` communicates intent more clearly and lets the compiler reason about definite assignment better.

---

## 2.5 Version 4 — Handle Bad Input Gracefully

Right now, if the user types `"abc"`, the program panics. Let's handle that gracefully using `match` on the `Result` from `.parse()`:

```rust,no_run
// src/main.rs  —  v4: handle invalid input without panicking
use std::io;
use std::cmp::Ordering;
use rand;

fn main() {
    let secret_number: u32 = rand::random_range(1..=100);

    println!("Guess the number! (between 1 and 100)");

    loop {
        println!("Please input your guess:");

        let mut guess = String::new();

        io::stdin()
            .read_line(&mut guess)
            .expect("Failed to read line");

        // Instead of .expect(), match on the Result
        let guess: u32 = match guess.trim().parse() {
            Ok(num) => num,
            Err(_)  => {
                println!("Please type a valid number!");
                continue;   // restart the loop
            }
        };

        println!("You guessed: {guess}");

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("You win!");
                break;
            }
        }
    }
}
```

The key change:

```rust,no_run
let guess: u32 = match guess.trim().parse() {
    Ok(num) => num,
    Err(_)  => {
        println!("Please type a valid number!");
        continue;
    }
};
```

- `Ok(num)` — parsing succeeded; `num` is bound to the parsed `u32`; the `match` expression evaluates to `num`
- `Err(_)` — parsing failed; `_` ignores the error details; we print a message and `continue` to the next loop iteration
- Notice the `let guess: u32 = match { ... };` — `match` is an expression here and its result is assigned directly to `guess`

> **Java parallel:** This is the Rust idiom for checked exceptions without `try/catch`. You pattern-match on the result instead of catching a thrown exception. The `_` in `Err(_)` is the wildcard pattern — equivalent to `catch (Exception e)` where you don't use `e`.

---

## 2.6 The Complete Game

Here is the full, final version of the game with all features assembled:

```rust,no_run
// src/main.rs  —  complete guessing game
use std::io;
use std::cmp::Ordering;
use rand;

fn main() {
    let secret_number: u32 = rand::random_range(1..=100);

    // Uncomment to debug:
    // println!("(The secret number is {secret_number})");

    println!("=== Guess the Number ===");
    println!("I'm thinking of a number between 1 and 100.");

    let mut attempts = 0u32;

    loop {
        println!("\nEnter your guess:");

        let mut input = String::new();

        io::stdin()
            .read_line(&mut input)
            .expect("Failed to read line");

        let guess: u32 = match input.trim().parse() {
            Ok(num) => num,
            Err(_)  => {
                println!("Not a valid number. Try again.");
                continue;
            }
        };

        attempts += 1;

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small! ({attempts} guesses so far)"),
            Ordering::Greater => println!("Too big!  ({attempts} guesses so far)"),
            Ordering::Equal   => {
                println!("Correct! You found it in {attempts} guess(es).");
                break;
            }
        }
    }
}
```

```bash
cargo run
# === Guess the Number ===
# I'm thinking of a number between 1 and 100.
#
# Enter your guess:
# 50
# Too big!  (1 guesses so far)
#
# Enter your guess:
# 25
# Too small! (2 guesses so far)
#
# Enter your guess:
# 37
# Correct! You found it in 3 guess(es).
```

---

## 2.7 Extra Examples

The sections below show how to extend the game with practical features. Each example builds on what you've learned and introduces additional patterns worth knowing.

### 2.7.1 Range Validation — Only Accept 1–100

```rust,no_run
// src/main.rs  —  extra: validate range before comparing
use std::io;
use std::cmp::Ordering;
use rand;

fn main() {
    let secret_number: u32 = rand::random_range(1..=100);

    println!("Guess the number (1–100):");

    loop {
        let mut input = String::new();
        io::stdin().read_line(&mut input).expect("Failed to read line");

        let guess: u32 = match input.trim().parse() {
            Ok(num) => num,
            Err(_)  => { println!("Numbers only."); continue; }
        };

        // Validate range before comparing
        if !(1..=100).contains(&guess) {
            println!("Out of range! Enter a number from 1 to 100.");
            continue;
        }

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => { println!("Correct!"); break; }
        }
    }
}
```

`(1..=100).contains(&guess)` uses the `RangeInclusive` method `contains` — clean and readable.

---

### 2.7.2 Tracking All Previous Guesses

```rust,no_run
// src/main.rs  —  extra: display guess history
use std::io;
use std::cmp::Ordering;
use rand;

fn main() {
    let secret_number: u32 = rand::random_range(1..=100);
    let mut guesses: Vec<u32> = Vec::new();

    println!("Guess the number (1–100):");

    loop {
        if !guesses.is_empty() {
            // Display previous guesses sorted
            let mut sorted = guesses.clone();
            sorted.sort();
            let display: Vec<String> = sorted.iter().map(|n| n.to_string()).collect();
            println!("Previous guesses: [{}]", display.join(", "));
        }

        let mut input = String::new();
        io::stdin().read_line(&mut input).expect("Failed to read line");

        let guess: u32 = match input.trim().parse() {
            Ok(num) => num,
            Err(_)  => { println!("Numbers only."); continue; }
        };

        if guesses.contains(&guess) {
            println!("You already tried {guess}! Pick something else.");
            continue;
        }

        guesses.push(guess);

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("Correct in {} guess(es)!", guesses.len());
                break;
            }
        }
    }
}
```

New concepts here:
- `Vec<u32>` — a growable list (Java's `ArrayList<Integer>`)
- `.push()` — appends to the vector
- `.contains()` — linear search
- `.iter().map(...).collect()` — transform the vector into a `Vec<String>` (a mini pipeline, like Java streams)
- `sorted.sort()` — in-place sort (borrows `sorted` mutably for the duration of the call)

---

### 2.7.3 Difficulty Levels

```rust,no_run
// src/main.rs  —  extra: difficulty levels
use std::io;
use std::cmp::Ordering;
use rand;

fn read_line() -> String {
    let mut buf = String::new();
    io::stdin().read_line(&mut buf).expect("Failed to read line");
    buf.trim().to_string()
}

fn main() {
    println!("=== Guess the Number ===");
    println!("Choose difficulty:");
    println!("  1) Easy   (1–20, unlimited guesses)");
    println!("  2) Medium (1–100, 10 guesses)");
    println!("  3) Hard   (1–500, 7 guesses)");

    let (max_number, max_guesses): (u32, Option<u32>) = loop {
        match read_line().as_str() {
            "1" => break (20, None),
            "2" => break (100, Some(10)),
            "3" => break (500, Some(7)),
            _   => println!("Enter 1, 2, or 3."),
        }
    };

    let secret_number: u32 = rand::random_range(1..=max_number);
    let mut attempts = 0u32;

    println!("\nI'm thinking of a number between 1 and {max_number}.");
    if let Some(limit) = max_guesses {
        println!("You have {limit} guesses.");
    }

    loop {
        // Check if guess limit reached
        if let Some(limit) = max_guesses {
            if attempts >= limit {
                println!("Out of guesses! The number was {secret_number}. Better luck next time.");
                break;
            }
            let remaining = limit - attempts;
            println!("\nGuesses remaining: {remaining}. Enter your guess:");
        } else {
            println!("\nEnter your guess:");
        }

        let mut input = String::new();
        io::stdin().read_line(&mut input).expect("Failed to read line");

        let guess: u32 = match input.trim().parse() {
            Ok(num) if num >= 1 && num <= max_number => num,
            Ok(_)  => {
                println!("Please enter a number between 1 and {max_number}.");
                continue;
            }
            Err(_) => { println!("Numbers only."); continue; }
        };

        attempts += 1;

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("Correct in {attempts} guess(es)!");
                break;
            }
        }
    }
}
```

New patterns introduced:

- **`Option<u32>`** — `Some(10)` means there is a limit; `None` means unlimited. Java equivalent: `Optional<Integer>` (but without the boxing overhead).
- **`if let Some(limit) = max_guesses`** — destructure an `Option` in a single line without a full `match`. Equivalent to `if (maxGuesses != null)` in Java.
- **Match guard** — `Ok(num) if num >= 1 && num <= max_number => num` adds a condition to a `match` arm.
- **Helper function `read_line()`** — avoids repeating the boilerplate; returns a trimmed, owned `String`.

---

### 2.7.4 Play-Again Loop

```rust,no_run
// src/main.rs  —  extra: play again loop
use std::io;
use std::cmp::Ordering;
use rand;

fn read_line() -> String {
    let mut buf = String::new();
    io::stdin().read_line(&mut buf).expect("Failed to read");
    buf.trim().to_string()
}

fn play_round() -> u32 {
    let secret: u32 = rand::random_range(1..=100);
    let mut attempts = 0u32;

    println!("\nI'm thinking of a number between 1 and 100.");

    loop {
        println!("Your guess:");

        let input = read_line();

        let guess: u32 = match input.parse() {
            Ok(n)  => n,
            Err(_) => { println!("Numbers only."); continue; }
        };

        attempts += 1;

        match guess.cmp(&secret) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("Correct in {attempts} guess(es)!");
                return attempts;
            }
        }
    }
}

fn main() {
    println!("=== Guess the Number ===");

    let mut total_games = 0u32;
    let mut total_guesses = 0u32;
    let mut best_score = u32::MAX;

    loop {
        total_games += 1;
        let guesses = play_round();
        total_guesses += guesses;

        if guesses < best_score {
            best_score = guesses;
        }

        println!("\nPlay again? (y/n)");
        match read_line().to_lowercase().as_str() {
            "y" | "yes" => continue,
            _            => break,
        }
    }

    let average = total_guesses as f64 / total_games as f64;
    println!("\n--- Stats ---");
    println!("Games played:   {total_games}");
    println!("Total guesses:  {total_guesses}");
    println!("Best round:     {best_score}");
    println!("Average/game:   {average:.1}");
}
```

New patterns introduced:

- **Functions with return values** — `fn play_round() -> u32` returns the number of guesses taken.
- **`return` in a loop** — `return attempts;` exits both the loop and the function.
- **`u32::MAX`** — the maximum value for a `u32` (equivalent to `Integer.MAX_VALUE` in Java, but typed). Used here to initialize `best_score` so any real score beats it.
- **Cast with `as`** — `total_guesses as f64` converts an integer to a float. Java does this implicitly; Rust requires explicit `as`.
- **`{average:.1}`** — format a float to one decimal place.
- **`to_lowercase().as_str()`** — normalize input before matching. `.to_lowercase()` returns a new `String`; `.as_str()` borrows it as `&str` so it can be matched against string literals.

---

### 2.7.5 Full-Featured Game (All Extensions Combined)

```rust,no_run
// src/main.rs  —  full-featured guessing game
use std::io;
use std::cmp::Ordering;
use rand;

// ── helpers ──────────────────────────────────────────────────────────────────

fn read_line() -> String {
    let mut buf = String::new();
    io::stdin().read_line(&mut buf).expect("Failed to read line");
    buf.trim().to_string()
}

fn parse_u32_in_range(input: &str, min: u32, max: u32) -> Option<u32> {
    match input.parse::<u32>() {
        Ok(n) if n >= min && n <= max => Some(n),
        _ => None,
    }
}

// ── difficulty ───────────────────────────────────────────────────────────────

struct Difficulty {
    name: &'static str,
    max_number: u32,
    max_guesses: Option<u32>,
}

const EASY:   Difficulty = Difficulty { name: "Easy",   max_number: 20,  max_guesses: None        };
const MEDIUM: Difficulty = Difficulty { name: "Medium", max_number: 100, max_guesses: Some(10)    };
const HARD:   Difficulty = Difficulty { name: "Hard",   max_number: 500, max_guesses: Some(7)     };

fn choose_difficulty() -> &'static Difficulty {
    println!("Choose difficulty:");
    println!("  1) Easy   (1–20,  unlimited guesses)");
    println!("  2) Medium (1–100, 10 guesses)");
    println!("  3) Hard   (1–500,  7 guesses)");

    loop {
        match read_line().as_str() {
            "1" => return &EASY,
            "2" => return &MEDIUM,
            "3" => return &HARD,
            _   => println!("Enter 1, 2, or 3."),
        }
    }
}

// ── one round ────────────────────────────────────────────────────────────────

fn play_round(difficulty: &Difficulty) -> Option<u32> {
    let secret: u32 = rand::random_range(1..=difficulty.max_number);
    let mut attempts = 0u32;
    let mut history: Vec<u32> = Vec::new();

    println!(
        "\n[{}] Guess a number between 1 and {}.",
        difficulty.name, difficulty.max_number
    );

    loop {
        // Show remaining guesses if there is a limit
        if let Some(limit) = difficulty.max_guesses {
            if attempts >= limit {
                println!("No guesses left. The number was {secret}.");
                return None;   // signal: player lost
            }
            println!("Guesses left: {}. Your guess:", limit - attempts);
        } else {
            println!("Your guess:");
        }

        let input = read_line();

        let guess = match parse_u32_in_range(&input, 1, difficulty.max_number) {
            Some(n) => n,
            None    => {
                println!("Please enter a number between 1 and {}.", difficulty.max_number);
                continue;
            }
        };

        if history.contains(&guess) {
            println!("You already tried {guess}.");
            continue;
        }

        history.push(guess);
        attempts += 1;

        match guess.cmp(&secret) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("Correct in {attempts} guess(es)!");
                return Some(attempts);  // signal: player won
            }
        }
    }
}

// ── main loop ────────────────────────────────────────────────────────────────

fn main() {
    println!("=== Guess the Number ===\n");

    let difficulty = choose_difficulty();

    let mut wins = 0u32;
    let mut losses = 0u32;
    let mut total_guesses = 0u32;
    let mut best_score = u32::MAX;

    loop {
        match play_round(difficulty) {
            Some(guesses) => {
                wins += 1;
                total_guesses += guesses;
                if guesses < best_score {
                    best_score = guesses;
                }
            }
            None => {
                losses += 1;
            }
        }

        println!("\nPlay again? (y/n)");
        match read_line().to_lowercase().as_str() {
            "y" | "yes" => {}
            _            => break,
        }
    }

    println!("\n--- Final Stats ---");
    println!("Wins:    {wins}");
    println!("Losses:  {losses}");
    if wins > 0 {
        let avg = total_guesses as f64 / wins as f64;
        println!("Best:    {best_score} guess(es)");
        println!("Average: {avg:.1} guess(es) per win");
    }
}
```

---

## 2.8 Common Mistakes Java Developers Make

### Mistake 1 — Forgetting `mut`

```rust,no_run
// ❌ WRONG — variable is immutable by default
let guess = String::new();
io::stdin().read_line(&mut guess).expect("...");
// error[E0596]: cannot borrow `guess` as mutable, as it is not declared as mutable

// ✅ CORRECT
let mut guess = String::new();
io::stdin().read_line(&mut guess).expect("...");
```

> In Java, local variables are mutable by default (you have to opt out with `final`). In Rust, variables are **immutable by default**. You opt in to mutability with `mut`.

---

### Mistake 2 — Confusing `String` and `&str`

Java has one string type: `String`. Rust has two main kinds:

| | Java | Rust |
|--|------|------|
| Heap-allocated, owned | `String` | `String` |
| Borrowed slice | *(no equivalent)* | `&str` |

```rust,no_run
// ❌ WRONG — trying to match a String against &str without converting
let input = String::from("hello");
if input == "hello" {  // This actually works! Rust auto-deref compares String == &str
    println!("equal");
}

// But match arms need &str, not String:
// ❌ WRONG — match against a String directly
match input {
    "hello" => println!("hi"),  // error: expected String, found &str
    _       => {}
}

// ✅ CORRECT — borrow as &str with .as_str()
match input.as_str() {
    "hello" => println!("hi"),
    _       => {}
}

// ✅ ALSO CORRECT — match on a reference
match input.as_str() {
    "hello" | "hi" => println!("greeting"),
    _               => println!("other"),
}
```

```rust,no_run
// ❌ WRONG — returning a &str that references a local String (dangling reference)
fn get_name() -> &str {        // error: missing lifetime specifier
    let name = String::from("Alice");
    &name                      // name is dropped here — would be a dangling reference
}

// ✅ CORRECT — return the owned String
fn get_name() -> String {
    String::from("Alice")
}

// ✅ ALSO CORRECT — return a &'static str literal (lives forever)
fn get_name() -> &'static str {
    "Alice"
}
```

---

### Mistake 3 — Using `.expect()` Everywhere in Production Code

`.expect()` panics on error — it is fine for prototypes and tutorials but inappropriate in production:

```rust,no_run
// ❌ WRONG in production — panics on bad input
let n: u32 = input.trim().parse().expect("bad input");

// ✅ BETTER — handle the error gracefully
let n: u32 = match input.trim().parse() {
    Ok(num) => num,
    Err(e)  => {
        eprintln!("Invalid input: {e}");
        return;
    }
};

// ✅ IDIOMATIC for propagating errors up the call stack (Chapter 9)
// fn parse_guess(input: &str) -> Result<u32, std::num::ParseIntError> {
//     input.trim().parse()
// }
```

---

### Mistake 4 — Forgetting to `.trim()` Before `.parse()`

```rust,no_run
// ❌ WRONG — read_line includes a trailing newline
let mut input = String::new();
io::stdin().read_line(&mut input).expect("...");
let n: u32 = input.parse().expect("...");
// Panics! "42\n" cannot be parsed as u32

// ✅ CORRECT
let n: u32 = input.trim().parse().expect("...");
```

---

### Mistake 5 — Trying to Print a Type Without `Display`

```rust,no_run
// ❌ WRONG — Vec does not implement Display
let v = vec![1, 2, 3];
println!("{}", v);
// error[E0277]: `Vec<{integer}>` doesn't implement `std::fmt::Display`

// ✅ CORRECT — use debug format
println!("{:?}", v);   // [1, 2, 3]

// ✅ CORRECT — format it yourself
let s: Vec<String> = v.iter().map(|n| n.to_string()).collect();
println!("{}", s.join(", "));   // 1, 2, 3
```

---

### Mistake 6 — Thinking `loop` Needs a Condition

```rust,no_run
// ❌ JAVA INSTINCT — a Java developer writes:
// while (true) { ... }   // works in Rust too, but...

// ✅ IDIOMATIC RUST — use `loop` for an unconditional infinite loop
loop {
    // ...
    break; // exit explicitly
}

// ✅ USE `while` when the condition is checked at the top
let mut count = 0;
while count < 10 {
    count += 1;
}
```

---

### Mistake 7 — Shadowing vs. Mutability

```rust,no_run
// These are NOT the same thing:

// Shadowing — creates a new binding with a new type
let x = "5";
let x: u32 = x.trim().parse().expect("not a number");
// The first x (String) is shadowed; only the second x (u32) is accessible now

// Mutation — changes the value of the SAME binding
let mut y: u32 = 5;
y = 10;   // same binding, new value, same type
// y = "hello"; // error! can't change the type
```

---

## 2.9 Concept Reference

### `use` — Importing Names

```rust,no_run
use std::io;                  // import the io module
use std::cmp::Ordering;       // import the Ordering enum
use std::collections::HashMap; // import HashMap

// Import multiple items from the same module
use std::io::{self, Write};   // imports io AND io::Write

// Rename on import (like Java's import aliasing with a local variable)
use std::collections::HashMap as Map;

// Glob import (use sparingly — makes it hard to see where names come from)
use std::cmp::*;
```

### `let` vs `let mut`

```rust,no_run
let x = 5;        // immutable — x cannot be reassigned
// x = 6;         // error[E0384]: cannot assign twice to immutable variable

let mut y = 5;    // mutable — y can be reassigned
y = 6;            // ok

// Shadowing (not mutation — creates a new binding)
let x = 5;
let x = x + 1;    // new binding, shadows old x
let x = x * 2;    // new binding again
println!("{x}");  // 12
```

### `match` — Exhaustive Pattern Matching

```rust,no_run
use std::cmp::Ordering;

let result = 3u32.cmp(&5u32);  // Ordering::Less

// Every arm must be covered or the compiler errors
match result {
    Ordering::Less    => println!("less"),
    Ordering::Greater => println!("greater"),
    Ordering::Equal   => println!("equal"),
}

// Arms can execute blocks
match result {
    Ordering::Less => {
        println!("less");
        println!("try a higher number");
    }
    Ordering::Greater => println!("greater"),
    Ordering::Equal   => println!("equal"),
}

// match is an expression — it returns a value
let description = match result {
    Ordering::Less    => "lower",
    Ordering::Greater => "higher",
    Ordering::Equal   => "exact",
};
println!("{description}");

// Catch-all pattern
let n: u32 = 7;
match n {
    1     => println!("one"),
    2..=5 => println!("two to five"),
    _     => println!("something else"),  // _ matches anything
}
```

### `Result<T, E>` — Error Handling Without Exceptions

```rust,no_run
// Result is defined as:
// enum Result<T, E> { Ok(T), Err(E) }

// .expect() — unwrap or panic
let n: u32 = "42".parse().expect("not a number"); // returns 42

// .unwrap() — same as expect but no message (avoid in production)
let n: u32 = "42".parse().unwrap();

// match — handle both cases
let n: u32 = match "42".parse() {
    Ok(num) => num,
    Err(e)  => { eprintln!("Error: {e}"); 0 }
};

// .unwrap_or() — default value on error
let n: u32 = "abc".parse().unwrap_or(0);  // n = 0

// .unwrap_or_else() — compute default value lazily
let n: u32 = "abc".parse().unwrap_or_else(|_| {
    println!("Bad input, defaulting to 0");
    0
});
```

### `loop` and `break`

```rust,no_run
// Infinite loop
loop {
    // ...
    break;      // exit loop
}

// loop can return a value via break
let result = loop {
    let x = compute_something();
    if x > 100 {
        break x;     // break with a value — result = x
    }
};

// continue — skip to next iteration
loop {
    let input = get_input();
    if input.is_empty() {
        continue;    // go back to top of loop
    }
    // process input
    break;
}

// Labeled loops — for breaking out of nested loops
'outer: loop {
    loop {
        break 'outer;  // breaks the outer loop
    }
}
```

### `String` vs `&str` — Quick Reference

```rust,no_run
// String — heap-allocated, owned, growable
let mut s: String = String::new();          // empty
let s: String = String::from("hello");      // from a literal
let s: String = "hello".to_string();        // same
let s: String = format!("hello {}", "world"); // formatted

// &str — borrowed reference to a string slice
let s: &str = "hello";                      // string literal (static)
let s: &str = &owned_string;               // borrow from a String
let s: &str = &owned_string[0..5];         // substring slice

// Converting between them
let owned: String = "hello".to_string();
let borrowed: &str = &owned;               // String -> &str (deref coercion)
let owned2: String = borrowed.to_owned();  // &str -> String

// When to use which:
// - Function parameters: prefer &str (accepts both String and &str)
// - Return values: String if you're creating it, &str if you're borrowing
// - Struct fields: usually String (struct needs to own its data)
fn greet(name: &str) -> String {           // &str in, String out — idiomatic
    format!("Hello, {name}!")
}
```

---

## 2.10 Review and Self-Check

| Concept | Quick Test |
|---------|-----------|
| `let mut` | Why does `read_line` require `&mut guess` instead of just `guess`? |
| `String::new()` | What is the difference between `String::new()` and `String::from("hello")`? |
| `.trim()` | Why must you call `.trim()` before `.parse()` on user input? |
| `Result` | What is the difference between `.expect()`, `.unwrap()`, and `match`-ing on a `Result`? |
| Shadowing | Can the second `let guess` have a different type than the first? What about in Java? |
| `match` exhaustiveness | What happens if you add a fourth `Ordering` variant and forget to add an arm? |
| `loop` vs `while` | When does the compiler prefer `loop` (hint: it affects definite assignment)? |
| `String` vs `&str` | Why can't you `match my_string { "a" => ... }`? How do you fix it? |
| `rand::random_range` | What changed between rand 0.8 and rand 0.9+ in how you call this function? |

---

## Common Pitfalls at a Glance

```rust,no_run
fn main() {
    // ❌ WRONG: immutable String passed to read_line
    let guess = String::new();
    // io::stdin().read_line(&mut guess)...  // compile error

    // ✅ CORRECT
    let mut guess = String::new();
    io::stdin().read_line(&mut guess).expect("...");

    // ❌ WRONG: forget to trim before parsing (newline causes parse to fail)
    let _n: u32 = guess.parse().expect("bad");   // panics on "42\n"

    // ✅ CORRECT
    let _n: u32 = guess.trim().parse().expect("bad");

    // ❌ WRONG: matching a String directly against string literals
    // match guess { "quit" => ..., _ => ... }   // error: type mismatch

    // ✅ CORRECT
    match guess.trim() {
        "quit" => println!("Goodbye!"),
        other  => println!("You entered: {other}"),
    }

    // ❌ WRONG: using {} to print a Vec (no Display impl)
    let v = vec![1, 2, 3];
    // println!("{}", v);   // compile error

    // ✅ CORRECT: use debug format
    println!("{:?}", v);

    // ❌ WRONG: rand 0.8 API used with rand 0.9+
    // use rand::Rng;
    // let secret = rand::thread_rng().gen_range(1..=100);  // thread_rng gone in 0.9

    // ✅ CORRECT for rand 0.9 / 0.10
    let _secret: u32 = rand::random_range(1..=100);
}
```

---

## 📝 Chapter Review Notes

*Third-person critical review performed after drafting. Key patterns were compiled and verified against rand 0.9.2 with `cargo check --offline` on Rust 1.94.0 (edition 2024). Rand 0.10.1 was confirmed as the latest stable version; rand 0.9.2 was used for verification because it shares the same public API (`random_range`, `rng()`).*

### Issues Found and Fixed

| # | Issue | Severity | Fix Applied |
|---|-------|----------|-------------|
| 1 | Initial draft used `rand::thread_rng().gen_range(1..=100)` — the 0.8 API, removed in 0.9 | High | Replaced with `rand::random_range(1..=100)`, the idiomatic rand 0.9+/0.10 top-level function; verified via changelog and rand source |
| 2 | Initial draft used `use rand::Rng;` trait import — no longer needed for `random_range` as a top-level function | High | Removed the trait import; replaced with plain `use rand;`. Verified with `cargo check`: no warnings fired for `use rand;` when `rand::random_range` is called by full path in edition 2024 |
| 3 | `Rng` trait renamed to `RngExt` in rand 0.10 (as `rand_core::RngCore` was renamed to `Rng`); needed for method-call syntax on the RNG handle | Medium | Added versioning callout in section 2.3 explaining old vs new API; chapter uses the top-level `rand::random_range()` function which requires no trait import |
| 4 | `Difficulty` struct with `const` instances — `&'static Difficulty` requires rvalue static promotion of `&CONST` | Medium | Verified with `cargo check`: compiles cleanly. `const` items have `'static` lifetime; taking `&EASY` returns a `&'static Difficulty`. Promotion works here because `Difficulty` has no `Drop` impl or interior mutability |
| 5 | `match read_line().to_lowercase().as_str()` — temporary `String` from `to_lowercase()` could drop before `as_str()` is used | High | Verified with `cargo check`: compiles cleanly. Temporaries in a `match` scrutinee live until the end of the `match` statement. No fix needed |
| 6 | Helper function name inconsistency: section 2.7.3 used `read_line()`, section 2.7.4 used `read_trimmed_line()`, section 2.7.5 used `read_line()` again — three names for the same helper | Medium | Standardized to `read_line()` throughout all examples |
| 7 | `sorted.sort()` on a `Vec<u32>` in the history example: `.clone()` needed to avoid sorting the original | OK | Already clones before sorting — no change |
| 8 | `parse_u32_in_range` helper uses turbofish `input.parse::<u32>()` — verified syntactically correct | OK | No change; `cargo check` confirms |
| 9 | `u32::MAX` used for `best_score` initial value — correct for unsigned "not yet set" sentinel | OK | No change; `u32::MAX` is `4_294_967_295` |
| 10 | Edition `"2024"` in all `Cargo.toml` examples — correct for Rust 1.85+ | OK | Already correct |

### What This Chapter Does Well

- Progressive build: the program grows in seven clear stages (v1 through v4 + three extras + full version), each introducing one concept at a time
- Java-vs-Rust comparison tables for every major concept
- Covers the rand 0.8 → 0.10 API change explicitly to prevent confusion from outdated tutorials
- Shows `match` as both a statement and an expression
- Explains why temporaries in `match` scrutinees are safe
- Distinguishes shadowing from mutation clearly — a frequent Java-developer confusion point
- Addresses `String` vs `&str` in a dedicated pitfall section with concrete examples
- Covers `Option<T>` and `if let` naturally via the difficulty-levels example

### What Could Be Improved (Future Editions)

- Could show `?` operator for error propagation once readers are comfortable with `Result`
- Could add a brief note on `eprintln!` for debug output during development (print the secret number temporarily)
- The full-featured example could use a `struct GameStats` to demonstrate structs earlier
- Could add a unit-test block showing how to test `parse_u32_in_range` with `#[test]`

---

*Next: [Chapter 3 — Common Programming Concepts](ch03-common-concepts.md)*
