import {
  BarChartOutlined,
  CalendarOutlined,
  CloseOutlined,
  FilePdfOutlined,
  FunnelPlotOutlined,
  LoadingOutlined,
} from '@ant-design/icons'
import { Spin, Tag } from 'antd'
import dayjs from 'dayjs'
import { PRDocBand, TbBtn, TbSep } from '../components/pr-form/PRToolbar'
import PrReportFilterBar from '../components/pr-report/PrReportFilterBar'
import { ReportPreviewModal } from '../components/pr-report/ReportPreviewModal'
import { usePrReport } from '../hooks/usePrReport'
import { usePageTitle } from '@/shared/hooks/usePageTitle'

// ── Design tokens ─────────────────────────────────────────────────────────────
const BG     = '#F4F6F9'
const CARD   = '#fff'
const BORDER = '#E2E8F0'

// ── Report-type hint text ─────────────────────────────────────────────────────
const HINT: Record<string, string> = {
  Datewise:       'Select a date range and click Generate Report to download the Datewise PR list as a PDF.',
  Departmentwise: 'Select a date range and a Department, then click Generate Report.',
  Itemwise:       'Select a date range. Use All Items or choose specific items, then click Generate Report.',
}

// ── KPI mini-card ─────────────────────────────────────────────────────────────

interface KpiCardProps {
  icon:   React.ReactNode
  label:  string
  value:  string
  accent: string
}

