// ── usePoAmendment — orchestration hook for PO Amendment ─────────────────────
//
// Source authority: FN-PO-Amendment v1.2 (QA-locked 8-Jul, CEO-accepted 9-Jul).
// VB6 form: amdmnt.frm.
//
// REUSE, NOT REBUILD. This hook deliberately reuses the PR-to-PO Transfer stack:
//   • recalcLine / hydrateLineFromDb  ← usePoTransferForm (the ONE calc engine)
//   • resolveCharge, GST route helpers ← poTransferRules
//   • PoHeader / PoLine / DeliveryScheduleLine shapes ← poTransferTypes
//   • PoHeaderTabs / PoLineGrid / DeliveryScheduleGrid / GstTaxDetailsModal
// A forked second calc engine is the exact divergence class that produced the PO
// List report defects — so the amendment screen maps the server's amendment DTOs
// into the Transfer shapes and drives the same engine.
//
// What is genuinely amendment-specific and lives here:
//   1. Load an EXISTING PO (getPOForAmend) rather than building from PR lines.
//   2. Identity fields are locked (PO No/Date, Supplier, PO Group) — FN §1.
//   3. CHANGED-LINE DETECTION → Amendment Reason mandatory on any changed line
//      (FN §3.6, CEO-confirmed: "any changed line", not landed-cost-only).
//   4. Zero-change save is blocked (FN §3.1 — VB6 allowed it).
//   5. Save → ksp_PO_AmendOrder (snapshot + update live + delta backflush).
//
// NOT done client-side (server's job per FN §4.B — "do not trust client-sent
// amounts"): budget check (§3.9), GST tax-code activity (§3.5), and the
// amended-qty >= RCVDQTY + CANQTY floor (§3.4 dynamic half). The UI shows the
// received/cancelled quantities but never enforces the floor itself.

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Form } from 'antd'
import dayjs from 'dayjs'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { notificationService } from '@/shared/lib/notification'
import { usePoAmendmentStore } from '../store/usePoAmendmentStore'
import { recalcLine, hydrateLineFromDb } from './usePoTransferForm'
import type { GstHeaderDefaults } from './usePoTransferForm'
import {
  applyGstRouteToLine,
  getGstRouteFromState,
  clampNonNegativeNumber,
  round2,
} from '../utils/poTransferRules'
import * as amendApi from '../api/poAmendmentApi'
import * as poApi from '../api/poTransferApi'
import { resolveGstStateDisplay } from '../types'
import type {
  AmendablePoSummary,
  AmendmentSummary,
  PoAmendmentHeaderDto,
  PoAmendmentLineDto,
  AmendmentSaveRequest,
  AmendmentLineSaveRequest,
  PoHeader,
  PoLine,
  DeliveryScheduleLine,
  LineTaxDetail,
  GstTaxCodeOption,
  SupplierOption,
  OrderTypeOption,
  CarrierOption,
  BankOption,
  FormTypeOption,
  AddressOption,
  CurrencyOption,
  PayTermOption,
} from '../types'

// ── Changed-line detection (FN §3.6) ─────────────────────────────────────────
// "any open line where quantity, rate, discount/packing/charge values, tax codes,
//  delivery schedule or any other stored line value differs from the current live
//  PO line."
//
// Only fields the user can actually author are compared. Derived money (value,
// netAmount, cgstAmt…) is deliberately EXCLUDED: it is recomputed by recalcLine on
// every keystroke and again server-side, so diffing it would flag lines as changed
// purely from rounding — and the server recomputes it anyway (§4.B).
const AUTHORED_LINE_FIELDS = [
  'rate', 'qty',
  'discPer', 'discAmt', 'packingPer', 'packingAmt',
  'freightPer', 'freightAmt', 'insurancePer', 'insuranceAmt',
  'otherCharges',
  'discApp', 'packApp', 'freightPos', 'insuranceDuty',
  'taxCode', 'hsnCode', 'cgstCode', 'sgstCode', 'igstCode',
  'tcsPer', 'addTaxCode', 'addTaxPer',
] as const satisfies readonly (keyof PoLine)[]

// Must sit BELOW the finest stored precision, not at it. Rate is 4dp, so the
// smallest real edit a user can make is 0.0001 — an epsilon of 0.0005 would have
// swallowed it and let a genuine rate change through with no Amendment Reason
// (caught by usePoAmendment.test.ts). 1e-6 is under 4dp but still well above
// IEEE-754 representation noise.
const NUM_EPSILON = 1e-6

const fieldDiffers = (a: unknown, b: unknown): boolean => {
  if (typeof a === 'number' || typeof b === 'number') {
    return Math.abs((Number(a) || 0) - (Number(b) || 0)) > NUM_EPSILON
  }
  return (a ?? '') !== (b ?? '')
}

/** True when any authored value on `line` differs from its pristine `original`. */
export const isLineChanged = (line: PoLine, original: PoLine | undefined): boolean => {
  if (!original) return true            // a line with no pristine twin is new ⇒ changed
  return AUTHORED_LINE_FIELDS.some((f) => fieldDiffers(line[f], original[f]))
}

// ── Server DTO → Transfer shapes ─────────────────────────────────────────────
// Maps the amendment load DTO into the PoHeader/PoLine the reused components take.

