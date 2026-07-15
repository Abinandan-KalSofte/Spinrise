import { useEffect, useRef } from 'react'

const IDLE_EVENTS = ['mousemove', 'mousedown', 'keypress', 'touchstart', 'scroll', 'click'] as const

interface IdleTimerOptions {
  /** Minutes of inactivity before `onIdle` fires. */
  idleMinutes: number
  /** How many minutes before the cut-off `onWarn` fires. */
  warningMinutes: number
  /** Called once when the warning window opens. Show the countdown modal here. */
  onWarn: () => void
  /** Called at the cut-off. Sign the user out here. */
  onIdle: () => void
  enabled: boolean
}

/**
 * Two-stage idle timer.
 *
 * The previous version fired straight to logout with no warning, which meant an unattended entry
 * screen could discard work with no chance to save. Users respond to that by defeating the timeout
 * (keeping a tab active), so a warning is not a nicety — it is what makes the control survive
 * contact with the shop floor.
 *
 * Both thresholds come from the server's session policy, not from a constant in this file.
 *
 * Note: activity during the warning window does NOT silently cancel it. Once warned, the user must
 * make an explicit choice — otherwise a passing mouse-move would extend a session nobody is at.
 */
export function useIdleTimer({
  idleMinutes,
  warningMinutes,
  onWarn,
  onIdle,
  enabled,
}: IdleTimerOptions): { reset: () => void } {
  const warnTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const idleTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const warnedRef    = useRef(false)

  const onWarnRef = useRef(onWarn)
  const onIdleRef = useRef(onIdle)
  const resetRef  = useRef<() => void>(() => {})

  // Keep callbacks current without re-registering the listeners on every render
  useEffect(() => {
    onWarnRef.current = onWarn
    onIdleRef.current = onIdle
  })

  useEffect(() => {
    const clear = () => {
      if (warnTimerRef.current) clearTimeout(warnTimerRef.current)
      if (idleTimerRef.current) clearTimeout(idleTimerRef.current)
    }

    if (!enabled) {
      clear()
      warnedRef.current = false
      return
    }

    const idleMs = Math.max(idleMinutes, 1) * 60 * 1000
    // Guard the arithmetic: a warning window >= the idle window would schedule the warning at or
    // before t=0 and fire it immediately on every reset.
    const warnMs = Math.min(Math.max(warningMinutes, 0), Math.max(idleMinutes - 1, 0)) * 60 * 1000

    const start = () => {
      clear()
      warnedRef.current = false

      if (warnMs > 0) {
        warnTimerRef.current = setTimeout(() => {
          warnedRef.current = true
          onWarnRef.current()
        }, idleMs - warnMs)
      }

      idleTimerRef.current = setTimeout(() => onIdleRef.current(), idleMs)
    }

    resetRef.current = start

    const onActivity = () => {
      // Already warned — the modal owns the decision now. Ignore incidental activity.
      if (warnedRef.current) return
      start()
    }

    IDLE_EVENTS.forEach(e => window.addEventListener(e, onActivity, { passive: true }))
    start()

    return () => {
      IDLE_EVENTS.forEach(e => window.removeEventListener(e, onActivity))
      clear()
    }
  }, [enabled, idleMinutes, warningMinutes])

  // Lets the warning modal's "Stay Signed In" restart the clock explicitly.
  return { reset: () => resetRef.current() }
}
