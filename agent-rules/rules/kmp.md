---
paths:
  - "**/src/*Main/**/*.kt"
  - "src/*Main/**/*.kt"
  - "**/src/*Test/**/*.kt"
  - "src/*Test/**/*.kt"
  - "**/shared*/build.gradle.kts"
  - "**/composeApp/build.gradle.kts"
  - "**/androidApp/build.gradle.kts"
  - "**/desktopApp/build.gradle.kts"
  - "**/webApp/build.gradle.kts"
---
# Kotlin Multiplatform conventions (every KMP project)

Write idiomatic Kotlin Multiplatform. Follow the official project shape and the defaults of the Kotlin Gradle plugin instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `kmp-convention` folder of the programming-conventions repository, which hold the reasons, sources and decisions. It adds to `kotlin.md` and does not replace it: every Kotlin rule still applies in every source set. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-11-06; update it by hand whenever a note changes.

## How to apply

- This file applies to a module that applies `org.jetbrains.kotlin.multiplatform` or `com.android.kotlin.multiplatform.library`, or that has a `commonMain` source set. Ignore it in a plain Android, JVM or Spring module.
- New and edited code follows this file. Leave untouched code alone unless asked, and keep diffs small. Put mechanical changes (version upgrades, module moves, the move off `androidTarget`) in separate commits. If the repository documents its own conventions, follow them first. Generated code (the Compose `Res` accessors, serialisers, framework headers) is exempt.
- When sources disagree, the order is: language specification and compiler, `kotlin.md` and the Kotlin notes, this file and its notes, the JetBrains documentation for Kotlin Multiplatform and Compose Multiplatform, the Android documentation for the Android target (it wins on the AGP DSL), tool defaults.- Do not raise Kotlin, Gradle, AGP, Compose Multiplatform or Xcode unasked. Check the compatibility table first. Baseline: Kotlin 2.4.21 and Compose Multiplatform 1.12.2. Do not use Compose Multiplatform 1.13 (beta) or Kotlin 2.5 (planned for December 2026).
- Use Stable pieces. Beta: Kotlin/Wasm and Compose for web on Wasm, watchOS, tvOS, `expect`/`actual` classes, cinterop; they need a written reason. Alpha or Experimental, do not use: Swift export, SwiftPM import, Kotlin Toolchain, the top-level `kotlin { dependencies {} }`, `@HiddenFromObjC`, `@ObjCName`, `@OptionalExpectation`, the Compose UI test API; kotlinx-datetime and kotlinx-io are Alpha and need a written reason.
- Before you report multiplatform changes as done, run `ktlint`, `./gradlew check` and the tests of every target you can run, and say which targets you could not build (Apple targets need a Mac).

## Project shape

- Each app entry point is its own module: `androidApp`, `desktopApp`, `webApp`; `iosApp` is an Xcode project. This is mandatory for Android with AGP 9. Shared code goes in `shared`; split it into `sharedLogic` and `sharedUI` only when an app uses native UI. With a server add `server` and `core`. Dependencies run app, `sharedUI`, `sharedLogic`, `core`; never back. All `expect` and `actual` declarations stay in the shared modules.
- Use the default hierarchy template: declare targets and use `commonMain`, `iosMain`, `appleMain`, `webMain` by name. No `dependsOn()` for sets the template covers (it switches the template off); an extra set needs an explicit `applyDefaultHierarchyTemplate()` and a written reason. Put code in the most common source set that compiles, and `actual` declarations in `iosMain`, not in each target set. `expect` and `actual` share one package.
- File with top-level declarations in a platform source set: the set name as suffix (`Platform.ios.kt`, `Platform.android.kt`). Name a platform implementation by what it uses (`KeychainSecureStorage`); a platform prefix is fine when that is the only difference.
- Every declared target has a CI job. Declare the Android target, `iosArm64()` and `iosSimulatorArm64()`, `jvm()`, `js { browser() }` as needed. No `iosX64()` or `macosX64()`. `wasmJs` only with a reason. `commonMain` never imports `android.*`, `java.*`, `javax.*`, `platform.*` or `kotlinx.cinterop`; declare the iOS targets from the first day so that the compiler enforces it.
- Compose resources live in `src/commonMain/composeResources` of the module that owns them.

