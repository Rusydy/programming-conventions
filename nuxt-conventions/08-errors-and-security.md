# Nuxt Errors and Security

## Summary

Nuxt shows a full-screen error page for a fatal error, and you design that page in `app/error.vue`. Fail soft where you can with `<NuxtErrorBoundary>`, log every unhandled error once, and never show the message of an unexpected error. For security, keep every real check on the server: validate input, check the session in each handler, set cookies with `HttpOnly`, and keep secrets out of the public config.

## Rules

### Errors

- Throw `createError({ status, statusText, fatal })` for an error that the user or the client should see. In a page or a middleware, `fatal: true` renders the error page at once, and during server rendering the response gets that status, so a missing loan is a real 404, not a 200 with an empty page ([routing](04-pages-routing-and-navigation.md#pages)). Name the status with `HTTP_STATUS`, as the TypeScript notes say.
- Handle an expected failure where it happens, as the [Vue notes](../vue-conventions/10-errors-and-async.md) say, and show a message that you wrote. Do not render `error.message` or `error.data` from a response to the user.
- Write `app/error.vue` as the error page. It receives an `error` prop of type `NuxtError`, shows a heading by status (`error.status === 404`), and offers a way out with `clearError({ redirect: "/" })`. Keep it free of data fetching, and give it a `<main>` and a button, because the layout does not apply to it:

```vue
<script setup lang="ts">
import type { NuxtError } from "#app";

const { error } = defineProps<{ error: NuxtError }>();

function handleClear() {
  void clearError({ redirect: "/" });
}
</script>

<template>
  <div>
    <main tabindex="-1">
      <h1>{{ error.status === 404 ? "Page not found" : "Something went wrong" }}</h1>
      <button type="button" @click="handleClear">Back to loans</button>
    </main>
  </div>
</template>
```

- Wrap a region that can fail without taking the page down in `<NuxtErrorBoundary>`. Its `#error` slot receives `error` and `clearError`, and it catches errors from the rendering and the setup of its children. Put one around the layout's `<slot />`, and around a widget that loads its own data. Show a fixed message and a retry button that calls `clearError()`:

```vue
<NuxtErrorBoundary>
  <slot />
  <template #error="{ clearError }">
    <p role="alert">Something went wrong in this part of the page.</p>
    <button type="button" @click="clearError()">Try again</button>
  </template>
</NuxtErrorBoundary>
```

- Use `showError(error)` to open the error page from code, and `useError()` to read the current error. Use `clearError()` to leave it.
- Report unhandled errors from a plugin, once: `nuxtApp.hook("vue:error", (error, instance, info) => ...)` receives every error that reaches the top of the Vue app, and `app:error` receives start-up errors. Log the error with its `cause` chain and send it to your error-reporting service there. Do not also set `vueApp.config.errorHandler` for the same job, because the Nuxt documentation notes that it receives errors even when they were handled.
- Server errors in `server/` are logged by Nitro and answered as JSON. A fatal error during server rendering is rendered through `app/error.vue`. A client that sends `Accept: application/json` gets the JSON body, and a browser gets the page ([server](06-server-routes-and-validation.md#errors)).
- Nuxt reloads the page once when a lazy JavaScript chunk fails to load, which happens after a deployment replaces the hashed files. Leave `experimental.emitRouteChunkError` at its default. A project that serves old and new builds at once, behind a load balancer, keeps old files available for a while.
- Do not swallow an error in a plugin. A plugin that throws during start-up reaches `app:error`, and the page does not render. Handle what can fail, and let the rest fail loudly.

### Sessions and authentication

- Keep the real check in the server. A route middleware and a hidden button are for the user's convenience, because the user controls the browser. Every handler that reads or changes private data checks who is asking.
- Use `useSession(event)` from `nuxt/server` for a signed-in user. It seals the session data into a cookie with a key that comes from `NUXT_APP_SECRET`, so the cookie carries the data and the server keeps no store. The sample's cookie was `nuxt-session=...; Path=/; HttpOnly; Secure; SameSite=Lax`, and a second request with the cookie read the updated data (`visits` went from 1 to 2). Put no more than an id and a role in it, because the cookie is sent on every request and has a size limit.
- Write one helper that every private handler calls, and let it throw 401:

```ts
// server/utils/require-session.ts
export async function requireUserId(event: RequestEvent): Promise<string> {
  const session = await useSession<{ userId?: string }>(event);
  if (!session.data.userId) {
    throw createError({
      status: HTTP_STATUS.unauthorized,
      statusText: "Sign in first",
    });
  }
  return session.data.userId;
}
```

- Check authorisation, not only authentication: that this user may see this loan. Return 404 rather than 403 for a record that the user may not know exists, if its existence is private.
- Verify a password with a slow, salted hash (Argon2id or scrypt through the platform or a vetted library). Do not write your own, and do not log a password. For OAuth or magic links, use a vetted module (the Nuxt recipe uses `nuxt-auth-utils`), and read its documentation, because it owns that part ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Rotate `NUXT_APP_SECRET` only on purpose. Changing it signs every user out.
- Rate-limit the sign-in route and the other costly routes at nginx or with fail2ban, as the [infrastructure notes](../infra-conventions/07-abuse-control-and-edge-protection.md) say, and not in the handler.

### Cookies

- Set a cookie that carries identity or a secret from the server, with `setCookie(event, name, value, { httpOnly: true, secure: true, sameSite: "lax", path: "/", maxAge })`. A script in the page cannot read an `HttpOnly` cookie. Never keep a token in `localStorage` or in a cookie that `useCookie()` writes from the browser.
- `useCookie()` is for a preference that is not a secret (theme, locale). Set `sameSite: "lax"`, a `maxAge`, and `secure: true` in production. Values are serialised to JSON.
- Keep cookies small, and name them for their purpose. A cookie without `SameSite` follows the browser default, so write the attribute.

### Browser-side protections

- Rely on `SameSite=Lax` cookies and JSON bodies (`content-type: application/json`) as the baseline against cross-site requests. Check the `Origin` header on a state-changing request that accepts form encoding. Do not enable cross-origin access (`routeRules: { "/api/**": { cors: true } }`) unless another origin must call the API, and then list the origin.
- Send the security headers from nginx: `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy` and `Permissions-Policy`, as the [infrastructure notes](../infra-conventions/06-nginx-reverse-proxy.md) say. Nitro already sets `x-content-type-options: nosniff` on responses. A route rule with `headers` can add one for a path when nginx is not in front. The `nuxt-security` module needs Node.js 24 or later and adds a build dependency; do not add it unless a project has no reverse proxy.
- Write a Content-Security-Policy without `unsafe-eval`. Nuxt output uses inline scripts for the payload and the import map, so a strict policy needs a nonce or hashes. Test it against the built app, not the dev server.
- Never use `v-html`, as the [Vue notes](../vue-conventions/11-performance-and-security.md#security) say. `vue/no-v-html` is an error.
- Open a user-provided URL only after you check its scheme (`http`, `https` or a relative path). `navigateTo(url, { external: true })` sends the browser away, so do not pass it an unchecked URL from the query string: that is an open redirect.

### Secrets and public data

- Everything in `runtimeConfig.public`, in `app.config.ts`, in the page payload and in `useState` reaches every visitor. Keep keys, tokens and internal URLs in private `runtimeConfig`, and use them only in `server/` ([state and configuration](07-state-and-configuration.md#runtime-configuration)).
- Return only the fields a page shows. A handler that returns a whole record sends every column to the browser in the payload. Shape the response in the handler ([data fetching](05-data-fetching.md#payload-and-size)).
- Do not log request bodies, cookies or the `authorization` header, and do not put personal data in a URL.
- Keep dependencies current, audit them in CI with `npm audit`, and add a Nuxt module only after you read what it changes. A module runs at build time with full access to the project.

## Sources and raw notes

Pages read on 2026-11-20:

- [Error handling](https://nuxt.com/docs/getting-started/error-handling): Vue errors and the `vue:error` hook, startup errors and `app:error`, Nitro errors, JS chunk errors and `emitRouteChunkError`, the error page, `<NuxtErrorBoundary>`, `createError`, `showError`, `clearError`.
- [`error.vue`](https://nuxt.com/docs/directory-structure/app/error), [`createError`](https://nuxt.com/docs/api/utils/create-error), [`showError`](https://nuxt.com/docs/api/utils/show-error) and [`clearError`](https://nuxt.com/docs/api/utils/clear-error).
- [Server imports](https://nuxt.com/docs/guide/going-further/server-imports): sessions (`useSession`, `getSession`, `updateSession`, `clearSession`), sealed cookie, `deriveSecret`, client IP and forwarded headers.
- [Runtime config](https://nuxt.com/docs/guide/going-further/runtime-config): the application secret (32 random bytes, stable per environment).
- [Sessions and authentication recipe](https://nuxt.com/docs/guide/recipes/sessions-and-authentication): `nuxt-auth-utils`, a login route, protecting API and app routes.
- [`useCookie`](https://nuxt.com/docs/api/composables/use-cookie).
- [Vue security notes](../vue-conventions/11-performance-and-security.md#security) and the [infrastructure notes on nginx](../infra-conventions/06-nginx-reverse-proxy.md) and [abuse control](../infra-conventions/07-abuse-control-and-edge-protection.md).
- `nuxt-security` 2.7.0 on npm: `engines.node` is `>=24.0.0`.
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): an `error.vue` that takes `NuxtError` and calls `clearError({ redirect })`; a layout with `<NuxtErrorBoundary>` and an `#error` slot; a `requireUserId` helper that throws 401 through `useSession`; a `vue:error` hook in a plugin. Against the built server, `/api/visits` set the cookie `nuxt-session=...; Path=/; HttpOnly; Secure; SameSite=Lax` and returned `visits` 1 and then 2 with the cookie, with `NUXT_APP_SECRET` set. `nuxt typecheck` and typed ESLint passed.
