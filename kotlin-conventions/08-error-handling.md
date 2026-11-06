# Kotlin Error Handling

## Summary

All Kotlin exceptions are unchecked, so the compiler does not force anyone to handle them. Choose the mechanism by what the caller can do: `null` when a value may legitimately be missing, a precondition function when the caller broke the contract, an exception when the operation failed, and a sealed result type when the caller must branch on the kind of failure. Use one choice consistently within a module. Never swallow a coroutine cancellation.

## Rules

### Choosing the mechanism

| Situation | Mechanism | Example |
| --- | --- | --- |
| A value may legitimately be missing | Return a nullable type | `config["port"]?.toIntOrNull()`, `firstOrNull()` |
| An argument breaks the contract of the function | `require(condition) { message }`, which throws `IllegalArgumentException` | a blank name, a negative amount |
| The object is in the wrong state for the call | `check(condition) { message }` or `checkNotNull`, which throw `IllegalStateException` | `purchase()` on an empty cart |
| A branch should be impossible | `error("message")`, which throws `IllegalStateException` | the `else` branch of a `when` over a `String` |
| The caller must react to each kind of failure | A `sealed` result type | `Transfer.Done`, `Transfer.InsufficientFunds` |
| The operation can fail in ways the caller cannot enumerate | An exception, or `Result<T>` when it wraps one throwing call | I/O, parsing |

- Return `null` when data cannot be fetched or calculated. In other cases throw an exception or return a result type.
- Where both styles are useful, offer two functions and add the suffix `Catching` to the one that wraps the exception, as `run` and `runCatching` do.
- Do not use exceptions for normal control flow. Let callers test a condition before the operation, so they do not need a handler.
- Prefer a `sealed` type to `Result<T>` when the failures are part of your domain. A closed hierarchy makes `when` exhaustive. `Result<T>` holds a success value or any `Throwable`, so it cannot tell the caller which failures to expect. Stay with the standard library: do not add a library such as Arrow for `Either`.
- Use the `...OrNull` functions (`toIntOrNull()`, `getOrNull()`, `firstOrNull()`) instead of catching the exceptions that their counterparts throw.

```kotlin
fun findPort(config: Map<String, String>): Int? = config["port"]?.toIntOrNull()

sealed interface Transfer {
    data class Done(val reference: String) : Transfer
    data class Rejected(val reason: String) : Transfer
    data object InsufficientFunds : Transfer
}

fun transfer(balance: Long, amount: Long): Transfer = when {
    amount <= 0 -> Transfer.Rejected("amount must be positive, was $amount")
    amount > balance -> Transfer.InsufficientFunds
    else -> Transfer.Done("TX-$amount")
}

fun message(result: Transfer): String = when (result) {
    is Transfer.Done -> "done ${result.reference}"
    is Transfer.Rejected -> "rejected: ${result.reason}"
    Transfer.InsufficientFunds -> "insufficient funds"
}
```

### Preconditions

- Check the inputs and the state at the start of a function, before any work is done. Use `require` for arguments and `check` for state, and prefer `requireNotNull` and `checkNotNull` to a null test followed by a throw. detekt reports a hand-written `throw IllegalArgumentException` or `IllegalStateException` (`UseRequire`, `UseCheckOrError`).
- Write messages that include the offending input: `"Username can only contain letters and digits, was: $username"`. Leave out any value that would be sensitive if logged, such as a password.
- Use `error("...")` to mark a state that should not happen, for example in the `else` of a `when`. Its type is `Nothing`, so it fits wherever a value is expected.

```kotlin
class Cart {
    private val items = mutableListOf<String>()

    fun add(item: String) {
        require(item.isNotBlank()) { "item must not be blank" }
        items += item
    }

    fun checkout(): Int {
        check(items.isNotEmpty()) { "cannot check out an empty cart" }
        return items.size
    }
}
```

### Throwing and catching

