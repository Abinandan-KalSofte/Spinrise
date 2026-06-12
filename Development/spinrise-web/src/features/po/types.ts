// Barrel re-export for the PO (PR to PO Transfer) feature.
// Mirrors the `pr` feature convention: `types.ts` aggregates the `types/` folder.

export * from './types/poTaxTypes'
export * from './types/poTransferTypes'

// Single PO-number formatter — used by Doc Band, Order Details tab, toasts and
// the delete dialog so the displayed number is identical everywhere (6-digit,
// e.g. PO-000123). Returns '' when no number yet (CD-03 — never a guess).
export const formatPoNo = (poNo: number | null | undefined): string =>
  poNo ? `PO-${String(poNo).padStart(6, '0')}` : ''

// ── PO line item status badge colours (HTML route badges / status chips) ─────
// Matches the HTML token palette; maps to existing theme tokens at render time.
export const PO_ROUTE_BADGE: Record<string, { color: string; bg: string }> = {
  LOCAL: { color: '#185FA5', bg: '#E6F1FB' },
  IGST:  { color: '#722ED1', bg: '#F3EEFF' },
}

export const PO_APPROVAL_BADGE: Record<string, { color: string; bg: string }> = {
  'PENDING L1': { color: '#BA7517', bg: '#FAEEDA' },
  'PENDING L2': { color: '#BA7517', bg: '#FAEEDA' },
  'PENDING CEO':{ color: '#BA7517', bg: '#FAEEDA' },
  'APPROVED':   { color: '#3B6D11', bg: '#EAF3DE' },
  'REJECTED':   { color: '#A32D2D', bg: '#FCEBEB' },
  'NOT PRINTED':{ color: '#4A4A4A', bg: '#F5F5F3' },
}
