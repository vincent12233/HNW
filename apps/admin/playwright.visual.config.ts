import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/visual',
  outputDir: './test-results/visual',
  timeout: 30_000,
  expect: { timeout: 10_000 },
  use: { baseURL: 'http://127.0.0.1:3002', trace: 'retain-on-failure' },
  webServer: {
    command: 'npm run start:admin',
    url: 'http://127.0.0.1:3002/login',
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'desktop-1440', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } } },
    { name: 'phone-320', use: { ...devices['Desktop Chrome'], viewport: { width: 320, height: 720 }, isMobile: true } },
  ],
});
