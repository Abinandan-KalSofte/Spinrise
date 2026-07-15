import dayjs from 'dayjs'
import { create } from 'zustand'
import { getDepartments, getReportItems } from '../../pr/api/prReportApi'
import { getSuppliers } from '../api/supplierApi'
import { getCurrentMonthStart } from '@/shared/lib/dateUtils'
import type { ReportFilter, ReportLookups } from '../types/reportTypes'
import type { TabType } from '../configs/reportConfigs'

function buildInitFilter(reportId: string, defaultTab: TabType): ReportFilter {
  return {
    reportId,
    reportType: defaultTab,
    fromDate: getCurrentMonthStart(),
    toDate: dayjs().format('YYYY-MM-DD'),
    selectedDeptCodes: [],
    selectedItemCodes: [],
    selectedSupplierCodes: [],
    allDepts: true,
    allItems: true,
    allSuppliers: true,
    confirmStatus: 'A',
  }
}

interface ReportState {
  filter: ReportFilter | null
  lookups: ReportLookups
  loadingLookups: boolean
  generating: boolean

  previewOpen: boolean
  previewBlobUrl: string | null
  previewFilename: string

  setFilter: (patch: Partial<ReportFilter>) => void
  setReportType: (t: TabType) => void
  loadLookups: (divCode: string) => Promise<void>
  setGenerating: (v: boolean) => void
  openPreview: (url: string, filename: string) => void
  closePreview: () => void
  reset: (newReportId: string, defaultTab: TabType) => void
  clear: () => void
}

export const useReportStore = create<ReportState>((set, get) => ({
  filter: null,
  lookups: { departments: [], items: [], suppliers: [] },
  loadingLookups: false,
  generating: false,

  previewOpen: false,
  previewBlobUrl: null,
  previewFilename: '',

  setFilter: (patch) => {
    set((s) => s.filter ? { filter: { ...s.filter, ...patch } } : {})
  },

  setReportType: (reportType) => {
    set((s) => s.filter ? {
      filter: {
        ...s.filter,
        reportType,
        selectedDeptCodes: [],
        selectedItemCodes: [],
        selectedSupplierCodes: [],
        allDepts: true,
        allItems: true,
        allSuppliers: true,
        confirmStatus: 'A',
      },
    } : {})
  },

  loadLookups: async (divCode) => {
    set({ loadingLookups: true })
    try {
      const [departments, items, suppliers] = await Promise.all([
        getDepartments(divCode),
        getReportItems(divCode),
        getSuppliers(divCode),
      ])
      set({ lookups: { departments, items, suppliers } })
    } catch {
      // Non-critical
    } finally {
      set({ loadingLookups: false })
    }
  },

  setGenerating: (v) => set({ generating: v }),

  openPreview: (url, filename) => {
    const prev = get().previewBlobUrl
    if (prev) URL.revokeObjectURL(prev)
    set({ previewOpen: true, previewBlobUrl: url, previewFilename: filename })
  },

  closePreview: () => {
    set({ previewOpen: false })
    const url = get().previewBlobUrl
    if (url) {
      setTimeout(() => {
        URL.revokeObjectURL(url)
      }, 500)
    }
    set({ previewBlobUrl: null, previewFilename: '' })
  },

  reset: (newReportId, defaultTab) => {
    const url = get().previewBlobUrl
    if (url) URL.revokeObjectURL(url)
    set({
      filter: buildInitFilter(newReportId, defaultTab),
      previewOpen: false,
      previewBlobUrl: null,
      previewFilename: '',
    })
  },

  // No report selected yet (e.g. /periodic-report on a fresh visit, before
  // the user picks one) — clears filter back to null so no stale prior
  // selection leaks through the "already selected" picker highlight or the
  // filter/summary/preview panels, which all key off filter being non-null.
  clear: () => {
    const url = get().previewBlobUrl
    if (url) URL.revokeObjectURL(url)
    set({
      filter: null,
      previewOpen: false,
      previewBlobUrl: null,
      previewFilename: '',
    })
  },
}))
