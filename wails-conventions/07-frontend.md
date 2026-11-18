# Wails Frontend

## Summary

The frontend is a plain Svelte app built with Vite into `frontend/dist`, and Wails embeds and serves it. Bring the template to the baseline of the Svelte notes, and call Go through one small client module per feature that wraps the generated bindings. The generated bindings are exempt from the lint, format and strict TypeScript rules, and the rest of the code is not.

## Rules

### Frontend baseline

- Use the `svelte` template (Svelte, TypeScript and Vite), and then bring `frontend/` to the baseline of the [Svelte notes](../svelte-conventions/02-project-setup-and-tooling.md). The template differs from that baseline in these ways, and each one is changed in the first commit:
  - `typescript` is `^5.2.2`. Use `~6.0.3`. `svelte` is `^5.46.4`, so use the version of the Svelte notes, and add `@tsconfig/svelte`, `@types/node`, `eslint`, `typescript-eslint`, `eslint-plugin-svelte`, `eslint-config-prettier`, `globals`, `prettier`, `prettier-plugin-svelte` and `vitest`.
  - One `tsconfig.json` with `allowJs` and `checkJs`. Use `tsconfig.json` with project references to `tsconfig.app.json` and `tsconfig.node.json`, with `checkJs` and `allowJs` off, and the options of the TypeScript notes.
  - `svelte.config.js` with `vitePreprocess`, which Svelte 5 does not need for TypeScript. Replace it with `export default { compilerOptions: { runes: true } }`.
  - `src/main.ts` with `document.getElementById('app')!`. Replace the `!` with a guard that throws.
  - No ESLint or Prettier. Add the config of the Svelte notes, and a `.prettierignore` with `bindings`, `dist` and `public`.
- Keep what Wails needs: `@wailsio/runtime` as a dependency with exactly the version of the Go module (`"3.1.0"`), the dev server settings in `vite.config.ts`, and the `wails("./bindings")` plugin:

```ts
import { svelte } from "@sveltejs/vite-plugin-svelte";
import wails from "@wailsio/runtime/plugins/vite";
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: "127.0.0.1",
    port: Number(process.env.WAILS_VITE_PORT) || 9245,
    strictPort: true,
  },
  plugins: [svelte(), wails("./bindings")],
});
```

- The only required Vite change for a Wails project is the dev server port, so that `wails3 dev` can find it. The `wails` plugin is needed only for typed custom events. Keep the port, the `strictPort` and the `127.0.0.1` host.
- Keep the scripts that the build tasks call: `build` (`vite build --mode production`) and `build:dev` (`vite build --minify false --mode development`). Add `check`, `lint`, `format:check` and `test` beside them, as in the Svelte notes.
- Set the aliases in `tsconfig.app.json` and let Vite read them: `"paths": { "@/*": ["./src/*"], "@bindings/*": ["./bindings/*"] }`. The sample project built and tested with both and with no Vite setting, because Vite 8 reads `paths` from the tsconfig.
- Add `bindings` to the tsconfig `include`, so that the type check covers the files that the code imports.
- Delete the template's demo (`App.svelte` styling, `public/style.css`, the logos and the background images) when you start your own interface. Keep `public/` for assets that must keep their names.
- The template's `.npmrc` sets `minimum-release-age`. npm ignores it and prints a warning, while pnpm and bun honour it. Keep it, or delete it if you use npm only.
- There is no server rendering. The Svelte notes' module-level `$state` is safe, and SvelteKit is not used: this is the case that [the Svelte notes](../svelte-conventions/01-principles-and-sources.md) cover.

### TypeScript and generated code

- Exclude `frontend/bindings/` from ESLint (`globalIgnores(["dist/**", "bindings/**"])`) and from Prettier. The generated files carry `eslint-disable` and `@ts-ignore` comments of their own, and are rewritten on every build.
- The generator writes `export enum` for a Go enum type, and `erasableSyntaxOnly` rejects that: `svelte-check` reported `This syntax is not allowed when 'erasableSyntaxOnly' is enabled` for `models.ts`. Turn `erasableSyntaxOnly` off in the frontend's `tsconfig.app.json`, and keep the rule for hand-written code with ESLint:

```js
rules: {
  "no-restricted-syntax": [
    "error",
    { selector: "TSEnumDeclaration", message: "Use a string-literal union, not enum." },
    { selector: "TSParameterProperty", message: "Declare the field and assign it." },
    { selector: "TSImportEqualsDeclaration", message: "Use ES imports." },
    { selector: "TSExportAssignment", message: "Use ES exports." },
  ],
},
```

