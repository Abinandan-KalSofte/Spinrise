import api, { apiHelpers } from '@/shared/api/client'
import type { ApiResponse } from '@/shared/api/client'
import { formatPoNo } from '../types'
import type {
  PoParameters, PoPreAddChecks,
  SupplierOption, OrderTypeOption, CarrierOption, BankOption,
  FormTypeOption, AddressOption, CurrencyOption, PayTermOption,
  EligiblePrLine,
  PoHeader, PoSummary,
  AddPoRequest, DeletePoRequest,
  GstRoutingResult, GstTaxCodeOption,
} from '../types'

// ⚠ Q1 PENDING (Gate 0 — BLOCKER): module/DB/SP identity is unresolved.
//   MD + FSD say `ksp_PO_*` on the main DB ⇒ base segment 'po'.
//   CLAUDE.md M02 (RMI PO) says `ksp_RMI_PO_*` on JAT ⇒ base segment would differ.
//   Every call routes through this ONE const so a single edit retargets the API
//   once Sasi/CEO confirm. Do not inline the segment anywhere else.
const BASE = 'po'

// ── Screen init ──────────────────────────────────────────────────────────────

export const getParameters = (divCode: string) =>
  apiHelpers.get<PoParameters>(`${BASE}/parameters?divCode=${divCode}`)

export const runPreAddChecks = (divCode: string) =>
  apiHelpers.get<PoPreAddChecks>(`${BASE}/pre-add-checks?divCode=${divCode}`)

// ── Lookups (provisional — Q7) ───────────────────────────────────────────────

export const getSuppliers = (divCode: string) => {
  const p = new URLSearchParams({ divCode })
  return apiHelpers.get<SupplierOption[]>(`${BASE}/suppliers?${p}`)
}

export const getOrderTypes = (activeOnly = true) =>
  apiHelpers.get<OrderTypeOption[]>(`${BASE}/order-types?activeOnly=${activeOnly}`)

export const getCarriers = (search?: string) => {
  const p = new URLSearchParams()
  if (search) p.set('search', search)
  return apiHelpers.get<CarrierOption[]>(`${BASE}/carriers?${p}`)
}

export const getBanks = (divCode: string, search?: string) => {
  const p = new URLSearchParams({ divCode })
  if (search) p.set('search', search)
  return apiHelpers.get<BankOption[]>(`${BASE}/banks?${p}`)
}

export const getFormTypes = () =>
  apiHelpers.get<FormTypeOption[]>(`${BASE}/form-types`)

export const getGstTaxCodes = (search?: string) => {
  const p = new URLSearchParams()
  if (search) p.set('search', search)
  return apiHelpers.get<GstTaxCodeOption[]>(`${BASE}/gst-tax-codes?${p}`)
}

export const getCurrencies = () =>
  apiHelpers.get<CurrencyOption[]>(`${BASE}/currencies`)

export const getAddresses = (divCode: string, kind: 'DELIVERY' | 'BILLING', search?: string) => {
  const p = new URLSearchParams({ divCode, kind })
  if (search) p.set('search', search)
  return apiHelpers.get<AddressOption[]>(`${BASE}/addresses?${p}`)
}

export const getDeliveryLocations = (divCode: string, search?: string) =>
  getAddresses(divCode, 'DELIVERY', search)

export const getBillingAddresses = (divCode: string, search?: string) =>
  getAddresses(divCode, 'BILLING', search)

export const getPayTerms = () =>
  apiHelpers.get<PayTermOption[]>(`${BASE}/pay-terms`)

export const getPricingTerms = (search?: string) => {
  const p = new URLSearchParams()
  if (search) p.set('search', search)
  return apiHelpers.get<AddressOption[]>(`${BASE}/pricing-terms?${p}`)
}

// ── PR Picker — eligible approved PR lines (BR-02 filtered server-side) ───────
// Order Type is NOT a filter here — all eligible approved PR lines are returned
// regardless of the PO's order type; only free-text search + paging are sent.

export const getEligiblePrLines = (
  divCode: string,
  params?: { search?: string; page?: number; pageSize?: number },
) => {
  const p = new URLSearchParams({ divCode })
  if (params?.search)    p.set('search',    params.search)
  if (params?.page)      p.set('page',      String(params.page))
  if (params?.pageSize)  p.set('pageSize',  String(params.pageSize))
  return apiHelpers.get<EligiblePrLine[]>(`${BASE}/eligible-pr-lines?${p}`)
}

