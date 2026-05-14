# Chapter 17: Async Programming

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes Java developers make when they first encounter Rust's async model.

> **Edition note:** All examples assume `edition = "2024"` in your `Cargo.toml` (requires Rust 1.85+). Create a project with `cargo new my-project` — `edition = "2024"` is the default since Rust 1.85.

> **Java mental model:** Java developers are comfortable with `CompletableFuture`, thread pools, and — since JDK 21 — virtual threads. Rust async is conceptually similar but with important differences: futures are *lazy*, there is no garbage collector, and the borrow checker still applies at compile time across await points. The table below maps Java concurrency vocabulary to Tokio/Rust equivalents.

| Java Concept | Tokio / Rust Equivalent | Key Difference |
|---|---|---|
| `CompletableFuture<T>` | `impl Future<Output = T>` | Rust futures are **lazy** — they do nothing until polled via `.await` |
| `CompletableFuture.allOf(...)` | `tokio::join!` / `futures::future::try_join_all` | `join!` is a macro; both run futures concurrently then collect |
| `CompletableFuture.anyOf(...)` | `tokio::select!` | Macro with random-poll fairness by default; use `biased;` for order |
| Virtual thread (Project Loom) | `tokio::spawn`-ed task | Tokio tasks are M:N scheduled over a small OS thread pool; no JVM carrier thread |
| `ExecutorService` / thread pool | Tokio runtime | `#[tokio::main]` creates a multi-threaded runtime transparently |
| `ScheduledExecutorService.schedule` | `tokio::time::sleep` / `tokio::time::timeout` | Cancellation is by dropping the future, not an explicit cancel token |
| `BlockingQueue<T>` | `tokio::sync::mpsc` channel | Async sender/receiver; bounded or unbounded |
| `java.util.concurrent.Semaphore` | `tokio::sync::Semaphore` | `acquire()` returns a permit guard; dropped permit releases the slot |
| Reactive `Flux<T>` / `Flowable<T>` | `Stream` (tokio-stream / futures) | Pull-based, not push; consumer calls `next().await` |
| Blocking JDBC call on virtual thread | `tokio::task::spawn_blocking` | Required when calling any synchronous/blocking code from async |
| `synchronized` block / `ReentrantLock` | `tokio::sync::Mutex` | Non-reentrant; use tokio's Mutex (not std) when held across `.await` |
| `ReentrantReadWriteLock` | `tokio::sync::RwLock` | Multiple concurrent readers, exclusive writer |

---

> **Note on `trpl`:** The official Rust Programming Language book (chapter 17) uses a teaching crate called `trpl` that re-exports types from `futures` and `tokio`. This cookbook uses `tokio` directly, because that is what production code uses. The `trpl` crate is useful for following along with the book's narrative but is not intended for real applications.

---

## 17.1 Why Async Exists

OS threads are expensive. Each thread on Linux costs around 8 MB of stack space by default plus kernel scheduling overhead. A server handling 10,000 concurrent connections with one thread per connection consumes ~80 GB of virtual memory just for stacks — well before any actual work happens.

**I/O-bound vs CPU-bound:**
- *CPU-bound* tasks (video encoding, crypto) benefit from OS threads or Rayon's work-stealing pool.
- *I/O-bound* tasks (HTTP requests, database queries, file reads) spend most of their time *waiting*. A thread blocked on a network socket wastes a kernel scheduling slot.

Async solves the I/O-bound case by letting a small number of OS threads service a large number of concurrent operations. When a task is waiting for I/O, the runtime schedules another task on that same thread. No kernel context switch is needed.

**Java comparison:**
Java solved this first with `CompletableFuture` callback chains, then with reactive streams (Project Reactor, RxJava), and finally with virtual threads in JDK 21. Virtual threads let blocking code *look* synchronous while the JVM parks the virtual thread. Rust's async/await is closer to the `CompletableFuture` / reactive model than to virtual threads: your code explicitly marks suspension points with `.await`, and a runtime coordinates the scheduling. The advantage over virtual threads is zero-overhead abstractions — there is no JVM, no GC pause, and the borrow checker prevents data races at compile time.

---

## 17.2 Adding Tokio

Tokio is the dominant async runtime in the Rust ecosystem. Almost all production async Rust code runs on Tokio.

Add it to `Cargo.toml`:

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
```

The `"full"` feature enables every Tokio sub-system: the multi-threaded scheduler, async I/O, timers, sync primitives, `fs`, `net`, and the `#[tokio::main]` macro. In a production binary you would enable only what you need to reduce compile times, but `"full"` is correct for examples and getting started.

**Minimum features for common tasks:**

| Task | Minimum features |
|---|---|
| `#[tokio::main]` macro | `"macros"`, `"rt-multi-thread"` |
| `tokio::time::sleep` | `"time"` |
| `tokio::fs` | `"fs"` |
| `tokio::net` | `"net"` |
| `tokio::sync` | `"sync"` |
| `tokio::task::spawn_blocking` | `"rt"` |

---

## 17.3 `async fn`, `async {}`, and `.await`

### 17.3.1 Your First Async Function

```rust
use std::time::Duration;
use tokio::time::sleep;

// An async function returns a Future. It does nothing until awaited.
async fn fetch_data(id: u32) -> String {
    // Simulate network latency without blocking the OS thread.
    sleep(Duration::from_millis(100)).await;
    format!("data for id={id}")
}

#[tokio::main]
async fn main() {
    let result = fetch_data(42).await;
    println!("{result}");
}
```

`async fn fetch_data(...)` desugars to approximately:

