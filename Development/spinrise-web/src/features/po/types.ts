// Barrel re-export for the PO (PR to PO Transfer) feature.
// Mirrors the `pr` feature convention: `types.ts` aggregates the `types/` folder.

export * from './types/poTaxTypes'
export * from './types/poTransferTypes'

// Single PO-number formatter — used by Doc Band, Order Details tab, toasts and
// the delete dialog so the displayed number is identical everywhere (6-digit,
// e.g. PO-000123). Returns '' when no number yet (CD-03 — never a guess).
// POT-AM-06: pass amdSeq to append amendment suffix (e.g. PO-000123-A2).
export const formatPoNo = (
  poNo:    number | null | undefined,
  amdSeq?: number | null,
): string => {
  if (!poNo) return ''
  const base = `PO-${String(poNo).padStart(6, '0')}`
  return amdSeq ? `${base}-A${amdSeq}` : base
}

// ── PO line item status badge colours (HTML route badges / status chips) ─────
// Matches the HTML token palette; maps to existing theme tokens at render time.
export const PO_ROUTE_BADGE: Record<string, { color: string; bg: string }> = {
  LOCAL: { color: '#185FA5', bg: '#E6F1FB' },
  IGST:  { color: '#722ED1', bg: '#F3EEFF' },
}

export const PO_APPROVAL_BADGE: Record<string, { color: string; bg: string }> = {
  // GET /api/v1/po returns approvalStatus as 'CONFIRMED' | 'PENDING' (handover §1).
  'CONFIRMED':  { color: '#3B6D11', bg: '#EAF3DE' },   // green
  'PENDING':    { color: '#BA7517', bg: '#FAEEDA' },   // amber
  'PENDING L1': { color: '#BA7517', bg: '#FAEEDA' },
  'PENDING L2': { color: '#BA7517', bg: '#FAEEDA' },
  'PENDING CEO':{ color: '#BA7517', bg: '#FAEEDA' },
  'APPROVED':   { color: '#3B6D11', bg: '#EAF3DE' },
  'REJECTED':   { color: '#A32D2D', bg: '#FCEBEB' },
  'NOT PRINTED':{ color: '#4A4A4A', bg: '#F5F5F3' },
}

// ── Indian GST State Code → Name master (GSTIN portal codes 01–38) ──────────
export const GST_STATE_NAMES: Record<string, string> = {
  '01': 'Jammu & Kashmir',    '02': 'Himachal Pradesh',   '03': 'Punjab',
  '04': 'Chandigarh',         '05': 'Uttarakhand',        '06': 'Haryana',
  '07': 'Delhi',              '08': 'Rajasthan',          '09': 'Uttar Pradesh',
  '10': 'Bihar',              '11': 'Sikkim',             '12': 'Arunachal Pradesh',
  '13': 'Nagaland',           '14': 'Manipur',            '15': 'Mizoram',
  '16': 'Tripura',            '17': 'Meghalaya',          '18': 'Assam',
  '19': 'West Bengal',        '20': 'Jharkhand',          '21': 'Odisha',
  '22': 'Chhattisgarh',       '23': 'Madhya Pradesh',     '24': 'Gujarat',
  '25': 'Daman & Diu',        '26': 'Dadra & Nagar Haveli', '27': 'Maharashtra',
  '28': 'Andhra Pradesh',     '29': 'Karnataka',          '30': 'Goa',
  '31': 'Lakshadweep',        '32': 'Kerala',             '33': 'Tamil Nadu',
  '34': 'Puducherry',         '35': 'Andaman & Nicobar Islands',
  '36': 'Telangana',          '37': 'Andhra Pradesh (new)', '38': 'Ladakh',
}

// Returns "code - State Name" for display in the GST State field.
// Handles: numeric code only ("33") → "33 - Tamil Nadu";
//          name only ("Tamil Nadu") + code param → "33 - Tamil Nadu";
//          already-formatted "33 - Tamil Nadu" → pass-through;
//          both empty → empty string (triggers save validation).
export const resolveGstStateDisplay = (nameOrCode: string, code?: string): string => {
  if (!nameOrCode && !code) return ''
  if (nameOrCode.includes(' - ')) return nameOrCode     // already formatted
  const padded = nameOrCode.trim().padStart(2, '0')
  if (GST_STATE_NAMES[padded]) return `${nameOrCode.trim()} - ${GST_STATE_NAMES[padded]}`
  if (code?.trim()) {
    const paddedCode = code.trim().padStart(2, '0')
    const stateName  = GST_STATE_NAMES[paddedCode]
    if (stateName) return `${code.trim()} - ${stateName}`
  }
  return nameOrCode   // fallback: state name without code (older data)
}
