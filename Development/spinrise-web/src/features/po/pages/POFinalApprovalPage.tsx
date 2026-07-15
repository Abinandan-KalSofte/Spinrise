import { useCallback, useEffect, useRef, useState } from 'react'
import { Modal } from 'antd'
import { CheckOutlined, CloseOutlined, ReloadOutlined } from '@ant-design/icons'
import { ApiLoader } from '@/components/common/loading'
import { notifyError, notifySuccess, notifyWarning, notifyInfo } from '@/shared/lib/notificationHelper'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { usePageReset } from '@/shared/hooks/usePageReset'
import { PRDocBand, TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'
import {
  usePoFinalApprovalStore,
  selectSelectedLines,
  selectPendingCount,
} from '../store/usePoFinalApprovalStore'
import { poFinalApprovalApi } from '../api/poFinalApprovalApi'
import { usePoApprovalPrint } from '../hooks/usePoApprovalPrint'
import { PrPrintPreviewModal } from '@/features/pr/components/PrPrintPreviewModal'
import PoApprovalFilterBar from '../components/po-approval/PoApprovalFilterBar'
import PoApprovalGrid from '../components/po-approval/PoApprovalGrid'
import PoApprovalFooter from '../components/po-approval/PoApprovalFooter'
import PoApprovalConfirmSaveModal from '../components/po-approval/PoApprovalConfirmSaveModal'
import { DISPOSITION_LABELS, type DispositionCode } from '../types/poApprovalTypes'

// ── PO Final Level Approval page ────────────────────────────────────────────
// Faithful conversion of po-final-level.html (FSD v1.1 Stage 4, CR build
// 03-Jul-2026, POT-POA-01…09).
//
// Final Level is a GROUPED view (FSD §10.2, CEO Decision 1) — the mock data
// carries `lineCount`/`poValue` aggregates instead of `lines[]`; the shared
// Grid/Footer/ConfirmModal/PrintModal (components/po-approval/) already
// handle this via the optional fields on PoApprovalLine, so no new UI
// components were needed here — only level-specific props/text and the
// per-PO cascade toast on save (CEO Decision 1).

const DISP_TOAST_FN = {
  1: notifyInfo, 2: notifySuccess, 3: notifyWarning, 4: notifyError, 5: notifyInfo,
} as const satisfies Record<DispositionCode, (msg: string, title?: string) => void>

const PRESERVED_FLAGS_NOTE =
  "F ✓ S ✓ First & Second approvals preserved as audit history — only Final flag (conflg) reset (CEO Decision 4)"

export default function POFinalApprovalPage() {
  usePageTitle('PO Final Level Approval')

  const {
    lines, gridLoaded, loading, saving, filter, divisions,
    loadDivisions, loadGrid, setFilter, refresh, cancelSelections,
    updateDisposition, updateRemarks, updatePostponeDate, toggleRow, toggleAll,
    executeSave, auditNoteVisible, setSaving,
  } = usePoFinalApprovalStore()

  usePageReset(usePoFinalApprovalStore.getState().reset)

  const [confirmOpen, setConfirmOpen] = useState(false)
  const { printOpen, printLoading, printBlobUrl, printFilename, openPrint, closePrint } = usePoApprovalPrint()

  const selectedLines = selectSelectedLines(lines)
  const pendingCount  = selectPendingCount(lines)

  useEffect(() => { void loadDivisions() }, [loadDivisions])

  const handleLoad = useCallback(async () => {
    try {
      await loadGrid()
    } catch (e: unknown) {
      notifyError(getErrorMessage(e))
    }
  }, [loadGrid])

  const handleRefresh = useCallback(async () => {
    try {
      await refresh()
      notifyInfo('List refreshed — approved POs completed the chain, declined POs closed.')
    } catch (e: unknown) {
      notifyError(getErrorMessage(e))
    }
  }, [refresh])

  const handleCancel = useCallback(() => {
    cancelSelections()
    notifyInfo('Cancelled — selections and reasons cleared.')
  }, [cancelSelections])

  // Save flow — Confirm dialog always appears on Save; reason entry inside it
  // is only mandatory for Hold/Declined/Postpone lines.
  // CEO Decision 1 — one toast PER PO naming the cascaded line count,
  // instead of a single combined summary toast (unlike First/Second Level).
  const runSave = useCallback(async () => {
    setConfirmOpen(false)
    setSaving(true)
    const actioned = selectedLines.map((l) => ({ pordno: l.pordno, disposition: l.disposition, lineCount: l.lineCount ?? 0 }))
    try {
      const result = await poFinalApprovalApi.saveActions({
        items: selectedLines.map((l) => ({
          pordno: l.pordno, divCode: l.divCode, poNo: l.poNo, poDate: l.poDate,
          disposition: l.disposition, remarks: l.remarks, postponeDate: l.postponeDate,
        })),
      })
      executeSave(result)
      actioned.forEach((a) => {
        if (!result.saved.includes(a.pordno)) return
        const toast = DISP_TOAST_FN[a.disposition]
        toast(`${DISPOSITION_LABELS[a.disposition]} — action applied to all ${a.lineCount} lines of ${a.pordno} (header-level cascade)`)
      })
      // Reload line values from the backend so totals/KPIs/statuses/pending
      // count reflect the server's authoritative post-save state, not just
      // the optimistic local mutation from executeSave.
      await refresh()
    } catch (e: unknown) {
      notifyError(getErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }, [selectedLines, executeSave, refresh, setSaving])

  const handleSaveClick = useCallback(() => {
    if (selectedLines.length === 0) {
      Modal.info({
        title: 'No Records Selected',
        content: 'No purchase orders are selected to action. Please check at least one PO row before saving.',
      })
      return
    }
    setConfirmOpen(true)
  }, [selectedLines])

  // Ref keeps Ctrl+S pointing at the latest handler without re-binding the listener.
  const handleSaveClickRef = useRef(handleSaveClick)
  useEffect(() => { handleSaveClickRef.current = handleSaveClick }, [handleSaveClick])

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
        e.preventDefault()
        handleSaveClickRef.current()
      }
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>

      <PRDocBand
        breadcrumb={['Purchase Order', 'Purchase Order Final Level Approval']}
        subLabel="Pending POs"
        subValue={gridLoaded ? String(pendingCount) : '—'}
      />

      <div style={{
        background: '#fff', borderBottom: '1px solid #E2E2E2',
        display: 'flex', alignItems: 'center', gap: 4, padding: '0 12px', height: 44, flexShrink: 0,
      }}>
        <TbBtn icon={<ReloadOutlined style={{ fontSize: 11 }} />} label="Refresh" onClick={() => void handleRefresh()} />
        <TbSep />
        <TbBtn
          variant="success"
          icon={<CheckOutlined style={{ fontSize: 11 }} />}
          label="Save" kbd="Ctrl+S"
          disabled={selectedLines.length === 0 || saving}
          onClick={handleSaveClick}
        />
        <TbBtn
          icon={<CloseOutlined style={{ fontSize: 11 }} />}
          label="Cancel"
          disabled={!gridLoaded}
          onClick={handleCancel}
        />
      </div>

      <PoApprovalFilterBar
        filter={filter} divisions={divisions} setFilter={setFilter}
        onLoad={() => void handleLoad()} loading={loading}
      />

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: '#fff' }}>
        {!gridLoaded && !loading ? (
          <div style={{
            flex: 1, display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center', gap: 10,
          }}>
            <div style={{ fontSize: 36, opacity: 0.3 }}>📋</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#888' }}>No Data Loaded</div>
            <div style={{ fontSize: 12, color: '#888', textAlign: 'center', maxWidth: 420, lineHeight: 1.7 }}>
              Select a Division, then click <strong>Load</strong> to fetch purchase orders pending Final Level approval.
            </div>
          </div>
        ) : loading ? (
          <ApiLoader message="Loading pending purchase orders…" />
        ) : (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '8px 16px',
              borderBottom: '1px solid #E2E8F0', background: '#F8FAFD', flexShrink: 0, flexWrap: 'wrap',
            }}>
              <span style={{ fontSize: 12, fontWeight: 600, color: '#4A4A4A' }}>Pending Final Level Approval</span>
              <span style={{
                fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 20,
                background: '#E6F1FB', color: '#185FA5',
              }}>
                {lines.length} PO{lines.length !== 1 ? 's' : ''}
              </span>
              {auditNoteVisible && (
                <span style={{ fontSize: 10, color: '#888', marginLeft: 'auto', whiteSpace: 'nowrap' }}>
                  🛈 Audit: user, IP, host, level recorded in LogDet_PO
                </span>
              )}
            </div>

            <PoApprovalGrid
              lines={lines}
              updateDisposition={updateDisposition}
              toggleRow={toggleRow}
              toggleAll={toggleAll}
              onPrint={(line) => void openPrint(line)}
              levelLabel="final level"
              approvedChipText="Approved · conflg = 'Y'"
              preservedFlagsNote={PRESERVED_FLAGS_NOTE}
            />
          </div>
        )}
      </div>

      {gridLoaded && <PoApprovalFooter lines={lines} />}

      <PoApprovalConfirmSaveModal
        lines={lines}
        updateRemarks={updateRemarks}
        updatePostponeDate={updatePostponeDate}
        open={confirmOpen}
        title="Confirm Final Level Actions"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={() => void runSave()}
      />
      <PrPrintPreviewModal
        open={printOpen}
        blobUrl={printBlobUrl}
        filename={printFilename}
        loading={printLoading}
        onClose={closePrint}
      />
    </div>
  )
}
