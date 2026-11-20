# Vue Performance and Security

## Summary

Vue is fast by default, so measure before you optimise. Split code by route, keep props stable, keep large data shallow, and virtualise long lists. For security, let Vue escape everything: never render untrusted HTML, untrusted templates, untrusted URLs or untrusted styles, and keep every real check on the server.

## Rules

### Performance

- Measure first. Use the browser's performance panel and the Vue devtools' performance tab, and compare before and after. Do not add `v-memo`, `v-once` or a shallow ref without a measurement that shows a problem. The TypeScript notes say the same about `useMemo` in React.
- Load code by route. Every route component is a `() => import(...)` ([routing](09-routing-and-data-fetching.md#routes)), and a heavy component that is not a route uses `defineAsyncComponent()` ([errors and async](10-errors-and-async.md#async-in-components)). Check the output of `vite build` for a chunk that is larger than you expect.
- Import the single function you use from a package that ships ES modules, not a whole utility library. Prefer the platform to a package, as the principles say.
- Keep props stable. A child updates only when a prop changes, so pass a computed `active` boolean to each list item instead of the shared `activeId` that every item compares. Then a change of the active item updates two components, not all of them. Do the comparison in the parent.
- Keep a computed value stable: return a primitive, or an object that you keep the same when nothing changed. Vue 3.4 and later stop the update when a computed value is unchanged under `Object.is`.
- Use `shallowRef()` and `shallowReactive()` for large data that you replace whole, such as a table of thousands of rows from the server. Deep reactivity wraps every property in a proxy, which costs time and memory on a large structure. Replace the value to trigger an update: `rows.value = next`. Mutating a nested property does not. `markRaw()` keeps a library's object out of the proxy.
- Virtualise a list that can reach hundreds of rows. Render only the visible rows with a virtual-scrolling library, or paginate. Do not render a list of thousands in full, and do not `v-for` over a large list inside another `v-for`.
- Use `v-once` for a block that never changes, and `v-memo` for list rows that change rarely. Both are escape hatches. Reach for them after you measure a list of hundreds of rows.
- Use `v-show` for something that toggles often, and `v-if` for something that rarely renders ([templates](06-templates-styling-and-accessibility.md#conditionals-and-loops)).
- Avoid unnecessary component layers in large lists. Every component instance costs memory and time. A wrapper component that only forwards props to another component, rendered a hundred times, is worth removing. Do not remove abstractions in a part of the app that renders a few times.
- Do not watch deep structures. `watch(source, cb, { deep: true })` walks every property. Watch a getter for the one value you need, or use a number for the `deep` depth (3.5).
- Debounce an input that triggers a request, and cancel the previous one ([composables](07-composables.md#side-effects-and-cleanup)).
- Set explicit `width` and `height` on images, lazy-load images below the fold with `loading="lazy"`, and serve modern formats. These beat most Vue-level work.
- Use `<KeepAlive>` to keep an expensive view's state across a tab switch, and set `max`. Do not use it to hide a leak.
- For first-load speed on a content site, the choice of architecture matters more than any code in these notes: a client-only app sends an empty page and a script. A site that needs fast first paint or search indexing renders on the server, and that is Nuxt's job.

### Security

- Never use untrusted templates. The Vue documentation calls this rule number one: a template that comes from a user is code that runs in your page. Do not compile a template from a request, a database field or a query string, and do not alias `vue` to the full build to allow it ([setup](02-project-setup-and-tooling.md#vue-and-compiler)).
- Let Vue escape. Interpolation (`{{ }}`) and attribute bindings escape their values. Do not build HTML with string concatenation.
- Do not use `v-html`, `innerHTML` in a render function, or `eval`. `vue/no-v-html` is an error in this set. When you must show user-provided or CMS HTML, sanitise it with DOMPurify on the server or at the boundary, render it in a sandboxed `<iframe>` when you can, and disable the lint rule for that one line with a comment that names the sanitiser. The Vue documentation says user-provided HTML is never 100 percent safe.
- Do not bind a user-provided URL straight into `:href`, `:src` or `router.push`. A `javascript:` URL runs code. Validate that the scheme is `http` or `https` (or a relative path) with `new URL()` and a scheme check, in the function that produces the value. Do the real validation on the server: the Vue documentation says that if you sanitise URLs on the front end, you already have a security problem.
- Do not bind user-provided CSS. A bound style object (`:style="{ color }"`) with a value you control is fine. A string of user CSS can hide, overlay or click-jack the page. Vue refuses `<style>` in templates for this reason.
- Do not render a user-provided `<script>`, an event-handler attribute (`onclick`) or a component name from user data. Do not pass user data to `<component :is>`.
- Open an external link in a new tab with `rel="noopener noreferrer"` and `target="_blank"`. Modern browsers imply `noopener`, and the attribute makes the intent clear.
- Keep tokens out of JavaScript-readable storage when you can. Prefer an `HttpOnly`, `Secure`, `SameSite` cookie that the server sets. If a token must live in the page, keep it in memory, not in `localStorage`, which every script in the page can read.
- Do not trust the client. A route guard, a hidden button and a disabled field are for the user's convenience. The server checks authentication, authorisation and input on every request, as the Vue documentation says about backend coordination.
- Do not put secrets in the bundle. Everything that Vite exposes through `import.meta.env.VITE_*` is public. Keep an API key that must stay private on the server.
- Add a Content Security Policy at the server or the reverse proxy, with no `unsafe-inline` for scripts. The production build needs no `unsafe-eval`, because every template is compiled at build time.
- Keep dependencies current and audit them in CI (`npm audit`). Review a package before you add it ([principles](01-principles-and-sources.md#principles)). Report a vulnerability in Vue itself to the Vue team, as its security page describes.
- In an app that renders on the server, never share state between requests, and never pass user data into the HTML without Vue's escaping. The Vue documentation has a section on SSR security.

## Sources and raw notes

Pages read on 2026-11-20:

- [Performance](https://vuejs.org/guide/best-practices/performance.html): profiling options, page-load optimisations (architecture, bundle size, tree-shaking, code splitting), update optimisations (props stability, `v-once`, `v-memo`, computed stability), general optimisations (virtualising large lists, reducing reactivity overhead with shallow refs, avoiding unnecessary component abstractions).
- [Security](https://vuejs.org/guide/best-practices/security.html): rule number one (never use untrusted templates), what Vue escapes, HTML, URL, style and JavaScript injection, best practices, backend coordination, SSR.
- [Production deployment](https://vuejs.org/guide/best-practices/production-deployment.html): the production build, tracking runtime errors.
- [Computed properties](https://vuejs.org/guide/essentials/computed.html): computed stability (3.4).
- [Reactivity APIs: advanced](https://vuejs.org/api/reactivity-advanced.html): `shallowRef`, `shallowReactive`, `markRaw`.
- [Vue style guide](https://vuejs.org/style-guide/rules-essential.html): essential rules.
- No claim here was run in the sample project, except that `vue/no-v-html` reported `v-html` as an error and that the production build runs with no template compiler ([setup note](02-project-setup-and-tooling.md#sources-and-raw-notes)).
