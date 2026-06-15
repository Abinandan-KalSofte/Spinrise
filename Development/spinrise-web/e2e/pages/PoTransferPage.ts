/**
 * PoTransferPage.ts — Page Object Model for PR→PO Transfer screen
 * FSD v3.1 | ksp_PO_* stored procedures | JAT database
 *
 * Covers: ADD, VIEW, DELETE flows + all business rule validations.
 */
import { type Page, type Locator, expect } from '@playwright/test'

export class PoTransferPage {
  readonly page: Page

  // ── Toolbar buttons ──────────────────────────────────────────────────────────
  readonly btnAdd:    Locator
  readonly btnSave:   Locator
  readonly btnDelete: Locator
  readonly btnCancel: Locator
  readonly btnPrint:  Locator
  readonly btnFirst:  Locator
  readonly btnPrev:   Locator
  readonly btnNext:   Locator
  readonly btnLast:   Locator

  // ── Doc Band (read-only display) ────────────────────────────────────────────
  readonly poNoDisplay:    Locator
  readonly poValueDisplay: Locator

  // ── Order Details tab fields ─────────────────────────────────────────────────
  readonly poDateInput:    Locator
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

    this.btnAdd    = page.getByRole('button', { name: 'Add' }).first()
    this.btnSave   = page.getByRole('button', { name: 'Save' }).first()
    this.btnDelete = page.getByRole('button', { name: 'Delete' }).first()
    this.btnCancel = page.getByRole('button', { name: 'Cancel' }).first()
    this.btnPrint  = page.getByRole('button', { name: /Print/i }).first()
    this.btnFirst  = page.getByRole('button', { name: 'First' })
    this.btnPrev   = page.getByRole('button', { name: 'Prev' })
    this.btnNext   = page.getByRole('button', { name: 'Next' })
    this.btnLast   = page.getByRole('button', { name: 'Last' })

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
    // Wait for lookups to load
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
    await this.page.keyboard.press('ArrowDown')
    await this.page.keyboard.press('Enter')
  }

  async selectSupplier(code: string) {
    await this.supplierSelect.click()
    await this.page.waitForTimeout(200)
    await this.supplierSelect.pressSequentially(code, { delay: 50 })
    await this.page.waitForTimeout(500) // wait for supplier list to filter
    await this.page.keyboard.press('ArrowDown')
    await this.page.keyboard.press('Enter')
    await this.page.waitForTimeout(500) // wait for GST routing call
  }

  async setPoDate(dateStr: string) {
    await this.poDateInput.fill('')
    await this.poDateInput.fill(dateStr)
    await this.page.keyboard.press('Tab')
  }

  async clickTab(tabName: string) {
    await this.page.getByRole('button', { name: tabName }).click()
    await this.page.waitForTimeout(200)
  }

  async pickFirstPrLine() {
    await this.addPrLinesBtn.click()
    await expect(this.prPickerModal).toBeVisible({ timeout: 10_000 })
    // Select the first row checkbox
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
    // Wait for notification or for save to complete
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

  /** Returns the PO number text from the doc band (empty string if pre-save) */
  async getPoNoText(): Promise<string> {
    try {
      return (await this.poNoDisplay.textContent()) ?? ''
    } catch {
      return ''
    }
  }

  /** Returns true if a success notification appeared */
  async waitForSuccess(timeout = 10_000): Promise<boolean> {
    try {
      await expect(this.successNotif).toBeVisible({ timeout })
      return true
    } catch {
      return false
    }
  }

  /** Returns the first visible notification text */
  async getNotificationText(): Promise<string> {
    try {
      const notif = this.page.locator('.ant-notification-notice').first()
      return (await notif.textContent()) ?? ''
    } catch {
      return ''
    }
  }

  /** Returns true if the screen is in VIEW mode (Save button hidden/disabled) */
  async isViewMode(): Promise<boolean> {
    return !(await this.btnSave.isVisible().catch(() => false))
  }

  /** Returns true if the screen is in ADD mode (Save button visible) */
  async isAddMode(): Promise<boolean> {
    return this.btnSave.isVisible().catch(() => false)
  }
}
