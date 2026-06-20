import {
  BankOutlined,
  CalendarOutlined,
  CheckCircleOutlined,
  FileTextOutlined,
  FormOutlined,
  PercentageOutlined,
  StopOutlined,
  TruckOutlined,
} from '@ant-design/icons'
import { Tooltip } from 'antd'
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
  FormTypeOption, BankOption, AddressOption, CurrencyOption, PayTermOption,
} from '../../types'
import type { HeaderTabKey } from '../../hooks/usePoTransferForm'

// ── Header form — 7-tab workspace navigator ───────────────────────────────────
// Pill-style navigation with icons. All panels stay MOUNTED (display:none toggle)
// so headerForm.validateFields() never silently drops fields from inactive tabs.

type TabKey = HeaderTabKey

// Icon mapping — UI only. Keys must match TabKey values exactly.
const TAB_ICONS: Record<string, React.ReactNode> = {
  order:        <FileTextOutlined />,
  tax:          <PercentageOutlined />,
  payment:      <BankOutlined />,
  instructions: <TruckOutlined />,
  cancel:       <StopOutlined />,
  amendment:    <FormOutlined />,
  approval:     <CheckCircleOutlined />,
}

interface PoHeaderTabsProps {
  mode:              ScreenMode
  poNo:              number | null
  orderValue:        number
  lineItemValue:     number
  currentPo:         PoHeader | null
  orderTypes:        OrderTypeOption[]
  suppliers:         SupplierOption[]
  carriers:          CarrierOption[]
  formTypes:         FormTypeOption[]
  banks:             BankOption[]
  payTerms:          PayTermOption[]
  currencies:        CurrencyOption[]
  deliveryLocations: AddressOption[]
  billingAddresses:  AddressOption[]
  pricingTermsOpts:  AddressOption[]
  lastPoDate?:       string | null
  activeTab:         TabKey
  onTabChange:       (tab: TabKey) => void
  onSupplierChange:  (s: SupplierOption | null) => void
  onSupplierOpen:    () => void
}

export function PoHeaderTabs(props: PoHeaderTabsProps) {
  const {
    mode, poNo, orderValue, lineItemValue, currentPo,
    orderTypes, suppliers, carriers, formTypes, banks, payTerms,
    currencies, deliveryLocations, billingAddresses, pricingTermsOpts,
    lastPoDate,
    activeTab, onTabChange, onSupplierChange, onSupplierOpen,
  } = props

  const disabled = mode !== 'ADD'

  const tabs: { key: TabKey; label: string; hideInAdd?: boolean }[] = [
    { key: 'order',        label: 'Order Details'   },
    { key: 'tax',          label: 'Tax / Discount'  },
    { key: 'payment',      label: 'Payment'         },
    { key: 'instructions', label: 'Instructions'    },
    { key: 'cancel',       label: 'Cancel / Status' },
    { key: 'amendment',    label: 'Amendment'       },
    { key: 'approval',     label: 'Approval', hideInAdd: true },
  ]
  const visibleTabs = tabs.filter((t) => !(t.hideInAdd && mode === 'ADD'))
  const activeKey   = visibleTabs.some((t) => t.key === activeTab) ? activeTab : 'order'

  const createdBy = currentPo?.createdBy || ''
  const dateChip  = currentPo?.createdDt
    ? dayjs(currentPo.createdDt, 'DD/MM/YYYY').format('DD-MMM-YYYY')
    : dayjs().format('DD-MMM-YYYY')

  return (
    <div style={{
      background: '#fff',
      borderBottom: '1px solid #E2E8F0',
      boxShadow: '0 2px 6px rgba(0,0,0,0.05)',
      flexShrink: 0,
    }}>

      {/* ── Pill navigator bar ──────────────────────────────────────────────── */}
      <div style={{
        display: 'flex', alignItems: 'center',
        padding: '8px 14px 0',
        background: '#F8FAFD',
        borderBottom: '1px solid #EEF2F8',
        gap: 10,
      }}>

        {/* Pill track */}
        <div style={{
          display: 'flex', flexWrap: 'nowrap', overflowX: 'auto',
          background: '#EEF2F8', borderRadius: 10, padding: 3, gap: 2,
          scrollbarWidth: 'none',
          msOverflowStyle: 'none',
        } as React.CSSProperties}>
          {visibleTabs.map((t) => {
            const active = activeKey === t.key
            return (
              <button
                key={t.key}
                onClick={() => onTabChange(t.key)}
                style={{
                  display: 'inline-flex', alignItems: 'center', gap: 5,
                  padding: '5px 13px', borderRadius: 7,
                  border: 'none', cursor: 'pointer',
                  background: active ? '#185FA5' : 'transparent',
                  color:      active ? '#fff'    : '#637083',
                  fontWeight: active ? 600       : 500,
                  fontSize:   11.5,
                  fontFamily: 'inherit',
                  whiteSpace: 'nowrap',
                  flexShrink: 0,
                  boxShadow:  active ? '0 1px 4px rgba(24,95,165,0.28)' : 'none',
                  transition: 'background 0.14s, color 0.14s, box-shadow 0.14s',
                }}
              >
                <span style={{ fontSize: 11, opacity: active ? 1 : 0.7 }}>
                  {TAB_ICONS[t.key]}
                </span>
                <span>{t.label}</span>
              </button>
            )
          })}
        </div>

        <span style={{ flex: 1 }} />

        {/* Created date + author chip */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            padding: '3px 10px',
            background: '#EFF6FF', border: '1px solid #BFDBFE',
            borderRadius: 20,
            fontSize: 11, fontWeight: 600, color: '#1D4ED8',
          }}>
            <CalendarOutlined style={{ fontSize: 10 }} />
            {dateChip}
          </span>
          {createdBy && (
            <span style={{ fontSize: 11, color: '#9AA5B4' }}>
              Created by{' '}
              <Tooltip title={createdBy}>
                <strong style={{ color: '#4B5563', cursor: 'help', borderBottom: '1px dotted #9AA5B4' }}>
                  {createdBy}
                </strong>
              </Tooltip>
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
            currencies={currencies} lastPoDate={lastPoDate}
            onSupplierChange={onSupplierChange} onSupplierOpen={onSupplierOpen}
          />
        </div>
        <div style={{ display: activeKey === 'tax' ? 'block' : 'none' }}>
          <TaxDiscountTab disabled={disabled} lineItemValue={lineItemValue} />
        </div>
        <div style={{ display: activeKey === 'payment' ? 'block' : 'none' }}>
          <PaymentTab disabled={disabled} banks={banks} payTerms={payTerms} orderValue={orderValue} />
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
