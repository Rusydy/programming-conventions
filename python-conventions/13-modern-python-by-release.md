# Python Releases and Modern Python

## Summary

A new Python feature release comes out every October and is supported for five years: about two years of bugfix releases, then security fixes only. Choose `requires-python` on purpose, use the syntax and the library features of that release, and let Ruff's `UP` rules apply them. Code written for a newer release can fail on an older one even at parse time (checked: `except ValueError, TypeError:` is a `SyntaxError` on 3.12.15). The notes of this set target 3.14, the release used for the checks. 3.15 was released on 2026-10-09 and is described from the documentation only, because it was not installed for the checks.

## Rules

### Supported releases

| Release | Status | First release | End of life |
| --- | --- | --- | --- |
| 3.15 | bugfix | 2026-10-09 | 2031-10 |
| 3.14 | bugfix | 2025-10-07 | 2030-10 |
| 3.13 | security | 2024-10-07 | 2029-10 |
| 3.12 | security | 2023-10-02 | 2028-10 |
| 3.11 | security | 2022-10-24 | 2027-10 |
| 3.10 | end-of-life | 2021-10-04 | 2026-10-01 |

This is the table of the Python developer's guide, read on 2026-10-30. Its status key says:

- **bugfix:** once a release is out, bug fixes and security fixes are accepted, and new binaries are built roughly every two months.
- **security:** after two years (18 months for releases before 3.13) only security fixes are accepted, no more binaries are released, and source-only releases appear as needed.
- **end-of-life:** five years after a release, support ends.

The next feature release (PEP 826) is scheduled for 2027-10-06. In the checks, `python3` was Homebrew's 3.14.8, and the Docker image `python:3.12-alpine` has 3.12.15. 3.11, 3.13 and 3.15 are not installed, so everything said about them comes from the documentation.

Rules:

