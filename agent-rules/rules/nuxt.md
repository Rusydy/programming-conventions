---
paths:
  - "nuxt.config.ts"
  - "app/app.config.ts"
  - "app/app.vue"
  - "app/error.vue"
  - "app/pages/**"
  - "app/layouts/**"
  - "app/middleware/**"
  - "app/plugins/**"
  - "app/composables/**"
  - "app/components/**"
  - "app/stores/**"
  - "app/utils/**"
  - "server/**"
  - "shared/**"
  - "test/nuxt/**"
  - "test/e2e/**"
---
# Nuxt conventions (Nuxt 4.6)

Write idiomatic Nuxt 4. Follow Nuxt's own conventions, the generated types and the official Nuxt documentation instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `nuxt-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. It loads next to `vue.md` and `typescript.md` and replaces neither. If the project has no `nuxt.config.ts` (a Next.js `app/` folder, say), ignore this file. The digest was synced with the notes on 2026-11-20; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file, then `vue.md` for components, reactivity and composables, then `typescript.md`. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatting, autofixes, dependency bumps, `nuxt upgrade`) in their own commits.
- When sources disagree, the order is: Nuxt, Nitro, Vue behaviour and the official documentation; this file and the notes; the Vue notes; `nuxt typecheck`, `@nuxt/eslint`, `eslint-plugin-vue` and the typescript-eslint presets; the TypeScript notes.
- Nuxt's required shape overrides the Vue and TypeScript notes in seven places: auto-imports (no imports for Nuxt, Vue, shared and own composables, utils, components); directories by type, not by feature; top-level `await useFetch`/`await useAsyncData`; default exports for pages, layouts, middleware, plugins, handlers and the two config files; a single root element in pages and layouts; Nuxt's error body for your own API; generated tsconfig files.
- If the repository documents its own conventions, follow them first. Generated files are exempt (`.nuxt/`, `.output/`, `.data/`).
- Before you report Nuxt changes as done, run `npm run check`, `npm run lint` and `npm test`. Before you use a newer feature, read the version: `node -p "require('nuxt/package.json').version"`.

## Setup and tooling

- Create with `npm create nuxt@latest <name> -- --template minimal --packageManager npm`. Run Nuxt 4.6.4 or later (a security release). Add `typescript@~6.0.3`, `vue-tsc`, `@nuxt/eslint`, `eslint`, `prettier`, `eslint-config-prettier`, `@eslint/js`, `typescript-eslint`, `eslint-plugin-vuejs-accessibility`, `jiti`. Keep the `postinstall` script (`nuxt prepare`) and the `compatibilityDate`. CI uses `npm ci`, never `--ignore-scripts`.
- `app.vue`: `<NuxtLayout><NuxtRouteAnnouncer /><NuxtPage /></NuxtLayout>`; delete `<NuxtWelcome />`. Keep `nuxt.config.ts` short: modules, runtimeConfig, routeRules, typescript.
- Leave `tsconfig.json` as generated (four references to `.nuxt/tsconfig.*.json`). Add `noImplicitReturns`, `noFallthroughCasesInSwitch`, `erasableSyntaxOnly` through `typescript.tsConfig.compilerOptions` in `nuxt.config.ts` (Nuxt already sets `strict`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `noImplicitOverride`). Add `typescript.nodeTsConfig.include`: `../eslint.config.ts`, `../vitest.config.ts`, `../test/unit/**/*`, `../test/e2e/**/*`. Do not turn `typescript.typeCheck` on.
- Aliases: `@/` for `app/`, `#shared/` for `shared/`; never `../../..`.
- Scripts: `check` is `nuxt typecheck`, `lint` is `eslint --max-warnings 0`, `format:check` is `prettier --check .`, `test` is `vitest run`, `build` is `nuxt build`, and `ci` runs them in that order. CI calls `npm run ci` only.
- ESLint: `eslint.config.ts` wraps `withNuxt()` from `./.nuxt/eslint.config.mjs` (delete the generated `eslint.config.mjs`) with `js.configs.recommended`, typescript-eslint `recommendedTypeChecked` and `stylisticTypeChecked` mapped to `files: ["**/*.{ts,vue}"]`, `projectService: true` with `extraFileExtensions: [".vue"]`, `no-non-null-assertion` as an error, `pluginA11y.configs["flat/recommended"]`, the Vue rules of `vue.md` for `**/*.vue` (not `no-undef-components`), `vuejs-accessibility/label-has-for` with `required: { some: ["nesting", "id"] }`, and `eslint-config-prettier/flat` last. No stylistic module option, no Oxlint. A layout needs `defineSlots`.
- Prettier 3 with defaults and no `.prettierrc`; `.prettierignore` lists `.nuxt`, `.output`, `node_modules`.
- Add `@pinia/nuxt` only for real shared state; `@nuxt/image` and `@nuxt/fonts` only when the site has images or fonts to optimise. No UI kit, CSS framework or other module without a written reason.

