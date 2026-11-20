# Nuxt Project Layout and Auto-imports

## Summary

Put each file in the directory that Nuxt scans for it: pages, layouts, components, composables, utilities, middleware and plugins under `app/`, handlers under `server/`, and code that both sides use under `shared/`. Nuxt auto-imports what those directories export, so you write no `import` for them. Name files in kebab-case, keep composables flat, and never mix Vue code with server code.

## Rules

### Layout

- Use the `app/` directory that Nuxt 4 creates, and these top-level directories:

```text
app/
  app.vue            the root component
  app.config.ts      build-time-safe configuration that the browser sees
  error.vue          the error page
  pages/             routes, by file name
  layouts/           page shells
  components/        auto-registered components, one folder per feature
  composables/       auto-imported composables (`use-x.ts`), flat
  utils/             auto-imported plain functions
  middleware/        route middleware
  plugins/           app plugins
  stores/            Pinia stores (with `@pinia/nuxt`)
  assets/            files that the build processes (CSS, images)
server/
  api/               handlers under /api
  routes/            handlers outside /api
  middleware/        handlers that run on every request
  utils/             auto-imported server functions
shared/
  types/             types and schemas for app and server
  utils/             plain functions for app and server
public/              files served as they are
test/
  unit/  nuxt/  e2e/
nuxt.config.ts
```

