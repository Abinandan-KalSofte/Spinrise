import api, { apiHelpers } from '@/shared/api/client'
import type {
  PrParameters, PreAddChecks,
  DepartmentOption, EmployeeOption, PrTypeOption,
  ItemLookup, ItemDetail,
  PrHeader, PrSummary,
  SavePrRequest, DeletePrRequest,
  PendingOrder,
  UserPermissions,
} from '../types'

const BASE = 'pr'

// ── Screen init ────────────────────────────────────────────────────────────────

export const getParameters = (divCode: string) =>
  apiHelpers.get<PrParameters>(`${BASE}/parameters?divCode=${divCode}`)

export const runPreAddChecks = (divCode: string) =>
  apiHelpers.get<PreAddChecks>(`${BASE}/pre-add-checks?divCode=${divCode}`)

// ── Lookups ────────────────────────────────────────────────────────────────────

export const getDepartments = (divCode: string, search?: string) =>
  apiHelpers.get<DepartmentOption[]>(
    `${BASE}/departments?divCode=${divCode}${search ? `&search=${encodeURIComponent(search)}` : ''}`
  )

export const getEmployees = (divCode: string, empCommon: string, search?: string) =>
  apiHelpers.get<EmployeeOption[]>(
    `${BASE}/employees?divCode=${divCode}&empCommon=${empCommon}${search ? `&search=${encodeURIComponent(search)}` : ''}`
  )

export const getPrTypes = (activeOnly = true) =>
  apiHelpers.get<PrTypeOption[]>(`${BASE}/pr-types?activeOnly=${activeOnly}`)

export const getItems = (divCode: string, search?: string, itemGrpCode?: string, page = 1, pageSize = 50) => {
  const params = new URLSearchParams({ divCode, page: String(page), pageSize: String(pageSize) })
  if (search)      params.set('search', search)
  if (itemGrpCode) params.set('itemGrpCode', itemGrpCode)
  return apiHelpers.get<ItemLookup[]>(`${BASE}/items?${params}`)
}

export const getItemDetail = (divCode: string, itemCode: string, fDate: string, lDate: string, pDate: string) => {
  const params = new URLSearchParams({ divCode, fDate, lDate, pDate })
  return apiHelpers.get<ItemDetail>(`${BASE}/items/${encodeURIComponent(itemCode)}/detail?${params}`)
}

export const checkPendingOrder = (divCode: string, fDate: string, lDate: string, depCode: string, itemCode: string) => {
  const params = new URLSearchParams({ divCode, fDate, lDate, depCode })
  return apiHelpers.get<PendingOrder>(`${BASE}/items/${encodeURIComponent(itemCode)}/pending-order?${params}`)
}

// ── PR data ────────────────────────────────────────────────────────────────────

export const getLastRecord = (divCode: string, fDate: string, lDate: string) =>
  apiHelpers.get<PrHeader | null>(`${BASE}/last?divCode=${divCode}&fDate=${fDate}&lDate=${lDate}`)

export const getById = (divCode: string, prNo: number, prDate: string) =>
  apiHelpers.get<PrHeader>(`${BASE}/${prNo}?divCode=${divCode}&prDate=${prDate}`)

export const getList = (divCode: string, fDate: string, lDate: string, mode: string, params?: {
  depCode?: string
  reqName?: string
  poGrp?: string
  page?: number
  pageSize?: number
}) => {
  const p = new URLSearchParams({ divCode, fDate, lDate, mode })
  if (params?.depCode)  p.set('depCode',  params.depCode)
  if (params?.reqName)  p.set('reqName',  params.reqName)
  if (params?.poGrp)    p.set('poGrp',    params.poGrp)
  if (params?.page)     p.set('page',     String(params.page))
  if (params?.pageSize) p.set('pageSize', String(params.pageSize))
  return apiHelpers.get<PrSummary[]>(`${BASE}?${p}`)
}

// ── CRUD ───────────────────────────────────────────────────────────────────────

export const addPr = (divCode: string, fDate: string, lDate: string, request: SavePrRequest) => {
  const params = new URLSearchParams({ divCode, fDate, lDate })
  return apiHelpers.post<{ prNo: number }>(`${BASE}?${params}`, request)
}

export const modifyPr = (divCode: string, fDate: string, lDate: string, request: SavePrRequest) => {
  const params = new URLSearchParams({ divCode, fDate, lDate })
  return apiHelpers.put<{ prNo: number }>(`${BASE}?${params}`, request)
}

export const deletePr = (divCode: string, request: DeletePrRequest) =>
  apiHelpers.del<void>(`${BASE}?divCode=${divCode}`, { data: request })

// ── Permissions ────────────────────────────────────────────────────────────────

export const getUserPermissions = (divCode: string) =>
  apiHelpers.get<UserPermissions>(`${BASE}/permissions?divCode=${divCode}`)

// ── Print ──────────────────────────────────────────────────────────────────────

export const printPr = async (divCode: string, prNo: number, prDate: string): Promise<void> => {
  const params = new URLSearchParams({ divCode, prDate })
  const response = await api.get(`${BASE}/${prNo}/print?${params}`, { responseType: 'blob' })
  const url  = URL.createObjectURL(new Blob([response.data as BlobPart], { type: 'application/pdf' }))
  const link = document.createElement('a')
  link.href     = url
  link.download = `PR-${String(prNo).padStart(5, '0')}.pdf`
  link.click()
  URL.revokeObjectURL(url)
}
