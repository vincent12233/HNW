import test from 'node:test';
import assert from 'node:assert/strict';

import { missingLocaleKeys } from '../app/app-content/coverage.ts';

test('locale coverage counts saved, nonempty rows by module and language', () => {
  const entries = [
    { module: 'LEGAL', key: 'privacy.document', locale: 'en', body: '{"sections":[]}' },
    { module: 'LEGAL', key: 'privacy.document', locale: 'hi', body: '  ' },
    { module: 'ABOUT', key: 'terms.document', locale: 'hi', body: 'Other module' },
    { module: 'LEGAL', key: 'terms.document', locale: 'en', body: 'English only' },
  ];
  const keys = ['privacy.document', 'terms.document'];
  assert.deepEqual(missingLocaleKeys(entries, 'LEGAL', keys, 'en'), []);
  assert.deepEqual(missingLocaleKeys(entries, 'LEGAL', keys, 'hi'), keys);
});
