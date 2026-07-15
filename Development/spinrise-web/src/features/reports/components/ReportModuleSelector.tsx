import { Select } from 'antd'
import { REPORT_CONFIGS } from '../configs/reportConfigs'

interface Props {
  selectedReportId: string | null
  onChange: (reportId: string) => void
}

export function ReportModuleSelector({ selectedReportId, onChange }: Props) {
  const reports = Object.values(REPORT_CONFIGS)
  const filterOption = (input: string, opt: { label?: unknown } | undefined) =>
    (opt?.label as string ?? '').toLowerCase().includes(input.toLowerCase())

  return (
    <div style={{
      padding: '14px',
      background: '#fff',
      border: '1px solid #E2E8F0',
      borderRadius: 8,
    }}>
      <label style={{
        display: 'block',
        fontSize: 11,
        fontWeight: 600,
        color: '#4A5568',
        marginBottom: 8,
        textTransform: 'uppercase',
        letterSpacing: '0.07em',
      }}>
        Report Module
      </label>
      <Select
        size="small"
        placeholder="Choose a report to begin…"
        value={selectedReportId || undefined}
        onChange={onChange}
        allowClear={{
          clearIcon: selectedReportId ? undefined : undefined,
        }}
        onClear={() => onChange('')}
        style={{ width: '100%' }}
        options={reports.map((r) => ({ label: r.title, value: r.id }))}
        showSearch
        filterOption={filterOption}
        notFoundContent={
          <span style={{ fontSize: 11, color: '#A0AEC0' }}>No reports found</span>
        }
      />
    </div>
  )
}
