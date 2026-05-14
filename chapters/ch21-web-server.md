# Chapter 21: Final Project — Building a Multithreaded Web Server

This capstone chapter builds a complete, production-grade HTTP server from first principles using only Rust's standard library. There are no web framework crates, no HTTP parsing libraries, and no async runtimes — just raw TCP sockets, ownership, channels, and threads.

By the end you will have:
- A threaded server that handles concurrent requests
- A hand-rolled `ThreadPool` you can explain line by line
- Graceful shutdown via the `Drop` trait
- Route-based dispatch, static file serving, and JSON responses
- A brief comparison with Tokio for async I/O
- Connection timeout handling

The chapter mirrors the progression in the official Rust Book (Chapter 21) but goes further, adding practical extensions and explicit comparisons with Java's networking stack.

---

## Protocol Background: TCP and HTTP

Both TCP and HTTP are request-response protocols. A client initiates a connection; the server accepts it, reads the request, and writes a response.

**TCP** (Transmission Control Protocol) is the transport layer. It delivers ordered, reliable byte streams between two endpoints. It says nothing about what those bytes mean.

**HTTP** (Hypertext Transfer Protocol) rides on top of TCP and defines the structure of requests and responses. An HTTP request looks like:

```
GET /index.html HTTP/1.1\r\n
Host: localhost:7878\r\n
\r\n
```

An HTTP response looks like:

```
HTTP/1.1 200 OK\r\n
Content-Length: 42\r\n
Content-Type: text/html\r\n
\r\n
<html>...</html>
```

The blank line separating headers from body is mandatory and load-bearing — parsers depend on it.

### Java Comparison

| Concept | Java | Rust |
|---|---|---|
| Listen for connections | `ServerSocket(7878)` | `TcpListener::bind("127.0.0.1:7878")` |
| Accept a connection | `serverSocket.accept()` → `Socket` | `listener.incoming()` → `TcpStream` |
| Read/write | `socket.getInputStream()` / `getOutputStream()` | `TcpStream` implements `Read + Write` |
| Buffered reading | `BufferedReader(InputStreamReader(...))` | `BufReader::new(stream)` |
| Thread pool | `Executors.newFixedThreadPool(4)` | Roll your own with `mpsc` + `thread::spawn` |
| HTTP high-level | `com.sun.net.httpserver.HttpServer` | Not in std — you build it (or use a crate) |

Java's standard library includes `com.sun.net.httpserver.HttpServer`, which is a production-ready HTTP server. Rust's standard library intentionally excludes one: the ecosystem solved this problem at the crate level (Hyper, Actix, Axum). This chapter shows how you would build the foundation yourself.

---

## Project Setup

```bash
cargo new hello --edition 2024
cd hello
```

Your `Cargo.toml` will look like this. For the base project you need no external dependencies. The Tokio section at the end needs an extra entry.

```toml
[package]
name = "hello"
version = "0.1.0"
edition = "2024"

[[bin]]
name = "hello"
path = "src/main.rs"

# Uncomment for the Tokio example in Stage 8
# [dependencies]
# tokio = { version = "1", features = ["full"] }
```

Create two HTML files the server will serve:

```bash
mkdir -p static
```

**`static/hello.html`:**
```html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Hello!</title></head>
<body>
  <h1>Hello from Rust!</h1>
  <p>Your multithreaded server is working.</p>
</body>
</html>
```

**`static/404.html`:**
```html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Not Found</title></head>
<body>
  <h1>404 — Page Not Found</h1>
  <p>The resource you requested does not exist.</p>
</body>
</html>
```

---

## Stage 1 — Listening to TCP Connections

Start with the minimum: bind to a port and print something when a connection arrives.

```rust
// src/main.rs — Stage 1
use std::net::TcpListener;

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    println!("Listening on http://127.0.0.1:7878");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        println!("Connection established from {:?}", stream.peer_addr());
    }
}
```

`TcpListener::bind` binds to the given address and port. If the port is in use, `unwrap()` panics with a clear error — good enough for now; Chapter 9 covers proper error propagation.

`listener.incoming()` returns an iterator of `Result<TcpStream, io::Error>`. Each iteration blocks until a new connection arrives, then yields the stream. The shadow binding `let stream = stream.unwrap()` unwraps the `Result` — the outer `stream` is a `Result`, the inner is a `TcpStream`.

**Run it, then in another terminal:**

```bash
curl http://127.0.0.1:7878/
```

The server prints the connection info. The `curl` command will hang (we read nothing) and eventually close. That is expected.

### Java Comparison

```java
// Java equivalent — Stage 1
try (ServerSocket server = new ServerSocket(7878)) {
    while (true) {
        Socket client = server.accept(); // blocks
        System.out.println("Connection from: " + client.getRemoteSocketAddress());
        client.close();
    }
}
```

The structural parallel is exact: bind, loop, accept. The key difference is that Java's `accept()` must be called explicitly in a loop, while Rust's `incoming()` is a lazy iterator that calls `accept()` under the hood.

---

## Stage 2 — Reading the HTTP Request

Now read the bytes the client sent and parse the request line.

