# Vue Project Layout and Naming

## Summary

Group code by feature under `src/`, and keep the files that every feature shares in a few fixed folders. Name components by the Vue style guide (multi-word, base and single-instance prefixes, tightly coupled names), but write the file names in kebab-case, as the TypeScript notes do. Import a component as a default import with its extension, and everything else as named exports through the `@/` alias.

## Rules

### Where code lives

- Start from the layout that `create-vue` writes, then group by feature:

```text
src/
  main.ts            creates the app and mounts it
  app.vue            the root component
  router/index.ts    the route table and guards
  ui/                base components that know nothing about the domain
  loans/             one folder per feature
    loan.ts          types and plain functions of the feature
    loan-list-view.vue
    loan-row.vue
    loan-row.browser.test.ts
    use-loan-list.ts
    use-loan-list.test.ts
    loan-store.ts
  shared/            code that two or more features use
```

- A feature folder holds its components, composables, store, types and tests side by side. Move a file to `src/shared/` only after a second feature needs it, as the TypeScript notes say about waiting for a second use case.
- `create-vue` groups by type (`components/`, `views/`, `stores/`). That layout is fine for a project of a few screens. Switch to feature folders when a feature has more than a view and two components, and move one feature per change.
- `src/ui/` holds base components: a button, an input, a modal. A file in `ui/` imports nothing from a feature folder.
- A view is the component that a route renders. Name it with a `-view` suffix (`loan-list-view.vue`) and keep it thin: it reads the route, calls composables and stores, and lays out child components.
- Write no `index.ts` that re-exports a folder, as the TypeScript notes say. `src/router/index.ts` is not a barrel: it creates and exports the router, and `create-vue` writes it there.
- Put static files that a build must not hash in `public/`, and files that a component imports in the feature folder or in `src/assets/`.
- Keep `src/main.ts` to creating the app, installing plugins and mounting. Put no business code in it.

### Naming

