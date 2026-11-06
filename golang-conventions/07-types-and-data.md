# Go Types and Data Handling

## Summary

Use the zero value, nil slices and the `slices` and `maps` packages. Model enums as typed constants, keep instants in UTC as `time.Time`, never store money as `float64`, and tag serialised fields explicitly.

## Rules

### Slices and maps

- Declare an empty slice as `var s []T` (nil). Test emptiness with `len(s) == 0`, not `s == nil`. Use `[]T{}` only when a non-nil empty value matters, for example JSON `[]` instead of `null`. An API should not treat a nil slice and an empty slice differently.
- Pre-size when the size is known: `make([]T, 0, n)` and `make(map[K]V, n)`.
- Initialise a map before you write to it, because a write to a nil map panics. Reading a nil map is safe.
- Do not rely on map order. Iteration order is random. Sort the keys when the output must be stable: `slices.Sorted(maps.Keys(m))` (Go 1.23+).
- Use the `slices` and `maps` packages (Go 1.21+) instead of hand-written loops and `sort.Slice`: `slices.Contains`, `slices.Index`, `slices.SortFunc`, `slices.BinarySearch`, `slices.Clone`, `slices.DeleteFunc` and `maps.Clone`. Compare with `cmp.Compare` and use the built-ins `min`, `max` and `clear`.
- Remember that a sub-slice shares the backing array. Clone it (`slices.Clone`) before you keep or modify a slice that you did not create.
- Use the comma-ok form to tell a missing key from a zero value: `v, ok := m[key]`.

### Strings and bytes

- Build strings in loops with `strings.Builder`, and join with `strings.Join`.
- Split with `strings.Cut`, `strings.CutPrefix` and `strings.CutSuffix` (and `strings.CutLast` in Go 1.27) instead of `Index` and manual slicing. Iterate without allocating a slice by using `strings.SplitSeq` and `strings.Lines` (Go 1.24).
- Use raw string literals for regular expressions and for embedded SQL or JSON, so that nothing needs escaping.
- `len(s)` counts bytes. Range over a string to get runes, and use `unicode/utf8` to count them.

### Enums and constants

- Model an enum as a named type with typed constants and `iota`. Make the zero value deliberate: start at 1, or reserve 0 as `Unknown`, unless the zero value is the sensible default.
- Give the type a `String()` method (generate it with `stringer` through `go generate`) and validate values that arrive from outside.
- Name constants for domain values. Avoid magic numbers and strings in logic.

```go
type Status int

const (
	StatusUnknown Status = iota
	StatusPending
	StatusPaid
)

func (s Status) String() (name string) {
	switch s {
	case StatusPending:
		return "pending"
	case StatusPaid:
		return "paid"
	default:
		return "unknown"
	}
}
```

### Time

