import { useCallback, useEffect, useState } from 'react'
import { Input } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getAmendmentList } from '../../api/prAmendmentApi'
import type { AmendmentSummary } from '../../types'

interface Props {
  open:     boolean
  fDate:    string
  lDate:    string
  mode:     'modify' | 'delete' | 'view'
  onSelect: (item: AmendmentSummary) => void
  onClose:  () => void
}

export default function PrAmendmentListModal({ open, fDate, lDate, mode, onSelect, onClose }: Props) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')

  const [items,    setItems]    = useState<AmendmentSummary[]>([])
  const [loading,  setLoading]  = useState(false)
  const [search,   setSearch]   = useState('')
  const [selected, setSelected] = useState<AmendmentSummary | null>(null)

  const fetch = useCallback(async () => {
    if (!divCode) return
    setLoading(true)
    try {
      const data = await getAmendmentList(divCode, fDate, lDate, undefined, undefined, 1, 200)
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
          String(i.amendNo).includes(search) ||
          i.depName?.toLowerCase().includes(search.toLowerCase()) ||
          i.amendmentReason?.toLowerCase().includes(search.toLowerCase()),
      )
    : items

  const handleConfirm = () => { if (selected) onSelect(selected) }

  const iconColor = mode === 'delete' ? '#BA7517' : '#185FA5'
  const iconBg    = mode === 'delete' ? 'linear-gradient(135deg,#fefce8,#fef3c7)' : 'linear-gradient(135deg,#eff6ff,#dbeafe)'
  const iconShadow = mode === 'delete' ? '0 2px 8px rgba(186,117,23,.18)' : '0 2px 8px rgba(24,95,165,.18)'

  const title = mode === 'modify' ? 'Select Amendment to Modify'
    : mode === 'delete' ? 'Select Amendment to Delete'
    : 'Select Amendment to Load'

  const btnLabel = mode === 'modify' ? 'Modify →' : mode === 'delete' ? 'Delete →' : 'Load →'

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(15,23,42,.55)', backdropFilter: 'blur(4px)', display: open ? 'flex' : 'none', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ background: '#fff', borderRadius: 10, boxShadow: '0 24px 48px rgba(0,0,0,.22)', display: 'flex', flexDirection: 'column', width: 820, maxHeight: '90vh' }}>

        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 38, height: 38, borderRadius: 10, background: iconBg, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: iconShadow, flexShrink: 0 }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={iconColor} strokeWidth="2">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
              </svg>
            </div>
            <div>
              <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{title}</div>
              <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>Existing PR amendments · FY 2025–26</div>
            </div>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 18, color: '#888', padding: '2px 6px', borderRadius: 4 }}>✕</button>
        </div>

        {/* Search */}
        <div style={{ padding: '12px 20px', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
          <Input
            prefix={<SearchOutlined />}
            placeholder="Search by amendment no, PR no, department or reason…"
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
                    { label: 'Amend No.',  w: 90,       align: 'left'  as const },
                    { label: 'PR No.',     w: 70,       align: 'right' as const },
                    { label: 'Amend Date', w: 105,      align: 'left'  as const },
                    { label: 'Department', w: undefined, align: 'left' as const },
                    { label: 'Reason',     w: undefined, align: 'left' as const },
                    { label: 'Lines',      w: 50,       align: 'right' as const },
                  ].map((col) => (
                    <th key={col.label} style={{ padding: '8px 12px', fontSize: 11, fontWeight: 700, textAlign: col.align, borderBottom: '2px solid #e2e2e2', ...(col.w ? { width: col.w } : {}) }}>
                      {col.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.map((a) => {
                  const isSel = selected?.amendNo === a.amendNo && selected?.prNo === a.prNo && selected?.prDate === a.prDate
                  return (
                    <tr
                      key={`${a.prNo}-${a.prDate}-${a.amendNo}`}
                      onClick={() => setSelected(a)}
                      onDoubleClick={() => { setSelected(a); onSelect(a) }}
                      style={{ cursor: 'pointer', background: isSel ? '#dbeafe' : undefined }}
                      onMouseEnter={(e) => { if (!isSel) (e.currentTarget as HTMLTableRowElement).style.background = '#E6F1FB' }}
                      onMouseLeave={(e) => { (e.currentTarget as HTMLTableRowElement).style.background = isSel ? '#dbeafe' : '' }}
                    >
                      <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', fontFamily: 'monospace', fontWeight: 700 }}>
                        AMD-{String(a.amendNo).padStart(4, '0')}
                      </td>
                      <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', textAlign: 'right', fontFamily: 'monospace' }}>{a.prNo}</td>
                      <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5' }}>{a.amendDate}</td>
                      <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5' }}>{a.depCode} – {a.depName}</td>
                      <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {a.amendmentReason}
                      </td>
                      <td style={{ padding: '7px 12px', borderBottom: '1px solid #f5f5f5', textAlign: 'right', fontFamily: 'monospace' }}>{a.totalLines}</td>
                    </tr>
                  )
                })}
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: '#888', fontSize: 12 }}>
                      No amendments found.
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
            style={{ padding: '6px 22px', background: '#185FA5', color: '#fff', border: 'none', borderRadius: 6, fontSize: 12, fontWeight: 600, cursor: selected ? 'pointer' : 'not-allowed', opacity: selected ? 1 : .38, fontFamily: 'inherit' }}
          >
            {btnLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
