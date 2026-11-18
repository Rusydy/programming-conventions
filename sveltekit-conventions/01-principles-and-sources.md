# SvelteKit Principles and Sources of Truth

## Summary

These principles apply to every SvelteKit 3 application. They put the framework's documented behaviour, the generated `$types` and `svelte-check` ahead of local configuration, and they build on [svelte-conventions](../svelte-conventions/01-principles-and-sources.md) and [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) without repeating them. A plain Svelte project, such as a Wails frontend, uses the Svelte set alone.

## Rules

### Principles

1. **Read the Svelte notes first.** Every `.svelte` file, rune and component in a SvelteKit app follows [svelte-conventions](../svelte-conventions/01-principles-and-sources.md). This set covers only what SvelteKit adds: routing, loading, forms, hooks, rendering and deployment.
2. **Let the framework generate the types.** Import `PageProps`, `LayoutProps`, `PageServerLoad`, `Actions` and the other types from `./$types`, and never write a route's data type by hand ([TypeScript in SvelteKit](11-typescript-in-sveltekit.md)).
3. **Load on the server by default.** Write `+page.server.ts` for data, and move to a universal `+page.ts` only for a public API call or a value that cannot be serialised ([load and data fetching](04-load-and-data-fetching.md#server-or-universal)).
4. **Mutate with form actions.** A `<form method="POST">` with `use:enhance` works without JavaScript and improves when it loads. Use `+server.ts` for a JSON API, and leave remote functions alone until they leave the experimental namespace ([forms and mutations](05-forms-and-mutations.md)).
5. **Never share state on the server.** One server process serves every user. Keep per-user state in `event.locals`, in context or in a database, and never in a module-level variable ([state and navigation](06-state-and-navigation.md#state-on-the-server)).
6. **Authorise where the data is.** Check the user in `handle` for coarse rules, and again in each load function, action and endpoint that reads or writes private data. A layout's load function does not protect its children ([hooks, errors and security](07-hooks-errors-and-security.md#authentication-and-authorisation)).
7. **Validate at the edge.** Parse every `FormData`, search parameter, request body and environment variable with a schema before you use it, as the TypeScript notes require. Declare environment variables with `defineEnvVars`, which does this for the environment.
8. **Use the platform.** Use web standards (`Request`, `Response`, `fetch`, `FormData`, `URL`), the generated `resolve()` for links, and `<a>` and `<form>` for navigation, before you write a client-side router or a store.
9. **Server-render unless you must not.** Leave `ssr`, `csr` and `prerender` on their defaults, and change a page option on a route with a written reason ([rendering, SEO and performance](08-rendering-seo-and-performance.md)).
10. **Wait for a second use case.** Do not add a hook, a layout, a route group or an abstraction before a second route needs it.

### Order of precedence

When two sources disagree, the lower number wins.

1. The documented behaviour of SvelteKit, Svelte and Vite, and their release notes.
2. The notes in this folder.
3. [svelte-conventions](../svelte-conventions/01-principles-and-sources.md), for every question about Svelte itself.
4. [typescript-conventions](../typescript-conventions/01-principles-and-sources.md), for every question about TypeScript itself.
5. The `svelte-check` diagnostics and the lint presets that the notes name.
6. [infra-conventions](../infra-conventions/01-principles-and-sources.md), for the server, the proxy and the container that run the build.

SvelteKit's required shape overrides the Svelte and TypeScript notes for the code that the framework dictates. Each case is recorded in the note that uses it:

- A route file is named `+page.svelte`, `+layout.ts` and so on, which breaks the kebab-case rule for files ([layout and routing](03-project-layout-and-routing.md#naming)).
- A route file and a config file use `export const` names that the framework reads, such as `load`, `actions`, `prerender` and `handle`. A `.svelte` file, `vite.config.ts` and nothing else uses a default export.
- The `#lib` subpath import replaces the `@/` alias of the Svelte notes, and its imports carry the file extension ([layout and routing](03-project-layout-and-routing.md#imports)).
- Environment variables come from `$app/env/private` and `$app/env/public` through `src/env.ts`, not from a `lib/env.ts` module that parses `process.env` ([hooks, errors and security](07-hooks-errors-and-security.md#environment-variables)).

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change, and leave the rest alone unless someone asks for a clean-up.
- **SvelteKit 2 projects:** upgrade to the newest 2.x release first, fix its deprecation warnings, run `npx sv migrate sveltekit-3` one task at a time, and then apply these notes ([modern SvelteKit by release](12-modern-sveltekit-by-release.md#upgrading-from-sveltekit-2)).
- **Mechanical changes** (formatting, autofixes, dependency bumps, migrations) go in their own commits.
- **Generated code** is exempt: `.svelte-kit/`, the `$types` files, the `build/` output and any file that a tool writes.
- **Shared and team repositories:** when a repository documents its own conventions, follow those first, and apply these notes where it is silent.

### Decisions to review

These choices were made while writing the notes, because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Why | Where to change it |
| --- | --- | --- |
| `adapter-node` behind nginx as the default deployment | It fits the single-server model of the infrastructure notes. `adapter-auto` cannot detect a self-hosted server, and the platform adapters tie the app to a vendor. | [deployment and adapters](10-deployment-and-adapters.md#choosing-an-adapter) |
| Explicit `./$types` imports on every load function and action | The editor and `svelte-check` infer these types, but the typed lint rules see `any`. | [TypeScript in SvelteKit](11-typescript-in-sveltekit.md#generated-types) |
| No remote functions | The documentation marks them experimental, with breaking changes allowed in any release, and they need `await` in components, which the Svelte notes avoid. | [forms and mutations](05-forms-and-mutations.md#remote-functions) |
| Component tests named `*.browser.test.ts`, as in the Svelte notes | `sv add vitest` writes `*.svelte.{test,spec}` for browser tests, which the Svelte notes use for tests that contain runes. Keeping one scheme across both sets avoids two meanings. | [testing](09-testing-and-quality-gates.md#tools) |
| End-to-end tests in `e2e/` | The TypeScript notes say `e2e/`, and `sv add playwright` puts the example next to a route. | [testing](09-testing-and-quality-gates.md#end-to-end-tests) |
| The `.prettierrc` of the Svelte notes, with no style options | `sv add prettier` writes tabs, single quotes and a 100-column width. The TypeScript notes use the Prettier defaults. | [setup](02-project-setup-and-tooling.md#formatting) |
| The typed ESLint presets of the TypeScript notes | `sv add eslint` writes the untyped `recommended` preset. | [setup](02-project-setup-and-tooling.md#linting) |
| `checkJs` off | `$app/tsconfig` turns it on. The TypeScript notes keep it off, and every source file is TypeScript. | [setup](02-project-setup-and-tooling.md#tsconfig) |

### Version policy

- **SvelteKit:** run 3.x. On 2026-11-18 the newest release is 3.3.1, and `sv create` writes `^3.2.0`. SvelteKit 3 needs Node.js 22.17 or later, TypeScript 6, Svelte 5.57.1 or later, Vite 8.0.12 or later and `@sveltejs/vite-plugin-svelte` 7.
- **Adapters:** every first-party adapter needs SvelteKit 3. On 2026-11-18 the newest are `@sveltejs/adapter-node` 6.0.4, `@sveltejs/adapter-static` 4.0.1 and `@sveltejs/adapter-auto` 8.0.1. Install the newest release of the one you use.
- **Node.js:** the runtime of the production server has the same major as the one in `.nvmrc` and `engines`, as the [TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#nodejs-and-type-packages) say.
- **Experimental options:** options in the `experimental` namespace, such as `remoteFunctions`, are not under semantic versioning. Do not turn one on without a written decision.
- **Upgrades:** move one tool at a time, in its own pull request, and read the release notes first. SvelteKit 2 reached 3.0 with many removals, so run its migration command before anything else.

### Working with coding agents

- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/sveltekit.md](../agent-rules/rules/sveltekit.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** the rule has a `paths` field. Claude Code loads it when a session reads, writes or edits a file under `src/routes`, a hooks file, `src/env.ts`, `src/params.ts`, `src/app.d.ts` or `src/app.html`. It loads next to `svelte.md` and `typescript.md`, and does not replace them. Start the session inside the repository, and in a new repository tell the agent to read `~/.claude/rules/sveltekit.md` before it writes the first route.
- A project whose agents must follow these notes on other machines names this folder in its own `AGENTS.md`.
- Tell agents to run `npm run check`, `npm run lint` and `npm test` before they report SvelteKit changes as done, to read the installed `@sveltejs/kit` version before they use an API, and to look the API up in the documentation of that version. SvelteKit 3 renamed or removed many modules, so training data about SvelteKit 2 is often wrong.

## Sources and raw notes

Pages read on 2026-11-18 unless a bullet says otherwise:

- npm registry on 2026-11-18: `@sveltejs/kit` 3.3.1, `sv` 1.5.0, `svelte` 5.58.0, `vite` 8.3.8, `@sveltejs/vite-plugin-svelte` 7.3.1, `vitest` 5.1.1, `@sveltejs/adapter-node` 6.0.4, `@sveltejs/adapter-static` 4.0.1, `@sveltejs/adapter-auto` 8.0.1, `@sveltejs/enhanced-img` 1.0.1.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): the requirements, and every removed, renamed and changed API. The notes cite it throughout.
- [SvelteKit documentation](https://svelte.dev/docs/kit): the pages on project structure, configuration, routing, loading data, form actions, page options, state management, hooks, errors, authentication, environment variables, server-only modules, adapters, `adapter-node`, `adapter-static`, link options, advanced routing, images, SEO, performance and remote functions. The pages are cited in the notes that use them.
- `sv` 1.5.0: `npx sv create <name> --template minimal --types ts` wrote `@sveltejs/kit ^3.2.0`, `svelte ^5.57.3`, `vite ^8.3.8`, `typescript ^6.0.3`, `@sveltejs/adapter-auto ^8.0.1`, a `vite.config.ts` with the `sveltekit()` plugin and no `svelte.config.js`, and `"imports": { "#lib": ..., "#lib/*": ... }` in `package.json`. `sv add eslint prettier vitest playwright` added the configurations that the setup note compares.
- The sample application that checks these notes: scaffolded with `sv` 1.5.0, with `@sveltejs/kit` 3.3.1, `@sveltejs/adapter-node`, Svelte 5.58.0, Zod 4.6.7, TypeScript 6.0.3, ESLint 10.15.0, typescript-eslint 8.73.0, eslint-plugin-svelte 3.24.1, Prettier 3.10.1 and Vitest 5.1.1. Each note says which of its examples ran there.
