import test from 'node:test';
import assert from 'node:assert/strict';

import {
  classifyOpsMutationFailure,
  validateOpsMutationIntent,
} from '../lib/ops-mutation-contract.ts';

test('writes require impact, reason, request id, and explicit confirmation', () => {
  assert.deepEqual(
    validateOpsMutationIntent({
      currentValue: 'PENDING',
      newValue: 'REJECTED',
      impact: 'Customer must resubmit KYC evidence',
      reason: 'PAN image is unreadable',
      requestId: 'ops-123',
      confirmed: true,
    }),
    [],
  );
  assert.deepEqual(
    validateOpsMutationIntent({
      currentValue: 'PENDING',
      newValue: 'REJECTED',
      impact: '',
      reason: 'x',
      requestId: '',
      confirmed: false,
    }),
    ['impact', 'reason', 'requestId', 'confirmation'],
  );
});

test('mutation failures never imply success and prescribe safe recovery', () => {
  assert.equal(classifyOpsMutationFailure({ status: 403 }).kind, 'denied');
  assert.equal(classifyOpsMutationFailure({ status: 409 }).refreshRequired, true);
  assert.equal(classifyOpsMutationFailure({ status: 429 }).retryable, true);
  assert.equal(classifyOpsMutationFailure({ code: 'ECONNABORTED' }).kind, 'unknown');
  assert.equal(classifyOpsMutationFailure({}).kind, 'failed');
  assert.match(classifyOpsMutationFailure({ code: 'ECONNABORTED' }).message, /刷新|确认/);
});
