import { memo } from 'react'
import './loading.css'

interface Props {
  visible: boolean
  message?: string
  fixed?: boolean
}

function LoadingOverlay({ visible, message = 'Processing…', fixed = false }: Props) {
  if (!visible) return null
  return (
    <div className={`spr-overlay${fixed ? ' spr-overlay--fixed' : ''}`}>
      <div className="spr-overlay__ring" />
      {message && <span className="spr-overlay__text">{message}</span>}
    </div>
  )
}

export default memo(LoadingOverlay)
