
import type { PrForCancellationDetail } from '../../types'

interface Props {
  detail:          PrForCancellationDetail | null
  cancelReason:    string
  cancelReasonErr: string | null
  onReasonChange:  (v: string) => void
}

export default function CancelSubTab({ detail, cancelReason, cancelReasonErr, onReasonChange }: Props) {
  if (!detail) {
    return (
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8, color: '#888', padding: 40 }}>
        <span style={{ fontSize: 40 }}>🔍</span>
        <span style={{ fontSize: 13, fontWeight: 600 }}>No PR selected for cancellation</span>
        <span style={{ fontSize: 11, textAlign: 'center', maxWidth: 300, lineHeight: 1.6 }}>
          Click <strong>Find PR</strong> <kbd style={{ fontSize: 10, padding: '1px 4px', border: '1px solid #d0d0d0', borderRadius: 3 }}>F3</kbd> in the toolbar to select a PR eligible for cancellation.
        </span>
      </div>
    )
  }

  const { header, lines } = detail
  const prTag = `PR-${String(header.prNo).padStart(5, '0')}`

  const totalCost = lines.reduce((s, l) => s + (l.approxCost ?? 0), 0)
  const totalQty  = lines.reduce((s, l) => s + (l.qtyApproved ?? 0), 0)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0, overflow: 'hidden' }}>

      {/* Cancel mode banner */}
      <div style={{ background: '#FCEBEB', borderBottom: '1px solid #fca5a5', padding: '6px 16px', color: '#A32D2D', fontWeight: 500, fontSize: 12, flexShrink: 0 }}>
        Cancel mode — <strong style={{ fontFamily: 'monospace' }}>{prTag}</strong>
        {' '}· Enter a cancellation reason and click <strong>Cancel PR</strong> to proceed.
       
      </div>

      {/* PR Header view */}
      <div style={{ background: '#fff', borderBottom: '1px solid #e2e2e2', padding: '8px 18px 10px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 10, fontWeight: 700, color: '#185FA5', letterSpacing: '.06em' }}>REQUISITION DETAILS</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: 'linear-gradient(135deg,#eff6ff,#dbeafe)', border: '1px solid #bfdbfe', borderRadius: 20, padding: '1px 8px' }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: '#1e40af' }}>📅 {header.prDate}</span>
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 11, color: '#94A3B8' }}>Created by <strong style={{ color: '#475569' }}>{header.createdBy}</strong></span>
            <span style={{ fontSize: 12, fontWeight: 700, fontFamily: 'monospace', padding: '2px 10px', borderRadius: 4, background: '#e6f4ff', color: '#0958d9', border: '1px solid #91caff' }}>
              {prTag}
            </span>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '3fr 5fr 4fr 5fr 4fr 3fr', gap: '6px 10px' }}>
          {[
            { label: 'PR Date',          value: header.prDate },
            { label: 'Department',        value: header.department },
            { label: 'Section',           value: header.section || '—' },
            { label: 'Requested By',      value: header.requestedBy || '—' },
            { label: 'Requisition Type',  value: header.prType || '—' },
            { label: 'Reference No.',     value: header.refNo || '—' },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, fontWeight: 600, color: '#475569', marginBottom: 2 }}>{label}</div>
              <div style={{ fontSize: 12, color: '#1e293b', fontWeight: 500 }}>{value}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Reason strip */}
      <div style={{ background: '#fff', borderBottom: '1px solid #E2E2E2', padding: '7px 18px', flexShrink: 0, display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <span style={{ fontSize: 11, fontWeight: 600, color: '#475569', whiteSpace: 'nowrap', paddingTop: 5, minWidth: 150 }}>
          Cancellation Reason <span style={{ color: '#ef4444', marginLeft: 2 }}>*</span>
        </span>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 3 }}>
          <textarea
            value={cancelReason}
            onChange={e => onReasonChange(e.target.value)}
            maxLength={200}
            placeholder="Enter reason for cancellation… (stored in PO_PRH.CANREASON — required before save)"
            style={{
              width: '100%', minHeight: 48, maxHeight: 72, padding: '5px 9px',
              border: `1px solid ${cancelReasonErr ? '#A32D2D' : '#E2E2E2'}`,
              borderRadius: 6, fontSize: 12, fontFamily: 'inherit',
              color: '#1A1A1A', resize: 'vertical', outline: 'none',
              background: cancelReasonErr ? '#fff9f9' : '#fff',
            }}
          />
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            {cancelReasonErr
              ? <span style={{ fontSize: 10, color: '#A32D2D', fontWeight: 600 }}>⚠ {cancelReasonErr}</span>
              : <span />
            }
            <span style={{ fontSize: 10, color: '#888', marginLeft: 'auto' }}>{cancelReason.length} / 200</span>
          </div>
        </div>
      </div>

      {/* Items table */}
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: '#fff', margin: '0', border: '1px solid #e2e2e2' }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '8px 14px', borderBottom: '1px solid #e2e2e2', background: '#fafaf8', flexShrink: 0, gap: 8 }}>
          <span style={{ fontSize: 11, fontWeight: 600, color: '#185FA5', letterSpacing: '.3px' }}>Item Lines</span>
          <span style={{ fontSize: 11, padding: '2px 8px', background: '#E6F1FB', color: '#185FA5', borderRadius: 20 }}>{lines.length} {lines.length === 1 ? 'item' : 'items'}</span>
        </div>
        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 900 }}>
            <thead>
              <tr>
                {['#', 'Item Id', 'Item Name', 'Unit', 'Qty Req.', 'Qty App.', 'Qty Ord.', 'Rate', '₹ Approx. Value', 'Required Date', 'Machine', 'Place', 'Remarks'].map((h, i) => (
                  <th key={h} style={{
                    padding: '6px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '.06em',
                    color: '#f1f5f9', background: '#1e293b', borderBottom: '2px solid #0f172a',
                    whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 10,
                    textAlign: [4,5,6,7,8].includes(i) ? 'right' : [3].includes(i) ? 'center' : 'left',
                  }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {lines.map((l, i) => (
                <tr key={l.sno} style={{ background: i % 2 === 1 ? '#f0f5ff' : '#fff' }}>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'center', color: '#94a3b8' }}>{l.sno}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, fontFamily: 'monospace', fontWeight: 700 }}>{l.itemCode}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11 }}>{l.itemName}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'center' }}>{l.uom || '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{l.qtyRequired > 0 ? l.qtyRequired.toFixed(3) : '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{l.qtyApproved > 0 ? l.qtyApproved.toFixed(3) : '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{l.qtyOrdered > 0 ? l.qtyOrdered.toFixed(3) : '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{l.rate > 0 ? l.rate.toFixed(4) : '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{l.approxCost > 0 ? `₹ ${l.approxCost.toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 11 }}>{l.reqdDate || '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 10, fontFamily: 'monospace' }}>{l.machine || '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 10 }}>{l.placeOfIssue || '—'}</td>
                  <td style={{ padding: '4px 8px', fontSize: 10 }}>{l.remarks || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* KPI strip */}
      <div style={{ background: '#fafaf8', borderTop: '1px solid #E2E2E2', padding: '8px 16px', flexShrink: 0 }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 8 }}>
          {[
            { label: 'TOTAL LINES',    value: String(lines.length), color: '#185FA5', accent: '#185FA5' },
            { label: 'TOTAL QUANTITY', value: totalQty.toFixed(3),  color: '#1A1A1A', accent: '' },
            { label: 'APPROX. BUDGET', value: totalCost > 0 ? `₹ ${totalCost.toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : '—', color: '#BA7517', accent: '#BA7517' },
          ].map(({ label, value, color, accent }) => (
            <div key={label} style={{ background: '#fff', border: `1px solid #E2E2E2${accent ? '' : ''}`, borderLeft: `3px solid ${accent || '#E2E2E2'}`, borderRadius: 8, padding: '7px 12px', minWidth: 0 }}>
              <div style={{ fontSize: 10, fontWeight: 600, color: '#888', letterSpacing: '.3px', marginBottom: 2 }}>{label}</div>
              <div style={{ fontSize: 15, fontWeight: 700, color, lineHeight: 1.2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{value}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
