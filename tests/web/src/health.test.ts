import { afterEach, describe, expect, test } from 'vitest'
import { GET } from '@/app/api/health/route'

// The deploy's smoke reads this. It answers from the Worker alone — no v0
// call — and says whether a server key is set, never what it is.
afterEach(() => {
  delete process.env.V0_API_KEY
  delete process.env.NEXT_PUBLIC_V0_PREVIEW_PROXY_URL
})

describe("the host app's health route", () => {
  test('names the preview proxy origin its build was given', async () => {
    process.env.NEXT_PUBLIC_V0_PREVIEW_PROXY_URL = 'https://acme-preview-stage.acme.workers.dev'
    const res = GET()
    expect(res.headers.get('cache-control')).toBe('no-store')
    expect(await res.json()).toEqual({
      ok: true,
      app: 'web',
      previewProxy: 'https://acme-preview-stage.acme.workers.dev',
      v0ApiKey: 'browser',
    })
  })
  test('a server key is reported as set, and its value never appears', async () => {
    process.env.V0_API_KEY = 'v1:team_x:secret-token'
    const body = await GET().text()
    expect(JSON.parse(body).v0ApiKey).toBe('environment')
    expect(body).not.toContain('secret-token')
  })
})
