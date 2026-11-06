# Next.js Security

- Responsibility: engineering
- Area/system: nextjs
- Keywords: environment variables, NEXT_PUBLIC, secrets, Data Access Layer, DAL, DTO, server-only, taint, Server Actions security, authorisation, IDOR, CSRF, allowedOrigins, NEXT_SERVER_ACTIONS_ENCRYPTION_KEY, proxy.ts, middleware bypass, dangerouslySetInnerHTML, XSS, sanitiser, Content Security Policy, CSP, nonce, SRI, remotePatterns, SSRF, security release, CVE, patch
- Aliases: keamanan Next.js, Next.js security checklist, secret di Next.js, CSP Next.js, patch keamanan Next.js, XSS Next.js, rilis keamanan Next.js
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [setup and tooling](02-project-setup-and-tooling.md), [Server and Client Components](04-server-and-client-components.md), [mutations and forms](06-mutations-and-forms.md), [styling, images, fonts and scripts](09-styling-images-fonts-and-scripts.md), [deployment](12-deployment-and-self-hosting.md).

## Summary

Keep secrets and data access on the server, behind one data layer that authorises every read and write. Treat Server Functions, `proxy.ts` and Route Handlers as the entry points to audit, sanitise any HTML that you did not write, and apply Next.js patch releases within fixed deadlines. From July to October 2026, image handling or Server Actions appeared in every security release.

## Rules

### Environment variables

