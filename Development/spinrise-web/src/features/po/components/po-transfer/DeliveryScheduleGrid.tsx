import { Button, DatePicker, Input, InputNumber } from 'antd'
import { PlusOutlined, CloseOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import { erpTh, ERP_TD as TD } from '@/shared/styles/erpTable'
import { type DeliveryScheduleLine, type ScreenMode } from '../../types'

// ── Delivery Schedule (HTML #ds-table — VB6 childgrd / PO_ORDL_DETL) ─────────
// OQ-NEW Option B (approved): item-wise OPEN child grid — UNLIMITED delivery
// rows per PO line (retired 4-slot model removed). Reconciliation is on
// QUANTITY, not value (UX-01); each row keeps its own item UOM (UX-02).
// Editable in ADD; read-only in VIEW/DELETE.
//
// Columns (11):
//   # | Item Id | Item Name | PR No. | UOM | PO Qty | Slot | Scheduled Qty | Balance Qty | Delivery Date | Remarks
//   PO Qty      = d.poQty (total PO line quantity, rowspan)
//   Scheduled Qty = slot.qty (quantity for this specific delivery slot, editable)
//   Balance Qty = PO Qty − Σ Scheduled Qty across all slots (rowspan, colour-coded)

const TH = erpTh({ zIndex: 10 })
const fmt3 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 3, maximumFractionDigits: 3 })
const round3 = (n: number) => Math.round(n * 1000) / 1000

const scheduled = (d: DeliveryScheduleLine) =>
  round3(d.slots.reduce((s, x) => s + (Number(x.qty) || 0), 0))

interface DeliveryScheduleGridProps {
  mode:          ScreenMode
  deliveryLines: DeliveryScheduleLine[]
  onAddSlot:     (lineNo: number) => void
  onUpdateSlot:  (lineNo: number, slotNo: number, patch: { shDate?: string | null; qty?: number; remarks?: string }) => void
  onRemoveSlot:  (lineNo: number, slotNo: number) => void
}

