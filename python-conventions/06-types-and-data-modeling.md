# Python Types and Data Modeling

## Summary

Public functions and methods are fully annotated, and mypy in strict mode checks them. Parameters take abstract types (`Iterable`, `Mapping`), results are concrete (`list`, `dict`), absence is `X | None`, and `object` replaces `Any` wherever "anything" is meant. Data with a fixed shape is a frozen dataclass, a `NamedTuple` or a `TypedDict`; a closed set of values is an enum; an interface is a `Protocol`. Annotations are not enforced at run time, so data from outside is parsed at the boundary.

## Rules

### Annotate the public surface

- Annotate every parameter and the return type of every function and method that other code calls, including `-> None`. Locals are inferred, so annotate them only when the inferred type is wrong or too narrow (`counts: dict[str, int] = {}`). Tests are annotated too (`-> None`).
- Follow the typing council's best practices:
  - For parameters prefer protocols and abstract types (`Iterable`, `Sequence`, `Mapping`); for return values prefer the concrete type (`list`, `dict`). Avoid union return types, which force `isinstance` checks on every caller.
  - If a function accepts any object, annotate `object`, not `Any`; the same for the result of a callback that is ignored. Use `Any` only where the type system cannot express the type.
  - Write unions as `X | None`, with `None` last, not `Optional[X]` or `Union`; use `list[str]`, `dict[str, int]` and `type[C]`, not `typing.List`, `Dict` or `Type`; use `float` instead of `int | float`.
  - Mark an alias of a type with `type Name = ...` (Python 3.12) or `TypeAlias`, and only for types.

```python
from collections.abc import Iterable, Mapping


def word_counts(lines: Iterable[str]) -> dict[str, int]:
    """Return how often each word occurs in ``lines``."""
    counts: dict[str, int] = {}
    for line in lines:
        for word in line.split():
            counts[word] = counts.get(word, 0) + 1
    return counts


def describe(value: object) -> str:
    """Return ``value`` as text; accepts any object."""
    return str(value)


def lookup(table: Mapping[str, int], key: str) -> int | None:
    """Return the entry for ``key``, or ``None`` when it is missing."""
    return table.get(key)
```

### Checking with mypy

