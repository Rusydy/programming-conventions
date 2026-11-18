---
paths:
  - "**/build/config.yml"
  - "build/config.yml"
  - "**/frontend/bindings/**"
  - "frontend/bindings/**"
  - "**/build/Taskfile.yml"
  - "build/Taskfile.yml"
  - "**/build/*/Taskfile.yml"
  - "build/*/Taskfile.yml"
  - "**/frontend/e2e/**"
  - "frontend/e2e/**"
---
# Wails conventions (Wails v3 desktop apps)

Write idiomatic Wails v3: Go backend, plain Svelte frontend, generated bindings. Follow the framework and its generated Taskfiles instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `wails-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. It adds to `golang.md`, and to `svelte.md` and `typescript.md` for `frontend/`. The digest was synced with the notes on 2026-11-18; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatting, CLI and dependency bumps, regenerated bindings) in their own commits.
- When sources disagree, the order is: Wails runtime and CLI behaviour and release notes; this file and the notes; `golang.md` for Go, including the named parameters and results override; `svelte.md` and `typescript.md` for the frontend; the Wails guides where those are silent. Many Wails guide examples break the Go rules (unnamed parameters, `interface{}`, `services/` and repository layers, Wire, `init()`, `html.EscapeString` on input): take their facts, not their style.
- Generated files are exempt: `frontend/bindings/`, `frontend/dist/`, `bin/`, `.task/`, and the `build/` files that `wails3 task common:update:build-assets` writes. Edit the source (Go code, `build/config.yml`), never the generated file.
- Wails v2 is a different framework (`wails`, `wailsjs/`, `wails.Run`). Do not use v2 APIs from memory: check `go tool wails3 version` and the docs of that version. A v2 project is ported, not upgraded.
- Before you report changes as done, run the project's check task (`wails3 task check`) or, at least, `gofmt -l`, `go vet . ./internal/...`, `go test -race -shuffle=on . ./internal/...`, `wails3 generate bindings -clean=true -ts -i` (and `git diff` of `frontend/bindings`) and, in `frontend/`, `npm run check`, `lint`, `format:check` and `test`.

## Setup

- Wails needs Go 1.26 or later, Node.js and npm, the platform libraries (Xcode tools on macOS, WebView2 on Windows, `gcc` with `gtk4` and `webkitgtk-6.0` on Linux). Run `wails3 setup` once and `wails3 doctor` to check; include `doctor` output in bug reports.
- Pin the CLI in `go.mod`: `go get -tool github.com/wailsapp/wails/v3/cmd/wails3`, install with `go install tool`, keep `GOBIN` on `PATH` (the Taskfiles call a bare `wails3`). `@wailsio/runtime` in `frontend/package.json` has exactly the Go module's version. Move one Wails minor version at a time, in its own pull request, and regenerate the bindings.
- Create with `wails3 init -n <name> -t svelte -mod <module path> -productidentifier <id> -d .`. Fill in `build/config.yml` (`companyName`, `productName`, `productIdentifier`, `description`, `copyright`, `version`) before a release, then `wails3 task common:update:build-assets` (it overwrites hand edits). The scaffold's `My Product` and `My Company` otherwise land in the `Info.plist`.
- Run Go checks on `. ./internal/...`, not `./...`: `./...` also matches `build/` helpers and a Go package inside `frontend/node_modules`. `gofmt -l .` lists unformatted generated files under `build/`: filter them. On macOS set `CGO_CFLAGS` and `CGO_LDFLAGS` to `-mmacosx-version-min=12.0` to silence linker warnings in tests. Keep `nonamedreturns` and `unparam` off.
- Keep `build/` and its Taskfiles in version control. Do not replace them with a wrapper script. `wails3 build` runs `go build -tags production -trimpath -buildvcs=false -ldflags="-w -s"`; `wails3 package` builds the platform bundle.

## Layout

- This is the Go "single command" layout: `main.go` at the root beside `frontend/` (`//go:embed all:frontend/dist` cannot reach a parent folder), domain code and services in `internal/<feature>/` named by responsibility. No `services/`, `models/`, `repository/` or `controllers/` folders, no `pkg/`, no `util`.
- Domain packages do not import `github.com/wailsapp/wails/v3/pkg/application`, except for the signature of `ServiceStartup`. Only `main` and its small adapters touch the application. A consumer-owned interface (`loan.Publisher`) carries what a service needs from Wails.
- Commit `frontend/bindings/` (the template does not ignore it, and frontend checks need it). Regenerate with `wails3 generate bindings -clean=true -ts -i`, and make the check task fail on `git diff --exit-code frontend/bindings`. Never edit or move it.

## Lifecycle and wiring

