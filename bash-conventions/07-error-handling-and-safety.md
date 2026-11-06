# Bash Error Handling and Safety

## Summary

Every executable runs in strict mode (`set -euo pipefail` plus `inherit_errexit`) as a safety net, and still handles every failure it expects with an explicit check. The net has known holes, listed below with the form that avoids each one. Errors go to stderr with the program name, the exit status is 0, 1 or 2, and a trap on `EXIT` cleans up.

## Rules

### Strict mode

Put these lines in every executable, after the version guard and before the constants. Libraries never set shell options, because the options would change the shell of the caller.

```bash
set -euo pipefail
shopt -s inherit_errexit
```

`inherit_errexit` needs Bash 4.4. A script that declares an older minimum leaves that line out ([versions](09-portability-and-bash-versions.md#declaring-the-version)).

This is the one rule in the set on which the sources disagree, so it is recorded as a decision and not as a fact. BashFAQ/105 ends with three personal recommendations: do not use `set -e`; use it and know the gotchas; handle errors properly and do not rely on it. BashPitfalls 60 says the shell cannot tell which non-zero status is an error, that `pipefail` produces false failures, and that `set -u` is the least bad of the three; it advises `pipefail` only for pipelines where it fits. The Google guide prescribes none of the three. The notes enable all three, for these reasons:

1. An unchecked command that fails is the worst case, because the script carries on in a half-done state. Strict mode stops the script in plain control flow (checked: `grep` without a match and `v=$(false)` stop it), and a false stop shows up in the first test run and is fixed once. Without it the same mistakes pass silently.
2. ShellCheck can audit where the net has holes: `shellcheck -o check-set-e-suppressed,check-extra-masked-returns` reports them (SC2310, SC2311, SC2312). The checks are not in the `.shellcheckrc`, because they also report every helper function used in an `if`; run them as an occasional audit ([tooling](02-project-setup-and-tooling.md#shellcheck)).

The net is not the plan. Every command whose failure you expect or care about gets an explicit check, whatever the options say. To go back to the rule of the other camp, delete the `set` line and keep the rest of this note.

### Where strict mode does nothing or surprises

Each row was run on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9, with the same result unless noted.

| Situation | What happens | What to write |
| --- | --- | --- |
| A function called in a condition: `if f`, `f && x`, `f \|\| x` | `set -e` is off for everything inside `f`: `f() { false; echo "f continued"; }` printed "f continued" | `\|\| return` on each step that matters inside the function. The optional check `check-set-e-suppressed` reports the call (SC2310) |
| A command substitution | Without `inherit_errexit` the subshell ignores `-e`: `v=$(false; echo ran)` gives `v=ran`. With it, the script stops. `shopt -s inherit_errexit` is an error on 3.2.57 | Set `inherit_errexit` (Bash 4.4), and still check the status of the substitution |
| `local v=$(cmd)` | `local` returns its own status, so a failing `cmd` goes unnoticed | `local v` and then `v=$(cmd)` |
| A pipeline | Only the last status counts; with `pipefail` the last non-zero status counts. If the consumer exits early, the producer dies of SIGPIPE: `seq 1 200000 \| grep -q 1` returned 141 | Let the consumer read all input (`grep 1 >/dev/null` returned 0) or capture the output first |
| `&&` and `\|\|` lists | Only the last command of the list can stop the script: `false && echo x` does not | Use `if` |
| `((...))`, `let` | A value of 0 gives status 1: `((i++))` with `i=0` stops the script on 4.1 and newer; 3.2.57 carries on | `i=$((i + 1))` |
| A command whose status is an answer (`grep`, `diff`, `test`) | `echo abc \| grep zzz` stops the script | `if grep -q ...; then`, or `cmd \|\| true` with a comment that says why |
| A process substitution | Its exit status is discarded | Read its output and check it separately |
| `set -u` | An unset variable stops the script with "unbound variable" (status 127 on every tested version). `$@` and `$*` are exempt, and empty arrays are fine from 4.4 | `${var-}` or `${var:-default}` |

### Handle errors explicitly

```bash
# fragment
cd -- "${dir}" || return 1

if ! cp -- "${src}" "${dst}"; then
  err "cannot copy ${src} to ${dst}"
  return 1
fi

status=0
some_command || status=$?
```

- Branch on a command with `if command` or `command || handler`. Keep the status of a command that may fail with `status=0; cmd || status=$?`; the script is not stopped there (checked).
- Check the parts of a pipeline with `PIPESTATUS`, and copy it on the next line, because every command overwrites it, including `[` (Google guide). `false | true | false` leaves `1 0 1` (checked).
- Do not turn the options off and on around a block (`set +e`); use the forms above.
- Validate arguments and environment first: `: "${API_URL:?API_URL must be set}"` stops with a message when the variable is unset or empty.
- Make destructive commands fail closed: `rm -rf -- "${dir:?}/"*` stops when `dir` is empty (checked: "dir must not be empty"), instead of expanding to `/*` (ShellCheck SC2115).

### Messages and exit codes

- Error messages go to stderr, start with the program name, and say what failed and what to do. `die` prints and exits; it is the one function that calls `exit`.

```bash
readonly PROG="${0##*/}"

err() {
  printf '%s: %s\n' "${PROG}" "$*" >&2
}

die() {
  err "$@"
  exit 1
}

[[ $# -ge 1 ]] || die 'a file name is required'
```

- Exit with 0 for success, 1 for any failure, and 2 for misuse of the command line, which is what the Bash builtins return for incorrect usage (Bash manual, Exit Status). Use other values from 3 to 125 only when a caller must tell failures apart, and document them in the usage text. Do not use 126, 127 or values above 128: Bash uses 126 for a command that is not executable, 127 for one that is not found, and 128+N for death by signal N.
- `return` leaves a function and `exit` ends the shell. A script ended by SIGTERM exits with 143 (checked).

### Cleanup with traps

```bash
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/demo.XXXXXX")"

cleanup() {
  rm -rf -- "${tmp_dir:?}"
}
trap cleanup EXIT

printf 'working in %s\n' "${tmp_dir}"
```

- `trap cleanup EXIT` runs when the script ends normally, after `exit N`, when `set -e` stops the script, and on SIGTERM and SIGHUP, where the script exits with 143 and 129 (checked on Bash 3.2.57 and 5.2.15). A process killed with SIGKILL runs no trap.
- Inside the trap, `$?` is the status that ends the script (checked), and the script exits with it unless the trap itself exits.
- A script has one `EXIT` trap: a second `trap ... EXIT` replaces the first. Libraries do not set traps.
- Create temporary files with `mktemp`, never with a fixed name. `mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX"` works on macOS and on Debian, while `mktemp -d -t name` fails on GNU ("too few X's in template", checked) ([security](10-security.md#temporary-files-and-permissions)).
- Write the cleanup so that it works when the previous run crashed and cleaned up nothing (clig.dev).
- For a diagnostic message that says where a failure happened, use an `ERR` trap with `set -E` so that functions inherit it:

```bash
# fragment
set -Eeuo pipefail
trap 'printf "failed at line %s: %s\n" "${LINENO}" "${BASH_COMMAND}" >&2' ERR
```

The line number inside a function was one lower on 3.2.57 than on 5.x for the same failing command (checked), so treat it as a hint on old Bash.

### Debugging

- Run `bash -x ./script`, or put `set -x` and `set +x` around the suspect block. `xtrace` prints each command after expansion, with quotes that show how the arguments were split (BashGuide).
- Set `PS4` in single quotes so that it expands when printed: `PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}: '`. In double quotes it expands once, at assignment.
- `BASH_XTRACEFD` (Bash 4.1) sends the trace to another file descriptor and keeps stderr clean. A trace shows the values of secrets ([security](10-security.md#secrets)).
- Run ShellCheck first. Most "why does this not work" questions are answered by it, and by BashPitfalls (BashGuide advises reading both before asking).

## Sources and raw notes

Pages read on 2026-10-30:

- [BashFAQ/105](https://mywiki.wooledge.org/BashFAQ/105): the case against `set -e`, the exercises, the three recommendations. [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) entries 27, 60.1, 60.2 and 60.3. [BashFAQ/112](https://mywiki.wooledge.org/BashFAQ/112): advantages and disadvantages of `set -u`.
- Bash Reference Manual: [The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) (every context in which `-e` is ignored, `-u`, `pipefail`, `-E`), [The Shopt Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html) (`inherit_errexit`, `lastpipe`), [Exit Status](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html), and the `trap`, `exit` and `return` entries of the Bourne shell builtins.
- Bash NEWS and CHANGES: `((` and `[[` obey `set -e` since 4.1; `set -u` and `$@` since 4.1; `inherit_errexit` in 4.4; empty arrays and `set -u` fixed in 4.4-rc2.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): return values, `PIPESTATUS`, `err()`, stderr, `local` and `$?`.
- [Command Line Interface Guidelines](https://clig.dev/): exit codes, clean-up after a crash.
- ShellCheck 0.11.0: the codes in this note come from its output on test files.
- The behaviours marked "checked" were run on Bash 3.2.57 (macOS), 5.1.8, 5.2.15 and 5.3.9 (Docker images `mysql:8.0`, `node:24-slim` and `postgres:17-alpine`, without network). Every `bash` block without a `# fragment` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1.
