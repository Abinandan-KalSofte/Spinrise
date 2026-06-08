// ── Lookup types ───────────────────────────────────────────────────────────────

export interface PrParameters {
  manualIndNo:      string
  budgetQty:        string
  pendingOrderPara: string
  penpodetails:     string
  inditemGrp:       string
  purTypeFlg:       number
  empMasterComm:    string
  pdfExportFlag:    string
  prSmsSendFlg:     string
  prSmsStatusFlg:   string
  prILevel:         string
  prFLevel:         string
  defaultPrType:    string | null
  multiSelectLookup:string
}

export interface PreAddChecks {
  itemMasterExists: boolean
  deptMasterExists: boolean
  docParaExists:    boolean
  backDateFlag:     string
  maxPrDate:        string | null
}

export interface DepartmentOption {
  depCode: string
  depName: string
}

export interface EmployeeOption {
  empNo:   string
  empName: string
}

export interface PrTypeOption {
  iType: string
  iDesc: string
}

export interface MachineLookup {
  macNo:    string
  macDesc:  string
  macModel: string
}

export interface CostCentreOption {
  ccCode: number
  ccName: string
}

export interface ItemLookup {
  itemCode:  string
  itemName:  string
  uom:       string
  minLevel:  number
  maxLevel:  number
  itemImage: string | null
  lpoRate:   number | null
  lpoDate:   string | null
}

export interface ItemDetail {
  itemCode:     string
  itemName:     string
  uom:          string
  minLevel:     number
  maxLevel:     number
  itemImage:    string | null
  currentStock: number
  lpoRate:      number | null
  lpoDate:      string | null
  avgRate:      number | null
}

// ── PR types ───────────────────────────────────────────────────────────────────

export type RateSource = 'LPO' | 'AVG' | 'MANUAL' | 'ORIGINAL'

export interface PrLine {
  prSno:              number
  itemCode:           string
  itemName:           string
  uom:                string
  macNo:              string
  macDesc?:           string   // display-only; not persisted to DB
  qtyInd:             number
  reqdDate:           string | null
  rate:               number
  lpoRate:            number
  lpoDate:            string | null
  lpoFrom:            string
  rateSource:         RateSource
  rateJustification:  string
  curStock:           number
  ccCode:             number | null
  ccName?:            string   // display-only; not persisted to DB
  catCode:            string
  bgrpCode:           string
  appCost:            number
  remarks:            string
  sample:             string
  lineStatus:         string
}

export interface PrHeader {
  divCode:    string
  prNo:       number
  prDate:     string
  depCode:    string
  depName:    string
  reqName:    string
  reqEmpName: string
  section:    string
  iType:      string
  iDesc:      string
  refNo:      string
  poGrp:      string
  appFlg:       string
  cancelFlag:   string | null
  cancelReason: string | null
  amendNo:      number
  prStatus:   string
  createdBy:  string
  createdDt:  string
  userId:     string
  lines:      PrLine[]
}

export interface PrSummary {
  divCode:    string
  prNo:       number
  prDate:     string
  depCode:    string
  depName:    string
  reqName:    string
  reqEmpName: string
  iType:      string
  iDesc:      string
  poGrp:      string
  appFlg:     string
  prStatus:   string
  totalLines: number
}

// ── Request types ──────────────────────────────────────────────────────────────

export interface SavePrLineRequest {
  itemCode:           string
  macNo:              string
  qtyInd:             number
  reqdDate:           string | null
  rate:               number
  lpoRate:            number
  lpoDate:            string | null
  lpoFrom:            string
  rateSource:         RateSource
  rateJustification:  string
  curStock:           number
  ccCode:             number | null
  catCode:            string
  bgrpCode:           string
  appCost:            number
  remarks:            string
  sample:             string
}

export interface SavePrRequest {
  prDate:         string
  depCode:        string
  reqName:        string | null
  section:        string | null
  iType:          string | null
  refNo:          string | null
  poGrp:          string | null
  existingPrNo:   number | null
  existingPrDate: string | null
  lines:          SavePrLineRequest[]
}

export interface DeletePrRequest {
  prNo:         number
  prDate:       string
  deleteMode:   'FULL' | 'LINE'
  prSno:        number | null
  deleteReason: string | null
}

export interface PendingOrder {
  pendingQty: number | null
}

// ── User permissions ───────────────────────────────────────────────────────────

export interface UserPermissions {
  canAdd:    boolean
  canModify: boolean
  canDelete: boolean
}

// ── Screen mode ────────────────────────────────────────────────────────────────

export type ScreenMode = 'VIEW' | 'ADD' | 'EDIT' | 'DELETE'

// ── Amendment types ────────────────────────────────────────────────────────────

export interface AmendmentLine {
  prSno:             number
  itemCode:          string
  itemName:          string
  uom:               string
  minLevel:          number
  maxLevel:          number
  macNo:             string
  macDesc:           string
  qtyInd:            number
  reqdDate:          string | null
  rate:              number
  rateSource:        RateSource
  rateJustification: string
  curStock:          number
  ccCode:            number | null
  ccName:            string
  catCode:           string
  bgrpCode:          string
  place:             string
  appCost:           number
  remarks:           string
  qtyApproved:       number
  qtyOrdered:        number
  qtyReceived:       number
  lineStatus:        string
  rowVersion:        string | null   // base64 PO_PRL row_version; null for history/fallback rows
}