```rust
fn fetch_data(id: u32) -> impl Future<Output = String> {
    async move {
        sleep(Duration::from_millis(100)).await;
        format!("data for id={id}")
    }
}
```

The function body is **not executed** when you call `fetch_data(42)`. It returns a value of an anonymous type that implements `Future<Output = String>`. Execution begins only when you call `.await` on it, or when a runtime polls it.

**Java comparison:** `CompletableFuture.supplyAsync(() -> "hello")` begins executing on the fork-join pool immediately. Rust futures do nothing until awaited. This laziness is intentional — it enables zero-cost composability.

### 17.3.2 `async {}` Blocks

You can use `async {}` anywhere an expression is valid:

```rust
use std::time::Duration;
use tokio::time::sleep;

#[tokio::main]
async fn main() {
    let greeting = async {
        sleep(Duration::from_millis(10)).await;
        "hello from async block"
    };

    // Nothing has happened yet. Now we drive it to completion:
    let msg = greeting.await;
    println!("{msg}");
}
```

### 17.3.3 The `Future` Trait

Conceptually, `Future` is defined as:

```rust
pub trait Future {
    type Output;
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}

pub enum Poll<T> {
    Ready(T),
    Pending,
}
```

The runtime calls `poll` repeatedly. When the future is ready, it returns `Poll::Ready(value)`. When it must wait (e.g., for a socket to become readable), it returns `Poll::Pending` and registers a waker with the reactor so the runtime knows to try again later. You almost never implement `Future` by hand — `async fn` generates the state machine for you.

**`Pin<&mut Self>` explained:** Futures hold internal references across await points. Moving them in memory would invalidate those pointers. `Pin` prevents the move. In practice, `.await` and `Box::pin(future)` handle pinning automatically.

### 17.3.4 `#[tokio::main]`

`main` cannot itself be `async` without a runtime. The `#[tokio::main]` attribute expands to:

```rust
fn main() {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(async {
            // your async main body
        });
}
```

Use `#[tokio::main(flavor = "current_thread")]` for single-threaded execution (useful for embedded or simple CLIs):

```rust
#[tokio::main(flavor = "current_thread")]
async fn main() {
    println!("running on a single-threaded runtime");
}
```

---

## 17.4 `tokio::spawn` and `JoinHandle`

`tokio::spawn` launches an async task concurrently. It is analogous to `new Thread(...).start()` or submitting to an `ExecutorService`.

```rust
use std::time::Duration;
use tokio::time::sleep;

async fn download(url: &'static str) -> String {
    sleep(Duration::from_millis(200)).await;
    format!("content from {url}")
}

#[tokio::main]
async fn main() {
    // spawn returns a JoinHandle<String>
    let handle = tokio::spawn(download("https://example.com"));

    // Do other work here while download runs concurrently...
    println!("download started, doing other work");
    sleep(Duration::from_millis(50)).await;

    // Wait for the task. JoinHandle::await returns Result<T, JoinError>.
    let content = handle.await.unwrap();
    println!("got: {content}");
}
```

**`JoinHandle` rules:**
- `.await` on a `JoinHandle<T>` returns `Result<T, tokio::task::JoinError>`.
- `JoinError` occurs if the task panicked or was aborted.
- Dropping a `JoinHandle` **does not cancel** the spawned task — it detaches. Use `handle.abort()` to explicitly cancel.

**Java comparison:** Similar to `Future<T>` returned by `ExecutorService.submit(callable)`, but cancellation semantics differ. In Java, `future.cancel(true)` attempts interrupt-based cancellation. In Rust, `handle.abort()` drops the future at its next await point, which is cooperative cancellation.

### 17.4.1 `Send + 'static` Requirement

`tokio::spawn` requires the future to be `Send + 'static`:

```rust
// This does NOT compile:
// async fn bad(data: &str) -> usize { data.len() }
// tokio::spawn(bad("hello")); // Error: future is not 'static

// Fix: own the data
async fn good(data: String) -> usize {
    data.len()
}

#[tokio::main]
async fn main() {
    let handle = tokio::spawn(good("hello".to_string()));
    println!("{}", handle.await.unwrap());
}
```

The `'static` bound exists because the task may outlive the current scope. The `Send` bound is required because the multi-threaded scheduler can move tasks between worker threads at await points. Java's virtual threads have no equivalent restriction because the JVM heap is garbage-collected and thread-local assumptions are managed differently.

---

## 17.5 Running Futures Concurrently: `tokio::join!`

`tokio::join!` drives multiple futures concurrently on the **current task**. Unlike `tokio::spawn`, it does not create new tasks — it interleaves execution within one task.

```rust
use std::time::Duration;
use tokio::time::sleep;

async fn fetch(name: &str, ms: u64) -> String {
    sleep(Duration::from_millis(ms)).await;
    format!("{name} done")
}

#[tokio::main]
async fn main() {
    // All three run concurrently. Total time ≈ max(100, 200, 150) = 200ms.
    let (a, b, c) = tokio::join!(
        fetch("alpha", 100),
        fetch("beta", 200),
        fetch("gamma", 150),
    );

    println!("{a}");
    println!("{b}");
    println!("{c}");
}
```

**`join!` vs sequential `.await`:**

```rust
// Sequential — total time = 100 + 200 + 150 = 450ms
let a = fetch("alpha", 100).await;
let b = fetch("beta", 200).await;
let c = fetch("gamma", 150).await;

// Concurrent — total time ≈ 200ms
let (a, b, c) = tokio::join!(fetch("alpha", 100), fetch("beta", 200), fetch("gamma", 150));
```