- mypy runs in strict mode in CI and in the editor ([tooling](02-project-setup-and-tooling.md#mypy)). These are the errors it reported for the usual mistakes (mypy 2.4.1):

```python
# wrong
from typing import Any


def parse(data):
    return data["x"]


def total(values: list) -> int:
    return sum(values)


def first(xs: list[int]) -> int:
    return xs[0] if xs else None


def load() -> Any: ...


def use() -> int:
    return load()


x: int = "a"
```

| Error code | Message | Fix |
| --- | --- | --- |
| `no-untyped-def` | Function is missing a type annotation | Annotate parameters and the result |
| `type-arg` | Missing type arguments for generic type `list` | Write `list[int]`, not `list` |
| `return-value` | Incompatible return value type (got `int \| None`, expected `int`) | Return the right type, or declare `int \| None` |
| `no-any-return` | Returning `Any` from a function declared to return `int` | Narrow the value before returning it |
| `assignment` | Incompatible types in assignment | Fix the value or the annotation |

- Do not silence an error with a bare `# type: ignore`. Name the code (`# type: ignore[arg-type]`) and leave a reason when it is not obvious. In strict mode a stale ignore is itself an error. Use `cast` rarely, and prefer an `isinstance` check, which the checker understands.
- A library marks itself typed with an empty `py.typed` file in the package (`uv init --lib` creates it) and annotates its whole public API. A dependency without types gets a `types-<name>` stub package in the `dev` group.

### Shape of data

| Need | Use |
| --- | --- |
| A record with named, typed fields | `@dataclass(frozen=True, slots=True, kw_only=True)` |
| A tuple that must stay a tuple | `typing.NamedTuple` |
| A dict with known keys, from JSON | `typing.TypedDict` |
| A closed set of values | `enum.Enum`, or `enum.StrEnum` for string values (Python 3.11) |
| A fixed set of literal values in a signature | `typing.Literal["a", "b"]` |
| An interface that any matching class satisfies | `typing.Protocol` |
| A constant that must not be rebound | `typing.Final` |

- A frozen dataclass is hashable and compares by value; `slots=True` removes the per-instance `__dict__` and rejects assignment to unknown attributes; `kw_only=True` makes callers name the fields, so adding a field never breaks a call (checked: assigning raises `FrozenInstanceError`, there is no `__dict__`, equal instances have equal hashes, and a positional argument raises `TypeError`). Use `dataclasses.replace` to make a modified copy.
- A mutable default in a dataclass is `field(default_factory=...)`, never a literal list or dict (Ruff RUF012 for class attributes).
- A `StrEnum` member is a string: `Status.NEW == "new"` is true and `f"{Status.NEW}"` is `new` (checked).

```python
from dataclasses import dataclass, field, replace
from enum import StrEnum
from typing import Self


class Status(StrEnum):
    """Stage of an application."""

    NEW = "new"
    REVIEWED = "reviewed"
    HIRED = "hired"


@dataclass(frozen=True, slots=True, kw_only=True)
class Candidate:
    """A person who applied for a job."""

    name: str
    email: str
    status: Status = Status.NEW
    skills: frozenset[str] = field(default_factory=frozenset)

    def with_status(self, status: Status) -> Self:
        """Return a copy of the candidate with a new status."""
        return replace(self, status=status)


ada = Candidate(name="Ada", email="ada@example.com")
print(ada.with_status(Status.REVIEWED))
```

### Interfaces and generics

- Depend on behaviour, not on a class: a `Protocol` lists the methods that a collaborator needs, and any class with those methods satisfies it, without inheriting from anything. That is how the code stays testable ([API design](07-api-and-class-design.md#dependencies)).
- Write generic functions and aliases with the Python 3.12 syntax: `def first[T](items: Sequence[T]) -> T:` and `type Pair[A, B] = tuple[A, B]` (checked on 3.12 and 3.14; it is a syntax error before 3.12). Name a type variable `T` when it is generic over one thing, and with `_co` or `_contra` when it is declared covariant or contravariant in the older syntax.
- Mark an overriding method with `@override` (`typing.override`, Python 3.12) so that the checker flags a method that no longer overrides anything.

```python
from collections.abc import Sequence
from typing import Protocol, TypedDict


class Notifier(Protocol):
    """Anything that can send a message."""

    def send(self, to: str, body: str) -> None:
        """Send ``body`` to ``to``."""
        ...


class ConsoleNotifier:
    """Print messages instead of sending them."""

    def send(self, to: str, body: str) -> None:
        """Print ``body`` for ``to``."""
        print(f"to {to}: {body}")


def notify_all(notifier: Notifier, recipients: Sequence[str], body: str) -> None:
    """Send ``body`` to every recipient."""
    for recipient in recipients:
        notifier.send(recipient, body)


def first[T](items: Sequence[T]) -> T:
    """Return the first item."""
    return items[0]


class JobPosting(TypedDict):
    """Shape of a job posting returned by an API."""

    title: str
    company: str


notify_all(ConsoleNotifier(), ["ada", "bob"], "welcome")
print(first([3, 4]))
```

### Annotations at run time

- A union written with `|` works in annotations at run time on 3.10 and newer (checked). In Python 3.14 annotations are evaluated lazily (PEP 649), so a forward reference works without quotes and without `from __future__ import annotations`: `def f(x: Undefined) -> None` defines fine on 3.14 and raises `NameError` on 3.12 (checked). A project whose `requires-python` is below 3.14 quotes its forward references or imports the future feature.
- Import a name only for its annotation under `if TYPE_CHECKING:` when that breaks an import cycle.
- Annotations are not enforced. A function annotated `radius: float` still receives whatever the caller passes. Parse and validate data from outside (JSON, forms, files, environment) once, at the boundary, with explicit code or a validation library, and pass typed objects inside.

## Sources and raw notes

Pages read on 2026-10-30:

- [Typing best practices](https://typing.python.org/en/latest/reference/best_practices.html) (typing documentation): aliases, `Any` and `object`, argument and return types, union shorthand, built-in generics.
- [PEP 8](https://peps.python.org/pep-0008/): function and variable annotations, stub files.
- [mypy command line](https://mypy.readthedocs.io/en/stable/command_line.html) (mypy 2.4.1) and the mypy output printed for the examples above.
- [What's new in Python](https://docs.python.org/3/whatsnew/3.14.html) 3.10 to 3.15: `X | Y`, `Self`, `StrEnum`, `type` statements and generics syntax, `override`, deferred evaluation of annotations.
- Rule explanations from `ruff rule` for UP006, UP007, UP035 and RUF012 (Ruff 0.17.3).
- Behaviour marked "checked" was run on Python 3.14.8 and 3.12.15 with mypy 2.4.1 and Ruff 0.17.3. Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes.
