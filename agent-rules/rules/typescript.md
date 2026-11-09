---
paths:
  - "**/*.ts"
  - "*.ts"
  - "**/*.tsx"
  - "*.tsx"
  - "**/*.mts"
  - "*.mts"
  - "**/*.cts"
  - "*.cts"
  - "**/tsconfig.json"
  - "tsconfig.json"
---
# TypeScript conventions (every project)

Write type-safe, readable TypeScript. Follow the compiler's, the toolchain's and the language's conventions instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `typescript-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-10-26; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatting, autofixes, dependency bumps, TypeScript upgrades) in their own commits.
- When sources disagree, the order is: the ECMAScript specification and the documented behaviour of the compiler and Node.js; this file and the notes; the typescript-eslint presets; the Google TypeScript Style Guide where the rest is silent. A framework's required shape overrides these for the code it dictates, such as the default exports of Next.js special files.
- If the repository documents its own conventions, follow them first. Where it is silent, apply this file to the code you write.
- Generated files are exempt: `.next/types`, `next-env.d.ts`, the Prisma client and any `.d.ts` file that a tool writes.
- Write every new source file in TypeScript. A tool configuration file may stay `.js` or `.mjs` where the tool does not read `.ts`.
- Code inside a Next.js app also follows the Next.js conventions in the `nextjs-conventions` folder of the programming-conventions repository.
- Prefer the platform: `structuredClone`, `toSorted`, `AbortSignal.timeout` and `fetch` come before a utility library. Add a dependency only when it removes real complexity, and say why in the pull request.
- Before you report TypeScript changes as done, run `npm run typecheck` and `npm run lint`. Before you use a newer language feature, read the installed version: `node -p "require('typescript').version"`.

## Version and toolchain

- Install TypeScript with a tilde range: `npm install -D typescript@~6.0.3`. A bare install gets 7.0.2 today, because the npm `latest` tag points there, and TypeScript 7.0 has no JavaScript API that typescript-eslint can load.
- Stay on 6.0 while typescript-eslint supports `>=4.8.4 <6.1.0`. Move `typescript` to 7.x only when the typescript-eslint dependency-versions page lists 7.x as supported, and remove the side-by-side aliases in the same change.
- Run TypeScript 7 side by side only when a full `tsc` run takes more than a minute.
- An existing project on 5.9 may stay there until its next dependency update, and then moves to 6.0 in one change.
- Upgrade one minor version at a time, in its own pull request, after reading that release's breaking-change notes.
- `@types/node` has the major version of the production Node.js, in `engines` and in `.nvmrc`. `create-next-app` writes `^20`; change it to the runtime's major. Keep `@types/react` and `@types/react-dom` on the React major. Install no `@types/*` package for a library that ships its own types.

## Scripts and checks

- Scripts: `typecheck` is `tsc --noEmit` (Next.js: `next typegen && tsc --noEmit`), `lint` is `eslint`, `format:check` is `prettier --check .`, `test` is `vitest run`, and `ci` is `npm run typecheck && npm run lint && npm run format:check && npm test`. A Next.js project adds `next build` to `ci`.
- Run the checks in this order: type check, lint, format check, tests, build. CI runs `npm run ci` and nothing else.
- The type check includes the test files.

## tsconfig

