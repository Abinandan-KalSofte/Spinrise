import { useRef, useCallback, useState } from 'react'
import { AgGridReact } from 'ag-grid-react'
import type { ColDef, GridReadyEvent, CellClickedEvent } from 'ag-grid-community'
import { ModuleRegistry, AllCommunityModule } from 'ag-grid-community'
import 'ag-grid-community/styles/ag-grid.css'
import 'ag-grid-community/styles/ag-theme-alpine.css'
import type { PrLine, ScreenMode } from '../types'
import ItemSelectionModal from './ItemSelectionModal'
import ItemDetailDrawer from './ItemDetailDrawer'
import type { ItemDetail, ItemLookup } from '../types'
import { getItemDetail, checkPendingOrder } from '../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { Modal } from 'antd'
import { notifyError } from '@/shared/lib/notificationHelper'

ModuleRegistry.registerModules([AllCommunityModule])

interface Props {
  mode:       ScreenMode
  lines:      PrLine[]
  fDate:      string
  lDate:      string
  pDate:      string
  depCode:    string
  parameters: import('../types').PrParameters | null
  onLinesChange: (lines: PrLine[]) => void
}

export default function PrItemGrid({
  mode, lines, fDate, lDate, pDate, depCode, parameters, onLinesChange,
}: Props) {
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const gridRef = useRef<AgGridReact>(null)

  const [itemModalOpen,    setItemModalOpen]    = useState(false)
  const [drawerOpen,       setDrawerOpen]       = useState(false)
  const [drawerItem,       setDrawerItem]       = useState<ItemDetail | null>(null)
  const [drawerLoading,    setDrawerLoading]    = useState(false)
  const [clickedRowIndex,  setClickedRowIndex]  = useState<number | null>(null)

  const isEditable = mode === 'ADD' || mode === 'EDIT'

  const onGridReady = useCallback((_: GridReadyEvent) => {
    // Auto-size columns on load
  }, [])

  // When item code cell is clicked in ADD/EDIT → open modal
  const onCellClicked = useCallback((e: CellClickedEvent<PrLine>) => {
    if (!isEditable) {
      // VIEW: open drawer for any cell
      if (e.data?.itemCode) {
        openDrawer(e.data.itemCode)
      }
      return
    }
    if (e.column.getColId() === 'itemCode') {
      setClickedRowIndex(e.rowIndex ?? null)
      setItemModalOpen(true)
    }
  }, [isEditable])

  const openDrawer = async (itemCode: string) => {
    setDrawerOpen(true)
    setDrawerLoading(true)
    try {
      const detail = await getItemDetail(divCode, itemCode, fDate, lDate, pDate)
      setDrawerItem(detail)
    } catch {
      setDrawerItem(null)
    } finally {
      setDrawerLoading(false)
    }
  }

  const handleItemSelect = useCallback(async (item: ItemLookup) => {
    if (clickedRowIndex === null) return

    // Check for pending order if flag enabled
    if (parameters?.pendingOrderPara === 'Y' && depCode) {
      try {
        const pending = await checkPendingOrder(divCode, fDate, lDate, depCode, item.itemCode)
        if (pending?.pendingQty && pending.pendingQty > 0) {
          Modal.confirm({
            title:   'Pending Order Found',
            content: `Pending Indent Quantity: ${pending.pendingQty.toFixed(3)}. Do you still want to proceed?`,
            okText:  'Proceed',
            cancelText: 'Cancel',
            onOk:    () => applyItemToRow(item, clickedRowIndex),
          })
          return
        }
      } catch {
        // ignore
      }
    }
    await applyItemToRow(item, clickedRowIndex)
  }, [clickedRowIndex, divCode, fDate, lDate, pDate, depCode, parameters, lines])

  const applyItemToRow = async (item: ItemLookup, rowIndex: number) => {
    // Fetch full detail for stock + rates
    let detail: ItemDetail | null = null
    try {
      detail = await getItemDetail(divCode, item.itemCode, fDate, lDate, pDate)
    } catch {
      // use item lookup data as fallback
    }

    const newLines = [...lines]

    // Expand array if clicking beyond current length
    while (newLines.length <= rowIndex) {
      newLines.push(makeEmptyLine(newLines.length + 1))
    }

    const existing = newLines[rowIndex]

    // Duplicate item+machine check
    const dupIdx = newLines.findIndex(
      (l, i) => i !== rowIndex && l.itemCode === item.itemCode && l.macNo === existing.macNo
    )
    if (dupIdx >= 0) {
      notifyError('Same Machine or Same Item should not Be repeat')
      return
    }

    newLines[rowIndex] = {
      ...existing,
      itemCode:  item.itemCode,
      itemName:  item.itemName,
      uom:       item.uom,
      curStock:  detail?.currentStock ?? 0,
      lpoRate:   detail?.lpoRate ?? item.lpoRate ?? 0,
      lpoDate:   detail?.lpoDate ?? item.lpoDate ?? null,
      rate:      detail?.lpoRate ?? item.lpoRate ?? 0,
      rateSource:'LPO',
    }

    // Always add a blank row at end for next entry
    if (rowIndex === newLines.length - 1) {
      newLines.push(makeEmptyLine(newLines.length + 1))
    }

    onLinesChange(newLines)
  }

  const makeEmptyLine = (sno: number): PrLine => ({
    prSno: sno, itemCode: '', itemName: '', uom: '', macNo: '', qtyInd: 0,
    reqdDate: null, rate: 0, lpoRate: 0, lpoDate: null, lpoFrom: '',
    rateSource: 'LPO', rateJustification: '', curStock: 0,
    ccCode: null, catCode: '', bgrpCode: '', appCost: 0, remarks: '', sample: 'N', lineStatus: '',
  })

  const columnDefs: ColDef<PrLine>[] = [
    {
      headerName: '#',
      field:      'prSno',
      width:      50,
      pinned:     'left',
      editable:   false,
      cellStyle:  { color: '#888', fontSize: 11, textAlign: 'center' },
    },
    {
      headerName: 'Item Id',
      field:      'itemCode',
      width:      110,
      pinned:     'left',
      editable:   false,   // modal opens on click
      cellStyle:  (p) => ({
        color:    p.value ? '#185FA5' : '#888',
        cursor:   isEditable ? 'pointer' : 'default',
        fontFamily: 'monospace',
        fontSize: 12,
      }),
    },
    {
      headerName: 'Item Name',
      field:      'itemName',
      flex:       1,
      minWidth:   180,
      editable:   false,
      cellStyle:  { fontSize: 12 },
    },
    {
      headerName: 'UOM',
      field:      'uom',
      width:      65,
      editable:   false,
      cellStyle:  { textAlign: 'center', fontSize: 12 },
    },
    {
      headerName: 'Rate',
      field:      'rate',
      width:      90,
      editable:   isEditable,
      type:       'numericColumn',
      valueFormatter: (p) => p.value != null ? `₹ ${Number(p.value).toFixed(4)}` : '',
      cellStyle:  { fontFamily: 'monospace', fontSize: 12 },
    },
    {
      headerName: 'Current Stock',
      field:      'curStock',
      width:      105,
      editable:   false,
      type:       'numericColumn',
      valueFormatter: (p) => p.value != null ? Number(p.value).toFixed(3) : '',
      cellStyle:  { fontFamily: 'monospace', fontSize: 12 },
    },
    {
      headerName: 'Quantity',
      field:      'qtyInd',
      width:      90,
      editable:   isEditable,
      type:       'numericColumn',
      valueFormatter: (p) => p.value != null && p.value > 0 ? Number(p.value).toFixed(3) : '',
      cellStyle:  { fontFamily: 'monospace', fontSize: 12 },
    },
    {
      headerName: 'Required Date',
      field:      'reqdDate',
      width:      110,
      editable:   isEditable,
      valueFormatter: (p) =>
        p.value ? new Date(p.value).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '',
    },
    {
      headerName: 'Machine No.',
      field:      'macNo',
      width:      95,
      editable:   isEditable,
    },
    {
      headerName: 'Approx Cost',
      field:      'appCost',
      width:      100,
      editable:   isEditable,
      type:       'numericColumn',
      valueFormatter: (p) => p.value != null && p.value > 0 ? `₹ ${Number(p.value).toFixed(2)}` : '',
      cellStyle:  { fontFamily: 'monospace', fontSize: 12 },
    },
    {
      headerName: 'Remarks',
      field:      'remarks',
      width:      150,
      editable:   isEditable,
    },
    {
      headerName: 'LPO Rate',
      field:      'lpoRate',
      width:      95,
      editable:   false,
      type:       'numericColumn',
      valueFormatter: (p) => p.value != null && p.value > 0 ? Number(p.value).toFixed(4) : '—',
      cellStyle:  { color: '#888', fontFamily: 'monospace', fontSize: 11 },
    },
    {
      headerName: 'LPO Date',
      field:      'lpoDate',
      width:      95,
      editable:   false,
      valueFormatter: (p) =>
        p.value ? new Date(p.value).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—',
      cellStyle:  { color: '#888', fontSize: 11 },
    },
  ]

  const onCellValueChanged = useCallback((e: { rowIndex: number; data: PrLine }) => {
    const updated = [...lines]
    updated[e.rowIndex] = e.data
    onLinesChange(updated)
  }, [lines, onLinesChange])

  return (
    <div style={{ position: 'relative' }}>
      <div className="ag-theme-alpine" style={{ height: 320, width: '100%' }}>
        <AgGridReact<PrLine>
          ref={gridRef}
          rowData={lines}
          columnDefs={columnDefs}
          onGridReady={onGridReady}
          onCellClicked={onCellClicked}
          onCellValueChanged={onCellValueChanged as never}
          rowSelection="single"
          animateRows={false}
          suppressMovableColumns
          defaultColDef={{
            resizable:   true,
            sortable:    false,
              editable:    false,
          }}
          getRowStyle={(params) =>
            params.node.rowIndex !== null && params.node.rowIndex % 2 === 0
              ? { background: '#FAFAF8' }
              : undefined
          }
        />
      </div>

      <ItemSelectionModal
        open={itemModalOpen}
        onSelect={handleItemSelect}
        onClose={() => setItemModalOpen(false)}
      />

      <ItemDetailDrawer
        open={drawerOpen}
        item={drawerItem}
        loading={drawerLoading}
        onClose={() => setDrawerOpen(false)}
      />
    </div>
  )
}
