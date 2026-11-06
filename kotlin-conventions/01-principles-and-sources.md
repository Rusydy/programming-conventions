# Kotlin Principles and Sources of Truth

## Summary

These principles apply to every Kotlin project. They put the conventions of the language and its toolchain ahead of project-specific configuration, so that any Kotlin developer can read the code on the first day. A precedence list settles disagreements between sources. No personal override is recorded: where the sources leave a choice open, the notes pick the option that needs the least configuration and say so.

## Rules

### Principles

1. **Follow the conventions.** The Kotlin coding conventions, the compiler and a formatter define the baseline. Replace one of them only with a written reason. This is "convention over configuration" applied to Kotlin ([style](04-naming-comments-and-style.md), [tooling](02-project-setup-and-tooling.md)).
2. **Optimise for the reader.** Choose the clearest form, not the shortest. The Android guide says its primary goal for line wrapping is clear code, and the library guidelines open with minimising the mental effort needed to read and use an API.
3. **Prefer immutable values and expressions.** Use `val`, read-only collections, `data class` with `copy()`, and `if`, `when` and `try` as expressions ([idioms](05-idiomatic-language-use.md)).
4. **Let the type system carry the rules.** Non-null by default, `sealed` hierarchies with exhaustive `when`, value classes for identifiers, explicit backing fields for encapsulation ([null safety and types](06-null-safety-and-types.md)).
5. **Reuse before you add.** Prefer the standard library and the official kotlinx libraries (`kotlin.time.Duration`, `Clock`, `Uuid`, kotlinx.coroutines, kotlinx.serialization). Add a dependency only when it removes real complexity, and say why in the pull request.
6. **Fail fast and say why.** Validate with `require`, `check` and `error`, use one error mechanism per module, and put the offending input in the message ([error handling](08-error-handling.md)).
7. **Own every coroutine.** Each coroutine has a scope, an injected dispatcher and a cancellation path, and nobody swallows `CancellationException` ([coroutines and flow](09-coroutines-and-flow.md)).
8. **Pass dependencies in.** Use constructor injection, and inject the clock and the dispatchers. No mutable global state ([API and class design](07-api-and-class-design.md)).
9. **Be explicit at the boundaries.** Declare the types of public API and of values from Java, and make visibility deliberate. Libraries turn on explicit API mode.
10. **Use stable features.** Experimental means "try it only in toy projects". Prefer the modern stable form of an idiom ([modern Kotlin by release](12-modern-kotlin-by-release.md)).

### Order of precedence

When two sources disagree, the lower number wins.

