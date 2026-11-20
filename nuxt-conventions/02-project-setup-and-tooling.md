# Nuxt Project Setup and Tooling

## Summary

Start a Nuxt project from `create-nuxt`, then bring it to the baseline of this note: `typescript` and `vue-tsc` installed so that `nuxt typecheck` works, three extra compiler options added through `nuxt.config.ts`, a typed ESLint flat config built on `withNuxt()`, Prettier with its defaults, Vitest in three projects, and one script per check, all run in CI. Nuxt generates its own tsconfig files, so you extend them from `nuxt.config.ts` and never edit them.

## Rules

### Creating a project

- Create a project with `npm create nuxt@latest <name> -- --template minimal --packageManager npm`. The `minimal` template writes `nuxt`, `vue` and `vue-router`, `nuxt.config.ts`, `app/app.vue`, `public/` and the `.gitignore`. Add the modules that the project needs at the prompt, or later with `npx nuxt module add <name>`.
- Nuxt's own packages declare `node` in `engines` (`^22.22.3 || ^24.15.0 || >=26.0.0` for `nuxt` 4.6.4). Use the same Node.js major in `engines`, `.nvmrc` and the Docker image, and give `@types/node` that major ([setup of the TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#nodejs-and-type-packages)).
- The template writes no `typescript`, no `vue-tsc` and no linter. Install them: `npm install -D typescript@~6.0.3 vue-tsc @nuxt/eslint eslint prettier eslint-config-prettier @eslint/js typescript-eslint eslint-plugin-vuejs-accessibility jiti`.
- Replace the demo in `app/app.vue`: delete `<NuxtWelcome />`, keep `<NuxtRouteAnnouncer />`, which announces client-side navigation to screen readers, and render `<NuxtLayout>` around `<NuxtPage />`:

```vue
<!-- app/app.vue -->
<template>
  <NuxtLayout>
    <NuxtRouteAnnouncer />
    <NuxtPage />
  </NuxtLayout>
</template>
```

- Keep the `postinstall` script that the template writes (`nuxt prepare`). It generates `.nuxt/`, which the type check, the linter and the tests all read. CI installs with `npm ci` and never with `--ignore-scripts`.
- Keep `compatibilityDate` in `nuxt.config.ts`, as the template writes it. It pins the behaviour of Nitro presets and other date-based defaults. Raise it in its own change, after reading the upgrade notes.
- Run `npx prettier --write .` once after you scaffold, in its own commit.
- Commit `package-lock.json`. Do not commit `.nuxt/`, `.output/`, `.data/` or `node_modules/`; the template's `.gitignore` already lists them, and `.env` files too.

### nuxt.config.ts

