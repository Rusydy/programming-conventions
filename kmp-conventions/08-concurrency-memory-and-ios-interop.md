# Kotlin Multiplatform Concurrency, Memory and iOS Interop

## Summary

The coroutine rules of the [Kotlin set](../kotlin-conventions/09-coroutines-and-flow.md) hold on every target. Multiplatform adds three things: not every dispatcher exists on every target, Kotlin/Native has its own memory manager and garbage collector, and iOS code reaches Kotlin through a framework whose Objective-C API has rules of its own. Integrate iOS with direct integration, keep the Swift-facing API small, and mark what can fail with `@Throws`.

## Rules

### Dispatchers

- Inject dispatchers in common code, as the [Kotlin set](../kotlin-conventions/09-coroutines-and-flow.md#dispatchers-and-scopes) requires. Do not write a dispatcher inside a class.
- `Dispatchers.Default` and `Dispatchers.Unconfined` exist on every target. `Dispatchers.IO` is declared in the kotlinx.coroutines source set for JVM and Native targets, and JS and Wasm have no `IO`. So when a module declares a JS or Wasm target, `Dispatchers.IO` does not resolve in its `commonMain`, and it must not be the default value of a constructor parameter there ([decision 8](01-principles-and-sources.md#decisions-to-review)).
- Provide the dispatchers from the composition root. The DI module of each platform supplies `Dispatchers.IO` (Android, iOS, desktop) or `Dispatchers.Default` (web), and the class takes a `CoroutineDispatcher`. In a module without a web target a default value of `Dispatchers.IO` is allowed, as in the Kotlin set.
- `Dispatchers.Main` is there on Android, iOS and desktop, with conditions. On the JVM it needs an artifact at runtime: `kotlinx-coroutines-android` for Android and `kotlinx-coroutines-swing` for the desktop. On JS it equals `Default`. On native targets other than Apple's it is not available. Do not use `Main` in a class; the UI layer and `viewModelScope` use it.
- In tests nothing processes the main-thread queue on Kotlin/Native, so use `Dispatchers.setMain` from `kotlinx-coroutines-test` ([testing](09-testing-and-ci.md#coroutines-and-flows)).

### Memory and threads

- Kotlin/Native has a modern memory manager like the JVM's. Objects live in a shared heap that any thread can reach, and a tracing garbage collector frees them. Since Kotlin 2.4 the default collector is a concurrent mark and sweep (CMS) collector. Switch to the older collector with `kotlin.native.binary.gc=pmcs` only for a problem you can name ([setup](02-project-setup-and-tooling.md#compiler-options-and-properties)).
- Do not use `freeze()` or `@SharedImmutable`. They belong to the old memory model, and the migration guide says to remove all usages. Top-level properties can be read and changed from any thread.
- Share as little mutable state as possible, and guard what you share with a `Mutex` or confine it to one thread ([Kotlin set](../kotlin-conventions/09-coroutines-and-flow.md#shared-mutable-state)). The common atomic types in `kotlin.concurrent.atomics` were introduced as Experimental in Kotlin 2.1.20, and the Kotlin set's rule for non-Stable APIs applies to them.
- Keep work off the main thread on iOS as on Android. A `suspend` function is main-safe and moves its own blocking work with `withContext(dispatcher)` ([Kotlin set](../kotlin-conventions/09-coroutines-and-flow.md#suspend-functions)).

### iOS integration

- Use **direct integration** of the framework. An Xcode run-script build phase calls the Gradle task `embedAndSignAppleFrameworkForXcode` of the module that declares the framework, and the Kotlin code builds as part of the iOS build. The Kotlin Multiplatform IDE plugin sets this up by default. If the module name changes, change it in the script.
- Use **CocoaPods** only when the shared module imports Pod dependencies. The CocoaPods plugin cannot be combined with `embedAndSignAppleFrameworkForXcode`. If you move from CocoaPods to direct integration, remove the plugin and the Pod integration first.
- Use an **XCFramework in a Swift package** when the iOS app lives in another repository and consumes the shared code like a third-party library (remote integration). Keep `Package.swift` in a repository of its own, apart from the code it packages.
- Do not use Swift export and SwiftPM import in production. Both are Alpha in Kotlin 2.4. Swift export gives idiomatic Swift (`async` for `suspend` functions and `AsyncSequence` for flows), and a project that wants to try it does so in a branch.
- Declare the iOS targets `iosArm64()` and `iosSimulatorArm64()`, a static framework (`isStatic = true`), and a short `baseName`. The `baseName` is the module name that Swift imports. Set the Xcode deployment target to at least the Kotlin minimum (iOS 15.0 with Kotlin 2.4) ([setup](02-project-setup-and-tooling.md#targets)).
- Swift sees only the types of the framework's own module. To expose a type from another module, declare that module as `api` and list it in `export(...)` of the framework. Export as little as you can.
- Build and test Apple targets on a Mac, and in CI on a macOS runner ([CI](09-testing-and-ci.md#ci)).

### The Kotlin to Swift boundary

- Keep the Swift-facing API small: a few classes and interfaces that Swift needs, usually a facade for each feature. Make everything else `internal`, which hides it from Objective-C and Swift. Use `@HiddenFromObjC` only for a declaration that other Kotlin modules need but Swift must not see. It is Experimental and needs an opt-in.
- Put Swift-facing functions in a class or an `object`, and not at the top level. Kotlin turns each file with top-level declarations into a class named after the file, which reads badly in Swift.
- Mark every function that Swift calls and that can throw with `@Throws`, listing the narrowest exception types. Kotlin exceptions are unchecked. One that reaches Swift or Objective-C without `@Throws` is unhandled and terminates the app. A `suspend` function without `@Throws` passes on only `CancellationException`, as an `NSError`. When you add `@Throws` to a `suspend` function, list `CancellationException` as well, so that cancellation still reaches Swift as an error.
- Prefer a `sealed` result for failures that the caller should branch on ([Kotlin set](../kotlin-conventions/08-error-handling.md#choosing-the-mechanism)). The Swift code then switches over the result and the boundary needs no `@Throws`. Keep the rule that nobody swallows `CancellationException`.
- Objective-C export shows a `suspend` function as a function with a completion handler. Swift 5.5 `async` support for it exists but is highly experimental and limited. A `Flow` is not exported as a Swift type, so observe state through the ViewModel library from [architecture](06-architecture-state-and-navigation.md#viewmodel) or through a small callback API in the facade.
- Kotlin primitive boxes are Objective-C classes (`KotlinInt` for `Int`). Avoid nullable primitives, and generics beyond simple cases, in the Swift-facing API. The generics section of the Objective-C interop page lists the limits.
- Write KDoc for the Swift-facing API. The compiler copies it into the comments of the generated Objective-C header.
- Do not rename declarations with `@ObjCName`, which is Experimental. Choose names that read well in Swift, and keep them.

```kotlin
// fragment
class OrderFacade(private val orders: OrderRepository) {
    /** Places the order, or returns why it was rejected. */
    @Throws(OrderException::class, CancellationException::class)
    suspend fun place(order: Order): PlaceResult = orders.place(order)
}

class OrderException(message: String, cause: Throwable? = null) : Exception(message, cause)

sealed interface PlaceResult {
    data class Placed(val id: String) : PlaceResult
    data class Rejected(val reason: String) : PlaceResult
}
```

### Other targets

- **Desktop (JVM).** The `desktopApp` module is a JVM application with the Compose plugins. Packaging is configured in the `compose.desktop { application { } }` block. Add `kotlinx-coroutines-swing` for `Dispatchers.Main`.
- **Web.** Kotlin/JS is Stable. Kotlin/Wasm is Beta and runs only in browsers with WasmGC support, so it needs a written reason. The `webMain` source set is shared by the two web targets, and `webApp` holds the entry point.
- **Server (JVM).** A `server` module and a `core` module for the code shared with the clients keep server dependencies out of the client modules ([structure](03-project-structure-and-source-sets.md#modules)).

## Sources and raw notes

Pages read on 2026-11-06:

- kotlinx.coroutines sources on GitHub: `Dispatchers.common.kt` (the common `Dispatchers` object and the notes on `Main` per platform) and `concurrent/src/Dispatchers.kt` (the `expect val Dispatchers.IO`), `jsAndWasmShared/src/Dispatchers.kt` (no `IO`). That `Dispatchers.IO` is missing from the common view of a project with a web target follows from this layout and was not compiled.
- [Kotlin/Native memory management](https://kotlinlang.org/docs/native-memory-manager.html) (shared heap, CMS, `pmcs`, tests and the main thread), [Migrate to the new memory manager](https://kotlinlang.org/docs/native-migration-guide.html) (`freeze()` and `@SharedImmutable`), [What's new in Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html) (CMS default, Swift export Alpha, SwiftPM import, Apple minimum versions), [What's new in Kotlin 2.1.20](https://kotlinlang.org/docs/whatsnew2120.html) (atomic types).
- [Interoperability with Swift/Objective-C](https://kotlinlang.org/docs/native-objc-interop.html) (hiding, `@ObjCName`, errors and `@Throws`, suspending functions, top-level functions, primitive types, KDoc), [Swift export](https://kotlinlang.org/docs/native-swift-export.html).
- [iOS integration methods](https://kotlinlang.org/docs/multiplatform/multiplatform-ios-integration-overview.html), [Direct integration](https://kotlinlang.org/docs/multiplatform/multiplatform-direct-integration.html), [CocoaPods overview and setup](https://kotlinlang.org/docs/multiplatform/multiplatform-cocoapods-overview.html), [Swift package export setup](https://kotlinlang.org/docs/multiplatform/multiplatform-spm-export.html), [Adding Swift packages as dependencies](https://kotlinlang.org/docs/multiplatform/multiplatform-spm-import.html) (Alpha).
- [Multiplatform ViewModel](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html) (`Dispatchers.Main.immediate` on desktop), [Compatibility and versions](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html) (WasmGC browsers), [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html).
- The code block in this note was not compiled ([principles](01-principles-and-sources.md#applying-the-notes)).
