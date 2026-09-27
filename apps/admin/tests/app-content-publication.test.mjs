import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

test('CMS exposes draft schedule expiry version and rollback controls', () => {
  const page = readFileSync(join(root, '../app/app-content/page.tsx'), 'utf8');
  assert.match(page, /publicationStatus/);
  assert.match(page, /SCHEDULED/);
  assert.match(page, /publishAt/);
  assert.match(page, /expiresAt/);
  assert.match(page, /version/);
  assert.match(page, /restoreRevision/);
  assert.match(page, /英文必填法律文档不能保存为草稿或删除/);
});
