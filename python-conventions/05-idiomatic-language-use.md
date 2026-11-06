# Python Idiomatic Language Use

## Summary

Idiomatic Python reads like the plain description of what it does: truthiness and `is None` for emptiness and absence, `try`/`except` for the rare failure (EAFP), comprehensions and generators for transforming sequences, `with` for resources, `pathlib` for paths, f-strings for text, and `enumerate`/`zip` instead of index arithmetic. The rules below come from PEP 8, the Python glossary and the Ruff rule documentation; each behaviour that the notes rely on was run on Python 3.14 and 3.12.

## Rules

### Truthiness, None and identity

- Test emptiness with the truthiness of the object: `if items:` and `if not items:`, not `if len(items)` (PEP 8). Empty strings, lists, dicts and zero are false.
- Compare with `None` using `is` and `is not`, never `==`. Beware `if x:` when you mean `if x is not None:`: `0`, `""` and `[]` are false but valid values (PEP 8).
- Do not compare booleans with `True` or `False` (`if flag:`, not `if flag == True:`). Use `isinstance(x, int)`, not `type(x) == int` (PEP 8).
- A default that would be a mutable object is `None` plus an `if ... is None` branch. A mutable default is evaluated once and shared by all calls (checked: two calls returned `[1, 2]` and `[1, 2]` for the same list):

```python
# wrong
def collect(item, items=[]):
    items.append(item)
    return items
```

```python
def collect(item: str, items: list[str] | None = None) -> list[str]:
    """Return ``items`` with ``item`` appended, without sharing state between calls."""
    if items is None:
        items = []
    items.append(item)
    return items
```

### Errors: EAFP and short try blocks

- Python code usually follows EAFP, "easier to ask for forgiveness than permission": assume the key or attribute exists and handle the exception. LBYL ("look before you leap") tests first and is open to a race condition in threaded code: the key can disappear between the test and the lookup (Python glossary).
- Keep the `try` body to the single statement that can raise, and put the rest in `else`, so that an unrelated `KeyError` is not swallowed (PEP 8):

```python
def read_setting(config: dict[str, str], key: str) -> str | None:
    """Return the stripped value for ``key``, or ``None`` when it is missing."""
    try:
        value = config[key]
    except KeyError:
        return None
    else:
        return value.strip()
```

- For the plain "value or default" case use `config.get(key)` or `config.get(key, default)`, and `collections.defaultdict` or `dict.setdefault` for "create on first use". The full rules for exceptions are in the error handling note ([errors](08-error-handling-and-logging.md)).

### Comprehensions and generators

- Build a list, set or dict from an iterable with a comprehension, not with an append loop. Feed `sum`, `max`, `min`, `any` and `all` with a generator expression and no brackets: it stays lazy and uses no list (checked: a list of 100,000 items is larger than the generator object).
- A comprehension with more than two `for` clauses, or with side effects, is a loop. Write the loop.
- A generator function (`yield`) produces values on demand: calling it runs nothing until the first `next()` (checked).

```python
from collections.abc import Iterable, Iterator

def normalized(words: Iterable[str]) -> list[str]:
    """Return the unique lowercase words, sorted."""
    return sorted({word.casefold() for word in words})

def squares(limit: int) -> Iterator[int]:
    """Yield the squares of 0 to ``limit - 1`` one at a time."""
    for n in range(limit):
        yield n * n

even_total = sum(n for n in squares(5) if n % 2 == 0)
```

### Loops

- Loop over the items, not over indexes: `for item in items`, `for index, item in enumerate(items, start=1)`, `for key, value in mapping.items()`.
- Pair iterables with `zip(a, b, strict=True)`. Without `strict` a shorter iterable silently truncates the result; with it a length mismatch raises `ValueError: zip() argument 2 is shorter than argument 1` (Python 3.10; checked; Ruff B905).
- Sort with `sorted(items, key=len)` or `key=attrgetter("name")`, not with a comparison function.

```python
names = ["ada", "bob"]
scores = [0.9, 0.7]
for rank, (name, score) in enumerate(zip(names, scores, strict=True), start=1):
    print(f"{rank}. {name}: {score:.1f}")
```

