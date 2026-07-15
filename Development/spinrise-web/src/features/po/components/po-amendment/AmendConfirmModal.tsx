import { Modal } from 'antd'
import dayjs from 'dayjs'
import { formatPoNo } from '../../types'

// ── Amendment confirmation prompt (FN-PO-Amendment v1.2 §3.8) ────────────────
// "Confirmation prompt before save showing PO No/Date, Amendment No. preview,
//  count of changed lines and revised order value."
//
// VB6 had NO confirmation for amendment (§6 deviation) — an amendment is an
// irreversible, supplier-facing numbered document, so SPINRISE adds one.
//
// The Amendment No. is deliberately NOT predicted here. It is allocated inside
// the save transaction under UPDLOCK/HOLDLOCK (FN §4A) precisely because the VB6
// read it unlocked before save and produced duplicate numbers under concurrency.
// Showing a guessed number would reintroduce exactly the expectation that bug
// created, so we say it will be allocated on save and report the real one after.

interface Props {
  open:            boolean
  poNo:            number | null
  poDate:          string
  changedCount:    number
  revisedValue:    number
  saving:          boolean
  onConfirm:       () => void
  onCancel:        () => void
}

const fmt2 = (n: number) =>
  (n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export function AmendConfirmModal({
  open, poNo, poDate, changedCount, revisedValue, saving, onConfirm, onCancel,
}: Props) {
  return (
    <Modal
      title="Confirm Amendment"
      open={open}
      onOk={onConfirm}
      onCancel={onCancel}
      okText={saving ? 'Saving…' : 'Save Amendment'}
      cancelText="Back"
      confirmLoading={saving}
      okButtonProps={{ disabled: saving }}
      width={460}
      destroyOnClose
    >
      <div style={{ fontSize: 13, lineHeight: 1.9 }}>
        <Row label="Purchase Order" value={`${formatPoNo(poNo)}  ·  ${poDate ? dayjs(poDate).format('DD-MMM-YYYY') : '—'}`} />
        <Row label="Changed Lines"  value={String(changedCount)} strong />
        <Row label="Revised Order Value" value={`₹ ${fmt2(revisedValue)}`} strong />
        <Row label="Amendment No." value="Allocated on save" muted />

        <div style={{
          marginTop: 12, padding: '8px 10px', background: '#FFF7E6',
          border: '1px solid #FFD591', borderRadius: 6, fontSize: 12, color: '#7A4E00',
        }}>
          This creates a numbered amendment against a supplier-facing document and
          updates the live Purchase Order. It cannot be undone.
        </div>
      </div>
    </Modal>
  )
}

function Row({ label, value, strong, muted }: {
  label: string; value: string; strong?: boolean; muted?: boolean
}) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
      <span style={{ color: '#666' }}>{label}</span>
      <span style={{
        fontWeight: strong ? 700 : 500,
        color: muted ? '#888' : '#1a1a1a',
        fontStyle: muted ? 'italic' : undefined,
        fontFamily: strong ? 'monospace' : undefined,
      }}>
        {value}
      </span>
    </div>
  )
}
