import { useEffect, useState } from 'react'
import { Button, Input, InputNumber, Modal, Select } from 'antd'
import type { PoLine, LineTaxDetail, ScreenMode, GstTaxCodeOption } from '../types'
import type { GstHeaderDefaults } from '../hooks/usePoTransferForm'
import { notificationService } from '@/shared/lib/notification'

// ── GST & Tax Details modal ──────────────────────────────────────────────────
//
// Modern re-imagining of the legacy "Tax Calculation" popup (functional ref only).
// GST-based taxation ONLY — pre-GST BED/AED/Cess/Surcharge (NOT FOR SPINRISE) are
// absent. Three sections:
//   A. Tax Configuration — GST Tax Code, GST Route (server-driven, read-only per
//      FSD §5.6/D-07), Additional Tax Code, TCS %.
//   B. Commercial Charges — Discount / Packing / Freight / Insurance %, FCA/FOB.
//   C. Tax Breakdown — live auto-calculated summary card.
// The math mirrors recalcLine in usePoTransferForm (single source of truth); this
// modal only previews it. Unsaved lines seed charges from the LATEST header (§7);
// once saved (taxSaved) they reload the row's own values.

const fmt2 = (n: number) =>
  n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const round2 = (n: number) => Math.round(n * 100) / 100
const pctOf = (base: number, pct: number) => round2((base * (pct || 0)) / 100)

interface GstTaxDetailsModalProps {
  open:           boolean
  line:           PoLine | null
  mode:           ScreenMode
  gstTaxCodes:    GstTaxCodeOption[]
  headerDefaults: GstHeaderDefaults
  onApply:        (lineNo: number, payload: { detail: LineTaxDetail; deleteReason?: string }) => void
  onCancel:       () => void
}

interface DraftTax {
  hsnCode:      string
  taxCode:      string
  igstCode:     string
  cgstCode:     string
  sgstCode:     string
  cgstPer:      number
  sgstPer:      number
  igstPer:      number
  tcsPer:       number
  discPer:      number
  packingPer:   number
  freightPer:   number
  insurancePer: number
  fcaFob:       number
  addTaxCode:   string
  addTaxPer:    number
}

// Seed the draft from the line; for an UNSAVED line, charge/additional-tax/TCS
// defaults come from the LATEST header values (§7) rather than the line's seed.
const seed = (line: PoLine | null, hd: GstHeaderDefaults): DraftTax => {
  const useHeader = !line?.taxSaved
  return {
    hsnCode:      line?.hsnCode  ?? '',
    taxCode:      line?.taxCode  ?? '',
    igstCode:     line?.igstCode ?? '',
    cgstCode:     line?.cgstCode ?? '',
    sgstCode:     line?.sgstCode ?? '',
    cgstPer:      line?.cgstPer  ?? 0,
    sgstPer:      line?.sgstPer  ?? 0,
    igstPer:      line?.igstPer  ?? 0,
    addTaxCode:   line?.addTaxCode ?? '',
    tcsPer:       useHeader ? hd.tcsPer       : (line?.tcsPer       ?? 0),
    discPer:      useHeader ? hd.discPer      : (line?.discPer      ?? 0),
    packingPer:   useHeader ? hd.packingPer   : (line?.packingPer   ?? 0),
    freightPer:   useHeader ? hd.freightPer   : (line?.freightPer   ?? 0),
    insurancePer: useHeader ? hd.insurancePer : (line?.insurancePer ?? 0),
    fcaFob:       useHeader ? hd.fcaFob       : (line?.fcaFob       ?? 0),
    addTaxPer:    useHeader ? hd.addTaxPer    : (line?.addTaxPer    ?? 0),
  }
}

const labelChip = (text: string, bg: string, color: string) => (
  <span style={{
    fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 3,
    background: bg, color, whiteSpace: 'nowrap',
  }}>
    {text}
  </span>
)

