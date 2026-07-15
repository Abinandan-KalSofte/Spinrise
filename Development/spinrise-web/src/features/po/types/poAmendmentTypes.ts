// ── PO Amendment types (FN-PO-Amendment v1.2, VB6 amdmnt.frm) ────────────────
//
// Wire mirror of the C# DTOs in
// Spinrise.Application/Areas/PurchaseOrder/PurchaseOrderAmendment/DTOs/.
//
// Reuse note: the amendment screen loads a PO into the SAME PoHeader / PoLine /
// DeliveryScheduleLine shapes the Transfer screen uses, so it can reuse the one
// calc engine (poTransferRules) and the one set of grid/tab components. Only the
// server-facing shapes below are amendment-specific.

import type { DeliverySlot } from './poTransferTypes'

// ── Screen mode (FN §1 — four modes) ─────────────────────────────────────────
// Distinct from ScreenMode (VIEW/ADD/DELETE) in poTransferTypes: Amendment has no
// ADD-from-PR path, and its AMEND mode edits an existing PO in place.
export type AmendScreenMode = 'VIEW' | 'AMEND' | 'DELETE'

// ── ksp_PO_GetAmendablePOList row (FN §1 lookup) ─────────────────────────────
// The AmdAfterGRN predicate is the SP's internal logic — the client never sends it.
export interface AmendablePoSummary {
  divCode:      string
  poNo:         number
  poDate:       string
  poGroup:      string
  supplier:     string
  supplierName: string
  orderValue:   number
  totalLines:   number
}

// ── ksp_PO_GetAmendmentList row (FN §1 Find — view-only) ─────────────────────
export interface AmendmentSummary {
  divCode:      string
  poNo:         number
  poDate:       string
  poGroup:      string
  amdNo:        number
  amdDate:      string
  supplier:     string
  supplierName: string
  orderValue:   number
}

// ── ksp_PO_GetPOForAmend (server load shape) ─────────────────────────────────
// Raw server rows; the hook maps these into PoHeader / PoLine / DeliveryScheduleLine
// so the reused components can render them unchanged.

export interface PoAmendmentLineDto {
  sNo:           number
  itemCode:      string
  itemName:      string
  uom:           string
  quotNo:        string
  quotDate:      string
  prNo:          number
  prDate:        string
  prSno:         number
  rate:          number
  qty:           number
  weight:        number
  value:         number
  fRate:         number
  fValue:        number
  discPer:       number
  discAmt:       number
  packingPer:    number
  packingAmt:    number
  freightPer:    number
  freightAmt:    number
  insurancePer:  number
  insuranceAmt:  number
  otherCharges:  number
  fcaFob:        number
  discApp:       'BEFORE' | 'AFTER'
  packApp:       'BEFORE' | 'AFTER'
  freightPos:    'BEFORE' | 'AFTER'
  insuranceDuty: 'BEFORE' | 'AFTER'
  hsnCode:       string
  taxCode:       string
  taxPer:        number
  taxAmt:        number
  cgstCode:      string
  cgstPer:       number
  cgstAmt:       number
  sgstCode:      string
  sgstPer:       number
  sgstAmt:       number
  igstCode:      string
  igstPer:       number
  igstAmt:       number
  tcsPer:        number
  tcsAmt:        number
  addTaxCode:    string
  addTaxPer:     number
  addTaxAmt:     number
  landingCost:   number
  cenvat:        number
  receivedQty:   number    // RCVDQTY — read-only; feeds the SP's floor guard
  cancelQty:     number    // CANQTY  — read-only
  prBalance:     number    // qtyreqd - qtyord; feeds the amend ceiling (Gap #5)
  amendReason:   string
  remarks:       string
  itemMemo:      string
  requesterId:   string
  requesterName: string
  depCode:       string
}

export interface PoAmendmentDeliverySlotDto {
  sNo:      number         // parent PORDSNO
  itemCode: string
  slotNo:   number
  shDate:   string
  qty:      number
}

