# Vue Testing

## Summary

Test with Vitest, in two projects: logic, composables and stores run in Node.js, and components run in a real browser through Vitest Browser Mode and `vitest-browser-vue`. Move logic out of components so that most tests need no component. Test what a component does for its user, through its props, events and slots, not how it does it. The TypeScript testing rules apply to every test file.

## Rules

### Tools

- Use Vitest for every test. Vitest is made by the Vue and Vite teams, shares the Vite config, and the Vue documentation recommends it. The [TypeScript testing note](../typescript-conventions/10-testing.md#tools) allows Vitest for component tests. A Vue project does not use `node:test`.
- Import the test API from `vitest` and do not turn on `globals`, as the TypeScript notes say.
- Run two Vitest projects in one config: `unit` in Node.js for logic, and `component` in a browser for components ([setup](02-project-setup-and-tooling.md#vitest)). Run both with `"test": "vitest run"`.
- Test a component in a real browser with `vitest-browser-vue` and the Playwright provider. Vitest calls Browser Mode the recommended approach for component tests, and it catches layout and browser behaviour that a simulated DOM cannot. The Vue documentation shows Vue Test Utils with jsdom, and `create-vue` installs both. Use Vue Test Utils with jsdom only in a project that cannot run a browser, and record why ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Install the tools and one browser:

```bash
npm install -D vitest vitest-browser-vue @vitest/browser-playwright playwright
npx playwright install chromium
```

- Write end-to-end tests with Playwright against `vite preview`, in an `e2e/` folder, as the TypeScript notes say. The Vue documentation recommends end-to-end tests for flows that span several pages and use a real backend.
- Cache the Playwright browser in CI, and install it with `npx playwright install --with-deps chromium` on a Linux runner.

### Where tests live

- Put a test next to the file it tests, as the TypeScript notes say, and name it after that file.
- Name a unit test `name.test.ts` and a component test `name.browser.test.ts`. The `unit` project skips `.browser.test.ts` files, and the `component` project runs only them. `create-vue` puts tests in a `__tests__` folder; do not use it.
- A test file is TypeScript and follows every rule of the TypeScript testing note: typed fixtures built with `Partial<T>` overrides, no `any`, assertions on errors by class and data, and fake timers restored in `afterEach`.
- Name a `describe` block after the unit (`LoanRow`, `useLoanList`), and an `it` block as a sentence about what the user or the caller sees: `"emits the loan id when the borrower is clicked"`.
- Add `vitest/browser` to `types` in `tsconfig.app.json`, so that `expect.element` and the locators type-check, and include the test files in the project ([setup](02-project-setup-and-tooling.md#tsconfig)).

### Logic tests

- Test logic without a component whenever you can. The Vue documentation advises unit tests for plain functions, composables and stores, because they are simpler and faster. They run in the `unit` project.
- Test a composable without lifecycle hooks as a plain function. Test one that creates watchers or registers cleanup inside an `effectScope()`, so that you can stop it: `const scope = effectScope(); const result = scope.run(() => useFetchJson(schema, url)); ... scope.stop();`.
- Test a composable that uses `onMounted()` or `inject()` in the `component` project, inside a tiny component that calls it. A lifecycle hook called outside a component logs a warning, and a plain call to `inject()` has nothing to inject from.
- Test a store with a fresh Pinia: `setActivePinia(createPinia())` in `beforeEach`. Call the actions and read the state, as the sample does.
- Stub the network, the clock and the browser APIs only: `vi.stubGlobal("fetch", vi.fn<typeof fetch>(...))`, restored with `vi.unstubAllGlobals()` in `afterEach`. Give the double the type of what it replaces, as the TypeScript notes say. Do not mock Vue, Pinia or your own modules. The Vitest documentation recommends Mock Service Worker (MSW) for request mocking. Use `vi.stubGlobal()` while a handful of tests need one response each, and adopt MSW when many tests share handlers or need to test request details.
- Await asynchronous state with `vi.waitFor(() => expect(...))`, and never with a real `setTimeout`. After a ref changes in a unit test, `await nextTick()` before you assert on the DOM or on a watcher with the default flush.
- Use fake timers for a debounce or a timeout (`vi.useFakeTimers()`), and restore them in `afterEach`.

```ts
import { effectScope, nextTick, ref } from "vue";
import { describe, expect, it, vi } from "vitest";

describe("useFetchJson", () => {
  it("refetches when the url changes", async () => {
    vi.stubGlobal("fetch", vi.fn<typeof fetch>((input) =>
      Promise.resolve(Response.json({ name: typeof input === "string" ? input : "other" })),
    ));
    const url = ref("/a");
    const scope = effectScope();
    const result = scope.run(() => useFetchJson(schema, url));
    await vi.waitFor(() => expect(result?.data.value).toEqual({ name: "/a" }));
    url.value = "/b";
    await nextTick();
    await vi.waitFor(() => expect(result?.data.value).toEqual({ name: "/b" }));
    scope.stop();
  });
});
```

### Component tests

- Test a component through its public interface: its props and slots go in, and the DOM and the emitted events come out. Vue's documentation says to test what a component does, not how it does it. Do not read a component's internal state, call its methods, or assert on the order of its internal calls.
- Render with `render(Component, { props, slots, global })` and `await` it, because `render` returns a promise in `vitest-browser-vue` 3. Query the result like a user: `screen.getByRole("button", { name: "Ayu" })`, `getByRole("textbox", { name: "Note" })`, `getByText`. A role and an accessible name also check that the component is accessible. Use a `data-testid` only when nothing else identifies the element.
- Interact with `await locator.click()` and `await locator.fill("paid")`. Assert on the DOM with the retrying `await expect.element(locator).toBeVisible()` and `toHaveTextContent()`, not with a one-off read.
- Assert on emitted events with `screen.emitted("select")`, which returns the list of argument lists: `expect(screen.emitted("select")).toEqual([["1"]])`. A `v-model` component emits `update:modelValue`, or `update:note` for a named model.
- Provide what the component needs through `global.plugins`: a router built with `createRouter({ history: createMemoryHistory(), routes })`, and `createPinia()` for a store. Give a router a route that the component links to, so that `RouterLink` resolves. Prefer the real router and the real Pinia to a mock. Stub only the network.
- Do not mock a child component. Render the whole tree that the user sees, as the Vue documentation advises for component tests. Stub a heavy third-party child only when it needs a browser feature that the test cannot give.
- Test that a loading state, an error state and the data state each show. Return a failing response from the stubbed `fetch` to test the error state: the sample's `500` response shows the `role="alert"` message.
- Test an error boundary with a child whose `setup()` throws, as the sample does, and assert on the fallback and the `error` event.
- Do not snapshot a whole component. A snapshot fails for any change and tells the reader nothing. Assert on what matters.
- Test accessibility by querying with roles and names. Add an automated accessibility check (axe) as a separate end-to-end step if the project needs it; the lint rules do not replace it ([templates](06-templates-styling-and-accessibility.md#accessibility)).
- A test of a `<style scoped>` rule or of a pixel position belongs in an end-to-end or screenshot test, not in a component test.
- Test your own logic and your own types, not what Vue guarantees: do not test that `ref` is reactive.

### Type tests

- Test the types of a generic component or composable that other code relies on, with `expectTypeOf` in a `*.test-d.ts` file, run with `vitest run --typecheck`, as the TypeScript notes say. Pin `vitest` to an exact version while you use type tests. Type-check a `.vue` file's props in the application build, which `vue-tsc` already does.

## Sources and raw notes

Pages read on 2026-11-20:

- [Vue testing guide](https://vuejs.org/guide/scaling-up/testing.html): unit, component and end-to-end tests; Vitest as the recommended runner; component testing advice (test the public interface, do not mock child components, test what a component does and not how); testing composables; the Vue Test Utils, Cypress and Testing Library examples.
- [Vue tooling](https://vuejs.org/guide/scaling-up/tooling.html): Vitest, Cypress and Jest.
- [Vitest Browser Mode](https://vitest.dev/guide/browser/) and [Vitest component testing](https://vitest.dev/guide/browser/component-testing.html): "Browser Mode is the recommended approach for component testing", `vitest-browser-vue` as the official Vue package, MSW as the recommended way to mock requests, Playwright as the recommended provider.
- [Pinia testing cookbook](https://pinia.vuejs.org/cookbook/testing.html): `setActivePinia(createPinia())` for a store test.
- `vitest-browser-vue` 3.1.0: `render()` returns a promise of the render result, which has `emitted()`, `getByRole()` and the other locators. This was read from the TypeScript error that `vue-tsc` gave when a test did not `await` it.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): nine tests in six files: four unit tests in three files (a filter composable, a fetch composable in an `effectScope()` with a stubbed `fetch`, two tests, and a Pinia store) and five browser tests in three files (a row component's click and `v-model` events, a detail view with a memory router and a stubbed `fetch` for the data and the `500` cases, and an error boundary). `vitest run` passed. A composable that touched `document` failed in the Node.js project, and `optimizeDeps.include: ["vue"]` on the `component` project removed the reload warning on a cold cache.
