# Modern Next.js by Release

## Summary

This note lists what each Next.js release added and which old idiom each addition replaces. Write new code with the modern idiom. Treat the old idiom as something to replace when you touch the line, and run the codemods when you upgrade.

## Rules

### Release timeline

| Version | Released | What matters for these conventions |
| --- | --- | --- |
| 13 | 2022-10-25 | The `app` directory (beta) with layouts, React Server Components and streaming. `next/font`. A new `next/image`. |
| 13.4 | 2023-05-04 | The App Router becomes stable. |
| 14 | 2023-10-26 | Server Actions become stable. |
| 15 | 2024-10-21 | React 19 support (React 19 is the minimum for the App Router). `params`, `searchParams`, `cookies()`, `headers()` and `draftMode()` become async. `fetch`, GET Route Handlers and the client router cache stop caching by default. Turbopack for `next dev` is stable. `next.config.ts`. |
| 15.1 | 2024-12-10 | Stable React 19 support. Experimental authorisation APIs. |
| 15.2 | 2025-02-26 | Better error debugging. Streaming metadata. |
| 15.3 | 2025-04-09 | Turbopack for builds. Client instrumentation and navigation hooks. |
| 15.4 | 2025-07-14 | Stability and performance. |
| 15.5 | 2025-08-18 | Turbopack builds in beta. Stable Node.js middleware. `next typegen` and the route props helpers. `next lint` deprecated. Deprecation warnings for 16. |
| 16 | 2025-10-21 | Turbopack is the default bundler. Cache Components (`'use cache'`). `proxy.ts` replaces `middleware.ts`. React Compiler support is stable. React 19.2. `updateTag`, `refresh` and `revalidateTag(tag, profile)`. Removals and new image defaults. |
| 16.1 | 2025-12-18 | Turbopack file system cache for `next dev` is stable. Experimental bundle analyzer. `next upgrade`. |
| 16.2 | 2026-03-18 | Stable Adapter API. `unstable_retry` for `error.tsx`. `AGENTS.md` from `create-next-app`. Faster dev start and rendering. |
| 16.3 | 2026-08-03 | Instant Navigations and Partial Prefetching. `retry` and `catchError`. Root params. Bundled docs for agents. TypeScript 7 type checking. File system cache for builds. |
| 16.4 | 2026-10-06 | Cache Components recommended for every app and on in `create-next-app`. `ensureStatic`, `navigation()`, `prefetch()`. React 19.3. `next upgrade --agent`. |
| 17 | not released | The 16.4 post says Cache Components become the default. |

### Old idiom, modern idiom

| Old | Modern | Since |
| --- | --- | --- |
| `pages/_app`, `pages/_document` | Root `app/layout.tsx` | App Router (13.4) |
| `pages/api/*` API routes | Route Handlers (`route.ts`) | App Router (13.4) |
| `next/head` | Metadata API: `metadata`, `generateMetadata`, metadata files | 13.2 |
| `@next/font` | `next/font` | 15 |
| `useFormState` | `useActionState` | 15 (React 19) |
| Synchronous `params`, `searchParams`, `cookies()`, `headers()`, `draftMode()` | `await` them | Async in 15, sync access removed in 16 |
| Implicit caching of `fetch` and GET handlers | Uncached by default. Opt in with `cache: 'force-cache'`, or with `'use cache'` | 15 |
| `unstable_cache`, `dynamic`, `revalidate`, `fetchCache` segment config | `'use cache'`, `cacheLife`, `cacheTag` | 16 with `cacheComponents` |
| `unstable_cacheLife`, `unstable_cacheTag` | `cacheLife`, `cacheTag` | 16 |
| `revalidateTag(tag)` | `revalidateTag(tag, 'max')`, or `updateTag(tag)` in a Server Action | 16 |
| `experimental.ppr`, `experimental_ppr`, `experimental.dynamicIO`, `experimental.useCache` | `cacheComponents` | 16 |
| `middleware.ts`, `middleware()`, `skipMiddlewareUrlNormalize` | `proxy.ts`, `proxy()`, `skipProxyUrlNormalize` | 16 |
| `next lint`, the `eslint` config option, `.eslintrc.*` | ESLint CLI and `eslint.config.mjs` | 16 |
| `next dev --turbopack`, `experimental.turbopack` | Plain `next dev`, top-level `turbopack` | 16 |
| `serverRuntimeConfig`, `publicRuntimeConfig` | Environment variables | 16 |
| `images.domains`, `next/legacy/image` | `images.remotePatterns`, `next/image` | Deprecated in 16 |
| `<Image priority>` | `preload`, `loading="eager"` or `fetchPriority="high"` | Deprecated in 16 |
| `layout`, `objectFit`, `objectPosition` on `next/image` | `className` or `style` | Removed from the API in 13 |
| `experimental.bundlePagesExternals`, `experimental.serverComponentsExternalPackages` | `bundlePagesRouterDependencies`, `serverExternalPackages` | 15 |
| `error.tsx` prop `reset` | `retry` | `unstable_retry` in 16.2, `retry` in 16.3 |
| `unstable_catchError` | `catchError` | 16.3 |
| `unstable_rootParams` | `next/root-params` | Removed in 16, new API in 16.3 |
| AMP (`useAmp`, `amp` config) | Removed | 16 |

