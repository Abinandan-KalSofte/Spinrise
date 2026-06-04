import { useCallback, useEffect, useState } from 'react'
import { Input } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getList } from '../../api/prApi'
import type { PrSummary } from '../../types'

interface Props {
  open:     boolean
  fDate:    string
  lDate:    string
  onSelect: (item: PrSummary) => void
  onClose:  () => void
}

export default function PrPickerForAmendModal({ open, fDate, lDate, onSelect, onClose }: Props) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')

  const [items,    setItems]    = useState<PrSummary[]>([])
  const [loading,  setLoading]  = useState(false)
  const [search,   setSearch]   = useState('')
  const [selected, setSelected] = useState<PrSummary | null>(null)

  const fetch = useCallback(async () => {
    if (!divCode) return
    setLoading(true)
    try {
      const data = await getList(divCode, fDate, lDate, 'FIND', { pageSize: 200 })
      setItems(data)
    } catch {
      // handled by interceptor
    } finally {
      setLoading(false)
    }
  }, [divCode, fDate, lDate])

  useEffect(() => {
    if (open) { setSearch(''); setSelected(null); void fetch() }
  }, [open, fetch])

  const filtered = search
    ? items.filter(
        (i) =>
          String(i.prNo).includes(search) ||
          i.depName?.toLowerCase().includes(search.toLowerCase()) ||
          i.reqName?.toLowerCase().includes(search.toLowerCase()),
      )
    : items

  const handleConfirm = () => { if (selected) onSelect(selected) }

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(15,23,42,.55)', backdropFilter: 'blur(4px)', display: open ? 'flex' : 'none', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ background: '#fff', borderRadius: 10, boxShadow: '0 24px 48px rgba(0,0,0,.22)', display: 'flex', flexDirection: 'column', width: 820, maxHeight: '90vh' }}>

        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 38, height: 38, borderRadius: 10, background: 'linear-gradient(135deg,#eff6ff,#dbeafe)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 8px rgba(24,95,165,.18)', flexShrink: 0 }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#185FA5" strokeWidth="2">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/>
              </svg>
            </div>
            <div>
              <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>Select PR to Amend</div>
              <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>Purchase Requisitions · Requested status only</div>
            </div>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 18, color: '#888', padding: '2px 6px', borderRadius: 4 }}>✕</button>
        </div>

        {/* Search */}
        <div style={{ padding: '12px 20px', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
          <Input
            prefix={<SearchOutlined />}
            placeholder="Search by PR number, department or requester…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            allowClear
            style={{ height: 34 }}
          />
        </div>

        {/* Table */}
        <div style={{ overflowY: 'auto', maxHeight: 380 }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: 32, color: '#888', fontSize: 12 }}>Loading…</div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ background: '#FAFAF8', position: 'sticky', top: 0 }}>
                  {[
                    { label: 'PR No.',           w: 75,  align: 'right' as const },
                    { label: 'PR Date',          w: 105, align: 'left'  as const },
                    { label: 'Department',       w: undefined, align: 'left' as const },
                    { label: 'Requester',        w: undefined, align: 'left' as const },
                    { label: 'PR Type',          w: 80,  align: 'left'  as const },
                    { label: 'Lines',            w: 50,  align: 'right' as const },
                    { label: 'Prior Amendments', w: 110, align: 'right' as const },
                  ].map((col) => (
                    <th key={col.label} style={{ padding: '8px 12px', fontSize: 11, fontWeight: 700, textAlign: col.align, borderBottom: '2px solid #e2e2e2', ...(col.w ? { width: col.w } : {}) }}>
                      {col.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.map((pr) => (
                  <tr
                    key={`${pr.prNo}-${pr.prDate}`}
                    onClick={() => setSelected(pr)}
                    onDoubleClick={() => { setSelected(pr); onSelect(pr) }}
                    style={{
                      cursor: 'pointer',
                      background: selected?.prNo === pr.prNo && selected?.prDate === pr.prDate ? '#dbeafe' : undefined,
                    }}
                    onMouseEnter={(e) => { if (!(selected?.prNo === pr.prNo && selected?.prDate === pr.prDate)) (e.currentTarget as HTMLTableRowElement).style.background = '#E6F1FB' }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLTableRowElement).style.background = selected?.prNo === pr.prNo && selected?.prDate === pr.prDate ? '#dbeafe' : '' }}
                  >
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', textAlign: 'right', fontFamily: 'monospace', fontWeight: 700 }}>{pr.prNo}</td>
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5' }}>{pr.prDate}</td>
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5' }}>{pr.depCode} – {pr.depName}</td>
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5' }}>{pr.reqName}</td>
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5' }}>{pr.iDesc || pr.iType}</td>
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', textAlign: 'right', fontFamily: 'monospace' }}>{pr.totalLines}</td>
                    <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', textAlign: 'right', color: '#94a3b8', fontFamily: 'monospace' }}>—</td>
                  </tr>
                ))}
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: '#888', fontSize: 12 }}>
                      No purchase requisitions found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          )}
        </div>

        {/* Footer */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 20px', borderTop: '1px solid #e2e2e2', flexShrink: 0 }}>
          <span style={{ flex: 1, fontSize: 12, color: '#94a3b8' }}>Click to select · Double-click to confirm immediately</span>
          <button onClick={onClose} style={{ padding: '6px 14px', border: '1px solid #e2e2e2', borderRadius: 6, background: '#fff', fontSize: 12, cursor: 'pointer', fontFamily: 'inherit' }}>
            Cancel
          </button>
          <button
            onClick={handleConfirm}
            disabled={!selected}
            style={{ padding: '6px 22px', background: selected ? '#185FA5' : '#185FA5', color: '#fff', border: 'none', borderRadius: 6, fontSize: 12, fontWeight: 600, cursor: selected ? 'pointer' : 'not-allowed', opacity: selected ? 1 : .38, fontFamily: 'inherit' }}
          >
            Select →
          </button>
        </div>
      </div>
    </div>
  )
}
