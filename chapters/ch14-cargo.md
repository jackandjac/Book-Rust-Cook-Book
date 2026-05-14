# Chapter 14: More About Cargo and Crates.io

> **Cookbook Philosophy:** The official Rust book gives you the "what" and "why." This cookbook gives you the "how" — dense with runnable examples, real-world patterns, and the mistakes beginners commonly make.

---

## Maven/Gradle vs. Cargo — At a Glance

Java projects usually split build tooling across Maven `pom.xml` profiles, Gradle build types, Nexus/Artifactory for publishing, and Javadoc generation as a separate step. In Rust, Cargo handles all of it.

| Java / Maven / Gradle                          | Rust / Cargo equivalent                          |
|------------------------------------------------|--------------------------------------------------|
| Maven `<profiles>` or Gradle build variants    | `[profile.dev]` / `[profile.release]`            |
| `mvn deploy` / `gradle publish`                | `cargo publish`                                  |
| Nexus / Artifactory / Maven Central            | crates.io                                        |
| Multi-module Maven / Gradle subprojects        | Cargo workspaces                                 |
| `mvn install` for local tools                  | `cargo install`                                  |
| Javadoc (`/** ... */`)                         | Doc comments (`///`, `//!`) + `cargo doc`        |
| Maven classifier / Gradle feature variants     | Cargo feature flags                              |
| `mvn dependency:tree`                          | `cargo tree`                                     |

---

## 14.1 Release Profiles

Cargo defines two built-in profiles. `cargo build` uses `dev`; `cargo build --release` uses `release`. Each has independent defaults that you can override.

### Default profile settings

```toml
# Cargo.toml — these are the defaults; you only need to write what you change.

[profile.dev]
opt-level = 0       # no optimization → fast compile, slow runtime
debug = true        # include debug info
lto = false         # link-time optimization off
codegen-units = 256 # max parallelism → faster compile
panic = "unwind"    # stack unwinding on panic

[profile.release]
opt-level = 3       # maximum optimization → slow compile, fast runtime
debug = false       # strip debug info → smaller binary
lto = false         # LTO off by default (thin LTO available)
codegen-units = 16  # less parallelism → better optimization
panic = "unwind"    # can override to "abort" to shrink binary
```

**Java comparison:** This maps to Maven's `<profiles>` section or Gradle's `debug` vs `release` build types. Unlike Maven, Cargo profiles affect the compiler itself (LLVM opt passes, debug symbol generation) rather than just which resources or classpath entries are active.

### Commonly tuned settings

| Setting           | Values                            | When to change                                               |
|-------------------|-----------------------------------|--------------------------------------------------------------|
| `opt-level`       | `0`, `1`, `2`, `3`, `"s"`, `"z"` | `"s"`/`"z"` for size-optimized embedded/WASM builds         |
| `debug`           | `true`, `false`, `0`–`2`         | `debug = 1` gives line numbers without full DWARF overhead   |
| `lto`             | `false`, `"thin"`, `true`        | `"thin"` gives most LTO gains with much shorter link time    |
| `codegen-units`   | `1`–N                             | `1` in release for maximum optimization; costs link time     |
| `panic`           | `"unwind"`, `"abort"`            | `"abort"` shrinks binary; removes `catch_unwind` capability  |

### Example: a tuned release profile

```toml
[profile.release]
opt-level = 3
lto = "thin"
codegen-units = 1
strip = true        # strip symbols (Rust 1.59+)
```

### Custom profiles

Any `[profile.name]` that is not `dev`, `release`, `test`, or `bench` must declare `inherits`:

```toml
# A profile for profiling: full optimization but with debug symbols retained.
[profile.release-with-debug]
inherits = "release"
debug = true
```

Build with `cargo build --profile release-with-debug`. The `inherits` field is **required** for custom profiles — omitting it is a compile error.

