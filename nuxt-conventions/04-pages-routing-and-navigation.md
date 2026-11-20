# Nuxt Pages, Routing and Navigation

## Summary

Routes come from the files in `app/pages/`. A page has one root element, a title and the metadata that `definePageMeta()` holds, and it reads its params through `useRoute()`. Layouts shape the page, route middleware guards it, `<NuxtLink>` and `navigateTo()` move between pages, and `<NuxtRouteAnnouncer>` tells screen readers about each move.

## Rules

### Pages

- Create a route by creating a file: `app/pages/index.vue` is `/`, `app/pages/loans/index.vue` is `/loans`, `app/pages/loans/[id].vue` is `/loans/:id`, and `[...slug].vue` is a catch-all. Do not write a route table. Nuxt gives the route a name from its path (`loans-id`), and you navigate by name.
- A page and a layout have exactly one root element, because Nuxt applies transitions to it, and an HTML comment counts as an element. Wrap the content in a `<div>` or a `<section>`. `vue/no-multiple-template-root` is on in the Nuxt ESLint config.
- Do not add `vue-router` routes by hand, and do not call `createRouter()`. Nuxt owns the router. A route that cannot be a file goes in a module or a `pages:extend` hook, and the need is rare.
- Set page metadata with `definePageMeta()`: `title`, `layout`, `middleware`, `validate` and your own keys. The compiler hoists the call out of `<script setup>`, so it may use literals and imported values and may not read variables of the component:

```vue
<script setup lang="ts">
definePageMeta({
  title: "Loan",
  validate: (route) => typeof route.params.id === "string",
});
</script>
```

- Type your own meta keys by augmenting `PageMeta`, in `app/types/`:

```ts
// app/types/page-meta.d.ts
declare module "#app" {
  interface PageMeta {
    title?: string;
    requiresAuth?: boolean;
  }
}

export {};
```

