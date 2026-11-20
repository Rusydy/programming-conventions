# Vue Principles and Sources of Truth

## Summary

These principles apply to every Vue 3 project that is not a Nuxt application, such as a Vite single-page app, or a frontend that another host embeds. They put the Vue compiler, `vue-tsc` and the official Vue documentation and style guide ahead of local configuration, so that any Vue developer can read the code on the first day. The set adds to [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) and never replaces it. Nuxt will get its own folder, which builds on this one.

## Rules

### Principles

1. **Write `<script setup lang="ts">` only.** Use the Composition API with `<script setup>` in every new component. Do not write the Options API, `defineComponent()` or a `setup()` function in new code ([project setup](02-project-setup-and-tooling.md#vue-and-compiler), [modern Vue by release](14-modern-vue-by-release.md#idioms-to-replace)).
2. **Declare state with `ref()`, derive with `computed()`.** Compute a value with `computed()`. A `watch` or `watchEffect` is for talking to the outside world, never for copying state into other state ([reactivity](04-reactivity.md#watchers)).
3. **Follow the toolchain.** The Vue compiler, `vue-tsc`, `eslint-plugin-vue`, `@vue/tsconfig` and the Vue style guide define the baseline. Replace a default only with a written reason. This is convention over configuration applied to Vue.
4. **Props down, events up.** A parent gives a child props. A child tells its parent through emitted events. Use `v-model` through `defineModel()` where a component exists to edit a value ([components](05-components-props-emits-and-slots.md)).
5. **Compose with slots and composables.** A component accepts content through slots, and logic is reused through composables. Do not use mixins, `extends` or renderless-component tricks for reuse ([composables](07-composables.md)).
6. **Keep one component per concern.** A `.vue` file has one job. Move logic that has no markup into a composable or a plain `.ts` module, and test it there ([project layout](03-project-layout-and-naming.md#where-code-lives)).
7. **Use the platform first.** Use HTML elements, CSS, the Web APIs and the Vue built-ins before a package. Add a dependency only when it removes real complexity. A utility library such as VueUse is a dependency like any other ([composables](07-composables.md#vueuse)).
8. **Make it accessible by default.** Use a real `<button>`, `<a>` and `<label>`. Add a keyboard path to every pointer action ([templates](06-templates-styling-and-accessibility.md#accessibility)).
9. **Treat templates as code that runs.** Never render untrusted HTML or untrusted templates ([performance and security](11-performance-and-security.md#security)).
10. **Wait for a second use case.** Do not add a store, a provide/inject pair, a composable, a generic component or a prop "just in case".
11. **Follow the TypeScript notes.** Every `<script>` has `lang="ts"`, and every rule of [typescript-conventions](../typescript-conventions/01-principles-and-sources.md) applies inside it, except where [the rule on precedence](#order-of-precedence) names an exception.

### Order of precedence

When two sources disagree, the lower number wins.

1. The behaviour of the Vue compiler and runtime, and the official Vue documentation, API reference and release notes.
2. The notes in this folder.
3. The `vue-tsc` diagnostics, and the `eslint-plugin-vue` and typescript-eslint presets that the notes name.
4. The [official Vue style guide](https://vuejs.org/style-guide/). The notes follow its essential and strongly recommended rules, and record where they choose differently.
5. [typescript-conventions](../typescript-conventions/01-principles-and-sources.md), for every question about TypeScript itself.
6. Other style guides. Adopt one of their rules only when a note in this folder names it.

Vue's required shape overrides the TypeScript notes for the code that Vue dictates. There are five cases, and each one is recorded in the note that uses it:

- A `.vue` file is a default export, so a component is imported as a default import, and the TypeScript rule for named exports does not apply to it ([project layout](03-project-layout-and-naming.md#exports-and-imports)).
- A component reads its props from `defineProps()`, so its props type is a local `Props` interface, not an interface named after the component ([components](05-components-props-emits-and-slots.md#props)).
- `defineEmits()` takes its type as a type literal that lists the events, so the events are not a named `interface` ([components](05-components-props-emits-and-slots.md#emits)).
- A template event handler may be an `async` function, because Vue sends its rejection to the error handler, so the TypeScript rule against passing an `async` function as a void callback has an exception here ([errors and async](10-errors-and-async.md#event-handlers)).
- A component with `v-model` receives and emits an `update:` event, which Vue names, so the camelCase rule for callbacks does not apply to it ([components](05-components-props-emits-and-slots.md#v-model)).

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so each review stays small, and raise the rest as a separate task.
- **Options API code:** a component written with `export default { data() {} }` is converted when you change its logic, not when you only touch its styles. Convert one component per change ([modern Vue by release](14-modern-vue-by-release.md#migrating-an-existing-project)).
- **Stricter settings:** adopt a compiler option or a lint rule in its own change, with its errors fixed or suppressed in that change.
- **Mechanical changes** (formatting, autofixes, dependency bumps) go in their own commits.
- **Generated code** is exempt: any file that a tool writes, such as `typed-router.d.ts`, `components.d.ts` and a generated API client.
- **Shared and team repositories:** when a repository documents its own conventions, follow those first, and apply these notes to the code you write where the repository is silent.
- **Client-only hosts:** when a desktop shell or another host embeds the frontend, it is a client-only Vite project, so there is no server rendering. Every rule here applies, and the notes about server-side state sharing do not.
- **Nuxt:** a Nuxt app follows these notes for components, reactivity, composables and TypeScript, and the Nuxt notes for everything that Nuxt owns, such as routing, data fetching and auto-imports. Nuxt notes are not written yet, so follow the Nuxt documentation where this set is silent.

### Decisions to review

These choices were made while writing the notes, because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Why | Where to change it |
| --- | --- | --- |
| `<script setup lang="ts">` and no Options API | The Vue documentation says both styles are fully capable and recommends the Composition API with `<script setup>` for production apps that use a build tool. One style keeps the code uniform and lets `vue-tsc` type every component the same way. | [project setup](02-project-setup-and-tooling.md#eslint-rules-for-vue) |
| kebab-case file names for components (`loan-row.vue`) | The Vue style guide accepts PascalCase or kebab-case if the repository is consistent. The TypeScript notes use kebab-case for every file, and macOS and Windows file systems ignore case. `create-vue` writes PascalCase (`HelloWorld.vue`). The import still names the component in UpperCamelCase. | [naming](03-project-layout-and-naming.md#naming) |
| Prettier with no `.prettierrc` | The TypeScript notes use Prettier defaults. `create-vue` writes `semi: false`, `singleQuote: true` and `printWidth: 100`. Prettier also reads `max_line_length` from `.editorconfig`, so the setup note deletes that line too. | [formatting](02-project-setup-and-tooling.md#formatting) |
| Typed ESLint presets and `eslint-plugin-vue` `flat/recommended`, not the `create-vue` setup | `create-vue` uses `flat/essential` and the untyped `recommended` preset, and the Oxlint option. The TypeScript notes use `recommendedTypeChecked`, `stylisticTypeChecked` and no Oxlint. | [linting](02-project-setup-and-tooling.md#linting) |
| Sixteen `eslint-plugin-vue` rules switched on, and one switched off | The sixteen enforce the choices of these notes, such as type-based props and `useTemplateRef()`. Fourteen are outside every preset, so a plugin upgrade does not turn them on by itself, and two (`no-required-prop-with-default`, `no-v-html`) are warnings in `flat/recommended` and become errors. `vue/require-default-prop` is off, because the TypeScript notes use `undefined` for an absent value and it warns on every optional prop. | [eslint rules for Vue](02-project-setup-and-tooling.md#eslint-rules-for-vue) |
| `eslint-plugin-vuejs-accessibility` for accessibility | Svelte's compiler warns about accessibility problems, and Vue's does not, so a linter is the only automatic check. The plugin is community-maintained, and its `label-has-for` default is stricter than the HTML rules. | [linting](02-project-setup-and-tooling.md#linting) |
| `@/` alias for `src/` | The TypeScript notes use `@/` for anything further than one folder away, and `create-vue` writes the same alias. | [imports](03-project-layout-and-naming.md#exports-and-imports) |
| Local `interface Props` for props, with reactive props destructure for defaults | The Vue documentation uses both. The React note names the interface after the component, which `defineProps<T>()` does not need. Destructure has been stable since 3.5, and it replaces `withDefaults()`. | [components](05-components-props-emits-and-slots.md#props) |
| `ref()` as the default, `reactive()` rarely | The Vue documentation recommends `ref()` as the primary API, because `reactive()` cannot be reassigned or destructured. | [reactivity](04-reactivity.md#ref-and-reactive) |
| Pinia setup stores | The Vue documentation recommends Pinia for state shared across components, and `create-vue` writes a setup store. A setup store reads like a composable, so the same rules apply. | [state management](08-state-management-and-provide-inject.md#pinia) |
| Manual route table, not file-based routing | Vue Router 5 merged file-based routing and typed routes into the core package, but `create-vue` still writes a manual table, and the data loaders are experimental. | [routing](09-routing-and-data-fetching.md#routes) |
| TanStack Query once two components share server data | The Vue documentation has no data-fetching library. A hand-written fetch composable does the job for one screen, and a cache is a feature to adopt for a reason. | [data fetching](09-routing-and-data-fetching.md#data-fetching) |
| No `<Suspense>` and no top-level `await` in `<script setup>` | The Vue documentation marks `<Suspense>` experimental, and a component with top-level `await` needs one. | [errors and async](10-errors-and-async.md#async-in-components) |
| Vitest Browser Mode with `vitest-browser-vue` for component tests, in place of Vue Test Utils with jsdom | Vitest calls Browser Mode the recommended approach for component tests, and the Svelte notes made the same choice. The Vue documentation shows Vue Test Utils, which `create-vue` installs with jsdom. The browser needs a Playwright browser installed. | [testing](12-testing.md#tools) |
| Tests live in `tsconfig.app.json`, with no `tsconfig.vitest.json` | The TypeScript notes include the test files in the type check. `create-vue` writes a third project for them. | [project setup](02-project-setup-and-tooling.md#tsconfig) |
| Stay on Vue 3.5 while 3.6 is a release candidate | Vue 3.6 adds Vapor Mode and a new reactivity core, and was at `3.6.0-rc.15` on 2026-11-12. | [modern Vue by release](14-modern-vue-by-release.md#vue-36-and-vapor-mode) |

### Version policy

- **Vue:** run the newest 3.5 release, declared as `"vue": "^3.5.45"` or the newest 3.5 patch on the day you start. On 2026-11-20 the newest stable release is 3.5.45. Vue 3.6 is at the release-candidate stage, and its Vapor Mode is not used until 3.6 is stable.
- **Features by minimum version:** this set uses `defineModel()` (3.4), the same-name shorthand `:loan` (3.4), `useTemplateRef()`, `useId()` and reactive props destructure (all 3.5). Set the `vue` range to a version that has every feature the code uses.
- **TypeScript:** follow the [TypeScript version policy](../typescript-conventions/01-principles-and-sources.md#version-policy). `create-vue` already declares `"typescript": "~6.0.0"`, and `vue-tsc` and typescript-eslint work with it. Use `~6.0.3`.
- **Vite and `vue-tsc`:** run the versions that `create-vue` writes. The notes were checked with Vite 8.3.8, `@vitejs/plugin-vue` 6.0.11 and `vue-tsc` 3.3.14.
- **Vue Router and Pinia:** Vue Router 5.5 and Pinia 4.1 were current on 2026-11-20. Both run on Vue 3.
- **Upgrades:** move one tool at a time, in its own pull request, and read its release notes first. [Modern Vue by release](14-modern-vue-by-release.md) lists the Vue releases that matter.

### Working with coding agents

- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/vue.md](../agent-rules/rules/vue.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** the rule has a `paths` field, so Vue rules stay out of sessions that never touch Vue. Claude Code loads it when a session reads, writes or edits a `.vue` file. The patterns match against the session's primary working directory, so start the session inside the Vue repository. A brand-new repository has no `.vue` file yet, so tell the agent to read `~/.claude/rules/vue.md` before it writes the first one. The digest loads next to `typescript.md` and does not replace it. A composable or a store is a plain `.ts` file, so it loads only `typescript.md`; ask the agent to read `vue.md` first when you change one.
- A project whose agents must follow these notes on other machines names this folder in its own `AGENTS.md`, because the user-level rule is installed per machine.
- Tell agents to run `npm run check`, `npm run lint` and `npm test` before they report Vue changes as done, and to read the installed Vue version before they use a newer feature.

## Sources and raw notes

Pages read on 2026-11-20 unless a bullet says otherwise:

- npm registry on 2026-11-20: `vue` 3.5.45 (`latest`) and 3.6.0-rc.15 (`rc`), `vue-router` 5.5.1, `pinia` 4.1.0, `vite` 8.3.8, `@vitejs/plugin-vue` 6.0.11, `vue-tsc` 3.3.14, `@vue/tsconfig` 0.9.1, `eslint-plugin-vue` 10.12.1, `@vue/eslint-config-typescript` 14.9.0, `typescript-eslint` 8.73.0, `eslint` 10.15.0, `prettier` 3.10.1, `vitest` 5.1.1, `vitest-browser-vue` 3.1.0, `@vue/test-utils` 2.6.0, `create-vue` 3.24.0, `@vueuse/core` 15.0.0, `@tanstack/vue-query` 5.108.1, `typescript` 7.0.2 (`latest`).
- [Vue style guide](https://vuejs.org/style-guide/): the essential, strongly recommended, recommended and use-with-caution rule pages. The notes cite the rule that each of their rules follows.
- [Vue introduction](https://vuejs.org/guide/introduction.html): the two API styles, and that `<script setup>` with the Composition API suits production apps that use a build tool.
- [Vue tooling](https://vuejs.org/guide/scaling-up/tooling.html): `create-vue`, the Vue (Official) extension, `vue-tsc`, `eslint-plugin-vue`, Vitest.
- [Vue core releases](https://github.com/vuejs/core/releases) and its `CHANGELOG.md`: 3.5.45 (2026-11-05), and the 3.6.0-rc.1 notes on Vapor Mode and the alien-signals reactivity core.
- `create-vue` 3.24.0, run on 2026-11-20 with `--ts --router --pinia --vitest --eslint --prettier`: it writes `vue ^3.5.42`, `vue-router ^5.3.1`, `pinia ^4.0.3`, `vite ^8.2.2`, `typescript ~6.0.0`, `vue-tsc ^3.3.11`, `eslint ^10.10.0`, `eslint-plugin-vue ~10.11.0`, `@vue/eslint-config-typescript ^14.9.0`, `vitest ^4.1.11` and `@vue/test-utils ^2.5.0`, plus Oxlint packages and `@tsconfig/node24`. The ESLint config uses `flat/essential` and `vueTsConfigs.recommended`. `.prettierrc.json` has `semi: false`, `singleQuote: true` and `printWidth: 100`, and `.editorconfig` has `max_line_length = 100`.
- The sample project that checks these notes: scaffolded with `create-vue` 3.24.0, then brought to the baseline of the [setup note](02-project-setup-and-tooling.md) with Vue 3.5.45, TypeScript 6.0.3, Vite 8.3.8, `vue-tsc` 3.3.14, ESLint 10.15.0, `eslint-plugin-vue` 10.12.1, Vitest 5.1.1 and `vitest-browser-vue` 3.1.0. Each note says which of its examples ran there.
