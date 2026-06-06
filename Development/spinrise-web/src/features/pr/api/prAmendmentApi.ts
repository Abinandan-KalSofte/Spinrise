import api from '@/shared/api/client'
import { apiHelpers } from '@/shared/api/client'
import type {
  AmendmentSummary,
  AmendmentHeader,
  SaveAmendmentRequest,
} from '../types'

const BASE = 'pr-amendment'

// Convert DD/MM/YYYY → YYYY-MM-DD for safe use in URL path segments.
// Returns the string unchanged if it's already ISO or not a slash-date.
function toIsoDate(date: string): string {
  const m = date.match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
  return m ? `${m[3]}-${m[2]}-${m[1]}` : date
}

export const getAmendmentList = (
  divCode: string,
  fDate: string,
  lDate: string,
  prNo?: number,
  search?: string,
  page = 1,
  pageSize = 50,
) => {
  const params = new URLSearchParams({ divCode, fDate, lDate, page: String(page), pageSize: String(pageSize) })
  if (prNo)   params.set('prNo', String(prNo))
  if (search) params.set('search', search)
  return apiHelpers.get<AmendmentSummary[]>(`${BASE}?${params}`)
}

export const getAmendmentById = (
  divCode: string,
  prNo: number,
  prDate: string,
  amendNo: number,
) => {
  const params = new URLSearchParams({ divCode })
  return apiHelpers.get<AmendmentHeader>(`${BASE}/${prNo}/${toIsoDate(prDate)}/${amendNo}?${params}`)
}

export const getAmendmentForNew = (
  divCode: string,
  prNo: number,
  prDate: string,
) => {
  const params = new URLSearchParams({ divCode })
  return apiHelpers.get<AmendmentHeader>(`${BASE}/for-new/${prNo}/${toIsoDate(prDate)}?${params}`)
}

export const addAmendment = (
  divCode: string,
  fDate: string,
  lDate: string,
  request: SaveAmendmentRequest,
) => {
  const params = new URLSearchParams({ divCode, fDate, lDate })
  return apiHelpers.post<{ amendNo: number }>(`${BASE}?${params}`, request)
}

export const printAmendment = (
  divCode: string,
  prNo: number,
  prDate: string,
  amendNo: number,
): Promise<Blob> => {
  const params = new URLSearchParams({ divCode })
  return api
    .get(`${BASE}/${prNo}/${toIsoDate(prDate)}/${amendNo}/print?${params}`, { responseType: 'blob' })
    .then((r) => r.data as Blob)
}
