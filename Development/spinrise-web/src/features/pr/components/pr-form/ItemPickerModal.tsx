import { useCallback, useEffect, useRef, useState } from 'react'
import { Button, Input, Modal, Spin, Tag, Typography, type InputRef } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import * as prApi from '../../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { ItemLookup } from '../../types'
import { LOOKUP_TH as TH, LOOKUP_TD as TD } from '@/shared/styles/erpTable'

const PAGE_SIZE = 50

interface ItemPickerModalProps {
  open:             boolean
  depCode:          string
  depName?:         string
  initialSearch?:   string
  onSelectMultiple: (items: ItemLookup[]) => void
  onCancel:         () => void
}

const Kbd = ({ children }: { children: React.ReactNode }) => (
  <kbd style={{
    fontSize: 10, padding: '1px 5px', border: '1px solid #d1d5db',
    borderRadius: 3, background: '#f1f5f9', color: '#475569',
    fontFamily: 'monospace', lineHeight: 1.6, display: 'inline-block',
  }}>
    {children}
  </kbd>
)

export function ItemPickerModal({
  open, depCode, depName, initialSearch = '', onSelectMultiple, onCancel,
}: ItemPickerModalProps) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')

  const [items,         setItems]         = useState<ItemLookup[]>([])
  const [page,          setPage]          = useState(1)
  const [hasMore,       setHasMore]       = useState(true)
  const [loading,       setLoading]       = useState(false)
  const [loadingMore,   setLoadingMore]   = useState(false)
  const [search,        setSearch]        = useState('')
  const [selectedItems, setSelectedItems] = useState<Map<string, ItemLookup>>(new Map())
  const [focusedIdx,    setFocusedIdx]    = useState(-1)

  const searchInputRef = useRef<InputRef>(null)
  const searchTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const sentinelRef    = useRef<HTMLTableRowElement>(null)
  const scrollDivRef   = useRef<HTMLDivElement>(null)

  // ── Data loading ──────────────────────────────────────────────────────────

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
    setFocusedIdx(-1)
    void loadPage(1, initialSearch, true)
    setTimeout(() => searchInputRef.current?.focus(), 120)
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

  // Infinite scroll sentinel
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

  // Auto-scroll the focused row into view
  useEffect(() => {
    if (focusedIdx < 0) return
    scrollDivRef.current
      ?.querySelector<HTMLElement>(`tr[data-idx="${focusedIdx}"]`)
      ?.scrollIntoView({ block: 'nearest' })
  }, [focusedIdx])

  // ── Search ────────────────────────────────────────────────────────────────

  const handleSearchChange = (q: string) => {
    setSearch(q)
    setFocusedIdx(-1)
    clearTimeout(searchTimerRef.current)
    searchTimerRef.current = setTimeout(() => {
      setItems([])
      setHasMore(true)
      void loadPage(1, q, true)
    }, 300)
  }

  // ── Row actions ───────────────────────────────────────────────────────────

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

  // ── Keyboard handler (search input stays focused throughout) ──────────────

  const handleSearchKeyDown = useCallback((e: React.KeyboardEvent<HTMLInputElement>) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault()
        if (items.length > 0) setFocusedIdx((p) => Math.min(p + 1, items.length - 1))
        return

      case 'ArrowUp':
        e.preventDefault()
        setFocusedIdx((p) => Math.max(p - 1, -1))
        return

      case ' ':
        if (focusedIdx >= 0) {
          e.preventDefault()
          const item = items[focusedIdx]
          if (item) handleRowClick(item)
        }
        return

      case 'Enter':
        e.preventDefault()
        if (selectedItems.size > 0) {
          handleConfirm()
        } else if (focusedIdx >= 0 && items[focusedIdx]) {
          handleRowDblClick(items[focusedIdx])
        }
        return

      default:
        // Any printable character or Backspace while cursor is in list → drop cursor,
        // let the Input handle the character naturally (keeps typing feel snappy)
        if (focusedIdx >= 0 && (e.key.length === 1 || e.key === 'Backspace')) {
          setFocusedIdx(-1)
        }
    }
  }, [items, focusedIdx, selectedItems, handleRowClick, handleConfirm, handleRowDblClick])

  // ── Derived ───────────────────────────────────────────────────────────────

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
            <div style={{ fontSize: 11, color: '#64748b', marginTop: 2, display: 'flex', alignItems: 'center', gap: 5, flexWrap: 'wrap' }}>
              <span>Dept: <strong style={{ color: '#1677ff' }}>{depName || depCode || 'All'}</strong></span>
              <span style={{ color: '#cbd5e1' }}>·</span>
              <Kbd>↑↓</Kbd><span>navigate</span>
              <span style={{ color: '#cbd5e1' }}>·</span>
              <Kbd>Space</Kbd><span>select</span>
              <span style={{ color: '#cbd5e1' }}>·</span>
              <Kbd>Enter</Kbd><span>add</span>
              <span style={{ color: '#cbd5e1' }}>·</span>
              <span>Double-click to add instantly</span>
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
          placeholder="Search by item Id or name…"
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          onKeyDown={handleSearchKeyDown}
          allowClear
          style={{ borderRadius: 8, background: '#f8fafc', fontSize: 13 }}
        />
        <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Typography.Text type="secondary" style={{ fontSize: 11 }}>
            {focusedIdx >= 0
              ? <span>Row <strong>{focusedIdx + 1}</strong> of {items.length} — <Kbd>Space</Kbd> to {selectedItems.has(items[focusedIdx]?.itemCode ?? '') ? 'deselect' : 'select'}</span>
              : 'Press ↓ to navigate rows with keyboard'}
          </Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: 11 }}>
            {loading ? 'Loading…' : `${items.length.toLocaleString()} items loaded`}
          </Typography.Text>
        </div>
      </div>

      {/* ── Item table ── */}
      <div ref={scrollDivRef} style={{ maxHeight: 380, overflowY: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ ...TH, width: 36, textAlign: 'center' }}>Img</th>
              <th style={{ ...TH, width: 90 }}>Item Id</th>
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
                  const isSel     = selectedItems.has(item.itemCode)
                  const isFocused = focusedIdx === idx
                  return (
                    <tr
                      key={item.itemCode}
                      data-idx={idx}
                      style={{
                        background:    isSel ? '#eff6ff' : isFocused ? '#fefce8' : idx % 2 === 0 ? '#ffffff' : '#fafafa',
                        cursor:        'pointer',
                        outline:       isSel ? '2px solid #1677ff' : 'none',
                        outlineOffset: -1,
                        borderLeft:    isFocused ? '3px solid #f59e0b' : '3px solid transparent',
                        transition:    'background 0.1s',
                      }}
                      onClick={() => { handleRowClick(item); setFocusedIdx(idx) }}
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
                              ₹ {Number(item.lpoRate).toLocaleString('en-IN', { minimumFractionDigits: 4, maximumFractionDigits: 4 })}
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
              Click or use <Kbd>↑↓</Kbd> + <Kbd>Space</Kbd> to select · Double-click to add instantly
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