> **Gotcha:** The built-in `bench` profile inherits from `release`. The built-in `test` profile inherits from `dev`. You can override either without `inherits`, but custom names always need it.

---

## 14.2 Publishing to Crates.io

### Documentation comments

Rust has two styles of documentation comment, both rendered as HTML by `cargo doc`.

```rust,no_run
//! # my_math
//!
//! `my_math` provides precise arithmetic utilities.
//! The `//!` style documents the *containing* item — the crate or module.

/// Adds one to the number given.
///
/// # Examples
///
/// ```
/// let result = my_math::add_one(5);
/// assert_eq!(result, 6);
/// ```
///
/// # Panics
///
/// This function never panics.
///
/// # Errors
///
/// This function returns a plain value, not a `Result`.
pub fn add_one(x: i32) -> i32 {
    x + 1
}
```

**Standard doc sections** (Markdown `# Heading` inside `///`):

| Section     | Purpose                                                        |
|-------------|----------------------------------------------------------------|
| `Examples`  | Runnable code that documents the happy path                    |
| `Panics`    | Conditions under which the function panics                     |
| `Errors`    | For `Result`-returning functions: what error variants to expect |
| `Safety`    | Required for `unsafe fn`; explains invariants the caller must uphold |

**Java comparison:** JavaDoc `/** ... */` blocks are not compiled or run. Rust doc comments inside ` ``` ` fences are **compiled and executed as tests** by `cargo test --doc`. If you rename a parameter and forget to update the example, the doc test catches it.

### Running doc tests

```bash
cargo doc --open          # build HTML docs and open in browser
cargo test --doc          # run only doc tests
cargo test                # runs unit tests, integration tests, AND doc tests
```

Hiding boilerplate lines from rendered docs (still compiled):

```rust,no_run
/// ```
/// # use my_math::add_one;   // compiled but hidden in HTML
/// assert_eq!(add_one(2), 3);
/// ```
```

### Hiding implementation details

```rust,no_run
#[doc(hidden)]
pub fn internal_helper() {}   // still fully pub (callable by external crates); excluded from rustdoc

/// Use `#[doc = "..."]` for programmatically generated doc strings.
#[doc = "Returns the answer to everything."]
pub fn the_answer() -> u32 { 42 }
```

### Cleaning up the public API with `pub use`

Deep module hierarchies are useful internally but painful for callers. `pub use` re-exports items at the crate root.

```rust,no_run
// src/lib.rs
//! # art
//! A library for modeling artistic concepts.

pub use self::kinds::PrimaryColor;
pub use self::kinds::SecondaryColor;
pub use self::utils::mix;

pub mod kinds {
    /// The primary colors in the RYB color model.
    #[derive(Debug, PartialEq, Clone, Copy)]
    pub enum PrimaryColor { Red, Yellow, Blue }

    #[derive(Debug, PartialEq, Clone, Copy)]
    pub enum SecondaryColor { Orange, Green, Purple }
}

