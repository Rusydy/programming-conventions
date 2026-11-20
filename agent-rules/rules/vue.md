---
paths:
  - "**/*.vue"
  - "*.vue"
---
# Vue conventions (Vue 3.5, plain Vite apps)

Write idiomatic Vue 3 with `<script setup lang="ts">`. Follow the compiler, `vue-tsc`, `eslint-plugin-vue` and the official Vue documentation and style guide instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `vue-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. It loads next to `typescript.md` and never replaces it. The digest was synced with the notes on 2026-11-20; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatting, autofixes, dependency bumps) in their own commits.
- When sources disagree, the order is: the Vue compiler, runtime and official documentation; this file and the notes; `vue-tsc`, `eslint-plugin-vue` and the typescript-eslint presets; the Vue style guide; the TypeScript notes for every question about TypeScript itself.
- Vue's required shape overrides the TypeScript notes in five places: a `.vue` file is a default export; a component's props type is a local `Props` interface; `defineEmits` takes a type literal; a template event handler may be `async`; `v-model` events are named `update:x`.
- If the repository documents its own conventions, follow them first. Generated files are exempt (`typed-router.d.ts`, `components.d.ts`, a generated API client).
- A Nuxt app has its own notes and digest (`nuxt.md`), which load next to this file. Follow this file for components, reactivity, composables and TypeScript, and `nuxt.md` for what Nuxt owns.
- A composable or a store is a plain `.ts` file and loads only `typescript.md`; read this file first when you change one.
- Before you report Vue changes as done, run `npm run check`, `npm run lint` and `npm test`. Before you use a newer feature, read the version: `node -p "require('vue/package.json').version"`.

## Setup and tooling

- Create a project with `npm create vue@latest` (TypeScript, Router if multi-page, Pinia if state is shared, Vitest, ESLint and Prettier; no Oxlint, JSX or end-to-end). Delete the demo content. Rename `App.vue` to `app.vue` through a temporary name (`git mv`), because macOS ignores case. In `main.ts` throw when `#app` is missing instead of using `!`.
- Use `@vitejs/plugin-vue` with defaults, the runtime-only `vue` build (no alias to the full build), and no `vite-plugin-vue-devtools` unless you write a reason.
- `tsconfig.app.json` extends `@vue/tsconfig/tsconfig.dom.json` (which sets `strict` and `verbatimModuleSyntax`) and adds the TypeScript options: `noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns`, `noFallthroughCasesInSwitch`, `erasableSyntaxOnly`, plus `"types": ["vite/client", "vitest/browser"]`, `"paths": { "@/*": ["./src/*"] }` and `"vueCompilerOptions": { "strictTemplates": true }`. `tsconfig.node.json` lists the options out and does not extend `@tsconfig/node24` (`module: preserve`, `moduleResolution: bundler`, `types: ["node"]`). Delete `tsconfig.vitest.json`; tests live in the app project. Keep the `@/` alias in `vite.config.ts` `resolve.alias` too.
- Scripts: `check` is `vue-tsc --build`, `lint` is `eslint --max-warnings 0` (`flat/recommended` mostly warns), `format:check` is `prettier --check .`, `test` is `vitest run`, `build` is `vite build`, and `ci` runs them in that order. CI calls `npm run ci` only. Drop `npm-run-all2`.
- ESLint flat config (`eslint.config.ts`, needs `jiti`): `defineConfigWithVueTs` from `@vue/eslint-config-typescript` with `js.configs.recommended`, `pluginVue.configs["flat/recommended"]`, `pluginA11y.configs["flat/recommended"]` (`eslint-plugin-vuejs-accessibility`), `vueTsConfigs.recommendedTypeChecked` and `stylisticTypeChecked`, `no-non-null-assertion` as an error, a `.vue` block with the rules below, and `eslint-config-prettier/flat` last. No `strict` presets and no Oxlint.
- Vue rules to switch on for `**/*.vue`: `block-lang` (`script: { lang: "ts" }`), `component-api-style` (`["script-setup"]`), `define-emits-declaration` (`type-literal`), `define-macros-order` (order `defineOptions`, `defineProps`, `defineEmits`, `defineModel`, `defineSlots`), `define-props-declaration` (`type-based`), `define-props-destructuring` (`always`), `enforce-style-attribute` (`allow: ["scoped"]`), `no-ref-object-reactivity-loss`, `no-required-prop-with-default`, `no-undef-components`, `no-unused-refs`, `no-v-html`, `prefer-define-options`, `prefer-use-template-ref`, `require-explicit-slots`, `require-typed-ref`; switch `require-default-prop` off. Set `vuejs-accessibility/label-has-for` to `required: { some: ["nesting", "id"] }`. Disable a rule only with a comment that gives the reason (`<!-- eslint-disable-next-line vue/rule -- reason -->`).
- Prettier 3 with defaults and no `.prettierrc` (delete the one `create-vue` writes, and `max_line_length` from `.editorconfig`); run it once after the scaffold, in its own commit. Tailwind's plugin, if used, is the one reason for a `.prettierrc`.
- Tests: Vitest in two projects in `vite.config.ts` (`unit` in Node for `src/**/*.test.ts`, `component` in Chromium through `@vitest/browser-playwright` for `src/**/*.browser.test.ts`, with `optimizeDeps: { include: ["vue"] }` on the project). Install `vitest-browser-vue`, `@vitest/browser-playwright`, `playwright`; remove `@vue/test-utils`, `jsdom`, `@vitest/eslint-plugin`. Install the browser with `npx playwright install chromium`.
- Editor: the Vue (Official) extension and the workspace TypeScript version; Prettier formats on save.

