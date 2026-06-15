import { Col, DatePicker, Form, Input, InputNumber, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'
import type { CarrierOption } from '../../../types'

// ── Instructions tab (HTML #htab-panel-instructions) ─────────────────────────
// Carrier is mandatory (BR-14, validated on Save). Pricing Terms becomes
// mandatory when Order Type = 'HO' (BR-15) — enforced in the hook, not here.

interface InstructionsTabProps {
  disabled: boolean
  carriers: CarrierOption[]
}

const mb = { marginBottom: 8 }
const full = { width: '100%' }

export function InstructionsTab({ disabled, carriers }: InstructionsTabProps) {
  return (
    <TabPanel>
      <Row gutter={[12, 0]}>
        <Col span={4}>
          <Form.Item name="carrier" label="Carrier" required
            rules={[{ required: true, message: 'Carrier is required' }]} style={mb}>
            <Select showSearch optionFilterProp="label" placeholder="02 — COURIER" disabled={disabled}
              options={carriers.map((c) => ({ value: c.carCode, label: `${c.carCode} — ${c.carName}` }))} />
          </Form.Item>
        </Col>
        <Col span={4}><Form.Item name="creditDays" label="Credit Days" style={mb}><InputNumber min={0} controls={false} disabled={disabled} style={{ ...full, fontFamily: 'monospace' }} /></Form.Item></Col>
        <Col span={4}><Form.Item name="deliveryDate" label="Delivery Date" style={mb}><DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="deliveryLocation" label="Delivery Location" style={mb}><Input disabled={disabled} /></Form.Item></Col>
      
        <Col span={4}><Form.Item name="billingAddress" label="Billing Address" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="specialInstr" label="Special Instruction" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="despatch" label="Despatch" style={mb}><Input disabled={disabled} /></Form.Item></Col>
      
        <Col span={4}><Form.Item name="purpose" label="Purpose" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="otherLevies" label="Other Levies" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="pricingTerms" label="Pricing Terms" style={mb}><Input disabled={disabled} placeholder="Mandatory for HO order type" /></Form.Item></Col>
     
        <Col span={4}><Form.Item name="packForwarding" label="Packing & Forwarding" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="insurance" label="Insurance" style={mb}><Input disabled={disabled} /></Form.Item></Col>
        <Col span={4}><Form.Item name="freight" label="Freight" style={mb}><Input disabled={disabled} /></Form.Item></Col>
      </Row>
    </TabPanel>
  )
}
