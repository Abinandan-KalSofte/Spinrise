import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

page.on('console', m => {
  if (m.type() === 'error') console.log('[console error]', m.text());
});

// ── Step 1: landing page ────────────────────────────────────────────
await page.goto('http://localhost:5173', { timeout: 10000, waitUntil: 'networkidle' });
await page.waitForTimeout(1000);
console.log('LANDING URL:', page.url());

const inputCount = await page.locator('input').count();
console.log('LOGIN INPUTS FOUND:', inputCount);

// ── Step 2: attempt login ───────────────────────────────────────────
// Look for username / password fields by placeholder or type
const userInput = page.locator('input[type="text"], input:not([type="password"])').first();
const passInput = page.locator('input[type="password"]').first();

const userVisible = await userInput.isVisible().catch(() => false);
const passVisible = await passInput.isVisible().catch(() => false);
console.log('User input visible:', userVisible, '| Pass input visible:', passVisible);

if (userVisible && passVisible) {
  // Try known test credentials
  await userInput.fill('admin');
  await passInput.fill('admin');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(2000);
  console.log('AFTER LOGIN ATTEMPT URL:', page.url());
}

// ── Step 3: check if we landed on dashboard / main page ─────────────
const afterUrl = page.url();
const isStillOnLogin = afterUrl.includes('login') || await page.locator('input[type="password"]').isVisible().catch(() => false);
console.log('Still on login page:', isStillOnLogin);

await browser.close();
