import fs from 'node:fs';
import path from 'node:path';

const roots = ['apps/client/lib', 'apps/client/web'];
const forbidden = /\b(?:sandbox|staging|mock|demo|paper trading|internal matching|simulated trading)\b|沙盒|模拟交易|内部撮合|虚拟交易所|测试环境|人工撮合/iu;
const extensions = new Set(['.dart', '.html', '.js', '.jsx', '.ts', '.tsx', '.json']);
const violations = [];

function walk(directory) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filePath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(filePath);
    else if (extensions.has(path.extname(entry.name))) {
      const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
      lines.forEach((line, index) => {
        if (forbidden.test(line)) violations.push(`${filePath}:${index + 1}: ${line.trim()}`);
      });
    }
  }
}

roots.forEach(walk);
if (violations.length) {
  console.error('Customer-facing client copy contains an internal/testing term:');
  console.error(violations.join('\n'));
  process.exit(1);
}

console.log('Client copy policy passed: no internal, sandbox, simulation, or testing terms found.');
