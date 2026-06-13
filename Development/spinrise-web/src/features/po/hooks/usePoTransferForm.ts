// ── usePoTransferForm — orchestration hook for PR to PO Transfer ─────────────
//
// Mirrors src/features/pr/hooks/usePRFormCore.ts conventions: useAuthStore,
// getFYBounds, AntD Form for the header, Zustand store for lines. User feedback
// is surfaced via the centralized notificationService (top-right notifications).
//
// Source authority: built against FSD draft v3.1.
//   ⚠ Q2 PENDING (Gate 0): countersign status unconfirmed — no logic depends on
//     it, but treat business rules below as provisional until Stage 3 sign-off.
//
// Pending Gate-0 items are isolated so they can be finalised WITHOUT refactoring
// this hook's shape:
//   • Q1 (module/DB/SP)  → single BASE const inside poTransferApi (not here).
//   • Q4 (GST routing)   → resolveGstRoute() adapter; UI never computes route.
//   • Q5 (header tax)    → propagateHeaderTax() handler; no client-side loop.
//   • BR-16/17 (budget)  → server-driven only; surfaced via save-error handler.

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Form } from 'antd'
import type { Dayjs } from 'dayjs'
import dayjs from 'dayjs'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { getErrorMessage, AppError } from '@/shared/lib/errorHandler'
import { formatPoNo } from '../types'
import { usePoTransferStore } from '../store/usePoTransferStore'
import { notificationService } from '@/shared/lib/notification'
import * as poApi from '../api/poTransferApi'
import type {
  PoHeader, PoLine, PoParameters, PoPreAddChecks,
  SupplierOption, OrderTypeOption, CarrierOption, BankOption, FormTypeOption,
  EligiblePrLine, DeliveryScheduleLine, AddPoRequest, SavePoLineRequest,
  GstRoute, LineTaxDetail,
} from '../types'

// ── Numeric helpers (project precision: Value/Amt 2dp, Qty 3dp) ──────────────
const round2 = (n: number) => Math.round(n * 100) / 100
const round3 = (n: number) => Math.round(n * 1000) / 1000
const fmtDate = (d: Dayjs | null | undefined) => (d ? d.format('YYYY-MM-DD') : null)

// ── Pure line recompute ──────────────────────────────────────────────────────
// Line value excludes pre-GST charges (D-11 — not in SPINRISE line model).
// GST split honours the SERVER-supplied route (Q4); the UI never decides it.
const calcLineValue = (rate: number, qty: number) => round2((rate || 0) * (qty || 0))

const recalcLine = (line: PoLine): PoLine => {
  const value   = calcLineValue(line.rate, line.qty)
  const isLocal = line.route === 'LOCAL'
  const cgstAmt = isLocal ? round2((value * (line.cgstPer || 0)) / 100) : 0
  const sgstAmt = isLocal ? round2((value * (line.sgstPer || 0)) / 100) : 0
  const igstAmt = isLocal ? 0 : round2((value * (line.igstPer || 0)) / 100)
  const tcsAmt  = round2((value * (line.tcsPer || 0)) / 100)
  return {
    ...line,
    value,
    cgstAmt, sgstAmt, igstAmt, tcsAmt,
    taxAmt: round2(cgstAmt + sgstAmt + igstAmt),
    taxPer: isLocal ? (line.cgstPer || 0) + (line.sgstPer || 0) : (line.igstPer || 0),
  }
}

// ── Header form values (AntD Form; dates as Dayjs) ───────────────────────────
export interface PoHeaderFormValues {
  // Display-only, fed from hook state (not sent in requests):
  poNo:          string         // formatted server PO number (blank pre-save, CD-03)
  poValue:       string         // formatted computed Order Value (UI-03, same as KPI)
  // Order Details
  poDate:        Dayjs
  orderType:     string         // BR-11
  supplier:      string         // BR-12
  gstin:         string         // RO — auto from supplier (UX-06)
  gstState:      string         // RO — auto; drives route (Q4)
  inspect:       string
  formType:      string
  refNo:         string
  refDate:       Dayjs | null
  currency:      string         // BR-13
  currRate:      number
  remarks:       string
  // Tax / Discount (header-level)
  cgstPer:       number
  sgstPer:       number
  igstPer:       number
  tcsPer:        number
  discPer:       number
  cessPer:       number         // ⚠ header pre-GST applicability vs D-11 unconfirmed
  aedPer:        number         // ⚠ idem
  freightAmt:    number
  packPer:       number
  insurPer:      number
  surchargePer:  number         // ⚠ idem
  addTaxPer:     number
  fileNo:        string
  fcaFob:        number
  freightType:   'PAID' | 'TOPAY'
  discApp:       'BEFORE' | 'AFTER'
  packApp:       'BEFORE' | 'AFTER'
  cessApp:       'BEFORE' | 'AFTER'
  // Payment
  payMode:       'DIRECT' | 'BANK'
  directInstr:   string
  advPer:        number
  modeOfPayment: string
  payRef:        string
  payRefDate:    Dayjs | null
  bankCode:      string         // BR-15 (when BANK)
  paymentTerms:  string
  chequeNo:      string         // BR-15 (when BANK)
  chequeDate:    Dayjs | null   // BR-15 (when BANK)
  // Instructions
  carrier:          string      // BR-14
  creditDays:       number
  deliveryDate:     Dayjs | null
  deliveryLocation: string
  billingAddress:   string
  specialInstr:     string
  despatch:         string
  purpose:          string
  otherLevies:      string
  pricingTerms:     string      // BR-15 (when orderType 'HO')
  packForwarding:   string
  insurance:        string
  freight:          string
  // Cancel / Status
  reminder:      string
  status:        string
  cancelled:     boolean
  cancelDate:    Dayjs | null
  cancelReason:  string
  approved:      string
  approvedBy:    string
}

