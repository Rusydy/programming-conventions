---
paths:
  - "**/src/routes/**"
  - "src/routes/**"
  - "**/src/hooks.server.ts"
  - "src/hooks.server.ts"
  - "**/src/hooks.client.ts"
  - "src/hooks.client.ts"
  - "**/src/hooks.ts"
  - "src/hooks.ts"
  - "**/src/app.d.ts"
  - "src/app.d.ts"
  - "**/src/app.html"
  - "src/app.html"
  - "**/src/env.ts"
  - "src/env.ts"
  - "**/src/params.ts"
  - "src/params.ts"
  - "**/src/lib/server/**"
  - "src/lib/server/**"
---
# SvelteKit conventions (SvelteKit 3)

Write idiomatic SvelteKit 3. Follow the framework's documented behaviour, the generated `$types` and `svelte-check` instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `sveltekit-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. It loads next to `svelte.md` and `typescript.md`, and replaces neither. The digest was synced with the notes on 2026-11-18; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatting, autofixes, dependency bumps, migrations) in their own commits.
- When sources disagree, the order is: the documented behaviour of SvelteKit, Svelte and Vite; this file and the notes; `svelte.md`; `typescript.md`; `svelte-check` and the lint presets; the infrastructure notes for the server and proxy.
- SvelteKit's required shape overrides the other rules: `+`-prefixed route files, framework export names (`load`, `actions`, `GET`, `prerender`, `handle`), `#lib` instead of `@/`, and `src/env.ts` instead of a `lib/env.ts` that parses `process.env`.
- Generated files are exempt: `.svelte-kit/`, the `$types` files and `build/`. A plain Vite app, such as a Wails frontend, uses `svelte.md` alone.
- SvelteKit 3 renamed or removed many APIs of SvelteKit 2. Read the installed version (`node -p "require('@sveltejs/kit/package.json').version"`) and look the API up in the documentation of that major version. Training data about SvelteKit 2 is often wrong.
- Before you report changes as done, run `npm run check`, `npm run lint` and `npm test`.

## Setup

- Create with `npx sv create <name> --template minimal --types ts`. SvelteKit 3 needs Node.js 22.17 or later, TypeScript 6, Svelte 5.57.1 or later and Vite 8.0.12 or later. There is no `svelte.config.js`: pass every option to `sveltekit({ ... })` in `vite.config.ts` and keep the template's `compilerOptions.runes` function. Use `defineConfig` from `vitest/config` once tests exist.
- Choose the adapter on day one: `@sveltejs/adapter-node` for a server you run (the default of this set), `adapter-static` for a fully prerendered site. Replace `adapter-auto`. Do not turn on any `experimental` option.
- `package.json` has `"imports": { "#lib": "./src/lib/index.ts", "#lib/*": "./src/lib/*" }`. tsconfig: `"extends": "$app/tsconfig"`, `strict`, `"types": ["$app/types", "node"]`, `allowJs` and `checkJs` off, and the options of the TypeScript notes (`noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns`, `noFallthroughCasesInSwitch`, `erasableSyntaxOnly`). No `paths` and no `baseUrl`.
- Scripts: `check` is `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --fail-on-warnings`, then `lint` (`eslint`), `format:check` (`prettier --check .`), `test` (`vitest run`), `test:e2e` (`playwright test`), and `ci` runs check, lint, format:check, test and build.
- ESLint: the typed config of `svelte.md` (typescript-eslint `recommendedTypeChecked` and `stylisticTypeChecked`, `projectService`, `extraFileExtensions`, `no-non-null-assertion`, `svelte.configs.recommended`, Prettier last), plus `includeIgnoreFile(.gitignore)` and `globals.browser` and `globals.node`. No `svelteConfig` entry. Prettier: the `.prettierrc` of `svelte.md` with the plugin and no style option; delete the `prettier.config.js` that `sv add prettier` writes. Compare every `sv add` output with these rules before keeping it.

