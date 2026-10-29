import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare'
import { PHASE_DEVELOPMENT_SERVER } from 'next/constants.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Required by @opennextjs/cloudflare, which bundles `.next/standalone/**`
  // into the Worker; traced from the monorepo root. Upstream's config was
  // empty — Vercel needs neither.
  output: 'standalone',
  outputFileTracingRoot: path.join(__dirname, '../..'),
}

// `next dev` gets the Worker's environment (V0_API_KEY from .dev.vars, when
// set) through wrangler's local platform proxy. Only the dev server starts
// it: a build must need nothing from wrangler.
export default function config(phase) {
  if (phase === PHASE_DEVELOPMENT_SERVER) {
    initOpenNextCloudflareForDev()
  }
  return nextConfig
}
