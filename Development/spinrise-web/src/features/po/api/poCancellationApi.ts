import { apiHelpers } from '@/shared/api/client'
import type { CancellationReason, POCancellationLineDto, CancelSaveRequest, PoOpenSummary } from '../types'

// PO Cancellation backend (FN-PO-Cancellation v1.4). Every call routes through this
// ONE const so the route prefix can be retargeted in one place.
const BASE = 'po-cancellation'

// ksp_PO_GetCancelReasons.
export const getReasons = () =>
  apiHelpers.get<CancellationReason[]>(`${BASE}/reasons`)

// Open POs eligible for cancellation — ksp_PO_GetOpenPOList (FN §5). Dedicated
// picker source: narrower + cancel-aware, unlike the generic po-transfer getList
// shared by PR-to-PO Transfer / PO Approval print.
export const getOpenPOList = (yfDate: string, ylDate: string) => {
  const params = new URLSearchParams({ yfDate, ylDate })
  return apiHelpers.get<PoOpenSummary[]>(`${BASE}/open-po-list?${params}`)
}

// Open PO lines eligible for cancellation — ksp_PO_GetPOLinesForCancel.
export const getOpenLines = (poNo: number, poDate: string) => {
  const params = new URLSearchParams({ poNo: String(poNo), poDate })
  return apiHelpers.get<POCancellationLineDto[]>(`${BASE}/lines?${params}`)
}

export const cancelLines = (request: CancelSaveRequest) =>
  apiHelpers.post<void>(`${BASE}/cancel`, request)
