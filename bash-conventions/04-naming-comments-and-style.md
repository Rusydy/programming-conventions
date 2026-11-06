# Bash Naming, Comments and Style

## Summary

The style is the Google Shell Style Guide, enforced by shfmt wherever a tool can enforce it. Functions and variables are lowercase with underscores, constants and environment variables are uppercase, named variables are written with braces, and every file and non-trivial function has a comment. The last section lists each point where the sources disagree and how the notes settle it.

## Rules

### Formatting

shfmt applies this list except for line length ([tooling](02-project-setup-and-tooling.md#shfmt)).

- Indent 2 spaces, never tabs. The one exception is the body of a `<<-` here-document, because `<<-` strips leading tabs only (Google guide).
- Keep lines to 80 characters. No tool enforces this. Put a long literal string in a here-document or break it with embedded newlines. A path or URL that cannot be split may stay on a line of its own.
- Split a pipeline that does not fit on one line at the pipes: one command per line, the `|` at the start of the next line, and `\` at the end of the previous one. The same applies to `&&` and `||` chains.
- Write `; then` and `; do` on the same line as `if`, `for`, `while` and `until`. `else`, `elif`, `fi` and `done` go on lines of their own, aligned with the opening word.
- Indent the patterns of a `case` one level. A short action goes on the pattern line (`a) cmd ;;`, with a space after `)` and before `;;`). A long action, or several commands, go on separate lines with `;;` on its own line. No `(` before a pattern. Avoid `;&` and `;;&`.
- Write arithmetic as shfmt does: `((i += 3))`, `$((2 + 2))`, `if ((a < b)); then`.
- Leave one blank line between logical blocks.

```bash
zones=(eu-west us-east ap-south)
for zone in "${zones[@]}"; do
  case "${zone}" in
    eu-*) region=europe ;;
    us-*)
      region=america
      printf 'busy region: %s\n' "${zone}" >&2
      ;;
    *) region=other ;;
  esac
  printf '%s is in %s\n' "${zone}" "${region}"
done

find . -type f -name '*.log' -print0 \
  | xargs -0 grep -l ERROR \
  | sort
```

### Naming

| Thing | Form | Example |
| --- | --- | --- |
| Function | lowercase with underscores | `parse_args` |
| Library function | `library::function` | `log::info` |
| Variable, parameter | lowercase with underscores | `file_count` |
| Loop variable | named after what is looped over | `for zone in "${zones[@]}"` |
| Constant | uppercase with underscores, `readonly`, declared at the top of the file | `readonly DEFAULT_DIR='.'` |
| Exported or environment variable | uppercase letters, digits and underscores, with a prefix for the program | `MYTOOL_DEBUG` |
| Source file | lowercase letters, digits and underscores | `make_template` |

- A constant may be set at run time or in a conditional, but it is made `readonly` right after (Google guide).
- Environment variable names use only uppercase letters, digits and underscores and do not start with a digit, which is the portable form (clig.dev). Prefix the variables of your program so that you do not take a widely used name.
- Name booleans as words and compare them as strings: `dry_run=false` and `[[ "${dry_run}" == true ]]`.

```bash
readonly DEFAULT_DIR='.'

backup::count_files() {
  local dir=${1:-${DEFAULT_DIR}}
  local file_count
  file_count="$(find "${dir}" -maxdepth 1 -type f | wc -l)"
  printf '%s files in %s\n' "${file_count}" "${dir}"
}

backup::count_files
```

### Variable expansion

In order of precedence (Google guide): stay consistent with the file you are editing; quote; brace named variables.

- Brace named variables: `"${path}"`, `"${HOME}"`, `"${dir}/${name}"`.
- Leave positional and special parameters bare: `"$1"`, `"$@"`, `"$#"`, `"$?"`, `"$$"`, `"$0"`. Use braces when needed: `"${10}"`, and `"${1}0"` when text follows.
- Braces are not quoting. Write `"${var}"`, never `${var}`.
- Write names without `$` inside `(( ))` and `$(( ))`: `((total += count))`.
- ShellCheck enforces exactly this with the optional check `require-variable-braces`: on a test file it reported `"$v"` and nothing for `"$1"`, `"$@"`, `"$#"`, `"$?"`, `"$0"` and `"$$"`.

### Comments

- **File header:** the first comment after the shebang describes the file in one or two sentences. A script adds a `Requires:` line with its minimum Bash version ([versions](09-portability-and-bash-versions.md#declaring-the-version)). Copyright and author lines are optional (Google guide).
- **Function header:** required for every function that is not both obvious and short, and for every function in a library. Use these fields, and leave out the ones that do not apply:

```bash
readonly GREETING='Hello'

