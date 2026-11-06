# Modern Kotlin by Release

## Summary

This cheat sheet lists, release by release, the language and library features that replace older idioms. New code uses the modern form. The latest stable release is Kotlin 2.4.21 (2026-10-08), in the 2.4 line that started on 2026-06-03. Refresh this note after each language release, about every six months.

## Rules

### How to use this list

- A language feature needs a compiler that has it and a `languageVersion` that allows it. A library API needs an `apiVersion` that allows it. Applications keep the defaults of the compiler; libraries set both on purpose ([API design](07-api-and-class-design.md#libraries)).
- Use only **Stable** features in production code. Kotlin describes Experimental as "try it only in toy projects", Alpha as a feature under validation, Beta as usable with the best effort to ease migration, and Stable as usable "even in most conservative scenarios". Items below marked experimental, preview or beta are listed so that you recognise them, not so that you adopt them.
- Do not rewrite untouched code just to use these features ([principles](01-principles-and-sources.md#applying-the-notes)).
- Dates come from the release history table. The What's new page of 2.4 shows 2026-07-14, which the table gives as the date of 2.4.10; the table says 2.4.0 was released on 2026-06-03.

```kotlin
import kotlin.time.Clock
import kotlin.time.Instant
import kotlin.uuid.Uuid

enum class Level { LOW, HIGH }

sealed interface Event {
    data class Created(val id: Uuid, val at: Instant) : Event
    data object Cleared : Event
}

fun describe(event: Event): String = when (event) {
    is Event.Created if event.at < Clock.System.now() -> "created ${event.id}"
    is Event.Created -> "scheduled ${event.id}"
    Event.Cleared -> "cleared"
}

fun levelNames(): List<String> = Level.entries.map { it.name }

fun <T> elvisLike(x: T, y: T & Any): T & Any = x ?: y

fun sumUntilNegative(rows: List<List<Int>>): Int {
    var sum = 0
    for (row in rows) {
        row.forEach { value ->
            if (value < 0) break
            sum += value
        }
    }
    return sum
}

val sampleEvent = Event.Created(Uuid.random(), Clock.System.now())
val sampleRows = listOf(listOf(1, 2), listOf(3, -1, 4), listOf(5))
```

### Kotlin 2.4 (2026-06-03; 2.4.20 on 2026-09-07; 2.4.21 on 2026-10-08)

- **Context parameters** are stable, except explicit context arguments and callable references. `context(logger: Logger) fun process()` replaces the experimental context receivers.
- **Explicit backing fields** are stable. `val items: List<String>` with `field = mutableListOf()` replaces the pair of a private `_items` property and a public getter.
- **Annotation use-site targets:** the `@all` meta-target for properties and the new defaulting rules are stable.
- **`kotlin.uuid.Uuid`** is stable in the common standard library. The standard library also gains checks for sorted order and conversions from unsigned integers to `BigInteger` on the JVM.
- A deprecation warning is no longer reported on the last segment of an `import`. Java 26 is supported, and annotations in Kotlin metadata are enabled by default.
- **Experimental, not for production:** explicit context arguments, collection literals (`[1, 2, 3]`), improved compile-time constants, improved unused-result checks for higher-order functions, `@IntroducedAt` for version-based overloads, and map fallback functions. Kotlin 2.4.20 adds more experimental standard library items (stack trace recovery for coroutines, equality and uniqueness checks for collections, new `kotlin.test` overloads) and nothing that needs adopting.

### Kotlin 2.3 (2025-12-16; 2.3.20 on 2026-03-16)

- **Nested type aliases** are stable, and so are **data-flow-based exhaustiveness checks** for `when`: after an early return or a prior check the compiler no longer wants a redundant `else`.
- A `return` statement in an expression body is allowed by default when the return type is written explicitly.
- **`kotlin.time.Clock` and `kotlin.time.Instant`** are stable in the standard library. Use them in common code and inject a `Clock`.
- Experimental: the unused return value checker, explicit backing fields (stable in 2.4) and changes to context-sensitive resolution.
- 2.3.20 changes overload resolution for context parameters: calls that differ only by context parameters can now be ambiguous.

### Kotlin 2.2 (2025-06-23; 2.2.20 on 2025-09-10)

- **Guard conditions in `when`** (`is Type if condition ->`), **non-local `break` and `continue`** in lambdas passed to inline functions, and **multi-dollar string interpolation** (`$$"..."`) are stable.
- `Base64` and the `HexFormat` API are stable in the standard library.
- Preview in 2.2: context parameters, context-sensitive resolution (omitting the enum or sealed type name where the expected type is known) and annotation use-site target features. Nested type aliases were in beta.
- 2.2.20: `return` in expression bodies, data-flow-based exhaustiveness and reified types in `catch` clauses of inline functions (all experimental at that time) and improved contracts.

### Kotlin 2.1 (2024-11-27; 2.1.20 on 2025-03-20)

- Guard conditions, non-local `break` and `continue` and multi-dollar interpolation arrive as previews. `@SubclassOptInRequired` lets an API require an opt-in to extend it.
- Nullability mismatches against JSpecify annotations are reported as errors (strict level) by default.
- The compiler accepts `when` expressions over type parameters with sealed upper bounds without an `else`.
- The `extraWarnings` compiler option turns on additional declaration, expression and type checks.
- 2.1.20 introduces, as experiments, common atomic types and `kotlin.time.Clock` and `Instant`.

### Kotlin 2.0 (2024-05-21; 2.0.20 on 2024-08-22)

- The **K2 compiler** is stable, with more smart casts. A new Compose compiler Gradle plugin is released with Kotlin, and strong skipping is on by default from 2.0.20.
- `enumEntries<T>()` replaces `enumValues<T>()`, and the `AutoCloseable` interface is stable.
- 2.0.20 warns when a `data class` with a non-public constructor exposes a public `copy()`; fix it with `@ConsistentCopyVisibility` ([types](06-null-safety-and-types.md#data-classes)). It also begins the replacement of context receivers by context parameters.

### Kotlin 1.9 (2023-07-06; 1.9.20 on 2023-11-01)

- `Enum.entries` replaces `values()`. **`data object`** is stable. The **`..<` operator** gives an end-exclusive range, so write `0..<n` and not `0..n - 1`.
- The time measurement API is stable (the `Duration` part has been since 1.6) and replaces `measureTimeMillis` and `measureNanoTime`. `@Volatile` is stable in common code.

### Kotlin 1.8 (2022-12-28; 1.8.20 on 2023-04-03)

- Nothing to adopt. 1.8.20 previews `entries`, data objects, `AutoCloseable` and `Base64`.

### Kotlin 1.7 (2022-06-09; 1.7.20 on 2022-09-29)

- Builder inference, opt-in requirements (`@RequiresOptIn` and `@OptIn`) and **definitely non-nullable types** (`T & Any`) are stable. The underscore can stand for a type argument that the compiler infers.

### Kotlin 1.6 (2021-11-16; 1.6.20 on 2022-04-04)

- A non-exhaustive `when` statement over an enum, sealed or `Boolean` subject is reported (as a warning in 1.6, to become an error). Stable: `buildList`, `buildSet` and `buildMap`, `typeOf()`, the `Duration` API, suspending functions as supertypes and instantiation of annotation classes.
- Kover, the code coverage tool for Kotlin, is introduced.

### Kotlin 1.5 (2021-05-05; 1.5.20 on 2021-06-24)

- **`@JvmInline value class`** replaces the `inline class` modifier, which is deprecated. **Sealed interfaces** and package-wide sealed hierarchies arrive.
- Unsigned integer types and the `Path` API are stable. `lowercase()` and `uppercase()` replace the locale-sensitive `toLowerCase()` and `toUpperCase()`. JVM records are supported, and the default JVM target is 1.8.

### Kotlin 1.4 (2020-08-17; 1.4.20 on 2020-11-23)

- `fun interface` (SAM conversions for Kotlin interfaces), trailing commas, mixing named and positional arguments, explicit API mode and unqualified `break` and `continue` inside `when` in a loop.
- The new type inference and the JVM IR backend arrive. The Gradle plugin adds the standard library dependency by default.

### Upgrade checklist

1. Read the What's new page of the target release and its compatibility notes for changed defaults and removed options.
2. Check the new Kotlin version against the supported Gradle and AGP ranges ([tooling](02-project-setup-and-tooling.md#versions-and-compatibility)), then change it in the version catalog.
3. Build with warnings visible. New releases add warnings; fix them in their own commit.
4. Update tools that embed the Kotlin compiler (ktlint, detekt, KSP processors) to versions that support the new release before you raise the Kotlin version.
5. Use the IDE's migration tools for a new language release, and keep the changes mechanical and separate from behaviour changes.
6. Update this note.

## Sources and raw notes

Release notes read on 2026-10-22: [Kotlin 1.4](https://kotlinlang.org/docs/whatsnew14.html), [1.5](https://kotlinlang.org/docs/whatsnew15.html), [1.6](https://kotlinlang.org/docs/whatsnew16.html), [1.7](https://kotlinlang.org/docs/whatsnew17.html), [1.8](https://kotlinlang.org/docs/whatsnew18.html), [1.8.20](https://kotlinlang.org/docs/whatsnew1820.html), [1.9](https://kotlinlang.org/docs/whatsnew19.html), [1.9.20](https://kotlinlang.org/docs/whatsnew1920.html), [2.0](https://kotlinlang.org/docs/whatsnew20.html), [2.0.20](https://kotlinlang.org/docs/whatsnew2020.html), [2.1](https://kotlinlang.org/docs/whatsnew21.html), [2.1.20](https://kotlinlang.org/docs/whatsnew2120.html), [2.2](https://kotlinlang.org/docs/whatsnew22.html), [2.2.20](https://kotlinlang.org/docs/whatsnew2220.html), [2.3](https://kotlinlang.org/docs/whatsnew23.html), [2.3.20](https://kotlinlang.org/docs/whatsnew2320.html), [2.4](https://kotlinlang.org/docs/whatsnew24.html) and [2.4.20](https://kotlinlang.org/docs/whatsnew2420.html). Release dates come from the [release history](https://kotlinlang.org/docs/releases.html). The meaning of the stability levels comes from [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html), and the status of language features from [Kotlin language features and proposals](https://kotlinlang.org/docs/kotlin-language-features-and-proposals.html). Other pages used: [Properties](https://kotlinlang.org/docs/properties.html) (explicit backing fields), [Context parameters](https://kotlinlang.org/docs/context-parameters.html), [Conditions and loops](https://kotlinlang.org/docs/control-flow.html) (guard conditions) and [Android stability of Compose](https://developer.android.com/develop/ui/compose/performance/stability) (strong skipping).

The example at the top was compiled with Kotlin 2.4.21 on 2026-10-22 and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)). The 2.0.20 `copy()` warning and the explicit backing field syntax were also checked by compiling and running samples with Kotlin 2.4.21.
