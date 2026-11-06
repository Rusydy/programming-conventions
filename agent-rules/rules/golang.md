---
paths:
  - "**/*.go"
  - "*.go"
  - "**/go.mod"
  - "go.mod"
---
# Go conventions (every project)

Write idiomatic, readable Go. Follow the language's and the toolchain's conventions instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `golang-conventions` folder of the programming-conventions repository, which hold the reasons, sources and compiled examples. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-10-26; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (`gofmt`, `go fix`, dependency bumps) in separate commits.
- If the repository documents its own Go conventions, follow them first; where it is silent, apply this file to the code you write.
- Generated files (`// Code generated ... DO NOT EDIT.`) are exempt.
- Do not raise the `go` directive unasked. Use only features that the project's `go` directive allows. The latest stable release is Go 1.27 (2026-08-19); Go 1.26 is also supported.
- Prefer the standard library. Add a dependency only when it removes real complexity, and say why. Add no interface, generic, option or package until a second use exists.
- Before you report Go changes as done, run `gofmt -l`, `go vet ./...` and the affected tests with `-race`. Use the project's own commands when it defines them.
- When sources disagree, the order is: language spec and toolchain, this file and the notes, Go Code Review Comments, the Google Go Style Guide, the Uber Go Style Guide.

## Personal override: name every parameter and result

- Name every parameter and every result of every function, method, interface method, function type and function literal, including unused parameters (never `_`). Put results in parentheses, even a single one. Name by meaning, not by type: `(user *User, err error)`, `(found bool)`.
- Assign to a named result with `=`. Never redeclare it with `:=` or `var` (compile error). End with an explicit `return value` and avoid naked returns.
- Leave existing functions alone unless asked. Keep the `nonamedreturns` and `unparam` linters off. Every Go snippet you write in notes follows this too.

```go
func (s *Store) Find(ctx context.Context, id string) (user *User, err error)

func buildLookup(names []string) (index map[string]int) {
	index = make(map[string]int, len(names))
	for position, name := range names {
		index[name] = position
	}
	return index
}
```

## Setup and layout

- Format with `gofmt` and `goimports`: standard library first, a blank line, then the rest. Never hand-format, and add no `gofumpt`.
- Checks: `go vet ./...`, golangci-lint v2 (`linters.default: standard` plus `errorlint`, `errname`, `bodyclose`, `noctx`, `sqlclosecheck`, `rowserrcheck`, `sloglint`, `gosec`, `misspell`, `copyloopvar`, `intrange`, `modernize`), `govulncheck ./...`, `go test -race -shuffle=on ./...`.
- CI is GitLab CI: run the checks as three jobs, `test`, `lint` (a pinned `golangci/golangci-lint` image) and `govulncheck` (a pinned version).
- One `go.mod` per repository. Run `go mod tidy`; commit `go.mod` and `go.sum`. Pin developer tools with `tool` directives (Go 1.24+), not `tools.go`. After raising the `go` directive, run `go fix ./...` and commit the result separately.
- Start flat. Library: root package plus `internal/`. Service: `cmd/<name>/main.go` plus `internal/<package>/`. No `pkg/`; `golang-standards/project-layout` is not an official standard. An existing service keeps its layout: put new code where the repository already puts that kind of code.
- Packages by responsibility (`loan`, `report`), not by layer (`controller`, `service`, `repository`, `model`). No `util`, `common`, `helper`, `types`, `api` or `interfaces` packages.
- Keep `main` thin: it calls `run(ctx, args, getenv, stdout, stderr)` and turns the error into an exit code. `os.Exit` and `log.Fatal` only in `main`.
- File names are lower-case, with no `_impl.go` and no accidental `_linux`, `_windows` or `_arm64` suffix. Fixtures live in `testdata/`.

## Naming and style

- MixedCaps only, even for constants (`maxRetries`, never `MAX_RETRIES`). Keep initialisms in one case (`userID`, `ServeHTTP`, `parseURL`).
- Short names for short scopes. Receivers are one or two letters, the same in every method; never `this`, `self` or `me`.
- `Name()`, not `GetName()`. One-method interfaces end in `-er`; no `I` prefix and no `Interface` or `Impl` suffix.
- Sentinel errors are `ErrNotFound` (`errNotFound` when unexported); error types end in `Error`. Do not shadow predeclared names (`len`, `new`, `error`, `min`, `max`, `clear`).
- Package names are short, lower-case and named for what they provide. Do not repeat the package name in identifiers (`loan.Service`, not `loan.LoanService`).
- Every exported name has a doc comment that starts with the name and ends with a full stop; package comments start `// Package x ...`. Comments explain why, in English with American spelling. Delete commented-out code.
- Keep the normal path left-aligned: handle the error first, return early, no `else` after `return`. Use `any`, `for i := range n`, named struct-literal fields and `var s []T` for empty slices.
- Pass constant format strings to `Printf`-style calls; use `%w` only in `fmt.Errorf`.