pub mod utils {
    use crate::kinds::{PrimaryColor, SecondaryColor};
    pub fn mix(_c1: PrimaryColor, _c2: PrimaryColor) -> SecondaryColor {
        SecondaryColor::Orange // placeholder
    }
}
```

Without `pub use`, callers write `use art::kinds::PrimaryColor`. With it, they write `use art::PrimaryColor`. The re-exports appear at the top of the rustdoc page under "Re-exports".

### Required Cargo.toml metadata before publishing

```toml
[package]
name        = "my_math"
version     = "0.1.0"
edition     = "2024"
description = "Precise arithmetic utilities for Rust programs."
license     = "MIT OR Apache-2.0"    # SPDX identifier
# license-file = "LICENSE"           # alternative: path to custom license
authors     = ["Alice <alice@example.com>"]
repository  = "https://github.com/alice/my_math"
keywords    = ["math", "arithmetic"]     # max 5, lowercase
categories  = ["mathematics"]           # from https://crates.io/category_slugs
readme      = "README.md"
```

**Required fields for `cargo publish`:** `name`, `version`, `description`, `license` (or `license-file`). All other fields are strongly recommended for discoverability but are not enforced by Cargo.

### Semantic versioning for Rust crates

Rust crates follow [semver](https://semver.org/) strictly, and Cargo's dependency resolution depends on it.

| Change type                              | Version bump  | Example               |
|------------------------------------------|---------------|-----------------------|
| Bug fix, no API change                   | Patch `0.0.Z` | `1.2.3` → `1.2.4`    |
| Backward-compatible new feature          | Minor `0.Y.0` | `1.2.3` → `1.3.0`    |
| Breaking change (removed/renamed item)   | Major `X.0.0` | `1.2.3` → `2.0.0`    |

> **Note on `0.x` crates:** versions below `1.0.0` treat the minor version as the "major" for breaking-change purposes. `0.2.x` → `0.3.0` is considered a breaking change by convention.

### Publishing workflow

```bash
# 1. Create a crates.io account and log in (stores token in ~/.cargo/credentials.toml)
cargo login

# 2. Verify the package before actually uploading
cargo publish --dry-run

# 3. Publish (permanent — versions cannot be overwritten or deleted)
cargo publish
```

Publishing is **permanent**. You cannot unpublish a version, and you cannot overwrite it. If you accidentally commit a secret, rotate the secret immediately — yanking does not remove the code.

### Yanking a broken version

Yanking prevents new `Cargo.lock` files from selecting a version without blocking existing resolved users.

```bash
cargo yank --vers 1.0.1          # block new resolutions of 1.0.1
cargo yank --vers 1.0.1 --undo  # reverse the yank
```

**Yanking does not delete code.** Projects that already have `1.0.1` in `Cargo.lock` continue to build. Only new dependency resolution is blocked.

---

## 14.3 Cargo Workspaces

A workspace is a set of related crates that share one `Cargo.lock` and one `target/` directory.

**Java comparison:** This is Cargo's answer to Maven multi-module projects or Gradle multi-project builds. One top-level build descriptor, member sub-projects, shared dependency lockfile.

### Practical workspace: `core`, `cli`, and `web`

This example workspace will be referenced throughout §14.6 (feature flags) and §14.7 (tooling).

```
myapp/
├── Cargo.toml          ← workspace root (no [package] section)
├── Cargo.lock          ← single lock file for all members
├── target/             ← single output directory
├── core/               ← shared domain logic (library crate)
│   ├── Cargo.toml
│   └── src/lib.rs
├── cli/                ← command-line binary
│   ├── Cargo.toml
│   └── src/main.rs
└── web/                ← HTTP service binary
    ├── Cargo.toml
    └── src/main.rs
```

**Workspace root `Cargo.toml`:**

```toml
[workspace]
resolver = "3"          # required for Rust 2024 edition workspaces
members  = ["core", "cli", "web"]

# --- Shared dependency versions (Rust 1.64+) ---
[workspace.dependencies]
serde       = { version = "1", features = ["derive"] }
tokio       = { version = "1", features = ["full"] }
anyhow      = "1"
tracing     = "0.1"

# --- Shared package metadata (Rust 1.64+) ---
[workspace.package]
version = "0.1.0"
edition = "2024"
license = "MIT OR Apache-2.0"
authors = ["Alice <alice@example.com>"]
```

**`core/Cargo.toml` — inheriting from the workspace:**

```toml
[package]
name    = "myapp-core"
version.workspace = true    # inherit from [workspace.package]
edition.workspace = true
license.workspace = true

[dependencies]
serde   = { workspace = true }   # version + features inherited
anyhow  = { workspace = true }
tracing = { workspace = true }
```

**`cli/Cargo.toml`:**

```toml
[package]
name    = "myapp-cli"
version.workspace = true
edition.workspace = true
license.workspace = true

