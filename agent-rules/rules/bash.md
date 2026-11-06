---
paths:
  - "**/*.sh"
  - "*.sh"
  - "**/*.bash"
  - "*.bash"
  - "**/*.bats"
  - "*.bats"
  - "**/bin/*"
  - "bin/*"
  - "**/.shellcheckrc"
  - ".shellcheckrc"
---
# Bash conventions (every project)

Write idiomatic, readable Bash. Follow the shell's and its standard tools' conventions instead of inventing configuration ("convention over configuration"). This file is a digest of the notes in the `bash-conventions` folder of the programming-conventions repository, which hold the reasons, sources and checked examples. Read the matching note before a large change or when a rule here is unclear. The digest was synced with the notes on 2026-10-30; update it by hand whenever a note changes. The paths above match shell files, `.shellcheckrc` and anything in `bin/`; for an extensionless script elsewhere, read this file first.

## How to apply

- New and edited code follows this file. Leave untouched code alone unless asked to clean it up, and keep diffs small. Put mechanical changes (shfmt or ShellCheck upgrades, a newly enabled check, a change of the minimum Bash version) in separate commits.
- If the repository documents its own conventions, follow them first. Generated code is exempt. A script that must run under plain `sh` is outside this file: write POSIX and check it with `shellcheck -s sh`. A file in `bin/` whose shebang names another language (for example `#!/usr/bin/env python3`) is outside this file too: read and follow the rule of that language instead.
- First decide whether it is a Bash job. Bash is glue: calling programs, pipes, preparing files and environments, little data manipulation. Past about 100 lines, or with non-straightforward control flow, performance needs, structured data (JSON, XML, HTML), complex text processing or logic that only its author could maintain, say so and propose a structured language.
- Every script declares the oldest Bash it supports and checks it at the top. The default minimum is Bash 4.4; a script that must run on the stock macOS Bash declares 3.2 and keeps to the 3.2 subset. On macOS the stock `/bin/bash` is 3.2.57, so a 4.4 script stops at its guard there. Never run `brew install bash` unasked: it changes what `#!/usr/bin/env bash` starts for every script. Test newer Bash in a Docker image that carries it, started with `--network none`.
- Five choices in the notes are recorded decisions, not facts: strict mode, the 4.4 default, the `env bash` shebang, the Google style carried by `.editorconfig`, and five ShellCheck checks. Follow them; do not change them unasked.
- Before you report Bash changes as done, run `shfmt -d .`, `shfmt -f=0 . | xargs -0 shellcheck` and `bats test/` (or the project's own commands) and fix new findings. The newest stable tools on 2026-10-30 were ShellCheck 0.11.0, shfmt 3.14.1 and bats-core 1.14.0; the current Bash is 5.3.
- When sources disagree, the order is: what Bash does (manual, POSIX, NEWS and CHANGES, the real shell), this file and the notes, ShellCheck, the Google Shell Style Guide, Greg's Wiki (BashGuide, BashFAQ, BashPitfalls), the Command Line Interface Guidelines, tool defaults.

## Tooling

- shfmt formats, ShellCheck lints, bats-core tests; CI runs plain commands in that order, without flags. Two files in the project root configure them (the exact contents are in note 02). `.editorconfig`: `root = true`, `[*]` with `insert_final_newline = true`, then identical `[*.{sh,bash,bats}]` and `[[shell]]` sections (the second is read only by shfmt and covers scripts without an extension) with `indent_style = space`, `indent_size = 2`, `switch_case_indent = true` and `binary_next_line = true`. `.shellcheckrc`: `shell=bash`, `source-path=SCRIPTDIR`, `external-sources=true`, and `enable=` for `require-variable-braces`, `require-double-brackets`, `avoid-nullary-conditions`, `deprecate-which` and `useless-use-of-cat`.
- Fix findings. A justified disable goes on the line above the one command, names the code and gives the reason: `# shellcheck disable=SC2034 # read by the sourcing script`. A `source` with a computed path gets `# shellcheck source=<path>`. `check-set-e-suppressed` and `check-extra-masked-returns` are an occasional audit (`shellcheck -o ...`), not part of the rc.
- shfmt ignores `.editorconfig` as soon as a formatting flag is given, so use plain `shfmt -d .` (check) and `shfmt -w .` (fix). It writes `((i += 3))` and `$((2 + 2))` without inner spaces; the formatter wins. `shfmt -f=0 . | xargs -0 shellcheck` lints exactly the files shfmt recognises. No `bash -n`, `checkbashisms` or second linter.
- ShellCheck does not report `eval`, the `function` keyword, `echo "${x}"`, `((i++))` under `set -e` or lines over 80 columns: check those by eye.

## Layout and structure

- `bin/` holds executables (no extension, mode 755, shebang), `lib/` libraries (`*.sh`, mode 644, no shebang, sourced only), `test/` the `*.bats` files and `test_helper.bash`. A lone script may sit in the project root or in `scripts/`. File names: lowercase letters, digits, underscores. LF line endings.
- Every executable starts with `#!/usr/bin/env bash` (not `#!/bin/bash`; never `#!/bin/sh` for Bash) and has no options on that line. Order: header comment (what it does, plus `Requires: Bash 4.4 or newer.`), the version guard, `set -euo pipefail`, `shopt -s inherit_errexit` (Bash 4.4), `readonly` constants, functions, `main`, and `main "$@"` as the last non-comment line. `main` is required once there is another function, and its return status is the exit status. Start new scripts from the skeleton in note 03 (`usage`, `err`, a `while`/`case` option loop).
- The version guard comes before any syntax or option of a newer Bash (Bash reads a script command by command, so it stops the script in time):

```bash
if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404)); then
  printf '%s: requires Bash 4.4 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi
```

- A library defines functions and constants and nothing else: no `set`, `shopt`, `trap`, `cd` or `exit` when it is sourced. Name its functions `library::name`, give each a header comment, and take paths relative to it from `BASH_SOURCE`.
- Find the directory of a script with `SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"`; through a symbolic link it gives the directory of the link. Keep configuration in the home directory or `/etc`, not next to the script.

## Style and naming

- Two spaces, no tabs (except the body of a `<<-` here-document), 80 columns (no tool enforces it), `; then` and `; do` on the same line, `case` patterns indented one level (`a) cmd ;;` for a short action, no leading `(`, avoid `;&` and `;;&`), a long pipeline split before each `|` with `\`, a blank line between blocks.
- Functions and variables `lower_snake_case`. Constants and environment variables `UPPER_SNAKE_CASE`, with a program prefix for the variables of your program; constants are `readonly` and declared at the top (a computed constant is made readonly right after). Library functions `library::name`. A loop variable is named after what it loops over. Booleans are words compared as strings: `[[ "${dry_run}" == true ]]`.
- Brace named variables (`"${path}"`) and leave positional and special parameters bare (`"$1"`, `"$@"`, `"$#"`, `"$?"`). Braces are not quoting. Write names without `$` inside `(( ))`.
- Comments: a file header after the shebang; a header (Description, Globals, Arguments, Outputs, Returns) on every function that is not both obvious and short and on every library function; explain why, not what; `# TODO(name): ...`; delete dead code.
- Where the guides differ and the notes decided: `name() {` and never the `function` keyword; `printf '%s\n' "${x}"` for any variable data, `echo` only for fixed text without a backslash or a leading `-`; `==` in `[[ ]]` with a quoted right side; a regular expression in a variable (`re='^[0-9]+$'; [[ "${x}" =~ ${re} ]]`); always `for arg in "$@"`.

## Quoting and expansion

- Quote every expansion: `"${file}"`, `"$(cmd)"`, `"$1"`. Leave unquoted only integers in `(( ))`, `$?`, `$#`, `$$`, `$!` and a regular expression held in a variable. `"$@"` passes arguments on; `"$*"` only inside a message. Quote both sides of a string comparison in `[[ ]]`: an unquoted right side is a pattern.
- Lists live in arrays: `"${arr[@]}"`. Build commands with arrays, never in strings (variables hold data, functions hold code). Fill an array with `mapfile -t lines < <(cmd)` (Bash 4.0), never `a=( $(cmd) )`.
- Use parameter expansion before `sed`, `cut`, `basename` and `tr`: `${p##*/}`, `${p%/*}`, `${p%.gz}`, `${v:-d}`, `: "${v:=d}"`, `${v:?message}` (exit status 1 on Bash 5, 127 on 3.2: do not depend on the number), `${v,,}` and `${v^^}` (4.0), `${v@Q}` (4.4).
- `$(cmd)`, never backticks; it strips trailing newlines. `./*`, not `*`, and `--` before data arguments. A glob without a match stays literal: use `shopt -s nullglob` around the expansion, or `failglob`. Never parse `ls`; use globs, or `find -print0` with `while IFS= read -r -d ''` or `xargs -0`.
- `printf` for data, with a constant format string (`printf "$x"` breaks on `%` and `\`). `printf -v`, `%q`, `%(%F)T` (4.2). Quote the here-document delimiter (`<<'EOF'`) when `$` must stay literal.
- Arithmetic: `$(( ))` and `(( ))`; never `let`, `expr` or `$[ ]`.

## Variables, functions and control flow

- `local` for every variable of a function, loop variables included. Declare and assign apart when the value comes from a command substitution: `local v` and then `v="$(cmd)"`, because `local v=$(cmd)` hides the failure (SC2155). No results through globals: use stdout or the status, and list a global that cannot be avoided under `Globals:`. Under `set -u` read optional values as `${v-}` or `${v:-default}`. Export only what a child needs; `LC_ALL=C sort file` scopes a variable to one command.
- Functions: name the arguments on the first lines (`local src=$1 dst=$2`); return a status, print data to stdout and messages to stderr; end with `return`, and let only `die` and the top level call `exit`; pass lists by expanding them; avoid namerefs.
- Conditions: `[[ ]]` for strings and files, with `-z` and `-n` and never filler characters; `(( ))` for numbers once outside data is validated; `if cmd; then` and not a test of `$?`; `&&`, `||` and `!` inside one `[[ ]]`, never `-a` or `-o`; `case` with a `*)` branch. `A && B || C` is not if/else (C also runs when B fails): use `if`. A one-line guard such as `[[ -r "${f}" ]] || die "cannot read ${f}"` is fine.
- A `((...))` statement returns 1 when its value is 0: under `set -e`, `((count++))` at 0 stops the script on Bash 4.1 and newer (3.2 carries on). Write `count=$((count + 1))`.
- Loops: `for x in "${arr[@]}"`; `for ((i = 0; i < n; i++))`, not `seq`; `while IFS= read -r line || [[ -n "${line}" ]]` for a file (the last line may lack a newline); `done < <(cmd)` and not a pipe, because the subshell of a pipe loses variables; never `for x in $(cmd)` or `$(<file)`.
- Indexed arrays for lists; associative arrays (4.0) only for small lookup tables; no nested data or records, which is the point to switch language. Empty arrays are fine under `set -u` from Bash 4.4 and an error before.
- `cd -- "${dir}" || return`; to run a command elsewhere use a subshell: `( cd -- "${dir}" && make )`.

## Errors and strict mode

- Every executable runs `set -euo pipefail` and `shopt -s inherit_errexit` (4.4). It is a safety net, not the plan: every failure you expect gets an explicit check (`cmd || return`, `if ! cmd; then`, `status=0; cmd || status=$?`). Libraries never set shell options. Strict mode is contested among Bash experts, so it is a recorded decision: do not remove it unasked.
- The holes: `set -e` is off for everything inside a function called in `if`, `&&` or `||`; a command substitution ignores it without `inherit_errexit`; `local v=$(cmd)` masks the status; a pipeline reports its last command (with `pipefail`, the last non-zero one); with `pipefail` an early-exiting consumer (`grep -q`, `head`) makes the producer die of SIGPIPE with status 141, so let the consumer read all input (`grep pat >/dev/null`) or capture the output first; only the last command of an `&&`/`||` list can stop the script; `(( ))` and `let` with a value of 0; `grep` without a match; a process substitution's status is discarded; `set -u` stops on an unset variable (status 127 on every tested version).
- Copy `PIPESTATUS` at once; every command overwrites it. Validate early with `: "${VAR:?VAR must be set}"`, and make deletes fail closed: `rm -rf -- "${dir:?}/"*`.
- Errors go to stderr, start with the program name, and say what failed (`err` prints; `die` prints and exits 1). Exit 0 for success, 1 for failure, 2 for misuse of the command line; use 3 to 125 only when callers must tell failures apart, and never 126, 127 or a value above 128.
- Clean up with `tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX")"` and `trap cleanup EXIT`. The trap runs on a normal end, after `exit N`, when `set -e` stops the script, and on SIGTERM and SIGHUP; a script has one EXIT trap and libraries set none. `mktemp -d -t name` fails on GNU. For diagnostics use `set -E` with `trap '...' ERR` (LINENO inside functions is one lower on 3.2).
- Debug with `bash -x` or `set -x` and `set +x` around the block. Set `PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}: '` in single quotes. `BASH_XTRACEFD` (4.1) keeps the trace off stderr.

