import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir:  '.',
  timeout:  45_000,          // 45s per test — API calls can be slow
  retries:  0,
  reporter: [
    ['html', { outputFolder: 'report', open: 'never' }],
    ['list'],
  ],
  use: {
    baseURL:     'http://localhost:5173',
    headless:    false,       // set true for CI / unattended runs
    viewport:    { width: 1440, height: 900 },
    screenshot:  'on',        // always capture — needed for diagnosis
    video:       'retain-on-failure',
    trace:       'retain-on-failure',
  },
  outputDir: 'test-results',
})
