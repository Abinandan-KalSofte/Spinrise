import {
  forwardRef, useCallback, useEffect, useImperativeHandle,
  useMemo, useRef, useState, memo,
} from 'react'
import {
  Button, Checkbox, DatePicker, Drawer, Input, InputNumber,
  type InputRef, Modal, Space, Tooltip, Typography,
} from 'antd'
import {
  DeleteOutlined, EyeOutlined, FileImageOutlined, SearchOutlined,
} from '@ant-design/icons'
import { notifyWarning } from '@/shared/lib/notificationHelper'
import { ItemPickerModal } from './ItemPickerModal'
import { MachineLookupModal } from './MachineLookupModal'
import { CostCentreLookupModal } from './CostCentreLookupModal'
import type { MachineLookup, CostCentreOption } from '../../types'
import dayjs from 'dayjs'
import * as prApi from '../../api/prApi'
import { getItemImageUrl } from '../../api/prApi'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { generateUUID } from '@/shared/lib/uuid'
import type { PrLine, ItemLookup } from '../../types'
import { erpTh, ERP_TD as TD } from '@/shared/styles/erpTable'

// ── Types ─────────────────────────────────────────────────────────────────────

export type PRLineItem = PrLine & { key: string; minLevel?: number; maxLevel?: number; itemImage?: string | null }

export interface PRLineItemsTableHandle {
  flushEdit:   () => Promise<void>
  openPicker:  () => void
}

interface PRLineItemsTableProps {
  items:         PRLineItem[]
  divCode:       string
  depCode:       string
  depName?:      string
  prDate?:       string
  disabled:      boolean
  savedPrNo?:    number
  emptyText?:    string
  onAdd:         (item: PRLineItem) => void
  onUpdate:      (item: PRLineItem) => void
  onDelete:      (key: string) => void
  onLineDelete?: (prSno: number, itemCode: string) => Promise<void>
  onWarning?:    (msg: string) => void
}

// ── Constants ─────────────────────────────────────────────────────────────────

// DB column limits: Rate numeric(13,4) → 9 integer digits; AppCost numeric(13,2) → 11 integer digits
export const MAX_RATE     = 999_999_999
export const MAX_APPCOST  = 99_999_999_999

const TH = erpTh({ zIndex: 10 })
const TD_TEXT = { ...TD, fontSize: 11, color: '#1e293b' }

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeEmptyLine(): PRLineItem {
  return {
    key: generateUUID(),
    prSno: 0, itemCode: '', itemName: '', uom: '', macNo: '',
    qtyInd: 0, reqdDate: null, rate: 0, lpoRate: 0, lpoDate: null,
    lpoFrom: '', rateSource: 'LPO', rateJustification: '',
    curStock: 0, ccCode: null, catCode: '', bgrpCode: '', appCost: 0,
    remarks: '', sample: 'N', lineStatus: '',
  }
}

function calcAppCost(rate: number, qty: number): number {
  if (!rate || rate <= 0 || !qty || qty <= 0) return 0
  return parseFloat((rate * qty).toFixed(2))
}

// ── Drawer image (served via backend endpoint, not base64) ────────────────────

function DrawerItemImage({ itemCode }: { itemCode: string }) {
  const [errored, setErrored] = useState(false)
  return errored ? (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      margin: '20px 8px', height: 160, border: '2px dashed #d9d9d9', borderRadius: 8, background: '#fafafa',
    }}>
      <FileImageOutlined style={{ fontSize: 36, color: '#bfbfbf' }} />
      <Typography.Text type="secondary" style={{ fontSize: 12, marginTop: 8 }}>No Image Available</Typography.Text>
    </div>
  ) : (
    <div style={{ margin: '20px 8px', borderRadius: 8, overflow: 'hidden', border: '1px solid #e2e2e2' }}>
      <img
        src={getItemImageUrl(itemCode)}
        alt={itemCode}
        style={{ width: '100%', maxHeight: 200, objectFit: 'contain', display: 'block', background: '#fafafa' }}
        onError={() => setErrored(true)}
      />
    </div>
  )
}

// ── Read-Only Cell ────────────────────────────────────────────────────────────

