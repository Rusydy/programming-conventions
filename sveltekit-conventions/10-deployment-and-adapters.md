# SvelteKit Deployment and Adapters

## Summary

Deploy a SvelteKit app with `@sveltejs/adapter-node`, in a container, behind nginx, as the infrastructure notes describe. Set the public origin explicitly, give the build and the process the environment variables that `src/env.ts` validates, and shut down gracefully. Use `adapter-static` only for a site that is prerendered completely. The `adapter-auto` package guesses a platform and cannot guess a server of your own.

## Rules

### Choosing an adapter

- An adapter turns the built app into the output for one target, and it runs during `vite build`. Pass it to `sveltekit({ adapter })` in `vite.config.ts` ([setup](02-project-setup-and-tooling.md#sveltekit-configuration)).
- Use `@sveltejs/adapter-node` for a server that you run yourself. It is the default of this set ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Use `@sveltejs/adapter-static` for a site in which every page is prerendered, and no form action, endpoint or request-time feature is needed.
- Use `adapter-cloudflare`, `adapter-netlify` or `adapter-vercel` only when the project has chosen that platform. They tie the app to it, and each has its own `platform` object and limits. The Vercel `edge` runtime no longer exists in SvelteKit 3.
- Do not leave `adapter-auto` in a project that you deploy yourself. It prints `Could not detect a supported production environment` at the end of a build in the sample application, which is not a target you chose. The template ships with it so that a new project builds, so replace it in the first commit.
- Install an adapter with `npx sv add sveltekit-adapter` or `npm install -D @sveltejs/adapter-node`. Install the newest release, because every first-party adapter needs SvelteKit 3.
- Read the adapter's own page before you rely on a detail. In SvelteKit 3, `adapter-node` bundles with rolldown, serves static assets from a build-time list with content-hash `ETag`s, and answers 405 to a non-`GET`, non-`HEAD` request for a static asset.

### Building and running with `adapter-node`

- `npm run build` writes `build/`. Deploy `build/`, `package.json` and the production dependencies (`npm ci --omit dev`). Start the server with `node build`. Packages in `devDependencies` are bundled into `build/`, and packages in `dependencies` stay external, so list a runtime-only package under `dependencies`. In the sample application, `build/` was about 2 MB.
- The adapter options are `out` (default `build`), `precompress` (default `true`, which writes Brotli and gzip files for the assets) and `envPrefix` (default none). Keep the defaults, and let nginx serve the precompressed files if it can ([deployment of the infrastructure notes](../infra-conventions/10-ci-cd-and-deployment.md)).
- Production does not load `.env` files. Give the process its variables in its environment: `node --env-file=.env build` for a simple run, or the variables of the container or the service manager ([secrets and configuration](../infra-conventions/08-secrets-and-configuration.md)).
- The variables of the server itself are `PORT` (default 3000), `HOST` (default `0.0.0.0`), `ORIGIN`, `PROTOCOL_HEADER`, `HOST_HEADER`, `ADDRESS_HEADER`, `XFF_DEPTH`, `BODY_SIZE_LIMIT` (default 512 kB), `SHUTDOWN_TIMEOUT` (default 30 seconds) and the timeout variables `IDLE_TIMEOUT`, `KEEP_ALIVE_TIMEOUT` and `HEADERS_TIMEOUT`. Set `HOST=127.0.0.1` when nginx runs on the same host and `HOST=0.0.0.0` inside a container.
- Both the build and the process validate `src/env.ts`. A missing variable stops `vite build` and `node build` with `SvelteKit error: env_invalid` and the name of the variable, as the sample application showed. Give the build the values of every variable that is not optional while building ([environment variables](07-hooks-errors-and-security.md#environment-variables)).
- Add a `GET /health` endpoint in `src/routes/health/+server.ts` that answers `Response.json({ status: "ok" })` and touches no database. Use it for the container health check and the proxy.

```dockerfile
# Pin the Node.js LTS major of .nvmrc, and refresh the patch version on a schedule.
ARG NODE_VERSION=24-slim

FROM node:${NODE_VERSION} AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# The build validates src/env.ts, so it needs values for every required variable.
ARG DATABASE_URL=postgres://build.invalid/build
ARG PUBLIC_APP_NAME=App
RUN DATABASE_URL="$DATABASE_URL" PUBLIC_APP_NAME="$PUBLIC_APP_NAME" npm run build \
    && npm prune --omit=dev

FROM node:${NODE_VERSION} AS runner
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOST=0.0.0.0
COPY --from=builder --chown=node:node /app/build ./build
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package.json ./
USER node
EXPOSE 3000
CMD ["node", "build"]
```

- Follow the Dockerfile rules of the [infrastructure notes](../infra-conventions/04-docker-images-and-dockerfiles.md): the slim Debian image, a pinned major, a non-root user and a `.dockerignore` with `.git`, `node_modules`, `.svelte-kit`, `build` and `.env*`.
- Build the image once and promote it. A variable with `static: true` is inlined into the bundle at build time, so do not make a value that differs between environments static ([environment variables](07-hooks-errors-and-security.md#environment-variables)).
- Run more than one instance only when the app keeps no per-process state ([state on the server](06-state-and-navigation.md#state-on-the-server)). Sessions in a database and a shared store make that safe.

### Running behind nginx

- Put nginx in front of the Node.js process, as the [infrastructure notes](../infra-conventions/06-nginx-reverse-proxy.md) say: nginx terminates TLS, applies the security headers, limits and compresses, and proxies to `HOST:PORT`. Use the proxy settings of that note (`proxy_http_version 1.1`, a keep-alive upstream and `Host`, `X-Forwarded-Proto` and `X-Forwarded-For` overwritten at the edge).
- Give the server its public origin with `ORIGIN=https://app.example.com`. It is the simplest setting and the safest, because the server then does not trust a header for it. With the wrong origin a form `POST` fails with `Cross-site POST form submissions are forbidden`, which is the CSRF check doing its job ([CSRF](07-hooks-errors-and-security.md#csrf)).
- When the origin has to come from the request, set `PROTOCOL_HEADER=x-forwarded-proto` and `HOST_HEADER=x-forwarded-host`, and only behind a proxy that you control and that overwrites both headers. A client can send them otherwise.
- To read the client address in `getClientAddress()`, set `ADDRESS_HEADER=x-forwarded-for` and `XFF_DEPTH` to the number of proxies you trust. SvelteKit reads the list from the right, so a client cannot spoof it.
- Leave compression to nginx. A custom server that needs it uses `@polka/compression`, because the `compression` package does not support streaming.
- Serve `/_app/immutable/` with a long `Cache-Control` and `immutable` at nginx, because the file names are hashed, and keep HTML short-lived. Streaming responses need `proxy_buffering off` for the routes that stream, or nginx holds them until they finish.
- Test the whole path after a deploy: a page, a form `POST` through the real origin, the `/health` endpoint, and a streamed page.

### Shutdown

- On `SIGTERM` or `SIGINT`, `adapter-node` stops accepting requests, lets the running ones finish, and closes the remaining connections after `SHUTDOWN_TIMEOUT` seconds. Give the container a `stop_grace_period` longer than that.
- Close a database pool or any other resource in a listener for the `sveltekit:shutdown` event, which fires after the connections close.
- Run the process as PID 1 only with an init, or let Docker's `init: true` do it, so signals reach Node.js ([Compose and the runtime](../infra-conventions/05-compose-and-container-runtime.md)).

### Static sites

- With `adapter-static`, write `export const prerender = true;` in the root `+layout.ts`, so that every page is prerendered. Leave `strict` at `true`: the build then fails when a page is not prerendered and no `fallback` is set.
- Do not set a `fallback` page unless you accept its cost. It makes unprerendered URLs a single-page app, and the documentation warns about the performance and SEO effect. Name it `200.html`, not `index.html`.
- Do not set `ssr = false`. Prerendering would then save an empty shell.
- Set `trailingSlash: "always"` when the host does not serve `/a.html` for `/a`. For GitHub Pages, set `paths.base` to the repository name, add a `404.html`, and add a `static/.nojekyll` file when you do not deploy with Actions.
- Set `precompress: true` if the host serves the `.br` and `.gz` files.

### Service workers and extras

- Add `src/service-worker/` only for a real offline need. It registers as a module in SvelteKit 3, and it takes its assets from `$app/manifest` and its version from `$app/env`. Do not cache a live or streaming response.
- Keep `version.pollInterval` at its default of one hour, so that `updated.current` tells a long-lived tab that a new version exists.

## Sources and raw notes

Pages read on 2026-11-18:

- [Adapters](https://svelte.dev/docs/kit/adapters): the first-party adapters, `sv add sveltekit-adapter`, configuration in `vite.config`. [`adapter-node`](https://svelte.dev/docs/kit/adapter-node): the options, deploying `build`, `node --env-file`, every environment variable above, graceful shutdown and the `sveltekit:shutdown` event, the proxy notes and the `@polka/compression` advice. [`adapter-static`](https://svelte.dev/docs/kit/adapter-static): the options, `prerender` in the root layout, the fallback warning, GitHub Pages notes, the pitfalls.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): the changes to `adapter-node` and `adapter-vercel`, the service worker modules, `version.pollInterval`. [Configuration](https://svelte.dev/docs/kit/configuration): `version.pollInterval`, `paths.origin`.
- [Environment variables](https://svelte.dev/docs/kit/environment-variables): `static`, validation at start and build.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes) with `@sveltejs/adapter-node` 6.0.4 and Node.js 24.22.1:
  - `npm run build` passed, `build/` had `index.js`, `handler.js`, `client`, `server` and `adapter-node.js` and was 2.1 MB, and `node --env-file=.env build` served `/api/loans` as JSON.
  - `vite build` without `.env` stopped with `SvelteKit error: env_invalid`, naming `DATABASE_URL`, and `node build` without it stopped the same way.
  - With `ORIGIN=https://app.example.com`, a form `POST` with that `Origin` header got 200 and one with `Origin: http://localhost:4560` got 403.
  - With `PROTOCOL_HEADER=x-forwarded-proto` and `HOST_HEADER=x-forwarded-host`, a `POST` with the matching `Origin` and forwarded headers got 200.
  - With `adapter-auto`, `vite build` ended with `Could not detect a supported production environment`.
- Docker was not installed on the machine, so the Dockerfile above was not built. It follows the structure of the [Next.js deployment note](../nextjs-conventions/12-deployment-and-self-hosting.md#docker) and the `adapter-node` page. The nginx, `/health`, `stop_grace_period`, `proxy_buffering`, `immutable` cache and `init: true` advice come from the documentation and the infrastructure notes, and were not run.
