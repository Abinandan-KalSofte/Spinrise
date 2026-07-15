// PO Approval — shared types for the First/Second/Final Level approval queue
// screens. Sources: Development/UI_UX Designs/prototype/po-approval/
// po-first-level.html, po-second-level.html, po-final-level.html (FSD v1.1
// Stage 4, CR build 03-Jul-2026, POT-POA-01…09). The three levels share one
// FSD, one save/refresh state machine, and mostly one grid shape — but
// Final Level is a GROUPED view (FSD §10.2 / CEO Decision 1): one row per
// PO header with NO line-item detail, only a `lineCount` + `poValue`
// aggregate (First/Second Level carry full `lines[]`). Kept generic here —
// `lines` is optional and the aggregate fields are optional fallbacks — so
// all three levels reuse the same types instead of duplicating near-
// identical shapes.

// FSD §3.2 — five approval action codes (shared shape with PR Final Level
// Approval's DispositionCode, kept local to this feature to avoid a
// cross-feature import per project convention).
export type DispositionCode = 1 | 2 | 3 | 4 | 5

export const DISPOSITION_LABELS: Record<DispositionCode, string> = {
  1: 'PL Discuss',
  2: 'Approved',
  3: 'Hold',
  4: 'Declined',
  5: 'Postpone',
}

// CEO direction 02-Jul-2026 (Item 4): reason is mandatory for Hold/Declined/Postpone.
export function isReasonRequired(code: DispositionCode): boolean {
  return code === 3 || code === 4 || code === 5
}

export type PoApprovalStatus =
  | 'pending' | 'approved' | 'hold' | 'declined' | 'postponed' | 'pldiscuss'

export interface DivisionOption {
  code: string   // '0' = ALL Divisions
  name: string
}

export interface PoApprovalSupplier {
  code:  string
  name:  string
  place: string
}

// PO_ORDL shape — only needed for the Print preview and the footer's
// "Total Item Value" sum; never rendered as its own grid rows.
export interface PoApprovalLineItem {
  pordsno:       number
  itemCode:      string
  itemName:      string
  qty:           number   // 3dp
  uom:           string
  rate:          number   // 4dp
  value:         number   // 2dp
  onlineRemarks: string
  fclosed:       'Y' | 'N'
}

// Prior-level approval provenance — Second/Final Level only (FSD §3.3
// sequential gating: a PO reaches Second Level only once FirstlevelApp='Y',
// Final Level only once SecondLevelApp='Y' too — shown as a supplier
// sub-label). Absent on First Level's own rows.
export interface PoApprovalProvenance {
  by: string
  on: string   // DD/MM/YYYY
}

// PO_ORDH shape — one row per PO in the approval grid.
export interface PoApprovalLine {
  pordno:         string
  poNo:           number   // raw PO number — required by GET /po/{poNo}/print (print API)
  poDate:         string   // ISO YYYY-MM-DD — required by GET /po/{poNo}/print (print API)
  porddt:         string   // DD/MM/YYYY from API
  divCode:        string
  divName:        string   // 10-Jul-2026: pp_divmas.DIVNAME
  supplier:       PoApprovalSupplier
  orderType:      string
  currency:       string
  paymentTerm:    string
  netTotal:       number   // PO value incl. charges/taxes — grid "Total Amount"
  amendNo:        number
  firstLevelApp:  'Y' | 'N'
  secondLevelApp: 'Y' | 'N'
  conflg:         'Y' | 'N'
  // First/Second Level: full line detail. Final Level (FSD §10.2, grouped
  // view, CEO Decision 1): absent — use `lineCount`/`poValue` instead.
  lines?:         PoApprovalLineItem[]
  lineCount?:     number   // 10-Jul-2026: populated at all 3 levels now (First/Second: lines.length; Final: line count without the detail array)
  poValue?:       number   // Final Level only — item value aggregate (excl. charges/taxes)
  // Second Level only — prior level's approver + date, shown as a supplier
  // sub-label ("F ✓ …"). Final Level shows both firstLevel AND secondLevel.
  firstLevel?:    PoApprovalProvenance
  secondLevel?:   PoApprovalProvenance
  // UI-only state (not part of the API contract)
  disposition:    DispositionCode
  remarks:        string
  // BR-05 (legacy parity, 10-Jul-2026): re-surface date, mandatory for
  // disposition=5 (Postpone) only — ISO YYYY-MM-DD. The GET SPs hide a
  // postponed PO from the queue until this date arrives.
  postponeDate?:  string
  status:         PoApprovalStatus
  selected:       boolean
}

export interface PoApprovalFilterState {
  divCode:    string   // '0' = ALL Divisions
  poNoSearch: string
}

// ── GET response ──────────────────────────────────────────────────────────────

export interface PoApprovalGetResponse {
  items: PoApprovalLine[]
}

// ── Save request ──────────────────────────────────────────────────────────────

export interface PoApprovalSaveItem {
  pordno:       string
  // 10-Jul-2026 bug fix: divCode is per-item, never the grid filter's value —
  // when "ALL Divisions" (divCode='0') is selected, rows can span multiple real
  // divisions, so each row must carry its own actual division code.
  divCode:      string
  poNo:         number        // raw PO number — required by the real save API
  poDate:       string        // ISO YYYY-MM-DD — required by the real save API
  disposition:  DispositionCode
  remarks:      string        // only meaningful for Hold/Declined/Postpone; max 25 chars (LogDet_PO.reason)
  postponeDate?: string       // ISO YYYY-MM-DD — mandatory when disposition=5 (BR-05, legacy parity)
}

export interface PoApprovalSaveRequest {
  items: PoApprovalSaveItem[]
}

export interface PoApprovalSaveResult {
  saved: string[]   // PO numbers successfully actioned
}