## Build and tooling

- Gradle Kotlin DSL and a version catalog, as in `kotlin.md`. Apply plugins by alias, and list each one in the root `build.gradle.kts` with `apply false`. Shared module: `org.jetbrains.kotlin.multiplatform` and `com.android.kotlin.multiplatform.library`. App module: `com.android.application`, and no `org.jetbrains.kotlin.android` on AGP 9. Compose: `org.jetbrains.compose` and `org.jetbrains.kotlin.plugin.compose` (same version as Kotlin). Put the target list, compiler options and `android {}` block shared by several modules in a convention plugin of `build-logic`.
- Android target: `kotlin { android { namespace = ...; compileSdk = ...; minSdk = ... } }` (AGP 8.12 or newer; `androidLibrary {}` before that, deprecated since AGP 9.1.0-alpha09). `androidTarget()` with `com.android.library` is the legacy shape: migrate it; `android.enableLegacyVariantApi=true` is a dated bridge until AGP 10. The namespace differs from the app's. Opt in to `androidResources { enable = true }`, `withJava()` (only with Java sources), `withHostTest {}` and `withDeviceTest {}`. Sources are `src/androidMain`, `src/androidHostTest` and `src/androidDeviceTest`. No build types, flavors or `BuildConfig`: use a separate `com.android.library` module. Compose tooling goes in `"androidRuntimeClasspath"(...)`, not `debugImplementation`.
- AGP 9 needs Gradle 9.1.0 or newer; AGP 9.5.0 is above the AGP range of Kotlin 2.4.21, so stay in the compatibility table. `kotlin { jvmToolchain(<LTS>) }` also sets the Android JVM target. Compiler options go in the top-level `kotlin { compilerOptions {} }`. Add `-Xexpect-actual-classes` only if you use `expect` classes. No `withJava()` on `jvm()`.
- iOS: a static framework in the module that Xcode consumes (`binaries.framework { baseName = "Shared"; isStatic = true }`), deployment target at least iOS 15.0 (the Kotlin 2.4 default), direct integration (`embedAndSignAppleFrameworkForXcode`). CocoaPods only for Pod dependencies, and it cannot be combined with direct integration. An XCFramework in a Swift package is for an iOS app in another repository. Export a dependency to Swift with `api` and `export(...)`, and as little as possible.
- Gradle flags live in `gradle.properties`. `kotlin.native.binary.gc=pmcs` only as a workaround for a named problem. Build and run Apple targets on a Mac.

## Platform code

- Look for a multiplatform library first (klibs.io). Otherwise put an `interface` in `commonMain`, implement it in the platform source sets, and pass it in through a constructor. `expect fun` and `expect val` only for small things: a factory, a value, the module of the DI framework. A property only if it cannot throw, is cheap and is stable.
- Avoid `expect class` (Beta). If you must inherit from a platform class, add `-Xexpect-actual-classes` once in the module. Add no entries to an `actual enum`. `actual typealias` reuses an exact platform type.
- Provide implementations through the DI framework the project already uses, else constructor injection from the entry point, else an `expect fun` factory. One mechanism per module. When a framework is needed: Koin by default, Metro for compile-time injection. Hilt is Android-only.
- Android-only APIs (`Context`, `Activity`, `LocalContext`, `LocalConfiguration`, `ComposeView`, Hilt) stay in `androidMain` or `androidApp`. Never pass a `Context` through common code. Apple APIs (`platform.*`) only inside `iosMain` implementations. Wrap cinterop (Beta) behind an interface.

## Dependencies

