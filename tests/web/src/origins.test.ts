import { afterEach, describe, expect, test } from 'vitest'
import { getPreviewProxyOrigin, parseOrigin } from '@/lib/preview-proxy'

// Each app is told the other's origin at build time (NEXT_PUBLIC_…, inlined by
// Next; read from process.env here). Vercel's Related Projects are gone.
afterEach(() => {
  delete process.env.NEXT_PUBLIC_V0_PREVIEW_PROXY_URL
})

describe('the host app finds its preview proxy', () => {
  test('next dev, with nothing set, gets the local proxy as upstream does', () => {
    expect(getPreviewProxyOrigin()).toBe('http://localhost:3001')
  })
  test('a deployed build gets the origin its environment rendered', () => {
    process.env.NEXT_PUBLIC_V0_PREVIEW_PROXY_URL = 'https://acme-preview-stage.acme.workers.dev'
    expect(getPreviewProxyOrigin()).toBe('https://acme-preview-stage.acme.workers.dev')
  })
  test('a trailing slash is still an origin', () => {
    process.env.NEXT_PUBLIC_V0_PREVIEW_PROXY_URL = 'https://previews.example.net/'
    expect(getPreviewProxyOrigin()).toBe('https://previews.example.net')
  })
  test('a path, a query or credentials are refused', () => {
    for (const bad of ['https://x.example/p', 'https://x.example/?a=1', 'https://u:p@x.example']) {
      expect(() => parseOrigin(bad, 'The preview proxy URL')).toThrow(/origin without a path/)
    }
  })
  test('plain HTTP is refused except on loopback (a local wrangler dev)', () => {
    expect(() => parseOrigin('http://x.example', 'The preview proxy URL')).toThrow(/HTTPS/)
    expect(parseOrigin('http://127.0.0.1:8788', 'The preview proxy URL')).toBe('http://127.0.0.1:8788')
  })
})
