// ── GST & Tax types — PR to PO Transfer ──────────────────────────────────────
//
// GST routing (LOCAL = CGST+SGST vs IGST) is decided SERVER-SIDE in SPINRISE
// (FSD §5.6 / Rec #7 / D-07 — ksp_PO_GetGSTRouting compares division vs supplier
// gststatecode). The UI only DISPLAYS the returned route; it never computes it.
// The VB6 client-side CGST_SGST_or_IGST() routine is NOT reproduced.
//
// ⚠ Q4 PENDING (Gate 0): the exact routing endpoint/contract is unconfirmed.
//   The shapes below are PROVISIONAL — flagged for backend reconciliation (Q7).

/** Supply route returned by the server for a supplier+division pairing. */
export type GstRoute = 'LOCAL' | 'IGST'

/**
 * Server response for GST routing resolution.
 * Q4 PENDING — confirm whether this is returned inline on supplier selection
 * or via a dedicated call. Until then the UI reads `route` and never derives it.
 */
export interface GstRoutingResult {
  route:        GstRoute
  divStateCode: string
  supStateCode: string
}

/**
 * Per-line GST + tax detail edited in the GST & Tax Details modal.
 * Maps to PO_ORDL cols 67–82 (MD §10). Pre-GST excise/cess/surcharge columns
 * (D-11) are intentionally absent and must never be added here.
 */
export interface LineTaxDetail {
  hsnCode:   string          // PO_ORDL.hsncode (71) — BR-10 mandatory at save
  taxCode:   string          // PO_ORDL.Tax_code (27) — BR-08 mandatory
  igstCode:  string          // IGST tax code (when route = IGST)
  cgstCode:  string          // PO_ORDL.cgst_tax_code — BR-09 active in ig_tax
  sgstCode:  string          // PO_ORDL.sgst_tax_code — BR-09
  cgstPer:   number          // PO_ORDL.cgstper (72)
  sgstPer:   number          // PO_ORDL.sgstper (74)
  igstPer:   number          // PO_ORDL.igstper (76)
  tcsPer:    number          // PO_ORDL.Tcs_per (81)
  // Commercial charges (Section B) + Additional Tax (Section A) — GST modal.
  discPer:       number      // Discount %
  packingPer:    number      // Packing & Forwarding %
  freightPer:    number      // Freight %
  insurancePer:  number      // Insurance %
  otherCharges:      number      // Other Amount % — back-calculated from user-entered amount; SP receives as cessPer
  fcaFob:        number      // FCA / FOB charges
  addTaxCode:    string      // Additional Tax code (reuses GST tax-code master)
  addTaxPer:     number      // Additional Tax %
  // Applicability flags (Section C — editable per line in GST modal)
  freightPos:       'BEFORE' | 'AFTER'
  insuranceDuty:    'BEFORE' | 'AFTER'
  // cessTaxPos removed — Other Amount is always AFTER; it never shifts the GST assessable base
  freightType:      'PAID' | 'TOPAY'
  discApp:          'BEFORE' | 'AFTER'
  packApp:          'BEFORE' | 'AFTER'
  // CR-013: optional rate/qty override from the GST modal
  rate?:            number
  qty?:             number
}

/** Live totals shown in the GST modal footer (all computed display values). */
export interface LineTaxTotals {
  lineValue: number          // 2dp — Rate × Qty (after line charges)
  cgstAmt:   number          // 2dp
  sgstAmt:   number          // 2dp
  igstAmt:   number          // 2dp
  tcsAmt:    number          // 2dp
  gstTotal:  number          // 2dp — CGST+SGST+IGST
  lineTotal: number          // 2dp — value + GST + TCS
}

/** GST tax-code lookup row (IG_TAX master). Provisional — confirm with backend. */
export interface GstTaxCodeOption {
  taxCode:   string
  taxDesc:   string
  cgstPer:   number
  sgstPer:   number
  igstPer:   number
  taxStatus: string          // 'Y' = active (BR-09)
}
