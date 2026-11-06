---
paths:
  - "**/*.py"
  - "*.py"
  - "**/*.pyi"
  - "*.pyi"
  - "**/pyproject.toml"
  - "pyproject.toml"
---
# Python conventions (every project)

Write idiomatic, readable Python. Follow the language's and its standard tools' conventions instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `python-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-10-30; update it by hand whenever a note changes. The paths above match `.py` and `.pyi` files and `pyproject.toml`; a Python script without an extension (for example one in `bin/`, which the Bash rule's `bin/*` glob also matches) does not load this file, so read it first.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (a new Ruff release, a newly enabled rule family, a Python upgrade) in separate commits.
- If the repository documents its own conventions or tools, follow them first: an existing `unittest` suite keeps working, a Django project uses Django's test runner. Generated code is exempt. A repository can mix languages and each file follows the rule of its own language (a Python installer inside a Bash plugin follows this file; its Bash scripts follow `bash.md`).
- Find the project's Python floor before writing code: `requires-python`, `.python-version`, the CI matrix, a version check at the top of the entry script. Use no syntax or library name newer than the floor (see Releases). A new application starts on 3.14, the newest release that all its dependencies support (3.15 came out on 2026-10-09). A library, or a script that runs on other people's interpreters, keeps the oldest release it supports. Never choose an end-of-life release as a floor (3.10 ended on 2026-10-01, 3.9 on 2025-10-31); when an existing project's floor is end-of-life, say so and leave the decision to its owner.
- Twelve choices in the notes are recorded decisions, not facts: the four tools (uv, Ruff, mypy strict, pytest), the 3.14 baseline, the explicit Ruff rule set, 88 columns, Google docstrings, absolute imports, built-in generics with `X | None`, `%s` arguments in logging calls, the formatter's `except A, B:`, the src layout, Django's own test runner, and the custom user model. Follow them; do not change them unasked.
- Before you report Python changes as done, run the project's checks and fix new findings. In a project that follows these notes: `uv sync --locked`, `uv run ruff format --check`, `uv run ruff check`, `uv run mypy`, `uv run pytest`. The newest stable tools on 2026-10-30 were uv 0.13.6, Ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 and Django 6.1.2.
- A Homebrew Python on macOS is marked externally managed: `pip install` is refused, and `--break-system-packages` is never the answer. Keep uv, Ruff, mypy and pytest in throwaway environments, and ask before downloading a tool, a package or another interpreter. Test an older release in a Docker image without network: `docker run --rm --network none -i python:3.12-alpine python - < file.py`.
- When sources disagree, the order is: what Python does (the reference, "What's new", the real interpreter), this file and the notes, PEP 8 and PEP 257 with the typing best practices, the PyPA specifications and guides, the documentation of uv, Ruff, mypy and pytest, then a framework's documentation.

## Tooling

- One `pyproject.toml` at the root describes the project and configures every tool. It always has a `[build-system]`; `dependencies` are runtime only; development tools go in `[dependency-groups]` (PEP 735); no `setup.py`, `setup.cfg` or `requirements.txt` in a new project. `[project.scripts]` installs a command. This file was run end to end (note 02):

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
select = ["E", "F", "I", "N", "UP", "B", "A", "C4", "SIM", "PTH", "RET", "S", "DTZ", "G", "T20", "PT", "D", "RUF"]

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

- uv does the interpreter, the environment and the lock file: `uv init`, `uv python install 3.14`, `uv add pkg`, `uv add --dev pkg`, `uv remove pkg`, `uv sync` (creates `.venv` and `uv.lock`), `uv run cmd`, `uv lock --upgrade-package pkg`, `uv build`. Commit `pyproject.toml`, `uv.lock` and `.python-version`; ignore `.venv`. `uv run` locks and syncs first; CI uses `uv sync --locked` (an error when the lock is stale) or `uv lock --check`. uv never upgrades on its own: upgrade on purpose, one package per commit, tests run. Never use the system Python for a project.
- Ruff formats and lints; no Black, isort, flake8 or pyupgrade beside it. Do not set what is already default (88 columns, double quotes, spaces, magic trailing comma); the target version comes from `requires-python`. Select the families explicitly (`select`, not `extend-select`, not `ALL`) and do not enable `COM812` or `ISC001`. Fix a finding rather than silence it; a suppression is `# noqa: CODE` with a reason (stale ones are RUF100). With `requires-python` at 3.14 or newer `ruff format` writes `except A, B:`, a syntax error before 3.14: keep the formatter's output and set `requires-python` to match.
- mypy runs with `strict = true`. Suppress with `# type: ignore[error-code]`, never bare; a stale ignore fails the run. A dependency without types gets a `types-<name>` package in the `dev` group. pytest 9 reads the native `[tool.pytest]` table.
- CI runs plain commands in the order above after printing the tool versions. A git hook that repeats them is optional.

## Layout and structure

- Src layout for anything installed or run as a package: `src/<package>/` (`__init__.py` with the package docstring and re-exports, `__main__.py`, one module per cohesive topic, `cli.py`, `py.typed` in a library that ships types), `tests/test_<module>.py` outside the package, and `pyproject.toml`, `uv.lock`, `.python-version`, `README.md`, `LICENSE` (published projects) and a `.gitignore` with `.venv/`, caches and `dist/` in the root. A web framework keeps the layout of its generator. A project with more than one module gets a build system.
- Modules are small and named for what they contain: short, lowercase, underscores allowed; package names avoid underscores. Imports sit at the top in three groups (standard library, third party, local), are absolute, one module per line, no `import *`. Break import cycles by moving the shared piece, or import for annotations only under `if TYPE_CHECKING:`. Module-level code only defines things; anything that runs goes in a function. Every module and package has a docstring (`D104` fails an empty `__init__.py`).
- Public API: anything documented is public, internal names start with one underscore. List public names in `__all__` (after the docstring, before the imports) and re-export from `__init__.py` what users import from the package root.
- A command is `main(argv: Sequence[str] | None = None) -> int` wired in `[project.scripts]`, with a `__main__.py` that ends in `sys.exit(main())`. A single-file module keeps `if __name__ == "__main__":`.
- A single-file script declares its Python version and dependencies in a PEP 723 comment block (`# /// script` ... `# ///`) and runs with `uv run --script`. Keep it to one file; with a second module it becomes a project.

## Style and naming

- `ruff format` applies the style; do not format by hand. Four spaces, 88 columns (wrap comments and docstrings at about 72 by habit), double quotes (`"""` for docstrings), wrap inside brackets and never with a backslash, one item per line with a trailing comma when a call does not fit, break before a binary operator, two blank lines around top-level definitions and one between methods, one statement per line, UTF-8 sources without a coding line. No space inside brackets or around `=` of a keyword argument; one on each side of `=` in an annotated default (`x: int = 0`).
- Names: class and exception `CapWords` (exceptions end in `Error`, acronyms stay capitalised), function, method and variable `snake_case`, constant `UPPER_SNAKE_CASE` at module level, type variable `T` (`_co`, `_contra`), internal `_name`, keyword clash `class_`, booleans as predicates (`is_valid`, `dry_run`). Never `l`, `O` or `I`; do not shadow builtins (`A` rules). Non-public attributes get one underscore; a double one only to avoid a clash in a class built for inheritance; never invent `__dunder__` names; in doubt, an attribute is non-public.
- Docstrings on every public module, class, function and method: `"""`, a one-line imperative summary ending in a period ("Return the area"), then a blank line and the description when needed, Google sections `Args:`, `Returns:`, `Raises:`, `Yields:` without repeating types. A non-public function gets a comment instead. A script's docstring doubles as its usage message.
- Comments explain why, not what, in complete English sentences; update them with the code; delete dead code. Directives name the code and give a reason: `# type: ignore[arg-type]`, `# noqa: S101`.
- Where the guides disagree and the notes decided: 88 columns (PEP 8: 79), double quotes, Google docstrings, break before the operator, absolute imports, built-in generics and `X | None` instead of `typing.List` and `Optional`, `%s` arguments in logging calls instead of f-strings.

## Idioms

- Truthiness for emptiness (`if items:`); `is None` and `is not None`, never `== None`; no `== True`; `isinstance(x, int)`, not `type(x) == int`. `if x:` is wrong when `0`, `""` or `[]` are valid values.
- A default that would be mutable is `None` plus `if x is None: x = []` (a mutable default is shared by all calls; B006). No function call in a default (B008).
- EAFP: assume the key or attribute exists and handle the exception (LBYL races in threaded code). Keep the `try` body to the one statement that can raise and put the rest in `else`. `config.get(key, default)` for value-or-default, `defaultdict` or `setdefault` for create-on-first-use.
- A comprehension builds a list, set or dict; `sum`, `max`, `any` and `all` take a generator without brackets. More than two `for` clauses, or side effects, makes it a loop. A generator function runs nothing until the first `next()`.
- Loop over the items: `for item in items`, `enumerate(items, start=1)`, `mapping.items()`, `zip(a, b, strict=True)` (without `strict` a shorter iterable truncates silently; B905). Sort with `key=`, not a comparison function.
- Text: f-strings, `"".join(parts)` instead of `+=` in a loop, `startswith`, `endswith`, `removeprefix`, `removesuffix`. Paths: `pathlib.Path` with `/`, `read_text`, `write_text`, `open`, `glob`, `mkdir(parents=True, exist_ok=True)` (`PTH` rules). Always `encoding="utf-8"` when opening text (`python -X warn_default_encoding` finds the rest). `with` for every resource.
- Return early. Make `return` consistent: either every path returns a value or none does, and write `return None` when others return a value. `def` instead of a lambda bound to a name (E731). A lambda in a loop sees the variable, not its value (B023): bind it with `functools.partial`. No `*args` or `**kwargs` unless the function passes them on.
- `Counter`, `defaultdict` and `deque` before a hand-written loop; merge dicts with `a | b`; fixed fields go in a dataclass or `NamedTuple`, not a bare tuple or dict.
- A context manager is a generator with `@contextlib.contextmanager` and the cleanup in `finally`. `contextlib.suppress(KeyError)` instead of `try`/`except`/`pass` (SIM105, S110).
- `match` for data of several shapes (3.10); the walrus operator only when it removes a repeated call.
- A program's entry point is `def main() -> int` under `if __name__ == "__main__": sys.exit(main())`; importing a module runs nothing.
- Mistakes and their Ruff codes: `def f(x=[])` B006; `type(x) == int` E721; `x == None` E711; `x == True` E712; bare `except:` E722; `raise New(...)` inside `except` without `from err` B904; `f = open(path)` SIM115, PTH123; `import os, sys` E401; `l = []` E741; `f = lambda x: ...` E731; `dict()` C408; `else` after `return` RET505; `typing.List` and `Optional` UP006, UP035, UP045; `logging.info(f"...")` G004; `datetime.datetime.now()` DTZ005; `items = []` as a class attribute RUF012.

## Types and data modeling

- Annotate every parameter and the return type of every function and method that other code calls, `-> None` included, tests too. Locals are inferred; annotate one only when the inferred type is wrong or too narrow (`counts: dict[str, int] = {}`).
- Parameters take abstract types (`Iterable`, `Sequence`, `Mapping`), results are concrete (`list`, `dict`); avoid union return types. `object` when anything is accepted, `Any` only where the type system cannot say it. Write `X | None` (None last), `list[str]`, `dict[str, int]`, `type[C]`, and `float` instead of `int | float`; aliases with `type Name = ...` (3.12).
- Strict mypy errors and fixes: `no-untyped-def` annotate; `type-arg` write `list[int]`; `return-value` return the right type or declare `| None`; `no-any-return` narrow before returning; `assignment` fix the value or the annotation. Prefer an `isinstance` check to `cast`. A library marks itself typed with an empty `py.typed` and annotates its whole public API.
- Shapes: a record is `@dataclass(frozen=True, slots=True, kw_only=True)` (hashable, compares by value, rejects unknown attributes, adding a field never breaks a call; `dataclasses.replace` makes a modified copy; `field(default_factory=...)` for a mutable default); a tuple that must stay a tuple is a `NamedTuple`; a dict with known keys from JSON is a `TypedDict`; a closed set of values is an `Enum` or a `StrEnum` (3.11); literal values in a signature are `Literal[...]`; an interface is a `Protocol`; a constant is `Final`.
- Depend on behaviour with a `Protocol` so the code stays testable. Generics use the 3.12 syntax: `def first[T](items: Sequence[T]) -> T:` and `type Pair[A, B] = tuple[A, B]` (a syntax error before 3.12). Mark overrides with `@override` (3.12).
- Annotations are not enforced: parse and validate outside data (JSON, forms, files, environment) once, at the boundary, and pass typed objects inside. A `|` union in an annotation works at run time on 3.10 and newer. Annotations are evaluated lazily from 3.14 (a forward reference needs no quotes); below 3.14 quote forward references or add `from __future__ import annotations`.

## API and class design

- A function does one thing, has a name that says what, and is short; no class when there is no state. Options are keyword-only (`*`), arguments that must not be named are positional-only (`/`). A boolean that changes behaviour is a smell: two functions, an enum, or a keyword-only parameter (`export(data, compress=True)`). Return one kind of thing and raise for failure instead of returning a special value. A long list of related arguments becomes one dataclass.
- A class holds state or satisfies an interface; `@dataclass` is the default for data. Plain attributes first, a `@property` of the same name when logic arrives later (cheap, no side effects; `functools.cached_property` for an expensive stable value). Compose before you inherit and keep hierarchies shallow. Alternative constructors are `@classmethod`s. Define `__eq__` and `__hash__` together, all six ordering methods or `functools.total_ordering`, and a helpful `__repr__`. `super()` calls the parent; `__init__` does no failing or blocking work.
- Collaborators (database session, HTTP client, clock, random generator) are passed in and described by a `Protocol`, so a test passes a fake. Datetimes are timezone-aware (`datetime.now(UTC)`; DTZ005); inject a clock where time matters. No mutable module-level state.
- Backwards compatibility covers the public names only. Change an API by adding keyword-only parameters with defaults, keep old names working for at least one release, mark them `@warnings.deprecated("use new() instead")` (3.13) or call `warnings.warn(msg, DeprecationWarning, stacklevel=2)`, and remove them only in a release that the version number marks as breaking.

## Errors and logging

- Raise the built-in exception that fits (`ValueError`, `TypeError`, `KeyError`, `FileNotFoundError`, `PermissionError`); prefer the OS exception subclasses to `errno`. A custom exception derives from `Exception`, ends in `Error`, and exists because callers must tell it apart; a package gets one base class. The message says what was wrong and includes the value (`f"radius must be non-negative, got {radius}"`), never a secret.
- Chain when you translate: `raise ConfigError(...) from err` (B904); `from None` only when the original is noise. `assert` states an invariant and belongs to tests; it is not input validation, because `python -O` removes it (S101).
- Catch specific exceptions. A bare `except:` also catches `SystemExit` and `KeyboardInterrupt` (E722); `except Exception:` belongs at the boundary only (top of `main`, a worker loop, a request handler), where you log the traceback and exit or go on. Minimal `try` body, the rest in `else`; `finally`, or better `with`, for cleanup. Never `return`, `break` or `continue` out of a `finally` (3.14 warns, PEP 765). Log an exception where it is handled, not at every level. Independent failures go in an `ExceptionGroup` and are caught with `except*` (3.11); `err.add_note("text")` adds context.
- Every module that logs has `logger = logging.getLogger(__name__)`; never call `logging.info()` directly (root logger). A library does not configure logging (no `basicConfig`, handlers or levels) and attaches `logging.NullHandler()` to its top-level logger when it must stay silent. The application configures logging once, at its entry point.
- Pass values as arguments: `logger.info("loaded %d rows from %s", count, path)` (G004 flags f-strings; Django's style guide agrees); guard expensive arguments with `logger.isEnabledFor(logging.DEBUG)`. `logger.exception("what failed")` in an `except` block adds the traceback. Levels: DEBUG detail, INFO normal events, WARNING unexpected but handled, ERROR an operation failed, CRITICAL the program cannot go on. No secrets or personal data in logs. `print()` is for a program's output (T20); diagnostics go to stderr through `logging`.
- Exit status: `main()` returns 0 for success, 1 for any handled failure, 2 for misuse of the command line (`argparse` already exits with 2). Translate exceptions into the status once, at the boundary of `main`; library code never calls `sys.exit()`.

## Concurrency and async

- Measure before adding concurrency; start from correct sequential code. By workload: many waits on async-capable I/O `asyncio`; blocking I/O libraries `ThreadPoolExecutor`; CPU-bound work `ProcessPoolExecutor` (or a free-threaded build, only on purpose); another program `subprocess.run`. The default build has a GIL (`sys._is_gil_enabled()` was True on 3.14.8 here); free-threaded builds (`python3.14t`) are supported from 3.14 (PEP 779).
- Executors go in a `with` block. `submit` returns futures, `as_completed` yields them as they finish, `map` keeps the order, `future.result()` re-raises the worker's exception. Process-pool arguments and results must be picklable and the function lives at module level (no lambda).
- asyncio: `asyncio.run(main())` once, at the entry point. Related tasks run in an `asyncio.TaskGroup` (3.11; one failure cancels the siblings and raises an `ExceptionGroup`; `gather` only for `return_exceptions=True`). Deadlines use `async with asyncio.timeout(seconds):` (raises `TimeoutError`). Keep a reference to every `create_task()` result (the loop holds a weak one). Never block the loop (`time.sleep`, blocking clients, long CPU loops): `await asyncio.to_thread(fn, *args)`. Do not swallow `asyncio.CancelledError`; clean up and re-raise. `python -X dev` finds never-awaited coroutines and slow callbacks.
- Threads: an executor instead of `threading.Thread`, share little, pass data through `queue.Queue`, `with lock:` on what remains shared.
- Processes: `spawn` is the default on macOS and Windows; on Linux `fork` until 3.13 and `forkserver` from 3.14. Under `spawn` the main module is imported again in each worker, so code that starts processes needs the `if __name__ == "__main__":` guard: without it a `multiprocessing.Pool` program hung on macOS and worked on Linux.
- `subprocess.run([...], check=True, capture_output=True, text=True, timeout=30)`: a list of arguments (no shell, metacharacters stay literal), `check=True` raises `CalledProcessError`, `timeout` raises `TimeoutExpired`. `shell=True` only for constant command lines. Use `run` or `communicate`, not hand-read pipes of a `Popen`.

## Testing

- pytest, in `tests/` outside the package, files `test_*.py` one per module, shared fixtures in `tests/conftest.py`, plain functions with plain `assert`. `unittest.TestCase` classes keep working (pytest and `python -m unittest` collect them): do not rewrite working tests only to change style. Name a test after the behaviour (`test_negative_radius_raises_value_error`), one behaviour per test, no `if` or loop in a test. Tests are independent of order, working directory, clock, randomness and network; annotate them `-> None`.
- `pytest.approx` for floats; `pytest.raises(Error, match="text")` (PT011 asks for `match` on broad exceptions); `@pytest.mark.parametrize` for one behaviour with several inputs.
- A fixture builds what a test needs, and `yield` separates the cleanup; prefer fixtures to `setUp` and `tearDown`; the default scope is one test. Built-ins first: `tmp_path`, `monkeypatch`, `capsys`, `caplog`.
- Prefer a fake (a small class that implements the same `Protocol` and records calls in memory). `unittest.mock` only for what cannot be faked, with `autospec=True`, patching the name where the code looks it up; do not assert on internal calls.
- Register every marker (`--strict-markers`) and keep unit tests fast; mark slow ones (`-m "not slow"`). pytest runs no `async def` test without a plugin; add one to `dev` and keep async tests thin. Doctests only for small pure examples. Keep Selenium and `HTMLTestRunner` tests in a separate, marked suite.
- Commands: `uv run pytest`, `uv run pytest tests/test_x.py::test_name`, `-k "expr"`, `-x --lf`, `-ra`.

## Security and dependencies

- Input is data. SQL: pass parameters, never build the statement from strings (S608); Django querysets are parameterised, raw SQL, `extra()` and `RawSQL` need the same care. Processes: a list of arguments, `shell=True` only for constant lines (S602). No `eval` or `exec` of strings: `ast.literal_eval` (S307). `pickle` runs code when it loads: only your own data, JSON for the rest, `hmac` when integrity matters (S301); `yaml.safe_load` (S506). A file name from a user can contain `..` or be absolute: resolve the path and check `is_relative_to(BASE)`.
- `secrets` for tokens, passwords and keys (`random` is predictable, S311); `hmac.compare_digest` to compare secrets; never a plain `sha256(password)`: use the framework's password API (Django `make_password` and `check_password`) or `hashlib.scrypt` or `pbkdf2_hmac` with a salt. Secrets stay out of source control, logs and error messages; configuration comes from the environment or a secrets store. Never `verify=False` (S501).
- `tempfile` (`TemporaryDirectory`, `NamedTemporaryFile`, `mkstemp`), never `mktemp` (S306). No `assert` for validation (S101).
- Install only into a virtual environment. Applications install from the lock file (`uv sync --locked`); upgrade deliberately (`uv lock --upgrade-package pkg`), read the changelog, one package at a time, run the tests. A dependency must remove real complexity; prefer the standard library. Publish with Trusted Publishing, never `setup.py upload`. Ruff's `S` rules run in CI; silence one only with `# noqa: S...` and a reason.

## Command-line programs and Django

- A command-line program is `main(argv: Sequence[str] | None = None) -> int`: build the `argparse` parser (typed arguments, `choices`, `default`, `-h/--help` for free), parse `argv` so a test can pass a list, run, return the status. Results go to stdout with `print`; diagnostics go through `logging` (stderr), configured once in `main`; `T20` is ignored for `cli.py` only. An error a user can cause becomes one line on stderr and a non-zero status; an unexpected one shows its traceback.
- Django: start on the newest series (6.1.2 on 2026-10-30; LTS only for an application that upgrades rarely; 6.2 LTS is due in April 2027). Use what the generators write (`django-admin startproject config .`, `startapp`) and run commands as `uv run python manage.py ...`. Upgrade one feature release at a time after reading the release notes and the deprecation timeline, with the tests run with warnings on (`python -Wa manage.py test`).
- Settings come from the environment (`SECRET_KEY = os.environ["SECRET_KEY"]`, `DEBUG = os.environ.get("DEBUG") == "1"`, `ALLOWED_HOSTS` split from the environment); run `manage.py check --deploy` against the production settings as part of a release. Do not switch off CSRF protection, template escaping or the clickjacking middleware without a written reason.
- Start with a custom user model (`class User(AbstractUser)` and `AUTH_USER_MODEL`) before the first migration; refer to it with `settings.AUTH_USER_MODEL` in models and `get_user_model()` in code.
- Queries: `select_related` for foreign keys and one-to-one fields, `prefetch_related` for many-to-many and reverse relations (6 queries became 1 in the checked example); pin counts with `assertNumQueries`. Commit migrations with the model change; CI runs `python manage.py makemigrations --check --dry-run`.
- Tests: `django.test.TestCase` and `python manage.py test`, not pytest (it needs the third-party `pytest-django`); prefer `assertRaisesMessage()` and `assertIs(..., True)`.
- Generated Django code does not pass the strict configuration (49 findings in a fresh project, 25 of them in migrations). Note 12 holds the additions for `pyproject.toml`: exclude `**/migrations/*.py` from Ruff, ignore `PT`, per-file `D` ignores for the generated files, `E501` for `config/settings.py`, and mypy overrides (or `django-stubs` with its plugin, not tested here) because Django ships no type hints.

## Releases and modern Python

- Supported on 2026-10-30: 3.11 (security fixes only, ends 2027-10), 3.12 (2028-10), 3.13 (2029-10), 3.14 and 3.15 (bugfix phase; end 2030-10 and 2031-10). A feature release comes every October; the next is due on 2027-10-06. Move to a new release when every dependency supports it, in a change of its own.
- Added by release: 3.10 `match`, `X | Y` in annotations, `zip(strict=)`, parenthesized context managers; 3.11 `ExceptionGroup` and `except*`, `add_note()`, `tomllib`, `Self`, `TaskGroup`, `asyncio.timeout`, `StrEnum`, `datetime.UTC`; 3.12 the `type` statement and `def f[T]()` generics, f-string grammar (PEP 701), `override`, `itertools.batched`; 3.13 `warnings.deprecated`, `copy.replace()`, type parameter defaults, `ReadOnly`, `TypeIs`; 3.14 lazy annotations, `t"..."` template strings, `except A, B:` without brackets, `compression.zstd`, a supported free-threaded build; 3.15 `lazy import`, `frozendict`, UTF-8 as the default encoding, unpacking in comprehensions (documented only; 3.15 is not installed here).
- Run on 3.12.15, these fail: `except A, B:` and `t"..."` (SyntaxError), `from warnings import deprecated` (ImportError), `copy.replace` (AttributeError), an annotation that names something defined later (NameError). 3.14 warns about `return` in `finally`.
- Breaking changes: 3.12 removed `distutils`; 3.13 removed 19 legacy modules (PEP 594) and defined `locals()`; 3.14 changed the `multiprocessing` start methods; 3.15 uses UTF-8 as the default encoding (still pass `encoding=`).
- Ruff's `UP` rules ask for each new idiom when the target version reaches the release that has it; `ruff check --select UP --diff` shows the safe changes before anything is edited. Upgrade: pick the target and check that every dependency supports it; read "What's new" and "Porting to Python 3.x" for each release crossed; change `.python-version` (`uv python pin`), `requires-python`, the CI matrix and the container image together; `uv lock` and `uv sync`; run the tests with deprecation warnings visible (`-W error::DeprecationWarning`); `ruff check --select UP --diff`, review, `--fix`, `ruff format`; run mypy and the tests again.

## Notes index

Each file is in the `python-conventions` folder of the programming-conventions repository.

- `01-principles-and-sources.md`: principles, precedence, decisions to review, applying the notes
- `02-project-setup-and-tooling.md`: Python versions, pyproject.toml, uv, Ruff, mypy, pytest, CI order
- `03-project-layout-and-packages.md`: src layout, modules, public API, entry points, single-file scripts
- `04-naming-comments-and-style.md`: formatting, names, imports, docstrings, where the guides disagree
- `05-idiomatic-language-use.md`: idioms, worked example, mistake table
- `06-types-and-data-modeling.md`: annotations, mypy errors, dataclasses, enums, protocols, generics
- `07-api-and-class-design.md`: signatures, classes, dependencies, changing an API
- `08-error-handling-and-logging.md`: exceptions, logging, exit status
- `09-concurrency-and-async.md`: executors, asyncio, threads, processes, subprocess
- `10-testing.md`: pytest layout, fixtures, test doubles, markers, async tests
- `11-security-and-dependencies.md`: injection, secrets, temporary files, the lock file
- `12-platform-practices.md`: command-line programs, Django (tool additions for generated code)
- `13-modern-python-by-release.md`: supported releases, features by release, upgrade checklist
