import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

test('staff login keeps employeeNo and password and adds mandatory authenticator enrollment', () => {
  const source = readFileSync(join(root, '../app/login/page.tsx'), 'utf8');
  assert.match(source, /employeeNo: string; password: string; verificationCode\?: string/);
  assert.match(source, /name="employeeNo"/);
  assert.match(source, /name="password"/);
  assert.match(source, /\/auth\/login/);
  assert.match(source, /员工工作台/);
  assert.match(source, /Input.Password/);
  assert.match(source, /EyeInvisibleOutlined/);
  assert.doesNotMatch(source, /smsOtp/);
  assert.match(source, /twoFactorSetupRequired/);
  assert.match(source, /\/auth\/staff-two-factor\/setup/);
  assert.match(source, /\/auth\/staff-two-factor\/confirm/);
  assert.match(source, /QRCode value=\{setupData\.uri\}/);
  assert.match(source, /Input\.OTP/);
  assert.match(source, /恢复码只显示一次/);
  assert.doesNotMatch(source, /3002|3004|3005|3006|3007/);
  assert.doesNotMatch(source, /accessToken|staff_access_/);
});

test('team UI exposes only the scoped authenticator reset endpoint', () => {
  const source = readFileSync(join(root, '../app/team/page.tsx'), 'utf8');
  assert.match(source, /\/team\/\$\{row\.id\}\/two-factor-reset/);
  assert.match(source, /下次登录必须重新绑定/);
  assert.doesNotMatch(source, /\/business\/\$\{row\.id\}\/two-factor-reset/);
});

test('each staff role menu is an allowlist and does not include F&O, GTT, or basket routes', () => {
  const source = readFileSync(join(root, '../components/AdminShell.tsx'), 'utf8');
  const block = source.slice(
    source.indexOf('const menus: Record<Role, MenuItemDef[]>'),
    source.indexOf('const menuGroups'),
  );
  for (const role of ['ADMIN', 'MANAGER', 'BUSINESS', 'FINANCE', 'SUPPORT']) {
    assert.match(block, new RegExp(`${role}: \\[`));
  }
  assert.match(block, /\/business-kyc/);
  assert.match(block, /\/withdrawals/);
  assert.doesNotMatch(block, /\/fno|\/gtt|\/basket/);
  assert.match(block, /\/vip-settings/);
  assert.match(block, /\/team-vip/);
  assert.match(block, /\/business-vip/);
  assert.match(block, /\/team-assignments/);
  const managerBlock = block.slice(block.indexOf('MANAGER:'), block.indexOf('BUSINESS:'));
  assert.doesNotMatch(managerBlock, /\/team-assignments/);
  assert.doesNotMatch(managerBlock, /Transfer/);
  const financeBlock = block.slice(block.indexOf('FINANCE:'), block.indexOf('SUPPORT:'));
  assert.doesNotMatch(financeBlock, /\/vip-/);
  assert.doesNotMatch(financeBlock, /\/team-assignments/);
  const supportBlock = block.slice(block.indexOf('SUPPORT:'));
  assert.doesNotMatch(supportBlock, /\/vip-/);
  assert.doesNotMatch(supportBlock, /\/team-assignments/);
});

test('deployment role mapping currently isolates the five consoles', () => {
  const source = readFileSync(join(root, '../lib/backend-role.ts'), 'utf8');
  assert.match(source, /"3002": "ADMIN"/);
  assert.match(source, /"3004": "MANAGER"/);
  assert.match(source, /"3005": "FINANCE"/);
  assert.match(source, /"3006": "BUSINESS"/);
  assert.match(source, /"3007": "SUPPORT"/);
});
