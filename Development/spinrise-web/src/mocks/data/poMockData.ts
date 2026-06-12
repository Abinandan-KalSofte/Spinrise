import type {
  PoHeader, PoLine, EligiblePrLine, SupplierOption, OrderTypeOption,
  CarrierOption, BankOption, FormTypeOption, GstTaxCodeOption, PoParameters,
  AddPoRequest, SavePoLineRequest, GstRoute,
} from '@/features/po/types'

// ════════════════════════════════════════════════════════════════════════════
//  PR to PO Transfer — MOCK DATASETS (single source of demo data)
//  Edit these arrays to change what the screen shows. Consumed by poHandlers.ts.
//  TODO: Replace with actual backend API when available.
// ════════════════════════════════════════════════════════════════════════════

const round2 = (n: number) => Math.round(n * 100) / 100

// ── Parameters / Settings ────────────────────────────────────────────────────
export const PO_PARAMETERS: PoParameters = {
  poFirstLevelApp: 'N', poPrintApp: 'Y', poConf: 'N',
  budGrp: 'Y', budgetQty: 'Y', budgetControl: 'Y',
  currCode: 'INR', backDate: 'N', pdfExportFlag: 'Y',
}

// ── Suppliers ────────────────────────────────────────────────────────────────
export const SUPPLIERS: SupplierOption[] = [
  { slCode: 'SUP-0042', slName: 'Coimbatore Spinners Supply Co.', gstinNo: '33AABCS1429B1Z5', gstStateCode: '33', gstStateName: '33 — Tamil Nadu' },
  { slCode: 'SUP-0067', slName: 'Tirupur Textile Traders',        gstinNo: '33AAGCT2201C1Z9', gstStateCode: '33', gstStateName: '33 — Tamil Nadu' },
  { slCode: 'SUP-0091', slName: 'Salem Steel & Bearings',         gstinNo: '33AADCS7781E1Z2', gstStateCode: '33', gstStateName: '33 — Tamil Nadu' },
  { slCode: 'SUP-IGST', slName: 'Maharashtra Engineering Works',  gstinNo: '27AABCM0000A1Z0', gstStateCode: '27', gstStateName: '27 — Maharashtra' },
]

// ── Order Types ──────────────────────────────────────────────────────────────
export const ORDER_TYPES: OrderTypeOption[] = [
  { poGrp: 'STORE', typName: 'Store Purchase' },
  { poGrp: 'CAP',   typName: 'Capital Purchase' },
  { poGrp: 'HO',    typName: 'Head Office Purchase' },
  { poGrp: 'IMP',   typName: 'Import Purchase' },
]

// ── Carriers ─────────────────────────────────────────────────────────────────
export const CARRIERS: CarrierOption[] = [
  { carCode: '01', carName: 'LORRY' },
  { carCode: '02', carName: 'COURIER' },
  { carCode: '03', carName: 'RAIL' },
  { carCode: '04', carName: 'HAND DELIVERY' },
]

// ── Banks ────────────────────────────────────────────────────────────────────
export const BANKS: BankOption[] = [
  { bankCode: 'HDFC', bankName: 'HDFC Bank — Coimbatore' },
  { bankCode: 'SBI',  bankName: 'State Bank of India — RS Puram' },
  { bankCode: 'ICICI', bankName: 'ICICI Bank — Avinashi Road' },
]

// ── Form Types ───────────────────────────────────────────────────────────────
export const FORM_TYPES: FormTypeOption[] = [
  { formCode: '03', formName: 'NONE' },
  { formCode: '01', formName: 'C-FORM' },
  { formCode: '02', formName: 'H-FORM' },
]

