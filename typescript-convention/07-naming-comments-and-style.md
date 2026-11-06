# TypeScript Naming, Comments and Code Style

- Responsibility: engineering
- Area/system: typescript
- Keywords: naming, UpperCamelCase, lowerCamelCase, CONSTANT_CASE, kebab-case, acronyms, interface prefix, underscore prefix, TSDoc, JSDoc, doc comments, TODO owner, comment language, American spelling, Prettier, const, let, var, equality, early return, template literals
- Aliases: penamaan TypeScript, TypeScript naming conventions, TypeScript comments, gaya kode TypeScript, camelCase PascalCase, komentar kode, bahasa komentar, TypeScript code style
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [tsconfig](03-tsconfig.md), [modules and imports](06-modules-and-imports.md), [types and type design](04-types-and-type-design.md), [Next.js layout and routing](../nextjs-convention/03-project-layout-and-routing.md#naming).

## Summary

Names carry the meaning that types cannot, so write descriptive names in the casing of the table below. Document the exported API with doc comments, explain why in other comments, and write comments in English. Prettier decides the layout, and nobody formats by hand.

## Rules

### Naming

| Kind | Style | Example |
| --- | --- | --- |
| Types, interfaces, classes, React components | UpperCamelCase | `LoanStatus`, `HttpError`, `NameField` |
| Variables, parameters, functions, methods, properties | lowerCamelCase | `amountMinor`, `describePayment` |
| Module-level constants that never change | CONSTANT_CASE | `LOAN_STATUSES`, `API_URL` |
| Files and folders | kebab-case | `header-nav-bar.tsx`, `loan-store.ts` |

- Use CONSTANT_CASE only for a value that is created once, at module level: a primitive, an `as const` list or a lookup table. A value that a function creates on each call is lowerCamelCase, even when it is `const`.
- Treat an acronym as a word: `userId`, `parseUrl`, `HttpError`, `loadHttpUrl`. Write `ID` or `URL` in capitals only where a platform name requires it, such as `XMLHttpRequest`.
- Name by meaning, not by type. Do not prefix an interface with `I`, and do not add the suffixes `Interface`, `Impl` or `Type`. Do not use Hungarian notation.
- Do not start or end a name with an underscore, and do not name a variable `_`. Declare a callback with fewer parameters, or skip array elements with an extra comma (`const [first, , third] = list`).
- Name a boolean like a question: `isLoading`, `hasError`, `canEdit`.
- Write names that a new reader understands. Do not abbreviate by deleting letters (`customerId`, not `cstmrId`). A name in a scope of ten lines or fewer may be short (`i`, `item`).
- Name a file after the main thing it exports. Use `.tsx` only for a file with JSX, `.test.ts` for tests and `.d.ts` only for ambient declarations.

### Comments

- Write a doc comment (`/** ... */`) for every exported function, type and constant whose purpose is not obvious from its name. Use `//` for comments about the implementation.
- Do not repeat types in a doc comment. Leave out `@param` and `@returns` lines that only restate the name and the type, and keep the ones that add information (units, limits, side effects).
- Explain why, not what. Record constraints, trade-offs and surprising behaviour. Delete commented-out code, because Git keeps the history.
- Write `TODO(owner): ...` with an owner or a ticket. Mark deprecated API with `@deprecated` and the replacement.
- Write comments and doc comments in English, with American spelling. The language, the standard library and the DOM documentation use American spelling, and the identifiers follow it (`normalize`, `color`), so a comment that spells a word like its identifier turns up in the same search. Existing comments stay as they are.

```ts
/**
 * Formats a loan amount for display.
 *
 * @param amountMinor Amount in minor units. IDR has two decimal places,
 *   so 150000 is Rp 1.500,00.
 */
export function formatAmount(amountMinor: number): string {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
  }).format(amountMinor / 100);
}
```

### Code style

- Let Prettier decide layout, quotes, semicolons and trailing commas ([setup](02-project-setup-and-tooling.md#formatting)). Never format by hand and never argue about layout in a review.
- Declare with `const`. Use `let` only for a variable that you reassign. Never use `var`. The presets enforce both (`prefer-const`, `no-var`).
- Compare with `===` and `!==`. The exception `value == null` is covered in [null and undefined](04-types-and-type-design.md#null-and-undefined).
- Handle the failure case first and return, so that the normal path stays unindented. Do not write `else` after a `return`.
- Loop with `for...of` or array methods. Never loop over an array with `for...in` (`no-for-in-array`), and do not write an index loop when `for...of` is enough.
- Build strings with template literals. Write `Number.parseInt(text, 10)` with the radix, and write large literals with separators (`5_000`).
- Declare one variable per statement. Use destructuring when it makes the code shorter and clearer.
- Do not use `eval` or `new Function`, and do not pass a string to `setTimeout`. `no-implied-eval` reports `new Function` and string timers.

## Sources and raw notes

Pages read on 2026-10-26:

- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html): identifier styles and `CONSTANT_CASE` for module-level constants, acronyms as words, no `I` prefix, no underscore prefix or suffix and no `_` identifier, descriptive names with the ten-line exception, JSDoc against ordinary comments, no types in `@param`, comments that add information.
- [Next.js layout and routing](../nextjs-convention/03-project-layout-and-routing.md#naming): kebab-case file names.
- The `eslint-recommended` part of the typescript-eslint presets (`no-var`, `prefer-const`) and `no-for-in-array` and `no-implied-eval` in `recommended-type-checked` (`typescript-eslint@8.72.0`).
- The Go notes made the same decision for code comments ([comments](../golang-conventions/05-naming-comments-and-style.md#doc-comments-and-other-comments)).
- The `formatAmount` example compiled and passed the lint config of [setup](02-project-setup-and-tooling.md#linting) in a scratch project (TypeScript 5.9.3).