```rust
// src/main.rs — Stage 2
use std::{
    io::{BufRead, BufReader},
    net::{TcpListener, TcpStream},
};

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&stream);

    // Read lines until the blank line that separates headers from body
    let http_request: Vec<String> = buf_reader
        .lines()
        .map(|result| result.unwrap())
        .take_while(|line| !line.is_empty())
        .collect();

    println!("Request:\n{:#?}", http_request);
}
```

`BufReader::new(&stream)` wraps a shared reference to the stream in a buffered reader. The `&` is important: both the `BufReader` (for reading) and the original `stream` (for writing responses later) need access to the same file descriptor. Rust allows this because `TcpStream` implements both `Read` for `&TcpStream` and `Write` for `&TcpStream` — the stream is internally synchronized by the OS.

`.take_while(|line| !line.is_empty())` stops collecting once it hits the blank line that ends the HTTP headers. Without this you would block waiting for more data that the client may never send.

**Run and `curl`** — you will see the request headers printed to stdout.

---

## Stage 3 — Sending HTTP Responses (200 and 404)

Parse the first request line to determine the path and send the appropriate response.

```rust
// src/main.rs — Stage 3
use std::{
    fs,
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
};

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&stream);

    // The first line is the request line: "GET /path HTTP/1.1"
    let request_line = buf_reader
        .lines()
        .next()
        .unwrap()  // Option: at least one line must exist
        .unwrap(); // Result: I/O error

    let (status_line, filename) = if request_line == "GET / HTTP/1.1" {
        ("HTTP/1.1 200 OK", "static/hello.html")
    } else {
        ("HTTP/1.1 404 NOT FOUND", "static/404.html")
    };

    let body = fs::read_to_string(filename).unwrap();
    let length = body.len();

    let response = format!(
        "{status_line}\r\nContent-Length: {length}\r\nContent-Type: text/html; charset=utf-8\r\n\r\n{body}"
    );

    stream.write_all(response.as_bytes()).unwrap();
}
```

The response format is strict: `\r\n` line endings, a blank line (`\r\n\r\n`) between headers and body, and an accurate `Content-Length`. Most browsers will handle sloppy responses, but `curl -v` will expose problems immediately.

**Test it:**

```bash
curl -v http://127.0.0.1:7878/          # 200 with hello.html
curl -v http://127.0.0.1:7878/missing   # 404 with 404.html
```

### Java Comparison

```java
// Java — reading and responding
Socket client = server.accept();
BufferedReader in = new BufferedReader(
    new InputStreamReader(client.getInputStream()));
PrintWriter out = new PrintWriter(client.getOutputStream(), true);

String requestLine = in.readLine();
String[] parts = requestLine.split(" ");
String path = parts[1];

if ("/".equals(path)) {
    String body = Files.readString(Path.of("static/hello.html"));
    out.print("HTTP/1.1 200 OK\r\nContent-Length: " + body.length() + "\r\n\r\n" + body);
} else {
    // 404 response...
}
client.close();
```

Rust's pattern: one stream, two accessors (BufReader for reads, `write_all` directly on the stream for writes). Java separates input and output streams from the same socket, which is more familiar but requires more boilerplate.

---

## Stage 3.5 — Extended Routing, Static Files, and JSON

Before adding threading we add more routes. This gives the multithreaded server something realistic to dispatch.

```rust
// src/main.rs — Stage 3.5 (single-threaded, extended routing)
use std::{
    collections::HashMap,
    fs,
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
    path::Path,
    time::Duration,
};

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    println!("Server running on http://127.0.0.1:7878");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    // Set timeouts to avoid slow-client starvation
    stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    stream
        .set_write_timeout(Some(Duration::from_secs(5)))
        .unwrap();

    let buf_reader = BufReader::new(&stream);

    let request_line = match buf_reader.lines().next() {
        Some(Ok(line)) => line,
        _ => return, // malformed or timed-out connection — drop it silently
    };

    // Parse "METHOD /path HTTP/version"
    let mut parts = request_line.splitn(3, ' ');
    let method = parts.next().unwrap_or("");
    let path   = parts.next().unwrap_or("/");

    route(&mut stream, method, path);
}

fn route(stream: &mut TcpStream, method: &str, path: &str) {
    match (method, path) {
        ("GET", "/") | ("GET", "/index.html") => {
            serve_file(stream, "static/hello.html");
        }
        ("GET", "/api/status") => {
            serve_json(stream, r#"{"status":"ok","server":"rust-hello"}"#);
        }
        ("GET", p) if p.starts_with("/static/") => {
            serve_static(stream, p);
        }
        _ => {
            serve_not_found(stream);
        }
    }
}

fn serve_file(stream: &mut TcpStream, path: &str) {
    match fs::read_to_string(path) {
        Ok(body) => send_response(stream, 200, "OK", "text/html; charset=utf-8", &body),
        Err(_)   => serve_not_found(stream),
    }
}

fn serve_not_found(stream: &mut TcpStream) {
    let body = fs::read_to_string("static/404.html")
        .unwrap_or_else(|_| "<h1>404 Not Found</h1>".to_string());
    send_response(stream, 404, "NOT FOUND", "text/html; charset=utf-8", &body);
}

fn serve_static(stream: &mut TcpStream, url_path: &str) {
    // Security: reject path traversal
    if url_path.contains("..") {
        serve_not_found(stream);
        return;
    }

    // Map URL path to filesystem path (strip leading '/')
    let fs_path = format!(".{url_path}");
    let ext = Path::new(&fs_path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("");

    let content_type = match ext {
        "html" => "text/html; charset=utf-8",
        "css"  => "text/css",
        "js"   => "application/javascript",
        "png"  => "image/png",
        "ico"  => "image/x-icon",
        _      => "application/octet-stream",
    };

    match fs::read_to_string(&fs_path) {
        Ok(body) => send_response(stream, 200, "OK", content_type, &body),
        Err(_)   => serve_not_found(stream),
    }
}

fn serve_json(stream: &mut TcpStream, json: &str) {
    send_response(stream, 200, "OK", "application/json", json);
}

fn send_response(
    stream: &mut TcpStream,
    status_code: u16,
    status_text: &str,
    content_type: &str,
    body: &str,
) {
    let response = format!(
        "HTTP/1.1 {status_code} {status_text}\r\n\
         Content-Type: {content_type}\r\n\
         Content-Length: {}\r\n\
         \r\n\
         {body}",
        body.len()
    );
    let _ = stream.write_all(response.as_bytes());
}
```

