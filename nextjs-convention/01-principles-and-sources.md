# Next.js Principles and Sources of Truth

## Summary

These principles apply to every Next.js project. They put the conventions of the framework ahead of project-specific configuration, so that any Next.js developer can read the code on the first day. A precedence list settles disagreements between sources, and a version policy says which release a project runs.

## Rules

### Principles

1. **Follow the framework's defaults.** Start from `create-next-app` and the official docs. File conventions, `next/*` components and the Metadata API come first. Replace a default only with a written reason. This is "convention over configuration" applied to Next.js.
2. **Let the file system route.** Folders define URLs. Special files (`page`, `layout`, `loading`, `error`, `not-found`, `route`) define behaviour ([layout and routing](03-project-layout-and-routing.md)).
3. **Render on the server first.** Every component is a Server Component until it needs state, effects, event handlers or browser APIs. Put `'use client'` on the leaf that needs it ([Server and Client Components](04-server-and-client-components.md)).
4. **Fetch on the server, where the data is used.** Do not load your own site's content from the browser on first render ([data fetching and caching](05-data-fetching-and-caching.md)).
5. **Cache on purpose.** Nothing is cached by accident. Opt in per request with `fetch` options, and tag the data that you will revalidate ([caching](05-data-fetching-and-caching.md#caching-and-revalidation)).
6. **Treat every Server Function as a public endpoint.** Authenticate, authorise and validate inside each one ([mutations and forms](06-mutations-and-forms.md), [security](10-security.md)).
7. **Use the built-in components.** `next/link`, `next/image`, `next/font`, `next/script` and the Metadata API replace raw `<a>`, `<img>`, font links, `<script>` and `<head>` ([styling, images, fonts and scripts](09-styling-images-fonts-and-scripts.md)).
8. **Keep configuration small.** Each non-default option in `next.config.ts` carries a comment that says why.
9. **Stay on a supported release.** Apply patch releases promptly, because security fixes ship every month ([version policy](#version-policy)).
10. **Let tools check the work.** Strict TypeScript, generated route types, ESLint and `next build` run in CI ([testing and quality gates](11-testing-and-quality-gates.md)).

### Order of precedence

When two sources disagree, the lower number wins.

1. What the installed Next.js, React and TypeScript versions accept, and the Next.js documentation for that version. Since Next.js 16.2 the docs are bundled in `node_modules/next/dist/docs/`.
2. The notes in this folder, including recorded decisions.
3. Next.js release posts and upgrade guides, for deprecations and direction.
4. React documentation, where Next.js defers to React (Server Components, `use`, `useActionState`).
5. The documentation of other libraries, only where a note names the library.

### Applying the notes

- **New code** follows every note in this folder.
- **Existing code:** apply the notes to the lines you write or change. Leave untouched code alone unless someone asks for a clean-up, so each review stays small, and raise the rest as a separate task.
- **Mechanical changes** (codemods, formatter runs, dependency bumps) go in their own commits.
- **Generated files** are exempt and are never edited by hand: `next-env.d.ts`, `.next/` and the route types that `next typegen` writes.
- **Repositories owned by others:** follow the conventions that repository documents first.

### Version policy

- **Run the latest Active LTS.** New and existing production projects run it. On 2026-10-26 that is Next.js 16.4, with 16.4.3 as the latest patch (released on 2026-10-23). The last security release is 16.4.1 (2026-10-14); 16.4.2 and 16.4.3 carry bug fixes only. A project stays on Maintenance LTS only while a scheduled upgrade is in progress, and never after the policy window closes.
- **Know the support window.** The support policy keeps 16.x in Active LTS and 15.x in Maintenance LTS. A major version stays in Maintenance LTS for two years after its initial release, and 15.0 shipped on 2024-10-21. By that wording the 15.x window closed on 2026-10-21, although the policy page still listed 15.x as supported on 2026-10-26. Treat 15.x as ending and plan the move to 16.x.
- **Patch promptly.** Since July 2026 the Next.js team publishes a security release about once a month, announced in advance on the blog, and ships out-of-band patches for urgent issues. Check the blog every month and update the lock file to the patched release within the deadlines in [patching](10-security.md#patching). From 16.4, `experimental.agentUpgrade` (default `'security'`) prints upgrade reminders in `next dev` and `next build`.
- **Upgrade with the tools.** Run `npx next upgrade` in its own pull request ([upgrading](02-project-setup-and-tooling.md#upgrading), [modern Next.js by release](13-modern-nextjs-by-release.md)).
- **Keep Cache Components off on 16.x.** They conflict with the nonce-based CSP that these projects use, and `use cache` had one Critical and two Medium advisories in September and October 2026. They become the default in Next.js 17, and that upgrade follows its upgrade guide ([caching](05-data-fetching-and-caching.md#cache-components-not-adopted-on-16x)).

### Working with coding agents

- Next.js 16.2 and later bundle documentation that matches the installed version in `node_modules/next/dist/docs/`. `create-next-app` writes an `AGENTS.md` that points agents at it. From 16.3, `next dev` maintains that managed block when it detects a coding agent.
- Tell agents to read the matching page there before they write Next.js code, because training data often predates the installed version. For releases before 16.2, run `npx @next/codemod@canary agents-md`.
- Commit the managed `AGENTS.md` block with your work. Otherwise `next dev` recreates it as an uncommitted change.
- No separate digest of these notes exists. The bundled docs and the managed `AGENTS.md` block already cover the framework, and a manual copy would drift. A project whose agents must follow these notes names this folder in its own `AGENTS.md`.

## Sources and raw notes

Pages read on 2026-10-26:

- [Next.js blog index](https://nextjs.org/blog), including [Next.js 16.4](https://nextjs.org/blog/next-16-4) (published 2026-10-06).
- [Support policy](https://nextjs.org/support-policy): 16.x Active LTS (released 2025-10-21), 15.x Maintenance LTS (released 2024-10-21), 14.x and older unsupported; "two years following the initial release" for Maintenance LTS.
- [Next.js Security Release and Our Next Patch Release](https://nextjs.org/blog/next-security-release-program) (2026-07-13): monthly pre-announced releases plus ad-hoc patches.
- [Security update of 2026-10-14](https://nextjs.org/blog/nextjs-security-update-october-14-2026): v16.4.1 (Active LTS) and v15.5.28 (Maintenance LTS).
- GitHub releases [v16.4.2](https://github.com/vercel/next.js/releases/tag/v16.4.2) (2026-10-15) and [v16.4.3](https://github.com/vercel/next.js/releases/tag/v16.4.3) (2026-10-23): bug-fix backports with no advisories. The npm `latest` tag of `next` was 16.4.3 on 2026-10-26.
- [Installation](https://nextjs.org/docs/app/getting-started/installation) and [How Next.js supports AI coding agents](https://nextjs.org/docs/app/guides/ai-agents).
