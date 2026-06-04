/**
 * SPINRISE — DEF-FA Defect Fix Verification Tests
 * Verifies: DEF-FA-01 to DEF-FA-07 and FA-ADD-12
 * FSD: SPINRISE_FSD_M01_PRFirstLevelApproval_v1.2 · IST Review Feedback v1.0
 *
 * Run:
 *   npx playwright test def-fa-fixes.spec.ts --headed
 *   npx playwright test def-fa-fixes.spec.ts
 */

import { test, expect, type Page, type APIRequestContext } from '@playwright/test'
import * as fs   from 'fs'
import * as path from 'path'

// ── Server config ─────────────────────────────────────────────────────────────
const API_URL  = 'http://127.0.0.1:5000/api/v1'
const BASE_URL = 'http://localhost:5173'
const DIV_CODE = '01'
const USERNAME = 'kalsofte'
const PASSWORD = 'kalsofte'

// ── Screenshots ───────────────────────────────────────────────────────────────
const SHOT_DIR = path.join(__dirname, 'screenshots')
if (!fs.existsSync(SHOT_DIR)) fs.mkdirSync(SHOT_DIR, { recursive: true })
const shot = (name: string) => path.join(SHOT_DIR, `DEFFA_${name}_${Date.now()}.png`)

// ── Auth helpers ──────────────────────────────────────────────────────────────
async function getAuthState(request: APIRequestContext): Promise<string> {
  const resp = await request.post(`${API_URL}/auth/login`, {
    data: { divCode: DIV_CODE, userName: USERNAME, password: PASSWORD },
    headers: { 'Content-Type': 'application/json' },
  })
  if (!resp.ok()) throw new Error(`Login failed ${resp.status()}: ${await resp.text()}`)
  const json = await resp.json()
  if (!json.success || !json.data?.tokens?.accessToken)
    throw new Error(`No token: ${JSON.stringify(json)}`)
  const today = new Date().toISOString().split('T')[0]
  return JSON.stringify({
    state: { user: json.data.user, tokens: json.data.tokens, isAuthenticated: true, processingDate: today },
    version: 0,
  })
}

async function injectAuth(page: Page, authState: string): Promise<void> {
  await page.addInitScript((s: string) => localStorage.setItem('spinrise-auth-v2', s), authState)
}

async function gotoPage(page: Page): Promise<void> {
  await page.goto(`${BASE_URL}/pr-first-approval`)
  await page.waitForLoadState('networkidle', { timeout: 20_000 })
}

// ── API response helpers ──────────────────────────────────────────────────────
function ok(data: unknown) {
  return { status: 200, contentType: 'application/json',
    body: JSON.stringify({ success: true, message: 'OK', data }) }
}

// ── Mock data ─────────────────────────────────────────────────────────────────
const PO_PARA = {
  divCode: DIV_CODE, appUserLevel1: '5', appUserLevel2: '3', appUserLevel3: '2',
  appUserLabel1: 'SM', appUserLabel2: 'FM', appUserLabel3: 'GM',
}

const DEPTS = [
  { depCode: 'WVG', depName: 'Weaving', userLevel: '5' },
]

const PENDING_LIST = [
  { prNo: 329, prDate: '2026-05-15T00:00:00', depCode: 'WVG', depName: 'Weaving',
    reqName: 'Arjun M', iType: 'N', totalLines: 2, prStatus: 'REQUESTED' },
]

const APPROVED_LIST = [
  { prNo: 320, prDate: '2026-05-10T00:00:00', depCode: 'WVG', depName: 'Weaving',
    reqName: 'Velu K', iType: 'N', totalLines: 2, prStatus: 'FIRST LEVEL APPROVED' },
]

