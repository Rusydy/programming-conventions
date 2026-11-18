# Modern Svelte by Release

## Summary

Write the Svelte 5 idiom, and replace the Svelte 4 form of a line when you change it. Svelte 5 is still moving, with a new feature in many minor releases, so check the installed version before you use one. Convert an old project one component at a time, and turn on project-wide runes mode when the last component is converted.

## Rules

### Release timeline

This table lists the Svelte 5 releases that matter for the idioms in these notes. A feature needs the version in its row, so set the `svelte` range of the project to a version that has every feature the code uses. The newest release on 2026-11-18 is 5.58.0.

| Release | What it added | Where these notes use it |
| --- | --- | --- |
| 5.0 | Runes, snippets, event attributes, `mount` | Everything |
| 5.3 | `<svelte:boundary>` | [Errors](09-errors-and-async.md#error-boundaries) |
| 5.5 | Exporting snippets from `<script module>` | [Snippets](05-components-props-and-snippets.md#snippets) |
| 5.7 | `MediaQuery` and `createSubscriber` in `svelte/reactivity` | [Runes](04-runes-and-reactivity.md#reactive-built-ins) |
| 5.9 | Function bindings, `bind:value={get, set}` | [Bindings](06-events-bindings-and-attachments.md#bindings) |
| 5.14 | `$inspect.trace()` | [Debugging](04-runes-and-reactivity.md#debugging) |
| 5.16 | The `class` attribute with objects and arrays | [Styling](08-templates-styling-and-accessibility.md#styling) |
| 5.19 | The `ClassValue` type | [TypeScript](11-typescript-in-svelte.md#wrapper-components) |
| 5.20 | `$props.id()` | [Props](05-components-props-and-snippets.md#props) |
| 5.25 | A derived value can be assigned | [Runes](04-runes-and-reactivity.md#derived) |
| 5.29 | Attachments, `{@attach}` | [Attachments](06-events-bindings-and-attachments.md#attachments) |
| 5.32 | `fromAction` | [Attachments](06-events-bindings-and-attachments.md#attachments) |
| 5.36 | `await` expressions (experimental), `settled()` | [Async](09-errors-and-async.md#async-in-components) |
| 5.40 | `createContext` | [Context](07-state-sharing-and-context.md#context) |
| 5.41 | `$state.eager` | [Runes](04-runes-and-reactivity.md#state) |
| 5.42 | `fork()` (experimental) | Not used |
| 5.53 | Error boundaries work on the server | [Errors](09-errors-and-async.md#error-boundaries) |
| 5.54 | The `css`, `runes` and `customElement` compiler options can be functions | [Setup](02-project-setup-and-tooling.md#svelte-configuration) |
| 5.57 | `has` in the `createContext` triplet, `getOrInsert` on `SvelteMap` | [Context](07-state-sharing-and-context.md#context) |

### Idioms to replace

Replace the old form in the lines you change. Leave the rest of the file alone, as the [principles note](01-principles-and-sources.md#applying-the-notes) says.

| Old idiom (Svelte 3 and 4) | Modern idiom |
| --- | --- |
| `let count = 0` that the template reads and the code reassigns | `let count = $state(0)` |
| `$: doubled = count * 2` | `const doubled = $derived(count * 2)` |
| `$: { document.title = title }` | `$effect(() => { document.title = title; })`, and only if nothing else fits |
| `export let name` | `let { name } = $props()` |
| `$$props`, `$$restProps` | A rest element: `let { a, ...rest } = $props()` |
| `on:click={handler}` | `onclick={handler}` |
| `on:click\|preventDefault={handler}` | `onclick` with `event.preventDefault()` in the handler |
| `createEventDispatcher` and `on:select` | A callback prop, `onSelect` |
| `<slot />` and `<slot name="header" />` | `{@render children?.()}` and `{@render header?.()}` |
| `let:item` on a slot | A snippet parameter: `{#snippet row(item)}` |
| `<svelte:component this={Thing} />` | `<Thing />` |
| `class:active={isActive}` | `class={{ active: isActive }}` |
| `use:tooltip={text}` | `{@attach tooltip(text)}` |
| `writable`, `readable`, `derived` stores | A class or object with `$state` in a `.svelte.ts` file |
| `setContext("key", value)` and `getContext("key")` | `createContext<T>()` |
| `beforeUpdate` and `afterUpdate` | `$effect.pre` and `$effect` |
| `new App({ target })` | `mount(App, { target })` |
| `SvelteComponent` and `ComponentType` types | `Component<Props>` |
| A `bind:this` and an effect that sets up an element | An attachment |
| `<div />` and other self-closing non-void tags | `<div></div>` |
| `{#each items as item}` with no key | `{#each items as item (item.id)}` |
| `vitePreprocess` for TypeScript | Nothing: Svelte 5 removes types itself |

### Migrating an existing project

- Svelte 3 and 4 syntax still works in Svelte 5, and the components that use it run in legacy mode. The documentation calls the legacy features deprecated and says they will be removed later.
- A component is in runes mode as soon as it uses a rune, and it cannot then use the legacy features. Add `<svelte:options runes />` to a component to force runes mode for it. The compiler then rejects `export let`, which the sample project confirmed.
- Update `svelte`, `@sveltejs/vite-plugin-svelte`, `svelte-check`, `eslint-plugin-svelte` and `prettier-plugin-svelte` in one change, and fix what breaks in that change. Do not mix the dependency change with a rewrite.
- `npx sv migrate svelte-5` converts Svelte 4 syntax. It is a legacy migration that runs the unmaintained `svelte-migrate@1` package. Commit first, run it on a branch, review its whole diff, run `npm run ci`, and search the project for the `@migration-task` marker that flags places that need manual work.
- Convert one component per change, starting with the leaves of the component tree. Write `<svelte:options runes />` in each converted component, so that a later edit cannot bring the old syntax back.
- Set `compilerOptions.runes: true` in `svelte.config.js` when the last component is converted, and remove the per-component options ([setup](02-project-setup-and-tooling.md#svelte-configuration)).
- `npx sv migrate self-closing-tags` replaces self-closing tags on non-void elements. Run it in its own commit.
- Keep a store that a library returns, and replace your own stores when a change rewrites the code that uses them ([stores](07-state-sharing-and-context.md#stores)).

### Upgrading

- Move one Svelte minor version at a time in its own pull request when you are more than a few releases behind, and read the changelog entries for each. A minor release adds features and warnings, and a new warning fails `svelte-check --fail-on-warnings`.
- Read the installed version before you use a newer feature: `node -p "require('svelte/package.json').version"`. The editor's quick-fix list and the documentation show the newest API, which an older install may lack.
- A feature marked experimental, such as `await` in components and `fork()`, may change in a minor release. Do not use one without a written decision ([async](09-errors-and-async.md#async-in-components)).
- Svelte 6 is not released at the date of these notes. The documentation names it as the release that removes the `experimental.async` flag. Read its migration guide when it ships, and revise [project setup](02-project-setup-and-tooling.md) and [errors and async](09-errors-and-async.md) in the same change.

## Sources and raw notes

Pages read on 2026-11-18:

- [Svelte changelog](https://github.com/sveltejs/svelte/blob/main/packages/svelte/CHANGELOG.md): the entries for 5.40 to 5.58 (`createContext` 5.40, `$state.eager` 5.41, `fork` 5.42, error boundaries on the server 5.53, function options 5.54, `has` 5.57, 5.58.0 newest).
- Version tags from the reference pages: [`<svelte:boundary>`](https://svelte.dev/docs/svelte/svelte-boundary) 5.3.0, [snippets](https://svelte.dev/docs/svelte/snippet) 5.5.0, [`svelte/reactivity`](https://svelte.dev/docs/svelte/svelte-reactivity) `MediaQuery` and `createSubscriber` 5.7.0, [`bind`](https://svelte.dev/docs/svelte/bind) function bindings 5.9.0, [`$inspect`](https://svelte.dev/docs/svelte/$inspect) `trace` 5.14, [`class`](https://svelte.dev/docs/svelte/class) 5.16 and `ClassValue` 5.19, [`$props`](https://svelte.dev/docs/svelte/$props) `$props.id()` 5.20.0, [`$effect`](https://svelte.dev/docs/svelte/$effect) deriveds overridable 5.25, [`{@attach}`](https://svelte.dev/docs/svelte/@attach) 5.29, [await expressions](https://svelte.dev/docs/svelte/await-expressions) 5.36 and `fork` 5.42.
- [Migration guide](https://svelte.dev/docs/svelte/v5-migration-guide): the old and new forms in the table above. [Legacy overview](https://svelte.dev/docs/svelte/legacy-overview): legacy mode and the plan to remove it. [Lifecycle hooks](https://svelte.dev/docs/svelte/lifecycle-hooks): `beforeUpdate` and `afterUpdate`.
- [sv migrate](https://svelte.dev/docs/cli/sv-migrate): the `svelte-5` and `self-closing-tags` migrations are legacy ones that run `svelte-migrate@1`, which is no longer updated, the advice to commit first and review the diff, and the `@migration-task` marker. [Compiler warnings](https://svelte.dev/docs/svelte/compiler-warnings): `npx sv migrate self-closing-tags`.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): with no project-wide runes option, a component with `<svelte:options runes />` and `export let` gave `legacy_export_invalid`, and the same component without the option gave no error. `svelte@5.58.0` types: `createContext` returns the triplet with `has`.
- `sv migrate svelte-5` was not run. The row for 5.7 rests on the `svelte/reactivity` page, and the dates of the releases were not read.
