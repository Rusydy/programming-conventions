# Next.js Metadata and SEO

## Summary

Describe every public page with the Metadata API and the metadata file conventions. The root layout sets the language, the base URL and the title template, and each page sets its own title and description. Metadata does not read request data, and each brand gets its own metadata through a route group.

## Rules

### Language and root metadata

- Set `<html lang>` to the language of the content, for example `id` for Indonesian pages.
- Export a static `metadata` object from the root `layout.tsx` with `metadataBase`, `title: { default, template }` and a default `description`. A relative URL in a URL-based field fails the build when `metadataBase` is missing.

```tsx
// app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://example.com'), // the canonical origin
  title: { default: 'Example', template: '%s | Example' },
  description: 'One sentence that describes the site.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  )
}
```

- The canonical origin is the bare domain without `www` (for example `https://example.com`). Keep it in one `SITE_URL` setting, use it in `metadataBase`, `sitemap.ts` and `robots.ts`, and redirect any `www` host to it.
- `viewport`, `themeColor` and `colorScheme` belong in the `viewport` export (or `generateViewport`), not in `metadata`, since Next.js 14.

### Per-page metadata

- Every public page defines its own `title` and `description`. Use the static `metadata` object when the values do not depend on request data, and `generateMetadata` for data-driven pages such as a job detail.
- Only Server Components export `metadata` or `generateMetadata`, and a segment exports one of them, never both.
- `title.template` applies to child segments, not to the layout that defines it. A page that needs its exact title uses `title.absolute`.
- Metadata merges shallowly. A child that sets `openGraph` replaces the whole `openGraph` object of its parent. Share nested fields through a common constant.
- Share data between `generateMetadata` and the page with `fetch` memoisation or `React.cache`, so one request serves both.
- Set `alternates.canonical` on pages that more than one URL can reach.
- Do not read request data (`headers()`, `cookies()`) in `generateMetadata`. A static `metadata` export per route group covers a site with several brands ([multi-domain sites](#multi-domain-sites)). The only request read in the root layout is the CSP nonce ([CSP](10-security.md#content-security-policy)).

### File-based metadata

- Put these files in `app/` instead of writing `<link>` and `<meta>` tags: `favicon.ico`, `icon.*`, `apple-icon.*`, `opengraph-image.*` and `twitter-image.*`. A file overrides the `metadata` export, and a more specific file deeper in the tree wins over a file above it.
- Generate data-driven social images with `opengraph-image.tsx` and `ImageResponse` from `next/og`. It supports flexbox and a subset of CSS, and `display: grid` does not work.
- Keep manual `<head>`, `<link rel="icon">` and `<meta>` tags out of layouts.

### Sitemap and robots

- Add `app/sitemap.ts` (default export returning `MetadataRoute.Sitemap`) and `app/robots.ts` (returning `MetadataRoute.Robots`), with an absolute `sitemap` URL in the robots file. Both are cached unless they read request-time data.
- Build the sitemap from the same source as the routes: the static route list plus CMS lists such as job posts.

```ts
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/' },
    sitemap: 'https://example.com/sitemap.xml',
  }
}
```

- Do not allow-list `/robots.txt` or `/sitemap.xml` in `proxy.ts` unless the files exist.

### Structured data

- JSON-LD is not used, because no requirement names a type. When one does, render it as a plain `<script type="application/ld+json">` in the page (`next/script` is for executable code, and JSON-LD is data). `JSON.stringify` does not escape `<`, so replace `<` in the payload with its Unicode escape sequence, as the Next.js JSON-LD guide shows.

### Bots and streaming

- A dynamic `generateMetadata` streams after the first UI. Bots that cannot run JavaScript (for example `facebookexternalhit`) receive the metadata in `<head>`. Keep the default `htmlLimitedBots` list unless you have a measured reason.

### Multi-domain sites

- When one deployment serves several brands or domains, give each brand its own route group (or root layout) with its own metadata. Map host to route with `rewrites()` and `has: [{ type: 'host', value: '...' }]`, as the redirects reference shows for `redirects()`.
- Do not branch on the `host` header inside the root `generateMetadata`.
- Keep host rules in `proxy.ts` when the project already has one for the CSP nonce. Otherwise use `redirects()` and `rewrites()`.
- A second domain can serve its own landing page: `proxy.ts` redirects that host to a route, which keeps its own layout. That page moves into a `(standalone)` route group ([route groups](03-project-layout-and-routing.md#route-groups-and-private-folders)).

## Sources and raw notes

Pages read on 2026-10-26:

- [Metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images) and the [`generateMetadata` reference](https://nextjs.org/docs/app/api-reference/functions/generate-metadata): fields, `metadataBase`, title template, merging, streaming metadata, Cache Components behaviour.
- [`sitemap.xml`](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap) and [`robots.txt`](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots).
- [JSON-LD guide](https://nextjs.org/docs/app/guides/json-ld).
- [Project structure](https://nextjs.org/docs/app/getting-started/project-structure): metadata file conventions.
- [`redirects`](https://nextjs.org/docs/app/api-reference/config/next-config-js/redirects): `host` matching, and [self-hosting](https://nextjs.org/docs/app/guides/self-hosting) (rewrite by header, cookie, query).
- [Production checklist](https://nextjs.org/docs/app/guides/production-checklist): Metadata API, OG images, sitemaps and robots.
