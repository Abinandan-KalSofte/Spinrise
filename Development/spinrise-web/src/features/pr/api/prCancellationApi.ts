import { apiHelpers } from '@/shared/api/client'
import type {
  PrCancellablePrDto,
  PrForCancellationDetail,
  PrCancelledPrDto,
} from '../types'

const BASE = 'pr-cancellation'

export const getCancellable = (yfDate: string, ylDate: string) => {
  const params = new URLSearchParams({ yfDate, ylDate })
  return apiHelpers.get<PrCancellablePrDto[]>(`${BASE}/cancellable?${params}`)
}

export const getPRDetail = (prNo: number, prDate: string, depCode: string) => {
  const params = new URLSearchParams({ prNo: String(prNo), prDate, depCode })
  return apiHelpers.get<PrForCancellationDetail>(`${BASE}/detail?${params}`)
}

export const cancelPR = (prNo: number, prDate: string, depCode: string, cancelReason: string) =>
  apiHelpers.post<void>(`${BASE}/cancel`, { prNo, prDate: prDate, depCode, cancelReason })

export const getCancelledForUndo = (yfDate: string, ylDate: string) => {
  const params = new URLSearchParams({ yfDate, ylDate })
  return apiHelpers.get<PrCancelledPrDto[]>(`${BASE}/cancelled-for-undo?${params}`)
}

export const undoCancellation = (prNo: number, prDate: string, depCode: string, rowVersion: string) =>
  apiHelpers.post<void>(`${BASE}/undo`, { prNo, prDate: prDate, depCode, rowVersion })
