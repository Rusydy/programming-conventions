# Wails Security

## Summary

Every exported method of a registered service is an entry point that any script in the webview can call. Treat the page as a client that you do not fully trust: keep the service surface small and domain-shaped, validate every argument in Go, and never expose a method that takes a path, a command or a query. Load only your own bundled frontend, keep secrets in the operating system's keychain, and sign what you ship.

## Rules

### The webview

- Load only the frontend that you bundle. Serve it from the embedded assets (`application.AssetFileServerFS(assets)`), and do not set a remote `URL` on a window, because a window that loads someone else's page gives that page the same bridge to your Go code that your own frontend has.
- Assume that script injection is possible, and limit what it could do. A cross-site scripting hole in the page lets the attacker call every exported method of every registered service with any arguments. The Svelte notes keep that unlikely (no `{@html}` of untrusted text, a strict lint), and the notes below keep it harmless.
- Expose operations of the domain, not general tools. Never write a bound method that takes a file path to read or write, a shell command, a URL to fetch, a SQL string or a Go template, however convenient it would be. A method such as `ExportLoans(format Format)` is safe, and `ReadFile(path string)` hands the disk to the page.
- Keep the surface small. Every exported method is public API, as the [services note](05-services-and-bindings.md#services) says. Review the generated `frontend/bindings` in each pull request, because that file lists exactly what the frontend can call.
- Do not rely on `//wails:ignore` or `//wails:internal` to protect a method. They remove the generated wrapper, and the documentation says they are not an access-control boundary for exported service methods.
- Keep `AllowSimpleEventEmit` off for every window. It lets any script in the page fire the handlers that you registered for custom events, by name. Turn it on only for a window that shows HTML that you wrote in the project, as the documentation's updater window does.
- Handle a raw message with `RawMessageHandler` only when you have no better way, and check the `OriginInfo` and the content of every message.
- Leave `DevToolsEnabled` off in a release build, and keep a build that has it on for development.
- Do not use the content security policy of a web server as your only guard. The documentation does not describe a policy for the asset server, so rely on the rules above, and add a policy only after you have checked that the asset handler and the webview apply it.

### Input and output

- Validate in Go, as the [services note](05-services-and-bindings.md#validation) says: trim, check required fields, bound lengths and ranges, and check that identifiers exist. Reject with an error whose message is safe to show.
- Store text as the user typed it. The Wails guides call `html.EscapeString` on input before saving, and this set does not follow that: Svelte escapes text when it renders `{value}`, so a value that was escaped on the way in is shown as `&amp;lt;`, and it is also wrong for every other consumer of the data, such as an export. Escape at the place of output.
- When Go builds HTML, use `html/template`, never `text/template`, as the Go notes say. Do not build HTML by hand in a service and send it to the page to render with `{@html}`.
- Limit the size of every input, and set a timeout on every call that leaves the process, as the Go notes say. Paginate every list that can grow ([services and bindings](05-services-and-bindings.md#bindings)).
- Do not return more than the interface needs. Send a view type without password hashes, tokens, internal paths or other users' data.

### Files

- Accept a name or an identifier from the frontend, and map it to a path in Go. Choose the directory in trusted Go code, never from the frontend.
- Confine file access that depends on a name with `os.OpenRoot` (Go 1.24 and later), as the Go notes and the Wails security guide say: open the directory once and read through the returned `os.Root`, which also stops a symbolic link from leaving it. A check for `..` or for a string prefix alone is not a boundary.

```go
func readFile(allowedDir, name string) (data []byte, err error) {
	root, err := os.OpenRoot(allowedDir)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	return root.ReadFile(name)
}
```

- Let the user choose a file with the native dialog from the application's dialog manager, and read the file in Go. A path from a dialog is one that the user chose on purpose. Check the size and the type of the file before you parse it.
- Treat a path that arrives from a file drop or from a file association the same way: it came from the user, and it still needs the size, type and content checks.
- Keep application data in the folders of the platform: `os.UserConfigDir()`, `os.UserCacheDir()` and the user's data folder. Create files with the narrowest permissions (`0o600`) when they hold anything private.

### Secrets

- Keep passwords, API keys and tokens out of the source, the repository, the logs, the error messages and the frontend. Store a secret the application must keep in the operating system's keychain, for example with `github.com/zalando/go-keyring` as the security guide shows, and not in a settings file.
- Never put a secret in the frontend bundle or in a binding result. A secret in the page is a secret that any script in the page can read.
- Use `crypto/rand` for tokens and keys, and compare secrets in constant time, as the Go notes say.
- Implement `slog.LogValuer` on a type that holds a secret, so that logging it prints `[redacted]`.
- Obfuscated builds (`garble`) make reverse engineering harder and do not protect a secret that the binary contains. Do not hide a key in the binary.
- If the application has accounts, hash passwords with a slow, salted function such as bcrypt (as the Wails guide shows) or argon2id, never a plain hash, and never log them. If it encrypts local data, use an AEAD such as AES-GCM with a fresh random nonce per message and a key that is kept apart from the data. The guide uses `cipher.NewGCMWithRandomNonce`, which makes the nonce for you.

### Network and updates

- Call only `https` URLs, keep the default TLS settings, never set `InsecureSkipVerify` and never lower `MinVersion`, as the Go notes say. Give every `http.Client` a timeout, and refuse a redirect to a non-HTTPS URL.
- Do not add a rate limiter for calls from your own window. The user is the only caller. Limit what you send to other services.
- Sign what you ship. Sign and notarise on macOS, sign the executable and the installer on Windows, and sign the Linux packages ([build and distribution](10-build-and-distribution.md#signing)). Keep private keys and certificate files out of version control, as the signing guide says.
- If the application updates itself, use the signed-artifact path of the updater: a release with a cryptographic signature that the application verifies against a public key that ships in the binary. A release with only a digest is authenticated by no more than the transport, and the updater guide says so. Keep the signing key outside the repository and outside the CI logs.
- Give a second instance's data an `EncryptionKey` when it carries anything private ([application lifecycle](04-application-lifecycle.md#hooks-and-options)).
- Run `govulncheck` on the Go packages and review the lock file of the frontend. Update the Go toolchain, Wails and the frontend dependencies when a security release appears, and keep the `minimum-release-age` setting of the template for pnpm and bun.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Security best practices](https://wails.io/guides/security/): input validation, bcrypt, sessions, `NewGCMWithRandomNonce`, the keychain with `go-keyring`, HTTPS and TLS, `os.OpenRoot` for file confinement, rate limiting, and the checklist. [Bindings best practices](https://wails.io/features/bindings/best-practices/): validate on the Go side and sanitise. [Advanced binding](https://wails.io/features/bindings/advanced/): `//wails:ignore` and `//wails:internal` are not access control.
- [Updater](https://wails.io/guides/updater/): `AllowSimpleEventEmit` and its warning for pages that you do not fully control, cryptographic verification, the digest-only caveat, and keeping the signing key out of version control. [Single instance](https://wails.io/guides/single-instance/): the optional encryption key. [Application API](https://wails.io/reference/application/): `RawMessageHandler` and `OriginInfo`. [Window options](https://wails.io/features/windows/options/): `URL` can load an external address, and `DevToolsEnabled`. [Signing](https://wails.io/guides/build/signing/): keep private key files outside version control.
- [Go notes](../golang-conventions/11-service-practices.md#security-basics): `crypto/rand`, constant-time comparison, TLS defaults, `os.OpenRoot`, `html/template`, secrets out of logs, input limits, `govulncheck`.
- The statement that a script in the page can call every exported method of every registered service is the documented contract of the bridge. It was not exploited in the sample project, which was not started. The advice on which methods never to expose, on escaping at the output and on the content security policy is this set's own reasoning from that contract, and the documentation does not say it in these words.