- `main` calls `run(ctx, args, getenv, stdout, stderr) (err error)` and exits; `os.Exit` and `log.Fatal` only in `main`. `run` creates the `*slog.Logger`, registers events, builds services by hand, calls `application.New(application.Options{...})`, `app.RegisterService(application.NewService(value))` (or `Options.Services`), `app.Window.NewWithOptions(...)` and last `app.Run()`, wrapping its error. No globals, no `init()`, no DI container.
- Give `Options.Logger` the same logger as the services. Set `PanicHandler` to log `details.Error` and `details.StackTrace` through `slog`; Wails recovers panics only in bound methods, so goroutines you start recover their own. Never panic for an expected failure. Write logs to a file in the user's folders in production.
- Services start in registration order and stop in reverse; register dependencies first; one service per Go type (wrapper types for two instances). A service is shared by all windows: guard state with a named `sync.Mutex`, never embedded.
- `ServiceStartup(ctx context.Context, options application.ServiceOptions) (err error)` opens resources (keep it under about 2 seconds; return an error to stop startup); `ServiceShutdown() (err error)` releases them. The `ctx` is cancelled at shutdown: every background goroutine ends on `ctx.Done()`.
- Hooks: `ShouldQuit: func() (quit bool)`, `OnShutdown`, `PostShutdown` (final logging only; no windows or dialogs). No dialog in `OnShutdown`. `SingleInstance` with a reverse-domain `UniqueID`, restoring and focusing the window, and a unique 32-byte `EncryptionKey` when data is passed.
- Configuration: defaults in code, `getenv` for developer overrides (`LOANSAPP_SERVER_PORT`), a settings file in `os.UserConfigDir()` for user settings. No secret in the repository.

## Services and bindings

- One small service per feature, in that feature's package; constructor injection (`NewService(logger, publisher, now)`); the clock is a function. Exported methods are public API of the webview: keep helpers unexported. `//wails:ignore` and `//wails:internal` only hide the generated wrapper and are not access control.
- Method names are Go-style actions (`List`, `Create`, `MarkPaid`), no `Get` prefix. Name every parameter by meaning (names reach TypeScript: `Create(borrower: string, amountMinor: number)`). A first `ctx context.Context` is allowed and is dropped from the TypeScript signature. For more than about three arguments use one struct with JSON tags. Results are `(value, err)`; an error rejects the promise.
- Never expose a method that takes a file path, command, URL or SQL string from the frontend. Validate every argument in Go (trim, required, length, range, existence) and return sentinel or typed errors (`ErrInvalidInput`, `ErrNotFound`) wrapped with `%w`; the message crosses the bridge, so no secret, path or SQL in it. `errors.New` errors have an empty `cause`; typed errors with exported JSON fields reach `error.cause`. `ServiceOptions.MarshalError` only for a stable error shape.
- Models are plain data with JSON tags and doc comments (they become JSDoc). Enums are named types with constants and a deliberate zero value; the generator writes a TypeScript `enum` with `$zero`. `time.Time` is UTC and arrives as an RFC 3339 `string`; choose `-time-type=Date` for the whole project or convert at the edge. Money is `int64` minor units (`AmountMinor`) with a currency. Slices arrive as `T[] | null`. No channels, funcs or interfaces other than `any` across the bridge. Batch calls, paginate lists, do long work in your own goroutine with progress events.

## Events and windows

- Events are notifications; bound methods are requests. Name events `domain:action` in lower case (`loan:created`) and define the name as an exported constant next to its payload type. Register at the start of `run` with `application.RegisterEvent[T](Const)` (direct call, constant argument, no wrapper; the generator also finds it there, so no `init()`). Emit with `app.Event.Emit(name, value)` with the exact registered type, through a consumer-owned interface (an `appPublisher` adapter in `main`), never by passing `*application.App` into domain code. No events for RPC, loops, large payloads or frequent updates. Listen in Go with `app.Event.On` (returns a remove function); handlers must be short.
- Frontend: `Events.On(LoanCreated, (event) => ...)` with the constant from `@bindings/events` types `event.data`; unsubscribe by returning the remover from an `$effect`.
- Windows: the first in `run` with `Title`, `Width`, `Height`, `URL: "/"` and a `Name` when it must be found; few windows; find them with `app.Window.GetByName`/`Current`/`GetAll`, not your own map. Hide instead of close with `window.RegisterHook(events.Common.WindowClosing, func(event *application.WindowEvent) { window.Hide(); event.Cancel() })`. `Mac.ApplicationShouldTerminateAfterLastWindowClosed: true` unless it is a tray app. Set `BackgroundColour`. `DevToolsEnabled` off in release. Menus, tray, dialogs, shortcuts only when the product needs them.

## Frontend

