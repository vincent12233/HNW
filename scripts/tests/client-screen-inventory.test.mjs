import assert from 'node:assert/strict';
import test from 'node:test';
import { verifyClientScreenInventory } from '../check-client-screen-inventory.mjs';

test('every Flutter page surface is registered for visual acceptance', async () => {
  const result = await verifyClientScreenInventory();
  assert.equal(result.count, 70);
});
