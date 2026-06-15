import { useCallback, useEffect, useRef, useState } from 'react'
import { Alert, Modal, Skeleton, Typography } from 'antd'
import { PageLoader, ApiLoader } from '@/components/common/loading'
import { notifyError, notifySuccess } from '@/shared/lib/notificationHelper'
import {
  CheckOutlined, CloseOutlined, DeleteOutlined,
  DoubleLeftOutlined, DoubleRightOutlined, EditOutlined,
  LeftOutlined, PlusOutlined, PrinterOutlined, RightOutlined, UnorderedListOutlined,
} from '@ant-design/icons'
import { useSearchParams } from 'react-router-dom'
import { usePRFormCore } from '../hooks/usePRFormCore'
import { PRDocBand, TbBtn, TbSep } from '../components/pr-form/PRToolbar'
import type { PRLineItemsTableHandle } from '../components/pr-form/PRLineItemsTable'
import { PRPickerModal } from '../components/pr-form/PRPickerModal'
import { PRHeaderV1 } from '../components/pr-form/PRHeaderV1'
import { PRKPIStrip } from '../components/pr-form/PRKPIStrip'
import { PRLineItemsTable } from '../components/pr-form/PRLineItemsTable'
import PrListModal from '../components/PrListModal'
import { PrPrintPreviewModal } from '../components/PrPrintPreviewModal'
import { getFYBounds } from '@/shared/lib/dateUtils'
import * as prApi from '../api/prApi'
import type { PrSummary } from '../types'
import { usePageTitle } from '@/shared/hooks/usePageTitle'

