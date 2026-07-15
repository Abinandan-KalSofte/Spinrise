import { Button, Input, Select } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import type { DivisionOption, PoApprovalFilterState } from '../../types/poApprovalTypes'

// Shared across every PO Approval level — Division + PO No. search only.
// The prototype explicitly removed the From/To Date pickers per POT-POA-06
// (CR 03-Jul-2026); do not reintroduce them. Store-agnostic (props only) so
// First/Second/Final Level pages can each pass their own store's slice.
interface Props {
  filter:    PoApprovalFilterState
  divisions: DivisionOption[]
  setFilter: (patch: Partial<PoApprovalFilterState>) => void
  onLoad:    () => void
  loading:   boolean
}

export default function PoApprovalFilterBar({ filter, divisions, setFilter, onLoad, loading }: Props) {
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-end', gap: 14,
      padding: '10px 16px', background: '#fff',
      borderBottom: '1px solid #E2E2E2', flexShrink: 0, flexWrap: 'wrap',
    }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 3, flex: '0 0 260px', minWidth: 560 }}>
        <span style={{ fontSize: 11, fontWeight: 500, color: '#888' }}>
          Division<span style={{ color: '#A32D2D', marginLeft: 1 }}>*</span>
        </span>
        <Select
          style={{ width: '100%' }}
          placeholder="Select Division"
          value={divisions.some((d) => d.code === filter.divCode) ? filter.divCode : undefined}
          onChange={(v) => setFilter({ divCode: v })}
          options={divisions.map((d) => ({ label: d.name, value: d.code }))}
        />
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 3, flex: '0 0 200px' }}>
        <span style={{ fontSize: 11, fontWeight: 500, color: '#888' }}>PO No.</span>
        <Input
          placeholder="Search PO No. …"
          allowClear
          value={filter.poNoSearch}
          onChange={(e) => setFilter({ poNoSearch: e.target.value })}
          style={{ fontFamily: "'JetBrains Mono','Courier New',monospace" }}
        />
      </div>

      <Button type="primary" icon={<SearchOutlined />} loading={loading} onClick={onLoad}>
        Load
      </Button>
    </div>
  )
}
