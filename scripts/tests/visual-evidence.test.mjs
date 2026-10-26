import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');

test('Flutter visual capture covers narrow, phone, and tablet critical screens', () => {
  const source = read('apps/client/test/ui_capture_test.dart');
  for (const width of ['320', '390', '768']) assert.match(source, new RegExp(`Size\\(${width},`));
  for (const screen of ['login', 'register', 'kyc', 'home', 'trade', 'portfolio']) {
    assert.match(source, new RegExp(`'${screen}'`));
  }
  const workflow = read('.github/workflows/flutter-ci.yml');
  assert.match(workflow, /UI_CAPTURE_DIR/);
  assert.match(workflow, /flutter-visual-evidence/);
  const states = read('apps/client/test/enterprise_visual_states_test.dart');
  for (const state of ['loading', 'empty', 'offline-error', 'kyc-pending']) assert.match(states, new RegExp(state));
  assert.match(workflow, /enterprise_visual_states_test\.dart/);
  assert.match(workflow, /retention-days: 30/);
});

test('PWA visual evidence captures phone and desktop output', () => {
  const spec = read('tests/web-pwa/enterprise-visual.spec.ts');
  assert.match(spec, /India Trading/);
  assert.match(spec, /page\.screenshot/);
  const workflow = read('.github/workflows/web-pwa-ci.yml');
  assert.match(workflow, /pwa-visual-evidence/);
  assert.match(workflow, /test-results/);
});

test('Admin retains responsive and failure-state contracts', () => {
  const contract = read('apps/admin/tests/enterprise-visual-contract.test.mjs');
  assert.match(contract, /320/);
  assert.match(contract, /1440/);
  assert.match(contract, /loading|加载/);
  assert.match(contract, /error|错误/);
  const workflow = read('.github/workflows/admin-ci.yml');
  assert.match(workflow, /npm run test:visual/);
  assert.match(workflow, /admin-visual-evidence/);
});
