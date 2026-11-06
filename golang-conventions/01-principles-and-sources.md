# Go Principles and Sources of Truth

## Summary

These principles apply to every Go project. They put the conventions of the language and its toolchain ahead of project-specific configuration, so that any Go developer can read the code on the first day. A precedence list settles disagreements between sources.

## Rules

### Principles

1. **Follow the toolchain.** `gofmt`, `go vet`, `go test`, `go mod` and `go doc` define the baseline. Replace one of them only with a written reason. This is "convention over configuration" applied to Go.
2. **Optimise for the reader.** Choose the clearest form, not the shortest or the cleverest. The Google Go Style Guide ranks clarity first, then simplicity, concision, maintainability and consistency.
3. **Prefer the standard library.** Add a dependency only when it removes real complexity, and state the reason in the pull request.
4. **Wait for a second use case.** Do not add interfaces, generics, options or packages "just in case".
5. **Make the zero value useful.** `var x T` should work without a constructor wherever that is reasonable.
6. **Treat errors as values.** Check every error, add context, and handle each one once ([error handling](08-error-handling.md)).
7. **Own every goroutine.** Each goroutine has an owner, a stop condition and a context ([concurrency and context](09-concurrency-and-context.md)).
8. **Document for the caller.** Doc comments describe behaviour; other comments explain why ([naming, comments and style](05-naming-comments-and-style.md)).
9. **Name for the call site.** `package.Name` should read as a phrase.
10. **Keep state out of package scope.** Pass dependencies explicitly ([package and API design](06-package-and-api-design.md)).

### Order of precedence

When two sources disagree, the lower number wins.

1. The Go language specification, the documented behaviour of the standard library, and what `gofmt` and `go vet` accept.
2. The notes in this folder, including the recorded personal override ([named parameters and results](02-named-parameters-and-results.md)).
3. The Go team's guidance: Go Code Review Comments, Go Test Comments, Go Doc Comments, Organizing a Go module and, for core idioms, Effective Go. Effective Go says itself that it is not actively updated and does not cover generics, modules or newer libraries.
4. The Google Go Style Guide.
5. The Uber Go Style Guide. Adopt one of its rules only when a note in this folder names it, because some Uber rules fit Uber's codebase rather than Go in general.

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so each review stays small, and raise the rest as a separate task. The Google guide takes the same position on local style that disagrees with the guide.
- **Mechanical changes** (`gofmt`, `go fix`, dependency bumps) go in their own commits.
- **Generated code** is exempt, for example protobuf output, mocks and `stringer` files. The next generation overwrites hand edits.
- **Shared and team repositories:** these notes apply to every Go repository you write in, not only your own. When a repository documents its own conventions, follow those first, and apply these notes to the code you write where the repository is silent.
- **Version baseline:** start new projects on the latest stable Go (Go 1.27, released 2026-08-19). Go supports the two newest major releases, so Go 1.26 stays supported until Go 1.28 ships. Set the `go` directive in `go.mod` to the oldest release you test. [Modern Go by release](12-modern-go-by-release.md) lists what each release adds.
- **Agent rule:** a condensed digest of these notes is in [agent-rules/rules/golang.md](../agent-rules/rules/golang.md). Install it as a user-level Claude Code rule, as [agent-rules](../agent-rules/README.md) describes. The digest is a manual copy, so update it in the same change whenever a note here changes.
- **Loading the digest:** keep the `paths` field in the rule, so that Go rules stay out of sessions that never touch Go. Claude Code loads a path-scoped rule when it reads, writes or edits a matching file, or reads one with a command such as `cat`. A user-level rule matches its patterns against the session's primary working directory, so start the session inside the Go repository. A brand-new repository has no Go file yet, so the digest is not in context for the first one: tell the agent to read `~/.claude/rules/golang.md` before it writes that file.

## Sources and raw notes

Pages read on 2026-10-21:

- [Organizing a Go module](https://go.dev/doc/modules/layout)
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Test Comments](https://go.dev/wiki/TestComments)
- [Go Doc Comments](https://go.dev/doc/comment)
- [Effective Go](https://go.dev/doc/effective_go) (banner: written for the 2009 release, not actively updated)
- [Google Go Style Guide](https://google.github.io/styleguide/go/), with [Decisions](https://google.github.io/styleguide/go/decisions) and [Best Practices](https://google.github.io/styleguide/go/best-practices)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)
- [Go release history](https://go.dev/doc/devel/release) (Go 1.27.0 released 2026-08-19, Go 1.26.0 released 2026-02-10, support policy)
- [Go Proverbs](https://go-proverbs.github.io/)
- Claude Code documentation, [How Claude remembers your project](https://code.claude.com/docs/en/memory), read on 2026-10-26: path-specific rules, and user-level rules whose patterns are relative to the session's primary working directory.