**Java comparison:** `CompletableFuture.allOf(futA, futB, futC).thenRun(...)` runs all futures and waits for all to complete. `tokio::join!` is the direct equivalent but is resolved synchronously (no callbacks).

### 17.5.1 Fan-Out: Spawning N Tasks and Collecting Results

When the number of futures is determined at runtime, use `tokio::spawn` in a loop and collect `JoinHandle`s:

```rust
use std::time::Duration;
use tokio::time::sleep;

async fn process(id: u32) -> u32 {
    sleep(Duration::from_millis(50)).await;
    id * id
}

#[tokio::main]
async fn main() {
    let handles: Vec<_> = (1..=8)
        .map(|id| tokio::spawn(process(id)))
        .collect();

    let mut results = Vec::new();
    for handle in handles {
        results.push(handle.await.unwrap());
    }

    println!("squares: {results:?}");
}
```

For error-propagating fan-out, use `futures::future::try_join_all` (requires the `futures` crate):

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
futures = "0.3"
```

```rust
use futures::future::try_join_all;

async fn fetch_page(id: u32) -> Result<String, String> {
    // simulate potential failure
    if id == 3 {
        return Err(format!("failed on id={id}"));
    }
    Ok(format!("page {id}"))
}

#[tokio::main]
async fn main() -> Result<(), String> {
    let futures: Vec<_> = (1..=5).map(fetch_page).collect();
    let pages = try_join_all(futures).await?;
    println!("fetched {} pages", pages.len());
    Ok(())
}
```

---

## 17.6 Racing Futures: `tokio::select!`

`tokio::select!` polls multiple futures and returns when the *first* one completes, cancelling the rest.

```rust
use std::time::Duration;
use tokio::time::sleep;

async fn task_a() -> &'static str {
    sleep(Duration::from_millis(150)).await;
    "a won"
}

async fn task_b() -> &'static str {
    sleep(Duration::from_millis(100)).await;
    "b won"
}

#[tokio::main]
async fn main() {
    let winner = tokio::select! {
        result = task_a() => result,
        result = task_b() => result,
    };
    println!("{winner}"); // "b won"
}
```

**`select!` cancellation:** When one branch completes, the futures in the other branches are dropped — their async state machines are released and they do not continue running. This is cooperative cancellation. Code after the last `.await` in a dropped future does not execute.

**Biased polling:** By default, `select!` randomly polls branches to prevent starvation. Add `biased;` to poll in declaration order (useful for prioritizing a shutdown signal):

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (shutdown_tx, mut shutdown_rx) = oneshot::channel::<()>();

    // Signal shutdown after a short delay (in real code, from a signal handler).
    tokio::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_millis(200)).await;
        let _ = shutdown_tx.send(());
    });

    let mut counter = 0u32;
    loop {
        tokio::select! {
            biased; // check shutdown first, always
            // Use &mut shutdown_rx so the receiver is not consumed on the first
            // iteration — oneshot::Receiver is not Copy, so we borrow it each loop.
            _ = &mut shutdown_rx => {
                println!("shutting down after {counter} iterations");
                break;
            }
            _ = tokio::time::sleep(std::time::Duration::from_millis(50)) => {
                counter += 1;
                println!("tick {counter}");
            }
        }
    }
}
```

**Java comparison:** `CompletableFuture.anyOf(futA, futB)` returns when the first future completes but does **not** cancel the others. `tokio::select!` drops (cancels) the losing futures, which is a fundamental difference.

---

## 17.7 Timers: `tokio::time::sleep` and `tokio::time::timeout`

### 17.7.1 `sleep`

```rust
use std::time::Duration;
use tokio::time::sleep;

#[tokio::main]
async fn main() {
    println!("before sleep");
    sleep(Duration::from_secs(1)).await;
    println!("after 1 second");
}
```

**Critical:** Never use `std::thread::sleep` in async code — it blocks the OS thread and prevents other tasks on that thread from running. Always use `tokio::time::sleep`.

### 17.7.2 `timeout`

```rust
use std::time::Duration;
use tokio::time::{sleep, timeout};

async fn slow_operation() -> String {
    sleep(Duration::from_secs(5)).await;
    "completed".to_string()
}

#[tokio::main]
async fn main() {
    match timeout(Duration::from_secs(2), slow_operation()).await {
        Ok(result) => println!("success: {result}"),
        Err(_elapsed) => println!("timed out after 2 seconds"),
    }
}
```

`tokio::time::timeout` returns `Result<T, tokio::time::error::Elapsed>`. If the inner future itself returns a `Result`, you get nested results:

```rust
async fn fallible() -> Result<String, std::io::Error> {
    Ok("done".to_string())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // timeout(duration, future).await -> Result<T, Elapsed>
    // where T here is Result<String, io::Error>
    let result: Result<String, _> = timeout(Duration::from_secs(1), fallible())
        .await?  // unwrap Elapsed error
        ;        // result is now Result<String, io::Error>
    println!("{}", result?);
    Ok(())
}
```

Use the `?` operator carefully: the first `?` propagates `Elapsed`, the second propagates the inner IO error.

---

## 17.8 Async I/O

### 17.8.1 Async File Operations with `tokio::fs`

```rust
use tokio::fs;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Write a file asynchronously
    fs::write("hello.txt", b"Hello, async world!\n").await?;

    // Read the whole file into a Vec<u8>
    let bytes = fs::read("hello.txt").await?;
    println!("{}", String::from_utf8_lossy(&bytes));

    // Read as a String
    let content = fs::read_to_string("hello.txt").await?;
    println!("content: {content}");

    // Rename / remove
    fs::rename("hello.txt", "hello2.txt").await?;
    fs::remove_file("hello2.txt").await?;

    Ok(())
}
```

