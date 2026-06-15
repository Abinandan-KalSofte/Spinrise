import { useEffect, useState } from 'react'
import { Modal, Result, Descriptions, Table } from 'antd'
import { ModalLoader } from '@/components/common/loading'
import type { ColumnsType } from 'antd/es/table'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getById } from '../../api/prApi'
import type { PrHeader, PrLine } from '../../types'
import PrStatusBadge from '../PrStatusBadge'

// Raw prstatus DB char → readable label (mirrors ksp_PR_GetOpenForForeclosure CASE logic)
const LINE_STATUS_BADGE: Record<string, { label: string; color: string; bg: string; border: string }> = {
  '':  { label: 'Requested',      color: '#185FA5', bg: '#E6F1FB', border: '#bfdbfe' },
  'F': { label: 'First Approved', color: '#166534', bg: '#dcfce7', border: '#86efac' },
  'E': { label: 'Enquired',       color: '#185FA5', bg: '#E6F1FB', border: '#bfdbfe' },
  'O': { label: 'Ordered',        color: '#7c3aed', bg: '#f3e8ff', border: '#ddd6fe' },
  'C': { label: 'Received',       color: '#3B6D11', bg: '#EAF3DE', border: '#86efac' },
  'X': { label: 'Cancelled',      color: '#A32D2D', bg: '#FCEBEB', border: '#fca5a5' },
  'Z': { label: 'Force Closed',   color: '#888',    bg: '#f0f0f0', border: '#d0d0d0' },
}

function LineStatusBadge({ status }: { status: string }) {
  const cfg = LINE_STATUS_BADGE[status] ?? LINE_STATUS_BADGE['']
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 10,
      color: cfg.color, background: cfg.bg, border: `1px solid ${cfg.border}`,
      whiteSpace: 'nowrap',
    }}>
      {cfg.label}
    </span>
  )
}

const TYPE_LABEL: Record<string, string> = {
  'N': 'Normal',
  'U': 'Urgent',
  'S': 'Special',
}

const LINE_COLS: ColumnsType<PrLine> = [
  { title: '#',          dataIndex: 'prSno',    width: 40,  align: 'center', render: (v: number) => <span style={{ fontSize: 11, color: '#888' }}>{v}</span> },
  { title: 'Item Code',  dataIndex: 'itemCode', width: 90,  render: (v: string) => <span style={{ fontSize: 11, fontFamily: 'monospace', fontWeight: 600 }}>{v}</span> },
  { title: 'Item Name',  dataIndex: 'itemName', render: (v: string) => <span style={{ fontSize: 11 }}>{v}</span> },
  { title: 'UOM',        dataIndex: 'uom',      width: 55,  align: 'center', render: (v: string) => <span style={{ fontSize: 11 }}>{v || '—'}</span> },
  { title: 'Quantity',   dataIndex: 'qtyInd',   width: 90,  align: 'right',  render: (v: number) => <span style={{ fontSize: 11 }}>{v.toFixed(3)}</span> },
  { title: 'Rate',       dataIndex: 'rate',     width: 90,  align: 'right',  render: (v: number) => <span style={{ fontSize: 11 }}>{v.toFixed(4)}</span> },
  { title: 'App. Cost',  dataIndex: 'appCost',  width: 90,  align: 'right',  render: (v: number) => <span style={{ fontSize: 11 }}>{v.toFixed(2)}</span> },
  { title: 'Cost Centre',dataIndex: 'ccName',   width: 120, render: (_: unknown, r: PrLine) => <span style={{ fontSize: 11 }}>{r.ccName || (r.ccCode ? String(r.ccCode) : '—')}</span> },
  {
    title: 'Status', dataIndex: 'lineStatus', width: 110, align: 'center',
    render: (v: string) => <LineStatusBadge status={v ?? ''} />,
  },
]

interface Props {
  prNo:    number | null
  prDate:  string | null
  onClose: () => void
}

