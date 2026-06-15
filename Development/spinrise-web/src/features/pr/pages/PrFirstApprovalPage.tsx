import { useEffect, useState, useCallback, useRef } from 'react'
import { Button, Modal, Spin, Alert } from 'antd'
import { notifyError } from '@/shared/lib/notificationHelper'
import {
  CheckOutlined, CloseOutlined, DeleteOutlined,
  DoubleLeftOutlined, DoubleRightOutlined, LeftOutlined,
  PrinterOutlined, RightOutlined, SearchOutlined, UnorderedListOutlined,
} from '@ant-design/icons'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { usePrFirstApprovalStore } from '../store/usePrFirstApprovalStore'
import { prFirstApprovalApi } from '../api/prFirstApprovalApi'
import { PRDocBand, TbBtn, TbSep } from '../components/pr-form/PRToolbar'
import PrApprovalDeptModal    from '../components/first-approval/PrApprovalDeptModal'
import PrApprovalLookupModal  from '../components/first-approval/PrApprovalLookupModal'
import PrApprovalHeader       from '../components/first-approval/PrApprovalHeader'
import PrApprovalGrid         from '../components/first-approval/PrApprovalGrid'
import PrApprovalFooter       from '../components/first-approval/PrApprovalFooter'
import { PrPrintPreviewModal } from '../components/PrPrintPreviewModal'
import type { ApprovalDept, PrApprovalSummary } from '../types/prFirstApprovalTypes'
import dayjs from 'dayjs'
import { usePageTitle } from '@/shared/hooks/usePageTitle'

type LookupMode = 'APPROVE' | 'DELETE' | 'FIND'

