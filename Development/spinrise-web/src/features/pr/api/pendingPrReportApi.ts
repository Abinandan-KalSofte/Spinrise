import api from '@/shared/api/client'
import type { DownloadReportParams } from '../types/prReportTypes'

const BASE = 'pending-pr'

const PDF_MIME = 'application/pdf'

const FILENAMES: Record<string, (from: string, to: string) => string> = {
  Datewise:       (from, to) => `PendingPRDatewise_${from}_${to}.pdf`,
  Departmentwise: (from, to) => `PendingPRDeptWise_${from}_${to}.pdf`,
  Itemwise:       (from, to) => `PendingPRItemWise_${from}_${to}.pdf`,
}

function buildQueryString(params: DownloadReportParams): string {
  const { divCode, reportType, fromDate, toDate, allDepts, deptCodes, allItems, itemCodes, allSuppliers, supplierCodes } = params
  const qp = new URLSearchParams({ divCode, reportType, fromDate, toDate, allDepts: String(allDepts), allItems: String(allItems), allSuppliers: String(allSuppliers) })
  if (!allDepts) deptCodes.forEach((c) => qp.append('deptCodes', c))
  if (!allItems) itemCodes.forEach((c) => qp.append('itemCodes', c))
  if (!allSuppliers) supplierCodes.forEach((c) => qp.append('supplierCodes', c))
  return qp.toString()
}

export interface ReportBlobResult {
  blobUrl:  string
  filename: string
}

export const fetchPendingPrReportBlob = async (params: DownloadReportParams): Promise<ReportBlobResult> => {
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