- Keep `nuxt.config.ts` short. It names modules, runtime config, route rules and the few settings that this note names. Do not put application logic in it.
- A minimal config for these notes:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  compatibilityDate: "2025-07-15",
  devtools: { enabled: true },
  modules: ["@nuxt/eslint", "@nuxt/test-utils/module", "@pinia/nuxt"],
  typescript: {
    nodeTsConfig: {
      include: [
        "../eslint.config.ts",
        "../vitest.config.ts",
        "../test/unit/**/*",
        "../test/e2e/**/*",
      ],
    },
    tsConfig: {
      compilerOptions: {
        noImplicitReturns: true,
        noFallthroughCasesInSwitch: true,
        erasableSyntaxOnly: true,
      },
    },
  },
  runtimeConfig: {
    loansApiUrl: "",
    public: { siteName: "Loans" },
  },
  routeRules: {
    "/": { swr: 60 },
  },
});
```

- Add `@pinia/nuxt` only when the project has shared client state beyond `useState()` ([state](07-state-and-configuration.md#state)), and `@nuxt/image` and `@nuxt/fonts` only when the project has images or web fonts to optimise ([performance](09-rendering-seo-and-performance.md#images-fonts-and-assets)). Do not add a UI kit, a CSS framework or an icon module without a reason that you write in the pull request.
- `nuxt.config.ts` is a default export, and it needs no `import` for `defineNuxtConfig`.
- Do not turn `typescript.typeCheck` on. It type-checks on every `nuxt dev` and `nuxt build`, and it slows both. Run `nuxt typecheck` as its own step ([scripts](#scripts)).

### tsconfig

- Leave `tsconfig.json` as `create-nuxt` writes it: `"files": []` and four references to `.nuxt/tsconfig.app.json`, `tsconfig.server.json`, `tsconfig.shared.json` and `tsconfig.node.json`. The Nuxt documentation warns against editing it, because Nuxt and its modules rely on the generated settings. The four files describe four environments (the Vue app, the Nitro server, code shared by both, and Node.js tooling), as the [TypeScript notes](../typescript-conventions/03-tsconfig.md#one-tsconfig-per-environment) require.
- The generated files already set `strict`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `moduleResolution: Bundler`, `module: preserve` and `skipLibCheck`. Add the remaining options of the TypeScript notes through `typescript.tsConfig.compilerOptions` in `nuxt.config.ts`, which applies to all four files: `noImplicitReturns`, `noFallthroughCasesInSwitch` and `erasableSyntaxOnly`. `typescript.appTsConfig`, `serverTsConfig`, `sharedTsConfig` and `nodeTsConfig` extend one environment.
- Add the files that no generated project covers to `typescript.nodeTsConfig.include`: `eslint.config.ts`, `vitest.config.ts`, and the `test/unit` and `test/e2e` folders. The `test/nuxt` folder is already part of the app project. Without the entries, typed ESLint stops with "was not found by the project" for those files.
- Nuxt's generated files keep `allowJs: true`. Write every new file in TypeScript, and do not add `checkJs`, as the TypeScript notes say.
- Nuxt defines the aliases: `~` and `@` for `app/`, `~~` and `@@` for the project root, and `#shared` for `shared/`. Use `@/` for `app/` and `#shared/` for `shared/`, never `../../..` ([layout](03-project-layout-and-auto-imports.md#naming)).
- Put a type augmentation in the directory of the environment that it augments: `app/` for the app, `server/` for Nitro, `shared/` for both. A file outside them is not part of any project ([TypeScript in Nuxt](12-typescript-in-nuxt.md#type-contexts)).

### Scripts

```json
{
  "scripts": {
    "dev": "nuxt dev",
    "build": "nuxt build",
    "generate": "nuxt generate",
    "preview": "nuxt preview",
    "postinstall": "nuxt prepare",
    "check": "nuxt typecheck",
    "lint": "eslint --max-warnings 0",
    "format:check": "prettier --check .",
    "test": "vitest run",
    "ci": "npm run check && npm run lint && npm run format:check && npm test && npm run build"
  }
}
```

- `nuxt typecheck` runs `vue-tsc --build` over the four generated projects. It needs `typescript` and `vue-tsc` installed, and it fails with a message that says so when they are missing. It checks the whole project, because a renamed prop breaks the files that use it.
- `check` is the name that the Vue and Svelte notes use. The TypeScript notes call the script `typecheck`; the Nuxt command is `nuxt typecheck`, so the script keeps `check`.
- `eslint --max-warnings 0` fails on a warning, because the Nuxt config sets many Vue rules to `warn`.
- `nuxt build` builds the client, the server and the Nitro output in `.output/`. Run it in CI as the last step. `nuxt generate` is for a fully static site ([deployment](11-deployment-and-presets.md#static-sites)).
- Run the checks in this order: type check, lint, format check, tests, build. Have the CI runner call `npm run ci` and nothing else.
- The e2e project builds the app itself, so `vitest run` takes longer than in a plain Vue project. A project with many e2e tests runs them as a separate script, but keeps one `ci` entry that runs all of them.

### Linting

- Use `@nuxt/eslint`. The module generates `.nuxt/eslint.config.mjs`, and `withNuxt()` from it wraps your own flat config. The generated config already includes the JavaScript, typescript-eslint (not type-aware), Vue (`recommended`-level rules, mostly warnings) and Nuxt rules, with the globals of every auto-import, so that `ref`, `useFetch` and your own composables do not report `no-undef`. Delete the `eslint.config.mjs` that the module writes on its first run, and write `eslint.config.ts`:

```ts
// eslint.config.ts
import js from "@eslint/js";
import prettier from "eslint-config-prettier/flat";
import pluginA11y from "eslint-plugin-vuejs-accessibility";
import tseslint from "typescript-eslint";

import withNuxt from "./.nuxt/eslint.config.mjs";

export default withNuxt(
  js.configs.recommended,
  ...[
    ...tseslint.configs.recommendedTypeChecked,
    ...tseslint.configs.stylisticTypeChecked,
  ].map((config) => ({ ...config, files: ["**/*.{ts,vue}"] })),
  {
    files: ["**/*.{ts,vue}"],
    languageOptions: {
      parserOptions: { projectService: true, extraFileExtensions: [".vue"] },
    },
    rules: { "@typescript-eslint/no-non-null-assertion": "error" },
  },
  pluginA11y.configs["flat/recommended"],
  {
    files: ["**/*.vue"],
    rules: { /* the Vue rules in the next section */ },
  },
  prettier,
);
```

- Add the typed presets of the [TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#linting) (`recommendedTypeChecked`, `stylisticTypeChecked`, `projectService`, `no-non-null-assertion` as an error) with `files: ["**/*.{ts,vue}"]`, as the sample does, because the preset objects carry no `files` and would otherwise lint every file. Put `prettier` last, so that ESLint and Prettier do not fight.
- `projectService` finds the generated projects through the references in `tsconfig.json`. It works for `app/`, `server/` and `shared/` files, and for the tooling files that `nodeTsConfig.include` lists.
- Do not use the `strict` presets, and do not use Oxlint or Oxfmt, as the TypeScript notes say. Do not turn on the module's stylistic rules (`eslint: { config: { stylistic: true } }`), which format code and fight Prettier.

### ESLint rules for Nuxt

`withNuxt()` already enables `vue/attributes-order`, `vue/block-order`, `vue/require-v-for-key`, `vue/no-use-v-if-with-v-for`, `vue/no-mutating-props`, `vue/prop-name-casing`, `vue/v-bind-style`, `vue/v-on-style`, `vue/v-slot-style` and `vue/no-multiple-template-root`, and switches `vue/multi-word-component-names` and `vue/html-self-closing` off. Add the Vue rules of the [Vue setup note](../vue-conventions/02-project-setup-and-tooling.md#eslint-rules-for-vue) to the `**/*.vue` block, except `vue/no-undef-components`, which would report every auto-imported component:

- `vue/block-lang` (`script: { lang: "ts" }`), `vue/component-api-style` (`["script-setup"]`), `vue/define-emits-declaration` (`type-literal`), `vue/define-macros-order` (with its five-macro `order`), `vue/define-props-declaration` (`type-based`), `vue/define-props-destructuring` (`always`), `vue/enforce-style-attribute` (`allow: ["scoped"]`), `vue/no-ref-object-reactivity-loss`, `vue/no-required-prop-with-default`, `vue/no-unused-refs`, `vue/no-v-html`, `vue/prefer-define-options`, `vue/prefer-use-template-ref`, `vue/require-explicit-slots`, `vue/require-typed-ref`, all `error`, and `vue/require-default-prop` `off`.
- `vuejs-accessibility/label-has-for` with `required: { some: ["nesting", "id"] }`.
- A layout needs `defineSlots<{ default(): unknown }>()`, because `vue/require-explicit-slots` applies to it too.
- Nuxt turns `vue/multi-word-component-names` off, because Nuxt prefixes a component's name with its folder and pages are single words (`index.vue`). The naming rule of the [Vue notes](../vue-conventions/03-project-layout-and-naming.md#naming) still applies, and review enforces it.
- The `@nuxt/eslint` module has `nuxt/*` rules for `nuxt.config.ts` and for the files in the scanned directories. Leave them on.
- Disable a rule only with a comment that gives the reason, as the TypeScript notes say.

### Formatting

- Format with Prettier 3 and its default options, with no config file, as the TypeScript notes say. Prettier formats `.vue` files itself. Add a `.prettierignore` that lists `.nuxt`, `.output` and `node_modules`, because `prettier --check .` would otherwise read the generated files that `.gitignore` also lists. The `.gitignore` already hides them from ESLint through `withNuxt()`.
- The Tailwind plugin, if the project uses it, is listed last in `plugins` of a `.prettierrc`, which is then the one reason for that file.

### Editor

- Install the Vue (Official) extension, with the workspace TypeScript version selected ([editor of the TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#editor)). Run `nuxt prepare` after you clone, so that the editor finds the generated types. Nuxt DevTools (`devtools: { enabled: true }`) is a development tool only.

## Sources and raw notes

Pages read on 2026-11-20:

- [Nuxt installation](https://nuxt.com/docs/getting-started/installation) and the [`create-nuxt` command](https://www.npmjs.com/package/create-nuxt) 4.0.3: the options (`--template`, `--packageManager`, `--modules`, `--no-install`, `--no-gitInit`).
- [Nuxt TypeScript concept](https://nuxt.com/docs/guide/concepts/typescript): `vue-tsc` and `typescript` for `nuxt typecheck`, no type-check on `dev` and `build` by default for performance, the generated `.nuxt/tsconfig.*.json` files, project references, augmenting types in the right context, strict mode.
- [`tsconfig.json`](https://nuxt.com/docs/directory-structure/tsconfig) and the [`typescript` section of the Nuxt configuration reference](https://nuxt.com/docs/api/nuxt-config#typescript): `tsConfig`, `appTsConfig`, `serverTsConfig`, `sharedTsConfig`, `nodeTsConfig`, `typeCheck`, `strict`.
- [Code style](https://nuxt.com/docs/guide/concepts/code-style): `@nuxt/eslint`.
- [`.nuxt` directory](https://nuxt.com/docs/directory-structure/nuxt) and [`package.json`](https://nuxt.com/docs/directory-structure/package) pages.
- Generated files, read from the sample project: `.nuxt/tsconfig.app.json`, `tsconfig.server.json`, `tsconfig.shared.json`, `tsconfig.node.json` and `.nuxt/eslint.config.mjs`. The set of active Vue rules was read with `eslint --print-config`.
- Checked on 2026-11-20 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes):
  - `nuxt typecheck`, `eslint --max-warnings 0`, `prettier --check .`, `vitest run` and `nuxt build` passed with the config files of this note.
  - Without `nodeTsConfig.include`, typed ESLint reported "eslint.config.ts was not found by the project".
  - A file with a runtime `defineProps`, an untyped `ref(null)` template ref, `v-html`, a `v-for` with `v-if` and no key, a plain `<style>`, a clickable `<div>` and a non-null assertion gave 13 errors from the rules above. A component that Nuxt registers by itself (`<Unknown />`) was not reported, because `no-undef-components` is not enabled.
  - `vue/no-multiple-template-root` reported a layout with a `<header>` and a `<main>` as two roots. `vue/require-explicit-slots` reported a layout that used `<slot />` without `defineSlots()`.
  - `typescript.tsConfig.compilerOptions` reached all four generated files.
