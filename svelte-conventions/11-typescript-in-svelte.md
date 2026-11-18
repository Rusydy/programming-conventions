# TypeScript in Svelte

## Summary

Write every `<script>` with `lang="ts"` and follow the TypeScript notes inside it. Svelte only removes types, so it accepts erasable syntax, which is the same syntax that `erasableSyntaxOnly` allows. Type props with a local interface, extend the element types of `svelte/elements` to wrap an HTML element, and let inference type everything else. This note covers the TypeScript side only. The other Svelte notes decide components, state and styling.

## Rules

### Scripts

- Write `<script lang="ts">` in every component, and `<script module lang="ts">` for a module block. A `<script>` without `lang="ts"` is JavaScript, and the [TypeScript notes](../typescript-conventions/01-principles-and-sources.md#applying-the-notes) require TypeScript for every new source file. The `create-vite` template writes `App.svelte` that way, so fix it ([setup](02-project-setup-and-tooling.md#creating-a-project)).
- Svelte supports types and interfaces and nothing that needs compiled output. The documentation lists enums, constructor parameter modifiers and syntax that is not yet in ECMAScript as unsupported without a preprocessor. Write none of them: the [TypeScript notes](../typescript-conventions/03-tsconfig.md#compiler-options) already forbid `enum`, parameter properties and `namespace` with code.
- Use `import type` for a type, as `verbatimModuleSyntax` requires: `import type { Snippet } from "svelte"`. The `@tsconfig/svelte` base turns the option on because Svelte cannot tell by itself whether an import is a value or a type.
- `.svelte.ts` files are ordinary TypeScript modules in which runes work. Follow the same rules in them.
- Follow the [TypeScript notes](../typescript-conventions/01-principles-and-sources.md#principles) for everything else: `unknown` for external data, no `any`, no `as` to silence the compiler, no `!`, discriminated unions for alternatives.

### Props

- Declare props with an `interface Props` and destructure `$props()` with that annotation ([props](05-components-props-and-snippets.md#props)):

```svelte
<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    title: string;
    count?: number;
    onClose?: () => void;
    children?: Snippet;
  }

  let { title, count = 0, onClose, children }: Props = $props();
</script>
```

- Mark an optional prop with `?`, not `| undefined`, and give its default in the destructuring pattern.
- Give a prop that takes content the type `Snippet` for no argument, or `Snippet<[Loan]>` for one argument. The tuple lists the arguments.
- Type a callback prop as a function type, and give it no `async` signature ([callback props](05-components-props-and-snippets.md#callback-props)).
- An inline type is fine for one or two props: `let { title }: { title: string } = $props()`.
- An index signature such as `[key: string]: unknown` lets a component take extra props, but it weakens the check on the others. Extend an element's attribute type instead.
- `svelte/no-unused-props` reports a prop that the interface declares and the component never reads.

### Wrapper components

- Extend the attribute type of the element that a component wraps, so that it accepts every attribute and event of that element and passes the rest on with a spread:

```svelte
<script lang="ts">
  import type { HTMLInputAttributes } from "svelte/elements";

  interface Props extends Omit<HTMLInputAttributes, "value"> {
    label: string;
    value?: string;
  }

  let { label, value = $bindable(""), ...rest }: Props = $props();
</script>
```

- `svelte/elements` has `HTMLButtonAttributes`, `HTMLInputAttributes`, `HTMLAnchorAttributes` and the other element types. For an element without its own type, use `SvelteHTMLElements["section"]`.
- Use `Omit` to take a property out of the element's type when the component redefines it, such as `value` above.
- Type a prop that carries a class as `ClassValue` from `svelte/elements`. It accepts a string, an object and an array.
- Do not copy attribute types by hand.

### State and bindings

- `$state` and `$derived` infer their type from the initial value. A `$state` with no initial value has the type `T | undefined`. Give a type argument when the value starts empty: `$state<Loan[]>([])`, `$state<User | null>(null)` or `$state<HTMLInputElement>()`.
- Type a `bind:this` variable by its element: `let input = $state<HTMLInputElement>()`. Its value is `undefined` until mount, so use `input?.focus()` and never `input!`.
- Type a `bind:this` variable of a component by the component's name: `let title = $state<DocTitle>()`. The name of an imported component is its instance type, and `typeof DocTitle` is the constructor type.
- A function binding's getter and setter need the types of the bound value. Annotate the setter's parameter, because the linter cannot infer it ([setup](02-project-setup-and-tooling.md#linting)).
- Write a class field with `$state` the same way as a variable: `selectedId = $state<string>()`. A field with no initial value is `string | undefined`.

### Component types

- Use `Component<Props>` from `svelte` for a prop or a variable that holds any component with those props. This is how to type a component chosen at run time. `SvelteComponent` and `ComponentType` are for Svelte 4 and are deprecated.
- Use `ComponentProps<typeof Button>` to read the props of a component, for example in a wrapper or a test.
- Write a generic component with the `generics` attribute, which takes the same text as a type-parameter list. Constrain the parameter with `extends`, and add a parameter only when the component works on several types ([TypeScript rule on generics](../typescript-conventions/04-types-and-type-design.md)):

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
```

- Type an attachment function with `Attachment<T>` from `svelte/attachments`, where `T` is the element type: `Attachment<HTMLElement>`.
- Type context with `createContext<T>()`, which returns a typed getter and setter ([state sharing](07-state-sharing-and-context.md#context)).

### Events

- An inline handler needs no annotation, because the compiler infers the event from the element. Annotate an extracted handler by its event and its `currentTarget`: `SubmitEvent & { currentTarget: EventTarget & HTMLFormElement }` ([events](06-events-bindings-and-attachments.md#events)).
- Type a keyboard handler with `KeyboardEvent`, and a pointer handler with `PointerEvent`. Read values from `event.currentTarget`, which has the element's type, and not from `event.target`.

### Validation and external data

- Treat data from outside as `unknown` until a schema accepts it: fetch results, `FormData`, `localStorage`, `postMessage` data, and the replies of the Go bindings in a desktop app. Follow the [runtime validation note](../typescript-conventions/05-runtime-validation-and-external-data.md). Derive the type of the validated data with `z.infer` and use it as the prop type.

### Declarations

- Add a custom attribute or an event for an element by augmenting the `svelte/elements` module in a `.d.ts` file that is inside `include` of `tsconfig.app.json`. Add `export {}` to the file, so that it augments the module and does not replace it.
- Keep `vite/client` and `svelte` in `types` of `tsconfig.app.json`, so that imports of assets and of `.svelte` files are typed. Add no `declare module "*.svelte"`.

## Sources and raw notes

Pages read on 2026-11-18:

- [Svelte: TypeScript](https://svelte.dev/docs/svelte/typescript): `lang="ts"`, unsupported features, the three tsconfig requirements, `$props` typing with an interface, `Snippet`, `[key: string]: unknown`, `generics`, `HTMLButtonAttributes` and `SvelteHTMLElements`, `$state<T>()` and `undefined`, `Component`, `ComponentProps`, instance and constructor types, augmenting `svelte/elements`.
- [`$props`](https://svelte.dev/docs/svelte/$props) and [snippets](https://svelte.dev/docs/svelte/snippet): `Snippet` and tuple arguments. [`class`](https://svelte.dev/docs/svelte/class): `ClassValue` since 5.19. [Migration guide](https://svelte.dev/docs/svelte/v5-migration-guide): `SvelteComponent` and `ComponentType` deprecated in favour of `Component`.
- `create-vite` 9.3.4 `tsconfig.app.json`: `types` is `["svelte", "vite/client"]`.
- Checked on 2026-11-18 in the sample project of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the props, wrapper, generic and `Attachment` examples passed `svelte-check`, ESLint and Prettier. A probe with `Component<{ title: string }>`, `ComponentProps<typeof Button>`, `SvelteHTMLElements["section"]`, `$state<DocTitle>()` and `$state<ReturnType<typeof Button>>()` also passed `svelte-check`, and ESLint reported the unused prop in it with `svelte/no-unused-props`.
