# Vue Errors and Async Code

## Summary

Throw `Error` objects, catch what you can handle where you can handle it, and let the rest reach one handler on the app that logs it once. Show a safe message to the user, never the raw error. Fetch with an abortable, validated request, handle `fetch`'s non-throwing HTTP failures, and keep `await` out of `<script setup>`.

## Rules

### Errors

- Throw and reject only `Error` objects, with a `cause` when you wrap one, as the [TypeScript notes](../typescript-conventions/09-error-handling.md) say. In `catch (error)`, the value is `unknown`: narrow it with `instanceof Error`.
- Return a result for a failure that is a normal outcome (a form that does not validate). Throw for a fault (the server is down, an invariant broke).
- Handle an error where the code can do something about it: show a message beside the field, retry, or fall back. Do not catch an error only to log it and throw it again.
- Never put `error.message` of an unexpected error on the page. Show a short message that you wrote ("Could not load the loan") and log the real error. A message from your own validation (`"Amount must be positive"`) is for the user and is safe.

### The app handler

- Set one global handler in `main.ts`, with `app.config.errorHandler`. Vue sends it every error from component renders, event handlers, lifecycle hooks, `setup()`, watchers, custom directive hooks and transition hooks that nothing handled. Log the error once, with its `cause` chain, and send it to your error-reporting service there:

```ts
app.config.errorHandler = (error, _instance, info) => {
  console.error(`Unhandled error in ${info}`, error);
  // report(error)
};
```

- In production, `info` is a short code, and the Vue error reference maps each code to its meaning. Log the code.
- Register `window.addEventListener("unhandledrejection", ...)` and `"error"` next to it for errors that happen outside Vue, such as a rejected promise that no component awaited.
- Do not set `app.config.warnHandler` in production code. Warnings are development messages.
- A router error (a failed lazy import, a guard that throws) goes to `router.onError()`. A chunk that fails to load after a deploy is the common case; reload the page once, or show a message with a reload button.

### Error boundaries

- Put an error boundary around a region that can fail without taking the page down: a widget, a route's content, a list that renders user data. Write it as a small component that calls `onErrorCaptured()`, stores the error, and renders a fallback slot. Return `false` so that the error stops there. The error still reaches `app.config.errorHandler` if you return anything else:

```vue
<script setup lang="ts">
import { onErrorCaptured, ref } from "vue";

const emit = defineEmits<{ error: [error: Error] }>();
defineSlots<{
  default(): unknown;
  fallback(props: { error: Error; reset: () => void }): unknown;
}>();

const failure = ref<Error>();

onErrorCaptured((error) => {
  failure.value = error instanceof Error ? error : new Error(String(error));
  emit("error", failure.value);
  return false;
});

function reset() {
  failure.value = undefined;
}
</script>

<template>
  <slot v-if="!failure" />
  <slot v-else name="fallback" :error="failure" :reset>
    <p role="alert">Something went wrong.</p>
  </slot>
</template>
```

- The fallback must not render the content that threw, or the boundary throws again in an endless loop. The Vue documentation warns about this.
- Wrap a route's `<RouterView>` in a boundary in `app.vue`, and give a retry that calls `reset()`.
- Do not use `onErrorCaptured()` to handle expected failures. Handle those where they happen.

### Event handlers

- An `async` function may be a template event handler (`@click="save"`). Vue awaits the promise that a handler returns and sends a rejection to the error handler, so the rule of the TypeScript notes against passing an `async` function where a void callback is expected has an exception here. Say so in a comment if a reviewer would ask.
- Handle the errors you expect inside the handler with `try`/`catch` or a result, show the message, and let the rest reach the global handler.
- In script code that you call yourself (a watcher callback, a `setTimeout`, a function called from another), handle every promise: `await` it, return it, or mark a deliberate fire-and-forget call with `void` and handle its errors inside, as the TypeScript notes say. A rejection that nothing awaits is an `unhandledrejection`.
- Disable a button while its handler runs, so that a second click cannot start a second request. Use an `isSaving` ref that you set in a `try`/`finally`.

### Requests

- `fetch` rejects only for a network failure or an abort. A 404 or a 500 resolves, so check `response.ok`, and throw an `Error` that names the URL and the status: `Request to /api/loans failed with 500`.
- Read the body as `unknown` and validate it with a schema before you use it ([data fetching](09-routing-and-data-fetching.md#data-fetching)). A failed `schema.parse` is an error to show, not a crash.
- Abort a request when its input changes or the component goes away, and ignore the rejection of an aborted request: an abort is not a failure. A request that times out is a failure, and the user should see it ([composables](07-composables.md#side-effects-and-cleanup)).
- Put a request that more than one component makes in one function or composable, so that the error message, the timeout and the validation live in one place.
- Keep the request URL, headers and credentials in one module. A component does not build URLs.

### Async in components

- Do not write top-level `await` in `<script setup>`. A component with top-level `await` is an async component, and it needs `<Suspense>` above it, which the Vue documentation marks experimental and may change before it reaches stable. Load data in a composable that exposes `isLoading` and `error`, and render the three states in the template.
- Do not use `<Suspense>`. Revisit this when the Vue documentation drops the experimental label.
- Lazy-load a heavy component that is not a route (a chart, an editor, a map) with `defineAsyncComponent(() => import("./heavy-chart.vue"))`. Give it `loadingComponent`, `errorComponent`, a `delay` and a `timeout` when the user can see it wait, and wrap it in an error boundary otherwise. Route components are lazy-loaded in the route table instead.
- Await `nextTick()` only when you must read the DOM after a state change.
- Do not mix `.then()` chains and `await` in one function, as the TypeScript notes say.
- A `setTimeout` or `setInterval` started in a component is cleared in `onScopeDispose()` or `onUnmounted()`.

## Sources and raw notes

Pages read on 2026-11-20:

- [Application API: `app.config.errorHandler`](https://vuejs.org/api/application.html#app-config-errorhandler): the error, the instance, `info`, the sources of captured errors, the shortened `info` code in production.
- [Composition API lifecycle: `onErrorCaptured()`](https://vuejs.org/api/composition-api-lifecycle.html#onerrorcaptured): the sources, returning `false` to stop propagation, the order of the hooks, the infinite render loop warning.
- [Async components](https://vuejs.org/guide/components/async.html): `defineAsyncComponent`, loading and error states, `delay`, `timeout`.
- [Suspense](https://vuejs.org/guide/built-ins/suspense.html): "`<Suspense>` is an experimental feature".
- [Production deployment](https://vuejs.org/guide/best-practices/production-deployment.html): tracking runtime errors through the app-level error handler.
- [Vue Router navigation guards](https://router.vuejs.org/guide/advanced/navigation-guards.html): an `Error` thrown in a guard cancels the navigation and reaches `router.onError()` callbacks.
- The [TypeScript error-handling note](../typescript-conventions/09-error-handling.md) for throwing `Error` objects and the `cause`. That `fetch` resolves on an HTTP error status and rejects only on a network failure or an abort comes from the Fetch Standard.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): the `ErrorBoundary` component above, with a browser test that renders it around a child whose `setup()` throws, then asserts that the `role="alert"` fallback shows and that the `error` event fired once; the fetch composable checks `response.ok` and ignores the rejection of its own aborted request. `vue-tsc`, ESLint, Prettier, Vitest and `vite build` ran with 0 errors.
