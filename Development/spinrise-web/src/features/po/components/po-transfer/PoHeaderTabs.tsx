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
  FormTypeOption, BankOption, AddressOption, CurrencyOption,
} from '../../types'
import type { HeaderTabKey } from '../../hooks/usePoTransferForm'

// ── Header form — 7-tab navigation (HTML .hdr-tab-section) ───────────────────
// The page wraps this in <Form form={headerForm}>; tabs render Form.Items only.
// Approval tab is hidden in ADD (HTML .hide-add). Fields are editable only in
// ADD; VIEW/DELETE render them read-only/disabled.
// Tab state is fully controlled by the parent (activeTab / onTabChange) so the
// page can programmatically navigate to a failing field's tab on save validation.

type TabKey = HeaderTabKey

interface PoHeaderTabsProps {
  mode:              ScreenMode
  poNo:              number | null
  orderValue:        number        // total order value (including GST + charges ± roundoff)
  lineItemValue:     number        // Σ Rate × Qty — base for Tax tab % ↔ Amount calc
  currentPo:         PoHeader | null
  orderTypes:        OrderTypeOption[]
  suppliers:         SupplierOption[]
  carriers:          CarrierOption[]
  formTypes:         FormTypeOption[]
  banks:             BankOption[]
  currencies:        CurrencyOption[]
  deliveryLocations: AddressOption[]
  billingAddresses:  AddressOption[]
  pricingTermsOpts:  AddressOption[]
  activeTab:         TabKey
  onTabChange:       (tab: TabKey) => void
  onSupplierChange:  (s: SupplierOption | null) => void
  onSupplierOpen:    () => void
}

export function PoHeaderTabs(props: PoHeaderTabsProps) {
  const {
    mode, poNo, orderValue, lineItemValue, currentPo,
    orderTypes, suppliers, carriers, formTypes, banks,
    currencies, deliveryLocations, billingAddresses, pricingTermsOpts,
    activeTab, onTabChange, onSupplierChange, onSupplierOpen,
  } = props

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
  const activeKey = visibleTabs.some((t) => t.key === activeTab) ? activeTab : 'order'

  const createdBy = currentPo?.createdBy || ''
  const dateChip  = currentPo?.createdDt
    ? dayjs(currentPo.createdDt, 'DD/MM/YYYY').format('DD-MMM-YYYY')
    : dayjs().format('DD-MMM-YYYY')

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
            onClick={() => onTabChange(t.key)}
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

      {/* Panels — every form tab stays MOUNTED; only visibility is toggled.
          Conditionally mounting a panel unregisters its Form.Items, so
          headerForm.validateFields() would silently drop fields from inactive
          tabs — that produced crashes on Save. Keeping them mounted fixes both. */}
      <div style={{ display: activeKey === 'order' ? 'block' : 'none' }}>
        <OrderDetailsTab
          mode={mode} disabled={disabled} poNo={poNo} orderValue={orderValue}
          orderTypes={orderTypes} suppliers={suppliers} formTypes={formTypes}
          currencies={currencies}
          onSupplierChange={onSupplierChange} onSupplierOpen={onSupplierOpen}
        />
      </div>
      <div style={{ display: activeKey === 'tax' ? 'block' : 'none' }}>
        <TaxDiscountTab disabled={disabled} lineItemValue={lineItemValue} />
      </div>
      <div style={{ display: activeKey === 'payment' ? 'block' : 'none' }}>
        <PaymentTab disabled={disabled} banks={banks} />
      </div>
      <div style={{ display: activeKey === 'instructions' ? 'block' : 'none' }}>
        <InstructionsTab
          disabled={disabled} carriers={carriers}
          deliveryLocations={deliveryLocations}
          billingAddresses={billingAddresses}
          pricingTermsOpts={pricingTermsOpts}
        />
      </div>
      <div style={{ display: activeKey === 'cancel' ? 'block' : 'none' }}>
        <CancelStatusTab disabled={disabled} />
      </div>
      {/* Amendment / Approval are read-only display panels (no Form.Items). */}
      <div style={{ display: activeKey === 'amendment' ? 'block' : 'none' }}>
        <AmendmentTab currentPo={currentPo} />
      </div>
      {mode !== 'ADD' && (
        <div style={{ display: activeKey === 'approval' ? 'block' : 'none' }}>
          <ApprovalTab currentPo={currentPo} />
        </div>
      )}
    </div>
  )
}
