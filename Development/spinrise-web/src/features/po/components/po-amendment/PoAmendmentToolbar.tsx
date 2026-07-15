import {
  SearchOutlined, FileSearchOutlined, SaveOutlined, CloseOutlined, PrinterOutlined,
  StepBackwardOutlined, StepForwardOutlined, LeftOutlined, RightOutlined,
} from '@ant-design/icons'
import { TbBtn, TbSep } from '@/features/pr/components/pr-form/PRToolbar'

// ── PO Amendment toolbar ─────────────────────────────────────────────────────
// Independent component (does NOT import/reuse po-transfer/PoToolbar.tsx),
// built from the same shared TbBtn/TbSep primitives the Transfer toolbar uses,
// styled to match it 1:1 — layout, spacing, icons, button order, typography.
//
// Two intentional differences from the Transfer toolbar:
//   • No "New PO" — Amendment has no create-new concept; every record it shows
//     must already exist to be amendable, so there is nothing for that button
//     to do. (Flagged in the completion report — this is a judgement call, not
//     an FSD-confirmed rule; revert easily if a real equivalent is wanted.)
//   • No Delete — removed per explicit instruction; deletion is a distinct,
//     not-yet-wired action (see usePoAmendment.deleteOrder).
//
// Transfer's VIEW/ADD/DELETE modes are mutually exclusive, so one `mode` prop
// can gate both "browse" (New/Find/Nav/Print) and "edit" (Save/Cancel) groups.
// Amendment's mode model isn't: a record can be simultaneously loaded/browsable
// AND being edited (selectPo() puts it straight into AMEND). So this component
// takes two independent booleans instead of a single mode.

interface PoAmendmentToolbarProps {
  busy:         boolean   // saving, or loading a record — disables the whole bar
  canBrowse:    boolean   // Select PO / Find Amendment / record-nav enabled — false
                          // once an amendment is in progress, so the user can't
                          // switch documents mid-edit (re-enabled by Save/Cancel)
  canEdit:      boolean   // Save / Cancel group enabled (i.e. a PO is being amended)
  saveDisabled: boolean   // extra Save-only guard (FN §3.1 — zero-change amendment blocked)
  hasRecord:    boolean
  canPrev:      boolean
  canNext:      boolean
  onFind:           () => void
  onFindAmendment:  () => void
  onSave:       () => void
  onCancel:     () => void
  onPrint:      () => void
  onFirst:      () => void
  onPrev:       () => void
  onNext:       () => void
  onLast:       () => void
}

export function PoAmendmentToolbar({
  busy, canBrowse, canEdit, saveDisabled, hasRecord, canPrev, canNext,
  onFind, onFindAmendment, onSave, onCancel, onPrint, onFirst, onPrev, onNext, onLast,
}: PoAmendmentToolbarProps) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 3, padding: '5px 16px',
      background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0, flexWrap: 'wrap',
    }}>
      <TbBtn icon={<SearchOutlined />} label="Select PO" kbd="F1"
        title="Find a Purchase Order open for amendment"
        disabled={!canBrowse || busy} onClick={onFind} />
      <TbBtn icon={<FileSearchOutlined />} label="Find" kbd="F2"
        title="Browse saved amendments and view the underlying Purchase Order (read-only)"
        disabled={!canBrowse || busy} onClick={onFindAmendment} />

      {/* Record navigation — same icons/order/positions as the Transfer toolbar. */}
      <TbBtn icon={<StepBackwardOutlined />} variant="icon"
        disabled={!canBrowse || busy || !canPrev} onClick={onFirst} title="First record" />
      <TbBtn icon={<LeftOutlined />} variant="icon"
        disabled={!canBrowse || busy || !canPrev} onClick={onPrev} title="Previous record" />
      <TbBtn icon={<RightOutlined />} variant="icon"
        disabled={!canBrowse || busy || !canNext} onClick={onNext} title="Next record" />
      <TbBtn icon={<StepForwardOutlined />} variant="icon"
        disabled={!canBrowse || busy || !canNext} onClick={onLast} title="Last record" />

      <TbSep />

      <TbBtn icon={<SaveOutlined />} label="Save" kbd="Ctrl+S" variant="primary"
        title="Validate, confirm and save the amendment"
        disabled={!canEdit || busy || saveDisabled} onClick={onSave} />
      <TbBtn icon={<CloseOutlined />} label="Cancel" kbd="F6"
        title="Discard changes"
        disabled={!canEdit || busy} onClick={onCancel} />

      <TbSep />

      {/* Print is a read-only export — it doesn't switch documents, so it stays
          available during an in-progress amendment (unlike canBrowse's group). */}
      <TbBtn icon={<PrinterOutlined />} label="Print" kbd="F7"
        disabled={busy || !hasRecord} onClick={onPrint} />
    </div>
  )
}