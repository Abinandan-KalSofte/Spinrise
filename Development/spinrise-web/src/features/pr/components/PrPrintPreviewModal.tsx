import { useEffect, useRef, useState } from 'react'
import { Button, Modal, Spin } from 'antd'
import { DownloadOutlined, PrinterOutlined, CloseOutlined } from '@ant-design/icons'

interface Props {
  open: boolean
  blobUrl: string | null
  filename: string
  loading: boolean
  onClose: () => void
}

export function PrPrintPreviewModal({ open, blobUrl, filename, loading, onClose }: Props) {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const [iframeReady, setIframeReady] = useState(false)

  useEffect(() => {
    if (!open) setIframeReady(false)
  }, [open])

  const handleDownload = () => {
    if (!blobUrl) return
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = filename
    a.click()
  }

  const handlePrint = () => {
    iframeRef.current?.contentWindow?.print()
  }

  return (
    <Modal
      open={open}
      onCancel={onClose}
      title={
        <span style={{ fontSize: 13, fontWeight: 600, color: '#1e293b' }}>
          Print Preview — {filename}
        </span>
      }
      width="90vw"
      style={{ top: 20 }}
      styles={{ body: { padding: 0, height: 'calc(90vh - 110px)', overflow: 'hidden' } }}
      footer={
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
          <Button icon={<CloseOutlined />} onClick={onClose}>
            Close
          </Button>
          <Button
            icon={<DownloadOutlined />}
            disabled={!blobUrl || loading}
            onClick={handleDownload}
          >
            Download PDF
          </Button>
          <Button
            type="primary"
            icon={<PrinterOutlined />}
            disabled={!blobUrl || loading || !iframeReady}
            onClick={handlePrint}
            style={{ background: '#1e293b', borderColor: '#1e293b' }}
          >
            Print
          </Button>
        </div>
      }
      destroyOnClose
      closeIcon={<CloseOutlined />}
    >
      {loading || !blobUrl ? (
        <div style={{
          height: '100%', display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', gap: 12,
          background: '#f8fafc',
        }}>
          <Spin size="large" />
          <span style={{ fontSize: 13, color: '#64748b' }}>Generating PDF…</span>
        </div>
      ) : (
        <iframe
          ref={iframeRef}
          src={blobUrl}
          title="PR Print Preview"
          style={{ width: '100%', height: '100%', border: 'none', display: 'block' }}
          onLoad={() => setIframeReady(true)}
        />
      )}
    </Modal>
  )
}