- A hand-written `enum` and a parameter property then fail the lint, and a generated `enum` does not, because `bindings/**` is ignored. In the sample project the rule reported both on a scratch file.
- Use a generated enum freely. `Status.StatusPaid` in a `.svelte` file passed `svelte-check`, ESLint and `vite build`, because the import is an ordinary ES import and Vite compiles the `enum` in the generated `.ts` file. Write your own unions as string literals and not as `enum`.
- Do not edit a file in `bindings/`. Change the Go source and regenerate.

### Calling Go

- Import the generated bindings in one module per feature (`src/lib/loans/loan-client.ts`) and nowhere else. Components call the client module and never `@bindings/...` directly. The client module is the seam where you hide the generator's shapes, and the place that tests replace:

```ts
import { Service as LoanService, type Loan } from "@bindings/example.com/loansapp/internal/loan";

export type { Loan };

export async function listLoans(): Promise<Loan[]> {
  return (await LoanService.List()) ?? [];
}

export async function createLoan(borrower: string, amountMinor: number): Promise<Loan> {
  return LoanService.Create(borrower, amountMinor);
}
```

- The binding of a service in package `loan` is exported as `Service`. Alias it on import (`Service as LoanService`) so that two features do not collide.
- Turn a `T[] | null` result into `T[]` in the client module (`?? []`). Go sends a nil slice as `null`, and the generator types every slice result as nullable.
- Convert `createdAt` strings once. The generator types `time.Time` as `string` (an RFC 3339 value). Convert with `new Date(value)` where you format it, or generate `Date` values with `-time-type=Date` for the whole project, and do not mix the two ([services and bindings](05-services-and-bindings.md#models-and-enums)).
- Do not add a runtime schema for a reply of your own service. The generator writes the TypeScript from the Go source, which is one source of truth for the type, and validation lives in Go. Treat data from other sources (a file the user picks, a network call from the frontend) as `unknown`, as the [TypeScript notes](../typescript-conventions/05-runtime-validation-and-external-data.md) require.
- A call returns a `CancellablePromise`. Call its `cancel()` to cancel a call that is no longer needed, such as a search that the user has typed over, and the Go method's context is cancelled.
- Handle a failed call where the user acts: catch the rejected promise in the handler that started it, log it with `console.error`, and show a message in the page. A rejected call is an `Error` with the Go message, a `cause` with the serialised Go error and a `name` of `RuntimeError` when Go returned the error. Use `error instanceof Call.RuntimeError` from the runtime package to tell it from a failed call ([services and bindings](05-services-and-bindings.md#errors)).
- Do not show `error.message` of an unexpected failure. Show a fixed message, and log the rest.
- Do not call a method in a loop. Ask for a batch ([services and bindings](05-services-and-bindings.md#bindings)).
- Load data in an effect or an event handler and keep the result in `$state.raw`, as the Svelte notes say. A method call is async, so use the request-state union of the Svelte notes for loading and failure:

```svelte
<script lang="ts">
  import { createLoan, listLoans, type Loan } from "@/lib/loans/loan-client";

  let loans = $state.raw<Loan[]>([]);
  let status = $state<"loading" | "ready" | "failed">("loading");

  async function refresh(): Promise<void> {
    try {
      loans = await listLoans();
      status = "ready";
    } catch (error) {
      console.error(error);
      status = "failed";
    }
  }

  $effect(() => {
    void refresh();
  });
</script>
```

### Events and windows from the frontend

- Subscribe to Go events through one function per event in the client module of the feature, typed by the generated constant, and unsubscribe when the component goes away. Return the unsubscribe function from an `$effect`:

```svelte
<script lang="ts">
  import { onLoanCreated } from "@/lib/loans/loan-client";

  let { onCreated }: { onCreated: () => void } = $props();

  $effect(() => onLoanCreated(onCreated));
</script>
```

- Use the runtime package for what Go owns: `Events`, `Dialogs`, `Window`, `Browser`, `Clipboard`, `Screens` and `System`. Import them in the client modules and the few components that need them, and not across the tree.
- Open a link in the user's browser with `Browser.OpenURL(url)` from `@wailsio/runtime`, and not an `<a target="_blank">`, which a webview does not open the way a browser does. Put it behind a real `<button>` or an `<a href>` with an `onclick` that calls it and prevents the default.
- The template's footer link uses `data-wml-openURL` on an `<a>` without an `href`, which `svelte-check` warns about (`a11y_missing_attribute`). Replace it with the call above.
- Do not call the application's lifecycle (`Quit`) from deep in the tree. Put it in a bound method or a menu item.

### Routing and structure

- Start with one view. Add routing when a second view exists. A desktop webview is not a browser, so a history-based router can conflict with the Wails runtime, and the Wails routing guide recommends hash-based routing. Keep the router as small as the app: a `$state` for the current view is enough for two or three screens.
- The routing guide names `svelte-spa-router` for Svelte. Check that the version you choose supports Svelte 5 and runes before you adopt it.
- Do not use SvelteKit for a Wails frontend. It would need `adapter-static` in SPA mode, which brings the costs that the [SvelteKit notes](../sveltekit-conventions/10-deployment-and-adapters.md#static-sites) list, and gains nothing in a client-only app.
- Organise the source by feature as the [Svelte notes](../svelte-conventions/03-project-layout-and-naming.md#where-code-lives) say. A feature folder holds its components, its `.svelte.ts` state and its client module.

### Assets and styling

- Bundle everything. Put fonts, icons and images in the source and import them, or in `public/` when a name must stay, and load nothing from a CDN. A desktop application works offline, and a remote asset is a dependency on the network and a risk.
- Style with the Svelte notes: scoped `<style>`, custom properties on `:root`, no framework without a reason. Use `prefers-color-scheme` for light and dark, and the native backdrop options of the window where the design wants them.
- Make a drag region for a frameless window with the CSS property `--wails-draggable: drag`, and mark the controls inside it with `--wails-draggable: no-drag`, as the frameless window page says.
- Test in the real webviews. They are WebKit on macOS and Linux and WebView2 (Chromium) on Windows. Check a new CSS or browser API against the oldest of them before you rely on it.

### Frontend tests

- Follow the [Svelte testing note](../svelte-conventions/10-testing.md). Test the client modules as plain functions with the generated binding mocked at its module boundary, and test components with `vitest-browser-svelte`. The Go bindings are an allowed boundary to mock, like the network:

```ts
const list = vi.hoisted(() => vi.fn<() => Promise<unknown[] | null>>());

vi.mock("@bindings/example.com/loansapp/internal/loan", () => ({
  Service: { List: list, Create: vi.fn() },
}));

it("turns a null list from Go into an empty array", async () => {
  list.mockResolvedValue(null);

  expect(await listLoans()).toEqual([]);
});
```

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Frontend frameworks](https://wails.io/guides/dev/frontend-frameworks/): the frontend is just a web project, `frontend/dist` is what ships and is embedded, the Vite port is the only required change, and the runtime plugin is optional for typed events. [Project structure](https://wails.io/guides/dev/project-structure/): `frontend/bindings/` and `vite.config.ts`. [Routing](https://wails.io/guides/routing/): hash-based routing for Vue, Angular, React and `svelte-spa-router` for Svelte. [Frontend runtime](https://wails.io/reference/frontend-runtime/): the runtime API.
- `@wailsio/runtime` 3.1.0 types (`types/index.d.ts`): `Application`, `Browser`, `Call`, `Clipboard`, `Dialogs`, `Events`, `Flags`, `Screens`, `System`, `Window`, `WML` and the cancellable promise exports. `Browser.OpenURL(url: string | URL): Promise<void>`.
- The `svelte` template of `wails3` v3.1.0 wrote `typescript ^5.2.2`, `svelte ^5.46.4`, `vite ^8.2.4`, `@sveltejs/vite-plugin-svelte ^7.0.0`, `@wailsio/runtime 3.1.0`, a `tsconfig.json` with `allowJs` and `checkJs`, `svelte.config.js` with `vitePreprocess`, a `.npmrc` with `minimum-release-age=10080`, and `src/App.svelte` that imports `../bindings/example.com/loansapp`. `vite build` of the template printed `a11y_missing_attribute` for its footer link.
- Checked on 2026-11-18 in the sample project with Svelte 5.58.0, Vite 8.3.8, TypeScript 6.0.3, ESLint 10.15.0 and Vitest 5.1.1: the converted frontend passed `svelte-check` with `--fail-on-warnings`, `tsc -p tsconfig.node.json`, ESLint, `prettier --check`, `vite build` and the Vitest test above, and `wails3 build` embedded the result. With `erasableSyntaxOnly` on, `svelte-check` failed on the generated `models.ts`. With it off and the `no-restricted-syntax` rule on, ESLint reported a hand-written `enum` and a parameter property, and passed the project without them.
- The hash-routing advice, the `svelte-spa-router` suggestion, `Browser.OpenURL`, the cancellation of a call, the drag regions (the frameless window page) and the webview differences come from the documentation pages above and were not run, because the sample application was not started.
