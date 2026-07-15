import { useEffect, useState } from 'react'
import { Modal } from 'antd'

interface Props {
  /** Wall-clock time (ms since epoch) at which the user will be signed out. */
  deadlineMs: number
  /** User chose to continue — restart the idle clock. */
  onStay: () => void
  /** Deadline reached, or the user chose to sign out now. */
  onSignOut: () => void
}

function secondsLeft(deadlineMs: number): number {
  return Math.max(0, Math.ceil((deadlineMs - Date.now()) / 1000))
}

function formatRemaining(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60)
  const s = totalSeconds % 60
  return `${m}:${s.toString().padStart(2, '0')}`
}

/**
 * Warns before the idle timeout signs the user out, so unsaved entry work is not lost silently.
 * The countdown is honest — when it reaches zero, `onSignOut` fires.
 *
 * Counts down against a wall-clock deadline rather than decrementing a counter: browsers throttle
 * timers in background tabs, so a decrementing counter would drift and under-report the time left.
 *
 * Mounted fresh per warning (keyed on the deadline in AppShell), so the initial value comes from
 * the state initialiser and never from a setState inside an effect.
 */
export default function IdleWarningModal({ deadlineMs, onStay, onSignOut }: Props) {
  const [remaining, setRemaining] = useState(() => secondsLeft(deadlineMs))

  useEffect(() => {
    const id = setInterval(() => {
      const left = secondsLeft(deadlineMs)
      setRemaining(left)
      if (left <= 0) {
        clearInterval(id)
        onSignOut()
      }
    }, 1000)

    return () => clearInterval(id)
  }, [deadlineMs, onSignOut])

  return (
    <Modal
      open
      title="Still There?"
      onOk={onStay}
      okText="Stay Signed In"
      onCancel={onSignOut}
      cancelText="Sign Out Now"
      closable={false}
      maskClosable={false}
      centered
    >
      <p>
        You have been inactive and will be signed out in{' '}
        <strong>{formatRemaining(remaining)}</strong>.
      </p>
      <p style={{ marginBottom: 0 }}>Any unsaved work on this screen will be lost.</p>
    </Modal>
  )
}
