import { getCloneOrigin } from '@/lib/origins'

// The deploy's smoke reads this: it answers from the Worker alone — no v0
// call, no key needed — and names the host app origin the build inlined (the
// only origin that may provision this proxy's key). It says whether a server
// key is set, never what it is.
export const dynamic = 'force-dynamic'

export function GET() {
  return Response.json(
    {
      ok: true,
      app: 'preview',
      cloneOrigin: getCloneOrigin(),
      v0ApiKey: process.env.V0_API_KEY ? 'environment' : 'browser',
    },
    { headers: { 'Cache-Control': 'no-store' } },
  )
}
