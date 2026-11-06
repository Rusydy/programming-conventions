# Python Testing

## Summary

Tests run with pytest, in a `tests/` directory next to the package, written as plain functions with plain `assert`. Existing `unittest.TestCase` classes keep working, because pytest collects and runs them. A test names one behaviour, builds its own data with fixtures, replaces slow or external collaborators with fakes that implement the same interface, and does not depend on the clock, the network or the order of other tests. Coroutines need a plugin.

## Rules

### Layout and names

- Tests live in `tests/`, outside the package, in files named `test_*.py`, one per module under test. Shared fixtures go in `tests/conftest.py`. With the `importlib` import mode of the tooling note, test directories need no `__init__.py` ([tooling](02-project-setup-and-tooling.md#pytest)).
- pytest collects `test_*` functions, and `Test*` classes without an `__init__` method. It also collects `unittest.TestCase` subclasses (pytest documentation). A `unittest` test class ran unchanged under pytest 9.2: `3 passed`. New tests are plain functions; do not rewrite working `unittest` tests only to change style.
- Name a test after the behaviour, not the method: `test_negative_radius_raises_value_error`. One behaviour per test, arranged as setup, action, assertion, with no `if` or loop in the test.
- Every test is independent: it does not rely on another test having run, on the working directory, on the time of day, on random values, or on the network. Inject the clock and the random generator ([API design](07-api-and-class-design.md#dependencies)).
- Annotate tests with `-> None` and their fixtures with their types; mypy strict checks the tests too. Ruff ignores the docstring rules (`D`) and `assert` (`S101`) under `tests/`.

### Assertions

- Use plain `assert`: pytest shows the values of both sides when it fails. Compare floats with `pytest.approx`. Check exceptions with `pytest.raises(Error, match="text")`; Ruff's `PT011` asks for `match` when the exception is broad, such as `ValueError`, because the test could otherwise pass on an unrelated error.
- Use `@pytest.mark.parametrize` for the same behaviour with several inputs, instead of a loop in the test.

### Worked example

The idiomatic function is in the idioms note ([idioms](05-idiomatic-language-use.md#worked-example-area-of-a-circle)); these are its tests in pytest. The `type: ignore` is required: mypy rejects the string argument on purpose, and in strict mode an unneeded ignore would fail the run.

```python
import math

import pytest

from demo.circle import area_of_circle

@pytest.mark.parametrize(
    ("radius", "expected"),
    [(0, 0.0), (1, math.pi), (2, 4 * math.pi)],
)
def test_area_of_circle(radius: float, expected: float) -> None:
    assert area_of_circle(radius) == pytest.approx(expected)

def test_negative_radius_raises_value_error() -> None:
    with pytest.raises(ValueError, match="non-negative"):
        area_of_circle(-1)

def test_non_number_raises_type_error() -> None:
    with pytest.raises(TypeError):
        area_of_circle("abc")  # type: ignore[arg-type]
```

### Fixtures

- A fixture builds what a test needs; `yield` in it separates the setup from the cleanup. Prefer fixtures to `setUp` and `tearDown`. The default scope is one test; widen it only for something expensive that tests do not modify.
- Use the built-in fixtures before writing your own: `tmp_path` (a temporary directory per test, a `Path`), `monkeypatch` (set an environment variable, an attribute or a dictionary item, undone after the test), `capsys` (captured stdout and stderr), `caplog` (captured log records).

```python
import json
import logging
import os
from pathlib import Path

import pytest

@pytest.fixture
def config_file(tmp_path: Path) -> Path:
    """Create a JSON configuration file for a test."""
    path = tmp_path / "config.json"
    path.write_text(json.dumps({"debug": True}), encoding="utf-8")
    return path

def test_config_file_holds_the_debug_flag(config_file: Path) -> None:
    data = json.loads(config_file.read_text(encoding="utf-8"))
    assert data == {"debug": True}

def test_monkeypatch_sets_an_environment_variable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_MODE", "test")
    assert os.environ["APP_MODE"] == "test"

def test_warning_is_logged(caplog: pytest.LogCaptureFixture) -> None:
    with caplog.at_level(logging.WARNING):
        logging.getLogger("app").warning("disk almost full")
    assert "disk almost full" in caplog.text

def test_output_is_captured(capsys: pytest.CaptureFixture[str]) -> None:
    print("hello")
    assert capsys.readouterr().out == "hello\n"
```

### Test doubles

- Prefer a fake: a small class that implements the same interface as the real collaborator and keeps its calls in memory. It survives refactoring, because the test checks the outcome and not how the code reached it.
- Use `unittest.mock` only to replace something you cannot fake, with `autospec=True` so that the mock rejects calls the real object would reject, and patch the name where the code looks it up. Do not assert on internal calls that are not part of the contract.

```python
from collections.abc import Sequence
from typing import Protocol

class Notifier(Protocol):
    """Anything that can send a message."""

    def send(self, to: str, body: str) -> None:
        """Send ``body`` to ``to``."""
        ...

def notify_all(notifier: Notifier, recipients: Sequence[str], body: str) -> None:
    """Send ``body`` to every recipient."""
    for recipient in recipients:
        notifier.send(recipient, body)

class FakeNotifier:
    """Record the messages instead of sending them."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, str]] = []

    def send(self, to: str, body: str) -> None:
        """Remember the message."""
        self.sent.append((to, body))

def test_notify_all_sends_one_message_per_recipient() -> None:
    notifier = FakeNotifier()
    notify_all(notifier, ["ada", "bob"], "welcome")
    assert notifier.sent == [("ada", "welcome"), ("bob", "welcome")]
```

### Markers, speed and async tests

- Register every marker in the configuration. With `--strict-markers` an unregistered marker is an error instead of a silent typo. Keep unit tests fast (a full run in seconds) and mark the slow ones, so that they can be left out with `-m "not slow"`.

```toml
[tool.pytest]
markers = ["slow: tests that take more than a second"]
```

- pytest does not run `async def` tests by itself: without a plugin the test fails with "async def functions are not natively supported" and the output lists the plugins that add support (checked with pytest 9.2). Add one to the `dev` group, and keep the async tests thin by testing the logic in plain functions.
- Examples in docstrings are tests when they are doctests: `python -m doctest module.py` or `pytest --doctest-modules src`. Use them for small pure examples only.
- Django has its own runner and test cases ([Django](12-platform-practices.md#django)). Keep end-to-end browser tests in a separate, marked suite so the fast tests run on their own.

### Running tests

```bash
uv run pytest                                  # all tests
uv run pytest tests/test_circle.py::test_negative_radius_raises_value_error
uv run pytest -k "radius and not negative"     # by name
uv run pytest -x --lf                          # stop at the first failure; rerun the last failures
uv run pytest -ra                              # summary of skipped and failed tests
```

## Sources and raw notes

Pages read on 2026-10-30:

- pytest documentation: [Good Integration Practices](https://docs.pytest.org/en/stable/explanation/goodpractices.html) (test discovery, layouts, import modes, `unittest.TestCase` collection).
- Rule explanations from `ruff rule` for PT011 and the `PT` family (Ruff 0.17.3).
- [PEP 8](https://peps.python.org/pep-0008/) (comparisons and exceptions in tests) and the Django [Coding style](https://docs.djangoproject.com/en/stable/internals/contributing/writing-code/coding-style/) page (test naming and assertion advice).
- Run on 2026-10-30 with pytest 9.2.0 and Python 3.14.8: the sample project's tests (`5 passed`), a `unittest` class under pytest (`3 passed`), and an `async def` test without a plugin (failed with the message above). Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes; blocks with test functions were run with pytest.
