# TypeScript in Nuxt

## Summary

Nuxt generates four TypeScript projects (app, server, shared and Node.js tooling) and the types of every auto-import, route and API handler. Run `nuxt typecheck` over all of them, let the handler's return type flow into `useFetch` and `$fetch`, and put each type augmentation in the directory of the project it augments. The Vue and TypeScript notes apply in full.

## Rules

### Generated types

- Let Nuxt generate the types. `nuxt prepare` (run by `postinstall`, `nuxt dev` and `nuxt build`) writes `.nuxt/`: the four `tsconfig.*.json` files, `imports.d.ts` and `components.d.ts` for auto-imports, `types/` for routes and modules, and `eslint.config.mjs` for the linter. Never edit or commit `.nuxt/`. If the editor shows missing names after a clone or a branch change, run `npx nuxt prepare`.
- Check types with `nuxt typecheck`, which runs `vue-tsc --build` over the four projects ([setup](02-project-setup-and-tooling.md#scripts)). Install `typescript` and `vue-tsc` for it. Leave `typescript.typeCheck` off, so that `dev` and `build` stay fast.
- Keep `strict` on, and add the three options of the TypeScript notes that Nuxt does not set through `typescript.tsConfig.compilerOptions`. Do not set `typescript.strict: false` except while converting a JavaScript project, in its own change.
- Write every file in TypeScript. Nuxt's generated projects keep `allowJs`, and no new `.js` file belongs in `app/`, `server/` or `shared/`.

### Type contexts

- The four projects see different globals and different files. Put code where its context is:
  - `app/` is the Vue app (browser and server rendering): DOM and Vue types.
  - `server/` is Nitro: no DOM, and Nitro's types.
  - `shared/` is both: no DOM, no Vue and no Nitro types, so it holds Zod schemas, types and pure functions.
  - the root (`nuxt.config.ts`, `modules/`, and the files in `nodeTsConfig.include`) is Node.js tooling.
- Put a type augmentation in the directory of the project it augments. A file outside the directories is in no project, and TypeScript ignores it. The sample's `PageMeta` augmentation lives in `app/types/page-meta.d.ts` and gives `definePageMeta` the keys `title` and `requiresAuth`; a wrong type for a key was error `TS2322`.

```ts
// app/types/page-meta.d.ts
declare module "#app" {
  interface PageMeta {
    title?: string;
    requiresAuth?: boolean;
  }
}

export {};
```

- Put a type that both the app and the server use in `shared/types/`, and never import a type from `app/` into `server/` or the reverse. A type imported with `import type` does not pull code across, but the documentation still says to keep API types in `shared/`.
- A type that only one side uses lives beside it: `app/types/` for the app, `server/types/` for Nitro. Both folders are auto-imported on their own side only.

### Types across the boundary

- Annotate the return type of a handler with a domain type from `shared/types/`, and the app is typed: `useFetch("/api/loans")` has `data` of `Loan[]` after the handler's `.map(...)`, and `$fetch("/api/loans", { method: "POST", body })` returns `Loan`. This is Nuxt's typed API route, and it follows the rule of the TypeScript notes that a return type is written on an exported function that other code uses ([server](06-server-routes-and-validation.md#handlers)).
- Do not write a type argument on `useFetch` or `$fetch` for your own routes (`useFetch<Loan>(...)`). It appears only in the return type, so it is what the TypeScript notes ban, and it can disagree with the handler. Nuxt infers the type of a dynamic URL, such as a template string, from the matching handler. The sample read `data` as the handler's type without an argument.
- The handler's return is a JSON type. A `Date` in the handler becomes a string in the app, and Nuxt's types show it as a string. Return ISO strings and integers, as the TypeScript notes say, so that the type is the truth.
- Validate what comes from outside. The types of your own routes are checked by the compiler, and the values at run time are checked by the schema in the handler ([server](06-server-routes-and-validation.md#validation)). A request that Nuxt cannot type (an external URL, a URL built from several strings) gives `unknown` or `any` data: do not call an external API from a page. Call it from a handler, as the [data fetching note](05-data-fetching.md#headers-cookies-and-the-server) says.
- Derive types from Zod schemas with `z.infer`, export the schema and the type from the `shared` file, and use the type in props, stores and composables. A prop type may be `Loan`, which Nuxt auto-imports from `shared/types/`.
- Type `useState` and `useCookie` with a type argument (`useState<"light" | "dark">("theme", () => "light")`), because their initial value cannot carry a union.
- Type `runtimeConfig` by writing it in `nuxt.config.ts` with defaults of the right type. `useRuntimeConfig()` is typed from it, and the environment override takes the type of the default ([state and configuration](07-state-and-configuration.md#runtime-configuration)).
- A route param is `string | string[]`. Narrow it, or reject the route with `validate` in `definePageMeta()`, as the [routing note](04-pages-routing-and-navigation.md#pages) says. Do not turn on the experimental typed pages option for it.
- Type `error` as `NuxtError` from `#app` in `error.vue`. Use `isNuxtError(error)` to narrow an `unknown` error to Nuxt's, and `instanceof Error` for the rest ([errors and security](08-errors-and-security.md#errors)).

### Imports and aliases

- Auto-imported names need no import and no type annotation. A type from a package, or a name outside the scanned directories, is imported with `import type`.
- Use `@/` for `app/`, and `#shared/` for `shared/` in imports that must be explicit, as in a handler's `import { loanSchema } from "#shared/types/loan"` and in test files. Never use `#build`, `#internal` or `#nitro` paths in application code. They are internals, and they move between versions.
- Import from `nuxt/server` in `server/`, and from `#app` or `#imports` in `app/` when you must import explicitly ([layout](03-project-layout-and-auto-imports.md#auto-imports)).
- Do not add `baseUrl` or hand-written `paths` to `tsconfig.json`. The generated files hold the aliases, and modules add theirs.

### Where the TypeScript notes change for Nuxt

- Auto-imports replace imports for Nuxt and shared names, default exports are required for pages, layouts, plugins, middleware, handlers and the two config files, and the generated projects replace a hand-written `tsconfig.json` ([principles](01-principles-and-sources.md#order-of-precedence)).
- Every other rule stays: `unknown` for external data, no `any`, no `as` to silence the compiler, no `!`, no `enum`, `import type`, named types, and `HTTP_STATUS` for every status.

## Sources and raw notes

Pages read on 2026-11-20:

- [TypeScript](https://nuxt.com/docs/guide/concepts/typescript): type-checking with `vue-tsc` and `nuxt typecheck`, `typescript.typeCheck`, auto-generated types, project references and the four generated files, augmenting types in the right context, strict checks.
- [`tsconfig.json`](https://nuxt.com/docs/directory-structure/tsconfig): the reference file, extending the configuration from `nuxt.config.ts`.
- [`shared/`](https://nuxt.com/docs/directory-structure/shared): shared types and utilities, type-only imports across the boundary.
- [Data fetching](https://nuxt.com/docs/getting-started/data-fetching): typed routes, "requests Nuxt cannot type", declaring route types, serialising data from API routes.
- [`nuxt.config`](https://nuxt.com/docs/api/nuxt-config#typescript): the `typescript` options.
- [TypeScript notes](../typescript-conventions/04-types-and-type-design.md) and [Vue notes on TypeScript](../vue-conventions/13-typescript-in-vue.md).
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `typescript.tsConfig.compilerOptions` reached all four `.nuxt/tsconfig.*.json` files; `Loan` from `shared/types/loan.ts` was used in `app/` and `server/` with no import; `useFetch` with a template-string URL typed `data` as the handler's return type, and an assignment to `number` was error `TS2322`; the `PageMeta` augmentation in `app/types/` was applied; `nuxt typecheck` passed with the type contexts above.
