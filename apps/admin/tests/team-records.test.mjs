import test from 'node:test';
import assert from 'node:assert/strict';
import { loadTeamRecords } from '../lib/team-records.ts';

test('accepts unpaginated KYC records', async () => {
  assert.deepEqual(await loadTeamRecords(async () => [{id: 'kyc'}]), [{id: 'kyc'}]);
});
test('loads every orders data page', async () => {
  const calls = [];
  const result = await loadTeamRecords(async page => {
    calls.push(page);
    return {data: [{id: page}], totalPages: 3};
  });
  assert.deepEqual(calls, [1, 2, 3]);
  assert.deepEqual(result, [{id: 1}, {id: 2}, {id: 3}]);
});
test('accepts empty and legacy items responses', async () => {
  assert.deepEqual(await loadTeamRecords(async () => ({data: [], totalPages: 0})), []);
  assert.deepEqual(await loadTeamRecords(async () => ({items: [{id: 1}]})), [{id: 1}]);
});
test('does not silently display partial data after a page failure', async () => {
  await assert.rejects(loadTeamRecords(async page => {
    if (page === 2) throw new Error('offline');
    return {data: [{id: 1}], totalPages: 2};
  }), /offline/);
});
test('stops when the user leaves the view', async () => {
  let active = true;
  let calls = 0;
  assert.deepEqual(await loadTeamRecords(async () => {
    calls++; active = false;
    return {data: [{id: 1}], totalPages: 2};
  }, () => active), []);
  assert.equal(calls, 1);
});
test('rejects malformed responses', async () => {
  await assert.rejects(loadTeamRecords(async () => ({totalPages: 1})), /Invalid/);
});
