# Chapter 19: Patterns and Matching

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

## Java vs. Rust: The Pattern Matching Mindset

Java developers know `switch` statements — and in modern Java (17+), `switch` expressions with sealed interfaces and record patterns. Rust's pattern matching is more pervasive and more powerful: **patterns appear in `match`, `if let`, `while let`, `for` loops, `let` statements, and function parameters**. Every binding in Rust is a pattern.

| Java concept | Rust equivalent |
|---|---|
| `switch` / `switch` expression | `match` expression |
| `instanceof` + cast | Pattern matching in `if let` / `match` |
| Sealed interfaces + records | Enums with data variants |
| No direct equivalent | Destructuring `let`, `for`, function params |
| `Optional.isPresent()` / `.get()` | `if let Some(x) = opt { ... }` |

The key mindset shift: in Rust, **you never separately check a variant and then extract data**. You do both in a single pattern.

---

## 19.1 Where Patterns Are Used

### 19.1.1 `match` Arms

`match` is the most explicit place patterns appear. Every arm is a pattern, and `match` must be **exhaustive** — the compiler rejects non-exhaustive matches. The `_` wildcard acts like Java's `default`:

```rust
fn describe_byte(b: u8) -> &'static str {
    match b {
        0         => "null",
        32        => "space",
        33..=126  => "printable ASCII",
        127       => "DEL",
        _         => "control/non-ASCII",
    }
}

fn main() {
    println!("{}", describe_byte(65));   // printable ASCII
    println!("{}", describe_byte(200));  // control/non-ASCII
}
```

### 19.1.2 `if let` — Matching a Single Pattern

Use `if let` when you only care about one variant and want to avoid the boilerplate of a full `match`:

```rust
fn main() {
    let config_value: Option<u16> = Some(8080);

    // Java: if (opt.isPresent()) { int port = opt.get(); ... }
    if let Some(port) = config_value {
        println!("Listening on port {}", port);
    } else {
        println!("Using default port");
    }
}
```

`if let` compiles to the same code as a two-arm `match`. It accepts **refutable** patterns — patterns that might not match — which plain `let` does not (see section 19.2).

### 19.1.3 `if let` Chains (Rust 2024 Edition / Rust 1.88+)

`if let` chains combine `if let` and boolean `if` conditions with `&&`. Stabilized in **Rust 1.88, requires the 2024 edition**. Similar to Java 21's `instanceof` pattern + condition, but cleaner:

```rust
// edition = "2024" in Cargo.toml required
#[derive(Debug)]
enum AuthStatus { Authenticated { user_id: u64, role: &'static str }, Guest }

fn handle(status: AuthStatus, path: &str) {
    if let AuthStatus::Authenticated { user_id, role } = status
        && role == "admin"
        && path.starts_with("/admin")
    {
        println!("Admin {} accessing {}", user_id, path);
    } else {
        println!("Access denied");
    }
}

fn main() {
    handle(AuthStatus::Authenticated { user_id: 42, role: "admin" }, "/admin/users");
    handle(AuthStatus::Authenticated { user_id: 7,  role: "user"  }, "/admin/users");
    handle(AuthStatus::Guest, "/admin/users");
}
```

### 19.1.4 `while let` — Loop Until a Pattern Fails

`while let` keeps looping as long as the pattern matches. Classic uses: draining a stack, reading from a channel:

```rust
fn main() {
    let mut stack = vec![1, 2, 3];
    while let Some(top) = stack.pop() {
        println!("Popped: {}", top);
    }

    let (tx, rx) = std::sync::mpsc::channel::<&str>();
    tx.send("hello").unwrap();
    drop(tx);
    while let Ok(msg) = rx.recv() { println!("Got: {}", msg); }
}
```

### 19.1.5 `for` Loops and `let` — Patterns Everywhere

The variable after `for` is a pattern; so is the left side of every `let`:

