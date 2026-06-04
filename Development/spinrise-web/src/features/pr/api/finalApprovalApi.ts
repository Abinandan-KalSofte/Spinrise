import { apiHelpers } from '@/shared/api/client'
import type {
  FinalApprovalGetResponse,
  FinalApprovalSaveRequest,
  CompanyOption,
  DivisionOption,
  ItemHistoryEntry,
} from '../types/finalApprovalTypes'

const BASE = 'finallevel-pr'

export const finalApprovalApi = {
  getPending: (dbName: string, divCode: string, bypass: number) => {
    const p = new URLSearchParams({ dbName, divCode, bypass: String(bypass) })
    return apiHelpers.get<FinalApprovalGetResponse>(`${BASE}?${p}`)
  },

  saveApprovals: (request: FinalApprovalSaveRequest) =>
    apiHelpers.post<{ approvedCount: number; message: string }>(`${BASE}/approve`, request),

  getCompanies: () =>
    apiHelpers.get<CompanyOption[]>(`${BASE}/companies`),

  getDivisions: (dbName: string) =>
    apiHelpers.get<DivisionOption[]>(`${BASE}/divisions?dbName=${dbName}`),

  getItemHistory: (itemCode: string, divCode: string) => {
    const p = new URLSearchParams({ divCode })
    return apiHelpers.get<ItemHistoryEntry[]>(`${BASE}/items/${itemCode}/purchase-history?${p}`)
  },
}