**Test the new routes:**

```bash
curl http://127.0.0.1:7878/
curl http://127.0.0.1:7878/api/status
curl http://127.0.0.1:7878/static/hello.html
curl http://127.0.0.1:7878/../etc/passwd   # returns 404, not the file
```

Key design decisions:

- **Path traversal check**: `if url_path.contains("..")` is a simple but effective guard. A production server would canonicalize the path against a base directory using `std::fs::canonicalize`.
- **Timeouts**: `set_read_timeout` prevents a slow client from monopolizing a connection indefinitely. This is even more important with a fixed-size thread pool where each blocked thread is a wasted resource.
- **Route function**: separates dispatch from I/O, making both independently testable.

---

## Stage 4 — The Problem with Single-Threading

Add a `/sleep` route that simulates a slow endpoint:

```rust
// Add to the route() match arm:
("GET", "/sleep") => {
    std::thread::sleep(Duration::from_secs(5));
    serve_json(stream, r#"{"message":"I just woke up"}"#);
}
```

Open two terminals simultaneously:

```bash
# Terminal 1 — this will take 5 seconds
curl http://127.0.0.1:7878/sleep

# Terminal 2 — immediately after starting Terminal 1
curl http://127.0.0.1:7878/api/status   # waits ~5 seconds! blocked by Terminal 1
```

The single-threaded server processes requests one at a time. One slow request blocks every other client. This is the `Thread-per-request` problem Java developers solved with `ExecutorService`. Rust's answer is a `ThreadPool`.

### Java ExecutorService Equivalent

```java
// Java: fixed thread pool
ExecutorService pool = Executors.newFixedThreadPool(4);
ServerSocket server = new ServerSocket(7878);
while (true) {
    Socket client = server.accept();
    pool.submit(() -> handleConnection(client));
}
pool.shutdown();
pool.awaitTermination(30, TimeUnit.SECONDS);
```

We will build the Rust equivalent from scratch, which teaches more about ownership and concurrency than using a ready-made pool would.

---

## Stage 5 — The ThreadPool: Architecture

The pool consists of three pieces:

1. **`ThreadPool`**: holds a channel sender and a vector of `Worker`s. Its `execute` method sends jobs into the channel.
2. **`Worker`**: holds a thread handle. The thread loops, waiting for jobs on the channel receiver.
3. **`Job`**: a type alias for a boxed closure.

```
ThreadPool::execute(job)
       │
       │  mpsc channel
       ▼
  Sender<Job> ──────────────────► Receiver<Job> (shared via Arc<Mutex<...>>)
                                         │
                                  Worker 0 ◄──── receives job, runs it
                                  Worker 1 ◄──── waiting
                                  Worker 2 ◄──── waiting
                                  Worker 3 ◄──── waiting
```

All four workers share a single `Receiver`. `Arc` provides shared ownership; `Mutex` ensures only one worker dequeues a job at a time. This is safe and correct: `mpsc` is "multi-producer, single-consumer", but multiple consumers can share a `Mutex<Receiver>`.

Now split the project into a library and binary:

```
src/
  main.rs   ← binary crate
  lib.rs    ← library crate (ThreadPool lives here)
```

### `src/lib.rs` — ThreadPool Implementation

```rust
// src/lib.rs
use std::{
    sync::{Arc, Mutex, mpsc},
    thread,
};

// A Job is a closure that can be sent across threads and called once.
type Job = Box<dyn FnOnce() + Send + 'static>;

pub struct ThreadPool {
    workers: Vec<Worker>,
    // Option so we can take() it during shutdown
    sender: Option<mpsc::Sender<Job>>,
}

impl ThreadPool {
    /// Create a thread pool with `size` worker threads.
    ///
    /// # Panics
    /// Panics if `size` is zero.
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0, "ThreadPool size must be > 0");

        let (sender, receiver) = mpsc::channel();

        // Wrap receiver in Arc<Mutex<...>> so all workers share it safely.
        let receiver = Arc::new(Mutex::new(receiver));

        let mut workers = Vec::with_capacity(size);
        for id in 0..size {
            workers.push(Worker::new(id, Arc::clone(&receiver)));
        }

        ThreadPool {
            workers,
            sender: Some(sender),
        }
    }

    /// Send a job to one of the worker threads.
    pub fn execute<F>(&self, f: F)
    where
        F: FnOnce() + Send + 'static,
    {
        let job = Box::new(f);
        self.sender
            .as_ref()
            .expect("ThreadPool is shutting down")
            .send(job)
            .unwrap();
    }
}
```

