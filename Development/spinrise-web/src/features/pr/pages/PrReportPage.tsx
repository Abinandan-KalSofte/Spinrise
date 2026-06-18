import { FileExcelOutlined, CloseOutlined, BarChartOutlined } from '@ant-design/icons'
import { SectionLoader } from '@/components/common/loading'
import { PRDocBand, TbBtn, TbSep } from '../components/pr-form/PRToolbar'
import PrReportFilterBar from '../components/pr-report/PrReportFilterBar'
import { usePrReport } from '../hooks/usePrReport'
import { usePageTitle } from '@/shared/hooks/usePageTitle'

// ── Report type hint shown in the empty-state body ────────────────────────────
const HINT: Record<string, string> = {
  Datewise:       'Select a date range and click Report to download the Datewise PR list.',
  Departmentwise: 'Select a date range and at least one Department, then click Report.',
  Itemwise:       'Select a date range. Use All Items or choose specific items, then click Report.',
}

export default function PrReportPage() {
  usePageTitle('Purchase Requisition Report')

  const {
    filter, departments, items, loadingLookups, generating,
    setFilter, setReportType, handleGenerate, handleExit,
  } = usePrReport()

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>

      {/* ── Doc Band ─────────────────────────────────────────────────────────── */}
      <PRDocBand
        breadcrumb={['Purchase Order', 'Purchase Requisition Report']}
        subLabel="Report Type"
        subValue={filter.reportType}
      />

      {/* ── Toolbar — Report + Exit only (CR §4.2: no Crystal, no Preview) ──── */}
      <div style={{
        background:   '#fff',
        borderBottom: '1px solid #e2e2e2',
        display:      'flex',
        alignItems:   'center',
        gap:           4,
        padding:      '0 12px',
        height:        44,
        flexShrink:    0,
      }}>
        <TbBtn
          variant="success"
          icon={<FileExcelOutlined style={{ fontSize: 11 }} />}
          label="Report"
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
      </div>

      {/* ── Filter Panel ─────────────────────────────────────────────────────── */}
      <PrReportFilterBar
        filter={filter}
        departments={departments}
        items={items}
        loadingLookups={loadingLookups}
        onFilterChange={setFilter}
        onReportTypeChange={setReportType}
      />

      {/* ── Body ─────────────────────────────────────────────────────────────── */}
      <div style={{
        flex:          1,
        display:       'flex',
        flexDirection: 'column',
        overflow:      'hidden',
        background:    '#fff',
      }}>
        {generating ? (
          <SectionLoader message="Generating Excel report…" />
        ) : (
          <div style={{
            flex:          1,
            display:       'flex',
            flexDirection: 'column',
            alignItems:    'center',
            justifyContent:'center',
            padding:        48,
            gap:            12,
          }}>
            <BarChartOutlined style={{ fontSize: 44, color: '#185FA5', opacity: 0.18 }} />
            <div style={{ fontSize: 14, fontWeight: 600, color: '#555' }}>
              Ready to Generate Report
            </div>
            <div style={{
              fontSize:   12,
              color:      '#999',
              textAlign:  'center',
              maxWidth:   480,
              lineHeight: 1.8,
            }}>
              {HINT[filter.reportType]}
            </div>
            <div style={{
              marginTop:    8,
              fontSize:     11,
              color:        '#bbb',
              display:      'flex',
              alignItems:   'center',
              gap:           6,
            }}>
              <FileExcelOutlined />
              <span>Output: EPPlus Excel (.xlsx) — Landscape, A4</span>
            </div>
          </div>
        )}
      </div>

    </div>
  )
}
