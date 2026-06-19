import { create } from 'zustand'
import { getDepartments, getReportItems } from '../api/prReportApi'
import type { DeptOption, PrItemOption, PrReportFilter, ReportType } from '../types/prReportTypes'

// ── Initial filter ─────────────────────────────────────────────────────────────

function buildInitFilter(): PrReportFilter {
  const now  = new Date()
  const from = new Date(now.getFullYear(), now.getMonth(), 1)
  return {
    reportType:        'Datewise',
    fromDate:          from.toISOString().split('T')[0],
    toDate:            now.toISOString().split('T')[0],
    selectedDeptCode:  '',
    selectedItemCodes: [],
    allItems:          true,
  }
}

// ── Store interface ────────────────────────────────────────────────────────────

interface PrReportState {
  filter:          PrReportFilter
  departments:     DeptOption[]
  items:           PrItemOption[]
  loadingLookups:  boolean
  generating:      boolean

  // Preview state
  previewOpen:     boolean
  previewBlobUrl:  string | null
  previewFilename: string

  // Actions
  setFilter:     (patch: Partial<PrReportFilter>) => void
  setReportType: (t: ReportType) => void
  loadLookups:   (divCode: string) => Promise<void>
  setGenerating: (v: boolean) => void
  openPreview:   (url: string, filename: string) => void
  closePreview:  () => void
  reset:         () => void
}

// ── Store ─────────────────────────────────────────────────────────────────────

export const usePrReportStore = create<PrReportState>((set, get) => ({
  filter:          buildInitFilter(),
  departments:     [],
  items:           [],
  loadingLookups:  false,
  generating:      false,

  previewOpen:     false,
  previewBlobUrl:  null,
  previewFilename: '',

  setFilter: (patch) => {
    set((s) => ({ filter: { ...s.filter, ...patch } }))
  },

  setReportType: (reportType) => {
    set((s) => ({
      filter: {
        ...s.filter,
        reportType,
        selectedDeptCode:  '',
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
      // Non-critical — Datewise still works without lookup data
    } finally {
      set({ loadingLookups: false })
    }
  },

  setGenerating: (v) => set({ generating: v }),

  openPreview: (url, filename) => {
    // Revoke any previously held blob URL to avoid memory leaks
    const prev = get().previewBlobUrl
    if (prev) URL.revokeObjectURL(prev)
    set({ previewOpen: true, previewBlobUrl: url, previewFilename: filename })
  },

  closePreview: () => {
    set({ previewOpen: false })
    // Keep blobUrl alive briefly so the modal's destroy animation can complete,
    // then revoke it.
    const url = get().previewBlobUrl
    if (url) {
      setTimeout(() => {
        URL.revokeObjectURL(url)
      }, 500)
    }
    set({ previewBlobUrl: null, previewFilename: '' })
  },

  reset: () => {
    const url = get().previewBlobUrl
    if (url) URL.revokeObjectURL(url)
    set({
      filter:          buildInitFilter(),
      previewOpen:     false,
      previewBlobUrl:  null,
      previewFilename: '',
    })
  },
}))
