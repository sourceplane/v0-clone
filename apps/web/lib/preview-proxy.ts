import 'server-only'

const LOCAL_PREVIEW_PROXY_URL = 'http://localhost:3001'

/**
 * The preview proxy's origin — where the preview iframe points.
 *
 * On Vercel, Related Projects told this app the proxy's URL per deployment
 * (VERCEL_RELATED_PROJECTS), with V0_PREVIEW_PROXY_URL as the production
 * override. Here each environment's build is told it:
 * NEXT_PUBLIC_V0_PREVIEW_PROXY_URL is inlined at build time, from the
 * environment's V0_PREVIEW_PROXY_URL when an owner sets one (a custom domain),
 * else the preview Worker's workers.dev URL for that environment
 * (component.yaml's buildCommand). `next dev` sets neither and gets the local
 * proxy, as upstream does.
 */
export function getPreviewProxyOrigin() {
  const configured = process.env.NEXT_PUBLIC_V0_PREVIEW_PROXY_URL
  if (!configured) return LOCAL_PREVIEW_PROXY_URL
  return parseOrigin(configured, 'The preview proxy URL')
}

/**
 * An HTTP(S) origin with no path, query, fragment or credentials — HTTPS
 * everywhere but loopback (a local `wrangler dev` of the built Worker).
 */
export function parseOrigin(value: string, what: string) {
  const url = new URL(value)

  if (
    (url.protocol !== 'http:' && url.protocol !== 'https:') ||
    url.username ||
    url.password ||
    url.pathname !== '/' ||
    url.search ||
    url.hash
  ) {
    throw new Error(`${what} must be an HTTP(S) origin without a path.`)
  }

  if (url.protocol !== 'https:' && !isLoopback(url.hostname)) {
    throw new Error(`${what} must use HTTPS.`)
  }

  return url.origin
}

function isLoopback(hostname: string) {
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '[::1]'
}
