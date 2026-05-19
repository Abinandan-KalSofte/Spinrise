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
  itemImage:    string | null
  currentStock: number
  lpoRate:      number | null
  lpoDate:      string | null
  avgRate:      number | null
}

// ── PR types ───────────────────────────────────────────────────────────────────

export type RateSource = 'LPO' | 'AVG' | 'MANUAL'

export interface PrLine {
  prSno:              number
  itemCode:           string
  itemName:           string
  uom:                string
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
  appFlg:     string
  cancelFlag: string | null
  amendNo:    number
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

// ── Screen mode ────────────────────────────────────────────────────────────────

export type ScreenMode = 'VIEW' | 'ADD' | 'EDIT' | 'DELETE'

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
