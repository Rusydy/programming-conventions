# Modern Go by Release

- Responsibility: engineering
- Area/system: golang
- Keywords: Go 1.18, Go 1.19, Go 1.20, Go 1.21, Go 1.22, Go 1.23, Go 1.24, Go 1.25, Go 1.26, Go 1.27, generics, slog, slices, maps, range over int, iterators, WaitGroup.Go, synctest, errors.AsType, new(expr), go fix, modernize, generic methods, json v2, uuid, supported releases, existing projects
- Aliases: what is new in Go, Go release features, modern idioms Go, Go version cheat sheet, upgrade Go idioms, fitur Go per versi
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [tooling](03-project-setup-and-tooling.md), [types and data](07-types-and-data.md), [error handling](08-error-handling.md), [concurrency and context](09-concurrency-and-context.md), [testing](10-testing.md).

## Summary

This cheat sheet lists the language and library features, release by release, that replace older idioms. New code uses the modern form. The latest stable release is Go 1.27 (2026-08-19), and Go 1.26 is still supported. Refresh this note after each release, about every six months.

## Rules

### How to use this list

- A feature needs both a toolchain that has it and a `go` directive that allows it. Language changes depend on the `go` directive; since Go 1.27, `go test` also runs `stdversion` to report standard library symbols that are too new for it ([tooling](03-project-setup-and-tooling.md#modules-and-versions)).
- After raising the `go` directive, run `go fix ./...` (Go 1.26+) and review the diff in a separate commit.
- Do not rewrite untouched code just to use these features ([principles](01-principles-and-sources.md#applying-the-notes)).

### Go 1.27 (2026-08-19)

- **Generic methods:** a method may declare its own type parameters. Interface methods cannot, and a generic method cannot satisfy an interface method.
- **Struct literal keys** may be any valid field selector of the struct, not only a top-level field name.
- **`encoding/json/v2` and `encoding/json/jsontext`** are generally available, and `encoding/json` now runs on the v2 implementation. The v1 API stays supported; error message text can differ.
- **`uuid`** is a new standard library package (`uuid.New()`, `uuid.NewV7()`, `uuid.Parse`). Prefer it for new code when it covers your need.
- **`strings.CutLast` and `bytes.CutLast`** replace `LastIndex` plus slicing.
- **`go vet`** reports `fmt.Errorf("...: %w", p)` when `p` has type `*E` and `E` implements `error`. **`go test`** runs `stdversion` by default.
- **`goroutineleak`** profile (`runtime/pprof`, `/debug/pprof/goroutineleak`) is generally available. `testing/synctest` gains `Sleep`. `net/http/httptest` gains `NewTestServer`.
- **`go fix`** gains the `atomictypes`, `embedlit`, `slicesbackward` and `unsafefuncs` modernisers; `go doc` accepts `package@version` and `-ex`. `go mod tidy` keeps at most two `require` blocks for `go 1.27` modules.
- **Timers:** the `asynctimerchan` setting is gone, so timer channels are always synchronous.

### Go 1.26 (2026-02-10)

- **`new(expr)`:** `new` accepts an expression, so `Note: new("manual review")` replaces a temporary variable and `&v`.
- **`errors.AsType[E](err)`** returns the matching error and an `ok` flag. It replaces `errors.As` with a pre-declared target.
- **`go fix`** is rebuilt on the analysis framework with dozens of modernisers and an inliner for API migrations (`//go:fix inline`).
- **Self-referential generic constraints** such as `type Adder[A Adder[A]] interface` are allowed.
- **`slog.NewMultiHandler`** sends a record to several handlers. `signal.NotifyContext` cancels with a cause that names the signal. `testing.T.ArtifactDir` gives tests a place for output files. `B.Loop` no longer prevents inlining.
- **`go mod init`** writes the previous release in the `go` directive. The Green Tea garbage collector is on by default.

### Go 1.25 (2025-08-12)

- **`sync.WaitGroup.Go`** replaces `wg.Add(1)` plus `go func() { defer wg.Done() ... }()`. `go vet` gains `waitgroup` and `hostport`.
- **`testing/synctest`** is generally available for testing goroutines and timers with a virtual clock.
- **`GOMAXPROCS`** follows the container's CPU limit and updates while the program runs, so `automaxprocs` is no longer needed.
- **`encoding/json/v2`** is experimental in this release. **`go.mod`** gains the `ignore` directive.

### Go 1.24 (2025-02-11)

- **`tool` directives** in `go.mod` and `go tool` replace the `tools.go` blank-import file.
- **`testing.B.Loop`** replaces `for i := 0; i < b.N; i++`. **`T.Context`** and **`T.Chdir`** simplify tests.
- **`os.Root`** (`os.OpenRoot`) confines file operations to a directory.
- **`omitzero`** JSON tag option omits Go zero values, including `time.Time`. `strings.Lines` and `strings.SplitSeq` iterate without allocating a slice. `crypto/rand.Text` generates random text.
- **Generic type aliases** are fully supported. `runtime.AddCleanup` is preferred over `SetFinalizer`. The `weak` package provides weak pointers. `go vet` reports non-constant `Printf` format strings.

### Go 1.23 (2024-08-13)

- **Range over functions** and the `iter` package (`iter.Seq`, `iter.Seq2`) let a collection expose an iterator.
- **`slices.Collect`, `slices.Sorted`, `slices.Values`** and **`maps.Keys`, `maps.Values`** work with iterators. `slices.Sorted(maps.Keys(m))` replaces the key-collect-and-sort loop.
- **Timers and tickers** with `go 1.23` semantics use unbuffered channels, so `Reset` and `Stop` need no manual draining. The `unique` package interns values.
- **`go mod tidy -diff`** prints the needed changes and exits non-zero when there are any.

### Go 1.22 (2024-02-06)

- **Per-iteration loop variables** make `v := v` copies unnecessary.
- **`for i := range n`** ranges over an integer.
- **`net/http.ServeMux`** matches methods and wildcards (`GET /items/{id}`) and exposes `Request.PathValue`.
- **`math/rand/v2`** replaces `math/rand`. **`cmp.Or`** returns the first non-zero value. **`database/sql.Null[T]`** scans nullable columns of any type.

### Go 1.21 (2023-08-08)

- **`log/slog`** provides structured logging. **`slices`**, **`maps`** and **`cmp`** replace hand-written helpers and `sort.Slice`. The built-ins **`min`**, **`max`** and **`clear`** arrive.
- **`context.WithoutCancel`** and **`context.AfterFunc`**; **`sync.OnceFunc`** and **`sync.OnceValue`**.
- **The `go` line** in `go.mod` is a strict minimum, and the toolchain can switch versions automatically. Profile-guided optimisation is ready for general use.

### Go 1.20 (2023-02-01)

- **`errors.Join`** and several `%w` verbs in one `fmt.Errorf`. **`strings.CutPrefix`** and **`strings.CutSuffix`**. **`context.WithCancelCause`**.

### Go 1.19 (2022-08-02)

- **Typed atomics** (`atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]`) replace the function forms. `gofmt` reformats doc comments.

### Go 1.18 (2022-03-15)

- **Generics** and the **`any`** alias for `interface{}`. Native **fuzzing** and **workspaces** (`go.work`).

### Existing projects

- Go supports the two newest major releases, which are 1.27 and 1.26 since 2026-08-19. A project that declares an older release gets no security fixes for it. Raise the `go` line in a change of its own.
- Move each of those services to Go 1.26, the oldest supported release, in its own change, then follow the checklist below.
- Match the builder image to the `go` directive: a builder image older than the `go` line is a mismatch to fix.

### Upgrade checklist

1. Read the release notes for removed `GODEBUG` settings and changed defaults (Go 1.27 removes several TLS and timer settings).
2. Raise the `go` directive on purpose, then run `go vet ./...` and `go test -race ./...`.
3. Run `go fix ./...` and commit the result separately.
4. Rebuild or re-pin developer tools such as `staticcheck` with the new toolchain ([tooling](03-project-setup-and-tooling.md#modules-and-versions)).
5. Update this note.

## Sources and raw notes

Release notes read on 2026-10-21: [Go 1.18](https://go.dev/doc/go1.18), [1.19](https://go.dev/doc/go1.19), [1.20](https://go.dev/doc/go1.20), [1.21](https://go.dev/doc/go1.21), [1.22](https://go.dev/doc/go1.22), [1.23](https://go.dev/doc/go1.23), [1.24](https://go.dev/doc/go1.24), [1.25](https://go.dev/doc/go1.25), [1.26](https://go.dev/doc/go1.26) and [1.27](https://go.dev/doc/go1.27). Release dates come from the [release history](https://go.dev/doc/devel/release). The `uuid` API comes from [pkg.go.dev/uuid](https://pkg.go.dev/uuid). Symbols from Go 1.26 and earlier were also checked with `go doc` on Go 1.26.3; Go 1.27 symbols could not be checked locally and rely on the release notes.

The support window comes from [principles](01-principles-and-sources.md#applying-the-notes) and the [release history](https://go.dev/doc/devel/release).
