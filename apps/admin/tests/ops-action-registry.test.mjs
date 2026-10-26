import test from 'node:test';
import assert from 'node:assert/strict';

import { actionAllowed, opsActionRegistry } from '../lib/ops-action-registry.ts';

test('every registered mutation declares enterprise controls', () => {
  assert.ok(opsActionRegistry.length > 0);
  for (const action of opsActionRegistry.filter((entry) => entry.mutation)) {
    assert.equal(action.requiresReason, true, action.id);
    assert.equal(action.requiresConfirmation, true, action.id);
    assert.ok(action.idempotency, action.id);
    assert.ok(action.auditEvent, action.id);
    assert.ok(action.recovery, action.id);
    assert.ok(action.eligibleStates.length, action.id);
  }
});

test('KYC decisions keep current role and state boundaries', () => {
  assert.equal(actionAllowed('kyc.approve', 'BUSINESS', 'PENDING'), true);
  assert.equal(actionAllowed('kyc.reject', 'MANAGER', 'PENDING'), true);
  assert.equal(actionAllowed('kyc.approve', 'FINANCE', 'PENDING'), false);
  assert.equal(actionAllowed('kyc.reject', 'BUSINESS', 'APPROVED'), false);
});

test('read-only financial records never gain mutation actions', () => {
  assert.equal(actionAllowed('orders.view', 'FINANCE', 'OPEN'), true);
  assert.equal(actionAllowed('orders.cancel', 'FINANCE', 'OPEN'), false);
  assert.equal(actionAllowed('trades.edit', 'ADMIN', 'SETTLED'), false);
});
