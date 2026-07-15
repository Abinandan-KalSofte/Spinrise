import { useEffect, useRef } from 'react'
import type { ElementRef } from 'react'
import { InputNumber, Select } from 'antd'
import { erpTh, ERP_TD as TD } from '@/shared/styles/erpTable'
import { formatPoNo } from '../../types'
import type { CancellationReason, PoCancellationLine, PoOpenSummary } from '../../types'
import type { FocusTarget } from '../../hooks/usePoCancellation'
import dayjs from 'dayjs'

// ── PO Cancellation grid (HTML #cancel-grid) ─────────────────────────────────
// 16 columns, exact order from the prototype, including 3 hidden columns
// (Slcode, ItemCode, S.No) kept in the DOM at display:none for structural
// parity — only Reason Id (select) and Cancel Quantity (input) are editable.
//
// Layout follows PrForeclosureGrid: the table fills the page width (100% with a
// minWidth floor) and Item Name absorbs the slack, rather than sizing to
// max-content and forcing a horizontal scroll. Rows zebra-stripe and a selected
// row carries a left accent bar. The Reason/Cancel Qty editors stay on AntD —
// they carry the inline validation errors.

const TH = erpTh({ zIndex: 10 })
const TD_C: React.CSSProperties = { ...TD, textAlign: 'center' }
const TD_R: React.CSSProperties = { ...TD, textAlign: 'right', fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums' }
const TD_HIDDEN: React.CSSProperties = { display: 'none' }

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const fmt3 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 3, maximumFractionDigits: 3 })
const fmt4 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 4, maximumFractionDigits: 4 })

interface PoCancellationGridProps {
  selectedPo:    PoOpenSummary
  lines:         PoCancellationLine[]
  reasons:       CancellationReason[]
  onToggleRow:   (sNo: number, checked: boolean) => void
  onToggleAll:   (checked: boolean) => void
  onReasonChange:(sNo: number, reasonCode: string) => void
  onQtyChange:   (sNo: number, value: number | null) => void
  onQtyBlur:     (sNo: number) => void
  focusRequest:  FocusTarget
  onFocusHandled:() => void
}

