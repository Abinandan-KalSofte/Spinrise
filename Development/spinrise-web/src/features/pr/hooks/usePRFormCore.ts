import { useCallback, useEffect, useRef, useState } from 'react'
import { App, Form } from 'antd'
import dayjs from 'dayjs'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { generateUUID } from '@/shared/lib/uuid'
import { getFYBounds } from '@/shared/lib/dateUtils'
import * as prApi from '../api/prApi'
import type { PRHeaderFormValues } from '../components/pr-form/PRHeaderV1'
import type { PRLineItem } from '../components/pr-form/PRLineItemsTable'
import type {
  PrHeader, PrLine,
  DepartmentOption, EmployeeOption, PrTypeOption,
  PrParameters, PreAddChecks,
} from '../types'

export type PRFormMode = 'new' | 'view' | 'edit'

export function usePRFormCore() {
  const { message } = App.useApp()
  const [headerForm] = Form.useForm<PRHeaderFormValues>()

  const authUser = useAuthStore((s) => s.user)
  const divCode  = authUser?.divCode ?? ''
  const depCode  = (Form.useWatch('depCode', headerForm) as string | undefined) ?? ''

  // ── Core state ────────────────────────────────────────────────────────────
  const [items,          setItems]          = useState<PRLineItem[]>([])
  const [savedPrNo,      setSavedPrNo]      = useState<number | null>(null)
  const [savedPr,        setSavedPr]        = useState<PrHeader | null>(null)
  const [prStatus,       setPrStatus]       = useState<string | null>(null)
  const [lastPrDate,     setLastPrDate]     = useState<string | null>(null)
  const [saving,         setSaving]         = useState(false)
  const [deleting,       setDeleting]       = useState(false)
  const [deleteModalOpen,setDeleteModalOpen]= useState(false)
  const [mode,           setMode]           = useState<PRFormMode>('new')
  const [navLoading,     setNavLoading]     = useState(false)
  const [isDirty,        setIsDirty]        = useState(false)

  const markDirty  = () => setIsDirty(true)
  const clearDirty = () => setIsDirty(false)

  // ── Pre-check state ───────────────────────────────────────────────────────
  const [preCheckMsg,     setPreCheckMsg]     = useState<string | null>(null)
  const [preCheckLoading, setPreCheckLoading] = useState(false)

  // ── Lookup state ──────────────────────────────────────────────────────────
  const [departments,    setDepartments]    = useState<DepartmentOption[]>([])
  const [employees,      setEmployees]      = useState<EmployeeOption[]>([])
  const [prTypes,        setPrTypes]        = useState<PrTypeOption[]>([])
  const [parameters,     setParameters]     = useState<PrParameters | null>(null)
  const [lookupsLoading, setLookupsLoading] = useState(false)
  const [lookupsError,   setLookupsError]   = useState<string | null>(null)
  const [lookupsLoaded,  setLookupsLoaded]  = useState(false)

  // ── Map saved line → local item ───────────────────────────────────────────
  const mapSavedLine = (line: PrLine): PRLineItem => ({
    ...line,
    key: generateUUID(),
  })

  // ── Fill header form from saved PR ────────────────────────────────────────
  const fillFormFromPr = (pr: PrHeader) => {
    headerForm.setFieldsValue({
      prDate:  dayjs(pr.prDate),
      depCode: pr.depCode,
      section: pr.section  ?? '',
      iType:   pr.iType    ?? '',
      reqName: pr.reqName  ?? '',
      refNo:   pr.refNo    ?? '',
      poGrp:   pr.poGrp    ?? '',
    })
  }

  // ── Load lookups ──────────────────────────────────────────────────────────
  const loadAll = useCallback(async () => {
    if (!divCode) return
    setLookupsLoading(true)
    setLookupsError(null)
    try {
      const [params, depts, types] = await Promise.all([
        prApi.getParameters(divCode),
        prApi.getDepartments(divCode),
        prApi.getPrTypes(),
      ])
      setParameters(params)
      setDepartments(depts)
      setPrTypes(types)

      const empCommon = params?.empMasterComm ?? 'N'
      const emps = await prApi.getEmployees(divCode, empCommon)
      setEmployees(emps)
      setLookupsLoaded(true)
    } catch {
      setLookupsError('Failed to load reference data. Click Retry to reload.')
    } finally {
      setLookupsLoading(false)
    }
  }, [divCode])

  useEffect(() => { if (divCode) void loadAll() }, [divCode, loadAll])

  // ── Pre-checks ────────────────────────────────────────────────────────────
  const runPreChecks = async (): Promise<PreAddChecks | null> => {
    if (!divCode) return null
    setPreCheckLoading(true)
    try {
      const result = await prApi.runPreAddChecks(divCode)
      if      (!result.itemMasterExists) setPreCheckMsg('Item Master is not configured.')
      else if (!result.deptMasterExists) setPreCheckMsg('No departments configured for this division.')
      else if (!result.docParaExists)    setPreCheckMsg('PR document number series is not configured.')
      else                               setPreCheckMsg(null)
      return result
    } catch { return null }
    finally { setPreCheckLoading(false) }
  }

  useEffect(() => { if (divCode) void runPreChecks() }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Load record ───────────────────────────────────────────────────────────
  const loadRecord = async (prNo: number, prDate: string): Promise<string | null> => {
    setNavLoading(true)
    try {
      const pr = await prApi.getById(divCode, prNo, prDate)
      fillFormFromPr(pr)
      setItems(pr.lines.map(mapSavedLine))
      setSavedPrNo(pr.prNo)
      setSavedPr(pr)
      setPrStatus(pr.prStatus)
      setMode('view')
      clearDirty()
      return pr.prStatus
    } catch (err) {
      void message.error(err instanceof Error ? err.message : 'Failed to load the requisition.')
      return null
    } finally {
      setNavLoading(false)
    }
  }

  // ── Load last record (on mount) ───────────────────────────────────────────
  const loadLastRecord = async () => {
    if (!divCode) return
    const { yfDate, ylDate } = getFYBounds()
    setNavLoading(true)
    try {
      const pr = await prApi.getLastRecord(divCode, yfDate, ylDate)
      if (!pr) { setNavLoading(false); return }
      setLastPrDate(pr.prDate)
      await loadRecord(pr.prNo, pr.prDate)
    } catch {
      setNavLoading(false)
    }
  }

  // ── Navigate FIRST / PREV / NEXT / LAST (client-side) ────────────────────
  const navigateRecord = async (direction: 'FIRST' | 'PREV' | 'NEXT' | 'LAST') => {
    if (!divCode) return
    const { yfDate, ylDate } = getFYBounds()
    setNavLoading(true)
    try {
      const all = await prApi.getList(divCode, yfDate, ylDate, 'VIEW', { pageSize: 1000 })
      if (all.length === 0) { setNavLoading(false); return }

      let targetIdx: number
      if (direction === 'FIRST') {
        targetIdx = 0
      } else if (direction === 'LAST') {
        targetIdx = all.length - 1
      } else {
        const currIdx = savedPrNo ? all.findIndex((r) => r.prNo === savedPrNo) : -1
        if (direction === 'PREV') {
          if (currIdx <= 0) { void message.info('Already at the first record.'); setNavLoading(false); return }
          targetIdx = currIdx - 1
        } else {
          if (currIdx < 0 || currIdx >= all.length - 1) { void message.info('Already at the last record.'); setNavLoading(false); return }
          targetIdx = currIdx + 1
        }
      }

      const target = all[targetIdx]
      await loadRecord(target.prNo, target.prDate)
    } catch {
      setNavLoading(false)
    }
  }

  // ── Init new mode ─────────────────────────────────────────────────────────
  const initNewMode = () => {
    headerForm.resetFields()
    setItems([])
    setSavedPrNo(null)
    setSavedPr(null)
    setPrStatus(null)
    setMode('new')
    clearDirty()
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  const doSave = async () => {
    let values: PRHeaderFormValues
    try { values = await headerForm.validateFields() }
    catch { void message.error('Please fill in all required fields.'); return }

    const validLines = items.filter((l) => l.itemCode.trim() !== '')
    if (validLines.length === 0) {
      void message.error('Please add at least one item to the requisition before saving.')
      return
    }

    const belowMin = validLines.filter((l) => (l.qtyInd ?? 0) <= 0)
    if (belowMin.length > 0) {
      void message.error(`Quantity must be greater than 0 for: ${belowMin.map((l) => l.itemCode).join(', ')}.`)
      return
    }

    setSaving(true)
    try {
      const { yfDate, ylDate } = getFYBounds()
      const prDateStr = values.prDate.format('YYYY-MM-DD')
      const request = {
        prDate:         prDateStr,
        depCode:        values.depCode,
        reqName:        values.reqName?.trim() || null,
        section:        values.section?.trim() || null,
        iType:          values.iType?.trim()   || null,
        refNo:          values.refNo?.trim().toUpperCase() || null,
        poGrp:          values.poGrp?.trim()   || null,
        existingPrNo:   mode === 'edit' && savedPrNo ? savedPrNo          : null,
        existingPrDate: mode === 'edit' && savedPr   ? savedPr.prDate     : null,
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
      if (mode === 'edit' && savedPrNo) {
        result = await prApi.modifyPr(divCode, yfDate, ylDate, request)
      } else {
        result = await prApi.addPr(divCode, yfDate, ylDate, request)
        setLastPrDate(prDateStr)
      }

      const savedFull = await prApi.getById(divCode, result.prNo, prDateStr)
      fillFormFromPr(savedFull)
      setItems(savedFull.lines.map(mapSavedLine))
      setSavedPrNo(savedFull.prNo)
      setSavedPr(savedFull)
      setPrStatus(savedFull.prStatus)
      setMode('view')
      clearDirty()
      void message.success(`PR-${String(result.prNo).padStart(5, '0')} saved successfully.`)
    } catch (err) {
      void message.error(err instanceof Error ? err.message : 'Failed to save the requisition. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  const handleDeleteClick = () => {
    if (!savedPrNo) return
    setDeleteModalOpen(true)
  }

  const handleDeleteConfirm = async (): Promise<boolean> => {
    if (!savedPrNo || !savedPr) return false
    setDeleteModalOpen(false)
    setDeleting(true)
    try {
      await prApi.deletePr(divCode, {
        prNo:         savedPrNo,
        prDate:       savedPr.prDate,
        deleteMode:   'FULL',
        prSno:        null,
        deleteReason: null,
      })
      void message.success(`PR-${String(savedPrNo).padStart(5, '0')} deleted.`)
      initNewMode()
      return true
    } catch (err) {
      void message.error(err instanceof Error ? err.message : 'Failed to delete the requisition.')
      return false
    } finally {
      setDeleting(false)
    }
  }

  // ── KPI computations ─────────────────────────────────────────────────────
  const validLines = items.filter((l) => l.itemCode.trim() !== '')
  const totalCost  = validLines.reduce((s, l) => s + (l.appCost ?? 0), 0)
  const totalQtyByUOM = validLines.reduce<Record<string, number>>((acc, l) => {
    if (l.uom) acc[l.uom] = (acc[l.uom] ?? 0) + (l.qtyInd ?? 0)
    return acc
  }, {})
  const totalQtyDisplay =
    Object.entries(totalQtyByUOM)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([uom, qty]) =>
        `${uom.charAt(0).toUpperCase() + uom.slice(1).toLowerCase()}: ${qty.toLocaleString('en-IN', {
          minimumFractionDigits: 3, maximumFractionDigits: 3,
        })}`,
      )
      .join(' | ') || '—'

  const pageBusy = saving || deleting || navLoading

  // ── Ctrl+S global shortcut ────────────────────────────────────────────────
  const doSaveRef = useRef(doSave)
  doSaveRef.current = doSave
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === 's') {
        e.preventDefault()
        if (!saving && !deleting && (mode === 'new' || mode === 'edit')) void doSaveRef.current()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [saving, deleting, mode])

  return {
    // form
    headerForm, depCode, authUser, divCode,
    // state
    items, setItems,
    savedPrNo, savedPr, prStatus, lastPrDate,
    saving, deleting, pageBusy,
    deleteModalOpen, setDeleteModalOpen,
    // mode & nav
    mode, setMode, navLoading, isDirty, markDirty, clearDirty,
    // lookups
    departments, employees, prTypes, parameters,
    lookupsLoaded, lookupsLoading, lookupsError, loadAll,
    // pre-checks
    preCheckMsg, preCheckLoading, runPreChecks,
    // KPI
    validLines, totalCost, totalQtyByUOM, totalQtyDisplay,
    // actions
    doSave, handleDeleteClick, handleDeleteConfirm,
    loadRecord, loadLastRecord, navigateRecord, initNewMode, mapSavedLine,
  }
}
