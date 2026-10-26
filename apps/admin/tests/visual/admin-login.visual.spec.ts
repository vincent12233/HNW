import { expect, test } from '@playwright/test';

test('staff login renders without horizontal overflow and preserves its credentials', async ({ page }, testInfo) => {
  await page.goto('/login');
  await expect(page.getByRole('textbox', { name: /员工编号/i })).toBeVisible();
  await expect(page.getByLabel(/密码/i)).toBeVisible();
  await expect(page.getByRole('button', { name: /登录/i })).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  expect(overflow).toBe(false);
  await page.screenshot({ path: testInfo.outputPath(`${testInfo.project.name}-staff-login.png`), fullPage: true });
});