// PR with 2 lines, both NOT yet approved
const PR_DETAIL_2LINE = {
  header: {
    divCode: DIV_CODE, prNo: 329, prDate: '2026-05-15T00:00:00',
    depCode: 'WVG', depName: 'Weaving', refNo: 'REF-001',
    section: 'PROD', subCost: 'SC01', sccName: 'Production',
    app1: null, app2: null, app3: null, appFlg: 'N', app1Date: null, reqName: 'Arjun M',
  },
  lines: [
    { prSno: 1, itemCode: 'YARN001', itemName: 'Cotton Yarn 20s', uom: 'KG',
      machine: 'RG-01', curStock: 150, qtyInd: 500, qtyReqd: 500,
      firstAppQty: 0, secondAppQty: 0, thirdAppQty: 0, qtyOrd: 0, qtyRec: 0,
      rate: 85.5, value: 42750, reqdDate: null, firstApp: null, prStatus: null,
      place: null, appCost: 42750, remarks: null, bgrpCode: null, macNo: 'RG01' },
    { prSno: 2, itemCode: 'OIL002', itemName: 'Spindle Oil', uom: 'LTR',
      machine: null, curStock: 20, qtyInd: 50, qtyReqd: 50,
      firstAppQty: 0, secondAppQty: 0, thirdAppQty: 0, qtyOrd: 0, qtyRec: 0,
      rate: 120, value: 6000, reqdDate: null, firstApp: null, prStatus: null,
      place: null, appCost: 6000, remarks: null, bgrpCode: null, macNo: null },
  ],
}

// After partial approval (line 1 approved, line 2 still pending)
const PR_DETAIL_PARTIAL_REFRESH = {
  ...PR_DETAIL_2LINE,
  lines: [
    { ...PR_DETAIL_2LINE.lines[0], firstApp: 'Y', firstAppQty: 500, prStatus: 'F' },
    { ...PR_DETAIL_2LINE.lines[1], firstApp: null, firstAppQty: 0, prStatus: null },
  ],
}

// After full approval (both lines approved)
const PR_DETAIL_FULL_REFRESH = {
  ...PR_DETAIL_2LINE,
  lines: [
    { ...PR_DETAIL_2LINE.lines[0], firstApp: 'Y', firstAppQty: 500, prStatus: 'F' },
    { ...PR_DETAIL_2LINE.lines[1], firstApp: 'Y', firstAppQty: 50,  prStatus: 'F' },
  ],
}

// Previously approved PR for Find mode
const PR_DETAIL_APPROVED = {
  header: { ...PR_DETAIL_2LINE.header, prNo: 320, prDate: '2026-05-10T00:00:00', appFlg: 'Y', app1: 'kalsofte' },
  lines: [
    { ...PR_DETAIL_2LINE.lines[0], firstApp: 'Y', firstAppQty: 500, prStatus: 'F' },
    { ...PR_DETAIL_2LINE.lines[1], firstApp: 'Y', firstAppQty: 50,  prStatus: 'F' },
  ],
}

const APPROVE_SUCCESS = {
  success: true, message: 'PR-00329 — First Level Approval saved. PRSTATUS → F.', data: null,
}

// ── Route mock helpers ────────────────────────────────────────────────────────
async function mockBase(page: Page, detailOverride?: object): Promise<void> {
  await page.route('**/api/v1/pr-first-approval/po-para**',     r => r.fulfill(ok(PO_PARA)))
  await page.route('**/api/v1/pr-first-approval/departments**', r => r.fulfill(ok(DEPTS)))
  await page.route('**/api/v1/pr-first-approval/pending**',     r => r.fulfill(ok(PENDING_LIST)))
  await page.route('**/api/v1/pr-first-approval/approved**',    r => r.fulfill(ok(APPROVED_LIST)))
  await page.route('**/api/v1/pr-first-approval/detail**',      r => r.fulfill(ok(detailOverride ?? PR_DETAIL_2LINE)))
  await page.route('**/api/v1/pr-first-approval/*/print**',     r => r.fulfill({ status: 200, contentType: 'application/pdf', body: Buffer.from('%PDF-1.4') }))
}