- One `tsconfig.json` describes one environment. A Next.js app keeps the single file that `create-next-app` writes. Give a folder its own `tsconfig.json` only when its code runs in another environment, such as `scripts/` under `module: nodenext`, and exclude that folder from the root file.
- Keep `strict: true` written out. Every project also sets these six options: `noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns`, `noFallthroughCasesInSwitch`, `verbatimModuleSyntax` and `erasableSyntaxOnly`.
- Next.js: start from the file that `create-next-app@16.4.3` writes. Keep its generated values and `include` entries, add the six options, and use `"paths": { "@/*": ["./*"] }` with no `baseUrl`. Add no `types` entry: the generated `next-env.d.ts` loads the Next.js types, which reference the Node.js types and declare `*.css`, `*.sass` and `*.scss` modules.
- Node.js: `"module": "nodenext"`, `"types": ["node"]`, `"target": "es2024"`, a `lib` that matches the runtime, `"noEmit": true`, `"skipLibCheck": true`, `"allowImportingTsExtensions": true` (a project that emits JavaScript uses `rewriteRelativeImportExtensions` instead) and the six options. Set `"type": "module"` in `package.json`. Copy the values from the tsconfig note; do not add `@tsconfig/node24`.
- Leave these off: `exactOptionalPropertyTypes`, `noPropertyAccessFromIndexSignature`, `noUnusedLocals` and `noUnusedParameters` (ESLint reports unused code), `@tsconfig/strictest`, `checkJs`, `baseUrl`, `experimentalDecorators`, and every option that TypeScript 6.0 deprecated.
- TypeScript 6.0 deprecates `target: es5`, `moduleResolution: node10`, `classic`, `baseUrl`, `outFile`, `downlevelIteration`, `module` set to `amd`, `umd`, `system` or `none`, and `esModuleInterop` or `alwaysStrict` set to `false`. Each is an error until `"ignoreDeprecations": "6.0"` is set, and TypeScript 7.0 rejects them all.
- With a `tsconfig.json` in the folder, `tsc file.ts` stops with TS5112. Run `tsc -p .`, or pass `--ignoreConfig`.
- To adopt an option in an existing project, turn on first the options that report no errors (`noImplicitOverride`, `noFallthroughCasesInSwitch`, `erasableSyntaxOnly`). Then add one option per change, in this order: `noImplicitReturns`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`. Fix the errors in the same change, because TypeScript has no baseline mechanism.

## Linting and formatting

- ESLint flat config: add typescript-eslint's `recommendedTypeChecked` and `stylisticTypeChecked`, set `parserOptions.projectService` to `true`, and set `@typescript-eslint/no-non-null-assertion` to `error`. Put `eslint-config-prettier/flat` last. A Next.js project keeps `eslint-config-next` before them; a project without Next.js starts from `js.configs.recommended`.
- Do not use the `strict` presets.
- Disable a rule only with a comment that gives the reason. `@ts-ignore` and `@ts-nocheck` are banned; write `@ts-expect-error` with a description.
- Format with Prettier 3 and its default options, with no config file, and never by hand. An existing project keeps its settings until its own move to Prettier 3.
- To adopt the lint config in an existing project, run `npx eslint --fix --suppress-all`, commit the `eslint-suppressions.json` it writes, and run `npx eslint --prune-suppressions` after each clean-up. ESLint suppresses only rules set to `error`.

## Node.js and the editor

- Run a script with `node script.ts`. Type stripping is on by default from Node.js 22.18 and 24.3, and stable from 24.12 and 25.2. Node.js removes the types without checking them, so `tsc --noEmit` is the check.
- Stripping needs erasable syntax, `.ts` extensions in relative imports and `import type` for types. It ignores `tsconfig.json`, so `paths` do not work, and it does not run `.tsx`.
- Use `tsx` when a script needs what stripping lacks: path aliases, JSX or `enum`. Do not add `ts-node`. A script that runs under `tsx` uses the bundler settings in `tsconfig.json`.
- In the editor, select the workspace TypeScript version (VS Code: "TypeScript: Select TypeScript Version", then "Use Workspace Version") so that the editor and CI report the same errors.

## Types

- Use `unknown` for a value of unknown shape, and narrow it with `typeof`, `instanceof`, `in`, a type guard or a schema. Do not write `any`. When it is unavoidable, such as a partial mock in a test, disable the rule on that line and give the reason in the same comment.
- Assign the result of `JSON.parse`, `response.json()` and `Object.fromEntries(formData)` to an `unknown` variable at once, then validate it.
- Never use `{}`, `Object`, `Function`, `String`, `Number` or `Boolean` as types. Use `unknown`, `object`, `Record<string, T>`, a function signature or the lowercase primitive.
- Use `interface` for object shapes, and `extends` to build on them. Use `type` for unions, intersections, tuples, function types, mapped and conditional types, and names for primitives.
- Mark an optional property or parameter with `?`, not `| undefined`. Put no `| null` or `| undefined` inside a type alias; add it where the alias is used.
- Annotate an object literal with its type, or use `satisfies`. Do not write `as Foo`.
- Write `T[]` and `readonly T[]`, never `Array<T>`. Omit an annotation that inference already knows.
- Derive types instead of copying them: an `as const` array with `(typeof LIST)[number]` for a union; `satisfies Record<Union, Label>` for a lookup table; `z.infer` for a schema; `ReturnType`, `Parameters`, `Awaited` and `typeof` for functions and values. Use the built-in utility types (`Pick`, `Omit`, `Partial`, `Required`, `Readonly`, `Record`, `NonNullable`, `Extract`, `Exclude`, `NoInfer`) before you write a mapped type.
- Model alternatives with a discriminated union that has a literal `kind`. Handle it in a `switch` whose `default` calls `assertNever(value: never): never`, so that a new variant fails the build at each `switch` that misses it.
- Do not declare `enum`. Use a string-literal union derived from an `as const` array.
- For a failure that is a normal outcome, return a `Result` union: `{ ok: true; value: T } | { ok: false; error: E }`. Do not add a result library.
- `undefined` means absent in your own code: optional properties, `Map.get`, `Array.prototype.find`. `null` means an explicit "no value" that crosses a boundary: JSON, SQL `NULL`, DOM APIs, and the initial value of React state or a ref. Do not use both for one field; convert at the boundary.
- Compare with `===` and `!==`. The one exception is `value == null`. Prefer `??` and `?.` to `||` and `&&` chains.
- Do not use `as` to silence the compiler; narrow with a guard, a schema or a check. `as const` and `satisfies` are fine. Use `as unknown as T` only in a test double, with a comment. Never use the non-null assertion `!`: handle the missing value, or throw an error that names it.
- Add a type parameter only when a function works on several types. Name it `T`, `K`, `V` or a short UpperCamelCase word, and constrain it with `extends`. Do not write a generic that appears only in the return type (`get<T>(url): Promise<T>`); let a parameter, such as a schema, carry the type. Write a conditional, mapped or template-literal type only to remove duplication that exists today, with a comment and a type test.
- Keep money as an integer count of minor units with a currency code (`amountMinor: number`, `currency: "IDR"`). Use `bigint` only when an amount can exceed `Number.MAX_SAFE_INTEGER`. Do arithmetic on rates and interest with `decimal.js`, and round once. Send amounts as minor units or decimal strings, never as JSON floating-point numbers. Format for display with `Intl.NumberFormat`.
- Use `Date` and ISO 8601 UTC strings (`toISOString()`) for instants, and convert to a time zone only for display, with `Intl.DateTimeFormat`. Use `Temporal` in server code once the production Node.js is 26 or later. Keep browser code on `Date` and `Intl` until the browser matrix supports `Temporal`.

## Runtime validation and external data

- Hold every external value as `unknown` until a schema accepts it: an upstream API or CMS response, a request body, search parameters, `FormData`, cookies and headers, `localStorage`, `postMessage` data, a JSON file and the environment. Never write `as Foo` on external data.
- Validate once, where the data enters. In the same place, map the wire shape to the domain shape: rename fields, turn `null` into an absent property and parse dates.
- Use Zod (`import { z } from "zod"`) for every schema, on the server and in the browser. Use `zod/mini` when a client bundle must shrink. Declare a schema beside the code that reads the data, and export `z.infer<typeof schema>` instead of writing the same shape as an `interface`. Use `z.unknown()` for an opaque value, never `z.any()`.
- Call `parse` when invalid data is a fault: it throws a `ZodError`. Call `safeParse` when invalid data is a normal outcome, such as user input.
- Pass the schema to a generic helper, such as `fetchJson<T>(schema: z.ZodType<T>, url: string, init?: RequestInit)`, so that the schema carries the type. Give every network call `signal: AbortSignal.timeout(5_000)`.
- Forms: call `safeParse`, and return `z.flattenError(error).fieldErrors` to the form. Do not call `error.flatten()` or `error.format()`, which Zod 4 deprecates. Use `z.flattenError()`, `z.treeifyError()` or `z.prettifyError()` (for a readable log line).
- Environment: parse `process.env` once, in one `server-only` module (for example `lib/env.ts`), and export the typed result. Fail at start-up with the schema's error. No other file reads `process.env`, with one exception: Next.js inlines a `NEXT_PUBLIC_` variable only where the code writes `process.env.NEXT_PUBLIC_NAME` literally. Read those names one by one in their own module, and never pass `process.env` to a schema in code that reaches the browser.

## Modules and imports

- Use `import` and `export` only. Do not write `require()`, `import x = require()` or `export =`.
- Mark a type-only import with `type`, as in `import { fetchLoans, type Loan } from "@/lib/loans"`. Let the editor organise the imports; do not sort them by hand. Keep side-effect imports for styles and polyfills.
- In code that Node.js runs directly, write the `.ts` extension in relative imports (`./format.ts`), use the `node:` prefix for built-in modules, and import JSON with `with { type: "json" }`.
- Use named exports. Use a default export only where a framework or a tool requires one: Next.js special files, and tool configuration such as `next.config.ts`, `eslint.config.mjs` and `vitest.config.ts`. A module that already has a default export keeps it until a change rewrites the module.
- Do not write `export let`, and do not wrap functions in an object or a class to give them a namespace. Export only what another module uses.
- No barrel files: do not write an `index.ts` that re-exports a folder. Import from the module that defines the name.
- Import a file in the same folder as `./name`, one folder up as `../name`, and anything further away through the `@/` alias. Never write `../../..`.
- A Node.js project without a bundler cannot use `paths`. Use subpath imports instead: `"imports": { "#app/*": "./src/*" }` in `package.json`, imported as `#app/util.ts`. Use `#app/*` rather than `#/*` until every runtime and tool in the project accepts `#/*`.
- No circular imports. When two modules need each other, move the shared part into a third module. Load code on demand with `import()` or `next/dynamic`.

