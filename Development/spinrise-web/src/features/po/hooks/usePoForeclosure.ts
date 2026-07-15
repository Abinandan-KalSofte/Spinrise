import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { App } from 'antd'
import { useNavigate } from 'react-router-dom'
import { notifyError, notifySuccess } from '@/shared/lib/notificationHelper'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import * as api from '../api/poForeclosureApi'
import { formatPoNo } from '../types'
import type { POForeclosureLineDto } from '../types'

// ── usePoForeclosure — orchestration hook for the PO Fore Closure screen ────
// Mode-based (query/modify) flow taken 1:1 from script.js: Modify enables
// selection, Cancel resets to query state. Save shows a Yes/No confirm
// before committing — the approved HTML prototype had none, but
// FN-PO-Foreclosure.md §1/§3.2 explicitly requires one ("SPINRISE adds a
// confirmation prompt before save, VB6 had none"); this was tracked as an
// open Change Request and is now implemented, styled like Cancellation's
// confirm (modal.confirm, Yes/No).

export type ForeclosureMode = 'query' | 'modify'

const lineKey = (l: { poNo: number; sNo: number }) => `${l.poNo}-${l.sNo}`

export function usePoForeclosure() {
  const { modal } = App.useApp()
  const navigate = useNavigate()

  const [mode, setMode] = useState<ForeclosureMode>('query')
  const [lines, setLines] = useState<POForeclosureLineDto[]>([])
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [checkedKeys, setCheckedKeys] = useState<Set<string>>(new Set())
  const [filterText, setFilterText] = useState('')

  const confirmHandleRef = useRef<{ destroy: () => void } | null>(null)

  const loadLines = useCallback(async () => {
    setLoading(true)
    try {
      const data = await api.getOpenLines()
      setLines(data)
    } catch (err) {
      notifyError(getErrorMessage(err))
    } finally {
      setLoading(false)
    }
  }, [])

  const filteredLines = useMemo(() => {
    const q = filterText.trim().toLowerCase()
    if (!q) return lines
    return lines.filter((l) => formatPoNo(l.poNo).toLowerCase().includes(q))
  }, [lines, filterText])

  // Open PO lines are fetched on Modify, not on mount — the screen opens empty
  // and only hits the server once the user actually enters modify mode.
  const onModify = useCallback(() => {
    setMode('modify')
    void loadLines()
  }, [loadLines])

  const toggleRow = useCallback((key: string, checked: boolean) => {
    setCheckedKeys((prev) => {
      const next = new Set(prev)
      if (checked) next.add(key)
      else next.delete(key)
      return next
    })
  }, [])

  // Prototype guards toggleAll on mode==='mod' even though the master
  // checkbox is also disabled outside modify mode — mirrored exactly.
  const toggleAll = useCallback((checked: boolean) => {
    if (mode !== 'modify') return
    setCheckedKeys(checked ? new Set(filteredLines.map(lineKey)) : new Set())
  }, [mode, filteredLines])

  // Reset to the empty query state. Deliberately does NOT refetch — lines load on
  // Modify only, so reloading here would pull data back in outside modify mode.
  const onCancel = useCallback(() => {
    setCheckedKeys(new Set())
    setFilterText('')
    setMode('query')
    setLines([])
  }, [])

  const onSave = useCallback(() => {
    // Not modify mode → silent guard, save skipped (matches script.js exactly)
    if (mode !== 'modify') return

    const checked = lines.filter((l) => checkedKeys.has(lineKey(l)))
    if (checked.length === 0) {
      notifyError('Select at least one item to complete the transaction.', 'No Items Selected')
      return
    }

    const totalBalance = checked.reduce((sum, l) => sum + l.balanceQty, 0)

    const handle = modal.confirm({
      title:      'Confirm Fore Closure',
      icon:       null,
      content:    `Are you sure you want to fore close ${checked.length} selected line${checked.length > 1 ? 's' : ''}`
        + ` — total balance ${totalBalance.toFixed(3)}?`,
      okText:     'Yes',
      cancelText: 'No',
      onOk: async () => {
        confirmHandleRef.current = null
        setSaving(true)
        try {
          await api.foreclosureLines({
            lines: checked.map((l) => ({
              poNo: l.poNo, poDate: l.poDate, group: l.group,
              sNo: l.sNo, itemCode: l.itemCode, prNo: l.prNo, prDate: l.prDate,
            })),
          })
          const closedKeys = new Set(checked.map(lineKey))
          setLines((prev) => prev.filter((l) => !closedKeys.has(lineKey(l))))
          setCheckedKeys(new Set())
          setMode('query')
          notifySuccess('Purchase Order Closed Successfully', 'Success')
        } catch (err) {
          notifyError(getErrorMessage(err))
        } finally {
          setSaving(false)
        }
      },
      onCancel: () => { confirmHandleRef.current = null },
    })
    confirmHandleRef.current = handle
  }, [mode, lines, checkedKeys, modal])

  const onExit = useCallback(() => {
    const handle = modal.confirm({
      title:      'Exit Purchase Order Fore Closure',
      icon:       null,
      content:    'Close this screen? Any unsaved selections will be lost.',
      okText:     'Exit',
      cancelText: 'No',
      okButtonProps: { danger: true },
      onOk:     () => { confirmHandleRef.current = null; navigate('/dashboard') },
      onCancel: () => { confirmHandleRef.current = null },
    })
    confirmHandleRef.current = handle
  }, [modal, navigate])

  // Ctrl+M / Ctrl+S / Ctrl+Backspace / Ctrl+Q + Escape precedence (script.js).
  // Escape closes an already-open confirm dialog via its captured handle
  // (antd's modal.confirm doesn't self-dismiss on Escape) before falling
  // back to triggering the Exit confirm.
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (confirmHandleRef.current) {
          confirmHandleRef.current.destroy()
          confirmHandleRef.current = null
          return
        }
        onExit()
        return
      }
      if (e.ctrlKey) {
        const k = e.key.toLowerCase()
        if (k === 'm') { e.preventDefault(); onModify() }
        else if (k === 's') { e.preventDefault(); void onSave() }
        else if (k === 'q') { e.preventDefault(); onExit() }
        else if (e.key === 'Backspace') { e.preventDefault(); onCancel() }
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onModify, onSave, onExit, onCancel])

  return {
    mode, loading, saving,
    lines: filteredLines,
    checkedKeys, toggleRow, toggleAll,
    filterText, setFilterText,
    onModify, onSave, onCancel, onExit,
  }
}

export { lineKey }
