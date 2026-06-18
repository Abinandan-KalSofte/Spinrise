import { Col, DatePicker, Form, Input, InputNumber, Radio, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'
import type { BankOption } from '../../../types'
import { NON_NEGATIVE_INPUT_PROPS } from '../../../utils/poTransferRules'

// ── Payment tab (HTML #htab-panel-payment) ───────────────────────────────────
// Mode radio toggles Direct vs Bank field sets. BR-15 (Bank → Bank Code +
// Cheque No.; HO → Pricing Terms) is enforced in the hook at Save, not here.

interface PaymentTabProps {
  disabled: boolean
  banks:    BankOption[]
}

const mb = { marginBottom: 8 }
const full = { width: '100%' }

export function PaymentTab({ disabled, banks }: PaymentTabProps) {
  const payMode = (Form.useWatch('payMode') as string | undefined) ?? 'DIRECT'
  const isBank = payMode === 'BANK'

  return (
    <TabPanel>
      <Row gutter={[12, 0]}>
        <Col span={24}>
          <Form.Item name="payMode" label="Payment Mode" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="DIRECT">Direct</Radio>
              <Radio value="BANK">Through Bank</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
      </Row>

      {!isBank ? (
        <Row gutter={[12, 0]}>
          <Col span={5}><Form.Item name="directInstr" label="Direct Instruction" style={mb}><Input disabled={disabled} placeholder="Enter payment instruction…" /></Form.Item></Col>
          <Col span={4}><Form.Item name="advAmt" label="Advance Amount" style={mb}><InputNumber {...NON_NEGATIVE_INPUT_PROPS} precision={2} controls={false} disabled={disabled} style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} /></Form.Item></Col>
          <Col span={4}><Form.Item name="modeOfPayment" label="Mode of Payment" style={mb}>
            <Select disabled={disabled} options={['NEFT', 'RTGS', 'Cheque', 'Cash'].map((v) => ({ value: v, label: v }))} />
          </Form.Item></Col>
          <Col span={4}><Form.Item name="payRef" label="Payment Ref." style={mb}><Input disabled={disabled} /></Form.Item></Col>
          <Col span={4}><Form.Item name="payRefDate" label="Ref. Date" style={mb}><DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} /></Form.Item></Col>
        </Row>
      ) : (
        <Row gutter={[12, 0]}>
          <Col span={5}><Form.Item name="bankCode" label="Bank" style={mb}>
            <Select showSearch optionFilterProp="label" placeholder="Bank code + name" disabled={disabled}
              options={banks.map((b) => ({ value: b.bankCode, label: `${b.bankCode} – ${b.bankName}` }))} />
          </Form.Item></Col>
          <Col span={4}><Form.Item name="paymentTerms" label="Payment Terms" style={mb}><Input disabled={disabled} placeholder="e.g. 30 days net" /></Form.Item></Col>
          <Col span={3}><Form.Item name="advAmt" label="Advance Amount" style={mb}><InputNumber {...NON_NEGATIVE_INPUT_PROPS} precision={2} controls={false} disabled={disabled} style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} /></Form.Item></Col>
          <Col span={3}><Form.Item name="modeOfPayment" label="Mode of Payment" style={mb}>
            <Select disabled={disabled} options={['NEFT', 'RTGS', 'LC'].map((v) => ({ value: v, label: v }))} />
          </Form.Item></Col>
          <Col span={4}><Form.Item name="chequeNo" label="Cheque No." style={mb}><Input disabled={disabled} /></Form.Item></Col>
          <Col span={4}><Form.Item name="chequeDate" label="Cheque Date" style={mb}><DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} /></Form.Item></Col>
        </Row>
      )}
    </TabPanel>
  )
}
