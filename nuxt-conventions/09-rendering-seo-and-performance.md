# Nuxt Rendering, SEO and Performance

## Summary

Nuxt renders each page on the server and hydrates it in the browser. Set the rendering mode per route with `routeRules`, give every page a title and description with `useSeoMeta()`, and keep the server-rendered and browser-rendered output identical so that hydration does not fail. Load less code with lazy components and lazy hydration, and measure before you tune.

## Rules

### Rendering modes

- Keep the default, universal rendering: the server renders the HTML, the browser hydrates it, and later navigation runs in the browser. It gives a fast first paint, crawlable HTML and a single codebase.
- Choose the mode per route with `routeRules` in `nuxt.config.ts`, and do not turn the whole app into another mode without a reason:

| Rule | Effect | Use it for |
| --- | --- | --- |
| `{ prerender: true }` | Render once at build time and serve a static file | A page whose content is the same until the next deploy: a landing page, documentation |
| `{ swr: 60 }` | Cache the rendered response for 60 seconds, then serve it stale while a fresh one renders | A public page that tolerates a short delay: a product list |
| `{ isr: 3600 }` | Like `swr`, and also cached by a CDN that supports it | The same, on Netlify or Vercel |
| `{ ssr: false }` | Render in the browser only (a single-page app section) | An admin area behind a login that needs no search indexing |
| `{ redirect: "/new" }` | A server-side redirect | A moved page |
| `{ headers: { ... } }` | Add response headers | Cache headers for a path |
| `{ cors: true }` | Add CORS headers | An API another origin calls |

