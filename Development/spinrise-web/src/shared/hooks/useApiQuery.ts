import { useEffect, useRef, useState } from 'react'

interface QueryState<T> {
  data:     T | null
  loading:  boolean
  error:    string | null
}

interface UseApiQueryResult<T> extends QueryState<T> {
  /** Re-fetch manually (e.g., after a user action). */
  refetch: () => void
}

/**
 * Declarative data-fetching hook — fetches on mount and whenever `deps` change.
 * Use for read-only queries that should load automatically (dropdowns, lookup data).
 * For user-triggered actions (save, delete) use `useAsync` instead.
 *
 * @example
 * const { data: depts, loading } = useApiQuery(
 *   () => prApi.getDepartments(divCode),
 *   [divCode]
 * )
 */
export function useApiQuery<T>(
  fetcher: () => Promise<T>,
  deps: unknown[] = [],
): UseApiQueryResult<T> {
  const [state, setState] = useState<QueryState<T>>({
    data: null, loading: true, error: null,
  })

  const fetcherRef = useRef(fetcher)
  fetcherRef.current = fetcher

  const abortRef = useRef<AbortController | null>(null)
  const mountedRef = useRef(true)

  const run = () => {
    abortRef.current?.abort()
    abortRef.current = new AbortController()

    setState((s) => ({ ...s, loading: true, error: null }))

    void fetcherRef.current()
      .then((data) => {
        if (mountedRef.current) setState({ data, loading: false, error: null })
      })
      .catch((err: unknown) => {
        if (mountedRef.current) {
          const msg = err instanceof Error ? err.message : 'Failed to load data.'
          setState((s) => ({ ...s, loading: false, error: msg }))
        }
      })
  }

  useEffect(() => {
    mountedRef.current = true
    run()
    return () => {
      mountedRef.current = false
      abortRef.current?.abort()
    }
    // deps are caller-supplied; run is stable (only fetcherRef changes)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)

  useEffect(() => () => { mountedRef.current = false }, [])

  return { ...state, refetch: run }
}
