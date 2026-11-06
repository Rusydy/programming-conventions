# Bash Project Layout and Files

## Summary

Executables and libraries are different kinds of files with different rules: an executable has a shebang, no extension and the executable bit; a library has the `.sh` extension, no executable bit and defines functions only. Every executable starts with the same header, sets its shell options once, declares constants, defines functions and ends with `main "$@"`. The skeleton in this note is the template for new scripts.

## Rules

### Layout

No source prescribes a directory layout for Bash projects. These notes use the one that the file rules below imply:

```text
project/
  bin/              executables: no extension, mode 755, shebang
  lib/              libraries: .sh, mode 644, no shebang, sourced only
  test/             *.bats files, plus test_helper.bash for shared helpers
  .editorconfig     shfmt and editors (see tooling)
  .shellcheckrc     ShellCheck (see tooling)
```

A script that does one job on its own may live alone in the project root or in `scripts/`; it follows the same file rules.

### File rules

- **Executables** have no extension when they are meant to be run as commands, which is the case for everything in `bin/` (Google guide). A `.sh` extension is allowed for a script that is run by path from a checkout (an installer, a setup script), because editors and code hosts recognise it. Do not mix both styles in one directory.
- **Libraries** have the `.sh` extension, are not executable and have no shebang, because they are never run directly. The first comment line says so: `# Library: source this file, do not run it.`
- **Names** use lowercase letters, digits and underscores (Google guide): `make_template`, not `make-template`.
- **Tests** end in `.bats` and are named after the unit they test: `test/greet.bats`.
- **Line endings** are LF. A carriage return at the end of a line breaks the shebang and the syntax; `tr -d '\r' < script > tmp && mv tmp script` removes them (BashGuide).
- **Permissions:** `chmod 755` for executables, `chmod 644` for libraries and tests, and commit the executable bit.

### Shebang and shell options

- Start every executable with `#!/usr/bin/env bash`. This differs from the Google guide, which requires `#!/bin/bash` ([where the guides disagree](04-naming-comments-and-style.md#where-the-guides-disagree)). `env` finds the first Bash on `PATH`, so a newer Bash (Homebrew, another package manager) wins over the system one, and the BashGuide recommends this form. On macOS the system Bash at `/bin/bash` is 3.2 and has been since Mac OS X 10.5 according to the maintainer's page.
- A Bash script never starts with `#!/bin/sh`. That runs it as a POSIX shell, even where `sh` is a link to Bash (BashGuide). A script that must run under plain `sh` is a different kind of script: write it in POSIX, check it with `shellcheck -s sh`, and treat it as outside these notes.
- No options on the shebang line. Set them with `set` in the file, so that `bash script_name` works like `./script_name` (Google guide).

### Structure of an executable

The order is fixed (Google guide): header comment, Bash version guard, `set` and `shopt`, constants, functions, `main`, and the call of `main`. This script is complete and tested; start new scripts from it.

```bash
#!/usr/bin/env bash
#
# Greet each name given on the command line.
#
# Requires: Bash 4.4 or newer.

if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404)); then
  printf '%s: requires Bash 4.4 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi

set -euo pipefail
shopt -s inherit_errexit

readonly PROG="${0##*/}"

#######################################
# Print the help text.
# Outputs:
#   Writes usage to stdout
#######################################
usage() {
  cat <<EOF
Usage: ${PROG} [-n | --dry-run] NAME...

Greet each NAME.

Options:
  -h, --help     show this help and exit
  -n, --dry-run  show what would be done
EOF
}

err() {
  printf '%s: %s\n' "${PROG}" "$*" >&2
}

main() {
  local dry_run=false
  local -a names=()

  while (($#)); do
    case "$1" in
      -h | --help)
        usage
        return 0
        ;;
      -n | --dry-run) dry_run=true ;;
      --)
        shift
        names+=("$@")
        break
        ;;
      -*)
        err "unknown option: $1"
        usage >&2
        return 2
        ;;
      *) names+=("$1") ;;
    esac
    shift
  done

  if ((${#names[@]} == 0)); then
    err 'at least one NAME is required'
    usage >&2
    return 2
  fi

  local name
  for name in "${names[@]}"; do
    if [[ "${dry_run}" == true ]]; then
      printf 'would greet %s\n' "${name}"
    else
      printf 'Hello, %s!\n' "${name}"
    fi
  done
}

main "$@"
```

- A function called `main` is required once the script has any other function, and the last non-comment line is `main "$@"` (Google guide). `main` returns its status, which becomes the exit status of the script. A short linear script of a few lines needs no `main`.
- The version guard comes first, before any syntax or option that older Bash does not know, because Bash reads and runs a script command by command; on 3.2.57 the guard above stops the script before `shopt -s inherit_errexit`, which would fail there ([versions](09-portability-and-bash-versions.md#declaring-the-version)).
- Only the guard, `set`, `shopt` and constants come before the functions. Do not hide executable code between functions (Google guide).
- Exit statuses: 0 for success, 2 for misuse of the command line, 1 for every other failure ([error handling](07-error-handling-and-safety.md#messages-and-exit-codes)).
- Run on Bash 5.1.8, 5.2.15 and 5.3.9, the script gives identical output; on 3.2.57 it stops with the guard message and exit status 1.

### Libraries

- A library defines functions and constants and nothing else. Sourcing it must not run anything, and it must not call `set`, `shopt`, `trap`, `cd` or `exit`: those change the shell of the caller.
- Prefix the functions of a library with its name and `::` (Google guide): `log::info`, `fs::ensure_dir`. Names with `::` work on Bash 3.2.57 to 5.3.9. Plain scripts do not need a prefix.
- Every function in a library has a header comment ([comments](04-naming-comments-and-style.md#comments)).
- A library does not depend on the current directory; it uses `BASH_SOURCE` for paths relative to itself.

### Finding files next to the script

- Use `BASH_SOURCE[0]`, not `$0`, to find the directory of a script, and put it in a constant:

```bash
# fragment
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=../lib/log.sh
source "${SCRIPT_DIR}/../lib/log.sh"
```

- This idiom returns the directory of the link when the script is started through a symbolic link (checked on 3.2.57 and 5.x). BashFAQ/028 says that no method works in every case, since a script has no single location. The advice there is to avoid the problem: keep configuration in the home directory of the user or in `/etc`, not next to the script. `readlink -f` resolves links and works on macOS 26 and on Debian, but it is not in POSIX.
- Computed `source` paths need the `# shellcheck source=` directive shown above, as the ShellCheck manual describes.

## Sources and raw notes

Pages read on 2026-10-30:

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): file extensions, libraries, SUID, function location, `main`, naming of files and library functions, shell options set with `set`.
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): the `#!/usr/bin/env bash` shebang, the `sh` header, and carriage returns.
- [BashFAQ/028](https://mywiki.wooledge.org/BashFAQ/028): location of a script, configuration in the home directory or `/etc`.
- [The maintainer's Bash page](https://tiswww.case.edu/php/chet/bash/bashtop.html): Apple has shipped Bash 3.2 since Mac OS X 10.5; the current release is 5.3.
- ShellCheck 0.11.0 manual: the `source=` and `shell=` directives.
- The skeleton was checked with ShellCheck 0.11.0 (with the optional checks of the tooling note) and shfmt 3.14.1 (with the `.editorconfig` of that note), and run on Bash 3.2.57 (macOS), 5.1.8, 5.2.15 and 5.3.9 (Docker images `mysql:8.0`, `node:24-slim` and `postgres:17-alpine`, without network). The `::` names and the symbolic link behaviour were run on the same versions.