- Do not `prerender` a page that shows data that changes between deploys. A prerendered page runs `useFetch` at build time and ships that data as static files, so the page is stale until the next build. The sample's first version prerendered `/`, and the build output held a static `index.html` with the loans of build time. Use `swr` instead: the built node server then answered `cache-control: s-maxage=60, stale-while-revalidate`.
- Do not cache a response that depends on the user: never put `swr` or `isr` on a route that reads a session cookie, and never on an API handler that returns private data. Nitro caches by URL, not by cookie, so one user's page could be served to another.
- A fully static site (`nuxt generate`, or `routeRules` with `prerender: true` on every route) needs no Node.js server, and deploys to any static host ([deployment](11-deployment-and-presets.md#static-sites)). Choose it when every page can be built ahead of time.
- Use `ssr: false` for a section only when search engines do not need it and the first paint can wait. A client-only page shows a blank page until the scripts load, and it has no server error pages.
- Keep the same behaviour on the server and in the browser. Do not branch on `import.meta.client` and `import.meta.server` to render different markup; use them for side effects only.

### Hydration

- The browser's first render must produce the markup that the server sent. A mismatch makes Nuxt log a warning and redo the render, which costs time and can break event handlers. The Nuxt documentation names the causes:
  - **Browser-only APIs in setup.** `window`, `document`, `localStorage` and `navigator` do not exist on the server. Read them in `onMounted()`, or wrap the component in `<ClientOnly>`.
  - **Inconsistent data.** `Math.random()`, `Date.now()` and `new Date()` give a different value on each side. Compute them once on the server with `useState()`, or after mount.
  - **Client-state branches.** `v-if="isMounted"` that differs on first render, or content that depends on the viewport.
  - **Time-dependent text.** A relative time ("5 minutes ago") renders on the server and is old when the browser hydrates. Format it after mount, or with a fixed reference time.
  - **Third-party libraries** that write to the DOM before hydration. Load them in a `.client` plugin or inside `<ClientOnly>`.
  - **Invalid HTML nesting** (`<div>` in `<p>`, a `<button>` in a `<button>`), which the browser repairs before hydration. Fix the markup.
- Use `<ClientOnly>` with a `#fallback` slot of the same size, so that the layout does not jump. Use it for a widget that cannot render on the server, and for nothing else.
- Use `useId()` for ids, as the [Vue notes](../vue-conventions/05-components-props-emits-and-slots.md#props) say. It gives the same id on both sides.
- Read hydration warnings in the browser console in development, and fix each one. Treat a hydration mismatch as a bug.

### SEO

- Give every page a unique `title` and `description` with `useSeoMeta()`, in the page's `<script setup>`:

```ts
useSeoMeta({
  title: "Loans",
  description: "All active loans",
});
```

- Use `useSeoMeta` for the meta tags it knows (`title`, `description`, `ogTitle`, `ogImage`, `robots`) and `useHead()` for anything else (a `link rel="canonical"`, a script, `htmlAttrs`). They are typed, and they dedupe by key. Set a global `titleTemplate` once, in `app.vue`, with `useHead({ titleTemplate: (title) => (title ? title + " - Loans" : "Loans") })`.
- Set `app.head` in `nuxt.config.ts` for defaults that every page shares (`lang` on `<html>`, the charset, the viewport, the site name). Set `htmlAttrs.lang` to the page language, because the route announcer and screen readers use it.
- A title is also what `<NuxtRouteAnnouncer>` reads, so two pages with the same title announce nothing ([routing](04-pages-routing-and-navigation.md#accessibility)).
- Provide `robots.txt` in `public/`, and a canonical URL for pages with several addresses. Generate a sitemap with a Nuxt module only when the site has pages to index, and say why in the pull request.
- Render the content that crawlers need on the server. A page with `ssr: false` has no HTML for them.
- Return the right status: 404 for a missing page (`createError({ fatal: true })`), 301 for a moved one (`routeRules` `redirect`). A soft 404 harms indexing.
- Use `<NuxtLink>` for internal links, so that crawlers see `<a href>`, and give links real text.

### Loading

- Keep the first load small. Import what you use, avoid big libraries in the main bundle, and look at what `npx nuxt analyze` shows for each chunk.
- Load a component later with the `Lazy` prefix: `<LazyHeavyChart v-if="open" />`. Nuxt splits it into its own chunk and fetches it when it first renders. Use it for a modal, a chart, an editor, and anything below the fold that needs a lot of code.
- Delay the hydration of a component that is server-rendered but needs scripts later, with a hydration directive on its `Lazy` form: `<LazyLoanForm hydrate-on-visible />`. The component's HTML arrives at once, and its JavaScript loads when it scrolls into view. Other strategies are `hydrate-on-idle`, `hydrate-on-interaction`, `hydrate-on-media-query` and `hydrate-after`, and a `hydrate-never` component never becomes interactive, so use it only for static content. A delayed component must not be a parent of one that needs to be interactive at once.
- Let `<NuxtLink>` prefetch. Nuxt fetches the code of a linked route when the link becomes visible. Turn it off with `:prefetch="false"` for a link to a rarely used page, and never remove it globally.
- Do not use `<script>` tags in `app.head` for third-party code. Load it after interaction or after idle, with the `@nuxt/scripts` module when you need several, and keep the number of third-party scripts small.
- Do not overuse plugins. Every plugin runs on start-up, on the server for each request and in the browser. A plugin that does a slow job delays every page. Keep a plugin to registering something, and run slow work in a composable on demand. If a plugin must be `async`, mark it `parallel`, as the plugin best practices say.
- Fetch less on the server: `pick` and `transform` shrink the payload ([data fetching](05-data-fetching.md#payload-and-size)). Do not wrap `useFetch` in a loop of many requests; make one handler that returns what the page needs.

### Images, fonts and assets

- Use `@nuxt/image` and its `<NuxtImg>` and `<NuxtPicture>` for content images when the site has more than a few: it resizes, converts to modern formats and lazy-loads. Always give `width` and `height` (or an aspect ratio) so that the layout does not shift, and `alt` for every image. Do not add the module for a single logo.
- Use `@nuxt/fonts` for web fonts: it downloads a font, serves it from your origin and generates a fallback with matching metrics. Do not link a font from a third-party CDN in the page head.
- Put images that the build should hash in `app/assets/`, and static files that must keep their names in `public/`. The hashed files in `/_nuxt/` get a long cache lifetime ([deployment](11-deployment-and-presets.md#nginx)).
- Use CSS before a CSS framework, and scoped styles in components, as the [Vue notes](../vue-conventions/06-templates-styling-and-accessibility.md#styling) say. Add a UI library (`@nuxt/ui`) or Tailwind CSS only for a reason you write in the pull request.

### Measuring

- Measure before you tune. Use the Nuxt DevTools timeline in development, `nuxt analyze` for the bundle, the browser's performance panel, and Lighthouse or PageSpeed Insights on the built, deployed app. Record Core Web Vitals (LCP, INP, CLS) from real users when the site matters.
- The performance tips of the [Vue notes](../vue-conventions/11-performance-and-security.md#performance) apply: stable props, `shallowRef` for large data, a virtual list for hundreds of rows.

## Sources and raw notes

Pages read on 2026-11-20:

- [Rendering modes](https://nuxt.com/docs/guide/concepts/rendering): universal rendering, client-side rendering, hybrid rendering and route rules (`redirect`, `proxy`, `ssr`, `cors`, `headers`, `swr`, `isr`, `prerender`, `noScripts`, `appMiddleware`).
- [Prerendering](https://nuxt.com/docs/getting-started/prerendering): crawl-based prerendering, payload extraction, `prerenderRoutes`.
- [Hydration best practices](https://nuxt.com/docs/guide/best-practices/hydration): why mismatches matter, how to detect them, common reasons (browser-only APIs, inconsistent data, client-state branches, third-party libraries, time-dependent content), `<ClientOnly>`.
- [Performance best practices](https://nuxt.com/docs/guide/best-practices/performance): links and prefetching, resource hints, hybrid rendering, lazy loading components, lazy hydration, fetching data, `@nuxt/image`, `@nuxt/fonts`, `@nuxt/scripts`, `nuxi analyze`, DevTools, common problems (overusing plugins, unused dependencies).
- [Plugins best practices](https://nuxt.com/docs/guide/best-practices/plugins): avoid costly setup, use composition, `parallel` for async plugins.
- [`app/components`](https://nuxt.com/docs/directory-structure/app/components): `Lazy` prefix, delayed hydration strategies and their caveats, `.client` components.
- [SEO and meta](https://nuxt.com/docs/getting-started/seo-meta): `useSeoMeta`, `useHead`, `app.head`, `titleTemplate`. [Images](https://nuxt.com/docs/getting-started/images) and [fonts](https://nuxt.com/docs/getting-started/fonts).
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `useSeoMeta({ title })` in a page (the rendered HTML had `<title>Loans</title>`); `<LazyLoanForm hydrate-on-visible />` (it type-checked and built); `routeRules: { "/": { prerender: true } }` produced a static `.output/public/index.html` that held the data of build time, and `routeRules: { "/": { swr: 60 } }` answered `cache-control: s-maxage=60, stale-while-revalidate` from the built node server.
