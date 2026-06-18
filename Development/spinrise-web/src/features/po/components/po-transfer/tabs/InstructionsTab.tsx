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

const mb   = { marginBottom: 8 }
const full = { width: '100%' }

export function InstructionsTab({ disabled, carriers, deliveryLocations, billingAddresses, pricingTermsOpts }: InstructionsTabProps) {
  // CR-027 / CR-028: FY bounds for delivery date (full FY end — future dates allowed)
  const processingDate = useAuthStore((s) => s.processingDate)
  const today     = dayjs()
  const { yfDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const fyStart   = dayjs(yfDate)
  const fyEndFull = dayjs(getFYEndDate(processingDate))

  return (
    <TabPanel>
      <Row gutter={[12, 0]}>
        <Col span={6}>
          {/* CR-034: Carrier is mandatory. No default — starts blank in ADD mode.
              BR-14 is enforced here (field-level) AND at save time in the hook. */}
          <Form.Item name="carrier" label="Carrier" required
            validateTrigger="onBlur"
            rules={[{ required: true, message: 'Please select Carrier.' }]}
            style={mb}>
            <Select showSearch optionFilterProp="label" placeholder="Select carrier…"
              allowClear disabled={disabled}
              filterOption={prefixFilterOption} filterSort={priorityFilterSort}
              options={carriers.map((c) => ({ value: c.carCode, label: `${c.carCode} – ${c.carName}` }))} />
          </Form.Item>
        </Col>        
        <Col span={7}>
          <Form.Item name="deliveryLocation" label="Delivery Location" style={mb}>
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
          <Form.Item name="billingAddress" label="Billing Address" style={mb}>
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
          <Form.Item name="creditDays" label="Credit Days" style={mb}>
            <InputNumber {...NON_NEGATIVE_INPUT_PROPS} controls={false} disabled={disabled}
              style={{ ...full, fontFamily: 'monospace', textAlign: 'right' }} />
          </Form.Item>
        </Col>
        {/* CR-027 / CR-028: Delivery Date must be today or future, within active FY */}
        <Col span={4}>
          <Form.Item name="deliveryDate" label="Delivery Date"
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
            style={mb}>
            <DatePicker format="DD-MMM-YYYY" style={full} disabled={disabled}
              disabledDate={fyFutureDisabledDate(processingDate)}
            />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="specialInstr" label="Special Instruction" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="despatch" label="Despatch" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>

        <Col span={4}>
          <Form.Item name="purpose" label="Purpose" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="otherLevies" label="Other Levies" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="pricingTerms" label="Pricing Terms" style={mb}>
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
          <Form.Item name="packForwarding" label="Packing &amp; Forwarding" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="insurance" label="Insurance" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
        <Col span={4}>
          <Form.Item name="freight" label="Freight" style={mb}>
            <Input disabled={disabled} />
          </Form.Item>
        </Col>
      </Row>
    </TabPanel>
  )
}
