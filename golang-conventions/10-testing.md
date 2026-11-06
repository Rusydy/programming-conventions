# Go Testing

- Responsibility: engineering
- Area/system: golang
- Keywords: testing, table-driven tests, subtests, t.Run, t.Parallel, go-cmp, cmp.Diff, httptest, fakes, mocks, testdata, golden files, fuzzing, benchmarks, b.Loop, synctest, race detector, coverage, testify, assert library, golang/mock, go.uber.org/mock, TEST_DATABASE_URL, throwaway database, service container
- Aliases: Go test best practice, unit test Go, table test Go, mock Go, assert library Go, pengujian Go
- Status: active
- Last updated: 2026-10-26

Related notes: [named parameters and results](02-named-parameters-and-results.md), [package and API design](06-package-and-api-design.md), [error handling](08-error-handling.md), [concurrency and context](09-concurrency-and-context.md), [tooling](03-project-setup-and-tooling.md).

## Summary

Test with the standard `testing` package. Write table-driven tests with clear failure messages, compare whole values with `go-cmp`, prefer real implementations and small fakes over mocks, and run every test with the race detector. The Go team advises against assertion libraries.

## Rules

### Basics

- Name files `x_test.go` and functions `TestXxx`, `ExampleXxx`, `BenchmarkXxx` and `FuzzXxx`. Name a method test `TestType_Method`.
- Use `package foo_test` for tests that exercise the public API, and an in-package file only for tests that need internals.
- Run `go test -race -shuffle=on ./...` in CI. Add `-count=1` to bypass the test cache. Treat coverage (`-cover`) as a signal, not a target.
- Use the helpers on `*testing.T`: `t.TempDir()`, `t.Setenv()`, `t.Cleanup()`, `t.Context()` and `t.Chdir()` (Go 1.24+), and `t.ArtifactDir()` for output files (Go 1.26+).
- Mark helper functions with `t.Helper()`, so that failures point at the caller's line.

### Table-driven tests

- Use a table when the cases share logic. Write separate test functions when the logic differs. Do not make every table row pass through conditional branches.
- Give each case a descriptive `name`. Never identify a case by its index.
- Call `t.Parallel()` at the top of independent tests and subtests. Since Go 1.22 each loop iteration has its own variable, so no copy is needed.

```go
func TestParseAmount(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    int64
		wantErr error
	}{
		{name: "whole units", input: "10000", want: 1000000},
		{name: "with fraction", input: "10000.50", want: 1000050},
		{name: "empty", input: "", wantErr: ErrEmptyAmount},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := ParseAmount(test.input)
			if !errors.Is(err, test.wantErr) {
				t.Fatalf("ParseAmount(%q) error = %v, want %v", test.input, err, test.wantErr)
			}
			if got != test.want {
				t.Errorf("ParseAmount(%q) = %d, want %d", test.input, got, test.want)
			}
		})
	}
}
```

### Failure messages

- Print the function, its inputs, what it returned and what you expected, in that order: `Func(input) = got, want want`. Put `got` before `want`.
- Keep going after a failed check. Prefer `t.Errorf` to `t.Fatalf`, and use `t.Fatalf` only when the rest of the test cannot run, such as a failed setup or a failed subtest step.
- Never call `t.Fatal` or `t.FailNow` from a goroutine other than the test's own. Use `t.Error` there.

### Assertions and comparisons

- Compare whole values in one step. Build the expected struct and use `cmp.Diff(want, got)` from `github.com/google/go-cmp/cmp`. Label the direction: `(-want +got)`. Do not compare field by field and do not use `reflect.DeepEqual` in new code.

```go
if diff := cmp.Diff(want, got); diff != "" {
	t.Errorf("Build() mismatch (-want +got):\n%s", diff)
}
```

- Check error identity with `errors.Is` and `errors.As`, not by comparing messages. Message text is a poor contract and turns the test into a change detector.
- Do not compare output that you do not control byte for byte, such as `json.Marshal` results. Parse the output and compare the values.
- Do not use assertion libraries (`testify/assert` and similar). The Go Test Comments and the Google style decisions both advise against them, because they stop the test early or hide detail and they add a second language on top of Go. New code does not add `testify`, however widely it is used: this folder follows the Go team. If a project already uses `testify`, follow the project and enable the `testifylint` linter.

### Test doubles and dependencies