[dependencies]
myapp-core = { path = "../core" }   # inter-crate dependency by path
anyhow     = { workspace = true }
```

**`web/Cargo.toml`:**

```toml
[package]
name    = "myapp-web"
version.workspace = true
edition.workspace = true
license.workspace = true

[dependencies]
myapp-core = { path = "../core" }
tokio      = { workspace = true }
anyhow     = { workspace = true }
```

**`core/src/lib.rs`:**

```rust,no_run
//! Shared domain logic for the myapp workspace.

use anyhow::Result;

/// A user in the system.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct User {
    pub id: u64,
    pub name: String,
}

/// Look up a user by ID (stub).
pub fn find_user(id: u64) -> Result<User> {
    Ok(User { id, name: format!("user_{id}") })
}
```

**`cli/src/main.rs`:**

```rust,no_run
use anyhow::Result;
use myapp_core::find_user;

fn main() -> Result<()> {
    let user = find_user(42)?;
    println!("Found: {:?}", user);
    Ok(())
}
```

### Workspace-level commands

```bash
# Build every member crate
cargo build

# Run a specific binary (must specify package when multiple binaries exist)
cargo run -p myapp-cli

# Test all crates in the workspace
cargo test

# Test only the core library
cargo test -p myapp-core

# Publish a single crate (each crate is published independently)
cargo publish -p myapp-core
```

All members share `Cargo.lock` — you cannot have two workspace members that require incompatible versions of the same dependency. This is the workspace's key constraint and key benefit.

---

## 14.4 `cargo install` — Installing Binary Tools

`cargo install` compiles a crate and puts the resulting binary in `~/.cargo/bin/`.

```bash
# Install ripgrep (a Rust-based grep replacement)
cargo install ripgrep    # installs as `rg`

# Install a specific version
cargo install ripgrep --version 14.1.1

# Upgrade (reinstall latest)
cargo install ripgrep --force
```

Binaries land in `~/.cargo/bin`. Add that to `PATH` if you haven't already:

```bash
# In ~/.zshrc or ~/.bashrc
export PATH="$HOME/.cargo/bin:$PATH"
```

`cargo install` only works for crates that have a binary target (`src/main.rs` or `[[bin]]` entry in `Cargo.toml`). It is not a general system package manager — it compiles from source every time.

**Java comparison:** There is no close Java equivalent. `mvn install` installs a JAR to the local Maven repository for use as a dependency, not as a runnable tool. The closest analog is installing a CLI tool via `pip install` in Python's ecosystem.

---

## 14.5 Extending Cargo with Custom Subcommands

Any executable in `PATH` named `cargo-something` can be invoked as `cargo something`:

```bash
# Install a third-party Cargo extension
cargo install cargo-edit       # adds: cargo add / cargo remove / cargo upgrade

# Now usable as a Cargo subcommand
cargo add serde --features derive
cargo remove serde
```

```bash
# List all available subcommands (built-in and custom)
cargo --list
```

The extensions covered in §14.7 follow this same pattern — they are all `cargo-*` binaries installed via `cargo install`.

---

## 14.6 Feature Flags and Conditional Compilation

Feature flags let a single crate compile differently depending on what the user opts into. The classic use case is optional `serde` support.

**Java comparison:** This maps to Maven profiles (`-Pserde`) or Gradle feature variants, but is first-class in Cargo — feature resolution is baked into the dependency solver, not bolted on.

### Declaring features in `core/Cargo.toml`

```toml
[package]
name    = "myapp-core"
version = "0.1.0"
edition = "2024"

[dependencies]
# serde is optional — only compiled when the "serde" feature is requested
serde = { version = "1", features = ["derive"], optional = true }

[features]
# The modern `dep:` form (Rust 1.60+) avoids a namespace collision where
# the feature name and the crate name would otherwise shadow each other.
serde = ["dep:serde"]
```

> **Important:** Using `serde = ["dep:serde"]` instead of the old `serde = ["serde"]` form ensures the `serde` feature name does not implicitly create a `serde` dependency. Always prefer `dep:` for optional dependencies in new code.

### Using `#[cfg(feature = "...")]` in code

