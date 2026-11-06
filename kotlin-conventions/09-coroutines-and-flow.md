# Kotlin Coroutines and Flow

## Summary

Concurrency in Kotlin is structured: every coroutine runs inside a scope that owns it, on a dispatcher that is injected, and cancellation is never swallowed. A `suspend` function is safe to call from the main thread. One-shot work is a `suspend` function, a stream of values is a `Flow`, and observable state is exposed as a read-only `StateFlow`.

## Rules

### Dispatchers and scopes

- Start a coroutine only in a `CoroutineScope`. Coroutines form a tree: a parent waits for its children, and cancelling or failing the parent cancels every child. This is what keeps cancellation and error handling predictable.
- Inject dispatchers. Do not write `Dispatchers.IO`, `Default` or `Main` inside a class; take a `CoroutineDispatcher` through the constructor, with the real dispatcher as the default value if you like. Tests then replace it with a test dispatcher. detekt reports hard-coded dispatchers (`InjectDispatcher`).
- Do not use `GlobalScope`. It hard-codes the scope, makes tests hard to control and bypasses structured concurrency. For work that must outlive the caller, inject an external `CoroutineScope` that is owned by something longer-lived, such as the application. detekt reports it (`GlobalCoroutineUsage`).
- Use `coroutineScope { }` when the work belongs to the caller and a failure should cancel the siblings. Use `supervisorScope { }` when a failing child must not cancel its siblings or its parent.
- Run independent calls in parallel with `async` inside a `coroutineScope`, and combine the results with `await()`. Do not write functions that return a `Deferred` after starting it in `GlobalScope` ("async-style" functions); the coroutines documentation strongly discourages them.
- Use `runBlocking` only when no other option exists to call suspending code from non-suspending code, for example in `main` or in a test.
- Use `delay` and never `Thread.sleep` in a coroutine: sleeping blocks the thread that other coroutines share (detekt `SleepInsteadOfDelay`).

```kotlin
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class NewsRepository(
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val externalScope: CoroutineScope,
) {
    suspend fun fetchLatest(): List<String> = withContext(ioDispatcher) {
        listOf("first", "second") // a blocking call would go here
    }

    suspend fun bookmark(id: String) {
        externalScope.launch { println("bookmarked $id") }.join()
    }
}

suspend fun loadBoth(repository: NewsRepository): Pair<List<String>, List<String>> =
    coroutineScope {
        val first = async { repository.fetchLatest() }
        val second = async { repository.fetchLatest() }
        first.await() to second.await()
    }
```

### Suspend functions

- Make every `suspend` function main-safe: safe to call from the main thread. The class that does blocking or CPU-heavy work moves it off the thread with `withContext(dispatcher)`, so callers never choose a dispatcher.
- Mark a function `suspend` only when it suspends. A needless `suspend` limits the function to other suspending functions (detekt `RedundantSuspendModifier`).
- Do not give a `suspend` function a `CoroutineScope` receiver. A function is either `suspend` or an extension on `CoroutineScope`, because both bring a coroutine context and the two become ambiguous (detekt `SuspendFunWithCoroutineScopeReceiver`).
- In the data and business layers expose `suspend` functions for one-shot calls and `Flow` for data that changes over time. The caller, usually the presentation layer, then controls the lifecycle of the work and can cancel it.
- A function that returns a `Flow` is not `suspend`. Calling it must have no side effect; work starts when somebody collects the flow (detekt `SuspendFunWithFlowReturnType`).

### Cancellation