export function PoCancellationGrid({
  selectedPo, lines, reasons,
  onToggleRow, onToggleAll, onReasonChange, onQtyChange, onQtyBlur,
  focusRequest, onFocusHandled,
}: PoCancellationGridProps) {
  const qtyRefs    = useRef(new Map<number, ElementRef<typeof InputNumber> | null>())
  const reasonRefs = useRef(new Map<number, ElementRef<typeof Select> | null>())

  useEffect(() => {
    if (!focusRequest) return
    if (focusRequest.field === 'qty') qtyRefs.current.get(focusRequest.sNo)?.focus()
    else reasonRefs.current.get(focusRequest.sNo)?.focus()
    onFocusHandled()
  }, [focusRequest, onFocusHandled])

  const allChecked  = lines.length > 0 && lines.every((l) => l.checked)
  const someChecked = lines.some((l) => l.checked) && !allChecked
  const poDate      = dayjs(selectedPo.poDate).format('DD-MMM-YYYY')

  const reasonOptions = reasons.map((r) => ({ value: r.code, label: `${r.code} — ${r.name}` }))
  const reasonName = (code: string) => reasons.find((r) => r.code === code)?.name

  // Footer totals — derived from the rows already on screen, no new data.
  // Balance mirrors the placeholder shown in the Cancel Qty cell: OrderQty − ReceivedQty.
  const selectedCount    = lines.filter((l) => l.checked).length
  const totalBalance     = lines.reduce((s, l) => s + (l.orderQty - l.receivedQty), 0)
  const totalCancelQty   = lines.reduce((s, l) => l.checked ? s + (l.cancelQty ?? 0) : s, 0)

  return (
    // Grid rows "1fr auto": the table area takes exactly the height left over on the
    // page and the footer takes only what it needs. Grid (not flex) because a flex
    // child can refuse to shrink below its content, which lets the table overrun the
    // page and push the footer up over it. minHeight:0 lets the 1fr row shrink.
    <div style={{
      display: 'grid', gridTemplateRows: '1fr auto',
      flex: 1, minHeight: 0, overflow: 'hidden',
    }}>
      <div style={{ minHeight: 0, position: 'relative', overflow: 'hidden', background: '#fff' }}>
        {/* paddingBottom gives the last row breathing room at the end of the scroll. */}
        <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'auto', paddingBottom: 24 }}>
        {lines.length === 0 ? (
          <div style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
            padding: 40, gap: 8, color: '#888',
          }}>
            <span style={{ fontSize: 13, fontWeight: 600 }}>No open lines for this Purchase Order.</span>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 1200 }}>
            <thead>
              <tr>
                <th style={{ ...TH, width: 36, textAlign: 'center' }}>
                  <input
                    type="checkbox"
                    checked={allChecked}
                    ref={(el) => { if (el) el.indeterminate = someChecked }}
                    onChange={(e) => onToggleAll(e.target.checked)}
                    aria-label="Select all rows"
                    style={{ width: 15, height: 15, accentColor: '#185FA5', cursor: 'pointer' }}
                  />
                </th>
                <th style={{ ...TH, width: 90,  textAlign: 'center' }}>PO.No</th>
                <th style={{ ...TH, width: 105, textAlign: 'center' }}>PO Date</th>
                <th style={TD_HIDDEN}>Slcode</th>
                <th style={{ ...TH, width: 170, textAlign: 'left' }}>Supplier Name</th>
                <th style={TD_HIDDEN}>ItemCode</th>
                {/* Item Name left width-less so it takes the remaining width (PR pattern). */}
                <th style={{ ...TH, textAlign: 'left' }}>Item Name</th>
                <th style={{ ...TH, width: 55,  textAlign: 'center' }}>UOM</th>
                <th style={TD_HIDDEN}>S.No</th>
                <th style={{ ...TH, width: 100, textAlign: 'right' }}>Order Quantity</th>
                <th style={{ ...TH, width: 110, textAlign: 'right' }}>Received Quantity</th>
                <th style={{ ...TH, width: 90,  textAlign: 'right' }}>Rate</th>
                <th style={{ ...TH, width: 100, textAlign: 'right' }}>Value</th>
                <th style={{ ...TH, width: 150, textAlign: 'left'  }}>Reason Id</th>
                <th style={{ ...TH, width: 150, textAlign: 'left'  }}>Reason</th>
                <th style={{ ...TH, width: 120, textAlign: 'right' }}>Cancel Quantity</th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, idx) => {
                const balance = line.orderQty - line.receivedQty
                return (
                  <tr
                    key={line.sNo}
                    style={{
                      background: line.checked ? '#dbeafe' : idx % 2 === 1 ? '#f0f5ff' : '#fff',
                      borderLeft: line.checked ? '3px solid #185FA5' : '3px solid transparent',
                    }}
                  >
                    <td style={TD_C}>
                      <input
                        type="checkbox"
                        checked={line.checked}
                        onChange={(e) => onToggleRow(line.sNo, e.target.checked)}
                        aria-label={`Select line ${line.sNo}`}
                        style={{ width: 15, height: 15, accentColor: '#185FA5', cursor: 'pointer' }}
                      />
                    </td>
                    <td style={TD_C}>{formatPoNo(selectedPo.poNo)}</td>
                    <td style={{ ...TD_C, fontFamily: 'monospace' }}>{poDate}</td>
                    <td style={TD_HIDDEN}>{line.slCode}</td>
                    <td style={TD}>{selectedPo.supplierName}</td>
                    <td style={TD_HIDDEN}>{line.itemCode}</td>
                    <td style={{ ...TD, whiteSpace: 'normal', wordBreak: 'break-word', minWidth: 100 }}>{line.itemName}</td>
                    <td style={TD_C}>{line.uom}</td>
                    <td style={TD_HIDDEN}>{line.sNo}</td>
                    <td style={TD_R}>{fmt3(line.orderQty)}</td>
                    <td style={TD_R}>{fmt3(line.receivedQty)}</td>
                    <td style={TD_R}>{fmt4(line.rate)}</td>
                    <td style={TD_R}>{fmt2(line.value)}</td>
                    <td style={TD}>
                      <Select
                        ref={(el) => { reasonRefs.current.set(line.sNo, el) }}
                        size="small"
                        style={{ width: '100%' }}
                        placeholder="— select —"
                        options={reasonOptions}
                        value={line.reasonCode || undefined}
                        status={line.reasonError ? 'error' : undefined}
                        onChange={(v) => onReasonChange(line.sNo, v)}
                      />
                      {line.reasonError && (
                        <div style={{ fontSize: 9, color: '#A32D2D', fontWeight: 600, marginTop: 2 }}>{line.reasonError}</div>
                      )}
                    </td>
                    <td style={TD}>{line.reasonCode ? (reasonName(line.reasonCode) ?? '—') : <span style={{ color: '#888' }}>—</span>}</td>
                    <td style={TD}>
                      <InputNumber
                        ref={(el) => { qtyRefs.current.set(line.sNo, el) }}
                        size="small"
                        min={0}
                        precision={3}
                        controls={false}
                        style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
                        placeholder={`≤ ${fmt3(balance)}`}
                        value={line.cancelQty}
                        status={line.qtyError ? 'error' : undefined}
                        onChange={(v) => onQtyChange(line.sNo, v)}
                        onBlur={() => onQtyBlur(line.sNo)}
                      />
                      {line.qtyError && (
                        <div style={{ fontSize: 9, color: '#A32D2D', fontWeight: 600, marginTop: 2 }}>{line.qtyError}</div>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
        </div>
      </div>

      {/* ── Footer strip ───────────────────────────────────────────────────── */}
      <div style={{
        background: '#FAFAF8', borderTop: '2px solid #185FA5',
        padding: '7px 16px', display: 'flex', alignItems: 'center', gap: 20, flexShrink: 0,
      }}>
        {[
          { label: 'Total Lines',    val: String(lines.length) },
          { label: 'Selected',       val: String(selectedCount) },
          { label: 'Total Balance',  val: fmt3(totalBalance) },
          { label: 'Cancel Quantity', val: fmt3(totalCancelQty) },
        ].map(({ label, val }) => (
          <span key={label} style={{ fontSize: 11, color: '#4A4A4A', display: 'flex', alignItems: 'center', gap: 5 }}>
            {label}: <strong style={{ fontFamily: 'monospace', fontSize: 13, color: '#185FA5' }}>{val}</strong>
          </span>
        ))}
      </div>
    </div>
  )
}
