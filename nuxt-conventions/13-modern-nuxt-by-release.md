# Modern Nuxt by Release

## Summary

Write Nuxt 4: the `app/` directory, `shared/`, typed API routes through `nuxt/server`, shallow data refs, project-reference tsconfig files and `createUseFetch`. Run 4.6.4 or later, which is a security release. Nuxt 3 reached end of life on 2026-07-31, so an old project moves to Nuxt 4 first. Nuxt 5 (Nitro 3, h3 2) is not released, and these notes keep the code compatible with it where they can.

## Rules

### Releases that matter

| Release | What it adds that these notes use |
| --- | --- |
| Nuxt 3.14 | The `shared/` directory |
| Nuxt 4.0 (2025-07-15) | The `app/` source directory, `shared/` by default, per-context tsconfig files with project references, shallow data refs and `undefined` defaults in `useFetch` and `useAsyncData`, shared data for a repeated key, a separate TypeScript project per environment |
| Nuxt 4.1 (2025-09-02) | Import maps for stable chunk hashes |
| Nuxt 4.2 (2025-10-25) | An abort `signal` passed to the `useAsyncData` handler, better TypeScript DX, error handling improvements |
| Nuxt 4.3 (2026-01-22) | Layout and caching features, faster builds, extended Nuxt 3 support |
| Nuxt 4.4 (2026-03-12) | `createUseFetch` and `createUseAsyncData` |
| Nuxt 4.5 (2026-07-18) | Groundwork for Nuxt 5: `unhead` 3, `unctx` 3, Vite 8 |
| Nuxt 4.6 (2026-10-05) | `nuxt/server`, a server-agnostic public surface, Nuxt CLI 4 with an interactive `nuxt dev` |
| Nuxt 4.6.4 (2026-11-02) | A security release: eight Nuxt advisories and three Nitro advisories fixed, and behaviour changes below |

- The notes target Nuxt 4.6.4. `nuxt/server` is why the range is `^4.6.4`, and 4.6.4 is the first release of the line that fixes the advisories.
- **Nuxt 3 is over.** Nuxt 3 reached end of life on 2026-07-31, after an extension that the 4.3 release notes announced. Do not start a project on it. Move an existing one to Nuxt 4 in its own change.
- Nuxt 2 and `@nuxt/bridge` are no longer supported by the Nuxt CLI.

### Behaviour changes of 4.6.4

The release notes list these changes. Read them before you upgrade, and test the ones that touch your app:

- **Production error details.** When a page fails to render on the server, the error page and the payload carry the message and data only of errors that you created with `createError`. Everything else is removed. Create an error with `createError` for anything that the user should see, and log the rest ([errors and security](08-errors-and-security.md#errors)).
- **Cached routes.** `cache`, `swr` and `isr` route rules cache only `GET` and `HEAD` requests, and no longer store a response that sets a cookie or sends `Cache-Control: private` or `no-store`. Wildcard `proxy` and `redirect` rules reject a request whose target would leave the rule's scope ([rendering](09-rendering-seo-and-performance.md#rendering-modes)).
- **Route rules and encoded slashes.** A rule such as `/api/**` now also matches `/api%2Fadmin`.
- **Dev server hosts.** The webpack and rspack dev servers reject an unexpected `Host` header, as Vite already did. Add a custom hostname or a tunnel to `devServer.allowedHosts`.
- **`workspaceDir`.** It widens past `rootDir` only to an explicit workspace root or the closest git repository.

### Idioms to replace

Replace the old form when you touch its line.

| Old idiom | Modern idiom |
| --- | --- |
| `pages/`, `components/`, `composables/` at the project root | The same folders under `app/` |
| `~/server`, `server/` code that imports from `h3` or `nitropack` | `server/` handlers that import from `nuxt/server` |
| A shared type or schema copied into `app/` and `server/` | One file in `shared/types/` |
| `export const state = ref()` at module level | `useState()` in a composable, or a Pinia store |
| `useFetch` data that you mutate in place | Replace the value, or set `deep: true` for data a component edits |
| `data.value ?? null` checks for the `null` default of Nuxt 3 | `undefined` is the default of `data` and `error` |
| A hand-written `useFetch` wrapper with shared options | `createUseFetch()` (4.4) |
| `useAsyncData` without a key in a composable | An explicit key |
| `useLazyFetch` and `useLazyAsyncData` | `useFetch` and `useAsyncData` with `lazy: true` |
| `fetch` aborted by hand inside `useAsyncData` | The `signal` that the handler receives (4.2) |
| A root `tsconfig.json` with `extends: "./.nuxt/tsconfig.json"` | A `tsconfig.json` that lists the four `.nuxt/tsconfig.*.json` references |
| `typescript.typeCheck: true` for every build | `nuxt typecheck` as its own step |
| `process.env` in code | `useRuntimeConfig()` and `NUXT_` variables |
| `defineNuxtComponent`, `asyncData`, mixins, the Options API | `<script setup lang="ts">` and composables |
| `nuxi` as a separate package | `nuxt` commands, with `@nuxt/cli` 4 as a dependency of `nuxt` |
| `.eslintrc` with `@nuxt/eslint-config` | A flat `eslint.config.ts` with `withNuxt()` from `@nuxt/eslint` |
| `useHead` for the page title and meta tags | `useSeoMeta` for the tags it knows, `useHead` for the rest |
| A hand-made navigation announcer | `<NuxtRouteAnnouncer />` |
| `router.beforeEach` or `next()` in middleware | `defineNuxtRouteMiddleware` that returns a value |

### Nuxt 5

- Nuxt 5 was not released on 2026-11-20. The Nuxt documentation on the main branch already describes it: Nitro 3 on h3 2 and srvx, server utilities from `nuxt/server`, sessions from `nuxt/server`, the Vite Environment API, Vite 8, and Node.js `^22.22.0`, `^24.15.0` or `>=26.0.0`. It also lists breaking changes: case-sensitive routing, page component names normalised, payload extraction `'client'` by default, `<NuxtErrorBoundary>` catching server-side errors, and runtime config environment variables following the type of their value (Nuxt 4.6.4 already does the last, which the sample confirmed).
- Do not adopt Nuxt 5 pre-releases in an application that ships. Prepare for it by what these notes already say: import server code from `nuxt/server` and not from `h3` or `nitropack`, keep handlers short and typed, keep logic in `shared/` and `server/utils/`, do not rely on case-insensitive routes, and keep the Node.js version current.
- The documentation shows `defineHandler` from `nuxt/server`; Nuxt 4.6.4 exports `defineEventHandler`, which the Nuxt 5 documentation calls an alias. Switch when your Nuxt version exports `defineHandler`. A search and replace does it.
- Nuxt 5 offers a `nitroLegacy: true` option for server code written for Nitro 2. Avoid needing it by keeping `h3` and `nitropack` imports out of `server/`.
- When Nuxt 5 is stable, upgrade in its own pull request, follow the migration guide, and rewrite these notes for the new surface.

### Upgrading

- Move one tool at a time, in its own pull request, and read its release notes first. Nuxt, Vue, Vue Router, Nitro, Vite, ESLint and TypeScript each have their own cadence.
- Use the supported way to upgrade: `npx nuxt upgrade --dedupe` (or the equivalent of the package manager), then `npx nuxt prepare`, `npm run ci`. Read the release notes between the versions, because a minor release can change a default.
- **Nuxt 3 to Nuxt 4:** move first to the newest Nuxt 3 release, then follow the Nuxt 4 migration guide and its codemods. Move to the `app/` directory and the new tsconfig references in their own commits: first the file moves, then the type fixes. Review every `useFetch` and `useAsyncData` call for the shallow ref, the `undefined` defaults and the shared data for a key.
- **Nuxt 4 to a later 4.x:** read the release notes. 4.6.4 and later need Node.js `^22.22.3`, `^24.15.0` or `>=26.0.0`.
- Keep `@nuxt/eslint`, `@nuxt/test-utils` and the other official modules on versions that support your Nuxt, and upgrade modules with Nuxt.
- After an upgrade, compare the type-error count, the lint count, the bundle size (`nuxt analyze`) and the test results before and after, as the TypeScript notes say.

## Sources and raw notes

Pages read on 2026-11-20:

- [Nuxt releases](https://github.com/nuxt/nuxt/releases): 4.0.0 (2025-07-15), 4.1.0 (2025-09-02), 4.2.0 (2025-10-25, abort control for data fetching), 4.3.0 (2026-01-22, extended Nuxt 3 support, end of life on 2026-07-31), 4.4.0 (2026-03-12, `createUseFetch` and `createUseAsyncData`), 4.5.0 (2026-07-18, preparing for Nuxt 5), 4.6.0 (2026-10-05, Nuxt CLI v4, `nuxt/server`), 4.6.4 (2026-11-02, a security release with five behaviour changes). Only the first lines of the 4.0 to 4.3 notes were read, and the table rows for those releases repeat their headings.
- [Upgrade guide](https://nuxt.com/docs/getting-started/upgrade) (main branch): upgrading Nuxt, the nightly channel, and the Nuxt 5 migration (Node.js versions, case-sensitive routing, normalised page component names, payload extraction defaults, `<NuxtErrorBoundary>` on the server, Nitro 3, `nuxt/server`, sessions, runtime config types, the Vite Environment API, `nitroLegacy`).
- [Server imports](https://nuxt.com/docs/guide/going-further/server-imports): `defineHandler` and the `defineEventHandler` alias; "`nuxt/server` ships from Nuxt 4.6".
- The `nuxt` 4.6.4 package: `dist/server/index.d.ts` exports `defineEventHandler` and no `defineHandler`.
- npm registry on 2026-11-20: `nuxt` `latest` 4.6.4 with no 5.x version published, the `3x` tag at 3.21.11 (2026-08-05).
- The rows for Nuxt 3.14 (`shared/`) and the Nuxt 4.0 list come from the documentation's version notes and from the behaviour that the sample showed (the `app/` directory, the four tsconfig files, `data` as a shallow ref); the Nuxt 4 migration guide was not re-read in full.
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `defineHandler` was not exported by `nuxt/server` 4.6.4 (a type error), and `defineEventHandler` was; runtime config variables took the type of their default; `nuxt build` used the `node-server` preset.
