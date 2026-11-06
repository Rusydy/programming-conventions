# Idiomatic Kotlin

## Summary

Prefer expressions to statements, immutable values to variables, the standard library to hand-written loops and helpers, and the type system to comments. This note lists the idioms that the Kotlin team recommends in its coding conventions, idioms and scope-function pages, and the choice that replaces each habit carried over from Java.

## Rules

### Immutability

- Declare every local variable and property as `val`. Use `var` only when the value really changes after initialisation.
- Declare collections with the read-only interfaces `Collection`, `List`, `Set` and `Map`, and create them with factory functions that return those types. `listOf("a", "b")` is correct; `arrayListOf("a", "b")` returns a mutable `ArrayList` for a value that is never changed.
- Build a collection that needs mutation in a limited scope with `buildList`, `buildSet` or `buildMap`. They return a read-only collection.
- A read-only type is a view, not a snapshot. If you keep changing a collection you also hand out, give the caller a copy with `toList()`, `toSet()` or `toMap()`.
- Model a plain value as a `data class` with `val` properties and change it with `copy()`.
- Prefer a small named class to `Pair` or `Triple` when the parts have a meaning. The Kotlin library guidelines call reusing `Pair` and `Triple` effective, but not a reason to skip a type that carries domain logic.

```kotlin
fun main() {
    val source = mutableListOf("a")
    val view: List<String> = source
    val snapshot: List<String> = source.toList()
    source.add("b")
    println(view) // [a, b]
    println(snapshot) // [a]
}

fun squares(limit: Int): List<Int> = buildList {
    for (n in 1..limit) add(n * n)
}
```

### Expressions, not statements

- Use `if`, `when` and `try` as expressions: `return if (x) foo() else bar()`. Use an expression body for a function that is one expression.
- Use `if` for two branches and `when` for three or more. Do not write `when (x) { null -> ...; else -> ... }`.
- Make a `when` over a `sealed` type or an `enum` exhaustive with no `else`. When someone adds a case, the compiler flags every `when` that misses it. An `else` branch hides that check.
- Use a guard (`is Type if condition ->`) to refine a branch. Guards are stable since Kotlin 2.2 and need a `when` with a subject; wrap combined conditions in parentheses.
- Leave a function early with `?: return` or `?: throw`. Use `?: run { ... }` when the fallback needs several statements.

```kotlin
sealed interface Payment {
    data class Card(val last4: String) : Payment
    data class Transfer(val bank: String, val verified: Boolean) : Payment
    data object Cash : Payment
}

fun label(payment: Payment): String = when (payment) {
    is Payment.Card -> "card ending ${payment.last4}"
    is Payment.Transfer if payment.verified -> "verified transfer from ${payment.bank}"
    is Payment.Transfer -> "unverified transfer"
    Payment.Cash -> "cash"
}

class Order(val id: String, val email: String?)

fun confirm(order: Order?): String {
    val target = order ?: return "no order"
    val email = target.email ?: error("order ${target.id} has no e-mail")
    return "sent to $email"
}
```

### Functions and properties

