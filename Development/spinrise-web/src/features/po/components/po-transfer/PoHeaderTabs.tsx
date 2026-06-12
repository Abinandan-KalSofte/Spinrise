import { useState } from 'react'
import dayjs from 'dayjs'
import { OrderDetailsTab } from './tabs/OrderDetailsTab'
import { TaxDiscountTab } from './tabs/TaxDiscountTab'
import { PaymentTab } from './tabs/PaymentTab'
import { InstructionsTab } from './tabs/InstructionsTab'
import { CancelStatusTab } from './tabs/CancelStatusTab'
import { AmendmentTab } from './tabs/AmendmentTab'
import { ApprovalTab } from './tabs/ApprovalTab'
import type {
  ScreenMode, PoHeader, SupplierOption, OrderTypeOption, CarrierOption,
  FormTypeOption, BankOption,
} from '../../types'

// ── Header form — 7-tab navigation (HTML .hdr-tab-section) ───────────────────
// The page wraps this in <Form form={headerForm}>; tabs render Form.Items only.
// Approval tab is hidden in ADD (HTML .hide-add). Fields are editable only in
// ADD; VIEW/DELETE render them read-only/disabled.

type TabKey = 'order' | 'tax' | 'payment' | 'instructions' | 'cancel' | 'amendment' | 'approval'

interface PoHeaderTabsProps {
  mode:             ScreenMode
  poNo:             number | null
  orderValue:       number
  currentPo:        PoHeader | null
  orderTypes:       OrderTypeOption[]
  suppliers:        SupplierOption[]
  carriers:         CarrierOption[]
  formTypes:        FormTypeOption[]
  banks:            BankOption[]
  onSupplierChange: (s: SupplierOption | null) => void
  onSupplierSearch: (q: string) => void
}

export function PoHeaderTabs(props: PoHeaderTabsProps) {
  const { mode, poNo, orderValue, currentPo, orderTypes, suppliers, carriers, formTypes, banks,
    onSupplierChange, onSupplierSearch } = props
  const [active, setActive] = useState<TabKey>('order')
  const disabled = mode !== 'ADD'

  const tabs: { key: TabKey; label: string; hideInAdd?: boolean }[] = [
    { key: 'order',        label: 'Order Details' },
    { key: 'tax',          label: 'Tax / Discount' },
    { key: 'payment',      label: 'Payment' },
    { key: 'instructions', label: 'Instructions' },
    { key: 'cancel',       label: 'Cancel / Status' },
    { key: 'amendment',    label: 'Amendment' },
    { key: 'approval',     label: 'Approval', hideInAdd: true },
  ]
  const visibleTabs = tabs.filter((t) => !(t.hideInAdd && mode === 'ADD'))
  const activeKey = visibleTabs.some((t) => t.key === active) ? active : 'order'

  const createdBy = currentPo?.createdBy || ''
  const dateChip  = currentPo?.createdDt ? dayjs(currentPo.createdDt).format('DD-MMM-YYYY') : dayjs().format('DD-MMM-YYYY')

  return (
    <div style={{ background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>
      {/* Tab nav */}
      <div style={{
        display: 'flex', alignItems: 'flex-end', padding: '0 12px',
        borderBottom: '1px solid #e2e2e2',
      }}>
        {visibleTabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setActive(t.key)}
            style={{
              padding: '9px 13px', border: 'none', background: 'transparent', cursor: 'pointer',
              fontSize: 12, fontFamily: 'inherit', whiteSpace: 'nowrap', marginBottom: -1,
              borderBottom: `2px solid ${activeKey === t.key ? '#185FA5' : 'transparent'}`,
              color: activeKey === t.key ? '#185FA5' : '#888',
              fontWeight: activeKey === t.key ? 600 : 500,
            }}
          >
            {t.label}
          </button>
        ))}
        <span style={{ flex: 1 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, alignSelf: 'center', marginBottom: 1 }}>
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 9px',
            background: '#E6F1FB', border: '1px solid #b8d4ee', borderRadius: 4,
            fontSize: 11, fontWeight: 600, color: '#185FA5',
          }}>
            📅 {dateChip}
          </span>
          {createdBy && (
            <span style={{ fontSize: 11, color: '#888' }}>
              Created by <strong style={{ color: '#4a4a4a' }}>{createdBy}</strong>
            </span>
          )}
        </div>
      </div>

      {/* Active panel */}
      {activeKey === 'order' && (
        <OrderDetailsTab
          mode={mode} disabled={disabled} poNo={poNo} orderValue={orderValue}
          orderTypes={orderTypes} suppliers={suppliers} formTypes={formTypes}
          onSupplierChange={onSupplierChange} onSupplierSearch={onSupplierSearch}
        />
      )}
      {activeKey === 'tax'          && <TaxDiscountTab disabled={disabled} />}
      {activeKey === 'payment'      && <PaymentTab disabled={disabled} banks={banks} />}
      {activeKey === 'instructions' && <InstructionsTab disabled={disabled} carriers={carriers} />}
      {activeKey === 'cancel'       && <CancelStatusTab disabled={disabled} />}
      {activeKey === 'amendment'    && <AmendmentTab currentPo={currentPo} />}
      {activeKey === 'approval'     && <ApprovalTab currentPo={currentPo} />}
    </div>
  )
}