### 17.8.2 `AsyncReadExt` and `AsyncWriteExt`

For streaming reads and writes, use the extension traits from `tokio::io`:

```rust
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Write with AsyncWriteExt
    let mut file = File::create("data.bin").await?;
    file.write_all(b"some binary data").await?;
    file.flush().await?;
    drop(file); // close

    // Read with AsyncReadExt — chunked
    let mut file = File::open("data.bin").await?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf).await?;
    println!("read {} bytes", buf.len());

    // Buffered reading line by line
    use tokio::io::BufReader;
    use tokio::io::AsyncBufReadExt;
    let file = File::open("data.bin").await?;
    let mut reader = BufReader::new(file);
    let mut line = String::new();
    let n = reader.read_line(&mut line).await?;
    println!("read {n} bytes in first line: {line:?}");

    tokio::fs::remove_file("data.bin").await?;
    Ok(())
}
```

### 17.8.3 Concurrent File Reader (Practical Example)

Read multiple files concurrently and collect their contents:

```rust
use tokio::fs;

async fn read_file(path: &str) -> Result<(String, String), std::io::Error> {
    let content = fs::read_to_string(path).await?;
    Ok((path.to_string(), content))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create sample files first
    fs::write("a.txt", "contents of a").await?;
    fs::write("b.txt", "contents of b").await?;
    fs::write("c.txt", "contents of c").await?;

    let paths = vec!["a.txt", "b.txt", "c.txt"];

    // Spawn a task per file — all reads happen concurrently.
    // Use `&'static str` literals so the futures are 'static and can be spawned.
    let handles: Vec<_> = paths
        .iter()
        .copied()                          // &&str → &str (which is &'static str here)
        .map(|path| tokio::spawn(read_file(path)))
        .collect();

    for handle in handles {
        // handle.await  → Result<_, JoinError>   (outer ?)
        // inner value   → Result<_, io::Error>   (inner ?)
        let (path, content) = handle.await??;
        println!("{path}: {content}");
    }

    // Cleanup
    for path in &paths {
        let _ = fs::remove_file(path).await;
    }

    Ok(())
}
```

---

## 17.9 TCP Echo Server

A minimal async TCP echo server demonstrates `TcpListener`, per-connection tasks, and `tokio::io::copy`:

```rust
use tokio::net::TcpListener;
use tokio::io;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;
    println!("echo server listening on 127.0.0.1:8080");

    loop {
        // accept() suspends until a new connection arrives.
        let (socket, addr) = listener.accept().await?;
        println!("new connection from {addr}");

        // Spawn a task per connection — each runs independently.
        tokio::spawn(async move {
            // Split into reader and writer halves so we can use copy.
            let (mut reader, mut writer) = io::split(socket);

            match io::copy(&mut reader, &mut writer).await {
                Ok(bytes) => println!("{addr}: echoed {bytes} bytes"),
                Err(e) => eprintln!("{addr}: error: {e}"),
            }
            println!("{addr}: connection closed");
        });
    }
}
```

To test this without a separate client binary, use `nc` or `telnet`:

```bash
# Terminal 1
cargo run

# Terminal 2
echo "hello server" | nc 127.0.0.1 8080
```

**Architecture notes:**
- The `accept` loop runs on a single async task.
- Each accepted connection spawns its own task, so connections do not block each other.
- `io::split` gives independent `ReadHalf`/`WriteHalf` handles that can be moved into different tasks if needed.
- `io::copy` asynchronously reads from the reader and writes to the writer until the connection closes.

---

## 17.10 Streams

A `Stream` is the async equivalent of an `Iterator`: it produces a sequence of values over time, yielding them one by one as they become available.

### 17.10.1 Setup

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
tokio-stream = "0.1"
```

### 17.10.2 Creating and Consuming Streams

```rust
use tokio_stream::{self, StreamExt};

#[tokio::main]
async fn main() {
    // Create a stream from an iterator.
    let mut stream = tokio_stream::iter(vec![1u32, 2, 3, 4, 5]);

    // Consume items one by one — next() is async, unlike Iterator::next().
    while let Some(value) = stream.next().await {
        println!("got {value}");
    }
}
```

### 17.10.3 Stream Combinators

`StreamExt` provides combinators analogous to `Iterator`:

```rust
use tokio_stream::{self, StreamExt};
use std::time::Duration;

#[tokio::main]
async fn main() {
    let stream = tokio_stream::iter(1u32..=10);

    // map + filter + take, then collect
    let results: Vec<u32> = stream
        .filter(|n| n % 2 == 0)       // keep evens
        .map(|n| n * n)               // square them
        .take(3)                      // take first 3
        .collect()
        .await;

    println!("{results:?}"); // [4, 16, 36]
}
```

### 17.10.4 Time-Based Stream (Ticks)

```rust
use tokio_stream::StreamExt;
use tokio::time::{interval, Duration};
use tokio_stream::wrappers::IntervalStream;

#[tokio::main]
async fn main() {
    // Emit a tick every 100ms, take 5 ticks.
    let mut stream = IntervalStream::new(interval(Duration::from_millis(100)))
        .take(5);

    while let Some(_tick) = stream.next().await {
        println!("tick");
    }
    println!("done");
}
```

### 17.10.5 Converting a Channel Receiver into a Stream