- Prefer the real implementation when it is cheap: an in-memory type, `httptest`, `t.TempDir()` or `fstest.MapFS`.
- Otherwise write a small fake behind an interface that the consumer defines ([package and API design](06-package-and-api-design.md#interfaces)). Use generated mocks only when the interaction itself is what you test, and generate them with `go.uber.org/mock`: `github.com/golang/mock` is archived.
- Test HTTP handlers with `httptest.NewRecorder` and `httptest.NewRequest`, and clients with `httptest.NewServer`. Go 1.27 adds `httptest.NewTestServer` for use with `testing/synctest`.
- Test databases against a real, throwaway database server with the migrations applied. CI starts it as a service container of the `test` job ([tooling](03-project-setup-and-tooling.md#automation)) and passes its DSN in `TEST_DATABASE_URL`, and a developer starts the same image with `docker run`. The tests skip when the variable is unset, so they need no build tag. Never point tests at a shared instance. Pin the image to the production major version (`mysql:8.0`, not `latest`). The helper and the command are below the list.
- Give each test its own database with a random name and drop it in `t.Cleanup`, so that packages can test in parallel.
- Control time and randomness. Inject a clock ([time](07-types-and-data.md#time)) or use `testing/synctest` ([tests for concurrent code](09-concurrency-and-context.md#tests-for-concurrent-code)). Inject a seeded `*rand.Rand` from `math/rand/v2` (`rand.New(rand.NewPCG(seed1, seed2))`). For deterministic cryptographic randomness in tests, use `testing/cryptotest.SetGlobalRandom` (Go 1.26+).

```go
// testDSN returns the DSN of a throwaway database server, or skips the test when none is configured.
func testDSN(t *testing.T) (dsn string) {
	t.Helper()
	dsn = os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL is not set")
	}
	return dsn
}
```

```bash
docker run --rm -d --name mysql-test -p 127.0.0.1:3307:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql:8.0
TEST_DATABASE_URL='root@tcp(127.0.0.1:3307)/' go test -race ./...
```

### Fixtures and golden files

- Keep fixtures in `testdata/`. The `go` tool ignores that folder when it builds.
- For golden files, add an `-update` flag that rewrites them, and review the diff of the rewritten files.

### Benchmarks and fuzzing

- Write benchmarks with `for b.Loop() { ... }` (Go 1.24+) instead of `for i := 0; i < b.N; i++`. Go 1.26 fixes the inlining problem, so every benchmark can move to `b.Loop`. Compare runs with `benchstat`.
- Add a fuzz test (`FuzzXxx` with seed inputs through `f.Add`) for every parser and decoder. Run it with `go test -fuzz=FuzzXxx -fuzztime=30s`.

## Sources and raw notes

- [Go Test Comments](https://go.dev/wiki/TestComments): Assert Libraries, Got before Want, Identify the Function and Input, Keep Going, Mark Test Helpers, Print Diffs, Table-Driven Tests vs Multiple Test Functions, Test Error Semantics, Compare Full Structures, Compare Stable Results.
- [Google Go Style Decisions](https://google.github.io/styleguide/go/decisions): Assertion libraries. [Google Go Best Practices](https://google.github.io/styleguide/go/best-practices): Test double and helper packages, t.Error vs. t.Fatal, Don't call t.Fatal from separate goroutines.
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md): Test Tables, Parallel Tests.
- [Table-driven tests](https://go.dev/wiki/TableDrivenTests), [Go fuzzing](https://go.dev/doc/security/fuzz/), [Go data race detector](https://go.dev/doc/articles/race_detector).
- Release notes: [Go 1.24](https://go.dev/doc/go1.24) (`T.Context`, `T.Chdir`, `B.Loop`), [Go 1.26](https://go.dev/doc/go1.26) (`T.ArtifactDir`, `B.Loop` inlining, `cryptotest.SetGlobalRandom`), [Go 1.27](https://go.dev/doc/go1.27) (`httptest.NewTestServer`).
- The table test compiles and passes in a scratch module (Go 1.26.3, 2026-10-21).
- pkg.go.dev imported-by counts on 2026-10-26: `testify/assert` 16,016, `testify/require` 20,797, `go-cmp/cmp` 5,704, `go.uber.org/mock/gomock` 7,360 and `golang/mock/gomock` 24,772. The GitHub API shows `golang/mock` as archived (last push 2024-01-08) and `uber-go/mock` as active (last push 2026-08-25).
- The `testDSN` helper compiled and skipped as intended in a scratch module on 2026-10-26 (Go 1.26.3, `go vet` and `go test -race -shuffle=on`). The `docker run` command was not run, because Docker was not running that day.
