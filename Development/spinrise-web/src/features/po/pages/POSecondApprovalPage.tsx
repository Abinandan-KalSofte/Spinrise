import { useCallback, useEffect, useRef, useState } from 'react'
import { Modal } from 'antd'
import { CheckOutlined, CloseOutlined, ReloadOutlined } from '@ant-design/icons'
import { ApiLoader } from '@/components/common/loading'
import { notifyError, notifySuccess, notifyInfo } from '@/shared/lib/notificationHelper'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { usePageReset } from '@/shared/hooks/usePageReset'
import { PRDocBand, TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'
import {
  usePoSecondApprovalStore,
  selectSelectedLines,
  selectPendingCount,
} from '../store/usePoSecondApprovalStore'
import { poSecondApprovalApi } from '../api/poSecondApprovalApi'
import { usePoApprovalPrint } from '../hooks/usePoApprovalPrint'
import { PrPrintPreviewModal } from '@/features/pr/components/PrPrintPreviewModal'
import PoApprovalFilterBar from '../components/po-approval/PoApprovalFilterBar'
import PoApprovalGrid from '../components/po-approval/PoApprovalGrid'
import PoApprovalFooter from '../components/po-approval/PoApprovalFooter'
import PoApprovalConfirmSaveModal from '../components/po-approval/PoApprovalConfirmSaveModal'

// ── PO Second Level Approval page ───────────────────────────────────────────
// Faithful conversion of po-second-level.html (FSD v1.1 Stage 4, CR build
// 03-Jul-2026, POT-POA-01…09). Business logic (division/pending-PO lookup,
// save) is placeholder-only — dummy data, no real backend exists yet (see
// poSecondApprovalApi.ts). Unlike First Level, this prototype has NO CD-08
// concurrency-conflict banner — omitted here to match exactly, not just
// left dormant. FSD §3.1's "level switched off per customer" behaviour
// (po_para.PoSecondLevelApp='N') needs no special-case UI: an empty API
// result renders the same silent empty state below regardless of why the
// queue is empty. Grid/Footer/ConfirmModal/PrintModal/FilterBar are shared
// with First/Final Level (components/po-approval/) to avoid duplicating
// ~90%-identical UI across the three levels.

export default function POSecondApprovalPage() {
  usePageTitle('PO Second Level Approval')

  const {
    lines, gridLoaded, loading, saving, filter, divisions,
    loadDivisions, loadGrid, setFilter, refresh, cancelSelections,
    updateDisposition, updateRemarks, updatePostponeDate, toggleRow, toggleAll,
    executeSave, auditNoteVisible, setSaving,
  } = usePoSecondApprovalStore()

  usePageReset(usePoSecondApprovalStore.getState().reset)

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
      notifyInfo('List refreshed — approved POs moved to Final Level, declined POs closed.')
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
  const runSave = useCallback(async () => {
    setConfirmOpen(false)
    setSaving(true)
    try {
      const result = await poSecondApprovalApi.saveActions({
        items: selectedLines.map((l) => ({
          pordno: l.pordno, divCode: l.divCode, poNo: l.poNo, poDate: l.poDate,
          disposition: l.disposition, remarks: l.remarks, postponeDate: l.postponeDate,
        })),
      })
      executeSave(result)
      if (result.saved.length > 0) {
        notifySuccess(`Second Level actions saved — ${result.saved.length} PO(s). Audit rows written to LogDet_PO.`)
      }
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
        breadcrumb={['Purchase Order', 'Purchase Order Second Level Approval']}
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
              Select a Division, then click <strong>Load</strong> to fetch purchase orders pending Second Level approval.
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
              <span style={{ fontSize: 12, fontWeight: 600, color: '#4A4A4A' }}>Pending Second Level Approval</span>
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
              levelLabel="second level"
              approvedChipText="Approved — now visible at Final Level"
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
        title="Confirm Second Level Actions"
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