## Naming, comments and style

- UpperCamelCase for types, interfaces, classes and React components (`LoanStatus`, `HttpError`, `NameField`). lowerCamelCase for variables, parameters, functions, methods and properties (`amountMinor`, `describePayment`). CONSTANT_CASE for module-level constants that never change (`LOAN_STATUSES`, `API_URL`). A value that a function creates on each call is lowerCamelCase, even when it is `const`. kebab-case for files and folders (`header-nav-bar.tsx`).
- Treat acronyms as words: `userId`, `parseUrl`, `HttpError`. Write `ID` or `URL` in capitals only where a platform name needs it, such as `XMLHttpRequest`.
- Name by meaning, not by type. No `I` prefix, no `Interface`, `Impl` or `Type` suffix, and no Hungarian notation.
- No underscore prefix or suffix, and never a variable named `_`. Skip an array element with an extra comma (`const [first, , third] = list`).
- Name a boolean like a question: `isLoading`, `hasError`, `canEdit`.
- Spell names in full (`customerId`, not `cstmrId`). A short name is fine in a scope of ten lines or fewer.
- Name a file after its main export. Use `.tsx` only for a file with JSX, `.test.ts` for tests, `.test-d.ts` for type tests, and `.d.ts` only for ambient declarations.
- Give every exported function, type and constant whose purpose is not obvious from its name a doc comment (`/** ... */`). Use `//` for comments about the implementation.
- Do not repeat types in a doc comment. Drop `@param` and `@returns` lines that only restate the name and type; keep those that add units, limits or side effects.
- Explain why, not what. Record constraints, trade-offs and surprising behaviour. Delete commented-out code.
- Write `TODO(owner): ...` with an owner or a ticket. Mark deprecated API with `@deprecated` and name its replacement.
- Write comments and doc comments in English with American spelling (`normalize`, `color`). Leave existing comments as they are.
- Declare with `const`. Use `let` only for a variable you reassign. Never use `var`.
- Handle the failure case first and return, so that the normal path stays unindented. Do not write `else` after a `return`.
- Loop with `for...of` or array methods. Never use `for...in` over an array, and do not write an index loop where `for...of` is enough.
- Build strings with template literals. Write `Number.parseInt(text, 10)` with the radix, and write large literals with separators (`5_000`).
- Declare one variable per statement. Use destructuring when it makes the code shorter and clearer.
- Never use `eval`, `new Function`, or a string passed to `setTimeout`.

