export function prefixFilterOption(input: string, option?: { label?: string }): boolean {
  return (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
}

export function priorityFilterSort(
  optA: { label?: string },
  optB: { label?: string },
  info: { searchValue: string },
): number {
  const a = (optA.label ?? '').toLowerCase()
  const b = (optB.label ?? '').toLowerCase()
  const q = info.searchValue.toLowerCase()
  const aStarts = a.startsWith(q)
  const bStarts = b.startsWith(q)
  if (aStarts && !bStarts) return -1
  if (!aStarts && bStarts) return 1
  return a.localeCompare(b)
}
