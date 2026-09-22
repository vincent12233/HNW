import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { maskBankAccount, maskIfsc, maskOpsPhone } from '../lib/ops-directory.ts';
import { opsStatusOf } from '../lib/ops-status.ts';
import { UNAVAILABLE } from '../lib/ops-governance.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const VIP_SPECIAL = /VIP 优先|VIP限额|vipPriority|自动升级|客户申请|服务请求|客户经理|工单系统/;
const PII_LOG = /console\.(log|debug|info|warn|error)\([^)]*(phone|accountNumber|token|stack|ifsc)/i;

function menuBlock() {
  const shell = read('../components/AdminShell.tsx');
  return shell.slice(
    shell.indexOf('const menus: Record<Role, MenuItemDef[]>'),
    shell.indexOf('const menuGroups'),
  );
}

function roleSlice(role) {
  const block = menuBlock();
  const order = ['ADMIN', 'MANAGER', 'BUSINESS', 'FINANCE', 'SUPPORT'];
  const start = block.indexOf(`${role}:`);
  const next = order[order.indexOf(role) + 1];
  const end = next ? block.indexOf(`${next}:`) : block.length;
  return block.slice(start, end);
}

test('J.4 residual page role allowlists stay on existing AdminShell menus', () => {
  const finance = roleSlice('FINANCE');
  const admin = roleSlice('ADMIN');
  const business = roleSlice('BUSINESS');
  const support = roleSlice('SUPPORT');
  assert.match(finance, /\/finance-overview/);
  assert.match(finance, /\/transactions/);
  assert.match(finance, /\/bank-accounts/);
  assert.match(finance, /\/deposits/);
  assert.match(finance, /\/customers/);
  assert.doesNotMatch(finance, /\/approvals/);
  assert.doesNotMatch(finance, /\/vip-settings/);
  assert.match(admin, /\/approvals/);
  assert.match(admin, /\/vip-settings/);
  assert.match(admin, /\/watchlist/);
  assert.match(admin, /\/quant/);
  assert.match(admin, /\/team-assignments/);
  assert.doesNotMatch(admin, /\/finance-overview/);
  assert.match(business, /\/business-accounts/);
  assert.match(business, /\/business-positions/);
  assert.match(support, /\/business-institutional/);
  assert.match(support, /\/support-console/);
  assert.doesNotMatch(business, /\/vip-settings/);
});

test('J.4 403, 404, session expired and global error keep password-login return paths', () => {
  const denied = read('../components/OpsPermissionDenied.tsx');
  const missing = read('../app/not-found.tsx');
  const crashed = read('../app/error.tsx');
  const global = read('../app/global-error.tsx');
  const login = read('../app/login/page.tsx');
  const shell = read('../components/AdminShell.tsx');
  const api = read('../lib/api.ts');
  const layout = read('../app/layout.tsx');
  assert.match(denied, /status="403"/);
  assert.match(denied, /没有访问该页面的权限/);
  assert.match(denied, /返回工作台/);
  assert.match(missing, /status="404"/);
  assert.match(missing, /返回登录入口/);
  assert.match(missing, /返回工作台/);
  assert.match(crashed, /请重试当前页面/);
  assert.match(crashed, /返回登录入口/);
  assert.doesNotMatch(crashed, /error\.stack|error\.message/);
  assert.match(global, /返回登录入口/);
  assert.match(global, /请重试/);
  assert.doesNotMatch(global, /error\.stack|error\.message/);
  assert.doesNotMatch(global, /suppressHydrationWarning/);
  assert.doesNotMatch(layout, /suppressHydrationWarning/);
  assert.ok(login.includes('params.get("session") !== "expired"'));
  assert.match(login, /员工编号和密码/);
  assert.match(shell, /\/login\?session=expired/);
  assert.match(shell, /aria-label="返回登录入口"/);
  assert.match(shell, /OpsPermissionDenied/);
  assert.doesNotMatch(shell, /if \(user && !allowed\) router\.replace/);
  assert.match(api, /\/login\?session=expired/);
});

