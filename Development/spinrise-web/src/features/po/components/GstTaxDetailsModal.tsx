import { useEffect, useState } from 'react'
import { Button, ConfigProvider, Input, InputNumber, Modal, Radio, Select } from 'antd'
import type { PoLine, LineTaxDetail, ScreenMode, GstTaxCodeOption } from '../types'
import type { GstHeaderDefaults } from '../hooks/usePoTransferForm'
import { notificationService } from '@/shared/lib/notification'
import { NON_NEGATIVE_INPUT_PROPS, clampNonNegativeNumber } from '../utils/poTransferRules'

// ── GST & Tax Details modal ──────────────────────────────────────────────────
//
// Layout:
//   A. Tax Config       — 3-col grid: HSN / Route / Code · TCS% / FCA-FOB
//   B. Charges + Applic — 2-col: charge grid LEFT (Discount/Packing/Insurance/Freight + Other amt-only),
//                         applicability RIGHT (Cess Position removed)
//   C. Tax Breakdown    — compact right panel
//
// Other Amount (otherAmt):
//   - New lines start at 0
//   - Saved lines load computed value from their stored otherCharges
//   - No % field shown — amount entry only
//   - Always AFTER, never affects GST base; back-calculated to otherCharges on apply
// Applicability sync (§5 / §7): seeded from GstHeaderDefaults on every open.

const fmt2 = (n: number) =>
  n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const round2 = (n: number) => Math.round(n * 100) / 100
const pctOf  = (base: number, pct: number) => round2((base * (pct || 0)) / 100)
const backCalcPer = (amt: number, base: number) =>
  base > 0 ? round2((amt / base) * 100) : 0

// ── Types ────────────────────────────────────────────────────────────────────

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
  hsnCode:          string
  taxCode:          string
  igstCode:         string
  cgstCode:         string
  sgstCode:         string
  cgstPer:          number
  sgstPer:          number
  igstPer:          number
  tcsPer:           number
  discPer:          number
  packingPer:       number
  freightPer:       number
  insurancePer:     number
  // cessPer removed — Other Amount is amount-entry only; cessTaxPos fixed 'AFTER'
  fcaFob:           number
  freightPos:       'BEFORE' | 'AFTER'
  insuranceDuty:    'BEFORE' | 'AFTER'
  freightType:      'PAID' | 'TOPAY'
  discApp:          'BEFORE' | 'AFTER'
  packApp:          'BEFORE' | 'AFTER'
  // CR-013: editable rate/qty in modal
  localRate:        number
  localQty:         number
  // CR-011: stored charge amounts (no snap-back on amount entry)
  discAmt:          number
  packingAmt:       number
  freightAmt:       number
  insuranceAmt:     number
  // Other Amount — user-entered amount; 0 for new lines, computed from stored otherCharges for saved lines
  otherAmt:         number
}

