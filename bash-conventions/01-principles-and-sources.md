# Bash Principles and Sources of Truth

## Summary

These principles apply to every Bash script and project. They put the conventions of the language and of its standard tools ahead of project-specific configuration, so that any Bash programmer can read the code on the first day. A precedence list settles disagreements between sources. Where the sources disagree on a rule that matters, the notes record a decision with its reason, and the list of decisions near the end says where to change each one.

## Rules

### Principles

1. **Decide whether it is a Bash job.** Bash is for glue: calling programs, wiring pipes, preparing files and environments, with little data manipulation. Past about 100 lines, with non-straightforward control flow, with performance needs, with structured data or with complex text processing, use a structured language ([patterns](12-patterns-and-pitfalls.md#things-that-do-not-belong-in-bash)).
2. **Follow the conventions.** The Bash manual, ShellCheck, shfmt and the Google Shell Style Guide define the baseline. Replace one of them only with a written reason. This is "convention over configuration" applied to Bash ([style](04-naming-comments-and-style.md), [tooling](02-project-setup-and-tooling.md)).
3. **Optimise for the reader.** Choose the clearest form, not the shortest one: consistent names and layout, blank lines between blocks, comments that explain why. The BashGuide calls code that you cannot read a year later unfinished.
4. **Quote every expansion and keep data apart from code.** Variables hold data, functions hold code, arrays hold lists ([quoting](05-quoting-and-expansion.md)).
5. **Fail loudly and check explicitly.** Strict mode is the safety net; every failure you expect gets its own check ([error handling](07-error-handling-and-safety.md)).
6. **Use the shell before external programs.** Parameter expansion, arithmetic, `[[ ]]` and `printf` before `sed`, `cut`, `expr` and `echo` ([quoting](05-quoting-and-expansion.md#use-the-expansions-of-the-shell)).
7. **Declare the Bash version.** Every script states the oldest Bash it supports and checks it at the top ([versions](09-portability-and-bash-versions.md#declaring-the-version)).
8. **Never trust input.** Validate numbers before arithmetic, never use `eval`, and keep secrets out of arguments and traces ([security](10-security.md)).
9. **Behave like a command.** Results on stdout, messages on stderr, `--help`, an honest exit status, and setup scripts that are safe to run twice ([scripts](08-scripts-and-command-line.md)).
10. **Let the tools check the rules.** shfmt formats, ShellCheck lints and bats-core tests, in CI, with plain commands ([tooling](02-project-setup-and-tooling.md#automation), [testing](11-testing.md)).

### Order of precedence

When two sources disagree, the lower number wins.

1. What Bash does: the Bash Reference Manual, POSIX where portability is the question, the Bash NEWS and CHANGES files, and the behaviour of the real shell (the notes were checked by running it).
2. The notes in this folder. They record each conflict between the sources and how it is settled ([style](04-naming-comments-and-style.md#where-the-guides-disagree)).
3. ShellCheck. Its default checks are findings to fix. Adopt an optional check only when a note names it.
4. The Google Shell Style Guide, for style and structure: formatting, naming, comments, functions, `main`, quoting.
5. Greg's Wiki (BashGuide, BashFAQ, BashPitfalls), for correctness advice and pitfalls. Its opinions on style yield to the Google guide.
6. The Command Line Interface Guidelines and the NO_COLOR convention, for the behaviour of scripts as commands.
7. Tool defaults: shfmt and bats-core, where no note says otherwise.

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so that each review stays small, and raise the rest as a separate task.
- **Mechanical changes** (formatter upgrades, a newly enabled ShellCheck check, a change of the minimum Bash version) go in their own commits.
- **Generated code** is exempt, for example the output of a parser generator. The next run overwrites hand edits, so keep it out of the lint run.
- **Repositories owned by others:** follow the conventions that repository documents first.
- **Version baseline:** use the newest stable tools. On 2026-10-30 they were ShellCheck 0.11.0, shfmt 3.14.1 and bats-core 1.14.0, installed through Homebrew. The current Bash is 5.3. New scripts declare a minimum of Bash 4.4 by default; a script that must run on the stock macOS Bash declares 3.2. Scripts that declare Bash 4.4 or newer need a newer Bash than the one macOS ships. Newer Bash was tested in local Docker images (5.1.8, 5.2.15, 5.3.9) without network ([versions](09-portability-and-bash-versions.md)).
- **Examples:** the notes hold 42 `bash` code blocks. 35 are complete: each was checked with ShellCheck 0.11.0 (with the `.shellcheckrc` of the tooling note) and shfmt 3.14.1 (with its `.editorconfig`). 6 start with `# fragment`, because they need code that is not in the block, and were checked with shfmt only. 1 starts with `# wrong`, shows a mistake on purpose and is flagged by ShellCheck. No code line is longer than 80 characters. Of the complete blocks, 30 were also run: on Bash 5.2.15, and on Bash 3.2.57 for comparison. 21 gave identical output on both; the other 9 differ because of the working directory or the temporary path (4 blocks) or because they use a feature that Bash 3.2 lacks, as the notes say (5 blocks). The script in the layout note was run on 5.1.8, 5.2.15 and 5.3.9 with identical output, and stops with its version message on 3.2.57. The script and the bats tests of the testing note passed with bats 1.14.0 on 3.2.57. Behaviour described as "checked" was run on 3.2.57, 5.1.8, 5.2.15 and 5.3.9. No Bash 4.x was available, so statements about 4.0 to 4.4 come from the Bash NEWS and CHANGES files, not from running them.
- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/bash.md](../agent-rules/rules/bash.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. Its `paths` field lists globs for `.sh`, `.bash` and `.bats` files, for `.shellcheckrc` and for files in `bin/`, so Claude Code loads it when it uses Read, Write or Edit on a matching file. The `bin/` globs are broad on purpose, because the layout note keeps executables there without an extension; an extensionless script elsewhere is not matched, so ask Claude to read the rule first. In the other direction, a file in `bin/` whose shebang names another language, for example `#!/usr/bin/env python3`, is matched by these globs, so the digest tells Claude to follow the rule of that language instead. The digest is a manual copy: update it in the same change whenever a note here changes, and bump the sync date in its first paragraph. How path-scoped rules load, their size limit and the working-directory caveat are described in the [Kotlin note](../kotlin-conventions/01-principles-and-sources.md).

### Decisions to review

These choices were made while writing the notes because the sources disagree or leave the choice open. Each can be reversed in the place named.

| Decision | Where to change it |
| --- | --- |
| Strict mode (`set -euo pipefail` and `inherit_errexit`) in every executable | [error handling](07-error-handling-and-safety.md#strict-mode) |
| Default minimum Bash 4.4 (not 3.2), declared and checked in each script | [versions](09-portability-and-bash-versions.md#declaring-the-version), [layout](03-project-layout-and-files.md#structure-of-an-executable) |
| `#!/usr/bin/env bash` instead of the `#!/bin/bash` of the Google guide | [style](04-naming-comments-and-style.md#where-the-guides-disagree) |
| Google style (2 spaces, indented `case`, leading pipes) carried by `.editorconfig`, with shfmt winning on the spaces inside `(( ))` | [tooling](02-project-setup-and-tooling.md#shfmt) |
| Five optional ShellCheck checks adopted, three left out | [tooling](02-project-setup-and-tooling.md#shellcheck) |

### Notes in this folder

| Note | Content |
| --- | --- |
| [02 Project setup and tooling](02-project-setup-and-tooling.md) | ShellCheck and shfmt configuration, versions, CI order |
| [03 Project layout and files](03-project-layout-and-files.md) | Executables and libraries, shebang, the script skeleton, finding files |
| [04 Naming, comments and style](04-naming-comments-and-style.md) | Formatting, names, comments, where the guides disagree |
| [05 Quoting and expansion](05-quoting-and-expansion.md) | Quoting, arrays, parameter expansion, globs, `printf`, arithmetic |
| [06 Variables, functions and control flow](06-variables-functions-and-control-flow.md) | `local`, functions, conditions, loops, arrays |
| [07 Error handling and safety](07-error-handling-and-safety.md) | Strict mode and its holes, exit codes, traps, debugging |
| [08 Scripts and the command line](08-scripts-and-command-line.md) | Streams, help, options, prompts, environment, idempotence |
| [09 Portability and Bash versions](09-portability-and-bash-versions.md) | Version declaration, features by release, the 3.2 subset, GNU and BSD tools |
| [10 Security](10-security.md) | Untrusted input, arithmetic injection, temporary files, secrets |
| [11 Testing](11-testing.md) | bats-core, a script and its test, stubs, which Bash runs the tests |
| [12 Patterns and pitfalls](12-patterns-and-pitfalls.md) | Mistake and replacement table, what does not belong in Bash |

## Sources and raw notes

Pages read on 2026-10-30:

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) (read in full).
- Greg's Wiki: [BashGuide: Practices](https://mywiki.wooledge.org/BashGuide/Practices), [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) (68 entries, the strict-mode entry 60 in full), and the BashFAQ entries [001](https://mywiki.wooledge.org/BashFAQ/001), [028](https://mywiki.wooledge.org/BashFAQ/028), [035](https://mywiki.wooledge.org/BashFAQ/035), [048](https://mywiki.wooledge.org/BashFAQ/048), [050](https://mywiki.wooledge.org/BashFAQ/050), [054](https://mywiki.wooledge.org/BashFAQ/054), [062](https://mywiki.wooledge.org/BashFAQ/062), [083](https://mywiki.wooledge.org/BashFAQ/083), [105](https://mywiki.wooledge.org/BashFAQ/105) and [112](https://mywiki.wooledge.org/BashFAQ/112).
- Bash Reference Manual: [The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html), [The Shopt Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html), [Exit Status](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html), the entries for `trap`, `getopts`, `exit`, `return` and `shift` in [Bourne Shell Builtins](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html), for `printf`, `read`, `mapfile`, `local` and `command` in [Bash Builtins](https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html), and for `BASH_SOURCE`, `FUNCNAME`, `PIPESTATUS`, `BASH_XTRACEFD` and `PS4` in [Bash Variables](https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html).
- Bash release history: [NEWS](https://tiswww.case.edu/php/chet/bash/NEWS) (3.0 to 5.3), [CHANGES](https://tiswww.case.edu/php/chet/bash/CHANGES) (searched for the `set -u` rules), the [maintainer's page](https://tiswww.case.edu/php/chet/bash/bashtop.html) (current release 5.3, Apple's Bash 3.2, versions in distributions) and the [GNU Bash page](https://www.gnu.org/software/bash/).
- [POSIX echo](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/echo.html) (Issue 8), [Command Line Interface Guidelines](https://clig.dev/) and [NO_COLOR](https://no-color.org/).
- Manuals: ShellCheck 0.11.0 (`man shellcheck`, `shellcheck --list-optional`), shfmt 3.14.1 (`man shfmt`) and bats-core 1.14.0 (`man bats`, `man 7 bats`).
- Version checks: `/bin/bash --version` (3.2.57 on macOS), `zsh --version` (5.9), and `brew info` for the tools and for Bash (5.3.20).
- Behaviour checks used Bash 3.2.57 (macOS) and the local Docker images `mysql:8.0` (5.1.8, Oracle Linux), `node:24-slim` (5.2.15, Debian 12) and `postgres:17-alpine` (5.3.9, Alpine), started without network.
- Each of the other notes lists the pages it was written from.
- The equivalents of this set for other languages: [golang-conventions](../golang-conventions/01-principles-and-sources.md) and [kotlin-conventions](../kotlin-conventions/01-principles-and-sources.md).
