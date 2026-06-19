import { useCallback, useRef, useState } from 'react'
import { Button, Modal, Spin, Tooltip } from 'antd'
import {
  CloseOutlined,
  ColumnWidthOutlined,
  CompressOutlined,
  DownloadOutlined,
  FilePdfOutlined,
  MinusOutlined,
  PlusOutlined,
  WarningOutlined,
} from '@ant-design/icons'
import { Document, Page, pdfjs } from 'react-pdf'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'
import { triggerDownload } from '../../api/prReportApi'

// Configure PDF.js worker once at module scope
pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString()

// ── Constants ─────────────────────────────────────────────────────────────────

const ZOOM_STEP    = 0.25
const ZOOM_MIN     = 0.25
const ZOOM_MAX     = 3.0
const ZOOM_DEFAULT = 1.0

// ── Design tokens ─────────────────────────────────────────────────────────────

const VIEWER_BG   = '#525659'   // grey PDF viewer background (matches Adobe/Chrome)
const TOOLBAR_BG  = '#F8FAFC'
const BORDER      = '#E2E8F0'
const PAGE_SHADOW = '0 2px 12px rgba(0,0,0,0.45)'

// ── Props ─────────────────────────────────────────────────────────────────────

interface Props {
  open:     boolean
  blobUrl:  string | null
  filename: string
  loading:  boolean
  onClose:  () => void
}

// ── Component ─────────────────────────────────────────────────────────────────

