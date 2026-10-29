import { getPreviewProxyOrigin } from '@/lib/preview-proxy'

// The deploy's smoke reads this: it answers from the Worker alone — no v0
// call, no key needed — and names the preview proxy origin the build inlined,
// so the smoke can check that origin answers as the preview proxy. It says
// whether a server key is set, never what it is.
export const dynamic = 'force-dynamic'

export function GET() {
  return Response.json(
    {
      ok: true,
      app: 'web',
      previewProxy: getPreviewProxyOrigin(),
      v0ApiKey: process.env.V0_API_KEY ? 'environment' : 'browser',
    },
    { headers: { 'Cache-Control': 'no-store' } },
  )
}
