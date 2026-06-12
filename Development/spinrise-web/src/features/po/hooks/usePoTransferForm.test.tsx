import { render, act, waitFor } from '@testing-library/react'
import { App, Form } from 'antd'
import { http, HttpResponse } from 'msw'
import dayjs from 'dayjs'
import { beforeEach, describe, expect, it } from 'vitest'
import { server } from '@/test/mocks/server'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { AuthUser } from '@/features/auth/types'
import { usePoTransferStore } from '../store/usePoTransferStore'
import { usePoTransferForm } from './usePoTransferForm'
import type { EligiblePrLine, SupplierOption, PoHeader, PoLine } from '../types'

const BASE = '/api/v1/po'

// Latest hook value (reassigned every render).
let hook: ReturnType<typeof usePoTransferForm>

function Harness() {
  // Test harness: capture the latest hook value for assertions. Intentional
  // render-time write to a module variable (standard renderHook-style pattern).
  // eslint-disable-next-line react-hooks/globals
  hook = usePoTransferForm()
  // A real <Form> so headerForm.validateFields() resolves against registered fields.
  return (
    <Form form={hook.headerForm}>
      <Form.Item name="orderType" rules={[{ required: true }]}><input /></Form.Item>
      <Form.Item name="supplier"  rules={[{ required: true }]}><input /></Form.Item>
      <Form.Item name="currency"  rules={[{ required: true }]}><input /></Form.Item>
      <Form.Item name="carrier"   rules={[{ required: true }]}><input /></Form.Item>
      <Form.Item name="poDate"><input /></Form.Item>
      <Form.Item name="payMode"><input /></Form.Item>
    </Form>
  )
}

const mount = () => render(<App><Harness /></App>)

const SF_LINE: EligiblePrLine = {
  id: 'PR-0053|1|SF-450', prNo: 53, prDate: '01-Jun-26', prSno: 1,
  itemCode: 'SF-450', itemName: 'Separator Felt 450mm', uom: 'MTR', balanceQty: 150,
  department: 'Spinning', subCostCentre: 'Ring Frame', remarks: '', hsnCode: '5911',
  cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar',
}

const SUP_IGST: SupplierOption = {
  slCode: 'SUP-IGST', slName: 'Maharashtra Traders', gstinNo: '27AABCM0000A1Z0',
  gstStateCode: '27', gstStateName: '27 — Maharashtra',
}

function makeSavedPo(lines: Partial<PoLine>[]): PoHeader {
  return {
    divCode: 'S', poNo: 138, poDate: '2026-06-09', orderType: 'STORE', orderTypeDesc: '',
    supplier: 'SUP-0042', supplierName: '', gstin: '', gstState: '', inspect: 'YES',
    roundOff: 0, orderValue: 0, formType: '', refNo: '', refDate: null, currency: 'INR', currRate: 1, remarks: '',
    cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, discPer: 0, cessPer: 0, aedPer: 0,
    freightAmt: 0, packPer: 0, insurPer: 0, surchargePer: 0, addTaxPer: 0, fileNo: '', fcaFob: 0,
    freightType: 'PAID', discApp: 'BEFORE', packApp: 'BEFORE', cessApp: 'BEFORE',
    payMode: 'DIRECT', directInstr: '', bankCode: '', paymentTerms: '', advPer: 0, advAmt: 0,
    modeOfPayment: 'NEFT', payRef: '', payRefDate: null, chequeNo: '', chequeDate: null,
    carrier: '02', creditDays: 0, deliveryDate: null, deliveryLocation: '', billingAddress: '',
    specialInstr: '', despatch: '', purpose: '', otherLevies: '', pricingTerms: '',
    packForwarding: '', insurance: '', freight: '',
    reminder: '', status: '', cancelled: false, cancelDate: null, cancelReason: '',
    approved: 'NO', approvedBy: '',
    amdOrderNo: null, amdDate: null, amdRefNo: null, amdRefDate: null,
    approvalStatus: 'Pending L1', printStatus: 'Not Printed', firstLevelApp: 'Y', conflg: 'N',
    createdBy: 'Suresh Kumar', createdDt: '2026-06-09T10:42:00', userId: '0012',
    lines: lines.map((l, i) => ({
      lineNo: i + 1, prSno: i + 1, itemCode: 'X', itemName: 'X', uom: 'NOS', prNo: 1, prDate: '',
      rate: 1, qty: 1, balanceQty: 1, value: 1, taxCode: 'GST18', taxPer: 18, taxAmt: 0,
      hsnCode: '5911', cgstPer: 9, cgstAmt: 0, sgstPer: 9, sgstAmt: 0, igstPer: 0, igstAmt: 0,
      tcsPer: 0, tcsAmt: 0, cgstCode: '', sgstCode: '', igstCode: '',
      requesterId: '', requesterName: '', route: 'LOCAL', deleteReason: '', ...l,
    })) as PoLine[],
    delivery: [],
  }
}

