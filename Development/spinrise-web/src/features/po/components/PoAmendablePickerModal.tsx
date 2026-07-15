import { useMemo, useState } from 'react'
import { Modal, Table, Input, ConfigProvider, type TableColumnsType } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import type { AmendablePoSummary } from '../types'
import { formatPoNo } from '../types'
import { modalTableTheme } from '@/shared/styles/erpTable'

// ── Amendable PO picker (FN-PO-Amendment v1.2 §1) ────────────────────────────
// Mirrors PoOpenListModal. Source is ksp_PO_GetAmendablePOList, which already
// applies the AmdAfterGRN predicate server-side (open balance, not cancelled /
// foreclosed, current division) — so, as with the cancellation picker, there is
// no client-side eligibility filter and no server pagination: the result set is
// already scoped to "amendable right now" within the caller's FY.
//
// The list is fetched by the hook (openPicker) and passed in, rather than fetched
// here, so the page can show a load error once instead of an empty table.

interface Props {
  open:     boolean
  items:    AmendablePoSummary[]
  loading:  boolean
  onSelect: (item: AmendablePoSummary) => void
  onClose:  () => void
}

export default function PoAmendablePickerModal({ open, items, loading, onSelect, onClose }: Props) {
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((r) =>
      formatPoNo(r.poNo).toLowerCase().includes(q) ||
      r.supplierName.toLowerCase().includes(q) ||
      r.poGroup.toLowerCase().includes(q))
  }, [items, search])

  const columns: TableColumnsType<AmendablePoSummary> = [
    {
      title:     'PO No.',
      dataIndex: 'poNo',
      width:     110,
      render:    (v: number) => (
        <strong style={{ color: '#185FA5', fontFamily: 'monospace' }}>{formatPoNo(v)}</strong>
      ),
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
    {
      title:     'Type',
      dataIndex: 'poGroup',
      width:     70,
      render:    (v: string) => v || '—',
    },
    {
      title:     'Order Value',
      dataIndex: 'orderValue',
      width:     120,
      align:     'right',
      render:    (v: number) => (
        <span style={{ fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums' }}>
          {(v ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </span>
      ),
    },
    {
      title:     'Lines',
      dataIndex: 'totalLines',
      width:     60,
      align:     'right',
    },
  ]

  return (
    <Modal
      title="Find Purchase Order — Open for Amendment"
      open={open}
      onCancel={onClose}
      footer={null}
      width="min(95vw, 900px)"
      styles={{ body: { padding: '12px 16px' } }}
      destroyOnClose
    >
      <Input
        prefix={<SearchOutlined style={{ color: '#888' }} />}
        placeholder="Search by PO number, supplier or order type…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        onClear={() => setSearch('')}
        allowClear
        style={{ marginBottom: 8 }}
      />

      <div style={{ marginBottom: 8, fontSize: 12, color: '#666' }}>
        {loading ? 'Loading…' : `Showing ${filtered.length} record${filtered.length !== 1 ? 's' : ''}`}
      </div>

      <div style={{ maxHeight: 380, overflowY: 'auto' }}>
        <ConfigProvider theme={modalTableTheme}>
          <Table<AmendablePoSummary>
            className="erp-modal-anttable"
            dataSource={filtered}
            columns={columns}
            rowKey={(r) => `${r.poNo}-${r.poDate}-${r.poGroup}`}
            loading={loading}
            size="small"
            pagination={false}
            locale={{
              emptyText: search
                ? `No amendable POs match "${search}"`
                : 'No purchase orders are open for amendment.',
            }}
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
