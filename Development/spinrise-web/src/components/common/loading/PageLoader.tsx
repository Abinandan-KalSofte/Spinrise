import { memo } from 'react'
import './loading.css'

interface Props {
  toolbarButtons?: number
  formRows?: number
  gridRows?: number
}

function PageLoader({ toolbarButtons = 6, formRows = 2, gridRows = 6 }: Props) {
  return (
    <div className="spr-page-loader">
      {/* Doc band */}
      <div className="spr-page-loader__header">
        <div className="spr-skel spr-skel--text" style={{ width: 120 }} />
        <div className="spr-skel spr-skel--text" style={{ width: 80, marginLeft: 'auto' }} />
      </div>

      {/* Toolbar */}
      <div className="spr-page-loader__toolbar">
        {Array.from({ length: toolbarButtons }).map((_, i) => (
          <div key={i} className="spr-skel spr-skel--btn" style={{ width: 64 }} />
        ))}
      </div>

      {/* Body */}
      <div className="spr-page-loader__body">
        {/* Form skeleton */}
        <div style={{ background: '#fff', borderRadius: 6, padding: '16px 16px 12px', border: '1px solid #E2E2E2' }}>
          <div className="spr-form-loader">
            {Array.from({ length: formRows }).map((_, r) => (
              <div key={r} className="spr-form-loader__row">
                {Array.from({ length: 4 }).map((__, c) => (
                  <div key={c} className="spr-form-loader__field">
                    <div className="spr-form-loader__label" />
                    <div className="spr-form-loader__input" />
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>

        {/* Grid skeleton */}
        <div className="spr-grid-loader" style={{ flex: 1 }}>
          <div className="spr-grid-loader__header">
            <div className="spr-skel spr-skel--text spr-grid-loader__cell--sm" style={{ height: 12 }} />
            <div className="spr-skel spr-skel--text spr-grid-loader__cell--lg" style={{ height: 12 }} />
            <div className="spr-skel spr-skel--text" style={{ height: 12, flex: 1 }} />
            <div className="spr-skel spr-skel--text spr-grid-loader__cell--num" style={{ height: 12 }} />
            <div className="spr-skel spr-skel--text spr-grid-loader__cell--num" style={{ height: 12 }} />
          </div>
          {Array.from({ length: gridRows }).map((_, i) => (
            <div key={i} className="spr-grid-loader__row">
              <div className="spr-grid-loader__cell spr-grid-loader__cell--sm" />
              <div className="spr-grid-loader__cell spr-grid-loader__cell--lg" />
              <div className="spr-grid-loader__cell" />
              <div className="spr-grid-loader__cell spr-grid-loader__cell--num" />
              <div className="spr-grid-loader__cell spr-grid-loader__cell--num" />
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default memo(PageLoader)