// ── GST routing — SERVER-SIDE (Q4 PENDING) ───────────────────────────────────
// ⚠ The UI must DISPLAY this result, never derive it (FSD §5.6 / D-07).
//   Contract is PROVISIONAL: confirm whether routing is returned inline on
//   supplier selection or via this dedicated call.
export const getGstRouting = (divCode: string, supplier: string) =>
  apiHelpers.get<GstRoutingResult>(
    `${BASE}/gst-routing?divCode=${divCode}&supplier=${encodeURIComponent(supplier)}`,
  )

// ── Header-tax propagation — SERVER-SIDE (Q5 PENDING) ─────────────────────────
// ⚠ VB6 HeadTaxload → server endpoint (D-05 / Rec #6). Requires a SAVED PO id.
//   In ADD mode there is no id yet; pre-save behaviour is UNCONFIRMED (Q5).
//   Endpoint kept behind this fn so the UI never loops over lines client-side.
export const applyHeaderTax = async (divCode: string, poNo: number, poDate: string, body: {
  cgstPer?: number; sgstPer?: number; igstPer?: number; tcsPer?: number
  discPer?: number; packPer?: number; insurPer?: number; freightAmt?: number
}): Promise<PoHeader> => {
  // apiHelpers has no `patch`; unwrap raw api.patch (same pattern as getPrintBlobUrl).
  const p = new URLSearchParams({ divCode, poDate })
  const res = await api.patch<ApiResponse<PoHeader>>(`${BASE}/${poNo}/lines/apply-header-tax?${p}`, body)
  return res.data.data as PoHeader
}

// ── PO data ──────────────────────────────────────────────────────────────────

export const getLastRecord = (divCode: string, fDate: string, lDate: string) =>
  apiHelpers.get<PoHeader | null>(`${BASE}/last?divCode=${divCode}&fDate=${fDate}&lDate=${lDate}`)

export const getFirstRecord = (divCode: string, fDate: string, lDate: string) =>
  apiHelpers.get<PoHeader | null>(`${BASE}/first?divCode=${divCode}&fDate=${fDate}&lDate=${lDate}`)

export const getById = (divCode: string, poNo: number, poDate: string) =>
  apiHelpers.get<PoHeader>(`${BASE}/${poNo}?divCode=${divCode}&poDate=${poDate}`)

// Find/Query — deferred this sprint (Q6); kept for Sprint-N reuse.
export const getList = (divCode: string, fDate: string, lDate: string, params?: {
  supplier?: string; search?: string; page?: number; pageSize?: number
}) => {
  const p = new URLSearchParams({ divCode, fDate, lDate,mode: 'FIND' })
  if (params?.supplier) p.set('supplier', params.supplier)
  if (params?.search)   p.set('search',   params.search)
  if (params?.page)     p.set('page',     String(params.page))
  if (params?.pageSize) p.set('pageSize', String(params.pageSize))
  return apiHelpers.get<PoSummary[]>(`${BASE}?${p}`)
}

// ── CRUD ─────────────────────────────────────────────────────────────────────

// PO No is allocated server-side AFTER validation (CD-03 / UX-04). The response
// carries the real number — the UI never displays a guessed one.
export const addPo = (divCode: string, fDate: string, lDate: string, request: AddPoRequest) => {
  const p = new URLSearchParams({ divCode, fDate, lDate })
  return apiHelpers.post<{ poNo: number; poDate: string }>(`${BASE}?${p}`, request)
}

// GRN guard (BR-03) is enforced server-side → expect HTTP 409 if any GRN exists.
export const deletePo = (divCode: string, request: DeletePoRequest) =>
  apiHelpers.del<void>(`${BASE}?divCode=${divCode}`, { data: request })

// ── Print (approval-gated — FSD §5.18; QuestPDF backend, out of scope here) ───

export const getPrintBlobUrl = async (
  divCode: string,
  poNo: number,
  poDate: string,
): Promise<{ blobUrl: string; filename: string }> => {
  const p = new URLSearchParams({ divCode, poDate })
  const response = await api.get(`${BASE}/${poNo}/print?${p}`, { responseType: 'blob' })
  const blobUrl = URL.createObjectURL(new Blob([response.data as BlobPart], { type: 'application/pdf' }))
  const filename = `${formatPoNo(poNo)}.pdf`
  return { blobUrl, filename }
}

export const getPrintV2BlobUrl = async (
  divCode: string,
  poNo: number,
  poDate: string,
): Promise<{ blobUrl: string; filename: string }> => {
  const p = new URLSearchParams({ divCode, poDate })
  const response = await api.get(`${BASE}/${poNo}/print-v2?${p}`, { responseType: 'blob' })
  const blobUrl = URL.createObjectURL(new Blob([response.data as BlobPart], { type: 'application/pdf' }))
  const filename = `${formatPoNo(poNo)}.pdf`
  return { blobUrl, filename }
}
