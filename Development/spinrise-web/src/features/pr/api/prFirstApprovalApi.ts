import api, { apiHelpers } from '@/shared/api/client'
import type {
  PoParaApproval,
  ApprovalDept,
  PrApprovalSummary,
  PrApprovalDetail,
  SaveFirstApprovalRequest,
  DeleteFirstApprovalRequest,
} from '../types/prFirstApprovalTypes'

const BASE = 'pr-first-approval'

export const prFirstApprovalApi = {
  getPoPara: (divCode: string) =>
    apiHelpers.get<PoParaApproval>(`${BASE}/po-para?divCode=${divCode}`),

  getDepartments: (divCode: string) =>
    apiHelpers.get<ApprovalDept[]>(`${BASE}/departments?divCode=${divCode}`),

  getPendingList: (divCode: string, dep: string, yfDate: string, ylDate: string) => {
    const p = new URLSearchParams({ divCode, dep, yfDate, ylDate })
    return apiHelpers.get<PrApprovalSummary[]>(`${BASE}/pending?${p}`)
  },

  getApprovedList: (divCode: string, yfDate: string, ylDate: string) => {
    const p = new URLSearchParams({ divCode, yfDate, ylDate })
    return apiHelpers.get<PrApprovalSummary[]>(`${BASE}/approved?${p}`)
  },

  getDetail: (divCode: string, prNo: number, prDate: string) => {
    const p = new URLSearchParams({ divCode, prNo: String(prNo), prDate })
    return apiHelpers.get<PrApprovalDetail>(`${BASE}/detail?${p}`)
  },

  approve: (divCode: string, request: SaveFirstApprovalRequest) =>
    apiHelpers.post<void>(`${BASE}/approve?divCode=${divCode}`, request),

  deleteApproval: (divCode: string, request: DeleteFirstApprovalRequest) =>
    apiHelpers.post<void>(`${BASE}/delete-approval?divCode=${divCode}`, request),

  getPrintBlobUrl: async (divCode: string, prNo: number, prDate: string): Promise<{ blobUrl: string; filename: string }> => {
    const p = new URLSearchParams({ divCode, prDate })
    const response = await api.get(`${BASE}/${prNo}/print?${p}`, { responseType: 'blob' })
    const blobUrl = URL.createObjectURL(new Blob([response.data as BlobPart], { type: 'application/pdf' }))
    const filename = `PR-APPROVAL-${String(prNo).padStart(5, '0')}.pdf`
    return { blobUrl, filename }
  },
}
