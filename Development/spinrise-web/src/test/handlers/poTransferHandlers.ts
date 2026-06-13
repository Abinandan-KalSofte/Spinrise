import { http, HttpResponse } from 'msw'

// ── PR to PO Transfer — MSW handlers ─────────────────────────────────────────
//
// ⚠ PROVISIONAL CONTRACT (Gate-0 Q7): no backend REST spec exists yet. Every
//   shape below is a placeholder and MUST be reconciled with the real API once
//   published. Backend-reconciliation notes are tagged at each boundary.
//
// ⚠ Q1 (BASE): assumes `ksp_PO_*` on the main DB ⇒ '/api/v1/po'. If the ruling
//   is M02 (ksp_RMI_PO_*/JAT) this base segment changes in ONE place here and in
//   poTransferApi's BASE const.

const BASE = '/api/v1/po'
const ok = <T,>(data: T, message = '') => HttpResponse.json({ success: true, message, data })

// Reusable provisional PO header (server shape — RECONCILE).
const makePo = (poNo: number, poDate = '2026-06-09') => ({
  divCode: 'S', poNo, poDate,
  orderType: 'STORE', orderTypeDesc: 'Store Purchase',
  supplier: 'SUP-0042', supplierName: 'Coimbatore Spinners Supply Co.',
  gstin: '33AABCS1429B1Z5', gstState: '33 — Tamil Nadu',
  inspect: 'YES', roundOff: 0, orderValue: 0,
  formType: '', refNo: '', refDate: null, currency: 'INR', currRate: 1, remarks: '',
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
  lines: [], delivery: [],
})

export const poTransferHandlers = [
  // ── Screen init (RECONCILE: param/flag names) ──────────────────────────────
  http.get(`${BASE}/parameters`, () =>
    ok({
      poFirstLevelApp: 'N', poPrintApp: 'Y', poConf: 'N',
      budGrp: 'Y', budgetQty: 'Y', budgetControl: 'Y',
      currCode: 'INR', backDate: 'N', pdfExportFlag: 'Y',
    })),

  http.get(`${BASE}/pre-add-checks`, () =>
    ok({ approvedPrLinesExist: true, docParaExists: true, backDateFlag: 'N', maxPoDate: null })),

  // ── Lookups (RECONCILE: every column name) ─────────────────────────────────
  http.get(`${BASE}/order-types`, () =>
    ok([{ poGrp: 'STORE', typName: 'Store Purchase' }, { poGrp: 'HO', typName: 'Head Office' }])),

  http.get(`${BASE}/carriers`, () =>
    ok([{ carCode: '02', carName: 'COURIER' }])),

  http.get(`${BASE}/form-types`, () =>
    ok([{ formCode: '03', formName: 'NONE' }])),

  http.get(`${BASE}/suppliers`, () =>
    ok([
      { slCode: 'SUP-0042', slName: 'Coimbatore Spinners Supply Co.', gstinNo: '33AABCS1429B1Z5', gstStateCode: '33', gstStateName: '33 — Tamil Nadu' },
      { slCode: 'SUP-IGST', slName: 'Maharashtra Traders', gstinNo: '27AABCM0000A1Z0', gstStateCode: '27', gstStateName: '27 — Maharashtra' },
    ])),

  http.get(`${BASE}/banks`, () =>
    ok([{ bankCode: 'HDFC', bankName: 'HDFC Bank' }])),

  http.get(`${BASE}/gst-tax-codes`, () =>
    ok([{ taxCode: 'GST18', taxDesc: 'GST 18%', cgstPer: 9, sgstPer: 9, igstPer: 18, taxStatus: 'Y' }])),

  // ── GST routing — SERVER-SIDE (Q4). UI displays this; never computes it.
  //    RECONCILE: confirm inline-on-supplier vs dedicated endpoint.
  http.get(`${BASE}/gst-routing`, ({ request }) => {
    const supplier = new URL(request.url).searchParams.get('supplier') ?? ''
    const igst = supplier.includes('IGST')
    return ok({ route: igst ? 'IGST' : 'LOCAL', divStateCode: '33', supStateCode: igst ? '27' : '33' })
  }),

  // ── PR Picker — server pre-filters by BR-02 (DirectApp='Y', Fclosed<>'Y') ──
  http.get(`${BASE}/eligible-pr-lines`, () =>
    ok([
      { id: 'PR-0053|1|SF-450', prNo: 53, prDate: '01-Jun-26', prSno: 1, itemCode: 'SF-450', itemName: 'Separator Felt 450mm', uom: 'MTR', balanceQty: 150, department: 'Spinning', subCostCentre: 'Ring Frame', remarks: '', hsnCode: '5911', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar' },
      { id: 'PR-0054|1|RB-6206', prNo: 54, prDate: '03-Jun-26', prSno: 1, itemCode: 'RB-6206', itemName: 'Ball Bearing 6206 ZZ', uom: 'NOS', balanceQty: 24, department: 'Maintenance', subCostCentre: 'Mechanical', remarks: '', hsnCode: '', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar' },
    ])),

  // ── PO data ────────────────────────────────────────────────────────────────
  http.get(`${BASE}/last`, () => ok(null)),

  // Find / record-navigation list (PoSummary[]). RECONCILE: paging shape.
  http.get(BASE, () =>
    ok([
      { divCode: 'S', poNo: 137, poDate: '2026-06-05', orderType: 'STORE', supplier: 'SUP-0042', supplierName: 'Coimbatore Spinners Supply Co.', orderValue: 125000, approvalStatus: 'APPROVED', totalLines: 3 },
      { divCode: 'S', poNo: 138, poDate: '2026-06-07', orderType: 'STORE', supplier: 'SUP-IGST', supplierName: 'Maharashtra Traders', orderValue: 48250, approvalStatus: 'PENDING L1', totalLines: 1 },
    ])),

  http.get(`${BASE}/:poNo`, ({ params }) => ok(makePo(Number(params.poNo)))),

  // ── CRUD ───────────────────────────────────────────────────────────────────
  // Server allocates the PO number atomically AFTER validation (CD-03). The UI
  // never displays a guessed number. RECONCILE: response shape.
  http.post(`${BASE}`, async ({ request }) => {
    const body = (await request.json()) as { poDate?: string }
    return ok({ poNo: 139, poDate: body?.poDate ?? '2026-06-09' }, 'Purchase Order created.')
  }),

  // GRN guard (BR-03) is server-side — default success; tests override for 409.
  http.delete(`${BASE}`, () => ok(undefined, 'PO deleted. PR quantities reversed.')),

  // Header-tax propagation — SERVER-SIDE (Q5 / D-05). RECONCILE: returns updated PO.
  http.patch(`${BASE}/:poNo/lines/apply-header-tax`, ({ params }) =>
    ok(makePo(Number(params.poNo)))),

  // Print — approval-gated QuestPDF (backend out of scope). Returns a stub blob.
  http.get(`${BASE}/:poNo/print`, () =>
    HttpResponse.arrayBuffer(new ArrayBuffer(8), { headers: { 'Content-Type': 'application/pdf' } })),
]

export { makePo as makeProvisionalPo }
