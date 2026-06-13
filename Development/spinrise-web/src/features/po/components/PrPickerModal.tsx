import { useCallback, useEffect, useRef, useState } from 'react'
import { Button, Checkbox, Input, Modal, Tag, Typography, type InputRef } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import * as poApi from '../api/poTransferApi'
import type { EligiblePrLine } from '../types'
import { LOOKUP_TH as TH, LOOKUP_TD as TD } from '@/shared/styles/erpTable'

// ── PR Picker (HTML #pr-overlay — VB6 FpSpdInd / delmodok_Click) ─────────────
// Browses approved PR lines and multi-selects them into the PO. The list is
// pre-filtered SERVER-SIDE by BR-02 (DirectApp='Y', Fclosed<>'Y'); the modal
// only displays and selects. HSN-missing rows are flagged (BR-10) but not blocked
// here — enforcement happens at save.

const fmt3 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 3, maximumFractionDigits: 3 })

interface PrPickerModalProps {
  open:      boolean
  divCode:   string
  onLoad:    (lines: EligiblePrLine[]) => void
  onCancel:  () => void
}

export function PrPickerModal({ open, divCode, onLoad, onCancel }: PrPickerModalProps) {
  const [rows,     setRows]     = useState<EligiblePrLine[]>([])
  const [loading,  setLoading]  = useState(false)
  const [search,   setSearch]   = useState('')
  const [selected, setSelected] = useState<Map<string, EligiblePrLine>>(new Map())

  const searchRef = useRef<InputRef>(null)
  const timerRef  = useRef<ReturnType<typeof setTimeout>>(undefined)

  const load = useCallback(async (searchTerm: string) => {
    if (!divCode) return
    setLoading(true)
    try {
      const result = await poApi.getEligiblePrLines(divCode, {
        search: searchTerm.trim() || undefined,
      })
      setRows(result)
    } catch { setRows([]) }
    finally { setLoading(false) }
  }, [divCode])

  useEffect(() => {
    if (!open) return
    setRows([])
    setSelected(new Map())
    setSearch('')
    void load('')
    setTimeout(() => searchRef.current?.focus(), 120)
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSearch = (q: string) => {
    setSearch(q)
    clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => void load(q), 300)   // 300ms debounce (HTML)
  }

  const toggle = (row: EligiblePrLine) => {
    setSelected((prev) => {
      const next = new Map(prev)
      if (next.has(row.id)) next.delete(row.id)
      else next.set(row.id, row)
      return next
    })
  }

  const toggleAll = (checked: boolean) =>
    setSelected(checked ? new Map(rows.map((r) => [r.id, r])) : new Map())

  const handleLoad = () => {
    if (selected.size === 0) return
    onLoad(Array.from(selected.values()))
    setSelected(new Map())
  }

  const selCount = selected.size
  const allChecked = rows.length > 0 && selCount === rows.length

  return (
    <Modal
      open={open} onCancel={onCancel} footer={null} width={920} destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={<span style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>Browse Approved PR Lines</span>}
    >
      {/* Search */}
      <div style={{ padding: '14px 20px 10px', borderBottom: '1px solid #f0f0f0' }}>
        <Input
          ref={searchRef}
          prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
          placeholder="Search by PR No., Item Code, or Item Name…"
          value={search}
          onChange={(e) => handleSearch(e.target.value)}
          allowClear
          style={{ borderRadius: 8, background: '#f8fafc' }}
        />
        <div style={{ marginTop: 8, fontSize: 11, color: '#185FA5', fontWeight: 600 }}>
          {loading ? 'Loading…' : `${rows.length} PR line${rows.length !== 1 ? 's' : ''} available`}
          {selCount > 0 && <span style={{ color: '#888', fontWeight: 400 }}> · {selCount} selected</span>}
        </div>
      </div>

      {/* Table */}
      <div style={{ maxHeight: 340, overflow: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ ...TH, width: 36 }}>
                <Checkbox checked={allChecked} indeterminate={selCount > 0 && !allChecked}
                  onChange={(e) => toggleAll(e.target.checked)} />
              </th>
              <th style={{ ...TH, width: 110 }}>PR No.</th>
              <th style={{ ...TH, width: 90 }}>PR Date</th>
              <th style={{ ...TH, width: 80 }}>Item Code</th>
              <th style={{ ...TH, minWidth: 180 }}>Item Name</th>
              <th style={{ ...TH, width: 50, textAlign: 'center' }}>UOM</th>
              <th style={{ ...TH, width: 90, textAlign: 'right' }}>Balance Qty</th>
              <th style={{ ...TH, width: 120 }}>Department</th>
              <th style={{ ...TH, width: 120 }}>Sub-Cost Centre</th>
              <th style={{ ...TH }}>Remarks</th>
            </tr>
          </thead>
          <tbody>
            {loading && rows.length === 0 ? (
              <tr><td colSpan={10} style={{ textAlign: 'center', padding: 40, color: '#94a3b8', fontSize: 13 }}>Loading PR lines…</td></tr>
            ) : rows.length === 0 ? (
              <tr><td colSpan={10} style={{ textAlign: 'center', padding: 40, color: '#94a3b8', fontSize: 13 }}>
                {search ? `No PR lines match "${search}"` : 'No approved PR lines available.'}
              </td></tr>
            ) : (
              rows.map((row, idx) => {
                const isSel = selected.has(row.id)
                const noHsn = !row.hsnCode?.trim()
                return (
                  <tr key={row.id}
                    style={{ background: isSel ? '#EBF3FF' : idx % 2 === 0 ? '#ffffff' : '#fafafa', cursor: 'pointer' }}
                    onClick={() => toggle(row)}>
                    <td style={TD} onClick={(e) => e.stopPropagation()}>
                      <Checkbox checked={isSel} onChange={() => toggle(row)} />
                    </td>
                    <td style={{ ...TD, fontFamily: 'monospace', fontWeight: 600 }}>{row.prNo}</td>
                    <td style={TD}>{row.prDate}</td>
                    <td style={{ ...TD, fontFamily: 'monospace', color: '#185FA5' }}>{row.itemCode}</td>
                    <td style={{ ...TD, minWidth: 180 }}>
                      {row.itemName}
                      {noHsn && (
                        <Tag color="warning" style={{ marginLeft: 6, fontSize: 10 }}>⚠ No HSN</Tag>
                      )}
                    </td>
                    <td style={{ ...TD, textAlign: 'center' }}>{row.uom}</td>
                    <td style={{ ...TD, textAlign: 'right', fontFamily: 'monospace' }}>{fmt3(row.balanceQty)}</td>
                    <td style={TD}>{row.department}</td>
                    <td style={TD}>{row.subCostCentre}</td>
                    <td style={{ ...TD, fontSize: 11, color: '#888' }}>{row.remarks}</td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Footer */}
      <div style={{
        padding: '12px 20px', borderTop: '2px solid #f0f0f0', background: '#fafafa',
        display: 'flex', alignItems: 'center', gap: 12, borderRadius: '0 0 8px 8px',
      }}>
        <Typography.Text type="secondary" style={{ fontSize: 11, flex: 1 }}>
          Items without HSN Code are flagged — configure in Item Master before PO submission.
        </Typography.Text>
        <Button onClick={onCancel}>Cancel</Button>
        <Button type="primary" disabled={selCount === 0} onClick={handleLoad}>
          {selCount > 0 ? `Load ${selCount} Line${selCount !== 1 ? 's' : ''}` : 'Load Selected Lines'}
        </Button>
      </div>
    </Modal>
  )
}
