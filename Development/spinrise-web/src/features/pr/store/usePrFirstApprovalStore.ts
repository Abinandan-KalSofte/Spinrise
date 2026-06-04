import { create } from 'zustand'
import { message } from 'antd'
import { prFirstApprovalApi } from '../api/prFirstApprovalApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type {
  PoParaApproval,
  ApprovalDept,
  PrApprovalSummary,
  PrApprovalDetail,
  PrApprovalLineLocal,
  ApprovalScreenMode,
} from '../types/prFirstApprovalTypes'

interface PrFirstApprovalState {
  // ── Screen state ─────────────────────────────────────────────────────────────
  mode:         ApprovalScreenMode
  poPara:       PoParaApproval | null
  yfDate:       string   // financial year start — from poPara (server-computed)
  ylDate:       string   // financial year end
  depts:        ApprovalDept[]
  pendingList:  PrApprovalSummary[]
  approvedList: PrApprovalSummary[]
  detail:       PrApprovalDetail | null
  lines:        PrApprovalLineLocal[]
  loading:      boolean
  saving:       boolean

  // ── Actions ───────────────────────────────────────────────────────────────────
  loadPoPara:      (divCode: string) => Promise<void>
  loadDepts:       (divCode: string) => Promise<void>
  loadPendingList: (divCode: string, dep: string) => Promise<void>
  loadApprovedList:(divCode: string) => Promise<void>
  loadDetail:      (divCode: string, prNo: number, prDate: string, mode: 'APPROVE' | 'DELETE' | 'SAVED') => Promise<void>
  updateLine:      (key: string, field: 'editFirstAppQty' | 'editRate', value: number) => void
  toggleRow:       (key: string, checked: boolean) => void
  toggleAllRows:   (checked: boolean) => void
  approve:         (divCode: string, appDate: string) => Promise<void>
  deleteApproval:  (divCode: string) => Promise<void>
  reset:           () => void
  softReset:       () => void
}

const initState = {
  mode:         'QUERY' as ApprovalScreenMode,
  poPara:       null,
  yfDate:       '',
  ylDate:       '',
  depts:        [],
  pendingList:  [],
  approvedList: [],
  detail:       null,
  lines:        [],
  loading:      false,
  saving:       false,
}

