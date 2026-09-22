import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  aboutFields,
  depositFields,
  homeFields,
  homeLegacyFields,
  insightArticleKeys,
  insightIntroFields,
  supportFields,
  supportQuickReplies,
  supportTagField,
  tradingFields,
  tradingLegacyFields,
} from '../app/app-content/fields.ts';

const root = dirname(fileURLToPath(import.meta.url));

function keysOf(fields) {
  return new Set(fields.map((field) => field.key));
}

function apiDefaultKeys() {
  const source = readFileSync(
    join(root, '../../api/src/app-content/app-content.defaults.ts'),
    'utf8',
  );
  const byModule = new Map();
  const rows = source.matchAll(
    /module:\s*AppContentModule\.(\w+),[\s\S]*?key:\s*'([^']+)',[\s\S]*?locale:\s*'([^']+)'/g,
  );
  for (const [, module, key] of rows) {
    if (!byModule.has(module)) byModule.set(module, new Set());
    byModule.get(module).add(key);
  }
  return byModule;
}

test('every API App Content default has a Super Admin editor field', () => {
  const adminKeys = new Map([
    ['HOME', keysOf([...homeFields, ...homeLegacyFields])],
    ['DEPOSIT', keysOf(depositFields)],
    [
      'SUPPORT',
      keysOf([...supportFields, supportTagField, ...supportQuickReplies]),
    ],
    ['TRADING', keysOf([...tradingFields, ...tradingLegacyFields])],
    ['ABOUT', keysOf(aboutFields)],
    ['LEGAL', new Set(['privacy.document', 'terms.document', 'risk.document'])],
    ['INSIGHTS', keysOf([...insightIntroFields, ...insightArticleKeys.map((key) => ({ key }))])],
  ]);

  for (const [module, apiKeys] of apiDefaultKeys()) {
    const editable = adminKeys.get(module);
    assert.ok(editable, `Missing Super Admin module editor for ${module}`);
    const missing = [...apiKeys].filter((key) => !editable.has(key));
    assert.deepEqual(missing, [], `${module} keys missing from Super Admin`);
  }
});
