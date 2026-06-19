import { Checkbox, Col, DatePicker, Row, Segmented, Select, Spin } from 'antd'
import {
  ApartmentOutlined,
  CalendarOutlined,
  FilterOutlined,
  SettingOutlined,
  UnorderedListOutlined,
} from '@ant-design/icons'
import dayjs from 'dayjs'
import type { DeptOption, PrItemOption, PrReportFilter, ReportType } from '../../types/prReportTypes'

// ── Shared card wrapper ────────────────────────────────────────────────────────

interface FilterCardProps {
  icon:     React.ReactNode
  title:    string
  children: React.ReactNode
}

function FilterCard({ icon, title, children }: FilterCardProps) {
  return (
    <div style={{ background: '#fff', border: '1px solid #E2E8F0', borderRadius: 8 }}>
      <div style={{
        padding: '8px 14px',
        borderBottom: '1px solid #EDF2F7',
        display: 'flex', alignItems: 'center', gap: 7,
        background: '#FAFBFD', borderRadius: '8px 8px 0 0',
      }}>
        <span style={{ fontSize: 12, color: '#185FA5', display: 'flex' }}>{icon}</span>
        <span style={{
          fontSize: 10, fontWeight: 700, color: '#4A5568',
          textTransform: 'uppercase', letterSpacing: '0.08em',
        }}>
          {title}
        </span>
      </div>
      <div style={{ padding: '12px 14px' }}>
        {children}
      </div>
    </div>
  )
}

// ── Sub-label ──────────────────────────────────────────────────────────────────

function FieldLabel({ label, muted }: { label: string; muted?: boolean }) {
  return (
    <label style={{
      display: 'block',
      fontSize: 11, fontWeight: 600,
      color: muted ? '#CBD5E0' : '#4A5568',
      marginBottom: 4,
    }}>
      {label}
    </label>
  )
}

// ── Props ─────────────────────────────────────────────────────────────────────

interface Props {
  filter:             PrReportFilter
  departments:        DeptOption[]
  items:              PrItemOption[]
  loadingLookups:     boolean
  onFilterChange:     (patch: Partial<PrReportFilter>) => void
  onReportTypeChange: (t: ReportType) => void
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function PrReportFilterBar({
  filter, departments, items, loadingLookups,
  onFilterChange, onReportTypeChange,
}: Props) {
  const { reportType, fromDate, toDate, selectedDeptCode, selectedItemCodes, allItems } = filter
  const isDeptwise = reportType === 'Departmentwise'
  const isItemwise = reportType === 'Itemwise'

  const filterOption = (input: string, opt: { label?: unknown } | undefined) =>
    (opt?.label as string ?? '').toLowerCase().includes(input.toLowerCase())

  return (
    <>

      {/* ── Report Configuration ──────────────────────────────────────────────── */}
      <FilterCard icon={<SettingOutlined />} title="Report Configuration">
        <Segmented
          block
          value={reportType}
          onChange={(v) => onReportTypeChange(v as ReportType)}
          options={[
            { label: 'Datewise',       value: 'Datewise' },
            { label: 'Departmentwise', value: 'Departmentwise' },
            { label: 'Itemwise',       value: 'Itemwise' },
          ]}
          style={{ fontSize: 12, fontWeight: 500 }}
        />
        <div style={{ marginTop: 10, fontSize: 11, color: '#718096', lineHeight: 1.7 }}>
          {reportType === 'Datewise' &&
            'Lists all PR entries within the selected date range.'}
          {reportType === 'Departmentwise' &&
            'Groups PRs by department. At least one department is required.'}
          {reportType === 'Itemwise' &&
            'Groups PRs by item. Select specific items or include all.'}
        </div>
      </FilterCard>

      {/* ── Date Range ───────────────────────────────────────────────────────── */}
      <FilterCard icon={<CalendarOutlined />} title="Date Range">
        <Row gutter={12}>
          <Col span={12}>
            <FieldLabel label="From PR Date" />
            <DatePicker
              size="small"
              value={fromDate ? dayjs(fromDate) : null}
              format="DD/MM/YYYY"
              allowClear={false}
              style={{ width: '100%' }}
              onChange={(v) => onFilterChange({ fromDate: v ? v.format('YYYY-MM-DD') : '' })}
              placeholder="Select start date"
            />
          </Col>
          <Col span={12}>
            <FieldLabel label="To PR Date" />
            <DatePicker
              size="small"
              value={toDate ? dayjs(toDate) : null}
              format="DD/MM/YYYY"
              allowClear={false}
              style={{ width: '100%' }}
              onChange={(v) => onFilterChange({ toDate: v ? v.format('YYYY-MM-DD') : '' })}
              placeholder="Select end date"
            />
          </Col>
        </Row>
      </FilterCard>

      {/* ── Department Filter (Departmentwise) ───────────────────────────────── */}
      {isDeptwise && (
        <FilterCard icon={<ApartmentOutlined />} title="Department Filter">
          <FieldLabel label="Department" />
          {loadingLookups ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}>
              <Spin size="small" />
              <span style={{ fontSize: 11, color: '#A0AEC0' }}>Loading departments…</span>
            </div>
          ) : (
            <Select
              size="small"
              placeholder="Select Department…"
              value={selectedDeptCode || undefined}
              onChange={(v) => onFilterChange({ selectedDeptCode: v as string ?? '' })}
              allowClear
              onClear={() => onFilterChange({ selectedDeptCode: '' })}
              style={{ width: '100%' }}
              options={departments.map((d) => ({ label: `${d.depCode} - ${d.depName}`, value: d.depCode }))}
              showSearch
              filterOption={filterOption}
              notFoundContent={
                <span style={{ fontSize: 11, color: '#A0AEC0' }}>No departments found</span>
              }
            />
          )}
        </FilterCard>
      )}

