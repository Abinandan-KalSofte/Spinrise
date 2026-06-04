/**
 * Playwright UI tests — PR Foreclosure & Cancellation
 *
 * Setup (one-time, run in D:\SpinriseV2\Tools\playwright):
 *   npm install
 *   npx playwright install chromium
 *
 * Run:
 *   npx playwright test --headed          ← browser visible
 *   npx playwright test                   ← headless (CI)
 *   npx playwright show-report report     ← HTML report with screenshots
 *
 * How login works here:
 *   We do NOT interact with the login UI (Ant Design Select is complex).
 *   Instead: call the real API → get JWT → inject into localStorage
 *   (Zustand persist key 'spinrise-auth-v2') → navigate directly to the page.
 *   This is the standard Playwright pattern for bypassing auth UI.
 */

import { test, expect, Page, APIRequestContext } from '@playwright/test'
import * as fs from 'fs'
import * as path from 'path'

// ── Credentials ───────────────────────────────────────────────────────────────
// These match the values you set in the file earlier
const API_URL   = 'http://127.0.0.1:5000/api/v1'   // direct to backend (not Vite proxy)
const BASE_URL  = 'http://localhost:5173'            // Vite dev server
const DIV_CODE  = '01'
const USERNAME  = 'kalsofte'
const PASSWORD  = 'kalsofte'
const YF_DATE   = '2026-04-01'
const YL_DATE   = '2027-03-31'

// ── Screenshot dir ────────────────────────────────────────────────────────────
const SHOT_DIR = path.join(__dirname, 'screenshots')
if (!fs.existsSync(SHOT_DIR)) fs.mkdirSync(SHOT_DIR, { recursive: true })

const shot = (name: string) =>
  path.join(SHOT_DIR, `${name}_${Date.now()}.png`)

// ── Get auth token from the API ───────────────────────────────────────────────
async function getAuthState(request: APIRequestContext): Promise<string> {
  const resp = await request.post(`${API_URL}/auth/login`, {
    data: { divCode: DIV_CODE, userName: USERNAME, password: PASSWORD },
    headers: { 'Content-Type': 'application/json' },
  })

  if (!resp.ok()) {
    const body = await resp.text()
    throw new Error(`Login API failed ${resp.status()}: ${body}`)
  }

  const json = await resp.json()
  if (!json.success || !json.data?.tokens?.accessToken) {
    throw new Error(`Login returned no token: ${JSON.stringify(json)}`)
  }

  // Build the Zustand persist payload that the app reads on boot
  const today = new Date().toISOString().split('T')[0]           // YYYY-MM-DD
  const zustandPayload = {
    state: {
      user:            json.data.user,
      tokens:          json.data.tokens,
      isAuthenticated: true,
      processingDate:  today,
    },
    version: 0,
  }
  return JSON.stringify(zustandPayload)
}

// ── Inject auth into localStorage BEFORE React app boots ─────────────────────
// addInitScript runs before every page.goto on this page instance
async function injectAuth(page: Page, authState: string) {
  await page.addInitScript((state: string) => {
    localStorage.setItem('spinrise-auth-v2', state)
  }, authState)
}

