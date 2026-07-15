import { useState, useEffect, useMemo } from 'react'
import { Modal, Table, Input, ConfigProvider, type TableColumnsType } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import type { PoOpenSummary } from '../types'
import { formatPoNo } from '../types'
import { modalTableTheme } from '@/shared/styles/erpTable'
import { getOpenPOList } from '../api/poCancellationApi'

// ── Open PO picker for Cancellation (mirrors PoListModal, cancel-aware source) ──
// ksp_PO_GetOpenPOList already excludes fully-cancelled/foreclosed POs and POs
// with no remaining open-line balance, so — unlike PoListModal — there is no
// Status/Total Value column and no server pagination: the result set is already
// scoped to "cancellable right now" within the caller's FY.

interface Props {
  open:     boolean
  yfDate:   string
  ylDate:   string
  onSelect: (item: PoOpenSummary) => void
  onClose:  () => void
}

export default function PoOpenListModal({ open, yfDate, ylDate, onSelect, onClose }: Props) {
  const [items,   setItems]   = useState<PoOpenSummary[]>([])
  const [loading, setLoading] = useState(false)
  const [search,  setSearch]  = useState('')

  useEffect(() => {
    if (!open) return
    setSearch('')
    setLoading(true)
    getOpenPOList(yfDate, ylDate)
      .then(setItems)
      .catch(() => setItems([]))
      .finally(() => setLoading(false))
  }, [open, yfDate, ylDate])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((r) =>
      formatPoNo(r.poNo).toLowerCase().includes(q) ||
      r.supplierName.toLowerCase().includes(q))
  }, [items, search])

  const columns: TableColumnsType<PoOpenSummary> = [
    {
      title:     'PO No.',
      dataIndex: 'poNo',
      width:     110,
      render:    (v: number) => <strong style={{ color: '#185FA5', fontFamily: 'monospace' }}>{formatPoNo(v)}</strong>,
    },
    {
      title:     'Supplier',
      dataIndex: 'supplierName',
      ellipsis:  true,
      render:    (v: string) => v || '—',
    },
    {
      title:     'PO Date',
      dataIndex: 'poDate',
      width:     120,
      render:    (v: string) => (v ? dayjs(v).format('DD-MMM-YYYY') : '—'),
    },
  ]

  return (
    <Modal
      title="Find Purchase Order — Open for Cancellation"
      open={open}
      onCancel={onClose}
      footer={null}
      width="min(95vw, 760px)"
      styles={{ body: { padding: '12px 16px' } }}
      destroyOnClose
    >
      <Input
        prefix={<SearchOutlined style={{ color: '#888' }} />}
        placeholder="Search by PO number or supplier…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        onClear={() => setSearch('')}
        allowClear
        style={{ marginBottom: 8 }}
      />

      <div style={{ marginBottom: 8, fontSize: 12, color: '#666' }}>
        {loading ? 'Loading…' : `Showing ${filtered.length} record${filtered.length !== 1 ? 's' : ''}`}
      </div>

      <div style={{ maxHeight: 360, overflowY: 'auto' }}>
        <ConfigProvider theme={modalTableTheme}>
          <Table<PoOpenSummary>
            className="erp-modal-anttable"
            dataSource={filtered}
            columns={columns}
            rowKey={(r) => `${r.poNo}-${r.poDate}-${r.poGrp}`}
            loading={loading}
            size="small"
            pagination={false}
            locale={{ emptyText: search ? `No open POs match "${search}"` : 'No open purchase orders found.' }}
            onRow={(record) => ({
              onClick: () => { onSelect(record); onClose() },
              style:   { cursor: 'pointer' },
            })}
          />
        </ConfigProvider>
      </div>
    </Modal>
  )
}
