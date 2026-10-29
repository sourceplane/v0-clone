// OpenNext Cloudflare adapter config.
//
// Every route is dynamic: the pages read the visitor's v0 key from a cookie
// (or V0_API_KEY) and fetch chats from the v0 API per request, and nothing
// revalidates. The static-assets incremental cache serves whatever the build
// pre-rendered straight from the Worker's static assets (read only, nothing
// to provision for it; `opennextjs-cloudflare populateCache local` puts it
// there at build time, and with no remote bindings it needs no Cloudflare
// credential). A version that revalidates swaps this for the R2 incremental
// cache plus a tag cache.
import { defineCloudflareConfig } from "@opennextjs/cloudflare/config";
import staticAssetsIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache,
});
