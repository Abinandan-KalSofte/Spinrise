import { useEffect } from 'react'
import { Col, DatePicker, Form, Input, InputNumber, Row, Select } from 'antd'
import type { Dayjs } from 'dayjs'
import dayjs from 'dayjs'
import { TabPanel } from './_fieldKit'
import { formatPoNo } from '../../../types'
import type { ScreenMode, SupplierOption, OrderTypeOption, FormTypeOption, CurrencyOption } from '../../../types'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds, fyPastDisabledDate } from '@/shared/lib/dateUtils'
import { prefixFilterOption, priorityFilterSort } from '@/shared/utils/selectUtils'
import { NON_NEGATIVE_INPUT_PROPS } from '../../../utils/poTransferRules'

// ── Order Details tab (HTML #htab-panel-order) ───────────────────────────────
// Mandatory: Order Type (BR-11), Supplier (BR-12), Currency (BR-13) — validated
// on Save. GSTIN / GST State are auto-filled from the supplier (UX-06); supplier
// selection also re-resolves the server GST route (Q4) via onSupplierChange.
// Order Value is read-only, bound to the computed total (UI-03). PO No is never
// guessed — server allocates on save (CD-03 / UX-04).
// Round Off is now editable — recalculates Order Value / Grand Total live.

const fmt2   = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const round2 = (n: number) => Math.round(n * 100) / 100

const lbl: React.CSSProperties = {
  fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3, whiteSpace: 'nowrap',
}
const req = <span style={{ color: '#ff4d4f', marginRight: 2 }}>*</span>
const full = { width: '100%' }
const fi   = { marginBottom: 0 }

interface OrderDetailsTabProps {
  mode:             ScreenMode
  disabled:         boolean
  poNo:             number | null
  orderValue:       number         // total order value (including GST + charges ± roundoff)
  orderTypes:       OrderTypeOption[]
  suppliers:        SupplierOption[]
  formTypes:        FormTypeOption[]
  currencies:       CurrencyOption[]
  lastPoDate?:      string | null   // CR-024: lower bound for PO Date picker
  onSupplierChange: (s: SupplierOption | null) => void
  onSupplierOpen:   () => void
}

