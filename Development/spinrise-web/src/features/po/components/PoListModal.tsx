import { useState, useEffect, useCallback, useRef } from 'react'
import { Modal, Table, Input, Spin, type TableColumnsType } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import type { PoSummary } from '../types'
import { formatPoNo, PO_APPROVAL_BADGE } from '../types'
import { getList } from '../api/poTransferApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'

// ── Find Purchase Orders (mirrors PrListModal) ───────────────────────────────
// Lists existing POs for the active FY with debounced server search + infinite
// scroll. Selecting a row loads that PO into the form (VIEW mode).

interface Props {
  open:     boolean
  fDate:    string
  lDate:    string
  onSelect: (item: PoSummary) => void
  onClose:  () => void
}

const PAGE_SIZE = 50

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

function StatusBadge({ status }: { status: string }) {
  const badge = PO_APPROVAL_BADGE[status] ?? { color: '#4A4A4A', bg: '#F5F5F3' }
  return (
    <span style={{
      fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 20,
      background: badge.bg, color: badge.color,
    }}>
      {status || '—'}
    </span>
  )
}

export default function PoListModal({ open, fDate, lDate, onSelect, onClose }: Props) {
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const [items,       setItems]       = useState<PoSummary[]>([])
  const [loading,     setLoading]     = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore,     setHasMore]     = useState(true)
  const [search,      setSearch]      = useState('')
  const [page,        setPage]        = useState(1)

  const searchTimer   = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const currentSearch = useRef('')

  const loadPage = useCallback(async (searchTerm: string, pageNum: number, append: boolean) => {
    if (!divCode) return
    if (pageNum === 1) setLoading(true)
    else               setLoadingMore(true)
    try {
      const data = await getList(divCode, fDate, lDate, {
        search:   searchTerm || undefined,
        page:     pageNum,
        pageSize: PAGE_SIZE,
      })
      setItems((prev) => append ? [...prev, ...data] : data)
      setPage(pageNum)
      setHasMore(data.length === PAGE_SIZE)
    } catch {
      // surfaced by the axios interceptor
    } finally {
      setLoading(false)
      setLoadingMore(false)
    }
  }, [divCode, fDate, lDate])

  useEffect(() => {
    if (open) {
      setSearch('')
      currentSearch.current = ''
      setItems([])
      setPage(1)
      setHasMore(true)
      void loadPage('', 1, false)
    }
    return () => clearTimeout(searchTimer.current)
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

  const columns: TableColumnsType<PoSummary> = [
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
      render:    (v: string, r) => v || r.supplier || '—',
    },
    {
      title:     'PO Date',
      dataIndex: 'poDate',
      width:     110,
      render:    (v: string) => (v ? dayjs(v).format('DD-MMM-YYYY') : '—'),
    },
    {
      title:     'Status',
      dataIndex: 'approvalStatus',
      width:     150,
      render:    (v: string) => <StatusBadge status={v} />,
    },
    {
      title:     'Total Value',
      dataIndex: 'orderValue',
      width:     130,
      align:     'right' as const,
      render:    (v: number) => <span style={{ fontFamily: 'monospace' }}>{fmt2(v ?? 0)}</span>,
    },
  ]

  return (
    <Modal
      title="Find Purchase Order"
      open={open}
      onCancel={onClose}
      footer={null}
      width={900}
      styles={{ body: { padding: '12px 16px' } }}
      destroyOnClose
    >
      <Input
        prefix={<SearchOutlined style={{ color: '#888' }} />}
        placeholder="Search by PO number or supplier…"
        value={search}
        onChange={(e) => handleSearch(e.target.value)}
        onClear={() => handleSearch('')}
        allowClear
        style={{ marginBottom: 8 }}
      />

      <div style={{ marginBottom: 8, fontSize: 12, color: '#666' }}>
        {loading ? 'Loading…' : `Showing ${items.length} record${items.length !== 1 ? 's' : ''}${hasMore ? ' — scroll for more' : ''}`}
      </div>

      <div style={{ maxHeight: 360, overflowY: 'auto' }} onScroll={handleScroll}>
        <Table<PoSummary>
          dataSource={items}
          columns={columns}
          rowKey={(r) => `${r.poNo}-${r.poDate}`}
          loading={loading}
          size="small"
          pagination={false}
          locale={{ emptyText: search ? `No POs match "${search}"` : 'No purchase orders found.' }}
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
