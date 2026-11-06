# Kotlin Multiplatform Platform Code

## Summary

Look for a multiplatform library before you write platform code. When you need platform code, put an interface in `commonMain`, implement it in the platform source sets, and pass the implementation in through a constructor or the DI framework the project already uses. Use `expect`/`actual` only for small things such as a factory function, a value or the configuration of the DI framework. Android-only APIs stay in `androidMain` or the Android app module.

## Rules

### Choosing the mechanism

| Need | Mechanism |
| --- | --- |
| A multiplatform library already offers the API | Use the library; search klibs.io ([dependencies](05-dependencies-and-libraries.md#choosing-a-library)) |
| A small value or function that differs per platform (the platform name, a file path, the DI module of a platform) | `expect fun` or `expect val`, with the `actual` in the intermediate source set |
| A service with behaviour (secure storage, a printer driver, a file picker) | A common `interface`, one implementation per platform, passed in through a constructor |
| A common type must inherit from a platform class | `expect class` as a last resort (Beta) |
| An existing platform type is exactly the expected type | `actual typealias` |

- JetBrains: "rely on standard language constructs wherever possible instead of using expected and actual declarations." An interface does not limit the design to one implementation per platform, and it is easy to replace with a fake in tests.
- Do not use `@OptionalExpectation`. It needs an opt-in to an experimental API.

### expect and actual

- An `expect` declaration has no implementation. Every `expect` declaration needs an `actual` declaration in every platform source set that compiles the common code, in the **same package**. Put the `actual` in the intermediate source set (`iosMain`) and not in each target set ([source sets](03-project-structure-and-source-sets.md#source-sets-and-hierarchy)).
- Prefer `expect fun` and `expect val`. Choose between them with the [Kotlin rule](../kotlin-conventions/05-idiomatic-language-use.md#functions-and-properties): a property only when the value cannot throw, is cheap and is stable.
- Keep an `expect` signature small. Return a common interface or a common type, and do not let a platform type appear in it.
- **Avoid `expect class`.** Expected and actual classes are Beta, and JetBrains does not recommend them where an interface would do. If you must use one, for example to inherit from a platform base class, add the compiler flag once in the module and do not suppress the warning in code:

```kotlin
// fragment
kotlin {
    compilerOptions {
        // The flag has no typed property yet, so freeCompilerArgs is the exception.
        freeCompilerArgs.add("-Xexpect-actual-classes")
    }
}
```

- Without that flag the compiler warns about each expected class, and `allWarningsAsErrors` turns the warning into a failed build ([Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#compiler-settings)).
- Do not add entries in an `actual enum` that the `expect enum` does not have. Every `when` over the enum then needs an `else`, which breaks the [exhaustive `when` rule](../kotlin-conventions/06-null-safety-and-types.md) of the Kotlin set.
- Use `actual typealias` to reuse a platform type, in the same package as the `expect` declaration.

### Interfaces and injection

- Express a platform dependency in common code as an interface, and pass it to the class that needs it through the constructor ([Kotlin set](../kotlin-conventions/07-api-and-class-design.md#dependencies-and-testability)). Put the implementations in the platform source sets, and the fakes in `commonTest`.
- Provide the implementation in one of these ways, in this order of preference:
  1. **The DI framework the project already uses.** Then `expect`/`actual` is needed only in the configuration of the DI framework (for example `expect val platformModule: Module`). JetBrains recommends the DI framework for platform dependencies too, so the project does not mix two ways of injecting.
  2. **Constructor injection from the entry point.** The app module creates the platform implementation and passes it to a common function or class. This is enough to adopt Kotlin Multiplatform.
  3. **An `expect fun` factory** that returns the interface. This is what the wizard generates, and it is fine for a small project without a DI framework.
- Use one of the three in a module, not a mix.
- When a project needs a DI framework, use one that supports Kotlin Multiplatform. JetBrains documents Koin (runtime, DSL or annotations) and Metro (compile time, a compiler plugin). Hilt does not work in common code. Koin is the default of this set ([decision 9](01-principles-and-sources.md#decisions-to-review)).
- An implementation may be written in Swift and passed to Kotlin from the iOS app at start-up, through the DI framework. Use this only for an API that exists only in Swift or Objective-C. It makes the shared module depend on the iOS app for that piece, so it is not self-sufficient.

```kotlin
// fragment
// commonMain
interface SecureStorage {
    suspend fun read(key: String): String?
    suspend fun write(key: String, value: String)
}

class SessionRepository(private val storage: SecureStorage) {
    suspend fun token(): String? = storage.read("token")
}

// iosMain
class KeychainSecureStorage : SecureStorage {
    override suspend fun read(key: String): String? = TODO("Keychain call")
    override suspend fun write(key: String, value: String) = TODO("Keychain call")
}
```

### Android-only and platform APIs

- Keep Android-only APIs in `androidMain` or in the Android app module: `Context`, `Activity`, `LocalContext`, `LocalConfiguration`, `ComposeView`, `LocalView` and Hilt. Compose Multiplatform lists these as Android-only, and common code cannot see them.
- Do not pass a `Context` through common code. Hide it behind an interface and let the Android implementation hold it, created in the app module.
- Call Apple frameworks (`platform.*`) only inside the implementation classes of `iosMain`. Opt in to the API once for the source set, with the module-wide option of the [Kotlin set](../kotlin-conventions/02-project-setup-and-tooling.md#compiler-settings), and not with `@OptIn` on each class.
- Importing a C or Objective-C library with cinterop is Beta, and it needs a Mac to build. Wrap it behind an interface in `iosMain`, so that common code and the tests never touch it.
- Keep `expect`/`actual` declarations out of the app modules. A declaration there is invisible to the other platforms ([structure](03-project-structure-and-source-sets.md#modules)).

## Sources and raw notes

Pages read on 2026-11-06:

- [Expected and actual declarations](https://kotlinlang.org/docs/multiplatform/multiplatform-expect-actual.html): the rules, functions, properties and objects, the recommendation on dependency injection, expected classes (Beta, `-Xexpect-actual-classes`), type aliases, enum entries, `OptionalExpectation`.
- [Use platform-specific APIs](https://kotlinlang.org/docs/multiplatform/multiplatform-connect-to-apis.html): check libraries first, interfaces in common code, the three ways to provide an implementation, Koin example, an implementation in Swift.
- [Compose Multiplatform: Android-only components](https://kotlinlang.org/docs/multiplatform/compose-android-only-components.html), [Multiplatform ViewModel](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html) (Koin and Metro).
- [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html): C and Objective-C interop is Beta. [Set up library publication](https://kotlinlang.org/docs/multiplatform/multiplatform-publish-lib-setup.html): cinterop needs a Mac host.
- The Kotlin set: [layout](../kotlin-conventions/03-project-layout-and-packages.md#multiplatform-source-sets), [platform practices](../kotlin-conventions/11-platform-practices.md#kotlin-multiplatform), [API design](../kotlin-conventions/07-api-and-class-design.md).
- The code blocks in this note were not compiled ([principles](01-principles-and-sources.md#applying-the-notes)).