## Command-line behaviour

- Results go to stdout; progress, warnings and errors go to stderr. Print something brief on success and say what changed; `-q` or `--quiet` silences the rest. Use colour only when the stream is a terminal (`[[ -t 2 ]]`) and `NO_COLOR` is unset or empty.
- `-h` and `--help` print the usage to stdout and exit 0; misuse prints a short message and the usage to stderr and exits 2. Every flag has a long form. Use the common names: `-h/--help`, `--version`, `-n/--dry-run`, `-q/--quiet`, `-f/--force`, `-o/--output`, `-d/--debug`, `--no-input`; avoid `-v`. Prefer flags to positional arguments.
- Parse options with a manual loop, `while (($#)); do case "$1" in ... esac; shift; done`: it handles long options, `--opt value`, `--opt=value` and `--`, and rejects unknown options with status 2. `getopts` only in a small script with single-letter options; never the external `getopt`. Validate all input before changing anything.
- Prompt only when stdin is a terminal (`[[ -t 0 ]]`); otherwise fail and name the flag (`--yes`). `read -r -s` for passwords. Confirm destructive actions.
- Environment variables: uppercase letters, digits and underscores, with a program prefix, and a default (`${VAR:-default}`). Honour `NO_COLOR`, `TMPDIR`, `HOME`, `EDITOR`, `PAGER` and `DEBUG` where they apply. Check required programs up front with `command -v`, never `which`.
- Setup scripts are safe to run twice: test the state first (`mkdir -p`, `ln -sfn`, `command -v x || install_x`). `--dry-run` goes through a `run` wrapper that prints `printf ' %q' "$@"` and handles simple commands only. Retry with `until "$@"`. Lock with `mkdir` (atomic, portable; `flock` is missing on macOS) and release in the EXIT trap. Use `sudo` on the one command that needs it, not on the whole script.

