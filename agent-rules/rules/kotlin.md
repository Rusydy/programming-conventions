---
paths:
  - "**/*.kt"
  - "*.kt"
  - "**/*.kts"
  - "*.kts"
  - "**/libs.versions.toml"
  - "libs.versions.toml"
---
# Kotlin conventions (every project)

Write idiomatic, readable Kotlin. Follow the language's and the platform's conventions instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `kotlin-conventions` folder of the programming-conventions repository, which hold the reasons, sources and compiled examples. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-11-06; update it by hand whenever a note changes.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (formatter or Kotlin upgrades, dependency bumps) in separate commits.
- If the repository documents its own Kotlin conventions, follow them first. Generated code (KSP and kapt output, generated clients) is exempt.
- Do not raise the Kotlin, Gradle or AGP version unasked, and use only features the project's `languageVersion` allows. The latest stable release is Kotlin 2.4.21 (2026-10-08). Use Stable features only; Experimental means "toy projects".
- Prefer the standard library and the official kotlinx libraries. Add a dependency only when it removes real complexity, and say why.
- Before you report Kotlin changes as done, run `ktlint` and `./gradlew check` (or the project's own commands) and fix new warnings.
- When sources disagree, the order is: language specification and compiler, this file and the notes, Kotlin team guidance, platform guidance (Android, Compose, Multiplatform, Spring), tool defaults.

## Setup and layout

- Gradle Kotlin DSL, the `plugins {}` block, versions only in `gradle/libs.versions.toml`, repositories in `settings.gradle.kts`, flags in the root `gradle.properties`, no manual `kotlin-stdlib`. Shared build logic goes in convention plugins in an included `build-logic` build, not `buildSrc`. Split modules along natural boundaries early; no sources in the root project.
- Pin the JDK with `kotlin { jvmToolchain(<LTS version>) }`. Check the Kotlin Gradle plugin against the Gradle and AGP ranges before an upgrade (note 02).
- CI treats warnings as errors (`allWarningsAsErrors`, plus `extraWarnings`). Module-wide opt-ins use `optIn`. Use typed `compilerOptions` properties, not `freeCompilerArgs`. Applications keep the default `languageVersion` and `apiVersion`; libraries set both to the same value and use `explicitApi()`.
- AGP 9 has built-in Kotlin: remove `org.jetbrains.kotlin.android`, move `android.kotlinOptions {}` to `kotlin.compilerOptions {}`. Use KSP, not kapt, wherever the processor supports it.
- ktlint 1.8.0 (not the 2.0 alpha) with a committed `.editorconfig`: `ktlint_code_style = intellij_idea`, `max_line_length = 100`, wildcard imports disabled (the exact file is in note 02), and `kotlin.code.style=official` in `gradle.properties`. Keep generated code out of the lint run. detekt is optional; its stable 1.23.8 targets Kotlin 2.0.21.
- Sources live in `src/<source set>/kotlin`, Java in `src/main/java`. File name: the class name for a single class or interface, else PascalCase for the contents (`ProcessDeclarations.kt`); no `Util`. Related declarations may share a file of a few hundred lines at most. An extension that all clients need goes in the class's file; one client's extension goes next to that client.
- Class order: properties and `init` blocks, secondary constructors, methods, companion object. Keep related members together, not alphabetical.
- Packages: lower case, no underscores, words joined (no camel case), grouped by feature or responsibility; no `util`, `common` or `helpers`. The Gradle module is the `internal` boundary.
- Multiplatform: the default hierarchy template; platform access through interfaces in `commonMain`; `expect`/`actual` only for small things (classes are Beta); platform file suffix (`Platform.jvm.kt`).

## Naming and style

- Four spaces, UTF-8, no semicolons, K&R braces, 100 columns, no wildcard imports; the formatter owns import order. Wrap only what does not fit: one parameter per line, a trailing comma, the closing parenthesis on its own line. Break chains before `.` or `?.`, and long initialisers after `=`.
- Braces on every `if`, `for`, `do`, `while` and `when` branch, except a one-line `if` or `when` branch. Annotations go before modifiers; the modifier order is in note 04.
- Names: PascalCase types; camelCase functions, properties and locals; `UPPER_SNAKE_CASE` for `const val` and for deeply immutable `val`s at top level or in an `object` with no custom getter. Acronyms longer than two letters are words (`XmlFormatter`), two-letter ones are capitals (`IOStream`), but `Id` is a word (`userId`). No `mName` or `name_` decoration, no `Manager`, `Wrapper` or `Util`. `sort` mutates, `sorted` copies. A test class is named after the class plus `Test` (`HashTest`); backticked test names only in JVM tests.
- Omit what the language already says: `: Unit`, `public` (except in libraries), obvious types (never on a library's public API). One-expression functions get an expression body. In string templates use braces only around expressions; `trimIndent()` and `trimMargin()` for raw strings.
- Named arguments for several parameters of the same primitive type and for every `Boolean`, unless obvious. A single lambda goes outside the parentheses; `it` only in short, non-nested lambdas. Parenthesise combined conditions in `when` guards.
- KDoc: a summary fragment first; prose with links in square brackets before `@param` and `@return`. `@Deprecated`, not `@deprecated`. Every public library member has KDoc; application code documents what the signature hides. `TODO("reason")` for unfinished code.

## Idioms

- `val` unless it changes. `List`, `Set` and `Map` with `listOf` (not `arrayListOf`); `buildList`, `buildSet` and `buildMap` for local mutation; `toList()` when you hand out a collection you keep changing. Immutable `data class` and `copy()`.
- `if`, `when` and `try` as expressions; `if` for two branches, `when` for three or more; no `else` on a `when` over a sealed type or an enum; guards `is Type if condition ->` (2.2+). Leave early with `?: return`, `?: throw` or `?: error("reason")`.
- Default values instead of overloads. A property instead of a no-argument function only if it cannot throw, is cheap and stable. Keep extensions private or near their client; they resolve statically and members win. A `typealias` is not a new type: use a value class.
- `filter` and `map` instead of loops; prefer a plain `for` to `forEach` (unless the receiver is nullable or it ends a chain). `asSequence()` only for big or unbounded pipelines. Use `in`, `..<`, `firstOrNull()`, `toIntOrNull()`, `orEmpty()`, `isNullOrEmpty()` and `Enum.entries`.
- `object` and `data object`; `by lazy`; `by` delegation instead of inheritance; `use { }` for resources; `lateinit` only for framework or test setup.
- Scope functions by intent: `let` (a non-null value, or naming an expression), `apply` (configure), `run` (configure and compute), `also` (side effect), `with` (group calls). Never nest them.

## Types and null safety

- Non-null unless absence is a real state. Avoid `!!`: use `requireNotNull`, `checkNotNull` or `?: error("reason")`. `as?` with `?:`; `filterNotNull()` and `mapNotNull`. A `var` property is never smart cast: copy it into a local `val`.
- Give public declarations, and properties initialised from Java, an explicit Kotlin type (platform types). JSpecify is strict from Kotlin 2.1; JSR-305 is checked at `warn` by default.
- A closed set of cases with data: `sealed interface` or `sealed class` with `data class` and `data object` subtypes. Single constants: `enum`; use `entries`, never `values()`.
- `data class`: `val` properties; with a private or internal constructor add `@ConsistentCopyVisibility`, otherwise `copy()` bypasses the validation; not in public library APIs.
- `@JvmInline value class` for identifiers and units, validated in `init`; never a bare `Long` or `String` id; `kotlin.time.Duration` for time spans.
- Classes are final by default; `open` only by design. `fun interface` for single-method callbacks. Expose the narrowest type. For a `val` that is mutable inside and read-only outside use an explicit backing field (stable in 2.4): `val items: List<String>` with `field = mutableListOf()`. Use a leading-underscore backing property only where that does not fit, or before 2.4.
- Variance with `out` and `in`. `inline` with `reified` only when you need the type at runtime; do not inline large functions.

## API and class design

- Parameters from general to specific; one name per concept. No `Boolean` flag parameters in an API (two functions or an enum). Classes for data and state; top-level or extension functions when all state is passed in. Accept and return read-only collections; avoid arrays.
- Constructor injection. Inject the `Clock` and the dispatchers. No mutable global state or mutable `object` singletons.
- Builders take a lambda with receiver last, with required values as parameters and `@DslMarker` for nested DSLs.
- Context parameters (stable in 2.4) only for shared, rarely changing dependencies such as a logger. Collection literals, explicit context arguments and `@IntroducedAt` are experimental: do not use them.
- `@JvmStatic`, `@JvmField`, `@JvmOverloads`, `@JvmName` and `@Throws` only when Java or Swift calls the code.
- Libraries: `explicitApi()`; KDoc on every public member; no third-party types or data classes in the public API; keep old signatures (add an overload, not a parameter, even with a default); explicit return types; deprecate in steps (warning, error, hidden) with `ReplaceWith` and remove only in a major release; check ABI compatibility (`abiValidation {}` with `checkKotlinAbi`, or `apiCheck`).

## Errors

- Missing value: return `null`. Bad argument: `require`. Wrong state: `check` or `checkNotNull`. Impossible branch: `error`. A failure the caller must branch on: a `sealed` result. Other failures: exceptions. One mechanism per module; the non-throwing twin gets the suffix `Catching`. Do not add a library such as Arrow for `Either`.
- Messages name the offending input and never a secret. Throw a new exception object each time (never an `object`). Catch the narrowest type, never `Throwable`; keep the `cause` when you wrap.
- `runCatching` catches every `Throwable`, `CancellationException` included, so use it only around non-suspending calls. In suspending code rethrow `CancellationException` before you catch `Exception`. Suspending cleanup goes in `withContext(NonCancellable)` inside `finally`, never on `launch` or `async`.

## Coroutines and Flow

- Launch only in a `CoroutineScope`. Inject dispatchers; never write `Dispatchers.IO`, `Default` or `Main` inside a class. No `GlobalScope`: inject an external scope. Use `coroutineScope` or `supervisorScope`, and `async` inside `coroutineScope` for parallel work. `runBlocking` only in `main` and in tests. `delay`, never `Thread.sleep`.
- `suspend` functions are main-safe: the class that blocks uses `withContext(dispatcher)`. A function that returns `Flow` is not `suspend`. One-shot calls are `suspend`; streams are `Flow`.
- Cancellation is cooperative: `ensureActive()` in long loops. Never swallow `CancellationException`.
- `flow { }` is cold: share it with `stateIn` or `shareIn`, change context with `flowOn`, never `emit` from another context (use `channelFlow` or `callbackFlow`, and end `callbackFlow` with `awaitClose`), handle upstream errors with `catch { }`.
- Expose a read-only `StateFlow` and keep the `MutableStateFlow` private (explicit backing field on 2.4+). Build UI state with `stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), initialValue)`. Collect with `collectAsStateWithLifecycle()`; it also works in common code, through `lifecycle-runtime-compose`.
- Shared mutable state: thread-safe structures, thread confinement or a `Mutex` with `withLock { }`.

## Testing

- `kotlin("test")` on the JUnit Platform in `src/test` (`commonTest` in Multiplatform); `kotlinx-coroutines-test` and Turbine as test dependencies only.
- Fakes in the test source set before mocks; MockK (`every`, `coEvery`, `verify`) only to check an interaction.
- `runTest { }`, returned from the test function; inject `StandardTestDispatcher(testScheduler)`; `Dispatchers.setMain` and `resetMain` for `Main` and `viewModelScope`. Opt in once to `ExperimentalCoroutinesApi` for the test compilation. Test flows with Turbine's `flow.test { }` and `awaitItem()`.

## Platforms

- Android: a data layer with repositories, a UI layer, a domain layer only in big apps; unidirectional data flow. One ViewModel per screen, with no `Context` or `Activity`, not `AndroidViewModel`, exposing one `uiState` property of type `StateFlow<ScreenUiState>`; no events from the ViewModel to the UI. Constructor injection (Hilt for non-trivial apps).
- Compose: composables that return `Unit` are PascalCase nouns, value-returning ones camelCase, remembered factories get the `remember` prefix. `modifier: Modifier = Modifier` is the first optional parameter and goes to the root node. Prefer stateless composables with hoisted state; `rememberSaveable` across configuration changes; never a non-observable mutable object as state.
- Compose performance: `remember` with keys for expensive work; unique, saveable lazy list keys (never an index or `hashCode()`); `derivedStateOf`; never write state during composition. Strong skipping (Kotlin 2.0.20+) compares unstable parameters by `===`: pass new instances and prefer immutable data.
- Multiplatform: shared logic in `commonMain` on multiplatform libraries (kotlinx.coroutines, kotlinx.serialization with `@Serializable`, `kotlin.time`, `kotlin.uuid`); tests in `commonTest`, run on every target. Inject platform dependencies as interfaces, with the project's DI framework or plain constructor injection.
- Spring: Kotlin 2.2+, `kotlin("plugin.spring")` and `kotlin("plugin.jpa")`, `jackson-module-kotlin`; `suspend` and `Flow` in controllers.

## Modern Kotlin

- Prefer the stable modern forms: `fun interface` and trailing commas (1.4), `@JvmInline value class` and sealed interfaces (1.5), `buildList` (1.6), `T & Any` (1.7), `entries`, `data object` and `..<` (1.9), K2 (2.0), guards, non-local `break` and `continue` and `$$` strings (2.2), nested type aliases, data-flow exhaustiveness and `kotlin.time.Clock` (2.3), context parameters, explicit backing fields and `kotlin.uuid.Uuid` (2.4).
- Not for production code: collection literals, explicit context arguments, `@IntroducedAt`, the unused return value checker, context-sensitive resolution. Do not rewrite untouched code to use the stable forms.

## Notes index

Each file is in the `kotlin-conventions` folder of the programming-conventions repository.

- `01-principles-and-sources.md`: principles, precedence, applying the notes
- `02-project-setup-and-tooling.md`: Gradle, versions, compiler options, AGP 9, ktlint
- `03-project-layout-and-packages.md`: source roots, file names, modules, source sets
- `04-naming-comments-and-style.md`: formatting, names, KDoc, style guide conflicts
- `05-idiomatic-language-use.md`: immutability, expressions, collections, scope functions
- `06-null-safety-and-types.md`: nullability, sealed, data and value classes
- `07-api-and-class-design.md`: parameters, dependencies, DSLs, library rules
- `08-error-handling.md`: preconditions, exceptions, results, cancellation
- `09-coroutines-and-flow.md`: scopes, dispatchers, Flow, StateFlow
- `10-testing.md`: kotlin.test, fakes, runTest, Turbine
- `11-platform-practices.md`: Android and Compose, Multiplatform, Spring
- `12-modern-kotlin-by-release.md`: features per Kotlin release, 1.4 to 2.4
