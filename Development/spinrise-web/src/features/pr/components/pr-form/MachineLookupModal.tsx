import { useCallback, useEffect, useRef, useState } from 'react'
import { Button, Input, Modal, type InputRef } from 'antd'
import { SearchOutlined, ToolOutlined } from '@ant-design/icons'
import * as prApi from '../../api/prApi'
import type { MachineLookup } from '../../types'

interface MachineLookupModalProps {
  open:      boolean
  divCode:   string
  depCode:   string
  onSelect:  (machine: MachineLookup) => void
  onCancel:  () => void
}

const TH: React.CSSProperties = {
  padding: '8px 10px', fontSize: 11, fontWeight: 700, color: '#64748b',
  background: '#f8fafc', borderBottom: '2px solid #e2e8f0',
  textTransform: 'uppercase', letterSpacing: '0.05em',
  whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 1,
}

const TD: React.CSSProperties = {
  padding: '7px 10px', borderBottom: '1px solid #f1f5f9', verticalAlign: 'middle',
}

export function MachineLookupModal({ open, divCode, depCode, onSelect, onCancel }: MachineLookupModalProps) {
  const [machines,  setMachines]  = useState<MachineLookup[]>([])
  const [loading,   setLoading]   = useState(false)
  const [search,    setSearch]    = useState('')
  const [selected,  setSelected]  = useState<MachineLookup | null>(null)

  const searchInputRef = useRef<InputRef>(null)
  const searchTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined)

  const load = useCallback(async (q: string) => {
    if (!divCode || !depCode) return
    setLoading(true)
    try {
      const result = await prApi.getMachineLookup(divCode, depCode, q.trim() || undefined)
      setMachines(result)
    } catch { /* swallow */ }
    finally { setLoading(false) }
  }, [divCode, depCode])

  // destroyOnClose remounts fresh each open — just load and focus on mount
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load('')
    setTimeout(() => searchInputRef.current?.focus(), 120)
  }, [load])

  const handleSearchChange = (q: string) => {
    setSearch(q)
    clearTimeout(searchTimerRef.current)
    searchTimerRef.current = setTimeout(() => void load(q), 300)
  }

  const handleRowClick = (m: MachineLookup) =>
    setSelected((prev) => prev?.macNo === m.macNo ? null : m)

  const handleRowDblClick = (m: MachineLookup) => {
    onSelect(m)
    setSelected(null)
  }

  const handleConfirm = () => {
    if (!selected) return
    onSelect(selected)
    setSelected(null)
  }

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width={620}
      destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
            boxShadow: '0 2px 8px rgba(217,119,6,0.18)',
          }}>
            <ToolOutlined style={{ color: '#b45309', fontSize: 18 }} />
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b', lineHeight: 1.3 }}>
              Machine Lookup
            </div>
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
              Dept: <strong style={{ color: '#b45309' }}>{depCode || '—'}</strong>
              {' · '}Double-click to select instantly
            </div>
          </div>
        </div>
      }
    >
      {/* Search */}
      <div style={{ padding: '14px 20px 10px', borderBottom: '1px solid #f0f0f0' }}>
        <Input
          ref={searchInputRef}
          prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
          placeholder="Search by machine number or description…"
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          allowClear
          style={{ borderRadius: 8, background: '#f8fafc', fontSize: 13 }}
        />
        <div style={{ marginTop: 6, fontSize: 11, color: '#94a3b8', textAlign: 'right' }}>
          {loading ? 'Loading…' : `${machines.length} machine${machines.length !== 1 ? 's' : ''} found`}
        </div>
      </div>

      {/* Table */}
      <div style={{ maxHeight: 340, overflowY: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ ...TH, width: 90 }}>Machine No</th>
              <th style={{ ...TH, minWidth: 200 }}>Description</th>
              <th style={{ ...TH, width: 160 }}>Model</th>
            </tr>
          </thead>
          <tbody>
            {loading && machines.length === 0 ? (
              <tr>
                <td colSpan={3} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  Loading machines…
                </td>
              </tr>
            ) : machines.length === 0 ? (
              <tr>
                <td colSpan={3} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  {!depCode
                    ? 'Select a department first.'
                    : search
                    ? `No machines match "${search}"`
                    : 'No machines found for this department.'}
                </td>
              </tr>
            ) : (
              machines.map((m, idx) => {
                const isSel = selected?.macNo === m.macNo
                return (
                  <tr
                    key={m.macNo}
                    style={{
                      background:    isSel ? '#fffbeb' : idx % 2 === 0 ? '#ffffff' : '#fafafa',
                      cursor:        'pointer',
                      outline:       isSel ? '2px solid #f59e0b' : 'none',
                      outlineOffset: -1,
                      transition:    'background 0.1s',
                    }}
                    onClick={() => handleRowClick(m)}
                    onDoubleClick={() => handleRowDblClick(m)}
                  >
                    <td style={TD}>
                      <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, color: '#1e293b' }}>
                        {m.macNo}
                      </span>
                    </td>
                    <td style={TD}>
                      <span style={{ fontSize: 13, color: '#1e293b' }}>{m.macDesc || <span style={{ color: '#d1d5db' }}>—</span>}</span>
                    </td>
                    <td style={TD}>
                      <span style={{ fontSize: 12, color: '#475569' }}>{m.macModel || <span style={{ color: '#d1d5db' }}>—</span>}</span>
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Footer */}
      <div style={{
        padding: '12px 20px', borderTop: '2px solid #f0f0f0',
        display: 'flex', alignItems: 'center', gap: 12,
        background: '#fafafa', borderRadius: '0 0 8px 8px',
      }}>
        <div style={{ flex: 1 }}>
          {selected ? (
            <span style={{ fontSize: 12, color: '#b45309', fontWeight: 600 }}>
              <span style={{ fontFamily: 'monospace' }}>{selected.macNo}</span>
              {selected.macDesc && (
                <span style={{ color: '#475569', fontWeight: 400 }}> — {selected.macDesc}</span>
              )}
            </span>
          ) : (
            <span style={{ fontSize: 12, color: '#94a3b8' }}>Click a row to select · Double-click to add instantly</span>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
          <Button onClick={onCancel}>Cancel</Button>
          <Button
            type="primary"
            disabled={!selected}
            onClick={handleConfirm}
            style={selected ? {
              background: 'linear-gradient(135deg, #f59e0b, #d97706)',
              border: 'none', fontWeight: 600, paddingInline: 24,
              boxShadow: '0 3px 10px rgba(217,119,6,0.35)',
            } : { paddingInline: 24 }}
          >
            Select Machine →
          </Button>
        </div>
      </div>
    </Modal>
  )
}
