# TypeScript Error Handling

## Summary

Throw `Error` objects for faults, and keep the original error as the `cause`. Return a typed result when failure is a normal outcome, such as invalid input. Catch only what the code can handle, narrow the caught value before use, and log once at the boundary.

## Rules

### Throwing

- Throw and reject only `Error` objects. A string or a plain object has no stack trace. `only-throw-error` and `prefer-promise-reject-errors` report the rest.
- Create errors with `new`, and keep the original error as the cause: `new Error("Cannot save order 42", { cause: error })`. State what the code was doing and to which value, so that the message reads well at the top of a log line.
- Throw for faults: an upstream failure, a broken invariant, data that must be valid and is not. Do not throw for a normal outcome ([expected failures](#expected-failures)).

```ts
interface Order {
  id: string;
}

declare function save(order: Order): Promise<void>;

export async function saveOrder(order: Order): Promise<void> {
  try {
    await save(order);
  } catch (error) {
    throw new Error(`Cannot save order ${order.id}`, { cause: error });
  }
}
```

### Custom errors

- Write an error subclass when callers branch on the condition or need data from it, such as an HTTP status. Set `name`, pass `options` to `super` so that `cause` survives, and declare the extra fields `readonly`.
- Test for a subclass with `instanceof`. Never test the message text or the `name`.
- Keep the set small and flat. Do not build a hierarchy.

```ts
export class HttpError extends Error {
  readonly status: number;

  constructor(status: number, message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "HttpError";
    this.status = status;
  }
}

export function toError(value: unknown): Error {
  return value instanceof Error
    ? value
    : new Error(String(value), { cause: value });
}
```

### Catching

- In `catch (error)` the value is `unknown`, because `strict` turns on `useUnknownInCatchVariables`. Do not annotate it with `any`. Narrow it with `instanceof Error` before you read `message`, or convert it with `toError`.
- Catch only an error that the code can handle. Otherwise let it propagate. Do not catch an error to log it and throw it again, because that logs the same fault at every layer.
- Keep the `try` block to the statements that can throw.
- Do not leave a `catch` block empty. When ignoring the error is correct, say why in a comment inside the block.
- Existing code: remove the `any` annotation from `catch` clauses in the lines you change.

### Expected failures

- Return a result when failure is a normal outcome: a parser that rejects arbitrary text, a form that the user filled in wrong, a lookup that may find nothing. A union that you narrow with `ok` keeps the failure in the type.
- Use the result of `safeParse` for schemas, and a state object for a form ([forms](../nextjs-conventions/06-mutations-and-forms.md#validation-and-errors)). Do not add a result library. `neverthrow` has 2.2 million weekly downloads, and the three-line union below covers these cases.

```ts
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export function parsePort(text: string): Result<number, string> {
  const port = Number.parseInt(text, 10);
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    return { ok: false, error: `Invalid port: ${text}` };
  }
  return { ok: true, value: port };
}
```

### Errors at the boundary

- Log an error once, where the request, the job or the render ends: a Route Handler, a Server Function, a script's `main` function or an error boundary. Log the whole chain, `cause` included.
- Return a client-safe message from the boundary. Never send the `message` of an unexpected error to the client.
- A new Route Handler returns errors as RFC 9457 problem details (`application/problem+json` with `title`, `status` and `detail`), as the Go services do ([errors at the boundary](../golang-conventions/08-error-handling.md#errors-at-the-boundary)). An existing API keeps its current body, and a published body changes only with a new API version.

```ts
import { type HttpStatus } from "@/lib/http-status";

export function problem(status: HttpStatus, title: string, detail?: string): Response {
  return Response.json(
    { title, status, detail },
    { status, headers: { "Content-Type": "application/problem+json" } },
  );
}
```

The type of `status` comes from the table of [status codes](#status-codes).

- The error boundaries of Next.js (`error.tsx`) receive an `unknown` error that you narrow before use ([Next.js error handling](../nextjs-conventions/07-error-handling-and-loading.md)).

### Status codes

- Name every HTTP status in your own code with a constant, and write no bare number: `error(HTTP_STATUS.notFound, "…")`, `redirect(HTTP_STATUS.seeOther, …)`, `fail(HTTP_STATUS.unprocessable, …)`, `Response.json(value, { status: HTTP_STATUS.unprocessable })`, and `{ status: HTTP_STATUS.notFound }` in a test assertion. The Go notes do the same with `http.StatusNotFound`, and the web platform has no named constants for a status.
- A number may stay where it is data and not code: a status in a JSON body that an example shows (`"status": 404`), and a status in prose.
- Keep the table in one module of the project, such as `lib/http-status.ts`, and import it where you use it (`@/lib/http-status` in a Next.js or Vite project, `#lib/http-status.ts` in a SvelteKit one). Make it an `as const` object and derive the union from it, as the [types note](04-types-and-type-design.md) says for other lists. Do not write an `enum`:

```ts
export const HTTP_STATUS = {
  ok: 200,
  created: 201,
  noContent: 204,
  movedPermanently: 301,
  seeOther: 303,
  permanentRedirect: 308,
  badRequest: 400,
  unauthorized: 401,
  forbidden: 403,
  notFound: 404,
  conflict: 409,
  unprocessable: 422,
  internalServerError: 500,
} as const;

export type HttpStatus = (typeof HTTP_STATUS)[keyof typeof HTTP_STATUS];
```

- Type a parameter or a result that holds a status of your own as `HttpStatus`, as `problem` does above. A code that is not in the table (`418`) is then a type error, and a value of `HttpStatus` is assignable to `number`, so it works wherever a framework takes a status.
- Name the object in `CONSTANT_CASE`, its properties in `lowerCamelCase` after the standard reason phrase (`notFound`, `unprocessable`, `seeOther`) and the type in `UpperCamelCase`, as the [naming note](07-naming-comments-and-style.md#naming) says.
- Add a code to the table when the project first uses it, as the principle "wait for a second use case" says. Do not copy the whole registry into every project.
- Compare a status that arrives from outside with the same constants (`response.status === HTTP_STATUS.ok`). It is a `number` there, and the table is for naming the codes, not for validating them.
- Do not import the constants from `node:http2` (`http2.constants.HTTP_STATUS_NOT_FOUND`). The module loads HTTP/2 code that the project does not use, and `node:` imports do not exist in browser and edge code. `node:http` exports no numeric constants, only `STATUS_CODES`, a map from a code to its reason phrase.
- Do not add an npm package for the table. It is about fifteen lines, and the [principles](01-principles-and-sources.md#principles) ask for a dependency only when it removes real complexity.

## Sources and raw notes

Pages read on 2026-10-26:

- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html): exception handling (instantiate errors with `new`, only throw errors, catching and rethrowing, empty catch blocks), keeping `try` blocks focused. The guide prefers exceptions to ad-hoc error containers. The `Result` union here is limited to normal outcomes, which the Next.js notes already return as values.
- The `recommended-type-checked` rules of `typescript-eslint@8.72.0`: `only-throw-error`, `prefer-promise-reject-errors`. [TypeScript `useUnknownInCatchVariables`](https://www.typescriptlang.org/tsconfig/#useUnknownInCatchVariables) is part of `strict`.
- [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) through the Go notes ([errors at the boundary](../golang-conventions/08-error-handling.md#errors-at-the-boundary)).
- npm weekly downloads (`api.npmjs.org`, 2026-10-16 to 2026-10-22): `neverthrow` 2,207,892.
- Before 2026-11-19, the four code blocks compiled under the Next.js baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application) with TypeScript 5.9.3 and passed the lint config of [setup](02-project-setup-and-tooling.md#linting) without a finding. Under `node --experimental-strip-types` on Node.js 22.14.0, `problem(404, "Not Found", "Loan 42 was not found")` returned status 404 with the content type `application/problem+json` and the body `{"title":"Not Found","status":404,"detail":"Loan 42 was not found"}`, and a wrapped `Error` kept its `cause`.
- `catch` annotations counted in the TypeScript syntax tree of both repositories on 2026-10-26.
- Checked on 2026-11-19 with TypeScript 6.0.3 under `strict`, `erasableSyntaxOnly`, `verbatimModuleSyntax` and `noUncheckedIndexedAccess`: the `HTTP_STATUS` block compiled, `problem(HTTP_STATUS.notFound, …)` was accepted, and `problem(418, …)` was a type error. The same constants were used in the SvelteKit sample application (`error`, `fail` and `redirect` with `HTTP_STATUS`), which passed `svelte-check`, ESLint and `vite build`. The `problem` block that takes `HttpStatus` was changed on 2026-11-19 and compiled with the table in a scratch file. On Node.js v26.13.1, `node:http` exported only `STATUS_CODES` (`STATUS_CODES[404]` is `Not Found`), and `node:http2` `constants` held 63 `HTTP_STATUS_*` entries.
