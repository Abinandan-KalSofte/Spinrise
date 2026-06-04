import { useCallback, useEffect, useState } from 'react'
import { App } from 'antd'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'
import * as api from '../api/prCancellationApi'
import type {
  PrCancellablePrDto,
  PrForCancellationDetail,
  PrCancelledPrDto,
} from '../types'

export type CancelTab = 'cancel' | 'undo'

export function usePrCancellation() {
  const { modal, message } = App.useApp()
  const processingDate = useAuthStore((s) => s.processingDate)

  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)

  // ── Cancel tab ────────────────────────────────────────────────────────────
  const [activeTab,         setActiveTab]         = useState<CancelTab>('cancel')
  const [cancellableList,   setCancellableList]   = useState<PrCancellablePrDto[]>([])
  const [cancelModalOpen,   setCancelModalOpen]   = useState(false)
  const [selectedCancelPr,  setSelectedCancelPr]  = useState<PrForCancellationDetail | null>(null)
  const [cancelReason,      setCancelReason]      = useState('')
  const [cancelReasonError, setCancelReasonError] = useState<string | null>(null)
  const [isCancelling,      setIsCancelling]      = useState(false)
  const [cancelLoading,     setCancelLoading]     = useState(false)

  // ── Undo tab ──────────────────────────────────────────────────────────────
  const [cancelledList,   setCancelledList]   = useState<PrCancelledPrDto[]>([])
  const [undoModalOpen,   setUndoModalOpen]   = useState(false)
  const [selectedUndoPr,  setSelectedUndoPr]  = useState<PrCancelledPrDto | null>(null)
  const [isUndoing,       setIsUndoing]       = useState(false)
  const [undoLoading,     setUndoLoading]     = useState(false)

  const loadCancellable = useCallback(async () => {
    setCancelLoading(true)
    try {
      const data = await api.getCancellable(yfDate, ylDate)
      setCancellableList(data)
    } catch {
      void message.error('Failed to load eligible PRs.')
    } finally {
      setCancelLoading(false)
    }
  }, [yfDate, ylDate, message])

  const loadCancelled = useCallback(async () => {
    setUndoLoading(true)
    try {
      const data = await api.getCancelledForUndo(yfDate, ylDate)
      setCancelledList(data)
    } catch {
      void message.error('Failed to load cancelled PRs.')
    } finally {
      setUndoLoading(false)
    }
  }, [yfDate, ylDate, message])

  useEffect(() => { void loadCancellable() }, [loadCancellable])

  const openCancelModal = () => {
    void loadCancellable()
    setCancelModalOpen(true)
  }

  const closeCancelModal = () => setCancelModalOpen(false)

  const selectPrToCancel = async (pr: PrCancellablePrDto) => {
    closeCancelModal()
    try {
      const detail = await api.getPRDetail(pr.prNo, pr.prDate, pr.depCode)
      setSelectedCancelPr(detail)
      setCancelReason('')
      setCancelReasonError(null)
    } catch {
      void message.error('Failed to load PR details.')
    }
  }

  const onReasonChange = (v: string) => {
    setCancelReason(v)
    if (v.trim()) setCancelReasonError(null)
  }

  const doCancel = async () => {
    if (!selectedCancelPr) return
    if (!cancelReason.trim()) {
      setCancelReasonError('Cancellation reason is required.')
      return
    }
    const { header } = selectedCancelPr
    const prTag = `PR-${String(header.prNo).padStart(5, '0')}`

    modal.confirm({
      title:   'Confirm PR Cancellation',
      icon:    null,
      content: `Cancelling ${prTag} (${header.department}). This will set CANCELFLAG='Y' and PRSTATUS='X' on all lines. This action can be undone within the current financial year.`,
      okText:  'Cancel This PR',
      okButtonProps: { danger: true },
      cancelText: 'Go Back',
      onOk: async () => {
        setIsCancelling(true)
        try {
          await api.cancelPR(header.prNo, header.prDate, header.depCode, cancelReason.trim())
          void message.success(`${prTag} cancelled. Audit written to LogDet_PO.`)
          reset()
          await loadCancellable()
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : 'Cancellation failed.'
          void message.error(msg)
        } finally {
          setIsCancelling(false)
        }
      },
    })
  }

  const openUndoModal = () => {
    void loadCancelled()
    setUndoModalOpen(true)
  }

  const closeUndoModal = () => setUndoModalOpen(false)

  const selectPrToUndo = (pr: PrCancelledPrDto) => {
    closeUndoModal()
    setSelectedUndoPr(pr)
  }

  const doUndo = async () => {
    if (!selectedUndoPr) return
    const prTag = `PR-${String(selectedUndoPr.prNo).padStart(5, '0')}`

    modal.confirm({
      title:   'Confirm Undo Cancellation',
      icon:    null,
      content: `Restoring ${prTag} (${selectedUndoPr.department}) from Cancelled back to ${selectedUndoPr.prevStatus || 'previous'} status. Restricted to current FY.`,
      okText:  '↩ Restore PR',
      okButtonProps: { style: { background: '#BA7517', borderColor: '#BA7517' } },
      cancelText: 'Go Back',
      onOk: async () => {
        setIsUndoing(true)
        try {
          await api.undoCancellation(selectedUndoPr.prNo, selectedUndoPr.prDate, selectedUndoPr.depCode, selectedUndoPr.rowVersion)
          void message.success(`${prTag} restored. Audit written to LogDet_PO.`)
          reset()
          await loadCancellable()
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : 'Undo failed.'
          void message.error(msg)
        } finally {
          setIsUndoing(false)
        }
      },
    })
  }

  const switchTab = (tab: CancelTab) => {
    setActiveTab(tab)
    if (tab === 'undo' && !selectedUndoPr) {
      setTimeout(() => openUndoModal(), 100)
    }
    if (tab === 'cancel' && !selectedCancelPr) {
      setTimeout(() => openCancelModal(), 100)
    }
  }

  const reset = () => {
    setSelectedCancelPr(null)
    setCancelReason('')
    setCancelReasonError(null)
    setSelectedUndoPr(null)
  }

  return {
    activeTab, switchTab,
    // Cancel
    cancellableList, cancelLoading,
    cancelModalOpen, openCancelModal, closeCancelModal,
    selectedCancelPr, selectPrToCancel,
    cancelReason, onReasonChange, cancelReasonError,
    isCancelling, doCancel,
    // Undo
    cancelledList, undoLoading,
    undoModalOpen, openUndoModal, closeUndoModal,
    selectedUndoPr, selectPrToUndo,
    isUndoing, doUndo,
    // Shared
    reset,
  }
}
