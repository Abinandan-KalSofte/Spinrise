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
import { getFYBounds, getFYEndDate } from '@/shared/lib/dateUtils'
import { getErrorMessage, AppError } from '@/shared/lib/errorHandler'
import { formatPoNo, resolveGstStateDisplay } from '../types'
import { usePoTransferStore } from '../store/usePoTransferStore'
import { notificationService } from '@/shared/lib/notification'
import {
  applyGstRouteToDetail,
  applyGstRouteToLine,
  clampNonNegativeNumber,
  getCurrentSystemDate,
  getCurrentSystemDateIso,
  getGstRouteFromState,
  isNegativeNumber,
} from '../utils/poTransferRules'
import * as poApi from '../api/poTransferApi'
import type {
  PoHeader, PoLine, PoParameters, PoPreAddChecks,
  SupplierOption, OrderTypeOption, CarrierOption, BankOption, FormTypeOption,
  AddressOption, CurrencyOption, PayTermOption,
  EligiblePrLine, DeliveryScheduleLine, AddPoRequest, SavePoLineRequest,
  GstRoute, LineTaxDetail, GstTaxCodeOption,
} from '../types'

// Per-line charge / additional-tax defaults sourced from the header tab. Re-read
// live on each GST-modal open so unsaved lines pick up the latest header values.
export interface GstHeaderDefaults {
  discPer:         number
  packingPer:      number
  freightPer:      number
  insurancePer:    number
  addTaxPer:       number
  cessPer:         number
  tcsPer:          number
  fcaFob:          number
  freightPos:      'BEFORE' | 'AFTER'
  insuranceDuty:   'BEFORE' | 'AFTER'
  cessTaxPos:      'BEFORE' | 'AFTER'
  exciseIncPacking: 'Y' | 'N'
  freightType:     'PAID' | 'TOPAY'
  discApp:         'BEFORE' | 'AFTER'
  packApp:         'BEFORE' | 'AFTER'
}

// ── Header tab key type + field-to-tab map (used for smart validation nav) ────
export type HeaderTabKey = 'order' | 'tax' | 'payment' | 'instructions' | 'cancel' | 'amendment' | 'approval'

export const FIELD_TAB_MAP: Record<string, HeaderTabKey> = {
  // Order Details
  poDate: 'order', orderType: 'order', supplier: 'order', gstin: 'order',
  gstState: 'order', inspect: 'order', formType: 'order', refNo: 'order',
  refDate: 'order', currency: 'order', currRate: 'order', remarks: 'order', roundOff: 'order',
  // Tax / Discount
  cgstPer: 'tax', sgstPer: 'tax', igstPer: 'tax', tcsPer: 'tax', fcaFob: 'tax', fileNo: 'tax',
  discPer: 'tax', discAmt: 'tax', freightPer: 'tax', freightAmt: 'tax',
  packPer: 'tax', packAmt: 'tax', insurPer: 'tax', insurAmt: 'tax',
  addTaxPer: 'tax', addTaxAmtHdr: 'tax', cessPer: 'tax', cessAmt: 'tax',
  freightType: 'tax', freightPos: 'tax', discApp: 'tax', packApp: 'tax',
  insuranceDuty: 'tax', cessTaxPos: 'tax', exciseIncPacking: 'tax',
  // Payment
  payMode: 'payment', directInstr: 'payment', advAmt: 'payment', advPer: 'payment',
  modeOfPayment: 'payment', payRef: 'payment', payRefDate: 'payment',
  bankCode: 'payment', paymentTerms: 'payment', paymentTermCode: 'payment', chequeNo: 'payment', chequeDate: 'payment',
  // Instructions
  carrier: 'instructions', creditDays: 'instructions', deliveryDate: 'instructions',
  deliveryLocation: 'instructions', billingAddress: 'instructions', specialInstr: 'instructions',
  despatch: 'instructions', purpose: 'instructions', otherLevies: 'instructions',
  pricingTerms: 'instructions', packForwarding: 'instructions', insurance: 'instructions', freight: 'instructions',
  // Cancel / Status
  reminder: 'cancel', status: 'cancel', cancelled: 'cancel', cancelDate: 'cancel',
  cancelReason: 'cancel', approved: 'cancel', approvedBy: 'cancel',
}

// ── Numeric helpers (project precision: Value/Amt 2dp, Qty 3dp) ──────────────
const round2 = (n: number) => Math.round(n * 100) / 100
const round3 = (n: number) => Math.round(n * 1000) / 1000
const fmtDate = (d: Dayjs | null | undefined) => (d ? d.format('YYYY-MM-DD') : null)
// Normalise a PR date string (ISO, or display form like '01-Jun-26') to
// 'YYYY-MM-DD' for the save payload. Returns '' when missing/unparseable so the
// save-time guard can block it (B1 — server validates PR balance against prDate).
const toIsoDate = (d: string | null | undefined): string => {
  if (!d) return ''
  if (/^\d{4}-\d{2}-\d{2}/.test(d)) return d.slice(0, 10)   // already ISO
  const p = dayjs(d)
  return p.isValid() ? p.format('YYYY-MM-DD') : ''
}

// ── Pure line recompute ──────────────────────────────────────────────────────
// Standard Indian GST formula (CR-012). GST is computed on the assessable base,
// which adjusts for discount/freight/packing/insurance position flags (BEFORE/AFTER).
//
//   Taxable Value  = Rate × Qty
//   Discount       = Taxable × disc%
//   Packing        = (Taxable − Discount) × packing%
//   Freight        = Taxable × freight%
//   Insurance      = Taxable × insurance%
//   GST Base       = Taxable ± charges per position flags
//   CGST/SGST/IGST = GST Base × rate%   (route-driven, server Q4)
//   TCS            = Taxable × tcs%     (always on raw taxable)
//   Net Amount     = Taxable − Discount + Packing + Freight + Insurance + All Tax
// FCA/FOB is a pass-through reference value and is not folded into Net.
const calcLineValue = (rate: number, qty: number) => round2((rate || 0) * (qty || 0))
const pctOf = (base: number, pct: number) => round2((base * (pct || 0)) / 100)

