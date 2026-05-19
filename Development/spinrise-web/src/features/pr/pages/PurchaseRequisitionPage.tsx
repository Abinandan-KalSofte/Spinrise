import { useEffect, useState, useMemo } from 'react'
import { Button, Form, Divider, message, Modal, Spin, Tooltip, Space, Typography } from 'antd'
import {
  PlusOutlined, EditOutlined, DeleteOutlined,
  SearchOutlined, SaveOutlined, CloseOutlined, PrinterOutlined,
} from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import type { PrLine, PrSummary } from '../types'
import { usePrStore } from '../store/usePrStore'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import {
  getParameters, runPreAddChecks, getLastRecord, getById,
  addPr, modifyPr, deletePr,
} from '../api/prApi'
import PrHeaderForm from '../components/PrHeaderForm'
import PrItemGrid from '../components/PrItemGrid'
import PrKpiStrip from '../components/PrKpiStrip'
import PrStatusBadge from '../components/PrStatusBadge'
import PrListModal from '../components/PrListModal'

const { Text } = Typography

// Financial year helpers — April-March
const getFY = (today: Dayjs) => {
  const yr = today.month() >= 3 ? today.year() : today.year() - 1
  return {
    fDate: dayjs(`${yr}-04-01`).format('YYYY-MM-DD'),
    lDate: dayjs(`${yr + 1}-03-31`).format('YYYY-MM-DD'),
  }
}

