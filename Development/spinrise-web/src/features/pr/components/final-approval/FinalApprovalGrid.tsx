import { useCallback } from 'react'
import { Checkbox, InputNumber, Modal, Select } from 'antd'
import {
  useFinalApprovalStore,
} from '../../store/useFinalApprovalStore'
import type { DispositionCode } from '../../types/finalApprovalTypes'
import { DISPOSITION_LABELS } from '../../types/finalApprovalTypes'
import { erpTh, erpTd } from '@/shared/styles/erpTable'

// ── Style helpers ─────────────────────────────────────────────────────────────

const TH = (extra?: React.CSSProperties): React.CSSProperties =>
  erpTh({ borderRight: '1px solid rgba(255,255,255,.07)', ...extra })

const TD = (extra?: React.CSSProperties): React.CSSProperties =>
  erpTd({ padding: '2px 6px', height: 32, ...extra })

const ROW_COLORS: Record<string, string> = {
  first:  '#FFFFAA',
  second: '#FFD400',
  final:  '#7FFF00',
}

const DISPOSITION_OPTIONS = ([1, 2, 3, 4, 5] as DispositionCode[]).map((v) => ({
  value: v,
  label: DISPOSITION_LABELS[v],
}))

function numFmt(v: number | null | undefined, dp: number): string {
  if (v === null || v === undefined) return '—'
  return v.toLocaleString('en-IN', { minimumFractionDigits: dp, maximumFractionDigits: dp })
}

// ── Main component ────────────────────────────────────────────────────────────

