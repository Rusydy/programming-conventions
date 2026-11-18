# Wails Services and Bindings

## Summary

A service is a small Go type whose exported methods the frontend can call. Keep each service thin and focused, give it its dependencies through a constructor, and treat every exported method as a public API that the webview can reach with any argument. Validate on the Go side, return `(value, err)` with errors that a caller can test, and let `wails3 generate bindings` write the TypeScript.

## Rules

### Services

- Write one service per feature, in the package of that feature (`loan.Service`). A service exposes what the frontend needs and nothing more. Do not write one `AppService` that does everything, which the documentation also warns against.
- Keep a service thin: it validates the input, calls the domain code, logs and returns. Put rules that do not depend on Wails in unexported types of the same package or in their own package, so that plain Go tests reach them ([testing](09-testing-and-quality-gates.md#go-tests)).
- Give the service its dependencies through its constructor, and wire it by hand in `run`: `loan.NewService(logger, publisher, now)`. Do not use a global, a registry or a dependency injection container such as `Wire`. The Wails architecture guide shows Wire, and the Go notes ask for hand wiring.
- Take the clock as a function (`now func() (current time.Time)`) and the logger as a `*slog.Logger`, as the Go notes say, so tests control them.
- Define an interface only where the service consumes something that you need to replace, in the service's own package, and keep it small. The example is the publisher of events:

```go
// Publisher announces events to whoever listens, such as the frontend.
type Publisher interface {
	// Publish sends loan to the listeners of the named event.
	Publish(name string, loan Loan)
}
```

  The `main` package implements it with a few lines that call `app.Event.Emit`, so the domain package does not import Wails ([events and windows](06-events-and-windows.md#events)).
- Do not define an interface for every service, a `UserRepository` interface beside its only implementation, or a `Mock` type for the sake of it. The Go notes define an interface at the consumer, and only when one is needed.
- Guard shared state with a named `sync.Mutex` field. Every window calls the same instance, and two calls can run at the same time. Keep the lock held for short, simple sections, and never embed the mutex, as the Go notes say.
- Name methods as actions in the Go style: `List`, `Create`, `MarkPaid`, not `GetLoans` and `DoCreate`. The Go notes drop the `Get` prefix, and the documentation's `GetUser` is not the style here.
- Keep the methods that the frontend does not need unexported. The generator binds only exported methods of the registered service type, so `helper()` never reaches the frontend.
- Remember that `//wails:ignore` and `//wails:internal` only hide a method from the generated bindings. An exported method of a registered service stays callable from a script in the webview, so they are not access control. Make a method that must not be called from the frontend unexported, or put it on a type that is not registered as a service.

### Bindings

- Generate the bindings with `wails3 generate bindings -ts -i`, which the generated build task runs on every build and `wails3 dev` runs on every change. The flags make TypeScript interfaces for models instead of classes. Do not change the flags without reading the `generate bindings` help.
- Read a binding as the contract. Change the Go signature, regenerate, and let `svelte-check` find every call that no longer fits ([frontend](07-frontend.md#calling-go)).
- Write a doc comment on every exported service method and type. It becomes the JSDoc in the binding, and `Create records a new open loan for borrower with amountMinor minor units.` appears in the editor of the frontend developer. The Go notes already require the comment.
- Name every parameter by meaning, as the Go notes require. The generator reads parameter names from the source, so `Create(borrower string, amountMinor int64)` becomes `Create(borrower: string, amountMinor: number)`. An unnamed parameter becomes `$0`, `$1` and so on in the frontend.
- A `context.Context` first parameter is allowed and is not part of the generated signature: `List(ctx context.Context)` becomes `List()` on the frontend, and the context is cancelled when the call is cancelled. Take one in every method that waits, and honour it, as the [Go concurrency note](../golang-conventions/09-concurrency-and-context.md#context) says.
- Pass related arguments as one struct with JSON tags when a method takes more than about three, as the Go notes say about options structs. It makes the call readable and lets you add a field without breaking callers.
- A bound method's results are `(value, err)`, `err` alone, or a value alone. A method that returns an error rejects the promise on the frontend, and a nil `error` resolves it.
- Do not use these types across the bridge: channels, functions, interfaces other than `any`, and unexported fields. Return an identifier instead of a handle (a file ID, not an `*os.File`).
- Return `[]T` and not a pointer to a slice. A nil slice arrives as `null`, and the generator types every slice result as `T[] | null`, so the frontend must handle `null`. Return an empty slice from Go where you can, and handle the `null` in the client module regardless ([frontend](07-frontend.md#calling-go)).
- Return a pointer when "absent" differs from the zero value (`*string` becomes `string | null`), as the Go notes say for JSON.
- Keep the surface small and batched. A call across the bridge is cheap, but a loop of many calls is slower than one method that takes a slice. Add a `ProcessItems(items []Item)` and not a frontend loop over `ProcessItem`.
- Paginate any method that can return many rows, with a validated page size and a maximum, and do not return a whole table.
- Do not block the bridge with a long task. Run it in a goroutine that you own, report progress with an event and return quickly ([events and windows](06-events-and-windows.md#events)).

### Models and enums

- A struct that crosses the bridge is a plain data type. Put a `json` tag on every field, as the Go notes say, and write a doc comment on the type and each field, which become JSDoc. The generator uses the JSON tag as the property name.
- Keep model structs free of behaviour that the frontend needs. A method on a model is Go-only, and the generator ignores it. A custom `MarshalJSON` on a pointer receiver runs only when the value is addressable, so return a pointer or define it on the value receiver, as the models page says.
- Use a named type with constants for an enum, as the Go notes say, with a deliberate zero value:

```go
// Status is the state of a loan.
type Status string

const (
	// StatusOpen means the loan still has an outstanding balance.
	StatusOpen Status = "open"
	// StatusPaid means the loan is settled.
	StatusPaid Status = "paid"
)
```

  The generator finds it without registration and writes a TypeScript `enum` with an extra `$zero` member for the Go zero value. A named type with a custom `MarshalJSON` or `MarshalText` method, a generic type and a type whose constants cannot be evaluated statically are not turned into enums.
- Send a time as `time.Time` in UTC, as the Go notes say. The generator types it as `string` by default, an RFC 3339 value. Keep that default and convert at the edge of the frontend (`new Date(value)`), or generate `Date` values with `-time-type=Date` in one place, and do not mix the two ([frontend](07-frontend.md#calling-go)).
- Send money as an integer count of minor units with a currency, as the Go notes say, and never as a JSON float. `AmountMinor int64` becomes `number`, which is exact up to 2^53 minor units, so keep an amount that can exceed that as a string.
- Do not return secrets, password hashes, tokens or internal identifiers that the interface does not need. Build a separate view type for what the frontend may see.

### Errors

- A bound method that returns an error rejects the promise with a JavaScript `Error`. The error's `message` is the Go error's message, and its `cause` is the Go error serialised with `encoding/json`. A call with the wrong arguments throws a `TypeError`, and a method that returned an error or panicked throws `Call.RuntimeError`.
- An error made with `errors.New` or `fmt.Errorf` has no exported fields, so its `cause` is an empty object. Give the frontend something to branch on in one of two ways: a sentinel with a message the frontend can show, or an error type with exported, tagged fields:

```go
// ValidationError reports an argument that failed validation.
type ValidationError struct {
	Field  string `json:"field"`
	Reason string `json:"reason"`
}

// Error implements error.
func (e *ValidationError) Error() (message string) {
	return fmt.Sprintf("%s: %s", e.Field, e.Reason)
}
```

- Wrap with `%w`, as the Go notes say, and return an error whose `message` is safe to show to the user. The message crosses the bridge, so it must not hold a secret, a path, an SQL statement or a stack. Log the detail with `slog` and return a message without it.
- Use `ServiceOptions.MarshalError` only when you need full control of the JSON that a failed call produces, for example a stable `{ "type": "validation", "field": "email" }` shape. It must return valid JSON, or `nil` for the default.
- Do not panic to report a failure. Wails recovers a panic in a bound method and sends it to the panic handler, which by default quits the application ([application lifecycle](04-application-lifecycle.md#panics-and-errors)).

### Validation

- Validate every argument in the service, whatever the frontend already checked. Trim and reject empty required fields, bound lengths, check ranges and check that identifiers exist, and return a validation error that the user can act on:

```go
borrower = strings.TrimSpace(borrower)
if borrower == "" {
	return Loan{}, fmt.Errorf("%w: borrower is required", ErrInvalidInput)
}
if amountMinor <= 0 {
	return Loan{}, fmt.Errorf("%w: amount must be above zero", ErrInvalidInput)
}
```

- Keep `ErrInvalidInput` and `ErrNotFound` as exported sentinels in the package, as the Go notes say, and test them with `errors.Is`.
- Validate on the frontend too, for speed and for the user's convenience, with the schema of the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md). The Go check is the one that counts.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Services](https://wails.io/features/bindings/services/): the service model, only exported methods are bound, singletons, locking, constructor injection, the do and do-not list. [Call Go from JavaScript](https://wails.io/features/bindings/methods/): `generate bindings`, the type mapping, unsupported types, the error classes (`TypeError`, `RuntimeError`, `Error`), `cause`, `MarshalError`, batching and events for streaming. [Bindings best practices](https://wails.io/features/bindings/best-practices/): single responsibility, input validation, pagination, batching, descriptive errors, typed errors.
- [Models](https://wails.io/features/bindings/models/): JSON tags, comments as JSDoc, `time.Time` as `string` or `Date`, pointer receivers and `MarshalJSON`, no methods on models. [Enums](https://wails.io/features/bindings/enums/): automatic detection, the `$zero` member, the limitations. [Advanced binding](https://wails.io/features/bindings/advanced/): `//wails:ignore` and `//wails:internal` are not an access-control boundary for exported service methods. [Go-frontend bridge](https://wails.io/concepts/bridge/): a `context.Context` parameter and automatic cancellation.
- Checked on 2026-11-18 in the sample project with `wails3` v3.1.0: `wails3 generate bindings -clean=true -ts -i` reported `1 Service, 3 Methods, 1 Enum, 1 Model, 1 Event` and wrote `Create(borrower: string, amountMinor: number): $CancellablePromise<$models.Loan>`, `List(): $CancellablePromise<$models.Loan[] | null>` and `MarkPaid(id: string)`, with the Go doc comments as JSDoc, `Loan` as an `interface` with the JSON tag names and `createdAt: string`, and `Status` as an `export enum` with `$zero`. A probe `List(ctx context.Context) (loans []Loan, err error)` generated `List()` with no `ctx`, and an unexported `helper()` method gave the same method count. `Service` was the generated export name of `loan.Service`.
- The error classes, the `MarshalError` behaviour, the cancellation of a context and the panic path were not run, because the sample application was not started. They rest on the documentation pages above.
