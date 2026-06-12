import type { ReactNode } from 'react'

// ── Shared header-tab field primitives ───────────────────────────────────────
// Keeps the 7 tab panels visually consistent with the HTML hdr-tab-panel.
// Exports components only (Fast-Refresh safe) — shared padding is a component.

export function TabPanel({ children }: { children: ReactNode }) {
  return <div style={{ padding: '8px 16px 10px' }}>{children}</div>
}

/** Dense section divider label (HTML .htab-sec-lbl). */
export function Section({ label }: { label: string }) {
  return (
    <div style={{
      flex: '0 0 100%', fontSize: 10, fontWeight: 700, color: '#888',
      textTransform: 'uppercase', letterSpacing: '0.06em',
      paddingBottom: 3, borderBottom: '1px solid #e2e2e2', margin: '4px 0 6px',
    }}>
      {label}
    </div>
  )
}

/** Read-only display field (not bound to the form). */
export function ReadOnlyField({ label, value, mono, blue }: {
  label: string; value: string; mono?: boolean; blue?: boolean
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      <label style={{ fontSize: 11, fontWeight: 500, color: '#4a4a4a' }}>{label}</label>
      <div style={{
        height: 28, lineHeight: '28px', padding: '0 8px', border: '1px solid #e2e2e2',
        borderRadius: 4, background: '#F5F5F3', fontSize: 12, color: blue ? '#185FA5' : '#4a4a4a',
        fontFamily: mono ? 'monospace' : undefined, fontWeight: mono ? 700 : 400,
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
      }}>
        {value || '—'}
      </div>
    </div>
  )
}
