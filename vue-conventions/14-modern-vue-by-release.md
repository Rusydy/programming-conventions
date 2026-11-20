# Modern Vue by Release

## Summary

Write the idiom of Vue 3.5: `<script setup>`, type-based macros, `defineModel()`, reactive props destructure, `useTemplateRef()`, `useId()` and `onWatcherCleanup()`. Replace an old idiom when you touch its line, and convert an Options API component only when you change its logic. Stay on 3.5 while Vue 3.6, with Vapor Mode, is a release candidate.

## Rules

### Releases that matter

| Release | What it adds that these notes use |
| --- | --- |
| Vue 3.0 | The Composition API, `ref`, `reactive`, `computed`, `watch`, the lifecycle hooks as functions, `Teleport`, fragments |
| Vue 3.2 | `<script setup>` stable, `defineProps` and `defineEmits`, `effectScope()`, `v-memo` |
| Vue 3.3 | `defineSlots()`, `defineOptions()`, generic components, imported types in `defineProps`, the short `defineEmits` type literal, `toValue()` and `MaybeRefOrGetter`, getter support in `toRef()` |
| Vue 3.4 | `defineModel()` stable, the same-name shorthand (`:loan`), `watch` with `once`, a stable computed value, a faster template parser |
| Vue 3.5 | Reactive props destructure stable, `useTemplateRef()`, `useId()`, `onWatcherCleanup()`, a `deep` depth for `watch`, `pause()` and `resume()` on a watcher, a lighter reactivity core, deferred `Teleport`, lazy hydration for server rendering |
| Vue 3.6 (release candidate) | Vapor Mode and a reactivity core based on alien-signals |

