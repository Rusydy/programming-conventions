# Nuxt Server Routes and Validation

## Summary

The `server/` directory is a Nitro server with no Vue in it. Each file in `server/api/` is one handler, named for its route and method, that imports its helpers from `nuxt/server`. Every handler validates its input with a Zod schema, annotates its return type with a type from `shared/`, throws `createError()` for failures that the client may see, and lets everything else become a generic 500.

## Rules

### The boundary

- Keep three zones apart: `app/` (the Vue app, in the browser and on the server during rendering), `server/` (Nitro handlers, middleware, plugins and utilities), and `shared/` (code with no Vue and no Nitro in it). `app/` never imports from `server/`, `server/` never imports from `app/`, and `shared/` imports from neither. The Nuxt documentation says a cross import can break the build, fail at run time, or leak server code into the browser bundle.
- Put in `shared/` the Zod schemas of your API, the types that `z.infer` derives from them, constants and pure helpers such as `HTTP_STATUS`. Both sides then use one definition ([layout](03-project-layout-and-auto-imports.md#layout)).
- Put a helper that only a handler uses in `server/utils/`. Nitro auto-imports it in `server/`. Keep helpers that reach a database, a file or a secret there, so that they cannot reach the browser.
- Do not import `useNuxtApp()`, `useRoute()` or any other composable in `server/`. Nitro has no Vue context. Read the runtime config with `useRuntimeConfig(event)`.

### Handlers

- Name the file for the route and the method: `server/api/loans/index.get.ts` is `GET /api/loans`, `server/api/loans/index.post.ts` is `POST /api/loans`, and `server/api/loans/[id].get.ts` is `GET /api/loans/:id`. A file with no method suffix answers every method. Always write the method suffix, so that a stray `PUT` does not run your `GET` logic. A request with a method that no file handles answers 404 in Nuxt 4.6.4, which the sample confirmed for `PUT /api/loans/1` and `DELETE /api/loans`. Files in `server/routes/` have no `/api` prefix and are for non-API routes such as `/health`.
- Import the helpers from `nuxt/server`, the portable surface that Nuxt 4.6 ships, and not from `h3` or `nitropack`: `import { createError, defineEventHandler, getValidatedQuery } from "nuxt/server"`. It exports `defineEventHandler`, `createError`, `getValidatedQuery`, `readValidatedBody`, `getRouterParam`, `getRouterParams`, `getRequestURL`, `getRequestHeader`, `getCookie`, `setCookie`, `setResponseStatus`, `sendRedirect`, `useRuntimeConfig`, `useSession` and a few more. The documentation on the main branch also names `defineHandler`, which Nuxt 4.6.4 does not export yet; use `defineEventHandler`. Server code that imports only from `nuxt/server` keeps working when Nuxt 5 moves to Nitro 3 and h3 2.
- Default-export the handler. Annotate the return value, not the handler, with a domain type, because the return type is what types `$fetch` and `useFetch` in the app:

```ts
// server/api/loans/[id].get.ts
import { createError, defineEventHandler, getRouterParam } from "nuxt/server";

import type { Loan } from "#shared/types/loan";

export default defineEventHandler((event): Loan => {
  const id = getRouterParam(event, "id");
  if (id !== "1") {
    throw createError({
      status: HTTP_STATUS.notFound,
      statusText: "Loan not found",
    });
  }
  return { id, borrower: "Ayu", amountMinor: 100_000, currency: "IDR" };
});
```

- Return plain data. Nitro serialises it to JSON and sets the content type. Do not return a `Date`, a class instance, a `Map` or a `bigint`: send ISO 8601 strings and integers of minor units, as the TypeScript notes say. Do not return a database row; map it to the shared domain type, so that no internal column reaches the client.
- Set a status other than 200 with `setResponseStatus(event, HTTP_STATUS.created)`. Name every status with the `HTTP_STATUS` table in `shared/utils/http-status.ts`, as the TypeScript notes say, and never write a bare number in `createError`, `setResponseStatus`, `sendRedirect` or a test.
- Keep a handler short: parse input, call a function, map the result. Put logic in `server/utils/` functions that you can test without an event.
- A handler does not touch the DOM, `window` or the Vue instance, and it does not hold state in a module-level variable that depends on the user. A module-level value is shared by every request.
- Prefix no route with `/api/v1` until you publish an API to other clients. Then version it in the path and keep a published body unchanged ([TypeScript error notes](../typescript-conventions/09-error-handling.md)).

### Validation

- Hold every external value as `unknown` until a schema accepts it: the query, the body, the route params, the headers, the cookies and every response from an upstream service. Use `getValidatedQuery(event, schema)` and `readValidatedBody(event, schema)`; they take any Standard Schema, so a Zod schema goes in directly. An input that fails answers 400 with `data.issues` that list the failed fields, which the sample returned for a wrong body and for a repeated `q`.

```ts
// server/api/loans/index.post.ts
import {
  createError,
  defineEventHandler,
  readValidatedBody,
  setResponseStatus,
} from "nuxt/server";

import { loanSchema, type Loan } from "#shared/types/loan";

const bodySchema = loanSchema.omit({ id: true });

export default defineEventHandler(async (event): Promise<Loan> => {
  const body = await readValidatedBody(event, bodySchema);
  if (body.amountMinor <= 0) {
    throw createError({
      status: HTTP_STATUS.unprocessableContent,
      statusText: "Amount must be positive",
    });
  }
  setResponseStatus(event, HTTP_STATUS.created);
  return { id: crypto.randomUUID(), ...body };
});
```

- Declare the schema beside the handler, or in `shared/types/` when the browser validates the same shape. Derive the type with `z.infer` and export both from the `shared` file, as the TypeScript notes say. `z.coerce` is for query strings, which are always strings: `z.coerce.number().int().positive()`.
- A route param has no validated helper in `nuxt/server`. Read it with `getRouterParam(event, "id")` and parse it with `schema.safeParse`. Throw 400 (or 404) when it fails.
- Check business rules after the schema: an amount that is positive, a state that allows the change. A failed rule answers 422 (`unprocessableContent`), as the sample does.
- Check authorisation in every handler that reads or changes private data. Route middleware in the app does not protect the API ([errors and security](08-errors-and-security.md#sessions-and-authentication)).
- Limit what a client may send: validate string lengths and array sizes in the schema (`z.string().max(200)`), and let nginx cap the body size ([deployment](11-deployment-and-presets.md#nginx)).

### Calling other services

- Call a third-party API from a handler. The handler holds the key in the private `runtimeConfig`, calls the service with a timeout (`signal: AbortSignal.timeout(5_000)`), parses the response with a schema, maps it to your domain type and returns that. The page then calls your own typed route.
- Never forward the browser's `cookie` or `authorization` header to a third party. Pass the credentials that the service needs.
- Do not return the upstream response as it is. Its shape is the vendor's decision, and a field you did not mean to expose goes to the browser with it.
- Cache an expensive upstream call with a `routeRules` entry (`swr`) or Nitro's cached handlers, with a key that does not depend on the user, and never for a response that contains personal data.

### Errors

- Throw `createError({ status, statusText })` for a failure that the client may see: a missing resource, a rule that failed, a user who may not do this. `statusText` is the short reason and is public. Put structured detail in `data` only when the client needs it.
- Throw any other error as it is. Nitro logs it on the server and answers 500 with the generic body `Server Error`, and never the message of the original error. The sample threw `new Error("database password is hunter2")`, the client got `{"statusCode":500,"statusMessage":"Server Error","message":"Server Error"}`, and the log held the real message.
- Wrap an upstream failure in an error that keeps the cause, as the TypeScript notes say, and decide what the client sees: a 502 for a bad gateway, a 503 for an unavailable service. Do not forward the upstream message.
- Nuxt's error body is `{ error, url, statusCode, statusMessage, message, data }`. It is the shape that `useFetch` returns in `error`, and `isNuxtError()` recognises it. Keep it for a handler that only your own app calls. An API that other clients consume returns RFC 9457 problem details instead, as the TypeScript notes say about a new Route Handler, and that is a separate decision per API ([principles](01-principles-and-sources.md#order-of-precedence)).

### Server middleware and plugins

- A file in `server/middleware/` runs on every request, before the routes. It returns nothing, does not end the response, and only reads the request, extends `event.context`, or throws. Keep it cheap: it runs for every asset and every API call. Prefer a check inside the handler for something that only a few routes need.
- A file in `server/plugins/` runs once when the server starts: open a connection pool, register a hook. Close what it opens on shutdown.
- Do not log the body, the cookies or the `authorization` header. Log the method, the path, the status and a request id.

### Configuration in handlers

- Read private values with `useRuntimeConfig(event)`: `const { loansApiUrl } = useRuntimeConfig(event)`. A value in `runtimeConfig` outside `public` stays on the server. Set it in production with a `NUXT_` environment variable ([state and configuration](07-state-and-configuration.md#runtime-configuration)).
- Do not read `process.env` in a handler. Runtime config gives you a typed, documented key, and the TypeScript notes say that one module reads the environment.

## Sources and raw notes

Pages read on 2026-11-20:

- [`server/` directory](https://nuxt.com/docs/directory-structure/server): API and routes directories, the method suffix, middleware that returns nothing, plugins, "do not import Vue app code in server routes".
- [`shared/` directory](https://nuxt.com/docs/directory-structure/shared): why Vue and Nitro code cannot mix, `shared/types` and `shared/utils`, auto-imports in both zones.
- [Server imports (`nuxt/server`)](https://nuxt.com/docs/guide/going-further/server-imports): the portable import surface, the table of helpers, validation with any Standard Schema, `getRequestIP`, sessions, `deriveSecret`. The page is from the main branch. `node_modules/nuxt/dist/server/index.d.ts` of 4.6.4 was read for what ships: it exports `defineEventHandler` and not `defineHandler`, and has `getValidatedQuery`, `readValidatedBody`, `getRouterParam`, `setResponseStatus`, `createError`, `useSession` and `useRuntimeConfig`.
- [Server engine](https://nuxt.com/docs/guide/concepts/server-engine): Nitro, typed API routes.
- [Runtime config](https://nuxt.com/docs/guide/going-further/runtime-config): private and public keys, `NUXT_` variables.
- [TypeScript notes on errors](../typescript-conventions/09-error-handling.md) and [on runtime validation](../typescript-conventions/05-runtime-validation-and-external-data.md).
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes), against the built server (`node .output/server/index.mjs`):
  - `GET /api/loans?q=ay` answered 200 with the loan, and `GET /api/loans?q=1&q=2` answered 400 `Validation failed`.
  - `POST /api/loans` with a valid body answered 201 and a generated id. A body with `borrower: 1` answered 400 with `data.issues`. An amount of `-5` answered 422 `Amount must be positive`.
  - `GET /api/loans/99` answered 404 `Loan not found`.
  - A handler that threw `new Error("database password is hunter2")` answered 500 with the body `Server Error`, and the text appeared twice in the server log and not in the response.
  - The handlers import from `nuxt/server`, annotate the return type with `Loan`, and use `HTTP_STATUS` from `shared/utils`. `defineHandler` was a type error in 4.6.4 (`has no exported member`). `nuxt typecheck`, typed ESLint and the tests passed.