```rust,no_run
// core/src/lib.rs

#[derive(Debug, Clone)]
// This derive is only emitted when the "serde" feature is active.
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct User {
    pub id: u64,
    pub name: String,
}

/// Look up a user by ID (stub; compilation varies by active features).
pub fn find_user(id: u64) -> User {
    User { id, name: format!("user_{id}") }
}
```

### Enabling features from a dependent crate

```toml
# cli/Cargo.toml
[dependencies]
myapp-core = { path = "../core", features = ["serde"] }
```

Or from the command line:

```bash
cargo build -p myapp-core --features serde
cargo test  -p myapp-core --all-features   # enable every declared feature
cargo build --no-default-features          # disable all default features
```

### Default features

```toml
[features]
default = ["serde"]     # enabled unless the user opts out with --no-default-features
serde   = ["dep:serde"]
```

Keep `default` minimal. Library crates that pull in many default features make it hard for downstream users to slim down their binary.

---

## 14.7 Useful Cargo Tooling

### `cargo add` and `cargo remove` (Cargo 1.62+)

Built into modern Cargo — no install required:

```bash
cargo add serde --features derive          # adds serde with the derive feature
cargo add tokio --features full            # adds tokio with all features
cargo add --dev tempfile                   # adds to [dev-dependencies]
cargo add --build cc                       # adds to [build-dependencies]
cargo remove serde                         # removes from Cargo.toml
```

### `cargo tree` — dependency inspection

```bash
cargo tree                              # full dependency tree
cargo tree -p myapp-core               # tree for one workspace member
cargo tree --invert serde              # which crates pull in serde?
cargo tree --duplicates                # show dependencies with multiple versions
```

`cargo tree --duplicates` is invaluable when diagnosing why your binary is larger than expected or why you have two versions of the same crate linked in.

### `cargo audit` — security vulnerability scanning

```bash
cargo install cargo-audit
cargo audit                    # checks Cargo.lock against RustSec advisory database
cargo audit fix                # attempts automatic version bumps for known CVEs
```

Equivalent to running `npm audit` or OWASP dependency-check in a Java project. Integrate into CI alongside `cargo test`.

### `cargo expand` — macro expansion

```bash
cargo install cargo-expand
cargo expand                   # print fully macro-expanded source to stdout
cargo expand --bin myapp-cli   # expand a specific binary
```

When a procedural macro produces a confusing error, `cargo expand` shows you exactly what code was generated. Essential for debugging `derive` macros and `tokio::main`.

### `cargo flamegraph` — profiling

```bash
cargo install flamegraph
# On Linux (requires perf):
cargo flamegraph --bin myapp-cli -- --some-arg
# On macOS (requires DTrace):
sudo cargo flamegraph --bin myapp-cli -- --some-arg
```

Produces a `flamegraph.svg` in the current directory showing where CPU time is spent. Always profile with `--release` builds — dev-mode code is unoptimized and produces misleading profiles.

### Summary of essential tools

| Tool              | Install                      | Purpose                                      |
|-------------------|------------------------------|----------------------------------------------|
| `cargo add`       | built-in (Cargo 1.62+)       | Add/remove dependencies from the CLI         |
| `cargo tree`      | built-in                     | Inspect dependency graph                     |
| `cargo audit`     | `cargo install cargo-audit`  | Security advisory scanning                   |
| `cargo expand`    | `cargo install cargo-expand` | Macro expansion debugging                    |
| `cargo flamegraph`| `cargo install flamegraph`   | CPU flamegraph profiling                     |
| `cargo clippy`    | `rustup component add clippy`| Lints beyond rustc warnings                  |
| `cargo fmt`       | `rustup component add rustfmt`| Opinionated code formatting                 |

---

## 14.8 `.cargo/config.toml`

