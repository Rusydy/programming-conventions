# Python Error Handling and Logging

## Summary

Failures are exceptions. Raise the most specific one that fits, define your own base exception only when callers need to catch it, chain with `raise ... from err`, keep `try` bodies to one statement, and catch broadly only at the boundary of the program, where the error is logged with its traceback. Libraries log through `logging.getLogger(__name__)` and never configure logging; the application configures it once. Log calls pass arguments instead of formatting the message.

## Rules

### Raising exceptions

- Raise the built-in exception that fits: `ValueError` for a bad value, `TypeError` for a wrong type (usually Python raises it for you, as `radius < 0` does for a string), `KeyError`, `FileNotFoundError`, `PermissionError`. Prefer the OS exception subclasses to inspecting `errno` (PEP 8).
- Define your own exception when callers need to tell it apart. Derive it from `Exception`, never from `BaseException`, and end its name in `Error`. Give a library or a package one base class (`class ConfigError(Exception)`) so that callers can catch everything it raises. Design the hierarchy around what the code that catches needs to distinguish, not around where the exception is raised (PEP 8).
- The message says what was wrong and includes the offending value: `f"radius must be non-negative, got {radius}"`. Never put a secret in a message.
- When you translate an exception, chain it: `raise ConfigError(...) from err` keeps the original as `__cause__` and shows it in the traceback (checked; Ruff B904). Write `from None` only when the original is noise, and then carry the useful detail into the new message (PEP 8).
- `assert` states an invariant that the program guarantees, and tests use it freely. It is not input validation: assertions are removed under `python -O` (checked: `assert False` did not run). Ruff reports it as `S101`.

### Catching exceptions

