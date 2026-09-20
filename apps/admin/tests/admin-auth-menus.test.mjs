import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

test('staff login currently uses employeeNo and password, not OTP', () => {
  const source = readFileSync(join(root, '../app/login/page.tsx'), 'utf8');
  assert.match(source, /type Values = \{ employeeNo: string; password: string \}/);
  assert.match(source, /name="employeeNo"/);
  assert.match(source, /name="password"/);
  assert.match(source, /\/auth\/login/);
  assert.match(source, /员工工作台/);
  assert.match(source, /Input.Password/);
  assert.match(source, /EyeInvisibleOutlined/);
  assert.doesNotMatch(source, /smsOtp|verificationCode|\bOTP\b/);
  assert.doesNotMatch(source, /totp|authenticator/i);
  assert.doesNotMatch(source, /3002|3004|3005|3006|3007/);
  assert.doesNotMatch(source, /accessToken|staff_access_/);
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
  const financeBlock = block.slice(block.indexOf('FINANCE:'), block.indexOf('SUPPORT:'));
  assert.doesNotMatch(financeBlock, /\/vip-/);
  const supportBlock = block.slice(block.indexOf('SUPPORT:'));
  assert.doesNotMatch(supportBlock, /\/vip-/);
});

test('deployment role mapping currently isolates the five consoles', () => {
  const source = readFileSync(join(root, '../lib/backend-role.ts'), 'utf8');
  assert.match(source, /"3002": "ADMIN"/);
  assert.match(source, /"3004": "MANAGER"/);
  assert.match(source, /"3005": "FINANCE"/);
  assert.match(source, /"3006": "BUSINESS"/);
  assert.match(source, /"3007": "SUPPORT"/);
});
