import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { maskBankAccount, maskOpsPhone } from '../lib/ops-directory.ts';
import { opsStatusOf } from '../lib/ops-status.ts';
import {
  GOVERNANCE_COPY,
  UNAVAILABLE,
  governanceWorkflowForRole,
  healthCodeFromProbe,
  sanitizeGovernanceMetadata,
  sanitizeGovernanceValue,
} from '../lib/ops-governance.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const PII_LOG = /console\.(log|debug|info|warn|error)\([^)]*(phone|accountNumber|token|stack)/i;
const VIP_SPECIAL = /VIP 优先|VIP限额|vipPriority|自动升级|客户经理/;
const AUTH_INVENT = /smsOtp|verificationCode|\bOTP\b|totp|authenticator|2FA/i;
const DANGER_HEALTH = /重启服务|清缓存|auto-repair|replayAudit|删除审计/;

test('G.5 governance role allowlist keeps audit and settings on ADMIN only', () => {
  assert.equal(governanceWorkflowForRole('ADMIN').auditPage, '/audit-logs');
  assert.equal(governanceWorkflowForRole('ADMIN').healthPage, '/market');
  assert.equal(governanceWorkflowForRole('ADMIN').canMutateContent, true);
  assert.equal(governanceWorkflowForRole('MANAGER').auditPage, null);
  assert.equal(governanceWorkflowForRole('FINANCE').settingsPage, null);
  assert.equal(governanceWorkflowForRole('SUPPORT').announcementsPage, null);
  assert.equal(governanceWorkflowForRole('BUSINESS').canDecideApprovals, false);
  const shell = read('../components/AdminShell.tsx');
  const block = shell.slice(shell.indexOf('const menus: Record<Role, MenuItemDef[]>'), shell.indexOf('const menuGroups'));
  const admin = block.slice(block.indexOf('ADMIN:'), block.indexOf('MANAGER:'));
  const finance = block.slice(block.indexOf('FINANCE:'), block.indexOf('SUPPORT:'));
  const support = block.slice(block.indexOf('SUPPORT:'));
  assert.match(admin, /\/audit-logs/);
  assert.match(admin, /\/announcements/);
  assert.match(admin, /\/app-settings/);
  assert.doesNotMatch(admin, /\/operator-console/);
  assert.doesNotMatch(finance, /\/audit-logs/);
  assert.doesNotMatch(finance, /\/announcements/);
  assert.doesNotMatch(support, /\/app-settings/);
  assert.match(support, /\/operator-console/);
  assert.doesNotMatch(support, /客户经理/);
});

test('G.5 audit metadata sanitizes secrets, phones and accounts', () => {
  const rows = sanitizeGovernanceMetadata({
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.aaa',
    password: 'secret-pass',
    jwt: 'header.payload.sig',
    cookie: 'sid=abc',
    phone: '9876543210',
    accountNumber: '1234567890123456',
    ifsc: 'HDFC0001234',
    title: 'loan approved',
    empty: '',
  });
  const byKey = Object.fromEntries(rows.map((row) => [row.key, row.value]));
  assert.equal(byKey.token, '••••');
  assert.equal(byKey.password, '••••');
  assert.equal(byKey.jwt, '••••');
  assert.equal(byKey.cookie, '••••');
  assert.equal(byKey.phone, maskOpsPhone('9876543210'));
  assert.equal(byKey.accountNumber, maskBankAccount('1234567890123456'));
  assert.equal(byKey.ifsc, '••••');
  assert.equal(byKey.title, 'loan approved');
  assert.equal(byKey.empty, UNAVAILABLE);
  assert.equal(sanitizeGovernanceValue('unknown', null), UNAVAILABLE);
  assert.match(GOVERNANCE_COPY.loadedFilter, /不是新的服务端权限查询/);
});

test('G.5 health mapping stays honest and does not invent uptime', () => {
  assert.equal(healthCodeFromProbe({ failed: true }), 'UNAVAILABLE');
  assert.equal(healthCodeFromProbe({ stale: true }), 'DEGRADED');
  assert.equal(healthCodeFromProbe({ status: 'ok' }), 'HEALTHY');
  assert.equal(healthCodeFromProbe({ status: 'ready' }), 'HEALTHY');
  assert.equal(healthCodeFromProbe({ healthy: true }), 'HEALTHY');
  assert.equal(healthCodeFromProbe({ healthy: false }), 'DEGRADED');
  assert.equal(healthCodeFromProbe({ status: 'open' }), 'UNKNOWN');
  assert.equal(healthCodeFromProbe({}), 'UNKNOWN');
  assert.equal(opsStatusOf('HEALTHY').label, 'Healthy');
  assert.equal(opsStatusOf('DEGRADED').tone, 'warning');
  assert.equal(opsStatusOf('UNAVAILABLE').label, 'Unavailable');
  assert.equal(opsStatusOf('UNKNOWN').label, 'Unknown');
  const health = read('../components/OpsHealthPanel.tsx');
  assert.match(health, /if \(inflight\.current\) return/);
  assert.match(health, /\/health\/ready/);
  assert.match(health, /\/market-data\/health/);
  assert.match(health, /code: "UNKNOWN"/);
  assert.doesNotMatch(health, /uptime|成功率|setInterval/);
  assert.doesNotMatch(health, DANGER_HEALTH);
  assert.doesNotMatch(health, PII_LOG);
});

