// The Worker's environment as getCloudflareContext().env (and process.env,
// which @opennextjs/cloudflare fills from it) sees it: the static-assets
// binding, and the one optional Worker secret the deploy lane sets
// (tooling/wire/worker-secrets.mjs). The app's own code reads neither through
// Worker types — upstream's client code needs the DOM's, which
// @cloudflare/workers-types would shadow — so ASSETS is typed by its shape.
interface CloudflareEnv {
  ASSETS: { fetch: typeof fetch }
  V0_API_KEY?: string
}
