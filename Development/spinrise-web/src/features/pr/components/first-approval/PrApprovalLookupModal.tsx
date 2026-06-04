import { useState } from 'react'
import { Modal, Table, Input, Button, Typography } from 'antd'
import type { PrApprovalSummary } from '../../types/prFirstApprovalTypes'
import dayjs from 'dayjs'

const { Search } = Input

interface Props {
  open:      boolean
  title:     string
  subtitle:  string
  list:      PrApprovalSummary[]
  loading:   boolean
  onSelect:  (pr: PrApprovalSummary) => void
  onClose:   () => void
}

export default function PrApprovalLookupModal({
  open, title, subtitle, list, loading, onSelect, onClose,
}: Props) {
  const [search,   setSearch]   = useState('')
  const [selected, setSelected] = useState<PrApprovalSummary | null>(null)

  const filtered = search
    ? list.filter(
        (p) =>
          String(p.prNo).includes(search) ||
          p.depName.toLowerCase().includes(search.toLowerCase()) ||
          (p.refNo ?? '').toLowerCase().includes(search.toLowerCase()) ||
          p.depCode.toLowerCase().includes(search.toLowerCase())
      )
    : list

  return (
    <Modal
      open={open}
      title={
        <div>
          <div style={{ fontWeight: 700, fontSize: 14 }}>{title}</div>
          <div style={{ fontSize: 11, color: '#888', fontWeight: 400 }}>{subtitle}</div>
        </div>
      }
      onCancel={onClose}
      width={700}
      footer={
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, color: '#888' }}>
            {filtered.length} record{filtered.length !== 1 ? 's' : ''} found
          </span>
          <div style={{ display: 'flex', gap: 8 }}>
            <Button onClick={onClose}>Close</Button>
            <Button type="primary" disabled={!selected} onClick={() => selected && onSelect(selected)}>
              Select
            </Button>
          </div>
        </div>
      }
      destroyOnClose
      afterClose={() => { setSearch(''); setSelected(null) }}
    >
      <Search
        placeholder="Search PR No., Department, Ref No.…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 12 }}
        allowClear
      />
      <Table
        size="small"
        loading={loading}
        dataSource={filtered}
        rowKey={(r) => `${r.prNo}-${r.prDate}`}
        pagination={false}
        scroll={{ y: 360 }}
        rowSelection={{
          type:            'radio',
          selectedRowKeys: selected ? [`${selected.prNo}-${selected.prDate}`] : [],
          onChange:        (_, rows) => setSelected(rows[0] ?? null),
        }}
        onRow={(record) => ({
          onClick:       () => setSelected(record),
          onDoubleClick: () => { setSelected(record); onSelect(record) },
          style:         { cursor: 'pointer' },
        })}
        columns={[
          { title: 'PR No.',          dataIndex: 'prNo',    key: 'prNo',    width: 80,  render: (v) => <Typography.Text strong code>{v}</Typography.Text> },
          { title: 'PR Date',         dataIndex: 'prDate',  key: 'prDate',  width: 100, render: (v) => dayjs(v).format('DD/MM/YYYY') },
          { title: 'Department Id',   dataIndex: 'depCode', key: 'depCode', width: 110 },
          { title: 'Department Name', dataIndex: 'depName', key: 'depName' },
          { title: 'Reference No.',   dataIndex: 'refNo',   key: 'refNo',   width: 130, render: (v) => v ?? '—' },
          { title: 'Section',         dataIndex: 'section', key: 'section', width: 100, render: (v) => v ?? '—' },
        ]}
        locale={{ emptyText: 'No records found' }}
      />
    </Modal>
  )
}
