import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');

test('operator interfaces reject direct production deploy and rollback', () => {
  for (const path of ['scripts/ops/hnw-ops.ps1', 'scripts/ops/hnw-ops.sh']) {
    const source = read(path);
    assert.match(source, /production/);
    assert.match(source, /CI-only|CI environment approval|production deployment is CI-only/i);
    assert.match(source, /image.?digest/i);
  }
});

test('gateway bounds traffic and keeps its admin listener private', () => {
  const envoy = read('docker/gateway/envoy.yaml');
  assert.match(envoy, /max_request_bytes: 1048576/);
  assert.match(envoy, /request_headers_to_remove/);
  assert.match(envoy, /upgrade_type: websocket/);
  assert.match(envoy, /address: 127\.0\.0\.1, port_value: 9901/);
});

test('production workflows serialize deploy and rollback with approvals', () => {
  for (const path of [
    '.github/workflows/production-deploy.yml',
    '.github/workflows/production-rollback.yml',
  ]) {
    const workflow = read(path);
    assert.match(workflow, /group: hnw-production/);
    assert.match(workflow, /cancel-in-progress: false/);
    assert.match(workflow, /environment: production/);
    assert.match(workflow, /sha256:/);
  }
});
