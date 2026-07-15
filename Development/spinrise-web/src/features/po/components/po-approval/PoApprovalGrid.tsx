import { Checkbox, Select } from 'antd'
import { PrinterOutlined } from '@ant-design/icons'
import { erpTh, erpTd } from '@/shared/styles/erpTable'
import { isActionable } from '../../store/createPoApprovalStore'
import { DISPOSITION_LABELS, type DispositionCode, type PoApprovalLine } from '../../types/poApprovalTypes'

const DISPOSITION_OPTIONS = ([1, 2, 3, 4, 5] as DispositionCode[]).map((v) => ({
  value: v, label: DISPOSITION_LABELS[v],
}))

const fmtV = (v: number) => v.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

function chip(bg: string, color: string, text: string) {
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 10,
      whiteSpace: 'nowrap', display: 'inline-block', background: bg, color,
    }}>
      {text}
    </span>
  )
}

// `preservedFlagsNote` — Final Level only (CEO Decision 4): an extra
// sub-label under Hold/Declined/Postpone explaining that First/Second
// approval flags are preserved as permanent audit history.
function statusChip(line: PoApprovalLine, approvedChipText: string, preservedFlagsNote?: string) {
  const preserved = preservedFlagsNote && (
    <span style={{ display: 'block', fontSize: 10, color: '#3B6D11', fontWeight: 700, marginTop: 2, maxWidth: 230, lineHeight: 1.4, whiteSpace: 'normal' }}>
      {preservedFlagsNote}
    </span>
  )
  switch (line.status) {
    case 'approved':  return chip('#EAF3DE', '#3B6D11', approvedChipText)
    case 'declined':  return <>{chip('#FCEBEB', '#A32D2D', "Declined · FClosed = 'Y'")}{preserved}</>
    case 'postponed': return <>{chip('#f5f5f5', '#888888', 'Postponed — will resurface in this list')}{preserved}</>
    case 'hold':      return <>{chip('#FAEEDA', '#BA7517', 'On Hold')}{preserved}</>
    case 'pldiscuss': return chip('#F3EEFF', '#722ED1', 'PL Discuss')
    default:          return <span style={{ color: '#888', fontSize: 11 }}>—</span>
  }
}

function amendmentCell(line: PoApprovalLine, approvedChipText: string, preservedFlagsNote?: string) {
  if (line.amendNo <= 0) return statusChip(line, approvedChipText, preservedFlagsNote)
  return (
    <>
      <span style={{
        fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 10,
        background: '#F3EEFF', color: '#722ED1', marginRight: 4, whiteSpace: 'nowrap',
      }}>
        Amended · A{line.amendNo}
      </span>
      {line.status !== 'pending' && statusChip(line, approvedChipText, preservedFlagsNote)}
    </>
  )
}

// Prior-level provenance sub-label under the supplier name — combines
// whichever of firstLevel/secondLevel/lineCount the line actually carries:
//   First Level's own rows: none of these, no sub-label rendered.
//   Second Level: firstLevel only ("F ✓ …").
//   Final Level (grouped view): firstLevel + secondLevel + lineCount
//   ("F ✓ … · S ✓ … · N lines").
function provenanceSubLabel(line: PoApprovalLine) {
  if (!line.firstLevel && !line.secondLevel && line.lineCount === undefined) return null
  return (
    <span style={{ display: 'block', fontSize: 10, color: '#888', marginTop: 1, whiteSpace: 'nowrap' }}>
      {line.firstLevel && (
        <><span style={{ color: '#3B6D11', fontWeight: 700 }}>F ✓</span> {line.firstLevel.on} {line.firstLevel.by}</>
      )}
      {line.firstLevel && line.secondLevel && ' · '}
      {line.secondLevel && (
        <><span style={{ color: '#3B6D11', fontWeight: 700 }}>S ✓</span> {line.secondLevel.on} {line.secondLevel.by}</>
      )}
      {(line.firstLevel || line.secondLevel) && line.lineCount !== undefined && ' · '}
      {line.lineCount !== undefined && `${line.lineCount} line${line.lineCount !== 1 ? 's' : ''}`}
    </span>
  )
}

// Shared across every PO Approval level. Level-specific wording/behaviour is
// passed as props rather than duplicating the component:
//   - `approvedChipText` — the full "Approved" chip text (First/Second:
//     "Approved — now visible at …"; Final: "Approved · conflg = 'Y'").
//   - `preservedFlagsNote` — Final Level only (CEO Decision 4).
//   - `line.firstLevel`/`line.secondLevel`/`line.lineCount` (optional, in
//     the data) — provenance sub-label, auto-detected from what's present.
interface Props {
  lines:  PoApprovalLine[]
  updateDisposition: (pordno: string, code: DispositionCode) => void
  toggleRow: (pordno: string, selected: boolean) => void
  toggleAll: (selected: boolean) => void
  onPrint: (line: PoApprovalLine) => void
  levelLabel:       string   // e.g. "first level" — for the empty-grid message
  approvedChipText: string   // e.g. "Approved — now visible at Second Level"
  preservedFlagsNote?: string
}