const HO_TYPE = 'HO'

export function usePoTransferForm() {
  const [headerForm] = Form.useForm<PoHeaderFormValues>()

  const authUser       = useAuthStore((s) => s.user)
  const processingDate = useAuthStore((s) => s.processingDate)
  const divCode        = authUser?.divCode ?? ''

  // ── Store (mode + working lines + delivery + modal selection) ──────────────
  const mode            = usePoTransferStore((s) => s.mode)
  const setMode         = usePoTransferStore((s) => s.setMode)
  const currentPo       = usePoTransferStore((s) => s.currentPo)
  const setCurrentPo    = usePoTransferStore((s) => s.setCurrentPo)
  const draftLines      = usePoTransferStore((s) => s.draftLines)
  const setDraftLines   = usePoTransferStore((s) => s.setDraftLines)
  const updateDraftLine = usePoTransferStore((s) => s.updateDraftLine)
  const removeDraftLine = usePoTransferStore((s) => s.removeDraftLine)
  const deliveryLines   = usePoTransferStore((s) => s.deliveryLines)
  const setDeliveryLines= usePoTransferStore((s) => s.setDeliveryLines)
  const addSlot         = usePoTransferStore((s) => s.addSlot)
  const updateSlot      = usePoTransferStore((s) => s.updateSlot)
  const removeSlot      = usePoTransferStore((s) => s.removeSlot)
  const gstLineNo       = usePoTransferStore((s) => s.gstLineNo)
  const openGstModal    = usePoTransferStore((s) => s.openGstModal)
  const closeGstModal   = usePoTransferStore((s) => s.closeGstModal)
  const selectedLineNo  = usePoTransferStore((s) => s.selectedLineNo)
  const setSelectedLineNo = usePoTransferStore((s) => s.setSelectedLineNo)
  const resetToView     = usePoTransferStore((s) => s.resetToView)

  // ── Local flags / lookups ──────────────────────────────────────────────────
  const [saving,   setSaving]   = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [navLoading, setNavLoading] = useState(false)
  const [deleteModalOpen, setDeleteModalOpen] = useState(false)

  const [parameters,  setParameters]  = useState<PoParameters | null>(null)
  const [preChecks,   setPreChecks]   = useState<PoPreAddChecks | null>(null)
  // Record-navigation index — every PO number in the active FY, ascending.
  const [navList, setNavList] = useState<{ poNo: number; poDate: string }[]>([])

  const [orderTypes, setOrderTypes] = useState<OrderTypeOption[]>([])
  const [carriers,   setCarriers]   = useState<CarrierOption[]>([])
  const [formTypes,  setFormTypes]  = useState<FormTypeOption[]>([])
  const [suppliers,  setSuppliers]  = useState<SupplierOption[]>([])
  const [banks,      setBanks]      = useState<BankOption[]>([])
  const [lookupsLoaded,  setLookupsLoaded]  = useState(false)
  const [lookupsLoading, setLookupsLoading] = useState(false)
  const [lookupsError,   setLookupsError]   = useState<string | null>(null)

  // GST route for the current supplier (server-resolved, Q4). Applies to all lines.
  const [gstRoute, setGstRoute] = useState<GstRoute>('LOCAL')

  // Working line set: VIEW reads the saved PO; ADD/DELETE use draft lines.
  // Memoised so the `?? []` fallback doesn't churn `totals` every render.
  const lines = useMemo(
    () => (mode === 'VIEW' ? currentPo?.lines ?? [] : draftLines),
    [mode, currentPo, draftLines],
  )

  // ── Load lookups on mount ───────────────────────────────────────────────────
  const loadLookups = useCallback(async () => {
    if (!divCode) return
    setLookupsLoading(true)
    setLookupsError(null)
    try {
      const [params, types, cars, forms] = await Promise.all([
        poApi.getParameters(divCode),
        poApi.getOrderTypes(),
        poApi.getCarriers(),
        poApi.getFormTypes(),
      ])
      setParameters(params)
      setOrderTypes(types)
      setCarriers(cars)
      setFormTypes(forms)
      setLookupsLoaded(true)
    } catch {
      setLookupsError('Failed to load reference data. Click Retry to reload.')
    } finally {
      setLookupsLoading(false)
    }
  }, [divCode])

  useEffect(() => {
    if (!divCode) return
    void loadLookups()
  }, [divCode, loadLookups])

  // Supplier list — loaded in full once (on first dropdown open). The Select
  // then filters the loaded options client-side (UX-3 — list appears immediately).
  const suppliersLoadedRef = useRef(false)
  const loadSuppliers = useCallback(async () => {
    if (!divCode || suppliersLoadedRef.current) return
    try {
      setSuppliers(await poApi.getSuppliers(divCode))
      suppliersLoadedRef.current = true
    } catch { /* surfaced by caller */ }
  }, [divCode])
  const loadBanks = useCallback(async (search?: string) => {
    try { setBanks(await poApi.getBanks(search)) } catch { /* noop */ }
  }, [])

  // ── Pre-add checks (FSD §4.1) ──────────────────────────────────────────────
  const runPreChecks = useCallback(async (): Promise<PoPreAddChecks | null> => {
    if (!divCode) return null
    try {
      const result = await poApi.runPreAddChecks(divCode)
      setPreChecks(result)
      return result
    } catch { return null }
  }, [divCode])

  // ── GST routing adapter — SERVER-SIDE placeholder (Q4) ─────────────────────
  // The ONLY source of a line's route. UI displays the result; never derives it.
  // TODO[Q4]: confirm contract — inline on supplier select vs dedicated call.
  const resolveGstRoute = useCallback(async (supplier: string): Promise<GstRoute> => {
    if (!supplier) return 'LOCAL'
    try {
      const res = await poApi.getGstRouting(divCode, supplier)
      return res.route
    } catch {
      // Provisional fallback until Q4 is confirmed — flagged, not authoritative.
      return 'LOCAL'
    }
  }, [divCode])

  // Supplier selection: fill GSTIN/GST State (UX-06) and re-route all lines (Q4).
  const onSupplierChange = useCallback(async (supplier: SupplierOption | null) => {
    headerForm.setFieldsValue({
      supplier: supplier?.slCode ?? '',
      gstin:    supplier?.gstinNo ?? '',
      gstState: supplier?.gstStateName ?? '',
    })
    const route = supplier ? await resolveGstRoute(supplier.slCode) : 'LOCAL'
    setGstRoute(route)
    // Re-apply route to every working line and recompute its GST split.
    setDraftLines(draftLines.map((l) => recalcLine({ ...l, route })))
  }, [headerForm, resolveGstRoute, draftLines, setDraftLines])

  // ── Header tax propagation — SERVER-SIDE handler (Q5) ──────────────────────
  // Abstracted so final behaviour can be wired without touching callers.
  // TODO[Q5]: VB6 HeadTaxload → PATCH /po/{id}/lines/apply-header-tax requires a
  //   SAVED PO id. Pre-save (ADD) behaviour is UNCONFIRMED — no client-side loop.
  const propagateHeaderTax = useCallback(async (changes: {
    cgstPer?: number; sgstPer?: number; igstPer?: number; tcsPer?: number
    discPer?: number; packPer?: number; insurPer?: number; freightAmt?: number
  }): Promise<void> => {
    const poNo = currentPo?.poNo
    if (!poNo || mode === 'ADD') {
      // Provisional: propagation deferred to save-time server computation.
      notificationService.info('Header Tax', 'Header tax will be applied to all lines when the PO is saved.')
      return
    }
    try {
      const updated = await poApi.applyHeaderTax(divCode, poNo, currentPo!.poDate, changes)
      setCurrentPo(updated)
      notificationService.success('Header Tax Applied', 'Header tax has been applied to all lines.')
    } catch (err) {
      notificationService.error('Header Tax Failed', getErrorMessage(err))
    }
  }, [currentPo, mode, divCode, setCurrentPo])

  // ── PR Picker → add lines (VB6 delmodok_Click) ─────────────────────────────
  const mapEligibleToLine = (pr: EligiblePrLine, lineNo: number): PoLine =>
    recalcLine({
      lineNo,
      prSno:         pr.prSno,
      itemCode:      pr.itemCode,
      itemName:      pr.itemName,
      uom:           pr.uom,
      prNo:          pr.prNo,
      prDate:        pr.prDate,
      rate:          0,                 // BR-07: user must enter > 0 before save
      qty:           pr.balanceQty,     // defaults to full balance (≤ balance, BR-05)
      balanceQty:    pr.balanceQty,
      value:         0,
      taxCode:       pr.gstTaxCode,
      taxPer:        0,
      taxAmt:        0,
      hsnCode:       pr.hsnCode,        // blank ⇒ BR-10 warn (block at save)
      cgstPer:       pr.cgstPer,
      cgstAmt:       0,
      sgstPer:       pr.sgstPer,
      sgstAmt:       0,
      igstPer:       pr.igstPer,
      igstAmt:       0,
      tcsPer:        0,
      tcsAmt:        0,
      cgstCode:      '',
      sgstCode:      '',
      igstCode:      '',
      requesterId:   pr.requesterId,
      requesterName: pr.requesterName,
      route:         gstRoute,          // server-resolved route (Q4)
      deleteReason:  '',
    })

  const toDeliveryLine = (line: PoLine): DeliveryScheduleLine => ({
    lineNo:   line.lineNo,
    itemCode: line.itemCode,
    itemName: line.itemName,
    uom:      line.uom,
    prNo:     line.prNo,
    poQty:    line.qty,
    slots:    [{ slotNo: 1, shDate: null, qty: line.qty, remarks: '' }],
  })

  const addPrLines = (selected: EligiblePrLine[]) => {
    if (selected.length === 0) return
    const start = draftLines.length
    const newLines = selected.map((pr, i) => mapEligibleToLine(pr, start + i + 1))
    setDraftLines([...draftLines, ...newLines])
    setDeliveryLines([...deliveryLines, ...newLines.map(toDeliveryLine)])
    notificationService.success(
      'PR Lines Loaded',
      `${newLines.length} PR line${newLines.length !== 1 ? 's' : ''} loaded. Set rates and save.`,
    )
  }

  // Edit Rate / Qty inline → recompute line + keep delivery poQty in sync.
  const updateLineRateQty = (lineNo: number, patch: { rate?: number; qty?: number }) => {
    const target = draftLines.find((l) => l.lineNo === lineNo)
    if (!target) return
    const merged = recalcLine({ ...target, ...patch })
    updateDraftLine(lineNo, merged)
    if (patch.qty !== undefined) {
      setDeliveryLines(deliveryLines.map((d) =>
        d.lineNo === lineNo ? { ...d, poQty: merged.qty } : d,
      ))
    }
  }

  // GST modal apply → merge tax detail, recompute, refresh row.
  const applyGstDetail = (lineNo: number, detail: LineTaxDetail) => {
    const target = draftLines.find((l) => l.lineNo === lineNo)
    if (!target) return
    updateDraftLine(lineNo, recalcLine({ ...target, ...detail }))
    closeGstModal()
  }

  // Delete-mode: header default reason auto-propagates to all lines (BR-04 step 2).
  const setDefaultDeleteReason = (reason: string) => {
    setDraftLines(draftLines.map((l) => ({ ...l, deleteReason: reason })))
  }

  // Per-line delete reason override (BR-04 step 3).
  const setLineDeleteReason = (lineNo: number, reason: string) =>
    updateDraftLine(lineNo, { deleteReason: reason })

  // ── Mode transitions ───────────────────────────────────────────────────────
  const headerDefaults = (): Partial<PoHeaderFormValues> => ({
    poDate:      processingDate ? dayjs(processingDate) : dayjs(),
    inspect:     'YES',
    currency:    parameters?.currCode ?? 'INR',
    currRate:    1,
    freightType: 'PAID',
    discApp:     'BEFORE',
    packApp:     'BEFORE',
    cessApp:     'BEFORE',
    payMode:     'DIRECT',
    cancelled:   false,
  })

  const enterAddMode = async () => {
    const result = await runPreChecks()
    // BR-02 gate: no eligible PR lines ⇒ cannot start an Add.
    if (result && result.approvedPrLinesExist === false) {
      notificationService.warning('No Eligible PR Lines', 'There are no approved PR lines available to convert.')
      return
    }
    headerForm.resetFields()
    headerForm.setFieldsValue(headerDefaults())
    setDraftLines([])
    setDeliveryLines([])
    setGstRoute('LOCAL')
    setMode('ADD')
  }

  const enterDeleteMode = () => {
    if (!currentPo) return
    // GRN guard (BR-03) is enforced server-side (HTTP 409); the confirm step
    // surfaces it. Seed draft lines so per-line delete reasons are editable.
    setDraftLines(currentPo.lines.map((l) => ({ ...l, deleteReason: '' })))
    setDeliveryLines(currentPo.delivery ?? [])
    setMode('DELETE')
  }

  const cancelMode = () => {
    resetToView()
    if (currentPo) fillHeaderFromPo(currentPo)
    notificationService.info('Operation Cancelled', 'The current operation was cancelled.')
  }

  // ── Load existing PO (VIEW) ────────────────────────────────────────────────
  function fillHeaderFromPo(po: PoHeader) {
    headerForm.setFieldsValue({
      poDate:        dayjs(po.poDate),
      orderType:     po.orderType,
      supplier:      po.supplier,
      gstin:         po.gstin,
      gstState:      po.gstState,
      inspect:       po.inspect,
      formType:      po.formType,
      refNo:         po.refNo,
      refDate:       po.refDate ? dayjs(po.refDate) : null,
      currency:      po.currency,
      currRate:      po.currRate,
      remarks:       po.remarks,
      cgstPer:       po.cgstPer,
      sgstPer:       po.sgstPer,
      igstPer:       po.igstPer,
      tcsPer:        po.tcsPer,
      discPer:       po.discPer,
      freightAmt:    po.freightAmt,
      packPer:       po.packPer,
      insurPer:      po.insurPer,
      addTaxPer:     po.addTaxPer,
      fileNo:        po.fileNo,
      fcaFob:        po.fcaFob,
      freightType:   po.freightType,
      discApp:       po.discApp,
      packApp:       po.packApp,
      cessApp:       po.cessApp,
      payMode:       po.payMode,
      directInstr:   po.directInstr,
      bankCode:      po.bankCode,
      paymentTerms:  po.paymentTerms,
      advPer:        po.advPer,
      modeOfPayment: po.modeOfPayment,
      payRef:        po.payRef,
      payRefDate:    po.payRefDate ? dayjs(po.payRefDate) : null,
      chequeNo:      po.chequeNo,
      chequeDate:    po.chequeDate ? dayjs(po.chequeDate) : null,
      carrier:          po.carrier,
      creditDays:       po.creditDays,
      deliveryDate:     po.deliveryDate ? dayjs(po.deliveryDate) : null,
      deliveryLocation: po.deliveryLocation,
      billingAddress:   po.billingAddress,
      specialInstr:     po.specialInstr,
      despatch:         po.despatch,
      purpose:          po.purpose,
      otherLevies:      po.otherLevies,
      pricingTerms:     po.pricingTerms,
      packForwarding:   po.packForwarding,
      insurance:        po.insurance,
      freight:          po.freight,
      reminder:      po.reminder,
      status:        po.status,
      cancelled:     po.cancelled,
      cancelDate:    po.cancelDate ? dayjs(po.cancelDate) : null,
      cancelReason:  po.cancelReason,
      approved:      po.approved,
      approvedBy:    po.approvedBy,
    })
  }

  const loadRecord = async (poNo: number, poDate: string) => {
    if (!divCode) return
    setNavLoading(true)
    try {
      const po = await poApi.getById(divCode, poNo, poDate)
      setCurrentPo(po)
      fillHeaderFromPo(po)
      setMode('VIEW')
    } catch (err) {
      notificationService.error('Failed to Load Record', getErrorMessage(err))
    } finally {
      setNavLoading(false)
    }
  }

  const loadLastRecord = useCallback(async () => {
    if (!divCode) return
    const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
    setNavLoading(true)
    try {
      const po = await poApi.getLastRecord(divCode, yfDate, ylDate)
      if (po) { setCurrentPo(po); fillHeaderFromPo(po) }
    } catch { /* empty list is fine */ }
    finally { setNavLoading(false) }
  }, [divCode, processingDate]) // eslint-disable-line react-hooks/exhaustive-deps

  // Build the navigation index (all PO numbers in the FY, ascending) for the
  // First / Prev / Next / Last toolbar buttons. Refreshed after Save/Delete.
  const loadNavList = useCallback(async () => {
    if (!divCode) return
    const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
    try {
      const list = await poApi.getList(divCode, yfDate, ylDate, { pageSize: 2000 })
      setNavList(
        [...list].sort((a, b) => a.poNo - b.poNo).map((s) => ({ poNo: s.poNo, poDate: s.poDate })),
      )
    } catch { setNavList([]) }
  }, [divCode, processingDate])

  // ── Client-side validation (mirrors BR register; server is authoritative) ──
  const validateLines = (): boolean => {
    const working = draftLines.filter((l) => l.itemCode.trim() !== '')
    if (working.length === 0) {
      notificationService.warning('No Line Items', 'Add at least one PR line before saving.')
      return false
    }
    // BR-07 Rate > 0
    const zeroRate = working.filter((l) => (l.rate ?? 0) <= 0)
    if (zeroRate.length) {
      notificationService.warning('Validation Failed', `Rate must be greater than 0 for: ${zeroRate.map((l) => l.itemCode).join(', ')}.`)
      return false
    }
    // BR-06 Qty > 0
    const zeroQty = working.filter((l) => (l.qty ?? 0) <= 0)
    if (zeroQty.length) {
      notificationService.warning('Validation Failed', `Quantity must be greater than 0 for: ${zeroQty.map((l) => l.itemCode).join(', ')}.`)
      return false
    }
    // BR-05 Qty ≤ PR balance
    const overBalance = working.filter((l) => (l.qty ?? 0) > (l.balanceQty ?? 0))
    if (overBalance.length) {
      notificationService.warning('Validation Failed', `Quantity exceeds PR balance for: ${overBalance.map((l) => l.itemCode).join(', ')}.`)
      return false
    }
    // BR-08 Tax Code mandatory
    const noTaxCode = working.filter((l) => !l.taxCode.trim())
    if (noTaxCode.length) {
      notificationService.warning('Mandatory Fields Missing', `Tax Code is required for: ${noTaxCode.map((l) => l.itemCode).join(', ')}.`)
      return false
    }
    // BR-10 HSN mandatory (SPINRISE enforces at save; server re-checks → 400)
    const noHsn = working.filter((l) => !l.hsnCode.trim())
    if (noHsn.length) {
      notificationService.warning('Mandatory Fields Missing', `HSN Code is required for: ${noHsn.map((l) => l.itemCode).join(', ')}. Configure it in Item Master.`)
      return false
    }
    // UX-01 delivery reconciliation — block over-allocation; under is allowed.
    const overSched = deliveryLines.filter((d) =>
      round3(d.slots.reduce((s, x) => s + (Number(x.qty) || 0), 0)) > round3(d.poQty),
    )
    if (overSched.length) {
      notificationService.warning('Delivery Schedule Mismatch', `Scheduled quantity exceeds PO quantity for: ${overSched.map((d) => d.itemCode).join(', ')}.`)
      return false
    }
    return true
  }

  // Cross-field header rules not expressible as single-field AntD `required`.
  const validateHeaderConditionals = (v: PoHeaderFormValues): boolean => {
    // BR-15 Bank → Bank Code + Cheque No.
    if (v.payMode === 'BANK') {
      if (!v.bankCode?.trim()) { notificationService.warning('Mandatory Fields Missing', 'Bank is required for bank payment.'); return false }
      if (!v.chequeNo?.trim()) { notificationService.warning('Mandatory Fields Missing', 'Cheque No. is required for bank payment.'); return false }
    }
    // BR-15 HO order type → Pricing Terms
    if (v.orderType === HO_TYPE && !v.pricingTerms?.trim()) {
      notificationService.warning('Mandatory Fields Missing', 'Pricing Terms is required for HO purchase type.'); return false
    }
    // BR-01 backdate guard (client mirror; server re-enforces)
    if (preChecks?.backDateFlag === 'N' && preChecks.maxPoDate && v.poDate) {
      const maxDate = dayjs(preChecks.maxPoDate)
      if (v.poDate.isBefore(maxDate, 'day')) {
        notificationService.warning('Invalid PO Date', `PO date must be ${maxDate.format('DD-MMM-YYYY')} or later.`); return false
      }
    }
    return true
  }

  // ── Build request (PO No NEVER sent — server allocates, CD-03) ─────────────
  const buildAddRequest = (v: PoHeaderFormValues): AddPoRequest => {
    const working = draftLines.filter((l) => l.itemCode.trim() !== '')
    const slotsFor = (lineNo: number) =>
      (deliveryLines.find((d) => d.lineNo === lineNo)?.slots ?? [])
        .filter((s) => (Number(s.qty) || 0) > 0 || s.shDate)

    const reqLines: SavePoLineRequest[] = working.map((l) => ({
      prSno:    l.prSno,
      itemCode: l.itemCode,
      rate:     l.rate,
      qty:      l.qty,
      taxCode:  l.taxCode,
      hsnCode:  l.hsnCode,
      cgstPer:  l.cgstPer,
      sgstPer:  l.sgstPer,
      igstPer:  l.igstPer,
      tcsPer:   l.tcsPer,
      cgstCode: l.cgstCode,
      sgstCode: l.sgstCode,
      igstCode: l.igstCode,
      route:    l.route,
      slots:    slotsFor(l.lineNo),
    }))

    // Guard the PO date: fall back to the processing date / today if the form
    // value is ever missing, so the request can never crash on `.format`.
    const poDateStr = fmtDate(v.poDate) ?? processingDate ?? dayjs().format('YYYY-MM-DD')

    return {
      poDate: poDateStr,
      header: {
        poDate:        poDateStr,
        orderType:     v.orderType,
        orderTypeDesc: orderTypes.find((t) => t.poGrp === v.orderType)?.typName ?? '',
        supplier:      v.supplier,
        supplierName:  suppliers.find((s) => s.slCode === v.supplier)?.slName ?? '',
        gstin:         v.gstin,
        gstState:      v.gstState,
        inspect:       v.inspect,
        roundOff:      totals.roundOff,
        orderValue:    totals.orderValue,
        formType:      v.formType,
        refNo:         v.refNo,
        refDate:       fmtDate(v.refDate),
        currency:      v.currency,
        currRate:      v.currRate,
        remarks:       v.remarks,
        cgstPer:       v.cgstPer, sgstPer: v.sgstPer, igstPer: v.igstPer, tcsPer: v.tcsPer,
        discPer:       v.discPer, cessPer: v.cessPer, aedPer: v.aedPer,
        freightAmt:    v.freightAmt, packPer: v.packPer, insurPer: v.insurPer,
        surchargePer:  v.surchargePer, addTaxPer: v.addTaxPer, fileNo: v.fileNo, fcaFob: v.fcaFob,
        freightType:   v.freightType, discApp: v.discApp, packApp: v.packApp, cessApp: v.cessApp,
        payMode:       v.payMode, directInstr: v.directInstr, bankCode: v.bankCode,
        paymentTerms:  v.paymentTerms, advPer: v.advPer, advAmt: 0,
        modeOfPayment: v.modeOfPayment, payRef: v.payRef, payRefDate: fmtDate(v.payRefDate),
        chequeNo:      v.chequeNo, chequeDate: fmtDate(v.chequeDate),
        carrier:       v.carrier, creditDays: v.creditDays, deliveryDate: fmtDate(v.deliveryDate),
        deliveryLocation: v.deliveryLocation, billingAddress: v.billingAddress,
        specialInstr:  v.specialInstr, despatch: v.despatch, purpose: v.purpose,
        otherLevies:   v.otherLevies, pricingTerms: v.pricingTerms,
        packForwarding: v.packForwarding, insurance: v.insurance, freight: v.freight,
        reminder:      v.reminder, status: v.status, cancelled: v.cancelled,
        cancelDate:    fmtDate(v.cancelDate), cancelReason: v.cancelReason,
        approved:      v.approved, approvedBy: v.approvedBy,
        amdOrderNo: null, amdDate: null, amdRefNo: null, amdRefDate: null,
        approvalStatus: '', printStatus: '', firstLevelApp: '', conflg: '',
        createdBy: '', createdDt: '', userId: '',
      },
      lines: reqLines,
    }
  }

  // ── Save (ADD only here; Modify is a separate screen) ──────────────────────
  const doSave = async () => {
    let values: PoHeaderFormValues
    try { values = await headerForm.validateFields() }   // BR-11..14 via field rules (HF-19a)
    catch { notificationService.warning('Mandatory Fields Missing', 'Please fill in all required fields.'); return }

    if (!validateHeaderConditionals(values)) return       // BR-15, BR-01
    if (!validateLines()) return                          // BR-05/06/07/08/10, UX-01

    setSaving(true)
    try {
      const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
      const request = buildAddRequest(values)
      // Server allocates the PO number atomically after validation (CD-03 / UX-04).
      const result = await poApi.addPo(divCode, yfDate, ylDate, request)
      const saved = await poApi.getById(divCode, result.poNo, result.poDate)
      setCurrentPo(saved)
      fillHeaderFromPo(saved)
      resetToView()
      void loadNavList()   // new PO joins the navigation index
      notificationService.success('Purchase Order Saved Successfully', `Purchase Order ${formatPoNo(result.poNo)} was created.`)
    } catch (err) {
      // BR-16/17 budget rejections are SERVER-DRIVEN — surface the server message
      // verbatim. TODO[BR-16/17]: when the contract is final, branch on a typed
      // budget-error code for inline field highlighting (provisional: message only).
      notificationService.error('Failed to Save Purchase Order', getErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  // ── Delete (FULL cascade; GRN guard server-side → 409) ─────────────────────
  const handleDeleteClick = () => {
    if (!currentPo?.poNo) return
    setDeleteModalOpen(true)
  }

  const handleDeleteConfirm = async (defaultReason: string): Promise<boolean> => {
    if (!currentPo?.poNo) return false
    // BR-04: every line must carry a non-empty delete reason.
    const blank = draftLines.find((l) => !l.deleteReason.trim())
    if (blank) {
      notificationService.warning('Delete Reason Required', 'A delete reason is mandatory on every line.')
      return false
    }
    setDeleteModalOpen(false)
    setDeleting(true)
    try {
      await poApi.deletePo(divCode, {
        poNo:          currentPo.poNo,
        poDate:        currentPo.poDate,
        deleteMode:    'FULL',
        defaultReason,
        lineReasons:   draftLines.map((l) => ({ prSno: l.prSno, deleteReason: l.deleteReason.trim() })),
      })
      notificationService.success('Purchase Order Deleted', `${formatPoNo(currentPo.poNo)} deleted. PR quantities reversed.`)
      resetToView()
      await loadLastRecord()
      void loadNavList()   // drop the deleted PO from the navigation index
      return true
    } catch (err) {
      // BR-03: GRN raised → HTTP 409. Surface the (server) guard message.
      const msg = err instanceof AppError && err.status === 409
        ? 'Cannot delete — a GRN has already been raised for this Purchase Order.'
        : getErrorMessage(err)
      notificationService.error('Failed to Delete Purchase Order', msg)
      return false
    } finally {
      setDeleting(false)
    }
  }

  // ── Totals (KPI strip + header Order Value / Total Order Value) ─────────────
  const totals = useMemo(() => {
    let orderValue = 0, totalGst = 0, totalTcs = 0
    const qtyByUom: Record<string, number> = {}
    for (const l of lines) {
      const v = mode === 'VIEW' ? l.value : calcLineValue(l.rate, l.qty)
      orderValue += v
      totalGst   += (l.cgstAmt || 0) + (l.sgstAmt || 0) + (l.igstAmt || 0)
      totalTcs   += l.tcsAmt || 0
      if (l.uom) qtyByUom[l.uom] = (qtyByUom[l.uom] || 0) + (l.qty || 0)
    }
    orderValue = round2(orderValue)
    totalGst   = round2(totalGst)
    totalTcs   = round2(totalTcs)
    // Round-off is server-authoritative (TaxOK_Click, §5.5); 0 pre-save.
    const roundOff = currentPo?.roundOff ?? 0
    return {
      totalLines: lines.length,
      orderValue,
      totalGst,
      totalTcs,
      roundOff,
      totalOrderValue: round2(orderValue + totalGst + totalTcs + roundOff),
      qtyByUom,
    }
  }, [lines, mode, currentPo])

  // Header "Order Value" (RO) is bound by the component to `totals.orderValue`
  // (UI-03) — kept out of the form so there is a single computed source.

  const pageBusy = saving || deleting || navLoading

  // ── Record navigation (First / Prev / Next / Last) ─────────────────────────
  // Position within the FY index; -1 when the current PO isn't in the list yet.
  const currentIndex = useMemo(
    () => (currentPo?.poNo ? navList.findIndex((r) => r.poNo === currentPo.poNo) : -1),
    [navList, currentPo],
  )
  const hasRecords = navList.length > 0
  const canPrev = currentIndex > 0
  const canNext = currentIndex >= 0 && currentIndex < navList.length - 1

  const goToIndex = async (idx: number) => {
    const rec = navList[idx]
    if (rec) await loadRecord(rec.poNo, rec.poDate)
  }
  const goFirst = () => { if (hasRecords) void goToIndex(0) }
  const goPrev  = () => { if (canPrev)    void goToIndex(currentIndex - 1) }
  const goNext  = () => { if (canNext)    void goToIndex(currentIndex + 1) }
  const goLast  = () => { if (hasRecords) void goToIndex(navList.length - 1) }

  // ── Ctrl+S save shortcut (ADD only) ────────────────────────────────────────
  const doSaveRef = useRef(doSave)
  doSaveRef.current = doSave
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === 's') {
        e.preventDefault()
        if (!saving && !deleting && mode === 'ADD') void doSaveRef.current()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [saving, deleting, mode])

  return {
    // identity / form
    headerForm, divCode, processingDate, authUser,
    // mode + flags
    mode, setMode, pageBusy, saving, deleting, navLoading,
    deleteModalOpen, setDeleteModalOpen,
    // data
    currentPo, lines, draftLines, deliveryLines, gstRoute,
    // lookups
    parameters, preChecks,
    orderTypes, carriers, formTypes, suppliers, banks,
    lookupsLoaded, lookupsLoading, lookupsError,
    loadLookups, loadSuppliers, loadBanks, runPreChecks,
    // line ops
    addPrLines, updateLineRateQty, removeDraftLine, applyGstDetail,
    setDefaultDeleteReason, setLineDeleteReason,
    // delivery row ops (OQ-NEW B — item-wise open grid, unlimited rows)
    addSlot, updateSlot, removeSlot,
    // gst modal / selection
    gstLineNo, openGstModal, closeGstModal, selectedLineNo, setSelectedLineNo,
    // pending-isolated handlers (Q4 / Q5)
    onSupplierChange, propagateHeaderTax,
    // mode transitions
    enterAddMode, enterDeleteMode, cancelMode,
    // record nav
    loadRecord, loadLastRecord, loadNavList,
    goFirst, goPrev, goNext, goLast, canPrev, canNext, hasRecords,
    // actions
    doSave, handleDeleteClick, handleDeleteConfirm,
    // totals
    totals,
  }
}
