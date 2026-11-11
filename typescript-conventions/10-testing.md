# TypeScript Testing

## Summary

Test TypeScript with Vitest, keep the tests inside the type check, build fixtures with typed helpers, and avoid `any` in tests. Test the types of generic helpers and complex types with `expectTypeOf`. The Next.js notes cover end-to-end tests and the performance gates.

## Rules

### Tools

- Choose one runner for each project. Use `node:test` with `node:assert/strict` for Node.js-only code that needs no DOM, no `expectTypeOf` and no module mocking. `node --test` finds `.test.ts` files only while type stripping is on, which is the default from Node.js 22.18. Use Vitest for component tests, which need a DOM, for type tests and for code that needs module mocking, and say in the pull request why `node:test` does not fit. A project that needs Vitest for any of these uses it for all its tests. Playwright covers end-to-end tests ([Next.js testing](../nextjs-conventions/11-testing-and-quality-gates.md#choosing-the-test-tool)).
- Put a test next to the code it tests (`loan.test.ts` beside `loan.ts`), and a type test in a `*.test-d.ts` file. Keep end-to-end tests in `e2e/`.
- Import the test API from the runner: `import { describe, expect, it, vi } from "vitest"` for Vitest, or `import { describe, it } from "node:test"` for `node:test`. Do not turn on Vitest's `globals`, so that no `types` entry is needed.
- Include the test files in `tsconfig.json`, so that `npm run typecheck` and the lint config cover them. A type error in a test fails the build.
- Run the tests with `"test": "vitest run"` in a Vitest project, or with `"test": "node --test"` in a project that uses only `node:test` ([scripts](02-project-setup-and-tooling.md#scripts)).

A Node.js-only module, tested with `node:test`:

```ts
// greet.ts
export function greet(name: string): string {
  return `Hello, ${name}`;
}
```

```ts
// greet.test.ts
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { greet } from "./greet.ts";

describe("greet", () => {
  it("names the reader", () => {
    assert.equal(greet("Ada"), "Hello, Ada");
  });
});
```

### Writing tests

The examples in this section and the next two use Vitest.

- Name a `describe` block after the unit and an `it` block as a sentence about its behaviour.
- Write a table with `it.each` when the cases share their logic. Give the table an `interface`, so that each case is type-checked, and put a `name` in every case.
- Build fixtures with a typed helper that takes `Partial<T>` overrides, and not with copies of a literal. The compiler then reports a fixture that no longer matches the type.
- Assert an error by its class and data, not by its message: `await expect(getLoan("missing")).rejects.toMatchObject({ status: 404 })` ([custom errors](09-error-handling.md#custom-errors)).
- Control time with `vi.useFakeTimers()`, and restore it in `afterEach`. Never wait with a real `setTimeout`.
- Test your own logic and your own types. Do not test what a library or the framework already guarantees.

```ts
import { describe, expect, it } from "vitest";
import { describePayment } from "@/lib/loan";
import type { Loan, PaymentResult } from "@/lib/loan";

function buildLoan(overrides: Partial<Loan> = {}): Loan {
  return {
    id: "loan-1",
    amountMinor: 150_000,
    status: "pending",
    ...overrides,
  };
}

interface PaymentCase {
  name: string;
  result: PaymentResult;
  expected: string;
}

const cases: PaymentCase[] = [
  {
    name: "paid",
    result: { kind: "paid", paidAt: "2026-10-26T08:00:00Z" },
    expected: "Paid at 2026-10-26T08:00:00Z",
  },
  {
    name: "failed",
    result: { kind: "failed", reason: "no funds" },
    expected: "Failed: no funds",
  },
  { name: "pending", result: { kind: "pending" }, expected: "Waiting for payment" },
];

describe("describePayment", () => {
  it.each(cases)("describes a $name payment", ({ result, expected }) => {
    expect(describePayment(result)).toBe(expected);
  });
});

describe("buildLoan", () => {
  it("lets a test override one field", () => {
    expect(buildLoan({ status: "paid" })).toMatchObject({ id: "loan-1", status: "paid" });
  });
});
```

### Test doubles

- Prefer the real implementation when it is cheap: a pure function, an in-memory object, a schema.
- Give a double the type of what it replaces. Pass a typed implementation to `vi.fn`, and the double takes the parameter and return types from it.
- When a test needs only part of a large dependency, write one cast with a comment that says what the test leaves out: `{ fetchLoans } as unknown as LoanApi`. Keep that cast in the test.
- Do not use `any` in a test. When it is unavoidable, disable `no-explicit-any` on that line and say why in the same comment.
- Mock a module (`vi.mock`) only at a boundary: the network, the clock, the file system.

```ts
import { expect, it, vi } from "vitest";
import type { Loan } from "@/lib/loan";

it("passes the user id to the loader", async () => {
  const fetchLoans = vi.fn(
    (userId: string): Promise<Loan[]> =>
      Promise.resolve([{ id: userId, amountMinor: 1, status: "paid" }]),
  );

  const loans = await fetchLoans("user-1");

  expect(fetchLoans).toHaveBeenCalledWith("user-1");
  expect(loans).toHaveLength(1);
});
```

### Type tests

- Test the types of an exported generic helper, a schema-derived type and any conditional or mapped type with `expectTypeOf` in a `*.test-d.ts` file. Vitest calls `tsc` and reports a type error as a failing test, and it does not run the file.
- Run type tests by adding the `--typecheck` flag to the Vitest command.
- Pin `vitest` to an exact version in `package.json` while you use type tests. Vitest prints that type testing is experimental and that breaking changes might not follow SemVer.
- Write `// @ts-expect-error` with a description, because the lint config requires one. Also list the file in `test.include`, so that Vitest runs it and a typo in the line below the comment fails the test, as the Vitest documentation advises.

```ts
import { expectTypeOf, test } from "vitest";
import { describePayment } from "@/lib/loan";
import type { LoanStatus } from "@/lib/loan";

test("describePayment returns a string", () => {
  expectTypeOf(describePayment).returns.toEqualTypeOf<string>();
});

test("LoanStatus lists the three statuses", () => {
  expectTypeOf<LoanStatus>().toEqualTypeOf<"pending" | "paid" | "overdue">();
});
```

## Sources and raw notes

Pages read on 2026-10-26:

- [Vitest: testing types](https://vitest.dev/guide/testing-types) (`expectTypeOf`, `assertType`, `*.test-d.ts`, `--typecheck`, the `@ts-expect-error` tip), [`vi.fn`](https://vitest.dev/api/vi), [`test.each`](https://vitest.dev/api/test) and [`expect`](https://vitest.dev/api/expect) (`rejects`, `toMatchObject`). npm: `vitest` is 5.0.5.
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html): suppressing `any` warnings in tests with a comment, partial mocks with a documented cast, and the limits of `@ts-expect-error`.
- Pages read on 2026-11-10: the [Node.js test runner](https://nodejs.org/api/test.html) page (v26.13.0 documentation). The runner is Stable, `mock.module` is Early development, and the page describes no DOM and no type-test API.
- The `node:test` example above ran on 2026-11-10 with `node --test` in a scratch project that uses the [Node.js baseline](03-tsconfig.md#baseline-for-a-nodejs-project). It passed on Node.js 24.22.1 and 26.13.0, one test each, with exit code 0. On Node.js 22.14.0 the same command found no test and still exited with code 0, which is why the minimum version matters. Node.js 22.18, the first 22.x release with type stripping on by default, was not run because it is not installed.
- The same project type-checked with TypeScript 5.9.3 and `@types/node` 24.19.2 under the baseline, with no errors. A deliberate type error in a `.ts` file was reported (TS2322 and TS2345), so the check covers test files. TypeScript 6.0.3 was not run because it is not installed locally.
- The examples were run in a scratch project on 2026-10-26, with Vitest 5.0.5, TypeScript 6.0.3 and Node.js 22.14.0. The three code blocks, extracted from this note, import `@/lib/loan`, which holds the two snippets of [types](04-types-and-type-design.md#model-alternatives-with-unions). They type-checked under the Next.js baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application) (with the `@/*` alias pointing at `src`), `vitest run` passed 5 tests, `vitest run --typecheck` passed 7 tests with no type errors, and the typed lint config of [setup](02-project-setup-and-tooling.md#linting) reported nothing.
- Two type-test claims were checked in the same project. A wrong `toEqualTypeOf` failed as a test (`TypeCheckError`) and the file did not run. A typo behind `// @ts-expect-error` passed under `--typecheck` alone, and failed with a `ReferenceError` when the `*.test-d.ts` file was in `test.include`.
- Test files and `test` scripts counted in both repositories on 2026-10-26.
