# Go Naming, Comments and Code Style

## Summary

Names and comments carry most of the readability in Go. Use MixedCaps, short names for short scopes, names that read well at the call site, and doc comments that start with the name they describe. Keep the normal path left-aligned by handling errors first.

## Rules

### Identifiers

- **Use MixedCaps.** Write `maxRetries` or `MaxRetries`, never `max_retries` or `MAX_RETRIES`, even for constants. A leading capital exports the name.
- **Keep initialisms in one case:** `ServeHTTP`, `userID`, `parseURL`, `xmlHTTPRequest`. Never `ServeHttp`, `userId` or `parseUrl`.
- **Match the name length to the scope.** Use `i`, `r`, `ctx` and `err` within a few lines. Use descriptive names for package-level identifiers and for anything used far from its declaration.
- **Name receivers with one or two letters** taken from the type (`c` for `Client`) and use the same name in every method. Never use `this`, `self` or `me`.
- **Drop `Get` from getters.** Write `user.Name()` and `user.SetName(name)`.
- **Name one-method interfaces after the method** plus `-er`: `Reader`, `Closer`, `Stringer`. Do not prefix with `I` and do not suffix with `Interface` or `Impl`.
- **Prefix sentinel errors** with `Err` (`ErrNotFound`), or `err` when unexported, and **suffix error types** with `Error` (`ValidationError`). The `errname` linter checks both.
- **Do not shadow predeclared names** such as `len`, `new`, `error`, `string`, `copy`, `min`, `max` and `clear`, or the names of imported packages.
- **Avoid unexplained literals at call sites.** `Run(ctx, true, false)` says nothing. Use a named type, a small options struct or two functions ([package and API design](06-package-and-api-design.md#functions-and-methods)).

### Packages

- Use short, lower-case, single-word names without underscores or capitals. The last element of the import path is the package name.
- Name the package for what it provides and read it together with the identifier: `http.Server`, `bytes.Buffer`. Do not repeat the package name in the identifier (`loan.LoanService`). A type that is the package's subject may share the name (`list.List`).
- Avoid catch-all names ([project layout](04-project-layout.md#rules-for-folders-and-packages)) and names that local variables commonly use, such as `count`.

### Doc comments and other comments

- Write comments and doc comments in English, with American spelling. The standard library documents itself that way and its identifiers follow (`Normalize`, `color`), so a comment that spells a word like its identifier turns up in the same search.
- Write a doc comment for every exported name and every non-trivial unexported type or function. Start with the name, write full sentences and end with a full stop: `// Encode writes the JSON encoding of req to w.`
- Put the package comment directly above the `package` clause: `// Package loan calculates repayment schedules.` For a command, start with `// Command <name> ...`.
- Use the Go doc comment syntax (headings, lists, links, indented code blocks). `gofmt` reformats doc comments to match it.
- Mark deprecated identifiers with a paragraph that starts with `Deprecated:`.
- Explain why, not what. Record constraints, trade-offs and surprising behaviour. Delete commented-out code, because version control keeps the history.
- Write `TODO(owner): ...` with an owner or a ticket.
- Add a runnable `ExampleXxx` function for each new package, so that `go test` checks the usage.

### Code layout

- **Keep the normal path left-aligned.** Handle the error first and return. Do not write `else` after a `return`.

```go
x, err := f()
if err != nil {
	return err
}
// use x
```

- **Declare variables near their first use** and keep the scope small. Use `if v, ok := m[key]; ok { ... }` when the variable is not needed afterwards.
- **Use `var` for zero values and `:=` for initialised values:** `var buf bytes.Buffer`, `count := len(items)`. Declare an empty slice as `var items []Item` ([types and data](07-types-and-data.md#slices-and-maps)).
- **Name the fields in struct literals** and omit fields that are zero unless the zero value is meaningful: `User{ID: id, Name: name}`.
- **Prefer `switch`** to a chain of `else if`, and a tagless `switch` for conditions.
- **Count with `for i := range n`** (Go 1.22+). Write `for range n` when the index is unused.
- **Write `any`** instead of `interface{}`.
- **Pass constant format strings** to `Printf`-style functions. Since Go 1.24, `go vet` reports non-constant ones. Use `%w` only in `fmt.Errorf`.
- **Use `strconv`** for simple conversions between numbers and strings instead of `fmt.Sprintf`.
- **Do not wrap lines to hit a length.** Go has no line-length limit. Break a line where the meaning breaks, and shorten names when lines grow too long. Apply the same thinking to function length: split at real boundaries, not at a line count.
- **Keep one concern per function.** Split a function that mixes levels of abstraction, but do not scatter it into tiny helpers that hide the flow.

### Constants and enums

- Group related constants in a `const (...)` block, give them a type and name them in MixedCaps. [Types and data](07-types-and-data.md#enums-and-constants) covers enums.

## Sources and raw notes

- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): Mixed Caps, Initialisms, Receiver Names, Package Names, Package Comments, Comment Sentences, Doc Comments, Indent Error Flow, Variable Names, Line Length.
- [Effective Go](https://go.dev/doc/effective_go): getters and interface names. [Go Doc Comments](https://go.dev/doc/comment). [Go 1.19 release notes](https://go.dev/doc/go1.19): `gofmt` reformats doc comments. [Go 1.24 release notes](https://go.dev/doc/go1.24): the `printf` vet check reports non-constant format strings.
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md): Error Naming, Avoid Using Built-In Names, Prefer strconv over fmt, Reduce Scope of Variables, Avoid Naked Parameters.
- [golangci-lint linters](https://golangci-lint.run/docs/linters/): `errname`.