1. The Kotlin language specification, the documented behaviour of the standard library, and what the compiler accepts and warns about.
2. The notes in this folder. They record each conflict between the guides and how it is settled ([style](04-naming-comments-and-style.md#where-the-guides-disagree)).
3. The Kotlin team's guidance: the coding conventions, the language documentation and idioms, the library authors' guidelines (for code that other projects depend on) and the kotlinx.coroutines documentation.
4. Platform guidance, for code that targets that platform: the Android Kotlin style guide, the Android architecture and Compose documentation, the Compose API guidelines, the Kotlin Multiplatform documentation and the Spring Kotlin documentation. This guidance covers things the Kotlin team's guidance does not (architecture, Compose, lifecycle) and is stricter on a few style points.
5. Tool defaults: ktlint and detekt. Adopt a rule of a tool only when a note names it.

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so that each review stays small, and raise the rest as a separate task.
- **Mechanical changes** (formatter upgrades, dependency bumps, Kotlin upgrades and their migrations) go in their own commits.
- **Generated code** is exempt, for example KSP and kapt output, generated API clients and protobuf classes. The next build overwrites hand edits. Keep it out of the lint run ([tooling](02-project-setup-and-tooling.md#formatting-and-static-checks)).
- **Repositories owned by others:** follow the conventions that repository documents first.
- **Version baseline:** start new projects on the latest stable Kotlin, 2.4.21 (released 2026-10-08), with Gradle and AGP inside the supported range of that plugin. Existing projects move on purpose, with the [upgrade checklist](12-modern-kotlin-by-release.md#upgrade-checklist): when a project needs a stable feature of a newer release, or when its build is being touched anyway, in a commit of its own. There is no bulk migration.
- **Examples:** every code block in these notes was compiled with Kotlin 2.4.21 and checked with ktlint 1.8.0, unless the block starts with a `// fragment` comment. Fragments need libraries that were not on the compile classpath (Compose, Spring, Gradle).
- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/kotlin.md](../agent-rules/rules/kotlin.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. Its `paths` field lists globs for `.kt`, `.kts` and `libs.versions.toml` files, so Claude Code loads it when it uses Read, Write or Edit on a matching file. The digest is a manual copy, so update it in the same change whenever a note here changes. The Claude Code documentation cuts a path-scoped rule off after 40,000 characters in a session with a 200K context window; the digest is far below that. A path-scoped rule loads only when a matching file is touched, so in a brand-new project it arrives with the first `.kt` or `.kts` file that is read or edited; to load it earlier, ask Claude to read the digest or remove the `paths` field. The patterns are relative to the primary working directory of the session, so files outside that directory may not match.

### Notes in this folder

| Note | Content |
| --- | --- |
| [02 Project setup and tooling](02-project-setup-and-tooling.md) | Gradle, versions, compiler options, AGP 9, ktlint, detekt, CI order |
| [03 Project layout and packages](03-project-layout-and-packages.md) | Source roots, file names, class order, modules, multiplatform source sets |
| [04 Naming, comments and style](04-naming-comments-and-style.md) | Formatting, names, KDoc, where the style guides disagree |
| [05 Idiomatic language use](05-idiomatic-language-use.md) | Immutability, expressions, functions, collections, scope functions |
| [06 Null safety and types](06-null-safety-and-types.md) | Nullability, sealed types, data and value classes, visibility |
| [07 API and class design](07-api-and-class-design.md) | Parameters, dependencies, DSLs, context parameters, library rules |
| [08 Error handling](08-error-handling.md) | Preconditions, exceptions, results, cancellation |
| [09 Coroutines and flow](09-coroutines-and-flow.md) | Scopes, dispatchers, cancellation, Flow, StateFlow |
| [10 Testing](10-testing.md) | kotlin.test, fakes, runTest, Turbine |
| [11 Platform practices](11-platform-practices.md) | Android and Compose, multiplatform, Spring |
| [12 Modern Kotlin by release](12-modern-kotlin-by-release.md) | Features by release from 1.4 to 2.4, upgrade checklist |

## Sources and raw notes

Pages read on 2026-10-22:

- [Kotlin language specification](https://kotlinlang.org/spec/introduction.html).
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html), [Idioms](https://kotlinlang.org/docs/idioms.html) and [Library authors' guidelines](https://kotlinlang.org/docs/api-guidelines-introduction.html).
- [Kotlin evolution principles](https://kotlinlang.org/docs/kotlin-evolution-principles.html) and [Stability of Kotlin components](https://kotlinlang.org/docs/components-stability.html) (the meaning of Experimental, Alpha, Beta and Stable).
- [Kotlin release process](https://kotlinlang.org/docs/releases.html) (latest release, release dates, support window).
- [Android Kotlin style guide](https://developer.android.com/kotlin/style-guide), [Recommendations for Android architecture](https://developer.android.com/topic/architecture/recommendations) and the [API Guidelines for Jetpack Compose](https://github.com/androidx/androidx/blob/androidx-main/compose/docs/compose-api-guidelines.md).
- ktlint [code styles](https://ktlint.github.io/ktlint/latest/rules/code-styles/) and detekt [introduction](https://detekt.dev/docs/intro).
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) (Claude Code documentation, read on 2026-10-23): `.claude/rules/`, the `paths` frontmatter, when a path-scoped rule loads, user-level rules and the size limit for on-demand rules.
- Each of the other notes lists the pages it was written from. The compiler (Kotlin 2.4.21), ktlint (1.8.0) and the test libraries used to check the examples were downloaded from their official release locations on 2026-10-22 and verified against the published SHA-256 checksum (Kotlin compiler), the PGP signature (ktlint) or the Maven Central SHA-1 files (Turbine, JUnit).
- The Go equivalent of this set is in [golang-conventions](../golang-conventions/01-principles-and-sources.md).