beforeEach(() => {
  useAuthStore.setState({
    user: { divCode: 'S', userName: 'Tester' } as AuthUser,
    processingDate: '2026-06-12', isAuthenticated: true,
  })
  usePoTransferStore.setState({
    mode: 'VIEW', currentPo: null, draftLines: [], deliveryLines: [],
    gstLineNo: null, selectedLineNo: null, loading: false, saving: false,
  })
})

async function enterAddWithLine(rate = 10) {
  await act(async () => { await hook.enterAddMode() })
  act(() => { hook.addPrLines([SF_LINE]) })
  const lineNo = hook.draftLines[0].lineNo
  act(() => { hook.updateLineRateQty(lineNo, { rate }) })
  return lineNo
}

// ── Lookup loading + retry ─────────────────────────────────────────────────
describe('lookups', () => {
  it('loads reference data on mount', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    expect(hook.orderTypes.length).toBeGreaterThan(0)
    expect(hook.carriers.length).toBeGreaterThan(0)
  })

  it('surfaces an error then recovers on retry', async () => {
    server.use(http.get(`${BASE}/parameters`, () => HttpResponse.json({ success: false, message: 'boom' }, { status: 500 })))
    mount()
    await waitFor(() => expect(hook.lookupsError).toBeTruthy())
    expect(hook.lookupsLoaded).toBe(false)

    server.resetHandlers()   // restore default success handlers
    await act(async () => { await hook.loadLookups() })
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    expect(hook.lookupsError).toBeNull()
  })
})

// ── Permission-gated print (server-driven, deny-by-default) ────────────────
describe('permissions', () => {
  it('reflects server print permission (gates the Print toolbar button)', async () => {
    server.use(http.get(`${BASE}/permissions`, () =>
      HttpResponse.json({ success: true, message: '', data: { canAdd: true, canDelete: true, canPrint: false } })))
    mount()
    await waitFor(() => expect(hook.permissions.canPrint).toBe(false))
    expect(hook.permissions.canAdd).toBe(true)
  })
})

// ── PR lines + delivery schedule synchronisation ───────────────────────────
describe('lines & delivery sync', () => {
  it('adds PR lines and seeds a matching delivery line', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    await enterAddWithLine()
    expect(hook.draftLines).toHaveLength(1)
    expect(hook.deliveryLines).toHaveLength(1)
    expect(hook.deliveryLines[0].poQty).toBe(150)        // defaults to PR balance
  })

  it('recomputes line value and syncs delivery poQty on qty change', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    const lineNo = await enterAddWithLine(10)
    expect(hook.draftLines[0].value).toBe(1500)          // 10 × 150
    act(() => { hook.updateLineRateQty(lineNo, { qty: 100 }) })
    expect(hook.draftLines[0].value).toBe(1000)
    expect(hook.deliveryLines[0].poQty).toBe(100)        // delivery follows line qty
  })

  it('adds, edits and removes delivery slots (4-slot model)', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    const lineNo = await enterAddWithLine()
    act(() => { hook.addSlot(lineNo) })
    expect(hook.deliveryLines[0].slots).toHaveLength(2)
    act(() => { hook.updateSlot(lineNo, 2, { qty: 50 }) })
    expect(hook.deliveryLines[0].slots[1].qty).toBe(50)
    act(() => { hook.removeSlot(lineNo, 2) })
    expect(hook.deliveryLines[0].slots).toHaveLength(1)
  })
})