```rust
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tokio_stream::StreamExt;

#[tokio::main]
async fn main() {
    let (tx, rx) = mpsc::channel::<u32>(16);

    // Produce values in a background task.
    tokio::spawn(async move {
        for i in 0..5 {
            tx.send(i).await.unwrap();
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        }
        // tx drops here, closing the channel.
    });

    // Treat the receiver as a stream.
    let mut stream = ReceiverStream::new(rx);
    while let Some(value) = stream.next().await {
        println!("stream value: {value}");
    }
}
```

---

## 17.11 Error Handling in Async

The `?` operator works inside `async fn` exactly as in synchronous functions:

```rust
use tokio::fs;

async fn read_config(path: &str) -> Result<String, std::io::Error> {
    let content = fs::read_to_string(path).await?; // ? propagates io::Error
    Ok(content)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = read_config("config.toml").await?;
    println!("{config}");
    Ok(())
}
```

### 17.11.1 `anyhow` in Async Context

`anyhow` works seamlessly with async:

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
anyhow = "1"
```

```rust
use anyhow::{Context, Result};
use tokio::fs;

async fn load_and_parse(path: &str) -> Result<u64> {
    let text = fs::read_to_string(path)
        .await
        .with_context(|| format!("failed to read {path}"))?;

    let number: u64 = text.trim().parse()
        .with_context(|| format!("invalid number in {path}"))?;

    Ok(number)
}

#[tokio::main]
async fn main() -> Result<()> {
    match load_and_parse("count.txt").await {
        Ok(n) => println!("count = {n}"),
        Err(e) => eprintln!("error: {e:#}"), // {:#} prints full chain
    }
    Ok(())
}
```

### 17.11.2 Collecting Results from Spawned Tasks

When spawning fallible tasks, you deal with double-wrapping: `JoinError` on the outside, your error type on the inside:

```rust
use anyhow::Result;

async fn might_fail(id: u32) -> Result<String> {
    if id == 2 {
        anyhow::bail!("id 2 always fails");
    }
    Ok(format!("ok {id}"))
}

#[tokio::main]
async fn main() -> Result<()> {
    let handles: Vec<_> = (1..=4)
        .map(|id| tokio::spawn(might_fail(id)))
        .collect();

    for (i, handle) in handles.into_iter().enumerate() {
        match handle.await {
            Ok(Ok(msg)) => println!("task {i}: {msg}"),
            Ok(Err(e)) => println!("task {i} logic error: {e}"),
            Err(je) => println!("task {i} panicked: {je}"),
        }
    }
    Ok(())
}
```

---

## 17.12 Channels in Async

Tokio provides four channel types for different communication patterns:

| Channel | Use case | Senders | Receivers |
|---|---|---|---|
| `mpsc` | Work queues, event buses | Many (clone sender) | One |
| `oneshot` | Request-response, one-shot result | One | One |
| `broadcast` | Fan-out to many subscribers | One or many | Many |
| `watch` | Latest-value notifications (config, state) | One | Many |

### 17.12.1 `mpsc` — Multi-Producer Single-Consumer

```rust
use tokio::sync::mpsc;
use std::time::Duration;

#[tokio::main]
async fn main() {
    // Bounded channel — sender blocks (async) when buffer is full.
    let (tx, mut rx) = mpsc::channel::<String>(32);

    // Clone the sender before moving the original into the first spawn.
    // Both tx (moved into spawn 1) and tx2 (moved into spawn 2) must be
    // dropped for the channel to close and rx.recv() to return None.
    let tx1 = tx.clone();
    let tx2 = tx.clone();

    // The original tx is no longer needed here — drop it so the channel
    // closes when both spawned producers finish.
    drop(tx);

    // Producer 1
    tokio::spawn(async move {
        for i in 0..3 {
            tx1.send(format!("producer-1: msg {i}")).await.unwrap();
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        // tx1 drops here
    });

    // Producer 2
    tokio::spawn(async move {
        for i in 0..3 {
            tx2.send(format!("producer-2: msg {i}")).await.unwrap();
            tokio::time::sleep(Duration::from_millis(150)).await;
        }
        // tx2 drops here; channel closes when both producers are done
    });

    // Consumer — loops until all senders are dropped.
    while let Some(msg) = rx.recv().await {
        println!("received: {msg}");
    }
    println!("channel closed");
}
```

### 17.12.2 `oneshot` — Single Response

```rust
use tokio::sync::oneshot;

async fn compute(tx: oneshot::Sender<u64>, input: u64) {
    tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    let _ = tx.send(input * input); // ignore error if receiver dropped
}

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel();

    tokio::spawn(compute(tx, 12));

    match rx.await {
        Ok(result) => println!("12² = {result}"),
        Err(_) => println!("sender dropped without sending"),
    }
}
```

**Java comparison:** `oneshot` is equivalent to a `CompletableFuture` that you pass to one producer and one consumer, manually completing it.

### 17.12.3 `broadcast` — Fan-Out

```rust
use tokio::sync::broadcast;

#[tokio::main]
async fn main() {
    let (tx, _) = broadcast::channel::<String>(16);

    // Subscribe two receivers before sending.
    let mut rx1 = tx.subscribe();
    let mut rx2 = tx.subscribe();

    tokio::spawn(async move {
        while let Ok(msg) = rx1.recv().await {
            println!("receiver-1 got: {msg}");
        }
    });

    tokio::spawn(async move {
        while let Ok(msg) = rx2.recv().await {
            println!("receiver-2 got: {msg}");
        }
    });

    tx.send("broadcast message 1".to_string()).unwrap();
    tx.send("broadcast message 2".to_string()).unwrap();

    // Give spawned tasks time to process.
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
}
```

---

## 17.13 Shared State: `tokio::sync::Mutex` and `RwLock`

### 17.13.1 Why NOT `std::sync::Mutex` Across Await Points

```rust
use std::sync::Mutex;
use std::time::Duration;

