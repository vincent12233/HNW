import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');

test('supply-chain workflow is least privilege and produces commit-bound evidence', () => {
  const workflow = read('.github/workflows/supply-chain-security.yml');
  assert.match(workflow, /permissions:\s*\n\s*contents: read/);
  assert.match(workflow, /security-events: write/);
  assert.match(workflow, /cyclonedx-npm/);
  assert.match(workflow, /gitleaks/);
  assert.match(workflow, /dependency-review-action@[0-9a-f]{40}/);
  assert.match(workflow, /\bfs --format sarif/);
  assert.match(workflow, /trivy/);
  assert.match(workflow, /GITHUB_SHA/);
  assert.match(workflow, /retention-days: 90/);
  assert.match(workflow, /severity: ['"]HIGH,CRITICAL['"]/);
  assert.match(workflow, /--exit-code 1/);
  assert.match(workflow, /aquasec\/trivy@sha256:[0-9a-f]{64}/);
  assert.doesNotMatch(workflow, /pull-requests: write/);
  assert.doesNotMatch(workflow, /contents: write/);
  assert.doesNotMatch(workflow, /uses:\s*[^\s]+@(v\d|\d+\.\d)/);
});

test('security policy documents SBOM and vulnerability evidence handling', () => {
  const policy = read('SECURITY.md');
  assert.match(policy, /SBOM/);
  assert.match(policy, /90 days|90 天/);
  assert.match(policy, /HIGH.*CRITICAL|High.*Critical/i);
  assert.match(policy, /false positive|误报/i);
});
