import { useCallback, useEffect, useRef, useState } from 'react'

interface UseLookupModalOptions<T> {
  /**
   * Called on mount (autoLoad=true) and whenever the debounced search term changes.
   * Return an empty array if preconditions (e.g. divCode) are not yet met.
   */
  fetcher: (q: string) => Promise<T[]>
  /** Extract a stable unique key from a row — used for selection identity. */
  keyOf: (item: T) => string
  /** Called when the user confirms a selection (double-click or Select button). */
  onSelect: (item: T) => void
  /** Fetch with empty query on mount. Default: true. */
  autoLoad?: boolean
  /** Debounce delay for search input in ms. Default: 300. */
  debounceMs?: number
}

interface UseLookupModalResult<T> {
  items: T[]
  loading: boolean
  search: string
  selected: T | null
  handleSearchChange: (q: string) => void
  handleRowClick: (item: T) => void
  handleRowDblClick: (item: T) => void
  handleConfirm: () => void
}

/**
 * Encapsulates the state and event-handling common to all ERP lookup modals:
 * debounced search, auto-load on mount, click-to-select, double-click-to-confirm.
 *
 * @example
 * const lookup = useLookupModal({
 *   fetcher: (q) => prApi.getCostCentreLookup(divCode, q || undefined),
 *   keyOf: (cc) => cc.ccCode,
 *   onSelect,
 * })
 */
export function useLookupModal<T>({
  fetcher,
  keyOf,
  onSelect,
  autoLoad = true,
  debounceMs = 300,
}: UseLookupModalOptions<T>): UseLookupModalResult<T> {
  const [items,    setItems]    = useState<T[]>([])
  const [loading,  setLoading]  = useState(false)
  const [search,   setSearch]   = useState('')
  const [selected, setSelected] = useState<T | null>(null)

  // Stable refs so callbacks never stale-close over props
  const fetcherRef  = useRef(fetcher)
  fetcherRef.current = fetcher
  const onSelectRef = useRef(onSelect)
  onSelectRef.current = onSelect

  const timerRef = useRef<ReturnType<typeof setTimeout>>(undefined)

  const load = useCallback(async (q: string) => {
    setLoading(true)
    try {
      const result = await fetcherRef.current(q)
      setItems(result)
    } catch { /* swallow — modal shows empty state */ }
    finally { setLoading(false) }
  }, [])

  useEffect(() => {
    if (autoLoad) void load('')
  // load is stable (useCallback with no deps); autoLoad is a static option
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handleSearchChange = (q: string) => {
    setSearch(q)
    clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => void load(q), debounceMs)
  }

  const handleRowClick = (item: T) =>
    setSelected(prev => (prev && keyOf(prev) === keyOf(item) ? null : item))

  const handleRowDblClick = (item: T) => {
    onSelectRef.current(item)
    setSelected(null)
  }

  const handleConfirm = () => {
    if (!selected) return
    onSelectRef.current(selected)
    setSelected(null)
  }

  return { items, loading, search, selected, handleSearchChange, handleRowClick, handleRowDblClick, handleConfirm }
}