export default function FinalApprovalGrid() {
  const { lines, approvalLabels, updateQty, updateDisposition, toggleRow, toggleAll } = useFinalApprovalStore()

  const selectableLines = lines.filter((l) => l.disposition !== 1)
  const allSelected     = selectableLines.length > 0 && selectableLines.every((l) => l.selected)
  const someSelected    = selectableLines.some((l) => l.selected)

  const handleQtyChange = useCallback((idx: number, val: number | null) => {
    const line = lines[idx]
    if (val === null || val <= 0) {
      Modal.warning({
        title:   'Quantity Validation',
        content: 'Approved quantity must be greater than zero. Value reset to 1.',
      })
      updateQty(idx, 1)
      return
    }
    if (val > line.qtyRequired) {
      Modal.warning({
        title:   'Quantity Validation',
        content: `Approved quantity (${val.toFixed(3)}) cannot exceed Required Quantity (${line.qtyRequired.toFixed(3)}). Value reset.`,
      })
      updateQty(idx, line.qtyRequired)
      return
    }
    updateQty(idx, parseFloat(val.toFixed(3)))
  }, [lines, updateQty])

  const handleDispositionChange = useCallback((idx: number, code: DispositionCode) => {
    updateDisposition(idx, code)
  }, [updateDisposition])

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

      {/* Legend strip */}
      <div style={{
        display: 'flex', gap: 16, padding: '4px 16px',
        background: '#FAFAF8', borderBottom: '1px solid #f0f0f0',
        fontSize: 11, alignItems: 'center', flexShrink: 0,
      }}>
        {(['first', 'second', 'final'] as const).map((s) => (
          <span key={s} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            <span style={{
              width: 10, height: 10, borderRadius: 2, display: 'inline-block',
              background: ROW_COLORS[s], border: '1px solid #ccc',
            }} />
            <span style={{ color: '#555' }}>
              {s === 'first' ? approvalLabels.appUserLabel1 : s === 'second' ? approvalLabels.appUserLabel2 : approvalLabels.appUserLabel3}
            </span>
          </span>
        ))}
        {someSelected && (
          <span style={{ marginLeft: 'auto', fontSize: 11, color: '#185FA5', fontWeight: 600 }}>
            {selectableLines.filter((l) => l.selected).length} selected
          </span>
        )}
      </div>

      {/* Scrollable grid */}
      <div style={{ flex: 1, minHeight: 0, overflowX: 'auto', overflowY: 'auto' }}>
        <table style={{ borderCollapse: 'collapse', fontSize: 12, width: 'max-content', minWidth: '100%' }}>
          <thead>
            <tr>
              <th style={TH({ width: 36, textAlign: 'center' })}>
                <Checkbox
                  checked={allSelected}
                  indeterminate={someSelected && !allSelected}
                  onChange={(e) => toggleAll(e.target.checked)}
                />
              </th>
              <th style={TH({ width: 40 })}>Div</th>
              <th style={TH({ width: 62, textAlign: 'right' })}>PR No.</th>
              <th style={TH({ width: 84 })}>PR Date</th>
              <th style={TH({ width: 100 })}>Department</th>
              <th style={TH({ minWidth: 160 })}>Item Name</th>
              <th style={TH({ width: 40, textAlign: 'center' })}>Unit</th>
              <th style={TH({ width: 74, textAlign: 'right' })}>Stock</th>
              <th style={TH({ width: 80, textAlign: 'right' })}>Qty Required</th>
              <th style={TH({ width: 90, textAlign: 'right' })}>Qty Approved</th>
              <th style={TH({ width: 112 })}>Disposition</th>
              <th style={TH({ width: 74, textAlign: 'right' })}>LPO Rate</th>
              <th style={TH({ width: 80 })}>LPO Date</th>
              <th style={TH({ width: 86, textAlign: 'right' })}>Approx. Value</th>
            </tr>
          </thead>
          <tbody>
            {lines.length === 0 && (
              <tr>
                <td colSpan={14} style={{ textAlign: 'center', padding: '32px', color: '#888', fontSize: 12 }}>
                  No pending PR lines found.
                </td>
              </tr>
            )}
            {lines.map((line, idx) => {
              const rowBg    = ROW_COLORS[line.approvalStatus] ?? '#fff'
              const disabled = line.disposition === 1

              return (
                <tr
                  key={`${line.divCode}-${line.prNo}-${line.prSno}`}
                  style={{ background: rowBg }}
                >
                  {/* Checkbox */}
                  <td style={TD({ width: 36, textAlign: 'center' })}>
                    <Checkbox
                      checked={line.selected}
                      disabled={disabled}
                      onChange={(e) => toggleRow(idx, e.target.checked)}
                    />
                  </td>

                  {/* Div */}
                  <td style={TD({ width: 40, fontSize: 11, color: '#555' })}>{line.divCode}</td>

                  {/* PR No */}
                  <td style={TD({ width: 62, textAlign: 'right', fontFamily: 'monospace', fontWeight: 700 })}>
                    {line.prNo}
                  </td>

                  {/* PR Date */}
                  <td style={TD({ width: 84, fontSize: 11 })}>{line.prDate}</td>

                  {/* Department */}
                  <td style={TD({ width: 100, fontSize: 11 })}>{line.department}</td>

                  {/* Item Name */}
                  <td style={TD({ minWidth: 160 })}>{line.itemName}</td>

                  {/* Unit */}
                  <td style={TD({ width: 40, textAlign: 'center', fontSize: 11, color: '#555' })}>{line.uom}</td>

                  {/* Current Stock */}
                  <td style={TD({ width: 74, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#666' })}>
                    {numFmt(line.currentStock, 3)}
                  </td>

                  {/* Qty Required */}
                  <td style={TD({ width: 80, textAlign: 'right', fontFamily: 'monospace', fontSize: 11 })}>
                    {numFmt(line.qtyRequired, 3)}
                  </td>

                  {/* Qty Approved — editable */}
                  <td style={TD({ width: 90 })}>
                    <InputNumber
                      size="small"
                      value={line.qtyApproved}
                      min={0.001}
                      max={line.qtyRequired}
                      precision={3}
                      style={{ width: '100%', height: 26 }}
                      onBlur={(e) => {
                        const val = parseFloat(e.target.value.replace(/,/g, ''))
                        handleQtyChange(idx, isNaN(val) ? null : val)
                      }}
                      onChange={(v) => {
                        if (v !== null && v > 0 && v <= line.qtyRequired)
                          updateQty(idx, parseFloat(v.toFixed(3)))
                      }}
                    />
                  </td>

                  {/* Disposition — editable */}
                  <td style={TD({ width: 112 })}>
                    <Select
                      size="small"
                      value={line.disposition}
                      options={DISPOSITION_OPTIONS}
                      style={{ width: '100%' }}
                      onChange={(v) => handleDispositionChange(idx, v as DispositionCode)}
                    />
                  </td>

                  {/* LPO Rate */}
                  <td style={TD({ width: 74, textAlign: 'right', fontFamily: 'monospace', fontSize: 11 })}>
                    {numFmt(line.lpoRate, 4)}
                  </td>

                  {/* LPO Date */}
                  <td style={TD({ width: 80, fontSize: 11, color: line.lpoDate ? '#333' : '#ccc' })}>
                    {line.lpoDate ?? '—'}
                  </td>

                  {/* Approx. Value */}
                  <td style={TD({ width: 86, textAlign: 'right', fontFamily: 'monospace', fontSize: 11 })}>
                    {line.approxCost != null ? numFmt(line.approxCost, 2) : '—'}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
