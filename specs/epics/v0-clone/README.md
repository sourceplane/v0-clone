# Epic: v0-clone (VC)

**The v0 clone is two Next.js apps over one HTTP API. The host app is a v0-style chat: it creates chats, streams the model's messages, lists files, restores versions and deploys through the v0 Platform API with the `v0` SDK, and shows each chat's app in an iframe. That iframe points at the second app, a preview proxy on an origin of its own, because the preview is generated code and must never run on the host's origin. Both are plain request/response and streaming over `fetch`, so each runs as a Cloudflare Worker built by `@opennextjs/cloudflare`; what Vercel supplied around them — Related Projects telling each app the other's URL, and OIDC as a credential — becomes per-environment origins rendered at build time, and is left out, respectively.**

The port keeps the chat, the sidebar of favourite and recent chats, file, ZIP and GitHub imports, the files and code view, version restore, duplicate and download, task resolution, Design Mode, deploy, and upstream's credential model: an optional server key (`V0_API_KEY`), else a key each visitor saves through the dialog into an HTTP-only cookie on each origin. The model behind the chat is v0's own, reached through its API: there is no model call here that a Workers AI binding could stand in for (decisions).

## Status

| Field | Value |
|-------|-------|
| Status | VC0 in progress |
| Cluster | **VC** (VC0–VC3) |
| Owner(s) | `apps/web` (the host: chat UI, server routes, the preview iframe) · `apps/preview` (the preview proxy) · `tests/web` |
| Builds on | `ai-chatbot` (the OpenNext shape, the CI and tooling), `portfolio-starter-kit` (a baseline with no data plane), `next-forge` (several Workers in one product), `ai-emoji-generator` (optional Orun secrets pushed as Worker secrets) |
| Upstream | [vercel/v0-sdk `examples/v0-clone`](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone) (Apache-2.0), at `024bcaf` (2026-10-23); the `v0` and `@v0-sdk/react` packages from npm at 3.0.12 |
| Changes | bun → pnpm 10 + Node 22 and the reference's lint/test shape; Vercel Related Projects → origins rendered per environment at build; Vercel OIDC left out; the upstream tests (bun:test) run under vitest; a health route per app for the deploy's smoke |
| Gate | VC1 is the first user-visible rung |

## Read order

1. `design.md` — what maps to what, the request flow, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| VC0 — the spec | intent, CI, tooling, the spec index, this doc set and the task contracts | merged on `main` |
| VC1 — the apps on Workers | `apps/web`, `apps/preview`, `tests/web` | both serve under `wrangler dev`, a key saved in the host reaches the proxy; checks green |
| VC2 — ready to instantiate | README, as-built status | a reader can run, test, connect and deploy it |
| VC3 — a baseline | card, build document (`01-product` + `02-docs`), rename, bootstrap tooling, tests | a new app builder goes from nothing to live in one landing; Baseline CI green |

There is no data plane — upstream keeps no store of its own ("chats and files come from the v0 API") — so there is no Terraform root and no migration milestone.
