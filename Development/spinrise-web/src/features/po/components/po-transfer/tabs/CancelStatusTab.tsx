import { Checkbox, Col, DatePicker, Form, Input, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'

// ── Cancel / Status tab (HTML #htab-panel-cancel) ────────────────────────────
// PO cancellation is handled on a separate screen (out of scope here); these
// fields are bound pass-through and read-only outside ADD. The Cancelled
// checkbox toggles the Cancellation Date field per the mockup.

interface CancelStatusTabProps { disabled: boolean }

const mb = { marginBottom: 8 }
const full = { width: '100%' }

export function CancelStatusTab({ disabled }: CancelStatusTabProps) {
  const cancelled = Boolean(Form.useWatch('cancelled'))

  return (
    <TabPanel>
      <Row gutter={[12, 0]} align="bottom">
        <Col span={4}><Form.Item name="reminder" label="Reminder" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="status" label="Status" style={mb}><Input disabled={disabled} style={{ fontFamily: 'monospace' }} /></Form.Item></Col>
        <Col span={2}>
          <Form.Item name="cancelled" valuePropName="checked" label=" " colon={false} style={mb}>
            <Checkbox disabled={disabled}>Cancelled</Checkbox>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="cancelDate" label="Cancellation Date" style={mb}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled || !cancelled} />
          </Form.Item>
        </Col>
        <Col span={4}><Form.Item name="cancelReason" label="Reason" style={mb}><Input disabled={disabled} placeholder="Enter cancellation reason" /></Form.Item></Col>
        <Col span={4}>
          <Form.Item name="approved" label="Approved" style={mb}>
            <Select disabled={disabled} options={[{ value: 'NO', label: 'NO' }, { value: 'YES', label: 'YES' }]} />
          </Form.Item>
        </Col>
        <Col span={4}><Form.Item name="approvedBy" label="Approved By" style={mb}><Input disabled={disabled} /></Form.Item></Col>
      </Row>
    </TabPanel>
  )
}
