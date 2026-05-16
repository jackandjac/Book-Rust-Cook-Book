#!/usr/bin/env bash
#
# Generate three PDF books from the Rust Cookbook markdown sources.
#
# Books produced:
#   1. RUST_COOKBOOK.pdf          — 21 language chapters (Part I)
#   2. RUST_LEETCODE.pdf          — 19 Rust LeetCode chapters (Part II)
#   3. JAVA_LEETCODE.pdf          — 19 Java LeetCode chapters (Part III)
#
# Usage:
#   ./generate-pdfs.sh            # skip PDFs whose sources haven't changed
#   ./generate-pdfs.sh --force    # regenerate all PDFs
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

CSS="book-style.css"
PDF_OPTIONS='{"format":"Letter","printBackground":true,"margin":{"top":"0","bottom":"0","left":"0","right":"0"}}'

TMPDIR_LOCAL="/tmp/rust-cookbook-pdf"
mkdir -p "$TMPDIR_LOCAL"

# ─────────────────────────────────────────────────────────────────────────────
# Helper: concatenate files with a separator line between them
# ─────────────────────────────────────────────────────────────────────────────
concat_files() {
  local outfile="$1"
  shift
  : > "$outfile"
  local first=true
  for f in "$@"; do
    if [[ "$first" == false ]]; then
      printf '\n\n---\n\n' >> "$outfile"
    fi
    cat "$f" >> "$outfile"
    first=false
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: generate one PDF
#   $1 = source markdown
#   $2 = output pdf path
#   $3 = human label (for logging)
# ─────────────────────────────────────────────────────────────────────────────
generate_pdf() {
  local md="$1"
  local pdf="$2"
  local label="$3"

  if [[ "$FORCE" == false && -f "$pdf" && "$pdf" -nt "$md" && "$pdf" -nt "$CSS" ]]; then
    echo "⏭️  $label — up to date, skipping"
    return 0
  fi

  echo "📄 Generating $label ..."
  npx --yes md-to-pdf "$md" \
    --stylesheet "$CSS" \
    --highlight-style github-dark \
    --pdf-options "$PDF_OPTIONS"

  # md-to-pdf writes alongside the .md, so move if needed
  local generated_pdf="${md%.md}.pdf"
  if [[ "$generated_pdf" != "$pdf" ]]; then
    mv "$generated_pdf" "$pdf"
  fi

  local size
  size=$(du -h "$pdf" | cut -f1 | xargs)
  echo "✅ $label → $pdf ($size)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Book 1: Rust Cookbook (21 language chapters)
# ─────────────────────────────────────────────────────────────────────────────
BOOK1_MD="$TMPDIR_LOCAL/RUST_COOKBOOK.md"
BOOK1_PDF="$SCRIPT_DIR/RUST_COOKBOOK.pdf"

cat > "$TMPDIR_LOCAL/book1_cover.md" << 'COVER'
# The Rust Cookbook for Java Developers

**Part I: The Rust Language**

> A practical companion to [The Rust Programming Language](https://doc.rust-lang.org/book/) — packed with runnable examples, real-world patterns, and Java↔Rust comparisons.

**Rust Edition:** 2024 (default since Rust 1.85, Feb 2025)
**Target audience:** Java developers transitioning to Rust
**Approach:** Every topic from the official book — with more code, more examples, and honest reviews.

---
COVER

concat_files "$BOOK1_MD" \
  "$TMPDIR_LOCAL/book1_cover.md" \
  chapters/ch01-getting-started.md \
  chapters/ch02-guessing-game.md \
  chapters/ch03-common-concepts.md \
  chapters/ch04-ownership.md \
  chapters/ch05-structs.md \
  chapters/ch06-enums-patterns.md \
  chapters/ch07-modules.md \
  chapters/ch08-collections.md \
  chapters/ch09-error-handling.md \
  chapters/ch10-generics-traits-lifetimes.md \
  chapters/ch11-testing.md \
  chapters/ch12-cli-project.md \
  chapters/ch13-closures-iterators.md \
  chapters/ch14-cargo.md \
  chapters/ch15-smart-pointers.md \
  chapters/ch16-concurrency.md \
  chapters/ch17-async.md \
  chapters/ch18-oop.md \
  chapters/ch19-patterns.md \
  chapters/ch20-advanced.md \
  chapters/ch21-web-server.md

generate_pdf "$BOOK1_MD" "$BOOK1_PDF" "Book 1: Rust Cookbook"

# ─────────────────────────────────────────────────────────────────────────────
# Book 2: Rust LeetCode (17 chapters)
# ─────────────────────────────────────────────────────────────────────────────
BOOK2_MD="$TMPDIR_LOCAL/RUST_LEETCODE.md"
BOOK2_PDF="$SCRIPT_DIR/RUST_LEETCODE.pdf"

cat > "$TMPDIR_LOCAL/book2_cover.md" << 'COVER'
# LeetCode Problem Solving in Rust

**Part II: Competitive Programming & Interview Prep**

> Blind 75 · NeetCode 150 · LeetCode Study Plans — all solved in idiomatic Rust.

**Why Rust for LeetCode?**
Rust's type system forces correct solutions upfront. The borrow checker eliminates null-pointer bugs. Zero-cost iterators match raw loops in speed. Every solution compiles and is verified.

---
COVER

concat_files "$BOOK2_MD" \
  "$TMPDIR_LOCAL/book2_cover.md" \
  leetcode/lc01-arrays-hashing.md \
  leetcode/lc02-two-pointers-sliding-window.md \
  leetcode/lc03-stack-binary-search.md \
  leetcode/lc04-linked-lists.md \
  leetcode/lc05-trees.md \
  leetcode/lc06-heap-backtracking.md \
  leetcode/lc07-tries-graphs.md \
  leetcode/lc08-dynamic-programming.md \
  leetcode/lc09-greedy-intervals-math-bits.md \
  leetcode/lc10-binary-search-deep-dive.md \
  leetcode/lc11-dfs-deep-dive.md \
  leetcode/lc12-bfs-deep-dive.md \
  leetcode/lc13-advanced-graphs.md \
  leetcode/lc14-advanced-dp-part1.md \
  leetcode/lc14-advanced-dp-part2.md \
  leetcode/lc14-advanced-dp-part3.md \
  leetcode/lc14-advanced-dp-part4.md \
  leetcode/lc15-trie-deep-dive.md \
  leetcode/lc16-union-find-deep-dive.md

generate_pdf "$BOOK2_MD" "$BOOK2_PDF" "Book 2: Rust LeetCode"

# ─────────────────────────────────────────────────────────────────────────────
# Book 3: Java LeetCode (17 chapters)
# ─────────────────────────────────────────────────────────────────────────────
BOOK3_MD="$TMPDIR_LOCAL/JAVA_LEETCODE.md"
BOOK3_PDF="$SCRIPT_DIR/JAVA_LEETCODE.pdf"

cat > "$TMPDIR_LOCAL/book3_cover.md" << 'COVER'
# LeetCode Problem Solving in Java

**Part III: Java 17+ Companion Chapters**

> The same problems as Part II — solved in Java 17+ for side-by-side comparison.

**Why the Java companion?**
For teams migrating Java → Rust, seeing the same algorithm in both languages is the fastest path to fluency. Each chapter highlights where Java and Rust diverge: heap direction, ownership, tree nodes, error handling.

---
COVER

concat_files "$BOOK3_MD" \
  "$TMPDIR_LOCAL/book3_cover.md" \
  leetcode-java/lc01-arrays-hashing-java.md \
  leetcode-java/lc02-two-pointers-sliding-window-java.md \
  leetcode-java/lc03-stack-binary-search-java.md \
  leetcode-java/lc04-linked-lists-java.md \
  leetcode-java/lc05-trees-java.md \
  leetcode-java/lc06-heap-backtracking-java.md \
  leetcode-java/lc07-tries-graphs-java.md \
  leetcode-java/lc08-dynamic-programming-java.md \
  leetcode-java/lc09-greedy-intervals-math-bits-java.md \
  leetcode-java/lc10-binary-search-deep-dive-java.md \
  leetcode-java/lc11-dfs-deep-dive-java.md \
  leetcode-java/lc12-bfs-deep-dive-java.md \
  leetcode-java/lc13-advanced-graphs-java.md \
  leetcode-java/lc14-advanced-dp-part1-java.md \
  leetcode-java/lc14-advanced-dp-part2-java.md \
  leetcode-java/lc14-advanced-dp-part3-java.md \
  leetcode-java/lc14-advanced-dp-part4-java.md \
  leetcode-java/lc15-trie-deep-dive-java.md \
  leetcode-java/lc16-union-find-deep-dive-java.md

generate_pdf "$BOOK3_MD" "$BOOK3_PDF" "Book 3: Java LeetCode"

# ─────────────────────────────────────────────────────────────────────────────
# Book 4: System Design (16 chapters — bilingual Rust + Java)
# ─────────────────────────────────────────────────────────────────────────────
BOOK4_MD="$TMPDIR_LOCAL/SYSTEM_DESIGN.md"
BOOK4_PDF="$SCRIPT_DIR/SYSTEM_DESIGN.pdf"

cat > "$TMPDIR_LOCAL/book4_cover.md" << 'COVER'
# System Design: Interview Prep & Production Patterns

**Part IV: Distributed Systems Design**

> From interview fundamentals (Rate Limiter, URL Shortener, Chat System) to distributed theory (CAP theorem, Raft, Consistent Hashing) to production patterns (Event Sourcing, Circuit Breaker, Saga Pattern).

**Approach:** Every chapter: Requirements → Back-of-envelope math → Architecture → Component deep-dive → Tradeoffs → Compilable Rust + Java code snippets.
**Code:** All snippets compile with `rustc --edition 2024` and `javac --release 17` — no external dependencies.

---
COVER

concat_files "$BOOK4_MD" \
  "$TMPDIR_LOCAL/book4_cover.md" \
  system-design/sd01-rate-limiter.md \
  system-design/sd02-url-shortener.md \
  system-design/sd03-consistent-hashing.md \
  system-design/sd04-cap-theorem.md \
  system-design/sd05-raft-consensus.md \
  system-design/sd06-key-value-store.md \
  system-design/sd07-chat-system.md \
  system-design/sd08-news-feed.md \
  system-design/sd09-search-autocomplete.md \
  system-design/sd10-notification-system.md \
  system-design/sd11-distributed-cache.md \
  system-design/sd12-load-balancing.md \
  system-design/sd13-video-streaming.md \
  system-design/sd14-event-sourcing-cqrs.md \
  system-design/sd15-circuit-breaker.md \
  system-design/sd16-saga-idempotency.md

generate_pdf "$BOOK4_MD" "$BOOK4_PDF" "Book 4: System Design"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "All done! PDFs in $SCRIPT_DIR:"
for pdf in RUST_COOKBOOK.pdf RUST_LEETCODE.pdf JAVA_LEETCODE.pdf SYSTEM_DESIGN.pdf; do
  if [[ -f "$SCRIPT_DIR/$pdf" ]]; then
    echo "  $(du -h "$SCRIPT_DIR/$pdf" | cut -f1 | xargs)  $pdf"
  fi
done
