import { App } from 'antd'
import { PRDocBand } from '../components/pr-form/PRToolbar'
import PrForeclosureGrid from '../components/foreclosure/PrForeclosureGrid'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import dayjs from 'dayjs'
import { usePageTitle } from '@/shared/hooks/usePageTitle'

export default function PrForeclosurePage() {
  usePageTitle('PR Foreclosure')
  const processingDate = useAuthStore((s) => s.processingDate)
  const today = processingDate
    ? dayjs(processingDate).format('DD MMM YYYY')
    : dayjs().format('DD MMM YYYY')

  return (
    <App style={{ display: 'flex', flexDirection: 'column', flex: 1, height: '100%', minHeight: 0, overflow: 'hidden' }}>
      <PRDocBand
        title="Purchase Requisition Foreclosure"
        breadcrumb={['Purchase Order', 'Purchase Requisition Foreclosure']}
        subLabel="Processing Date"
        subValue={today}
      />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, overflow: 'hidden' }}>
        <PrForeclosureGrid />
      </div>
    </App>
  )
}
