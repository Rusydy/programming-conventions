# Named Parameters and Results (Personal Override)

- Responsibility: engineering
- Area/system: golang
- Keywords: named parameters, named results, named return values, naked return, godoc, nonamedreturns, personal override, function signature, deferred closure, shadowing, namecheck, unused parameter, blank identifier, unparam
- Aliases: name every parameter, name every return value, return value names, penamaan parameter dan return, single result parentheses, unnamed result
- Status: active
- Last updated: 2026-10-26

Related notes: [principles and sources](01-principles-and-sources.md), [error handling](08-error-handling.md), [static checks](03-project-setup-and-tooling.md#static-checks).

## Summary

Every Go function, method, interface method, function type and function literal names each parameter and each result. A single result also goes in parentheses. This rule deviates on purpose from the Go team's guidance, which prefers unnamed results unless the names add information. Every code example in this folder follows the rule.

## Rules

### The rule

- Name every parameter and every result.
- Put results in parentheses, even when there is only one: `(table map[rune]rune)`.
- Name by meaning, not by type: `(user *User, err error)`, `(found bool)`, `(lat, lng float64)`.
- Name receivers as well, as the [naming note](05-naming-comments-and-style.md#identifiers) already requires. An unused receiver keeps its name.
- Keep the name when the body ignores a parameter, and never write `_` instead. Go accepts unused parameters, and the `unparam` linter that reports them stays off ([tooling](#tooling)). The name still tells the reader what a callback or an interface method receives.

```go
func (s *Store) Find(ctx context.Context, id string) (user *User, err error)

func buildLookup(names []string) (index map[string]int)

type Option func(cfg *config)

type Reader interface {
	Read(p []byte) (n int, err error)
}
```

Function literals follow the same rule: `func(w http.ResponseWriter, r *http.Request) { ... }`. A parameter that the body ignores keeps its name:

```go
// ServeHTTP answers every request with no content; r keeps its name although the body ignores it.
func (h *Health) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}
```

### Writing the body

Assign to a named result; do not declare it again. The result lives in the function's outermost scope, so a second declaration clashes with it.

```go
func buildLookup(names []string) (index map[string]int) {
	index = make(map[string]int, len(names))
	for position, name := range names {
		index[name] = position
	}
	return index
}
```

The compiler (Go 1.26.3) rejects the three usual slips:

- `index := make(...)` fails with `no new variables on left side of :=`.
- `var index map[string]int` fails with `index redeclared in this block`.
- A bare `return` after an inner `err :=` fails with `result parameter err not in scope at return`.

### Explicit returns

- End every function with `return value`, naming the values. Avoid naked returns: they hide what leaves the function, and the Go team accepts them only in functions of a handful of lines.
- Assign to results with `=` inside nested blocks, for example `if err = row.Scan(...); err != nil`.

### Deferred closures

A named result lets a deferred function change what the caller receives. The Go team also recommends naming for this case.

```go
func writeReport(path string, body []byte) (err error) {
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("create report %q: %w", path, err)
	}
	defer func() { err = errors.Join(err, file.Close()) }()

	_, err = file.Write(body)
	return err
}
```

`errors.Join` returns `nil` when both errors are `nil`, keeps the write error when only the write failed, and adds the close error when both failed. See [error handling](08-error-handling.md) for the wider rules.

### Where the rule does not apply

- **Generated files** (protobuf, mocks, `stringer`): the next generation overwrites edits.
- **Existing functions:** leave them alone unless someone asks for a clean-up, so diffs stay small ([principles](01-principles-and-sources.md#applying-the-notes)).
- **Repositories with their own rule:** follow the repository's documented convention first. Where it is silent, apply this rule to the code you write ([principles](01-principles-and-sources.md#applying-the-notes)).

### Tooling

- Keep the `nonamedreturns` linter off. It reports every named result. Keep `unparam` off as well. It reports unused function parameters.
- Check the whole rule with a `go/ast` walk that reports any `FuncType` field without a name and any name that is `_`. This program does it; save it as `namecheck/main.go` and run `go run ./namecheck file.go ...`.

```go
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
)

func main() {
	failed := false
	for _, path := range os.Args[1:] {
		fset := token.NewFileSet()
		file, err := parser.ParseFile(fset, path, nil, 0)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		ast.Inspect(file, func(node ast.Node) (descend bool) {
			funcType, ok := node.(*ast.FuncType)
			if !ok {
				return true
			}
			for _, fields := range []*ast.FieldList{funcType.Params, funcType.Results} {
				if fields == nil {
					continue
				}
				for _, field := range fields.List {
					if len(field.Names) == 0 {
						fmt.Printf("%s: unnamed parameter or result\n", fset.Position(field.Pos()))
						failed = true
					}
					for _, name := range field.Names {
						if name.Name == "_" {
							fmt.Printf("%s: blank parameter or result name\n", fset.Position(name.Pos()))
							failed = true
						}
					}
				}
			}
			return true
		})
	}
	if failed {
		os.Exit(1)
	}
}
```

## Trade-offs

- Go Code Review Comments and the Google Go Style Guide advise against names that only repeat the type, such as `(node *Node)`, because godoc then repeats them. They recommend names when two results share a type, when the meaning is unclear, when the caller must act on a result (a cancel function, for example), and when a deferred closure changes a result.
- This rule accepts the repetition in exchange for uniform signatures that read the same everywhere.
- Signatures become longer. Choose names that add meaning (`user`, `found`, `rows`) so the extra words earn their place.

## Sources and raw notes

- [Go Code Review Comments: Named Result Parameters](https://go.dev/wiki/CodeReviewComments) and the matching passage in the [Google Go Style Decisions](https://google.github.io/styleguide/go/decisions).
- [golangci-lint linters](https://golangci-lint.run/docs/linters/): `nonamedreturns` "reports all named returns", and `unparam` "reports unused function parameters" (page read again on 2026-10-26).
- Compiler messages and the `namecheck` program were checked with Go 1.26.3 on 2026-10-21. On 2026-10-26 the `_` check was added and tested on a sample with a blank name, an unnamed parameter and unnamed results (four reports, exit status 1); the program reports nothing on its own source.
