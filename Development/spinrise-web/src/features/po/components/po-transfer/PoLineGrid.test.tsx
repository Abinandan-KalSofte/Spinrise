import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { PoLineGrid } from './PoLineGrid'
import type { PoLine } from '../../types'

const noop = () => {}

function makeLine(over: Partial<PoLine>): PoLine {
  return {
    lineNo: 1, prSno: 1, itemCode: 'IT-1', itemName: 'Item One', uom: 'NOS', prNo: 53, prDate: '01-Jun-26',
    rate: 10, qty: 5, balanceQty: 5, value: 50, taxCode: 'GST18', taxPer: 18, taxAmt: 9,
    hsnCode: '5911', cgstPer: 9, cgstAmt: 0, sgstPer: 9, sgstAmt: 0, igstPer: 0, igstAmt: 0,
    tcsPer: 0, tcsAmt: 0, cgstCode: '', sgstCode: '', igstCode: '',
    requesterId: 'EMP-1', requesterName: 'Req One', route: 'LOCAL', deleteReason: '', ...over,
  }
}

function renderGrid(lines: PoLine[], mode: 'VIEW' | 'ADD' | 'DELETE' = 'VIEW') {
  return render(
    <PoLineGrid
      mode={mode} lines={lines} selectedLineNo={null}
      onSelectLine={noop} onUpdateRateQty={noop} onOpenGst={noop}
      onRemoveLine={noop} onDeleteReasonChange={noop}
    />,
  )
}

describe('PoLineGrid', () => {
  it('renders server-routed amounts as-is — IGST line shows the IGST amount', () => {
    // route comes from the server (Q4); the grid only displays the carried amounts.
    renderGrid([makeLine({ route: 'IGST', igstPer: 18, igstAmt: 123.45, cgstAmt: 0, sgstAmt: 0 })])
    expect(screen.getByText('123.45')).toBeInTheDocument()
  })

  it('renders a LOCAL line CGST amount as-is', () => {
    renderGrid([makeLine({ route: 'LOCAL', cgstAmt: 67.89, igstAmt: 0 })])
    expect(screen.getByText('67.89')).toBeInTheDocument()
  })

  it('flags a missing HSN code (BR-10 warning)', () => {
    renderGrid([makeLine({ hsnCode: '' })])
    expect(screen.getByText('⚠')).toBeInTheDocument()
  })

  it('shows the Delete Reason column only in DELETE mode', () => {
    const { rerender } = renderGrid([makeLine({})], 'VIEW')
    expect(screen.queryByText('Delete Reason')).not.toBeInTheDocument()
    rerender(
      <PoLineGrid
        mode="DELETE" lines={[makeLine({})]} selectedLineNo={null}
        onSelectLine={noop} onUpdateRateQty={noop} onOpenGst={noop}
        onRemoveLine={noop} onDeleteReasonChange={noop}
      />,
    )
    expect(screen.getByText('Delete Reason')).toBeInTheDocument()
  })

  it('renders an empty-state row when there are no lines', () => {
    renderGrid([])
    expect(screen.getByText(/No line items/i)).toBeInTheDocument()
  })
})
