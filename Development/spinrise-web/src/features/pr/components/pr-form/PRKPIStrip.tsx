import { Fragment } from 'react'
import dayjs from 'dayjs'
import { PR_STATUS_BADGE } from '../../types'

const C = {
  blue:   '#185FA5',
  blueL:  '#E6F1FB',
  amber:  '#BA7517',
  green:  '#3B6D11',
  greenL: '#EAF3DE',
  red:    '#A32D2D',
  redL:   '#FCEBEB',
  purple: '#722ED1',
  text:   '#1a1a1a',
  text3:  '#888',
  border: '#e2e2e2',
  bg2:    '#fafaf8',
} as const

// ── Approval stage bar ─────────────────────────────────────────────────────────

const STAGES = [
  { key: 'REQUESTED',           label: 'Requested'    },
  { key: 'FIRST LEVEL APPROVED', label: 'L1 Approved' },
  { key: 'SECOND LEVEL APPROVED', label: 'L2 Approved' },
  { key: 'FINAL LEVEL APPROVED', label: 'Final'       },
]

function getStageIndex(status: string | null): number {
  if (!status || status === 'REQUESTED')         return 0
  if (status === 'FIRST LEVEL APPROVED')         return 1
  if (status === 'SECOND LEVEL APPROVED' || status === 'THIRD LEVEL APPROVED') return 2
  if (status === 'FINAL LEVEL APPROVED')         return 3
  if (status === 'ORDERED' || status === 'RECEIVED') return 4
  return 0
}

function ApprovalStageBar({ prStatus, savedPrNo }: { prStatus: string | null; savedPrNo: number | null }) {
  if (!savedPrNo) return null

  const cancelled   = prStatus === 'PR. CANCELLED'
  const activeIdx   = getStageIndex(prStatus)
  const isConverted = prStatus === 'ORDERED' || prStatus === 'RECEIVED'

  if (cancelled) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0 8px', borderBottom: `1px solid ${C.border}`, marginBottom: 8 }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6, padding: '2px 12px', borderRadius: 20,
          background: C.redL, border: '1px solid #fca5a5', fontSize: 11, fontWeight: 600, color: C.red,
        }}>
          ✕ This PR has been cancelled
        </div>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '5px 0 8px', borderBottom: `1px solid ${C.border}`, marginBottom: 8 }}>
      {STAGES.map((stage, i) => {
        const isCompleted = i < activeIdx
        const isCurrent   = i === Math.min(activeIdx, STAGES.length - 1) && !isConverted
        const dotBg     = isCompleted || (isConverted && i === STAGES.length - 1) ? C.green : isCurrent ? C.blue : 'transparent'
        const dotBorder = isCompleted || (isConverted && i === STAGES.length - 1) ? C.green : isCurrent ? C.blue : '#d1d5db'
        const labelColor = isCompleted || (isConverted && i === STAGES.length - 1) ? C.green : isCurrent ? C.blue : C.text3
        const lineColor  = isCompleted || isConverted ? C.green : C.border

        return (
          <Fragment key={stage.key}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, minWidth: 84 }}>
              <div style={{
                width: 10, height: 10, borderRadius: '50%', flexShrink: 0,
                background: dotBg, border: `2px solid ${dotBorder}`,
                boxShadow: isCurrent ? `0 0 0 3px ${C.blueL}` : 'none', transition: 'all 0.2s',
              }} />
              <span style={{ fontSize: 9, fontWeight: isCurrent ? 700 : 500, color: labelColor, whiteSpace: 'nowrap' }}>
                {(isCompleted || (isConverted && i === STAGES.length - 1)) ? '✓ ' : ''}{stage.label}
              </span>
            </div>
            {i < STAGES.length - 1 && (
              <div style={{ flex: 1, height: 2, marginBottom: 13, background: lineColor, transition: 'background 0.2s' }} />
            )}
          </Fragment>
        )
      })}

      {isConverted && (
        <>
          <div style={{ flex: 1, height: 2, marginBottom: 13, background: C.purple }} />
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, minWidth: 72 }}>
            <div style={{ width: 10, height: 10, borderRadius: '50%', background: C.purple, border: `2px solid ${C.purple}`, flexShrink: 0 }} />
            <span style={{ fontSize: 9, fontWeight: 700, color: C.purple, whiteSpace: 'nowrap' }}>
              ✓ {prStatus === 'RECEIVED' ? 'Received' : 'Ordered'}
            </span>
          </div>
        </>
      )}
    </div>
  )
}