- Group by type, because Nuxt scans these directories. Inside `app/components/` make one folder per feature (`loan/`, `payment/`) and one for base components (`base/`). Nuxt prefixes a component's name with its folders and removes a repeated prefix, so `app/components/loan/loan-row.vue` is `<LoanRow>` and `app/components/base/button.vue` is `<BaseButton>`. The sample's `.nuxt/components.d.ts` listed exactly those two names.
- Keep `app/composables/` and `app/utils/` flat. Nuxt scans the top level of each, and a file in a subfolder was not auto-imported in the sample (`composables/loan/use-nested.ts`). When a feature needs its own folder, add it to `imports.dirs` in `nuxt.config.ts`, or import from it explicitly.
- Put in `shared/` only code that has no Vue and no Nitro in it: Zod schemas and their types (`shared/types/`), constants, and pure functions (`shared/utils/`). `shared/` code cannot import Vue or Nitro code, and the generated `shared` project enforces it. Nuxt auto-imports `shared/types` and `shared/utils` in both the app and `server/`, and `#shared/...` is the alias for explicit imports.
- Never import `app/` code in `server/`, and never import `server/` code in `app/`. Nuxt builds the Vue app and the Nitro server as separate bundles, and a cross import breaks the build or pulls server code into the browser. A type may cross with `import type`, but put a shared type in `shared/types/` anyway ([server](06-server-routes-and-validation.md#the-boundary)).
- A page in `app/pages/` is thin: it reads the route, fetches data, and lays out components. Put reusable markup in a component and reusable logic in a composable, as the [Vue notes](../vue-conventions/03-project-layout-and-naming.md#where-code-lives) say.
- Put a module of your own in `modules/` and a layer in `layers/`, only after a second project needs it.
- Put static files that must not change names (`robots.txt`, `favicon.ico`) in `public/`. Put files that the build should hash and optimise in `app/assets/`.
- Do not create `app/index.ts`, a barrel, or a `src/` directory. Nuxt 4's default `srcDir` is `app/`.

### Naming

- **Files** are kebab-case, as in the Vue and TypeScript notes: `loan-row.vue`, `use-loan-filter.ts`, `loan-store.ts`. Nuxt reads the file name of a component and turns it into PascalCase. Pages and server routes follow Nuxt's file-name syntax instead: `[id].vue`, `index.vue`, `[...slug].vue`, `index.get.ts`, `[id].get.ts`.
- **Components** are UpperCamelCase where used (`<LoanRow />`). The name that Nuxt builds from the folders and the file has two or more words, and the folder supplies the prefix: `app/components/base/button.vue` is `<BaseButton>`, `app/components/the/header.vue` is `<TheHeader>` (a component used once per page), and a child starts with its parent's name (`loan/loan-list.vue` and `loan/loan-list-item.vue`), as the [Vue notes](../vue-conventions/03-project-layout-and-naming.md#naming) say. Do not repeat the folder name in a file name unless the dedupe above gives the name you want.
- **Composables** are `use-x.ts` files that export `useX`. **Stores** are `x-store.ts` files in `app/stores/` that export `useXStore`, with the id `"x"`. **Utilities** are named by what they do (`format-money.ts` exports `formatMoney`). The auto-import name is the export name, not the file name.
- **Named exports** everywhere, except where Nuxt requires a default export: pages, layouts, `app.vue`, `error.vue`, middleware, plugins, server handlers, `nuxt.config.ts`, `app.config.ts` and `vitest.config.ts`.
- **Pages and layouts** use Nuxt's names. A layout is `default.vue` or a single word (`blank.vue`, `dashboard.vue`). A route middleware is a verb or a noun (`auth.ts`), and a global one has a `.global` suffix (`track.global.ts`). A plugin is named for what it adds (`error-handler.ts`), and a `.client.ts` or `.server.ts` suffix limits it to one side.
- **Components that render only in the browser** have a `.client.vue` suffix, or live inside `<ClientOnly>`. A `.server.vue` component renders only on the server and needs the experimental server components feature, which these notes do not use.
- **Imports.** Use `@/` for `app/`, `#shared/` for `shared/`, and `./x` or `../x` for a neighbour. Never `../../..`. Use `import type` for types, and write the `.vue` extension when you import a component by hand (in a test, for instance). Nuxt generates `~`, `@`, `~~`, `@@` and `#shared`; the notes use the two above ([decisions to review](01-principles-and-sources.md#decisions-to-review)).

### Auto-imports

- Rely on auto-imports in `app/`, `server/` and `shared/`. Write no `import` for `ref`, `computed`, `watch`, `useFetch`, `useRoute`, `navigateTo`, `defineStore`, your own composables, your own utilities, your own components, or types from `shared/types`. Nuxt builds the list from the Vue and Nuxt packages, your `composables/` and `utils/` directories, `shared/`, and the modules that you install. `.nuxt/imports.d.ts` and `.nuxt/components.d.ts` hold the generated list, and `nuxt typecheck` and `@nuxt/eslint` read it.
- Import explicitly when a name is not auto-imported (a type from a package, a function from a library), and in test files that run outside Nuxt (`test/unit`, `test/e2e`). Use `#imports` to import a Nuxt name explicitly: `import { ref } from "#imports"`. Do it where a file must also work outside Nuxt, such as a composable that a unit test runs in Node.js.
- A name that two files export is a conflict. Nuxt warns and keeps one of them. Rename one.
- Do not add `unplugin-auto-import` or `unplugin-vue-components`; Nuxt already does the job. Do not turn auto-imports off (`imports.autoImport: false`); it fights the framework.
- Auto-imported composables must be called where Nuxt's context exists: in `<script setup>`, in a plugin, in a middleware, or synchronously in another composable. After an `await`, the context is lost unless the function is wrapped in `callWithNuxt`, so call `useRuntimeConfig()`, `useNuxtApp()` and `useRoute()` before the first `await`.
- Prefix a component with `Lazy` (`<LazyHeavyChart />`) to load it only when it renders ([performance](09-rendering-seo-and-performance.md#loading)). Set a lazy-hydration directive (`hydrate-on-visible`) for one that is server-rendered but needs scripts late.
- Components that a page needs but no template mentions (a dynamic component) use `resolveComponent("LoanRow")` or an explicit import. Do not pass a string to `<component :is>`.

### Where Nuxt differs from the Vue notes

- A Vue project imports every name, groups by feature, and rejects top-level `await`. A Nuxt project does the opposite for the first two, because Nuxt scans by directory and generates the imports ([principles](01-principles-and-sources.md#order-of-precedence)). Every other Vue rule applies as written.
- Do not register a component globally by hand. `components/` registers all of them, and an `app/plugins/` file that calls `nuxtApp.vueApp.component(...)` hides the dependency.

## Sources and raw notes

Pages read on 2026-11-20:

- [Directory structure](https://nuxt.com/docs/directory-structure), and the pages for [`app/components`](https://nuxt.com/docs/directory-structure/app/components) (component names, `Lazy` prefix, `.client` and `.server` suffixes, delayed hydration, direct imports), [`app/composables`](https://nuxt.com/docs/directory-structure/app/composables), [`app/utils`](https://nuxt.com/docs/directory-structure/app/utils), [`app/pages`](https://nuxt.com/docs/directory-structure/app/pages), [`app/layouts`](https://nuxt.com/docs/directory-structure/app/layouts), [`app/middleware`](https://nuxt.com/docs/directory-structure/app/middleware), [`app/plugins`](https://nuxt.com/docs/directory-structure/app/plugins), [`server`](https://nuxt.com/docs/directory-structure/server), [`shared`](https://nuxt.com/docs/directory-structure/shared) (why Vue and Nitro code cannot mix, `shared/types` and `shared/utils`, `#shared`), and [`public`](https://nuxt.com/docs/directory-structure/public).
- [Auto-imports](https://nuxt.com/docs/guide/concepts/auto-imports): directory-based auto-imports, explicit imports through `#imports`, disabling, auto-imported components, third-party packages.
- [Nuxt lifecycle](https://nuxt.com/docs/guide/concepts/nuxt-lifecycle): the Nuxt context and its loss after `await`.
- [Code style](https://nuxt.com/docs/guide/concepts/code-style): the `@nuxt/eslint` module.
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `.nuxt/components.d.ts` listed `LoanRow` for `app/components/loan/loan-row.vue` and `BaseButton` for `app/components/base/button.vue`, each with a `Lazy` twin. `.nuxt/imports.d.ts` listed `useLoanFilter`, `loanSchema` (from `shared/types`) and `formatMoney` (from `shared/utils`). A composable in `app/composables/loan/use-nested.ts` was not listed. `Loan`, `ref`, `computed`, `toValue` and `useFetch` were used with no import in the sample's pages, components and composables, and `nuxt typecheck` and typed ESLint passed.
