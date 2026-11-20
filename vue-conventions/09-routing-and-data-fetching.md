# Vue Routing and Data Fetching

## Summary

Write a manual route table with named, lazily loaded routes and pass route params to components as props. Guards return a value and never call `next`. Fetch data in a composable that validates the response, aborts stale requests and shows loading and error states, and add a query library only when two components share the same server data.

## Rules

### Routes

- Create the router with `createRouter()` and `createWebHistory(import.meta.env.BASE_URL)`, and export it as `router` from `src/router/index.ts`. Install it with `app.use(router)`. Use `createWebHashHistory()` only when the host cannot rewrite URLs, such as a file served from disk.
- Write a manual route table. Vue Router 5 merged file-based routing and typed routes into the core package, with no breaking change for a project that did not use them, but `create-vue` writes a manual table, and the data loaders that came with version 5 are marked experimental. A project may adopt file-based routing in its own change, with its own note ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Give every route a `name`, and navigate by name: `<RouterLink :to="{ name: 'loan', params: { id } }">` and `router.push({ name: "loans" })`. A path string breaks when a path changes. A name does not.
- Load each route's component with `() => import("@/loans/loan-list-view.vue")`, so that each route is a separate chunk. Import a route component statically only for a route that every visit needs, such as the home page of a small app.
- Pass route params to a component as props with `props: true`, and declare them in the component: `const { id } = defineProps<{ id: string }>()`. The component then does not depend on the router, and a test passes `id` directly. Use `props: (route) => ({ page: Number(route.query.page ?? 1) })` for a query value, and parse it there.
- Add a catch-all route last: `{ path: "/:pathMatch(.*)*", name: "not-found", component: ... }`. Without it, an unknown URL renders nothing.
- Type `meta` by augmenting `RouteMeta`, so that `to.meta.title` has a type:

```ts
// src/router/route-meta.ts
import "vue-router";

declare module "vue-router" {
  interface RouteMeta {
    title: string;
    requiresAuth?: boolean;
  }
}
```

- Nest routes (`children`) for a shared layout, and render the child in a `<RouterView />` in the parent. Do not nest routes only to share a path prefix.
- Read the route with `useRoute()` in the component, and the router with `useRouter()`. Read `route.params` and `route.query` through a `computed()` or a props getter, never once at the top of `setup()`, because they change while the component stays mounted.
- Put state that a user may share in the query string (`route.query.q`, `page`), and update it with `router.replace({ query })` for a refinement, and `router.push` for a new place in the history.
- Serve the app with a fallback to `index.html` when you use history mode. In nginx, `try_files $uri $uri/ /index.html;` does it. The router's catch-all route then renders the 404 page, while the server answers 200.
- Do not use a trailing wildcard in a route to catch every path of an API. A route table is for pages.

### Guards

- Return a value from a guard: `false` to cancel, a route location to redirect, and `true` or nothing to continue. Do not use the `next` callback. Since Vue Router 5.0.3, calling `next` logs a deprecation warning in development, and the documentation calls it a common source of mistakes: a path that forgets to call it hangs the navigation, and one that calls it twice breaks it.
- Keep a global `beforeEach` guard small: authentication and redirects. It runs on every navigation. Put a route-specific check in the route's `beforeEnter`.
- Do not fetch data in a global guard. A slow request there blocks the whole navigation. Fetch in the component or a composable and show a loading state, unless the page must not show before the data is there; the router's documentation offers both choices.
- Use `onBeforeRouteLeave()` in a component to confirm leaving a form with unsaved changes, and `onBeforeRouteUpdate()` when the same component stays for a different param. Prefer a watcher on a prop for the second.
- Protect pages in the router for the user's convenience only. The server must check every request ([security](11-performance-and-security.md#security)).

### Navigation and focus

