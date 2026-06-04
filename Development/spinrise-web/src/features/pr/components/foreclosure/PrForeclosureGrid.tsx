import { useEffect, useState } from 'react'
import { Spin } from 'antd'
import { TbBtn, TbSep } from '../pr-form/PRToolbar'
import { usePrForeclosure } from '../../hooks/usePrForeclosure'
import type { PrForeclosureLineDto } from '../../types'
import PrViewModal from './PrViewModal'

// ── Status badge — keys match the readable labels returned by ksp_PR_GetOpenForForeclosure
const STATUS_BADGE: Record<string, { color: string; bg: string; border: string }> = {
  'Requested':       { color: '#185FA5', bg: '#E6F1FB', border: '#bfdbfe' },
  'First Approved':  { color: '#166534', bg: '#dcfce7', border: '#86efac' },
  'Enquired':        { color: '#185FA5', bg: '#E6F1FB', border: '#bfdbfe' },
  'Ordered':         { color: '#7c3aed', bg: '#f3e8ff', border: '#ddd6fe' },
  'Order Cancelled': { color: '#A32D2D', bg: '#FCEBEB', border: '#fca5a5' },
  'Received':        { color: '#3B6D11', bg: '#EAF3DE', border: '#86efac' },
  'Cancelled':       { color: '#A32D2D', bg: '#FCEBEB', border: '#fca5a5' },
  'Force Closed':    { color: '#888',    bg: '#f0f0f0', border: '#d0d0d0' },
}

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_BADGE[status] ?? STATUS_BADGE['Requested']
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 10,
      color: cfg.color, background: cfg.bg, border: `1px solid ${cfg.border}`,
      whiteSpace: 'nowrap',
    }}>
      {status || 'Requested'}
    </span>
  )
}

// ── Column headers ─────────────────────────────────────────────────────────────
const COLS = [
  { key: 'chk',    label: null,             w: 36,        align: 'center' as const },
  { key: 'idx',    label: '#',              w: 32,        align: 'left'   as const },
  { key: 'prno',   label: 'PR No',          w: 88,        align: 'left'   as const },
  { key: 'prdate', label: 'PR Date',        w: 100,       align: 'left'   as const },
  { key: 'dept',   label: 'Department',     w: 160,       align: 'left'   as const },
  { key: 'code',   label: 'Item Id',        w: 86,        align: 'left'   as const },
  { key: 'name',   label: 'Item Name',      w: undefined, align: 'left'   as const },
  { key: 'uom',    label: 'Unit',           w: 55,        align: 'center' as const },
  { key: 'qty',    label: 'Quantity',       w: 88,        align: 'right'  as const },
  { key: 'ord',    label: 'Ordered',        w: 88,        align: 'right'  as const },
  { key: 'bal',    label: 'Balance',        w: 88,        align: 'right'  as const },
  { key: 'scc',    label: 'Sub Cost Centre',w: 130,       align: 'left'   as const },
  { key: 'status', label: 'Status',         w: 100,       align: 'center' as const },
]

