import { Col, Form, Input, InputNumber, Radio, Row } from 'antd'
import { TabPanel, Section } from './_fieldKit'

// ── Tax / Discount tab (HTML #htab-panel-tax) ────────────────────────────────
// Header-level rates/charges. Header → line tax propagation is performed by the
// SERVER (D-05 / Q5) via the hook's propagateHeaderTax handler — this tab only
// binds the input values; it runs NO client-side propagation or calculation.
//
// GST-based taxation only. Pre-GST AED / Surcharge / Cess inputs (D-11) are NOT
// FOR SPINRISE and have been removed.

interface TaxDiscountTabProps { disabled: boolean }

const pct = { precision: 2, controls: false as const, style: { width: '100%', fontFamily: 'monospace' } }
const mb = { marginBottom: 8 }

export function TaxDiscountTab({ disabled }: TaxDiscountTabProps) {
  return (
    <TabPanel>
      <Section label="Tax Rates" />
      <Row gutter={[12, 0]}>
        <Col span={3}><Form.Item name="cgstPer" label="CGST %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="sgstPer" label="SGST %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="igstPer" label="IGST %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="tcsPer"  label="TCS %"  style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
      </Row>

      <Section label="Deductions & Charges" />
      <Row gutter={[12, 0]}>
        <Col span={3}><Form.Item name="discPer" label="Discount %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="freightAmt" label="Freight Amt." style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="packPer" label="Packing %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="insurPer" label="Insurance %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="addTaxPer" label="Add. Tax %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="fileNo" label="File No." style={mb}><Input disabled={disabled} style={{ fontFamily: 'monospace' }} /></Form.Item></Col>
        <Col span={3}><Form.Item name="fcaFob" label="FCA / FOB" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
      </Row>

      <Section label="Applicability" />
      <Row gutter={[12, 0]}>
        <Col span={4}>
          <Form.Item name="freightType" label="Freight" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="PAID">Paid</Radio><Radio value="TOPAY">To Pay</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="discApp" label="Discount Application" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio><Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="packApp" label="Packing Charge" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio><Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="freightApp" label="Freight Charge" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio><Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="insurApp" label="Insurance Charge" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio><Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}
