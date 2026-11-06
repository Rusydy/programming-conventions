# Bash Security

## Summary

A shell script runs what its input tells it to run whenever the input reaches the wrong place: `eval`, an arithmetic context, a format string, an unquoted expansion or a command line built as a string. The rules below keep input in data positions: quote everything, validate numbers before arithmetic, never use `eval`, create temporary files with `mktemp`, and keep secrets out of arguments and traces. Scripts never run with SUID or SGID.

## Rules

### Treat input as data

- Arguments, environment variables, file names, file contents and the output of other programs are untrusted until checked. Check input early and fail with a message that says what is wrong and what is valid (clig.dev).
- Quote every expansion ([quoting](05-quoting-and-expansion.md)). ShellCheck reports the misses (SC2086, SC2046).
- End the options with `--` before data arguments, and expand globs as `./*`: a file called `-f` is read as an option otherwise (Google guide, BashPitfalls 3).
- Do not build a command in a string. Run programs from an array of arguments (`"${cmd[@]}"`), and keep code in functions (BashFAQ/050).
- Do not use `eval` (Google guide). It parses its input a second time, so a value that contains shell syntax runs. BashFAQ/048 shows that even the usual excuse, passing a variable name to a function, can be exploited. Use an array for a command, a `case` for a fixed set of values, and `printf -v` for a variable whose name you received, after checking that the name is an identifier:

```bash
set_var() {
  local name=$1 value=$2
  local re='^[A-Za-z_][A-Za-z0-9_]*$'
  [[ "${name}" =~ ${re} ]] || return 1
  printf -v "${name}" '%s' "${value}"
}

greeting=''
set_var greeting hello && echo "${greeting}"
# shellcheck disable=SC2016 # the single quotes are the point of this example
set_var 'x[$(echo PWNED >&2)]' v || echo 'rejected'
```

The second call shows the rejection: the name is not an identifier, so nothing is assigned and nothing runs (checked).

### Untrusted numbers

- Arithmetic evaluates strings as expressions. `(( x > 0 ))`, `[[ $x -gt 0 ]]`, `$(( ))`, `let`, `declare -i` and array subscripts all do it, and a value such as `a[$(command)]` runs the command. With `x='a[$(echo PWNED >&2)]'`, both `(( x > 0 ))` and `[[ $x -gt 0 ]]` ran the command on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9 (checked), while `[ "$x" -gt 0 ]` refused with "integer expression expected". BashPitfalls 46 shows the same for `$(( ))`, and BashGuide warns about `[[ ]]`.
- Validate a number from outside before any arithmetic. Test with a glob and not with `[0-9]` or `[[:digit:]]`, which can match more than the ten digits in some locales (BashFAQ/054):

```bash
is_uint() {
  [[ -n "$1" && "$1" != *[!0123456789]* ]]
}

# shellcheck disable=SC2016 # the single quotes are the point of this example
untrusted='a[$(echo PWNED >&2)]'
if is_uint "${untrusted}"; then
  echo 'numeric'
else
  echo 'rejected: not a number'
fi
```

- A number with a leading zero is octal in arithmetic. Force base 10 with `$((10#${n}))` for numbers without a sign (BashPitfalls 59).
- Do not use text from outside as a key or an index in `(( ))` or `[[ -v array[$key] ]]` (BashPitfalls 45, 61 and 62).

### Temporary files and permissions

- Create temporary files and directories with `mktemp`, never with a fixed or guessable name in `/tmp`: the directory is world-writable, and another user can plant a file or a link there. `mktemp` creates the file atomically (BashFAQ/062).

```bash
umask 077
tmp_file="$(mktemp "${TMPDIR:-/tmp}/secret.XXXXXX")"
trap 'rm -f -- "${tmp_file}"' EXIT
printf 'private data\n' >"${tmp_file}"
```

- `umask 077` makes new files readable by the owner only. Single quotes around the trap command make it expand when the trap runs (ShellCheck SC2064). The cleanup rules are in the error handling note ([cleanup](07-error-handling-and-safety.md#cleanup-with-traps)).
- Keep files that hold secrets at mode 600.

### Secrets

- Do not pass a secret as an argument. The process list shows it to other users: `ps -o args=` printed `bash -c sleep 3; : -- --token=SECRET123` on macOS. Pass secrets on standard input or in a file with mode 600.
- Read a password with `read -r -s`, which does not echo it (clig.dev).
- Tracing prints expanded values. With `set -x` a secret appears in the trace (checked: `+ : hunter2`). Turn tracing off around the code that handles secrets (`set +x`), or send the trace to a file descriptor that is not logged (`BASH_XTRACEFD`).

### Privileges

- SUID and SGID are forbidden on shell scripts: shell has too many security problems to make them safe (Google guide). Use `sudo` for elevated access.
- A redirection happens before the command, in the shell of the caller, so `sudo cmd > /etc/file` writes as you. Use `cmd | sudo tee /etc/file >/dev/null` (BashPitfalls 53).
- Elevate the one command that needs it, not the whole script.

### Passing data to other programs

- The format string of `printf` is a constant. `printf "${text}"` lets `%` and `\` in the data change the output (BashPitfalls 32).
- To send a command line through `sh -c` or `ssh`, quote every argument with `printf '%q'`, which produces text that the shell reads back as the same words (checked on Bash 3.2.57 and 5.x):

```bash
args=(echo "it's a \"test\"")
remote_cmd="$(printf '%q ' "${args[@]}")"
bash -c "${remote_cmd}"
```

- Use `find -print0 | xargs -0` and `read -d ''` for file names, because names may hold spaces, quotes and newlines (BashPitfalls 56).

## Sources and raw notes

Pages read on 2026-10-30:

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): SUID and SGID, `eval`, wildcard expansion.
- [BashFAQ/048](https://mywiki.wooledge.org/BashFAQ/048) (eval), [BashFAQ/054](https://mywiki.wooledge.org/BashFAQ/054) (valid numbers), [BashFAQ/062](https://mywiki.wooledge.org/BashFAQ/062) (secure temporary files), [BashFAQ/050](https://mywiki.wooledge.org/BashFAQ/050).
- [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls): entries 3, 32, 45, 46, 53, 56, 59, 61 and 62.
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): the code execution risk of `[[ $x -gt 0 ]]` with external data.
- [Command Line Interface Guidelines](https://clig.dev/): validate input, hide passwords.
- Checks run on 2026-10-30: the injection behaviour of `(( ))`, `[[ ]]` and `[ ]` on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9; `ps` on macOS 26; `set -x` and `printf %q`. Every `bash` block without a `# fragment` first line was checked with ShellCheck 0.11.0 and shfmt 3.14.1.
