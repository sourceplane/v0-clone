'use client'

import type { Files } from '@v0-sdk/react'
import { useFiles, useUpdateChatFiles } from '@v0-sdk/react/swr'
import { use, useState } from 'react'
import { Loader } from '@/components/ai-elements/loader'
import { Button } from '@/components/ui/button'
import { FileIcon, SpinnerIcon } from '@/lib/icons'
import { cn } from '@/lib/utils'

type ChatFile = Files['files'][number]
export type ChatFilesResult = { files: Files['files'] } | { error: string }

export function CodeEditorLoading() {
  return (
    <div className="flex h-full items-center justify-center gap-2 text-sm text-muted-foreground">
      <Loader size={16} /> Loading files…
    </div>
  )
}

export function CodeEditorPane({
  chatId,
  filesPromise,
  isPreviewReady,
}: {
  chatId: string
  filesPromise: Promise<ChatFilesResult>
  isPreviewReady: boolean
}) {
  const result = use(filesPromise)

  if ('error' in result) {
    return (
      <div className="flex h-full items-center justify-center px-6 text-sm text-destructive">
        {result.error}
      </div>
    )
  }

  return <CodeEditor chatId={chatId} files={result.files} isPreviewReady={isPreviewReady} />
}

function CodeEditor({
  chatId,
  files: initialFiles,
  isPreviewReady,
}: {
  chatId: string
  files: ChatFile[]
  isPreviewReady: boolean
}) {
  const filesUrl = `/api/chats/${encodeURIComponent(chatId)}/files`
  const filesQuery = useFiles(filesUrl, {
    fallbackData: { files: initialFiles },
    revalidateOnMount: false,
  })
  const updateFiles = useUpdateChatFiles(filesUrl)
  const cachedFiles = filesQuery.data?.files ?? initialFiles
  const [files, setFiles] = useState(cachedFiles)
  const [savedFiles, setSavedFiles] = useState(cachedFiles)
  const [selectedPath, setSelectedPath] = useState(
    cachedFiles.find((file) => file.encoding === 'utf8')?.path ?? cachedFiles[0]?.path ?? null,
  )
  const [status, setStatus] = useState<string | null>(null)
  const isSaving = updateFiles.isMutating
  const selectedFile = files.find((file) => file.path === selectedPath)
  const changedFiles = files.filter((file) => {
    if (file.encoding !== 'utf8') return false
    return savedFiles.find((saved) => saved.path === file.path)?.content !== file.content
  })

  const updateSelectedFile = (content: string) => {
    setStatus(null)
    setFiles((current) =>
      current.map((file) => (file.path === selectedPath ? { ...file, content } : file)),
    )
  }

  const save = async () => {
    if (changedFiles.length === 0 || !isPreviewReady) return

    setStatus(null)

    try {
      await updateFiles.trigger({
        files: changedFiles.map(({ path, content }) => ({ path, content })),
      })
      setSavedFiles(files)
      setStatus('Saved')
    } catch (error) {
      setStatus(error instanceof Error ? error.message : 'Failed to save files.')
    }
  }

  if (files.length === 0) {
    return (
      <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
        No files yet.
      </div>
    )
  }

  return (
    // A phone: the files are a row of chips above the editor; a wide screen:
    // a list beside it.
    <div className="flex h-full min-h-0 flex-col bg-background md:flex-row">
      <aside
        aria-label="Files"
        className="flex shrink-0 gap-1.5 overflow-x-auto border-b border-border p-2 md:block md:w-52 md:overflow-x-hidden md:overflow-y-auto md:border-r md:border-b-0"
      >
        {files.map((file) => (
          <button
            className={cn(
              'flex max-w-[70vw] shrink-0 items-center gap-2 rounded-full border border-border px-3 py-1.5 text-left text-[13px] text-muted-foreground hover:bg-accent hover:text-foreground md:w-full md:max-w-none md:rounded-md md:border-0 md:px-2 md:text-xs',
              file.path === selectedPath && 'bg-accent text-foreground',
            )}
            key={file.path}
            onClick={() => setSelectedPath(file.path)}
            title={file.path}
            type="button"
          >
            <FileIcon className="size-3.5 shrink-0" />
            <span className="truncate">{file.path}</span>
          </button>
        ))}
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex h-10 shrink-0 items-center gap-3 border-b border-border px-3">
          <span className="min-w-0 flex-1 truncate text-xs text-muted-foreground">
            {selectedFile?.path}
          </span>
          {status ? (
            <span
              className={cn(
                'text-xs',
                status === 'Saved' ? 'text-muted-foreground' : 'text-destructive',
              )}
            >
              {status}
            </span>
          ) : null}
          <Button
            disabled={changedFiles.length === 0 || isSaving || !isPreviewReady}
            className="max-md:h-8 max-md:px-3 max-md:text-sm"
            onClick={save}
            size="xs"
            title={isPreviewReady ? undefined : 'Preview is still loading'}
          >
            {isSaving ? <SpinnerIcon className="size-3 animate-spin" /> : null}
            {isSaving ? 'Saving' : 'Save'}
          </Button>
        </div>

        {selectedFile?.encoding === 'utf8' ? (
          <textarea
            aria-label={`Edit ${selectedFile.path}`}
            className="min-h-0 flex-1 resize-none bg-background p-4 font-mono text-base leading-6 text-foreground outline-none md:text-xs md:leading-5"
            disabled={isSaving}
            onChange={(event) => updateSelectedFile(event.target.value)}
            spellCheck={false}
            value={selectedFile.content}
          />
        ) : (
          <div className="flex flex-1 items-center justify-center text-sm text-muted-foreground">
            Binary files cannot be edited.
          </div>
        )}
      </div>
    </div>
  )
}
