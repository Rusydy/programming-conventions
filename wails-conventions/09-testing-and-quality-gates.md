# Wails Testing and Quality Gates

## Summary

Test the Go services as plain Go with a fixed clock and a recording double, test the frontend as a plain Vite project with the generated binding mocked at its module boundary, and run one end-to-end test against the `server` build of the application, which needs no native window. Native menus, dialogs, tray icons and windows have no automated test here, so they get a short manual check on each platform before a release.

## Rules

### Gates

- One task runs every check: `wails3 task check` ([setup](02-project-setup-and-tooling.md#scripts)). It formats, vets and tests the Go packages with `-race -shuffle=on`, regenerates the bindings and fails when they differ from what is committed, and runs the frontend's `check`, `lint`, `format:check` and `test`.
- CI runs three jobs: the `check` task, the end-to-end job, and a build job for each platform that you ship ([build and distribution](10-build-and-distribution.md#continuous-integration)). Add `govulncheck` and golangci-lint as separate jobs, as the [Go notes](../golang-conventions/03-project-setup-and-tooling.md#automation) say.
- Do not merge with a skipped gate. A flaky test is fixed or deleted in its own change.

### Go tests

- Test a service as a plain Go type. Construct it with its dependencies and call its methods, with no application and no window. The documentation's own service pages do the same.
- Put the test in the external package (`package loan_test`), beside the code, and follow the [Go testing note](../golang-conventions/10-testing.md): table-driven tests with named cases, `t.Parallel()`, `t.Helper()`, `t.Context()`, failure messages that say what was got and wanted, and `errors.Is` for sentinel errors. Name every parameter and result of a helper, as the Go notes require.
- Control time with the clock that the service takes as a function, and never sleep in a test. Record events with a small hand-written double of the interface that the service owns:

```go
type recordingPublisher struct {
	names []string
}

func (r *recordingPublisher) Publish(name string, loan loan.Loan) {
	r.names = append(r.names, name)
}

func newTestService(t *testing.T) (service *loan.Service, published *recordingPublisher) {
	t.Helper()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	fixed := time.Date(2026, time.November, 18, 9, 0, 0, 0, time.UTC)
	published = &recordingPublisher{}
	return loan.NewService(logger, published, func() (current time.Time) { return fixed }), published
}
```

- Assert the contract that the frontend relies on: the validation errors (`errors.Is(err, loan.ErrInvalidInput)`), the status that a call leaves behind, and the event that it publishes. Do not assert on log output.
- Test `ServiceStartup` and `ServiceShutdown` by calling them directly with `context.Background()` and `application.ServiceOptions{}`, as the services page shows, and check that `ServiceShutdown` releases what `ServiceStartup` opened. Wait for the goroutines that startup launched before the test ends.
- Do not mock Wails. If a unit needs the application, the unit holds too much of it: move the logic into a type that does not import `application`, and test that.
- Keep the generated bindings out of the Go tests. They are checked by regeneration (below).
- A test binary that imports `application` links the native libraries. On macOS this prints linker warnings about the deployment target, which `CGO_CFLAGS` and `CGO_LDFLAGS` set to `-mmacosx-version-min=12.0` remove ([setup](02-project-setup-and-tooling.md#go-checks)).
- Run `go test -race -shuffle=on . ./internal/...`, as the setup note says, and not `./...`.

### Bindings

- Treat the committed bindings as a snapshot of the Go API. Regenerate with `wails3 generate bindings -clean=true -ts -i` and compare with `git diff --exit-code frontend/bindings`. A difference means someone changed a bound type or method and did not commit the result, and the build fails.
- When the diff is intended, commit it with the Go change, in the same commit, so that the frontend and the backend stay in step.
- Do not test the generator. Test that the frontend code compiles against the bindings, which `svelte-check` does.

### Frontend tests

- Follow the [Svelte testing note](../svelte-conventions/10-testing.md) for the Vitest setup, the unit and component projects and the naming of test files.
- Replace the Go bindings at the one module that imports them, the client module of the feature ([frontend](07-frontend.md#calling-go)). A mocked generated binding is an allowed boundary, like the network. Mock the whole module path (`@bindings/<module>/internal/loan`) with `vi.mock`, and give it the same shape as the generated one (`Service: { List, Create }`).
- Test the client module for the behaviour that it adds: the `null` slice that becomes `[]`, the date conversion, the mapping of errors. Test components against the client module's functions, not against the bridge.
- Never start the Wails runtime in a frontend test. The `@wailsio/runtime` package expects the host page of the application.

### End-to-end tests

- Run Playwright against the `server` build of the application, which serves the same frontend and the same services over HTTP and needs no native window or toolkit. The documentation's end-to-end guide uses this approach. It tests the browser interface and the real Go services together, and nothing in the native shell.
- Let the application read the port from the environment, through `getenv` in `run`, as the Go notes say, and set the server options with it:

```go
port, err := strconv.Atoi(cmp.Or(getenv("LOANSAPP_SERVER_PORT"), "8080"))
if err != nil {
	return fmt.Errorf("parse LOANSAPP_SERVER_PORT: %w", err)
}

app := application.New(application.Options{
	// Server applies only to a build with the "server" tag, which the end-to-end tests use.
	Server: application.ServerOptions{Host: "127.0.0.1", Port: port},
	// ...
})
```

- Put the tests in `frontend/e2e/` with `frontend/playwright.config.ts`, where the Node tooling and the lock file already are, as the documentation does. Name them `*.e2e.ts`, query by role and name, and start the Go host from the project root:

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  testMatch: "**/*.e2e.ts",
  use: { baseURL: "http://127.0.0.1:8089" },
  webServer: {
    command: "go run -tags server,production .",
    cwd: "..",
    env: { CGO_ENABLED: "0", LOANSAPP_SERVER_PORT: "8089" },
    url: "http://127.0.0.1:8089",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

```ts
import { expect, test } from "@playwright/test";

test("adds a loan through the Go service", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("No loans yet")).toBeVisible();
  await page.getByRole("button", { name: "Add" }).click();

  await expect(page.getByRole("listitem").filter({ hasText: "Ayu" })).toBeVisible();
});
```

- Build the frontend (`npm run build` in `frontend/`) and regenerate the bindings with the server tag before the run, because the server build embeds `frontend/dist`. Use `wails3 generate bindings -f '-tags=server' -clean=true -ts -i` as the documentation shows.
- Run one host for each test job, give tests their own temporary storage or an in-memory store, and never share state between tests.
- Keep the number of end-to-end tests small: the flows a user cannot do without. Cover the rest with Go and component tests.
- Install the browser with `npx playwright install --with-deps chromium` in CI and cache it. Commit the `package.json` and the lock file, so that CI can use `npm ci`.
- The end-to-end harness does not drive a native window, the menus, the tray, native dialogs or the operating system's file handling. Test them by hand on each platform you ship, with a short checklist that lives in the repository: the application starts, the window opens, the menu works, a file opens through a dialog, a second launch focuses the first window, and a quit closes everything.
- Check the packaged application on a clean machine or virtual machine for each platform at release time, with the signed build, because signing and notarisation problems appear only there.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Testing](https://wails.io/guides/testing/): unit tests of services, mocks, integration tests with real dependencies, frontend tests, the do and do-not list. [End-to-end testing](https://wails.io/guides/e2e-testing/): Playwright against a `server` build, `Server: application.ServerOptions{Host, Port}`, `wails3 generate bindings -f '-tags=server'`, the `webServer` configuration that runs `go run -tags server,production .`, committing the lock file, and the limit that native windows, menus, trays and dialogs are not automated. [Services](https://wails.io/features/bindings/services/): testing a service and its lifecycle directly.
- [Go notes](../golang-conventions/10-testing.md): table-driven tests, failure messages, test doubles at the consumer's interface.
- Checked on 2026-11-18 in the sample project: `go test -race -shuffle=on . ./internal/...` passed with the service test above, which asserts the trimmed borrower, the open status, the published event name and `errors.Is(err, loan.ErrInvalidInput)`. A build with `CGO_ENABLED=0 go build -tags server,production` produced a 15 MB binary that served `/`, `/wails/runtime.js` and logged `loan service started`. The Playwright test above, with `testMatch`, a `go run -tags server,production .` web server and `LOANSAPP_SERVER_PORT=8089`, passed in 2.9 seconds against that host: it clicked the button, called `List` and `Create` through the real bridge and saw the loan appear. The Vitest test that mocks `@bindings/...` passed.
- The Playwright run used the Chromium that was already installed on the machine, passed through `launchOptions.executablePath`, and `@playwright/test` ran from a scratch folder next to the project, not from `frontend/e2e`. That setting is left out of the configuration above. The `wails3 task check` task, the CI jobs, `govulncheck` and the manual checklist were not run.
