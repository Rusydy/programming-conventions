# Nuxt Principles and Sources of Truth

## Summary

These principles apply to every Nuxt 4 application. They put Nuxt's own conventions, the generated types and the official Nuxt documentation ahead of local configuration, so that any Nuxt developer can read the code on the first day. The set builds on [vue-conventions](../vue-conventions/01-principles-and-sources.md) for components, reactivity and composables, and on [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) for every question about TypeScript. It adds only what Nuxt owns: directories, auto-imports, routing, data fetching, the Nitro server, rendering, configuration and deployment.

## Rules

### Principles

1. **Let Nuxt's conventions do the work.** Put a file in the directory that Nuxt scans (`app/pages`, `app/components`, `app/composables`, `server/api`, `shared`) instead of registering it by hand. A route, a layout, a middleware, a plugin and an API handler each have a directory ([layout](03-project-layout-and-auto-imports.md#layout)).
2. **Write Vue the way the Vue notes say.** Every component is `<script setup lang="ts">`, state is `ref()`, derived values are `computed()`, and the Vue lint rules apply. Nuxt changes where the code lives and what you may leave out, not how a component is written ([Vue principles](../vue-conventions/01-principles-and-sources.md#principles)).
3. **Fetch with the Nuxt composables.** Use `useFetch` or `useAsyncData` for data that a page needs, and `$fetch` for actions that a user starts. A bare `$fetch` in `setup` fetches twice, once on the server and once in the browser ([data fetching](05-data-fetching.md)).
4. **Keep the server and the app apart.** Code in `server/` never imports Vue code, and code in `app/` never imports server code. Shared types and pure functions live in `shared/` ([server](06-server-routes-and-validation.md#the-boundary)).
5. **Validate at the edge.** Every external value is `unknown` until a Zod schema accepts it: a request body, a query string, a header, and a response from a third-party API. Do it once, in `server/`, and send the app a typed domain shape ([server](06-server-routes-and-validation.md#validation)).
6. **Never share state between requests.** A module-level `ref()` in a Nuxt app leaks between users on the server. Use `useState()` or a Pinia store ([state and configuration](07-state-and-configuration.md#state)).
7. **Configure at run time, not at build time.** A value that differs between environments goes in `runtimeConfig` and is set with a `NUXT_` environment variable. Only `runtimeConfig.public` reaches the browser ([state and configuration](07-state-and-configuration.md#runtime-configuration)).
8. **Choose the rendering mode per route.** Server-render by default and use `routeRules` to prerender, cache or turn off server rendering for a section ([rendering](09-rendering-seo-and-performance.md#rendering-modes)).
9. **Follow the toolchain.** `nuxt typecheck`, `@nuxt/eslint`, `@nuxt/test-utils` and the generated `.nuxt` configs define the baseline. Replace a default only with a written reason. This is convention over configuration applied to Nuxt.
10. **Wait for a second use case.** Do not add a module, a layer, a plugin, a store or a custom wrapper "just in case". Nuxt already ships most of what a first version needs.
11. **Follow the TypeScript notes.** Every rule of [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) applies in `app/`, `server/` and `shared/`, except where [the rule on precedence](#order-of-precedence) names an exception.

### Order of precedence

When two sources disagree, the lower number wins.

1. The behaviour of Nuxt, Nitro and Vue, and the official Nuxt documentation, API reference and release notes.
2. The notes in this folder.
3. The notes in [vue-conventions](../vue-conventions/01-principles-and-sources.md), for every question about components, reactivity, composables and templates.
4. The `nuxt typecheck` diagnostics, and the `@nuxt/eslint`, `eslint-plugin-vue` and typescript-eslint presets that the notes name.
5. [typescript-conventions](../typescript-conventions/01-principles-and-sources.md), for every question about TypeScript itself.
6. Other style guides. Adopt one of their rules only when a note in this folder names it.

Nuxt's required shape overrides the Vue and TypeScript notes for the code that Nuxt dictates. There are seven cases, and each one is recorded in the note that uses it:

- **Auto-imports.** Nuxt APIs, `vue` functions, composables, utilities, components and shared types need no `import`. The Vue rule to import everything explicitly does not apply in `app/`, `server/` and `shared/` ([layout](03-project-layout-and-auto-imports.md#auto-imports)).
- **Directory structure.** Code is grouped by what it is (`app/components`, `app/composables`), not by feature, because Nuxt scans those directories. The Vue rule to group by feature does not apply ([layout](03-project-layout-and-auto-imports.md#layout)).
- **Top-level `await` for Nuxt data composables.** `await useFetch(...)` and `await useAsyncData(...)` in `<script setup>` are the Nuxt idiom, because Nuxt wraps the app in `<Suspense>` for them. The Vue rule against top-level `await` and `<Suspense>` still applies to everything else ([data fetching](05-data-fetching.md#await-and-suspense)).
- **Default exports.** A page, a layout, a middleware, a plugin, an API handler, `nuxt.config.ts` and `app.config.ts` are default exports, because Nuxt requires them. The TypeScript rule for named exports applies to every other module ([layout](03-project-layout-and-auto-imports.md#naming)).
- **Single-root templates.** A page and a layout have exactly one root element, because Nuxt applies transitions to it. `vue/no-multiple-template-root` is on in the Nuxt ESLint config ([routing](04-pages-routing-and-navigation.md#pages)).
- **The error body of your own API.** A handler that only your app calls answers with Nuxt's error shape, not with RFC 9457 problem details, because `useFetch` and `isNuxtError()` read that shape ([server](06-server-routes-and-validation.md#errors)).
- **Generated tsconfig files.** `tsconfig.json` is a list of references to `.nuxt/tsconfig.*.json`. Compiler options are added in `nuxt.config.ts`, not in `tsconfig.json` ([setup](02-project-setup-and-tooling.md#tsconfig)).

### Applying the notes

- **New code** follows every note in this folder and in the Vue and TypeScript sets.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so each review stays small, and raise the rest as a separate task.
- **Nuxt 3 projects:** a project on Nuxt 3 moves to Nuxt 4 in its own change, with the codemod and the migration guide, before it adopts these notes ([modern Nuxt by release](13-modern-nuxt-by-release.md#upgrading)).
- **Stricter settings:** adopt a compiler option or a lint rule in its own change, with its errors fixed or suppressed in that change.
- **Mechanical changes** (formatting, autofixes, dependency bumps, `nuxt upgrade` runs) go in their own commits.
- **Generated code** is exempt: everything in `.nuxt/`, `.output/` and `.data/`, and any file that a tool writes.
- **Shared and team repositories:** when a repository documents its own conventions, follow those first, and apply these notes to the code you write where the repository is silent.
- **Modules and layers:** a Nuxt module that you install brings its own conventions. Follow its documentation for what it owns, and these notes for everything else.

### Decisions to review

These choices were made while writing the notes, because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Why | Where to change it |
| --- | --- | --- |
| Nuxt 4 with the `app/` directory, and no move to Nuxt 5 yet | Nuxt 4.6.4 is the stable release. The documentation on its main branch already describes Nuxt 5 (Nitro 3, h3 2), which was not released on 2026-11-20. | [modern Nuxt by release](13-modern-nuxt-by-release.md#nuxt-5) |
| Auto-imports stay on | They are Nuxt's own design, `@nuxt/eslint` generates the globals, and `nuxt typecheck` knows every name. Turning them off fights the framework. | [layout](03-project-layout-and-auto-imports.md#auto-imports) |
| Code is grouped by type, not by feature | Nuxt scans `app/components`, `app/composables` and the other directories. A component folder per feature (`app/components/loan/`) keeps most of the grouping. | [layout](03-project-layout-and-auto-imports.md#layout) |
| kebab-case file names for components (`loan-row.vue`) | The Vue notes and the TypeScript notes use kebab-case. Nuxt turns `components/loan/loan-row.vue` into `<LoanRow>`. The Nuxt documentation writes PascalCase file names. | [naming](03-project-layout-and-auto-imports.md#naming) |
| The `@/` alias for `app/` | The TypeScript and Vue notes use `@/`. Nuxt generates `@` and `~` for `app/`, and the documentation writes `~/`. `#shared` is Nuxt's alias for `shared/`. | [layout](03-project-layout-and-auto-imports.md#naming) |
| `await useFetch(...)` at the top of `<script setup>` | It is Nuxt's idiom, and the Vue notes' ban on `<Suspense>` would otherwise rule out Nuxt's data fetching. | [data fetching](05-data-fetching.md#await-and-suspense) |
| Nitro handlers import from `nuxt/server`, not from `h3` | `nuxt/server` ships from Nuxt 4.6 and is meant to survive the h3 and Nitro majors that Nuxt 5 brings. In 4.6.4 it exports `defineEventHandler`, and `defineHandler` is in the main-branch documentation only. | [server](06-server-routes-and-validation.md#handlers) |
| Zod for every server schema | The TypeScript notes use Zod. `getValidatedQuery` and `readValidatedBody` accept any Standard Schema, so Zod works with no adapter. | [server](06-server-routes-and-validation.md#validation) |
| Sessions with `useSession` from `nuxt/server`, not `nuxt-auth-utils` | The built-in helper seals a cookie with a key derived from `NUXT_APP_SECRET` and needs no module. The Nuxt recipe uses `nuxt-auth-utils`, which adds login helpers and OAuth providers. | [errors and security](08-errors-and-security.md#sessions-and-authentication) |
| `useState` first, Pinia (`@pinia/nuxt`) when state grows | `useState` is SSR-safe and built in. The Vue notes pick Pinia for shared state, and the module adds the store directory to the auto-imports. | [state and configuration](07-state-and-configuration.md#state) |
| `@nuxt/eslint` with typed typescript-eslint presets, and a11y rules | The Nuxt config is not type-aware, and the TypeScript and Vue notes require the typed presets. | [setup](02-project-setup-and-tooling.md#linting) |
| Vitest in three projects: `unit`, `nuxt` (happy-dom) and `e2e`, with no Browser Mode | `vitest-browser-vue` has no Nuxt runtime, so a component that uses auto-imports, plugins or `useNuxtApp()` cannot run in it. The Nuxt documentation describes `@nuxt/test-utils` with `happy-dom` only. | [testing](10-testing-and-quality-gates.md#tools) |
| Tests in `test/unit`, `test/nuxt` and `test/e2e`, not beside the code | The folder selects the Nuxt environment, and the generated app project includes `test/nuxt`. The TypeScript notes put a test beside its code. | [testing](10-testing-and-quality-gates.md#where-tests-live) |
| `node-server` preset behind nginx | It matches the infrastructure notes. Nuxt also builds static sites, and edge and serverless targets, and the deployment note lists when each fits. | [deployment](11-deployment-and-presets.md) |
| Prettier defaults, and no stylistic ESLint rules | The TypeScript notes use Prettier with no config file. `@nuxt/eslint` can add formatting rules, and they would fight Prettier. | [setup](02-project-setup-and-tooling.md#formatting) |

### Version policy

- **Nuxt:** run the newest 4.x release, declared as `"nuxt": "^4.6.4"` or the newest minor on the day you start. On 2026-11-20 the newest release is 4.6.4, a security release that fixes eight Nuxt advisories and pulls in `nitropack` 2.13.6 with three more fixes. Run 4.6.4 or later. Nuxt follows semantic versioning for its public API, and a minor release adds features without breaking.
- **Features by minimum version:** this set uses `nuxt/server` (4.6), `shared/` (3.14), the `app/` directory and project references in the generated tsconfig files (4.0). Set the `nuxt` range to a version that has every feature the code uses.
- **Vue and Vue Router:** Nuxt pins the Vue range, and `create-nuxt` writes `vue` and `vue-router` into `package.json`. Keep what it writes, and follow the [Vue version policy](../vue-conventions/01-principles-and-sources.md#version-policy) for everything else.
- **TypeScript:** follow the [TypeScript version policy](../typescript-conventions/01-principles-and-sources.md#version-policy). `create-nuxt` does not install `typescript` or `vue-tsc`; add `typescript@~6.0.3` and `vue-tsc`.
- **Node.js:** `nuxt` 4.6.4 declares `^22.22.3 || ^24.15.0 || >=26.0.0` in `engines`, the CLI (`create-nuxt`, `@nuxt/cli`) declares `^22.21.0 || ^24.11.0 || >=26.0.0`, and `@nuxt/test-utils` declares `^20.19.0 || ^22.12.0 || >=24.0.0`. Run an active LTS release of Node.js, and set the same major in `engines`, `.nvmrc` and the Docker image.
- **Upgrades:** move one tool at a time, in its own pull request, and read its release notes first. [Modern Nuxt by release](13-modern-nuxt-by-release.md) lists the releases that matter.

### Working with coding agents

- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/nuxt.md](../agent-rules/rules/nuxt.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** the rule has a `paths` field, so Nuxt rules stay out of sessions that never touch Nuxt. Claude Code loads it when a session reads, writes or edits `nuxt.config.ts`, `app.config.ts`, a file under `app/` (pages, layouts, middleware, plugins, composables, utils, stores), `server/` or `shared/`. The patterns match against the session's primary working directory, so start the session inside the Nuxt repository. A brand-new repository has no such file yet, so tell the agent to read `~/.claude/rules/nuxt.md` before it writes the first one. The digest loads next to `vue.md` and `typescript.md` and replaces neither.
- A project whose agents must follow these notes on other machines names this folder in its own `AGENTS.md`, because the user-level rule is installed per machine. Nuxt also publishes an MCP server and an `llms.txt` file that help an agent look up the documentation, and they do not override these notes.
- Tell agents to run `npm run check`, `npm run lint` and `npm test` before they report Nuxt changes as done, and to read the installed Nuxt version before they use a newer feature: `node -p "require('nuxt/package.json').version"`.

## Sources and raw notes

Pages read on 2026-11-20 unless a bullet says otherwise:

- npm registry on 2026-11-20: `nuxt` 4.6.4 (`latest`), `@nuxt/eslint` 1.17.0, `@nuxt/test-utils` 4.4.0, `@nuxt/image` 2.2.1, `@nuxt/fonts` 1.2.0, `@nuxt/ui` 4.13.0, `@pinia/nuxt` 1.0.3, `create-nuxt` 4.0.3 and `@nuxt/cli` 4.0.3 (Node.js `^22.21.0 || ^24.11.0 || >=26.0.0`), `nuxt-security` 2.7.0, `@nuxtjs/i18n` 10.6.0, `vue-tsc` 3.3.14.
- [Nuxt documentation](https://nuxt.com/docs), read from the `docs` folder of the `nuxt/nuxt` repository (main branch, after the 4.6.4 release of 2026-11-02): the getting-started pages, the directory-structure pages, the concepts, best-practices and recipes guides, the API pages for the data-fetching composables and `nuxt.config`, and the upgrade page. The main-branch documentation describes some features that are not in 4.6.4, and the notes name each such case.
- [Nuxt releases](https://github.com/nuxt/nuxt/releases): 4.6.4 (2026-11-02) as the latest.
- `create-nuxt` 4.0.3 with the `minimal` template, run on 2026-11-20: it writes `nuxt ^4.6.4`, `vue ^3.5.45` and `vue-router ^5.4.0`, a `compatibilityDate` of `2025-07-15`, `app/app.vue` with `<NuxtRouteAnnouncer />`, and a `tsconfig.json` that lists the four `.nuxt/tsconfig.*.json` references.
- The sample project that checks these notes: scaffolded with `create-nuxt` 4.0.3, with Nuxt 4.6.4, Vue 3.5.45, Vue Router 5.5.1, TypeScript 6.0.3, `vue-tsc` 3.3.14, ESLint 10.15.0, `@nuxt/eslint` 1.17.0, typescript-eslint 8.73.0, `eslint-plugin-vuejs-accessibility` 2.6.3, Prettier 3.10.1, Vitest 5.1.1, `@nuxt/test-utils` 4.4.0, happy-dom 21.0.4, Pinia 4.1.0 and `@pinia/nuxt` 1.0.3. `npm run ci` passed `nuxt typecheck`, `eslint --max-warnings 0`, `prettier --check .`, six Vitest tests in three projects and `nuxt build`. Each note says which of its examples ran there.