// ── Seed ─────────────────────────────────────────────────────────────────────
const seed = (line: PoLine | null, hd: GstHeaderDefaults): DraftTax => {
  const useHeader = !line?.taxSaved
  const discPer      = useHeader ? hd.discPer      : (line?.discPer      ?? 0)
  const packingPer   = useHeader ? hd.packingPer   : (line?.packingPer   ?? 0)
  const freightPer   = useHeader ? hd.freightPer   : (line?.freightPer   ?? 0)
  const insurancePer = useHeader ? hd.insurancePer : (line?.insurancePer ?? 0)
  const seedTaxable  = round2((line?.rate ?? 0) * (line?.qty ?? 0))
  const seedDiscAmt  = pctOf(seedTaxable, discPer)
  return {
    hsnCode:          line?.hsnCode    ?? '',
    taxCode:          line?.taxCode    ?? '',
    igstCode:         line?.igstCode   ?? '',
    cgstCode:         line?.cgstCode   ?? '',
    sgstCode:         line?.sgstCode   ?? '',
    cgstPer:          line?.cgstPer    ?? 0,
    sgstPer:          line?.sgstPer    ?? 0,
    igstPer:          line?.igstPer    ?? 0,
    tcsPer:           useHeader ? hd.tcsPer       : (line?.tcsPer       ?? 0),
    discPer,
    packingPer,
    freightPer,
    insurancePer,
    fcaFob:           useHeader ? hd.fcaFob       : (line?.fcaFob       ?? 0),
    // Applicability: saved lines use their stored value; unsaved lines use Header.
    freightPos:       line?.taxSaved ? (line.freightPos       ?? hd.freightPos)    : hd.freightPos,
    insuranceDuty:    line?.taxSaved ? (line.insuranceDuty    ?? hd.insuranceDuty) : hd.insuranceDuty,
    freightType:      line?.taxSaved ? (line.freightType      ?? hd.freightType)   : hd.freightType,
    discApp:          line?.taxSaved ? (line.discApp          ?? hd.discApp)       : hd.discApp,
    packApp:          line?.taxSaved ? (line.packApp          ?? hd.packApp)       : hd.packApp,
    // CR-013: editable rate/qty
    localRate:        line?.rate ?? 0,
    localQty:         line?.qty  ?? 0,
    // CR-011: stored charge amounts seeded from computed values
    discAmt:          seedDiscAmt,
    packingAmt:       pctOf(seedTaxable - seedDiscAmt, packingPer),
    freightAmt:       pctOf(seedTaxable - seedDiscAmt, freightPer),   // POT-TC-01
    insuranceAmt:     pctOf(seedTaxable - seedDiscAmt, insurancePer), // POT-TC-01
    // Other Amount: 0 for new lines; for saved lines, compute from stored otherCharges.
    otherAmt:         line?.taxSaved ? pctOf(seedTaxable, line?.otherCharges ?? 0) : 0,
  }
}

// ── Component ─────────────────────────────────────────────────────────────────