## Versions and portability

- Bash, not `sh` and not zsh (zsh arrays start at 1 and do not split an unquoted `$var`); test with `bash ./script`.
- By release: 3.0 `{1..10}`, `=~`, `pipefail`; 3.1 `+=`; 4.0 `declare -A`, `mapfile`, `${v,,}`, `&>>`, `|&`, `globstar`; 4.1 `BASH_XTRACEFD`, and `[[` and `((` obey `set -e`; 4.2 `[[ -v x ]]`, `lastpipe`, `%(fmt)T`; 4.3 namerefs, `wait -n`; 4.4 `inherit_errexit`, `${v@Q}`, `local -`, empty arrays under `set -u`; 5.0 `EPOCHSECONDS`, `BASH_ARGV0`; 5.1 `SRANDOM`, `wait -p`; 5.2 `patsub_replacement`, `globskipdots`; 5.3 `${ cmd; }`, `GLOBSORT`. From 5.2 an `&` in the replacement of `${v/p/r}` stands for the matched text; write `\&` for a literal one.
- The 3.2 subset keeps `local`, indexed arrays, `[[ ]]`, `=~`, `+=`, `pipefail`, process substitution and `printf -v`. Replace the rest: `while IFS= read -r` with `+=` for `mapfile`; a `case` or two arrays for `declare -A`; `tr '[:upper:]' '[:lower:]'` for `${v,,}`; `[[ -n "${x+set}" ]]` for `[[ -v x ]]`; `2>&1 |` for `|&`; `>> f 2>&1` for `&>>`; `date +%s` for `EPOCHSECONDS`; `${a[@]+"${a[@]}"}` for a possibly empty array under `set -u`; no `lastpipe`, `inherit_errexit`, `globstar`, `local -n` or `wait -n`.
- GNU and BSD (macOS 26 and Debian 12): the portable in-place edit is `sed -i.bak ... && rm f.bak`. `grep -P`, `date -d`, `stat -c`, `find -printf`, `flock`, `timeout`, `tac` and `shuf` are GNU only; `date -v` and `stat -f` are BSD only; `sed -E`, `grep -E`, `xargs -r` and `mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX"` work on both. Name a GNU-only tool in the header and check for it with `command -v`.

