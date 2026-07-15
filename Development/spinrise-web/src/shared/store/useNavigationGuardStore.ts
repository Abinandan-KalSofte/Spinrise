import { create } from 'zustand'

// Lightweight navigation-guard registry.
// Pages that have unsaved changes set isDirty = true and provide a
// onConfirmDiscard callback (e.g. cancelMode). AppShell reads this
// before any menu-item or brand-logo navigation and shows a confirm
// dialog when the guard is active.
interface NavigationGuardState {
  isDirty:          boolean
  onConfirmDiscard: (() => void) | null
  setGuard:  (dirty: boolean, onConfirmDiscard?: (() => void) | null) => void
  clearGuard: () => void
}

export const useNavigationGuardStore = create<NavigationGuardState>()((set) => ({
  isDirty:          false,
  onConfirmDiscard: null,
  setGuard:  (dirty, onConfirmDiscard = null) => set({ isDirty: dirty, onConfirmDiscard }),
  clearGuard: () => set({ isDirty: false, onConfirmDiscard: null }),
}))
