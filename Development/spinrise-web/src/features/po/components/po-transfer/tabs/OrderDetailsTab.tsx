import { useEffect } from 'react'
import { Col, DatePicker, Form, Input, InputNumber, Row, Select } from 'antd'
import { TabPanel } from './_fieldKit'
import { formatPoNo } from '../../../types'
import type { ScreenMode, SupplierOption, OrderTypeOption, FormTypeOption } from '../../../types'

// ── Order Details tab (HTML #htab-panel-order) ───────────────────────────────
// Mandatory: Order Type (BR-11), Supplier (BR-12), Currency (BR-13) — validated
// on Save. GSTIN / GST State are auto-filled from the supplier (UX-06); supplier
// selection also re-resolves the server GST route (Q4) via onSupplierChange.
// Order Value is read-only, bound to the computed total (UI-03). PO No is never
// guessed — server allocates on save (CD-03 / UX-04).

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

interface OrderDetailsTabProps {
  mode:             ScreenMode
  disabled:         boolean
  poNo:             number | null
  orderValue:       number
  orderTypes:       OrderTypeOption[]
  suppliers:        SupplierOption[]
  formTypes:        FormTypeOption[]
  onSupplierChange: (s: SupplierOption | null) => void
  onSupplierOpen:   () => void
}

export function OrderDetailsTab({
  mode, disabled, poNo, orderValue, orderTypes, suppliers, formTypes,
  onSupplierChange, onSupplierOpen,
}: OrderDetailsTabProps) {
  const form = Form.useFormInstance()

  // Single source of truth: PO No. and Order Value are READ-ONLY mirrors of the
  // hook's `currentPo.poNo` and computed `orderValue` (same values feeding the
  // Doc Band and KPI strip). We push them into the form's poNo / poValue fields
  // so the read-only inputs render via form state — no duplicate calculation.
  // CD-03: blank (placeholder) until the server allocates a number on save.
  const poNoText = mode === 'ADD' ? '' : formatPoNo(poNo)
  const poValueText = fmt2(orderValue)
  useEffect(() => {
    form.setFieldsValue({ poNo: poNoText, poValue: poValueText })
  }, [form, poNoText, poValueText])

  return (
    <TabPanel>
      <Row gutter={[12, 0]}>
        <Col span={4}>
        <Form.Item name="poNo" label="PO No." style={mb}>
          <Input readOnly placeholder="Auto-generated on save" style={{ fontFamily: 'monospace', color: '#185FA5' }} />
        </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="poDate" label="PO Date" style={mb}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} allowClear={false} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="orderType" label="Order Type" required
            rules={[{ required: true, message: 'Order Type is required' }]} style={mb}>
            <Select
              showSearch optionFilterProp="label" placeholder="Select order type…" disabled={disabled}
              options={orderTypes.map((t) => ({ value: t.poGrp, label: `${t.poGrp} — ${t.typName}` }))}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="supplier" label="Supplier" required
            rules={[{ required: true, message: 'Supplier is required' }]} style={mb}>
            <Select
              showSearch optionFilterProp="label" placeholder="Select supplier — type to filter…" disabled={disabled}
              onDropdownVisibleChange={(open) => { if (open) onSupplierOpen() }}
              onChange={(v) => onSupplierChange(suppliers.find((s) => s.slCode === v) ?? null)}
              options={suppliers.map((s) => ({ value: s.slCode, label: `${s.slCode} — ${s.slName}` }))}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="gstin" label="GSTIN" style={mb}>
            <Input readOnly placeholder="Auto-filled from supplier" style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="gstState" label="GST State" style={mb}>
            <Input readOnly placeholder="Auto" style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="inspect" label="Inspect" style={mb}>
            <Select disabled={disabled} options={[{ value: 'YES', label: 'YES' }, { value: 'NO', label: 'NO' }]} />
          </Form.Item>
        </Col>
        <Col span={4}>
        <Form.Item name="poValue" label="Order Value (₹)" style={mb}>
          <Input readOnly style={{ fontFamily: 'monospace', color: '#185FA5' }} />
        </Form.Item>
        </Col>

        <Col span={4}>
          <Form.Item name="formType" label="Form Type" style={mb}>
            <Select allowClear placeholder="03 — NONE" disabled={disabled} optionFilterProp="label"
              options={formTypes.map((f) => ({ value: f.formCode, label: `${f.formCode} — ${f.formName}` }))} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="refNo" label="Ref. No." style={mb}>
            <Input placeholder="Optional" disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="refDate" label="Ref. Date" style={mb}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="roundOff" label="Round Off" style={mb}>
            <InputNumber readOnly precision={2} controls={false} style={{ ...full, fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>

        <Col span={4}>
          <Form.Item name="currency" label="Currency" required
            rules={[{ required: true, message: 'Currency is required' }]} style={mb}>
            <Input disabled={mode === 'VIEW'} style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="currRate" label="Curr. Rate" style={mb}>
            <InputNumber disabled={disabled} precision={4} controls={false} style={{ ...full, fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>
        <Col span={8}>
          <Form.Item name="remarks" label="Remarks" style={mb}>
            <Input placeholder="Optional remarks" disabled={disabled} />
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}

const mb = { marginBottom: 8 }
const full = { width: '100%' }
