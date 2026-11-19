# SvelteKit Forms and Mutations

## Summary

Change data with a form action in `+page.server.ts`, and submit it from a real `<form method="POST">` that `use:enhance` improves. Parse the `FormData` with a schema, return validation errors with `fail()`, redirect with `303` after a success, and check the user inside every action. Use a `+server.ts` endpoint only for a JSON API. Remote functions are experimental and are not used.

## Rules

### Actions

- Export `actions` from `+page.server.ts`, typed with `Actions` from `./$types`. An action receives the request event and does the work on the server. Every action answers a `POST` request, because a `GET` must have no side effects.
- Use one `default` action when a page has one form. Use named actions (`?/archive`) when it has several, and do not mix `default` with named actions on one page: the `?/name` query string stays in the URL, and the next default `POST` would hit the named action.
- Read the fields with `await request.formData()`, assign the result to an `unknown` variable at once, and validate it with a Zod `safeParse`, as the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md#forms-and-user-input) require. `Object.fromEntries(formData)` is `unknown` data until a schema accepts it.
- Return a validation failure with `fail(status, data)`. Use `422` for invalid fields and `400` for a malformed request. The data reaches the page as the `form` prop. Return the field errors with `z.flattenError(error).fieldErrors`, and return the field values the user typed so that the form can show them again. Never return a password, a token or any other secret.
- Return plain, serialisable data from a successful action, and redirect with `redirect(HTTP_STATUS.seeOther, location)` when the result is a different page. A `POST` that ends in a redirect cannot be repeated by a refresh.
- Do not catch a `redirect` or an `error`. If you wrap an action's body in `try`, rethrow with `isRedirect` and `isHttpError` from `@sveltejs/kit`.
- Check the user inside the action, with the same `requireUser()` helper as in `load`. A form action is a public endpoint, and a page's `load` check does not cover it ([authorisation](07-hooks-errors-and-security.md#authentication-and-authorisation)).
- Keep a money amount as an integer count of minor units with a currency code, and validate it as one, as the [TypeScript notes](../typescript-conventions/01-principles-and-sources.md) say for money. The sample action above stores `amountMinor`.
- `handle` runs before the action and not again. When an action changes a cookie that `handle` reads to fill `event.locals`, update `event.locals` in the action as well.
- After a successful action, SvelteKit runs the page's load functions again, so the page shows the new data without a manual `invalidate`.

```ts
// src/routes/loans/+page.server.ts
import { fail } from "@sveltejs/kit";
import { z } from "zod";

import { HTTP_STATUS } from "#lib/http-status.ts";
import { requireUser } from "#lib/server/auth.ts";
import { createLoan, listLoans } from "#lib/server/loans.ts";

import type { Actions, PageServerLoad } from "./$types";

const schema = z.object({
  borrower: z.string().min(1, "Enter a name"),
  amount: z.coerce.number().int().positive("Enter an amount above zero"),
});

export const load: PageServerLoad = () => {
  requireUser();
  return { loans: listLoans() };
};

export const actions: Actions = {
  default: async ({ request }) => {
    requireUser();
    const raw: unknown = Object.fromEntries(await request.formData());
    const result = schema.safeParse(raw);
    if (!result.success) {
      return fail(HTTP_STATUS.unprocessable, { errors: z.flattenError(result.error).fieldErrors });
    }
    createLoan({
      borrower: result.data.borrower,
      amountMinor: result.data.amount,
    });
    return { saved: true };
  },
};
```

### The form

