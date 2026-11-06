# Python Project Setup and Tooling

## Summary

Every Python project describes itself in one `pyproject.toml` and uses the same four tools: uv for the interpreter, the environment and the lock file; Ruff for formatting and linting; mypy in strict mode for types; and pytest for tests. CI runs them as plain commands in that order. The Python Packaging Authority purposely makes no blanket recommendation for most of these jobs, so the choice of these four tools is a recorded decision ([principles](01-principles-and-sources.md#decisions-to-review)); the file format underneath is the standard one, so any other tool can read it.

## Rules

### Python versions

- On 2026-10-30 the supported releases were 3.11, 3.12 and 3.13 (security fixes only), 3.14 and 3.15 (bugfix phase). End of life: 3.11 in 2027-10, 3.12 in 2028-10, 3.13 in 2029-10, 3.14 in 2030-10, 3.15 in 2031-10. Python 3.15 was first released on 2026-10-09; 3.10 reached end of life on 2026-10-01 and 3.9 on 2025-10-31 (Python Developer's Guide). Never start a project on an end-of-life release.
- An application pins its interpreter with a `.python-version` file and `requires-python`, on the newest release that all its dependencies support. Today that is 3.14. Move to 3.15 when the dependencies support it, in a change of its own ([modern Python](13-modern-python-by-release.md#upgrade-checklist)).
- A library sets `requires-python` to the oldest release it tests (3.11 today), runs its tests on every supported release, and raises the minimum only when a release reaches end of life. The classifiers do not restrict installation; `requires-python` does (PyPA guide).
- Install interpreters with uv (`uv python install 3.14`), or with any other method. Never use the system Python for a project, and never `pip install` into it: recent Debian, Ubuntu and Fedora refuse it (PEP 668), and `--break-system-packages` can break the tools of the operating system. Create a virtual environment instead (pytest documentation).

### pyproject.toml

- One `pyproject.toml` at the project root describes the project and configures the tools. `[build-system]` is always present. `[project]` holds the metadata; do not use `setup.py` or `setup.cfg` in new projects, and never call `setup.py` directly (PyPA guide).
- `dependencies` lists runtime dependencies only. Tools for development go in `[dependency-groups]` (PEP 735): they are not part of the built package metadata, and they suit linting, testing and projects that are not distributed. Extras (`[project.optional-dependencies]`) are for optional features of a distributed package.
- `[project.scripts]` installs a command: `demo = "demo.cli:main"` runs the equivalent of `sys.exit(main())`.
- `uv_build` is the build backend that `uv init` writes. Hatchling, setuptools, flit-core and others are equally valid; a published package that declares a licence uses the SPDX expression in `license` and `license-files` (PEP 639).
- This file was run end to end with uv 0.13.6, Ruff 0.17.3, mypy 2.4.1 and pytest 9.2.0 on Python 3.14.8:

```toml
[project]
name = "demo"
version = "0.1.0"
description = "Example project that follows the Python conventions."
readme = "README.md"
requires-python = ">=3.14"
dependencies = []

[project.scripts]
demo = "demo.cli:main"

[dependency-groups]
dev = ["mypy", "pytest", "ruff"]

[build-system]
requires = ["uv_build>=0.13.6,<0.14.0"]
build-backend = "uv_build"

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "F",    # Pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "A",    # flake8-builtins
    "C4",   # flake8-comprehensions
    "SIM",  # flake8-simplify
    "PTH",  # flake8-use-pathlib
    "RET",  # flake8-return
    "S",    # flake8-bandit
    "DTZ",  # flake8-datetimez
    "G",    # flake8-logging-format
    "T20",  # flake8-print
    "PT",   # flake8-pytest-style
    "D",    # pydocstyle
    "RUF",  # Ruff-specific rules
]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["D", "S101"]
"src/*/cli.py" = ["T20"]

[tool.mypy]
strict = true
files = ["src", "tests"]

[tool.pytest]
addopts = ["--import-mode=importlib", "--strict-markers", "--strict-config"]
testpaths = ["tests"]
```

### uv

- `uv init` creates `pyproject.toml`, `.python-version`, `README.md`, `.gitignore` and `src/<name>/__init__.py` (checked with uv 0.13.6: the same layout for the default, `--app`, `--package` and `--lib`; `--lib` adds `py.typed`). `uv sync` creates `.venv` and `uv.lock` and installs the dependencies and the `dev` group.
- Commit `pyproject.toml`, `uv.lock` and `.python-version`; ignore `.venv`. `uv.lock` is a cross-platform lock file with the exact resolved versions; it is managed by uv and not edited by hand (uv documentation).
- Day-to-day commands:

```bash
uv add httpx                  # add a runtime dependency (edits pyproject.toml and uv.lock)
uv add --dev pytest           # add to the dev dependency group
uv remove httpx               # remove a dependency
uv lock --upgrade-package httpx   # upgrade one package, keep the rest of the lock
uv run pytest                 # lock and sync, then run a command in the project environment
uv run python -m demo         # run the package
uv build                      # build the sdist and the wheel into dist/
```

- `uv run` locks and syncs before every command, so the environment always matches the project. uv does not treat the lock file as outdated when new package versions appear; upgrade on purpose. In CI use `uv sync --locked` (an error if `uv.lock` is out of date) or `uv lock --check`; `--frozen` uses the lock without checking it.
- A single-file script declares its own dependencies in a PEP 723 comment block, and `uv run --script` runs it ([layout](03-project-layout-and-packages.md#single-file-scripts)).

### Dependencies

- Declare direct dependencies only, and import only what you declare. An application pins everything through `uv.lock`; a library gives lower bounds in `pyproject.toml` and adds an upper bound only for a known incompatibility.
- No `requirements.txt` in a new project. If a tool needs one, export it from the lock file instead of maintaining a second list.
- Update dependencies on purpose: one upgrade per commit, with the tests run. Do not add a dependency that the standard library already covers (`pathlib`, `dataclasses`, `argparse`, `logging`, `tomllib`, `zoneinfo`).

### Ruff

- Ruff formats and lints. Do not add Black, isort, flake8 or pyupgrade next to it: the Ruff formatter is a drop-in replacement for Black (more than 99.9% of the lines of Django and Zulip come out identical), and the rule families below replace the others.
- Do not set what is already the default: line length 88, double quotes, space indentation, magic trailing comma. The target Python version is read from `requires-python`.
- The rule set is explicit, as the Ruff documentation advises (prefer `select` to `extend-select`; use `ALL` with discretion, because an upgrade then enables new rules). Each family has a reason in these notes:

| Family | Why |
| --- | --- |
| `E`, `F` | PEP 8 style errors and Pyflakes: the starting point the Ruff documentation suggests |
| `I` | PEP 8 import order: standard library, third party, local ([style](04-naming-comments-and-style.md#imports)) |
| `N` | PEP 8 naming ([style](04-naming-comments-and-style.md#naming)) |
| `UP` | Modern syntax: `X \| None`, built-in generics, the newest idiom of the target version ([types](06-types-and-data-modeling.md)) |
| `B` | Bugbear: mutable defaults (B006), `raise ... from` (B904), `zip(strict=)` (B905) |
| `A` | Names that shadow builtins |
| `C4`, `SIM`, `RET` | Comprehensions, simplifications and consistent returns (PEP 8) |
| `PTH` | `pathlib` instead of `os.path` and `open()` |
| `S` | Bandit security rules: `pickle`, `eval`, `subprocess` with a shell, weak randomness, `mktemp`, `assert` ([security](11-security-and-dependencies.md)) |
| `DTZ` | Naive datetimes |
| `G` | Lazy `%`-style arguments in logging calls ([errors and logging](08-error-handling-and-logging.md#logging)) |
| `T20` | No `print()` in library code |
| `PT` | pytest style |
| `D` | PEP 257 docstrings, with the `google` convention ([style](04-naming-comments-and-style.md#docstrings)) |
| `RUF` | Ruff-specific rules: mutable class attributes (RUF012), stale `noqa` (RUF100) |

- Do not enable `COM812` or `ISC001`: they conflict with the formatter.
- Fix a finding rather than silence it. A suppression is `# noqa: <code>` on the line, with the rule code and a reason; Ruff reports stale ones as RUF100. Tests ignore `D` and `S101` (assert), and the command-line module ignores `T20` (print), as in the file above.
- `ruff format` rewrites `except (ValueError, TypeError):` to `except ValueError, TypeError:` when `requires-python` is 3.14 or newer (PEP 758; checked), and leaves it alone for older targets. Keep what the formatter writes, and set `requires-python` correctly, because that spelling is a syntax error before 3.14.

### mypy

- `strict = true` runs mypy with the flags `--disallow-any-generics`, `--disallow-subclassing-any`, `--disallow-untyped-calls`, `--disallow-untyped-defs`, `--disallow-incomplete-defs`, `--check-untyped-defs`, `--disallow-untyped-decorators`, `--warn-redundant-casts`, `--warn-unused-ignores`, `--warn-return-any`, `--no-implicit-reexport`, `--strict-equality` and `--extra-checks` (mypy 2.4.1; the list may change between versions). `--warn-unreachable` is not part of it.
- Suppress with `# type: ignore[error-code]`, never a bare ignore. With `warn-unused-ignores` a stale ignore fails the run ([types](06-types-and-data-modeling.md#checking-with-mypy)).
- Add a `types-<package>` stub package to the `dev` group when a dependency ships no types.

### pytest

- pytest 9 reads the native `[tool.pytest]` table of `pyproject.toml`. The options above follow its good-practice guide: `importlib` import mode for new projects, strict markers and config, and `testpaths`. The conventions for writing tests are in the testing note ([testing](10-testing.md)).

### Automation

- Put plain commands in CI and run the same ones locally, in this order. The sample project passed all four checks (`5 passed` for pytest, `no issues found` for mypy) after its two findings were fixed:

```bash
uv sync --locked
uv run ruff format --check
uv run ruff check
uv run mypy
uv run pytest
```

- `ruff format` and `ruff check --fix` repair formatting and the safe fixes locally. Review unsafe fixes. Commit mechanical changes (a new Ruff release, a newly enabled rule family, a Python upgrade) separately from behaviour changes.
- Print the tool versions at the start of CI (`uv --version`, `uv run ruff --version`, `uv run mypy --version`, `uv run pytest --version`), so that a failing run shows what ran.
- A git hook that runs the same commands is optional and only repeats them.

## Sources and raw notes

Pages read on 2026-10-30:

- Python Developer's Guide: [Status of Python versions](https://devguide.python.org/versions/).
- Python Packaging User Guide: [Tool recommendations](https://packaging.python.org/en/latest/guides/tool-recommendations/), [Writing your pyproject.toml](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/), [Dependency Groups](https://packaging.python.org/en/latest/specifications/dependency-groups/) (PEP 735).
- uv documentation: [Working on projects](https://docs.astral.sh/uv/guides/projects/) and [Locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/).
- Ruff documentation: [The Ruff Linter](https://docs.astral.sh/ruff/linter/) (rule selection), [The Ruff Formatter](https://docs.astral.sh/ruff/formatter/), and the rule explanations printed by `ruff rule <code>` (Ruff 0.17.3).
- [mypy command line](https://mypy.readthedocs.io/en/stable/command_line.html) (mypy 2.4.1, the `--strict` flag list).
- pytest documentation: [Good Integration Practices](https://docs.pytest.org/en/stable/explanation/goodpractices.html).
- Tools run on 2026-10-30 in a scratch virtual environment with network: uv 0.13.6, Ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 and Django 6.1.2 (the newest releases on PyPI), on Python 3.14.8 from Homebrew. The sample project of this note, `uv init` layouts, the `except` rewrite and Ruff's inference of the target version from `requires-python` were run there. Every `toml` and `bash` block of this note was parsed or checked as the principles note describes.