// ── GST routing display from server-provided route (Q4) ────────────────────
describe('GST routing (server-driven)', () => {
  it('applies the server route to lines on supplier change', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    await enterAddWithLine()
    expect(hook.draftLines[0].route).toBe('LOCAL')
    await act(async () => { await hook.onSupplierChange(SUP_IGST) })
    expect(hook.gstRoute).toBe('IGST')
    expect(hook.draftLines[0].route).toBe('IGST')         // re-routed from server result
  })
})

// ── Save flow — server-allocated PO number (CD-03) ─────────────────────────
describe('save', () => {
  it('creates a PO with the server-generated number', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    await enterAddWithLine(10)
    act(() => {
      hook.headerForm.setFieldsValue({
        orderType: 'STORE', supplier: 'SUP-0042', currency: 'INR', carrier: '02',
        poDate: dayjs('2026-06-09'), payMode: 'DIRECT',
      })
    })
    await act(async () => { await hook.doSave() })
    await waitFor(() => expect(hook.currentPo?.poNo).toBe(139))   // from server, not guessed
    expect(hook.mode).toBe('VIEW')
  })

  it('surfaces a server budget-validation error (BR-16/17) without completing', async () => {
    server.use(http.post(`${BASE}`, () =>
      HttpResponse.json({ success: false, message: 'Budget Amount Exceeds!!! Balance Budget Amount is 5000.00' }, { status: 400 })))
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    await enterAddWithLine(10)
    act(() => {
      hook.headerForm.setFieldsValue({
        orderType: 'STORE', supplier: 'SUP-0042', currency: 'INR', carrier: '02',
        poDate: dayjs('2026-06-09'), payMode: 'DIRECT',
      })
    })
    await act(async () => { await hook.doSave() })
    expect(hook.currentPo).toBeNull()    // save did not complete
    expect(hook.mode).toBe('ADD')        // stays in ADD for correction
  })

  it('blocks save when a line rate is zero (BR-07)', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    await enterAddWithLine(0)   // rate 0
    act(() => {
      hook.headerForm.setFieldsValue({
        orderType: 'STORE', supplier: 'SUP-0042', currency: 'INR', carrier: '02',
        poDate: dayjs('2026-06-09'), payMode: 'DIRECT',
      })
    })
    await act(async () => { await hook.doSave() })
    expect(hook.currentPo).toBeNull()
    expect(hook.mode).toBe('ADD')
  })
})

// ── Delete flow — BR-04 + BR-03 (GRN 409) ──────────────────────────────────
describe('delete', () => {
  function enterDeleteSeeded() {
    usePoTransferStore.setState({ currentPo: makeSavedPo([{ prSno: 1, itemCode: 'SF-450' }]) })
    act(() => { hook.enterDeleteMode() })
  }

  it('blocks confirm when any line delete reason is blank (BR-04)', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    enterDeleteSeeded()
    let result: boolean | undefined
    await act(async () => { result = await hook.handleDeleteConfirm('') })
    expect(result).toBe(false)
  })

  it('returns 409 GRN-guard failure as a handled error (BR-03)', async () => {
    server.use(http.delete(`${BASE}`, () =>
      HttpResponse.json({ success: false, message: 'GRN raised' }, { status: 409 })))
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    enterDeleteSeeded()
    act(() => { hook.setDefaultDeleteReason('No longer required') })
    let result: boolean | undefined
    await act(async () => { result = await hook.handleDeleteConfirm('No longer required') })
    expect(result).toBe(false)   // surfaced GRN guard; no crash
  })

  it('deletes successfully when reasons are filled', async () => {
    mount()
    await waitFor(() => expect(hook.lookupsLoaded).toBe(true))
    enterDeleteSeeded()
    act(() => { hook.setDefaultDeleteReason('No longer required') })
    let result: boolean | undefined
    await act(async () => { result = await hook.handleDeleteConfirm('No longer required') })
    expect(result).toBe(true)
  })
})
