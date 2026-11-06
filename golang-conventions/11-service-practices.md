# Go Service Practices

## Summary

A Go service stays on the standard library first: `net/http`, `database/sql`, `log/slog`, environment variables and `flag`. Build it in `main`, pass dependencies down explicitly, set a timeout on every network call, log structured events once, and treat all input as untrusted.

## Rules

### Application wiring

- `main` calls `run` ([project layout](04-project-layout.md#keep-main-thin)). `run` loads the configuration, builds the logger, the database handle and the HTTP server, and passes them down as constructor parameters. No package keeps these in a global variable.
- Read configuration once, at start-up, into a typed struct. Validate it and stop with a clear message when a required value is missing. Keep the defaults in code, so that the service runs with a minimal environment: that is convention over configuration.
- Take configuration from environment variables (and flags for command-line tools). Use the standard `os` and `flag` packages first, and add a configuration library only when it removes real code. Never read configuration from the repository, and never log secrets.
- Pass `getenv` into the loader, so that tests do not touch the process environment.

```go
type Config struct {
	Addr            string
	DatabaseURL     string
	ShutdownTimeout time.Duration
}

func LoadConfig(getenv func(key string) (value string)) (cfg Config, err error) {
	cfg = Config{
		Addr:            cmp.Or(getenv("APP_ADDR"), ":8080"),
		DatabaseURL:     getenv("APP_DATABASE_URL"),
		ShutdownTimeout: 15 * time.Second,
	}
	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("APP_DATABASE_URL is required")
	}
	return cfg, nil
}
```

### Logging

- Use `log/slog`. Create one `*slog.Logger` in `main` and pass it to constructors. A library package never configures global logging. Use the JSON handler in production and the text handler for local work. A project that already uses another logger keeps it until a change touches the logging code.
- Write short, constant messages and put the variable data in attributes, so that logs can be searched and aggregated: `logger.InfoContext(ctx, "loan submitted", "loan_code", code, "amount_minor", amount)`.
- Use the `...Context` methods, so that a handler can add the request ID from the context. `go vet` checks the key and value pairs, and the `sloglint` linter keeps the style consistent.
- Choose the level by action: debug for diagnostics, info for business and lifecycle events, warn for unexpected but handled cases, error when an operation failed and needs attention. Log an error once ([error handling](08-error-handling.md#core-rules)).
- Never log secrets, tokens, full account or card numbers, or personal data. Implement `slog.LogValuer` on sensitive types so that they redact themselves.

```go
// Token is a secret that must never appear in logs.
type Token string

// LogValue redacts the token when it is logged.
func (t Token) LogValue() (value slog.Value) {
	return slog.StringValue("[redacted]")
}
```

- Send one record to several handlers with `slog.NewMultiHandler` (Go 1.26+). Do not leave `fmt.Println` or `log.Printf` debugging in committed code.

### Observability beyond logs

- Logs are the baseline. Add traces or metrics only when an operator needs them.
- Then use OpenTelemetry. It keeps the backend replaceable. Use `otelhttp` for `net/http` and `otelsql` for `database/sql`, and add the trace ID to log records through the context.
- Do not add a vendor agent to a new service.

### HTTP servers

- Start with `net/http`. Since Go 1.22 the standard `ServeMux` matches methods and wildcards: `mux.HandleFunc("GET /loans/{code}", handler)` and `r.PathValue("code")`. Add a router library only when the standard mux cannot express what you need. If a framework is already in use, follow its documented conventions and keep business logic out of its types. A project keeps the router it has, and a new service uses `ServeMux`.
- Always set the server timeouts: `ReadHeaderTimeout` at least, and `ReadTimeout`, `WriteTimeout` and `IdleTimeout` to suit the workload. A bare `http.ListenAndServe` has none.

```go
func newServer(cfg Config, handler http.Handler) (srv *http.Server) {
	return &http.Server{
		Addr:              cfg.Addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}
}
```

- Keep handlers thin: decode, call the service, encode. Write middleware as `func(next http.Handler) (handler http.Handler)`.
- Limit request bodies with `http.MaxBytesReader`, decode strictly ([JSON and struct tags](07-types-and-data.md#json-and-struct-tags)), and set the `Content-Type` header.
- Use `r.Context()` for downstream calls. Do not start a goroutine that outlives the request unless you detach it on purpose with `context.WithoutCancel`.
- Return errors as RFC 9457 problem details, mapped in one place, and never return internal error text to the client ([error handling](08-error-handling.md#errors-at-the-boundary)).
- Shut down gracefully. Cancel a context on `SIGINT` and `SIGTERM` with `signal.NotifyContext`, then call `Shutdown` with a fresh timeout.

```go
func serve(ctx context.Context, srv *http.Server, shutdownTimeout time.Duration) (err error) {
	failed := make(chan error, 1)
	go func() { failed <- srv.ListenAndServe() }()

	select {
	case err = <-failed:
		return err
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), shutdownTimeout)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}
```

### HTTP clients

- Never use `http.DefaultClient` or `http.Get` in production code: they set no timeout. Build one `http.Client` with a `Timeout` (and a tuned `Transport` if needed) and reuse it. It is safe for concurrent use and it pools connections.
- Create requests with `http.NewRequestWithContext`, close `resp.Body` (the `bodyclose` linter checks it) and check the status code. Go 1.27 drains a small unread remainder when you close an HTTP/1 body, but still read what you need.
- Build URLs with `net/url` and addresses with `net.JoinHostPort`, not with string concatenation (`go vet` reports the `hostport` mistake since Go 1.25).
- Retry only idempotent requests, or requests that carry an idempotency key. Use exponential backoff with jitter and stop at the context deadline.

```go
func fetch(ctx context.Context, client *http.Client, url string) (body []byte, err error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	response, err := client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("get %s: %w", url, err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("get %s: unexpected status %s", url, response.Status)
	}
	return io.ReadAll(io.LimitReader(response.Body, 1<<20))
}
```

### Database

- Use `database/sql` with the database's standard driver: `github.com/go-sql-driver/mysql` for MySQL and `github.com/jackc/pgx/v5/stdlib` for PostgreSQL. Do not add an ORM or a query builder to a new service. An existing project keeps the query layer it has. Take the native `pgx` interface only when you need `COPY` or `LISTEN` and `NOTIFY`, which `database/sql` hides.
- Keep schema changes in numbered, forward-only SQL files in a `migrations/` folder, embed them with `//go:embed`, and apply each file once with `golang-migrate` (its `iofs` source). Never edit a migration after it has been merged.
- Use the `...Context` methods (`QueryContext`, `ExecContext`, `BeginTx`). Pass every value as a placeholder argument and never build SQL with string concatenation or `fmt.Sprintf`. The placeholder syntax depends on the driver (`?` for MySQL, `$1` for PostgreSQL).
- Close `rows` with `defer rows.Close()` and check `rows.Err()` after the loop. The `sqlclosecheck` and `rowserrcheck` linters check both.
- Keep transactions short, with no network calls inside. Defer the rollback straight away; it is a no-op after a successful commit.

```go
func transfer(ctx context.Context, db *sql.DB) (err error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer func() {
		// Rollback is a no-op after a successful Commit; its error carries no information then.
		_ = tx.Rollback()
	}()

	if _, err = tx.ExecContext(ctx, `UPDATE accounts SET balance = balance - ? WHERE id = ?`, 100, 1); err != nil {
		return fmt.Errorf("debit account: %w", err)
	}
	return tx.Commit()
}
```

- Set the connection pool explicitly in production: `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime` and `SetConnMaxIdleTime`.
- Map `sql.ErrNoRows` to a domain `ErrNotFound` at the store boundary ([error handling](08-error-handling.md#designing-errors-for-callers)). Use `sql.Null[T]` (Go 1.22+) or pointers for nullable columns.
- Keep SQL in the store package. It accepts a context and returns domain types.

### Security basics

- Use `crypto/rand` for secrets and tokens (`rand.Text()` since Go 1.24), never `math/rand`.
- Compare secrets and MACs in constant time with `crypto/subtle.ConstantTimeCompare` or `hmac.Equal`.
- Keep the default TLS settings. Never set `InsecureSkipVerify` and never lower `MinVersion`.
- Confine file access that depends on user input: check names with `filepath.IsLocal`, or open the directory with `os.OpenRoot` (Go 1.24+) and work through the returned `os.Root`.
- Use `html/template`, not `text/template`, for HTML.
- Keep secrets out of source, logs, error messages and URLs. Load them from the environment or a secret manager.
- Limit the size of every input and set a timeout on every call that leaves the process.
- Run `govulncheck ./...` in CI and update the toolchain and dependencies when a security release appears ([tooling](03-project-setup-and-tooling.md#static-checks)). Add `gosec` to the lint set.

## Sources and raw notes

- [Go Security Best Practices](https://go.dev/doc/security/best-practices), [govulncheck tutorial](https://go.dev/doc/tutorial/govulncheck), [Structured logging with slog](https://go.dev/blog/slog), [Routing enhancements for Go 1.22](https://go.dev/blog/routing-enhancements), [`net/http`](https://pkg.go.dev/net/http) and [`log/slog`](https://pkg.go.dev/log/slog) package documentation.
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): Crypto Rand, Contexts.
- Release notes: [Go 1.22](https://go.dev/doc/go1.22) (`ServeMux` patterns, `sql.Null`), [Go 1.24](https://go.dev/doc/go1.24) (`os.Root`, `rand.Text`), [Go 1.25](https://go.dev/doc/go1.25) (vet `hostport`), [Go 1.26](https://go.dev/doc/go1.26) (`slog.NewMultiHandler`), [Go 1.27](https://go.dev/doc/go1.27) (HTTP/1 body draining).
- The `LoadConfig`, `newServer`, `serve`, `fetch`, `transfer` and `Token` blocks compile, pass `go vet` and run in tests under `-race` in a scratch module (Go 1.26.3, 2026-10-21).
- pkg.go.dev imported-by counts on 2026-10-26: `golang-migrate/migrate/v4` 5,219 and `goose/v3` 1,725; `jackc/pgx/v5` 12,050 and `lib/pq` 57,719; `go-sql-driver/mysql` 55,215; `gorm.io/gorm` 86,926; `jmoiron/sqlx` 27,167; `go.opentelemetry.io/otel` 16,050, `otelhttp` 2,776 and `XSAM/otelsql` 213; `newrelic/go-agent/v3/newrelic` 899. GitHub shows `jackc/pgx` at v5.11.0 (2026-09-07) and `lib/pq` at v1.12.3 (2026-04-03), both active.
- The [pgx README](https://github.com/jackc/pgx#choosing-between-the-pgx-and-databasesql-interfaces) states that `LISTEN` and `NOTIFY` and `COPY` are not available through `database/sql`.
