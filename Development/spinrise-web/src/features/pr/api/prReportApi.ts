import api, { apiHelpers } from '@/shared/api/client'
import type { DeptOption, DownloadReportParams, PrItemOption } from '../types/prReportTypes'

const BASE = 'pr'

// ── Lookups ────────────────────────────────────────────────────────────────────

export const getDepartments = (divCode: string) =>
  apiHelpers.get<DeptOption[]>(`${BASE}/departments?divCode=${encodeURIComponent(divCode)}`)

export const getReportItems = (divCode: string) =>
  apiHelpers.get<PrItemOption[]>(`${BASE}/items?divCode=${encodeURIComponent(divCode)}&pageSize=9999`)

// ── Report generation ──────────────────────────────────────────────────────────

const PDF_MIME = 'application/pdf'

const FILENAMES: Record<string, (from: string, to: string) => string> = {
  Datewise:       (from, to) => `PRDatewise_${from}_${to}.pdf`,
  Departmentwise: (from, to) => `PRDeptWise_${from}_${to}.pdf`,
  Itemwise:       (from, to) => `PRItemWise_${from}_${to}.pdf`,
}

function buildQueryString(params: DownloadReportParams): string {
  const { divCode, reportType, fromDate, toDate, depCode, allItems, itemCodes } = params
  const qp = new URLSearchParams({ divCode, reportType, fromDate, toDate, allItems: String(allItems) })
  if (depCode) qp.set('depCode', depCode)
  if (!allItems) itemCodes.forEach((c) => qp.append('itemCodes', c))
  return qp.toString()
}

export interface ReportBlobResult {
  blobUrl:  string
  filename: string
}

/** Fetch the report PDF from the API and return an in-memory blob URL + filename. */
export const fetchReportBlob = async (params: DownloadReportParams): Promise<ReportBlobResult> => {
  const response = await api.get(`${BASE}/report/download?${buildQueryString(params)}`, {
    responseType: 'blob',
  })

  const from     = params.fromDate.replace(/-/g, '')
  const to       = params.toDate.replace(/-/g, '')
  const filename = (FILENAMES[params.reportType] ?? FILENAMES['Datewise'])(from, to)

  const blobUrl = URL.createObjectURL(
    new Blob([response.data as BlobPart], { type: PDF_MIME }),
  )

  return { blobUrl, filename }
}

/** Programmatically trigger a browser download from an existing blob URL. */
export const triggerDownload = (blobUrl: string, filename: string): void => {
  const anchor    = document.createElement('a')
  anchor.href     = blobUrl
  anchor.download = filename
  document.body.appendChild(anchor)
  anchor.click()
  document.body.removeChild(anchor)
}
