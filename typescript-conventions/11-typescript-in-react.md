# TypeScript in React

## Summary

Write function components with typed props, and let inference type everything else. Do not use `React.FC`. Extend `ComponentProps` to wrap an HTML element, give hooks a type argument only where the initial value cannot carry it, and type events by their element. This note covers the TypeScript side only. The Next.js notes decide components, routing and data.

## Rules

### Components

- Declare a component with `function`, and type its props in the signature. Give the props an `interface` named after the component (`ButtonProps`), or an inline type when there are one or two props. The React documentation types components this way.
- Do not use `React.FC`, `FC` or `FunctionComponent`. A plain function needs no wrapper type, and it works with generic components.
- Do not annotate the return type with `JSX.Element`. The React 19 types expose JSX only as `React.JSX`, and `JSX.Element` fails with TS2503. Let inference give the return type.
- Type `children` as `React.ReactNode`. Extend `ComponentProps<"button">` (or another element) when a component wraps an HTML element, so that it accepts every attribute of that element and its `ref`.
- In React 19, `ref` is an ordinary prop of a function component. Write new components without `forwardRef`.
- Give an optional prop its default in the destructuring pattern.
- Existing code: change the old forms in the lines you rewrite.

```tsx
import type { ComponentProps } from "react";

interface ButtonProps extends ComponentProps<"button"> {
  variant?: "primary" | "secondary";
}

export function Button({ variant = "primary", children, ...rest }: ButtonProps) {
  return (
    <button data-variant={variant} {...rest}>
      {children}
    </button>
  );
}
```

### Hooks

- Let `useState` infer from the initial value. Give a type argument when the initial value is `null` or an empty collection: `useState<User | null>(null)`, `useState<Loan[]>([])`.
- Type a ref by its element: `useRef<HTMLInputElement>(null)`.
- Type a reducer through the `State` annotation of its initial state, and write the actions as a discriminated union ([types and type design](04-types-and-type-design.md#model-alternatives-with-unions)).
- Create a context with `createContext<T | null>(null)`, and read it through a hook that throws when the value is `null`. The hook then returns `T`, so no component handles `null`.
- Do not add `useMemo`, `useCallback` or `React.memo` for typing reasons, and not without a profiler result ([memoisation](../nextjs-conventions/04-server-and-client-components.md#memoisation)).

```tsx
import { createContext, useContext } from "react";

interface User {
  name: string;
}

const UserContext = createContext<User | null>(null);

export function useUser(): User {
  const user = useContext(UserContext);
  if (!user) throw new Error("useUser must be used within a UserProvider");
  return user;
}
```

### Events

- Write an inline handler without a type. TypeScript infers the event from the element.
- Type an extracted handler with the event type of its element (`ChangeEvent<HTMLInputElement>`, `MouseEvent<HTMLButtonElement>`, `FormEvent<HTMLFormElement>`), and read the value from `event.currentTarget`.
- Name a callback prop `onSomething` and the function that implements it `handleSomething`.
- Do not give an event prop an `async` function. Call the async function from a normal handler ([async code](08-functions-classes-and-async.md#async-code)).
- Type a style prop as `React.CSSProperties`.

```tsx
import { useRef, useState } from "react";
import type { ChangeEvent } from "react";

export function NameField() {
  const [name, setName] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    setName(event.currentTarget.value);
  }

  return <input ref={inputRef} value={name} onChange={handleChange} />;
}
```

### Next.js boundaries

- Type route props with the generated `PageProps`, `LayoutProps` and `RouteContext` helpers. `params` and `searchParams` are promises ([props and params](../nextjs-conventions/03-project-layout-and-routing.md#props-and-params)).
- Give a Client Component only props that can cross the server boundary: plain data, not class instances or functions, except Server Functions ([props across the boundary](../nextjs-conventions/04-server-and-client-components.md#props-across-the-boundary)).
- Type a Server Function by the `FormData` it reads and the state it returns. Parse the `FormData` with a schema, and define the state as an `interface` ([forms](05-runtime-validation-and-external-data.md#forms-and-user-input)).
- Put `'use client'` only on a file that uses state, effects, event handlers or browser APIs. It is not a typing tool.

## Sources and raw notes

Pages read on 2026-10-26:

- [React: Using TypeScript](https://react.dev/learn/typescript): components typed as plain functions with a props type (the guide never uses `FC`), `useState`, `useReducer`, `useContext` with `| null` and a guard hook, `useCallback` with event handler types, DOM events, `children`, style props.
- `@types/react` 19.3.0: JSX exists only inside `namespace React` (`React.JSX`), and a sample `function A(): JSX.Element` failed with TS2503 under the Next.js baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application).
- [React 19 release post](https://react.dev/blog/2024/12/05/react-19): "ref as a prop" for function components, and new components no longer need `forwardRef`.
- The three code blocks compiled with TypeScript 5.9.3 and `@types/react` 19.3.0 under the baseline of [tsconfig](03-tsconfig.md#baseline-for-a-nextjs-application), and passed the lint config of [setup](02-project-setup-and-tooling.md#linting) without a finding. A sample `onClick={async () => ...}` triggered `no-misused-promises`.
- `React.FC`, `JSX.` and `forwardRef` counted in both repositories on 2026-10-26.