- Use default parameter values instead of overloads. Use named arguments for several parameters of the same primitive type and for `Boolean` parameters, unless the meaning is obvious from the context ([style](04-naming-comments-and-style.md#braces-lambdas-and-arguments)).
- Prefer a property to a no-argument function when the value does not throw, is cheap to compute (or cached on the first call) and is the same on every call while the object state is unchanged.
- Use extension functions liberally for code that works mainly on one object. Keep their visibility as small as makes sense: a local function, a member extension, or a `private` top-level function. Put an extension that every client of the class needs in the file of the class; put one for a single client next to that client. Do not create a file only to collect the extensions of a type.
- Remember that extensions are resolved statically, from the declared type of the receiver, and that a member function takes precedence over an extension with the same receiver type, name and compatible arguments.
- Declare a function `infix` only when it works on two objects that play a similar role (`and`, `to`, `zip`), and never when it mutates the receiver.
- Pass a lambda outside the parentheses when it is the last parameter. Avoid several labeled returns in one lambda, and never use a labeled return on its last statement.
- Give a function type or a generic type that you repeat a `typealias`. A `typealias` is only another name: it does not create a new type, so `UserId` and `OrderId` aliases for `String` can still be mixed up. Use a `value class` for that ([types](06-null-safety-and-types.md#value-classes)).
- Use string templates and `"""` blocks instead of concatenation and `\n` escapes ([style](04-naming-comments-and-style.md#omit-what-the-language-already-says)).

```kotlin
fun connect(
    host: String,
    port: Int = 443,
    timeoutSeconds: Int = 30,
    secure: Boolean = true,
): String = "${if (secure) "https" else "http"}://$host:$port (timeout ${timeoutSeconds}s)"

val quickUrl = connect("example.com", timeoutSeconds = 5)
val plainUrl = connect("example.com", port = 80, secure = false)

private fun String?.orDash(): String = this?.takeIf { it.isNotBlank() } ?: "-"

val Int.isLeapYear: Boolean
    get() = this % 4 == 0 && (this % 100 != 0 || this % 400 == 0)
```

### Collections and loops

- Prefer `filter`, `map`, `groupBy` and the other higher-order functions to hand-written loops. Prefer a plain `for` loop to `forEach`, unless the receiver is nullable or `forEach` ends a longer chain.
- When a chain of several operations on a large collection builds big intermediate lists, use `asSequence()`: a sequence handles each element through every step and builds no intermediate collections. For a small collection or a simple operation the laziness costs more than it saves, so compare both. A sequence is also the right tool for an unbounded source.
- Use `in` and `!in` for membership. Use `..<` for an end-exclusive range (`0..<n`), `step` and `downTo` for the rest.
- Use the `...OrNull` functions instead of catching exceptions or checking sizes: `firstOrNull()`, `getOrNull(i)`, `singleOrNull()`, `toIntOrNull()`.
- Replace `x ?: emptyList()` with `x.orEmpty()`, and `x == null || x.isEmpty()` with `x.isNullOrEmpty()`. detekt has a rule for each (`UseOrEmpty`, `UseIsNullOrEmpty`).
- Traverse a map with destructuring: `for ((key, value) in map)`.
- Use `entries` instead of `values()` on an enum (stable since Kotlin 1.9).

```kotlin
val firstEvenMultiple = generateSequence(1) { it + 1 }
    .map { it * 3 }
    .filter { it % 2 == 0 }
    .first() // 6, from an unbounded source

fun parseAge(raw: String): Int =
    raw.toIntOrNull()?.takeIf { it in 0..150 } ?: error("invalid age: $raw")

fun totals(prices: Map<String, Int>): List<String> = buildList {
    for ((name, price) in prices) add("$name=$price")
}
```

### Objects, delegation and resources

- Use `object` for a singleton and `data object` for a stateless case of a `sealed` hierarchy, so that it prints its name. Compare data objects with `==`, never with `===`.
- Put constants in an `object` or at the top level, and mark scalar ones `const`.
- Use `by lazy { ... }` for a property that is costly to compute. The default mode is synchronised. Pass `LazyThreadSafetyMode.PUBLICATION` or `NONE` only when you can name the reason.
- Use `by` class delegation to reuse an interface implementation. The Kotlin documentation calls delegation a good alternative to implementation inheritance and supports it with no boilerplate.
- Close resources with `use { }`, the counterpart of try-with-resources.
- Use `lateinit var` only when a framework or test setup assigns the value after construction. The property must be non-null and not a primitive, must not be in the primary constructor, and throws a clear exception when read too early. Otherwise initialise in the constructor or use a delegate (detekt `LateinitUsage` says the same).

```kotlin
import java.io.File

class Report(private val path: String) {
    val lines: List<String> by lazy { File(path).readLines() }
}

fun firstLine(path: String): String? = File(path).bufferedReader().use { it.readLine() }
```

### Scope functions

Pick the function by intent and by what the lambda returns. The usage areas overlap, so settle on one choice per intent and stay consistent in a project.

| Intent | Function | Context object | Result |
| --- | --- | --- | --- |
| Run a lambda on a non-null value, or name an expression in a local scope | `let` | `it` | lambda result |
| Configure an object | `apply` | `this` | the object |
| Configure an object and compute a result | `run` | `this` | lambda result |
| Add a side effect (logging, validation) | `also` | `it` | the object |
| Group calls on an object | `with(obj) { }` | `this` | lambda result |
| Run statements where an expression is required | `run { }` | none | lambda result |

- Do not overuse them, do not nest them, and be careful when you chain them: it is easy to lose track of `this` and `it`.
- Replace `a.let { print(it) }` with `print(a)`, and `config.apply { version = "1.2" }` with `config.version = "1.2"`. detekt has rules for both (`UnnecessaryLet`, `UnnecessaryApply`).

```kotlin
class Request {
    var url = ""
    var retries = 0
}

fun buildRequest(rawUrl: String?): Request? = rawUrl?.let { url ->
    Request()
        .apply {
            this.url = url
            retries = 3
        }
        .also { println("built request for ${it.url}") }
}
```

## Sources and raw notes

Pages read on 2026-10-22:

- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html): idiomatic use of language features (immutability, default values, type aliases, lambdas, named arguments, `if` versus `when`, loops, ranges, strings, functions versus properties, extension and infix functions, factory functions, scope functions).
- [Idioms](https://kotlinlang.org/docs/idioms.html): `when` with `is`, Elvis with `run`, `firstOrNull`, `use`, `data object`-style singletons, `apply` and `with`.
- [Scope functions](https://kotlinlang.org/docs/scope-functions.html): function selection table and the warning about overuse.
- [Sequences](https://kotlinlang.org/docs/sequences.html): eager versus lazy processing and its overhead.
- [Constructing collections](https://kotlinlang.org/docs/constructing-collections.html): `buildList`, `buildSet`, `buildMap`.
- [Conditions and loops](https://kotlinlang.org/docs/control-flow.html): exhaustive `when` and guard conditions; [What's new in Kotlin 2.2](https://kotlinlang.org/docs/whatsnew22.html): guards stable; [What's new in Kotlin 1.9](https://kotlinlang.org/docs/whatsnew19.html): `entries`, data objects and `..<` stable.
- [Delegated properties](https://kotlinlang.org/docs/delegated-properties.html) (`lazy`), [Properties](https://kotlinlang.org/docs/properties.html) (`lateinit`), [Delegation](https://kotlinlang.org/docs/delegation.html), [Extensions](https://kotlinlang.org/docs/extensions.html), [Type aliases](https://kotlinlang.org/docs/type-aliases.html), [Object declarations](https://kotlinlang.org/docs/object-declarations.html).
- [Library authors' guidelines: consistency and predictability](https://kotlinlang.org/docs/api-guidelines-consistency.html), [readability](https://kotlinlang.org/docs/api-guidelines-readability.html) and [predictability](https://kotlinlang.org/docs/api-guidelines-predictability.html): sealed types and exhaustive `when`, read-only collections, `Pair` and `Triple`.
- detekt rules: [style](https://detekt.dev/docs/rules/style/) (`UseOrEmpty`, `UseIsNullOrEmpty`, `UnnecessaryApply`, `UnnecessaryLet`) and [potential bugs](https://detekt.dev/docs/rules/potential-bugs/) (`LateinitUsage`, `DoubleMutabilityForCollection`).
- Code examples in this note were compiled with Kotlin 2.4.21 and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)) on 2026-10-22.