export function OrderDetailsTab({
  mode, disabled, poNo, orderValue, orderTypes, suppliers, formTypes, currencies,
  lastPoDate,
  onSupplierChange, onSupplierOpen,
}: OrderDetailsTabProps) {
  const form = Form.useFormInstance()

  // POT-OD-14: watch currency + currRate to derive the live FC Order Value
  const currencyWatch = (Form.useWatch('currency') as string | undefined) ?? ''
  const currRateWatch = (Form.useWatch('currRate') as number | undefined) ?? 0
  const isNonInr      = !!currencyWatch && currencyWatch !== 'INR'
  const fcOrderValue  = isNonInr && currRateWatch > 0
    ? round2(orderValue / currRateWatch)
    : null

  const processingDate = useAuthStore((s) => s.processingDate)
  const today    = dayjs()
  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const fyStart  = dayjs(yfDate)
  const fyEnd    = dayjs(ylDate)
  const poDateVal = form.getFieldValue('poDate') as Dayjs | null

  const poNoText    = mode === 'ADD' ? '' : formatPoNo(poNo)
  const poValueText = fmt2(orderValue)
  useEffect(() => {
    form.setFieldsValue({ poNo: poNoText, poValue: poValueText })
  }, [form, poNoText, poValueText])

  const handleCurrencyChange = (code: string) => {
    const curr = currencies.find((c) => c.currCode === code)
    if (curr) form.setFieldValue('currRate', curr.currRate)
  }

  return (
    <TabPanel>
      <Row gutter={[12, 8]}>
        <Col span={2}>
          <div style={lbl}>PO No.</div>
          <Form.Item name="poNo" style={fi}>
            <Input readOnly placeholder="Auto" style={{ fontFamily: 'monospace', color: '#185FA5' }} />
          </Form.Item>
        </Col>
        <Col span={2}>
          <div style={lbl}>PO Date</div>
          {/* CR-024: disabledDate uses fyPastDisabledDate with lastPoDate lower bound */}
          <Form.Item name="poDate"
            validateTrigger={['onChange', 'onBlur']}
            rules={[{
              validator: (_, val: Dayjs | null) => {
                if (!val) return Promise.reject('PO Date is required.')
                if (val.isBefore(fyStart, 'day') || val.isAfter(fyEnd, 'day'))
                  return Promise.reject(`Date must be within the financial year (${fyStart.format('DD-MMM-YYYY')} – ${fyEnd.format('DD-MMM-YYYY')}).`)
                if (val.isAfter(today, 'day'))
                  return Promise.reject('PO Date cannot be a future date.')
                if (lastPoDate && val.isBefore(dayjs(lastPoDate), 'day'))
                  return Promise.reject(`PO Date cannot be earlier than the last PO date (${dayjs(lastPoDate).format('DD-MMM-YYYY')}).`)
                return Promise.resolve()
              },
            }]}
            style={fi}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled} allowClear={false}
              disabledDate={fyPastDisabledDate(processingDate, lastPoDate)}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Order Type {req}</div>
          <Form.Item name="orderType"
            rules={[{ required: true, message: 'Order Type is required' }]}
            validateTrigger="onBlur" style={fi}>
            <Select
              showSearch optionFilterProp="label" placeholder="Select order type…" disabled={disabled}
              filterSort={priorityFilterSort}
              options={orderTypes.map((t) => ({ value: t.poGrp, label: `${t.poGrp} – ${t.typName}` }))}
            />
          </Form.Item>
        </Col>
        <Col span={10}>
          <div style={lbl}>Supplier {req}</div>
          <Form.Item name="supplier"
            rules={[{ required: true, message: 'Supplier is required' }]}
            validateTrigger="onBlur" style={fi}>
            <Select
              showSearch optionFilterProp="label" placeholder="Select supplier — type to filter…" disabled={disabled}
              filterOption={prefixFilterOption} filterSort={priorityFilterSort}
              onDropdownVisibleChange={(open) => { if (open) onSupplierOpen() }}
              onChange={(v) => onSupplierChange(suppliers.find((s) => s.slCode === v) ?? null)}
              options={suppliers.map((s) => ({ value: s.slCode, label: `${s.slCode} – ${s.slName}${s.city ? ` – ${s.city}` : ''}` }))}
            />
          </Form.Item>
        </Col>
        <Col span={3}>
          <div style={lbl}>GSTIN</div>
          <Form.Item name="gstin" style={fi}>
            <Input readOnly placeholder="Auto" style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>
        <Col span={3}>
          <div style={lbl}>GST State</div>
          <Form.Item name="gstState" style={fi}>
            <Input readOnly placeholder="Auto" style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </Col>

        <Col span={4}>
          <div style={lbl}>Inspect</div>
          <Form.Item name="inspect" style={fi}>
            <Select disabled={disabled} options={[{ value: 'YES', label: 'Yes' }, { value: 'NO', label: 'No' }]} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Form Type</div>
          <Form.Item name="formType" style={fi}>
            <Select allowClear placeholder="03 — NONE" disabled={disabled} optionFilterProp="label"
              options={formTypes.map((f) => ({ value: f.formCode, label: `${f.formCode} – ${f.formName}` }))} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Ref. No.</div>
          <Form.Item name="refNo" style={fi}>
            <Input placeholder="Optional" disabled={disabled} />
          </Form.Item>
        </Col>
        {/* CR-025 / CR-028: Ref Date cannot be a future date and must be within FY */}
        <Col span={4}>
          <div style={lbl}>Ref. Date</div>
          <Form.Item name="refDate"
            validateTrigger={['onChange', 'onBlur']}
            rules={[{
              validator: (_, val: Dayjs | null) => {
                if (!val) return Promise.resolve()
                if (val.isBefore(fyStart, 'day') || val.isAfter(fyEnd, 'day'))
                  return Promise.reject(`Ref. Date must be within the financial year (${fyStart.format('DD-MMM-YYYY')} – ${fyEnd.format('DD-MMM-YYYY')}).`)
                if (val.isAfter(today, 'day'))
                  return Promise.reject('Reference Date cannot be a future date.')
                return Promise.resolve()
              },
            }]}
            style={fi}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled}
              disabledDate={(d) => {
                if (d.isBefore(fyStart, 'day') || d.isAfter(fyEnd, 'day')) return true
                if (d.isAfter(today, 'day')) return true
                if (poDateVal && d.isAfter(poDateVal, 'day')) return true
                return false
              }}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Round Off</div>
          <Form.Item name="roundOff" style={fi}>
            <InputNumber
              precision={2} controls={false} disabled={disabled}
              style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Order Value (₹)</div>
          <Form.Item name="poValue" style={fi}>
            <Input readOnly style={{ fontFamily: 'monospace', color: '#185FA5', textAlign: 'right' }} />
          </Form.Item>
        </Col>

        <Col span={4}>
          <div style={lbl}>Currency</div>
          <Form.Item name="currency" style={fi}>
            <Select
              showSearch optionFilterProp="label" allowClear
              placeholder="Select currency…" disabled={disabled}
              onChange={handleCurrencyChange}
              options={currencies.map((c) => ({ value: c.currCode, label: `${c.currCode} – ${c.currName}` }))}
              notFoundContent={currencies.length === 0 ? 'Loading currencies…' : 'Not found'}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Curr. Rate</div>
          <Form.Item name="currRate" style={fi}>
            <InputNumber {...NON_NEGATIVE_INPUT_PROPS} disabled precision={4} controls={false}
              style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} />
          </Form.Item>
        </Col>
        {isNonInr && (
          <Col span={4}>
            <div style={lbl}>Order Value ({currencyWatch})</div>
            <Form.Item style={fi}>
              <Input
                readOnly
                value={fcOrderValue !== null ? fmt2(fcOrderValue) : '—'}
                style={{ fontFamily: 'monospace', color: '#B45309', textAlign: 'right' }}
              />
            </Form.Item>
          </Col>
        )}
        <Col span={8}>
          <div style={lbl}>Remarks</div>
          <Form.Item name="remarks" style={fi}>
            <Input placeholder="Optional remarks" disabled={disabled} />
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}