```rust
fn main() {
    // for: destructure (index, value) from enumerate
    let fruits = ["apple", "banana", "cherry"];
    for (i, fruit) in fruits.iter().enumerate() {
        println!("{i}: {fruit}");
    }

    // for: destructure tuples from zip
    let prices = [1.20_f64, 0.50, 2.00];
    for (fruit, &price) in fruits.iter().zip(prices.iter()) {
        println!("{fruit} ${price:.2}");
    }

    // let: tuple and nested tuple destructuring
    let (x, y, z) = (1, 2, 3);
    let ((ax, ay), (bx, by)) = ((0, 1), (10, 20));
    println!("x={x} A=({ax},{ay}) B=({bx},{by}) z={z}");

    // let: tuple struct
    struct Rgb(u8, u8, u8);
    let Rgb(r, g, b) = Rgb(255, 128, 0);
    println!("r={r} g={g} b={b}");
}
```

> **Java comparison:** Java 21 record patterns in `instanceof` let you write `if (obj instanceof Point(int x, int y))`. Rust's `let` destructuring is similar but applies unconditionally — the pattern must be irrefutable.

### 19.1.6 `let...else` — Irrefutable or Bail Out

`let...else` (stabilized in Rust 1.65) bridges the gap between `let` (irrefutable only) and `if let` (no binding escapes the block). It binds variables in the outer scope while the `else` branch **must diverge** (return, panic, break, continue):

```rust
fn parse_port(s: &str) -> u16 {
    let Ok(n) = s.parse::<u16>() else {
        eprintln!("'{}' is not a valid port number", s);
        return 0;
    };
    n // `n` is available here, in the outer scope
}

fn main() {
    println!("{}", parse_port("8080")); // 8080
    println!("{}", parse_port("abc"));  // prints error, returns 0
}
```

This is the idiomatic Rust replacement for Java's "validate-then-use" pattern with early returns.

### 19.1.7 Function Parameters — Patterns as Arguments

Function parameters are patterns. You can destructure references to tuples directly:

```rust
// Destructure a reference to a tuple in the parameter list
fn distance(&(x1, y1): &(f64, f64), &(x2, y2): &(f64, f64)) -> f64 {
    ((x2 - x1).powi(2) + (y2 - y1).powi(2)).sqrt()
}

fn main() {
    let a = (0.0_f64, 0.0_f64);
    let b = (3.0_f64, 4.0_f64);
    println!("Distance: {}", distance(&a, &b)); // 5.0
}
```

Closures use the same mechanism: `points.iter().map(|&(x, y)| x + y)` destructures each `&(i32, i32)` tuple pair directly in the closure parameter.

---

## 19.2 Refutability: Will This Pattern Always Match?

Rust divides all patterns into two categories:

| Category | Definition | Example |
|---|---|---|
| **Irrefutable** | Always matches any possible value | `x`, `(a, b)`, `_` |
| **Refutable** | Might *not* match some values | `Some(x)`, `Ok(v)`, `1` |

**The rule:**
- `let`, `for`, function parameters: **irrefutable only**
- `match` arms, `if let`, `while let`, `let...else`: **refutable OK**

### Compile Error: Refutable Pattern in `let` / Wrong Construct

The compiler rejects a refutable pattern where only irrefutable patterns are allowed, and warns when an irrefutable pattern appears in `if let` (because the `if` can never be false):

```rust
fn main() {
    let some_value: Option<i32> = Some(42);

    // ERROR: `let Some(x) = some_value;`
    // — Some(x) is refutable; use if let or let...else instead

    // Fix 1: if let (refutable pattern, binding stays in block)
    if let Some(x) = some_value {
        println!("Got: {}", x);
    }

    // Fix 2: let...else (Rust 1.65+) — binding escapes to outer scope
    let Some(x) = some_value else {
        return; // else block MUST diverge
    };
    println!("Got: {}", x); // x available here

    // WARNING: `if let x = 5` — x is irrefutable, use plain `let`
    let x = 5; // correct form
    println!("{}", x);
}
```

> **Key insight:** The compiler tells you which side of the line you've crossed. "Refutable pattern in irrefutable context" means use `if let` or `let...else`. "Irrefutable pattern in `if let`" means use plain `let`.

---

## 19.3 Pattern Syntax Reference

### 19.3.1 Matching Literals

