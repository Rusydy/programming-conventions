# Bash Scripts and the Command Line

## Summary

A script is a command-line program, so it follows the conventions of one: results on stdout and messages on stderr, `--help` and short and long flags, prompts only on a terminal, colour only on a terminal and never when `NO_COLOR` is set, and a clear exit status. Setup scripts are written to be run twice safely. The guidance here comes from the Command Line Interface Guidelines, applied to Bash with the idioms of the other notes.

## Rules

### Output streams and colour

- Print the result of the command to stdout, and also everything that another program may read. Print progress, warnings and errors to stderr, so that a pipe passes on only the result (clig.dev).
- Print something on success but keep it brief, and say what changed when the command changes state; a command that prints nothing for a long time looks hung. Add `-q`/`--quiet` to silence the non-essential output (clig.dev).
- Use colour only when the stream is a terminal and `NO_COLOR` is not set to a non-empty value. The `NO_COLOR` convention says that colour is off when the variable is present and not an empty string, whatever its value; a flag or a configuration file of the user may switch colour back on.

```bash
if [[ -t 2 && -z "${NO_COLOR-}" ]]; then
  readonly RED=$'\033[31m' RESET=$'\033[0m'
else
  readonly RED='' RESET=''
fi

printf '%serror%s: something failed\n' "${RED}" "${RESET}" >&2
```

### Help and usage

