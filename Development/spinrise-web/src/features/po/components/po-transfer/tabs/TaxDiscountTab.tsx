import { useEffect } from 'react'
import { Col, Form, Input, InputNumber, Radio, Row } from 'antd'
import { TabPanel, Section } from './_fieldKit'
import { NON_NEGATIVE_INPUT_PROPS, clampNonNegativeNumber } from '../../../utils/poTransferRules'
import { notificationService } from '@/shared/lib/notification'

// ── Tax / Discount tab (HTML #htab-panel-tax) ────────────────────────────────
// CR-026: Deductions & Charges now use a compact paired layout — each charge
// shows its label once with % and Amount inputs side by side beneath it.
// All calculations and API mappings are unchanged from Sprint 1.

interface TaxDiscountTabProps {
  disabled:      boolean
  lineItemValue: number   // Σ Rate × Qty — base for % ↔ Amount calculations
}

const pct = {
  ...NON_NEGATIVE_INPUT_PROPS,
  precision: 2,
  controls: false as const,
  style: { width: '100%', fontFamily: 'monospace', textAlign: 'right' as const },
}
const mb  = { marginBottom: 8 }
const round2 = (n: number) => Math.round(n * 100) / 100

const CHARGES: { label: string; perName: string; amtName: string }[] = [
  { label: 'Discount',  perName: 'discPer',    amtName: 'discAmt'    },
  { label: 'Packing',   perName: 'packPer',    amtName: 'packAmt'    },
  { label: 'Freight',   perName: 'freightPer', amtName: 'freightAmt' },
  { label: 'Insurance', perName: 'insurPer',   amtName: 'insurAmt'   },
  { label: 'Cess',      perName: 'cessPer',    amtName: 'cessAmt'    },
]

export function TaxDiscountTab({ disabled, lineItemValue }: TaxDiscountTabProps) {
  const form = Form.useFormInstance()

  const base = lineItemValue || 0

  const onPerChange = (perField: string, amtField: string, value: number | string | null) => {
    if (base <= 0) {
      notificationService.warning('No Line Items', 'Please add PO line items before entering charges.')
      // Reset both fields so no stale value remains
      form.setFieldsValue({ [perField]: 0, [amtField]: 0 })
      return
    }
    const per = clampNonNegativeNumber(value)
    const amt = round2(per * base / 100)
    if (!Number.isFinite(amt)) return
    form.setFieldValue(amtField, amt)
  }

  const onAmtChange = (perField: string, amtField: string, value: number | string | null) => {
    if (base <= 0) {
      notificationService.warning('No Line Items', 'Please add PO line items before entering charges.')
      // Reset both fields so no stale value remains
      form.setFieldsValue({ [perField]: 0, [amtField]: 0 })
      return
    }
    const amt = clampNonNegativeNumber(value)
    const per = round2(amt / base * 100)
    if (!Number.isFinite(per)) return
    form.setFieldValue(perField, per)
  }

  // When lines are added/removed, the base (Σ Rate×Qty) changes. Re-derive all
  // charge amounts from the currently-stored % values so the amounts stay in sync.
  // Guard on disabled: in VIEW mode the base prop changes when a record is loaded,
  // and we must NOT overwrite the server-authoritative amounts with client-derived ones.
  useEffect(() => {
    if (disabled || base === 0) return
    const v = form.getFieldsValue([
      'discPer', 'freightPer', 'packPer', 'insurPer', 'cessPer',
    ])
    form.setFieldsValue({
      discAmt:    round2((Number(v.discPer)    || 0) * base / 100),
      freightAmt: round2((Number(v.freightPer) || 0) * base / 100),
      packAmt:    round2((Number(v.packPer)    || 0) * base / 100),
      insurAmt:   round2((Number(v.insurPer)   || 0) * base / 100),
      cessAmt:    round2((Number(v.cessPer)    || 0) * base / 100),
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

      {/* CR-026: Deductions & Charges — compact paired layout */}
      <Section label="Deductions &amp; Charges" />
      <div
  style={{
    display: 'grid',
    gridTemplateColumns: 'repeat(5, minmax(180px, 1fr))',
    gap: '12px',
    padding: '2px 0 10px',
  }}
>
  {CHARGES.map(({ label, perName, amtName }) => (
    <div
      key={perName}
    >
      <div
        style={{
          fontSize: 11,
          fontWeight: 600,
          color: '#475569',
          marginBottom: 6,
        }}
      >
        {label}
      </div>

      <div style={{ display: 'flex', gap: 6 }}>
        <Form.Item
          name={perName}
          style={{ marginBottom: 0, flex: 1 }}
        >
          <InputNumber
            {...pct}
            addonAfter="%"
            disabled={disabled}
            onChange={(v) => onPerChange(perName, amtName, v)}
          />
        </Form.Item>

        <Form.Item
          name={amtName}
          style={{ marginBottom: 0, flex: 1 }}
        >
          <InputNumber
            {...pct}
            addonAfter="₹"
            disabled={disabled}
            onChange={(v) => onAmtChange(perName, amtName, v)}
          />
        </Form.Item>
      </div>
    </div>
  ))}
</div>

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
