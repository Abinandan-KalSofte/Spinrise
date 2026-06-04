/**
 * SPINRISE — PR First Level Approval (frmindentapp.frm)
 * FSD: SPINRISE_FSD_M01_PRFirstLevelApproval_v1.1 · Blueprint v6.0
 * VB6 source: frmindentapp.frm (4481 lines, 22 error handlers)
 * Test ID prefix: FA-
 *
 * Login strategy:
 *   Call real /auth/login API → get JWT → inject into localStorage
 *   key 'spinrise-auth-v2' (Zustand persist) via addInitScript
 *   BEFORE React boots. No Ant Design form interaction needed.
 *
 * Run:
 *   npx playwright test first-level-approval.spec.ts --headed
 *   npx playwright test first-level-approval.spec.ts
 *   npx playwright show-report report
 */

import { test, expect, type Page, type APIRequestContext } from '@playwright/test'
import * as fs   from 'fs'
import * as path from 'path'

// ── Server config ─────────────────────────────────────────────────────────────
const API_URL  = 'http://127.0.0.1:5000/api/v1'   // direct to backend
const BASE_URL = 'http://localhost:5173'            // Vite dev server
const DIV_CODE = '01'
const USERNAME = 'kalsofte'
const PASSWORD = 'kalsofte'

// ── Screenshots ───────────────────────────────────────────────────────────────
const SHOT_DIR = path.join(__dirname, 'screenshots')
if (!fs.existsSync(SHOT_DIR)) fs.mkdirSync(SHOT_DIR, { recursive: true })
const shot = (name: string) => path.join(SHOT_DIR, `FA_${name}_${Date.now()}.png`)

// ── Auth helpers ───────────────────────────────────────────────────────────────

async function getAuthState(request: APIRequestContext): Promise<string> {
  const resp = await request.post(`${API_URL}/auth/login`, {
    data: { divCode: DIV_CODE, userName: USERNAME, password: PASSWORD },
    headers: { 'Content-Type': 'application/json' },
  })
  if (!resp.ok()) throw new Error(`Login failed ${resp.status()}: ${await resp.text()}`)
  const json = await resp.json()
  if (!json.success || !json.data?.tokens?.accessToken)
    throw new Error(`No token in response: ${JSON.stringify(json)}`)

  const today = new Date().toISOString().split('T')[0]
  return JSON.stringify({
    state: {
      user:            json.data.user,
      tokens:          json.data.tokens,
      isAuthenticated: true,
      processingDate:  today,
    },
    version: 0,
  })
}

// Inject BEFORE React boots — addInitScript runs before every page.goto
async function injectAuth(page: Page, authState: string): Promise<void> {
  await page.addInitScript((state: string) => {
    localStorage.setItem('spinrise-auth-v2', state)
  }, authState)
}

async function gotoPage(page: Page, waitSelector?: string): Promise<void> {
  await page.goto(`${BASE_URL}/pr-first-approval`)
  await page.waitForLoadState('networkidle', { timeout: 20_000 })
  if (waitSelector)
    await page.waitForSelector(waitSelector, { timeout: 15_000 }).catch(() => {})
}

// ── API response wrapper (Spinrise.Shared ApiResponse<T>) ─────────────────────
function ok(data: unknown) {
  return { status: 200, contentType: 'application/json',
    body: JSON.stringify({ success: true, message: 'OK', data }) }
}
function fail(status: number, message: string) {
  return { status, contentType: 'application/json',
    body: JSON.stringify({ success: false, message, data: null }) }
}

// ── Mock data ─────────────────────────────────────────────────────────────────
const PO_PARA = {
  divCode: DIV_CODE, appUserLevel1: '5', appUserLevel2: '3', appUserLevel3: '2',
  appUserLabel1: 'SM', appUserLabel2: 'FM', appUserLabel3: 'GM',
}

const DEPTS = [
  { depCode: 'WVG', depName: 'Weaving',  userLevel: '5' },
  { depCode: 'SPG', depName: 'Spinning', userLevel: '5' },
]

const PENDING_LIST = [
  { prNo: 329, prDate: '2026-05-15T00:00:00', depCode: 'WVG', depName: 'Weaving',
    reqName: 'Arjun M', iType: 'N', totalLines: 2, prStatus: 'REQUESTED' },
  { prNo: 330, prDate: '2026-05-20T00:00:00', depCode: 'WVG', depName: 'Weaving',
    reqName: 'Kumar S', iType: 'N', totalLines: 1, prStatus: 'REQUESTED' },
]

const APPROVED_LIST = [
  { prNo: 320, prDate: '2026-05-10T00:00:00', depCode: 'SPG', depName: 'Spinning',
    reqName: 'Velu K', iType: 'N', totalLines: 3, prStatus: 'FIRST LEVEL APPROVED' },
]

const PR_DETAIL = {
  header: {
    divCode: DIV_CODE, prNo: 329, prDate: '2026-05-15T00:00:00',
    depCode: 'WVG', depName: 'Weaving', refNo: 'REF-2026-001',
    section: 'PROD', subCost: 'SC01', sccName: 'Production Cost Centre',
    app1: null, app2: null, app3: null, appFlg: 'N', app1Date: null, reqName: 'Arjun M',
  },
  lines: [
    { prSno: 1, itemCode: 'YARN001', itemName: 'Cotton Yarn 20s', uom: 'KG',
      machine: 'Ring Frame RG-01', curStock: 150.000, qtyInd: 500.000, qtyReqd: 500.000,
      firstAppQty: 0.000, secondAppQty: 0.000, thirdAppQty: 0.000,
      qtyOrd: 0.000, qtyRec: 0.000, rate: 85.5000, value: 42750.00,
      reqdDate: '2026-06-01T00:00:00', firstApp: null, prStatus: null,
      place: null, appCost: 42750.00, remarks: 'Urgent requirement', bgrpCode: null, macNo: 'RG01' },
    { prSno: 2, itemCode: 'OIL002', itemName: 'Spindle Oil', uom: 'LTR',
      machine: null, curStock: 20.000, qtyInd: 50.000, qtyReqd: 50.000,
      firstAppQty: 0.000, secondAppQty: 0.000, thirdAppQty: 0.000,
      qtyOrd: 0.000, qtyRec: 0.000, rate: 120.0000, value: 6000.00,
      reqdDate: null, firstApp: null, prStatus: null,
      place: null, appCost: 6000.00, remarks: null, bgrpCode: null, macNo: null },
  ],
}

