# Svelte Components, Props and Snippets

## Summary

A component takes data through props, reports changes through callback props, and takes content through snippets. Declare the props with a local `Props` interface and destructure `$props()` once. Reach for `$bindable` only for a form-like component whose whole job is to edit a value. Compose with `children` and named snippets, and never with inheritance.

## Rules

### Props

- Declare the props in an `interface Props` at the top of the `<script>`, and read them with one `$props()` call that destructures them. Put the default of an optional prop in the destructuring pattern. A local `Props` is the form of the Svelte documentation and the `sv` templates ([decisions to review](01-principles-and-sources.md#decisions-to-review)).
- Do not give a prop a default for the sake of it. A required prop has no `?` and no default, so a parent that forgets it gets an error from `svelte-check`.
- Collect the other props with a rest element and spread them onto the element that the component wraps: `let { label, ...rest }: Props = $props()`, then `<input {...rest} />`. Extend the props of that element with the types of `svelte/elements`, such as `HTMLInputAttributes` and `HTMLButtonAttributes`, so that the component accepts every attribute and event of the element ([TypeScript in Svelte](11-typescript-in-svelte.md#wrapper-components)).
- Put `{...rest}` after the attributes that the caller may override and before the ones that it may not.
- Give a prop that carries a class the name `class`, rename it on destructuring (`class: className`), and type it as `ClassValue` from `svelte/elements`. It accepts a string, an object or an array, as the `class` attribute does ([styling](08-templates-styling-and-accessibility.md#styling)).
- Do not change a prop. A parent that passes a plain object sees no change, and a parent that passes `$state` gets an `ownership_invalid_mutation` warning. Report the change to the parent, or make the prop `$bindable`.
- Do not copy a prop into `$state` to edit it: the copy never follows the prop, and the compiler warns with `state_referenced_locally`. When the user edits a local version of a prop, derive it (`let draft = $derived(value)`) and assign to it, because a derived can be overridden and returns to the prop when the prop changes. When the edit is a draft of a new item, key the component on the item so that it starts fresh (`{#key item.id}`).
- Create an id for a form control with `$props.id()`. It is unique per component instance and equal on the server and in the browser. Link a label to its input through it.
- Read every prop through its destructured name. Do not pass the whole `$props()` object around.

```svelte
<script lang="ts">
  import type { HTMLButtonAttributes } from "svelte/elements";

  interface Props extends HTMLButtonAttributes {
    variant?: "primary" | "secondary";
  }

  let { variant = "primary", children, ...rest }: Props = $props();
</script>

<button data-variant={variant} {...rest}>
  {@render children?.()}
</button>
```

### Callback props

- Report a change from a child to its parent with a callback prop. Do not use `createEventDispatcher`, which is deprecated, and do not dispatch a `CustomEvent`.
- Name a callback prop `onSomething` in camel case (`onSelect`, `onDelete`), and the function that implements it `handleSomething` ([TypeScript in React](../typescript-conventions/11-typescript-in-react.md#events) uses the same names). Pass the data, not an event object: `onSelect: (id: string) => void`.
- When a prop is a DOM event of the wrapped element, keep the DOM name in lowercase (`onclick`, `oninput`) and let the rest spread carry it. `HTMLButtonAttributes` already types it.
- Type a callback prop as `(…) => void`. Do not give it an `async` function. Call the async function from a normal function in the parent, as the [TypeScript async rules](../typescript-conventions/08-functions-classes-and-async.md#async-code) say.
- Call an optional callback with `onClose?.()`.
- Do not forward an event through three components. Pass the callback down once, or share state through [context](07-state-sharing-and-context.md#context).

### Bindable props

- Mark a prop `$bindable` only when the component exists to edit a value for its parent, such as a text field, a toggle or a date picker: `let { value = $bindable("") }: Props = $props()`. The parent writes `bind:value={name}`.
- The fallback of a bindable prop applies only when the parent does not bind it. When a parent binds a prop that has a fallback, it must pass a value other than `undefined`, or Svelte throws an error at run time.
- Declaring a prop bindable allows a binding and does not require one. A parent may still pass the value alone.
- Do not bind a whole object so that a child can change its fields. Pass the object and a callback, so that the parent owns the change.
- Prefer a plain prop with a callback to a binding when the parent must validate or transform the value. A function binding does the same in the parent ([bindings](06-events-bindings-and-attachments.md#bindings)).

### Snippets

- Give a component content through the `children` snippet and render it with `{@render children?.()}`. Type it as `Snippet` from `svelte`. A component that has content inside its tags cannot also declare a prop named `children` that the parent sets.
- Use a named snippet prop for each other region: `header`, `row`, `actions`, `emptyState`. Render it with `{@render header?.()}`, or with `{#if header}…{:else}fallback{/if}` when the region has default content.
- Type a snippet that takes arguments with a tuple: `Snippet<[Loan]>`. The parent writes `{#snippet actions(loan)}`, and the child writes `{@render actions?.(loan)}`. A snippet replaces both the default slot and the `let:` data of a named slot.
- Annotate the parameter of a snippet that you write in a parent when the linter reports `any`: `{#snippet actions(item: Loan)}` ([setup](02-project-setup-and-tooling.md#linting)).
- Declare a snippet directly inside the tags of a component to pass it as a prop of the same name. Declare it at the top of the file and pass it as `{row}` when two components share it.
- Use a snippet inside one file to remove repeated markup. A snippet sees the values of the scope that it is declared in, and it may call itself or another snippet.
- A snippet takes no rest parameter, but it may destructure its argument and give defaults.
- Export a snippet from `<script module>` only when it needs nothing from the instance `<script>`. It needs Svelte 5.5 or later.
- Do not use `<slot>` or `let:` in new code. The `sv migrate svelte-5` command converts old slots ([modern Svelte by release](12-modern-svelte-by-release.md#migrating-an-existing-project)).
- Write markup inline when a region is used once and takes no argument. A snippet needs a reason: reuse, or a name that explains the markup.

```svelte
<script lang="ts" generics="Item extends { id: string }">
  import type { Snippet } from "svelte";

  interface Props {
    items: readonly Item[];
    row: Snippet<[Item]>;
    empty?: Snippet;
  }

  let { items, row, empty }: Props = $props();
</script>

<ul>
  {#each items as item (item.id)}
    <li>{@render row(item)}</li>
  {:else}
    {@render empty?.()}
  {/each}
</ul>
```

### Composition

- Compose components inside other components. Do not extend one component from another: a `.svelte` file has no `extends`.
- Prefer a few snippet props to many props that configure markup, such as `showIcon` and `iconPosition`.
- Render a component chosen at run time as a capitalised variable: `<Thing {...props} />`, or `<item.component />`. Do not use `<svelte:component this={Thing}>`, which is unnecessary in runes mode. Type the variable as `Component<Props>` from `svelte` ([TypeScript in Svelte](11-typescript-in-svelte.md#component-types)).
- Use `<svelte:element this={tag}>` only when the tag is a run-time value. Write a fixed tag as the tag.
- Do not reach into a child through `bind:this` to call its methods when a prop and an effect would do. A component may export a function only when it controls a resource, such as focus or a canvas, that props cannot describe.

### Mounting

- Mount the root component with `mount(App, { target })` from `svelte`. Do not write `new App({ target })`, which is Svelte 4 syntax. `mount` returns the instance, and `unmount(instance)` removes it.
- A component test mounts through `render` of the test library, not through `mount` directly ([testing](10-testing.md#component-tests)).

## Sources and raw notes

Pages read on 2026-11-18:

- [`$props`](https://svelte.dev/docs/svelte/$props): destructuring, fallbacks that are not proxies, rest props, renaming, the rule against mutating props, `$props.id()` since 5.20, typing with `svelte/elements` and `Snippet`.
- [`bind`](https://svelte.dev/docs/svelte/bind): `$bindable`, the fallback rule for bound props, and function bindings since 5.9.
- [Snippets](https://svelte.dev/docs/svelte/snippet): declaration, scope, passing as props, the implicit `children`, optional rendering, `Snippet` typing, exporting since 5.5, no rest parameters, slots deprecated.
- [Migration guide](https://svelte.dev/docs/svelte/v5-migration-guide): `createEventDispatcher` deprecated in favour of callback props, event attributes are properties, slots to snippets, `<svelte:component>` unnecessary, `new App()` replaced by `mount`.
- [`$derived`](https://svelte.dev/docs/svelte/$derived): a derived can be overridden since 5.25. [Compiler warnings](https://svelte.dev/docs/svelte/compiler-warnings): `state_referenced_locally`.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): `loan-row.svelte` (props, callback prop, optional snippet with an argument) and `search-field.svelte` (`$bindable`, `$props.id()`, rest spread of `HTMLInputAttributes`) passed `svelte-check`, ESLint and Prettier, and a browser test clicked the row and received the id in the callback. The generic list and the button samples above passed the same three checks in the sample project.
