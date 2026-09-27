#!/usr/bin/env node
import fs from 'node:fs';

const coveragePath = new URL('../apps/api/coverage/coverage-final.json', import.meta.url);
if (!fs.existsSync(coveragePath)) {
  console.error('Missing apps/api/coverage/coverage-final.json; run npm run test:cov first.');
  process.exit(1);
}
const coverage = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
const groups = [
  { name: 'funds', dirs: ['account', 'deposit', 'withdrawal'], thresholds: { statements: 40, functions: 25, branches: 35 } },
  { name: 'orders', dirs: ['orders', 'trading'], thresholds: { statements: 50, functions: 40, branches: 40 } },
  { name: 'matching', dirs: ['matching'], thresholds: { statements: 70, functions: 75, branches: 65 } },
  { name: 'idempotency', dirs: ['common'], filePattern: /idempotency|operation-idempotency/, thresholds: { statements: 70, functions: 55, branches: 65 } },
];
const flatten = (value) => (Array.isArray(value) ? value.flat(Infinity) : [value]);
const percent = (hit, total) => (total ? (hit / total) * 100 : 100);
let failed = false;
for (const group of groups) {
  const files = Object.values(coverage).filter((entry) => {
    const normalized = entry.path.split('\\').join('/');
    const inDirectory = group.dirs.some((dir) => normalized.includes(`/src/${dir}/`));
    return inDirectory && (!group.filePattern || group.filePattern.test(normalized));
  });
  const totals = { statements: [0, 0], functions: [0, 0], branches: [0, 0] };
  for (const file of files) {
    for (const [metric, key] of [['statements', 's'], ['functions', 'f'], ['branches', 'b']]) {
      const values = flatten(Object.values(file[key]));
      totals[metric][0] += values.filter((value) => value > 0).length;
      totals[metric][1] += values.length;
    }
  }
  if (!files.length) {
    console.error(`[${group.name}] no covered files found`);
    failed = true;
    continue;
  }
  const summary = Object.fromEntries(Object.entries(totals).map(([metric, [hit, total]]) => [metric, percent(hit, total)]));
  console.log(`[${group.name}] files=${files.length} statements=${summary.statements.toFixed(1)}% functions=${summary.functions.toFixed(1)}% branches=${summary.branches.toFixed(1)}%`);
  for (const [metric, minimum] of Object.entries(group.thresholds)) {
    if (summary[metric] < minimum) {
      console.error(`  ${metric} ${summary[metric].toFixed(1)}% < required ${minimum}%`);
      failed = true;
    }
  }
}
if (failed) process.exit(1);
console.log('Directory coverage thresholds passed.');