## Security

- Input is data: quote, put `--` before data arguments, use `./*`, run commands from arrays. Never `eval`: use arrays, `case`, or `printf -v` after checking that the name matches `^[A-Za-z_][A-Za-z0-9_]*$`.
- Arithmetic evaluates strings: `(( x > 0 ))`, `[[ $x -gt 0 ]]`, `$(( ))`, `let`, `declare -i` and array subscripts run the command in `a[$(cmd)]`, while `[ "$x" -gt 0 ]` refuses it. Validate numbers first with a glob (`[[ -n "$1" && "$1" != *[!0123456789]* ]]`, not `[0-9]`). A leading zero means octal: use `$((10#${n}))`. Never use outside text as a key or an index in `(( ))` or `[[ -v a[$k] ]]`.
- `mktemp` for temporary files, `umask 077` for private ones, mode 600 for secrets. Never pass a secret as an argument (`ps` shows it): use stdin or a mode-600 file, and `read -r -s`. `set -x` prints secrets: use `set +x` around them, or `BASH_XTRACEFD`. No SUID or SGID on scripts; use `sudo`, and `cmd | sudo tee file >/dev/null` rather than `sudo cmd > file`.
- To pass a command line to `sh -c` or `ssh`, quote each word with `printf '%q '`. Pass file names with `find -print0 | xargs -0`.