- Use `time.Time` for instants and `time.Duration` for periods. Do not pass bare integers for seconds or milliseconds. When an external format forces an integer, put the unit in the name (`timeoutSeconds`).
- Store and transmit instants in UTC, formatted as RFC 3339 (`time.RFC3339`). Convert to a zone only at the edge, for example with `time.LoadLocation("Asia/Jakarta")`. Do not depend on `time.Local` on servers.
- New services and new tables store UTC. An existing table keeps the zone it was written in, and nobody converts its rows without a migration.
- Make the zone explicit in the connection, not in the process: put `parseTime=true&loc=UTC` in a `go-sql-driver/mysql` DSN, and use `timestamptz` columns in PostgreSQL ([PostgreSQL wiki, Don't Do This](https://wiki.postgresql.org/wiki/Don%27t_Do_This)). Do not rely on `loc=Local` or on the `TZ` variable.
- Compare with `Before`, `After` and `Equal`, not `==`.
- Inject the clock (`func() time.Time`) instead of calling `time.Now()` deep in the logic, so that tests control time. For goroutines and timers, use `testing/synctest` ([tests for concurrent code](09-concurrency-and-context.md#tests-for-concurrent-code)).

### Money and numbers

- Never use `float64` or `float32` for money. Binary floating point cannot represent most decimal fractions exactly.
- Store money as integer minor units (`int64`) together with an explicit currency, or use a decimal type from a vetted library or `math/big`. Document the rounding rule and apply it in one place.
- Use `shopspring/decimal` for rates, interest and rounding that integer arithmetic cannot express. The services already use it, and it has far more importers than the alternatives (40,713, against 259 for `cockroachdb/apd` and 94 for `govalues/decimal`).
- Existing code may hold amounts as `float64`. Replace those fields with `decimal.Decimal` or `int64` minor units when a change touches them, and keep the wire format a decimal string.
- Use `int64` explicitly for money and for identifiers that cross systems. Parse with `strconv.ParseInt(text, 10, 64)` and check the error.
- Agree the wire format for amounts with the other system (integer minor units or a decimal string). Never send amounts as JSON floating-point numbers.

```go
// Amount is a monetary value in minor units of one currency.
type Amount struct {
	Minor    int64
	Currency string // ISO 4217 code, for example "IDR"
}
```

### JSON and struct tags

- Tag every serialised field with its wire name: `json:"loan_code"`. Do not rely on field-name matching.
- Use `omitzero` (Go 1.24+) for `time.Time` and struct fields, because it omits Go zero values, including the zero time. `omitempty` omits only empty values (0, "", nil and empty collections) and keeps a zero `time.Time`.
- Use a pointer field only when "absent" differs from the zero value. Since Go 1.26, `new` accepts an expression: `Note: new("manual review")`.

```go
type LoanPayload struct {
	Code   string    `json:"loan_code"`
	Amount int64     `json:"amount_minor"`
	PaidAt time.Time `json:"paid_at,omitzero"`
	Note   *string   `json:"note,omitempty"`
}
```

- Decode untrusted input with `json.NewDecoder`, call `DisallowUnknownFields()` for strict inputs, and limit the body size ([HTTP servers](11-service-practices.md#http-servers)).
- Keep using `encoding/json`. In Go 1.27 it runs on the new v2 implementation, so error message text can differ, and `encoding/json/v2` is generally available. Migrate only with a reason ([modern Go by release](12-modern-go-by-release.md)).
- In tests, compare parsed values, not raw JSON strings ([assertions and comparisons](10-testing.md#assertions-and-comparisons)).

### Pointers and nil

- Use pointers for mutation, large structs and optional values. Do not use pointers to slices, maps or interfaces.
- When "not found" is possible, return an extra `ok bool` or an error instead of an in-band value such as `""` or `-1`. Do not return `nil, nil`; the `nilnil` linter checks it.
- Use `sync.OnceValue` for lazy one-time initialisation instead of package-level `init`.
- Avoid `unsafe`, `reflect` and `cgo` outside small, well-tested packages. Prefer generics and interfaces.

## Sources and raw notes

- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): Declaring Empty Slices, In-Band Errors.
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md): Start Enums at One, Use time to handle time, Prefer Specifying Container Capacity, Use Raw String Literals to Avoid Escaping.
- Release notes: [Go 1.21](https://go.dev/doc/go1.21) (`slices`, `maps`, `min`, `max`, `clear`, `sync.OnceValue`), [Go 1.23](https://go.dev/doc/go1.23) (iterator functions), [Go 1.24](https://go.dev/doc/go1.24) (`omitzero`, `strings.SplitSeq`, `strings.Lines`), [Go 1.26](https://go.dev/doc/go1.26) (`new` with an expression), [Go 1.27](https://go.dev/doc/go1.27) (`strings.CutLast`, `encoding/json/v2`).
- The money rule is general engineering practice, not a Go-specific source.
- pkg.go.dev imported-by counts on 2026-10-26: `shopspring/decimal` 40,713, `cockroachdb/apd/v3` 259, `govalues/decimal` 94.
- [go-sql-driver/mysql README](https://github.com/go-sql-driver/mysql#loc): `loc` defaults to `UTC`. [PostgreSQL wiki, Don't Do This](https://wiki.postgresql.org/wiki/Don%27t_Do_This): do not use `timestamp` (without time zone), not even to store UTC times.
