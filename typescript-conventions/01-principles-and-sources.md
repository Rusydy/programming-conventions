# TypeScript Principles and Sources of Truth

## Summary

These principles apply to every TypeScript project. They put the compiler and the typescript-eslint presets ahead of local configuration, so that any TypeScript developer can read the code on the first day. A precedence list settles disagreements between sources, and a version policy keeps the compiler, the linter and the framework on releases that work together.

## Rules

### Principles

1. **Let the compiler prove it.** Keep `strict` on, and treat `any`, `as` and `!` as debts that need a reason. A type system is only as strong as its weakest `any` ([types and type design](04-types-and-type-design.md)).
2. **Follow the toolchain.** The compiler defaults, the typescript-eslint presets and the Prettier defaults define the baseline. Replace one only with a written reason. This is convention over configuration applied to TypeScript.
3. **Validate at the edge.** Types disappear at run time. Data from a network, a file, a form, the environment or storage is `unknown` until a schema parses it ([runtime validation](05-runtime-validation-and-external-data.md)).
4. **Model with unions.** Use discriminated unions and exhaustive `switch` statements instead of flags and optional fields that only make sense together.
5. **Write erasable syntax only.** Do not use `enum`, `namespace` with code, parameter properties or `import =`. The code then runs under Node.js type stripping and means the same in every tool ([tsconfig](03-tsconfig.md#compiler-options)).
6. **Prefer the platform.** Use the ECMAScript, Web and Node.js built-ins before a package: `structuredClone`, `Array.prototype.toSorted`, `AbortSignal.timeout`, `fetch`, the `node:` modules, type stripping and `node:test`. The same order applies to tools. Add a dependency only when it removes real complexity, and state the reason in the pull request. A tool with no built-in equivalent, such as a linter, a formatter or a schema validator, is exempt, and its choice is listed under [decisions to review](#decisions-to-review).
7. **Keep one source of truth per type.** Derive types from schemas and constants (`z.infer`, `as const`, `typeof`) instead of writing them twice.
8. **Throw errors, and return values for expected failures.** Throw only `Error` objects, and return a discriminated union when failure is a normal outcome ([error handling](09-error-handling.md)).
9. **Wait for a second use case.** Do not add generics, conditional types, abstractions or options "just in case".
10. **Name for the reader.** A name states what a thing is, not its type, and a comment explains why ([naming, comments and style](07-naming-comments-and-style.md)).

### Order of precedence

When two sources disagree, the lower number wins.

1. The ECMAScript specification, and the documented behaviour of the TypeScript compiler (handbook, tsconfig reference, release notes) and of the runtime (Node.js documentation).
2. The notes in this folder.
3. The typescript-eslint presets and their rule documentation.
4. The Google TypeScript Style Guide, where the sources above are silent.
5. Other style guides. Adopt one of their rules only when a note in this folder names it.

A framework's required shape overrides items 2 to 5 for the code that the framework dictates, such as the default exports of Next.js special files ([Next.js conventions](../nextjs-conventions/03-project-layout-and-routing.md#naming)).

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so each review stays small, and raise the rest as a separate task.
- **Stricter settings:** adopt a compiler option or a lint preset in its own change, with its errors fixed or suppressed in that change ([adopting options](03-tsconfig.md#adopting-options-in-an-existing-project), [adopting the lint config](02-project-setup-and-tooling.md#adopting-the-lint-config-in-an-existing-project)).
- **Mechanical changes** (formatting, autofixes, dependency bumps, TypeScript upgrades) go in their own commits.
- **Generated code** is exempt: `.next/types`, `next-env.d.ts`, the Prisma client and any `.d.ts` file that a tool writes.
- **Shared and team repositories:** these notes apply to every TypeScript repository you write in, not only your own. When a repository documents its own conventions, follow those first, and apply these notes to the code you write where the repository is silent.
- **JavaScript:** write every new source file in TypeScript. A tool configuration file may stay `.js` or `.mjs` where the tool does not read `.ts`.

### Decisions to review

These choices were made while writing the notes because the platform does not cover a need, or because a built-in exists and a tool was kept anyway. Each can be reversed in the place named.

| Decision | Why not the built-in | Where to change it |
| --- | --- | --- |
| Vitest for component, type and module-mocking tests, and `node:test` for other Node.js-only code, with one runner per project | `node:test` has no DOM environment and no type-test API, and the Node.js docs mark `mock.module` Early development. A project that needs Vitest for any of these uses it for all its tests. | [testing](10-testing.md#tools) |
| Zod for runtime schemas | Node.js replaces types with whitespace and checks nothing at run time, and the platform has no schema validator, so data from outside the program needs a library to check it. | [runtime validation](05-runtime-validation-and-external-data.md) |
| ESLint with typescript-eslint and Prettier | `tsc` reports type errors, not style or unsafe patterns such as floating promises, and the platform has no formatter. Both are exempt tools. | [linting](02-project-setup-and-tooling.md#linting) |
| `tsx` for scripts that need path aliases, JSX or `enum` | Node.js type stripping does not read `tsconfig.json`, so `paths` fail, and it does not run `.tsx` files. `tsx` covers what stripping lacks. | [running TypeScript on Node.js](02-project-setup-and-tooling.md#running-typescript-on-nodejs) |

### Version policy

- **TypeScript:** run the newest line that typescript-eslint supports. On 2026-10-26 that is 6.0, declared as `"typescript": "~6.0.3"`. TypeScript 7.0 ships no JavaScript compiler API yet, so typescript-eslint cannot load it ([TypeScript versions](02-project-setup-and-tooling.md#typescript-versions)).
- **Existing projects on 5.9** may stay there until their next dependency update, and then move to 6.0 in one change.
- **TypeScript 7:** move `typescript` itself to 7.x when typescript-eslint lists it as supported. Until then, run 7.x side by side only when a full type check takes more than a minute.
- **Node.js types:** `@types/node` has the same major version as the production Node.js. The Next.js notes decide that major ([versions and runtime](../nextjs-conventions/02-project-setup-and-tooling.md#versions-and-runtime)).
- **Upgrades:** move one TypeScript minor version at a time, in its own pull request. A minor release can add errors to a clean build, and its release notes list the behaviour changes ([modern TypeScript by release](12-modern-typescript-by-release.md#upgrading)).

### Working with coding agents

- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/typescript.md](../agent-rules/rules/typescript.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** the rule has a `paths` field, so TypeScript rules stay out of sessions that never touch TypeScript. Claude Code loads it when a session reads, writes or edits a `.ts`, `.tsx`, `.mts`, `.cts` or `tsconfig.json` file. A user-level rule matches its patterns against the session's primary working directory, as [the Go notes](../golang-conventions/01-principles-and-sources.md#applying-the-notes) record, so start the session inside the TypeScript repository. A brand-new repository has no TypeScript file yet, so tell the agent to read `~/.claude/rules/typescript.md` before it writes the first one.
- A project whose agents must follow these notes on other machines names this folder in its own `AGENTS.md`, because the user-level rule is installed per machine.
- Tell agents to run `npm run typecheck` and `npm run lint` before they report TypeScript changes as done, and to read the installed TypeScript version before they use a newer language feature.

## Sources and raw notes

Pages read on 2026-10-26 unless a bullet says otherwise:

- [Announcing TypeScript 7.0](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/) (2026-07-08): the native compiler, no JavaScript API in 7.0, the `@typescript/typescript6` compatibility package, new defaults. [Announcing TypeScript 6.0](https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/) (2026-03-23). [Announcing TypeScript 7.1 Beta](https://devblogs.microsoft.com/typescript/announcing-typescript-7-1-beta/) (2026-10-20): the new API, release candidate in about a month.
- npm registry on 2026-10-26: `typescript` dist-tags `latest` 7.0.2, `rc` 7.0.1-rc, `beta` 7.1.0-beta. Weekly downloads by version (`api.npmjs.org/versions/typescript/last-week`, 2026-10-16 to 2026-10-22): 5.9 has 43.3 percent, 6.0 has 20.1 percent, 7.0 has 13.7 percent, and the 5.x line has 59.7 percent in total.
- [typescript-eslint dependency versions](https://typescript-eslint.io/users/dependency-versions): TypeScript `>=4.8.4 <6.1.0`, ESLint `^8.57.0 || ^9.0.0 || ^10.0.0`. The `typescript-eslint@8.72.0` package declares the same peer ranges.
- [TypeScript page of the Next.js documentation](https://nextjs.org/docs/app/api-reference/config/typescript) (updated 2026-08-25): "TypeScript 7 does not currently provide the JavaScript compiler API". `create-next-app@16.4.3` writes `typescript ^5` and `@types/node ^20`.
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html).
- Release notes of TypeScript 5.2 to 5.9 (`TypeScript-Website` repository): each minor release has a section on breaking or notable behaviour changes.
- Loading of path-scoped user-level rules: the Claude Code memory documentation, as the [Go notes](../golang-conventions/01-principles-and-sources.md#applying-the-notes) record it (read on 2026-10-26).
- Pages read on 2026-11-10 (Node.js v26.13.0 documentation): the [test runner](https://nodejs.org/api/test.html) page (the runner is Stable, `mock.module` is Early development, and `.test.ts` files match only while type stripping is on) and the [TypeScript](https://nodejs.org/api/typescript.html) page (type stripping history, erasable syntax only, no `tsconfig.json` or `paths`).
