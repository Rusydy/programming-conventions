# TypeScript Modules and Imports

- Responsibility: engineering
- Area/system: typescript
- Keywords: ES modules, import type, verbatimModuleSyntax, named exports, default exports, barrel file, index.ts, export star, path alias, paths, subpath imports, imports field, package.json, node prefix, .ts extension, side-effect import, circular dependency, dynamic import, JSON import attributes, require
- Aliases: modul TypeScript, import dan export TypeScript, barrel file, alias path @/, circular import, impor tipe, export default vs named export, subpath imports
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [tsconfig](03-tsconfig.md), [naming, comments and style](07-naming-comments-and-style.md), [Next.js layout and routing](../nextjs-convention/03-project-layout-and-routing.md).

## Summary

Write ES modules with named exports, mark type-only imports with `type`, and import across folders through the `@/` alias instead of long relative paths. Import from the module that defines a name, not through a barrel file.

## Rules

### Imports

- Use `import` and `export` only. Do not call `require()` and do not write `import x = require()`. The `recommended` preset reports `require()` (`no-require-imports`), and `erasableSyntaxOnly` rejects the `import =` form.
- Mark an import that carries only types with `type`: `import type { Loan } from "@/lib/loans"`, or `import { fetchLoans, type Loan } from "@/lib/loans"`. `verbatimModuleSyntax` makes the compiler enforce it, and it matches what bundlers and Node.js type stripping need.
- Let the editor's organise-imports action order the imports. Do not sort them by hand.
- Keep a side-effect import (`import "./globals.css"`) for styles and polyfills. TypeScript 6.0 checks that its path resolves (`noUncheckedSideEffectImports`), and Next.js already declares `*.css`, `*.sass` and `*.scss` ([tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application)).
- In code that Node.js runs, name the file with its extension (`./format.ts`), and import built-in modules with the `node:` prefix (`node:fs/promises`). Import a JSON file with the import attribute: `import data from "./data.json" with { type: "json" }`.

### Exports

- Use named exports. Use a default export only where a framework requires it: the Next.js special files and the tool config files (`next.config.ts`, `eslint.config.mjs`, `vitest.config.ts`). A module that already has a default export keeps it until a change rewrites the module ([Next.js naming](../nextjs-convention/03-project-layout-and-routing.md#naming)).
- Do not write `export let`. A mutable binding is hard to follow through re-exports. Export a function that returns the current value.
- Do not wrap functions in an object or a class only to give them a namespace (`export const Utils = { ... }`). Export each function and constant on its own.
- Export only what another module uses.
- Do not create barrel files, that is, an `index.ts` that re-exports a folder. Import from the module that defines the name. A barrel pulls every module behind it into the compiler and the bundler, and it hides circular imports. Next.js documents `optimizePackageImports` for packages that export hundreds or thousands of modules, because they hurt development and production performance.

### Import paths

- Import a file in the same folder as `./name`, and a file one folder up as `../name`. Import anything further away through the `@/` alias, which `create-next-app` sets up (`"paths": { "@/*": ["./*"] }`). Do not write `../../..`.
- Existing code: switch relative imports that climb two or more folders to the `@/` alias in the lines you change.
- A Node.js project without a bundler cannot use `paths`: Node.js ignores `tsconfig.json`, so an alias fails at run time. Use subpath imports instead. Their names start with `#`, and `package.json` maps them:

```json
{
  "name": "example",
  "type": "module",
  "imports": { "#app/*": "./src/*" }
}
```

```ts
import { double } from "#app/util.ts";
```

- TypeScript 6.0 and Node.js 24 also accept the bare prefix `#/*`, which gives the same look as `@/`. Node.js 22.14.0 rejected it and TypeScript 5.9.3 did not resolve it, so use `#app/*` until every runtime and tool in the project accepts `#/*`.
- Name files in kebab-case ([naming](07-naming-comments-and-style.md#naming)).

### Structure

- Do not create circular imports. When two modules need each other, move the shared part into a third module. ESLint does not report cycles in the current config, so check for them in review.
- Load code on demand with `import()` or `next/dynamic` ([Next.js lazy loading](../nextjs-convention/04-server-and-client-components.md#lazy-loading)). Do not use `require()` for that.

## Sources and raw notes

Pages read on 2026-10-26:

- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html): exports (named exports, no default exports, no mutable exports, no container classes), import and export type.
- [Announcing TypeScript 6.0](https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/): subpath imports that start with `#/`, and `noUncheckedSideEffectImports` on by default.
- [Node.js TypeScript documentation](https://nodejs.org/api/typescript.html) (v26.12.1): mandatory file extensions, `import type`, and `tsconfig` `paths` that are not transformed (subpath imports starting with `#` are the closest feature).
- [`optimizePackageImports`](https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports): "Some packages can export hundreds or thousands of modules, which can cause performance issues in development and production."
- [typescript-eslint `recommended-type-checked` rules](https://typescript-eslint.io/users/configs) in `typescript-eslint@8.72.0`: `no-require-imports`.
- Checked in a scratch project on 2026-10-26: with `package.json` `imports` set to `#app/*`, `node --experimental-strip-types` ran a file that imported `#app/util.ts` on Node.js 22.14.0 and printed `42`, and TypeScript 5.9.3 resolved it under the Node.js baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nodejs-project). The prefix `#/*` failed in both (`ERR_INVALID_MODULE_SPECIFIER` and TS2307). In the same project, `#/util.ts` ran on Node.js 24.22.1 and type-checked under TypeScript 6.0.3 and 7.0.2, and `#app/util.ts` worked on both Node.js versions and under all three TypeScript versions. With only `rewriteRelativeImportExtensions`, a `.ts` subpath import failed with TS2877.
- Import counts come from the TypeScript syntax tree of both repositories (excluding `node_modules`, `.next` and `public`), run on 2026-10-26.
