# Kotlin Naming, Comments and Style

## Summary

Kotlin code follows the JetBrains coding conventions. Android modules also follow the Android Kotlin style guide, which is mostly a stricter version of the same rules. A formatter enforces layout, so reviews discuss design and not whitespace. The few places where the two guides disagree are settled in the last table of this note.

## Rules

### Formatting

- Let the formatter do it. ktlint enforces most of this section in CI ([tooling](02-project-setup-and-tooling.md#formatting-and-static-checks)); the IDE reformats on save.
- Indent with four spaces, never tabs. Save files as UTF-8. Omit semicolons.
- Put the opening brace at the end of the line and the closing brace on its own line. Kotlin ends a statement at a line break, so other brace styles can change what the code means.
- Limit lines to 100 columns. The Android guide sets this number; the JetBrains guide names none. `package` and `import` lines, long URLs in KDoc and shell commands in comments are exempt.
- Order a file like this, with one blank line between the parts: licence header (optional), `@file:` annotations, `package`, imports, declarations. A licence header is a `/* ... */` block, not KDoc and not `//` lines.
- Never use wildcard imports. The Android guide forbids them, and ktlint (`no-wildcard-imports`) and detekt (`WildcardImport`) report them. Do not sort imports by hand; the formatter owns the order.
- Break a parameter list that does not fit on one line so that each parameter has its own line, indented by four spaces, with the closing parenthesis on its own line. End such lists with a trailing comma. A list that fits within the column limit stays on one line, and ktlint joins it.
- Break a long chain before the `.` or `?.` and indent it once. Break after an operator or infix function name.
- Break after the `=` of a long property initialiser or expression body and indent once.
- Put `else`, `catch` and `finally` on the same line as the preceding closing brace.
- Put modifiers in this order: visibility, `expect`/`actual`, `final`/`open`/`abstract`/`sealed`/`const`, `external`, `override`, `lateinit`, `tailrec`, `vararg`, `suspend`, `inner`, `enum`/`annotation`/`fun`, `companion`, `inline`/`value`, `infix`, `operator`, `data`. Put annotations before all modifiers.
- Put annotations on separate lines before the declaration. Annotations without arguments may share one line (`@JvmField @Volatile`), and a single annotation without arguments may stay on the declaration's line: `@Test fun foo() { }`.
- Put spaces around binary operators and after commas and colons. Put a space before a colon only where it introduces a supertype, a constructor delegation (`: this(x)`) or a `where` bound. Put no space around `..`, `.`, `?.` or `::`. Do not align code horizontally, because renaming an identifier must not change the formatting of other lines.

```kotlin
class Point(val x: Int, val y: Int)

class Customer(
    val identifier: String,
    val displayName: String,
    val emailAddress: String?,
    val preferredLanguage: String = "en",
    val marketingConsent: Boolean = false,
)

fun describe(
    customer: Customer,
    separator: String = ", ",
    includeEmail: Boolean = false,
    fallbackName: String = "unknown",
): String {
    val name = customer.displayName.ifBlank { fallbackName }
    val email = customer.emailAddress.takeIf { includeEmail }
    return listOfNotNull(name, email).joinToString(separator)
}

val initials = listOf(Customer("c-1", "Ada Lovelace", null))
    .map { it.displayName.first() }
    .joinToString("")
```

### Braces, lambdas and arguments

- Use curly braces for every `if`, `for`, `do` and `while` body and every `when` branch, even when the body is one statement. The exception (Android guide) is an `if` expression with at most one `else`, or a `when` branch, that fits on one line: `if (list.isEmpty()) return`, `0 -> return`. The JetBrains guide agrees: short `when` branches stay on the condition's line without braces.
- Use braces whenever an `if` or `when` condition spans several lines. Put the closing parenthesis of the condition on its own line, followed by the opening brace: `) {`.
- Put spaces around the braces and the arrow of a lambda. Pass a single lambda outside the parentheses. Name lambda parameters that are nested or long; use `it` only in short lambdas that are not nested.
- Use named arguments when a call takes several parameters of the same primitive type or a `Boolean`, unless the meaning is obvious from the context.
- Put parentheses around each boolean expression that you combine with `&&` and `||` in a `when` guard: `is Status.Ok if (status.info.isEmpty() || status.info.id == null) -> ...`.
- Test a nullable `Boolean` with `if (value == true)` or `if (value == false)`.

```kotlin
fun drawSquare(x: Int, y: Int, width: Int, height: Int, fill: Boolean): String =
    "square at $x,$y size ${width}x$height filled=$fill"

val square = drawSquare(x = 10, y = 10, width = 100, height = 100, fill = true)
```

### Omit what the language already says

Leave out any construct that the IDE marks as redundant, even "for clarity".

- Omit `: Unit` return types, semicolons and `public` (except in libraries, see [API design](07-api-and-class-design.md#libraries)).
- Use an expression body for a function that is one expression, and omit its return type when it is clear from the body. In a library, keep the explicit type on every public declaration.
- Write `"$name has ${children.size} children"`: no braces around a simple name, braces around anything longer. Use `$$"""..."""` (multi-dollar interpolation, stable since Kotlin 2.2) when a text is full of literal `$`, such as a JSON schema.
- Use `"""` blocks instead of `\n` escapes, with `trimIndent()` when no indentation is needed in the result and `trimMargin()` when it is.

### Names

| What | Style | Example |
| --- | --- | --- |
| Package | all lower case, no underscores, words joined | `com.example.deepspace` |
| Class, interface, object, type alias | PascalCase; a noun or noun phrase | `PaymentProcessor`, `EmptyProcessor` |
| Function, property, local, parameter | camelCase; functions are verbs | `readPersons`, `declarationCount` |
| Constant | `UPPER_SNAKE_CASE` | `const val MAX_COUNT = 8` |
| Enum entry | `UPPER_SNAKE_CASE` or PascalCase; one style per enum | `RED`, `NOT_FOUND` |
| Backing property, where an explicit backing field does not fit | the real name with a leading underscore | `_elementList` |
| Type parameter | one capital letter with an optional digit, or a class-style name ending in `T` | `T`, `T2`, `RequestT` |
| `@Composable` function that returns `Unit` | PascalCase noun, like a type | `NameTag` |
| Factory function | the type's name, only when it has no special semantics; otherwise a distinct name | `Point.fromPolar(...)` |

- **Constants** are `const val` properties, or `val` properties of an `object` or at top level that have no custom getter and hold deeply immutable data (a read-only list of strings, for example). A scalar constant uses `const`. A `val` that holds an object with behaviour or mutable data is not a constant, so it uses camelCase: `val logger = ...`.
- **Method names tell what they do.** The name says whether the method changes the object or returns a new one: `sort` sorts in place, `sorted` returns a sorted copy.
- **Avoid empty words** such as `Manager`, `Wrapper` and `Util`. The name must say what the thing is for.
- **Backing fields.** Prefer an explicit backing field (`val items: List<String>` with `field = mutableListOf()`, stable since Kotlin 2.4) to a second, underscored property ([types](06-null-safety-and-types.md#classes-inheritance-and-visibility)). Use the underscored backing property when the property has a custom getter, is not a `val`, is `open` or delegated, or when the project is on an older Kotlin.
- **Do not decorate names.** No `mName`, `s_name`, `kName` or `name_`; the leading underscore of a backing property is the only exception.
- **Acronyms.** Both guides agree that an acronym longer than two letters is written as a word: `XmlFormatter`, `HttpInputStream`. For two-letter acronyms JetBrains writes both letters in capitals (`IOStream`) and the Android guide treats them as words. This set follows JetBrains for acronyms such as `IO` and treats `Id` as an ordinary word, as the Android guide's own example does: `userId`, `OrderId`.

```kotlin
const val MAX_RETRIES = 3
val SUPPORTED_LOCALES = listOf("en", "id", "ja")
val activeSessions = mutableSetOf<String>()

class Basket {
    private val _items = mutableListOf<String>()
    val items: List<String>
        get() = _items

    fun add(item: String) {
        _items += item
    }
}

enum class Level { LOW, NOT_SET, HIGH }

class XmlFormatter
class IOStream
class OrderId(val value: String)
```

### Test names

- Name a test class after the class it tests plus `Test`: `HashTest`, `HashIntegrationTest`.
- Backticked names with spaces (`` fun `rejects an empty cart`() ``) are allowed in tests and only in tests. They need API 30 or later when the test runs on the Android runtime, so use camelCase or underscores (`pop_emptyStack`) in instrumented tests below that level. JVM unit tests can use backticks.

### Comments and KDoc

- Write KDoc (`/** ... */`) for every public declaration of a library, except an override that adds nothing. In an application module, document what the signature does not show: units, nullability, the dispatcher a `suspend` function uses, and the errors it can throw. A KDoc that only repeats the name adds noise.
- The first paragraph is the summary. Write it as a noun or verb phrase, capitalised and ending with a full stop, not as a sentence that opens with "A Foo is..." or "This method returns...".
- Put `/**` on its own line for a multi-line comment. A one-line comment may use `/** Short summary. */`.
- Prefer prose with links to `@param` and `@return`. Use a tag only when the text is too long for the flow. When you use tags, keep this order and never leave one empty: `@constructor`, `@receiver`, `@param`, `@property`, `@return`, `@throws`, `@see`.
- Link to another declaration with square brackets: `[number]`, `[kotlin.reflect.KClass.properties]`. KDoc uses Markdown for the rest. Embed an example with `@sample`.
- Mark deprecations with the `@Deprecated` annotation. KDoc has no `@deprecated` tag.
- Mark unfinished code with `TODO("reason")`. It throws `NotImplementedError`, returns `Nothing` and shows in the IDE's TODO window.

```kotlin
/**
 * Returns the absolute value of the given [number].
 *
 * The result is negative only for [Int.MIN_VALUE], which has no positive counterpart.
 */
fun abs(number: Int): Int = if (number < 0) -number else number
```

### Where the guides disagree

| Topic | JetBrains guide | Android guide | Rule here |
| --- | --- | --- | --- |
| Line length | No limit named | 100 columns | 100 columns |
| Two-letter acronyms | `IOStream` | Treated as words | JetBrains for acronyms, `Id` as a word |
| Spaces in function names | Allowed in tests | Not allowed ("not supported on every platform") | Tests only; API 30+ on the Android runtime |
| Wildcard imports | Not covered | Not allowed | Not allowed |
| `@param` and `@return` | Avoid unless long | Tags never empty, fixed order | Prose first; fixed order when used |
| Public KDoc | Libraries: all public members | Every public type and member, with exceptions | Libraries: all; applications: what the signature hides |

## Sources and raw notes

Pages read on 2026-10-22:

- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html): naming, formatting, modifier order, named arguments, strings, documentation comments, libraries.
- [Android Kotlin style guide](https://developer.android.com/kotlin/style-guide) (last updated 2026-09-22): column limit, file structure, imports, braces, naming, KDoc usage.
- [KDoc syntax](https://kotlinlang.org/docs/kotlin-doc.html): tags, links, `@Deprecated`.
- [Idioms](https://kotlinlang.org/docs/idioms.html): `TODO()`.
- ktlint documentation: [code styles](https://ktlint.github.io/ktlint/latest/rules/code-styles/) and [standard rules](https://ktlint.github.io/ktlint/latest/rules/standard/) (`max_line_length` and trailing-comma defaults per style, `no-wildcard-imports`).
- detekt rules: [style](https://detekt.dev/docs/rules/style/) (`WildcardImport`).
- Code examples in this note were compiled with Kotlin 2.4.21 and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)) on 2026-10-22.
