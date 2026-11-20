# Nuxt Data Fetching

## Summary

Fetch the data that a page needs with `useFetch()` or `useAsyncData()`, so that the server fetches once and sends the result in the payload. Fetch in response to a user action with `$fetch()`. Give every `useAsyncData` an explicit key, pass changing inputs as refs or getters, and render the loading, error and data states. Third-party APIs are called from `server/`, not from the page.

## Rules

### Which one to use

- `useFetch(url, options)` is the default for a page or component that shows data from a URL. It is `useAsyncData` plus `$fetch`, and it builds the key from the URL and the options.
- `useAsyncData(key, handler)` is for data that is not one URL: several requests combined, a query layer that a CMS provides, or work that is not HTTP. Use it with `$fetch` calls inside the handler. Do not call a Pinia action in it, and do not use it for side effects. Use `callOnce()` for a side effect that must run once per render.
- `$fetch(url, options)` is for events: a click, a submit, a polling timer. It does not de-duplicate, and it does not forward the payload, so calling it in `setup()` fetches on the server and again in the browser.
- Use the typed result. For your own routes, `useFetch("/api/loans")` and `$fetch("/api/loans", { method: "POST" })` are typed from the return type of the handler in `server/api/`, so annotate the handler's return type with a type from `shared/` ([server](06-server-routes-and-validation.md#handlers)). Write no `as Loan[]` and no type argument (`useFetch<Loan>(...)`): a type argument that appears only in the return type is what the TypeScript notes ban, and Nuxt infers the type of a dynamic URL such as a template string from the route that matches it.
- `useLazyFetch` and `useLazyAsyncData` are `useFetch` and `useAsyncData` with `lazy: true`. Write the option, not the alias, so that the call reads the same as the others.

### Await and Suspense