- **Files** are kebab-case, like every file in the TypeScript notes: `loan-row.vue`, `use-loan-list.ts`, `loan-store.ts`. The Vue style guide accepts PascalCase or kebab-case if a repository is consistent, and `create-vue` writes PascalCase (`HelloWorld.vue`). kebab-case avoids the case-insensitive file system problem on macOS and Windows ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- **Rename through a temporary name.** A case-only rename (`App.vue` to `app.vue`) does nothing on macOS if you write the new file, and `vue-tsc` then reports TS1149. Use `git mv App.vue tmp.vue && git mv tmp.vue app.vue`.
- **Components** are UpperCamelCase where they are imported and used: `import LoanRow from "./loan-row.vue"` and `<LoanRow />`. The compiler infers the component's name from the file name, so `loan-row.vue` is `LoanRow` in the devtools.
- **Multi-word names.** Every component name has at least two words, so that it never clashes with an HTML element, present or future. The root `app.vue` is the exception. `vue/multi-word-component-names` enforces this.
- **Base components** start with `Base`: `base-button.vue`, `base-modal.vue`. A base component is presentational, has no business logic and no store access, and wraps one HTML element or a small group of them.
- **Single-instance components** start with `The`: `the-header.vue`, `the-sidebar.vue`. A component that is used once per page and takes no props is a single-instance component.
- **Tightly coupled children** start with the name of the parent: `loan-list.vue` and `loan-list-item.vue`, `search-form.vue` and `search-form-input.vue`. Files then sort together.
- **Order the words from general to specific**: `search-input.vue`, `search-button.vue`, not `input-search.vue`. A folder per feature already gives most of the context, so do not repeat the feature name in a file that has no sibling with a different prefix.
- **Write full words.** `student-dashboard-settings.vue`, not `stu-dash-settings.vue`.
- **Composables** are `use-` files with a `use` function: `use-loan-list.ts` exports `useLoanList`. A composable that holds module-level state is a store, and it is written as one ([state management](08-state-management-and-provide-inject.md)).
- **Stores** are `<subject>-store.ts` and export `use<Subject>Store`. The store id is the subject in camelCase (`"loan"`, `"loanDraft"`). Pinia's documentation names its stores this way.
- **Props** are lowerCamelCase in the script and kebab-case in templates: `<LoanRow :selected-id="id" />`. `vue/prop-name-casing` and `vue/attribute-hyphenation` enforce both.
- **Events** are lowerCamelCase in `defineEmits` (`rowSelect`, `update:note`) and kebab-case in the listener: `@row-select="..."`. `vue/v-on-event-hyphenation` enforces the listener side; review enforces the camelCase of the emitted name.
- **Slots** are lowerCamelCase or one word: `header`, `rowActions`. The default slot has no name.
- **Types** are UpperCamelCase and booleans read like questions (`isLoading`, `hasError`, `canEdit`), as the TypeScript notes say. A ref is named like any variable, with no `Ref` suffix.
- **Handlers** that implement a callback or an event are `handleSelect`, as the TypeScript notes say about `handleSomething`. An emitted event is a past-tense or noun phrase (`select`, `rowSelect`), not `onSelect`.
- **Template refs** are named after the element (`searchInput`), and the `ref` attribute in the template has the same name as the `useTemplateRef()` key.
- Test files are `name.test.ts` for logic, and `name.browser.test.ts` for components ([testing](12-testing.md#where-tests-live)).

### Exports and imports

- Import a component as a default import with its extension: `import LoanRow from "./loan-row.vue"`. TypeScript needs the `.vue` extension, and the Vue (Official) extension and `vue-tsc` resolve it.
- Import `.ts` modules without the extension (`./use-loan-list`), because Vite resolves them and the TypeScript notes only require `.ts` extensions in code that Node.js runs directly. A project that runs scripts with `node script.ts` follows the TypeScript notes for those scripts.
- Use `import type` for types, and inline `type` in a mixed import, as the TypeScript notes say: `import { computed, type MaybeRefOrGetter } from "vue"`. `verbatimModuleSyntax` requires it.
- Use named exports in modules. Default exports are for `.vue` files and for tool configuration (`vite.config.ts`, `eslint.config.ts`). A route component loaded with `import()` uses the default export of the `.vue` file.
- Same folder `./x`, one up `../x`, further through `@/`: `import { useLoanStore } from "@/loans/loan-store"`. Never `../../..`. Vite reads the alias from `resolve.alias` in `vite.config.ts` ([setup](02-project-setup-and-tooling.md#vitest)).
- Import from `vue` only the functions the file uses. Do not rely on auto-imports in a plain Vue project: `unplugin-auto-import` and `unplugin-vue-components` hide where a name comes from, and `vue/no-undef-components` then cannot catch a missing import.
- Import `RouterLink` and `RouterView` from `vue-router` in the file that uses them, instead of relying on the globally registered names. Register no component globally, except through a plugin that a library documents.

### Order inside a component

- Order the blocks as `<script setup lang="ts">`, then `<template>`, then `<style scoped>`. `vue/block-order` in `flat/recommended` keeps `<style>` last and accepts either order of the other two; keep the script first, as `create-vue` and the Vue documentation do.
- Order the script as: imports, the compiler macros, constants, refs and reactive state, computed values, functions, watchers, lifecycle hooks. `vue/define-macros-order` fixes the macros, and they come first after the imports: `defineOptions`, `defineProps`, `defineEmits`, `defineModel`, `defineSlots`.
- Keep a component to one `<script setup>`. A second plain `<script>` is for something that must run once per module, such as a named export; if you only need `inheritAttrs` or `name`, use `defineOptions()`, which `vue/prefer-define-options` enforces.
- Write attributes in the order of the style guide's recommended rule (`vue/attributes-order`): definition, conditionals, loops, unique attributes (`ref`, `key`), two-way binding, other attributes, events, content. Prettier does not reorder them, so the lint rule does.
- Write a component with several attributes on one line each, as Prettier does, with the first attribute on its own line when the tag wraps.

## Sources and raw notes

Pages read on 2026-11-20:

- [Vue style guide, strongly recommended](https://vuejs.org/style-guide/rules-strongly-recommended.html): component files, single-file component filename casing (PascalCase or kebab-case, always the same), base component names (`Base`, `App` or `V`), single-instance component names (`The`), tightly coupled component names, order of words, full-word names, self-closing components, component name casing in templates (PascalCase in SFCs) and in JS, prop name casing, multi-attribute elements, simple template expressions, simple computed properties, quoted attribute values, directive shorthands.
- [Vue style guide, essential](https://vuejs.org/style-guide/rules-essential.html): multi-word component names, detailed prop definitions, keyed `v-for`, no `v-if` with `v-for`, component-scoped styling.
- [Vue style guide, recommended](https://vuejs.org/style-guide/rules-recommended.html): element attribute order, single-file component top-level element order (`<script>`, `<template>`, `<style>`).
- [Vue events guide](https://vuejs.org/guide/components/events.html): emit in camelCase and listen in kebab-case in templates.
- [Vue Pinia state management](https://vuejs.org/guide/scaling-up/state-management.html): Pinia as the recommended store.
- `create-vue` 3.24.0 output: `src/components`, `src/views`, `src/stores`, `src/router/index.ts`, `src/assets`, `HelloWorld.vue`, `App.vue`, `@/` alias.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): the layout above (`loans/` with a view, a row component, a composable and two tests), the `./app.vue` and `./loan-row.vue` imports, `./use-loan-list` imported without an extension, the `@/loans/loan-list-view.vue` route import, and the `:loan` same-name shorthand. `vue-tsc`, ESLint and Prettier ran with 0 errors.