Project-level Cargo configuration lives in `.cargo/config.toml` (formerly `.cargo/config`). Settings here override Cargo defaults for everyone who clones the repository.

```toml
# .cargo/config.toml

[build]
# Use the faster mold linker on Linux
# linker = "clang"
# rustflags = ["-C", "link-arg=-fuse-ld=mold"]

# Set the target directory (useful in monorepos to share a single cache)
# target-dir = "/tmp/cargo-target"

[alias]
# Custom shortcuts: `cargo t` → `cargo test`
t   = "test"
b   = "build"
rr  = "run --release"
# Run clippy and tests in one shot
ci  = "hack --each-feature -- test"

[net]
retry = 3    # retry registry requests on transient network failure

[profile.release]
# Can also be set here instead of in Cargo.toml (project settings win)
lto = "thin"
```

> **Scope:** `.cargo/config.toml` in the project root affects only that project. A file in `~/.cargo/config.toml` affects all Cargo invocations for your user. Never commit user-level credentials or machine-specific paths to the project config.

---

## 14.9 Quick Reference

### Profile settings cheat sheet

```bash
cargo build                         # dev profile (unoptimized)
cargo build --release               # release profile (optimized)
cargo build --profile release-with-debug   # custom profile
```

### Publishing cheat sheet

```bash
cargo login                         # authenticate with crates.io
cargo doc --open                    # preview documentation
cargo test --doc                    # run doc tests only
cargo publish --dry-run             # validate without uploading
cargo publish                       # publish current version
cargo yank --vers 1.0.1             # prevent new users from picking 1.0.1
cargo yank --vers 1.0.1 --undo     # reverse a yank
```

### Workspace cheat sheet

```bash
cargo build                         # build all workspace members
cargo run -p <crate>                # run a specific member binary
cargo test                          # test all members
cargo test -p <crate>               # test one member
cargo publish -p <crate>            # publish one member
```

### Feature flags cheat sheet

```bash
cargo build --features serde                # enable one feature
cargo build --all-features                  # enable all features
cargo build --no-default-features           # disable default features
cargo test --features serde --doc           # doc-test with a feature active
```

---

## 📝 Chapter Review Notes

### Critical review (third-person)

The chapter covers all five upstream Rust book sections (ch14-01 through ch14-05) and the additional Cargo topics requested in the task specification. Code examples are syntactically valid for Rust 2024 edition. The workspace example is coherent across sections — `core`/`cli`/`web` are referenced consistently in §14.3, §14.6, and §14.7 rather than introducing throwaway crates per section.

The advisor recommended keeping the chapter toward ~750 lines to avoid the overrun in Ch11. After self-review, the chapter lands at approximately 703 lines — within the 700–900 target.

### Issues table

