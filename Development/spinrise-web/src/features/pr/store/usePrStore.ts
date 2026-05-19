import { create } from 'zustand'
import type { PrHeader, PrLine, PrParameters, ScreenMode } from '../types'

interface PrState {
  // Screen mode
  mode: ScreenMode

  // Parameters (loaded once on screen open)
  parameters: PrParameters | null

  // Currently displayed PR
  currentPr: PrHeader | null

  // Working lines (for Add / Edit)
  draftLines: PrLine[]

  // Loading flags
  loading: boolean
  saving:  boolean

  // Actions
  setMode:        (mode: ScreenMode) => void
  setParameters:  (p: PrParameters) => void
  setCurrentPr:   (pr: PrHeader | null) => void
  setDraftLines:  (lines: PrLine[]) => void
  addDraftLine:   (line: PrLine) => void
  updateDraftLine:(index: number, line: Partial<PrLine>) => void
  removeDraftLine:(index: number) => void
  setLoading:     (v: boolean) => void
  setSaving:      (v: boolean) => void
  resetToView:    () => void
}

export const usePrStore = create<PrState>()((set) => ({
  mode:        'VIEW',
  parameters:  null,
  currentPr:   null,
  draftLines:  [],
  loading:     false,
  saving:      false,

  setMode:       (mode)   => set({ mode }),
  setParameters: (p)      => set({ parameters: p }),
  setCurrentPr:  (pr)     => set({ currentPr: pr }),
  setDraftLines: (lines)  => set({ draftLines: lines }),

  addDraftLine: (line) =>
    set((s) => ({ draftLines: [...s.draftLines, line] })),

  updateDraftLine: (index, partial) =>
    set((s) => ({
      draftLines: s.draftLines.map((l, i) =>
        i === index ? { ...l, ...partial } : l
      ),
    })),

  removeDraftLine: (index) =>
    set((s) => ({
      draftLines: s.draftLines
        .filter((_, i) => i !== index)
        .map((l, i) => ({ ...l, prSno: i + 1 })),
    })),

  setLoading: (v) => set({ loading: v }),
  setSaving:  (v) => set({ saving: v }),

  resetToView: () =>
    set({ mode: 'VIEW', draftLines: [], saving: false }),
}))
