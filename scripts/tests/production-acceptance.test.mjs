import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { aggregateEvidence } from '../production-acceptance.mjs';

const SHA = 'a'.repeat(40);

const evidence = (category, name, overrides = {}) => ({
  category,
  name,
  sha: SHA,
  passed: true,
  simulated: false,
  source: 'github-actions',
  observedAt: '2026-10-26T00:00:00.000Z',
  ...overrides,
});

const completeSet = () => [
  evidence('repository', 'automated-tests'),
  evidence('repository', 'supply-chain-scan'),
  evidence('environment', 'production-smoke'),
  evidence('environment', 'recovery-drill'),
  evidence('external', 'kyc-provider'),
  evidence('external', 'market-data-provider'),
  evidence('external', 'exchange-clearing'),
];

const requirements = {
  repository: ['automated-tests', 'supply-chain-scan'],
  environment: ['production-smoke', 'recovery-drill'],
  external: ['kyc-provider', 'market-data-provider', 'exchange-clearing'],
};

test('rejects stale evidence from another commit', () => {
  const items = completeSet();
  items[0] = evidence('repository', 'automated-tests', { sha: 'b'.repeat(40) });
  const report = aggregateEvidence({ sha: SHA, requirements, evidence: items });
  assert.equal(report.repositoryComplete, false);
  assert.match(report.categories.repository.invalid[0].reason, /SHA mismatch/);
});

test('reports missing artifacts by category without hiding the gap', () => {
  const report = aggregateEvidence({
    sha: SHA,
    requirements,
    evidence: completeSet().filter((item) => item.name !== 'recovery-drill'),
  });
  assert.equal(report.environmentComplete, false);
  assert.deepEqual(report.categories.environment.missing, ['recovery-drill']);
  assert.equal(report.productionComplete, false);
});

test('simulated evidence can never satisfy production acceptance', () => {
  const items = completeSet();
  items[4] = evidence('external', 'kyc-provider', { simulated: true, source: 'fixture' });
  const report = aggregateEvidence({ sha: SHA, requirements, evidence: items });
  assert.equal(report.externalComplete, false);
  assert.match(report.categories.external.invalid[0].reason, /simulated/);
});

test('is complete only when every required real artifact matches the exact SHA', () => {
  const report = aggregateEvidence({ sha: SHA, requirements, evidence: completeSet() });
  assert.equal(report.repositoryComplete, true);
  assert.equal(report.environmentComplete, true);
  assert.equal(report.externalComplete, true);
  assert.equal(report.productionComplete, true);
});

test('requires a full commit SHA', () => {
  assert.throws(
    () => aggregateEvidence({ sha: 'main', requirements, evidence: [] }),
    /full Git SHA/,
  );
});

test('CI preserves evidence and gates repository completion without claiming production completion', () => {
  const workflow = readFileSync(
    new URL('../../.github/workflows/enterprise-acceptance.yml', import.meta.url),
    'utf8',
  );
  assert.match(workflow, /permissions:\s*\n\s*contents: read/);
  assert.match(workflow, /--gate repository/);
  assert.match(workflow, /github\.sha/);
  assert.match(workflow, /simulated:\s*false/);
  assert.match(workflow, /retention-days: 90/);
  assert.doesNotMatch(workflow, /--gate production/);

  for (const file of ['../verify-all.ps1', '../verify-all.sh']) {
    assert.match(
      readFileSync(new URL(file, import.meta.url), 'utf8'),
      /production-acceptance\.test\.mjs/,
    );
  }
});