test('G.5 audit workspace is read-only chrome over GET /admin/audit-logs', () => {
  const source = read('../app/audit-logs/page.tsx');
  assert.match(source, /\/admin\/audit-logs/);
  assert.match(source, /OpsDrawer/);
  assert.match(source, /OpsEmpty/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /sanitizeGovernanceMetadata/);
  assert.match(source, /scroll=\{\{ x: 1280 \}/);
  assert.match(source, /aria-label="查询审计日志"/);
  assert.match(source, /筛选已加载的操作人或说明/);
  assert.doesNotMatch(source, /api\.(patch|post|put|delete)/);
  assert.doesNotMatch(source, /重新执行|删除日志|replay/);
  assert.doesNotMatch(source, /JSON\.stringify\(.*metadata/);
  assert.doesNotMatch(source, PII_LOG);
  assert.doesNotMatch(source, VIP_SPECIAL);
});

test('G.5 announcements and insights keep existing CRUD and confirm before mutate', () => {
  const announcements = read('../app/announcements/page.tsx');
  const insights = read('../app/insights/page.tsx');
  assert.match(announcements, /\/admin\/announcements/);
  assert.match(announcements, /savingRef\.current/);
  assert.match(announcements, /确认发布公告/);
  assert.match(announcements, /OpsDrawer/);
  assert.match(announcements, /message\.success\("已保存"\)/);
  assert.match(announcements, /await load\(\)/);
  assert.doesNotMatch(announcements, /阅读量|送达率/);
  assert.match(insights, /\/admin\/insights/);
  assert.match(insights, /savingRef\.current/);
  assert.match(insights, /确认删除/);
  assert.doesNotMatch(insights, /阅读量|送达率/);
  assert.doesNotMatch(announcements, VIP_SPECIAL);
  assert.doesNotMatch(insights, PII_LOG);
});

test('G.5 settings, invites and operator console keep server scopes and mask PII', () => {
  const settings = read('../app/app-settings/page.tsx');
  const invites = read('../components/InvitePoolButton.tsx');
  const operator = read('../app/operator-console/page.tsx');
  const current = read('../components/CurrentInviteCode.tsx');
  assert.match(settings, /\/admin\/app-settings/);
  assert.match(settings, /savingRef\.current/);
  assert.match(settings, /危险配置确认/);
  assert.match(settings, /message\.success\("已保存"\)/);
  assert.doesNotMatch(settings, /NEXT_PUBLIC_|process\.env/);
  assert.match(invites, /\/business\/\$\{id\}\/invite-codes/);
  assert.match(invites, /busyRef\.current/);
  assert.match(invites, /确认生成/);
  assert.match(current, /\/business\/my-invite-code/);
  assert.match(current, /pending\.current/);
  assert.match(operator, /\/operator\/customers/);
  assert.match(operator, /maskOpsPhone/);
  assert.match(operator, /maskBankAccount/);
  assert.match(operator, /OpsEmpty/);
  assert.doesNotMatch(operator, /`\+91 \$\{/);
  assert.doesNotMatch(operator, /客户经理/);
  assert.doesNotMatch(settings, VIP_SPECIAL);
});

test('G.5 account, 403, 404 and global error states stay password-login only', () => {
  const shell = read('../components/AdminShell.tsx');
  const login = read('../app/login/page.tsx');
  const denied = read('../components/OpsPermissionDenied.tsx');
  const missing = read('../app/not-found.tsx');
  const crashed = read('../app/error.tsx');
  const api = read('../lib/api.ts');
  assert.match(shell, /确认退出登录/);
  assert.match(shell, /businessProfile\?\.employeeNo/);
  assert.match(shell, /\/login\?session=expired/);
  assert.doesNotMatch(shell, /user\.phone/);
  assert.ok(login.includes('params.get("session") !== "expired"'));
  assert.match(login, /员工编号和密码/);
  assert.doesNotMatch(login, AUTH_INVENT);
  assert.match(denied, /status="403"/);
  assert.match(denied, /没有访问该页面的权限/);
  assert.match(missing, /status="404"/);
  assert.match(crashed, /请重试当前页面/);
  assert.doesNotMatch(crashed, /error\.stack|error\.message/);
  assert.match(api, /\/login\?session=expired/);
});

test('G.5 approvals, company showcase and market health keep existing APIs', () => {
  const approvals = read('../app/approvals/page.tsx');
  const company = read('../app/company-showcase/page.tsx');
  const market = read('../app/market/page.tsx');
  assert.match(approvals, /\/admin\/approvals/);
  assert.match(approvals, /\/admin\/approvals\/\$\{selected\.id\}\/decision/);
  assert.match(approvals, /submittingRef\.current/);
  assert.match(approvals, /maskBankAccount/);
  assert.match(company, /\/company-showcase\/admin/);
  assert.match(company, /savingRef\.current/);
  assert.match(market, /OpsHealthPanel/);
  assert.match(market, /\/admin\/market\/instruments/);
  assert.doesNotMatch(market, /uptime/);
  assert.doesNotMatch(approvals, VIP_SPECIAL);
});

test('G.5 reduced motion and overflow wrapping cover governance chrome', () => {
  const css = read('../app/globals.css');
  assert.match(css, /\.ops-health-panel/);
  assert.match(css, /\.ops-health-grid/);
  assert.match(css, /\.ops-wrap-text/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /\.ops-health-panel \*/);
  assert.match(css, /\.ops-system-state/);
  assert.match(css, /@media \(max-width:767px\)/);
});
