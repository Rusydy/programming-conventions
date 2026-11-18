# SvelteKit Testing and Quality Gates

## Summary

Test with Vitest in two projects, as the Svelte notes do: logic and server code run in Node.js, and components run in a real browser. Test server code and `load` functions as plain functions, test a page by rendering it with its props, and cover whole flows with Playwright against the built app. Run the same checks locally and in CI.

## Rules

### Quality gates

- One command runs every gate: `npm run ci` runs `check`, `lint`, `format:check`, `test` and `build`, in that order ([scripts](02-project-setup-and-tooling.md#scripts)). CI calls it and nothing else for the first job.
- Run the end-to-end tests in a second job after the build, because they start a server and a browser.
- A failing `svelte-check` warning fails the build, because `--fail-on-warnings` is on. That makes accessibility warnings and unused CSS gates.
- Do not merge with a skipped gate. A gate that is flaky is fixed or removed in its own change.

### Tools

- Use Vitest for unit and component tests, and Playwright for end-to-end tests. `sv add vitest` and `sv add playwright` install both. The [Svelte testing note](../svelte-conventions/10-testing.md#tools) gives the reasons and the browser setup, and the same rules apply here.
- Use the two-project Vitest configuration of the Svelte notes inside `vite.config.ts`, next to the `sveltekit()` plugin. `extends: true` makes each project reuse the plugins, so server-only imports and `#lib` resolve the same way as in the app:

```ts
test: {
  expect: { requireAssertions: true },
  projects: [
    {
      extends: true,
      test: {
        name: "unit",
        environment: "node",
        include: ["src/**/*.test.ts"],
        exclude: ["src/**/*.browser.test.ts"],
      },
    },
    {
      extends: true,
      test: {
        name: "component",
        include: ["src/**/*.browser.test.ts"],
        exclude: ["src/lib/server/**"],
        browser: {
          enabled: true,
          headless: true,
          provider: playwright(),
          instances: [{ browser: "chromium" }],
        },
      },
    },
  ],
},
```

- Import `defineConfig` from `vitest/config` and `playwright` from `@vitest/browser-playwright`.
- Keep `expect: { requireAssertions: true }`, which `sv add vitest` writes. A test without an assertion fails.
- `sv add vitest` names browser tests `*.svelte.{test,spec}.ts` and the others `*.{test,spec}.ts`. This set keeps the names of the Svelte notes: `name.test.ts` in Node.js, and `name.browser.test.ts` in the browser. Keep `.svelte.test.ts` for a test that itself uses a rune. Rename the files that `sv add vitest` writes.
- Do not test what the framework already guarantees, such as that a matcher returns a 404 or that `use:enhance` posts a form. Test your logic.

### Where tests live

- Put a test next to the file it tests, and name it so that it does not start with `+`. SvelteKit ignores such files in a route folder: `src/routes/loans/page.browser.test.ts` tests `+page.svelte`, and `src/lib/server/loans.test.ts` tests `loans.ts`.
- SvelteKit turns the illegal-import check off when `process.env.TEST` is `true`, because Vitest does not tell server code from client code. A test therefore never catches a client file that imports a server module, and only `vite build` does, which is one more reason to keep `build` in `npm run ci`. List `src/lib/server/**` in the `exclude` of the browser project, as above, so that a browser test never loads a server module.

### Server code and load functions

- Move the logic of a route into a module in `src/lib/server/` and test that module as a plain function in the `unit` project. The route file then only reads the event, calls the function and returns the result:

```ts
// src/lib/server/loans.test.ts
import { describe, expect, it } from "vitest";

import { createLoan, findLoan } from "./loans.ts";

describe("createLoan", () => {
  it("stores an open loan that can be found by id", () => {
    const loan = createLoan({ borrower: "Budi", amountMinor: 200 });

    expect(loan.status).toBe("open");
    expect(findLoan(loan.id)).toEqual(loan);
  });
});
```

- When a test must call a `load` function or an action directly, build the event with only the fields that the function reads, and write one cast with a comment that says what is left out (`{ locals } as unknown as RequestEvent`), as the [TypeScript notes](../typescript-conventions/10-testing.md#test-doubles) allow.
- A server module that reads `$app/env/private` or calls `getRequestEvent()` needs those values supplied. Pass the data as an argument where you can, and mock the module only at its boundary. `getRequestEvent()` throws outside a request, so a function that calls it, such as `requireUser()`, cannot run in a plain unit test.
- Test that an action returns `fail(422, ...)` with the right field errors for each invalid case, and that it requires a user. These are the rules that regress.
- Reset module-level state, such as an in-memory store, in `beforeEach`.

### Component tests

- Render a page or a component with `render` from `vitest-browser-svelte`, as the [Svelte notes](../svelte-conventions/10-testing.md#component-tests) show. Give a page component its `data`, `form` and `params` props, because `PageProps` requires all three:

```ts
const screen = await render(Page, {
  data: { loans: [{ id: "1", borrower: "Ayu", amountMinor: 150000, status: "open" }] },
  form: null,
  params: {},
});

await expect.element(screen.getByRole("link", { name: "Ayu" })).toHaveAttribute("href", "/loans/1");
```

- Find elements by role and accessible name. Check a link with `toHaveAttribute("href", ...)`, which proves that `resolve()` built the right path.
- Do not mock `$app/state`, `$app/navigation` or `$app/forms` for a page that uses `resolve`, `enhance` or `page`. The sample page rendered with them in the browser project. Test the behaviour of the whole flow in an end-to-end test where a mock would be needed.

### End-to-end tests

- Write end-to-end tests in `e2e/` with `@playwright/test`, and name them `*.e2e.ts`. `sv add playwright` puts its example next to a route, so move it. Configure the server and the match in `playwright.config.ts`:

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  testMatch: "**/*.e2e.ts",
  webServer: { command: "npm run build && npm run preview", port: 4173 },
});
```

- Run against the built app, as the Svelte testing page says, so the test sees the production behaviour. Give the `webServer` the environment variables that `src/env.ts` validates.
- Test a flow a user cares about: sign in, create a loan, see it in the list, and the error and redirect paths. Keep the number small. A test that is not about a flow belongs in a unit or component test.
- Query by role and label, and never by CSS class. Playwright's `getByRole` and `getByLabel` double as an accessibility check.
- Do not share state between tests. Create the data a test needs through the app or a test-only seed, and clean it afterwards.
- Run `npx playwright install --with-deps chromium` in CI and cache the browser. `sv add playwright` adds `playwright install` to its `test:e2e` script, which downloads a browser, so run that step on purpose.

## Sources and raw notes

Pages read on 2026-11-18:

- [Svelte testing](https://svelte.dev/docs/svelte/testing): Vitest, rune tests, component tests, Playwright against a built app. [Server-only modules](https://svelte.dev/docs/kit/server-only-modules): the check is off when `process.env.TEST` is `true`. [Project structure](https://svelte.dev/docs/kit/project-structure): `tests/` for Playwright, files in a route folder that are not `+` files are ignored. [Routing](https://svelte.dev/docs/kit/routing): other files in a route directory are ignored.
- `sv` 1.5.0 `sv add vitest="usages:unit,component" playwright="demo:no"`: the Vitest `client` and `server` projects (`*.svelte.{test,spec}` in the browser), `expect: { requireAssertions: true }`, `exclude: ['src/lib/server/**']` for the browser project, and `playwright.config.ts` with `testMatch: '**/*.e2e.{ts,js}'` and `webServer: { command: 'npm run build && npm run preview', port: 4173 }`.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the two-project configuration ran with 2 test files and 2 tests passing under Vitest 5.1.1, where `src/lib/server/loans.test.ts` ran in Node.js and `src/routes/loans/page.browser.test.ts` rendered `+page.svelte`, with `enhance` and `resolve`, in Chromium. The browser project ran with the Chromium build that was already installed, as the [Svelte testing note](../svelte-conventions/10-testing.md#sources-and-raw-notes) records. Without `params: {}`, `svelte-check` reported that `params` is missing from `PageProps`.
- The end-to-end config and the CI advice were not run. `playwright test` was not run, because it needs a browser download.
