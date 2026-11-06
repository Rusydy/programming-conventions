# Bash Quoting and Expansion

## Summary

Most Bash bugs are expansion bugs. Quote every expansion, keep lists in arrays and not in strings, use the expansions of the shell instead of `sed`, `cut` and `expr` for simple string work, and print data with `printf`. The rules come from the Google guide, the BashGuide and BashPitfalls, and every behaviour claimed below was run on Bash 3.2.57 and on 5.1, 5.2 and 5.3 unless a version is named.

## Rules

### Quote every expansion

- Quote every variable, command substitution and parameter expansion: `"${file}"`, `"$(date)"`, `"$1"`. The shell splits an unquoted result at the characters of `IFS` (space, tab, newline) and then expands `*`, `?` and `[...]` as file name patterns. A value with a space becomes several arguments, and a value with `*` becomes the list of files.
- Leave unquoted only: integers inside `(( ))`, the special parameters `$?`, `$#`, `$$` and `$!`, and a regular expression that is stored in a variable on the right side of `=~`. Never quote a literal integer (`value=32`). Prefer quoting words (`mode='fast'`).
- Use single quotes when nothing should expand and double quotes when something should.
- Inside `[[ ]]` no splitting or globbing happens, but the right side of `==` and `!=` is a pattern unless it is quoted. Quote both sides of a string comparison:

```bash
# wrong
a=foo
b='f*'
[[ "${a}" == ${b} ]] && echo 'matches, because the right side is a pattern'
```

```bash
a=foo
b='f*'
[[ "${a}" == "${b}" ]] || echo 'no match: both sides are compared as strings'
```

- `"$@"` passes the arguments on exactly as they came, and passes nothing when there are none. Unquoted `$@` and `$*` split the arguments again and drop empty ones, and `"$*"` joins them into one string. Use `"$@"`, and `"$*"` only to put the arguments in a message (Google guide, BashPitfalls 24).

### Lists go in arrays

- Keep a list of words (arguments, files) in an array and expand it quoted: `"${array[@]}"`. A string that holds several arguments leads to `eval` or to quotes inside the string, and neither works (BashFAQ/050: variables hold data, functions hold code).

```bash
flags=(--name 'a b' --verbose)
printf '[%s]' "${flags[@]}"
echo
```

- This prints `[--name][a b][--verbose]`: the element with the space stays one argument.
- Fill an array from a command with `mapfile -t` (Bash 4.0), never with `files=( $(command) )`, which splits on whitespace and expands globs (ShellCheck SC2207, BashPitfalls 50). On Bash 3.2 use `IFS=$'\n' read -r -d '' -a lines < <(command) || true`.

```bash
mapfile -t lines < <(printf 'first line\nsecond line\n')
printf '%s items, the first is "%s"\n' "${#lines[@]}" "${lines[0]}"
```

### Use the expansions of the shell

Prefer parameter expansion to `sed`, `cut`, `basename` and `tr` for simple string work: it starts no process and is safe for odd characters (Google guide, BashGuide). With `path=/var/log/app.tar.gz`:

| Task | Expansion | Result |
| --- | --- | --- |
| File name | `${path##*/}` | `app.tar.gz` |
| Directory | `${path%/*}` | `/var/log` |
| Drop a suffix | `${path%.tar.gz}` | `/var/log/app` |
| Replace a suffix | `${path%.gz}.bz2` | `/var/log/app.tar.bz2` |
| Substring (offset 5, length 3) | `${path:5:3}` | `log` |
| Length | `${#path}` | `19` |
| Replace the first match | `${path/log/LOG}` | `/var/LOG/app.tar.gz` |
| Replace all matches | `${path//a/A}` | `/vAr/log/App.tAr.gz` |
| Default when unset or empty | `${name:-world}` | `world` |
| Assign a default | `: "${name:=world}"` | sets `name` |
| Required value | `${name:?name is required}` | message on stderr and exit; the exit status is 1 on Bash 5 and 127 on 3.2.57, so do not depend on the number |
| Lowercase, uppercase (Bash 4.0) | `${name,,}` and `${name^^}` | `hello` and `HELLO` for `HeLLo` |
| Quoted for reuse (Bash 4.4) | `${name@Q}` | `'a b'` for `a b` |

```bash
path=/var/log/app.tar.gz
printf '%s\n' "${path##*/}" "${path%/*}" "${path%.tar.gz}" "${path%.gz}.bz2"
printf '%s\n' "${path:5:3}" "${path/log/LOG}" "${#path}"
name=HeLLo
printf '%s %s\n' "${name,,}" "${name^^}"
```

