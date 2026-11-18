# Svelte State Sharing and Context

## Summary

Share state in the smallest scope that works: props first, then context, then a module-level instance. Put reactive state that several components use in a class in a `.svelte.ts` file, and hand it to the tree with `createContext`. Write no new stores.

## Rules

### Choose the scope

1. **Props.** Pass state down one or two levels, and report changes up with callback props.
2. **Context.** Use it for state that a whole subtree needs, such as a form, a list with a selection or a theme, when passing props would cross many components that do not use them.
3. **Module-level instance.** Use it only for state that exists once for the whole application and never differs between users or windows, such as the application settings of a client-only app.

- Move to the next scope when passing the value through components that ignore it makes the code harder to read, not before. Do not create a context "just in case".
- Do not share state with a store, a custom event or a `window` property.

### State in a class

- Put reactive state that several components share in a class in a `.svelte.ts` module. Give it `$state` and `$state.raw` fields, `$derived` fields and methods:

```ts
// loan-list.svelte.ts
import { createContext } from "svelte";

import type { Loan } from "./loan";

export class LoanList {
  loans = $state.raw<Loan[]>([]);
  selectedId = $state<string>();

  open = $derived(this.loans.filter((loan) => loan.status === "open"));
  selected = $derived(this.loans.find((loan) => loan.id === this.selectedId));

  select = (id: string): void => {
    this.selectedId = id;
  };
}

export const [getLoanList, setLoanList] = createContext<LoanList>();
```

- This is the one deliberate extension of the [TypeScript rule on classes](../typescript-conventions/08-functions-classes-and-async.md#classes), which allows a class for an `Error` and for an object that owns a resource and its lifecycle. `$state` and `$derived` work on class fields, and the compiler turns them into accessors on the prototype. The Svelte documentation uses classes for shared state for this reason. A reactive container holds the state that its methods change, which is an object that owns its lifecycle.
- The other class rules of the TypeScript notes still apply. Do not use parameter properties, which `erasableSyntaxOnly` rejects, so declare the field and assign it in the constructor. Mark a field that never changes `readonly`, and use `override` on an overriding method. Do not build an inheritance chain.
- A class instance is not proxied, so put `$state` on its fields. Assigning a new array to `loans` updates every reader, and `$state.raw` avoids proxying a large list that the code replaces as a whole.
- Write a method that you pass as a callback as an arrow-function field (`select = (id) => {}`), so that `this` stays bound. A normal method loses `this` when passed as `onSelect={list.select}`. The other fix is an inline arrow function at the call site.
- Keep a function that works on plain data out of the class: filtering rules and formatting belong in `.ts` files that need no runes.
- Write a smaller piece of reactive logic that has no identity as a function that returns an object with getters, or as a class when it keeps several fields.
- Do not name the class after the mechanism. `LoanList` is right and `LoanListStore` is not.

### Context

- Create context with `createContext<T>()` from `svelte` (Svelte 5.40). It returns a typed `[get, set, has]` triplet with no string key. Export the pair from the module that defines the type, as above.
- Call `set` in the parent during component initialisation, and `get` in a descendant, also during initialisation. `get` throws when no ancestor called `set`, so a consumer receives `T` and never `T | undefined`. This is the same guard that the [React note](../typescript-conventions/11-typescript-in-react.md#hooks) writes by hand.
- Use `has` only to make a context optional, such as a component that works with or without a parent.
- Put a reactive object or class instance in context, and mutate its properties. Reassigning a state variable that you put in context breaks the link between parent and child, and Svelte warns about it. For a primitive, pass a getter function.
- Create the instance in the parent that calls `set`, so each mounted tree has its own state:

```svelte
<script lang="ts">
  import { LoanList, setLoanList } from "@/lib/loans/loan-list.svelte";
  import LoanPanel from "@/lib/loans/loan-panel.svelte";

  const list = new LoanList();
  setLoanList(list);
</script>

<LoanPanel />
```

- Context is not shared between server requests, so it is the safe choice when state must stay per user. A module-level instance on a server leaks one user's data to the next request. That matters for SvelteKit and does not for a client-only app such as a Wails frontend ([principles](01-principles-and-sources.md#applying-the-notes)).
- A component test that needs a context renders a small wrapper component that calls `set` and then renders the component under test ([testing](10-testing.md#component-tests)).

### Module-level instance

- Export one instance from a `.svelte.ts` module when the state is a true application singleton and the app has no server rendering:

```ts
// settings.svelte.ts
class Settings {
  theme = $state<"light" | "dark">("light");
}

export const settings = new Settings();
```

- Export the instance, and never a reassigned `$state` variable. An importer receives the signal and not the value, so the compiler rejects a reassigned export.
- Do not mutate a module-level instance while the module runs on a server.
- In a test, create a fresh instance, or reset the singleton in `beforeEach`, so that tests do not share state.

### Stores

- Write no new `writable`, `readable` or `derived` stores. Runes cover what stores did, and they work outside components, in `.svelte.ts` files.
- Keep an existing store until a change rewrites it. The documentation keeps stores as a supported feature.
- Use a store only where the documentation says it is still a good fit: a complex asynchronous data stream, a case that needs manual control over updates and listeners, or a codebase that already uses RxJS. A library may also return one.
- Wrap an event source that is not a store with `createSubscriber` from `svelte/reactivity` ([runes](04-runes-and-reactivity.md#reactive-built-ins)).

## Sources and raw notes

Pages read on 2026-11-18:

- [Context](https://svelte.dev/docs/svelte/context): `createContext` since 5.40 and its `get` error, `setContext` and `getContext`, reactive state in context, the warning when the link breaks, module state and server rendering, wrapper components for tests.
- [`$state`](https://svelte.dev/docs/svelte/$state): classes, `this` in callbacks, passing state by value, exports of a `.svelte.ts` module. [Stores](https://svelte.dev/docs/svelte/stores): runes diminished the need, and the three cases where stores are still a good solution.
- [Changelog of Svelte](https://github.com/sveltejs/svelte/blob/main/packages/svelte/CHANGELOG.md): `createContext` in 5.40, usable when instantiating components in 5.50, `has` in 5.57. `svelte@5.58.0` types: `createContext<T>(): [() => T, (context: T) => T, () => boolean]`.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `loan-list.svelte.ts` and its context pair passed `svelte-check` and ESLint, `loan-panel.svelte` read it through `getLoanList()`, and `loan-list.svelte.test.ts` ran under Vitest 5.1.1 in Node.js with `flushSync`.
