# TypeScript Testing

## Summary

Test TypeScript with Vitest, keep the tests inside the type check, build fixtures with typed helpers, and avoid `any` in tests. Test the types of generic helpers and complex types with `expectTypeOf`. The Next.js notes cover end-to-end tests and the performance gates.

## Rules

### Tools

- Use Vitest for unit and component tests. It has 83.7 million weekly downloads, against 28.0 million for Jest. Playwright covers end-to-end tests ([Next.js testing](../nextjs-convention/11-testing-and-quality-gates.md#choosing-the-test-tool)).
- Put a test next to the code it tests (`loan.test.ts` beside `loan.ts`), and a type test in a `*.test-d.ts` file. Keep end-to-end tests in `e2e/`.
- Import the test API from `vitest` (`import { describe, expect, it, vi } from "vitest"`). Do not turn on `globals`, so that no `types` entry is needed.
- Include the test files in `tsconfig.json`, so that `npm run typecheck` and the lint config cover them. A type error in a test fails the build.
- Run the tests with `"test": "vitest run"` ([scripts](02-project-setup-and-tooling.md#scripts)).

### Writing tests

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
- npm weekly downloads (`api.npmjs.org`, 2026-10-16 to 2026-10-22): `vitest` 83,654,107, `jest` 27,983,327, `@playwright/test` 49,812,826.
- The examples were run in a scratch project on 2026-10-26, with Vitest 5.0.5, TypeScript 6.0.3 and Node.js 22.14.0. The three code blocks, extracted from this note, import `@/lib/loan`, which holds the two snippets of [types](04-types-and-type-design.md#model-alternatives-with-unions). They type-checked under the Next.js baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application) (with the `@/*` alias pointing at `src`), `vitest run` passed 5 tests, `vitest run --typecheck` passed 7 tests with no type errors, and the typed lint config of [setup](02-project-setup-and-tooling.md#linting) reported nothing.
- Two type-test claims were checked in the same project. A wrong `toEqualTypeOf` failed as a test (`TypeCheckError`) and the file did not run. A typo behind `// @ts-expect-error` passed under `--typecheck` alone, and failed with a `ReferenceError` when the `*.test-d.ts` file was in `test.include`.
- Test files and `test` scripts counted in both repositories on 2026-10-26.
