import { mkdir } from 'node:fs/promises';
import path from 'node:path';

const baseUrl = process.env.ADMIN_VISUAL_BASE_URL;
const output = path.resolve(process.env.ADMIN_VISUAL_OUTPUT ?? 'artifacts/admin-visuals');
const viewports = [
  { name: '1280x720', width: 1280, height: 720 },
  { name: '1440x900', width: 1440, height: 900 },
  { name: '1920x1080', width: 1920, height: 1080 },
];

if (!baseUrl?.startsWith('http://') && !baseUrl?.startsWith('https://')) {
  throw new Error('ADMIN_VISUAL_BASE_URL must point to an authorized local or review deployment.');
}

let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  throw new Error('Install Playwright in the visual-review environment before capturing Admin evidence.');
}

await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  for (const viewport of viewports) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      reducedMotion: 'reduce',
    });
    const page = await context.newPage();
    await page.goto(baseUrl, { waitUntil: 'networkidle' });
    await page.screenshot({
      path: path.join(output, `admin-${viewport.name}.png`),
      fullPage: true,
    });
    await context.close();
  }
} finally {
  await browser.close();
}

console.log(`Admin visual evidence written to ${output}`);
