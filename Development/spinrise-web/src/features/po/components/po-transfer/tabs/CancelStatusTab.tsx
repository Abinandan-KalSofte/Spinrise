import { Checkbox, Col, DatePicker, Form, Input, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'

// ── Cancel / Status tab (HTML #htab-panel-cancel) ────────────────────────────
// Sprint 1 business decision: this tab is VIEW-ONLY in all modes (ADD, VIEW,
// DELETE). No edits are permitted here — cancellation is handled on a
// dedicated screen (out of scope for Sprint 1).

interface CancelStatusTabProps { disabled: boolean }

const mb   = { marginBottom: 8 }
const full = { width: '100%' }

export function CancelStatusTab({ disabled: _disabled }: CancelStatusTabProps) {
  // Always read-only — Sprint 1 decision. The prop is retained in the interface
  // so PoHeaderTabs requires no change; it is intentionally unused here.
  const alwaysDisabled = true

  return (
    <TabPanel>
      <Row gutter={[12, 0]} align="bottom">
        <Col span={4}><Form.Item name="reminder" label="Reminder" style={mb}><Input placeholder="—" disabled={alwaysDisabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="status" label="Status" style={mb}><Input placeholder="—" disabled={alwaysDisabled} style={{ fontFamily: 'monospace' }} /></Form.Item></Col>
        <Col span={2}>
          <Form.Item name="cancelled" valuePropName="checked" label=" " colon={false} style={mb}>
            <Checkbox disabled={alwaysDisabled}>Cancelled</Checkbox>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="cancelDate" label="Cancellation Date" style={mb}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={alwaysDisabled} placeholder="—" />
          </Form.Item>
        </Col>
        <Col span={4}><Form.Item name="cancelReason" label="Reason" style={mb}><Input disabled={alwaysDisabled} placeholder="—" /></Form.Item></Col>
        <Col span={4}>
          <Form.Item name="approved" label="Approved" style={mb}>
            <Select disabled={alwaysDisabled} options={[{ value: 'NO', label: 'NO' }, { value: 'YES', label: 'YES' }]} placeholder="—"/>
          </Form.Item>
        </Col>
        <Col span={4}><Form.Item name="approvedBy" label="Approved By" style={mb}><Input disabled={alwaysDisabled} placeholder="—"/></Form.Item></Col>
      </Row>
    </TabPanel>
  )
}
