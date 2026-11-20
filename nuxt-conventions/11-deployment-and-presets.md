# Nuxt Deployment and Presets

## Summary

Build once with `nuxt build` and run `.output/server/index.mjs` with the `node-server` preset, behind nginx, in a container that runs as a non-root user. The `.output` folder is self-contained, so the image needs no `node_modules`. Configure the process with environment variables at run time, add a `/health` route, and let nginx terminate TLS, set the security headers and compress. Choose a static, serverless or edge preset only for a reason.

## Rules

### Choosing a preset

- Use the `node-server` preset, which is Nuxt's default when you run `nuxt build` on a machine that is not a known hosting platform. It writes a Node.js server in `.output/server/` and the browser files in `.output/public/`, and it matches the [infrastructure notes](../infra-conventions/01-principles-and-sources.md): one container, behind nginx, on your own server.
- Use a static build (`nuxt generate`) only when every page can be built ahead of time and no server route is needed ([static sites](#static-sites)).
- Use a serverless or edge preset (`NITRO_PRESET=vercel`, `cloudflare-pages`, and so on) only when the project is hosted there, and write down why. Such a preset changes what `server/` may use (file system, long connections, Node.js APIs), so test it on the target.
- Set the preset with the `NITRO_PRESET` environment variable or `nitro.preset` in `nuxt.config.ts`, and keep it the same for local builds and CI.
- Keep `compatibilityDate` in `nuxt.config.ts`, as the template writes it. It pins preset behaviour, and a bump is a separate change ([setup](02-project-setup-and-tooling.md#creating-a-project)).

### Building and running with the node-server preset

- `npm run build` runs `nuxt build` and writes `.output/`. In the sample project it was about 4 MB. Deploy `.output/` and nothing else. `.output/server/package.json` lists the packages the server needs, and `.output/server/node_modules/` already holds them, so the sample ran from a copy of `.output/` in an empty folder, with no `npm install`. Start it with `node .output/server/index.mjs`.
- Production does not read `.env`. Give the process its variables in its environment: the container's, or the service manager's. Use `node --env-file=.env .output/server/index.mjs` only for a simple local run ([secrets and configuration](../infra-conventions/08-secrets-and-configuration.md)).
- The server's own variables are `NITRO_PORT` (or `PORT`, default 3000) and `NITRO_HOST` (or `HOST`, default `0.0.0.0`). Set `NITRO_HOST=127.0.0.1` when nginx runs on the same host, and `0.0.0.0` inside a container. The sample listened on `NITRO_PORT=3999` and `NITRO_HOST=127.0.0.1`.
- Application settings come from `NUXT_` variables, as the [state note](07-state-and-configuration.md#runtime-configuration) says, and `NUXT_APP_SECRET` is set when the app uses sessions. Build once and promote the same image through the environments: no value that differs between environments may be baked in at build time, so keep it in `runtimeConfig` and not in `app.config.ts`.
- Add `GET /health` in `server/routes/health.get.ts` that answers `{ "status": "ok" }` and touches no database. Use it for the container health check and for nginx.
- Leave compression, TLS and the security headers to nginx. Nitro serves `/_nuxt/` files with `cache-control: public, max-age=31536000, immutable`, because their names are hashed, and the sample showed that header. HTML is short-lived or not cached.
- One process per container. Do not use PM2 or Node's cluster mode inside a container; run more containers. Run more than one instance only when the app keeps no per-process state: no module-level state, sessions in sealed cookies (as `useSession` does) or a shared store, and `NUXT_APP_SECRET` identical on every instance ([state](07-state-and-configuration.md#state)).
- Pin the Node.js major in `engines`, `.nvmrc` and the image, and keep it on an active LTS line that `nuxt` 4.6.4's `engines` accepts.

```dockerfile
# syntax=docker/dockerfile:1
# Pin the Node.js major of .nvmrc, and refresh the patch version on a schedule.
ARG NODE_VERSION=24-slim

FROM node:${NODE_VERSION} AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:${NODE_VERSION} AS runner
WORKDIR /app
ENV NODE_ENV=production NITRO_PORT=3000 NITRO_HOST=0.0.0.0
COPY --from=builder --chown=node:node /app/.output ./.output
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/health').then((r) => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]
CMD ["node", ".output/server/index.mjs"]
```

- This Dockerfile was written from the rules of the [infrastructure notes](../infra-conventions/04-docker-images-and-dockerfiles.md) and not built, because no Docker daemon was running when the notes were written. The part that matters, that `.output/` runs alone, was checked outside Docker. Follow the Dockerfile rules of those notes: a pinned image with a digest, a fixed numeric user ID, a read-only root file system with a `tmpfs` for writes, labels, and a `.dockerignore` with `.git`, `node_modules`, `.nuxt`, `.output` and `.env*`.
- The build needs no secrets. A value that the build reads (a public site name) comes from a build argument, and a secret never goes into the image ([secrets](../infra-conventions/08-secrets-and-configuration.md)).

### nginx

- Put nginx in front of the Node.js process, as the [infrastructure notes](../infra-conventions/06-nginx-reverse-proxy.md) say: nginx terminates TLS, applies the security headers, limits request rates and sizes, compresses, and proxies to `NITRO_HOST:NITRO_PORT`. Use the proxy settings of that note (HTTP/1.1, a keep-alive upstream, `Host`, `X-Forwarded-For` and `X-Forwarded-Proto`).
- Set `client_max_body_size` to the largest body that the API accepts, and validate the size again in the schema ([server](06-server-routes-and-validation.md#validation)).
- Forward `Host` unchanged, so that `useRequestURL()` builds the public origin. The Nuxt documentation says to trust `X-Forwarded-Host` and `X-Forwarded-Proto` (`getRequestURL(event, { xForwardedHost: true, xForwardedProto: true })`) and `X-Forwarded-For` (`getRequestIP(event, { xForwardedFor: true })`) only behind a proxy that you control and that overwrites them. A client can send them otherwise. Nuxt trusts none of them by default.
- Serve `/_nuxt/` with a long `Cache-Control` and `immutable`, because the names are hashed, and keep HTML short-lived. Nitro already sets the first header, and nginx may serve the files itself from `.output/public/` for speed.
- Stream-friendly routes (server-sent events) need `proxy_buffering off` for that location.
- Test the whole path after a deploy: a page, an API `POST` through the real origin, the `/health` route, a 404 page, and a sign-in that sets a cookie. A `Secure` cookie needs HTTPS end to end at the browser, and the sample's session cookie had `Secure`.

### Shutdown and logs

- Nitro stops on `SIGTERM`. The sample's server exited when it received `SIGTERM`. Give the container a stop grace period for requests in progress, run the process as PID 1 only with an init (`init: true` in Compose), so that signals reach Node.js ([Compose and the runtime](../infra-conventions/05-compose-and-container-runtime.md)). Close a connection pool in a Nitro plugin's `close` hook.
- Log to standard output, one line per event, and let the container runtime collect it ([logging and alerting](../infra-conventions/11-logging-monitoring-and-alerting.md)). Do not log request bodies, cookies or credentials.

### Static sites

- `nuxt generate` (or `nuxt build --prerender`) prerenders the routes that it can find by crawling links, and writes `.output/public/`. Every route that is not linked, or that depends on data, must be listed in `nitro.prerender.routes`. A static site has no `server/` routes at run time, no sessions and no `swr`; call a separate API.
- A single-page section (`ssr: false`) of a static site needs a fallback file, so that the host serves the app shell for an unknown path. Nuxt writes `200.html` and `404.html` for this. Configure the host to serve `404.html` with a 404 status and `200.html` for client-routed paths.
- Do not prerender pages whose data changes between deploys ([rendering](09-rendering-seo-and-performance.md#rendering-modes)).
- Deploy a static site to an object store or a static host behind a CDN, as the infrastructure notes describe, with a long cache lifetime on `/_nuxt/` and a short one on HTML.

### Releases

- Build once in CI, tag the image with the commit SHA, run the tests against that build, and promote the same image from staging to production ([CI/CD](../infra-conventions/10-ci-cd-and-deployment.md)).
- A deployment replaces the hashed files in `/_nuxt/`. A browser with an old page loaded may request a file that no longer exists. Nuxt reloads the page once when a lazy chunk fails to load ([errors](08-errors-and-security.md#errors)). Keep the previous build's files available for a few minutes behind a load balancer, or serve `/_nuxt/` from a store that keeps old versions.
- Roll back by redeploying the previous image. Keep `NUXT_APP_SECRET` the same, so that sessions survive.

## Sources and raw notes

Pages read on 2026-11-20:

- [Deployment](https://nuxt.com/docs/getting-started/deployment): the Node.js server (`NODE_ENV=production node .output/server/index.mjs`), entry point, serving the same build at several paths, PM2 and cluster mode, static hosting and fallback pages, hosting providers, presets (`NITRO_PRESET`), CDN proxy.
- [`.output` directory](https://nuxt.com/docs/directory-structure/output) and [`nuxt build`](https://nuxt.com/docs/api/commands/build).
- [Prerendering](https://nuxt.com/docs/getting-started/prerendering): crawl-based prerendering, `nitro.prerender.routes`, payload extraction.
- [Server imports](https://nuxt.com/docs/guide/going-further/server-imports): the forwarded-header options of `getRequestURL`, `getRequestIP`.
- [Infrastructure notes](../infra-conventions/01-principles-and-sources.md) on Docker, Compose, nginx, secrets, CI/CD and logging, and the [SvelteKit deployment note](../sveltekit-conventions/10-deployment-and-adapters.md), whose Dockerfile this one follows.
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes), with Node.js 24 on macOS:
  - `nuxt build` printed "Building Nuxt Nitro server (preset: node-server" and wrote `.output/` (4.2 MB) with `server/index.mjs`, `server/node_modules/` and `public/`.
  - A copy of `.output/` in an empty folder served `/` (200), `/health` (`{"status":"ok"}`) and `/_nuxt/<file>.js` with `cache-control: public, max-age=31536000, immutable`, and exited when it received `SIGTERM`. It printed `Listening on http://127.0.0.1:3998`.
  - `NITRO_PORT` and `NITRO_HOST` set the address. `NUXT_PUBLIC_SITE_NAME` and `NUXT_APP_SECRET` were read at start-up with no rebuild.
  - The Dockerfile and the in-flight shutdown were not run: the Docker daemon was down, and no request was in progress when the signal arrived.