function KpiCard({ icon, label, value, accent }: KpiCardProps) {
  return (
    <div style={{
      flex: 1, minWidth: 0,
      background: CARD,
      border: `1px solid ${BORDER}`,
      borderRadius: 8,
      padding: '10px 12px',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
    }}>
      <div style={{
        width: 34, height: 34, borderRadius: 8, flexShrink: 0,
        background: `${accent}1A`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: accent, fontSize: 16,
      }}>
        {icon}
      </div>
      <div style={{ minWidth: 0 }}>
        <div style={{
          fontSize: 10, fontWeight: 700, color: '#A0AEC0',
          textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 2,
        }}>
          {label}
        </div>
        <div style={{
          fontSize: 12, fontWeight: 700, color: '#1A202C',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>
          {value}
        </div>
      </div>

    </div>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function PrReportPage() {
  usePageTitle('Purchase Requisition Report')

  const {
    filter, departments, items, loadingLookups, generating,
    previewOpen, previewBlobUrl, previewFilename,
    setFilter, setReportType, handleGenerate, closePreview, handleExit,
  } = usePrReport()

  // ── KPI computed values ──────────────────────────────────────────────────────
  const dateRangeLabel =
    filter.fromDate && filter.toDate
      ? `${dayjs(filter.fromDate).format('DD MMM YY')} – ${dayjs(filter.toDate).format('DD MMM YY')}`
      : 'Not configured'

  const filterLabel =
    filter.reportType === 'Departmentwise'
      ? filter.selectedDeptCode
        ? filter.selectedDeptCode
        : 'No dept'
      : filter.reportType === 'Itemwise'
        ? filter.allItems
          ? 'All items'
          : filter.selectedItemCodes.length > 0
            ? `${filter.selectedItemCodes.length} item${filter.selectedItemCodes.length !== 1 ? 's' : ''}`
            : 'No items'
        : 'Date range only'

  // Type badge color
  const typeColor: Record<string, string> = {
    Datewise: 'blue', Departmentwise: 'purple', Itemwise: 'gold',
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden', background: BG }}>

      {/* ── Doc Band ──────────────────────────────────────────────────────────── */}
      <PRDocBand
        breadcrumb={['Purchase Order', 'Purchase Requisition Report']}
        subLabel="Report Type"
        subValue={filter.reportType}
      />

      {/* ── Toolbar ───────────────────────────────────────────────────────────── */}
      <div style={{
        background:   CARD,
        borderBottom: `1px solid ${BORDER}`,
        display:      'flex',
        alignItems:   'center',
        gap:           6,
        padding:      '0 16px',
        height:        48,
        flexShrink:    0,
      }}>
        <TbBtn
          variant="success"
          icon={
            generating
              ? <Spin indicator={<LoadingOutlined style={{ fontSize: 11, color: '#fff' }} />} size="small" />
              : <FilePdfOutlined style={{ fontSize: 12 }} />
          }
          label={generating ? 'Generating…' : 'Generate Report'}
          kbd="Alt+R"
          disabled={generating}
          onClick={() => void handleGenerate()}
        />
        <TbSep />
        <TbBtn
          variant="danger-filled"
          icon={<CloseOutlined style={{ fontSize: 11 }} />}
          label="Exit"
          onClick={handleExit}
        />
        <div style={{ flex: 1 }} />
        {generating && (
          <span style={{ fontSize: 11, color: '#185FA5', fontWeight: 500, fontStyle: 'italic' }}>
            Building PDF — opening preview…
          </span>
        )}
      </div>

      {/* ── Main layout: filter left + preview right ───────────────────────── */}
      <div style={{ flex: 1, display: 'flex', overflow: 'hidden' }}>

        {/* ─ Left: Filter panel ──────────────────────────────────────────────── */}
        <div style={{
          width:      460,
          flexShrink: 0,
          background: BG,
          borderRight: `1px solid ${BORDER}`,
          overflowY:  'auto',
          padding:    '14px 14px 24px',
          display:    'flex',
          flexDirection: 'column',
          gap:         12,
        }}>
          {/* Panel header */}
          <div style={{
            fontSize: 11, fontWeight: 700, color: '#4A5568',
            textTransform: 'uppercase', letterSpacing: '0.07em',
            paddingBottom: 6, borderBottom: `1px solid ${BORDER}`,
          }}>
            Filter Configuration
          </div>

          <PrReportFilterBar
            filter={filter}
            departments={departments}
            items={items}
            loadingLookups={loadingLookups}
            onFilterChange={setFilter}
            onReportTypeChange={setReportType}
          />
        </div>

        {/* ─ Right: Summary + Preview ────────────────────────────────────────── */}
        <div style={{
          flex:           1,
          overflow:       'hidden',
          display:        'flex',
          flexDirection:  'column',
          padding:        '14px 16px 16px',
          gap:             12,
        }}>

          {/* KPI summary row */}
          <div style={{ display: 'flex', gap: 10, flexShrink: 0 }}>
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

          {/* Preview card */}
          <div style={{
            flex:           1,
            background:     CARD,
            border:         `1px solid ${BORDER}`,
            borderRadius:    10,
            overflow:       'hidden',
            display:        'flex',
            flexDirection:  'column',
          }}>

            {/* Preview card header bar */}
            <div style={{
              padding:      '9px 16px',
              borderBottom: `1px solid ${BORDER}`,
              display:      'flex',
              alignItems:   'center',
              gap:           8,
              background:   '#FAFBFD',
              flexShrink:   0,
            }}>
              <BarChartOutlined style={{ color: '#185FA5', fontSize: 13 }} />
              <span style={{ fontSize: 12, fontWeight: 600, color: '#2D3748' }}>Report Preview</span>
              <div style={{ flex: 1 }} />
              <Tag
                color={typeColor[filter.reportType] ?? 'blue'}
                style={{ fontSize: 10, margin: 0, lineHeight: '18px' }}
              >
                {filter.reportType}
              </Tag>
              {filter.fromDate && filter.toDate && (
                <Tag color="default" style={{ fontSize: 10, margin: 0, lineHeight: '18px' }}>
                  {dayjs(filter.fromDate).format('DD MMM YY')} – {dayjs(filter.toDate).format('DD MMM YY')}
                </Tag>
              )}
            </div>

            {/* Preview body */}
            <div style={{
              flex:           1,
              display:        'flex',
              flexDirection:  'column',
              alignItems:     'center',
              justifyContent: 'center',
              padding:        40,
            }}>
              {generating ? (

                /* ── Generating state ── */
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
                  <div style={{
                    width: 72, height: 72, borderRadius: 16,
                    background: 'linear-gradient(135deg, #C53030 0%, #E53E3E 100%)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: '0 4px 20px rgba(197,48,48,0.3)',
                  }}>
                    <Spin
                      indicator={<LoadingOutlined style={{ fontSize: 32, color: '#fff' }} />}
                      size="large"
                    />
                  </div>
                  <div style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 15, fontWeight: 700, color: '#1A202C', marginBottom: 6 }}>
                      Generating Report
                    </div>
                    <div style={{ fontSize: 12, color: '#718096', lineHeight: 1.8 }}>
                      Building your {filter.reportType} PR report from the database.
                      <br />The preview will open automatically when ready.
                    </div>
                  </div>
                </div>

              ) : (

                /* ── Ready state ── */
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, maxWidth: 440, textAlign: 'center' }}>

                  {/* PDF icon */}
                  <div style={{
                    width: 72, height: 72, borderRadius: 16,
                    background: 'linear-gradient(135deg, #C53030 0%, #E53E3E 100%)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: '0 4px 20px rgba(197,48,48,0.2)',
                  }}>
                    <FilePdfOutlined style={{ fontSize: 34, color: '#fff' }} />
                  </div>

                  <div>
                    <div style={{ fontSize: 16, fontWeight: 700, color: '#1A202C', marginBottom: 8 }}>
                      Ready to Generate
                    </div>
                    <div style={{ fontSize: 12, color: '#718096', lineHeight: 1.9 }}>
                      {HINT[filter.reportType]}
                    </div>
                  </div>

                  {/* Divider */}
                  <div style={{ width: 48, height: 2, background: '#E2E8F0', borderRadius: 1 }} />

                  {/* Output format badge */}
                  <div style={{
                    display: 'flex', alignItems: 'center', gap: 8,
                    padding: '8px 16px',
                    background: '#FFF5F5',
                    border: '1px solid #FED7D7',
                    borderRadius: 8,
                  }}>
                    <FilePdfOutlined style={{ color: '#C53030', fontSize: 13 }} />
                    <span style={{ fontSize: 11, color: '#C53030', fontWeight: 600 }}>
                      QuestPDF (.pdf) · A4 · Landscape
                    </span>
                  </div>

                  {/* Keyboard hint */}
                  <div style={{ fontSize: 11, color: '#A0AEC0', marginTop: -4 }}>
                    Press{' '}
                    <kbd style={{
                      display: 'inline-block',
                      padding: '1px 5px',
                      background: '#EDF2F7',
                      border: '1px solid #CBD5E0',
                      borderRadius: 4,
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: '#4A5568',
                    }}>
                      Alt+R
                    </kbd>
                    {' '}to generate instantly
                  </div>

                </div>
              )}
            </div>
          </div>

        </div>
      </div>

      <ReportPreviewModal
        open={previewOpen}
        blobUrl={previewBlobUrl}
        filename={previewFilename}
        loading={generating}
        onClose={closePreview}
      />

    </div>
  )
}
