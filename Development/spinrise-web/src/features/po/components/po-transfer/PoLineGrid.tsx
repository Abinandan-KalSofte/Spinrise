import { memo } from 'react'
import { Button, Input, InputNumber, Tooltip } from 'antd'
import { DeleteOutlined } from '@ant-design/icons'
import { erpTh, ERP_TD as TD } from '@/shared/styles/erpTable'
import type { PoLine, ScreenMode } from '../../types'

// ── PO Line Item grid (HTML #po-grid / .po-table) ────────────────────────────
//
// 22 SPINRISE columns (PO_ORDL subset, MD §10) + Delete Reason (DELETE only).
// Pre-GST excise/cess/surcharge columns (D-11) are intentionally absent.
// Controlled: Rate/Qty edit + GST cell click are emitted upward; the page owns
// the GST modal and the hook owns recompute/validation. Route is server-driven
// (line.route, Q4) — the grid only renders the resulting CGST/SGST vs IGST split.

const TH = erpTh({ zIndex: 10 })
const TD_TXT = { ...TD, fontSize: 11, color: '#1e293b' } as React.CSSProperties

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const fmt3 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 3, maximumFractionDigits: 3 })
const fmt4 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 4, maximumFractionDigits: 4 })

interface PoLineGridProps {
  mode:                 ScreenMode
  lines:                PoLine[]
  selectedLineNo:       number | null
  onSelectLine:         (lineNo: number) => void
  onUpdateRateQty:      (lineNo: number, patch: { rate?: number; qty?: number }) => void
  onOpenGst:            (lineNo: number) => void
  onRemoveLine:         (lineNo: number) => void
  onDeleteReasonChange: (lineNo: number, reason: string) => void
  emptyText?:           string
}

const numTd = (w: number): React.CSSProperties => ({
  ...TD_TXT, width: w, textAlign: 'right', fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums',
})

