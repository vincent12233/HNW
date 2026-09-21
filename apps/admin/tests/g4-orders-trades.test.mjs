import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { formatInr } from '../lib/ops-format.ts';
import { maskOpsPhone } from '../lib/ops-directory.ts';
import { opsStatusOf } from '../lib/ops-status.ts';
import {
  ORDER_SIDES,
  ORDER_STATUSES,
  ORDER_TIFS,
  ORDER_TYPES,
  TRADING_COPY,
  orderStatusLabel,
  tradeFeeOf,
  tradingWorkflowForRole,
} from '../lib/ops-trading.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const PII_LOG = /console\.(log|debug|info|warn|error)\([^)]*(phone|accountNumber|token|stack)/i;
const NEW_ORDER_TYPE = /STOP_LIMIT|BRACKET|GTT|ICEBERG/;
const VIP_PRIORITY = /VIP 优先|VIP限额|vipPriority/;

test('G.4 order enums stay BUY/SELL MARKET/LIMIT DAY/IOC/FOK and six statuses', () => {
  assert.deepEqual([...ORDER_SIDES], ['BUY', 'SELL']);
  assert.deepEqual([...ORDER_TYPES], ['MARKET', 'LIMIT']);
  assert.deepEqual([...ORDER_TIFS], ['DAY', 'IOC', 'FOK']);
  assert.deepEqual([...ORDER_STATUSES], ['PENDING', 'OPEN', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'REJECTED']);
  assert.equal(orderStatusLabel('CANCELLED'), '已撤单');
  assert.equal(opsStatusOf('MARKET').label, '市价');
  assert.equal(opsStatusOf('FOK').tone, 'warning');
});

test('G.4 trade fees use API fields and INR grouping', () => {
  assert.equal(tradeFeeOf({ feeAmount: '0' }), '0');
  assert.equal(tradeFeeOf({ fees: '1.5' }), '1.5');
  assert.equal(formatInr('1234567.8').replace(/[\s\u00a0\u202f]/g, ''), '₹12,34,567.80');
  assert.equal(maskOpsPhone('9876543210'), '******3210');
});

test('G.4 role workflows do not grant BUSINESS admin order APIs or cancel', () => {
  assert.equal(tradingWorkflowForRole('ADMIN').ordersApi, '/admin/orders');
  assert.equal(tradingWorkflowForRole('FINANCE').tradesApi, '/admin/trades');
  assert.equal(tradingWorkflowForRole('BUSINESS').ordersApi, '/business/my-orders');
  assert.equal(tradingWorkflowForRole('SUPPORT').tradesApi, '/business/my-trade-pairs');
  assert.equal(tradingWorkflowForRole('MANAGER').ordersPage, '/team?view=orders');
  assert.equal(tradingWorkflowForRole('ADMIN').ordersApi.includes('cancel'), false);
});

test('G.4 order workspace is read-only chrome over existing list APIs', () => {
  const source = read('../components/OpsOrderWorkspace.tsx');
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsToolbar/);
  assert.match(source, /OpsEmpty/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /OpsStatusTag/);
  assert.match(source, /OpsDrawer/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.match(source, /aria-label="刷新订单列表"/);
  assert.match(source, /TRADING_COPY\.noCancel/);
  assert.doesNotMatch(source, /\/orders\/\$\{.*\}\/cancel/);
  assert.doesNotMatch(source, /api\.(patch|post|put|delete)/);
  assert.doesNotMatch(source, PII_LOG);
  assert.doesNotMatch(source, NEW_ORDER_TYPE);
});

test('G.4 admin and business order pages keep scoped GET APIs', () => {
  const admin = read('../app/orders/page.tsx');
  const business = read('../app/business-orders/page.tsx');
  assert.match(admin, /listApi="\/admin\/orders"/);
  assert.match(business, /listApi="\/business\/my-orders"/);
  assert.doesNotMatch(admin, /\/business\/my-orders/);
  assert.doesNotMatch(business, /\/admin\/orders/);
  assert.doesNotMatch(admin, /VIP 优先/);
});

test('G.4 trades workspace does not recompute fees or invent fills', () => {
  const source = read('../components/OpsTradeWorkspace.tsx');
  assert.match(source, /listApi/);
  assert.match(source, /tradeFeeOf/);
  assert.match(source, /OpsMoney/);
  assert.match(source, /maskOpsPhone/);
  assert.doesNotMatch(source, /grossAmount \*|quantity \* Number/);
  assert.doesNotMatch(source, /api\.(patch|post)/);
  assert.doesNotMatch(source, VIP_PRIORITY);
});

test('G.4 trades pages keep admin vs own-book APIs', () => {
  const admin = read('../app/trades/page.tsx');
  const business = read('../app/business-trades/page.tsx');
  assert.match(admin, /listApi="\/admin\/trades"/);
  assert.match(business, /\/business\/my-trade-pairs/);
  assert.match(business, /\/business\/my-customers/);
  assert.match(business, /maskOpsPhone/);
  assert.match(business, /LOADED_FILTER|loadedFilter|只作用于已经加载/);
  assert.doesNotMatch(business, /`\+91 \$\{.*phone/);
  assert.doesNotMatch(business, PII_LOG);
  assert.match(read('../lib/ops-trading.ts'), /不在前端重算/);
  assert.match(TRADING_COPY.noCancel, /不提供撤单/);
});

test('G.4 CSS wraps long ids and honors reduced motion', () => {
  const css = read('../app/globals.css');
  assert.match(css, /\.ops-wrap-text/);
  assert.match(css, /\.ops-workspace \*/);
  assert.match(css, /prefers-reduced-motion: reduce/);
});