## Layout, naming and imports

- `src/` holds `app.d.ts`, `app.html`, `error.html`, `env.ts`, `hooks.server.ts`, `hooks.client.ts`, `hooks.ts`, `params.ts`, `lib/<feature>/`, `lib/server/` and `routes/`. Shared code is grouped by feature in `src/lib/<feature>/`. A component for one route stays in that route's folder. No barrels.
- Server-only code goes in `src/lib/server/` (any `server` folder outside `src/routes` and `static`, or a file with a `server` segment). A client import of it, direct or indirect, fails the build with `server_only_import`.
- Folders and files are kebab-case, route parameters lowerCamelCase (`[loanId]`), `+` files fixed. A test file never starts with `+`: `page.browser.test.ts` sits beside `+page.svelte`.
- Import your own files with the extension: `#lib/server/loans.ts`, `#lib/loans/loan-list.svelte.ts`, `./loan-row.svelte`. `import type` for types, `./$types` without extension. No `$lib` (removed), no `alias`. Never `../../..`.
- `+page.server.ts` is the default home of a page's data and actions. Add `+page.ts` only for a public API call or a non-serialisable value. `+layout.svelte` renders `{@render children()}` and stays thin. One `+error.svelte` in `src/routes`. `+server.ts` is for JSON APIs, webhooks and files; return `Response.json(...)`, never the deprecated `json()`. Do not put a page and an endpoint with the same `GET` in one folder.
- Give every dynamic segment a matcher in `src/params.ts` with `defineParams` (`[id=uuid]`); a failing matcher gives 404 before `load`. Avoid `[...rest]` and `[[optional]]` without a need. Route groups `(app)` need a reason.

## Load

- Annotate every load with its generated type: `export const load: PageServerLoad = ...` (typed lint sees `any` otherwise). Page props are `PageProps` and `LayoutProps` (`data`, `form`, `params`, `children`); a test must pass `params: {}`.
- Server `load` for databases, files and private env. Return only what the page uses, as serialisable data (`devalue`: `Date`, `Map`, `Set`, `BigInt`, promises). With both `+page.server.ts` and `+page.ts`, the universal return value replaces the page data, so it must return the server data too; avoid having both.
- Use the `fetch` that `load` receives. Treat `response.json()` as `unknown` and validate with Zod; give it `AbortSignal.timeout`. No side effects in `load`: no writes to stores or module variables.
- Load functions run in parallel: no await chains for independent requests, `await parent()` only when needed and late, never read the user from `parent()`.
- Stream slow, non-essential data as a promise from a server `load` with `{#await}` and a `{:catch}` branch; do not stream what the first paint or SEO needs.
- `error(status, message)` and `redirect(303, location)` never return and must not sit inside `try`; rethrow with `isHttpError` and `isRedirect`. Rerun with `depends("app:x")` and `invalidate("app:x")`, or `refreshAll()`; `invalidateAll` is deprecated.

## Forms and endpoints

- Mutate with `actions: Actions` in `+page.server.ts`: one `default`, or named actions, never mixed. Read `request.formData()` into `unknown`, validate with Zod `safeParse`, return `fail(422, { errors: z.flattenError(error).fieldErrors, values })` without secrets, `redirect(303, ...)` after success, and call `requireUser()` first. Money is `amountMinor` integers.
- The form is `<form method="POST">` with a submit button plus `use:enhance` from `$app/forms`; it works without JavaScript. Read `form?.errors?.x`. Mark fields `aria-invalid` and show messages in `role="alert"`. Pending state: `const handleSubmit: SubmitFunction = ...` (type from `$app/forms`, not `@sveltejs/kit`) returning `async ({ update }) => { await update(); ... }`. Disable the submit button while it runs.
- A `GET` form is for search and filters. Custom listeners use `deserialize`, not `JSON.parse`.
- `+server.ts` handlers validate the body (`const raw: unknown = await request.json()`), check the user, and answer with `Response.json(value, { status })`.
- Do not use remote functions (experimental, need `await` in components).

