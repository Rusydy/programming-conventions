# Svelte Errors and Async Code

## Summary

Handle errors where they happen, as the TypeScript notes say, and use `<svelte:boundary>` as the safety net for errors that rendering and effects throw. Show loading and failure states from plain state or an `{#await}` block. Do not use `await` inside components or `$derived`, because the feature is still experimental.

## Rules

### Errors

- Follow the [TypeScript error rules](../typescript-conventions/09-error-handling.md): throw only `Error` objects, keep the original error as the `cause`, catch only what the code can handle, and return a result for an outcome that is normal.
- Catch the error of a request in the function that makes it, and turn it into state that the template shows:

```svelte
<script lang="ts">
  let status = $state<"idle" | "loading" | "failed">("idle");

  async function save(): Promise<void> {
    status = "loading";
    try {
      await saveLoan();
      status = "idle";
    } catch (error) {
      console.error(error);
      status = "failed";
    }
  }
</script>

<button type="button" disabled={status === "loading"} onclick={() => void save()}>
  Save
</button>
{#if status === "failed"}<p role="alert">The loan was not saved.</p>{/if}
```

- Model a request with a union, not with three booleans: `{ state: "loading" } | { state: "failed"; error: Error } | { state: "ready"; data: Loan[] }`. Handle it in an `{#if}` chain or in a `{#each}` over the union's `data`. A discriminated union rules out the state in which `loading` and `failed` are both `true` ([types and type design](../typescript-conventions/04-types-and-type-design.md#model-alternatives-with-unions)).
- Do not pass an `async` function to an event attribute. Call it from a normal handler with `void`: `onclick={() => void save()}`. This is the [TypeScript rule](../typescript-conventions/08-functions-classes-and-async.md#async-code) that `no-misused-promises` enforces.
- Show a message that a user can act on. Do not show `error.message` of an unexpected error, as the TypeScript notes say, and log the error once where you catch it.
- Validate data that enters from outside with a schema before it reaches state: a response, a value from storage and the result of a Go binding in a desktop app ([runtime validation](../typescript-conventions/05-runtime-validation-and-external-data.md)).

### Error boundaries

- Wrap a part of the tree that can fail in `<svelte:boundary>` with a `failed` snippet, which receives the `error` and a `reset` function. Put one boundary near the root, so that a render error never leaves a blank page, and add more around parts that can fail on their own, such as a chart or a third-party widget.

```svelte
<script lang="ts">
  import { userMessage } from "@/lib/shared/user-message";

  let { data }: { data: number[] } = $props();
</script>

<svelte:boundary onerror={(error) => console.error(error)}>
  <Chart {data} />
  {#snippet failed(error, reset)}
    <p>{userMessage(error)}</p>
    <button type="button" onclick={reset}>Try again</button>
  {/snippet}
</svelte:boundary>
```

- `userMessage(error: unknown): string` is a function of your own that maps an error to a text that is safe to show. The linter reports an unused `error` parameter, so use it, and do not rename it to `_`.

- A boundary catches errors that are thrown while rendering and while effects run. It does not catch an error in an event handler, a `setTimeout` callback or other async work. Catch those yourself, as above.
- Use `onerror` to report the error, for example to a log. A boundary that handles an error removes the content it held, so show something in `failed`. If `onerror` throws, or you rethrow, the parent boundary handles the error.
- Do not render the message of the error in `failed` unless you know that it is safe to show.
- On a server, a boundary has no effect by default. That is a SvelteKit matter ([principles](01-principles-and-sources.md#applying-the-notes)).

### Loading data

- Fetch in a function that an event handler calls, or in the module that owns the data, and store the result in `$state` or `$state.raw`. Do not fetch inside a `$derived`.
- Start a request from an `$effect` only when it depends on state, such as a search term, and then cancel the previous one with the effect's cleanup and an `AbortController`. Give every request a timeout with `AbortSignal.timeout`, as the [TypeScript notes](../typescript-conventions/08-functions-classes-and-async.md#async-code) require.
- A `{#await promise}` block is fine for one promise that has a pending, a resolved and a rejected branch and no other state. Create the promise outside the block, so that it is not created again on every update.
- Show the stale data, not an empty screen, while a new request runs, and mark it as updating. Disable the control that started the request.

### Async in components

- Do not use `await` at the top level of a component, inside `$derived`, or inside the markup. Do not set `experimental.async` in `svelte.config.js`. The documentation marks the feature experimental and says that the flag will be removed in Svelte 6. It also says that details of `await` handling, `$effect.pending()` and related APIs may change in breaking ways outside major releases.
- That also covers `settled()`, `fork()` and `$state.eager`, which exist for it. `$state.eager` appears in [runes](04-runes-and-reactivity.md#state) only so that you recognise it.
- Revisit this rule when the flag is removed. At that point a boundary with a `pending` snippet is the place for loading UI, independent `await` expressions in markup run in parallel, and sequential `await` in a script can trigger the `await_waterfall` warning.

## Sources and raw notes

Pages read on 2026-11-18:

- [`<svelte:boundary>`](https://svelte.dev/docs/svelte/svelte-boundary): `failed`, `onerror`, `reset`, `pending`, what it catches and does not catch, and its behaviour on the server.
- [`await` expressions](https://svelte.dev/docs/svelte/await-expressions): experimental, the `experimental.async` option and its removal in Svelte 6, where `await` can appear since 5.36, `settled()` since 5.36, `fork()` since 5.42, and the parallel and waterfall behaviour.
- [`$state`](https://svelte.dev/docs/svelte/$state): `$state.eager`. [Compiler reference](https://svelte.dev/docs/svelte/svelte-compiler): `experimental.async` since 5.36.
- [Changelog of Svelte](https://github.com/sveltejs/svelte/blob/main/packages/svelte/CHANGELOG.md): `await` support in 5.36 behind the flag, async server rendering experimental in 5.39, error boundaries on the server in 5.53. The changelog entries read do not say that the feature left its experimental state.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the `<svelte:boundary>` sample in `format-name.svelte` passed `svelte-check` and ESLint. The `{#await}` block, the `AbortController` advice and the request-state union are standard Svelte and TypeScript practice that the sample project did not exercise.
