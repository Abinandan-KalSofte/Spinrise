import { apiHelpers } from '@/shared/api/client'
import type { PrForeclosureLineDto, PrForeclosureLineKey } from '../types'

const BASE = 'pr-foreclosure'

export const getOpenLines = (fDate: string, lDate: string, prNoFilter?: string) => {
  const params = new URLSearchParams({ fDate, lDate })
  if (prNoFilter) params.set('prNoFilter', prNoFilter)
  return apiHelpers.get<PrForeclosureLineDto[]>(`${BASE}/open-lines?${params}`)
}

export const saveForeclosure = (lines: PrForeclosureLineKey[]) =>
  apiHelpers.post<{ count: number }>(`${BASE}/save`, { lines })
