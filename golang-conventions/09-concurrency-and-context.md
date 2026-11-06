# Go Concurrency and Context

## Summary

Prefer synchronous code. When you start a goroutine, give it an owner, a stop condition and a context. Pick the simplest synchronisation (a mutex or a channel), run the race detector, and test concurrent code without sleeping.

## Rules

### Design

- **Prefer synchronous functions.** A caller can start a goroutine around a synchronous function, but it cannot remove concurrency that is hidden inside one.
- **Give every goroutine an owner and a stop condition.** The owner waits for it (`sync.WaitGroup` or `errgroup`) or the code documents why it exits. Do not fire and forget: a goroutine blocked on a channel is never collected.
- **Bound the concurrency.** Use `errgroup.SetLimit`, a worker pool or a semaphore (`chan struct{}`) for fan-out per request or per row. Call `errgroup` directly where you need it: a shared helper in every repository would only wrap three lines.
- **Choose by purpose:** channels for ownership transfer, pipelines and signals; a mutex for protecting shared state. Use whichever is simpler to read ([Mutex or channel](https://go.dev/wiki/MutexOrChannel)).
- **Never synchronise with `time.Sleep`.**

### Fan-out with errgroup

Use `golang.org/x/sync/errgroup` when the goroutines return errors. It cancels the group's context after the first failure and waits for all goroutines. Each goroutine below writes a different element of `results`, so there is no race.

```go
func processAll(ctx context.Context, items []Item) (results []Result, err error) {
	group, ctx := errgroup.WithContext(ctx)
	results = make([]Result, len(items))
	for position, item := range items {
		group.Go(func() (workErr error) {
			results[position], workErr = process(ctx, item)
			return workErr
		})
	}
	if err = group.Wait(); err != nil {
		return nil, err
	}
	return results, nil
}
```

The usual leak is a results channel that nobody drains after an early `return`: the remaining senders block forever. The Go 1.26 release notes show this case. The version above has no such channel.

When the goroutines return no errors, Go 1.25 adds `sync.WaitGroup.Go`, which replaces the manual `Add` and `Done` calls (`go vet` also reports a misplaced `Add`):

```go
func notifyAll(ctx context.Context, targets []string, send func(ctx context.Context, target string)) {
	var wg sync.WaitGroup
	for _, target := range targets {
		wg.Go(func() { send(ctx, target) })
	}
	wg.Wait()
}
```

### Context

- **Pass `ctx` as the first parameter,** named `ctx`. Do not store a `Context` in a struct, except when a method must match an interface. Do not create custom context types.
- **Never pass a nil context.** Use `context.TODO()` when you are unsure. Call `context.Background()` only at the top: `main`, tests and background jobs.
- **Call `cancel` every time.** Write `defer cancel()` straight after `WithCancel`, `WithTimeout` or `WithDeadline`. `go vet` reports a lost cancel function.
- **Honour cancellation.** Select on `ctx.Done()` in loops and blocking calls, and pass `ctx` to database and HTTP calls (`QueryContext`, `http.NewRequestWithContext`). The `noctx` linter flags requests without a context.
- **Keep context values for request-scoped data** such as a trace ID or the caller's identity, with an unexported key type. Pass everything else as a parameter or a field.
- **Detach work that must outlive the request** with `context.WithoutCancel(ctx)` (Go 1.21+). It keeps the values and drops the cancellation.
- **Record why a context ended** with `context.WithCancelCause` and `context.Cause` (Go 1.20+). `signal.NotifyContext` cancels with a cause that names the signal (Go 1.26).

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
```

### Shared state

- **Use the zero-value mutex.** Declare `mu sync.Mutex` as an unexported field directly above the data it guards. Call `defer mu.Unlock()` straight after `Lock()`. Do not copy a struct that contains a mutex, and do not embed the mutex.
- **Use the typed atomics** (`atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]`, Go 1.19+) for counters and flags instead of the function forms.
- **Use `sync.OnceFunc` and `sync.OnceValue`** (Go 1.21+) for lazy one-time setup.
- **Reach for `sync.Map` and `sync.Pool` only after measuring,** or when the documented use case matches.
- **Run the race detector** (`go test -race`). A data race is a bug even when the tests pass.

```go
type Counter struct {
	mu    sync.Mutex
	count int
}

func (c *Counter) Increment() (count int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.count++
	return c.count
}
```

### Channels

- **Let the sender close the channel,** never the receiver, and only when receivers need the signal (for example `range`).
- **Use directional types in signatures:** `<-chan T` to receive, `chan<- T` to send.
- **Keep the buffer size at 0 or 1.** Any other size needs a reason and a comment.
- **Remember that a nil channel blocks forever.** Use that on purpose in a `select` to disable a case.

### Language changes that remove old workarounds

- **Loop variables:** with `go 1.22` or later in `go.mod`, each iteration has its own variable. Delete `v := v` copies; the `copyloopvar` linter finds them.
- **Timers:** with `go 1.23` or later, timer and ticker channels are unbuffered, and a call to `Reset` or `Stop` never lets a stale value through. Do not drain the channel by hand. Go 1.27 removes the old behaviour completely.

### Tests for concurrent code

- Use `testing/synctest` (generally available since Go 1.25) to test code that uses goroutines, timers and `time.Sleep` without real waiting. Go 1.27 adds `synctest.Sleep`.
- Use `t.Context()` (Go 1.24) for a context that ends when the test ends.
- Do not call `t.Fatal` or `t.FailNow` from any goroutine except the test's own ([testing](10-testing.md)).

### Diagnostics

- Since Go 1.25 the default `GOMAXPROCS` follows the container's CPU limit, so do not add `go.uber.org/automaxprocs` on Go 1.25 or later. Leave an indirect dependency alone.
- Go 1.27 makes the `goroutineleak` profile generally available in `runtime/pprof` and at `/debug/pprof/goroutineleak`. Use it in tests, CI and production to find goroutines that can never resume.

## Sources and raw notes

- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): Contexts, Goroutine Lifetimes, Synchronous Functions, Copying. [Contexts and structs](https://go.dev/blog/context-and-structs).
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md): Channel Size is One or None, Don't fire-and-forget goroutines, Wait for goroutines to exit, Zero-value Mutexes are Valid.
- Release notes: [Go 1.20](https://go.dev/doc/go1.20) (`WithCancelCause`), [Go 1.21](https://go.dev/doc/go1.21) (`WithoutCancel`, `OnceFunc`), [Go 1.22](https://go.dev/doc/go1.22) (loop variables), [Go 1.23](https://go.dev/doc/go1.23) (timers), [Go 1.24](https://go.dev/doc/go1.24) (`T.Context`), [Go 1.25](https://go.dev/doc/go1.25) (`WaitGroup.Go`, `synctest`, `GOMAXPROCS`, vet `waitgroup`), [Go 1.26](https://go.dev/doc/go1.26) (`NotifyContext` cause, leak profile experiment), [Go 1.27](https://go.dev/doc/go1.27) (leak profile, `synctest.Sleep`).
- The `errgroup`, `WaitGroup.Go` and `Counter` blocks compile and pass `go test -race` in a scratch module (Go 1.26.3, 2026-10-21). The scratch module used a local stub of `errgroup`.
