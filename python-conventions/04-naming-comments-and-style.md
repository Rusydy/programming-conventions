# Python Naming, Comments and Style

## Summary

The style is PEP 8, applied by `ruff format` (the Black style) and `ruff check`, with docstrings that follow PEP 257 and use the Google section layout. Four spaces, 88 columns, double quotes, names in `snake_case` and `CapWords`, absolute imports in three groups. Where the sources disagree, the last section says which one wins and why.

## Rules

### Formatting

`ruff format` applies this list; do not format by hand ([tooling](02-project-setup-and-tooling.md#ruff)).

- Four spaces per indentation level, never tabs. Lines have at most 88 characters. PEP 8 says 79 (72 for comments and docstrings) and allows a team to agree on up to 99; 88 is the Black and Ruff default, and Django uses it for code too ([where the guides disagree](#where-the-guides-disagree)). Wrap comments and docstrings at about 72 characters by habit; no rule enforces it.
- Double quotes, because the formatter writes them and PEP 8 has no preference. Triple-quoted strings and docstrings always use `"""` (PEP 257).
- Wrap long lines inside parentheses, brackets and braces, not with a backslash. Put one item per line with a trailing comma when a call, collection or signature does not fit on one line; the formatter treats that "magic trailing comma" as a request to keep it exploded and produces smaller diffs.
- Break before a binary operator in a multi-line expression (PEP 8 suggests it, and the formatter does it).
- Two blank lines around top-level functions and classes, one between methods, and blank lines inside functions only to mark logical sections.
- One statement per line: no `;`, and no `if x: do()` on one line. Source files are UTF-8 without an encoding declaration.
- Whitespace: none inside brackets or before a call's parenthesis, one space around binary operators and `=` in assignments, none around `=` for keyword arguments and for defaults without annotation, one on each side for annotated defaults (`def f(x: int = 0)`).

```python
import re
from collections.abc import Iterable


def keyword_score(
    text: str,
    keywords: Iterable[str],
    *,
    ignore_case: bool = True,
) -> float:
    """Return the share of ``keywords`` that appear in ``text``."""
    if ignore_case:
        text = text.casefold()
        keywords = [word.casefold() for word in keywords]
    wanted = set(keywords)
    if not wanted:
        return 0.0
    found = set(re.findall(r"\w+", text)) & wanted
    return len(found) / len(wanted)
```

### Naming

| Thing | Form | Example |
| --- | --- | --- |
| Package | short, lowercase, no underscores | `scoring` |
| Module | short, lowercase, underscores allowed | `keyword_match.py` |
| Class, exception | `CapWords`; acronyms stay capitalised; exceptions end in `Error` | `KeywordMatcher`, `HTTPServerError`, `ScoringError` |
| Function, method, variable | `lower_case_with_underscores` | `keyword_score`, `found` |
| Constant | `UPPER_CASE_WITH_UNDERSCORES`, defined at module level | `MAX_KEYWORDS` |
| Type variable | short `CapWords`; `_co` or `_contra` for variance | `T`, `KeyT_contra` |
| Internal name | one leading underscore | `_normalize`, `_internal.py` |
| Keyword clash | one trailing underscore | `class_` |
| First argument | `self` for instance methods, `cls` for class methods | |

- Never use `l`, `O` or `I` as single-character names (PEP 8). Do not reuse the name of a builtin for a variable or function; Ruff's `A` rules catch it (`id`, `input`, `type`, `list`, `max`).
- Names visible to users reflect usage, not implementation (PEP 8). Use English words and ASCII identifiers.
- A non-public attribute gets one leading underscore. Use a double leading underscore (name mangling) only to avoid a collision with attributes of subclasses in a class designed for inheritance (PEP 8). Never invent `__dunder__` names; use only the documented ones.
- Decide for every attribute whether it is public. When in doubt make it non-public: that is easier to relax later (PEP 8).
- A boolean is named as a predicate or a state (`is_valid`, `has_access`, `dry_run`), and a function that returns one reads as a question.

```python
import re
from collections.abc import Iterable

MAX_KEYWORDS = 50


class ScoringError(Exception):
    """Raised when a resume cannot be scored."""


class KeywordMatcher:
    """Find keywords in text."""

    def __init__(self, keywords: Iterable[str]) -> None:
        self._keywords = frozenset(word.casefold() for word in keywords)

    def matches(self, text: str) -> set[str]:
        """Return the keywords that appear in ``text``."""
        return set(re.findall(r"\w+", text.casefold())) & self._keywords
```

### Imports

- Imports are at the top of the file, after the module docstring and `__all__`, one module per line, in three groups separated by a blank line: standard library, third party, local. Ruff's `I` rules sort them.
- Absolute imports inside a package; no `from module import *` (PEP 8). Import the module, not the class, when the name would clash.

### Docstrings

- Write a docstring for every public module, class, function and method, and for packages in `__init__.py`. Ruff's `D` rules, with the `google` convention, enforce it. A non-public function needs a comment about what it does, not a docstring (PEP 8).
- PEP 257: triple double quotes; a one-line summary that is an imperative phrase ending in a period ("Return the area", not "Returns the area" and not a restated signature); for a multi-line docstring, a blank line after the summary, then the description, and the closing quotes on a line of their own.
- Describe behaviour, arguments, return values, exceptions and side effects when they are not obvious. Use the Google section layout, which most documentation tools understand: `Args:`, `Returns:`, `Raises:`, `Yields:`. Do not repeat types in the sections, because the signature carries them.
- A class docstring summarises the class and its public interface; the constructor is documented by the class docstring or by `__init__`. A script's docstring doubles as its usage message (PEP 257).

```python
from collections.abc import Mapping


class ScoringError(Exception):
    """Raised when a resume cannot be scored."""


def best_match(text: str, candidates: Mapping[str, set[str]]) -> str:
    """Return the name of the candidate whose keywords fit ``text`` best.

    Ties go to the candidate that comes first in ``candidates``.

    Args:
        text: The text to score, for example the body of a resume.
        candidates: Candidate names mapped to their lowercase keywords.

    Returns:
        The name of the best candidate.

    Raises:
        ScoringError: If ``candidates`` is empty.
    """
    if not candidates:
        raise ScoringError("no candidates to compare")
    words = set(text.casefold().split())
    return max(candidates, key=lambda name: len(words & candidates[name]))
```

### Comments

- A comment explains why, not what. Comments that contradict the code are worse than none, so update them with the code. Write complete sentences in English (PEP 8).
- A block comment is indented like the code it describes and starts with `# `. An inline comment is separated from the code by two spaces and used sparingly.
- Delete dead code instead of commenting it out; version control keeps it.
- Type-checker and linter directives name the code and give a reason: `# type: ignore[arg-type]`, `# noqa: S101`.

### Where the guides disagree

| Topic | What the sources say | Decision and reason |
| --- | --- | --- |
| Line length | PEP 8: 79 (72 for docstrings and comments); a team may raise code to 99. Black and Ruff: 88. Django: 88 for code, 79 for comments and docstrings | 88, enforced by `E501` and the formatter. It is inside the range PEP 8 allows, it is the default of the tool, and Django uses it |
| Quotes | PEP 8: pick one. Ruff and Black: double | Double, the formatter default; PEP 257 requires `"""` for docstrings |
| Docstring format | PEP 257 fixes the shape of the first line only. Google, NumPy and reST layouts are all in use | Google sections, through `convention = "google"` in Ruff |
| Binary operators | PEP 8: break before the operator is suggested; either is allowed | Before the operator, as the formatter writes it |
| Relative imports | PEP 8: absolute are recommended, explicit relative are acceptable | Absolute |
| `except (A, B)` | PEP 758 (3.14) allows `except A, B:` without parentheses when there is no `as` | Keep what the formatter writes, and set `requires-python` to match (it rewrites the parentheses away for 3.14 and newer) |
| Type hints | Older code uses `typing.List` and `Optional`; the typing best practices page prefers built-in generics and `X \| None` | Built-in generics and `\|` ([types](06-types-and-data-modeling.md)) |
| Strings in log calls | An f-string is the usual choice elsewhere; Django says not to use f-strings for logging or error messages, and Ruff's `G004` flags them | `%s` arguments in `logging` calls ([errors and logging](08-error-handling-and-logging.md#logging)) |

## Sources and raw notes

Pages read on 2026-10-30:

- [PEP 8](https://peps.python.org/pep-0008/) (read in full): layout, imports, whitespace, comments, naming, public and internal interfaces, programming recommendations.
- [PEP 257](https://peps.python.org/pep-0257/): docstring conventions.
- Django documentation: [Coding style](https://docs.djangoproject.com/en/stable/internals/contributing/writing-code/coding-style/) (black, 88 and 79 columns, f-strings and translation, isort).
- Ruff documentation: [The Ruff Formatter](https://docs.astral.sh/ruff/formatter/); defaults from `ruff check --show-settings` (88 columns, double quotes, spaces, magic trailing comma respected).
- Rule explanations from `ruff rule` for `A001`, `D203`, `G004`, `ISC001` and `COM812` (Ruff 0.17.3).
- The `google` docstring convention and the `except` rewrite were run with Ruff 0.17.3. Every `python` block without a `# fragment` or `# wrong` first line was checked as the principles note describes.