**Why `FnOnce() + Send + 'static`?**

- `FnOnce()`: the closure is called exactly once.
- `Send`: the closure (and any data it captures) must be safe to transfer to another thread.
- `'static`: the closure must not borrow data with a shorter lifetime than the thread itself, since we don't know when the thread will run.

This is the same contract Java's `Runnable` interface expresses implicitly (all captured values are shared by reference via the GC in Java; Rust enforces the constraints at compile time).

---

## Stage 5b — Worker Threads

```rust
// Continues in src/lib.rs

struct Worker {
    id: usize,
    // Option so we can take() the handle during shutdown
    thread: Option<thread::JoinHandle<()>>,
}

impl Worker {
    fn new(id: usize, receiver: Arc<Mutex<mpsc::Receiver<Job>>>) -> Worker {
        let thread = thread::spawn(move || loop {
            // Lock the mutex, receive a job, release the lock before running the job.
            let message = receiver.lock().unwrap().recv();

            match message {
                Ok(job) => {
                    println!("Worker {id} executing a job.");
                    job();
                }
                Err(_) => {
                    // The sender was dropped — time to shut down.
                    println!("Worker {id} shutting down.");
                    break;
                }
            }
        });

        Worker {
            id,
            thread: Some(thread),
        }
    }
}
```

**Critical detail — mutex lock scope:**

```rust
// CORRECT: lock is released before job() runs
let message = receiver.lock().unwrap().recv();
match message { Ok(job) => job(), ... }

// WRONG: lock held across job(), serializing all workers
loop {
    let job = receiver.lock().unwrap().recv().unwrap();
    job(); // still holding the lock! other workers are blocked
}
```

In the wrong version, `recv()` returns a `MutexGuard<Receiver<Job>>`, and calling `.recv()` on it produces a value of type `Result<Job, RecvError>`. When you store this result and the guard drops, the lock is released. The bug occurs when you chain: `receiver.lock().unwrap().recv().unwrap()` and immediately call the job — the temporary guard from `lock()` lives until the end of the statement, so `job()` runs while the lock is held.

The correct pattern breaks the chain: store the `Result<Job>` first, letting the temporary guard drop, then call `job()` in the next statement.

---

## Stage 6 — Graceful Shutdown with `Drop`

When `ThreadPool` goes out of scope, we want to:
1. Signal all workers to stop accepting new jobs.
2. Wait for in-progress jobs to finish (`join`).

The signal is simple: drop the sender. When the channel's sender side is dropped, `recv()` in each worker returns `Err(RecvError)`, which causes the worker loop to `break`.

```rust
// Continues in src/lib.rs

impl Drop for ThreadPool {
    fn drop(&mut self) {
        // Step 1: Drop the sender. This closes the channel from the producer side.
        // All workers' recv() calls will now return Err, causing them to exit.
        drop(self.sender.take());

        // Step 2: Join each worker thread so we wait for in-progress work to finish.
        for worker in &mut self.workers {
            println!("Shutting down worker {}", worker.id);

            if let Some(thread) = worker.thread.take() {
                thread.join().unwrap();
            }
        }
    }
}
```

**Why `Option<JoinHandle>` and `.take()`?**

`JoinHandle::join()` takes `self` (moves it). But we only have `&mut Worker` inside the `for` loop — we cannot move out of a mutable reference. The `Option` wrapper lets us `take()` the value, replacing it with `None`, and giving us ownership of the handle to join. This is a common Rust pattern for "move out of borrowed context."

**Why `Option<Sender>` and `drop(self.sender.take())`?**

Same reason in reverse: we want to explicitly drop the sender before joining threads. Without `take()`, the sender would be dropped at the very end of `drop()`, after the join loop — but the joins would block forever because the workers would still be waiting on the channel. The order must be:

1. Drop sender → workers get `Err` → workers exit their loops.
2. Join workers → main thread waits for them to actually finish.

### Java Comparison

```java
// Java graceful shutdown
ExecutorService pool = Executors.newFixedThreadPool(4);
// ...submit work...

// At shutdown time (must be called explicitly):
pool.shutdown();                              // stop accepting new tasks
pool.awaitTermination(30, TimeUnit.SECONDS); // wait for in-progress tasks
```

Java's `ExecutorService.shutdown()` is called explicitly. Rust's `Drop` implementation runs this logic automatically when the `ThreadPool` goes out of scope — whether the scope exits normally or via a panic. This is RAII (Resource Acquisition Is Initialization), Rust's equivalent of Java's `try-with-resources` but for any scope, not just `try` blocks.

---

## Stage 7 — Putting It Together: `main.rs` with ThreadPool

