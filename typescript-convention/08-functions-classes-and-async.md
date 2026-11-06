# TypeScript Functions, Classes and Async Code

- Responsibility: engineering
- Area/system: typescript
- Keywords: function declaration, arrow function, options object, boolean parameter, default parameter, overloads, return type, immutability, toSorted, structuredClone, class, parameter properties, override, async, await, Promise.all, Promise.allSettled, floating promises, no-misused-promises, AbortSignal.timeout, require-await
- Aliases: fungsi TypeScript, TypeScript async await, promise TypeScript, kelas TypeScript, options object, parameter boolean, floating promise, TypeScript function style
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [types and type design](04-types-and-type-design.md), [error handling](09-error-handling.md), [TypeScript in React](11-typescript-in-react.md), [runtime validation](05-runtime-validation-and-external-data.md).

## Summary

Write small functions with named options instead of long parameter lists, avoid mutation, and use classes only where an object needs identity or a lifecycle. Handle every promise, start independent work together, and give every network call a timeout.

## Rules

### Functions

- Declare a named function with `function`, including a React component. Use an arrow function for a callback and for a short inline function.
- Take at most three positional parameters. When a function needs more, or has optional ones, take one options object that has its own `interface`. Read the options by destructuring, with defaults in the pattern.
- Do not add a boolean parameter that switches behaviour. Name it as an option (`dryRun`), or write two functions.
- Let inference work inside components, handlers and local functions. Write the return type of an exported function in a data-access or shared `lib/` module, because it is a contract that callers rely on.
- Use overloads only when the return type depends on the parameter type. Otherwise use a union or a generic.
- Do not change a parameter or a shared object. Return a new value, and prefer `toSorted`, `toSpliced`, `with`, spreading and `structuredClone` to `sort`, `splice`, `reverse` and assignment.
- Mark a parameter you only read as `readonly` (`readonly string[]`).
- Handle the empty case of an indexed read. With `noUncheckedIndexedAccess`, destructure the first element and test it.

```ts
interface SendEmailOptions {
  to: string;
  subject: string;
  dryRun?: boolean;
}

export function sendEmail({
  to,
  subject,
  dryRun = false,
}: SendEmailOptions): string {
  return dryRun ? `Would send "${subject}" to ${to}` : `Sent "${subject}" to ${to}`;
}

export function firstOrThrow<T>(items: readonly T[]): T {
  const [first] = items;
  if (first === undefined) throw new Error("Expected at least one item");
  return first;
}

export function parseId(value: string): number;
export function parseId(value: readonly string[]): number[];
export function parseId(value: string | readonly string[]): number | number[] {
  return typeof value === "string"
    ? Number(value)
    : value.map((item) => Number(item));
}
```

### Classes

- Prefer functions and plain objects. Write a class for an `Error` subclass ([error handling](09-error-handling.md#custom-errors)) and for an object that owns a resource and its lifecycle.
- Do not use parameter properties (`constructor(private service: Service)`). Declare the field and assign it. `erasableSyntaxOnly` rejects the shortcut.
- Mark a field `readonly` when it never changes, and mark an overriding method `override` (`noImplicitOverride`).
- Do not write a class that only holds static members. Export functions instead. Do not build an inheritance chain deeper than one level. Compose objects instead.

### Async code

- Write `async` and `await`. Do not mix a `.then()` chain and `await` in one function.
- Handle every promise: `await` it, return it, or mark a deliberate fire-and-forget call with `void` and handle its errors inside the called function. `no-floating-promises` reports the rest.
- Do not pass an `async` function where the caller expects a function that returns nothing, such as a React event handler: `no-misused-promises` reports it. Call the async function from a normal handler (`onClick={() => void save()}`).
- Start independent requests together with `Promise.all`. Use `Promise.allSettled` when a partial result is acceptable. Do not `await` inside a loop whose iterations are independent.
- Give every network call a timeout and pass the cancel signal on: `AbortSignal.timeout(5_000)` ([runtime validation](05-runtime-validation-and-external-data.md#validating-data)).
- Write `await` in every `async` function (`require-await`). When there is nothing to await, return the promise from a normal function.
- Wrap a callback API in `new Promise`, and never wrap a function that already returns a promise.
- Reject only with an `Error` (`prefer-promise-reject-errors`).

```ts
interface Loan {
  id: string;
}

interface Payment {
  loanId: string;
}

interface Account {
  loans: Loan[];
  payments: Payment[];
}

declare function fetchLoans(userId: string): Promise<Loan[]>;
declare function fetchPayments(userId: string): Promise<Payment[]>;
declare function saveAudit(event: string): Promise<void>;

export async function loadAccount(userId: string): Promise<Account> {
  const [loans, payments] = await Promise.all([
    fetchLoans(userId),
    fetchPayments(userId),
  ]);
  void saveAudit(`loaded ${userId}`);
  return { loans, payments };
}
```

## Sources and raw notes

Pages read on 2026-10-26:

- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html): prefer function declarations for named functions, arrow functions for callbacks, parameter initializers, `override`, no container classes, disallowed class patterns.
- The `recommended-type-checked` rules of `typescript-eslint@8.72.0` ([shared configs](https://typescript-eslint.io/users/configs)): `no-floating-promises`, `no-misused-promises`, `require-await`, `await-thenable`, `prefer-promise-reject-errors`.
- The two code blocks compiled under the Next.js baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application) with TypeScript 5.9.3 and passed the lint config of [setup](02-project-setup-and-tooling.md#linting) without a finding. `toSorted` ran on Node.js 22.14.0.
- Class counts come from the TypeScript syntax tree of both repositories, run on 2026-10-26.
