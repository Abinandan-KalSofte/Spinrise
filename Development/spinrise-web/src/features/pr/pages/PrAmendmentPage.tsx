import { useCallback, useEffect, useRef, useState } from 'react'
import { Modal } from 'antd'
import { SectionLoader } from '@/components/common/loading'
import { notifyError } from '@/shared/lib/notificationHelper'
import { usePrAmendmentForm } from '../hooks/usePrAmendmentForm'
import { PrAmendmentHeader } from '../components/amendment/PrAmendmentHeader'
import { PrAmendmentLineGrid } from '../components/amendment/PrAmendmentLineGrid'
import * as amendApi from '../api/prAmendmentApi'
import * as prApi from '../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { AmendmentSummary, PrSummary, PrTypeOption } from '../types'
import PrAmendmentListModal from '../components/amendment/PrAmendmentListModal'
import PrPickerForAmendModal from '../components/amendment/PrPickerForAmendModal'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { PRDocBand } from '../components/pr-form/PRToolbar'

// ── Style tokens ──────────────────────────────────────────────────────────────
function tbBtn(extra?: React.CSSProperties): React.CSSProperties {
  return {
    display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 12px',
    borderRadius: 5, border: '1px solid #e2e2e2', background: '#fff',
    fontSize: 12, fontWeight: 500, cursor: 'pointer', color: '#4A4A4A',
    whiteSpace: 'nowrap', fontFamily: 'inherit',
    ...extra,
  }
}
const KBD: React.CSSProperties = {
  fontFamily: 'monospace', fontSize: 9, fontWeight: 700,
  background: 'rgba(0,0,0,.07)', padding: '1px 4px', borderRadius: 3,
  color: 'inherit', marginLeft: 2,
}
const KBD_INV: React.CSSProperties = { ...KBD, background: 'rgba(255,255,255,.2)' }
const NAV_BTN: React.CSSProperties = {
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  width: 28, height: 28, border: '1px solid #e2e2e2', background: '#fff',
  cursor: 'pointer', color: '#4A4A4A', fontSize: 14, fontFamily: 'inherit',
}
const SEP: React.CSSProperties = { width: 1, height: 20, background: '#e2e2e2', margin: '0 4px' }