export function GstTaxDetailsModal({
  open, line, mode, gstTaxCodes, headerDefaults, onApply, onCancel,
}: GstTaxDetailsModalProps) {
  const [tax, setTax] = useState<DraftTax>(seed(null, headerDefaults))
  const [deleteReason, setDeleteReason] = useState('')
  const [reasonError, setReasonError] = useState(false)

  // Re-seed on open / line change. headerDefaults is read at open time only — a
  // mid-edit header change must not clobber the user's in-progress edits.
  useEffect(() => {
    if (open && line) {
      setTax(seed(line, headerDefaults))
      setDeleteReason(line.deleteReason ?? '')
      setReasonError(false)
    }
  }, [open, line]) // eslint-disable-line react-hooks/exhaustive-deps

  if (!line) return null

  const isLocal  = line.route === 'LOCAL'
  const isDelete = mode === 'DELETE'
  

  // ── Live breakdown (mirrors recalcLine) ─────────────────────────────────────
  const taxable      = round2((line.rate || 0) * (line.qty || 0))
  const discountAmt  = pctOf(taxable, tax.discPer)
  const packingAmt   = pctOf(taxable - discountAmt, tax.packingPer)
  const freightAmt   = pctOf(taxable, tax.freightPer)
  const insuranceAmt = pctOf(taxable, tax.insurancePer)
  const cgstAmt      = isLocal ? pctOf(taxable, tax.cgstPer) : 0
  const sgstAmt      = isLocal ? pctOf(taxable, tax.sgstPer) : 0
  const igstAmt      = isLocal ? 0 : pctOf(taxable, tax.igstPer)
  const addTaxAmt    = pctOf(taxable, tax.addTaxPer)
  const tcsAmt       = pctOf(taxable, tax.tcsPer)
  const totalTax     = round2(cgstAmt + sgstAmt + igstAmt + addTaxAmt + tcsAmt)
  const netAmount    = round2(
    taxable - discountAmt + packingAmt + freightAmt + insuranceAmt + totalTax,
  )

  const set = <K extends keyof DraftTax>(k: K, v: DraftTax[K]) =>
    setTax((p) => ({ ...p, [k]: v }))

  // Selecting a GST Tax Code prefills its CGST/SGST/IGST rates (Section C amounts
  // recompute live). The codes are mirrored so the save payload stays consistent.
  const onGstCodeChange = (code: string) => {
    const opt = gstTaxCodes.find((t) => t.taxCode === code)
    setTax((p) => ({
      ...p,
      taxCode:  code,
      igstCode: isLocal ? p.igstCode : code,
      cgstCode: isLocal ? code : p.cgstCode,
      sgstCode: isLocal ? code : p.sgstCode,
      cgstPer:  opt ? opt.cgstPer : p.cgstPer,
      sgstPer:  opt ? opt.sgstPer : p.sgstPer,
      igstPer:  opt ? opt.igstPer : p.igstPer,
    }))
  }

  // Additional Tax Code reuses the GST tax-code master. Selecting one prefills a
  // single combined % (editable) — GST codes carry no dedicated additional rate.
  const onAddTaxCodeChange = (code: string) => {
    const opt = gstTaxCodes.find((t) => t.taxCode === code)
    const combined = opt ? (opt.igstPer || round2(opt.cgstPer + opt.sgstPer)) : 0
    setTax((p) => ({ ...p, addTaxCode: code, addTaxPer: opt ? combined : p.addTaxPer }))
  }

  const handleApply = () => {
    if (isDelete && !deleteReason.trim()) {
      setReasonError(true)
      notificationService.warning('Delete Reason Required', 'A delete reason is mandatory.')   // BR-04
      return
    }
    if (!isDelete && !tax.hsnCode.trim()) {
      notificationService.warning('HSN Code Required', 'HSN Code is mandatory before saving GST details.')   // BR-10
      return
    }
    const detail: LineTaxDetail = {
      hsnCode:      tax.hsnCode.trim(),
      taxCode:      tax.taxCode.trim(),
      igstCode:     tax.igstCode.trim(),
      cgstCode:     tax.cgstCode.trim(),
      sgstCode:     tax.sgstCode.trim(),
      cgstPer:      tax.cgstPer,
      sgstPer:      tax.sgstPer,
      igstPer:      tax.igstPer,
      tcsPer:       tax.tcsPer,
      discPer:      tax.discPer,
      packingPer:   tax.packingPer,
      freightPer:   tax.freightPer,
      insurancePer: tax.insurancePer,
      fcaFob:       tax.fcaFob,
      addTaxCode:   tax.addTaxCode.trim(),
      addTaxPer:    tax.addTaxPer,
    }
    onApply(line.lineNo, { detail, deleteReason: isDelete ? deleteReason.trim() : undefined })
  }

  const codeOptions = gstTaxCodes.map((t) => ({
    value: t.taxCode,
    label: `${t.taxCode} — ${t.taxDesc}`,
  }))

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width={880}
      destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: '#1a1a1a' }}>GST &amp; Tax Details</span>
            {labelChip(isLocal ? 'LOCAL' : 'IGST',
              isLocal ? '#E6F1FB' : '#F3EEFF',
              isLocal ? '#185FA5' : '#722ED1')}
          </div>
          <div style={{ fontSize: 11, color: '#888', marginTop: 3 }}>
            <span style={{ fontFamily: 'monospace', fontWeight: 600, color: '#185FA5' }}>{line.itemCode}</span>
            <span style={{ margin: '0 4px' }}>·</span>
            <span>{line.itemName}</span>
            <span style={{ margin: '0 6px', color: '#ccc' }}>|</span>
            <span>Qty {line.qty} × Rate {fmt2(line.rate)}</span>
          </div>
        </div>
      }
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 0 }}>
        {/* ── Left: inputs (Sections A + B) ─────────────────────────────────── */}
        <div style={{ padding: '14px 18px', borderRight: '1px solid #eee' }}>
          {/* Section A — Tax Configuration */}
          {sectionLabel('A · Tax Configuration')}
          <div style={grid2}>
            <Field label="HSN Code">
              <Input
                size="small" style={mono} value={tax.hsnCode} placeholder="HSN"
                status={!tax.hsnCode.trim() ? 'warning' : undefined}   // BR-10
                onChange={(e) => set('hsnCode', e.target.value)}
              />
            </Field>
            <Field label="GST Route">
              {/* Server-resolved (FSD §5.6/D-07) — read-only. */}
              <Select
                size="small" style={full} value={line.route} disabled
                options={[{ value: 'LOCAL', label: 'LOCAL (CGST + SGST)' }, { value: 'IGST', label: 'IGST' }]}
              />
            </Field>
            <Field label="GST Tax Code">
              <Select
                size="small" style={full} showSearch optionFilterProp="label"
                placeholder="Select GST tax code" value={tax.taxCode || undefined}
                options={codeOptions} onChange={onGstCodeChange}
                notFoundContent={gstTaxCodes.length ? undefined : 'No tax codes loaded'}
              />
            </Field>
            <Field label="Additional Tax Code">
              <Select
                size="small" style={full} showSearch optionFilterProp="label" allowClear
                placeholder="Optional" value={tax.addTaxCode || undefined}
                options={codeOptions}
                onChange={(v) => onAddTaxCodeChange(v ?? '')}
              />
            </Field>
            <Field label="Additional Tax %">
              <InputNumber
                size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.addTaxPer} onChange={(v) => set('addTaxPer', v ?? 0)}
              />
            </Field>
            <Field label="TCS %">
              <InputNumber
                size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.tcsPer} onChange={(v) => set('tcsPer', v ?? 0)}
              />
            </Field>
          </div>

          <div style={divider} />

          {/* Section B — Commercial Charges */}
          {sectionLabel('B · Commercial Charges')}
          <div style={grid2}>
            <Field label="Discount %">
              <InputNumber size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.discPer} onChange={(v) => set('discPer', v ?? 0)} disabled={isDelete} />
            </Field>
            <Field label="Packing %">
              <InputNumber size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.packingPer} onChange={(v) => set('packingPer', v ?? 0)} disabled={isDelete} />
            </Field>
            <Field label="Freight %">
              <InputNumber size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.freightPer} onChange={(v) => set('freightPer', v ?? 0)} disabled={isDelete} />
            </Field>
            <Field label="Insurance %">
              <InputNumber size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.insurancePer} onChange={(v) => set('insurancePer', v ?? 0)} disabled={isDelete} />
            </Field>
            <Field label="FCA / FOB Charges">
              <InputNumber size="small" min={0} precision={2} controls={false} style={{ ...full, ...mono }}
                value={tax.fcaFob} onChange={(v) => set('fcaFob', v ?? 0)} disabled={isDelete} />
            </Field>
          </div>

          {/* Requester (read-only) */}
          <div style={divider} />
          <div style={{ display: 'flex', gap: 16, fontSize: 11, color: '#888' }}>
            <span>Requester: <b style={{ color: '#555' }}>{line.requesterId || '—'}</b></span>
            <span>{line.requesterName}</span>
          </div>

          {/* Delete reason (DELETE mode only) — BR-04 */}
          {isDelete && (
            <>
              <div style={divider} />
              <Field label="Delete Reason *">
                <Input
                  size="small" style={full} value={deleteReason}
                  status={reasonError ? 'error' : undefined}
                  placeholder="Enter delete reason (mandatory)…"
                  onChange={(e) => { setDeleteReason(e.target.value); setReasonError(false) }}
                />
              </Field>
            </>
          )}
        </div>

        {/* ── Right: Section C — Tax Breakdown summary card ─────────────────── */}
        <div style={{ padding: '14px 16px', background: '#f8fafc' }}>
          {sectionLabel('C · Tax Breakdown')}
          <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 8, overflow: 'hidden' }}>
            <SummaryRow label="Taxable Value" value={taxable} strong />
            <SummaryRow label="Discount" value={-discountAmt} muted />
            <SummaryRow label="Packing" value={packingAmt} muted />
            <SummaryRow label="Freight" value={freightAmt} muted />
            <SummaryRow label="Insurance" value={insuranceAmt} muted />
            <div style={summaryDiv} />
            {isLocal ? (
              <>
                <SummaryRow label={`CGST (${fmt2(tax.cgstPer)}%)`} value={cgstAmt} />
                <SummaryRow label={`SGST (${fmt2(tax.sgstPer)}%)`} value={sgstAmt} />
              </>
            ) : (
              <SummaryRow label={`IGST (${fmt2(tax.igstPer)}%)`} value={igstAmt} />
            )}
            <SummaryRow label={`Additional Tax (${fmt2(tax.addTaxPer)}%)`} value={addTaxAmt} />
            <SummaryRow label={`TCS (${fmt2(tax.tcsPer)}%)`} value={tcsAmt} />
            <div style={summaryDiv} />
            <SummaryRow label="Total Tax" value={totalTax} accent="#b45309" />
            <div style={{ background: '#185FA5', padding: '10px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: '#cfe2f5', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Net Amount</span>
              <span style={{ fontSize: 17, fontWeight: 800, fontFamily: 'monospace', color: '#fff' }}>₹{fmt2(netAmount)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Footer actions */}
      <div style={{
        background: '#f8fafc', borderTop: '1px solid #e2e2e2', padding: '10px 18px',
        display: 'flex', justifyContent: 'flex-end', gap: 8,
      }}>
        <Button onClick={onCancel}>Cancel</Button>
        <Button type="primary" onClick={handleApply}>
          {isDelete ? 'Apply & Close' : 'Save & Update'}
        </Button>
      </div>
    </Modal>
  )
}

