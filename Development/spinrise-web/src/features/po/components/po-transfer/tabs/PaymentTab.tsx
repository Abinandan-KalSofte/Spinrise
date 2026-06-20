import { Col, DatePicker, Form, Input, InputNumber, Radio, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'
import type { BankOption, PayTermOption } from '../../../types'
import { NON_NEGATIVE_INPUT_PROPS } from '../../../utils/poTransferRules'

// ── Payment tab (HTML #htab-panel-payment) ───────────────────────────────────
// Mode radio toggles Direct vs Bank field sets. BR-15 (Bank → Bank Code +
// Cheque No.; HO → Pricing Terms) is enforced in the hook at Save, not here.

interface PaymentTabProps {
  disabled:   boolean
  banks:      BankOption[]
  payTerms:   PayTermOption[]
  // POT-PM-04: Order Value is required to validate Advance Amount <= Order Value
  orderValue: number
}

const lbl: React.CSSProperties = {
  fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3, whiteSpace: 'nowrap',
}
const full = { width: '100%' }
const fi   = { marginBottom: 0 }

export function PaymentTab({ disabled, banks, payTerms, orderValue }: PaymentTabProps) {
  const payMode = (Form.useWatch('payMode') as string | undefined) ?? 'DIRECT'
  const isBank = payMode === 'BANK'

  // POT-PM-04: Advance Amount must not exceed the current Order Value
  const advAmtRule = {
    validator: (_: unknown, value: number | null | undefined) => {
      if (value === null || value === undefined || value === 0) return Promise.resolve()
      if (Number(value) > orderValue)
        return Promise.reject(new Error('Advance Amount cannot exceed Order Value.'))
      return Promise.resolve()
    },
  }

  return (
    <TabPanel>
      <Row gutter={[12, 8]}>
        <Col span={24}>
          <div style={lbl}>Payment Mode</div>
          <Form.Item name="payMode" style={fi}>
            <Radio.Group disabled={disabled} optionType="button" buttonStyle="outline" size="small"
              options={[{ label: 'Direct', value: 'DIRECT' }, { label: 'Through Bank', value: 'BANK' }]}
            />
          </Form.Item>
        </Col>

        <Col span={6}>
          <div style={lbl}>Payment Term</div>
          <Form.Item name="paymentTermCode" style={fi}>
            <Select
              showSearch allowClear optionFilterProp="label"
              placeholder="Select payment term" disabled={disabled}
              options={payTerms.map((t) => ({ value: t.payTermCode, label: `${t.payTermCode} – ${t.payTermDesc}` }))}
            />
          </Form.Item>
        </Col>

        {!isBank ? (
          <>
            <Col span={5}>
              <div style={lbl}>Direct Instruction</div>
              <Form.Item name="directInstr" style={fi}>
                <Input disabled={disabled} placeholder="Enter payment instruction…" />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Advance Amount</div>
              <Form.Item name="advAmt" style={fi} rules={[advAmtRule]} validateTrigger="onChange">
                <InputNumber {...NON_NEGATIVE_INPUT_PROPS} precision={2} controls={false} disabled={disabled}
                  style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Mode of Payment</div>
              <Form.Item name="modeOfPayment" style={fi}>
                <Select disabled={disabled} options={['NEFT', 'RTGS', 'Cheque', 'Cash'].map((v) => ({ value: v, label: v }))} />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Payment Ref.</div>
              <Form.Item name="payRef" style={fi}>
                <Input disabled={disabled} />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Ref. Date</div>
              <Form.Item name="payRefDate" style={fi}>
                <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} />
              </Form.Item>
            </Col>
          </>
        ) : (
          <>
            <Col span={5}>
              <div style={lbl}>Bank</div>
              <Form.Item name="bankCode" style={fi}>
                <Select showSearch optionFilterProp="label" placeholder="Bank code + name" disabled={disabled}
                  options={banks.map((b) => ({ value: b.bankCode, label: `${b.bankCode} – ${b.bankName}` }))} />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Payment Terms</div>
              <Form.Item name="paymentTerms" style={fi}>
                <Input disabled={disabled} placeholder="e.g. 30 days net" />
              </Form.Item>
            </Col>
            <Col span={3}>
              <div style={lbl}>Advance Amount</div>
              <Form.Item name="advAmt" style={fi} rules={[advAmtRule]} validateTrigger="onChange">
                <InputNumber {...NON_NEGATIVE_INPUT_PROPS} precision={2} controls={false} disabled={disabled}
                  style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} />
              </Form.Item>
            </Col>
            <Col span={3}>
              <div style={lbl}>Mode of Payment</div>
              <Form.Item name="modeOfPayment" style={fi}>
                <Select disabled={disabled} options={['NEFT', 'RTGS', 'LC'].map((v) => ({ value: v, label: v }))} />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Cheque No.</div>
              <Form.Item name="chequeNo" style={fi}>
                <Input disabled={disabled} />
              </Form.Item>
            </Col>
            <Col span={4}>
              <div style={lbl}>Cheque Date</div>
              <Form.Item name="chequeDate" style={fi}>
                <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} />
              </Form.Item>
            </Col>
          </>
        )}
      </Row>
    </TabPanel>
  )
}