## Design

- Export the minimum; keep private code in `internal/`. No mutable package-level state (database handles, loggers, config, clients) and no `init()`. Pass dependencies through constructors and wire them by hand in `main` or `run`.
- Define interfaces in the package that uses them, keep them small, and never create one only to mock. Accept interfaces, return concrete types. Never return a typed nil pointer as an interface value. Check at compile time when needed: `var _ http.Handler = (*Server)(nil)`.
- Constructors are `NewX(deps...) *X` or `(*X, error)`; they validate input. Make the zero value useful. Optional settings go in an options struct, or in functional options for a public API that will grow.
- No boolean parameters that switch behaviour; use two functions, a named type or an options struct.
- Use pointer receivers when the method mutates, the struct holds a mutex, or it is large; do not mix receiver kinds. Never embed `sync.Mutex`. Copy slices and maps at API boundaries. Prefer synchronous functions.
- Use generics only for containers and algorithms over many types.
- Avoid habits from other ecosystems: interface-plus-`Impl` pairs, getters and setters, layer packages, DI containers, `ternary` helpers, `panic` for control flow, log-and-rethrow. Leave existing `Impl` pairs until a change rewrites that component.

## Data

- Prefer `slices`, `maps`, `cmp`, `min`, `max` and `clear` to hand-written loops and `sort.Slice`. Pre-size slices and maps when the size is known; initialise a map before writing. Sort keys with `slices.Sorted(maps.Keys(m))`.
- Enums are a named type with `iota`, a deliberate zero value (start at 1 or reserve 0 as `Unknown`), a `String()` method, and validation of external input.
- Time: `time.Time` and `time.Duration`, never bare integers. Store and send UTC (RFC 3339), convert at the edge, and inject a clock. New data is UTC and an existing table keeps its zone; put `loc=UTC` in MySQL DSNs, use `timestamptz` in PostgreSQL, and never rely on `loc=Local`.
- Money: never `float64`. Use integer minor units (`int64`) with an explicit currency, or a vetted decimal type (`shopspring/decimal` for rates and rounding). Never send amounts as JSON floats.
- JSON: tag every field with its wire name; use `omitzero` for `time.Time` and structs; use pointer fields only when "absent" differs from zero (`new(expr)` in Go 1.26+).
- Use `strings.Builder` in loops, the `strings.Cut` family instead of index slicing, and `strconv` instead of `fmt.Sprintf` for simple conversions.

## Errors

- Check every error. Never discard one with `_` without a comment. `error` is the last result.
- Handle each error once: return it with context, or handle and log it. Log at the boundary (handler, job runner, `main`).
- Wrap with context and put `%w` last: `fmt.Errorf("load config %q: %w", path, err)`. Lower-case, no trailing punctuation, no "failed to". Use `%v` to hide an implementation detail.
- Inspect with `errors.Is`, `errors.As` or `errors.AsType` (Go 1.26+). Never use `==` on wrapped errors and never match message text.
- Expose sentinels only for conditions callers branch on; use `...Error` types when callers need data. Translate at package boundaries (`sql.ErrNoRows` to `ErrNotFound`). Never return `nil, nil` for "not found". Declare a sentinel beside the code that returns it (`errors.go` only when several files share it).
- HTTP errors in new services are RFC 9457 problem details (`application/problem+json` with `title`, `status`, `detail`), mapped in one place. An existing service keeps its error body, and an external specification such as BI SNAP overrides this.
- Combine errors with `errors.Join`. Report close errors on files you write: `defer func() { err = errors.Join(err, file.Close()) }()`.
- `panic` only for programmer errors and start-up `Must` helpers; never across a package boundary.

## Concurrency and context

- Every goroutine has an owner, a stop condition and a `ctx`. Wait for it (`errgroup`, or `sync.WaitGroup.Go` in Go 1.25+). No fire-and-forget; bound fan-out with `SetLimit`, calling `errgroup` directly. No `automaxprocs` on Go 1.25 or later.
- `ctx context.Context` is the first parameter. Never store it in a struct and never pass nil. Write `defer cancel()` right after `WithCancel` or `WithTimeout`. Pass `ctx` to database and HTTP calls. Use `context.WithoutCancel` for work that must outlive the request.
- Mutex: zero value, a `mu` field above the data it guards, `defer mu.Unlock()`; never copy or embed it. Use typed atomics (`atomic.Int64`). Channels: the sender closes, use directional types, buffer 0 or 1.
- Always run `go test -race`. With `go 1.22` or later there is no `v := v`; with `go 1.23` or later do not drain timer channels by hand. Test goroutines and timers with `testing/synctest`, not `time.Sleep`.