// This compiles but is WRONG — std::Mutex held across .await
// blocks the OS thread while waiting.
async fn bad_example(data: &Mutex<Vec<u32>>) {
    let mut guard = data.lock().unwrap();
    tokio::time::sleep(Duration::from_millis(100)).await; // BLOCKS THREAD!
    guard.push(42);
} // guard drops here
```

The problem: `std::sync::Mutex` holds the OS mutex across the await point, blocking the worker thread from servicing other tasks.

**Fix 1:** Drop the guard before the `.await`:

```rust
use std::sync::Mutex;

async fn fixed_with_std_mutex(data: &Mutex<Vec<u32>>) {
    {
        let mut guard = data.lock().unwrap();
        guard.push(42);
    } // guard drops here — lock released before any await
    tokio::time::sleep(std::time::Duration::from_millis(100)).await; // fine
}
```

**Fix 2:** Use `tokio::sync::Mutex` when you must hold the lock across `.await`:

```rust
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() {
    let data = Arc::new(Mutex::new(vec![]));

    let handles: Vec<_> = (0..5)
        .map(|i| {
            let data = Arc::clone(&data);
            tokio::spawn(async move {
                let mut guard = data.lock().await; // async lock acquisition
                tokio::time::sleep(std::time::Duration::from_millis(10)).await;
                guard.push(i);
                // guard drops at end of scope — lock released
            })
        })
        .collect();

    for h in handles {
        h.await.unwrap();
    }

    println!("{:?}", data.lock().await);
}
```

### 17.13.2 `RwLock` for Read-Heavy Workloads

```rust
use std::sync::Arc;
use tokio::sync::RwLock;

#[tokio::main]
async fn main() {
    let config = Arc::new(RwLock::new(std::collections::HashMap::<String, String>::new()));

    // Many concurrent readers.
    let mut readers = vec![];
    for _ in 0..4 {
        let config = Arc::clone(&config);
        readers.push(tokio::spawn(async move {
            let guard = config.read().await; // shared read lock
            println!("config size: {}", guard.len());
        }));
    }

    // One exclusive writer.
    {
        let mut guard = config.write().await;
        guard.insert("host".to_string(), "localhost".to_string());
    } // write lock released here

    for r in readers {
        r.await.unwrap();
    }
}
```

---

## 17.14 `spawn_blocking`: Calling Blocking Code from Async

When you must call synchronous blocking code (database drivers, CPU-intensive work, legacy libraries), use `tokio::task::spawn_blocking` to run it on a dedicated thread pool that does not affect the async worker threads.

```rust
use tokio::task;

fn heavy_computation(input: u64) -> u64 {
    // Simulates blocking/CPU-intensive work (e.g., hashing, compression).
    // std::thread::sleep would block; in real code this might be diesel, LZMA, etc.
    let mut result = input;
    for i in 1..=1_000_000u64 {
        result = result.wrapping_add(i);
    }
    result
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let result = task::spawn_blocking(move || {
        heavy_computation(42)
    }).await?;

    println!("result: {result}");
    Ok(())
}
```

**Java comparison:** Equivalent to submitting a `Callable` to `ForkJoinPool.commonPool()` for CPU work, or using a separate `ExecutorService` for blocking I/O while keeping the main event loop free. The critical difference: in Java you might block a virtual thread without ill effect; in Rust's async, blocking a worker thread starves all other tasks on that thread.

**When to use `spawn_blocking`:**
- Synchronous file I/O that you cannot replace with `tokio::fs`
- CPU-intensive computation that would exceed a few milliseconds
- Any call to a blocking C library via FFI
- Synchronous database drivers (Diesel, rusqlite)

---

## 17.15 Semaphore for Rate Limiting

`tokio::sync::Semaphore` limits the number of concurrent operations:

```rust
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Semaphore;
use tokio::time::sleep;

const MAX_CONCURRENT: usize = 3;

async fn fetch_url(id: u32) -> String {
    // Simulate HTTP request latency.
    sleep(Duration::from_millis(200)).await;
    format!("response {id}")
}

#[tokio::main]
async fn main() {
    let semaphore = Arc::new(Semaphore::new(MAX_CONCURRENT));

    let handles: Vec<_> = (1..=10)
        .map(|id| {
            let sem = Arc::clone(&semaphore);
            tokio::spawn(async move {
                // acquire_owned() gives a permit that is Send + 'static.
                // Hold the permit in the spawning closure; drop it when done.
                let _permit = sem.acquire_owned().await.unwrap();
                let result = fetch_url(id).await;
                // _permit drops here — slot freed for the next waiter.
                result
            })
        })
        .collect();

    for handle in handles {
        let result = handle.await.unwrap();
        println!("{result}");
    }
}
```

Only `MAX_CONCURRENT` (3) tasks will be inside `fetch_url` simultaneously. The rest wait in `acquire_owned()` until a permit is released. This is the async equivalent of `java.util.concurrent.Semaphore`.

---

## 17.16 Practical Example: Async HTTP Fetcher (Simulated)

A realistic pattern for concurrent HTTP fetching, simulated with `tokio::time::sleep` to avoid requiring `reqwest`:

```rust
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Semaphore;
use tokio::time::{sleep, timeout, Instant};

#[derive(Debug)]
struct FetchResult {
    url: String,
    status: Result<String, String>,
    elapsed_ms: u128,
}

