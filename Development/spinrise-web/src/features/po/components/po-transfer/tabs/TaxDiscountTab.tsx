import { useEffect } from 'react'
import { Col, Form, Input, InputNumber, Radio, Row } from 'antd'
import { TabPanel, Section } from './_fieldKit'

// ── Tax / Discount tab (HTML #htab-panel-tax) ────────────────────────────────
// Header-level rates/charges. CGST/SGST/IGST removed from UI per spec — GST
// percentages come from item-level GST Tax Details modal only.
//
// Each charge has both % and Amount fields; entering either recalculates the other
// using lineItemValue (Σ Rate × Qty across all lines) as the base.

interface TaxDiscountTabProps {
  disabled:      boolean
  lineItemValue: number   // Σ Rate × Qty — base for % ↔ Amount calculations
}

const pct = { precision: 2, controls: false as const, style: { width: '100%', fontFamily: 'monospace', textAlign: 'right' as const } }
const mb  = { marginBottom: 8 }
const round2 = (n: number) => Math.round(n * 100) / 100

export function TaxDiscountTab({ disabled, lineItemValue }: TaxDiscountTabProps) {
  const form = Form.useFormInstance()

  const base = lineItemValue || 0

  const onPerChange = (amtField: string, value: number | string | null) => {
    const per = Number(value) || 0
    form.setFieldValue(amtField, round2(per * base / 100))
  }

  const onAmtChange = (perField: string, value: number | string | null) => {
    const amt = Number(value) || 0
    const per = base > 0 ? round2(amt / base * 100) : 0
    form.setFieldValue(perField, per)
  }

  // When lines are added/removed, the base (Σ Rate×Qty) changes. Re-derive all
  // charge amounts from the currently-stored % values so the amounts stay in sync.
  // Guard on disabled: in VIEW mode the base prop changes when a record is loaded,
  // and we must NOT overwrite the server-authoritative amounts with client-derived ones.
  useEffect(() => {
    if (disabled || base === 0) return
    const v = form.getFieldsValue([
      'discPer', 'freightPer', 'packPer', 'insurPer', 'addTaxPer', 'cessPer',
    ])
    form.setFieldsValue({
      discAmt:      round2((Number(v.discPer)    || 0) * base / 100),
      freightAmt:   round2((Number(v.freightPer) || 0) * base / 100),
      packAmt:      round2((Number(v.packPer)    || 0) * base / 100),
      insurAmt:     round2((Number(v.insurPer)   || 0) * base / 100),
      addTaxAmtHdr: round2((Number(v.addTaxPer)  || 0) * base / 100),
      cessAmt:      round2((Number(v.cessPer)    || 0) * base / 100),
    })
  }, [lineItemValue]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <TabPanel>
      {/* Tax Rates — TCS only (CGST/SGST/IGST come from item-level GST modal) */}
      <Section label="Tax Rates" />
      <Row gutter={[12, 0]}>
        <Col span={2}><Form.Item name="tcsPer" label="TCS %" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={2}><Form.Item name="fcaFob" label="FCA / FOB" style={mb}><InputNumber {...pct} disabled={disabled} /></Form.Item></Col>
        <Col span={3}><Form.Item name="fileNo" label="File No." style={mb}><Input disabled={disabled} style={{ fontFamily: 'monospace' }} /></Form.Item></Col>
      </Row>

      {/* Deductions & Charges — dual % + Amount fields */}
      <Section label="Deductions &amp; Charges" />
      <Row gutter={[12, 0]}>
        <Col span={2}>
          <Form.Item name="discPer" label="Discount %" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onPerChange('discAmt', v)} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <Form.Item name="discAmt" label="Discount Amount" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onAmtChange('discPer', v)} />
          </Form.Item>
        </Col>

        <Col span={2}>
          <Form.Item name="freightPer" label="Freight %" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onPerChange('freightAmt', v)} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <Form.Item name="freightAmt" label="Freight Amount" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onAmtChange('freightPer', v)} />
          </Form.Item>
        </Col>

        <Col span={2}>
          <Form.Item name="packPer" label="Packing %" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onPerChange('packAmt', v)} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <Form.Item name="packAmt" label="Packing Amount" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onAmtChange('packPer', v)} />
          </Form.Item>
        </Col>

        <Col span={2}>
          <Form.Item name="insurPer" label="Insurance %" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onPerChange('insurAmt', v)} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <Form.Item name="insurAmt" label="Insurance Amount" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onAmtChange('insurPer', v)} />
          </Form.Item>
        </Col>

        <Col span={2}>
          <Form.Item name="addTaxPer" label="Add. Tax %" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onPerChange('addTaxAmtHdr', v)} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <Form.Item name="addTaxAmtHdr" label="Add. Tax Amount" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onAmtChange('addTaxPer', v)} />
          </Form.Item>
        </Col>

        <Col span={2}>
          <Form.Item name="cessPer" label="Cess %" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onPerChange('cessAmt', v)} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <Form.Item name="cessAmt" label="Cess Amount" style={mb}>
            <InputNumber {...pct} disabled={disabled}
              onChange={(v) => onAmtChange('cessPer', v)} />
          </Form.Item>
        </Col>
      </Row>

      {/* Applicability */}
      <Section label="Applicability" />
      <Row gutter={[12, 0]}>
        <Col span={3}>
          <Form.Item name="freightType" label="Freight Payment" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="PAID">Paid</Radio>
              <Radio value="TOPAY">To Pay</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={3}>
          <Form.Item name="freightPos" label="Freight Position" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio>
              <Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={3}>
          <Form.Item name="discApp" label="Discount Application" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio>
              <Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={3}>
          <Form.Item name="packApp" label="Packing Charge" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio>
              <Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="insuranceDuty" label="Insurance Position" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Duty</Radio>
              <Radio value="AFTER">After Duty</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={3}>
          <Form.Item name="cessTaxPos" label="Cess Position" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="BEFORE">Before Tax</Radio>
              <Radio value="AFTER">After Tax</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
        <Col span={3}>
          <Form.Item name="exciseIncPacking" label="Excise Include Packing" style={mb}>
            <Radio.Group disabled={disabled}>
              <Radio value="Y">Yes</Radio>
              <Radio value="N">No</Radio>
            </Radio.Group>
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}
