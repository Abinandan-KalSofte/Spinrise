import { create, type UseBoundStore, type StoreApi } from 'zustand'
import type { PoApprovalApiClient } from '../api/createPoApprovalApi'
import type {
  PoApprovalLine,
  DivisionOption,
  DispositionCode,
  PoApprovalFilterState,
  PoApprovalSaveResult,
} from '../types/poApprovalTypes'
import { isReasonRequired } from '../types/poApprovalTypes'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'

// 10-Jul-2026: FY guard, same pattern as the PR module — accessed via
// useAuthStore.getState() since this store creator runs outside React.
function currentFYBounds() {
  const processingDate = useAuthStore.getState().processingDate
  return getFYBounds(processingDate ? new Date(processingDate) : undefined)
}

// Shared store shape/logic for every PO Approval level (First/Second/Final).
// The three levels are independent queues (different mock/API data, no
// shared runtime state), but the save/refresh/selection state machine is
// identical FSD business logic — factored out here so each level's store
// hook is a thin one-line instantiation instead of a ~180-line duplicate.

export interface PoApprovalState {
  lines:        PoApprovalLine[]
  divisions:    DivisionOption[]
  gridLoaded:   boolean
  loading:      boolean
  saving:       boolean
  filter:       PoApprovalFilterState
  auditNoteVisible: boolean

  loadDivisions: () => Promise<void>
  loadGrid:      () => Promise<void>
  setFilter:     (patch: Partial<PoApprovalFilterState>) => void
  updateDisposition: (pordno: string, code: DispositionCode) => void
  updateRemarks:     (pordno: string, remarks: string) => void
  updatePostponeDate: (pordno: string, date: string) => void
  toggleRow:     (pordno: string, selected: boolean) => void
  toggleAll:     (selected: boolean) => void
  cancelSelections: () => void
  setSaving:     (v: boolean) => void
  executeSave:   (result: PoApprovalSaveResult) => void
  refresh:       () => Promise<void>
  reset:         () => void
}

const initFilter: PoApprovalFilterState = {
  divCode:    '0',
  poNoSearch: '',
}

const initState = {
  lines:            [] as PoApprovalLine[],
  divisions:        [] as DivisionOption[],
  gridLoaded:       false,
  loading:          false,
  saving:           false,
  filter:           initFilter,
  auditNoteVisible: false,
}

// FSD §3.3 — a row remains actionable while pending / re-surfaced (postponed) / PL Discuss.
export function isActionable(line: PoApprovalLine): boolean {
  return line.status === 'pending' || line.status === 'hold' || line.status === 'pldiscuss'
}