- Cancellation is cooperative. A cancelled coroutine stops only when it suspends or checks. All `suspend` functions of `kotlinx.coroutines` (`delay`, `withContext`) are cancellable. In a loop of blocking or CPU-bound work, call `ensureActive()` (or check `isActive`, or call `yield()`) on each iteration.
- Never swallow `CancellationException` ([error handling](08-error-handling.md#cancellation)).
- Release resources in `finally`. If cleanup itself suspends, run it in `withContext(NonCancellable) { ... }`.

```kotlin
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

suspend fun readAll(paths: List<String>): List<String> = buildList {
    for (path in paths) {
        currentCoroutineContext().ensureActive()
        add(java.io.File(path).readText())
    }
}
```

### Errors and cancellation

- A coroutine that fails with an exception other than `CancellationException` cancels its parent. Cancelling a child with `Job.cancel()` does not cancel the parent.
- On a root coroutine, `launch` treats an exception as uncaught, while `async` keeps it until `await()` is called. In `viewModelScope.launch` or `lifecycleScope.launch`, catch the exceptions you expect in the body, using specific types such as `IOException`, not `Exception` or `Throwable`.
- A `CoroutineExceptionHandler` works only on a root coroutine created by `launch`. It is not used by children or by `async`, and it cannot recover: the coroutine has already completed. Use it to log, report or terminate.

### Flow

- A `flow { }` is cold. Its code runs again for every collector, so two collectors fetch the data twice. Share one upstream with `stateIn` or `shareIn`.
- Change the context of the upstream with `flowOn`. Do not call `emit` from another context inside `flow { }`, either with `withContext` or with a new coroutine. Use `channelFlow` or `callbackFlow` when values arrive from other coroutines or callbacks.
- Handle upstream errors with the `catch { }` operator, which can also `emit` a fallback value. It does not catch errors thrown in the collector, so those reach the caller of `collect`.
- Convert a callback API with `callbackFlow` and always end the block with `awaitClose { ... }` to unregister the callback. Without it the flow fails with an `IllegalStateException`, because the callback could leak.

```kotlin
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn

interface Sensor {
    fun register(listener: (Int) -> Unit)
    fun unregister(listener: (Int) -> Unit)
}

fun Sensor.readings(): Flow<Int> = callbackFlow {
    val listener: (Int) -> Unit = { trySend(it) }
    register(listener)
    awaitClose { unregister(listener) }
}

fun numbers(dispatcher: CoroutineDispatcher): Flow<Int> =
    flow { for (n in 1..3) emit(n) }.flowOn(dispatcher)
```

### State and flows

- Create coroutines in the `ViewModel` (`viewModelScope.launch`) and expose state, instead of exposing `suspend` functions that hold business logic. A view should not start coroutines for business logic. Work that must run for 5 seconds or more, or that must survive the screen, does not belong in `viewModelScope`.
- Keep the mutable type private and expose a read-only one: a `MutableStateFlow` behind a public `StateFlow`. The change then stays in one class and is easy to debug. On Kotlin 2.4 or later declare it with an explicit backing field, as in the example below. Before 2.4 (or when the property needs a custom getter) use a private `_selected` backing property and expose it as `_selected.asStateFlow()` ([types](06-null-safety-and-types.md#classes-inheritance-and-visibility)).
- Produce UI state as a flow and turn it into a `StateFlow` with `stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), initialValue)`. `WhileSubscribed` keeps the pipeline active only while the UI collects in a lifecycle-aware way; `Lazily` keeps it active while the user may return to the screen. Combine several sources with `combine`.
- Collect in Compose with `collectAsStateWithLifecycle()`, the recommended way on Android ([platform practices](11-platform-practices.md#android-and-jetpack-compose)).

```kotlin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

sealed interface UiState {
    data object Loading : UiState
    data class Ready(val items: List<String>) : UiState
}

class ItemsModel(scope: CoroutineScope, items: Flow<List<String>>) {
    val selected: StateFlow<String?>
        field = MutableStateFlow(null)

    val uiState: StateFlow<UiState> = items
        .map<List<String>, UiState> { UiState.Ready(it) }
        .catch { emit(UiState.Ready(emptyList())) }
        .stateIn(scope, SharingStarted.WhileSubscribed(5_000), UiState.Loading)

    fun select(item: String) {
        selected.value = item
    }
}
```

### Shared mutable state

- Share as little mutable state as you can. When coroutines must share some, use a thread-safe structure (an atomic class or a concurrent collection), confine the state to one thread, or guard it with a `Mutex` and `withLock { }`. A `Mutex` suspends and does not block a thread. Fine-grained locking costs time, so use it where the state has no natural thread to be confined to.
- `@Volatile` does not make compound operations such as `counter++` atomic.

## Sources and raw notes

Pages read on 2026-10-22:

- [Coroutines basics](https://kotlinlang.org/docs/coroutines-basics.html): structured concurrency, `coroutineScope`, `runBlocking`, dispatchers.
- [Cancellation and timeouts](https://kotlinlang.org/docs/coroutines-cancellation.html), [Coroutine exceptions handling](https://kotlinlang.org/docs/exception-handling.html), [Composing suspending functions](https://kotlinlang.org/docs/composing-suspending-functions.html) (async-style functions), [Coroutine context and dispatchers](https://kotlinlang.org/docs/coroutine-context-and-dispatchers.html), [Flows](https://kotlinlang.org/docs/coroutines-flow.html), [Shared mutable state and concurrency](https://kotlinlang.org/docs/shared-mutable-state-and-concurrency.html). The Markdown sources were read in the [kotlinx.coroutines repository](https://github.com/Kotlin/kotlinx.coroutines/tree/master/docs/topics).
- [Best practices for coroutines in Android](https://developer.android.com/kotlin/coroutines/coroutines-best-practices) (last updated 2026-09-24): injected dispatchers, main-safety, the `ViewModel` creates coroutines, immutable types, `GlobalScope`, cancellation, exceptions.
- [Kotlin flows on Android](https://developer.android.com/kotlin/flow), [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow) and [UI State production](https://developer.android.com/topic/architecture/ui-layer/state-production): `catch`, `flowOn`, `stateIn` with `WhileSubscribed`.
- [State and Jetpack Compose](https://developer.android.com/develop/ui/compose/state): `collectAsStateWithLifecycle()`.
- detekt [coroutines rules](https://detekt.dev/docs/rules/coroutines/): `GlobalCoroutineUsage`, `InjectDispatcher`, `RedundantSuspendModifier`, `SleepInsteadOfDelay`, `SuspendFunWithCoroutineScopeReceiver`, `SuspendFunWithFlowReturnType`.
- Code examples in this note were compiled with Kotlin 2.4.21 and kotlinx.coroutines 1.11.0, and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)), on 2026-10-22. The `IllegalStateException` of a `callbackFlow` without `awaitClose` was confirmed by running it with the same versions.
