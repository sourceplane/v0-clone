import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, test, vi } from 'vitest'

// The phone layout, the way a native chat app does it: a drawer for the chats,
// a top bar with the menu, the title and a new chat, one pane at a time on a
// chat (Chat | Preview | Code), and a composer that never makes iOS zoom.

vi.mock('next/navigation', () => ({
  usePathname: () => '/',
  useRouter: () => ({ push: () => {}, refresh: () => {} }),
}))

const { AppShell, MobileTopBar } = await import('@/components/layout/app-shell')
const { PreviewProxyProvider } = await import('@/components/preview/preview-proxy-provider')
const { TooltipProvider } = await import('@/components/ui/tooltip')
const { ChatHeader } = await import('@/components/chat/chat-header')
const { PromptBox } = await import('@/components/prompt-box')
const { default: manifest } = await import('@/app/manifest')

const apiKeyStatus = { hasBrowserApiKey: false, hasEnvironmentApiKey: true }
// Already settled, the way React reads a promise it has seen resolve.
const sidebarChats = Object.assign(
  Promise.resolve({ favoriteChats: [], recentChats: { chats: [], cursor: null } }),
  { status: 'fulfilled', value: { favoriteChats: [], recentChats: { chats: [], cursor: null } } },
)

const classOf = (html: string, pattern: RegExp) => pattern.exec(html)?.[1] ?? ''
const decode = (html: string) => html.replace(/&amp;/g, '&').replace(/&quot;/g, '"')

describe('the shell on a phone', () => {
  const html = decode(
    renderToStaticMarkup(
      <PreviewProxyProvider origin="https://preview.example.test">
        <TooltipProvider>
          <AppShell apiKeyStatus={apiKeyStatus} sidebarChats={sidebarChats as never}>
            <MobileTopBar title="My App Builder" />
          </AppShell>
        </TooltipProvider>
      </PreviewProxyProvider>,
    ),
  )

  test('the chats are a drawer, closed at first, beside the page on a wide screen', () => {
    const aside = classOf(html, /<aside[^>]*class="([^"]*)"/)
    expect(aside).toContain('fixed')
    expect(aside).toContain('-translate-x-full')
    // Out of the tab order and the screen reader while shut, on a phone only.
    expect(aside).toContain('max-md:invisible')
    expect(aside).toContain('md:static')
    expect(aside).toContain('md:translate-x-0')
    expect(aside).toContain('md:w-64')
  })

  test('its scrim lets taps through while the drawer is shut', () => {
    const scrim = classOf(html, /<div aria-hidden="true" class="([^"]*bg-black[^"]*)"/)
    expect(scrim).toContain('pointer-events-none')
    expect(scrim).toContain('md:hidden')
  })

  test('the page runs under the notch, padded by the safe area', () => {
    expect(html).toContain('h-dvh')
    expect(html).toContain('pt-[env(safe-area-inset-top)]')
  })

  test('the top bar has the menu, the title and a new chat, on a phone only', () => {
    const bar = /<header class="([^"]*)">([\s\S]*?)<\/header>/.exec(html)!
    expect(bar[1]).toContain('md:hidden')
    expect(bar[2]).toContain('aria-label="Open menu"')
    expect(bar[2]).toContain('My App Builder')
    expect(bar[2]).toContain('aria-label="New chat"')
  })
})

describe('a chat on a phone', () => {
  const header = (mobilePane: 'chat' | 'preview' | 'code') =>
    decode(
      renderToStaticMarkup(
        <ChatHeader
          chatId="chat_1"
          mobilePane={mobilePane}
          onMobilePaneChange={() => {}}
          onViewChange={() => {}}
          title="Yoga studio"
          view="preview"
        />,
      ),
    )

  test('switches between Chat, Preview and Code, the chat first', () => {
    const html = header('chat')
    expect([...html.matchAll(/role="tab"[^>]*>([^<]+)</g)].map((m) => m[1])).toEqual([
      'Chat',
      'Preview',
      'Code',
    ])
    expect(/aria-selected="true"[^>]*>([^<]+)</.exec(html)?.[1]).toBe('Chat')
    expect(/aria-selected="true"[^>]*>([^<]+)</.exec(header('code'))?.[1]).toBe('Code')
  })

  test('has the title and the chat’s actions in one menu', () => {
    const html = header('chat')
    expect(html).toContain('Yoga studio')
    expect(html).toContain('aria-label="Chat actions"')
  })
})

describe('the composer', () => {
  const render = (compact: boolean) =>
    decode(
      renderToStaticMarkup(
        <PromptBox
          compact={compact}
          model="v0-mini"
          onModelChange={() => {}}
          onSubmit={() => {}}
        />,
      ),
    )

  test('writes at 16px on a phone, so iOS does not zoom when it takes focus', () => {
    for (const compact of [false, true]) {
      const textarea = classOf(render(compact), /<textarea[^>]*class="([^"]*)"/).split(/\s+/)
      expect(textarea).toContain('text-base')
      expect(textarea).not.toContain('text-sm')
      expect(textarea).not.toContain('text-xs')
    }
  })

  test('sends with a round button on a phone', () => {
    const tag = /<button[^>]*aria-label="Send message"[^>]*>/.exec(render(true))?.[0] ?? ''
    const send = classOf(tag, /class="([^"]*)"/)
    expect(send).toContain('rounded-full')
    expect(send).toContain('md:rounded-lg')
  })
})

test('installed on a phone, it opens on its own, like an app', () => {
  expect(manifest()).toMatchObject({ display: 'standalone', start_url: '/' })
})
