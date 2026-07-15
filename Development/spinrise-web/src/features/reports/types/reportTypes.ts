import type { TabType } from '../configs/reportConfigs'
import type { DeptOption, PrItemOption } from '../../pr/types/prReportTypes'

export type ItemOption = PrItemOption

export interface SupplierOption {
  slCode: string
  slName: string
}

export type { DeptOption }

export interface ReportFilter {
  reportId: string
  reportType: TabType
  fromDate: string
  toDate: string
  selectedDeptCodes: string[]
  selectedItemCodes: string[]
  selectedSupplierCodes: string[]
  allDepts: boolean
  allItems: boolean
  allSuppliers: boolean
  // PO Item-Wise only: VB6's confirm-status filter — 'A'=all, 'Y'=confirmed, 'N'=not confirmed.
  confirmStatus: string
}

export interface ReportLookups {
  departments: DeptOption[]
  items: ItemOption[]
  suppliers: SupplierOption[]
}
