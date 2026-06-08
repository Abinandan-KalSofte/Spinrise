import { useEffect, useCallback, useRef } from 'react'
import { Modal, Spin, App } from 'antd'
import { CheckOutlined, CloseOutlined, ReloadOutlined } from '@ant-design/icons'
import { useFinalApprovalStore, selectEligibleLines } from '../store/useFinalApprovalStore'
import { finalApprovalApi } from '../api/finalApprovalApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { DispositionCode } from '../types/finalApprovalTypes'
import { PRDocBand, TbBtn, TbSep } from '../components/pr-form/PRToolbar'
import FinalApprovalFilterBar from '../components/final-approval/FinalApprovalFilterBar'
import FinalApprovalGrid      from '../components/final-approval/FinalApprovalGrid'
import FinalApprovalFooter    from '../components/final-approval/FinalApprovalFooter'
import { usePageTitle } from '@/shared/hooks/usePageTitle'

export default function FinalLevelApprovalPage() {
  usePageTitle('Final Level PR Approval')
  const { message } = App.useApp()
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const {
    lines, gridLoaded, loading, saving, filter,
    loadCompanies, loadApprovalLabels, loadGrid, setSaving, reset,
  } = useFinalApprovalStore()

  const eligibleLines = selectEligibleLines(lines)

  // Load company dropdown and approval level labels on mount
  useEffect(() => {
    void loadCompanies()
    if (divCode) void loadApprovalLabels(divCode)
  }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleShow = useCallback(async () => {
    if (!filter.dbName) {
      void message.warning('Please Select the Company Name')
      return
    }
    try {
      await loadGrid()
    } catch (e: unknown) {
      void message.error(e instanceof Error ? e.message : 'Failed to load PR lines.')
    }
  }, [filter.dbName, loadGrid, message])

  const handleRefresh = useCallback(async () => {
    if (!gridLoaded) { void message.info('Click Show to load PR lines first.'); return }
    await handleShow()
  }, [gridLoaded, handleShow, message])

  const handleCancel = useCallback(() => {
    reset()
  }, [reset])

  const handleSaveClick = useCallback(() => {
    if (eligibleLines.length === 0) {
      Modal.info({
        title: 'No Records Selected',
        content: 'No records are selected to approve. Please check at least one row. Rows with Disposition = PL Discuss cannot be selected.',
      })
      return
    }
    Modal.confirm({
      title: 'Confirm Final Approval',
      icon: <CheckOutlined />,
      content: (
        <div>
          <p>Save final-level approval for <strong>{eligibleLines.length}</strong> selected PR line(s)?</p>
          <p>This cannot be undone.</p>
        </div>
      ),
      okText: 'Save Approval',
      cancelText: 'Cancel',
      onOk: () => void handleSave(),
    })
  }, [eligibleLines]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSave = useCallback(async () => {
    setSaving(true)
    try {
      await finalApprovalApi.saveApprovals({
        dbName:    filter.dbName,
        bypassAll: filter.bypassAll,
        items: eligibleLines.map((r) => ({
          divCode:     r.divCode,
          prNo:        r.prNo,
          prDate:      r.prDate,
          prSno:       r.prSno,
          qtyApproved: r.qtyApproved,
          disposition: Number(r.disposition) as DispositionCode,
          rowVersion:  r.rowVersion,
        })),
      })
      void message.success('Purchase Requisition Approval Completed.')
      await handleShow()
    } catch (e: unknown) {
      // Check for 409 concurrency conflict
      const err = e as { response?: { status?: number; data?: { message?: string } } }
      if (err?.response?.status === 409) {
        Modal.error({
          title: 'Conflict — Record Modified',
          content: err.response?.data?.message
            ?? 'One or more records were modified by another user. Please refresh and try again.',
          onOk: () => void handleShow(),
        })
      } else {
        void message.error(e instanceof Error ? e.message : 'Save failed.')
      }
    } finally {
      setSaving(false)
    }
  }, [eligibleLines, filter, setSaving, message, handleShow]) // eslint-disable-line react-hooks/exhaustive-deps

  // Ref keeps Ctrl+S handler pointing at the latest handleSaveClick on every render,
  // avoiding stale closure when line qty/disposition changes without count changing.
  const handleSaveClickRef = useRef(handleSaveClick)
  handleSaveClickRef.current = handleSaveClick

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === 's') {
        e.preventDefault()
        if (gridLoaded && !saving) void handleSaveClickRef.current()
      }
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [gridLoaded, saving]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>

      {/* ── Doc Band ─────────────────────────────────────────────────────────── */}
      <PRDocBand
        breadcrumb={['Purchase Order', 'Final Level PR Approval']}
      />

      {/* ── Toolbar ──────────────────────────────────────────────────────────── */}
      <div style={{
        background: '#fff', borderBottom: '1px solid #e2e2e2',
        display: 'flex', alignItems: 'center', gap: 4,
        padding: '0 12px', height: 44, flexShrink: 0,
      }}>
        <TbBtn
          icon={<ReloadOutlined style={{ fontSize: 11 }} />}
          label="Refresh"
          onClick={() => void handleRefresh()}
        />
        <TbSep />
        <TbBtn
          variant="success"
          icon={<CheckOutlined style={{ fontSize: 11 }} />}
          label="Save"
          kbd="Ctrl+S"
          disabled={!gridLoaded || eligibleLines.length === 0 || saving}
          onClick={handleSaveClick}
        />
        <TbBtn
          icon={<CloseOutlined style={{ fontSize: 11 }} />}
          label="Cancel"
          disabled={!gridLoaded || saving}
          onClick={handleCancel}
        />
      </div>

      {/* ── Filter Bar ───────────────────────────────────────────────────────── */}
      <FinalApprovalFilterBar onShow={() => void handleShow()} loading={loading} />

      {/* ── Grid area ────────────────────────────────────────────────────────── */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: '#fff' }}>
        {!gridLoaded && !loading ? (
          <div style={{
            flex: 1, display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center', padding: 48, gap: 10,
          }}>
            <div style={{ fontSize: 36, opacity: 0.3 }}>✅</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#888' }}>No Data Loaded</div>
            <div style={{ fontSize: 12, color: '#aaa', textAlign: 'center', maxWidth: 400, lineHeight: 1.7 }}>
              Select Company and Division, then click <strong>Show</strong> to load pending PR lines for Final Level Approval.
            </div>
          </div>
        ) : loading ? (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Spin size="large" />
          </div>
        ) : (
          <FinalApprovalGrid />
        )}
      </div>

      {/* ── Footer ───────────────────────────────────────────────────────────── */}
      {gridLoaded && <FinalApprovalFooter />}

    </div>
  )
}
