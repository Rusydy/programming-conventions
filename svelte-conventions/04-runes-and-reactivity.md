# Svelte Runes and Reactivity

## Summary

State is `$state`, and everything computed from state is `$derived`. An `$effect` is an escape hatch for the outside world, such as a third-party library, a canvas or analytics, and it never copies one piece of state into another. Reactive code lives in components and in `.svelte.ts` modules alike, and the same rules apply in both.

## Rules

### `$state`

- Declare a variable with `$state` only when a change to it must update the UI or a derived value. Keep other values as `const` or plain `let`. The compiler warns with `non_reactive_update` when a plain variable is reassigned and read in a reactive place.
- Mutate a `$state` object or array in place: `todos.push(todo)`, `todo.done = true`. Svelte wraps plain objects and arrays in a deep proxy, and the update reaches only the markup that reads that property.
- Use `$state.raw` for a large value that you replace as a whole and never change in place, such as a list that came from the server. A raw value skips the proxy. Assign a new array or object to update it. The class in the [state sharing note](07-state-sharing-and-context.md#state-in-a-class) uses `$state.raw` for its list of loans.
- A class instance is not proxied. Give the class `$state` fields instead.
- Give a `$state` that starts empty its type as a type argument: `$state<string>()` has the type `string | undefined`, and `$state<Loan[]>([])` has the type `Loan[]`. A value without an initial value is `undefined`.
- Do not destructure reactive state when you need it to stay reactive. `let { name } = user` reads `name` once. Read `user.name`, or wrap it in `$derived`.
- Pass a getter, not the value, when a function must read the current value later: `watch(() => count)`. A call such as `watch(count)` passes the value at the time of the call.
- Use `$state.snapshot(value)` to get a plain copy of a proxy before you hand it to code that does not expect a proxy, such as `structuredClone` or a library call.
- Use `$state.eager` only with `await` expressions, and only for feedback to a direct user action. This set does not use `await` expressions ([errors and async](09-errors-and-async.md#async-in-components)).

```svelte
<script lang="ts">
  interface Todo {
    id: string;
    text: string;
    done: boolean;
  }

  let todos = $state<Todo[]>([]);

  function toggle(todo: Todo): void {
    todo.done = !todo.done;
  }
</script>
```

- A `.svelte.ts` module cannot export a `$state` variable that you reassign, because an importer receives the signal and not the value. Export an object whose properties you change, a class, or functions that read and write the variable ([state sharing](07-state-sharing-and-context.md)).

### Reactive built-ins

- A plain `Map`, `Set`, `Date`, `URL` or `URLSearchParams` in `$state` is not reactive inside. Use the classes of `svelte/reactivity` instead: `SvelteMap`, `SvelteSet`, `SvelteDate`, `SvelteURL` and `SvelteURLSearchParams`. `svelte/prefer-svelte-reactivity` reports the plain forms.
- The values inside a `SvelteMap` or a `SvelteSet` are not deeply reactive. Replace a value to update it.
- Use `MediaQuery` from `svelte/reactivity` to branch on a media query in code. Use a CSS media query when CSS can do the job, because the class cannot know the value during server rendering.
- Use `createSubscriber` to make an external source reactive, such as an `IntersectionObserver` or a WebSocket. It starts listening only while something reads the value.
- Do not wrap another reactive source in a store. Write a function or a class with `$state` and `$derived` ([state sharing](07-state-sharing-and-context.md#stores)).

### `$derived`

- Compute every value that depends on other state with `$derived`. The compiler tracks the reads, caches the result and recalculates it only when a dependency changes and the value is read.
- Write a single expression as `$derived(expression)`. Write several statements as `$derived.by(() => { ... })`.
- A derived expression has no side effects. Svelte rejects a write such as `count++` inside it.
- Do not copy state with an effect when a derived does the job. `svelte/prefer-writable-derived` reports the pair of `$state` and `$effect`.
- A derived can be assigned a new value since Svelte 5.25, and it returns to the computed value when a dependency changes. Use it for an optimistic update or for a local edit of a computed value, and declare the derived with `const` where no assignment is intended.
- A derived does not proxy its value. When it returns an object from deep `$state`, writes through it still update that state.
- Do not use a derived to start work, such as a request. That is an effect, or an event handler.

```svelte
<script lang="ts">
  let first = $state("Ayu");
  let last = $state("Lestari");
  const full = $derived(`${first} ${last}`);
</script>
```

### `$effect`

- Reach for `$effect` only to talk to something outside Svelte: a third-party library, a canvas, `document.title`, analytics, a subscription or a timer. The documentation calls it an escape hatch. An effect runs only in the browser, after the component mounts, and again after its dependencies change.
- Do not set state in an effect to mirror other state. Use `$derived` for a value that follows other state. Use an event handler or a callback prop for a change that a user causes. Use a function binding (`bind:value={get, set}`) for two values that follow each other ([bindings](06-events-bindings-and-attachments.md#bindings)).
- Return a cleanup function from an effect that starts something. It runs before the effect runs again and when the component is destroyed.
- An effect tracks the state that it reads synchronously, including through the functions it calls. A read after an `await` or inside `setTimeout` is not tracked. A read inside `untrack(() => ...)` is not tracked either.
- Use `untrack` only as the last resort, when an effect must read and write the same state and loops without it. Say why in a comment.
- Mutating a property of an object does not rerun an effect that reads the object itself. Read the property, or reassign the object.
- Prefer an attachment to an effect that works on one element, so that the code is reused and cleans up with the element ([attachments](06-events-bindings-and-attachments.md#attachments)). An effect with `bind:this` and a null check is the old form of it.
- Use `$effect.pre` only when the code must run before the DOM updates, such as measuring scroll position before a list grows. Use `$effect.root` only to create effects outside a component, and always call the function that it returns to destroy them. `$effect.tracking` is for authors of abstractions such as `createSubscriber`.
- `onMount` still runs a callback once after mount and does not track state. It is fine for one-time browser setup that reads no state. `beforeUpdate` and `afterUpdate` do not exist in runes mode: use `$effect.pre` and `$effect`.

```svelte
<script lang="ts">
  let { title }: { title: string } = $props();

  $effect(() => {
    const previous = document.title;
    document.title = title;
    return () => {
      document.title = previous;
    };
  });
</script>
```

### Debugging

- Use `$inspect(value)` to log a value each time it changes, including a deep change. It works only in development and does nothing in a production build. Remove it before you commit.
- Use `$inspect.trace()` as the first statement of an effect or a derived to see which state made it run again.
- Do not `console.log` a `$state` object. It prints a proxy. Use `$inspect` or `$state.snapshot`.

## Sources and raw notes

Pages read on 2026-11-18:

- [`$state`](https://svelte.dev/docs/svelte/$state): deep proxies, classes, `$state.raw`, `$state.snapshot`, `$state.eager`, destructuring, passing state to functions, and the rule against exporting a reassigned state variable.
- [`$derived`](https://svelte.dev/docs/svelte/$derived): `$derived.by`, no side effects, overriding since 5.25, no proxying, push-pull evaluation.
- [`$effect`](https://svelte.dev/docs/svelte/$effect): the escape-hatch wording, when not to use it, the alternatives, teardown, dependency rules, `$effect.pre`, `$effect.tracking`, `$effect.root`, `untrack` as the last resort.
- [`$inspect`](https://svelte.dev/docs/svelte/$inspect): development only, `.with`, `.trace` since 5.14.
- [`svelte/reactivity`](https://svelte.dev/docs/svelte/svelte-reactivity): the seven exports and when to use each one. [Lifecycle hooks](https://svelte.dev/docs/svelte/lifecycle-hooks): `onMount`, `onDestroy`, and `beforeUpdate` and `afterUpdate` not available in runes mode. [Compiler warnings](https://svelte.dev/docs/svelte/compiler-warnings): `non_reactive_update`, `state_referenced_locally`.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the `$state.raw`, `$derived` and class examples ran under Vitest 5.1.1 in Node.js, and the `$state` plus `$effect` pair, the plain `Set` and the unkeyed `{#each}` were reported by the lint rules named above.
