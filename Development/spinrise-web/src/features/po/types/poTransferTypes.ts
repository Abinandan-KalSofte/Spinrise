// ── PR to PO Transfer types ──────────────────────────────────────────────────
//
// Field set mirrors the approved HTML mockup (SPINRISE_FSD_M02_POTransfer_v3_1).
// DB column references are PO_ORDH / PO_ORDL per MD §8 / §10. Pre-GST excise,
// cess and surcharge line columns (D-11) are intentionally NOT modelled.
//
// ⚠ PROVISIONAL CONTRACT (Q7): no REST spec exists yet. All request/response
//   shapes below are placeholders flagged for backend reconciliation.

import type { GstRoute } from './poTaxTypes'

// ── Screen mode ──────────────────────────────────────────────────────────────
// No EDIT here — VB6 Modify/Amendment is a separate screen (Q6 confirmed).
export type ScreenMode = 'VIEW' | 'ADD' | 'DELETE'

export type DeleteMode = 'FULL' | 'LINE'

// ── Parameters & pre-add checks ──────────────────────────────────────────────

/** po_para / in_para driven flags read on screen open. Provisional shape. */
export interface PoParameters {
  poFirstLevelApp: string    // 'Y'/'N'
  poPrintApp:      string    // 'Y'/'N' — gates Print on conflg
  poConf:          string    // 'Y'/'N' — drives auto-confirm
  budGrp:          string    // 'Y'/'N' — BR-16
  budgetQty:       string    // 'Y'/'N' — BR-17
  budgetControl:   string    // 'Y'/'N' — hard vs soft budget block
  currCode:        string    // default currency (BR-13)
  backDate:        string    // 'Y'/'N' — BR-01
  pdfExportFlag:   string
}

/** Pre-Add gate checks (FSD §4.1). Provisional shape. */
export interface PoPreAddChecks {
  approvedPrLinesExist: boolean   // BR-02
  docParaExists:        boolean   // PO_DOC_PARA entry for 'PURCHASE ORDER'
  backDateFlag:         string
  maxPoDate:            string | null   // BR-01 ceiling
  lastPoDate:           string | null   // CR-024: last saved PO date — lower bound for new PO date
}

// ── Lookups (provisional) ────────────────────────────────────────────────────

export interface SupplierOption {
  slCode:       string
  slName:       string
  gstinNo:      string       // auto-fills GSTIN (UX-06)
  gstStateCode: string       // drives GST route (server-side, Q4)
  gstStateName: string
  city?:        string       // CR-003: shown in dropdown label
}

export interface OrderTypeOption {
  poGrp:   string
  typName: string
}

export interface CarrierOption {
  carCode: string
  carName: string
}

export interface BankOption {
  bankCode: string
  bankName: string
}

export interface FormTypeOption {
  formCode: string
  formName: string
}

export interface AddressOption {
  code: string
  name: string
}

export interface CurrencyOption {
  currCode: string
  currName: string
  currRate: number
}

export interface PayTermOption {
  payTermCode: string
  payTermDesc: string
}

// ── PR eligible line (PR Picker — FpSpdInd / delmodok_Click) ──────────────────
// Server list is pre-filtered by BR-02 (DirectApp='Y', Fclosed<>'Y').

export interface EligiblePrLine {
  id:            string       // client selection key (prNo+prSno+itemCode)
  prNo:          number
  prDate:        string
  prSno:         number       // PO_ORDL.PRSNO back-reference
  itemCode:      string
  itemName:      string
  uom:           string
  balanceQty:    number       // QTYREQD - QTYORD - enq_qty (BR-05 ceiling)
  department:    string
  subCostCentre: string
  remarks:       string
  hsnCode:       string       // blank ⇒ HSN-missing flag (BR-10)
  cgstPer:       number
  sgstPer:       number
  igstPer:       number
  gstTaxCode:    string
  requesterId:   string
  requesterName: string
  suggestedRate: number      // last ordered rate from PO_ORDL; 0 if no history
}

// ── PO line (PO_ORDL subset — 22 SPINRISE columns, MD §10) ───────────────────

