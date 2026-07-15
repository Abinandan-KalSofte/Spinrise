import { selectSelectedLines, selectTotalItemValue, selectTotalPoValue } from '../../store/createPoApprovalStore'
import type { PoApprovalLine } from '../../types/poApprovalTypes'

const fmtV = (v: number) => v.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Shared across every PO Approval level. POT-POA-07/08/09 — both value
// totals default 0 and reflect the SELECTED PO(s) only (ERP 7.4 Web
// Approval reference).
interface Props {
  lines: PoApprovalLine[]
}

export default function PoApprovalFooter({ lines }: Props) {
  const selected     = selectSelectedLines(lines)
  const totalItemVal = selectTotalItemValue(lines)
  const totalPoVal    = selectTotalPoValue(lines)

  const card = (label: string, value: string, sub: string) => (
    <div style={{ flex: 1, padding: '10px 20px', borderRight: '1px solid #E2E2E2' }}>
      <div style={{ fontSize: 10, fontWeight: 600, color: '#888', letterSpacing: '.03em', marginBottom: 2 }}>
        {label}
      </div>
      <div style={{ fontSize: 18, fontWeight: 700, color: '#1A1A1A', lineHeight: 1.1, fontFamily: 'monospace' }}>
        {value}
      </div>
      <div style={{ fontSize: 10, color: '#888', marginTop: 1 }}>{sub}</div>
    </div>
  )

  return (
    <div style={{ background: '#fff', borderTop: '2px solid #E2E2E2', display: 'flex', flexShrink: 0 }}>
      {card('Total POs', String(lines.length), 'in current filter')}
      {card('Selected', String(selected.length), 'POs checked — only these commit on Save')}
      {card('Total Item Value (Rs.)', fmtV(totalItemVal), 'selected POs — item value only, excl. charges/taxes')}
      {card('Total PO Value (Rs.)', fmtV(totalPoVal), 'selected POs — incl. charges & taxes · 0 when none selected')}
    </div>
  )
}
