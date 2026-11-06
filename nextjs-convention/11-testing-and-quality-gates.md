# Next.js Testing and Quality Gates

- Responsibility: engineering
- Area/system: nextjs
- Keywords: testing, quality gates, typecheck, ESLint, next build, Vitest, Jest, Playwright, Cypress, end-to-end test, unit test, component test, async Server Components, instant helper, smoke test, Lighthouse, Core Web Vitals, useReportWebVitals, bundle analyzer, next experimental-analyze, jsx-a11y, accessibility, .env.test
- Aliases: Next.js testing, tes Next.js, CI Next.js, quality gate Next.js, Playwright Next.js, Vitest Next.js, uji website Next.js, bundle size Next.js
- Status: active
- Last updated: 2026-10-26

Related notes: [principles](01-principles-and-sources.md), [setup and tooling](02-project-setup-and-tooling.md), [Server and Client Components](04-server-and-client-components.md), [data fetching and caching](05-data-fetching-and-caching.md), [security](10-security.md).

## Summary

Every pull request passes the same gates: type check, lint, format check, `next build` and tests. Unit tests cover pure logic and client components. End-to-end tests cover routes and journeys, because async Server Components do not work well in unit tests. Performance checks run against a production build.

## Rules

### Quality gates

- Run `npm run ci` ([automation](02-project-setup-and-tooling.md#automation)) in CI and require it before merge. It runs `next typegen`, `tsc --noEmit`, `eslint`, `prettier --check` and `next build`, and the test commands below join it.
- `next build` is a gate in its own right. It catches missing `<Suspense>` boundaries, bad `metadataBase` values and server-only imports in client code, and it prints the route table ([setup](02-project-setup-and-tooling.md#upgrading)).
- Never turn a gate off to merge. Fix it or record why in the pull request.

### Choosing the test tool

- The Next.js docs describe four tools: Jest and Vitest for unit and component tests, Playwright and Cypress for end-to-end tests. They recommend end-to-end tests over unit tests for `async` Server Components.
- Use Vitest for pure functions (formatters, validators, data-layer mappers) and for client components, and Playwright for routes and user journeys. Jest and Cypress are not used: Vitest has about three times the weekly downloads of Jest, and Playwright about fourteen times those of Cypress.
- Add `"test": "vitest run"` and `"e2e": "playwright test"` to `package.json`, and append `&& npm test && npm run e2e` to the `ci` script.
- Test your own logic and your journeys. Do not test what Next.js already guarantees.
- Keep unit tests beside the code (`*.test.ts`) and end-to-end tests in `e2e/`.
- Commit a `.env.test` for test defaults. Next.js does not load `.env.local` when `NODE_ENV` is `test`, so every machine gets the same values. Use `loadEnvConfig` from `@next/env` in test set-up code.

### Smoke tests for a marketing site

For every public route, an end-to-end test checks that:

- the route answers with status 200 (or the intended redirect);
- the page has one `h1`, a unique `<title>`, a description and a canonical link;
- the first HTML response already contains the main content, which proves that the content does not wait for client-side fetching;
- the main navigation links resolve and the images load;
- each form shows a validation error for bad input and a success message for good input;
- `/robots.txt` and `/sitemap.xml` answer.

### Performance and bundle checks

- Before a release, run `next build` and `next start` to measure in a production-like setting. Run Lighthouse by hand in an incognito window, and pair it with field data, because Lighthouse is a simulation. CI does not run Lighthouse.
- Send Core Web Vitals to analytics with the `useReportWebVitals` hook.
- Since 16.0, `next build` no longer prints `size` and `First Load JS`. Use the Turbopack bundle analyzer (`next experimental-analyze`, from 16.1) to find large modules. Since 16.4 it also shows a route summary and bundle diffs. `@next/bundle-analyzer` serves webpack builds.
- Check the weight of a new dependency before you add it (Import Cost, Bundlephobia).

### Accessibility

- `eslint-config-next` depends on `eslint-plugin-jsx-a11y`, so the lint gate catches the first class of accessibility errors. The production checklist recommends that plugin.
- Give every image an `alt`, every form control a label, and check keyboard navigation by hand on the main journeys.
- No automated accessibility scanner is added. The lint rules and the keyboard check cover the basics: alt text, labels and keyboard access.

## Sources and raw notes

Pages read on 2026-10-26:

- [Testing](https://nextjs.org/docs/app/guides/testing): test types, tools, advice on async Server Components.
- [Production checklist](https://nextjs.org/docs/app/guides/production-checklist): production-like checks, Lighthouse, web vitals, bundle analysis, accessibility linting.
- [Environment variables](https://nextjs.org/docs/app/guides/environment-variables): test environment and load order.
- [Next.js 16.1](https://nextjs.org/blog/next-16-1) (bundle analyzer) and [16.4](https://nextjs.org/blog/next-16-4) (analyzer additions).
- npm weekly downloads on 2026-10-26 (`api.npmjs.org`): `vitest` 83.7 million, `jest` 28.0 million, `@playwright/test` 49.8 million, `cypress` 3.5 million.
- [Upgrading to version 16](https://nextjs.org/docs/app/guides/upgrading/version-16): removal of `size` and `First Load JS` from the build output.
- `eslint-config-next@16.4.1` `package.json` on unpkg: dependencies.
