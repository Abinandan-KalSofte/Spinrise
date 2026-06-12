import { Col, Row } from 'antd'
import dayjs from 'dayjs'
import { TabPanel, ReadOnlyField } from './_fieldKit'
import type { PoHeader } from '../../../types'

// ── Amendment tab (HTML #htab-panel-amendment) ───────────────────────────────
// Read-only amendment history. PO amendment is raised on a separate screen.

interface AmendmentTabProps { currentPo: PoHeader | null }

const fmtD = (d: string | null | undefined) => (d ? dayjs(d).format('DD-MMM-YYYY') : '—')

export function AmendmentTab({ currentPo }: AmendmentTabProps) {
  const hasAmendment = !!currentPo?.amdOrderNo

  return (
    <TabPanel>
      <Row gutter={[12, 8]}>
        <Col span={6}><ReadOnlyField label="AMD Order No." value={currentPo?.amdOrderNo != null ? String(currentPo.amdOrderNo) : '—'} mono /></Col>
        <Col span={6}><ReadOnlyField label="AMD Date" value={fmtD(currentPo?.amdDate)} /></Col>
        <Col span={6}><ReadOnlyField label="Ref. Order No." value={currentPo?.amdRefNo != null ? String(currentPo.amdRefNo) : '—'} mono /></Col>
        <Col span={6}><ReadOnlyField label="Ref. Date" value={fmtD(currentPo?.amdRefDate)} /></Col>
      </Row>
      {!hasAmendment && (
        <div style={{
          marginTop: 10, padding: '10px 12px', background: '#F5F5F3', border: '1px solid #e2e2e2',
          borderRadius: 6, fontSize: 11, color: '#888', fontStyle: 'italic',
        }}>
          No amendments raised. Amendment history will appear here once an amendment is created.
        </div>
      )}
    </TabPanel>
  )
}
