import { useRef } from 'react'
import { Button, Input, Modal, type InputRef } from 'antd'
import { SearchOutlined, BankOutlined } from '@ant-design/icons'
import * as prApi from '../../api/prApi'
import type { CostCentreOption } from '../../types'
import { LOOKUP_TH as TH, LOOKUP_TD as TD } from '@/shared/styles/erpTable'
import { useLookupModal } from '@/shared/hooks/useLookupModal'

interface CostCentreLookupModalProps {
  open:      boolean
  divCode:   string
  onSelect:  (cc: CostCentreOption) => void
  onCancel:  () => void
}

export function CostCentreLookupModal({ open, divCode, onSelect, onCancel }: CostCentreLookupModalProps) {
  const searchInputRef = useRef<InputRef>(null)

  const { items, loading, search, selected, handleSearchChange, handleRowClick, handleRowDblClick, handleConfirm } =
    useLookupModal<CostCentreOption>({
      fetcher:  (q) => divCode ? prApi.getCostCentreLookup(divCode, q.trim() || undefined) : Promise.resolve([]),
      keyOf:    (cc) => String(cc.ccCode),
      onSelect,
    })

  // destroyOnClose remounts fresh each open — focus search on mount
  setTimeout(() => searchInputRef.current?.focus(), 120)

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width={520}
      destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: 'linear-gradient(135deg, #ecfdf5, #d1fae5)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
            boxShadow: '0 2px 8px rgba(5,150,105,0.18)',
          }}>
            <BankOutlined style={{ color: '#059669', fontSize: 18 }} />
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b', lineHeight: 1.3 }}>
              Sub Cost Centre Lookup
            </div>
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
              Double-click to select instantly
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
          placeholder="Search by code or name…"
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          allowClear
          style={{ borderRadius: 8, background: '#f8fafc', fontSize: 13 }}
        />
        <div style={{ marginTop: 6, fontSize: 11, color: '#94a3b8', textAlign: 'right' }}>
          {loading ? 'Loading…' : `${items.length} cost centre${items.length !== 1 ? 's' : ''} found`}
        </div>
      </div>

      {/* Table */}
      <div style={{ maxHeight: 340, overflowY: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ ...TH, width: 90, textAlign: 'right' }}>SCC Id</th>
              <th style={{ ...TH, minWidth: 200 }}>Name</th>
            </tr>
          </thead>
          <tbody>
            {loading && items.length === 0 ? (
              <tr>
                <td colSpan={2} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  Loading cost centres…
                </td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={2} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  {search ? `No cost centres match "${search}"` : 'No cost centres found for this division.'}
                </td>
              </tr>
            ) : (
              items.map((cc, idx) => {
                const isSel = selected?.ccCode === cc.ccCode
                return (
                  <tr
                    key={cc.ccCode}
                    style={{
                      background:    isSel ? '#ecfdf5' : idx % 2 === 0 ? '#ffffff' : '#fafafa',
                      cursor:        'pointer',
                      outline:       isSel ? '2px solid #059669' : 'none',
                      outlineOffset: -1,
                      transition:    'background 0.1s',
                    }}
                    onClick={() => handleRowClick(cc)}
                    onDoubleClick={() => handleRowDblClick(cc)}
                  >
                    <td style={{ ...TD, textAlign: 'right' }}>
                      <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, color: '#1e293b' }}>
                        {cc.ccCode}
                      </span>
                    </td>
                    <td style={TD}>
                      <span style={{ fontSize: 13, color: '#1e293b' }}>{cc.ccName || <span style={{ color: '#d1d5db' }}>—</span>}</span>
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
            <span style={{ fontSize: 12, color: '#059669', fontWeight: 600 }}>
              <span style={{ fontFamily: 'monospace' }}>{selected.ccCode}</span>
              {selected.ccName && (
                <span style={{ color: '#475569', fontWeight: 400 }}> — {selected.ccName}</span>
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
              background: 'linear-gradient(135deg, #059669, #047857)',
              border: 'none', fontWeight: 600, paddingInline: 24,
              boxShadow: '0 3px 10px rgba(5,150,105,0.35)',
            } : { paddingInline: 24 }}
          >
            Select →
          </Button>
        </div>
      </div>
    </Modal>
  )
}
