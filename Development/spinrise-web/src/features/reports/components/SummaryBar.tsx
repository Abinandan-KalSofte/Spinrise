import { BarChartOutlined, CalendarOutlined, FilePdfOutlined, FunnelPlotOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import type { ReportFilter } from '../types/reportTypes'

const CARD_BG = '#fff'
const BORDER_COLOR = '#E2E8F0'

interface KpiCardProps {
  icon: React.ReactNode
  label: string
  value: string
  accent: string
}

function KpiCard({ icon, label, value, accent }: KpiCardProps) {
  return (
    <div style={{
      flex: 1,
      minWidth: 0,
      background: CARD_BG,
      border: `1px solid ${BORDER_COLOR}`,
      borderRadius: 8,
      padding: '10px 12px',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
    }}>
      <div style={{
        width: 34,
        height: 34,
        borderRadius: 8,
        flexShrink: 0,
        background: `${accent}1A`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: accent,
        fontSize: 16,
      }}>
        {icon}
      </div>
      <div style={{ minWidth: 0 }}>
        <div style={{
          fontSize: 10,
          fontWeight: 700,
          color: '#A0AEC0',
          textTransform: 'uppercase',
          letterSpacing: '0.07em',
          marginBottom: 2,
        }}>
          {label}
        </div>
        <div style={{
          fontSize: 12,
          fontWeight: 700,
          color: '#1A202C',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}>
          {value}
        </div>
      </div>
    </div>
  )
}

interface Props {
  filter: ReportFilter | null
}

export function SummaryBar({ filter }: Props) {
  if (!filter) return null

  const dateRangeLabel = filter.fromDate && filter.toDate
    ? `${dayjs(filter.fromDate).format('DD MMM YY')} – ${dayjs(filter.toDate).format('DD MMM YY')}`
    : 'Not configured'

  const filterLabel = (() => {
    switch (filter.reportType) {
      case 'Departmentwise':
        return filter.allDepts
          ? 'All departments'
          : filter.selectedDeptCodes.length > 0
            ? `${filter.selectedDeptCodes.length} department${filter.selectedDeptCodes.length !== 1 ? 's' : ''}`
            : 'No departments'
      case 'Itemwise':
        return filter.allItems
          ? 'All items'
          : filter.selectedItemCodes.length > 0
            ? `${filter.selectedItemCodes.length} item${filter.selectedItemCodes.length !== 1 ? 's' : ''}`
            : 'No items'
      case 'Supplierwise':
        return filter.allSuppliers
          ? 'All suppliers'
          : filter.selectedSupplierCodes.length > 0
            ? `${filter.selectedSupplierCodes.length} supplier${filter.selectedSupplierCodes.length !== 1 ? 's' : ''}`
            : 'No suppliers'
      default:
        return 'Date range only'
    }
  })()

  return (
    <div style={{ display: 'flex', gap: 10 }}>
      <KpiCard
        icon={<CalendarOutlined />}
        label="Date Range"
        value={dateRangeLabel}
        accent="#185FA5"
      />
      <KpiCard
        icon={<BarChartOutlined />}
        label="Report Type"
        value={filter.reportType}
        accent="#6B46C1"
      />
      <KpiCard
        icon={<FunnelPlotOutlined />}
        label="Filters"
        value={filterLabel}
        accent="#B7791F"
      />
      <KpiCard
        icon={<FilePdfOutlined />}
        label="Output"
        value="PDF · A4 Landscape"
        accent="#C53030"
      />
    </div>
  )
}
