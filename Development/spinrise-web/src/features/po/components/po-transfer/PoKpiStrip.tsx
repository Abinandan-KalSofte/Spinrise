import type { ScreenMode } from '../../types'

// ── KPI strip (HTML .kpi-strip) ──────────────────────────────────────────────
// Cards 2/3/5 (Order Value, Total GST, Approval Pipeline) are hidden in ADD
// before the PO exists (HTML .kpi-add-hide). Pure presentation — values come
// pre-computed from the hook's `totals`.

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

interface PoKpiStripProps {
  mode:   ScreenMode
  totals: {
    totalLines:      number
    orderValue:      number
    totalGst:        number
    totalOrderValue: number
  }
  approvalStatus?: string
  approvalActor?:  string
}

export function PoKpiStrip({ mode, totals, approvalStatus, approvalActor }: PoKpiStripProps) {
  const hideExtra = mode === 'ADD'   // pre-save: only Total Lines + Total Order Value

  return (
    <div style={{
      display: 'flex', gap: 8, padding: '8px 16px', background: '#F5F5F3',
      borderTop: '1px solid #e2e2e2', flexShrink: 0,
    }}>
      <Card accent="#185FA5" label="Total Lines" value={String(totals.totalLines)} sub="PO line items" />

      {!hideExtra && (
        <Card accent="#185FA5" label="Order Value" value={fmt2(totals.orderValue)} sub="Before GST" />
      )}
      {!hideExtra && (
        <Card accent="#3B6D11" label="Total GST" value={fmt2(totals.totalGst)} valSmall sub="CGST + SGST / IGST" warning />
      )}

      <Card accent="#BA7517" label="Total Order Value" value={`₹${fmt2(totals.totalOrderValue)}`}
        valColor="#BA7517" sub="Incl. GST & TCS" />

      {!hideExtra && (
        <div style={cardStyle('#722ED1')}>
          <div style={kpiLabel}>Approval Pipeline</div>
          <Pipeline status={approvalStatus} />
          <div style={{ fontSize: 10, color: '#888', marginTop: 3 }}>
            {approvalActor ? `${approvalActor} · ` : ''}{approvalStatus ?? '—'}
          </div>
        </div>
      )}
    </div>
  )
}

function Card({ label, value, sub, accent, valColor, valSmall, warning }: {
  label: string; value: string; sub: string
  accent?: string; valColor?: string; valSmall?: boolean; warning?: boolean
}) {
  return (
    <div style={cardStyle(accent)}>
      <div style={kpiLabel}>{label}</div>
      <div style={{
        fontSize: valSmall ? 13 : 16, fontWeight: 700, fontFamily: 'monospace', lineHeight: 1.2,
        color: valColor ?? (warning ? '#BA7517' : '#1a1a1a'),
      }}>
        {value}
      </div>
      <div style={{ fontSize: 10, color: '#888', marginTop: 2 }}>{sub}</div>
    </div>
  )
}

function Pipeline({ status }: { status?: string }) {
  const s = (status ?? '').toUpperCase()
  const l1Active = s.includes('L1') || !status
  const l2Active = s.includes('L2')
  const node = (label: string, state: 'done' | 'active' | 'wait') => (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
      <div style={{
        width: 11, height: 11, borderRadius: '50%', border: '2px solid',
        ...(state === 'done'   ? { background: '#3B6D11', borderColor: '#3B6D11' }
          : state === 'active' ? { background: '#185FA5', borderColor: '#185FA5', boxShadow: '0 0 0 3px rgba(24,95,165,0.18)' }
          :                      { background: '#fff', borderColor: '#ccc' }),
      }} />
      <span style={{ fontSize: 9, fontWeight: 600, color: state === 'wait' ? '#888' : state === 'done' ? '#3B6D11' : '#185FA5' }}>
        {label}
      </span>
    </div>
  )
  const line = (done: boolean) => (
    <div style={{ flex: 1, height: 2, background: done ? '#3B6D11' : '#e2e2e2', minWidth: 18, marginTop: 5, marginBottom: 14 }} />
  )
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', marginTop: 6 }}>
      {node('Requested', 'done')}
      {line(true)}
      {node('L1', l1Active ? 'active' : l2Active ? 'done' : 'wait')}
      {line(l2Active)}
      {node('L2', l2Active ? 'active' : 'wait')}
    </div>
  )
}

const cardStyle = (accent?: string): React.CSSProperties => ({
  background: '#fff', border: '1px solid #e2e2e2', borderRadius: 8, padding: '8px 14px',
  flex: 1, minWidth: 120, maxWidth: 240,
  ...(accent ? { borderLeft: `3px solid ${accent}` } : {}),
})
const kpiLabel: React.CSSProperties = { fontSize: 10, fontWeight: 500, color: '#888', marginBottom: 3 }