Match specific values directly — integers, characters, booleans, strings:

```rust
fn classify_char(c: char) -> &'static str {
    match c {
        'a'..='z' => "lowercase",
        'A'..='Z' => "uppercase",
        '0'..='9' => "digit",
        ' ' | '\t' | '\n' => "whitespace",
        _ => "other",
    }
}

fn main() {
    println!("{}", classify_char('g'));  // lowercase
    println!("{}", classify_char('3'));  // digit
    println!("{}", classify_char(' ')); // whitespace
    println!("{}", classify_char('!'));  // other
}
```

### 19.3.2 Named Variables and Shadowing in `match`

A pattern variable in a `match` arm creates a **new binding that shadows** any outer variable of the same name — it does not compare to it. To compare against an outer variable's value, use a guard:

```rust
fn main() {
    let x = Some(5);
    let y = 10;

    match x {
        Some(50) => println!("Got 50"),
        Some(y)  => println!("Got Some({y})"), // y = 5, NOT the outer y = 10
        _        => println!("None, outer y is still {}", y),
    }
    println!("Outer y is still: {}", y); // 10

    // To compare against outer y, use a guard:
    match x {
        Some(n) if n == y => println!("inner value equals outer y"),
        Some(n)           => println!("inner {n} != outer y ({y})"),
        None              => println!("None"),
    }
}
```

### 19.3.3 Multiple Patterns with `|`

The `|` operator means "or" — match any of these patterns:

```rust
fn is_weekend(day: u8) -> bool {
    match day {
        6 | 7 => true,  // Saturday or Sunday
        1..=5 => false, // Monday through Friday
        _ => panic!("Invalid day: {}", day),
    }
}

fn main() {
    println!("Day 6 is weekend: {}", is_weekend(6)); // true
    println!("Day 3 is weekend: {}", is_weekend(3)); // false
}
```

### 19.3.4 Range Patterns with `..=`

Range patterns match an inclusive range of values. **Only `..=` (inclusive) is allowed in patterns** — the exclusive `..` range syntax is not valid here:

```rust
fn letter_grade(score: u8) -> &'static str {
    match score {
        90..=100 => "A",
        80..=89  => "B",
        70..=79  => "C",
        60..=69  => "D",
        0..=59   => "F",
        _        => "Invalid",
    }
}

fn main() {
    println!("{}", letter_grade(95));  // A
    println!("{}", letter_grade(82));  // B
    println!("{}", letter_grade(55));  // F
}
```

### 19.3.5 Destructuring Structs, Enums, and Tuples

**Structs** — shorthand `Point { x, y }` binds fields by name; `Point { x: px, y: py }` renames them. Literal values in struct patterns restrict which values match:

```rust
#[derive(Debug)]
struct Point { x: f64, y: f64 }

fn main() {
    let p = Point { x: 3.0, y: 0.0 };
    let Point { x, y } = p;                  // shorthand
    println!("x={x}, y={y}");

    match (Point { x: 0.0, y: 5.0 }) {
        Point { x: 0.0, y } => println!("On y-axis at {y}"),
        Point { x, y: 0.0 } => println!("On x-axis at {x}"),
        Point { x, y }      => println!("At ({x},{y})"),
    }
}
```

**Enums** — pattern shape mirrors variant definition (unit / tuple / struct):

```rust
#[derive(Debug)]
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(u8, u8, u8),
}

fn process(msg: Message) {
    match msg {
        Message::Quit             => println!("Quit"),
        Message::Move { x, y }   => println!("Move ({x},{y})"),
        Message::Write(text)      => println!("Write: {text}"),
        Message::ChangeColor(r,g,b) => println!("Color rgb({r},{g},{b})"),
    }
}

fn main() {
    process(Message::ChangeColor(255, 128, 0));
    process(Message::Write("hello".to_string()));
}
```

**Nested enums** — patterns nest as deeply as the type structure:

```rust
#[derive(Debug)]
enum Fill { Solid(u8, u8, u8), Gradient(u8, u8, u8) }
#[derive(Debug)]
enum Shape { Circle { fill: Fill, radius: f64 }, Square { fill: Fill } }

fn describe(s: &Shape) {
    match s {
        Shape::Circle { fill: Fill::Solid(r, g, b), radius }
            => println!("Solid circle r={radius} color=({r},{g},{b})"),
        Shape::Circle { fill, radius }
            => println!("Gradient circle r={radius} fill={fill:?}"),
        Shape::Square { fill: Fill::Solid(r, g, b) }
            => println!("Solid square ({r},{g},{b})"),
        Shape::Square { .. } => println!("Gradient square"),
    }
}

fn main() {
    describe(&Shape::Circle { fill: Fill::Solid(255,0,0), radius: 5.0 });
}
```

**Tuples and tuple structs** — positional patterns with `_` or `..` to skip:

```rust
struct Rgb(u8, u8, u8);

fn main() {
    let Rgb(r, g, b) = Rgb(255, 128, 0);
    println!("r={r} g={g} b={b}");

    let ((ax, ay), (bx, by)) = ((0, 1), (10, 20)); // nested tuple
    println!("A=({ax},{ay}) B=({bx},{by})");
}
```

### 19.3.6 Ignoring Values with `_` and `..`

`_` ignores a single value without binding. `..` ignores all remaining fields or elements. **Key difference:** `_name` takes ownership (moves the value); bare `_` never binds and never moves:

```rust
#[derive(Debug)]
struct Config { host: String, port: u16, timeout: u32, retries: u8 }

fn main() {
    let cfg = Config { host: "localhost".to_string(), port: 8080, timeout: 30, retries: 3 };

    // .. ignores all unneeded fields
    let Config { host, port, .. } = cfg;
    println!("{}:{}", host, port);

    // _ ignores a single positional element
    let (first, _, last) = (1, 2, 3);
    println!("first={first}, last={last}");

    // _name suppresses unused warning but DOES take ownership
    let s = String::from("hello");
    let _s = s;            // s is moved into _s
    // println!("{}", s);  // compile error

    // bare _ does NOT move
    let t = String::from("world");
    let _ = &t;            // borrow only
    println!("{}", t);     // t still valid
}
```

### 19.3.7 Match Guards

A match guard is an extra `if` condition after the pattern. It can reference variables bound by the pattern:

```rust
fn main() {
    let numbers = vec![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    for &n in &numbers {
        let label = match n {
            x if x % 2 == 0 && x > 5 => "large even",
            x if x % 2 == 0          => "small even",
            x if x > 5               => "large odd",
            _                        => "small odd",
        };
        println!("{n}: {label}");
    }
}
```

Guards and `|` patterns: the guard applies to **all** alternatives in a `|` arm:

```rust
fn main() {
    let x = 4;
    let y = false;

    // The guard `if y` applies to BOTH `4` and `5`, not just `5`
    match x {
        4 | 5 | 6 if y => println!("yes"),
        _              => println!("no"),
    }
    // Prints "no" because y is false
}
```

### 19.3.8 `@` Bindings — Bind and Test Simultaneously

The `@` operator **binds a value to a variable while simultaneously testing it** against a pattern. Without `@`, you can test a range but cannot use the value in the arm body:

```rust
fn categorize(n: u32) {
    match n {
        small @ 1..=9   => println!("{} is a single digit", small),
        mid   @ 10..=99 => println!("{} is two digits", mid),
        big   @ _       => println!("{} is large", big),
    }
}

// Note: float range patterns are NOT stable. Use a match guard for floats:
#[derive(Debug)]
enum Alert { Temperature(f64), Pressure(f64) }

fn handle_alert(alert: Alert) {
    match alert {
        Alert::Temperature(t) if (37.0_f64..=38.5).contains(&t)
            => println!("Normal body temp: {}°C", t),
        Alert::Temperature(t) => println!("Abnormal temp: {}°C", t),
        Alert::Pressure(p) if p >= 0.0 && p <= 1.0
            => println!("Safe pressure: {}", p),
        Alert::Pressure(p) => println!("Dangerous pressure: {}", p),
    }
}

fn main() {
    categorize(7);
    categorize(1000);
    handle_alert(Alert::Temperature(37.5));
    handle_alert(Alert::Pressure(5.0));
}
```

