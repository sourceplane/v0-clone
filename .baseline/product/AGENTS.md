# AGENTS.md — v0-clone

For a coding agent (or a person) about to change this repository.

## What this is

An AI app builder over the v0 Platform API: a v0-style chat that creates and
refines apps, shows their files and a live preview, and deploys them — with
the preview served from an origin of its own. Two Next.js apps on two
Cloudflare Workers + Static Assets (built by `@opennextjs/cloudflare`), each
told the other's origin at build; no database, and the v0 key each visitor's
own (a cookie) unless the owner stores one. It is an
[Orun](https://github.com/sourceplane/orun) repository: `intent.yaml`
declares the environments, and each `component.yaml` is a component Orun
plans and deploys.

| Component | Path | What it is |
|---|---|---|
| `preview` | `apps/preview` | the preview proxy and its Worker, `v0-clone-preview-<env>` |
| `web` | `apps/web` | the host app and its Worker, `v0-clone-web-<env>` |
| `preview-tests` | `tests/preview` | vitest: the key route, the origins, trusted hosts |
| `web-tests` | `tests/web` | vitest: upstream's Design Mode tests, the host's routes |

## Read first

1. `README.md` — run, test, connect v0, and how it deploys; and its security
   warning: there are no accounts.
2. `ai/context/operations.md` — the operating contract: deploy order,
   secrets, caveats, common operations.
3. `ai/context/deployment.md` — what is live now: URLs, workspace, secrets
   by name.
4. `apps/web/components/home/home-client.tsx` and
   `apps/web/components/chat/` — the chat; `apps/web/app/api/chats/` — its
   routes over the v0 API; `apps/web/lib/v0-client.ts` — which key.
5. `apps/preview/app/api/v0-preview/[chatId]/[[...path]]/route.ts` and
   `apps/preview/proxy.ts` — how a preview is served;
   `apps/preview/app/api/api-key/route.ts` — how the host hands it a key.

## Before you push

```bash
pnpm install
pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

Run them yourself: the pull request's lanes build and dry-deploy both apps
and run both test suites, but do not run the linter.

## How changes land

- One change, one pull request into `main`. If the work is an Orun task,
  open the pull request for it: `orun pr open --task <KEY>`.
- On the pull request, `ci.yml` plans with `orun plan --changed` and
  verifies: both apps build and dry-deploy, both test suites run. Nothing
  deploys.
- The merge is the deploy. `ci.yml` plans the changed components and runs
  each lane: the preview proxy builds with the host's origin, hands a stored
  key to its Worker as a secret, deploys and is smoke-tested; then the host
  does the same with the proxy's origin — stage, then prod.
- A new component is a directory under `apps/`, `infra/`, `packages/` or
  `tests/` with a `component.yaml`.

## What not to touch

- `intent.yaml` → `execution.state.workspace`: the workspace CI
  authenticates to. Also the stack-tectonic pin (`0.19.0`); its comment says
  why it is not `0.20.0`.
- `apps/web/component.yaml`'s `dependsOn: preview`: it is what makes the
  preview origin deploy before the host on `main`, and the host's smoke
  checks that origin.
- Each app's `buildCommand`: it inlines the other app's origin
  (`NEXT_PUBLIC_V0_PREVIEW_PROXY_URL`, `NEXT_PUBLIC_V0_CLONE_ORIGIN`). Change
  an origin under the environment's `env:` in `intent.yaml`, not in code.
- `authorizeProxyRequest` (`apps/web/lib/proxy.ts`,
  `apps/preview/lib/authorize.ts`) is a same-origin check, not auth. Replace
  it with a session check before storing `V0_API_KEY` without Cloudflare
  Access; never loosen it.
- The last line of each `component.yaml` (`# orun: redeploy …`) is a deploy
  trigger; change it only to redeploy.
- `ai/context/deployment.md` is regenerated from probed state; a hand edit is
  overwritten. `.rebrand/values.json` records the product's identity; leave
  it.
- Only `ci.yml` may run on a push to `main`.
- No secret value goes in the repository, and none reaches the build:
  `V0_API_KEY` is an Orun secret the build strips from its environment
  (`env -u V0_API_KEY`) and hands to each Worker as a Worker secret. The
  Cloudflare token and account id are brokered from the workspace's
  Cloudflare connection; list secrets by name only (`orun secrets list`).
