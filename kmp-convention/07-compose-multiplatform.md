# Compose Multiplatform

## Summary

Compose Multiplatform shares Compose UI across Android, iOS, desktop and web with the same API as Jetpack Compose, so the Compose rules of the [Kotlin set](../kotlin-conventions/11-platform-practices.md#android-and-jetpack-compose) apply unchanged to common code. This note adds what is specific to sharing UI: when to share, the plugins and artifacts, resources, previews, entry points and the differences between platforms.

## Rules

### Adopting

- Share the UI when every app needs the same screens. Keep a native UI where the look or the integration of the platform matters, and share the ViewModel instead ([architecture](06-architecture-state-and-navigation.md#layers-and-sharing)). The choice is per app.
- Compose Multiplatform is Stable on Android, iOS and desktop. For the web it is Beta, on Wasm only ([stability](01-principles-and-sources.md#stability-of-the-pieces)).
- Put the shared UI in `sharedUI`, or in `shared` when there is one shared module. App modules hold only the entry points ([structure](03-project-structure-and-source-sets.md#modules)).
- Write common composables with the rules of the Kotlin set: PascalCase nouns, `modifier: Modifier = Modifier` as the first optional parameter, hoisted state, stable keys in lazy lists.
- Do not use Android-only Compose APIs in common code (`LocalContext`, `LocalConfiguration`, `LocalView`, `ComposeView`, `Activity`). The IDE reports them as unavailable ([platform code](04-platform-code.md#android-only-and-platform-apis)).

### Dependencies and compiler plugin

- Apply `org.jetbrains.compose` and `org.jetbrains.kotlin.plugin.compose` in every module that contains composables, the app modules included. The Compose compiler plugin has the same version as the Kotlin plugin, so it takes `version.ref = "kotlin"` ([setup](02-project-setup-and-tooling.md#plugins-and-modules)).
- Reference Compose Multiplatform libraries directly in the version catalog. Compose Multiplatform 1.10 deprecated the plugin aliases (`compose.ui`, `compose.foundation`, `compose.material3`). The groups are `org.jetbrains.compose.ui`, `org.jetbrains.compose.foundation` and `org.jetbrains.compose.material3`, and the deprecation notice of each alias names the exact coordinates. JetBrains structure pages that still show the aliases are out of date.
- Add the AndroidX libraries that Compose needs through the JetBrains artifacts of the same name, for example `org.jetbrains.androidx.lifecycle:lifecycle-runtime-compose` and `org.jetbrains.androidx.navigation3:navigation3-ui`. JetBrains publishes them together with the Android artifact under one group id, so the Android app still uses the original Android library.
- Compose Multiplatform releases separately from Kotlin. The latest release works with the latest Kotlin. Projects with native or web targets need Kotlin 2.3.10 or newer for the latest features of Compose Multiplatform 1.11, and JetBrains advises Kotlin 2.2.20 or newer for iOS and web in general. Check [Compatibility and versions](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html) before you upgrade.
- Use a release, not an alpha, beta or EAP version, in an app. Compose Multiplatform 1.13.0 was in beta on 2026-11-06.
- Compose Multiplatform runs on Android 5.0 (API 21) and newer, and on 64-bit platforms only. The desktop target needs JDK 11 or newer to run, and JDK 17 or newer to package a distribution.

### Resources

- Put resources in `src/commonMain/composeResources` of the module that owns them. Use these subfolders: `drawable` for images (PNG, JPEG, WebP, bitmap and vector XML without references to Android resources), `font`, `values` for strings and `files` for anything else. Add qualifiers for locale, density and theme to the folder names.
- Add the resources library to `commonMain` of that module (`org.jetbrains.compose.components:components-resources`), and read resources through the generated `Res` class: `painterResource(Res.drawable.logo)`.
- The generated package is named after the module. Moving resources to another module changes the imports of `Res`, so keep resources in the module that has the UI.
- In an Android-KMP library module, set `androidResources { enable = true }` to use the resources in the Android app ([setup](02-project-setup-and-tooling.md#android-target)). JetBrains marks this support as Experimental.
- Use custom directories (`compose.resources { customDirectory(...) }`) only for files that a Gradle task produces or that must stay in a fixed folder.
- The `Res` accessors are generated code and are exempt from the rules of the Kotlin set.

### Previews and tooling

- Use the AndroidX `@Preview` annotation in common code (Compose Multiplatform 1.10 and newer; the library's own annotation is deprecated). Add `org.jetbrains.compose.ui:ui-tooling-preview` to `commonMain`.
- Previews in common code need an Android target, because they depend on Android libraries. Add the tooling to the runtime classpath of the Android target, as in the [setup note](02-project-setup-and-tooling.md#android-target).
- Compose Hot Reload is bundled with the Compose Multiplatform Gradle plugin since 1.10. It runs on the desktop JVM target and needs Kotlin 2.1.20 or newer and a JVM target compatible with Java 21 or earlier. Use it as a development tool only, and do not depend on it in a build.

### Entry points

- Every platform has a native entry point that calls one common composable, usually `App()`. Keep the entry points in the app modules:
  - Android: `setContent { App() }` in a `ComponentActivity`.
  - iOS: a function in `iosMain` such as `fun MainViewController() = ComposeUIViewController { App() }`, which the Swift app calls.
  - Desktop: `application { Window(...) { App() } }`.
  - Web: `ComposeViewport { App() }` in `main()`.
- `App()` takes no platform types. Pass platform dependencies as parameters of interface type or through the DI framework ([platform code](04-platform-code.md#interfaces-and-injection)).
- Put platform behaviour that belongs to the entry point there: edge-to-edge on Android, the window on desktop, the host view controller on iOS.

### Platform behaviour

- Expect differences between platforms and test the UI on each target:
  - **Keyboard and insets.** iOS imitates the Compose window-insets approach and the safe areas, so the keyboard may sit slightly differently. Check that it never covers important UI.
  - **Pointer input.** Desktop treats all pointer input as mouse input, so it has no multitouch gestures such as pinch to zoom.
  - **Back.** Android has the back gesture, Compose Multiplatform adds it on iOS, and desktop uses the Esc key.
  - **Text.** Each system picks its own default font and renders glyphs differently. Set a font explicitly when the design needs the same look, and take screenshot tests per platform.
  - **Native pop-ups**, such as the actions of a text selection, look like the platform and cannot be styled.
- Embed native views only through the documented interop (SwiftUI and UIKit on iOS, Swing on desktop). Keep that code in the platform source set or the app module.
- Keep the web target out of a project unless you have decided to accept Beta ([decision 5](01-principles-and-sources.md#decisions-to-review)).

## Sources and raw notes

Pages read on 2026-11-06:

- [Relationship between Compose Multiplatform and Jetpack Compose](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-and-jetpack-compose.html), [How multiplatform Jetpack libraries are packaged](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-jetpack-libraries.html), [Android-only components](https://kotlinlang.org/docs/multiplatform/compose-android-only-components.html).
- [Compatibility and versions](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html): supported platforms, Kotlin compatibility, the Compose compiler plugin, desktop JDK limits. What's new in Compose Multiplatform 1.10.3 (aliases deprecated, `@Preview`, Navigation 3, Hot Reload bundled), 1.11.1 (minimum Kotlin 2.3.10, `iosX64` removed) and 1.12.2.
- [Setup and configuration for multiplatform resources](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-resources-setup.html), [Access and usage](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-resources-usage.html), [Compose UI previews](https://kotlinlang.org/docs/multiplatform/compose-previews.html), [Compose Hot Reload](https://kotlinlang.org/docs/multiplatform/compose-hot-reload.html).
- [Native application entry points](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-entry-points.html), [Default UI behavior on different platforms](https://kotlinlang.org/docs/multiplatform/compose-platform-specifics.html).
- [Recommended project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-project-recommended-structure.html) and [Updating projects to AGP 9](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html): resource imports change with the module. The latest stable release number comes from the [Compose Multiplatform releases](https://github.com/JetBrains/compose-multiplatform/releases) on GitHub.
- The code in this note is inline and was not compiled ([principles](01-principles-and-sources.md#applying-the-notes)).