---

## 19.4 Practical Recipes

### Recipe 1: Parsing a Command into Structured Types

Nested pattern matching handles command dispatch. Match on the outer variant, then destructure inner data in the same arm:

```rust
#[derive(Debug)]
enum Target { File(String), Directory { path: String, recursive: bool }, Stdin }

#[derive(Debug)]
enum Command {
    Copy { from: Target, to: Target },
    Delete(Target),
    List { target: Target, show_hidden: bool },
    Help,
}

fn execute(cmd: Command) {
    match cmd {
        Command::Help => println!("Available: copy, delete, list, help"),

        // Nested enum pattern: match outer + inner in one arm
        Command::Delete(Target::Stdin)             => println!("ERROR: cannot delete stdin"),
        Command::Delete(Target::File(path))         => println!("Deleting file: {}", path),
        Command::Delete(Target::Directory { path, recursive: true })
                                                   => println!("Deleting {} recursively", path),
        Command::Delete(Target::Directory { path, .. })
                                                   => println!("Deleting dir: {}", path),

        // Struct variant + nested enum in the same arm
        Command::Copy { from: Target::File(src), to: Target::File(dst) }
                                                   => println!("Copying {} -> {}", src, dst),
        Command::Copy { from, to }                 => println!("Copying {:?} -> {:?}", from, to),

        // .. ignores unused fields
        Command::List { target: Target::Directory { path, recursive }, show_hidden }
                                                   => println!("List {} rec={} hidden={}", path, recursive, show_hidden),
        Command::List { target, show_hidden }       => println!("List {:?} hidden={}", target, show_hidden),
    }
}

fn main() {
    execute(Command::Delete(Target::File("/tmp/old.log".to_string())));
    execute(Command::Copy {
        from: Target::File("src.txt".to_string()),
        to: Target::File("dst.txt".to_string()),
    });
    execute(Command::List {
        target: Target::Directory { path: "/home".to_string(), recursive: true },
        show_hidden: false,
    });
}
```

### Recipe 2: Extracting Data from Nested JSON-like Enums

Pattern matching shines when navigating nested data structures. Each field extraction uses a separate nested `match` or `if let`, combining variant testing with value binding in one step:

```rust
#[derive(Debug, Clone)]
enum Json {
    Null,
    Bool(bool),
    Number(f64),
    Text(String),
    Array(Vec<Json>),
    Object(Vec<(String, Json)>),
}

fn find<'a>(obj: &'a Json, key: &str) -> Option<&'a Json> {
    if let Json::Object(fields) = obj {
        fields.iter().find(|(k, _)| k == key).map(|(_, v)| v)
    } else {
        None
    }
}

fn extract_user(data: &Json) {
    let name = match find(data, "name") {
        Some(Json::Text(s)) => s.as_str(),
        _ => "<unknown>",
    };
    let age = match find(data, "age") {
        Some(Json::Number(n)) if *n >= 0.0 => *n as u32,
        _ => 0,
    };
    println!("User: {} | Age: {}", name, age);

    // Nested array: if let + filter_map with pattern closure
    if let Some(Json::Array(tags)) = find(data, "tags") {
        let list: Vec<&str> = tags.iter()
            .filter_map(|t| if let Json::Text(s) = t { Some(s.as_str()) } else { None })
            .collect();
        println!("Tags: {}", list.join(", "));
    }
}

fn main() {
    let data = Json::Object(vec![
        ("name".to_string(), Json::Text("Alice".to_string())),
        ("age".to_string(),  Json::Number(30.0)),
        ("tags".to_string(), Json::Array(vec![
            Json::Text("rust".to_string()),
            Json::Text("systems".to_string()),
        ])),
    ]);
    extract_user(&data);
}
```

### Recipe 3: Validation with Match Guards

Guards embed business rules directly into pattern arms. Each rule uses literals, ranges, and `if` guards — no `if/else` chains needed:

