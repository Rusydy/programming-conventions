# SvelteKit Hooks, Errors and Security

## Summary

Hooks run for every request: `handle` identifies the user and fills `event.locals`, and `handleError` logs unexpected errors and hides their details. Authorise where the data is read or written, not in a layout. Declare environment variables with `defineEnvVars` so that a missing one stops the build or the start. Leave CSRF protection on, and set a content security policy.

## Rules

### Hooks

- Put server hooks in `src/hooks.server.ts`, client hooks in `src/hooks.client.ts` and the hooks that run on both sides in `src/hooks.ts`. Type them with `Handle`, `HandleServerError`, `HandleFetch` and the other types from `@sveltejs/kit/hooks`. SvelteKit 3 moved the hook types there from `@sveltejs/kit`.
- Keep `handle` short. It identifies the request and calls `resolve`. Combine several handlers with `sequence` from `@sveltejs/kit/hooks`, one per concern: sessions, logging, headers.
- Put the data that later code needs on `event.locals`, and declare it in `App.Locals` in `src/app.d.ts`. `locals` reaches `+server.ts` files, server `load` functions and actions.
- `handle` runs for every dynamic request, including during prerendering, and it does not run for static assets or prerendered pages.
- `resolve` does not throw. Keep the code around it from throwing, because an error in `handle` is fatal for the request.
- In a request that comes from a remote function, `event.route`, `event.params` and `event.url` describe the page that called it, so do not use them for an authorisation decision there.
- Use `handleFetch` only to change what the server-side `fetch` sends: to add a header, to point a public URL at an internal one, or to forward a cookie to a sibling subdomain, which the default does not do.
- Use the `init` hook for one-time start-up work, such as opening a connection. In the browser, async work in `init` delays hydration.
- Use `reroute` and `transport` only for a real need: a translated URL scheme, or a custom class that must cross the server and client boundary. `reroute` must be fast, pure and idempotent, because the client caches it.
- Do not write `hooks.client.ts` until you need to report client errors ([errors](#errors)).

```ts
// src/hooks.server.ts
import type { Handle } from "@sveltejs/kit/hooks";

export const handle: Handle = async ({ event, resolve }) => {
  const session = event.cookies.get("session");
  if (session) event.locals.user = await findUserBySession(session);
  return resolve(event);
};
```

### Authentication and authorisation

- Authenticate in `handle`: read the session cookie, look the session up, and set `event.locals.user` when it is valid. A database session can be revoked at once, and costs a query per request. A signed token such as a JWT needs no query and cannot be revoked until it expires. Choose the database session unless latency forces the other.
- Authorise in each place that reads private data or changes data: every server `load`, every action and every `+server.ts` handler. Put the check in one helper that calls `getRequestEvent()` from `$app/server`, so that it reads `locals.user` and redirects or throws when there is none:

```ts
// src/lib/server/auth.ts
import { redirect } from "@sveltejs/kit";
import { getRequestEvent } from "$app/server";

export function requireUser() {
  const { locals } = getRequestEvent();
  if (!locals.user) redirect(303, "/login");
  return locals.user;
}
```

- A layout's `load` does not protect the pages below it. All load functions of a page run at the same time, so a page's `load` can run, and return data, before or without the layout's check finishing. Check in the page's own `load` and in its actions.
- Put a coarse guard in `handle` for whole sections, such as everything under `/admin`. Match on `event.route.id`, not on `event.url.pathname`, because a pathname can be encoded and a `startsWith("/admin")` test can be bypassed. This guard cannot protect prerendered pages or static assets, because `handle` does not run for them. Never prerender a page that holds private data.
- Return the user's id and the few fields that a page shows. Do not return the whole user row from a `load`.
- Set cookies with `cookies.set` in `handle` or an action, with `httpOnly`, `secure` and `sameSite: "lax"` for a session, and a `maxAge`. SvelteKit 3 uses `cookie` v2, so a cookie name must be ASCII, and the default `path` is `/`.
- Do not write a password or session system by hand when a library will do. `npx sv add better-auth` sets one up, and the documentation points to Lucia-style guides for a custom one. Hash passwords with a slow hash, never log them, and rate-limit the login action at the proxy ([abuse control](../infra-conventions/07-abuse-control-and-edge-protection.md)).

### Errors

- Separate expected from unexpected errors, as the documentation does. Call `error(status, message)` for an expected one, such as a missing record or a refused request. The user sees the message, so write it for the user. Everything else is unexpected: the user sees a generic message, and the details stay on the server.
- Implement `handleError` in `src/hooks.server.ts`. It receives `{ kind, error, event }`, where `kind` is `"app"` for an `error()` call, `"framework"` for SvelteKit's own errors such as a 404, `"validation"` for invalid remote-function input and `"unknown"` for the rest. Log an unknown error once, with its `cause` chain, and return a safe `App.Error`. It must never throw:

```ts
import type { HandleServerError } from "@sveltejs/kit/hooks";

export const handleError: HandleServerError = ({ kind, error, event }) => {
  if (kind !== "unknown") return;
  console.error(`Unhandled error on ${event.url.pathname}`, error);
  return { message: "Something went wrong" };
};
```

- Do not log `framework` errors, such as every 404: they are routine. Do not return the message of an unknown error, a stack or a query. Return a status in the result only when you need a different one.
- `App.Error` always has `status` and `message`. Add fields in `src/app.d.ts`, and give an `error()` call the extra properties as its third argument: `error(409, "Loan already paid", { code: "LOAN_PAID" })`. The second argument must be a string in SvelteKit 3.
- Render an error with `+error.svelte`, reading `page.status` and `page.error` from `$app/state`. Write a generic message for status 500, and show `page.error.message` only for expected errors. Keep a `src/error.html` for the case where nothing else can render.
- Use `<svelte:boundary>` with a `failed` snippet for a part of a page that can fail on its own ([Svelte errors](../svelte-conventions/09-errors-and-async.md#error-boundaries)).
- Catch errors in an action or an endpoint only to turn them into a `fail()` result or a status. Do not catch an `error()` or a `redirect()` call, and rethrow them with `isHttpError` and `isRedirect` if you must.
- Follow the [TypeScript error rules](../typescript-conventions/09-error-handling.md): throw `Error` objects with a `cause`, and log at the boundary.

### Environment variables

- Declare every variable in `src/env.ts` with `defineEnvVars` and a schema. The application stops at build or at start when a variable is missing or invalid, with a message that names it:

```ts
// src/env.ts
import { defineEnvVars } from "@sveltejs/kit/env";
import { z } from "zod";

export const variables = defineEnvVars({
  DATABASE_URL: { schema: z.url() },
  PUBLIC_APP_NAME: { public: true, schema: z.string().min(1) },
});
```

- Import a private variable from `$app/env/private` and a public one from `$app/env/public`. A variable is private unless it sets `public: true`, and `$app/env/private` is a server-only module that the browser cannot import. Prefix the name of every public variable with `PUBLIC_`, so a reader sees at a glance what the browser can read.
- Use a Zod schema, which is a Standard Schema, for every variable, as the TypeScript notes require for data from outside. A function that returns the value or throws also works. Transform a number or a list in the schema, not at the use site.
- Leave a variable dynamic, read when the app starts, unless it must be a build-time constant. `static: true` inlines the value into the bundle, which enables dead-code elimination for a feature flag and means the value is fixed at build time.
- Do not use `$env/static/*`, `$env/dynamic/*` or `$app/environment`. SvelteKit 3 deprecates them for removal in SvelteKit 4. Use `$app/env` for `dev`, `building`, `browser` and `version`.
- Do not read `process.env` anywhere. This replaces the `lib/env.ts` module of the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md#environment-variables), because the framework now does the parsing.
- Keep a `.env.example` with every name and no secret. `.env` files are loaded in development and at build time only. In production the process needs the variables in its environment, for example `node --env-file=.env build` or the variables of the service manager ([secrets and configuration](../infra-conventions/08-secrets-and-configuration.md)). Never commit `.env`.
- The build needs the build-time values. Give the CI job the variables that `vite build` validates, as fake values where a real one is not needed, and set a variable that only exists at run time to be optional while `building` from `$app/env` is true.

### CSRF

- CSRF protection is always on in SvelteKit 3, and the `csrf.checkOrigin` option no longer exists. It rejects a cross-origin form `POST`, `PUT`, `PATCH` or `DELETE`, and a mutating request that has no `Content-Type` header.
- Allow another origin only by listing it in `csrf.trustedOrigins`. Never use `*`.
- Behind a reverse proxy the server must know its public origin, or a form `POST` fails with `Cross-site POST form submissions are forbidden`. Set `ORIGIN` for `adapter-node`, or the protocol and host headers from a trusted proxy ([deployment](10-deployment-and-adapters.md#running-behind-nginx)).
- Do not switch off CSRF protection to fix a proxy. Fix the origin.

### Content security policy

- Set `csp` in the SvelteKit options. Use `mode: "auto"`, which gives dynamic pages a nonce and prerendered pages hashes, and start with `default-src: ["self"]` and a `script-src` that SvelteKit extends with its nonces. Run with `reportOnly` first and watch the reports before enforcing.
- Add the origins of fonts, images, analytics and the API in the directives, and no `unsafe-inline` for scripts.
- Do not use `{@html}` with content you did not sanitise. A policy limits the damage but does not replace escaping ([Svelte templates](../svelte-conventions/08-templates-styling-and-accessibility.md#templates)).
- Set the other headers (`Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`) at nginx, as the [infrastructure notes](../infra-conventions/06-nginx-reverse-proxy.md) say, and not in `handle`, unless the app runs without a proxy.

## Sources and raw notes

Pages read on 2026-11-18:

- [Hooks](https://svelte.dev/docs/kit/hooks): `handle` and `resolve`, `locals`, `handleFetch`, `handleError` and its `kind` values, `init`, `reroute`, `transport`, and the types from `@sveltejs/kit/hooks`. [Authentication](https://svelte.dev/docs/kit/auth): sessions and tokens, `handle` and `locals`, `getRequestEvent`, the `event.route.id` rule, prerendered pages skipping `handle`, `better-auth`.
- [Errors](https://svelte.dev/docs/kit/errors): expected and unexpected errors, `error()`, `handleError`, `+error.svelte` resolution, `src/error.html`, `App.Error`. [Loading data](https://svelte.dev/docs/kit/load): the parallel run of all load functions on a page.
- [Environment variables](https://svelte.dev/docs/kit/environment-variables): `src/env.ts`, `defineEnvVars`, private and public, Standard Schema or a function, static and dynamic, the `building` flag, the deprecation of `$env/*` and `$app/environment`. [`$app/env`](https://svelte.dev/docs/kit/$app-env): `browser`, `building`, `dev`, `version`. [Server-only modules](https://svelte.dev/docs/kit/server-only-modules): `$app/env/private` and `$app/server` are server-only.
- [Configuration](https://svelte.dev/docs/kit/configuration): `csp` modes and `reportOnly`, `csrf.trustedOrigins`. [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): CSRF always on, rejecting mutating requests without a `Content-Type`, cookie v2, hook types moved to `@sveltejs/kit/hooks`, the `error()` signature, `handleError` receives every error, `handleValidationError` removed.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `hooks.server.ts` with `handle` and `handleError`, `src/env.ts` with a private and a public variable, `app.d.ts` with `Locals` and `Error`, and the `requireUser` helper with `getRequestEvent` passed `svelte-check`, ESLint and Prettier. Typing `handleError` as `({ error, event, status })` failed `svelte-check`, because the input has `kind`, `error` and `event` and no `status`. The built server, started without `.env`, stopped with `SvelteKit error: env_invalid` and named `DATABASE_URL`, and ran with `node --env-file=.env build`. A `POST` without an `Origin` header and one from `http://evil.example` got 403. A request without a session cookie for a page that calls `redirect(303, "/login")` got `303`.
- The cookie attributes, the choice of database sessions, the CSP starting point and the proxy header advice come from the documentation, the infrastructure notes and general practice. The sample application did not set a cookie or a `csp`, so those examples were not run. The `handle` example calls `findUserBySession`, a function that you write, and the sample application's hook reads the cookie directly, so that example shows a shape and was not run. `requireUser` ran in the sample application, called from a server `load` and from an action.
