import { useEffect } from 'react'
import { Form, Input, InputNumber, Radio, Tooltip } from 'antd'
import { TabPanel } from './_fieldKit'
import { NON_NEGATIVE_INPUT_PROPS, clampNonNegativeNumber } from '../../../utils/poTransferRules'
import { notificationService } from '@/shared/lib/notification'

// ── Tax / Discount tab (HTML #htab-panel-tax) ────────────────────────────────
// Compact 2-row layout:
//   Row 1 — Tax Rates (TCS, FCA/FOB, File No.) + Deductions (% + ₹ pairs)
//   Row 2 — Applicability (7 toggle groups, Radio.Button style)
// All field names, values, onChange logic and useEffect are unchanged.

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
const round2 = (n: number) => Math.round(n * 100) / 100

const lbl: React.CSSProperties = {
  fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3, whiteSpace: 'nowrap',
}

// useNetBase: true → amount = (lineItemValue − discAmt) × % per POT-TC-01.
// cascadeNet: true → when this field changes, also recompute all useNetBase fields.
const CHARGES: { label: string; perName: string; amtName: string; useNetBase?: boolean; cascadeNet?: boolean }[] = [
  { label: 'Discount',  perName: 'discPer',  amtName: 'discAmt',  cascadeNet: true },
  { label: 'Packing',   perName: 'packPer',  amtName: 'packAmt',  useNetBase: true },
  { label: 'Insurance', perName: 'insurPer', amtName: 'insurAmt', useNetBase: true },
]

const APPLICABILITY: { label: string; name: string; opts: { label: string; value: string }[]; tooltip?: string }[] = [ 
  { label: 'Discount Application', name: 'discApp',         opts: [{ label: 'Before',   value: 'BEFORE' }, { label: 'After',   value: 'AFTER'  }] },
  { label: 'Packing Charge',       name: 'packApp',         opts: [{ label: 'Before',   value: 'BEFORE' }, { label: 'After',   value: 'AFTER'  }] },
  { label: 'Insurance Position',   name: 'insuranceDuty',   opts: [{ label: 'Before Duty', value: 'BEFORE' }, { label: 'After Duty', value: 'AFTER' }],
  tooltip: "Insurance is assessed against customs duty, not tax — hence 'Duty' instead of 'Tax'" },
  { label: 'Freight Payment',      name: 'freightType',     opts: [{ label: 'Paid',     value: 'PAID'  }, { label: 'To Pay',   value: 'TOPAY'  }] },
  { label: 'Freight Position',     name: 'freightPos',      opts: [{ label: 'Before',   value: 'BEFORE' }, { label: 'After',   value: 'AFTER'  }] },
]

