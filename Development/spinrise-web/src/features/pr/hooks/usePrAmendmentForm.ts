import { useCallback, useRef, useState } from 'react'
import { notifyError, notifySuccess } from '@/shared/lib/notificationHelper'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { generateUUID } from '@/shared/lib/uuid'
import * as api from '../api/prAmendmentApi'
import type {
  AmendmentHeader, AmendmentLineLocal, AmendmentSummary, SaveAmendmentRequest,
} from '../types'

export type DeleteLineMode = 'complete' | 'line' | null

export type AmendMode = 'none' | 'new' | 'view'



export function usePrAmendmentForm() {
  const authUser       = useAuthStore((s) => s.user)
  const processingDate = useAuthStore((s) => s.processingDate)
  const divCode        = authUser?.divCode ?? ''
  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)

  const [mode,    setMode]    = useState<AmendMode>('none')
  const [header,  setHeader]  = useState<AmendmentHeader | null>(null)
  const [lines,   setLines]   = useState<AmendmentLineLocal[]>([])
  const [loading, setLoading] = useState(false)
  const [saving,  setSaving]  = useState(false)

  // Nav list — ref mirrors state to avoid stale closures in callbacks
  const [navList, _setNavList] = useState<AmendmentSummary[]>([])
  const [navIdx,  setNavIdx]   = useState(-1)
  const navListRef = useRef<AmendmentSummary[]>([])
  const navIdxRef  = useRef(-1)

  const setNavList = useCallback((list: AmendmentSummary[]) => {
    navListRef.current = list
    _setNavList(list)
  }, [])

  const setNavIdxSync = useCallback((idx: number) => {
    navIdxRef.current = idx
    setNavIdx(idx)
  }, [])

  const mapLines = (raw: AmendmentHeader['lines']): AmendmentLineLocal[] =>
    raw.map((l) => ({ ...l, key: generateUUID() }))

  // ── Load PR for new amendment ─────────────────────────────────────────────
  const loadForNew = useCallback(async (prNo: number, prDate: string) => {
    setLoading(true)
    try {
      const data = await api.getAmendmentForNew(divCode, prNo, prDate)
      setHeader(data)
      setLines(mapLines(data.lines))
      setMode('new')
    } catch (e: unknown) {
      notifyError((e as Error).message ?? 'Failed to load PR.')
    } finally {
      setLoading(false)
    }
  }, [divCode]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Load existing amendment ───────────────────────────────────────────────
  const loadById = useCallback(async (
    prNo: number, prDate: string, amendNo: number, targetMode: AmendMode = 'view',
  ) => {
    setLoading(true)
    try {
      const data = await api.getAmendmentById(divCode, prNo, prDate, amendNo)
      setHeader(data)
      setLines(mapLines(data.lines))
      // Find position in nav list
      const idx = navListRef.current.findIndex(
        (n) => n.amendNo === amendNo && String(n.prNo) === String(prNo),
      )
      if (idx >= 0) setNavIdxSync(idx)
      setMode(targetMode)
    } catch (e: unknown) {
      notifyError((e as Error).message ?? 'Failed to load amendment.')
    } finally {
      setLoading(false)
    }
  }, [divCode, setNavIdxSync]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Refresh nav list ──────────────────────────────────────────────────────
  const refreshNavList = useCallback(async (): Promise<AmendmentSummary[]> => {
    if (!divCode) return []
    try {
      const list = await api.getAmendmentList(divCode, yfDate, ylDate, undefined, undefined, 1, 1000)
      setNavList(list)
      return list
    } catch {
      return []
    }
  }, [divCode, yfDate, ylDate, setNavList])

  // ── Load last amendment on mount ──────────────────────────────────────────
  const loadLastAmendment = useCallback(async () => {
    if (!divCode) return
    try {
      const list = await api.getAmendmentList(divCode, yfDate, ylDate, undefined, undefined, 1, 1000)
      setNavList(list)
      if (list.length > 0) {
        const lastIdx = list.length - 1
        const last = list[lastIdx]
        const data = await api.getAmendmentById(divCode, last.prNo, last.prDate, last.amendNo)
        setHeader(data)
        setLines(mapLines(data.lines))
        setNavIdxSync(lastIdx)
        setMode('view')
      } else {
        setMode('none')
      }
    } catch {
      setMode('none')
    }
  }, [divCode, yfDate, ylDate, setNavList, setNavIdxSync]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Mode enter helpers ────────────────────────────────────────────────────
  const enterNew = useCallback(() => {
    setHeader(null)
    setLines([])
    setMode('new')
  }, [])

  const enterFind = useCallback(() => {
    setHeader(null)
    setLines([])
    setMode('view')
  }, [])

  // ── Navigation ────────────────────────────────────────────────────────────
  const navTo = useCallback(async (idx: number) => {
    const list = navListRef.current
    if (idx < 0 || idx >= list.length) return
    const rec = list[idx]
    setLoading(true)
    try {
      const data = await api.getAmendmentById(divCode, rec.prNo, rec.prDate, rec.amendNo)
      setHeader(data)
      setLines(mapLines(data.lines))
      setNavIdxSync(idx)
      setMode('view')
    } catch (e: unknown) {
      notifyError((e as Error).message ?? 'Navigation failed.')
    } finally {
      setLoading(false)
    }
  }, [divCode, setNavIdxSync]) // eslint-disable-line react-hooks/exhaustive-deps

  const navFirst = useCallback(() => void navTo(0), [navTo])
  const navPrev  = useCallback(() => void navTo(navIdxRef.current - 1), [navTo])
  const navNext  = useCallback(() => void navTo(navIdxRef.current + 1), [navTo])
  const navLast  = useCallback(() => void navTo(navListRef.current.length - 1), [navTo])

  // ── Save (Add or Modify) ──────────────────────────────────────────────────
  const doSave = useCallback(async (refNo: string, amendReason: string, iType: string | null): Promise<boolean> => {
    const hdr = header
    if (!hdr) return false

    if (!amendReason.trim()) {
      notifyError('Amendment Reason is required.')
      return false
    }
    if (lines.length === 0) {
      notifyError('At least one line item is required.')
      return false
    }
    const manualNoJust = lines.find((l) => l.rateSource === 'MANUAL' && !l.rateJustification?.trim())
    if (manualNoJust) {
      notifyError(`Rate Justification required for item ${manualNoJust.itemCode}.`)
      return false
    }
    const qtyEmpty = lines.find((l) => !l.qtyInd || l.qtyInd <= 0)
    if (qtyEmpty) {
      notifyError(`Qty must be greater than 0 for item ${qtyEmpty.itemCode}.`)
      return false
    }
    const belowMin = lines.find((l) =>
      (l.minLevel ?? 0) > 0 && l.qtyInd > 0 && l.qtyInd < (l.minLevel ?? 0)
    )
    if (belowMin) {
      notifyError(`Qty for ${belowMin.itemCode} is below the minimum order level (min: ${belowMin.minLevel}).`)
      return false
    }
    const aboveMax = lines.find((l) =>
      (l.maxLevel ?? 0) > 0 && l.qtyInd > 0 && l.qtyInd > (l.maxLevel ?? 0)
    )
    if (aboveMax) {
      notifyError(`Qty for ${aboveMax.itemCode} exceeds the maximum order level (max: ${aboveMax.maxLevel}).`)
      return false
    }
    const rateOverMax = lines.find((l) => (l.rate ?? 0) > 999_999_999)
    if (rateOverMax) {
      notifyError(`Rate for ${rateOverMax.itemCode} exceeds the maximum allowed value.`)
      return false
    }
    const costOverMax = lines.find((l) => l.appCost > 99_999_999_999)
    if (costOverMax) {
      notifyError(`Approx. value for ${costOverMax.itemCode} exceeds the maximum allowed value.`)
      return false
    }
    const prDayjs = hdr.prDate
      ? (hdr.prDate.includes('/') ? hdr.prDate.split('/').reverse().join('-') : hdr.prDate)
      : null
    const badDate = prDayjs
      ? lines.find((l) => l.reqdDate && l.reqdDate < prDayjs)
      : null
    if (badDate) {
      notifyError(`Required Date for item ${badDate.itemCode} cannot be before the PR Date.`)
      return false
    }

    const maxSno = lines.reduce((m, l) => (l.prSno > 0 ? Math.max(m, l.prSno) : m), 0)
    let nextSno = maxSno + 1
    const resolvedLines = lines.map((l) => ({ ...l, prSno: l.prSno > 0 ? l.prSno : nextSno++ }))

    const todayIso = new Date().toISOString().split('T')[0]
    const request: SaveAmendmentRequest = {
      prNo:            String(hdr.prNo),
      prDate:          hdr.prDate,
      amendDate:       processingDate ?? todayIso,
      amendmentReason: amendReason.trim(),
      refNo:           refNo.trim() || null,
      iType:           iType || null,
      rowVersion:      hdr.rowVersion || null,
      pDate:           processingDate ?? todayIso,
      lines: resolvedLines.map((l) => ({
        prSno:             l.prSno,
        itemCode:          l.itemCode,
        macNo:             l.macNo,
        qtyInd:            l.qtyInd,
        reqdDate:          l.reqdDate,
        rate:              l.rate,
        rateSource:        l.rateSource,
        rateJustification: l.rateJustification,
        curStock:          l.curStock,
        ccCode:            l.ccCode,
        catCode:           l.catCode,
        bgrpCode:          l.bgrpCode,
        place:             l.place,
        appCost:           l.appCost,
        remarks:           l.remarks,
        rowVersion:        l.rowVersion ?? null,
      })),
    }

    setSaving(true)
    try {
      const result = await api.addAmendment(divCode, yfDate, ylDate, request)
      notifySuccess(`Amendment No. ${result.amendNo} created.`)
      const list = await refreshNavList()
      const newIdx = list.findIndex(
        (n) => n.amendNo === result.amendNo && String(n.prNo) === String(hdr.prNo),
      )
      if (newIdx >= 0) setNavIdxSync(newIdx)
      await loadById(hdr.prNo, hdr.prDate, result.amendNo, 'view')
      return true
    } catch (e: unknown) {
      notifyError((e as Error).message ?? 'Save failed.')
      return false
    } finally {
      setSaving(false)
    }
  }, [header, lines, divCode, yfDate, ylDate, loadById, refreshNavList, setNavIdxSync])

  // ── Reset to blank ────────────────────────────────────────────────────────
  const resetForm = useCallback(() => {
    setHeader(null)
    setLines([])
    setMode('none')
  }, [])

  return {
    mode,
    header, lines, setLines,
    loading, saving,
    navList, navIdx,
    divCode, processingDate,
    yfDate, ylDate,
    loadForNew, loadById, loadLastAmendment,
    enterNew, enterFind,
    navFirst, navPrev, navNext, navLast,
    doSave, resetForm,
  }
}
