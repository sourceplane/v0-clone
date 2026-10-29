# web

The v0 clone's host app — the chat UI, its server routes over the v0 Platform API and the preview iframe (Next.js on Cloudflare Workers + Static Assets via @opennextjs/cloudflare, per environment)

A Cloudflare Worker with Static Assets (server rendering plus static files), deployed per environment by its CI lane.

|              |                                                                                                                    |
| ------------ | ------------------------------------------------------------------------------------------------------------------ |
| Type         | `cloudflare-workers-assets-turbo`                                                                                  |
| Source       | `apps/web`                                                                                                         |
| Package      | `@app/web`                                                                                                         |
| Environments | `dev`: `verify` · `stage`: `verify`, `deploy` on a push to `main` · `prod`: `verify`, `deploy` on a push to `main` |

## Depends on

- **preview** — The v0 clone's preview proxy, on an origin of its own — it fetches each chat's preview with the v0 key and serves it into the host app's iframe (Next.js on Cloudflare Workers + Static Assets via @opennextjs/cloudflare, per environment)

## Depended on by

- (none)