export const usePrFirstApprovalStore = create<PrFirstApprovalState>((set, get) => ({
  ...initState,

  loadPoPara: async (divCode) => {
    try {
      const poPara = await prFirstApprovalApi.getPoPara(divCode)
      const pd = useAuthStore.getState().processingDate
      const ylDate = pd && pd < poPara.ylDate ? pd : poPara.ylDate
      set({ poPara, yfDate: poPara.yfDate, ylDate })
    } catch {
      message.error('Set User Level In Parameter Form')
    }
  },

  loadDepts: async (divCode) => {
    set({ loading: true })
    try {
      const depts = await prFirstApprovalApi.getDepartments(divCode)
      set({ depts })
    } catch (e: unknown) {
      message.error(e instanceof Error ? e.message : 'Failed to load departments')
    } finally {
      set({ loading: false })
    }
  },

  loadPendingList: async (divCode, dep) => {
    const { yfDate, ylDate } = get()
    set({ loading: true })
    try {
      const pendingList = await prFirstApprovalApi.getPendingList(divCode, dep, yfDate, ylDate)
      set({ pendingList })
      if (pendingList.length === 0) message.info('No Records Found')
    } catch (e: unknown) {
      message.error(e instanceof Error ? e.message : 'Failed to load pending PRs')
    } finally {
      set({ loading: false })
    }
  },

  loadApprovedList: async (divCode) => {
    const { yfDate, ylDate } = get()
    set({ loading: true })
    try {
      const approvedList = await prFirstApprovalApi.getApprovedList(divCode, yfDate, ylDate)
      set({ approvedList })
      if (approvedList.length === 0) message.info('No Records Found')
    } catch (e: unknown) {
      message.error(e instanceof Error ? e.message : 'Failed to load approved PRs')
    } finally {
      set({ loading: false })
    }
  },

  loadDetail: async (divCode, prNo, prDate, mode) => {
    set({ loading: true })
    try {
      const detail = await prFirstApprovalApi.getDetail(divCode, prNo, prDate)

      // APPROVE: only unapproved lines — already-approved lines cannot be re-approved.
      // SAVED:   only approved lines — unapproved lines with firstAppQty=0 are meaningless in view.
      // DELETE:  all lines — must show everything that will be reset.
      const eligibleLines =
        mode === 'APPROVE' ? detail.lines.filter((l) => l.firstApp !== 'Y') :
        mode === 'SAVED'   ? detail.lines.filter((l) => l.firstApp === 'Y') :
        detail.lines

      const lines: PrApprovalLineLocal[] = eligibleLines.map((l) => ({
        ...l,
        key:             `${l.prSno}-${l.itemCode}`,
        selected:        false,
        editRate:        l.rate,
        editFirstAppQty: mode === 'APPROVE' ? l.qtyInd : l.firstAppQty,
        calcValue:       (mode === 'APPROVE' ? l.qtyInd : l.firstAppQty) * l.rate,
        hasError:        false,
      }))
      set({ detail, lines, mode })
    } catch (e: unknown) {
      message.error(e instanceof Error ? e.message : 'Failed to load PR detail')
    } finally {
      set({ loading: false })
    }
  },

  updateLine: (key, field, value) => {
    set((state) => ({
      lines: state.lines.map((l) => {
        if (l.key !== key) return l
        const updated = { ...l, [field]: value }
        updated.calcValue = +(updated.editFirstAppQty * updated.editRate).toFixed(2)
        updated.hasError  = updated.editFirstAppQty > updated.qtyInd
        if (updated.hasError) {
          message.warning(
            `First Approval Quantity must be less than or equal to Quantity Required — row ${l.prSno}`
          )
        }
        return updated
      }),
    }))
  },

  toggleRow: (key, checked) => {
    set((state) => ({
      lines: state.lines.map((l) =>
        l.key === key ? { ...l, selected: checked } : l
      ),
    }))
  },

  toggleAllRows: (checked) => {
    set((state) => ({
      lines: state.lines.map((l) => ({ ...l, selected: checked })),
    }))
  },

  approve: async (divCode, appDate) => {
    const { detail, lines } = get()
    if (!detail) return

    const selectedLines = lines.filter((l) => l.selected)
    if (selectedLines.length === 0) {
      message.error('Item is not Selected')
      return
    }

    // CR-M01-001: block save when any selected row has qty > required
    const invalidRows = selectedLines.filter((l) => l.hasError)
    if (invalidRows.length > 0) {
      const rowNums = invalidRows.map((l) => `row ${l.prSno}`).join(', ')
      message.error(
        `First Approval Quantity exceeds Required Quantity for ${rowNums}. Please correct before saving.`
      )
      return
    }

    if (new Date(appDate) > new Date()) {
      message.error('Date should be Equal to Current Date Or Max Purchase Requisition Date')
      return
    }

    set({ saving: true })
    try {
      await prFirstApprovalApi.approve(divCode, {
        prNo:    detail.header.prNo,
        prDate:  detail.header.prDate,
        appDate,
        lines:   selectedLines.map((l) => ({
          prSno:       l.prSno,
          itemCode:    l.itemCode,
          depCode:     detail.header.depCode,
          qtyReqd:     l.editFirstAppQty,
          firstAppQty: l.editFirstAppQty,
          rate:        l.editRate,
          macNo:       l.macNo,
          subCost:     detail.header.subCost,
          uom:         l.uom,
        })),
      })

      // DEF-FA-04/05: transition to SAVED immediately so form becomes read-only
      // CR-M01-007: clear pending list so next Load PRs re-fetches fresh from API
      set({ mode: 'SAVED', pendingList: [] })

      // Refresh from DB — filter to approved lines only for SAVED view
      try {
        const refreshed = await prFirstApprovalApi.getDetail(divCode, detail.header.prNo, detail.header.prDate)
        const refreshedLines: PrApprovalLineLocal[] = refreshed.lines
          .filter((l) => l.firstApp === 'Y')
          .map((l) => ({
            ...l,
            key:             `${l.prSno}-${l.itemCode}`,
            selected:        false,
            editRate:        l.rate,
            editFirstAppQty: l.firstAppQty,
            calcValue:       +(l.firstAppQty * l.rate).toFixed(2),
            hasError:        false,
          }))
        set({ detail: refreshed, lines: refreshedLines })
      } catch {
        // Refresh failed — SAVED mode already set; user sees last known approved state
      }

      message.success(
        `PR-${String(detail.header.prNo).padStart(5, '0')} — First Level Approval saved.`
      )
    } catch (e: unknown) {
      message.error(e instanceof Error ? e.message : 'Save failed')
    } finally {
      set({ saving: false })
    }
  },

  deleteApproval: async (divCode) => {
    const { detail, yfDate, ylDate, poPara } = get()
    if (!detail) return

    set({ saving: true })
    try {
      await prFirstApprovalApi.deleteApproval(divCode, {
        prNo:   detail.header.prNo,
        prDate: detail.header.prDate,
      })
      message.success(
        `PR-${String(detail.header.prNo).padStart(5, '0')} — First Level Approval deleted. PRSTATUS → Requested.`
      )
      get().reset()
      // Restore FY dates so subsequent Find / loadApprovedList still works
      set({ yfDate, ylDate, poPara })
    } catch (e: unknown) {
      message.error(e instanceof Error ? e.message : 'Delete failed')
    } finally {
      set({ saving: false })
    }
  },

  reset: () => set(initState),

  softReset: () => {
    const { yfDate, ylDate, poPara } = get()
    set({ ...initState, yfDate, ylDate, poPara })
  },
}))
