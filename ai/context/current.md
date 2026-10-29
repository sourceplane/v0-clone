# v0-clone — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a product built from it;
the two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's v0 clone (the v0 SDK's example app) — a v0-style chat that creates
and refines apps through the v0 Platform API, with their previews served
from an isolated origin — as two Next.js apps on two Cloudflare Workers +
Static Assets (through `@opennextjs/cloudflare`): the host app (`web`) and
its preview proxy (`preview`), each told the other's origin at build. It
keeps no store of its own; the v0 key is each visitor's own (a cookie) or
one optional `V0_API_KEY` for the deployment. It is packaged as an Orun
baseline: `orun new --blueprint repo-blueprint.yaml` builds a new product in
its own repository and takes it to live on stage and prod in one landing
(`01-product`: the preview origin, then the host app that frames it), then
records what went live (`02-docs`).

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` (VC3, [#4](https://github.com/sourceplane/v0-clone/pull/4)) |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI: the product placed and branded, its plan ordering the preview before the host on each environment, both apps built in orun's staged job trees, dry-deployed and served by `wrangler dev` against a stand-in v0 API — a key provisioned host → proxy, a chat's preview served through the proxy, both deploys' own smokes passed. No bootstrap from a tag has run against a workspace (risk VC-E), and the real v0 API has not been called from a Worker (VC-F) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/v0-clone/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/v0-clone/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/v0-clone/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `apps/preview/docs/`, `tests/web/docs/`, `tests/preview/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one product from the tag against a workspace, connect a v0 key,
   create a chat and open its preview, and record the timings (closes VC-E
   and VC-F).
