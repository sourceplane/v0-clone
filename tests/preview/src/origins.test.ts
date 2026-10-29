import { afterEach, describe, expect, test } from 'vitest'
import { getCloneOrigin } from '@/lib/origins'

// The host app's origin is told to this build (NEXT_PUBLIC_V0_CLONE_ORIGIN,
// inlined by Next; read from process.env here). Vercel's Related Projects are
// gone.
afterEach(() => {
  delete process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN
})

describe('the preview proxy finds its host app', () => {
  test('next dev, with nothing set, gets the local host as upstream does', () => {
    expect(getCloneOrigin()).toBe('http://localhost:3000')
  })
  test('a deployed build gets the origin its environment rendered', () => {
    process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN = 'https://acme-web-prod.acme.workers.dev'
    expect(getCloneOrigin()).toBe('https://acme-web-prod.acme.workers.dev')
  })
  test('an origin with a path, or plain HTTP off loopback, is refused', () => {
    process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN = 'https://acme.example/app'
    expect(() => getCloneOrigin()).toThrow(/origin without a path/)
    process.env.NEXT_PUBLIC_V0_CLONE_ORIGIN = 'http://acme.example'
    expect(() => getCloneOrigin()).toThrow(/HTTPS/)
  })
})
