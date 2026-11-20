# Vue Components, Props, Emits and Slots

## Summary

A component is a typed contract: props in, events and `v-model` out, slots for content. Declare props with a local `Props` interface and destructure them, declare events with a type literal, use `defineModel()` for two-way binding, and describe every slot with `defineSlots()`. Pass data down and events up, and never mutate a prop.

## Rules

### Props

- Declare props with a local `interface Props` and the type argument of `defineProps()`. Destructure the result and give defaults in the pattern. `vue/define-props-declaration` (`type-based`) and `vue/define-props-destructuring` enforce both:

```vue
<script setup lang="ts">
import type { Loan } from "./loan";

interface Props {
  loan: Loan;
  selected?: boolean;
}

const { loan, selected = false } = defineProps<Props>();
</script>
```

- A prop is lowerCamelCase in the script and kebab-case in a template. Use `?` for an optional prop, as the TypeScript notes say, never `| undefined`. An optional prop without a default is `undefined` when the parent omits it.
- Destructured props are reactive in Vue 3.5 and later: the compiler rewrites `loan` to `props.loan`. Do not use `withDefaults()`, and do not write `props.x` in new code. A component that must run on Vue 3.4 or older keeps `withDefaults()`.
- Pass a destructured prop to a function as a getter, because the compiler cannot rewrite a value that leaves the component: `watch(() => id, load)` and `useLoan(() => id)`. `watch(id, load)` is a compiler warning, since it passes a value instead of a source. A composable accepts the getter through `MaybeRefOrGetter<T>` ([composables](07-composables.md#arguments)).
- Do not mutate a prop, and do not assign it to state that you then mutate. The data flow is one-way, and `vue/no-mutating-props` reports the mutation. For a draft that starts from a prop, use a `ref` seeded in a `watch` with `immediate`, or, simpler, key the component so that it resets: `<LoanForm :key="loan.id" :loan />`.
- A prop with a default is optional, so do not mark it required. `vue/no-required-prop-with-default` reports a required prop that has a default.
- A default for an object or array in a destructure is written as the value, and Vue creates it for each instance: `const { tags = [] } = defineProps<Props>()`. `withDefaults()` needs a function for the same.
- A boolean prop with no value in the template (`<LoanRow selected />`) is `true`. Vue casts a missing boolean prop to `false`. Write `selected` for `true`, and `:selected="false"` for `false`.
- Keep props few and flat. Pass a domain object (`loan`) rather than five of its fields, when the component shows the whole thing. Pass the fields when the component is a generic one that knows nothing about the domain.
- Wrap an HTML element by extending its attribute type, and mark it with the `@vue-ignore` comment so that the Vue compiler does not try to resolve it. Fallthrough attributes (`class`, `aria-*`, listeners) already reach the root element, so you only extend the type for the editor's sake:

```ts
import type { ButtonHTMLAttributes } from "vue";

interface Props extends /* @vue-ignore */ ButtonHTMLAttributes {
  variant?: "primary" | "quiet";
}
```

- A component with more than one root element must say where fallthrough attributes go. Set `inheritAttrs: false` with `defineOptions()` and bind `v-bind="$attrs"` on the element that should receive them, or read them with `useAttrs()`.
- Generate ids with `useId()` (3.5), not a counter or `Math.random()`. The id is stable across server and client rendering: `const selectId = useId()`.

### Emits

- Declare events with a type literal: `defineEmits<{ select: [id: string]; remove: [] }>()`. Each key is an event and each value a tuple of its arguments, with a name for each argument. `vue/define-emits-declaration` (`type-literal`) enforces it. The call-signature form (`(e: "select", id: string): void`) is the older form.
- Name an event for what happened (`select`, `remove`, `rowSelect`), in lowerCamelCase in the script and kebab-case in the template: `@row-select`. Pass data in the arguments, not the DOM event, unless the parent needs the event.
- Emit from a handler: `emit("select", loan.id)`. In a template, `$emit` is available, but prefer `emit` so that the call is typed and searchable. A short inline emit such as `@click="emit('select', loan.id)"` is fine.
- Declare every event. An undeclared native event on the root element, such as `click`, falls through to it. A declared event does not.
- Do not use `$emit` for a call that expects a result. An event announces; it does not ask. For a callback with a result, pass a function prop.
- Do not pass a function prop where an event fits: `onSelect` as a prop and `select` as an event are the same contract in two shapes, and Vue treats `@select` as `onSelect`. Use events, so that the parent writes `@select`.

### `v-model`

- Use `defineModel()` (3.4) for a component that edits a value. It declares the prop and the `update:` event, and returns a ref that you read and write: `const note = defineModel<string>("note", { default: "" })`. The default model is `modelValue`. Name a second model, as in `defineModel("note")`, and bind it as `v-model:note`.
- Declare the model after `defineEmits()`, as `vue/define-macros-order` expects ([setup](02-project-setup-and-tooling.md#eslint-rules-for-vue)).
- A model with `required: true` has the type `T`. One with a default has the type `T`. One with neither is `T | undefined`.
- Write to the model ref to change it (`model.value = next`), and bind it with `v-model="model"` on a native input. Do not also emit `update:modelValue` by hand.
- Use modifiers through the tuple form: `const [model, modifiers] = defineModel<string>()` and read `modifiers.trim`. Do not use a modifier when an ordinary prop would do.
- A component that exists to show data does not need `v-model`. A parent that passes a value and listens for one event does the same job in a way that is easier to read.
- Do not bind a whole object with `v-model` so that a child edits its fields. The child would mutate the parent's data, and the parent could not see where. Bind one field at a time, or emit an updated copy.
- The compiler rejects `defineModel` options that refer to a destructured prop (an error since 3.5.44). Use a constant instead.

### Slots

- Pass content through slots, not through a prop that holds HTML or a render function. A component with a header and a body has two slots: `<slot name="header" />` and a default `<slot />`.
- Declare the slots with `defineSlots<{ ... }>()`, so that the parent type-checks the slot names and their props. `vue/require-explicit-slots` reports a slot that you did not declare. Write each slot as a method that receives its props and returns `unknown`:

```ts
defineSlots<{
  default(): unknown;
  option(props: { option: T }): unknown;
}>();
```

- A scoped slot passes data to the parent: `<slot name="option" :option>` and `<template #option="{ option }">`. Use it when the parent decides how to show an item that the child owns, as in a list or a table.
- Give a slot a fallback in the `<slot>` tag when there is a sensible one: `<slot name="option" :option>{{ option.id }}</slot>`.
- Use the shorthand `#header` for `v-slot:header`. `vue/v-slot-style` enforces it. Put the `v-slot` on the `<template>` for a named slot, and on the component for a lone default slot.
- Do not read `$slots` to decide what to render unless you must, as with a wrapper that hides an empty header: `useSlots()` or `$slots.header` is the one allowed check.

### Generic components

- Declare a type parameter with the `generic` attribute of the script tag, and constrain it: `<script setup lang="ts" generic="T extends { id: string }">`. Use it in props, emits, the model and the slots, so that the parent gets one consistent type. Use a generic component only when it works on several types, as the TypeScript notes say about type parameters.
- Do not write a generic component for a component that has one caller.

### Exposing and referencing

- A `<script setup>` component is closed: a parent that holds a template ref sees nothing until you call `defineExpose({ open, close })`. Expose a small set of methods, not state, and use it rarely. A parent that needs to open a dialog may call `open()`, but prefer a prop and an event for ordinary data flow.
- Type a ref to a component with `useTemplateRef<InstanceType<typeof BaseDialog>>("dialog")`.
- Do not use `$parent`, `$root` or `$refs`. They hide the data flow, and the style guide lists implicit parent-child communication under rules to use with caution. Pass props and events, or use [provide and inject](08-state-management-and-provide-inject.md#provide-and-inject).

### Component design

- A component has one job. When a component takes a prop whose only use is to switch a block of markup on, split the block into a component or a slot.
- Do not nest components only for naming. The performance note explains that every component instance costs memory and time ([performance](11-performance-and-security.md#performance)).
- Do not use `<component :is>` with a string. Pass the imported component, or use a map from a known key to a component, and type it as `Component`.
- Do not write render functions or JSX for ordinary components. They suit a library that builds markup from data, and they give up the compiler's optimisations. A functional component is a plain function component that takes props and returns a vnode, and it is for the same rare cases.
- Do not use mixins, `extends` or global registration. Reuse logic through composables and content through slots.

## Sources and raw notes

Pages read on 2026-11-20:

- [Props](https://vuejs.org/guide/components/props.html): runtime and type-based declaration, reactive props destructure (3.5), passing destructured props into functions as getters, one-way data flow, boolean casting.
- [Vue and TypeScript: Composition API](https://vuejs.org/guide/typescript/composition-api.html): type-based `defineProps` and `defineEmits`, `withDefaults()` for 3.4 and below, `defineSlots()`, template refs and generics.
- [Component events](https://vuejs.org/guide/components/events.html): declaring and validating events, casing, and that a declared event does not fall through.
- [Component v-model](https://vuejs.org/guide/components/v-model.html): `defineModel()` since 3.4, the returned ref, options, multiple models, modifiers.
- [Slots](https://vuejs.org/guide/components/slots.html): named, scoped and fallback slots.
- [Fallthrough attributes](https://vuejs.org/guide/components/attrs.html): `inheritAttrs`, `$attrs`, `useAttrs()`.
- [`<script setup>`](https://vuejs.org/api/sfc-script-setup.html): `defineProps`, `defineEmits`, `defineModel`, `defineExpose`, `defineOptions`, `defineSlots`, `generic`.
- [Composition API helpers](https://vuejs.org/api/composition-api-helpers.html) and [accessibility](https://vuejs.org/guide/best-practices/accessibility.html): `useId()` (3.5) for form-label ids.
- [Vue style guide, use with caution](https://vuejs.org/style-guide/rules-use-with-caution.html): element selectors with `scoped`, implicit parent-child communication.
- Vue 3.5.44 [changelog](https://github.com/vuejs/core/blob/main/CHANGELOG.md): `compiler-sfc` errors when `defineModel` options refer to a destructured prop.
- Checked on 2026-11-20 in the sample project of the [setup note](02-project-setup-and-tooling.md#sources-and-raw-notes): a row component with destructured props, a default and `defineModel`; a button that extends `ButtonHTMLAttributes` under `@vue-ignore` and declares its slot; a generic select with `defineModel`, `defineEmits`, a scoped `option` slot and `useId()`; a dialog with `inheritAttrs: false`, `$attrs` and `defineExpose`, referenced as `InstanceType<typeof BaseDialog>`. `vue-tsc`, ESLint (`--max-warnings 0`) and Prettier ran with 0 errors. The macro-order rule reported `defineEmits` written after `defineModel` until its `order` option listed the five macros.
