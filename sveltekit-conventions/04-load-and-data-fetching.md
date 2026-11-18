# SvelteKit Load and Data Fetching

## Summary

Load a page's data in `+page.server.ts` and type the function with the generated `PageServerLoad`. Use a universal `+page.ts` only for a public API call or a value that cannot cross the network as data. Give `load` no side effects, stream slow and non-essential data as a promise, and rerun a function with `depends` and `invalidate`, not with a reload.

## Rules

### Server or universal

- Write a server `load` in `+page.server.ts` or `+layout.server.ts` by default. It always runs on the server, so it can use a database, the file system and private environment variables, and it receives `cookies`, `locals`, `request` and `getClientAddress`.
- Write a universal `load` in `+page.ts` or `+layout.ts` when the page calls an external API that needs no private credential, or when it returns a value that is not serialisable, such as a component constructor. It runs on the server for the first request and in the browser afterwards, and it can return any value.
- A server `load` must return data that `devalue` can serialise: JSON values, `Date`, `Map`, `Set`, `BigInt` and promises. A class instance does not qualify.
- When a route has both files, the server `load` runs first and its result arrives as the `data` argument of the universal `load`. The universal function's return value becomes the page's data, so it must return the server data too, or the page loses it. In the sample application a `+page.svelte` that read `data.summary` failed `svelte-check` when a universal `load` sat beside the server one and returned only its own fields. Avoid having both unless the route needs both.
- A layout's load data merges with its pages' data, and a page wins when a key appears in both.
- Write `load` as an `export const load: PageServerLoad = async (event) => { ... }`, with the type from `./$types` ([TypeScript in SvelteKit](11-typescript-in-sveltekit.md#generated-types)).
- Return only what the page uses. A server `load` that returns a whole database row sends every column to the browser.

```ts
// src/routes/loans/[loanId=uuid]/+page.server.ts
import { error } from "@sveltejs/kit";

import { findLoan } from "#lib/server/loans.ts";

import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = ({ params }) => {
  const loan = findLoan(params.loanId);
  if (!loan) error(404, "Loan not found");
  return { loan };
};
```

### Fetching

- Use the `fetch` that `load` receives, not the global one. On the server it passes the cookies and the `authorization` header of the page request to the app's own host, accepts relative URLs, and calls a `+server` handler directly without an HTTP round trip. During server rendering, SvelteKit inlines the response in the HTML and reuses it on hydration, so the browser does not ask again.
- Treat the body of a response as `unknown` and validate it with a schema, as the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md) require. Give the request a timeout:

```ts
// src/routes/feed/+page.ts
import { z } from "zod";

import type { PageLoad } from "./$types";

const loansSchema = z.array(z.object({ id: z.string(), borrower: z.string() }));

export const load: PageLoad = async ({ fetch, depends }) => {
  depends("app:loans");
  const response = await fetch("/api/loans", { signal: AbortSignal.timeout(5_000) });
  const raw: unknown = await response.json();
  return { loans: loansSchema.parse(raw) };
};
```

- Cookies go through `fetch` only to the app's own host or a subdomain. Another host needs the `handleFetch` hook ([hooks](07-hooks-errors-and-security.md#hooks)).
- Do not write to a store, a module variable or a global in `load`. A load function must be free of side effects: return the data, and pass it on through props or `page.data` ([state on the server](06-state-and-navigation.md#state-on-the-server)).
- Set a cache header with `setHeaders` only on the server. It has no effect in the browser, setting one header twice is an error, and `set-cookie` goes through `cookies.set`.
- Read the search parameters from `url.searchParams` in `load`, and keep state that must survive a reload in the URL ([state and navigation](06-state-and-navigation.md#state-in-the-url)). Reading `url.searchParams` makes a page unprerenderable, and `url.hash` is not available in `load`.

### Parallel loading and parent data

- Every load function of a page runs at the same time. Do not write a chain of `await`s for requests that do not depend on each other. Start them together with `Promise.all`, as the [TypeScript notes](../typescript-conventions/08-functions-classes-and-async.md#async-code) say.
- Call `await parent()` only when the function needs the parent's data, and call it after the independent work, so it does not start a waterfall.
- Do not use `parent()` to read the user. Read `locals.user` ([authorisation](07-hooks-errors-and-security.md#authentication-and-authorisation)).
- Do not put the same query in a layout and in its page. Load it once, in the layout, and read it from `page.data` or from the `data` prop.

### Streaming

- Return a promise from a server `load` for data that is slow and not essential, and render it with an `{#await}` block. The fast data arrives with the page, and the rest streams in:

```ts
export const load: PageServerLoad = ({ locals }) => {
  const summary = fetchSummary(locals.user);
  return { summary };
};
```

```svelte
{#await data.summary}
  <p>Loading…</p>
{:then summary}
  <p>{summary}</p>
{:catch}
  <p>Could not load the summary.</p>
{/await}
```

- Streaming works only in server loads, not in universal ones. After streaming starts, the status and headers are fixed, so a redirect or `setHeaders` inside a streamed promise does nothing. Some platforms, such as AWS Lambda, buffer the response and stream nothing.
- Attach a no-op `catch` to a promise that does not come from SvelteKit's `fetch`, so that a rejection before the page reads it is not an unhandled one.
- Always write the `{:catch}` branch. Do not show the error's message in it ([errors](07-hooks-errors-and-security.md#errors)).
- Do not stream data that search engines or the first paint need. Await it.

### Errors and redirects

- Call `error(status, message)` to stop a load with an expected failure, such as a missing record, and `redirect(status, location)` to send the user elsewhere. Neither returns, so do not write `return error(...)`.
- Do not call either inside a `try` block, because the `catch` would intercept them. If you must catch around such a call, rethrow with `isHttpError` or `isRedirect` from `@sveltejs/kit`.
- Use `303` for a redirect after a form `POST`, and `301` or `308` only for a permanent move.
- Do not return a value that means "not found". Throw the error, so that the nearest `+error.svelte` renders it.

### Rerunning

- A load function reruns when a parameter, a URL property or the parent data that it read changes, and when something invalidates it. It does not rerun when the user navigates to the same route with the same inputs.
- Name a dependency with `depends("app:loans")`, and rerun the functions that declared it with `invalidate("app:loans")`. Use `invalidate` with a custom identifier or a URL that `fetch` requested. Call `refreshAll()` to rerun everything without resetting `page.state`.
- Do not call `invalidateAll`, which SvelteKit 3 deprecates in favour of `refreshAll`.
- Use `untrack` from the load event when a function reads a value but must not rerun on its change.
- A form action reruns the page's load functions after it succeeds, so a form needs no manual invalidation ([forms](05-forms-and-mutations.md)).

## Sources and raw notes

Pages read on 2026-11-18:

- [Loading data](https://svelte.dev/docs/kit/load): universal and server load, the return values and `devalue`, the order when both exist, the `fetch` rules for cookies and relative URLs, `setHeaders`, `parent()`, errors and redirects, streaming and its limits, parallel loading. The page text was cut before the sections on rerunning and `getRequestEvent`, which the notes take from the migration guide and the type definitions.
- [Authentication](https://svelte.dev/docs/kit/auth): reading `locals.user` through `getRequestEvent`. [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): `invalidateAll` deprecated for `refreshAll`, which does not reset `page.state`, and `invalidate` no longer aborts in-flight navigations. [Page options](https://svelte.dev/docs/kit/page-options): `url.searchParams` is forbidden while prerendering.
- `@sveltejs/kit` 3.3.1 types: `refreshAll`, `invalidate`, `isHttpError`, `isRedirect`, `error`, `redirect`.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the `loans/[id]` server load, the universal `feed/+page.ts` with a Zod schema and `depends`, and the streamed `summary` with an `{#await}` block passed `svelte-check` with `--fail-on-warnings`, ESLint and Prettier. Without the `PageServerLoad` annotation, `svelte-check` still inferred `params` and `locals`, and it reported a `params.id` that the route did not have, but ESLint reported four `no-unsafe-*` errors on the same file.
- The built Node.js server redirected an unauthenticated request for `/loans` with 303 to `/login`, and answered 404 for a missing loan.
