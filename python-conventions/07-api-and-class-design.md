# Python API and Class Design

## Summary

A function does one thing, takes the few arguments it needs, and uses keyword-only parameters for options. A class exists to hold state or to satisfy an interface; plain data is a dataclass, and behaviour is built by composition more often than by inheritance. Collaborators, the clock and randomness are passed in, which keeps code testable. Public names are documented and few, and an API changes by deprecating first.

## Rules

### Functions

- A function does one thing, has a name that says what, and is short enough to read at once. Prefer functions to classes when there is no state.
- Make options keyword-only with `*`, and make arguments that should never be named positional-only with `/`. A boolean flag that changes behaviour is a design smell: use two functions, an enum, or at least a keyword-only parameter so that calls read `export(data, compress=True)`.
- Give defaults that are immutable, or `None` and build the object inside ([idioms](05-idiomatic-language-use.md#truthiness-none-and-identity)). Do not call a function in a default argument: it runs once, at definition (Ruff B008).
- Use `*args` and `**kwargs` only to pass arguments on to another call. Otherwise name the parameters, so that the signature documents the function and mypy can check it.
- Return one kind of thing. Return `None` for "nothing" only when the signature says `| None`; raise an exception for failure rather than returning a special value ([errors](08-error-handling-and-logging.md)).
- A function that takes a long list of related arguments takes one object instead (a dataclass).

```python
from collections.abc import Sequence
from pathlib import Path


def export_rows(
    rows: Sequence[Sequence[str]],
    path: Path,
    /,
    *,
    delimiter: str = ",",
    header: Sequence[str] | None = None,
) -> int:
    """Write ``rows`` to ``path`` and return how many lines were written.

    Args:
        rows: The rows to write.
        path: Destination file.
        delimiter: Separator between the columns.
        header: Optional header line.

    Returns:
        The number of lines written, the header included.
    """
    lines = [delimiter.join(row) for row in rows]
    if header is not None:
        lines.insert(0, delimiter.join(header))
    path.write_text("\n".join(lines), encoding="utf-8")
    return len(lines)
```

### Classes

- Use a class when data and behaviour belong together, or to satisfy an interface. A `@dataclass` is the default for data ([types](06-types-and-data-modeling.md#shape-of-data)); it writes `__init__`, `__repr__` and `__eq__` for you.
- Expose simple data as plain attributes. If it later needs logic, turn it into a `@property` with the same name; the callers do not change. Keep properties cheap and free of side effects, because attribute access suggests a cheap operation (PEP 8). Use `functools.cached_property` for a value that is expensive and stable.
- Prefer composition: hold a collaborator and call it. Inherit to specialise a base class that was designed for it, and then decide which attributes belong to the subclass API, which are public, and which are private (PEP 8). Keep hierarchies shallow.
- Alternative constructors are `@classmethod`s that return `cls(...)`. `@staticmethod` is rarely worth it; a module-level function says the same.
- Implement all six ordering methods or use `functools.total_ordering` when a class defines an order (PEP 8). Define `__eq__` and `__hash__` together; a frozen dataclass does it.
- Write the special methods that exist (`__repr__`, `__eq__`, `__iter__`, `__enter__`, `__exit__`); never invent a `__dunder__` name (PEP 8). `__repr__` should help a developer: the class name and the fields.
- Use `super()` to call the parent, and keep `__init__` free of work that can fail or block; build resources in a factory or a context manager.

### Public and internal names

- Anything documented is public, and the rest is internal (PEP 8). A name with one leading underscore is internal, and the public names of a module are listed in `__all__` ([layout](03-project-layout-and-packages.md#public-api)).
- Backwards compatibility applies only to the public names. Everything else may change in any release.
- When in doubt, make an attribute non-public; it is easier to make it public later than the opposite (PEP 8).

### Dependencies

- A function or class receives what it needs as a parameter instead of creating it or importing a global: the database session, the HTTP client, the clock, the random generator. The test then passes a fake. Describe the dependency with a `Protocol` ([types](06-types-and-data-modeling.md#interfaces-and-generics)).
- Time is the most common hidden dependency. Use timezone-aware datetimes (`datetime.now(UTC)`; Ruff DTZ005 flags `datetime.now()` without a time zone) and inject a clock where the code must be tested at a given time.
- No mutable module-level state. A module-level constant is fine; a module-level cache or connection that functions mutate is global state, and it makes tests depend on order.

```python
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime


@dataclass(frozen=True, slots=True)
class Token:
    """A token that expires."""

    value: str
    expires_at: datetime

    def is_valid(self, now: Callable[[], datetime] = lambda: datetime.now(UTC)) -> bool:
        """Return whether the token has not expired yet at ``now()``."""
        return now() < self.expires_at


token = Token("abc", datetime(2030, 1, 1, tzinfo=UTC))
print(token.is_valid(), token.is_valid(now=lambda: datetime(2031, 1, 1, tzinfo=UTC)))
```

### Changing an API

- A public function or class is a promise. Add keyword-only parameters with defaults instead of changing positional ones. Keep old names working for at least one release, and say so in the docs.
- Mark the old name deprecated with `warnings.deprecated` (Python 3.13: `@deprecated("use new() instead")` makes the call emit a `DeprecationWarning` and tells type checkers). On older versions call `warnings.warn(msg, DeprecationWarning, stacklevel=2)` so that the warning points at the caller (checked: `warnings.deprecated` works on 3.14 and is an `ImportError` on 3.12).
- Remove a deprecated name only in a release that the version number marks as breaking.

## Sources and raw notes

Pages read on 2026-10-30:

- [PEP 8](https://peps.python.org/pep-0008/): public and internal interfaces, designing for inheritance, properties, rich comparisons, naming of special methods.
- Python documentation: [What's new in Python 3.13](https://docs.python.org/3/whatsnew/3.13.html) (`warnings.deprecated`), `dataclasses`, `functools` and `warnings` module documentation.
- Rule explanations from `ruff rule` for B006, B008 and DTZ005 (Ruff 0.17.3).
- [Typing best practices](https://typing.python.org/en/latest/reference/best_practices.html) (argument and return types, protocols).
- Behaviour marked "checked" was run on Python 3.14.8 and 3.12.15. Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes.
