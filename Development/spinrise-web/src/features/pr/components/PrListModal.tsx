import { useState, useEffect, useCallback, useRef } from 'react'
import { Modal, Table, Input, Tag, Spin, type TableColumnsType } from 'antd'
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

const PAGE_SIZE = 50

export default function PrListModal({ open, mode, fDate, lDate, onSelect, onClose }: Props) {
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const [items,       setItems]       = useState<PrSummary[]>([])
  const [loading,     setLoading]     = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore,     setHasMore]     = useState(true)
  const [search,      setSearch]      = useState('')
  const [page,        setPage]        = useState(1)

  const searchTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const currentSearch = useRef('')

  const apiMode = mode === 'VIEW' ? 'FIND' : 'MODIFY'

  const loadPage = useCallback(async (searchTerm: string, pageNum: number, append: boolean) => {
    if (!divCode) return
    if (pageNum === 1) setLoading(true)
    else               setLoadingMore(true)
    try {
      const data = await getList(divCode, fDate, lDate, apiMode, {
        search:   searchTerm || undefined,
        page:     pageNum,
        pageSize: PAGE_SIZE,
      })
      setItems((prev) => append ? [...prev, ...data] : data)
      setPage(pageNum)
      setHasMore(data.length === PAGE_SIZE)
    } catch {
      // handled by interceptor
    } finally {
      setLoading(false)
      setLoadingMore(false)
    }
  }, [divCode, fDate, lDate, apiMode])

  useEffect(() => {
    if (open) {
      setSearch('')
      currentSearch.current = ''
      setItems([])
      setPage(1)
      setHasMore(true)
      void loadPage('', 1, false)
    }
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSearch = (value: string) => {
    setSearch(value)
    clearTimeout(searchTimer.current)
    searchTimer.current = setTimeout(() => {
      currentSearch.current = value
      setItems([])
      setPage(1)
      setHasMore(true)
      void loadPage(value, 1, false)
    }, 350)
  }

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    if (loadingMore || !hasMore) return
    const el = e.currentTarget
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
      void loadPage(currentSearch.current, page + 1, true)
    }
  }

  const title = mode === 'VIEW' ? 'Find Purchase Requisition'
              : mode === 'EDIT' ? 'Select PR to Modify'
              : 'Select PR to Delete'

  const showStatus = mode === 'VIEW'

  const columns: TableColumnsType<PrSummary> = [
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
  ]

  if (showStatus) {
    columns.push({
      title:     'Status',
      dataIndex: 'prStatus',
      width:     160,
      render:    (v: string) => <PrStatusBadge status={v} />,
    })
  }

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
        placeholder="Search by PR number, department or requester…"
        value={search}
        onChange={(e) => handleSearch(e.target.value)}
        onClear={() => handleSearch('')}
        allowClear
        style={{ marginBottom: 8 }}
      />

      <div style={{ marginBottom: 8, fontSize: 12, color: '#666' }}>
        {loading ? 'Loading…' : `Showing ${items.length} record${items.length !== 1 ? 's' : ''}${hasMore ? ' — scroll for more' : ''}`}
      </div>

      <div
        style={{ maxHeight: 360, overflowY: 'auto' }}
        onScroll={handleScroll}
      >
        <Table<PrSummary>
          dataSource={items}
          columns={columns}
          rowKey={(r) => `${r.prNo}-${r.prDate}`}
          loading={loading}
          size="small"
          pagination={false}
          onRow={(record) => ({
            onClick: () => { onSelect(record); onClose() },
            style:   { cursor: 'pointer' },
          })}
        />
        {loadingMore && (
          <div style={{ textAlign: 'center', padding: '12px 0', color: '#888', fontSize: 12 }}>
            <Spin size="small" style={{ marginRight: 8 }} />
            Loading more…
          </div>
        )}
        {!loading && !loadingMore && !hasMore && items.length > 0 && (
          <div style={{ textAlign: 'center', padding: '10px 0', color: '#bbb', fontSize: 12 }}>
            All records loaded
          </div>
        )}
      </div>
    </Modal>
  )
}