```rust
#[derive(Debug)]
struct SignupForm { username: String, password: String, age: u8 }

fn validate(form: &SignupForm) -> Result<String, Vec<String>> {
    let mut errors = Vec::new();

    // Literal 0, range 1..=2, guard for upper bound
    match form.username.len() {
        0     => errors.push("Username required".to_string()),
        1..=2 => errors.push("Username too short (min 3)".to_string()),
        n if n > 50 => errors.push("Username too long (max 50)".to_string()),
        _ => {}
    }

    // Chained guards on the wildcard arm — each checks one rule
    match form.password.len() {
        0     => errors.push("Password required".to_string()),
        1..=7 => errors.push("Password too short (min 8)".to_string()),
        _ if !form.password.chars().any(|c| c.is_uppercase()) =>
            errors.push("Password needs an uppercase letter".to_string()),
        _ if !form.password.chars().any(|c| c.is_ascii_digit()) =>
            errors.push("Password needs a digit".to_string()),
        _ => {}
    }

    // Range patterns for age
    match form.age {
        0..=12  => errors.push("Must be at least 13".to_string()),
        13..=17 => errors.push("Parental consent required".to_string()),
        _       => {}
    }

    if errors.is_empty() { Ok(format!("Welcome, {}!", form.username)) }
    else { Err(errors) }
}

fn main() {
    let ok = SignupForm { username: "alice_dev".into(), password: "Secure1!".into(), age: 25 };
    println!("{:?}", validate(&ok));

    let bad = SignupForm { username: "x".into(), password: "weak".into(), age: 10 };
    println!("{:?}", validate(&bad));
}
```

### Recipe 4: Destructuring RGB Colors from Tuples

Tuple patterns make color processing concise — destructure a `(u8, u8, u8)` right in the `match` arms:

```rust
fn describe_color(color: (u8, u8, u8)) -> &'static str {
    match color {
        (255, 0, 0)     => "pure red",
        (0, 255, 0)     => "pure green",
        (0, 0, 255)     => "pure blue",
        (0, 0, 0)       => "black",
        (255, 255, 255) => "white",
        (r, g, b) if r == g && g == b => "grey",
        (r, _, _) if r > 200          => "reddish",
        (_, g, _) if g > 200          => "greenish",
        (_, _, b) if b > 200          => "bluish",
        _                             => "mixed",
    }
}

fn main() {
    let palette = [(255_u8, 0_u8, 0_u8), (0, 128, 0), (100, 100, 100), (200, 50, 30)];

    for rgb in palette {
        let (r, g, b) = rgb;  // destructure the tuple in let
        println!("({r:3},{g:3},{b:3}) => {}", describe_color(rgb));
    }

    // Struct destructuring from a named type
    struct Rgb(u8, u8, u8);
    let orange = Rgb(255, 165, 0);
    let Rgb(r, g, b) = orange;  // tuple struct pattern
    println!("Orange: r={r}, g={g}, b={b}");
}
```

### Recipe 5: Pattern Matching on HTTP Responses

Struct patterns let you simultaneously match on a variant field and destructure another field. The `|` operator groups success codes; `@` binds the matched integer for use in the arm body; `..` skips unused fields:

```rust
#[derive(Debug)]
enum HttpStatus {
    Ok, Created, NoContent,
    BadRequest(String),
    Unauthorized, Forbidden, NotFound,
    TooManyRequests { retry_after: u32 },
    ServerError(u16),
}

#[derive(Debug)]
struct HttpResponse { status: HttpStatus, body: Option<String> }

fn handle(resp: HttpResponse) {
    match resp {
        // | groups variants; struct pattern matches body field too
        HttpResponse { status: HttpStatus::Ok | HttpStatus::Created, body: Some(b) }
            => println!("200/201 with body: {}", &b[..b.len().min(60)]),

        HttpResponse { status: HttpStatus::Ok | HttpStatus::Created | HttpStatus::NoContent, .. }
            => println!("2xx success (no body)"),

        HttpResponse { status: HttpStatus::BadRequest(reason), .. }
            => println!("400 Bad Request: {}", reason),

        HttpResponse { status: HttpStatus::NotFound, .. }
            => println!("404 Not Found"),

        // Struct variant destructuring + @ binding
        HttpResponse { status: HttpStatus::TooManyRequests { retry_after }, .. }
            => println!("429 Rate limited — retry after {}s", retry_after),

        // @ binds the integer code while testing the range
        HttpResponse { status: HttpStatus::ServerError(code @ 500..=511), .. }
            => println!("{}  Server Error", code),

        HttpResponse { status, body }
            => println!("Unhandled: {:?} body={:?}", status, body),
    }
}

fn main() {
    handle(HttpResponse { status: HttpStatus::Ok, body: Some(r#"{"id":1}"#.to_string()) });
    handle(HttpResponse { status: HttpStatus::TooManyRequests { retry_after: 60 }, body: None });
    handle(HttpResponse { status: HttpStatus::ServerError(503), body: None });
    handle(HttpResponse { status: HttpStatus::BadRequest("missing email".to_string()), body: None });
}
```

