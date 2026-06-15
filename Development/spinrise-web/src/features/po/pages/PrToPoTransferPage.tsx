import { useEffect, useRef, useState } from 'react'
import { Alert, ConfigProvider, Form, Skeleton, Spin } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { notificationService } from '@/shared/lib/notification'
import { usePoTransferForm } from '../hooks/usePoTransferForm'
import * as poApi from '../api/poTransferApi'
import { PoDocBand } from '../components/po-transfer/PoDocBand'
import { PoToolbar } from '../components/po-transfer/PoToolbar'
import { PoHeaderTabs } from '../components/po-transfer/PoHeaderTabs'
import { PoLineGrid } from '../components/po-transfer/PoLineGrid'
import { DeliveryScheduleGrid } from '../components/po-transfer/DeliveryScheduleGrid'
import { PoKpiStrip } from '../components/po-transfer/PoKpiStrip'
import { PrPickerModal } from '../components/PrPickerModal'
import PoListModal from '../components/PoListModal'
import { GstTaxDetailsModal } from '../components/GstTaxDetailsModal'
import { ConfirmDeleteModal } from '../components/ConfirmDeleteModal'
import { PrPrintPreviewModal } from '@/features/pr/components/PrPrintPreviewModal'

// ── PR to PO Transfer page ───────────────────────────────────────────────────
// Composes the orchestration hook with all presentation components inside the
// existing AppShell. Pending Gate-0 items stay behind their adapters: GST route
// via the hook's onSupplierChange (Q4); header-tax via propagateHeaderTax (Q5);
// budget (BR-16/17) server-driven via the save-error path. Mounted at /po/transfer.