export default function PrAmendmentPage() {
  usePageTitle('PR Amendment')

  const {
    mode,
    header, lines, setLines,
    loading, saving,
    navList, navIdx,
    processingDate,
    loadForNew, loadById, loadLastAmendment,
    enterNew, enterFind,
    navFirst, navPrev, navNext, navLast,
    doSave, resetForm,
  } = usePrAmendmentForm()

  const [prPickerOpen,   setPrPickerOpen]   = useState(false)
  const [amendListOpen,  setAmendListOpen]  = useState(false)
  const [amendListMode,  setAmendListMode]  = useState<'view'>('view')
  const [printLoading,   setPrintLoading]   = useState(false)
  const [printBlobUrl,   setPrintBlobUrl]   = useState<string | null>(null)
  const [printOpen,      setPrintOpen]      = useState(false)
  const [printFilename,  setPrintFilename]  = useState('')

  // PR Type options + PurTypeFlg (fetched once on mount)
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')
  const [prTypes,    setPrTypes]    = useState<PrTypeOption[]>([])
  const [purTypeFlg, setPurTypeFlg] = useState(0)

  // Editable header fields
  const [refNo,          setRefNo]          = useState('')
  const [amendReason,    setAmendReason]    = useState('')
  const [iType,          setIType]          = useState<string>('')
  const [reasonError,    setReasonError]    = useState(false)
  const { yfDate: fyStart, ylDate: fyEnd } = getFYBounds(
    processingDate ? new Date(processingDate) : undefined,
  )

  // Fetch PR Types and PurTypeFlg once on mount
  useEffect(() => {
    if (!divCode) return
    void prApi.getPrTypes().then(setPrTypes).catch(() => {/* non-fatal */})
    void prApi.getParameters(divCode).then((p) => setPurTypeFlg(p.purTypeFlg)).catch(() => {/* non-fatal */})
  }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  // Sync header fields when a record loads
  useEffect(() => {
    if (header) {
      setRefNo(header.refNo ?? '')
      setAmendReason(header.amendmentReason ?? '')
      setIType(header.iType ?? '')
      setReasonError(false)
    } else if (mode === 'new') {
      setRefNo('')
      setAmendReason('')
      setIType('')
      setReasonError(false)
    }
  }, [header, mode])

  useEffect(() => { void loadLastAmendment() }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Computed states ───────────────────────────────────────────────────────
  const isView  = mode === 'view'
  const isNew   = mode === 'new'
  const isNone  = mode === 'none'
  const editing = isNew

  const canNew    = (isView || isNone) && !saving
  const canFind   = (isView || isNone) && !saving
  const canSave   = editing && !saving
  const canCancel = editing && !saving
  const canPrint  = isView && !!header && !saving
  const canNav    = isView && navList.length > 1

  // ── Handlers ──────────────────────────────────────────────────────────────
  const handleNew = useCallback(() => {
    enterNew()
    setPrPickerOpen(true)
  }, [enterNew])

  const handleFind = useCallback(() => {
    enterFind()
    setAmendListMode('view')
    setAmendListOpen(true)
  }, [enterFind])

  const handleCancel = useCallback(() => {
    if (navList.length > 0) {
      const idx = navIdx >= 0 && navIdx < navList.length ? navIdx : 0
      const rec = navList[idx]
      void loadById(rec.prNo, rec.prDate, rec.amendNo, 'view')
    } else {
      resetForm()
    }
  }, [navList, navIdx, loadById, resetForm])

  const handleSave = useCallback(async () => {
    if (!amendReason.trim()) { setReasonError(true); notifyError('Amendment Reason is required.'); return }
    if (purTypeFlg === 1 && !iType.trim()) { notifyError('PR Type is required.'); return }
    setReasonError(false)
    await doSave(refNo, amendReason, iType || null)
  }, [amendReason, refNo, iType, purTypeFlg, doSave])

  const handlePrSelected = useCallback(async (pr: PrSummary) => {
    setPrPickerOpen(false)
    try {
      const existing = await amendApi.getAmendmentList(divCode, fyStart, fyEnd, pr.prNo)
      if (existing.length > 0) {
        Modal.confirm({
          icon: null,
          title: 'Prior Amendments Found',
          content: `This PR has already been amended ${existing.length} time${existing.length === 1 ? '' : 's'}. Do you want to proceed?`,
          okText: 'Proceed',
          cancelText: 'Cancel',
          onOk: () => void loadForNew(pr.prNo, pr.prDate),
        })
        return
      }
    } catch {
      // Non-fatal — proceed without the check
    }
    await loadForNew(pr.prNo, pr.prDate)
  }, [divCode, fyStart, fyEnd, loadForNew])

  const handleAmendSelected = useCallback(async (amend: AmendmentSummary) => {
    setAmendListOpen(false)
    await loadById(amend.prNo, amend.prDate, amend.amendNo, amendListMode)
  }, [loadById, amendListMode])

  const handlePrint = useCallback(async () => {
    if (!header) return
    setPrintLoading(true)
    try {
      const blob = await amendApi.printAmendment(header.divCode, header.prNo, header.prDate, header.amendNo)
      const url  = URL.createObjectURL(blob)
      if (printBlobUrl) URL.revokeObjectURL(printBlobUrl)
      setPrintBlobUrl(url)
      setPrintFilename(`AMD-${String(header.amendNo).padStart(4, '0')}-PR${header.prNo}.pdf`)
      setPrintOpen(true)
    } catch (e: unknown) {
      notifyError((e as Error).message ?? 'Print failed.')
    } finally {
      setPrintLoading(false)
    }
  }, [header, printBlobUrl])

  const closePrint = useCallback(() => {
    setPrintOpen(false)
    if (printBlobUrl) { URL.revokeObjectURL(printBlobUrl); setPrintBlobUrl(null) }
  }, [printBlobUrl])

  // ── Keyboard shortcuts ────────────────────────────────────────────────────
  // Refs so the event listener always sees latest handlers
  const handleNewRef    = useRef(handleNew)
  const handleSaveRef   = useRef(handleSave)
  const handleCancelRef = useRef(handleCancel)
  const canNewRef       = useRef(canNew)
  const canSaveRef      = useRef(canSave)
  const canCancelRef    = useRef(canCancel)
  useEffect(() => { handleNewRef.current    = handleNew    }, [handleNew])
  useEffect(() => { handleSaveRef.current   = handleSave   }, [handleSave])
  useEffect(() => { handleCancelRef.current = handleCancel }, [handleCancel])
  useEffect(() => { canNewRef.current    = canNew    }, [canNew])
  useEffect(() => { canSaveRef.current   = canSave   }, [canSave])
  useEffect(() => { canCancelRef.current = canCancel }, [canCancel])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'F3') {
        e.preventDefault()
        if (canNewRef.current) handleNewRef.current()
      }
      if (e.ctrlKey && e.key === 's') {
        e.preventDefault()
        if (canSaveRef.current) void handleSaveRef.current()
      }
      if (e.altKey && e.key === 'x') {
        e.preventDefault()
        if (canCancelRef.current) handleCancelRef.current()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, []) // mount/unmount only — handlers accessed via refs

  // ── Labels ────────────────────────────────────────────────────────────────
  const amendNoLabel = header
    ? `AMD-${String(header.amendNo).padStart(4, '0')}`
    : 'Auto-generated on save'

  const showGrid = !!header && (mode !== 'none')

  const emptyTitle = mode === 'none' ? 'No amendment loaded'
    : mode === 'new'  ? 'No PR selected'
    : 'No amendment selected'

  const emptySub = mode === 'none'
    ? 'Click <strong>New</strong> (F3) to create a new amendment, or <strong>Find</strong> to view an existing one.'
    : mode === 'new'
      ? 'Select a PR from the popup to create a new amendment.'
      : `Select an amendment from the popup to ${mode} it.`

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden', background: '#F5F5F3' }}>

      {/* ── Doc Band ──────────────────────────────────────────────────────────── */}
      <PRDocBand
        breadcrumb={[ 'Purchase Order', 'Purchase Requisition Amendment' ]}
        subLabel="Amendment No."
        subValue={amendNoLabel}
      />

      {/* ── Toolbar ───────────────────────────────────────────────────────────── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 4, padding: '6px 16px',
        background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0,
      }}>
        {/* New */}
        <button
          style={tbBtn(!canNew ? { opacity: .4, cursor: 'not-allowed' } : {})}
          disabled={!canNew} onClick={handleNew}
        >
          + <span>New</span><kbd style={KBD}>F3</kbd>
        </button>


        {/* Find */}
        <button
          style={tbBtn(!canFind
            ? { opacity: .4, cursor: 'not-allowed' }
            : isView ? { background: '#E6F1FB', color: '#185FA5', borderColor: '#a8c8ea', fontWeight: 600 } : {}
          )}
          disabled={!canFind} onClick={handleFind}
        >
          ≡ <span>Find</span>
        </button>

        <div style={SEP} />

        {/* Nav buttons */}
        {[
          { lbl: '«', title: 'First',    fn: navFirst, off: !canNav || navIdx <= 0 },
          { lbl: '‹', title: 'Previous', fn: navPrev,  off: !canNav || navIdx <= 0 },
          { lbl: '›', title: 'Next',     fn: navNext,  off: !canNav || navIdx >= navList.length - 1 },
          { lbl: '»', title: 'Last',     fn: navLast,  off: !canNav || navIdx >= navList.length - 1 },
        ].map(({ lbl, title, fn, off }, i) => (
          <button key={lbl} title={title} disabled={off} onClick={fn}
            style={{
              ...NAV_BTN,
              borderLeft: i > 0 ? 'none' : undefined,
              borderRadius: i === 0 ? '5px 0 0 5px' : i === 3 ? '0 5px 5px 0' : 0,
              opacity: off ? .35 : 1, cursor: off ? 'not-allowed' : 'pointer',
            }}
          >{lbl}</button>
        ))}

        <div style={SEP} />

        {/* Save */}
        <button
          style={tbBtn(
            !canSave
              ? { opacity: .4, cursor: 'not-allowed', background: '#185FA5', color: '#fff', borderColor: '#185FA5' }
              : { background: '#185FA5', color: '#fff', borderColor: '#185FA5' },
          )}
          disabled={!canSave} onClick={() => void handleSave()}
        >
          ✓ <span>Save</span><kbd style={KBD_INV}>Ctrl+S</kbd>
        </button>

        {/* Print */}
        <button
          style={tbBtn(!canPrint || printLoading ? { opacity: .4, cursor: 'not-allowed' } : {})}
          disabled={!canPrint || printLoading} onClick={() => void handlePrint()}
        >
          🖨 <span>Print</span>
        </button>

        {/* Cancel */}
        <button
          style={tbBtn(!canCancel ? { opacity: .4, cursor: 'not-allowed' } : {})}
          disabled={!canCancel} onClick={handleCancel}
        >
          ✕ <span>Cancel</span><kbd style={KBD}>Alt+X</kbd>
        </button>
      </div>

      {/* ── Content ───────────────────────────────────────────────────────────── */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

        {/* Amendment Details header */}
        {loading && <SectionLoader message="Loading amendment…" height={120} />}
        {!loading && <PrAmendmentHeader
            header={header}
            mode={mode}
            refNo={refNo}
            amendReason={amendReason}
            reasonError={reasonError}
            processingDate={processingDate}
            prTypes={prTypes}
            purTypeFlg={purTypeFlg}
            iType={iType}
            onRefNoChange={setRefNo}
            onAmendReasonChange={(v) => { setAmendReason(v); if (v.trim()) setReasonError(false) }}
            onITypeChange={setIType}
            onFindPR={() => { if (mode === 'new') setPrPickerOpen(true) }}
          />}

        {/* Grid section */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: '#fff' }}>

          {/* Grid bar */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8, padding: '8px 16px',
            borderBottom: '1px solid #e2e2e2', background: '#FAFAF8', flexShrink: 0,
          }}>
            <svg width="13" height="13" viewBox="0 0 16 16" style={{ stroke: '#185FA5', fill: 'none', strokeWidth: 1.8 }}>
              <rect x="2" y="2" width="12" height="12" rx="1.5"/>
              <line x1="5" y1="6" x2="11" y2="6"/><line x1="5" y1="9" x2="11" y2="9"/>
            </svg>
            <span style={{ fontSize: 12, fontWeight: 600, color: '#4A4A4A' }}>Item Lines</span>
            <span style={{ fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 20, background: '#E6F1FB', color: '#185FA5' }}>
              {lines.filter((l) => l.itemCode).length} items
            </span>
          </div>

          {!showGrid ? (
            /* Empty state */
            <div style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
              padding: '48px 24px', gap: 10, flex: 1,
            }}>
              <div style={{ fontSize: 36, opacity: .3 }}>✏️</div>
              <div style={{ fontSize: 14, fontWeight: 600, color: '#888' }}>{emptyTitle}</div>
              <div
                style={{ fontSize: 12, color: '#888', textAlign: 'center', maxWidth: 400, lineHeight: 1.7 }}
                dangerouslySetInnerHTML={{ __html: emptySub }}
              />
            </div>
          ) : (
            <>
              <PrAmendmentLineGrid
                lines={lines}
                isReadOnly={isView}
                depCode={header?.depCode ?? ''}
                depName={header?.depName ?? ''}
                amendDate={header?.amendDate}
                prDate={header?.prDate}
                onChange={setLines}
              />
              {/* Footer summary */}
              <div style={{ background: '#fff', borderTop: '1px solid #e2e2e2', display: 'flex', flexShrink: 0 }}>
                {[
                  { lbl: 'Total Lines',    val: String(lines.length),                                                                                  sub: 'Items in this amendment' },
                  { lbl: 'Total Quantity', val: `Nos: ${lines.reduce((s, l) => s + (parseFloat(String(l.qtyInd)) || 0), 0).toFixed(3)}`, sub: 'By Unit of Measure' },
                ].map((card, i) => (
                  <div key={card.lbl} style={{ flex: 1, padding: '10px 20px', borderRight: i === 0 ? '1px solid #e2e2e2' : 'none' }}>
                    <div style={{ fontSize: 10, fontWeight: 600, color: '#888', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 2 }}>{card.lbl}</div>
                    <div style={{ fontSize: 18, fontWeight: 700, color: '#1A1A1A', lineHeight: 1.1 }}>{card.val}</div>
                    <div style={{ fontSize: 10, color: '#888', marginTop: 1 }}>{card.sub}</div>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      {/* ── Modals ────────────────────────────────────────────────────────────── */}
      {prPickerOpen && (
        <PrPickerForAmendModal
          open={prPickerOpen}
          fDate={fyStart}
          lDate={fyEnd}
          onSelect={handlePrSelected}
          onClose={() => { setPrPickerOpen(false); if (!header) resetForm() }}
        />
      )}

      {amendListOpen && (
        <PrAmendmentListModal
          open={amendListOpen}
          fDate={fyStart}
          lDate={fyEnd}
          mode={amendListMode}
          onSelect={handleAmendSelected}
          onClose={() => { setAmendListOpen(false); if (!header) resetForm() }}
        />
      )}

      <Modal
        open={printOpen}
        title={printFilename}
        onCancel={closePrint}
        footer={null}
        width="90vw"
        style={{ top: 20 }}
        styles={{ body: { padding: 0, height: '85vh' } }}
      >
        {printBlobUrl && (
          <iframe src={printBlobUrl} style={{ width: '100%', height: '100%', border: 'none' }} title={printFilename} />
        )}
      </Modal>
    </div>
  )
}
