import { formatPoNo } from '../../types'
import type { ScreenMode } from '../../types'

// ── Document band (HTML .doc-band) ───────────────────────────────────────────
// Breadcrumb + PO No / FY / Record. In ADD the PO No reads "NEW" (server
// allocates the real number on save — CD-03 / UX-04: never a guessed value).

interface PoDocBandProps {
  mode:      ScreenMode
  poNo:      number | null
  fy:        string
  recordPos?: string        // e.g. "138 / 138"
}

export function PoDocBand({ mode, poNo, fy, recordPos }: PoDocBandProps) {
  // Same formatter as the Order Details tab / toasts → identical number everywhere.
  const poLabel = mode === 'ADD'
    ? 'NEW'
    : formatPoNo(poNo) || 'Auto-generated on save'

  return (
    <div style={{
      background: 'linear-gradient(90deg, #0C447C 0%, #185FA5 100%)',
      padding: '6 18px', height: 30, display: 'flex', alignItems: 'center',
      justifyContent: 'space-between', flexShrink: 0,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.65)' }}>Purchase Order</span>
        <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.35)' }}>›</span>
        <span style={{ fontSize: 11, fontWeight: 600, color: '#fff' }}>PR to PO Transfer</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Chip label="PO No." value={poLabel} pill />
        <Chip label="FY" value={fy} />
        <Chip label="Record" value={recordPos ?? (mode === 'ADD' ? 'New Document' : '—')} />
      </div>
    </div>
  )
}

function Chip({ label, value, pill }: { label: string; value: string; pill?: boolean }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
      <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)' }}>{label}</span>
      <span style={{
        fontSize: pill ? 12 : 11, fontWeight: 700, color: '#fff', fontFamily: 'monospace',
        ...(pill ? { background: 'rgba(255,255,255,0.15)', padding: '1px 8px', borderRadius: 4 } : {}),
      }}>
        {value}
      </span>
    </div>
  )
}
