# Bash Portability and Versions

## Summary

Scripts are written for Bash, not for `sh` and not for zsh. Each script declares the oldest Bash it supports and checks it at the top; the default is Bash 4.4, and a script that must run on the stock macOS Bash (3.2) declares 3.2 and uses the subset in this note. The release table shows which feature needs which version, and the last section lists the places where GNU and BSD tools differ, as measured on macOS 26 and Debian 12.

## Rules

### Bash, not sh, not zsh

- Write Bash and start with `#!/usr/bin/env bash`. There is no need to avoid Bash-only syntax ("bashisms") in Bash scripts (Google guide). A script that must run under plain `sh` is outside these notes: write it in POSIX syntax, check it with `shellcheck -s sh`, and start it with `#!/bin/sh`.
- zsh is not Bash. The default shell on macOS is zsh, and the shell that runs commands typed in the terminal is not the shell that runs `#!/usr/bin/env bash` scripts. In zsh, arrays start at 1 (`a=(x y); echo ${a[1]}` prints `x`) and an unquoted `$var` is not split into words (checked). Test a script with `bash ./script`, not by pasting it into the terminal.

### Versions in the field

On 2026-10-30:

- The current release is Bash 5.3 (maintainer's page). Homebrew packages 5.3.20.
- macOS ships Bash 3.2 as `/bin/bash` and has since Mac OS X 10.5 (maintainer's page). With no newer Bash on `PATH`, `#!/usr/bin/env bash` resolves to that 3.2.57(1) release.
- Most GNU/Linux systems use Bash 5.1 or 5.2, and some still use 4.4 (maintainer's page). The Docker images used for the checks in these notes carry 5.1.8 (`mysql:8.0`, Oracle Linux), 5.2.15 (`node:24-slim`, Debian 12) and 5.3.9 (`postgres:17-alpine`, Alpine).

### Declaring the version

- Every script says which Bash it needs: a `Requires:` line in the header comment and a check at the top. The default is **Bash 4.4**. It is the oldest release with `inherit_errexit`, with empty arrays that are safe under `set -u`, with `mapfile -d`, `local -` and the `${var@Q}` family, and long-supported distributions still ship it.
- A script that must run on a stock macOS (for example a setup script that installs Homebrew) declares **Bash 3.2** and follows the subset below.
- The check goes before any syntax or option of a newer version. Bash reads a script command by command, so the guard stops the script before the later lines are parsed; on 3.2.57 the guard exited with status 1 before `declare -A` and `shopt -s inherit_errexit` could fail (checked).

```bash
if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404)); then
  printf '%s: requires Bash 4.4 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi
```

- A script that declares 4.4 stops with that message until a newer Bash is first on `PATH`. `brew install bash` provides one (5.3.20 today); it changes what `#!/usr/bin/env bash` runs for every script on the machine, so install it on purpose.

### Features by release

From the Bash NEWS file. Features marked with an asterisk failed on Bash 3.2.57 when run (checked).

| Release | New in this release |
| --- | --- |
| 3.0 | `{1..10}` sequences, `[[ ... =~ ... ]]` with `BASH_REMATCH`, `set -o pipefail`, `BASH_SOURCE`, `BASH_LINENO`, `FUNCNAME` as an array |
| 3.1 | `+=` append for strings and arrays, `nocasematch` |
| 3.2 | A quoted right side of `=~` is matched as a string. Stock macOS stops here |
| 4.0 | Associative arrays `declare -A`*, `mapfile` and `readarray`*, `${v,,}` and `${v^^}`*, `&>>`*, `\|&`*, `;;&`, `globstar`*, `coproc`, fractional `read -t` |
| 4.1 | `BASH_XTRACEFD`* (3.2.57 ignores it and traces to stderr), `{var}` redirections, `read -N`. `[[` and `((` obey `set -e` and the `ERR` trap |
| 4.2 | `[[ -v name ]]`*, `shopt -s lastpipe`*, `printf '%(fmt)T'`*, `declare -g`, negative array subscripts and `${v:off:-len}` |
| 4.3 | Namerefs `local -n`*, `wait -n`*, `BASH_COMPAT` |
| 4.4 | `shopt -s inherit_errexit`*, the `${v@Q}` family*, `mapfile -d`, `local -`*. Empty arrays are no longer an error under `set -u` |
| 5.0 | `EPOCHSECONDS`* and `EPOCHREALTIME`, `BASH_ARGV0`, `wait -f`, `localvar_inherit` |
| 5.1 | `SRANDOM`, `wait -p`, `test -v N` for positional parameters, `local -I`, `${v@K}` |
| 5.2 | `patsub_replacement` (on by default), `globskipdots` (on by default), `printf %Q`, `varredir_close` |
| 5.3 | `${ command; }` without a fork (checked: 5.3.9 only), `GLOBSORT`, `trap -P`, `BASH_MONOSECONDS`, `read -E`, `bash_source_fullpath` |

Changes in behaviour that break a script silently:

- `((i++))` with `i=0` under `set -e` stops the script on 4.1 and newer, and carries on on 3.2.57 (checked). A script tested only on the Mac can die on Linux.
- Under `set -u`, `"${arr[@]}"` of an empty array is an error up to 4.3 and fine from 4.4. On 3.2.57 it stopped with "unbound variable" (checked; CHANGES 4.4-rc2, BashFAQ/112).
- From 5.2 an `&` in the replacement of `${v/pat/repl}` stands for the matched text: `v=abc; echo "${v/b/[&]}"` printed `a[&]c` on 3.2.57 and 5.1.8 and `a[b]c` on 5.2.15 and 5.3.9 (checked). Write `\&` for a literal ampersand, or turn the option off with `shopt -u patsub_replacement`.
- From 5.2 a glob never matches `.` and `..` (`globskipdots`).
- `${var:?message}` exits with status 1 on 5.x and 127 on 3.2.57 (checked). Do not depend on the number.

### The Bash 3.2 subset

A script that declares Bash 3.2 keeps `local`, indexed arrays, `[[ ]]`, `=~`, `+=`, `{1..n}`, `pipefail`, process substitution, here-strings, `printf -v`, `BASH_SOURCE` and `FUNCNAME`, all of which worked on 3.2.57. It replaces the newer features like this:

| Instead of (Bash 4.0 and newer) | Use on 3.2 |
| --- | --- |
| `mapfile -t lines < <(cmd)` | `while IFS= read -r line; do lines+=("${line}"); done < <(cmd)` |
| `declare -A map` | A `case` in a function, or two parallel arrays |
| `${v,,}`, `${v^^}` | `tr '[:upper:]' '[:lower:]'` |
| `[[ -v name ]]` | `[[ -n "${name+set}" ]]` |
| `cmd1 \|& cmd2`, `cmd &>> file` | `cmd1 2>&1 \| cmd2`, `cmd >> file 2>&1` |
| `printf '%(%F)T' -1`, `EPOCHSECONDS` | `date +%F`, `date +%s` |
| `shopt -s inherit_errexit`, `lastpipe`, `globstar` | Leave them out; use process substitution and `find` |
| `"${a[@]}"` of a possibly empty array under `set -u` | `${a[@]+"${a[@]}"}` (checked) |
| `local -n`, `wait -n`, `${v@Q}`, `local -` | Do not use them. Quote with `printf '%q'` |

### GNU and BSD tools

macOS carries BSD tools and Linux carries GNU tools. Measured on macOS 26 and on Debian 12:

| Need | Works on both | GNU only | BSD only |
| --- | --- | --- | --- |
| In-place edit | `sed -i.bak 's/a/b/' f && rm f.bak` | `sed -i 's/a/b/' f` | `sed -i '' 's/a/b/' f` (GNU takes `''` as the script) |
| Extended regex | `sed -E`, `grep -E` | `grep -P` | |
| Dates | `date +%s`, `date +%F` | `date -d '2026-01-01'` | `date -v+1d` |
| File size | | `stat -c %s f` | `stat -f %z f` |
| Temporary directory | `mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX"` | | `mktemp -d -t name` |
| Empty input to `xargs` | `xargs -r` | | |
| Listing | `find -print0`, `xargs -0` | `find -printf` | |
| Misc | `readlink -f`, `realpath`, `sort -V`, `base64 -d`, `mkdir` as a lock | `flock`, `timeout`, `tac`, `shuf` | |

- `readlink -f`, `realpath`, `sort -V` and `base64 -d` worked on both of these systems, but they are not in POSIX; an older macOS may lack them.
- Use the form in the first column when one exists. When a script needs a GNU-only tool, say so in the header and check for it with `command -v` ([scripts](08-scripts-and-command-line.md#environment-and-configuration)).

## Sources and raw notes

Pages read on 2026-10-30:

- [The maintainer's Bash page](https://tiswww.case.edu/php/chet/bash/bashtop.html): the current release, Apple's Bash 3.2, the versions in distributions.
- Bash [NEWS](https://tiswww.case.edu/php/chet/bash/NEWS) (releases 3.0 to 5.3) and [CHANGES](https://tiswww.case.edu/php/chet/bash/CHANGES) (the `set -u` rules of 4.1 and 4.4-rc2).
- Bash Reference Manual: [The Shopt Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html) (`inherit_errexit`, `lastpipe`, `patsub_replacement`, `globskipdots`).
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): choosing a shell, macOS and the Bash version, "make note of which version of Bash is required".
- [BashFAQ/112](https://mywiki.wooledge.org/BashFAQ/112) and [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) ("no need to strive for POSIX-compatibility").
- No Bash 4.x binary was available for these checks, so the rows for 4.0 to 4.4 in the release table, and the choice of 4.4 as the default minimum, rest on the NEWS and CHANGES files and on the results from 3.2.57 and 5.1.8 and newer; no code was run on a 4.x release.
- Checks run on 2026-10-30: `/bin/bash --version` (3.2.57) and `zsh --version` (5.9); `brew info bash` (5.3.20); each feature and behaviour above marked "checked" on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9; the userland table on macOS 26 and on Debian 12 (`node:24-slim`). Every `bash` block without a `# fragment` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1.