export default function PoApprovalGrid({
  lines, updateDisposition, toggleRow, toggleAll, onPrint, levelLabel, approvedChipText, preservedFlagsNote,
}: Props) {
  const actionableLines = lines.filter(isActionable)
  const selectedCount = lines.filter((l) => l.selected).length
  const allSelected = actionableLines.length > 0 && actionableLines.every((l) => l.selected)
  const someSelected = selectedCount > 0 && !allSelected

  return (
    <div style={{ flex: 1, minHeight: 0, overflow: 'auto' }}>
      <table style={{ borderCollapse: 'collapse', fontSize: 12, width: 'max-content', minWidth: '100%' }}>
        <thead>
          <tr>
            <th style={erpTh({ width: 36, textAlign: 'center' })}>
              <Checkbox
                checked={allSelected}
                indeterminate={someSelected}
                onChange={(e) => toggleAll(e.target.checked)}
                aria-label="Select all pending POs"
              />
            </th>
            <th style={erpTh({ minWidth: 96 })}>Division</th>
            <th style={erpTh({ minWidth: 100 })}>PO No.</th>
            <th style={erpTh({ minWidth: 80 })}>PO Date</th>
            <th style={erpTh({ minWidth: 230 })}>Supplier</th>
            <th style={erpTh({ minWidth: 120, textAlign: 'right' })}>Total Amount</th>
            <th style={erpTh({ minWidth: 110 })}>Payment Terms</th>
            <th style={erpTh({ minWidth: 104 })}>Disposition</th>
            <th style={erpTh({ minWidth: 50, textAlign: 'center' })}>Print</th>
            <th style={erpTh({ minWidth: 180 })}>Amendment Status</th>
          </tr>
        </thead>
        <tbody>
          {lines.length === 0 && (
            <tr>
              <td colSpan={10} style={{ textAlign: 'center', padding: 32, color: '#888', fontSize: 12 }}>
                No purchase orders pending {levelLabel} approval.
              </td>
            </tr>
          )}
          {lines.map((line) => {
            const actionable = isActionable(line)
            const struckThrough = !actionable
            const rowOpacity = line.status === 'declined' || line.status === 'postponed' || line.status === 'approved' ? 0.62 : 1
            const strike: React.CSSProperties = struckThrough ? { textDecoration: 'line-through', color: '#888' } : {}

            return (
              <tr
                key={line.pordno}
                style={{ background: line.selected ? '#EBF3FF' : undefined, opacity: rowOpacity, transition: 'opacity .8s ease' }}
              >
                <td style={erpTd({ width: 36, textAlign: 'center' })}>
                  <Checkbox
                    checked={line.selected}
                    disabled={!actionable}
                    onChange={(e) => toggleRow(line.pordno, e.target.checked)}
                    aria-label={`Select ${line.pordno}`}
                  />
                </td>
                <td style={erpTd({...strike, fontSize: 11, textAlign: 'center', whiteSpace: 'nowrap'})}>
                  <span style={{
                    fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 9999,
                    background: '#ffffff', color: '#4A4A4A', border: '1px solid #E2E2E2', whiteSpace: 'nowrap',
                  }}>
                    {line.divName}
                  </span>
                </td>
                <td style={erpTd({ ...strike, textAlign: 'center', fontWeight: 700, fontFamily: 'monospace', fontSize: 11, color: '#185FA5', whiteSpace: 'nowrap' })}>
                  {line.pordno}
                </td>
                <td style={erpTd({ ...strike, textAlign: 'center', fontFamily: 'monospace', fontSize: 11, whiteSpace: 'nowrap' })}>
                  {line.porddt}
                </td>
                <td style={erpTd(strike)} title={`${line.supplier.name}, ${line.supplier.place}`}>
                  {line.supplier.name} · {line.supplier.place}
                  {provenanceSubLabel(line)}
                </td>
                <td style={erpTd({ ...strike, textAlign: 'right', fontFamily: 'monospace', fontWeight: 700, whiteSpace: 'nowrap' })}>
                  ₹ {fmtV(line.netTotal)}
                </td>
                <td style={erpTd({ ...strike, fontSize: 11, textAlign: 'center' })}>{line.paymentTerm}</td>
                <td style={erpTd()}>
                  <Select<DispositionCode>
                    size="small"
                    value={line.disposition}
                    disabled={!actionable}
                    options={DISPOSITION_OPTIONS}
                    style={{ width: '100%', minWidth: 94 }}
                    onChange={(v) => updateDisposition(line.pordno, v)}
                    aria-label={`Disposition for ${line.pordno}`}
                  />
                </td>
                <td style={erpTd({ textAlign: 'center' })}>
                  <button
                    type="button"
                    onClick={() => onPrint(line)}
                    title={`PO Print preview — ${line.pordno} (placeholder pending OI-03)`}
                    aria-label={`PO print preview for ${line.pordno}`}
                    style={{
                      width: 24, height: 24, border: '1px solid #d0d0d0', borderRadius: 3,
                      background: '#fafafa', cursor: 'pointer', color: '#4A4A4A',
                      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                    }}
                  >
                    <PrinterOutlined style={{ fontSize: 12 }} />
                  </button>
                </td>
                <td style={erpTd({ textAlign: 'center' })}>{amendmentCell(line, approvedChipText, preservedFlagsNote)}</td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
