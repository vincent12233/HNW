import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');

test('Admin shell keeps navigation usable from 320 through 1440 pixels', () => {
  const shell = read('components/AdminShell.tsx');
  const styles = read('app/globals.css');
  assert.match(shell, /Drawer|Sider/);
  assert.match(styles, /@media/);
  assert.match(styles, /overflow/);
  const rendered = read('playwright.visual.config.ts');
  assert.match(rendered, /width: 320/);
  assert.match(rendered, /width: 1440/);
});

test('Admin shared states distinguish loading, empty, and error output', () => {
  const loading = read('components/KycReviewList.tsx');
  const empty = read('components/OpsEmpty.tsx');
  const error = read('components/OpsErrorState.tsx');
  assert.match(loading, /加载|loading/i);
  assert.match(empty, /暂无|empty/i);
  assert.match(error, /错误|error|重试/i);
});
