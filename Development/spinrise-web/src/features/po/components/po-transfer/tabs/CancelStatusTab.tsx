import { Checkbox, Col, DatePicker, Form, Input, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'

// ── Cancel / Status tab (HTML #htab-panel-cancel) ────────────────────────────
// Sprint 1 business decision: this tab is VIEW-ONLY in all modes (ADD, VIEW,
// DELETE). No edits are permitted here — cancellation is handled on a
// dedicated screen (out of scope for Sprint 1).

interface CancelStatusTabProps { disabled: boolean }

const lbl: React.CSSProperties = {
  fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3, whiteSpace: 'nowrap',
}
const full = { width: '100%' }
const fi   = { marginBottom: 0 }

export function CancelStatusTab({ disabled: _disabled }: CancelStatusTabProps) {
  // Always read-only — Sprint 1 decision. The prop is retained in the interface
  // so PoHeaderTabs requires no change; it is intentionally unused here.
  const alwaysDisabled = true

  return (
    <TabPanel>
      <Row gutter={[12, 8]} align="bottom">
        <Col span={4}>
          <div style={lbl}>Reminder</div>
          <Form.Item name="reminder" style={fi}>
            <Input placeholder="—" disabled={alwaysDisabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Status</div>
          <Form.Item name="status" style={fi}>
            <Input placeholder="—" disabled={alwaysDisabled} style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>
        <Col span={2}>
          {/* Spacer div matches label height so checkbox aligns with adjacent fields */}
          <div style={{ ...lbl, visibility: 'hidden' }}>_</div>
          <Form.Item name="cancelled" valuePropName="checked" style={fi}>
            <Checkbox disabled={alwaysDisabled}>Cancelled</Checkbox>
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Cancellation Date</div>
          <Form.Item name="cancelDate" style={fi}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={alwaysDisabled} placeholder="—" />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Reason</div>
          <Form.Item name="cancelReason" style={fi}>
            <Input disabled={alwaysDisabled} placeholder="—" />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Approved</div>
          <Form.Item name="approved" style={fi}>
            <Select disabled={alwaysDisabled} options={[{ value: 'NO', label: 'NO' }, { value: 'YES', label: 'YES' }]} placeholder="—" />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Approved By</div>
          <Form.Item name="approvedBy" style={fi}>
            <Input disabled={alwaysDisabled} placeholder="—" />
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}
