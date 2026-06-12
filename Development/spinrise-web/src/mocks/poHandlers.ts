import { http, HttpResponse } from 'msw'
import type {
  PoHeader, PoLine, EligiblePrLine, AddPoRequest, SavePoLineRequest,
  DeletePoRequest, GstRoute,
} from '@/features/po/types'

// ════════════════════════════════════════════════════════════════════════════
//  PR to PO Transfer — RUNTIME MOCK LAYER (browser / demo / UAT)
//  ----------------------------------------------------------------------------
//  Self-contained, stateful mock for the PO module so the screen works end-to-end
//  with NO backend. The API layer (poTransferApi) and every contract are
//  UNCHANGED — only these handler implementations return mock data. To go live,
//  flip VITE_ENABLE_MOCKS=false (or delete this mock layer); the UI/hooks keep
//  calling the same endpoints.
//
//  ⚠ Q1 (BASE): assumes '/api/v1/po'. If the ruling is M02 (ksp_RMI_PO_*/JAT),
//    change the BASE here and the poTransferApi BASE const together.
// ════════════════════════════════════════════════════════════════════════════

const BASE = '/api/v1/po'
const ok = <T,>(data: T, message = '') => HttpResponse.json({ success: true, message, data })
const round2 = (n: number) => Math.round(n * 100) / 100

// ── Demo configuration ───────────────────────────────────────────────────────
const BUDGET_CAP = 500_000          // order value above this → budget block (BR-16)
let nextPoNo = 123                  // CD-03: server-allocated, incrementing (123, 124…)
const createdPos = new Map<number, PoHeader>()
const GRN_PO_NOS = new Set<number>([138])   // seeded PO with a GRN → delete 409 (BR-03)