const toPoLine = (d: PoAmendmentLineDto, gstState: string): PoLine => {
  const route = getGstRouteFromState(gstState)
  const line: PoLine = {
    lineNo:        d.sNo,               // PORDSNO is the stable line key on an existing PO
    prSno:         d.prSno,
    itemCode:      d.itemCode,
    itemName:      d.itemName,
    uom:           d.uom,
    prNo:          d.prNo,
    prDate:        d.prDate,
    rate:          d.rate,
    qty:           d.qty,
    // Gap #5 (VB6 parity): the amend ceiling. Max new qty = current qty + the PR's
    // remaining unordered balance (qtyreqd - qtyord, returned as prBalance). A
    // non-PR line comes back with a large sentinel, so it is effectively uncapped.
    balanceQty:    d.qty + d.prBalance,
    value:         d.value,
    taxCode:       d.taxCode,
    taxPer:        d.taxPer,
    taxAmt:        d.taxAmt,
    hsnCode:       d.hsnCode,
    cgstPer:       d.cgstPer,
    cgstAmt:       d.cgstAmt,
    sgstPer:       d.sgstPer,
    sgstAmt:       d.sgstAmt,
    igstPer:       d.igstPer,
    igstAmt:       d.igstAmt,
    tcsPer:        d.tcsPer,
    tcsAmt:        d.tcsAmt,
    cgstCode:      d.cgstCode,
    sgstCode:      d.sgstCode,
    igstCode:      d.igstCode,
    discPer:       d.discPer,
    discAmt:       d.discAmt,
    packingPer:    d.packingPer,
    packingAmt:    d.packingAmt,
    freightPer:    d.freightPer,
    freightAmt:    d.freightAmt,
    insurancePer:  d.insurancePer,
    insuranceAmt:  d.insuranceAmt,
    otherCharges:  d.otherCharges,
    fcaFob:        d.fcaFob,
    addTaxCode:    d.addTaxCode,
    addTaxPer:     d.addTaxPer,
    addTaxAmt:     d.addTaxAmt,
    freightPos:    d.freightPos,
    insuranceDuty: d.insuranceDuty,
    discApp:       d.discApp,
    packApp:       d.packApp,
    taxableValue:  d.value,
    netAmount:     d.landingCost,
    taxSaved:      true,
    requesterId:   d.requesterId,
    requesterName: d.requesterName,
    route,
    deleteReason:  '',
    subCostCode:   0,
    depCode:       d.depCode,
    // Amendment-only (optional on PoLine ⇒ Transfer unaffected)
    amendReason:   d.amendReason ?? '',
    amendChanged:  false,
    receivedQty:   d.receivedQty,
    cancelledQty:  d.cancelQty,
  }
  return hydrateLineFromDb(line, {} as PoHeader)
}

// Every date field the header form binds to a DatePicker. AntD expects Dayjs
// objects; the server sends 'YYYY-MM-DD' strings. Anything not coerced here
// throws "getUDayjs(...).isValid is not a function" inside rc-field-form the
// moment the form renders — so this list must stay in step with the DatePicker
// fields on the reused header tabs (OrderDetails / Payment / Instructions /
// Cancel-Status).
const toFormDates = (po: PoHeader) => ({
  poDate:       po.poDate       ? dayjs(po.poDate)       : null,
  refDate:      po.refDate      ? dayjs(po.refDate)      : null,
  payRefDate:   po.payRefDate   ? dayjs(po.payRefDate)   : null,
  chequeDate:   po.chequeDate   ? dayjs(po.chequeDate)   : null,
  deliveryDate: po.deliveryDate ? dayjs(po.deliveryDate) : null,
  cancelDate:   po.cancelDate   ? dayjs(po.cancelDate)   : null,
})

// The Tax/Discount tab's AntD form field NAMES don't all match the PoHeader
// property they come from (packAmt/insurAmt vs packingAmt/insuranceAmt,
// freightPos/insuranceDuty vs freightPosition/insurancePosition), and the T-0081
// charge-mode fields (discMode/packMode/insurMode/freightMode) have no PoHeader
// property at all — they're inferred, same as usePoTransferForm.fillHeaderFromPo
// does for the Transfer screen. A raw `{ ...header }` spread misses all of these,
// leaving Packing/Insurance Amount and Freight/Insurance Position blank on load.
const toFormFieldAliases = (po: PoHeader) => ({
  discAmt:       po.discountAmt        ?? 0,
  packAmt:       po.packingAmt         ?? 0,
  insurAmt:      po.insuranceAmt       ?? 0,
  freightPos:    po.freightPosition    ?? 'BEFORE',
  insuranceDuty: po.insurancePosition  ?? 'BEFORE',
  discMode:      (po.discPer    ?? 0) > 0 ? 'PCT' : 'AMT',
  packMode:      (po.packPer    ?? 0) > 0 ? 'PCT' : 'AMT',
  insurMode:     (po.insurPer   ?? 0) > 0 ? 'PCT' : 'AMT',
  freightMode:   (po.freightAmt ?? 0) > 0 ? 'AMT' : 'PCT',
})

