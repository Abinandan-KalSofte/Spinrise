import { useState, useEffect, useCallback } from 'react'
import { Modal, Table, Input, Tag } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import type { PrSummary, ScreenMode } from '../types'
import { getList } from '../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import PrStatusBadge from './PrStatusBadge'

interface Props {
  open:     boolean
  mode:     Extract<ScreenMode, 'VIEW' | 'EDIT' | 'DELETE'>
  fDate:    string
  lDate:    string
  onSelect: (item: PrSummary) => void
  onClose:  () => void
}

export default function PrListModal({ open, mode, fDate, lDate, onSelect, onClose }: Props) {
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const [items,   setItems]   = useState<PrSummary[]>([])
  const [loading, setLoading] = useState(false)
  const [search,  setSearch]  = useState('')

  const apiMode = mode === 'VIEW' ? 'FIND' : 'MODIFY'

  const fetch = useCallback(async () => {
    if (!divCode) return
    setLoading(true)
    try {
      const data = await getList(divCode, fDate, lDate, apiMode, { pageSize: 100 })
      setItems(data)
    } catch {
      // handled by interceptor
    } finally {
      setLoading(false)
    }
  }, [divCode, fDate, lDate, apiMode])

  useEffect(() => {
    if (open) { setSearch(''); void fetch() }
  }, [open, fetch])

  const filtered = search
    ? items.filter(
        (i) =>
          String(i.prNo).includes(search) ||
          i.depName.toLowerCase().includes(search.toLowerCase()) ||
          i.reqEmpName.toLowerCase().includes(search.toLowerCase())
      )
    : items

  const title = mode === 'VIEW' ? 'Find Purchase Requisition'
              : mode === 'EDIT' ? 'Select PR to Modify'
              : 'Select PR to Delete'

  const columns = [
    {
      title:     'PR No.',
      dataIndex: 'prNo',
      width:     80,
      render:    (v: number) => <strong style={{ color: '#185FA5' }}>{v}</strong>,
    },
    {
      title:     'PR Date',
      dataIndex: 'prDate',
      width:     100,
      render:    (v: string) => dayjs(v).format('DD/MM/YYYY'),
    },
    {
      title:     'Department',
      dataIndex: 'depName',
      ellipsis:  true,
    },
    {
      title:     'Requester',
      dataIndex: 'reqEmpName',
      ellipsis:  true,
    },
    {
      title:     'Type',
      dataIndex: 'iDesc',
      width:     80,
      render:    (v: string) => v ? <Tag style={{ fontSize: 11 }}>{v}</Tag> : '—',
    },
    {
      title:     'Lines',
      dataIndex: 'totalLines',
      width:     60,
      align:     'center' as const,
    },
    {
      title:     'Status',
      dataIndex: 'prStatus',
      width:     160,
      render:    (v: string) => <PrStatusBadge status={v} />,
    },
  ]

  return (
    <Modal
      title={title}
      open={open}
      onCancel={onClose}
      footer={null}
      width={900}
      styles={{ body: { padding: '12px 16px' } }}
    >
      <Input
        prefix={<SearchOutlined style={{ color: '#888' }} />}
        placeholder="Filter by PR number, department, requester…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        allowClear
        style={{ marginBottom: 12 }}
      />

      <Table<PrSummary>
        dataSource={filtered}
        columns={columns}
        rowKey={(r) => `${r.prNo}-${r.prDate}`}
        loading={loading}
        size="small"
        scroll={{ y: 360 }}
        pagination={false}
        onRow={(record) => ({
          onClick: () => { onSelect(record); onClose() },
          style:   { cursor: 'pointer' },
        })}
      />
    </Modal>
  )
}