// ── Source mock data ─────────────────────────────────────────────────────────
const ELIGIBLE_PR: EligiblePrLine[] = [
  { id: 'PR-0053|1|SF-450', prNo: 53, prDate: '01-Jun-26', prSno: 1, itemCode: 'SF-450', itemName: 'Separator Felt 450mm', uom: 'MTR', balanceQty: 150, department: 'Spinning', subCostCentre: 'Ring Frame', remarks: '', hsnCode: '5911', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar' },
  { id: 'PR-0053|2|NW-12',  prNo: 53, prDate: '01-Jun-26', prSno: 2, itemCode: 'NW-12',  itemName: 'Nylon Webbing 12mm',  uom: 'MTR', balanceQty: 300, department: 'Spinning', subCostCentre: 'Ring Frame', remarks: '20mm also OK', hsnCode: '5806', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar' },
  { id: 'PR-0054|1|RB-6206', prNo: 54, prDate: '03-Jun-26', prSno: 1, itemCode: 'RB-6206', itemName: 'Ball Bearing 6206 ZZ', uom: 'NOS', balanceQty: 24, department: 'Maintenance', subCostCentre: 'Mechanical', remarks: '', hsnCode: '', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0031', requesterName: 'Ravi S.' },
  { id: 'PR-0055|1|BO-22',  prNo: 55, prDate: '05-Jun-26', prSno: 1, itemCode: 'BO-22',  itemName: 'Bobbin (22mm Bore)', uom: 'NOS', balanceQty: 500, department: 'Spinning', subCostCentre: 'Winding', remarks: 'Plastic preferred', hsnCode: '8448', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0019', requesterName: 'Kumar T.' },
  { id: 'PR-0056|1|TC-304', prNo: 56, prDate: '07-Jun-26', prSno: 1, itemCode: 'TC-304', itemName: 'Tin Can 304mm', uom: 'NOS', balanceQty: 200, department: 'Spinning', subCostCentre: 'Winding', remarks: '', hsnCode: '7310', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0019', requesterName: 'Kumar T.' },
  { id: 'PR-0056|2|TC-406', prNo: 56, prDate: '07-Jun-26', prSno: 2, itemCode: 'TC-406', itemName: 'Tin Can 406mm', uom: 'NOS', balanceQty: 100, department: 'Spinning', subCostCentre: 'Winding', remarks: '', hsnCode: '7310', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0019', requesterName: 'Kumar T.' },
]
const PR_BY_ITEM = new Map(ELIGIBLE_PR.map((p) => [p.itemCode, p]))

// ── Builders ─────────────────────────────────────────────────────────────────
function buildLine(req: SavePoLineRequest, lineNo: number): PoLine {
  const src = PR_BY_ITEM.get(req.itemCode)
  const value = round2(req.rate * req.qty)
  const isLocal = (req.route as GstRoute) !== 'IGST'
  const cgstAmt = isLocal ? round2((value * req.cgstPer) / 100) : 0
  const sgstAmt = isLocal ? round2((value * req.sgstPer) / 100) : 0
  const igstAmt = isLocal ? 0 : round2((value * req.igstPer) / 100)
  const tcsAmt  = round2((value * req.tcsPer) / 100)
  return {
    lineNo, prSno: req.prSno,
    itemCode: req.itemCode, itemName: src?.itemName ?? req.itemCode, uom: src?.uom ?? 'NOS',
    prNo: src?.prNo ?? 0, prDate: src?.prDate ?? '',
    rate: req.rate, qty: req.qty, balanceQty: src?.balanceQty ?? req.qty, value,
    taxCode: req.taxCode, taxPer: isLocal ? req.cgstPer + req.sgstPer : req.igstPer,
    taxAmt: round2(cgstAmt + sgstAmt + igstAmt), hsnCode: req.hsnCode,
    cgstPer: req.cgstPer, cgstAmt, sgstPer: req.sgstPer, sgstAmt, igstPer: req.igstPer, igstAmt,
    tcsPer: req.tcsPer, tcsAmt, cgstCode: req.cgstCode, sgstCode: req.sgstCode, igstCode: req.igstCode,
    requesterId: src?.requesterId ?? '', requesterName: src?.requesterName ?? '',
    route: (req.route as GstRoute) ?? 'LOCAL', deleteReason: '',
  }
}

function buildSavedPo(req: AddPoRequest, poNo: number): PoHeader {
  const lines = req.lines.map((l, i) => buildLine(l, i + 1))
  const orderValue = round2(lines.reduce((s, l) => s + l.value, 0))
  const delivery = req.lines.map((l, i) => ({
    lineNo: i + 1, itemCode: l.itemCode, itemName: PR_BY_ITEM.get(l.itemCode)?.itemName ?? l.itemCode,
    uom: PR_BY_ITEM.get(l.itemCode)?.uom ?? 'NOS', prNo: PR_BY_ITEM.get(l.itemCode)?.prNo ?? 0,
    poQty: l.qty,
    slots: l.slots.length ? l.slots : [{ slotNo: 1, shDate: null, qty: l.qty, remarks: '' }],
  }))
  return {
    ...(req.header as Omit<PoHeader, 'divCode' | 'poNo' | 'lines' | 'delivery'>),
    divCode: 'S', poNo, lines, orderValue,
    approvalStatus: 'Pending L1', printStatus: 'Not Printed', firstLevelApp: 'Y', conflg: 'N',
    createdBy: 'Demo User', createdDt: new Date().toISOString(), userId: '0012',
    delivery,
  }
}

// Seeded "existing" PO (populates the screen on first load; flagged GRN → 409 demo).
function seededPo(): PoHeader {
  return buildSavedPo({
    poDate: '2026-06-09',
    header: {
      poDate: '2026-06-09', orderType: 'STORE', orderTypeDesc: 'Store Purchase',
      supplier: 'SUP-0042', supplierName: 'Coimbatore Spinners Supply Co.',
      gstin: '33AABCS1429B1Z5', gstState: '33 — Tamil Nadu', inspect: 'YES', roundOff: 0, orderValue: 0,
      formType: '03', refNo: '', refDate: null, currency: 'INR', currRate: 1, remarks: '',
      cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, discPer: 0, cessPer: 0, aedPer: 0,
      freightAmt: 0, packPer: 0, insurPer: 0, surchargePer: 0, addTaxPer: 0, fileNo: '', fcaFob: 0,
      freightType: 'PAID', discApp: 'BEFORE', packApp: 'BEFORE', cessApp: 'BEFORE',
      payMode: 'DIRECT', directInstr: '', bankCode: '', paymentTerms: '', advPer: 0, advAmt: 0,
      modeOfPayment: 'NEFT', payRef: '', payRefDate: null, chequeNo: '', chequeDate: null,
      carrier: '02', creditDays: 30, deliveryDate: null, deliveryLocation: 'Coimbatore Stores', billingAddress: 'Coimbatore HO',
      specialInstr: '', despatch: '', purpose: '', otherLevies: '', pricingTerms: '',
      packForwarding: '', insurance: '', freight: '',
      reminder: '', status: 'OPEN', cancelled: false, cancelDate: null, cancelReason: '',
      approved: 'NO', approvedBy: '',
      amdOrderNo: null, amdDate: null, amdRefNo: null, amdRefDate: null,
      approvalStatus: 'Pending L1', printStatus: 'Not Printed', firstLevelApp: 'Y', conflg: 'N',
      createdBy: 'Suresh Kumar', createdDt: '2026-06-09T10:42:00', userId: '0012',
    },
    lines: [
      { prSno: 1, itemCode: 'SF-450', rate: 0.85, qty: 150, taxCode: 'GST18', hsnCode: '5911', cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, cgstCode: 'CG09', sgstCode: 'SG09', igstCode: '', route: 'LOCAL', slots: [{ slotNo: 1, shDate: '2026-06-20', qty: 100, remarks: 'First batch' }, { slotNo: 2, shDate: '2026-06-30', qty: 50, remarks: 'Balance' }] },
      { prSno: 1, itemCode: 'BO-22', rate: 12, qty: 500, taxCode: 'GST18', hsnCode: '8448', cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, cgstCode: 'CG09', sgstCode: 'SG09', igstCode: '', route: 'LOCAL', slots: [{ slotNo: 1, shDate: '2026-06-25', qty: 500, remarks: 'Full qty' }] },
    ],
  }, 138)
}

export const poHandlers = [
  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/parameters`, () =>
    ok({ poFirstLevelApp: 'N', poPrintApp: 'Y', poConf: 'N', budGrp: 'Y', budgetQty: 'Y', budgetControl: 'Y', currCode: 'INR', backDate: 'N', pdfExportFlag: 'Y' })),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/pre-add-checks`, () =>
    ok({ approvedPrLinesExist: true, docParaExists: true, backDateFlag: 'N', maxPoDate: null })),

  // TODO: Replace with actual backend API when available  (deny-by-default, D-12)
  http.get(`${BASE}/permissions`, () => ok({ canAdd: true, canDelete: true, canPrint: true })),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/order-types`, () => ok([{ poGrp: 'STORE', typName: 'Store Purchase' }, { poGrp: 'HO', typName: 'Head Office' }, { poGrp: 'CAP', typName: 'Capital' }])),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/carriers`, () => ok([{ carCode: '01', carName: 'LORRY' }, { carCode: '02', carName: 'COURIER' }, { carCode: '03', carName: 'RAIL' }])),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/form-types`, () => ok([{ formCode: '03', formName: 'NONE' }, { formCode: '01', formName: 'C-FORM' }])),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/suppliers`, ({ request }) => {
    const q = (new URL(request.url).searchParams.get('search') ?? '').toLowerCase()
    const all = [
      { slCode: 'SUP-0042', slName: 'Coimbatore Spinners Supply Co.', gstinNo: '33AABCS1429B1Z5', gstStateCode: '33', gstStateName: '33 — Tamil Nadu' },
      { slCode: 'SUP-0067', slName: 'Tirupur Textile Traders', gstinNo: '33AAGCT2201C1Z9', gstStateCode: '33', gstStateName: '33 — Tamil Nadu' },
      { slCode: 'SUP-IGST', slName: 'Maharashtra Engineering Works', gstinNo: '27AABCM0000A1Z0', gstStateCode: '27', gstStateName: '27 — Maharashtra' },
    ]
    return ok(q ? all.filter((s) => s.slCode.toLowerCase().includes(q) || s.slName.toLowerCase().includes(q)) : all)
  }),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/banks`, () => ok([{ bankCode: 'HDFC', bankName: 'HDFC Bank' }, { bankCode: 'SBI', bankName: 'State Bank of India' }])),

  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/gst-tax-codes`, () => ok([
    { taxCode: 'GST18', taxDesc: 'GST 18%', cgstPer: 9, sgstPer: 9, igstPer: 18, taxStatus: 'Y' },
    { taxCode: 'GST12', taxDesc: 'GST 12%', cgstPer: 6, sgstPer: 6, igstPer: 12, taxStatus: 'Y' },
    { taxCode: 'GST05', taxDesc: 'GST 5%',  cgstPer: 2.5, sgstPer: 2.5, igstPer: 5, taxStatus: 'Y' },
  ])),

  // GST routing — SERVER-SIDE (Q4). UI displays; never computes.
  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/gst-routing`, ({ request }) => {
    const supplier = new URL(request.url).searchParams.get('supplier') ?? ''
    const igst = supplier.includes('IGST')         // Maharashtra supplier ⇒ inter-state
    return ok({ route: igst ? 'IGST' : 'LOCAL', divStateCode: '33', supStateCode: igst ? '27' : '33' })
  }),

  // PR Picker — server pre-filters by BR-02 (DirectApp='Y', Fclosed<>'Y').
  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/eligible-pr-lines`, ({ request }) => {
    const q = (new URL(request.url).searchParams.get('search') ?? '').toLowerCase()
    return ok(q
      ? ELIGIBLE_PR.filter((p) => `${p.prNo} ${p.itemCode} ${p.itemName}`.toLowerCase().includes(q))
      : ELIGIBLE_PR)
  }),

  // Latest PO — seeds the screen with a populated VIEW on load.
  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/last`, () => {
    const latest = [...createdPos.values()].at(-1)
    return ok(latest ?? seededPo())
  }),

  // ── CRUD ─────────────────────────────────────────────────────────────────
  // Server allocates the PO number atomically AFTER validation (CD-03). Budget
  // control (BR-16) blocks when order value exceeds the cap.
  // TODO: Replace with actual backend API when available
  http.post(`${BASE}`, async ({ request }) => {
    const body = (await request.json()) as AddPoRequest
    const orderValue = (body.lines ?? []).reduce((s, l) => s + l.rate * l.qty, 0)
    if (orderValue > BUDGET_CAP) {
      return HttpResponse.json(
        { success: false, message: `Budget Amount Exceeds!!! Balance Budget Amount is ${BUDGET_CAP.toLocaleString('en-IN')}.00` },
        { status: 400 },
      )
    }
    const poNo = nextPoNo++
    createdPos.set(poNo, buildSavedPo(body, poNo))
    return ok({ poNo, poDate: body.poDate }, `Purchase Order created. Number: ${poNo}`)
  }),

  // GRN guard (BR-03) — seeded PO 138 "has a GRN" ⇒ 409; created POs delete OK.
  // TODO: Replace with actual backend API when available
  http.delete(`${BASE}`, async ({ request }) => {
    const body = (await request.json().catch(() => null)) as DeletePoRequest | null
    const poNo = body?.poNo ?? 0
    if (GRN_PO_NOS.has(poNo)) {
      return HttpResponse.json(
        { success: false, message: 'SORRY - ALREADY GRN IS RAISED FOR THIS PURCHASE ORDER' },
        { status: 409 },
      )
    }
    createdPos.delete(poNo)
    return ok(undefined, 'PO deleted. PR quantities reversed.')
  }),

  // Header-tax propagation — SERVER-SIDE (Q5 / D-05). Returns the updated PO.
  // TODO: Replace with actual backend API when available
  http.patch(`${BASE}/:poNo/lines/apply-header-tax`, ({ params }) => {
    const poNo = Number(params.poNo)
    return ok(createdPos.get(poNo) ?? seededPo())
  }),

  // Print — approval-gated QuestPDF (backend). Returns a minimal valid PDF blob.
  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/:poNo/print`, () => {
    const pdf = '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF'
    return new HttpResponse(new TextEncoder().encode(pdf), { headers: { 'Content-Type': 'application/pdf' } })
  }),

  // Single PO by number (stored ⇒ just-created; else the seeded demo).
  // TODO: Replace with actual backend API when available
  http.get(`${BASE}/:poNo`, ({ params }) => {
    const poNo = Number(params.poNo)
    return ok(createdPos.get(poNo) ?? { ...seededPo(), poNo })
  }),
]
