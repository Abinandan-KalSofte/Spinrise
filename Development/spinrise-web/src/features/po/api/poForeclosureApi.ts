import { apiHelpers } from '@/shared/api/client'
import type { POForeclosureLineDto, ForeclosureSaveRequest } from '../types'

// PO Foreclosure backend (FN-PO-Foreclosure v1.4). Every call routes through this
// ONE const so the route prefix can be retargeted in one place.
const BASE = 'po-foreclosure'

// ksp_PO_GetOpenLinesForForeclose. No params — this screen loads every open PO line
// up front; filtering is client-side (PO No. box).
export const getOpenLines = () =>
  apiHelpers.get<POForeclosureLineDto[]>(`${BASE}/lines`)

// ksp_PO_ForeCloseLines.
export const foreclosureLines = (request: ForeclosureSaveRequest) =>
  apiHelpers.post<void>(`${BASE}/foreclose`, request)
