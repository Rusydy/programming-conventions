# Kotlin Multiplatform Architecture, State and Navigation

## Summary

Use the layers and the unidirectional data flow of the [Kotlin set](../kotlin-conventions/11-platform-practices.md#android-and-jetpack-compose), and share as deep as the apps allow: the data layer first, then the ViewModel, then the UI. The ViewModel is the AndroidX ViewModel in common code, with a factory because non-JVM targets have no reflection. UI state is a `StateFlow`, collected with `collectAsStateWithLifecycle()`. New Compose Multiplatform apps use Navigation 3.

## Rules

### Layers and sharing

- Use the layered architecture of the Kotlin set: a data layer with repositories, a UI layer, a domain layer only in big apps, and unidirectional data flow. In a multiplatform project the layers sit in the shared modules ([structure](03-project-structure-and-source-sets.md#modules)).
- Decide per app how deep the sharing goes. JetBrains describes three levels: share the logic and the UI, share the logic and the ViewModel with a native UI, or share only the data layer. Share the data layer first, then the ViewModel, then the UI, and stop at the deepest level that every app agrees with.
- Keep repository interfaces, models and use cases in `commonMain`. Put an implementation in `commonMain` too, unless it needs a platform API. Then put the platform part behind an interface ([platform code](04-platform-code.md)).
- Keep UI types out of the logic module. A model that holds a Compose `DrawableResource`, a `Color` or an `ImageVector` cannot move into `sharedLogic`. Map the model to a UI type in the UI layer.

### ViewModel

- Use the AndroidX `ViewModel` in common code, not a home-grown base class. With shared Compose UI add `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` to `commonMain`. With a shared ViewModel and a native UI add `androidx.lifecycle:lifecycle-viewmodel` as an `api` dependency, so that the iOS framework exports it.
- Non-JVM targets have no type reflection, so a `viewModel()` call needs an initializer or a factory: `viewModel { OrderViewModel(repository) }`. With Koin use `koinViewModel()`; with Metro use `metroViewModel()`.
- On the desktop target add `kotlinx-coroutines-swing`. `viewModelScope` runs on `Dispatchers.Main.immediate`, which the desktop JVM does not have without it ([concurrency](08-concurrency-memory-and-ios-interop.md#dispatchers)).
- Keep every ViewModel rule of the Kotlin set: one ViewModel per screen, no `Context` or `Activity`, one `uiState` property of type `StateFlow<ScreenUiState>`, a private `MutableStateFlow` behind an explicit backing field on Kotlin 2.4, and no events from the ViewModel to the UI.
- With Navigation 3, scope each ViewModel to its navigation entry. Pass `rememberSaveableStateHolderNavEntryDecorator()` and `rememberViewModelStoreNavEntryDecorator()` as `entryDecorators` of `NavDisplay`. Without them the ViewModel is tied to the Activity and lives on after the user leaves the screen.
- iOS has no `ViewModelStoreOwner`. With a SwiftUI app the ViewModel lifecycle must be tied to SwiftUI by hand. JetBrains documents the KMP-ObservableViewModel library for this; wrap the ViewModel in the app module and keep that code out of the shared module.

```kotlin
// fragment
class OrderViewModel(private val orders: OrderRepository) : ViewModel() {
    val uiState: StateFlow<OrderUiState>
        field = MutableStateFlow(OrderUiState())

    fun setQuantity(quantity: Int) {
        uiState.update { it.copy(quantity = quantity) }
    }
}

@Composable
fun OrderScreen(viewModel: OrderViewModel = koinViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    OrderContent(uiState = uiState, onQuantityChange = viewModel::setQuantity)
}
```

### State in the UI

- Collect a `StateFlow` in common Compose code with `collectAsStateWithLifecycle()` from `lifecycle-runtime-compose`. The library declares it in its `commonMain`, and JetBrains publishes the artifact for the other targets as `org.jetbrains.androidx.lifecycle:lifecycle-runtime-compose`. See [decision 7](01-principles-and-sources.md#decisions-to-review).
- Use `collectAsState()` only in a module that does not depend on the lifecycle library. The JetBrains ViewModel sample uses it.
- Keep platform types out of UI state. A state class holds plain Kotlin types and domain models, so it works on every target and in `commonTest`.
- Keep the `StateFlow` and Compose rules of the Kotlin set: `stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), initialValue)` for state built from streams, hoisted state, stable keys in lazy lists ([coroutines](../kotlin-conventions/09-coroutines-and-flow.md#state-and-flows)).

### Navigation

- Use **Navigation 3** in a new Compose Multiplatform app (Compose Multiplatform 1.10 and newer, on Android, iOS, desktop and web). Add `org.jetbrains.androidx.navigation3:navigation3-ui` to `commonMain`; `navigation3-common` comes transitively. You own the back stack as a `SnapshotStateList`. Check the version suffix of each Navigation 3 artifact in your catalog, because the adaptive artifacts were still in beta when this note was written ([decision 10](01-principles-and-sources.md#decisions-to-review)).
- An existing app on Navigation Compose (`org.jetbrains.androidx.navigation:navigation-compose`) stays on it. Move to Navigation 3 in a change of its own.
- Replace `PredictiveBackHandler()` with `NavigationBackHandler()`. Compose Multiplatform deprecated the first in 1.10, in favour of the Navigation Event library.
- Do not use the browser history integration of the web target (`ExperimentalBrowserHistoryApi`). It is Experimental.
- When a platform keeps its native UI, it keeps its native navigation, and only the ViewModels are shared.

### Dependency injection

- Follow [platform code](04-platform-code.md#interfaces-and-injection): constructor injection, with one DI framework (Koin by default) when a framework is needed.
- Give a ViewModel its dependencies as constructor parameters of interface type. The factory (`viewModel { }`, `koinViewModel()`) is the only place that builds the graph.

## Sources and raw notes

Pages read on 2026-11-06:

- [Multiplatform ViewModel](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html): dependencies, the reflection limit and initializers, desktop and `kotlinx-coroutines-swing`, scoping with Navigation 3, Koin and Metro, the levels of code sharing, the iOS case.
- [Navigation 3 in Compose Multiplatform](https://kotlinlang.org/docs/multiplatform/compose-navigation-3.html), [Navigation and routing](https://kotlinlang.org/docs/multiplatform/compose-navigation-routing.html) (browser history is Experimental), [Lifecycle](https://kotlinlang.org/docs/multiplatform/compose-lifecycle.html), what's new in Compose Multiplatform 1.10 (`PredictiveBackHandler()` deprecated, Navigation 3 support).
- [Recommended project structure](https://kotlinlang.org/docs/multiplatform/multiplatform-project-recommended-structure.html) (a `DrawableResource` in a model ties it to the UI module), the tutorial [Native UI: Shared logic for REST API requests](https://kotlinlang.org/docs/multiplatform/multiplatform-upgrade-app.html) (`collectAsStateWithLifecycle()` in `sharedUI/src/commonMain`).
- Library source: [`FlowExt.kt`](https://github.com/androidx/androidx/blob/androidx-main/lifecycle/lifecycle-runtime-compose/src/commonMain/kotlin/androidx/lifecycle/compose/FlowExt.kt) of `lifecycle-runtime-compose` declares `collectAsStateWithLifecycle` in `commonMain`.
- The Kotlin set: [platform practices](../kotlin-conventions/11-platform-practices.md), [coroutines and flow](../kotlin-conventions/09-coroutines-and-flow.md).
- The code block in this note was not compiled ([principles](01-principles-and-sources.md#applying-the-notes)).