- Write `await useFetch(...)` and `await useAsyncData(...)` at the top of `<script setup>`, as the Nuxt documentation does. Nuxt wraps the app in `<Suspense>` for these calls. This is the one exception to the [Vue rule](../vue-conventions/10-errors-and-async.md#async-in-components) against top-level `await`; every other top-level `await` is still banned.
- The `await` does not change the server-rendered HTML, because the server waits for the request either way. It decides what happens in your own script, and on client-side navigation: with `await`, navigation waits for the data, and the user stays on the current page, ideally with `<NuxtLoadingIndicator />`. Without `await`, the page shows at once, `data` starts empty, and you render the loading state.
- Choose per page. Await data that the page cannot show without. Use `lazy: true` for secondary data (a sidebar, a recommendation list) so that it never blocks navigation, and render its `status`.
- Do not `await` a `lazy` call and expect it to be lazy on the client. The documentation warns that an `await` on a lazy call still blocks server rendering and resolves at once on a client navigation.
- Call the composables in `setup()`, a plugin or a middleware, not in an event handler or after an `await` that is not one of them. Nuxt needs its context.

### Keys and reactive sources

- Give every `useAsyncData` an explicit key: `` useAsyncData(`loan:${id}`, () => ...) ``. The generated key is the file and the line, which breaks when you wrap the call in your own composable. `useFetch` builds its key from the URL and the options.
- Two calls with the same key share the data, and they must use the same options (`transform`, `pick`, `default`, `deep`, `server`, `lazy`, `immediate`, `getCachedData`). Nuxt warns when they differ.
- Pass an input that changes as a ref, a computed value or a getter, and Nuxt refetches when it changes: `query: { q: query }` on a ref, or a URL as a getter, `` () => `/api/loans/${encodeURIComponent(id.value)}` ``. Do not read `.value` into a string yourself, because that fixes the input at the first call.
- Add `watch: [source]` for a source that is not part of the URL or the query. Set `immediate: false` and call `execute()` for data that waits for a user action.
- Use `refresh()` to fetch again. Nuxt de-duplicates: a second `refresh()` while one runs cancels the first (`dedupe: "cancel"`, the default). Use `dedupe: "defer"` to let the first finish.
- Use `clear()` to reset `data`, `error` and `status`. Use `refreshNuxtData("key")` to refresh another component's data by its key, and `useNuxtData("key")` to read it.
- The `data` ref is `undefined` until the data arrives. Give `default: () => []` when a template needs an array, and never read `data.value` in the script before you know it is there.
- In Nuxt 4, `data` is a shallow ref (`deep` is `false`). Replace the whole value to change it, and do not mutate a nested property. Set `deep: true` only for data that a component edits in place, and prefer copying it into a draft instead.

### The three states

- Render `status` (`idle`, `pending`, `success`, `error`) and `error`, as the [Vue notes](../vue-conventions/09-routing-and-data-fetching.md#data-fetching) do. Show a loading message with `role="status"`, an error with `role="alert"`, and the data, in one `v-if` chain:

```vue
<script setup lang="ts">
const query = ref("");
const { data: loans, status, error } = await useFetch("/api/loans", {
  query: { q: query },
});
</script>

<template>
  <div>
    <label for="search">Search</label>
    <input id="search" v-model="query" type="search" />
    <p v-if="status === 'pending'" role="status">Loading</p>
    <p v-else-if="error" role="alert">Could not load the loans.</p>
    <ul v-else>
      <li v-for="loan in loans" :key="loan.id">{{ loan.borrower }}</li>
    </ul>
  </div>
</template>
```

- Show a message that you wrote. Do not render `error.message`, because it can carry the response body ([errors and security](08-errors-and-security.md#errors)).
- Treat a missing resource as an error of the page, not an empty page. After the call, `throw createError({ status: 404, statusText: "Loan not found", fatal: true })` when `data` is empty or `error.value?.status === 404` ([routing](04-pages-routing-and-navigation.md#pages)).

### Payload and size

- Everything that `useFetch` returns on the server is serialised into the page payload. Keep it small: use `pick: ["id", "borrower"]` for a list of fields, or `transform` to shape the data, and send only what the page shows. Do not return a database row to the browser. Shape it in the handler ([server](06-server-routes-and-validation.md#handlers)).
- Do not fetch the same URL in a layout, a page and a component without a shared key. Share the key, or fetch once in the parent and pass props.
- Use `server: false` only for data that must come from the browser (it depends on browser state, or it is personal and must not be cached). The page then renders without it, and `data` stays `undefined` until hydration ends.
- Client navigation reuses cached data for a key until a refresh. Use `getCachedData` to change that, for data that must be fresh on every visit.

### Headers, cookies and the server

- During server rendering, `useFetch` and `useRequestFetch()` forward the browser's cookies and headers to your own API, so the handler sees the user's session. A raw `$fetch` on the server does not. Forward only what you need to a third-party API, and never `host`, `content-length`, `content-type`, `x-forwarded-*` or `cf-*` headers, as the documentation lists.
- Call a third-party API from a `server/api` handler, not from a page. The handler holds the secret key, validates the response with a schema, maps it to the domain type and sets the cache headers. The page then calls your own typed route ([server](06-server-routes-and-validation.md#validation)).
- Never put a secret in a `useFetch` call that runs in the browser. Everything in `runtimeConfig.public` and in the payload is public.

### Mutations

- A mutation is a function that calls `$fetch` with a method and a body, from a submit handler. Set an `isSaving` ref and disable the button while it runs, handle the failure in a `try` block, show a message that you wrote, and update the page with the response or `refresh()`:

```ts
async function handleSubmit() {
  isSaving.value = true;
  try {
    const loan = await $fetch("/api/loans", { method: "POST", body: draft });
    emit("created", loan);
  } catch {
    failure.value = "Could not save the loan.";
  } finally {
    isSaving.value = false;
  }
}
```

- Validate the form with a schema in the browser for fast feedback, and in the handler on the server for safety. The server never trusts the browser ([server](06-server-routes-and-validation.md#validation)).
- Send amounts as integers of minor units, as the TypeScript notes say, and ids as strings.

### Queries and caches

- A query library (`@tanstack/vue-query` with its Nuxt setup) is for the cases that the [Vue notes](../vue-conventions/09-routing-and-data-fetching.md#data-fetching) name: data shared between components, retries, background refresh. In Nuxt, `useFetch` and `useAsyncData` already share and de-duplicate by key, so do not add a library for those.
- Do not write your own `useFetch` wrapper by hand. When a second page needs the same defaults (a `baseURL`, `server: false`, an error hook), make a custom instance with `createUseFetch()` or `createUseAsyncData()` (Nuxt 4.4) in `app/composables/`, such as `export const useApiFetch = createUseFetch({ ... })`. The instance keeps the key logic and the types of `useFetch`, and you call it exactly like `useFetch`. A function argument gives control over how your defaults merge with the caller's options.

## Sources and raw notes

Pages read on 2026-11-20:

- [Data fetching](https://nuxt.com/docs/getting-started/data-fetching): why `useFetch` and `useAsyncData` exist, Suspense, the note on `await`, `$fetch`, passing client headers (and the headers not to proxy), return values, `lazy`, `server: false`, `pick` and `transform`, keys and shared state, reactive keys, `refresh`, `clear`, `watch`, computed URLs, `immediate: false`, typed routes, serialising data from the server.
- [`useFetch`](https://nuxt.com/docs/api/composables/use-fetch) and [`useAsyncData`](https://nuxt.com/docs/api/composables/use-async-data): options and defaults (`deep` is `false`, `dedupe` is `"cancel"`), `getCachedData`, and the note not to call a Pinia action in `useAsyncData`.
- [`useNuxtData`](https://nuxt.com/docs/api/composables/use-nuxt-data) and the [custom `useFetch` recipe](https://nuxt.com/docs/guide/recipes/custom-usefetch) (`createUseFetch`). The [Nuxt 4.4.0](https://github.com/nuxt/nuxt/releases/tag/v4.4.0) release notes (2026-03-12) introduce `createUseFetch` and `createUseAsyncData`, and the [4.2.0](https://github.com/nuxt/nuxt/releases/tag/v4.2.0) notes (2025-10-25) add the abort `signal` that `useAsyncData` passes to its handler. The sample project did not call `createUseFetch`.
- [Vue notes on data fetching](../vue-conventions/09-routing-and-data-fetching.md#data-fetching) and the [TypeScript notes on runtime validation](../typescript-conventions/05-runtime-validation-and-external-data.md).
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `await useFetch("/api/loans", { query: { q: query } })` with a ref, `useFetch` with a URL getter on a narrowed param (its `data` was typed as the handler's `Loan` with no type argument), the type of `$fetch("/api/loans", { method: "POST" })` inferred from the handler, a form that sets `isSaving` and handles the failure, and a page that throws `createError({ fatal: true })`. `nuxt typecheck`, typed ESLint and the tests passed.
