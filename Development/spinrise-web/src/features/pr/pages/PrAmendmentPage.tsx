import { useCallback, useEffect, useRef, useState } from 'react'
import { App, Modal, Spin } from 'antd'
import { usePrAmendmentForm } from '../hooks/usePrAmendmentForm'
import { PrAmendmentHeader } from '../components/amendment/PrAmendmentHeader'
import { PrAmendmentLineGrid } from '../components/amendment/PrAmendmentLineGrid'
import * as amendApi from '../api/prAmendmentApi'
import type { AmendmentSummary, PrSummary } from '../types'
import PrAmendmentListModal from '../components/amendment/PrAmendmentListModal'
import PrPickerForAmendModal from '../components/amendment/PrPickerForAmendModal'
import { getFYBounds } from '@/shared/lib/dateUtils'

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
  const { message } = App.useApp()

  const {
    mode,
    header, lines, setLines,
    loading, saving,
    navList, navIdx,
    processingDate,
    loadForNew, loadById, loadLastAmendment,
    enterNew, enterModify, enterDelete, enterFind,
    navFirst, navPrev, navNext, navLast,
    doSave, doDelete, doDeleteLine, resetForm,
  } = usePrAmendmentForm()

  const [prPickerOpen,   setPrPickerOpen]   = useState(false)
  const [amendListOpen,  setAmendListOpen]  = useState(false)
  const [amendListMode,  setAmendListMode]  = useState<'modify' | 'delete' | 'view'>('view')
  const [printLoading,   setPrintLoading]   = useState(false)
  const [printBlobUrl,   setPrintBlobUrl]   = useState<string | null>(null)
  const [printOpen,      setPrintOpen]      = useState(false)
  const [printFilename,  setPrintFilename]  = useState('')

  // Editable header fields
  const [refNo,          setRefNo]          = useState('')
  const [amendReason,    setAmendReason]    = useState('')
  const [reasonError,    setReasonError]    = useState(false)
  const [deleteSubMode,  setDeleteSubMode]  = useState<'complete' | 'line' | null>(null)

  const { yfDate: fyStart, ylDate: fyEnd } = getFYBounds(
    processingDate ? new Date(processingDate) : undefined,
  )

  // Sync header fields when a record loads
  useEffect(() => {
    if (header) {
      setRefNo(header.refNo ?? '')
      setAmendReason(header.amendmentReason ?? '')
      setReasonError(false)
    } else if (mode === 'new') {
      setRefNo('')
      setAmendReason('')
      setReasonError(false)
    }
  }, [header, mode])

  useEffect(() => { void loadLastAmendment() }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Computed states ───────────────────────────────────────────────────────
  const isView  = mode === 'view'
  const isNew   = mode === 'new'
  const isMod   = mode === 'modify'
  const isDel   = mode === 'delete'
  const isNone  = mode === 'none'
  const hasRec  = navList.length > 0
  const editing = isNew || isMod || isDel

  const canNew    = (isView || isNone) && !saving
  const canModify = (isView || isNone) && hasRec && !saving
  const canDelete = (isView || isNone) && hasRec && !saving
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

  const handleModify = useCallback(() => {
    enterModify()
    setAmendListMode('modify')
    setAmendListOpen(true)
  }, [enterModify])

  const handleDelete = useCallback(() => {
    enterDelete()
    setAmendListMode('delete')
    setAmendListOpen(true)
  }, [enterDelete])

  const handleFind = useCallback(() => {
    enterFind()
    setAmendListMode('view')
    setAmendListOpen(true)
  }, [enterFind])

  const handleCancel = useCallback(() => {
    setDeleteSubMode(null)
    if ((isMod || isDel) && header && header.amendNo > 0) {
      void loadById(header.prNo, header.prDate, header.amendNo, 'view')
    } else if (navList.length > 0) {
      const idx = navIdx >= 0 && navIdx < navList.length ? navIdx : 0
      const rec = navList[idx]
      void loadById(rec.prNo, rec.prDate, rec.amendNo, 'view')
    } else {
      resetForm()
    }
  }, [isMod, isDel, header, navList, navIdx, loadById, resetForm])

  const handleSave = useCallback(async () => {
    if (isDel && deleteSubMode === 'complete') {
      const lbl = header ? `AMD-${String(header.amendNo).padStart(4, '0')}` : 'this amendment'
      Modal.confirm({
        icon: null,
        title: 'Confirm Delete',
        content: `This will permanently delete Amendment ${lbl} and all its line items. This cannot be undone.`,
        okText: 'Confirm Delete',
        okButtonProps: { danger: true },
        onOk: async () => { setDeleteSubMode(null); await doDelete() },
      })
    } else if (isDel && deleteSubMode === 'line') {
      message.info('Click a line in the grid to delete it.')
    } else if (isDel) {
      message.warning('Please choose Delete Amendment or Delete Line below.')
    } else {
      if (!amendReason.trim()) { setReasonError(true); message.error('Amendment Reason is required.'); return }
      setReasonError(false)
      await doSave(refNo, amendReason)
    }
  }, [isDel, header, amendReason, refNo, doSave, doDelete, message])

  const handlePrSelected = useCallback(async (pr: PrSummary) => {
    setPrPickerOpen(false)
    await loadForNew(pr.prNo, pr.prDate)
  }, [loadForNew])

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
      message.error((e as Error).message ?? 'Print failed.')
    } finally {
      setPrintLoading(false)
    }
  }, [header, printBlobUrl, message])

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
    ? 'Click <strong>New</strong> (F3) to create a new amendment, or <strong>Modify</strong> / <strong>Delete</strong> to load an existing one.'
    : mode === 'new'
      ? 'Select a PR from the popup to create a new amendment.'
      : `Select an amendment from the popup to ${mode} it.`

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden', background: '#F5F5F3' }}>

      {/* ── Doc Band ──────────────────────────────────────────────────────────── */}
      <div style={{
        background: 'linear-gradient(90deg,#0C447C 0%,#185FA5 100%)',
        padding: '0 20px', height: 30,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 11, color: 'rgba(255,255,255,.65)' }}>Purchase Order</span>
          <span style={{ fontSize: 11, color: 'rgba(255,255,255,.35)' }}>›</span>
          <span style={{ fontSize: 11, fontWeight: 600, color: '#fff' }}>Purchase Requisition Amendment</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 10, color: 'rgba(255,255,255,.5)' }}>Amendment No.</span>
          <span style={{ fontSize: 11, fontWeight: 700, color: '#fff', fontFamily: 'monospace' }}>
            {amendNoLabel}
          </span>
        </div>
      </div>

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

        {/* Modify */}
        <button
          style={tbBtn(!canModify
            ? { opacity: .4, cursor: 'not-allowed' }
            : isMod ? { background: '#E6F1FB', color: '#185FA5', borderColor: '#a8c8ea', fontWeight: 600 } : {}
          )}
          disabled={!canModify} onClick={handleModify}
        >
          ✎ <span>Modify</span>
        </button>

        {/* Delete */}
        <button
          style={tbBtn(!canDelete
            ? { color: '#A32D2D', borderColor: '#A32D2D', opacity: .4, cursor: 'not-allowed' }
            : isDel
              ? { background: '#FCEBEB', color: '#A32D2D', borderColor: '#A32D2D', fontWeight: 600 }
              : { color: '#A32D2D', borderColor: '#A32D2D' }
          )}
          disabled={!canDelete} onClick={handleDelete}
        >
          🗑 <span>Delete</span>
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
              ? { opacity: .4, cursor: 'not-allowed', ...(isDel ? { background: '#A32D2D', color: '#fff', borderColor: '#A32D2D' } : { background: '#185FA5', color: '#fff', borderColor: '#185FA5' }) }
              : isDel
                ? { background: '#A32D2D', color: '#fff', borderColor: '#A32D2D' }
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

      {/* ── Delete Banner ─────────────────────────────────────────────────────── */}
      {isDel && header && (
        <div style={{
          background: '#FCEBEB', borderBottom: '2px solid #A32D2D',
          padding: '8px 16px', flexShrink: 0,
          display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap',
        }}>
          <span style={{ fontSize: 12, color: '#A32D2D', fontWeight: 600 }}>
            ⚠ Delete mode — AMD-{String(header.amendNo).padStart(4, '0')}
          </span>
          <span style={{ fontSize: 11, color: '#A32D2D' }}>Choose deletion type:</span>
          {(['complete', 'line'] as const).map((opt) => (
            <button
              key={opt}
              onClick={() => setDeleteSubMode(opt)}
              style={{
                fontSize: 11, fontWeight: 600, padding: '3px 12px', borderRadius: 6, cursor: 'pointer',
                border: `1px solid #A32D2D`,
                background: deleteSubMode === opt ? '#A32D2D' : '#fff',
                color:      deleteSubMode === opt ? '#fff'    : '#A32D2D',
              }}
            >
              {opt === 'complete' ? 'Delete Amendment' : 'Delete Line'}
            </button>
          ))}
          {deleteSubMode === 'line' && (
            <span style={{ fontSize: 11, color: '#555', fontStyle: 'italic' }}>
              Click a line in the grid to delete it.
            </span>
          )}
        </div>
      )}

      {/* ── Content ───────────────────────────────────────────────────────────── */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

        {/* Amendment Details header */}
        <Spin spinning={loading}>
          <PrAmendmentHeader
            header={header}
            mode={mode}
            refNo={refNo}
            amendReason={amendReason}
            reasonError={reasonError}
            processingDate={processingDate}
            onRefNoChange={setRefNo}
            onAmendReasonChange={(v) => { setAmendReason(v); if (v.trim()) setReasonError(false) }}
            onFindPR={() => { if (mode === 'new') setPrPickerOpen(true) }}
          />
        </Spin>

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
                isReadOnly={isView || isDel}
                depCode={header?.depCode ?? ''}
                depName={header?.depName ?? ''}
                amendDate={header?.amendDate}
                onChange={setLines}
                onLineDelete={deleteSubMode === 'line' ? (prSno) => {
                  const lineItem = lines.find((l) => l.prSno === prSno)
                  Modal.confirm({
                    icon: null,
                    title: 'Delete Line',
                    content: `Delete line ${lineItem?.itemCode ?? prSno} (${lineItem?.itemName ?? ''}) from this amendment?`,
                    okText: 'Delete Line',
                    okButtonProps: { danger: true },
                    onOk: async () => { await doDeleteLine(prSno) },
                  })
                } : undefined}
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
