/**
 * PoTransferPage.ts — Page Object Model for PR→PO Transfer screen
 * FSD v3.1 | ksp_PO_* stored procedures | JAT database
 *
 * Toolbar labels (from PoToolbar.tsx):
 *   "New PO" (F1) | "Find" (F2) | "Delete" (F3)
 *   "Save PO" / "Confirm Delete" | "Cancel" (F6) | "Print" (F7)
 *   Nav buttons: icon-only with title="First/Previous/Next/Last record"
 */
import { type Page, type Locator, expect } from '@playwright/test'

export class PoTransferPage {
  readonly page: Page

  // ── Toolbar buttons ──────────────────────────────────────────────────────────
  readonly btnAdd:    Locator   // "New PO"
  readonly btnSave:   Locator   // "Save PO" (ADD) / "Confirm Delete" (DELETE)
  readonly btnDelete: Locator   // "Delete"
  readonly btnCancel: Locator   // "Cancel"
  readonly btnPrint:  Locator   // "Print"
  readonly btnFirst:  Locator   // icon-only, title="First record"
  readonly btnPrev:   Locator   // icon-only, title="Previous record"
  readonly btnNext:   Locator   // icon-only, title="Next record"
  readonly btnLast:   Locator   // icon-only, title="Last record"

  // ── Doc Band (read-only display) ────────────────────────────────────────────
  readonly poNoDisplay:    Locator
  readonly poValueDisplay: Locator

  // ── Order Details tab fields ─────────────────────────────────────────────────
  readonly poDateInput:     Locator
  readonly orderTypeSelect: Locator
  readonly supplierSelect:  Locator
  readonly gstinField:      Locator
  readonly gstStateField:   Locator
  readonly currencyInput:   Locator
  readonly remarksInput:    Locator

  // ── Line grid ───────────────────────────────────────────────────────────────
  readonly addPrLinesBtn: Locator
  readonly lineGrid:      Locator

  // ── PR Picker modal ─────────────────────────────────────────────────────────
  readonly prPickerModal:   Locator
  readonly prPickerConfirm: Locator

  // ── Delete modal ─────────────────────────────────────────────────────────────
  readonly deleteModal:       Locator
  readonly deleteReasonInput: Locator
  readonly deleteConfirmBtn:  Locator

  // ── Notification / toast ─────────────────────────────────────────────────────
  readonly successNotif: Locator
  readonly errorNotif:   Locator
  readonly warningNotif: Locator

  constructor(page: Page) {
    this.page = page

    // Toolbar: match on label text inside the button span (kbd shortcut text is separate)
    this.btnAdd    = page.locator('button').filter({ hasText: /New PO/ }).first()
    this.btnSave   = page.locator('button').filter({ hasText: /Save PO|Confirm Delete/ }).first()
    this.btnDelete = page.locator('button').filter({ hasText: /^Delete/ }).first()
    this.btnCancel = page.locator('button').filter({ hasText: /^Cancel/ }).first()
    this.btnPrint  = page.locator('button').filter({ hasText: /^Print/ }).first()

    // Nav buttons are icon-only — located by their title attribute
    this.btnFirst = page.locator('button[title="First record"]')
    this.btnPrev  = page.locator('button[title="Previous record"]')
    this.btnNext  = page.locator('button[title="Next record"]')
    this.btnLast  = page.locator('button[title="Last record"]')

    this.poNoDisplay    = page.locator('[data-testid="doc-band-po-no"], .po-doc-band .po-no')
    this.poValueDisplay = page.locator('[data-testid="kpi-order-value"], .kpi-order-value')

    this.poDateInput     = page.locator('#poDate')
    this.orderTypeSelect = page.locator('#orderType')
    this.supplierSelect  = page.locator('#supplier')
    this.gstinField      = page.locator('#gstin')
    this.gstStateField   = page.locator('#gstState')
    this.currencyInput   = page.locator('#currency')
    this.remarksInput    = page.locator('#remarks')

    this.addPrLinesBtn = page.getByRole('button', { name: /Add PR Lines|Pick PR Lines/i })
    this.lineGrid      = page.locator('[data-testid="po-line-grid"], .po-line-grid')

    this.prPickerModal   = page.locator('.ant-modal').filter({ hasText: /Eligible PR Lines|PR Picker/i })
    this.prPickerConfirm = this.prPickerModal.getByRole('button', { name: /Add Selected|Confirm/i })

    this.deleteModal       = page.locator('.ant-modal').filter({ hasText: /Delete Purchase Order/i })
    this.deleteReasonInput = this.deleteModal.locator('input[type="text"], textarea').first()
    this.deleteConfirmBtn  = this.deleteModal.getByRole('button', { name: /Confirm Delete|Delete/i })

    this.successNotif = page.locator('.ant-notification-notice').filter({ hasText: /success|saved|created/i }).first()
    this.errorNotif   = page.locator('.ant-notification-notice').filter({ hasText: /error|failed/i }).first()
    this.warningNotif = page.locator('.ant-notification-notice').filter({ hasText: /warning|required|cannot|invalid/i }).first()
  }

