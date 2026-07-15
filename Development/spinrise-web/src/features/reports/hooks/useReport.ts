import { useEffect, useCallback, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { useReportStore } from '../store/useReportStore'
import { getReportConfig } from '../configs/reportConfigs'
import { notifyError, notifyWarning } from '@/shared/lib/notificationHelper'

export function useReport(initialReportId: string | null) {
  const navigate = useNavigate()
  const user = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const {
    filter,
    lookups,
    loadingLookups,
    generating,
    previewOpen,
    previewBlobUrl,
    previewFilename,
    setFilter,
    setReportType,
    loadLookups,
    setGenerating,
    openPreview,
    closePreview,
    reset,
  } = useReportStore()

  const config = filter ? getReportConfig(filter.reportId) : null

  // Reset filters to defaults every time a report becomes active — including
  // re-selecting the same report after navigating away and back, where a
  // same-ID check would otherwise skip the reset and leave stale filters
  // from the previous visit showing.
  useEffect(() => {
    if (!initialReportId) {
      // No report selected yet
      return
    }
    const newConfig = getReportConfig(initialReportId)
    if (newConfig) {
      reset(initialReportId, newConfig.defaultTab)
    }
  }, [initialReportId]) // eslint-disable-line react-hooks/exhaustive-deps

  // Load lookups when divCode changes
  useEffect(() => {
    if (divCode) void loadLookups(divCode)
  }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  // Validation function
  const validate = useCallback((): boolean => {
    if (!filter) {
      notifyWarning('Please select a report module first.')
      return false
    }
    if (!filter.fromDate) {
      notifyWarning('Please select From Date.')
      return false
    }
    if (!filter.toDate) {
      notifyWarning('Please select To Date.')
      return false
    }
    if (filter.fromDate > filter.toDate) {
      notifyWarning('From Date cannot be later than To Date.')
      return false
    }
    if (filter.reportType === 'Departmentwise' && !filter.allDepts && filter.selectedDeptCodes.length === 0) {
      notifyWarning('Please select at least one Department, or check All Departments.')
      return false
    }
    if (filter.reportType === 'Itemwise' && !filter.allItems && filter.selectedItemCodes.length === 0) {
      notifyWarning('Please select at least one Item, or check All Items.')
      return false
    }
    if (filter.reportType === 'Supplierwise' && !filter.allSuppliers && filter.selectedSupplierCodes.length === 0) {
      notifyWarning('Please select at least one Supplier, or check All Suppliers.')
      return false
    }
    return true
  }, [filter])

  // Generate report
  const handleGenerate = useCallback(async () => {
    if (!config || !filter || !validate()) return

    setGenerating(true)
    try {
      const deptCodes = filter.reportType === 'Departmentwise' && !filter.allDepts ? filter.selectedDeptCodes : []
      const itemCodes = filter.reportType === 'Itemwise' && !filter.allItems ? filter.selectedItemCodes : []
      const supplierCodes = filter.reportType === 'Supplierwise' && !filter.allSuppliers ? filter.selectedSupplierCodes : []
      const params = {
        divCode,
        reportType: filter.reportType as 'Datewise' | 'Departmentwise' | 'Itemwise' | 'Supplierwise',
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        allDepts: filter.reportType !== 'Departmentwise' || filter.allDepts,
        deptCodes,
        allItems: filter.reportType !== 'Itemwise' || filter.allItems,
        itemCodes,
        allSuppliers: filter.reportType !== 'Supplierwise' || filter.allSuppliers,
        supplierCodes,
        confirmStatus: filter.reportType === 'Itemwise' ? filter.confirmStatus : undefined,
      }

      const { blobUrl, filename } = await config.fetchBlob(params)
      openPreview(blobUrl, filename)
    } catch (e: unknown) {
      notifyError(e instanceof Error ? e.message : 'Failed to generate report. Please try again.')
    } finally {
      setGenerating(false)
    }
  }, [filter, divCode, config, validate, setGenerating, openPreview]) // eslint-disable-line react-hooks/exhaustive-deps

  // Alt+R keyboard shortcut
  const handleGenerateRef = useRef(handleGenerate)
  handleGenerateRef.current = handleGenerate

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

  // Exit handler
  const handleExit = useCallback(() => {
    if (initialReportId && config) {
      reset(initialReportId, config.defaultTab)
    }
    navigate(-1)
  }, [reset, navigate, initialReportId, config]) // eslint-disable-line react-hooks/exhaustive-deps

  return {
    config,
    filter,
    lookups,
    loadingLookups,
    generating,
    previewOpen,
    previewBlobUrl,
    previewFilename,
    setFilter,
    setReportType,
    handleGenerate,
    closePreview,
    handleExit,
  }
}
