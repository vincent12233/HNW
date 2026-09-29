import assert from 'node:assert/strict';
import test from 'node:test';
import { hasAdminPermission, permissionForAdminRoute, rolePermissions } from '../lib/role-permissions.ts';

test('role permission matrix keeps write boundaries explicit', () => {
  assert.equal(hasAdminPermission('ADMIN', 'cms.write'), true);
  assert.equal(hasAdminPermission('MANAGER', 'cms.write'), false);
  assert.equal(hasAdminPermission('FINANCE', 'withdrawals.review'), true);
  assert.equal(hasAdminPermission('BUSINESS', 'funds.write'), false);
  assert.equal(rolePermissions.SUPPORT.includes('orders.read'), true);
});

test('route permission mapping covers sensitive Admin surfaces', () => {
  assert.equal(permissionForAdminRoute('/app-content'), 'cms.write');
  assert.equal(permissionForAdminRoute('/team'), 'customers.read');
  assert.equal(permissionForAdminRoute('/team-assignments/preview'), 'team.manage');
  assert.equal(permissionForAdminRoute('/unknown'), undefined);
});