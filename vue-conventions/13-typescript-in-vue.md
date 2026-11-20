# TypeScript in Vue

## Summary

Every `<script>` has `lang="ts"` and is checked by `vue-tsc`, with `strictTemplates` on so that templates are checked too. Type props, emits, models and slots with the macros, type refs by their element or value, and let inference do the rest. The TypeScript notes apply in full, with the Vue exceptions that the principles note lists.

## Rules

### Setup

- Write `<script setup lang="ts">` in every component. `vue/block-lang` makes a script without `lang="ts"` an error. A script without it is parsed as JavaScript, and the type-aware lint rules cannot run.
- Check types with `vue-tsc --build`, never with `tsc`, which cannot read `.vue` files. The Vue (Official) extension gives the same diagnostics in the editor ([setup](02-project-setup-and-tooling.md#scripts)).
- Set `vueCompilerOptions.strictTemplates` to `true` in `tsconfig.app.json`, so that a component's undeclared props, events and slots are errors ([setup](02-project-setup-and-tooling.md#tsconfig)).
- Keep `/// <reference types="vite/client" />` in `env.d.ts`, so that `import.meta.env`, asset imports and `*.css` have types. Declare your own env variables by augmenting `ImportMetaEnv` in the same file, and parse them once with a schema in one module, as the TypeScript notes say about the environment.
- A project that needs `.vue` files typed in a plain `.ts` import relies on the `*.vue` shim that `create-vue` no longer writes: the Vue (Official) extension and `vue-tsc` resolve `.vue` imports themselves. Do not add a `declare module "*.vue"` shim, because it hides prop types from the importing file.

### Props, emits, models and slots

- Type props with `defineProps<Props>()` and a local `interface Props`, emits with a type literal, models with `defineModel<T>()`, and slots with `defineSlots<{...}>()`. [Components](05-components-props-emits-and-slots.md) gives the rules, the examples and the lint rules that enforce them.
- Keep the type that you give `defineProps` simple. The compiler resolves it from the syntax tree and does not run the type checker, so it supports an interface, a type literal, an imported type, `Pick`, `Omit` and a few other built-ins, but not a conditional type for the whole object. A conditional type for a single property is fine. If a props type will not compile, simplify it, or declare it with a local interface and `extends`.
- Import a props type from another file when several components share it: `import type { Props } from "./shared-props"`. Vue supports relative paths, aliases and packages, as long as TypeScript is installed.
- Do not use `PropType`, `withDefaults()` or runtime `defineProps({ ... })` in new code. `PropType` is for the runtime declaration, and the notes use the type-based one.
- Use a literal union for a prop with a fixed set of values: `variant?: "primary" | "quiet"`. Derive it from a constant array when the values also appear at run time, as the TypeScript notes say: `export const VARIANTS = ["primary", "quiet"] as const; type Variant = (typeof VARIANTS)[number]`. Never use an `enum`: `erasableSyntaxOnly` rejects it.
- Use `Readonly` or `readonly T[]` for a prop that holds an array that the component only reads. A prop is already read-only, and `readonly T[]` says that the array is too.
- Type an emitted payload with a name for each argument: `change: [value: T, index: number]`. Name the tuple elements, because the editor shows them.

### Refs, computed values and the DOM

- Type a ref by its value: `ref<Loan[]>([])` and `ref<Loan>()`. Let inference type a ref that has a value (`ref(0)` is `Ref<number>`). `vue/require-typed-ref` reports the ones that need a type. Use `shallowRef<T>()` the same way.
- Do not annotate a `computed()`: its type comes from the getter. Annotate the return type of the getter only when it is wider than what the body returns.
- Type a template ref with the element and the key, and let it be null before mount: `const search = useTemplateRef<HTMLInputElement>("search")`. Read it as `search.value?.focus()`. Never use `!` on it.
- Type a ref to a component with `InstanceType<typeof BaseDialog>`. The type shows only what `defineExpose()` exposes.
- Type a function that is passed to a template. A handler that receives a DOM event narrows `event.currentTarget` or `event.target` with `instanceof`, as in `if (!(event.currentTarget instanceof HTMLSelectElement)) return;`. Do not cast with `as HTMLInputElement`, because the TypeScript notes forbid `as` to silence the compiler. An inline handler's `$event` is typed from the element's event.
- Type the value of `reactive()` with an interface, and never with a cast: `const form = reactive<LoanForm>({ ... })`. Prefer `ref`.
- Use `Ref<T>`, `ComputedRef<T>`, `ShallowRef<T>` and `MaybeRefOrGetter<T>` as parameter and return types. Use `Readonly<Ref<T>>` for a readonly ref that a composable returns ([composables](07-composables.md#naming-and-shape)).

### Composables

- Type the arguments and let inference type the return value of a composable used in one feature. Write the return type of a composable that other features use, as the TypeScript notes say about exported functions in `lib/` modules.
- Take `MaybeRefOrGetter<T>` and read it with `toValue()`. Take a schema as a parameter and let it carry the result type: `useFetchJson<T>(schema: z.ZodType<T>, url: MaybeRefOrGetter<string>)`. Do not write `useFetch<T>(url)`, where the type parameter appears only in the return type.
- Return a plain object, so that each member keeps its type when it is destructured ([composables](07-composables.md)).

### Provide, inject and the store

- Type the key, not the call: `const THEME_KEY: InjectionKey<Readonly<Ref<"light" | "dark">>> = Symbol("theme")`. Then `provide(THEME_KEY, value)` checks the value, and `inject(THEME_KEY)` returns the type or `undefined`. Do not use a string key with a type argument on `inject`.
- A Pinia setup store is typed by what it returns, so write no interface for it. Type the refs inside it: `ref<Loan[]>([])`.
- Give a router `meta` a type by augmenting `RouteMeta`, and give route params a type in the component through props: `defineProps<{ id: string }>()`. Parse a numeric param in the route's `props` function, where it is still a string ([routing](09-routing-and-data-fetching.md#routes)).

### Generics

- Declare a generic component with the `generic` attribute: `<script setup lang="ts" generic="T extends { id: string }">`. Use `T` in props, emits, the model and the slots. Constrain it, and name it `T`, `K` or a short UpperCamelCase word, as the TypeScript notes say.
- A composable gets an ordinary type parameter. Add one only when the function works on several types.

### Data and boundaries

- Treat everything from outside as `unknown` until a schema accepts it: a response, `JSON.parse`, `localStorage`, the route query, `postMessage`, `import.meta.env`. Never write `as Loan[]` on a response, as the TypeScript notes say ([data fetching](09-routing-and-data-fetching.md#data-fetching)).
- Derive a type from its schema with `z.infer<typeof loanSchema>`, and export the schema and the type from the feature's `loan.ts`. Do not write the same shape twice. A prop type may then be `Loan`.
- A route `query` value is `string | string[] | null | undefined`. Narrow or parse it before use.

### Where the TypeScript notes change for Vue

- A `.vue` file is a default export, and it is imported with its extension. Everything else follows the named-export rule of the TypeScript notes ([layout](03-project-layout-and-naming.md#exports-and-imports)).
- The props interface is a local `Props`, and the events are a type literal, not named interfaces ([principles](01-principles-and-sources.md#order-of-precedence)).
- A template event handler may be `async`, and Vue handles its rejection ([errors and async](10-errors-and-async.md#event-handlers)).
- Every other rule stays: no `any`, no `as` to silence the compiler, no `!`, no `enum`, named types for domain shapes, `unknown` for external data, `import type`, and the six compiler options.
- `@ts-ignore` and `@ts-nocheck` stay banned, and `// @ts-expect-error` needs a description. In a template, the comment that expects a type error on the next line is `<!-- @vue-expect-error reason -->`; it reports an error itself when the next line has none. Use it as rarely as the script one.

## Sources and raw notes

Pages read on 2026-11-20:

- [Using Vue with TypeScript: overview](https://vuejs.org/guide/typescript/overview.html): `lang="ts"`, `vue-tsc`, the Vue (Official) extension, `tsconfig` settings.
- [TypeScript with the Composition API](https://vuejs.org/guide/typescript/composition-api.html): type-based props and the syntax limitations (supported since 3.3, no conditional type for the whole object), reactive props destructure for defaults, `withDefaults()` for 3.4 and below, emits, slots, `ref()` typing, `reactive()`, `computed()`, event handlers, `provide`/`inject` with `InjectionKey`, template refs, component template refs.
- [`<script setup>`](https://vuejs.org/api/sfc-script-setup.html): the `generic` attribute, `defineSlots`, `defineModel`.
- [`@vue/tsconfig`](https://github.com/vuejs/tsconfig) 0.9.1 and [`vue-tsc`](https://github.com/vuejs/language-tools) 3.3.14: `vueCompilerOptions.strictTemplates`.
- The [TypeScript notes](../typescript-conventions/04-types-and-type-design.md) for `unknown`, `as`, `!`, enums, derived types and generics.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): type-based props with a destructured default, typed emits and models, a generic component with a scoped slot, `useTemplateRef<HTMLInputElement>`, `InstanceType<typeof BaseDialog>`, an `InjectionKey`, a typed `RouteMeta`, a Pinia setup store, and a composable that takes a Zod schema. `vue-tsc --build` ran with 0 errors, with `strictTemplates` on. An undeclared prop on a component gave `TS2353`. `<!-- @vue-expect-error reason -->` silenced the error on the next line, and `vue-tsc` reported `TS2578` for the same comment above a line with no error.
