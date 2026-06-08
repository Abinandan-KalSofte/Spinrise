import { Button, Checkbox, Select } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import { useFinalApprovalStore } from '../../store/useFinalApprovalStore'

interface Props {
  onShow: () => void
  loading: boolean
}

export default function FinalApprovalFilterBar({ onShow, loading }: Props) {
  const { filter, companies, divisions, setFilter, loadDivisions } = useFinalApprovalStore()

  const handleCompanyChange = async (dbName: string) => {
    setFilter({ dbName, divCode: '0' })
    if (dbName) await loadDivisions(dbName)
  }

  const companyAll = !filter.dbName

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '8px 16px', background: '#FAFAF8',
      borderBottom: '1px solid #e8e8e8', flexShrink: 0,
    }}>
      <label style={{ fontSize: 12, fontWeight: 500, color: '#555' }}>Company</label>
      <Select
        style={{ width: 180 }}
        size="small"
        placeholder="All Companies"
        allowClear
        value={filter.dbName || undefined}
        onChange={(v) => void handleCompanyChange(v ?? '')}
        options={companies.map((c) => ({ label: c.companyName, value: c.dbName }))}
      />

      <label style={{ fontSize: 12, fontWeight: 500, color: '#555' }}>Division</label>
      <div style={{ flex: 1 }}>
        <Select
          style={{ width: '100%' }}
          size="small"
          disabled={companyAll}
          value={filter.divCode}
          onChange={(v) => setFilter({ divCode: v })}
          options={[
            { label: 'All Divisions', value: '0' },
            ...divisions.map((d) => ({ label: d.divisionName, value: d.divCode })),
          ]}
        />
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 'auto' }}>
        <Checkbox
          checked={filter.bypassAll}
          onChange={(e) => setFilter({ bypassAll: e.target.checked })}
          style={{ fontSize: 12 }}
        >
          Bypass All
        </Checkbox>

        <Button
          type="primary"
          size="small"
          icon={<SearchOutlined />}
          loading={loading}
          disabled={companyAll}
          onClick={onShow}
        >
          Show
        </Button>
      </div>
    </div>
  )
}
