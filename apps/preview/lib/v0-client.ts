import 'server-only'

import { createHash } from 'node:crypto'
import { cookies } from 'next/headers'
import { createV0Client } from 'v0'
import { v0Fetch } from '@/lib/v0-fetch'

export const V0_PROXY_API_KEY_COOKIE =
  process.env.NODE_ENV === 'production'
    ? '__Host-v0-preview-api-key'
    : 'v0-preview-api-key'

async function getV0ApiKey() {
  if (process.env.V0_API_KEY) return process.env.V0_API_KEY

  const cookieStore = await cookies()
  return cookieStore.get(V0_PROXY_API_KEY_COOKIE)?.value
}

export async function getV0ApiKeyFingerprint() {
  const apiKey = await getV0ApiKey()

  return apiKey ? createHash('sha256').update(apiKey).digest('base64url') : undefined
}

// Upstream fell back to Vercel OIDC when neither key was there; there is no
// OIDC token on Cloudflare, so with no key the v0 API refuses the call and the
// preview shows its loading page until the host app provisions a key.
export const v0 = createV0Client({
  auth: async () => (await getV0ApiKey()) ?? '',
  fetch: v0Fetch,
})
