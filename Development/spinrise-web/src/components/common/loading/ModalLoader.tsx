import { memo } from 'react'
import './loading.css'

interface Props {
  message?: string
  rows?: number
}

function ModalLoader({ message = 'Loading…', rows = 4 }: Props) {
  return (
    <div style={{ padding: '8px 0' }}>
      <div className="spr-modal-loader">
        <div className="spr-modal-loader__ring" />
        {message && <span className="spr-modal-loader__text">{message}</span>}
      </div>
      <div className="spr-form-loader" style={{ padding: '0 4px' }}>
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i} className="spr-form-loader__field">
            <div className="spr-form-loader__label" style={{ width: '40%' }} />
            <div className="spr-form-loader__input" />
          </div>
        ))}
      </div>
    </div>
  )
}

export default memo(ModalLoader)