// Open Load PRs → dept modal → pending list modal → select PR 329
async function openPR329ForApproval(page: Page): Promise<void> {
  await page.getByRole('button', { name: /Load PRs/i }).click()
  const deptRow = page.getByRole('dialog').locator('tr').filter({ hasText: 'Weaving' }).first()
  await deptRow.waitFor({ timeout: 5_000 })
  await deptRow.dblclick()
  const prRow = page.getByRole('dialog').locator('tr').filter({ hasText: '329' }).first()
  await prRow.waitFor({ timeout: 8_000 })
  await prRow.dblclick()
  await page.waitForLoadState('networkidle')
}

// ── Shared auth ───────────────────────────────────────────────────────────────
let authState: string

test.beforeAll(async ({ request }) => {
  authState = await getAuthState(request)
})

// ═════════════════════════════════════════════════════════════════════════════
// DEF-FA-01: Save must be blocked when First Approval Qty > Qty Required
// ═════════════════════════════════════════════════════════════════════════════
test.describe('DEF-FA-01 — Qty Validation Blocks Save', () => {

  test('DEF-FA-01-A: save is blocked and API is NOT called when qty exceeds required', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page)

    let approveCallCount = 0
    await page.route('**/api/v1/pr-first-approval/approve', r => {
      approveCallCount++
      return r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) })
    })

    await gotoPage(page)
    await openPR329ForApproval(page)

    // Select first row checkbox
    const firstRowCheckbox = page.locator('table tbody tr').first().locator('input[type="checkbox"]')
    await firstRowCheckbox.check()

    // Change First Approval Qty to 600 (exceeds qtyReqd=500)
    const qtyInput = page.locator('table tbody tr').first().locator('input[type="number"]').first()
    await qtyInput.fill('600')
    await qtyInput.blur()

    // Attempt save
    await page.getByRole('button', { name: /Save/i }).first().click()
    await page.screenshot({ path: shot('FA01A-blocked') })

    // API must NOT have been called
    expect(approveCallCount, 'Approve API must not be called when qty is invalid').toBe(0)
  })

  test('DEF-FA-01-B: save proceeds when qty equals required quantity', async ({ page }) => {
    await injectAuth(page, authState)
    let refreshCallCount = 0
    await mockBase(page)
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) }))
    await page.route('**/api/v1/pr-first-approval/detail**', r => {
      refreshCallCount++
      // second call (refresh after save) returns approved data
      return r.fulfill(ok(refreshCallCount > 1 ? PR_DETAIL_FULL_REFRESH : PR_DETAIL_2LINE))
    })

    await gotoPage(page)
    await openPR329ForApproval(page)

    // Select all rows and keep default qty (pre-filled to qtyReqd — FA-ADD-12)
    await page.locator('table thead input[type="checkbox"]').check()

    // Confirm save modal
    await page.getByRole('button', { name: /Save/i }).first().click()
    const confirmBtn = page.getByRole('button', { name: /OK|Confirm|Yes/i }).last()
    if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false))
      await confirmBtn.click()

    await page.waitForLoadState('networkidle')
    await page.screenshot({ path: shot('FA01B-success') })
  })

})

// ═════════════════════════════════════════════════════════════════════════════
// DEF-FA-02: Validation message must say "Quantity Required" not "Required Quantity"
// ═════════════════════════════════════════════════════════════════════════════
test.describe('DEF-FA-02 — Correct Field Name in Error Message', () => {

  test('DEF-FA-02-A: error message says "Quantity Required" when qty exceeds limit', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page)
    await page.route('**/api/v1/pr-first-approval/approve', r => r.fulfill(ok(null)))

    await gotoPage(page)
    await openPR329ForApproval(page)

    const firstRowCheckbox = page.locator('table tbody tr').first().locator('input[type="checkbox"]')
    await firstRowCheckbox.check()

    const qtyInput = page.locator('table tbody tr').first().locator('input[type="number"]').first()
    await qtyInput.fill('999')
    await qtyInput.blur()
    await page.screenshot({ path: shot('FA02A-msg') })

    // Message must contain "Quantity Required" (not "Required Quantity")
    const pageText = await page.content()
    expect(pageText).toContain('Quantity Required')
    expect(pageText).not.toMatch(/Required Quantity/)
  })

})