## Layout and auto-imports

- `app/` has `app.vue`, `app.config.ts`, `error.vue`, `pages/`, `layouts/`, `components/`, `composables/`, `utils/`, `middleware/`, `plugins/`, `stores/`, `assets/`, `types/`; `server/` has `api/`, `routes/`, `middleware/`, `plugins/`, `utils/`; `shared/` has `types/` and `utils/`; tests in `test/{unit,nuxt,e2e}`.
- Components in a folder per feature (`components/loan/loan-row.vue` is `<LoanRow>`), base ones in `components/base/` (`<BaseButton>`), single-instance ones in `components/the/`. Nuxt dedupes repeated prefixes. Keep `composables/` and `utils/` flat (a file in a subfolder is not auto-imported).
- Files are kebab-case; composables `use-x.ts` export `useX`; stores `x-store.ts` export `useXStore`. Named exports, except where Nuxt needs a default (pages, layouts, `app.vue`, `error.vue`, middleware, plugins, handlers, config files). Page files use Nuxt syntax (`[id].vue`, `index.get.ts`).
- `shared/` has no Vue and no Nitro code (schemas, `z.infer` types, constants like `HTTP_STATUS`, pure functions). `app/` never imports `server/`, `server/` never imports `app/`.
- Rely on auto-imports in `app/`, `server/` (Nuxt and shared names) and `shared/`. Import explicitly in `test/unit` and `test/e2e`, for types from packages, and via `#imports` when a file must run outside Nuxt. No `unplugin-auto-import`, no `imports.autoImport: false`. Call Nuxt composables before the first `await`. `Lazy` prefix for lazy components.

## Pages, layouts, middleware, navigation

- Routes are files. Pages and layouts have exactly one root element (comments count). Metadata through `definePageMeta` (literals only); type custom keys by augmenting `PageMeta` in `app/types/`. Distinct title per page via `useSeoMeta`. Param is `string | string[]`: narrow it, or use `validate`.
- Missing resource: `throw createError({ status: HTTP_STATUS.notFound, statusText: "...", fatal: true })` so the response is a real 404.
- Layouts: one root with a `<slot />` inside, `defineSlots`, the `<main tabindex="-1">` landmark; `layout` in `definePageMeta`.
- Route middleware: `defineNuxtRouteMiddleware` returns nothing, `navigateTo(...)` or `abortNavigation()`, never `next`. Cheap, no data fetching, `.global` sparingly. Real checks live in the server.
- `<NuxtLink>` with route objects by name; `navigateTo` in handlers; `<NuxtRouteAnnouncer />` stays; `<NuxtLoadingIndicator />` for blocking routes. After navigation focus the page heading or `<main>`.

## Data fetching

