const defaultCloneOrigin = 'http://localhost:3000'

/**
 * The host app's origin — the only origin allowed to provision this proxy's
 * key (app/api/api-key/route.ts).
 *
 * On Vercel, Related Projects told this app the host's URL per deployment,
 * with V0_CLONE_ORIGIN as the production override. Here each environment's
 * build is told it: NEXT_PUBLIC_V0_CLONE_ORIGIN is inlined at build time, from
 * the environment's V0_CLONE_ORIGIN when an owner sets one (a custom domain),
 * else the host Worker's workers.dev URL for that environment (component.yaml's
 * buildCommand). `next dev` sets neither and gets the local host app, as
 * upstream does.
 */
export function getCloneOrigin() {
  const configured = process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN
  if (!configured) return defaultCloneOrigin

  const url = new URL(configured)

  if (
    (url.protocol !== 'http:' && url.protocol !== 'https:') ||
    url.username ||
    url.password ||
    url.pathname !== '/' ||
    url.search ||
    url.hash
  ) {
    throw new Error('V0_CLONE_ORIGIN must be an HTTP(S) origin without a path.')
  }

  if (url.protocol !== 'https:' && !isLoopback(url.hostname)) {
    throw new Error('V0_CLONE_ORIGIN must use HTTPS.')
  }

  return url.origin
}

function isLoopback(hostname: string) {
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '[::1]'
}