### Text, files and paths

- Format text with f-strings (`f"{name}: {score:.1f}"`; `f"{value=}"` prints the expression and its value for debugging). Join pieces with `"".join(parts)` rather than `+=` in a loop (PEP 8). Use `startswith` and `endswith` instead of slicing, and `removeprefix` and `removesuffix` to cut a known prefix or suffix (checked).
- Use `pathlib.Path` for paths and files, with `/` to join and `read_text`, `write_text`, `open`, `exists`, `glob` and `mkdir(parents=True, exist_ok=True)` as methods. Ruff's `PTH` rules point at `os.path` and `open()` calls.
- Always pass `encoding="utf-8"` when opening text. Without it the platform decides. `python -X warn_default_encoding` emits an `EncodingWarning` for each call without the argument (checked on 3.12 and 3.14); Python 3.15 makes UTF-8 the default (PEP 686).
- Use `with` for every resource (files, locks, connections). When a context manager does more than acquire and release, call it through a function whose name says what it does (`with conn.begin_transaction():`, not `with conn:`) (PEP 8).

```python
from pathlib import Path

def line_count(path: Path) -> int:
    """Return the number of lines in a UTF-8 text file."""
    with path.open(encoding="utf-8") as handle:
        return sum(1 for _ in handle)
```

### Functions

