# Go Package and API Design

- Responsibility: engineering
- Area/system: golang
- Keywords: interfaces, accept interfaces return structs, constructors, functional options, options struct, receivers, pointer receiver, embedding, generics, zero value, init, global state, dependency injection, Impl suffix, Java-style Go, compile-time interface check
- Aliases: desain API Go, Go interface design, Go constructor pattern, Go dependency injection, Go package design, idiomatic Go design
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [project layout](04-project-layout.md), [naming and style](05-naming-comments-and-style.md), [types and data](07-types-and-data.md), [error handling](08-error-handling.md), [testing](10-testing.md).

## Summary

Export little, define interfaces where they are used, return concrete types, pass dependencies through constructors and keep package-level state out. Small, concrete packages stay easier to read and to test than layered abstractions.

## Rules

### Packages and state

- **Export the minimum.** Everything that is not part of the intended API stays unexported or moves into `internal/`.
- **Give a package one responsibility** that its name states ([project layout](04-project-layout.md)).
- **Point dependencies in one direction.** Core packages do not import adapters; adapters import core. When two packages need each other, extract the shared concept into a third package or merge them. Go forbids import cycles.
- **Avoid mutable package-level state:** database handles, loggers, configuration, HTTP clients and singletons. Pass them through constructors and struct fields. Constants, sentinel errors, compiled regular expressions (`regexp.MustCompile`) and read-only lookup tables are fine.
- **Avoid `init()`.** Use it only to register drivers or codecs. Never perform I/O, read the environment or start goroutines in `init`. Blank imports belong in `main` and in tests.
- **Wire dependencies by hand** in `main` and `run`. Consider a dependency injection tool only when manual wiring becomes unmanageable, and record the reason.

### Constructors and options

- **Make the zero value useful** (`sync.Mutex`, `bytes.Buffer`). When it cannot be useful, provide `NewX` and document that the zero value is not ready.
- **Name constructors `NewX`,** or `New` when the package has one main type. Return the concrete type: `*X`, or `(*X, error)` when validation or I/O can fail. Validate in the constructor, so that a value that exists is valid.
- **Pass required dependencies as parameters.** Group optional settings in a config struct, or use functional options when the API is public and likely to grow.

```go
type Option func(cfg *config)

func WithTimeout(timeout time.Duration) (option Option) {
	return func(cfg *config) { cfg.timeout = timeout }
}

func NewClient(baseURL string, options ...Option) (client *Client) {
	cfg := config{timeout: 10 * time.Second}
	for _, option := range options {
		option(&cfg)
	}
	return &Client{baseURL: baseURL, timeout: cfg.timeout}
}
```

### Functions and methods

- **Avoid boolean parameters that switch behaviour.** `Run(ctx, true)` is unreadable at the call site. Use two functions, a named type (`DryRun`) or an options struct.
- **Prefer synchronous functions.** Let the caller start a goroutine when it wants concurrency; removing concurrency from a callee is hard.
- **Choose receivers consistently.** Use a pointer receiver when the method mutates the receiver, when the struct holds a `sync.Mutex` or a similar field, or when the struct is large. Use a value receiver for small immutable values and for map, func and chan types. Do not mix pointer and value receivers on one type. When unsure, use a pointer.
- **Do not pass pointers to save bytes.** Pass `string`, slices and interface values directly, never `*string` or a pointer to an interface.
- **Copy at the boundary.** Clone slices and maps that you store from a caller or hand out from internal state.
- **Do not copy** values whose methods have pointer receivers or that contain a lock. `go vet` reports copied locks.
- **Embed with care.** Embedding promotes methods and fields into your API, so avoid it in exported structs. Do not embed `sync.Mutex`, even in an unexported struct; use a named `mu` field.

### Interfaces

- **Define interfaces in the package that uses them,** not in the package that implements them. The implementing package returns concrete types.
- **Keep interfaces small,** one to three methods, listing only what the consumer calls.
- **Create an interface only when it has a user.** Do not create one just to mock. Design the API so that tests can use the real implementation or a small fake ([testing](10-testing.md)).
- **Accept interfaces, return concrete types.** Standard interfaces (`io.Reader`, `io.Writer`, `fs.FS`, `http.Handler`, `fmt.Stringer`) make functions easy to reuse and test.
- **Check implementation at compile time** when a type must satisfy an interface: `var _ http.Handler = (*Server)(nil)`.
- **Never return a typed nil pointer as an interface value,** including `error`. Return the literal `nil`, because a nil pointer inside an interface compares as non-nil ([Go FAQ](https://go.dev/doc/faq#nil_error)).
- **Use the comma-ok form** for type assertions unless a panic is intended.

```go
// loanFinder lists only what Reporter needs, so the consumer owns the interface.
type loanFinder interface {
	FindLoan(ctx context.Context, code string) (loan *Loan, err error)
}

func NewReporter(loans loanFinder) (reporter *Reporter) {
	return &Reporter{loans: loans}
}
```

### Generics

- Use generics for containers and algorithms that work on many types, the way `slices` and `maps` do. Prefer a plain function or an interface when only one or two concrete types exist.
- Constrain with `comparable`, `cmp.Ordered` or a small interface. Name type parameters `T`, `K`, `V` or a short word such as `Elem`.
- Go 1.27 lets a method declare its own type parameters. Interface methods cannot, and a generic method cannot satisfy an interface method. Use the feature when the operation belongs to the type, as `(*Rand).N` in `math/rand/v2` does.

### Habits from other ecosystems

| Habit | Idiomatic Go |
| --- | --- |
| `UserService` interface plus `UserServiceImpl` struct in `user_service_impl.go` | One concrete `Service` type. Add a small interface in the consumer only when a second implementation or a test seam needs it |
| `IUserRepository`, `UserRepositoryInterface` | A consumer-defined interface named for behaviour (`userFinder`), with no `I` prefix and no `Interface` suffix |
| Constructors that return interfaces | Return `*Service`; the consumer defines the interface |
| `GetName()` and `SetName()` on every field | Export the field when no rule guards it; use `Name()` when you must hide it |
| `MAX_RETRIES`, `DATE_PATTERN` | `maxRetries`, `datePattern` |
| Layer packages `controller`, `service`, `repository`, `model` | Packages by responsibility: `loan`, `report`, `auth` |
| Singletons and reflection-based DI containers | Constructor injection wired by hand in `main` |
| `util`, `common`, `helper` packages | A named package for the concept, or an unexported function beside its caller |
| Exceptions for control flow (`panic` and `recover`) | Return an `error`; panic only for programmer errors |
| A `ternary(condition, a, b)` helper | `if` and `else`; `cmp.Or`, `min` and `max` cover the common cases |
| Log and rethrow at every layer | Wrap with context and log once at the boundary ([error handling](08-error-handling.md)) |
| Deep type hierarchies through embedding | Composition and small interfaces |

The table applies to new code. Leave an existing `*_impl.go` pair, an interface and its implementation, until a change rewrites that component. Then collapse the pair into one concrete type, and let the consumer define the interface ([principles](01-principles-and-sources.md#applying-the-notes)).

## Sources and raw notes

- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): Interfaces, Receiver Type, Pass Values, Copying, Synchronous Functions.
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md): Verify Interface Compliance, Pointers to Interfaces, Zero-value Mutexes are Valid, Copy Slices and Maps at Boundaries, Avoid Mutable Globals, Avoid init(), Avoid Embedding Types in Public Structs, Functional Options.
- [Google Go Best Practices](https://google.github.io/styleguide/go/best-practices): Option structure, Variadic options, Global state.
- [Go 1.27 release notes](https://go.dev/doc/go1.27): generic methods.