- Template `svelte`, then the Svelte baseline: `typescript ~6.0.3`, `@tsconfig/svelte`, `tsconfig.json` with references to `tsconfig.app.json` and `tsconfig.node.json`, `checkJs` and `allowJs` off, `svelte.config.js` with `compilerOptions.runes`, typed ESLint, Prettier with the plugin, Vitest, a guard instead of `getElementById("app")!`, `@bindings/*` and `@/*` aliases in `paths` (Vite reads them). `@wailsio/runtime` stays an exact version. Keep the Vite dev server settings (`127.0.0.1`, `WAILS_VITE_PORT` or 9245, `strictPort`) and `wails("./bindings")`. Scripts `build` and `build:dev` stay.
- Generated bindings are ignored by ESLint and Prettier. Their `enum` conflicts with `erasableSyntaxOnly`, so turn that option off in `tsconfig.app.json` and ban hand-written `enum`, parameter properties, `import =` and `export =` with `no-restricted-syntax` selectors. Using a generated enum value is fine. Never edit `bindings/`.
- Call Go only through one client module per feature (`src/lib/loans/loan-client.ts`) that wraps the bindings (`import { Service as LoanService, type Loan } from "@bindings/<module>/internal/loan"`), turns `T[] | null` into `T[]`, and converts dates once. Components never import `@bindings/...` directly. Do not re-validate replies of your own services with a schema (the generator is the type source and Go validates); treat other data as `unknown`. A call returns a `CancellablePromise` (`cancel()`); `error instanceof Call.RuntimeError` means Go returned the error; show a fixed message, never `error.message` of an unexpected failure.
- Open links with `Browser.OpenURL` from `@wailsio/runtime`. Use hash-based routing only when a second view exists; no SvelteKit in Wails. Bundle all assets, no CDN. Drag regions use `--wails-draggable: drag` and `no-drag`. Test in real webviews (WebKit on macOS and Linux, WebView2 on Windows).

## Security

- Any script in the page can call every exported method of every registered service: keep the surface small and domain-shaped, validate in Go, load only the bundled frontend (no remote `URL` in a window), keep `AllowSimpleEventEmit` off, validate `RawMessageHandler` input, and review `frontend/bindings` in each pull request.
- Store text as typed and escape at output (Svelte escapes `{value}`); do not `html.EscapeString` on input. `html/template` if Go builds HTML. Limit input sizes, paginate, set timeouts.
- Files: map names or IDs to paths in Go, in a directory chosen in Go; confine with `os.OpenRoot`; let the user pick files with the native dialog and check size and type. App data in `os.UserConfigDir()`/`os.UserCacheDir()`, mode `0o600` for private files.
- Secrets: OS keychain (`zalando/go-keyring`), never in the repo, bundle, binding results or logs (`slog.LogValuer` redaction); `crypto/rand`; slow salted password hashes; AES-GCM with a random nonce. Obfuscation is not secrecy. HTTPS only, default TLS, client timeouts. Sign every release; updates use cryptographic signatures, not digest-only; keys stay out of the repository.

## Testing

- Services are tested as plain Go in `package loan_test`: table-driven, `t.Parallel()`, `t.Context()`, fixed clock, a recording double of the consumer-owned interface, `errors.Is` on sentinels, `-race -shuffle=on`. Test `ServiceStartup`/`ServiceShutdown` by calling them directly. Do not mock Wails; move logic out of anything that needs the application.
- Frontend: Vitest per the Svelte notes; mock the generated binding module (`vi.mock("@bindings/...")` with the generated shape) in client-module tests; never start the Wails runtime in a test.
- End-to-end: Playwright against the `server` build (`go run -tags server,production .` with `CGO_ENABLED=0`, `Server: application.ServerOptions{Host: "127.0.0.1", Port: port}` with the port from `getenv`), tests in `frontend/e2e/*.e2e.ts`, `wails3 generate bindings -f '-tags=server' ...` and `npm run build` first, one host per job, few tests. Native windows, menus, tray and dialogs are checked by hand per platform before a release, and the signed package on a clean machine.

## Build and distribution

- Build each platform on that platform where possible; Docker cross-builds (`wails3 task setup:docker`, about 800 MB) are the fallback. `wails3 build GOOS=... ARCH=...` selects the platform Taskfile. Do not build mobile targets. CGo and the Taskfiles are the default: do not adopt `purego` or Wake (both experimental in 3.1).
- Sign and notarise (macOS Developer ID, hardened runtime, minimal entitlements, `notarytool`), Authenticode on Windows (self-signed only for tests), PGP for `deb` and `rpm`; store credentials with `wails3 setup`; keep keys and certificates outside the repository. Installers: DMG, NSIS or MSIX, `deb`/`rpm`/AppImage. Name artifacts with product, version, OS and arch, and publish checksums. The updater is optional and needs a writable install folder.
- CI order: check task, e2e, golangci-lint and `govulncheck` (separate jobs, pinned), a build per platform on that platform, release from a protected tag with protected secrets. Install the CLI with `go install tool`; use `npm ci`; never run `common:update:build-assets` in CI.

## Releases

- v3.0.0 (2026-10-26) is stable for desktop (Windows, macOS, Linux; amd64 and arm64); mobile is experimental. v3.1.0 (2026-11-01) is the first weekly release; the newest on 2026-11-18 is v3.1.0, and nightlies are not for products. Read release notes before each upgrade.
- Replace v2 forms when you change a line: `wails.Run` to `application.New` + windows + `Run`; `Bind` to `Services`; a stored `ctx` and `startup(ctx)` to `ServiceStartup`; `runtime.*(ctx, ...)` to methods on `app` and window objects; `wailsjs/go/...` to `frontend/bindings/...`; `wails.json` to `build/config.yml` and the Taskfiles; `wails` to `wails3`. Port v2 on a branch and keep v2 working until v3 does.
