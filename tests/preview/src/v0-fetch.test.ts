import { afterEach, describe, expect, test, vi } from 'vitest'
import { v0Fetch } from '@/lib/v0-fetch'

// Unset, every call goes to v0's API exactly as upstream; V0_API_BASE_URL
// points v0's calls — and only v0's — at another origin with the same paths.
const seen: string[] = []
const real = globalThis.fetch
afterEach(() => {
  delete process.env.V0_API_BASE_URL
  globalThis.fetch = real
  seen.length = 0
})
function stubFetch() {
  globalThis.fetch = vi.fn(async (input: RequestInfo | URL) => {
    seen.push(input instanceof Request ? input.url : String(input))
    return new Response('{}')
  }) as typeof fetch
}

describe('v0Fetch', () => {
  test('unset, a v0 call goes to api.v0.dev unchanged', async () => {
    stubFetch()
    await v0Fetch('https://api.v0.dev/v2/chats?limit=1')
    expect(seen).toEqual(['https://api.v0.dev/v2/chats?limit=1'])
  })
  test('set, a v0 call keeps its path and query on the other origin', async () => {
    stubFetch()
    process.env.V0_API_BASE_URL = 'http://127.0.0.1:9911'
    await v0Fetch(new Request('https://api.v0.dev/v2/chats/abc/preview', { headers: { Authorization: 'Bearer k' } }))
    expect(seen).toEqual(['http://127.0.0.1:9911/v2/chats/abc/preview'])
  })
  test('set, a call to anywhere else is left alone', async () => {
    stubFetch()
    process.env.V0_API_BASE_URL = 'http://127.0.0.1:9911'
    await v0Fetch('https://api.vercel.com/v13/deployments/d')
    expect(seen).toEqual(['https://api.vercel.com/v13/deployments/d'])
  })
})
