import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  filterVipClients,
  summarizeVipClients,
  vipBusinessBreakdown,
} from '../lib/vip.ts';

const root = dirname(fileURLToPath(import.meta.url));

const clients = [
  {
    userId: 'c1',
    displayName: 'Client One',
    currentTier: 'GOLD',
    cumulativeConfirmedDeposit: '100.00',
    suggestionStatus: 'UPGRADE',
    assignedBusiness: { id: 'b1', fullName: 'Agent A', employeeNo: 'B001' },
  },
  {
    userId: 'c2',
    displayName: 'Client Two',
    currentTier: 'STANDARD',
    cumulativeConfirmedDeposit: '0.00',
    suggestionStatus: 'NOT_CONFIGURED',
    assignedBusiness: { id: 'b1', fullName: 'Agent A', employeeNo: 'B001' },
  },
  {
    userId: 'c3',
    displayName: 'Client Three',
    currentTier: 'PLATINUM',
    cumulativeConfirmedDeposit: '500.00',
    suggestionStatus: 'DOWNGRADE',
    assignedBusiness: { id: 'b2', fullName: 'Agent B', employeeNo: 'B002' },
  },
  {
    userId: 'c4',
    displayName: 'Client Four',
    currentTier: 'SILVER',
    cumulativeConfirmedDeposit: '20.00',
    suggestionStatus: 'KEEP',
    assignedBusiness: { id: 'b2', fullName: 'Agent B', employeeNo: 'B002' },
  },
];

test('VIP summary counts come from the loaded client list', () => {
  const summary = summarizeVipClients(clients);
  assert.equal(summary.total, 4);
  assert.equal(summary.byTier.GOLD, 1);
  assert.equal(summary.byTier.STANDARD, 1);
  assert.equal(summary.notConfigured, 1);
  assert.equal(summary.upgrade, 1);
  assert.equal(summary.downgrade, 1);
  assert.equal(summary.keepCurrent, 1);
});

test('VIP filters only use fields already returned by the list API', () => {
  assert.equal(filterVipClients(clients, { tier: 'GOLD' }).length, 1);
  assert.equal(filterVipClients(clients, { businessId: 'b1' }).length, 2);
  assert.equal(filterVipClients(clients, { suggestionStatus: 'UPGRADE' }).length, 1);
  assert.equal(filterVipClients(clients, { suggestionStatus: 'KEEP' }).length, 1);
});

test('manager breakdown groups clients by assigned business, not a manager id', () => {
  const groups = vipBusinessBreakdown(clients);
  assert.equal(groups.length, 2);
  assert.equal(groups.find((row) => row.id === 'b1')?.clientCount, 2);
});

test('admin VIP workspace is read-only except history/details and does not invent manager filters', () => {
  const source = readFileSync(join(root, '../components/VipClientsWorkspace.tsx'), 'utf8');
  assert.match(source, /summarizeVipClients/);
  assert.match(source, /按所属业务员筛选/);
  assert.match(source, /以下数量来自当前 VIP 客户接口返回的完整列表/);
  assert.match(source, /lastTierChangedAt/);
  assert.match(source, /vip-summary-grid/);
  assert.doesNotMatch(source, /businessCreatorId/);
  assert.doesNotMatch(source, /按管理员筛选/);
  assert.doesNotMatch(source, /service request|客户经理|工单/);
  assert.doesNotMatch(source, /onDrag|draggable/);
});

test('admin VIP page keeps existing list/history APIs and adds config links', () => {
  const source = readFileSync(join(root, '../app/vip-clients/page.tsx'), 'utf8');
  assert.match(source, /\/admin\/vip-clients/);
  assert.match(source, /showAdminLinks/);
  assert.doesNotMatch(source, /allowAdjust/);
  assert.doesNotMatch(source, /\/admin\/vip-clients\/\$\{.*\}\/tier/);
});

test('manager VIP page stays scoped and has no transfer or adjust controls', () => {
  const source = readFileSync(join(root, '../app/team-vip/page.tsx'), 'utf8');
  assert.match(source, /\/team\/vip-clients/);
  assert.match(source, /showBusinessBreakdown/);
  assert.doesNotMatch(source, /allowAdjust/);
  assert.doesNotMatch(source, /\/admin\/vip-clients/);
  assert.doesNotMatch(source, /Transfer|转移/);
  assert.doesNotMatch(source, /客户经理/);
});

test('business VIP page keeps the existing manual adjust flow', () => {
  const source = readFileSync(join(root, '../app/business-vip/page.tsx'), 'utf8');
  assert.match(source, /\/business\/vip-clients/);
  assert.match(source, /allowAdjust/);
  assert.match(source, /\/business\/vip-clients\/\$\{userId\}\/tier/);
});

test('VIP suggestion tags use text plus icon, not color alone', () => {
  const source = readFileSync(join(root, '../components/VipSuggestionTag.tsx'), 'utf8');
  assert.match(source, /ArrowUpOutlined/);
  assert.match(source, /suggestionLabel/);
  assert.match(source, /aria-label/);
});

test('VIP CSS honors reduced motion and keeps 8px cards', () => {
  const source = readFileSync(join(root, '../app/globals.css'), 'utf8');
  assert.match(source, /vip-workspace/);
  assert.match(source, /vip-summary-card/);
  assert.match(source, /border-radius: 8px;/);
  assert.match(source, /prefers-reduced-motion/);
});
