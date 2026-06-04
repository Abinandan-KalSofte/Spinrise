import { Checkbox, Tooltip } from 'antd'
import type { PrApprovalLineLocal, ApprovalScreenMode } from '../../types/prFirstApprovalTypes'
import { usePrFirstApprovalStore } from '../../store/usePrFirstApprovalStore'
import { ERP_TH as TH, ERP_TD as TD, erpRowBg } from '@/shared/styles/erpTable'

interface Props {
  lines:  PrApprovalLineLocal[]
  mode:   ApprovalScreenMode
}

export default function PrApprovalGrid({ lines, mode }: Props) {
  const editable    = mode === 'APPROVE'
  const updateLine  = usePrFirstApprovalStore((s) => s.updateLine)
  const toggleRow   = usePrFirstApprovalStore((s) => s.toggleRow)
  const toggleAll   = usePrFirstApprovalStore((s) => s.toggleAllRows)

  const allChecked  = lines.length > 0 && lines.every((l) => l.selected)
  const someChecked = lines.some((l) => l.selected)

  return (
    <div style={{ overflow: 'auto', flex: 1 }}>
      <table style={{ borderCollapse: 'collapse', fontSize: 12, width: 'max-content', minWidth: '100%' }}>
        <thead>
          <tr>
            <th style={{ ...TH, width: 34, textAlign: 'center' }}>
              <Checkbox
                checked={allChecked}
                indeterminate={!allChecked && someChecked}
                disabled={!editable}
                onChange={(e) => toggleAll(e.target.checked)}
              />
            </th>
            <th style={{ ...TH, width: 30, textAlign: 'center' }}>#</th>
            <th style={{ ...TH }}>Item Id</th>
            <th style={{ ...TH }}>Item Name</th>
            <th style={{ ...TH, textAlign: 'center' }}>Unit</th>
            <th style={{ ...TH, textAlign: 'right' }}>Rate ✎</th>
            <th style={{ ...TH }}>Machine</th>
            <th style={{ ...TH, textAlign: 'right' }}>Current Stock</th>
            <th style={{ ...TH, textAlign: 'right' }}>Quantity Required</th>
            <th style={{ ...TH, textAlign: 'right' }}>First Approval Quantity ✎</th>
            <th style={{ ...TH, textAlign: 'center' }}>Required Date</th>
            <th style={{ ...TH, textAlign: 'right' }}>Approx. Value</th>
            <th style={{ ...TH }}>Remarks</th>
          </tr>
        </thead>
        <tbody>
          {lines.map((l, i) => (
            <tr key={l.key} style={{ background: erpRowBg(i, l.selected) }}>
              <td style={{ ...TD, textAlign: 'center' }}>
                <Checkbox
                  checked={l.selected}
                  disabled={!editable}
                  onChange={(e) => toggleRow(l.key, e.target.checked)}
                />
              </td>
              <td style={{ ...TD, textAlign: 'center', fontSize: 11, color: '#94a3b8' }}>{l.prSno}</td>
              <td style={{ ...TD, fontWeight: 700, fontFamily: 'monospace', fontSize: 11, whiteSpace: 'nowrap' }}>{l.itemCode}</td>
              <td style={{ ...TD, maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                <Tooltip title={l.itemName}>{l.itemName}</Tooltip>
              </td>
              <td style={{ ...TD, textAlign: 'center', fontSize: 11 }}>{l.uom}</td>
              <td style={{ ...TD, textAlign: 'right' }}>
                <input
                  type="number"
                  step="0.0001"
                  min="0"
                  value={l.editRate}
                  disabled={!editable}
                  onChange={(e) => updateLine(l.key, 'editRate', parseFloat(e.target.value) || 0)}
                  style={{
                    width: 80, height: 22,
                    border: `1px solid ${editable ? '#e0d070' : 'transparent'}`,
                    borderRadius: 3, padding: '0 6px',
                    fontSize: 11, fontFamily: 'monospace',
                    textAlign: 'right',
                    background: editable ? '#fffce8' : 'transparent',
                    outline: 'none',
                  }}
                />
              </td>
              <td style={{ ...TD, fontSize: 11 }}>{l.machine ?? <span style={{ color: '#d1d5db' }}>—</span>}</td>
              <td style={{ ...TD, fontFamily: 'monospace', fontSize: 11, color: '#666', textAlign: 'right' }}>
                {l.curStock.toFixed(3)}
              </td>
              <td style={{ ...TD, fontFamily: 'monospace', fontSize: 11, textAlign: 'right' }}>
                {l.qtyInd.toFixed(3)}
              </td>
              <td style={{ ...TD, textAlign: 'right' }}>
                <input
                  type="number"
                  step="0.001"
                  min="0"
                  value={l.editFirstAppQty}
                  disabled={!editable}
                  onChange={(e) => { const raw = parseFloat(e.target.value); updateLine(l.key, 'editFirstAppQty', isNaN(raw) ? 0 : Math.max(0, raw)) }}
                  style={{
                    width: 88, height: 22,
                    border: `1px solid ${l.hasError ? '#ef4444' : editable ? '#e0d070' : 'transparent'}`,
                    borderRadius: 3, padding: '0 6px',
                    fontSize: 11, fontFamily: 'monospace',
                    textAlign: 'right',
                    background: l.hasError ? '#FCEBEB' : editable ? '#fffce8' : 'transparent',
                    outline: 'none',
                  }}
                />
              </td>
              <td style={{ ...TD, textAlign: 'center', fontSize: 11 }}>
                {l.reqdDate ? new Date(l.reqdDate).toLocaleDateString('en-GB') : <span style={{ color: '#d1d5db' }}>—</span>}
              </td>
              <td style={{ ...TD, fontFamily: 'monospace', fontSize: 11, textAlign: 'right' }}>
                {l.calcValue.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </td>
              <td style={{ ...TD, fontSize: 11, maxWidth: 140, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                <Tooltip title={l.remarks}>{l.remarks ?? ''}</Tooltip>
              </td>
            </tr>
          ))}
          {lines.length === 0 && (
            <tr>
              <td colSpan={13} style={{ textAlign: 'center', padding: 48, color: '#aaa' }}>
                No items loaded
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