const toPoHeader = (d: PoAmendmentHeaderDto, lines: PoLine[], delivery: DeliveryScheduleLine[]): PoHeader => ({
  divCode:      d.divCode,
  poNo:         d.poNo,
  poDate:       d.poDate,
  orderType:    d.orderType,
  orderTypeDesc:d.orderTypeDesc,
  supplier:     d.supplier,
  supplierName: d.supplierName,
  gstin:        d.gstin,
  gstState:     resolveGstStateDisplay(d.gstState),
  inspect:      d.inspect,
  roundOff:     d.roundOff,
  orderValue:   d.orderValue,
  formType:     d.formType,
  refNo:        d.refNo,
  refDate:      d.refDate,
  currency:     d.currency,
  currRate:     d.currRate,
  remarks:      d.remarks,
  cgstPer:      d.cgstPer,
  sgstPer:      d.sgstPer,
  igstPer:      d.igstPer,
  tcsPer:       d.tcsPer,
  discPer:      d.discPer,
  freightAmt:   d.freightAmt,
  packPer:      d.packPer,
  insurPer:     d.insurPer,
  addTaxPer:    d.addTaxPer,
  fileNo:       d.fileNo,
  // discountAmt / addTaxAmt: derived amounts recomputed client-side once loaded,
  // not selected by ksp_PO_GetPOForAmend by design — left at 0 intentionally.
  fcaFob:       d.fcaFob,
  freightType:  d.freightType,
  discApp:      d.discApp,
  packApp:      d.packApp,
  discountAmt:  0,
  freightPer:   d.freightPer,
  packingAmt:   d.packingAmt,
  insuranceAmt: d.insuranceAmt,
  addTaxAmt:    0,
  freightPosition:   d.freightPosition,
  insurancePosition: d.insurancePosition,
  payMode:      d.payMode,
  directInstr:  d.directInstr,
  bankCode:     d.bankCode,
  paymentTerms: d.paymentTerms,
  paymentTermCode: d.paymentTermCode,
  advPer:       d.advPer,
  advAmt:       d.advAmt,
  modeOfPayment:d.modeOfPayment,
  payRef:       d.payRef,
  payRefDate:   d.payRefDate,
  chequeNo:     d.chequeNo,
  chequeDate:   d.chequeDate,
  carrier:      d.carrier,
  creditDays:   d.creditDays,
  deliveryDate: d.dueDate,
  deliveryLocation: d.deliveryLocation,
  billingAddress:   d.billingAddress,
  specialInstr: d.specialInstr,
  despatch:     d.despatch,
  purpose:      d.purpose,
  otherLevies:  d.otherLevies,
  pricingTerms: d.pricingTerms,
  packForwarding: d.packForwarding,
  insurance:    d.insurance,
  freight:      d.freight,
  reminder:     d.reminder,
  status:       '',
  cancelled:    (d.cancelFlag ?? '').trim().toUpperCase() === 'Y',
  cancelDate:   d.cancelDate,
  cancelReason: '',
  approved:     d.approved,
  approvedBy:   d.approvedBy,
  amdOrderNo:   d.amdOrderNo,
  amdDate:      d.amdDate,
  amdRefNo:     d.refOrderNo != null ? String(d.refOrderNo) : null,
  amdRefDate:   d.refOrderDate,
  approvalStatus: '',
  printStatus:  '',
  firstLevelApp:'',
  conflg:       d.conflg,
  createdBy:    d.createdBy,
  createdDt:    d.createdDt,
  userId:       '',
  lines,
  delivery,
})

// ─────────────────────────────────────────────────────────────────────────────

