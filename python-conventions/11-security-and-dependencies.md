# Python Security and Dependencies

## Summary

Keep input in data positions: parameterised SQL, argument lists instead of shell strings, `ast.literal_eval` instead of `eval`, JSON instead of `pickle`, and a check that a path stays inside its directory. Use `secrets` for anything that must be unguessable, `tempfile` for temporary files, and the framework for passwords. Dependencies come from a lock file, are installed only into a virtual environment, and are updated on purpose. Ruff's `S` rules are the safety net.

## Rules

### Injection

- **SQL:** pass values as parameters, never build the statement from strings. With the string-built form, the input `nobody' OR '1'='1` returned all rows; with a parameter it returned none (checked with `sqlite3`). Django's querysets are parameterised for you; raw SQL, `extra()` and `RawSQL` need the same care (Django documentation). Ruff: `S608`.
- **Processes:** pass a list of arguments to `subprocess.run`. The module never calls a shell by itself, so metacharacters stay literal (checked: `echo $HOME` printed `$HOME`). With `shell=True` the application is responsible for quoting every part (`shlex.quote`), so use it only for constant command lines (subprocess documentation). Ruff: `S602`.
- **Code from text:** do not `eval` or `exec` strings. For literals use `ast.literal_eval`, which raises on anything else (Ruff `S307`).
- **Deserialisation:** `pickle` runs code while loading: unpickling an object whose `__reduce__` returns `(print, ("...",))` printed the message (checked). Load only data that you wrote, and use JSON for data from outside; if integrity matters, sign it with `hmac` (pickle documentation). Ruff: `S301`. For YAML use `yaml.safe_load`, not `yaml.load` (Ruff `S506`).
- **Paths:** a file name from a user can contain `..` or be absolute. Resolve the final path and check that it is inside the base directory (checked: `../../etc/passwd` and `/etc/passwd` were both rejected).

```python
import ast
import sqlite3
import subprocess
import sys
from pathlib import Path

BASE = Path("/srv/app/files").resolve()


def safe_path(name: str) -> Path:
    """Return the file inside ``BASE``, or raise if ``name`` escapes it."""
    target = (BASE / name).resolve()
    if not target.is_relative_to(BASE):
        raise ValueError(f"{name!r} is outside {BASE}")
    return target


db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE users (name TEXT, secret TEXT)")
db.executemany("INSERT INTO users VALUES (?, ?)", [("ada", "x1"), ("bob", "x2")])
hostile = "nobody' OR '1'='1"
print(len(db.execute("SELECT * FROM users WHERE name = ?", (hostile,)).fetchall()))

done = subprocess.run(
    [sys.executable, "-c", "import sys; print(sys.argv[1])", "$HOME; echo owned"],
    check=True,
    capture_output=True,
    text=True,
)
print(done.stdout.strip())
print(ast.literal_eval("[1, 2, {'a': 3}]"), safe_path("report.txt"))
```

```python
# wrong
import sqlite3
import subprocess


def find_user(db: sqlite3.Connection, name: str) -> list[tuple[str, str]]:
    return db.execute("SELECT * FROM users WHERE name = '" + name + "'").fetchall()


def ping(host: str) -> None:
    subprocess.run(f"ping -c 1 {host}", shell=True, check=False)
```

### Secrets and randomness

- Use `secrets` for tokens, passwords and keys. The `random` module is for simulation and is predictable; the documentation says not to use it for security (Ruff `S311`). `secrets.token_urlsafe(32)` gave a 43-character token (checked).
- Compare secrets with `hmac.compare_digest`, which takes the same time wherever the values differ.
- Never store a password in plain text or as a plain hash such as `sha256(password)`. A password hash must be tunable, slow and salted; `hashlib.scrypt` and `hashlib.pbkdf2_hmac` provide it, with a salt of about 16 or more bytes from a proper source such as `os.urandom()`, and for `pbkdf2_hmac` hundreds of thousands of SHA-256 iterations as of 2022 (hashlib documentation). Use the framework's password API (Django's `make_password` and `check_password`) rather than calling these yourself.
- Keep secrets out of source control and out of logs and error messages. Configuration comes from the environment or a secrets store; a `.env` file is ignored by git. Django's `SECRET_KEY` and database passwords are read from the environment or a file, not committed (Django deployment checklist).
- Do not turn off TLS verification (`verify=False` and similar); an attacker can then intercept the traffic (Ruff `S501`).

