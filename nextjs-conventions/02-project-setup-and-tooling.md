# Next.js Project Setup and Tooling

## Summary

Every Next.js project starts from the `create-next-app` defaults and keeps a small toolchain: strict TypeScript, generated route types, an ESLint flat config, a formatter and `next build`, all run in CI. Configuration stays minimal because the defaults are the convention.

## Rules

### Versions and runtime

- **Next.js:** the latest Active LTS ([version policy](01-principles-and-sources.md#version-policy)).
- **Node.js:** use the major that the official `with-docker` example runs (24 on 2026-10-26). Existing projects on Node.js 22 stay there until it reaches end of life on 2027-04-30. Node.js 20 reached end of life on 2026-04-30, and Next.js 16 needs 20.9 or later. Use the same major in `.nvmrc`, in the `engines` field and in the Docker base image.
- **TypeScript:** 5.1 or later is the Next.js minimum. Run the line that the [TypeScript version policy](../typescript-conventions/01-principles-and-sources.md#version-policy) names (6.0 on 2026-10-26, `~6.0.3`). Do not install `typescript@^7` yet. `next build` can type-check with it through the local `tsc` CLI, but typescript-eslint, and `eslint-config-next` with it, need the JavaScript API that TypeScript 7.0 does not provide ([TypeScript versions](../typescript-conventions/02-project-setup-and-tooling.md#typescript-versions)).
- **React:** keep `react`, `react-dom`, `@types/react` and `@types/react-dom` on one major version (19.x). The App Router runs the React build that ships inside Next.js (React 19.3 in Next.js 16.4), but you still declare React in `package.json` for tooling. The Pages Router uses the version from `package.json`.
- **Package manager:** one per repository, with a committed lock file. CI installs from the lock file (`npm ci`).
- **Ranges:** declare `next`, `react` and `react-dom` with caret ranges (`^16.4.3`, the latest patch on 2026-10-26). The lock file pins the exact version, and `npm update` then takes patch releases. An exact pin in `package.json` blocks that.

### Creating a project

```bash
npx create-next-app@latest my-app --yes
```

`--yes` applies the recommended defaults: TypeScript, ESLint, Tailwind CSS, App Router, Turbopack, Cache Components, the `@/*` import alias, no `src/` folder, no React Compiler and an `AGENTS.md`. Accept them, except Cache Components: answer No in the custom flow, or delete `cacheComponents` and `partialPrefetching` from the generated `next.config.ts` ([caching](05-data-fetching-and-caching.md#cache-components-not-adopted-on-16x)). Change another default only with a reason recorded in the pull request.

### Scripts

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "lint:fix": "eslint --fix",
    "format:check": "prettier --check .",
    "typecheck": "next typegen && tsc --noEmit",
    "ci": "npm run typecheck && npm run lint && npm run format:check && npm run build"
  }
}
```

- Write `next dev`, not a bare `next`.
- Turbopack is the default bundler for `next dev` and `next build` since 16.0. Do not add `--turbopack`. Use `--webpack` only when a plugin fails under Turbopack, and name that plugin in the README.
- `next build` no longer runs the linter since 16.0, so run `lint` in CI.
- `PageProps`, `LayoutProps` and `RouteContext` come from generated files. Run `next typegen` before `tsc`, or a clean checkout cannot find those types.

### TypeScript

- Keep `strict: true`. Keep the entries that `create-next-app` generates in `tsconfig.json`, including `next-env.d.ts` and `.next/types/**/*.ts` in `include`, and the `@/*` alias.
- Add `next-env.d.ts` to `.gitignore` and never edit it. Put custom declarations in a separate `.d.ts` file that `include` lists.
- Never set `typescript.ignoreBuildErrors`.
- Use `next.config.ts` with `import type { NextConfig } from 'next'`.
- Set `typedRoutes: true`. TypeScript then checks literal `href` strings in `<Link>` and in `router.push`, `replace` and `prefetch`. Cast a non-literal string with `as Route`.
- Type route props with the global helpers ([props and params](03-project-layout-and-routing.md#props-and-params)).
- Add the compiler options of the TypeScript conventions to a new project ([tsconfig](../typescript-conventions/03-tsconfig.md#baseline-for-a-nextjs-application)).

### Linting and formatting

- Use an ESLint flat config in `eslint.config.mjs`. Spread `eslint-config-next/core-web-vitals` and `eslint-config-next/typescript`, and keep the default ignores.

```js
// eslint.config.mjs
import { defineConfig, globalIgnores } from 'eslint/config'
import nextVitals from 'eslint-config-next/core-web-vitals'
import nextTs from 'eslint-config-next/typescript'
import prettier from 'eslint-config-prettier/flat'

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  prettier,
  globalIgnores(['.next/**', 'out/**', 'build/**', 'next-env.d.ts']),
])
```

- `eslint-config-next` bundles the Next.js, React and React Hooks rules, `typescript-eslint` and `eslint-plugin-jsx-a11y` (a dependency of the package). It needs ESLint 9 or later, and ESLint 10 works from `eslint-config-next@16.4.0`.
- `next lint` and the `eslint` option in the Next.js config were removed in 16.0. A legacy `.eslintrc.*` migrates with `npx @next/codemod@canary next-lint-to-eslint-cli .`.
- Disable a Next.js rule only with a comment that gives the reason.
- Add the typed typescript-eslint presets after these two configs, as the TypeScript conventions show ([linting](../typescript-conventions/02-project-setup-and-tooling.md#linting)).
- ESLint is the linter and Prettier is the formatter. Biome is not used: `create-next-app` generates the ESLint setup, and both tools have several times the weekly downloads of Biome.
- Format with Prettier and its default options, with no config file. `eslint-config-prettier/flat` goes last in the ESLint config, so that the two tools do not fight.

### Configuration

- Keep `next.config.ts` short. Expect these entries and nothing more by default:

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone', // Docker image without node_modules
  typedRoutes: true, // type-checked href values
  poweredByHeader: false, // do not announce the framework in a response header
}

export default nextConfig
```

- Do not repeat defaults. `reactStrictMode` is already on for the App Router since Next.js 13.5.1.
- Comment every non-default option with its reason. An `experimental.*` flag also needs a link to its documentation page.
- Leave `reactCompiler` off. It raises compile times, so turn it on only when a profiler shows a render problem, in its own pull request.
- Add `images.remotePatterns` only when the project optimises remote images, and keep it as specific as possible ([images](09-styling-images-fonts-and-scripts.md#images)). Without it the optimiser stays closed to remote sources.

### Environment files

- Keep `.env*` files out of Git. `create-next-app` ignores them. Commit a `.env.example` that lists variable names with harmless placeholders.
- Next.js looks up a variable in this order: `process.env`, `.env.$(NODE_ENV).local`, `.env.local` (skipped when `NODE_ENV` is `test`), `.env.$(NODE_ENV)`, `.env`. Keep `.env*` files in the project root, even with a `src/` folder.
- Rules for secrets and `NEXT_PUBLIC_` values live in [security](10-security.md#environment-variables).

### Upgrading

- Run `npx next upgrade` to move to the latest release. A coding agent can run `npx next@canary upgrade --agent=latest`.
- The `upgrade` codemod does not cover every migration. If code still reads `params`, `searchParams`, `cookies()`, `headers()` or `draftMode()` synchronously, also run `npx @next/codemod@canary next-async-request-api .`.
- Make one upgrade per pull request. Compare the route table in the `next build` output before and after, because `○` (static) and `ƒ` (dynamic) markers show rendering changes.
- [Modern Next.js by release](13-modern-nextjs-by-release.md) lists what changed in each version.

### Automation

One script runs every check: `npm run ci`. Run it before you open a pull request, and have the CI runner call that script and nothing else. No CI system is mandated, and the runner file stays a thin wrapper. The script chains these steps in order:

```bash
npm ci                # CI only: install from the lock file
npm run typecheck     # next typegen, then tsc --noEmit
npm run lint
npm run format:check
npm run build
```

Append the test commands from [testing and quality gates](11-testing-and-quality-gates.md) to the `ci` script when the project has tests.

## Sources and raw notes

Pages read on 2026-10-26:

- [Installation](https://nextjs.org/docs/app/getting-started/installation): Node.js 20.9 minimum, TypeScript 5.1 minimum, `create-next-app` defaults, scripts, linting setup, `next upgrade`.
- [ESLint plugin](https://nextjs.org/docs/app/api-reference/config/eslint) and the `eslint-config-next@16.4.1` `package.json` on unpkg (dependencies, ESLint 9 and later).
- [TypeScript](https://nextjs.org/docs/app/api-reference/config/typescript): `next-env.d.ts`, `typedRoutes`, route-aware helpers, `ignoreBuildErrors`, TypeScript 7.
- [Upgrading to version 16](https://nextjs.org/docs/app/guides/upgrading/version-16): Turbopack default, `next lint` removal, codemods.
- [Environment variables](https://nextjs.org/docs/app/guides/environment-variables) and [`reactStrictMode`](https://nextjs.org/docs/app/api-reference/config/next-config-js/reactStrictMode).
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) (TypeScript 7 type checking) and the Node.js [release schedule](https://github.com/nodejs/Release/blob/main/schedule.json) (v20 end 2026-04-30; v22 end 2027-04-30).
- The official [`with-docker` Dockerfile](https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile) (canary branch, 2026-10-26): `node:24.13.0-slim`.
- npm weekly downloads on 2026-10-26 (`api.npmjs.org`): `eslint` 102.2 million, `prettier` 87.5 million, `@biomejs/biome` 11.9 million.
