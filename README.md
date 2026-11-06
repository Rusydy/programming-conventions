# Programming Conventions

Sourced, opinionated conventions for writing **Bash, Go, Kotlin, Kotlin Multiplatform, Next.js, Python and TypeScript** code.

Each set starts from what the language, its compiler and its official tools already do. It adds configuration only where a default does not fit, and it records the reason. Where the official guides disagree, the notes say which source wins and why.

These are one developer's choices. The notes flag the places where they go beyond the official guides.

## Getting started

1. Choose the set for your language, for example [`kotlin-conventions/`](kotlin-conventions/).
2. Read its `01-principles-and-sources.md`.
3. Open the topic note for your task, for example [`09-coroutines-and-flow.md`](kotlin-conventions/09-coroutines-and-flow.md).
4. If you use Claude Code, install the rules in [`agent-rules/`](agent-rules/README.md) so that every session follows these conventions.

## Sets

| Set | Folder | What it covers |
| --- | --- | --- |
| Bash | [`bash-conventions/`](bash-conventions/) | Project setup with ShellCheck and shfmt, layout, naming and style, quoting and expansion, functions and control flow, error handling and strict mode, scripts as commands, portability across Bash versions, security, testing with bats-core, patterns and pitfalls |
| Go | [`golang-conventions/`](golang-conventions/) | Tooling, project layout, naming and style, package and API design, types, errors, concurrency and context, testing, service practices, modern Go by release |
| Kotlin | [`kotlin-conventions/`](kotlin-conventions/) | Gradle and static checks, packages, naming, idiomatic use, null safety and types, API design, errors, coroutines and Flow, testing, platform practices (Android, Compose, multiplatform, Spring), modern Kotlin by release |
| Kotlin Multiplatform | [`kmp-convention/`](kmp-convention/) | The multiplatform layer on top of the Kotlin set: project setup with the Android-KMP library plugin, module structure and source sets, `expect`/`actual` and platform code, dependencies, architecture and navigation, Compose Multiplatform, concurrency and the iOS boundary, testing and CI, modern Kotlin Multiplatform by release |
| Next.js | [`nextjs-convention/`](nextjs-convention/) | App Router projects: routing, Server and Client Components, data fetching and caching, forms, errors and loading, metadata, styling and assets, security, testing, deployment and self-hosting, version policy |
| Python | [`python-conventions/`](python-conventions/) | Tooling with uv, Ruff, mypy and pytest, project layout, naming and style, idiomatic use, types and data modeling, API and class design, errors and logging, concurrency and async, testing, security and dependencies, platform practices (scripts and Django), modern Python by release |
| TypeScript | [`typescript-convention/`](typescript-convention/) | tsconfig, types and type design, validating external data, modules, naming, functions and async code, errors, testing, TypeScript in React, modern TypeScript by release |

## How each set is organized

- `01-principles-and-sources.md` holds the rules that every project in the set follows, the order in which sources win when they disagree, how to apply the notes to existing code, and the sources the set was written from. Read it first.
- The numbered notes after it cover one topic each, in reading order. Each one has a summary, its rules, and a list of its sources.
- Where a note says it checked its examples with a tool, the note names the version it used.

## Shared ideas

Several ideas recur across the principles notes:

- **Follow the defaults.** Start from the compiler, the standard tools and the official guides. Replace a default only with a written reason.
- **Optimise for the reader.** Pick the clearest form, not the shortest or the cleverest.
- **Prefer the platform.** Use the standard library before adding a dependency, and add one only when it removes real complexity.
- **Wait for a second use case.** Do not add an abstraction, option or generic "just in case".
- **Check failures explicitly.** Handle every error, and validate input at the edges of the program.
- **Let tools check the rules.** Formatters, linters, the compiler and CI enforce what the notes say.

## Applying the notes

- **New code** follows every note in its set.
- **Existing code:** apply the notes to the lines you write or change. Leave the rest alone unless someone asks for a clean-up, so each review stays small.
- **Mechanical changes**, such as formatter runs, dependency bumps and migrations, go in their own commits.
- **Generated code** is exempt, because the next generation overwrites hand edits.
- **Repositories owned by others:** follow that repository's conventions first.

## Decisions beyond the official guides

- **Go:** [named parameters and results](golang-conventions/02-named-parameters-and-results.md) is a labelled personal override. It names every parameter and result, and the note says it deviates on purpose from the Go team's guidance on unnamed results.
- **Bash:** the [principles note](bash-conventions/01-principles-and-sources.md#decisions-to-review) lists the decisions made where the sources disagree, and the place to change each one.
- **Python:** the [principles note](python-conventions/01-principles-and-sources.md#decisions-to-review) lists twelve decisions made where the sources disagree or leave a choice open, such as an 88-column line length instead of PEP 8's 79.
- **Kotlin Multiplatform:** the [principles note](kmp-convention/01-principles-and-sources.md#decisions-to-review) lists eleven decisions, such as keeping Gradle while Kotlin Toolchain is Alpha.
Read these as one developer's choices, not as consensus.

## Versions

Version numbers in these notes are a snapshot from October 2026 (November 2026 for Kotlin Multiplatform). Each set says which versions it targets. Check the current release notes before you start a project, because version facts go stale quickly.

## Sources

Each note ends with its sources and the date they were read. The main upstream guides are:

- **Bash:** the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html), [BashGuide](https://mywiki.wooledge.org/BashGuide/Practices) and [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) from Greg's Wiki, the [Bash Reference Manual](https://www.gnu.org/software/bash/manual/), and the [Command Line Interface Guidelines](https://clig.dev/).
- **Go:** [Effective Go](https://go.dev/doc/effective_go), [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments), the [Google Go Style Guide](https://google.github.io/styleguide/go/) and the [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md).
- **Kotlin:** the [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html), the [Android Kotlin style guide](https://developer.android.com/kotlin/style-guide) and the [library authors' guidelines](https://kotlinlang.org/docs/api-guidelines-introduction.html).
- **Kotlin Multiplatform:** the [Kotlin Multiplatform documentation](https://kotlinlang.org/docs/multiplatform/get-started.html), the [Compose Multiplatform compatibility page](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html) and the [Android-KMP library plugin](https://developer.android.com/kotlin/multiplatform/plugin).
- **Next.js:** the [Next.js documentation](https://nextjs.org/docs) and the [support policy](https://nextjs.org/support-policy).
- **Python:** [PEP 8](https://peps.python.org/pep-0008/) and [PEP 257](https://peps.python.org/pep-0257/), the [Python Developer's Guide](https://devguide.python.org/versions/), and the documentation of [uv](https://docs.astral.sh/uv/), [Ruff](https://docs.astral.sh/ruff/), [mypy](https://mypy.readthedocs.io/) and [pytest](https://docs.pytest.org/).
- **TypeScript:** the [TypeScript Handbook](https://www.typescriptlang.org/docs/) and the [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html).

## Contributing

Corrections and additions are welcome. For a wrong or outdated fact, open an issue. For a change to a note:

- Cite a source for each new claim, with its URL and the date you read it.
- Keep the set's structure: principles first, then topic notes in order.
- If a note names the tool versions it was checked with, check your examples with the same versions.
- Keep each pull request to one topic.

## License

- The text in this repository (the notes, the digests in `agent-rules/`, and this README) is licensed under [CC BY 4.0](LICENSE). You may share and adapt it if you give credit.
- The code samples in the notes are licensed under the [MIT License](LICENSE-CODE).
- The notes summarise upstream guides and documentation. Those sources keep their own licenses, and any quoted material stays under them.

Copyright 2026 Rusydy.