## State and navigation

- One server process serves every user: no user data in module variables, singletons or module-level `$state` on the server. Per-user data lives in `event.locals`, cookies and the database. Shared UI state is a class in `.svelte.ts` handed down with `createContext` created in a layout. Pass state down, not up, during SSR.
- Values that depend on `data` or `page` use `$derived`: layouts and pages persist across navigation. Use `afterNavigate`, not `onMount`, for per-navigation work. `snapshot` keeps disposable UI state.
- State that survives reloads or the server needs goes in the URL search parameters, read with a schema in `load`; change it with a `GET` form or `goto(resolve(...))`.
- `page`, `navigating` and `updated` come from `$app/state` (no `$app/stores`, no `$page`). `page.url` is a `ReadonlyURL`: copy it to change it. `page` is readable on the server only while rendering, not in `load`.
- Every internal link and `goto` uses `resolve()` from `$app/paths`: `resolve("/loans/[loanId]", { loanId })`; `asset()` for `static/`. `svelte/no-navigation-without-resolve` enforces it. Use `<a>` for navigation, not a button with `goto`. `data-sveltekit-preload-data="hover"` stays on `<body>`; options take `false`, not `"off"`.

## Hooks, errors and security

- `src/hooks.server.ts`: `handle` fills `event.locals` and calls `resolve`; combine with `sequence`; types from `@sveltejs/kit/hooks` (`Handle`, `HandleServerError`). `handle` does not run for static assets or prerendered pages. `handleFetch` only to change server `fetch`. `reroute` and `transport` only for a real need.
- Authenticate in `handle`; authorise in every `load`, action and `+server` handler through one helper that calls `getRequestEvent()` from `$app/server` (`requireUser()`). A layout's `load` does not protect its children. Section guards in `handle` match `event.route.id`, not `url.pathname`. Never prerender a private page. Cookies: `httpOnly`, `secure`, `sameSite: "lax"`, `maxAge`. Prefer database sessions to JWT; use a library (`sv add better-auth`) rather than hand-rolled auth.
- `handleError` receives `{ kind, error, event }` (`app`, `framework`, `validation`, `unknown`): for `unknown`, log once with the cause chain and return a safe `{ message }`; never throw, never return details. `App.Error` always has `status` and `message`; `error(409, "msg", { code })` puts extras in the third argument. `+error.svelte` reads `page.status` and `page.error`; show messages only for expected errors. Keep `src/error.html`.
- Environment: declare every variable in `src/env.ts` with `defineEnvVars` and a Zod schema; private by default (`$app/env/private`), `public: true` for the browser (`$app/env/public`, names prefixed `PUBLIC_`), `static: true` only for build-time constants. Never read `process.env`; no `$env/*` or `$app/environment` (use `$app/env`). A missing variable stops `vite build` and the server (`env_invalid`), so give CI the build-time values. Commit `.env.example`, never `.env`.
- CSRF protection is always on; allow other origins only through `csrf.trustedOrigins`, never `*`. Fix a proxy origin problem with `ORIGIN`, not by weakening CSRF. Set `csp` (`mode: "auto"`, start with `reportOnly`). Other security headers at nginx. `{@html}` only with sanitised input.

## Rendering, SEO and performance

