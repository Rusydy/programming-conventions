# Svelte Testing

## Summary

Test with Vitest, in two projects: reactive logic and plain functions run in Node.js, and components run in a real browser through Vitest Browser Mode and `vitest-browser-svelte`. Move logic out of components so that most tests need no component. The TypeScript testing rules apply to every test file.

## Rules

### Tools

- Use Vitest for every test. A Svelte test needs the Svelte compiler for runes in test files and for components, so `node:test` does not fit, and the [TypeScript testing note](../typescript-conventions/10-testing.md#tools) allows Vitest for component tests.
- Import the test API from `vitest` and do not turn on `globals`, as the TypeScript notes say.
- Run two Vitest projects in one config: `unit` in Node.js for logic, and `component` in a browser for components. Run both with `"test": "vitest run"`.
- Test a component in a real browser with `vitest-browser-svelte` and the Playwright provider. Vitest calls Browser Mode the recommended approach for component tests, and it catches layout and browser behaviour that a simulated DOM cannot ([decisions to review](01-principles-and-sources.md#decisions-to-review)). The Svelte documentation shows jsdom and Testing Library instead. Use that only in a project that cannot run a browser, and record why.
- Install the tools and one browser:

```bash
npm install -D vitest vitest-browser-svelte @vitest/browser-playwright playwright
npx playwright install chromium
```

- Write end-to-end tests with Playwright against `vite preview`, as the Svelte testing page describes. A Wails app needs its own end-to-end approach, which these notes do not cover.

```ts
// vite.config.ts
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { playwright } from "@vitest/browser-playwright";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [svelte()],
  test: {
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
});
```

- Add `vitest/config` to the type check by keeping `vite.config.ts` in `tsconfig.node.json`. Include the test files in `tsconfig.app.json`, so that a type error in a test fails `npm run check` ([setup](02-project-setup-and-tooling.md#tsconfig)).
- Cache the Playwright browser in CI, and install it with `npx playwright install --with-deps chromium` on a Linux runner.

### Where tests live

- Put a test next to the file it tests, as the TypeScript notes say. Name it after that file.
- Name a unit test `name.test.ts`, and a component test `name.browser.test.ts`. The `unit` project skips the `.browser.test.ts` files, and the `component` project runs only them.
- Name a test file `name.svelte.test.ts` when the test itself uses a rune, such as `$state` or `$effect.root`. The `.svelte` in the name makes the compiler transform the runes in the test.
- A test file is TypeScript and follows every rule of the TypeScript testing note: typed fixtures built with `Partial<T>` overrides, no `any`, assertions on errors by class and data, and fake timers restored in `afterEach`.

### Logic tests

- Test logic without a component whenever you can. The Svelte documentation advises it, because it is simpler. A function in a `.ts` file, or a class in a `.svelte.ts` file, runs in the `unit` project.
- Create a fresh instance in each test, and do not share one between tests. Reset a module-level instance in `beforeEach` ([state sharing](07-state-sharing-and-context.md#module-level-instance)).
- Call `flushSync()` from `svelte` after you change state and before you assert on a `$derived` value that the test reads, or on an effect that ran:

```ts
import { flushSync } from "svelte";
import { describe, expect, it } from "vitest";

import { LoanList } from "./loan-list.svelte";

describe("LoanList", () => {
  it("derives the open loans and the selected loan", () => {
    const list = new LoanList();
    list.loans = [
      { id: "1", borrower: "Ayu", amountMinor: 100, status: "open" },
      { id: "2", borrower: "Budi", amountMinor: 200, status: "paid" },
    ];
    list.select("2");
    flushSync();

    expect(list.open.map((loan) => loan.id)).toEqual(["1"]);
    expect(list.selected?.borrower).toBe("Budi");
  });
});
```

- To test code that uses `$effect`, wrap the test body in `$effect.root(() => { ... })`, call `flushSync()` to run the effects, and call the cleanup function that `$effect.root` returns at the end.

### Component tests

- Render a component with `render` from `vitest-browser-svelte`, find elements the way a user does (`getByRole`, `getByLabelText`, `getByText`), act through the returned locators, and assert on what the user sees and on callback props:

```ts
import { expect, it, vi } from "vitest";
import { render } from "vitest-browser-svelte";

import LoanRow from "./loan-row.svelte";

it("calls onSelect with the loan id when the row is clicked", async () => {
  const onSelect = vi.fn();
  const screen = await render(LoanRow, {
    loan: { id: "7", borrower: "Ayu", amountMinor: 150000, status: "open" },
    onSelect,
  });

  await screen.getByRole("button", { name: /Ayu/ }).click();

  expect(onSelect).toHaveBeenCalledExactlyOnceWith("7");
});
```

- Query by role and accessible name first. A test that finds an element by class or by test id gives you no check that a user or a screen reader can find it.
- Do not test what Svelte already guarantees, such as that `$derived` recomputes or that `bind:value` updates a variable. Test your own behaviour.
- To test a component that uses context, a two-way binding or a snippet prop, write a small wrapper component for the test. It calls `set` of the context pair or passes the snippet, and renders the component under test.
- Mock only a boundary: the network, the clock and the Go bindings of a desktop app. Give a double the type of what it replaces, as the TypeScript notes say. Do not mock a child component.
- Keep component tests few and about behaviour. A test per prop combination slows the suite and breaks on every refactor.

## Sources and raw notes

Pages read on 2026-11-18:

- [Svelte testing](https://svelte.dev/docs/svelte/testing): Vitest, `*.svelte.test.ts` files for runes, `flushSync` and `$effect.root`, the advice to extract logic first, jsdom with Testing Library, wrapper components for bindings, context and snippets, and Playwright against a built app.
- [Vitest component testing](https://vitest.dev/guide/browser/component-testing): Browser Mode is "the recommended approach for component testing", and `vitest-browser-svelte` is an official framework package.
- [Svelte context](https://svelte.dev/docs/svelte/context): wrapper components for tests.
- npm registry on 2026-11-18: `vitest` 5.1.1, `@vitest/browser-playwright` 5.1.1 (peer `vitest` 5.1.1 and `playwright`), `vitest-browser-svelte` 3.1.0 (peer `svelte` 3 to 5, `vitest` 4 or 5), `@testing-library/svelte` 5.4.2, `playwright` 1.65.1.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): both projects of the config above ran, with 2 test files and 2 tests passing under Vitest 5.1.1. The Playwright build that `playwright` 1.65.1 expects was not installed on the machine, so the browser project ran with the already installed Chromium 1254 headless shell, passed through `launchOptions.executablePath`, and the note leaves that setting out. The unit project ran by itself with `vitest run --project unit` and passed.
- The `npx playwright install --with-deps chromium` command and the CI cache advice come from the Playwright documentation and were not run.
