# Kotlin Multiplatform Principles and Sources of Truth

## Summary

These principles apply to every Kotlin Multiplatform (KMP) project. They sit on top of the [Kotlin conventions](../kotlin-conventions/01-principles-and-sources.md): every rule there applies to code in every source set, and this set adds only what multiplatform changes (modules, source sets, targets, platform access, the iOS boundary, testing across targets). The baseline is the official project shape: entry points in their own modules, a shared module, the default hierarchy template and the Android-KMP library plugin. A precedence list settles disagreements between sources, and the last table of this note lists the places where the sources disagree.

## Rules

### Principles

1. **Follow the Kotlin conventions first.** Nothing in this set relaxes them. Naming, null safety, error handling, coroutines and API design are defined in [kotlin-conventions](../kotlin-conventions/01-principles-and-sources.md).
2. **Use the official project shape.** Put each app entry point in its own module, share code through a shared module, use the default hierarchy template, and use the Android-KMP library plugin for the Android target. Replace one of them only with a written reason ("convention over configuration"; [setup](02-project-setup-and-tooling.md), [structure](03-project-structure-and-source-sets.md)).
3. **Put code in `commonMain` unless it needs a platform API.** The compiler rejects a platform API in common code, so a clean `commonMain` is the check that the code is portable ([source sets](03-project-structure-and-source-sets.md#source-sets-and-hierarchy)).
4. **Keep platform access behind interfaces.** Use `expect`/`actual` for small things such as a factory function, and write platform classes as implementations of a common interface ([platform code](04-platform-code.md)).
5. **Give every declared target a CI job.** A target that CI does not compile and test will break unnoticed. Do not declare a target "for later" without that job ([testing and CI](09-testing-and-ci.md#ci)).
6. **Use Stable pieces.** The Kotlin rule "Experimental means toy projects" applies to every KMP component. The table below lists the level of each piece and what this set does with it.
7. **Check that a library supports every target before it enters `commonMain`.** Look it up on klibs.io or in its documentation ([dependencies](05-dependencies-and-libraries.md)).
8. **Test common code on more than the JVM.** Code that passes on the JVM can still fail on Kotlin/Native or Kotlin/JS ([testing](09-testing-and-ci.md)).
9. **Keep the boundary to Swift small and explicit.** Expose a narrow API, mark what Swift may call as failing with `@Throws`, and hide the rest ([iOS interop](08-concurrency-memory-and-ios-interop.md#the-kotlin-to-swift-boundary)).
10. **Move versions together.** Kotlin, the Gradle and Android Gradle plugins, Gradle, Compose Multiplatform and Xcode have a compatibility table. Check it before you change one of them ([setup](02-project-setup-and-tooling.md#versions-and-compatibility)).

### Order of precedence

When two sources disagree, the lower number wins.

1. The Kotlin language specification, the documented behaviour of the standard library, and what the compiler and the Kotlin Multiplatform Gradle plugin accept and warn about.
2. The [Kotlin conventions](../kotlin-conventions/01-principles-and-sources.md#order-of-precedence). A rule there that names a multiplatform situation holds here.
3. The notes in this folder. They record each conflict between the sources ([table below](#where-the-sources-disagree)).
4. The JetBrains documentation for Kotlin Multiplatform and Compose Multiplatform.
5. The Android documentation, for the Android target only: the Android-KMP library plugin, the Android Gradle plugin (AGP) and the AndroidX libraries. It wins over level 4 on anything AGP owns, such as the names of its DSL blocks.
6. Tool defaults.

### Stability of the pieces

Levels come from the [stability table of Kotlin components](https://kotlinlang.org/docs/components-stability.html) and the [stability of supported platforms](https://kotlinlang.org/docs/multiplatform/supported-platforms.html), read on 2026-11-06.

| Piece | Level | What this set does |
| --- | --- | --- |
| Kotlin Multiplatform, the KMP Gradle plugin, the KMP IDE plugin | Stable | Use |
| Android, iOS, desktop (JVM) and server-side (JVM) targets | Stable | Use |
| Kotlin/JS (web) | Stable | Use |
| Kotlin/Wasm (web), Compose Multiplatform for web on Wasm, watchOS, tvOS | Beta | Use only with a written reason |
| Compose Multiplatform on Android, iOS and desktop | Stable | Use |
| `expect`/`actual` classes | Beta | Avoid; use an interface ([platform code](04-platform-code.md#expect-and-actual)) |
| Import of C and Objective-C libraries (cinterop) | Beta | Wrap behind an interface in `iosMain` |
| Swift export | Alpha | Do not use in production |
| SwiftPM import | Alpha (Experimental in the Kotlin 2.4 release notes) | Do not use in production |
| Kotlin Toolchain (JetBrains build tool) | Alpha | Do not use; Gradle stays the build tool |
| Top-level `dependencies {}` in `kotlin {}` | Experimental | Do not use; declare per source set |
| `@HiddenFromObjC`, `@ObjCName`, `@ShouldRefineInSwift` | Experimental opt-in | Prefer `internal`; see [the Swift boundary](08-concurrency-memory-and-ios-interop.md#the-kotlin-to-swift-boundary) |
| Compose Multiplatform UI test API | Experimental | Use only with a written reason |
| kotlinx.coroutines, kotlinx.serialization | Stable | Use |
| kotlinx-datetime, kotlinx-io | Alpha | Prefer `kotlin.time` and `kotlin.uuid`; an Alpha dependency needs a written reason |

### Applying the notes

- **New code** follows every note in this set and in the Kotlin set. Start a new project from the Kotlin Multiplatform wizard (IDE plugin or kmp.jetbrains.com) and delete what you do not need; JetBrains says the wizard's output shows how projects are organised by default.
- **Existing code:** apply the notes to the lines you write or change, as in the [Kotlin set](../kotlin-conventions/01-principles-and-sources.md#applying-the-notes). Move an old single-module layout or the legacy Android target to the new shape in its own change, and only when you upgrade to AGP 9 or when someone asks.
- **Mechanical changes** (version upgrades, dependency bumps, module moves) go in their own commits.
- **Generated code** is exempt: the Compose Multiplatform `Res` accessors, serialisers and framework headers.
- **Repositories owned by others:** follow the conventions that repository documents first.
- **Version baseline:** Kotlin 2.4.21 (released 2026-10-08), as in the Kotlin set, and Compose Multiplatform 1.12.2 (released 2026-10-15). Compose Multiplatform 1.13.0 is in beta on 2026-11-06; do not use it. Kotlin 2.5.0 is planned for December 2026. Version numbers are a snapshot, so check the release pages before you start.
- **Examples:** the code blocks in this set are fragments (they start with `// fragment` or are configuration files). They were written from the documentation and were not compiled, because no Kotlin 2.4.21 toolchain with the Kotlin/Native and Android parts was set up when the set was written. Check an example against the versions of the project before you copy it.
- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/kmp.md](../agent-rules/rules/kmp.md). Install it as the [agent-rules README](../agent-rules/README.md) describes. It adds to `kotlin.md` and does not replace it. The digest is a manual copy, so update it in the same change whenever a note here changes.

### Where the sources disagree

| Topic | One source says | Another says | Rule here |
| --- | --- | --- | --- |
| Android target block in the shared module | JetBrains pages show `androidLibrary {}` | The Android documentation says `android {}` replaced it in AGP 8.12 and `androidLibrary {}` is deprecated since AGP 9.1.0-alpha09 | `android {}`; AGP owns the DSL ([setup](02-project-setup-and-tooling.md#android-target)) |
| Compose dependency aliases (`compose.ui`, `compose.foundation`) | JetBrains structure pages still use them | Compose Multiplatform 1.10 deprecated them | Direct library references in the version catalog ([Compose](07-compose-multiplatform.md#dependencies-and-compiler-plugin)) |
| Gradle flags in CI | The JetBrains CI sample sets `GRADLE_OPTS` | [Kotlin note 02](../kotlin-conventions/02-project-setup-and-tooling.md#gradle-build): flags live in `gradle.properties` | `gradle.properties`; CI runs plain commands |
| Apple simulator targets | Kotlin still lists `iosX64` as supported | Compose Multiplatform 1.11 removed `iosX64` and `macosX64` | Declare `iosArm64` and `iosSimulatorArm64` only |
| Android test source sets | The JetBrains layout page names `androidUnitTest` and `androidInstrumentedTest` (legacy plugin) | The Android-KMP plugin names `androidHostTest` and `androidDeviceTest` | The plugin's names |
| `@Preview` in common code | Before Compose Multiplatform 1.10 it was a library-specific annotation | From 1.10 the AndroidX annotation is multiplatform and the old one is deprecated | The AndroidX annotation |

### Decisions to review

These choices go beyond the sources, or the sources leave them open. Change one by editing the note it points to and the digest.

1. **Gradle stays the build tool.** Kotlin Toolchain is Alpha, so it is not adopted ([setup](02-project-setup-and-tooling.md#tools-not-used)).
2. **`kotlin { android {} }` is the Android target block**, which needs AGP 8.12 or newer ([setup](02-project-setup-and-tooling.md#android-target)).
3. **One `shared` module by default.** Split `sharedLogic` and `sharedUI` only when an app uses native UI ([structure](03-project-structure-and-source-sets.md#modules)).
4. **iOS uses direct integration of an Objective-C framework.** Swift export and SwiftPM import are Alpha, so they are not used; CocoaPods is used only for Pod dependencies ([iOS integration](08-concurrency-memory-and-ios-interop.md#ios-integration)).
5. **Web: Kotlin/JS is allowed, Kotlin/Wasm needs a written reason** because it is Beta ([setup](02-project-setup-and-tooling.md#targets)).
6. **Test names in `commonTest` are camelCase, without backticks.** The Kotlin digest allows backticked names only in JVM tests, and `commonTest` also runs on other runtimes ([testing](09-testing-and-ci.md#common-tests)).
7. **`collectAsStateWithLifecycle()` is used in common Compose code.** `lifecycle-runtime-compose` declares it in its `commonMain` ([state in the UI](06-architecture-state-and-navigation.md#state-in-the-ui)). The Kotlin set called it Android-only until 2026-11-06, when Kotlin note 11 and `kotlin.md` were corrected.
8. **No `Dispatchers.IO` default value in common code that has a web target.** `Dispatchers.IO` is not declared for JS and Wasm, so the dispatcher comes from the platform or the DI framework ([concurrency](08-concurrency-memory-and-ios-interop.md#dispatchers)).
9. **Constructor injection by default; Koin when a DI framework is needed.** The JetBrains documentation shows Koin and Metro, and the Printer App plan uses Koin ([platform code](04-platform-code.md#interfaces-and-injection)).
10. **Navigation 3 for new Compose Multiplatform apps** (Compose Multiplatform 1.10 and newer). Existing apps on Navigation Compose stay on it until a larger change ([architecture](06-architecture-state-and-navigation.md#navigation)).
11. **Reference stack.** Ktor, kotlinx.serialization, SQLDelight or Room, DataStore and Koin are the default choices when a project has no stack yet. They come from the JetBrains examples and the Printer App plan, not from a rule of the platform ([dependencies](05-dependencies-and-libraries.md#reference-stack)).

### Notes in this folder

| Note | Content |
| --- | --- |
| [02 Project setup and tooling](02-project-setup-and-tooling.md) | Versions, plugins, the Android-KMP library plugin, targets, properties, Xcode, tools not used |
| [03 Project structure and source sets](03-project-structure-and-source-sets.md) | Modules, the hierarchy template, directories, packages, file names, keeping `commonMain` portable |
| [04 Platform code](04-platform-code.md) | `expect`/`actual`, interfaces, dependency injection, Android-only APIs |
| [05 Dependencies and libraries](05-dependencies-and-libraries.md) | Choosing and declaring libraries, the reference stack, libraries you publish |
| [06 Architecture, state and navigation](06-architecture-state-and-navigation.md) | Layers, the multiplatform ViewModel, UI state, Navigation 3, DI |
| [07 Compose Multiplatform](07-compose-multiplatform.md) | Sharing UI, plugins, resources, previews, entry points, platform behaviour |
| [08 Concurrency, memory and iOS interop](08-concurrency-memory-and-ios-interop.md) | Dispatchers, Kotlin/Native memory, iOS integration, the Swift boundary, other targets |
| [09 Testing and CI](09-testing-and-ci.md) | `commonTest`, platform tests, coroutines, Compose UI tests, CI jobs |
| [10 Modern KMP by release](10-modern-kmp-by-release.md) | What changed from Kotlin 2.0 to 2.4, upgrade checklist |

## Sources and raw notes

Pages read on 2026-11-06. The text of the JetBrains pages was read from their Markdown sources on the `master` branch of [kotlin-multiplatform-dev-docs](https://github.com/JetBrains/kotlin-multiplatform-dev-docs) and [kotlin-web-site](https://github.com/JetBrains/kotlin-web-site), which can run ahead of the published pages. Where a page depended on an early-access version, the note says so. The Android pages were read as published.

- Kotlin Multiplatform: [Recommended project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-project-recommended-structure.html), [Updating projects with Android apps to use AGP 9](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html), [The basics of project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-discover-project.html), [Source set hierarchy](https://kotlinlang.org/docs/multiplatform/multiplatform-hierarchy.html), [Expected and actual declarations](https://kotlinlang.org/docs/multiplatform/multiplatform-expect-actual.html), [Use platform-specific APIs](https://kotlinlang.org/docs/multiplatform/multiplatform-connect-to-apis.html), [Adding dependencies](https://kotlinlang.org/docs/multiplatform/multiplatform-add-dependencies.html), [Stability of supported platforms](https://kotlinlang.org/docs/multiplatform/supported-platforms.html), [Kotlin Toolchain](https://kotlinlang.org/docs/multiplatform/kotlin-toolchain.html).
- Compose Multiplatform: [Compatibility and versions](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html), what's new in 1.10, 1.11 and 1.12.
- Kotlin: [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html), [What's new in Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html), [release process](https://kotlinlang.org/docs/releases.html).
- Android: [Android-KMP library plugin](https://developer.android.com/kotlin/multiplatform/plugin), [Android Gradle plugin release notes](https://developer.android.com/build/releases/gradle-plugin).
- Library source: [`FlowExt.kt` in androidx lifecycle-runtime-compose](https://github.com/androidx/androidx/blob/androidx-main/lifecycle/lifecycle-runtime-compose/src/commonMain/kotlin/androidx/lifecycle/compose/FlowExt.kt) (`collectAsStateWithLifecycle` in `commonMain`).
- The other notes list the pages they were written from.
- The Kotlin equivalent of this set is in [kotlin-conventions](../kotlin-conventions/01-principles-and-sources.md).
