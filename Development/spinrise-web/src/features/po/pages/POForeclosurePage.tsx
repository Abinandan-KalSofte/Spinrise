import { Input } from 'antd'
import { PRDocBand, TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { ApiLoader } from '@/components/common/loading'
import { PoForeclosureGrid } from '../components/po-foreclosure/PoForeclosureGrid'
import { usePoForeclosure } from '../hooks/usePoForeclosure'

// ── PO Fore Closure page (HTML po-foreclosure/index.html, FSD v1.1) ─────────
// Faithful conversion: toolbar (Modify/Save/Cancel/Exit), PO No. filter bar,
// grid of all open PO lines. No PO picker — the prototype loads everything
// up front and filters client-side. Save forecloses immediately, no confirm.

export default function POForeclosurePage() {
  usePageTitle('Purchase Order Fore Closure')

  const {
    mode, loading,
    lines,
    checkedKeys, toggleRow, toggleAll,
    filterText, setFilterText,
    onModify, onSave, onCancel, onExit,
  } = usePoForeclosure()

  const isModify = mode === 'modify'

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: 1, height: '100%', minHeight: 0, overflow: 'hidden' }}>
      <PRDocBand
        breadcrumb={['Purchase Order', 'Purchase Order Fore Closure']}
        subLabel="Mode"
        subValue={isModify ? 'Modify' : 'Query'}
      />

      {/* Toolbar — FSD buttons: Modify / Save / Cancel / Exit */}
      <div style={{
        background: '#fff', borderBottom: '1px solid #E2E2E2',
        display: 'flex', alignItems: 'center', gap: 4, padding: '0 12px', height: 44, flexShrink: 0,
      }}>
        <TbBtn icon="✏️" label="Modify" kbd="Ctrl+M" variant={isModify ? 'primary' : 'default'}
          onClick={onModify} title="Modify — enable line selection (Ctrl+M)" />
        <TbBtn icon="💾" label="Save" kbd="Ctrl+S" variant="primary"
          disabled={!isModify} onClick={() => void onSave()} title="Save — fore close selected lines (Ctrl+S)" />
        <TbBtn icon="↺" label="Cancel" kbd="Ctrl+⌫"
          onClick={onCancel} title="Cancel — reset to query state (Ctrl+Backspace)" />
        <TbSep />
        <TbBtn icon="✕" label="Exit" kbd="Ctrl+Q" onClick={onExit} title="Exit (Ctrl+Q)" />
      </div>

      {/* Text1 PO filter */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10, padding: '8px 16px',
        background: '#fff', borderBottom: '1px solid #E2E2E2', flexShrink: 0,
      }}>
        <span style={{ fontSize: 11, fontWeight: 600, color: '#4a4a4a', whiteSpace: 'nowrap' }}>PO No.</span>
        <Input
          value={filterText}
          onChange={(e) => setFilterText(e.target.value)}
          placeholder="Enter PO number to filter…"
          style={{ height: 30, width: 220, maxWidth: '50vw', fontSize: 12 }}
          allowClear
        />
        <span style={{ fontSize: 10, color: '#888' }}>Leave blank to show all open lines.</span>
      </div>

      {/* Grid section — no "Open PO Lines" header bar: it duplicated the footer's
          Total Lines count and cost the table a row of height. PR Foreclosure has
          no such bar either, so the header stack now matches it exactly. */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, background: '#F5F5F3' }}>
        {loading ? (
          <ApiLoader message="Loading open PO lines…" />
        ) : (
          <PoForeclosureGrid
            lines={lines}
            checkedKeys={checkedKeys}
            isModify={isModify}
            onToggleRow={toggleRow}
            onToggleAll={toggleAll}
          />
        )}
      </div>
    </div>
  )
}
