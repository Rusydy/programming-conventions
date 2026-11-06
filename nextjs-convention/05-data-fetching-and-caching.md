# Next.js Data Fetching and Caching

- Responsibility: engineering
- Area/system: nextjs
- Keywords: data fetching, fetch, Server Components, Data Access Layer, DAL, DTO, Zod, React.cache, Promise.all, waterfall, streaming, Suspense, loading.tsx, Data Cache, next.revalidate, next.tags, force-cache, unstable_cache, revalidateTag, updateTag, revalidatePath, refresh, route segment config, dynamic rendering, Route Handlers, webhook, Cache Components, cacheComponents, use cache, cacheLife, cacheTag, Partial Prerendering, PPR, ensureStatic, ISR
- Aliases: Next.js caching, Next.js data fetching, fetch di server, revalidasi Next.js, ISR Next.js, previous caching model, Cache Components, use cache directive, caching Next.js 16
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [layout and routing](03-project-layout-and-routing.md), [Server and Client Components](04-server-and-client-components.md), [mutations and forms](06-mutations-and-forms.md), [security](10-security.md), [deployment](12-deployment-and-self-hosting.md), [modern Next.js by release](13-modern-nextjs-by-release.md).

## Summary

Fetch data in Server Components through one `server-only` module per upstream, and validate the response with Zod. Start independent requests together, and stream the slow ones behind `<Suspense>`. Cache upstream data with `fetch` options and revalidate it with tags. The HTML renders per request, and Cache Components stay off on Next.js 16.x.

## Rules

### Where to fetch

- Fetch in Server Components with `fetch` or an ORM or database client, in the component that needs the data. Identical `fetch` requests in one render are memoised, so you do not need to pass props down. Wrap non-`fetch` access (ORM, SQL) with `React.cache` to get the same effect.
- Use one data-access approach in every project: a Data Access Layer (DAL). Do not mix it with queries inside components.
- For an upstream HTTP service (a CMS or a backend API), write one `server-only` module per upstream. It reads the base URL and token from the environment, checks `response.ok`, validates the JSON with a Zod schema and returns typed data.

```ts
// lib/cms.ts
import 'server-only'
import { z } from 'zod'

const faqResponseSchema = z.object({
  data: z.array(z.object({ question: z.string(), answer: z.string() })),
})

export async function getFaqs() {
  const response = await fetch(`${process.env.CMS_API_URL}/faq`, {
    next: { revalidate: 3600, tags: ['faq'] },
  })
  if (!response.ok) throw new Error(`CMS request failed with ${response.status}`)
  return faqResponseSchema.parse(await response.json()).data
}
```

- Do not call your own Route Handler from a Server Component, because it adds a request. Call the data function directly.
- Fetch in the browser only for interactions after the first render: search as you type, polling, a user-triggered reload. Use SWR, React Query, or `use()` with a promise that a Server Component started. Do not load the first-render content of the site this way. It stays out of the HTML and adds a request waterfall.
- Type every upstream response. Do not use `any`.

### Waterfalls and streaming

- Layouts and pages render in parallel. Inside one component, consecutive `await` calls run one after another. Start independent requests first, then `await Promise.all([...])`. Use `Promise.allSettled` when one failure must not fail the rest.
- Fetch sequentially only when one request needs the result of another. Wrap the dependent part in `<Suspense>` so the rest of the page is not blocked.
- Start a request early with a `preload` function when the inputs are known but blocking work comes first. The data function must deduplicate calls (`fetch` or `React.cache`).
- Stream slow parts with `<Suspense fallback>` close to the data read. Use `loading.tsx` to stream a whole page. Design skeletons that resemble the final content.
- A layout that reads uncached or request-time data is not covered by the `loading.tsx` of its own segment, and it blocks navigation. Move the read into its own `<Suspense>` boundary or into the page.
- Bots and crawlers receive the fully rendered page instead of a stream.

### Caching and revalidation

