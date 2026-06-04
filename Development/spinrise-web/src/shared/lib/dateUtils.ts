// April-March financial year bounds.
// ylDate is capped at `date` (the processing/transaction date) so records dated
// after the user's login date never appear in any listing.
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
