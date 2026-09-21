import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { formatInr } from '../lib/ops-format.ts';
import { opsStatusOf } from '../lib/ops-status.ts';
import {
  IPO_CATALOG_STATUSES,
  OTC_STATUSES,
  PRODUCT_COPY,
  ipoApplicationStatusLabel,
  ipoCatalogStatusLabel,
  productWorkflowForRole,
} from '../lib/ops-product.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const PII_LOG = /console\.(log|debug|info|warn|error)\([^)]*(phone|accountNumber|token|stack)/i;
const VIP_PRIORITY = /VIP 优先|VIP限额|vipPriority/;
const NEW_STATUS = /PRE_ALLOTMENT|WAITLISTED|GREY_MARKET|DARK_POOL/;

test('G.4 IPO catalog statuses stay existing API values', () => {
  assert.deepEqual([...IPO_CATALOG_STATUSES], ['DRAFT', 'PUBLISHED', 'OPEN', 'CLOSED', 'LISTED', 'ALLOTMENT_DONE']);
  assert.deepEqual([...OTC_STATUSES], ['PENDING', 'APPROVED', 'REJECTED']);
  assert.match(ipoCatalogStatusLabel('LISTED') ?? '', /申购价结算/);
  assert.equal(ipoApplicationStatusLabel('PENDING', 0), '待分配');
  assert.equal(ipoApplicationStatusLabel('PENDING', 10), '待公布分配');
  assert.equal(opsStatusOf('ALLOTTED').label, '已分配');
  assert.equal(opsStatusOf('DEFAULTED').tone, 'error');
  assert.match(PRODUCT_COPY.catalogNotTraded, /不是已交易/);
});

test('G.4 product role workflows do not grant BUSINESS instrument write', () => {
  assert.equal(productWorkflowForRole('ADMIN').instrumentsPage, '/instruments');
  assert.equal(productWorkflowForRole('ADMIN').canApproveOtc, false);
  assert.equal(productWorkflowForRole('BUSINESS').otcPage, '/business-otc');
  assert.equal(productWorkflowForRole('BUSINESS').instrumentsPage, null);
  assert.equal(productWorkflowForRole('FINANCE').ipoDebtsPage, '/ipo-debts');
  assert.equal(productWorkflowForRole('FINANCE').canAllocateIpo, false);
  assert.equal(productWorkflowForRole('MANAGER').ipoPage, null);
});

test('G.4 IPO management uses existing status PATCH and does not fake trades', () => {
  const source = read('../app/ipo-management/page.tsx');
  assert.match(source, /\/admin\/ipo/);
  assert.match(source, /\/admin\/ipo\/\$\{.*\}\/status/);
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsStatusTag/);
  assert.match(source, /OpsMoney/);
  assert.match(source, /确认上架到 APP|确认下架 IPO/);
  assert.match(source, /上架不代表上市/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.doesNotMatch(source, NEW_STATUS);
  assert.doesNotMatch(source, VIP_PRIORITY);
  assert.doesNotMatch(source, /已成交目录|假成交/);
});

test('G.4 IPO debts and applications keep existing APIs and mask phones', () => {
  const debts = read('../app/ipo-debts/page.tsx');
  const apps = read('../app/business-ipo/page.tsx');
  assert.match(debts, /\/admin\/ipo\/debts/);
  assert.doesNotMatch(debts, /api\.(patch|post|put|delete)/);
  assert.match(debts, /maskOpsPhone/);
  assert.match(apps, /\/business\/my-ipo-applications/);
  assert.match(apps, /\/business\/my-ipo-applications\/publish/);
  assert.match(apps, /\/allocate/);
  assert.match(apps, /maskOpsPhone/);
  assert.match(apps, /提交到服务器/);
  assert.doesNotMatch(apps, /`\+91 \$\{/);
  assert.doesNotMatch(debts, PII_LOG);
  assert.doesNotMatch(apps, VIP_PRIORITY);
});

test('G.4 OTC review keeps pending PATCH and confirm-before-mutate', () => {
  const source = read('../app/business-otc/page.tsx');
  assert.match(source, /\/otc\/orders\/pending/);
  assert.match(source, /\/otc\/orders\/\$\{id\}\/\$\{decision\}/);
  assert.match(source, /OpsModal/);
  assert.match(source, /reviewing/);
  assert.match(source, /OpsMoney/);
  assert.match(source, /未成功前状态保持待审核|失败记录/);
  assert.doesNotMatch(source, NEW_STATUS);
  assert.doesNotMatch(source, PII_LOG);
});

test('G.4 instruments keep search/status/exchange APIs and catalog honesty', () => {
  const source = read('../app/instruments/page.tsx');
  assert.match(source, /\/admin\/instruments/);
  assert.match(source, /\/admin\/instruments\/sync/);
  assert.match(source, /\/admin\/instruments\/\$\{record\.id\}\/status/);
  assert.match(source, /OpsDrawer/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /aria-label="搜索股票资料库"/);
  assert.match(source, /PRODUCT_COPY\.catalogNotTraded/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.doesNotMatch(source, /行情 provider|新交易入口/);
  assert.doesNotMatch(source, VIP_PRIORITY);
});

test('G.4 fund catalog does not present products as settled trades', () => {
  const source = read('../app/funds/page.tsx');
  assert.match(source, /\/admin-products\/funds/);
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsMoney/);
  assert.match(source, /目录删除不是交易或结算|catalogNotTraded/);
  assert.match(formatInr('250000').replace(/[\s\u00a0\u202f]/g, ''), /₹2,50,000.00/);
  assert.doesNotMatch(source, /已成交基金/);
});

test('G.4 product pages honor reduced motion chrome', () => {
  const css = read('../app/globals.css');
  assert.match(css, /\.ops-workspace \*/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  for (const page of [
    '../app/ipo-management/page.tsx',
    '../app/business-otc/page.tsx',
    '../app/instruments/page.tsx',
  ]) {
    assert.match(read(page), /ops-workspace/);
    assert.match(read(page), /aria-label=/);
  }
});