// ── KPI card ───────────────────────────────────────────────────────────────────

function KPICard({
  label, value, sub, valueColor, mono = false, accent,
}: {
  label: string; value: React.ReactNode; sub?: string
  valueColor?: string; mono?: boolean; accent?: string
}) {
  return (
    <div style={{
      background: '#fff', border: `1px solid ${C.border}`,
      borderLeft: accent ? `3px solid ${accent}` : `1px solid ${C.border}`,
      borderRadius: 8, padding: '7px 12px', minWidth: 0,
    }}>
      <div style={{ fontSize: 10, fontWeight: 600, color: C.text3, letterSpacing: '0.3px', marginBottom: 2 }}>{label}</div>
      <div style={{
        fontSize: mono ? 12 : 15, fontWeight: 700, color: valueColor ?? C.text, lineHeight: 1.2,
        fontVariantNumeric: 'tabular-nums', fontFamily: mono ? 'monospace' : 'inherit',
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
      }}>
        {value}
      </div>
      {sub && <div style={{ fontSize: 10, color: C.text3, marginTop: 2, whiteSpace: 'nowrap' }}>{sub}</div>}
    </div>
  )
}

// ── Component ──────────────────────────────────────────────────────────────────

interface PRKPIStripProps {
  validLinesCount: number
  totalQtyDisplay: string
  totalCost:       number
  prDate?:         string | null
  prStatus:        string | null
  savedPrNo:       number | null
  isNewMode?:      boolean
}

export function PRKPIStrip({ validLinesCount, totalQtyDisplay, totalCost, prDate, prStatus, savedPrNo, isNewMode = false }: PRKPIStripProps) {
  const statusInfo  = prStatus ? (PR_STATUS_BADGE[prStatus] ?? null) : null
  const daysOpen    = savedPrNo && prDate ? dayjs().diff(dayjs(prDate), 'day') : null
  const daysColor   = daysOpen === null ? C.text3 : daysOpen < 5 ? C.green : daysOpen <= 14 ? C.amber : C.red
  const statusColor = statusInfo?.color ?? C.text3

  // FSD §2 (CEO R2.0 #17): cards 3-5 hidden in Add mode; only visible after first save
  const cols = isNewMode ? 2 : 5

  return (
    <div style={{ background: C.bg2, borderTop: `1px solid ${C.border}`, padding: '8px 16px', flexShrink: 0 }}>
      <ApprovalStageBar prStatus={prStatus} savedPrNo={savedPrNo} />
      <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: 8 }}>
        <KPICard label="Total Lines" value={validLinesCount}
          sub={`${validLinesCount === 1 ? 'item' : 'items'} in this PR`}
          valueColor={C.blue} accent={C.blue} />
        <KPICard label="Total Quantity" value={totalQtyDisplay} sub="By unit of measure" mono />
        {!isNewMode && (
          <>
            <KPICard label="Approx. Budget"
              value={totalCost > 0 ? `₹ ${totalCost.toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : '—'}
              sub="Indicative cost" valueColor={totalCost > 0 ? C.amber : C.text3}
              accent={totalCost > 0 ? C.amber : undefined} />
            <KPICard label="Days Open" value={daysOpen !== null ? daysOpen : '—'}
              sub={daysOpen === null ? 'Not yet saved' : daysOpen === 0 ? 'Created today' : `${daysOpen} days since creation`}
              valueColor={daysColor}
              accent={daysOpen !== null && daysOpen > 14 ? C.red : daysOpen !== null && daysOpen >= 5 ? C.amber : undefined} />
            <KPICard label="Approval Status"
              value={statusInfo
                ? <span style={{ fontWeight: 700, color: statusColor }}>{prStatus}</span>
                : <span style={{ color: C.text3, fontWeight: 400 }}>Draft</span>}
              sub={!savedPrNo ? 'Not yet saved' : prStatus === 'PR. CANCELLED' ? 'No further action' : 'Awaiting approval'}
              accent={statusColor !== C.text3 ? statusColor : undefined} />
          </>
        )}
      </div>
    </div>
  )
}