export default function PrViewModal({ prNo, prDate, onClose }: Props) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')
  const [loading, setLoading] = useState(false)
  const [pr,      setPr]      = useState<PrHeader | null>(null)
  const [error,   setError]   = useState(false)

  const open = prNo != null && prDate != null

  useEffect(() => {
    if (!open) { setPr(null); setError(false); return }
    let cancelled = false
    setLoading(true)
    setError(false)
    setPr(null)
    void getById(divCode, prNo!, prDate!).then((data) => {
      if (!cancelled) setPr(data)
    }).catch(() => {
      if (!cancelled) setError(true)
    }).finally(() => {
      if (!cancelled) setLoading(false)
    })
    return () => { cancelled = true }
  }, [open, divCode, prNo, prDate])

  const totalLines = pr?.lines.length ?? 0
  const totalQty   = pr?.lines.reduce((s, l) => s + l.qtyInd, 0) ?? 0

  return (
    <Modal
      open={open}
      onCancel={onClose}
      title={
        pr
          ? `Purchase Requisition — PR No. ${String(pr.prNo).padStart(5, '0')} (${pr.prDate})`
          : 'Purchase Requisition'
      }
      width={1000}
      footer={null}
      destroyOnClose
      styles={{ body: { paddingTop: 8, maxHeight: '80vh', overflowY: 'auto' } }}
    >
      {loading && <ModalLoader message="Loading PR details…" rows={5} />}

      {error && !loading && (
        <Result
          status="error"
          title="Failed to Load"
          subTitle="Could not retrieve PR details. Please try again."
        />
      )}

      {pr && !loading && (
        <>
          {/* ── Header fields ── */}
          <Descriptions
            bordered
            size="small"
            column={{ xs: 1, sm: 2, md: 3 }}
            style={{ marginBottom: 16 }}
            labelStyle={{ fontSize: 11, fontWeight: 600, whiteSpace: 'nowrap', width: 110 }}
            contentStyle={{ fontSize: 11 }}
          >
            <Descriptions.Item label="PR No.">
              <span style={{ fontFamily: 'monospace', fontWeight: 700 }}>
                {String(pr.prNo).padStart(5, '0')}
              </span>
            </Descriptions.Item>
            <Descriptions.Item label="PR Date">{pr.prDate || '—'}</Descriptions.Item>
            <Descriptions.Item label="Status">
              <PrStatusBadge status={pr.prStatus} />
            </Descriptions.Item>
            <Descriptions.Item label="Department">{pr.depName || pr.depCode || '—'}</Descriptions.Item>
            <Descriptions.Item label="Requester">{pr.reqEmpName || pr.reqName || '—'}</Descriptions.Item>
            <Descriptions.Item label="Type">{(TYPE_LABEL[pr.iType] ?? pr.iType) || '—'}</Descriptions.Item>
            <Descriptions.Item label="Description" span={2}>{pr.iDesc || '—'}</Descriptions.Item>
            <Descriptions.Item label="Ref. No.">{pr.refNo || '—'}</Descriptions.Item>
          </Descriptions>

          {/* ── Lines table ── */}
          <Table<PrLine>
            columns={LINE_COLS}
            dataSource={pr.lines}
            rowKey="prSno"
            size="small"
            pagination={false}
            scroll={{ x: 800 }}
            style={{ fontSize: 11 }}
          />

          {/* ── Summary strip ── */}
          <div style={{
            marginTop: 10, padding: '7px 14px',
            background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 6,
            display: 'flex', gap: 24,
          }}>
            {[
              { label: 'Total Lines', val: String(totalLines) },
              { label: 'Total Qty',   val: totalQty.toFixed(3) },
            ].map(({ label, val }) => (
              <span key={label} style={{ fontSize: 11, color: '#4A4A4A', display: 'flex', alignItems: 'center', gap: 5 }}>
                {label}: <strong style={{ fontFamily: 'monospace', fontSize: 13, color: '#185FA5' }}>{val}</strong>
              </span>
            ))}
          </div>
        </>
      )}
    </Modal>
  )
}
