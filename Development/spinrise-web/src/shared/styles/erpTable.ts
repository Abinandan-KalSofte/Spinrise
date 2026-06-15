import type { CSSProperties } from 'react'
import type { ThemeConfig } from 'antd'

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

// ── Modal-table theme — SINGLE reusable standard for ALL modal grids ─────────
// Blueprint §6/§10: ERP-primary sticky header, white text, 600 weight, 42px.
// Raw <table> modals (PR Picker, GST) use MODAL_TH / MODAL_TD + className
// `erp-modal-table`. AntD <Table> modals (Find) wrap in
// <ConfigProvider theme={modalTableTheme}> + className `erp-modal-anttable`.
// Both share row-hover + sticky + sort-icon placeholders via index.css so the
// look is identical everywhere.

export const MODAL_TH: CSSProperties = {
  height: 42,
  padding: '0 12px',
  fontSize: 12,
  fontWeight: 600,
  color: '#ffffff',
  background: '#185FA5',
  borderBottom: '1px solid #0C447C',
  textAlign: 'left',
  whiteSpace: 'nowrap',
  position: 'sticky',
  top: 0,
  zIndex: 2,
  letterSpacing: '0.02em',
  verticalAlign: 'middle',
}

export const MODAL_TD: CSSProperties = {
  height: 40,
  padding: '8px 12px',
  fontSize: 12,
  color: '#1A1A1A',
  borderBottom: '1px solid #E2E2E2',
  verticalAlign: 'middle',
}

/** Merge MODAL_TH with per-column overrides (textAlign, width, …). */
export const modalTh = (extra?: CSSProperties): CSSProperties => ({ ...MODAL_TH, ...extra })
/** Merge MODAL_TD with per-column overrides. */
export const modalTd = (extra?: CSSProperties): CSSProperties => ({ ...MODAL_TD, ...extra })

/** AntD <Table> token theme — identical modal-header look for AntD-rendered grids. */
export const modalTableTheme: ThemeConfig = {
  components: {
    Table: {
      headerBg:           '#185FA5',
      headerColor:        '#ffffff',
      headerSortActiveBg: '#0C447C',
      headerSortHoverBg:  '#0C447C',
      headerSplitColor:   'rgba(255,255,255,0.25)',
      rowHoverBg:         '#E6F1FB',
      cellPaddingBlock:   10,
      cellPaddingInline:  12,
      fontSize:           12,
      borderColor:        '#E2E2E2',
    },
  },
}