- `fetch` is not cached by default since Next.js 15. Opt in per request with `next: { revalidate: seconds, tags: [...] }` for data that changes (CMS content uses `revalidate: 3600`), or with `cache: 'force-cache'` for data that never changes. GET Route Handlers are not cached by default either.
- These projects render the HTML of every page per request, because the root layout reads the CSP nonce ([CSP](10-security.md#content-security-policy)). The Data Cache that `fetch` options fill is the cache that matters. Do not add route segment config (`dynamic`, `revalidate`, `fetchCache`) to pages.
- Use `unstable_cache` only for a non-`fetch` result that must live across requests.
- Reading `cookies()`, `headers()` or `searchParams` makes a route dynamic. Here every page is dynamic already, so the route table of `next build` shows `ƒ` for pages and `○` only for `robots` and `sitemap`.
- Revalidate on demand after a change:
  - `revalidateTag('tag', 'max')` serves stale content while fresh content loads. It works in Server Actions and Route Handlers. The second argument, a `cacheLife` profile, has been required since 16.0.
  - `updateTag('tag')` expires the data and refreshes it in the same request, so a user sees their own change. It works in Server Actions only, and it works with `fetch` tags.
  - `revalidatePath('/path')` only when no tag fits. Tags are more precise.
  - `refresh()` refreshes the client router from a Server Action. It does not touch cached data.
- CMS content: tag each request, give it `revalidate: 3600`, and let the CMS call a webhook that runs `revalidateTag`. The handler verifies a shared secret before it revalidates.

```ts
// app/api/revalidate/route.ts
import { revalidateTag } from 'next/cache'
import { timingSafeEqual } from 'node:crypto'

export async function POST(request: Request) {
  const received = Buffer.from(request.headers.get('x-revalidate-token') ?? '')
  const expected = Buffer.from(process.env.REVALIDATE_TOKEN ?? '')
  const authorised =
    expected.length > 0 &&
    received.length === expected.length &&
    timingSafeEqual(received, expected)
  if (!authorised) return new Response('Unauthorized', { status: 401 })

  revalidateTag('faq', 'max')
  return Response.json({ revalidated: true })
}
```

### Cache Components (not adopted on 16.x)

- `cacheComponents`, `'use cache'`, `cacheLife`, `cacheTag`, Partial Prerendering and `ensureStatic` stay off on Next.js 16.x. Do not add `'use cache'` to a project.
- The nonce-based CSP forces per-request rendering, and the CSP guide says that Partial Prerendering does not work with nonces, because the static shell cannot carry one.
- `use cache` had one Critical advisory (2026-10-14: remote code execution in functions that return typed arrays) and two Medium advisories (2026-09-30: a cache leak across root params in nested `use cache` functions, and Draft Mode content leaking into regular responses) ([patching](10-security.md#patching)).
- `fetch` options already cache the CMS data that these sites read, so the new model would add cost and no benefit.
- Next.js 17 makes Cache Components the default. That upgrade follows the official guide "Migrating to Cache Components" and the `next-cache-components-adoption` skill.

### Route Handlers

- Use a Route Handler (`route.ts`) for webhooks, for endpoints that external consumers call, and for a Client Component that needs a backend resource a Server Component cannot pass down. Do not use one for data that Server Components can fetch directly.
- A GET handler is not cached. Add `export const dynamic = 'force-static'` only to a handler whose response never depends on the request.
- A segment cannot hold both `route.ts` and `page.tsx`. Put handlers under a separate path such as `app/api/...`.
- Special handlers (`sitemap.ts`, `robots.ts`, `opengraph-image.tsx`, `icon.tsx`) stay static unless they read request-time data.

## Sources and raw notes

Pages read on 2026-10-26:

- [Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data): server fetching, streaming, parallel and sequential patterns, `React.cache`, preloading.
- [Caching and revalidating (previous model)](https://nextjs.org/docs/app/guides/caching-without-cache-components): `fetch` options, `unstable_cache`, segment config, on-demand revalidation.
- [`updateTag`](https://nextjs.org/docs/app/api-reference/functions/updateTag) (works with `fetch` tags, Server Actions only) and [`refresh`](https://nextjs.org/docs/app/api-reference/functions/refresh) (Server Actions only).
- [Caching (Cache Components)](https://nextjs.org/docs/app/getting-started/caching) and [Content Security Policy](https://nextjs.org/docs/app/guides/content-security-policy): Partial Prerendering is incompatible with nonce-based CSP.
- [Next.js 16.4](https://nextjs.org/blog/next-16-4): Cache Components become the default in Next.js 17.
- [Upgrading to version 16](https://nextjs.org/docs/app/guides/upgrading/version-16): `revalidateTag` signature.
- Security posts of [2026-09-30](https://nextjs.org/blog/september-2026-security-release) and [2026-10-14](https://nextjs.org/blog/nextjs-security-update-october-14-2026): the `use cache` advisories.
- [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers) and [Data security](https://nextjs.org/docs/app/guides/data-security) (Data Access Layer).
- Verified in a scratch build: with the nonce CSP in the root layout, every page is `ƒ` (dynamic).
