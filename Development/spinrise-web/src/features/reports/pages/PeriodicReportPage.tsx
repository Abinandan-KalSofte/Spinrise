import { useState } from 'react'
import {
  CloseOutlined,
  FilePdfOutlined,
  LoadingOutlined,
} from '@ant-design/icons'
import { Spin } from 'antd'
import { useLocation } from 'react-router-dom'
import { PRDocBand, TbBtn, TbSep } from '../../pr/components/pr-form/PRToolbar'
import { ReportPreviewModal } from '../components/ReportPreviewModal'
import { ReportModuleSelector } from '../components/ReportModuleSelector'
import { DynamicFilterRenderer } from '../components/DynamicFilterRenderer'
import { SummaryBar } from '../components/SummaryBar'
import { ReportPreview } from '../components/ReportPreview'
import { useReport } from '../hooks/useReport'
import { useReportStore } from '../store/useReportStore'
import { usePageTitle } from '@/shared/hooks/usePageTitle'
import { usePageReset } from '@/shared/hooks/usePageReset'

const BG = '#F4F6F9'
const CARD = '#fff'
const BORDER = '#E2E8F0'

const containerStyle: React.CSSProperties = { display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden', background: BG }
const toolbarStyle: React.CSSProperties = { background: CARD, borderBottom: `1px solid ${BORDER}`, display: 'flex', alignItems: 'center', gap: 6, padding: '0 16px', height: 48, flexShrink: 0 }
const mainLayoutStyle: React.CSSProperties = { flex: 1, display: 'flex', overflow: 'hidden' }
const leftPanelStyle: React.CSSProperties = { width: 550, flexShrink: 0, background: CARD, borderRight: `1px solid ${BORDER}`, overflowY: 'auto', padding: '14px', display: 'flex', flexDirection: 'column', gap: 12 }
const filterContainerStyle: React.CSSProperties = { flex: 1, overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 12, paddingBottom: 12 }
const rightPanelStyle: React.CSSProperties = { flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', padding: '14px 16px 16px', gap: 12 }
const loadingTextStyle: React.CSSProperties = { fontSize: 11, color: '#185FA5', fontWeight: 500, fontStyle: 'italic' }
const flexSpacerStyle: React.CSSProperties = { flex: 1 }

// Map route paths to report IDs
// /periodic-report = null (no default selection - user must choose)
// Old routes kept for backward compatibility
const ROUTE_TO_REPORT_ID: Record<string, string | null> = {
  '/pr-report': 'pr-report',
  '/pending-pr-report': 'pending-pr-report',
  '/periodic-report': null,
}

export default function PeriodicReportPage() {
  const location = useLocation()
  const [selectedReportId, setSelectedReportId] = useState<string | null>(null)

  // Detect report ID from current route for backward compatibility
  const routeReportId = ROUTE_TO_REPORT_ID[location.pathname]

  // Use selected report if on /periodic-report, otherwise use route-based selection
  const activeReportId = location.pathname === '/periodic-report' ? selectedReportId : routeReportId

  // Clears any report/filter left over from a prior visit before useReport's
  // own mount effect (below) runs — otherwise a stale, still-populated
  // store `filter` leaks through the ReportModuleSelector's "already
  // selected" highlight and the filter/summary/preview panels on
  // /periodic-report, since those all key off filter being non-null rather
  // than this page's local `selectedReportId`.
  usePageReset(useReportStore.getState().clear)

  const {
    config,
    filter,
    lookups,
    loadingLookups,
    generating,
    previewOpen,
    previewBlobUrl,
    previewFilename,
    setFilter,
    setReportType,
    handleGenerate,
    closePreview,
    handleExit,
  } = useReport(activeReportId)

  usePageTitle(config?.title || 'Periodic Reports')

  const handleReportChange = (newReportId: string) => {
    if (!newReportId) {
      setSelectedReportId(null)
      return
    }
    setSelectedReportId(newReportId)
  }

  // Only show content if a report is selected
  const isReportSelected = !!config && !!filter

  return (
    <div style={containerStyle}>

      {/* Doc Band */}
      <PRDocBand
        breadcrumb={['Reports', 'Periodic Reports']}
        subLabel="Report"
        subValue={config?.title || 'Select a Report'}
      />

      {/* Toolbar */}
      <div style={toolbarStyle}>
        <TbBtn
          variant="success"
          icon={
            generating
              ? <Spin indicator={<LoadingOutlined style={{ fontSize: 11, color: '#fff' }} />} size="small" />
              : <FilePdfOutlined style={{ fontSize: 12 }} />
          }
          label={generating ? 'Generating…' : 'Generate Report'}
          kbd="Alt+R"
          disabled={generating || !isReportSelected}
          onClick={() => void handleGenerate()}
        />
        <TbSep />
        <TbBtn
          variant="danger-filled"
          icon={<CloseOutlined style={{ fontSize: 11 }} />}
          label="Exit"
          onClick={handleExit}
        />
        <div style={flexSpacerStyle} />
        {generating && (
          <span style={loadingTextStyle}>
            Building PDF — opening preview…
          </span>
        )}
      </div>

      {/* Main layout */}
      <div style={mainLayoutStyle}>

        {/* Left panel: Filters */}
        <div style={leftPanelStyle}>
          {/* Report Module Selector */}
          <ReportModuleSelector
            selectedReportId={filter?.reportId || null}
            onChange={handleReportChange}
          />

          {/* Show tabs, filters, and other content only after selection */}
          {isReportSelected && config && filter && (
            <>
              {/* Filters */}
              <div style={filterContainerStyle}>
                <DynamicFilterRenderer
                  config={config}
                  filter={filter}
                  departments={lookups.departments}
                  items={lookups.items}
                  suppliers={lookups.suppliers}
                  loadingLookups={loadingLookups}
                  onFilterChange={setFilter}
                  onReportTypeChange={setReportType}
                />
              </div>
            </>
          )}
        </div>

        {/* Right panel: Summary + Preview */}
        {isReportSelected && config && filter && (
          <div style={rightPanelStyle}>
            <SummaryBar filter={filter} />
            <ReportPreview config={config} filter={filter} generating={generating} />
          </div>
        )}
      </div>

      {/* Preview Modal */}
      {config && (
        <ReportPreviewModal
          open={previewOpen}
          blobUrl={previewBlobUrl}
          filename={previewFilename}
          loading={generating}
          onClose={closePreview}
          title={config.previewTitle}
        />
      )}

    </div>
  )
}
