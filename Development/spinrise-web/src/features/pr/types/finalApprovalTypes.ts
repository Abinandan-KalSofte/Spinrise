// ── Disposition codes ─────────────────────────────────────────────────────────

export type DispositionCode = 1 | 2 | 3 | 4 | 5

export const DISPOSITION_LABELS: Record<DispositionCode, string> = {
  1: 'PL Discuss',
  2: 'Approved',
  3: 'Hold',
  4: 'Declined',
  5: 'Postponed',
}

// ── Grid row from API ─────────────────────────────────────────────────────────

export interface FinalApprovalLine {
  divCode:        string
  prNo:           number
  prDate:         string        // DD/MM/YYYY from API
  prSno:          number
  dbName:         string
  department:     string
  itemCode:       string
  itemName:       string
  uom:            string
  currentStock:   number        // 3dp
  qtyRequired:    number        // 3dp — read-only
  qtyApproved:    number        // 3dp — editable
  disposition:    DispositionCode
  lpoRate:        number        // 4dp
  lpoDate:        string | null // DD/MM/YYYY or null
  approxCost:     number | null // 2dp
  approvalStatus: 'first' | 'second' | 'final'
  rowVersion:     string        // hex string — must be passed back on save
  // UI-only state
  selected:       boolean       // checkbox — false when disposition=1
}

// ── GET response ──────────────────────────────────────────────────────────────

export interface FinalApprovalGetResponse {
  items:      FinalApprovalLine[]
  totalLines: number
  totalCost:  number
}

// ── Filter state ──────────────────────────────────────────────────────────────

export interface FinalApprovalFilterState {
  dbName:    string
  divCode:   string   // '0' = all divisions
  bypassAll: boolean
}

// ── Save request ──────────────────────────────────────────────────────────────

export interface FinalApprovalSaveItem {
  divCode:     string
  prNo:        number
  prDate:      string
  prSno:       number
  qtyApproved: number
  disposition: DispositionCode
  rowVersion:  string
}

export interface FinalApprovalSaveRequest {
  dbName:    string
  bypassAll: boolean
  items:     FinalApprovalSaveItem[]
}

// ── Dropdowns ─────────────────────────────────────────────────────────────────

export interface CompanyOption {
  dbName:      string
  companyName: string
}

export interface DivisionOption {
  divCode:      string
  divisionName: string
  abbr:         string
}

// ── Item history ──────────────────────────────────────────────────────────────

export interface ItemHistoryEntry {
  poNo:   string
  poDate: string
  qty:    number
  rate:   number
  amount: number
}
