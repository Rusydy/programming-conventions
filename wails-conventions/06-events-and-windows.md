# Wails Events and Windows

## Summary

Use a bound method for a request and an event for a notification. Register each custom event with its data type at the start of `run`, give it a constant name, and let the generator type it for the frontend. Create windows in `run` or from a service through the application, give each a name, and keep their number small.

## Rules

### Events

- Use an event for a one-way notification: progress, a change that happened, a state that other windows must learn. Use a bound method for anything that needs an answer. The documentation says the same: do not use events for remote procedure calls, for large data, or in loops where A emits B and B emits A.
- Register every custom event once, with its data type, before the application starts. Call `application.RegisterEvent[T](name)` directly with a constant name, at the start of `run`:

```go
// EventCreated is the name of the event that Service publishes for a new loan.
const EventCreated = "loan:created"

func run(ctx context.Context, args []string, getenv func(key string) (value string), stdout, stderr io.Writer) (err error) {
	// Registering the event here lets the binding generator type it for the frontend.
	application.RegisterEvent[loan.Loan](loan.EventCreated)
	// ...
}
```

- The documentation and the template register events in `init()`. The Go notes ban `init()`, and the generator reads the call from `run` as well. In the sample project both forms gave `1 Event`. The generator can only find a call that is direct and has constant arguments, so do not wrap `RegisterEvent` in a helper and do not pass a variable. A constant from another package, such as `loan.EventCreated`, is a constant argument.
- Registering the same name twice with the same type is safe, and with a different type panics.
- Define the name as an exported constant next to the type that it carries, and use the constant for both the registration and the `Emit`. Do not type the same string in two places.
- Name an event in lower case with a namespace and a colon, and kebab-case words after it: `loan:created`, `import:progress`. The documentation asks for consistent kebab-case names, and its reference uses names such as `user:login`.
- Emit with the application's event manager: `app.Event.Emit(name, data)`. Data of a registered event must match the registered type exactly, and a mismatch is logged and the event is not delivered. Emit a value, not a pointer, unless you registered a pointer type.
- Let a service emit events through an interface that it owns, and not through `*application.App` ([services and bindings](05-services-and-bindings.md#services)). `main` implements the interface in a few lines:

```go
// appPublisher sends events through the Wails application.
type appPublisher struct {
	app *application.App
}

// Publish implements loan.Publisher.
func (p appPublisher) Publish(name string, payload loan.Loan) {
	p.app.Event.Emit(name, payload)
}
```

- Listen in Go with `app.Event.On(name, func(event *application.CustomEvent) { ... })`. It returns a function that removes the listener. Each handler runs one event at a time and in order, handlers do not wait for each other, and `Emit` never waits for handlers, so keep handlers short and do not block in them.
- A cancellable hook runs before the listeners and can stop the event. Use a hook only for validation or flow control, and a plain listener for everything else.
- Listen on the frontend with the runtime package, and use the constant that the generator writes into `frontend/bindings/events`, so that the data is typed. In the sample project `Events.On(LoanCreated, (event) => ...)` gave `event.data` the type `Loan`, and assigning it to a `number` failed `svelte-check`:

```ts
import { Events } from "@wailsio/runtime";

import { LoanCreated } from "@bindings/events";

export function onLoanCreated(handler: (loan: Loan) => void): () => void {
  return Events.On(LoanCreated, (event) => {
    handler(event.data);
  });
}
```

- Always remove a frontend listener when its component is destroyed. `Events.On` returns the function to call, and the Svelte way is to return it from an `$effect` ([frontend](07-frontend.md#events-and-windows-from-the-frontend)).
- Do not emit more often than the interface can show. Batch updates, debounce the source, and send a summary and not every step of a loop.
- Do not send a large payload in an event. Send an identifier and let the frontend call a method for the data.
- Do not subscribe to the application's system events (`events.Common.*`) from the frontend for anything that Go can handle. Handle the window and application lifecycle in Go.

### Windows

- Create the first window in `run` after the application and the services, with `app.Window.NewWithOptions(application.WebviewWindowOptions{ ... })`. Set `Title`, `Width`, `Height` and `URL: "/"`. Give a window a `Name` as soon as the code needs to find it again.
- Keep the number of windows small. Add a second window for a real need such as a settings window or a document, not for a view that a route in the same window can show.
- Services and the application are shared by every window. A window gets its state from the same services, so keep per-window state in the frontend and shared state in a service.
- Find windows with the window manager: `app.Window.GetByName(name)`, `Get`, `GetByID`, `Current()` and `GetAll()`. Use `OnCreate` to react when a window appears. Do not keep your own map of windows, which leaks when a window closes.
- Open a second window for one purpose only once. A "singleton window" is a name lookup, then `Show` and `Focus` when it exists, and creation when it does not.
- Hide instead of close for a tray application or one that keeps running, with a hook on the closing event. Compile-checked in the sample project:

```go
window.RegisterHook(events.Common.WindowClosing, func(event *application.WindowEvent) {
	window.Hide()
	event.Cancel()
})
```

- Ask before closing a window with unsaved work by cancelling the closing event in a hook, not by a dialog in `OnShutdown`.
- Set `Mac.ApplicationShouldTerminateAfterLastWindowClosed: true` for an application that ends with its last window, and leave it off for a tray application.
- Set the window's `BackgroundColour` to the colour of the page, so that no white flash shows before the page loads. Use the platform options (`Mac`, `Windows`, `Linux`) from the window options page for the title bar and the translucency, and keep them to what the design needs.
- Leave `DevToolsEnabled` off in a release build. Turn it on in development only.
- Do not load a remote URL into a window. The window is a boundary for your own frontend ([security](08-security.md#the-webview)).
- Remove references to a window when it closes, and do not hold a `*WebviewWindow` in a service for longer than the call that needs it.

### Menus, dialogs, tray and the rest

- Add a menu, a tray icon, a dialog or a shortcut only when the product needs it. Each is a feature that you then own on three platforms.
- Use the native dialogs from the application's dialog manager for file selection and messages, and not a custom web dialog, when the user is choosing a file or confirming a destructive action. Validate the path that the dialog returns in Go before you use it ([security](08-security.md#files)).
- Build menus and tray menus in Go in `run`, give each item a handler function and a label, and use the standard roles (copy, paste, quit) that the platform expects.
- Use `app.Event` and the window manager for communication between windows. Do not reach into another window's page.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Event system](https://wails.io/features/events/system/): emit and listen in Go and JavaScript, system, window and custom events, delivery order, hooks, the do and do-not list (use events for notifications and bindings for requests, kebab-case names, unsubscribe, no loops, no large data). [Events guide](https://wails.io/guides/events-reference/): `application.RegisterEvent` at init time, panics for invalid arguments or two types for one name, safe to register twice with the same type, type checking on `Emit`.
- [Lifecycle](https://wails.io/concepts/lifecycle/): window hooks, `ShouldQuit`, hide instead of close, the multi-window lifecycle. [Window basics](https://wails.io/features/windows/basics/) and [multiple windows](https://wails.io/features/windows/multiple/): creation, named windows, the window registry and singleton patterns, communication through events, memory management.
- `wails/v3@v3.1.0` source: `RegisterEvent`'s doc comment recommends a direct call with constant arguments, from init functions, and says that indirect calls or instantiations are not discoverable by the binding generator. `EventManager` has `Emit`, `EmitEvent`, `On` (returns a remove function), `Off`, `OnMultiple`, `Reset`, `OnApplicationEvent` and `RegisterApplicationEventHook`. `WindowManager` has `GetByName`, `Get`, `GetByID`, `OnCreate`, `New`, `NewWithOptions`, `Current`, `Add`, `Remove`, `RemoveByName` and `GetAll`. `events.Common.WindowClosing` exists.
- Checked on 2026-11-18 in the sample project: `RegisterEvent[loan.Loan](loan.EventCreated)` inside `run` and inside `init()` both gave `1 Event` from `wails3 generate bindings`, and wrote `export const LoanCreated = "loan:created"` in `frontend/bindings/events/index.ts`. `Events.On(LoanCreated, (event) => event.data)` typed `event.data` as `Loan`. The `WindowClosing` hook compiled and passed `go vet`. The `Emit` of the sample's publisher compiled, and the unit test checked the service against a recording publisher.
- No window was opened, because the sample application was only built. The hide-on-close hook, the singleton window pattern, the order of events and the dialogs were not run. The naming rule for events combines the documentation's kebab-case advice with the colon namespaces of its reference.
