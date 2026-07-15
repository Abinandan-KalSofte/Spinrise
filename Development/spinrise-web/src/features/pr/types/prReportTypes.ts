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
  divCode:      string
  reportType:   ReportType | 'Supplierwise'
  fromDate:     string
  toDate:       string
  allDepts:     boolean
  deptCodes:    string[]  // empty when allDepts=true
  allItems:     boolean
  itemCodes:    string[]  // empty when allItems=true
  allSuppliers: boolean
  supplierCodes: string[] // empty when allSuppliers=true
  // PO Item-Wise only ('A'=all, 'Y'=confirmed, 'N'=not confirmed) — optional so
  // PR/Pending-PR reports (which share this param shape) aren't forced to carry it.
  confirmStatus?: string
}