export default function PurchaseRequisitionPage() {
  const [form] = Form.useForm()
  const user   = useAuthStore((s) => s.user)
  const store  = usePrStore()

  const pDate  = dayjs()
  const { fDate, lDate } = useMemo(() => getFY(pDate), [])
  const divCode = user?.divCode ?? ''

  const [listModal, setListModal] = useState<false | 'VIEW' | 'EDIT' | 'DELETE'>(false)
  const [draftLines, setDraftLines] = useState<PrLine[]>([])

  // ── Screen boot ────────────────────────────────────────────────────────────
  useEffect(() => {
    void boot()
  }, [divCode])

  const boot = async () => {
    if (!divCode) return
    store.setLoading(true)
    try {
      // Load parameters
      const params = await getParameters(divCode)
      if (params) store.setParameters(params)

      // Load last PR record
      const last = await getLastRecord(divCode, fDate, lDate)
      store.setCurrentPr(last)
      store.setMode('VIEW')
    } catch {
      // handled by interceptor
    } finally {
      store.setLoading(false)
    }
  }

  // ── Add (F3 / Add button) ──────────────────────────────────────────────────
  const handleAdd = async () => {
    store.setLoading(true)
    try {
      const checks = await runPreAddChecks(divCode)
      if (!checks.itemMasterExists) { void message.error('Please Define Item in Item Master'); return }
      if (!checks.deptMasterExists) { void message.error('Please Define Department in Setup'); return }
      if (!checks.docParaExists)    { void message.error('Please Define Document No. for Requisition in Housekeeping'); return }

      // Backdate check
      if (checks.backDateFlag === 'N' && checks.maxPrDate) {
        const maxDate = dayjs(checks.maxPrDate)
        if (pDate.isBefore(maxDate, 'day')) {
          void message.error('Date should be Equal to Current Date Or Max PR. Date')
          return
        }
      }

      store.setMode('ADD')
      setDraftLines([makeEmptyLine(1)])
    } finally {
      store.setLoading(false)
    }
  }

  // ── Modify ─────────────────────────────────────────────────────────────────
  const handleModifySelect = async (summary: PrSummary) => {
    store.setLoading(true)
    try {
      const pr = await getById(divCode, summary.prNo, summary.prDate)
      store.setCurrentPr(pr)
      setDraftLines([...pr.lines, makeEmptyLine(pr.lines.length + 1)])
      store.setMode('EDIT')
    } finally {
      store.setLoading(false)
    }
  }

  // ── Delete selection ───────────────────────────────────────────────────────
  const handleDeleteSelect = async (summary: PrSummary) => {
    store.setLoading(true)
    try {
      const pr = await getById(divCode, summary.prNo, summary.prDate)
      store.setCurrentPr(pr)
      store.setMode('DELETE')
    } finally {
      store.setLoading(false)
    }
  }

  // ── Find ───────────────────────────────────────────────────────────────────
  const handleFindSelect = async (summary: PrSummary) => {
    store.setLoading(true)
    try {
      const pr = await getById(divCode, summary.prNo, summary.prDate)
      store.setCurrentPr(pr)
      store.setMode('VIEW')
    } finally {
      store.setLoading(false)
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  const handleSave = async () => {
    try {
      await form.validateFields()
    } catch {
      return
    }

    const values = form.getFieldsValue()
    const validLines = draftLines.filter((l) => l.itemCode.trim() !== '')

    if (validLines.length === 0) {
      void message.error('Purchase Requisition Requires at least one Item')
      return
    }

    store.setSaving(true)
    try {
      const request = {
        prDate:         values.prDate?.format('YYYY-MM-DD') ?? pDate.format('YYYY-MM-DD'),
        depCode:        values.depCode,
        reqName:        values.reqName ?? null,
        section:        values.section ?? null,
        iType:          values.iType ?? null,
        refNo:          values.refNo ?? null,
        poGrp:          values.poGrp ?? null,
        existingPrNo:   store.mode === 'EDIT' ? (store.currentPr?.prNo ?? null) : null,
        existingPrDate: store.mode === 'EDIT' ? (store.currentPr?.prDate ?? null) : null,
        lines: validLines.map((l) => ({
          itemCode:          l.itemCode,
          macNo:             l.macNo,
          qtyInd:            l.qtyInd,
          reqdDate:          l.reqdDate,
          rate:              l.rate,
          lpoRate:           l.lpoRate,
          lpoDate:           l.lpoDate,
          lpoFrom:           l.lpoFrom,
          rateSource:        l.rateSource,
          rateJustification: l.rateJustification,
          curStock:          l.curStock,
          ccCode:            l.ccCode,
          catCode:           l.catCode,
          bgrpCode:          l.bgrpCode,
          appCost:           l.appCost,
          remarks:           l.remarks,
          sample:            l.sample,
        })),
      }

      let result: { prNo: number }
      if (store.mode === 'ADD') {
        result = await addPr(divCode, fDate, lDate, request)
      } else {
        result = await modifyPr(divCode, fDate, lDate, request)
      }

      void message.success(`PR No. for your transaction is ${result.prNo}`)

      // Reload the saved PR
      const saved = await getById(divCode, result.prNo, request.prDate)
      store.setCurrentPr(saved)
      store.resetToView()
      setDraftLines([])
    } catch {
      // handled by interceptor
    } finally {
      store.setSaving(false)
    }
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────
  const handleCancel = () => {
    form.resetFields()
    setDraftLines([])
    store.resetToView()
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────
  const handleDeleteConfirm = () => {
    if (!store.currentPr) return
    Modal.confirm({
      title:   'Confirm Delete',
      content: `Delete entire PR No. ${store.currentPr.prNo}? This cannot be undone.`,
      okText:  'Delete',
      okButtonProps: { danger: true },
      onOk:    async () => {
        try {
          await deletePr(divCode, {
            prNo:         store.currentPr!.prNo,
            prDate:       store.currentPr!.prDate,
            deleteMode:   'FULL',
            prSno:        null,
            deleteReason: null,
          })
          void message.success('PR deleted successfully.')
          store.setCurrentPr(null)
          store.resetToView()
        } catch {
          // handled by interceptor
        }
      },
    })
  }

  const makeEmptyLine = (sno: number): PrLine => ({
    prSno: sno, itemCode: '', itemName: '', uom: '', macNo: '', qtyInd: 0,
    reqdDate: null, rate: 0, lpoRate: 0, lpoDate: null, lpoFrom: '',
    rateSource: 'LPO', rateJustification: '', curStock: 0,
    ccCode: null, catCode: '', bgrpCode: '', appCost: 0, remarks: '', sample: 'N', lineStatus: '',
  })

  const isEditingMode = store.mode === 'ADD' || store.mode === 'EDIT'
  const isDeleteMode  = store.mode === 'DELETE'
  const gridLines     = isEditingMode ? draftLines : (store.currentPr?.lines ?? [])

  // KPI draft quantities
  const draftQtyGroups = useMemo(() => {
    const map: Record<string, number> = {}
    draftLines.filter((l) => l.itemCode).forEach((l) => {
      map[l.uom] = (map[l.uom] ?? 0) + l.qtyInd
    })
    return Object.entries(map).map(([uom, qty]) => ({ uom, qty }))
  }, [draftLines])

  // ── Keyboard shortcuts ─────────────────────────────────────────────────────
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey) {
        if (e.key === 'a' || e.key === 'A') { e.preventDefault(); if (!isEditingMode) void handleAdd() }
        if (e.key === 's' || e.key === 'S') { e.preventDefault(); if (isEditingMode) void handleSave() }
        if (e.key === 'Backspace')           { e.preventDefault(); if (isEditingMode) handleCancel() }
        if (e.key === 'm' || e.key === 'M') { e.preventDefault(); if (!isEditingMode) setListModal('EDIT') }
        if (e.key === 'd' || e.key === 'D') { e.preventDefault(); if (!isEditingMode) setListModal('DELETE') }
        if (e.key === 'f' || e.key === 'F') { e.preventDefault(); if (!isEditingMode) setListModal('VIEW') }
      }
      if (e.key === 'F3') { e.preventDefault(); if (!isEditingMode) void handleAdd() }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [isEditingMode])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', padding: '12px 16px', gap: 10, overflow: 'hidden' }}>

      {/* ── Toolbar ── */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, borderBottom: '1px solid #E2E2E2', paddingBottom: 10 }}>
        <Text style={{ fontWeight: 700, fontSize: 15, color: '#0C447C', marginRight: 8 }}>
          Purchase Requisition
        </Text>

        {store.currentPr && store.mode === 'VIEW' && (
          <Text style={{ fontSize: 12, color: '#888', marginRight: 12 }}>
            PR No. <strong style={{ color: '#185FA5' }}>{store.currentPr.prNo}</strong>
            &nbsp;·&nbsp;
            {dayjs(store.currentPr.prDate).format('DD/MM/YYYY')}
            &nbsp;·&nbsp;
            <PrStatusBadge status={store.currentPr.prStatus} />
          </Text>
        )}

        <Space wrap>
          <Tooltip title="Add (Ctrl+A / F3)">
            <Button
              icon={<PlusOutlined />}
              type="primary"
              disabled={isEditingMode}
              onClick={() => void handleAdd()}
            >
              Add
            </Button>
          </Tooltip>

          <Tooltip title="Modify (Ctrl+M)">
            <Button
              icon={<EditOutlined />}
              disabled={isEditingMode}
              onClick={() => setListModal('EDIT')}
            >
              Modify
            </Button>
          </Tooltip>

          <Tooltip title="Delete (Ctrl+D)">
            <Button
              icon={<DeleteOutlined />}
              danger
              disabled={isEditingMode}
              onClick={() => setListModal('DELETE')}
            >
              Delete
            </Button>
          </Tooltip>

          <Tooltip title="Find (Ctrl+F)">
            <Button
              icon={<SearchOutlined />}
              disabled={isEditingMode}
              onClick={() => setListModal('VIEW')}
            >
              Find
            </Button>
          </Tooltip>

          <Divider type="vertical" />

          <Tooltip title="Save (Ctrl+S)">
            <Button
              icon={<SaveOutlined />}
              type="primary"
              disabled={!isEditingMode && !isDeleteMode}
              loading={store.saving}
              onClick={isDeleteMode ? handleDeleteConfirm : () => void handleSave()}
            >
              Save
            </Button>
          </Tooltip>

          <Tooltip title="Cancel (Ctrl+Backspace)">
            <Button
              icon={<CloseOutlined />}
              disabled={!isEditingMode && !isDeleteMode}
              onClick={handleCancel}
            >
              Cancel
            </Button>
          </Tooltip>

          <Divider type="vertical" />

          <Tooltip title="Print (Ctrl+Y)">
            <Button icon={<PrinterOutlined />} disabled={!store.currentPr || isEditingMode}>
              Print
            </Button>
          </Tooltip>
        </Space>
      </div>

      {/* ── Header form ── */}
      <div style={{ background: '#ffffff', border: '1px solid #E2E2E2', borderRadius: 8, padding: '12px 16px' }}>
        <Spin spinning={store.loading} size="small">
          <PrHeaderForm
            mode={store.mode}
            parameters={store.parameters}
            initialPr={store.currentPr}
            form={form}
            pDate={pDate}
          />
        </Spin>
      </div>

      {/* ── Delete mode info panel ── */}
      {isDeleteMode && store.currentPr && (
        <div style={{
          background: '#FCEBEB', border: '1px solid #A32D2D', borderRadius: 8,
          padding: '10px 16px', color: '#A32D2D', fontWeight: 500, fontSize: 13,
        }}>
          You are about to delete PR No. {store.currentPr.prNo}.
          Click Save to confirm deletion, or Cancel to abort.
        </div>
      )}

      {/* ── Item grid ── */}
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <Spin spinning={store.loading} size="small">
          <PrItemGrid
            mode={store.mode}
            lines={gridLines}
            fDate={fDate}
            lDate={lDate}
            pDate={pDate.format('YYYY-MM-DD')}
            depCode={form.getFieldValue('depCode') ?? ''}
            parameters={store.parameters}
            onLinesChange={setDraftLines}
          />
        </Spin>
      </div>

      {/* ── KPI Strip ── */}
      <div>
        <PrKpiStrip
          pr={store.currentPr}
          mode={store.mode}
          draftLineCount={draftLines.filter((l) => l.itemCode).length}
          draftTotalQty={draftQtyGroups}
        />
      </div>

      {/* ── Modals ── */}
      {listModal === 'VIEW' && (
        <PrListModal
          open
          mode="VIEW"
          fDate={fDate}
          lDate={lDate}
          onSelect={handleFindSelect}
          onClose={() => setListModal(false)}
        />
      )}
      {listModal === 'EDIT' && (
        <PrListModal
          open
          mode="EDIT"
          fDate={fDate}
          lDate={lDate}
          onSelect={handleModifySelect}
          onClose={() => setListModal(false)}
        />
      )}
      {listModal === 'DELETE' && (
        <PrListModal
          open
          mode="DELETE"
          fDate={fDate}
          lDate={lDate}
          onSelect={handleDeleteSelect}
          onClose={() => setListModal(false)}
        />
      )}
    </div>
  )
}