/// Simulates an HTTP GET. Replace body with `reqwest::get(url).await` in production.
async fn http_get(url: &str) -> Result<String, String> {
    // Simulate variable latency.
    let ms = (url.len() as u64 % 5) * 100 + 50;
    sleep(Duration::from_millis(ms)).await;

    // Simulate occasional failure.
    if url.contains("fail") {
        return Err(format!("connection refused: {url}"));
    }
    Ok(format!("200 OK body from {url}"))
}

async fn fetch_with_timeout(url: String, deadline: Duration) -> FetchResult {
    let start = Instant::now();
    let status = match timeout(deadline, http_get(&url)).await {
        Ok(Ok(body)) => Ok(body),
        Ok(Err(e)) => Err(e),
        Err(_elapsed) => Err(format!("timeout after {}ms", deadline.as_millis())),
    };
    FetchResult {
        url,
        status,
        elapsed_ms: start.elapsed().as_millis(),
    }
}

#[tokio::main]
async fn main() {
    let urls = vec![
        "https://example.com/api/users",
        "https://example.com/api/posts",
        "https://fail.example.com/data",
        "https://example.com/api/comments",
        "https://example.com/api/tags",
    ];

    // Limit to 3 concurrent requests.
    let semaphore = Arc::new(Semaphore::new(3));
    let timeout_duration = Duration::from_millis(500);

    let handles: Vec<_> = urls
        .into_iter()
        .map(|url| {
            let sem = Arc::clone(&semaphore);
            let url = url.to_string();
            tokio::spawn(async move {
                let _permit = sem.acquire_owned().await.unwrap();
                fetch_with_timeout(url, timeout_duration).await
            })
        })
        .collect();

    let mut success_count = 0;
    let mut error_count = 0;

    for handle in handles {
        let result = handle.await.unwrap();
        match &result.status {
            Ok(body) => {
                success_count += 1;
                println!("[{}ms] OK  {}: {}...", result.elapsed_ms, result.url,
                    &body[..body.len().min(40)]);
            }
            Err(e) => {
                error_count += 1;
                println!("[{}ms] ERR {}: {}", result.elapsed_ms, result.url, e);
            }
        }
    }

    println!("\n{success_count} succeeded, {error_count} failed");
}
```

---

## 17.17 Common Pitfalls

### Pitfall 1: Blocking the Async Thread

```rust
// WRONG: blocks the tokio worker thread
async fn bad() {
    std::thread::sleep(std::time::Duration::from_secs(1)); // NEVER do this
    std::fs::read_to_string("file.txt").unwrap();          // NEVER do this
}

// CORRECT:
async fn good() {
    tokio::time::sleep(std::time::Duration::from_secs(1)).await; // ok
    tokio::fs::read_to_string("file.txt").await.unwrap();        // ok
}
```

### Pitfall 2: `std::sync::Mutex` Held Across `.await`

As shown in §17.13.1, holding an `std::sync::Mutex` guard across an `.await` point can cause deadlocks or performance problems. Use `tokio::sync::Mutex` or restructure to release the lock before awaiting.

### Pitfall 3: Forgetting `Send + 'static` for Spawned Tasks

Borrows and non-`Send` types cannot be sent across tasks:

```rust
// WRONG
let local = std::rc::Rc::new(42); // Rc is not Send
tokio::spawn(async move {
    println!("{}", local); // compile error: Rc<i32> cannot be sent
});

// CORRECT: use Arc instead of Rc
let shared = std::sync::Arc::new(42);
tokio::spawn(async move {
    println!("{}", shared); // ok: Arc<i32> is Send
});
```

### Pitfall 4: Cancellation and Cleanup

Dropping a future cancels it at its next await point. If a future performs cleanup (closing resources, sending a final message), that cleanup may not run if the future is cancelled:

```rust
use tokio::sync::mpsc;

async fn worker(mut rx: mpsc::Receiver<u32>) {
    while let Some(item) = rx.recv().await {
        // process item
        println!("processing {item}");
    }
    println!("worker shutting down cleanly"); // runs when channel closes
}
```

For guaranteed cleanup, use `tokio::select!` with a cancellation token or implement `Drop` on a guard struct that performs the cleanup synchronously.

### Pitfall 5: `select!` Cancellation Safety