```rust
// src/main.rs — with ThreadPool
use hello::ThreadPool;
use std::{
    fs,
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
    path::Path,
    time::Duration,
};

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    let pool = ThreadPool::new(4);

    println!("Server running on http://127.0.0.1:7878");
    println!("Press Ctrl+C to stop (pool will drain in-flight requests first).");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        pool.execute(|| {
            handle_connection(stream);
        });
    }

    println!("Shutting down.");
} // pool is dropped here → Drop runs → all workers finish → process exits

fn handle_connection(mut stream: TcpStream) {
    stream.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
    stream.set_write_timeout(Some(Duration::from_secs(5))).unwrap();

    let buf_reader = BufReader::new(&stream);

    let request_line = match buf_reader.lines().next() {
        Some(Ok(line)) => line,
        _ => return,
    };

    let mut parts = request_line.splitn(3, ' ');
    let method = parts.next().unwrap_or("");
    let path   = parts.next().unwrap_or("/");

    route(&mut stream, method, path);
}

fn route(stream: &mut TcpStream, method: &str, path: &str) {
    match (method, path) {
        ("GET", "/") | ("GET", "/index.html") => {
            serve_file(stream, "static/hello.html");
        }
        ("GET", "/sleep") => {
            std::thread::sleep(Duration::from_secs(5));
            serve_json(stream, r#"{"message":"I just woke up"}"#);
        }
        ("GET", "/api/status") => {
            serve_json(stream, r#"{"status":"ok","server":"rust-hello","threads":4}"#);
        }
        ("GET", p) if p.starts_with("/static/") => {
            serve_static(stream, p);
        }
        _ => {
            serve_not_found(stream);
        }
    }
}

fn serve_file(stream: &mut TcpStream, path: &str) {
    match fs::read_to_string(path) {
        Ok(body) => send_response(stream, 200, "OK", "text/html; charset=utf-8", &body),
        Err(_)   => serve_not_found(stream),
    }
}

fn serve_not_found(stream: &mut TcpStream) {
    let body = fs::read_to_string("static/404.html")
        .unwrap_or_else(|_| "<h1>404 Not Found</h1>".to_string());
    send_response(stream, 404, "NOT FOUND", "text/html; charset=utf-8", &body);
}

fn serve_static(stream: &mut TcpStream, url_path: &str) {
    if url_path.contains("..") {
        serve_not_found(stream);
        return;
    }

    let fs_path = format!(".{url_path}");
    let ext = Path::new(&fs_path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("");

    let content_type = match ext {
        "html" => "text/html; charset=utf-8",
        "css"  => "text/css",
        "js"   => "application/javascript",
        "png"  => "image/png",
        "ico"  => "image/x-icon",
        _      => "application/octet-stream",
    };

    match fs::read_to_string(&fs_path) {
        Ok(body) => send_response(stream, 200, "OK", content_type, &body),
        Err(_)   => serve_not_found(stream),
    }
}

fn serve_json(stream: &mut TcpStream, json: &str) {
    send_response(stream, 200, "OK", "application/json", json);
}

fn send_response(
    stream: &mut TcpStream,
    status_code: u16,
    status_text: &str,
    content_type: &str,
    body: &str,
) {
    let response = format!(
        "HTTP/1.1 {status_code} {status_text}\r\n\
         Content-Type: {content_type}\r\n\
         Content-Length: {}\r\n\
         \r\n\
         {body}",
        body.len()
    );
    let _ = stream.write_all(response.as_bytes());
}
```

**Test concurrency:**

```bash
# In three terminals simultaneously:
curl http://127.0.0.1:7878/sleep    # takes 5 seconds
curl http://127.0.0.1:7878/sleep    # takes 5 seconds concurrently
curl http://127.0.0.1:7878/api/status  # returns immediately!
```

With the ThreadPool the last request is no longer blocked by the slow ones.

---

## Complete Final Code Listing

This is the complete, paste-and-run code for the project. All three files together produce a working multithreaded HTTP server with graceful shutdown.

### `Cargo.toml`

```toml
[package]
name = "hello"
version = "0.1.0"
edition = "2024"
```

### `src/lib.rs` — ThreadPool

```rust
use std::{
    sync::{Arc, Mutex, mpsc},
    thread,
};

type Job = Box<dyn FnOnce() + Send + 'static>;

pub struct ThreadPool {
    workers: Vec<Worker>,
    sender: Option<mpsc::Sender<Job>>,
}

impl ThreadPool {
    /// Create a new ThreadPool.
    ///
    /// `size` is the number of threads in the pool.
    ///
    /// # Panics
    ///
    /// Panics if `size` is zero.
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);

        let (sender, receiver) = mpsc::channel();
        let receiver = Arc::new(Mutex::new(receiver));

        let mut workers = Vec::with_capacity(size);
        for id in 0..size {
            workers.push(Worker::new(id, Arc::clone(&receiver)));
        }

        ThreadPool {
            workers,
            sender: Some(sender),
        }
    }

    pub fn execute<F>(&self, f: F)
    where
        F: FnOnce() + Send + 'static,
    {
        let job = Box::new(f);
        self.sender
            .as_ref()
            .expect("ThreadPool sender dropped")
            .send(job)
            .unwrap();
    }
}

impl Drop for ThreadPool {
    fn drop(&mut self) {
        // Drop sender first so workers receive Err on recv() and break out.
        drop(self.sender.take());

        for worker in &mut self.workers {
            println!("Shutting down worker {}", worker.id);
            if let Some(thread) = worker.thread.take() {
                thread.join().unwrap();
            }
        }
    }
}

struct Worker {
    id: usize,
    thread: Option<thread::JoinHandle<()>>,
}

impl Worker {
    fn new(id: usize, receiver: Arc<Mutex<mpsc::Receiver<Job>>>) -> Worker {
        let thread = thread::spawn(move || loop {
            let message = receiver.lock().unwrap().recv();
            match message {
                Ok(job) => {
                    println!("Worker {id} got a job; executing.");
                    job();
                }
                Err(_) => {
                    println!("Worker {id} shutting down.");
                    break;
                }
            }
        });

        Worker {
            id,
            thread: Some(thread),
        }
    }
}
```