export interface PoLine {
  lineNo:        number       // client row key (PO_ORDL.PORDSNO on save)
  prSno:         number       // PO_ORDL.PRSNO
  itemCode:      string       // (40) RO
  itemName:      string       // (5)  RO
  uom:           string       // (8)  RO
  prNo:          number       // (9)  RO
  prDate:        string       // (10) RO
  rate:          number       // (12) 4dp — BR-07 > 0
  qty:           number       // (13) 3dp — BR-05/06
  balanceQty:    number       // PR balance ceiling for BR-05 (display/validate)
  value:         number       // (15) 2dp — computed Rate×Qty (after line charges)
  taxCode:       string       // (27) — BR-08
  taxPer:        number       // (28)
  taxAmt:        number       // (29) 2dp
  hsnCode:       string       // (71) — BR-10 (warn inline, block at save)
  cgstPer:       number       // (72)
  cgstAmt:       number       // (73) 2dp
  sgstPer:       number       // (74)
  sgstAmt:       number       // (75) 2dp
  igstPer:       number       // (76)
  igstAmt:       number       // (77) 2dp
  tcsPer:        number       // (81)
  tcsAmt:        number       // (82) 2dp
  cgstCode:      string       // (78) cgst_tax_code — BR-09
  sgstCode:      string       // (79) sgst_tax_code — BR-09
  igstCode:      string       // (80) igst_tax_code — BR-09
  // ── Commercial charges (per-line; GST & Tax modal) — seeded from header ─────
  discPer:       number       // Discount %
  packingPer:    number       // Packing & Forwarding %
  freightPer:    number       // Freight %
  insurancePer:  number       // Insurance %
  cessPer:       number       // Cess %
  fcaFob:        number       // FCA / FOB charges (pass-through; not in net)
  // ── Additional Tax (GST-family; code reuses the GST tax-code master) ────────
  addTaxCode:    string       // Additional Tax code
  addTaxPer:     number       // Additional Tax %
  addTaxAmt:     number       // Additional Tax amount (2dp, computed)
  // ── Applicability (per-line; seeded from header, editable in GST modal) ─────
  freightPos:       'BEFORE' | 'AFTER'
  insuranceDuty:    'BEFORE' | 'AFTER'
  cessTaxPos:       'BEFORE' | 'AFTER'
  exciseIncPacking: 'Y' | 'N'
  freightType:      'PAID' | 'TOPAY'
  discApp:          'BEFORE' | 'AFTER'
  packApp:          'BEFORE' | 'AFTER'
  // ── Computed money fields (recalcLine) ─────────────────────────────────────
  taxableValue:  number       // 2dp — Rate × Qty (GST base)
  netAmount:     number       // 2dp — taxable − disc + charges + all taxes
  taxSaved:      boolean      // true once the GST & Tax modal is saved for this line
  requesterId:   string       // (83) RO
  requesterName: string       // (84) RO
  route:         GstRoute     // server-driven (Q4); UI displays, never computes
  deleteReason:  string       // (85) — DELETE mode only (BR-04)
}

// ── Delivery schedule (PO_ORDL_DETL — item-wise open child grid; OQ-NEW B) ───
// OQ-NEW Option B (approved): UNLIMITED delivery rows per PO item — the retired
// fixed 4-slot model is gone. Reconciliation is on QTY not value (UX-01); each
// slot keeps its own item UOM (UX-02). `slotNo` is just the 1..n row sequence
// within the item, re-numbered on add/remove.

export interface DeliverySlot {
  slotNo:  number             // 1..n row sequence within the item (open grid)
  shDate:  string | null      // PO_ORDL_DETL.shdate
  qty:     number             // PO_ORDL_DETL.Quantity (3dp)
  remarks: string
}

/** Delivery rows grouped per PO line (keyed by lineNo). Unlimited rows per item. */
export interface DeliveryScheduleLine {
  lineNo:   number            // matches PoLine.lineNo
  itemCode: string
  itemName: string
  uom:      string
  prNo:     number
  poQty:    number            // Σ slot qty must reconcile to this (UX-01)
  slots:    DeliverySlot[]    // unlimited rows (OQ-NEW B)
}

// ── PO header (PO_ORDH) ──────────────────────────────────────────────────────

export interface PoHeader {
  // Order Details
  divCode:      string
  poNo:         number | null   // null until server allocates (CD-03 / UX-04)
  poDate:       string          // BR-01
  orderType:    string          // poGrp — BR-11
  orderTypeDesc:string
  supplier:     string          // slCode — BR-12
  supplierName: string
  gstin:        string          // auto from supplier (UX-06)
  gstState:     string          // auto from supplier; drives route (Q4)
  inspect:      string          // 'YES'/'NO'
  roundOff:     number
  orderValue:   number          // computed Σ line value before GST (UI-03)
  formType:     string
  refNo:        string
  refDate:      string | null
  currency:     string          // BR-13
  currRate:     number
  remarks:      string