export function TaxDiscountTab({ disabled, lineItemValue }: TaxDiscountTabProps) {
  const form = Form.useFormInstance()
  const base = lineItemValue || 0

  // POT-TC-01: insurance & packing net base = lineItemValue − discAmt
  const getEffectiveBase = (useNetBase?: boolean) => {
    if (!useNetBase) return base
    const discAmt = (form.getFieldValue('discAmt') as number) || 0
    return round2(base - discAmt)
  }

  // After computing discAmt, recompute all net-base fields (insurance, packing).
  const cascadeNetBaseFields = (newDiscAmt: number) => {
    const netBase  = round2(base - newDiscAmt)
    const insurPer = (form.getFieldValue('insurPer') as number) || 0
    const packPer  = (form.getFieldValue('packPer')  as number) || 0
    form.setFieldsValue({
      insurAmt: round2(insurPer * netBase / 100),
      packAmt:  round2(packPer  * netBase / 100),
    })
  }

  const onPerChange = (perField: string, amtField: string, value: number | string | null, useNetBase?: boolean, cascadeNet?: boolean) => {
    if (base <= 0) {
      notificationService.warning('No Line Items', 'Please add PO line items before entering charges.')
      form.setFieldsValue({ [perField]: 0, [amtField]: 0 })
      return
    }
    const per = clampNonNegativeNumber(value)
    const amt = round2(per * getEffectiveBase(useNetBase) / 100)
    if (!Number.isFinite(amt)) return
    form.setFieldValue(amtField, amt)
    if (cascadeNet) cascadeNetBaseFields(amt)
  }

  const onAmtChange = (perField: string, amtField: string, value: number | string | null, useNetBase?: boolean, cascadeNet?: boolean) => {
    if (base <= 0) {
      notificationService.warning('No Line Items', 'Please add PO line items before entering charges.')
      form.setFieldsValue({ [perField]: 0, [amtField]: 0 })
      return
    }
    const amt = clampNonNegativeNumber(value)
    const eff = getEffectiveBase(useNetBase)
    const per = eff > 0 ? round2(amt / eff * 100) : 0
    if (!Number.isFinite(per)) return
    form.setFieldValue(perField, per)
    if (cascadeNet) cascadeNetBaseFields(amt)
  }

  useEffect(() => {
    if (disabled || base === 0) return
    const v = form.getFieldsValue(['discPer', 'packPer', 'insurPer'])
    const discAmt   = round2((Number(v.discPer)  || 0) * base       / 100)
    const netAfDisc = round2(base - discAmt)
    form.setFieldsValue({
      discAmt,
      packAmt:  round2((Number(v.packPer)  || 0) * base       / 100),
      insurAmt: round2((Number(v.insurPer) || 0) * netAfDisc  / 100),
    })
  }, [lineItemValue]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <TabPanel>
      {/* ── Row 1: Tax Rates + Deductions in a single compact flex row ── */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', flexWrap: 'wrap' }}>

        {/* Tax rate fields — custom div labels (avoids Form layout="vertical" 22px label overhead) */}
        <div style={{ minWidth: 72, maxWidth: 90 }}>
          <div style={lbl}>TCS %</div>
          <Form.Item name="tcsPer" style={{ marginBottom: 0 }}>
            <InputNumber {...pct} disabled={disabled} />
          </Form.Item>
        </div>
        <div style={{ minWidth: 72, maxWidth: 90 }}>
          <div style={lbl}>FCA / FOB</div>
          <Form.Item name="fcaFob" style={{ marginBottom: 0 }}>
            <InputNumber {...pct} disabled={disabled} />
          </Form.Item>
        </div>
        <div style={{ minWidth: 110, maxWidth: 150 }}>
          <div style={lbl}>File No.</div>
          <Form.Item name="fileNo" style={{ marginBottom: 0 }}>
            <Input disabled={disabled} style={{ fontFamily: 'monospace' }} />
          </Form.Item>
        </div>

        {/* Thin vertical separator */}
        <div style={{ width: 1, background: '#d1d5db', flexShrink: 0, margin: '16px 4px 0', alignSelf: 'stretch' }} />

        {/* Deduction charge pairs (% + ₹) */}
        {CHARGES.map(({ label, perName, amtName, useNetBase, cascadeNet }) => (
          <div key={perName} style={{ flex: 1, minWidth: 155 }}>
            <div style={lbl}>{label}</div>
            <div style={{ display: 'flex', gap: 4 }}>
              <Form.Item name={perName} style={{ marginBottom: 0, flex: 1, minWidth: 0 }}>
                <InputNumber {...pct} addonAfter="%" disabled={disabled}
                  onChange={(v) => onPerChange(perName, amtName, v, useNetBase, cascadeNet)} />
              </Form.Item>
              <Form.Item name={amtName} style={{ marginBottom: 0, flex: 1, minWidth: 0 }}>
                <InputNumber {...pct} addonAfter="₹" disabled={disabled}
                  onChange={(v) => onAmtChange(perName, amtName, v, useNetBase, cascadeNet)} />
              </Form.Item>
            </div>
          </div>
        ))}

        {/* Freight — amount entry only, no % field */}
        <div style={{ flex: 1, minWidth: 90 }}>
          <div style={lbl}>Freight</div>
          <Form.Item name="freightAmt" style={{ marginBottom: 0 }}>
            <InputNumber {...pct} addonAfter="₹" disabled={disabled} />
          </Form.Item>
        </div>
      </div>

      {/* ── Divider ── */}
      <div style={{ borderTop: '1px solid #e2e2e2', margin: '6px 0 5px' }} />

      {/* ── Row 2: Applicability — compact Radio.Button toggle groups ── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(128px, 1fr))', gap: '4px 10px' }}>
        {APPLICABILITY.map(({ label, name, opts, tooltip }) => (
          <div key={name}>
            <div style={lbl}>
              {tooltip ? (
                <Tooltip title={tooltip}>
                  <span style={{ borderBottom: '1px dotted #94A3B8', cursor: 'help' }}>{label}</span>
                </Tooltip>
              ) : label}
            </div>
            <Form.Item name={name} style={{ marginBottom: 0 }}>
              <Radio.Group disabled={disabled} size="small" optionType="button" buttonStyle="outline"
                options={opts} />
            </Form.Item>
          </div>
        ))}
      </div>
    </TabPanel>
  )
}