- Catch specific exceptions. A bare `except:` also catches `SystemExit` and `KeyboardInterrupt`, which makes Ctrl-C harder and hides bugs (PEP 8; E722). `except Exception:` is for the boundary only: the top of `main`, the loop of a worker, the handler of a request. There the code logs the traceback and either exits or goes on to the next item.
- Keep the `try` body to the one statement that can raise, and put the rest in `else`, so an unrelated exception is not swallowed. Use `finally` or, better, `with` for cleanup. Do not `return`, `break` or `continue` in a `finally` that jumps out of it: it cancels the exception in flight. Python 3.14 reports it as a `SyntaxWarning` (PEP 765), and `-W error` turns it into a `SyntaxError` (checked).
- Do not log an exception and then re-raise it at every level; log it where it is handled.
- To ignore one exception around one statement, use `contextlib.suppress(KeyError)` ([idioms](05-idiomatic-language-use.md#context-managers)).
- Several independent failures (from `asyncio.TaskGroup`, or from validating many rows) are raised as one `ExceptionGroup` and caught with `except*` (Python 3.11; checked). `err.add_note("text")` adds context to an exception on its way up (Python 3.11; checked).
- Python 3.14 allows `except A, B:` without parentheses when there is no `as` clause (PEP 758). `ruff format` writes it for projects whose `requires-python` is 3.14 or newer ([style](04-naming-comments-and-style.md#where-the-guides-disagree)).

```python
import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class ConfigError(Exception):
    """Base class for configuration problems."""


class ConfigNotFoundError(ConfigError):
    """The configuration file does not exist."""


def load_config(path: Path) -> dict[str, object]:
    """Load the JSON configuration at ``path``.

    Args:
        path: Location of the configuration file.

    Returns:
        The configuration as a dict.

    Raises:
        ConfigNotFoundError: If ``path`` does not exist.
        ConfigError: If the file is not a valid JSON object.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError as err:
        raise ConfigNotFoundError(f"no configuration at {path}") from err
    try:
        data = json.loads(text)
    except json.JSONDecodeError as err:
        raise ConfigError(f"invalid JSON in {path}: {err}") from err
    if not isinstance(data, dict):
        raise ConfigError(f"{path} must contain a JSON object")
    return data


def main() -> int:
    """Run the program and return its exit status."""
    try:
        load_config(Path("settings.json"))
    except ConfigError:
        logger.exception("cannot start")
        return 1
    return 0


print(f"exit status: {main()}")
```

```python
def validate(rows: list[int]) -> None:
    """Raise one ``ExceptionGroup`` that holds every invalid row."""
    errors = [
        ValueError(f"row {index}: {value} is negative")
        for index, value in enumerate(rows)
        if value < 0
    ]
    if errors:
        raise ExceptionGroup("invalid rows", errors)


try:
    validate([1, -2, -3])
except* ValueError as group:
    for error in group.exceptions:
        print(error)
```

### Logging

- Every module that logs has `logger = logging.getLogger(__name__)` at module level. Do not call `logging.info()` and friends directly: they use the root logger.
- A library does not configure logging: no `basicConfig`, no handlers, no levels. With no configuration, Python prints events of level WARNING and above to stderr and drops the rest (checked), which the logging HOWTO calls the best default behaviour. A library whose warnings must stay silent unless the application configures logging attaches `logging.NullHandler()` to its top-level logger (`logging.getLogger("mylib").addHandler(logging.NullHandler())`; checked: nothing is printed).
- An application configures logging once, at its entry point, with `logging.basicConfig(level=..., format=...)` or `logging.config.dictConfig`.
- Pass the values as arguments: `logger.info("loaded %d rows from %s", count, path)`. The string is formatted only if the event is emitted; with `logger.debug("value %s", obj)` while debug is off, `obj.__str__` was never called (checked). An f-string formats eagerly, so Ruff's `G004` flags it, and Django's style guide says not to use f-strings for logging or error messages. If computing an argument is expensive, guard it with `if logger.isEnabledFor(logging.DEBUG):`.
- In an `except` block log with `logger.exception("what failed")`, which adds the traceback at level ERROR (checked).
- Levels: `DEBUG` for diagnostic detail, `INFO` for normal events, `WARNING` for something unexpected that was handled, `ERROR` when an operation failed, `CRITICAL` when the program cannot go on.
- Do not log secrets or personal data. `print()` is for the output of a program, not for diagnostics; Ruff's `T20` flags it outside the command-line module. Diagnostics go to stderr through `logging`, results to stdout.

```python
import logging

logger = logging.getLogger(__name__)


def process(path: str, rows: int) -> None:
    """Process one file."""
    logger.info("processing %s (%d rows)", path, rows)
    if rows == 0:
        logger.warning("%s is empty", path)


def configure_logging(*, verbose: bool) -> None:
    """Configure logging once, at the entry point of the program."""
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


configure_logging(verbose=False)
process("data.csv", 0)
```

### Exit status of a program

- `main()` returns the status: 0 for success, 1 for any failure, 2 for misuse of the command line. `argparse` already exits with 2 and prints the usage to stderr when an argument is invalid (checked: `argument radius: invalid float value: 'abc'`). The entry point is `sys.exit(main())`.
- Translate exceptions into the exit status at the boundary of `main`, once, and do not call `sys.exit()` from library code.

## Sources and raw notes

Pages read on 2026-10-30:

- [PEP 8](https://peps.python.org/pep-0008/): exception hierarchy, chaining, bare except, minimal try bodies, `finally`, resources.
- Python documentation: [Logging HOWTO](https://docs.python.org/3/howto/logging.html) (logging from libraries, `NullHandler`, optimisation), [glossary](https://docs.python.org/3/glossary.html) (EAFP), [What's new in Python 3.11](https://docs.python.org/3/whatsnew/3.11.html) (exception groups, notes) and [3.14](https://docs.python.org/3/whatsnew/3.14.html) (PEP 758, PEP 765).
- Django documentation: [Coding style](https://docs.djangoproject.com/en/stable/internals/contributing/writing-code/coding-style/) (no f-strings in logging and error messages).
- Rule explanations from `ruff rule` for B904, E722, BLE001, S101, G004 and T201 (Ruff 0.17.3).
- Behaviour marked "checked" was run on Python 3.14.8 and 3.12.15. Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes.
