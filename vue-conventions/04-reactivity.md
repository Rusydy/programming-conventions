# Vue Reactivity

## Summary

Declare state with `ref()`, derive values with `computed()`, and reach for `watch()` only to talk to something outside the component. Keep reactive state shallow and plain, mutate it in place, and never copy a value into other state just to keep two values in step. Lifecycle hooks set up and tear down what a component owns.

## Rules

### `ref` and `reactive`

- Declare state with `ref()`. The Vue documentation recommends `ref()` as the primary API, because `reactive()` works only on objects, cannot be reassigned, and loses reactivity when you destructure it. Read and write a ref through `.value` in the script. The template unwraps top-level refs.
- Use `reactive()` only for a fixed-shape object that you never reassign or destructure and that lives in one scope. Most code needs no `reactive()`; a `ref` holding an object is deeply reactive too.
- Type an empty ref with its type argument: `ref<Loan[]>([])` and `ref<string>()`. The second is `Ref<string | undefined>`. `vue/require-typed-ref` reports an untyped empty `ref()`.
- Mutate deep state in place (`loans.value.push(loan)`, `form.value.name = "x"`). Replace the whole value when you load fresh data from the server.
- Use `shallowRef()` for a large value that you replace whole, such as a long list or a parsed document. A change inside it does not trigger an update, and the sample run confirmed that a `watch` on a `shallowRef` ran 0 times after `sh.value.x = 2`. Use `markRaw()` for an object that must never be proxied, such as a class instance from a library.
- A `ref` or `reactive` holding a `Map` or `Set` is reactive in Vue 3. Use the built-in collections, and read them through the ref.
- Do not destructure a `reactive` object or read one of its properties into a plain variable if it must stay reactive: `const { n } = state` copies the value, and the sample run kept `n` at `1` after `state.n = 2`. Use `toRef(state, "n")` or `toRefs(state)`. Destructuring `defineProps()` is the exception, because the compiler rewrites it ([components](05-components-props-emits-and-slots.md#props)).
- A ref nested in an object is not unwrapped in a template expression such as `{{ state.count.value + 1 }}`; only a top-level ref is. Expose a top-level ref, or a computed value, for the template.
- `structuredClone()` throws a `DataCloneError` on a reactive proxy. Pass the raw value: `structuredClone(toRaw(form.value))`. The sample run cloned the raw value and failed on the proxy. A value whose nested objects were once proxied needs a deep copy of the data instead.
- Expose state read-only with `readonly()` when a composable or a store must not let callers write to it.

### `computed`

- Every value that you can compute from state is a `computed()`. Write the getter as a pure function: no side effects, no mutation of other state, no `await`. `vue/no-side-effects-in-computed-properties` and `vue/no-async-in-computed-properties` enforce this, and the style guide says to keep computed properties simple.
- Use `computed()` instead of a function in the template, for a value that you read more than once. A computed value caches until its dependencies change; a method call runs on every render.
- Return a stable value. Vue 3.4 and later trigger a computed's dependents only when its result changes under `Object.is`, but a getter that returns a new object each time triggers them every time. Return a primitive where one will do.
- A writable computed (`computed({ get, set })`) is for a value that has a clear inverse, such as a full name from two fields. Keep the setter free of side effects.
- A computed value is read-only. Never assign to `.value` of a plain `computed()`.

### Watchers

- `watch()` and `watchEffect()` are for side effects: a request, a DOM or storage write, analytics, a third-party library. Never use one to copy state into other state; write a `computed()` instead. If you must reset a draft when a prop changes, key the component or use a computed with a setter ([components](05-components-props-emits-and-slots.md#props)).
- Prefer `watch(source, callback)` to `watchEffect()` when the effect must run for specific sources only. A `watch` source is a ref, a getter, a reactive object or an array of those. Watch a prop or a reactive property with a getter: `watch(() => id, load)`.
- `watchEffect()` runs at once and tracks every reactive value that it reads before the first `await`. Reads after an `await` are not tracked, so read what the effect needs first. `vue/no-watch-after-await` helps, and the notes do not enable it separately.
- `watch()` is lazy by default. Add `{ immediate: true }` for a first run, and `{ once: true }` (3.4) for a single run. `{ deep: true }` walks the whole object, and Vue 3.5 accepts a number for the maximum depth. Do not set `deep` on a large structure.
- Clean up in the watcher. Return nothing from the callback and call `onWatcherCleanup()` (3.5) synchronously, before any `await`, to abort the previous request:

```ts
import { onWatcherCleanup, ref, watch } from "vue";

const loans = ref<Loan[]>([]);

watch(
  () => query.value,
  async (text) => {
    const controller = new AbortController();
    onWatcherCleanup(() => controller.abort());
    loans.value = await fetchLoans(text, controller.signal);
  },
);
```

- The default `flush` is `"pre"`: the watcher runs before the component updates. Use `{ flush: "post" }`, or `watchPostEffect()`, when the callback reads the updated DOM.
- Watchers created in `<script setup>` stop with the component. A watcher created after an `await`, or outside a component, must be stopped through the function that `watch()` returns, or created in an `effectScope`. A watcher that you pause and resume uses the `pause()` and `resume()` of the handle (3.5).
- Do not mutate the watched source inside its own callback.
- Use `nextTick()` only to read the DOM after a state change. The DOM updates asynchronously, and many changes in one tick make one update.

### Lifecycle

- Call a lifecycle hook synchronously from `<script setup>` or a composable that a component runs. A hook after an `await` has no instance to attach to.
- Use `onMounted()` for anything that needs the DOM or the browser (`window`, `document`, a measured element). It does not run on the server, so the same code is safe in a project that renders on the server later.
- Clean up what you start: remove the event listener, clear the timer, abort the request, close the connection. Do it in `onUnmounted()` in a component. In a composable, use `onScopeDispose()`, which also works inside an `effectScope` and in a store.
- Do not use `onBeforeMount`, `onUpdated` or `onBeforeUpdate` for state changes. They exist for the DOM, and a state change in `onUpdated()` can loop.
- Prefer a watcher on state to `onUpdated()`. Prefer a `computed()` to either.
- Do not name a function `created` or `mounted`. Those are Options API hooks and do not exist in `<script setup>`.

### Debugging

- Log a plain value, not a proxy: `console.log(toRaw(state))` or `JSON.stringify` it. Use the Vue devtools to inspect state, and `onRenderTracked()` and `onRenderTriggered()` (development only) to find what re-renders a component. Remove them before you commit.

## Sources and raw notes

Pages read on 2026-11-20:

- [Reactivity fundamentals](https://vuejs.org/guide/essentials/reactivity-fundamentals.html): `ref()` as the recommended API, deep reactivity, DOM update timing, `reactive()` limitations (only objects, no reassignment, no destructuring), refs in templates and nested refs.
- [Reactivity in depth](https://vuejs.org/guide/extras/reactivity-in-depth.html): proxies, `shallowRef`, `markRaw` and the design of tracking.
- [Computed properties](https://vuejs.org/guide/essentials/computed.html): the getter must be pure, caching, stability since 3.4, writable computed.
- [Watchers](https://vuejs.org/guide/essentials/watchers.html): `watch`, `watchEffect`, `flush`, `deep` as a number (3.5), `once` (3.4), `onWatcherCleanup()` (3.5, synchronous only), stopping, pause and resume.
- [Lifecycle hooks](https://vuejs.org/guide/essentials/lifecycle.html) and [Composition API: lifecycle](https://vuejs.org/api/composition-api-lifecycle.html): hooks must be called synchronously during `setup()`.
- [Vue style guide, strongly recommended](https://vuejs.org/style-guide/rules-strongly-recommended.html): simple computed properties.
- Checked on 2026-11-20 with Vue 3.5.45 in Node.js, in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): `structuredClone()` of a `ref` value threw `DataCloneError`, and `structuredClone(toRaw(value))` returned the data. A `watch` on `m.value.get("b")` of a `ref(new Map())` ran once after `m.value.set("b", 2)`. `const { n } = reactive({ n: 1 })` stayed `1` after the property changed to `2`. A `watch` on a `shallowRef` ran 0 times after a nested change. A `computed()` returned the same object across two reads.