The caching rows (`'use cache'`, `cacheLife`, `cacheTag`, `cacheComponents`) describe the direction of the framework. Projects here stay on the previous caching model until Next.js 17 ([caching](05-data-fetching-and-caching.md#cache-components-not-adopted-on-16x)).

### Checks when upgrading

- Run the codemods: `npx @next/codemod@canary upgrade latest`, then `npx @next/codemod@canary next-async-request-api .` when code still reads request APIs synchronously. `npx @next/codemod@canary next-lint-to-eslint-cli .` moves lint scripts to the ESLint CLI.
- Moving from 15 to 16:
  - Node.js 20.9 or later, TypeScript 5.1 or later, React 19.
  - Rename `middleware.ts` to `proxy.ts` and the function to `proxy`. Keep `middleware.ts` only for the Edge runtime.
  - Remove `--turbopack` from scripts. A custom `webpack` config makes `next build` fail under Turbopack, so migrate it, or build with `--webpack`.
  - Review the image defaults: `qualities` is `[75]`, `minimumCacheTTL` is 4 hours, `maximumRedirects` is 3, local IPs are blocked, local images with query strings need `localPatterns`.
  - Every parallel route slot needs a `default.tsx`.
  - Move to an ESLint flat config.
  - Replace the single-argument `revalidateTag`.
  - Replace `serverRuntimeConfig` and `publicRuntimeConfig` with environment variables.
  - The build output no longer prints `size` and `First Load JS`.
- Cache Components stay off on 16.x ([caching](05-data-fetching-and-caching.md#cache-components-not-adopted-on-16x)). On the Next.js 17 upgrade, follow the "Migrating to Cache Components" guide or the `next-cache-components-adoption` skill. Turning on `cacheComponents` is not a rename: it can surface build errors for uncached data outside `<Suspense>`.
- Compare the route table of `next build` before and after every upgrade.

## Sources and raw notes

Pages read on 2026-10-26:

- Release posts: [Next.js 16](https://nextjs.org/blog/next-16), [16.1](https://nextjs.org/blog/next-16-1), [16.2](https://nextjs.org/blog/next-16-2), [16.3](https://nextjs.org/blog/next-16-3), [16.4](https://nextjs.org/blog/next-16-4). Dates and one-line summaries for 13 to 15.5 come from the [blog index](https://nextjs.org/blog).
- Upgrade guides: [version 16](https://nextjs.org/docs/app/guides/upgrading/version-16) and [version 15](https://nextjs.org/docs/app/guides/upgrading/version-15).
- Reference pages with version history: [`error.js`](https://nextjs.org/docs/app/api-reference/file-conventions/error), [`Image`](https://nextjs.org/docs/app/api-reference/components/image), [TypeScript](https://nextjs.org/docs/app/api-reference/config/typescript) (`next.config.ts` since 15.0.0).
- [`generateMetadata`](https://nextjs.org/docs/app/api-reference/functions/generate-metadata): metadata since 13.2, streaming since 15.2.0.
