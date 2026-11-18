# SvelteKit Rendering, SEO and Performance

## Summary

Keep the default hybrid rendering: the server renders each page, and the browser hydrates it and takes over navigation. Change a page option only for a route that needs it, and write the reason beside it. Give every page a unique title and description, import images instead of dropping them in `static/`, and measure a production build, not the dev server.

## Rules

### Page options

- Leave `ssr`, `csr` and `prerender` at their defaults. SvelteKit renders on the server first, and the SEO page says to keep server rendering on unless you have a good reason. Server-rendered content is indexed more often and more reliably.
- Export a page option from `+page.ts`, `+page.server.ts`, `+layout.ts` or `+layout.server.ts` as a literal: `export const prerender = true;`. A layout's value is the default for every route below it, and a child overrides it. When all the options in a file are literals, SvelteKit reads them without running the module. If one is computed, the module loads on the server, so no browser-only code may run at its top level.
- Prerender a page whose content is the same for every visitor, such as a marketing page or documentation. Prerendering needs these conditions: no form action in the page, no read of `url.searchParams` while it renders, and a link or an `entries` list that lets the crawler reach every dynamic route:

```ts
// src/routes/blog/[slug]/+page.server.ts
export const prerender = true;

export function entries() {
  return [{ slug: "hello-world" }];
}
```

- Use `prerender = "auto"` for a dynamic route where only some pages are prerendered, so the route stays in the server manifest for the rest. A route set to `true` that the crawler never reaches fails the build, so add `entries` or a link, or switch to `"auto"`.
- Never prerender a page that holds data for one user, and remember that `handle` does not run for a prerendered page.
- Set `ssr = false` only for a page that cannot render on the server, such as one built on a browser-only library, and not in the root layout. A root `ssr = false` turns the whole app into a single-page app, which adds round trips before the first paint and removes the SEO benefit. If the app needs no server at all, such as a desktop shell, use plain Svelte and the [Svelte notes](../svelte-conventions/01-principles-and-sources.md).
- Set `csr = false` only for a page of pure content, such as a legal text. It ships no JavaScript, so links do full page loads and forms cannot be enhanced.
- Leave `trailingSlash` at `"never"`. Do not use `"ignore"`, because `/x` and `/x/` become two URLs. `"always"` makes a prerendered page `about/index.html`, which hosts that cannot map `/about` to `about.html` need.
- `config` is shaped by the adapter and merges only at its top level, so a nested object in a page replaces the layout's one.
- In SvelteKit 3, the route `config` of a universal `+page.ts` or `+layout.ts` takes precedence over the server file's `config`.

### SEO

- Give every page a unique `<title>` and `<meta name="description">` in `<svelte:head>`. A usual pattern returns an `seo` object from `load` and reads it from `page.data` in the root layout:

```svelte
<!-- src/routes/+layout.svelte -->
<script lang="ts">
  import { page } from "$app/state";

  import type { LayoutProps } from "./$types";

  let { children }: LayoutProps = $props();
</script>

<svelte:head>
  <title>{page.data.seo?.title ?? "Loans"}</title>
  <meta name="description" content={page.data.seo?.description ?? ""} />
</svelte:head>

{@render children()}
```

- Declare `seo` in `App.PageData` in `src/app.d.ts`, so that `page.data.seo` is typed.
- Set the `lang` attribute on `<html>` in `src/app.html`.
- Serve one URL per page. SvelteKit redirects to the form that `trailingSlash` names, and duplicate URLs hurt SEO.
- Build a sitemap with a `+server.ts` at `src/routes/sitemap.xml/` that returns `application/xml`. Add `robots.txt` to `static/`.
- Leave the dynamic-rendering workaround, which serves crawlers a different render, alone. The documentation does not recommend it.

### Images and assets

- Import an image from `src/lib/assets/` and give it to `<img src={...}>`. Vite hashes the file name for long caching and inlines small files. Use `static/` only for a file that must keep its name, such as `robots.txt` or a favicon that something else links to.
- Use `@sveltejs/enhanced-img` for images that exist at build time. Add `enhancedImages()` to the Vite plugins before `sveltekit()`, then write `<enhanced:img src="..." alt="..." />`. It produces `avif` and `webp`, sets the `width` and `height`, and makes several sizes. Set `sizes` for an image wider than about 400 pixels, and give originals at about twice the display width, never upscaled.
- Serve images that are not known at build time, such as ones from a CMS, through a CDN with a library such as `@unpic/svelte`.
- Always write `alt`, and `alt=""` for a decorative image. The compiler warns when it is missing.
- Give the largest above-the-fold image `fetchpriority="high"` and no `loading="lazy"`. Give every image a size or an aspect ratio so that the layout does not shift as it loads.
- Compress video, lazy-load video below the fold with `preload="none"`, and strip audio from a muted video.

### Performance

- Measure a production build with `npm run build && npm run preview`. The dev server behaves differently. Use PageSpeed Insights or Lighthouse, and the Network and Performance panels of the browser.
- Keep the default preloading (`data-sveltekit-preload-data="hover"` on `<body>`). SvelteKit already splits the code per route, preloads the critical JavaScript and CSS, and hashes the files so they cache forever.
- Return a promise from a server `load` for slow data that is not essential, so it streams ([load](04-load-and-data-fetching.md#streaming)). Do not chain requests in the browser: move them to a server `load`, run independent ones in parallel, and join dependent queries in the database.
- SvelteKit does not preload fonts. Preload the font files that the first paint needs with the `preload` filter of `resolve` in `handle`, and subset fonts to the characters that you use.
- Load code that only some users need with a dynamic `import()`. Keep third-party scripts few, prefer server-side analytics, and run the rest off the main thread with a tool such as Partytown.
- Compress responses at nginx, not in the app, as the [infrastructure notes](../infra-conventions/06-nginx-reverse-proxy.md) say. Use HTTP/2 or later, because code splitting makes many small files.
- Run the newest Svelte. Svelte 5 is smaller and faster than Svelte 4.
- Use `rollup-plugin-visualizer` to see what is in a bundle when a measurement points at its size.

## Sources and raw notes

Pages read on 2026-11-18:

- [Page options](https://svelte.dev/docs/kit/page-options): `prerender` with `true`, `false` and `"auto"`, `entries`, the prerender limits, `ssr`, `csr`, `trailingSlash`, `config`, static evaluation of literal options, inheritance. [`adapter-static`](https://svelte.dev/docs/kit/adapter-static): the cost of a fallback page and `ssr = false`.
- [SEO](https://svelte.dev/docs/kit/seo): server rendering, Core Web Vitals, normalised URLs, titles and meta tags in `<svelte:head>`, the `page.data` pattern, the sitemap endpoint. [Images](https://svelte.dev/docs/kit/images): Vite assets, `@sveltejs/enhanced-img`, `sizes`, CDN images, LCP images, alt text. [Performance](https://svelte.dev/docs/kit/performance): diagnosing, preview mode, fonts and the `resolve` preload filter, third-party scripts, waterfalls, streaming.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): route `config` precedence of universal files.
- npm registry on 2026-11-18: `@sveltejs/enhanced-img` 1.0.1.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `page` from `$app/state` in `+error.svelte` type-checked, and the default rendering ran on the built Node.js server. The prerender, SEO, image and font examples come from the documentation, and the sample application did not exercise them.
