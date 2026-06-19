import { useEffect, useRef, useState } from 'react'
import type { HeaderTabKey } from '../hooks/usePoTransferForm'
import { Alert, ConfigProvider, Form, Skeleton } from 'antd'
import { useNavigationGuardStore } from '@/shared/store/useNavigationGuardStore'
import { PageLoader, ApiLoader } from '@/components/common/loading'
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

  // CR-023: Register navigation guard when form has unsaved changes (mode ≠ VIEW).
  // AppShell reads this store before any sidebar/logo navigation and shows the
  // confirm dialog. beforeunload handles browser close/refresh.
  const setGuard  = useNavigationGuardStore((s) => s.setGuard)
  const clearGuard = useNavigationGuardStore((s) => s.clearGuard)
  useEffect(() => {
    const dirty = f.mode !== 'VIEW'
    setGuard(dirty, dirty ? f.cancelMode : null)
  }, [f.mode]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => { if (f.mode !== 'VIEW') e.preventDefault() }
    window.addEventListener('beforeunload', handler)
    return () => {
      window.removeEventListener('beforeunload', handler)
      clearGuard()
    }
  }, [f.mode]) // eslint-disable-line react-hooks/exhaustive-deps

  const [prPickerOpen,   setPrPickerOpen]   = useState(false)
  const [findOpen,       setFindOpen]       = useState(false)
  const [deletePickOpen, setDeletePickOpen] = useState(false)   // delete-flow Find modal
  const [bodyTab,        setBodyTab]        = useState<'lines' | 'delivery'>('lines')
  const [deleteReason,   setDeleteReason]   = useState('')

  // Header tab state — controlled here so the page can programmatically navigate
  // to the tab containing the first failing field on save validation.
  const [headerTab, setHeaderTab] = useState<HeaderTabKey>('order')
  useEffect(() => { setHeaderTab('order') }, [f.headerTabResetKey])
  // Reset body section to Item Details after a successful save (Task 1).
  useEffect(() => { setBodyTab('lines') }, [f.bodyTabResetKey])

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
  const handleNew    = () => { setBodyTab('lines'); void f.enterAddMode().then((ok) => { if (ok) setPrPickerOpen(true) }) }
  const handleFind   = () => setFindOpen(true)
  // Delete flow: always open the Find PO modal first so the user picks which PO
  // to delete — prevents accidental deletion of whichever PO happens to be loaded.
  const handleDelete = () => { setDeleteReason(''); setDeletePickOpen(true) }
  const handleCancel = () => { setDeleteReason(''); setBodyTab('lines'); f.cancelMode() }
  const handleSave   = () => {
    if (f.mode === 'DELETE') {
      f.handleDeleteClick()
    } else {
      void f.doSave(
        (tab, fieldName) => {
          setHeaderTab(tab)
          // Small delay lets React re-render the new active tab before scrolling.
          setTimeout(() => {
            f.headerForm.scrollToField(fieldName)
            const inst = f.headerForm.getFieldInstance(fieldName) as { focus?: () => void } | null
            inst?.focus?.()
          }, 100)
        },
        (bodyTab) => setBodyTab(bodyTab),
      )
    }
  }

  // Delete-find: user picks a PO → load it → enter DELETE mode immediately.
  const handleDeletePickSelect = (po: { poNo: number; poDate: string }) => {
    setDeletePickOpen(false)
    void f.loadRecord(po.poNo, po.poDate).then((loaded) => {
      if (loaded) f.enterDeleteMode(loaded)
    })
  }

  const handlePrint = async () => {
    if (!f.currentPo?.poNo) return
    setPrintOpen(true)
    setPrintLoading(true)
    setPrintBlobUrl(null)
    try {
      const { blobUrl, filename } = await poApi.getPrintV2BlobUrl(f.divCode, f.currentPo.poNo, f.currentPo.poDate)
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
        case 's':
        case 'S':
          if (e.ctrlKey) { e.preventDefault(); if (!isView && !busy) handleSave() }
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
    return <PageLoader toolbarButtons={7} formRows={2} gridRows={8} />
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: '#F4F6F9', minWidth: 0 }}>
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
      {f.navLoading && <ApiLoader message="Loading record…" />}
      {f.lookupsError && (
        <Alert type="error" showIcon banner message={f.lookupsError}
          action={<span style={{ fontSize: 12, color: '#185FA5', cursor: 'pointer' }} onClick={() => void f.loadLookups()}>Retry</span>} />
      )}
      {f.mode === 'ADD' && (
        <div style={{
          background: '#EFF6FF', borderBottom: '2px solid #3B82F6', borderLeft: '4px solid #3B82F6',
          padding: '7px 16px', fontSize: 11, color: '#1D4ED8', fontWeight: 500,
          flexShrink: 0, display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <span style={{
            background: '#3B82F6', color: '#fff', borderRadius: 5,
            padding: '1px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
          }}>
            ADD MODE
          </span>
          Select approved PR lines, set rates, and save to generate the Purchase Order.
        </div>
      )}
      {f.mode === 'DELETE' && (
        <div style={{
          background: '#FEF2F2', borderBottom: '2px solid #DC2626', borderLeft: '4px solid #DC2626',
          padding: '7px 16px', display: 'flex', alignItems: 'center', gap: 12, flexShrink: 0,
        }}>
          <span style={{
            background: '#DC2626', color: '#fff', borderRadius: 5,
            padding: '1px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
          }}>
            DELETE MODE
          </span>
          <span style={{ fontSize: 11, color: '#7F1D1D' }}>GRN guard is verified on the server.</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 'auto' }}>
            <label style={{ fontSize: 11, fontWeight: 600, color: '#DC2626' }}>Default Delete Reason *</label>
            <input
              value={deleteReason}
              onChange={(e) => handleDefaultReason(e.target.value)}
              placeholder="Enter reason — auto-fills all lines…"
              style={{ height: 26, width: 300, border: '1px solid #DC2626', borderRadius: 5, padding: '0 8px', fontSize: 12, outline: 'none', background: '#fff' }}
            />
          </div>
        </div>
      )}

      {/* Header form — 7 tabs. In VIEW/DELETE the fields are disabled; the
          ConfigProvider token darkens disabled text so saved values stay
          clearly readable (UX-5) while remaining non-editable. */}
      <Skeleton active loading={!f.lookupsLoaded && !f.lookupsError} paragraph={{ rows: 3 }} style={{ padding: 16 }}>
        <ConfigProvider theme={{
          token: { colorTextDisabled: 'rgba(0,0,0,0.82)' },
          components: { Form: { labelColor: '#475569', labelFontSize: 11 } },
        }}>
          <Form form={f.headerForm} layout="vertical" size="small" component={false}>
            <PoHeaderTabs
              mode={f.mode}
              poNo={f.currentPo?.poNo ?? null}
              orderValue={f.totals.totalOrderValue}
              lineItemValue={f.totals.orderValue}
              currentPo={f.currentPo}
              orderTypes={f.orderTypes}
              suppliers={f.suppliers}
              carriers={f.carriers}
              formTypes={f.formTypes}
              banks={f.banks}
              payTerms={f.payTerms}
              currencies={f.currencies}
              deliveryLocations={f.deliveryLocations}
              billingAddresses={f.billingAddresses}
              pricingTermsOpts={f.pricingTermsOpts}
              lastPoDate={f.preChecks?.lastPoDate ?? null}
              activeTab={headerTab}
              onTabChange={setHeaderTab}
              onSupplierChange={(s) => void f.onSupplierChange(s)}
              onSupplierOpen={() => void f.loadSuppliers()}
            />
          </Form>
        </ConfigProvider>
      </Skeleton>

      {/* PR selection bar (ADD only) */}
      {f.mode === 'ADD' && (
        <div style={{
          display: 'flex', alignItems: 'center', gap: 12, padding: '8px 16px',
          background: '#FFFBEB', borderBottom: '1px solid #FDE68A',
          borderLeft: '4px solid #F59E0B', flexShrink: 0,
        }}>
          <div>
            <span style={{ fontSize: 12, color: '#92400E', fontWeight: 700 }}>Select PR Lines</span>
            <span style={{ fontSize: 11, color: '#B45309', marginLeft: 8 }}>
              Browse and select approved Purchase Requisition lines to add to this PO
            </span>
          </div>
          <span style={{
            marginLeft: 'auto',
            background: f.draftLines.length > 0 ? '#FEF3C7' : '#FEF9EC',
            color: '#B45309', border: '1px solid #FDE68A',
            fontSize: 11, fontWeight: 700, padding: '2px 10px', borderRadius: 20,
          }}>
            {f.draftLines.length} line{f.draftLines.length !== 1 ? 's' : ''} selected
          </span>
          <button
            onClick={() => setPrPickerOpen(true)}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: 5,
              padding: '5px 14px', borderRadius: 6,
              border: '1px solid #185FA5', background: '#185FA5',
              color: '#fff', fontSize: 12, fontWeight: 600, cursor: 'pointer',
              boxShadow: '0 1px 3px rgba(24,95,165,0.2)',
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
        alreadyAdded={new Set(f.draftLines.map((l) => `${l.prNo}-${l.prSno}`))}
        onLoad={(lines) => {
          f.addPrLines(lines)
          setPrPickerOpen(false)
          // CR-002: focus Order Type after PR lines are selected so the user can
          // immediately fill in the required header field without clicking.
          setTimeout(() => {
            const inst = f.headerForm.getFieldInstance('orderType') as { focus?: () => void } | null
            inst?.focus?.()
          }, 100)
        }}
        onCancel={() => {
          setPrPickerOpen(false)
          // CR-002: also focus Order Type when the picker is dismissed (Escape /
          // mouse close / cancel button) so focus is never lost in ADD mode.
          if (f.mode === 'ADD') {
            setTimeout(() => {
              const inst = f.headerForm.getFieldInstance('orderType') as { focus?: () => void } | null
              inst?.focus?.()
            }, 100)
          }
        }}
      />

      <GstTaxDetailsModal
        open={f.gstLineNo !== null}
        line={gstLine}
        mode={f.mode}
        gstTaxCodes={f.gstTaxCodes}
        headerDefaults={f.gstHeaderDefaults}
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

      {/* Delete-find: user picks which PO to delete → load → enter DELETE mode */}
      <PoListModal
        open={deletePickOpen}
        fDate={yfDate}
        lDate={ylDate}
        onSelect={handleDeletePickSelect}
        onClose={() => setDeletePickOpen(false)}
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
