import { create } from 'zustand'
import { finalApprovalApi } from '../api/finalApprovalApi'
import { prFirstApprovalApi } from '../api/prFirstApprovalApi'
import type {
  FinalApprovalLine,
  FinalApprovalFilterState,
  DispositionCode,
  CompanyOption,
  DivisionOption,
} from '../types/finalApprovalTypes'

interface ApprovalLevelLabels {
  appUserLabel1: string
  appUserLabel2: string
  appUserLabel3: string
}

interface FinalApprovalState {
  // ── Data ─────────────────────────────────────────────────────────────────────
  lines:        FinalApprovalLine[]
  companies:    CompanyOption[]
  divisions:    DivisionOption[]
  approvalLabels: ApprovalLevelLabels
  gridLoaded:   boolean
  loading:      boolean
  saving:       boolean
  filter:       FinalApprovalFilterState

  // ── Actions ───────────────────────────────────────────────────────────────────
  loadCompanies:    () => Promise<void>
  loadDivisions:    (dbName: string) => Promise<void>
  loadApprovalLabels: (divCode: string) => Promise<void>
  loadGrid:         () => Promise<void>
  setFilter:        (patch: Partial<FinalApprovalFilterState>) => void
  updateQty:        (idx: number, qty: number) => void
  updateDisposition:(idx: number, code: DispositionCode) => void
  toggleRow:        (idx: number, selected: boolean) => void
  toggleAll:        (selected: boolean) => void
  setSaving:        (v: boolean) => void
  reset:            () => void
}

const initFilter: FinalApprovalFilterState = {
  dbName:    '',
  divCode:   '0',
  bypassAll: true,
}

const initState = {
  lines:          [] as FinalApprovalLine[],
  companies:      [] as CompanyOption[],
  divisions:      [] as DivisionOption[],
  approvalLabels: { appUserLabel1: 'First', appUserLabel2: 'Second', appUserLabel3: 'Third' } as ApprovalLevelLabels,
  gridLoaded:     false,
  loading:        false,
  saving:         false,
  filter:         initFilter,
}

export const useFinalApprovalStore = create<FinalApprovalState>((set, get) => ({
  ...initState,

  loadCompanies: async () => {
    const companies = await finalApprovalApi.getCompanies()
    set({ companies })
  },

  loadApprovalLabels: async (divCode) => {
    try {
      const para = await prFirstApprovalApi.getPoPara(divCode)
      if (para) {
        set({
          approvalLabels: {
            appUserLabel1: para.appUserLabel1 || 'First',
            appUserLabel2: para.appUserLabel2 || 'Second',
            appUserLabel3: para.appUserLabel3 || 'Third',
          },
        })
      }
    } catch {
      // Keep defaults if fetch fails
    }
  },

  loadDivisions: async (dbName) => {
    const divisions = await finalApprovalApi.getDivisions(dbName)
    set({ divisions })
  },

  loadGrid: async () => {
    const { filter } = get()
    set({ loading: true, gridLoaded: false })
    try {
      const bypass = filter.bypassAll ? 1 : 0
      const resp   = await finalApprovalApi.getPending(filter.dbName, filter.divCode, bypass)
      const lines  = resp.items.map((item) => ({ ...item, selected: false }))
      set({ lines, gridLoaded: true })
    } finally {
      set({ loading: false })
    }
  },

  setFilter: (patch) => {
    set((s) => ({ filter: { ...s.filter, ...patch } }))
  },

  updateQty: (idx, qty) => {
    set((s) => {
      const lines = [...s.lines]
      lines[idx] = { ...lines[idx], qtyApproved: qty }
      return { lines }
    })
  },

  updateDisposition: (idx, code) => {
    const safeCode = Number(code) as DispositionCode   // guard against Select returning a string
    set((s) => {
      const lines = [...s.lines]
      const selected = safeCode === 1 ? false : lines[idx].selected
      lines[idx] = { ...lines[idx], disposition: safeCode, selected }
      return { lines }
    })
  },

  toggleRow: (idx, selected) => {
    set((s) => {
      const lines = [...s.lines]
      // Cannot select PL Discuss rows
      if (lines[idx].disposition === 1) return { lines }
      lines[idx] = { ...lines[idx], selected }
      return { lines }
    })
  },

  toggleAll: (selected) => {
    set((s) => ({
      lines: s.lines.map((l) =>
        l.disposition === 1 ? l : { ...l, selected }
      ),
    }))
  },

  setSaving: (v) => set({ saving: v }),

  reset: () => set({ lines: [], gridLoaded: false }),
}))

// ── Selectors (computed — not stored) ─────────────────────────────────────────

export const selectEligibleLines = (lines: FinalApprovalLine[]) =>
  lines.filter((l) => l.selected && l.disposition !== 1)

export const selectTotalCost = (lines: FinalApprovalLine[]) =>
  lines.reduce((s, l) => s + l.qtyRequired * l.lpoRate, 0)

export const selectSelectedCost = (lines: FinalApprovalLine[]) =>
  selectEligibleLines(lines).reduce((s, l) => s + l.qtyRequired * l.lpoRate, 0)
