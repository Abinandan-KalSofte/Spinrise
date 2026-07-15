import type { ClipboardEvent, KeyboardEvent } from 'react'
import dayjs from 'dayjs'

import type { ChargeMode, GstRoute, GstTaxCodeOption, LineTaxDetail, PoLine } from '../types'

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

// Decimal-place-limiting parsers for InputNumber fields.
// The parser is called on every keystroke — truncating here prevents the user from
// typing more than dp decimal places without modifying the value after the fact.
const parsePrecision = (dp: number) => (value?: string): number => {
  const cleaned = (value ?? '').replace(/,/g, '').trim()
  if (!cleaned || cleaned.startsWith('-')) return 0
  const dotIdx = cleaned.indexOf('.')
  const limited = dotIdx >= 0 ? cleaned.slice(0, dotIdx + 1 + dp) : cleaned
  const num = parseFloat(limited)
  return Number.isFinite(num) && num >= 0 ? num : 0
}
// Percentage fields: max 2 decimal places (e.g. 5, 5.2, 5.25 — not 5.256)
export const parsePct2dp  = parsePrecision(2)
// Amount fields: max 3 decimal places (e.g. 39.789 — not 39.7891)
export const parseAmt3dp  = parsePrecision(3)
// Charge amount fields (₹): max 2 decimal places — DB stores amounts as NUMERIC(13,2)
export const parseAmt2dp  = parsePrecision(2)

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

// ── Single calculation engine — shared money helpers (T-0081) ────────────────
// ONE implementation used by the hook (recalcLine, cascade), the header tab
// (TaxDiscountTab), and the GST popup (GstTaxDetailsModal). No layer re-implements
// charge math — they all call resolveCharge, so a % and its amount can never drift.
export const round2 = (n: number) => Math.round(n * 100) / 100
export const round3 = (n: number) => Math.round(n * 1000) / 1000
// Percentage → amount (2dp currency).
export const pctOf  = (base: number, pct: number) => round2((base * (pct || 0)) / 100)
// Amount → percentage. Full internal precision — display rounded by InputNumber precision={2}.
// Do NOT wrap in round2 here: the stored per is used in pctOf on mode-flip; rounding it first
// causes pctOf(base, round2_per) ≠ original amt (e.g. 200 → 0.29% → 203.00).
export const calcPct = (amt: number, base: number) => (base > 0 ? ((amt || 0) / base) * 100 : 0)

// Resolve one commercial charge to { amt, per } from its intent mode.
//   PCT → % authoritative; amount = base × %/100 (2dp).
//   AMT → amount authoritative, preserved to 3dp exactly; % = amt/base×100 (2dp, display).
// When mode is undefined (legacy/DB rows) the pre-refactor rule is inferred:
//   amountFirst=false (Discount/Packing/Insurance): "% wins" → %>0 ? PCT : AMT
//   amountFirst=true  (Freight):                    "amount wins" → amt>0 ? AMT : PCT
// In the inferred path the incoming `per` is passed through unchanged (strict no-op);
// only an explicit mode makes the engine emit a freshly-derived display %.
export const resolveCharge = (
  base: number, per: number, amt: number,
  mode: ChargeMode | undefined, amountFirst: boolean,
): { amt: number; per: number } => {
  const explicit = mode !== undefined
  const effMode: ChargeMode = mode
    ?? (amountFirst ? ((amt || 0) > 0 ? 'AMT' : 'PCT')
                    : ((per || 0) > 0 ? 'PCT' : 'AMT'))
  if (effMode === 'PCT') {
    return { amt: pctOf(base, per), per: per || 0 }
  }
  return {
    amt: round3(amt || 0),
    per: explicit ? calcPct(amt || 0, base) : (per || 0),
  }
}

// ── Header Amount guard (Amount mode only) — new business rule, additive ─────
// Once a header Packing/Insurance/Freight charge is Amount-authored with a value
// > 0, the sum of that charge across ALL lines (overridden and inherited) must
// never exceed the header amount. Does not touch %-mode, Discount, GST popup
// internals, save logic, or header→line cascade/redistribution — evaluated on a
// candidate line set before any of that logic runs; pure pass/fail gate.
export type AmountGuardCharge = 'pack' | 'insur' | 'freight'

const AMOUNT_GUARD_FIELD: Record<AmountGuardCharge, 'packingAmt' | 'insuranceAmt' | 'freightAmt'> = {
  pack: 'packingAmt', insur: 'insuranceAmt', freight: 'freightAmt',
}

export const AMOUNT_GUARD_MESSAGE: Record<AmountGuardCharge, string> = {
  pack:    'Total Packing Amount across all line items cannot exceed the Header Packing Amount.',
  insur:   'Total Insurance Amount across all line items cannot exceed the Header Insurance Amount.',
  freight: 'Total Freight Amount across all line items cannot exceed the Header Freight Amount.',
}

export const checkHeaderAmountGuard = (
  charge: AmountGuardCharge,
  candidateLines: PoLine[],
  headerMode: ChargeMode | undefined,
  headerAmt: number,
): boolean => {
  if (headerMode !== 'AMT' || !(headerAmt > 0)) return true
  const field = AMOUNT_GUARD_FIELD[charge]
  const sum = round2(candidateLines.reduce((s, l) => s + (Number(l[field]) || 0), 0))
  return sum <= round2(headerAmt) + 0.005
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