export function ReportPreviewModal({ open, blobUrl, filename, loading, onClose }: Props) {
  const [numPages,    setNumPages]    = useState(0)
  const [scale,       setScale]       = useState(ZOOM_DEFAULT)
  const [naturalW,    setNaturalW]    = useState(0)   // natural page width at scale=1
  const [pdfError,    setPdfError]    = useState<string | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)

  // ── Handlers ──────────────────────────────────────────────────────────────

  const onDocumentLoadSuccess = ({ numPages: n }: { numPages: number }) => {
    setNumPages(n)
    setPdfError(null)
  }

  const onDocumentLoadError = (err: Error) => {
    setPdfError(err.message || 'Unable to load the PDF document.')
  }

  // Capture the natural (unscaled) width from the first page for Fit Width
  const onFirstPageLoad = useCallback((page: { getViewport: (p: { scale: number }) => { width: number } }) => {
    const vp = page.getViewport({ scale: 1 })
    setNaturalW(vp.width)
  }, [])

  const zoomIn  = () => setScale((s) => parseFloat(Math.min(s + ZOOM_STEP, ZOOM_MAX).toFixed(2)))
  const zoomOut = () => setScale((s) => parseFloat(Math.max(s - ZOOM_STEP, ZOOM_MIN).toFixed(2)))

  const fitWidth = useCallback(() => {
    if (!scrollRef.current || !naturalW) return
    const containerW = scrollRef.current.clientWidth - 48  // 24px padding each side
    setScale(parseFloat((containerW / naturalW).toFixed(2)))
  }, [naturalW])

  const fitPage = () => setScale(ZOOM_DEFAULT)

  const handleDownload = () => {
    if (blobUrl) triggerDownload(blobUrl, filename)
  }

  const handleClose = () => {
    setNumPages(0)
    setScale(ZOOM_DEFAULT)
    setNaturalW(0)
    setPdfError(null)
    onClose()
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  const canZoomIn  = numPages > 0 && scale < ZOOM_MAX
  const canZoomOut = numPages > 0 && scale > ZOOM_MIN
  const hasPdf     = !!blobUrl && !loading

  const toolbar = (
    <div style={{
      display:      'flex',
      alignItems:   'center',
      gap:           6,
      padding:      '7px 14px',
      borderBottom: `1px solid ${BORDER}`,
      background:    TOOLBAR_BG,
      flexShrink:    0,
    }}>

      {/* Zoom out */}
      <Tooltip title="Zoom Out (−)">
        <Button size="small" icon={<MinusOutlined />} disabled={!canZoomOut} onClick={zoomOut} />
      </Tooltip>

      {/* Zoom level badge */}
      <div style={{
        minWidth:   52,
        textAlign:  'center',
        fontSize:    12,
        fontWeight:  700,
        color:      '#2D3748',
        padding:    '1px 8px',
        background: '#EDF2F7',
        border:     `1px solid ${BORDER}`,
        borderRadius: 4,
        lineHeight: '22px',
        fontVariantNumeric: 'tabular-nums',
      }}>
        {Math.round(scale * 100)}%
      </div>

      {/* Zoom in */}
      <Tooltip title="Zoom In (+)">
        <Button size="small" icon={<PlusOutlined />} disabled={!canZoomIn} onClick={zoomIn} />
      </Tooltip>

      {/* Separator */}
      <div style={{ width: 1, height: 20, background: BORDER, margin: '0 4px' }} />

      {/* Fit Width */}
      <Tooltip title="Scale to container width">
        <Button
          size="small"
          icon={<ColumnWidthOutlined />}
          disabled={!hasPdf || !numPages}
          onClick={fitWidth}
        >
          Fit Width
        </Button>
      </Tooltip>

      {/* Fit Page */}
      <Tooltip title="Reset to 100%">
        <Button
          size="small"
          icon={<CompressOutlined />}
          disabled={!hasPdf || !numPages}
          onClick={fitPage}
        >
          Fit Page
        </Button>
      </Tooltip>

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* Page count */}
      {numPages > 0 && (
        <span style={{ fontSize: 11, color: '#718096', fontWeight: 500, marginRight: 4 }}>
          {numPages} {numPages === 1 ? 'page' : 'pages'}
        </span>
      )}

      {/* Separator */}
      <div style={{ width: 1, height: 20, background: BORDER, margin: '0 4px' }} />

      {/* Download */}
      <Button
        size="small"
        type="primary"
        icon={<DownloadOutlined />}
        disabled={!hasPdf}
        onClick={handleDownload}
        style={{ background: '#185FA5', borderColor: '#185FA5' }}
      >
        Download PDF
      </Button>

      {/* Close */}
      <Button size="small" icon={<CloseOutlined />} onClick={handleClose}>
        Close
      </Button>
    </div>
  )

  // ── Body states ───────────────────────────────────────────────────────────

  const loadingState = (
    <div style={{
      display:        'flex',
      flexDirection:  'column',
      alignItems:     'center',
      justifyContent: 'center',
      flex:            1,
      gap:             16,
    }}>
      <div style={{
        width: 64, height: 64, borderRadius: 14,
        background: 'linear-gradient(135deg, #C53030 0%, #E53E3E 100%)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 4px 20px rgba(197,48,48,0.35)',
      }}>
        <Spin indicator={
          <span style={{ fontSize: 28, color: '#fff', display: 'flex', alignItems: 'center' }}>
            <FilePdfOutlined />
          </span>
        } spinning />
      </div>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: '#E2E8F0', marginBottom: 4 }}>
          Generating PDF
        </div>
        <div style={{ fontSize: 12, color: '#A0AEC0' }}>
          Please wait while the report is being built…
        </div>
      </div>
    </div>
  )

  const errorState = (
    <div style={{
      display:        'flex',
      flexDirection:  'column',
      alignItems:     'center',
      justifyContent: 'center',
      flex:            1,
      gap:             12,
    }}>
      <WarningOutlined style={{ fontSize: 48, color: '#FC8181' }} />
      <div style={{ fontSize: 14, fontWeight: 700, color: '#FED7D7' }}>
        Failed to load PDF
      </div>
      <div style={{ fontSize: 12, color: '#FC8181', maxWidth: 360, textAlign: 'center' }}>
        {pdfError}
      </div>
    </div>
  )

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Modal
      open={open}
      onCancel={handleClose}
      width="90vw"
      style={{ top: 16, maxWidth: 1400, padding: 0, overflow: 'hidden' }}
      styles={{
        header:  {
          padding:      '10px 16px',
          borderBottom: `1px solid ${BORDER}`,
          margin:        0,
          background:    TOOLBAR_BG,
        },
        body: {
          padding:        0,
          height:         'calc(90vh - 110px)',
          display:        'flex',
          flexDirection:  'column',
          overflow:       'hidden',
        },
      }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <FilePdfOutlined style={{ color: '#C53030', fontSize: 15 }} />
          <span style={{ fontSize: 13, fontWeight: 700, color: '#1A202C' }}>
            Purchase Requisition Report Preview
          </span>
          {filename && (
            <span style={{ fontSize: 11, color: '#A0AEC0', fontWeight: 400, marginLeft: 2 }}>
              — {filename}
            </span>
          )}
        </div>
      }
      footer={null}
      closeIcon={<CloseOutlined />}
      destroyOnClose
    >
      {/* Toolbar */}
      {toolbar}

      {/* Viewer area */}
      <div
        ref={scrollRef}
        style={{
          flex:           1,
          overflow:       'auto',
          background:     VIEWER_BG,
          display:        'flex',
          flexDirection:  'column',
          alignItems:     'center',
          padding:        '20px 24px 32px',
          gap:             12,
        }}
      >
        {/* Loading state */}
        {(loading || (!blobUrl && !pdfError)) && loadingState}

        {/* Error state */}
        {!loading && pdfError && errorState}

        {/* PDF Document */}
        {hasPdf && (
          <Document
            file={blobUrl}
            onLoadSuccess={onDocumentLoadSuccess}
            onLoadError={onDocumentLoadError}
            loading={
              <div style={{
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', gap: 16, paddingTop: 80,
              }}>
                <Spin size="large" />
                <span style={{ fontSize: 12, color: '#CBD5E0' }}>Loading document…</span>
              </div>
            }
            error={
              <div style={{
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', gap: 12, paddingTop: 80,
                color: '#FC8181',
              }}>
                <WarningOutlined style={{ fontSize: 32 }} />
                <span style={{ fontSize: 12 }}>Could not render document</span>
              </div>
            }
          >
            {Array.from({ length: numPages }, (_, i) => {
              const pageNum = i + 1
              return (
                <div
                  key={pageNum}
                  style={{
                    background:   '#fff',
                    boxShadow:     PAGE_SHADOW,
                    lineHeight:    0,
                    flexShrink:    0,
                    marginBottom:  pageNum < numPages ? 0 : undefined,
                  }}
                >
                  <Page
                    pageNumber={pageNum}
                    scale={scale}
                    renderTextLayer
                    renderAnnotationLayer
                    onLoadSuccess={pageNum === 1 ? onFirstPageLoad as never : undefined}
                  />
                </div>
              )
            })}
          </Document>
        )}
      </div>
    </Modal>
  )
}