const recalcLine = (line: PoLine): PoLine => {
  const taxable = calcLineValue(line.rate, line.qty)
  const isLocal = line.route === 'LOCAL'

  const discountAmt  = pctOf(taxable, line.discPer)
  const packingAmt   = pctOf(taxable - discountAmt, line.packingPer)
  const freightAmt   = pctOf(taxable, line.freightPer)
  const insuranceAmt = pctOf(taxable, line.insurancePer)
  const cessAmt      = pctOf(taxable, line.cessPer ?? 0)
  const addTaxAmt    = pctOf(taxable, line.addTaxPer)
  const tcsAmt       = pctOf(taxable, line.tcsPer)

  // CR-012: assessable base adjusts per position flags
  let gstBase = taxable
  if (line.discApp       === 'BEFORE') gstBase = round2(gstBase - discountAmt)
  if (line.freightPos    === 'BEFORE') gstBase = round2(gstBase + freightAmt)
  if (line.packApp       === 'BEFORE') gstBase = round2(gstBase + packingAmt)
  if (line.insuranceDuty === 'BEFORE') gstBase = round2(gstBase + insuranceAmt)

  const cgstAmt = isLocal ? pctOf(gstBase, line.cgstPer) : 0
  const sgstAmt = isLocal ? pctOf(gstBase, line.sgstPer) : 0
  const igstAmt = isLocal ? 0 : pctOf(gstBase, line.igstPer)

  const gstTotal = round2(cgstAmt + sgstAmt + igstAmt)
  const totalTax = round2(gstTotal + addTaxAmt + tcsAmt + cessAmt)
  const netAmount = round2(
    taxable - discountAmt + packingAmt + freightAmt + insuranceAmt + totalTax,
  )

  return {
    ...line,
    value: taxable,
    taxableValue: taxable,
    cgstAmt, sgstAmt, igstAmt, tcsAmt, addTaxAmt,
    netAmount,
    taxAmt: gstTotal,
    taxPer: isLocal ? (line.cgstPer || 0) + (line.sgstPer || 0) : (line.igstPer || 0),
  }
}

// ── Header form values (AntD Form; dates as Dayjs) ───────────────────────────
export interface PoHeaderFormValues {
  // Display-only, fed from hook state (not sent in requests):
  poNo:          string         // formatted server PO number (blank pre-save, CD-03)
  poValue:       string         // formatted computed Total Order Value (UI-03)
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
  roundOff:      number         // editable; drives Order Value recalc
  // Tax / Discount (header-level)
  // Note: cgstPer/sgstPer/igstPer hidden from UI (GST comes from line-level only)
  cgstPer:       number
  sgstPer:       number
  igstPer:       number
  tcsPer:        number
  discPer:       number
  discAmt:       number         // computed from discPer × line item value
  freightAmt:    number
  freightPer:    number         // computed from freightAmt / line item value
  packPer:       number
  packAmt:       number         // computed from packPer × line item value
  insurPer:      number
  insurAmt:      number         // computed from insurPer × line item value
  addTaxPer:     number
  addTaxAmtHdr:  number         // computed from addTaxPer × line item value
  cessPer:       number
  cessAmt:       number
  fileNo:        string
  fcaFob:        number
  freightType:   'PAID' | 'TOPAY'
  freightPos:    'BEFORE' | 'AFTER'   // freight position relative to tax
  discApp:       'BEFORE' | 'AFTER'
  packApp:       'BEFORE' | 'AFTER'
  insuranceDuty: 'BEFORE' | 'AFTER'  // insurance before/after duty
  cessTaxPos:    'BEFORE' | 'AFTER'  // cess before/after tax
  exciseIncPacking: 'Y' | 'N'
  // Payment
  payMode:       'DIRECT' | 'BANK'
  directInstr:   string
  advAmt:        number         // advance amount (replaces advPer)
  modeOfPayment: string
  payRef:        string
  payRefDate:    Dayjs | null
  bankCode:         string       // BR-15 (when BANK)
  paymentTerms:     string
  paymentTermCode:  string       // Ig_PayTerm lookup code — stored in paytermcode column
  chequeNo:         string       // BR-15 (when BANK)
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
  // Bumped by the operations that must land the user on the Header (Order
  // Details) tab — Add, Find→Load, Load Last, record navigation — but NOT by
  // Save. PoHeaderTabs resets its active tab to 'order' when this changes.
  const [headerTabResetKey, setHeaderTabResetKey] = useState(0)
  const resetToHeaderTab = useCallback(() => setHeaderTabResetKey((k) => k + 1), [])
  // Bumped on successful save so the page resets the body tab to "Item Details".
  const [bodyTabResetKey, setBodyTabResetKey] = useState(0)
  const resetBodyTab = useCallback(() => setBodyTabResetKey((k) => k + 1), [])
  const [deleteModalOpen, setDeleteModalOpen] = useState(false)

  const [parameters,  setParameters]  = useState<PoParameters | null>(null)
  const [preChecks,   setPreChecks]   = useState<PoPreAddChecks | null>(null)
  // Record-navigation index — every PO number in the active FY, ascending.
  const [navList, setNavList] = useState<{ poNo: number; poDate: string }[]>([])

  const [orderTypes,         setOrderTypes]         = useState<OrderTypeOption[]>([])
  const [carriers,           setCarriers]           = useState<CarrierOption[]>([])
  const [formTypes,          setFormTypes]          = useState<FormTypeOption[]>([])
  const [suppliers,          setSuppliers]          = useState<SupplierOption[]>([])
  const [banks,              setBanks]              = useState<BankOption[]>([])
  const [gstTaxCodes,        setGstTaxCodes]        = useState<GstTaxCodeOption[]>([])
  const [currencies,         setCurrencies]         = useState<CurrencyOption[]>([])
  const [deliveryLocations,  setDeliveryLocations]  = useState<AddressOption[]>([])
  const [billingAddresses,   setBillingAddresses]   = useState<AddressOption[]>([])
  const [pricingTermsOpts,   setPricingTermsOpts]   = useState<AddressOption[]>([])
  const [payTerms,           setPayTerms]           = useState<PayTermOption[]>([])
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

