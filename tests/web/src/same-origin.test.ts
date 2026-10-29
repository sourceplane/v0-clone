import { describe, expect, test } from 'vitest'
import { authorizeProxyRequest } from '@/lib/proxy'

// Upstream's seam for session auth, kept: a cross-origin browser request to a
// server route is refused.
describe("upstream's same-origin seam", () => {
  test('a cross-origin browser request is refused, a same-origin one passes', () => {
    const url = 'https://acme-web-stage.acme.workers.dev/api/chats'
    expect(authorizeProxyRequest(new Request(url, { headers: { Origin: 'https://evil.example' } }))?.status).toBe(403)
    expect(authorizeProxyRequest(new Request(url, { headers: { Origin: 'https://acme-web-stage.acme.workers.dev' } }))).toBeUndefined()
    expect(authorizeProxyRequest(new Request(url))).toBeUndefined()
  })
})
