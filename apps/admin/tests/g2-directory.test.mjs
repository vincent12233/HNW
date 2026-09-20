import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  DIRECTORY_SCOPE_COPY,
  accountStatusLabel,
  filterLoadedRows,
  maskOpsPhone,
} from '../lib/ops-directory.ts';
import { opsStatusOf } from '../lib/ops-status.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const FORBIDDEN_ENTRY = /客户经理|服务请求|工单系统|Relationship Manager/;

test('phone masking never shows a full number', () => {
  assert.equal(maskOpsPhone('9876543210'), '******3210');
  assert.equal(maskOpsPhone('+91 98765 43210'), '******3210');
  assert.equal(maskOpsPhone('123'), '****');
  assert.equal(maskOpsPhone(null), '—');
});

test('loaded-row filters stay client-side and honest about missing values', () => {
  const rows = [
    { id: 'a', name: 'Alpha Client', phone: '1111222233' },
    { id: 'b', name: 'Beta', phone: '9999000011' },
  ];
  assert.equal(filterLoadedRows(rows, 'alpha', (row) => [row.name, row.id]).length, 1);
  assert.equal(filterLoadedRows(rows, '2233', (row) => [row.phone]).length, 1);
  assert.equal(filterLoadedRows(rows, '', (row) => [row.name]).length, 2);
  assert.equal(accountStatusLabel('ACTIVE'), '正常');
  assert.equal(opsStatusOf('NOT_SUBMITTED').label, '未提交');
});

test('admin customers page uses scoped list/overview APIs and display-only VIP', () => {
  const source = read(join('..', 'app/customers/page.tsx'));
  assert.match(source, /\/admin\/customers/);
  assert.match(source, /\/admin\/customers\/\$\{customer\.id\}\/overview/);
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsDrawer/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /OpsEmpty/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /LOADED_FILTER_CAPTION/);
  assert.match(source, /useDebouncedValue/);
  assert.match(source, /vipTierLabel/);
  assert.match(source, /DIRECTORY_SCOPE_COPY\.noKycOnList/);
  assert.doesNotMatch(source, /\/admin\/clients\/.*tier/);
  assert.doesNotMatch(source, /修改等级/);
  assert.doesNotMatch(source, /kind="tier"/);
  assert.doesNotMatch(source, FORBIDDEN_ENTRY);
  assert.doesNotMatch(source, /Aadhaar|PAN number|完整银行卡/);
});

test('business customers page keeps own-customer API and removes VIP write from the list', () => {
  const source = read(join('..', 'app/business-customers/page.tsx'));
  assert.match(source, /\/business\/my-customers/);
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /vipTierLabel/);
  assert.match(source, /kind="status"/);
  assert.doesNotMatch(source, /kind="tier"/);
  assert.doesNotMatch(source, /\/business\/customers\/\$\{record\.id\}\/tier/);
  assert.doesNotMatch(source, FORBIDDEN_ENTRY);
  assert.match(source, /DIRECTORY_SCOPE_COPY\.businessCustomers/);
});

test('business user list keeps enable/disable/password and does not invent manager stats', () => {
  const source = read(join('..', 'app/business-users/page.tsx'));
  assert.match(source, /\/business/);
  assert.match(source, /\/business\/\$\{record\.userId\}\/customers/);
  assert.match(source, /\/business\/\$\{record\.userId\}\/status/);
  assert.match(source, /reset-password/);
  assert.match(source, /OpsDrawer/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /当前接口未返回所属管理员/);
  assert.doesNotMatch(source, FORBIDDEN_ENTRY);
  assert.doesNotMatch(source, /kind="tier"/);
});

test('manager team page keeps assignment history read-only and types the customers view', () => {
  const source = read(join('..', 'app/team/page.tsx'));
  assert.match(source, /\/team\/assignment-history/);
  assert.match(source, /VIP 客户/);
  assert.match(source, /view === "customers"/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /只读客户范围/);
  assert.match(source, /客户在业务员转移后仍归属原业务员/);
  assert.doesNotMatch(source, /\/admin\/business-assignments\/transfer/);
  assert.doesNotMatch(source, />转移</);
  assert.doesNotMatch(source, FORBIDDEN_ENTRY);
  assert.match(source, /KycReviewList/);
  assert.match(source, /\/team\/\$\{member\.id\}\/\$\{view\}/);
});

test('directory pages do not replace server scope with a frontend-only IDOR check', () => {
  const customers = read(join('..', 'app/customers/page.tsx'));
  const team = read(join('..', 'app/team/page.tsx'));
  const mine = read(join('..', 'app/business-customers/page.tsx'));
  assert.doesNotMatch(customers, /filter\(\(customer\) => customer\.assignedBusinessId === currentUser/);
  assert.match(customers, /api\.get<Customer\[]>\("\/admin\/customers"\)/);
  assert.match(mine, /\/business\/my-customers/);
  assert.match(team, /api\.get\("\/team"\)/);
  assert.match(DIRECTORY_SCOPE_COPY.managerTeam, /403\/404/);
});

test('finance and support directory surfaces do not add VIP or team writes', () => {
  const customers = read(join('..', 'app/customers/page.tsx'));
  const mine = read(join('..', 'app/business-customers/page.tsx'));
  assert.match(customers, /DIRECTORY_SCOPE_COPY\.financeCustomers/);
  assert.doesNotMatch(customers, /api\.patch/);
  assert.doesNotMatch(mine, /kind="tier"/);
  assert.match(mine, /DIRECTORY_SCOPE_COPY\.supportCustomers/);
});

test('directory CSS clips long names and keeps reduced motion', () => {
  const css = read(join('..', 'app/globals.css'));
  assert.match(css, /\.ops-cell-clip/);
  assert.match(css, /\.ops-directory-panel \.ant-table-wrapper/);
  assert.match(css, /ant-table-thead > tr > th/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /border-radius: 8px/);
});

test('shared directory helper documents that filters are loaded-result only', () => {
  const source = read(join('..', 'lib/ops-directory.ts'));
  assert.match(source, /useDebouncedValue/);
  assert.match(source, /不是新的服务端查询/);
  assert.doesNotMatch(source, FORBIDDEN_ENTRY);
});
