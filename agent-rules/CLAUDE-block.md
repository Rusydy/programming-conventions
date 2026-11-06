## Programming conventions

Before you write or change code in one of these languages, check that its convention rule is in context. If it is not, read the rule file first:

- Bash (`*.sh`, `*.bash`, `*.bats`, files in `bin/`): `~/.claude/rules/bash.md`
- Go (`*.go`, `go.mod`): `~/.claude/rules/golang.md`
- Kotlin (`*.kt`, `*.kts`, `libs.versions.toml`): `~/.claude/rules/kotlin.md`
- TypeScript (`*.ts`, `*.tsx`, `*.mts`, `*.cts`, `tsconfig.json`): `~/.claude/rules/typescript.md`
- Next.js: follow the bundled docs in `node_modules/next/dist/docs/` when the project has them, and the `nextjs-convention` folder of the programming-conventions repository.

A project's own documented conventions come first. The rules apply where the project is silent. Generated code is exempt.
