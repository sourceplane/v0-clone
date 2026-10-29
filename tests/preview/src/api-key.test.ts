import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'

// The preview proxy's key route: only the host app's origin may provision it
// (credentialed CORS), it validates the key against v0 by registering its own
// hostname as a trusted preview host, then keeps the key in its own cookie.
const getPreviewHosts = vi.fn(async () => ({ data: { hosts: [] as string[] }, error: undefined, response: { status: 200 } }))
const setPreviewHosts = vi.fn(async (_: { hosts: string[] }) => ({ data: {}, error: undefined, response: { status: 200 } }))
const jar = new Map<string, string>()
vi.doMock('v0', () => ({ createV0Client: () => ({ settings: { getPreviewHosts, setPreviewHosts } }) }))
vi.doMock('next/headers', () => ({
  cookies: async () => ({ set: (name: string, value: string) => jar.set(name, value), get: (name: string) => (jar.has(name) ? { value: jar.get(name) } : undefined) }),
}))
const { OPTIONS, PUT, DELETE } = await import('@/app/api/api-key/route')

const HOST = 'https://acme-web-stage.acme.workers.dev'
const PROXY = 'https://acme-preview-stage.acme.workers.dev/api/api-key'
const put = (origin: string, body: unknown) =>
  new Request(PROXY, { method: 'PUT', headers: { Origin: origin, 'Content-Type': 'application/json' }, body: JSON.stringify(body) })

beforeEach(() => {
  process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN = HOST
  jar.clear()
  getPreviewHosts.mockClear()
  setPreviewHosts.mockClear()
})
afterEach(() => {
  delete process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN
  delete process.env.V0_API_KEY
})

describe("the preview proxy's key route", () => {
  test('a preflight from the host app is allowed, credentials and all', async () => {
    const res = await OPTIONS(new Request(PROXY, { method: 'OPTIONS', headers: { Origin: HOST } }))
    expect(res.status).toBe(204)
    expect(res.headers.get('access-control-allow-origin')).toBe(HOST)
    expect(res.headers.get('access-control-allow-credentials')).toBe('true')
  })
  test('any other origin is refused, and nothing is stored', async () => {
    expect((await OPTIONS(new Request(PROXY, { method: 'OPTIONS', headers: { Origin: 'https://evil.example' } }))).status).toBe(403)
    expect((await PUT(put('https://evil.example', { apiKey: 'k' }))).status).toBe(403)
    expect(jar.size).toBe(0)
  })
  test("the host app's key registers the proxy's hostname and is kept in the proxy's own cookie", async () => {
    const res = await PUT(put(HOST, { apiKey: '  v1:team:token  ' }))
    expect(res.status).toBe(200)
    expect(setPreviewHosts).toHaveBeenCalledWith({ hosts: ['acme-preview-stage.acme.workers.dev'] })
    expect([...jar.values()]).toEqual(['v1:team:token'])
  })
  test('an empty key is refused', async () => {
    expect((await PUT(put(HOST, { apiKey: ' ' }))).status).toBe(400)
  })
  test('with V0_API_KEY set on the proxy, a browser key is refused', async () => {
    process.env.V0_API_KEY = 'v1:team:server'
    expect((await PUT(put(HOST, { apiKey: 'k' }))).status).toBe(409)
  })
  test('DELETE clears the cookie the key was kept in', async () => {
    await PUT(put(HOST, { apiKey: 'v1:team:token' }))
    const [name] = [...jar.keys()]
    const res = await DELETE(new Request(PROXY, { method: 'DELETE', headers: { Origin: HOST } }))
    expect(res.status).toBe(200)
    expect(jar.get(name!)).toBe('')
  })
})
