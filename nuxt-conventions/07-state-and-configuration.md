# Nuxt State and Configuration

## Summary

State that more than one component shares goes in `useState()` or a Pinia store, never in a module-level `ref()`, because the server handles many users with one module. Configuration that differs between environments goes in `runtimeConfig`, set with `NUXT_` environment variables at run time. `app.config.ts` holds public tokens that are not secret and not environment-specific.

## Rules

### State

- Keep state in the component that owns it, as the [Vue notes](../vue-conventions/08-state-management-and-provide-inject.md#where-state-lives) say. Share it only when two distant components need it.
- Never write `export const state = ref(...)` at the top level of a module. On the server, that module is loaded once and shared by every request, so one user's state leaks into another's and the memory grows. Nuxt's documentation names this explicitly. Use `useState` inside a function:

```ts
// app/composables/use-theme.ts
export function useTheme() {
  const theme = useState<"light" | "dark">("theme", () => "light");
  function toggle() {
    theme.value = theme.value === "light" ? "dark" : "light";
  }
  return { theme: readonly(theme), toggle };
}
```

- `useState(key, init)` is an SSR-friendly `ref`: the server creates it, Nuxt puts the value in the payload, and the browser reuses it without running `init` again. Give each state a unique key and write the type argument. The `init` function runs only if the state has no value.
- Wrap `useState` in a composable named `useX()`, so that the key lives in one place. Return `readonly()` state and functions for the changes, as the Vue notes say about composables.
- Put only serialisable values in `useState` and in a store: strings, numbers, booleans, arrays, plain objects, ISO date strings. A function, a class instance, a `Map` or a `Set` does not survive the trip from server to browser.
- Use `useCookie("name")` for a small value that must survive a reload and be readable on the server, such as a theme choice or a locale. Give it a `maxAge`, `sameSite: "lax"` and, for anything sensitive, set the cookie from the server with `HttpOnly` and read it only there ([errors and security](08-errors-and-security.md#cookies)). Do not use `localStorage` for state that the server render needs, because the server cannot read it.
- Use Pinia (`@pinia/nuxt`) when the state is large, has many actions, or needs devtools and testing in isolation. Write a setup store, as the [Vue notes](../vue-conventions/08-state-management-and-provide-inject.md#pinia) say, in `app/stores/x-store.ts`. The module auto-imports `defineStore`, `storeToRefs` and the stores of `app/stores/`, so the file needs no import and the component calls `useLoanStore()` directly. Add the module only when a store is needed, and say why in the pull request.
- Do not copy server data into a store only to read it elsewhere. `useFetch` and `useAsyncData` share data by key, and `useNuxtData("key")` reads it ([data fetching](05-data-fetching.md#keys-and-reactive-sources)).
- Do not call a Pinia action inside `useAsyncData`, as the Nuxt documentation warns. Use `callOnce(() => store.load())` for a side effect that must run once per render.
- Keep the URL as state for anything the user may share: filters, pages, tabs ([routing](04-pages-routing-and-navigation.md#pages)).
- Reset state on sign-out with `clearNuxtState("key")` or a store's own reset action, and navigate away.

### Runtime configuration

- Define every environment-specific value in `runtimeConfig` in `nuxt.config.ts`, with a default. A key outside `public` is available only on the server. A key in `public` is sent to the browser in the page payload, so it must be harmless. Read it with `useRuntimeConfig()`; in the app you get the public part, in `server/` you get both and pass the event: `useRuntimeConfig(event)`.

```ts
runtimeConfig: {
  loansApiUrl: "",          // server only
  public: { siteName: "Loans" },  // server and browser
},
```

- Override a value in production with an environment variable named `NUXT_` plus the key in upper snake case: `loansApiUrl` is `NUXT_LOANS_API_URL`, and `public.siteName` is `NUXT_PUBLIC_SITE_NAME`. The built server read `NUXT_PUBLIC_SITE_NAME=Pinjaman` at start-up, with no rebuild, and rendered it. A key must exist in `runtimeConfig` with a default to be overridable; an environment variable for an undefined key is ignored.
- Nuxt converts the value to the type of the default: a numeric default (`pageSize: 20`) with `NUXT_PAGE_SIZE=50` gave the number `50`, and a boolean default with `NUXT_FEATURE_ON=true` gave `true`. Give every key a default of the right type, so that the type holds. The conversion is documented as part of Nuxt 5's migration notes, so check it on your version.
- Never put a secret in `public`, in `app.config.ts`, in a component or in a committed file. Secrets go in private `runtimeConfig` keys, and the value comes from the environment. Commit a `.env.example` with the keys and no values, as the [infrastructure notes](../infra-conventions/08-secrets-and-configuration.md) say.
- A `.env` file is read by the Nuxt CLI during `nuxt dev`, `nuxt build` and `nuxt generate` only. The production server does not read it. Set the variables in the process environment, through your service manager or container runtime. Do not copy a `.env` into the image.
- Do not read `process.env` in application code, as the TypeScript notes say. Read `useRuntimeConfig()`. The one module that reads the environment is `nuxt.config.ts` and Nuxt itself.
- Validate configuration that must be present: a handler or a plugin that needs `loansApiUrl` throws a clear error when it is empty. A Zod schema over `useRuntimeConfig(event)` in one server utility does it once.
- `NUXT_APP_SECRET` is the application's root secret. Nuxt derives session and signing keys from it. Set a value of at least 32 random bytes (`openssl rand -base64 32`) per environment, keep it stable across deployments and servers, and know that changing it invalidates every session. Do not use the `app` prefix for your own keys: `runtimeConfig.app` and `appSecret` are reserved.
- Do not put a function, a `Map` or a class instance in `runtimeConfig`. It is serialised, and they do not survive.

### `app.config.ts`

- Use `app/app.config.ts` for configuration that is public, not secret, and not different between environments, and that components read reactively: UI tokens such as a density or a default page title. It is a default export through `defineAppConfig()`. Read it with `useAppConfig()`.
- Use `runtimeConfig` for anything that differs by environment or must be a secret. A value in `app.config.ts` is bundled at build time, so an environment variable does not change it.
- Type your own keys by what you write in `defineAppConfig()`, and do not cast the values. The sample's `ui: { density: "comfortable" }` was typed as the literal, and an `as` cast was a lint error.

### Environment and the server

- The server learns its address from `NITRO_HOST` and `NITRO_PORT` (or `HOST` and `PORT`), the Nitro variables. The sample server started on `NITRO_PORT=3999` and `NITRO_HOST=127.0.0.1`. See the [deployment note](11-deployment-and-presets.md#building-and-running-with-the-node-server-preset).
- Use `useRequestURL()` and `getRequestURL(event)` for the origin of a request. Behind a proxy, trust the forwarded headers only from a proxy that you control and that overwrites them ([deployment](11-deployment-and-presets.md#nginx)).

## Sources and raw notes

Pages read on 2026-11-20:

- [State management](https://nuxt.com/docs/getting-started/state-management): "Never define `const state = ref()` outside of `<script setup>` or `setup()`", `useState`, initialising, shared state with a composable, using Pinia, and the advanced usage.
- [`useState`](https://nuxt.com/docs/api/composables/use-state) and [`useCookie`](https://nuxt.com/docs/api/composables/use-cookie).
- [Runtime config](https://nuxt.com/docs/guide/going-further/runtime-config): public and private keys, `NUXT_` variables, the type of the default, serialisation, the application secret and `NUXT_APP_SECRET`.
- [`.env`](https://nuxt.com/docs/directory-structure/env): `.env` is loaded at dev, build and generate time only; use runtime config in application code.
- [`app.config.ts`](https://nuxt.com/docs/directory-structure/app/app-config): reactive public configuration, `defineAppConfig`, `useAppConfig`.
- [Pinia setup stores](../vue-conventions/08-state-management-and-provide-inject.md#pinia) in the Vue notes, and the [infrastructure secrets note](../infra-conventions/08-secrets-and-configuration.md).
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): a `useTheme` composable over `useState`, a Pinia setup store in `app/stores/` used with no import (a unit test in the `nuxt` project created and read it), `defineAppConfig`, and a layout that reads `useRuntimeConfig().public.siteName`. Against the built server, `NUXT_PUBLIC_SITE_NAME=Pinjaman` changed the rendered name and the payload with no rebuild. In a scratch change, `pageSize: 20` and `featureOn: false` read back as the number `50` and the boolean `true` from `NUXT_PAGE_SIZE=50` and `NUXT_FEATURE_ON=true`.