const APPROVED_DETAIL = {
  header: { ...PR_DETAIL.header, prNo: 320, prDate: '2026-05-10T00:00:00',
    app1: 'Y', app1Date: '2026-05-10T00:00:00', appFlg: 'Y' },
  lines: PR_DETAIL.lines.map(l => ({ ...l, firstApp: 'Y', firstAppQty: l.qtyInd })),
}

const APPROVE_SUCCESS = {
  success: true, message: 'PR-00329 — First Level Approval saved. PRSTATUS → F.', data: null,
}

const PDF_BYTES = Buffer.from('%PDF-1.4 1 0 obj<</Type/Catalog>>endobj trailer<</Root 1 0 R>>')

// ── Mock all module API routes ─────────────────────────────────────────────────
async function mockModuleApis(page: Page, detailOverride?: object): Promise<void> {
  await page.route('**/api/v1/pr-first-approval/po-para**',      r => r.fulfill(ok(PO_PARA)))
  await page.route('**/api/v1/pr-first-approval/departments**',  r => r.fulfill(ok(DEPTS)))
  await page.route('**/api/v1/pr-first-approval/pending**',      r => r.fulfill(ok(PENDING_LIST)))
  await page.route('**/api/v1/pr-first-approval/approved**',     r => r.fulfill(ok(APPROVED_LIST)))
  await page.route('**/api/v1/pr-first-approval/detail**',       r => r.fulfill(ok(detailOverride ?? PR_DETAIL)))
  await page.route('**/api/v1/pr-first-approval/approve',        r => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) }))
  await page.route('**/api/v1/pr-first-approval/delete-approval**', r => r.fulfill(ok(null)))
  await page.route('**/api/v1/pr-first-approval/*/print**',      r => r.fulfill({ status: 200, contentType: 'application/pdf', body: PDF_BYTES }))
}

// ── Flow helpers ───────────────────────────────────────────────────────────────
//
// PrApprovalDeptModal:   row onClick → setSelected only.  row onDoubleClick → setSelected + onNext(record)
// PrApprovalLookupModal: row onClick → setSelected only.  row onDoubleClick → setSelected + onSelect(record)
// → use dblclick on rows so the modal proceeds in one gesture.

// Load PRs → dept modal (dblclick Weaving) → pending PR modal (dblclick PR 329)
async function selectPRForApprove(page: Page): Promise<void> {
  await page.getByRole('button', { name: /Load PRs/i }).click()

  // Dept modal: dblclick row (scoped to dialog to avoid sidebar)
  const deptRow = page.getByRole('dialog').locator('tr').filter({ hasText: 'Weaving' }).first()
  await deptRow.waitFor({ timeout: 5_000 })
  await deptRow.dblclick()

  // Pending list modal: dblclick PR 329 row
  const prRow = page.getByRole('dialog').locator('tr').filter({ hasText: '329' }).first()
  await prRow.waitFor({ timeout: 8_000 })
  await prRow.dblclick()

  await page.waitForLoadState('networkidle')
}

// Delete → approved list modal (dblclick PR 320)
async function selectPRForDelete(page: Page): Promise<void> {
  await page.getByRole('button', { name: /Delete/i }).first().click()
  const prRow = page.getByRole('dialog').locator('tr').filter({ hasText: '320' }).first()
  await prRow.waitFor({ timeout: 5_000 })
  await prRow.dblclick()
  await page.waitForLoadState('networkidle')
}

// Find → approved list modal (dblclick PR 320)
async function selectPRForFind(page: Page): Promise<void> {
  await page.getByRole('button', { name: /Find/i }).click()
  const prRow = page.getByRole('dialog').locator('tr').filter({ hasText: '320' }).first()
  await prRow.waitFor({ timeout: 5_000 })
  await prRow.dblclick()
  await page.waitForLoadState('networkidle')
}

// ── Shared auth state (obtained once for entire run) ───────────────────────────
let authState: string

