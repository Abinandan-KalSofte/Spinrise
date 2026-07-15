import { memo } from 'react'
import './loading.css'

interface Props {
  message?: string
}

function AppLoader({ message = 'Loading Spinrise ERP…' }: Props) {
  return (
    <div className="spr-app-loader">
      <div className="spr-app-loader__logo">
        <span className="spr-app-loader__brand">Spinrise</span>
        <span className="spr-app-loader__sub">Enterprise ERP</span>
      </div>

      <svg
        className="spr-app-loader__ring"
        viewBox="0 0 44 44"
        xmlns="http://www.w3.org/2000/svg"
      >
        <circle className="track" cx="22" cy="22" r="18" />
        <circle cx="22" cy="22" r="18" strokeDasharray="113" />
      </svg>

      <span className="spr-app-loader__text">{message}</span>
    </div>
  )
}

export default memo(AppLoader)
