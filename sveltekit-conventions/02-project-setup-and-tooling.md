# SvelteKit Project Setup and Tooling

## Summary

Create a project with `sv create`, then bring it to the baseline of this note: the SvelteKit options in `vite.config.ts`, the tsconfig additions of the TypeScript notes, the typed ESLint config of the Svelte notes, Prettier with the Svelte plugin and no style options, and one script per check. `sv add` writes useful defaults, but several of them differ from the notes, so compare each add-on's output before you keep it.

## Rules

### Creating a project

- Create a project with `npx sv create <name> --template minimal --types ts`. Use `--no-add-ons` and add the tools in the next sections yourself. The `minimal` template is "barebones scaffolding". The `demo` template is a showcase, and `library` and `addon` are for packages.
- A SvelteKit 3 project has no `svelte.config.js`. The template writes a `vite.config.ts` with the `sveltekit()` plugin and a `package.json` with `"imports": { "#lib": "./src/lib/index.js", "#lib/*": "./src/lib/*" }`, and `engine-strict=true` in `.npmrc`.
- Set `"#lib": "./src/lib/index.ts"` in `package.json`, because the template points it at a `.js` file while it writes `index.ts`.
- Give `.nvmrc` and `engines` the Node.js major of the production server (22.17 or later). `.npmrc` already makes `npm install` fail on an engine mismatch.
- Run `npx prettier --write .` once after you scaffold, in its own commit.

### SvelteKit configuration

