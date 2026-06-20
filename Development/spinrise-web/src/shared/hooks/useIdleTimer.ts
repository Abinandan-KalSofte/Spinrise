import { useEffect, useRef } from 'react'

const IDLE_EVENTS = ['mousemove', 'mousedown', 'keypress', 'touchstart', 'scroll', 'click'] as const
const IDLE_TIMEOUT_MS = 30 * 60 * 1000 // 30 minutes

export function useIdleTimer(onIdle: () => void, enabled: boolean): void {
  const timerRef  = useRef<ReturnType<typeof setTimeout> | null>(null)
  const onIdleRef = useRef(onIdle)

  // Keep ref current without triggering re-effects
  useEffect(() => { onIdleRef.current = onIdle })

  useEffect(() => {
    if (!enabled) {
      if (timerRef.current) clearTimeout(timerRef.current)
      return
    }

    const reset = () => {
      if (timerRef.current) clearTimeout(timerRef.current)
      timerRef.current = setTimeout(() => onIdleRef.current(), IDLE_TIMEOUT_MS)
    }

    IDLE_EVENTS.forEach(e => window.addEventListener(e, reset, { passive: true }))
    reset() // start timer immediately on mount

    return () => {
      IDLE_EVENTS.forEach(e => window.removeEventListener(e, reset))
      if (timerRef.current) clearTimeout(timerRef.current)
    }
  }, [enabled]) // re-register only when enabled toggles
}