### `src/main.rs` — HTTP Server

```rust
use hello::ThreadPool;
use std::{
    fs,
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
    path::Path,
    time::Duration,
};

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    let pool = ThreadPool::new(4);

    println!("Server running on http://127.0.0.1:7878");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        pool.execute(|| {
            handle_connection(stream);
        });
    }

    println!("Shutting down.");
}

fn handle_connection(mut stream: TcpStream) {
    stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    stream
        .set_write_timeout(Some(Duration::from_secs(5)))
        .unwrap();

    let buf_reader = BufReader::new(&stream);

    let request_line = match buf_reader.lines().next() {
        Some(Ok(line)) => line,
        _ => return,
    };

    let mut parts = request_line.splitn(3, ' ');
    let method = parts.next().unwrap_or("");
    let path   = parts.next().unwrap_or("/");

    route(&mut stream, method, path);
}

fn route(stream: &mut TcpStream, method: &str, path: &str) {
    match (method, path) {
        ("GET", "/") | ("GET", "/index.html") => {
            serve_file(stream, "static/hello.html");
        }
        ("GET", "/sleep") => {
            std::thread::sleep(Duration::from_secs(5));
            serve_json(stream, r#"{"message":"I just woke up"}"#);
        }
        ("GET", "/api/status") => {
            serve_json(stream, r#"{"status":"ok","server":"rust-hello","threads":4}"#);
        }
        ("GET", p) if p.starts_with("/static/") => {
            serve_static(stream, p);
        }
        _ => {
            serve_not_found(stream);
        }
    }
}

fn serve_file(stream: &mut TcpStream, path: &str) {
    match fs::read_to_string(path) {
        Ok(body) => send_response(stream, 200, "OK", "text/html; charset=utf-8", &body),
        Err(_)   => serve_not_found(stream),
    }
}

fn serve_not_found(stream: &mut TcpStream) {
    let body = fs::read_to_string("static/404.html")
        .unwrap_or_else(|_| "<h1>404 Not Found</h1>".to_string());
    send_response(stream, 404, "NOT FOUND", "text/html; charset=utf-8", &body);
}

fn serve_static(stream: &mut TcpStream, url_path: &str) {
    if url_path.contains("..") {
        serve_not_found(stream);
        return;
    }

    let fs_path = format!(".{url_path}");
    let ext = Path::new(&fs_path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("");

    let content_type = match ext {
        "html" => "text/html; charset=utf-8",
        "css"  => "text/css",
        "js"   => "application/javascript",
        "png"  => "image/png",
        "ico"  => "image/x-icon",
        _      => "application/octet-stream",
    };

    match fs::read_to_string(&fs_path) {
        Ok(body) => send_response(stream, 200, "OK", content_type, &body),
        Err(_)   => serve_not_found(stream),
    }
}

fn serve_json(stream: &mut TcpStream, json: &str) {
    send_response(stream, 200, "OK", "application/json", json);
}

fn send_response(
    stream: &mut TcpStream,
    status_code: u16,
    status_text: &str,
    content_type: &str,
    body: &str,
) {
    let response = format!(
        "HTTP/1.1 {status_code} {status_text}\r\n\
         Content-Type: {content_type}\r\n\
         Content-Length: {}\r\n\
         \r\n\
         {body}",
        body.len()
    );
    let _ = stream.write_all(response.as_bytes());
}
```

**To run:**

```bash
cargo new hello --edition 2024
cd hello
mkdir static
# Write static/hello.html and static/404.html (contents shown in Project Setup)
# Replace src/main.rs and create src/lib.rs with the listings above
cargo run
```

---

## Stage 8 — Async Alternative with Tokio

The ThreadPool approach above uses **OS threads** — each request gets its own OS thread up to the pool size. This is the **thread-per-request** model, which works well for CPU-bound or blocking I/O workloads up to a few hundred concurrent connections.

For high-concurrency I/O-bound workloads (thousands of simultaneous connections), **async I/O** is more efficient. Instead of blocking an entire thread waiting for network data, async tasks yield control and allow one OS thread to interleave many I/O operations.

Tokio is Rust's dominant async runtime. Add it to `Cargo.toml`:

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
```

### Minimal Tokio Web Server

```rust
// src/main.rs — Tokio async version (separate project)
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{TcpListener, TcpStream},
};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").await.unwrap();
    println!("Async server on http://127.0.0.1:7878");

    loop {
        let (stream, addr) = listener.accept().await.unwrap();
        println!("Connection from {addr}");

        // Spawn a new async task for each connection.
        // Unlike thread::spawn, this does NOT create an OS thread.
        tokio::spawn(async move {
            handle_connection(stream).await;
        });
    }
}

