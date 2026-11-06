# Kotlin Platform Practices

## Summary

Kotlin is rarely written in a vacuum. On Android and in Jetpack Compose, follow the architecture guidance of the Android team and the Compose API guidelines. In Kotlin Multiplatform, keep shared code in `commonMain` and reach platforms through interfaces. On the server, use the Spring compiler plugins and its Kotlin support. Platform guidance applies to code that targets the platform, where the Kotlin team's guidance has nothing to say; the few style conflicts are settled in the [style note](04-naming-comments-and-style.md#where-the-guides-disagree) ([order of precedence](01-principles-and-sources.md#order-of-precedence)).

## Rules

### Android and Jetpack Compose

#### Architecture

- Use a **layered architecture**. A clearly defined data layer exposes data through repositories, even when a repository has a single data source. A UI layer shows the data. Add a domain layer with use cases in big apps, when business logic is reused by several ViewModels or one ViewModel becomes too complex. Composables and ViewModels never talk to a data source (database, DataStore, location, network status) directly. In a small app, a `data` and a `ui` package or module is enough ([layout](03-project-layout-and-packages.md#packages-and-modules)).
- Follow **unidirectional data flow**: the ViewModel exposes UI state through the observer pattern and receives actions through method calls.
- Use coroutines and flows between the layers ([coroutines](09-coroutines-and-flow.md)).
- Use dependency injection, mainly **constructor injection**. Use Hilt when the app has several screens with ViewModels, WorkManager, or ViewModels scoped to the navigation back stack; manual injection is fine in a simple app.
- Build new apps with Jetpack Compose, in a single activity, and use Navigation 3 when there is more than one screen.
- Name a function that returns a stream `get{Model}Stream` (`getAuthorsStream(): Flow<List<Author>>`). Give an interface implementation a descriptive name (`OfflineFirstNewsRepository`) or the prefix `Default`, and prefix fakes with `Fake`.
- Enable R8 in full mode, generate Baseline Profiles and Startup Profiles, and measure with Macrobenchmark.

#### ViewModel and state

- Use a ViewModel at screen level, not in reusable pieces of UI. Reusable components use plain state holder classes, so that their state can be hoisted.
- Keep the ViewModel independent of the Android lifecycle: hold no `Activity`, `Context` or `Resources`, and use `ViewModel`, not `AndroidViewModel`.
- Expose UI state through one property called `uiState`, of type `StateFlow<ScreenUiState>`. Model it as a `data class`, or as a `sealed interface` when the states exclude each other. For streams from other layers build it with `combine` and `stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), initialValue)`. For simple cases expose a `MutableStateFlow` as an immutable `StateFlow` ([coroutines](09-coroutines-and-flow.md#state-and-flows)).
- Do not send events from the ViewModel to the UI. Handle the event in the ViewModel and update the state with the result.
- Collect state in the UI with `collectAsStateWithLifecycle()`. In place of overriding `Activity` lifecycle callbacks, use `LifecycleStartEffect`, `LifecycleResumeEffect`, `repeatOnLifecycle` or `collectAsStateWithLifecycle()`.

#### Composables

- Name a composable that returns `Unit` with a PascalCase noun (`FancyButton`), as if it were a class. Name a composable that returns a value in camelCase, like any function. Prefix a composable factory that remembers a mutable object with `remember` (`rememberScrollState`). Name a `CompositionLocal` after its value, with `Local` as a prefix when nothing better fits (`LocalTheme`).
- A UI element returns `Unit`, accepts `modifier: Modifier = Modifier` as its first optional parameter, passes it to the root node it emits, and only adds its own modifiers after the one it received.
- Prefer stateless composables with hoisted state: replace a state variable with a `value` parameter and an `onValueChange` callback. Hoist state to at least the lowest common parent of the composables that read it, to at least the highest level at which it may be changed, and together with other state that changes in response to the same events.
- Use `remember` for state across recompositions and `rememberSaveable` for state that must also survive configuration changes.
- Do not use a mutable object that Compose cannot observe (`mutableListOf()`, `ArrayList`, a mutable data class) as state. Hold the list in an observable `State<List<T>>` and assign a new immutable list when it changes.
- Run side effects in the right API: `LaunchedEffect(key)` for suspend work tied to the composition, `rememberCoroutineScope` to launch from callbacks, `rememberUpdatedState` for a value that a long-running effect reads but that must not restart it, `DisposableEffect` for cleanup, `snapshotFlow` to turn Compose state into a flow.

```kotlin
// fragment
@Composable
fun NewsScreen(viewModel: NewsViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    NewsContent(uiState = uiState, onRefresh = viewModel::refresh)
}

@Composable
fun NewsContent(
    uiState: NewsUiState,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Stateless: draws uiState and reports events upwards.
}
```

#### Compose performance

- Do as little calculation as possible in a composable. Cache an expensive one with `remember` and pass every input it uses as a key. Better still, calculate in the ViewModel and pass the result in.
- Give items of lazy lists a stable key and a content type. A key is unique, deterministic and saveable in a `Bundle`: use a primitive such as a `Long` or `String`, never a list index or `hashCode()`. Use `itemsIndexed`, not `indexOf`, inside `items`. Use a plain `Row` or `Column` for a small, bounded list.
- Limit recomposition caused by fast-changing state with `derivedStateOf` (or `computedStateOf` in Compose Runtime 1.13 and later). Defer reads of state as long as possible, for example with the lambda form of a modifier (`Modifier.offset { }`), so that Compose can skip composition. Never write to state during composition; write in an event handler.
- With strong skipping (on by default from Kotlin 2.0.20), Compose compares unstable parameters, standard collections included, by instance (`===`) and skips a composable when the same instance is passed again. So do not mutate an object in place and expect a recomposition; pass a new instance, and prefer immutable data classes. For classes from modules that the Compose compiler does not process, use a stability configuration file or `@Stable` and `@Immutable` where `equals()` is cheap. A `@Stable` type must have an `equals()` that always returns the same answer for the same two references.

### Kotlin Multiplatform

- Set up source sets with the default hierarchy template, keep platform access behind interfaces, and name platform files with the source set suffix ([layout](03-project-layout-and-packages.md#multiplatform-source-sets)).
- Inject platform dependencies as interfaces. Use the DI framework the project already uses (the Printer App plan uses Koin), or plain constructor injection with interfaces and factory functions, which the Multiplatform documentation says is enough to adopt Kotlin Multiplatform. The Hilt advice above is for Android modules.
- Write shared code in `commonMain` with multiplatform libraries rather than platform APIs: kotlinx.coroutines, kotlinx.serialization, `kotlin.time` (`Clock`, `Instant`) and `kotlin.uuid` (stable in 2.4).
- Use kotlinx.serialization for serialisation in shared code. It consists of a compiler plugin that generates the serialisers (no reflection), a runtime library and format libraries (JSON, ProtoBuf, CBOR, Hocon, Properties), and it runs on the JVM, JS and Native. Mark classes `@Serializable`.
- In shared Compose code collect flows with `collectAsState()`. `collectAsStateWithLifecycle()` is Android-only.
- Put shared tests in `commonTest` with `kotlin.test` and run them on every target. For a library, give the same inputs the same results on all platforms and design the API for use from common code.

### Server-side (Spring)

- Spring Framework supports Kotlin 2.2 and later and needs `kotlin-stdlib` and `kotlin-reflect` on the classpath. Add `jackson-module-kotlin` for JSON; Spring registers it automatically when it finds it.
- Apply the `kotlin-spring` compiler plugin: `kotlin("plugin.spring")`. Kotlin classes are final, and the plugin opens classes and members that carry `@Component` (and annotations built on it), `@Async`, `@Transactional`, `@Cacheable` or `@SpringBootTest`. Apply `kotlin-jpa` (`kotlin("plugin.jpa")`) to entities: it generates the zero-argument constructor that JPA needs and opens the entities so that lazy loading works. A project from start.spring.io enables them by default.
- Spring annotates its API with JSpecify, and Kotlin 2.1 and later enforce these annotations strictly ([types](06-null-safety-and-types.md#platform-types)).
- Use `suspend` functions and `Flow` in annotated controllers, in Spring MVC and WebFlux. Add `kotlinx-coroutines-core` and `kotlinx-coroutines-reactor`. A `Mono<T>` becomes `suspend fun handler(): T` (or `T?` when it may be empty), and a `Flux<T>` becomes `Flow<T>`.

```kotlin
// fragment
plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    kotlin("plugin.jpa")
}
```

## Sources and raw notes

Pages read on 2026-10-22:

- Android: [Recommendations for Android architecture](https://developer.android.com/topic/architecture/recommendations), [State and Jetpack Compose](https://developer.android.com/develop/ui/compose/state), [Side-effects in Compose](https://developer.android.com/develop/ui/compose/side-effects), [Follow best practices (Compose performance)](https://developer.android.com/develop/ui/compose/performance/bestpractices), [Stability in Compose](https://developer.android.com/develop/ui/compose/performance/stability), [UI State production](https://developer.android.com/topic/architecture/ui-layer/state-production), [Guide to Android app modularization](https://developer.android.com/topic/modularization).
- [API Guidelines for Jetpack Compose](https://github.com/androidx/androidx/blob/androidx-main/compose/docs/compose-api-guidelines.md): naming, `Modifier` parameter and stable types (the rules marked as applying to app development), and state hoisting.
- Kotlin Multiplatform: [Expected and actual declarations](https://kotlinlang.org/docs/multiplatform/multiplatform-expect-actual.html), [Source set hierarchy](https://kotlinlang.org/docs/multiplatform/multiplatform-hierarchy.html), [Library authors' guidelines: build for multiplatform](https://kotlinlang.org/docs/api-guidelines-build-for-multiplatform.html), [kotlinx.serialization](https://github.com/Kotlin/kotlinx.serialization).
- Spring: [Kotlin support](https://docs.spring.io/spring-framework/reference/languages/kotlin.html) with [requirements](https://docs.spring.io/spring-framework/reference/languages/kotlin/requirements.html), [null-safety](https://docs.spring.io/spring-framework/reference/languages/kotlin/null-safety.html) and [coroutines](https://docs.spring.io/spring-framework/reference/languages/kotlin/coroutines.html); Kotlin's [kotlin-spring](https://kotlinlang.org/docs/kotlin-spring-plugin.html), [kotlin-jpa](https://kotlinlang.org/docs/kotlin-jpa-plugin.html), [all-open](https://kotlinlang.org/docs/all-open-plugin.html) and [no-arg](https://kotlinlang.org/docs/no-arg-plugin.html) plugins.
- The code blocks in this note are fragments. They need the Compose or Spring libraries and were not compiled.
