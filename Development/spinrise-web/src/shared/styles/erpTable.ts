import type { CSSProperties } from 'react'

// ── ERP data-grid — dark slate header ────────────────────────────────────────
// Base style shared by all main ERP grids (PR, Approval, Amendment, etc.)

export const ERP_TH: CSSProperties = {
  padding: '6px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '0.06em',
  color: '#f1f5f9', background: '#1e293b', borderBottom: '2px solid #0f172a',
  whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 2,
}

export const ERP_TD: CSSProperties = {
  padding: '4px 6px', verticalAlign: 'middle',
  borderBottom: '1px solid #f0f0f0', height: 28,
}

/** Merge ERP_TH with per-column overrides (textAlign, width, zIndex, etc.). */
export const erpTh = (extra?: CSSProperties): CSSProperties => ({ ...ERP_TH, ...extra })

/** Merge ERP_TD with per-column overrides (padding, height, etc.). */
export const erpTd = (extra?: CSSProperties): CSSProperties => ({ ...ERP_TD, ...extra })

/** Alternating row background; selected rows highlight in blue. */
export const erpRowBg = (index: number, selected = false): string =>
  selected ? '#EBF3FF' : index % 2 === 0 ? '#ffffff' : '#F0F5FF'

// ── Lookup / picker modal — light header ─────────────────────────────────────
// Used in Machine, CostCentre, Item, and similar lookup modals.

export const LOOKUP_TH: CSSProperties = {
  padding: '8px 10px', fontSize: 11, fontWeight: 700, color: '#64748b',
  background: '#f8fafc', borderBottom: '2px solid #e2e8f0',
  textTransform: 'uppercase', letterSpacing: '0.05em',
  whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 1,
}

export const LOOKUP_TD: CSSProperties = {
  padding: '7px 10px', borderBottom: '1px solid #f1f5f9', verticalAlign: 'middle',
}