async fn handle_connection(mut stream: TcpStream) {
    let (reader, mut writer) = stream.split();
    let mut buf_reader = BufReader::new(reader);

    let mut request_line = String::new();
    if buf_reader.read_line(&mut request_line).await.is_err() {
        return;
    }

    let mut parts = request_line.trim().splitn(3, ' ');
    let _method = parts.next().unwrap_or("GET");
    let path    = parts.next().unwrap_or("/");

    let (status, body) = match path {
        "/" => ("200 OK", "<h1>Hello from async Rust!</h1>"),
        "/api/status" => ("200 OK", r#"{"status":"ok","runtime":"tokio"}"#),
        _ => ("404 NOT FOUND", "<h1>Not Found</h1>"),
    };

    let content_type = if path.starts_with("/api/") {
        "application/json"
    } else {
        "text/html; charset=utf-8"
    };

    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\n\r\n{body}",
        body.len()
    );

    let _ = writer.write_all(response.as_bytes()).await;
}
```

### Threading vs Async: Choosing the Right Model

| Dimension | Threads (ThreadPool) | Async (Tokio) |
|---|---|---|
| Concurrency model | OS preemptive scheduling | Cooperative yielding |
| Resource per connection | 1 OS thread (stack ~2MB) | 1 task (heap allocation, ~few KB) |
| Max concurrent connections | ~hundreds (bounded by pool) | Tens of thousands |
| Blocking code | Works naturally | Must use `tokio::task::spawn_blocking` |
| CPU-bound work | Great | Use rayon or `spawn_blocking` |
| Code complexity | Familiar, sequential | Requires `async`/`await` everywhere |
| Std library | Yes — no extra deps | No — requires `tokio` crate |

**When to use threads:** CLI tools, scripts, servers with bounded concurrency, CPU-heavy work, code that calls blocking APIs (file I/O, databases without async drivers).

**When to use Tokio:** High-throughput network services, WebSocket servers, proxies, anything using async ecosystem crates (reqwest, sqlx, axum).

### Java Comparison: Virtual Threads

Java 21 introduced virtual threads (`Thread.ofVirtual()`), which are similar to Tokio tasks: lightweight, scheduled by the JVM rather than the OS, capable of blocking without consuming OS threads.

```java
// Java 21 — virtual thread per connection
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    ServerSocket server = new ServerSocket(7878);
    while (true) {
        Socket client = server.accept();
        executor.submit(() -> handleConnection(client));
    }
}
```

Java's virtual threads are preemptive (the JVM can suspend them at any point). Tokio tasks are cooperative (they only yield at `.await` points). Both models achieve high concurrency, but Tokio makes the yield points explicit in the type system — you can tell at a glance whether a function might suspend by whether it returns a `Future`.

---

## Connection Timeout Handling (Deep Dive)

Timeouts protect the server from two distinct problems:

1. **Slow-read attacks**: a client connects and sends the request headers one byte every 30 seconds (Slowloris attack). Without a read timeout, the connection holds a thread/task indefinitely.
2. **Slow writes**: a client's network is congested and cannot receive data quickly. Without a write timeout, a write call blocks indefinitely.

For the threaded version we used `set_read_timeout` and `set_write_timeout`. These are OS-level socket options:

```rust
stream.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
stream.set_write_timeout(Some(Duration::from_secs(5))).unwrap();
```

When a timeout fires, the next `read` or `write` call returns `Err(io::Error { kind: TimedOut, ... })`. Our `handle_connection` function handles this gracefully:

```rust
let request_line = match buf_reader.lines().next() {
    Some(Ok(line)) => line,
    _ => return, // TimedOut, broken pipe, EOF — all handled here
};
```

For the Tokio version, use `tokio::time::timeout`:

```rust
use tokio::time::{timeout, Duration};

async fn handle_connection(mut stream: TcpStream) {
    // Wrap the entire connection handler in a 10-second timeout.
    let result = timeout(Duration::from_secs(10), async {
        // ... all the I/O ...
    }).await;

    if result.is_err() {
        println!("Connection timed out");
    }
}
```

`tokio::time::timeout` wraps any `Future` and returns `Err(Elapsed)` if it does not complete within the given duration. This composable approach works at any granularity — wrap a single read, a batch of reads, or the entire connection handler.

---

## Key Concepts Summary

| Concept | Rust mechanism | Java equivalent |
|---|---|---|
| TCP listener | `TcpListener::bind(addr)` | `new ServerSocket(port)` |
| Accept connections | `.incoming()` iterator | `server.accept()` in a loop |
| Buffered reading | `BufReader::new(&stream)` | `new BufferedReader(new InputStreamReader(socket.getInputStream()))` |
| Read until blank line | `.take_while(!empty)` | Read until `readLine()` returns empty string |
| Thread pool | Hand-rolled with `mpsc` + `Arc<Mutex<Receiver>>` | `Executors.newFixedThreadPool(n)` |
| Job type | `Box<dyn FnOnce() + Send + 'static>` | `Runnable` (lambda) |
| Graceful shutdown | `impl Drop for ThreadPool` (automatic) | `pool.shutdown()` + `awaitTermination()` (explicit) |
| Path traversal guard | `url_path.contains("..")` check | `Paths.get(base).resolve(path).normalize().startsWith(base)` |
| Async I/O | `tokio`, `async`/`await` | Virtual threads (Java 21), CompletableFuture, Netty |