export function createPoApprovalStore(api: PoApprovalApiClient): UseBoundStore<StoreApi<PoApprovalState>> {
  return create<PoApprovalState>((set, get) => ({
    ...initState,

    loadDivisions: async () => {
      const divisions = await api.getDivisions()
      set({ divisions })
    },

    loadGrid: async () => {
      const { filter } = get()
      set({ loading: true })
      try {
        const { yfDate, ylDate } = currentFYBounds()
        const resp = await api.getPending(filter.divCode, yfDate, ylDate, filter.poNoSearch)
        set({ lines: resp.items, gridLoaded: true })
      } finally {
        set({ loading: false })
      }
    },

    setFilter: (patch) => set((s) => ({ filter: { ...s.filter, ...patch } })),

    updateDisposition: (pordno, code) => {
      set((s) => ({
        lines: s.lines.map((l) => (l.pordno === pordno ? { ...l, disposition: code } : l)),
      }))
    },

    updateRemarks: (pordno, remarks) => {
      set((s) => ({
        lines: s.lines.map((l) => (l.pordno === pordno ? { ...l, remarks } : l)),
      }))
    },

    updatePostponeDate: (pordno, date) => {
      set((s) => ({
        lines: s.lines.map((l) => (l.pordno === pordno ? { ...l, postponeDate: date } : l)),
      }))
    },

    toggleRow: (pordno, selected) => {
      set((s) => ({
        lines: s.lines.map((l) => (l.pordno === pordno ? { ...l, selected } : l)),
      }))
    },

    toggleAll: (selected) => {
      set((s) => ({
        lines: s.lines.map((l) => (isActionable(l) ? { ...l, selected } : l)),
      }))
    },

    cancelSelections: () => {
      set((s) => ({
        lines: s.lines.map((l) =>
          isActionable(l)
            ? { ...l, selected: false, disposition: 2, remarks: '', postponeDate: undefined }
            : l,
        ),
      }))
    },

    setSaving: (v) => set({ saving: v }),

    // Applies the save result to local state — mirrors the prototype's
    // executeSave(): committed disposition becomes `status`, Declined POs'
    // lines are marked fclosed.
    executeSave: (result) => {
      set((s) => ({
        lines: s.lines.map((l) => {
          if (!l.selected) return l
          if (!result.saved.includes(l.pordno)) return l
          const status =
            l.disposition === 2 ? 'approved'
            : l.disposition === 3 ? 'hold'
            : l.disposition === 4 ? 'declined'
            : l.disposition === 5 ? 'postponed'
            : 'pldiscuss'
          // Final Level (grouped view, no `lines[]`) has nothing to mark fclosed on —
          // CEO Decision 4: Declined/Hold/Postpone leave firstLevelApp/secondLevelApp
          // untouched regardless of level, so no other field needs resetting here either.
          const lines = status === 'declined' && l.lines
            ? l.lines.map((ln) => ({ ...ln, fclosed: 'Y' as const }))
            : l.lines
          // Approved sets the Final-level flag (conflg) — harmless no-op for
          // First/Second Level, which never read/display conflg.
          const conflg = status === 'approved' ? 'Y' : l.conflg
          return { ...l, status, selected: false, lines, conflg }
        }),
        auditNoteVisible: true,
      }))
    },

    // FSD §3.2/§3.3 — Refresh sweeps Approved/Declined rows out of this list
    // (they move to the next level / are closed) and re-surfaces Postponed
    // rows back to `pending`. Hold rows are untouched.
    refresh: async () => {
      const { gridLoaded } = get()
      if (!gridLoaded) {
        await get().loadGrid()
        return
      }
      set({ loading: true })
      try {
        const { filter } = get()
        const { yfDate, ylDate } = currentFYBounds()
        const resp = await api.getPending(filter.divCode, yfDate, ylDate, filter.poNoSearch)
        set((s) => ({
          lines: resp.items.map((fresh) => {
            const prev = s.lines.find((l) => l.pordno === fresh.pordno)
            if (prev?.status === 'postponed') {
              return { ...fresh, status: 'pending', disposition: 2, remarks: '', postponeDate: undefined }
            }
            if (prev?.status === 'hold') {
              return { ...fresh, status: 'hold', disposition: prev.disposition, remarks: prev.remarks }
            }
            return fresh
          }),
        }))
      } finally {
        set({ loading: false })
      }
    },

    reset: () => set({ ...initState, divisions: get().divisions }),
  }))
}

// ── Selectors (computed — not stored; identical across levels) ───────────────

export const selectSelectedLines = (lines: PoApprovalLine[]) =>
  lines.filter((l) => l.selected)

export const selectLinesNeedingReason = (lines: PoApprovalLine[]) =>
  selectSelectedLines(lines).filter((l) => isReasonRequired(l.disposition))

// Final Level (grouped view) carries no `lines[]` — falls back to the
// `poValue` aggregate the API supplies directly for that case.
export const selectItemValue = (line: PoApprovalLine) =>
  line.lines ? line.lines.reduce((s, ln) => s + ln.value, 0) : (line.poValue ?? 0)

export const selectTotalItemValue = (lines: PoApprovalLine[]) =>
  selectSelectedLines(lines).reduce((s, l) => s + selectItemValue(l), 0)

export const selectTotalPoValue = (lines: PoApprovalLine[]) =>
  selectSelectedLines(lines).reduce((s, l) => s + l.netTotal, 0)

export const selectPendingCount = (lines: PoApprovalLine[]) =>
  lines.filter(isActionable).length