- The notes target Vue 3.5. The features of 3.4 and 3.5 are the reason for the `"vue": "^3.5.45"` range in the [version policy](01-principles-and-sources.md#version-policy). Pinia 4 also needs Vue 3.5.11 or later.
- Vue 2 reached end of life on 2023-12-31. Do not start a project on it, and plan a move of an existing one to Vue 3. The `@vue/compat` build is a migration aid and not a target.
- Vue CLI is in maintenance mode, and the Vue documentation recommends Vite. Vuex is in maintenance mode and Pinia replaced it.

### Idioms to replace

Replace the old form when you touch its line.

| Old idiom | Modern idiom |
| --- | --- |
| `export default { data() { return {...} }, methods: {...} }` | `<script setup lang="ts">` with `ref()` and functions |
| `defineComponent({ props, setup() {} })` | `defineProps<Props>()` in `<script setup>` |
| `props: { id: { type: Number, required: true } }` and `PropType<T>` | `interface Props { id: number }` and `defineProps<Props>()` |
| `withDefaults(defineProps<Props>(), { n: 1 })` | `const { n = 1 } = defineProps<Props>()` |
| `const props = defineProps<Props>()` and `props.id` | `const { id } = defineProps<Props>()` |
| A `modelValue` prop and an `update:modelValue` emit | `const model = defineModel<T>()` |
| `const input = ref<HTMLInputElement | null>(null)` with `ref="input"` | `const input = useTemplateRef<HTMLInputElement>("input")` |
| `this.$refs.input`, `$parent` and `$root` | A template ref, props and events, or provide and inject |
| A counter or `Math.random()` for an element id | `useId()` |
| `watch(src, (v, o, onCleanup) => { onCleanup(...) })` | `onWatcherCleanup()` (3.5), called before any `await` |
| `watch(src, cb)` that runs once and stops itself | `watch(src, cb, { once: true })` |
| `<LoanRow :loan="loan" />` where the names match | `<LoanRow :loan />` |
| `emits: ["select"]` and `$emit("select")` | `defineEmits<{ select: [id: string] }>()` and `emit("select", id)` |
| A mixin or `extends` | A composable |
| `inheritAttrs: false` in a second `<script>` or `export default` | `defineOptions({ inheritAttrs: false })` |
| `reactive()` for a flat object that you reassign | `ref()` |
| `next()` in a navigation guard | `return` a value |
| Vuex | Pinia |
| `$listeners`, `.native`, filters and `$on` (removed in Vue 3) | Emits, `@click` on the component's root, functions and a store or an event emitter library |
| A global `<style>` in a component | `<style scoped>`, or a `.css` file imported in `main.ts` |
| `@vue/test-utils` with jsdom | `vitest-browser-vue` in Browser Mode |
| `tsconfig` without `strictTemplates` | `vueCompilerOptions.strictTemplates: true` |
| Volar and Vetur | The Vue (Official) extension and `vue-tsc` |
| `npm run build` that runs `run-p type-check build-only` | `npm run ci` with the checks in order |
| `create-vue`'s `eslint-plugin-vue` `flat/essential` | `flat/recommended` and the sixteen rules of the setup note |

### Vue 3.6 and Vapor Mode

- Vue 3.6 was at `3.6.0-rc.15` on 2026-11-12. Its release notes say the feature set of Vapor Mode is complete, that it is 100 percent opt-in, that it supports a subset of the Vue APIs, and that it does not support features that depend on virtual nodes or the component instance proxy. It works for `<script setup>` and template-only components, and not for the Options API. A component opts in with `<script setup vapor>`.
- Do not use Vapor Mode until Vue 3.6 is stable. The release notes recommend it for a performance-sensitive page in an existing app or for a small new app. These notes target the virtual DOM, and a Vapor component does not support every rule here, such as `$attrs` and `getCurrentInstance()`.
- When 3.6 is stable, upgrade in its own pull request: run `npm run ci`, compare the bundle size and the test results, and read the migration notes. The new reactivity core is meant to be compatible. Adopt `vapor` per component afterwards, for a measured reason, and write what you learn into this note.
- Do not install a 3.6 pre-release in an application that ships.

### Migrating an existing project

- **Convert one component per change**, and only when you change its logic. Do not convert a component when you only touch its styles or its text. A converted component keeps the same props, events and slots, so that its callers do not change.
- **Convert in this order:** `<script lang="ts">`, then `<script setup lang="ts">` with `ref` and `computed`, then the props, emits and models with macros, then template refs and watchers. Run `npm run check` after each step.
- **Mixed code is fine.** A project can hold Options API components and `<script setup>` components together, and the Vue documentation says the two styles share the same system. Turn on `vue/component-api-style` for `script-setup` in its own pull request, after the last Options component is converted, or scope the rule to the folders that are done.
- **Replace a mixin with a composable** before you convert the components that use it. Convert one mixin at a time.
- **Move Vuex to Pinia one module at a time.** Each Pinia store replaces one Vuex module, and both run side by side until the last one moves.
- **Move off Vue CLI and webpack to Vite** in its own pull request, before you convert components. Change nothing else in it.
- **Adopt a stricter setting in its own change:** `strictTemplates`, one lint rule of the setup note, or `noUncheckedIndexedAccess`. Fix or suppress its errors in the same change, as the TypeScript notes say.

### Upgrading

- Move one tool at a time, in its own pull request, and read its release notes first. Vue, Vue Router, Pinia, Vite, `vue-tsc`, `eslint-plugin-vue`, TypeScript and Vitest each have their own cadence.
- `vue` and `vue-tsc` are versioned apart. Keep `@vitejs/plugin-vue` and `vite` on versions that list each other as supported.
- Vue Router 4 to 5 is a transition release that merges `unplugin-vue-router` into the core package, with no breaking change for a project that did not use it. A project that did use it changes its import paths.
- Pinia 3 to 4 is ESM-only and needs `@vue/devtools-api` installed beside it, which npm installs as a peer dependency.
- TypeScript follows the [TypeScript version policy](../typescript-conventions/01-principles-and-sources.md#version-policy). `vue-tsc` 3.3 works with TypeScript 6.0. Check `vue-tsc`'s support before you move to TypeScript 7.
- After an upgrade, compare the type-error count, the lint count, the bundle size and the test results before and after, as the TypeScript notes say.

## Sources and raw notes

Pages read on 2026-11-20:

- [Vue core releases](https://github.com/vuejs/core/releases) and [`CHANGELOG.md`](https://github.com/vuejs/core/blob/main/CHANGELOG.md): 3.5.45 (2026-11-05) as the latest stable release; 3.6.0-rc.1 (2026-07-18) release notes on Vapor Mode ("100% opt-in", the supported subset, `<script setup vapor>`, recommended uses) and the alien-signals reactivity refactor; 3.6.0-rc.15 (2026-11-12) as the newest pre-release.
- [Vue documentation](https://vuejs.org/): the version badges on `defineModel` (3.4), reactive props destructure (3.5), `useTemplateRef` (3.5), `useId` (3.5), `onWatcherCleanup` (3.5), `watch` `once` (3.4), `deep` as a number (3.5), `defineSlots` and `defineOptions` (3.3), generic components, and `toValue` (3.3).
- [Vue tooling](https://vuejs.org/guide/scaling-up/tooling.html): Vue CLI in maintenance mode, Vue (Official) replaced Vetur.
- [Vue Router 5.0.0 release notes](https://github.com/vuejs/router/releases/tag/v5.0.0) and [Pinia 4.0.0 release notes](https://github.com/vuejs/pinia/releases/tag/v4.0.0).
- [Vue 2 end of life](https://v2.vuejs.org/lts/): Vue 2.7 reached end of life on 2023-12-31. This date is from the Vue 2 site and was not re-read for this set.
- [Vue introduction](https://vuejs.org/guide/introduction.html): the Options API and the Composition API are both fully capable and share one system.
- The 3.3 and 3.2 rows of the table come from the Vue documentation's version badges and the 3.3 and 3.2 release notes, which these notes did not re-read in full.
