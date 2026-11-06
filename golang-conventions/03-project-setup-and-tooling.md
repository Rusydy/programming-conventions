# Go Project Setup and Tooling

## Summary

Every Go project uses the same small toolchain: `gofmt`, `goimports`, `go vet`, a lint runner on its standard linter set, `govulncheck` and `go test -race`, all run in CI. The configuration stays minimal because the defaults are the convention.

## Rules

### Modules and versions

- Use one `go.mod` per repository. Split into several modules only when the parts are released separately.
- Use the repository URL as the module path, in lower case: `github.com/org/repo`.
- Set the `go` directive to the oldest Go release you test. It selects language semantics (per-iteration loop variables from Go 1.22, for example) and is a hard minimum for the toolchain. From Go 1.26, `go mod init` writes the previous release (a Go 1.27 toolchain writes `go 1.26.0`). Keep that default and raise it on purpose with `go get go@<version>`.
- Raise the `go` directive before you use a newer standard library symbol. Since Go 1.27, `go test` runs the `stdversion` vet check, which reports symbols that are too new for the file's Go version.
- Run `go mod tidy` before every commit that changes imports, and commit `go.mod` and `go.sum`. In CI, run `go mod tidy -diff` (Go 1.23+) to fail on drift. For modules at `go 1.27` or later, `go mod tidy` also keeps at most two `require` blocks, one direct and one indirect.
- Do not vendor dependencies unless the build environment requires it.
- Pin developer tools with `tool` directives (Go 1.24+): `go get -tool honnef.co/go/tools/cmd/staticcheck@latest`, then `go tool staticcheck ./...`. Do not keep a `tools.go` file with blank imports. The module's own toolchain rebuilds a pinned tool, which avoids running an old binary on a new Go release: on 2026-10-21 a `staticcheck` built with Go 1.24.5 refused a module that requires Go 1.26.

### Formatting and imports

- Run `gofmt` on every file and format on save. CI fails when `gofmt -l .` prints anything. Go 1.27 changed gofmt's column alignment slightly, so the first run after an upgrade can produce small whitespace changes; commit them separately.
- Group imports in blocks separated by a blank line, standard library first. Use `goimports` or the editor's organise-imports action to do it.
- Use `gofmt` and `goimports` as the only formatters. `gofumpt` is a second, stricter formatter on top of `gofmt`: it adds a second source of formatting churn, and `gofmt -l` in CI already enforces one format. A repository that already runs `gofumpt` keeps it.
- Rename an import only to resolve a collision. Use blank imports (`import _ "pkg"`) only in `main` and in tests. Do not use dot imports, apart from the rare external-test case that Go Code Review Comments describes.

### Static checks

- `go vet ./...` must pass.
- Lint with golangci-lint v2. Start from `linters.default: standard` and add only linters that pay for themselves. Suggested additions: `errorlint`, `errname`, `bodyclose`, `noctx`, `sqlclosecheck`, `rowserrcheck`, `sloglint`, `gosec`, `misspell`, `copyloopvar`, `intrange` and `modernize`. Do not enable `all`. Set `new-from-rev` so that a repository with an unclean baseline fails only on new findings.
- Keep `nonamedreturns` and `unparam` off ([named parameters and results](02-named-parameters-and-results.md)).
- Enable the `std-error-handling` exclusion preset (`linters.exclusions.presets`). It silences `errcheck` for `Close`, `Flush` and print calls; without it, `defer file.Close()` is reported.
- Keep one `.golangci.yml` that starts with `version: "2"`. Generated files are excluded by default.
- Run `govulncheck ./...` in CI and before each release.
- Run `go test -race ./...` in CI ([testing](10-testing.md)).

### Keeping code modern

- After you raise the `go` directive or upgrade the toolchain, run `go fix ./...` and review the diff in its own commit. Since Go 1.26, `go fix` carries dozens of modernisers and an inliner for API migrations; Go 1.27 adds more.
- Use `go doc <package>.<Symbol>` for quick lookups and `gopls` as the editor language server.

### Automation

- Put plain commands in CI. A `Makefile` is optional and only wraps the same commands.
- Run these checks in this order, locally and in CI:

```bash
test -z "$(gofmt -l .)"
go mod tidy -diff
go vet ./...
golangci-lint run
go test -race -shuffle=on ./...
govulncheck ./...
```

The example below is GitLab CI. Run the checks as three jobs of the `test` stage (trimmed here):

```yaml
test:
  stage: test
  image: golang:1.26-alpine
  services:
    - name: mysql:8.0
      alias: mysql
  variables:
    MYSQL_ALLOW_EMPTY_PASSWORD: "yes"
    TEST_DATABASE_URL: "root@tcp(mysql:3306)/"
  before_script:
    - apk add --no-cache build-base # the race detector needs cgo and a C compiler
  script:
    - test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }
    - go vet ./...
    - go test -race -shuffle=on ./...

lint:
  stage: test
  image: golangci/golangci-lint:v2.15.0-alpine
  script:
    - golangci-lint run

govulncheck:
  stage: test
  image: golang:1.26-alpine
  script:
    - go install golang.org/x/vuln/cmd/govulncheck@v1.9.0
    - govulncheck ./...
```

- Pin the image tags and the `govulncheck` version, and keep the Go image on the same release as the `go` directive.
- Give a job `allow_failure: true` only while its baseline is unclean, and remove the line once it passes.
- An existing project adopts the jobs when a change already touches its CI file.
- The database service container is for tests that need a database ([testing](10-testing.md#test-doubles-and-dependencies)).

## Sources and raw notes

- Release notes: [Go 1.23](https://go.dev/doc/go1.23) (`go mod tidy -diff`), [Go 1.24](https://go.dev/doc/go1.24) (`tool` directive), [Go 1.26](https://go.dev/doc/go1.26) (`go fix` modernisers, `go mod init` default), [Go 1.27](https://go.dev/doc/go1.27) (`stdversion` in `go test`, gofmt alignment, `go mod tidy` blocks).
- golangci-lint documentation, last updated 2026-10-21: [linters](https://golangci-lint.run/docs/linters/), [configuration file](https://golangci-lint.run/docs/configuration/file/), [false-positive presets](https://golangci-lint.run/docs/linters/false-positives/).
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): Gofmt, Imports, Import Blank, Import Dot.
- golangci-lint v2.15.0 was released on 2026-10-16, and gofumpt v0.12.0 on 2026-09-07. The [linters page](https://golangci-lint.run/docs/linters/) describes `unparam` as the linter that reports unused function parameters.
