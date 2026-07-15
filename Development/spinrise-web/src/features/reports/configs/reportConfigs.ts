/**
 * Configuration-driven report definitions.
 * Each report defines: id, title, API endpoints, tabs, filters, and hints.
 * Future reports can be added here without modifying page logic.
 */

import { fetchReportBlob as fetchPrReportBlob } from '../../pr/api/prReportApi'
import { fetchPendingPrReportBlob } from '../../pr/api/pendingPrReportApi'
import { fetchPoReportBlob } from '../api/poReportApi'
import type { DownloadReportParams } from '../../pr/types/prReportTypes'

export type TabType = 'Datewise' | 'Departmentwise' | 'Itemwise' | 'Supplierwise'

export type FilterType = 'date' | 'department' | 'item' | 'supplier' | 'confirmStatus'

export interface FilterConfig {
  type: FilterType
  label: string
}

export interface ReportConfig {
  id: string
  title: string
  subtitle?: string
  tabs: TabType[]
  defaultTab: TabType
  filters: Record<TabType, FilterConfig[]>
  hints: Record<TabType, string>
  docBandTitle: string
  previewTitle: string
  fetchBlob: (params: DownloadReportParams) => Promise<{ blobUrl: string; filename: string }>
  getFilename: (reportType: TabType, fromDate: string, toDate: string) => string
}

export const REPORT_CONFIGS: Record<string, ReportConfig> = {
  'pr-report': {
    id: 'pr-report',
    title: 'Purchase Requisition List',
    subtitle: 'Purchase Requisition',
    tabs: ['Datewise', 'Departmentwise', 'Itemwise'],
    defaultTab: 'Datewise',
    filters: {
      Datewise: [{ type: 'date', label: 'Date Range' }],
      Departmentwise: [{ type: 'date', label: 'Date Range' }, { type: 'department', label: 'Department Filter' }],
      Itemwise: [{ type: 'date', label: 'Date Range' }, { type: 'item', label: 'Item Filter' }],
      Supplierwise: [],
    },
    hints: {
      Datewise: 'Select a date range and click Generate Report to download the Datewise PR list as a PDF.',
      Departmentwise: 'Select a date range and a Department, then click Generate Report.',
      Itemwise: 'Select a date range. Use All Items or choose specific items, then click Generate Report.',
      Supplierwise: '',
    },
    docBandTitle: 'Purchase Requisition Report',
    previewTitle: 'Purchase Requisition Report Preview',
    fetchBlob: fetchPrReportBlob,
    getFilename: (type, from, to) => {
      const fromStr = from.replace(/-/g, '')
      const toStr = to.replace(/-/g, '')
      const fileMap: Record<TabType, string> = {
        Datewise: `PRDatewise_${fromStr}_${toStr}.pdf`,
        Departmentwise: `PRDeptWise_${fromStr}_${toStr}.pdf`,
        Itemwise: `PRItemWise_${fromStr}_${toStr}.pdf`,
        Supplierwise: `PRSupplierWise_${fromStr}_${toStr}.pdf`,
      }
      return fileMap[type] || fileMap.Datewise
    },
  },

  'pending-pr-report': {
    id: 'pending-pr-report',
    title: 'Pending Purchase Requisition List',
    subtitle: 'Pending Purchase Requisition',
    tabs: ['Datewise', 'Departmentwise', 'Itemwise'],
    defaultTab: 'Datewise',
    filters: {
      Datewise: [{ type: 'date', label: 'Date Range' }],
      Departmentwise: [{ type: 'date', label: 'Date Range' }, { type: 'department', label: 'Department Filter' }],
      Itemwise: [{ type: 'date', label: 'Date Range' }, { type: 'item', label: 'Item Filter' }],
      Supplierwise: [],
    },
    hints: {
      Datewise: 'Select a date range and click Generate Report to download the Pending PR Date-wise list as a PDF.',
      Departmentwise: 'Select a date range and a Department, then click Generate Report.',
      Itemwise: 'Select a date range. Use All Items or choose specific items, then click Generate Report.',
      Supplierwise: '',
    },
    docBandTitle: 'Pending Purchase Requisition Report',
    previewTitle: 'Pending Purchase Requisition Report Preview',
    fetchBlob: fetchPendingPrReportBlob,
    getFilename: (type, from, to) => {
      const fromStr = from.replace(/-/g, '')
      const toStr = to.replace(/-/g, '')
      const fileMap: Record<TabType, string> = {
        Datewise: `PendingPRDatewise_${fromStr}_${toStr}.pdf`,
        Departmentwise: `PendingPRDeptWise_${fromStr}_${toStr}.pdf`,
        Itemwise: `PendingPRItemWise_${fromStr}_${toStr}.pdf`,
        Supplierwise: `PendingPRSupplierWise_${fromStr}_${toStr}.pdf`,
      }
      return fileMap[type] || fileMap.Datewise
    },
  },

  'po-report': {
    id: 'po-report',
    title: 'Purchase Order List',
    subtitle: 'Purchase Order',
    tabs: ['Datewise', 'Supplierwise', 'Itemwise'],
    defaultTab: 'Datewise',
    filters: {
      Datewise: [{ type: 'date', label: 'Date Range' }],
      Departmentwise: [],
      Itemwise: [
        { type: 'date', label: 'Date Range' },
        { type: 'item', label: 'Item Filter' },
        { type: 'confirmStatus', label: 'Final Approval Status' },
      ],
      Supplierwise: [{ type: 'date', label: 'Date Range' }, { type: 'supplier', label: 'Supplier Filter' }],
    },
    hints: {
      Datewise: 'Select a date range and click Generate Report to download the Datewise PO list as a PDF.',
      Departmentwise: '.',
      Itemwise: 'Select a date range. Use All Items or choose specific items, then click Generate Report.',
      Supplierwise: 'Select a date range and a Supplier, then click Generate Report.',
    },
    docBandTitle: 'Purchase Order Report',
    previewTitle: 'Purchase Order Report Preview',
    fetchBlob: fetchPoReportBlob,
    getFilename: (type, from, to) => {
      const fromStr = from.replace(/-/g, '')
      const toStr = to.replace(/-/g, '')
      const fileMap: Record<TabType, string> = {
        Datewise: `PODatewise_${fromStr}_${toStr}.pdf`,
        Departmentwise: `PODeptWise_${fromStr}_${toStr}.pdf`,
        Itemwise: `POItemWise_${fromStr}_${toStr}.pdf`,
        Supplierwise: `POSupplierWise_${fromStr}_${toStr}.pdf`,
      }
      return fileMap[type] || fileMap.Datewise
    },
  },
}

export function getReportConfig(reportId: string): ReportConfig | null {
  return REPORT_CONFIGS[reportId] || null
}

export function getAllReports(): ReportConfig[] {
  return Object.values(REPORT_CONFIGS)
}
