import { useEffect, useRef, useState } from 'react'
import { Alert, ConfigProvider, Form, Skeleton } from 'antd'
import dayjs from 'dayjs'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { useNavigationGuardStore } from '@/shared/store/useNavigationGuardStore'
import { PageLoader, ApiLoader } from '@/components/common/loading'
import { PRDocBand } from '@/features/pr/components/pr-form/PRToolbar'
import { PrPrintPreviewModal } from '@/features/pr/components/PrPrintPreviewModal'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { notificationService } from '@/shared/lib/notification'
import { usePoAmendment } from '../hooks/usePoAmendment'
import type { HeaderTabKey } from '../hooks/usePoTransferForm'
import * as poApi from '../api/poTransferApi'
import { PoAmendmentToolbar } from '../components/po-amendment/PoAmendmentToolbar'
import { PoHeaderTabs } from '../components/po-transfer/PoHeaderTabs'
import { PoLineGrid } from '../components/po-transfer/PoLineGrid'
import { DeliveryScheduleGrid } from '../components/po-transfer/DeliveryScheduleGrid'
import { GstTaxDetailsModal } from '../components/GstTaxDetailsModal'
import PoAmendablePickerModal from '../components/PoAmendablePickerModal'
import AmendmentListModal from '../components/po-amendment/AmendmentListModal'
import { AmendConfirmModal } from '../components/po-amendment/AmendConfirmModal'
import { formatPoNo } from '../types'

// ── PO Amendment page (FN-PO-Amendment v1.2, VB6 amdmnt.frm) ─────────────────
//
// Reuses the PR-to-PO Transfer presentation stack wholesale — PoHeaderTabs,
// PoLineGrid, DeliveryScheduleGrid, GstTaxDetailsModal — driving them in "amend
// mode" (see usePoAmendment). The Transfer screen is untouched: every amendment
// prop on those components is OPTIONAL and undefined there.
//
// Amendment-specific behaviour on this page:
//   • Identity fields locked (lockIdentity) — FN §1.
//   • Amendment Reason column, mandatory on any CHANGED line — FN §3.6.
//   • Confirmation prompt before the irreversible save — FN §3.8.
//
// ⚠ The 6 SPs behind this screen are Mariyaiya's and are NOT YET AUTHORED
//   (CEO 12-Jul). Every call will fail at the DB until they land — the screen is
//   built contract-first and goes live unchanged the moment they do.

