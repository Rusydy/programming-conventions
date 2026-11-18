# Svelte Project Layout and Naming

## Summary

Group code by feature. A feature folder holds its components, its `.svelte.ts` state modules, its types and its tests side by side. Name every file in kebab-case, name every component in UpperCamelCase at the import, and import a component as a default import with its `.svelte` extension. Keep the order inside a component file the same everywhere, and let Prettier enforce it.

## Rules

### Where code lives

- Put the application code in `src/`. The entry file `main.ts` mounts `App.svelte`, and `app.css` holds the global styles.
- Group by feature under `src/lib/`: `src/lib/loans/` holds `loan-row.svelte`, `loan-list.svelte.ts`, `loan.ts` and the tests of all three. Do not group by kind, with a folder for all components and another for all stores.
- Put a component that has no feature, such as a button or a dialog, in `src/lib/ui/`. Put other code that several features share in `src/lib/shared/`, and only after a second feature needs it.
- Keep a component small enough to read in one screen. Split a component when a part has its own state, its own props or a name of its own, not because the file is long.
- Move logic that has no markup out of the component: a function into a `.ts` file, reactive state into a `.svelte.ts` module ([state sharing](07-state-sharing-and-context.md)). A `.ts` file runs in a plain test with no component.
- Do not write an `index.ts` that re-exports a folder, as the [TypeScript notes](../typescript-conventions/06-modules-and-imports.md#exports) say. Import from the file that defines the name.
- A Wails frontend keeps the folder that Wails generates for the Go bindings as it is, and imports from it. Treat it as generated code, and do not edit it.

```text
src/
  main.ts
  App.svelte
  app.css
  lib/
    loans/
      loan.ts
      loan-list.svelte.ts
      loan-list.svelte.test.ts
      loan-panel.svelte
      loan-row.svelte
      loan-row.browser.test.ts
    ui/
      autofocus.ts
      search-field.svelte
```

### Naming

- Name a file in kebab-case: `loan-row.svelte`, `loan-list.svelte.ts`. The [TypeScript notes](../typescript-conventions/07-naming-comments-and-style.md#naming) use kebab-case for every file, and a name that differs only by case breaks on a case-insensitive file system.
- Name a component in UpperCamelCase where you import it: `import LoanRow from "./loan-row.svelte"`. The compiler treats a capitalised tag as a component, and the file name has no effect on that.
- Use `.svelte.ts` for a module that uses a rune, such as `$state` or `$derived`. The compiler only transforms runes in a file with `.svelte` in the name. Use plain `.ts` for a module with no rune.
- Do not give a component and a `.svelte.ts` module the same base name in one folder. Both would be imported as `./name.svelte`.
- Name a test after its file: `loan-list.svelte.test.ts` tests `loan-list.svelte.ts`, and `loan-row.browser.test.ts` tests `loan-row.svelte` in a browser ([testing](10-testing.md#where-tests-live)).
- Name a prop, a variable and a function in lowerCamelCase, and a type and an interface in UpperCamelCase, as the TypeScript notes say. Name a boolean like a question: `isOpen`, `hasError`, `selected`.
- Name a snippet after what it renders, as a noun or a short phrase: `header`, `row`, `actions`, `emptyState`.
- Name a class that holds reactive state after the thing it holds, and do not end it in `Store`: `LoanList`, not `LoanListStore`.
- Name a function that returns an attachment after what it does, without a prefix: `autofocus()`, `tooltip(text)`. An attachment is used as `{@attach autofocus()}`.
- Name a CSS class in kebab-case, and a CSS custom property in kebab-case with two dashes: `--panel-gap`.

### Exports and imports

- Import a component as a default import and always write the `.svelte` extension: `import LoanRow from "./loan-row.svelte"`. A `.svelte` file is a default export, and this is the one place where the [TypeScript rule for named exports](../typescript-conventions/06-modules-and-imports.md#exports) does not apply.
- Import a `.svelte.ts` module without its `.ts` extension: `import { LoanList } from "./loan-list.svelte"`. Write the same for plain `.ts` modules: `import type { Loan } from "./loan"`. In a bundled app, the `.ts` extension is an error unless `allowImportingTsExtensions` is on. `svelte-check` reports `An import path can only end with a '.ts' extension` in the sample project.
- Mark a type-only import with `import type`. `verbatimModuleSyntax` makes the compiler enforce it, and the Svelte compiler needs it to tell a type from a value.
- Import a file in the same folder as `./name`, one folder up as `../name`, and anything further away through the `@/` alias, as in `@/lib/loans/loan-panel.svelte`. Never write `../../..`.
- Use named exports in `.ts` and `.svelte.ts` modules. Do not write `export let` in a module. A `.svelte.ts` module that needs to share a reassigned value exports an object or a function, as [runes](04-runes-and-reactivity.md#state) explains.
- Use a default export only where a tool requires one: `svelte.config.js`, `vite.config.ts` and a `.svelte` file.
- Export a value from a component only through `<script module>`:

```svelte
<script module lang="ts">
  export const PAGE_SIZE = 20;
</script>
```

- Keep `<script module>` for constants and plain functions that every instance shares. Do not put `$state` in it, because every instance would then share that state. Import a value from a `<script module>` as a named import from the `.svelte` file.

### Order inside a component

- A `.svelte` file reads in this order: `<script lang="ts">`, the markup, then `<style>`. `prettier-plugin-svelte` sorts them with its default `options-scripts-markup-styles`.
- Write a `<script module>` block before the instance `<script>`.
- Inside the instance script, write in this order: imports, the `Props` interface, the `$props()` line, constants, `$state`, `$derived`, functions, `$effect`. Each part uses what the part above it declares.
- Write one `<style>` block at the bottom of the file, and keep it short ([styling](08-templates-styling-and-accessibility.md#styling)).

### Comments

- Follow the [TypeScript comment rules](../typescript-conventions/07-naming-comments-and-style.md#comments) in a `<script>`: explain why, not what, and write `TODO(owner)` with an owner.
- Write a markup comment as `<!-- ... -->`. Use it for a reason that the markup cannot show, such as why an element has no label. Do not comment out markup.
- Document a prop with a `/** ... */` comment on its line in the `Props` interface. The editor shows it at every use of the component.

## Sources and raw notes

Pages read on 2026-11-18:

- [Svelte: `.svelte.js` and `.svelte.ts` files](https://svelte.dev/docs/svelte/svelte-js-files) and [`$state`](https://svelte.dev/docs/svelte/$state): runes work in `.svelte.js` and `.svelte.ts` modules, and a module cannot export a reassigned `$state` variable.
- [Svelte: `.svelte` files](https://svelte.dev/docs/svelte/svelte-files): the four blocks, `<script module>` runs once when the module first evaluates, its exports become exports of the compiled module, and a default export is not allowed. [Snippets](https://svelte.dev/docs/svelte/snippet): exported snippets since 5.5.
- [Svelte: basic markup](https://svelte.dev/docs/svelte/basic-markup): a tag that starts with a capital letter is a component.
- [prettier-plugin-svelte](https://github.com/sveltejs/prettier-plugin-svelte): the default sort order.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the layout above compiled, and `./loan-list.svelte` resolved to `loan-list.svelte.ts` in `svelte-check`, in ESLint and in `vite build`. Importing `./loan-list.svelte.ts` failed in `svelte-check` with the `allowImportingTsExtensions` error. The `@/lib/...` imports built without a Vite setting.
- `create-vite` 9.3.4 writes `src/lib/Counter.svelte` in UpperCamelCase, and the Svelte documentation uses the same style. The choice of kebab-case is recorded under [decisions to review](01-principles-and-sources.md#decisions-to-review).