- `useFetch` for data a page needs, `useAsyncData(key, ...)` for non-URL data (explicit key; no Pinia actions inside, use `callOnce`), `$fetch` for events (submit, click). Never bare `$fetch` in `setup`.
- `await useFetch(...)`/`await useAsyncData(...)` at the top of `<script setup>` is the Nuxt idiom (the one exception to the Vue top-level `await` ban). Use `lazy: true` for secondary data and render `status`. Don't `await` a lazy call and expect it to be lazy.
- Pass changing inputs as refs, computed values or getters (`query: { q: query }`, a URL getter). Same key means same options. `data` is a shallow ref (`deep: false`) and `undefined` until loaded; set `default` where the template needs a value. `dedupe: "cancel"` by default; the handler receives an abort `signal`.
- Render loading (`role="status"`), error (`role="alert"`, your own message) and data states. No type argument on `useFetch<T>` for your own routes: Nuxt infers it from the handler. Shrink payloads with `pick`/`transform`.
- Call third-party APIs from `server/api` handlers (key in private runtimeConfig, timeout, schema parse, map to the domain type), never from pages. Forward only needed headers.
- Mutations: a submit handler with `$fetch` and a method, `isSaving`, `try/catch/finally`, own error message, then `refresh()` or the response. `createUseFetch()`/`createUseAsyncData()` (4.4) for shared defaults. A query library is not needed for Nuxt's own sharing.

## Server

- Handlers named `x.get.ts`/`x.post.ts` in `server/api/` (`server/routes/` for non-API like `health.get.ts`). Import from `nuxt/server`, not `h3`/`nitropack`: `defineEventHandler` (4.6.4 does not export `defineHandler`), `createError`, `getValidatedQuery`, `readValidatedBody`, `getRouterParam`, `setResponseStatus`, `useRuntimeConfig(event)`, `useSession`. Annotate the handler's return type with a type from `shared/`; return JSON types (ISO strings, integer minor units), never DB rows.
- Validate every external value (`unknown` until a Zod schema accepts it): `getValidatedQuery(event, schema)`, `readValidatedBody(event, schema)` (400 with `data.issues`), params with `safeParse`; business rules after (422). `HTTP_STATUS` table in `shared/utils/http-status.ts` for every status, never bare numbers.
- `createError({ status, statusText })` for client-visible failures; anything else becomes a generic 500 and is logged. Nuxt's error body shape stays for your own API (RFC 9457 only for a public API). A method with no handler answers 404.
- Server middleware returns nothing; plugins run at start-up. No module-level per-user state. No `process.env`; use `useRuntimeConfig(event)`.

## State and configuration

- Never `const x = ref()` at module level (leaks between requests). `useState<T>("key", () => init)` inside a `useX()` composable, return `readonly()` state and functions; serialisable values only. `useCookie` for small non-secret preferences. Pinia setup store in `app/stores/` (auto-imported with `@pinia/nuxt`) when state grows; `callOnce` for side effects.
- `runtimeConfig` with typed defaults; keys outside `public` are server-only; override with `NUXT_...` env vars at run time (type follows the default). `.env` works only for dev/build/generate; production gets real environment variables. `.env.example` has keys only. `NUXT_APP_SECRET` (32+ random bytes) per environment, stable across instances. No secrets in `public`, `app.config.ts` or the payload.
- `app.config.ts`: public, non-secret, build-time UI tokens via `defineAppConfig` (no casts); read with `useAppConfig()`.

## Errors and security

- `app/error.vue` takes a `NuxtError` prop, no data fetching, offers `clearError({ redirect: "/" })`. `<NuxtErrorBoundary>` with an `#error` slot around the layout slot and failing widgets. Report errors once in a plugin with the `vue:error` hook (and `app:error`). Never show `error.message` of an unexpected error. 4.6.4 strips error details except for `createError` errors.
- Sessions: `useSession(event)` from `nuxt/server` (sealed cookie from `NUXT_APP_SECRET`; `HttpOnly; Secure; SameSite=Lax`), keep only an id and role. One `requireUserId(event)` helper throws 401 in every private handler; check authorisation too. Route middleware is only convenience.
- Cookies that carry identity come from the server with `httpOnly`, `secure`, `sameSite: "lax"`; never tokens in `localStorage`. Security headers and CSP at nginx; no `unsafe-eval`. Never `v-html`. Validate URL schemes before `navigateTo(url, { external: true })` (open redirect). Rate-limit at nginx/fail2ban.

## Rendering, SEO, performance