// ── GST Tax Codes ────────────────────────────────────────────────────────────
export const GST_TAX_CODES: GstTaxCodeOption[] = [
  { taxCode: 'GST18', taxDesc: 'GST 18%', cgstPer: 9,   sgstPer: 9,   igstPer: 18, taxStatus: 'Y' },
  { taxCode: 'GST12', taxDesc: 'GST 12%', cgstPer: 6,   sgstPer: 6,   igstPer: 12, taxStatus: 'Y' },
  { taxCode: 'GST05', taxDesc: 'GST 5%',  cgstPer: 2.5, sgstPer: 2.5, igstPer: 5,  taxStatus: 'Y' },
  { taxCode: 'GST28', taxDesc: 'GST 28%', cgstPer: 14,  sgstPer: 14,  igstPer: 28, taxStatus: 'Y' },
]

// ── Eligible PR Lines (PR Picker — BR-02 pre-filtered server-side) ───────────
export const ELIGIBLE_PR: EligiblePrLine[] = [
  { id: 'PR-0053|1|SF-450', prNo: 53, prDate: '01-Jun-26', prSno: 1, itemCode: 'SF-450', itemName: 'Separator Felt 450mm',   uom: 'MTR', balanceQty: 150, department: 'Spinning',    subCostCentre: 'Ring Frame',  remarks: '',                 hsnCode: '5911', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar' },
  { id: 'PR-0053|2|NW-12',  prNo: 53, prDate: '01-Jun-26', prSno: 2, itemCode: 'NW-12',  itemName: 'Nylon Webbing 12mm',     uom: 'MTR', balanceQty: 300, department: 'Spinning',    subCostCentre: 'Ring Frame',  remarks: '20mm also acceptable', hsnCode: '5806', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0012', requesterName: 'Suresh Kumar' },
  { id: 'PR-0054|1|RB-6206', prNo: 54, prDate: '03-Jun-26', prSno: 1, itemCode: 'RB-6206', itemName: 'Ball Bearing 6206 ZZ', uom: 'NOS', balanceQty: 24,  department: 'Maintenance', subCostCentre: 'Mechanical',  remarks: '',                 hsnCode: '',     cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0031', requesterName: 'Ravi S.' },
  { id: 'PR-0055|1|BO-22',  prNo: 55, prDate: '05-Jun-26', prSno: 1, itemCode: 'BO-22',  itemName: 'Bobbin (22mm Bore)',     uom: 'NOS', balanceQty: 500, department: 'Spinning',    subCostCentre: 'Winding',     remarks: 'Plastic preferred', hsnCode: '8448', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0019', requesterName: 'Kumar T.' },
  { id: 'PR-0056|1|TC-304', prNo: 56, prDate: '07-Jun-26', prSno: 1, itemCode: 'TC-304', itemName: 'Tin Can 304mm',          uom: 'NOS', balanceQty: 200, department: 'Spinning',    subCostCentre: 'Winding',     remarks: '',                 hsnCode: '7310', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0019', requesterName: 'Kumar T.' },
  { id: 'PR-0056|2|TC-406', prNo: 56, prDate: '07-Jun-26', prSno: 2, itemCode: 'TC-406', itemName: 'Tin Can 406mm',          uom: 'NOS', balanceQty: 100, department: 'Spinning',    subCostCentre: 'Winding',     remarks: '',                 hsnCode: '7310', cgstPer: 9, sgstPer: 9, igstPer: 0, gstTaxCode: 'GST18', requesterId: 'EMP-0019', requesterName: 'Kumar T.' },
]

/** Item-master backfill for fields a saved line carries but the request omits. */
export const PR_BY_ITEM = new Map(ELIGIBLE_PR.map((p) => [p.itemCode, p]))

// ── Builders (shared by the seeded PO and the live POST handler) ─────────────
export function buildLine(req: SavePoLineRequest, lineNo: number): PoLine {
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

export function buildSavedPo(req: AddPoRequest, poNo: number): PoHeader {
  const lines = req.lines.map((l, i) => buildLine(l, i + 1))
  const orderValue = round2(lines.reduce((s, l) => s + l.value, 0))
  const delivery = req.lines.map((l, i) => ({
    lineNo: i + 1, itemCode: l.itemCode,
    itemName: PR_BY_ITEM.get(l.itemCode)?.itemName ?? l.itemCode,
    uom: PR_BY_ITEM.get(l.itemCode)?.uom ?? 'NOS',
    prNo: PR_BY_ITEM.get(l.itemCode)?.prNo ?? 0,
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

// ── Seeded "existing" Purchase Order (loads on screen open; has a GRN → 409) ─
const DEMO_HEADER: Omit<PoHeader, 'divCode' | 'poNo' | 'lines' | 'delivery'> = {
  poDate: '2026-06-09', orderType: 'STORE', orderTypeDesc: 'Store Purchase',
  supplier: 'SUP-0042', supplierName: 'Coimbatore Spinners Supply Co.',
  gstin: '33AABCS1429B1Z5', gstState: '33 — Tamil Nadu', inspect: 'YES', roundOff: 0, orderValue: 0,
  formType: '03', refNo: 'REF/2026/0098', refDate: null, currency: 'INR', currRate: 1, remarks: 'Standard store purchase',
  cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, discPer: 0, cessPer: 0, aedPer: 0,
  freightAmt: 0, packPer: 0, insurPer: 0, surchargePer: 0, addTaxPer: 0, fileNo: '', fcaFob: 0,
  freightType: 'PAID', discApp: 'BEFORE', packApp: 'BEFORE', cessApp: 'BEFORE',
  payMode: 'DIRECT', directInstr: 'Pay against delivery', bankCode: '', paymentTerms: '', advPer: 0, advAmt: 0,
  modeOfPayment: 'NEFT', payRef: '', payRefDate: null, chequeNo: '', chequeDate: null,
  carrier: '02', creditDays: 30, deliveryDate: null, deliveryLocation: 'Coimbatore Stores', billingAddress: 'Coimbatore Head Office',
  specialInstr: 'Handle with care', despatch: '', purpose: 'Production', otherLevies: '', pricingTerms: '',
  packForwarding: '', insurance: '', freight: '',
  reminder: '', status: 'OPEN', cancelled: false, cancelDate: null, cancelReason: '',
  approved: 'NO', approvedBy: '',
  amdOrderNo: null, amdDate: null, amdRefNo: null, amdRefDate: null,
  approvalStatus: 'Pending L1', printStatus: 'Not Printed', firstLevelApp: 'Y', conflg: 'N',
  createdBy: 'Suresh Kumar', createdDt: '2026-06-09T10:42:00', userId: '0012',
}

const DEMO_LINE_SPECS: SavePoLineRequest[] = [
  { prSno: 1, itemCode: 'SF-450', rate: 0.85, qty: 150, taxCode: 'GST18', hsnCode: '5911', cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, cgstCode: 'CG09', sgstCode: 'SG09', igstCode: '', route: 'LOCAL', slots: [
    { slotNo: 1, shDate: '2026-06-20', qty: 100, remarks: 'First batch' },
    { slotNo: 2, shDate: '2026-06-30', qty: 50,  remarks: 'Balance' },
  ] },
  { prSno: 1, itemCode: 'BO-22', rate: 12, qty: 500, taxCode: 'GST18', hsnCode: '8448', cgstPer: 9, sgstPer: 9, igstPer: 0, tcsPer: 0, cgstCode: 'CG09', sgstCode: 'SG09', igstCode: '', route: 'LOCAL', slots: [
    { slotNo: 1, shDate: '2026-06-25', qty: 500, remarks: 'Full quantity' },
  ] },
]

/** Fully-built seeded PO-000138 (lines + delivery). PO number 138 is GRN-flagged. */
export const DEMO_PO: PoHeader = buildSavedPo(
  { poDate: DEMO_HEADER.poDate, header: DEMO_HEADER, lines: DEMO_LINE_SPECS },
  138,
)

export const FIRST_PO_NO = 123          // CD-03: first server-allocated number
export const BUDGET_CAP = 500_000       // BR-16: order value above this is blocked
export const GRN_PO_NOS = new Set<number>([138])   // BR-03: these POs have a GRN → 409
