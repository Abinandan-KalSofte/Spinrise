import { useMemo } from 'react'
import { Modal, Input, Button, DatePicker } from 'antd'
import { CheckCircleOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import { selectLinesNeedingReason, selectSelectedLines } from '../../store/createPoApprovalStore'
import { DISPOSITION_LABELS, isReasonRequired, type DispositionCode, type PoApprovalLine } from '../../types/poApprovalTypes'

interface Props {
  lines:              PoApprovalLine[]
  updateRemarks:      (pordno: string, remarks: string) => void
  updatePostponeDate: (pordno: string, date: string) => void
  open:               boolean
  title:              string    // e.g. "Confirm First Level Actions" / "Confirm Second Level Actions"
  onCancel:           () => void
  onConfirm:          () => void
}

const GROUP_ORDER: DispositionCode[] = [3, 4, 5]   // Hold, Declined, Postpone — same order as the prototype


// Shared across every PO Approval level. Reason entered HERE, grouped by
// disposition — the grid's own Remarks column was removed per CR
// 03-Jul-2026 (Items 1 & 4). Mandatory for Hold/Declined/Postpone only (CEO
// direction 02-Jul-2026); Confirm stays disabled until every required
// reason is a non-whitespace value, max 25 chars (LogDet_PO.reason).
// Final Level (grouped view, CEO Decision 1) also shows a per-PO cascade
// line — auto-detected whenever `line.lineCount` is present in the data.
export default function PoApprovalConfirmSaveModal({ lines, updateRemarks, updatePostponeDate, open, title, onCancel, onConfirm }: Props) {
  const needingReason = selectLinesNeedingReason(lines)

  // Selected lines that don't require a reason (Approved / PL Discuss) — shown
  // as a plain summary so the dialog always reflects everything Save is about
  // to do, even when no line needs a reason at all.
  const otherLines = useMemo(
    () => selectSelectedLines(lines).filter((l) => !isReasonRequired(l.disposition)),
    [lines],
  )

  const groups = useMemo(() => {
    const byCode = new Map<DispositionCode, typeof needingReason>()
    needingReason.forEach((line) => {
      const arr = byCode.get(line.disposition) ?? []
      arr.push(line)
      byCode.set(line.disposition, arr)
    })
    return GROUP_ORDER
      .filter((code) => byCode.has(code))
      .map((code) => ({ code, label: DISPOSITION_LABELS[code], items: byCode.get(code)! }))
  }, [needingReason])

  // No reason-required lines at all (e.g. an Approved-only save) → nothing to
  // validate, Confirm stays enabled. Otherwise every reason-required line
  // must have a non-blank remark, and every Postpone line must also have a
  // postpone date (BR-05, legacy parity — the SP hides it from the queue
  // until that date arrives, so there's no valid "postpone with no date").
  const allValid = needingReason.every((l) =>
    l.remarks.trim() !== '' && (l.disposition !== 5 || !!l.postponeDate),
  )

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      title={
        <span>
          <CheckCircleOutlined style={{ marginRight: 8, color: '#3B6D11' }} />
          {title}
        </span>
      }
      footer={[
        <Button key="cancel" onClick={onCancel}>Cancel</Button>,
        <Button key="ok" type="primary" disabled={!allValid} onClick={onConfirm}>
          Confirm Save
        </Button>,
      ]}
      width={560}
      destroyOnHidden
    >
      {groups.map((group) => (
        <div key={group.code} style={{ marginBottom: 10 }}>
          <div style={{
            fontSize: 11, fontWeight: 700, color: '#1A1A1A',
            textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 4,
          }}>
            {group.label} ({group.items.length})
          </div>
          {group.items.map((line) => {
            const len = line.remarks.length
            const invalid = line.remarks.trim() === ''
            return (
              <div key={line.pordno} style={{
                padding: '6px 10px', border: '1px solid #E2E2E2', borderRadius: 6,
                marginBottom: 5, background: '#FAFAF8',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                  <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 11, color: '#185FA5' }}>
                    {line.pordno}
                  </span>
                  <span style={{ fontSize: 11, color: '#4A4A4A', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {line.supplier.name}
                  </span>
                  {(() => {
                    const lineCount = line.lineCount ?? line.lines?.length ?? 0
                    return (
                      <span style={{
                        fontSize: 10, fontWeight: 700, padding: '1px 7px', borderRadius: 10,
                        background: '#E6F1FB', color: '#185FA5', whiteSpace: 'nowrap',
                      }}>
                        {lineCount} line{lineCount !== 1 ? 's' : ''}
                      </span>
                    )
                  })()}
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 5 }}>
                  <span style={{ fontSize: 10, color: '#888', minWidth: 104 }}>
                    Reason<span style={{ color: '#A32D2D' }}> *</span>
                  </span>
                  <Input
                    size="small"
                    maxLength={25}
                    value={line.remarks}
                    placeholder="Reason (required) — max 25"
                    status={invalid ? 'error' : undefined}
                    onChange={(e) => updateRemarks(line.pordno, e.target.value)}
                    aria-label={`Reason for ${line.pordno}`}
                    style={{ width: 200 }}
                  />
                  <span style={{ fontSize: 9, color: len >= 25 ? '#BA7517' : '#888', fontFamily: 'monospace', minWidth: 28 }}>
                    {len}/25
                  </span>
                </div>
                {/* Postpone only (BR-05, legacy parity) — re-surface date, mandatory */}
                {line.disposition === 5 && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 5 }}>
                    <span style={{ fontSize: 10, color: '#888', minWidth: 104 }}>
                      Postpone Until<span style={{ color: '#A32D2D' }}> *</span>
                    </span>
                    <DatePicker
                      size="small"
                      format="DD-MMM-YYYY"
                      value={line.postponeDate ? dayjs(line.postponeDate) : null}
                      status={!line.postponeDate ? 'error' : undefined}
                      disabledDate={(d) => d.isBefore(dayjs().startOf('day'))}
                      onChange={(d) => updatePostponeDate(line.pordno, d ? d.format('YYYY-MM-DD') : '')}
                      aria-label={`Postpone date for ${line.pordno}`}
                      style={{ width: 130 }}
                    />
                  </div>
                )}
                {/* Final Level only (CEO Decision 1) — explicit header-level cascade statement */}
                {line.lineCount !== undefined && (
                  <div style={{ fontSize: 10, color: '#4A4A4A', fontWeight: 600, marginTop: 2 }}>
                    Action applied to all {line.lineCount} lines (header-level cascade — CEO Decision 1)
                  </div>
                )}
              </div>
            )
          })}
        </div>
      ))}
      {otherLines.length > 0 && (
        <div style={{ marginBottom: 10 }}>
          <div style={{
            fontSize: 11, fontWeight: 700, color: '#1A1A1A',
            textTransform: 'uppercase', letterSpacing: '.04em', marginBottom: 4,
          }}>
            Approved / PL Discuss ({otherLines.length}) — no reason required
          </div>
          {otherLines.map((line) => (
            <div key={line.pordno} style={{
              display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
              padding: '6px 10px', border: '1px solid #E2E2E2', borderRadius: 6,
              marginBottom: 5, background: '#FAFAF8',
            }}>
              <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 11, color: '#185FA5' }}>
                {line.pordno}
              </span>
              <span style={{ fontSize: 11, color: '#4A4A4A', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {line.supplier.name}
              </span>
              <span style={{
                fontSize: 10, fontWeight: 700, padding: '1px 7px', borderRadius: 10,
                background: '#EAF3DE', color: '#3B6D11', whiteSpace: 'nowrap',
              }}>
                {DISPOSITION_LABELS[line.disposition]}
              </span>
            </div>
          ))}
        </div>
      )}
    </Modal>
  )
}
