'use client'

import type { Chat } from '@v0-sdk/react'
import { useChats, useChatsInfinite } from '@v0-sdk/react/swr'
import { Suspense, use, useEffect, useState } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { Button } from '@/components/ui/button'
import { ChatItem } from '@/components/layout/chat-item'
import { ApiKeyDialog } from '@/components/layout/api-key-dialog'
import type { getSidebarChats } from '@/lib/sidebar-chats'
import { cn } from '@/lib/utils'
import { ChevronDownIcon, ChevronRightIcon, CrossIcon, SidebarToggleIcon } from '@/lib/icons'

type SidebarProps = {
  open: boolean
  /** A phone: the drawer is out. */
  mobileOpen: boolean
  onMobileClose: () => void
  apiKeyStatus: {
    hasBrowserApiKey: boolean
    hasEnvironmentApiKey: boolean
  }
  onToggle: () => void
  sidebarChats: ReturnType<typeof getSidebarChats>
}

export function Sidebar(props: SidebarProps) {
  return (
    <Suspense
      fallback={
        <SidebarSkeleton
          apiKeyStatus={props.apiKeyStatus}
          mobileOpen={props.mobileOpen}
          onToggle={props.onToggle}
          open={props.open}
        />
      }
    >
      <SidebarContent {...props} />
    </Suspense>
  )
}

/** The aside: beside the page on a wide screen; on a phone, a drawer over it
 *  that slides in from the left. */
function asideClass(open: boolean, mobileOpen: boolean) {
  return cn(
    'flex shrink-0 flex-col gap-1 overflow-hidden bg-sidebar',
    'fixed inset-y-0 left-0 z-50 w-[85vw] max-w-80 pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)] transition-[translate,visibility] duration-300 ease-out',
    // Shut, it slides out, then leaves the tab order and the screen reader;
    // its shadow shows only while it is out.
    mobileOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full max-md:invisible',
    'md:static md:z-auto md:max-w-none md:translate-x-0 md:pt-0 md:pb-0 md:shadow-none md:transition-[width] md:duration-200',
    open ? 'md:w-64 md:border-r md:border-sidebar-border' : 'md:w-0',
  )
}

function SidebarSkeleton({
  open,
  mobileOpen,
  apiKeyStatus,
  onToggle,
}: Pick<SidebarProps, 'open' | 'mobileOpen' | 'apiKeyStatus' | 'onToggle'>) {
  return (
    <aside aria-busy="true" aria-label="Loading sidebar" className={asideClass(open, mobileOpen)}>
      {open || mobileOpen ? (
        <div className="flex w-full flex-1 flex-col gap-1 overflow-y-auto p-3 md:w-64 md:p-2">
          <div className="mb-1 flex items-center gap-1">
            <div className="flex min-w-0 flex-1 items-center gap-2 rounded-md px-1.5 py-1 text-sm font-medium text-sidebar-foreground">
              <img src="/acme-logo.svg" alt="" width={24} height={24} className="size-6 shrink-0" />
              <span className="truncate">Acme Team</span>
              <ChevronDownIcon className="ml-auto size-3.5 text-muted-foreground" />
            </div>

            <Button
              aria-label="Collapse sidebar"
              className="hidden size-8 shrink-0 text-muted-foreground md:inline-flex"
              onClick={onToggle}
              size="icon"
              variant="ghost"
            >
              <SidebarToggleIcon size={18} />
            </Button>
          </div>

          <button
            className="flex items-center justify-center rounded-xl border border-sidebar-border bg-background px-3 py-2.5 text-[15px] font-medium text-sidebar-foreground shadow-sm transition-colors hover:bg-accent active:scale-[0.99] md:rounded-lg md:py-1.5 md:text-sm"
            onClick={() => window.location.assign('/')}
            type="button"
          >
            New Chat
          </button>

          <div className="mt-4">
            <div className="flex items-center gap-1 px-2.5 py-1 text-xs font-medium text-muted-foreground">
              <span className="flex-1">Favorites</span>
              <ChevronRightIcon className="size-3.5 rotate-90" />
            </div>
            <ChatNamesSkeleton />
          </div>

          <div className="mt-2">
            <div className="flex items-center gap-1 px-2.5 py-1 text-xs font-medium text-muted-foreground">
              <span className="flex-1">Recent Chats</span>
              <ChevronDownIcon className="size-3.5" />
            </div>
            <ChatNamesSkeleton />
            <ChatNamesSkeleton />
          </div>

          <div className="flex-1" />
          <ApiKeyDialog {...apiKeyStatus} />
        </div>
      ) : null}
    </aside>
  )
}

function ChatNamesSkeleton() {
  return (
    <div className="animate-pulse px-2.5 py-1.5">
      <div className="h-3 w-3/4 rounded bg-muted" />
    </div>
  )
}