- Check that a library supports every declared target before it enters `commonMain`. Declare it per source set (`commonMain.dependencies {}`) by its common name, with no target suffix. Platform libraries (database driver, HTTP engine) go in the platform source set. `implementation` by default; `api` only for public API and for what the iOS framework exports. No `kotlin-stdlib`; `kotlin("test")` once in `commonTest`. Versions only in the catalog, modules through `projects.sharedLogic`.
- `kotlin.time` and `kotlin.uuid` before kotlinx-datetime or kotlinx-io. AndroidX libraries that are multiplatform: annotation, collection, compose, datastore, lifecycle, viewmodel, navigation, navigation3, navigationevent, paging, room, savedstate, sqlite; fully supported on Android, JVM and iOS, tier 3 (untested) on JS and Wasm.
- Reference stack for a project without one: kotlinx.coroutines, kotlinx.serialization, Ktor client with one engine per platform, SQLDelight (or Room without a web target), DataStore, Koin, Coil. A project with a stack keeps it.
- A published library follows the Kotlin library rules and publishes all publications from one host (a Mac with cinterop, CocoaPods or final Apple binaries), with `publishAllPublicationsTo<Repository>`. The Android publication is configured in the `android {}` block.

## Architecture and state

- Layers and unidirectional data flow as in `kotlin.md`. Share the data layer first, then the ViewModel, then the UI, to the deepest level every app accepts. Keep UI types (`DrawableResource`, `Color`, `ImageVector`) out of logic modules.
- Use the AndroidX `ViewModel` in common code (`org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose`; `androidx.lifecycle:lifecycle-viewmodel` as `api` with a native UI). Non-JVM targets have no reflection: `viewModel { OrderViewModel(repository) }`, `koinViewModel()` or `metroViewModel()`. Desktop adds `kotlinx-coroutines-swing`. With Navigation 3 pass `rememberSaveableStateHolderNavEntryDecorator()` and `rememberViewModelStoreNavEntryDecorator()` to `NavDisplay`. A SwiftUI app wraps the ViewModel in the app module (KMP-ObservableViewModel is the documented option).
- `collectAsStateWithLifecycle()` works in common Compose code (`lifecycle-runtime-compose` declares it in `commonMain`); use it. `collectAsState()` only in a module without the lifecycle library. Keep the `MutableStateFlow` private (explicit backing field on 2.4) and expose one `uiState`. No platform types in UI state.
- Navigation 3 (`org.jetbrains.androidx.navigation3:navigation3-ui`, Compose Multiplatform 1.10 and newer) for new apps; an app on Navigation Compose stays until a change of its own. `NavigationBackHandler()` replaces `PredictiveBackHandler()`. No browser-history API (Experimental).

## Compose Multiplatform

- Share UI only when every app needs the same screens; otherwise share the ViewModel. Stable on Android, iOS and desktop; Beta on web (Wasm). The Compose rules of `kotlin.md` apply to common code. No Android-only Compose APIs in common code.
- Reference libraries directly in the catalog (`org.jetbrains.compose.ui`, `.foundation`, `.material3`), not through the `compose.*` aliases, which are deprecated since 1.10. The Compose compiler plugin has the version of Kotlin. Use a release, not an alpha, beta or EAP. Compose runs on Android 5.0 (API 21) and newer, on 64-bit only; desktop needs JDK 11 to run and JDK 17 to package.
- Resources: `drawable`, `font`, `values`, `files` under `composeResources`, read through the generated `Res` (`painterResource(Res.drawable.logo)`). In an Android-KMP library module set `androidResources { enable = true }` (Experimental support). Keep resources in the module with the UI, because the `Res` package follows the module name.
- `@Preview` is the AndroidX annotation (1.10 and newer; `org.jetbrains.compose.ui:ui-tooling-preview`), and previews in common code need an Android target. Compose Hot Reload is a desktop development tool only.
- Entry points live in the app modules and call one common `App()` that takes no platform types: Android `setContent { App() }`, iOS `ComposeUIViewController { App() }`, desktop `application { Window(...) { App() } }`, web `ComposeViewport { App() }`. Test the UI on every target: keyboard and insets, back, fonts and pointer input differ.

## Concurrency, memory and the iOS boundary

