import api, { apiHelpers } from '@/shared/api/client'
import type { DeptOption, DownloadReportParams, PrItemOption } from '../types/prReportTypes'

const BASE = 'pr'

// ── Lookups ────────────────────────────────────────────────────────────────────

export const getDepartments = (divCode: string) =>
  apiHelpers.get<DeptOption[]>(`${BASE}/departments?divCode=${encodeURIComponent(divCode)}`)

export const getReportItems = (divCode: string) =>
  apiHelpers.get<PrItemOption[]>(`${BASE}/items?divCode=${encodeURIComponent(divCode)}`)

// ── Report generation (Excel download) ────────────────────────────────────────

const EXCEL_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

const FILENAMES = {
  Datewise:       (from: string, to: string) => `PRDatewise_${from}_${to}.xlsx`,
  Departmentwise: (from: string, to: string) => `PRDeptWise_${from}_${to}.xlsx`,
  Itemwise:       (from: string, to: string) => `PRItemWise_${from}_${to}.xlsx`,
} as const

export const downloadReport = async (params: DownloadReportParams): Promise<void> => {
  const { divCode, reportType, fromDate, toDate, deptCodes, itemCodes } = params

  const qp = new URLSearchParams({ divCode, reportType, fromDate, toDate })
  deptCodes.forEach((c) => qp.append('deptCodes', c))
  itemCodes.forEach((c) => qp.append('itemCodes', c))

  const response = await api.get(`${BASE}/download?${qp}`, { responseType: 'blob' })

  const from    = fromDate.replace(/-/g, '')
  const to      = toDate.replace(/-/g, '')
  const filename = FILENAMES[reportType](from, to)

  const blobUrl = URL.createObjectURL(
    new Blob([response.data as BlobPart], { type: EXCEL_MIME })
  )

  const anchor = document.createElement('a')
  anchor.href     = blobUrl
  anchor.download = filename
  document.body.appendChild(anchor)
  anchor.click()
  document.body.removeChild(anchor)

  // Revoke after browser has had time to trigger the download
  setTimeout(() => URL.revokeObjectURL(blobUrl), 5000)
}