- `-h` and `--help` print the usage to stdout and exit with 0. A missing or wrong argument prints a short message and the usage to stderr and exits with 2. The skeleton in the layout note does both ([layout](03-project-layout-and-files.md#structure-of-an-executable)).
- The usage text has the synopsis, one line on what the program does, and the options. Examples help. Put it in a function with a here-document.
- Add `--version` when the script is installed or shared.

### Options and arguments

- Prefer flags to positional arguments when there is more than one input. Give every flag a long form. Use the common names so that nobody has to look them up: `-h/--help`, `--version`, `-n/--dry-run`, `-q/--quiet`, `-f/--force`, `-o/--output`, `-d/--debug`, `--no-input`. Avoid `-v`, which people read as "verbose" or as "version" (clig.dev).
- Parse the options with a manual `while`/`case` loop, as the skeleton does. It handles long options; `getopts` does not (BashFAQ/035). Do not use the external `getopt(1)` (BashFAQ/035). Accept both `--output FILE` and `--output=FILE`, check that a value is present, stop at `--`, and reject unknown options with status 2.

```bash
# fragment
while (($#)); do
  case "$1" in
    -o | --output)
      (($# >= 2)) || die '--output needs a value'
      output=$2
      shift
      ;;
    --output=*) output=${1#*=} ;;
    -q | --quiet) quiet=true ;;
    --)
      shift
      break
      ;;
    -*) die "unknown option: $1" ;;
    *) break ;;
  esac
  shift
done
```

- `getopts` is fine for a small script with single-letter options only. Start the option string with `:` for silent error handling, and shift the parsed options afterwards. (The Bash manual: `OPTIND` is not reset between calls.)

```bash
verbose=false
output=''
while getopts ':hvo:' opt; do
  case "${opt}" in
    h)
      printf 'usage: tool [-h] [-v] [-o FILE] [ARG...]\n'
      exit 0
      ;;
    v) verbose=true ;;
    o) output=${OPTARG} ;;
    :)
      printf 'option -%s needs a value\n' "${OPTARG}" >&2
      exit 2
      ;;
    *)
      printf 'unknown option -%s\n' "${OPTARG}" >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))
printf 'verbose=%s output=%s rest=%s\n' "${verbose}" "${output}" "$*"
```

- Validate all input before changing anything, and say in the message what was wrong and what is valid (clig.dev).
- A generator such as argbash can produce the parser; clig.dev lists it for Bash. The notes do not use it, to keep scripts free of generated code.

### Interactivity

- Prompt only when stdin is a terminal (`[[ -t 0 ]]`). Otherwise fail with the flag that answers the question (`--yes`, `--force`). Offer `--no-input` to switch every prompt off (clig.dev).
- Read a password with `read -r -s`, which does not echo it.
- Confirm before a destructive action, and skip the question with `--yes`.

```bash
confirm() {
  if [[ ! -t 0 ]]; then
    printf 'not a terminal; pass --yes to continue\n' >&2
    return 1
  fi
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "${reply}" == [yY] ]]
}

confirm 'Delete the cache?' </dev/null || echo 'refused'
```

### Environment and configuration

- Read settings from the environment where it helps, with a default: `${MYTOOL_DIR:-${HOME}/.mytool}`. Name your variables with the program prefix, in uppercase letters, digits and underscores. Honour the general ones when they apply: `NO_COLOR`, `TMPDIR`, `HOME`, `EDITOR`, `PAGER`, `DEBUG` (clig.dev).
- Keep configuration in the home directory of the user or in `/etc`, not next to the script (BashFAQ/028).
- Check that the programs the script needs exist before the work starts:

```bash
require() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    return 1
  }
}

require bash
require no-such-tool-xyz || echo 'handled'
```

- `command -v` is the check. ShellCheck's optional check `deprecate-which` flags `which`. Tools that exist only in GNU or only in BSD userland need a note in the header ([portability](09-portability-and-bash-versions.md#gnu-and-bsd-tools)).

### Safe to run twice

- Write setup and deploy scripts so that a second run finds the work done and does nothing. Test the state first: `mkdir -p`, `ln -sfn`, `command -v tool || install_tool`, `grep -qxF line file || printf '%s\n' line >>file`. clig.dev asks for idempotent operations where possible.
- Offer `--dry-run` for anything that changes the system. A wrapper that prints the command instead of running it handles simple commands only; it cannot handle pipelines, redirections or loops (BashFAQ/050).

```bash
DRY_RUN=true

run() {
  if [[ "${DRY_RUN}" == true ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

run rm -rf -- 'some dir'
```

- Retry a flaky command with a function, not with a copy of the loop. `until "$@"` is a condition, so `set -e` does not stop the script inside it:

```bash
retry() {
  local -i attempts=$1 n=0
  shift
  until "$@"; do
    ((++n < attempts)) || return 1
    sleep 1
  done
}

retry 3 true
retry 2 false || echo "gave up with status $?"
```

- Do not let two copies of a script run at once when that breaks something. `mkdir` is an atomic lock that works on macOS and Linux; `flock` is missing on macOS. Release the lock in the `EXIT` trap, and document how to remove a lock that a crash left behind.

```bash
lock_dir="$(mktemp -d)/lock.d"

acquire_lock() {
  mkdir "${lock_dir}" 2>/dev/null
}

acquire_lock && echo 'first: acquired'
acquire_lock || echo 'second: busy'
rmdir "${lock_dir}"
```

- Check for root with `((EUID == 0))` only to refuse to run as root or to explain what is missing. Prefer `sudo` on the one command that needs it over running the whole script as root (Google guide: use `sudo` for elevated access).

## Sources and raw notes

Pages read on 2026-10-30:

- [Command Line Interface Guidelines](https://clig.dev/): The Basics, Help, Output, Errors, Arguments and flags, Interactivity, Robustness, Signals and control characters, and Environment variables.
- [NO_COLOR](https://no-color.org/): the convention and its FAQ on configuration files and flags.
- [BashFAQ/035](https://mywiki.wooledge.org/BashFAQ/035) (options), [BashFAQ/028](https://mywiki.wooledge.org/BashFAQ/028) (location of configuration), [BashFAQ/050](https://mywiki.wooledge.org/BashFAQ/050) (commands in variables).
- Bash Reference Manual: `getopts`, `read`, `command` and `local` entries of the builtin pages.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): `getopts` example, stderr, `sudo`.
- Every `bash` block without a `# fragment` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1. `confirm`, `require`, `retry`, the lock and the `getopts` example were run on Bash 3.2.57 (macOS), 5.1.8, 5.2.15 and 5.3.9 with the same output. Command availability (`flock`, `timeout`) was checked on macOS 26 and on Debian 12.