Not all futures are safe to cancel and restart. `tokio::sync::mpsc::Receiver::recv()` is cancellation-safe (you won't lose a message). `tokio::io::AsyncReadExt::read_exact()` is *not* — if cancelled mid-read, you've consumed some bytes. Check the Tokio docs for each API's cancellation safety guarantee.

---

## 17.18 `async fn` in Traits (Rust 2024)

Since Rust 1.75, `async fn` in traits is stable:

```rust
trait Fetcher {
    async fn fetch(&self, url: &str) -> Result<String, String>;
}

struct MockFetcher;

impl Fetcher for MockFetcher {
    async fn fetch(&self, url: &str) -> Result<String, String> {
        tokio::time::sleep(std::time::Duration::from_millis(10)).await;
        Ok(format!("mock response for {url}"))
    }
}

#[tokio::main]
async fn main() {
    let f = MockFetcher;
    match f.fetch("https://example.com").await {
        Ok(r) => println!("{r}"),
        Err(e) => eprintln!("{e}"),
    }
}
```

**Caveat:** `async fn` in traits using dynamic dispatch (`dyn Trait`) still requires the `async-trait` crate or manual `Box::pin` wrapping, because the compiler cannot determine the size of the returned future at compile time when dispatching dynamically. For static dispatch (generics), it works natively.

---

## 17.19 Summary: Choosing the Right Tool

| Goal | Tool |
|---|---|
| Run async code at all | `#[tokio::main]` / `tokio::runtime::Runtime::block_on` |
| Run one future, wait for it | `.await` |
| Run N futures concurrently (known N) | `tokio::join!` |
| Run N futures concurrently (dynamic N) | `Vec<JoinHandle>` + loop, or `futures::future::try_join_all` |
| Race futures, take first result | `tokio::select!` |
| Background independent task | `tokio::spawn` + `JoinHandle` |
| Work queue (multiple producers) | `tokio::sync::mpsc` |
| Single response / handoff | `tokio::sync::oneshot` |
| Publish to many subscribers | `tokio::sync::broadcast` |
| Latest value notification | `tokio::sync::watch` |
| Shared mutable state | `Arc<tokio::sync::Mutex<T>>` |
| Read-heavy shared state | `Arc<tokio::sync::RwLock<T>>` |
| Rate limiting | `Arc<tokio::sync::Semaphore>` |
| Call blocking / CPU code | `tokio::task::spawn_blocking` |
| Sequence of async values | `tokio_stream::StreamExt` |
| Deadline on any future | `tokio::time::timeout` |

---

## 📝 Chapter Review Notes

*The following is a critical third-person review of this chapter, intended for editorial use.*

### Overall Assessment

The chapter covers the primary Tokio surface area at appropriate depth for its target audience. The Java mental-model table is the strongest structural element, providing immediate orientation for readers who know `CompletableFuture` but not Rust futures. The progression from simple `async fn` through channels, shared state, and streams follows a logical dependency order. Code examples are self-contained and include realistic setup/teardown.

### Issues Table

| Severity | Topic | Status / Issue |
|---|---|---|
| **Fixed** | §17.12.1 `mpsc` example | Original had `tx` moved into first spawn then `drop(tx)` below — a compile error. Fixed: two clones (`tx1`, `tx2`), drop original before spawning, channel closes when both clones drop. |
| **Fixed** | §17.6 `select!` biased loop | `oneshot::Receiver` consumed on first loop iteration. Fixed: declared `mut shutdown_rx`, used `&mut shutdown_rx` in the `select!` branch so the receiver is borrowed, not moved. |
| **Fixed** | §17.15 Semaphore | Permit was passed as a function parameter (non-idiomatic). Fixed: permit held via `_permit` in the spawning closure; drops at scope end after the inner future resolves. |
| **Fixed** | §17.8.3 File reader | `.iter()` on `Vec<&str>` gives `&&str`; added `.copied()` to produce `&'static str` required for `'static` bound. Added inline comment explaining double-`??`. |
| **High** | §17.9 TCP echo server | Server loops forever with no shutdown path. A production example needs `tokio::signal::ctrl_c()` or a shutdown channel. Omitted here to keep the echo example readable; a graceful-shutdown section is recommended for a future revision. |
| **Medium** | §17.3.3 `Future` / `Pin` | `Pin<&mut Self>` introduced without sufficient explanation. Java developers will not understand self-referential state machines. A cross-reference to Chapter 15 and one paragraph on why moves invalidate internal pointers would help. |
| **Medium** | §17.10 `Stream` not in std | `Stream` lives in `futures-core`, not `std`. The chapter mentions this, but a callout box would make it more visible — Java developers expect a standard library analog to `java.util.stream.Stream`. |
| **Low** | §17.18 `async fn` in traits | `dyn Trait` caveat correct but does not name `async-trait` crate or show the workaround. |
| **Low** | §17.7.2 nested `Result` | Explanation of `Result<Result<T,E>, Elapsed>` is terse. Noting that `timeout` *wraps* the inner output would clarify. |
| **OK** | §17.4 `JoinHandle` drop | Correctly states drop = detach; `abort()` needed for cancellation. |
| **OK** | §17.13 Mutex warning | Correct identification of `std::sync::Mutex` across `.await` as problematic; two correct fixes shown. |
| **OK** | §17.2 feature flags | Accurate for Tokio 1.x. |
| **OK** | Tokio version | All APIs match Tokio 1.x (current stable as of 2026). |
| **OK** | Rust 2024 edition | `async fn` in traits stabilized at 1.75; `dyn Trait` caveat accurate. |

### Fact-Check Notes

- `tokio::select!` randomly polls by default: **correct** (pseudo-random unless `biased;`).
- `JoinHandle` drop = detach, not cancel: **correct** — use `.abort()`.
- `std::sync::Mutex` across `.await` is problematic: **correct** — the chapter explains the problem and two fixes.
- `tokio::time::timeout` returns `Result<T, Elapsed>`: **correct**.
- `async fn` in traits stable since Rust 1.75: **correct**.
- `tokio::spawn` requires `Send + 'static`: **correct** for multi-thread runtime.
- `tokio-stream` is a separate crate: **correct** — separate `Cargo.toml` entry required.
- `io::copy` for echo server: **correct** — copies until EOF, back-pressure handled.
- `&mut shutdown_rx` in `select!` loop: **correct** — `oneshot::Receiver` is not `Copy`; `&mut` borrows rather than moves it.

### Suggested Additions for a Future Revision

1. **Graceful shutdown** (`tokio::signal::ctrl_c`) — directly relevant to the TCP server example.
2. **`Pin` and `Box::pin`** — the most common confusing compile error for new async Rust developers.
3. **`async fn` with `dyn Trait`** — the `async-trait` crate workaround with a minimal example.
4. **`tokio-console`** — async equivalent of thread dumps; essential for debugging production async code.
5. **`tokio::task::LocalSet`** — for running `!Send` futures on a dedicated thread.