## Layout and naming

- Group by feature: `src/<feature>/` holds components, composables, store, types and tests side by side. `src/ui/` has base components, `src/shared/` has code that two features use, `src/router/index.ts` defines the router. Views end in `-view`. No `index.ts` barrels (`router/index.ts` is not one). Group by type (`components/`, `views/`) only while the project is a few screens.
- Files are kebab-case (`loan-row.vue`, `use-loan-list.ts`, `loan-store.ts`). Components are UpperCamelCase where used (`<LoanRow />`). Names have two or more words, except `app.vue`. Base components start `base-` (`base-button.vue`), single-instance ones `the-`, tightly coupled children start with the parent name (`loan-list-item.vue`), words run from general to specific, no abbreviations.
- Composables: `use-x.ts` exports `useX`. Stores: `x-store.ts` exports `useXStore` with id `"x"`. Props are camelCase in script and kebab-case in templates. Events are camelCase in `defineEmits` and `@kebab-case` in templates. Booleans read like questions. Handlers are `handleSelect`; emitted events are `select` and `rowSelect`, never `onSelect`.
- Import a component as a default import with its extension (`import LoanRow from "./loan-row.vue"`). Import `.ts` modules without the extension. `import type` for types. Same folder `./x`, one up `../x`, further through `@/`; never `../../..`. Named exports in modules; default exports only for `.vue` files and tool config.
- No auto-import plugins and no global registration. Import `RouterLink` and `RouterView` where you use them (`vue/no-undef-components`).
- Order in a component: `<script setup lang="ts">`, `<template>`, `<style scoped>`. In the script: imports, macros, constants, state, computed, functions, watchers, hooks. One `<script setup>`; use `defineOptions()` for `inheritAttrs`.

## Reactivity

