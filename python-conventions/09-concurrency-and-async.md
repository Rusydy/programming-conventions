# Python Concurrency and Async

## Summary

Do not add concurrency until something is slow, and measure first. Then pick by workload: `asyncio` for many waits on async-capable I/O, a thread pool for blocking I/O libraries, a process pool for CPU-bound work, and the free-threaded build only on purpose. Use structured tools (`TaskGroup`, `timeout`, executors in a `with` block) so that failures and cancellation are not lost, never block the event loop, and guard multiprocessing code with `if __name__ == "__main__":`.

## Rules

### Choosing

| Workload | Use |
| --- | --- |
| Many network or file waits, libraries that support `async` | `asyncio` |
| A few blocking I/O calls in libraries without `async` support | `concurrent.futures.ThreadPoolExecutor` |
| CPU-bound work | `concurrent.futures.ProcessPoolExecutor`, or a free-threaded build |
| Running another program | `subprocess.run` |

- The default CPython build has a global interpreter lock (GIL), so threads do not make Python code run in parallel: `sys._is_gil_enabled()` was `True` on Python 3.14.8. Free-threaded builds are officially supported from 3.14 (PEP 779) and are a separate, opt-in interpreter (`python3.14t`); the official macOS and Windows installers can install them since 3.13. Check which interpreter you have with `python -VV` or `sys._is_gil_enabled()` (free-threading HOWTO). Do not depend on it unless the project decides to.
- Start from the simplest correct sequential code, find the bottleneck, then change that part.

### Executors

- Use `ThreadPoolExecutor` and `ProcessPoolExecutor` in a `with` block, so that the workers are joined. `submit` returns a future, `as_completed` yields them as they finish, `map` keeps the input order. An exception in a worker is raised again by `future.result()` in the caller.
- Arguments and results of a process pool must be picklable; a function that is defined at module level, not a lambda or a closure.

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

def fetch_length(text: str) -> int:
    """Stand in for a blocking call."""
    return len(text)

with ThreadPoolExecutor(max_workers=4) as pool:
    futures = {pool.submit(fetch_length, word): word for word in ["a", "bb", "ccc"]}
    for future in as_completed(futures):
        print(futures[future], future.result())
```

### asyncio

- Start the event loop once, at the entry point, with `asyncio.run(main())`. Inside, use `await`.
- Run related tasks in an `asyncio.TaskGroup` (Python 3.11). If one task fails, the group cancels the others and raises an `ExceptionGroup` with the failures, caught with `except*` (checked: the sibling printed "sibling cancelled" and the group held the `RuntimeError`). Use `asyncio.gather` only when you need `return_exceptions=True`.
- Set a deadline with `async with asyncio.timeout(seconds):`, which raises `TimeoutError` (checked).
- `asyncio.create_task()` returns a task that you must keep a reference to: the event loop keeps only a weak reference, so an unreferenced task can be garbage collected before it finishes. A `TaskGroup` keeps them for you; otherwise store tasks in a set and remove each when it is done (asyncio documentation).
- Never block the loop: no `time.sleep`, no blocking HTTP or database client, no long CPU loop. A blocking call runs in a thread with `await asyncio.to_thread(function, *args)`, or in an executor (asyncio documentation).
- Do not swallow `asyncio.CancelledError`; do the cleanup and re-raise it.
- Debug mode finds mistakes such as never-awaited coroutines and slow callbacks (over 100 ms are logged): run with `python -X dev`, set `PYTHONASYNCIODEBUG=1`, or pass `debug=True` to `asyncio.run`.
- Test coroutines with a pytest plugin ([testing](10-testing.md#markers-speed-and-async-tests)).

```python
import asyncio

async def fetch(name: str, delay: float) -> str:
    """Pretend to fetch ``name``."""
    await asyncio.sleep(delay)
    return name.upper()

async def main() -> None:
    """Fetch several things at once, with a deadline."""
    async with asyncio.timeout(1.0), asyncio.TaskGroup() as group:
        tasks = [group.create_task(fetch(name, 0.01)) for name in ("a", "b", "c")]
    print([task.result() for task in tasks])

