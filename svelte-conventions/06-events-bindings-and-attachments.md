# Svelte Events, Bindings and Attachments

## Summary

A DOM event is an attribute (`onclick`), and a handler is an ordinary function. Use `bind:` for form controls and `bind:this` for DOM nodes, and use a function binding to validate or transform a bound value. Put code that works on one element into an attachment (`{@attach}`), not into an effect. Validate form data with a schema, as the TypeScript notes require.

## Rules

### Events

- Write a DOM event as an attribute in lowercase: `onclick`, `oninput`, `onsubmit`. Do not use the `on:` directive or event modifiers. Svelte rejects a mix of `on:click` and `onclick` on one element, with the error `mixed_event_handler_syntaxes`.
- Event attribute names are case sensitive. `onclick` listens to `click`, and `onClick` listens to a different event named `Click`.
- Write an inline arrow function for a short handler, and a named function for a longer one. Name it `handleSomething` ([callback props](05-components-props-and-snippets.md#callback-props)).
- Call `event.preventDefault()` and `event.stopPropagation()` in the handler. An event attribute has no `|preventDefault` modifier. Capture is written in the name: `onclickcapture`.
- Put one handler of each event on an element. Combine two handlers into one function, because Svelte rejects a duplicate.
- Give a component a callback prop to report an event that the element does not own, and spread a DOM handler to the element through `...rest` ([props](05-components-props-and-snippets.md#props)).
- Type an extracted handler by the event and by its `currentTarget`: `SubmitEvent & { currentTarget: EventTarget & HTMLFormElement }`. Read the value from `event.currentTarget`. An inline handler needs no type, because `svelte-check` infers it from the element.
- Listen to the window or the document with `<svelte:window onkeydown={handleKeydown} />` and `<svelte:document>`. The element sits at the top level of the component, removes its listener when the component is destroyed, and is safe during server rendering. Do not call `window.addEventListener` inside an effect.
- Svelte delegates many events (`click`, `input`, `keydown`, `pointerdown` and others) to one listener at the root. Give a manually dispatched event `{ bubbles: true }`, and do not call `stopPropagation` in a listener you added with `addEventListener`, because that can stop delegated handlers. When you must add a listener by hand, use `on` from `svelte/events`, which keeps the order and handles `stopPropagation`.
- `ontouchstart` and `ontouchmove` are passive. To call `preventDefault` in them, add the listener with `on` from `svelte/events`.
- Use a real `<button>` for a click and a real `<a href>` for navigation, not a `div` with `onclick` ([accessibility](08-templates-styling-and-accessibility.md#accessibility)).

### Bindings

- Bind form controls with `bind:value`, `bind:checked` and `bind:group`. `bind:value` on a number or range input gives a number, and an empty or invalid number input gives `undefined`. `bind:group` works only inside one component.
- An event attribute runs after the binding has updated, so `oninput` sees the new `bind:value`.
- Bind a DOM node with `bind:this`, and declare the variable with `$state`: `let input = $state<HTMLInputElement>()`. The value is `undefined` until the component mounts, so read it in an event handler, an attachment or an effect, and write `input?.focus()`.
- Bind a readonly dimension straight to a variable: `bind:clientWidth={width}`. Svelte measures it with a `ResizeObserver`. An inline element cannot be observed, so give it `display: inline-block` or another display.
- Use a function binding to validate or transform a value without an effect: `bind:value={() => format(first), (next: string) => (first = next)}`. It needs Svelte 5.9. Annotate the setter's parameter, because the linter cannot infer it ([setup](02-project-setup-and-tooling.md#linting)).
- Bind to a component's prop only when the component marks it `$bindable` ([bindable props](05-components-props-and-snippets.md#bindable-props)).
- Use `bind:this` on a component only to call a function that it exports on purpose.

### Attachments

- Write behaviour that belongs to one element as an attachment and apply it with `{@attach fn}`. It needs Svelte 5.29. An attachment is a function that receives the element and may return a cleanup function. It runs when the element mounts and again when state that it reads changes.
- Write a reusable one as a function that returns an attachment, and type it with `Attachment` from `svelte/attachments`:

```ts
import type { Attachment } from "svelte/attachments";

export function autofocus(enabled = true): Attachment<HTMLElement> {
  return (element) => {
    if (enabled) element.focus();
  };
}
```

```svelte
<input {@attach autofocus()} />
```

- The call `autofocus(enabled)` runs inside an effect, so a change to `enabled` recreates the attachment. Pass a getter and read it inside the attachment when the setup is expensive and must not run again.
- An element accepts any number of attachments, and a falsy value means none: `{@attach enabled && autofocus()}`.
- Put a third-party library on an element through an attachment: create it in the function and destroy it in the cleanup that you return.
- A component passes attachments to the element that it spreads `...rest` onto, because `{@attach}` on a component becomes a prop with a symbol key. A wrapper component needs no extra code.
- Use `fromAction` from `svelte/attachments` to use a library written as an action. Write no new `use:` action. The documentation describes attachments as fully reactive and actions as not, and it keeps both.
- Do not write an effect that reads `bind:this` and checks for `undefined` to do what an attachment does.
- Use `createAttachmentKey` only to add an attachment to an object that is spread onto an element or a component.

### Forms

- Handle a form with `<form onsubmit={handleSubmit}>` and a `<button type="submit">`, so that Enter submits and the browser validates `required` fields. Call `event.preventDefault()` in the handler.
- Read the fields with `new FormData(event.currentTarget)`, and assign the result to an `unknown` variable at once. Validate it with a Zod schema and `safeParse`, then return the field errors with `z.flattenError(error).fieldErrors`, as the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md#forms-and-user-input) require.
- Bind a field with `bind:value` when the UI needs its value while the user types, such as a live preview or a character count. Use `FormData` when it needs the values only on submit.
- Give every control a `<label>` and a `name`. Put an error next to its field, mark the field with `aria-invalid`, and render the message in an element with `role="alert"`.
- Disable a submit button during a request with a `$state` flag that the handler sets, and set it back in a `finally` block.

```svelte
<script lang="ts">
  import { z } from "zod";

  const schema = z.object({
    borrower: z.string().min(1, "Enter a name"),
    amount: z.coerce.number().int().positive("Enter an amount above zero"),
  });
  type LoanInput = z.infer<typeof schema>;

  interface Props {
    onSave: (input: LoanInput) => void;
  }

  let { onSave }: Props = $props();

  let errors = $state<Partial<Record<keyof LoanInput, string[]>>>({});

  function handleSubmit(
    event: SubmitEvent & { currentTarget: EventTarget & HTMLFormElement },
  ): void {
    event.preventDefault();
    const raw: unknown = Object.fromEntries(new FormData(event.currentTarget));
    const result = schema.safeParse(raw);
    if (!result.success) {
      errors = z.flattenError(result.error).fieldErrors;
      return;
    }
    errors = {};
    onSave(result.data);
  }
</script>

<form onsubmit={handleSubmit}>
  <label>
    Borrower
    <input name="borrower" aria-invalid={errors.borrower ? "true" : undefined} />
  </label>
  {#if errors.borrower}<p role="alert">{errors.borrower[0]}</p>{/if}
  <label>
    Amount
    <input name="amount" type="number" />
  </label>
  <button type="submit">Save</button>
</form>
```

## Sources and raw notes

Pages read on 2026-11-18:

- [Basic markup](https://svelte.dev/docs/svelte/basic-markup): event attributes, case sensitivity, shorthand and spread, the order against `bind:`, passive touch events, delegation and its caveats.
- [Migration guide](https://svelte.dev/docs/svelte/v5-migration-guide): events as properties, no modifiers, `onclickcapture`, no duplicate handlers.
- [`bind`](https://svelte.dev/docs/svelte/bind): function bindings since 5.9, readonly bindings, `bind:group`, `bind:this`, dimension bindings, the `ResizeObserver` and inline-element caveat.
- [`{@attach}`](https://svelte.dev/docs/svelte/@attach): attachments since 5.29, factories, reactivity, conditional values, passing through props, `createAttachmentKey`, `fromAction`.
- [`<svelte:window>`](https://svelte.dev/docs/svelte/svelte-window): top level only, no manual cleanup, safe during server rendering.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes) with Zod 4.6.7: the form above, the `autofocus` attachment on `search-field.svelte`, a `<svelte:window>` handler with `bind:this`, and `bind:clientWidth={width}` passed `svelte-check`, ESLint and Prettier. A `bind:clientWidth={null, setter}` sample failed `svelte-check` with a type error on the setter parameter, so the note uses the plain binding. An `on:click` beside an `onclick` failed with `mixed_event_handler_syntaxes`.
- The Svelte documentation does not say that `use:` actions are deprecated, so the note calls attachments the form for new code and keeps the existing actions working.
