import { memo, useCallback, useEffect, useRef, useState } from 'react'
import { Button, DatePicker, InputNumber, Modal, Tooltip } from 'antd'
import dayjs from 'dayjs'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { generateUUID } from '@/shared/lib/uuid'
import { getFYBounds } from '@/shared/lib/dateUtils'
import * as prApi from '../../api/prApi'
import { ItemPickerModal } from '../pr-form/ItemPickerModal'
import { MachineLookupModal } from '../pr-form/MachineLookupModal'
import { CostCentreLookupModal } from '../pr-form/CostCentreLookupModal'
import type { AmendmentLineLocal, ItemLookup, MachineLookup, CostCentreOption, RateSource } from '../../types'
import { erpTh, erpTd } from '@/shared/styles/erpTable'

// ── Constants ─────────────────────────────────────────────────────────────────
const MAX_RATE    = 999_999_999
const MAX_APPCOST = 99_999_999_999

// ── Style helpers ─────────────────────────────────────────────────────────────
const TH = (extra?: React.CSSProperties): React.CSSProperties =>
  erpTh({ padding: '8px 8px', fontSize: 11, fontWeight: 600, textAlign: 'left',
          zIndex: 10, borderRight: '1px solid rgba(255,255,255,.07)', ...extra })
const TD = (extra?: React.CSSProperties): React.CSSProperties =>
  erpTd({ padding: '3px 6px', ...extra })

function numFmt(v: number | undefined | null, dp: number): string {
  if (v === null || v === undefined || v === 0) return '—'
  return Number(v).toLocaleString('en-IN', { minimumFractionDigits: dp, maximumFractionDigits: dp })
}

function calcAppCost(rate: number, qty: number): number {
  if (!rate || rate <= 0 || !qty || qty <= 0) return 0
  return parseFloat((rate * qty).toFixed(2))
}

function statusBadge(status: string): React.ReactNode {
  const map: Record<string, { bg: string; color: string }> = {
    Approved: { bg: '#EAF3DE', color: '#3B6D11' },
    Ordered:  { bg: '#FAEEDA', color: '#BA7517' },
    Requested:{ bg: '#E6F1FB', color: '#185FA5' },
  }
  const s = map[status] ?? { bg: '#f0f0f0', color: '#888' }
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 10,
      whiteSpace: 'nowrap', display: 'inline-block',
      background: s.bg, color: s.color,
    }}>
      {status || '—'}
    </span>
  )
}

// ── Read-only row ─────────────────────────────────────────────────────────────
const RORow = memo(({ row, idx }: { row: AmendmentLineLocal; idx: number }) => (
  <>
    <td style={TD({ width: 36, textAlign: 'center', fontSize: 11, color: '#888', padding: '0 8px' })}>{idx + 1}</td>
    <td style={TD({ width: 88, fontFamily: 'monospace', fontWeight: 700, fontSize: 11, padding: '0 8px' })}>{row.itemCode}</td>
    <td style={TD({ minWidth: 175, fontSize: 12, padding: '0 8px' })}>{row.itemName}</td>
    <td style={TD({ width: 48, textAlign: 'center', fontSize: 11, color: '#888', padding: '0 8px' })}>{row.uom}</td>
    <td style={TD({ width: 82, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>
      {numFmt(row.curStock, 3)}
    </td>
    <td style={TD({ width: 100, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, padding: '0 8px' })}>
      {numFmt(row.qtyInd, 3)}
    </td>
    <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, padding: '0 8px' })}>
      {numFmt(row.rate, 4)}
    </td>
    <td style={TD({ width: 95, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, fontWeight: 600, padding: '0 8px' })}>
      {row.appCost > 0 ? row.appCost.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '—'}
    </td>
    <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>
      {numFmt(row.qtyApproved, 3)}
    </td>
    <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>
      {numFmt(row.qtyOrdered, 3)}
    </td>
    <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>
      {numFmt(row.qtyReceived, 3)}
    </td>
    <td style={TD({ width: 112, fontSize: 11, padding: '0 8px' })}>
      {row.reqdDate ? dayjs(row.reqdDate).format('DD/MM/YYYY') : <span style={{ color: '#d1d5db' }}>—</span>}
    </td>
    <td style={TD({ minWidth: 115, fontSize: 11, padding: '0 8px' })}>{row.macNo || <span style={{ color: '#d1d5db' }}>—</span>}</td>
    <td style={TD({ minWidth: 135, fontSize: 11, padding: '0 8px' })}>{row.ccName || (row.ccCode != null ? String(row.ccCode) : <span style={{ color: '#d1d5db' }}>—</span>)}</td>
    <td style={TD({ minWidth: 105, fontSize: 11, padding: '0 8px' })}>{row.remarks || <span style={{ color: '#d1d5db' }}>—</span>}</td>
    <td style={TD({ width: 88, textAlign: 'center', padding: '0 6px' })}>{statusBadge(row.lineStatus)}</td>
    <td style={TD({ width: 32, textAlign: 'center', padding: '0 4px' })}>
      {/* delete placeholder — invisible in read-only */}
      <span style={{ display: 'inline-block', width: 26, height: 26 }} />
    </td>
  </>
))
RORow.displayName = 'RORow'