- Declare state with `ref()` (the documented primary API); `reactive()` only for a fixed object that you never reassign or destructure. Type an empty ref: `ref<Loan[]>([])`, `ref<string>()`. Mutate deep state in place; replace the whole value for fresh server data. `shallowRef()` for large data that you replace whole (a nested change does not update). `markRaw()` for library objects. `Map` and `Set` in a ref are reactive.
- Do not destructure a `reactive` object (`const { n } = state` copies); use `toRef`/`toRefs`. Destructuring `defineProps()` is the exception. Only top-level refs unwrap in templates. `structuredClone` throws on a proxy; use `structuredClone(toRaw(x))`. `readonly()` for state that callers must not write.
- Everything derived is `computed()` with a pure getter (no side effects, no `await`). Prefer it to a template function call. Return primitives or stable values.
- `watch` and `watchEffect` are for side effects only (request, DOM, storage, analytics, library), never to copy state. Prefer `watch(() => x, cb)` with an explicit getter. `watchEffect` tracks only reads before the first `await`. Abort with `onWatcherCleanup()` (3.5), called before any `await`. `flush: "post"` to read the updated DOM. `once` (3.4) for one run. Do not use `deep` on large data.
- Call lifecycle hooks synchronously in setup or composables. `onMounted()` for DOM/browser access. Clean up in `onUnmounted()` (components) or `onScopeDispose()` (composables). No `onUpdated` for state changes.

## Components, props, emits, slots

- Props: `interface Props` and `const { loan, selected = false } = defineProps<Props>();`. `?` for optional, never `| undefined`. Destructured props are reactive (3.5); no `withDefaults()`, no `props.x`. Pass a destructured prop to a function as a getter (`watch(() => id, load)`, `useLoan(() => id)`). Never mutate a prop or copy it into mutable state; key the component (`:key="loan.id"`) to reset a draft. A prop with a default is optional.
- Wrap an element: `interface Props extends /* @vue-ignore */ ButtonHTMLAttributes`, fallthrough attributes reach the root; with several roots use `defineOptions({ inheritAttrs: false })` and `v-bind="$attrs"`. Ids from `useId()`.
- Emits: `defineEmits<{ select: [id: string]; remove: [] }>()`, named tuple elements, data not DOM events in arguments. Declare every event. An event announces, it does not ask.
- `defineModel<T>()` (3.4) for components that edit a value; declare it after `defineEmits`. Named models `defineModel("note")` with `v-model:note`. Modifiers via `const [model, modifiers] = defineModel()`. Never bind a whole object so a child edits its fields.
- Slots, not HTML props; declare them with `defineSlots<{ default(): unknown; row(props: { loan: Loan }): unknown }>()`. Scoped slots pass data up, fallback content goes inside `<slot>`. `#name` shorthand. No `$slots` checks unless you hide an empty region.
- Generic components: `<script setup lang="ts" generic="T extends { id: string }">`, only when the component works on several types.
- `defineExpose()` exposes a small API; type a ref to a component as `InstanceType<typeof X>`. No `$parent`, `$root`, `$refs`. No mixins, `extends`, render functions or JSX for ordinary components; `<component :is>` takes a component, not a string.

## Templates, styling, accessibility

- Shorthands `:`, `@`, `#`; quote attributes; self-close components; PascalCase components in templates; same-name shorthand `:loan` (3.4). One expression per binding; move chains to `computed()`. Attribute order of `vue/attributes-order`.
- Every `v-for` has a stable `:key` from the data (never the index when items change). Never `v-if` and `v-for` on one element; filter in a `computed()`. `v-if` by default, `v-show` for frequent toggles. Use `v-for="x in xs"`.
- A method for more than one statement (`@click="handleSelect"`); inline for a single emit or assignment. Modifiers (`.prevent`) in the template. `v-model` with `.trim`/`.number`. A form submits through `<form @submit.prevent>` and `<button type="submit">`.
- `<style scoped>` only (`vue/enforce-style-attribute`); class selectors, `:deep()` rarely. Global styles in a `.css` file imported in `main.ts`, tokens as CSS custom properties. `v-bind()` in CSS or a custom property for reactive styles. Plain CSS, no Sass, no framework without a written reason.
- Use the right element: `<button>` for actions, `<a>` or `RouterLink` for navigation, `<label :for="id">` with `useId()`, `<dialog>` with `showModal()`. No click handlers on `<div>`. `alt` on every image, one `<h1>`, one `<main>`, visible focus. After a route change set `document.title` and focus `<main tabindex="-1">`. Live regions for async messages. The accessibility lint rules are errors in CI.