export type AmendmentLineLocal = AmendmentLine & { key: string }

export interface AmendmentHeader {
  divCode:          string
  prNo:             number
  prDate:           string
  amendNo:          number
  amendDate:        string
  amendmentReason:  string
  refNo:            string
  createdBy:        string
  createdDt:        string
  rowVersion:       string
  depCode:          string
  depName:          string
  reqName:          string
  reqEmpName:       string
  section:          string
  iType:            string
  iDesc:            string
  appFlg:           string
  cancelFlag:       string
  lines:            AmendmentLine[]
}

export interface AmendmentSummary {
  divCode:         string
  prNo:            number
  prDate:          string
  amendNo:         number
  amendDate:       string
  amendmentReason: string
  refNo:           string
  createdBy:       string
  depCode:         string
  depName:         string
  reqName:         string
  totalLines:      number
}

export interface SaveAmendmentLineRequest {
  prSno:             number
  itemCode:          string
  macNo:             string
  qtyInd:            number
  reqdDate:          string | null
  rate:              number
  rateSource:        RateSource
  rateJustification: string
  curStock:          number
  ccCode:            number | null
  catCode:           string
  bgrpCode:          string
  place:             string
  appCost:           number
  remarks:           string
  rowVersion:        string | null   // base64; required for PATH A (existing lines)
}

export interface SaveAmendmentRequest {
  prNo:             string
  prDate:           string
  amendDate:        string
  amendmentReason:  string
  refNo:            string | null
  iType:            string | null   // editable PR Type; null = inherit from PR
  rowVersion:       string | null
  pDate:            string    // processing date; enforces BR-AMD-01 at SP level
  lines:            SaveAmendmentLineRequest[]
}

// ── PR Foreclosure ─────────────────────────────────────────────────────────────

export interface PrForeclosureLineDto {
  prNo:       number
  prDate:     string
  department: string
  depCode:    string
  prSno:      number
  itemCode:   string
  itemName:   string
  uom:        string
  prQty:      number
  ordQty:     number
  balance:    number
  sccCode:    string
  sccName:    string
  prevStatus: string
}

export interface PrForeclosureLineKey {
  prNo:     number
  prDate:   string
  prSno:    number
  itemCode: string
  depCode:  string
  balance:  number
}

// ── PR Cancellation ────────────────────────────────────────────────────────────

export interface PrCancellablePrDto {
  prNo:       number
  prDate:     string
  depCode:    string
  department: string
  requester:  string
  itemCount:  number
  refNo:      string
  prType:     string
  section:    string
  createdBy:  string
  status:     string
}

export interface PrForCancellationHeader {
  prNo:        number
  prDate:      string
  depCode:     string
  department:  string
  section:     string
  requestedBy: string
  prType:      string
  refNo:       string
  createdBy:   string
  status:      string
}

export interface PrForCancellationLine {
  sno:          number
  itemCode:     string
  itemName:     string
  uom:          string
  qtyRequired:  number
  qtyApproved:  number
  qtyOrdered:   number
  qtyReceived:  number
  currentStock: number
  rate:         number
  approxCost:   number
  reqdDate:     string
  machine:      string
  placeOfIssue: string
  remarks:      string
  isSample:     boolean
}

export interface PrForCancellationDetail {
  header: PrForCancellationHeader
  lines:  PrForCancellationLine[]
}

export interface PrCancelledPrDto {
  prNo:         number
  prDate:       string
  depCode:      string
  department:   string
  requestedBy:  string
  cancelledOn:  string
  prevStatus:   string
  rowVersion:   string
  cancelReason: string | null
}

// ── KPI status badge colour map (Blueprint Section 10) ────────────────────────

export const PR_STATUS_BADGE: Record<string, { color: string; bg: string }> = {
  'REQUESTED':           { color: '#185FA5', bg: '#E6F1FB' },
  'FIRST LEVEL APPROVED':{ color: '#0C6E5E', bg: '#E0F5F0' },
  'SECOND LEVEL APPROVED':{ color: '#BA7517', bg: '#FAEEDA' },
  'THIRD LEVEL APPROVED':{ color: '#BA7517', bg: '#FAEEDA' },
  'FINAL LEVEL APPROVED':{ color: '#3B6D11', bg: '#EAF3DE' },
  'ORDERED':             { color: '#722ED1', bg: '#F3E8FF' },
  'ORDER CANCELLED':     { color: '#A32D2D', bg: '#FCEBEB' },
  'PR. CANCELLED':       { color: '#A32D2D', bg: '#FCEBEB' },
  'ENQUIRED':            { color: '#BA7517', bg: '#FAEEDA' },
  'RECEIVED':            { color: '#3B6D11', bg: '#EAF3DE' },
}
