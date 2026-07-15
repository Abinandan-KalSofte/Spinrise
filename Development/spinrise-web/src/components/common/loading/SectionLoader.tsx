import { memo } from 'react'
import './loading.css'

interface Props {
  message?: string
  height?: number | string
}

function SectionLoader({ message = 'Loading…', height }: Props) {
  return (
    <div
      className="spr-section-loader"
      style={height !== undefined ? { height, flex: 'none' } : undefined}
    >
      <div className="spr-section-loader__ring" />
      {message && <span className="spr-section-loader__text">{message}</span>}
    </div>
  )
}

export default memo(SectionLoader)