| # | Issue | Severity | Notes |
|---|-------|----------|-------|
| 1 | `resolver = "3"` in workspace | OK | Rust 2024 edition uses resolver version 3 by default. The fetched source content shows `resolver = "3"` in its workspace example. This is accurate. |
| 2 | `[workspace.package]` minimum version | OK | Both `[workspace.package]` and `[workspace.dependencies]` were stabilized in Rust 1.64 (Sept 2022), as confirmed by the Cargo reference MSRV markers. An earlier draft incorrectly stated 1.75+; corrected. Both are well below the Rust 2024 edition baseline (1.85). |
| 3 | `dep:` prefix syntax | OK | `dep:` for optional dependencies was stabilized in Rust 1.60. The chapter correctly recommends it over the older `feature = ["crate-name"]` form and explains why (namespace collision). |
| 4 | Custom profiles require `inherits` | OK | Verified: Cargo's reference states "A custom profile must specify `inherits` to the profile it inherits from." The chapter calls this out explicitly. |
| 5 | Yanking behavior — existing lockfiles | OK | The chapter clarifies that yanking only blocks new resolutions; existing `Cargo.lock` users are unaffected. The upstream source soft-pedals this; the chapter adds the clarification the advisor flagged. |
| 6 | `cargo publish --dry-run` | OK | Mentioned in §14.2 workflow. Not in the original source pages but is standard Cargo practice. |
| 7 | `cargo add` / `cargo remove` built-in status | OK | These shipped as stable in Cargo 1.62 (June 2022). They do not require `cargo-edit` to be installed. The chapter correctly marks them "built-in (Cargo 1.62+)". |
| 8 | `strip = true` in release profile | OK | Stabilized in Rust 1.59. Safe to include without a nightly caveat. |
| 9 | `lto = "thin"` vs `lto = true` | OK | `lto = true` enables "fat" LTO; `lto = "thin"` enables thin LTO. The chapter shows `"thin"` as the recommended starting point, which is consistent with Cargo's documentation. |
| 10 | `panic = "abort"` and `catch_unwind` | Low | The chapter states `"abort"` "removes `catch_unwind` capability" in a table note. Technically, `panic = "abort"` means the process aborts instead of unwinding — `catch_unwind` cannot catch aborts. The note is accurate but terse; readers wanting to use `catch_unwind` in libraries should know `"abort"` is incompatible. A one-sentence expansion would improve clarity. |
| 11 | `serde_json` used in feature example | OK — fixed | An earlier draft of §14.6 included a `user_to_json` function that called `serde_json::to_string` without declaring `serde_json` as a dependency. This was caught during review and fixed: the function was replaced with a simple `find_user` stub. The `#[cfg_attr(feature = "serde", derive(...))]` example alone is sufficient to illustrate conditional compilation without requiring `serde_json`. |
| 12 | `cargo audit fix` subcommand | Low | `cargo audit fix` is a relatively recent addition to cargo-audit (0.18+) and may not be available in all versions. The chapter mentions it without a version caveat. Adding `# requires cargo-audit 0.18+` would be precise. |
| 13 | `cargo flamegraph` on macOS requires `sudo` | Low | The `sudo cargo flamegraph` invocation on macOS requires DTrace, which requires root on newer macOS versions (SIP restrictions). The chapter shows `sudo` for macOS, which is correct, but does not mention that SIP must be disabled for some macOS versions. This is an edge case but worth a brief note. |
| 14 | `#[doc(hidden)]` semantics | OK — fixed | Original comment said "pub for use within crate; hidden from rustdoc" which was imprecise — `#[doc(hidden)]` items remain fully public and importable by external crates; only the documentation is hidden. The code comment was updated to read "still fully pub (callable by external crates); excluded from rustdoc." |
| 15 | Java analog for `cargo install` | OK | The chapter notes there is no close Java equivalent and draws the analogy to `pip install`. This is accurate and honest. |
| 16 | `opt-level = "s"` and `"z"` | OK | `"s"` optimizes for size, `"z"` for minimum size (may disable some vectorization). Both are stable. The table notes their use for embedded/WASM, which is accurate. |
| 17 | Workspace `Cargo.lock` constraint | OK | The chapter states "you cannot have two workspace members that require incompatible versions of the same dependency." This is accurate for workspace-level dependency unification. |
| 18 | `cargo tree --duplicates` vs `--duplicate` | Low | The correct flag is `--duplicates` (plural). Verify with `cargo tree --help`. Some versions of Cargo may accept both. The chapter uses `--duplicates`, which is the documented form. OK but worth noting for the copy-editor. |
| 19 | Rust 2024 edition impact on Cargo features | OK | The Rust 2024 edition changes the default resolver to version 3 and adjusts some `edition`-specific behaviors, but the Cargo.toml feature syntax, profile syntax, and workspace syntax shown in this chapter are all compatible with edition 2024. |
| 20 | `#[cfg_attr]` syntax correctness | OK | `#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]` is valid Rust syntax. The `serde::` path form inside `derive` requires serde 1.0+ and is standard practice. |