- Keep `ssr`, `csr` and `prerender` at their defaults and write a reason beside any change. Prerender only pages that are identical for every visitor (no form action, no `url.searchParams`, `entries` for dynamic routes, `"auto"` for partial). Never `ssr = false` in the root layout; a client-only app with no server needs plain Svelte instead. `csr = false` only for pure content. Keep `trailingSlash` at `"never"`, never `"ignore"`.
- Every page has a unique `<title>` and `<meta name="description">` in `<svelte:head>` (SEO data from `load` through `page.data`, typed in `App.PageData`). Set `lang` in `app.html`. Sitemap as `+server.ts`, `robots.txt` in `static/`.
- Import images (`src/lib/assets/`); `@sveltejs/enhanced-img` before `sveltekit()` for build-time images; `alt` always; `fetchpriority="high"` and no lazy loading for the LCP image; set image sizes. Measure `npm run build && npm run preview`, not the dev server. Preload fonts with the `resolve` filter in `handle`, avoid waterfalls, compress at nginx.

## Testing

- Vitest with the two projects of `svelte.md` inside `vite.config.ts` (`extends: true`): `unit` (`src/**/*.test.ts`, Node.js) and `component` (`src/**/*.browser.test.ts`, Browser Mode, `exclude: ["src/lib/server/**"]`), `expect: { requireAssertions: true }`. Rename the `*.svelte.{test,spec}` files that `sv add vitest` writes. `*.svelte.test.ts` is for tests that use runes.
- Move route logic into `src/lib/server/` and unit-test that. `getRequestEvent()` throws outside a request, so a function that calls it cannot run in a plain unit test. Tests never catch a client import of a server module (the check is off when `TEST` is true), so keep `build` in `ci`.
- Render pages with `render` from `vitest-browser-svelte` giving `data`, `form: null` and `params: {}`; query by role; check links with `toHaveAttribute("href", ...)`. Playwright e2e tests live in `e2e/` as `*.e2e.ts`, run against `npm run build && npm run preview`, query by role and label, and run in a separate CI job.

## Deployment

- `adapter-node`: `npm run build`, deploy `build/`, `package.json` and production dependencies, start with `node build`. `.env` is not loaded in production (`node --env-file=.env build` or the container environment). Server variables: `PORT`, `HOST`, `ORIGIN`, `PROTOCOL_HEADER`, `HOST_HEADER`, `ADDRESS_HEADER`, `XFF_DEPTH`, `BODY_SIZE_LIMIT`, `SHUTDOWN_TIMEOUT`.
- Behind nginx set `ORIGIN=https://<host>` (simplest and safest); use the header variables only behind a proxy that overwrites them; `ADDRESS_HEADER=x-forwarded-for` with `XFF_DEPTH` for the client address. Compress and cache at nginx (`/_app/immutable/` long and immutable; no buffering for streamed routes). Follow the infrastructure notes for the container (slim image, pinned major, non-root, `.dockerignore`), and add `GET /health`.
- Shut down gracefully (`SIGTERM`, `SHUTDOWN_TIMEOUT`, close resources on the `sveltekit:shutdown` event) and keep no per-process state if you run several instances.
- `adapter-static`: `export const prerender = true` in the root `+layout.ts`, keep `strict`, no `fallback` unless accepted, no `ssr = false`.

## Modern SvelteKit

- Replace SvelteKit 2 forms when you change a line: `svelte.config.js` `kit` to `sveltekit({ ... })` in `vite.config.ts`; `$lib` to `#lib`; `$app/stores` to `$app/state`; `$app/environment` and `$env/*` to `$app/env` and `src/env.ts`; `base` and `resolveRoute` to `resolve()`; `pushState` to `goto(..., { shallow: true })`; `invalidateAll` to `refreshAll`; hook types to `@sveltejs/kit/hooks`; `json()` to `Response.json()`; `handleValidationError` to `handleError`; `csrf.checkOrigin` to `csrf.trustedOrigins`; `src/params/*` to `src/params.ts`; `extends ./.svelte-kit/tsconfig.json` to `$app/tsconfig`.
- Upgrade from 2.x: newest 2.x first and fix its deprecation warnings, then `npx sv migrate sveltekit-3` one task at a time on a clean tree, committing after each; search for `@migration-task`; run `npm run ci` after each task. Update adapters with `@sveltejs/kit`.
