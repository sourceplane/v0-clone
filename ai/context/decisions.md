# v0-clone — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | Upstream as it is now: two Next.js apps over the v0 Platform API, no database and no accounts — so no Supabase, Hyperdrive, Auth.js or Drizzle, though the programme's row for this starter planned them | Upstream dropped its database and accounts (2026-07-30); the port follows the code, not an older shape of it, and requires Cloudflare alone | design.md, IMPLEMENTATION-STATUS (departure 11) |
| 2 | Two Workers, `web` and `preview`, each on its own hostname | The preview's isolation is upstream's security boundary: generated code never runs on the origin that holds the key | design.md, risks VC-B |
| 3 | Related Projects become build-time origins, the sibling Worker's workers.dev URL unless the environment names a custom one | Each Worker's name is known at plan time; a custom domain is one `env:` line | `apps/*/component.yaml`, `apps/web/lib/preview-proxy.ts`, `apps/preview/lib/origins.ts` |
| 4 | `web` waits for `preview` on a merge (enforced on main, advisory on a pull request) | The host's smoke checks that the proxy origin it was built with answers | `apps/web/component.yaml` |
| 5 | Bring-your-own-key is the default; `V0_API_KEY` is an optional Orun secret handed to both Workers as a Worker secret, never a bundle value | A product deploys before its owner has a v0 key, and a shared key is shared with everyone who can reach the Workers | risks VC-A, `tooling/wire/worker-secrets.mjs` |
| 6 | Vercel OIDC is left out | It has no Cloudflare equivalent | IMPLEMENTATION-STATUS |
| 7 | `/api/health` on each app calls no v0 API | The smoke and the deployment record must pass with no key | `apps/*/app/api/health/route.ts` |
| 8 | `V0_API_BASE_URL` points the v0 calls at another origin, unset in a product | The end-to-end test runs both Workers against a stand-in v0 API | `apps/*/lib/v0-fetch.ts`, `testing/lib/fake-v0-api.py` |
| 9 | One landing (`01-product`) then the record (`02-docs`) | The plan, not a landing boundary, orders the preview before the host | `repo-blueprint.yaml` |
| 10 | Two brokered secrets: `workers-deploy` deploys both Workers | No data plane, so nothing else to apply | `blueprint.yaml` |
| 11 | The product's name comes from one seam per app (`lib/site.ts`); upstream's name stays in its credit and in `V0_CLONE_ORIGIN`, upstream's variable | The rename rewrites one literal; the credit and the variable say where the code came from | `tooling/rebrand/rebrand.mjs` |
| 12 | stack-tectonic 0.19.0, not 0.20.0 | 0.20.0's lane-scoped install is refused by Next 16's Turbopack | `intent.yaml` |
| 13 | The console asks for no domain and reads `subdomain` from the Cloudflare connection | Both apps go live on workers.dev; the subdomain belongs to the account | `blueprint.yaml` |
| 14 | Upstream's code is kept as written; the lint rules eslint-config-next 16 added after it are off by name | A port, not a rewrite | `apps/web/eslint.config.mjs` |
