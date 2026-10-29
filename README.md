# v0-clone

Vercel's [v0 clone](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone)
— the v0 SDK's example app: a v0-style chat that builds apps through the
[v0 Platform API](https://v0.app/docs/api/platform), with a live preview served
from an isolated origin, Design Mode, file, ZIP and GitHub imports, version
restore and one-click deploys — running as **two Cloudflare Workers** built by
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare): the host app
and its preview proxy, each on its own origin, deployed per environment
through [Orun](https://github.com/sourceplane/orun). It keeps no store of its
own: chats, files and previews are the v0 API's.

The v0 SDK and its example are © Vercel, Inc., under the Apache License 2.0
(`apps/web/LICENSE`, `apps/preview/LICENSE`). See
[`specs/epics/v0-clone`](specs/epics/v0-clone/README.md) for the design, the
milestones and the as-built status.

> **Security warning — upstream's, read for Cloudflare.** The example has no
> user accounts. With `V0_API_KEY` stored, everyone who can reach the Workers
> shares that key's v0 workspace: they can read, create, change and delete
> chats, run generations at its expense and deploy with the Vercel token the
> key carries. Every server route passes through `authorizeProxyRequest`
> (`apps/web/lib/proxy.ts`, `apps/preview/lib/authorize.ts`), a same-origin
> check only — the seam where real session auth goes. Until it does, **leave
> `V0_API_KEY` unset** (each visitor then uses their own key, through the
> app's dialog) or put [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/)
> in front of both Workers before you store one.

## What is here

| Surface | Where |
|---|---|
| The host app: the chat, the sidebar, the files, code and preview panes, the server routes over the v0 API | `apps/web` |
| The preview proxy: each chat's preview, fetched with the key and served into the host's iframe; the key route the host provisions | `apps/preview` |
| Where each app finds the other | `apps/web/lib/preview-proxy.ts`, `apps/preview/lib/origins.ts` |
| The v0 key (server, else the visitor's cookie) | `apps/web/lib/v0-client.ts`, `apps/preview/lib/v0-client.ts` |
| Workers build and deploy contract | each app's `next.config.mjs`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (upstream's Design Mode tests, the host's routes), `tests/preview` (the key route, trusted hosts) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build          # next build + opennextjs-cloudflare build, for both apps
```

```bash
pnpm dev            # both apps: the host on http://localhost:3000, the proxy on http://localhost:3001
```

Open the host app and save a v0 API key through its dialog
([v0.app → Settings → API keys](https://v0.app/chat/settings/keys); it needs
write access and generation credits). The key is validated, kept in an
HTTP-only cookie on the host's origin, and handed by your browser straight to
the preview proxy, which keeps its own copy in its own cookie. To serve the
built Workers instead: `pnpm --filter @app/preview preview` and
`pnpm --filter @app/web preview` (wrangler dev; `.dev.vars.example` in each
app).

## Connecting v0

Each app resolves its credential in this order: `V0_API_KEY`, then its own
cookie. Upstream's third, Vercel OIDC, has no Cloudflare equivalent.

- **Bring your own key (the default).** Leave `V0_API_KEY` unset. Every
  visitor saves their own key through the dialog and spends their own credits.
- **One shared key.** Store it per environment as the Orun secret
  `V0_API_KEY` and redeploy: both Workers' deploys push it as a Worker secret
  (it never reaches a bundle), and the dialog turns read-only. Read the
  security warning above first.

## How it maps to Vercel

| Vercel-side | Here |
|---|---|
| `apps/web`, a Vercel project | `apps/web`, the Worker `<repo>-web-<env>` (`.open-next/worker.js` + Static Assets) |
| `apps/preview-proxy`, a second project on another domain | `apps/preview`, the Worker `<repo>-preview-<env>` — its own hostname per environment |
| Related Projects telling each app the other's URL | each build is told the other's origin: `V0_PREVIEW_PROXY_URL` / `V0_CLONE_ORIGIN` from the environment when set (custom domains), else the sibling Worker's workers.dev URL (`component.yaml`'s `buildCommand`) |
| Vercel OIDC as the fallback credential | left out; `V0_API_KEY` (optional Orun secret → Worker secret) or the visitor's own key |
| Deployment Protection on both projects | Cloudflare Access on both Workers, before a shared key is stored |
| Deploy on push | Orun deploys the preview proxy, then the host, to stage → prod on merge to `main`, each smoke-tested |
| `bun test` | `vitest` in `tests/web` and `tests/preview` |

## Deploying

A merge to `main` deploys, per environment, `<repo>-preview-<env>` and then
`<repo>-web-<env>` (the host waits for its proxy), each checked by its
`smokeCommand`: the proxy's `/api/health`, then the host's page, its
`/api/health` and the proxy origin it was built with. Neither needs a v0 key
to pass.

**Deploy by hand:** Orunbase's Deploy button, or Actions → CI → Run workflow
on `main` with a component (`web`, `preview`, or empty for both) and an
environment, deploys exactly as a merge does.

### Custom domains

Attach a domain to each Worker in Cloudflare, then set the two origins under
the environment's `env:` in `intent.yaml` and redeploy both apps:

```yaml
env:
  V0_PREVIEW_PROXY_URL: https://acme-previews.net   # the host's iframe points here
  V0_CLONE_ORIGIN: https://app.acme.com            # the only origin the proxy lets provision its key
```

Both Workers' workers.dev hostnames share one registrable domain
(`<subdomain>.workers.dev`), so the preview is cross-origin to the host but
same-site with it. For production, give the preview proxy a domain on a
**different registrable domain** from the host's, as upstream recommends.

### Trusted preview hosts

The preview proxy registers its own hostname in the v0 team's trusted preview
hosts (at most five) the first time it is provisioned with a key or serves a
preview. Stage and prod take two; remove stale ones in v0's settings.

## CI

| Workflow | What it runs |
|---|---|
| `ci.yml` | the Orun pipeline: `orun plan --changed`, then one job per lane. A pull request verifies (both apps built and dry-deployed per environment, both test suites run); a merge deploys the preview proxy, then the host, stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger |
