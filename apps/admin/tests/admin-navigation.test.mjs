import test from 'node:test';
import assert from 'node:assert/strict';
import { findNavigationItem } from '../lib/admin-navigation.ts';

const items = [
  { key: '/team?view=customers' },
  { key: '/team?view=deposits' },
  { key: '/team?view=team' },
  { key: '/orders' },
];

test('keeps the correct manager view selected with unrelated filters and reordered parameters', () => {
  assert.equal(findNavigationItem(items, '/team?page=2&view=deposits')?.key, '/team?view=deposits');
});

test('matches the actual default team view instead of the first manager item', () => {
  assert.equal(findNavigationItem(items, '/team')?.key, '/team?view=team');
});

test('matches detail routes and avoids paths that only share a prefix', () => {
  assert.equal(findNavigationItem(items, '/orders/123?tab=history')?.key, '/orders');
  assert.equal(findNavigationItem(items, '/orders-archive'), undefined);
});

test('does not highlight an unrelated manager view for an unknown view', () => {
  assert.equal(findNavigationItem(items, '/team?view=unknown'), undefined);
});