- Use `<RouterLink>` for in-app navigation, not `<a href>`, so that the router handles the click and the link gets `aria-current="page"` when active. Import `RouterLink` and `RouterView` in the file that uses them ([layout](03-project-layout-and-naming.md#exports-and-imports)).
- A single-page app does not announce a page change. In `router.afterEach`, set `document.title` from `to.meta.title` and move focus to the new page's `<main tabindex="-1">`, so that a screen reader and a keyboard user land in the new content. The sample project does both.
- Keep the default scroll to the top for a new page and restore the saved position for back and forward: `scrollBehavior: (_to, _from, saved) => saved ?? { top: 0 }`.
- Use `router.push` in a handler for navigation that follows an action, and `await` it when the code that follows must run after the navigation. Handle a navigation failure with the result of `push`, which is `undefined` on success and a failure object otherwise, not with `try`/`catch`.

### Data fetching

- Fetch in a composable that a view or a component calls: it owns the `data`, `error` and `isLoading` refs, takes its input as a getter, and aborts a request that a newer one replaced ([composables](07-composables.md#side-effects-and-cleanup)). Write one `useFetchJson(schema, url)` for the app and build the specific ones on it.
- Treat the response as `unknown` until a schema accepts it, as the TypeScript notes require. Parse once, at the boundary, and map the wire shape to the domain shape there. Give the schema the type: `useFetchJson<T>(schema: z.ZodType<T>, url)`. Never write `as Loan[]` on a response.
- Give every request a timeout and an `AbortSignal`. The composable owns an `AbortController` per request. The TypeScript notes say `signal: AbortSignal.timeout(5_000)`; combine it with the controller using `AbortSignal.any([controller.signal, AbortSignal.timeout(5_000)])`, as the sample project does. A timeout is an error to show, and an abort by a newer request is not.
- Show three states in the template: loading, error and data (and empty, where the data is a list). Use `v-if`, `v-else-if` and `v-else` on one chain, and a `role="status"` for loading and `role="alert"` for an error.
- Fetch when the input changes, not in `onMounted()`. A `watchEffect` or a `watch` on the getter handles the first fetch and every change after it.
- A mutation (create, update, delete) is a function, not a watcher: call it from the submit handler, disable the button while it runs, handle the error in the handler, and update the shown data from the response or refetch.
- Add a query library, TanStack Query for Vue (`@tanstack/vue-query`), once two components must share the same server data, or when you need caching, deduplication, retries or background refresh. Do not add it for one screen. The set does not write the library's own rules; use its documentation, and keep the schema parse at the boundary inside the query function.
- Do not fetch in a store's top-level code. Fetch from an action, or in a composable that updates the store.
- Never build a URL by joining user input as a string. Use `encodeURIComponent()` for a path segment and `URLSearchParams` for a query.

## Sources and raw notes

Pages read on 2026-11-20:

- [Vue Router: migrating to version 5](https://router.vuejs.org/guide/migration/v4-to-v5.html): Vue Router 5 merges unplugin-vue-router into the core package, and a Vue Router 4 project without it has no breaking changes.
- [Vue Router 5.0.0 release notes](https://github.com/vuejs/router/releases/tag/v5.0.0) (2026-01-29): "a boring release", data loaders added as experimental; 5.1.0 (2026-05-28): typed `definePage` params.
- [Passing props to route components](https://router.vuejs.org/guide/essentials/passing-props.html), [named routes](https://router.vuejs.org/guide/essentials/named-routes.html), [history modes](https://router.vuejs.org/guide/essentials/history-mode.html) (the nginx `try_files` fallback and the catch-all 404), [route matching syntax](https://router.vuejs.org/guide/essentials/route-matching-syntax.html), [lazy loading](https://router.vuejs.org/guide/advanced/lazy-loading.html), [route meta fields](https://router.vuejs.org/guide/advanced/meta.html) and [scroll behaviour](https://router.vuejs.org/guide/advanced/scroll-behavior.html).
- [Navigation guards](https://router.vuejs.org/guide/advanced/navigation-guards.html): returning `false`, a location, or `true` or nothing; the `next` argument is deprecated since 5.0.3.
- [Data fetching](https://router.vuejs.org/guide/advanced/data-fetching.html): fetching after and before navigation, both valid.
- [Vue style guide](https://vuejs.org/style-guide/rules-essential.html) and the [TypeScript runtime-validation note](../typescript-conventions/05-runtime-validation-and-external-data.md) for the schema at the boundary.
- `@tanstack/vue-query` 5.108.1 on npm: version only.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): a router with three named, lazy routes, `props: true`, a catch-all, `scrollBehavior`, a `beforeEach` guard that returns values, an `afterEach` hook that sets the title and focuses `main`, and the `RouteMeta` augmentation; a detail view that reads `id` from props and passes a getter to `useFetchJson`. ESLint's `vue/no-undef-components` reported `<RouterLink>` until the view imported it. `vue-tsc`, ESLint, Prettier, Vitest and `vite build` ran with 0 errors.
