import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import type { AuthTokens, AuthUser, UserRole } from '../types'

interface AuthState {
  user:             AuthUser | null
  tokens:           AuthTokens | null
  isAuthenticated:  boolean
  processingDate:   string | null
  setAuthSession:   (payload: { user: AuthUser; tokens: AuthTokens }) => void
  setProcessingDate:(date: string) => void
  clearAuthSession: () => void
  hasRole:          (role: UserRole) => boolean
}

export const useAuthStore = create<AuthState>()(
  devtools(
    persist(
      (set, get) => ({
        user:            null,
        tokens:          null,
        isAuthenticated: false,
        processingDate:  null,

        setAuthSession: ({ user, tokens }) =>
          set({ user, tokens, isAuthenticated: true }, false, 'auth/setAuthSession'),

        setProcessingDate: (date) =>
          set({ processingDate: date }, false, 'auth/setProcessingDate'),

        clearAuthSession: () =>
          set(
            { user: null, tokens: null, isAuthenticated: false, processingDate: null },
            false,
            'auth/clearAuthSession',
          ),

        hasRole: (role) => get().user?.role === role,
      }),
      {
        name: 'spinrise-auth-v2',
        partialize: (state) => ({
          user:            state.user,
          tokens:          state.tokens,
          isAuthenticated: state.isAuthenticated,
          processingDate:  state.processingDate,
        }),
      },
    ),
    { name: 'SpinriseAuthStore' },
  ),
)
