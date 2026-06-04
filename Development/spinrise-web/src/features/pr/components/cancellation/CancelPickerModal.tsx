import { useState } from 'react'
import { Modal, Spin } from 'antd'
import type { PrCancellablePrDto } from '../../types'

interface Props {
  open:       boolean
  list:       PrCancellablePrDto[]
  loading:    boolean
  onSelect:   (pr: PrCancellablePrDto) => void
  onClose:    () => void
}

export default function CancelPickerModal({ open, list, loading, onSelect, onClose }: Props) {
  const [search,  setSearch]  = useState('')
  const [selIdx,  setSelIdx]  = useState<number | null>(null)

  const filtered = search
    ? list.filter(r =>
        JSON.stringify(r).toLowerCase().includes(search.toLowerCase()))
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
            background: 'linear-gradient(135deg,#fff1f0,#fde8e8)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 8px rgba(220,38,38,.18)',
          }}>
            <span style={{ color: '#dc2626', fontSize: 18 }}>🚫</span>
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>Select PR to Cancel</div>
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
              Purchase Requisition
              <span style={{ marginLeft: 8, color: '#94a3b8' }}>({list.length} record{list.length !== 1 ? 's' : ''})</span>
            </div>
          </div>
        </div>
      }
      styles={{ body: { padding: 0 } }}
    >
      {/* Search */}
      <div style={{ padding: '10px 16px', borderBottom: '1px solid #E2E2E2', display: 'flex', gap: 8 }}>
        <input
          autoFocus
          value={search}
          onChange={e => { setSearch(e.target.value); setSelIdx(null) }}
          placeholder="Search by PR number, department or requester…"
          style={{ flex: 1, height: 34, padding: '0 10px', border: '1px solid #E2E2E2', borderRadius: 8, fontSize: 13, background: '#f8fafc', outline: 'none' }}
        />
      </div>

      {/* Table */}
      <div style={{ maxHeight: 380, overflowY: 'auto' }}>
        <Spin spinning={loading}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                {['PR No', 'PR Date', 'Department', 'Requester', 'Items'].map((h, i) => (
                  <th key={h} style={{
                    padding: '8px 10px', fontSize: 10, fontWeight: 700, color: '#64748b',
                    textTransform: 'uppercase', letterSpacing: '.05em',
                    background: '#f8fafc', borderBottom: '2px solid #e2e8f0',
                    whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 1,
                    textAlign: i === 4 ? 'right' : 'left',
                  }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((pr, i) => (
                <tr
                  key={`${pr.prNo}-${pr.prDate}`}
                  onClick={() => setSelIdx(i)}
                  onDoubleClick={() => { setSelIdx(i); setTimeout(confirm, 50) }}
                  style={{
                    cursor: 'pointer',
                    background:   selIdx === i ? '#eff6ff' : i % 2 === 0 ? '#fff' : '#fafafa',
                    outline:      selIdx === i ? '2px solid #dc2626' : 'none',
                    outlineOffset: selIdx === i ? '-1px' : '0',
                  }}
                >
                  <td style={{ padding: '8px 10px', fontSize: 12, fontFamily: 'monospace', fontWeight: 700, color: '#1e293b' }}>
                    PR-{String(pr.prNo).padStart(5, '0')}
                  </td>
                  <td style={{ padding: '8px 10px', fontSize: 12, color: '#475569' }}>{pr.prDate}</td>
                  <td style={{ padding: '8px 10px', fontSize: 13, fontWeight: 500, color: '#1e293b' }}>{pr.department}</td>
                  <td style={{ padding: '8px 10px', fontSize: 12, color: '#475569' }}>{pr.requester}</td>
                  <td style={{ padding: '8px 10px', fontSize: 12, color: '#64748b', textAlign: 'right' }}>{pr.itemCount}</td>
                </tr>
              ))}
              {filtered.length === 0 && !loading && (
                <tr><td colSpan={5} style={{ padding: 24, textAlign: 'center', color: '#888', fontSize: 12 }}>No eligible PRs found.</td></tr>
              )}
            </tbody>
          </table>
        </Spin>
      </div>

      {/* Footer */}
      <div style={{
        padding: '10px 16px', borderTop: '2px solid #f0f0f0',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: '#FAFAF8',
      }}>
        <div style={{ flex: 1 }}>
          {selIdx !== null ? (
            <span style={{ fontSize: 12, color: '#dc2626', fontWeight: 600, fontFamily: 'monospace' }}>
              PR-{String(filtered[selIdx]?.prNo ?? 0).padStart(5, '0')}
              <span style={{ color: '#475569', fontWeight: 400, fontFamily: 'inherit' }}> — {filtered[selIdx]?.department}</span>
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
              padding: '6px 24px', background: '#dc2626', color: '#fff',
              border: 'none', borderRadius: 6, fontSize: 12, fontWeight: 600,
              cursor: selIdx === null ? 'not-allowed' : 'pointer',
              opacity: selIdx === null ? 0.4 : 1,
            }}
          >
            Select to Cancel →
          </button>
        </div>
      </div>
    </Modal>
  )
}