export function GstTaxDetailsModal({
  open, line, mode, gstTaxCodes, headerDefaults, onApply, onCancel,
}: GstTaxDetailsModalProps) {
  const [tax,          setTax]          = useState<DraftTax>(seed(null, headerDefaults))
  const [deleteReason, setDeleteReason] = useState('')
  const [reasonError,  setReasonError]  = useState(false)

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
  const isView = mode === 'VIEW'

  // ── Calculations ──────────────────────────────────────────────────────────
  // CR-013: taxable uses editable localRate/localQty from DraftTax
  const taxable = round2((tax.localRate || 0) * (tax.localQty || 0))

  // CR-012 / CR-010: standard Indian GST assessable base formula.
  // Charge amounts are stored in DraftTax (CR-011) — no snap-back on direct entry.
  // cessTaxPos removed from UI — Other Amount is always AFTER so it never affects gstBase.
  let gstBase = taxable
  if (tax.discApp       === 'BEFORE') gstBase = round2(gstBase - tax.discAmt)
  if (tax.freightPos    === 'BEFORE') gstBase = round2(gstBase + tax.freightAmt)
  if (tax.packApp       === 'BEFORE') gstBase = round2(gstBase + tax.packingAmt)
  if (tax.insuranceDuty === 'BEFORE') gstBase = round2(gstBase + tax.insuranceAmt)

  const cgstAmt   = isLocal ? pctOf(gstBase, tax.cgstPer) : 0
  const sgstAmt   = isLocal ? pctOf(gstBase, tax.sgstPer) : 0
  const igstAmt   = isLocal ? 0 : pctOf(gstBase, tax.igstPer)
  const tcsAmt    = pctOf(taxable, tax.tcsPer)
  const gstTotal  = round2(cgstAmt + sgstAmt + igstAmt)
  const totalTax  = round2(gstTotal + tax.otherAmt + tcsAmt)
  const netAmount = round2(
    taxable - tax.discAmt + tax.packingAmt + tax.freightAmt + tax.insuranceAmt + totalTax,
  )

  // ── State helpers ─────────────────────────────────────────────────────────
  const set = <K extends keyof DraftTax>(k: K, v: DraftTax[K]) =>
    setTax((p) => ({ ...p, [k]: v }))

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

  // CR-011: % change → update per + re-derive stored amount (no snap-back)
  const setDiscPer  = (v: number | null) => {
    const per = clampNonNegativeNumber(v); setTax((p) => ({ ...p, discPer: per, discAmt: pctOf(taxable, per) }))
  }
  const setPackPer  = (v: number | null) => {
    const per = clampNonNegativeNumber(v); setTax((p) => ({ ...p, packingPer: per, packingAmt: pctOf(taxable - p.discAmt, per) }))
  }
  const setFrePer   = (v: number | null) => {
    const per = clampNonNegativeNumber(v)
    setTax((p) => ({ ...p, freightPer: per, freightAmt: pctOf(round2(taxable - p.discAmt), per) }))  // POT-TC-01
  }
  const setInsurPer = (v: number | null) => {
    const per = clampNonNegativeNumber(v)
    setTax((p) => ({ ...p, insurancePer: per, insuranceAmt: pctOf(round2(taxable - p.discAmt), per) })) // POT-TC-01
  }

  // Amount change → store directly + back-compute per only (amount stays as typed)
  const onDiscAmt  = (v: number | null) =>
    setTax((p) => ({ ...p, discAmt: clampNonNegativeNumber(v), discPer: backCalcPer(clampNonNegativeNumber(v), taxable) }))
  const onPackAmt  = (v: number | null) =>
    setTax((p) => ({ ...p, packingAmt: clampNonNegativeNumber(v), packingPer: backCalcPer(clampNonNegativeNumber(v), taxable - p.discAmt) }))
  // POT-TC-01: back-calc % against net-after-discount so the stored % round-trips correctly
  const onFreAmt   = (v: number | null) =>
    setTax((p) => ({ ...p, freightAmt: clampNonNegativeNumber(v), freightPer: backCalcPer(clampNonNegativeNumber(v), round2(taxable - p.discAmt)) }))
  const onInsurAmt = (v: number | null) =>
    setTax((p) => ({ ...p, insuranceAmt: clampNonNegativeNumber(v), insurancePer: backCalcPer(clampNonNegativeNumber(v), round2(taxable - p.discAmt)) }))
  // Other Amount — direct entry only, no % field
  const onOtherAmt = (v: number | null) =>
    setTax((p) => ({ ...p, otherAmt: clampNonNegativeNumber(v) }))

  // ── Apply ─────────────────────────────────────────────────────────────────
  const handleApply = () => {
    if (isDelete && !deleteReason.trim()) {
      setReasonError(true)
      notificationService.warning('Delete Reason Required', 'A delete reason is mandatory.')
      return
    }
    // CR-036: qty must be > 0
    if (!isDelete && tax.localQty <= 0) {
      notificationService.warning('Invalid Quantity', 'Quantity must be greater than zero.')
      return
    }
    if (!isDelete && !tax.hsnCode.trim()) {
      notificationService.warning('HSN Code Required', 'HSN Code is mandatory before saving GST details.')
      return
    }
    const detail: LineTaxDetail = {
      hsnCode:          tax.hsnCode.trim(),
      taxCode:          tax.taxCode.trim(),
      igstCode:         tax.igstCode.trim(),
      cgstCode:         tax.cgstCode.trim(),
      sgstCode:         tax.sgstCode.trim(),
      cgstPer:          tax.cgstPer,
      sgstPer:          tax.sgstPer,
      igstPer:          tax.igstPer,
      tcsPer:           tax.tcsPer,
      discPer:          tax.discPer,
      packingPer:       tax.packingPer,
      freightPer:       tax.freightPer,
      insurancePer:     tax.insurancePer,
      // Back-calculate otherCharges from user-entered Other Amount for SP compatibility
      // (SP receives otherCharges as the cessPer column; always AFTER so it never shifts GST base).
      otherCharges:         backCalcPer(tax.otherAmt, taxable),
      fcaFob:           tax.fcaFob,
      addTaxCode:       '',    // CR-011a: removed from modal
      addTaxPer:        0,     // CR-011a: removed from modal
      freightPos:       tax.freightPos,
      insuranceDuty:    tax.insuranceDuty,
      freightType:      tax.freightType,
      discApp:          tax.discApp,
      packApp:          tax.packApp,
      // CR-013: propagate edited rate/qty back to the line
      rate: tax.localRate,
      qty:  tax.localQty,
    }
    onApply(line.lineNo, { detail, deleteReason: isDelete ? deleteReason.trim() : undefined })
  }

  const codeOptions = gstTaxCodes.map((t) => ({
    value: t.taxCode,
    label: `${t.taxCode} — ${t.taxDesc}`,
  }))

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <ConfigProvider theme={readableDisabled}>
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width="min(90vw, 1000px)"
      destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: '#1a1a1a' }}>GST &amp; Tax Details</span>
            <RouteChip route={line.route} />
          </div>
          <div style={{ fontSize: 12, color: '#888', marginTop: 2, display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
            <span>
              <span style={{ fontFamily: 'monospace', fontWeight: 600, color: '#185FA5' }}>{line.itemCode}</span>
              <span style={{ margin: '0 4px', color: '#ccc' }}>·</span>
              <span style={{ color: '#555' }}>{line.itemName}</span>
            </span>
            <span style={{ color: '#ccc' }}>|</span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <label style={{ fontSize: 11, color: '#888' }}>Qty</label>
              <InputNumber
                {...NON_NEGATIVE_INPUT_PROPS}
                size="small" precision={3} controls={false} disabled={isDelete || isView}
                value={tax.localQty}
                style={{ width: 90, fontFamily: 'monospace', textAlign: 'right' }}
                onChange={(v) => set('localQty', clampNonNegativeNumber(v))}
              />
              <label style={{ fontSize: 11, color: '#888', marginLeft: 4 }}>Rate</label>
              <InputNumber
                {...NON_NEGATIVE_INPUT_PROPS}
                size="small" precision={4} controls={false} disabled={isDelete || isView}
                value={tax.localRate}
                style={{ width: 110, fontFamily: 'monospace', textAlign: 'right' }}
                onChange={(v) => set('localRate', clampNonNegativeNumber(v))}
              />
            </span>
          </div>
        </div>
      }
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 250px' }}>

        {/* ── Left panel ──────────────────────────────────────────────────── */}
        <div style={{ padding: '10px 14px', borderRight: '1px solid #eee' }}>

          {/* ── Section A: Tax Configuration ──────────────────────────────── */}
          {SL('A · Tax Configuration')}
          <div style={grid3}>
            <Field label="HSN Code">
              <Input
                size="small" style={mono} value={tax.hsnCode} placeholder="HSN"
                status={!tax.hsnCode.trim() ? 'warning' : undefined}
                onChange={(e) => set('hsnCode', e.target.value)}
              />
            </Field>
            <Field label="GST Route">
              <Select
                size="small" style={full} value={line.route} disabled
                options={[
                  { value: 'LOCAL', label: 'LOCAL (CGST + SGST)' },
                  { value: 'IGST',  label: 'IGST' },
                ]}
              />
            </Field>
            <Field label="GST Tax Code">
              <Select
                size="small" style={full} showSearch optionFilterProp="label"
                placeholder="Select code" value={tax.taxCode || undefined}
                options={codeOptions} onChange={onGstCodeChange}
                notFoundContent={gstTaxCodes.length ? undefined : 'No codes loaded'}
                disabled={isDelete || isView}
              />
            </Field>
            <Field label="TCS %">
              <InputNumber
                {...NON_NEGATIVE_INPUT_PROPS}
                size="small" precision={2} controls={false}
                style={{ ...full, ...monoR }} value={tax.tcsPer}
                onChange={(v) => set('tcsPer', clampNonNegativeNumber(v))}
                disabled={isDelete || isView}
              />
            </Field>
            <Field label="FCA / FOB">
              <InputNumber
                {...NON_NEGATIVE_INPUT_PROPS}
                size="small" precision={2} controls={false}
                style={{ ...full, ...monoR }} value={tax.fcaFob}
                onChange={(v) => set('fcaFob', clampNonNegativeNumber(v))} disabled={isDelete || isView}
              />
            </Field>
          </div>

          <div style={divider} />

          {/* ── Section B: Commercial Charges + Applicability (side-by-side) ─ */}
          {SL('B · Commercial Charges & Applicability')}
          <div style={{ display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0 18px', alignItems: 'start' }}>

            {/* Left: Charge grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: '108px 72px 80px',
              columnGap: 5,
              rowGap: 3,
              alignItems: 'center',
            }}>
              {/* Column headers */}
              <span style={colHdr}>Charge</span>
              <span style={{ ...colHdr, textAlign: 'right' }}>%</span>
              <span style={{ ...colHdr, textAlign: 'right' }}>Amount</span>
              {/* Rows — ChargeRow renders 3 naked cells each */}
              <ChargeRow label="Discount"  per={tax.discPer}      amt={tax.discAmt}      disabled={isDelete || isView}
                onPer={setDiscPer}  onAmt={onDiscAmt}  />
              <ChargeRow label="Packing"   per={tax.packingPer}   amt={tax.packingAmt}   disabled={isDelete || isView}
                onPer={setPackPer}  onAmt={onPackAmt}  />
              <ChargeRow label="Insurance" per={tax.insurancePer} amt={tax.insuranceAmt} disabled={isDelete || isView}
                onPer={setInsurPer} onAmt={onInsurAmt} />
              <ChargeRow label="Freight"   per={tax.freightPer}   amt={tax.freightAmt}   disabled={isDelete || isView}
                onPer={setFrePer}   onAmt={onFreAmt}   />
              {/* Other — Amount entry only; no % field */}
              <span style={{ fontSize: 11, color: '#444' }}>Other Charges</span>
              <span />
              <InputNumber
                {...NON_NEGATIVE_INPUT_PROPS}
                size="small" precision={2} controls={false}
                style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
                value={tax.otherAmt} onChange={onOtherAmt} disabled={isDelete || isView}
              />
            </div>

            {/* Right: Applicability — compact Radio controls (Cess Position removed) */}
            <div style={{
              borderLeft: '1px solid #f0f0f0',
              paddingLeft: 14,
              display: 'flex',
              flexDirection: 'column',
              gap: 5,
            }}>
              <AppRadio label="Discount Application" value={tax.discApp}      disabled={isDelete || isView}
                onChange={(v) => set('discApp',       v as 'BEFORE' | 'AFTER')}
                options={[{ value: 'BEFORE', label: 'Before Tax' }, { value: 'AFTER', label: 'After Tax' }]} />
              <AppRadio label="Packing Application"  value={tax.packApp}      disabled={isDelete || isView}
                onChange={(v) => set('packApp',       v as 'BEFORE' | 'AFTER')}
                options={[{ value: 'BEFORE', label: 'Before Tax' }, { value: 'AFTER', label: 'After Tax' }]} />
              <AppRadio label="Insurance Position"   value={tax.insuranceDuty} disabled={isDelete || isView}
                onChange={(v) => set('insuranceDuty', v as 'BEFORE' | 'AFTER')}
                options={[{ value: 'BEFORE', label: 'Before Duty' }, { value: 'AFTER', label: 'After Duty' }]} />
              <AppRadio label="Freight Position"     value={tax.freightPos}   disabled={isDelete || isView}
                onChange={(v) => set('freightPos',    v as 'BEFORE' | 'AFTER')}
                options={[{ value: 'BEFORE', label: 'Before Tax' }, { value: 'AFTER', label: 'After Tax' }]} />
              <AppRadio label="Freight Payment"      value={tax.freightType}  disabled={isDelete || isView}
                onChange={(v) => set('freightType',   v as 'PAID' | 'TOPAY')}
                options={[{ value: 'PAID', label: 'Paid' }, { value: 'TOPAY', label: 'To Pay' }]} />
            </div>

          </div>

          {/* DELETE mode: per-line delete reason — BR-04 */}
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

        {/* ── RIGHT PANEL: Tax Breakdown — always fully visible, no collapse ─── */}
        <div style={{ background: '#f8fafc', display: 'flex', flexDirection: 'column' }}>
          <div style={{ padding: '10px 10px 6px' }}>{SL('C · Tax Breakdown')}</div>

          {/* Single card: all rows + Net Amount band — nothing hidden */}
          <div style={{
            margin: '0 8px 8px',
            background: '#fff',
            border: '1px solid #e2e8f0',
            borderRadius: 6,
            overflow: 'hidden',
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
          }}>
            <SR label="Value"      value={taxable}          strong />
            <div style={summaryDiv} />
            <SR label="Discount"   value={tax.discAmt}      muted />
            <SR label="Packing"    value={tax.packingAmt}   muted />
            <SR label="Freight"    value={tax.freightAmt}   muted />
            <SR label="Insurance"  value={tax.insuranceAmt} muted />
            <SR label="Other Charges"      value={tax.otherAmt}     muted />
            <div style={summaryDiv} />
            {isLocal ? (
              <>
                <SR label={`CGST ${fmt2(tax.cgstPer)}%`}  value={cgstAmt} />
                <SR label={`SGST ${fmt2(tax.sgstPer)}%`}  value={sgstAmt} />
              </>
            ) : (
              <SR label={`IGST ${fmt2(tax.igstPer)}%`}    value={igstAmt} />
            )}
            <SR label={`TCS ${fmt2(tax.tcsPer)}%`}         value={tcsAmt} />
            {/* Net Amount — last row of the card, always visible */}
            <div style={{ marginTop: 'auto' }}>
              <div style={{
                background: '#185FA5', padding: '8px 10px',
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              }}>
                <span style={{ fontSize: 12, fontWeight: 700, color: '#b8d4ef', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                  Net Amount
                </span>
                <span style={{ fontSize: 16, fontWeight: 800, fontFamily: 'monospace', color: '#fff' }}>
                  ₹{fmt2(netAmount)}
                </span>
              </div>
            </div>
          </div>
        </div>

      </div>

      {/* Footer: Requester LEFT · Buttons RIGHT */}
      <div style={{
        background: '#f8fafc', borderTop: '1px solid #e2e2e2',
        padding: '7px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <span style={{ fontSize: 12, color: '#888' }}>
          {(line.requesterId || line.requesterName)
            ? <>Requester: <b style={{ color: '#444' }}>{line.requesterName || line.requesterId}</b></>
            : null}
        </span>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button size="middle" onClick={onCancel}>Cancel</Button>
          {
            !isView && <Button size="middle" type="primary" onClick={handleApply}>
            {isDelete ? 'Apply & Close' : 'Save & Update'}
          </Button>
          }
        </div>
      </div>
    </Modal>
    </ConfigProvider>
  )
}

// ── Presentational helpers ───────────────────────────────────────────────────

function RouteChip({ route }: { route: string }) {
  const isLocal = route === 'LOCAL'
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, padding: '1px 6px', borderRadius: 3,
      background: isLocal ? '#E6F1FB' : '#F3EEFF',
      color:      isLocal ? '#185FA5' : '#722ED1',
      whiteSpace: 'nowrap',
    }}>
      {route}
    </span>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      <label style={{ fontSize: 12, fontWeight: 500, color: '#535353' }}>{label}</label>
      {children}
    </div>
  )
}

// ChargeRow contributes 3 naked cells into the parent charge grid.
function ChargeRow({
  label, per, amt, onPer, onAmt, disabled,
}: {
  label:    string
  per:      number
  amt:      number
  onPer:    (v: number | null) => void
  onAmt:    (v: number | null) => void
  disabled: boolean
}) {
  return (
    <>
      <span style={{ fontSize: 11, color: '#444' }}>{label}</span>
      <InputNumber
        {...NON_NEGATIVE_INPUT_PROPS}
        size="small" precision={2} controls={false}
        style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
        value={per} onChange={onPer} disabled={disabled}
      />
      <InputNumber
        {...NON_NEGATIVE_INPUT_PROPS}
        size="small" precision={2} controls={false}
        style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
        value={amt} onChange={onAmt} disabled={disabled}
      />
    </>
  )
}

// Compact plain Radio.Group — ERP standard (circles, not button-group style).
function AppRadio({
  label,
  value,
  options,
  onChange,
  disabled,
}: {
  label: string
  value: string
  options: { value: string; label: string }[]
  onChange: (v: string) => void
  disabled: boolean
}) {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: '140px 1fr',
        alignItems: 'center',
        columnGap: 12,
        minHeight: 30,
      }}
    >
      <label
        style={{
          fontSize: 12,
          fontWeight: 500,
          color: '#414040',
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </label>

      <Radio.Group
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value as string)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 16,
        }}
      >
        {options.map((opt) => (
          <Radio
            key={opt.value}
            value={opt.value}
            style={{
              margin: 0,
              fontSize: 12,
              whiteSpace: 'nowrap',
            }}
          >
            {opt.label}
          </Radio>
        ))}
      </Radio.Group>
    </div>
  )
}