## Composables

- A composable is for stateful logic with a lifecycle; a stateless function is a plain `.ts` function. Extract when a second component needs it or the script grows long, not before. Keep it in the feature folder until a second feature needs it.
- `useLoanList(source: MaybeRefOrGetter<readonly Loan[]>)`, read with `toValue()` inside `computed`/`watch`/`watchEffect`. At most three positional parameters, then an options object. Return a plain object of refs, never `reactive()`; `readonly()` refs for state that callers must not write. Create state inside the function, never at module level.
- Clean up everything it starts (`onScopeDispose`, `onWatcherCleanup` + `AbortController`). Call composables synchronously in setup. Do not touch `document` or `window` at call time; test such a composable in the browser project.
- Platform first. VueUse (`@vueuse/core`) only when it replaces several of your own composables, and say so in the pull request.

## State and provide/inject

- State lives in the lowest component that needs it; lift it when siblings need it. Server data is not client state. URL state (`route.query`) for anything shareable. No module-level `ref()` as a store.
- Pinia setup stores: `defineStore("loan", () => { ... })`, `ref` for state, `computed` for getters, functions for actions, and return every state ref (no private state). Call `useLoanStore()` only inside setup, actions or guards. Do not destructure the store; `storeToRefs(store)` for state, destructure actions. Write your own `$reset` action for setup stores. Test with `setActivePinia(createPinia())`.
- `provide`/`inject` with an `InjectionKey` Symbol in its own module, provide `readonly()` state and functions for changes, wrap both in `provideX()`/`useX()` and make `useX()` throw when the provider is missing. For compound components only; not for ordinary data flow.

## Routing and data fetching

- Manual route table with `createWebHistory(import.meta.env.BASE_URL)`; every route named and lazy (`() => import("@/x/x-view.vue")`), a catch-all last, `RouteMeta` augmented for `title` and `requiresAuth`. Pass params as props with `props: true` and `defineProps<{ id: string }>()`. Navigate by name. Serve a history-mode app with an `index.html` fallback.
- Guards return a value (`false`, a location, or nothing); never `next` (deprecated since router 5.0.3). Keep `beforeEach` small, no data fetching there. Authorisation is checked on the server.
- `router.afterEach` sets the title and focuses `main`. `scrollBehavior: (_to, _from, saved) => saved ?? { top: 0 }`.
- Fetch in a composable (`useFetchJson(schema, () => url)`): getter input, `AbortController` per request combined with `AbortSignal.timeout(5_000)` through `AbortSignal.any`, `response.ok` check, body held as `unknown` and parsed with a Zod schema, `shallowRef` data, readonly `data`/`error`/`isLoading`. Render loading, error and data states. Mutations are functions that disable their button. TanStack Query for Vue only when two components share server data. Encode user input in URLs.

## Errors and async

- Throw `Error` objects with a `cause`. Handle expected failures where they happen; return a result for normal outcomes. Never show `error.message` of an unexpected error; log it.
- `app.config.errorHandler` in `main.ts` logs once with the cause chain and reports; `unhandledrejection` and `error` listeners beside it; `router.onError` for failed lazy imports.
- Error boundary component: `onErrorCaptured` stores the error, returns `false`, renders a fallback slot that does not re-render the failing content. Wrap `RouterView` in one.
- An `async` template handler is allowed (Vue routes its rejection to the handler). In script, handle every promise (`await`, return, or `void` with inner handling). Disable the button while a handler runs. `fetch` does not reject on HTTP errors: check `response.ok`.
- No top-level `await` in `<script setup>` and no `<Suspense>` (experimental). `defineAsyncComponent` for heavy non-route components. Clear timers in cleanup hooks.

## Performance and security

