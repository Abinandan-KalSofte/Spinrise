import { create } from 'zustand'
import type {
  AmendScreenMode,
  AmendablePoSummary,
  AmendmentSummary,
  PoHeader,
  PoLine,
  DeliveryScheduleLine,
  DeliverySlot,
} from '../types'

// PO Amendment store (FN-PO-Amendment v1.2). Deliberately separate from
// usePoTransferStore — the Transfer screen is live on JAT and must not be
// destabilised — but it holds the SAME PoHeader / PoLine / DeliveryScheduleLine
// shapes, so the amendment screen reuses the Transfer grid/tab components and the
// one calc engine (poTransferRules) rather than forking them.
//
// The one thing this store has that Transfer's does not: `originalLines`. Change
// detection (FN §3.6 — Amendment Reason mandatory on ANY changed line) is a
// diff against the PO as it was loaded, so the pristine copy must be kept.

interface PoAmendmentState {
  mode: AmendScreenMode

  // The PO picked for amendment (picker row) and its loaded header.
  selectedPo: AmendablePoSummary | null
  currentPo:  PoHeader | null

  // The amendment row currently being viewed (Find Amendment, or the initial
  // auto-load of the latest amendment) — distinct from selectedPo, which
  // tracks a PO picked to actually AMEND. Kept separate so "which amendment
  // am I looking at" and "which PO am I editing" can never be conflated: a
  // view-only load never sets selectedPo's amendment fields (it has none —
  // AmendablePoSummary has no amdNo/amdDate), and starting a fresh amendment
  // via Select PO clears this rather than leaving a stale amendment reference.
  selectedAmendment: AmendmentSummary | null

  // Working lines + the pristine copy they are diffed against (§3.6).
  lines:         PoLine[]
  originalLines: PoLine[]

  deliveryLines: DeliveryScheduleLine[]

  selectedLineNo: number | null
  gstLineNo:      number | null

  loading: boolean
  saving:  boolean

  setMode:       (mode: AmendScreenMode) => void
  setSelectedPo: (po: AmendablePoSummary | null) => void
  setSelectedAmendment: (a: AmendmentSummary | null) => void

  // Loads a PO for amendment: seeds both the working lines and the pristine copy.
  loadPo: (po: PoHeader, lines: PoLine[], delivery: DeliveryScheduleLine[]) => void

  updateLine: (lineNo: number, patch: Partial<PoLine>) => void
  setLines:   (lines: PoLine[]) => void

  setDeliveryLines: (lines: DeliveryScheduleLine[]) => void
  addSlot:          (lineNo: number) => void
  updateSlot:       (lineNo: number, slotNo: number, patch: Partial<DeliverySlot>) => void
  removeSlot:       (lineNo: number, slotNo: number) => void

  setSelectedLineNo: (lineNo: number | null) => void
  openGstModal:      (lineNo: number) => void
  closeGstModal:     () => void
  setLoading:        (v: boolean) => void
  setSaving:         (v: boolean) => void
  reset:             () => void
}

const reseq = (slots: DeliverySlot[]): DeliverySlot[] =>
  slots.map((s, i) => ({ ...s, slotNo: i + 1 }))

export const usePoAmendmentStore = create<PoAmendmentState>()((set) => ({
  mode:              'VIEW',
  selectedPo:        null,
  selectedAmendment: null,
  currentPo:      null,
  lines:          [],
  originalLines:  [],
  deliveryLines:  [],
  selectedLineNo: null,
  gstLineNo:      null,
  loading:        false,
  saving:         false,

  setMode:       (mode) => set({ mode }),
  setSelectedPo: (po)   => set({ selectedPo: po }),
  setSelectedAmendment: (a) => set({ selectedAmendment: a }),

  loadPo: (po, lines, delivery) =>
    set({
      currentPo:     po,
      lines,
      // Deep-ish copy: the diff must survive in-place patches to `lines`.
      originalLines: lines.map((l) => ({ ...l })),
      deliveryLines: delivery,
      selectedLineNo: null,
      gstLineNo:      null,
    }),

  updateLine: (lineNo, patch) =>
    set((s) => ({
      lines: s.lines.map((l) => (l.lineNo === lineNo ? { ...l, ...patch } : l)),
    })),

  setLines: (lines) => set({ lines }),

  setDeliveryLines: (lines) => set({ deliveryLines: lines }),

  addSlot: (lineNo) =>
    set((s) => ({
      deliveryLines: s.deliveryLines.map((d) => {
        if (d.lineNo !== lineNo) return d
        const balance = d.poQty - d.slots.reduce((a, x) => a + (Number(x.qty) || 0), 0)
        const next: DeliverySlot = {
          slotNo: d.slots.length + 1,
          shDate: null,
          qty:    balance > 0 ? balance : 0,
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

  reset: () =>
    set({
      mode:              'VIEW',
      selectedPo:        null,
      selectedAmendment: null,
      currentPo:      null,
      lines:          [],
      originalLines:  [],
      deliveryLines:  [],
      selectedLineNo: null,
      gstLineNo:      null,
      saving:         false,
    }),
}))
