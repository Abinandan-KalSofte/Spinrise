// Shared toolbar primitives — identical to existing Spinrise design

const C = {
  blue:   '#185FA5',
  red:    '#A32D2D',
  border: '#d0d0d0',
  bg:     '#f5f5f3',
  text:   '#1a1a1a',
  text3:  '#888',
} as const

// ── Toolbar button ─────────────────────────────────────────────────────────────

interface TbBtnProps {
  icon:      React.ReactNode
  label?:    string
  kbd?:      string
  onClick?:  () => void
  disabled?: boolean
  variant?:  'default' | 'primary' | 'success' | 'danger' | 'danger-filled' | 'icon'
  title?:    string
}

export function TbBtn({
  icon, label, kbd, onClick, disabled = false, variant = 'default', title,
}: TbBtnProps) {
  const base: React.CSSProperties = {
    display: 'inline-flex', alignItems: 'center', gap: 5,
    padding: variant === 'icon' ? '5px 8px' : '5px 11px',
    border: `1px solid ${C.border}`, borderRadius: 6,
    background: '#fff', fontSize: 12, fontWeight: 500,
    cursor: disabled ? 'not-allowed' : 'pointer',
    color: C.text, opacity: disabled ? 0.35 : 1,
    fontFamily: 'inherit', whiteSpace: 'nowrap',
    transition: 'background 0.12s, opacity 0.12s',
  }
  const variants: Partial<Record<string, React.CSSProperties>> = {
    primary:          { background: C.blue,    color: '#fff', borderColor: C.blue    },
    success:          { background: '#185FA5', color: '#fff', borderColor: '#185FA5' },
    danger:           { color: C.red, borderColor: '#E24B4A', background: '#fff'     },
    'danger-filled':  { background: '#dc2626', color: '#fff', borderColor: '#dc2626' },
  }
  return (
    <button
      style={{ ...base, ...(variants[variant] ?? {}) }}
      onClick={!disabled ? onClick : undefined}
      disabled={disabled}
      title={title}
    >
      {icon}
      {label && <span>{label}</span>}
      {kbd && (
        <span style={{
          fontSize: 10, padding: '1px 4px',
          border: `1px solid ${C.border}`, borderRadius: 3,
          color: C.text3, background: C.bg, fontFamily: 'monospace', marginLeft: 2,
        }}>
          {kbd}
        </span>
      )}
    </button>
  )
}

export function TbSep() {
  return (
    <div style={{
      width: 1, height: 22, background: C.border,
      margin: '0 3px', flexShrink: 0,
    }} />
  )
}

// ── Document header band ───────────────────────────────────────────────────────

interface PRDocBandProps {
  savedPrNo: number | null
  prStatus:  string | null
}

export function PRDocBand({ savedPrNo, prStatus: _prStatus }: PRDocBandProps) {
  return (
    <div style={{
      background: 'linear-gradient(135deg, #0C447C 0%, #185FA5 100%)',
      padding: '8px 18px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      flexShrink: 0,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        <div>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,.6)', marginBottom: 1 }}>Document</div>
          <div style={{ fontSize: 12, fontWeight: 700, color: '#fff', letterSpacing: '.3px' }}>
            Purchase Requisition
          </div>
        </div>
        <div>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,.6)', marginBottom: 1 }}>PR Number</div>
          <div style={{ fontSize: 13, fontWeight: 700, color: '#fff', fontFamily: 'monospace' }}>
            {savedPrNo ? `PR-${String(savedPrNo).padStart(5, '0')}` : 'Auto-generated on save'}
          </div>
        </div>
      </div>
    </div>
  )
}
