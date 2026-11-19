# Modern SvelteKit by Release

## Summary

SvelteKit 3 removed or renamed many APIs that SvelteKit 2 code and most tutorials still use. Write the SvelteKit 3 form, and replace the old one when you touch its line. Upgrade a 2.x project to the newest 2.x release first, fix its deprecation warnings, and then run `sv migrate sveltekit-3` one task at a time.

## Rules

### What SvelteKit 3 requires

- Node.js 22.17 or later, TypeScript 6, Svelte 5.57.1 or later, Vite 8.0.12 or later, and `@sveltejs/vite-plugin-svelte` 7. Every first-party adapter needs SvelteKit 3.
- Set `engines`, `.nvmrc` and the production runtime to a Node.js that meets this. `sv create` writes `engine-strict=true` in `.npmrc`, so `npm install` fails on an older one.
- The newest SvelteKit release on 2026-11-18 is 3.3.1. The documentation for SvelteKit 2 is still online and is a frequent source of wrong code, so check the page's version.

### Idioms to replace

Replace the old form in the lines you change, and leave the rest of the file alone.

| SvelteKit 2 | SvelteKit 3 |
| --- | --- |
| `svelte.config.js` with `kit: { ... }` | Options passed to `sveltekit({ ... })` in `vite.config.ts`, at the top level |
| `import x from "$lib/x"` | `import x from "#lib/x.ts"`, with `"#lib/*": "./src/lib/*"` in `package.json` `imports` |
| `kit.alias` | Subpath imports in `package.json` |
| `import { page } from "$app/stores"` and `$page` | `import { page } from "$app/state"` and `page` |
| `$navigating`, `$updated` | `navigating`, `updated` from `$app/state` |
| `$app/environment` | `$app/env` |
| `$env/static/private`, `$env/dynamic/private` and the public pair | `src/env.ts` with `defineEnvVars`, read from `$app/env/private` and `$app/env/public` |
| `base`, `assets`, `resolveRoute` from `$app/paths` | `resolve()` and `asset()`, with no leading slash on a pathname |
| `pushState(url, state)` and `replaceState` | `goto(url, { shallow: true, state })`, with `replace: true` where needed |
| `invalidateAll()` | `refreshAll()` |
| `goto(url, { invalidateAll: true, keepFocus: true, noScroll: true })` | `goto(url, { refreshAll: true, reset: false })` |
| `import type { Handle } from "@sveltejs/kit"` | `import type { Handle } from "@sveltejs/kit/hooks"` |
| `json(value)` and `text(value)` helpers | `Response.json(value)` and `new Response(text)` |
| `handleValidationError` | `handleError` with `kind: "validation"` |
| `error(HTTP_STATUS.notFound, { message })` with a non-string second argument | `error(HTTP_STATUS.notFound, "message", { code })` |
| `csrf: { checkOrigin: false }` | `csrf: { trustedOrigins: [...] }` |
| `src/params/uuid.ts` files | One `src/params.ts` with `defineParams` |
| `$service-worker` | `$app/manifest`, `$app/env` and `$app/paths` |
| `instanceof` on `HttpError` and `Redirect` | `isHttpError()` and `isRedirect()` |
| `data-sveltekit-preload-data="off"` | `data-sveltekit-preload-data="false"` |
| `import ... from "@sveltejs/kit/node/polyfills"` | Nothing: remove the import |
| `extends: "./.svelte-kit/tsconfig.json"` | `extends: "$app/tsconfig"` |

### Other behaviour changes to know