#######################################
# Print a greeting.
# Globals:
#   GREETING
# Arguments:
#   Name to greet.
# Outputs:
#   Writes the greeting to stdout.
# Returns:
#   0 on success, 1 if no name was given.
#######################################
greet::say() {
  local name=${1-}
  [[ -n "${name}" ]] || return 1
  printf '%s, %s!\n' "${GREETING}" "${name}"
}

greet::say Ada
```

- **Implementation comments** explain what is tricky, non-obvious or important, and why. Do not comment everything (Google guide). Write down your reasoning before you forget it (BashGuide). Delete dead code; version control keeps it.
- **TODO comments** use `# TODO(name): what and why`, with the name of the person who knows most about the problem (Google guide).

### Where the guides disagree

When the sources differ the notes pick one answer and say why. The rows are in the order of the sections above.

| Topic | What the sources say | Decision and reason |
| --- | --- | --- |
| Shebang | Google: `#!/bin/bash`. BashGuide: `#!/usr/bin/env bash` | `#!/usr/bin/env bash`. `/bin/bash` is the system Bash, which is 3.2 on macOS; `env` finds a newer Bash first on `PATH` |
| Indentation | Google: 2 spaces. shfmt default: tabs | 2 spaces. The shfmt manual lists `-i 2 -ci -bn` as the Google style; `.editorconfig` carries it |
| Spaces in `(( ))` | Google writes `(( i += 3 ))`. shfmt writes `((i += 3))` | The shfmt output. A formatter must have one answer and shfmt cannot keep the spaces |
| `function` keyword | Google: optional, but be consistent. BashPitfalls 25: do not combine `function` with `()`; write `foo() { ... }` | `name() {`. It works in every shell, and no tool rewrites it |
| Variable braces | Google: `"${var}"`, bare for specials. BashGuide examples: `"$var"` | Google's rule. One rule, and ShellCheck can enforce it |
| `echo` and `printf` | Google's own `err()` uses `echo`. POSIX Issue 8: new applications should use `printf`, and `echo` is implementation-defined for a first operand such as `-n` or for a backslash | `printf '%s\n' "${x}"` for any variable data; `echo` only for fixed text without a backslash or a leading `-`. `x='-n'; echo "$x"` prints nothing (checked) |
| Numeric tests | Google: `(( ))`. BashGuide: `[ "$x" -gt 0 ]` for external data, because `[[ ]]` and `(( ))` evaluate operands as arithmetic | `(( ))` after validating external data. `(( x > 0 ))` ran a command hidden in `x='a[$(cmd)]'` on every tested version ([security](10-security.md#untrusted-numbers)) |
| `set -e`, `-u`, `pipefail` | Google: set options with `set`, "minimal". BashFAQ/105 and BashPitfalls 60: do not rely on them | A safety net with rules ([error handling](07-error-handling-and-safety.md#strict-mode)) |
| `for arg in "$@"` | Google: always write `in "$@"`. BashPitfalls 24: bare `for arg` is the same | Write it. Explicit is easier to read |
| `==` in `[[ ]]` | Google: `==`. BashGuide examples: `=` | `==`, because `=` looks like an assignment. Quote the right side unless a pattern is meant |
| Regular expression | Google: literal, unquoted. BashPitfalls 35: put it in a variable | A variable for anything but a trivial pattern: `re='^[0-9]+$'; [[ "${x}" =~ ${re} ]]`. A quoted pattern is matched as a string (checked) |
| Option parsing | Google's example: `getopts`. BashFAQ/035: only a manual loop handles long options. clig.dev: give every flag a long name | A manual `while`/`case` loop ([scripts](08-scripts-and-command-line.md#options-and-arguments)) |

## Sources and raw notes

Pages read on 2026-10-30:

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): formatting, variable expansion, naming, comments, function location. The guide is the base of this note.
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): readability, `[[ ]]`, the shebang.
- [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls): entries 22, 24, 25, 34, 35, 44 and 60 cited above.
- [BashFAQ/035](https://mywiki.wooledge.org/BashFAQ/035) and [BashFAQ/105](https://mywiki.wooledge.org/BashFAQ/105).
- [POSIX echo](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/echo.html) (Issue 8, IEEE Std 1003.1-2024).
- [Command Line Interface Guidelines](https://clig.dev/): environment variable names, long flag names.
- shfmt 3.14.1 and ShellCheck 0.11.0 manuals: the Google style flags, EditorConfig keys, the `require-variable-braces` check.
- Every `bash` block in this note without a `# fragment` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1; the statements marked "checked" were run on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9.
