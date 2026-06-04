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
  PrParameters, PreAddChecks, UserPermissions,
} from '../types'

export type PRFormMode = 'new' | 'view' | 'edit'

export function usePRFormCore() {
  const { message } = App.useApp()
  const [headerForm] = Form.useForm<PRHeaderFormValues>()

  const authUser        = useAuthStore((s) => s.user)
  const processingDate  = useAuthStore((s) => s.processingDate)
  const divCode         = authUser?.divCode ?? ''
  const depCode  = (Form.useWatch('depCode', headerForm) as string | undefined) ?? ''
  const reqName  = (Form.useWatch('reqName', headerForm) as string | undefined) ?? ''
  const iType    = (Form.useWatch('iType',   headerForm) as string | undefined) ?? ''

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
  const [preCheckResult,  setPreCheckResult]  = useState<PreAddChecks | null>(null)

  // ── Permissions ───────────────────────────────────────────────────────────
  const [permissions, setPermissions] = useState<UserPermissions>({ canAdd: true, canModify: true, canDelete: true })

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

  useEffect(() => {
    if (!divCode) return
    void loadAll()
    prApi.getUserPermissions(divCode)
      .then((p) => setPermissions(p))
      .catch(() => { /* permissive fallback already set as default */ })
  }, [divCode, loadAll])

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
      setPreCheckResult(result)
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

      // Back-fill minLevel/maxLevel from item master so save validation fires for existing lines
      const mappedLines = pr.lines.map(mapSavedLine)
      const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
      const pDate = processingDate ?? new Date().toISOString().split('T')[0]
      const uniqueCodes = [...new Set(mappedLines.map((l) => l.itemCode))]
      const details = await Promise.all(
        uniqueCodes.map((code) =>
          prApi.getItemDetail(divCode, code, yfDate, ylDate, pDate).catch(() => null)
        )
      )
      const detailMap = new Map(details.filter(Boolean).map((d) => [d!.itemCode, d!]))
      const linesWithLevels = mappedLines.map((l) => {
        const d = detailMap.get(l.itemCode)
        return d ? { ...l, minLevel: d.minLevel, maxLevel: d.maxLevel } : l
      })

      setItems(linesWithLevels)
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
    const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
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
    const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
    setNavLoading(true)
    try {
      // getList returns DESC (newest first); reverse → ASC (oldest = index 0)
      const all = (await prApi.getList(divCode, yfDate, ylDate, 'FIND', { pageSize: 1000 }))
        .reverse()
      if (all.length === 0) { setNavLoading(false); return }

      let targetIdx: number
      if (direction === 'FIRST') {
        targetIdx = 0
      } else if (direction === 'LAST') {
        targetIdx = all.length - 1
      } else {
        const currIdx = savedPrNo
        ? all.findIndex((r) => r.prNo === savedPrNo && r.prDate === savedPr?.prDate)
        : -1
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
      void message.error('Navigation failed. Please try again.')
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

    // G7: Duplicate item + machine check
    const seen = new Set<string>()
    for (const l of validLines) {
      const dupeKey = `${l.itemCode}|${l.macNo || ''}`
      if (seen.has(dupeKey)) {
        void message.error(`Duplicate item found: ${l.itemCode}${l.macNo ? ` / Machine: ${l.macNo}` : ''}. Remove or change the machine number.`)
        return
      }
      seen.add(dupeKey)
    }

    const belowMin = validLines.filter((l) => (l.qtyInd ?? 0) <= 0)
    if (belowMin.length > 0) {
      void message.error(`Quantity must be greater than 0 for: ${belowMin.map((l) => l.itemCode).join(', ')}.`)
      return
    }

    // G4: MANUAL rate must have justification
    const manualNoJustification = validLines.filter(
      (l) => l.rateSource === 'MANUAL' && !l.rateJustification?.trim()
    )
    if (manualNoJustification.length > 0) {
      void message.error(`Rate justification is required for: ${manualNoJustification.map((l) => l.itemCode).join(', ')}.`)
      return
    }

    // G5: Required date must be >= today (Add) or >= PR date (Modify)
    const prDateVal = dayjs(values.prDate.format('YYYY-MM-DD'))
    const today     = dayjs().startOf('day')
    const invalidDate = validLines.filter((l) => {
      if (!l.reqdDate) return false
      const rd = dayjs(l.reqdDate)
      return mode === 'new' ? rd.isBefore(today) : rd.isBefore(prDateVal)
    })
    if (invalidDate.length > 0) {
      void message.error(
        `Required date cannot be before ${mode === 'new' ? 'today' : 'the PR date'} for: ${invalidDate.map((l) => l.itemCode).join(', ')}.`
      )
      return
    }

    // G9: Backdate check — if backDateFlag='N', PR date must be >= maxPrDate
    if (mode === 'new' && preCheckResult?.backDateFlag === 'N' && preCheckResult.maxPrDate) {
      const maxDate = dayjs(preCheckResult.maxPrDate)
      if (prDateVal.isBefore(maxDate)) {
        void message.error(`Backdating is not allowed. PR date must be ${maxDate.format('DD-MMM-YYYY')} or later.`)
        return
      }
    }

    // G6: Qty below MINLEVEL — blocks save
    const belowMinLevel = validLines.filter(
      (l) => (l.minLevel ?? 0) > 0 && (l.qtyInd ?? 0) < (l.minLevel ?? 0)
    )
    if (belowMinLevel.length > 0) {
      void message.error(
        `Quantity is below minimum order level for: ${belowMinLevel.map((l) => l.itemCode).join(', ')}. Increase quantity before saving.`
      )
      return
    }

    // G6b: Qty above MAXLEVEL — blocks save
    const aboveMaxLevel = validLines.filter(
      (l) => (l.maxLevel ?? 0) > 0 && (l.qtyInd ?? 0) > (l.maxLevel ?? 0)
    )
    if (aboveMaxLevel.length > 0) {
      void message.error(
        `Quantity exceeds maximum order level for: ${aboveMaxLevel.map((l) => l.itemCode).join(', ')}. Reduce quantity before saving.`
      )
      return
    }

    // G6c: Rate exceeds DB column limit — numeric(13,4) allows max 9 integer digits
    const MAX_RATE_DB    = 999_999_999
    const MAX_APPCOST_DB = 99_999_999_999
    const rateOverflow = validLines.filter((l) => (l.rate ?? 0) > MAX_RATE_DB)
    if (rateOverflow.length > 0) {
      void message.error(
        `Rate exceeds the maximum allowed value (₹9,99,99,999) for: ${rateOverflow.map((l) => l.itemCode).join(', ')}. Please correct the rate before saving.`
      )
      return
    }

    // G6d: Approx. Value exceeds DB column limit
    const appCostOverflow = validLines.filter((l) => (l.appCost ?? 0) > MAX_APPCOST_DB)
    if (appCostOverflow.length > 0) {
      void message.error(
        `Approx. Value exceeds the maximum allowed (₹99,99,99,99,999) for: ${appCostOverflow.map((l) => l.itemCode).join(', ')}. Reduce quantity or rate before saving.`
      )
      return
    }

    setSaving(true)
    try {
      const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
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
      const mappedSaved = savedFull.lines.map(mapSavedLine)
      const savedCodes = [...new Set(mappedSaved.map((l) => l.itemCode))]
      const savedDetails = await Promise.all(
        savedCodes.map((code) =>
          prApi.getItemDetail(divCode, code, yfDate, ylDate, prDateStr).catch(() => null)
        )
      )
      const savedDetailMap = new Map(savedDetails.filter(Boolean).map((d) => [d!.itemCode, d!]))
      setItems(mappedSaved.map((l) => {
        const d = savedDetailMap.get(l.itemCode)
        return d ? { ...l, minLevel: d.minLevel, maxLevel: d.maxLevel } : l
      }))
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
      await loadLastRecord()
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
    headerForm, depCode, reqName, iType, authUser, divCode, processingDate,
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
    preCheckMsg, preCheckLoading, preCheckResult, runPreChecks,
    // permissions
    permissions,
    // KPI
    validLines, totalCost, totalQtyByUOM, totalQtyDisplay,
    // actions
    doSave, handleDeleteClick, handleDeleteConfirm,
    loadRecord, loadLastRecord, navigateRecord, initNewMode, mapSavedLine,
  }
}