- `server` is now a server-only marker in more places. A file with a `server` segment in its name and any `server` folder outside `src/routes` and `static` is server-only, where SvelteKit 2 recognised only `src/lib/server` and the `.server.` infix.
- `page.url` is a `ReadonlyURL`, and a mutation is a type error. Copy it first.
- An external `redirect()` needs an `external` option, and a shallow navigation runs the navigation callbacks.
- Clicking a link to the current page runs `refreshAll()`.
- `use:enhance` on a form whose `action` targets another page now navigates there, and an enhanced response carries the status passed to `fail()`.
- Cookies use `cookie` v2: names must be ASCII, and the default `path` is `/`.
- Sourcemaps are generated and applied to stack traces by default.
- `version.pollInterval` defaults to one hour, where it did not poll before, and `updated.current` refreshes itself.
- An empty `2xx` response from a `+server` has no body, and `resolve` in `handle` always returns a `Promise<Response>`.
- The `config` of a universal `+page.ts` or `+layout.ts` now takes precedence over the server file's.
- `adapter-node` bundles with rolldown and sends content-hash `ETag`s without `Last-Modified`. The `adapter-vercel` `edge` runtime is gone. `adapter-cloudflare` reads `env` and `ctx` from `cloudflare:workers`.
- Remote functions stay experimental. They need `experimental.remoteFunctions`, `compilerOptions.experimental.async`, and files with a `remote` segment, and `form` controls must use `field.as(...)`. This set does not use them ([forms and mutations](05-forms-and-mutations.md#remote-functions)).
- Observability is built in: a `src/instrumentation.server.ts` runs on its own, and `tracing.server` turns on OpenTelemetry tracing. This set does not cover it.

### Upgrading from SvelteKit 2

1. Update to the newest 2.x release and to the Svelte, Vite and plugin versions that SvelteKit 3 needs, if 2.x allows them. Fix every deprecation warning that the build and the editor print.
2. Run on a clean git working tree: `npx sv migrate sveltekit-3`. It is a task-based migration, so run one task at a time and commit after each. List the tasks with `--tasks`. The prerequisite tasks are `package-json` and `tsconfig`. The others are `svelte-config`, `environment`, `paths`, `external-redirects`, `shallow-routing`, `params` and `app-state`. `npx sv migrate app-state` runs the `$app/stores` to `$app/state` change on its own.
3. Search the project for the `@migration-task` marker that the migration leaves where it needs a human, and review the whole diff of each task.
4. Run `npm run ci` after every task. A project does not work after only some tasks, so do not release in the middle.
5. Then apply the rest of these notes: typed lint, `defineEnvVars`, `requireUser()`, `PageProps` and the file layout.
6. Update `adapter-*` packages in the same pull request as `@sveltejs/kit`, and read the adapter's own note in the migration guide.

### Upgrading within SvelteKit 3

- Move one minor version at a time in its own pull request, and read the release notes. A new minor release can add warnings that `svelte-check --fail-on-warnings` turns into failures.
- Treat the `experimental` namespace as unstable in every release. Read the notes of a release before you update when you use any of it.
- Read the installed version before you use an API: `node -p "require('@sveltejs/kit/package.json').version"`. Look the API up in the documentation of that major version.
- Revise this set when SvelteKit 4 is released. The documentation says the deprecated `$env/*` modules and `$app/environment` will be removed in 4.

## Sources and raw notes

Pages read on 2026-11-18:

- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): the requirements, the configuration, module and alias changes, `$app/navigation`, `$app/paths`, `$app/state`, `$app/forms`, `$app/tsconfig`, `@sveltejs/kit`, security, cookies, error handling, params, observability, adapters, responses, server-only modules, remote functions, and the miscellaneous list. The table above is a copy of its old and new forms.
- [Configuration](https://svelte.dev/docs/kit/configuration): `vite.config` support since 2.62, `csrf.checkOrigin` removed in 3.0, `output.linkHeaderPreload`. [Environment variables](https://svelte.dev/docs/kit/environment-variables): `$env/*` and `$app/environment` deprecated in 3 for removal in 4. [`sv migrate`](https://svelte.dev/docs/cli/sv-migrate): the `sveltekit-3` tasks, `app-state`, the `--tasks` option, the advice to commit first and to run one task at a time, the `@migration-task` marker, and that the `svelte-5` migration is a legacy one.
- `sv` 1.5.0 `sv create`: the template already follows the SvelteKit 3 shape, with `vite.config.ts`, `#lib`, `$app/tsconfig` and `engine-strict`.
- `sv migrate sveltekit-3` was not run, because the sample application was created with SvelteKit 3. The table and the steps rest on the migration guide.
