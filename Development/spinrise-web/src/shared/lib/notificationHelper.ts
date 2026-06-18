import { useEffect } from 'react'
import { App, notification as staticNotification } from 'antd'
import type { NotificationInstance } from 'antd/es/notification/interface'

// ── Centralized Ant Design Notification helper ───────────────────────────────
// The ONE notification path for the whole app. Usable from anywhere — components,
// hooks AND plain modules / Zustand stores — because it renders through the
// context-aware AntD <App> notification instance bound once by <NotificationBridge/>
// (see main.tsx), falling back to the static API before the bridge mounts.
//
// Usage:
//   notifySuccess('Purchase Order PO-000139 created.')
//   notifyError(err.message)
//   notifyWarning('Please fill in all required fields.')
//   notifyInfo('No records found.')

type NotifyType = 'success' | 'error' | 'warning' | 'info'

let boundApi: NotificationInstance | null = null

// Per-type auto-close duration (seconds). Errors/warnings linger a little longer.
const DURATION: Record<NotifyType, number> = {
  success: 3,
  info:    3,
  warning: 4.5,
  error:   5,
}

/**
 * Mount ONCE inside AntD's <App> (see main.tsx). Binds the context-aware
 * notification instance so notifications render with the app theme at top-right.
 */
export function NotificationBridge() {
  const { notification } = App.useApp()
  useEffect(() => {
    boundApi = notification
    return () => { boundApi = null }
  }, [notification])
  return null
}

function notify(type: NotifyType, message: string, description?: string) {
  const api = boundApi ?? staticNotification
  api[type]({
    title:        message,
    description,
    placement:    'topRight',
    duration:     DURATION[type],
    showProgress: true,
    className:    `${type}-notification`,
    style:        { width: 380 },
  })
}

export const notifySuccess = (description: string, message = 'Success') =>
  notify('success', message, description)

export const notifyError = (description: string, message = 'Error') =>
  notify('error', message, description)

export const notifyWarning = (description: string, message = 'Warning') =>
  notify('warning', message, description)

export const notifyInfo = (description: string, message = 'Information') =>
  notify('info', message, description)
