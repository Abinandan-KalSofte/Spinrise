import { useCallback, useEffect, useRef, useState } from 'react'
import { Button, Input, Modal, Spin, Tag, Typography, type InputRef } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import * as prApi from '../../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { ItemLookup } from '../../types'

const PAGE_SIZE = 50

interface ItemPickerModalProps {
  open:             boolean
  depCode:          string
  initialSearch?:   string
  onSelectMultiple: (items: ItemLookup[]) => void
  onCancel:         () => void
}

const TH: React.CSSProperties = {
  padding: '8px 10px', fontSize: 11, fontWeight: 700, color: '#64748b',
  background: '#f8fafc', borderBottom: '2px solid #e2e8f0',
  textTransform: 'uppercase', letterSpacing: '0.05em',
  whiteSpace: 'nowrap', position: 'sticky', top: 0, zIndex: 1,
}

const TD: React.CSSProperties = {
  padding: '7px 10px', borderBottom: '1px solid #f1f5f9', verticalAlign: 'middle',
}

export function ItemPickerModal({
  open, depCode, initialSearch = '', onSelectMultiple, onCancel,
}: ItemPickerModalProps) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')

  const [items,         setItems]         = useState<ItemLookup[]>([])
  const [page,          setPage]          = useState(1)
  const [hasMore,       setHasMore]       = useState(true)
  const [loading,       setLoading]       = useState(false)
  const [loadingMore,   setLoadingMore]   = useState(false)
  const [search,        setSearch]        = useState('')
  const [selectedItems, setSelectedItems] = useState<Map<string, ItemLookup>>(new Map())

  const searchInputRef = useRef<InputRef>(null)
  const searchTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const sentinelRef    = useRef<HTMLTableRowElement>(null)

  const loadPage = useCallback(async (pageNum: number, searchTerm: string, replace: boolean) => {
    if (!divCode) return
    if (pageNum === 1) setLoading(true)
    else               setLoadingMore(true)
    try {
      const result = await prApi.getItems(divCode, searchTerm.trim() || undefined, undefined, pageNum, PAGE_SIZE)
      setPage(pageNum)
      setHasMore(result.length === PAGE_SIZE)
      setItems((prev) => replace ? result : [...prev, ...result])
    } catch { /* swallow */ }
    finally { setLoading(false); setLoadingMore(false) }
  }, [divCode])

  useEffect(() => {
    if (!open) return
    setItems([])
    setPage(1)
    setHasMore(true)
    setSelectedItems(new Map())
    setSearch(initialSearch)
    void loadPage(1, initialSearch, true)
    setTimeout(() => searchInputRef.current?.focus(), 120)
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSearchChange = (q: string) => {
    setSearch(q)
    clearTimeout(searchTimerRef.current)
    searchTimerRef.current = setTimeout(() => {
      setItems([])
      setHasMore(true)
      void loadPage(1, q, true)
    }, 300)
  }

  useEffect(() => {
    const sentinel = sentinelRef.current
    if (!sentinel) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && hasMore && !loading && !loadingMore) {
          void loadPage(page + 1, search, false)
        }
      },
      { threshold: 0.1 },
    )
    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [hasMore, loading, loadingMore, page, search, loadPage])

  const handleRowClick = useCallback((item: ItemLookup) => {
    setSelectedItems((prev) => {
      const next = new Map(prev)
      if (next.has(item.itemCode)) next.delete(item.itemCode)
      else next.set(item.itemCode, item)
      return next
    })
  }, [])

  const handleConfirm = useCallback(() => {
    if (selectedItems.size === 0) return
    onSelectMultiple(Array.from(selectedItems.values()))
    setSelectedItems(new Map())
  }, [selectedItems, onSelectMultiple])

  const handleRowDblClick = useCallback((item: ItemLookup) => {
    onSelectMultiple([item])
    setSelectedItems(new Map())
  }, [onSelectMultiple])

  const selCount  = selectedItems.size
  const selValues = selCount > 0 ? Array.from(selectedItems.values()) : []

  return (
    <Modal
      open={open}
      onCancel={onCancel}
      footer={null}
      width={860}
      destroyOnClose
      styles={{ body: { padding: 0 } }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: 'linear-gradient(135deg, #eff6ff, #dbeafe)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
            boxShadow: '0 2px 8px rgba(22,119,255,0.18)',
          }}>
            <SearchOutlined style={{ color: '#1d4ed8', fontSize: 18 }} />
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b', lineHeight: 1.3 }}>
              Item Selection — Purchase Requisition
            </div>
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
              Dept: <strong style={{ color: '#1677ff' }}>{depCode || 'All'}</strong>
              {' · '}Click to select · Double-click to add instantly
            </div>
          </div>
        </div>
      }
    >
      {/* ── Search bar ── */}
      <div style={{ padding: '14px 20px 10px', borderBottom: '1px solid #f0f0f0' }}>
        <Input
          ref={searchInputRef}
          prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
          placeholder="Search by item code or name…"
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          allowClear
          style={{ borderRadius: 8, background: '#f8fafc', fontSize: 13 }}
        />
        <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
          <Typography.Text type="secondary" style={{ fontSize: 11 }}>
            {loading ? 'Loading…' : `${items.length.toLocaleString()} items loaded`}
          </Typography.Text>
        </div>
      </div>

      {/* ── Item table ── */}
      <div style={{ maxHeight: 380, overflowY: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ ...TH, width: 36, textAlign: 'center' }}>Img</th>
              <th style={{ ...TH, width: 90 }}>Item Code</th>
              <th style={{ ...TH, minWidth: 180 }}>Description</th>
              <th style={{ ...TH, width: 60, textAlign: 'center' }}>UOM</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>Min Level</th>
              <th style={{ ...TH, width: 80, textAlign: 'right' }}>Max Level</th>
              <th style={{ ...TH, width: 110, textAlign: 'right' }}>Last PO Rate</th>
              <th style={{ ...TH, width: 110 }}>Last PO Date</th>
            </tr>
          </thead>
          <tbody>
            {loading && items.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  Loading items…
                </td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8', fontSize: 13 }}>
                  {search ? `No items match "${search}"` : 'No active items found.'}
                </td>
              </tr>
            ) : (
              <>
                {items.map((item, idx) => {
                  const isSel = selectedItems.has(item.itemCode)
                  return (
                    <tr
                      key={item.itemCode}
                      style={{
                        background:    isSel ? '#eff6ff' : idx % 2 === 0 ? '#ffffff' : '#fafafa',
                        cursor:        'pointer',
                        outline:       isSel ? '2px solid #1677ff' : 'none',
                        outlineOffset: -1,
                        transition:    'background 0.1s',
                      }}
                      onClick={() => handleRowClick(item)}
                      onDoubleClick={() => handleRowDblClick(item)}
                    >
                      <td style={{ ...TD, width: 36, textAlign: 'center', padding: '4px' }}>
                        {item.itemImage ? (
                          <img
                            src={`data:image/*;base64,${item.itemImage}`}
                            alt=""
                            style={{ width: 28, height: 28, objectFit: 'cover', borderRadius: 4, border: '1px solid #e2e8f0' }}
                          />
                        ) : (
                          <div style={{ width: 28, height: 28, borderRadius: 4, background: '#f1f5f9', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
                            <span style={{ fontSize: 10, color: '#cbd5e1' }}>—</span>
                          </div>
                        )}
                      </td>
                      <td style={TD}>
                        <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, color: '#1e293b' }}>
                          {item.itemCode}
                        </span>
                      </td>
                      <td style={{ ...TD, minWidth: 180 }}>
                        <div style={{ fontWeight: 500, fontSize: 13, color: '#1e293b', lineHeight: 1.4 }}>
                          {item.itemName}
                        </div>
                      </td>
                      <td style={{ ...TD, textAlign: 'center' }}>
                        {item.uom
                          ? <Tag style={{ fontSize: 11, margin: 0, padding: '0 5px' }}>{item.uom}</Tag>
                          : <span style={{ color: '#d1d5db' }}>—</span>}
                      </td>
                      <td style={{ ...TD, textAlign: 'right', fontVariantNumeric: 'tabular-nums', fontSize: 12, color: '#64748b' }}>
                        {item.minLevel > 0 ? item.minLevel.toFixed(3) : <span style={{ color: '#d1d5db' }}>—</span>}
                      </td>
                      <td style={{ ...TD, textAlign: 'right', fontVariantNumeric: 'tabular-nums', fontSize: 12, color: '#64748b' }}>
                        {item.maxLevel > 0 ? item.maxLevel.toFixed(3) : <span style={{ color: '#d1d5db' }}>—</span>}
                      </td>
                      <td style={{ ...TD, textAlign: 'right', fontVariantNumeric: 'tabular-nums', fontSize: 12 }}>
                        {item.lpoRate != null
                          ? <span style={{ fontWeight: 600, color: '#b45309' }}>
                              ₹ {Number(item.lpoRate).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 4 })}
                            </span>
                          : <span style={{ color: '#d1d5db' }}>—</span>}
                      </td>
                      <td style={{ ...TD, fontSize: 12, color: '#475569' }}>
                        {item.lpoDate ? dayjs(item.lpoDate).format('DD-MMM-YYYY') : <span style={{ color: '#d1d5db' }}>—</span>}
                      </td>
                    </tr>
                  )
                })}
                <tr ref={sentinelRef}>
                  <td colSpan={8} style={{ padding: '8px', textAlign: 'center' }}>
                    {loadingMore && <Spin size="small" />}
                    {!loadingMore && !hasMore && items.length > 0 && (
                      <span style={{ fontSize: 11, color: '#cbd5e1' }}>All items loaded</span>
                    )}
                  </td>
                </tr>
              </>
            )}
          </tbody>
        </table>
      </div>

      {/* ── Footer ── */}
      <div style={{
        padding: '12px 20px', borderTop: '2px solid #f0f0f0',
        display: 'flex', alignItems: 'center', gap: 12,
        background: '#fafafa', borderRadius: '0 0 8px 8px',
      }}>
        <div style={{ flex: 1, overflow: 'hidden' }}>
          {selCount === 0 ? (
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              Click a row to select · Double-click to add instantly
            </Typography.Text>
          ) : selCount === 1 ? (
            <span style={{ fontSize: 12, color: '#1677ff', fontWeight: 600 }}>
              <span style={{ fontFamily: 'monospace' }}>{selValues[0].itemCode}</span>
              {' — '}
              <span style={{ color: '#475569', fontWeight: 400 }}>{selValues[0].itemName}</span>
            </span>
          ) : (
            <span style={{ fontSize: 12, color: '#1677ff', fontWeight: 600 }}>
              {selCount} items selected
              <span style={{ color: '#94a3b8', fontWeight: 400, marginLeft: 6 }}>
                · {selValues.map((i) => i.itemCode).join(', ')}
              </span>
            </span>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
          <Button onClick={onCancel}>Cancel</Button>
          <Button
            type="primary"
            disabled={selCount === 0}
            onClick={handleConfirm}
            style={selCount > 0 ? {
              background: 'linear-gradient(135deg, #1677ff, #0950a8)',
              border: 'none', fontWeight: 600, paddingInline: 24,
              boxShadow: '0 3px 10px rgba(22,119,255,0.4)',
            } : { paddingInline: 24 }}
          >
            {selCount > 1 ? `Add ${selCount} Items →` : selCount === 1 ? 'Add Item →' : 'Add Item'}
          </Button>
        </div>
      </div>
    </Modal>
  )
}