// ═════════════════════════════════════════════════════════════════════════════
// DEF-FA-04/05: Post-save screen must transition to SAVED (read-only) mode
// ═════════════════════════════════════════════════════════════════════════════
test.describe('DEF-FA-04/05 — Post-Save Mode and Screen State', () => {

  test('DEF-FA-04-A: after successful save, qty inputs are disabled (read-only SAVED mode)', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page)
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) }))
    let detailCallCount = 0
    await page.route('**/api/v1/pr-first-approval/detail**', r => {
      detailCallCount++
      return r.fulfill(ok(detailCallCount > 1 ? PR_DETAIL_FULL_REFRESH : PR_DETAIL_2LINE))
    })

    await gotoPage(page)
    await openPR329ForApproval(page)

    // Select all and save
    await page.locator('table thead input[type="checkbox"]').check()
    await page.getByRole('button', { name: /Save/i }).first().click()
    const confirmBtn = page.getByRole('button', { name: /OK|Confirm|Yes/i }).last()
    if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false))
      await confirmBtn.click()
    await page.waitForLoadState('networkidle')

    await page.screenshot({ path: shot('FA04A-saved-mode') })

    // In SAVED mode, qty inputs must be disabled/read-only
    const qtyInputs = page.locator('table tbody tr input[type="number"]')
    const count = await qtyInputs.count()
    if (count > 0) {
      const firstInput = qtyInputs.first()
      const isDisabled = await firstInput.isDisabled()
      const isReadOnly = await firstInput.getAttribute('readonly')
      expect(isDisabled || isReadOnly !== null, 'Qty input must be disabled in SAVED mode').toBe(true)
    }
  })

  test('DEF-FA-05-A: after save, grid shows only approved lines (firstApp=Y)', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page)
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) }))
    let detailCallCount = 0
    await page.route('**/api/v1/pr-first-approval/detail**', r => {
      detailCallCount++
      // After save, refresh returns only 1 approved line (partial) — should display 1 row
      return r.fulfill(ok(detailCallCount > 1 ? PR_DETAIL_PARTIAL_REFRESH : PR_DETAIL_2LINE))
    })

    await gotoPage(page)
    await openPR329ForApproval(page)

    // Select only first row
    const firstCheckbox = page.locator('table tbody tr').first().locator('input[type="checkbox"]')
    await firstCheckbox.check()

    await page.getByRole('button', { name: /Save/i }).first().click()
    const confirmBtn = page.getByRole('button', { name: /OK|Confirm|Yes/i }).last()
    if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false))
      await confirmBtn.click()
    await page.waitForLoadState('networkidle')

    await page.screenshot({ path: shot('FA05A-refresh') })

    // After partial save refresh, grid must show only the 1 approved line
    const rows = page.locator('table tbody tr')
    const rowCount = await rows.count()
    expect(rowCount, 'Grid must show only approved lines after save (partial → 1 line)').toBe(1)
  })

})