```python
import hmac
import secrets

token = secrets.token_urlsafe(32)
same = hmac.compare_digest(token, token)
other = hmac.compare_digest(token, "x" * len(token))
print(len(token), same, other)
```

### Files and assertions

- Create temporary files and directories with `tempfile` (`TemporaryDirectory`, `NamedTemporaryFile`, `mkstemp`), which create them safely in a shared temporary directory. `tempfile.mktemp` only returns a name, so another process can create the file first; the documentation marks it as deprecated and as a possible security hole (Ruff `S306`). No runtime warning is printed (checked), so only the linter and the reader catch it.
- Do not use `assert` to validate input: `python -O` removes assertions (checked), which makes the check disappear in production (Ruff `S101`). Raise an exception.

```python
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp) / "report.txt"
    work.write_text("data", encoding="utf-8")
    print(work.read_text(encoding="utf-8"))
```

### Dependencies

- Install packages only into a virtual environment, never into the system Python, and never with `--break-system-packages`, which can break tools of the operating system (pytest documentation). Systems that follow PEP 668 refuse the plain install: pip on macOS with Homebrew's Python 3.14.8 stopped with `error: externally-managed-environment` (checked with `--no-index --dry-run`, so nothing was downloaded).
- Applications install from the lock file: `uv sync --locked` fails when `uv.lock` does not match `pyproject.toml`, so CI never silently resolves new versions (checked: with `mypy` removed from the `dev` group, `uv sync --locked` ended with status 1 and `The lockfile at uv.lock needs to be updated, but --locked was provided`; `uv lock --check` is the same test without installing). uv does not consider a lock file outdated when new versions of packages are released, so upgrading is a deliberate act, `uv lock --upgrade-package <package>` for one package within the constraints of the project (uv documentation; [tooling](02-project-setup-and-tooling.md#uv)). Read the changelog of an upgrade, upgrade one package at a time, and run the tests.
- Add a dependency only when it removes real complexity, and prefer the standard library. Every dependency is code that runs with your privileges.
- Publish packages with Trusted Publishing from CI instead of a long-lived API token; never use `python setup.py upload`, which is deprecated and insecure (PyPA guide).
- The Ruff `S` rules run in CI as a net for the patterns above. Silence one only with a `# noqa: S...` that carries a reason.

```bash
uv sync --locked      # install exactly what uv.lock says; error if the lock is stale
uv lock --check       # the same check, without installing
uv lock --upgrade-package requests    # upgrade one package; needs the network, not run here
```

## Sources and raw notes

Pages read on 2026-10-30:

- Python documentation: [subprocess](https://docs.python.org/3/library/subprocess.html) (security considerations), [pickle](https://docs.python.org/3/library/pickle.html) (the module is not secure), [random](https://docs.python.org/3/library/random.html), [secrets](https://docs.python.org/3/library/secrets.html), [hashlib](https://docs.python.org/3/library/hashlib.html) (password hashing), [tempfile](https://docs.python.org/3/library/tempfile.html) (`mktemp` is deprecated).
- Django documentation: [Security in Django](https://docs.djangoproject.com/en/stable/topics/security/) (SQL injection protection) and [Deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/) (`SECRET_KEY`, `DEBUG`).
- Python Packaging User Guide: [Tool recommendations](https://packaging.python.org/en/latest/guides/tool-recommendations/) (Trusted Publishing, deprecated `setup.py` commands). pytest documentation: [Good Integration Practices](https://docs.pytest.org/en/stable/explanation/goodpractices.html) (PEP 668 note). uv documentation: [Locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/).
- Rule explanations from `ruff rule` for S101, S301, S306, S307, S311, S501, S506, S602, S603 and S608 (Ruff 0.17.3).
- Behaviour marked "checked" was run on Python 3.14.8 and 3.12.15. Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes.
