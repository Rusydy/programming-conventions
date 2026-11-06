# Modern Kotlin Multiplatform by Release

## Summary

This cheat sheet lists what changed for multiplatform projects, release by release, and which old form each change replaces. The latest stable Kotlin is 2.4.21 (2026-10-08), the latest stable Compose Multiplatform is 1.12.2 (2026-10-15), and the latest Android Gradle plugin (AGP) is 9.5.0 (October 2026). Refresh this note after each Kotlin language release, about every six months, together with the [Kotlin set](../kotlin-conventions/12-modern-kotlin-by-release.md).

## Rules

### How to use this list

- New code and new projects use the modern form. Do not rewrite untouched code just to use it ([principles](01-principles-and-sources.md#applying-the-notes)).
- A change that is Alpha, Experimental or in beta is listed so that you recognise it, not so that you adopt it ([stability](01-principles-and-sources.md#stability-of-the-pieces)).
- Release dates of Kotlin come from the [Kotlin set](../kotlin-conventions/12-modern-kotlin-by-release.md). The release dates of Compose Multiplatform come from its GitHub releases.

### Kotlin and the Kotlin Multiplatform Gradle plugin

**Kotlin 2.4 (2026-06-03; 2.4.20 on 2026-09-07; 2.4.21 on 2026-10-08)**

- **Swift export is Alpha**, with `suspend` functions exported as Swift `async` functions and flows as `AsyncSequence`. **SwiftPM import** is new and not yet stable (Experimental in the release notes, Alpha in the multiplatform documentation). Neither is for production ([iOS integration](08-concurrency-memory-and-ios-interop.md#ios-integration)).
- The Kotlin/Native garbage collector is the concurrent mark and sweep (CMS) collector by default. `kotlin.native.binary.gc=pmcs` switches back.
- Apple targets have higher default minimum versions: iOS and tvOS 15.0, macOS 12.0, watchOS 8.0. Xcode 26.4 and LLVM 21 are supported.
- Default module names are the same on all platforms, `{group}:{project_name}`. The minimum AGP is 8.5.2.
- The K1 compiler is gone: `-language-version=1.9` is no longer supported.
- The Compose compiler flags `StrongSkipping` and `IntrinsicRemember` are errors and go away in Kotlin 2.5.0. Remove them from the build.
- Kotlin 2.5.0 is planned for December 2026.

**Kotlin 2.3 (2025-12-16; 2.3.20 on 2026-03-16)**

- The Android team's plugin `com.android.kotlin.multiplatform.library` is the way to configure the Android target. Use the `android` block, not `androidTarget`. Kotlin 2.3.0 warned about `androidTarget` and 2.3.10 reverted the warning, which gives projects on AGP 8.x more time.
- Kotlin 2.3.10 supports AGP up to 9.0.0.
- `macosX64`, `watchosX64` and `tvosX64` are deprecated since 2.3.20.

**Kotlin 2.2 (2025-06-23; 2.2.20 on 2025-09-10)**

- Kotlin/Wasm is Beta since 2.2.20. JetBrains advises Kotlin 2.2.20 or newer for projects with iOS and web targets.
- Kotlin 2.2.20 lists Xcode 16.4, and Kotlin 2.2.21 lists Xcode 26.0.

**Kotlin 2.1 (2024-11-27; 2.1.20 on 2025-03-20)**

- From 2.1.20 the Java source sets of the JVM target exist by default, and `jvm { withJava() }` is phased out.
- Common atomic types (`kotlin.concurrent.atomics`) arrive in 2.1.20 as Experimental.

**Kotlin 2.0 (2024-05-21) and 1.9**

- Kotlin 2.0 makes K2 Stable and ships the Compose compiler as a Kotlin Gradle plugin.
- Kotlin 1.9.20 (2023-11-01) makes Kotlin Multiplatform, the Kotlin/Native runtime, klib binaries and the CocoaPods integration Stable. Kotlin/Native itself is Stable since 1.9.0.
- The compatibility guide of Kotlin Multiplatform lists the removals since 2.0: Apple target shortcuts, the target presets API, bitcode embedding, the Gradle properties for the hierarchical structure and libraries published in legacy mode. Read it when you upgrade a project that is older than Kotlin 2.0.

### Compose Multiplatform

- **1.12 (1.12.2 on 2026-10-15).** Skia is updated to Milestone 150. The window and dialog API v2 is available for desktop, and `LocalSystemTheme` is deprecated. Compose Hot Reload has an MCP server for AI agents (not used by this set).
- **1.11.** Projects with native or web targets need Kotlin 2.3.10 for the latest features. `iosX64` and `macosX64` are removed, the minimum iOS version is 14, and a v2 of the Compose UI testing API arrives.
- **1.10.** The plugin aliases (`compose.ui` and others) are deprecated in favour of direct library references. The AndroidX `@Preview` annotation replaces the library's own. Navigation 3 is supported on all platforms. Compose Hot Reload is bundled with the Gradle plugin. `PredictiveBackHandler()` is deprecated in favour of `NavigationBackHandler()`.
- **1.9.** Compose Multiplatform for web is in Beta, and `@Preview` takes parameters.
- **1.8.** The UI framework moves fully to the K2 compiler.
- **1.6.10.** The Compose compiler Gradle plugin `org.jetbrains.kotlin.plugin.compose` is required.
- **1.13** is in beta on 2026-11-06. Do not use it.

### Android Gradle plugin

- **8.10.0** is the minimum for `com.android.kotlin.multiplatform.library`.
- **8.12.0** adds the `android {}` block in place of `androidLibrary {}`.
- **9.0** (Q4 2025) stops the Kotlin Multiplatform plugin from working with `com.android.application` and `com.android.library`. The legacy APIs sit behind `android.enableLegacyVariantApi=true`.
- **9.1.0-alpha09** deprecates `androidLibrary {}`.
- **AGP 10** (expected in the second half of 2026) removes the legacy APIs.
- **9.5.0** (October 2026) is above the AGP range that Kotlin 2.4.21 fully supports; check the compatibility table before you use it.

### Upgrade checklist

1. Read the What's new page of the target Kotlin release and the compatibility guide of Kotlin Multiplatform, then the What's new page of the Compose Multiplatform release you move to.
2. Check the target Kotlin version against Gradle, AGP and Xcode in the compatibility table ([setup](02-project-setup-and-tooling.md#versions-and-compatibility)), and Compose Multiplatform against Kotlin. Change the versions in the version catalog.
3. Update the tools that embed the Kotlin compiler or read its output (ktlint, KSP processors, SQLDelight) before you raise Kotlin, as in the [Kotlin checklist](../kotlin-conventions/12-modern-kotlin-by-release.md#upgrade-checklist).
4. Build every target with warnings visible. Fix new warnings in their own commit.
5. Run `ktlint`, `./gradlew check` and the tests on every CI runner, and build the iOS app in Xcode. Check the deployment target against the new Apple minimum version.
6. Move deprecated forms (`androidTarget`, the Compose aliases, the old `@Preview`) in their own commits, with no behaviour change.
7. Update this note and the digest.

## Sources and raw notes

Pages read on 2026-11-06:

- [What's new in Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html) and [2.4.20](https://kotlinlang.org/docs/whatsnew2420.html), [What's new in Kotlin 2.1.20](https://kotlinlang.org/docs/whatsnew2120.html), [Kotlin release process](https://kotlinlang.org/docs/releases.html) (Kotlin 2.5.0 planned for December 2026), [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html) (stable-since versions), [Kotlin/Native target support](https://kotlinlang.org/docs/native-target-support.html) (deprecated targets).
- [Kotlin Multiplatform compatibility guide](https://kotlinlang.org/docs/multiplatform/multiplatform-compatibility-guide.html): the version table (Gradle, AGP, Xcode), the deprecation cycle of `androidTarget`, Java source sets created by default, the removals since Kotlin 2.0.
- What's new in Compose Multiplatform [1.8](https://kotlinlang.org/docs/multiplatform/whats-new-compose-180.html), [1.9](https://kotlinlang.org/docs/multiplatform/whats-new-compose-190.html), [1.10](https://kotlinlang.org/docs/multiplatform/whats-new-compose-110.html), [1.11](https://kotlinlang.org/docs/multiplatform/whats-new-compose-111.html) and [1.12](https://kotlinlang.org/docs/multiplatform/whats-new-compose-112.html), the [Compatibility and versions](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html) page (1.6.10 and 1.8.0), and the [Compose Multiplatform releases](https://github.com/JetBrains/compose-multiplatform/releases) on GitHub (release dates).
- [Android-KMP library plugin](https://developer.android.com/kotlin/multiplatform/plugin) and [Android Gradle plugin release notes](https://developer.android.com/build/releases/gradle-plugin): AGP 8.10.0, 8.12.0, 9.0, 9.1.0-alpha09, 9.5.0 and AGP 10. [Updating projects to AGP 9](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html): the legacy variant API.
- The Kotlin set: [modern Kotlin by release](../kotlin-conventions/12-modern-kotlin-by-release.md) for the Kotlin release dates.