- Trim whitespace and join an array with expansions only:

```bash
trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "${s}"
}

join_by() {
  local IFS=$1
  shift
  printf '%s' "$*"
}

printf '[%s]\n' "$(trim '   hello world  ')"
join_by , a 'b c' d
echo
```

### Command substitution

- Write `$(command)`, never backticks (SC2006). Nesting needs no escapes (Google guide).
- It removes all trailing newlines: `$(printf 'a\n\n\n')` is `a` (checked). To keep them, add a character inside and strip it outside (BashPitfalls 41).
- `$(<file)` reads a file without `cat`.
- Quote the result: `"$(command)"`. An assignment `v=$(command)` needs no quotes, because assignments do not split.

### Globs and file names

- Expand with `./*`, not `*`, so that a file called `-f` is not read as an option (checked: with `-f` and `x` in the directory `echo *` prints `-f x`). Put `--` before data arguments: `rm -- "${file}"` (Google guide, BashPitfalls 3).
- A glob without a match stays as written: `*.txt` stays `*.txt` (checked). Turn on `nullglob` around the expansion to get an empty list, or `failglob` to stop with an error ("no match: *.txt", checked):

```bash
shopt -s nullglob
files=(./*.txt)
shopt -u nullglob
if ((${#files[@]} == 0)); then
  echo 'no .txt files here' >&2
fi
```

- Never parse `ls` (BashGuide, SC2045, SC2010): names can hold newlines, and the format differs between systems. Use a glob, or `find -print0` with a loop that reads NUL-separated names (a name with a newline works; checked):

```bash
while IFS= read -r -d '' file; do
  printf 'found: %s\n' "${file}"
done < <(find . -maxdepth 1 -type f -print0)
```

- With external programs use `find -print0 | xargs -0` (BashPitfalls 56). `dotglob` (hidden files), `extglob` and `globstar` (Bash 4.0) are off until you turn them on.

### Printing

- Print data with `printf '%s\n' "${value}"`. `echo` takes its first argument as an option when it looks like one: `x='-n'; echo "$x"` prints nothing (checked). POSIX leaves `echo` implementation-defined for a first operand such as `-n`, `-e` or `-E` and for operands with a backslash, and tells new applications to use `printf`. `echo` stays fine for a fixed literal without a backslash or a leading dash.
- The format string is a constant. `printf "$text"` treats `%` and `\` in the data as format: `x='100%d done'; printf "$x\n"` printed `1000 done` (checked, BashPitfalls 32, ShellCheck SC2059).
- `printf` repeats its format for extra arguments, so `printf '%s\n' "$@"` prints one argument per line. `printf -v name '%05d' 42` assigns without a subshell. `%q` quotes a value for reuse as shell input. `%(%F)T` formats a time (Bash 4.2; the argument `-1` means now).

```bash
printf -v padded '%05d' 42
printf '%s\n' "${padded}"
printf '%(%Y-%m-%d)T\n' -1
```

- Here-documents: quote the delimiter (`<<'EOF'`) when `$` and backticks in the text must stay literal; leave it unquoted when variables should expand. `<<<` feeds a string to standard input.

### Arithmetic

- Use `$((expr))` for a value and `((expr))` for a test or an assignment. Never `let`, `expr` or `$[ ]` (Google guide, BashGuide).
- Arithmetic evaluates strings as expressions, so data from outside must be validated first ([security](10-security.md#untrusted-numbers)).
- A `((expr))` statement returns status 1 when the value is 0 ([control flow](06-variables-functions-and-control-flow.md#conditions)).

## Sources and raw notes

Pages read on 2026-10-30:

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): quoting, arrays, command substitution, wildcards, builtins over external commands, arithmetic.
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): quoting, `ls`, parameter expansion, `expr`.
- [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls): entries 3, 24, 32, 41, 50 and 56.
- [BashFAQ/050](https://mywiki.wooledge.org/BashFAQ/050) (commands in variables) and [BashFAQ/001](https://mywiki.wooledge.org/BashFAQ/001) (reading lines).
- [POSIX echo](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/echo.html).
- Bash Reference Manual: `printf`, `mapfile` and `read` ([Bourne shell builtins](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html), [Bash builtins](https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html)); the Bash NEWS file for the versions that introduced `mapfile` and the case-changing expansions (4.0), `%(fmt)T` (4.2) and `@Q` (4.4).
- Every `bash` block without a `# fragment` or `# wrong` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1; the behaviours marked "checked" were run on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9, and the features of 4.0 and newer failed on 3.2.57 as the version table in the portability note shows.
