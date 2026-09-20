import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

test('admin assignment workspace confirms before writing and does not drag-transfer', () => {
  const source = readFileSync(
    join(root, '../components/TeamAssignmentWorkspace.tsx'),
    'utf8',
  );
  assert.match(source, /\/admin\/business-assignments\/preview/);
  assert.match(source, /\/admin\/business-assignments\/transfer/);
  assert.match(source, /idempotencyKey/);
  assert.match(source, /expectedCurrentManagerId/);
  assert.match(source, /客户仍归属于该业务员/);
  assert.match(source, /旧管理员将失去团队可见性/);
  assert.match(source, /savingRef/);
  assert.doesNotMatch(source, /onDrag|draggable|DndContext|useDrop/);
  assert.match(source, /aria-label/);
});

test('manager team page stays read-only for assignment writes', () => {
  const source = readFileSync(join(root, '../app/team/page.tsx'), 'utf8');
  assert.match(source, /\/team\/assignment-history/);
  assert.match(source, /VIP 客户/);
  assert.doesNotMatch(source, /\/admin\/business-assignments\/transfer/);
  assert.doesNotMatch(source, />转移</);
});

test('assignment CSS honors reduced motion', () => {
  const source = readFileSync(join(root, '../app/globals.css'), 'utf8');
  assert.match(source, /prefers-reduced-motion/);
  assert.match(source, /assignment-workspace/);
  assert.match(source, /assignment-drawer/);
});