test('J.4 PII helpers still mask phones, bank accounts and IFSC', () => {
  assert.equal(maskOpsPhone('9876543210'), '******3210');
  assert.equal(maskBankAccount('123456789012'), '••••9012');
  assert.equal(maskIfsc('HDFC0001234'), 'HDFC••••');
  assert.equal(UNAVAILABLE, 'Unavailable');
});

test('J.4 bank-accounts list masks values and does not offer full-account copy', () => {
  const source = read('../app/bank-accounts/page.tsx');
  assert.match(source, /\/admin\/bank-accounts/);
  assert.match(source, /maskBankAccount/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /maskIfsc/);
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /OpsEmpty/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.match(source, /aria-label="刷新银行账户"/);
  assert.doesNotMatch(source, /copyable/);
  assert.doesNotMatch(source, /`\+91 \$\{/);
  assert.doesNotMatch(source, PII_LOG);
});

test('J.4 customers list no longer prefetches login-risk N+1', () => {
  const source = read('../app/customers/page.tsx');
  const load = source.slice(source.indexOf('async function loadCustomers'), source.indexOf('useEffect(() => {'));
  assert.match(load, /\/admin\/customers/);
  assert.doesNotMatch(load, /login-risk/);
  assert.doesNotMatch(load, /Promise\.allSettled/);
  assert.match(source, /openLoginRisk/);
  assert.match(source, /\/admin\/customers\/\$\{customer\.id\}\/login-risk/);
  assert.match(source, /detailError/);
  assert.match(source, /maskOpsPhone/);
  assert.doesNotMatch(source, /风险评分|riskScore/);
  assert.doesNotMatch(source, PII_LOG);
});

test('J.4 finance-overview uses real account pagination and honest sample copy', () => {
  const source = read('../app/finance-overview/page.tsx');
  assert.match(source, /\/admin\/accounts/);
  assert.match(source, /pageSize/);
  assert.match(source, /不是全平台合计|当前页已加载账户|当前页账户资产/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /submittingRef\.current/);
  assert.match(source, /\/admin\/accounts\/\$\{adjustment\.accountNumber\}\/\$\{adjustment\.direction\}/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.doesNotMatch(source, /客户总资产/);
  assert.doesNotMatch(source, /`\+91 \$\{/);
  assert.doesNotMatch(source, VIP_SPECIAL);
});

test('J.4 transactions use server pagination and mask phones', () => {
  const source = read('../app/transactions/page.tsx');
  assert.match(source, /\/admin\/accounts\/transactions/);
  assert.match(source, /pagination\?\.total/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /LOADED_FILTER_CAPTION/);
  assert.match(source, /OpsEmpty/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.doesNotMatch(source, /查看所有客户账户/);
  assert.doesNotMatch(source, /`\+91 \$\{/);
});

test('J.4 deposits create reloads from server, blocks double submit, and does not show success on failure', () => {
  const source = read('../app/deposits/page.tsx');
  const create = source.slice(source.indexOf('async function createTopUp'), source.indexOf('const showActions'));
  assert.match(create, /creatingRef\.current/);
  assert.match(create, /\/admin\/accounts\/\$\{accountNumber\}\/credit/);
  assert.match(create, /await load\(\)/);
  assert.match(create, /message\.success/);
  assert.match(create, /message\.error/);
  const successIndex = create.indexOf('message.success');
  const loadIndex = create.indexOf('await load()');
  const catchIndex = create.indexOf('} catch');
  assert.ok(successIndex > -1 && loadIndex > successIndex && loadIndex < catchIndex);
  assert.ok(create.indexOf('message.success', catchIndex) === -1);
  assert.match(source, /processing\.current/);
  assert.doesNotMatch(source, /setRows\(.*APPROVED/);
});

test('J.4 approvals keep type, status and decision separate', () => {
  const source = read('../app/approvals/page.tsx');
  assert.match(source, /function approvalTypeCode/);
  assert.match(source, /title: "类型"/);
  assert.match(source, /title: "状态"/);
  assert.match(source, /UNAVAILABLE/);
  assert.match(source, /\/admin\/approvals\/\$\{selected\.id\}\/decision/);
  assert.match(source, /submittingRef\.current/);
  assert.doesNotMatch(source, /OpsStatusTag code=\{.*CREDIT \? "APPROVED"/);
  assert.doesNotMatch(source, /code=\{row\.action\.includes\("CREDIT"\) \? "APPROVED"/);
  assert.equal(opsStatusOf('CREDIT').label, '账户入金');
  assert.equal(opsStatusOf('DEBIT').label, '账户扣款');
  assert.equal(opsStatusOf('APPROVED').label, '已通过');
  assert.equal(opsStatusOf('REJECTED').label, '已拒绝');
  assert.notEqual(opsStatusOf('CREDIT').label, opsStatusOf('APPROVED').label);
  assert.notEqual(opsStatusOf('DEBIT').label, opsStatusOf('REJECTED').label);
});

test('J.4 VIP residual pages stay ordinary-tier surfaces', () => {
  const settings = read('../app/vip-settings/page.tsx');
  const clients = read('../app/vip-clients/page.tsx');
  const history = read('../app/vip-history/page.tsx');
  const team = read('../app/team-vip/page.tsx');
  const mine = read('../app/business-vip/page.tsx');
  for (const source of [settings, clients, history, team, mine]) {
    assert.match(source, /OpsPageHeader/);
    assert.doesNotMatch(source, VIP_SPECIAL);
    assert.doesNotMatch(source, /VIP 产品目录|Relationship Manager/);
  }
  assert.match(settings, /moneyKey/);
  assert.match(settings, /\/admin\/vip-tiers/);
  assert.match(clients, /\/admin\/vip-clients/);
  assert.match(history, /\/admin\/vip-history/);
  assert.match(team, /\/team\/vip-clients/);
  assert.match(mine, /allowAdjust/);
});

test('J.4 residual pages keep loading empty error retry, scroll and aria-labels', () => {
  const pages = [
    '../app/support-console/page.tsx',
    '../app/business-accounts/page.tsx',
    '../app/business-positions/page.tsx',
    '../app/business-institutional/page.tsx',
    '../app/watchlist/page.tsx',
    '../app/quant/page.tsx',
    '../app/team-assignments/page.tsx',
  ];
  for (const page of pages) {
    const source = read(page);
    assert.match(source, /OpsPageHeader|TeamAssignmentWorkspace/);
    if (page !== '../app/team-assignments/page.tsx') {
      assert.match(source, /OpsErrorState|OpsEmpty|aria-label=/);
    }
  }
  const assignment = read('../components/TeamAssignmentWorkspace.tsx');
  assert.match(assignment, /OpsPageHeader/);
  assert.match(assignment, /OpsErrorState/);
  assert.match(assignment, /aria-label="刷新团队归属"/);
  const watchlist = read('../app/watchlist/page.tsx');
  assert.match(watchlist, /Tooltip title="删除涨停股"/);
  assert.match(watchlist, /aria-label=\{`删除 \$\{record\.symbol\}`\}/);
  const accounts = read('../app/business-accounts/page.tsx');
  assert.match(accounts, /maskOpsPhone/);
  assert.match(accounts, /scroll=\{\{ x:/);
  const positions = read('../app/business-positions/page.tsx');
  assert.match(positions, /maskOpsPhone/);
  assert.doesNotMatch(positions, /`\+91/);
});

test('J.4 KYC review remains a dedicated review view without API changes', () => {
  const copy = read('../lib/kyc-review.ts');
  const modal = read('../components/KycReviewModal.tsx');
  assert.match(copy, /审核专用视图/);
  assert.match(copy, /六步/);
  assert.match(modal, /审核专用账号/);
  assert.match(modal, /kyc\/.*review|onSubmit/);
});

test('J.4 reduced motion still covers residual chrome', () => {
  const css = read('../app/globals.css');
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /\.ops-system-state \*/);
  assert.match(css, /\.ops-support-grid/);
  assert.match(css, /@media \(max-width:767px\)/);
  const eslint = read('../eslint.config.mjs');
  assert.match(eslint, /tmp\/\*\*/);
});
