import { memo } from 'react'
import './loading.css'

interface Props {
  message?: string
}

function ApiLoader({ message = 'Loading…' }: Props) {
  return (
    <div className="spr-api-loader">
      <div className="spr-api-loader__ring" />
      <span className="spr-api-loader__text">{message}</span>
    </div>
  )
}

export default memo(ApiLoader)