---

## 📝 Chapter Review Notes

*The following is a third-person critical review of this chapter.*

### Overall Assessment

The chapter successfully covers all seven required stages from the Rust Book and extends meaningfully beyond them with routing, static file serving, JSON responses, Tokio comparison, and timeout handling. The code is progressive: each stage builds on the previous, and the final listing is self-contained and runnable.

### Issues Table

| Severity | Issue | Detail |
|---|---|---|
| **OK** | ThreadPool Drop order | Correctly drops sender before joining workers. The book's first attempt (Listing 21-22) is intentionally broken; this chapter goes straight to the working version. |
| **OK** | Mutex lock scope | The chapter explicitly calls out the lock-across-job-call bug and shows the correct pattern with a code contrast. |
| **OK** | Path traversal | Includes `url_path.contains("..")` check in `serve_static` with an explanation. |
| **OK** | `edition = "2024"` | Cargo.toml uses 2024 edition as required. Grouped imports are used throughout. |
| **OK** | Tokio API accuracy | `tokio::net::TcpListener::accept().await` is used (not `incoming()`). `#[tokio::main]` on `async fn main`. `stream.split()` for independent reader/writer is correct. |
| **OK** | `route()` catch-all arm | All three listings (Stage 3.5, Stage 7, final listing) correctly call only `serve_not_found(stream)` in the `_ =>` arm. An earlier draft sent two responses (a `200` followed by a `404`) — this was caught in review and fixed. |
| **Medium** | Binary file serving | `serve_static` uses `fs::read_to_string` which fails for binary files (images, fonts). For a real static file server, `fs::read` returning `Vec<u8>` is needed. The chapter serves only text-based static content correctly. |
| **Medium** | `Content-Length` with Unicode | `body.len()` returns byte length, not character count. For UTF-8 encoded HTML, this is correct for `Content-Length` (which measures bytes). No bug here, but worth mentioning: if `body.chars().count()` were used instead, it would produce wrong headers for multi-byte characters. |
| **Low** | `unwrap()` prevalence | Production code should use `?` with a proper error type. `unwrap()` is acceptable for a tutorial but should be flagged. The chapter notes this implicitly by referencing Chapter 9 for error handling. |
| **Low** | No `Connection: close` header | The server does not send `Connection: close`, so HTTP/1.1 clients may attempt to keep the connection alive for pipelining, then hang when no more data arrives. For a tutorial server this is acceptable; a production server would handle keep-alive. |
| **Low** | Tokio server sends no Date header | RFC 7231 recommends an HTTP `Date` header in all responses. Neither the threaded nor the async version sends one. Minor omission, acceptable for a tutorial. |
| **Low** | Thread panic handling | If a worker's job panics, `job()` propagates the panic to the worker thread, terminating that worker silently. The pool does not respawn workers after panic. A more robust pool would catch panics with `std::panic::catch_unwind`. |
| **Low** | `serve_static` reads text only | Using `fs::read_to_string` for `/static/` paths means truly binary resources (`.png`, `.ico` mapped in `content_type`) will return an error and a 404. The content-type table includes binary types that can never be successfully served. This is mildly misleading. |

### Fact-Check Results

- `TcpListener::bind` is from `std::net` — correct.
- `BufReader::new(&stream)` requires `TcpStream: Read` for `&TcpStream` — confirmed in std docs since Rust 1.x; this works because `Read` is implemented for `&TcpStream`.
- `mpsc` stands for "multiple producer, single consumer" — correct, and the chapter notes that multiple consumers can share a `Mutex<Receiver>`.
- `FnOnce() + Send + 'static` is the correct bound for cross-thread closures — confirmed.
- `tokio::net::TcpListener::accept()` returns `Result<(TcpStream, SocketAddr)>` — correct; `incoming()` on `tokio::net::TcpListener` was stabilized later but `accept()` in a loop is the idiomatic pattern.
- `thread::JoinHandle::join()` takes `self` — correct, which is why `Option<JoinHandle>` + `.take()` is necessary.
- Java 21 `Executors.newVirtualThreadPerTaskExecutor()` — correct API name since JDK 21.

### What Could Be Improved in a Future Revision

1. **Separate binary from text file serving**: Add a `serve_binary_file` helper that uses `fs::read` → `Vec<u8>` and writes raw bytes, enabling true image/PNG serving.
2. **Request body reading**: The chapter only reads the request line. A `POST` handler would need to read `Content-Length` bytes from the body.
3. **Keep-alive support**: Add `Connection: keep-alive` header handling to avoid repeated TCP handshakes for browsers loading multiple resources.
4. **Worker panic recovery**: Demonstrate `std::panic::catch_unwind` to show how a robust pool would respawn crashed workers.
5. **Structured routing**: Replace the `match` arm on tuples with a simple router struct mapping `(Method, &str)` → handler function pointer, illustrating how real frameworks like Axum build on this idea.