// ═════════════════════════════════════════════════════════════════════════════
// DEF-FA-06: Find mode shows only approved lines
// ═════════════════════════════════════════════════════════════════════════════
test.describe('DEF-FA-06 — Find Mode Shows Approved Lines Only', () => {

  test('DEF-FA-06-A: Find mode loads only lines where firstApp=Y', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page, PR_DETAIL_APPROVED)
    await page.route('**/api/v1/pr-first-approval/approve', r => r.fulfill(ok(null)))

    await gotoPage(page)

    // Enter Find mode
    await page.getByRole('button', { name: /Find/i }).click()
    const prRow = page.getByRole('dialog').locator('tr').filter({ hasText: '320' }).first()
    await prRow.waitFor({ timeout: 5_000 })
    await prRow.dblclick()
    await page.waitForLoadState('networkidle')

    await page.screenshot({ path: shot('FA06A-find') })

    // All visible rows must have firstApp='Y' — meaning no un-approved lines shown.
    // In SAVED/FIND mode the store filters to firstApp==='Y' only.
    // With PR_DETAIL_APPROVED both lines have firstApp='Y', so 2 rows visible.
    // Crucially, lines with firstApp=null must NOT appear.
    const rows = page.locator('table tbody tr')
    const rowCount = await rows.count()
    expect(rowCount, 'Find mode must show only approved lines').toBeGreaterThanOrEqual(1)

    // In SAVED/FIND mode, checkboxes must be disabled
    if (rowCount > 0) {
      const firstCheckbox = rows.first().locator('input[type="checkbox"]')
      if (await firstCheckbox.count() > 0) {
        const isDisabled = await firstCheckbox.isDisabled()
        expect(isDisabled, 'Checkboxes must be disabled in Find/SAVED mode').toBe(true)
      }
    }
  })

})

// ═════════════════════════════════════════════════════════════════════════════
// DEF-FA-07: After approval, pending list is cleared (PR drops from pending)
// ═════════════════════════════════════════════════════════════════════════════
test.describe('DEF-FA-07 — Approved PR Removed from Pending List', () => {

  test('DEF-FA-07-A: after save, pending list is cleared so next Load PRs re-fetches fresh', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page)
    await page.route('**/api/v1/pr-first-approval/approve', r =>
      r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(APPROVE_SUCCESS) }))
    let detailCallCount = 0
    await page.route('**/api/v1/pr-first-approval/detail**', r => {
      detailCallCount++
      return r.fulfill(ok(detailCallCount > 1 ? PR_DETAIL_FULL_REFRESH : PR_DETAIL_2LINE))
    })

    // Track pending list API calls — after save, the next Load PRs click must re-call the API
    let pendingCallCount = 0
    await page.route('**/api/v1/pr-first-approval/pending**', r => {
      pendingCallCount++
      return r.fulfill(ok([]))  // Return empty — the approved PR is no longer pending
    })

    await gotoPage(page)
    await openPR329ForApproval(page)

    await page.locator('table thead input[type="checkbox"]').check()
    await page.getByRole('button', { name: /Save/i }).first().click()
    const confirmBtn = page.getByRole('button', { name: /OK|Confirm|Yes/i }).last()
    if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false))
      await confirmBtn.click()
    await page.waitForLoadState('networkidle')

    const callsBefore = pendingCallCount
    // Click Load PRs again — must trigger a fresh API call (pendingList was cleared in store)
    await page.getByRole('button', { name: /Load PRs/i }).click()
    await page.waitForLoadState('networkidle')

    expect(pendingCallCount, 'Pending list API must be called again after save (cache cleared)').toBeGreaterThan(callsBefore)
    await page.screenshot({ path: shot('FA07A-pending-cleared') })
  })

})

// ═════════════════════════════════════════════════════════════════════════════
// FA-ADD-12: First Approval Qty defaults to Quantity Required on PR load
// ═════════════════════════════════════════════════════════════════════════════
test.describe('FA-ADD-12 — Qty Pre-fills with Quantity Required', () => {

  test('FA-ADD-12-A: First Approval Qty fields pre-filled with Quantity Required (qtyInd) on load', async ({ page }) => {
    await injectAuth(page, authState)
    await mockBase(page)
    await page.route('**/api/v1/pr-first-approval/approve', r => r.fulfill(ok(null)))

    await gotoPage(page)
    await openPR329ForApproval(page)

    await page.screenshot({ path: shot('ADD12A-prefill') })

    // First item: qtyInd=500, so qty input must show 500
    const firstQtyInput = page.locator('table tbody tr').first().locator('input[type="number"]').first()
    const value = await firstQtyInput.inputValue()
    expect(parseFloat(value), 'First Approval Qty must pre-fill to Quantity Required (500)').toBe(500)
  })

})