      {/* ── Item Filter (Itemwise) ────────────────────────────────────────────── */}
      {isItemwise && (
        <FilterCard icon={<UnorderedListOutlined />} title="Item Filter">

          {/* Item selection */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
              <FieldLabel label="Item" />
              <Checkbox
                checked={allItems}
                onChange={(e) => onFilterChange({ allItems: e.target.checked, selectedItemCodes: [] })}
                style={{ fontSize: 11, marginBottom: 4 }}
              >
                All Items
              </Checkbox>
            </div>

            {!allItems && (
              loadingLookups ? (
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}>
                  <Spin size="small" />
                  <span style={{ fontSize: 11, color: '#A0AEC0' }}>Loading items…</span>
                </div>
              ) : (
                <Select
                  mode="multiple"
                  size="small"
                  placeholder="Select Items…"
                  value={selectedItemCodes}
                  onChange={(v) => onFilterChange({ selectedItemCodes: v })}
                  style={{ width: '100%' }}
                  options={items.map((i) => ({ label: `${i.itemCode} - ${i.itemName}`, value: i.itemCode }))}
                  maxTagCount="responsive"
                  showSearch
                  filterOption={filterOption}
                  notFoundContent={
                    <span style={{ fontSize: 11, color: '#A0AEC0' }}>No items found</span>
                  }
                />
              )
            )}

            {!allItems && selectedItemCodes.length > 0 && (
              <div style={{ marginTop: 6, fontSize: 11, color: '#718096' }}>
                {selectedItemCodes.length} item{selectedItemCodes.length !== 1 ? 's' : ''} selected
              </div>
            )}
          </div>
        </FilterCard>
      )}

      {/* ── Filter-type info card (Datewise — no extra filters) ──────────────── */}
      {!isDeptwise && !isItemwise && (
        <div style={{
          padding: '10px 14px',
          background: '#EBF8FF',
          border: '1px solid #BEE3F8',
          borderRadius: 8,
          fontSize: 11,
          color: '#2C5282',
          lineHeight: 1.6,
        }}>
          <FilterOutlined style={{ marginRight: 6 }} />
          No additional filters for Datewise report. Just set the date range above and generate.
        </div>
      )}

    </>
  )
}
