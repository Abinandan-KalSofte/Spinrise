import { defineConfig, devices } from '@playwright/test'

/**
 * Spinrise ERP — Playwright E2E Configuration
 * Run: npx playwright test
 * UI mode: npx playwright test --ui
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,      // ERP tests are stateful — run sequentially
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile:  'playwright-report/results.json' }],
    ['list'],
  ],
  use: {
    baseURL:       process.env.APP_URL ?? 'http://localhost:5173',
    trace:         'on-first-retry',
    screenshot:    'only-on-failure',
    video:         'retain-on-failure',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
  },
  projects: [
    // Setup project: authenticates once and saves storage state
    {
      name: 'setup',
      testMatch: /global\.setup\.ts/,
    },
    // Main test project: reuses saved auth state
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'e2e/.auth/state.json',
      },
      dependencies: ['setup'],
    },
  ],
  // Dev server is started separately — set APP_URL env var if not localhost:5173
})
