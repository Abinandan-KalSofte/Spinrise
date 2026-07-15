import { Segmented } from 'antd'
import type { TabType } from '../configs/reportConfigs'

interface Props {
  availableTabs: TabType[]
  selectedTab: TabType
  onChange: (tab: TabType) => void
}

export function ReportTabs({ availableTabs, selectedTab, onChange }: Props) {
  return (
    <div style={{
      borderBottom: '1px solid #EDF2F7',
      background: '#FAFBFD',
    }}>
      <Segmented
        block
        value={selectedTab}
        onChange={(v) => onChange(v as TabType)}
        options={availableTabs.map((tab) => ({ label: tab, value: tab }))}
        style={{ fontSize: 12, fontWeight: 500 }}
      />
    </div>
  )
}
