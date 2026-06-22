import { Col, Row, Tag } from 'antd'
import dayjs from 'dayjs'
import { TabPanel, ReadOnlyField } from './_fieldKit'
import { PO_APPROVAL_BADGE, type PoHeader } from '../../../types'

// ── Approval tab (HTML #htab-panel-approval) ─────────────────────────────────
// Read-only approval pipeline + status. Hidden in ADD (PoHeaderTabs omits it).
// The print-approval gate (FSD §5.18) is reflected by conflg/approvalStatus;
// this tab only displays server state.
//
// Label mapping (IST):
//   L1 approved   → "First Level Approved"  (was "Approved")
//   Final approved → "Final Level Approved" (was raw status string "CONFIRMED")

interface ApprovalTabProps { currentPo: PoHeader | null }

// Map raw approvalStatus to a user-friendly display label.
// Only CONFIRMED/APPROVED get the "Final Level Approved" label;
// all other states (PENDING*, REJECTED, NOT PRINTED) keep their own label.
const finalApprovalLabel = (status: string): string => {
  const up = status.toUpperCase()
  if (up === 'CONFIRMED' || up === 'APPROVED') return 'Final Level Approved'
  return status
}

export function ApprovalTab({ currentPo }: ApprovalTabProps) {
  const status = currentPo?.approvalStatus || 'Pending L1'
  const badge  = PO_APPROVAL_BADGE[status.toUpperCase()] ?? PO_APPROVAL_BADGE['PENDING L1']
  const printStatus = currentPo?.printStatus || 'Not Printed'

  return (
    <TabPanel>
      <Row gutter={[12, 8]}>
        <Col span={4}>
          <div style={lbl}>L1 Approval</div>
          <Tag style={currentPo?.firstLevelApp === 'Y'
            ? { background: '#D1FAE5', color: '#065F46', border: 'none', fontWeight: 500 }
            : { background: '#FEF3C7', color: '#92400E', border: 'none', fontWeight: 500 }
          }>
            {/* IST: "Approved" → "First Level Approved" */}
            {currentPo?.firstLevelApp === 'Y' ? 'First Level Approved' : 'Pending'}
          </Tag>
        </Col>
        <Col span={4}>
          <div style={lbl}>Final Approval</div>
          {/* IST: CONFIRMED/APPROVED → "Final Level Approved"; other states unchanged */}
          <Tag style={{ background: badge.bg, color: badge.color, border: 'none', fontWeight: 500 }}>
            {finalApprovalLabel(status)}
          </Tag>
        </Col>
        <Col span={4}>
          <div style={lbl}>Print Status</div>
          <Tag style={{ background: '#F5F5F3', color: '#4a4a4a', border: '1px solid #e2e2e2' }}>{printStatus==='N' ?  'Not Printed' : 'Printed'  }</Tag>
        </Col>
        <Col span={6}><ReadOnlyField label="Created By" value={currentPo?.createdBy || '—'} /></Col>
        <Col span={4}>
          <ReadOnlyField label="Created On"
            value={currentPo?.createdDt ? dayjs(currentPo.createdDt, 'DD/MM/YYYY').format('DD-MMM-YYYY') : '—'} mono />
        </Col>
      </Row>
    </TabPanel>
  )
}

const lbl: React.CSSProperties = { fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3 }