asyncio.run(main())
```

```python
import asyncio

async def slow() -> None:
    """Run until cancelled."""
    try:
        await asyncio.sleep(5)
    except asyncio.CancelledError:
        print("sibling cancelled")
        raise

async def boom() -> None:
    """Fail after a short wait."""
    await asyncio.sleep(0.05)
    raise RuntimeError("boom")

async def main() -> None:
    """Show that one failure cancels the other tasks of the group."""
    try:
        async with asyncio.TaskGroup() as group:
            group.create_task(slow())
            group.create_task(boom())
    except* RuntimeError as errors:
        print("group:", [str(error) for error in errors.exceptions])

asyncio.run(main())
```

### Threads

- Prefer an executor to creating `threading.Thread` objects. Share as little as possible. Pass work and results through `queue.Queue`, and protect the shared state that remains with `with lock:` on a `threading.Lock`. In a free-threaded build, races in your own data structures become visible, so treat them as bugs everywhere.

### Processes

- The start method of `multiprocessing` differs by platform. `spawn` is the default on macOS and Windows; on Linux `fork` was the default until Python 3.13, and from 3.14 `fork` is no longer the default on any platform (`forkserver` on Linux); code that needs `fork` must ask for it explicitly (multiprocessing documentation). Observed: `spawn` on Python 3.14.8 on macOS, `fork` on 3.12.15 on Linux in Docker.
- Under `spawn` the main module is imported again in every worker, so code that starts processes needs the `if __name__ == "__main__":` guard. Without it a `multiprocessing.Pool` program hung on macOS and was killed after 20 seconds, while the same file printed `[1, 4, 9]` on Linux with `fork`; with the guard it printed `[1, 4, 9]` on both (checked). That is a program that works on Linux and hangs on macOS.

```python
from concurrent.futures import ProcessPoolExecutor

def square(n: int) -> int:
    """Return the square of ``n``."""
    return n * n

def main() -> None:
    """Square some numbers in worker processes."""
    with ProcessPoolExecutor(max_workers=2) as pool:
        print(list(pool.map(square, [1, 2, 3])))

if __name__ == "__main__":
    main()
```

### Running programs

- Run another program with `subprocess.run([...], check=True, capture_output=True, text=True, timeout=30)`: a list of arguments, so that no shell is involved and metacharacters stay literal (checked: `echo $HOME` printed `$HOME`); `check=True` raises `CalledProcessError` on a non-zero exit status (checked); `timeout` raises `TimeoutExpired`. `shell=True` is for constant command lines only ([security](11-security-and-dependencies.md#injection)).
- Do not read the pipes of a `Popen` by hand while the child writes a lot; `run` and `communicate` avoid the deadlock (subprocess documentation).

```python
import subprocess
import sys

result = subprocess.run(
    [sys.executable, "-c", "print('hello')"],
    check=True,
    capture_output=True,
    text=True,
    timeout=30,
)
print(result.stdout.strip())
```

## Sources and raw notes

Pages read on 2026-10-30:

- Python documentation: [asyncio tasks](https://docs.python.org/3/library/asyncio-task.html) (the weak reference to tasks), [Developing with asyncio](https://docs.python.org/3/library/asyncio-dev.html) (debug mode, blocking code), [multiprocessing](https://docs.python.org/3/library/multiprocessing.html) (start methods and the 3.14 change), [subprocess](https://docs.python.org/3/library/subprocess.html) (security considerations), [Python support for free threading](https://docs.python.org/3/howto/free-threading-python.html), [What's new in Python 3.11](https://docs.python.org/3/whatsnew/3.11.html), [3.13](https://docs.python.org/3/whatsnew/3.13.html) and [3.14](https://docs.python.org/3/whatsnew/3.14.html).
- Behaviour marked "checked" was run on Python 3.14.8 (macOS, Homebrew) and 3.12.15 (Docker image `python:3.12-alpine`, without network). Every `python` block without a `# fragment`, `# before` or `# wrong` first line was checked as the principles note describes; the blocks that start processes were run as files.
