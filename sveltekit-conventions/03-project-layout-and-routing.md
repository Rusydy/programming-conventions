# SvelteKit Project Layout and Routing

## Summary

Routes are folders under `src/routes`, and each route is made of `+`-prefixed files. Put code that more than one route uses in `src/lib` and import it through `#lib`. Put server-only code in a `server` folder, where SvelteKit stops the browser from importing it. Keep one `+page.server.ts` per page for its data and actions, and give a dynamic segment a matcher.

## Rules

### Layout

- `src/` holds the application, and `static/` holds files that are served as they are, such as `robots.txt` and fonts. Import images and other assets instead of putting them in `static/`, so that Vite hashes them for caching.
- The folders and files below are the whole standard shape. Add nothing to the root of `src/` that this list does not name:

```text
src/
  app.d.ts            # App.Error, App.Locals, App.PageData, App.PageState
  app.html            # the page template
  error.html          # the last-resort error page
  env.ts              # environment variables (defineEnvVars)
  hooks.server.ts     # handle, handleError, handleFetch
  hooks.client.ts     # client handleError
  hooks.ts            # reroute, transport
  params.ts           # route parameter matchers
  lib/
    <feature>/        # shared code, grouped by feature
    server/           # server-only code
  routes/
    +layout.svelte
    +error.svelte
    <route>/...
e2e/                  # Playwright tests
static/
```

