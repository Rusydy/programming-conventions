# Nuxt Testing and Quality Gates

## Summary

Test with Vitest in three projects: `unit` runs plain logic in Node.js, `nuxt` runs components, composables and pages inside a Nuxt runtime with `@nuxt/test-utils`, and `e2e` builds the app and tests it over HTTP and in a browser. Mock only the network, with `registerEndpoint`, and clear Nuxt's data cache between tests. One script, `npm run ci`, runs every gate in order.

## Rules

### Quality gates

- Run these gates, in this order, in `npm run ci`: `nuxt typecheck`, `eslint --max-warnings 0`, `prettier --check .`, `vitest run`, `nuxt build` ([setup](02-project-setup-and-tooling.md#scripts)). CI calls `npm run ci` and nothing else.
- Install with `npm ci`, so that the `postinstall` script runs `nuxt prepare` and generates `.nuxt/`. The type check, the linter and the Nuxt test project all read it.
- A test file is part of the type check, as the TypeScript notes say. The `test/nuxt` folder is in the generated app project, and `nodeTsConfig.include` lists `test/unit` and `test/e2e` ([setup](02-project-setup-and-tooling.md#tsconfig)).

### Tools

- Use Vitest, with `@nuxt/test-utils` for anything that needs Nuxt. Import `describe`, `it` and `expect` from `vitest`, and do not turn on `globals`, as the TypeScript notes say.
- Install: `npm install -D vitest @nuxt/test-utils @vue/test-utils happy-dom playwright-core`, and add `@nuxt/test-utils/module` to `modules` in `nuxt.config.ts`, which adds a test panel to Nuxt DevTools. Install a browser for browser tests with `npx playwright install chromium`, and cache it in CI.
- A test file runs in one environment. `@nuxt/test-utils/runtime` (the Nuxt environment) and `@nuxt/test-utils/e2e` cannot be used in the same file. Choose the environment by the `include` glob of the project, not by a `// @vitest-environment` comment. The comment changes the environment without the Nuxt setup that the project provides.
- Do not use Vitest Browser Mode and `vitest-browser-vue` in a Nuxt project, as the Vue notes do for a plain Vue app. They have no Nuxt runtime, so a component that uses auto-imports, plugins or `useNuxtApp()` cannot run in them. The Nuxt documentation describes the `happy-dom` and `jsdom` environments, and the sample used `happy-dom`. A component test that needs a real browser is an end-to-end test ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Configure three projects in `vitest.config.ts`:

```ts
// vitest.config.ts
import { defineVitestProject } from "@nuxt/test-utils/config";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    projects: [
      {
        test: {
          name: "unit",
          include: ["test/unit/**/*.test.ts"],
          environment: "node",
        },
      },
      {
        test: {
          name: "e2e",
          include: ["test/e2e/**/*.test.ts"],
          environment: "node",
          testTimeout: 120_000,
        },
      },
      await defineVitestProject({
        test: {
          name: "nuxt",
          include: ["test/nuxt/**/*.test.ts"],
          environment: "nuxt",
        },
      }),
    ],
  },
});
```

### Where tests live

- Put tests in `test/unit/`, `test/nuxt/` and `test/e2e/`, named `name.test.ts`, as the Nuxt documentation does. This is the one exception to the TypeScript rule of putting a test beside its code: the folder is what selects the Nuxt environment, and the generated app project includes `test/nuxt`.
- Name a `describe` block after the unit and an `it` block as a sentence about its behaviour, as the TypeScript notes say. Follow every other rule of the TypeScript testing note: typed fixtures built with `Partial<T>` overrides, no `any`, errors asserted by class and data, and fake timers restored in `afterEach`.

### Unit tests

- Test plain logic in `test/unit/`: Zod schemas, functions in `shared/utils/` and `server/utils/`, and parsers. They need no Nuxt, and they run in Node.js. Import them explicitly by relative path, because Node.js has no auto-imports.
- Keep logic out of handlers and components, so that most tests are unit tests. A handler that is a few lines of parse, call and map needs only an end-to-end test.

### Nuxt-environment tests

- Test a component, a composable that uses Nuxt, or a page in `test/nuxt/`. Auto-imports work in the test file itself: the sample's tests used `ref`, `Loan`, `useLoanFilter`, `useLoanStore`, `createError` and `HTTP_STATUS` with no `import`.
- Mount with `mountSuspended(Component, { props })`, which wraps Vue Test Utils' `mount` and waits for async setup. Await it, find elements by role, a label or a visible text, and trigger events through the wrapper: `await wrapper.get("button").trigger("click")`, and assert on `wrapper.emitted("select")`. `renderSuspended` (Testing Library) is the alternative for tests written in that style.
- Import a component by hand with its alias and extension (`import LoanRow from "@/components/loan/loan-row.vue"`).
- Mock the network with `registerEndpoint("/api/loans", () => [...])`, which answers `$fetch` and `useFetch` in the Nuxt environment. A handler that throws `createError({ status })` tests the error state. Do not mock Vue, Nuxt or your own modules. Use `mockNuxtImport("useRoute", () => ...)` only to replace a Nuxt composable at a boundary, such as the clock or a browser API.
- Call `clearNuxtData()` in `beforeEach` when a test uses `useFetch` or `useAsyncData`. Nuxt caches data by key across the tests of a file, so a second test that registers a different endpoint for the same URL reads the first test's data. The sample's error-state test failed until it did.
- Test a page by mounting the page component, with the endpoints it fetches registered, and assert on the loading, error and data states, as the [Vue notes](../vue-conventions/12-testing.md#component-tests) say.
- Test your own logic, not Nuxt's: do not test that `useState` shares state or that `useFetch` de-duplicates.
- Pass a route with `mountSuspended(App, { route: "/loans/1" })` for a test that depends on the route.
- A test that needs a real browser, a real server, or layout does not belong here. Write an end-to-end test.

### End-to-end tests

- Call `await setup({ rootDir })` at the top of the file. It builds the app and starts a server, once per file, so end-to-end files are slow: keep their number small and give them a long `testTimeout`. Test the server over HTTP with `$fetch` from `@nuxt/test-utils/e2e`, and a page in a browser with `setup({ browser: true })` and `createPage()`, which returns a Playwright page:

```ts
await setup({ rootDir: new URL("../..", import.meta.url).pathname, browser: true });

it("lists the loans and opens one", async () => {
  const page = await createPage("/");
  await page.getByRole("link", { name: "Ayu" }).click();
  await page.waitForURL("**/loans/1");
  expect(await page.getByRole("heading", { level: 1 }).textContent()).toBe("Ayu");
  await page.close();
});
```

- Assert on an API error by status: `await expect($fetch("/api/loans/99")).rejects.toMatchObject({ statusCode: HTTP_STATUS.notFound })`. Name the status with `HTTP_STATUS`, import it by relative path, and never write a bare number.
- Cover each handler's success, its validation failure (400), its rule failure (422), its missing resource (404) and, for a private route, the missing session (401). The server validation is the contract, so it deserves the most tests.
- Test the critical journeys in a browser: sign in, the main list, a form that saves. Keep them few. Query by role and name, so that a test also checks accessibility.
- Run the end-to-end tests against the built app (`setup` builds it) and, before a release, against `nuxt preview` or the deployed environment with Playwright's own runner, if the project has one.
- Do not make end-to-end tests depend on each other or on data that another test creates. A test creates what it needs.

### Type tests

- Test the types of a generic composable or a shared schema type with `expectTypeOf` in a `*.test-d.ts` file, as the TypeScript notes say, and pin `vitest` to an exact version while you do.

## Sources and raw notes

Pages read on 2026-11-20:

- [Testing](https://nuxt.com/docs/getting-started/testing): `@nuxt/test-utils`, the Nuxt and Node.js environments, `defineVitestProject`, "use your projects' `include` globs to choose the environment", `mountSuspended`, `renderSuspended`, `mockNuxtImport`, `registerEndpoint`, end-to-end tests with `setup`, `$fetch` and `createPage`, browser testing.
- [`test/` directory](https://nuxt.com/docs/directory-structure/test): the `test/nuxt` folder and the generated project that includes it.
- [Vue testing note](../vue-conventions/12-testing.md) and the [TypeScript testing note](../typescript-conventions/10-testing.md).
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes) with `@nuxt/test-utils` 4.4.0, Vitest 5.1.1, happy-dom 21.0.4 and Playwright Chromium:
  - Three projects ran: `unit` (a schema test), `nuxt` (a component with `mountSuspended`, a composable, a Pinia store, and the index page with `registerEndpoint`) and `e2e` (HTTP tests of two handlers, and a browser test through `createPage`). All passed.
  - The page test with a second `registerEndpoint` for the same URL failed to find the alert until `clearNuxtData()` ran in `beforeEach`.
  - `nuxt typecheck` and typed ESLint passed with the test files and `vitest.config.ts` in the generated projects.
