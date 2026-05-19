// April-March financial year bounds
export function getFYBounds(date: Date = new Date()): { yfDate: string; ylDate: string } {
  const month  = date.getMonth()       // 0-indexed
  const year   = date.getFullYear()
  const fyYear = month >= 3 ? year : year - 1
  return {
    yfDate: `${fyYear}-04-01`,
    ylDate: `${fyYear + 1}-03-31`,
  }
}
