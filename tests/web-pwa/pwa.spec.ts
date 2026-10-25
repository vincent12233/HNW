import { expect, test } from '@playwright/test';

test('manifest is installable and customer safe', async ({ request }) => {
  const response = await request.get('/manifest.json');
  expect(response.ok()).toBeTruthy();
  const manifest = await response.json();
  expect(manifest).toMatchObject({
    name: 'India Trading',
    short_name: 'India Trading',
    display: 'standalone',
    start_url: '/',
    scope: '/',
  });
  expect(JSON.stringify(manifest)).not.toMatch(/Flutter|repository|localhost/i);
});

test('root and deep-link refresh render the same app shell', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle('India Trading');
  await page.goto('/account/settings');
  await expect(page).toHaveTitle('India Trading');
  await expect(page.locator('flutter-view')).toBeAttached();
});

test('service worker contains no background write replay', async ({ request }) => {
  const response = await request.get('/pwa_service_worker.js');
  expect(response.ok()).toBeTruthy();
  const source = await response.text();
  expect(source).toContain("request.method !== 'GET'");
  expect(source).toContain("cache: 'no-store'");
  expect(source).not.toContain('sync.register');
});
