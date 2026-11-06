# Bash Patterns and Pitfalls

## Summary

This note is the quick lookup: the common mistakes with the form that replaces each one, the ShellCheck code that finds it, the entry of BashPitfalls that explains it, and the list of jobs that do not belong in Bash. The wrong forms were run through ShellCheck 0.11.0, and the codes in the table are what it printed; the right forms were run through it too and lint clean.

## Rules

### Mistakes and their replacements

| Wrong | Right | ShellCheck | BashPitfalls |
| --- | --- | --- | --- |
| `for f in $(ls *.mp3)` | `for f in ./*.mp3` | SC2045 | 1 |
| `cp $file $target` | `cp -- "${file}" "${target}"` | SC2086 | 2, 3 |
| `cd $(dirname "$f")` | `cd -- "$(dirname -- "${f}")" \|\| return` | SC2046, SC2164 | 5 |
| `[ $foo = "bar" ]` | `[[ "${foo}" == 'bar' ]]` | SC2086 | 4 |
| `[ -n $foo ]` | `[[ -n "${foo}" ]]` | SC2070 | 36 |
| `` echo `date` `` | `date`, or `now="$(date)"` when the value is needed | SC2006, SC2005 | |
| `local v=$(cmd)` | `local v` and then `v=$(cmd)` | SC2155 | 27 |
| `for a in $*` | `for a in "$@"` | SC2048 | 24 |
| `a && b \|\| c` | `if a; then b; else c; fi` | SC2015, but not when `a` is a `[[ ]]` test | 22 |
| `printf "$fmt"` | `printf '%s\n' "${fmt}"` | SC2059 | 32 |
| `hosts=( $(cmd) )` | `mapfile -t hosts < <(cmd)` | SC2207 | 50 |
| `read line` | `read -r line` | SC2162 | |
| `cmd; if [ $? -eq 0 ]` | `if cmd; then` | SC2181 | 44 |
| `[[ $a = $b ]]` | `[[ "${a}" == "${b}" ]]` | SC2053 | 34 |
| `[[ $s =~ 'a.c' ]]` | `re='a.c'; [[ "${s}" =~ ${re} ]]` | SC2076 | 35 |
| `rm -rf $dir/*` | `rm -rf -- "${dir:?}/"*` | SC2115 | |
| `trap "rm $tmp" EXIT` | `trap 'rm -- "${tmp}"' EXIT` | SC2064 | |
| `ls \| grep foo` | `for f in ./*foo*` or `find` | SC2010 | |
| `cat file \| grep x` | `grep x file` | SC2002 (optional) | |
| `which ls` | `command -v ls` | SC2230 (optional) | |
| `` for i in `seq 1 3` `` | `for ((i = 1; i <= 3; i++))` | SC2006 | |
| `[ "$a" = 1 -a "$b" = 2 ]` | `[[ "${a}" == 1 && "${b}" == 2 ]]` | SC2166 | |
| `tr [a-z] [A-Z]` | `tr '[:lower:]' '[:upper:]'` | SC2060 | 30 |
| `cmd 2>&1 >>log` | `cmd >>log 2>&1` | SC2069 | 43 |
| `sudo cmd > /etc/file` | `cmd \| sudo tee /etc/file >/dev/null` | SC2024 | 53 |
| `find ... \| xargs cmd` | `find ... -print0 \| xargs -0 cmd` | SC2038 | 56 |
| `done <<< "$(foo)"` | `done < <(foo)` | not reported | 63 |
| `echo "$x"` | `printf '%s\n' "${x}"` | not reported | 14 |
| `[[ $x -gt 0 ]]` on input from outside | validate first ([security](10-security.md#untrusted-numbers)) | not reported | 46 |
| `((i++))` under `set -e` | `i=$((i + 1))` | not reported | BashFAQ/105 |
| `IFS=, read -ra f <<< "${line}"` drops an empty last field | `IFS=, read -ra f <<< "${line},"` | not reported | 47 |

Points that no tool reports, so review them by eye:

- ShellCheck 0.11.0 reports none of `eval`, the `function` keyword, `echo` with variables, `[ "$a" == "$b" ]` in Bash (with the default checks), or `((i++))` under `set -e` (checked).
- `cmd 2>&1 >>log` sends stderr to the old stdout, which is the terminal, because redirections apply from left to right: the log stayed empty and the error text appeared on screen (checked). `2>&1` goes last.
- `$(<file)` and `$(cmd)` remove trailing newlines, so do not use them to copy data exactly (BashPitfalls 41).
- `IFS=, read -ra f <<< "a,b,"` gave two fields and the version with the extra comma gave three, the last one empty (checked).

### Things that do not belong in Bash

Leave Bash, or at least stop adding to the script, when any of these is true (Google guide, BashGuide):

- The script is longer than about 100 lines, or its control flow is not straightforward. Rewrite it early, because scripts grow, and the rewrite gets harder.
- Performance matters.
- It needs data structures beyond lists and small lookup tables: nested data, records, objects.
- It parses structured text such as JSON, XML or HTML with `grep`, `sed` or `awk`. Use a tool that understands the format (`jq` for JSON) or a language with a parsing library.
- It does complex text processing: `awk`, Perl or Python are better suited.
- Someone other than the author could not maintain it easily. The Google guide asks you to judge complexity by that test.

Bash stays the right choice for the glue: calling other programs, wiring pipes, and setting up files and environments with little data manipulation.

## Sources and raw notes

Pages read on 2026-10-30:

- [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) (68 entries; the numbers above are its numbers) and [BashFAQ/105](https://mywiki.wooledge.org/BashFAQ/105).
- [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices): `ls`, `grep` on file names, `cat`, `seq`, `expr`; choosing the tool.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): when to use shell, wildcards, `eval`, arithmetic.
- ShellCheck 0.11.0: the codes come from its output on the wrong forms. The optional checks in the table are enabled in the `.shellcheckrc` of the tooling note.
- The behaviours (`a && b || c`, `2>&1 >>log`, `read` and empty fields, trailing newlines) were run on Bash 3.2.57, 5.1.8, 5.2.15 and 5.3.9.
