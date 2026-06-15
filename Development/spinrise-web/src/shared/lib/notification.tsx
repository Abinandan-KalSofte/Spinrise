// ── notificationService — compatibility shim ─────────────────────────────────
// Thin wrapper that delegates to the centralized notificationHelper so the app
// has a SINGLE Ant Design Notification path. notificationService keeps the
// (title, description) call signature used by the PO module; new code should
// import { notifySuccess, notifyError, notifyWarning, notifyInfo } from
// './notificationHelper' directly.

import { notifySuccess, notifyError, notifyWarning, notifyInfo } from './notificationHelper'

export { NotificationBridge } from './notificationHelper'

export const notificationService = {
  success: (title: string, description = '') => notifySuccess(description, title),
  error:   (title: string, description = '') => notifyError(description, title),
  warning: (title: string, description = '') => notifyWarning(description, title),
  info:    (title: string, description = '') => notifyInfo(description, title),
}
