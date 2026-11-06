# Kotlin Project Layout and Packages

## Summary

Follow the default source layout, name files after what they contain, group code by feature or responsibility, and let the Gradle module be the unit of encapsulation. Start with few modules and split along natural boundaries. In multiplatform projects use the default hierarchy template and put platform access behind interfaces.

## Rules

### Source roots and directories

- Keep Kotlin sources in `src/<source set>/kotlin`: `src/main/kotlin` and `src/test/kotlin`, or `src/commonMain/kotlin` and `src/commonTest/kotlin` in a multiplatform module. Kotlin does not compile `.java` files in a `src/*/kotlin` directory, so put Java sources in `src/main/java`.
- In a pure Kotlin module, JetBrains recommends that the directories follow the packages **without the common root package**. If all code is in `org.example.kotlin` and its subpackages, files of `org.example.kotlin` sit directly in the source root, and files of `org.example.kotlin.network.socket` are in `network/socket`. A module that already uses the full package path may keep it. Use one of the two layouts per module and do not mix them.
- In a module that mixes Kotlin and Java, use the Java layout: Kotlin files sit in the same source root as the Java files, and each file is in the directory that matches its `package` statement.
- Do not put source files in the root project of a Gradle build. Give the code a module of its own.
- Keep one `settings.gradle.kts`, one version catalog and one `build-logic` included build per repository ([tooling](02-project-setup-and-tooling.md#gradle-build)).

```text
project/
├── build-logic/                  convention plugins (included build)
├── gradle/libs.versions.toml     version catalog
├── gradle.properties
├── settings.gradle.kts
├── app/                          :app
│   └── src/main/kotlin/…
├── feature/news/                 :feature:news
│   └── src/{main,test}/kotlin/…
└── shared/                       Kotlin Multiplatform module
    └── src/{commonMain,commonTest,androidMain,iosMain}/kotlin/…
```

### File names and contents

- Name a file with a single class or interface after it (`PaymentProcessor.kt`), including its related top-level declarations. Name a file with several classes, or with only top-level declarations, after what it contains, in PascalCase: `ProcessDeclarations.kt`. ktlint's `filename` rule enforces both.
- Do not use empty words such as `Util` in a file name. The name describes what the code does.
- Put several declarations in one file when they are closely related and the file stays reasonable, a few hundred lines at most. Keep the contents of a file on one theme: one public type, or one set of extensions for the same operation.
- Put an extension function that every client of a class needs in the file of that class. Put one that only one client needs next to that client. Do not create a file only to hold all extensions of a class.
- In a multiplatform project, give a file with top-level declarations in a platform source set the name of that source set as a suffix: `Platform.jvm.kt`, `Platform.android.kt`, `Platform.ios.kt`. The common file has no suffix: `Platform.kt`. Without it, two `Platform.kt` files in the same package produce the same JVM file facade (`PlatformKt`) and the build fails with "Duplicate JVM classes".
- Order a file as in the [style note](04-naming-comments-and-style.md#formatting): licence header, `@file:` annotations, `package`, imports, declarations.

### Order inside a class

- Order the contents of a class as follows: property declarations and initialiser blocks, secondary constructors, methods, companion object.
- Do not sort methods alphabetically or by visibility, and do not separate ordinary methods from extension methods. Keep related members together so that a reader can follow the logic from top to bottom. Pick one direction (high-level first, or the reverse) and keep it. A new function does not go to the end of the file by habit; that would order the file by the date of the change.
- Put a nested class next to the code that uses it. If it is meant for external use and nothing inside the class refers to it, put it at the end, after the companion object.
- When a class implements an interface, keep the implementing members in the order of the interface. Keep overloads next to each other.

### Packages and modules

- Name a package in lower case without underscores and prefer one word: `org.example.project`. If you need several words, join them (`deepspace`). JetBrains also accepts camel case (`myProject`), but the Android guide marks it as wrong, so do not use it.
- Group code by feature or responsibility, not by technical layer for the whole app. Gradle lists vertical slices (feature modules that contain UI and business logic) among the splits that give cohesive projects, and Android uses feature modules such as `:feature:news`. In a small Android app, `data` and `ui` packages (or modules) are enough.
- Choose the granularity of modules on purpose. Gradle advises splitting the build along natural boundaries from the start and erring towards more projects than fewer. Android warns about three pitfalls: modules that are too fine-grained (build overhead and boilerplate), too coarse (another monolith) and modularisation that a small codebase does not need. Merge modules when the overhead outweighs the gain.
- Treat the module as the boundary of encapsulation. Mark everything except the public interface of a module `internal` or `private`. `internal` means visible within the same module; the `test` source set can see the `internal` declarations of `main`.
- Do not create dumping grounds. Packages and files called `util`, `common` or `helpers` say nothing about their contents.

### Multiplatform source sets

- Set up the source set hierarchy with the **default hierarchy template** of the Kotlin Gradle plugin, which creates the intermediate source sets (for example `iosMain`) from the targets you declare. Configure the hierarchy manually only for an advanced project.
- A source set sees only the APIs that exist for all its targets. Code in `commonMain` can therefore compile for every target.
- Reach platform APIs from common code through a regular interface in `commonMain` with a platform implementation in the platform source set, wired up by dependency injection or a factory function. This keeps fakes easy in tests and does not limit you to one implementation per platform.
- Use `expect`/`actual` for small things such as a factory function. Expected and actual classes are in Beta, so avoid them where an interface does the job. If you do use them, the compiler warns until you add `-Xexpect-actual-classes`.

## Sources and raw notes

Pages read on 2026-10-22:

- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html): directory structure, source file names, source file organisation, class layout, naming of packages, multiplatform file names.
- [Configure a Gradle project](https://kotlinlang.org/docs/gradle-configure-project.html): `src/*/kotlin` and `src/main/java`.
- [Visibility modifiers](https://kotlinlang.org/docs/visibility-modifiers.html): `internal` and modules.
- Gradle best practices: [structuring builds](https://docs.gradle.org/current/userguide/best_practices_structuring_builds.html) (modularise, no sources in the root project, `build-logic`).
- [Guide to Android app modularization](https://developer.android.com/topic/modularization) (last updated 2026-03-05) and [Recommendations for Android architecture](https://developer.android.com/topic/architecture/recommendations) (small apps, `data` and `ui` packages).
- [Android Kotlin style guide](https://developer.android.com/kotlin/style-guide): file naming, ordering of members.
- Kotlin Multiplatform: [Source set hierarchy](https://kotlinlang.org/docs/multiplatform/multiplatform-hierarchy.html), [Expected and actual declarations](https://kotlinlang.org/docs/multiplatform/multiplatform-expect-actual.html), [Test your multiplatform app](https://kotlinlang.org/docs/multiplatform/multiplatform-run-tests.html).
- ktlint [standard rules](https://ktlint.github.io/ktlint/latest/rules/standard/): `filename`. The messages of that rule were also seen in a run of ktlint 1.8.0 on 2026-10-22.
