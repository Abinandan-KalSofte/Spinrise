import { useEffect, useState } from 'react'
import { Button, Input, InputNumber, Modal } from 'antd'
import type { PoLine, LineTaxDetail, ScreenMode } from '../types'
import { modalTh } from '@/shared/styles/erpTable'
import { notificationService } from '@/shared/lib/notification'

// ── GST & Tax Details modal (HTML #gst-modal-overlay) ────────────────────────
//
// Controlled collector: gathers HSN / tax codes / GST rates / TCS (and, in
// DELETE mode, the per-line delete reason) and hands them back via onApply.
// It does NOT decide the supply route — `line.route` is SERVER-SUPPLIED (Q4);
// the modal only shows the matching CGST+SGST or IGST block. It performs no
// business-rule threshold checks (those live in usePoTransferForm); the only
// inline guard is the BR-04 delete-reason required field, which the hook also
// re-enforces at delete confirm.

const fmt2 = (n: number) =>
  n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const round2 = (n: number) => Math.round(n * 100) / 100

interface GstTaxDetailsModalProps {
  open:           boolean
  line:           PoLine | null
  mode:           ScreenMode
  onApply:        (lineNo: number, payload: { detail: LineTaxDetail; deleteReason?: string }) => void
  onCancel:       () => void
  onTaxCodeLookup?: () => void   // IG_TAX lookup (separate modal — out of scope here)
}

interface DraftTax {
  hsnCode:  string
  taxCode:  string
  igstCode: string
  cgstCode: string
  sgstCode: string
  cgstPer:  number
  sgstPer:  number
  igstPer:  number
  tcsPer:   number
}

const seed = (line: PoLine | null): DraftTax => ({
  hsnCode:  line?.hsnCode  ?? '',
  taxCode:  line?.taxCode  ?? '',
  igstCode: line?.igstCode ?? '',
  cgstCode: line?.cgstCode ?? '',
  sgstCode: line?.sgstCode ?? '',
  cgstPer:  line?.cgstPer  ?? 0,
  sgstPer:  line?.sgstPer  ?? 0,
  igstPer:  line?.igstPer  ?? 0,
  tcsPer:   line?.tcsPer   ?? 0,
})

const labelChip = (text: string, bg: string, color: string) => (
  <span style={{
    fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 3,
    background: bg, color, whiteSpace: 'nowrap',
  }}>
    {text}
  </span>
)

