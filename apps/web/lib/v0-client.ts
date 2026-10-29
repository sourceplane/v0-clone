import 'server-only'

import { cookies } from 'next/headers'
import { createV0Client } from 'v0'
import { v0Fetch } from '@/lib/v0-fetch'

export const V0_API_KEY_COOKIE = 'v0-api-key'

export async function getV0ApiKey() {
  if (process.env.V0_API_KEY) return process.env.V0_API_KEY

  const cookieStore = await cookies()
  return cookieStore.get(V0_API_KEY_COOKIE)?.value
}

// Upstream fell back to Vercel OIDC when neither key was there. There is no
// OIDC token on Cloudflare, so with no key a call is unauthenticated, the v0
// API refuses it, and the app opens its API key dialog (as upstream does off
// Vercel).
export const v0 = createV0Client({
  auth: async () => (await getV0ApiKey()) ?? '',
  fetch: v0Fetch,
})

export async function getV0ApiKeyStatus() {
  const cookieStore = await cookies()

  return {
    hasBrowserApiKey: Boolean(cookieStore.get(V0_API_KEY_COOKIE)?.value),
    hasEnvironmentApiKey: Boolean(process.env.V0_API_KEY),
  }
}