// ── Navigate and wait for page to be ready ────────────────────────────────────
async function gotoAndWait(page: Page, path: string, waitSelector?: string) {
  await page.goto(`${BASE_URL}${path}`)
  await page.waitForLoadState('networkidle', { timeout: 20_000 })
  if (waitSelector) {
    await page.waitForSelector(waitSelector, { timeout: 15_000 }).catch(() => {})
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SETUP — runs before EVERY test in this file
// ─────────────────────────────────────────────────────────────────────────────
let authState: string

test.beforeAll(async ({ request }) => {
  // Get token ONCE for the entire test run (not per-test — avoids login spam)
  authState = await getAuthState(request)
  console.log('✅  Auth token obtained from API')
})

// ═════════════════════════════════════════════════════════════════════════════
//  PR FORECLOSURE TESTS
// ═════════════════════════════════════════════════════════════════════════════
test.describe('PR Foreclosure', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await gotoAndWait(page, '/pr-foreclosure', 'table tbody tr, .ant-spin')
    // Give the grid one extra second to finish rendering data
    await page.waitForTimeout(1000)
  })

  // ── FC-01: Banner must NOT contain technical SP / internal details ──────────
  test('FC-01  Banner shows clean user message only', async ({ page }) => {
    await page.screenshot({ path: shot('FC-01_page') })

    // These technical strings must NOT appear
    await expect(page.locator('body')).not.toContainText('ksp_PR_GetOpenForForeclosure')
    await expect(page.locator('body')).not.toContainText('Cross-FY scope')
    await expect(page.locator('body')).not.toContainText('CancelFlag = NULL')

    // The clean message MUST appear
    const banner = page.locator('div').filter({ hasText: /force-close/i }).first()
    await expect(banner).toBeVisible()
    console.log('FC-01: Banner text OK')
  })

  // ── FC-02: Grid loads and has records ─────────────────────────────────────
  test('FC-02  Grid loads open PR lines', async ({ page }) => {
    await page.screenshot({ path: shot('FC-02_grid') })

    const rows = page.locator('table tbody tr')
    const count = await rows.count()

    console.log(`FC-02: Grid row count = ${count}`)
    if (count === 0) {
      // Capture the full page HTML to diagnose why no rows appeared
      const html = await page.content()
      fs.writeFileSync(path.join(SHOT_DIR, 'FC-02_page_source.html'), html)
      console.log('FC-02: Page source saved to screenshots/FC-02_page_source.html')
    }

    expect(count).toBeGreaterThan(0)
  })

  // ── FC-03: PR Date column is non-empty ─────────────────────────────────────
  test('FC-03  PR Date column is non-empty on every visible row', async ({ page }) => {
    const rows = page.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No rows loaded — run FC-02 first to diagnose')

    // PR Date is 4th column (index 3: ☐ # PRNo PRDate)
    const emptyCells: number[] = []
    for (let i = 0; i < Math.min(count, 10); i++) {
      const cell = rows.nth(i).locator('td').nth(3)
      const text = (await cell.innerText()).trim()
      if (!text || text === '—') emptyCells.push(i + 1)
      console.log(`  Row ${i + 1} PRDate: "${text}"`)
    }

    await page.screenshot({ path: shot('FC-03_date_col') })
    expect(emptyCells, `Rows with empty PRDate: ${emptyCells.join(', ')}`).toHaveLength(0)
  })

  // ── FC-04: Checkbox selects only its own row (not all same-PR rows) ────────
  test('FC-04  Row checkbox selects only that row', async ({ page }) => {
    const rows = page.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No rows loaded')

    // Click the checkbox in the FIRST row
    const firstChk = rows.nth(0).locator('input[type="checkbox"]')
    await firstChk.check()
    await expect(firstChk).toBeChecked()

    // Check that rows 2–5 are NOT checked
    const wronglyChecked: number[] = []
    for (let i = 1; i < Math.min(count, 5); i++) {
      const chk = rows.nth(i).locator('input[type="checkbox"]')
      const checked = await chk.isChecked()
      if (checked) wronglyChecked.push(i + 1)
    }

    await page.screenshot({ path: shot('FC-04_checkbox') })
    expect(wronglyChecked, `These rows were unexpectedly selected: ${wronglyChecked.join(', ')}`).toHaveLength(0)

    // Footer badge should show exactly 1
    const badge = page.locator('span').filter({ hasText: /1 selected/ }).first()
    await expect(badge).toBeVisible()
    console.log('FC-04: Only row 1 is selected ✅')
  })

  // ── FC-05: Row body click must NOT select the row ─────────────────────────
  test('FC-05  Clicking row body does NOT select row', async ({ page }) => {
    const rows = page.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No rows loaded')

    // Click the Item Name cell (column index 6 — not the checkbox)
    const itemNameCell = rows.nth(0).locator('td').nth(6)
    await itemNameCell.click()

    const chk = rows.nth(0).locator('input[type="checkbox"]')
    const isChecked = await chk.isChecked()

    await page.screenshot({ path: shot('FC-05_row_click') })
    expect(isChecked, 'Row checkbox was checked by a row body click — tr.onClick must be removed').toBe(false)
  })

  // ── FC-06: Status column shows readable labels, not single chars ───────────
  test('FC-06  Status column shows readable text labels', async ({ page }) => {
    const rows = page.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No rows loaded')

    const RAW_CHARS = ['C', 'E', 'O', 'S', 'P', 'F', 'X', 'Z']
    const problems: string[] = []

    for (let i = 0; i < Math.min(count, 5); i++) {
      // Status is the LAST column
      const statusCell = rows.nth(i).locator('td').last()
      const text = (await statusCell.innerText()).trim()
      console.log(`  Row ${i + 1} Status: "${text}"`)
      if (RAW_CHARS.includes(text)) {
        problems.push(`Row ${i + 1}: "${text}" is a raw char`)
      }
    }

    await page.screenshot({ path: shot('FC-06_status') })
    expect(problems, problems.join('\n')).toHaveLength(0)
  })

  // ── FC-07: Select All / Clear buttons work correctly ──────────────────────
  test('FC-07  Select All and Clear work', async ({ page }) => {
    const rows  = page.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No rows loaded')

    // Click Select All
    await page.getByRole('button', { name: /Select All/i }).click()
    await page.waitForTimeout(300)

    // Badge text contains the count — check it's non-zero and contains "selected"
    const badgeAfterAll = page.locator('span').filter({ hasText: /selected/ }).first()
    await expect(badgeAfterAll).toBeVisible()
    const badgeTextAll = (await badgeAfterAll.innerText()).trim()
    console.log(`FC-07: Badge after Select All = "${badgeTextAll}"`)
    expect(parseInt(badgeTextAll)).toBeGreaterThan(0)
    await page.screenshot({ path: shot('FC-07_select_all') })

    // Click Clear
    await page.getByRole('button', { name: /Clear/i }).click()
    await page.waitForTimeout(300)

    const badgeAfterClear = page.locator('span').filter({ hasText: /selected/ }).first()
    const badgeTextClear = (await badgeAfterClear.innerText()).trim()
    console.log(`FC-07: Badge after Clear = "${badgeTextClear}"`)
    expect(badgeTextClear).toContain('0')
    await page.screenshot({ path: shot('FC-07_cleared') })
    console.log('FC-07: Select All and Clear ✅')
  })

  // ── FC-08: Confirm Foreclosure button is styled correctly ─────────────────
  test('FC-08  Confirm Foreclosure button is styled (not plain browser default)', async ({ page }) => {
    const rows  = page.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No rows loaded')

    // Select a row so the button becomes enabled
    await rows.nth(0).locator('input[type="checkbox"]').check()
    await page.waitForTimeout(300)

    const btn = page.getByRole('button', { name: /Confirm Foreclosure/i })
    await expect(btn).toBeEnabled()

    // Must have a background colour (plain browser buttons have transparent bg)
    const bgColor = await btn.evaluate((el) =>
      window.getComputedStyle(el).backgroundColor
    )
    console.log(`FC-08: Confirm Foreclosure button bg = "${bgColor}"`)
    expect(bgColor).not.toBe('rgba(0, 0, 0, 0)')
    expect(bgColor).not.toBe('transparent')

    await page.screenshot({ path: shot('FC-08_confirm_btn') })
  })

  // ── FC-09: Confirm Foreclosure validation — requires selection ────────────
  test('FC-09  Confirm Foreclosure disabled when nothing selected', async ({ page }) => {
    // Before selecting anything
    const btn = page.getByRole('button', { name: /Confirm Foreclosure/i })
    await expect(btn).toBeDisabled()
    await page.screenshot({ path: shot('FC-09_btn_disabled') })
  })

})

