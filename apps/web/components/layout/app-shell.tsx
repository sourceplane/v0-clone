'use client'

import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import { usePathname } from 'next/navigation'
import { Sidebar } from '@/components/layout/sidebar'
import { Button } from '@/components/ui/button'
import type { getSidebarChats } from '@/lib/sidebar-chats'
import { MenuIcon, NewChatIcon, SidebarToggleIcon } from '@/lib/icons'
import { cn } from '@/lib/utils'

// The shell: the sidebar beside the page on a wide screen; on a phone, a
// drawer over it, the way a native chat app does it (closed at first, opened
// from the menu button or a swipe from the left edge, closed by the scrim, a
// swipe back, or going to another chat).

const SidebarContext = createContext<{
  open: boolean
  setOpen: (open: boolean) => void
  mobileOpen: boolean
  setMobileOpen: (open: boolean) => void
} | null>(null)

/** How far from the left edge a swipe must start to open the drawer, and how
 *  far it must travel. */
const EDGE_PX = 24
const SWIPE_PX = 56

export function SidebarToggleButton({
  className,
  wideOnly = false,
}: {
  className?: string
  /** Leave the phone's menu button to the page's own top bar. */
  wideOnly?: boolean
}) {
  const sidebar = useContext(SidebarContext)
  if (!sidebar) return null

  return (
    <>
      {/* A phone: the menu button, always there. */}
      {wideOnly ? null : (
        <Button
          aria-label="Open menu"
          className={cn('size-10 shrink-0 text-foreground md:hidden', className)}
          onClick={() => sidebar.setMobileOpen(true)}
          size="icon"
          variant="ghost"
        >
          <MenuIcon size={20} />
        </Button>
      )}
      {/* A wide screen: only while the sidebar is collapsed. */}
      {sidebar.open ? null : (
        <Button
          aria-label="Expand sidebar"
          className={cn('hidden size-8 shrink-0 text-muted-foreground md:inline-flex', className)}
          onClick={() => sidebar.setOpen(true)}
          size="icon"
          variant="ghost"
        >
          <SidebarToggleIcon size={18} />
        </Button>
      )}
    </>
  )
}

/** A phone's new-chat button, top right. */
export function NewChatButton({ className }: { className?: string }) {
  return (
    <Button
      aria-label="New chat"
      className={cn('size-10 shrink-0 text-foreground md:hidden', className)}
      onClick={() => window.location.assign('/')}
      size="icon"
      variant="ghost"
    >
      <NewChatIcon size={20} />
    </Button>
  )
}

/** A phone's top bar: menu, title, then what the page adds (new chat by
 *  default). Hidden on a wide screen. */
export function MobileTopBar({
  title,
  actions,
}: {
  title?: React.ReactNode
  actions?: React.ReactNode
}) {
  return (
    <header className="flex h-12 shrink-0 items-center gap-1 px-1.5 md:hidden">
      <SidebarToggleButton />
      <div className="min-w-0 flex-1 truncate text-center text-[15px] font-semibold text-foreground">
        {title}
      </div>
      {actions ?? <NewChatButton />}
    </header>
  )
}

export function AppShell({
  children,
  apiKeyStatus,
  sidebarChats,
}: {
  children: React.ReactNode
  apiKeyStatus: {
    hasBrowserApiKey: boolean
    hasEnvironmentApiKey: boolean
  }
  sidebarChats: ReturnType<typeof getSidebarChats>
}) {
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [mobileOpen, setMobileOpen] = useState(false)
  const pathname = usePathname()
  const touchStart = useRef<{ x: number; y: number } | null>(null)

  // Going to another chat closes the drawer.
  const [drawerPath, setDrawerPath] = useState(pathname)
  if (drawerPath !== pathname) {
    setDrawerPath(pathname)
    setMobileOpen(false)
  }

  // Escape closes it too.
  useEffect(() => {
    if (!mobileOpen) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setMobileOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [mobileOpen])

  const onTouchStart = useCallback((event: React.TouchEvent) => {
    const touch = event.touches[0]
    touchStart.current = touch ? { x: touch.clientX, y: touch.clientY } : null
  }, [])

  // A swipe from the left edge opens the drawer; a swipe left closes it.
  const onTouchEnd = useCallback(
    (event: React.TouchEvent) => {
      const start = touchStart.current
      const touch = event.changedTouches[0]
      touchStart.current = null
      if (!start || !touch) return
      const dx = touch.clientX - start.x
      const dy = Math.abs(touch.clientY - start.y)
      if (dy > Math.abs(dx)) return
      if (!mobileOpen && start.x <= EDGE_PX && dx >= SWIPE_PX) setMobileOpen(true)
      else if (mobileOpen && dx <= -SWIPE_PX) setMobileOpen(false)
    },
    [mobileOpen],
  )

  return (
    <SidebarContext.Provider
      value={{
        open: sidebarOpen,
        setOpen: setSidebarOpen,
        mobileOpen,
        setMobileOpen,
      }}
    >
      <div
        className="relative flex h-dvh overflow-hidden bg-background pt-[env(safe-area-inset-top)] pr-[env(safe-area-inset-right)] pl-[env(safe-area-inset-left)]"
        onTouchEnd={onTouchEnd}
        onTouchStart={onTouchStart}
      >
        <Sidebar
          apiKeyStatus={apiKeyStatus}
          mobileOpen={mobileOpen}
          onMobileClose={() => setMobileOpen(false)}
          onToggle={() => setSidebarOpen((open) => !open)}
          open={sidebarOpen}
          sidebarChats={sidebarChats}
        />
        {/* The scrim behind the phone drawer. */}
        <div
          aria-hidden
          className={cn(
            'fixed inset-0 z-40 bg-black/40 transition-opacity duration-300 md:hidden',
            mobileOpen ? 'opacity-100' : 'pointer-events-none opacity-0',
          )}
          onClick={() => setMobileOpen(false)}
        />
        <main className="min-w-0 flex-1 overflow-hidden">{children}</main>
      </div>
    </SidebarContext.Provider>
  )
}