export function GstTaxDetailsModal({
  open, line, mode, onApply, onCancel, onTaxCodeLookup,
}: GstTaxDetailsModalProps) {
  const [tax, setTax] = useState<DraftTax>(seed(null))
  const [deleteReason, setDeleteReason] = useState('')
  const [reasonError, setReasonError] = useState(false)

  useEffect(() => {
    if (open && line) {
      setTax(seed(line))
      setDeleteReason(line.deleteReason ?? '')
      setReasonError(false)
    }
  }, [open, line])

  if (!line) return null

  const isLocal = line.route === 'LOCAL'
  const isDelete = mode === 'DELETE'
  const value = round2((line.rate || 0) * (line.qty || 0))

  // Presentation math (value × rate%) — not a business rule.
  const cgstAmt = isLocal ? round2((value * tax.cgstPer) / 100) : 0
  const sgstAmt = isLocal ? round2((value * tax.sgstPer) / 100) : 0
  const igstAmt = isLocal ? 0 : round2((value * tax.igstPer) / 100)
  const tcsAmt  = round2((value * tax.tcsPer) / 100)
  const gstTotal  = round2(cgstAmt + sgstAmt + igstAmt)
  const lineTotal = round2(value + gstTotal + tcsAmt)

  const set = <K extends keyof DraftTax>(k: K, v: DraftTax[K]) =>
    setTax((p) => ({ ...p, [k]: v }))

  const handleApply = () => {
    if (isDelete && !deleteReason.trim()) {
      setReasonError(true)
      notificationService.warning('Delete Reason Required', 'A delete reason is mandatory.')   // BR-04 (hook re-checks)
      return
    }
    const detail: LineTaxDetail = {
      hsnCode:  tax.hsnCode.trim(),
      taxCode:  tax.taxCode.trim(),
      igstCode: tax.igstCode.trim(),
      cgstCode: tax.cgstCode.trim(),
      sgstCode: tax.sgstCode.trim(),
      cgstPer:  tax.cgstPer,
      sgstPer:  tax.sgstPer,
      igstPer:  tax.igstPer,
      tcsPer:   tax.tcsPer,
    }
    onApply(line.lineNo, { detail, deleteReason: isDelete ? deleteReason.trim() : undefined })
  }

  const sectionLabel = (text: string, chip?: React.ReactNode) => (
    <div style={{
      fontSize: 10, fontWeight: 700, color: '#888', textTransform: 'uppercase',
      letterSpacing: '0.06em', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6,
    }}>
      {text}{chip}
    </div>
  )

  const rateInput = (label: React.ReactNode, val: number, onChange: (v: number) => void, amt: number) => (
    <tr>
      <td style={{ padding: '8px 10px' }}>{label}</td>
      <td style={{ padding: '8px 10px' }}>
        <InputNumber
          size="small" min={0} value={val} precision={2} controls={false}
          style={{ width: '100%', fontFamily: 'monospace' }}
          onChange={(v) => onChange(v ?? 0)}
        />
      </td>
      <td style={{
        padding: '8px 10px', textAlign: 'right', fontFamily: 'monospace',
        fontWeight: 700, color: '#1a1a1a',
      }}>
        {fmt2(amt)}
      </td>
    </tr>
  )

  const taxTable = (rows: React.ReactNode, amtHeader = 'Amount ₹') => (
    <table style={{
      width: '100%', borderCollapse: 'collapse', border: '1px solid #e2e2e2',
      borderRadius: 6, overflow: 'hidden', marginBottom: 8,
    }}>
      <thead>
        <tr>
          <th style={modalTh({ textAlign: 'left' })}>Tax Type</th>
          <th style={modalTh({ textAlign: 'left' })}>Rate %</th>
          <th style={modalTh({ textAlign: 'right' })}>{amtHeader}</th>
        </tr>
      </thead>
      <tbody>{rows}</tbody>
    </table>
  )

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width={600}
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
          </div>
        </div>
      }
    >
      <div style={{ padding: '14px 18px 12px' }}>
        {/* Tax Identification */}
        <div style={{ marginBottom: 12 }}>
          {sectionLabel('Tax Identification')}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'flex-end' }}>
            <div style={fieldCol}>
              <label style={fieldLbl}>HSN Code</label>
              <Input
                size="small" style={{ width: 100, fontFamily: 'monospace' }}
                value={tax.hsnCode} placeholder="HSN"
                status={!tax.hsnCode.trim() ? 'warning' : undefined}   // BR-10 (warn; blocked at save)
                onChange={(e) => set('hsnCode', e.target.value)}
              />
            </div>
            {isLocal ? (
              <div style={fieldCol}>
                <label style={fieldLbl}>GST Tax Code</label>
                <Input.Search
                  size="small" style={{ width: 160 }} value={tax.taxCode}
                  onChange={(e) => set('taxCode', e.target.value)}
                  onSearch={() => onTaxCodeLookup?.()}
                  enterButton
                />
              </div>
            ) : (
              <div style={fieldCol}>
                <label style={fieldLbl}>IGST Tax Code</label>
                <Input.Search
                  size="small" style={{ width: 160 }} value={tax.igstCode}
                  onChange={(e) => set('igstCode', e.target.value)}
                  onSearch={() => onTaxCodeLookup?.()}
                  enterButton
                />
              </div>
            )}
          </div>
        </div>

        <div style={divider} />

        {/* GST block — route-driven (server, Q4) */}
        {isLocal ? (
          <div style={{ marginBottom: 12 }}>
            {sectionLabel('GST — Local Supply', labelChip('CGST + SGST', '#E6F1FB', '#185FA5'))}
            {taxTable(
              <>
                {rateInput(labelChip('CGST', '#dbeafe', '#1e40af'), tax.cgstPer, (v) => set('cgstPer', v), cgstAmt)}
                {rateInput(labelChip('SGST', '#dbeafe', '#1e40af'), tax.sgstPer, (v) => set('sgstPer', v), sgstAmt)}
              </>,
            )}
          </div>
        ) : (
          <div style={{ marginBottom: 12 }}>
            {sectionLabel('GST — Inter-State Supply', labelChip('IGST', '#F3EEFF', '#722ED1'))}
            {taxTable(rateInput(labelChip('IGST', '#F3EEFF', '#722ED1'), tax.igstPer, (v) => set('igstPer', v), igstAmt))}
          </div>
        )}

        <div style={divider} />

        {/* TCS */}
        <div style={{ marginBottom: 12 }}>
          {sectionLabel('TCS (Tax Collected at Source)')}
          {taxTable(
            rateInput(labelChip('TCS', '#fef3c7', '#92400e'), tax.tcsPer, (v) => set('tcsPer', v), tcsAmt),
            'TCS Amount ₹',
          )}
        </div>

        <div style={divider} />

        {/* Requester (read-only) */}
        <div style={{ marginBottom: isDelete ? 12 : 0 }}>
          {sectionLabel('Requester')}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
            <div style={fieldCol}>
              <label style={fieldLbl}>Requester ID</label>
              <Input size="small" style={{ width: 100 }} value={line.requesterId} readOnly />
            </div>
            <div style={fieldCol}>
              <label style={fieldLbl}>Requester Name</label>
              <Input size="small" style={{ width: 170 }} value={line.requesterName} readOnly />
            </div>
          </div>
        </div>

        {/* Delete Reason (DELETE mode only) — BR-04 */}
        {isDelete && (
          <>
            <div style={divider} />
            <div>
              {sectionLabel('Delete Reason *')}
              <Input
                size="small" style={{ width: '100%' }}
                value={deleteReason}
                status={reasonError ? 'error' : undefined}
                placeholder="Enter delete reason (mandatory)…"
                onChange={(e) => { setDeleteReason(e.target.value); setReasonError(false) }}
              />
            </div>
          </>
        )}
      </div>

      {/* Footer: line totals + actions */}
      <div style={{
        background: '#f8fafc', borderTop: '1px solid #e2e2e2', padding: '10px 18px',
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, flex: 1 }}>
          <FooterTotal label="Line Value"  value={`₹${fmt2(value)}`} />
          <FooterTotal label="Total GST"   value={`₹${fmt2(gstTotal)}`} color="#b45309" />
          <FooterTotal label="Line Total"  value={`₹${fmt2(lineTotal)}`} color="#1d4ed8" bold />
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button onClick={onCancel}>Cancel</Button>
          <Button type="primary" onClick={handleApply}>
            {isDelete ? 'Apply & Close' : 'Save & Update'}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

function FooterTotal({ label, value, color, bold }: {
  label: string; value: string; color?: string; bold?: boolean
}) {
  return (
    <div>
      <div style={{ fontSize: 10, color: '#6b7280', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {label}
      </div>
      <div style={{
        fontSize: bold ? 16 : 14, fontWeight: bold ? 800 : 700,
        fontFamily: 'monospace', color: color ?? '#111827', lineHeight: 1.3,
      }}>
        {value}
      </div>
    </div>
  )
}

// ── Local styles ─────────────────────────────────────────────────────────────
const fieldCol: React.CSSProperties = { display: 'flex', flexDirection: 'column', gap: 3 }
const fieldLbl: React.CSSProperties = { fontSize: 10, fontWeight: 500, color: '#888' }
const divider:  React.CSSProperties = { height: 1, background: '#e2e2e2', margin: '10px 0 12px' }
