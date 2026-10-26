import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function percentile(values, percent) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.max(1, Math.ceil((percent / 100) * sorted.length));
  return sorted[rank - 1];
}

export function evaluateReport(samples, thresholds) {
  const errorRate = samples.total ? samples.failures / samples.total : 1;
  const p95Ms = percentile(samples.durationsMs, 95);
  const violations = [];
  if (errorRate > thresholds.maxErrorRate) violations.push('errorRate');
  if (p95Ms > thresholds.maxP95Ms) violations.push('p95Ms');
  return { errorRate, p50Ms: percentile(samples.durationsMs, 50), p95Ms, p99Ms: percentile(samples.durationsMs, 99), violations, passed: violations.length === 0 };
}

export function validateConfig(input) {
  if (!/^[0-9a-f]{40}$/.test(input.sha ?? '')) throw new Error('sha must be a full Git SHA');
  const target = new URL(input.baseUrl);
  const local = ['localhost', '127.0.0.1', '::1'].includes(target.hostname);
  if (!local && !input.allowNonLocal) throw new Error('non-local target requires --allow-non-local');
  if (!local && target.protocol !== 'https:') throw new Error('non-local target must use HTTPS');
  return {
    sha: input.sha,
    baseUrl: target.origin,
    path: input.path ?? '/health/ready',
    scenario: input.scenario ?? 'health-readiness',
    durationSeconds: Number(input.durationSeconds ?? 15),
    concurrency: Number(input.concurrency ?? 4),
    timeoutMs: Number(input.timeoutMs ?? 3000),
    thresholds: {
      maxErrorRate: Number(input.maxErrorRate ?? 0.01),
      maxP95Ms: Number(input.maxP95Ms ?? 500),
    },
  };
}

async function run(config) {
  const samples = { total: 0, failures: 0, durationsMs: [] };
  const deadline = Date.now() + config.durationSeconds * 1000;
  const worker = async () => {
    while (Date.now() < deadline) {
      const started = performance.now();
      samples.total += 1;
      try {
        const response = await fetch(`${config.baseUrl}${config.path}`, { signal: AbortSignal.timeout(config.timeoutMs), cache: 'no-store' });
        if (!response.ok) samples.failures += 1;
      } catch {
        samples.failures += 1;
      } finally {
        samples.durationsMs.push(Number((performance.now() - started).toFixed(2)));
      }
    }
  };
  await Promise.all(Array.from({ length: config.concurrency }, worker));
  const evaluation = evaluateReport(samples, config.thresholds);
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    sha: config.sha,
    scenario: config.scenario,
    target: `${config.baseUrl}${config.path}`,
    durationSeconds: config.durationSeconds,
    concurrency: config.concurrency,
    totalRequests: samples.total,
    failedRequests: samples.failures,
    thresholds: config.thresholds,
    ...evaluation,
  };
}

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (key === '--allow-non-local') result.allowNonLocal = true;
    else if (key.startsWith('--')) result[key.slice(2)] = argv[++index];
  }
  return result;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const config = validateConfig({ ...args, baseUrl: args.baseUrl ?? 'http://127.0.0.1:3100' });
    const report = await run(config);
    writeFileSync(args.report ?? 'enterprise-capacity-report.json', `${JSON.stringify(report, null, 2)}\n`);
    console.log(`Capacity scenario ${report.scenario}: ${report.passed ? 'PASS' : 'FAIL'} (${report.totalRequests} requests, p95 ${report.p95Ms}ms)`);
    if (!report.passed) process.exitCode = 1;
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
