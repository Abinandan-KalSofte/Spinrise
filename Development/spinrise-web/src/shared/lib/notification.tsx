import { useEffect } from 'react'
import { App, notification as staticNotification } from 'antd'
import type { NotificationInstance } from 'antd/es/notification/interface'

// ── Centralized notification service ─────────────────────────────────────────
// Single, theme-aware notification API usable from ANYWHERE (components, hooks,
// plain modules) — not just inside React render. AntD's <App> already renders a
// notification holder; <NotificationBridge/> grabs that context-aware instance
// once and stores it here so `notificationService.*` can be called as a plain
// function. Falls back to the static API if called before the bridge mounts.
//
// Usage:
//   notificationService.success('Purchase Order Saved', 'PO-000139 created.')
//   notificationService.error('Failed to Save Purchase Order', err.message)

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
 * notification instance so the service renders with the app theme + at top-right.
 */
export function NotificationBridge() {
  const { notification } = App.useApp()
  useEffect(() => {
    boundApi = notification
    return () => { boundApi = null }
  }, [notification])
  return null
}

function notify(type: NotifyType, title: string, description?: string) {
  const api = boundApi ?? staticNotification
  api[type]({
    message:     title,
    description,
    placement:   'topRight',
    duration:    DURATION[type],
    showProgress: true,
  })
}

export const notificationService = {
  success: (title: string, description?: string) => notify('success', title, description),
  error:   (title: string, description?: string) => notify('error',   title, description),
  warning: (title: string, description?: string) => notify('warning', title, description),
  info:    (title: string, description?: string) => notify('info',    title, description),
}
