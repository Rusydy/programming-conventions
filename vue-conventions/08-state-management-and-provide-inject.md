# Vue State Management and Provide/Inject

## Summary

Keep state in the component that owns it, pass it down with props and up with events, and reach for a store only when two distant components need the same state. Pinia is the store, written as a setup store that reads like a composable. Use provide and inject for dependencies that a whole subtree shares, with a typed key.

## Rules

### Where state lives

- Put state in the lowest component that needs it. Lift it to a parent when two siblings need it, as the Vue documentation says about one-way data flow.
- Use a composable for stateful logic that each caller owns ([composables](07-composables.md)), and a store for state that every caller must see the same copy of.
- A value that you can compute from other state is not state. Write a `computed()`.
- Server data is not client state. Hold it in the component that shows it, or in a query cache once two components share it ([data fetching](09-routing-and-data-fetching.md#data-fetching)). Do not copy a response into a Pinia store only to read it from another component, unless that component edits it.
- Keep the URL as state for anything the user may want to share or bookmark: a search text, a filter, a page number, an open tab. Read it from `route.query` ([routing](09-routing-and-data-fetching.md#routes)).
- Do not keep a module-level `ref()` or `reactive()` as a shared store. It works, and the Vue documentation shows it as simple state management, but it leaks between requests when the app renders on the server and has no devtools support. Use Pinia for shared state.

### Pinia

- Install Pinia only when the project has shared state. Use `createPinia()` in `main.ts` and `app.use(pinia)`, as the scaffold writes. Pinia 4 is ESM-only and has `@vue/devtools-api` and Vue 3.5.11 as peer dependencies, which npm 7 and later install.
- Write a setup store: `defineStore("loan", () => { ... })`. Declare state with `ref()`, getters with `computed()`, and actions as functions, and return everything that the store exposes. The Pinia documentation offers option stores too, and `create-vue` writes a setup store. A setup store reads like a composable, so every rule about refs and computed values applies:

```ts
export const useLoanStore = defineStore("loan", () => {
  const loans = ref<Loan[]>([]);
  const selectedId = ref<string>();

  const selected = computed(() =>
    loans.value.find((loan) => loan.id === selectedId.value),
  );

  function add(loan: Loan) {
    loans.value.push(loan);
  }

  function select(id: string) {
    selectedId.value = id;
  }

  return { loans, selected, add, select };
});
```

- Name the store `useLoanStore`, give it a unique id (`"loan"`), and put it in `loan-store.ts` ([naming](03-project-layout-and-naming.md#naming)). One store holds one subject. Do not write a single root store.
- Call `useLoanStore()` inside `setup()`, an action, a router guard or another function that runs after `app.use(pinia)`. Never call it at the top level of a module, because no Pinia exists then.
- Change state through an action, or through a ref that the store returns, and never through `store.$patch()` unless you set several fields at once. An action is a function that you can name, test and log.
- Return every state ref from a setup store. The Pinia documentation says a setup store must return all state properties for Pinia to pick them up, so it cannot hold private state. Keep a helper function or a constant that is not state as a local, and do not return it.
- Do not destructure a store, because that detaches the state from it. Read `store.loans` in the script and the template. When you need a ref, use `storeToRefs(store)` for state and getters, and destructure actions from the store directly: `const { selected } = storeToRefs(store); const { select } = store;`.
- Do not copy a store ref into a component `ref()` to edit it. Edit a draft in a local `ref`, then call an action to save it.
- Reset a setup store with an action that you write, named `$reset`, as the Pinia documentation shows. The built-in `$reset()` exists for option stores only.
- Watch a store from a component with `watch(() => store.loans, ...)`. Use `store.$subscribe` only in a plugin.
- Do not put the whole API layer in a store. Fetching goes in a composable or a query library, and the store receives the result.
- Add `pinia-plugin-persistedstate` or your own plugin only for a reason that you write down. Do not store tokens in `localStorage` for convenience ([security](11-performance-and-security.md#security)).
- Test a store as a plain module, with `setActivePinia(createPinia())` in `beforeEach` ([testing](12-testing.md#logic-tests)).

### Provide and inject

- Use `provide()` and `inject()` for a dependency that many descendants use and that props would force through several levels: a theme, a form context, a user session in a layout, a tab-group's state. Do not use them for ordinary data flow. A value injected from far away is harder to trace than a prop.
- Create the key in its own module as an `InjectionKey`, with a `Symbol`, named in CONSTANT_CASE like any module-level constant of the TypeScript notes: `export const THEME_KEY: InjectionKey<Readonly<Ref<"light" | "dark">>> = Symbol("theme")`. A string key can collide, and a symbol key gives `inject()` a type.
- Provide a `readonly()` ref, and expose a function for each change, so that a descendant cannot write to the state. The Vue documentation recommends `readonly()` for this reason. Keep every mutation inside the provider.
- Wrap both calls in functions, so that the consumer has a single place that fails loudly when the provider is missing:

```ts
export function provideTheme() {
  const theme = ref<"light" | "dark">("light");
  provide(THEME_KEY, readonly(theme));
  return theme;
}

export function useTheme() {
  const theme = inject(THEME_KEY);
  if (!theme) {
    throw new Error("useTheme() needs provideTheme() in an ancestor");
  }
  return theme;
}
```

- Call `provide()` and `inject()` synchronously from `setup()`, like any composable. Use `app.provide()` for a value that the whole app shares, such as a client.
- Pass a default to `inject(key, default)` only when the dependency is optional. Otherwise fail, as above. `inject()` returns `T | undefined` without a default.
- Do not provide a plain mutable object. A descendant that mutates it changes state that the provider does not know about.
- For a compound component (a tab group, an accordion), provide from the parent and inject in the children, and keep the key private to the folder.

### Server rendering

- If the app ever renders on the server, create the app, router and Pinia in a factory function so that each request gets its own instance. State in a module-level variable would be shared by every user. Nuxt does this for you. A client-only Vite app does not need a factory.

## Sources and raw notes

Pages read on 2026-11-20:

- [State management](https://vuejs.org/guide/scaling-up/state-management.html): what state management is, simple state with `reactive()`, SSR considerations, Pinia as the recommended store.
- [Provide and inject](https://vuejs.org/guide/components/provide-inject.html): prop drilling, app-level provide, injection defaults, working with reactivity, `readonly()`, symbol keys in a dedicated file.
- [Vue and TypeScript: provide and inject](https://vuejs.org/guide/typescript/composition-api.html): `InjectionKey`.
- [Pinia documentation](https://pinia.vuejs.org/) and the [Pinia 4.0.0 release notes](https://github.com/vuejs/pinia/releases/tag/v4.0.0) (2026-07-14): ESM only, `@vue/devtools-api` v8 installed alongside `pinia`; 4.1.0 (2026-10-14): `getStores()`. The [core concepts](https://pinia.vuejs.org/core-concepts/) page (read from the `v4` branch of the repository): setup stores, that all state must be returned, that a store cannot be destructured, `storeToRefs()`. The [state](https://pinia.vuejs.org/core-concepts/state.html) page: `$reset()` in option stores and a hand-written `$reset()` in setup stores.
- `pinia@4.1.0` `package.json`, read from `node_modules`: peer dependencies `@vue/devtools-api ^8.2.1`, `typescript >=5.6.0` and `vue ^3.5.11`.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): the `useLoanStore` setup store above, with a unit test that calls `setActivePinia(createPinia())` in `beforeEach`, adds a loan, selects it, and reads `selected` through `storeToRefs()`; `provideTheme()` and `useTheme()` with an `InjectionKey` and `readonly()`. `vue-tsc`, ESLint, Prettier, Vitest and `vite build` ran with 0 errors.
