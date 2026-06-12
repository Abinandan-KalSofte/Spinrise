import { setupWorker } from 'msw/browser'
import { demoAuthHandlers } from './authHandlers'
import { poHandlers } from './poHandlers'

// ── Runtime mock worker (browser) ────────────────────────────────────────────
// Started from main.tsx only when VITE_ENABLE_MOCKS === 'true'. Unhandled
// requests bypass to the real backend, so enabling this mocks ONLY the PO module
// (+ demo auth) and leaves every other endpoint untouched.
// TODO: Replace with actual backend API when available — then set VITE_ENABLE_MOCKS=false.
export const worker = setupWorker(...demoAuthHandlers, ...poHandlers)
