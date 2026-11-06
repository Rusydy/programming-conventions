# Kotlin Testing

## Summary

Test behaviour through the public API with the standard stack: `kotlin.test` on the JUnit Platform, `kotlinx-coroutines-test` for coroutines, Turbine for flows. Replace dependencies with fakes before you reach for a mock, and write the production code so that this is possible: constructor injection, with the clock and the dispatchers passed in.

## Rules

### Setup

- Use `kotlin("test")` with the JUnit Platform, and put the tests in the `test` source set (`commonTest` in a multiplatform project). The `test` source set can see the `internal` declarations of `main`.
- Add `kotlinx-coroutines-test` and Turbine as test dependencies only. Do not depend on `kotlinx-coroutines-test` from main sources.
- Name a test class after the class it tests, plus `Test`: `HashTest`, `HashIntegrationTest`.
- Name a test after the behaviour it proves. Backticked names are allowed in JVM tests ([style](04-naming-comments-and-style.md#test-names)); long ones can be exempted from the line-length rule with `ktlint_ignore_back_ticked_identifier`.
- Use `lateinit var` for a fixture that a `@BeforeTest` or `@BeforeEach` method sets up. That is the case `lateinit` exists for, and it avoids nullable fields in tests.

```kotlin
// fragment
dependencies {
    testImplementation(kotlin("test"))
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.turbine)
}

tasks.test {
    useJUnitPlatform()
}
```

### Test doubles

- Prefer a **fake**: a lightweight, working implementation that lives in the test source set, such as an in-memory repository. Fakes need no mocking framework. Prefer a fake to a stub for simplicity, and avoid spies, which add complexity.
- Use a **mock** only to check an interaction that has no visible result, for example that a method was called exactly once. MockK is the Kotlin mocking library: `mockk<T>()`, `every { }` and `verify { }`, with `coEvery { }` and `coVerify { }` for `suspend` functions.
- When a library or framework ships official test support, such as fakes, use it before you write your own.
- Make tests hermetic: no real network, clock or file system when a fake can stand in. Passing the dependencies through the constructor is what makes this cheap ([API design](07-api-and-class-design.md#dependencies-and-testability)).

```kotlin
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

interface UserRepository {
    fun users(): List<String>
}

class FakeUserRepository(private val data: List<String>) : UserRepository {
    override fun users(): List<String> = data
}

class Greeter(private val repository: UserRepository) {
    fun firstUser(): String? = repository.users().firstOrNull()
}

class GreeterTest {
    @Test
    fun `first user is the first one in the repository`() {
        val greeter = Greeter(FakeUserRepository(listOf("Alice", "Bob")))

        assertEquals("Alice", greeter.firstUser())
    }

    @Test
    fun `first user is null when the repository is empty`() {
        val greeter = Greeter(FakeUserRepository(emptyList()))

        assertNull(greeter.firstUser())
    }
}
```

### Coroutines and Flow

- Test `suspend` code inside `runTest { }`. It skips `delay` calls while keeping the order of the tasks, rethrows uncaught exceptions from child coroutines at the end, and fails after 60 seconds so that a hung test cannot block CI. Return its result from the test function (`= runTest { }`); Kotlin/JS requires it.
- Inject a test dispatcher into the class under test, and give every test dispatcher the scheduler of the test: `StandardTestDispatcher(testScheduler)`. The code then runs on one thread, in a deterministic order. A `StandardTestDispatcher` queues coroutines until the test lets them run (`advanceUntilIdle()`); an `UnconfinedTestDispatcher` runs them eagerly, which is simpler but gives less control.
- Control virtual time with `currentTime`, `runCurrent()`, `advanceTimeBy(duration)` and `advanceUntilIdle()`.
- For code that uses `Dispatchers.Main` or `viewModelScope`, call `Dispatchers.setMain(testDispatcher)` before the test and `Dispatchers.resetMain()` after it. Both change the global `Main` dispatcher immediately.
- Expect an opt-in warning for part of this API. With kotlinx.coroutines 1.11.0 the compiler flags `advanceUntilIdle`, `runCurrent`, `advanceTimeBy`, `currentTime`, `UnconfinedTestDispatcher`, `setMain` and `resetMain` as `@ExperimentalCoroutinesApi`, while `runTest`, `StandardTestDispatcher` and `testScheduler` need nothing. Opt in once for the test compilation with the compiler argument `-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi` instead of annotating every test ([opt-in requirements](https://kotlinlang.org/docs/opt-in-requirements.html)).
- Test flows with Turbine. `flow.test { }` collects the flow into a channel and gives you `awaitItem()`, `awaitComplete()` and `awaitError()`. It fails with a timeout instead of hanging, and ends by checking that no event was left unconsumed. To test several flows use `testIn(backgroundScope)`.
- A `StateFlow` emits its current value first, so the first `awaitItem()` returns the initial state.
- Do not launch coroutines from a test outside `runTest`: exceptions can be swallowed (detekt `CoroutineLaunchedInTestWithoutRunTest`, inactive by default).

```kotlin
import app.cash.turbine.test
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlin.test.Test
import kotlin.test.assertEquals

class Fetcher(private val dispatcher: CoroutineDispatcher) {
    suspend fun fetch(): String = withContext(dispatcher) {
        delay(1_000)
        "data"
    }
}

class FetcherTest {
    @Test
    fun `fetch returns the data without waiting for the delay`() = runTest {
        val fetcher = Fetcher(StandardTestDispatcher(testScheduler))

        assertEquals("data", fetcher.fetch()) // the one-second delay runs in virtual time
    }

    @Test
    fun `flow emits its items and completes`() = runTest {
        flowOf(1, 2).test {
            assertEquals(1, awaitItem())
            assertEquals(2, awaitItem())
            awaitComplete()
        }
    }

    @Test
    fun `state flow emits the current value first`() = runTest {
        val state = MutableStateFlow("loading")

        state.test {
            assertEquals("loading", awaitItem())
            state.value = "ready"
            assertEquals("ready", awaitItem())
        }
    }
}
```

### Assertions and diagnostics

- Use the assertion functions of `kotlin.test` (`assertEquals`, `assertNull`, `assertTrue`, `assertFailsWith`). They work in common code as well as on the JVM.
- The Power-assert compiler plugin prints the value of each sub-expression when an `assert` fails. It is experimental (it needs an opt-in), so adopt it deliberately and not by default.

## Sources and raw notes

Pages read on 2026-10-22:

- [Test Java code using Kotlin and JUnit](https://kotlinlang.org/docs/jvm-test-using-junit.html): `kotlin("test")`, JUnit Platform, `lateinit` fixtures. [Test your multiplatform app](https://kotlinlang.org/docs/multiplatform/multiplatform-run-tests.html): `commonTest`.
- [kotlinx-coroutines-test](https://github.com/Kotlin/kotlinx.coroutines/tree/master/kotlinx-coroutines-test): `runTest`, test dispatchers, `setMain`, virtual time, the 60-second timeout.
- [Testing Kotlin coroutines on Android](https://developer.android.com/kotlin/coroutines/test), [Best practices for coroutines in Android](https://developer.android.com/kotlin/coroutines/coroutines-best-practices) (inject `TestDispatcher`s) and [Use test doubles in Android](https://developer.android.com/training/testing/fundamentals/test-doubles) (fakes over stubs, mocks and spies).
- [Turbine](https://github.com/cashapp/turbine): `test`, `testIn`, `awaitItem`, `ensureAllEventsConsumed`. [MockK](https://mockk.io/) (README read at [github.com/mockk/mockk](https://github.com/mockk/mockk)): `every`, `coEvery`, `verify`, `coVerify`.
- [Power-assert compiler plugin](https://kotlinlang.org/docs/power-assert.html) (experimental).
- [Library authors' guidelines: testability](https://kotlinlang.org/docs/api-guidelines-testability.html) and [consistency](https://kotlinlang.org/docs/api-guidelines-consistency.html).
- [Android Kotlin style guide](https://developer.android.com/kotlin/style-guide): test class names. ktlint [standard rules](https://ktlint.github.io/ktlint/latest/rules/standard/): `ktlint_ignore_back_ticked_identifier`. detekt [coroutines rules](https://detekt.dev/docs/rules/coroutines/): `CoroutineLaunchedInTestWithoutRunTest`.
- Code examples in this note were compiled with Kotlin 2.4.21, kotlinx.coroutines 1.11.0, Turbine 1.2.1 and JUnit 6.1.3, and checked with ktlint 1.8.0 (the `.editorconfig` of the [tooling note](02-project-setup-and-tooling.md#formatting-and-static-checks)), on 2026-10-22. The test bodies were also run outside a JUnit engine: the `runTest` example finished in 77 ms of real time for a one-second delay, and the Turbine assertions passed. Which test APIs need an opt-in was read from the compiler warnings of the same setup.
