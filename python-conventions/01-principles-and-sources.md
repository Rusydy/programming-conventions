# Python Principles and Sources of Truth

## Summary

These principles apply to every Python project. They put the conventions of the language, of the standard library and of the Python Enhancement Proposals ahead of project-specific configuration, so that any Python programmer can read the code on the first day. A precedence list settles disagreements between sources. Where the sources disagree on a rule that matters, or leave the choice open (the Python Packaging Authority names no tool for formatting, linting or environments), the notes record a decision with its reason, and the list of decisions near the end says where to change each one.

## Rules

### Principles

1. **Follow the conventions.** The language reference, the standard library, PEP 8, PEP 257 and the typing best-practices page define the baseline. Replace one of them only with a written reason. This is "convention over configuration" applied to Python ([style](04-naming-comments-and-style.md), [tooling](02-project-setup-and-tooling.md)).
2. **Optimise for the reader.** PEP 8 starts from the insight that code is read much more often than it is written, and the Zen of Python says "Readability counts". Choose the clearest form: descriptive names, small functions, comments that explain why ([style](04-naming-comments-and-style.md), [idioms](05-idiomatic-language-use.md)).
3. **Be explicit.** "Explicit is better than implicit": annotate the public surface, pass `encoding=` to `open()`, declare the public API, name the exceptions you catch ([types](06-types-and-data-modeling.md), [API design](07-api-and-class-design.md)).
4. **Be idiomatic, and use the standard library first.** Comprehensions, `pathlib`, context managers, `dataclasses`, `argparse`, `logging` and `tomllib` before a dependency or a hand-made loop ([idioms](05-idiomatic-language-use.md), [dependencies](02-project-setup-and-tooling.md#dependencies)).
5. **Let types describe the data, and check them.** Frozen dataclasses, enums, `TypedDict` and `Protocol`, with mypy in strict mode ([types](06-types-and-data-modeling.md)).
6. **Let errors be loud and specific.** "Errors should never pass silently": raise specific exceptions, catch narrowly, translate them once at the boundary of `main`, and log with `logging`, not `print` ([errors and logging](08-error-handling-and-logging.md)).
7. **Never trust input.** Parameterised SQL, argument lists instead of shell strings, no `eval` or `pickle` on foreign data, `secrets` for tokens, and a lock file for dependencies ([security](11-security-and-dependencies.md)).
8. **Measure before adding concurrency.** Choose `asyncio`, threads or processes by the workload, with structured tools and a guard for `multiprocessing` ([concurrency](09-concurrency-and-async.md)).
9. **Test behaviour.** Small, deterministic pytest tests of what the code promises, with fakes before mocks ([testing](10-testing.md)).
10. **Declare the version and let the tools check the rules.** `requires-python` and `.python-version`, then uv, Ruff, mypy and pytest in CI, in that order ([tooling](02-project-setup-and-tooling.md#automation), [releases](13-modern-python-by-release.md)).

### Order of precedence

When two sources disagree, the lower number wins.

1. What Python does: the language and library reference of the release in use, the "What's new" pages, and the behaviour of the real interpreter (the notes were checked by running it).
2. The notes in this folder. They record each conflict between the sources and how it is settled ([style](04-naming-comments-and-style.md#where-the-guides-disagree)).
3. PEP 8 and PEP 257 for style and docstrings, and the typing best-practices page for annotations.
4. The Python Packaging Authority specifications and guides, for `pyproject.toml`, layout and publishing. The guides lag behind the tools: the tool recommendations page names no formatter, linter or environment tool, and does not mention uv or Ruff.
5. The documentation of the tools the notes adopt: uv, Ruff, mypy and pytest.
6. The documentation of a framework, for code written in it (Django: [platform note](12-platform-practices.md#django)).

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so that each review stays small, and raise the rest as a separate task.
- **Mechanical changes** (a new Ruff release, a newly enabled rule family, a Python upgrade) go in their own commits ([tooling](02-project-setup-and-tooling.md#automation)).
- **Generated code** is exempt: Django migrations are excluded from Ruff, and the other generated files get the per-file adjustments of the platform note.
- **Repositories owned by others:** follow the conventions that repository documents first.
- **Version baseline:** on 2026-10-30 the checks ran on Python 3.14.8 from Homebrew, marked as externally managed (`pip install` is refused, as the security note shows). Python 3.15 had been released on 2026-10-09 and was not installed for the checks. New projects pin the newest release that all their dependencies support, 3.14 today ([releases](13-modern-python-by-release.md#supported-releases)). The tools were the newest on PyPI that day: uv 0.13.6, Ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 and Django 6.1.2. They ran in a throwaway virtual environment created for the checks, and nothing was installed system-wide. Python 3.12.15 came from the Docker image `python:3.12-alpine`, run without network. No 3.11, 3.13 or 3.15 interpreter was available, so statements about those releases come from the "What's new" pages.
- **Examples:** the notes hold 49 `python` code blocks. 37 are complete: 34 programs and 3 pytest test modules. Each complete block was formatted by Ruff (`ruff format --check`), linted with the rule set of the tooling note (with `D`, `T20` and `S101` switched off, because the blocks are snippets), type-checked with mypy in strict mode, and run on Python 3.14.8, the test modules under pytest (5, 4 and 1 tests passed). No line of a complete block is longer than 88 characters. 32 of the 34 programs also ran on Python 3.12.15; the other two need the `demo` package of the sample project, or the syntax of Python 3.14, as their notes say. 6 blocks start with `# fragment` and were checked for syntax here: the `__main__.py` of the layout note; `src/demo/cli.py`, which is identical to the file of the sample project, where Ruff and mypy checked it and the command was run; and four Django files, copied into a generated Django 6.1.2 project and run there. 2 start with `# before`: the original function of the `unittest` example, and the legacy file of the releases note, which was also fed to Ruff for its table of target versions. 4 start with `# wrong`, show a mistake on purpose, and are flagged by Ruff or mypy. The 3 `toml` blocks were parsed with `tomllib`; the `pyproject.toml` of the tooling note was run end to end in the sample project, and the Django additions in the generated project. The 6 `bash` blocks passed `bash -n`, and the commands that need no network were run. Behaviour described as "checked" was run on Python 3.14.8 and, where the note says so, on 3.12.15.
- **Sample project:** the `demo` project of the notes (src layout, `circle.py`, `cli.py`, a test module) passed `uv sync --locked`, `ruff format --check`, `ruff check`, `mypy` and `pytest` (`5 passed`), in the order the tooling note gives. It was a scratch project.
- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/python.md](../agent-rules/rules/python.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. Its `paths` field lists globs for `.py` and `.pyi` files and for `pyproject.toml`, so Claude Code loads it when it uses Read, Write or Edit on a matching file. The digest is a manual copy: update it in the same change whenever a note here changes, and bump the sync date in its first paragraph. It stays below the 40,000 characters after which the Claude Code documentation cuts a path-scoped rule off. A Python script without an extension in `bin/` is matched by the `bin/*` glob of the Bash rule instead, and that rule sends it to the rule of its language. Because the 3.14 baseline is for new applications, the rule tells Claude to find the Python floor of an existing project before it writes code. How path-scoped rules load, their size limit and the working-directory caveat are described in the [Kotlin note](../kotlin-conventions/01-principles-and-sources.md).

### Decisions to review

These choices were made while writing the notes because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Where to change it |
| --- | --- |
| uv, Ruff, mypy in `strict` mode and pytest as the four tools, on top of the standard `pyproject.toml` | [tooling](02-project-setup-and-tooling.md) |
| New projects on Python 3.14 (`requires-python = ">=3.14"`), the release installed here, and not on 3.15 yet | [tooling](02-project-setup-and-tooling.md#python-versions), [releases](13-modern-python-by-release.md#supported-releases) |
| Explicit Ruff `select` list of 18 rule families, including `D` (docstrings) and `S` (security) | [tooling](02-project-setup-and-tooling.md#ruff) |
| Line length 88 instead of the 79 of PEP 8 | [style](04-naming-comments-and-style.md#where-the-guides-disagree) |
| Google docstring sections (`convention = "google"`) | [style](04-naming-comments-and-style.md#where-the-guides-disagree) |
| Absolute imports only | [style](04-naming-comments-and-style.md#where-the-guides-disagree) |
| Built-in generics and `X \| None` instead of `typing.List` and `Optional` | [style](04-naming-comments-and-style.md#where-the-guides-disagree), [types](06-types-and-data-modeling.md) |
| `%s` arguments in logging calls instead of f-strings | [logging](08-error-handling-and-logging.md#logging) |
| Keep what `ruff format` writes for `except A, B:` and set `requires-python` to match | [style](04-naming-comments-and-style.md#where-the-guides-disagree) |
| src layout, with the tests outside the package | [layout](03-project-layout-and-packages.md#layout) |
| pytest for tests, but Django's own runner in a Django project | [testing](10-testing.md), [Django](12-platform-practices.md#django) |
| A custom user model from the start of a Django project, and Ruff and mypy adjusted for generated code | [Django](12-platform-practices.md#django) |

### Notes in this folder

| Note | Content |
| --- | --- |
| [02 Project setup and tooling](02-project-setup-and-tooling.md) | Python versions, `pyproject.toml`, uv, dependencies, Ruff, mypy, pytest, CI order |
| [03 Project layout and packages](03-project-layout-and-packages.md) | The src layout, modules, public API, entry points, single-file scripts |
| [04 Naming, comments and style](04-naming-comments-and-style.md) | Formatting, names, imports, docstrings, comments, where the guides disagree |
| [05 Idiomatic language use](05-idiomatic-language-use.md) | Truthiness, EAFP, comprehensions, loops, files, functions, context managers, modern syntax, mistake table |
| [06 Types and data modeling](06-types-and-data-modeling.md) | Annotating the public surface, mypy errors, dataclasses, enums, protocols, generics |
| [07 API and class design](07-api-and-class-design.md) | Function signatures, classes, public and internal names, dependencies, changing an API |
| [08 Error handling and logging](08-error-handling-and-logging.md) | Raising, catching, exception groups, logging, exit status |
| [09 Concurrency and async](09-concurrency-and-async.md) | Choosing a model, executors, asyncio, threads, processes, subprocess |
| [10 Testing](10-testing.md) | pytest layout, assertions, fixtures, test doubles, markers, async tests |
| [11 Security and dependencies](11-security-and-dependencies.md) | Injection, secrets, temporary files, assertions, the lock file |
| [12 Platform practices](12-platform-practices.md) | Command-line programs, Django |
| [13 Releases and modern Python](13-modern-python-by-release.md) | Supported releases, features by release, what fails on older ones, Ruff as upgrade tool, upgrade checklist |

## Sources and raw notes

Pages read on 2026-10-30:

- [PEP 8](https://peps.python.org/pep-0008/) (read in full), [PEP 257](https://peps.python.org/pep-0257/), and PEP 20, the Zen of Python, as printed by `python3 -c "import this"`.
- [Typing best practices](https://typing.python.org/en/latest/reference/best_practices.html).
- Python Packaging User Guide: [Tool recommendations](https://packaging.python.org/en/latest/guides/tool-recommendations/), [Writing your pyproject.toml](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/), [src layout vs flat layout](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/), [Dependency Groups](https://packaging.python.org/en/latest/specifications/dependency-groups/) and [Inline script metadata](https://packaging.python.org/en/latest/specifications/inline-script-metadata/).
- Python Developer's Guide: [Status of Python versions](https://devguide.python.org/versions/). Python documentation: the "What's new" pages for [3.10](https://docs.python.org/3/whatsnew/3.10.html) to [3.15](https://docs.python.org/3/whatsnew/3.15.html), the [Logging HOWTO](https://docs.python.org/3/howto/logging.html) and [Python support for free threading](https://docs.python.org/3/howto/free-threading-python.html).
- Version checks: `python3 --version` (3.14.8 from Homebrew, with the `EXTERNALLY-MANAGED` marker), `docker run python:3.12-alpine` (3.12.15), and the versions of the tools in the throwaway virtual environment listed above.
- Each of the other notes lists the pages it was written from.
- The equivalents of this set for other languages: [golang-conventions](../golang-conventions/01-principles-and-sources.md), [kotlin-conventions](../kotlin-conventions/01-principles-and-sources.md) and [bash-conventions](../bash-conventions/01-principles-and-sources.md).