export default function PurchaseRequisitionPage() {
  usePageTitle('Purchase Requisition')
  const [searchParams] = useSearchParams()

  const {
    headerForm, depCode, reqName, iType, authUser, divCode, processingDate,
    items, setItems,
    savedPrNo, savedPr, prStatus,
    deleting, pageBusy, navLoading,
    preCheckMsg, preCheckLoading, preCheckResult, runPreChecks,
    deleteModalOpen, setDeleteModalOpen,
    departments, employees, prTypes,
    lookupsLoaded, lookupsLoading, lookupsError, loadAll,
    validLines, totalCost, totalQtyDisplay,
    mode, setMode, isDirty, markDirty, clearDirty,
    permissions,
    doSave, handleDeleteClick, handleDeleteConfirm,
    navigateRecord, loadRecord, loadLastRecord, initNewMode,
  } = usePRFormCore()

  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const systemYfDate  = getFYBounds().yfDate
  const isPreviousFY  = !!processingDate && processingDate < systemYfDate

  const [dirtyConfirmOpen, setDirtyConfirmOpen] = useState(false)
  const pendingActionRef   = useRef<(() => void) | null>(null)
  const [pickerMode,       setPickerMode]        = useState<'modify' | 'delete' | null>(null)
  const [findOpen,         setFindOpen]          = useState(false)
  const [isDeleteMode,     setIsDeleteMode]      = useState(false)

  // ── Print preview modal state ─────────────────────────────────────────────
  const lineItemsTableRef = useRef<PRLineItemsTableHandle>(null)

  const [printOpen,        setPrintOpen]         = useState(false)
  const [printLoading,     setPrintLoading]      = useState(false)
  const [printBlobUrl,     setPrintBlobUrl]      = useState<string | null>(null)
  const [printFilename,    setPrintFilename]     = useState('')
  const prevBlobUrlRef     = useRef<string | null>(null)

  // ── Load on mount ─────────────────────────────────────────────────────────
  useEffect(() => {
    const prNoParam   = searchParams.get('prNo')
    const prDateParam = searchParams.get('prDate')
    const modeParam   = searchParams.get('mode')
    if (prNoParam && prDateParam) {
      void (async () => {
        const status = await loadRecord(Number(prNoParam), prDateParam)
        if (modeParam === 'edit' && status) setMode('edit')
        else if (modeParam === 'delete' && status) setIsDeleteMode(true)
      })()
    } else {
      void loadLastRecord()
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Guard dirty ───────────────────────────────────────────────────────────
  const guardDirty = useCallback((action: () => void) => {
    if (isDirty) {
      pendingActionRef.current = action
      setDirtyConfirmOpen(true)
    } else {
      action()
    }
  }, [isDirty])

  const confirmDirtyLeave = () => {
    setDirtyConfirmOpen(false)
    clearDirty()
    pendingActionRef.current?.()
    pendingActionRef.current = null
  }

  // ── Line delete (G12) ─────────────────────────────────────────────────────
  const handleLineDelete = useCallback(async (prSno: number, itemCode: string) => {
    if (!savedPrNo || !savedPr) return
    const wasEditing = mode === 'edit'
    try {
      await prApi.deletePr(divCode, {
        prNo:         savedPrNo,
        prDate:       savedPr.prDate,
        deleteMode:   'LINE',
        prSno,
        deleteReason: null,
      })
      await loadRecord(savedPrNo, savedPr.prDate)
      if (wasEditing) setMode('edit')
      notifySuccess(`Line ${itemCode} deleted.`)
    } catch (err) {
      notifyError(err instanceof Error ? err.message : 'Failed to delete line.')
    }
  }, [divCode, mode, savedPrNo, savedPr, loadRecord, setMode])

  // ── Print (G14) ───────────────────────────────────────────────────────────
  const handlePrint = useCallback(async () => {
    if (!savedPrNo || !savedPr) return
    // Revoke previous blob URL to free memory
    if (prevBlobUrlRef.current) {
      URL.revokeObjectURL(prevBlobUrlRef.current)
      prevBlobUrlRef.current = null
    }
    setPrintBlobUrl(null)
    setPrintLoading(true)
    setPrintOpen(true)
    try {
      const { blobUrl, filename } = await prApi.getPrintBlobUrl(divCode, savedPrNo, savedPr.prDate)
      prevBlobUrlRef.current = blobUrl
      setPrintBlobUrl(blobUrl)
      setPrintFilename(filename)
    } catch (err) {
      setPrintOpen(false)
      notifyError(err instanceof Error ? err.message : 'Failed to generate print.')
    } finally {
      setPrintLoading(false)
    }
  }, [divCode, savedPrNo, savedPr])

  const handlePrintClose = useCallback(() => {
    setPrintOpen(false)
  }, [])

  // ── Add ───────────────────────────────────────────────────────────────────
  const handleAdd = useCallback(async () => {
    const checks = await runPreChecks()
    if (!checks) return
    if (!checks.itemMasterExists) { notifyError('Please Define Item in Item Master'); return }
    if (!checks.deptMasterExists) { notifyError('Please Define Department in Setup'); return }
    if (!checks.docParaExists)    { notifyError('Please Define Document No. for Requisition'); return }
    guardDirty(() => { setIsDeleteMode(false); initNewMode() })
  }, [runPreChecks, guardDirty, initNewMode])

  // ── PR picker select ──────────────────────────────────────────────────────
  const handlePickerSelect = useCallback((prNo: number, prDate: string) => {
    const pm = pickerMode
    setPickerMode(null)
    if (pm === 'modify') {
      void (async () => {
        const status = await loadRecord(prNo, prDate)
        if (!status) return
        setMode('edit')
      })()
    } else {
      void (async () => {
        const status = await loadRecord(prNo, prDate)
        if (!status) return
        setIsDeleteMode(true)
      })()
    }
  }, [pickerMode, loadRecord, setMode])

  // ── Find select (PrListModal) ─────────────────────────────────────────────
  const handleFindSelect = useCallback((summary: PrSummary) => {
    setFindOpen(false)
    void loadRecord(summary.prNo, summary.prDate)
  }, [loadRecord])

  // ── Cancel ────────────────────────────────────────────────────────────────
  const handleCancel = useCallback(() => {
    if (isDeleteMode) { setIsDeleteMode(false); return }
    if (mode === 'edit' && savedPrNo && savedPr) {
      guardDirty(() => void loadRecord(savedPrNo, savedPr.prDate))
    } else {
      guardDirty(() => void loadLastRecord())
    }
  }, [isDeleteMode, mode, savedPrNo, savedPr, guardDirty, loadRecord, loadLastRecord])

  // ── Keyboard shortcuts ────────────────────────────────────────────────────
  const shortcutRef = useRef({
    guardDirty, initNewMode, navigateRecord, handleCancel, handleAdd,
    mode, savedPrNo, pageBusy, handleDeleteClick, isDeleteMode, setPickerMode, setIsDeleteMode, isPreviousFY,
  })
  shortcutRef.current = {
    guardDirty, initNewMode, navigateRecord, handleCancel, handleAdd,
    mode, savedPrNo, pageBusy, handleDeleteClick, isDeleteMode, setPickerMode, setIsDeleteMode, isPreviousFY,
  }

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const s      = shortcutRef.current
      const tag    = (e.target as HTMLElement)?.tagName?.toLowerCase()
      const inInput = tag === 'input' || tag === 'textarea'

      if (e.key === 'F3') {
        e.preventDefault()
        if (!s.isPreviousFY) void s.handleAdd()
        return
      }
      if (e.altKey && e.key === 'x') {
        e.preventDefault()
        s.handleCancel()
        return
      }
      if (e.ctrlKey && !e.shiftKey && !e.altKey) {
        switch (e.key) {
          case 'ArrowLeft':
            if (!inInput && !s.pageBusy && s.mode === 'view') { e.preventDefault(); s.guardDirty(() => { s.setIsDeleteMode(false); void s.navigateRecord('PREV') }) }
            break
          case 'ArrowRight':
            if (!inInput && !s.pageBusy && s.mode === 'view') { e.preventDefault(); s.guardDirty(() => { s.setIsDeleteMode(false); void s.navigateRecord('NEXT') }) }
            break
          case 'Home':
            if (!inInput && !s.pageBusy && s.mode === 'view') { e.preventDefault(); s.guardDirty(() => { s.setIsDeleteMode(false); void s.navigateRecord('FIRST') }) }
            break
          case 'End':
            if (!inInput && !s.pageBusy && s.mode === 'view') { e.preventDefault(); s.guardDirty(() => { s.setIsDeleteMode(false); void s.navigateRecord('LAST') }) }
            break
          case 'd':
            e.preventDefault()
            if (!s.pageBusy) {
              if (s.isDeleteMode && s.mode === 'view' && s.savedPrNo) s.handleDeleteClick()
              else if (s.mode !== 'new' && s.mode !== 'edit') s.setPickerMode('delete')
            }
            break
        }
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Derived ───────────────────────────────────────────────────────────────
  const isEditing      = mode === 'new' || mode === 'edit'
  const formDisabled   = mode === 'view' || pageBusy
  const headerComplete = !!depCode && !!reqName && !!iType
  const gridDisabled   = formDisabled || (isEditing && !headerComplete)
  const depName        = departments.find((d) => d.depCode === depCode)?.depName

  if (lookupsLoading) {
    return <PageLoader toolbarButtons={8} formRows={2} gridRows={8} />
  }

  return (
    <div className="pr-page" style={{ display: 'flex', flexDirection: 'column', height: '100%', background: '#f5f5f3' }}>

      {/* ── Header band ── */}
      <PRDocBand savedPrNo={savedPrNo} prStatus={prStatus} />

      {/* ── Toolbar ── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 3, padding: '5px 16px',
        background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0, flexWrap: 'wrap',
      }}>
        {/* Primary actions */}
        <TbBtn
          variant="primary"
          icon={<PlusOutlined style={{ fontSize: 11 }} />}
          label="New" kbd="F3"
          disabled={isEditing || isDeleteMode || pageBusy || pickerMode !== null || !permissions.canAdd || isPreviousFY}
          title={isPreviousFY ? 'Cannot create a new PR in a previous financial year' : undefined}
          onClick={() => void handleAdd()}
        />
        <TbBtn
          icon={<EditOutlined style={{ fontSize: 11 }} />}
          label="Modify"
          disabled={isEditing || pageBusy || isDeleteMode || !permissions.canModify}
          onClick={() => setPickerMode('modify')}
        />
        <TbBtn
          icon={<UnorderedListOutlined style={{ fontSize: 11 }} />}
          label="Find"
          disabled={isEditing || isDeleteMode}
          onClick={() => setFindOpen(true)}
        />
        <TbSep />
        {/* Delete actions */}
        <TbBtn
          variant="danger"
          icon={<DeleteOutlined style={{ fontSize: 11 }} />}
          label="Delete"
          disabled={pageBusy || isEditing || isDeleteMode || !permissions.canDelete}
          onClick={() => setPickerMode('delete')}
        />
        {isDeleteMode && savedPrNo && (
          <TbBtn
            variant="danger-filled"
            icon={<DeleteOutlined style={{ fontSize: 11 }} />}
            label={`Delete PR-${String(savedPrNo).padStart(5, '0')}`}
            disabled={pageBusy}
            onClick={handleDeleteClick}
          />
        )}
        <TbSep />
        {/* Save / Cancel */}
        <TbBtn
          variant="success"
          icon={<CheckOutlined style={{ fontSize: 11 }} />}
          label="Save" kbd="Ctrl+S"
          disabled={!isEditing || pageBusy}
          onClick={() => void doSave()}
        />
        <TbBtn
          icon={<CloseOutlined style={{ fontSize: 11 }} />}
          label="Cancel" kbd="Alt+X"
          disabled={!isEditing && !isDeleteMode}
          onClick={handleCancel}
        />
        <TbSep />
        {/* Document actions */}
        <TbBtn
          icon={<PrinterOutlined style={{ fontSize: 11 }} />}
          label="Print"
          disabled={isEditing || !savedPrNo || isDeleteMode || pageBusy}
          onClick={() => void handlePrint()}
        />
        {/* Record navigation — far right (matches PO Transfer pattern) */}
        <span style={{ flex: 1 }} />
        <TbBtn variant="icon" icon={<DoubleLeftOutlined style={{ fontSize: 10 }} />}
          disabled={isEditing || pageBusy || isDeleteMode}
          title="First record (Ctrl+Home)"
          onClick={() => guardDirty(() => { setIsDeleteMode(false); void navigateRecord('FIRST') })}
        />
        <TbBtn variant="icon" icon={<LeftOutlined style={{ fontSize: 10 }} />}
          disabled={isEditing || pageBusy || isDeleteMode}
          title="Previous record (Ctrl+←)"
          onClick={() => guardDirty(() => { setIsDeleteMode(false); void navigateRecord('PREV') })}
        />
        <TbBtn variant="icon" icon={<RightOutlined style={{ fontSize: 10 }} />}
          disabled={isEditing || pageBusy || isDeleteMode}
          title="Next record (Ctrl+→)"
          onClick={() => guardDirty(() => { setIsDeleteMode(false); void navigateRecord('NEXT') })}
        />
        <TbBtn variant="icon" icon={<DoubleRightOutlined style={{ fontSize: 10 }} />}
          disabled={isEditing || pageBusy || isDeleteMode}
          title="Last record (Ctrl+End)"
          onClick={() => guardDirty(() => { setIsDeleteMode(false); void navigateRecord('LAST') })}
        />
      </div>

      {/* ── Status bars ── */}
      {navLoading && <ApiLoader message="Loading record…" />}
      {lookupsError && (
        <Alert type="error" showIcon banner message={lookupsError}
          action={<span style={{ fontSize: 12, color: '#185FA5', cursor: 'pointer' }} onClick={() => void loadAll()}>Retry</span>}
        />
      )}
      {preCheckMsg && <Alert type="warning" showIcon banner message={preCheckMsg} />}
      {preCheckLoading && <ApiLoader message="Running pre-checks…" />}
      {mode === 'new' && (
        <div style={{ background: '#E6F1FB', borderBottom: '2px solid #185FA5', padding: '5px 16px', fontSize: 11, color: '#185FA5', fontWeight: 600, flexShrink: 0 }}>
          ADD MODE — Fill in the header fields and add item lines, then save to generate the PR.
        </div>
      )}
      {mode === 'edit' && (
        <div style={{ background: '#fffbf0', borderBottom: '2px solid #BA7517', padding: '5px 16px', fontSize: 11, color: '#BA7517', fontWeight: 600, flexShrink: 0 }}>
          EDIT MODE — Modify the PR lines and save to apply changes.
        </div>
      )}
      {isDeleteMode && savedPrNo && (
        <div style={{
          background: '#FCEBEB', borderBottom: '2px solid #A32D2D',
          padding: '6px 16px', color: '#A32D2D', fontWeight: 500, fontSize: 12, flexShrink: 0,
        }}>
          Delete mode — PR-{String(savedPrNo).padStart(5, '0')} · Click the red Delete button in the toolbar to confirm.
        </div>
      )}

      {/* ── Header form ── */}
      <Skeleton active loading={!lookupsLoaded && !lookupsError}>
        <PRHeaderV1
          form={headerForm}
          departments={departments}
          employees={employees}
          prTypes={prTypes}
          savedPrNo={savedPrNo}
          disabled={formDisabled}
          createdBy={savedPr?.createdBy ?? authUser?.userName ?? null}
          maxPrDate={preCheckResult?.maxPrDate ?? null}
          isNewMode={mode === 'new'}
          prDateDisabled={mode === 'edit'}
          onValuesChange={markDirty}
          onTabToGrid={!gridDisabled && depCode ? () => lineItemsTableRef.current?.openPicker() : undefined}
        />
      </Skeleton>

      {/* ── Item grid (flex-fill) ── */}
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        <PRLineItemsTable
          ref={lineItemsTableRef}
          items={items}
          divCode={divCode}
          depCode={depCode}
          depName={depName}
          prDate={headerForm.getFieldValue('prDate')?.format('YYYY-MM-DD')}
          disabled={gridDisabled}
          savedPrNo={savedPrNo ?? undefined}
          emptyText={
            isEditing && !headerComplete
              ? 'Fill in Department, Requested By, and Requisition Type to add items.'
              : undefined
          }
          onAdd={(item) => {
            markDirty()
            setItems((prev) => [...prev, item])
          }}
          onUpdate={(updated) => {
            markDirty()
            setItems((prev) => prev.map((l) => l.key === updated.key ? updated : l))
          }}
          onDelete={(key) => {
            markDirty()
            setItems((prev) => prev.filter((l) => l.key !== key))
          }}
          onLineDelete={handleLineDelete}
        />
      </div>

      {/* ── KPI strip ── */}
      <PRKPIStrip
        validLinesCount={validLines.length}
        totalQtyDisplay={totalQtyDisplay}
        totalCost={totalCost}
        prDate={savedPr?.prDate ?? null}
        prStatus={prStatus}
        savedPrNo={savedPrNo}
        isNewMode={mode === 'new'}
        hideApprovalStatus={mode === 'edit' || isDeleteMode}
        cancelReason={savedPr?.cancelReason}
      />

      {/* ── Unsaved-changes confirmation ── */}
      <Modal
        title="Unsaved Changes"
        open={dirtyConfirmOpen}
        onOk={confirmDirtyLeave}
        onCancel={() => { setDirtyConfirmOpen(false); pendingActionRef.current = null }}
        okText="Leave without saving"
        cancelText="Stay"
        width={400}
        destroyOnClose
      >
        <Typography.Text>You have unsaved changes. Leave without saving?</Typography.Text>
      </Modal>

      {/* ── PR Picker (Modify / Delete) ── */}
      {pickerMode && (
        <PRPickerModal
          open={pickerMode !== null}
          mode={pickerMode}
          onSelect={handlePickerSelect}
          onCancel={() => setPickerMode(null)}
        />
      )}

      {/* ── Find (PrListModal — existing V2 component) ── */}
      <PrListModal
        open={findOpen}
        mode="VIEW"
        fDate={yfDate}
        lDate={ylDate}
        onSelect={handleFindSelect}
        onClose={() => setFindOpen(false)}
      />

      {/* ── Print Preview ── */}
      <PrPrintPreviewModal
        open={printOpen}
        blobUrl={printBlobUrl}
        filename={printFilename}
        loading={printLoading}
        onClose={handlePrintClose}
      />

      {/* ── Delete confirmation ── */}
      <Modal
        title={<span><DeleteOutlined style={{ color: '#dc2626', marginRight: 8 }} />Delete Purchase Requisition</span>}
        open={deleteModalOpen}
        onCancel={() => setDeleteModalOpen(false)}
        onOk={() => void (async () => {
          setIsDeleteMode(false)
          const ok = await handleDeleteConfirm()
          if (!ok) setIsDeleteMode(true)
        })()}
        okText="Confirm Delete"
        okButtonProps={{ danger: true }}
        confirmLoading={deleting}
        width={420}
        destroyOnClose
      >
        <Typography.Paragraph style={{ color: '#374151', marginBottom: 0 }}>
          You are about to permanently delete{' '}
          <Typography.Text strong>PR-{String(savedPrNo).padStart(5, '0')}</Typography.Text>.
          This action cannot be undone.
        </Typography.Paragraph>
      </Modal>
    </div>
  )
}
