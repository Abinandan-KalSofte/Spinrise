import { useEffect } from 'react'

// Resets page-level store state on mount AND on unmount, so a page always
// opens clean regardless of whether the user is arriving fresh or returning
// from another page (Zustand stores are module-scope singletons and
// otherwise outlive route navigation). Pass the store's own reset action —
// call sites choose which reset (full vs. soft) preserves session/config
// data appropriately; this hook only owns the mount/unmount timing.
export function usePageReset(reset: () => void) {
  useEffect(() => {
    reset()
    return () => reset()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- fire once per mount/unmount by design, not on every reset-identity change
  }, [])
}
