# SvelteKit State and Navigation

## Summary

Read the current page from `$app/state`, keep shared state out of module variables on the server, and use context for state that a subtree shares. Put state that must survive a reload or that the server needs in the URL. Build every internal link with `resolve()` from `$app/paths`, and navigate with `goto` or a plain `<a>`.

## Rules

### State on the server

- One server process answers every user. Do not store user data in a module-level variable, a `$state` at module level or a singleton, because the next request would read it. The [Svelte notes](../svelte-conventions/07-state-sharing-and-context.md#module-level-instance) allow a module-level instance only in a client-only app.
- Keep per-user data in `event.locals` for the length of a request, in a cookie that names a session, and in a database for anything longer ([hooks, errors and security](07-hooks-errors-and-security.md#authentication-and-authorisation)).
- Keep `load` free of side effects. It does not write to a store or a shared object ([load](04-load-and-data-fetching.md#fetching)).
- A module-level cache of public, identical data, such as a parsed configuration file, is safe. A cache that depends on the user or the request is not.

### State in components

- Share state with a subtree through context, as the [Svelte notes](../svelte-conventions/07-state-sharing-and-context.md#context) say: create a class with `$state`, create the instance in a layout, and call `setLoanList(list)`. Context is not shared between requests.
- Pass state down, not up, during server rendering. A child that changes context state cannot update a parent that the server has already rendered, and the value flashes when the page hydrates.
- Pass a function when you put a load result into context so that it stays reactive: `() => data.user`. A value read once keeps the first page's data.
- Use `page.data` from `$app/state` when a layout needs data that a child page's `load` returned. Declare its type in `App.PageData` in `src/app.d.ts`, and keep that interface small.

### Pages and layouts persist

- SvelteKit reuses a layout and a page component when the user moves between routes that use it, so their setup code does not run again. Use `$derived` for values that depend on `data` or `page`, not `const` or `$state(data.x)`.
- Run navigation-triggered code in `afterNavigate` and `beforeNavigate` from `$app/navigation`, and not in `onMount`, which runs once.
- Wrap a part of the tree in `{#key page.url.pathname}` when it must remount on every navigation, such as a transition container.
- Keep disposable UI state, such as the open section of an accordion or a scroll position inside a panel, with a `snapshot` export in `+page.svelte` or `+layout.svelte`. It ties that state to the history entry, so back and forward restore it, and it needs no URL and no database.

### State in the URL

- Store state that the server must know, that a reload must keep or that a user may share in the URL: filters, sort order, the page number, the selected tab. Use the search parameters.
- Read them in `load` from `url.searchParams`, validate them with a schema, and give each a default. In a component read `page.url.searchParams` from `$app/state`.
- Change them with a `GET` form, or with `goto(resolve(...))` that carries the new query. Use `replace: true` for a state that should not add a history entry.
- `page.url` is a `ReadonlyURL` in SvelteKit 3. Copy it with `new URL(page.url)` before you change it.

### Page state

- Read `page`, `navigating` and `updated` from `$app/state`. They are read-only reactive objects, so use them in a component or in `$derived`, and do not mutate them. The `$app/stores` module is removed in SvelteKit 3, together with the `$` prefix. Write `page.params.loanId`, not `$page.params.loanId`.
- On the server, `page` is readable only during rendering, not inside `load`. Use the load event's `url`, `params` and `route` there.
- Use `page.status` and `page.error` in `+error.svelte`. Use `page.form` to read an action result outside the page that submitted it.
- Use `page.state` and `goto(url, { shallow: true })` for history entries that carry UI state without a navigation, such as a modal that opens over a list. `pushState` and `replaceState` are deprecated in SvelteKit 3. Add `persistState: true` when a reload should restore the state. A shallow navigation also runs `beforeNavigate`, `onNavigate` and `afterNavigate`, so test their `shallow` property.
- Show a deployment-update banner from `updated.current`. In SvelteKit 3 it updates itself on navigations, window focus and an hourly poll, and `version.pollInterval` controls the poll.

### Navigation

- Build every internal URL with `resolve()` from `$app/paths`. It prefixes the base path, and with a route id it fills the parameters and checks them against the route:

```svelte
<script lang="ts">
  import { resolve } from "$app/paths";
</script>

<a href={resolve("/loans/[loanId]", { loanId: loan.id })}>{loan.borrower}</a>
```

- Pass `resolve()` the route id with its parameters, as above, or a pathname without a leading slash (`resolve("blog/hello-world")`). `svelte/no-navigation-without-resolve` reports an `href` and a `goto` call that skip it. `base`, `assets` and `resolveRoute` are removed in SvelteKit 3.
- Use `asset("logo.png")` for a file in `static/`. Import everything else, so that Vite hashes it.
- Use an `<a>` for navigation and a `<form>` for a change. Do not use a `<button onclick={() => goto(...)}>` for a link, because it has no URL to open in a new tab.
- Call `goto(resolve(...))` only after an event that is not a link, such as a finished form or a timer. `goto` rejects a URL that is not an app route, so use `window.location.href` for an external one. Its options are `replace`, `reset`, `shallow` and `refreshAll`.
- Tune preloading with the `data-sveltekit-*` attributes. The template sets `data-sveltekit-preload-data="hover"` on `<body>`, which preloads a page's code and data when a pointer rests on a link. Use `"tap"` for expensive pages and `false` to turn it off for a subtree. A SvelteKit 3 option takes `false`, not `"off"`.
- Use `data-sveltekit-reload` or `rel="external"` for a link that must do a full page load, and `data-sveltekit-reset="false"` to keep scroll and focus on a link or a `GET` form, only where the element still exists after the navigation.

## Sources and raw notes

Pages read on 2026-11-18:

- [State management](https://svelte.dev/docs/kit/state-management): no shared state on the server, no side effects in `load`, context for the tree, passing state down during server rendering, reuse of layouts and pages, state in the URL, snapshots.
- [`$app/state`](https://svelte.dev/docs/kit/$app-state): `page`, `navigating` and `updated`, the properties of `page`, read-only reactive values, readable on the server only while rendering. [`$app/paths`](https://svelte.dev/docs/kit/$app-paths): `resolve()` and `asset()`. [Link options](https://svelte.dev/docs/kit/link-options): `data-sveltekit-preload-data`, `reload`, `reset`, and the default on `<body>`.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): `$app/stores` removed, `page.url` as `ReadonlyURL`, `pushState` and `replaceState` deprecated for `goto` with `shallow`, `persistState`, the navigation events for shallow routing, `base`, `assets` and `resolveRoute` removed, `goto` rejecting external URLs, `false` replacing `'off'`, `updated.current` and the hourly poll.
- [Svelte context](https://svelte.dev/docs/svelte/context): context is not shared between requests.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `page` from `$app/state` in `+error.svelte`, `resolve("/loans/[id]", { id })` in `loans/+page.svelte` and `invalidate` in `feed/+page.svelte` passed `svelte-check`, ESLint and Prettier. The same `<a href="/loans">` and `goto("/loans")` without `resolve()` gave two `svelte/no-navigation-without-resolve` errors.
- The `snapshot` export, `afterNavigate`, `beforeNavigate`, shallow routing, `page.state` and the `reset` attribute come from the documentation pages above and the migration guide, and the sample application did not exercise them.
