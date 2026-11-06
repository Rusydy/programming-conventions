# Python Project Layout and Packages

## Summary

An installable project uses the src layout: the importable package lives in `src/<package>/`, the tests in `tests/`, and everything that describes the project in the root. Modules are small, named for what they contain, import each other with absolute imports, and declare their public API. A command is a function that returns an exit status, wired in `[project.scripts]` and run with `python -m package`. One-file scripts carry their dependencies in a PEP 723 block. A web framework keeps the layout its own generator creates.

## Rules

### Layout

```text
project/
  pyproject.toml        project metadata and the configuration of every tool
  uv.lock               exact versions (commit it)
  .python-version       interpreter of the project (commit it)
  README.md
  src/
    demo/               the importable package
      __init__.py       package docstring, and the public re-exports
      __main__.py       python -m demo
      circle.py         one module per cohesive topic
      cli.py            command-line entry point
      py.typed          marker file in a library that ships its types
  tests/
    test_circle.py      one test module per module under test
```

- Use the src layout for anything that is installed or run as a package. The PyPA guide describes the effect: the package must be installed to be imported, which stops tests from accidentally using the in-development copy through the current directory, and an editable install can import only the files meant to be importable. `uv sync` performs the editable install. pytest's guide also says to prefer it, especially with the default import mode.
- Tests live in `tests/`, outside the package, so that they run against the installed package. They need no `__init__.py` in the `importlib` import mode of the tooling note.
- A web framework keeps the layout of its generator (`manage.py` in the root for Django); the platform note shows it ([Django](12-platform-practices.md#django)).
- Root files: `README.md`, `LICENSE` for a published project, `.gitignore` with `.venv/`, caches and `dist/`. Commit `uv.lock` and `.python-version`.
- A project without `[build-system]` is a collection of scripts; give anything with more than one module a build system so that imports work the same everywhere.

### Modules and packages

- A module holds one cohesive topic and is small enough to read in one sitting. Name it by what it contains, not by how it is implemented. Module names are short and lowercase, underscores allowed; package names are short and lowercase and avoid underscores (PEP 8).
- Imports go at the top of the file, one module per line, in three groups separated by a blank line: standard library, third party, local. Ruff's `I` rules sort them. Use absolute imports (`from demo.circle import area_of_circle`); explicit relative imports are acceptable inside a package with a complex layout. No wildcard imports (PEP 8).
- Avoid import cycles by structure: move the shared piece into a module both can import. When a type is needed only for annotations, import it under `if TYPE_CHECKING:` ([types](06-types-and-data-modeling.md)).
- Module-level code only defines things: constants, functions, classes. Anything that runs (reading files, opening connections, starting threads) goes in a function that is called on purpose.
- Every module and package has a docstring: the first statement of the file, one line for a small module. The docstring of `__init__.py` documents the package (PEP 257). Ruff's `D104` fails an empty `__init__.py`, which is how the sample project found its missing docstring.

### Public API

- Anything documented is public; everything else is internal (PEP 8). Prefix internal names with one underscore: `_helper`, `_internal.py`. Imported names are an implementation detail unless the module re-exports them on purpose.
- Declare the public API of a module or package in `__all__`, after the module docstring and before the imports, and re-export from `__init__.py` what users should import from the package root:

```python
"""Geometry helpers."""

from demo.circle import area_of_circle

__all__ = ["area_of_circle"]
```

- Without a leading underscore and without `__all__`, a name is still importable; the underscore and `__all__` document intent, and mypy's `no_implicit_reexport` (part of `strict`) makes a re-export explicit.

### Entry points

- A command is a function `main(argv: Sequence[str] | None = None) -> int` that parses its arguments, runs, and returns the exit status. Wire it in `[project.scripts]`, and give the package a `__main__.py` so that `python -m demo` works:

```python
# fragment
"""Run the command with ``python -m demo``."""

import sys

from demo.cli import main

sys.exit(main())
```

- Keep `if __name__ == "__main__":` guards for single-file modules; in a package, `__main__.py` is the entry point. The guard is also what makes `multiprocessing` safe under the spawn start method ([concurrency](09-concurrency-and-async.md)).
- When a package must run from the source tree without installation, the PyPA guide suggests prepending the package path to `sys.path` in `__main__.py`. Prefer `uv run` instead.

### Single-file scripts

- A script that is not a project declares its Python version and dependencies in a PEP 723 block at the top, and runs with `uv run --script`. The block is a comment, so the file stays valid Python (checked: `uv run --script` printed the output of a script with such a block):

```python
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Print a greeting."""

print("hello from a script")
```

- Keep a script to one file and a screenful or two of code. When it grows a second module, turn it into a project.

## Sources and raw notes

Pages read on 2026-10-30:

- [PEP 8](https://peps.python.org/pep-0008/): imports, module level dunder names, package and module names, public and internal interfaces.
- [PEP 257](https://peps.python.org/pep-0257/): module and package docstrings.
- Python Packaging User Guide: [src layout vs flat layout](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/), [Writing your pyproject.toml](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/) (`[project.scripts]`), [Inline script metadata](https://packaging.python.org/en/latest/specifications/inline-script-metadata/) (PEP 723).
- pytest documentation: [Good Integration Practices](https://docs.pytest.org/en/stable/explanation/goodpractices.html) (test layouts, import modes).
- uv documentation: [Working on projects](https://docs.astral.sh/uv/guides/projects/).
- Checked on 2026-10-30 with uv 0.13.6, Ruff 0.17.3 and mypy 2.4.1 on Python 3.14.8; every `python` block without a `# fragment` or `# wrong` first line was checked as the principles note describes.
