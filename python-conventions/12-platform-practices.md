# Python Platform Practices

## Summary

Two kinds of Python programs recur in practice: command-line programs and scripts, and Django applications. A command-line program is a `main(argv) -> int` function with `argparse`, results on stdout, logging on stderr and a meaningful exit status. A Django project keeps the layout that `startproject` generates, reads its secrets from the environment, starts with a custom user model, avoids N+1 queries with `select_related`, commits its migrations, uses Django's own test runner, adapts the Ruff and mypy configuration to generated code, and passes `check --deploy` before it goes live.

## Rules

### Command-line programs

- The program is a function `main(argv: Sequence[str] | None = None) -> int` in a module of the package. It builds the parser, parses `argv` (so a test can pass a list), runs, and returns the exit status. The installed command is generated from `[project.scripts]` and ends with `sys.exit(main())`, so the returned number becomes the exit status (checked: `uv run demo -- -1` ended with status 1 because `main` returned 1; see [layout](03-project-layout-and-packages.md#entry-points)).
- Use `argparse` from the standard library: typed arguments (`type=float`), `choices`, `default`, and `-h/--help` for free. Exit status 0 means success, 1 a failure the program handled, and 2 misuse: `argparse` itself prints the usage and the error to stderr and exits with 2 on a bad argument (checked; see [exit status](08-error-handling-and-logging.md#exit-status-of-a-program)).
- Results go to stdout with `print`. Diagnostics go through `logging`, which writes to stderr by default, configured once in `main` ([logging](08-error-handling-and-logging.md#logging)). Checked: with `-v`, stdout held only `12.566` and stderr held only the debug line. Ruff's `T20` (print) is ignored for `cli.py` only, in the configuration of the [tooling note](02-project-setup-and-tooling.md#pyprojecttoml).
- Turn the exceptions that users can cause into one line on stderr and a non-zero status at the boundary of `main`, and let the unexpected ones show their traceback ([catching exceptions](08-error-handling-and-logging.md#catching-exceptions)).
- A short single-purpose script has the same shape and declares its dependencies in the PEP 723 block ([single-file scripts](03-project-layout-and-packages.md#single-file-scripts)).

```python
# fragment
"""Command-line interface: print the area of a circle."""

import argparse
import logging
import sys
from collections.abc import Sequence

from demo.circle import area_of_circle

logger = logging.getLogger(__name__)

def build_parser() -> argparse.ArgumentParser:
    """Return the argument parser of the command."""
    parser = argparse.ArgumentParser(prog="demo", description=__doc__)
    parser.add_argument("radius", type=float, help="radius of the circle")
    parser.add_argument("-v", "--verbose", action="store_true", help="log details")
    return parser

def main(argv: Sequence[str] | None = None) -> int:
    """Run the command and return its exit status."""
    args = build_parser().parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.WARNING)
    try:
        area = area_of_circle(args.radius)
    except ValueError as err:
        logger.error("invalid input: %s", err)
        return 1
    logger.debug("radius=%s area=%s", args.radius, area)
    print(f"{area:.3f}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

This module is `src/demo/cli.py` of the sample project, checked with Ruff and mypy there and run as `uv run demo 2` (stdout `12.566`, status 0), `uv run demo abc` (usage error on stderr, status 2), `uv run demo -- -1` (error on stderr, status 1) and `uv run demo -v 2` (debug line on stderr, `12.566` on stdout).

### Django

Django is the framework used in the examples. The rules come from the Django documentation. The numbers come from a project generated and run with Django 6.1.2 on Python 3.14.8 on 2026-10-30. The blocks below were copied into that project and run there; they are marked as fragments only because the block checker of these notes reads their syntax and does not know the project.

- **Versions.** Mainstream support covers security fixes, data-loss bugs, crashing bugs, major bugs in new features and regressions; extended support covers only security fixes and data-loss bugs (Django download page). Start a new project on the newest series, and use an LTS series only for an application that upgrades rarely. From 2028 releases are named by year, come out every January, and each one gets three years of support.

| Series | Latest on 2026-10-30 | Mainstream support ends | Extended support ends |
| --- | --- | --- | --- |
| 6.1 | 6.1.2 | April 2027 | December 2027 |
| 6.0 | 6.0.9 | August 4, 2026 | April 2027 |
| 5.2 LTS | 5.2.18 | December 3, 2025 | April 2028 |
| 6.2 LTS (due April 2027) | not released | December 2027 | April 2030 |

- **Upgrading.** Read the release notes of every final release from the one after yours up to the target, and the deprecation timeline. When the upgrade crosses several feature releases, go through them one at a time. Python hides deprecation warnings by default, so run the tests with them on, `python -Wa manage.py test`, and fix them before upgrading (Django upgrade guide). With pytest the guide uses `PYTHONWARNINGS=always pytest --capture=no`.
- **Layout.** Use what the generators write. `django-admin startproject config .` creates `manage.py` and a `config/` package (`__init__.py`, `settings.py`, `urls.py`, `asgi.py`, `wsgi.py`), and `python manage.py startapp ats` creates the app `ats` (`__init__.py`, `admin.py`, `apps.py`, `models.py`, `tests.py`, `views.py` and a `migrations/` package) (checked). Run commands as `uv run python manage.py ...`.
- **Style.** Django formats its code with black at 88 columns and wraps comments and docstrings at 79 (coding style); `ruff format` is black-compatible ([where the guides disagree](04-naming-comments-and-style.md#where-the-guides-disagree)).
- **Ruff and mypy on generated code.** The generators do not write code that passes the strict configuration of the tooling note. A project with the apps `accounts` and `ats` and a first migration for each had 49 findings under that configuration (checked), 25 of them in the generated migrations (`E501`, `RUF012`, missing docstrings) and one `PT009` for `assertEqual` in a test class, because the `PT` rules are for pytest style. The rest are the unused placeholder imports (`F401`), the first line of the generated module docstrings (`D212`, `D411`), the long lines of `settings.py` and the docstrings that the generator does not write. The additions in the `toml` block below exclude the migrations, drop `PT` (a Django project uses Django's own test runner), and skip the docstring rules only for the generated files that carry no code of the project. Then 10 findings remain, all fixed by one `ruff check --fix`, and one `ruff format` reformats the rest; the project still passed `manage.py check` and its tests afterwards (checked). A generated `models.py` also needs its module docstring, which the blocks below have. The overrides in the same block are for mypy, see Typing below.
- **Custom user model.** The Django documentation shows how to start a project with `class User(AbstractUser)` and says to point `AUTH_USER_MODEL` at it before creating any migrations or running `migrate` for the first time. Changing it after the tables exist "can be complex", because it affects foreign keys and many-to-many relations, and cannot be done automatically. So a new project starts with its own user model, even when it adds nothing yet. Refer to it with `settings.AUTH_USER_MODEL` in models and `get_user_model()` in code.
- **Settings from the environment.** The generated `settings.py` has a `SECRET_KEY` that starts with `django-insecure-`, `DEBUG = True` and `ALLOWED_HOSTS = []`. The deployment checklist asks for a large random secret key that is kept out of source control and may be loaded from an environment variable, says never to enable debug in production, and says that Django does not work with `DEBUG = False` unless `ALLOWED_HOSTS` is set. With the excerpt below, a missing `SECRET_KEY` stops the program at start-up with a `KeyError` (checked), which is the point.
- **Deployment check.** Run `manage.py check --deploy` against the production settings and treat it as part of the release. On the generated defaults of Django 6.1.2 it reported one error, `mail.E001`, because the `MAILERS` setting that `startproject` writes uses the development-only console email backend, and seven warnings: `security.W004` (HSTS), `W008` (SSL redirect), `W009` (the insecure `SECRET_KEY`), `W012` (session cookie), `W016` (CSRF cookie), `W018` (`DEBUG`) and `W020` (empty `ALLOWED_HOSTS`). With a long random `SECRET_KEY`, no `DEBUG` and `ALLOWED_HOSTS` set in the environment, `W009`, `W018` and `W020` were gone and the other five remained (checked). The `runserver` command is not designed for production; use a WSGI or ASGI server.
- **Queries.** A loop that touches a related object runs one query per row. With five candidates and a foreign key to a job, `[c.job.title for c in Candidate.objects.all()]` ran 6 queries, and the same loop over `Candidate.objects.select_related("job")` ran 1 (checked with `CaptureQueriesContext`). Use `select_related` for foreign keys and one-to-one fields and `prefetch_related` for many-to-many and reverse relations. Pin the count of a view or function in a test with `assertNumQueries`.
- **Migrations.** Commit the migration files with the model change they belong to. In CI run `python manage.py makemigrations --check --dry-run`: it prints "No changes detected" and exits with 0 when the models and the migrations agree, and exits with 1 and lists what is missing when they do not (checked: a new field without a migration gave status 1 and `Add field note to candidate`).
- **Tests.** The framework's convention is `django.test.TestCase` and `python manage.py test`, so a Django project uses that runner instead of the pytest setup of the tooling note. pytest needs the third-party `pytest-django` plugin (its PyPI page for version 4.14.0 lists Django 5.2 and 6.0; not run here). Django's own style asks for `assertRaisesMessage()` instead of `assertRaises()` and `assertIs(..., True)` instead of `assertTrue()` (coding style); both are good habits for application tests.
- **Security features stay on.** SQL goes through the ORM, whose querysets use query parameterization, and any raw SQL, `extra()` or `RawSQL` needs the care of the [injection rules](11-security-and-dependencies.md#injection). Do not turn off CSRF protection, the escaping of templates or the clickjacking middleware without a reason that is written down (Security in Django).
- **Typing.** Django ships no type hints (checked: no `py.typed` file and no `.pyi` files in the installed package). With the `strict` setting of the tooling note, mypy reports `import-untyped` for the Django imports and `Class cannot subclass "Model" (has type "Any")` for each model (checked: 7 errors in the 3 files below). The answer made for this is the third-party `django-stubs` package, which adds stubs and a mypy plugin (`plugins = ["mypy_django_plugin.main"]` and `django_settings_module` under `[tool.django-stubs]`); its PyPI page for 6.1.2 lists mypy 1.13 to 2.4, Django 6.1 and Python 3.11 to 3.14. It was not installed here and not run. Without it, silence only what Django causes, per module (checked: strict mypy then passes on the 3 files).

Additions for a Django project; merge the keys into the tables of the tooling note, because TOML does not allow a table twice:

```toml
[tool.ruff]
extend-exclude = ["**/migrations/*.py"]

[tool.ruff.lint]
ignore = ["PT"]

[tool.ruff.lint.per-file-ignores]
"**/{admin,views,tests}.py" = ["D100"]
"**/apps.py" = ["D100", "D101"]
"**/__init__.py" = ["D104"]
"config/settings.py" = ["E501"]

[[tool.mypy.overrides]]
module = ["django.*"]
ignore_missing_imports = true

[[tool.mypy.overrides]]
module = ["accounts.*", "ats.*"]
disallow_subclassing_any = false
```

Excerpt of `config/settings.py`:

```python
# fragment
import os

SECRET_KEY = os.environ["SECRET_KEY"]
DEBUG = os.environ.get("DEBUG") == "1"
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split()
AUTH_USER_MODEL = "accounts.User"
```

`accounts/models.py`:

```python
# fragment
"""Models of the accounts app."""

from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    """The project user model. Keep it even if it adds nothing yet."""
```

`ats/models.py`:

```python
# fragment
"""Models of the ats app."""

from django.db import models

class Job(models.Model):
    """An open position."""

    title = models.CharField(max_length=100)

class Candidate(models.Model):
    """A person who applied for a job."""

    name = models.CharField(max_length=100)
    job = models.ForeignKey(Job, on_delete=models.CASCADE)
```

`ats/tests.py`:

```python
# fragment
"""Tests of the ats app."""

from django.test import TestCase

from ats.models import Candidate, Job

class CandidateQueryTests(TestCase):
    """Query counts of the candidate list."""

    def test_titles_use_one_query(self) -> None:
        """Reading each job title takes one query with select_related."""
        job = Job.objects.create(title="Backend")
        Candidate.objects.bulk_create(
            [Candidate(name=f"c{i}", job=job) for i in range(5)]
        )
        with self.assertNumQueries(1):
            titles = [c.job.title for c in Candidate.objects.select_related("job")]
        self.assertEqual(titles, ["Backend"] * 5)
```

```bash
uv run python manage.py check --deploy
uv run python manage.py makemigrations --check --dry-run
uv run python manage.py test
```

## Sources and raw notes

Pages read on 2026-10-30:

- Django documentation: [Coding style](https://docs.djangoproject.com/en/stable/internals/contributing/writing-code/coding-style/) (black, 88 and 79 columns, `assertRaisesMessage`, `assertIs`), [Deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/) (`SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `check --deploy`, `runserver`), [Customizing authentication](https://docs.djangoproject.com/en/stable/topics/auth/customizing/) (custom user model), [Security in Django](https://docs.djangoproject.com/en/stable/topics/security/), [How to upgrade Django](https://docs.djangoproject.com/en/stable/howto/upgrade-version/) and the [download page](https://www.djangoproject.com/download/) (supported versions and their footnotes).
- PyPI pages, read only: [django-stubs](https://pypi.org/project/django-stubs/) 6.1.2 and [pytest-django](https://pypi.org/project/pytest-django/) 4.14.0. Neither package was installed.
- Python documentation: `argparse` and `logging`, as used above.
- Run on 2026-10-30 with Django 6.1.2 and Python 3.14.8 in a scratch directory: `django-admin startproject`, `startapp`, `check`, `check --deploy`, `makemigrations`, `makemigrations --check --dry-run`, `migrate`, `manage.py test`, the query counts (6 and 1), Ruff with the configuration of the tooling note before and after the additions, and strict mypy with and without the overrides. The command-line module was run through `uv run demo` in the sample project.
