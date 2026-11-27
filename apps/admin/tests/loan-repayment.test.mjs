import test from 'node:test';
import assert from 'node:assert/strict';
import { repaymentOperation } from '../lib/loan-repayment.ts';
test('loan repayment keeps its key and payload through ambiguous errors and reconstructed UI', () => {
  const data = new Map();
  const storage = { getItem: key => data.get(key), setItem: (key,value) => data.set(key,value), removeItem: key => data.delete(key) };
  const first = repaymentOperation(storage, 'loan');
  const sent = first.begin('100.00', 'cash received');
  const reopened = repaymentOperation(storage, 'loan');
  assert.deepEqual(reopened.read(), sent);
  assert.deepEqual(reopened.begin('100.00', 'cash received'), sent);
  assert.throws(() => reopened.begin('200.00', 'cash received'));
  reopened.complete();
  assert.notEqual(reopened.begin('100.00', 'cash received').requestId, sent.requestId);
  assert.equal(repaymentOperation(storage, 'another-loan').read(), null);
});
