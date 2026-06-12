import {
  PlusOutlined, SearchOutlined, DeleteOutlined, SaveOutlined,
  CloseOutlined, PrinterOutlined,
  StepBackwardOutlined, StepForwardOutlined, LeftOutlined, RightOutlined,
} from '@ant-design/icons'
import { TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'
import type { ScreenMode } from '../../types'

// ── Toolbar (HTML .toolbar) — maps to VB6 BUTTON_Click(Index) ─────────────────
// Reuses the shared TbBtn / TbSep primitives. Mode drives enable/disable.
// Find and record navigation depend on getList (Q6 deferred this sprint) → shown
// disabled with a clear title rather than omitted, preserving mockup parity.

interface PoToolbarProps {
  mode:        ScreenMode
  canAdd:      boolean
  canDelete:   boolean
  canPrint:    boolean
  busy:        boolean
  onNew:       () => void
  onDelete:    () => void
  onSave:      () => void
  onCancel:    () => void
  onPrint:     () => void
}

export function PoToolbar({
  mode, canAdd, canDelete, canPrint, busy, onNew, onDelete, onSave, onCancel, onPrint,
}: PoToolbarProps) {
  const isView   = mode === 'VIEW'
  const isAdd    = mode === 'ADD'
  const isDelete = mode === 'DELETE'

  const saveLabel = isDelete ? 'Confirm Delete' : isAdd ? 'Save PO' : 'Save'

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 3, padding: '5px 16px',
      background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0, flexWrap: 'wrap',
    }}>
      <TbBtn icon={<PlusOutlined />} label="New PO" kbd="Ctrl+A" variant="primary"
        disabled={!isView || !canAdd || busy} onClick={onNew} />
      <TbBtn icon={<SearchOutlined />} label="Find" kbd="Ctrl+F"
        disabled title="Find by PO No. — planned for a later sprint" />
      <TbBtn icon={<DeleteOutlined />} label="Delete" kbd="Ctrl+D" variant="danger"
        disabled={!isView || !canDelete || busy} onClick={onDelete} />

      <TbSep />

      <TbBtn icon={<SaveOutlined />} label={saveLabel} kbd="Ctrl+S"
        variant={isDelete ? 'danger-filled' : 'primary'}
        disabled={isView || busy} onClick={onSave} />
      <TbBtn icon={<CloseOutlined />} label="Cancel" kbd="Ctrl+Bksp"
        disabled={isView || busy} onClick={onCancel} />

      <TbSep />

      <TbBtn icon={<PrinterOutlined />} label="Print" kbd="Ctrl+P"
        disabled={!isView || !canPrint || busy} onClick={onPrint}
        title={!canPrint ? 'Print enabled after approval' : undefined} />

      <span style={{ flex: 1 }} />

      {/* Record navigation — deferred with Find (Q6); disabled this sprint. */}
      <TbBtn icon={<StepBackwardOutlined />} variant="icon" disabled title="First — later sprint" />
      <TbBtn icon={<LeftOutlined />}        variant="icon" disabled title="Previous — later sprint" />
      <TbBtn icon={<RightOutlined />}       variant="icon" disabled title="Next — later sprint" />
      <TbBtn icon={<StepForwardOutlined />} variant="icon" disabled title="Last — later sprint" />
    </div>
  )
}
