import { create } from 'zustand'
import type {
  ScreenMode,
  PoParameters,
  PoHeader,
  PoLine,
  DeliveryScheduleLine,
  DeliverySlot,
} from '../types'
import { DS_MAX_SLOTS } from '../types'

interface PoTransferState {
  // Screen mode — VIEW / ADD / DELETE (no EDIT; Modify is a separate screen)
  mode: ScreenMode

  // Parameters (loaded once on screen open)
  parameters: PoParameters | null

  // Currently displayed PO
  currentPo: PoHeader | null

  // Working lines (Add) — re-sequenced on remove
  draftLines: PoLine[]

  // Delivery schedule (fixed 4-slot per line — Sprint 1, Q3)
  deliveryLines: DeliveryScheduleLine[]

  // Row currently open in the GST & Tax modal (lineNo) or null
  gstLineNo: number | null

  // Selected grid row (lineNo) — drives F5 / GST cell open
  selectedLineNo: number | null

  // Loading flags
  loading: boolean
  saving:  boolean

  // Actions — mode & data
  setMode:        (mode: ScreenMode) => void
  setParameters:  (p: PoParameters) => void
  setCurrentPo:   (po: PoHeader | null) => void
  setDraftLines:  (lines: PoLine[]) => void
  addDraftLines:  (lines: PoLine[]) => void
  updateDraftLine:(lineNo: number, patch: Partial<PoLine>) => void
  removeDraftLine:(lineNo: number) => void

  // Actions — delivery schedule
  setDeliveryLines: (lines: DeliveryScheduleLine[]) => void
  addSlot:          (lineNo: number) => void
  updateSlot:       (lineNo: number, slotNo: number, patch: Partial<DeliverySlot>) => void
  removeSlot:       (lineNo: number, slotNo: number) => void

  // Actions — selection / modal / flags
  setSelectedLineNo: (lineNo: number | null) => void
  openGstModal:      (lineNo: number) => void
  closeGstModal:     () => void
  setLoading:        (v: boolean) => void
  setSaving:         (v: boolean) => void
  resetToView:       () => void
}

// Re-number slots 1..n after add/remove.
const reseq = (slots: DeliverySlot[]): DeliverySlot[] =>
  slots.map((s, i) => ({ ...s, slotNo: i + 1 }))

export const usePoTransferStore = create<PoTransferState>()((set) => ({
  mode:           'VIEW',
  parameters:     null,
  currentPo:      null,
  draftLines:     [],
  deliveryLines:  [],
  gstLineNo:      null,
  selectedLineNo: null,
  loading:        false,
  saving:         false,

  setMode:       (mode)  => set({ mode }),
  setParameters: (p)     => set({ parameters: p }),
  setCurrentPo:  (po)    => set({ currentPo: po }),
  setDraftLines: (lines) => set({ draftLines: lines }),

  addDraftLines: (lines) =>
    set((s) => {
      const start = s.draftLines.length
      const appended = lines.map((l, i) => ({ ...l, lineNo: start + i + 1 }))
      return { draftLines: [...s.draftLines, ...appended] }
    }),

  updateDraftLine: (lineNo, patch) =>
    set((s) => ({
      draftLines: s.draftLines.map((l) =>
        l.lineNo === lineNo ? { ...l, ...patch } : l,
      ),
    })),

  removeDraftLine: (lineNo) =>
    set((s) => ({
      draftLines: s.draftLines
        .filter((l) => l.lineNo !== lineNo)
        .map((l, i) => ({ ...l, lineNo: i + 1 })),
      // drop the matching delivery line; re-key the rest to the new lineNos
      deliveryLines: s.deliveryLines
        .filter((d) => d.lineNo !== lineNo)
        .map((d, i) => ({ ...d, lineNo: i + 1 })),
    })),

  setDeliveryLines: (lines) => set({ deliveryLines: lines }),

  addSlot: (lineNo) =>
    set((s) => ({
      deliveryLines: s.deliveryLines.map((d) => {
        if (d.lineNo !== lineNo) return d
        if (d.slots.length >= DS_MAX_SLOTS) return d   // Sprint 1 cap (Q3)
        const balance = d.poQty - d.slots.reduce((a, x) => a + (Number(x.qty) || 0), 0)
        const next: DeliverySlot = {
          slotNo:  d.slots.length + 1,
          shDate:  null,
          qty:     balance > 0 ? balance : 0,
          remarks: '',
        }
        return { ...d, slots: [...d.slots, next] }
      }),
    })),

  updateSlot: (lineNo, slotNo, patch) =>
    set((s) => ({
      deliveryLines: s.deliveryLines.map((d) =>
        d.lineNo === lineNo
          ? { ...d, slots: d.slots.map((sl) => (sl.slotNo === slotNo ? { ...sl, ...patch } : sl)) }
          : d,
      ),
    })),

  removeSlot: (lineNo, slotNo) =>
    set((s) => ({
      deliveryLines: s.deliveryLines.map((d) =>
        d.lineNo === lineNo && d.slots.length > 1
          ? { ...d, slots: reseq(d.slots.filter((sl) => sl.slotNo !== slotNo)) }
          : d,
      ),
    })),

  setSelectedLineNo: (lineNo) => set({ selectedLineNo: lineNo }),
  openGstModal:      (lineNo) => set({ gstLineNo: lineNo }),
  closeGstModal:     ()       => set({ gstLineNo: null }),
  setLoading:        (v)      => set({ loading: v }),
  setSaving:         (v)      => set({ saving: v }),

  resetToView: () =>
    set({
      mode:           'VIEW',
      draftLines:     [],
      deliveryLines:  [],
      gstLineNo:      null,
      selectedLineNo: null,
      saving:         false,
    }),
}))
