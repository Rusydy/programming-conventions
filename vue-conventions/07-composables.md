# Vue Composables

## Summary

A composable is a function that uses Vue's reactivity and lifecycle to package stateful logic. Name it `useX`, accept values, refs or getters, return a plain object of refs, and clean up whatever it starts. Extract one when logic has its own state and is used twice, or when it makes a component easier to read, and not before.

## Rules

### When to write one

- Write a composable for logic that has reactive state or a lifecycle: a search box with a filtered list, a fetch with loading and error state, a media query, an event listener that must be removed. A function that only transforms values is a plain function in a `.ts` file, with no `use` prefix and no Vue import.
- Extract a composable when a second component needs the same stateful logic, or when a component's script is long and the logic splits cleanly into named parts. The Vue documentation lists both reasons. Do not extract one "just in case".
- Keep a composable that only one component uses next to that component, in the feature folder (`use-loan-list.ts` beside `loan-list-view.vue`). Move it to `src/shared/` after a second feature needs it ([layout](03-project-layout-and-naming.md#where-code-lives)).
- A composable is not a store. State that lives inside the call belongs to the component that called it, and each call makes its own copy. State that must be shared across components goes in a Pinia store ([state management](08-state-management-and-provide-inject.md)).

### Naming and shape

- Name the file `use-loan-list.ts` and the function `useLoanList`. The name says what the composable gives you, not how it works: `useLoanList`, `useMediaQuery`, `useFetchJson`.
- Use named exports. Write `export function useLoanList(...)`, as the TypeScript notes say, and give the exported function its return type when it is not obvious.
- Return a plain object of refs and functions, and never a `reactive()` object. A caller can then destructure the result and keep the connection: `const { query, visible } = useLoanList(loans)`. A reactive object would lose it on destructuring. A caller that wants property access wraps the result in `reactive()`.
- Return `readonly()` refs for state that the caller must not write, such as `data`, `error` and `isLoading` in a fetch composable. Return a writable ref for state that the caller owns, such as `query`.
- Name a returned boolean like a question (`isLoading`, `hasError`), as the TypeScript notes say.
- Keep the return value small. A composable that returns twenty values does several jobs; split it.

### Arguments

- Accept `MaybeRefOrGetter<T>` for an input that may change, and read it with `toValue()` inside a computed value or a watcher. This accepts a plain value, a ref and a getter, which is how a destructured prop passes in as `() => id`. Vue documents `toValue()` and `MaybeRefOrGetter` for this purpose:

```ts
import { computed, ref, toValue, type MaybeRefOrGetter } from "vue";

import type { Loan } from "./loan";

export function useLoanList(source: MaybeRefOrGetter<readonly Loan[]>) {
  const query = ref("");
  const visible = computed(() =>
    toValue(source).filter((loan) =>
      loan.borrower.toLowerCase().includes(query.value.toLowerCase()),
    ),
  );
  return { query, visible };
}
```

- Call `toValue()` inside the reactive scope that should track it (`computed`, `watch` getter, `watchEffect`). Calling it once at the top of the function reads the value once, and a later change goes unseen.
- Take at most three positional parameters, and an options object after that, as the TypeScript notes say. Give the options an `interface` and read them by destructuring.
- Do not take a component instance, `this` or a props object. Take the values that the composable needs.

### Side effects and cleanup

- A composable may add an event listener, start a timer, open a connection or fetch. It must stop what it starts, so that a component that unmounts leaves nothing behind. Use `onScopeDispose()` in a composable: it runs when the component unmounts, when an `effectScope()` stops, and when a store is disposed. Use `onUnmounted()` only in a component:

```ts
import { onScopeDispose } from "vue";

export function useEventListener<K extends keyof WindowEventMap>(
  type: K,
  listener: (event: WindowEventMap[K]) => void,
) {
  window.addEventListener(type, listener);
  onScopeDispose(() => window.removeEventListener(type, listener));
}
```

- Abort a request when its input changes or the scope ends. Use `AbortController` with `onWatcherCleanup()` (3.5), and ignore the error of an aborted request ([errors and async](10-errors-and-async.md#requests)):

```ts
watchEffect(() => {
  const target = toValue(url);
  const controller = new AbortController();
  onWatcherCleanup(() => controller.abort());
  void load(target, controller.signal);
});
```

- Touch the DOM or `window` after mount only, if the app might render on the server one day. A composable that reads `document` at call time breaks in the `unit` test project, which runs in Node.js. The sample run failed with `document is not defined` until the DOM access moved out of the composable. Test that composable in the `component` project, or pass the target in as an argument.
- Call a composable synchronously from `<script setup>` or from another composable, at the top level of the function. A call after an `await`, inside a condition or in an event handler has no component instance, so a lifecycle hook or a watcher would attach to nothing, and Vue warns.
- A watcher created inside a composable stops with the component that called it. A watcher created after an `await` does not, so create watchers before any `await`.

### State in a composable

- Create the state inside the function. State at module level is shared by every caller, so it is a store in disguise, and it leaks across requests in a server-rendered app. When you do want shared state, write a Pinia store.
- Use `shallowRef()` for a large value that you replace whole, such as the data of a fetch, and validate it first ([data fetching](09-routing-and-data-fetching.md#data-fetching)).
- Keep a composable pure of the component: no `getCurrentInstance()`, no `$el`, no emitting. If it must tell the component something, it returns a ref or takes a callback.

### VueUse

- Use the platform before a package. A browser API that already does the job (`matchMedia`, `IntersectionObserver`, `localStorage`) is wrapped in a small composable of your own.
- Add VueUse (`@vueuse/core`) when it replaces more than a few of your own composables, and say so in the pull request. It is tree-shakeable, so you import only the functions that you use: `import { useEventListener } from "@vueuse/core"`. It is a dependency like any other, and it follows the same cleanup rules as these notes.
- Do not import VueUse for a one-line function. `useEventListener` above is eight lines.

### Testing and typing

- Test a composable as a plain function when it has no lifecycle hook, and inside an `effectScope()` when it has one or creates watchers. `scope.run(() => useX())` returns the result, and `scope.stop()` runs the cleanup ([testing](12-testing.md#logic-tests)).
- Type the arguments and let inference type the return value. Write the return type of a composable that other features use ([TypeScript in Vue](13-typescript-in-vue.md#composables)).
- Do not use a composable in a template. Call it in the script and expose the refs.

## Sources and raw notes

Pages read on 2026-11-20:

- [Composables](https://vuejs.org/guide/reusability/composables.html): what a composable is, the mouse tracker and async state examples, accepting reactive state with `toValue()`, naming (`use` prefix), input arguments, return values (a plain object of refs, never `reactive()`), side effects and cleanup, usage restrictions (synchronous, in `setup()`), extracting composables for organisation.
- [Reactivity utilities](https://vuejs.org/api/reactivity-utilities.html): `toValue()`, `MaybeRefOrGetter`.
- [Watchers](https://vuejs.org/guide/essentials/watchers.html): `onWatcherCleanup()`.
- [Effect scope API](https://vuejs.org/api/reactivity-advanced.html): `effectScope()`, `onScopeDispose()`.
- [VueUse](https://vueuse.org/) 15.0.0 on npm: version only; the notes make no claim about its functions beyond `useEventListener` existing.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): `useLoanList` with `MaybeRefOrGetter`, `useEventListener` with `onScopeDispose`, and `useFetchJson` with `onWatcherCleanup`, a Zod schema, `AbortSignal.any()` with a five-second timeout, `shallowRef` and `readonly()`. Two unit tests ran the fetch composable in an `effectScope()` with a stubbed `fetch`: one loaded `/a`, refetched after the `url` ref changed to `/b`, and one reported a body that the schema rejects as an `Error`. A composable that wrote `document.title` in `watchEffect` failed in the Node.js `unit` project. `vue-tsc`, ESLint and Prettier ran with 0 errors.
