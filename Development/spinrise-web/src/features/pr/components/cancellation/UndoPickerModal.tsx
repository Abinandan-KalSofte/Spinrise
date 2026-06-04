import { useState } from 'react'
import { Modal, Spin } from 'antd'
import type { PrCancelledPrDto } from '../../types'

const STATUS_LABEL: Record<string, string> = {
  S: 'Requested', P: 'Partial', E: 'Enquired', O: 'Ordered',
  F: 'First Approved', T: 'Second Approved', L: 'Final Approved',
}
const STATUS_BADGE: Record<string, { color: string; bg: string; border: string }> = {
  S: { color: '#15803d', bg: '#dcfce7', border: '#86efac' },
  P: { color: '#BA7517', bg: '#FAEEDA', border: '#fcd34d' },
  E: { color: '#185FA5', bg: '#E6F1FB', border: '#bfdbfe' },
  O: { color: '#7c3aed', bg: '#f3e8ff', border: '#ddd6fe' },
}

interface Props {
  open:     boolean
  list:     PrCancelledPrDto[]
  loading:  boolean
  onSelect: (pr: PrCancelledPrDto) => void
  onClose:  () => void
}

export default function UndoPickerModal({ open, list, loading, onSelect, onClose }: Props) {
  const [search, setSearch] = useState('')
  const [selIdx, setSelIdx] = useState<number | null>(null)

  const filtered = search
    ? list.filter(r => JSON.stringify(r).toLowerCase().includes(search.toLowerCase()))
    : list

  const confirm = () => {
    if (selIdx === null) return
    onSelect(filtered[selIdx])
    setSearch('')
    setSelIdx(null)
  }

  const handleClose = () => {
    setSearch('')
    setSelIdx(null)
    onClose()
  }

  return (
    <Modal
      open={open}
      onCancel={handleClose}
      footer={null}
      width={820}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10, flexShrink: 0,
            background: 'linear-gradient(135deg,#fefce8,#fef3c7)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 8px rgba(186,117,23,.18)',
          }}>
            <span style={{ fontSize: 18 }}>↩</span>
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>Select Cancelled PR to Undo</div>
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
              Cancelled PRs · FY 2025–26 only
              <span style={{ marginLeft: 8, color: '#94a3b8' }}>({list.length} cancelled PR{list.length !== 1 ? 's' : ''})</span>
            </div>
          </div>
        </div>
      }
      styles={{ body: { padding: 0 } }}
    >
      <div style={{ padding: '10px 16px', borderBottom: '1px solid #E2E2E2', display: 'flex', gap: 8 }}>
        <input
          autoFocus
          value={search}
          onChange={e => { setSearch(e.target.value); setSelIdx(null) }}
          placeholder="Search by PR number, department or requester…"
          style={{ flex: 1, height: 34, padding: '0 10px', border: '1px solid #E2E2E2', borderRadius: 8, fontSize: 13, background: '#f8fafc', outline: 'none' }}
        />
      </div>

      <div style={{ maxHeight: 380, overflowY: 'auto' }}>
        <Spin spinning={loading}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                {['PR No', 'PR Date', 'Department', 'Requested By', 'Cancelled On', 'Prev. Status'].map((h) => (
                  <th key={h} style={{
                    padding: '8px 10px', fontSize: 10, fontWeight: 700, color: '#64748b',
                    textTransform: 'uppercase', letterSpacing: '.05em',
                    background: '#f8fafc', borderBottom: '2px solid #e2e8f0',
                    whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 1, textAlign: 'left',
                  }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((pr, i) => {
                const badge = STATUS_BADGE[pr.prevStatus] ?? STATUS_BADGE['S']
                const label = STATUS_LABEL[pr.prevStatus] ?? pr.prevStatus
                return (
                  <tr
                    key={`${pr.prNo}-${pr.prDate}`}
                    onClick={() => setSelIdx(i)}
                    onDoubleClick={() => { setSelIdx(i); setTimeout(confirm, 50) }}
                    style={{
                      cursor: 'pointer',
                      background:    selIdx === i ? '#fefce8' : i % 2 === 0 ? '#fff' : '#fafafa',
                      outline:       selIdx === i ? '2px solid #BA7517' : 'none',
                      outlineOffset: selIdx === i ? '-1px' : '0',
                    }}
                  >
                    <td style={{ padding: '8px 10px', fontSize: 12, fontFamily: 'monospace', fontWeight: 700, color: '#A32D2D' }}>
                      PR-{String(pr.prNo).padStart(5, '0')}
                    </td>
                    <td style={{ padding: '8px 10px', fontSize: 12, color: '#475569' }}>{pr.prDate}</td>
                    <td style={{ padding: '8px 10px', fontSize: 13, fontWeight: 500, color: '#1e293b' }}>{pr.department}</td>
                    <td style={{ padding: '8px 10px', fontSize: 12, color: '#475569' }}>{pr.requestedBy}</td>
                    <td style={{ padding: '8px 10px', fontSize: 12, color: '#A32D2D', fontWeight: 500 }}>{pr.cancelledOn}</td>
                    <td style={{ padding: '8px 10px' }}>
                      <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 10, color: badge.color, background: badge.bg, border: `1px solid ${badge.border}` }}>
                        {label}
                      </span>
                    </td>
                  </tr>
                )
              })}
              {filtered.length === 0 && !loading && (
                <tr><td colSpan={6} style={{ padding: 24, textAlign: 'center', color: '#888', fontSize: 12 }}>No cancelled PRs found for the current financial year.</td></tr>
              )}
            </tbody>
          </table>
        </Spin>
      </div>

      <div style={{
        padding: '10px 16px', borderTop: '2px solid #f0f0f0',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: '#FAFAF8',
      }}>
        <div style={{ flex: 1 }}>
          {selIdx !== null ? (
            <span style={{ fontSize: 12, color: '#BA7517', fontWeight: 600, fontFamily: 'monospace' }}>
              PR-{String(filtered[selIdx]?.prNo ?? 0).padStart(5, '0')}
              <span style={{ color: '#475569', fontWeight: 400, fontFamily: 'inherit' }}> — {filtered[selIdx]?.department}</span>
              <span style={{ color: '#94a3b8' }}> · Cancelled {filtered[selIdx]?.cancelledOn}</span>
            </span>
          ) : (
            <span style={{ fontSize: 12, color: '#94a3b8' }}>Click to select · Double-click to confirm immediately</span>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={handleClose} style={{ padding: '6px 14px', background: '#fff', border: '1px solid #E2E2E2', borderRadius: 6, fontSize: 12, cursor: 'pointer' }}>
            Cancel
          </button>
          <button
            onClick={confirm}
            disabled={selIdx === null}
            style={{
              padding: '6px 24px', background: '#BA7517', color: '#fff',
              border: 'none', borderRadius: 6, fontSize: 12, fontWeight: 600,
              cursor: selIdx === null ? 'not-allowed' : 'pointer',
              opacity: selIdx === null ? 0.4 : 1,
            }}
          >
            ↩ Undo This PR →
          </button>
        </div>
      </div>
    </Modal>
  )
}
