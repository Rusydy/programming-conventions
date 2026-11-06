# Kotlin Multiplatform Project Setup and Tooling

## Summary

A Kotlin Multiplatform build is Gradle with the Kotlin DSL and a version catalog, as in the [Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md). It adds the Kotlin Multiplatform plugin in the shared module, the Android-KMP library plugin for the Android target, a separate module for each app entry point (mandatory with Android Gradle plugin 9), the Compose plugins where UI is shared, and Xcode for Apple targets. Declare only the targets that CI builds, and keep the defaults of the plugin.

## Rules

### Versions and compatibility

- Follow the [Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#versions-and-compatibility) for the Kotlin, Gradle and Android Gradle plugin (AGP) ranges. The multiplatform compatibility table adds the Xcode version: read the Xcode column in the row of your Kotlin version (Kotlin 2.4.0 to 2.4.10 lists Xcode 26.4).
- AGP 9 needs Gradle 9.1.0 or newer, and newer AGP releases raise that minimum (AGP 9.5.0, released in October 2026, lists Gradle 9.6.0 as its minimum). AGP 9.5.0 is also above the AGP range that the Kotlin set lists as fully supported for Kotlin 2.4.20 to 2.4.21 (up to 9.3.1). Stay inside the range of the compatibility table and raise AGP in its own commit.
- The Android-KMP library plugin needs AGP 8.10.0 and Kotlin Gradle plugin 2.0.0 or newer. The `android {}` block needs AGP 8.12 or newer ([Android target](#android-target)).
- Compose Multiplatform ships separately from Kotlin. The latest release works with the latest Kotlin, and its Compose compiler plugin must have the same version as the Kotlin plugin ([Compose](07-compose-multiplatform.md#dependencies-and-compiler-plugin)).

### Plugins and modules

- Declare each plugin once in `gradle/libs.versions.toml` and apply it by alias. List every plugin in the root `build.gradle.kts` with `apply false`, as JetBrains does, so that modules do not conflict when they apply it.
- Put what several shared modules have in common (the target list, compiler options, the `android {}` block) in a convention plugin of the included `build-logic` build ([Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#gradle-build)). Every shared module then declares the same targets.
- Apply these plugins per module:

| Module | Plugins |
| --- | --- |
| `shared` (or `sharedLogic`) | `org.jetbrains.kotlin.multiplatform`, `com.android.kotlin.multiplatform.library` |
| `sharedUI`, or `shared` when it holds UI | the two above, plus `org.jetbrains.compose` and `org.jetbrains.kotlin.plugin.compose` |
| `androidApp` | `com.android.application`, plus the two Compose plugins when it has UI; no `org.jetbrains.kotlin.android` ([AGP 9 has built-in Kotlin](../kotlin-conventions/02-project-setup-and-tooling.md#android-gradle-plugin-9)) |
| `desktopApp` | `org.jetbrains.kotlin.jvm`, plus the two Compose plugins |
| `webApp` | `org.jetbrains.kotlin.multiplatform`, plus the two Compose plugins |
| `iosApp` | none: it is an Xcode project, and Gradle builds the framework from the shared module |

```toml
[versions]
agp = "<version from the compatibility table>"
kotlin = "2.4.21"
compose-multiplatform = "1.12.2"

[plugins]
kotlinMultiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
androidMultiplatformLibrary = { id = "com.android.kotlin.multiplatform.library", version.ref = "agp" }
androidApplication = { id = "com.android.application", version.ref = "agp" }
composeMultiplatform = { id = "org.jetbrains.compose", version.ref = "compose-multiplatform" }
composeCompiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
```

### Android target

- Use `com.android.kotlin.multiplatform.library` for the Android target of a shared module. The Android documentation calls it the officially supported tool for this. With AGP 9 the Kotlin Multiplatform plugin no longer works with `com.android.library` or `com.android.application`.
- The legacy way (`androidTarget()` with `com.android.library`) works on AGP 8.x, or on AGP 9 with `android.enableLegacyVariantApi=true`. AGP 10 (expected in the second half of 2026) removes those APIs. Treat `androidTarget()` as a layout to migrate, and migrate in its own change.
- Configure the target in `kotlin { android { } }` (AGP 8.12 and newer). Before AGP 8.12 the block is `androidLibrary {}`, which is deprecated since AGP 9.1.0-alpha09.
- Give the library a `namespace` that differs from the namespace of the app module.
- Opt in to what you need, because the plugin turns most things off to keep the build fast: `androidResources { enable = true }` for `res` folders and for Compose resources, `withJava()` only if the module has Java sources, and the host and device tests ([testing](09-testing-and-ci.md#platform-tests)).
- The plugin has a single variant. It has no build types and no product flavors. When you need them, native builds (`externalNativeBuild`) or `BuildConfig`, create a separate `com.android.library` module and depend on it from `androidMain`. For build metadata on all targets use a generator plugin, as the Android documentation suggests with BuildKonfig.
- Android sources live in `src/androidMain`, `src/androidHostTest` and `src/androidDeviceTest` only. `src/main`, `src/test` and `src/androidTest` do not exist for this plugin.
- Android-only dependencies go in `androidMain.dependencies {}`. A tool that must not reach the published API, such as the Compose preview tooling, goes in `"androidRuntimeClasspath"(...)` and not in `debugImplementation`, which needs build types.
- The Android app module is an ordinary application module that depends on the shared module. Keep the activity, the manifest and Android-only wiring there, and keep every `expect` and `actual` declaration in the shared module ([structure](03-project-structure-and-source-sets.md#modules)).

```kotlin
// fragment
// shared/build.gradle.kts
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
}

kotlin {
    android {
        namespace = "com.example.app.shared"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()
    }
    iosArm64()
    iosSimulatorArm64()
    jvm()

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
    }
}
```

### Targets

- Declare only the targets that you ship, and give each one a CI job ([principle 5](01-principles-and-sources.md#principles)). The usual set is the Android target, `iosArm64()` and `iosSimulatorArm64()` for iOS, `jvm()` for desktop or server, and `js { browser() }` for web.
- Do not declare `iosX64()` or `macosX64()`. Compose Multiplatform 1.11 removed them, and Kotlin has deprecated `macosX64` since 2.3.20. The simulator target is `iosSimulatorArm64()`.
- `wasmJs { browser() }` is Beta and needs `@OptIn(ExperimentalWasmDsl::class)`. Add it only with a written reason.
- Do not call `withJava()` on the `jvm()` target. Since Kotlin 2.1.20 the Java source sets exist by default, and JetBrains is phasing the function out. This is a different function from `withJava()` in the `android {}` block.
- Kotlin 2.4 raised the default minimum versions of Apple targets to iOS and tvOS 15.0, macOS 12.0 and watchOS 8.0. Set the deployment target of the Xcode project to match, and do not lower it with `-Xoverride-konan-properties` without a reason.
- A source set sees only the APIs that exist on all of its targets. In a project with one target (for example only the JVM) common code can still use target-specific symbols. They disappear as soon as you add a second target, so expect that when you migrate a single-target project.
- Kotlin cannot share a source set between several JVM targets, between a JVM and an Android target, or between several JS targets. Use one JVM target next to the Android target.
- A framework for Xcode is declared in the module that Xcode consumes. `baseName` is the name that Swift imports, and `isStatic = true` is what the JetBrains samples use:

```kotlin
// fragment
kotlin {
    listOf(iosArm64(), iosSimulatorArm64()).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }
}
```

### Compiler options and properties

- Set compiler options once in the top-level `kotlin { compilerOptions { } }` block, which applies to all source sets, with the flags of the [Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#compiler-settings) (`allWarningsAsErrors`, `extraWarnings`). Use `freeCompilerArgs` only for a flag that has no typed property.
- `kotlin { jvmToolchain(<LTS version>) }` sets the JVM target for all JVM-based targets, the Android target included. `android { compilerOptions { jvmTarget } }` overrides it for the Android target, and compiler options of one compilation override both. Use the toolchain alone unless a target needs another JVM version.
- Keep the **default hierarchy template**. A manual `dependsOn()` call switches it off with a warning. Opt out with `kotlin.mpp.applyDefaultHierarchyTemplate=false` only in a project that configures the whole hierarchy by hand ([source sets](03-project-structure-and-source-sets.md#source-sets-and-hierarchy)).
- Kotlin 2.4 turned on the concurrent mark and sweep garbage collector for Kotlin/Native. Set `kotlin.native.binary.gc=pmcs` in `gradle.properties` only as a dated workaround for a problem you can name ([memory](08-concurrency-memory-and-ios-interop.md#memory-and-threads)).
- Set `android.enableLegacyVariantApi=true` only as a short bridge during the AGP 9 migration, with a comment that names the date it goes away.

### IDE and Xcode

- Use IntelliJ IDEA or Android Studio with the Kotlin Multiplatform IDE plugin (Stable). It adds environment checks, launching and debugging of iOS apps, and support for Compose resources and previews.
- Xcode is required for iOS code and for running iOS apps. Kotlin/Native can produce `.klib` files for Apple targets on any host, but final Apple binaries, their tests, cinterop and CocoaPods need a Mac. Do the iOS work on a Mac.

### Tools not used

- **Kotlin Toolchain**, the JetBrains CLI build tool configured with `project.yaml` and `module.yaml`, is Alpha. Gradle stays the build tool. Revisit it when it is Stable.
- **The top-level `dependencies {}` block of `kotlin {}`** is Experimental. Declare dependencies per source set ([dependencies](05-dependencies-and-libraries.md#declaring-dependencies)).
- **Swift export and SwiftPM import** are Alpha ([iOS](08-concurrency-memory-and-ios-interop.md#ios-integration)).

## Sources and raw notes

Pages read on 2026-11-06:

- [Updating multiplatform projects with Android apps to use AGP 9](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html) (plugin ids, `kotlin.androidLibrary`, Gradle 9.1.0, legacy variant API until AGP 10), [Recommended project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-project-recommended-structure.html) (plugins per module, `apply false`, `baseName` and `isStatic`).
- [Android-KMP library plugin](https://developer.android.com/kotlin/multiplatform/plugin) (Android documentation): the `android {}` block, opt-in tests, resources and Java, single variant, `androidRuntimeClasspath`, JVM target precedence, source directories, minimum AGP and Kotlin versions. [Android Gradle plugin release notes](https://developer.android.com/build/releases/gradle-plugin): AGP 9.5.0.
- [Source set hierarchy](https://kotlinlang.org/docs/multiplatform/multiplatform-hierarchy.html), [The basics of project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-discover-project.html) (single-target note), [Set up library publication](https://kotlinlang.org/docs/multiplatform/multiplatform-publish-lib-setup.html) (host requirements), [Recommended IDEs](https://kotlinlang.org/docs/multiplatform/recommended-ides.html), [Kotlin Toolchain](https://kotlinlang.org/docs/multiplatform/kotlin-toolchain.html), [Compatibility and versions](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html), the multiplatform compatibility guide (version table).
- [What's new in Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html) (Apple minimum versions, concurrent garbage collector, Swift export Alpha, minimum AGP), [Kotlin/Native target support](https://kotlinlang.org/docs/native-target-support.html) (deprecated targets), what's new in Compose Multiplatform 1.11 (`iosX64` and `macosX64` removed).
- The `top-level dependencies {}` status comes from the [Kotlin Multiplatform DSL reference](https://kotlinlang.org/docs/multiplatform/multiplatform-dsl-reference.html).
- The code blocks in this note were not compiled ([principles](01-principles-and-sources.md#applying-the-notes)).
