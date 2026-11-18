---
paths:
  - "**/*.svelte"
  - "*.svelte"
  - "**/*.svelte.ts"
  - "*.svelte.ts"
  - "**/*.svelte.js"
  - "*.svelte.js"
  - "**/svelte.config.js"
  - "svelte.config.js"
---
# Svelte conventions (Svelte 5, plain Vite apps)

Write idiomatic Svelte 5 in runes mode. Follow the compiler, `svelte-check` and the official Svelte documentation instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `svelte-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. It loads next to `typescript.md` and never replaces it. The digest was synced with the notes on 2026-11-18; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatting, autofixes, dependency bumps, `sv migrate` runs) in their own commits.
- When sources disagree, the order is: the Svelte compiler and official documentation; this file and the notes; `svelte-check`, `eslint-plugin-svelte` and the typescript-eslint presets; the TypeScript notes for every question about TypeScript itself.
- Svelte's required shape overrides the TypeScript notes in three places: a `.svelte` file is a default export, a component's props type is a local `Props` interface, and shared reactive state is a class.
- If the repository documents its own conventions, follow them first. Generated files are exempt, such as the folder that Wails writes for Go bindings.
- SvelteKit has its own notes (`sveltekit-conventions`, when it exists). This file covers a plain Vite app, such as a Wails frontend, which has no server rendering.
- Before you report Svelte changes as done, run `npm run check`, `npm run lint` and `npm test`. Before you use a newer feature, read the version: `node -p "require('svelte/package.json').version"`.

## Setup and tooling

- Create a project with `npm create vite@latest <name> -- --template svelte-ts`. `npx sv create` makes a SvelteKit project, so do not use it here. Add `lang="ts"` to the template's `App.svelte`, replace the `!` in `main.ts` with a guard, and run Prettier once in its own commit.
- `svelte.config.js` forces runes mode: `export default { compilerOptions: { runes: true } };`. If a dependency ships Svelte 4 components, use `runes: ({ filename }) => (filename.includes("node_modules") ? undefined : true)`. Do not use `dynamicCompileOptions`: `svelte-check` ignores it. No `vitePreprocess` for TypeScript, and no `experimental.async`.
- `tsconfig.app.json` extends `@tsconfig/svelte/tsconfig.json` (it sets `verbatimModuleSyntax`, `strict`, `bundler` resolution) and adds `"paths": { "@/*": ["./src/*"] }` and the options that the TypeScript notes require: `noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns`, `noFallthroughCasesInSwitch` and `erasableSyntaxOnly`. `verbatimModuleSyntax` comes from the base. Remove `allowJs`, `checkJs` and (in `tsconfig.node.json`) `noUnusedLocals` and `noUnusedParameters`. Vite reads the `paths` alias from the tsconfig, so `vite.config.ts` needs no alias setting.
- Scripts: `check` is `svelte-check --tsconfig ./tsconfig.app.json --fail-on-warnings && tsc -p tsconfig.node.json`, `lint` is `eslint`, `format:check` is `prettier --check .`, `test` is `vitest run`, `build` is `vite build`, and `ci` runs them in that order. CI calls `npm run ci` only.
- ESLint flat config: `js.configs.recommended`, then typescript-eslint `recommendedTypeChecked` and `stylisticTypeChecked` with `projectService` and `extraFileExtensions: [".svelte"]` for `**/*.{ts,svelte}` and `no-non-null-assertion` as an error, then `svelte.configs.recommended`, a block for `**/*.svelte` and `**/*.svelte.ts` with `parser: tseslint.parser` and `svelteConfig`, and `eslint-config-prettier/flat` and `svelte.configs.prettier` last.
- Prettier 3 with `prettier-plugin-svelte` 4: the only config is `.prettierrc` with `"plugins": ["prettier-plugin-svelte"]` and `"overrides": [{ "files": "*.svelte", "options": { "parser": "svelte" } }]`. Set no style option. List the Tailwind plugin last, if the project uses it.
- The linter infers a snippet parameter and a function-binding setter as `any`. Annotate them: `{#snippet actions(item: Loan)}`, `(next: string) => (first = next)`.
- Use `<!-- svelte-ignore code (reason) -->` only for a false positive, and always give the reason.

## Layout and naming

- Group by feature under `src/lib/<feature>/` (component, `.svelte.ts` state, types, tests side by side). Shared components go in `src/lib/ui/`, other shared code in `src/lib/shared/` after a second feature needs it. No `index.ts` barrels.
- Files are kebab-case: `loan-row.svelte`, `loan-list.svelte.ts`. Components are UpperCamelCase where imported. Use `.svelte.ts` only for a module that uses a rune. A component and a `.svelte.ts` module never share a base name in a folder.
- Import a component as a default import with its extension: `import LoanRow from "./loan-row.svelte"`. Import `.ts` and `.svelte.ts` modules without the extension (`./loan-list.svelte`); a `.ts` extension is an error. Use `import type` for types. Same folder `./x`, one up `../x`, further through `@/`; never `../../..`.
- Named exports in modules. Default exports only for `svelte.config.js`, `vite.config.ts` and `.svelte` files. `<script module>` holds shared constants and plain functions, never `$state`.
- Order in a component: `<script module>`, `<script lang="ts">`, markup, `<style>`. In the script: imports, `Props`, `$props()`, constants, `$state`, `$derived`, functions, `$effect`.
- Name a boolean like a question, a snippet by what it renders (`header`, `row`), an attachment function by what it does (`autofocus()`), and a state class after its subject (`LoanList`, never `LoanListStore`).

## Runes and reactivity

- `$state` only for values that must update the UI. Mutate deep state in place. `$state.raw` for large data that you replace whole. A class instance is not proxied, so put `$state` on its fields. Type an empty state: `$state<Loan[]>([])`, `$state<string>()` (is `string | undefined`).
- Do not destructure state that must stay reactive. Pass a getter (`() => count`) when a function must read the current value later. `$state.snapshot` before `structuredClone` or a library call. Do not `console.log` a proxy; use `$inspect` (development only, remove before commit).
- A plain `Map`, `Set`, `Date`, `URL` or `URLSearchParams` in state is not reactive: use `SvelteMap`, `SvelteSet`, `SvelteDate`, `SvelteURL` or `SvelteURLSearchParams` from `svelte/reactivity`. `MediaQuery` and `createSubscriber` live there too.
- Everything computed from state is `$derived` (`$derived.by` for several statements). No side effects in it. Never mirror state with `$effect` (`svelte/prefer-writable-derived`). A derived can be assigned (5.25), which resets when its dependencies change.
- `$effect` is an escape hatch for the outside world (third-party library, canvas, `document.title`, analytics, subscription) and runs only in the browser. Do not set state in it to sync. Return a cleanup. Reads after `await` or in `setTimeout` are not tracked. `untrack` only as a last resort, with a comment. Use an attachment instead of `bind:this` plus an effect. `$effect.pre` and `$effect.root` are rare. `onMount` is fine for one-time setup that reads no state. `beforeUpdate` and `afterUpdate` do not exist in runes mode.
- A `.svelte.ts` module cannot export a reassigned `$state` variable. Export an object, a class instance, or functions.

## Components, props and snippets

- Props: a local `interface Props`, one `let { a, b = 1, ...rest }: Props = $props();`, defaults in the pattern, `?` for optional (never `| undefined`). Do not mutate a prop and do not copy a prop into `$state` (`state_referenced_locally`): derive a draft with `let draft = $derived(value)`, or key the component with `{#key id}`.
- Wrap an element by extending its type from `svelte/elements` (`HTMLButtonAttributes`, `HTMLInputAttributes`; `SvelteHTMLElements["section"]` for others; `Omit<…, "value">` to redefine one) and spread `...rest` onto it. Type a class prop as `ClassValue`. Make ids with `$props.id()`.
- Report changes with callback props named `onSomething` (`onSelect`), implemented by `handleSomething`, passing data, not events. A prop that mirrors a DOM event keeps the lowercase name (`onclick`). No `createEventDispatcher`, no `async` function in a callback prop, no `CustomEvent`.
- `$bindable` only when the component exists to edit a value (inputs, toggles). A bound prop with a fallback needs a parent value other than `undefined`. Never bind a whole object so a child edits its fields.
- Content: `children` plus named snippets. `{@render children?.()}`; `Snippet` or `Snippet<[Loan]>` types. Snippets replace slots and `let:`. No `<slot>`, no `<svelte:component>` (write `<Thing />`, type `Component<Props>`). Use a snippet for reuse or a name, otherwise write the markup inline.
- Compose, never inherit. Mount with `mount(App, { target })`, never `new App()`. Generic components use `<script lang="ts" generics="Item extends { id: string }">`.

## Events, bindings and attachments

- Events are attributes in lowercase: `onclick`, `oninput`, `onsubmit`. No `on:`, no modifiers: call `event.preventDefault()` in the handler. One handler per event per element. Type an extracted handler by event and `currentTarget` (`SubmitEvent & { currentTarget: EventTarget & HTMLFormElement }`); inline handlers need no type.
- Listen to the window with `<svelte:window onkeydown={…} />`, not `addEventListener` in an effect. For manual listeners use `on` from `svelte/events`. Manually dispatched events need `{ bubbles: true }`.
- Use `<button>` and `<a href>`, never `onclick` on a `div`.
- `bind:value`, `bind:checked`, `bind:group` for form controls. `bind:this` with `$state<HTMLInputElement>()` and `input?.focus()` (never `!`). Readonly sizes: `bind:clientWidth={width}`. Use a function binding `bind:value={() => format(first), (next: string) => (first = next)}` (5.9) to validate or transform, not an effect.
- Behaviour on one element is an attachment (5.29): a function that returns `Attachment<HTMLElement>` from `svelte/attachments`, used as `{@attach autofocus()}`. Put third-party libraries in attachments and clean up in the returned function. Attachments pass through components that spread `...rest`. Use `fromAction` for old actions. Write no new `use:` action.
- Forms: `<form onsubmit>` with a submit button. Read `new FormData(event.currentTarget)`, assign to `unknown`, validate with Zod `safeParse`, return `z.flattenError(error).fieldErrors`, mark fields with `aria-invalid` and show errors in `role="alert"`.

## State sharing

- Scope in order: props, then context, then a module-level instance. Do not move up a level until passing props gets worse.
- Shared reactive state is a class in `.svelte.ts` with `$state`, `$state.raw` and `$derived` fields. This extends the TypeScript class rule on purpose; its other rules hold (no parameter properties, `readonly`, `override`, no deep inheritance). Write methods that you pass as callbacks as arrow-function fields.
- Context: `export const [getLoanList, setLoanList] = createContext<LoanList>();` (5.40) next to the class. Call `set` in the parent during initialisation, create the instance there, and mutate its properties. `get` throws without a provider. Module-level instances only for client-only app singletons, never mutated on a server. Test context with a wrapper component.
- No new `writable`, `readable` or `derived` stores. Keep existing ones until you rewrite their code. Stores remain fine for complex async streams, manual control and RxJS.

## Templates, styling and accessibility

- Every `{#each}` has a key from a stable unique id, never the index, plus `{:else}` when it can be empty. Keep expressions short: move logic into `$derived` or a function. Use `{#key}` to reset a subtree.
- Write non-void elements in full (`<div></div>`). `{@html}` only for trusted or sanitised HTML, with a comment about its origin (`svelte/no-at-html-tags`).
- Scoped `<style>` per component. Set classes with `class={["row", { selected }]}` (5.16); no `class:` directive. `style:width={…}` for one dynamic property. Global styles and `:root` custom properties in `src/app.css`. `:global(...)` only for markup you do not control, preferably nested (`.content :global { a { } }`). Pass per-instance values as `--custom-property` attributes. Delete unused selectors. Scoped CSS and custom properties come before Tailwind, which needs a written reason.
- Accessibility: semantic elements, `alt` on every image, a `<label>` on every control, no positive `tabindex`, no `autofocus` attribute, captions on video. `--fail-on-warnings` makes every `a11y_*` warning fail CI; never disable it in `warningFilter`. Test new screens with the keyboard.

## Errors and async

- Follow the TypeScript error rules. Catch request errors in the function that makes the request and turn them into state. Model a request as a discriminated union. Call async functions from event attributes through `void`: `onclick={() => void save()}`. Never render the `message` of an unexpected error.
- Wrap risky parts in `<svelte:boundary>` with `failed(error, reset)` and `onerror`, and add one near the root. A boundary does not catch errors in event handlers, timers or async code. Use the `error` argument of `failed`, for example through a `userMessage(error)` helper.
- Fetch in a handler or in the module that owns the data, never in `$derived`. An effect that fetches cancels the previous request with an `AbortController` and gives every request `AbortSignal.timeout`.
- Do not use `await` in a component, `$derived` or markup, and do not set `experimental.async`: it is experimental, and the flag is removed in Svelte 6. That includes `fork()`, `settled()` and `$state.eager`.

## Testing

- Vitest only, `globals` off, two projects in `vite.config.ts` with `extends: true`: `unit` (node, `src/**/*.test.ts`, excluding `*.browser.test.ts`) and `component` (`src/**/*.browser.test.ts`, browser mode with `playwright()` and `instances: [{ browser: "chromium" }]`). Install `vitest vitest-browser-svelte @vitest/browser-playwright playwright`, then `npx playwright install chromium`. Browser mode is Vitest's recommended way for components; jsdom with Testing Library only where a browser cannot run, with a recorded reason.
- Name a test after its file. Use `name.svelte.test.ts` when the test itself uses a rune. Extract logic from components and test it without a component first. Create fresh instances per test, call `flushSync()` before asserting on derived values or effects, and wrap effect tests in `$effect.root`.
- Component tests: `render` from `vitest-browser-svelte`, query by role and name (`getByRole`), act through locators, assert on what a user sees and on callback props. Use a wrapper component for context, bindings and snippet props. Mock only boundaries (network, clock, Go bindings), never a child component. Playwright covers end-to-end tests against `vite preview`.
- All TypeScript test rules apply: typed fixtures with `Partial<T>`, no `any`, assert errors by class and data, restore fake timers.

## TypeScript in Svelte

- Every `<script>` and `<script module>` has `lang="ts"`. Svelte only strips types, so use no `enum`, parameter properties or other non-erasable syntax. `import type` for types. The TypeScript notes apply in full: `unknown` for external data, no `any`, no `as` to silence the compiler, no `!`, discriminated unions.
- Type `$state` by argument when it starts empty. Type `bind:this` by element (`$state<HTMLInputElement>()`) or by component name (`$state<DocTitle>()`). `Component<Props>` for a component-valued prop, `ComponentProps<typeof Button>` for props of an existing component. Never `SvelteComponent` or `ComponentType`.
- Treat the replies of Go bindings, fetch results, `FormData` and storage as `unknown` until a schema parses them; use `z.infer` for the prop type.
- Augment `svelte/elements` in a `.d.ts` with `export {}` for custom attributes. Keep `svelte` and `vite/client` in `types`. Add no `declare module "*.svelte"`.

## Modern Svelte

- Replace Svelte 4 forms when you change a line: `let` and `$:` to `$state` and `$derived`, `export let` and `$$props` to `$props()`, `on:click` to `onclick`, `createEventDispatcher` to callback props, slots and `let:` to snippets, `<svelte:component>` to `<Thing />`, `class:` to the `class` object form, `use:` to `{@attach}`, stores to `.svelte.ts` classes, `setContext` keys to `createContext`, `beforeUpdate` and `afterUpdate` to effects, `new App()` to `mount`.
- Feature versions: boundary 5.3, exported snippets 5.5, function bindings 5.9, `class` objects 5.16, `$props.id()` 5.20, attachments 5.29, `createContext` 5.40. The newest release on 2026-11-18 is 5.58.0. Set the `svelte` range to a version that has every feature in use.
- Migrate an old project one component per change: add `<svelte:options runes />` to each converted component, and set `compilerOptions.runes: true` after the last one. `npx sv migrate svelte-5` is a legacy, unmaintained migration: commit first, review the diff and search for `@migration-task`.
- Upgrade tools one at a time in their own pull request. A new compiler warning fails `svelte-check --fail-on-warnings`.
