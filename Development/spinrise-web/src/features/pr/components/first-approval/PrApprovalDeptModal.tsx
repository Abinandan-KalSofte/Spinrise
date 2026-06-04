import { useState } from 'react'
import { Modal, Table, Input, Button, Typography } from 'antd'
import type { ApprovalDept } from '../../types/prFirstApprovalTypes'

const { Search } = Input

interface Props {
  open:    boolean
  depts:   ApprovalDept[]
  loading: boolean
  onNext:  (dept: ApprovalDept) => void
  onClose: () => void
}

export default function PrApprovalDeptModal({ open, depts, loading, onNext, onClose }: Props) {
  const [search, setSearch]     = useState('')
  const [selected, setSelected] = useState<ApprovalDept | null>(null)

  const filtered = search
    ? depts.filter(
        (d) =>
          d.depCode.toLowerCase().includes(search.toLowerCase()) ||
          d.depName.toLowerCase().includes(search.toLowerCase())
      )
    : depts

  const handleSelect = () => {
    if (selected) onNext(selected)
  }

  return (
    <Modal
      open={open}
      title={
        <div>
          <div style={{ fontWeight: 700, fontSize: 14 }}>Select Department</div>
          <div style={{ fontSize: 11, color: '#888', fontWeight: 400 }}>
            Step 1 of 2 — Choose a department to filter pending PRs
          </div>
        </div>
      }
      onCancel={onClose}
      width={520}
      footer={
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
          <Button onClick={onClose}>Close</Button>
          <Button type="primary" disabled={!selected} onClick={handleSelect}>
            Next ›
          </Button>
        </div>
      }
      destroyOnClose
      afterClose={() => { setSearch(''); setSelected(null) }}
    >
      <Search
        placeholder="Search department Id or name…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 12 }}
        allowClear
      />
      <Table
        size="small"
        loading={loading}
        dataSource={filtered}
        rowKey="depCode"
        pagination={false}
        scroll={{ y: 300 }}
        rowSelection={{
          type:             'radio',
          selectedRowKeys:  selected ? [selected.depCode] : [],
          onChange:         (_, rows) => setSelected(rows[0] ?? null),
        }}
        onRow={(record) => ({
          onClick:       () => setSelected(record),
          onDoubleClick: () => { setSelected(record); onNext(record) },
          style:         { cursor: 'pointer' },
        })}
        columns={[
          { title: 'Department Id',   dataIndex: 'depCode',      key: 'depCode',      width: 140, render: (v: string) => <Typography.Text code>{v}</Typography.Text> },
          { title: 'Department Name', dataIndex: 'depName',      key: 'depName' },
          {
            title: 'Pending PRs', dataIndex: 'pendingCount', key: 'pendingCount', width: 110, align: 'right' as const,
            render: (v: number) => (
              <span style={{
                fontWeight: 700, fontVariantNumeric: 'tabular-nums',
                color: v > 0 ? '#185FA5' : '#aaa',
              }}>
                {v}
              </span>
            ),
          },
        ]}
        locale={{ emptyText: 'No departments found' }}
      />
      <div style={{ marginTop: 8, fontSize: 11, color: '#888' }}>
        {filtered.length} department{filtered.length !== 1 ? 's' : ''}
      </div>
    </Modal>
  )
}
