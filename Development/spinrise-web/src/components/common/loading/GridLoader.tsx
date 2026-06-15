import { memo } from 'react'
import './loading.css'

interface ColDef {
  size?: 'sm' | 'lg' | 'num' | 'default'
}

interface Props {
  rows?: number
  cols?: ColDef[]
}

const DEFAULT_COLS: ColDef[] = [
  { size: 'sm' },
  { size: 'lg' },
  { size: 'default' },
  { size: 'num' },
  { size: 'num' },
]

function GridLoader({ rows = 7, cols = DEFAULT_COLS }: Props) {
  const cellClass = (size: ColDef['size'] = 'default') =>
    `spr-grid-loader__cell${size !== 'default' ? ` spr-grid-loader__cell--${size}` : ''}`

  return (
    <div className="spr-grid-loader">
      <div className="spr-grid-loader__header">
        {cols.map((c, i) => (
          <div key={i} className={cellClass(c.size)} style={{ height: 12 }} />
        ))}
      </div>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="spr-grid-loader__row">
          {cols.map((c, j) => (
            <div key={j} className={cellClass(c.size)} />
          ))}
        </div>
      ))}
    </div>
  )
}

export default memo(GridLoader)