export function DeliveryScheduleGrid({
  mode, deliveryLines, onAddSlot, onUpdateSlot, onRemoveSlot,
}: DeliveryScheduleGridProps) {
  const ro = mode !== 'ADD'

  const schedTotal = round3(deliveryLines.reduce((s, d) => s + scheduled(d), 0))
  const poTotal    = round3(deliveryLines.reduce((s, d) => s + (d.poQty || 0), 0))
  const matched    = Math.abs(schedTotal - poTotal) < 0.001

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0, background: '#fff', overflow: 'hidden' }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8, padding: '6px 16px',
        borderBottom: '1px solid #e2e2e2', background: '#fafaf8', flexShrink: 0,
      }}>
        <span style={{ fontSize: 12, fontWeight: 600, color: '#4a4a4a' }}>Delivery Schedule</span>
        <span style={{ fontSize: 11, fontWeight: 700, padding: '1px 8px', borderRadius: 20, background: '#E6F1FB', color: '#185FA5' }}>
          {deliveryLines.length} Item{deliveryLines.length !== 1 ? 's' : ''}
        </span>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 11, color: '#888' }}>
          Add unlimited delivery rows per item · Σ Scheduled Qty must equal PO Qty per item
        </span>
      </div>

      <div style={{ flex: 1, minHeight: 0, overflow: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ position: 'sticky', top: 0, zIndex: 10 }}>
            <tr>
              <th style={{ ...TH, width: 30,  textAlign: 'center' }}>#</th>
              <th style={{ ...TH, width: 78,  textAlign: 'center' }}>Item Id</th>
              <th style={{ ...TH, width: 180, textAlign: 'left' }}>Item Name</th>
              <th style={{ ...TH, width: 90 }}>PR No.</th>
              <th style={{ ...TH, width: 46,  textAlign: 'center' }}>UOM</th>
              <th style={{ ...TH, width: 100, textAlign: 'right'  }}>PO Qty</th>
              <th style={{ ...TH, width: 44,  textAlign: 'center' }}>Slot</th>
              <th style={{ ...TH, width: 120, textAlign: 'right'  }}>Scheduled Qty</th>
              <th style={{ ...TH, width: 100, textAlign: 'right'  }}>Balance Qty</th>
              <th style={{ ...TH, width: 150 }}>Delivery Date</th>
              <th style={{ ...TH }}>Remarks</th>
            </tr>
          </thead>
          <tbody>
            {deliveryLines.length === 0 ? (
              <tr>
                <td colSpan={11} style={{ textAlign: 'center', padding: 20, color: '#888', fontSize: 12 }}>
                  No items to schedule. Add PR lines first.
                </td>
              </tr>
            ) : (
              deliveryLines.map((d, idx) => {
                const bal      = round3(d.poQty - scheduled(d))
                const balColor = bal === 0 ? '#3B6D11' : bal < 0 ? '#A32D2D' : '#BA7517'
                const n        = d.slots.length
                return d.slots.map((slot, si) => (
                  <tr key={`${d.lineNo}-${slot.slotNo}`} style={{ borderBottom: '1px solid #f0f0f0' }}>
                    {si === 0 && <>
                      {/* Columns 1–6: item-level data (rowspan across all slots) */}
                      <td rowSpan={n} style={{ ...TD, textAlign: 'center', color: '#888', fontSize: 11 }}>{idx + 1}</td>
                      <td rowSpan={n} style={{ ...TD, textAlign: 'center', fontFamily: 'monospace', fontWeight: 600, color: '#185FA5', fontSize: 11 }}>{d.itemCode}</td>
                      <td rowSpan={n} style={{ ...TD, fontSize: 11 }}>{d.itemName}</td>
                      <td rowSpan={n} style={{ ...TD, fontFamily: 'monospace', fontSize: 11,  textAlign: 'center' }}>{d.prNo}</td>
                      <td rowSpan={n} style={{ ...TD, textAlign: 'center', fontSize: 11, color: '#4a4a4a' }}>{d.uom}</td>
                      {/* PO Qty — total purchase order quantity for this line */}
                      <td rowSpan={n} style={{ ...TD, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, fontWeight: 600, color: '#1a1a1a' }}>
                        {fmt3(d.poQty)}
                      </td>
                    </>}

                    {/* Column 7: Slot number + remove button */}
                    <td style={{ ...TD, textAlign: 'center', fontSize: 11, color: '#888' }}>
                      {slot.slotNo}
                      {!ro && n > 1 && (
                        <CloseOutlined
                          onClick={() => onRemoveSlot(d.lineNo, slot.slotNo)}
                          style={{ marginLeft: 4, color: '#A32D2D', cursor: 'pointer', fontSize: 10 }}
                        />
                      )}
                    </td>

                    {/* Column 8: Scheduled Qty — quantity for this specific delivery slot */}
                    <td style={{ ...TD, textAlign: 'right' }}>
                      <InputNumber
                        size="small" min={0} precision={3} controls={false} disabled={ro}
                        value={slot.qty}
                        style={{ width: '100%', fontFamily: 'monospace', textAlign: 'right' }}
                        onChange={(v) => onUpdateSlot(d.lineNo, slot.slotNo, { qty: v ?? 0 })}
                      />
                    </td>

                    {/* Column 9: Balance Qty = PO Qty − Σ Scheduled Qty (rowspan, colour-coded) */}
                    {si === 0 && (
                      <td rowSpan={n} style={{ ...TD, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, fontWeight: 600, color: balColor }}>
                        {fmt3(bal)}
                      </td>
                    )}

                    {/* Column 10: Delivery Date */}
                    <td style={TD}>
                      <DatePicker
                        size="small" disabled={ro} format="DD-MMM-YYYY"
                        value={slot.shDate ? dayjs(slot.shDate) : null}
                        style={{ width: '100%' }}
                        onChange={(dt) => onUpdateSlot(d.lineNo, slot.slotNo, { shDate: dt ? dt.format('YYYY-MM-DD') : null })}
                      />
                    </td>

                    {/* Column 11: Remarks */}
                    <td style={TD}>
                      <Input
                        size="small" disabled={ro} value={slot.remarks} placeholder="Remarks"
                        style={{ fontSize: 11 }}
                        onChange={(e) => onUpdateSlot(d.lineNo, slot.slotNo, { remarks: e.target.value })}
                      />
                    </td>
                  </tr>
                )).concat(
                  !ro ? [(
                    <tr key={`${d.lineNo}-add`}>
                      <td colSpan={11} style={{ ...TD, padding: '3px 8px 5px 12px' }}>
                        <Button size="small" type="dashed" icon={<PlusOutlined />}
                          onClick={() => onAddSlot(d.lineNo)} style={{ fontSize: 11, height: 22 }}>
                          Add delivery row
                        </Button>
                      </td>
                    </tr>
                  )] : [],
                )
              })
            )}
          </tbody>
          {deliveryLines.length > 0 && (
            <tfoot>
              <tr style={{ background: '#fafaf8', fontWeight: 700 }}>
                {/* Cols 1–5: label */}
                <td colSpan={5} style={{ ...TD, textAlign: 'right', fontSize: 11, color: '#4a4a4a' }}>
                  Σ Totals
                </td>
                {/* Col 6: Σ PO Qty */}
                <td style={{ ...TD, textAlign: 'right', fontFamily: 'monospace', fontSize: 12 }}>
                  {fmt3(poTotal)}
                </td>
                {/* Col 7: Slot — empty */}
                <td style={TD} />
                {/* Col 8: Σ Scheduled Qty */}
                <td style={{ ...TD, textAlign: 'right', fontFamily: 'monospace', fontSize: 12 }}>
                  {fmt3(schedTotal)}
                </td>
                {/* Cols 9–11: reconciliation indicator */}
                <td colSpan={3} style={{ ...TD, fontSize: 11 }}>
                  <span style={{
                    fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 20,
                    background: matched ? '#EAF3DE' : '#FAEEDA',
                    color:      matched ? '#3B6D11' : '#BA7517',
                  }}>
                    {matched
                      ? `Reconciled · PO: ${fmt3(poTotal)} = Sched: ${fmt3(schedTotal)}`
                      : `Mismatch · PO: ${fmt3(poTotal)} ≠ Sched: ${fmt3(schedTotal)}`}
                  </span>
                </td>
              </tr>
            </tfoot>
          )}
        </table>
      </div>
    </div>
  )
}
