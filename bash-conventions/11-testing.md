# Bash Testing

## Summary

Test scripts with bats-core, which is itself written in Bash. A test file is a Bash file with `@test` blocks; each block is a function whose lines are assertions, because bats runs it with `set -e`. Test executables from outside, as a user would, with `run`, `$status`, `$output` and `$lines`. Put logic that needs unit tests into a library under `lib/` and source it from the test. Static checks (shfmt and ShellCheck) run before the tests and cover `.bats` files as well.

## Rules

### Layout and running

- Tests live in `test/`, one `.bats` file per executable or library: `test/slugify.bats` tests `bin/slugify`. Shared helpers go in `test/test_helper.bash`, which a test pulls in with `load test_helper`.
- Run `bats test/` (bats-core 1.14.0). Useful options: `-r` for subdirectories, `--print-output-on-failure` to show `$output` of failed tests, `--filter <regex>` to run tests by name, `-x` to trace, `--tap` for TAP output (the default when the output is not a terminal), `--timing`, and `--jobs N` for parallel runs (needs GNU parallel).
- A test passes when every command in it returns 0 (bats runs the test with `set -e`). Write each assertion as a plain `[ ... ]` line, not `[[ ... ]]`: `[[` obeys `set -e` only from Bash 4.1, and in a test run by Bash 3.2.57 a failing `[[ 1 == 2 ]]` in the middle of the test passed, while `[ 1 = 2 ]` failed it (checked; `[[ ]]` as the last command of a test failed it too). The optional ShellCheck check `require-double-brackets` flags `[ ]`, so a `.bats` file starts with `# shellcheck disable=SC2292` and the reason.
- CI runs the same command as the developer ([tooling](02-project-setup-and-tooling.md#automation)). A test tagged `bats:focus` runs alone and makes bats exit with 1 even if it passes, so that a forgotten tag cannot go unnoticed in CI (bats(7)).

### A script and its test

`bin/slugify` is a small script written for Bash 3.2, so it also runs under bats. It uses `tr` and parameter expansion where a 4.x script would use `${v,,}`:

```bash
#!/usr/bin/env bash
#
# Print a URL-friendly slug for each argument, or for each line of stdin.
#
# Requires: Bash 3.2 or newer.

set -euo pipefail

slugify() {
  local text=$1 slug
  slug="$(
    printf '%s' "${text}" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cs 'a-z0-9' '-'
  )"
  slug=${slug#-}
  slug=${slug%-}
  printf '%s\n' "${slug}"
}

main() {
  local arg line
  if (($# == 0)); then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      slugify "${line}"
    done
    return 0
  fi
  for arg in "$@"; do
    slugify "${arg}"
  done
}

main "$@"
```

`test/slugify.bats`:

```bash
#!/usr/bin/env bats
# shellcheck disable=SC2292 # assertions use [ ]; see the rules below

bats_require_minimum_version 1.7.0

setup() {
  PATH="${BATS_TEST_DIRNAME}/../bin:${PATH}"
}

@test "turns words into a lowercase slug" {
  run -0 slugify 'Hello, World!'
  [ "${output}" = 'hello-world' ]
}

@test "prints one slug per argument" {
  run -0 slugify 'First Post' 'Second Post'
  [ "${lines[0]}" = 'first-post' ]
  [ "${lines[1]}" = 'second-post' ]
}

@test "reads standard input when there are no arguments" {
  run -0 bash -c 'printf "Some Title\n" | slugify'
  [ "${output}" = 'some-title' ]
}
```

- `run` runs the command, stores its exit status in `$status` and its stdout and stderr together in `$output`, and the lines of the output in the array `$lines`. `run -0` and `run -1` also check the status, and name the expected and actual status on failure. `--separate-stderr` splits stderr into `$stderr`. Use `run bats_pipe a \| b` to run a pipeline (a plain `run a | b` pipes the output of `run` itself).
- `bats_require_minimum_version` states the oldest bats-core that the file works with. The function exists from bats-core 1.7.0 (bats(7)).
- `setup` runs before each test and `teardown` after it; `setup_file` and `teardown_file` run once per file. Put the `bin/` directory on `PATH` in `setup`, so that tests call the script by name, as users do.
- Each test runs in its own process. `$BATS_TEST_TMPDIR` is a temporary directory unique to the test, `$BATS_FILE_TMPDIR` is shared by the file, and `$BATS_TEST_DIRNAME` is the directory of the test file. Never write into the project directory.
- `skip 'reason'` skips a test, for example when a tool is missing on the machine. Output of code outside the tests, `setup` and `teardown` must go to stderr (`>&2`), or it corrupts the TAP stream.
- Run on macOS, the three tests passed with bats 1.14.0 under Bash 3.2.57.

### What to test

- Test the behaviour a caller sees: exit status, stdout, stderr, files created. `--help`, bad arguments and `--dry-run` are cheap tests.
- Test the failure paths, not only the good one: missing argument (status 2), missing dependency, unreadable input.
- Do not test with real side effects. Replace a program with a stub that the script finds first on `PATH`:

```bash
# fragment
@test "uses the git that it finds first on PATH" {
  printf '%s\n' '#!/bin/sh' 'echo "git version 9.9.9"' \
    >"${BATS_TEST_TMPDIR}/git"
  chmod +x "${BATS_TEST_TMPDIR}/git"
  PATH="${BATS_TEST_TMPDIR}:${PATH}" run -0 uptodate
  [ "${output}" = 'git: git version 9.9.9' ]
}
```

- To test a missing program, shorten `PATH` and start the script through an absolute interpreter, because `#!/usr/bin/env bash` needs `bash` on `PATH`: `PATH=/nonexistent run -1 /bin/bash "${BATS_TEST_DIRNAME}/../bin/uptodate"`.
- Put logic that needs unit tests into a library in `lib/`, where sourcing has no side effects ([layout](03-project-layout-and-files.md#libraries)), and source it from the test: `source "${BATS_TEST_DIRNAME}/../lib/fs.sh"`. Libraries hold the logic and the executables stay thin.
- Libraries installed on the system, such as helper libraries for assertions, load with `bats_load_library` and `BATS_LIB_PATH` (bats(7)). The plain `[ ]` tests above need none; add a helper library only when the failure messages of plain tests are not enough.

### Which Bash runs the tests

- bats-core runs tests in the Bash that `#!/usr/bin/env bash` finds first. A script that declares Bash 4.4 cannot be tested until a newer Bash is installed ([versions](09-portability-and-bash-versions.md#declaring-the-version)). Run the suite in CI, or in a container, on the declared minimum version and on the newest one. A script that declares Bash 3.2 runs everywhere.
- A test of the version guard itself needs that old Bash; skip the test when the Bash is newer.

### Static checks cover tests

- `shfmt -d .` formats `.bats` files (it knows the `@test` syntax) and ShellCheck checks them: both ran without findings on the file above (with its `SC2292` directive), and `shfmt -f` lists `.bats` files, so the pipeline in the tooling note includes them.

## Sources and raw notes

Pages and manuals read on 2026-10-30:

- bats-core 1.14.0 manuals: `man bats` (options, filtering, TAP) and `man 7 bats` (the test file format, `run`, `bats_pipe`, `load`, `bats_load_library`, `skip`, `bats_require_minimum_version`, `setup` and `teardown`, special variables, tags).
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) and [BashFAQ/001](https://mywiki.wooledge.org/BashFAQ/001): the style and the read loop of the script above.
- The script, the test file and the stub test were run on macOS with bats 1.14.0 under Bash 3.2.57; shfmt 3.14.1 and ShellCheck 0.11.0 were run on the test file.
