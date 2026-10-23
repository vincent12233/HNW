import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { formatOpsCount } from '../lib/ops-dashboard.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

test('formatOpsCount distinguishes unknown values from a valid zero', () => {
  assert.equal(formatOpsCount(0), '0');
  assert.equal(formatOpsCount(1250), '1,250');
  assert.equal(formatOpsCount(undefined), '—');
  assert.equal(formatOpsCount(null), '—');
  assert.equal(formatOpsCount(Number.NaN), '—');
  assert.equal(formatOpsCount(Number.POSITIVE_INFINITY), '—');
  assert.equal(formatOpsCount(null, 'Unavailable'), 'Unavailable');
});

test('dashboard uses shared metric and quick-action components', () => {
  const dashboard = read('../app/dashboard/page.tsx');
  assert.match(dashboard, /<OpsMetricCard\b/);
  assert.match(dashboard, /<OpsQuickAction\b/);
  assert.doesNotMatch(dashboard, /function MetricCard\s*\(/);
  assert.doesNotMatch(dashboard, /function QuickAction\s*\(/);
  assert.match(dashboard, /formatOpsCount\(/);
});

test('dashboard preserves role endpoints, funding guidance, and workflow links', () => {
  const dashboard = read('../app/dashboard/page.tsx');
  for (const endpoint of [
    '/auth/me',
    '/business/my-dashboard',
    '/business/my-risk-dashboard',
    '/admin/login-risk-summary',
  ]) {
    assert.ok(dashboard.includes(endpoint), `missing ${endpoint}`);
  }
  for (const path of ['/finance-overview', '/deposits', '/withdrawals']) {
    assert.ok(dashboard.includes(`href="${path}"`), `missing ${path}`);
  }
  assert.match(dashboard, /无需双人复核/);
  assert.match(dashboard, /客户存款完成后由财务单人创建上分订单/);
});

test('dashboard styles retain responsive, focus, and reduced-motion behavior', () => {
  const css = read('../app/globals.css');
  assert.match(css, /\.ops-dashboard-grid/);
  assert.match(css, /\.ops-dashboard-section/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /:focus-visible/);
  assert.match(css, /@media \(max-width:767px\)/);
});
