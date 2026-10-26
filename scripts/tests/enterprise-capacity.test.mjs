import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateReport, percentile, runCapacity, validateConfig } from '../enterprise-capacity.mjs';

test('percentile uses the nearest-rank observation', () => {
  assert.equal(percentile([10, 20, 30, 40], 95), 40);
  assert.equal(percentile([30, 10, 20], 50), 20);
});

test('report fails when latency or error thresholds are exceeded', () => {
  const result = evaluateReport(
    { total: 100, failures: 3, durationsMs: [10, 20, 500] },
    { maxErrorRate: 0.01, maxP95Ms: 200 },
  );
  assert.equal(result.passed, false);
  assert.deepEqual(result.violations.sort(), ['errorRate', 'p95Ms']);
});

test('configuration requires an exact SHA and defaults to local targets', () => {
  assert.throws(() => validateConfig({ sha: 'short', baseUrl: 'http://127.0.0.1:3100' }), /full Git SHA/);
  assert.throws(
    () => validateConfig({ sha: 'a'.repeat(40), baseUrl: 'https://production.example' }),
    /non-local target/,
  );
  const config = validateConfig({ sha: 'a'.repeat(40), baseUrl: 'http://localhost:3100' });
  assert.equal(config.scenario, 'health-readiness');
  assert.equal(config.thresholds.maxErrorRate, 0.01);
});

test('explicit non-local execution still requires HTTPS', () => {
  assert.throws(
    () => validateConfig({ sha: 'a'.repeat(40), baseUrl: 'http://example.com', allowNonLocal: true }),
    /HTTPS/,
  );
});

test('rejects non-finite, non-positive, and out-of-range numeric configuration', () => {
  const base = { sha: 'a'.repeat(40), baseUrl: 'http://127.0.0.1:3100' };
  assert.throws(() => validateConfig({ ...base, concurrency: 'NaN' }), /concurrency/);
  assert.throws(() => validateConfig({ ...base, durationSeconds: 0 }), /durationSeconds/);
  assert.throws(() => validateConfig({ ...base, maxErrorRate: 2 }), /maxErrorRate/);
});

test('bounded runner records timeouts and dependency state', async () => {
  const config = validateConfig({
    sha: 'a'.repeat(40),
    baseUrl: 'http://127.0.0.1:3100',
    durationSeconds: 0.01,
    concurrency: 1,
    timeoutMs: 5,
  });
  const report = await runCapacity(config, async () => {
    await new Promise((resolve) => setTimeout(resolve, 20));
    throw new DOMException('timed out', 'TimeoutError');
  });
  assert.ok(report.totalRequests >= 1);
  assert.equal(report.failedRequests, report.totalRequests);
  assert.ok(report.timeouts >= 1);
  assert.equal(report.dependencyState.status, 'unobserved');
});

test('degradation scenarios require exact-SHA real scenario evidence', () => {
  const base = {
    sha: 'a'.repeat(40),
    baseUrl: 'http://127.0.0.1:3100',
    scenario: 'redis-degraded',
  };
  assert.throws(() => validateConfig(base), /scenario evidence/);
  assert.throws(
    () => validateConfig({ ...base, scenarioEvidence: { sha: 'b'.repeat(40), scenario: 'redis-degraded', simulated: false } }),
    /evidence SHA/,
  );
  const config = validateConfig({
    ...base,
    scenarioEvidence: {
      sha: 'a'.repeat(40), scenario: 'redis-degraded', simulated: false,
      dependencyState: { redis: 'degraded', database: 'healthy' },
      outboxBacklog: 0, financialIdempotencyVerified: true,
    },
  });
  assert.equal(config.scenarioEvidence.dependencyState.redis, 'degraded');
});
