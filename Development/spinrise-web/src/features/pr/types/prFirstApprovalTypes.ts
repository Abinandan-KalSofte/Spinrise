// ── PO Para (approval config) ──────────────────────────────────────────────────

export interface PoParaApproval {
  divCode:       string
  appUserLevel1: string | null
  appUserLevel2: string | null
  appUserLevel3: string | null
  appUserLabel1: string
  appUserLabel2: string
  appUserLabel3: string
  yfDate:        string   // financial year start — computed server-side
  ylDate:        string   // financial year end
}

// ── Department (user-scoped) ───────────────────────────────────────────────────

export interface ApprovalDept {
  depCode:      string
  depName:      string
  pendingCount: number
}

// ── PR Approval Summary (listing modal) ───────────────────────────────────────

export interface PrApprovalSummary {
  prNo:    number
  prDate:  string
  depCode: string
  depName: string
  refNo:   string | null
  section: string | null
}

// ── PR Approval Header ─────────────────────────────────────────────────────────

export interface PrApprovalHeader {
  divCode:  string
  prNo:     number
  prDate:   string
  depCode:  string
  depName:  string
  refNo:    string | null
  section:  string | null
  subCost:  string | null
  sccName:  string | null
  app1:     string | null
  app2:     string | null
  app3:     string | null
  appFlg:   string | null
  app1Date: string | null
  reqName:  string | null
}

// ── PR Approval Line ───────────────────────────────────────────────────────────

export interface PrApprovalLine {
  prSno:        number
  itemCode:     string
  itemName:     string
  uom:          string
  machine:      string | null
  curStock:     number
  qtyInd:       number
  qtyReqd:      number
  firstAppQty:  number
  secondAppQty: number
  thirdAppQty:  number
  qtyOrd:       number
  qtyRec:       number
  rate:         number
  value:        number
  reqdDate:     string | null
  firstApp:     string | null
  prStatus:     string | null
  place:        string | null
  appCost:      number
  remarks:      string | null
  bgrpCode:     string | null
  macNo:        string | null
}

// ── PR Approval Detail ─────────────────────────────────────────────────────────

export interface PrApprovalDetail {
  header: PrApprovalHeader
  lines:  PrApprovalLine[]
}

// ── Local editable line (extends PrApprovalLine with UI state) ─────────────────

export interface PrApprovalLineLocal extends PrApprovalLine {
  key:          string     // React table row key
  selected:     boolean    // checkbox state
  editRate:     number     // editable rate (UI)
  editFirstAppQty: number  // editable firstAppQty (UI)
  calcValue:    number     // editFirstAppQty × editRate (auto-calc)
  hasError:     boolean    // validation flag
}

// ── Request types ──────────────────────────────────────────────────────────────

export interface SaveFirstApprovalLineRequest {
  prSno:       number
  itemCode:    string
  depCode:     string
  qtyReqd:     number
  firstAppQty: number
  rate:        number
  macNo:       string | null
  subCost:     string | null
  uom:         string
}

export interface SaveFirstApprovalRequest {
  prNo:    number
  prDate:  string
  appDate: string
  lines:   SaveFirstApprovalLineRequest[]
}

export interface DeleteFirstApprovalRequest {
  prNo:   number
  prDate: string
}

// ── Screen mode ────────────────────────────────────────────────────────────────

export type ApprovalScreenMode = 'QUERY' | 'APPROVE' | 'DELETE' | 'SAVED'
