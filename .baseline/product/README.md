# v0-clone

An AI app builder — describe an app, the [v0 Platform API](https://v0.app/docs/api/platform)
writes it, and you refine it in chat, read and edit its files, restore a
version, design against its live preview and deploy it — with every preview
served from an origin of its own, so generated code never runs beside the
app that holds the key. Vercel's [v0 clone](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone)
(the v0 SDK's example app) on **two Cloudflare Workers + Static Assets**
through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare): the
host app and its preview proxy, each told the other's origin at build. It
keeps no store of its own: chats, files and previews are the v0 API's.

> **Security warning — upstream's, read for Cloudflare.** There are no user
> accounts. With `V0_API_KEY` stored, everyone who can reach the Workers
> shares that key's v0 workspace: they can read, create, change and delete
> chats, run generations at its expense and deploy with the Vercel token the
> key carries. Every server route passes through `authorizeProxyRequest`
> (`apps/web/lib/proxy.ts`, `apps/preview/lib/authorize.ts`), a same-origin
> check only — the seam where real session auth goes. Until it does, **leave
> `V0_API_KEY` unset** (each visitor then uses their own key, through the
> app's dialog) or put [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/)
> in front of both Workers before you store one.

Building on it with an agent? Start it at [AGENTS.md](AGENTS.md): what to
read first, how a change lands, and what not to touch.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the product uses into
[ai/context/deployment.md](ai/context/deployment.md); how the product deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The host app: the chat, the sidebar, the files, code and preview panes | `apps/web/app`, `apps/web/components` |
| Its server routes over the v0 API: messages, files, Design Mode, imports, restore, deploy | `apps/web/app/api/chats`, `apps/web/app/api/settings/api-key` |
| The preview proxy: each chat's preview, fetched with the key and served into the host's iframe; the key route the host provisions | `apps/preview/app/api/v0-preview`, `apps/preview/app/api/api-key`, `apps/preview/proxy.ts` |
| Where each app finds the other | `apps/web/lib/preview-proxy.ts`, `apps/preview/lib/origins.ts` |
| The v0 key (server, else the visitor's cookie) | `apps/web/lib/v0-client.ts`, `apps/preview/lib/v0-client.ts` |
| The product's name | `apps/web/lib/site.ts`, `apps/preview/lib/site.ts` |
| What each deploy's smoke reads | `apps/web/app/api/health/route.ts`, `apps/preview/app/api/health/route.ts` |
| Workers build and deploy contract | each app's `next.config.mjs`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| The Worker-secrets helper | `tooling/wire` |
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
cookie.

- **Bring your own key (the default).** Leave `V0_API_KEY` unset. Every
  visitor saves their own key through the dialog and spends their own credits.
- **One shared key.** Store it per environment as the Orun secret
  `V0_API_KEY` (`orun secrets set V0_API_KEY --org <ws> --env <env>`) and
  redeploy that environment: both Workers' deploys push it as a Worker
  secret (it never reaches a bundle), and the dialog turns read-only. Read
  the security warning above first.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. Per environment, the preview proxy
deploys first as `v0-clone-preview-<env>`, then the host app as
`v0-clone-web-<env>` — the host waits for its proxy — to `stage`, then to
`prod` once stage has converged on the same commit; `dev` only verifies.
Each deploy is smoke-tested over HTTP: the proxy's `/api/health`, then the
host's page, its `/api/health` and the health of the proxy origin it was
built with. Neither needs a v0 key to pass. A pull request runs the same
pipeline's verify lanes, with nothing deployed: both apps built and
dry-deployed per environment, both test suites run.

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection, and `V0_API_KEY` is an Orun secret you store if you
want one; nothing provider-shaped is stored in the repository or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick (`web`, `preview`), and
each one deploys exactly as a merge would deploy it. Leave the component
blank to redeploy every component in that environment, with nothing
changed: after storing or rotating `V0_API_KEY`, say. A component with
nothing to run in that environment (a test suite in `prod`) is left out with
a notice.

## Custom domains

Both apps answer on workers.dev from their first deploy. Both workers.dev
hostnames share one registrable domain (`<subdomain>.workers.dev`), so the
preview is cross-origin to the host but same-site with it; for production,
give the preview proxy a domain on a **different registrable domain** from
the host's, as upstream recommends. Attach a domain to each Worker
(dashboard → Workers & Pages → `v0-clone-web-prod` / `v0-clone-preview-prod`
→ Settings → Domains & Routes → Add → Custom domain), then tell each build
the other's origin under the environment's `env:` in `intent.yaml`, and
redeploy both apps:

```yaml
env:
  BASE_DOMAIN: acme.com                            # was the placeholder v0-clone.example.com
  V0_PREVIEW_PROXY_URL: https://acme-previews.net  # the host's iframe points here
  V0_CLONE_ORIGIN: https://app.acme.com            # the only origin the proxy lets provision its key
```

## Trusted preview hosts

The preview proxy registers its own hostname in the v0 team's trusted preview
hosts (at most five) the first time it is provisioned with a key or serves a
preview. Stage and prod take two; remove stale ones in v0's settings.

## Credits

Vercel's [v0 clone](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone)
and the v0 SDK are © Vercel, Inc., under the Apache License 2.0
(`apps/web/LICENSE`, `apps/preview/LICENSE`).
