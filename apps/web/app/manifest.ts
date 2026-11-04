import type { MetadataRoute } from 'next'
import { SITE_NAME } from '@/lib/site'

// Installed on a phone, the app opens on its own, without the browser's bars.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: SITE_NAME,
    short_name: SITE_NAME,
    description: 'A v0.app clone built with AI Elements and Geist.',
    start_url: '/',
    display: 'standalone',
    background_color: '#ffffff',
    theme_color: '#ffffff',
    icons: [{ src: '/icon.svg', sizes: 'any', type: 'image/svg+xml' }],
  }
}
