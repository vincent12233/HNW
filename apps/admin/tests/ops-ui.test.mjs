import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { formatInr, formatOpsDateTime, formatOpsId, homePathForRole } from '../lib/ops-format.ts';
import { opsStatusOf } from '../lib/ops-status.ts';

const root = dirname(fileURLToPath(import.meta.url));

test('INR formatting uses the rupee sign and Indian grouping', () => {
  const formatted = formatInr('1234567.8').replace(/[\s\u00a0\u202f]/g, '');
  assert.equal(formatted, '₹12,34,567.80');
  assert.equal(formatInr(null), '—');
  assert.equal(formatInr('not-a-number'), '—');
});

test('datetime and id helpers stay honest about missing values', () => {
  assert.equal(formatOpsDateTime(null), '—');
  assert.equal(formatOpsId('  '), '—');
  assert.equal(formatOpsId('ACC-1001'), 'ACC-1001');
  assert.match(formatOpsDateTime('2026-09-20T10:11:12.000Z'), /2026/);
});

test('status maps keep text plus a tone for icon/color pairing', () => {
  assert.equal(opsStatusOf('PENDING').label, '待处理');
  assert.equal(opsStatusOf('PENDING').tone, 'warning');
  assert.equal(opsStatusOf('FILLED').tone, 'success');
  assert.equal(opsStatusOf('UNKNOWN_CODE').label, 'UNKNOWN_CODE');
});

test('role home paths do not invent new landing routes', () => {
  assert.equal(homePathForRole('MANAGER'), '/team');
  assert.equal(homePathForRole('ADMIN'), '/dashboard');
  assert.equal(homePathForRole('FINANCE'), '/dashboard');
});

test('shared ops components cover empty, error, denied, table chrome, and status icons', () => {
  const files = {
    empty: readFileSync(join(root, '../components/OpsEmpty.tsx'), 'utf8'),
    error: readFileSync(join(root, '../components/OpsErrorState.tsx'), 'utf8'),
    denied: readFileSync(join(root, '../components/OpsPermissionDenied.tsx'), 'utf8'),
    status: readFileSync(join(root, '../components/OpsStatusTag.tsx'), 'utf8'),
    header: readFileSync(join(root, '../components/OpsPageHeader.tsx'), 'utf8'),
    money: readFileSync(join(root, '../components/OpsMoney.tsx'), 'utf8'),
    drawer: readFileSync(join(root, '../components/OpsDrawer.tsx'), 'utf8'),
    modal: readFileSync(join(root, '../components/OpsModal.tsx'), 'utf8'),
  };
  assert.match(files.empty, /aria-label="重新加载"/);
  assert.match(files.error, /aria-label="重新加载"/);
  assert.match(files.denied, /没有访问该页面的权限/);
  assert.match(files.denied, /不会扩大访问范围/);
  assert.match(files.status, /aria-label=\{`状态 \$\{text\}`\}/);
  assert.match(files.status, /CheckCircleOutlined/);
  assert.match(files.header, /aria-label="页面路径"/);
  assert.match(files.money, /formatInr/);
  assert.match(files.drawer, /destroyOnHidden/);
  assert.match(files.modal, /maskClosable = false/);
  assert.doesNotMatch(files.denied, /VIP 产品|客户经理|工单/);
});

test('AdminShell keeps role menus, adds tooltips, and shows permission denied instead of silent redirect', () => {
  const source = readFileSync(join(root, '../components/AdminShell.tsx'), 'utf8');
  const block = source.slice(
    source.indexOf('const menus: Record<Role, MenuItemDef[]>'),
    source.indexOf('const menuGroups'),
  );
  assert.match(block, /ADMIN: \[/);
  assert.match(block, /\/vip-settings/);
  assert.match(block, /\/team-vip/);
  assert.doesNotMatch(block, /\/vip-products/);
  assert.doesNotMatch(source, /VIP 产品目录/);
  assert.match(source, /Tooltip title="退出登录"/);
  assert.match(source, /aria-label=\{mobile \? \(drawerOpen \? "关闭导航"/);
  assert.match(source, /OpsPermissionDenied/);
  assert.doesNotMatch(source, /if \(user && !allowed\) router\.replace/);
  assert.match(source, /aria-label="页面路径"/);
});

test('ops theme and CSS stay dense, 8px, and reduced-motion safe', () => {
  const css = readFileSync(join(root, '../app/globals.css'), 'utf8');
  const providers = readFileSync(join(root, '../components/AppProviders.tsx'), 'utf8');
  assert.match(providers, /borderRadius: 8/);
  assert.match(css, /border-radius: 8px/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /\.ops-money/);
  assert.match(css, /\.ops-status-tag/);
  assert.doesNotMatch(css, /radial-gradient\(circle at 95%/);
  assert.doesNotMatch(css, /linear-gradient\(135deg, #07192d/);
  assert.doesNotMatch(css, /border-radius: 18px/);
});