// ── Inline cell input ─────────────────────────────────────────────────────────
const cellInp = (extra?: React.CSSProperties): React.CSSProperties => ({
  height: 26, border: '1px solid #e2e2e2', borderRadius: 3, padding: '0 6px',
  fontSize: 11, fontFamily: 'monospace', color: '#1a1a1a', background: '#fff',
  outline: 'none', width: '100%', boxSizing: 'border-box',
  ...extra,
})

// ── Editable row ──────────────────────────────────────────────────────────────
interface EditRowProps {
  row:           AmendmentLineLocal
  idx:           number
  isLast:        boolean
  onUpdate:      (field: keyof AmendmentLineLocal, value: unknown) => void
  onDelete:      () => void
  onOpenMachine: () => void
  onOpenCC:      () => void
  amendDate?:    string  // DD/MM/YYYY — from PO_APRH.amenddate
}

const EditRow = memo(({
  row, idx, isLast, onUpdate, onDelete, onOpenMachine, onOpenCC, amendDate,
}: EditRowProps) => {
  const qtyError  = !row.qtyInd || row.qtyInd <= 0
  const rateError = (row.rate ?? 0) > MAX_RATE
  const costError = row.appCost > MAX_APPCOST
  const amendDayjs    = amendDate ? dayjs(amendDate, 'DD/MM/YYYY') : null
  const reqdDateError = !!row.reqdDate && !!amendDayjs &&
    dayjs(row.reqdDate).isBefore(amendDayjs, 'day')

  return (
    <>
      <td style={TD({ width: 36, textAlign: 'center', fontSize: 11, color: '#888', padding: '0 8px' })}>{idx + 1}</td>
      <td style={TD({ width: 88, fontFamily: 'monospace', fontWeight: 700, fontSize: 11, color: '#1e293b', padding: '0 8px' })}>{row.itemCode}</td>
      <td style={TD({ minWidth: 175, fontSize: 12, color: '#1e293b', padding: '0 8px' })}>{row.itemName}</td>
      <td style={TD({ width: 48, textAlign: 'center', fontSize: 11 })}>{row.uom || <span style={{ color: '#d1d5db' }}>—</span>}</td>
      {/* Curr. Stock — read-only */}
      <td style={TD({ width: 82, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>
        {numFmt(row.curStock, 3)}
      </td>
      {/* Qty Required — editable */}
      <td style={TD({ width: 100 })}>
        <InputNumber
          size="small"
          value={row.qtyInd}
          min={0}
          precision={3}
          style={{ width: '100%', height: 26 }}
          status={qtyError ? 'error' : undefined}
          onChange={(v) => onUpdate('qtyInd', v ?? 0)}
        />
      </td>
      {/* Rate — editable + optional justification */}
      <td style={TD({ width: 88 })}>
        <InputNumber
          size="small"
          value={row.rate}
          min={0}
          max={MAX_RATE}
          precision={4}
          style={{ width: '100%', height: 26 }}
          status={rateError ? 'error' : undefined}
          onChange={(v) => onUpdate('rate', v ?? 0)}
        />
        {row.rateSource === 'MANUAL' && (
          <input
            value={row.rateJustification}
            placeholder="Justification *"
            maxLength={200}
            style={cellInp({
              marginTop: 2, height: 22, fontSize: 10,
              borderColor: row.rateJustification ? '#e2e2e2' : '#A32D2D',
            })}
            onChange={(e) => onUpdate('rateJustification', e.target.value)}
          />
        )}
      </td>
      {/* Approx Value — computed read-only */}
      <td style={TD({ width: 95, textAlign: 'right', fontFamily: 'monospace', fontWeight: 600, fontSize: 11, padding: '0 8px', ...(costError ? { color: '#ff4d4f', background: '#fff1f0' } : {}) })}>
        {row.appCost > 0 ? row.appCost.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : <span style={{ color: '#d1d5db' }}>—</span>}
      </td>
      {/* Qty Approved/Ordered/Received — read-only */}
      <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>{numFmt(row.qtyApproved, 3)}</td>
      <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>{numFmt(row.qtyOrdered, 3)}</td>
      <td style={TD({ width: 88, textAlign: 'right', fontFamily: 'monospace', fontSize: 11, color: '#888', padding: '0 8px' })}>{numFmt(row.qtyReceived, 3)}</td>
      {/* Required Date — editable; must be >= Amendment Date (FSD §3) */}
      <td style={TD({ width: 112 })}>
        <Tooltip
          title="Required Date cannot be before Amendment Date"
          color="#ff4d4f"
          open={reqdDateError ? true : false}
        >
          <DatePicker
            size="small"
            value={row.reqdDate ? dayjs(row.reqdDate) : null}
            format="DD/MM/YYYY"
            style={{ width: '100%', height: 26 }}
            status={reqdDateError ? 'error' : undefined}
            disabledDate={(d) => amendDayjs ? d.isBefore(amendDayjs, 'day') : false}
            onChange={(d) => onUpdate('reqdDate', d ? d.format('YYYY-MM-DD') : null)}
          />
        </Tooltip>
      </td>
      {/* Machine — button lookup */}
      <td style={TD({ minWidth: 115 })}>
        <Button size="small" onClick={onOpenMachine}
          style={{
            width: '100%', height: 26, fontSize: 11, padding: '0 6px', textAlign: 'left',
            fontFamily: row.macNo ? 'monospace' : undefined,
            color: row.macNo ? '#1e293b' : '#94a3b8',
            borderColor: '#d9d9d9', background: '#fff',
          }}
          title={row.macDesc || undefined}
        >
          {row.macNo || 'Machine…'}
        </Button>
      </td>
      {/* Sub Cost Centre — button lookup */}
      <td style={TD({ minWidth: 135 })}>
        <Button size="small" onClick={onOpenCC}
          style={{
            width: '100%', height: 26, fontSize: 11, padding: '0 6px', textAlign: 'left',
            color: row.ccCode != null ? '#1e293b' : '#94a3b8',
            borderColor: '#d9d9d9', background: '#fff',
          }}
          title={row.ccCode != null ? `ID: ${row.ccCode}` : undefined}
        >
          {row.ccCode != null ? (row.ccName || String(row.ccCode)) : 'Sub Cost Centre…'}
        </Button>
      </td>
      {/* Remarks — editable */}
      <td style={TD({ minWidth: 105 })}>
        <input
          value={row.remarks}
          maxLength={50}
          placeholder="Remarks…"
          style={cellInp({ fontFamily: 'inherit' })}
          onChange={(e) => onUpdate('remarks', e.target.value)}
        />
      </td>
      {/* PR Status — read-only */}
      <td style={TD({ width: 88, textAlign: 'center', padding: '0 6px' })}>{statusBadge(row.lineStatus)}</td>
      {/* Delete */}
      <td style={TD({ width: 32, textAlign: 'center', padding: '0 4px' })}>
        <button
          disabled={isLast}
          onClick={onDelete}
          title={isLast ? 'At least one line is required' : 'Remove row'}
          style={{
            width: 26, height: 26, border: 'none', background: 'none',
            cursor: isLast ? 'default' : 'pointer',
            color: '#888', fontSize: 13,
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            borderRadius: 3, opacity: isLast ? 0 : 1,
          }}
          onMouseEnter={(e) => { if (!isLast) { (e.currentTarget as HTMLButtonElement).style.background = '#FCEBEB'; (e.currentTarget as HTMLButtonElement).style.color = '#A32D2D' } }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = 'none'; (e.currentTarget as HTMLButtonElement).style.color = '#888' }}
        >
          ✕
        </button>
      </td>
    </>
  )
})
EditRow.displayName = 'EditRow'

// ── Props ─────────────────────────────────────────────────────────────────────
interface Props {
  lines:          AmendmentLineLocal[]
  isReadOnly:     boolean
  depCode:        string
  depName?:       string
  amendDate?:     string
  onChange:       (updated: AmendmentLineLocal[]) => void
  onLineDelete?:  (prSno: number) => void   // deltype=2 line-level delete
}

// ── Main component ────────────────────────────────────────────────────────────
export function PrAmendmentLineGrid({ lines, isReadOnly, depCode, depName, amendDate, onChange, onLineDelete }: Props) {
  const divCode = useAuthStore((s) => s.user?.divCode ?? '')

  const linesRef = useRef<AmendmentLineLocal[]>(lines)
  useEffect(() => { linesRef.current = lines }, [lines])

  const [pickerOpen,       setPickerOpen]       = useState(false)
  const [machinePickerKey, setMachinePickerKey] = useState<string | null>(null)
  const [ccPickerKey,      setCcPickerKey]      = useState<string | null>(null)

  // ── Row update ────────────────────────────────────────────────────────────
  const handleRowUpdate = useCallback((rowKey: string, field: keyof AmendmentLineLocal, value: unknown) => {
    const row = linesRef.current.find((r) => r.key === rowKey)
    if (!row) return
    const updated = { ...row, [field]: value } as AmendmentLineLocal

    if (field === 'rate' || field === 'qtyInd') {
      const r = field === 'rate' ? (value as number) : row.rate
      const q = field === 'qtyInd' ? (value as number) : row.qtyInd
      updated.appCost = calcAppCost(r, q)
    }
    if (field === 'rate') {
      const newRate = value as number
      if (newRate !== row.rate && row.rateSource !== 'MANUAL') {
        updated.rateSource = 'MANUAL'
        updated.rateJustification = ''
      }
    }

    onChange(linesRef.current.map((l) => (l.key === rowKey ? updated : l)))
  }, [onChange])

  // ── Row delete ────────────────────────────────────────────────────────────
  const handleRowDelete = useCallback((rowKey: string) => {
    const row = linesRef.current.find((r) => r.key === rowKey)
    if (!row) return
    Modal.confirm({
      title:         'Remove Item',
      content:       `Remove ${row.itemCode} from the amendment?`,
      okText:        'Remove',
      okButtonProps: { danger: true },
      cancelText:    'Cancel',
      onOk: () => { onChange(linesRef.current.filter((l) => l.key !== rowKey)) },
    })
  }, [onChange])

  // ── Machine picker ────────────────────────────────────────────────────────
  const handleMachineSelect = useCallback((machine: MachineLookup) => {
    const rowKey = machinePickerKey
    if (!rowKey) return
    const row = linesRef.current.find((r) => r.key === rowKey)
    if (!row) return
    const isDupe = linesRef.current.some(
      (l) => l.key !== rowKey && l.itemCode === row.itemCode && l.macNo === machine.macNo,
    )
    if (isDupe) {
      Modal.warning({
        title:   'Duplicate Machine',
        content: `${row.itemCode} is already assigned to machine ${machine.macNo}.`,
      })
      setMachinePickerKey(null)
      return
    }
    onChange(linesRef.current.map((l) => l.key === rowKey ? { ...l, macNo: machine.macNo, macDesc: machine.macDesc } : l))
    setMachinePickerKey(null)
  }, [machinePickerKey, onChange])

  // ── CC picker ─────────────────────────────────────────────────────────────
  const handleCcSelect = useCallback((cc: CostCentreOption) => {
    const rowKey = ccPickerKey
    if (!rowKey) return
    onChange(linesRef.current.map((l) => l.key === rowKey ? { ...l, ccCode: cc.ccCode, ccName: cc.ccName } : l))
    setCcPickerKey(null)
  }, [ccPickerKey, onChange])

  // ── Item picker ───────────────────────────────────────────────────────────
  const handleItemsFromPicker = useCallback(async (picked: ItemLookup[]) => {
    const { yfDate, ylDate } = getFYBounds()
    const today = new Date().toISOString().split('T')[0]
    const newLines: AmendmentLineLocal[] = []
    const duplicates: string[] = []
    const batchKeys = new Set<string>()

    picked.forEach((item) => {
      const inListNoMachine = linesRef.current.some((l) => l.itemCode === item.itemCode && !l.macNo)
      if (inListNoMachine || batchKeys.has(item.itemCode)) { duplicates.push(item.itemCode); return }
      batchKeys.add(item.itemCode)
      newLines.push({
        key:               generateUUID(),
        prSno:             0,
        itemCode:          item.itemCode,
        itemName:          item.itemName,
        uom:               item.uom,
        minLevel:          item.minLevel,
        maxLevel:          item.maxLevel,
        macNo:             '',
        macDesc:           '',
        qtyInd:            0,
        reqdDate:          null,
        rate:              item.lpoRate ?? 0,
        rateSource:        (item.lpoRate && item.lpoRate > 0 ? 'LPO' : 'ORIGINAL') as RateSource,
        rateJustification: '',
        curStock:          0,
        ccCode:            null,
        ccName:            '',
        catCode:           '',
        bgrpCode:          '',
        place:             '',
        appCost:           0,
        remarks:           '',
        qtyApproved:       0,
        qtyOrdered:        0,
        qtyReceived:       0,
        lineStatus:        'Requested',
        rowVersion:        null,
      })
    })

    if (duplicates.length > 0) {
      Modal.warning({
        title:   'Duplicate Item',
        content: duplicates.length === 1
          ? `${duplicates[0]} is already in the list.`
          : `Already in list: ${duplicates.join(', ')}.`,
      })
    }

    setPickerOpen(false)
    if (newLines.length === 0) return

    onChange([...linesRef.current, ...newLines])

    // Fetch curStock + detail for each new line
    for (const line of newLines) {
      try {
        const detail = await prApi.getItemDetail(divCode, line.itemCode, yfDate, ylDate, today)
        const current = linesRef.current.find((i) => i.key === line.key)
        if (!current) continue
        const rate = detail.lpoRate ?? current.rate
        onChange(linesRef.current.map((l) =>
          l.key === line.key
            ? { ...l, rate, rateSource: (detail.lpoRate && detail.lpoRate > 0 ? 'LPO' : l.rateSource) as RateSource, curStock: detail.currentStock, appCost: calcAppCost(rate, l.qtyInd) }
            : l,
        ))
      } catch { /* non-critical */ }
    }
  }, [divCode, onChange])

  //const validCount = lines.filter((l) => l.itemCode.trim() !== '').length

  return (
    <div style={{
      display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0,
      background: '#fff', overflow: 'hidden',
    }}>
      {/* Scrollable table */}
      <div style={{ flex: 1, minHeight: 0, overflowX: 'auto', overflowY: 'auto', scrollbarGutter: 'stable' } as React.CSSProperties}>
        <table style={{ borderCollapse: 'collapse', fontSize: 12, width: 'max-content', minWidth: '100%' }}>
          <thead>
            <tr>
              <th style={TH({ width: 36, textAlign: 'center' })}>#</th>
              <th style={TH({ width: 88 })}>Item Id</th>
              <th style={TH({ minWidth: 175 })}>Item Name</th>
              <th style={TH({ width: 48, textAlign: 'center' })}>Unit</th>
              <th style={TH({ width: 82, textAlign: 'right' })}>Current Stock</th>
              <th style={TH({ width: 100, textAlign: 'right' })}>
                Quantity Required <span style={{ color: '#f87171' }}>*</span>
              </th>
              <th style={TH({ width: 88, textAlign: 'right' })}>Rate</th>
              <th style={TH({ width: 95, textAlign: 'right' })}>₹ Approx. Value</th>
              <th style={TH({ width: 88, textAlign: 'right' })}>Quantity Approved</th>
              <th style={TH({ width: 88, textAlign: 'right' })}>Quantity Ordered</th>
              <th style={TH({ width: 88, textAlign: 'right' })}>Quantity Received</th>
              <th style={TH({ width: 112 })}>Required Date</th>
              <th style={TH({ minWidth: 115 })}>Machine</th>
              <th style={TH({ minWidth: 135 })}>Sub Cost Centre</th>
              <th style={TH({ minWidth: 105 })}>Remarks</th>
              <th style={TH({ width: 88, textAlign: 'center' })}>PR Status</th>
              <th style={TH({ width: 32 })}></th>
            </tr>
          </thead>
          <tbody>
            {lines.map((row, idx) => (
              <tr
                key={row.key}
                style={{
                  background: isReadOnly ? (idx % 2 === 0 ? '#fff' : '#fafaf8') : '#fff',
                  cursor: onLineDelete ? 'pointer' : undefined,
                }}
                onMouseEnter={(e) => { if (isReadOnly) (e.currentTarget as HTMLTableRowElement).style.background = onLineDelete ? '#fff0f0' : '#f0f6ff' }}
                onMouseLeave={(e) => { if (isReadOnly) (e.currentTarget as HTMLTableRowElement).style.background = idx % 2 === 0 ? '#fff' : '#fafaf8' }}
                onClick={() => { if (onLineDelete && row.prSno > 0) onLineDelete(row.prSno) }}
              >
                {isReadOnly
                  ? <RORow row={row} idx={idx} />
                  : (
                    <EditRow
                      row={row}
                      idx={idx}
                      isLast={lines.length <= 1}
                      onUpdate={(f, v) => handleRowUpdate(row.key, f, v)}
                      onDelete={() => handleRowDelete(row.key)}
                      onOpenMachine={() => setMachinePickerKey(row.key)}
                      onOpenCC={() => setCcPickerKey(row.key)}
                      amendDate={amendDate}
                    />
                  )
                }
              </tr>
            ))}

            {/* Add row — edit mode only */}
            {!isReadOnly && (
              <tr style={{ background: '#F5F5F3' }}>
                <td style={{ padding: '5px 8px', textAlign: 'center', fontSize: 11, color: '#888' }}>
                  {lines.length + 1}
                </td>
                <td colSpan={16} style={{ padding: '5px 8px' }}>
                  {!depCode ? (
                    <span style={{ fontSize: 11, color: '#94a3b8', fontStyle: 'italic' }}>Select a PR first</span>
                  ) : (
                    <div
                      onClick={() => setPickerOpen(true)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => { if (e.key === 'Enter') setPickerOpen(true) }}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 8, height: 26,
                        border: '1px dashed #bbb', borderRadius: 4, padding: '0 10px',
                        cursor: 'text', color: '#888', fontSize: 12, fontStyle: 'italic',
                        background: '#fff',
                      }}
                    >
                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ flexShrink: 0 }}>
                        <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
                      </svg>
                      Click or Tab here to add items…
                    </div>
                  )}
                </td>
              </tr>
            )}

            {/* Empty message — read-only and no lines */}
            {lines.length === 0 && isReadOnly && (
              <tr>
                <td colSpan={17} style={{ textAlign: 'center', padding: '32px', color: '#888', fontSize: 12 }}>
                  No items in this amendment.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Item picker */}
      <ItemPickerModal
        open={pickerOpen}
        depCode={depCode}
        depName={depName}
        onSelectMultiple={handleItemsFromPicker}
        onCancel={() => setPickerOpen(false)}
      />

      {/* Machine lookup */}
      <MachineLookupModal
        open={machinePickerKey !== null}
        divCode={divCode}
        depCode={depCode}
        onSelect={handleMachineSelect}
        onCancel={() => setMachinePickerKey(null)}
      />

      {/* Cost Centre lookup */}
      <CostCentreLookupModal
        open={ccPickerKey !== null}
        divCode={divCode}
        onSelect={handleCcSelect}
        onCancel={() => setCcPickerKey(null)}
      />
    </div>
  )
}
