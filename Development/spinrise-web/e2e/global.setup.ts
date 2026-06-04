/**
 * global.setup.ts
 * Runs once before all tests. Performs login and saves browser storage state
 * so every test starts already authenticated — no repeated logins.
 *
 * Required env vars (or fill TEST_* constants below):
 *   APP_URL       — base URL  (default: http://localhost:5173)
 *   TEST_DB       — company/database name visible in the dropdown
 *   TEST_DIVCODE  — division code
 *   TEST_USER     — user ID
 *   TEST_PASSWORD — password
 */
import { test as setup, expect } from '@playwright/test'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname  = path.dirname(__filename)

export const AUTH_STATE = path.join(__dirname, '.auth', 'state.json')

const DB       = process.env.TEST_DB       ?? 'JAT'
const DIVCODE  = process.env.TEST_DIVCODE  ?? '01'
const USER     = process.env.TEST_USER     ?? 'kalsofte'
const PASSWORD = process.env.TEST_PASSWORD ?? 'kalsofte'

setup('authenticate', async ({ page }) => {
  await page.goto('/login')

  // Wait for the API that populates the Company dropdown to complete
  await page.waitForLoadState('networkidle', { timeout: 20_000 })

  const submitBtn = page.getByRole('button', { name: 'Log In' })
  await expect(submitBtn).toBeVisible({ timeout: 10_000 })

  // ── Company (database) select ──────────────────────────────────────────────
  // AntD Form.Item name="dbName" → inner Select input has id="dbName".
  // Using keyboard navigation avoids AntD virtual-list viewport positioning issues.
  const companyInput = page.locator('#dbName')
  await expect(companyInput).toBeVisible({ timeout: 8_000 })
  await companyInput.click()
  await page.waitForTimeout(200)

  // pressSequentially fires key events React can observe; type to filter the list
  await companyInput.pressSequentially(DB, { delay: 50 })
  await page.waitForTimeout(300)

  // ArrowDown selects the first (filtered) option; Enter confirms — no portal click needed
  await page.keyboard.press('ArrowDown')
  await page.keyboard.press('Enter')
  await page.waitForTimeout(200)

  // ── Division select ────────────────────────────────────────────────────────
  // After selecting DB, loadDivisions fires an API call — wait for network idle
  await page.waitForLoadState('networkidle', { timeout: 10_000 })

  // AntD Form.Item name="divCode" → input id="divCode"
  const divInput = page.locator('#divCode')
  await expect(divInput).toBeEnabled({ timeout: 8_000 })
  await divInput.click()
  await page.waitForTimeout(200)

  // Division label is "{divCode} – {divName}"; typing the code filters to one entry
  await divInput.pressSequentially(DIVCODE, { delay: 50 })
  await page.waitForTimeout(300)

  await page.keyboard.press('ArrowDown')
  await page.keyboard.press('Enter')
  await page.waitForTimeout(200)

  // ── Credentials ────────────────────────────────────────────────────────────
  await page.getByPlaceholder('Enter your User ID').fill(USER)
  await page.getByPlaceholder('Enter your password').fill(PASSWORD)

  // ── Submit ─────────────────────────────────────────────────────────────────
  await submitBtn.click()
  await expect(page).toHaveURL(/dashboard/, { timeout: 15_000 })

  // Save auth state — all subsequent tests reuse this session
  await page.context().storageState({ path: AUTH_STATE })
})
