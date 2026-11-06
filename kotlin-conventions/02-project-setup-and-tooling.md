# Kotlin Project Setup and Tooling

## Summary

Every Kotlin project uses the same small toolchain: Gradle with the Kotlin DSL and a version catalog, a pinned JDK, the Kotlin compiler with warnings treated as errors, ktlint for formatting and style, tests on `kotlin.test`, and optionally detekt. They run in CI in one order. The configuration stays short because the defaults are the convention.

## Rules

### Versions and compatibility

- Start new projects on the latest stable Kotlin: 2.4.21 (released 2026-10-08). Kotlin ships a language release every six months (2.x.0), a tooling release three months later (2.x.20) and bug fix releases (2.x.yz). Update the Kotlin version in one place, the version catalog ([modern Kotlin by release](12-modern-kotlin-by-release.md) lists what each release adds).
- Check the Kotlin Gradle plugin (KGP) against the versions of Gradle and the Android Gradle plugin (AGP) before you upgrade. For KGP 2.4.20 to 2.4.21 the fully supported ranges are Gradle 7.6.3 to 9.7.0 and AGP 8.5.2 to 9.3.1.
- Keep Gradle on the latest minor version of its current major release, through the wrapper: `./gradlew :wrapper --gradle-version <version>`. Only the latest minor of the current and the previous major release is supported.
- Since Kotlin 2.4.0 the standard library for the JVM has an 18-month support window per release line. The published table lists the 2.4 line only (released 2026-06-03, supported until 2027-12-03). Plan upgrades of older projects with that in mind.
- Do not use Experimental or Alpha language features or libraries in production code. Opt in to an experimental API only for a reason you can write down, and propagate the requirement if you publish a library ([API design](07-api-and-class-design.md#libraries)).

### Gradle build

- Write build files in the Kotlin DSL (`build.gradle.kts`, `settings.gradle.kts`). Apply plugins in the `plugins {}` block.
- Declare dependency versions once, in the version catalog `gradle/libs.versions.toml`. A catalog fixes declared versions only; use dependency locking or alignment when resolved versions matter.
- Declare repositories in `settings.gradle.kts` (`dependencyResolutionManagement`), not in every project.
- Do not add `kotlin-stdlib` by hand. The Kotlin plugin adds the version that matches itself.
- Put shared build configuration in convention plugins, in an included build named `build-logic`, and not in `buildSrc`. Do not copy the same block into many build files.
- Split the code into several Gradle modules along natural boundaries from the start (API and implementation, feature slices, core and UI). Do not wait for the build to get slow.
- Put build flags (`org.gradle.*` properties and others) in the `gradle.properties` file of the root project and commit it. Do not rely on command-line flags.
- Pin the JDK with a toolchain: `kotlin { jvmToolchain(<LTS version>) }`. It also sets `jvmTarget` and the toolchain of Java compile, test and javadoc tasks. Gradle can detect or download that JDK.
- Add `kotlin.code.style=official` to `gradle.properties` so that the IDE uses the Kotlin style guide for every developer.

### Android Gradle plugin 9

- AGP 9.0 has built-in Kotlin support and enables it by default. Remove the `org.jetbrains.kotlin.android` plugin from module and top-level build files, and from the version catalog. AGP 9 fails the build if the plugin stays.
- Move `android.kotlinOptions {}` to `kotlin.compilerOptions {}`.
- `kapt` does not work with built-in Kotlin. Migrate to KSP. If you cannot yet, use `com.android.legacy-kapt` at the version of AGP.
- A Kotlin Multiplatform library module still applies `org.jetbrains.kotlin.multiplatform`, together with `com.android.kotlin.multiplatform.library` for the Android target. The Kotlin multiplatform plugin may no longer be combined with `com.android.library` or `com.android.application` when built-in Kotlin is on.

### Annotation processing

- Use KSP, not kapt, whenever the library supports it. The Android documentation recommends migrating from kapt to KSP, and kapt does not work with built-in Kotlin in AGP 9. KSP's API hides compiler changes, so processors need less maintenance.

### Compiler settings

- Treat warnings as errors, at least in CI: `allWarningsAsErrors`. Add `extraWarnings` (Kotlin 2.1 and later) for the additional declaration, expression and type checks.
- Opt in to an API for a whole module with the `optIn` compiler option and not with a `@Suppress` or a repeated `@OptIn`.
- Use the typed `compilerOptions {}` properties. The Kotlin documentation plans to deprecate `freeCompilerArgs`, so use it only for options that have no property yet.
- Leave `languageVersion` and `apiVersion` at their defaults in applications. Set them (to the same value) in libraries only.

```kotlin
// fragment
kotlin {
    jvmToolchain(21)
    compilerOptions {
        allWarningsAsErrors.set(true)
        extraWarnings.set(true)
    }
}
```

### Formatting and static checks

- Configure the IDE once: set the code style scheme **Kotlin style guide** and switch on the **Incorrect formatting** inspection. Commit `.idea/codeStyle`, or set `kotlin.code.style=official`.
- Check style in CI with ktlint, which is a linter and a formatter in one tool and aims to capture the Kotlin coding conventions and the Android style guide. Commit an `.editorconfig` and pin the ktlint version.
- Use the `intellij_idea` code style in every project. It is based on the Kotlin coding conventions and aims to be compatible with the default formatter of IntelliJ IDEA. With the Kotlin style guide scheme (or `kotlin.code.style=official`) set in the IDE, format-on-save and ktlint agree. The default `ktlint_official` style is stricter, and ktlint advises switching the editor's formatter off when you use it. Set `max_line_length` to 100 ([style](04-naming-comments-and-style.md#formatting)).
- Disable wildcard imports completely. ktlint's `no-wildcard-imports` rule still allows `java.util.*` unless `ij_kotlin_packages_to_use_import_on_demand` is set explicitly. The three `ij_kotlin_` settings below also stop IntelliJ from creating star imports.
- Pin ktlint to the latest stable release: 1.8.0 (2025-11-14) on 2026-10-22. A 2.0 alpha series exists (2.0.0-ALPHA-4, 2026-08-21) with new Maven coordinates (`io.github.ktlint.core`); do not use it for production builds yet.
- Exclude generated code from the checks, for example `ktlint 'src/**/*.kt' '!src/**/generated/**'` or `ktlint = disabled` for the generated folder in `.editorconfig`.
- detekt is optional. If you add it, check its compatibility table first: on 2026-10-22 the newest stable release (1.23.8, 2025-02-21) was built with Kotlin 2.0.21, and only the 2.0 alpha line (2.0.0-alpha.6, built with Kotlin 2.4.10, plugin id `dev.detekt`) tracks Kotlin 2.4. Use `buildUponDefaultConfig` and a baseline file for a legacy codebase, and note that many rules need type resolution.

```ini
root = true

[*]
insert_final_newline = true

[{*.kt,*.kts}]
max_line_length = 100
ktlint_code_style = intellij_idea
ij_kotlin_code_style_defaults = KOTLIN_OFFICIAL

# Disable wildcard imports entirely
ij_kotlin_name_count_to_use_star_import = 2147483647
ij_kotlin_name_count_to_use_star_import_for_members = 2147483647
ij_kotlin_packages_to_use_import_on_demand = unset
```

### Automation

- Put plain commands in CI. A wrapper script is optional and only repeats them.
- Run these checks in this order, locally and in CI. `ktlint` with no arguments checks every `.kt` and `.kts` file below the current directory and exits non-zero on a violation; `ktlint --format` fixes what it can.

```bash
ktlint
./gradlew check
```

- `./gradlew check` runs the tests, the ABI check of a library (`checkKotlinAbi`) and detekt when they are configured.
- Commit mechanical changes (formatting after a ktlint upgrade, dependency bumps, migrations) separately from behaviour changes.

## Sources and raw notes

Pages read on 2026-10-22:

- Kotlin: [Configure a Gradle project](https://kotlinlang.org/docs/gradle-configure-project.html) (compatibility table, toolchains), [Compiler options in the Kotlin Gradle plugin](https://kotlinlang.org/docs/gradle-compiler-options.html), [Migrate to Kotlin code style](https://kotlinlang.org/docs/code-style-migration-guide.html), [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html), [Kotlin release process](https://kotlinlang.org/docs/releases.html) (release process, support window, release history), [Opt-in requirements](https://kotlinlang.org/docs/opt-in-requirements.html), [KSP overview](https://kotlinlang.org/docs/ksp-overview.html), [What's new in Kotlin 2.1](https://kotlinlang.org/docs/whatsnew21.html) (`extraWarnings`), [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html).
- Gradle best practices (documentation for Gradle 9.8.2): [index](https://docs.gradle.org/current/userguide/best_practices_index.html), [general](https://docs.gradle.org/current/userguide/best_practices_general.html), [structuring builds](https://docs.gradle.org/current/userguide/best_practices_structuring_builds.html), [dependencies](https://docs.gradle.org/current/userguide/best_practices_dependencies.html).
- [Migrate to built-in Kotlin](https://developer.android.com/build/migrate-to-built-in-kotlin) (Android Gradle plugin 9.0).
- ktlint: [introduction](https://ktlint.github.io/ktlint/latest/), [code styles](https://ktlint.github.io/ktlint/latest/rules/code-styles/), [`.editorconfig` configuration](https://ktlint.github.io/ktlint/latest/rules/configuration-ktlint/), [IntelliJ IDEA configuration](https://ktlint.github.io/ktlint/latest/rules/configuration-intellij-idea/), [command line](https://ktlint.github.io/ktlint/latest/install/cli/), [FAQ](https://ktlint.github.io/ktlint/latest/faq/), [releases](https://github.com/ktlint/ktlint/releases).
- detekt: [introduction](https://detekt.dev/docs/intro), [compatibility table](https://detekt.dev/docs/introduction/compatibility/), [configurations](https://detekt.dev/docs/introduction/configurations/), [baseline](https://detekt.dev/docs/introduction/baseline/), [releases](https://github.com/detekt/detekt/releases).
- The installed Kotlin Gradle plugin version was read from the Gradle cache in `~/.gradle` on 2026-10-22.
