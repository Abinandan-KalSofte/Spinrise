import { Col, Row, Tag } from 'antd'
import dayjs from 'dayjs'
import { TabPanel, ReadOnlyField } from './_fieldKit'
import { PO_APPROVAL_BADGE, type PoHeader } from '../../../types'

// ── Approval tab (HTML #htab-panel-approval) ─────────────────────────────────
// Read-only approval pipeline + status. Hidden in ADD (PoHeaderTabs omits it).
// The print-approval gate (FSD §5.18) is reflected by conflg/approvalStatus;
// this tab only displays server state.

interface ApprovalTabProps { currentPo: PoHeader | null }

export function ApprovalTab({ currentPo }: ApprovalTabProps) {
  const status = currentPo?.approvalStatus || 'Pending L1'
  const badge  = PO_APPROVAL_BADGE[status.toUpperCase()] ?? PO_APPROVAL_BADGE['PENDING L1']
  const printStatus = currentPo?.printStatus || 'Not Printed'

  return (
    <TabPanel>
      <Row gutter={[12, 8]}>
        <Col span={6}>
          <div style={lbl}>L1 Approval</div>
          <Tag style={currentPo?.firstLevelApp === 'Y'
            ? { background: '#D1FAE5', color: '#065F46', border: 'none', fontWeight: 700 }
            : { background: '#FEF3C7', color: '#92400E', border: 'none', fontWeight: 700 }
          }>
            {currentPo?.firstLevelApp === 'Y' ? 'Approved' : 'Pending'}
          </Tag>
        </Col>
        <Col span={6}>
          <div style={lbl}>Final Approval</div>
          <Tag style={{ background: badge.bg, color: badge.color, border: 'none', fontWeight: 700 }}>{status}</Tag>
        </Col>
        <Col span={6}>
          <div style={lbl}>Print Status</div>
          <Tag style={{ background: '#F5F5F3', color: '#4a4a4a', border: '1px solid #e2e2e2' }}>{printStatus==='N' ?  'Not Printed' : 'Printed'  }</Tag>
        </Col>
        <Col span={6}><ReadOnlyField label="Created By" value={currentPo?.createdBy || '—'} /></Col>
      </Row>
      <Row gutter={[12, 8]} style={{ marginTop: 8 }}>
        <Col span={6}>
          <ReadOnlyField label="Created On"
            value={currentPo?.createdDt ? dayjs(currentPo.createdDt, 'DD/MM/YYYY').format('DD-MMM-YYYY') : '—'} mono />
        </Col>
      </Row>
    </TabPanel>
  )
}

const lbl: React.CSSProperties = { fontSize: 11, fontWeight: 500, color: '#4a4a4a', marginBottom: 4 }
