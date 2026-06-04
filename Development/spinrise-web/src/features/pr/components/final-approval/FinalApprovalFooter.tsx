import { useFinalApprovalStore, selectEligibleLines, selectTotalCost, selectSelectedCost } from '../../store/useFinalApprovalStore'

export default function FinalApprovalFooter() {
  const lines = useFinalApprovalStore((s) => s.lines)

  const eligible      = selectEligibleLines(lines)
  const totalCost     = selectTotalCost(lines)
  const selectedCost  = selectSelectedCost(lines)

  const card = (label: string, value: string, sub?: string) => (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      padding: '6px 24px', borderRight: '1px solid #e0e0e0', minWidth: 160,
    }}>
      <span style={{ fontSize: 11, color: '#888', fontWeight: 500 }}>{label}</span>
      <span style={{ fontSize: 15, fontWeight: 700, color: '#1a1a2e' }}>{value}</span>
      {sub && <span style={{ fontSize: 10, color: '#aaa', textAlign: 'center' }}>{sub}</span>}
    </div>
  )

  return (
    <div style={{
      display: 'flex', alignItems: 'center',
      background: '#F5F5F0', borderTop: '1px solid #d9d9d9',
      height: 52, flexShrink: 0,
    }}>
      {card('Total Lines', String(lines.length))}
      {card(
        'Selected For Save',
        String(eligible.length),
        'rows checked — only these commit on Save',
      )}
      {card('Approx. Cost (Selected)', `₹${selectedCost.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`)}
      {card('Total Approx. Cost',      `₹${totalCost.toLocaleString('en-IN',    { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`)}
    </div>
  )
}