// SR = compact summary row for the right panel.
function SR({ label, value, strong, muted, accent }: {
  label:   string
  value:   number
  strong?: boolean
  muted?:  boolean
  accent?: string
}) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '4px 10px',
    }}>
      <span style={{
        fontSize: 12, fontWeight: strong ? 700 : 500,
        color: muted ? '#515152' : '#4b5563',
      }}>
        {label}
      </span>
      <span style={{
        fontSize: strong ? 13 : 12, fontFamily: 'monospace',
        fontWeight: strong || accent ? 700 : 600,
        color: accent ?? (muted ? '#6b7280' : '#1a1a1a'),
      }}>
        {fmt2(value)}
      </span>
    </div>
  )
}

// SL = section label
const SL = (text: string) => (
  <div style={{
    fontSize: 10, fontWeight: 700, color: '#181818',
    textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 6,
  }}>
    {text}
  </div>
)

// AntD 5 disabled fields use the colorTextDisabled token — inline style has no
// effect. Override the token here so disabled values stay fully readable in VIEW.
const readableDisabled = {
  token: { colorTextDisabled: '#262626', colorBgContainerDisabled: '#f5f5f5' },
}

// ── Styles ────────────────────────────────────────────────────────────────────
const full: React.CSSProperties     = { width: '100%' }
const mono: React.CSSProperties     = { fontFamily: 'monospace' }
const monoR: React.CSSProperties    = { fontFamily: 'monospace', textAlign: 'right' }
const grid3: React.CSSProperties    = { display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }
const divider: React.CSSProperties  = { height: 1, background: '#e8e8e8', margin: '8px 0' }
const summaryDiv: React.CSSProperties = { height: 1, background: '#eef2f6', margin: '2px 0' }
const colHdr: React.CSSProperties   = {
  fontSize: 10, fontWeight: 700, color: '#383838',
  textTransform: 'uppercase', letterSpacing: '0.05em', paddingBottom: 2,
}
