import { useEffect, useCallback, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { usePrReportStore } from '../store/usePrReportStore'
import { downloadReport } from '../api/prReportApi'
import { notifyError, notifyWarning, notifySuccess } from '@/shared/lib/notificationHelper'

export function usePrReport() {
  const navigate = useNavigate()
  const user     = useAuthStore((s) => s.user)
  const divCode  = user?.divCode ?? ''

  const {
    filter,
    departments,
    items,
    loadingLookups,
    generating,
    setFilter,
    setReportType,
    loadLookups,
    setGenerating,
    reset,
  } = usePrReportStore()

  // Load department and item lists once per divCode
  useEffect(() => {
    if (divCode) void loadLookups(divCode)
  }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Validation ──────────────────────────────────────────────────────────────

  const validate = useCallback((): boolean => {
    if (!filter.fromDate) {
      notifyWarning('Please select From PR Date.')
      return false
    }
    if (!filter.toDate) {
      notifyWarning('Please select To PR Date.')
      return false
    }
    if (filter.fromDate > filter.toDate) {
      notifyWarning('From PR Date cannot be later than To PR Date.')
      return false
    }
    if (
      filter.reportType === 'Departmentwise' &&
      filter.selectedDeptCodes.length === 0
    ) {
      notifyWarning('Please select at least one Department for Departmentwise report.')
      return false
    }
    if (
      filter.reportType === 'Itemwise' &&
      !filter.allItems &&
      filter.selectedItemCodes.length === 0
    ) {
      notifyWarning('Please select at least one Item, or check All Items.')
      return false
    }
    return true
  }, [filter])

  // ── Generate report ─────────────────────────────────────────────────────────

  const handleGenerate = useCallback(async () => {
    if (!validate()) return

    setGenerating(true)
    try {
      // When allItems is checked, pass every available item code to the backend
      const itemCodes =
        filter.reportType === 'Itemwise'
          ? filter.allItems
            ? items.map((i) => i.itemCode)
            : filter.selectedItemCodes
          : []

      await downloadReport({
        divCode,
        reportType: filter.reportType,
        fromDate:   filter.fromDate,
        toDate:     filter.toDate,
        deptCodes:  filter.selectedDeptCodes,
        itemCodes,
      })

      notifySuccess(`${filter.reportType} PR report downloaded.`)
    } catch (e: unknown) {
      notifyError(e instanceof Error ? e.message : 'Failed to generate report. Please try again.')
    } finally {
      setGenerating(false)
    }
  }, [filter, divCode, items, validate, setGenerating]) // eslint-disable-line react-hooks/exhaustive-deps

  // Keep ref fresh so the keyboard handler always calls the latest closure
  const handleGenerateRef = useRef(handleGenerate)
  handleGenerateRef.current = handleGenerate

  // Alt+R keyboard shortcut for Report
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.altKey && e.key.toLowerCase() === 'r' && !generating) {
        e.preventDefault()
        void handleGenerateRef.current()
      }
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [generating])

  // ── Exit ────────────────────────────────────────────────────────────────────

  const handleExit = useCallback(() => {
    reset()
    navigate(-1)
  }, [reset, navigate])

  return {
    filter,
    departments,
    items,
    loadingLookups,
    generating,
    setFilter,
    setReportType,
    handleGenerate,
    handleExit,
  }
}
