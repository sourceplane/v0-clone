# apps/preview — the preview proxy

The v0 clone's preview origin (upstream's `apps/preview-proxy`): it fetches a
chat's preview from the v0 API with the key and serves it, path for path,
into the host app's iframe; `proxy.ts` keeps root-relative preview requests on
the chat's proxy path; `/api/api-key` lets only the host app's origin
provision this proxy's own cookie. Generated code runs here, never on the
host's origin. One Cloudflare Worker per environment (`<repo>-preview-<env>`).
Upstream: [vercel/v0-sdk `examples/v0-clone/apps/preview-proxy`](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone/apps/preview-proxy)
(Apache-2.0, `LICENSE`).
