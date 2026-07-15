import { useCallback, useRef, useState } from 'react'
import { notifyError } from '@/shared/lib/notificationHelper'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { getPrintBlobUrl } from '../api/poTransferApi'
import type { PoApprovalLine } from '../types/poApprovalTypes'

// Shared across First/Second/Final Level Approval — GET /po/{poNo}/print is
// one real endpoint regardless of approval level, so this reuses the same
// call already wired for PR to PO Transfer (poTransferApi.getPrintBlobUrl)
// instead of duplicating the blob/loading/error plumbing three times.
export function usePoApprovalPrint() {
  const [printOpen,     setPrintOpen]     = useState(false)
  const [printLoading,  setPrintLoading]  = useState(false)
  const [printBlobUrl,  setPrintBlobUrl]  = useState<string | null>(null)
  const [printFilename, setPrintFilename] = useState('')
  const prevBlobUrlRef = useRef<string | null>(null)

  const revokePrev = () => {
    if (prevBlobUrlRef.current) {
      URL.revokeObjectURL(prevBlobUrlRef.current)
      prevBlobUrlRef.current = null
    }
  }

  const openPrint = useCallback(async (line: PoApprovalLine) => {
    revokePrev()
    setPrintBlobUrl(null)
    setPrintLoading(true)
    setPrintOpen(true)
    try {
      const { blobUrl, filename } = await getPrintBlobUrl(line.divCode, line.poNo, line.poDate)
      prevBlobUrlRef.current = blobUrl
      setPrintBlobUrl(blobUrl)
      setPrintFilename(filename)
    } catch (err) {
      setPrintOpen(false)
      notifyError(getErrorMessage(err))
    } finally {
      setPrintLoading(false)
    }
  }, [])

  const closePrint = useCallback(() => {
    setPrintOpen(false)
    revokePrev()
    setPrintBlobUrl(null)
  }, [])

  return { printOpen, printLoading, printBlobUrl, printFilename, openPrint, closePrint }
}
