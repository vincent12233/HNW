import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { formatInr, formatOpsDateTime } from '../lib/ops-format.ts';
import { maskBankAccount, maskIfsc, maskOpsPhone } from '../lib/ops-directory.ts';
import { opsStatusOf } from '../lib/ops-status.ts';
import { UNAVAILABLE } from '../lib/ops-governance.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

function menuBlock() {
  const shell = read('../components/AdminShell.tsx');
  return shell.slice(
    shell.indexOf('const menus: Record<Role, MenuItemDef[]>'),
    shell.indexOf('const menuGroups'),
  );
}

test('CREDIT/DEBIT stay ledger types, not approval results', () => {
  assert.equal(opsStatusOf('CREDIT').label, '账户入金');
  assert.equal(opsStatusOf('CREDIT').tone, 'info');
  assert.equal(opsStatusOf('DEBIT').label, '账户扣款');
  assert.equal(opsStatusOf('DEBIT').tone, 'warning');
  assert.equal(opsStatusOf('APPROVED').tone, 'success');
  assert.equal(opsStatusOf('REJECTED').tone, 'error');
  assert.equal(opsStatusOf('PENDING').tone, 'warning');
  assert.notEqual(opsStatusOf('CREDIT').tone, opsStatusOf('APPROVED').tone);
  assert.notEqual(opsStatusOf('DEBIT').tone, opsStatusOf('REJECTED').tone);
  assert.equal(opsStatusOf('BUY').tone, 'info');
  assert.equal(opsStatusOf('SELL').tone, 'warning');
});

test('INR zero is formatted and null stays a missing placeholder', () => {
  const zero = formatInr(0).replace(/[\s\u00a0\u202f]/g, '');
  assert.equal(zero, '₹0.00');
  assert.equal(formatInr(null), '—');
  assert.equal(formatInr('not-a-number'), '—');
  assert.match(formatInr(-12).replace(/[\s\u00a0\u202f]/g, ''), /₹12.00|₹-12.00|-₹12.00/);
  assert.equal(formatOpsDateTime(null), '—');
  assert.equal(UNAVAILABLE, 'Unavailable');
});

test('PII masks do not regress to full account copy', () => {
  assert.equal(maskOpsPhone('9876543210'), '******3210');
  assert.equal(maskBankAccount('123456789012'), '••••9012');
  assert.equal(maskIfsc('HDFC0001234'), 'HDFC••••');
  const accounts = read('../app/bank-accounts/page.tsx');
  assert.match(accounts, /maskBankAccount/);
  assert.doesNotMatch(accounts, /copyable/);
  const vip = read('../components/VipClientsWorkspace.tsx');
  assert.match(vip, /maskedPhone/);
  assert.doesNotMatch(vip, /copyable/);
});

test('VIP and assignment tables reuse Ops empty/error chrome', () => {
  const vip = read('../components/VipClientsWorkspace.tsx');
  const assignment = read('../components/TeamAssignmentWorkspace.tsx');
  assert.match(vip, /OpsEmpty/);
  assert.match(vip, /OpsErrorState/);
  assert.doesNotMatch(vip, /PRESENTED_IMAGE_SIMPLE/);
  assert.match(vip, /await api\.get/);
  assert.match(vip, /await api\.patch\(adjustEndpoint/);
  assert.match(assignment, /OpsEmpty description="没有未归属业务员"/);
  assert.match(assignment, /OpsEmpty description="该管理员名下暂无业务员"/);
  assert.match(assignment, /OpsEmpty description="暂无归属历史"/);
  assert.match(assignment, /\/admin\/business-assignments\/preview/);
  assert.match(assignment, /\/admin\/business-assignments\/transfer/);
});

test('session picker empty is not merged into record-empty chrome', () => {
  const support = read('../app/support-console/page.tsx');
  assert.match(support, /请选择一个客户会话/);
  assert.match(support, /OpsEmpty description=\{loading \? "正在加载会话" : "暂无会话"\}/);
});

test('role allowlists stay on the existing AdminShell menus', () => {
  const block = menuBlock();
  assert.match(block, /ADMIN: \[/);
  assert.match(block, /\/vip-settings/);
  assert.match(block, /\/team-vip/);
  assert.doesNotMatch(block, /\/vip-products/);
  assert.match(block, /FINANCE: \[/);
  assert.match(block, /\/finance-overview/);
  assert.doesNotMatch(block, /VIP 产品目录/);
});

test('shared ops chrome keeps aria labels, reduced motion, and system-state class', () => {
  const empty = read('../components/OpsEmpty.tsx');
  const error = read('../components/OpsErrorState.tsx');
  const status = read('../components/OpsStatusTag.tsx');
  const header = read('../components/OpsPageHeader.tsx');
  const denied = read('../components/OpsPermissionDenied.tsx');
  const missing = read('../app/not-found.tsx');
  const crashed = read('../app/error.tsx');
  const global = read('../app/global-error.tsx');
  const css = read('../app/globals.css');
  assert.match(empty, /aria-label="重新加载"/);
  assert.match(error, /aria-label="重新加载"/);
  assert.match(status, /aria-label=\{`状态 \$\{text\}`\}/);
  assert.match(header, /aria-label="页面路径"/);
  assert.match(denied, /ops-system-state|没有访问该页面的权限/);
  assert.match(missing, /ops-system-state/);
  assert.match(crashed, /ops-system-state/);
  assert.match(global, /ops-system-state/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /\.ops-empty-icon/);
  assert.match(css, /\.ops-error-state/);
  assert.match(css, /@media \(max-width: 390px\)/);
  assert.match(css, /@media \(max-width:767px\)/);
});
