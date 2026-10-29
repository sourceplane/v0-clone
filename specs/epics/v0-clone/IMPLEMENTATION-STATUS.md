# Implementation status — v0-clone

| Milestone | Status | Shipped as |
|---|---|---|
| VC0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/v0-clone/pull/1) |
| VC1 — the apps on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/v0-clone/pull/2) |
| VC2 — ready to instantiate | ✅ Shipped | [#3](https://github.com/sourceplane/v0-clone/pull/3) |
| VC3 — a baseline | ✅ Shipped | [#4](https://github.com/sourceplane/v0-clone/pull/4) |

## Departures from upstream (vercel/v0-sdk `examples/v0-clone` at `024bcaf`)

1. **Two Cloudflare Workers** instead of two Vercel projects: `apps/web` (the host) and `apps/preview` (upstream's `apps/preview-proxy`, renamed for the component), each built by `@opennextjs/cloudflare` and deployed per environment as `<repo>-web-<env>` and `<repo>-preview-<env>`.
2. **Related Projects → build-time origins.** `lib/preview-proxy.ts` and `lib/origins.ts` read `NEXT_PUBLIC_V0_PREVIEW_PROXY_URL` / `NEXT_PUBLIC_V0_CLONE_ORIGIN`, inlined by each component's `buildCommand` from the environment's `V0_PREVIEW_PROXY_URL` / `V0_CLONE_ORIGIN`, else the sibling Worker's workers.dev URL. The validation is upstream's, except that plain HTTP is allowed on loopback (a local `wrangler dev`) rather than everywhere off Vercel. `@vercel/related-projects` is gone.
3. **Vercel OIDC left out.** Both `lib/v0-client.ts` resolve `V0_API_KEY`, then the app's cookie; with neither the call is unauthenticated and refused, and the host opens its key dialog.
4. **`V0_API_BASE_URL`** (`lib/v0-fetch.ts`, unset in a product): the v0 calls go to another origin with the same paths — the stand-in v0 API of the end-to-end test.
5. **A health route per app** (`/api/health`) for the deploy's smoke: no v0 call, the other app's origin, whether a server key is set (never its value).
6. **The web Worker waits for the preview Worker** on a merge (`dependsOn`, enforced on push to main), so the host's smoke can check that the proxy origin it was built with answers.
7. **The cookie and storage keys** no longer carry the example's name (`v0-api-key`, `__Host-v0-preview-api-key`, `v0-settings`), so a product renamed from this baseline keeps upstream's keys' meaning without the baseline's slug in them.
8. **bun → pnpm 10 + Node 22**, the reference's ESLint (eslint-config-next 16; the React Compiler and TypeScript rules that flag upstream's code as written are off by name, in the two files they flag), Next 16.2.4 → 16.3.8 (the reference's OpenNext-tested version), React 19.2.5 → 19.2.7, TypeScript 6 → 5.8 (the reference's). `v0` and `@v0-sdk/react` from npm at 3.0.12 (upstream used the monorepo's workspace copies of the same release).
9. **Tests:** upstream's three bun test files run under vitest in `tests/web` (`mock.module` → `vi.doMock` + a dynamic import, the same un-hoisted semantics), unchanged otherwise; new tests in `tests/web` and `tests/preview` cover the departures above.
10. **Upstream's security model is unchanged** — no accounts, a same-origin seam — and the README re-reads its warning for Cloudflare: leave `V0_API_KEY` unset, or put Cloudflare Access in front of both Workers.
11. **No Supabase, Auth.js or Drizzle — a departure from the programme's row for this starter**, which planned Cloudflare + Supabase (Postgres through Hyperdrive) with Auth.js and Drizzle. Upstream removed its database and its accounts on 2026-07-30 (the example now keeps no store of its own: chats, files and previews are the v0 API's), so there is nothing for Postgres to hold and no sign-in to port. The baseline follows upstream as it is at `024bcaf`: it requires Cloudflare alone, and its one brokered token deploys both Workers. Sign-in, where an owner wants it, goes in the `authorizeProxyRequest` seam.

## Measured

- Worker sizes (`wrangler deploy --dry-run`, gzipped): web 2,173 KiB, preview 1,600 KiB — both under Workers Free's 3 MiB.
- Under `wrangler dev`, against a stand-in v0 API: both serve with no key; the dialog validates a key (401 for a wrong one); the proxy accepts a key only from the host's origin (403 otherwise) and keeps it in its own cookie; a chat's preview is served through the proxy with v0's preview token.

## The baseline (VC3)

- **Shape:** `blueprint.yaml` (the card: `reponame`, `productname`, `githuborg` from the repository and `subdomain` from the Cloudflare connection; `CLOUDFLARE_API_TOKEN` brokered as `workers-deploy` and `CLOUDFLARE_ACCOUNT_ID`; requires GitHub and Cloudflare) and `repo-blueprint.yaml` (21 modules, two phases): `01-product` places, brands and lands the whole product as one pull request, and its convergence deploys each environment's preview origin and then its host app (`web` → `preview`, enforced on main); `02-docs` records the live deployment from probes (both Workers' `/api/health`, both environments) and restores the promotion gate and dev's lanes. Estimated 8 + 1 minutes; no bootstrap has been timed.
- **The name seam** is one `SITE_NAME` per app (`apps/web/lib/site.ts`, `apps/preview/lib/site.ts`), the baseline's placeholder "My App Builder": upstream hard-coded "v0 clone" / "v0 Clone" in the host's title and the proxy's page.
- **The rename** rewrites the slug, both Workers' names, the secret project, the domain placeholder and the subdomain, and leaves upstream's identity alone: its `examples/v0-clone` links and `V0_CLONE_ORIGIN`, the variable upstream named after itself (kept as upstream spells it, so its README and this one agree).
- **Tiers** (Baseline CI and locally): contract (manifest, phases — the origin edge and both builds naming their sibling — coverage, rebrand, retouch, bootstrap-defer), the component docs check, the blueprint read by orun v2.88.0, the leak gate, placement (the offline bootstrap and the product's own plans: preview at level 0, web at level 1 per environment on a merge; neither waits on a pull request; the 02-docs merge plans nothing), and end to end — the landing installed, type-checked, linted and tested (19 + 43); each app's stage lane run in its own staged job tree, the v0 key kept out of the bundle, the sibling origin inlined, both dry runs under 3 MiB; both Workers served under `wrangler dev` against a stand-in v0 API, both deploys' own smokes passing, the key flow host → proxy, a chat's preview served with v0's preview token.
