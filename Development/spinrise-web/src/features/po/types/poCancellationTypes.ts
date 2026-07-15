// PO Cancellation — types for the dedicated cancellation screen.
// Source: Development/UI_UX Designs/po-cancellation (FSD v1.1, Pocancel.frm).

export interface CancellationReason {
  code: string
  name: string
}

// One open PO eligible for cancellation — ksp_PO_GetOpenPOList (FN §5).
// Narrower than PoSummary (poTransferTypes.ts): no order value/approval status,
// the open-PO picker doesn't need them.
export interface PoOpenSummary {
  poNo:         number
  poDate:       string
  slCode:       string
  supplierName: string
  poGrp:        string
}

// Server-side shape of one open PO line eligible for cancellation.
export interface POCancellationLineDto {
  slCode:      string
  itemCode:    string
  sNo:         number
  itemName:    string
  uom:         string
  orderQty:    number
  receivedQty: number
  rate:        number
  value:       number
}

// Grid row — server fields plus the UI-editable cancellation fields and
// per-cell validation state, mutated in place (mirrors PoLine in poTransferTypes.ts).
export interface PoCancellationLine extends POCancellationLineDto {
  checked:     boolean
  reasonCode:  string
  cancelQty:   number | null
  qtyError:    string | null
  reasonError: string | null
}

export interface CancelLineRequest {
  sNo:        number
  itemCode:   string
  reasonCode: string
  cancelQty:  number
}

export interface CancelSaveRequest {
  poNo:   number
  poDate: string
  lines:  CancelLineRequest[]
}