- Return early and keep the main path unindented. Make `return` consistent: either every path returns a value, or none does; where a function returns a value, write `return None` explicitly (PEP 8; Ruff's `RET`).
- Name a function with `def`; do not bind a `lambda` to a name: the function would be called `<lambda>` in tracebacks (PEP 8; E731).
- A closure in a loop sees the variable, not its value at that time: `[lambda: i for i in range(3)]` returns `[2, 2, 2]` (checked; Ruff B023). Bind the value with `functools.partial`:

```python
# wrong
callbacks = [lambda: i for i in range(3)]
print([callback() for callback in callbacks])
```

```python
from functools import partial

def identity(value: int) -> int:
    """Return ``value`` unchanged."""
    return value

callbacks = [partial(identity, i) for i in range(3)]
print([callback() for callback in callbacks])
```

- Do not use `*args` and `**kwargs` unless the function passes them on. Details of signatures are in the API design note ([API design](07-api-and-class-design.md)).

### Data and collections

- Use `collections.Counter`, `defaultdict` and `deque` before writing the loop yourself; merge dicts with `a | b` or `{**a, **b}` (checked).
- Use a `dataclass` or `NamedTuple` instead of a bare tuple or dict that has fixed fields ([types](06-types-and-data-modeling.md)).

```python
from collections import Counter, defaultdict

words = ["red", "blue", "red", "green", "blue", "red"]
counts = Counter(words)
by_length: defaultdict[int, list[str]] = defaultdict(list)
for word in counts:
    by_length[len(word)].append(word)
print(counts.most_common(2), dict(by_length))
```

### Context managers

- Write a context manager as a generator with `@contextlib.contextmanager`, and put the cleanup in `finally`. `contextlib.suppress` ignores one named exception around one statement (Ruff SIM105 asks for it instead of `try`/`except`/`pass`).

```python
import contextlib
import time
from collections.abc import Iterator

@contextlib.contextmanager
def timed(label: str) -> Iterator[None]:
    """Print how long the body of the ``with`` block took."""
    start = time.perf_counter()
    try:
        yield
    finally:
        print(f"{label}: {time.perf_counter() - start:.3f}s")

cache = {"a": 1}
with timed("cleanup"), contextlib.suppress(KeyError):
    del cache["missing"]
```

### Modern syntax

- Use `match` for structured data with several shapes (Python 3.10). The `_` case handles the rest. Use the walrus operator `:=` only when it removes a repeated call and the result still reads well (Python 3.8).

```python
import re

def describe(event: dict[str, object]) -> str:
    """Return a short description of an event."""
    match event:
        case {"type": "login", "user": str(user)}:
            return f"{user} logged in"
        case {"type": "logout"}:
            return "someone logged out"
        case _:
            return "unknown event"

if (found := re.search(r"\d+", "order 66")) is not None:
    print(found.group())
```

### Programs

- A program's entry point is a function that returns the exit status, called under a guard so that importing the module runs nothing:

```python
import sys

def main() -> int:
    """Run the program and return its exit status."""
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### Worked example: area of a circle

The following tests check this function:

```python
# before
import math

def area_of_circle(radius):
    if type(radius) not in [int, float]:
        raise TypeError("Radius must be a number")
    if radius < 0:
        raise ValueError("Radius must be non-negative")
    return math.pi * radius**2
```

The `type(...) in [...]` check rejects every subclass of `int` and `float`, `bool`, and numbers such as `fractions.Fraction`, which work fine in the formula (PEP 8 asks for `isinstance` for this reason). The idiomatic version drops the check, because the comparison `radius < 0` already raises `TypeError` for a string, documents the contract in the signature and the docstring, and lets mypy check the callers:

```python
import math

def area_of_circle(radius: float) -> float:
    """Return the area of a circle.

    Args:
        radius: Radius of the circle. Must not be negative.

    Returns:
        The area, in the square of the unit of ``radius``.

    Raises:
        ValueError: If ``radius`` is negative.
    """
    if radius < 0:
        raise ValueError(f"radius must be non-negative, got {radius}")
    return math.pi * radius**2
```

The three tests pass unchanged against this version when run by pytest, and the pytest version of the tests is in the testing note ([testing](10-testing.md#worked-example)).

### Mistakes and their replacements

The wrong forms were run through Ruff 0.17.3 with the rule set of the tooling note; the codes are what it printed.

| Wrong | Right | Ruff | Source |
| --- | --- | --- | --- |
| `def f(items=[])` | `items=None` and `if items is None` | B006 | Ruff, Python docs |
| `type(x) == int` | `isinstance(x, int)` | E721 | PEP 8 |
| `x == None` | `x is None` | E711 | PEP 8 |
| `x == True` | `if x:` | E712 | PEP 8 |
| bare `except:` | `except Exception:` or a specific class | E722 | PEP 8 |
| `raise New(...)` inside `except` | `raise New(...) from err` | B904 | PEP 8 |
| `f = open(path)` | `with Path(path).open(encoding="utf-8") as f:` | SIM115, PTH123 | PEP 8 |
| `import os, sys` | one module per line | E401 | PEP 8 |
| `l = []` | a descriptive name | E741 | PEP 8 |
| `f = lambda x: ...` | `def f(x): ...` | E731 | PEP 8 |
| `d = dict()` | `d = {}` | C408 | Ruff |
| `else` after `return` | drop the `else` | RET505 | Ruff |
| `from typing import List, Optional` | `list[str] \| None` | UP035, UP006, UP045 | typing best practices |
| `logging.info(f"x {y}")` | `logging.info("x %s", y)` | G004 | logging docs, Django |
| `datetime.datetime.now()` | `datetime.now(UTC)` | DTZ005 | Ruff |
| `class C: items = []` | `field(default_factory=list)` | RUF012 | Ruff |
| `try: ... except: pass` | `contextlib.suppress(...)` | SIM105, S110 | Ruff |

## Sources and raw notes

Pages read on 2026-10-30:

- [PEP 8](https://peps.python.org/pep-0008/): programming recommendations (None, isinstance, boolean comparisons, sequences, startswith, return statements, lambda, exceptions, resources).
- Python documentation: [glossary](https://docs.python.org/3/glossary.html) (EAFP, LBYL), [What's new in Python 3.10](https://docs.python.org/3/whatsnew/3.10.html) (`match`, `zip(strict=)`) and [3.15](https://docs.python.org/3/whatsnew/3.15.html) (UTF-8 default).
- Rule explanations from `ruff rule` for B006, B008, B904, B905, E722, UP006, UP007, UP035, G004, PTH123, DTZ005, RET505, SIM102, C408, RUF012 and A001 (Ruff 0.17.3).
- Behaviour marked "checked" was run on Python 3.14.8 and 3.12.15. Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes.
