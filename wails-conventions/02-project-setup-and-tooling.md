# Wails Project Setup and Tooling

## Summary

Install the platform dependencies once with `wails3 setup`, then create a project with `wails3 init -t svelte`. Pin the CLI in `go.mod` with a `tool` directive, so that it matches the library, and install it with `go install tool`. Run the Go checks on named packages and not on `./...`, because the frontend's `node_modules` contains a Go package. Bring the frontend to the baseline of the Svelte notes.

## Rules

### Dependencies

- Wails v3 supports Windows (amd64, arm64), macOS (Intel and Apple Silicon, with a 12.0 deployment target in the generated build) and Linux (amd64, arm64, tested on Ubuntu 24.04).
- Install Go 1.26 or later. Wails selects a Go 1.26 toolchain, so an older Go with `GOTOOLCHAIN=auto` may download it. Check that `~/go/bin` is on your `PATH`.
- Install Node.js and npm for the frontend. The bundled templates call npm, and another package manager works if you change the `PACKAGE_MANAGER` variable in `Taskfile.yml`.
- macOS needs the Xcode command line tools (`xcode-select --install`). Windows needs the WebView2 runtime, which almost every installation has. Linux needs `gcc` plus `gtk4` and `webkitgtk-6.0`. The GTK3 stack with the `gtk3` build tag is a legacy option that v3.1 removes.
- Run `wails3 setup` once after you install the CLI. It checks the platform dependencies, asks for the author and the bundle identifier prefix, and can set up Docker and code signing. The documentation marks it as new and mostly tested on Linux, so use `wails3 doctor` to check the result. `wails3 doctor` also belongs in every bug report.

### The Wails CLI