export default function PrForeclosureGrid() {
  const {
    lines, loading, hasLoaded,
    prNoFilter, setPrNoFilter, load, reset,
    toggleRow, selectAll, clearAll, isSelected,
    totalLines, selectedCount, totalBalance, selectedBalance,
    confirmForeclosure,
  } = usePrForeclosure()

  const [viewPr, setViewPr] = useState<{ prNo: number; prDate: string } | null>(null)

  const allChecked  = lines.length > 0 && selectedCount === lines.length
  const someChecked = selectedCount > 0 && selectedCount < lines.length

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === 's') { e.preventDefault(); confirmForeclosure() }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [confirmForeclosure])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0, overflow: 'hidden' }}>

      {/* ── Toolbar (BUG-FC-07 fix: TbBtn instead of raw button) ─────────────── */}
      <div style={{
        background: '#fff', borderBottom: '1px solid #E2E2E2',
        display: 'flex', alignItems: 'center', gap: 4, padding: '0 12px', height: 44, flexShrink: 0,
      }}>
        <TbBtn icon="📋" label="Load PRs" onClick={() => void load(prNoFilter || undefined)} disabled={loading} />
        <TbBtn icon="✕"  label="Cancel"   onClick={reset}                                    disabled={!hasLoaded} />
        <TbSep />
        <TbBtn icon="☑" label="Select All" onClick={selectAll} disabled={lines.length === 0} />
        <TbBtn icon="☐" label="Clear"      onClick={clearAll}  disabled={selectedCount === 0} />
        <TbSep />
        <TbBtn
          icon="⚡" label="Confirm Foreclosure" kbd="Ctrl+S"
          variant={selectedCount > 0 ? 'success' : 'default'}
          onClick={confirmForeclosure}
          disabled={selectedCount === 0}
        />
        <div style={{ marginLeft: 'auto' }}>
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            fontSize: 11, fontWeight: 700, padding: '3px 10px', borderRadius: 20,
            background: selectedCount > 0 ? '#dcfce7' : '#E6F1FB',
            color:      selectedCount > 0 ? '#15803d' : '#185FA5',
            border:     `1px solid ${selectedCount > 0 ? '#86efac' : '#bfdbfe'}`,
          }}>
            {selectedCount} selected
          </span>
        </div>
      </div>

      {/* ── Banner (BUG-FC-01 fix: clean message, no internal SP details) ─────── */}
      {/* <div style={{
        padding: '6px 16px', fontSize: 12, fontWeight: 500, flexShrink: 0,
        background: '#e6f4ff', color: '#1677ff', borderBottom: '1px solid #bae0ff',
        display: 'flex', alignItems: 'flex-start', gap: 8,
      }}>
        <span style={{ flexShrink: 0, fontSize: 13, marginTop: 1 }}>ℹ</span>
        <span>
          Select PR lines to force-close.{' '}
          <strong>This action cannot be undone — no undo-foreclosure exists.</strong>
        </span>
      </div> */}

      {/* ── Filter bar ───────────────────────────────────────────────────────── */}
      <div style={{
        background: '#fff', borderBottom: '1px solid #E2E2E2',
        padding: '6px 14px', display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0,
      }}>
        <span style={{ fontSize: 11, fontWeight: 600, color: '#475569', whiteSpace: 'nowrap' }}>PR No. Filter</span>
        <input
          value={prNoFilter}
          onChange={e => setPrNoFilter(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && void load(prNoFilter || undefined)}
          placeholder="Type PR number prefix…"
          style={{ height: 30, padding: '0 9px', border: '1px solid #E2E2E2', borderRadius: 6, fontSize: 12, width: 150, outline: 'none' }}
        />
        <TbBtn icon="🔍" label="Load" onClick={() => void load(prNoFilter || undefined)} />
        <span style={{ fontSize: 10, color: '#888' }}>Leave blank to load all open PR lines</span>
      </div>

      {/* ── Grid ─────────────────────────────────────────────────────────────── */}
      <div style={{ flex: 1, minHeight: 0, position: 'relative', overflow: 'hidden' }}>
        {loading && (
          <div style={{
            position: 'absolute', inset: 0, zIndex: 10,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: 'rgba(255,255,255,0.65)',
          }}>
            <Spin />
          </div>
        )}
          <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'auto' }}>

            {lines.length === 0 && !loading && !hasLoaded ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 40, gap: 8, color: '#888' }}>
                <span style={{ fontSize: 40 }}>📋</span>
                <span style={{ fontSize: 13, fontWeight: 600 }}>No data loaded</span>
                <span style={{ fontSize: 11, textAlign: 'center', maxWidth: 300, lineHeight: 1.6 }}>
                  Click <strong>Load PRs</strong> to view open PR lines available for foreclosure.
                </span>
              </div>
            ) : lines.length === 0 && !loading && hasLoaded ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 40, gap: 8, color: '#888' }}>
                <span style={{ fontSize: 40 }}>📭</span>
                <span style={{ fontSize: 13, fontWeight: 600 }}>No open PR lines found</span>
                <span style={{ fontSize: 11, textAlign: 'center', maxWidth: 300, lineHeight: 1.6 }}>
                  All lines have zero balance, are already force-closed, or are cancelled.
                </span>
              </div>
            ) : (
              <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 900 }}>
                <thead>
                  <tr>
                    {COLS.map((col) => (
                      <th key={col.key} style={{
                        padding: '6px 8px', fontSize: 10, fontWeight: 700, letterSpacing: '.06em',
                        color: '#f1f5f9', background: '#1e293b', borderBottom: '2px solid #0f172a',
                        whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 10,
                        textAlign: col.align, width: col.w,
                      }}>
                        {/* BUG-FC-02 fix: native checkbox in header — no Ant Design Checkbox */}
                        {col.key === 'chk' ? (
                          <input
                            type="checkbox"
                            checked={allChecked}
                            ref={el => { if (el) el.indeterminate = someChecked }}
                            onChange={e => e.target.checked ? selectAll() : clearAll()}
                            style={{ width: 15, height: 15, accentColor: '#185FA5', cursor: 'pointer' }}
                          />
                        ) : col.label}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line: PrForeclosureLineDto, idx: number) => {
                    const sel = isSelected(line)
                    return (
                      // BUG-FC-02 / BUG-FC-03 fix: NO tr.onClick — selection only via checkbox
                      <tr
                        key={`${line.prNo}-${line.prDate}-${line.itemCode}-${line.depCode}-${line.sccCode}`}
                        style={{
                          background: sel ? '#dbeafe' : idx % 2 === 1 ? '#f0f5ff' : '#fff',
                          borderLeft: sel ? '3px solid #185FA5' : '3px solid transparent',
                        }}
                      >
                        <td style={{ textAlign: 'center', padding: '4px 8px' }}>
                          {/* BUG-FC-02 fix: native checkbox — no Ant Design Checkbox */}
                          <input
                            type="checkbox"
                            checked={sel}
                            onChange={e => toggleRow(line, e.target.checked)}
                            style={{ width: 15, height: 15, accentColor: '#185FA5', cursor: 'pointer' }}
                          />
                        </td>
                        <td style={{ padding: '4px 8px', fontSize: 11, color: '#888' }}>{idx + 1}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, fontFamily: 'monospace', fontWeight: 700 }}>
                          <span
                            role="link"
                            tabIndex={0}
                            style={{ color: '#185FA5', cursor: 'pointer', textDecoration: 'underline' }}
                            onClick={() => setViewPr({ prNo: line.prNo, prDate: line.prDate })}
                            onKeyDown={e => e.key === 'Enter' && setViewPr({ prNo: line.prNo, prDate: line.prDate })}
                          >
                            {String(line.prNo).padStart(5, '0')}
                          </span>
                        </td>
                        <td style={{ padding: '4px 8px', fontSize: 11 }}>{line.prDate || '—'}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11 }}>{line.department}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, fontFamily: 'monospace', fontWeight: 600 }}>{line.itemCode}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, whiteSpace: 'normal', wordBreak: 'break-word', minWidth: 100 }}>{line.itemName}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'center' }}>{line.uom || '—'}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{line.prQty.toFixed(3)}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right' }}>{line.ordQty.toFixed(3)}</td>
                        <td style={{ padding: '4px 8px', fontSize: 11, textAlign: 'right', color: '#15803d', fontWeight: 700 }}>
                          {line.balance.toFixed(3)}
                        </td>
                        <td style={{ padding: '4px 8px', fontSize: 11 }}>{line.sccName || line.sccCode || '—'}</td>
                        <td style={{ padding: '4px 8px', textAlign: 'center' }}>
                          {/* BUG-FC-05 fix: StatusBadge uses readable text keys from SP */}
                          <StatusBadge status={line.prevStatus} />
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            )}
          </div>
      </div>

      {/* ── Footer strip ─────────────────────────────────────────────────────── */}
      <div style={{
        background: '#FAFAF8', borderTop: '2px solid #185FA5',
        padding: '7px 16px', display: 'flex', alignItems: 'center', gap: 20, flexShrink: 0,
      }}>
        {[
          { label: 'Total Lines',      val: String(totalLines) },
          { label: 'Selected',         val: String(selectedCount) },
          { label: 'Total Balance',    val: totalBalance.toFixed(3) },
          { label: 'Selected Balance', val: selectedBalance.toFixed(3) },
        ].map(({ label, val }) => (
          <span key={label} style={{ fontSize: 11, color: '#4A4A4A', display: 'flex', alignItems: 'center', gap: 5 }}>
            {label}: <strong style={{ fontFamily: 'monospace', fontSize: 13, color: '#185FA5' }}>{val}</strong>
          </span>
        ))}
      </div>

      <PrViewModal
        prNo={viewPr?.prNo ?? null}
        prDate={viewPr?.prDate ?? null}
        onClose={() => setViewPr(null)}
      />
    </div>
  )
}
