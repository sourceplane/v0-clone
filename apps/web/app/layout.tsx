import type { Metadata, Viewport } from 'next'
import { SITE_NAME } from '@/lib/site'
import { GeistSans } from 'geist/font/sans'
import { GeistMono } from 'geist/font/mono'
import { ThemeProvider } from 'next-themes'
import { TooltipProvider } from '@/components/ui/tooltip'
import { AppShell } from '@/components/layout/app-shell'
import { PreviewProxyProvider } from '@/components/preview/preview-proxy-provider'
import { getPreviewProxyOrigin } from '@/lib/preview-proxy'
import { getSidebarChats } from '@/lib/sidebar-chats'
import { getV0ApiKeyStatus } from '@/lib/v0-client'
import './globals.css'

export const dynamic = 'force-dynamic'

export const metadata: Metadata = {
  title: SITE_NAME,
  description: 'A v0.app clone built with AI Elements and Geist.',
  // Added to a phone's home screen, it opens full screen, like an app.
  appleWebApp: { capable: true, title: SITE_NAME, statusBarStyle: 'default' },
}

// A phone: the page runs edge to edge (the shell pads for the notch and the
// home bar), the keyboard shrinks the page rather than covering the composer,
// and the browser's bars take the page's colour.
export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  interactiveWidget: 'resizes-content',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0f0f11' },
  ],
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  const sidebarChats = getSidebarChats()
  const apiKeyStatus = await getV0ApiKeyStatus()
  const previewProxyOrigin = getPreviewProxyOrigin()

  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${GeistSans.variable} ${GeistMono.variable} antialiased`}>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
          storageKey="theme"
        >
          <PreviewProxyProvider origin={previewProxyOrigin}>
            <TooltipProvider delayDuration={300}>
              <AppShell apiKeyStatus={apiKeyStatus} sidebarChats={sidebarChats}>
                {children}
              </AppShell>
            </TooltipProvider>
          </PreviewProxyProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