- Pin the CLI to the version of the library in `go.mod`, as the [Go notes](../golang-conventions/03-project-setup-and-tooling.md#automation) pin tools. In the project folder:

```bash
go get -tool github.com/wailsapp/wails/v3/cmd/wails3
go install tool
```

- `go get -tool` adds `tool github.com/wailsapp/wails/v3/cmd/wails3` to `go.mod`, at the version that the module already requires, and `go install tool` puts `wails3` into `GOBIN`. `go tool wails3 version` also works. The generated Taskfiles call a bare `wails3`, so `GOBIN` (by default `~/go/bin`) must be on `PATH`. In the sample project the command printed `v3.1.0`.
- The directive adds many indirect requirements to `go.mod`, because the CLI has its own dependencies. That is the cost of a pinned version, and `go mod tidy` keeps it consistent.
- The documentation installs the CLI with `go install github.com/wailsapp/wails/v3/cmd/wails3@v3.0.0`. Use that form for the first install, or on a machine that has no project yet.
- Wails v2 has its own CLI, `wails`, and its own module path. Both can be on one machine.
- After any CLI upgrade, run `wails3 task common:update:build-assets` only when you want the build files regenerated. It overwrites hand edits in `build/`.

### Creating a project

- List the templates with `wails3 init -l`. The built-in ones are `vanilla` (the default), `vanilla-js`, `react`, `react-js`, `svelte`, `svelte-js`, `vue`, `vue-js` and `ios`. Use `svelte`, which is Svelte, TypeScript and Vite.
- Create the project with the module path and the bundle identifier set, and quote what you want in the product fields:

```bash
wails3 init -n loansapp -t svelte -mod example.com/loansapp \
  -productidentifier com.example.loansapp -d .
```

- The project folder is the `-d` folder joined with the name, so `-d .` creates `./loansapp`. The module path follows the Go notes: the import path of the repository.
- Use `-nocolour` in scripts and CI, and `-git` to set the repository URL.
- Edit `build/config.yml` first: `companyName`, `productName`, `productIdentifier`, `description`, `copyright` and `version`. These values feed the bundle, the installer and the signing, and the generated defaults (`My Company`, `com.mycompany.myproduct`) must not reach a release. Then run `wails3 task common:update:build-assets` once to rewrite the platform files from them.
- Keep the generated `.gitignore` (`.task`, `.wails`, `bin`, `frontend/dist`, `frontend/node_modules`).
- The template writes `go 1.26.0` and `require github.com/wailsapp/wails/v3 v3.1.0`. Do not lower the `go` directive, and follow the Go notes on raising it.

### Go checks

- Follow the [Go notes](../golang-conventions/03-project-setup-and-tooling.md) for formatting, `go vet`, golangci-lint, `govulncheck` and `go test -race -shuffle=on`.
- Run the checks on the packages that you wrote, not on `./...`. The pattern `./...` also matches `build/android/scripts/deps`, `build/ios` and the Go package inside `frontend/node_modules` (the `flatted` package), so it vets and tests code that you do not own. Use `. ./internal/...`:

```bash
gofmt -l . | grep -v '^build/'
go vet . ./internal/...
go test -race -shuffle=on . ./internal/...
```

- `gofmt -l .` lists the files under `build/ios/`, which the template does not format. Leave them alone, because they are generated, and filter them out of the check.
- A cgo test run on macOS prints `ld: warning: object file ... was built for newer 'macOS' version` for every object. It is harmless. Set `CGO_CFLAGS=-mmacosx-version-min=12.0` and `CGO_LDFLAGS=-mmacosx-version-min=12.0` to match the generated build and silence it.
- Point golangci-lint at the same packages, and exclude `build/`, `frontend/` and `bin/` in its config.
- Keep the `nonamedreturns` and `unparam` linters off, as the Go notes say. The generator reads parameter names from the Go source and carries them into the TypeScript signatures, so named parameters make the frontend API readable (`Create(borrower: string, amountMinor: number)`).

### Frontend checks

- Bring `frontend/` to the baseline of the Svelte notes ([frontend](07-frontend.md#frontend-baseline)), and run its checks from the `frontend` folder: `npm run check`, `npm run lint`, `npm run format:check` and `npm test`.
- Remember that `frontend/bindings/` must exist before these checks run. Generate it with `wails3 generate bindings -ts -i` ([project layout](03-project-layout.md#generated-files)).

### Scripts

- Use the `Taskfile.yml` of the project for everything about building, and add the checks as tasks next to it, so that one command runs them all. Add a `check` task to the root `Taskfile.yml`:

```yaml
  check:
    summary: Runs every check
    cmds:
      - gofmt -l . | grep -v '^build/' | (! grep .)
      - go vet . ./internal/...
      - go test -race -shuffle=on . ./internal/...
      - wails3 generate bindings -clean=true -ts -i
      - git diff --exit-code frontend/bindings
      - cd frontend && npm run check && npm run lint && npm run format:check && npm test
```

- Run it with `wails3 task check` (or `task check` when the standalone Task runner is installed). CI calls this task and nothing else for the checks, and builds with `wails3 build` in a separate job ([build and distribution](10-build-and-distribution.md#continuous-integration)).
- `wails3 build` is the same as `wails3 task build`. It builds the frontend, regenerates the bindings, and runs `go build -tags production -trimpath -buildvcs=false -ldflags="-w -s"`.

### Editor

- Open the Go code with the Go language server and the `frontend` folder with the Svelte language server, and select the workspace TypeScript version, as the [Svelte notes](../svelte-conventions/02-project-setup-and-tooling.md#editor) say.
- Wails reads parameter names and comments from the source, so keep the doc comments on exported service methods and types in good order. They become JSDoc in the frontend.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Installation](https://wails.io/getting-started/installation/): the platforms, Go 1.26 or later, npm optional, the Xcode tools, WebView2, `gtk4` and `webkitgtk-6.0`, `go install ...wails3@v3.0.0`, `wails3 setup` and `wails3 doctor`. [Setup](https://wails.io/getting-started/setup/): the wizard. [CLI reference](https://wails.io/reference/cli/): the commands. [Frontend frameworks](https://wails.io/guides/dev/frontend-frameworks/): the templates and the runtime package.
- `wails3 init -l` (v3.1.0): the templates `ios`, `react`, `react-js`, `svelte`, `svelte-js`, `vanilla`, `vanilla-js`, `vue` and `vue-js`. `wails3 init -n loansapp -t svelte -mod example.com/loansapp -d wailsprobe -nocolour -productidentifier com.example.loansapp` created `wailsprobe/loansapp` with `main.go`, `greetservice.go`, `Taskfile.yml`, `build/`, `frontend/` and `go.mod` (`go 1.26.0`, `wails/v3 v3.1.0`), and the `.gitignore` above.
- Checked on 2026-11-18 with Go 1.26.10 on macOS 26.6: `go install github.com/wailsapp/wails/v3/cmd/wails3@v3.1.0` installed the CLI. In the sample project `go get -tool github.com/wailsapp/wails/v3/cmd/wails3` added the `tool` line, `go install tool` installed `wails3`, and both `wails3 version` and `go tool wails3 version` printed `v3.1.0`. `wails3 build` passed and wrote a 9.2 MB `bin/loansapp`. `go vet . ./internal/...` and `go test -race -shuffle=on . ./internal/...` passed. With the build cache cleared, `go test -race` printed 17 `ld: warning` lines, and with `CGO_CFLAGS` and `CGO_LDFLAGS` set to `-mmacosx-version-min=12.0` it printed none. `go list ./...` listed `example.com/loansapp/frontend/node_modules/flatted/golang/pkg/flatted`, and `gofmt -l .` listed three files under `build/ios/` and `build/android/scripts/`.
- The `check` task above was not run as one command. Its steps ran one by one in the sample project, except `git diff --exit-code`, which needs a git repository.
- `wails3 setup` was not run, because the wizard is interactive. The Linux, Windows and Docker paths were not run on this machine.
