import type { PrCancelledPrDto } from '../../types'

const STATUS_LABEL: Record<string, string> = {
  S: 'Requested', P: 'Partial', E: 'Enquired', O: 'Ordered',
  F: 'First Approved', T: 'Second Approved', L: 'Final Approved',
}
const STATUS_BADGE: Record<string, { color: string; bg: string; border: string }> = {
  S: { color: '#15803d', bg: '#dcfce7', border: '#86efac' },
  P: { color: '#BA7517', bg: '#FAEEDA', border: '#fcd34d' },
  E: { color: '#185FA5', bg: '#E6F1FB', border: '#bfdbfe' },
  O: { color: '#7c3aed', bg: '#f3e8ff', border: '#ddd6fe' },
}

interface Props {
  pr: PrCancelledPrDto | null
}

export default function UndoSubTab({ pr }: Props) {
  if (!pr) {
    return (
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8, color: '#888', padding: 40 }}>
        <span style={{ fontSize: 40 }}>↩</span>
        <span style={{ fontSize: 13, fontWeight: 600 }}>No cancelled PR selected</span>
        <span style={{ fontSize: 11, textAlign: 'center', maxWidth: 300, lineHeight: 1.6 }}>
          Click <strong>Find Cancelled PR</strong> in the toolbar. Only cancelled PRs within FY 2025–26 are eligible for undo.
        </span>
      </div>
    )
  }

  const prTag  = `PR-${String(pr.prNo).padStart(5, '0')}`
  const badge  = STATUS_BADGE[pr.prevStatus] ?? STATUS_BADGE['S']
  const label  = STATUS_LABEL[pr.prevStatus] ?? pr.prevStatus

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0, overflow: 'auto' }}>

      {/* Undo mode banner — amber */}
      <div style={{ background: '#FAEEDA', borderBottom: '1px solid #fcd34d', padding: '6px 16px', color: '#BA7517', fontWeight: 500, fontSize: 12, flexShrink: 0 }}>
        Undo mode — <strong style={{ fontFamily: 'monospace' }}>{prTag}</strong>
        {' '}· Click <strong>Undo Cancellation</strong> to restore this PR.
        {' '}Clears CANCELFLAG on PO_PRH. Lines restored to pre-cancel approval status. Current FY only.
      </div>

      {/* View header — amber styling */}
      <div style={{ background: '#fff', borderBottom: '1px solid #e2e2e2', padding: '8px 18px 10px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 10, fontWeight: 700, color: '#185FA5', letterSpacing: '.06em' }}>CANCELLED REQUISITION</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: 'linear-gradient(135deg,#fefce8,#fef9c3)', border: '1px solid #fde68a', borderRadius: 20, padding: '1px 8px' }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: '#92400e' }}>⚠ Cancelled · Current FY only</span>
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 11, color: '#94A3B8' }}>Requested by <strong style={{ color: '#475569' }}>{pr.requestedBy}</strong></span>
            <span style={{ fontSize: 12, fontWeight: 700, fontFamily: 'monospace', padding: '2px 10px', borderRadius: 4, background: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }}>
              {prTag}
            </span>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '2fr 2fr 4fr 2fr', gap: '6px 10px' }}>
          {[
            { label: 'PR Date',          value: pr.prDate },
            { label: 'Cancelled On',     value: pr.cancelledOn, red: true },
            { label: 'Department',       value: pr.department },
            { label: 'Lines Restore To', value: null as null, badge: true },
          ].map(({ label, value, red, badge: isBadge }) => (
            <div key={label}>
              <div style={{ fontSize: 11, fontWeight: 600, color: '#475569', marginBottom: 2 }}>{label}</div>
              {isBadge ? (
                <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 10, color: badge.color, background: badge.bg, border: `1px solid ${badge.border}` }}>
                  {label === 'Lines Restore To' ? label === 'Lines Restore To' && label : label}
                </span>
              ) : (
                <div style={{ fontSize: 12, color: red ? '#A32D2D' : '#1e293b', fontWeight: red ? 600 : 500 }}>{value}</div>
              )}
            </div>
          ))}
        </div>
        {/* Fix badge render */}
        <div style={{ display: 'grid', gridTemplateColumns: '2fr 2fr 4fr 2fr', gap: '6px 10px', marginTop: 4 }}>
          {['', '', '', ''].map((_, i) =>
            i === 3 ? (
              <div key={i} style={{ display: 'flex', alignItems: 'center' }}>
                <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 10, color: badge.color, background: badge.bg, border: `1px solid ${badge.border}` }}>
                  {label}
                </span>
              </div>
            ) : <div key={i} />
          )}
        </div>
      </div>

      {/* Cancellation detail card */}
      <div style={{ margin: '10px 16px 0', background: '#fff', border: '1px solid #E2E2E2', borderRadius: 8, overflow: 'hidden', flexShrink: 0 }}>
        <div style={{ background: '#FAEEDA', padding: '7px 14px', borderBottom: '1px solid #fcd34d', display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: '#BA7517' }}>Original Cancellation Reason</span>
        </div>
        <div style={{ padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ padding: '8px 10px', background: '#F5F5F3', border: '1px solid #E2E2E2', borderRadius: 6, fontSize: 12, color: '#4A4A4A', fontStyle: 'italic', lineHeight: 1.5 }}>
            {pr.cancelReason ? pr.cancelReason : '(No reason recorded)'}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11, color: '#4A4A4A' }}>
            <span style={{ fontWeight: 600 }}>Line Status After Undo</span>
            <span style={{ color: '#888' }}>(restored to previous status)</span>
            <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 10, color: badge.color, background: badge.bg, border: `1px solid ${badge.border}` }}>
              {label}
            </span>
          </div>
          <div style={{ display: 'flex', gap: 8, padding: '8px 10px', background: '#e6f4ff', border: '1px solid #bae0ff', borderRadius: 6, fontSize: 11, color: '#1677ff', lineHeight: 1.5 }}>
            <span>ℹ</span>
            <span>
              Undo clears <code style={{ fontFamily: 'monospace', fontSize: 10 }}>CANCELFLAG</code> on{' '}
              <code style={{ fontFamily: 'monospace', fontSize: 10 }}>PO_PRH</code> and restores{' '}
              <code style={{ fontFamily: 'monospace', fontSize: 10 }}>PO_PRL.PRSTATUS</code> to its pre-cancellation value (BR-UNDO-01).
              Inside a single BeginTransaction. Restricted to current FY 2025–26.
            </span>
          </div>
        </div>
      </div>

    </div>
  )
}