- Variables are server-only by default. Next.js inlines a variable that starts with `NEXT_PUBLIC_` into the browser bundle at build time, so it is never a secret.
- `NEXT_PUBLIC_` values are frozen when `next build` runs. A Docker image that is built once and promoted through several environments needs a different route for per-environment values: read them on the server at request time (after `await connection()` or another request-time API), or serve them from your own endpoint ([deployment](12-deployment-and-self-hosting.md#environment-variables-at-runtime)).
- Only the data layer reads secrets from `process.env`.
- Keep secrets, private service URLs, tunnel URLs and tokens out of source code. Configuration comes from the environment. `.env*` files stay out of Git and a `.env.example` lists the names ([setup](02-project-setup-and-tooling.md#environment-files)).

### Data Access Layer

- Every project uses a Data Access Layer: an internal, `server-only` module that authorises each read and returns small Data Transfer Objects (DTOs) ([data fetching](05-data-fetching-and-caching.md#where-to-fetch)).
- Return the fields a page renders and nothing else. Do not pass a raw database or CMS record to a Client Component, because every field in its props reaches the browser.
- A cached `getCurrentUser()` built with `React.cache` lets many components read the user without passing it around.
- React's taint APIs (`experimental.taint`) add a second layer but do not replace filtering in the data layer.
- A dynamic segment folder such as `[id]` is user input. Validate it.

### Server Functions

- Every exported Server Function is a public POST endpoint, even when no page imports it. Authenticate and authorise inside the function, check ownership of the resource (to prevent insecure direct object references), validate the input, and return only what the UI needs ([mutations and forms](06-mutations-and-forms.md)).
- Next.js encrypts the variables that an inline action closes over, but do not rely on encryption to keep a secret out of the browser.
- Next.js compares the `Origin` header with the `Host` header. Behind a reverse proxy with a different public host, list the allowed hosts in `serverActions.allowedOrigins`.
- With several instances, set one `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (base64, 16, 24 or 32 bytes) for the build ([deployment](12-deployment-and-self-hosting.md#several-instances)).
- Rate limiting lives at the reverse proxy and in the backend that owns the data ([mutations and forms](06-mutations-and-forms.md#return-values-and-abuse)).
- Never change state while rendering. Use an action.

### Proxy is not an authorisation layer

- `proxy.ts` and `route.ts` hold a lot of power. Audit them like any other entry point.
- Use `proxy.ts` for optimistic checks such as redirecting a visitor without a session. Do the real authorisation in the data layer and in each action.
- The July 2026 advisory CVE-2026-64642 shows why: apps built with Turbopack and a single-entry `i18n.locales` could bypass the middleware or proxy.
- Do not build the destination host of a `redirects()` or `rewrites()` rule from request-controlled input. CVE-2026-64645 turned that into SSRF and open redirects.

### Untrusted HTML

- Do not pass CMS or user HTML to `dangerouslySetInnerHTML` as it is. Sanitise it on the server with DOMPurify (`isomorphic-dompurify`) and an allow-list of tags and attributes. Do not use `sanitize-html`: DOMPurify has more than five times its weekly downloads.
- Removing `style` attributes or `<span>` tags is formatting, not sanitising. It leaves `<script>`, event-handler attributes and `javascript:` URLs in place.
- Treat links from user or CMS data the same way: allow `https:`, `mailto:` and `tel:` and nothing else.

### Content Security Policy

- Use a nonce-based CSP, set in `proxy.ts` on every response. It is the strictest option that the docs support: a script without the nonce does not run, and `'strict-dynamic'` lets trusted scripts load their own.
- Accept its cost. Every page renders per request, a CDN cannot cache the HTML, and Partial Prerendering and Cache Components do not work with nonces ([caching](05-data-fetching-and-caching.md#cache-components-not-adopted-on-16x)).
- Do not use a static CSP header with `'unsafe-inline'` for scripts, and do not use the experimental Subresource Integrity option (`experimental.sri`).
- Allow-list the third-party hosts that the site uses (Google Analytics, Tag Manager) and the CMS host in the matching directives.
- `'unsafe-eval'` is only needed in development.
- Set the other security headers (`X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `X-Frame-Options`) in the same `proxy.ts`. Send `Strict-Transport-Security` from the reverse proxy that terminates TLS.

### Images and redirects

- Leave `images.remotePatterns` empty (CMS images use `unoptimized`) and keep `dangerouslyAllowLocalIP` off ([images](09-styling-images-fonts-and-scripts.md#images)). Without any `remotePatterns`, the September 2026 SSRF in Image Optimization (CVE-2026-94483) does not apply.

### Patching

- Read each monthly security post and the out-of-band posts. Update the lock file within three working days of the post for a Critical or High issue, and within 30 days (the next monthly release) for a Medium or Low issue. Use the workaround in the post when you cannot upgrade at once.
- From July to October 2026 every security release touched image handling (Image Optimization or `ImageResponse`) or Server Actions:

| Post date | Patched releases | Highlights |
| --- | --- | --- |
| 2026-07-20 | 16.2.11, 15.5.21 | Server Actions DoS (High), proxy bypass with Turbopack and a single locale (High), SSRF in `rewrites()` and in Server Actions on custom servers (High), SVG DoS in Image Optimization (Medium) |
| 2026-08-25 | 16.3.3, 15.5.24 | RCE in Image Optimization with AVIF (Critical), RCE on Windows hosts that use both routers without Cache Components (Critical) |
| 2026-09-22 | 16.3.6, 15.5.26 | RCE in the Node.js `ImageResponse` (Critical, 16.x only; 15.x gets hardening) |
| 2026-09-30 | 16.3.8, 15.5.27 | SSRF in Image Optimization when `remotePatterns` exist (High), cache poisoning and leaks (Medium) |
| 2026-10-14 | 16.4.1, 15.5.28 | RCE in `use cache` functions that return typed arrays (Critical), RCE in Image Optimization with SVG on glibc Linux (Critical; workaround `sharp` 0.35.5 or later), Server Actions DoS (High) |

- The deadlines apply whether or not the code uses the affected feature.

## Sources and raw notes

Pages read on 2026-10-26:

- [Data security](https://nextjs.org/docs/app/guides/data-security): Data Access Layer, DTOs, taint, Server Function risks, allowed origins, encryption key, auditing list.
- [Environment variables](https://nextjs.org/docs/app/guides/environment-variables): `NEXT_PUBLIC_` inlining, runtime reads.
- [Content Security Policy](https://nextjs.org/docs/app/guides/content-security-policy): nonces, static headers, SRI, effect on static rendering.
- [Proxy](https://nextjs.org/docs/app/getting-started/proxy) and the [production checklist](https://nextjs.org/docs/app/guides/production-checklist).
- Security posts: [July 2026](https://nextjs.org/blog/july-2026-security-release), [August 2026](https://nextjs.org/blog/august-2026-security-release), [2026-09-22](https://nextjs.org/blog/nextjs-security-update-september-22-2026), [September 2026](https://nextjs.org/blog/september-2026-security-release), [2026-10-14](https://nextjs.org/blog/nextjs-security-update-october-14-2026).
- [Image `remotePatterns`](https://nextjs.org/docs/app/api-reference/components/image): wildcard behaviour and the warning about omitted fields.
- npm weekly downloads on 2026-10-26 (`api.npmjs.org`): `dompurify` 45.3 million, `isomorphic-dompurify` 3.6 million, `sanitize-html` 8.0 million.