### Recipe 6: Calculator with Operator Enums

`match` replaces chains of `if/else` cleanly. The compiler enforces exhaustiveness — add a new `Op` variant and every `match` that omits it fails to compile:

```rust
#[derive(Debug, Clone, Copy)]
enum Op { Add, Sub, Mul, Div, Mod, Pow }

fn calculate(left: f64, op: Op, right: f64) -> Result<f64, &'static str> {
    match op {
        Op::Add => Ok(left + right),
        Op::Sub => Ok(left - right),
        Op::Mul => Ok(left * right),
        Op::Div if right == 0.0 => Err("division by zero"),
        Op::Div => Ok(left / right),
        Op::Mod if right == 0.0 => Err("division by zero"),
        Op::Mod => Ok(left % right),
        Op::Pow => {
            let r = left.powf(right);
            if r.is_infinite() { Err("overflow") } else { Ok(r) }
        }
    }
}

// parse_op: multiple patterns per arm via |
fn parse_op(s: &str) -> Option<Op> {
    match s {
        "+" | "add" => Some(Op::Add),
        "-" | "sub" => Some(Op::Sub),
        "*" | "mul" => Some(Op::Mul),
        "/" | "div" => Some(Op::Div),
        "%" | "mod" => Some(Op::Mod),
        "^" | "pow" => Some(Op::Pow),
        _           => None,
    }
}

fn main() {
    let ops = [(10.0, Op::Add, 5.0), (10.0, Op::Div, 0.0), (2.0, Op::Pow, 10.0)];
    for (l, op, r) in ops {
        match calculate(l, op, r) {
            Ok(v)  => println!("{:?}: {l} op {r} = {v}", op),
            Err(e) => println!("{:?}: ERROR — {e}", op),
        }
    }

    // parse_op returns Option — handle with if let
    if let Some(op) = parse_op("%") {
        println!("17 mod 5 = {:?}", calculate(17.0, op, 5.0));
    }
    if parse_op("??").is_none() {
        println!("'??' is not a known operator");
    }
}
```

---

## 19.5 Quick Reference: Pattern Cheat Sheet

| Pattern | Syntax | Notes |
|---|---|---|
| Wildcard | `_` | Matches anything, no binding |
| Variable | `x` | Matches anything, binds value |
| Literal | `42`, `'a'`, `true` | Exact value match |
| Range | `1..=10` | Inclusive range only in patterns |
| Or | `A \| B` | Either pattern |
| Tuple | `(a, b)` | Positional destructure |
| Struct | `Foo { x, y }` | Field destructure |
| Tuple struct | `Foo(a, b)` | Positional destructure |
| Enum unit | `Variant` | Matches exact variant |
| Enum tuple | `Variant(a, b)` | Matches + destructures |
| Enum struct | `Variant { f }` | Matches + destructures |
| Rest | `..` | Ignore remaining fields/elements |
| Guard | `x if cond` | Extra condition |
| Binding | `n @ 1..=5` | Bind value, test pattern |
| Reference | `&x`, `ref x` | Pattern ergonomics usually handles |

---

## 19.6 Common Mistakes and Java Comparisons

