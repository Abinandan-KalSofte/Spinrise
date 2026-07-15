import { Checkbox, Col, DatePicker, Row, Select, Spin } from "antd";
import {
  ApartmentOutlined,
  CalendarOutlined,
  CheckCircleOutlined,
  FilterOutlined,
  TruckOutlined,
  UnorderedListOutlined,
} from "@ant-design/icons";
import dayjs from "dayjs";
import type { ReportConfig, TabType } from "../configs/reportConfigs";
import type {
  ReportFilter,
  DeptOption,
  ItemOption,
  SupplierOption,
} from "../types/reportTypes";
import { ReportTabs } from "./ReportTabs";

interface FilterCardProps {
  icon: React.ReactNode;
  title: string;
  children: React.ReactNode;
}

function FilterCard({ icon, title, children }: FilterCardProps) {
  return (
    <div
      style={{
        background: "#fff",
        border: "1px solid #E2E8F0",
        borderRadius: 8,
      }}
    >
      <div
        style={{
          padding: "8px 14px",
          borderBottom: "1px solid #EDF2F7",
          display: "flex",
          alignItems: "center",
          gap: 7,
          background: "#FAFBFD",
          borderRadius: "8px 8px 0 0",
        }}
      >
        <span style={{ fontSize: 12, color: "#185FA5", display: "flex" }}>
          {icon}
        </span>
        <span
          style={{
            fontSize: 10,
            fontWeight: 700,
            color: "#4A5568",
            textTransform: "uppercase",
            letterSpacing: "0.08em",
          }}
        >
          {title}
        </span>
      </div>
      <div style={{ padding: "12px 14px" }}>{children}</div>
    </div>
  );
}

function FieldLabel({ label, muted }: { label: string; muted?: boolean }) {
  return (
    <label
      style={{
        display: "block",
        fontSize: 11,
        fontWeight: 600,
        color: muted ? "#CBD5E0" : "#4A5568",
        marginBottom: 4,
      }}
    >
      {label}
    </label>
  );
}

interface Props {
  config: ReportConfig;
  filter: ReportFilter;
  departments: DeptOption[];
  items: ItemOption[];
  suppliers: SupplierOption[];
  loadingLookups: boolean;
  onFilterChange: (patch: Partial<ReportFilter>) => void;
  onReportTypeChange: (tab: TabType) => void;
}

