# Vue Project Setup and Tooling

## Summary

Start a Vue project from `create-vue`, then bring it to the baseline of this note: the six TypeScript options of the TypeScript notes, the `@/` alias, a typed ESLint flat config with `eslint-plugin-vue`, Prettier with its defaults, Vitest in two projects, and one script per check, all run in CI. The `vue-tsc` command is the type checker for `.vue` files, because `tsc` cannot read them.

## Rules

### Creating a project

- Create a project with `npm create vue@latest`. Answer yes to TypeScript, Vue Router (for a multi-page app), Pinia (for shared state), Vitest, and ESLint with Prettier. Answer no to Oxlint, JSX, end-to-end tools and the experimental options. The prompts also accept flags: `npm create vue@latest app -- --ts --router --pinia --vitest --eslint --prettier`.
- Vue's own tooling page names `create-vue` as the scaffolding tool for Vite projects, and `vue-cli` as maintenance mode. Do not start a project with Vue CLI or webpack.
- `create-vue` 3.24.0 writes `vue`, `vue-router`, `pinia`, `vite`, `@vitejs/plugin-vue`, `vue-tsc`, `@vue/tsconfig`, `typescript ~6.0.0`, ESLint, `eslint-plugin-vue`, `@vue/eslint-config-typescript`, Vitest, `@vue/test-utils`, `jsdom` and `@tsconfig/node24`. Keep the Vue, Vite, TypeScript and ESLint packages. The sections below replace the test packages and the `node24` base, and remove Oxlint if you chose it.
- Give `@types/node` the major version of the Node.js that runs the tools ([setup of the TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#nodejs-and-type-packages)). The template writes `engines.node` as `^22.18.0 || >=24.12.0`; keep it.
- Replace the demo content at once: delete `src/components`, `src/views`, `src/assets` and `src/stores/counter.ts`, and the demo routes. Rename `App.vue` to `app.vue` in two steps (`git mv App.vue tmp.vue && git mv tmp.vue app.vue`), because macOS and Windows treat the two names as one file ([naming](03-project-layout-and-naming.md#naming)).
- In `src/main.ts`, throw when `#app` is missing instead of using a non-null assertion, and use `./app.vue`:

```ts
// src/main.ts
import { createPinia } from "pinia";
import { createApp } from "vue";

import App from "./app.vue";
import { router } from "./router";

const root = document.getElementById("app");
if (!root) {
  throw new Error("Missing #app element in index.html");
}

const app = createApp(App);
app.use(createPinia());
app.use(router);
app.mount(root);
```

- Run `npx prettier --write .` once after you scaffold, in its own commit ([formatting](#formatting)).

### Vue and compiler

- Use the Vite plugin `@vitejs/plugin-vue` with its defaults: `plugins: [vue()]`. Reactive props destructure is on by default since Vue 3.5, so it needs no compiler option.
- Do not alias `vue` to the full build (`vue/dist/vue.esm-bundler.js`). The runtime-only build is the default, and every template is compiled at build time. In-browser template compilation adds about 14 kB, and the [security note](11-performance-and-security.md#security) bans untrusted templates.
- Do not install the Vue Devtools plugin (`vite-plugin-vue-devtools`) as a project dependency by default. The browser extension covers the same ground. Add the plugin to `devDependencies` only for a reason you write in the pull request.

### tsconfig

- Keep the two build files that `create-vue` writes: `tsconfig.app.json` for the code in `src/`, and `tsconfig.node.json` for `vite.config.ts` and `eslint.config.ts`. They describe two environments, as the [TypeScript notes](../typescript-conventions/03-tsconfig.md#one-tsconfig-per-environment) require. Delete `tsconfig.vitest.json`: the test files go in the app project.
- `tsconfig.app.json` extends `@vue/tsconfig/tsconfig.dom.json`. That base sets `strict`, `verbatimModuleSyntax`, `moduleResolution: bundler`, `moduleDetection: force`, `jsx: preserve`, `skipLibCheck`, `noEmit`, `lib` of `ES2022`, `DOM` and `DOM.Iterable`, and an empty `types` list. The Vue documentation needs `verbatimModuleSyntax` for `<script setup>`.
- Add the options that the TypeScript notes require, and the alias. `create-vue` already writes `noUncheckedIndexedAccess` and `paths`:

```jsonc
// tsconfig.app.json
{
  "extends": "@vue/tsconfig/tsconfig.dom.json",
  "include": ["env.d.ts", "src/**/*", "src/**/*.vue"],
  "vueCompilerOptions": { "strictTemplates": true },
  "compilerOptions": {
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "erasableSyntaxOnly": true,
    "types": ["vite/client", "vitest/browser"],
    "paths": { "@/*": ["./src/*"] },
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo"
  }
}
```

```jsonc
// tsconfig.json
{
  "files": [],
  "references": [{ "path": "./tsconfig.app.json" }, { "path": "./tsconfig.node.json" }]
}
```

- `vueCompilerOptions.strictTemplates` makes `vue-tsc` report a prop that a component does not declare, and an event or slot that does not exist, instead of accepting it as a fallthrough attribute. The sample project reported `bogus` on `<LoanRow bogus="1" />` with the option on and nothing with it off. `data-*` and `aria-*` attributes still pass. It is the template counterpart of `strict`.
- `strict` and `verbatimModuleSyntax` come from the base, so they are not written again. If your project must not depend on the base for them, write them out, as the TypeScript notes do.
- Remove the `exclude` entry for `__tests__` from `tsconfig.app.json`, and keep `env.d.ts` with `/// <reference types="vite/client" />`. The `vitest/browser` type entry gives the browser matchers and the `vitest/browser` module types to the test files.
- `erasableSyntaxOnly` matches Vue: `<script setup lang="ts">` strips types and does not run a TypeScript emitter, so an `enum` or a constructor parameter property would not mean the same everywhere. The sample project type-checked with the option on.
- The `@/*` alias needs the `resolve.alias` entry in `vite.config.ts` (see [Vitest](#vitest)), because `create-vue` writes it there. Keep it in step with `paths`.
- `create-vue` writes `tsconfig.node.json` with `extends: "@tsconfig/node24/tsconfig.json"`. The TypeScript notes write the options in the file instead of adding a base package, so replace the file with this one, and run `npm uninstall @tsconfig/node24`. Vite and ESLint read these files through their own loaders, so `module: preserve` and `moduleResolution: bundler` fit, not `nodenext`:

```jsonc
// tsconfig.node.json
{
  "include": ["vite.config.*", "eslint.config.*"],
  "compilerOptions": {
    "target": "es2024",
    "lib": ["es2024"],
    "module": "preserve",
    "moduleResolution": "bundler",
    "moduleDetection": "force",
    "types": ["node"],
    "strict": true,
    "verbatimModuleSyntax": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "erasableSyntaxOnly": true,
    "allowImportingTsExtensions": true,
    "skipLibCheck": true,
    "noEmit": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo"
  }
}
```

- Set `lib` and `target` to match the Node.js major in `engines`, as the TypeScript notes say.

### Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "check": "vue-tsc --build",
    "lint": "eslint --max-warnings 0",
    "format:check": "prettier --check .",
    "test": "vitest run",
    "ci": "npm run check && npm run lint && npm run format:check && npm test && npm run build"
  }
}
```

- The script is `check`, as in the Svelte notes, and not the `typecheck` of the TypeScript notes, because `vue-tsc --build` is the type check for `.vue` and `.ts` files together, and `create-vue` calls it `type-check`. It reads the references in `tsconfig.json`, so it checks the app and the Node.js config files.
- `eslint --max-warnings 0` is the only difference from the TypeScript notes' `eslint` script. `eslint-plugin-vue`'s `flat/recommended` set most rules to `warn`, and a warning must fail CI, as the Svelte notes do with `--fail-on-warnings`.
- `create-vue` writes `build` as `run-p type-check "build-only {@}" --` and `lint` as `run-s "lint:*"`. Replace both, and remove `npm-run-all2`.
- Run the checks in this order: type check, lint, format check, tests, build. Have the CI runner call `npm run ci` and nothing else.
- `vue-tsc` checks the whole project. It cannot check only the staged files, because a renamed prop breaks the files that use it.

### Linting

- Use the typed flat config of the [TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#linting) (`recommendedTypeChecked`, `stylisticTypeChecked`, `projectService`, and `no-non-null-assertion` as an error) and add `eslint-plugin-vue`. `@vue/eslint-config-typescript` wraps the typescript-eslint presets so that they run on `.vue` files; its `defineConfigWithVueTs()` and `vueTsConfigs` exports replace the `tseslint.config()` and `tseslint.configs` of a plain project.
- Use `pluginVue.configs["flat/recommended"]`, not the `flat/essential` that `create-vue` writes. The `recommended` preset adds the strongly recommended and recommended rules of the Vue style guide, such as `vue/attributes-order`, `vue/block-order` and `vue/html-self-closing`.

```ts
// eslint.config.ts
import js from "@eslint/js";
import {
  defineConfigWithVueTs,
  vueTsConfigs,
} from "@vue/eslint-config-typescript";
import prettier from "eslint-config-prettier/flat";
import pluginVue from "eslint-plugin-vue";
import pluginA11y from "eslint-plugin-vuejs-accessibility";
import { globalIgnores } from "eslint/config";

export default defineConfigWithVueTs(
  globalIgnores(["dist/**", "coverage/**"]),
  js.configs.recommended,
  pluginVue.configs["flat/recommended"],
  pluginA11y.configs["flat/recommended"],
  vueTsConfigs.recommendedTypeChecked,
  vueTsConfigs.stylisticTypeChecked,
  {
    files: ["**/*.{ts,vue}"],
    rules: { "@typescript-eslint/no-non-null-assertion": "error" },
  },
  {
    files: ["**/*.vue"],
    rules: { /* the rules in the next section */ },
  },
  {
    files: ["**/*.vue"],
    rules: {
      "vuejs-accessibility/label-has-for": [
        "error",
        { required: { some: ["nesting", "id"] } },
      ],
    },
  },
  prettier,
);
```

- Add `eslint-plugin-vuejs-accessibility` with its `flat/recommended` config. Vue has no compiler warnings for accessibility, as Svelte does, so the plugin is the only automatic check. It reports a click handler on a `<div>` with no key handler, an `<img>` with no `alt`, and a form control with no label. Its default `label-has-for` rule requires a label to nest the control and to name it by `id`; the setting above accepts either, which fits a label that uses `:for` with `useId()`. The plugin is a community project and is not part of the Vue organisation ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Put `prettier` last, so that ESLint and Prettier do not fight. `eslint-plugin-vue` ships formatting rules, and `eslint-config-prettier/flat` turns the ones that Prettier owns off.
- Install `@eslint/js`, `eslint-config-prettier`, `eslint-plugin-vue`, `eslint-plugin-vuejs-accessibility`, `@vue/eslint-config-typescript`, `typescript-eslint` and `jiti`. ESLint reads `eslint.config.ts` through `jiti`.
- Do not use the `strict` typescript-eslint presets, as the TypeScript notes say.
- Do not use the Oxlint option of `create-vue`, and do not replace ESLint and Prettier with Oxlint and Oxfmt ([decisions in the TypeScript notes](../typescript-conventions/01-principles-and-sources.md#decisions-to-review)). Oxlint has a Vue plugin, but it cannot match the template rules and the typed rules of this config.

### ESLint rules for Vue

`flat/recommended` already reports the rules of the style guide's essential and strongly recommended pages: `vue/multi-word-component-names`, `vue/require-v-for-key`, `vue/no-use-v-if-with-v-for`, `vue/no-mutating-props`, `vue/prop-name-casing` and the template rules. Add these sixteen, because they enforce the choices of these notes, and switch one off:

| Rule | Setting | What it enforces |
| --- | --- | --- |
| `vue/block-lang` | `["error", { script: { lang: "ts" } }]` | Every `<script>` has `lang="ts"` |
| `vue/component-api-style` | `["error", ["script-setup"]]` | No Options API and no `setup()` function |
| `vue/define-emits-declaration` | `["error", "type-literal"]` | `defineEmits<{ select: [id: string] }>()` |
| `vue/define-macros-order` | `["error", { order: ["defineOptions", "defineProps", "defineEmits", "defineModel", "defineSlots"] }]` | The macros come first, in that order. Without the `order` option the rule knows only `defineProps` and `defineEmits`, and reports a `defineModel` written before `defineEmits` |
| `vue/define-props-declaration` | `["error", "type-based"]` | `defineProps<Props>()`, not a runtime object |
| `vue/define-props-destructuring` | `["error", { destructure: "always" }]` | Props are destructured, not read as `props.x` |
| `vue/enforce-style-attribute` | `["error", { allow: ["scoped"] }]` | `<style scoped>` only |
| `vue/no-ref-object-reactivity-loss` | `error` | No destructuring that detaches a ref from its object |
| `vue/no-required-prop-with-default` | `error` | A prop with a default is optional |
| `vue/no-undef-components` | `error` | A component in the template is imported |
| `vue/no-unused-refs` | `error` | A template `ref` is read in the script |
| `vue/no-v-html` | `error` | No `v-html` |
| `vue/prefer-define-options` | `error` | `defineOptions()` instead of a second `<script>` for options |
| `vue/prefer-use-template-ref` | `error` | `useTemplateRef()`, not `ref(null)` |
| `vue/require-explicit-slots` | `error` | Every slot is declared with `defineSlots()` |
| `vue/require-typed-ref` | `error` | `ref<string>()`, not an untyped empty `ref()` |
| `vue/require-default-prop` | `off` | An optional prop is `undefined` when absent, as the TypeScript notes say |

- A rule in this table that a note does not explain is explained where the note uses it. If a plugin upgrade adds a rule to `flat/recommended` that conflicts with a note, switch it off with a comment that gives the reason.
- Disable a rule only with a comment that gives the reason, as the TypeScript notes say. Use `<!-- eslint-disable-next-line vue/rule-name -- reason -->` in a template.

### Formatting

- Format with Prettier 3 and its default options, with no `.prettierrc`. Prettier formats `.vue` files itself, so there is no plugin to load. This follows the TypeScript rule of no Prettier config file, and it differs from `create-vue`, which writes `.prettierrc.json` with `semi: false`, `singleQuote: true` and `printWidth: 100`.
- Delete `.prettierrc.json`, and delete the `max_line_length = 100` line from `.editorconfig`. Prettier reads `.editorconfig` and maps `max_line_length` to `printWidth`, so the line would keep the old width. Keep the other `.editorconfig` lines: they match the Prettier defaults.
- Keep the default `vueIndentScriptAndStyle: false`, which leaves the code in `<script>` and `<style>` at the left margin.
- Change the `format` script that `create-vue` writes to `prettier --write .`, or drop it, and use `format:check` in CI. Run `prettier --write .` once after the scaffold, in its own commit. The template's files do not pass Prettier with the default options.
- When the project uses the Tailwind CSS plugin for Prettier, list it last in `plugins`. That is the only reason for a `.prettierrc`.

### Vitest

- Run Vitest in two projects, in `vite.config.ts`. Delete the separate `vitest.config.ts`. The [testing note](12-testing.md#tools) explains the two projects:

```ts
// vite.config.ts
import { fileURLToPath, URL } from "node:url";

import vue from "@vitejs/plugin-vue";
import { playwright } from "@vitest/browser-playwright";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  test: {
    projects: [
      {
        extends: true,
        test: {
          name: "unit",
          environment: "node",
          include: ["src/**/*.test.ts"],
          exclude: ["src/**/*.browser.test.ts"],
        },
      },
      {
        extends: true,
        optimizeDeps: { include: ["vue"] },
        test: {
          name: "component",
          include: ["src/**/*.browser.test.ts"],
          browser: {
            enabled: true,
            headless: true,
            provider: playwright(),
            instances: [{ browser: "chromium" }],
          },
        },
      },
    ],
  },
});
```

- `optimizeDeps.include` goes on the project, not inside `test`. On a cold cache Vitest otherwise prints "Vite unexpectedly reloaded a test", because Vite finds `vue` while it runs the first browser test.
- Install the test tools and one browser:

```bash
npm install -D vitest vitest-browser-vue @vitest/browser-playwright playwright
npx playwright install chromium
```

- Remove `@vue/test-utils`, `jsdom`, `@types/jsdom` and `@vitest/eslint-plugin` from the scaffold. The sample project ran without them.

### Editor

- Install the Vue (Official) extension, and select the workspace TypeScript version, so that the editor and CI report the same errors ([editor of the TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#editor)). The extension replaced Volar and Vetur. Turn Vetur off in a Vue 3 project.
- Let Prettier format on save, not the extension. `create-vue` writes `.vscode/settings.json` with `editor.formatOnSave` on and `editor.defaultFormatter` set to the Prettier extension, which is correct. Delete the `oxc.oxc-vscode` entry from `.vscode/extensions.json`.

## Sources and raw notes

Pages read on 2026-11-20:

- [Vue tooling](https://vuejs.org/guide/scaling-up/tooling.html): `create-vue`, Vue CLI in maintenance mode, the runtime-only build and the 14 kB of the compiler, the Vue (Official) extension, `vue-tsc`, `eslint-plugin-vue`, Vitest and Prettier.
- [Vue TypeScript overview](https://vuejs.org/guide/typescript/overview.html) and [with the Composition API](https://vuejs.org/guide/typescript/composition-api.html): `lang="ts"`, `vue-tsc`, type-based props and emits.
- [`@vue/tsconfig`](https://github.com/vuejs/tsconfig) 0.9.1, read from `node_modules`: the options of `tsconfig.json` and `tsconfig.dom.json`.
- [eslint-plugin-vue](https://eslint.vuejs.org/) 10.12.1: the `flat/recommended` config and the rules in the table. The list of rules that `flat/recommended` enables was read from the installed package.
- [`@vue/eslint-config-typescript`](https://github.com/vuejs/eslint-config-typescript) 14.9.0: `defineConfigWithVueTs`, `vueTsConfigs.recommendedTypeChecked` and `stylisticTypeChecked`.
- [Vitest browser mode](https://vitest.dev/guide/browser/) and [Vitest projects](https://vitest.dev/guide/projects.html).
- `create-vue` 3.24.0, run on 2026-11-20 (see the [principles note](01-principles-and-sources.md#sources-and-raw-notes)).
- Checked on 2026-11-20 in a scratch project made with `create-vue` 3.24.0, Vue 3.5.45, `@vue/tsconfig` 0.9.1, TypeScript 6.0.3, Vite 8.3.8, `vue-tsc` 3.3.14, ESLint 10.15.0, `eslint-plugin-vue` 10.12.1, `@vue/eslint-config-typescript` 14.9.0, `eslint-config-prettier` 10.1.8, Prettier 3.10.1, Vitest 5.1.1, `vitest-browser-vue` 3.1.0 and Playwright Chromium:
  - The `tsconfig.app.json`, `tsconfig.node.json` (with no `@tsconfig/node24`), `eslint.config.ts`, `vite.config.ts` and scripts of this note ran with 0 errors: `npm run ci` passed `vue-tsc --build`, `eslint --max-warnings 0`, `prettier --check .`, `vitest run` (one unit test, one browser test) and `vite build`.
  - A file with a runtime `defineProps`, an untyped `ref(null)` template ref, a `ref` without a type, `v-html` with child content, a `v-for` with `v-if` and no key, an unknown component, a plain `<style>` and a non-null assertion gave 18 errors and one warning from the rules in the table and from `flat/recommended`.
  - `eslint-plugin-vuejs-accessibility` 2.6.3 reported a `<div @click>` (two rules), an `<img>` without `alt` and an unlabelled `<input>`, and its `label-has-for` default reported a `<label :for>` that does not wrap its control until the setting above was added. The plugin declares ESLint 10 in its peer range.
  - An optional prop without a default (`label?: string`) gave a `vue/require-default-prop` warning until the rule was switched off.
  - `vueCompilerOptions.strictTemplates` reported an undeclared prop on a component (`TS2353`), and the whole sample then passed with the option on.
  - A composable that read `document` inside `watchEffect` failed in the `unit` project with `document is not defined`.
  - Without `optimizeDeps.include: ["vue"]` on the `component` project, the first run on an empty cache printed "Vite unexpectedly reloaded a test". With it, the cold run was clean.
  - Renaming `App.vue` to `app.vue` by writing a new file on macOS kept the old name on disk, and `vue-tsc` then reported TS1149 (names that differ only in casing). Renaming through a temporary name fixed it.