| Mistake | Java analogy | What happens in Rust |
|---|---|---|
| `Point { x: 5 }` in a `let` statement | No equivalent | `x: 5` in `let` patterns **renames**, not compares. To compare, use a match guard: `Point { x, .. } if x == 5` |
| Non-exhaustive `match` | `switch` without `default` gives a warning | Rust gives a **compile error**. Add `_` or cover all variants. |
| `let _s = val` vs `let _ = val` | No equivalent — GC avoids this | `_s` **takes ownership** (val is moved); bare `_` never binds, never moves. |
| `1..5` in a pattern | No range-pattern analogy | Only `1..=5` (inclusive) is valid in patterns. `1..5` is a compile error. |
| Shadowing in `match Some(y)` | No variable shadowing in switch | A pattern variable `y` in a `match` arm **shadows** an outer `y` — it does not compare to it. Use a guard to compare: `Some(n) if n == y`. |

```rust
fn main() {
    // Mistake 3 demo: _ vs _name ownership
    let s = String::from("hello");
    let _s = s;             // s is MOVED — s is gone
    // println!("{}", s);   // compile error

    let t = String::from("world");
    let _ = &t;             // _ borrows, does NOT move
    println!("{}", t);      // t still valid

    // Mistake 4 demo: ..= required in patterns
    let x: u8 = 5;
    match x {
        1..=5 => println!("one to five"),   // correct
        6..=10 => println!("six to ten"),
        _ => println!("other"),
    }
    // match x { 1..5 => ... }  // compile error: use ..= not ..
}
```

---

## 📝 Chapter Review Notes

Third-person critical review covering factual accuracy, code correctness, and pedagogical completeness.

### Issues Table

| # | Severity | Item | Finding |
|---|---|---|---|
| 1 | **High** | Task prompt: `if let` chains version wrong | Prompt states "1.64+". Incorrect. Rust 1.65 stabilized `let...else`; `if let` chains stabilized in **Rust 1.88 (June 26, 2025)**, require **Rust 2024 edition**. Chapter corrects this. |
| 2 | **High** | Exclusive range `1..5` not valid in patterns | Only `1..=5` (inclusive) is valid in patterns. `1..5` is a compile error. Chapter calls this out in §19.3.4 and §19.6. |
| 3 | **Medium** | `_` vs `_name` ownership footgun | `_name` takes ownership; bare `_` does not. Java GC makes this invisible to Java developers. Addressed in §19.3.9. |
| 4 | **Medium** | Match guard scope over `\|` alternatives | In `4 \| 5 \| 6 if y`, the guard applies to all alternatives, not just `6`. Demonstrated in §19.3.10. |
| 5 | **Medium** | `ref`/`ref mut` obsolete in Rust 2024 | Match ergonomics (Rust 1.26) infers binding modes; `ref` is a historical artefact rarely needed in 2024 edition code. Chapter avoids it in main examples. |
| 6 | **Medium** | `let...else` not in task list but added | Upstream ch19-02 covers it under refutability. Added as §19.1.7 to close the gap. Intentional, not an error. |
| 7 | **Fixed** | Awkward usize range in validation | Original arm `51..=u8::MAX as usize \| usize::MAX` was unidiomatic. Fixed to guard `n if n > 50`. |
| 8 | **Fixed** | Float range patterns not stable | `t @ 37.0..=38.5` does not compile for floats. Fixed to `t if (37.0_f64..=38.5).contains(&t)`. |
| 9 | **OK** | All `match` arms exhaustive | No missing arms found. |
| 10 | **OK** | Java comparisons accurate | Java 21 sealed interface / record pattern descriptions are correct. |
| 11 | **OK** | Edition requirement stated | `if let` chains correctly flagged as requiring Rust 2024 edition. |
| 12 | **OK** | `let...else` divergence requirement | Correctly stated: else block must diverge (return, break, continue, or panic). |

### Summary

Fixes applied before publication: float range pattern → guard form (#8); usize range arm → guard (#7); version corrected from "1.64+" to "1.88 / Rust 2024 edition" (#1). All runnable code examples are now correct. Overall quality: **Good**.