export function DynamicFilterRenderer({
  config,
  filter,
  departments,
  items,
  suppliers,
  loadingLookups,
  onFilterChange,
  onReportTypeChange,
}: Props) {
  const filterConfigs = config.filters[filter.reportType] || [];
  const filterOption = (input: string, opt: { label?: unknown } | undefined) =>
    ((opt?.label as string) ?? "").toLowerCase().includes(input.toLowerCase());

  return (
    <>
      {/* Report Configuration */}
      <FilterCard icon={<FilterOutlined />} title="Report Configuration">
        {/* Report Tabs */}
        <div>
          <ReportTabs
            availableTabs={config.tabs}
            selectedTab={filter.reportType}
            onChange={onReportTypeChange}
          />
        </div>
        <div
          style={{
            fontSize: 11,
            color: "#718096",
            lineHeight: 1.7,
            padding: "8px 0",
          }}
        >
          {config.hints[filter.reportType]}
        </div>
      </FilterCard>

      {/* Render date range filter (always present) */}
      {filterConfigs.some((f) => f.type === "date") && (
        <FilterCard icon={<CalendarOutlined />} title="Date Range">
          <Row gutter={12}>
            <Col span={12}>
              <FieldLabel label="From Date" />
              <DatePicker
                size="small"
                value={filter.fromDate ? dayjs(filter.fromDate) : null}
                format="DD/MM/YYYY"
                allowClear={false}
                style={{ width: "100%" }}
                onChange={(v) =>
                  onFilterChange({ fromDate: v ? v.format("YYYY-MM-DD") : "" })
                }
                placeholder="Select start date"
              />
            </Col>
            <Col span={12}>
              <FieldLabel label="To Date" />
              <DatePicker
                size="small"
                value={filter.toDate ? dayjs(filter.toDate) : null}
                format="DD/MM/YYYY"
                allowClear={false}
                style={{ width: "100%" }}
                onChange={(v) =>
                  onFilterChange({ toDate: v ? v.format("YYYY-MM-DD") : "" })
                }
                placeholder="Select end date"
              />
            </Col>
          </Row>
        </FilterCard>
      )}

      {/* Department Filter */}
      {filterConfigs.some((f) => f.type === "department") && (
        <FilterCard icon={<ApartmentOutlined />} title="Department Filter">
          <div>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                marginBottom: 6,
              }}
            >
              <FieldLabel label="Department" />
              <Checkbox
                checked={filter.allDepts}
                onChange={(e) =>
                  onFilterChange({
                    allDepts: e.target.checked,
                    selectedDeptCodes: [],
                  })
                }
                style={{ fontSize: 11, marginBottom: 4 }}
              >
                All Departments
              </Checkbox>
            </div>

            {!filter.allDepts &&
              (loadingLookups ? (
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    padding: "6px 0",
                  }}
                >
                  <Spin size="small" />
                  <span style={{ fontSize: 11, color: "#A0AEC0" }}>
                    Loading departments…
                  </span>
                </div>
              ) : (
                <Select
                  mode="multiple"
                  size="small"
                  placeholder="Select Departments…"
                  value={filter.selectedDeptCodes}
                  onChange={(v) => onFilterChange({ selectedDeptCodes: v })}
                  style={{ width: "100%" }}
                  options={departments.map((d) => ({
                    label: `${d.depCode} - ${d.depName}`,
                    value: d.depCode,
                  }))}
                  maxTagCount="responsive"
                  showSearch
                  filterOption={filterOption}
                  notFoundContent={
                    <span style={{ fontSize: 11, color: "#A0AEC0" }}>
                      No departments found
                    </span>
                  }
                />
              ))}

            {!filter.allDepts && filter.selectedDeptCodes.length > 0 && (
              <div style={{ marginTop: 6, fontSize: 11, color: "#718096" }}>
                {filter.selectedDeptCodes.length} department
                {filter.selectedDeptCodes.length !== 1 ? "s" : ""} selected
              </div>
            )}
          </div>
        </FilterCard>
      )}

      {/* Item Filter */}
      {filterConfigs.some((f) => f.type === "item") && (
        <FilterCard icon={<UnorderedListOutlined />} title="Item Filter">
          <div>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                marginBottom: 6,
              }}
            >
              <FieldLabel label="Item" />
              <Checkbox
                checked={filter.allItems}
                onChange={(e) =>
                  onFilterChange({
                    allItems: e.target.checked,
                    selectedItemCodes: [],
                  })
                }
                style={{ fontSize: 11, marginBottom: 4 }}
              >
                All Items
              </Checkbox>
            </div>

            {!filter.allItems &&
              (loadingLookups ? (
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    padding: "6px 0",
                  }}
                >
                  <Spin size="small" />
                  <span style={{ fontSize: 11, color: "#A0AEC0" }}>
                    Loading items…
                  </span>
                </div>
              ) : (
                <Select
                  mode="multiple"
                  size="small"
                  placeholder="Select Items…"
                  value={filter.selectedItemCodes}
                  onChange={(v) => onFilterChange({ selectedItemCodes: v })}
                  style={{ width: "100%" }}
                  options={items.map((i) => ({
                    label: `${i.itemCode} - ${i.itemName}`,
                    value: i.itemCode,
                  }))}
                  maxTagCount="responsive"
                  showSearch
                  filterOption={filterOption}
                  notFoundContent={
                    <span style={{ fontSize: 11, color: "#A0AEC0" }}>
                      No items found
                    </span>
                  }
                />
              ))}

            {!filter.allItems && filter.selectedItemCodes.length > 0 && (
              <div style={{ marginTop: 6, fontSize: 11, color: "#718096" }}>
                {filter.selectedItemCodes.length} item
                {filter.selectedItemCodes.length !== 1 ? "s" : ""} selected
              </div>
            )}
          </div>
        </FilterCard>
      )}

      {/* Confirm Status Filter (PO Item-Wise only) */}
      {filterConfigs.some((f) => f.type === "confirmStatus") && (
        <FilterCard icon={<CheckCircleOutlined />} title="Final Approval Status">
          <div>
            <FieldLabel label="Final Approval Status" />
            <Select
              size="small"
              value={filter.confirmStatus}
              onChange={(v) => onFilterChange({ confirmStatus: v })}
              style={{ width: "100%" }}
              options={[
                { label: "All", value: "A" },
                { label: "Approved", value: "Y" },
                { label: "Not Approved", value: "N" },
              ]}
            />
          </div>
        </FilterCard>
      )}

      {/* Supplier Filter */}
      {filterConfigs.some((f) => f.type === "supplier") && (
        <FilterCard icon={<TruckOutlined />} title="Supplier Filter">
          <div>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                marginBottom: 6,
              }}
            >
              <FieldLabel label="Supplier" />
              <Checkbox
                checked={filter.allSuppliers}
                onChange={(e) =>
                  onFilterChange({
                    allSuppliers: e.target.checked,
                    selectedSupplierCodes: [],
                  })
                }
                style={{ fontSize: 11, marginBottom: 4 }}
              >
                All Suppliers
              </Checkbox>
            </div>

            {!filter.allSuppliers &&
              (loadingLookups ? (
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    padding: "6px 0",
                  }}
                >
                  <Spin size="small" />
                  <span style={{ fontSize: 11, color: "#A0AEC0" }}>
                    Loading suppliers…
                  </span>
                </div>
              ) : (
                <Select
                  mode="multiple"
                  size="small"
                  placeholder="Select Suppliers…"
                  value={filter.selectedSupplierCodes}
                  onChange={(v) => onFilterChange({ selectedSupplierCodes: v })}
                  style={{ width: "100%" }}
                  options={suppliers.map((s) => ({
                    label: `${s.slCode} - ${s.slName}`,
                    value: s.slCode,
                  }))}
                  maxTagCount="responsive"
                  showSearch
                  filterOption={filterOption}
                  notFoundContent={
                    <span style={{ fontSize: 11, color: "#A0AEC0" }}>
                      No suppliers found
                    </span>
                  }
                />
              ))}

            {!filter.allSuppliers && filter.selectedSupplierCodes.length > 0 && (
              <div style={{ marginTop: 6, fontSize: 11, color: "#718096" }}>
                {filter.selectedSupplierCodes.length} supplier
                {filter.selectedSupplierCodes.length !== 1 ? "s" : ""} selected
              </div>
            )}
          </div>
        </FilterCard>
      )}

      {/* No extra filters info */}
      {filterConfigs.length === 1 && (
        <div
          style={{
            padding: "10px 14px",
            background: "#EBF8FF",
            border: "1px solid #BEE3F8",
            borderRadius: 8,
            fontSize: 11,
            color: "#2C5282",
            lineHeight: 1.6,
          }}
        >
          <FilterOutlined style={{ marginRight: 6 }} />
          No additional filters for this report type. Just set the date range
          above and generate.
        </div>
      )}
    </>
  );
}
