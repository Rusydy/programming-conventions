# Kotlin Null Safety and Type Design

## Summary

Let the type system carry the rules. Types are non-null by default; nullable only when absence is a real state; closed sets of cases are `sealed` or `enum`; distinct primitives are `value class`es; classes are final unless inheritance is designed. The compiler then rejects whole groups of mistakes before the code runs.

## Rules

### Nullability

- Use a non-null type unless "no value" is a legitimate state. Do not use `T?` to mean "not initialised yet"; initialise in the constructor instead ([idioms](05-idiomatic-language-use.md#objects-delegation-and-resources) for the `lateinit` exception).
- Work with nullable values through `?.`, `?:` and `let`. Leave early with `?: return`, `?: throw` or `?: error("reason")`.
- Avoid `!!`. It turns a missing value into a `NullPointerException` at the call site and says nothing about why the value should be there. Use `requireNotNull(x) { "reason" }` for arguments, `checkNotNull(x) { "reason" }` for state, or an Elvis with `error`. The Kotlin documentation presents `!!` for the case where you are sure and the compiler cannot prove it. detekt reports each use (`UnsafeCallOnNullableType`).
- Use `as?` instead of `as` when the cast may fail, and combine it with `?:`. A plain `as` throws when the value is of another type.
- Use `filterNotNull()` and `mapNotNull { }` on collections of nullable elements. Write an extension on a nullable receiver (`fun String?.orDash()`) when the null case has a natural default.
- A smart cast works only when the compiler can prove that the value cannot change between the check and the use:

| Value | Smart cast works |
| --- | --- |
| `val` local variable | always (not for a local delegated property) |
| `val` property | when it is `private` or `internal`, or the check is in the same module; never for `open` properties or custom getters |
| `var` local variable | when it is not changed between the check and the use and not captured by a lambda that changes it |
| `var` property | never |

- Copy a `var` property into a local `val` before you test it: `val token = session.token ?: return null`.

```kotlin
class Session {
    var token: String? = null
}

fun authorization(session: Session): String? {
    val token = session.token ?: return null
    return "Bearer $token"
}

fun idOrFail(raw: String?): String = requireNotNull(raw) { "id is required" }

fun describe(value: Any): String =
    (value as? CharSequence)?.let { "text of ${it.length} characters" } ?: "not text"
```

### Platform types

- A value that comes from Java code without nullability annotations has a platform type. The compiler does not check it, and assigning it to `T` or `T?` is your decision.
- Declare the Kotlin type explicitly on every public function that returns a platform-type expression and on every property that a platform-type expression initialises. A local value may leave the type to inference.
- In Java code that you own, annotate with `@Nullable` and `@NotNull` (JetBrains, Android or JSpecify). Kotlin then sees real nullable and non-null types. JSpecify is the only flavour that is reported at the `strict` level by default.
- Nullability annotations from JSpecify are enforced strictly from Kotlin 2.1 without any option, and Spring Framework annotates its API with them ([platform practices](11-platform-practices.md#server-side-spring)). Libraries that still use JSR-305 annotations are checked at the `warn` level by default. The compiler option `-Xjsr305=strict` turns those warnings into errors, but the Kotlin documentation considers the `strict` value experimental because more checks may be added to it.

```kotlin
fun userHome(): String? = System.getProperty("user.home")
```

### Sealed hierarchies and enums

- Model a closed set of cases that carry different data as a `sealed interface` or `sealed class` with `data class` and `data object` subtypes. All direct subtypes are known at compile time, so `when` can be exhaustive with no `else`, and code outside the module cannot add an invalid case. For a library this is how you keep third parties from extending a type in ways your design forbids.
- Use an `enum class` when every case is a single constant of one shape. Each constant exists once, while a sealed subtype may have many instances. An enum cannot extend a sealed class, but it can implement a sealed interface.
- Use `Enum.entries`, not `values()`. A lookup by name with `valueOf()` throws `IllegalArgumentException` for an unknown name, so search `entries` when the input comes from outside.
- Do not add an `else` branch to a `when` over a sealed type or an enum, because it switches off the exhaustiveness check ([idioms](05-idiomatic-language-use.md#expressions-not-statements)).

```kotlin
sealed interface LoadState<out T> {
    data object Loading : LoadState<Nothing>
    data class Loaded<T>(val value: T) : LoadState<T>
    data class Failed(val message: String) : LoadState<Nothing>
}

fun <T> LoadState<T>.describe(): String = when (this) {
    LoadState.Loading -> "loading"
    is LoadState.Loaded -> "loaded: $value"
    is LoadState.Failed -> "failed: $message"
}

enum class Level { LOW, MEDIUM, HIGH }

fun levelOf(name: String): Level? =
    Level.entries.firstOrNull { it.name.equals(name, ignoreCase = true) }
```

### Data classes

- Use a `data class` for a value that is defined by its contents. The primary constructor needs at least one parameter, and every parameter must be `val` or `var`. The compiler derives `equals()`, `hashCode()`, `toString()`, `copy()` and `componentN()` from the primary-constructor properties only. A property declared in the body is left out of all of them, so two objects can compare equal while differing in it.
- Make every property a `val` and change a value with `copy()`.
- A data class with a private or internal constructor still gets a public `copy()` unless you say otherwise, and `copy()` then bypasses the validation in your factory. Kotlin 2.4.21 reports a warning for this ("non-public primary constructor is exposed via the generated 'copy()' method"). Annotate the class with `@ConsistentCopyVisibility` so that `copy()` follows the constructor, or choose a regular class.
- Do not expose a data class in the public API of a library: adding a property later changes the constructor and `copy()` signatures and breaks binary compatibility ([API design](07-api-and-class-design.md#libraries)).

```kotlin
@ConsistentCopyVisibility
data class Money private constructor(val cents: Long) {
    companion object {
        fun of(cents: Long): Money {
            require(cents >= 0) { "negative amount: $cents" }
            return Money(cents)
        }
    }
}
```

### Value classes

- Wrap an identifier, a unit or any other primitive that has a meaning in a `@JvmInline value class`. The compiler stores only the wrapped value in most places, so there is no allocation, and a `UserId` can no longer be passed where an `OrderId` is expected.
- Do not store an identifier in a `Long` or `String`, and do not use an arithmetic type for something you never calculate with. The Kotlin library guidelines give identifiers as the example, because callers may start to compare them. Use `kotlin.time.Duration` for time spans instead of a bare `Long` of milliseconds.
- A value class has one `val` property in its primary constructor, may have an `init` block, functions and computed properties, may implement interfaces, and cannot extend a class. As a rule of thumb it is boxed whenever it is used as another type, an interface it implements for example. Referential equality (`===`) is not allowed on it.
- A function that takes a value class gets a mangled name in the bytecode. Add `@JvmName` on the function when Java must call it.
- A `typealias` is only another name and gives no such protection ([idioms](05-idiomatic-language-use.md#functions-and-properties)).

```kotlin
@JvmInline
value class UserId(val value: String) {
    init {
        require(value.isNotBlank()) { "user id must not be blank" }
    }
}

@JvmInline
value class OrderId(val value: String)

fun cancel(user: UserId, order: OrderId): String = "order ${order.value} cancelled by ${user.value}"
```

### Classes, inheritance and visibility

- Classes and their members are `final` by default. Add `open` only to a class that you designed and documented for inheritance. To reuse behaviour, implement an interface and delegate to an object with `by`.
- Initialise state in the primary constructor and check it in an `init` block with `require`. If a class has several overloaded constructors that cannot be replaced by default values, use factory functions with distinct names instead.
- An interface may contain default implementations. Declare an interface with a single abstract method as a `fun interface` so that callers can pass a lambda.
- Visibility is `public` unless you say otherwise. Keep implementation details `private`. Use `internal` for code that is shared inside one module and hidden from other modules: a module is a set of files compiled together, such as a Gradle source set, and the `test` source set can see the `internal` declarations of `main`. A top-level `private` declaration is visible in its file only.
- Expose the narrowest type that does the job: `List` and not `MutableList`, a read-only flow and not the mutable one ([coroutines](09-coroutines-and-flow.md#state-and-flows)).
- For a property that is mutable inside its class and read-only outside, use an **explicit backing field** (stable since Kotlin 2.4.0). The property declares the public type, the `field` declares the private implementation type, and the compiler smart casts to it inside the class. No second property and no underscore name are needed. The Kotlin documentation now presents this first and keeps the backing property as the fallback.
- An explicit backing field needs a read-only `val` that is not `open`, not delegated, not a compile-time constant and has no custom getter; the field type must be a subtype of the property type and private. When one of these rules blocks you, or the project is on a Kotlin version before 2.4, use a backing property with a leading underscore ([style](04-naming-comments-and-style.md#names)).

```kotlin
class ShoppingCart {
    val items: List<String>
        field = mutableListOf()

    fun addItem(item: String) {
        items.add(item)
    }
}
```

### Generics

- Use declaration-site variance. Mark a type parameter `out` when the type only produces values of it and `in` when it only consumes them. Kotlin has no wildcards.
- Make an `inline` function with a `reified` type parameter when you need the type at runtime, for example to parse a value into `T`. Avoid inlining large functions: inlining makes the generated code grow, and it pays off for small functions, especially at call sites inside loops.

```kotlin
interface Source<out T> {
    fun next(): T
}

interface Sink<in T> {
    fun put(value: T)
}

inline fun <reified T> Any?.takeAs(): T? = this as? T
```

## Sources and raw notes

Pages read on 2026-10-22:

- [Null safety](https://kotlinlang.org/docs/null-safety.html): safe calls, Elvis, `!!`, safe casts, collections of nullable elements, nullable receivers.
- [Type checks and casts](https://kotlinlang.org/docs/typecasts.html): smart cast prerequisites.
- [Calling Java from Kotlin](https://kotlinlang.org/docs/java-interop.html): platform types, nullability annotations, JSpecify and JSR-305 support.
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html): platform types, factory functions.
- [Sealed classes and interfaces](https://kotlinlang.org/docs/sealed-classes.html), [Enum classes](https://kotlinlang.org/docs/enum-classes.html), [Data classes](https://kotlinlang.org/docs/data-classes.html), [Inline value classes](https://kotlinlang.org/docs/inline-classes.html), [Inheritance](https://kotlinlang.org/docs/inheritance.html), [Visibility modifiers](https://kotlinlang.org/docs/visibility-modifiers.html), [Generics](https://kotlinlang.org/docs/generics.html), [Inline functions](https://kotlinlang.org/docs/inline-functions.html), [Functional (SAM) interfaces](https://kotlinlang.org/docs/fun-interfaces.html), [Delegation](https://kotlinlang.org/docs/delegation.html).
- [What's new in Kotlin 2.0.20](https://kotlinlang.org/docs/whatsnew2020.html): `copy()` visibility change and `@ConsistentCopyVisibility`.
- [Library authors' guidelines](https://kotlinlang.org/docs/api-guidelines-readability.html) (numeric types), [predictability](https://kotlinlang.org/docs/api-guidelines-predictability.html) (sealed types) and [backward compatibility](https://kotlinlang.org/docs/api-guidelines-backward-compatibility.html) (data classes).
- detekt rules: [potential bugs](https://detekt.dev/docs/rules/potential-bugs/) (`UnsafeCallOnNullableType`).
- The warning text about `copy()`, and the fact that it bypasses a private constructor, were checked by compiling and running a sample with Kotlin 2.4.21 on 2026-10-22. All code examples in this note were compiled with the same version and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)).