## Functions, classes and async

- Wait for a second use case: add no generic, conditional type, abstraction or option before one exists.
- Declare named functions with `function`, including React components. Use an arrow function for a callback or a short inline function.
- Take at most three positional parameters. For more, or for optional ones, take one options object with its own `interface`, and read it by destructuring with defaults in the pattern.
- Do not add a boolean parameter that switches behaviour. Name it as an option (`dryRun`), or write two functions.
- Let inference work inside components, handlers and local functions. Write the return type of an exported function in a data-access or shared `lib/` module.
- Use overloads only when the return type depends on the parameter type. Otherwise use a union or a generic.
- Never change a parameter or a shared object. Return a new value with `toSorted`, `toSpliced`, `with`, spreading or `structuredClone`, rather than `sort`, `splice`, `reverse` or assignment.
- Mark a parameter that you only read as `readonly` (`readonly string[]`).
- Handle the empty case of an indexed read. With `noUncheckedIndexedAccess`, destructure the first item and test it.
- Prefer functions and plain objects. Use a class only for an `Error` subclass and for an object that owns a resource and its lifecycle.
- Do not use parameter properties (`constructor(private service: Service)`); declare the field and assign it. Mark a field that never changes `readonly`, and an overriding method `override`.
- Do not write a class that holds only static members. Do not build an inheritance chain deeper than one level; compose objects instead.
- Write `async` and `await`. Do not mix `.then()` chains with `await` in one function.
- Handle every promise: `await` it, return it, or mark a deliberate fire-and-forget call with `void` and handle its errors inside the called function.
- Do not pass an `async` function where a void-returning callback is expected, such as an event handler. Call it from a normal handler: `onClick={() => void save()}`.
- Start independent requests together with `Promise.all`, or with `Promise.allSettled` when a partial result is acceptable. Do not `await` inside a loop whose iterations are independent.
- Give every network call a timeout. Every `async` function contains an `await`; when there is nothing to await, return the promise from a normal function.
- Wrap a callback API in `new Promise`, and never wrap a function that already returns a promise. Reject only with an `Error`.