function SidebarContent({
  open,
  mobileOpen,
  onMobileClose,
  apiKeyStatus,
  onToggle,
  sidebarChats,
}: SidebarProps) {
  const initialChats = use(sidebarChats)
  const pathname = usePathname()
  const router = useRouter()
  const [favoritesOpen, setFavoritesOpen] = useState(initialChats.favoriteChats.length > 0)
  const favoritesQuery = useChats(
    '/api/chats',
    {
      limit: 5,
      metadata: { favorite: 'true' },
    },
    {
      fallbackData: {
        chats: initialChats.favoriteChats,
        cursor: null,
      },
      revalidateOnMount: false,
    },
  )
  const recentQuery = useChatsInfinite(
    '/api/chats',
    { limit: 5 },
    {
      fallbackData: [initialChats.recentChats],
      revalidateOnMount: false,
    },
  )
  const favoriteChats = favoritesQuery.data?.chats ?? initialChats.favoriteChats
  const recentPages = recentQuery.data ?? [initialChats.recentChats]
  const recentChats = recentPages
    .flatMap((page) => page.chats)
    .filter((chat) => chat.metadata.favorite !== 'true')
  const recentCursor = recentPages.at(-1)?.cursor
  const isLoadingMore = recentQuery.isValidating

  useEffect(() => {
    void favoritesQuery.mutate(
      { chats: initialChats.favoriteChats, cursor: null },
      { revalidate: false },
    )
    void recentQuery.mutate([initialChats.recentChats], {
      revalidate: false,
    })
  }, [initialChats])

  const renderItem = (chat: Chat) => (
    <ChatItem
      chat={chat}
      isActive={pathname === `/chats/${chat.id}`}
      key={chat.id}
      onFavoriteAdded={() => setFavoritesOpen(true)}
      onDeleted={handleDeleted}
    />
  )

  function handleDeleted(id: string) {
    if (pathname === `/chats/${id}`) router.push('/')
  }

  const handleLoadMore = () => {
    if (!recentCursor) return
    void recentQuery.setSize((size) => size + 1)
  }

  return (
    <aside aria-label="Chats" className={asideClass(open, mobileOpen)}>
      {open || mobileOpen ? (
        <div className="flex w-full flex-1 flex-col gap-1 overflow-y-auto overscroll-contain p-3 md:w-64 md:p-2">
          <div className="mb-1 flex items-center gap-1">
            <div className="flex min-w-0 flex-1 items-center gap-2 rounded-md px-1.5 py-1 text-sm font-medium text-sidebar-foreground">
              <img src="/acme-logo.svg" alt="" width={24} height={24} className="size-6 shrink-0" />
              <span className="truncate">Acme Team</span>
              <ChevronDownIcon className="ml-auto size-3.5 text-muted-foreground" />
            </div>

            <Button
              aria-label="Collapse sidebar"
              className="hidden size-8 shrink-0 text-muted-foreground md:inline-flex"
              onClick={onToggle}
              size="icon"
              variant="ghost"
            >
              <SidebarToggleIcon size={18} />
            </Button>
            <Button
              aria-label="Close chats"
              className="size-10 shrink-0 text-muted-foreground md:hidden"
              onClick={onMobileClose}
              size="icon"
              variant="ghost"
            >
              <CrossIcon size={20} />
            </Button>
          </div>

          <button
            className="flex items-center justify-center rounded-xl border border-sidebar-border bg-background px-3 py-2.5 text-[15px] font-medium text-sidebar-foreground shadow-sm transition-colors hover:bg-accent active:scale-[0.99] md:rounded-lg md:py-1.5 md:text-sm"
            onClick={() => window.location.assign('/')}
            type="button"
          >
            New Chat
          </button>

          {/* Favorites */}
          <Collapsible className="mt-4" onOpenChange={setFavoritesOpen} open={favoritesOpen}>
            <CollapsibleTrigger className="group flex w-full items-center gap-1 px-2.5 py-2 text-[13px] font-medium text-muted-foreground md:py-1 md:text-xs">
              <span className="flex-1 text-left">Favorites</span>
              <ChevronRightIcon className="size-3.5 transition-transform group-data-[state=open]:rotate-90" />
            </CollapsibleTrigger>
            <CollapsibleContent className="flex flex-col gap-0.5">
              {favoriteChats.length === 0 ? (
                <p className="px-2.5 py-1 text-xs text-muted-foreground">No favorites yet</p>
              ) : (
                favoriteChats.map(renderItem)
              )}
            </CollapsibleContent>
          </Collapsible>

          {/* Recent Chats */}
          <Collapsible className="mt-2" defaultOpen>
            <CollapsibleTrigger className="group flex w-full items-center gap-1 px-2.5 py-2 text-[13px] font-medium text-muted-foreground md:py-1 md:text-xs">
              <span className="flex-1 text-left">Recent Chats</span>
              <ChevronDownIcon className="size-3.5 transition-transform group-data-[state=closed]:-rotate-90" />
            </CollapsibleTrigger>
            <CollapsibleContent className="flex flex-col gap-0.5">
              {recentChats.length === 0 ? (
                <p className="px-2.5 py-1 text-xs text-muted-foreground">No chats yet</p>
              ) : (
                recentChats.map(renderItem)
              )}
              {recentCursor ? (
                <button
                  className="px-2.5 py-1.5 text-left text-xs text-muted-foreground transition-colors hover:text-sidebar-foreground disabled:opacity-50"
                  disabled={isLoadingMore}
                  onClick={handleLoadMore}
                  type="button"
                >
                  {isLoadingMore ? 'Loading…' : 'Load more'}
                </button>
              ) : null}
            </CollapsibleContent>
          </Collapsible>

          <div className="flex-1" />
          <ApiKeyDialog {...apiKeyStatus} />
        </div>
      ) : null}
    </aside>
  )
}
