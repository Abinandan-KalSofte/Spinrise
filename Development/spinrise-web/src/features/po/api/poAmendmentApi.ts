import { apiHelpers } from '@/shared/api/client'
import type {
  AmendablePoSummary,
  AmendmentSummary,
  PoAmendmentHeaderDto,
  AmendmentSaveRequest,
  AmendmentSaveResponse,
  DeleteOrderRequest,
  DeleteLinesRequest,
} from '../types'

// PO Amendment backend (FN-PO-Amendment v1.2). Every call routes through this ONE
// const so the route prefix can be retargeted in one place.
//
// ⚠ The 6 SPs behind these endpoints are Mariyaiya's and are NOT YET AUTHORED
// (CEO 12-Jul, E-0046). The C# layer is built contract-first; these calls go live
// the moment his SP bodies land. Until then every endpoint will 500 at the DB.
const BASE = 'po-amendment'

// ksp_PO_GetAmendablePOList — POs eligible for amendment (FN §1 predicate is
// server-side: AmdAfterGRN branch, open balance, not cancelled/foreclosed).
export const getAmendablePOList = (yfDate: string, ylDate: string) => {
  const params = new URLSearchParams({ yfDate, ylDate })
  return apiHelpers.get<AmendablePoSummary[]>(`${BASE}/amendable-po-list?${params}`)
}

// ksp_PO_GetPOForAmend — header + lines + delivery schedule for one PO.
export const getPOForAmend = (poNo: number, poDate: string, group: string) => {
  const params = new URLSearchParams({ poNo: String(poNo), poDate, group })
  return apiHelpers.get<PoAmendmentHeaderDto>(`${BASE}/po?${params}`)
}

// ksp_PO_GetAmendmentList — Find mode: saved amendments for the year (view-only).
export const getAmendmentList = (yfDate: string, ylDate: string) => {
  const params = new URLSearchParams({ yfDate, ylDate })
  return apiHelpers.get<AmendmentSummary[]>(`${BASE}/amendment-list?${params}`)
}

// ksp_PO_AmendOrder — allocate Amd No, snapshot to PO_AORDH/L, update live PO,
// delta-backflush PO_PRL. Returns the allocated Amendment No.
export const amend = (request: AmendmentSaveRequest) =>
  apiHelpers.post<AmendmentSaveResponse>(`${BASE}/amend`, request)

// ksp_PO_DeleteOrder — whole-PO cascade delete.
export const deleteOrder = (request: DeleteOrderRequest) =>
  apiHelpers.post<void>(`${BASE}/delete-order`, request)

// ksp_PO_DeleteLines — line-level delete.
export const deleteLines = (request: DeleteLinesRequest) =>
  apiHelpers.post<void>(`${BASE}/delete-lines`, request)
