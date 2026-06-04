/**
 * AmendmentPage — Page Object for /pr-amendment
 * Encapsulates all selectors and interactions for the PR Amendment screen.
 */
import { Page, Locator, expect } from '@playwright/test'

export class AmendmentPage {
  readonly page: Page

  // Toolbar buttons
  readonly btnNew:    Locator
  readonly btnModify: Locator
  readonly btnDelete: Locator
  readonly btnFind:   Locator
  readonly btnSave:   Locator
  readonly btnCancel: Locator
  readonly btnPrint:  Locator

  // Nav buttons — toolbar uses title="First" etc. with symbol text (« ‹ › »)
  readonly btnFirst: Locator
  readonly btnPrev:  Locator
  readonly btnNext:  Locator
  readonly btnLast:  Locator

  // Header fields
  readonly fieldAmendReason: Locator
  readonly fieldRefNo:       Locator

  // Delete banner sub-mode buttons
  readonly btnDeleteAmendment: Locator
  readonly btnDeleteLine:      Locator

  // Line grid (main page table — last table when no modal is open)
  readonly lineGrid: Locator

  constructor(page: Page) {
    this.page = page

    // Toolbar buttons — use .first() to avoid strict-mode violation with the
    // disabled "Find" button that also appears inside PrAmendmentHeader.
    this.btnNew    = page.getByRole('button', { name: /New/i }).first()
    this.btnModify = page.getByRole('button', { name: /Modify/i }).first()
    this.btnDelete = page.getByRole('button', { name: /Delete/i }).first()
    this.btnFind   = page.getByRole('button', { name: /Find/i }).first()
    this.btnSave   = page.getByRole('button', { name: /Save/i }).first()
    this.btnCancel = page.getByRole('button', { name: /Cancel/i }).first()
    this.btnPrint  = page.getByRole('button', { name: /Print/i }).first()

    // Nav buttons have title attr (text content is «/‹/›/»), so getByTitle is correct
    this.btnFirst  = page.getByTitle('First')
    this.btnPrev   = page.getByTitle('Previous')
    this.btnNext   = page.getByTitle('Next')
    this.btnLast   = page.getByTitle('Last')

    // Amendment Reason is a plain <input> with a placeholder (not inside AntD Form.Item)
    this.fieldAmendReason = page.getByPlaceholder(/amendment reason/i)
    this.fieldRefNo       = page.locator('input[placeholder*="Ref"]').first()

    this.btnDeleteAmendment = page.getByRole('button', { name: 'Delete Amendment' })
    this.btnDeleteLine      = page.getByRole('button', { name: 'Delete Line' })

    this.lineGrid = page.locator('table').last()
  }

  // ── Custom modal (PrPickerForAmendModal / PrAmendmentListModal) ─────────────
  // Both modals use a fixed-position overlay with backdrop-filter: blur(4px).
  // They are NOT AntD <Modal> components — no .ant-modal-content class.
  get customModal(): Locator {
    return this.page.locator('div[style*="backdrop-filter"]')
  }

  /** Rows inside whichever custom modal is currently open. */
  get modalRows(): Locator {
    return this.customModal.locator('tbody tr')
  }

  async goto() {
    await this.page.goto('/pr-amendment')
    await this.page.waitForLoadState('networkidle')
  }

  // ── New Amendment flow ──────────────────────────────────────────────────────

  /**
   * Click New → wait for PR picker to open → double-click the matching row
   * (double-click triggers onDoubleClick → onSelect immediately without needing
   * the "Select →" button).
   */
  async startNewAmendment(prNo: string) {
    await this.btnNew.click()
    await expect(this.customModal).toBeVisible({ timeout: 8_000 })

    // Type PR number in the picker's search field
    const searchInput = this.customModal.locator('input[type="text"], input[placeholder*="PR"]').first()
    await searchInput.fill(prNo)
    await this.page.waitForTimeout(400)

    // Double-click the matching row to auto-confirm selection
    await this.customModal.locator('tr').filter({ hasText: prNo }).first().dblclick()
    await this.page.waitForTimeout(1_000)
  }

  /** Fill amendment reason field via placeholder. */
  async fillReason(reason: string) {
    await this.fieldAmendReason.fill(reason)
  }

  /** Get all visible grid rows in the main line grid. */
  async getLineRows(): Promise<Locator[]> {
    const tbody = this.lineGrid.locator('tbody tr')
    const count = await tbody.count()
    return Array.from({ length: count }, (_, i) => tbody.nth(i))
  }

  // ── Confirm dialogs (AntD Modal.confirm) ────────────────────────────────────

  async confirmDialog() {
    const okBtn = this.page.locator('.ant-modal-confirm-btns .ant-btn-primary, .ant-modal-footer .ant-btn-primary').last()
    await expect(okBtn).toBeVisible({ timeout: 5_000 })
    await okBtn.click()
    await this.page.waitForTimeout(500)
  }

  async cancelDialog() {
    await this.page.locator('.ant-modal-confirm-btns .ant-btn:not(.ant-btn-primary)').click()
  }

  // ── Assertions ──────────────────────────────────────────────────────────────

  async expectSuccess(pattern?: string | RegExp) {
    const toast = this.page.locator('.ant-message-success')
    await expect(toast).toBeVisible({ timeout: 8_000 })
    if (pattern) await expect(toast).toContainText(pattern instanceof RegExp ? pattern : new RegExp(pattern, 'i'))
  }

  async expectError(text: string | RegExp) {
    const re = text instanceof RegExp ? text : new RegExp(text, 'i')
    await expect(
      this.page.locator('.ant-message-error, .ant-form-item-explain-error').first()
    ).toContainText(re, { timeout: 6_000 })
  }

  async expectAmendNoVisible() {
    await expect(this.page.locator('text=/AMD-\\d{4}/')).toBeVisible({ timeout: 5_000 })
  }

  async expectOnAmendmentPage() {
    await expect(this.page).toHaveURL(/pr-amendment/)
  }

  /** Assert the delete banner (shown in delete mode) is visible. */
  async expectDeleteBanner() {
    // The delete banner renders "Delete mode" text in red
    await expect(this.page.getByText(/Delete mode/)).toBeVisible({ timeout: 3_000 })
  }
}
