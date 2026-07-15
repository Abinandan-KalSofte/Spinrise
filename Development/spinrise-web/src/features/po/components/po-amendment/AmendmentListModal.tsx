import { useMemo, useState } from 'react'
import { Modal, Table, Input, ConfigProvider, type TableColumnsType } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import type { AmendmentSummary } from '../../types'
import { formatPoNo } from '../../types'
import { modalTableTheme } from '@/shared/styles/erpTable'

// ── Find Amendment (FN-PO-Amendment v1.2 §1 Find — view-only) ───────────────
// Mirrors PoOpenListModal/PoAmendablePickerModal: ksp_PO_GetAmendmentList has no
// server-side pagination (unlike ksp_PO_GetPOList/ksp_PR_GetList, which support
// page/pageSize → OFFSET/FETCH) — confirmed end-to-end (controller → service →
// repo → SP all pass just DivCode/YFDate/YLDate). So this loads the FY's full
// amendment list once (fetched by the hook) and filters client-side, same as the
// other single-shot PO pickers — no infinite-scroll UI is built on top of an
// endpoint that can't back it.
//
// AMDORDNO/AMDORDDT/PORDNO/SLCODE/ORDVAL are the only columns
// ksp_PO_GetAmendmentList / AmendmentSummaryDto return. Amendment Reason, Status,
// Created By and Created On are NOT present on this DTO — they are not rendered
// here rather than shown as fabricated placeholders.

interface Props {
  open:     boolean
  items:    AmendmentSummary[]
  loading:  boolean
  onSelect: (item: AmendmentSummary) => void
  onClose:  () => void
}

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export default function AmendmentListModal({ open, items, loading, onSelect, onClose }: Props) {
  const [search,    setSearch]    = useState('')

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    let rows = items
    if (q) {
      rows = rows.filter((r) =>
        formatPoNo(r.poNo).toLowerCase().includes(q) ||
        String(r.amdNo).includes(q) ||
        r.supplierName.toLowerCase().includes(q))
    }
    return rows
  }, [items, search])

  const columns: TableColumnsType<AmendmentSummary> = [
    {
      title:     'Amendment No.',
      dataIndex: 'amdNo',
      width:     120,
      render:    (v: number) => <strong style={{ color: '#185FA5', fontFamily: 'monospace' }}>{v || '—'}</strong>,
    },
    {
      title:     'Amendment Date',
      dataIndex: 'amdDate',
      width:     130,
      render:    (v: string) => (v ? dayjs(v).format('DD-MMM-YYYY') : '—'),
    },
    {
      title:     'PO No.',
      dataIndex: 'poNo',
      width:     110,
      render:    (v: number) => <span style={{ fontFamily: 'monospace' }}>{formatPoNo(v)}</span>,
    },
    {
      title:     'Supplier',
      dataIndex: 'supplierName',
      ellipsis:  true,
      render:    (v: string) => v || '—',
    },
    {
      title:     'Order Value',
      dataIndex: 'orderValue',
      width:     130,
      align:     'right',
      render:    (v: number) => (
        <span style={{ fontFamily: 'monospace', fontVariantNumeric: 'tabular-nums' }}>{fmt2(v ?? 0)}</span>
      ),
    },
  ]

  return (
    <Modal
      title="Find Amendment — Saved Purchase Order Amendments"
      open={open}
      onCancel={onClose}
      footer={null}
      width="min(95vw, 940px)"
      styles={{ body: { padding: '12px 16px' } }}
      destroyOnClose
    >
      <div style={{ display: 'flex', gap: 8, marginBottom: 8, flexWrap: 'wrap' }}>
        <Input
          prefix={<SearchOutlined style={{ color: '#888' }} />}
          placeholder="Search by PO number, amendment number or supplier…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onClear={() => setSearch('')}
          allowClear
          style={{ flex: 1, minWidth: 240 }}
        />
      </div>

      <div style={{ marginBottom: 8, fontSize: 12, color: '#666' }}>
        {loading ? 'Loading…' : `Showing ${filtered.length} record${filtered.length !== 1 ? 's' : ''}`}
        <span style={{ marginLeft: 10, color: '#aaa' }}>
          Amendment Reason, Status, Created By and Created On are not returned by the backend yet.
        </span>
      </div>

      <div style={{ maxHeight: 380, overflowY: 'auto' }}>
        <ConfigProvider theme={modalTableTheme}>
          <Table<AmendmentSummary>
            className="erp-modal-anttable"
            dataSource={filtered}
            columns={columns}
            rowKey={(r) => `${r.poNo}-${r.poDate}-${r.amdNo}`}
            loading={loading}
            size="small"
            pagination={false}
            locale={{
              emptyText: search 
                ? 'No amendments match the current filters.'
                : 'No saved amendments found for this financial year.',
            }}
            onRow={(record) => ({
              onClick: () => onSelect(record),
              style:   { cursor: 'pointer' },
            })}
          />
        </ConfigProvider>
      </div>
    </Modal>
  )
}