- A page title comes from `useSeoMeta({ title })` or `useHead({ title })`, and every route has a distinct one, because the route announcer reads it ([rendering and SEO](09-rendering-seo-and-performance.md#seo)). `meta.title` is a convenience for your own use, such as a breadcrumb.
- Read a route param through `useRoute()` in the component, and narrow it. A param is `string | string[]`, so check it, or reject the route with `validate`:

```ts
const route = useRoute();
const id = computed(() =>
  typeof route.params.id === "string" ? route.params.id : "",
);
```

- Return a 404 for a missing resource. When the fetched data is empty, throw `createError({ status: 404, statusText: "Loan not found", fatal: true })` in the page. `fatal: true` makes Nuxt render the error page and the server answer 404, which the sample verified over HTTP ([errors and security](08-errors-and-security.md#errors)). A page that renders an empty shell with status 200 is a soft 404.
- Use `validate` in `definePageMeta()` for a route whose param has a format (a number, a slug). A failed `validate` answers 404. Return `false` or an error object from it.
- Keep a page thin: fetch, lay out, and hand work to components and composables ([layout](03-project-layout-and-auto-imports.md#layout)).
- Put state that a user may share in the query string (`route.query`), not in a ref, and update it with `navigateTo({ query }, { replace: true })` or `router.replace`.
- Use `<NuxtPage :page-key="route => route.fullPath">` only when a page must remount for a param change. By default Nuxt reuses the page component, so watch the param, or key the fetch on it, as the data-fetching note says ([reactive keys](05-data-fetching.md#keys-and-reactive-sources)).

### Layouts

- A layout is a component in `app/layouts/` with a single root element and a `<slot />` inside it, not as the root. The default layout is `default.vue`. Choose another with `definePageMeta({ layout: "blank" })`, or `layout: false` for none. Wrap `<NuxtPage />` in `<NuxtLayout>` in `app.vue`.
- Declare the slot with `defineSlots<{ default(): unknown }>()`, because `vue/require-explicit-slots` applies to layouts.
- Put the `<main tabindex="-1">` landmark in the layout, so that the route announcer and your focus handling have one place to land ([accessibility](#accessibility)). One `<main>` per page.
- Do not use more than a handful of layouts. A layout that differs by one element is a prop or a slot on a component.

### Middleware

- A route middleware is a file in `app/middleware/` that runs before a route renders. It default-exports `defineNuxtRouteMiddleware((to, from) => ...)` and returns nothing to continue, `navigateTo(...)` to redirect, or `abortNavigation()` to stop. Never use the `next` callback of Vue Router.
- Name a middleware for its purpose (`auth.ts`) and attach it to a page with `definePageMeta({ middleware: "auth" })`. A file named `x.global.ts` runs on every route; use it rarely, because it costs every navigation. Order global middleware by the number prefix in the file name.
- Keep a middleware cheap: it runs on the server for the first request and in the browser afterwards. Do not fetch data in it. Check a cookie, a session state or a route meta flag, and redirect.
- Route middleware is a convenience. Protect data in the server routes, as the [errors and security note](08-errors-and-security.md#sessions-and-authentication) says.
- Do not use `router.beforeEach` from Vue Router in a plugin when a route middleware does the job.
- Use `routeRules` with `redirect` for a permanent redirect, and `appMiddleware` for a middleware that applies to a path pattern ([rendering](09-rendering-seo-and-performance.md#rendering-modes)).

### Navigation

- Use `<NuxtLink>` for every link inside the app, and a plain `<a>` for an external one that opens in the same tab. `<NuxtLink>` renders an `<a>`, prefetches the code of the target route when the link becomes visible, and sets `aria-current="page"` on the active link. Pass a route object by name: `:to="{ name: 'loans-id', params: { id } }"`.
- Use `navigateTo()` in a handler, a middleware or a plugin: `await navigateTo("/loans")`. Return its result from a middleware. Do not call `router.push` unless you need its navigation-failure result.
- Use `useRouter()` and `useRoute()` only inside `setup()` or Nuxt-context code. In a plugin, use `useNuxtApp().$router`.
- A link opens in a new tab with `target="_blank"` and `rel="noopener noreferrer"`. `<NuxtLink>` adds `rel` for external links by default; still write it when you set `target`.
- Add `<NuxtLoadingIndicator />` to `app.vue` for pages whose data blocks navigation, so that a slow route shows progress.

### Accessibility

- Keep `<NuxtRouteAnnouncer />` in `app.vue`, as `create-nuxt` writes it. Nuxt routes on the client after hydration, so the browser no longer announces a new page. The announcer reads the document title after each navigation, so a title that two routes share announces nothing.
- Give every route a distinct title with `useSeoMeta({ title })` or a `titleTemplate`. Use `useRouteAnnouncer().set(message)` for an extra message after a navigation, and `useAnnouncer` with `<NuxtAnnouncer>` for in-page updates such as form errors and toasts.
- Move focus on a navigation to the new page: the page's `<h1>` or `<main tabindex="-1">`. For scroll, Nuxt restores the position on back and forward and scrolls to the top for a new page; change that with `app/router.options.ts` only for a reason.
- The rules of the [Vue notes](../vue-conventions/06-templates-styling-and-accessibility.md#accessibility) apply in every page and layout: the right element for the job, a label for every control, and a key path for every pointer action. `eslint-plugin-vuejs-accessibility` runs in CI.
- `@nuxt/a11y` reports accessibility problems in development and was in alpha when these notes were written, so they do not use it.

## Sources and raw notes

Pages read on 2026-11-20:

- [Pages](https://nuxt.com/docs/directory-structure/app/pages): file-based routes, dynamic routes, "pages must have a single root element", `definePageMeta`, `validate`, `<NuxtPage>` and `page-key`, route names.
- [Layouts](https://nuxt.com/docs/directory-structure/app/layouts): a single root element that is not the `<slot />`, `definePageMeta({ layout })`, `layout: false`, `<NuxtLayout>`.
- [Middleware](https://nuxt.com/docs/directory-structure/app/middleware) and [`defineNuxtRouteMiddleware`](https://nuxt.com/docs/api/utils/define-nuxt-route-middleware): return values, `navigateTo`, `abortNavigation`, the `.global` suffix, ordering, when middleware runs.
- [Routing](https://nuxt.com/docs/getting-started/routing) and [transitions](https://nuxt.com/docs/getting-started/transitions).
- [Accessibility best practices](https://nuxt.com/docs/guide/best-practices/accessibility): `<NuxtRouteAnnouncer>` and the document title it reads, `useRouteAnnouncer`, `<NuxtAnnouncer>`, page titles, links, focus management, scroll behaviour, `@nuxt/a11y` in alpha.
- [Error handling](https://nuxt.com/docs/getting-started/error-handling): `createError` with `fatal: true`.
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): a page `[id].vue` with `definePageMeta({ validate })` and a narrowed param; a `PageMeta` augmentation in `app/types/` (an assignment of `"yes"` to `requiresAuth` gave `TS2322`); an `auth` middleware attached with `definePageMeta({ middleware: "auth" })`; a `default` layout with one root; `<NuxtRouteAnnouncer />` in `app.vue`; `<NuxtLink :to="{ name: 'loans-id', params: { id } }">`. Against the built server, `/loans/99` answered 404 when the page threw `createError({ fatal: true })`, and `/loans/1` answered 200. `nuxt typecheck`, typed ESLint, Prettier and the build passed.
