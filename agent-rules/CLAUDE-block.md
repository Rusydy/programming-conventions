## Programming conventions

Before you write or change code in one of these languages, or the infrastructure files below, check that its convention rule is in context. If it is not, read the rule file first:

- Bash (`*.sh`, `*.bash`, `*.bats`, files in `bin/`): `~/.claude/rules/bash.md`
- Go (`*.go`, `go.mod`): `~/.claude/rules/golang.md`
- Kotlin (`*.kt`, `*.kts`, `libs.versions.toml`): `~/.claude/rules/kotlin.md`
- Kotlin Multiplatform (a module with a `commonMain` source set or the `org.jetbrains.kotlin.multiplatform` plugin, and its Gradle build files): `~/.claude/rules/kmp.md`, together with `kotlin.md`
- Python (`*.py`, `*.pyi`, `pyproject.toml`): `~/.claude/rules/python.md`
- TypeScript (`*.ts`, `*.tsx`, `*.mts`, `*.cts`, `tsconfig.json`): `~/.claude/rules/typescript.md`
- Next.js: follow the bundled docs in `node_modules/next/dist/docs/` when the project has them, and the `nextjs-conventions` folder of the programming-conventions repository.
- Infrastructure (Dockerfiles, Compose files, nginx and CI configuration, systemd units, SSH, fail2ban and Docker daemon settings, runbooks, deploy and backup scripts): `~/.claude/rules/infra.md`, together with `bash.md` for scripts

A project's own documented conventions come first. The rules apply where the project is silent. Generated code is exempt.
