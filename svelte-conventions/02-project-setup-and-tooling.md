# Svelte Project Setup and Tooling

## Summary

Start a Svelte project from `create-vite` with the `svelte-ts` template, then bring it to the baseline of this note: runes mode forced on, the six TypeScript options of the TypeScript notes, the `@/` alias, a typed ESLint flat config with the Svelte plugin, Prettier with the Svelte plugin, and one script per check, all run in CI. The `svelte-check` command is the type checker for `.svelte` files, because `tsc` cannot read them.

## Rules

### Creating a project

- Create a plain Svelte app with `npm create vite@latest <name> -- --template svelte-ts`. A Wails frontend starts from the same template, or from the Wails template, and is then brought to this baseline.
- `npx sv create` writes a SvelteKit project, not a plain Svelte one. Its four templates are `minimal`, `demo`, `library` and `addon`. Use it only for SvelteKit, which has its own notes.
- The `svelte-ts` template writes `svelte`, `vite`, `@sveltejs/vite-plugin-svelte`, `svelte-check`, `@tsconfig/svelte` and `typescript ~6.0.3`. Keep them. Give `@types/node` the major version of the Node.js that runs the tools ([setup of the TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#nodejs-and-type-packages)).
- Add `lang="ts"` to the `<script>` tag of `App.svelte`, because the template writes it without one.
- Replace the non-null assertion in `src/main.ts` (`document.getElementById("app")!`) with a guard that throws when the element is missing, because `no-non-null-assertion` rejects it.
- Run `npx prettier --write .` once after you scaffold, in its own commit. The template's `README.md` and `svelte.config.js` do not pass Prettier.

### Svelte configuration

- Set runes mode for the whole project in `svelte.config.js`. The compiler then reports `export let`, `$:` and `on:click` as errors, in the build and in `svelte-check`:

```js
// svelte.config.js
/** @type {import("@sveltejs/vite-plugin-svelte").SvelteConfig} */
export default { compilerOptions: { runes: true } };
```

- The setting also applies to components in `node_modules`. If a dependency still ships components in Svelte 4 syntax, give `runes` as a function that skips `node_modules` (Svelte 5.54 and later). Both the build and `svelte-check` apply it:

```js
export default {
  compilerOptions: {
    runes: ({ filename }) => (filename.includes("node_modules") ? undefined : true),
  },
};
```

- Do not use `dynamicCompileOptions` in `vitePlugin` for this. The Vite build applies it, and `svelte-check` does not, so Svelte 4 syntax in your own files passes the type check.

- Do not add `vitePreprocess` for TypeScript. Svelte 5 strips types itself, and the documentation's own sample says the preprocessor is no longer needed for it.
- Do not set `experimental.async` ([errors and async](09-errors-and-async.md#async-in-components)).
- Leave `compilerOptions.css` at the default.
- `svelte.config.js` stays JavaScript, because the tools that read it do not read TypeScript.

### tsconfig

- Keep the two files that `create-vite` writes: `tsconfig.app.json` for the code in `src/`, and `tsconfig.node.json` for `vite.config.ts`. They describe two environments, as the [TypeScript notes](../typescript-conventions/03-tsconfig.md#one-tsconfig-per-environment) require.
- `tsconfig.app.json` extends `@tsconfig/svelte/tsconfig.json`. That base sets `verbatimModuleSyntax`, `strict`, `esModuleInterop`, `skipLibCheck`, `module: esnext` and `moduleResolution: bundler`. Svelte's TypeScript page requires `verbatimModuleSyntax` and `isolatedModules`, and a `target` of at least ES2015.
- Add the options that the TypeScript notes require, and the alias:

```jsonc
{
  "extends": "@tsconfig/svelte/tsconfig.json",
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "target": "es2023",
    "module": "esnext",
    "types": ["svelte", "vite/client"],
    "allowArbitraryExtensions": true,
    "noEmit": true,
    "moduleDetection": "force",
    "paths": { "@/*": ["./src/*"] },
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "erasableSyntaxOnly": true
  },
  "include": ["src/**/*.ts", "src/**/*.js", "src/**/*.svelte"]
}
```

- Remove `allowJs` and `checkJs` from the generated file. The TypeScript notes keep `checkJs` off, and every `<script>` has `lang="ts"`.
- Remove `noUnusedLocals` and `noUnusedParameters` from `tsconfig.node.json`. ESLint reports unused code once ([options that stay off](../typescript-conventions/03-tsconfig.md#options-that-stay-off)).
- `erasableSyntaxOnly` matches Svelte: its TypeScript support only removes types, and the TypeScript page lists enums and constructor parameter modifiers as unsupported without a preprocessor.
- The `@/*` alias needs no setting in Vite. Vite 8 read `paths` from `tsconfig.app.json` in the sample project, and the build failed with `Rolldown failed to resolve import` once the `paths` entry was removed. `resolve.tsconfigPaths` in the Vite config defaults to `false`, and the sample built without it.

### Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "check": "svelte-check --tsconfig ./tsconfig.app.json --fail-on-warnings && tsc -p tsconfig.node.json",
    "lint": "eslint",
    "format:check": "prettier --check .",
    "test": "vitest run",
    "ci": "npm run check && npm run lint && npm run format:check && npm test && npm run build"
  }
}
```

- `svelte-check` is the type check for `.svelte` and `.ts` files together. It reports TypeScript errors, compiler errors, unused CSS and accessibility warnings. `--fail-on-warnings` turns the warnings into a failing exit code, which is how the `a11y_*` warnings become errors in CI.
- `check` also runs `tsc -p tsconfig.node.json`, because `svelte-check` does not check `vite.config.ts`.
- `svelte-check` checks the whole project. It cannot check only the staged files, because a renamed prop breaks the files that use it.
- Run the checks in this order: type check, lint, format check, tests, build. Have the CI runner call `npm run ci` and nothing else.

### Linting

- Use the typed flat config of the [TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#linting) (`recommendedTypeChecked`, `stylisticTypeChecked`, `projectService`, and `no-non-null-assertion` as an error) and add `eslint-plugin-svelte`. The plugin's guide shows the non-typed `ts.configs.recommended`, and the typed presets replace it:

```js
// eslint.config.js
import js from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import prettier from "eslint-config-prettier/flat";
import svelte from "eslint-plugin-svelte";
import globals from "globals";
import tseslint from "typescript-eslint";

import svelteConfig from "./svelte.config.js";

export default defineConfig([
  globalIgnores(["dist/**"]),
  js.configs.recommended,
  {
    files: ["**/*.{ts,svelte}"],
    extends: [
      tseslint.configs.recommendedTypeChecked,
      tseslint.configs.stylisticTypeChecked,
    ],
    languageOptions: {
      globals: globals.browser,
      parserOptions: { projectService: true, extraFileExtensions: [".svelte"] },
    },
    rules: { "@typescript-eslint/no-non-null-assertion": "error" },
  },
  svelte.configs.recommended,
  {
    files: ["**/*.svelte", "**/*.svelte.ts"],
    languageOptions: {
      parserOptions: { parser: tseslint.parser, svelteConfig },
    },
  },
  prettier,
  svelte.configs.prettier,
]);
```

- Put `prettier` and `svelte.configs.prettier` last, so that ESLint and Prettier do not fight.
- Do not use the `strict` typescript-eslint presets, as the TypeScript notes say.
- `svelte.configs.recommended` reports `svelte/require-each-key`, `svelte/prefer-writable-derived`, `svelte/prefer-svelte-reactivity` (a plain `Set` or `Map` in state) and `svelte/no-at-html-tags`. Disable one only with a comment that gives the reason.
- The linter cannot infer the type of a snippet parameter or a function binding setter from the component that receives it. It sees `any` and reports `no-unsafe-member-access` or `no-unsafe-assignment`. Annotate the parameter: `{#snippet actions(item: Loan)}` and `(next: string) => (first = next)`. `svelte-check` infers both and needs no annotation.
- Use `<!-- svelte-ignore code (reason) -->` only for a warning that is wrong in your case, and always give the reason in parentheses.

### Formatting

- Format with Prettier 3 and `prettier-plugin-svelte` 4. Prettier 3 does not load plugins by itself, so the project has one `.prettierrc` with the plugin and the parser override and no style option. This is the only exception to the TypeScript rule of no Prettier config file:

```json
{
  "plugins": ["prettier-plugin-svelte"],
  "overrides": [{ "files": "*.svelte", "options": { "parser": "svelte" } }]
}
```

- Keep the plugin defaults: `svelteSortOrder` is `options-scripts-markup-styles`, so a file reads as script, markup, style. `svelteIndentScriptAndStyle` is `true`.
- The plugin removed `svelteStrictMode` and `svelteBracketNewLine` in version 4. Do not set them.
- When the project also uses the Tailwind CSS plugin for Prettier, list it last in `plugins`.

### Editor

- Install the Svelte for VS Code extension, or the language server of your editor, and select the workspace TypeScript version, so that the editor and CI report the same errors ([editor of the TypeScript notes](../typescript-conventions/02-project-setup-and-tooling.md#editor)).

### Adding tools later

- `npx sv add` installs official add-ons into an existing project. Its list includes `eslint`, `prettier`, `vitest`, `playwright` and `tailwindcss`. The add-ons write SvelteKit-oriented defaults, so compare their output with this note and keep the settings of this note.

## Sources and raw notes

Pages read on 2026-11-18:

- [Svelte: TypeScript](https://svelte.dev/docs/svelte/typescript): `lang="ts"`, types only, `vitePreprocess` not needed for TypeScript since Svelte 5, the three tsconfig requirements, `generics`, `HTMLButtonAttributes`.
- [sv create](https://svelte.dev/docs/cli/sv-create): the four templates, `--types ts`. [sv check](https://svelte.dev/docs/cli/sv-check): `--tsconfig`, `--fail-on-warnings`, `--threshold`, the output formats and the whole-project limit. [sv add](https://svelte.dev/docs/cli/sv-add): the add-on list.
- [Svelte compiler reference](https://svelte.dev/docs/svelte/svelte-compiler): the `runes` option (`true` forces runes mode, including in `node_modules`, and the page points to `dynamicCompileOptions` for Vite), `experimental.async`, `css`.
- [eslint-plugin-svelte user guide](https://sveltejs.github.io/eslint-plugin-svelte/user-guide/): the flat config with `extraFileExtensions`, `projectService`, `parser: ts.parser` and `svelteConfig`, and `svelte.configs.prettier`.
- [prettier-plugin-svelte](https://github.com/sveltejs/prettier-plugin-svelte): the `plugins` entry, the `parser: svelte` override, the three options of version 4, the removed options, and compatibility (version 4 needs Prettier 3 and Svelte 5).
- Checked on 2026-11-18 in a scratch project made with `create-vite` 9.3.4 (`svelte-ts`), Svelte 5.58.0, `@sveltejs/vite-plugin-svelte` 7.3.1, Vite 8.3.8, TypeScript 6.0.3, svelte-check 4.7.8, ESLint 10.15.0, typescript-eslint 8.73.0, eslint-plugin-svelte 3.24.1, `eslint-config-prettier` 10.1.8, Prettier 3.10.1 and prettier-plugin-svelte 4.2.0:
  - The `tsconfig.app.json` block, the ESLint config and the `.prettierrc` ran with 0 errors from `svelte-check`, ESLint and `prettier --check`, and `vite build` and `tsc -p tsconfig.node.json` passed.
  - A legacy component with `export let` stopped the Vite build under `compilerOptions.runes: true`, under the function form of that option, and under `dynamicCompileOptions`. `svelte-check` reported it (`legacy_export_invalid`) under the first two and not under `dynamicCompileOptions`. The function form was not tried with a dependency that ships legacy components.
  - A sample with `$state` plus `$effect` copying state, a mutable `Set`, an unkeyed `{#each}` and `{@html}` gave `prefer-writable-derived`, `prefer-svelte-reactivity`, `require-each-key` and `no-at-html-tags`. A `div` with `onclick`, an `img` without `alt` and an unused CSS selector gave four `svelte-check` warnings.
  - An unannotated snippet parameter gave `no-unsafe-member-access`, and an unannotated function binding setter gave `no-unsafe-return` and `no-unsafe-assignment`. Annotating them cleared the errors.
  - The template's `main.ts` has `getElementById("app")!`, which `no-non-null-assertion` rejects. The checked sample replaces it with a guard that throws.
