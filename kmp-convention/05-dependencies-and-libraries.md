# Kotlin Multiplatform Dependencies and Libraries

## Summary

Check that a library supports every declared target before it enters `commonMain`. Declare it once in the source set that needs it, by its common name, and let the Kotlin Gradle plugin pick the artifact for each target. Platform libraries go only in the platform source sets. The Kotlin set's rules on the standard library, Stable dependencies and the version catalog hold here. A reference stack names the defaults for a project that has no stack yet, and libraries you publish add rules for targets and hosts.

## Rules

### Choosing a library

- Search for a multiplatform library before you use a platform API. klibs.io indexes the libraries on GitHub and Maven Central and tags them by supported platform.
- Before you add a library to `commonMain`, check that it publishes for every target of the module (Android, `iosArm64`, `iosSimulatorArm64`, `jvm`, and `js` or `wasmJs` if declared). A library that misses one target breaks the build of that target.
- Apply the [Kotlin rules](../kotlin-conventions/01-principles-and-sources.md#principles): the standard library and the official kotlinx libraries first, a new dependency only when it removes real complexity, and no Alpha library in production code without a written reason. In the stability table kotlinx-datetime and kotlinx-io are Alpha, so use `kotlin.time` (`Clock`, `Instant`, `Duration`) and `kotlin.uuid` first. For time zones, calendar arithmetic or I/O that the standard library does not cover, name the dependency and its version in the pull request and say why.
- The AndroidX libraries that support Kotlin Multiplatform, on 2026-11-04: annotation, collection, compose, datastore, lifecycle, viewmodel, viewmodel-compose, navigation, navigation3, navigationevent, paging, room, savedstate and sqlite. Android tests them fully on Android, the JVM and iOS (tier 1). macOS and Linux are tier 2, and JavaScript, Wasm, Windows, watchOS and tvOS are tier 3 (untested in CI). A project with a web target should not assume that these libraries work there.
- Libraries that exist only for Android (the `android.*` and `androidx.*` libraries that are not multiplatform, and Hilt) go in `androidMain` or the app module ([platform code](04-platform-code.md#android-only-and-platform-apis)).

### Declaring dependencies

- Declare each dependency in the source set that needs it, inside `kotlin { sourceSets { } }`: `commonMain.dependencies { }`, `commonTest.dependencies { }`, `iosMain.dependencies { }`. The top-level `dependencies {}` block of `kotlin {}` is Experimental, so do not use it.
- Add a library to `commonMain` by its common name (`ktor-client-core`, `sqldelight-runtime`). The plugin resolves the artifact of each target. Never write a target suffix such as `-iosarm64` by hand.
- `commonMain` cannot depend on a platform artifact, because common code must compile for every target. Put such a library in the platform source set (`androidMain`, `iosMain`).
- Use `implementation` by default. Use `api` only for a type that appears in the public API of the module, and for a dependency that the module exports in an iOS framework (for example the ViewModel library when the UI is native, [iOS](08-concurrency-memory-and-ios-interop.md#ios-integration)).
- Do not add `kotlin-stdlib`. Each source set depends on the matching standard library automatically. Add `kotlin("test")` to `commonTest` once, and it gives every test source set the right variant.
- Keep all versions in `gradle/libs.versions.toml`, and reference other modules with type-safe project accessors such as `projects.sharedLogic` ([Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#gradle-build)). Reference Compose Multiplatform libraries directly and not through the deprecated `compose.*` aliases ([Compose](07-compose-multiplatform.md#dependencies-and-compiler-plugin)).
- A library that needs more set-up on a target (the `kotlinx` libraries on the web, npm packages for JS) documents that set-up itself. Follow its page and put the extra dependency in `webMain`.
- Wire a platform-specific part of a library, such as the database driver or the HTTP engine, in the platform source set, and give it to common code through an interface or the DI framework ([platform code](04-platform-code.md#interfaces-and-injection)).

```kotlin
// fragment
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.ktor.client.core)
            implementation(libs.sqldelight.runtime)
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.android)
            implementation(libs.sqldelight.android.driver)
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
            implementation(libs.sqldelight.native.driver)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
    }
}
```

### Reference stack

When a project has no stack yet, start from these defaults ([decision 11](01-principles-and-sources.md#decisions-to-review)). They come from the JetBrains examples and the Android list of multiplatform libraries, and they are choices of this set and not rules of the platform. A project that already has a stack keeps it.

| Concern | Default | Notes |
| --- | --- | --- |
| Async and streams | kotlinx.coroutines | Stable |
| Serialisation | kotlinx.serialization | Stable; mark classes `@Serializable` |
| Time and identifiers | `kotlin.time`, `kotlin.uuid` | Standard library |
| HTTP | Ktor client | `ktor-client-core` in `commonMain`, one engine in each platform source set (Android and Darwin in the JetBrains tutorial) |
| Local database | SQLDelight, or Room when there is no web target | SQLDelight: runtime in `commonMain`, one driver per platform. Room is on the Android list of multiplatform libraries, without web support |
| Key-value storage | AndroidX DataStore | On the Android list of multiplatform libraries |
| Dependency injection | Koin; Metro for compile-time injection | [Platform code](04-platform-code.md#interfaces-and-injection) |
| ViewModel, lifecycle | AndroidX Lifecycle (the JetBrains Compose build in shared UI) | [Architecture](06-architecture-state-and-navigation.md) |
| Navigation | Navigation 3 | [Architecture](06-architecture-state-and-navigation.md#navigation) |
| Images in Compose | Coil | Named as multiplatform in the JetBrains documentation |

### Libraries you publish

The rules for [libraries in the Kotlin set](../kotlin-conventions/07-api-and-class-design.md#libraries) (explicit API mode, KDoc, no data classes in the public API, ABI validation, deprecation steps) hold for a shared module that other repositories consume. Multiplatform adds these rules:

- Declare only the targets that your users need, and test each one in CI. The set of targets is part of your compatibility promise.
- Publish with `maven-publish`. The plugin creates one publication per target and a root `kotlinMultiplatform` publication that resolves to the right target artifact. Publish everything with `publishAllPublicationsTo<Repository>`, or with `publishToMavenLocal` locally.
- Publish all publications from **one host**. Maven Central rejects duplicate publications. Kotlin/Native can produce `.klib` files on any host, but a library with cinterop, CocoaPods integration or final Apple binaries needs a Mac, so publish from a Mac in that case.
- The Android target publishes nothing by default. Add the publication for it in the `android {}` block of the Android-KMP plugin, and opt in to its tests explicitly ([setup](02-project-setup-and-tooling.md#android-target)).
- Design the API for use from common code. Give the same inputs the same results on every platform ([Kotlin set](../kotlin-conventions/11-platform-practices.md#kotlin-multiplatform)), and keep platform types out of the public signatures.

## Sources and raw notes

Pages read on 2026-11-06:

- [Adding dependencies on multiplatform libraries](https://kotlinlang.org/docs/multiplatform/multiplatform-add-dependencies.html): dependency types, version catalogs, common names, platform artifacts, `kotlin("test")`, project dependencies. [Use platform-specific APIs](https://kotlinlang.org/docs/multiplatform/multiplatform-connect-to-apis.html): check libraries first, klibs.io.
- [klibs.io](https://kotlinlang.org/docs/multiplatform/klibs-io.html), the Kotlin Multiplatform library catalog. [Kotlin Multiplatform DSL reference](https://kotlinlang.org/docs/multiplatform/multiplatform-dsl-reference.html): top-level `dependencies {}` is Experimental.
- [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html): levels of kotlinx.coroutines, kotlinx.serialization, kotlinx-datetime and kotlinx-io.
- [Kotlin Multiplatform and Jetpack libraries](https://developer.android.com/kotlin/multiplatform) (Android documentation, last updated 2026-11-04): the list of multiplatform Jetpack libraries and the support tiers by platform.
- [Create a multiplatform app using Ktor and SQLDelight](https://kotlinlang.org/docs/multiplatform/multiplatform-ktor-sqldelight.html) (JetBrains tutorial with Koin for the platform drivers), [Multiplatform ViewModel](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html) (`api` for exported dependencies; Koin and Metro).
- [Set up library publication](https://kotlinlang.org/docs/multiplatform/multiplatform-publish-lib-setup.html): publications, `publishAllPublicationsTo`, host requirements, duplicate publications, the Android library. The [Maven Central tutorial](https://kotlinlang.org/docs/multiplatform/multiplatform-publish-libraries-to-maven.html) was not read in full.
- The code block in this note was not compiled ([principles](01-principles-and-sources.md#applying-the-notes)).
