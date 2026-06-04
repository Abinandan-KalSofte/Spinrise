import { useState, useEffect, useCallback } from 'react'
import { Modal, Input, Table, Spin, Tag } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import type { ItemLookup } from '../types'
import { getItems } from '../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { usePrStore } from '../store/usePrStore'

interface Props {
  open:       boolean
  onSelect:   (item: ItemLookup) => void
  onClose:    () => void
}

export default function ItemSelectionModal({ open, onSelect, onClose }: Props) {
  const user       = useAuthStore((s) => s.user)
  const parameters = usePrStore((s) => s.parameters)

  const [search,  setSearch]  = useState('')
  const [items,   setItems]   = useState<ItemLookup[]>([])
  const [loading, setLoading] = useState(false)
  const [page,    setPage]    = useState(1)

  const divCode = user?.divCode ?? ''

  const fetchItems = useCallback(async (q: string, pg: number) => {
    if (!divCode) return
    setLoading(true)
    try {
      const grpCode = parameters?.inditemGrp === 'Y' ? undefined : undefined
      const data = await getItems(divCode, q || undefined, grpCode, pg, 50)
      setItems(data)
    } catch {
      // handled by interceptor
    } finally {
      setLoading(false)
    }
  }, [divCode, parameters])

  useEffect(() => {
    if (open) {
      setSearch('')
      setPage(1)
      void fetchItems('', 1)
    }
  }, [open, fetchItems])

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => void fetchItems(search, 1), 300)
    return () => clearTimeout(timer)
  }, [search, fetchItems])

  const columns = [
    {
      title:     'Item Id',
      dataIndex: 'itemCode',
      width:     110,
      render:    (v: string) => <code style={{ fontSize: 12, color: '#185FA5' }}>{v}</code>,
    },
    {
      title:     'Item Name',
      dataIndex: 'itemName',
      ellipsis:  true,
    },
    {
      title:     'UOM',
      dataIndex: 'uom',
      width:     70,
      align:     'center' as const,
    },
    {
      title:     'Min Qty',
      dataIndex: 'minLevel',
      width:     80,
      align:     'right' as const,
      render:    (v: number) => v > 0 ? v.toFixed(3) : '—',
    },
    {
      title:     'Last PO Rate',
      dataIndex: 'lpoRate',
      width:     100,
      align:     'right' as const,
      render:    (v: number | null) =>
        v != null
          ? <span style={{ fontFamily: 'monospace' }}>₹ {v.toFixed(4)}</span>
          : <Tag color="default" style={{ fontSize: 10 }}>No PO</Tag>,
    },
  ]

  return (
    <Modal
      title="Item Selection"
      open={open}
      onCancel={onClose}
      footer={null}
      width={820}
      styles={{ body: { padding: '12px 16px' } }}
    >
      <Input
        prefix={<SearchOutlined style={{ color: '#888' }} />}
        placeholder="Search by Id or name…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        allowClear
        style={{ marginBottom: 12 }}
        autoFocus
      />

      <Spin spinning={loading}>
        <Table<ItemLookup>
          dataSource={items}
          columns={columns}
          rowKey="itemCode"
          size="small"
          scroll={{ y: 360 }}
          pagination={{
            pageSize: 50,
            current:  page,
            onChange: (pg) => { setPage(pg); void fetchItems(search, pg) },
            showSizeChanger: false,
            showTotal: (total) => `${total} items`,
          }}
          onRow={(record) => ({
            onClick:       () => { onSelect(record); onClose() },
            onDoubleClick: () => { onSelect(record); onClose() },
            style:         { cursor: 'pointer' },
          })}
        />
      </Spin>
    </Modal>
  )
}
