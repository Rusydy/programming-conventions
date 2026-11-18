# Svelte Templates, Styling and Accessibility

## Summary

Keep the markup a plain description of the UI: short expressions, keyed `{#each}` blocks, and logic in `$derived` values and functions. Style with the scoped `<style>` block, the `class` attribute with objects and arrays, and CSS custom properties. Use the right HTML element first, and let the compiler's accessibility warnings fail the build.

## Rules

### Templates

- Write every `{#each}` block with a key: `{#each items as item (item.id)}`. The key is a stable, unique value of the item, such as its id. Do not use the index, because the index changes when the list changes. `svelte/require-each-key` reports an unkeyed block.
- Add `{:else}` to an `{#each}` that can be empty, to render the empty state. `null` and `undefined` count as an empty list.
- Keep an expression in the markup short. Move a condition, a format or a filter into a `$derived` value or a function, and give it a name ([runes](04-runes-and-reactivity.md#derived)).
- Prefer an early, flat `{#if}` with `{:else if}` over nested blocks. When a component has three or more states, such as loading, error and data, write them as one block chain, not as nested `{#if}` blocks.
- Use `{#key value}` to destroy and recreate a part of the tree when a value changes, such as a form that must start fresh for another record.
- Use the shorthand when the name matches: `{value}` and `{onclick}`. Use `{...rest}` to spread attributes.
- Write a self-closing tag only for a void element (`<input />`) or a component (`<Thing />`). Write `<div></div>` and `<span></span>` in full, because the compiler warns with `element_invalid_self_closing_tag`.
- Render text through `{expression}`. Svelte escapes it. Use `{@html}` only for HTML that you trust or that you sanitised, because it opens the page to cross-site scripting, and `svelte/no-at-html-tags` reports it. Add a comment that says where the HTML comes from.
- Write the page title with `<svelte:head><title>…</title></svelte:head>` or an effect on `document.title`, and nothing else in the head of a component ([effects](04-runes-and-reactivity.md#effect)).
- Do not use `<svelte:component>`, `<svelte:self>` or `<slot>`. They are for Svelte 4 ([modern Svelte by release](12-modern-svelte-by-release.md#idioms-to-replace)).

### Styling

- Style a component with its own `<style>` block. Svelte scopes the rules by adding a hashed class to the elements, so a rule in one component cannot leak into another. Keep the block short, and move shared design values to custom properties.
- Style by class, not by element, when the component renders content that it does not own. A scoped element selector also gets a specificity boost of one class, so it beats a global rule that loads later.
- Set classes with the `class` attribute and an object or an array, since Svelte 5.16:

```svelte
<li class={["row", { selected, paid: loan.status === "paid" }]}>
```

- Do not use the `class:` directive. The documentation advises against it for new code. The attribute form is easier to compose and to pass through a component prop typed as `ClassValue` ([props](05-components-props-and-snippets.md#props)).
- `class={undefined}` and `class={null}` leave the attribute out. A falsy value such as `false` becomes the text `"false"`, so put conditions inside an object or an array.
- Set one dynamic CSS property with the `style:` directive, such as `style:width={`${percent}%`}`, rather than building a `style` string.
- Put global rules in `src/app.css`: a reset, the page background, fonts and the custom properties of the theme. Import it once in `main.ts`.
- Use `:global(...)` only for markup that you do not control, such as the HTML that a library or `{@html}` renders. Prefer the nested form that stays under a scoped parent: `.content :global { a { color: inherit; } }`. Keep the global part as small as possible.
- Name a keyframe animation normally to keep it scoped to the component. Write `-global-name` only when another component must use it.
- Theme with custom properties defined on `:root`, and read them with a fallback: `var(--panel-gap, 1rem)`.
- Give a component a custom property at the call site when one instance needs a different look: `<Slider --track-color="black" />`. Svelte wraps the component in a `<svelte-css-wrapper>` element with `display: contents`, which can affect a child combinator (`>`) in a parent's selectors.
- Use the platform before a CSS framework. Scoped styles and custom properties come with Svelte. Add Tailwind CSS only for a reason that you write in the pull request, and list its Prettier plugin last in `.prettierrc`.
- Delete a rule that the compiler reports as unused (`css_unused_selector`). The warning appears when no element in the component can match the selector.
- Animate with `transition:`, `in:`, `out:` and `animate:` from `svelte/transition` and `svelte/animate`, and keep durations short. Turn motion off for users who ask for less of it, with a `prefers-reduced-motion` media query or a `MediaQuery` from `svelte/reactivity`.

### Accessibility

- Use the HTML element that has the meaning: `<button type="button">` for an action, `<a href>` for navigation, `<label>` for a control, `<ul>` for a list, `<dialog>` for a dialog. Do not put `onclick` on a `div` or a `span`. The compiler reports it with `a11y_click_events_have_key_events` and `a11y_no_static_element_interactions`.
- Give every `<img>` an `alt`. Write `alt=""` for a decorative image, and never start the text with "image", "photo" or "picture" (`a11y_img_redundant_alt`).
- Give every form control a visible `<label>`. Link them with `for` and an id from `$props.id()`, or wrap the control in the label ([props](05-components-props-and-snippets.md#props)).
- Do not use a positive `tabindex`, and do not give a non-interactive element `tabindex="0"`. Use the `autofocus` attribute rarely, because the compiler warns about it with `a11y_autofocus`. Move focus on purpose, in an attachment or an event handler, and only after the user's action.
- Give a `<video>` a `<track kind="captions">`, unless it is muted.
- Run `svelte-check --fail-on-warnings` in CI, so that every `a11y_*` warning fails the build ([scripts](02-project-setup-and-tooling.md#scripts)). Do not turn a warning off in `compilerOptions.warningFilter`.
- Silence one warning only with `<!-- svelte-ignore a11y_… (reason) -->` on the line above it, and only when the warning is wrong for that element. The reason goes in the parentheses.
- Check a new screen with the keyboard alone and with a screen reader before you call it done. The compiler checks a subset of the rules, and the rest need a person.

## Sources and raw notes

Pages read on 2026-11-18:

- [`{#each}`](https://svelte.dev/docs/svelte/each): keyed blocks, `{:else}`, `null` as empty. [Basic markup](https://svelte.dev/docs/svelte/basic-markup): text escaping and `{@html}` with trusted content only.
- [`class`](https://svelte.dev/docs/svelte/class): the `class` attribute with objects and arrays since 5.16 (clsx), `ClassValue` since 5.19, falsy values stringified, and the advice to avoid `class:`.
- [Scoped styles](https://svelte.dev/docs/svelte/scoped-styles): the hashed class, the specificity boost, scoped keyframes. [Global styles](https://svelte.dev/docs/svelte/global-styles): `:global(...)`, the `:global { }` block and its preferred nested form, `-global-` keyframes. [Custom properties](https://svelte.dev/docs/svelte/custom-properties): the `svelte-css-wrapper` element and `display: contents`, `var()` with a fallback, theming on `:root`.
- [Compiler warnings](https://svelte.dev/docs/svelte/compiler-warnings): the `a11y_*` warnings named above, `element_invalid_self_closing_tag`, and `svelte-ignore` with a reason in parentheses.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the class array in `loan-row.svelte` compiled and passed the checks, a `div` with `onclick`, an `img` without `alt` and an unused selector gave `svelte-check` warnings with the four codes `a11y_click_events_have_key_events`, `a11y_no_static_element_interactions`, `a11y_missing_attribute` and `css_unused_selector`, and an unkeyed `{#each}` and `{@html}` gave `require-each-key` and `no-at-html-tags` in ESLint.
- A sample with `style:width`, `<svelte:head><title>` and a nested `.content :global { a { } }` block passed `svelte-check` with no warning, and ESLint reported only the `{@html}` in it. The `svelte/transition` and `svelte/animate` modules and the `prefers-reduced-motion` advice come from the Svelte reference and general web practice, and the sample project did not exercise them.
