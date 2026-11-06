# Kotlin API and Class Design

## Summary

Design for the caller. Keep the surface small, name and order parameters consistently, make the safe behaviour the default, validate input, hand out read-only types and pass dependencies in. A published library adds stricter rules for visibility, documentation and compatibility, collected in the last section. The sources are the Kotlin library authors' guidelines, which apply in spirit to application code as well.

## Rules

### Functions and parameters

- Order parameters from general to specific: required inputs first, optional ones last. Use one name for one concept across the API (`offset` and `length`, or `startIndex` and `endIndex`, not both pairs), and make overloads behave identically.
- Use default values instead of overloads in application code ([idioms](05-idiomatic-language-use.md#functions-and-properties)). A published library follows a different rule, see [Libraries](#libraries).
- Do not take a `Boolean` that switches behaviour: `doWork(true)` says nothing at the call site, and named arguments cannot be forced on callers. Provide two functions with descriptive names, or an `enum class` when there are several modes or more may come.
- Use classes for data and state. Use inheritance only for hierarchical state. When all the state can be passed as parameters, write a top-level function, and make it an extension function when calls are chained.
- Declare the core concept of a type as members, and extra behaviour and derived information as extension functions and properties. The standard library does this with `CharSequence`.
- Prefer composing small operations to adding customisation parameters. `Flow` has separate `buffer` and `conflate` operators instead of parameters on every operator, and Compose composables take one `Modifier` instead of a parameter per visual option.
- Do not use arithmetic types for things you never calculate with, such as identifiers. Use a value class ([types](06-null-safety-and-types.md#value-classes)). Reuse standard types such as `kotlin.time.Duration` instead of inventing new ones.
- Accept and return read-only collections. Mutable collections are not thread-safe, and the caller cannot tell whether a mutation changes your internals. Avoid arrays in an API; if you must use one, copy it on the way in and out. A `vararg` parameter is copied by the compiler.
- Choose how a function reports failure and keep the choice consistent ([error handling](08-error-handling.md)).

```kotlin
enum class RenderMode { FAST, SMALL }

fun render(mode: RenderMode): String = "rendered in $mode mode"

val quick = render(RenderMode.FAST)
```

### Dependencies and testability

- Pass dependencies in through the constructor. Do not reach for global state, mutable `object` singletons or stateful top-level functions: tests then have to control hidden values. The Kotlin guidelines use the system clock as the example and inject a `Clock` instead of calling a global `now()`.
- Inject the things that make tests slow or flaky: a `Clock` and coroutine dispatchers ([coroutines](09-coroutines-and-flow.md#dispatchers-and-scopes)).
- Keep boundaries small: depend on a narrow interface that a test can replace with a fake ([testing](10-testing.md)).

```kotlin
import kotlin.time.Clock
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant

class TokenIssuer(private val clock: Clock) {
    fun expiresAt(): Instant = clock.now() + 15.minutes
}

val issuer = TokenIssuer(Clock.System)
```

### DSLs and builders

- Write a builder as a function whose last parameter is a lambda with a receiver. Callers then omit the parentheses and set optional values as properties inside the lambda.
- Pass required values as function parameters. The compiler cannot check that a lambda sets a property.
- Name a factory function after the type it returns, starting with a capital letter, when it has no special semantics (`Json { ... }`).
- Add a `@DslMarker` annotation to the receiver types of a nested DSL so that an inner lambda cannot call the outer receiver's functions by accident.
- A DSL keeps compatibility easier than a function with many parameters, because adding an option adds a property and does not change a signature.

```kotlin
class Route(val path: String) {
    var method: String = "GET"
    var timeoutSeconds: Int = 30
}

fun route(path: String, configure: Route.() -> Unit = {}): Route = Route(path).apply(configure)

val health = route("/health") { timeoutSeconds = 5 }
```

### Context parameters

- Context parameters are stable since Kotlin 2.4. They let a function or property declare a dependency that the caller's scope supplies implicitly, such as a logger or a service that is shared and rarely changes across a group of calls. This set uses them only for that case and keeps ordinary parameters as the default. Explicit context arguments and callable references are still experimental.
- Context parameters replace the older context receivers. Migrate code that uses context receivers; the IDE offers assisted migration.

```kotlin
interface Logger {
    fun info(message: String)
}

context(logger: Logger)
fun process(orderId: String): String {
    logger.info("processing $orderId")
    return orderId
}

fun run(logger: Logger): String = with(logger) { process("A-1") }
```

### Java interoperability

Add these annotations only when Java (or, for `@Throws`, Swift or Objective-C) code calls the Kotlin code. Kotlin-only code needs none of them.

| Annotation | Effect |
| --- | --- |
| `@JvmStatic` | Generates a static method for a function in an `object` or a `companion object` |
| `@JvmField` | Exposes a property as a field (not for `private`, `open`, `override`, `const` or delegated properties) |
| `@JvmOverloads` | Generates overloads for default parameters (in a library, prefer `@IntroducedAt` for newly added optional parameters; it is experimental in Kotlin 2.4) |
| `@JvmName` | Sets the name of the facade class or of a method, for example to avoid a clash or to unmangle a function that takes a value class |
| `@Throws` | Declares the exceptions that Java sees as checked, or that Swift receives as errors |

### Libraries

These rules apply to code published for others to depend on, including shared modules of a multiplatform project that other repositories consume.

- Turn on explicit API mode: `kotlin { explicitApi() }`. The compiler then requires a visibility modifier and an explicit type on every declaration that is part of the public API, and `explicitApiWarning()` reports them as warnings first.
- Write KDoc for every public member except overrides that add nothing ([style](04-naming-comments-and-style.md#comments-and-kdoc)). Document by example, and explain lambda parameters.
- Keep third-party and platform types out of the public API unless the benefit is clear, because they tie your library to them. Make a type `sealed` when users must not extend it.
- Give every stateful type a `toString()` that is useful in logs and the debugger, without sensitive data. Do not rely on a `data class` for it in a public type.
- Do not expose a `data class`, because adding a property changes the constructor, `copy()` and `componentN()` signatures.
- Keep the old signature when you evolve a function. Adding a parameter, even one with a default, breaks binary compatibility, so add an overload instead. Do not widen or narrow a return type, and declare return types explicitly.
- Use `@RequiresOptIn` markers to separate preview or experimental parts from the stable API, and propagate the opt-in requirement of anything you depend on. Do not use opt-in to deprecate an existing declaration; use `@Deprecated`.
- Deprecate in steps: `@Deprecated` with a `message` and a `replaceWith`, first at warning level, then error, then hidden, over several minor releases. Remove the declaration only in a major release.
- Validate compatibility in the build. The Kotlin Gradle plugin has an `abiValidation {}` block (experimental) whose `checkKotlinAbi` task runs with `check`, and `updateKotlinAbi` refreshes the reference dump. The separate Binary compatibility validator plugin does the same with `apiDump` and `apiCheck`.
- Set the language version and the API version to the same value unless you have a reason. They decide which compiler and standard library versions your consumers need.
- Test every documented behaviour of every entry point, including boundary cases, and run the suite on each release.

```kotlin
@Deprecated(
    message = "Use fetchUser(id) instead.",
    replaceWith = ReplaceWith("fetchUser(id)"),
    level = DeprecationLevel.WARNING,
)
fun loadUser(id: String): String = fetchUser(id)

fun fetchUser(id: String): String = "user $id"

fun connect(host: String): String = connect(host, 443)

fun connect(host: String, port: Int): String = "$host:$port"

@RequiresOptIn(message = "This API is a preview. It can change without notice.")
@Retention(AnnotationRetention.BINARY)
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION)
annotation class PreviewApi

@PreviewApi
fun newFeature(): String = "preview"

@OptIn(PreviewApi::class)
fun useNewFeature(): String = newFeature()
```

## Sources and raw notes

Pages read on 2026-10-22:

- [Library authors' guidelines](https://kotlinlang.org/docs/api-guidelines-introduction.html) and its pages on [consistency](https://kotlinlang.org/docs/api-guidelines-consistency.html), [readability](https://kotlinlang.org/docs/api-guidelines-readability.html), [predictability](https://kotlinlang.org/docs/api-guidelines-predictability.html), [simplicity](https://kotlinlang.org/docs/api-guidelines-simplicity.html), [debuggability](https://kotlinlang.org/docs/api-guidelines-debuggability.html), [testability](https://kotlinlang.org/docs/api-guidelines-testability.html), [backward compatibility](https://kotlinlang.org/docs/api-guidelines-backward-compatibility.html) and [informative documentation](https://kotlinlang.org/docs/api-guidelines-informative-documentation.html).
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html): libraries, factory functions.
- [Type-safe builders](https://kotlinlang.org/docs/type-safe-builders.html) (`@DslMarker`), [Context parameters](https://kotlinlang.org/docs/context-parameters.html), [What's new in Kotlin 2.4](https://kotlinlang.org/docs/whatsnew24.html) (context parameters stable, `@IntroducedAt`), [What's new in Kotlin 2.3](https://kotlinlang.org/docs/whatsnew23.html) (`kotlin.time.Clock` stable).
- [What's new in Kotlin 1.4](https://kotlinlang.org/docs/whatsnew14.html): explicit API mode.
- [Binary compatibility validation in the Kotlin Gradle plugin](https://kotlinlang.org/docs/gradle-binary-compatibility-validation.html), [Opt-in requirements](https://kotlinlang.org/docs/opt-in-requirements.html).
- [Calling Kotlin from Java](https://kotlinlang.org/docs/java-to-kotlin-interop.html) and [Exception and error handling](https://kotlinlang.org/docs/exceptions.html): `@JvmStatic`, `@JvmField`, `@JvmOverloads`, `@JvmName`, `@Throws`.
- Code examples in this note were compiled with Kotlin 2.4.21 and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)) on 2026-10-22.