- Throw the built-in exception that fits (`IllegalArgumentException`, `IllegalStateException`) and add your own type only when callers need to tell cases apart. A custom exception extends `Exception` (or a more specific subclass) and takes a `message` and a `cause`.
- Create a new exception object at every `throw`. An exception carries the stack trace of the place where it was created, so never declare one as an `object`.
- Catch the narrowest type you can handle. `Throwable` also covers `Error` (`OutOfMemoryError`, `StackOverflowError`), which an application generally does not try to handle.
- Use `try` as an expression to return a value from either branch. Put cleanup in `finally`, or better, close resources with `use { }`.
- When you translate a low-level exception into your own type, keep the original as the `cause`, and adopt one policy for the whole library or module: pass it on, wrap it or suppress it. The type of the exception must say what failed, and its data must help to find the cause.
- Add `@Throws(IOException::class)` to a function that Java (or Swift and Objective-C) callers need to handle as failing.

```kotlin
class ConfigException(message: String, cause: Throwable? = null) : Exception(message, cause)

fun loadPort(raw: String): Int = try {
    raw.trim().toInt()
} catch (e: NumberFormatException) {
    throw ConfigException("invalid port '$raw'", e)
}
```

### Result and runCatching

- `runCatching` catches every `Throwable` and returns it as a failed `Result`. That includes `CancellationException` and `Error`s. Use it for one plain, non-suspending call at a boundary, and read the result with `getOrElse`, `getOrNull`, `fold` or `exceptionOrNull`.
- Do not call a `suspend` function inside `runCatching`. The coroutine then swallows its own cancellation. detekt reports this (`SuspendFunSwallowedCancellation`).

### Cancellation

- A cancelled coroutine throws `CancellationException` at its next suspension point. Catching it can break the propagation of cancellation. If a `catch (e: Exception)` or `catch (e: Throwable)` wraps suspending code, rethrow `CancellationException` first.
- Run suspending cleanup that must complete after cancellation in `withContext(NonCancellable) { ... }` inside a `finally` block. Do not pass `NonCancellable` to `launch` or `async`, because it breaks the parent-child relationship.
- See [coroutines and flow](09-coroutines-and-flow.md#errors-and-cancellation) for how `launch`, `async` and supervisors treat exceptions.

```kotlin
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

suspend fun fetchOrNull(id: String): String? = try {
    delay(10)
    "value $id"
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    null
}

// Avoid: runCatching also catches the CancellationException of the suspending call
suspend fun fetchResult(id: String): Result<String> = runCatching {
    delay(10)
    "value $id"
}
```

## Sources and raw notes

Pages read on 2026-10-22:

- [Exception and error handling](https://kotlinlang.org/docs/exceptions.html): precondition functions, `try` as an expression, custom exceptions, the `Nothing` type, the exception hierarchy, Java and Swift interoperability.
- [Library authors' guidelines](https://kotlinlang.org/docs/api-guidelines-consistency.html): choosing an error handling mechanism, the `Catching` suffix; [predictability](https://kotlinlang.org/docs/api-guidelines-predictability.html): `require` and `check`; [debuggability](https://kotlinlang.org/docs/api-guidelines-debuggability.html): exception policy.
- [`Result`](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-result/) and [`runCatching`](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/run-catching.html) in the Kotlin standard library reference.
- [Cancellation and timeouts](https://kotlinlang.org/docs/coroutines-cancellation.html) and [Coroutine exceptions handling](https://kotlinlang.org/docs/exception-handling.html): `CancellationException`, `NonCancellable`, propagation. The Markdown sources were read in the [kotlinx.coroutines repository](https://github.com/Kotlin/kotlinx.coroutines/tree/master/docs/topics).
- [Calling Kotlin from Java](https://kotlinlang.org/docs/java-to-kotlin-interop.html): `@Throws`.
- detekt rules: [style](https://detekt.dev/docs/rules/style/) (`UseRequire`, `UseCheckOrError`) and [coroutines](https://detekt.dev/docs/rules/coroutines/) (`SuspendFunSwallowedCancellation`).
- Code examples in this note were compiled with Kotlin 2.4.21 and kotlinx.coroutines 1.11.0, and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)), on 2026-10-22.