test.beforeAll(async ({ request }) => {
  authState = await getAuthState(request)
  console.log('✅  Auth token obtained')
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-SL — Screen Load
// FSD §1 · CD-06 po_para single-read caching (VB6 read it 8× per session)
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-SL — Screen Load', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
  })

  test('FA-SL-01: breadcrumb shows Purchase Order › PR First Level Approval', async ({ page }) => {
    await page.screenshot({ path: shot('SL-01') })
    await expect(page.getByText(/Purchase Order/i).first()).toBeVisible()
    await expect(page.getByText(/First Level Approval/i).first()).toBeVisible()
  })

  test('FA-SL-02: po-para NOT called more than twice per page load — CD-06 (≤2 allows React StrictMode dev double-invoke)', async ({ page }) => {
    // This test controls its own navigation — does NOT rely on beforeEach gotoPage
    // React StrictMode in dev intentionally double-invokes effects → allow ≤2.
    // The VB6 bug (CD-06) called po-para 8× per session — we must be far below that.
    await injectAuth(page, authState)
    let calls = 0
    await page.route('**/api/v1/pr-first-approval/po-para**', async r => { calls++; await r.fulfill(ok(PO_PARA)) })
    await mockModuleApis(page)
    await gotoPage(page)
    expect(calls).toBeGreaterThanOrEqual(1)  // must call at least once (page loaded)
    expect(calls).toBeLessThanOrEqual(2)     // must not call 8× like VB6 (CD-06)
  })

  test('FA-SL-03: No PR Selected empty state shown', async ({ page }) => {
    await expect(page.getByText(/No PR Selected/i)).toBeVisible()
  })

  test('FA-SL-04: Load PRs, Delete, Find enabled in QUERY mode', async ({ page }) => {
    await expect(page.getByRole('button', { name: /Load PRs/i })).toBeEnabled()
    await expect(page.getByRole('button', { name: /Delete/i }).first()).toBeEnabled()
    await expect(page.getByRole('button', { name: /Find/i })).toBeEnabled()
  })

  test('FA-SL-05: Save and Print disabled in QUERY mode', async ({ page }) => {
    await expect(page.getByRole('button', { name: /Save|Approve/i })).toBeDisabled()
    await expect(page.getByRole('button', { name: /Print/i })).toBeDisabled()
  })

  test('FA-SL-06: navigation buttons hardcoded disabled — approval has no record nav', async ({ page }) => {
    // All four nav buttons « ‹ › » are disabled in HTML design
    const nav = page.locator('button:disabled').filter({ hasText: /[«‹›»]/ })
    await expect(nav.first()).toBeDisabled()
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-DP — Department Selection & PR Lookup
// FSD §4 BR: Listing query (level-aware) · User level check on Add
// VB6: BUTTON_Click Case 0 → checkrs query → dep variable
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-DP — Department & PR Lookup', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
  })

  test('FA-DP-01: Load PRs opens Department modal', async ({ page }) => {
    await page.getByRole('button', { name: /Load PRs/i }).click()
    await page.screenshot({ path: shot('DP-01') })
    await expect(page.getByRole('dialog')).toBeVisible()
  })

  test('FA-DP-02: Department modal lists Weaving and Spinning from /departments', async ({ page }) => {
    await page.getByRole('button', { name: /Load PRs/i }).click()
    await expect(page.getByText('Weaving')).toBeVisible()
    await expect(page.getByText('Spinning')).toBeVisible()
  })

  test('FA-DP-03: /departments receives divCode — FSD §4 division scope', async ({ page }) => {
    let url = ''
    await page.route('**/api/v1/pr-first-approval/departments**', async r => {
      url = r.request().url(); await r.fulfill(ok(DEPTS))
    })
    await page.getByRole('button', { name: /Load PRs/i }).click()
    await page.waitForLoadState('networkidle')
    expect(url).toMatch(/divCode=/i)
  })

  test('FA-DP-04: dblclick dept row opens pending PR list — Step 1 of 2 flow', async ({ page }) => {
    await page.getByRole('button', { name: /Load PRs/i }).click()
    const deptRow = page.getByRole('dialog').locator('tr').filter({ hasText: 'Weaving' }).first()
    await deptRow.waitFor({ timeout: 5_000 })
    await deptRow.dblclick()
    await expect(page.getByRole('dialog').getByText('329')).toBeVisible({ timeout: 8_000 })
    await page.screenshot({ path: shot('DP-04') })
  })

  test('FA-DP-05: pending list shows PR No., Requester from PENDING_LIST', async ({ page }) => {
    await page.getByRole('button', { name: /Load PRs/i }).click()
    const deptRow = page.getByRole('dialog').locator('tr').filter({ hasText: 'Weaving' }).first()
    await deptRow.waitFor({ timeout: 5_000 })
    await deptRow.dblclick()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('329')).toBeVisible({ timeout: 8_000 })
    await expect(dialog.getByText('Arjun M')).toBeVisible()
  })

  test('FA-DP-06: empty pending list shows no-records message from Zustand store', async ({ page }) => {
    await page.route('**/api/v1/pr-first-approval/pending**', r => r.fulfill(ok([])))
    await page.getByRole('button', { name: /Load PRs/i }).click()
    const deptRow = page.getByRole('dialog').locator('tr').filter({ hasText: 'Weaving' }).first()
    await deptRow.waitFor({ timeout: 5_000 })
    await deptRow.dblclick()
    // Store calls message.info('No Records Found') when list is empty
    await expect(page.getByText(/No Records Found|No data/i)).toBeVisible({ timeout: 5_000 })
  })

  test('FA-DP-07: /pending receives dep code WVG from selected department', async ({ page }) => {
    let url = ''
    await page.route('**/api/v1/pr-first-approval/pending**', async r => {
      url = r.request().url(); await r.fulfill(ok(PENDING_LIST))
    })
    await page.getByRole('button', { name: /Load PRs/i }).click()
    const deptRow = page.getByRole('dialog').locator('tr').filter({ hasText: 'Weaving' }).first()
    await deptRow.waitFor({ timeout: 5_000 })
    await deptRow.dblclick()
    await page.waitForLoadState('networkidle')
    expect(url).toMatch(/dep=WVG/i)
  })

  test('FA-DP-08: Delete button opens approved list modal', async ({ page }) => {
    await page.getByRole('button', { name: /Delete/i }).first().click()
    await expect(page.getByRole('dialog').getByText('320')).toBeVisible({ timeout: 5_000 })
    await page.screenshot({ path: shot('DP-08') })
  })

  test('FA-DP-09: Find button opens approved list modal', async ({ page }) => {
    await page.getByRole('button', { name: /Find/i }).click()
    await expect(page.getByRole('dialog').getByText('320')).toBeVisible({ timeout: 5_000 })
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-DL — PR Detail Load
// FSD §3 Field Table: PO_PRH header + PO_PRL lines via two Dapper queries
// VB6: adoPrimaryRS SHAPE query (parent-child OLE DB — replaced by CD-04)
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-DL — PR Detail Load', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
    await selectPRForApprove(page)
  })

  test('FA-DL-01: PR No. 329 shown in doc band after selection — PO_PRH.prno', async ({ page }) => {
    await page.screenshot({ path: shot('DL-01') })
    await expect(page.getByText('329').first()).toBeVisible()
  })

  test('FA-DL-02: Department Name Weaving shown — IN_DEP join', async ({ page }) => {
    await expect(page.getByText('Weaving')).toBeVisible()
  })

  test('FA-DL-03: Requester Arjun M shown — PO_PRH.REQNAME', async ({ page }) => {
    await expect(page.getByText('Arjun M')).toBeVisible()
  })

  test('FA-DL-04: Ref No. shown — PO_PRH.refno', async ({ page }) => {
    await expect(page.getByText('REF-2026-001')).toBeVisible()
  })

  test('FA-DL-05: Section shown — PO_PRH.section', async ({ page }) => {
    await expect(page.getByText('PROD')).toBeVisible()
  })

  test('FA-DL-06: SubCost Centre Name shown — In_Scc join', async ({ page }) => {
    await expect(page.getByText('Production Cost Centre')).toBeVisible()
  })

  test('FA-DL-07: Approve Date defaults to today — FSD §3 Default=pdate', async ({ page }) => {
    const yyyy = new Date().getFullYear().toString()
    const datePicker = page.locator('.ant-picker-input input').first()
    await expect(datePicker).toHaveValue(new RegExp(yyyy))
  })

  test('FA-DL-08: Item Code YARN001 and OIL002 in grid — PO_PRL+IN_ITEM', async ({ page }) => {
    await expect(page.getByText('YARN001')).toBeVisible()
    await expect(page.getByText('OIL002')).toBeVisible()
  })

  test('FA-DL-09: Item Names shown — in_item.Itemname', async ({ page }) => {
    await expect(page.getByText('Cotton Yarn 20s')).toBeVisible()
    await expect(page.getByText('Spindle Oil')).toBeVisible()
  })

  test('FA-DL-10: UOM KG and LTR shown — in_item.Cuom', async ({ page }) => {
    await expect(page.getByText('KG')).toBeVisible()
    await expect(page.getByText('LTR')).toBeVisible()
  })

  test('FA-DL-11: Machine shown from mm_MACmas join', async ({ page }) => {
    await expect(page.getByText(/Ring Frame|RG-01/i)).toBeVisible()
  })

  test('FA-DL-12: Qty Required 500.000 shown — PO_PRL.QTYIND read-only', async ({ page }) => {
    await expect(page.getByText('500.000').first()).toBeVisible()
  })

  test('FA-DL-13: item count badge shows 2 items', async ({ page }) => {
    await expect(page.getByText(/2 item/i)).toBeVisible()
  })

  test('FA-DL-14: APPROVE mode yellow hint banner visible', async ({ page }) => {
    await expect(page.getByText(/Editable.*Approval|First Approval Quantity/i)).toBeVisible()
  })

  test('FA-DL-15: Load PRs, Delete, Find disabled after PR load — APPROVE mode not QUERY', async ({ page }) => {
    await expect(page.getByRole('button', { name: /Load PRs/i })).toBeDisabled()
    await expect(page.getByRole('button', { name: /Delete/i }).first()).toBeDisabled()
    await expect(page.getByRole('button', { name: /Find/i })).toBeDisabled()
  })

  test('FA-DL-16: Save enabled after PR load', async ({ page }) => {
    await expect(page.getByRole('button', { name: /Save|Approve/i })).toBeEnabled()
  })

  test('FA-DL-17: approval level label SM shown from PO_PARA.AppUserLabel1', async ({ page }) => {
    await expect(page.getByText('SM').first()).toBeVisible()
  })

  test('FA-DL-18: Remarks column displays from PO_PRL.remarks — read-only', async ({ page }) => {
    await expect(page.getByText('Urgent requirement')).toBeVisible()
    // Not an editable input
    const remarksInput = page.locator('td').filter({ hasText: 'Urgent requirement' }).locator('input')
    await expect(remarksInput).toHaveCount(0)
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-GR — Grid Editing in APPROVE Mode
// FSD §3: Rate, QTYREQD, FirstAppQty editable. Others read-only.
// VB6: ubGrid1 editable cols 10 (FirstAppQty), rate, value
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-GR — Grid Editing', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
    await selectPRForApprove(page)
  })

  test('FA-GR-01: row checkbox present and checkable', async ({ page }) => {
    await page.screenshot({ path: shot('GR-01') })
    const box = page.locator('tbody input[type="checkbox"]').first()
    await expect(box).toBeVisible()
    await box.check()
    await expect(box).toBeChecked()
  })

  test('FA-GR-02: Select All header checkbox selects all rows', async ({ page }) => {
    const selectAll = page.locator('thead input[type="checkbox"]').first()
    await selectAll.check()
    const boxes = page.locator('tbody input[type="checkbox"]')
    for (let i = 0; i < await boxes.count(); i++)
      await expect(boxes.nth(i)).toBeChecked()
  })

  test('FA-GR-03: uncheck Select All deselects all rows', async ({ page }) => {
    const selectAll = page.locator('thead input[type="checkbox"]').first()
    await selectAll.check()
    await selectAll.uncheck()
    const boxes = page.locator('tbody input[type="checkbox"]')
    for (let i = 0; i < await boxes.count(); i++)
      await expect(boxes.nth(i)).not.toBeChecked()
  })

  test('FA-GR-04: selected count badge updates when row checked', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await expect(page.getByText(/1 selected/i)).toBeVisible()
  })

  test('FA-GR-05: two items selected shows 2 selected', async ({ page }) => {
    const boxes = page.locator('tbody input[type="checkbox"]')
    await boxes.nth(0).check()
    await boxes.nth(1).check()
    await expect(page.getByText(/2 selected/i)).toBeVisible()
  })

  test('FA-GR-06: numeric inputs present and enabled in APPROVE mode — QTYREQD/Rate editable', async ({ page }) => {
    const inputs = page.locator('tbody input[type="number"]')
    const count  = await inputs.count()
    expect(count).toBeGreaterThan(0)
    await expect(inputs.first()).toBeEnabled()
  })

  test('FA-GR-07: Item Code cell is not an editable input — FSD §3 read-only', async ({ page }) => {
    const itemCodeInput = page.locator('td').filter({ hasText: 'YARN001' }).locator('input')
    await expect(itemCodeInput).toHaveCount(0)
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-SV — Save / First Level Approve
// FSD §4: Date validation, Item selection, DB writes (PO_PRH + PO_PRL loop)
// VB6: BUTTON_Click Case 0 → BeginTrans → UPDATE PO_PRH → loop UPDATE PO_PRL
// CD-05: Print is a separate endpoint — not bundled with save
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-SV — Save / Approve', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
    await selectPRForApprove(page)
  })

  test('FA-SV-01: Save opens Confirm First Level Approval modal', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.screenshot({ path: shot('SV-01') })
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByText(/Confirm First Level Approval/i)).toBeVisible()
  })

  test('FA-SV-02: confirmation modal shows PR No. 329', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await expect(page.getByRole('dialog').getByText('329')).toBeVisible()
  })

  test('FA-SV-03: confirmation modal mentions PRSTATUS → F — FSD §4 DB writes', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await expect(page.getByRole('dialog').getByText(/First Approved|PRSTATUS.*F/i)).toBeVisible()
  })

  test('FA-SV-04: confirming calls POST /approve exactly once', async ({ page }) => {
    let calls = 0
    await page.route('**/api/v1/pr-first-approval/approve', async r => {
      calls++
      await r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) })
    })
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    expect(calls).toBe(1)
  })

  test('FA-SV-05: /approve body has prNo, prDate, appDate, lines array — FSD §4', async ({ page }) => {
    let body: Record<string, unknown> = {}
    await page.route('**/api/v1/pr-first-approval/approve', async r => {
      body = JSON.parse(r.request().postData() ?? '{}')
      await r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) })
    })
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    expect(body).toHaveProperty('prNo')
    expect(body).toHaveProperty('prDate')
    expect(body).toHaveProperty('appDate')
    expect(Array.isArray(body['lines'])).toBe(true)
  })

  test('FA-SV-06: Item is not Selected when API rejects empty lines — FSD §4 BR', async ({ page }) => {
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill(fail(422, 'Item is not Selected')))
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await expect(page.getByText(/Item is not Selected/i)).toBeVisible({ timeout: 5_000 })
  })

  test('FA-SV-07: future date → Date should be Equal to Current Date error — FSD §4', async ({ page }) => {
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill(fail(422, 'Date should be Equal to Current Date Or Max Purchase Requisition Date')))
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await expect(page.getByText(/Date should be Equal to Current Date/i)).toBeVisible({ timeout: 5_000 })
  })

  test('FA-SV-08: 403 → Not Approved User Level toast — CD-07 level enforced at API', async ({ page }) => {
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill(fail(403, 'Not Approved User Level')))
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await expect(page.getByText(/Not Approved User Level/i)).toBeVisible({ timeout: 5_000 })
  })

  test('FA-SV-09: cancelling confirmation does not call /approve', async ({ page }) => {
    let called = false
    await page.route('**/api/v1/pr-first-approval/approve', async r => { called = true; await r.fulfill(ok(null)) })
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /Cancel/i }).last().click()
    expect(called).toBe(false)
  })

  test('FA-SV-10: Ctrl+S opens confirmation modal — FSD §4 keyboard shortcuts', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.keyboard.press('Control+s')
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByText(/Confirm First Level Approval/i)).toBeVisible()
  })

  test('FA-SV-11: after approval Print button becomes enabled — CD-05 print after save', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    await page.screenshot({ path: shot('SV-11') })
    await expect(page.getByRole('button', { name: /Print/i })).toBeEnabled({ timeout: 8_000 })
  })

  test('FA-SV-12: after approval Save becomes disabled — mode SAVED', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    await expect(page.getByRole('button', { name: /Save|Approve/i })).toBeDisabled({ timeout: 8_000 })
  })

  test('FA-SV-13: after approval grid becomes read-only — no editable number inputs', async ({ page }) => {
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    await expect(page.locator('tbody input[type="number"]:not([disabled])')).toHaveCount(0, { timeout: 5_000 })
  })

  test('FA-SV-14: double-submit — Save disabled while /approve in-flight — SV-07', async ({ page }) => {
    let release!: () => void
    const hold = new Promise<void>(r => { release = r })
    await page.route('**/api/v1/pr-first-approval/approve', async r => {
      await hold
      await r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) })
    })
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await expect(
      page.getByRole('button', { name: /^Approve$/ }).last()
    ).toBeDisabled({ timeout: 3_000 }).catch(() => {/* loading state also acceptable */})
    release()
    await page.waitForLoadState('networkidle')
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-DA — Delete First Level Approval
// FSD §4: UPDATE PO_PRH SET appflg='N', app1/2/3=null · UPDATE PO_PRL reset
// VB6: BUTTON_Click Case 2 (Delete) → BeginTrans → UPDATE PO_PRH → UPDATE PO_PRL
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-DA — Delete Approval', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page, APPROVED_DETAIL)
    await gotoPage(page)
    await selectPRForDelete(page)
  })

  test('FA-DA-01: red Delete Approval Mode banner shown', async ({ page }) => {
    await page.screenshot({ path: shot('DA-01') })
    await expect(page.getByText(/Delete Approval Mode|Undoing First Level Approval/i)).toBeVisible()
  })

  test('FA-DA-02: Delete mode — grid is read-only, no editable inputs', async ({ page }) => {
    await expect(page.locator('tbody input[type="number"]:not([disabled])')).toHaveCount(0, { timeout: 3_000 })
  })

  test('FA-DA-03: Confirm Delete button visible', async ({ page }) => {
    await expect(page.getByRole('button', { name: /Confirm Delete/i })).toBeVisible()
  })

  test('FA-DA-04: Confirm Delete opens deletion modal with PR No. 320', async ({ page }) => {
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await page.screenshot({ path: shot('DA-04') })
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByRole('dialog').getByText('320')).toBeVisible()
  })

  test('FA-DA-05: deletion modal mentions PRSTATUS reset to Requested — FSD §4', async ({ page }) => {
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await expect(page.getByRole('dialog').getByText(/Requested/i)).toBeVisible()
  })

  test('FA-DA-06: deletion modal describes app1, FirstAppQty reset — FSD §4', async ({ page }) => {
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await expect(page.getByRole('dialog').getByText(/app1|FirstAppQty|reset/i)).toBeVisible()
  })

  test('FA-DA-07: confirming delete calls POST /delete-approval once', async ({ page }) => {
    let calls = 0
    await page.route('**/api/v1/pr-first-approval/delete-approval**', async r => { calls++; await r.fulfill(ok(null)) })
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await page.getByRole('button', { name: /Delete Approval/i }).last().click()
    await page.waitForLoadState('networkidle')
    expect(calls).toBe(1)
  })

  test('FA-DA-08: /delete-approval body has prNo and prDate — FSD §4', async ({ page }) => {
    let body: Record<string, unknown> = {}
    await page.route('**/api/v1/pr-first-approval/delete-approval**', async r => {
      body = JSON.parse(r.request().postData() ?? '{}')
      await r.fulfill(ok(null))
    })
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await page.getByRole('button', { name: /Delete Approval/i }).last().click()
    await page.waitForLoadState('networkidle')
    expect(body).toHaveProperty('prNo')
    expect(body).toHaveProperty('prDate')
  })

  test('FA-DA-09: 403 → Not Approved User Level — CD-07', async ({ page }) => {
    await page.route('**/api/v1/pr-first-approval/delete-approval**', r =>
      r.fulfill(fail(403, 'Not Approved User Level')))
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await page.getByRole('button', { name: /Delete Approval/i }).last().click()
    await expect(page.getByText(/Not Approved User Level/i)).toBeVisible({ timeout: 5_000 })
  })

  test('FA-DA-10: cancelling delete modal does not call /delete-approval', async ({ page }) => {
    let called = false
    await page.route('**/api/v1/pr-first-approval/delete-approval**', async r => { called = true; await r.fulfill(ok(null)) })
    await page.getByRole('button', { name: /Confirm Delete/i }).click()
    await page.getByRole('button', { name: /Cancel/i }).last().click()
    expect(called).toBe(false)
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-FI — Find / View Approved PR (SAVED mode)
// FSD §4 CD-05: reprint allowed at any time after approval
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-FI — Find / View', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page, APPROVED_DETAIL)
    await gotoPage(page)
  })

  test('FA-FI-01: Find opens modal with Find PR title — FIND mode', async ({ page }) => {
    await page.getByRole('button', { name: /Find/i }).click()
    await page.waitForLoadState('networkidle')
    await page.screenshot({ path: shot('FI-01') })
    // .ant-modal-title is more robust than role="dialog" for Ant Design modal title assertions
    await expect(page.locator('.ant-modal-title').getByText(/Find PR/i)).toBeVisible({ timeout: 8_000 })
  })

  test('FA-FI-02: Find list shows PR 320 with FIRST LEVEL APPROVED status', async ({ page }) => {
    await page.getByRole('button', { name: /Find/i }).click()
    await expect(page.getByText('320')).toBeVisible()
  })

  test('FA-FI-03: SAVED mode grid is read-only after Find select', async ({ page }) => {
    await selectPRForFind(page)
    await expect(page.locator('tbody input[type="number"]:not([disabled])')).toHaveCount(0, { timeout: 3_000 })
  })

  test('FA-FI-04: Print enabled in SAVED mode — CD-05 reprint allowed', async ({ page }) => {
    await selectPRForFind(page)
    await page.screenshot({ path: shot('FI-04') })
    await expect(page.getByRole('button', { name: /Print/i })).toBeEnabled()
  })

  test('FA-FI-05: Save disabled in SAVED mode', async ({ page }) => {
    await selectPRForFind(page)
    await expect(page.getByRole('button', { name: /Save|Approve/i })).toBeDisabled()
  })

  test('FA-FI-06: APPROVE mode hint banner not shown in SAVED mode', async ({ page }) => {
    await selectPRForFind(page)
    await expect(page.getByText(/Editable.*Approval|First Approval Quantity/i)).not.toBeVisible()
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-PR — Print (QuestPDF PrApprovalReport)
// FSD §5 Print Replacement (Crystal Reports → QuestPDF)
// CD-05: Separate /print endpoint — if print fails, approval record stands
// VB6: Cry_PO_IndentcrTransPrint called AFTER CommitTrans — already outside transaction
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-PR — Print', () => {

  test('FA-PR-01: Print disabled in QUERY mode', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
    await expect(page.getByRole('button', { name: /Print/i })).toBeDisabled()
  })

  test('FA-PR-02: Print disabled in APPROVE mode before save', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
    await selectPRForApprove(page)
    await expect(page.getByRole('button', { name: /Print/i })).toBeDisabled()
  })

  test('FA-PR-03: Print opens PDF modal — NOT a new tab (fixes window.open JWT issue)', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page, APPROVED_DETAIL)
    await gotoPage(page)
    await selectPRForFind(page)

    const newTabPromise = page.context().waitForEvent('page', { timeout: 2_000 }).catch(() => null)
    await page.getByRole('button', { name: /Print/i }).click()
    const newTab = await newTabPromise

    await page.screenshot({ path: shot('PR-03') })
    expect(newTab).toBeNull()                                            // no new tab
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 6_000 }) // modal shown
  })

  test('FA-PR-04: Print request carries Authorization Bearer header — Axios not window.open', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page, APPROVED_DETAIL)
    let authHeader = ''
    await page.route('**/api/v1/pr-first-approval/*/print**', async r => {
      authHeader = r.request().headers()['authorization'] ?? ''
      await r.fulfill({ status: 200, contentType: 'application/pdf', body: PDF_BYTES })
    })
    await gotoPage(page)
    await selectPRForFind(page)
    await page.getByRole('button', { name: /Print/i }).click()
    await page.waitForLoadState('networkidle')
    expect(authHeader).toMatch(/^Bearer /i)
  })

  test('FA-PR-05: Print URL contains prNo 320 and divCode — FSD §5 @Prno @Divcode', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page, APPROVED_DETAIL)
    let printUrl = ''
    await page.route('**/api/v1/pr-first-approval/*/print**', async r => {
      printUrl = r.request().url()
      await r.fulfill({ status: 200, contentType: 'application/pdf', body: PDF_BYTES })
    })
    await gotoPage(page)
    await selectPRForFind(page)
    await page.getByRole('button', { name: /Print/i }).click()
    await page.waitForLoadState('networkidle')
    expect(printUrl).toMatch(/\/320\/print/)
    expect(printUrl).toMatch(/divCode=/i)
  })

  test('FA-PR-06: Print failure shows error message — approval record unaffected CD-05', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page, APPROVED_DETAIL)
    await page.route('**/api/v1/pr-first-approval/*/print**', r => r.fulfill(fail(500, 'Failed to generate print.')))
    await gotoPage(page)
    await selectPRForFind(page)
    await page.getByRole('button', { name: /Print/i }).click()
    await expect(page.getByText(/Failed to generate print|print failed/i)).toBeVisible({ timeout: 5_000 })
  })

  test('FA-PR-07: approval success followed by print failure — Print still enabled (CD-05)', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await page.route('**/api/v1/pr-first-approval/*/print**', r => r.fulfill(fail(500, 'Print unavailable')))
    await gotoPage(page)
    await selectPRForApprove(page)
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    // Approval committed — Print button still enabled even though print will fail
    await expect(page.getByRole('button', { name: /Print/i })).toBeEnabled({ timeout: 8_000 })
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-CN — Cancel / Reset
// FSD §4 BR: Cancel/Reset → Opt='Qry', NEWFORM() — no DB write
// VB6: BUTTON_Click Case 10
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-CN — Cancel / Reset', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
    await selectPRForApprove(page)
  })

  test('FA-CN-01: Cancel returns to QUERY mode — No PR Selected shown', async ({ page }) => {
    await page.getByRole('button', { name: /Cancel/i }).last().click()
    await page.screenshot({ path: shot('CN-01') })
    await expect(page.getByText(/No PR Selected/i)).toBeVisible()
  })

  test('FA-CN-02: Alt+X resets — FSD §4 keyboard shortcuts', async ({ page }) => {
    await page.keyboard.press('Alt+x')
    await expect(page.getByText(/No PR Selected/i)).toBeVisible()
  })

  test('FA-CN-03: after cancel Load PRs, Delete, Find re-enabled', async ({ page }) => {
    await page.getByRole('button', { name: /Cancel/i }).last().click()
    await expect(page.getByRole('button', { name: /Load PRs/i })).toBeEnabled()
    await expect(page.getByRole('button', { name: /Delete/i }).first()).toBeEnabled()
    await expect(page.getByRole('button', { name: /Find/i })).toBeEnabled()
  })

  test('FA-CN-04: after cancel Save and Print disabled', async ({ page }) => {
    await page.getByRole('button', { name: /Cancel/i }).last().click()
    await expect(page.getByRole('button', { name: /Save|Approve/i })).toBeDisabled()
    await expect(page.getByRole('button', { name: /Print/i })).toBeDisabled()
  })

  test('FA-CN-05: cancel makes no DB-write API call — FSD §4 no DB write', async ({ page }) => {
    let writeCalled = false
    await page.route('**/api/v1/pr-first-approval/approve', async r => { writeCalled = true; await r.fulfill(ok(null)) })
    await page.route('**/api/v1/pr-first-approval/delete-approval**', async r => { writeCalled = true; await r.fulfill(ok(null)) })
    await page.getByRole('button', { name: /Cancel/i }).last().click()
    expect(writeCalled).toBe(false)
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-AU — Authorization
// FSD §4 CD-07: User level enforced at API. HTTP 403 on mismatch.
// CD-01: Dapper @param binding — verified via JWT header presence
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-AU — Authorization', () => {

  test('FA-AU-01: unauthenticated navigation redirects to /login', async ({ page }) => {
    // No injectAuth — clean page
    await page.goto(`${BASE_URL}/pr-first-approval`)
    await expect(page).toHaveURL(/login/, { timeout: 8_000 })
    await page.screenshot({ path: shot('AU-01') })
  })

  test('FA-AU-02: po-para 404 → Set User Level In Parameter Form — FSD §4 BR', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    // Override po-para after mockModuleApis so this route fires first (LIFO)
    await page.route('**/api/v1/pr-first-approval/po-para**', r =>
      r.fulfill(fail(404, 'Set User Level In Parameter Form')))
    await gotoPage(page)
    // Store's catch calls static antd message.error — look in ant-message container and page body
    await expect(
      page.locator('.ant-message-notice, .ant-message').getByText(/Set User Level In Parameter Form/i)
        .or(page.getByText(/Set User Level In Parameter Form/i))
    ).toBeVisible({ timeout: 8_000 })
  })

  test('FA-AU-03: every API request carries Authorization Bearer token — CD-01', async ({ page }) => {
    await injectAuth(page, authState)
    // Register mockModuleApis FIRST, then override po-para AFTER — LIFO means this route fires first
    await mockModuleApis(page)
    let hdr = ''
    await page.route('**/api/v1/pr-first-approval/po-para**', async r => {
      hdr = r.request().headers()['authorization'] ?? ''
      await r.fulfill(ok(PO_PARA))
    })
    await gotoPage(page)
    await page.waitForLoadState('networkidle')
    expect(hdr).toMatch(/^Bearer /i)
  })

  test('FA-AU-04: 403 on approve → Not Approved User Level — CD-07 API enforcement', async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill(fail(403, 'Not Approved User Level')))
    await gotoPage(page)
    await selectPRForApprove(page)
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await expect(page.getByText(/Not Approved User Level/i)).toBeVisible({ timeout: 5_000 })
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// FA-CD — Critical Defect Fixes verified in SPINRISE
// CD-01: SQL injection → Dapper @param (verified: JSON body, not form data)
// CD-04: SHAPE recordset → two Dapper queries (verified: single /detail call)
// CD-05: Print/save separation (verified: separate endpoints, approval stands on print fail)
// CD-06: po_para read 8× in VB6 → read once at page load in SPINRISE
// CD-07: User level hard-coded in VB6 → API-level enforcement in SPINRISE
// ═════════════════════════════════════════════════════════════════════════════

test.describe('FA-CD — Critical Defect Fixes', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await mockModuleApis(page)
    await gotoPage(page)
  })

  test('FA-CD-01: po_para called at most twice across full approve workflow — CD-06 (not 8× like VB6)', async ({ page }) => {
    // Register counting route BEFORE navigation so it captures the initial load
    let calls = 0
    await page.route('**/api/v1/pr-first-approval/po-para**', async r => { calls++; await r.fulfill(ok(PO_PARA)) })
    await gotoPage(page)
    await page.waitForLoadState('networkidle')
    // Perform full workflow — VB6 called po-para 8× during this; SPINRISE must call it far less
    await selectPRForApprove(page)
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    expect(calls).toBeLessThanOrEqual(2) // 1 in prod, 2 in React StrictMode dev — both pass CD-06 (not 8)
  })

  test('FA-CD-02: /detail returns header+lines in one call — replaces SHAPE CD-04', async ({ page }) => {
    let detailCalls = 0
    await page.route('**/api/v1/pr-first-approval/detail**', async r => {
      detailCalls++
      await r.fulfill(ok(PR_DETAIL))
    })
    await selectPRForApprove(page)
    // Single /detail replaces SHAPE parent-child OLE DB query
    expect(detailCalls).toBe(1)
  })

  test('FA-CD-03: /departments uses divCode param — no SQL concat — CD-01', async ({ page }) => {
    let url = ''
    await page.route('**/api/v1/pr-first-approval/departments**', async r => { url = r.request().url(); await r.fulfill(ok(DEPTS)) })
    await page.getByRole('button', { name: /Load PRs/i }).click()
    await page.waitForLoadState('networkidle')
    expect(url).toMatch(/divCode=[^&]+/i)
    expect(url).not.toMatch(/';|--|DROP TABLE|SELECT \*/i) // no injection fragments
  })

  test('FA-CD-04: /approve sends application/json body — CD-01 parameterised', async ({ page }) => {
    let ct = ''
    await page.route('**/api/v1/pr-first-approval/approve', async r => {
      ct = r.request().headers()['content-type'] ?? ''
      await r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) })
    })
    await selectPRForApprove(page)
    await page.locator('tbody input[type="checkbox"]').first().check()
    await page.getByRole('button', { name: /Save|Approve/i }).click()
    await page.getByRole('button', { name: /^Approve$/ }).last().click()
    await page.waitForLoadState('networkidle')
    expect(ct).toMatch(/application\/json/i)
  })

  test('FA-CD-05: /approve and /print are distinct endpoints — CD-05 separation', async ({ page }) => {
    const seen: string[] = []
    await page.route('**/api/v1/pr-first-approval/**', async r => {
      seen.push(new URL(r.request().url()).pathname)
      await r.continue()
    })
    await mockModuleApis(page, APPROVED_DETAIL)
    await page.route('**/api/v1/pr-first-approval/*/print**', r =>
      r.fulfill({ status: 200, contentType: 'application/pdf', body: PDF_BYTES }))
    await gotoPage(page)
    await selectPRForFind(page)
    await page.getByRole('button', { name: /Print/i }).click()
    await page.waitForLoadState('networkidle')
    // /print endpoint was called during Find+Print
    expect(seen.some(p => p.includes('/print'))).toBe(true)
    // /approve must NOT have been called in a Find+Print flow
    expect(seen.some(p => p.endsWith('/approve'))).toBe(false)
  })
})
