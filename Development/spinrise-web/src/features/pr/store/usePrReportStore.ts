import { create } from 'zustand'
import { getDepartments, getReportItems } from '../api/prReportApi'
import type { DeptOption, PrItemOption, PrReportFilter, ReportType } from '../types/prReportTypes'

// ── Initial date helpers ───────────────────────────────────────────────────────

function buildInitFilter(): PrReportFilter {
  const now  = new Date()
  const from = new Date(now.getFullYear(), now.getMonth(), 1)
  return {
    reportType:        'Datewise',
    fromDate:          from.toISOString().split('T')[0],
    toDate:            now.toISOString().split('T')[0],
    selectedDeptCodes: [],
    selectedItemCodes: [],
    allItems:          true,
  }
}

// ── Store interface ────────────────────────────────────────────────────────────

interface PrReportState {
  filter:         PrReportFilter
  departments:    DeptOption[]
  items:          PrItemOption[]
  loadingLookups: boolean
  generating:     boolean

  setFilter:     (patch: Partial<PrReportFilter>) => void
  setReportType: (t: ReportType) => void
  loadLookups:   (divCode: string) => Promise<void>
  setGenerating: (v: boolean) => void
  reset:         () => void
}

// ── Store ─────────────────────────────────────────────────────────────────────

export const usePrReportStore = create<PrReportState>((set) => ({
  filter:         buildInitFilter(),
  departments:    [],
  items:          [],
  loadingLookups: false,
  generating:     false,

  setFilter: (patch) => {
    set((s) => ({ filter: { ...s.filter, ...patch } }))
  },

  // Changing report type resets the mode-specific selections
  setReportType: (reportType) => {
    set((s) => ({
      filter: {
        ...s.filter,
        reportType,
        selectedDeptCodes: [],
        selectedItemCodes: [],
        allItems:          true,
      },
    }))
  },

  loadLookups: async (divCode) => {
    set({ loadingLookups: true })
    try {
      const [departments, items] = await Promise.all([
        getDepartments(divCode),
        getReportItems(divCode),
      ])
      set({ departments, items })
    } catch {
      // Non-critical — user can still use Datewise without lookup data
    } finally {
      set({ loadingLookups: false })
    }
  },

  setGenerating: (v) => set({ generating: v }),

  reset: () => set({ filter: buildInitFilter() }),
}))
