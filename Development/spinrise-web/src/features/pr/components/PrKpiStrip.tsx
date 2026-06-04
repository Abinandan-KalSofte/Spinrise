import PrStatusBadge from './PrStatusBadge'
import type { PrHeader, ScreenMode } from '../types'

interface Props {
  pr:   PrHeader | null
  mode: ScreenMode
  // live draft lines in ADD mode
  draftLineCount: number
  draftTotalQty:  { uom: string; qty: number }[]
}

const Card = ({ label, accent = '#185FA5', children }: { label: string; accent?: string; children: React.ReactNode }) => (
  <div
    style={{
      flex:         1,
      minWidth:     120,
      background:   '#ffffff',
      border:       '1px solid #E2E2E2',
      borderLeft:   `3px solid ${accent}`,
      borderRadius: 8,
      padding:      '7px 12px',
    }}
  >
    <div style={{ fontSize: 10, color: '#888888', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 4 }}>
      {label}
    </div>
    <div style={{ fontSize: 15, fontWeight: 700, color: '#1A1A1A' }}>
      {children}
    </div>
  </div>
)

export default function PrKpiStrip({ pr, mode, draftLineCount, draftTotalQty }: Props) {
  const isAddMode = mode === 'ADD'

  // KPI 1: Total Lines
  const totalLines = isAddMode ? draftLineCount : (pr?.lines.length ?? 0)

  // KPI 2: Total Quantity (UOM-grouped)
  const qtyGroups = isAddMode
    ? draftTotalQty
    : (() => {
        const map: Record<string, number> = {}
        pr?.lines.forEach((l) => {
          map[l.uom] = (map[l.uom] ?? 0) + l.qtyInd
        })
        return Object.entries(map).map(([uom, qty]) => ({ uom, qty }))
      })()

  const qtyDisplay = qtyGroups.length === 0
    ? '—'
    : qtyGroups.map(({ uom, qty }) => `${qty.toFixed(3)} ${uom}`).join(' | ')

  // KPI 3–5: only after save (View/Edit mode with a loaded PR)
  const showPostSave = !isAddMode && pr !== null

  const approxBudget = showPostSave
    ? pr!.lines.reduce((sum, l) => sum + l.appCost, 0).toFixed(2)
    : null

  return (
    <div style={{ display: 'flex', gap: 8 }}>
      <Card label="Total Lines" accent="#185FA5">{totalLines}</Card>

      <Card label="Total Quantity" accent="#475569">
        <span style={{ fontSize: 11, fontWeight: 500 }}>{qtyDisplay}</span>
      </Card>

      {showPostSave && (
        <>
          <Card label="Approx Budget" accent="#BA7517">
            <span style={{ fontFamily: "'JetBrains Mono', monospace" }}>
              ₹ {Number(approxBudget).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
            </span>
          </Card>

          <Card label="Created By" accent="#475569">
            {pr!.reqEmpName || pr!.reqName || '—'}
          </Card>

          <Card label="Approval Status" accent="#185FA5">
            <PrStatusBadge status={pr!.prStatus} />
          </Card>
        </>
      )}
    </div>
  )
}