  async goto() {
    await this.page.goto('/po/transfer')
    await this.page.waitForLoadState('networkidle')
    // "New PO" button is enabled in VIEW mode once lookups finish loading
    await expect(this.btnAdd).toBeEnabled({ timeout: 15_000 })
  }

  async clickAdd() {
    await this.btnAdd.click()
    await this.page.waitForTimeout(300)
  }

  async selectOrderType(code: string) {
    await this.orderTypeSelect.click()
    await this.page.waitForTimeout(200)
    await this.orderTypeSelect.pressSequentially(code, { delay: 50 })
    await this.page.waitForTimeout(200)
    await this.page.locator('.ant-select-item-option').first().click()
  }

  async selectSupplier(code: string) {
    await this.supplierSelect.click()
    await this.page.waitForTimeout(200)
    await this.supplierSelect.pressSequentially(code, { delay: 50 })
    await this.page.waitForTimeout(500)
    await this.page.locator('.ant-select-item-option').first().click()
    await this.page.waitForTimeout(500) // wait for GST routing call
  }

  async setPoDate(dateStr: string) {
    await this.poDateInput.fill('')
    await this.poDateInput.fill(dateStr)
    await this.page.keyboard.press('Tab')
  }

  /** Click a header tab by its label (uses role="tab" for AntD Tabs) */
  async clickTab(tabName: string) {
    const tab = this.page.getByRole('tab', { name: tabName })
    if (await tab.isVisible().catch(() => false)) {
      await tab.click()
    } else {
      // Fallback: some tab implementations use buttons or divs
      await this.page.locator(`[role="tab"]:has-text("${tabName}"), button:has-text("${tabName}")`).first().click()
    }
    await this.page.waitForTimeout(200)
  }

  async pickFirstPrLine() {
    await this.addPrLinesBtn.click()
    await expect(this.prPickerModal).toBeVisible({ timeout: 10_000 })
    await this.prPickerModal.locator('.ant-checkbox-input').first().click()
    await this.prPickerConfirm.click()
    await expect(this.prPickerModal).toBeHidden({ timeout: 8_000 })
    await this.page.waitForTimeout(300)
  }

  async setLineRate(rowIndex: number, rate: string) {
    const rateCell = this.lineGrid.locator('tr').nth(rowIndex).locator('input[type="number"]').first()
    await rateCell.fill(rate)
    await this.page.keyboard.press('Tab')
  }

  async clickSave() {
    await this.btnSave.click()
    await this.page.waitForTimeout(500)
  }

  async clickDelete() {
    await this.btnDelete.click()
    await expect(this.deleteModal).toBeVisible({ timeout: 5_000 })
  }

  async fillDeleteReason(reason: string) {
    await this.deleteReasonInput.fill(reason)
  }

  async confirmDelete() {
    await this.deleteConfirmBtn.click()
    await this.page.waitForTimeout(500)
  }

  async getPoNoText(): Promise<string> {
    try {
      return (await this.poNoDisplay.textContent()) ?? ''
    } catch {
      return ''
    }
  }

  async waitForSuccess(timeout = 10_000): Promise<boolean> {
    try {
      await expect(this.successNotif).toBeVisible({ timeout })
      return true
    } catch {
      return false
    }
  }

  async getNotificationText(): Promise<string> {
    try {
      // Wait briefly for any notification to appear
      await this.page.waitForTimeout(800)
      const notif = this.page.locator('.ant-notification-notice, .ant-message-notice').first()
      return (await notif.textContent()) ?? ''
    } catch {
      return ''
    }
  }

  /** True when in VIEW mode: "New PO" is enabled and "Save PO" is disabled */
  async isViewMode(): Promise<boolean> {
    return this.btnSave.isDisabled().catch(() => true)
  }

  /** True when in ADD mode: "Save PO" is enabled */
  async isAddMode(): Promise<boolean> {
    return this.btnSave.isEnabled().catch(() => false)
  }
}
