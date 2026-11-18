# Svelte Principles and Sources of Truth

## Summary

These principles apply to every Svelte 5 project that is not a SvelteKit application, such as a Vite single-page app or the frontend of a Wails desktop app. They put the Svelte compiler, `svelte-check` and the official Svelte documentation ahead of local configuration, so that any Svelte developer can read the code on the first day. The set adds to [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) and never replaces it. SvelteKit has its own folder, which will build on this one.

## Rules

### Principles

1. **Write runes mode only.** Use `$state`, `$derived`, `$props` and `{@render}`. Do not write `export let`, `$:`, `on:click`, `<slot>`, `createEventDispatcher` or `<svelte:component>` in new code. The project turns on `compilerOptions.runes`, so the compiler rejects them ([project setup](02-project-setup-and-tooling.md#svelte-configuration), [modern Svelte by release](12-modern-svelte-by-release.md#idioms-to-replace)).
2. **Derive, do not synchronise.** Compute a value with `$derived`. An `$effect` is the last resort for talking to the outside world, never for copying state into other state ([runes and reactivity](04-runes-and-reactivity.md#effect)).
3. **Follow the toolchain.** The compiler warnings, `svelte-check`, `eslint-plugin-svelte` and the Prettier plugin define the baseline. Replace a default only with a written reason. This is convention over configuration applied to Svelte.
4. **Pass data down and events up.** A parent gives a child props. A child tells its parent through callback props. Use `bind:` only where a form control or `$bindable` makes two-way flow the clearer choice ([components](05-components-props-and-snippets.md), [events and bindings](06-events-bindings-and-attachments.md)).
5. **Compose with snippets and `children`.** A component accepts content through snippets, and it never inherits from another component.
6. **Keep one component per concern.** A `.svelte` file has one job. Move logic that has no markup into a `.svelte.ts` module or a plain `.ts` file, and test it there ([project layout](03-project-layout-and-naming.md#where-code-lives)).
7. **Use the platform first.** Use HTML elements, CSS, the `svelte/reactivity` classes and the browser APIs before a package. Add a dependency only when it removes real complexity.
8. **Make it accessible by default.** Use a real `<button>`, `<a>` and `<label>`. The compiler's `a11y_*` warnings are errors in CI ([accessibility](08-templates-styling-and-accessibility.md#accessibility)).
9. **Wait for a second use case.** Do not add a context, a store, a generic component or a prop "just in case".
10. **Follow the TypeScript notes.** Every `<script>` has `lang="ts"`, and every rule of [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) applies inside it, except where [the rule on precedence](#order-of-precedence) names an exception.

### Order of precedence

When two sources disagree, the lower number wins.

1. The behaviour of the Svelte compiler and runtime, and the official Svelte documentation and release notes.
2. The notes in this folder.
3. The `svelte-check` diagnostics, and the `eslint-plugin-svelte` and typescript-eslint presets that the notes name.
4. [typescript-conventions](../typescript-conventions/01-principles-and-sources.md), for every question about TypeScript itself.
5. Other style guides. Adopt one of their rules only when a note in this folder names it.

Svelte's required shape overrides the TypeScript notes for the code that Svelte dictates. There are three cases, and each one is recorded in the note that uses it:

- A `.svelte` file is a default export, so a component is imported as a default import, and the TypeScript rule for named exports does not apply to it ([project layout](03-project-layout-and-naming.md#exports-and-imports)).
- A component reads its props from `$props()`, so its props type is a local `Props` interface, not an interface named after the component ([components](05-components-props-and-snippets.md#props)).
- A reactive state container is a class, because `$state` and `$derived` fields work on class fields ([state sharing](07-state-sharing-and-context.md#state-in-a-class)).

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so each review stays small, and raise the rest as a separate task.
- **Svelte 4 syntax:** a component written with `export let` or `$:` is converted when you change its logic, not when you only touch its styles. Convert one component per change ([modern Svelte by release](12-modern-svelte-by-release.md#migrating-an-existing-project)).
- **Stricter settings:** adopt a compiler option or a lint rule in its own change, with its errors fixed or suppressed in that change.
- **Mechanical changes** (formatting, autofixes, dependency bumps, `sv migrate` runs) go in their own commits.
- **Generated code** is exempt: the folder that Wails writes for its Go bindings, and any file that a tool writes.
- **Shared and team repositories:** when a repository documents its own conventions, follow those first, and apply these notes to the code you write where the repository is silent.
- **Wails and other desktop shells:** the frontend is a client-only Vite project, so there is no server rendering. Every rule here applies, and the notes about server-side state sharing do not.

### Decisions to review

These choices were made while writing the notes, because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Why | Where to change it |
| --- | --- | --- |
| `compilerOptions.runes: true` for the whole project | It makes the compiler reject Svelte 4 syntax, so new code cannot drift. It also applies to dependencies in `node_modules`. The Svelte documentation offers `dynamicCompileOptions` to skip them, but only the build applies it, so the setup note uses the function form of `runes` (5.54) instead. | [project setup](02-project-setup-and-tooling.md#svelte-configuration) |
| kebab-case file names for components (`loan-row.svelte`) | The TypeScript notes use kebab-case for every file, and macOS and Windows file systems ignore case. The Svelte documentation and the `create-vite` template use UpperCamelCase (`Counter.svelte`). The import still names the component in UpperCamelCase, so the markup reads the same. | [naming](03-project-layout-and-naming.md#naming) |
| The `@/` alias for `src/` | The TypeScript notes use `@/` for anything further than one folder away. SvelteKit fixes its alias as `$lib`, and its notes will use that. | [imports](03-project-layout-and-naming.md#exports-and-imports) |
| Local interface named `Props` | The Svelte documentation and `sv` templates use it. The React note names the interface after the component, which a `.svelte` file cannot export without `<script module>`. | [components](05-components-props-and-snippets.md#props) |
| Callback props in `onSomething` camel case (`onSelect`) | It follows the TypeScript notes. A callback that mirrors a DOM event and spreads onto an element keeps the lowercase DOM name (`onclick`). | [components](05-components-props-and-snippets.md#callback-props) |
| Reactive state in classes | The TypeScript notes allow a class only for an `Error` or an object that owns a resource. `$state` only works as a class field or a variable, and the Svelte documentation shows classes for shared state. The other class rules of the TypeScript notes still apply. | [state sharing](07-state-sharing-and-context.md#state-in-a-class) |
| Vitest Browser Mode with `vitest-browser-svelte` for component tests | Vitest calls Browser Mode the recommended approach for component tests. The Svelte documentation shows jsdom with Testing Library. The browser needs a Playwright browser installed. | [testing](10-testing.md#tools) |
| No `await` in components and no `experimental.async` | The documentation marks the feature experimental, with the flag to be removed in Svelte 6. | [errors and async](09-errors-and-async.md#async-in-components) |
| A minimal `.prettierrc` that loads the Svelte plugin | The TypeScript notes use Prettier with no config file. Prettier 3 does not load plugins by itself, so the plugin and the parser override are the only entries, and no style option is set. | [formatting](02-project-setup-and-tooling.md#formatting) |

### Version policy

- **Svelte:** run the newest 5.x release, declared as `"svelte": "^5.58.0"` or the newest minor on the day you start. Svelte follows semantic versioning, and a minor release adds features without breaking runes mode. On 2026-11-18 the newest release is 5.58.0.
- **Features by minimum version:** this set uses `$props.id()` (5.20), `{@attach}` (5.29), `createContext` (5.40) and the class attribute with objects and arrays (5.16). Set the `svelte` range to a version that has every feature the code uses.
- **TypeScript:** follow the [TypeScript version policy](../typescript-conventions/01-principles-and-sources.md#version-policy). `create-vite` already declares `"typescript": "~6.0.3"`, and `svelte-check` and typescript-eslint work with it.
- **Vite:** run the version that `create-vite` writes. The notes were checked with Vite 8.3.8 and `@sveltejs/vite-plugin-svelte` 7.3.1.
- **Upgrades:** move one tool at a time, in its own pull request, and read its release notes first. [Modern Svelte by release](12-modern-svelte-by-release.md) lists the Svelte releases that matter.

### Working with coding agents

- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/svelte.md](../agent-rules/rules/svelte.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** the rule has a `paths` field, so Svelte rules stay out of sessions that never touch Svelte. Claude Code loads it when a session reads, writes or edits a `.svelte` file, a `.svelte.ts` or `.svelte.js` module, or `svelte.config.js`. The patterns match against the session's primary working directory, so start the session inside the Svelte repository. A brand-new repository has no Svelte file yet, so tell the agent to read `~/.claude/rules/svelte.md` before it writes the first one. The digest loads next to `typescript.md` and does not replace it.
- A project whose agents must follow these notes on other machines names this folder in its own `AGENTS.md`, because the user-level rule is installed per machine.
- Tell agents to run `npm run check`, `npm run lint` and `npm test` before they report Svelte changes as done, and to read the installed Svelte version before they use a newer feature. The official Svelte documentation also publishes agent skills and an MCP server, as the [AI page](https://svelte.dev/docs/ai/skills) describes. They can help an agent look up the documentation, and they do not override the notes.

## Sources and raw notes

Pages read on 2026-11-18 unless a bullet says otherwise:

- npm registry on 2026-11-18: `svelte` 5.58.0, `svelte-check` 4.7.8, `@sveltejs/vite-plugin-svelte` 7.3.1, `vite` 8.3.8, `eslint-plugin-svelte` 3.24.1, `prettier-plugin-svelte` 4.2.0, `prettier` 3.10.1, `vitest` 5.1.1, `vitest-browser-svelte` 3.1.0, `@tsconfig/svelte` 5.0.9, `eslint` 10.15.0, `typescript-eslint` 8.73.0, `@sveltejs/kit` 3.3.1, `sv` 1.5.0.
- [Svelte documentation](https://svelte.dev/docs/svelte): the overview pages for runes, the template syntax, the TypeScript page, the testing page and the migration guide. The pages are cited in the notes that use them.
- [Svelte changelog](https://github.com/sveltejs/svelte/blob/main/packages/svelte/CHANGELOG.md): the minor releases 5.40 to 5.58.
- [Svelte legacy overview](https://svelte.dev/docs/svelte/legacy-overview): Svelte 3 and 4 syntax still works in Svelte 5, is deprecated, and will be removed later.
- `create-vite` 9.3.4, template `svelte-ts`, run on 2026-11-18: it writes `svelte ^5.57.3`, `vite ^8.3.6`, `typescript ~6.0.3`, `svelte-check ^4.7.7` and `@sveltejs/vite-plugin-svelte ^7.3.1`. The template's `App.svelte` has a `<script>` tag without `lang="ts"`.
- The sample project that checks these notes: scaffolded with `create-vite` 9.3.4, with Svelte 5.58.0, TypeScript 6.0.3, ESLint 10.15.0, typescript-eslint 8.73.0, eslint-plugin-svelte 3.24.1, Prettier 3.10.1, prettier-plugin-svelte 4.2.0 and Vitest 5.1.1. Each note says which of its examples ran there.