function ROCell({ value, type = 'text', precision = 3 }: {
  value?: unknown; type?: 'text' | 'number' | 'date'; precision?: number
}) {
  if (value === null || value === undefined || value === '') {
    return <span style={{ color: '#d1d5db' }}>—</span>
  }
  if (type === 'number') return (
    <span style={{ fontVariantNumeric: 'tabular-nums' }}>
      {Number(value).toLocaleString('en-IN', { minimumFractionDigits: precision, maximumFractionDigits: precision })}
    </span>
  )
  if (type === 'date')   return <span>{dayjs(value as string).format('DD-MMM-YYYY')}</span>
  return <span>{value as string}</span>
}

// ── Read-Only Row ─────────────────────────────────────────────────────────────

interface RORowProps { row: PRLineItem; idx: number; onView: (r: PRLineItem) => void }

const RORow = memo(({ row, idx, onView }: RORowProps) => (
  <>
    <td style={{ ...TD_TEXT, width: 30, textAlign: 'center', color: '#94a3b8' }}>{row.prSno > 0 ? row.prSno : idx + 1}</td>
    <td style={{ ...TD_TEXT, width: 88, fontFamily: 'monospace', fontWeight: 700 }}>{row.itemCode}</td>
    <td style={{ ...TD_TEXT, minWidth: 150 }}>{row.itemName}</td>
    <td style={{ ...TD_TEXT, width: 46, textAlign: 'center' }}><ROCell value={row.uom} /></td>
    <td style={{ ...TD_TEXT, width: 82, textAlign: 'right' }}><ROCell value={row.qtyInd} type="number" precision={3} /></td>
    <td style={{ ...TD_TEXT, width: 110, textAlign: 'right' }}><ROCell value={row.rate} type="number" precision={4} /></td>
    <td style={{ ...TD_TEXT, width: 120, textAlign: 'right' }}>
      {row.appCost > 0
        ? <span style={{ fontVariantNumeric: 'tabular-nums' }}>
            {row.appCost.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </span>
        : <span style={{ color: '#d1d5db' }}>—</span>}
    </td>
    <td style={{ ...TD_TEXT, width: 140 }}><ROCell value={row.reqdDate} type="date" /></td>
    <td style={{ ...TD_TEXT, width: 90, fontSize: 10 }}>
      {row.macNo
        ? <Tooltip title={row.macDesc || undefined}>
            <span style={{ fontFamily: 'monospace', cursor: row.macDesc ? 'help' : 'default' }}>{row.macNo}</span>
          </Tooltip>
        : <span style={{ color: '#d1d5db' }}>—</span>}
    </td>
    <td style={{ ...TD_TEXT, width: 130, fontSize: 10 }}>
      {row.ccCode != null
        ? <Tooltip title={`ID: ${row.ccCode}`}>
            <span style={{ cursor: 'help' }}>{row.ccName || String(row.ccCode)}</span>
          </Tooltip>
        : <span style={{ color: '#d1d5db' }}>—</span>}
    </td>
    <td style={{ ...TD_TEXT, minWidth: 110, fontSize: 10, maxWidth: 150, overflow: 'hidden', textOverflow: 'ellipsis' }}>
      <ROCell value={row.remarks} />
    </td>
    <td style={{ ...TD_TEXT, width: 52, textAlign: 'center', userSelect: 'none' }}>{row.sample === 'Y' ? '✓' : ''}</td>
    <td style={{ ...TD_TEXT, width: 40, textAlign: 'center', userSelect: 'none' }}>
      <Tooltip title="View Details" mouseEnterDelay={0.5}>
        <Button tabIndex={-1} type="text" size="small"
          icon={<EyeOutlined style={{ color: '#7c3aed', fontSize: 12 }} />}
          onClick={(e) => { e.stopPropagation(); onView(row) }} />
      </Tooltip>
    </td>
  </>
), (prev, next) => prev.row === next.row && prev.idx === next.idx)
RORow.displayName = 'RORow'

// ── Editable Row ──────────────────────────────────────────────────────────────

interface EditRowProps {
  row:              PRLineItem
  idx:              number
  divCode:          string
  depCode:          string
  qtyError:         boolean
  rateError:        boolean
  isLast:           boolean
  isFirstRow:       boolean
  isLastRow:        boolean
  onUpdate:         (field: keyof PRLineItem, value: unknown) => void
  onView:           (r: PRLineItem) => void
  onDelete:         () => void
  onTabToNext:      () => void
  onTabToPrev:      () => void
  onTabToSearch:    () => void
  onOpenMachine:     () => void
  onOpenMachineAuto: () => void
  onOpenCC:          () => void
}

const EditRow = memo(({
  row, idx, qtyError, rateError, isLast, isFirstRow, isLastRow,
  onUpdate, onView, onDelete, onTabToNext, onTabToPrev, onTabToSearch,
  onOpenMachine, onOpenMachineAuto, onOpenCC,
}: EditRowProps) => {
  const deleteTip = isLast ? 'At least one line is required' : 'Delete line'

  return (
    <>
      <td style={{ ...TD, width: 30, textAlign: 'center', color: '#94a3b8' }}>{row.prSno > 0 ? row.prSno : idx + 1}</td>
      <td style={{ ...TD, width: 88, fontFamily: 'monospace', fontWeight: 700, color: '#1e293b' }}>{row.itemCode}</td>
      <td style={{ ...TD, minWidth: 150, fontSize: 11, color: '#1e293b' }}>{row.itemName}</td>
      <td style={{ ...TD, width: 46, textAlign: 'center', fontSize: 11 }}>{row.uom || <span style={{ color: '#d1d5db' }}>—</span>}</td>
      <td style={{ ...TD, width: 82 }} data-qty-for={row.key}>
        <Tooltip
          title={qtyError
            ? ((row.qtyInd ?? 0) === 0
                ? 'Qty must be greater than 0'
                : (row.maxLevel ?? 0) > 0 && (row.qtyInd ?? 0) > (row.maxLevel ?? 0)
                  ? `Exceeds maximum order level (max: ${row.maxLevel})`
                  : `Below minimum order level (min: ${row.minLevel ?? 0})`)
            : ''}
          open={qtyError}
          color="#ff4d4f"
        >
          <InputNumber
            size="small"
            value={row.qtyInd}
            min={0}
            precision={3}
            style={{ width: '100%', height: '24px' }}
            status={qtyError ? 'error' : undefined}
            onChange={(v) => onUpdate('qtyInd', v ?? 0)}
            onKeyDown={(e) => {
              if (e.key === 'Tab' && e.shiftKey && !isFirstRow) {
                e.preventDefault()
                onTabToPrev()
              }
            }}
          />
        </Tooltip>
      </td>
      <td style={{ ...TD, width: 110 }}>
        <Tooltip
          title={rateError ? `Rate cannot exceed ${MAX_RATE.toLocaleString('en-IN')}` : ''}
          open={rateError}
          color="#ff4d4f"
        >
          <InputNumber
            size="small"
            tabIndex={-1}
            value={row.rate}
            min={0}
            max={MAX_RATE}
            precision={4}
            style={{ width: '100%', height: '24px' }}
            status={rateError ? 'error' : undefined}
            onChange={(v) => onUpdate('rate', v ?? 0)}
          />
        </Tooltip>
      </td>
      <td style={{
        ...TD, width: 120, textAlign: 'right', fontVariantNumeric: 'tabular-nums', fontWeight: 600, fontSize: 11,
        ...(row.appCost > MAX_APPCOST ? { color: '#ff4d4f', background: '#fff1f0' } : {}),
      }}>
        {row.appCost > 0
          ? row.appCost.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
          : <span style={{ color: '#d1d5db' }}>—</span>}
      </td>
      <td style={{ ...TD, width: 140 }}>
        <DatePicker
          size="small"
          value={row.reqdDate ? dayjs(row.reqdDate) : null}
          format="DD-MMM-YYYY"
          style={{ width: '100%', height: '24px' }}
          onChange={(d) => {
            onUpdate('reqdDate', d ? d.format('YYYY-MM-DD') : null)
            if (d) onOpenMachineAuto()
          }}
        />
      </td>
      <td style={{ ...TD, width: 90 }}>
        <Button
          size="small"
          onClick={onOpenMachine}
          style={{
            width: '100%', height: '24px', fontSize: 11, padding: '0 6px',
            textAlign: 'left', fontFamily: row.macNo ? 'monospace' : undefined,
            color: row.macNo ? '#1e293b' : '#94a3b8',
            borderColor: '#d9d9d9', background: '#fff',
          }}
          title={row.macDesc || undefined}
        >
          {row.macNo || 'Machine…'}
        </Button>
      </td>
      <td style={{ ...TD, width: 130 }}>
        <Button
          size="small"
          onClick={onOpenCC}
          style={{
            width: '100%', height: '24px', fontSize: 11, padding: '0 6px',
            textAlign: 'left',
            color: row.ccCode != null ? '#1e293b' : '#94a3b8',
            borderColor: '#d9d9d9', background: '#fff',
          }}
          title={row.ccCode != null ? `ID: ${row.ccCode}` : undefined}
        >
          {row.ccCode != null ? (row.ccName || String(row.ccCode)) : 'Sub Cost Centre…'}
        </Button>
      </td>
      <td style={{ ...TD, minWidth: 110 }} data-remarks-for={row.key}>
        <Input
          size="small"
          value={row.remarks}
          maxLength={500}
          placeholder="Remarks…"
          style={{ height: '24px' }}
          onChange={(e) => onUpdate('remarks', e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Tab' && !e.shiftKey) {
              e.preventDefault()
              if (!isLastRow) onTabToNext()
              else onTabToSearch()
            }
          }}
        />
      </td>
      <td style={{ ...TD, width: 52, textAlign: 'center' }}>
        <Checkbox
          tabIndex={-1}
          checked={row.sample === 'Y'}
          onChange={(e) => onUpdate('sample', e.target.checked ? 'Y' : 'N')}
        />
      </td>
      <td style={{ ...TD, width: 40, textAlign: 'center' }}>
        <Space size={2}>
          <Tooltip title="View Details" mouseEnterDelay={0.5}>
            <Button tabIndex={-1} type="text" size="small"
              icon={<EyeOutlined style={{ color: '#7c3aed', fontSize: 12 }} />}
              onClick={() => onView(row)} />
          </Tooltip>
          <Tooltip title={deleteTip} mouseEnterDelay={0.5}>
            <Button tabIndex={-1} type="text" size="small" danger
              icon={<DeleteOutlined style={{ fontSize: 12 }} />}
              disabled={isLast}
              onClick={onDelete} />
          </Tooltip>
        </Space>
      </td>
    </>
  )
})
EditRow.displayName = 'EditRow'

