// ── CR-M01-060626-001: Purchase Requisition Report — type definitions ─────────

export type ReportType = 'Datewise' | 'Departmentwise' | 'Itemwise'

export interface DeptOption {
  depCode: string
  depName: string
}

export interface PrItemOption {
  itemCode: string
  itemName: string
}

export interface PrReportFilter {
  reportType:        ReportType
  fromDate:          string    // YYYY-MM-DD
  toDate:            string    // YYYY-MM-DD
  selectedDeptCode:  string
  selectedItemCodes: string[]
  allItems:          boolean
}

export interface DownloadReportParams {
  divCode:    string
  reportType: ReportType
  fromDate:   string
  toDate:     string
  depCode:    string
  allItems:   boolean
  itemCodes:  string[]  // empty when allItems=true
}
