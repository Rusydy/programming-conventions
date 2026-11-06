# Bash Variables, Functions and Control Flow

## Summary

Variables are local unless they must not be, constants are readonly, and a function returns a status and prints its data. Conditions use `[[ ]]` for strings and files, `(( ))` for numbers and `if command` for commands. Loops read lines with `while read`, not from `ls` or `$(cat file)`. Lists live in arrays; anything beyond lists, such as nested data or records, is the signal to leave Bash ([principles](01-principles-and-sources.md#principles)).

## Rules

### Variables

- Declare every variable of a function with `local`, including loop variables (Google guide). Without it the variable is global and can overwrite one of the caller. A local variable is visible to the functions the function calls.
- Declare and assign in two statements when the value comes from a command substitution. `local value="$(cmd)"` hides the failure of `cmd`, because `local` returns its own status (checked: under `set -e` the function carried on after a failing command), and ShellCheck reports SC2155.

```bash
get_year() {
  local year
  year="$(date +%Y)"
  printf '%s\n' "${year}"
}

get_year
```

- Constants are `readonly NAME='value'`, uppercase, at the top of the file. A second assignment is an error (checked). If the value is computed, make it readonly right after computing it.
- Do not return results through global variables. Use stdout or the status. If a global is unavoidable, list it under `Globals:` in the header comment of the function.
- Under `set -u` read optional values with `${var-}` or `${var:-default}`. `"$@"` and `"$*"` are exempt from the check.
- Export only what a child process needs. To set a variable for one command, put it in front: `LC_ALL=C sort file`.

### Functions

- Define a function as `name() {`. Do not use the `function` keyword ([style](04-naming-comments-and-style.md#where-the-guides-disagree)).
- Give the arguments names on the first lines: `local src=$1 dst=$2`. A missing argument stops the script under `set -u`, which is the wanted behaviour.
- A function returns a status and prints its data to stdout; the caller captures it with `$(...)`. Messages for people go to stderr. Do not mix data and messages on stdout.
- Functions end with `return`; only `die` and the top level call `exit`.
- Pass a list by expanding it: `process "${files[@]}"`. Avoid namerefs (`local -n`, Bash 4.3). To return a list, print one item per line and read it with `mapfile -t`.
- Keep a function short enough to read at once, and put the program flow in `main` ([layout](03-project-layout-and-files.md#structure-of-an-executable)).

### Conditions

- Strings and files: `[[ ]]` with quoted operands. Test emptiness with `-z` and `-n`, never with filler characters (`[[ "${x}X" == "yX" ]]`). Compare with `==`. Quote the right side unless a pattern is meant.
- Numbers: `(( ))`. `[[ 22 > 3 ]]` compares strings and is false (checked), while `((22 > 3))` compares numbers. Validate data from outside first ([security](10-security.md#untrusted-numbers)).
- Commands: `if command; then`. Do not run a command and test `$?` afterwards (SC2181, BashPitfalls 44). Read `$?` only when you need the exact value, and in the very next statement.
- Combine tests inside one `[[ ]]` with `&&`, `||` and `!`. Never `-a` and `-o` (SC2166).
- `A && B || C` is not `if A; then B; else C; fi`: `C` also runs when `B` fails. With `i=0`, `true && ((i++)) || ((i--))` leaves `i` at 0, because `((i++))` returned 1 (checked, BashPitfalls 22). Use `if`.
- `&&` and `||` are fine for a one-line guard: `[[ -r "${file}" ]] || die "cannot read ${file}"`.
- Test several string values with `case`, and finish with a `*)` branch that reports the unexpected value (Google guide).
- A `((...))` statement returns 1 when its value is 0. Under `set -e` the script stops at `((count++))` while `count` is 0 on Bash 4.1 and newer (checked: 3.2.57 carries on). Write `count=$((count + 1))`.
- In `.bats` files write assertions with `[ ]`, not `[[ ]]`: bats runs a test with `set -e`, and before Bash 4.1 a failing `[[ ]]` in the middle of a test does not stop it (checked: such a test passed on 3.2.57) ([testing](11-testing.md#a-script-and-its-test)).

```bash
name=Ada
count=0
count=$((count + 1))
if ((count > 0)) && [[ -n "${name}" ]]; then
  printf '%s counted %s\n' "${name}" "${count}"
fi
```

### Loops

- Loop over an array with `for item in "${items[@]}"` and over the arguments with `for arg in "$@"`. Count with `for ((i = 0; i < n; i++))`, not with `seq` (BashGuide).
- Read a file line by line with `while IFS= read -r line`. `IFS=` keeps leading and trailing whitespace, `-r` keeps backslashes, and `|| [[ -n "${line}" ]]` keeps a last line that has no newline (checked: without it that line is lost; BashFAQ/001).

```bash
file=$(mktemp)
printf 'one\ntwo\nlast without newline' >"${file}"
while IFS= read -r line || [[ -n "${line}" ]]; do
  printf 'line: %s\n' "${line}"
done <"${file}"
rm -f -- "${file}"
```

- Read the output of a command with process substitution, not with a pipe. A pipe runs the loop in a subshell and the variables set in it are lost: the counter stays 0 after a piped loop and is 2 after `done < <(...)` (checked). `shopt -s lastpipe` (Bash 4.2, scripts only) also works but is less obvious (Google guide, BashPitfalls 63).

```bash
n=0
while IFS= read -r _; do
  n=$((n + 1))
done < <(printf 'a\nb\n')
echo "n=${n}"
```

- Do not loop over `$(command)` or `$(<file)`: the output is split at whitespace, not at lines (BashGuide). Do not loop over `ls`.

### Arrays

- Use indexed arrays for lists. Use associative arrays (`declare -A`, Bash 4.0) only for a small lookup table. Do not build nested data or records in Bash; that is the point to switch language (Google guide).
- Initialise with `local -a items=()`, append with `items+=("${value}")`, count with `${#items[@]}`, and expand with `"${items[@]}"`. `"${items[*]}"` joins the items and belongs only in a message.
- Under `set -u` an empty array expands without error on Bash 4.4 and newer, and fails on older versions: on 3.2.57 `"${a[@]}"` stopped with "unbound variable" (checked). The 3.2 form is `${a[@]+"${a[@]}"}` ([versions](09-portability-and-bash-versions.md#the-bash-32-subset)).
- Do not use text from outside as a key or an index in `(( ))`, `[[ -v ]]` or `$(( ))`: the subscript is evaluated and can run a command (BashPitfalls 45, 61 and 62).

### Directories

- Change directory with `cd -- "${dir}" || return` (ShellCheck SC2164). To run a command somewhere else without moving the shell, use a subshell: `( cd -- "${dir}" && make )`.

## Sources and raw notes

Pages read on 2026-10-30:

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): `local`, separate declaration and assignment, constants, function location, `[[ ]]`, strings, arithmetic, pipes to `while`, arrays.
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): `seq`, `for line in $(<file)`, `[[ ]]` against `[ ]`.
- [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls): entries 22, 27, 44, 45, 61, 62 and 63.
- [BashFAQ/001](https://mywiki.wooledge.org/BashFAQ/001): reading lines.
- Bash NEWS file: `declare -A` and `mapfile` (4.0), `lastpipe` (4.2), namerefs (4.3), and CHANGES for the 4.4 change to empty arrays under `set -u`.
- Every `bash` block without a `# fragment` or `# wrong` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1; the behaviours marked "checked" were run on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9.
