import type { PrApprovalLineLocal, ApprovalScreenMode } from '../../types/prFirstApprovalTypes'

interface Props {
  lines:          PrApprovalLineLocal[]
  mode:           ApprovalScreenMode
  totalLineCount: number   // total lines from DB (before mode-based filtering)
}

export default function PrApprovalFooter({ lines, mode, totalLineCount }: Props) {
  const totalValue = lines.reduce((s, l) => s + l.calcValue, 0)

  const approvedCount = lines.filter((l) => l.firstApp === 'Y').length
  // Compare against full DB line count — in SAVED mode, lines is already filtered to approved only
  const isPartial = approvedCount > 0 && approvedCount < totalLineCount

  const statusLabel =
    mode === 'DELETE'                         ? '⚠ Pending Deletion' :
    mode === 'APPROVE'                        ? '✎ Pending Save' :
    mode === 'SAVED' && isPartial             ? '⚠ Partially Approved' :
    mode === 'SAVED' && approvedCount > 0     ? '✅ First Level Approved' :
    '—'

  const card = (label: string, value: string, sub?: string) => (
    <div style={{ flex: 1, padding: '10px 20px', borderRight: '1px solid #f0f0f0' }}>
      <div style={{ fontSize: 10, fontWeight: 600, color: '#888', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 2 }}>
        {label}
      </div>
      <div style={{ fontSize: 18, fontWeight: 700, lineHeight: 1.1, fontFamily: 'monospace' }}>{value}</div>
      {sub && <div style={{ fontSize: 10, color: '#aaa', marginTop: 1 }}>{sub}</div>}
    </div>
  )

  return (
    <div style={{ background: '#fff', borderTop: '1px solid #f0f0f0', display: 'flex', flexShrink: 0 }}>
      {card('Total Items', String(lines.length))}
      {card(
        'Total Value',
        totalValue.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
        'First Approval Quantity × Rate (auto-calculated)'
      )}
      <div style={{ flex: 1, padding: '10px 20px' }}>
        <div style={{ fontSize: 10, fontWeight: 600, color: '#888', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 2 }}>
          Approval Status
        </div>
        <div style={{ fontSize: 13, fontWeight: 700, paddingTop: 3 }}>{statusLabel}</div>
      </div>
    </div>
  )
}