- Measure first. Route-level code splitting, stable props (compute `active` in the parent), `shallowRef` for large data, virtualise lists of hundreds of rows, `v-once`/`v-memo`/`<KeepAlive max>` only after a measurement. Do not watch deep structures. Size images and lazy-load them.
- Never use untrusted templates or the full Vue build. No `v-html` (lint error); if you must render HTML, sanitise it with DOMPurify at the boundary and say so in a comment on the disable line. Validate user URLs (`http`, `https` or relative) before `:href` or `router.push`. No user CSS strings, no `:is` from user data. Tokens in `HttpOnly` cookies, not `localStorage`. The server checks everything. `VITE_*` values are public. CSP at the server, no `unsafe-inline` for scripts. `npm audit` in CI.

## Testing

- Vitest only, no `globals`. Tests sit beside the code: `x.test.ts` (Node) and `x.browser.test.ts` (Chromium). Logic, composables and stores need no component. Composables with hooks or watchers run inside `effectScope()` (`scope.run`, `scope.stop()`); hooks and `inject` need a tiny component in the browser project. Stores: fresh `setActivePinia(createPinia())` per test.
- Component tests: `const screen = await render(Comp, { props, slots, global: { plugins: [router, createPinia()] } })` (`render` returns a promise), query by role and name, `await locator.click()`/`.fill()`, `await expect.element(locator).toBeVisible()`, `screen.emitted("select")`. Real router (`createMemoryHistory`) and Pinia; do not mock children; test loading, error and data states; no snapshots of whole components.
- Stub only network, clock and browser APIs: `vi.stubGlobal("fetch", vi.fn<typeof fetch>(...))` with `vi.unstubAllGlobals()` in `afterEach`, or MSW when many tests share handlers. `vi.waitFor` for async state. Fake timers restored in `afterEach`. Playwright end-to-end tests in `e2e/` against `vite preview`.
- All TypeScript testing rules apply: typed fixtures, no `any`, errors asserted by class and data.

## TypeScript

- Every `<script>` is `lang="ts"`, checked by `vue-tsc --build` with `strictTemplates`. No `*.vue` shim. `env.d.ts` keeps `/// <reference types="vite/client" />`.
- Props, emits, models, slots by macro types; keep the props type simple (no conditional type for the whole object); shared props types are imported with `import type`. No `PropType`, no `enum` (`as const` unions instead). `readonly T[]` for read-only array props.
- Type refs by value (`ref<Loan[]>([])`), template refs by element (`useTemplateRef<HTMLInputElement>("input")`, read with `?.`), component refs by `InstanceType<typeof X>`. Narrow `event.currentTarget` with `instanceof`; no `as`, no `!`. Do not annotate `computed()`.
- Composables take `MaybeRefOrGetter<T>`, take schemas as parameters instead of `<T>` return generics, return plain objects; write the return type of shared composables. `InjectionKey` for provide/inject. Type `RouteMeta` by augmentation. External data is `unknown` until a Zod schema accepts it; `z.infer` for the type.
- `<!-- @vue-expect-error reason -->` in templates, `@ts-expect-error` with a description in scripts; never `@ts-ignore`.

## Modern Vue

- Replace on touch: Options API and `defineComponent` with `<script setup>`; `PropType` and `withDefaults()` with type-based props and destructure; `modelValue` plus emit with `defineModel()`; `ref(null)` and `$refs` with `useTemplateRef()`; counters for ids with `useId()`; `onCleanup` with `onWatcherCleanup()`; `:loan="loan"` with `:loan`; mixins with composables; Vuex with Pinia; `next()` in guards with a return; `@vue/test-utils` and jsdom with Browser Mode.
- Stay on Vue 3.5 (`^3.5.45`). Vue 3.6 and Vapor Mode (`<script setup vapor>`) are a release candidate; do not use them until 3.6 is stable. Vue 2 and Vue CLI are not for new work.
- Convert an Options API component only when you change its logic, one component per change, keeping props, events and slots. Move Vuex one module at a time. Move one tool at a time, in its own pull request, after reading its release notes. Vue Router 5 and Pinia 4 are current.