// ── Presentational helpers ───────────────────────────────────────────────────

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <label style={{ fontSize: 10, fontWeight: 500, color: '#888' }}>{label}</label>
      {children}
    </div>
  )
}

function SummaryRow({ label, value, strong, muted, accent }: {
  label: string; value: number; strong?: boolean; muted?: boolean; accent?: string
}) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '6px 12px',
    }}>
      <span style={{ fontSize: 11, color: muted ? '#9ca3af' : '#4b5563', fontWeight: strong ? 700 : 500 }}>{label}</span>
      <span style={{
        fontSize: strong ? 13 : 12, fontFamily: 'monospace',
        fontWeight: strong || accent ? 700 : 600, color: accent ?? (muted ? '#6b7280' : '#1a1a1a'),
      }}>
        {fmt2(value)}
      </span>
    </div>
  )
}

const sectionLabel = (text: string) => (
  <div style={{
    fontSize: 10, fontWeight: 700, color: '#888', textTransform: 'uppercase',
    letterSpacing: '0.06em', marginBottom: 10,
  }}>
    {text}
  </div>
)

// ── Local styles ─────────────────────────────────────────────────────────────
const full: React.CSSProperties = { width: '100%' }
const mono: React.CSSProperties = { fontFamily: 'monospace' }
const grid2: React.CSSProperties = { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }
const divider: React.CSSProperties = { height: 1, background: '#e2e2e2', margin: '12px 0' }
const summaryDiv: React.CSSProperties = { height: 1, background: '#eef2f6', margin: '2px 0' }
