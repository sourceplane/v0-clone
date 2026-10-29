# Design — v0-clone

## What maps to what

| Upstream (Vercel) | Here (Cloudflare) |
|---|---|
| `apps/web`, a Vercel project | `apps/web`, the Worker `<repo>-web-<env>` built by OpenNext |
| `apps/preview-proxy`, a second Vercel project on another origin | `apps/preview`, the Worker `<repo>-preview-<env>` — its own `workers.dev` hostname per environment |
| Related Projects (`VERCEL_RELATED_PROJECTS`) telling each app the other's URL | each build is told the other's origin: `V0_PREVIEW_PROXY_URL` / `V0_CLONE_ORIGIN` from the environment when an owner sets them (custom domains), else the sibling Worker's `workers.dev` URL |
| Vercel OIDC as the fallback credential | left out — there is no Cloudflare equivalent; the key is `V0_API_KEY` (an optional Orun secret, a Worker secret on both Workers) or the visitor's own, saved through the dialog |
| `bun test` | `vitest` in `tests/web` |
| `localhost:3000` / `localhost:3001` | the same, for `next dev`; `wrangler dev` serves each built Worker |

## The request flow

```
browser ──► <repo>-web-<env>      chat UI, /api/chats/*, /api/settings/api-key
               │  v0 SDK ──► api.v0.dev (the key: V0_API_KEY, else the visitor's cookie)
               └─ iframe src ──► <repo>-preview-<env>/api/v0-preview/<chatId>/…
                                    │  v0.chats.getPreview + fetchPreview ──► the chat's preview
                                    └─ /api/api-key  (CORS: the web origin only) stores the key in its own partitioned cookie
```

## Out of scope

- A data store: upstream has none; chats and files are the v0 API's.
- Session auth: upstream ships a same-origin check as the seam where real auth goes. Kept as the seam; the README carries upstream's warning, re-read for Cloudflare (Cloudflare Access in front of both Workers before an owner stores a shared key).