- Universal rendering by default; choose per route with `routeRules`: `prerender` for static-until-deploy pages only, `swr`/`isr` for public cacheable pages (never for user-specific routes), `ssr: false` for sections that need no indexing, `redirect`, `headers`, `cors`. A prerendered page ships build-time data.
- Hydration: no `window`/`document`, `Math.random()`, `Date.now()` or time-dependent text in setup; use `onMounted`, `useState`, `<ClientOnly>` with a same-size `#fallback`, `useId()`. Treat hydration warnings as bugs.
- `useSeoMeta` (title, description, og) and `useHead`; global `titleTemplate`; `lang` in `app.head`; `robots.txt` in `public/`. Real 404s/redirects.
- `Lazy` components, `hydrate-on-visible` and friends for late hydration, `<NuxtLink>` prefetch, few plugins (async ones `parallel`), `@nuxt/image` (`width`/`height`/`alt`) and `@nuxt/fonts` when needed, `nuxt analyze`. Measure first.

## Testing

- Vitest, no `globals`, three projects in `vitest.config.ts`: `unit` (node, `test/unit/**`), `e2e` (node, `test/e2e/**`, long timeout), `nuxt` (`defineVitestProject`, `environment: "nuxt"`, `test/nuxt/**`, happy-dom). Add `@nuxt/test-utils/module`. No Browser Mode or `vitest-browser-vue` in Nuxt. Folder, not comment, selects the environment. Tests live under `test/`, not beside code.
- Nuxt tests: `mountSuspended(Component, { props })` (or `renderSuspended`), query by role, assert `emitted()`; mock only the network with `registerEndpoint("/api/x", () => ...)`; `clearNuxtData()` in `beforeEach`; auto-imports work in the test. Unit tests import explicitly by relative path.
- e2e: `await setup({ rootDir, browser: true })`, `$fetch` for handlers (assert `statusCode: HTTP_STATUS.x`), `createPage` for journeys. Cover success, 400, 422, 404 and 401 per handler. All TypeScript testing rules apply.

## TypeScript

- Four generated projects (app, server, shared, node). Put augmentations in the matching directory (`app/types/page-meta.d.ts` with `declare module "#app" { interface PageMeta { ... } }`). Never edit `.nuxt/`; run `npx nuxt prepare` after a clone.
- Handler return types flow into `useFetch`/`$fetch`; no type arguments on them; `useState<T>` and `useCookie` take a type argument. External data is `unknown` until a schema accepts it; `z.infer` types live in `shared/types/` (auto-imported). `NuxtError` from `#app`, `isNuxtError` to narrow. Never use `#build`/`#internal`/`#nitro` paths. No `baseUrl`/`paths` in `tsconfig.json`.

## Deployment

- `node-server` preset behind nginx: `nuxt build`, ship `.output/` only (self-contained, about 4 MB), `node .output/server/index.mjs`. `NITRO_PORT`/`NITRO_HOST` (or `PORT`/`HOST`), `NUXT_*` settings and `NUXT_APP_SECRET` from the process environment. `GET /health` route. One process per container (no PM2/cluster), non-root user, slim pinned image, health check, `init: true`, `SIGTERM` stops it. Build once, promote the image.
- nginx terminates TLS, sets security headers, compresses, limits body size, forwards `Host`; trust `X-Forwarded-*` only from your own proxy (`getRequestURL(event, { xForwardedHost: true, xForwardedProto: true })`). `/_nuxt/` is immutable-cached (Nitro sets it). Keep old hashed files for a few minutes after a deploy. Static (`nuxt generate`) only if every page can be prerendered; serverless/edge presets only with a written reason.

## Modern Nuxt

- Nuxt 3 is end of life (2026-07-31); move to 4 first. Nuxt 4.6.4: error details stripped in production except `createError`, `swr`/`isr`/`cache` only cache GET/HEAD and responses without cookies, route rules match encoded slashes.
- Replace on touch: root-level `pages/`, `components/` with `app/`; `h3`/`nitropack` imports with `nuxt/server`; module-level `ref` with `useState`; hand-written `useFetch` wrappers with `createUseFetch`; `useLazyFetch` with `lazy: true`; `process.env` with runtime config; `.eslintrc` with `withNuxt()`; `next()` in middleware with returns.
- Nuxt 5 (Nitro 3, h3 2) is not released. Do not adopt pre-releases. Keep server code on `nuxt/server`; switch `defineEventHandler` to `defineHandler` when your version exports it.
