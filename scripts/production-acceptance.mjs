#!/usr/bin/env node

import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEFAULT_REQUIREMENTS = Object.freeze({
  repository: [
    'acceptance-contracts',
    'protected-flow-contracts',
  ],
  environment: [
    'supply-chain-scan',
    'visual-evidence',
    'github-governance',
    'production-smoke',
    'capacity-run',
    'recovery-drill',
  ],
  external: [
    'kyc-provider',
    'market-data-provider',
    'exchange-clearing',
    'legal-compliance',
    'physical-device-acceptance',
  ],
});

const categories = ['repository', 'environment', 'external'];
const fullSha = /^[0-9a-f]{40}$/i;

function invalidReason(item, sha, category, name) {
  if (!item || item.category !== category || item.name !== name) return 'identity mismatch';
  if (item.sha !== sha) return `SHA mismatch: expected ${sha}, received ${item.sha ?? 'missing'}`;
  if (item.simulated !== false) return 'simulated or unclassified evidence is not accepted';
  if (item.passed !== true) return 'evidence did not pass';
  if (typeof item.source !== 'string' || item.source.trim().length < 3) return 'evidence source is missing';
  if (!item.observedAt || Number.isNaN(Date.parse(item.observedAt))) return 'observation time is invalid';
  return null;
}

export function aggregateEvidence({ sha, requirements = DEFAULT_REQUIREMENTS, evidence = [] }) {
  if (!fullSha.test(sha ?? '')) throw new Error('Acceptance requires a full Git SHA');
  const result = {
    schemaVersion: 1,
    sha,
    generatedAt: new Date().toISOString(),
    repositoryComplete: false,
    environmentComplete: false,
    externalComplete: false,
    productionComplete: false,
    categories: {},
  };

  for (const category of categories) {
    const required = [...new Set(requirements[category] ?? [])];
    const accepted = [];
    const missing = [];
    const invalid = [];
    for (const name of required) {
      const candidates = evidence.filter((item) => item?.category === category && item?.name === name);
      if (candidates.length === 0) {
        missing.push(name);
        continue;
      }
      const valid = candidates.find((item) => invalidReason(item, sha, category, name) === null);
      if (valid) {
        accepted.push({ name, source: valid.source, observedAt: valid.observedAt });
      } else {
        invalid.push({ name, reason: invalidReason(candidates[0], sha, category, name) });
      }
    }
    result.categories[category] = { required, accepted, missing, invalid };
    result[`${category}Complete`] = missing.length === 0 && invalid.length === 0;
  }
  result.productionComplete =
    result.repositoryComplete && result.environmentComplete && result.externalComplete;
  return result;
}

function parseArgs(argv) {
  const parsed = { gate: 'production' };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith('--')) throw new Error(`Unexpected argument: ${key}`);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) throw new Error(`Missing value for ${key}`);
    parsed[key.slice(2)] = value;
    index += 1;
  }
  if (!['repository', 'environment', 'external', 'production'].includes(parsed.gate)) {
    throw new Error('Gate must be repository, environment, external, or production');
  }
  return parsed;
}

function readEvidence(directory) {
  if (!directory) return [];
  return readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.json'))
    .flatMap((entry) => {
      const parsed = JSON.parse(readFileSync(join(directory, entry.name), 'utf8'));
      return Array.isArray(parsed) ? parsed : [parsed];
    });
}

function runCli() {
  const args = parseArgs(process.argv.slice(2));
  const requirements = args.requirements
    ? JSON.parse(readFileSync(args.requirements, 'utf8'))
    : DEFAULT_REQUIREMENTS;
  const report = aggregateEvidence({
    sha: args.sha,
    requirements,
    evidence: readEvidence(args['evidence-dir']),
  });
  const output = resolve(args.output ?? 'enterprise-acceptance.json');
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  const passed = args.gate === 'production' ? report.productionComplete : report[`${args.gate}Complete`];
  if (!passed) process.exitCode = 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
