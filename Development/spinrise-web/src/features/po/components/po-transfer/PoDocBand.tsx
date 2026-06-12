import { formatPoNo } from '../../types'
import type { ScreenMode } from '../../types'
import { PRDocBand } from '@/features/pr/components/pr-form/PRToolbar'

// ── Document band (HTML .doc-band) ───────────────────────────────────────────
// Breadcrumb + PO No / FY / Record. In ADD the PO No reads "NEW" (server
// allocates the real number on save — CD-03 / UX-04: never a guessed value).

interface PoDocBandProps {
  mode:      ScreenMode
  poNo:      number | null
  fy:        string
  recordPos?: string        // e.g. "138 / 138"
}

export function PoDocBand({ mode, poNo }: PoDocBandProps) {
  const poLabel = mode === 'ADD' ? 'NEW' : formatPoNo(poNo) || 'Auto-generated on save'

  return (
    <PRDocBand
      breadcrumb={[ 'Purchase Order', 'PR to PO Transfer' ]}
      subLabel="PO No."
      subValue={poLabel}
    />
  )
}