- Pass every SvelteKit option to the `sveltekit()` plugin in `vite.config.ts`. SvelteKit 3 does not read `svelte.config.js`. Options that were under `kit` are now top-level, next to `compilerOptions`.
- Keep the `compilerOptions.runes` function that the template writes. It forces runes mode for your code and skips `node_modules` ([Svelte setup](../svelte-conventions/02-project-setup-and-tooling.md#svelte-configuration)).
- Choose the adapter on the first day and write it in the same place ([deployment and adapters](10-deployment-and-adapters.md#choosing-an-adapter)):

```ts
// vite.config.ts
import adapter from "@sveltejs/adapter-node";
import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    sveltekit({
      adapter: adapter(),
      compilerOptions: {
        runes: ({ filename }) =>
          filename.split(/[/\\]/).includes("node_modules") ? undefined : true,
      },
    }),
  ],
});
```

- Leave `appDir`, `outDir`, `trailingSlash`, `router`, `output` and `prerender` at their defaults until a note or a requirement says otherwise. `alias` and `files` are deprecated: use subpath imports and the standard folders.
- Set `csp` in `kit` options for any app that has users ([hooks, errors and security](07-hooks-errors-and-security.md#content-security-policy)), and set `paths.origin` when the app does not know its public origin.
- Do not enable an option in `experimental`. The namespace is not under semantic versioning.

### tsconfig

- Extend the base that SvelteKit provides, and keep the template's `include`:

```jsonc
{
  "extends": "$app/tsconfig",
  "compilerOptions": {
    "strict": true,
    "types": ["$app/types", "node"],
    "allowJs": false,
    "checkJs": false,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "erasableSyntaxOnly": true
  },
  "include": ["src", "vite.config.ts", "playwright.config.ts"]
}
```

- `$app/tsconfig` is a base file that SvelteKit writes into `node_modules/$app`. It sets `verbatimModuleSyntax`, `isolatedModules`, `moduleResolution: bundler`, `module` and `target` `esnext`, `allowImportingTsExtensions`, `skipLibCheck` and `noEmit`, so none of those need writing. It also sets `allowJs` and `checkJs`, which the TypeScript notes keep off, so turn them off here.
- Add `"node"` to `types` only when server code or a config file uses the Node.js types. Install `@types/node` with the major version of the production Node.js.
- Do not add `paths` or `baseUrl`. The base sets `paths` to an empty object, and SvelteKit 3 resolves aliases from the `imports` field of `package.json`.
- Exclude `src/service-worker` from the root config and give it its own `tsconfig.json` that extends `$app/tsconfig/service-worker`, if the app has a service worker.
- Run `svelte-kit sync` before any type check. It writes the `$types` files and `.svelte-kit/`. The `prepare` script and the `check` script both run it.

### Scripts

```json
{
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "prepare": "svelte-kit sync || echo ''",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --fail-on-warnings",
    "lint": "eslint",
    "format:check": "prettier --check .",
    "test": "vitest run",
    "test:e2e": "playwright test",
    "ci": "npm run check && npm run lint && npm run format:check && npm test && npm run build"
  }
}
```

- `svelte-check --fail-on-warnings` turns the compiler's accessibility warnings into failures, as the [Svelte notes](../svelte-conventions/02-project-setup-and-tooling.md#scripts) say.
- Run the checks in this order: type check, lint, format check, unit and component tests, build. Run `test:e2e` in a separate CI job that builds first, because it needs a browser ([testing](09-testing-and-quality-gates.md#end-to-end-tests)).
- Have the CI runner call `npm run ci` and nothing else for the first job. `vite build` fails on a missing environment variable, so the CI job needs the build-time values ([environment variables](07-hooks-errors-and-security.md#environment-variables)).

### Linting

- Use the typed flat config of the [Svelte notes](../svelte-conventions/02-project-setup-and-tooling.md#linting), with two changes. Ignore the files that `.gitignore` lists, and set both browser and Node.js globals, because a SvelteKit app runs in both. `sv add eslint` writes the untyped `recommended` preset, so replace it:

```js
// eslint.config.js
import js from "@eslint/js";
import { defineConfig, includeIgnoreFile } from "eslint/config";
import prettier from "eslint-config-prettier/flat";
import svelte from "eslint-plugin-svelte";
import globals from "globals";
import path from "node:path";
import tseslint from "typescript-eslint";

const gitignorePath = path.resolve(import.meta.dirname, ".gitignore");

export default defineConfig([
  includeIgnoreFile(gitignorePath),
  js.configs.recommended,
  {
    files: ["**/*.{ts,svelte}"],
    extends: [
      tseslint.configs.recommendedTypeChecked,
      tseslint.configs.stylisticTypeChecked,
    ],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parserOptions: { projectService: true, extraFileExtensions: [".svelte"] },
    },
    rules: { "@typescript-eslint/no-non-null-assertion": "error" },
  },
  svelte.configs.recommended,
  {
    files: ["**/*.svelte", "**/*.svelte.ts"],
    languageOptions: { parserOptions: { parser: tseslint.parser } },
  },
  prettier,
  svelte.configs.prettier,
]);
```

- The config needs no `svelteConfig` entry, because there is no `svelte.config.js`.
- `svelte.configs.recommended` reports `svelte/no-navigation-without-resolve` on an `<a href="/loans">` and on `goto("/loans")`. Build every internal link with `resolve()` from `$app/paths` ([state and navigation](06-state-and-navigation.md#navigation)).
- Do not set `no-undef`. The `sv add eslint` file turns it off, and typescript-eslint recommends that for TypeScript projects. With the typed presets and `globals`, it is not needed either.

### Formatting

- Use the `.prettierrc` of the [Svelte notes](../svelte-conventions/02-project-setup-and-tooling.md#formatting), which loads `prettier-plugin-svelte` and sets no style option. `sv add prettier` writes a `prettier.config.js` with tabs, single quotes, no trailing commas and a width of 100. Delete that file, because the TypeScript notes use the Prettier defaults. Format the whole project once in its own commit.
- Add the generated and lock files to `.prettierignore`, as `sv add prettier` does: the lock files and `/static/`.

### Editor

- Install the Svelte for VS Code extension and select the workspace TypeScript version ([editor](../typescript-conventions/02-project-setup-and-tooling.md#editor)). The language server types `load` functions and actions without annotations, and the lint rules do not, so the notes write the annotations out ([TypeScript in SvelteKit](11-typescript-in-sveltekit.md#generated-types)).

### Official add-ons

- `npx sv add` installs add-ons into an existing project: `eslint`, `prettier`, `vitest`, `playwright`, `tailwindcss`, `sveltekit-adapter`, `drizzle`, `better-auth`, `paraglide`, `mdsvex`, `storybook` and `enhanced-img`. Run it on a clean git working tree, because it asks before it changes a dirty one. Pass options in the command (`"vitest=usages:unit,component" "playwright=demo:no"`) to skip prompts.
- Compare the output with this note before you keep it. The three add-ons that this set changes are `eslint` (untyped preset), `prettier` (style options) and `vitest` (test file names, see [testing](09-testing-and-quality-gates.md#tools)). Keep `requireAssertions: true` that `sv add vitest` writes, because it fails a test with no assertion.
- Install `sveltekit-adapter` for the adapter, and `playwright` for end-to-end tests.

## Sources and raw notes

Pages read on 2026-11-18:

- [Project structure](https://svelte.dev/docs/kit/project-structure), [configuration](https://svelte.dev/docs/kit/configuration): the `sveltekit()` plugin options, the removal of `svelte.config.js` (supported in `vite.config` since 2.62), the deprecated `alias` and `files`, and the experimental namespace. [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): `$app/tsconfig`, `#lib`, the removed options. [sv add](https://svelte.dev/docs/cli/sv-add): the add-on list.
- `sv` 1.5.0 `sv create ... --template minimal --types ts` output: `vite.config.ts`, `package.json` with `imports`, `tsconfig.json` extending `$app/tsconfig`, `.npmrc`, `src/app.d.ts`, `src/app.html`, and a `src/lib/index.ts`.
- `node_modules/$app/tsconfig/tsconfig.json` of `@sveltejs/kit` 3.3.1: the options listed above, with `paths` set to `{}`, `lib` of `ESNext` and `WebWorker`, `allowJs` and `checkJs` on.
- `sv add eslint prettier "vitest=usages:unit,component" "playwright=demo:no"`: wrote `eslint.config.js` with `ts.configs.recommended` and `no-undef` off, `prettier.config.js` with tabs, single quotes, `trailingComma: 'none'` and `printWidth: 100`, a Vitest config with two projects, and a Playwright config with `testMatch: '**/*.e2e.{ts,js}'`.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the `vite.config.ts`, `tsconfig.json`, scripts and ESLint config above passed `svelte-check` with `--fail-on-warnings`, ESLint and `prettier --check`, and `vite build` passed with `@sveltejs/adapter-node`. An `<a href="/loans">` and a `goto("/loans")` gave two `svelte/no-navigation-without-resolve` errors.
