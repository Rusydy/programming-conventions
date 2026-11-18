# Wails Build and Distribution

## Summary

Build with `wails3 build` and package with `wails3 package`, both of which run the Taskfiles in the project. Set the product information in `build/config.yml` before the first release, build each platform on that platform where you can, and sign and notarise every release. Keep the build steps visible in the Taskfiles, change them there, and run the checks and the end-to-end test in CI before any package is built.

## Rules

### Building

- Develop with `wails3 dev`. It builds a development binary, starts the Vite dev server in the background and runs the application, and it stops its background processes when the application exits. The settings are the `dev_mode` section of `build/config.yml`, and the Vite port is set by `WAILS_VITE_PORT` (default 9245). The documentation says it also regenerates the bindings when Go code changes.
- Build a release binary with `wails3 build`. On macOS in the sample project it installed the frontend dependencies, regenerated the bindings, built the frontend with `vite build --mode production`, and ran `go build -tags production -trimpath -buildvcs=false -ldflags="-w -s" -o bin/loansapp`. The result was a 9.2 MB binary in `bin/`.
- Keep those flags. `production` selects the release code paths, `-trimpath` and `-buildvcs=false` keep the build reproducible and free of local paths, and `-w -s` strips debug data. Change the build in the Taskfile, as the [build customisation guide](https://wails.io/guides/build/customization/) says, and not with a wrapper script around it.
- Package with `wails3 package`. On macOS it builds, creates `bin/<name>.app` with the `Info.plist`, the icons and the binary, and ad-hoc signs it. In the sample project the result passed `codesign --verify --deep --strict`. The ad-hoc signature is for local runs only, and a release is signed with a real identity ([signing](#signing)).
- Run `wails3 task` with a task name for anything else. `wails3 task --list` shows what the project defines, including `build:server`, `build:docker`, the signing tasks and the platform packaging tasks.
- Set the product information in `build/config.yml` before the first release: `companyName`, `productName`, `productIdentifier`, `description`, `copyright`, `comments`, `version`. The scaffolded values flow into the bundle. In the sample project the packaged `Info.plist` carried `CFBundleName` `My Product`, the copyright `© 2026, My Company` and the comment `This is a comment` from the `init` defaults. Pass real values to `wails3 init` with `-productname`, `-productcompany`, `-productdescription`, `-productcopyright`, `-productcomments`, `-productidentifier` and `-productversion`, or edit `build/config.yml` and run `wails3 task common:update:build-assets`.
- Set the version in `build/config.yml` and change it in the release commit, so that the bundle, the installer and the updater agree. Tag the commit with the same version.
- Give the Go and the frontend the same release by building the frontend in the same job as the binary. The binary embeds `frontend/dist`, so a stale `dist` ships a stale interface.
- Do not commit `bin/` or `frontend/dist`. The generated `.gitignore` already ignores them.

### Targets

- Build each desktop platform on that platform when you can. A native build needs the platform's toolchain and libraries, and the generated Taskfiles use them: the Xcode tools on macOS, a C compiler with `gtk4` and `webkitgtk-6.0` on Linux, and Go alone on Windows.
- Cross-compile with Docker only when a native runner is not available. `wails3 task setup:docker` builds the image once (about 800 MB), and then `wails3 build GOOS=linux` and similar commands use it automatically, as the cross-platform guide describes. Per the guide, Windows builds with plain Go unless the code needs cgo, a macOS target from Linux or Windows needs Docker with the macOS SDK, and a Linux target from another host needs Docker unless a C compiler is present.
- Pass `GOOS` and `ARCH` to the build task and not to `go build` directly: `wails3 build GOOS=windows ARCH=arm64`. The task picks the right platform Taskfile.
- Test each target on that operating system. A build that compiles for Windows still needs to run on Windows.
- The Android and iOS tasks that the template includes are experimental and outside the stable contract. Leave them in the Taskfile, and do not build or ship them.
- A `build:server` task builds the application without a window as an HTTP server (`-tags server,production`), and `build:docker` puts it into a distroless image. Use them for the end-to-end tests ([testing](09-testing-and-quality-gates.md#end-to-end-tests)), and for a hosted version of the same application only when the product needs one.

### Signing

- Sign every release. An unsigned application triggers warnings on macOS and Windows that most users will not click through.
- Run `wails3 setup` once to store the signing identity, the notarisation profile and the certificate settings in `~/.config/wails/defaults.yaml`, and the secrets in the system keychain. The sign tasks read them from there, so no secret enters the repository. The tasks are `darwin:sign`, `darwin:sign:notarize`, `windows:sign`, `windows:sign:installer`, `linux:sign:deb`, `linux:sign:rpm` and `linux:sign:packages`.
- On macOS, sign with a Developer ID Application identity, enable the hardened runtime with entitlements that grant the minimum (network only for most applications), and notarise with `notarytool`. Store the credentials in the keychain once with `wails3 signing` or `notarytool store-credentials`, and verify the result with the commands in the guide.
- On Windows, sign the executable and the installer with an Authenticode certificate from a trusted authority. A self-signed certificate is for testing and internal use only, and it triggers SmartScreen warnings for everyone else. The signing guide describes the supported formats, including MSIX.
- On Linux, sign the `deb` and `rpm` packages with a PGP key.
- Keep certificates, private keys and passwords outside the repository and out of CI logs. Give CI the secret through the CI system's protected variables, and never print it.
- Check a signed build on a machine that has never seen the application. Signing and notarisation failures appear only there.

### Installers and updates

- Package for each platform in its usual form: a signed and notarised `.app` in a `.dmg` on macOS, an NSIS installer (or MSIX) on Windows, and `deb`, `rpm` or AppImage on Linux. The installers guide describes the tasks. Use GoReleaser or the CI system to attach the artifacts to a release when you publish more than one.
- Name artifacts with the product, the version, the operating system and the architecture, and publish a checksum file next to them.
- Add the in-app updater only when the product needs to update itself. It stages the new version in a `wails-update-*` folder beside the installed binary (beside the `.app` on macOS), so that folder must be writable, which excludes a read-only install. It supports providers such as GitHub releases and a manifest endpoint, verifies a signature or a digest, and swaps the binary atomically.
- Use a cryptographic signature for updates, not a digest only, as the [security note](08-security.md#network-and-updates) says. Publish the public key in the binary, and keep the private key outside the repository.
- Use the updater's constants for its events and do not type the event names by hand, as the guide says.
- Keep the data of the application in the user's folders, so that an update or an uninstall does not delete it.

### Continuous integration

- Run these jobs in this order, as the Go notes' pipeline does for a service ([Go automation](../golang-conventions/03-project-setup-and-tooling.md#automation)):
  1. `check`: the project's check task, which formats, vets and tests the Go packages, verifies the bindings and runs the frontend checks ([setup](02-project-setup-and-tooling.md#scripts)).
  2. `e2e`: the Playwright test against the server build ([testing](09-testing-and-quality-gates.md#end-to-end-tests)).
  3. `lint` and `govulncheck`: golangci-lint and the vulnerability scan, as separate jobs with pinned versions.
  4. `build`: one job per target platform, on a runner of that platform, that runs `wails3 build` or `wails3 package` and keeps the artifact.
  5. `release`: on a tag only, sign, notarise and publish the artifacts.
- Install the CLI in CI from the module's `tool` directive (`go install tool`), so that the CLI matches the library, and put `GOBIN` on `PATH`.
- Cache the Go module cache and the npm cache, and use `npm ci` for the frontend.
- Give `wails3 init`'s build assets a stable copy: do not run `wails3 task common:update:build-assets` in CI, because it rewrites the committed files.
- Run the release job only from a protected tag, and give it the signing secrets through protected variables.

## Sources and raw notes

Pages read on 2026-11-18, from the `v3.1.0` documentation source:

- [Build system](https://wails.io/concepts/build-system/) and [build customisation](https://wails.io/guides/build/customization/): the Taskfiles, `build/config.yml`, development mode and its `dev_mode` settings. [Building applications](https://wails.io/guides/build/building/), [cross-platform builds](https://wails.io/guides/build/cross-platform/): the Docker image for cross-compilation, the matrix of hosts and targets, and the auto-detection. [Signing](https://wails.io/guides/build/signing/): the backends, macOS identities, entitlements and notarisation, Windows certificates, Linux package signing, `wails3 setup`. [Installers](https://wails.io/guides/installers/): NSIS, WiX, DMG, DEB, RPM, AppImage and GoReleaser. [Updater](https://wails.io/guides/updater/): providers, the staging folder, verification, artifact formats and events. [CLI](https://wails.io/guides/cli/): the commands and flags.
- `wails3` v3.1.0: `wails3 task --list` printed the tasks `common:build:server`, `common:build:docker`, `common:setup:docker`, `darwin:sign`, `darwin:sign:notarize`, `windows:sign`, `windows:sign:installer`, `linux:sign:deb`, `linux:sign:rpm`, `linux:sign:packages` and the Android and iOS tasks. `wails3 init -help` listed the `-product*` flags and their defaults (`My Company`, `My Product`, `0.1.0`).
- Checked on 2026-11-18 in the sample project on macOS 26.6 with Go 1.26.10: `wails3 build` took about 15 to 30 seconds with a warm cache and wrote `bin/loansapp` (9.2 MB). `wails3 package` took about 94 seconds including the frontend dependencies, wrote `bin/loansapp.app` with `Contents/MacOS`, `Contents/Resources` and `Info.plist`, ad-hoc signed it with `codesign --force --deep --sign -`, and `codesign --verify --deep --strict` passed. `plutil -p` showed `CFBundleIdentifier` `com.example.loansapp`, `CFBundleName` `My Product`, `CFBundleVersion` `0.1.0`, `LSMinimumSystemVersion` `12.0.0` and the placeholder copyright and comment.
- Not run: `wails3 dev` (it opens a window), signing and notarisation (they need an Apple identity), the Windows and Linux builds, Docker cross-compilation (Docker is not installed on the machine), installers, the updater and every CI job. Those rules rest on the documentation pages above and on the Go and infrastructure notes.
