# Kotlin Multiplatform Testing and CI

## Summary

Write the tests of common code once, in `commonTest`, with `kotlin.test`, and run them on more than the JVM. Use fakes there, with the test rules of the [Kotlin set](../kotlin-conventions/10-testing.md). Tests of platform code live in the platform test source sets. CI compiles and tests every declared target: a Linux runner for the JVM and Android work, and a macOS runner for the Apple targets.

## Rules

### Common tests

- Put the tests of common code in `commonTest`, with one dependency: `commonTest.dependencies { implementation(kotlin("test")) }`. The plugin gives each test source set the right variant of `kotlin.test` (JUnit on the JVM and Android, the Kotlin/Native runner on iOS).
- Use only multiplatform libraries in `commonTest`, and stay inside the `kotlin.test` API. Do not use the `Asserter` directly. Check that a test library supports every target, as for any dependency ([dependencies](05-dependencies-and-libraries.md#choosing-a-library)).
- Name a test class after the class it tests plus `Test`, as in the Kotlin set. Name the tests in camelCase without backticks (`firstUserIsNullWhenRepositoryIsEmpty`). The Kotlin set allows backticked names only in JVM tests, and they need API 30 or newer on the Android runtime, while `commonTest` runs on the other runtimes too ([decision 6](01-principles-and-sources.md#decisions-to-review)). Backticked names are fine in `jvmTest` and `androidHostTest`, which run on the JVM.
- Use fakes, not mocks, in `commonTest`: a fake implements the common interface of the platform boundary ([platform code](04-platform-code.md#interfaces-and-injection)). A mocking library that works only on the JVM belongs in `jvmTest` or `androidHostTest`.
- Keep the tests hermetic, as in the Kotlin set: inject the clock and the dispatchers, and use no real network, clock or file system.

### Platform tests

- Test platform code in the test source set of its platform: `iosTest`, `jvmTest`, `androidHostTest` (a local unit test that runs on the JVM) and `androidDeviceTest` (an instrumented test that runs on a device or an emulator). The `expect`/`actual` declarations they test stay in the shared module.
- The Android-KMP library plugin turns host and device tests off by default. Opt in to each in the `android {}` block, with `withHostTest { }` and `withDeviceTest { }` (older AGP versions use `withHostTestBuilder` and `withDeviceTestBuilder`), and keep the sources in `src/androidHostTest` and `src/androidDeviceTest` ([setup](02-project-setup-and-tooling.md#android-target)).
- Run `./gradlew allTests` to run the tests of every target with its own runner. Gradle writes HTML reports to `build/reports/tests`. The reports of the Android tests are not merged into the `allTests` report, so read them separately.
- Run the tests with each runner that you ship. A test that passes on one runner can fail on another because of the platform ("physics" differences, such as scroll inertia, and runtime behaviour).

### Coroutines and flows

- Follow the [Kotlin set](../kotlin-conventions/10-testing.md#coroutines-and-flow): `runTest` returned from the test function (Kotlin/JS requires it), `StandardTestDispatcher(testScheduler)` injected into the class under test, and Turbine for flows where it supports your targets.
- On Kotlin/Native nothing processes the main-thread queue. Do not use `Dispatchers.Main` in a test unless you replaced it with `Dispatchers.setMain(testDispatcher)` from `kotlinx-coroutines-test`, and call `Dispatchers.resetMain()` afterwards.
- Opt in once to `ExperimentalCoroutinesApi` for the test compilations with the module-wide option, as the Kotlin set says, and not on each test.

### Compose UI tests

- The Compose Multiplatform test API (`runComposeUiTest`, which does not use JUnit's `TestRule`) is Experimental. Use it only with a written reason. A JUnit-based API exists for the desktop targets.
- Keep composables thin and test the state in the ViewModel with `commonTest`. Text rendering differs between platforms, so keep screenshot tests per platform and do not compare them across platforms ([Compose](07-compose-multiplatform.md#platform-behaviour)).

### CI

- Give every declared target a CI job that compiles it and runs its tests ([principle 5](01-principles-and-sources.md#principles)). Run plain `./gradlew` commands, as in the [Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#automation), and keep Gradle flags in `gradle.properties`.
- Split the work by runner:

| Runner | Work |
| --- | --- |
| Linux | `ktlint`, `./gradlew check`, `./gradlew jvmTest`, the Android host tests, and the Android debug build (`:androidApp:assembleDebug`) |
| macOS | Link the iOS framework, run the Apple tests (`./gradlew iosSimulatorArm64Test`) and build the iOS app for the simulator with `xcodebuild`, which needs no code signing |

- A JVM-only run does not prove that common code works on Kotlin/Native or Kotlin/JS ([principle 8](01-principles-and-sources.md#principles)). Run `commonTest` on at least one non-JVM target in CI, and that target is `iosSimulatorArm64` in a project with iOS.
- Cache Gradle with the Gradle setup action, as the JetBrains sample does, and set up the same JDK in every job (the JetBrains sample uses a composite action).
- Device tests need an emulator or a device. Run them in a job of their own and not in the jobs above.
- Publish a library from one host only ([dependencies](05-dependencies-and-libraries.md#libraries-you-publish)).

## Sources and raw notes

Pages read on 2026-11-06:

- [Test your multiplatform app](https://kotlinlang.org/docs/multiplatform/multiplatform-run-tests.html): common and platform tests, `kotlin.test`, `Asserter`, `androidHostTest` and `iosTest`, `allTests`, reports, the rules for tests in multiplatform projects.
- [Android-KMP library plugin](https://developer.android.com/kotlin/multiplatform/plugin): tests are off by default, `withHostTest`, `withDeviceTest`, the source directories.
- [Testing Compose Multiplatform UI](https://kotlinlang.org/docs/multiplatform/compose-test.html) (Experimental), [Default UI behavior on different platforms](https://kotlinlang.org/docs/multiplatform/compose-platform-specifics.html) (text rendering and screenshot tests).
- [Kotlin/Native memory management](https://kotlinlang.org/docs/native-memory-manager.html): unit tests and the main thread.
- [Configure GitHub Actions for a Kotlin Multiplatform application](https://kotlinlang.org/docs/multiplatform/github-actions-for-kmp.html): `jvmTest` on Linux, `xcodebuild` on a macOS runner, the composite Gradle setup action.
- The Kotlin set: [testing](../kotlin-conventions/10-testing.md), [test names](../kotlin-conventions/04-naming-comments-and-style.md#test-names), [automation](../kotlin-conventions/02-project-setup-and-tooling.md#automation).
- The task name `iosSimulatorArm64Test` follows the `<target>Test` pattern and was not run.