export default function POAmendmentPage() {
  usePageTitle('Purchase Order Amendment')

  const f = usePoAmendment()

  const [headerTab, setHeaderTab] = useState<HeaderTabKey>('order')
  const [bodyTab,   setBodyTab]   = useState<'lines' | 'delivery'>('lines')

  const inAmend = f.mode === 'AMEND' && !!f.currentPo
  const busy    = f.saving || f.loading

  // Unsaved-changes guard — an amendment in progress is dirty work (mirrors the
  // Transfer page's guard so sidebar navigation prompts before discarding).
  const setGuard   = useNavigationGuardStore((s) => s.setGuard)
  const clearGuard = useNavigationGuardStore((s) => s.clearGuard)
  useEffect(() => {
    const dirty = inAmend && f.changedLines.length > 0
    setGuard(dirty, dirty ? f.cancelAmend : null)
  }, [inAmend, f.changedLines.length]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => {
      if (inAmend && f.changedLines.length > 0) e.preventDefault()
    }
    window.addEventListener('beforeunload', handler)
    return () => {
      window.removeEventListener('beforeunload', handler)
      clearGuard()
    }
  }, [inAmend, f.changedLines.length]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Toolbar: print preview (mirrors PrToPoTransferPage.handlePrint) ────────
  const [printOpen,     setPrintOpen]     = useState(false)
  const [printLoading,  setPrintLoading]  = useState(false)
  const [printBlobUrl,  setPrintBlobUrl]  = useState<string | null>(null)
  const [printFilename, setPrintFilename] = useState('')

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

  // ── Toolbar: keyboard shortcuts (mirrors PrToPoTransferPage's F-key scheme) ─
  // Ref keeps the handler pointing at the latest closure without re-binding the
  // window listener every render (same pattern as PrToPoTransferPage).
  const shortcutRef = useRef<(e: KeyboardEvent) => void>(() => {})
  useEffect(() => {
    shortcutRef.current = (e: KeyboardEvent) => {
      // F1/F2 (Select PO / Find Amendment) and nav intentionally have no bound
      // key while inAmend — they mirror the toolbar's canBrowse gate, which is
      // hard-disabled (not just guarded) once an amendment is in progress.
      switch (e.key) {
        case 'F1': e.preventDefault(); if (!inAmend && !busy) void f.openPicker(); break
        case 'F2': e.preventDefault(); if (!inAmend && !busy) void f.openFindAmendment(); break
        case 'F6': e.preventDefault(); if (inAmend && !busy) f.cancelAmend(); break
        case 'F7': e.preventDefault(); if (f.currentPo && !busy) void handlePrint(); break
        case 's':
        case 'S':
          if (e.ctrlKey) { e.preventDefault(); if (inAmend && !busy) f.requestSave() }
          break
      }
    }
  })
  useEffect(() => {
    const handler = (e: KeyboardEvent) => shortcutRef.current(e)
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])

  if (f.lookupsLoading) {
    return <PageLoader toolbarButtons={4} formRows={2} gridRows={8} />
  }

  const gstLine = f.lines.find((l) => l.lineNo === f.gstLineNo) ?? null

  const subValue = f.currentPo
    ? `${formatPoNo(f.currentPo.poNo)} · ${dayjs(f.currentPo.poDate).format('DD-MMM-YYYY')}`
    : (f.processingDate ? dayjs(f.processingDate).format('DD MMM YYYY') : dayjs().format('DD MMM YYYY'))

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: '#F4F6F9', minWidth: 0, overflowX: 'hidden' }}>
      <PRDocBand
        breadcrumb={['Purchase Order', 'Purchase Order Amendment']}
        subLabel='Amendment No'
        subValue={subValue}
      />

      {/* Toolbar — PoAmendmentToolbar (independent component, not the Transfer
          toolbar) styled to match it. No "New PO": amendment only ever operates
          on an existing PO, there is no create-new concept to map it to. Delete
          is likewise omitted — deletion is a separate, not-yet-wired action (see
          usePoAmendment.deleteOrder). Select PO / Find Amendment / record nav
          are hard-disabled (canBrowse = !inAmend) the moment an amendment is in
          progress — the user cannot switch documents mid-edit; they re-enable
          on Save or Cancel (cancelAmend reloads the same PO read-only). Print
          stays available regardless — it's read-only and doesn't switch documents. */}
      <PoAmendmentToolbar
        busy={busy}
        canBrowse={!inAmend}
        canEdit={inAmend}
        saveDisabled={f.changedLines.length === 0}
        hasRecord={!!f.currentPo}
        canPrev={f.canPrev}
        canNext={f.canNext}
        onFind={() => void f.openPicker()}
        onFindAmendment={() => void f.openFindAmendment()}
        onSave={f.requestSave}
        onCancel={f.cancelAmend}
        onPrint={() => void handlePrint()}
        onFirst={f.goFirst}
        onPrev={f.goPrev}
        onNext={f.goNext}
        onLast={f.goLast}
      />

      {f.lookupsError && (
        <Alert type="error" showIcon banner message={f.lookupsError}
          action={<span style={{ fontSize: 12, color: '#185FA5', cursor: 'pointer' }}
                        onClick={() => void f.loadLookups()}>Retry</span>} />
      )}

      {/* Amendment status strip — surfaces the §3.6 gate before the user hits Save,
          rather than letting them discover it in a rejection toast. */}
      {inAmend && (
        <div style={{
          background: f.linesMissingReason.length > 0 ? '#FEF2F2' : '#F0F7FF',
          borderBottom: `1px solid ${f.linesMissingReason.length > 0 ? '#DC2626' : '#BBDDFB'}`,
          borderLeft: `4px solid ${f.linesMissingReason.length > 0 ? '#DC2626' : '#185FA5'}`,
          padding: '7px 16px', display: 'flex', alignItems: 'center', gap: 12, flexShrink: 0,
        }}>
          <span style={{
            background: '#185FA5', color: '#fff', borderRadius: 5,
            padding: '1px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
          }}>
            AMEND MODE
          </span>
          <span style={{ fontSize: 11, color: '#334155' }}>
            {f.changedLines.length === 0
              ? 'Edit any line to begin. A zero-change amendment cannot be saved.'
              : `${f.changedLines.length} line${f.changedLines.length !== 1 ? 's' : ''} changed.`}
          </span>
          {f.linesMissingReason.length > 0 && (
            <span style={{ fontSize: 11, color: '#7F1D1D', fontWeight: 600, marginLeft: 'auto' }}>
              ⚠ Amendment Reason required on {f.linesMissingReason.length} changed line
              {f.linesMissingReason.length !== 1 ? 's' : ''}
              {' '}(line {f.linesMissingReason.map((l) => l.lineNo).join(', ')})
            </span>
          )}
        </div>
      )}

      {/* Read-only viewing strip — set when a record is loaded via Find Amendment.
          getPOForAmend only ever returns the PO's CURRENT live state (there is no
          backend endpoint for a specific past amendment's point-in-time snapshot),
          so this is honest about what's actually being shown rather than implying
          it's the historical amendment. */}
      {!inAmend && f.mode === 'VIEW' && f.currentPo && (
        <div style={{
          background: '#F8FAFD', borderBottom: '1px solid #E2E8F0', borderLeft: '4px solid #94A3B8',
          padding: '7px 16px', display: 'flex', alignItems: 'center', gap: 12, flexShrink: 0,
        }}>
          <span style={{
            background: '#64748B', color: '#fff', borderRadius: 5,
            padding: '1px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '0.05em',
          }}>
            VIEW ONLY
          </span>
          <span style={{ fontSize: 11, color: '#475569' }}>
            Showing this Purchase Order&rsquo;s current state (read-only) — its point-in-time
            amendment snapshot isn&rsquo;t available. Click Select PO to amend it.
          </span>
        </div>
      )}

      {f.loading && <ApiLoader message="Loading Purchase Order…" />}

      {!f.currentPo && !f.loading ? (
        <div style={{
          flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
          justifyContent: 'center', gap: 6, color: '#888', padding: 40, textAlign: 'center',
        }}>
          <div style={{ fontSize: 34, opacity: 0.5 }}>📝</div>
          <div style={{ fontSize: 13, fontWeight: 600, color: '#4a4a4a' }}>No Purchase Order selected</div>
          <div style={{ fontSize: 11, maxWidth: 380, lineHeight: 1.6 }}>
            Select a Purchase Order above to load it for amendment. PO No/Date stay
            locked (the record key); Supplier, Order Type, taxes, charges, quantities,
            rates and the delivery schedule can all be amended.
          </div>
        </div>
      ) : f.currentPo ? (
        <>
          <Skeleton active loading={false} paragraph={{ rows: 3 }} style={{ padding: 16 }}>
            <ConfigProvider theme={{
              token: { colorTextDisabled: 'rgba(0,0,0,0.82)' },
              components: { Form: { labelColor: '#475569', labelFontSize: 11 } },
            }}>
              <Form form={f.headerForm} layout="vertical" size="small" component={false}>
                <PoHeaderTabs
                  mode="VIEW"
                  amendMode={inAmend}        // header editable only while actually amending —
                                             // read-only when a record was loaded via Find Amendment
                  lockPoDate                 // …but PO Date stays read-only (record key)
                  // 13-Jul ruling (Mariyaiya, FN author + Seenivasan, IST): FN §1's
                  // "locked identity" restriction applies to the LINE GRID only — the
                  // HEADER follows VB6, which unlocks every field. Supplier / Order Type
                  // / GSTIN / GST state are amendable. PO No stays read-only in
                  // OrderDetailsTab regardless; PO Date is pinned via lockPoDate.
                  poNo={f.currentPo.poNo}
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
                  activeTab={headerTab}
                  onTabChange={setHeaderTab}
                  // Supplier is amendable now; changing it can flip the GST route, so the
                  // hook re-routes and recomputes every line (the SP re-bases on save too).
                  onSupplierChange={f.onSupplierChange}
                  // Gap #12 (VB6 parity): header charge / applicability changes cascade
                  // to lines, but only to lines with no receipts (see cascadeHeaderToLines).
                  onHeaderCommit={f.cascadeHeaderToLines}
                  onApplicabilityCommit={f.cascadeHeaderToLines}
                />
              </Form>
            </ConfigProvider>
          </Skeleton>

          <div style={{ display: 'flex', alignItems: 'flex-end', padding: '0 16px', background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
            <BodyTab label="Item Details"      count={f.lines.length}         active={bodyTab === 'lines'}    onClick={() => setBodyTab('lines')} />
            <BodyTab label="Delivery Schedule" count={f.deliveryLines.length} active={bodyTab === 'delivery'} onClick={() => setBodyTab('delivery')} />
          </div>

          <div style={{ flex: 1, minHeight: 0, minWidth: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            {bodyTab === 'lines' ? (
              <PoLineGrid
                mode="VIEW"
                amendMode={inAmend}             // Rate/Qty editable + Amendment Reason column,
                                                 // only while actually amending
                onAmendReasonChange={f.setAmendReason}
                lines={f.lines}
                selectedLineNo={f.selectedLineNo}
                onSelectLine={f.setSelectedLineNo}
                onUpdateRateQty={f.updateLineRateQty}
                onOpenGst={f.openGstModal}
                onRemoveLine={() => { /* line delete is ksp_PO_DeleteLines — separate action, not inline */ }}
                onDeleteReasonChange={() => { /* delete-reason column is not shown in amend mode */ }}
                emptyText="This Purchase Order has no amendable lines."
              />
            ) : (
              <DeliveryScheduleGrid
                mode={inAmend ? 'ADD' : 'VIEW'}  // editable during amendment (FN §2 group 11),
                                                  // read-only when just viewing via Find Amendment
                deliveryLines={f.deliveryLines}
                onAddSlot={f.addSlot}
                onUpdateSlot={f.updateSlot}
                onRemoveSlot={f.removeSlot}
              />
            )}
          </div>
        </>
      ) : null}

      {/* Modals */}
      <PoAmendablePickerModal
        open={f.pickerOpen}
        items={f.amendablePos}
        loading={f.pickerLoading}
        onSelect={(po) => { void f.selectPo(po) }}
        onClose={f.closePicker}
      />

      <AmendmentListModal
        open={f.findAmendmentOpen}
        items={f.amendmentList}
        loading={f.amendmentListLoading}
        onSelect={(row) => { void f.viewAmendment(row) }}
        onClose={f.closeFindAmendment}
      />

      <GstTaxDetailsModal
        open={f.gstLineNo !== null}
        line={gstLine}
        mode={inAmend ? 'ADD' : 'VIEW'}         // editable during amendment, read-only when
                                                 // viewing via Find Amendment
        gstTaxCodes={f.gstTaxCodes}
        headerDefaults={f.gstHeaderDefaults}
        onApply={(lineNo, { detail }) => {
          if (f.applyGstDetail(lineNo, detail)) f.closeGstModal()
        }}
        onCancel={f.closeGstModal}
      />

      <AmendConfirmModal
        open={f.confirmOpen}
        poNo={f.currentPo?.poNo ?? null}
        poDate={f.currentPo?.poDate ?? ''}
        changedCount={f.changedLines.length}
        revisedValue={f.totals.totalOrderValue}
        saving={f.saving}
        onConfirm={() => void f.confirmSave()}
        onCancel={() => f.setConfirmOpen(false)}
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
