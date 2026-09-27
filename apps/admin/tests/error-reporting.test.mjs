import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

test('admin API failures use the privacy-safe reporting abstraction', () => {
  const api = readFileSync(join(root, '../lib/api.ts'), 'utf8');
  const reporter = readFileSync(join(root, '../lib/error-report.ts'), 'utf8');
  assert.match(api, /reportAdminError\(error/);
  assert.match(reporter, /admin-error-report/);
  assert.match(reporter, /observability\/client-errors/);
  assert.match(reporter, /keepalive: true/);
  assert.match(reporter, /\[REDACTED\]/);
  assert.match(reporter, /\[EMAIL\]/);
  assert.match(reporter, /\[PHONE\]/);
  assert.doesNotMatch(reporter, /console\.(log|warn|error)/);
});