export function usePoAmendment() {
  const [headerForm] = Form.useForm()

  const user           = useAuthStore((s) => s.user)
  const processingDate = useAuthStore((s) => s.processingDate)
  const divCode        = user?.divCode ?? ''

  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)

  const s = usePoAmendmentStore()

  // ── Lookups (reused from the Transfer API — same masters) ──────────────────
  const [suppliers,        setSuppliers]        = useState<SupplierOption[]>([])
  const [orderTypes,       setOrderTypes]       = useState<OrderTypeOption[]>([])
  const [carriers,         setCarriers]         = useState<CarrierOption[]>([])
  const [banks,            setBanks]            = useState<BankOption[]>([])
  const [formTypes,        setFormTypes]        = useState<FormTypeOption[]>([])
  const [currencies,       setCurrencies]       = useState<CurrencyOption[]>([])
  const [payTerms,         setPayTerms]         = useState<PayTermOption[]>([])
  const [gstTaxCodes,      setGstTaxCodes]      = useState<GstTaxCodeOption[]>([])
  const [deliveryLocations,setDeliveryLocations]= useState<AddressOption[]>([])
  const [billingAddresses, setBillingAddresses] = useState<AddressOption[]>([])
  const [pricingTermsOpts, setPricingTermsOpts] = useState<AddressOption[]>([])
  const [lookupsLoading,   setLookupsLoading]   = useState(true)
  const [lookupsError,     setLookupsError]     = useState<string | null>(null)

  const loadLookups = useCallback(async () => {
    if (!divCode) return
    setLookupsLoading(true)
    setLookupsError(null)
    try {
      const [sup, ot, car, bk, ft, cur, pt, gst, dl, ba, ptm] = await Promise.all([
        poApi.getSuppliers(divCode),
        poApi.getOrderTypes(),
        poApi.getCarriers(),
        poApi.getBanks(divCode),
        poApi.getFormTypes(),
        poApi.getCurrencies(),
        poApi.getPayTerms(),
        poApi.getGstTaxCodes(),
        poApi.getDeliveryLocations(divCode),
        poApi.getBillingAddresses(divCode),
        poApi.getPricingTerms(),
      ])
      setSuppliers(sup); setOrderTypes(ot); setCarriers(car); setBanks(bk)
      setFormTypes(ft);  setCurrencies(cur); setPayTerms(pt);  setGstTaxCodes(gst)
      setDeliveryLocations(dl); setBillingAddresses(ba); setPricingTermsOpts(ptm)
    } catch (err) {
      setLookupsError(getErrorMessage(err))
    } finally {
      setLookupsLoading(false)
    }
  }, [divCode])

  // Mount-time master-data fetch. `react-hooks/set-state-in-effect` fires because
  // loadLookups sets state, but this is the rule's intended exception: an effect
  // synchronising React with an external system (the API). loadLookups is a
  // useCallback keyed on divCode, so this runs once per division, not per render.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void loadLookups() }, [loadLookups])

  // ── Picker: amendable POs (FN §1) ─────────────────────────────────────────
  const [pickerOpen,  setPickerOpen]  = useState(false)
  const [amendablePos, setAmendablePos] = useState<AmendablePoSummary[]>([])
  const [pickerLoading, setPickerLoading] = useState(false)

  const openPicker = useCallback(async () => {
    setPickerOpen(true)
    setPickerLoading(true)
    try {
      setAmendablePos(await amendApi.getAmendablePOList(yfDate, ylDate))
    } catch (err) {
      notificationService.error('Failed to Load Purchase Orders', getErrorMessage(err))
      setAmendablePos([])
    } finally {
      setPickerLoading(false)
    }
  }, [yfDate, ylDate])

  const closePicker = useCallback(() => setPickerOpen(false), [])

  // ── Load one PO — shared by selectPo (→ AMEND) and viewAmendment (→ read-only
  // VIEW) ─────────────────────────────────────────────────────────────────────
  // getPOForAmend always returns the PO's CURRENT live state (PO_ORDH/PO_ORDL) —
  // there is no backend endpoint for a specific past amendment's point-in-time
  // snapshot (ksp_PO_GetAmendmentList only returns summary rows; unlike the PR
  // module there is no ksp_PO_GetAmendmentById reading PO_AORDH/PO_AORDL). So
  // "view an amendment" reuses this exact same load path and just stops short of
  // entering AMEND — it does NOT reconstruct history that isn't queryable.
  const loadPoInto = useCallback(async (
    poNo: number, poDate: string, poGroup: string, targetMode: 'AMEND' | 'VIEW',
  ): Promise<boolean> => {
    s.setLoading(true)
    try {
      const dto = await amendApi.getPOForAmend(poNo, poDate, poGroup)

      const lines = dto.lines.map((l) => toPoLine(l, dto.gstState))

      // Delivery slots arrive flat (keyed by sNo+itemCode) → group per line.
      const delivery: DeliveryScheduleLine[] = lines.map((l) => ({
        lineNo:   l.lineNo,
        itemCode: l.itemCode,
        itemName: l.itemName,
        uom:      l.uom,
        prNo:     l.prNo,
        poQty:    l.qty,
        slots: dto.delivery
          .filter((d) => d.sNo === l.lineNo && d.itemCode === l.itemCode)
          .map((d, i) => ({ slotNo: i + 1, shDate: d.shDate || null, qty: d.qty })),
      }))

      const header = toPoHeader(dto, lines, delivery)
      s.loadPo(header, lines, delivery)
      s.setMode(targetMode)
      // AntD DatePicker binds Dayjs, NOT strings. The server returns dates as
      // 'YYYY-MM-DD' strings, so every date field must be coerced before it
      // reaches the form — passing the header in raw throws
      // "getUDayjs(...).isValid is not a function" deep inside rc-field-form.
      // (usePoTransferForm.fillHeaderFromPo does the same coercion; it is not
      // reused here because it also fires a setGstRoute side effect that the
      // amendment screen must not trigger — supplier is locked. The field-name
      // renames it also does are reused here directly, via toFormFieldAliases.)
      headerForm.setFieldsValue({ ...header, ...toFormDates(header), ...toFormFieldAliases(header) })
      return true
    } catch (err) {
      notificationService.error('Failed to Load Purchase Order', getErrorMessage(err))
      return false
    } finally {
      s.setLoading(false)
    }
  }, [s, headerForm])

  // ── Load one PO for amendment ─────────────────────────────────────────────
  const selectPo = useCallback(async (po: AmendablePoSummary) => {
    setPickerOpen(false)
    s.setSelectedPo(po)
    // Starting a fresh amendment on (possibly) a different PO — any
    // previously-viewed amendment reference no longer describes what's on
    // screen, so it must not linger as stale state.
    s.setSelectedAmendment(null)
    const ok = await loadPoInto(po.poNo, po.poDate, po.poGroup, 'AMEND')
    if (!ok) s.setSelectedPo(null)
  }, [loadPoInto, s])

  // ── Find Amendment (FN-PO-Amendment v1.2 §1 Find — view-only) ─────────────
  const [findAmendmentOpen,    setFindAmendmentOpen]    = useState(false)
  const [amendmentList,        setAmendmentList]        = useState<AmendmentSummary[]>([])
  const [amendmentListLoading, setAmendmentListLoading] = useState(false)

  const openFindAmendment = useCallback(async () => {
    setFindAmendmentOpen(true)
    setAmendmentListLoading(true)
    try {
      setAmendmentList(await amendApi.getAmendmentList(yfDate, ylDate))
    } catch (err) {
      notificationService.error('Failed to Load Amendments', getErrorMessage(err))
      setAmendmentList([])
    } finally {
      setAmendmentListLoading(false)
    }
  }, [yfDate, ylDate])

  const closeFindAmendment = useCallback(() => setFindAmendmentOpen(false), [])

  // Loads the amendment row's underlying PO read-only (see loadPoInto note above
  // re: no historical-snapshot endpoint). setSelectedPo mirrors selectPo so the
  // rest of the screen (save payload's poGroup fallback, etc.) sees a consistent
  // selection regardless of which picker was used. Closes the modal immediately
  // on selection (same order as selectPo/setPickerOpen(false)) so the page's own
  // "Loading Purchase Order…" indicator shows through instead of the modal
  // sitting on top of it; on failure the page just stays on its prior record.
  const viewAmendment = useCallback(async (row: AmendmentSummary) => {
    setFindAmendmentOpen(false)
    s.setSelectedPo({
      divCode: row.divCode, poNo: row.poNo, poDate: row.poDate, poGroup: row.poGroup,
      supplier: row.supplier, supplierName: row.supplierName, orderValue: row.orderValue,
      totalLines: 0,
    })
    s.setSelectedAmendment(row)
    const ok = await loadPoInto(row.poNo, row.poDate, row.poGroup, 'VIEW')
    if (!ok) { s.setSelectedPo(null); s.setSelectedAmendment(null) }
  }, [loadPoInto, s])

  // ── Initial load: auto-view the latest saved amendment (read-only) ────────
  // The screen must open showing the latest AMENDMENT, not the latest
  // amendable PO, and must NOT enter edit mode on its own — only an explicit
  // Select PO does that (see selectPo). ksp_PO_GetAmendmentList is already
  // ORDER BY AMDORDDT DESC, PORDNO DESC (see the SP), so its first row IS the
  // latest amendment; reusing viewAmendment's load path (→ VIEW mode) instead
  // of adding a new backend call. Ref-guarded so StrictMode's dev double-invoke
  // and re-renders fire exactly one list call, mirroring PrToPoTransferPage's
  // didInitRef.
  const didAutoLoadRef = useRef(false)
  useEffect(() => {
    if (didAutoLoadRef.current || !divCode) return
    didAutoLoadRef.current = true
    void (async () => {
      try {
        const list = await amendApi.getAmendmentList(yfDate, ylDate)
        if (list.length > 0) await viewAmendment(list[0])
      } catch {
        /* no saved amendment yet (or list failed) — Select PO remains available */
      }
    })()
  }, [divCode, yfDate, ylDate]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Record navigation (First / Prev / Next / Last) ────────────────────────
  // Mirrors usePoTransferForm.navigateRecord, but there is no generic "list all
  // POs in FY" endpoint on the Amendment API — ksp_PO_GetAmendablePOList (already
  // used by the picker) IS the correct navigation universe here anyway, since this
  // screen can only ever load a PO that's in that list. FIRST/LAST are O(1) off its
  // DESC sort; PREV/NEXT reverse it to ASC and walk from the current position,
  // matching Transfer's PREV/NEXT convention. Callers (the toolbar's guardedNav)
  // are responsible for confirming discard of unsaved changes before invoking these
  // — navigateRecord itself just loads, exactly like selectPo does for the picker.
  const navigateRecord = useCallback(async (direction: 'FIRST' | 'PREV' | 'NEXT' | 'LAST') => {
    if (!divCode) return
    try {
      const list = await amendApi.getAmendablePOList(yfDate, ylDate)   // DESC: newest first
      if (list.length === 0) {
        notificationService.info('Navigation', 'No amendable Purchase Orders found.')
        return
      }
      if (direction === 'LAST')  { await selectPo(list[0]);              return }
      if (direction === 'FIRST') { await selectPo(list[list.length - 1]); return }

      const ascending = [...list].reverse()   // oldest → newest, mirrors Transfer's ASC convention
      const currIdx = s.currentPo
        ? ascending.findIndex((r) => r.poNo === s.currentPo!.poNo && r.poDate === s.currentPo!.poDate)
        : -1

      let targetIdx: number
      if (direction === 'PREV') {
        if (currIdx <= 0) {
          notificationService.info('Navigation', 'Already at the first record.')
          return
        }
        targetIdx = currIdx - 1
      } else {
        if (currIdx < 0 || currIdx >= ascending.length - 1) {
          notificationService.info('Navigation', 'Already at the last record.')
          return
        }
        targetIdx = currIdx + 1
      }
      await selectPo(ascending[targetIdx])
    } catch (err) {
      notificationService.error('Navigation Failed', getErrorMessage(err))
    }
  }, [divCode, yfDate, ylDate, s, selectPo])

  const goFirst = useCallback(() => { void navigateRecord('FIRST') }, [navigateRecord])
  const goPrev  = useCallback(() => { void navigateRecord('PREV')  }, [navigateRecord])
  const goNext  = useCallback(() => { void navigateRecord('NEXT')  }, [navigateRecord])
  const goLast  = useCallback(() => { void navigateRecord('LAST')  }, [navigateRecord])

  // Boundary checks happen inside navigateRecord at click time (same as Transfer);
  // these just gate the buttons on "is there anything loaded to navigate from".
  const canPrev = !!s.currentPo
  const canNext = !!s.currentPo

  // ── Line editing — one engine (recalcLine), same as Transfer ──────────────
  const updateLineRateQty = useCallback((lineNo: number, patch: { rate?: number; qty?: number }) => {
    const target = s.lines.find((l) => l.lineNo === lineNo)
    if (!target) return

    let next = { ...target, ...patch }
    // Qty guards (VB6 parity), applied client-side so the user sees them immediately;
    // the SP re-checks both (defence in depth).
    if (patch.qty !== undefined) {
      const floor   = (target.receivedQty ?? 0) + (target.cancelledQty ?? 0)  // Gap #4
      const ceiling = target.balanceQty                                       // Gap #5
      if (patch.qty < floor) {
        notificationService.warning(
          'Quantity Below Received/Cancelled',
          `Line ${lineNo}: order quantity cannot be less than received + cancelled (${floor}). Reset to ${floor}.`,
        )
        next = { ...next, qty: floor }
      } else if (patch.qty > ceiling) {
        notificationService.warning(
          'Quantity Exceeds PR Balance',
          `Line ${lineNo}: order quantity cannot exceed the Purchase Requisition balance (max ${ceiling}). Reset to ${ceiling}.`,
        )
        next = { ...next, qty: ceiling }
      }
    }

    const merged = recalcLine(next)
    const original = s.originalLines.find((l) => l.lineNo === lineNo)
    s.updateLine(lineNo, { ...merged, amendChanged: isLineChanged(merged, original) })
  }, [s])

  const applyGstDetail = useCallback((lineNo: number, detail: LineTaxDetail) => {
    const target = s.lines.find((l) => l.lineNo === lineNo)
    if (!target) return false
    const merged = { ...target, ...detail }
    const updated = recalcLine(applyGstRouteToLine(merged, target.route, gstTaxCodes))
    const original = s.originalLines.find((l) => l.lineNo === lineNo)
    s.updateLine(lineNo, { ...updated, amendChanged: isLineChanged(updated, original) })
    return true
  }, [s, gstTaxCodes])

  const setAmendReason = useCallback((lineNo: number, reason: string) => {
    s.updateLine(lineNo, { amendReason: reason })
  }, [s])

  // Gap #12 (VB6 parity): header charge changes cascade to lines — but ONLY to
  // lines with no receipts (ReceivedQty = 0), exactly like VB6's HeadTaxload. A
  // partially-received line keeps its own charges. Header %s push straight to the
  // line; the header freight AMOUNT is split proportionally by line value.
  const cascadeHeaderToLines = useCallback(() => {
    const h = headerForm.getFieldsValue() as Partial<PoHeader>
    const editable = s.lines.filter((l) => (l.receivedQty ?? 0) === 0)
    if (editable.length === 0) return

    const totalValue = editable.reduce((a, l) => a + (l.value || 0), 0)
    const headerFreight = Number(h.freightAmt ?? 0)

    editable.forEach((l) => {
      const share = totalValue > 0 ? (l.value || 0) / totalValue : 0
      const patched: PoLine = {
        ...l,
        discPer:       Number(h.discPer  ?? 0),
        discMode:      'PCT',
        packingPer:    Number(h.packPer  ?? 0),
        packMode:      'PCT',
        insurancePer:  Number(h.insurPer ?? 0),
        insurMode:     'PCT',
        freightAmt:    round2(headerFreight * share),
        freightMode:   'AMT',
        discApp:       (h.discApp           as PoLine['discApp'])       ?? l.discApp,
        packApp:       (h.packApp           as PoLine['packApp'])       ?? l.packApp,
        freightPos:    (h.freightPosition   as PoLine['freightPos'])    ?? l.freightPos,
        insuranceDuty: (h.insurancePosition as PoLine['insuranceDuty']) ?? l.insuranceDuty,
      }
      const merged = recalcLine(patched)
      const original = s.originalLines.find((o) => o.lineNo === l.lineNo)
      s.updateLine(l.lineNo, { ...merged, amendChanged: isLineChanged(merged, original) })
    })
  }, [s, headerForm])

  // ── Derived: which lines changed (FN §3.6) ────────────────────────────────
  const changedLines = useMemo(
    () => s.lines.filter((l) => isLineChanged(l, s.originalLines.find((o) => o.lineNo === l.lineNo))),
    [s.lines, s.originalLines],
  )

  // Changed lines whose Amendment Reason is still blank — these block the save.
  const linesMissingReason = useMemo(
    () => changedLines.filter((l) => !(l.amendReason ?? '').trim()),
    [changedLines],
  )

  const totals = useMemo(() => {
    const orderValue      = round2(s.lines.reduce((a, l) => a + (l.value || 0), 0))
    const totalOrderValue = round2(s.lines.reduce((a, l) => a + (l.netAmount || 0), 0))
    return { orderValue, totalOrderValue, lineCount: s.lines.length }
  }, [s.lines])

  // Header charge defaults the GST modal seeds a line from. Read off the LOADED
  // PO's header (not a fresh-entry header), so opening the modal on an amendment
  // line shows that PO's own charge basis rather than blank/zero values.
  const gstHeaderDefaults: GstHeaderDefaults = useMemo(() => {
    const po = s.currentPo
    return {
      discPer:       po?.discPer      ?? 0,
      discAmt:       po?.discountAmt  ?? 0,
      packingPer:    po?.packPer      ?? 0,
      packingAmt:    po?.packingAmt   ?? 0,
      freightPer:    po?.freightPer   ?? 0,
      freightAmt:    po?.freightAmt   ?? 0,
      insurancePer:  po?.insurPer     ?? 0,
      insuranceAmt:  po?.insuranceAmt ?? 0,
      addTaxPer:     po?.addTaxPer    ?? 0,
      tcsPer:        po?.tcsPer       ?? 0,
      fcaFob:        po?.fcaFob       ?? 0,
      freightPos:    po?.freightPosition   ?? 'BEFORE',
      insuranceDuty: po?.insurancePosition ?? 'BEFORE',
      discApp:       po?.discApp      ?? 'BEFORE',
      packApp:       po?.packApp      ?? 'BEFORE',
    }
  }, [s.currentPo])

  // ── Save (FN §3 + §4) ─────────────────────────────────────────────────────
  const buildSaveRequest = useCallback((): AmendmentSaveRequest | null => {
    const po = s.currentPo
    if (!po?.poNo) return null
    const h = headerForm.getFieldsValue() as Partial<PoHeader>

    const lines: AmendmentLineSaveRequest[] = s.lines.map((l) => ({
      sNo:           l.lineNo,
      itemCode:      l.itemCode,
      prNo:          l.prNo,
      prDate:        l.prDate || null,
      prSno:         l.prSno,
      rate:          l.rate,
      qty:           l.qty,
      weight:        0,
      discPer:       l.discPer,
      packingPer:    l.packingPer,
      freightPer:    l.freightPer,
      insurancePer:  l.insurancePer,
      otherCharges:  l.otherCharges,
      discApp:       l.discApp,
      packApp:       l.packApp,
      freightPos:    l.freightPos,
      insuranceDuty: l.insuranceDuty,
      taxCode:       l.taxCode,
      hsnCode:       l.hsnCode,
      cgstCode:      l.cgstCode,
      sgstCode:      l.sgstCode,
      igstCode:      l.igstCode,
      tcsPer:        l.tcsPer,
      addTaxCode:    l.addTaxCode,
      addTaxPer:     l.addTaxPer,
      remarks:       '',
      itemMemo:      '',
      amendReason:   (l.amendReason ?? '').trim(),
      slots:         s.deliveryLines.find((d) => d.lineNo === l.lineNo)?.slots ?? [],
    }))

    // AntD returns Dayjs for DatePicker fields; the wire contract is 'YYYY-MM-DD'.
    const iso = (v: unknown): string | null =>
      v && dayjs.isDayjs(v) ? v.format('YYYY-MM-DD') : (typeof v === 'string' && v ? v : null)

    return {
      poNo:           po.poNo,
      poDate:         po.poDate,
      poGroup:        s.selectedPo?.poGroup ?? po.orderType,
      carrier:        h.carrier        ?? po.carrier,
      // Unlocked by the 13-Jul ruling (header follows VB6).
      supplier:       h.supplier       ?? po.supplier       ?? '',
      gstin:          h.gstin          ?? po.gstin          ?? '',
      gstState:       h.gstState       ?? po.gstState       ?? '',
      inspect:        h.inspect        ?? po.inspect        ?? '',
      formType:       h.formType       ?? po.formType       ?? '',
      currency:       h.currency       ?? po.currency       ?? '',
      currRate:       h.currRate       ?? po.currRate       ?? 0,
      remarks:        h.remarks        ?? po.remarks        ?? '',
      refNo:          h.refNo          ?? po.refNo          ?? '',
      refDate:        iso(h.refDate    ?? po.refDate),
      fileNo:         h.fileNo         ?? po.fileNo         ?? '',
      paymentTerms:   h.paymentTerms   ?? po.paymentTerms   ?? '',
      creditDays:     h.creditDays     ?? po.creditDays     ?? 0,
      bankCode:       h.bankCode       ?? po.bankCode       ?? '',
      payMode:        h.payMode        ?? po.payMode        ?? 'DIRECT',
      directInstr:    h.directInstr    ?? po.directInstr    ?? '',
      advPer:         h.advPer         ?? po.advPer         ?? 0,
      advAmt:         h.advAmt         ?? po.advAmt         ?? 0,
      chequeNo:       h.chequeNo       ?? po.chequeNo       ?? '',
      chequeDate:     iso(h.chequeDate ?? po.chequeDate),
      deliveryInstr1: h.deliveryLocation ?? po.deliveryLocation ?? '',
      deliveryInstr2: h.billingAddress   ?? po.billingAddress   ?? '',
      specialInstr:   h.specialInstr   ?? po.specialInstr   ?? '',
      dueDate:        iso(h.deliveryDate ?? po.deliveryDate),
      roundOff:       h.roundOff       ?? po.roundOff       ?? 0,
      discPer:        h.discPer        ?? po.discPer        ?? 0,
      packPer:        h.packPer        ?? po.packPer        ?? 0,
      insurPer:       h.insurPer       ?? po.insurPer       ?? 0,
      freightAmt:     h.freightAmt     ?? po.freightAmt     ?? 0,
      packingAmt:     h.packingAmt     ?? po.packingAmt     ?? 0,
      insuranceAmt:   h.insuranceAmt   ?? po.insuranceAmt   ?? 0,
      addTaxPer:      h.addTaxPer      ?? po.addTaxPer      ?? 0,
      freightType:    h.freightType    ?? po.freightType    ?? 'PAID',
      discApp:        h.discApp        ?? po.discApp        ?? 'BEFORE',
      packApp:        h.packApp        ?? po.packApp        ?? 'BEFORE',
      freightPosition:   h.freightPosition   ?? po.freightPosition   ?? 'BEFORE',
      insurancePosition: h.insurancePosition ?? po.insurancePosition ?? 'BEFORE',
      lines,
    }
  }, [s.currentPo, s.lines, s.deliveryLines, s.selectedPo, headerForm])

  // Supplier is amendable since the 13-Jul ruling — and changing it can flip the GST
  // route (CGST+SGST ⇄ IGST) when the new supplier sits in a different state. Every
  // line must therefore be re-routed and recomputed, or the screen would keep showing
  // the OLD supplier's tax split while the SP re-bases it server-side on save.
  // (The server is authoritative either way — this keeps the UI honest, it does not
  // decide the route.)
  const onSupplierChange = useCallback((sup: SupplierOption | null) => {
    if (!sup) return

    // Gap #1/#2 (VB6 parity): a supplier without a GSTIN or GST state code cannot be
    // used. VB6 hard-blocks the selection and reverts; do the same here (the SP is
    // the backstop). Revert to the previously-loaded supplier so the header is never
    // left pointing at an unusable one.
    if (!(sup.gstinNo ?? '').trim()) {
      notificationService.error('GST No. Missing',
        'The GST No. is not available for the selected supplier. Please choose another.')
      headerForm.setFieldsValue({ supplier: s.currentPo?.supplier ?? '' })
      return
    }
    if (!(sup.gstStateCode ?? '').trim()) {
      notificationService.error('GST State Code Missing',
        'The GST state code is not available for the selected supplier. Please choose another.')
      headerForm.setFieldsValue({ supplier: s.currentPo?.supplier ?? '' })
      return
    }

    const gstStateDisplay = resolveGstStateDisplay(sup.gstStateName || sup.gstStateCode, sup.gstStateCode)
    headerForm.setFieldsValue({
      gstin:    sup.gstinNo ?? '',
      gstState: gstStateDisplay,
    })
    const route = getGstRouteFromState(gstStateDisplay)
    s.setLines(
      s.lines.map((l) => {
        const rerouted = recalcLine(applyGstRouteToLine(l, route, gstTaxCodes))
        const original = s.originalLines.find((o) => o.lineNo === l.lineNo)
        return { ...rerouted, amendChanged: isLineChanged(rerouted, original) }
      }),
    )
  }, [s, headerForm, gstTaxCodes])

  /** Client-side gate mirroring the FN §3 rules the server also enforces. */
  const validate = useCallback((): string | null => {
    if (!s.currentPo?.poNo) return 'Select a Purchase Order to amend.'
    // §3.1 — a zero-change amendment is an empty numbered document (VB6 allowed it).
    if (changedLines.length === 0)
      return 'No changes to amend — modify at least one item to complete the transaction.'
    // §3.6 — CEO-confirmed: reason required on ANY changed line, not landed-cost only.
    if (linesMissingReason.length > 0) {
      const nos = linesMissingReason.map((l) => l.lineNo).join(', ')
      return `Amendment Reason is required on every changed line. Missing on line ${nos}.`
    }
    const h = headerForm.getFieldsValue() as Partial<PoHeader>
    // §3.2 / §3.3
    if (!(h.carrier ?? s.currentPo.carrier ?? '').trim()) return 'Carrier cannot be empty.'
    if (!(s.selectedPo?.poGroup ?? s.currentPo.orderType ?? '').trim())
      return 'Order Type cannot be empty.'
    // §3.4 (static half) — the RCVDQTY+CANQTY floor is the SP's (§4.B).
    const bad = s.lines.find((l) => (l.rate ?? 0) <= 0 || (l.qty ?? 0) <= 0)
    if (bad) return `Line ${bad.lineNo}: Rate and Quantity must be greater than zero.`
    return null
  }, [s.currentPo, s.lines, s.selectedPo, changedLines, linesMissingReason, headerForm])

  const [confirmOpen, setConfirmOpen] = useState(false)

  /** FN §3.8 — confirmation prompt before the irreversible numbered document. */
  const requestSave = useCallback(() => {
    const err = validate()
    if (err) {
      notificationService.warning('Cannot Save Amendment', err)
      return
    }
    setConfirmOpen(true)
  }, [validate])

  const confirmSave = useCallback(async () => {
    const request = buildSaveRequest()
    if (!request) return
    s.setSaving(true)
    try {
      const res = await amendApi.amend(request)
      notificationService.success('Amendment Saved', res.message)
      setConfirmOpen(false)
      s.reset()
      headerForm.resetFields()
    } catch (err) {
      notificationService.error('Failed to Save Amendment', getErrorMessage(err))
    } finally {
      s.setSaving(false)
    }
  }, [buildSaveRequest, s, headerForm])

  // Cancel discards the local unsaved edits and reloads the SAME PO read-only
  // (VIEW) instead of blanking the page back to "no PO selected". This also
  // takes mode out of 'AMEND', which is what re-enables Select PO / Find
  // Amendment / record navigation (see the toolbar's canBrowse = !inAmend).
  // Falls back to a full reset only if there is genuinely nothing loaded to
  // restore — Cancel is only reachable while a PO is loaded, so this is
  // defensive, not a normal path.
  const cancelAmend = useCallback(() => {
    const po = s.currentPo
    if (!po || po.poNo == null) {
      s.reset()
      headerForm.resetFields()
      return
    }
    const poGroup = s.selectedPo?.poGroup ?? po.orderType
    void loadPoInto(po.poNo, po.poDate, poGroup, 'VIEW').then((ok) => {
      if (ok) {
        notificationService.info(
          'Amendment Cancelled',
          'Unsaved changes were discarded — showing the saved Purchase Order.',
        )
      }
    })
  }, [s, headerForm, loadPoInto])

  // ── Delete (FN §4 deletion — GRN guard is server-side) ────────────────────
  const deleteOrder = useCallback(async () => {
    const po = s.currentPo
    if (!po?.poNo) return
    s.setSaving(true)
    try {
      await amendApi.deleteOrder({
        poNo:    po.poNo,
        poDate:  po.poDate,
        poGroup: s.selectedPo?.poGroup ?? po.orderType,
      })
      notificationService.success('Purchase Order Deleted', 'The Purchase Order was deleted.')
      s.reset()
      headerForm.resetFields()
    } catch (err) {
      notificationService.error('Failed to Delete', getErrorMessage(err))
    } finally {
      s.setSaving(false)
    }
  }, [s, headerForm])

  return {
    // identity / context
    divCode, processingDate, yfDate, ylDate, headerForm,

    // lookups
    suppliers, orderTypes, carriers, banks, formTypes, currencies, payTerms,
    gstTaxCodes, deliveryLocations, billingAddresses, pricingTermsOpts,
    lookupsLoading, lookupsError, loadLookups,

    // picker
    pickerOpen, openPicker, closePicker, amendablePos, pickerLoading, selectPo,

    // record navigation (toolbar First/Prev/Next/Last)
    navigateRecord, goFirst, goPrev, goNext, goLast, canPrev, canNext,

    // Find Amendment (view-only — see loadPoInto's note on the missing
    // historical-snapshot endpoint)
    findAmendmentOpen, openFindAmendment, closeFindAmendment,
    amendmentList, amendmentListLoading, viewAmendment,

    // state
    mode: s.mode,
    selectedPo: s.selectedPo,
    selectedAmendment: s.selectedAmendment,
    currentPo:  s.currentPo,
    lines:      s.lines,
    deliveryLines: s.deliveryLines,
    selectedLineNo: s.selectedLineNo,
    gstLineNo:  s.gstLineNo,
    loading:    s.loading,
    saving:     s.saving,

    // line ops (reused engine)
    updateLineRateQty, applyGstDetail, setAmendReason, onSupplierChange, cascadeHeaderToLines,
    setSelectedLineNo: s.setSelectedLineNo,
    openGstModal: s.openGstModal,
    closeGstModal: s.closeGstModal,
    addSlot: s.addSlot, updateSlot: s.updateSlot, removeSlot: s.removeSlot,

    // derived
    changedLines, linesMissingReason, totals, gstHeaderDefaults,

    // save / delete
    confirmOpen, setConfirmOpen, requestSave, confirmSave, cancelAmend, deleteOrder,
    validate,
  }
}

export { clampNonNegativeNumber }
