import { memo } from 'react'
import './loading.css'

interface Props {
  rows?: number
  cols?: number
}

function FormLoader({ rows = 2, cols = 4 }: Props) {
  return (
    <div className="spr-form-loader">
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="spr-form-loader__row">
          {Array.from({ length: cols }).map((__, c) => (
            <div key={c} className="spr-form-loader__field">
              <div className="spr-form-loader__label" />
              <div className="spr-form-loader__input" />
            </div>
          ))}
        </div>
      ))}
    </div>
  )
}

export default memo(FormLoader)
