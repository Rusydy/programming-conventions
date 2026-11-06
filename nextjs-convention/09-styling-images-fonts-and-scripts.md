# Next.js Styling, Images, Fonts and Scripts

- Responsibility: engineering
- Area/system: nextjs
- Keywords: Tailwind CSS, CSS Modules, global CSS, next/image, Image, remotePatterns, localPatterns, qualities, preload, priority, sizes, fill, next/font, Geist, Inter, variable font, next/script, @next/third-parties, GoogleAnalytics, Google Tag Manager, public folder, assetPrefix, consent, line-clamp
- Aliases: Next.js styling, optimasi gambar Next.js, font Next.js, Google Analytics Next.js, script pihak ketiga Next.js, CSS Next.js, Tailwind Next.js, next/image config
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [setup and tooling](02-project-setup-and-tooling.md), [Server and Client Components](04-server-and-client-components.md), [metadata and SEO](08-metadata-and-seo.md), [security](10-security.md).

## Summary

Use Tailwind CSS for most styling and CSS Modules for the rest. Use the built-in `next/image`, `next/font` and `next/script` components instead of raw tags, and keep every remote image host and every third-party script on an explicit allow-list.

## Rules

### Styling

- Use Tailwind CSS for most styling, CSS Modules (`name.module.css`) when utilities are not enough, and global CSS only for truly global rules such as the Tailwind base layer.
- Import global CSS once, in the root layout. Keep other CSS imports in as few entry files as you can. Import order sets CSS order, and the order in `next build` can differ from `next dev`, so check the production build.
- Turn off linters that sort imports automatically (such as ESLint `sort-imports`), because they reorder CSS imports.
- New projects use Tailwind CSS v4: `@tailwindcss/postcss` in `postcss.config.mjs` and `@import 'tailwindcss'` in the global stylesheet. The docs keep a separate v3 guide for older browsers. A project on v3 stays on v3 until a change needs something that only v4 offers. There is no standalone migration.
- Do not install a plugin for a feature that Tailwind ships in its core. Since Tailwind v3.3 the `@tailwindcss/line-clamp` plugin is built in, and the build prints a warning when the plugin is still listed.
- Name CSS Modules after their component (`header.module.css` beside `header.tsx`).

### Images

- Use `next/image` for content images, and always give `alt`.
- Import local images statically, so that width, height and the blur placeholder are known. For remote images give `width` and `height`, or use `fill` inside a sized parent with a `sizes` value.
- Use `preload` only on the Largest Contentful Paint image. In most cases `loading="eager"` or `fetchPriority="high"` is enough. The `priority` prop is deprecated since 16.0.
- Do not pass the removed pre-13 props `layout`, `objectFit` and `objectPosition`. Use `className` or `style`.
- Allow remote hosts in `images.remotePatterns` with `protocol`, `hostname` and `pathname` as specific as possible. A missing `protocol`, `port`, `pathname` or `search` implies `**`, and a bare `hostname: '**'` allows every host. Both let outsiders send URLs through your image optimiser. `images.domains` is deprecated.
- Know the 16.0 defaults: `qualities` is `[75]` (a `quality` prop that is not listed is coerced to the nearest listed value), `minimumCacheTTL` is 4 hours, `maximumRedirects` is 3, `dangerouslyAllowLocalIP` is off, and a local image with a query string needs `images.localPatterns`. List the qualities you use in `images.qualities`.
- Serve CMS images with `unoptimized` and leave `images.remotePatterns` empty, so that the optimiser stays closed to remote hosts. `next/image` still prevents layout shift, but nothing resizes the file, so size and compress it in the CMS before upload. Open `remotePatterns` for one host only when a measurement shows that resizing is needed, and then set `protocol`, `hostname` and `pathname` (the CMS serves uploads under `/api/uploads/`).
- Use a plain `<img>` only for something `next/image` cannot serve, and say why in a comment. ESLint flags it with `@next/next/no-img-element`.

### Fonts

- Load fonts with `next/font/google` or `next/font/local` in the root layout. Next.js self-hosts the files, so the browser sends no request to Google. Prefer variable fonts and set `subsets`.
- Expose each font as a CSS variable (`variable: '--font-inter'`) and map it in the Tailwind theme. Components then use a class, not a font name.
- Do not link fonts with a `<link>` tag. ESLint covers `google-font-display`, `google-font-preconnect` and `no-page-custom-font`.

### Scripts and analytics

- Load third-party scripts with `next/script` and a `strategy`. An inline script needs an `id`, and under the nonce CSP every script also needs the `nonce` prop.
- For Google Analytics use `GoogleAnalytics` from `@next/third-parties/google`, and pass it the nonce. The docs mark that package as experimental, so pin its version.
- Google Analytics 4 records a page view on every history change by itself when enhanced measurement is on ("Page changes based on browser history events"). Do not also send `gtag('config', ...)` on each route change, unless you turn the default measurement off. Both together can count page views twice.
- Read the measurement ID from `NEXT_PUBLIC_GA_ID` once, not as a literal in several files.
- Analytics loads only after the visitor accepts. The consent banner owns the choice: it stores `accepted` or `rejected`, and it renders `GoogleAnalytics` only for `accepted`. Reject means that no analytics script loads.

### Static assets

- Put static files in `public/` and refer to them from `/`.
- Commit no file larger than 5 MB. Compress video first (for example with `ffmpeg`). A file that stays above 5 MB lives outside the repository, on the company's static host or object storage, and the page refers to it by URL.

## Sources and raw notes

Pages read on 2026-10-26:

- [CSS](https://nextjs.org/docs/app/getting-started/css): Tailwind v4 setup, CSS Modules, global CSS, ordering and recommendations.
- [Image optimization](https://nextjs.org/docs/app/getting-started/images) and the [`Image` reference](https://nextjs.org/docs/app/api-reference/components/image): props, `preload`, `remotePatterns`, version history.
- [Font optimization](https://nextjs.org/docs/app/getting-started/fonts).
- [Third-party libraries](https://nextjs.org/docs/app/guides/third-party-libraries): `GoogleAnalytics`, automatic page views.
- [Upgrading to version 16](https://nextjs.org/docs/app/guides/upgrading/version-16): image defaults.
- [ESLint plugin](https://nextjs.org/docs/app/api-reference/config/eslint): image, font and script rules.
- npm weekly downloads on 2026-10-26 (`api.npmjs.org`): `tailwindcss` 4.x 66.2 million, 3.x 23.4 million.