- Group shared code by feature in `src/lib/<feature>/`, as the [Svelte notes](../svelte-conventions/03-project-layout-and-naming.md#where-code-lives) say. Put a component that only one route uses in that route's folder.
- Put code that must run only on the server in `src/lib/server/` (`src/lib/server/loans.ts`). SvelteKit treats any folder named `server`, at any depth outside `src/routes` and `static`, as server-only, and so any file with a `server` segment in its name, such as `loans.server.ts`. Use the folder, because it keeps the name of the module free of the marker.
- A server-only module can be imported into other server code, and into a `.svelte` file only as a type. If client code imports one, directly or through a chain, the build stops with `server_only_import`, even when the client uses only a harmless export.
- Do not add an `index.ts` barrel. `#lib` points at `src/lib/index.ts`, which the template leaves empty, so leave it empty or delete the entry. Import from the file that defines the name.
- Put a test next to the file it tests, and name it so that it does not start with `+`. SvelteKit ignores other files in a route folder, so `page.browser.test.ts` sits beside `+page.svelte` ([testing](09-testing-and-quality-gates.md#where-tests-live)).

### Naming

- Name a folder and a file in kebab-case, as the [TypeScript notes](../typescript-conventions/07-naming-comments-and-style.md#naming) say: `src/routes/loan-requests/`, `loan-summary.svelte`. The `+page`, `+layout`, `+server` and `+error` files are the exception, because the framework names them.
- Name a route parameter in lowerCamelCase and make it say what it holds: `[loanId]`, not `[id]` when a page has two ids. A route folder with a matcher is `[loanId=uuid]`.
- Name a URL segment as a noun in the plural for a collection (`/loans`) and the singular for one item (`/loans/[loanId]`). Do not put a verb in a path, except under `/api`.
- Name a route group `(app)` or `(marketing)` after the audience or the layout it shares, not after its content.
- Export names that the framework reads are fixed: `load`, `actions`, `GET`, `POST`, `prerender`, `ssr`, `csr`, `trailingSlash`, `entries`, `handle`, `handleError`, `reroute` and `transport`. Write them as `export const`. A `.svelte` file is the only default export in a SvelteKit project, besides `vite.config.ts`.

### Imports

- Import a file in your own project with the file extension. `#lib/*` is a Node.js subpath import, which Vite resolves from `package.json`, and it needs the exact file name, so write `#lib/server/loans.ts`, `#lib/loan.ts` and `#lib/loans/loan-list.svelte.ts`. `$app/tsconfig` turns on `allowImportingTsExtensions`, so the `.ts` extension type-checks.
- Write relative imports the same way (`./loan-row.svelte`, `./loan-list.svelte.ts`). A relative import without the extension also works in the sample project, and this set picks one form so that the two kinds look alike.
- Use `import type` for types, as `verbatimModuleSyntax` requires. Import generated types as `import type { PageProps } from "./$types"`, with no extension.
- Use `#lib` for anything outside the route folder, and `./` or `../` for the same folder or one level up. Never write `../../..`, as the [TypeScript notes](../typescript-conventions/06-modules-and-imports.md#import-paths) say.
- Do not use `$lib`. SvelteKit 3 removed it. Do not use the `alias` option, which is deprecated.
- Let the editor organise the imports, and do not sort them by hand.

### Route files

| File | Job |
| --- | --- |
| `+page.svelte` | The page. It receives `data`, `form` and `params` as props. |
| `+page.server.ts` | Server `load` and form `actions`. The default home of a page's data. |
| `+page.ts` | Universal `load`, for a public API or a non-serialisable value ([load](04-load-and-data-fetching.md#server-or-universal)). |
| `+layout.svelte` | Markup shared by the routes below it. It must render `{@render children()}`. |
| `+layout.server.ts`, `+layout.ts` | Data that every route below the layout needs. |
| `+error.svelte` | The page for an error in a `load` function or a component below it. |
| `+server.ts` | A JSON or file endpoint, with one function per HTTP method. |

- Write `+page.server.ts` for a page's data and mutations, and add `+page.ts` only for a reason. Both files in one folder run in a fixed order and the universal one decides the page data ([load](04-load-and-data-fetching.md#server-or-universal)).
- Type the props of `+page.svelte` and `+layout.svelte` with `PageProps` and `LayoutProps`: `let { data, form }: PageProps = $props()`. `PageProps` includes `params` too, which a test must pass.
- Keep a layout thin: shared chrome, navigation and the data that every child needs. A layout whose `load` is slow slows every page below it, and its data cannot protect those pages ([authorisation](07-hooks-errors-and-security.md#authentication-and-authorisation)).
- Put one `+error.svelte` in `src/routes`, and add more only where a section needs its own error page. An error in a root layout's `load` cannot use that page, so keep the root layout's `load` free of work that can fail.
- Write a `+server.ts` for a JSON API, a webhook, a file download or an endpoint that a non-browser client calls. `GET` must have no side effects. Return `Response.json(value)`. Do not use the `json()` helper of `@sveltejs/kit`, which is deprecated. A `HEAD` request uses the `GET` handler.
- Do not put a `+page` and a `+server` with the same `GET` in one folder to serve both HTML and JSON, because the `accept` header decides which one answers and the result confuses callers. Give the endpoint its own path under `/api`.

### Dynamic routes

- Use a matcher for every dynamic segment that has a known shape. A matcher lives in `src/params.ts`, and returns the value when it is valid and `undefined` when it is not. A request that fails the matcher gets a 404 and never reaches `load`:

```ts
// src/params.ts
import { defineParams } from "@sveltejs/kit/params";

export const params = defineParams({
  uuid: (value) =>
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value)
      ? value
      : undefined,
});
```

- Apply it in the folder name: `src/routes/items/[id=uuid]/`. A matcher can also be a Standard Schema validator, such as a Zod schema, whose output extends `string`, `boolean`, `number` or `bigint`.
- A matcher runs on the server and in the browser, so it must not use a server-only module.
- Keep a matcher's transformation symmetrical, so that `resolve()` can build the path back.
- Avoid `[...rest]` and `[[optional]]` unless the URL design needs them. `[...rest]` also matches zero segments, so validate it. A catch-all `[...path]` that calls `error(404)` is the way to render a nested not-found page.
- Use a route group in parentheses to give a set of routes a layout without a URL segment. Use `+page@` to reset to the root layout only when a page truly needs none of the layouts above it.
- Build every internal link with `resolve()` ([state and navigation](06-state-and-navigation.md#navigation)).

## Sources and raw notes

Pages read on 2026-11-18:

- [Project structure](https://svelte.dev/docs/kit/project-structure): `src`, `static`, `app.html`, `error.html`, the hooks files, `params`, `instrumentation.server`, `.svelte-kit`, `#lib`, and the rule that any `server` folder is server-only.
- [Server-only modules](https://svelte.dev/docs/kit/server-only-modules): a `server` segment in a file name, a `server` folder anywhere except `src/routes` and `static`, the error for a client import, dynamic imports, and the exemption when `process.env.TEST` is `true`.
- [Routing](https://svelte.dev/docs/kit/routing): the route files, `+layout` rules, `+error` resolution, `+server` handlers, `HEAD`, content negotiation, `PageProps` and `LayoutProps`. [Advanced routing](https://svelte.dev/docs/kit/advanced-routing): rest and optional parameters, matchers in `src/params.ts` with `defineParams`, sorting, groups, the `@` layout reset.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): `$lib` removed in favour of `#lib` with file extensions, `src/params.ts` replacing the `src/params` folder, the server-only rules, `json()` deprecated.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): imports of `#lib/loan.ts`, `#lib/server/loans.ts` and `#lib/items/item-badge.svelte` passed `svelte-check`, ESLint and `vite build`. Both `./item-state.svelte.ts` and `./item-state.svelte` passed. A `.svelte` page that imported `#lib/server/loans.ts` stopped `vite build` with `server_only_import`. The `uuid` matcher above gave 404 for `/items/abc` and 200 for a UUID on the built Node.js server.
- The advice to avoid `[...rest]` and `[[optional]]`, and to keep a `+server` and a `+page` apart, is this set's own judgement. The documentation describes both features and the content negotiation without recommending against them.
