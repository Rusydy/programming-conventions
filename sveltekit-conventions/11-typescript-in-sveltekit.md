# TypeScript in SvelteKit

## Summary

SvelteKit generates the types of every route into `./$types`. Import them and annotate `load` functions, actions, endpoints and page props with them. Declare the shapes of errors, `locals`, page data and page state in `src/app.d.ts`. Everything else follows the [Svelte](../svelte-conventions/11-typescript-in-svelte.md) and [TypeScript](../typescript-conventions/01-principles-and-sources.md) notes.

## Rules

### Generated types

- Run `svelte-kit sync` before a type check. It writes `$types` next to each route into `.svelte-kit/types`, and the `prepare` and `check` scripts run it ([setup](02-project-setup-and-tooling.md#scripts)). The `tsconfig.json` of the project merges that folder through `$app/tsconfig`.
- Import the types of a route from `./$types` with `import type`:

| File | Types |
| --- | --- |
| `+page.svelte` | `PageProps` for `data`, `form` and `params` |
| `+layout.svelte` | `LayoutProps` for `data`, `children` and `params` |
| `+page.server.ts` | `PageServerLoad`, `Actions` |
| `+page.ts` | `PageLoad` |
| `+layout.server.ts`, `+layout.ts` | `LayoutServerLoad`, `LayoutLoad` |
| `+server.ts` | `RequestHandler` |

- Annotate every `load`, every action object and every endpoint with its type, as in `export const load: PageServerLoad = ...`. The language server and `svelte-check` infer `params`, `locals` and the return value without it, but the typed ESLint rules see `any` and report four `no-unsafe-*` errors on a bare `load = ({ params, locals }) => ...`. The annotation is one line, and it pins the contract.
- Type page props with `PageProps` and `LayoutProps` (SvelteKit 2.16 and later): `let { data, form }: PageProps = $props();`. Do not write `PageData` and `ActionData` by hand, which is the older form.
- `PageProps` requires `params` as well as `data` and `form`, so a component test passes `params: {}` ([testing](09-testing-and-quality-gates.md#component-tests)).
- Let the return type of `load` be inferred. A type written by hand drifts from what the function returns, and `data` in the page already has the inferred type.
- Type an action's result by inference too. The `form` prop is the union of what the actions return, so `fail(422, { errors })` makes `form.errors` available, and reading it needs `form?.errors`.
- Use `satisfies` for a value that must match a type and keep its own, as in the TypeScript notes. Do not use `as` on route data.

### app.d.ts

- Declare the application's shared types in `src/app.d.ts`, inside `declare global { namespace App { ... } }`, and end the file with `export {}`:

```ts
// src/app.d.ts
declare global {
  namespace App {
    interface Error {
      code?: string;
    }
    interface Locals {
      user?: { id: string; name: string };
    }
    interface PageData {
      seo?: { title: string; description: string };
    }
  }
}

export {};
```

- `App.Error` is the shape of an error that reaches `+error.svelte`, and it always has `status` and `message`. `App.Locals` is the shape of `event.locals`. `App.PageData` types `page.data`, so keep it to the fields that layouts read from child pages. `App.PageState` types `page.state`, and `App.Platform` types the adapter's `platform`.
- The interface names `Error`, `Locals`, `PageData`, `PageState` and `Platform` are fixed by SvelteKit. Declare them as `interface` and not `type`, because they merge with SvelteKit's own, which the [TypeScript notes](../typescript-conventions/04-types-and-type-design.md) allow for object shapes.
- Mark a field of `Locals` optional when `handle` may not set it, as `user` above, and narrow it where it is used. `requireUser()` returns the non-optional user ([authorisation](07-hooks-errors-and-security.md#authentication-and-authorisation)).
- Do not put a function or a class instance into `PageData`, because server data must be serialisable.

### Hooks, events and helpers

- Import the hook types from `@sveltejs/kit/hooks`: `Handle`, `HandleServerError`, `HandleClientError` and `HandleFetch`. Import `RequestEvent`, `Cookies`, `Redirect` and the other shared types from `@sveltejs/kit`. In SvelteKit 3 the hook types are no longer exported from the main module.
- A `handleError` hook receives a discriminated union with `kind`, `error` and `event`. Narrow it with `kind`. The `error` of `kind: "unknown"` is `unknown`, so narrow it with `instanceof Error` before you read a property ([errors](07-hooks-errors-and-security.md#errors)).
- Use `SubmitFunction` from `$app/forms`, not from `@sveltejs/kit`, to type a `use:enhance` callback.
- Define route parameter matchers with `defineParams` from `@sveltejs/kit/params`, so that the parameter types follow from the matcher's return type ([routing](03-project-layout-and-routing.md#dynamic-routes)).
- Define environment variables with `defineEnvVars` from `@sveltejs/kit/env`. The schema's output type is the type of the value that `$app/env/private` exports, so the schema is the one source of the type ([environment variables](07-hooks-errors-and-security.md#environment-variables)).
- Get the current event in a shared server helper with `getRequestEvent()` from `$app/server` instead of passing `event` through every function. It works only while a request is being handled.

### Data across the boundary

- Everything that a server `load` returns is serialised with `devalue`, so `Date`, `Map`, `Set`, `BigInt` and promises survive, and a class instance or a function does not. Return plain data, and map a database row to the fields the page needs.
- Treat the body of every `fetch` response, every `request.json()` and every `FormData` as `unknown`, and validate it with a schema, as the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md) require. Put the schema beside the code that reads the data, and derive the type with `z.infer`.
- Register a type that has to cross the boundary through the `transport` hook in `src/hooks.ts`, with an `encode` and a `decode` function, only when you need one.
- Do not share a Zod schema between a form action and the page by importing it from a `server` folder. Put a schema that both need in `src/lib/`, and keep server-only schemas in `src/lib/server/`.

### Tsconfig and tools

- Follow the tsconfig of the [setup note](02-project-setup-and-tooling.md#tsconfig): `$app/tsconfig` plus the six options of the TypeScript notes, with `allowJs` and `checkJs` off.
- Use `svelte-check` as the type checker. `tsc` cannot read `.svelte` files, and `svelte-check` reads the `.ts` files in the same run.
- Keep the Svelte rules for `.svelte` files: `lang="ts"`, local `Props`, `Snippet` and `Component` types, and no `any` ([TypeScript in Svelte](../svelte-conventions/11-typescript-in-svelte.md)).

## Sources and raw notes

Pages read on 2026-11-18:

- [Routing](https://svelte.dev/docs/kit/routing): `./$types`, `PageProps` and `LayoutProps` since 2.16, `PageLoad`, `PageServerLoad`, `LayoutLoad`, `LayoutServerLoad`, and that the types can be omitted in an editor with language-server support. [Hooks](https://svelte.dev/docs/kit/hooks): the types from `@sveltejs/kit/hooks`, `App` augmentation in `src/app.d.ts`. [Errors](https://svelte.dev/docs/kit/errors): `App.Error` always has `status` and `message`. [State management](https://svelte.dev/docs/kit/state-management): `App.PageData`. [Loading data](https://svelte.dev/docs/kit/load): serialisation with `devalue`.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): `$app/tsconfig`, the hook types moved to `@sveltejs/kit/hooks`, `defineParams` in `@sveltejs/kit/params`, `defineEnvVars` in `@sveltejs/kit/env`.
- `@sveltejs/kit` 3.3.1 types: `HandleServerError` input of `kind`, `error` and `event`, `SubmitFunction` exported from `$app/forms`, `getRequestEvent` from `$app/server`, `CaughtError`.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): all route files, `src/app.d.ts`, `src/hooks.server.ts`, `src/env.ts`, `src/params.ts` and the `requireUser()` helper passed `svelte-check` with `--fail-on-warnings`, ESLint and Prettier. A `load` without the `PageServerLoad` annotation was typed by `svelte-check` (it reported `params.id` as missing from `RouteParams`) and gave four `no-unsafe-*` errors in ESLint. A `handleError` typed with `status` in its input failed `svelte-check`. A test that rendered a page without `params` failed `svelte-check`. Importing `DATABASE_URL` from `$app/env/private` gave the type `string` from the `z.url()` schema, and assigning it to a `number` failed `svelte-check`.
- The `transport` hook, the `App.PageState` and `App.Platform` interfaces, and the schema-sharing advice come from the documentation and the TypeScript notes, and the sample application did not exercise them.