## Testing

- bats-core in `test/*.bats`, run with `bats test/`. Start a file with `#!/usr/bin/env bats` and `bats_require_minimum_version 1.7.0`. Test executables from outside: `run -0 cmd args` (or `run -1`), then `$status`, `$output`, `${lines[n]}`. `setup` puts `bin/` on `PATH`; `$BATS_TEST_TMPDIR` is the place for files; a stub is a script earlier on `PATH`. To shorten `PATH`, start the script through an absolute interpreter (`/bin/bash script`), because `#!/usr/bin/env bash` needs `bash` on `PATH`. Never write into the project directory.
- Write assertions as `[ ... ]`, not `[[ ... ]]`: before Bash 4.1 a failing `[[ ]]` in the middle of a test does not fail it (it passed on 3.2.57). Each `.bats` file starts with `# shellcheck disable=SC2292` and the reason.
- Logic that needs unit tests goes in `lib/*.sh` and the test sources it; executables stay thin. A script that declares Bash 4.4 cannot be tested on macOS until a newer Bash is installed: run the suite in CI or in a container on the declared minimum and on the newest Bash. shfmt and ShellCheck cover `.bats` files.

## Pitfalls

- `for f in $(ls *.mp3)` -> `./*.mp3`. `cp $a $b` -> `cp -- "${a}" "${b}"`. `[ -n $x ]` -> `[[ -n "${x}" ]]`. `cmd; if [ $? -eq 0 ]` -> `if cmd; then`. `trap "rm $t" EXIT` -> single quotes. `rm -rf $d/*` -> `"${d:?}/"*`. `cmd 2>&1 >>log` -> `>>log 2>&1`. `find ... | xargs cmd` -> `-print0` and `xargs -0`. `IFS=, read -ra f <<< "${line}"` drops an empty last field: append the delimiter. `echo "$x"` -> `printf '%s\n' "${x}"`. `cat f | grep x` -> `grep x f`. `which x` -> `command -v x`. `[ a -a b ]` -> `[[ a && b ]]`. `tr [a-z] [A-Z]` -> `tr '[:lower:]' '[:upper:]'`. `done <<< "$(foo)"` -> `done < <(foo)`.
- Leave Bash when the script passes about 100 lines, needs data structures beyond lists, parses structured text, does complex text processing, or needs performance.

## Notes index

Each file is in the `bash-conventions` folder of the programming-conventions repository.

- `01-principles-and-sources.md`: principles, precedence, decisions to review, applying the notes
- `02-project-setup-and-tooling.md`: ShellCheck and shfmt configuration, versions, CI order
- `03-project-layout-and-files.md`: executables and libraries, shebang, the script skeleton
- `04-naming-comments-and-style.md`: formatting, names, comments, where the guides disagree
- `05-quoting-and-expansion.md`: quoting, arrays, parameter expansion, globs, printf
- `06-variables-functions-and-control-flow.md`: local, functions, conditions, loops, arrays
- `07-error-handling-and-safety.md`: strict mode and its holes, exit codes, traps
- `08-scripts-and-command-line.md`: streams, help, options, prompts, idempotence
- `09-portability-and-bash-versions.md`: version guard, features by release, 3.2 subset, GNU and BSD
- `10-security.md`: untrusted input, arithmetic injection, temporary files, secrets
- `11-testing.md`: bats-core, stubs, `[ ]` against `[[ ]]`
- `12-patterns-and-pitfalls.md`: mistake and replacement table, what does not belong in Bash
