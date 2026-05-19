import { useCallback, useEffect, useRef, useState } from 'react'
import { Button, Input, Modal, Spin, Typography, type InputRef } from 'antd'
import { FileTextOutlined, SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import * as prApi from '../../api/prApi'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { PR_STATUS_BADGE, type PrSummary } from '../../types'
import { useAuthStore } from '@/features/auth/store/useAuthStore'

interface PRPickerModalProps {
  open:     boolean
  mode:     'modify' | 'delete'
  onSelect: (prNo: number, prDate: string) => void
  onCancel: () => void
}

const TH: React.CSSProperties = {
  padding: '8px 10px', fontSize: 11, fontWeight: 700, color: '#64748b',
  background: '#f8fafc', borderBottom: '2px solid #e2e8f0', whiteSpace: 'nowrap',
  position: 'sticky', top: 0, zIndex: 1,
}

const TD: React.CSSProperties = {
  padding: '7px 10px', borderBottom: '1px solid #f1f5f9', verticalAlign: 'middle',
}

function fmtDate(d: string): string {
  const dt = dayjs(d)
  return dt.isValid() ? dt.format('DD/MM/YYYY') : d
}

export function PRPickerModal({ open, mode, onSelect, onCancel }: PRPickerModalProps) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')
  const [allRows,  setAllRows]  = useState<PrSummary[]>([])
  const [loading,  setLoading]  = useState(false)
  const [search,   setSearch]   = useState('')
  const [selected, setSelected] = useState<PrSummary | null>(null)
  const searchRef = useRef<InputRef>(null)

  const apiMode = mode === 'modify' ? 'EDIT' : 'DELETE'

  const load = useCallback(async () => {
    if (!divCode) return
    const { yfDate, ylDate } = getFYBounds()
    setLoading(true)
    try {
      const data = await prApi.getList(divCode, yfDate, ylDate, apiMode, { pageSize: 500 })
      setAllRows(data)
    } catch { /* stay as-is */ }
    finally { setLoading(false) }
  }, [divCode, apiMode])

  useEffect(() => {
    if (!open) return
    setSearch('')
    setSelected(null)
    setAllRows([])
    void load()
    setTimeout(() => searchRef.current?.focus(), 120)
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

  const rows = search.trim()
    ? allRows.filter((r) => {
        const q = search.toLowerCase()
        return (
          String(r.prNo).includes(q) ||
          (r.depName ?? '').toLowerCase().includes(q) ||
          (r.reqEmpName ?? '').toLowerCase().includes(q)
        )
      })
    : allRows

  const isDelete  = mode === 'delete'
  const accentClr = isDelete ? '#dc2626' : '#1d4ed8'
  const accentBg  = isDelete ? 'linear-gradient(135deg, #fff1f0, #fde8e8)' : 'linear-gradient(135deg, #eff6ff, #dbeafe)'
  const accentSdw = isDelete ? 'rgba(220,38,38,0.18)' : 'rgba(22,119,255,0.18)'

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width={820}
      destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: accentBg, flexShrink: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 2px 8px ${accentSdw}`,
          }}>
            <FileTextOutlined style={{ color: accentClr, fontSize: 18 }} />
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b', lineHeight: 1.3 }}>
              {isDelete ? 'Select PR to Delete' : 'Select PR to Modify'}
            </div>
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
              Purchase Requisition
              {allRows.length > 0 && (
                <span style={{ marginLeft: 8, color: '#94a3b8' }}>
                  ({rows.length}{search ? ` of ${allRows.length}` : ''} records)
                </span>
              )}
            </div>
          </div>
        </div>
      }
    >
      {/* ── Search ── */}
      <div style={{ padding: '14px 20px 10px', borderBottom: '1px solid #f0f0f0' }}>
        <Input
          ref={searchRef}
          prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
          placeholder="Search by PR number, department or requester"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onClear={() => setSearch('')}
          allowClear
          style={{ borderRadius: 8, background: '#f8fafc', fontSize: 13 }}
        />
      </div>

      {/* ── Table ── */}
      <div style={{ maxHeight: 380, overflowY: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ ...TH, width: 105 }}>PR No</th>
              <th style={{ ...TH, width: 100 }}>PR Date</th>
              <th style={{ ...TH }}>Department</th>
              <th style={{ ...TH }}>Requester</th>
              <th style={{ ...TH, width: 72, textAlign: 'right' }}>Items</th>
              <th style={{ ...TH, width: 180 }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '40px' }}>
                  <Spin size="small" />
                </td>
              </tr>
            ) : rows.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  {search ? `No records match "${search}"` : 'No purchase requisitions found.'}
                </td>
              </tr>
            ) : (
              rows.map((row, idx) => {
                const isSel      = selected?.prNo === row.prNo && selected?.prDate === row.prDate
                const statusInfo = PR_STATUS_BADGE[row.prStatus]
                return (
                  <tr
                    key={`${row.prNo}-${row.prDate}`}
                    style={{
                      background:    isSel ? '#eff6ff' : idx % 2 === 0 ? '#fff' : '#fafafa',
                      cursor:        'pointer',
                      outline:       isSel ? '2px solid #1677ff' : 'none',
                      outlineOffset: -1,
                      transition:    'background 0.1s',
                    }}
                    onClick={() => setSelected((prev) =>
                      prev?.prNo === row.prNo && prev?.prDate === row.prDate ? null : row
                    )}
                    onDoubleClick={() => onSelect(row.prNo, row.prDate)}
                  >
                    <td style={TD}>
                      <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, color: '#1e293b' }}>
                        PR-{String(row.prNo).padStart(5, '0')}
                      </span>
                    </td>
                    <td style={{ ...TD, fontSize: 12, color: '#475569' }}>{fmtDate(row.prDate)}</td>
                    <td style={TD}>
                      <div style={{ fontWeight: 500, fontSize: 13, color: '#1e293b' }}>{row.depName ?? '—'}</div>
                    </td>
                    <td style={{ ...TD, fontSize: 12, color: '#475569' }}>{row.reqEmpName ?? '—'}</td>
                    <td style={{ ...TD, textAlign: 'right', fontSize: 12, color: '#64748b' }}>{row.totalLines}</td>
                    <td style={TD}>
                      {statusInfo ? (
                        <span style={{
                          display: 'inline-block', padding: '1px 8px', borderRadius: 12,
                          background: statusInfo.bg, color: statusInfo.color,
                          border: `1px solid ${statusInfo.color}40`,
                          fontSize: 11, fontWeight: 600, whiteSpace: 'nowrap',
                        }}>
                          {row.prStatus}
                        </span>
                      ) : (
                        <span style={{ fontSize: 11, color: '#888' }}>{row.prStatus}</span>
                      )}
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>

      {/* ── Footer ── */}
      <div style={{
        padding: '12px 20px', borderTop: '2px solid #f0f0f0',
        display: 'flex', alignItems: 'center', gap: 12,
        background: '#fafafa', borderRadius: '0 0 8px 8px',
      }}>
        <div style={{ flex: 1 }}>
          {selected ? (
            <span style={{ fontSize: 12, color: '#1677ff', fontWeight: 600 }}>
              <span style={{ fontFamily: 'monospace' }}>PR-{String(selected.prNo).padStart(5, '0')}</span>
              {' — '}
              <span style={{ color: '#475569', fontWeight: 400 }}>{selected.depName ?? selected.depCode}</span>
              {selected.reqEmpName && <span style={{ color: '#94a3b8' }}> · {selected.reqEmpName}</span>}
            </span>
          ) : (
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              Click to select · Double-click to confirm immediately
            </Typography.Text>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
          <Button onClick={onCancel}>Cancel</Button>
          <Button
            type="primary"
            danger={isDelete}
            disabled={!selected}
            onClick={() => selected && onSelect(selected.prNo, selected.prDate)}
            style={selected ? {
              fontWeight: 600, paddingInline: 24,
              ...(!isDelete ? {
                background: 'linear-gradient(135deg, #1677ff, #0950a8)',
                border: 'none', boxShadow: '0 3px 10px rgba(22,119,255,0.4)',
              } : {}),
            } : { paddingInline: 24 }}
          >
            {isDelete ? 'Select to Delete →' : 'Modify PR →'}
          </Button>
        </div>
      </div>
    </Modal>
  )
}