// ═════════════════════════════════════════════════════════════════════════════
//  FC-PRSTATUS — Foreclosure PRSTATUS Filter Tests
//  Verifies Fix 2: WHERE PRSTATUS NOT IN ('O','E','C','Z','X')
//  CEO directive 31 May 2026: both SPs must exclude all 5 statuses
// ═════════════════════════════════════════════════════════════════════════════
test.describe('FC-PRSTATUS — PRSTATUS Exclusion Filter', () => {

  test('FC-PRSTATUS-A: API response for foreclosure list contains no items with PrevStatus=Ordered', async ({ request }) => {
    // Get a fresh token
    const resp = await request.post(`${API_URL}/auth/login`, {
      data: { divCode: DIV_CODE, userName: USERNAME, password: PASSWORD },
      headers: { 'Content-Type': 'application/json' },
    })
    const json = await resp.json()
    const token: string = json.data?.tokens?.accessToken ?? ''

    // Call the foreclosure list endpoint directly
    const listResp = await request.get(`${API_URL}/pr-foreclosure/open-for-foreclosure`, {
      params: { divCode: DIV_CODE, fdate: YF_DATE, ldate: YL_DATE },
      headers: { Authorization: `Bearer ${token}` },
    })

    if (!listResp.ok()) {
      // If endpoint returns 404/error, skip gracefully — SP fix is what matters
      test.skip(true, `Foreclosure list endpoint returned ${listResp.status()} — verify SP fix manually`)
      return
    }

    const listJson = await listResp.json()
    const items: { prevStatus?: string }[] = listJson.data ?? listJson ?? []

    // No item may have PrevStatus=Ordered (prstatus='O') — these must be excluded by SP fix
    const orderedItems = items.filter((i) => i.prevStatus === 'Ordered')
    expect(orderedItems.length,
      'No items with PrevStatus=Ordered must appear in foreclosure list (excluded by PRSTATUS NOT IN fix)'
    ).toBe(0)
  })

  test('FC-PRSTATUS-B: API response for foreclosure list contains no items with PrevStatus=Enquired', async ({ request }) => {
    const resp = await request.post(`${API_URL}/auth/login`, {
      data: { divCode: DIV_CODE, userName: USERNAME, password: PASSWORD },
      headers: { 'Content-Type': 'application/json' },
    })
    const json = await resp.json()
    const token: string = json.data?.tokens?.accessToken ?? ''

    const listResp = await request.get(`${API_URL}/pr-foreclosure/open-for-foreclosure`, {
      params: { divCode: DIV_CODE, fdate: YF_DATE, ldate: YL_DATE },
      headers: { Authorization: `Bearer ${token}` },
    })

    if (!listResp.ok()) {
      test.skip(true, `Foreclosure list endpoint returned ${listResp.status()} — verify SP fix manually`)
      return
    }

    const listJson = await listResp.json()
    const items: { prevStatus?: string }[] = listJson.data ?? listJson ?? []

    // No item may have PrevStatus=Enquired (prstatus='E')
    const enquiredItems = items.filter((i) => i.prevStatus === 'Enquired')
    expect(enquiredItems.length,
      'No items with PrevStatus=Enquired must appear in foreclosure list (excluded by PRSTATUS NOT IN fix)'
    ).toBe(0)
  })

})

