# Vue Templates, Styling and Accessibility

## Summary

Keep templates declarative and simple: one expression, no statements, a stable `key` on every loop, and `v-if` apart from `v-for`. Scope every style to its component and use CSS custom properties for anything shared. Write semantic HTML first, and let `eslint-plugin-vuejs-accessibility` catch what the compiler cannot.

## Rules

### Template syntax

- Use the shorthands everywhere: `:prop`, `@event` and `#slot`. Never mix `v-bind:` and `:` in one file. `vue/v-bind-style`, `vue/v-on-style` and `vue/v-slot-style` enforce them.
- Quote every attribute value, and write a component with no content as self-closing (`<LoanRow />`). Write `<div></div>` for an HTML element, as `vue/html-self-closing` in `flat/recommended` expects.
- Write a component in PascalCase in a single-file template (`<LoanRow />`) and an HTML element in lowercase. The style guide recommends PascalCase in SFC templates and kebab-case in in-DOM templates, which this set does not use.
- Use the same-name shorthand when the attribute and the variable share a name (Vue 3.4): `<LoanRow :loan />` for `:loan="loan"`. A component, `ref` or `id` that reads `:id` is the same idea. Do not use it when it makes the template harder to read.
- Keep an expression to one value. Move a chain of operations, a filter or a sort into a `computed()`, and a function that does more than call something into the script. The style guide calls this simple expressions in templates, and a template with a statement does not compile.
- Do not call a function in a template for a value that you read more than once. Use a `computed()`, which caches ([reactivity](04-reactivity.md#computed)).
- Break a tag with several attributes onto lines, one attribute for each line, as Prettier does. The style guide's multi-attribute rule agrees.
- Keep the order of attributes that `vue/attributes-order` defines: definition (`is`), list rendering (`v-for`), conditionals (`v-if`), render modifiers, global attributes (`id`), unique attributes (`ref`, `key`), two-way binding (`v-model`), other attributes, events (`@click`), content (`v-html`, `v-text`).
- Write a comment that explains why, as in code. HTML comments in a template are removed in production builds, so they cost nothing to leave.

### Conditionals and loops

- Give every `v-for` a `:key` that is a unique, stable value from the data (`:key="loan.id"`). Never use the index when items can be reordered, inserted or removed, and never use an object. `vue/require-v-for-key` is an error in `flat/recommended`. On a `<template v-for>`, put the key on the `<template>`.
- Write `v-for="loan in loans"` with `in`. Use `of` only when you want to match a `for...of` loop; the notes use `in`.
- Never put `v-if` and `v-for` on one element. `v-if` is evaluated first in Vue 3 and cannot see the loop variable, so the combination fails or filters the wrong thing. Filter in a `computed()`, or move the `v-if` to a wrapping `<template>`. `vue/no-use-v-if-with-v-for` is an error.
- Use `v-if` / `v-else-if` / `v-else` chains for blocks that are mutually exclusive, and `v-show` for an element that toggles often and should keep its state. `v-if` is the default: it does not render the branch at all when it is false.
- `v-show` does not work on `<template>`, and it hides with `display: none`. Do not use it for content that should be absent from the accessibility tree and the DOM.
- Put a stable `key` on an element in `v-if` branches that reuse the same tag, if the state of one branch must not carry over to the other.
- Use `<template v-if>` and `<template v-for>` to group without an extra element. A template tag with no directive has no meaning, and `vue/no-lone-template` reports it.
- A list of more than a few hundred rows is virtualised, not rendered in full ([performance](11-performance-and-security.md#performance)).

### Events and forms

- Call a method for anything more than one statement: `@click="handleSelect"`. An inline statement that emits or sets one value is fine: `@click="emit('select', loan.id)"` and `@click="open = true"`.
- Use event modifiers (`.prevent`, `.stop`, `.once`) in the template instead of calling `preventDefault()` in the handler. Order modifiers as they should apply.
- Use `v-model` for form inputs. Use `.trim` for text, `.number` for numbers that you parse, and `.lazy` to update on `change`. `v-model` on a native input, textarea or select needs no extra handler, and it keeps the IME composition working.
- Do not mix `v-model` with `:value` and `@input` on the same input.
- A form submits through `<form @submit.prevent="handleSubmit">` and a `<button type="submit">`. Do not rely on a click handler on a button to submit, because Enter would not work.
- Validate with a schema in the submit handler and show the field errors beside the fields, as the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md) say about form input. Do not repeat the validation rules in the template.

### Styling

- Use `<style scoped>` in every component that has styles. The style guide makes component-scoped styling an essential rule, and `vue/enforce-style-attribute` (with `allow: ["scoped"]`) rejects a plain `<style>` and a `<style module>`.
- Put global styles in plain `.css` files and import them once in `main.ts`: `import "./assets/main.css"`. Put design tokens in CSS custom properties on `:root`, and read them in components with `var(--color-text)`.
- Select by class, not by element, in a scoped style. A scoped element selector such as `div p` is slow, and the style guide lists element selectors with `scoped` under rules to use with caution.
- Style a child component's inner element with `:deep(.name)`. Use it rarely, because it breaks the child's encapsulation, and ask for a prop or a custom property instead. Use `:global(.name)` for one global rule inside a scoped block, and `:slotted()` for slotted content.
- Bind a style to reactive state with a custom property on the element (`:style="{ '--progress': percent + '%' }"`) or `v-bind()` in the CSS. Do not write inline style strings.
- Use `:class` with an object or an array: `:class="{ selected }"` and `:class="['base-button', variant]"`. A component's `class` falls through to its root, so a parent can add a class without a prop.
- Use the platform before a CSS framework. Scoped styles, custom properties, `@layer` and `@container` come with the browser. Add Tailwind CSS only for a reason that you write in the pull request, and list its Prettier plugin last in `.prettierrc`, which is the one reason to have one ([formatting](02-project-setup-and-tooling.md#formatting)).
- Write plain CSS in `<style>`. Do not add Sass or Less, because nesting, variables and `color-mix()` are in CSS. Add a preprocessor only for an existing codebase that already uses one.

### Accessibility

- Use the HTML element that has the meaning: `<button>` for an action, `<a>` for navigation (or `RouterLink`), `<label>` for a field name, `<nav>`, `<main>`, `<header>`, `<ul>`. Do not put a click handler on a `<div>` or `<span>`. `vuejs-accessibility/click-events-have-key-events` and `no-static-element-interactions` are errors.
- Give every form control a label. Link them with `<label :for="id">` and `:id="id"` from `useId()`, or wrap the control in the label. Use `aria-label` only when no visible label exists. A placeholder is not a label.
- Give every `<img>` an `alt`. Write `alt=""` for a decorative image, and a short description for a meaningful one.
- Give a heading level the document's structure, not its size. Use one `<h1>` for the page, and style headings with CSS.
- Keep one `<main>` landmark per page, and add a skip link as the first focusable element when there is a repeated header.
- Show focus. Do not remove the outline without a replacement.
- After a route change, move focus to the new page's heading or its `<main>`, and update `document.title`. A single-page app does not do either by itself ([routing](09-routing-and-data-fetching.md#navigation-and-focus)).
- Announce changes that the user cannot see with a live region (`role="status"`, `aria-live="polite"`). Use `aria-hidden="true"` only on content that is not for assistive technology, and never on a focusable element.
- Use `<dialog>` with `showModal()` for a modal: it traps focus, closes on Escape and makes the page behind inert. A hand-written modal needs all of that by hand.
- A keyboard user reaches every pointer action. Test with the Tab key before you ship.
- `eslint-plugin-vuejs-accessibility` runs in CI as errors. It does not replace testing with a screen reader and a keyboard.

## Sources and raw notes

Pages read on 2026-11-20:

- [Template syntax](https://vuejs.org/guide/essentials/template-syntax.html), [list rendering](https://vuejs.org/guide/essentials/list.html) and [conditional rendering](https://vuejs.org/guide/essentials/conditional.html): the key, `v-if` with `v-for`, `v-show` against `v-if`, `<template>`.
- [Vue style guide, essential](https://vuejs.org/style-guide/rules-essential.html): keyed `v-for`, no `v-if` with `v-for`, component-scoped styling.
- [Vue style guide, strongly recommended](https://vuejs.org/style-guide/rules-strongly-recommended.html): self-closing components, name casing in templates, multi-attribute elements, simple expressions, quoted attribute values, directive shorthands.
- [Vue style guide, recommended](https://vuejs.org/style-guide/rules-recommended.html): element attribute order.
- [Vue style guide, use with caution](https://vuejs.org/style-guide/rules-use-with-caution.html): element selectors with `scoped`.
- [SFC CSS features](https://vuejs.org/api/sfc-css-features.html): `scoped`, `:deep()`, `:slotted()`, `:global()`, `v-bind()` in CSS, `<style module>`.
- [Class and style bindings](https://vuejs.org/guide/essentials/class-and-style.html) and [form input bindings](https://vuejs.org/guide/essentials/forms.html): `.trim`, `.number`, `.lazy`.
- [Accessibility](https://vuejs.org/guide/best-practices/accessibility.html): the skip link, content structure, headings, landmarks, semantic forms, labels, placeholders, hiding content, buttons, functional images, `useId()`.
- [eslint-plugin-vuejs-accessibility](https://vue-a11y.github.io/eslint-plugin-vuejs-accessibility/) 2.6.3: the `flat/recommended` config, `click-events-have-key-events`, `no-static-element-interactions`, `alt-text`, `form-control-has-label`, `label-has-for`.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): a sample with a plain `<style>`, a `v-for` without a key, a `v-if` on the same element as `v-for`, `v-html` and an unlabelled input gave the errors that this note names. The same-name shorthand (`:loan`, `:option`, `:id="selectId"`) compiled and type-checked, and the `scoped` style with a class selector passed `vue/enforce-style-attribute`.
