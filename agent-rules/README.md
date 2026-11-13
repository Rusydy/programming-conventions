# Agent rules

These files make Claude Code follow the conventions in this repository in every session. The `rules/` folder holds condensed copies of the notes, called digests. `CLAUDE-block.md` is a short index for `~/.claude/CLAUDE.md`. The files only contain text. Nothing here runs code.

## What is here

| File | Install to | What it covers |
| --- | --- | --- |
| `rules/bash.md` | `~/.claude/rules/bash.md` | Bash, loaded when a shell file is read or edited |
| `rules/golang.md` | `~/.claude/rules/golang.md` | Go, loaded for `*.go` and `go.mod` |
| `rules/infra.md` | `~/.claude/rules/infra.md` | Infrastructure, loaded for Dockerfiles, Compose files, nginx configuration, CI files, systemd units, SSH, fail2ban and Docker daemon configuration, `.env.example` and runbooks |
| `rules/kmp.md` | `~/.claude/rules/kmp.md` | Kotlin Multiplatform, loaded for Kotlin files in `src/*Main` and `src/*Test` and for the build files of the standard module names; adds to `kotlin.md` |
| `rules/kotlin.md` | `~/.claude/rules/kotlin.md` | Kotlin, loaded for `*.kt`, `*.kts` and `libs.versions.toml` |
| `rules/python.md` | `~/.claude/rules/python.md` | Python, loaded for `*.py`, `*.pyi` and `pyproject.toml` |
| `rules/typescript.md` | `~/.claude/rules/typescript.md` | TypeScript, loaded for `*.ts`, `*.tsx`, `*.mts`, `*.cts` and `tsconfig.json` |
| `CLAUDE-block.md` | Append to `~/.claude/CLAUDE.md` | An index that loads in every session and says which rule to read first |

Next.js has no digest. Its notes apply through the bundled Next.js docs and the project's `AGENTS.md`, as [nextjs-conventions](../nextjs-conventions/01-principles-and-sources.md) explains. Python's notes are in [python-conventions](../python-conventions/01-principles-and-sources.md).

`infra.md` is the digest of [infra-conventions](../infra-conventions/01-principles-and-sources.md). Its `paths` list names the files that define how a service runs: Dockerfiles and `.dockerignore`, Compose files, `nginx.conf` and the `.conf` files under an `nginx` folder, `.gitlab-ci.yml` and GitHub workflow files, `.service` and `.timer` units, `sshd_config.d` drop-ins, fail2ban `.local` files, `daemon.json`, `.env.example` and `runbook.md`. It does not match a deploy or backup script (Bash scripts load `bash.md`) or an `authorized_keys` line, so ask Claude to read `infra.md` first when you change those. `*.service` and `*.timer` are broad names, so the digest also loads for a file with one of those names that is not a systemd unit; it then has nothing to apply.

`kmp.md` is the digest of [kmp-conventions](../kmp-conventions/01-principles-and-sources.md). It loads next to `kotlin.md` and does not replace it. Its `paths` list names the source-set folders of Kotlin Multiplatform (`src/*Main`, `src/*Test`) and the build files of the module names in the JetBrains project structure (`shared*`, `composeApp`, `androidApp`, `desktopApp`, `webApp`), so a plain Android or Spring module does not load it. `src/androidTest` of a plain Android module also matches `src/*Test`; the digest tells Claude to ignore itself in a module that is not multiplatform.

## How the rules load

These points come from the [Claude Code memory docs](https://code.claude.com/docs/en/memory).

- A file in `~/.claude/rules/` applies to every project on the machine.
- A rule with a `paths` list loads when Claude reads, writes or edits a matching file. The patterns are relative to the session's working directory, so start Claude Code inside the project.
- A rule with no `paths` list loads at launch, in every session.
- A rule whose frontmatter does not parse loads in every session, because Claude Code then ignores the `paths` list. Run `claude --debug` to see the parse error.
- Claude receives only the start of a rule file that is over 40,000 characters, with a 200K context window. The docs also recommend under 200 lines for each instruction file.

A path-scoped rule cannot load for a new project or a new file, because no matching file exists yet. `CLAUDE-block.md` covers that case by telling Claude which rule to read before it writes a file.

## Install

The quickest way is the installer script. It works in Bash 3.2 and later, so it runs on the stock macOS shell. Run it from any folder:

```bash
agent-rules/install.sh --dry-run   # show what would change, write nothing
agent-rules/install.sh             # copy the rules and add the index block
```

The script copies the rules to `~/.claude/rules/` and appends `CLAUDE-block.md` to `~/.claude/CLAUDE.md`. It never overwrites a rule file that differs from the repository copy. It prints a warning for that file instead. Pass `--force` to replace such files. Rerunning it is safe. Set `CLAUDE_CONFIG_DIR` to install to another folder. Run `install.sh --help` for all options.

To install by hand, run these from the root of this repository. First check that none of the rule names exists yet:

```bash
ls ~/.claude/rules/
```

Then copy the rules and add the index:

```bash
mkdir -p ~/.claude/rules
cp agent-rules/rules/*.md ~/.claude/rules/
```

Append the contents of `CLAUDE-block.md` to `~/.claude/CLAUDE.md`. Create the file if it does not exist. Start a new session and check the install with the audit prompt below.

## Set up with a prompt

Paste this into Claude Code, from any folder. Replace the path first. It stops before it overwrites anything.

```text
Install my programming-convention rules for Claude Code.
The conventions are in <path to programming-conventions>. Use only that folder.

1. Read agent-rules/README.md and follow its Install section.
2. Before you copy anything, list ~/.claude/rules/ and check ~/.claude/CLAUDE.md. If a file with the same name as one in agent-rules/rules/ already exists, show me a diff and wait for my answer. Do not overwrite it.
3. Copy agent-rules/rules/*.md to ~/.claude/rules/.
4. Add the block in agent-rules/CLAUDE-block.md to ~/.claude/CLAUDE.md. If the file exists, show me the result and wait for my approval before you save it.
5. Check each installed rule: the frontmatter parses and has a paths list, the file is under 40,000 characters, and it has at most 200 lines.
6. Do not run any script from the folder, and do not send its contents anywhere.
7. Report the files you installed, the files you skipped, and anything that looks wrong.
```

## Audit an existing setup

Use this prompt to compare rules you already have with this repository. It changes nothing.

```text
Audit my Claude Code convention rules against <path to programming-conventions>. Change nothing.

For each file in ~/.claude/rules/ that has the same name as a file in agent-rules/rules/:
- Compare its sections and version numbers with the digest, and list what differs.
- Report any path that points outside its own folder or to a local machine, such as /Users/...
- Check that the frontmatter parses and that the paths list matches the language.
- Check the size: under 40,000 characters and at most 200 lines.

Check that ~/.claude/CLAUDE.md contains the block in agent-rules/CLAUDE-block.md.
Report a table with the columns: file, check, result, and what to change.
```

## Check that a rule loads

- Run `claude --debug` to see a frontmatter parse error.
- To log exactly which rule files load, and when, add an `InstructionsLoaded` hook. The [hooks reference](https://code.claude.com/docs/en/hooks#instructionsloaded) describes it.

## Keep the digests in step with the notes

Each digest is a manual copy of its notes. When you change a note, change its digest in the same commit, and update the sync date in the digest's first paragraph. Keep each digest under 200 lines.