export default function PrFirstApprovalPage() {
  usePageTitle('First Level PR Approval')
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const {
    mode, poPara, yfDate, ylDate, depts, pendingList, approvedList,
    detail, lines, loading, saving,
    loadPoPara, loadDepts, loadPendingList, loadApprovedList,
    loadDetail, approve, deleteApproval, reset, softReset,
  } = usePrFirstApprovalStore()

  // ── Modal visibility state ─────────────────────────────────────────────────
  const [deptModalOpen,   setDeptModalOpen]   = useState(false)
  const [lookupOpen,      setLookupOpen]      = useState(false)
  const [lookupMode,      setLookupMode]      = useState<LookupMode>('APPROVE')
  const [selectedDept,    setSelectedDept]    = useState<ApprovalDept | null>(null)
  const [confirmSave,     setConfirmSave]     = useState(false)
  const [confirmDelete,   setConfirmDelete]   = useState(false)
  const [cancelConfirm,   setCancelConfirm]   = useState(false)
  const [appDate,         setAppDate]         = useState(dayjs().format('YYYY-MM-DD'))
  const [printOpen,       setPrintOpen]       = useState(false)
  const [printLoading,    setPrintLoading]    = useState(false)
  const [printBlobUrl,    setPrintBlobUrl]    = useState<string | null>(null)
  const [printFilename,   setPrintFilename]   = useState('')
  const prevBlobUrlRef = useRef<string | null>(null)

  // ── Navigation state (approved PRs list for First/Prev/Next/Last) ──────────
  const [navList,  setNavList]  = useState<PrApprovalSummary[]>([])
  const [navIndex, setNavIndex] = useState(-1)

  // ── Load latest approved record (reused on page mount and after delete) ──────
  const loadLatestApproved = useCallback(async () => {
    const { yfDate: yf, ylDate: yl } = usePrFirstApprovalStore.getState()
    if (!yf || !yl) return
    try {
      const list    = await prFirstApprovalApi.getApprovedList(divCode, yf, yl)
      const ordered = [...list].reverse()   // index 0 = oldest, last = newest
      setNavList(ordered)
      if (ordered.length > 0) {
        const latest = ordered[ordered.length - 1]
        setNavIndex(ordered.length - 1)
        await loadDetail(divCode, latest.prNo, latest.prDate, 'SAVED')
      } else {
        setNavList([])
        setNavIndex(-1)
      }
    } catch {
      setNavList([])
      setNavIndex(-1)
    }
  }, [divCode, loadDetail])

  // ── Page load — po-para first (provides yfDate/ylDate), then latest record ──
  useEffect(() => {
    if (!divCode) return
    void (async () => {
      await loadPoPara(divCode)
      await loadLatestApproved()
    })()
  }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Keyboard shortcuts ─────────────────────────────────────────────────────
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === 's') { e.preventDefault(); if (mode === 'APPROVE' || mode === 'DELETE') setConfirmSave(true) }
      if (e.altKey  && e.key === 'x') { e.preventDefault(); if (mode === 'APPROVE' || mode === 'DELETE') handleCancelClick() }
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [mode, reset])

  // ── Toolbar handlers ───────────────────────────────────────────────────────

  const handleLoadPRs = () => {
    void loadDepts(divCode)
    setDeptModalOpen(true)
  }

  const handleDeptSelected = async (dept: ApprovalDept) => {
    setSelectedDept(dept)
    setDeptModalOpen(false)
    await loadPendingList(divCode, dept.depCode)
    setLookupMode('APPROVE')
    setLookupOpen(true)
  }

  const handleEnterDelete = async () => {
    await loadApprovedList(divCode)
    setLookupMode('DELETE')
    setLookupOpen(true)
  }

  const handleFind = async () => {
    await loadApprovedList(divCode)
    setLookupMode('FIND')
    setLookupOpen(true)
  }

  const handlePRSelected = async (pr: PrApprovalSummary) => {
    setLookupOpen(false)
    const loadMode = lookupMode === 'APPROVE' ? 'APPROVE' : lookupMode === 'DELETE' ? 'DELETE' : 'SAVED'
    await loadDetail(divCode, pr.prNo, pr.prDate, loadMode)
    setAppDate(dayjs().format('YYYY-MM-DD'))
  }

  // ── Navigation helpers ──���──────────────────────────────────────────────────
  const goToIndex = useCallback(async (idx: number) => {
    if (idx < 0 || idx >= navList.length) return
    setNavIndex(idx)
    const pr = navList[idx]
    await loadDetail(divCode, pr.prNo, pr.prDate, 'SAVED')
  }, [navList, divCode, loadDetail])

  const handleFirst = useCallback(() => void goToIndex(0),                     [goToIndex])
  const handlePrev  = useCallback(() => void goToIndex(navIndex - 1),          [goToIndex, navIndex])
  const handleNext  = useCallback(() => void goToIndex(navIndex + 1),          [goToIndex, navIndex])
  const handleLast  = useCallback(() => void goToIndex(navList.length - 1),    [goToIndex, navList.length])

  const navDisabled = mode !== 'SAVED' || navList.length === 0

  // ── Save / Delete handlers ──────────────────────────��──────────────────────
  const handleSaveClick = () => {
    if (mode === 'DELETE') { setConfirmDelete(true); return }
    setConfirmSave(true)
  }

  const handleConfirmSave = async () => {
    setConfirmSave(false)
    await approve(divCode, appDate)
    // Refresh nav list so newly approved PR appears in navigation
    try {
      const fresh = await prFirstApprovalApi.getApprovedList(divCode, yfDate, ylDate)
      const ordered = [...fresh].reverse()
      setNavList(ordered)
      const currentPrNo = detail?.header.prNo
      const idx = ordered.findIndex((p) => p.prNo === currentPrNo)
      setNavIndex(idx >= 0 ? idx : ordered.length - 1)
    } catch { /* non-critical */ }
  }

  const handleConfirmDelete = async () => {
    setConfirmDelete(false)
    await deleteApproval(divCode)
    await loadLatestApproved()
  }

  const handlePrint = useCallback(async () => {
    if (!detail) return
    if (prevBlobUrlRef.current) {
      URL.revokeObjectURL(prevBlobUrlRef.current)
      prevBlobUrlRef.current = null
    }
    setPrintBlobUrl(null)
    setPrintLoading(true)
    setPrintOpen(true)
    try {
      const { blobUrl, filename } = await prFirstApprovalApi.getPrintBlobUrl(
        divCode, detail.header.prNo, detail.header.prDate
      )
      prevBlobUrlRef.current = blobUrl
      setPrintBlobUrl(blobUrl)
      setPrintFilename(filename)
    } catch (err) {
      setPrintOpen(false)
      notifyError(err instanceof Error ? err.message : 'Failed to generate print.')
    } finally {
      setPrintLoading(false)
    }
  }, [divCode, detail])

  // ── Button states ──────────────────────────────────────────────────────────
  const hasDetail  = !!detail
  const saveLabel  = mode === 'DELETE' ? 'Confirm Delete' : 'Save'
  const saveDanger = mode === 'DELETE'

  const selectedCount = lines.filter((l) => l.selected).length

  const isDirty = mode === 'APPROVE' && lines.some(
    (l) => l.selected || l.editFirstAppQty !== l.firstAppQty || l.editRate !== l.rate
  )

  const performCancel = useCallback(async () => {
    softReset()
    await loadLatestApproved()
  }, [softReset, loadLatestApproved])

  const handleCancelClick = useCallback(() => {
    if (isDirty) { setCancelConfirm(true); return }
    void performCancel()
  }, [isDirty, performCancel])

  const lookupTitle    = lookupMode === 'APPROVE' ? 'Select PR — Load for First Level Approval'
    : lookupMode === 'DELETE'  ? 'Select PR — Delete First Level Approval'
    : 'Find PR — First Level Approved'

  const lookupSubtitle = lookupMode === 'APPROVE'
    ? `Filtered by ${selectedDept?.depName ?? ''} · sp_PR_GetPendingFirstApproval`
    : 'Showing First Level Approved PRs (sp_PR_GetFirstApprovedForDeletion)'

  const lookupList = lookupMode === 'APPROVE' ? pendingList : approvedList

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>

      {/* ── Doc Band ──────────────────────────────────────────────────────────── */}
      <PRDocBand
        breadcrumb={['Purchase Order', 'PR First Level Approval']}
        subLabel="PR No."
        subValue={detail?.header.prNo != null ? String(detail.header.prNo) : undefined}
      />

      {/* ── Toolbar ───────────────────────────────────────────────────────────── */}
      <div style={{
        background: '#fff', borderBottom: '1px solid #e2e2e2',
        display: 'flex', alignItems: 'center', gap: 4,
        padding: '0 12px', height: 44, flexShrink: 0,
      }}>
        <TbBtn
          variant="primary"
          icon={<UnorderedListOutlined style={{ fontSize: 11 }} />}
          label="Load PRs"
          disabled={mode === 'APPROVE' || mode === 'DELETE'}
          onClick={handleLoadPRs}
        />
        <TbBtn
          variant="danger"
          icon={<DeleteOutlined style={{ fontSize: 11 }} />}
          label="Delete"
          disabled={mode === 'APPROVE' || mode === 'DELETE'}
          onClick={handleEnterDelete}
        />
        <TbBtn
          icon={<SearchOutlined style={{ fontSize: 11 }} />}
          label="Find"
          disabled={mode === 'APPROVE' || mode === 'DELETE'}
          onClick={handleFind}
        />
        <TbSep />
        <TbBtn variant="icon" icon={<DoubleLeftOutlined  style={{ fontSize: 10 }} />}
          disabled={navDisabled || navIndex <= 0}
          title="First record" onClick={handleFirst} />
        <TbBtn variant="icon" icon={<LeftOutlined        style={{ fontSize: 10 }} />}
          disabled={navDisabled || navIndex <= 0}
          title="Previous record" onClick={handlePrev} />
        <TbBtn variant="icon" icon={<RightOutlined       style={{ fontSize: 10 }} />}
          disabled={navDisabled || navIndex >= navList.length - 1}
          title="Next record" onClick={handleNext} />
        <TbBtn variant="icon" icon={<DoubleRightOutlined style={{ fontSize: 10 }} />}
          disabled={navDisabled || navIndex >= navList.length - 1}
          title="Last record" onClick={handleLast} />
        <TbSep />
        <TbBtn
          variant={saveDanger ? 'danger-filled' : 'success'}
          icon={saveDanger ? <DeleteOutlined style={{ fontSize: 11 }} /> : <CheckOutlined style={{ fontSize: 11 }} />}
          label={saveLabel} kbd="Ctrl+S"
          disabled={!hasDetail || mode === 'SAVED' || mode === 'QUERY' || saving}
          onClick={handleSaveClick}
        />
        <TbBtn
          icon={<PrinterOutlined style={{ fontSize: 11 }} />}
          label="Print"
          disabled={mode !== 'SAVED' || !hasDetail || printLoading}
          onClick={() => void handlePrint()}
        />
        <TbBtn
          icon={<CloseOutlined style={{ fontSize: 11 }} />}
          label="Cancel" kbd="Alt+X"
          disabled={mode === 'QUERY' || mode === 'SAVED'}
          onClick={handleCancelClick}
        />
      </div>

      {/* ── Delete mode banner ─────────────────────────────────────────────────── */}
      {mode === 'DELETE' && detail && (
        <Alert
          type="error"
          banner
          message={
            <span>
              ⚠ Delete Approval Mode — Undoing First Level Approval for PR{' '}
              <strong>{detail.header.prNo}</strong>.
              This will reset all approval fields and PRSTATUS → Requested. <em>(OI-07 HELD: header-level reset)</em>
            </span>
          }
          style={{ flexShrink: 0 }}
        />
      )}

      {/* ── APPROVE mode hint ──────────────────────────────────────────────────── */}
      {mode === 'APPROVE' && (
        <div style={{ padding: '4px 16px', background: '#FFF8E1', borderBottom: '1px solid #ffe082', fontSize: 11, color: '#7a5f00', flexShrink: 0 }}>
          Editable: First Approval Quantity · Rate (auto-calculates Approx. Value) — select rows then Save
        </div>
      )}

      {/* ── Header form ───────────────────────────────────────────────────────── */}
      <PrApprovalHeader
        header={detail?.header ?? null}
        poPara={poPara}
        mode={mode}
        appDate={appDate}
        onAppDateChange={setAppDate}
      />

      {/* ── Grid section ──────────────────────────────────────────────────────── */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: '#fff' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '8px 16px', borderBottom: '1px solid #f0f0f0',
          background: '#FAFAF8', flexShrink: 0,
        }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: '#4a4a4a' }}>PR Line Items</span>
          <span style={{
            fontSize: 11, fontWeight: 700, padding: '2px 8px',
            borderRadius: 20, background: '#E6F1FB', color: '#185FA5',
          }}>
            {lines.length} item{lines.length !== 1 ? 's' : ''}
          </span>
          {mode === 'APPROVE' && selectedCount > 0 && (
            <span style={{ fontSize: 11, color: '#185FA5' }}>
              {selectedCount} selected
            </span>
          )}
        </div>

        {!hasDetail && !loading ? (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 48, gap: 10 }}>
            <div style={{ fontSize: 36, opacity: 0.3 }}>📋</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#888' }}>No PR Selected</div>
            <div style={{ fontSize: 12, color: '#aaa', textAlign: 'center', maxWidth: 400, lineHeight: 1.7 }}>
              Click <strong>Load PRs</strong> to select a pending Purchase Requisition for First Level Approval,
              or <strong>Delete</strong> to undo an existing First Level Approval.
            </div>
          </div>
        ) : loading ? (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Spin size="large" />
          </div>
        ) : (
          <PrApprovalGrid lines={lines} mode={mode} />
        )}
      </div>

      {/* ── Footer summary ─────────────────────────────────────────────────────── */}
      {hasDetail && (
        <PrApprovalFooter
          lines={lines}
          mode={mode}
          totalLineCount={detail?.lines.length ?? lines.length}
        />
      )}

      {/* ── Modals ────────────────────────────────────────────────────────────── */}

      <PrApprovalDeptModal
        open={deptModalOpen}
        depts={depts}
        loading={loading}
        onNext={handleDeptSelected}
        onClose={() => setDeptModalOpen(false)}
      />

      <PrApprovalLookupModal
        open={lookupOpen}
        title={lookupTitle}
        subtitle={lookupSubtitle}
        list={lookupList}
        loading={loading}
        onSelect={handlePRSelected}
        onClose={() => setLookupOpen(false)}
      />

      {/* Confirm Save */}
      <Modal
        open={confirmSave}
        title={<span>✅ Confirm First Level Approval</span>}
        onCancel={() => setConfirmSave(false)}
        footer={[
          <Button key="cancel" onClick={() => setConfirmSave(false)}>Cancel</Button>,
          <Button key="ok" type="primary" loading={saving} onClick={handleConfirmSave}>Approve</Button>,
        ]}
      >
        {detail && (
          <div>
            <p>First Level Approve PR <strong>{detail.header.prNo}</strong> dated <strong>{dayjs(detail.header.prDate).format('DD/MM/YYYY')}</strong>?</p>
            <p><strong>{selectedCount} of {lines.length} item{lines.length !== 1 ? 's' : ''}</strong> selected will be approved.</p>
            <p>PRSTATUS will transition to <strong>First Level Approved</strong>.</p>
          </div>
        )}
      </Modal>

      {/* Confirm Delete */}
      <Modal
        open={confirmDelete}
        title={<span>⚠️ Delete First Level Approval</span>}
        onCancel={() => setConfirmDelete(false)}
        footer={[
          <Button key="cancel" onClick={() => setConfirmDelete(false)}>Cancel</Button>,
          <Button key="ok" danger loading={saving} onClick={handleConfirmDelete}>Delete Approval</Button>,
        ]}
      >
        {detail && (
          <div>
            <p>Delete First Level Approval for PR <strong>{detail.header.prNo}</strong>?</p>
            <p>
              This will reset <em>app1, app1date, app1time</em> on PO_PRH and reset{' '}
              <em>QTYREQD, FirstAppQty, FirstApp</em> on all PO_PRL lines (DirectApp IS NULL only).
            </p>
            <p>PRSTATUS will revert to <strong>Requested</strong>. LogDet_PO Trans_Mod = <em>DELETE</em>.</p>
          </div>
        )}
      </Modal>

      {/* Confirm Cancel */}
      <Modal
        open={cancelConfirm}
        title="Discard Changes?"
        onCancel={() => setCancelConfirm(false)}
        footer={[
          <Button key="keep" onClick={() => setCancelConfirm(false)}>Keep Editing</Button>,
          <Button key="discard" danger onClick={() => { setCancelConfirm(false); void performCancel() }}>
            Discard &amp; Cancel
          </Button>,
        ]}
      >
        <p>You have unsaved changes. Discard them and return to view mode?</p>
      </Modal>

      {/* Print Preview */}
      <PrPrintPreviewModal
        open={printOpen}
        blobUrl={printBlobUrl}
        filename={printFilename}
        loading={printLoading}
        onClose={() => setPrintOpen(false)}
      />
    </div>
  )
}
