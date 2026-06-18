import { Checkbox, DatePicker, Radio, Select, Spin } from 'antd'
import type { RadioChangeEvent } from 'antd'
import dayjs from 'dayjs'
import type { DeptOption, PrItemOption, PrReportFilter, ReportType } from '../../types/prReportTypes'

// ── Design tokens (matches existing ERP filter-bar style) ─────────────────────

const SECTION_LABEL: React.CSSProperties = {
  fontSize: 11,
  fontWeight: 700,
  color:     '#374151',
  letterSpacing: '0.04em',
  textTransform: 'uppercase',
  display:   'block',
  marginBottom: 6,
}

const FIELD_LABEL: React.CSSProperties = {
  fontSize:    12,
  fontWeight:  600,
  color:       '#555',
  display:     'block',
  marginBottom: 4,
}

const FIELD_LABEL_MUTED: React.CSSProperties = {
  ...FIELD_LABEL,
  color: '#9ca3af',
}

const FIELD: React.CSSProperties = {
  display:       'flex',
  flexDirection: 'column',
}

const DIVIDER: React.CSSProperties = {
  height:     1,
  background: '#e8e8e8',
  margin:     '14px 0',
}

// ── Props ─────────────────────────────────────────────────────────────────────

interface Props {
  filter:            PrReportFilter
  departments:       DeptOption[]
  items:             PrItemOption[]
  loadingLookups:    boolean
  onFilterChange:    (patch: Partial<PrReportFilter>) => void
  onReportTypeChange:(t: ReportType) => void
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function PrReportFilterBar({
  filter, departments, items, loadingLookups,
  onFilterChange, onReportTypeChange,
}: Props) {
  const { reportType, fromDate, toDate, selectedDeptCodes, selectedItemCodes, allItems } = filter

  const isDeptwise = reportType === 'Departmentwise'
  const isItemwise = reportType === 'Itemwise'

  return (
    <div style={{
      background:   '#FAFAF8',
      borderBottom: '1px solid #e8e8e8',
      padding:      '16px 24px',
      flexShrink:   0,
      overflowY:    'auto',
      maxHeight:    420,
    }}>

      {/* ── Report Type ───────────────────────────────────────────────────────── */}
      <div style={{ marginBottom: 14 }}>
        <label style={SECTION_LABEL}>Report Type</label>
        <Radio.Group
          value={reportType}
          onChange={(e: RadioChangeEvent) => onReportTypeChange(e.target.value as ReportType)}
          optionType="button"
          buttonStyle="solid"
          size="small"
        >
          <Radio.Button value="Datewise">Datewise</Radio.Button>
          <Radio.Button value="Departmentwise">Departmentwise</Radio.Button>
          <Radio.Button value="Itemwise">Itemwise</Radio.Button>
        </Radio.Group>
      </div>

      <div style={DIVIDER} />

      {/* ── Date range (always visible) ───────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap', marginBottom: (isDeptwise || isItemwise) ? 14 : 0 }}>
        <div style={FIELD}>
          <label style={FIELD_LABEL}>From PR Date</label>
          <DatePicker
            size="small"
            value={fromDate ? dayjs(fromDate) : null}
            format="DD/MM/YYYY"
            allowClear={false}
            style={{ width: 154 }}
            onChange={(v) => onFilterChange({ fromDate: v ? v.format('YYYY-MM-DD') : '' })}
          />
        </div>
        <div style={FIELD}>
          <label style={FIELD_LABEL}>To PR Date</label>
          <DatePicker
            size="small"
            value={toDate ? dayjs(toDate) : null}
            format="DD/MM/YYYY"
            allowClear={false}
            style={{ width: 154 }}
            onChange={(v) => onFilterChange({ toDate: v ? v.format('YYYY-MM-DD') : '' })}
          />
        </div>
      </div>

      {/* ── Department section (Departmentwise — enabled) ─────────────────────── */}
      {isDeptwise && (
        <>
          <div style={DIVIDER} />
          <div style={FIELD}>
            <label style={FIELD_LABEL}>Department</label>
            {loadingLookups ? (
              <Spin size="small" />
            ) : (
              <Select
                mode="multiple"
                size="small"
                placeholder="Select Departments…"
                value={selectedDeptCodes}
                onChange={(v) => onFilterChange({ selectedDeptCodes: v })}
                style={{ width: '100%', maxWidth: 560 }}
                options={departments.map((d) => ({ label: d.depName, value: d.depCode }))}
                maxTagCount="responsive"
                showSearch
                filterOption={(input, opt) =>
                  (opt?.label as string ?? '').toLowerCase().includes(input.toLowerCase())
                }
              />
            )}
          </div>
        </>
      )}

      {/* ── Department section (Itemwise — greyed/disabled per CR §4.3) ─────────── */}
      {isItemwise && (
        <>
          <div style={DIVIDER} />
          <div style={{ ...FIELD, marginBottom: 14 }}>
            <label style={FIELD_LABEL_MUTED}>Department</label>
            <Select
              size="small"
              disabled
              placeholder="Not applicable in Itemwise mode"
              style={{ width: 300, background: '#f3f4f6', color: '#9ca3af' }}
            />
          </div>
        </>
      )}

      {/* ── Item section (Itemwise — enabled) ────────────────────────────────── */}
      {isItemwise && (
        <div style={FIELD}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 8 }}>
            <label style={{ ...FIELD_LABEL, marginBottom: 0 }}>Item</label>
            <Checkbox
              checked={allItems}
              onChange={(e) =>
                onFilterChange({
                  allItems:          e.target.checked,
                  selectedItemCodes: [],
                })
              }
              style={{ fontSize: 12 }}
            >
              All Items
            </Checkbox>
          </div>
          {!allItems && (
            loadingLookups ? (
              <Spin size="small" />
            ) : (
              <Select
                mode="multiple"
                size="small"
                placeholder="Select Items…"
                value={selectedItemCodes}
                onChange={(v) => onFilterChange({ selectedItemCodes: v })}
                style={{ width: '100%', maxWidth: 560 }}
                options={items.map((i) => ({ label: i.itemName, value: i.itemCode }))}
                maxTagCount="responsive"
                showSearch
                filterOption={(input, opt) =>
                  (opt?.label as string ?? '').toLowerCase().includes(input.toLowerCase())
                }
              />
            )
          )}
        </div>
      )}
    </div>
  )
}