- `requires-python` is the oldest release the project supports. An application sets it to the release it runs on; the notes use `>=3.14` (see the decisions in the [principles note](01-principles-and-sources.md#decisions-to-review)). A library sets it to the oldest release that is still supported and that its users need, and tests on that release and on the newest.
- Never choose an end-of-life release as the floor (3.10 ended on 2026-10-01). Move the floor up when the support of its release ends, and the new features come with it.
- Do not use syntax or library names that are newer than the floor. The table further down shows what fails on 3.12.15.
- Move to a new feature release when every dependency supports it, not on the day of its release.

### What each release added

The "Added" column comes from the "What's new" page of each release. The last column says where a feature was run on 2026-10-30: 3.12 means Python 3.12.15 in Docker, 3.14 means Python 3.14.8 on macOS, and docs means it was only read.

| Release | Added | Replaces | Run |
| --- | --- | --- | --- |
| 3.10 | `match` statements (PEP 634 to 636) | chains of `isinstance` and `if` | 3.12, 3.14 |
| 3.10 | `X \| Y` in annotations (PEP 604) | `Union[X, Y]`, `Optional[X]` | 3.12, 3.14 |
| 3.10 | `zip(..., strict=True)` (PEP 618) | `zip` that drops extra items silently | 3.12, 3.14 |
| 3.10 | parenthesized context managers (bpo-12782) | backslash continuation | docs |
| 3.11 | `ExceptionGroup` and `except*` (PEP 654), `add_note()` (PEP 678) | ad hoc collections of errors, text added to messages | 3.12, 3.14 |
| 3.11 | `tomllib` (PEP 680) | a third-party package to read TOML | 3.12, 3.14 |
| 3.11 | `typing.Self` (PEP 673) | a `TypeVar` bound to the class | 3.12, 3.14 |
| 3.11 | `asyncio.TaskGroup`, `asyncio.timeout` | `gather`, `wait_for` | 3.12, 3.14 |
| 3.11 | `enum.StrEnum`, `datetime.UTC` | `class X(str, Enum)`, `timezone.utc` | 3.12, 3.14 |
| 3.12 | type parameters and the `type` statement (PEP 695) | `TypeVar`, `Generic`, `TypeAlias` | 3.12, 3.14 |
| 3.12 | f-strings in the grammar (PEP 701): the same quotes and nested expressions | workarounds with other quotes | 3.12, 3.14 |
| 3.12 | `typing.override` (PEP 698) | nothing: a misspelled override went unnoticed | 3.12, 3.14 |
| 3.12 | `itertools.batched` | hand-written chunking | 3.12, 3.14 |
| 3.13 | `warnings.deprecated` (PEP 702) | deprecation only in the docstring | 3.14 |
| 3.13 | `copy.replace()` | `dataclasses.replace()`, which is for dataclasses only | 3.14 |
| 3.13 | type parameter defaults (PEP 696), `typing.ReadOnly` (PEP 705), `typing.TypeIs` (PEP 742) | | docs |
| 3.13 | defined semantics for `locals()` (PEP 667), a new interactive interpreter, experimental free-threaded build (PEP 703) and JIT (PEP 744) | | docs |
| 3.14 | deferred evaluation of annotations (PEP 649, PEP 749) | quoted annotations, `from __future__ import annotations` | 3.14 |
| 3.14 | template strings `t"..."` (PEP 750) | | 3.14 |
| 3.14 | `except A, B:` without brackets (PEP 758) | `except (A, B):` | 3.14 |
| 3.14 | `compression.zstd` (PEP 784), `concurrent.interpreters` (PEP 734) | | docs |
| 3.14 | the free-threaded build is officially supported (PEP 779) | | docs |
| 3.15 | `lazy import` (PEP 810) | imports inside functions to save start-up time | docs |
| 3.15 | `frozendict` (PEP 814) and `sentinel` (PEP 661) built-ins | | docs |
| 3.15 | UTF-8 as the default encoding (PEP 686) | the locale encoding | docs |
| 3.15 | unpacking in comprehensions (PEP 798) | nested comprehensions, `itertools.chain.from_iterable()` | docs |
| 3.15 | the `profiling` package with the Tachyon sampling profiler (PEP 799) | | docs |
| 3.15 | `TypedDict` with typed extra items (PEP 728), `TypeForm` (PEP 747), disjoint bases (PEP 800) | | docs |

One module with the features of 3.10 to 3.12. It ran on Python 3.12.15 and on 3.14.8, printed `3 list starting with 1 and 2 more (2, 1) square`, then the batches, the two exception groups and the note, and passed Ruff and strict mypy:

```python
"""Features of Python 3.10 to 3.12 in one module; runs on 3.12 and later."""

import tomllib  # 3.11
from itertools import batched  # 3.12
from typing import Self, override  # 3.11 and 3.12

type Pair[T] = tuple[T, T]  # 3.12

class Shape:
    """A shape with a name."""

    def name(self) -> str:
        """Return the name of the shape."""
        return "shape"

    def same(self) -> Self:  # 3.11
        """Return the object itself, typed as its own class."""
        return self

class Square(Shape):
    """A square."""

    @override  # 3.12
    def name(self) -> str:
        """Return the name of the square."""
        return "square"

def first[T](items: list[T]) -> T | None:  # 3.12 syntax, 3.10 union
    """Return the first item, or None for an empty list."""
    return items[0] if items else None

def describe(value: int | str | list[int]) -> str:
    """Describe a value with structural pattern matching (3.10)."""
    match value:
        case int():
            return f"int {value}"
        case str():
            return f"str {value!r}"
        case [head, *rest]:
            return f"list starting with {head} and {len(rest)} more"
        case _:
            return "empty list"

def swap(pair: Pair[int]) -> Pair[int]:
    """Swap the two items of a pair."""
    return pair[1], pair[0]

print(first([3, 4]), describe([1, 2, 3]), swap((1, 2)), Square().same().name())
# batched() gets a strict= parameter in 3.13; this module also runs on 3.12.
print(list(batched(range(7), 3)), list(zip([1, 2], [3, 4], strict=True)))  # noqa: B911

try:
    raise ExceptionGroup("many", [ValueError("a"), TypeError("b")])  # 3.11
except* ValueError as group:
    print("value errors:", [str(error) for error in group.exceptions])
except* TypeError as group:
    print("type errors:", [str(error) for error in group.exceptions])

failure = ValueError("bad value")
failure.add_note("while loading the config")  # 3.11
print(failure.__notes__, tomllib.loads('name = "demo"'))
```

One module with features of 3.13 and 3.14. It needs 3.14: it ran there and passed Ruff and strict mypy, and on 3.12.15 it does not even compile (`SyntaxError: multiple exception types must be parenthesized`).

```python
"""Features of Python 3.13 and 3.14 in one module; needs 3.14."""

import copy
import warnings
from dataclasses import dataclass

@dataclass(frozen=True)
class Point:
    """A point on a grid."""

    x: int
    y: int

class Node:
    """A list node; the annotation names the class that is being defined (3.14)."""

    def __init__(self, value: int, next_node: Node | None = None) -> None:
        self.value = value
        self.next_node = next_node

def moved(point: Point, dx: int = 1) -> Point:
    """Return the point moved to the right by ``dx``; copy.replace is 3.13."""
    return copy.replace(point, x=point.x + dx)

@warnings.deprecated("use moved() instead")  # 3.13
def shifted(point: Point) -> Point:
    """Return the point one step to the right."""
    return moved(point)

def parse(text: str) -> int:
    """Parse an integer, or return -1; the except clause needs 3.14."""
    try:
        return int(text)
    except ValueError, TypeError:
        return -1

name = "world"
greeting = t"Hello {name}"  # 3.14
print(type(greeting).__name__, greeting.strings, greeting.interpolations[0].value)
print(parse("x"), Node(1, Node(2)).value)
with warnings.catch_warnings(record=True) as caught:
    warnings.simplefilter("always")
    print(shifted(Point(1, 2)))
print(caught[0].category.__name__, caught[0].message)
```

3.15 from the examples of "What's new in Python 3.15". It was not run, because 3.15 is not installed here:

```text
lazy import json
lazy from pathlib import Path

lists = [[1, 2], [3, 4], [5]]
flat = [*items for items in lists]            # [1, 2, 3, 4, 5]
dicts = [{"a": 1}, {"b": 2}, {"a": 3}]
merged = {**d for d in dicts}                 # {'a': 3, 'b': 2}

point = frozendict(x=1, y=2)                  # immutable, hashable if its items are
```

### What fails on an older release

The same constructs were run on Python 3.12.15 and on 3.14.8:

| Code | Python 3.12.15 | Python 3.14.8 |
| --- | --- | --- |
| `except ValueError, TypeError:` | `SyntaxError: multiple exception types must be parenthesized` | works |
| `t"hello {name}"` | `SyntaxError: invalid syntax` | works, gives a `Template` |
| `from warnings import deprecated` | `ImportError: cannot import name 'deprecated'` | works, and calling the function warns with `DeprecationWarning` |
| `copy.replace(point, x=5)` | `AttributeError: module 'copy' has no attribute 'replace'` | works |
| an annotation that names something not defined yet | `NameError` when the function is defined | works, the annotation is evaluated later |
| `return` inside `finally` | no warning | `SyntaxWarning: 'return' in a 'finally' block` (PEP 765) |
| `sys._is_gil_enabled()` | not available | `True` on the default build |

The `finally` rule of 3.14 also covers `break` and `continue` that leave the block (PEP 765, What's new in 3.14).

### Ruff as the upgrade tool

Ruff takes its target version from `requires-python` when `target-version` is not set (checked: the same file gave the 3.9 set of findings with `requires-python = ">=3.9"` and the 3.14 set with `">=3.14"`). The `UP` rules, which the [tooling note](02-project-setup-and-tooling.md#ruff) selects, and `B905` therefore ask for the new idioms exactly when the floor reaches the release that has them. This is what Ruff 0.17.3 reported for the file below, with `--select UP,B905` and each target version:

| Target | Rules that fire | What they ask for |
| --- | --- | --- |
| 3.9 | `UP006`, `UP035`, `UP036` | `list` and `dict` instead of `List` and `Dict`, moved imports, a version check that is always true |
| 3.10 | `UP007`, `UP045`, `B905` | `X \| Y` instead of `Union`, `X \| None` instead of `Optional`, `strict=` for `zip` |
| 3.11 | `UP017`, `UP041`, `UP042` | `datetime.UTC`, `TimeoutError` instead of `asyncio.TimeoutError`, `StrEnum` |
| 3.12 | `UP040`, `UP046`, `UP047` | the `type` statement, type parameters on classes and functions instead of `TypeAlias`, `Generic` and `TypeVar` |
| 3.13 to 3.15 | nothing new for this file | |

```python
# before
import asyncio
import datetime
import sys
from enum import Enum
from typing import Dict, Generic, List, Optional, TypeAlias, TypeVar, Union

T = TypeVar("T")

Pair: TypeAlias = "tuple[int, int]"

class Color(str, Enum):
    RED = "red"

class Box(Generic[T]):
    def __init__(self, item: T) -> None:
        self.item = item

def first(items: List[T]) -> Optional[T]:
    return items[0] if items else None

def parse(value: Union[int, str]) -> Dict[str, int]:
    return {"v": int(value)}

def pairs(a: list[int], b: list[int]) -> list[tuple[int, int]]:
    return list(zip(a, b))

async def wait() -> None:
    try:
        await asyncio.wait_for(asyncio.sleep(1), 0.1)
    except asyncio.TimeoutError:
        pass

NOW = datetime.datetime.now(datetime.timezone.utc)

if sys.version_info >= (3, 9):
    pass
```

Save the block without its first line as `legacy.py` and run `ruff check legacy.py --isolated --select UP,B905 --target-version py312` to see the findings. `ruff check --select UP --diff` prints the safe changes before anything is edited (checked: `List[T]` became `list[T]`, `Optional[T]` became `T | None`, `Union[int, str]` became `int | str` and `asyncio.TimeoutError` became `TimeoutError`). Six more fixes are unsafe and need `--unsafe-fixes`. `ruff format` follows the floor too: with `requires-python = ">=3.14"` it writes `except A, B:` without brackets.

### Changes that break working code

- 3.12 removed the `distutils` package (PEP 632).
- 3.13 removed the remaining 19 "dead batteries", legacy standard library modules deprecated by PEP 594 in 3.11, and gave `locals()` defined semantics (PEP 667).
- 3.14 warns about `return`, `break` and `continue` that leave a `finally` block (PEP 765), and changes the default start methods of `multiprocessing` ([concurrency](09-concurrency-and-async.md#processes)).
- 3.15 uses UTF-8 as the default encoding, independent of the system's environment, for I/O without an explicit `encoding`. The documentation advises always passing an explicit `encoding`, for the best compatibility between versions, and offers `encoding="locale"` (since 3.10), the opt-in `EncodingWarning`, and `PYTHONUTF8=0` or `-X utf8=0` to keep the old behaviour. The tooling and idiom notes already pass `encoding="utf-8"` ([idioms](05-idiomatic-language-use.md#text-files-and-paths)).

### Upgrade checklist

1. Pick the target in the table of supported releases, and confirm that each dependency supports it (its release notes, and the `Requires-Python` and classifiers of its PyPI page).
2. Read "What's new" and "Porting to Python 3.x" for every release that the upgrade crosses.
3. Change the interpreter and the floor together: `.python-version` (`uv python pin`), `requires-python`, the CI matrix and the base image of the containers.
4. Re-lock and install: `uv lock` creates or updates `uv.lock` (uv documentation), and `uv sync` installs it.
5. Run the tests with deprecation warnings visible. Python hides `DeprecationWarning` outside `__main__` by default (Django upgrade guide). pytest prints a summary of warnings (checked: `1 passed, 1 warning`), and `-W error::DeprecationWarning` turns them into failures (checked).
6. Let Ruff modernise the code: `ruff check --select UP --diff`, review, then `--fix`, then `ruff format`.
7. Run `mypy` and the whole test suite again.

```bash
uv python pin 3.15                          # writes .python-version
# raise requires-python in pyproject.toml, then:
uv lock                                     # re-resolve for the new floor
uv sync
uv run pytest -W error::DeprecationWarning  # deprecation warnings fail the tests
uv run ruff check --select UP --diff        # what Ruff would modernise
```

`uv python pin` was run with `3.14` and printed ``Pinned `.python-version` to `3.14` ``. `uv lock` and `uv sync` need the network, and Python 3.15 is not installed here, so those lines were not run for 3.15. The Django-specific steps of an upgrade are in the [platform note](12-platform-practices.md#django).

## Sources and raw notes

Pages read on 2026-10-30:

- Python developer's guide: [Status of Python versions](https://devguide.python.org/versions/) (the table and the status key).
- Python documentation: What's new in Python [3.10](https://docs.python.org/3/whatsnew/3.10.html), [3.11](https://docs.python.org/3/whatsnew/3.11.html), [3.12](https://docs.python.org/3/whatsnew/3.12.html), [3.13](https://docs.python.org/3/whatsnew/3.13.html), [3.14](https://docs.python.org/3/whatsnew/3.14.html) and [3.15](https://docs.python.org/3/whatsnew/3.15.html) (release highlights, the 3.15 examples and the text on UTF-8). The pages carried the banner "Python 3.15.2 documentation".
- Django documentation: [How to upgrade Django to a newer version](https://docs.djangoproject.com/en/stable/howto/upgrade-version/) (deprecation warnings are silenced by default).
- uv documentation: [Locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/) (`uv lock` creates or updates the lock file).
- Run on 2026-10-30: the two feature modules and the construct table on Python 3.14.8 (macOS, Homebrew) and 3.12.15 (Docker image `python:3.12-alpine`, without network); Ruff 0.17.3 for the target matrix and `--diff`; uv 0.13.6 for `uv python pin`; pytest 9.2.0 for the warning filters (its output points to the page "How to capture warnings" of the pytest documentation, which was not read). Python 3.11, 3.13 and 3.15 were not available, so their rows rest on the documentation, and features that exist on both 3.12 and 3.14 were run on both.
