# apps/web — the host app

The v0 clone's host: the chat UI, its server routes over the v0 Platform API
(`app/api/**`, each behind `authorizeProxyRequest`) and the preview iframe,
which points at the preview proxy (`../preview`) on its own origin. One
Cloudflare Worker per environment, built by `@opennextjs/cloudflare`
(`<repo>-web-<env>`). See the repository README for running, connecting v0
and deploying. Upstream: [vercel/v0-sdk `examples/v0-clone/apps/web`](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone/apps/web)
(Apache-2.0, `LICENSE`).