- Write the form with `method="POST"` and a `<button type="submit">`, so that it works without JavaScript. Add `use:enhance` from `$app/forms` to submit with `fetch`, to update `form` and the page data without a reload, to reset the form on success and to follow redirects.
- `use:enhance` works only on a `POST` form that targets a `+page.server` action. It throws on a `GET` form and on a form that targets a `+server` endpoint.
- Read the result from the `form` prop: `let { data, form }: PageProps = $props()`. It is `null` or `undefined` before the first submit, so read it as `form?.errors?.borrower`.
- Give every field a `<label>` and a `name`. Mark an invalid field with `aria-invalid`, and render its message in an element with `role="alert"` ([accessibility](../svelte-conventions/08-templates-styling-and-accessibility.md#accessibility)).
- Show a pending state with a customised `use:enhance`. The `SubmitFunction` type comes from `$app/forms`, and the callback that you return runs after the response. Call `update()` in it to keep the default behaviour:

```svelte
<script lang="ts">
  import { enhance, type SubmitFunction } from "$app/forms";

  let submitting = $state(false);

  const handleSubmit: SubmitFunction = () => {
    submitting = true;
    return async ({ update }) => {
      await update();
      submitting = false;
    };
  };
</script>

<form method="POST" use:enhance={handleSubmit}>
  <button type="submit" disabled={submitting}>Save</button>
</form>
```

- Pass `reset: false` to `update` to keep what the user typed after a failure, and `navigate: false` to keep a cross-page submit on the current page. Call `cancel()` in the submit function to stop a submission.
- Use `applyAction(result)` only when you replace the default behaviour. It sets `form` and `page.status` for `success` and `failure`, calls `goto` with `refreshAll` for `redirect`, and renders the nearest `+error.svelte` for `error`.
- In SvelteKit 3, an enhanced form response carries the status that you passed to `fail()`, not always 200, and an enhanced form whose `action` targets another page navigates to that page.
- Write a custom submit listener without `use:enhance` only when you must. Prevent the default, send the `FormData` with `fetch`, and decode the response with `deserialize` from `$app/forms`. `JSON.parse` loses the `Date` and `BigInt` values that actions support. Send the `x-sveltekit-action: true` header when a `+server` file lives beside the page.
- Use a `GET` form for a search or a filter. It navigates to the `action` URL and runs `load` with the new search parameters, and it invokes no action ([state in the URL](06-state-and-navigation.md#state-in-the-url)).
- Give a destructive action a confirmation step, and disable the submit button while a request runs, so a double click cannot submit twice.

### Endpoints

- Use `+server.ts` for a JSON API, a webhook or a file response, and use a form action for a form on a page. Write one exported function per method: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`.
- Validate the body of a request with a schema, as for a form: `const raw: unknown = await request.json()`. Answer with `Response.json(value, { status })` and use the status codes of the method. Return an error with `error(status, message)` or with a JSON body that follows the [TypeScript notes](../typescript-conventions/09-error-handling.md#errors-at-the-boundary).
- Check the user in every method that reads private data or changes data.
- A cross-origin `POST`, `PUT`, `PATCH` or `DELETE` is rejected by the CSRF protection unless its origin is in `csrf.trustedOrigins`. Do not turn the protection off ([hooks, errors and security](07-hooks-errors-and-security.md#csrf)).
- An endpoint is a public API. Version it when other programs depend on its body, and do not change a published body in place.

### Remote functions

- Do not use remote functions (`query`, `form`, `command`, `prerender` in `.remote.ts` files). They are experimental, they need `experimental.remoteFunctions` in the SvelteKit options and `compilerOptions.experimental.async` in Svelte, and the documentation says that the `experimental` namespace is not under semantic versioning, so breaking changes or removal can happen in any release.
- They also need `await` in components, which [the Svelte notes](../svelte-conventions/09-errors-and-async.md#async-in-components) do not use.
- Revisit this rule when they leave the experimental namespace. The documentation then prefers a remote `form` to a `command`, because it works without JavaScript, requires a Standard Schema validator for every argument, and requires authorisation inside each function.

## Sources and raw notes

Pages read on 2026-11-18:

- [Form actions](https://svelte.dev/docs/kit/form-actions): default and named actions, `POST` only, the `form` prop, `fail`, redirects, the rerun of `load`, `handle` not rerunning, `use:enhance` and its callbacks, `applyAction`, the custom listener with `deserialize` and `x-sveltekit-action`, `GET` forms, the `+server` alternative.
- [Migrating to SvelteKit 3](https://svelte.dev/docs/kit/migrating-to-sveltekit-3): enhanced responses use the status of `fail()`, enhanced forms with another page's `action` navigate, CSRF always on, `csrf.trustedOrigins`, `json()` deprecated.
- [Remote functions](https://svelte.dev/docs/kit/remote-functions): experimental since 2.27, the two flags, the function kinds, Standard Schema validation, authorisation inside each function, `form` before `command`.
- `@sveltejs/kit` 3.3.1 types: `SubmitFunction` is exported from `$app/forms` with `enhance`, `applyAction` and `deserialize`.
- Checked on 2026-11-18 in the sample application of the [principles note](01-principles-and-sources.md#sources-and-raw-notes): the action above, the `+page.svelte` that reads `form?.errors?.borrower`, and the `SubmitFunction` sample passed `svelte-check`, ESLint and Prettier. Importing `SubmitFunction` from `@sveltejs/kit` left `update` typed as `any`, and the import from `$app/forms` fixed it. On the built Node.js server a `POST` to `/loans` without an `Origin` header and one from `http://evil.example` both got 403 (`Cross-site POST form submissions are forbidden`).
- The `reset`, `navigate` and `cancel` options, and the advice on confirmation steps and double submits, come from the documentation and general practice, and the sample application did not exercise them.
