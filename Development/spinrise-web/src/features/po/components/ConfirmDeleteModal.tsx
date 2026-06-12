import { Button, Modal } from 'antd'
import { ExclamationCircleFilled } from '@ant-design/icons'
import { formatPoNo } from '../types'

// ── Confirm Delete dialog (HTML #del-confirm) ────────────────────────────────
// Final yes/no for an overall PO deletion. The header-level default reason +
// per-line reasons (BR-04) are captured before this opens; the GRN guard (BR-03)
// is enforced SERVER-SIDE (HTTP 409) — the message here is informational only.

interface ConfirmDeleteModalProps {
  open:      boolean
  poNo:      number | null
  deleting:  boolean
  onConfirm: () => void
  onCancel:  () => void
}

export function ConfirmDeleteModal({ open, poNo, deleting, onConfirm, onCancel }: ConfirmDeleteModalProps) {
  const poLabel = formatPoNo(poNo) || 'this Purchase Order'

  return (
    <Modal open={open} onCancel={onCancel} footer={null} width={420} destroyOnClose>
      <div style={{ fontSize: 22, color: '#BA7517', marginBottom: 8 }}>
        <ExclamationCircleFilled />
      </div>
      <div style={{ fontSize: 15, fontWeight: 700, color: '#1a1a1a', marginBottom: 6 }}>
        Confirm Purchase Order Deletion
      </div>
      <div style={{ fontSize: 12, color: '#4a4a4a', lineHeight: 1.6, marginBottom: 16 }}>
        Are you sure you want to delete <strong>{poLabel}</strong>?<br />
        This reverses all PR quantities and budget allocations and cannot be undone.<br /><br />
        <span style={{ color: '#888' }}>
          The GRN guard is verified on the server — deletion is rejected if any GRN exists for this PO.
        </span>
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
        <Button onClick={onCancel} disabled={deleting}>Cancel</Button>
        <Button danger type="primary" loading={deleting} onClick={onConfirm}>
          Yes, Delete PO
        </Button>
      </div>
    </Modal>
  )
}
