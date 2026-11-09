# Kotlin Multiplatform Project Structure and Source Sets

## Summary

Give each app entry point its own module, put shared code in a `shared` module, and split it into `sharedLogic` and `sharedUI` only when an app uses native UI. Build the source set tree from the default hierarchy template, and put each piece of code in the most common source set that compiles. Directories, packages and file names follow the [Kotlin set](../kotlin-conventions/03-project-layout-and-packages.md), with a platform suffix for files in platform source sets.

## Rules

### Modules

- Put each app entry point in its own module that depends on the shared modules: `androidApp`, `desktopApp`, `webApp`. The iOS app is an Xcode project (`iosApp/`) and not a Gradle module. With AGP 9 the Android entry point must be separate from the shared code ([setup](02-project-setup-and-tooling.md#android-target)).
- If every app shares both UI and logic, one `shared` module is enough. If any app has a native UI (for example a SwiftUI app), split the shared code into `sharedLogic` and `sharedUI`, so that apps with native UI do not depend on Compose Multiplatform. A project that already has a `shared` module for logic can keep that name.
- With server code that shares logic with clients, JetBrains recommends an `app` folder with the entry-point modules and the client shared modules, a `server` module, and a `core` module for what both sides share, such as models and validation.
- Keep the dependency direction one way: app modules depend on `sharedUI`, `sharedUI` depends on `sharedLogic`, and `sharedLogic` depends on `core`. A shared module never depends on an app module.
- Keep every `expect` and `actual` declaration in the source sets of the shared module, and never in an app module. Then every platform sees them. Entry-point code stays in the app module: the Android activity and manifest, the desktop `main()`, the web `main()` and the Swift `@main` ([platform code](04-platform-code.md)).
- Split by feature and responsibility as in the [Kotlin set](../kotlin-conventions/03-project-layout-and-packages.md#packages-and-modules). A feature module that is multiplatform uses the same plugins and the same targets as the other shared modules, through one convention plugin.
- Only the module that Xcode consumes declares an iOS framework. When the UI module is that module, `sharedLogic` needs no framework configuration.

```text
project/
├── build-logic/                  convention plugins (included build)
├── gradle/libs.versions.toml
├── androidApp/                   com.android.application, entry point only
├── desktopApp/                   JVM entry point, packaging
├── webApp/                       web entry point
├── iosApp/                       Xcode project
├── sharedUI/                     Compose Multiplatform UI (optional)
│   └── src/{commonMain,commonTest,androidMain,iosMain,jvmMain,webMain}/kotlin/…
└── sharedLogic/                  business logic, data layer
    └── src/{commonMain,commonTest,androidMain,iosMain,jvmMain}/kotlin/…
```

### Source sets and hierarchy

- Use the **default hierarchy template**. Declare the targets, and the Kotlin Gradle plugin creates the intermediate source sets (`appleMain`, `iosMain`, `nativeMain`, `webMain` and the `*Test` twins) for exactly those targets. Reference them by name (`iosMain.dependencies { }`) and do not create them with `by creating`.
- The compiler gives each source set the APIs that exist on all of its targets. A source set named `nativeMain` or `appleMain` compiles only to the native or Apple targets you declared, so it can see the whole iOS API while iOS is your only Apple target. Do not assume that its code also compiles for a target you add later.
- Put code in the most common source set that compiles: `commonMain` first, then `iosMain` for iOS-only code, and a target-specific set such as `iosArm64Main` almost never.
- Put an `actual` declaration in the intermediate source set (`iosMain`) and not in each target set (`iosArm64Main` and `iosSimulatorArm64Main`).
- Do not call `dependsOn()` on source sets that the template covers: it switches the template off for the project and produces a warning. If you need an extra intermediate source set, such as one between a JVM and a macOS target, call `applyDefaultHierarchyTemplate()` explicitly, add the set by hand, and write down why. The relations of the template's own source sets cannot be changed.
- Test source sets mirror the main ones: `commonTest`, `iosTest`, `jvmTest`. The Android-KMP plugin names its sets `androidMain`, `androidHostTest` and `androidDeviceTest` ([testing](09-testing-and-ci.md#platform-tests)).
- A source set cannot be shared between several JVM targets, between a JVM and an Android target, or between several JS targets.

### Directories, packages and file names

- Keep Kotlin sources in `src/<source set>/kotlin`, as in the [Kotlin set](../kotlin-conventions/03-project-layout-and-packages.md#source-roots-and-directories). Use one package layout per module (with or without the common root package in the directory path) and the same layout in every source set of the module, so that an `expect` declaration and its `actual` declarations are easy to find side by side.
- Put the `expect` declaration and every `actual` declaration in the **same package**. The compiler requires it.
- Give a file with top-level declarations in a platform source set the source set name, without `Main`, as a suffix: `Platform.kt` in `commonMain`, `Platform.android.kt` in `androidMain`, `Platform.ios.kt` in `iosMain`, `Platform.jvm.kt` in `jvmMain`, `Platform.web.kt` in `webMain`. Without the suffix, two `Platform.kt` files in one package produce the same JVM file facade and fail with "Duplicate JVM classes" ([Kotlin set](../kotlin-conventions/03-project-layout-and-packages.md#file-names-and-contents)).
- A file with one class is named after the class, with no suffix. Name a platform implementation of a common interface by what it uses, for example `KeychainSecureStorage` and `AndroidKeystoreSecureStorage`. The platform name as a prefix (`AndroidPlatform`) is fine when the platform is the only difference.
- Compose Multiplatform resources go in `src/commonMain/composeResources` of the module that owns them ([Compose](07-compose-multiplatform.md#resources)).

### Keeping common code common

- `commonMain` does not import `android.*`, `java.*`, `javax.*`, `platform.*` (Apple) or `kotlinx.cinterop`. The compiler rejects those imports once the module has a second target, because common code must compile for every target.
- Declare the iOS targets from the first day and compile them in CI, even when only Android ships. The compiler is then the guard, and it is stronger than a text search for `import android.` in `commonMain`. A text or Konsist rule is the fallback for a module that cannot declare a second target yet.
- Use `kotlin.time` and `kotlin.uuid` and not `java.time` and `java.util.UUID` ([Kotlin set](../kotlin-conventions/11-platform-practices.md#kotlin-multiplatform)). Use a multiplatform library for files, sockets and databases ([dependencies](05-dependencies-and-libraries.md)).
- When a type from a platform API is needed in common code, hide it behind a common interface and keep the platform type inside the platform source set ([platform code](04-platform-code.md)).

## Sources and raw notes

Pages read on 2026-11-06:

- [Recommended project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-project-recommended-structure.html): separate entry-point modules, `shared` versus `sharedLogic` and `sharedUI`, the server layout, where the iOS framework is configured.
- [Updating projects with Android apps to use AGP 9](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html): what moves into `androidApp` and what stays in the shared module (`expect` and `actual` declarations).
- [Source set hierarchy](https://kotlinlang.org/docs/multiplatform/multiplatform-hierarchy.html): the default hierarchy template, the `dependsOn()` warning, additional source sets, unsupported combinations.
- [The basics of project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-discover-project.html): common code, targets, source sets, the compiler check on platform APIs. [Expected and actual declarations](https://kotlinlang.org/docs/multiplatform/multiplatform-expect-actual.html): the same-package rule and actuals in intermediate source sets.
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html) through the [Kotlin set](../kotlin-conventions/03-project-layout-and-packages.md): directories, packages, platform file suffixes.
- The platform implementation names are this set's choice; the JetBrains examples use `AndroidPlatform` and `IOSPlatform`.