## Errors

- Throw and reject only `Error` objects. Create them with `new`, and keep the original error as the cause: `new Error("Cannot save order 42", { cause: error })`. State what the code was doing and to which value.
- Throw for faults: an upstream failure, a broken invariant, or data that must be valid and is not. Do not throw for a normal outcome; return a result.
- Write an error subclass only when callers branch on the condition or need data from it. Set `name`, pass `options` to `super` so that `cause` survives, and declare extra fields `readonly`. Test with `instanceof`, never with the message or the name. Keep the set flat.
- In `catch (error)` the value is `unknown`. Narrow it with `instanceof Error`, or convert it with a `toError` helper. Do not annotate it with `any`.
- Catch only what the code can handle. Do not catch an error only to log it and throw it again. Keep the `try` block to the statements that can throw. Never leave a `catch` empty; when ignoring the error is correct, say why in a comment inside the block.
- At a boundary (a Route Handler, a Server Function, a script's `main` function or an error boundary), log the error once, with its whole `cause` chain. Return a client-safe message; never send the `message` of an unexpected error to the client.
- A new Route Handler returns errors as RFC 9457 problem details: `application/problem+json` with `title`, `status` and `detail`. An existing API keeps its body, and a published body changes only with a new API version.
- The Next.js `error.tsx` boundary receives an `unknown` error. Narrow it before use.

## Testing

- Use Vitest for unit and component tests, and Playwright for end-to-end tests in `e2e/`.
- Put a test beside the code it tests (`loan.test.ts` next to `loan.ts`), and a type test in a `*.test-d.ts` file.
- Import the test API from `vitest`. Do not turn on `globals`.
- Include the test files in `tsconfig.json`, so that a type error in a test fails the build. The test script is `"test": "vitest run"`.
- Name a `describe` block after the unit, and an `it` block as a sentence about its behaviour. Use `it.each` when cases share their logic: give the table an `interface`, and put a `name` in every case.
- Build fixtures with a typed helper that takes `Partial<T>` overrides, such as `buildLoan(overrides: Partial<Loan> = {})`, not with copies of a literal.
- Assert an error by its class and data, not by its message: `rejects.toMatchObject({ status: 404 })`.
- Control time with `vi.useFakeTimers()`, and restore it in `afterEach`. Never wait on a real `setTimeout`.
- Test your own logic and your own types, not what a library or the framework already guarantees.
- Prefer the real implementation when it is cheap. Give a double the type of what it replaces: pass a typed implementation to `vi.fn`. When a test needs part of a large dependency, write one cast with a comment that says what is left out (`{ fetchLoans } as unknown as LoanApi`). Do not use `any` in tests; when it is unavoidable, disable `no-explicit-any` on that line with a reason. Mock a module with `vi.mock` only at a boundary: the network, the clock or the file system.
- Test the types of exported generic helpers, schema-derived types, and conditional or mapped types with `expectTypeOf` in a `*.test-d.ts` file. Run them with `vitest run --typecheck`. Pin `vitest` to an exact version while you use type tests, because Vitest warns that type testing is experimental and that breaking changes may not follow SemVer. Write `// @ts-expect-error` with a description, and list the `*.test-d.ts` files in `test.include`, so that a typo below the comment fails the test.

## React

- Declare components with `function`. Type the props in the signature with an `interface` named after the component (`ButtonProps`), or inline for one or two props. Do not use `React.FC`, `FC` or `FunctionComponent`.
- Do not annotate a return type with `JSX.Element`: the React 19 types expose JSX as `React.JSX` only. Let inference type the return value.
- Type `children` as `React.ReactNode`. For a component that wraps an HTML element, extend `ComponentProps<"button">` (or the props of the element it wraps).
- In React 19, `ref` is an ordinary prop of a function component. Do not use `forwardRef` in new components.
- Give an optional prop its default in the destructuring pattern.
- Let `useState` infer from its initial value. Give a type argument when the value is `null` or an empty collection: `useState<User | null>(null)`, `useState<Loan[]>([])`. Type a ref by its element: `useRef<HTMLInputElement>(null)`. Type reducer actions as a discriminated union.
- Create a context with `createContext<T | null>(null)`, and read it through a hook that throws when the value is `null`, so that consumers receive `T`.
- Do not add `useMemo`, `useCallback` or `React.memo` for typing reasons, and do not add them without a profiler result.
- Write inline event handlers without a type. Type an extracted handler with its element's event type (`ChangeEvent<HTMLInputElement>`), and read the value from `event.currentTarget`. Type a style prop as `React.CSSProperties`.
- Name a callback prop `onSomething`, and the function that implements it `handleSomething`.
- Next.js: type route props with the generated `PageProps`, `LayoutProps` and `RouteContext` helpers; `params` and `searchParams` are promises. Pass a Client Component only props that can cross the server boundary: plain data, not functions or class instances, except Server Functions. Type a Server Function by the `FormData` it reads, parsed with a schema, and by the state it returns, an `interface`. Put `'use client'` only on a file that uses state, effects, event handlers or browser APIs.

## Modern TypeScript

- Write the modern idiom, and replace the old one when you touch its line. For example: an `as const` union for `enum`; ES `import` and `export` for `import =`, `export =` and a `namespace` with code; `value as Type` or a type guard for `<Type>value`; standard decorators for `experimentalDecorators`; `@ts-expect-error` with a description for `@ts-ignore`; `unknown` for `any`; `interface` for an object `type` alias; an inferred type predicate for a hand-written guard in `filter` (TypeScript 5.5); `with { type: "json" }` for `assert { type: "json" }`, which is an error since 6.0; `toSorted`, `toSpliced` and `with` for shared arrays; `lib: ["dom"]` instead of `["dom", "dom.iterable"]` (6.0); type stripping or `tsx` instead of `ts-node`.
- `moduleResolution: node` becomes `bundler` or `nodenext`, and `baseUrl` is replaced by `paths` with the folder in each entry.
- A `// @ts-expect-error` covers only the next line, and TypeScript 7.0 can move an error to another line. Fix the type where you can.
- Upgrading from 5.9 to 6.0: set `"typescript": "~6.0.3"`, set `types` explicitly in a Node.js project, set `rootDir` when the project emits files, remove `baseUrl`, and use `"ignoreDeprecations": "6.0"` only as a short bridge. Compare the type-error and lint counts before and after each upgrade. Do not keep `--stableTypeOrdering` on, because it can slow the check by up to 25 percent.
- Moving from 6.0 to 7.x waits for typescript-eslint's support (see Version and toolchain). Run `tsc` 7 side by side first and compare its errors with the 6.0 run, because code that is clean under 6.0 can still fail under 7.0.
