// PO Foreclosure — types for the dedicated foreclosure screen.
// Source: Development/UI_UX Designs/po-foreclosure (FSD v1.1, FrmPOForeclousre.frm).

// OA-02 (confirmed against the approved prototype + DB_Schema/JAT_Schema.md PO_PRL):
// sNo is the visible "S.No." column and is the same value used server-side as both
// @pordsno and @prsno. prNo/prDate are hidden in the UI but must stay on every line
// object and in the save payload — they participate in the PO_PRL WHERE clause.
export interface POForeclosureLineDto {
  group:        string
  poNo:         number
  poDate:       string
  slCode:       string
  supplierName: string
  sNo:          number
  itemCode:     string
  itemName:     string
  balanceQty:   number
  prNo:         string
  prDate:       string
}

export interface ForeclosureLineKey {
  poNo:   number
  poDate: string
  group:  string
  sNo:    number
  itemCode: string
  prNo:   string
  prDate: string
}

export interface ForeclosureSaveRequest {
  lines: ForeclosureLineKey[]
}
