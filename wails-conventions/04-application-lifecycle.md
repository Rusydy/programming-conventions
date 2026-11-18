# Wails Application Lifecycle

## Summary

`main` calls `run`, and `run` builds the logger, the services and the application by hand, opens the window and blocks in `app.Run()`. Services open their resources in `ServiceStartup` and release them in `ServiceShutdown`. Set a panic handler that logs, keep startup fast, and give every background goroutine the context that Wails cancels at shutdown.

## Rules

### `main` and `run`

- Follow the [Go notes](../golang-conventions/04-project-layout.md#keep-main-thin): `main` calls `run(ctx, args, getenv, stdout, stderr)` and turns the returned error into an exit code. `os.Exit` and `log.Fatal` appear only in `main`. The template writes `log.Fatal(err)` after `app.Run()` in `main`, so move that into `run`'s return value.
- Name every parameter and result of `run`, as the Go notes require:

```go
func main() {
	err := run(context.Background(), os.Args[1:], os.Getenv, os.Stdout, os.Stderr)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string, getenv func(key string) (value string), stdout, stderr io.Writer) (err error) {
	logger := slog.New(slog.NewTextHandler(stderr, &slog.HandlerOptions{Level: slog.LevelInfo}))

	// Registering the event here lets the binding generator type it for the frontend.
	application.RegisterEvent[loan.Loan](loan.EventCreated)

	app := application.New(application.Options{
		Name:        "loansapp",
		Description: "Track loans",
		Logger:      logger,
		Assets:      application.AssetOptions{Handler: application.AssetFileServerFS(assets)},
		Mac: application.MacOptions{
			ApplicationShouldTerminateAfterLastWindowClosed: true,
		},
	})

	loans := loan.NewService(logger, appPublisher{app: app}, func() (current time.Time) { return time.Now() })
	app.RegisterService(application.NewService(loans))

	app.Window.NewWithOptions(application.WebviewWindowOptions{
		Title:  "Loans",
		Width:  1000,
		Height: 618,
		URL:    "/",
	})

	if err = app.Run(); err != nil {
		return fmt.Errorf("run application: %w", err)
	}
	return nil
}
```

- Build everything in `run` and pass it down through constructors. Keep the dependencies in no global variable, and call no `init()`. The Wails template registers an event in `init()` and keeps `app` in a local of `main`. This set does the first at the start of `run` ([events and windows](06-events-and-windows.md#events)).
- Create the application with `application.New` once, and call `app.Run()` last. It blocks until the application exits and returns an error.
- Give the application a `Name` and a `Description`. They are metadata for the platform.
- Pass `Options.Logger` the same `*slog.Logger` that the services use, so Wails and your code log through one handler. Set `LogLevel` for the Wails messages.
- Take the configuration from `getenv` and defaults in code, as the [Go notes](../golang-conventions/11-service-practices.md#application-wiring) say. A desktop application has two more sources: a settings file that the user changes through the UI, in the folder from `os.UserConfigDir()`, and the product information in `build/config.yml`. Never read a secret from a file in the repository.
- Keep `args` for developer flags only. A double-clicked application gets none.
- Write logs to a file in the user's folders in production, because a double-clicked application has no terminal, and to `stderr` in development. Send one record to both with `slog.NewMultiHandler` (Go 1.26).

### Services

- Register services in `Options.Services` with `application.NewService(value)`. When a service needs the `*application.App`, create the application first and call `app.RegisterService(application.NewService(value))`, as the sample above does. Prefer a small interface owned by the service for what it needs from Wails, such as publishing an event, so that the domain code does not import `application` ([services and bindings](05-services-and-bindings.md#services)).
- Register at most one service per Go type. When two instances of one type are needed, give each a distinct wrapper type. `ServiceOptions.Name` only names the service in logs, and does not change the generated binding.
- Register a service before the services that depend on it. Services start in registration order and shut down in reverse.
- A service is a singleton that every window shares, so it needs its own locking. Guard the shared state with a named `sync.Mutex` field and never embed it, as the Go notes say.
- Implement the two lifecycle methods when the service owns a resource. Both are optional, and Wails finds them by name:

```go
// ServiceStartup is called by Wails when the application starts.
func (s *Service) ServiceStartup(ctx context.Context, options application.ServiceOptions) (err error)

// ServiceShutdown is called by Wails when the application stops.
func (s *Service) ServiceShutdown() (err error)
```

- Open files, database handles and connections in `ServiceStartup`, and close them in `ServiceShutdown`. Return an error from `ServiceStartup` to stop the application from starting. An error from `ServiceShutdown` is logged as a warning and does not stop the shutdown.
- Keep `ServiceStartup` fast: under about two seconds, as the lifecycle page advises. Start slow work in a goroutine and report its progress with an event.
- Start a background goroutine from `ServiceStartup` with the `ctx` that it receives, and end it when `ctx.Done()` fires. The context is cancelled at shutdown before `ServiceShutdown` runs, so wait for the goroutines there, as the [Go concurrency note](../golang-conventions/09-concurrency-and-context.md#context) says.
- A service that never needs the lifecycle needs no methods at all, and `application.NewService(&Calculator{})` is enough.
- Do not use the documentation's examples that open a database in `ServiceStartup` and ignore `ctx`, or that expire a cache with `time.Sleep` in a goroutine per key. Use `ctx` and a ticker.

### Hooks and options

- Use the application options for the hooks, and name the results of a function literal like any other: `ShouldQuit: func() (quit bool) { ... }`, `OnShutdown: func() { ... }`, `PostShutdown: func() { ... }`.
- `ShouldQuit` decides whether a quit request goes ahead, for an unsaved-changes prompt. `OnShutdown` runs before the application quits, for cleanup. `PostShutdown` runs after everything is closed, so use it only for final logging and call no window, dialog or other application feature in it.
- Do not show a dialog in `OnShutdown`: the application is quitting, and the interface may no longer work. Ask in `ShouldQuit` instead.
- Set `Mac.ApplicationShouldTerminateAfterLastWindowClosed` to `true` for a window application. A tray application that keeps running hides its window instead of closing it ([events and windows](06-events-and-windows.md#windows)).
- Handle a second launch with `SingleInstance` when the application opens files from the command line or the system, as the guide describes. Set a reverse-domain `UniqueID`, and bring the existing window forward from `OnSecondInstanceLaunch` with `Restore()` and `Focus()`:

```go
SingleInstance: &application.SingleInstanceOptions{
	UniqueID: "com.example.loansapp",
	OnSecondInstanceLaunch: func(data application.SecondInstanceData) {
		if window == nil {
			return
		}
		window.Restore()
		window.Focus()
	},
},
```

- Set `SingleInstance.EncryptionKey` to a 32-byte key that is unique to your application when the second instance passes data. Without a key the data between instances is not protected. Never use the example key of the documentation, and load yours from a place that is not the repository.
- Leave `DisableDefaultSignalHandler` at its default, so that `SIGINT` and `SIGTERM` end the application normally.

### Panics and errors

- A bound method that returns an error rejects the promise on the frontend. A bound method that panics is recovered by Wails and goes to the panic handler, which by default logs a formatted message and quits the application ([services and bindings](05-services-and-bindings.md#errors)).
- Set `Options.PanicHandler` to log the panic through `slog` with its error and stack trace, so the report reaches your log file. `PanicDetails` has `Error`, `StackTrace`, `Time` and `FullStackTrace`:

```go
PanicHandler: func(details *application.PanicDetails) {
	logger.Error("panic in a bound method", "error", details.Error, "stack", details.StackTrace)
},
```

- Wails recovers panics only in bound service methods and in the runtime paths that install its recovery. It does not recover a goroutine that you start. Put `defer` and `recover` at the top of every long-lived goroutine, convert the panic to an error, and log it, as the [Go notes](../golang-conventions/08-error-handling.md#panics-and-exits) allow at a boundary.
- Do not panic for an expected failure. Return an error, as the Go notes say, and give it a type or a sentinel that the caller can test.
- Set `ErrorHandler` and `WarningHandler` to log what the runtime reports, so that it reaches the same log file.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Application lifecycle](https://wails.io/concepts/lifecycle/): the stages, services, `ShouldQuit`, `OnShutdown`, `PostShutdown` and its note not to use application features, window hooks, and the do-not list (do not block startup, do not ignore the context, always implement `ServiceShutdown`). [Services](https://wails.io/features/bindings/services/): `ServiceStartup` and `ServiceShutdown`, registration and reverse shutdown order, singletons and locking, `ServiceOptions.Name`, one service per Go type with wrapper types, `app.RegisterService`.
- [Panic handling](https://wails.io/guides/panic-handling/): panics in bound methods are recovered, the default handler logs and quits, `PanicDetails`, and the rule that other goroutines handle their own panics. [Single instance](https://wails.io/guides/single-instance/): `SingleInstanceOptions`, `UniqueID`, `EncryptionKey` as an optional 32-byte AES-256-GCM key, the callback and the window methods.
- `wails/v3@v3.1.0` source, `pkg/application/application_options.go`: `Options` has `Name`, `Description`, `Services`, `MarshalError`, `Logger`, `LogLevel`, `Assets`, `PanicHandler`, `DisableDefaultSignalHandler`, `OnShutdown`, `PostShutdown`, `ShouldQuit`, `ErrorHandler`, `WarningHandler`, `SingleInstance` and the platform options. `single_instance.go`: `SingleInstanceOptions{UniqueID, OnSecondInstanceLaunch, AdditionalData, ExitCode, EncryptionKey [32]byte}`.
- Checked on 2026-11-18 in the sample project: the `run` function above, with `PanicHandler`, `OnShutdown`, `SingleInstance` and `app.RegisterService`, passed `gofmt`, `go vet`, `go test -race` and `wails3 build`. The window opens only on a desktop, so the application was built but not run.
- The behaviour of the lifecycle hooks, the panic handler and the single-instance lock was not exercised, because the sample application was not started. The advice on log files and on `slog.NewMultiHandler` comes from the Go notes and general practice.
