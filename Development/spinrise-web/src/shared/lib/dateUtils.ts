import type { Dayjs } from 'dayjs'
import dayjs from 'dayjs'

// April-March financial year bounds (processing-date-capped).
// ylDate is capped at `date` so records dated after the user's login date
// never appear in any listing. Use for PO Date, Ref Date (no future allowed).
export function getFYBounds(date: Date = new Date()): { yfDate: string; ylDate: string } {
  const month   = date.getMonth()       // 0-indexed
  const year    = date.getFullYear()
  const fyYear  = month >= 3 ? year : year - 1
  const fyEnd   = `${fyYear + 1}-03-31`
  const dateStr = date.toISOString().split('T')[0]
  return {
    yfDate: `${fyYear}-04-01`,
    ylDate: dateStr < fyEnd ? dateStr : fyEnd,
  }
}

// Full FY end date (31 March) — NOT capped at processing date.
// Use for future-facing date fields like Delivery Date where the allowed range
// extends to the end of the financial year even if that date is in the future.
export function getFYEndDate(processingDate?: string | null): string {
  const date   = processingDate ? new Date(processingDate) : new Date()
  const month  = date.getMonth()
  const year   = date.getFullYear()
  const fyYear = month >= 3 ? year : year - 1
  return `${fyYear + 1}-03-31`
}

// Validate that a Dayjs date falls within the active FY (capped at processingDate).
// Returns an error message string, or null when the date is valid.
export function validateFYDate(
  date: Dayjs,
  processingDate?: string | null,
  label = 'Date',
): string | null {
  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const fyStart = dayjs(yfDate)
  const fyEnd   = dayjs(ylDate)
  if (date.isBefore(fyStart, 'day') || date.isAfter(fyEnd, 'day')) {
    return `${label} must be within the active financial year (${fyStart.format('DD-MMM-YYYY')} – ${fyEnd.format('DD-MMM-YYYY')}).`
  }
  return null
}

// disabledDate callback for past-only fields (FY bounds + no future).
// Use with PO Date, Ref Date.
export function fyPastDisabledDate(
  processingDate?: string | null,
  additionalMin?: string | null,   // e.g. lastPoDate lower bound
): (d: Dayjs) => boolean {
  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const fyStart = dayjs(yfDate)
  const fyEnd   = dayjs(ylDate)
  const minDate = additionalMin ? dayjs(additionalMin) : null
  return (d: Dayjs) => {
    if (d.isBefore(fyStart, 'day') || d.isAfter(fyEnd, 'day')) return true
    if (minDate && d.isBefore(minDate, 'day')) return true
    return false
  }
}

// disabledDate callback for future-facing fields (FY bounds + no past dates).
// Use with Delivery Date where today and future within FY are allowed.
export function fyFutureDisabledDate(processingDate?: string | null): (d: Dayjs) => boolean {
  const { yfDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)
  const fyStart   = dayjs(yfDate)
  const fyEndFull = dayjs(getFYEndDate(processingDate))
  const today     = dayjs()
  return (d: Dayjs) => {
    if (d.isBefore(fyStart, 'day') || d.isAfter(fyEndFull, 'day')) return true
    if (d.isBefore(today, 'day')) return true
    return false
  }
}
