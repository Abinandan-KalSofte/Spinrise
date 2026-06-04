import { useEffect } from 'react'
import { App } from 'antd'
import { PRDocBand, TbBtn, TbSep } from '../components/pr-form/PRToolbar'
import CancelSubTab    from '../components/cancellation/CancelSubTab'
import UndoSubTab      from '../components/cancellation/UndoSubTab'
import CancelPickerModal from '../components/cancellation/CancelPickerModal'
import UndoPickerModal   from '../components/cancellation/UndoPickerModal'
import { usePrCancellation } from '../hooks/usePrCancellation'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import dayjs from 'dayjs'

export default function PrCancellationPage() {
  const processingDate = useAuthStore((s) => s.processingDate)
  const today = processingDate
    ? dayjs(processingDate).format('DD MMM YYYY')
    : dayjs().format('DD MMM YYYY')

  const {
    activeTab, switchTab,
    cancellableList, cancelLoading,
    cancelModalOpen, openCancelModal, closeCancelModal,
    selectedCancelPr, selectPrToCancel,
    cancelReason, onReasonChange, cancelReasonError,
    isCancelling, doCancel,
    cancelledList, undoLoading,
    undoModalOpen, openUndoModal, closeUndoModal,
    selectedUndoPr, selectPrToUndo,
    isUndoing, doUndo,
    reset,
  } = usePrCancellation()

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'F3') {
        e.preventDefault()
        if (activeTab === 'cancel') openCancelModal()
        else openUndoModal()
      }
      if (e.ctrlKey && e.key === 's') {
        e.preventDefault()
        if (activeTab === 'cancel') void doCancel()
        else void doUndo()
      }
      if (e.altKey && e.key === 'x') {
        e.preventDefault()
        reset()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [activeTab, openCancelModal, openUndoModal, doCancel, doUndo, reset])

  const subLabel = selectedCancelPr && activeTab === 'cancel'
    ? 'PR Number'
    : 'Processing Date'
  const subValue = selectedCancelPr && activeTab === 'cancel'
    ? `PR-${String(selectedCancelPr.header.prNo).padStart(5, '0')}`
    : today

  return (
    <App>
      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, height: '100%', minHeight: 0, overflow: 'hidden' }}>

        <PRDocBand
          title="Purchase Requisition Cancellation"
          breadcrumb={['Purchase Order', 'Purchase Requisition Cancellation']}
          subLabel={subLabel}
          subValue={subValue}
        />

        {/* Toolbar */}
        <div style={{
          background: '#fff', borderBottom: '1px solid #E2E2E2',
          display: 'flex', alignItems: 'center', gap: 4, padding: '0 12px', height: 44, flexShrink: 0,
        }}>
          {activeTab === 'cancel' ? (
            <>
              <TbBtn icon="🔍" label="Find PR to Cancel"  kbd="F3"     variant="primary"       onClick={openCancelModal} />
              <TbSep />
              <TbBtn icon="🚫" label="Cancel PR"          kbd="Ctrl+S" variant={selectedCancelPr ? 'danger-filled' : 'default'} onClick={() => void doCancel()} disabled={!selectedCancelPr || isCancelling} />
            </>
          ) : (
            <>
              <TbBtn icon="🔍" label="Find Cancelled PR"  kbd="F3"     variant="primary"       onClick={openUndoModal} />
              <TbSep />
              <TbBtn icon="↩"  label="Undo Cancellation"  kbd="Ctrl+S" variant={selectedUndoPr ? 'amber' : 'default'} onClick={() => void doUndo()} disabled={!selectedUndoPr || isUndoing} />
            </>
          )}
          <TbSep />
          <TbBtn icon="✕" label="Cancel" kbd="Alt+X" onClick={reset} />
        </div>

        {/* Sub-tabs */}
        <div style={{
          background: '#FAFAF8', borderBottom: '1px solid #E2E2E2',
          display: 'flex', alignItems: 'center', padding: '0 16px', flexShrink: 0, gap: 2,
        }}>
          {(['cancel', 'undo'] as const).map(tab => (
            <button
              key={tab}
              onClick={() => switchTab(tab)}
              style={{
                padding: '9px 16px',
                border: '1px solid transparent', borderBottom: 'none',
                borderRadius: '6px 6px 0 0', marginBottom: -1,
                fontSize: 12, fontWeight: 600, cursor: 'pointer',
                color:      activeTab === tab ? '#185FA5' : '#888',
                background: activeTab === tab ? '#fff'    : 'transparent',
                borderColor: activeTab === tab ? '#E2E2E2' : 'transparent',
                fontFamily: 'inherit',
              }}
            >
              {tab === 'cancel' ? '🚫 Cancel PR' : '↩ Undo Cancellation'}
            </button>
          ))}
        </div>

        {/* Sub-tab body */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, overflow: 'hidden', background: '#F5F5F3' }}>
          {activeTab === 'cancel' ? (
            <CancelSubTab
              detail={selectedCancelPr}
              cancelReason={cancelReason}
              cancelReasonErr={cancelReasonError}
              onReasonChange={onReasonChange}
            />
          ) : (
            <UndoSubTab pr={selectedUndoPr} />
          )}
        </div>

        <CancelPickerModal
          open={cancelModalOpen}
          list={cancellableList}
          loading={cancelLoading}
          onSelect={selectPrToCancel}
          onClose={closeCancelModal}
        />
        <UndoPickerModal
          open={undoModalOpen}
          list={cancelledList}
          loading={undoLoading}
          onSelect={selectPrToUndo}
          onClose={closeUndoModal}
        />
      </div>
    </App>
  )
}
