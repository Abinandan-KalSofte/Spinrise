import type { AmendmentHeader } from '../../types'
import type { AmendMode } from '../../hooks/usePrAmendmentForm'

// ── Style helpers ─────────────────────────────────────────────────────────────
function fldCtrl(disabled: boolean, extra?: React.CSSProperties): React.CSSProperties {
  return {
    height: 30, border: '1px solid #e2e2e2', borderRadius: 4, padding: '0 8px',
    fontSize: 12, fontFamily: 'inherit',
    color: disabled ? '#4A4A4A' : '#1A1A1A',
    background: disabled ? '#F5F5F3' : '#fff',
    width: '100%', outline: 'none', boxSizing: 'border-box',
    ...extra,
  }
}

const LBL: React.CSSProperties = {
  fontSize: 11, fontWeight: 500, color: '#888888', lineHeight: 1,
}

// ── Field group wrapper ───────────────────────────────────────────────────────
function Fg({
  width, flex, xl, children,
}: {
  width?: number; flex?: boolean; xl?: boolean; children: React.ReactNode
}) {
  const style: React.CSSProperties = flex
    ? (xl
        ? { flex: '2 1 260px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 }
        : { flex: '1 1 190px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: 3 })
    : { flex: `0 0 ${width}px`, display: 'flex', flexDirection: 'column', gap: 3 }
  return <div style={style}>{children}</div>
}

function Lbl({ text, required }: { text: string; required?: boolean }) {
  return (
    <span style={LBL}>
      {text}
      {required && <span style={{ color: '#A32D2D', marginLeft: 1 }}>*</span>}
    </span>
  )
}

// ── Props ─────────────────────────────────────────────────────────────────────
interface Props {
  header:              AmendmentHeader | null
  mode:                AmendMode
  refNo:               string
  amendReason:         string
  reasonError:         boolean
  processingDate:      string | null
  onRefNoChange:       (v: string) => void
  onAmendReasonChange: (v: string) => void
  onFindPR:            () => void
}

export function PrAmendmentHeader({
  header, mode, refNo, amendReason, reasonError, processingDate,
  onRefNoChange, onAmendReasonChange, onFindPR,
}: Props) {
  const canEdit = mode === 'new' || mode === 'modify'

  // "28 May 2026" format for the date pill
  const todayDisplay = (() => {
    const d = processingDate ? new Date(processingDate) : new Date()
    return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  })()

  const amendNoDisplay  = header ? `AMD-${String(header.amendNo).padStart(4, '0')}` : ''
  const amendDateDisplay = header?.amendDate || ''
  const deptDisplay      = header ? `${header.depCode} – ${header.depName}` : ''
  const reqDisplay       = header ? (header.reqEmpName || header.reqName) : ''
  const createdByLabel   = header?.createdBy || '—'

  const findBtnStyle: React.CSSProperties = {
    height: 30, padding: '0 10px', border: '1px solid #e2e2e2', borderRadius: 4,
    background: '#fff', color: '#185FA5', fontSize: 11, fontWeight: 700,
    cursor: mode === 'new' ? 'pointer' : 'not-allowed',
    opacity: mode === 'new' ? 1 : 0.38,
    whiteSpace: 'nowrap', fontFamily: 'inherit', flexShrink: 0,
  }

  return (
    <div style={{ background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>

      {/* Section header */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '9px 16px', borderBottom: '1px solid #e2e2e2',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 14 }}>📅</span>
          <span style={{ fontSize: 13, fontWeight: 600, color: '#1A1A1A' }}>Amendment Details</span>
          <span style={{
            background: '#E6F1FB', color: '#185FA5', fontSize: 11, fontWeight: 600,
            padding: '2px 9px', borderRadius: 20,
          }}>
            {todayDisplay}
          </span>
        </div>
        <span style={{ fontSize: 11, color: '#888' }}>
          Created by <strong style={{ color: '#4A4A4A' }}>{createdByLabel}</strong>
        </span>
      </div>

      {/* Fields */}
      <div style={{ padding: '12px 16px 8px' }}>

        {/* Row 1: Amendment No | Amendment Date | PR No (Find) | PR Date */}
        <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', marginBottom: 8 }}>
          <Fg width={128}>
            <Lbl text="Amendment No." />
            <input
              style={fldCtrl(true, { fontFamily: 'monospace', fontWeight: 600 })}
              value={amendNoDisplay}
              disabled
              placeholder="Auto-generated"
              readOnly
            />
          </Fg>
          <Fg width={148}>
            <Lbl text="Amendment Date" />
            <input style={fldCtrl(true)} value={amendDateDisplay} disabled readOnly placeholder="—" />
          </Fg>
          <Fg width={175}>
            <Lbl text="PR No." required />
            <div style={{ display: 'flex', gap: 3 }}>
              <input
                style={fldCtrl(true, {
                  flex: 1,
                  color: header?.prNo ? '#185FA5' : undefined,
                  fontFamily: 'monospace', fontWeight: 600,
                })}
                value={header?.prNo ? String(header.prNo) : ''}
                disabled
                readOnly
                placeholder="PR number"
              />
              <button style={findBtnStyle} disabled={mode !== 'new'} onClick={onFindPR}>
                Find
              </button>
            </div>
          </Fg>
          <Fg width={148}>
            <Lbl text="PR Date" />
            <input style={fldCtrl(true)} value={header?.prDate || ''} disabled readOnly placeholder="—" />
          </Fg>
        </div>

        {/* Row 2: Department | PR Type | Requester Name | Section */}
        <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', marginBottom: 8 }}>
          <Fg flex>
            <Lbl text="Department" />
            <input style={fldCtrl(true)} value={deptDisplay} disabled readOnly placeholder="—" />
          </Fg>
          <Fg width={128}>
            <Lbl text="PR Type" />
            <input
              style={fldCtrl(true)}
              value={header?.iDesc || header?.iType || ''}
              disabled readOnly placeholder="—"
            />
          </Fg>
          <Fg flex>
            <Lbl text="Requester Name" />
            <input style={fldCtrl(true)} value={reqDisplay} disabled readOnly placeholder="—" />
          </Fg>
          <Fg width={148}>
            <Lbl text="Section" />
            <input style={fldCtrl(true)} value={header?.section || ''} disabled readOnly placeholder="—" />
          </Fg>
        </div>

        {/* Row 3: Reference No | Amendment Reason */}
        <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
          <Fg width={148}>
            <Lbl text="Reference No." />
            <input
              style={fldCtrl(!canEdit)}
              value={refNo}
              disabled={!canEdit}
              maxLength={30}
              placeholder="Optional"
              onChange={(e) => onRefNoChange(e.target.value)}
            />
          </Fg>
          <Fg flex xl>
            <Lbl text="Amendment Reason" required />
            <input
              style={fldCtrl(!canEdit, reasonError ? { borderColor: '#A32D2D' } : {})}
              value={amendReason}
              disabled={!canEdit}
              maxLength={200}
              placeholder="Enter amendment reason…"
              onChange={(e) => onAmendReasonChange(e.target.value)}
            />
          </Fg>
        </div>

        <div style={{ fontSize: 10, color: '#888', marginTop: 4 }}>
          <span style={{ marginRight: 12 }}>Tab — move between fields</span>
          <span>Ctrl+S — save</span>
        </div>
      </div>
    </div>
  )
}