export interface PoAmendmentHeaderDto {
  divCode:       string
  poNo:          number
  poDate:        string
  poGroup:       string
  orderType:     string
  orderTypeDesc: string
  supplier:      string
  supplierName:  string
  gstin:         string
  gstState:      string
  // Amendment (read-only)
  amdOrderNo:    number | null
  amdDate:       string | null
  refOrderNo:    number | null
  refOrderDate:  string | null
  // Order details
  inspect:       string
  roundOff:      number
  orderValue:    number
  formType:      string
  refNo:         string
  refDate:       string | null
  currency:      string
  currRate:      number
  remarks:       string
  // Tax / discount
  cgstPer:       number
  sgstPer:       number
  igstPer:       number
  tcsPer:        number
  discPer:       number
  packPer:       number
  insurPer:      number
  freightPer:    number
  freightAmt:    number
  packingAmt:    number
  insuranceAmt:  number
  addTaxPer:     number
  fileNo:        string
  fcaFob:        number
  freightType:   'PAID' | 'TOPAY'
  discApp:       'BEFORE' | 'AFTER'
  packApp:       'BEFORE' | 'AFTER'
  freightPosition:   'BEFORE' | 'AFTER'
  insurancePosition: 'BEFORE' | 'AFTER'
  // Payment
  payMode:       'DIRECT' | 'BANK'
  directInstr:   string
  bankCode:      string
  paymentTerms:  string
  paymentTermCode: string
  advPer:        number
  advAmt:        number
  modeOfPayment: string
  payRef:        string
  payRefDate:    string | null
  chequeNo:      string
  chequeDate:    string | null
  // Instructions
  carrier:       string
  creditDays:    number
  dueDate:       string | null
  deliveryLocation: string
  billingAddress:   string
  specialInstr:  string
  despatch:      string
  purpose:       string
  otherLevies:   string
  pricingTerms:  string
  packForwarding: string
  insurance:     string   // text remark — distinct from insuranceAmt
  freight:       string   // text remark — distinct from freightAmt
  // Cancel / status (read-only context)
  cancelFlag:    string
  cancelDate:    string | null
  reminder:      string
  approved:      string
  approvedBy:    string
  conflg:        string
  // Audit
  createdBy:     string
  createdDt:     string
  // Children
  lines:         PoAmendmentLineDto[]
  delivery:      PoAmendmentDeliverySlotDto[]
}

// ── Save payload (ksp_PO_AmendOrder, FN §4) ──────────────────────────────────
// The Amendment No. is allocated server-side inside the transaction (§4A) — it is
// never sent. Derived amounts are recomputed server-side (§4.B "do not trust
// client-sent amounts"), so the line carries editable INPUTS, not computed money.

export interface AmendmentLineSaveRequest {
  sNo:           number
  itemCode:      string
  prNo:          number
  prDate:        string | null
  prSno:         number
  rate:          number
  qty:           number
  weight:        number
  discPer:       number
  packingPer:    number
  freightPer:    number
  insurancePer:  number
  otherCharges:  number
  discApp:       'BEFORE' | 'AFTER'
  packApp:       'BEFORE' | 'AFTER'
  freightPos:    'BEFORE' | 'AFTER'
  insuranceDuty: 'BEFORE' | 'AFTER'
  taxCode:       string
  hsnCode:       string
  cgstCode:      string
  sgstCode:      string
  igstCode:      string
  tcsPer:        number
  addTaxCode:    string
  addTaxPer:     number
  remarks:       string
  itemMemo:      string
  amendReason:   string          // §3.6 — mandatory on any CHANGED line
  slots:         DeliverySlot[]
}

// 13-Jul ruling (Mariyaiya, FN author + Seenivasan, IST): FN §1's "locked identity"
// restriction covers the LINE GRID only — the HEADER follows VB6, which unlocks every
// field (ENABLCONTLS). So Supplier / GSTIN / GST state are amendable, along with the
// rest of the header. PO No + PO Date stay locked: they are the record key.
export interface AmendmentSaveRequest {
  poNo:           number
  poDate:         string
  poGroup:        string         // §3.3 Order Type mandatory
  carrier:        string         // §3.2 Carrier mandatory
  supplier:       string         // SLCODE — unlocked by the 13-Jul ruling
  gstin:          string         // cust_gstinno
  gstState:       string         // cust_gststcode
  inspect:        string
  formType:       string
  currency:       string
  currRate:       number
  remarks:        string
  refNo:          string
  refDate:        string | null
  fileNo:         string
  paymentTerms:   string
  creditDays:     number
  bankCode:       string
  payMode:        string
  directInstr:    string
  advPer:         number
  advAmt:         number
  chequeNo:       string
  chequeDate:     string | null
  deliveryInstr1: string
  deliveryInstr2: string
  specialInstr:   string
  dueDate:        string | null
  roundOff:       number
  // Header charge basis + applicability flags
  discPer:            number
  packPer:            number
  insurPer:           number
  freightAmt:         number
  packingAmt:         number
  insuranceAmt:       number
  addTaxPer:          number
  freightType:        string
  discApp:            string
  packApp:            string
  freightPosition:    string
  insurancePosition:  string
  lines:          AmendmentLineSaveRequest[]   // §3.1 — at least one
}

export interface AmendmentSaveResponse {
  amendNo: number
  message: string
}

// ── Deletion payloads (ksp_PO_DeleteOrder / ksp_PO_DeleteLines, FN §4) ───────
export interface DeleteOrderRequest {
  poNo:    number
  poDate:  string
  poGroup: string
}

export interface DeleteLineKey {
  sNo:      number
  itemCode: string
}

export interface DeleteLinesRequest {
  poNo:    number
  poDate:  string
  poGroup: string
  lines:   DeleteLineKey[]
}
