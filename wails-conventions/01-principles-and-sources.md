# Wails Principles and Sources of Truth

## Summary

These principles apply to every Wails v3 desktop application: a Go program that shows a web frontend in the operating system's own web view. They build on [golang-conventions](../golang-conventions/01-principles-and-sources.md) for the backend and on [svelte-conventions](../svelte-conventions/01-principles-and-sources.md) for the frontend, and they add only what Wails itself decides: the project shape, services and bindings, events, windows, building and shipping. Wails v2 is a different framework and is not covered.

## Rules

### Principles

1. **Write the backend as ordinary Go.** A Wails service is a normal Go type with normal methods. Follow every rule of the Go notes, including the named parameters and results, and let Wails generate the frontend API from that code ([services and bindings](05-services-and-bindings.md)).
2. **Write the frontend as a plain Svelte app.** The frontend is a client-only Vite project with no server rendering, so the [Svelte notes](../svelte-conventions/01-principles-and-sources.md) apply and the SvelteKit notes do not.
3. **Keep the domain out of the framework.** Business rules live in packages under `internal/` that do not import Wails. Only `main` and a thin layer of services touch `application` ([project layout](03-project-layout.md#where-code-lives)).
4. **Let the bindings be the contract.** The frontend calls the backend through generated bindings and never through a hand-written bridge. Change the Go signature, regenerate and fix the compiler errors on the frontend side ([services and bindings](05-services-and-bindings.md#bindings)).
5. **Validate on the Go side.** The frontend is not trusted. Check every argument of every bound method, because the webview can run any script that reaches it ([security](08-security.md)).
6. **Use calls for requests and events for notifications.** A bound method is a request with an answer, and an event is a one-way announcement. Do not use events as a remote procedure call ([events and windows](06-events-and-windows.md#events)).
7. **Start and stop through the lifecycle.** Open resources in `ServiceStartup`, release them in `ServiceShutdown`, and stop background work through the context ([application lifecycle](04-application-lifecycle.md)).
8. **Build with the generated Taskfile.** Projects build through `wails3 build` and its Taskfiles, which you can read and change. Do not replace them with a script that hides the steps ([build and distribution](10-build-and-distribution.md)).
9. **Test the Go and the frontend without a window.** Services and domain packages test as plain Go, the frontend tests as a plain Vite project, and a small end-to-end test runs against the server build ([testing](09-testing-and-quality-gates.md)).
10. **Wait for a second use case.** Do not add a second window, a tray icon, a menu, an updater or a service until the product needs it.

### Order of precedence

When two sources disagree, the lower number wins.

1. The documented and observed behaviour of the Wails runtime and CLI, and the Wails release notes.
2. The notes in this folder.
3. [golang-conventions](../golang-conventions/01-principles-and-sources.md), for every question about the Go code, including the layout of packages and the personal override on named parameters and results.
4. [svelte-conventions](../svelte-conventions/01-principles-and-sources.md) and [typescript-conventions](../typescript-conventions/01-principles-and-sources.md), for the frontend.
5. The Wails guides, where the notes above are silent.

Many examples in the Wails documentation do not follow the Go notes. They use unnamed parameters, `interface{}`, a `services/` and a `repository` layer, a `Wire` container, a global `EventBus`, `time.Sleep` in a goroutine for expiry and `html.EscapeString` on stored text. This set takes the framework's facts from those pages and not their style. Where a Wails page recommends a pattern that the Go notes forbid, the Go notes win and the difference is recorded in the note that covers it:

- **Layers and interfaces.** The documentation shows a service layer over a repository interface. The Go notes organise by responsibility and define an interface only where a consumer needs one ([project layout](03-project-layout.md#where-code-lives)).
- **`init()`.** The documentation registers events in `init()`. This set registers them at the start of `run`, which the binding generator also reads ([events and windows](06-events-and-windows.md#events)).
- **Escaping on the Go side.** The documentation escapes HTML in Go before it stores a value. This set stores the value as typed and lets Svelte escape it where it renders ([security](08-security.md#input-and-output)).
- **`enum` in TypeScript.** The generator emits a TypeScript `enum` for a Go enum type, which the TypeScript notes forbid. The frontend allows the generated one and bans every other ([frontend](07-frontend.md#typescript-and-generated-code)).

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change, and leave the rest alone unless someone asks for a clean-up.
- **A Wails v2 project** is ported, not upgraded, so keep v2 in place until the v3 application works ([modern Wails by release](11-modern-wails-by-release.md#porting-from-wails-v2)).
- **Generated code** is exempt: `frontend/bindings/`, `frontend/dist/`, `bin/`, `.task/` and the platform files under `build/` that `wails3` writes or that `task common:update:build-assets` regenerates.
- **Mechanical changes** (formatting, dependency bumps, CLI upgrades) go in their own commits.
- **Shared and team repositories:** when a repository documents its own conventions, follow those first.

### Decisions to review

These choices were made while writing the notes, because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Why | Where to change it |
| --- | --- | --- |
| Pin the CLI with a `tool` directive in `go.mod` and install it with `go install tool` | The Go notes pin tools that way, and the CLI then always matches the library version. The documentation installs it with `go install ...@v3.0.0`. | [setup](02-project-setup-and-tooling.md#the-wails-cli) |
| The `svelte` template, then the Svelte notes' baseline for the frontend | The template pins `typescript ^5`, `allowJs` and `checkJs`, and has no lint or format setup. | [frontend](07-frontend.md#frontend-baseline) |
| `main.go` at the repository root and domain code in `internal/` | `//go:embed all:frontend/dist` can only embed files below its own folder, so `main` stays beside `frontend/`. This is the "single command" layout of the Go notes. | [project layout](03-project-layout.md#where-code-lives) |
| Commit `frontend/bindings/` and check it in CI | The template does not ignore it, and the frontend checks need it without a Go toolchain. | [project layout](03-project-layout.md#generated-files) |
| Allow the generated `enum`, ban hand-written ones with ESLint, and drop `erasableSyntaxOnly` in the frontend | The generator writes `export enum` for every Go enum type, and `erasableSyntaxOnly` rejects it. | [frontend](07-frontend.md#typescript-and-generated-code) |
| No `init()` for `RegisterEvent` | The generator finds `RegisterEvent` calls in `run` too, so the Go notes' ban on `init()` holds. | [events and windows](06-events-and-windows.md#events) |
| Escape on output, not on input | The Svelte template escapes text already, so escaping before storage corrupts the data and then shows `&amp;`. | [security](08-security.md#input-and-output) |
| The generated Taskfiles and cgo builds, not Wake and purego | Both are marked experimental in v3.1, and Wake replaces the Taskfile routing in a one-way migration. | [modern Wails by release](11-modern-wails-by-release.md#experimental-features-that-this-set-does-not-use) |
| Native builds per platform in CI, Docker cross-builds only as a fallback | The platform toolchain is what the generated tasks and the signing tools expect. Docker cross-compiles but adds an 800 MB image. | [build and distribution](10-build-and-distribution.md#targets) |
| Playwright against a `server` build for end-to-end tests | The documentation's own guide does this. Native windows, menus and dialogs have no automated test here. | [testing](09-testing-and-quality-gates.md#end-to-end-tests) |
| No remote content in a window | A window that loads remote pages gets the same bridge as your own, so it is a boundary that the notes do not cross. | [security](08-security.md#the-webview) |

### Version policy

- **Wails:** run v3. Wails v3.0.0 is stable on desktop and was released on 2026-10-26, and v3.1.0 followed on 2026-11-01. Releases are weekly minor versions, with dated nightlies in between. Pin the version you use, and move one minor version at a time.
- **Platforms:** Windows (amd64, arm64), macOS (Intel, Apple Silicon) and Linux (amd64, arm64), where Linux uses GTK4 and WebKitGTK 6.0. Android and iOS are experimental and outside the stable contract, so this set does not cover mobile.
- **Go:** Wails needs Go 1.26 or later. The Go notes say how to choose the `go` directive, and a Wails module cannot go below 1.26.
- **Node.js:** use an LTS or later. The frontend notes pin the Svelte, Vite and TypeScript versions.
- **`@wailsio/runtime`:** give the npm package exactly the version of the Go module (`"@wailsio/runtime": "3.1.0"`, as the template writes it).
- **Upgrades:** change the `go.mod` requirement, the `tool` directive and the npm package in one change, run `wails3 generate bindings`, and read the release notes first.

### Working with coding agents

- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/wails.md](../agent-rules/rules/wails.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** the rule has a `paths` field. Claude Code loads it when a session reads, writes or edits `build/config.yml`, `Taskfile.yml`, a file under `build/` or `frontend/bindings/`, or a Go file beside a `frontend/` folder. It loads next to `golang.md` and, for the frontend, `svelte.md` and `typescript.md`. Start the session in the repository root, and in a new project tell the agent to read `~/.claude/rules/wails.md` before it writes the first service.
- A project whose agents must follow these notes on other machines names this folder in its own `AGENTS.md`.
- Tell agents to run `go vet`, `go test -race`, `wails3 generate bindings` and `npm run ci` in `frontend/` before they report changes as done, and to read the installed version (`go tool wails3 version`) before they use an API. Wails v3 renamed most v2 APIs, so training data about v2 is often wrong.

## Sources and raw notes

Pages read on 2026-11-18 unless a bullet says otherwise. The Wails documentation site returns HTTP 403 to automated fetches, so the pages were read from the documentation source in the `wailsapp/wails` repository at the tag `v3.1.0` (`docs/mpress/content`):

- Go module proxy on 2026-11-18: `github.com/wailsapp/wails/v3` latest `v3.1.0`, published 2026-11-01. GitHub releases: `v3.1.0` (2026-11-01) and the nightlies `v3.2.0-nightly.20261101` to `v3.2.0-nightly.20261103`.
- [Wails v3.0.0 Released](https://wails.io/blog/wails-v3-released/) (2026-10-26): the stability promise, the feature list, Go 1.26, the `go install ...@v3.0.0` command, weekly releases and nightlies, and "Wails v2 isn't going away". [Roadmap](https://wails.io/status/): the desktop compatibility contract, and mobile as experimental. [Installation](https://wails.io/getting-started/installation/): the supported platforms and the dependencies, including `gtk4` and `webkitgtk-6.0` on Linux and the WebView2 runtime on Windows.
- The pages cited in the other notes: [services](https://wails.io/features/bindings/services/), [bindings best practices](https://wails.io/features/bindings/best-practices/), [methods](https://wails.io/features/bindings/methods/), [models](https://wails.io/features/bindings/models/), [enums](https://wails.io/features/bindings/enums/), [events](https://wails.io/features/events/system/), [lifecycle](https://wails.io/concepts/lifecycle/), [security](https://wails.io/guides/security/), [project structure](https://wails.io/guides/dev/project-structure/), [frontend frameworks](https://wails.io/guides/dev/frontend-frameworks/), [panic handling](https://wails.io/guides/panic-handling/), [single instance](https://wails.io/guides/single-instance/), [testing](https://wails.io/guides/testing/), [end-to-end testing](https://wails.io/guides/e2e-testing/), [cross-platform builds](https://wails.io/guides/build/cross-platform/), [signing](https://wails.io/guides/build/signing/), [updater](https://wails.io/guides/updater/) and the [v2 to v3 migration](https://wails.io/migration/v2-to-v3/).
- The sample application that checks these notes: `wails3 init -n loansapp -t svelte` with `wails3` v3.1.0, Go 1.26.10, Node.js 24.22.1, Svelte 5.58.0, Vite 8.3.8 and TypeScript 6.0.3, on macOS 26.6 (Apple M2). It has one service (`internal/loan`), one registered event and a Svelte frontend. Each note says which of its examples ran there.
