import dayjs from 'dayjs'
import { PRDocBand, TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { ApiLoader } from '@/components/common/loading'
import PoOpenListModal from '../components/PoOpenListModal'
import { PoCancellationGrid } from '../components/po-cancellation/PoCancellationGrid'
import { usePoCancellation } from '../hooks/usePoCancellation'
import { formatPoNo } from '../types'

// ── PO Cancellation page (HTML po-cancellation/index.html, FSD v1.1) ────────
// Faithful conversion: toolbar (OK/Exit), PO-pick bar → picker modal, grid of
// open PO lines with per-row reason + cancel-qty, Yes/No confirm on OK.

export default function POCancellationPage() {
  usePageTitle('Purchase Order Cancellation')
  const processingDate = useAuthStore((s) => s.processingDate)
  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)

  const {
    pickerOpen, openPicker, closePicker,
    selectedPo, selectPo,
    reasons, lines, loadingLines,
    toggleRow, toggleAll, setReason, setCancelQty, blurCancelQty,
    focusRequest, clearFocusRequest,
    onOk, onExit,
    canSubmit,
  } = usePoCancellation()

  const subLabel = selectedPo ? 'Purchase Order' : 'Processing Date'
  const subValue = selectedPo
    ? `${formatPoNo(selectedPo.poNo)} · ${dayjs(selectedPo.poDate).format('DD-MMM-YYYY')}`
    : (processingDate ? dayjs(processingDate).format('DD MMM YYYY') : dayjs().format('DD MMM YYYY'))

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, height: '100%', minHeight: 0, overflow: 'hidden' }}>
      <PRDocBand
        breadcrumb={['Purchase Order', 'Purchase Order Cancellation']}
        subLabel={subLabel}
        subValue={subValue}
      />

      {/* Toolbar — FSD controls only: CmdOK, CmdExit */}
      <div style={{
        background: '#fff', borderBottom: '1px solid #E2E2E2',
        display: 'flex', alignItems: 'center', gap: 4, padding: '0 12px', height: 44, flexShrink: 0,
      }}>
        <TbBtn icon="✔" label="OK" variant="primary" disabled={!canSubmit} onClick={onOk} title="Validate, confirm and cancel selected lines" />
        <TbSep />
        <TbBtn icon="✕" label="Exit" onClick={onExit} title="Exit (Escape)" />
      </div>

      {/* PO selection bar — opens the shared PO picker modal */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12, padding: '8px 16px',
        background: '#fff', borderBottom: '1px solid #E2E2E2', flexShrink: 0,
      }}>
        <span style={{ fontSize: 11, fontWeight: 600, color: '#4a4a4a', whiteSpace: 'nowrap' }}>
          Purchase Order<span style={{ color: '#A32D2D', marginLeft: 1 }}>*</span>
        </span>
        <button
          type="button"
          onClick={openPicker}
          style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8,
            height: 30, width: 540, maxWidth: '60vw', padding: '0 10px',
            border: '1px solid #d0d0d0', borderRadius: 6, background: '#fff',
            fontSize: 12, fontFamily: 'inherit', textAlign: 'left', cursor: 'pointer',
            color: selectedPo ? '#1a1a1a' : '#888', fontWeight: selectedPo ? 600 : 400,
          }}
        >
          <span>{selectedPo ? `${formatPoNo(selectedPo.poNo)}  ·  ${dayjs(selectedPo.poDate).format('DD-MMM-YYYY')}  ·  ${selectedPo.supplierName}` : 'Search and select a Purchase Order…'}</span>
          <span style={{ color: '#888', fontSize: 10 }}>▼</span>
        </button>
      </div>

      {/* Grid section — no "Open PO Lines" header bar: it duplicated the footer's
          Total Lines count and cost the table a row of height. PR Foreclosure has
          no such bar either, so the header stack now matches it exactly. */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, background: '#F5F5F3' }}>
        {!selectedPo ? (
          <div style={{
            flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 6, color: '#888', padding: 40, textAlign: 'center',
          }}>
            <div style={{ fontSize: 34, opacity: 0.5 }}>🔍</div>
            <div style={{ fontSize: 13, fontWeight: 600, color: '#4a4a4a' }}>No Purchase Order selected</div>
            <div style={{ fontSize: 11, maxWidth: 340, lineHeight: 1.6 }}>
              Select a Purchase Order above to load its open lines for cancellation.
            </div>
          </div>
        ) : loadingLines ? (
          <ApiLoader message="Loading open PO lines…" />
        ) : (
          <PoCancellationGrid
            selectedPo={selectedPo}
            lines={lines}
            reasons={reasons}
            onToggleRow={toggleRow}
            onToggleAll={toggleAll}
            onReasonChange={setReason}
            onQtyChange={setCancelQty}
            onQtyBlur={blurCancelQty}
            focusRequest={focusRequest}
            onFocusHandled={clearFocusRequest}
          />
        )}
      </div>

      <PoOpenListModal
        open={pickerOpen}
        yfDate={yfDate}
        ylDate={ylDate}
        onSelect={selectPo}
        onClose={closePicker}
      />
    </div>
  )
}
