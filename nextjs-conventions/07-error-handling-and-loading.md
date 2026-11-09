# Next.js Error Handling and Loading States

## Summary

Next.js separates expected errors from uncaught exceptions. Expected errors are values that the code returns and renders. Uncaught exceptions are bugs that an error boundary (`error.tsx`) catches. Every route that fetches data also needs a loading state, either an inline `<Suspense>` boundary or a `loading.tsx` file.

## Rules

### Expected errors

- Expected errors occur in normal operation: invalid form input, a rejected upstream call, a missing record. Handle them explicitly.
- In Server Functions, return them as values and read them with `useActionState`. Do not throw for them and do not wrap them in `try`/`catch` ([mutations and forms](06-mutations-and-forms.md#validation-and-errors)).
- In Server Components, check the response, then render a message, call `redirect()` or call `notFound()`.

### Unexpected errors

- Unexpected errors are bugs. Throw them and let an error boundary catch them.
- Add an `error.tsx` at the root and beside routes with their own fallback. It must be a Client Component and receives `error` and `retry`.

```tsx
// app/error.tsx
'use client'

import { useEffect } from 'react'

export default function Error({
  error,
  retry,
}: {
  error: unknown
  retry: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={() => retry()}>Try again</button>
    </div>
  )
}
```

- `retry()` re-fetches and re-renders the segment. `reset()` only clears the error state and re-renders the children without a refetch, so use it only when you want exactly that. `retry` is stable since 16.3 and was `unstable_retry` in 16.2. Before 16.2, use `reset`.
- `error` is typed `unknown`. Narrow it (for example with `instanceof Error`) before you read `message` or `digest`.
- Production hides the message of server errors and sends a `digest` instead. Match the `digest` with the server log, and do not show `error.message` for server errors.
- Errors go to the container log (standard output), and the `digest` links a browser error to its log line. No hosted error tracker or reporting SDK is added.
- `global-error.tsx` in the root of `app/` catches failures of the root layout. It must render its own `<html>` and `<body>`, it does not load your global styles, and it cannot export metadata.
- Use `catchError` from `next/error` (it was `unstable_catchError` in 16.2) for a boundary around one widget. It lets `redirect()` and `notFound()` pass through, which a hand-written React error boundary does not.
- Error boundaries do not catch errors in event handlers or other async code. Catch them there and store them in state.

### Not found

- Call `notFound()` when a record does not exist, for example in `app/career/detail/[id]/page.tsx`. Add a `not-found.tsx` beside that route and a root `app/not-found.tsx` that shows the site layout.
- Do not use `app/global-not-found.tsx` for unmatched routes. The production checklist marks it experimental, and the root `app/not-found.tsx` covers the case.

### Loading states

- Prefer `<Suspense>` around the slow read. It shows the page around it at once.
- `loading.tsx` wraps the `page` and its children of one segment in a Suspense boundary. It suits a whole-page skeleton.
- Give every route that fetches data a loading state, inline or in `loading.tsx`.
- Make the skeleton show a meaningful part of the final screen, such as a heading, a cover or a card outline.

### Choosing the mechanism

| Situation | Mechanism |
| --- | --- |
| Form input is invalid | Return a value and render it with `useActionState` |
| Record does not exist | `notFound()` and `not-found.tsx` |
| Upstream fails during render | Throw, and let the segment `error.tsx` catch it. If the section is optional, render a message instead. |
| Root layout throws | `global-error.tsx` |
| One widget may fail without breaking the page | A `catchError` boundary around it |
| A click handler fails | `try`/`catch` and `useState` |
| Data is slow | `<Suspense>` or `loading.tsx` |

## Sources and raw notes

Pages read on 2026-10-26:

- [Error handling](https://nextjs.org/docs/app/getting-started/error-handling): expected errors, `notFound`, `error.js`, `catchError`, `global-error.js`, event-handler errors.
- [`error.js`](https://nextjs.org/docs/app/api-reference/file-conventions/error): `error`, `retry` and `reset` props, `digest`, version history (`retry` stable in 16.3, `unstable_retry` added in 16.2).
- [Fetching data](https://nextjs.org/docs/app/getting-started/fetching-data): `loading.js` and `<Suspense>`, meaningful loading states.
- [Caching](https://nextjs.org/docs/app/getting-started/caching): blocking-route insight.
- [Production checklist](https://nextjs.org/docs/app/guides/production-checklist): `global-error.tsx`, `global-not-found.tsx`.
- [Next.js 16.3](https://nextjs.org/blog/next-16-3) and [16.2](https://nextjs.org/blog/next-16-2): `catchError`, `unstable_retry`.
