import { readFile, readdir } from 'node:fs/promises';
import { extname, relative, resolve, sep } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const rules = [
  { directory: 'apps/client/lib/pages', limit: 24 * 1024 },
  { directory: 'apps/client/lib/services', limit: 25 * 1024 },
  { directory: 'apps/api/src', limit: 30 * 1024 },
  { directory: 'apps/admin', limit: 52 * 1024 },
];
const ignoredSegments = new Set(['generated', 'node_modules', '.next', 'dist', 'coverage', 'test', 'tests']);
const ignoredNames = [/\.spec\.[cm]?[jt]s$/, /\.test\.[cm]?[jt]s$/, /\.defaults\./];
const sourceExtensions = new Set(['.dart', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs']);

async function visit(directory, limit, violations) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (ignoredSegments.has(entry.name)) continue;
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) {
      await visit(path, limit, violations);
      continue;
    }
    if (!entry.isFile() || !sourceExtensions.has(extname(entry.name))) continue;
    if (ignoredNames.some((pattern) => pattern.test(entry.name))) continue;
    const source = await readFile(path, 'utf8');
    const size = Buffer.byteLength(source.replace(/\r\n/g, '\n'));
    if (size > limit) violations.push({ path, size, limit });
  }
}

const violations = [];
for (const rule of rules) {
  await visit(resolve(root, rule.directory), rule.limit, violations);
}

if (violations.length > 0) {
  console.error('Oversized source files must be split into focused modules:');
  for (const violation of violations.sort((a, b) => b.size - a.size)) {
    const path = relative(root, violation.path).split(sep).join('/');
    console.error(`- ${path}: ${violation.size} bytes (limit ${violation.limit})`);
  }
  process.exitCode = 1;
} else {
  console.log('Source file size guard passed.');
}