// ── Main Component ────────────────────────────────────────────────────────────

export const PRLineItemsTable = forwardRef<PRLineItemsTableHandle, PRLineItemsTableProps>(
function PRLineItemsTable({ items, divCode, depCode, depName, disabled, savedPrNo, emptyText, onAdd, onUpdate, onDelete, onLineDelete }, ref) {
  const itemsRef = useRef<PRLineItem[]>(items)
  useEffect(() => { itemsRef.current = items }, [items])

  const [editingRowKey,  setEditingRowKey]  = useState<string | null>(null)
  const [qtyErrorKeys,   setQtyErrorKeys]   = useState<Set<string>>(new Set())
  const [focusQtyKey,    setFocusQtyKey]    = useState<string | null>(null)
  const [focusRemarksKey,setFocusRemarksKey]= useState<string | null>(null)
  const [pickerOpen,     setPickerOpen]     = useState(false)

  const [machinePickerKey,     setMachinePickerKey]     = useState<string | null>(null)
  const [machineAutoNextKey,   setMachineAutoNextKey]   = useState<string | null>(null)
  const [ccPickerKey,          setCcPickerKey]          = useState<string | null>(null)
  const [ccAutoNextKey,        setCcAutoNextKey]         = useState<string | null>(null)

  const [lineDeleteRow,  setLineDeleteRow]  = useState<PRLineItem | null>(null)
  const [lineDeleting,   setLineDeleting]   = useState(false)
  const [viewRow,        setViewRow]        = useState<PRLineItem | null>(null)
  const searchInputRef      = useRef<InputRef>(null)
  const pendingFocusKeyRef  = useRef<string | null>(null)

  useImperativeHandle(ref, () => ({
    flushEdit:  async () => {},
    openPicker: () => { if (!disabled) setPickerOpen(true) },
  }), [disabled])

  const handleOpenView = useCallback((row: PRLineItem) => {
    setViewRow({ ...row })
  }, [])

  // Focus helpers
  useEffect(() => {
    if (!focusQtyKey) return
    let cancelled = false
    const attempt = (tries: number) => {
      if (cancelled) return
      const td  = document.querySelector<HTMLElement>(`td[data-qty-for="${focusQtyKey}"]`)
      const inp = td?.querySelector<HTMLInputElement>('input')
      if (inp) { inp.focus(); inp.select(); setFocusQtyKey(null) }
      else if (tries > 0) setTimeout(() => attempt(tries - 1), 40)
      else setFocusQtyKey(null)
    }
    setTimeout(() => attempt(6), 30)
    return () => { cancelled = true }
  }, [focusQtyKey])

  useEffect(() => {
    if (!focusRemarksKey) return
    const t = setTimeout(() => {
      const td  = document.querySelector<HTMLElement>(`td[data-remarks-for="${focusRemarksKey}"]`)
      const inp = td?.querySelector<HTMLInputElement>('input')
      inp?.focus()
      setFocusRemarksKey(null)
    }, 80)
    return () => clearTimeout(t)
  }, [focusRemarksKey])

  // After item picker closes, re-assert editing row and focus its qty field.
  // 320ms wait lets Ant Design's modal close animation (300ms) complete before focusing.
  useEffect(() => {
    if (!pickerOpen && pendingFocusKeyRef.current) {
      const key = pendingFocusKeyRef.current
      pendingFocusKeyRef.current = null
      const timer = setTimeout(() => {
        setEditingRowKey(key)
        setFocusQtyKey(key)
      }, 320)
      return () => clearTimeout(timer)
    }
  }, [pickerOpen])

  // Row callbacks
  const handleRowUpdate = useCallback((rowKey: string, field: keyof PRLineItem, value: unknown) => {
    const row = itemsRef.current.find((r) => r.key === rowKey)
    if (!row) return
    const updated = { ...row, [field]: value } as PRLineItem
    if (field === 'rate' || field === 'qtyInd') {
      const r = field === 'rate' ? (value as number) : row.rate
      const q = field === 'qtyInd' ? (value as number) : row.qtyInd
      updated.appCost = calcAppCost(r, q)
    }
    onUpdate(updated)
    if (field === 'qtyInd') {
      const qty = value as number
      if ((qty ?? 0) > 0) {
        setQtyErrorKeys((prev) => { const s = new Set(prev); s.delete(rowKey); return s })
      } else {
        setQtyErrorKeys((prev) => new Set([...prev, rowKey]))
      }
    }
  }, [onUpdate])

  const handleRowDelete = useCallback((rowKey: string) => {
    const row = itemsRef.current.find((r) => r.key === rowKey)
    if (!row) return
    if (savedPrNo && row.prSno > 0) {
      setLineDeleteRow(row)
    } else {
      Modal.confirm({
        title:   'Remove Item',
        content: `Do you want to remove ${row.itemCode} from the list?`,
        okText:  'Remove',
        okButtonProps: { danger: true },
        cancelText: 'Cancel',
        onOk: () => onDelete(rowKey),
      })
    }
  }, [onDelete, savedPrNo])

  const handleTabToNextRow = useCallback((rowKey: string) => {
    const idx  = itemsRef.current.findIndex((r) => r.key === rowKey)
    const next = itemsRef.current[idx + 1]
    if (!next) return
    setEditingRowKey(next.key)
    setFocusQtyKey(next.key)
  }, [])

  const handleTabToPrevRow = useCallback((rowKey: string) => {
    const idx  = itemsRef.current.findIndex((r) => r.key === rowKey)
    const prev = itemsRef.current[idx - 1]
    if (!prev) return
    setEditingRowKey(prev.key)
    setFocusRemarksKey(prev.key)
  }, [])

  // Machine picker callback
  const handleMachineSelect = useCallback((machine: MachineLookup) => {
    const rowKey  = machinePickerKey
    const autoKey = machineAutoNextKey
    if (!rowKey) return
    const row = itemsRef.current.find((r) => r.key === rowKey)
    if (!row) return
    // FSD CEO D-09: itemCode + machineCode must be unique per PR
    const isDupe = itemsRef.current.some(
      (l) => l.key !== rowKey && l.itemCode === row.itemCode && l.macNo === machine.macNo
    )
    if (isDupe) {
      notifyWarning(`${row.itemCode} with the same machine is already in the list.`)
      setMachineAutoNextKey(null)
      setMachinePickerKey(null)
      return
    }
    onUpdate({ ...row, macNo: machine.macNo, macDesc: machine.macDesc })
    setMachineAutoNextKey(null)
    setMachinePickerKey(null)
    if (autoKey) { setCcPickerKey(autoKey); setCcAutoNextKey(autoKey) }
  }, [machinePickerKey, machineAutoNextKey, onUpdate])

  // CC picker callback
  const handleCcSelect = useCallback((cc: CostCentreOption) => {
    const rowKey  = ccPickerKey
    const autoKey = ccAutoNextKey
    if (!rowKey) return
    const row = itemsRef.current.find((r) => r.key === rowKey)
    if (!row) return
    onUpdate({ ...row, ccCode: cc.ccCode, ccName: cc.ccName })
    // Propagate to all other rows with no SCC set
    itemsRef.current
      .filter((r) => r.key !== rowKey && r.ccCode === null)
      .forEach((r) => onUpdate({ ...r, ccCode: cc.ccCode, ccName: cc.ccName }))
    setCcAutoNextKey(null)
    setCcPickerKey(null)
    if (autoKey) setFocusRemarksKey(autoKey)
  }, [ccPickerKey, ccAutoNextKey, onUpdate])

  // Item picker callback
  const handleItemsFromModal = useCallback(async (picked: ItemLookup[]) => {
    const { yfDate, ylDate } = getFYBounds()
    const today = new Date().toISOString().split('T')[0]
    let firstKey: string | null = null
    const newLines: PRLineItem[] = []
    const duplicates: string[] = []
    const batchKeys = new Set<string>()
    const lastCc = [...itemsRef.current].reverse().find((l) => l.ccCode != null)

    picked.forEach((item) => {
      // FSD CEO D-09: block add if same itemCode already exists WITHOUT a machine code
      // (once a machine is assigned, adding another of the same item for a different machine is valid)
      const inListNoMachine = itemsRef.current.some((l) => l.itemCode === item.itemCode && !l.macNo)
      const inBatch = batchKeys.has(item.itemCode)
      if (inListNoMachine || inBatch) {
        duplicates.push(item.itemCode)
        return
      }
      batchKeys.add(item.itemCode)
      const line: PRLineItem = {
        ...makeEmptyLine(),
        itemCode: item.itemCode,
        itemName: item.itemName,
        uom:      item.uom,
        lpoRate:  item.lpoRate ?? 0,
        lpoDate:  item.lpoDate ?? null,
        rate:     item.lpoRate ?? 0,
        appCost:  0,
        minLevel: item.minLevel,
        maxLevel: item.maxLevel,
        ccCode:   lastCc?.ccCode ?? null,
        ccName:   lastCc?.ccName ?? '',
      }
      onAdd(line)
      newLines.push(line)
      if (firstKey === null) firstKey = line.key
      setQtyErrorKeys((prev) => new Set([...prev, line.key]))
    })

    if (duplicates.length > 0) {
      Modal.warning({
        title:   'Duplicate Item',
        content: duplicates.length === 1
          ? `${duplicates[0]} is already in the list.`
          : `Already in list: ${duplicates.join(', ')}.`,
        okText:  'OK',
      })
    }

    if (firstKey) {
      setEditingRowKey(firstKey)
      pendingFocusKeyRef.current = firstKey
    }
    setPickerOpen(false)

    for (const line of newLines) {
      try {
        const detail  = await prApi.getItemDetail(divCode, line.itemCode, yfDate, ylDate, today)
        const current = itemsRef.current.find((i) => i.key === line.key)
        if (!current) continue
        const rate = detail.lpoRate ?? current.lpoRate
        onUpdate({
          ...current,
          rate,
          lpoRate:   detail.lpoRate       ?? current.lpoRate,
          lpoDate:   detail.lpoDate       ?? current.lpoDate,
          curStock:  detail.currentStock,
          minLevel:  detail.minLevel,
          maxLevel:  detail.maxLevel,
          itemImage: detail.itemImage,
          appCost:   calcAppCost(rate, current.qtyInd),
        })
      } catch { /* non-critical */ }
    }
  }, [divCode, onAdd, onUpdate])

  const validCount = items.filter((l) => l.itemCode.trim() !== '').length
  const drawerFields = useMemo(() => viewRow ? [
    { label: 'Item Name',    value: viewRow.itemName || '—' },
    { label: 'Current Stock',value: String(viewRow.curStock ?? '—') },
    { label: 'Last PO Rate', value: viewRow.lpoRate > 0 ? `₹ ${Number(viewRow.lpoRate).toFixed(4)}` : '—' },
    { label: 'Last PO Date', value: viewRow.lpoDate ? dayjs(viewRow.lpoDate).format('DD-MMM-YYYY') : '—' },
    { label: 'Rate Source',  value: viewRow.rateSource || '—' },
    { label: 'Rate Justification', value: viewRow.rateJustification || '—' },
    { label: 'LPO From',     value: viewRow.lpoFrom || '—' },
    { label: 'Cat Code',     value: viewRow.catCode || '—' },
    { label: 'Budget Grp',   value: viewRow.bgrpCode || '—' },
    { label: 'Line Status',  value: viewRow.lineStatus || '—' },
  ] : [], [viewRow])

  return (
    <div style={{
      display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0,
      background: '#fff', borderRadius: 4, overflow: 'hidden', border: '1px solid #e2e2e2',
    }}>
      {/* Header bar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '8px 14px', borderBottom: '1px solid #e2e2e2',
        background: '#fafaf8', flexShrink: 0,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="13" height="13" viewBox="0 0 16 16" style={{ stroke: '#185FA5', fill: 'none', strokeWidth: 1.8 }}>
            <rect x="2" y="2" width="12" height="12" rx="1.5"/>
            <line x1="5" y1="6" x2="11" y2="6"/>
            <line x1="5" y1="9" x2="11" y2="9"/>
          </svg>
          <span style={{ fontSize: 11, fontWeight: 600, color: '#185FA5', letterSpacing: '0.3px' }}>Item Lines</span>
          <span style={{ fontSize: 11, padding: '2px 8px', background: '#E6F1FB', color: '#185FA5', borderRadius: 20 }}>
            {validCount} {validCount === 1 ? 'item' : 'items'}
          </span>
        </div>
      </div>

      {/* Scrollable table */}
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', scrollbarGutter: 'stable' } as React.CSSProperties}>
        <table className="pr-items-grid" style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ position: 'sticky', top: 0, zIndex: 10 }}>
            <tr>
              <th style={{ ...TH, width: 30 }}>#</th>
              <th style={{ ...TH, width: 88 }}>Item Id</th>
              <th style={{ ...TH, minWidth: 150 }}>Item Name</th>
              <th style={{ ...TH, width: 46, textAlign: 'center' }}>Unit</th>
              <th style={{ ...TH, width: 82, textAlign: 'right' }}>Required Quantity <span style={{ color: '#E24B4A' }}>*</span></th>
              <th style={{ ...TH, width: 110, textAlign: 'right' }}>Rate</th>
              <th style={{ ...TH, width: 120, textAlign: 'right' }}>₹ Approx. Value</th>
              <th style={{ ...TH, width: 140 }}>Required Date</th>
              <th style={{ ...TH, width: 90 }}>Machine</th>
              <th style={{ ...TH, width: 130 }}>Sub Cost Centre</th>
              <th style={{ ...TH, minWidth: 110 }}>Remarks</th>
              <th style={{ ...TH, width: 52, textAlign: 'center' }}>Sample</th>
              <th style={{ ...TH, width: 40, textAlign: 'center' }} />
            </tr>
          </thead>
          <tbody>
            {items.map((row, idx) =>
              editingRowKey === row.key && !disabled ? (
                <tr key={row.key} className="pr-items-grid__editing"
                  style={{ background: '#f0f7ff', border: '1px solid #bfdbfe' }}>
                  <EditRow
                    row={row} idx={idx}
                    divCode={divCode}
                    depCode={depCode}
                    qtyError={
                      qtyErrorKeys.has(row.key) ||
                      ((row.minLevel ?? 0) > 0 && (row.qtyInd ?? 0) > 0 && (row.qtyInd ?? 0) < (row.minLevel ?? 0)) ||
                      ((row.maxLevel ?? 0) > 0 && (row.qtyInd ?? 0) > 0 && (row.qtyInd ?? 0) > (row.maxLevel ?? 0))
                    }
                    rateError={(row.rate ?? 0) > MAX_RATE}
                    isLast={items.length <= 1}
                    isFirstRow={idx === 0}
                    isLastRow={idx === items.length - 1}
                    onUpdate={(f, v) => handleRowUpdate(row.key, f, v)}
                    onView={handleOpenView}
                    onDelete={() => handleRowDelete(row.key)}
                    onTabToNext={() => handleTabToNextRow(row.key)}
                    onTabToPrev={() => handleTabToPrevRow(row.key)}
                    onTabToSearch={() => setPickerOpen(true)}
                    onOpenMachine={() => setMachinePickerKey(row.key)}
                    onOpenMachineAuto={() => { setMachinePickerKey(row.key); setMachineAutoNextKey(row.key) }}
                    onOpenCC={() => setCcPickerKey(row.key)}
                  />
                </tr>
              ) : (
                <tr key={row.key}
                  style={{ background: idx % 2 === 0 ? '#ffffff' : '#F0F5FF', cursor: !disabled ? 'pointer' : 'default' }}
                  onClick={() => {
                    if (!disabled) {
                      setEditingRowKey(row.key)
                      setFocusQtyKey(row.key)
                    }
                  }}>
                  <RORow row={row} idx={idx} onView={handleOpenView} />
                </tr>
              )
            )}
            {!disabled && (
              <tr style={{ background: '#f0f7ff', borderTop: '2px dashed #bfdbfe' }}>
                <td style={{ ...TD, textAlign: 'center', color: '#94a3b8' }}>{items.length + 1}</td>
                <td colSpan={12} style={{ ...TD, padding: '8px 14px' }}>
                  {!depCode ? (
                    <Typography.Text type="secondary" style={{ fontSize: 11 }}>Select department first</Typography.Text>
                  ) : (
                    <Input
                      size="small"
                      ref={searchInputRef}
                      placeholder="Click or Tab here to add items…"
                      prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
                      onClick={() => setPickerOpen(true)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') { e.preventDefault(); setPickerOpen(true) }
                      }}
                      readOnly
                      style={{ width: '300px', height: '24px', cursor: 'pointer' }}
                    />
                  )}
                </td>
              </tr>
            )}
            {items.length === 0 && disabled && (
              <tr>
                <td colSpan={13} style={{ textAlign: 'center', padding: '32px', color: '#888', fontSize: 12 }}>
                  {emptyText ?? 'No items added to this requisition.'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Item Picker Modal */}
      <ItemPickerModal
        open={pickerOpen}
        depCode={depCode}
        depName={depName}
        onSelectMultiple={handleItemsFromModal}
        onCancel={() => setPickerOpen(false)}
      />

      {/* Machine Lookup Modal */}
      <MachineLookupModal
        open={machinePickerKey !== null}
        divCode={divCode}
        depCode={depCode}
        onSelect={handleMachineSelect}
        onCancel={() => {
          const autoKey = machineAutoNextKey
          setMachineAutoNextKey(null)
          setMachinePickerKey(null)
          if (autoKey) { setCcPickerKey(autoKey); setCcAutoNextKey(autoKey) }
        }}
      />

      {/* CC Lookup Modal */}
      <CostCentreLookupModal
        open={ccPickerKey !== null}
        divCode={divCode}
        onSelect={handleCcSelect}
        onCancel={() => {
          const autoKey = ccAutoNextKey
          setCcAutoNextKey(null)
          setCcPickerKey(null)
          if (autoKey) setFocusRemarksKey(autoKey)
        }}
      />

      {/* Per-line Delete Modal */}
      <Modal
        title={`Delete Line — ${lineDeleteRow?.itemCode ?? ''}`}
        open={!!lineDeleteRow}
        onCancel={() => setLineDeleteRow(null)}
        onOk={async () => {
          if (!lineDeleteRow) return
          setLineDeleting(true)
          try {
            if (onLineDelete && lineDeleteRow.prSno > 0) {
              await onLineDelete(lineDeleteRow.prSno, lineDeleteRow.itemCode)
            } else {
              onDelete(lineDeleteRow.key)
            }
            setLineDeleteRow(null)
          } finally { setLineDeleting(false) }
        }}
        okText="Delete Line"
        okButtonProps={{ danger: true, loading: lineDeleting }}
        destroyOnClose
      >
        <p>Are you sure you want to permanently delete <strong>{lineDeleteRow?.itemCode}</strong> from this PR?</p>
      </Modal>

      {/* Line Detail Drawer */}
      <Drawer
        title={
          <span>
            Line Details —{' '}
            <span style={{ fontFamily: 'monospace', color: '#1677ff' }}>{viewRow?.itemCode ?? ''}</span>
          </span>
        }
        placement="left"
        width={340}
        open={!!viewRow}
        onClose={() => setViewRow(null)}
        footer={null}
        destroyOnClose
      >
        {viewRow && (
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {drawerFields.map(({ label, value }, i) => (
              <div key={label} style={{
                display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start',
                gap: 12, padding: '10px 8px', borderBottom: '1px solid #f0f0f0',
                background: i % 2 === 0 ? '#fafafa' : '#fff',
              }}>
                <Typography.Text type="secondary" style={{ fontSize: 12, fontWeight: 500, whiteSpace: 'nowrap', flexShrink: 0 }}>
                  {label}
                </Typography.Text>
                <Typography.Text style={{ fontSize: 13, textAlign: 'right', wordBreak: 'break-word' }}>
                  {value}
                </Typography.Text>
              </div>
            ))}
            <DrawerItemImage itemCode={viewRow.itemCode} />
          </div>
        )}
      </Drawer>
    </div>
  )
})

PRLineItemsTable.displayName = 'PRLineItemsTable'