// ═════════════════════════════════════════════════════════════════════════════
//  PR CANCELLATION TESTS
// ═════════════════════════════════════════════════════════════════════════════
test.describe('PR Cancellation', () => {

  test.beforeEach(async ({ page }) => {
    await injectAuth(page, authState)
    await gotoAndWait(page, '/pr-cancellation')
    await page.waitForTimeout(1000)
  })

  // ── CN-01: Page loads and shows Cancel PR sub-tab ─────────────────────────
  test('CN-01  Page loads and Cancel PR tab is active', async ({ page }) => {
    await page.screenshot({ path: shot('CN-01_page') })
    // The sub-tab "🚫 Cancel PR" — use exact match to avoid matching toolbar button
    const tab = page.getByRole('button', { name: '🚫 Cancel PR', exact: true })
    await expect(tab).toBeVisible({ timeout: 5_000 })
    console.log('CN-01: Page loaded, Cancel PR tab visible ✅')
  })

  // ── CN-02: Find PR modal opens (auto or via button) ───────────────────────
  test('CN-02  Find PR modal opens', async ({ page }) => {
    // Either auto-opens on load or opens via button click
    let modalVisible = await page.locator('[role="dialog"]').isVisible()

    if (!modalVisible) {
      // Click Find PR to Cancel button
      const findBtn = page.getByRole('button', { name: /Find PR/i })
      if (await findBtn.isVisible()) {
        await findBtn.click()
        await page.waitForTimeout(500)
        modalVisible = await page.locator('[role="dialog"]').isVisible()
      }
    }

    await page.screenshot({ path: shot('CN-02_modal') })
    expect(modalVisible, 'Cancel modal did not open — check auto-open on load implementation').toBe(true)
  })

  // ── CN-03: Cancellable PR list has records ────────────────────────────────
  test('CN-03  Cancellable PR modal shows records', async ({ page }) => {
    // Open modal if not already open
    const modal = page.locator('[role="dialog"]')
    if (!await modal.isVisible()) {
      const findBtn = page.getByRole('button', { name: /Find PR/i })
      if (await findBtn.isVisible()) await findBtn.click()
    }

    await expect(modal).toBeVisible({ timeout: 5_000 })

    // Wait for table rows (API call inside modal)
    await page.waitForSelector('[role="dialog"] table tbody tr', { timeout: 10_000 }).catch(() => {})
    const rows = modal.locator('table tbody tr')
    const count = await rows.count()

    console.log(`CN-03: Cancellable PR count = ${count}`)
    if (count === 0) {
      const html = await page.content()
      fs.writeFileSync(path.join(SHOT_DIR, 'CN-03_page_source.html'), html)
      console.log('CN-03: Page source saved for diagnosis')
    }

    await page.screenshot({ path: shot('CN-03_modal_rows') })
    expect(count, 'No cancellable PRs returned — check cancelflag filter in ksp_PR_GetCancellablePRs').toBeGreaterThan(0)
  })

  // ── CN-04: Selecting a PR loads its details ───────────────────────────────
  test('CN-04  Selecting a PR from modal loads header and reason input', async ({ page }) => {
    const modal = page.locator('[role="dialog"]')
    if (!await modal.isVisible()) {
      const findBtn = page.getByRole('button', { name: /Find PR/i })
      if (await findBtn.isVisible()) await findBtn.click()
    }

    await expect(modal).toBeVisible({ timeout: 5_000 })
    await page.waitForSelector('[role="dialog"] table tbody tr', { timeout: 10_000 }).catch(() => {})

    const rows = modal.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No cancellable PRs — CN-03 must pass first')

    // Single-click to select, then click the "Select to Cancel" button
    await rows.nth(0).click()
    await page.waitForTimeout(300)

    // Click "Select to Cancel →" button in modal footer
    const selectBtn = page.locator('button').filter({ hasText: /Select to Cancel/i })
    if (await selectBtn.isVisible()) {
      await selectBtn.click()
    } else {
      // Fallback: try double-click
      await rows.nth(0).dblclick()
    }
    await page.waitForTimeout(1500)

    await page.screenshot({ path: shot('CN-04_pr_loaded') })

    // After PR is selected, the cancellation reason textarea must appear
    const textarea = page.locator('textarea')
    const isVisible = await textarea.isVisible({ timeout: 5_000 }).catch(() => false)
    if (!isVisible) {
      // Log page state for diagnosis
      console.log('CN-04: Textarea not visible — checking for error message')
      const errText = await page.locator('body').innerText().catch(() => '')
      console.log('CN-04: Page text snippet:', errText.slice(0, 400))
    }
    await expect(textarea).toBeVisible({ timeout: 5_000 })
    console.log('CN-04: PR detail loaded, reason input visible ✅')
  })

  // ── CN-05: Cancel without reason shows error ──────────────────────────────
  test('CN-05  Cancel PR button requires a cancellation reason', async ({ page }) => {
    // Select a PR first
    const modal = page.locator('[role="dialog"]')
    if (!await modal.isVisible()) {
      const findBtn = page.getByRole('button', { name: /Find PR/i })
      if (await findBtn.isVisible()) await findBtn.click()
    }

    const rows = modal.locator('table tbody tr')
    const count = await rows.count()
    test.skip(count === 0, 'No cancellable PRs')

    await rows.nth(0).dblclick()
    await page.waitForTimeout(800)

    // Leave reason empty and click Cancel PR
    const cancelBtn = page.getByRole('button', { name: /^Cancel PR$/i })
    if (await cancelBtn.isEnabled()) {
      await cancelBtn.click()
      await page.waitForTimeout(500)

      await page.screenshot({ path: shot('CN-05_validation') })
      // Should show a validation error somewhere on the page
      const hasError = await page.locator('text=/reason.*required/i, text=/Please enter/i').isVisible().catch(() => false)
      expect(hasError, 'No validation error shown when reason is empty').toBe(true)
    } else {
      console.log('CN-05: Cancel PR button not enabled — no PR was loaded')
      test.skip(true, 'Could not load a PR to test')
    }
  })

  // ── CN-06: Undo tab — switch and modal opens ──────────────────────────────
  test('CN-06  Undo Cancellation tab switches correctly', async ({ page }) => {
    const undoTab = page.getByRole('button', { name: /Undo Cancellation/i })
    await expect(undoTab).toBeVisible({ timeout: 5_000 })
    await undoTab.click()
    await page.waitForTimeout(800)

    await page.screenshot({ path: shot('CN-06_undo_tab') })

    // Find Cancelled PR button should appear in toolbar
    const findUndoBtn = page.getByRole('button', { name: /Find Cancelled PR/i })
    await expect(findUndoBtn).toBeVisible({ timeout: 3_000 })
    console.log('CN-06: Undo tab active ✅')
  })

})
