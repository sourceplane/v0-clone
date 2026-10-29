import { describe, expect, test, vi } from 'vitest'
import { ensureTrustedPreviewHost, TrustedHostError } from '@/lib/trusted-host'
import { authorizeProxyRequest } from '@/lib/authorize'

// Each environment's preview Worker registers its own workers.dev hostname in
// the v0 team's trusted preview hosts, at most five of them.
function client(hosts: string[]) {
  const setPreviewHosts = vi.fn(async (_: { hosts: string[] }) => ({ data: {}, error: undefined, response: { status: 200 } }))
  return {
    setPreviewHosts,
    settings: { getPreviewHosts: async () => ({ data: { hosts }, error: undefined, response: { status: 200 } }), setPreviewHosts },
  }
}
type Client = Parameters<typeof ensureTrustedPreviewHost>[0]

describe('trusted preview hosts', () => {
  test('a new hostname is added beside the ones already there', async () => {
    const c = client(['old.example'])
    await ensureTrustedPreviewHost(c as unknown as Client, 'acme-preview-stage.acme.workers.dev')
    expect(c.setPreviewHosts).toHaveBeenCalledWith({ hosts: ['old.example', 'acme-preview-stage.acme.workers.dev'] })
  })
  test('a hostname a wildcard already covers is left alone', async () => {
    const c = client(['*.acme.workers.dev'])
    await ensureTrustedPreviewHost(c as unknown as Client, 'acme-preview-prod.acme.workers.dev')
    expect(c.setPreviewHosts).not.toHaveBeenCalled()
  })
  test('five hosts already is a 409 naming the limit', async () => {
    const c = client(['a', 'b', 'c', 'd', 'e'])
    await expect(ensureTrustedPreviewHost(c as unknown as Client, 'x.example')).rejects.toMatchObject({ status: 409 })
    await expect(ensureTrustedPreviewHost(c as unknown as Client, 'x.example')).rejects.toBeInstanceOf(TrustedHostError)
  })
  test('localhost needs no registration', async () => {
    const c = client([])
    await ensureTrustedPreviewHost(c as unknown as Client, 'localhost')
    expect(c.setPreviewHosts).not.toHaveBeenCalled()
  })
})

describe("upstream's same-origin seam", () => {
  test('a cross-origin browser request is refused, a same-origin one passes', () => {
    const url = 'https://acme-preview-stage.acme.workers.dev/api/v0-preview/chat_1'
    expect(authorizeProxyRequest(new Request(url, { headers: { Origin: 'https://evil.example' } }))?.status).toBe(403)
    expect(authorizeProxyRequest(new Request(url, { headers: { Origin: 'https://acme-preview-stage.acme.workers.dev' } }))).toBeUndefined()
    expect(authorizeProxyRequest(new Request(url))).toBeUndefined()
  })
})
