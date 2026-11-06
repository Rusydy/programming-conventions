# Bash Project Setup and Tooling

## Summary

Every Bash project uses the same three tools in the same order: shfmt formats, ShellCheck lints and bats-core tests. Two small files in the project root (`.editorconfig` and `.shellcheckrc`) configure them, so CI runs plain commands without flags. The files turn the defaults of the tools into the Google Shell Style Guide plus the ShellCheck checks that the other notes rely on. Everything else stays at the defaults of the tools.

## Rules

### Tools and versions

- Install the three tools from one package manager, and print their versions at the start of CI so that a failing run shows what ran. On 2026-10-30 the newest stable releases were ShellCheck 0.11.0, shfmt 3.14.1 and bats-core 1.14.0 (the Homebrew formulae).

```bash
brew install shellcheck shfmt bats-core
```

- Do not add `bash -n`, `checkbashisms` or a second linter. The shfmt manual presents shfmt as a more exhaustive replacement for `bash -n`, because it parses the whole script statically, and ShellCheck parses it again. `checkbashisms` finds Bash-only syntax in `sh` scripts, and these notes write Bash on purpose ([portability](09-portability-and-bash-versions.md)).

### ShellCheck

- Run ShellCheck on every executable, library and `.bats` file, large or small. The Google guide recommends it for all scripts. Treat any finding as a failure: ShellCheck exits with 1 when it reports an issue.
- ShellCheck reads `.shellcheckrc` (or `shellcheckrc`) from the directory of the checked script and from every parent directory. If none exists it falls back to `~/.shellcheckrc` and then to `$XDG_CONFIG_HOME/shellcheckrc`. Commit this file in the project root:

```ini
# Every file in the project is Bash. Libraries have no shebang, so say so here.
shell=bash

# Follow `source` statements relative to the checked script.
source-path=SCRIPTDIR
external-sources=true

# Optional checks adopted by these notes (see the table below).
enable=require-variable-braces
enable=require-double-brackets
enable=avoid-nullary-conditions
enable=deprecate-which
enable=useless-use-of-cat
```

| Optional check | Code | Why the notes adopt it |
| --- | --- | --- |
| `require-variable-braces` | SC2250 | Brace named variables: `"${name}"`. It leaves `$1`, `$@`, `$#`, `$?`, `$0` and `$$` alone, which is the rule of the Google guide ([style](04-naming-comments-and-style.md#variable-expansion)) |
| `require-double-brackets` | SC2292 | Use `[[ ]]` in Bash ([control flow](06-variables-functions-and-control-flow.md#conditions)). `.bats` files are the exception ([testing](11-testing.md#a-script-and-its-test)) |
| `avoid-nullary-conditions` | SC2244 | Write `[[ -n "${x}" ]]`, not `[[ "${x}" ]]` |
| `deprecate-which` | SC2230 | Use `command -v` |
| `useless-use-of-cat` | SC2002 | `grep x file`, not `cat file \| grep x` |

- Three more optional checks are left out on purpose. `check-set-e-suppressed` (SC2310, SC2311) and `check-extra-masked-returns` (SC2312) show where strict mode has holes ([error handling](07-error-handling-and-safety.md#where-strict-mode-does-nothing-or-surprises)), but they also report every helper function called in an `if` and every `done < <(find ...)` loop, which is ordinary Bash (checked). Run them as an occasional audit: `shellcheck -o check-set-e-suppressed,check-extra-masked-returns bin/*`. `check-unassigned-uppercase` reports environment variables and the variables that bats sets, such as `BATS_TEST_DIRNAME`.
- Fix a finding instead of disabling it. When a disable is justified, put the directive on the line above the one command it concerns, name the code, and give the reason on the same line:

```bash
# fragment
# shellcheck disable=SC2034 # read by the script that sources this file
readonly LIB_VERSION='1.2'
```

- Give ShellCheck a `# shellcheck source=<path>` directive above every `source` whose path is computed ([layout](03-project-layout-and-files.md#finding-files-next-to-the-script)).
- ShellCheck does not report `eval`, the `function` keyword, `echo "${variable}"`, `((i++))` under `set -e`, `[ "$a" == "$b" ]` in Bash, or lines over 80 characters (checked with ShellCheck 0.11.0). The other notes cover these rules; review catches them.

### shfmt

- shfmt formats from `.editorconfig`. Its manual lists `shfmt -i 2 -ci -bn` as flags that closely resemble the Google style, and the four EditorConfig keys below are the same three flags plus the indent style. Commit this file in the project root:

```ini
root = true

[*]
insert_final_newline = true

# Google Shell Style Guide: 2 spaces, indented case, pipes at the line start.
[*.{sh,bash,bats}]
indent_style = space
indent_size = 2
switch_case_indent = true
binary_next_line = true

# shfmt only: scripts without an extension, found by their shebang.
[[shell]]
indent_style = space
indent_size = 2
switch_case_indent = true
binary_next_line = true
```

- The glob section covers files with an extension and tells other editors the style. `[[shell]]` is an extension of shfmt, outside the EditorConfig specification according to its manual, and it is needed for executables without an extension (`bin/greet`): with only the glob section shfmt formatted such a file with tabs. Both sections are tested with shfmt 3.14.1.
- shfmt ignores `.editorconfig` as soon as any formatting flag appears on the command line. CI therefore runs plain `shfmt -d .`.
- shfmt detects files by extension and by shebang. `shfmt -l .` lists files that need formatting, `shfmt -w .` rewrites them, `shfmt -d .` prints a diff and exits with 1. `shfmt -f .` lists the shell files it recognises, so ShellCheck can check exactly the same set: `shfmt -f=0 . | xargs -0 shellcheck` (null-separated, safe for any file name).
- shfmt removes the spaces inside arithmetic commands: it writes `((i += 3))` and `$((2 + 2))` where the Google guide writes `(( i += 3 ))`. The formatter wins ([style](04-naming-comments-and-style.md#where-the-guides-disagree)). shfmt does not enforce line length and does not touch the `function` keyword.

### Automation

- Put plain commands in CI. A wrapper script is optional and only repeats them. Run them in this order, locally and in CI:

```bash
shfmt --version
shellcheck --version
bats --version

shfmt -d .
shfmt -f=0 . | xargs -0 shellcheck
bats test/
```

- `shfmt -w .` fixes formatting locally; commit mechanical changes (a formatter upgrade, a newly enabled optional check) separately from behaviour changes.
- Tests run with bats-core ([testing](11-testing.md)). A project without tests still runs the first two commands.

## Sources and raw notes

Pages and manuals read on 2026-10-30:

- ShellCheck 0.11.0 manual (`man shellcheck`): options, directives, `.shellcheckrc` lookup, optional checks (`shellcheck --list-optional`), exit codes. The SC codes in the table were taken from the output of ShellCheck 0.11.0 on test files.
- shfmt 3.14.1 manual (`man shfmt`): flags, EditorConfig keys, the `[[shell]]` section, the Google style flags, `-f`, `-d`, and the remark about replacing `bash -n`.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): ShellCheck recommendation and the formatting rules that the EditorConfig file reproduces.
- bats-core 1.14.0 manuals (`man bats`, `man 7 bats`) for the test command.
- Tool versions: `brew info` and `brew list --versions` on 2026-10-30.
- Behaviour of shfmt with the EditorConfig variants, of `shfmt -f=0 | xargs -0 shellcheck` and of ShellCheck on libraries without a shebang was run with the versions above.
