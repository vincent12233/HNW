import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

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
  const syntax = ts.createSourceFile('app-content.defaults.ts', source, ts.ScriptTarget.Latest, true);
  const byModule = new Map();
  const property = (node, name) => node.properties.find(
    (item) => ts.isPropertyAssignment(item) && item.name.getText(syntax) === name,
  )?.initializer;
  const visit = (node) => {
    if (ts.isObjectLiteralExpression(node)) {
      const module = property(node, 'module');
      const key = property(node, 'key');
      const locale = property(node, 'locale');
      if (module && ts.isPropertyAccessExpression(module) &&
          module.expression.getText(syntax) === 'AppContentModule' &&
          key && ts.isStringLiteral(key) && locale && ts.isStringLiteral(locale)) {
        const name = module.name.text;
        if (!byModule.has(name)) byModule.set(name, new Map());
        if (!byModule.get(name).has(key.text)) byModule.get(name).set(key.text, new Set());
        byModule.get(name).get(key.text).add(locale.text);
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(syntax);
  return byModule;
}

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

test('every API App Content default has a Super Admin editor field', () => {

  for (const [module, apiKeys] of apiDefaultKeys()) {
    const editable = adminKeys.get(module);
    assert.ok(editable, `Missing Super Admin module editor for ${module}`);
    const missing = [...apiKeys.keys()].filter((key) => !editable.has(key));
    assert.deepEqual(missing, [], `${module} keys missing from Super Admin`);
    if (!['LEGAL', 'ABOUT'].includes(module)) {
      for (const [key, locales] of apiKeys) {
        if (locales.has('zh')) continue;
        assert.deepEqual([...locales].sort(), ['en', 'hi'], `${module}:${key} locale coverage`);
      }
    }
  }
});

function* dartFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) yield* dartFiles(path);
    else if (entry.name.endsWith('.dart')) yield path;
  }
}

test('static Flutter content keys exist in API defaults and Super Admin', () => {
  const defaults = apiDefaultKeys();
  const references = [];
  for (const path of dartFiles(join(root, '../../client/lib'))) {
    const source = readFileSync(path, 'utf8');
    for (const [, module, key] of source.matchAll(
      /\.text\(\s*'(home|deposit|support|trading|legal|about|insights)'\s*,\s*'([^']+)'/g,
    )) references.push({ path, module: module.toUpperCase(), key });
    for (const [, key] of source.matchAll(/_marketCopy\(\s*'([^']+)'/g)) {
      references.push({ path, module: 'HOME', key });
    }
    for (const [, key] of source.matchAll(/_portfolioCopy\(\s*'([^']+)'/g)) {
      references.push({ path, module: 'TRADING', key });
    }
  }
  assert.ok(references.length > 0, 'No static Flutter content references found');
  for (const { path, module, key } of references) {
    assert.ok(defaults.get(module)?.has(key), `${path}: ${module}:${key} missing API default`);
    assert.ok(adminKeys.get(module)?.has(key), `${path}: ${module}:${key} missing editor`);
  }
});
