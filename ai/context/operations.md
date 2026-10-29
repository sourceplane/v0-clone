# v0-clone — operating contract (for humans and agents)

This is the standing guide to how this product is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the product without any
other source.

## What this system is

A v0-style app builder on Cloudflare — a chat over the v0 Platform API that
creates and refines apps, with their previews served from an origin of
their own — expressed as an Orun component-native desired-state repo. It
keeps no store of its own: chats, files, versions and previews are the v0
API's, under whichever v0 key a request carries.

- **`apps/preview`** — the preview proxy: Next.js built by
  `@opennextjs/cloudflare` into its own Worker plus Static Assets, on a
  hostname of its own. It fetches a chat's preview with the v0 key and v0's
  preview token and serves it into the host app's iframe, so generated code
  never runs on the origin that holds the key. `/api/api-key` takes a key
  from the host app's origin only (CORS + a partitioned cookie), and the
  proxy registers its own hostname in the v0 team's trusted preview hosts.
- **`apps/web`** — the host app: the chat, the sidebar, the files, code and
  preview panes, and the server routes over the v0 API (`/api/chats/*` —
  messages, files, Design Mode, imports, restore, deploy — and
  `/api/settings/api-key`). Built the same way, into the second
  Worker. `lib/proxy.ts` (`authorizeProxyRequest`) is the same-origin check
  every server route passes — the seam where real session auth goes.
- **`tests/web`**, **`tests/preview`** — vitest: upstream's Design Mode
  tests, the routes, the origins, the key route and the trusted hosts, with
  no network — verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  helper that hands a stored key to a Worker as a secret.

Each app is told the other's origin at build (inlined as
`NEXT_PUBLIC_V0_PREVIEW_PROXY_URL` in the host, `NEXT_PUBLIC_V0_CLONE_ORIGIN`
in the proxy): the environment's `V0_PREVIEW_PROXY_URL` / `V0_CLONE_ORIGIN`
when `intent.yaml` sets them (custom domains), else the sibling Worker's
workers.dev URL for that environment.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. **The preview proxy before the host.** `apps/preview` builds with the
   host's origin, hands the environment's `V0_API_KEY` (if one is stored) to
   its Worker as a secret, `wrangler deploy` ships `v0-clone-preview-<env>`,
   and its smoke reads `/api/health` (`"app":"preview"`, `"ok":true`).
4. `apps/web` declares an enforced `dependsOn` on `preview` for pushes to
   `main`, so it starts after that deploy: it builds with the proxy's
   origin, hands the key the same way, ships `v0-clone-web-<env>`, and its
   smoke fetches `/` (to `</html>`), `/api/health` (`"ok":true`), and then
   the `/api/health` of the proxy origin it names — the iframe points at
   something real. Neither smoke calls the v0 API or needs a key.
5. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
6. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing deploys: both apps build and dry-deploy per
environment, both test suites run on `dev`, and the edge in step 4 is
advisory.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "product
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` (a custom origin, say) maps to
  no component and redeploys nothing on its own. Land it with a change under
  `apps/web` and `apps/preview`, or deploy both by hand.
- Each origin is inlined at build: after changing one, redeploy the app
  that reads it, not only the one that moved.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (the
  `workers-deploy` scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per
  run from the workspace's Cloudflare connection. No long-lived values at
  rest; nothing to rotate by hand. Both Workers' deploys use the same two.
- **`V0_API_KEY`, optional**, stored by you per environment. Unset (the
  default), each visitor connects their own v0 key through the host's
  dialog: it is validated, kept in an HTTP-only cookie on the host's origin,
  and handed by the browser to the proxy, which keeps its own copy. Set,
  every visitor shares it and the dialog turns read-only — so put Cloudflare
  Access in front of both Workers first. The build resolves it if it exists
  (a missing one is skipped, not an error), keeps it out of the bundle
  (`env -u`) and hands it to each Worker with `wrangler secret bulk` before
  the deploy.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.

## Verifying the system

```bash
# the health check on each Worker (also recorded, probed, in deployment.md):
# ok, the sibling origin it was built with, and where its v0 key comes from
curl -s https://v0-clone-web-stage.your-workers-subdomain.workers.dev/api/health
curl -s https://v0-clone-preview-stage.your-workers-subdomain.workers.dev/api/health
curl -s -o /dev/null -w '%{http_code}\n' https://v0-clone-web-prod.your-workers-subdomain.workers.dev/

# workspace readiness
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| change the host app | `apps/web/app`, `apps/web/components` (its name: `apps/web/lib/site.ts`), merge |
| change the preview proxy | `apps/preview/app` (its name: `apps/preview/lib/site.ts`); the preview route is `app/api/v0-preview/[chatId]/[[...path]]/route.ts` (and `proxy.ts`, which sends a preview's own absolute paths back under it), the key route `app/api/api-key/route.ts` |
| add real sign-in | replace `authorizeProxyRequest` in `apps/web/lib/proxy.ts` and `apps/preview/lib/authorize.ts` with a session check |
| connect one v0 key for everyone | `orun secrets set V0_API_KEY --org <ws> --env <env>` (after Cloudflare Access is in front of both Workers), then deploy that environment by hand |
| remove the key | `orun secrets revoke V0_API_KEY --org <ws> --env <env>`, then `wrangler secret delete V0_API_KEY --name v0-clone-web-<env>` and the same for `v0-clone-preview-<env>` — each Worker keeps its copy until then |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` or `apps/preview/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve custom domains | attach a domain to each Worker in Cloudflare — the proxy's on a different registrable domain from the host's — then set `V0_PREVIEW_PROXY_URL` and `V0_CLONE_ORIGIN` under the environment's `env:` in `intent.yaml` and redeploy both (README, "Custom domains"); replace the placeholder `v0-clone.example.com` in `BASE_DOMAIN` in the same change |
| prune trusted preview hosts | v0 keeps at most five; remove stale hostnames in v0's settings (each environment's proxy re-registers its own) |
| add a runtime secret of your own | `orun secrets set <KEY> --org <ws> --env <env>`, its ref under `optionalSecretEnv` in the app's `component.yaml` and a `--secret <KEY>` (and `-u <KEY>`) in its `buildCommand` |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Accounts, saved settings or a usage cap would be a data component of their
own — D1 or Postgres — and the session check in `authorizeProxyRequest`.
Structural changes follow the same contract that deployed the product: add a
component under `apps/`, `infra/` or `packages/` with a `component.yaml`,
land it as a pull request, and the convergence run applies it.
