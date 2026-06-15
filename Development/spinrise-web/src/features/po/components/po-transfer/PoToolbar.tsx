import {
  PlusOutlined, SearchOutlined, DeleteOutlined, SaveOutlined,
  CloseOutlined, PrinterOutlined,
  StepBackwardOutlined, StepForwardOutlined, LeftOutlined, RightOutlined,
} from '@ant-design/icons'
import { TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'
import type { ScreenMode } from '../../types'

// ── Toolbar (HTML .toolbar) — maps to VB6 BUTTON_Click(Index) ─────────────────
// Reuses the shared TbBtn / TbSep primitives. Enable/disable is driven purely by
// screen MODE and business rules (no permission gating). New/Find/Delete/Print +
// record navigation are available in VIEW; Save/Cancel in ADD/DELETE.

interface PoToolbarProps {
  mode:      ScreenMode
  busy:      boolean
  hasRecord: boolean       // a saved PO is loaded → Delete / Print / nav apply
  canPrev:   boolean       // a previous record exists in the FY index
  canNext:   boolean       // a next record exists in the FY index
  onNew:     () => void
  onFind:    () => void
  onDelete:  () => void
  onSave:    () => void
  onCancel:  () => void
  onPrint:   () => void
  onFirst:   () => void
  onPrev:    () => void
  onNext:    () => void
  onLast:    () => void
}

export function PoToolbar({
  mode, busy, hasRecord, canPrev, canNext,
  onNew, onFind, onDelete, onSave, onCancel, onPrint,
  onFirst, onPrev, onNext, onLast,
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
      <TbBtn icon={<PlusOutlined />} label="New PO" kbd="F1" variant="primary"
        disabled={!isView || busy} onClick={onNew} />
      <TbBtn icon={<SearchOutlined />} label="Find" kbd="F2"
        disabled={!isView || busy} onClick={onFind} />
      <TbBtn icon={<DeleteOutlined />} label="Delete" kbd="F3" variant="danger"
        disabled={!isView || busy || !hasRecord} onClick={onDelete} />

      <TbSep />

      <TbBtn icon={<SaveOutlined />} label={saveLabel} kbd={isDelete ? 'F8' : 'ctrl+s'}
        variant={isDelete ? 'danger-filled' : 'primary'}
        disabled={isView || busy} onClick={onSave} />
      <TbBtn icon={<CloseOutlined />} label="Cancel" kbd="F6"
        disabled={isView || busy} onClick={onCancel} />

      <TbSep />

      <TbBtn icon={<PrinterOutlined />} label="Print" kbd="F7"
        disabled={!isView || busy || !hasRecord} onClick={onPrint} />

      <span style={{ flex: 1 }} />

      {/* Record navigation — VIEW mode, bounded by the FY index. */}
      <TbBtn icon={<StepBackwardOutlined />} variant="icon"
        disabled={!isView || busy || !canPrev} onClick={onFirst} title="First record" />
      <TbBtn icon={<LeftOutlined />} variant="icon"
        disabled={!isView || busy || !canPrev} onClick={onPrev} title="Previous record" />
      <TbBtn icon={<RightOutlined />} variant="icon"
        disabled={!isView || busy || !canNext} onClick={onNext} title="Next record" />
      <TbBtn icon={<StepForwardOutlined />} variant="icon"
        disabled={!isView || busy || !canNext} onClick={onLast} title="Last record" />
    </div>
  )
}
