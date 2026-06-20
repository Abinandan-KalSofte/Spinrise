import { Col, DatePicker, Form, Input, InputNumber, Row, Select } from 'antd'
import type { Dayjs } from 'dayjs'
import dayjs from 'dayjs'
import { TabPanel } from './_fieldKit'
import type { CarrierOption, AddressOption } from '../../../types'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds, getFYEndDate, fyFutureDisabledDate } from '@/shared/lib/dateUtils'
import { prefixFilterOption, priorityFilterSort } from '@/shared/utils/selectUtils'
import { NON_NEGATIVE_INPUT_PROPS } from '../../../utils/poTransferRules'

// ── Instructions tab (HTML #htab-panel-instructions) ─────────────────────────
// Carrier is mandatory (BR-14, validated on Save). Pricing Terms becomes
// mandatory when Order Type = 'HO' (BR-15) — enforced in the hook, not here.
// Delivery Location, Billing Address, Pricing Terms are lookup Selects
// (CODE — DESCRIPTION format); only the code is stored/sent in the payload.

interface InstructionsTabProps {
  disabled:          boolean
  carriers:          CarrierOption[]
  deliveryLocations: AddressOption[]
  billingAddresses:  AddressOption[]
  pricingTermsOpts:  AddressOption[]
}

const lbl: React.CSSProperties = {
  fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3, whiteSpace: 'nowrap',
}
const req = <span style={{ color: '#ff4d4f', marginRight: 2 }}>*</span>
const full = { width: '100%' }
const fi   = { marginBottom: 0 }

export function InstructionsTab({ disabled, carriers, deliveryLocations, billingAddresses, pricingTermsOpts }: InstructionsTabProps) {
  // CR-027 / CR-028: FY bounds for delivery date (full FY end — future dates allowed)
  const processingDate = useAuthStore((s) => s.processingDate)
  const today     = dayjs()
  const { yfDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const fyStart   = dayjs(yfDate)
  const fyEndFull = dayjs(getFYEndDate(processingDate))

  return (
    <TabPanel>
      <Row gutter={[12, 8]}>
        <Col span={6}>
          <div style={lbl}>{req}Carrier</div>
          {/* CR-034: Carrier is mandatory. No default — starts blank in ADD mode.
              BR-14 is enforced here (field-level) AND at save time in the hook. */}
          <Form.Item name="carrier"
            validateTrigger="onBlur"
            rules={[{ required: true, message: 'Please select Carrier.' }]}
            style={fi}>
            <Select showSearch optionFilterProp="label" placeholder="Select carrier…"
              allowClear disabled={disabled}
              filterOption={prefixFilterOption} filterSort={priorityFilterSort}
              options={carriers.map((c) => ({ value: c.carCode, label: `${c.carCode} – ${c.carName}` }))} />
          </Form.Item>
        </Col>
        <Col span={7}>
          <div style={lbl}>Delivery Location</div>
          <Form.Item name="deliveryLocation" style={fi}>
            <Select
              showSearch optionFilterProp="label" allowClear
              placeholder="Select delivery location…" disabled={disabled}
              filterOption={prefixFilterOption} filterSort={priorityFilterSort}
              options={deliveryLocations.map((l) => ({ value: l.code, label: `${l.code} – ${l.name}` }))}
              notFoundContent={deliveryLocations.length === 0 ? 'Loading…' : 'Not found'}
            />
          </Form.Item>
        </Col>
        <Col span={7}>
          <div style={lbl}>Billing Address</div>
          <Form.Item name="billingAddress" style={fi}>
            <Select
              showSearch optionFilterProp="label" allowClear
              placeholder="Select billing address…" disabled={disabled}
              filterOption={prefixFilterOption} filterSort={priorityFilterSort}
              options={billingAddresses.map((a) => ({ value: a.code, label: `${a.code} – ${a.name}` }))}
              notFoundContent={billingAddresses.length === 0 ? 'Loading…' : 'Not found'}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Credit Days</div>
          <Form.Item name="creditDays" style={fi}>
            <InputNumber {...NON_NEGATIVE_INPUT_PROPS} controls={false} disabled={disabled}
              style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} />
          </Form.Item>
        </Col>

        {/* CR-027 / CR-028: Delivery Date must be today or future, within active FY */}
        <Col span={4}>
          <div style={lbl}>Delivery Date</div>
          <Form.Item name="deliveryDate"
            validateTrigger={['onChange', 'onBlur']}
            rules={[{
              validator: (_, val: Dayjs | null) => {
                if (!val) return Promise.resolve()
                if (val.isBefore(fyStart, 'day') || val.isAfter(fyEndFull, 'day'))
                  return Promise.reject(`Delivery Date must be within the active financial year (${fyStart.format('DD-MMM-YYYY')} – ${fyEndFull.format('DD-MMM-YYYY')}).`)
                if (val.isBefore(today, 'day'))
                  return Promise.reject('Delivery Date must be greater than or equal to today\'s date.')
                return Promise.resolve()
              },
            }]}
            style={fi}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled}
              disabledDate={fyFutureDisabledDate(processingDate)}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Special Instruction</div>
          <Form.Item name="specialInstr" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Despatch</div>
          <Form.Item name="despatch" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Purpose</div>
          <Form.Item name="purpose" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Other Levies</div>
          <Form.Item name="otherLevies" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>

        <Col span={4}>
          <div style={lbl}>Pricing Terms</div>
          <Form.Item name="pricingTerms" style={fi}>
            <Select
              showSearch optionFilterProp="label" allowClear
              placeholder="Mandatory for HO order type" disabled={disabled}
              filterOption={prefixFilterOption} filterSort={priorityFilterSort}
              options={pricingTermsOpts.map((p) => ({ value: p.code, label: `${p.code} – ${p.name}` }))}
              notFoundContent={pricingTermsOpts.length === 0 ? 'Loading…' : 'Not found'}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Packing &amp; Forwarding</div>
          <Form.Item name="packForwarding" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Insurance</div>
          <Form.Item name="insurance" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <div style={lbl}>Freight</div>
          <Form.Item name="freight" style={fi}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}