- Inject dispatchers. `Dispatchers.IO` is not declared for JS and Wasm, so a module with a web target has no `Dispatchers.IO` in `commonMain` and no default value of it; the DI module of each platform supplies `IO` (Android, iOS, desktop) or `Default` (web). `Dispatchers.Main` needs `kotlinx-coroutines-android` or `-swing` on the JVM and does not exist on non-Apple native targets.
- Kotlin/Native has a shared heap and the CMS collector (default since 2.4). No `freeze()` and no `@SharedImmutable`. Guard shared state with a `Mutex` or confine it; the common atomics (`kotlin.concurrent.atomics`) were Experimental when introduced, so check their level first.
- Keep the Swift-facing API small: a facade per feature, everything else `internal`. No top-level functions for Swift (they land in `<File>Kt` classes). Every function Swift calls that can throw has `@Throws` with the narrowest types, and a `suspend` function with `@Throws` lists `CancellationException` too; an exception that reaches Swift without it ends the app. Prefer a `sealed` result for expected failures.
- Objective-C export shows `suspend` functions with completion handlers and does not export `Flow`; observe state through the ViewModel library or callbacks in the facade. Avoid nullable primitives (boxed as `KotlinInt`) and complex generics in Swift-facing API. Write KDoc for it; it becomes header comments.

## Testing and CI

- Tests of common code go in `commonTest` with `kotlin.test`, multiplatform libraries only, no direct `Asserter`. Names are camelCase without backticks (backticks only in `jvmTest` and `androidHostTest`). Fakes in `commonTest`, not mocks; a JVM-only mock library belongs in `jvmTest` or `androidHostTest`.
- Platform code is tested in `iosTest`, `jvmTest`, `androidHostTest` and `androidDeviceTest`. `./gradlew allTests` runs every target. `runTest` returned from the test function, `StandardTestDispatcher(testScheduler)`, and `Dispatchers.setMain` on Kotlin/Native. The Compose UI test API is Experimental; test state in the ViewModel instead.
- CI: a Linux job (`ktlint`, `./gradlew check`, `jvmTest`, the Android host tests, `:androidApp:assembleDebug`) and a macOS job (framework link, `./gradlew iosSimulatorArm64Test`, `xcodebuild` for the simulator without signing). Run `commonTest` on at least one non-JVM target. Plain `./gradlew` commands, flags in `gradle.properties`.

## Modern Kotlin Multiplatform

- Kotlin 2.4: Swift export is Alpha, CMS collector by default, Apple minimum iOS 15.0. Kotlin 2.3: the `android` block of the Android-KMP plugin replaces `androidTarget`; `macosX64` is deprecated. AGP 9: the Android app is a separate module and the legacy variant APIs go in AGP 10. Compose Multiplatform 1.10: aliases deprecated, unified `@Preview`, Navigation 3. 1.11: `iosX64` and `macosX64` removed, Kotlin 2.3.10 for the latest features.
- Upgrade by the checklist in note 10: What's new pages, the compatibility table, tools that embed the compiler first, warnings in their own commit, tests on every runner, then update the digest.

## Notes index

Each file is in the `kmp-convention` folder of the programming-conventions repository.

- `01-principles-and-sources.md`: principles, precedence, stability table, where sources disagree, decisions to review
- `02-project-setup-and-tooling.md`: versions, plugins, the Android-KMP plugin, targets, properties, tools not used
- `03-project-structure-and-source-sets.md`: modules, hierarchy template, directories, file names, portable `commonMain`
- `04-platform-code.md`: `expect`/`actual`, interfaces, injection, Android-only APIs
- `05-dependencies-and-libraries.md`: choosing and declaring libraries, reference stack, publishing
- `06-architecture-state-and-navigation.md`: layers, ViewModel, UI state, Navigation 3
- `07-compose-multiplatform.md`: sharing UI, artifacts, resources, previews, entry points, platform behaviour
- `08-concurrency-memory-and-ios-interop.md`: dispatchers, Kotlin/Native memory, iOS integration, the Swift boundary
- `09-testing-and-ci.md`: `commonTest`, platform tests, Compose UI tests, CI
- `10-modern-kmp-by-release.md`: what changed from Kotlin 2.0 to 2.4, upgrade checklist
