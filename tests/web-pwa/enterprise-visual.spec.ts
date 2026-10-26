import { expect, test } from '@playwright/test';

test('India Trading app shell has phone and desktop visual evidence', async ({ page }, testInfo) => {
  await page.goto('/');
  await expect(page).toHaveTitle('India Trading');
  await expect(page.locator('flutter-view')).toBeAttached();
  await page.screenshot({ path: testInfo.outputPath(`${testInfo.project.name}-home.png`), fullPage: true });
});