## Testing

- Use the standard `testing` package. Write table-driven tests with descriptive case names, `t.Run`, `t.Parallel()` for independent cases, `t.Helper()` in helpers, and `t.Context()`, `t.TempDir()` and `t.Setenv()`.
- Failure messages read `Func(input) = got, want want`. Use `t.Errorf` to keep going, `t.Fatalf` only when the test cannot continue, and never `t.Fatal` from another goroutine.
- Compare whole values with `cmp.Diff(want, got)` and label it `(-want +got)`. No assertion libraries such as `testify`, and no `reflect.DeepEqual` in new code. Check errors with `errors.Is` or `errors.As`, not messages, and compare parsed JSON, not strings.
- Prefer real implementations and small fakes over mocks, with consumer-defined interfaces. Use `httptest` for HTTP, `testdata/` for fixtures, `for b.Loop()` for benchmarks, and fuzz tests for parsers.
- Generate mocks with `go.uber.org/mock` (`golang/mock` is archived). Database tests use a throwaway server from a CI service container or `docker run`: read `TEST_DATABASE_URL`, skip when it is unset, never use a shared instance, and pin the image tag.

## Services

- Stdlib first: `net/http` (`ServeMux` patterns such as `GET /loans/{code}`), `database/sql` and `log/slog`. Follow the project's framework when one exists. The `database/sql` drivers are `go-sql-driver/mysql` and `pgx/v5/stdlib`; a new service gets no ORM.
- Migrations: numbered, forward-only SQL files embedded with `//go:embed` and applied with `golang-migrate`; never edit a merged migration. Traces and metrics only when needed, then OpenTelemetry (`otelhttp`, `otelsql`) and no vendor agent in a new service.
- Config: read the environment once at start-up into a typed struct, validate it, fail fast, keep defaults in code, pass `getenv` for tests, and never log secrets.
- Logging: one `*slog.Logger` passed in; constant messages with attributes for data; the `...Context` methods; never log secrets or personal data (implement `slog.LogValuer`).
- Always set `http.Server` timeouts (at least `ReadHeaderTimeout`). Never use `http.DefaultClient` or `http.Get` in production; use `http.NewRequestWithContext`, close `resp.Body`, retry only idempotent requests with backoff and jitter, limit request bodies with `http.MaxBytesReader`, and shut down gracefully with `signal.NotifyContext` and `Shutdown`.
- SQL: placeholders only, the `...Context` methods, `defer rows.Close()` and a check of `rows.Err()`, `defer tx.Rollback()` straight after `BeginTx`, and an explicit pool configuration.
- Security: `crypto/rand` for secrets, constant-time comparisons, never `InsecureSkipVerify`, `filepath.IsLocal` or `os.Root` for user-supplied paths, `html/template` for HTML, and `govulncheck`.

## Modern Go

- Prefer `log/slog`, `slices`, `maps`, `for range n`, `cmp.Or`, `errors.Join`, `context.WithoutCancel`, `sync.OnceValue`, typed atomics, `b.Loop()`, `omitzero`, `os.Root`, `new(expr)` (1.26), `errors.AsType` (1.26) and `WaitGroup.Go` (1.25). Go 1.27 adds generic methods, a `uuid` package and `strings.CutLast`; keep using `encoding/json`.
- Do not rewrite untouched code just to use these.
- Services on Go 1.24 or 1.25 are out of support: move each to Go 1.26, the oldest supported release, in its own change, and keep the builder image on the `go` directive's release.

## Notes index

Each file is in the `golang-conventions` folder of the programming-conventions repository.

- `01-principles-and-sources.md`: principles, source precedence, how to apply
- `02-named-parameters-and-results.md`: the naming override, with a checker program
- `03-project-setup-and-tooling.md`: modules, formatting, linters, CI commands
- `04-project-layout.md`: folders, thin `main`, generated code
- `05-naming-comments-and-style.md`: identifiers, comments, code layout
- `06-package-and-api-design.md`: interfaces, constructors, options, generics, habits to avoid
- `07-types-and-data.md`: slices, maps, enums, time, money, JSON
- `08-error-handling.md`: wrapping, inspecting, designing errors, panics
- `09-concurrency-and-context.md`: goroutines, context, mutexes, channels
- `10-testing.md`: tables, messages, go-cmp, doubles, benchmarks
- `11-service-practices.md`: config, slog, HTTP, database, security
- `12-modern-go-by-release.md`: features per Go release, 1.18 to 1.27
