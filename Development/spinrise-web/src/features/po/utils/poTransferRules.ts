import type { ClipboardEvent, KeyboardEvent } from 'react'
import dayjs from 'dayjs'

import type { GstRoute, GstTaxCodeOption, LineTaxDetail, PoLine } from '../types'

const BLOCKED_NUMBER_KEYS = new Set(['-', '+', 'e', 'E'])
const TAMIL_NADU_GST_CODE = '33'

type RouteAwareTaxFields = Pick<
  PoLine,
  'taxCode' | 'cgstCode' | 'sgstCode' | 'igstCode' | 'cgstPer' | 'sgstPer' | 'igstPer'
>

const findTaxCode = (taxCode: string, gstTaxCodes: GstTaxCodeOption[]) =>
  gstTaxCodes.find((entry) => entry.taxCode === taxCode)

const resolveTaxCode = (value: RouteAwareTaxFields | LineTaxDetail) =>
  value.taxCode.trim() || value.cgstCode.trim() || value.sgstCode.trim() || value.igstCode.trim()

export const clampNonNegativeNumber = (value: number | string | null | undefined): number => {
  const numeric = Number(value)
  if (!Number.isFinite(numeric)) return 0
  return Math.max(numeric, 0)
}

export const isNegativeNumber = (value: unknown): boolean => {
  const numeric = Number(value)
  return Number.isFinite(numeric) && numeric < 0
}

export const parseNonNegativeNumber = (value?: string): number => {
  const normalized = (value ?? '').replace(/,/g, '').trim()
  if (!normalized || normalized.startsWith('-')) return 0
  const num = parseFloat(normalized)
  return Number.isFinite(num) && num >= 0 ? num : 0
}

export const preventNegativeNumberKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
  if (BLOCKED_NUMBER_KEYS.has(event.key)) event.preventDefault()
}

export const preventNegativeNumberPaste = (event: ClipboardEvent<HTMLInputElement>) => {
  const pasted = event.clipboardData.getData('text').replace(/,/g, '').trim()
  if (!pasted) return
  const numeric = Number(pasted)
  if (pasted.startsWith('-') || (Number.isFinite(numeric) && numeric < 0)) {
    event.preventDefault()
  }
}

export const NON_NEGATIVE_INPUT_PROPS: {
  min: number
  parser: (displayValue: string | undefined) => number
  onKeyDown: (event: KeyboardEvent<HTMLInputElement>) => void
  onPaste:   (event: ClipboardEvent<HTMLInputElement>) => void
} = {
  min: 0,
  parser: parseNonNegativeNumber,
  onKeyDown: preventNegativeNumberKeyDown,
  onPaste: preventNegativeNumberPaste,
}

export const getCurrentSystemDate = () => dayjs()

export const getCurrentSystemDateIso = () => getCurrentSystemDate().format('YYYY-MM-DD')

export const getGstStateCode = (gstState: string): string => {
  const normalized = gstState.trim()
  if (!normalized) return ''
  const codeMatch = normalized.match(/^(\d{1,2})\b/)
  if (codeMatch) return codeMatch[1].padStart(2, '0')
  if (normalized.toLowerCase().includes('tamil nadu')) return TAMIL_NADU_GST_CODE
  return ''
}

export const getGstRouteFromState = (gstState: string): GstRoute =>
  !gstState.trim() || getGstStateCode(gstState) === TAMIL_NADU_GST_CODE ? 'LOCAL' : 'IGST'

const getRouteAdjustedTaxFields = (
  value: RouteAwareTaxFields | LineTaxDetail,
  route: GstRoute,
  gstTaxCodes: GstTaxCodeOption[],
) => {
  const taxCode = resolveTaxCode(value)
  const taxMaster = taxCode ? findTaxCode(taxCode, gstTaxCodes) : undefined
  const cgstPer = taxMaster?.cgstPer ?? value.cgstPer ?? 0
  const sgstPer = taxMaster?.sgstPer ?? value.sgstPer ?? 0
  const igstPer = taxMaster?.igstPer ?? value.igstPer ?? 0

  if (route === 'LOCAL') {
    return {
      taxCode,
      cgstCode: taxCode,
      sgstCode: taxCode,
      igstCode: '',
      cgstPer,
      sgstPer,
      igstPer: 0,
    }
  }

  return {
    taxCode,
    cgstCode: '',
    sgstCode: '',
    igstCode: taxCode,
    cgstPer: 0,
    sgstPer: 0,
    igstPer,
  }
}

export const applyGstRouteToLine = (
  line: PoLine,
  route: GstRoute,
  gstTaxCodes: GstTaxCodeOption[],
): PoLine => ({
  ...line,
  route,
  ...getRouteAdjustedTaxFields(line, route, gstTaxCodes),
})

export const applyGstRouteToDetail = (
  detail: LineTaxDetail,
  route: GstRoute,
  gstTaxCodes: GstTaxCodeOption[],
): LineTaxDetail => ({
  ...detail,
  ...getRouteAdjustedTaxFields(detail, route, gstTaxCodes),
})
