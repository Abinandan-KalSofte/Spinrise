import dayjs from 'dayjs'
import { erpTh, ERP_TD as TD } from '@/shared/styles/erpTable'
import { formatPoNo } from '../../types'
import type { POForeclosureLineDto } from '../../types'
import { lineKey } from '../../hooks/usePoForeclosure'

// ── PO Fore Closure grid (HTML #fc-grid) ─────────────────────────────────────
// 12 columns, exact order from the prototype. Column 7 "S.No." is VISIBLE
// (OA-02 — dual-purpose as @pordsno/@prsno server-side); columns 11-12
// (PR.No, PR. Date) are hidden at display:none but stay on every row object.
// Every cell is read-only — only the checkbox is interactive, and only in
// modify mode.
//
// Layout follows PrForeclosureGrid: the table fills the page width (100% with a
// minWidth floor) and Item Name absorbs the slack, rather than sizing to
// max-content and forcing a horizontal scroll. Rows zebra-stripe and a selected
// row carries a left accent bar.

const TH = erpTh({ zIndex: 10 })
const TD_C: React.CSSProperties = { ...TD, textAlign: 'center' }
const TD_R: React.CSSProperties = { ...TD, textAlign: 'right', fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums' }
const TD_HIDDEN: React.CSSProperties = { display: 'none' }

const fmt3 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 3, maximumFractionDigits: 3 })

// Item Name is left width-less so it takes the remaining width (PR pattern).
const COLS = [
  { key: 'chk',      label: null,               w: 36,        align: 'center' as const },
  { key: 'group',    label: 'PO. Group',        w: 80,        align: 'center' as const },
  { key: 'pono',     label: 'PO. No',           w: 90,        align: 'center' as const },
  { key: 'podate',   label: 'PO. Date',         w: 105,       align: 'center' as const },
  { key: 'slcode',   label: 'Supplier Id',      w: 85,        align: 'center' as const },
  { key: 'slname',   label: 'Supplier Name',    w: 180,       align: 'left'   as const },
  { key: 'sno',      label: 'S.No.',            w: 60,        align: 'center' as const },
  { key: 'itemcode', label: 'Item Id',          w: 95,        align: 'center' as const },
  { key: 'itemname', label: 'Item Name',        w: undefined, align: 'left'   as const },
  { key: 'bal',      label: 'Balance Quantity', w: 120,       align: 'right'  as const },
]

interface PoForeclosureGridProps {
  lines:       POForeclosureLineDto[]
  checkedKeys: Set<string>
  isModify:    boolean
  onToggleRow: (key: string, checked: boolean) => void
  onToggleAll: (checked: boolean) => void
}

export function PoForeclosureGrid({ lines, checkedKeys, isModify, onToggleRow, onToggleAll }: PoForeclosureGridProps) {
  const allChecked  = lines.length > 0 && lines.every((l) => checkedKeys.has(lineKey(l)))
  const someChecked = lines.some((l) => checkedKeys.has(lineKey(l))) && !allChecked

  // Footer totals — derived from the rows already on screen, no new data.
  const selectedCount   = lines.filter((l) => checkedKeys.has(lineKey(l))).length
  const totalBalance    = lines.reduce((s, l) => s + l.balanceQty, 0)
  const selectedBalance = lines.reduce((s, l) => checkedKeys.has(lineKey(l)) ? s + l.balanceQty : s, 0)

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
            {/* Lines load on Modify, so an empty grid in query mode means "not loaded
                yet", not "nothing to show" — say which. */}
            <span style={{ fontSize: 13, fontWeight: 600 }}>
              {isModify ? 'No open PO lines.' : 'Click Modify to load open PO lines.'}
            </span>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 900 }}>
            <thead>
              <tr>
                {COLS.map((col) => (
                  <th key={col.key} style={{ ...TH, width: col.w, textAlign: col.align }}>
                    {col.key === 'chk' ? (
                      <input
                        type="checkbox"
                        checked={allChecked}
                        ref={(el) => { if (el) el.indeterminate = someChecked }}
                        disabled={!isModify}
                        onChange={(e) => onToggleAll(e.target.checked)}
                        aria-label="Select all rows"
                        style={{ width: 15, height: 15, accentColor: '#185FA5', cursor: isModify ? 'pointer' : 'not-allowed' }}
                      />
                    ) : col.label}
                  </th>
                ))}
                <th style={TD_HIDDEN}>PR.No</th>
                <th style={TD_HIDDEN}>PR. Date</th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, idx) => {
                const key     = lineKey(line)
                const checked = checkedKeys.has(key)
                return (
                  <tr
                    key={key}
                    style={{
                      background: checked ? '#dbeafe' : idx % 2 === 1 ? '#f0f5ff' : '#fff',
                      borderLeft: checked ? '3px solid #185FA5' : '3px solid transparent',
                    }}
                  >
                    <td style={TD_C}>
                      <input
                        type="checkbox"
                        checked={checked}
                        disabled={!isModify}
                        onChange={(e) => onToggleRow(key, e.target.checked)}
                        aria-label={`Select line ${key}`}
                        style={{ width: 15, height: 15, accentColor: '#185FA5', cursor: isModify ? 'pointer' : 'not-allowed' }}
                      />
                    </td>
                    <td style={TD_C}>{line.group}</td>
                    <td style={TD_C}>{formatPoNo(line.poNo)}</td>
                    <td style={{ ...TD_C, fontFamily: 'monospace' }}>{dayjs(line.poDate).format('DD-MMM-YYYY')}</td>
                    <td style={TD_C}>{line.slCode}</td>
                    <td style={TD}>{line.supplierName}</td>
                    <td style={TD_C}>{line.sNo}</td>
                    <td style={TD_C}>{line.itemCode}</td>
                    <td style={{ ...TD, whiteSpace: 'normal', wordBreak: 'break-word', minWidth: 100 }}>{line.itemName}</td>
                    <td style={TD_R}>{fmt3(line.balanceQty)}</td>
                    <td style={TD_HIDDEN}>{line.prNo}</td>
                    <td style={TD_HIDDEN}>{line.prDate}</td>
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
          { label: 'Total Lines',      val: String(lines.length) },
          { label: 'Selected',         val: String(selectedCount) },
          { label: 'Total Balance',    val: fmt3(totalBalance) },
          { label: 'Selected Balance', val: fmt3(selectedBalance) },
        ].map(({ label, val }) => (
          <span key={label} style={{ fontSize: 11, color: '#4A4A4A', display: 'flex', alignItems: 'center', gap: 5 }}>
            {label}: <strong style={{ fontFamily: 'monospace', fontSize: 13, color: '#185FA5' }}>{val}</strong>
          </span>
        ))}
      </div>
    </div>
  )
}