  // Live header-tab values → defaults for a line's GST/charge fields. Watched so
  // an unsaved line opened in the GST modal reflects the LATEST header values (§7).
  const hDiscPer          = Form.useWatch('discPer',          headerForm)
  const hPackPer          = Form.useWatch('packPer',          headerForm)
  const hFreightPer       = Form.useWatch('freightPer',       headerForm)
  const hInsurPer         = Form.useWatch('insurPer',         headerForm)
  const hAddTaxPer        = Form.useWatch('addTaxPer',        headerForm)
  const hCessPer          = Form.useWatch('cessPer',          headerForm)
  const hTcsPer           = Form.useWatch('tcsPer',           headerForm)
  const hFcaFob           = Form.useWatch('fcaFob',           headerForm)
  const hRoundOff         = Form.useWatch('roundOff',         headerForm)
  const hFreightPos       = Form.useWatch('freightPos',       headerForm)
  const hInsuranceDuty    = Form.useWatch('insuranceDuty',    headerForm)
  const hCessTaxPos       = Form.useWatch('cessTaxPos',       headerForm)
  const hExciseIncPacking = Form.useWatch('exciseIncPacking', headerForm)
  const hFreightType      = Form.useWatch('freightType',      headerForm)
  const hDiscApp          = Form.useWatch('discApp',          headerForm)
  const hPackApp          = Form.useWatch('packApp',          headerForm)
  const gstHeaderDefaults = useMemo<GstHeaderDefaults>(() => ({
    discPer:         hDiscPer    ?? 0,
    packingPer:      hPackPer    ?? 0,
    freightPer:      hFreightPer ?? 0,
    insurancePer:    hInsurPer   ?? 0,
    addTaxPer:       hAddTaxPer  ?? 0,
    cessPer:         hCessPer    ?? 0,
    tcsPer:          hTcsPer     ?? 0,
    fcaFob:          hFcaFob     ?? 0,
    freightPos:       (hFreightPos       as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
    insuranceDuty:    (hInsuranceDuty    as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
    cessTaxPos:       (hCessTaxPos       as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
    exciseIncPacking: (hExciseIncPacking as 'Y' | 'N' | undefined)           ?? 'N',
    freightType:      (hFreightType      as 'PAID' | 'TOPAY' | undefined)    ?? 'PAID',
    discApp:          (hDiscApp          as 'BEFORE' | 'AFTER' | undefined)  ?? 'BEFORE',
    packApp:          (hPackApp          as 'BEFORE' | 'AFTER' | undefined)  ?? 'BEFORE',
  }), [hDiscPer, hPackPer, hFreightPer, hInsurPer, hAddTaxPer, hCessPer, hTcsPer, hFcaFob,
       hFreightPos, hInsuranceDuty, hCessTaxPos, hExciseIncPacking,
       hFreightType, hDiscApp, hPackApp])

  // Grid tax sync: when header tax % fields change in ADD mode, propagate to all
  // unsaved lines (taxSaved=false) immediately. Rows with taxSaved=true retain
  // their manually-entered values (manual override rule, §GST Modal Sync).
  const draftLinesRef = useRef(draftLines)
  draftLinesRef.current = draftLines
  useEffect(() => {
    if (mode !== 'ADD') return
    const lines = draftLinesRef.current
    if (lines.length === 0) return
    setDraftLines(lines.map((l) => {
      if (l.taxSaved) return l
      return recalcLine({
        ...l,
        discPer:          hDiscPer          ?? 0,
        packingPer:       hPackPer          ?? 0,
        freightPer:       hFreightPer       ?? 0,
        insurancePer:     hInsurPer         ?? 0,
        addTaxPer:        hAddTaxPer        ?? 0,
        tcsPer:           hTcsPer           ?? 0,
        // CR-010: Before/After flag changes propagate immediately to unsaved lines
        freightPos:       (hFreightPos       as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
        insuranceDuty:    (hInsuranceDuty    as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
        cessTaxPos:       (hCessTaxPos       as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
        discApp:          (hDiscApp          as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
        packApp:          (hPackApp          as 'BEFORE' | 'AFTER' | undefined) ?? 'BEFORE',
        exciseIncPacking: (hExciseIncPacking as 'Y' | 'N'           | undefined) ?? 'N',
        freightType:      (hFreightType      as 'PAID' | 'TOPAY'    | undefined) ?? 'PAID',
      })
    }))
  }, [hDiscPer, hPackPer, hFreightPer, hInsurPer, hAddTaxPer, hTcsPer, // eslint-disable-line react-hooks/exhaustive-deps
      hFreightPos, hInsuranceDuty, hCessTaxPos, hDiscApp, hPackApp, hExciseIncPacking, hFreightType])

  // ── Load lookups on mount ───────────────────────────────────────────────────
  const loadLookups = useCallback(async () => {
    if (!divCode) return
    setLookupsLoading(true)
    setLookupsError(null)
    try {
      const [params, types, cars, forms, bankList, taxCodes, currList, delLocs, billAddrs, pricTerms, payTermList] =
        await Promise.all([
          poApi.getParameters(divCode),
          poApi.getOrderTypes(),
          poApi.getCarriers(),
          poApi.getFormTypes(),
          poApi.getBanks(divCode),
          poApi.getGstTaxCodes(),
          poApi.getCurrencies().catch(() => [] as CurrencyOption[]),
          poApi.getDeliveryLocations(divCode).catch(() => [] as AddressOption[]),
          poApi.getBillingAddresses(divCode).catch(() => [] as AddressOption[]),
          poApi.getPricingTerms().catch(() => [] as AddressOption[]),
          poApi.getPayTerms().catch(() => [] as PayTermOption[]),
        ])
      setParameters(params)
      setOrderTypes(types)
      setCarriers(cars)
      setFormTypes(forms)
      setBanks(bankList)
      setGstTaxCodes(taxCodes)
      setCurrencies(currList)
      setDeliveryLocations(delLocs)
      setBillingAddresses(billAddrs)
      setPricingTermsOpts(pricTerms)
      setPayTerms(payTermList)
      setLookupsLoaded(true)
    } catch {
      setLookupsError('Failed to load reference data. Click Retry to reload.')
    } finally {
      setLookupsLoading(false)
    }
  }, [divCode])

  // Fetch the lookup set once per division. The ref persists across React
  // StrictMode's dev-only setup→cleanup→setup cycle, so this yields exactly one
  // network call per divCode while still re-fetching if the division changes.
  const lookupsDivRef = useRef<string | null>(null)
  useEffect(() => {
    if (!divCode) return
    if (lookupsDivRef.current === divCode) return
    lookupsDivRef.current = divCode
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
  // Banks are loaded once with the rest of the reference data in loadLookups so
  // a loaded PO's bankCode resolves to its name in VIEW (no dropdown open needed).

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
  const normalizeLineForGstState = useCallback((line: PoLine, gstState: string) => {
    const route = getGstRouteFromState(gstState)
    return recalcLine(applyGstRouteToLine(line, route, gstTaxCodes))
  }, [gstTaxCodes])

  const normalizePoForGstState = useCallback((po: PoHeader): PoHeader => {
    const gstState = resolveGstStateDisplay(po.gstState)
    return {
      ...po,
      gstState,
      lines: po.lines.map((line) => normalizeLineForGstState(line, gstState)),
    }
  }, [normalizeLineForGstState])

  // Supplier selection: fill GSTIN/GST State (UX-06) and re-route all lines (Q4).
  const onSupplierChange = useCallback(async (supplier: SupplierOption | null) => {
    const gstState = resolveGstStateDisplay(supplier?.gstStateName ?? '', supplier?.gstStateCode)
    headerForm.setFieldsValue({
      supplier: supplier?.slCode ?? '',
      gstin:    supplier?.gstinNo ?? '',
      gstState,
    })
    // GST State Code validation — must not be empty for GST compliance.
    if (supplier && !supplier.gstStateCode?.trim()) {
      notificationService.warning(
        'GST State Code Not Available',
        'GST State Code is not available for this supplier.',
      )
    }
    const route = supplier ? getGstRouteFromState(gstState) : 'LOCAL'
    setGstRoute(route)
    setDraftLines(draftLinesRef.current.map((line) => normalizeLineForGstState(line, gstState)))
  }, [headerForm, normalizeLineForGstState, setDraftLines])

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
      const updated = normalizePoForGstState(await poApi.applyHeaderTax(divCode, poNo, currentPo!.poDate, changes))
      setCurrentPo(updated)
      notificationService.success('Header Tax Applied', 'Header tax has been applied to all lines.')
    } catch (err) {
      notificationService.error('Header Tax Failed', getErrorMessage(err))
    }
  }, [currentPo, mode, divCode, setCurrentPo])

  // ── PR Picker → add lines (VB6 delmodok_Click) ─────────────────────────────
  const mapEligibleToLine = (pr: EligiblePrLine, lineNo: number): PoLine =>
    normalizeLineForGstState({
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
      tcsPer:        gstHeaderDefaults.tcsPer,
      tcsAmt:        0,
      cgstCode:      pr.gstTaxCode,
      sgstCode:      pr.gstTaxCode,
      igstCode:      pr.gstTaxCode,
      // Commercial charges + additional tax — seeded from the header (§3/§7).
      discPer:       gstHeaderDefaults.discPer,
      packingPer:    gstHeaderDefaults.packingPer,
      freightPer:    gstHeaderDefaults.freightPer,
      insurancePer:  gstHeaderDefaults.insurancePer,
      cessPer:       gstHeaderDefaults.cessPer,
      fcaFob:        gstHeaderDefaults.fcaFob,
      addTaxCode:    '',
      addTaxPer:     gstHeaderDefaults.addTaxPer,
      addTaxAmt:     0,
      // Applicability flags — seeded from header, editable per-line in GST modal.
      freightPos:       gstHeaderDefaults.freightPos,
      insuranceDuty:    gstHeaderDefaults.insuranceDuty,
      cessTaxPos:       gstHeaderDefaults.cessTaxPos,
      exciseIncPacking: gstHeaderDefaults.exciseIncPacking,
      freightType:      gstHeaderDefaults.freightType,
      discApp:          gstHeaderDefaults.discApp,
      packApp:          gstHeaderDefaults.packApp,
      taxableValue:  0,
      netAmount:     0,
      taxSaved:      false,
      requesterId:   pr.requesterId,
      requesterName: pr.requesterName,
      route:         gstRoute,
      deleteReason:  '',
    }, headerForm.getFieldValue('gstState') ?? '')

  const toDeliveryLine = (line: PoLine): DeliveryScheduleLine => ({
    lineNo:   line.lineNo,
    itemCode: line.itemCode,
    itemName: line.itemName,
    uom:      line.uom,
    prNo:     line.prNo,
    poQty:    line.qty,
    slots:    [{ slotNo: 1, shDate: getCurrentSystemDateIso(), qty: line.qty, remarks: '' }],
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
  // Qty is clamped to balanceQty immediately with a warning (BR-05 UX).
  const updateLineRateQty = (lineNo: number, patch: { rate?: number; qty?: number }) => {
    const target = draftLines.find((l) => l.lineNo === lineNo)
    if (!target) return
    if (patch.rate !== undefined && patch.rate < 0) {
      notificationService.warning('Invalid Value', 'Rate cannot be negative.')
      patch = { ...patch, rate: 0 }
    }
    if (patch.qty !== undefined && patch.qty < 0) {
      notificationService.warning('Invalid Value', 'Quantity cannot be negative.')
      patch = { ...patch, qty: 0 }
    }
    if (patch.qty !== undefined && patch.qty > target.balanceQty) {
      notificationService.warning(
        'Quantity Exceeded',
        'Quantity cannot exceed available balance quantity.',
      )
      patch = { ...patch, qty: target.balanceQty }
    }
    const merged = recalcLine({ ...target, ...patch })
    updateDraftLine(lineNo, merged)
    if (patch.qty !== undefined) {
      // CR-035: sync delivery poQty AND clamp each slot's qty to the new PO Qty.
      // Prevents the Scheduled Qty from silently exceeding the PO Qty after an inline edit.
      const newPoQty = merged.qty
      let slotWasClamped = false
      setDeliveryLines(deliveryLines.map((d) => {
        if (d.lineNo !== lineNo) return d
        const slots = d.slots.map((s) => {
          const clamped = round3(Math.min(s.qty, newPoQty))
          if (clamped < s.qty) slotWasClamped = true
          return { ...s, qty: clamped }
        })
        return { ...d, poQty: newPoQty, slots }
      }))
      if (slotWasClamped)
        notificationService.warning('Delivery Schedule Adjusted', 'Scheduled Qty has been automatically reduced to match the updated PO Qty.')
    }
  }

  // GST modal apply → merge tax detail, recompute, refresh ONLY this row (§4).
  // taxSaved flips true so later opens load the saved row, not header defaults (§7).
  // CR-013: optional rate/qty in detail overrides line rate/qty and syncs delivery.
  const applyGstDetail = (lineNo: number, detail: LineTaxDetail) => {
    const target = draftLines.find((l) => l.lineNo === lineNo)
    if (!target) return
    const safeDetail = applyGstRouteToDetail({
      ...detail,
      rate: detail.rate !== undefined ? clampNonNegativeNumber(detail.rate) : undefined,
      qty:  detail.qty  !== undefined ? clampNonNegativeNumber(detail.qty)  : undefined,
      tcsPer:        clampNonNegativeNumber(detail.tcsPer),
      discPer:       clampNonNegativeNumber(detail.discPer),
      packingPer:    clampNonNegativeNumber(detail.packingPer),
      freightPer:    clampNonNegativeNumber(detail.freightPer),
      insurancePer:  clampNonNegativeNumber(detail.insurancePer),
      cessPer:       clampNonNegativeNumber(detail.cessPer),
      fcaFob:        clampNonNegativeNumber(detail.fcaFob),
      addTaxPer:     clampNonNegativeNumber(detail.addTaxPer),
    }, target.route, gstTaxCodes)
    const merged = {
      ...target,
      ...safeDetail,
      rate: safeDetail.rate ?? target.rate,
      qty:  safeDetail.qty  ?? target.qty,
      taxSaved: true,
    }
    updateDraftLine(lineNo, recalcLine(applyGstRouteToLine(merged, target.route, gstTaxCodes)))
    if (safeDetail.qty !== undefined && safeDetail.qty !== target.qty) {
      // CR-035: clamp delivery slot quantities when GST modal changes the line qty.
      const newPoQty = safeDetail.qty!
      let slotWasClamped = false
      setDeliveryLines(deliveryLines.map((d) => {
        if (d.lineNo !== lineNo) return d
        const slots = d.slots.map((s) => {
          const clamped = round3(Math.min(s.qty, newPoQty))
          if (clamped < s.qty) slotWasClamped = true
          return { ...s, qty: clamped }
        })
        return { ...d, poQty: newPoQty, slots }
      }))
      if (slotWasClamped)
        notificationService.warning('Delivery Schedule Adjusted', 'Scheduled Qty has been automatically reduced to match the updated PO Qty.')
    }
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
    roundOff:    0,
    freightType: 'PAID',
    freightPos:  'BEFORE',
    discApp:     'BEFORE',
    packApp:     'BEFORE',
    insuranceDuty:    'BEFORE',
    cessTaxPos:       'BEFORE',
    exciseIncPacking: 'N',
    payMode:     'DIRECT',
    cancelled:   false,
    formType:    formTypes[0]?.formCode ?? '',   // auto-default first available form type
    carrier:     '',
    deliveryDate: getCurrentSystemDate(),
    // Numeric fields default to 0 so validateFields() never returns null.
    cgstPer: 0, sgstPer: 0, igstPer: 0, tcsPer: 0,
    discPer: 0, discAmt: 0,
    freightAmt: 0, freightPer: 0,
    packPer: 0, packAmt: 0,
    insurPer: 0, insurAmt: 0,
    addTaxPer: 0, addTaxAmtHdr: 0,
    cessPer: 0, cessAmt: 0,
    fcaFob: 0,
    creditDays: 0, advAmt: 0,
    otherLevies: '',
  })

  const enterAddMode = async (): Promise<boolean> => {
    const result = await runPreChecks()
    // BR-02 gate: no eligible PR lines ⇒ cannot start an Add.
    if (result && result.approvedPrLinesExist === false) {
      notificationService.warning('No Eligible PR Lines', 'There are no approved PR lines available to convert.')
      return false
    }
    headerForm.resetFields()
    headerForm.setFieldsValue(headerDefaults())
    setDraftLines([])
    setDeliveryLines([])
    setGstRoute(getGstRouteFromState(''))
    setMode('ADD')
    resetToHeaderTab()   // Add Mode opens the Header (Order Details) tab
    return true
  }

  // poOverride: when supplied (delete-find flow), skip the store lookup — avoids
  // the React closure staleness issue when called immediately after loadRecord.
  const enterDeleteMode = (poOverride?: PoHeader) => {
    const po = poOverride ?? currentPo
    if (!po) return
    // GRN guard (BR-03) is enforced server-side (HTTP 409); the confirm step
    // surfaces it. Seed draft lines so per-line delete reasons are editable.
    setDraftLines(po.lines.map((l) => ({
      ...l,
      discPer:          l.discPer          ?? 0,
      packingPer:       l.packingPer       ?? 0,
      freightPer:       l.freightPer       ?? 0,
      insurancePer:     l.insurancePer     ?? 0,
      cessPer:          l.cessPer          ?? 0,
      fcaFob:           l.fcaFob           ?? 0,
      addTaxCode:       l.addTaxCode       ?? '',
      addTaxPer:        l.addTaxPer        ?? 0,
      addTaxAmt:        l.addTaxAmt        ?? 0,
      freightPos:       l.freightPos       ?? 'BEFORE',
      insuranceDuty:    l.insuranceDuty    ?? 'BEFORE',
      cessTaxPos:       l.cessTaxPos       ?? 'BEFORE',
      exciseIncPacking: l.exciseIncPacking ?? 'N',
      freightType:      l.freightType      ?? 'PAID',
      discApp:          l.discApp          ?? 'BEFORE',
      packApp:          l.packApp          ?? 'BEFORE',
      taxableValue:     l.taxableValue     ?? (l.rate * l.qty),
      netAmount:        l.netAmount        ?? 0,
      taxSaved:         l.taxSaved         ?? true,
      deleteReason: '',
    })))
    setDeliveryLines(po.delivery ?? [])
    setMode('DELETE')
    resetToHeaderTab()
  }

  const cancelMode = () => {
    resetToView()   // resets deliveryLines → []
    resetToHeaderTab()
    if (currentPo) {
      fillHeaderFromPo(currentPo)
      setDeliveryLines(currentPo.delivery ?? [])  // restore delivery after reset
    } else {
      // No prior record — clear the form entirely so no ADD-mode values linger.
      headerForm.resetFields()
    }
    notificationService.info('Operation Cancelled', 'The current operation was cancelled.')
  }

  // ── Load existing PO (VIEW) ────────────────────────────────────────────────
  function fillHeaderFromPo(po: PoHeader) {
    setGstRoute(getGstRouteFromState(po.gstState))
    headerForm.setFieldsValue({
      poDate:        dayjs(po.poDate),
      orderType:     po.orderType,
      supplier:      po.supplier,
      gstin:         po.gstin,
      gstState:      resolveGstStateDisplay(po.gstState),
      inspect:       po.inspect,
      formType:      po.formType,
      refNo:         po.refNo,
      refDate:       po.refDate ? dayjs(po.refDate) : null,
      currency:      po.currency,
      currRate:      po.currRate,
      remarks:       po.remarks,
      roundOff:      po.roundOff ?? 0,
      cgstPer:       po.cgstPer,
      sgstPer:       po.sgstPer,
      igstPer:       po.igstPer,
      tcsPer:        po.tcsPer,
      discPer:       po.discPer,
      discAmt:       po.discountAmt         ?? 0,
      freightAmt:    po.freightAmt,
      freightPer:    po.freightPer          ?? 0,
      packPer:       po.packPer,
      packAmt:       po.packingAmt          ?? 0,
      insurPer:      po.insurPer,
      insurAmt:      po.insuranceAmt        ?? 0,
      addTaxPer:     po.addTaxPer,
      addTaxAmtHdr:  po.addTaxAmt           ?? 0,
      cessPer:       po.cessPer             ?? 0,
      cessAmt:       po.cessAmt             ?? 0,
      fileNo:        po.fileNo,
      fcaFob:        po.fcaFob,
      freightType:   po.freightType,
      freightPos:    po.freightPosition     ?? 'BEFORE',
      discApp:       po.discApp,
      packApp:       po.packApp,
      insuranceDuty:    po.insurancePosition  ?? 'BEFORE',
      cessTaxPos:       po.cessPosition       ?? 'BEFORE',
      exciseIncPacking: po.exciseIncludePacking ?? 'N',
      payMode:       po.payMode,
      directInstr:   po.directInstr,
      bankCode:         po.bankCode,
      paymentTerms:     po.paymentTerms,
      paymentTermCode:  po.paymentTermCode ?? '',
      advAmt:        po.advAmt ?? 0,
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

  const loadRecord = async (poNo: number, poDate: string): Promise<PoHeader | null> => {
    if (!divCode) return null
    setNavLoading(true)
    try {
      const po = normalizePoForGstState(await poApi.getById(divCode, poNo, poDate))
      // Supplier list is lazy-loaded (on dropdown open) and may be empty in VIEW.
      // Inject a synthetic option so the Select resolves the label immediately.
      // React 18 batches this with fillHeaderFromPo — zero flash, single render.
      // The real entry replaces this when the full list loads on dropdown open.
      setSuppliers((prev) =>
        prev.some((s) => s.slCode === po.supplier) ? prev : [
          { slCode: po.supplier, slName: po.supplierName, gstinNo: po.gstin, gstStateCode: '', gstStateName: po.gstState, city: '' },
          ...prev,
        ],
      )
      setCurrentPo(po)
      fillHeaderFromPo(po)
      setDeliveryLines(po.delivery ?? [])
      setMode('VIEW')
      resetToHeaderTab()   // Find→Load / record navigation opens the Header tab
      return po
    } catch (err) {
      notificationService.error('Failed to Load Record', getErrorMessage(err))
      return null
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
      if (po) {
        const normalizedPo = normalizePoForGstState(po)
        setSuppliers((prev) =>
          prev.some((s) => s.slCode === normalizedPo.supplier) ? prev : [
            { slCode: normalizedPo.supplier, slName: normalizedPo.supplierName, gstinNo: normalizedPo.gstin, gstStateCode: '', gstStateName: normalizedPo.gstState, city: '' },
            ...prev,
          ],
        )
        setCurrentPo(normalizedPo)
        fillHeaderFromPo(normalizedPo)
        setDeliveryLines(normalizedPo.delivery ?? [])
        resetToHeaderTab()
      }
    } catch { /* empty list is fine */ }
    finally { setNavLoading(false) }
  }, [divCode, normalizePoForGstState, processingDate]) // eslint-disable-line react-hooks/exhaustive-deps

  // Build the navigation index (all PO numbers in the FY, ascending) for the
  // First / Prev / Next / Last toolbar buttons. Refreshed after Save/Delete.
  const loadNavList = useCallback(async () => {
    if (!divCode) return
    const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
    try {
      const list = await poApi.getList(divCode, yfDate, ylDate, { pageSize: 50 })
      setNavList(
        [...list].sort((a, b) => a.poNo - b.poNo).map((s) => ({ poNo: s.poNo, poDate: s.poDate })),
      )
    } catch { setNavList([]) }
  }, [divCode, processingDate])

  const headerNegativeFields: { key: keyof PoHeaderFormValues; label: string }[] = [
    { key: 'currRate', label: 'Currency Rate' },
    { key: 'roundOff', label: 'Round Off' },
    { key: 'tcsPer', label: 'TCS %' },
    { key: 'discPer', label: 'Discount %' },
    { key: 'discAmt', label: 'Discount Amount' },
    { key: 'freightPer', label: 'Freight %' },
    { key: 'freightAmt', label: 'Freight Amount' },
    { key: 'packPer', label: 'Packing %' },
    { key: 'packAmt', label: 'Packing Amount' },
    { key: 'insurPer', label: 'Insurance %' },
    { key: 'insurAmt', label: 'Insurance Amount' },
    { key: 'addTaxPer', label: 'GST %' },
    { key: 'addTaxAmtHdr', label: 'GST Amount' },
    { key: 'cessPer', label: 'Other %' },
    { key: 'cessAmt', label: 'Other Amount' },
    { key: 'fcaFob', label: 'FCA / FOB' },
    { key: 'creditDays', label: 'Credit Days' },
    { key: 'advAmt', label: 'Advance Amount' },
  ]

  const lineNegativeFields: { key: keyof PoLine; label: string }[] = [
    { key: 'qty', label: 'Quantity' },
    { key: 'rate', label: 'Rate' },
    { key: 'discPer', label: 'Discount %' },
    { key: 'packingPer', label: 'Packing %' },
    { key: 'freightPer', label: 'Freight %' },
    { key: 'insurancePer', label: 'Insurance %' },
    { key: 'cessPer', label: 'Other %' },
    { key: 'cgstPer', label: 'CGST %' },
    { key: 'cgstAmt', label: 'CGST Amount' },
    { key: 'sgstPer', label: 'SGST %' },
    { key: 'sgstAmt', label: 'SGST Amount' },
    { key: 'igstPer', label: 'IGST %' },
    { key: 'igstAmt', label: 'IGST Amount' },
    { key: 'tcsPer', label: 'TCS %' },
    { key: 'tcsAmt', label: 'TCS Amount' },
    { key: 'addTaxPer', label: 'GST %' },
    { key: 'addTaxAmt', label: 'GST Amount' },
    { key: 'fcaFob', label: 'FCA / FOB' },
    { key: 'value', label: 'Line Value' },
    { key: 'taxableValue', label: 'Taxable Value' },
    { key: 'taxAmt', label: 'GST Amount' },
    { key: 'netAmount', label: 'Landing Cost' },
  ]

  const findNegativeHeaderField = (values: PoHeaderFormValues) => {
    for (const field of headerNegativeFields) {
      if (isNegativeNumber(values[field.key])) return field
    }
    return null
  }

  const findNegativeLineIssue = (working: PoLine[]) => {
    for (const line of working) {
      for (const field of lineNegativeFields) {
        if (isNegativeNumber(line[field.key])) {
          return { itemCode: line.itemCode, label: field.label }
        }
      }
    }
    return null
  }

  const findNegativeDeliveryIssue = () => {
    for (const delivery of deliveryLines) {
      for (const slot of delivery.slots) {
        if (isNegativeNumber(slot.qty)) {
          return { itemCode: delivery.itemCode, label: 'Scheduled Qty' }
        }
      }
    }
    return null
  }

  // ── Client-side validation (mirrors BR register; server is authoritative) ──
  const validateLines = (onBodyTab?: (tab: 'lines' | 'delivery') => void): boolean => {
    const working = draftLines.filter((l) => l.itemCode.trim() !== '')
    if (working.length === 0) {
      notificationService.warning('No Line Items', 'Add at least one PR line before saving.')
      onBodyTab?.('lines')
      return false
    }
    const negativeLine = findNegativeLineIssue(working)
    if (negativeLine) {
      notificationService.warning('Invalid Value', `${negativeLine.label} cannot be negative for item ${negativeLine.itemCode}.`)
      onBodyTab?.('lines')
      return false
    }
    const negativeDelivery = findNegativeDeliveryIssue()
    if (negativeDelivery) {
      notificationService.warning('Invalid Value', `${negativeDelivery.label} cannot be negative for item ${negativeDelivery.itemCode}.`)
      onBodyTab?.('delivery')
      return false
    }
    // BR-07 Rate > 0
    const zeroRate = working.filter((l) => (l.rate ?? 0) <= 0)
    if (zeroRate.length) {
      notificationService.warning('Validation Failed', `Rate must be greater than 0 for: ${zeroRate.map((l) => l.itemCode).join(', ')}.`)
      onBodyTab?.('lines')
      return false
    }
    // BR-06 Qty > 0
    const zeroQty = working.filter((l) => (l.qty ?? 0) <= 0)
    if (zeroQty.length) {
      notificationService.warning('Validation Failed', `Quantity must be greater than 0 for: ${zeroQty.map((l) => l.itemCode).join(', ')}.`)
      onBodyTab?.('lines')
      return false
    }
    // BR-05 Qty ≤ PR balance
    const overBalance = working.filter((l) => (l.qty ?? 0) > (l.balanceQty ?? 0))
    if (overBalance.length) {
      notificationService.warning('Validation Failed', `Quantity exceeds PR balance for: ${overBalance.map((l) => l.itemCode).join(', ')}.`)
      onBodyTab?.('lines')
      return false
    }
    // BR-08 Tax Code mandatory
    const noTaxCode = working.filter((l) => !l.taxCode.trim())
    if (noTaxCode.length) {
      notificationService.warning('Mandatory Fields Missing', `Tax Code is required for: ${noTaxCode.map((l) => l.itemCode).join(', ')}.`)
      onBodyTab?.('lines')
      return false
    }
    // BR-10 HSN mandatory (SPINRISE enforces at save; server re-checks → 400)
    const noHsn = working.filter((l) => !l.hsnCode.trim())
    if (noHsn.length) {
      notificationService.warning('Mandatory Fields Missing', `HSN Code is required for: ${noHsn.map((l) => l.itemCode).join(', ')}. Configure it in Item Master.`)
      onBodyTab?.('lines')
      return false
    }
    // B1 PR Date mandatory — server validates PR balance against it; an empty or
    // unresolvable date would silently validate against the wrong PR records.
    const noPrDate = working.filter((l) => !toIsoDate(l.prDate))
    if (noPrDate.length) {
      notificationService.warning('PR Date Missing', `PR date could not be resolved for: ${noPrDate.map((l) => l.itemCode).join(', ')}. Remove and re-select the line from the PR Picker.`)
      onBodyTab?.('lines')
      return false
    }
    // CR-027: Delivery slot dates must not be in the past
    const today = dayjs().startOf('day')
    const pastSlots = deliveryLines.filter((d) =>
      d.slots.some((s) => s.shDate && dayjs(s.shDate).isBefore(today, 'day')),
    )
    if (pastSlots.length) {
      notificationService.warning('Invalid Delivery Date', `Delivery Date cannot be in the past for: ${pastSlots.map((d) => d.itemCode).join(', ')}. Delivery dates must be today or a future date.`)
      onBodyTab?.('delivery')
      return false
    }
    // UX-01 delivery reconciliation — block over-allocation; under is allowed.
    const overSched = deliveryLines.filter((d) =>
      round3(d.slots.reduce((s, x) => s + (Number(x.qty) || 0), 0)) > round3(d.poQty),
    )
    if (overSched.length) {
      // CR-014: updated message format
      notificationService.warning('Delivery Schedule Mismatch', `Scheduled quantity exceeds PO quantity for item: ${overSched.map((d) => d.itemCode).join(', ')}.`)
      onBodyTab?.('delivery')
      return false
    }
    // CR-016: duplicate delivery dates per item are not allowed
    for (const d of deliveryLines) {
      const filledDates = d.slots.map((s) => s.shDate).filter(Boolean) as string[]
      if (filledDates.length !== new Set(filledDates).size) {
        notificationService.warning(
          'Duplicate Delivery Date',
          `Duplicate delivery date found for item ${d.itemCode}. Each delivery slot must have a unique date.`,
        )
        onBodyTab?.('delivery')
        return false
      }
    }
    return true
  }

  // Cross-field header rules not expressible as single-field AntD `required`.
  // Returns true on success, or the offending field name (string) on failure so
  // the caller can navigate to the correct tab and focus the invalid field.
  const validateHeaderConditionals = (v: PoHeaderFormValues): true | string => {
    const negativeHeader = findNegativeHeaderField(v)
    if (negativeHeader) {
      notificationService.warning('Invalid Value', `${negativeHeader.label} cannot be negative.`)
      return negativeHeader.key
    }
    // GST State Code guard: a selected supplier that has no gstStateCode cannot
    // route GST correctly. Block save so the SP never receives an empty state.
    if (v.supplier?.trim() && !v.gstState?.trim()) {
      notificationService.error('GST State Missing', 'The selected supplier does not have a GST State Code. Select a valid supplier before saving.')
      return 'supplier'
    }
    // BR-14 Carrier mandatory (CR-020: inline rule removed from form; validated here at save)
    if (!v.carrier?.trim()) {
      notificationService.warning('Mandatory Fields Missing', 'Carrier is required.')
      return 'carrier'
    }
    // BR-15 Bank → Bank Code + Cheque No.
    if (v.payMode === 'BANK') {
      if (!v.bankCode?.trim()) { notificationService.warning('Mandatory Fields Missing', 'Bank is required for bank payment.'); return 'bankCode' }
      if (!v.chequeNo?.trim()) { notificationService.warning('Mandatory Fields Missing', 'Cheque No. is required for bank payment.'); return 'chequeNo' }
    }
    // BR-15 HO order type → Pricing Terms
    if (v.orderType === HO_TYPE && !v.pricingTerms?.trim()) {
      notificationService.warning('Mandatory Fields Missing', 'Pricing Terms is required for HO purchase type.')
      return 'pricingTerms'
    }
    // BR-01 backdate guard: PO date must equal processing date when BACKDATE='N'
    if (preChecks?.backDateFlag === 'N' && v.poDate && processingDate) {
      const today = dayjs(processingDate)
      if (!v.poDate.isSame(today, 'day')) {
        notificationService.warning('Invalid PO Date', `PO date must equal today's processing date (${today.format('DD-MMM-YYYY')}).`)
        return 'poDate'
      }
    }
    // CR-017: PO Date cannot be a future date
    if (v.poDate && v.poDate.isAfter(dayjs(), 'day')) {
      notificationService.warning('Invalid PO Date', 'PO Date cannot be a future date.')
      return 'poDate'
    }
    // CR-024: PO Date must be >= last PO Date
    if (preChecks?.lastPoDate && v.poDate && v.poDate.isBefore(dayjs(preChecks.lastPoDate), 'day')) {
      notificationService.warning('Invalid PO Date', `PO Date cannot be earlier than the last PO date (${dayjs(preChecks.lastPoDate).format('DD-MMM-YYYY')}). Allowed range: ${dayjs(preChecks.lastPoDate).format('DD-MMM-YYYY')} – ${dayjs(processingDate ?? undefined).format('DD-MMM-YYYY')}.`)
      return 'poDate'
    }
    // CR-018: Reference Date cannot be later than PO Date
    if (v.refDate && v.poDate && v.refDate.isAfter(v.poDate, 'day')) {
      notificationService.warning('Invalid Reference Date', 'Reference Date cannot be later than PO Date.')
      return 'refDate'
    }
    // CR-025: Reference Date cannot be a future date
    if (v.refDate && v.refDate.isAfter(dayjs(), 'day')) {
      notificationService.warning('Invalid Reference Date', 'Reference Date cannot be a future date.')
      return 'refDate'
    }
    // CR-027 / CR-028: Delivery Date must be today or future and within FY
    if (v.deliveryDate) {
      const { yfDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
      const fyEndFull  = dayjs(getFYEndDate(processingDate))
      if (v.deliveryDate.isBefore(dayjs(), 'day')) {
        notificationService.warning('Invalid Delivery Date', 'Delivery Date must be greater than or equal to today\'s date.')
        return 'deliveryDate'
      }
      if (v.deliveryDate.isBefore(dayjs(yfDate), 'day') || v.deliveryDate.isAfter(fyEndFull, 'day')) {
        notificationService.warning('Invalid Delivery Date', 'Selected date must be within the active financial year.')
        return 'deliveryDate'
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
      prNo:     l.prNo,
      prSno:    l.prSno,
      prDate:   toIsoDate(l.prDate),   // ISO 'YYYY-MM-DD' (B1)
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
      route:            l.route,
      requesterId:      l.requesterId,
      requesterName:    l.requesterName,
      discPer:          l.discPer,
      packingPer:       l.packingPer,
      freightPer:       l.freightPer,
      insurancePer:     l.insurancePer,
      cessPer:          l.cessPer,
      fcaFob:           l.fcaFob,
      addTaxCode:       l.addTaxCode,
      addTaxPer:        l.addTaxPer,
      freightPos:       l.freightPos,
      insuranceDuty:    l.insuranceDuty,
      cessTaxPos:       l.cessTaxPos,
      exciseIncPacking: l.exciseIncPacking,
      freightType:      l.freightType,
      discApp:          l.discApp,
      packApp:          l.packApp,
      slots:            slotsFor(l.lineNo),
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
        roundOff:      v.roundOff ?? 0,
        orderValue:    totals.totalOrderValue,
        formType:      v.formType,
        refNo:         v.refNo,
        refDate:       fmtDate(v.refDate),
        currency:      v.currency,
        currRate:      v.currRate,
        remarks:       v.remarks,
        cgstPer:       v.cgstPer ?? 0, sgstPer: v.sgstPer ?? 0, igstPer: v.igstPer ?? 0, tcsPer: v.tcsPer ?? 0,
        discPer:       v.discPer,
        freightAmt:    v.freightAmt, packPer: v.packPer, insurPer: v.insurPer,
        addTaxPer:     v.addTaxPer ?? 0, fileNo: v.fileNo, fcaFob: v.fcaFob,
        freightType:   v.freightType, discApp: v.discApp, packApp: v.packApp,
        discountAmt:          v.discAmt         ?? 0,
        freightPer:           v.freightPer      ?? 0,
        packingAmt:           v.packAmt         ?? 0,
        insuranceAmt:         v.insurAmt        ?? 0,
        addTaxAmt:            0,
        cessPer:              v.cessPer         ?? 0,
        cessAmt:              v.cessAmt         ?? 0,
        freightPosition:      v.freightPos,
        insurancePosition:    v.insuranceDuty,
        cessPosition:         v.cessTaxPos,
        exciseIncludePacking: v.exciseIncPacking,
        payMode: v.payMode, directInstr: v.directInstr, bankCode: v.bankCode,
        paymentTerms: v.paymentTerms, paymentTermCode: v.paymentTermCode ?? '',
        advPer: 0, advAmt: v.advAmt ?? 0,
        modeOfPayment: v.modeOfPayment, payRef: v.payRef, payRefDate: fmtDate(v.payRefDate),
        chequeNo:      v.chequeNo, chequeDate: fmtDate(v.chequeDate),
        carrier:       v.carrier, creditDays: v.creditDays, deliveryDate: fmtDate(v.deliveryDate),
        deliveryLocation: v.deliveryLocation, billingAddress: v.billingAddress,
        specialInstr:  v.specialInstr, despatch: v.despatch, purpose: v.purpose,
        otherLevies:   v.otherLevies ?? '', pricingTerms: v.pricingTerms,
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
  const doSave = async (
    onValidationFailed?: (tab: HeaderTabKey, fieldName: string) => void,
    onBodyTabFailed?: (tab: 'lines' | 'delivery') => void,
  ) => {
    let values: PoHeaderFormValues
    try { values = await headerForm.validateFields() }   // BR-11..14 via field rules (HF-19a)
    catch (err) {
      notificationService.warning('Mandatory Fields Missing', 'Please fill in all required fields.')
      if (onValidationFailed && err && typeof err === 'object' && 'errorFields' in err) {
        const errorFields = (err as { errorFields: { name: (string | number)[] }[] }).errorFields
        const firstField  = errorFields[0]?.name?.[0]
        if (typeof firstField === 'string') {
          onValidationFailed(FIELD_TAB_MAP[firstField] ?? 'order', firstField)
        }
      }
      return
    }

    const condResult = validateHeaderConditionals(values)
    if (condResult !== true) {
      onValidationFailed?.(FIELD_TAB_MAP[condResult] ?? 'order', condResult)
      return
    }                                                      // BR-15, BR-01
    if (!validateLines(onBodyTabFailed)) return           // BR-05/06/07/08/10, UX-01

    setSaving(true)
    try {
      const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
      const request = buildAddRequest(values)
      // Server allocates the PO number atomically after validation (CD-03 / UX-04).
      const result = await poApi.addPo(divCode, yfDate, ylDate, request)
      const saved = normalizePoForGstState(await poApi.getById(divCode, result.poNo, result.poDate))
      setCurrentPo(saved)
      fillHeaderFromPo(saved)
      resetToView()
      // Must come AFTER resetToView — resetToView sets deliveryLines:[] in the store.
      setDeliveryLines(saved.delivery ?? [])
      resetToHeaderTab()
      void loadNavList()   // new PO joins the navigation index
      notificationService.success('Purchase Order Saved Successfully', `Purchase Order ${formatPoNo(result.poNo)} was created.`)
      resetBodyTab()   // navigate page body back to Item Details tab (Task 1)
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
    let orderValue = 0, totalGst = 0, totalTcs = 0, totalAddTax = 0, totalNet = 0
    const qtyByUom: Record<string, number> = {}
    for (const l of lines) {
      // Taxable (Order Value, "Before GST", UI-03) = Rate × Qty.
      const taxable = mode === 'VIEW'
        ? (l.value || calcLineValue(l.rate, l.qty))
        : calcLineValue(l.rate, l.qty)
      const gst    = (l.cgstAmt || 0) + (l.sgstAmt || 0) + (l.igstAmt || 0)
      const tcs    = l.tcsAmt || 0
      const addTax = l.addTaxAmt || 0
      // Net includes commercial charges; fall back for legacy/VIEW lines w/o netAmount.
      const net    = (l.netAmount && l.netAmount > 0) ? l.netAmount : round2(taxable + gst + tcs + addTax)
      orderValue  += taxable
      totalGst    += gst
      totalTcs    += tcs
      totalAddTax += addTax
      totalNet    += net
      if (l.uom) qtyByUom[l.uom] = (qtyByUom[l.uom] || 0) + (l.qty || 0)
    }
    orderValue  = round2(orderValue)
    totalGst    = round2(totalGst)
    totalTcs    = round2(totalTcs)
    totalAddTax = round2(totalAddTax)
    totalNet    = round2(totalNet)
    // Round-off: editable in ADD (watched from form); server-authoritative in VIEW.
    const roundOff = mode === 'ADD' ? (hRoundOff ?? 0) : (currentPo?.roundOff ?? 0)
    return {
      totalLines: lines.length,
      orderValue,
      totalGst,
      totalTcs,
      totalAddTax,
      roundOff,
      // Grand total = Σ per-line Net (charges + all taxes) + round-off.
      totalOrderValue: round2(totalNet + roundOff),
      qtyByUom,
    }
  }, [lines, mode, currentPo, hRoundOff])

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
    currentPo, lines, draftLines, deliveryLines, gstRoute, headerTabResetKey, bodyTabResetKey,
    // lookups
    parameters, preChecks,
    orderTypes, carriers, formTypes, suppliers, banks, gstTaxCodes,
    currencies, deliveryLocations, billingAddresses, pricingTermsOpts, payTerms,
    gstHeaderDefaults,
    lookupsLoaded, lookupsLoading, lookupsError,
    loadLookups, loadSuppliers, runPreChecks,
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