export default function PrToPoTransferPage() {
  usePageTitle('PR to PO Transfer')

  const f = usePoTransferForm()

  const [prPickerOpen, setPrPickerOpen] = useState(false)
  const [findOpen,     setFindOpen]     = useState(false)
  const [bodyTab,      setBodyTab]      = useState<'lines' | 'delivery'>('lines')
  const [deleteReason, setDeleteReason] = useState('')

  // Print preview (modal — mirrors the PR module; no new browser tab).
  const [printOpen,     setPrintOpen]     = useState(false)
  const [printLoading,  setPrintLoading]  = useState(false)
  const [printBlobUrl,  setPrintBlobUrl]  = useState<string | null>(null)
  const [printFilename, setPrintFilename] = useState('')

  // Load the latest PO + the navigation index on mount (VIEW). Guarded so React
  // StrictMode's dev-only double-invoke issues exactly one /po/last + /po(list)
  // call. Save/Delete refresh the nav index via their own paths — not gated here.
  const didInitRef = useRef(false)
  useEffect(() => {
    if (didInitRef.current) return
    didInitRef.current = true
    void f.loadLastRecord()
    void f.loadNavList()
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const { yfDate, ylDate } = getFYBounds(f.processingDate ? new Date(f.processingDate) : undefined)
  const fyYear = dayjs(yfDate).year()
  const fy = `${fyYear}-${String(fyYear + 1).slice(2)}`

  const showDelivery = f.mode !== 'DELETE'
  const activeBodyTab = showDelivery ? bodyTab : 'lines'

  // ── Toolbar actions ────────────────────────────────────────────────────────
  const handleNew    = () => { setBodyTab('lines'); void f.enterAddMode() }
  const handleFind   = () => setFindOpen(true)
  const handleDelete = () => { setDeleteReason(''); f.enterDeleteMode() }
  const handleCancel = () => { setDeleteReason(''); setBodyTab('lines'); f.cancelMode() }
  const handleSave   = () => { if (f.mode === 'DELETE') f.handleDeleteClick(); else void f.doSave() }

  const handlePrint = async () => {
    if (!f.currentPo?.poNo) return
    setPrintOpen(true)
    setPrintLoading(true)
    setPrintBlobUrl(null)
    try {
      const { blobUrl, filename } = await poApi.getPrintBlobUrl(f.divCode, f.currentPo.poNo, f.currentPo.poDate)
      setPrintBlobUrl(blobUrl)
      setPrintFilename(filename)
    } catch (err) {
      notificationService.error('Failed to Print', getErrorMessage(err))
      setPrintOpen(false)
    } finally {
      setPrintLoading(false)
    }
  }

  const closePrint = () => {
    setPrintOpen(false)
    if (printBlobUrl) URL.revokeObjectURL(printBlobUrl)
    setPrintBlobUrl(null)
  }

  // Header-level default delete reason → auto-propagate to all lines (BR-04).
  const handleDefaultReason = (reason: string) => {
    setDeleteReason(reason)
    f.setDefaultDeleteReason(reason)
  }

  // F5 — GST & Tax details for the selected line (also triggered by row dbl-click).
  const openGstForSelected = () => {
    if (f.selectedLineNo == null) {
      notificationService.info('No Line Selected', 'Select a line item first, then press F5 for GST details.')
      return
    }
    f.openGstModal(f.selectedLineNo)
  }

  // ── Keyboard shortcuts (F1–F8) ──────────────────────────────────────────────
  // Function keys are global action keys (not typed characters), so they fire
  // from anywhere in the form — including inside inputs — which is intended for
  // an ERP data-entry screen. preventDefault stops browser defaults (F1 help,
  // F3 find, F5 refresh, F7 caret browsing). Gating mirrors the toolbar rules.
  // A "latest ref" keeps the handler current (no stale closures) without
  // re-registering the listener; the ref is updated in an effect, not in render.
  const shortcutRef = useRef<(e: KeyboardEvent) => void>(() => {})
  useEffect(() => {
    shortcutRef.current = (e: KeyboardEvent) => {
      const isView    = f.mode === 'VIEW'
      const busy      = f.pageBusy || printLoading
      const hasRecord = !!f.currentPo?.poNo
      switch (e.key) {
        case 'F1': e.preventDefault(); if (isView && !busy) handleNew(); break
        case 'F2': e.preventDefault(); if (isView && !busy) handleFind(); break
        case 'F3': e.preventDefault(); if (isView && !busy && hasRecord) handleDelete(); break
        case 'F4': e.preventDefault(); if (!isView && !busy) handleSave(); break
        case 'F5': e.preventDefault(); openGstForSelected(); break
        case 'F6': e.preventDefault(); if (!isView && !busy) handleCancel(); break
        case 'F7': e.preventDefault(); if (isView && !busy && hasRecord) void handlePrint(); break
        case 'F8':
          e.preventDefault()
          if (f.deleteModalOpen) void f.handleDeleteConfirm(deleteReason)
          else if (f.mode === 'DELETE' && !busy) f.handleDeleteClick()
          break
      }
    }
  })
  useEffect(() => {
    const handler = (e: KeyboardEvent) => shortcutRef.current(e)
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])

  const gstLine = f.lines.find((l) => l.lineNo === f.gstLineNo) ?? null

  if (f.lookupsLoading) {
    return (
      <div style={{ padding: 32 }}>
        <Spin tip="Loading reference data…"><Skeleton active paragraph={{ rows: 8 }} /></Spin>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: '#F5F5F3', minWidth: 0 }}>
      <PoDocBand mode={f.mode} poNo={f.currentPo?.poNo ?? null} fy={fy} />

      <PoToolbar
        mode={f.mode}
        busy={f.pageBusy || printLoading}
        hasRecord={!!f.currentPo?.poNo}
        canPrev={f.canPrev}
        canNext={f.canNext}
        onNew={handleNew}
        onFind={handleFind}
        onDelete={handleDelete}
        onSave={handleSave}
        onCancel={handleCancel}
        onPrint={() => void handlePrint()}
        onFirst={f.goFirst}
        onPrev={f.goPrev}
        onNext={f.goNext}
        onLast={f.goLast}
      />

      {/* Status / mode banners */}
      {f.navLoading && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 16px', background: '#e6f4ff', flexShrink: 0 }}>
          <Spin size="small" /><span style={{ fontSize: 12, color: '#1677ff' }}>Loading record…</span>
        </div>
      )}
      {f.lookupsError && (
        <Alert type="error" showIcon banner message={f.lookupsError}
          action={<span style={{ fontSize: 12, color: '#185FA5', cursor: 'pointer' }} onClick={() => void f.loadLookups()}>Retry</span>} />
      )}
      {f.mode === 'ADD' && (
        <div style={{ background: '#E6F1FB', borderBottom: '2px solid #185FA5', padding: '5px 16px', fontSize: 11, color: '#185FA5', fontWeight: 600, flexShrink: 0 }}>
          ADD MODE — Select approved PR lines, set rates, and save to generate the Purchase Order.
        </div>
      )}
      {f.mode === 'DELETE' && (
        <div style={{
          background: '#FCEBEB', borderBottom: '2px solid #A32D2D', padding: '7px 16px',
          display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0,
        }}>
          <strong style={{ color: '#A32D2D', fontSize: 12 }}>⚠ DELETE MODE</strong>
          <span style={{ fontSize: 11, color: '#1a1a1a' }}>GRN guard is verified on the server.</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 'auto' }}>
            <label style={{ fontSize: 11, fontWeight: 600, color: '#A32D2D' }}>Default Delete Reason *</label>
            <input
              value={deleteReason}
              onChange={(e) => handleDefaultReason(e.target.value)}
              placeholder="Enter reason — auto-fills all lines…"
              style={{ height: 26, width: 300, border: '1px solid #A32D2D', borderRadius: 4, padding: '0 8px', fontSize: 12, outline: 'none' }}
            />
          </div>
        </div>
      )}

      {/* Header form — 7 tabs. In VIEW/DELETE the fields are disabled; the
          ConfigProvider token darkens disabled text so saved values stay
          clearly readable (UX-5) while remaining non-editable. */}
      <Skeleton active loading={!f.lookupsLoaded && !f.lookupsError} paragraph={{ rows: 3 }} style={{ padding: 16 }}>
        <ConfigProvider theme={{ token: { colorTextDisabled: 'rgba(0,0,0,0.82)' } }}>
          <Form form={f.headerForm} layout="vertical" component={false}>
            <PoHeaderTabs
              mode={f.mode}
              poNo={f.currentPo?.poNo ?? null}
              orderValue={f.totals.orderValue}
              currentPo={f.currentPo}
              orderTypes={f.orderTypes}
              suppliers={f.suppliers}
              carriers={f.carriers}
              formTypes={f.formTypes}
              banks={f.banks}
              onSupplierChange={(s) => void f.onSupplierChange(s)}
              onSupplierOpen={() => void f.loadSuppliers()}
            />
          </Form>
        </ConfigProvider>
      </Skeleton>

      {/* PR selection bar (ADD only) */}
      {f.mode === 'ADD' && (
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '6px 16px',
          background: '#fffbf0', borderBottom: '1px solid #f0e6c8', flexShrink: 0,
        }}>
          <span style={{ fontSize: 12, color: '#BA7517', fontWeight: 600 }}>Select PR Lines</span>
          <span style={{ fontSize: 11, color: '#888' }}>Browse and select approved Purchase Requisition lines to add to this PO</span>
          <span style={{
            marginLeft: 'auto', background: '#FAEEDA', color: '#BA7517', border: '1px solid #f0e6c8',
            fontSize: 11, fontWeight: 700, padding: '1px 8px', borderRadius: 20,
          }}>
            {f.draftLines.length} line{f.draftLines.length !== 1 ? 's' : ''} selected
          </span>
          <button
            onClick={() => setPrPickerOpen(true)}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: 5, padding: '4px 12px', borderRadius: 5,
              border: '1px solid #185FA5', background: '#185FA5', color: '#fff', fontSize: 12, fontWeight: 600, cursor: 'pointer',
            }}
          >
            <SearchOutlined /> Browse PR Lines
          </button>
        </div>
      )}

      {/* Body tabs: Item Details | Delivery Schedule */}
      <div style={{ display: 'flex', alignItems: 'flex-end', padding: '0 16px', background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
        <BodyTab label="Item Details"      count={f.lines.length}        active={activeBodyTab === 'lines'}    onClick={() => setBodyTab('lines')} />
        {showDelivery && (
          <BodyTab label="Delivery Schedule" count={f.deliveryLines.length} active={activeBodyTab === 'delivery'} onClick={() => setBodyTab('delivery')} />
        )}
      </div>

      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        {activeBodyTab === 'lines' ? (
          <PoLineGrid
            mode={f.mode}
            lines={f.lines}
            selectedLineNo={f.selectedLineNo}
            onSelectLine={f.setSelectedLineNo}
            onUpdateRateQty={f.updateLineRateQty}
            onOpenGst={f.openGstModal}
            onRemoveLine={f.removeDraftLine}
            onDeleteReasonChange={f.setLineDeleteReason}
          />
        ) : (
          <DeliveryScheduleGrid
            mode={f.mode}
            deliveryLines={f.deliveryLines}
            onAddSlot={f.addSlot}
            onUpdateSlot={f.updateSlot}
            onRemoveSlot={f.removeSlot}
          />
        )}
      </div>

      <PoKpiStrip
        mode={f.mode}
        totals={f.totals}
        approvalStatus={f.currentPo?.approvalStatus}
        approvalActor={undefined}
      />

      {/* Modals */}
      <PrPickerModal
        open={prPickerOpen}
        divCode={f.divCode}
        onLoad={(lines) => { f.addPrLines(lines); setPrPickerOpen(false) }}
        onCancel={() => setPrPickerOpen(false)}
      />

      <GstTaxDetailsModal
        open={f.gstLineNo !== null}
        line={gstLine}
        mode={f.mode}
        onApply={(lineNo, { detail, deleteReason: dr }) => {
          f.applyGstDetail(lineNo, detail)
          if (dr !== undefined) f.setLineDeleteReason(lineNo, dr)
          f.closeGstModal()
        }}
        onCancel={f.closeGstModal}
      />

      <ConfirmDeleteModal
        open={f.deleteModalOpen}
        poNo={f.currentPo?.poNo ?? null}
        deleting={f.deleting}
        onConfirm={() => void f.handleDeleteConfirm(deleteReason)}
        onCancel={() => f.setDeleteModalOpen(false)}
      />

      <PoListModal
        open={findOpen}
        fDate={yfDate}
        lDate={ylDate}
        onSelect={(po) => { void f.loadRecord(po.poNo, po.poDate) }}
        onClose={() => setFindOpen(false)}
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

function BodyTab({ label, count, active, onClick }: {
  label: string; count: number; active: boolean; onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 6, padding: '8px 16px',
        border: 'none', background: 'transparent', cursor: 'pointer', fontSize: 12,
        fontFamily: 'inherit', marginBottom: -1,
        borderBottom: `2px solid ${active ? '#185FA5' : 'transparent'}`,
        color: active ? '#185FA5' : '#888', fontWeight: active ? 600 : 500,
      }}
    >
      {label}
      <span style={{
        fontSize: 10, fontWeight: 700, padding: '1px 7px', borderRadius: 20,
        background: active ? '#185FA5' : '#E6F1FB', color: active ? '#fff' : '#185FA5',
      }}>
        {count}
      </span>
    </button>
  )
}
