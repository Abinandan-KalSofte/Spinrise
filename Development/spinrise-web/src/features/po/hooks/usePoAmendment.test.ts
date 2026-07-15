import { describe, it, expect } from 'vitest'
import { isLineChanged } from './usePoAmendment'
import type { PoLine } from '../types'

// FN-PO-Amendment v1.2 §3.6 — Amendment Reason is mandatory on ANY changed line
// (CEO-confirmed 9-Jul: not the VB6 landed-cost-only trigger). Everything about
// that rule hinges on what counts as "changed", so this is the piece worth
// pinning down: a false negative silently lets an unjustified amendment through,
// a false positive nags the user for a reason on a line they never touched.

const line = (over: Partial<PoLine> = {}): PoLine => ({
  lineNo: 1, prSno: 1, itemCode: '1334001', itemName: 'HYDRAULIC OIL', uom: 'LTR',
  prNo: 900, prDate: '2026-07-01',
  rate: 250.5, qty: 10, balanceQty: 100, value: 2505,
  taxCode: 'GST18', taxPer: 18, taxAmt: 450.9,
  hsnCode: '2710',
  cgstPer: 9, cgstAmt: 225.45, sgstPer: 9, sgstAmt: 225.45, igstPer: 0, igstAmt: 0,
  tcsPer: 0, tcsAmt: 0,
  cgstCode: 'C9', sgstCode: 'S9', igstCode: '',
  discPer: 0, discAmt: 0, packingPer: 0, packingAmt: 0,
  freightPer: 0, freightAmt: 0, insurancePer: 0, insuranceAmt: 0,
  otherCharges: 0, fcaFob: 0,
  addTaxCode: '', addTaxPer: 0, addTaxAmt: 0,
  freightPos: 'BEFORE', insuranceDuty: 'BEFORE', discApp: 'BEFORE', packApp: 'BEFORE',
  taxableValue: 2505, netAmount: 2955.9, taxSaved: true,
  requesterId: 'U1', requesterName: 'Tester',
  route: 'LOCAL', deleteReason: '', subCostCode: 0, depCode: 'ENG',
  amendReason: '', amendChanged: false,
  receivedQty: 0, cancelledQty: 0,
  ...over,
})

describe('isLineChanged — FN §3.6 changed-line detection', () => {
  it('reports an untouched line as unchanged', () => {
    const original = line()
    expect(isLineChanged(line(), original)).toBe(false)
  })

  it.each([
    ['quantity',      { qty: 12 }],
    ['rate',          { rate: 260 }],
    ['discount %',    { discPer: 5 }],
    ['discount amt',  { discAmt: 100 }],
    ['packing %',     { packingPer: 2 }],
    ['freight amt',   { freightAmt: 50 }],
    ['insurance %',   { insurancePer: 1 }],
    ['other charges', { otherCharges: 25 }],
    ['tax code',      { taxCode: 'GST12' }],
    ['HSN code',      { hsnCode: '2711' }],
    ['CGST code',     { cgstCode: 'C6' }],
    ['TCS %',         { tcsPer: 0.1 }],
    ['discount applicability', { discApp: 'AFTER' as const }],
    ['freight position',       { freightPos: 'AFTER' as const }],
  ])('flags a line whose %s changed', (_label, patch) => {
    const original = line()
    expect(isLineChanged(line(patch), original)).toBe(true)
  })

  it('ignores derived money — recalcLine rewrites these on every keystroke', () => {
    // value / netAmount / *Amt tax fields are recomputed client-side AND again
    // server-side (FN §4.B). Diffing them would flag lines as "changed" purely
    // from rounding, demanding an Amendment Reason for an edit nobody made.
    const original = line()
    const derivedOnly = line({
      value:        2505.01,
      netAmount:    2955.91,
      taxAmt:       450.91,
      cgstAmt:      225.46,
      sgstAmt:      225.46,
      taxableValue: 2505.01,
    })
    expect(isLineChanged(derivedOnly, original)).toBe(false)
  })

  it('ignores sub-precision float noise', () => {
    // Rate is stored to 4dp and qty to 3dp; a drift below that is representation
    // noise, not a user edit.
    const original = line()
    expect(isLineChanged(line({ rate: 250.5 + 1e-9 }), original)).toBe(false)
  })

  it('treats a real edit at stored precision as changed', () => {
    const original = line()
    expect(isLineChanged(line({ rate: 250.5001 }), original)).toBe(true)
  })

  it('does NOT treat the amendment reason itself as a change', () => {
    // Typing a reason must not be what makes a line "changed" — otherwise every
    // line would demand a reason the moment one was entered, and an untouched
    // line could be dragged into the amendment by a stray keystroke.
    const original = line()
    expect(isLineChanged(line({ amendReason: 'Rate revised' }), original)).toBe(false)
  })

  it('treats a line with no pristine twin as changed', () => {
    expect(isLineChanged(line(), undefined)).toBe(true)
  })
})