  // Tax / Discount (header-level) — GST-based taxation only.
  // Pre-GST AED / Surcharge / Cess columns (D-11) are NOT FOR SPINRISE and are
  // intentionally absent; never re-add them.
  cgstPer:      number
  sgstPer:      number
  igstPer:      number
  tcsPer:       number
  discPer:      number
  freightAmt:   number
  packPer:      number
  insurPer:     number
  addTaxPer:    number
  fileNo:       string
  fcaFob:       number
  freightType:  'PAID' | 'TOPAY'
  discApp:      'BEFORE' | 'AFTER'
  packApp:      'BEFORE' | 'AFTER'
  // Computed charge amounts + applicability flags — must reach the save payload.
  discountAmt:          number
  freightPer:           number
  packingAmt:           number
  insuranceAmt:         number
  addTaxAmt:            number
  cessPer:              number
  cessAmt:              number
  freightPosition:      'BEFORE' | 'AFTER'
  insurancePosition:    'BEFORE' | 'AFTER'
  cessPosition:         'BEFORE' | 'AFTER'
  exciseIncludePacking: 'Y' | 'N'

  // Payment
  payMode:          'DIRECT' | 'BANK'   // BR-15 when BANK
  directInstr:      string
  bankCode:         string
  paymentTerms:     string
  paymentTermCode:  string              // Ig_PayTerm.PayTerm_Code — code stored in paytermcode column
  advPer:       number
  advAmt:       number
  modeOfPayment:string
  payRef:       string
  payRefDate:   string | null
  chequeNo:     string              // BR-15
  chequeDate:   string | null       // BR-15

  // Instructions
  carrier:          string          // BR-14
  creditDays:       number
  deliveryDate:     string | null
  deliveryLocation: string
  billingAddress:   string
  specialInstr:     string
  despatch:         string
  purpose:          string
  otherLevies:      string
  pricingTerms:     string          // BR-15 mandatory when orderType 'HO'
  packForwarding:   string
  insurance:        string
  freight:          string

  // Cancel / Status
  reminder:     string
  status:       string
  cancelled:    boolean
  cancelDate:   string | null
  cancelReason: string
  approved:     string
  approvedBy:   string

  // Amendment (read-only history)
  amdOrderNo:   number | null
  amdDate:      string | null
  amdRefNo:     string | null
  amdRefDate:   string | null

  // Approval (read-only)
  approvalStatus: string
  printStatus:    string
  firstLevelApp:  string
  conflg:         string            // print-approval gate
  createdBy:      string
  createdDt:      string
  userId:         string

  lines:        PoLine[]
  delivery:     DeliveryScheduleLine[]
}

// ── PO list / summary row (Find — deferred Q6, type kept for reuse) ──────────

export interface PoSummary {
  divCode:      string
  poNo:         number
  poDate:       string
  orderType:    string
  supplier:     string
  supplierName: string
  orderValue:   number
  approvalStatus:string
  totalLines:   number
}

// ── Request types (provisional — Q7) ─────────────────────────────────────────

export interface SavePoLineRequest {
  prNo:          number       // PR back-reference — server validates PR balance
  prSno:         number
  prDate:        string       // "YYYY-MM-DD" — MANDATORY (server PR-balance validation)
  itemCode:      string
  rate:          number
  qty:           number
  taxCode:       string
  hsnCode:       string
  cgstPer:       number
  sgstPer:       number
  igstPer:       number
  tcsPer:        number
  cgstCode:      string
  sgstCode:      string
  igstCode:      string
  route:         GstRoute
  requesterId:   string      // propagated from PR line (required by SP)
  requesterName: string
  // Commercial charges
  discPer:          number
  packingPer:       number
  freightPer:       number
  insurancePer:     number
  cessPer:          number
  fcaFob:           number
  addTaxCode:       string
  addTaxPer:        number
  // Applicability flags
  freightPos:       'BEFORE' | 'AFTER'
  insuranceDuty:    'BEFORE' | 'AFTER'
  cessTaxPos:       'BEFORE' | 'AFTER'
  exciseIncPacking: 'Y' | 'N'
  freightType:      'PAID' | 'TOPAY'
  discApp:          'BEFORE' | 'AFTER'
  packApp:          'BEFORE' | 'AFTER'
  slots:            DeliverySlot[]   // unlimited delivery rows per item (OQ-NEW B)
}

/** Add-PO payload. PO No is allocated server-side — never sent (CD-03). */
export interface AddPoRequest {
  poDate:    string
  header:    Omit<PoHeader, 'divCode' | 'poNo' | 'lines' | 'delivery'>
  lines:     SavePoLineRequest[]
}

export interface DeletePoLineReason {
  prSno:        number
  deleteReason: string         // BR-04 — non-empty per line
}

export interface DeletePoRequest {
  poNo:         number
  poDate:       string
  deleteMode:   DeleteMode     // FULL (overall) | LINE
  defaultReason:string         // header-level default (auto-propagated)
  lineReasons:  DeletePoLineReason[]   // BR-04 — every line non-empty
}