const Row = memo(function Row({
  line, idx, mode, selected, onSelect, onRateQty, onOpenGst, onRemove, onReason,
}: {
  line:      PoLine
  idx:       number
  mode:      ScreenMode
  selected:  boolean
  onSelect:  () => void
  onRateQty: (patch: { rate?: number; qty?: number }) => void
  onOpenGst: () => void
  onRemove:  () => void
  onReason:  (reason: string) => void
}) {
  const isAdd    = mode === 'ADD'
  const isDelete = mode === 'DELETE'
  const hsnBlank = !line.hsnCode.trim()

  return (
    <tr
      onClick={onSelect}
      style={{
        background: selected ? '#EBF3FF' : isDelete ? '#fff7f7' : idx % 2 === 0 ? '#ffffff' : '#F0F5FF',
        cursor: 'pointer',
      }}
    >
      <td style={{ ...TD_TXT, width: 78, textAlign: 'center', fontFamily: 'monospace', fontWeight: 600, color: '#185FA5' }}>
        {line.itemCode || '—'}
      </td>
      <td style={{ ...TD_TXT, width: 190, fontWeight: 500 }}>{line.itemName || line.itemCode}</td>
      <td style={{ ...TD_TXT, width: 44, textAlign: 'center', color: '#4a4a4a' }}>{line.uom}</td>
      <td style={{ ...TD_TXT, width: 100, fontFamily: 'monospace' }}>{line.prNo}</td>
      <td style={{ ...TD_TXT, width: 80, fontFamily: 'monospace' }}>{line.prDate || '—'}</td>

      {/* Rate — editable in ADD (4dp, BR-07) */}
      <td style={{ ...TD_TXT, width: 88, textAlign: 'right' }} onClick={(e) => isAdd && e.stopPropagation()}>
        {isAdd ? (
          <InputNumber
            size="small" min={0} precision={4} controls={false} value={line.rate}
            style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
            status={line.rate <= 0 ? 'error' : undefined}
            onChange={(v) => onRateQty({ rate: v ?? 0 })}
          />
        ) : (
          <span style={{ fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums' }}>{fmt4(line.rate)}</span>
        )}
      </td>

      {/* Quantity — editable in ADD (3dp, BR-05/06) */}
      <td style={{ ...TD_TXT, width: 82, textAlign: 'right' }} onClick={(e) => isAdd && e.stopPropagation()}>
        {isAdd ? (
          <Tooltip
            title={line.qty > line.balanceQty ? `Exceeds PR balance (${fmt3(line.balanceQty)})` : ''}
            open={line.qty > line.balanceQty}
            color="#ff4d4f"
          >
            <InputNumber
              size="small" min={0} precision={3} controls={false} value={line.qty}
              style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
              status={line.qty <= 0 || line.qty > line.balanceQty ? 'error' : undefined}
              onChange={(v) => onRateQty({ qty: v ?? 0 })}
            />
          </Tooltip>
        ) : (
          <span style={{ fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums' }}>{fmt3(line.qty)}</span>
        )}
      </td>

      <td style={numTd(96)}>{fmt2(line.value)}</td>

      {/* Tax Code — opens GST & Tax modal (HTML "Click GST to enter tax details") */}
      <td style={{ ...TD_TXT, width: 80, textAlign: 'center' }} onClick={(e) => { e.stopPropagation(); onOpenGst() }}>
        <span style={{
          fontFamily: 'monospace', fontWeight: 600, color: '#185FA5',
          cursor: 'pointer', textDecoration: 'underline dotted', textUnderlineOffset: 2,
        }}>
          {line.taxCode || '— set —'}
        </span>
      </td>
      <td style={numTd(60)}>{fmt2(line.taxPer)}%</td>
      <td style={numTd(80)}>{fmt2(line.taxAmt)}</td>

      {/* HSN — BR-10 warn when blank */}
      <td style={{ ...TD_TXT, width: 80, textAlign: 'center' }}>
        {hsnBlank
          ? <Tooltip title="HSN Code missing — required before save"><span style={{ color: '#BA7517', fontWeight: 700 }}>⚠</span></Tooltip>
          : <span style={{ fontFamily: 'monospace' }}>{line.hsnCode}</span>}
      </td>

      <td style={numTd(60)}>{fmt2(line.cgstPer)}%</td>
      <td style={numTd(80)}>{fmt2(line.cgstAmt)}</td>
      <td style={numTd(60)}>{fmt2(line.sgstPer)}%</td>
      <td style={numTd(80)}>{fmt2(line.sgstAmt)}</td>
      <td style={numTd(60)}>{fmt2(line.igstPer)}%</td>
      <td style={numTd(80)}>{fmt2(line.igstAmt)}</td>
      <td style={numTd(60)}>{fmt2(line.tcsPer)}%</td>
      <td style={numTd(80)}>{fmt2(line.tcsAmt)}</td>

      <td style={{ ...TD_TXT, width: 90, fontFamily: 'monospace' }}>{line.requesterId || '—'}</td>
      <td style={{ ...TD_TXT, width: 120 }}>{line.requesterName || '—'}</td>

      {/* Delete Reason — DELETE mode only (BR-04) */}
      {isDelete && (
        <td style={{ ...TD, minWidth: 160 }} onClick={(e) => e.stopPropagation()}>
          <Input
            size="small" value={line.deleteReason} placeholder="Delete reason…"
            status={!line.deleteReason.trim() ? 'error' : undefined}
            onChange={(e) => onReason(e.target.value)}
          />
        </td>
      )}

      {/* Remove line — ADD mode only.
          Mockup variance: the approved HTML grid has no per-row delete. Picked
          PR lines must be removable before save, so this ADD-only action column
          is a functional requirement (store-backed removeDraftLine), consistent
          with the app's PRLineItemsTable. Hidden in VIEW/DELETE. (Decision 1) */}
      {isAdd && (
        <td style={{ ...TD, width: 40, textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
          <Tooltip title="Remove line" mouseEnterDelay={0.5}>
            <Button tabIndex={-1} type="text" size="small" danger
              icon={<DeleteOutlined style={{ fontSize: 12 }} />} onClick={onRemove} />
          </Tooltip>
        </td>
      )}
    </tr>
  )
})

export function PoLineGrid({
  mode, lines, selectedLineNo, onSelectLine, onUpdateRateQty,
  onOpenGst, onRemoveLine, onDeleteReasonChange, emptyText,
}: PoLineGridProps) {
  const isAdd    = mode === 'ADD'
  const isDelete = mode === 'DELETE'
  const baseCols = 22
  const colSpan  = baseCols + (isDelete ? 1 : 0) + (isAdd ? 1 : 0)

  return (
    <div style={{
      display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0,
      background: '#fff', overflow: 'hidden',
    }}>
      {/* Grid bar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8, padding: '6px 16px',
        borderBottom: '1px solid #e2e2e2', background: '#fafaf8', flexShrink: 0,
      }}>
        <span style={{ fontSize: 12, fontWeight: 600, color: '#4a4a4a' }}>Line Items</span>
        <span style={{ fontSize: 11, fontWeight: 700, padding: '1px 8px', borderRadius: 20, background: '#E6F1FB', color: '#185FA5' }}>
          {lines.length}
        </span>
        <span style={{ flex: 1 }} />
        {isAdd && <span style={{ fontSize: 11, color: '#888' }}>Edit Rate / Quantity inline · click Tax Code to enter GST &amp; tax</span>}
        {isDelete && <span style={{ fontSize: 11, color: '#A32D2D', fontWeight: 600 }}>Enter Delete Reason — auto-filled from the header reason</span>}
      </div>

      {/* Scroll area (wide grid scrolls horizontally) */}
      <div style={{ flex: 1, minHeight: 0, overflow: 'auto' }}>
        <table style={{ borderCollapse: 'collapse', width: 'max-content', minWidth: '100%' }}>
          <thead style={{ position: 'sticky', top: 0, zIndex: 10 }}>
            <tr>
              <th style={{ ...TH, width: 78, textAlign: 'center' }}>Item Id</th>
              <th style={{ ...TH, width: 190 }}>Item Name</th>
              <th style={{ ...TH, width: 44, textAlign: 'center' }}>UOM</th>
              <th style={{ ...TH, width: 100 }}>PR No</th>
              <th style={{ ...TH, width: 80 }}>PR Date</th>
              <th style={{ ...TH, width: 88, textAlign: 'right' }}>Rate</th>
              <th style={{ ...TH, width: 82, textAlign: 'right' }}>Quantity</th>
              <th style={{ ...TH, width: 96, textAlign: 'right' }}>Value</th>
              <th style={{ ...TH, width: 80, textAlign: 'center' }}>Tax Code</th>
              <th style={{ ...TH, width: 60, textAlign: 'right' }}>Tax %</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>Tax Amount</th>
              <th style={{ ...TH, width: 80, textAlign: 'center' }}>HSN Code</th>
              <th style={{ ...TH, width: 60, textAlign: 'right' }}>CGST %</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>CGST Amount</th>
              <th style={{ ...TH, width: 60, textAlign: 'right' }}>SGST %</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>SGST Amount</th>
              <th style={{ ...TH, width: 60, textAlign: 'right' }}>IGST %</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>IGST Amount</th>
              <th style={{ ...TH, width: 60, textAlign: 'right' }}>TCS %</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>TCS Amount</th>
              <th style={{ ...TH, width: 90 }}>Requester ID</th>
              <th style={{ ...TH, width: 120 }}>Requester Name</th>
              {isDelete && <th style={{ ...TH, minWidth: 160 }}>Delete Reason</th>}
              {isAdd && <th style={{ ...TH, width: 40 }} />}
            </tr>
          </thead>
          <tbody>
            {lines.length === 0 ? (
              <tr>
                <td colSpan={colSpan} style={{ textAlign: 'center', padding: 24, color: '#888', fontSize: 12 }}>
                  {emptyText ?? (isAdd ? 'No line items. Click Browse PR Lines to add items.' : 'No line items.')}
                </td>
              </tr>
            ) : (
              lines.map((line, idx) => (
                <Row
                  key={line.lineNo}
                  line={line} idx={idx} mode={mode}
                  selected={selectedLineNo === line.lineNo}
                  onSelect={() => onSelectLine(line.lineNo)}
                  onRateQty={(patch) => onUpdateRateQty(line.lineNo, patch)}
                  onOpenGst={() => onOpenGst(line.lineNo)}
                  onRemove={() => onRemoveLine(line.lineNo)}
                  onReason={(reason) => onDeleteReasonChange(line.lineNo, reason)}
                />
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
