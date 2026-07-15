import { useCallback, useEffect, useState } from 'react'
import { App } from 'antd'
import { useNavigate } from 'react-router-dom'
import dayjs from 'dayjs'
import { notifyError, notifySuccess } from '@/shared/lib/notificationHelper'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import * as api from '../api/poCancellationApi'
import { formatPoNo } from '../types'
import type { CancellationReason, PoCancellationLine, PoOpenSummary } from '../types'

// ── usePoCancellation — orchestration hook for the PO Cancellation screen ────
// Mirrors usePrCancellation.ts conventions (modal.confirm for Yes/No, toast
// helpers for messages). Validation order/text below is taken 1:1 from the
// approved prototype's script.js `onOk()` / `onCanQtyBlur()`.

export type FocusTarget = { sNo: number; field: 'qty' | 'reason' } | null

const balanceOf = (line: PoCancellationLine) => line.orderQty - line.receivedQty

export function usePoCancellation() {
  const { modal } = App.useApp()
  const navigate = useNavigate()

  const [pickerOpen, setPickerOpen] = useState(true) // Form_Load → lookup_call() opens the picker
  const [selectedPo, setSelectedPo] = useState<PoOpenSummary | null>(null)
  const [reasons, setReasons] = useState<CancellationReason[]>([])
  const [lines, setLines] = useState<PoCancellationLine[]>([])
  const [loadingLines, setLoadingLines] = useState(false)
  const [saving, setSaving] = useState(false)
  const [focusRequest, setFocusRequest] = useState<FocusTarget>(null)

  useEffect(() => {
    api.getReasons().then(setReasons).catch(() => notifyError('Failed to load cancellation reasons.'))
  }, [])

  const openPicker  = useCallback(() => setPickerOpen(true), [])
  const closePicker = useCallback(() => setPickerOpen(false), [])

  const selectPo = useCallback(async (po: PoOpenSummary) => {
    setPickerOpen(false)
    setSelectedPo(po)
    setLoadingLines(true)
    try {
      const dtos = await api.getOpenLines(po.poNo, po.poDate)
      setLines(dtos.map((dto) => ({
        ...dto,
        checked: false, reasonCode: '', cancelQty: null,
        qtyError: null, reasonError: null,
      })))
    } catch (err) {
      notifyError(getErrorMessage(err))
    } finally {
      setLoadingLines(false)
    }
  }, [])

  const toggleRow = useCallback((sNo: number, checked: boolean) => {
    setLines((prev) => prev.map((l) => (l.sNo === sNo ? { ...l, checked } : l)))
  }, [])

  const toggleAll = useCallback((checked: boolean) => {
    setLines((prev) => prev.map((l) => ({ ...l, checked })))
  }, [])

  const setReason = useCallback((sNo: number, reasonCode: string) => {
    setLines((prev) => prev.map((l) => (l.sNo === sNo ? { ...l, reasonCode, reasonError: null } : l)))
  }, [])

  const setCancelQty = useCallback((sNo: number, value: number | null) => {
    setLines((prev) => prev.map((l) => (l.sNo === sNo ? { ...l, cancelQty: value } : l)))
  }, [])

  // Cancel Qty enforcement on blur: reset to balance if it exceeds Ord − Rcvd.
  const blurCancelQty = useCallback((sNo: number) => {
    setLines((prev) => prev.map((l) => {
      if (l.sNo !== sNo || l.cancelQty === null) return l
      const bal = balanceOf(l)
      if (l.cancelQty > bal) {
        const msg = `Please Enter Cancel Quantity Less than Ordered Quantity...! (Available balance: ${bal.toFixed(3)})`
        notifyError(msg, 'Cancel Quantity')
        return { ...l, cancelQty: bal, qtyError: msg }
      }
      return l
    }))
  }, [])

  const clearFocusRequest = useCallback(() => setFocusRequest(null), [])

  const reset = useCallback(() => {
    setSelectedPo(null)
    setLines([])
  }, [])

  const onOk = useCallback(() => {
    if (!selectedPo) return
    setLines((prev) => prev.map((l) => ({ ...l, qtyError: null, reasonError: null })))

    const checked = lines.filter((l) => l.checked)
    if (checked.length === 0) {
      notifyError('Select at least one item to complete the transaction.', 'No Line Selected')
      return
    }

    for (const line of checked) {
      const bal = balanceOf(line)
      const qty = line.cancelQty

      if (qty === null || Number.isNaN(qty) || qty === 0) {
        setLines((prev) => prev.map((l) => (l.sNo === line.sNo ? { ...l, qtyError: 'Please Enter Cancel Quantity...!' } : l)))
        notifyError('Please Enter Cancel Quantity...!', 'Cancel Quantity')
        setFocusRequest({ sNo: line.sNo, field: 'qty' })
        return
      }
      if (!line.reasonCode) {
        setLines((prev) => prev.map((l) => (l.sNo === line.sNo ? { ...l, reasonError: 'Please Enter Cancellation Reason..!' } : l)))
        notifyError('Please Enter Cancellation Reason..!', 'Cancellation Reason')
        setFocusRequest({ sNo: line.sNo, field: 'reason' })
        return
      }
      if (qty > bal) {
        const msg = `Please Enter Cancel Quantity Less than Ordered Quantity...! (Available balance: ${bal.toFixed(3)})`
        setLines((prev) => prev.map((l) => (l.sNo === line.sNo
          ? { ...l, cancelQty: bal, qtyError: msg }
          : l)))
        notifyError(msg, 'Cancel Quantity')
        setFocusRequest({ sNo: line.sNo, field: 'qty' })
        return
      }
    }

    const poLabel  = formatPoNo(selectedPo.poNo)
    const poDateLabel = dayjs(selectedPo.poDate).format('DD-MMM-YYYY')
    const totalCancelQty = checked.reduce((sum, l) => sum + (l.cancelQty ?? 0), 0)

    modal.confirm({
      title:      'Confirm Cancellation',
      icon:       null,
      content:    `Are You Sure you want to Cancel Order No. ${poLabel} Dated ${poDateLabel} — `
        + `${checked.length} line${checked.length > 1 ? 's' : ''}, total cancel quantity ${totalCancelQty.toFixed(3)}?`,
      okText:     'Yes',
      cancelText: 'No',
      onOk: async () => {
        setSaving(true)
        try {
          await api.cancelLines({
            poNo:  selectedPo.poNo,
            poDate: selectedPo.poDate,
            lines: checked.map((l) => ({
              sNo: l.sNo, itemCode: l.itemCode, reasonCode: l.reasonCode, cancelQty: l.cancelQty!,
            })),
          })
          notifySuccess(`${poLabel} cancellation saved.`)
          reset()
        } catch (err) {
          notifyError(getErrorMessage(err))
        } finally {
          setSaving(false)
        }
      },
    })
  }, [selectedPo, lines, modal, reset])

  const onExit = useCallback(() => {
    modal.confirm({
      title:      'Exit Purchase Order Cancellation',
      icon:       null,
      content:    'Close this screen? Any unsaved selections will be lost.',
      okText:     'Exit',
      cancelText: 'Cancel',
      onOk: () => navigate('/dashboard'),
    })
  }, [modal, navigate])

  // Escape triggers the Exit confirm when no other dialog is open — the PO
  // picker and Yes/No confirm dialogs are AntD Modals and already close on
  // Escape themselves (keyboard=true by default).
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key !== 'Escape' || pickerOpen) return
      onExit()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [pickerOpen, onExit])

  return {
    pickerOpen, openPicker, closePicker,
    selectedPo, selectPo,
    reasons, lines, loadingLines,
    toggleRow, toggleAll, setReason, setCancelQty, blurCancelQty,
    focusRequest, clearFocusRequest,
    saving, onOk, onExit, reset,
    canSubmit: selectedPo !== null && lines.length > 0 && !saving,
  }
}
