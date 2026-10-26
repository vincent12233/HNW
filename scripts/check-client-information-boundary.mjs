import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rules = [
  ['network-address', /(?:https?:\/\/|redis:\/\/|postgres(?:ql)?:\/\/|localhost|\bapi\.[a-z0-9.-]+)/i],
  ['database-detail', /\b(?:SQLSTATE|PostgreSQL|Prisma|MongoDB|database column|column [a-z][a-z0-9_]*)\b/i],
  ['internal-role', /\b(?:SUPER_ADMIN|ROOT_ADMIN|ADMIN_ROLE|INTERNAL_OPERATOR)\b/],
  ['raw-provider-detail', /\b(?:raw (?:provider|vendor|third[- ]party) (?:response|error|body)|providerBody)\b/i],
  ['environment-detail', /\b(?:production|staging|development)\s+(?:api|environment|server|database)\b/i],
  ['filesystem-path', /(?:[A-Za-z]:\\Users\\|\/(?:srv|var|home|Users)\/)/],
  ['fixture-detail', /\b(?:fixture data|mock backend|seed record)\b/i],
];

const customerSourceRoots = ['pages', 'widgets', 'l10n', 'theme'];

export function inspectCustomerSource(source, relativePath) {
  const findings = [];
  const lines = source.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    // Technical imports and comments are not rendered customer copy.
    if (/^\s*(?:import|export|part(?:\s+of)?)\b/.test(line) || /^\s*\/\//.test(line)) continue;
    for (const [rule, pattern] of rules) {
      if (pattern.test(line)) {
        findings.push({ file: relativePath, line: index + 1, rule });
      }
    }
  }
  return findings;
}

async function dartFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await dartFiles(absolute));
    else if (entry.name.endsWith('.dart')) files.push(absolute);
  }
  return files;
}

export async function scanCustomerSources(repoRoot = process.cwd()) {
  const libRoot = path.join(repoRoot, 'apps', 'client', 'lib');
  const files = (await Promise.all(
    customerSourceRoots.map((root) => dartFiles(path.join(libRoot, root))),
  )).flat();
  const findings = [];
  for (const file of files) {
    const relative = path.relative(path.join(repoRoot, 'apps', 'client'), file).replaceAll('\\', '/');
    findings.push(...inspectCustomerSource(await readFile(file, 'utf8'), relative));
  }
  return findings;
}

async function main() {
  const findings = await scanCustomerSources();
  if (findings.length > 0) {
    for (const finding of findings) {
      console.error(`${finding.file}:${finding.line} [${finding.rule}]`);
    }
    console.error(`Customer information boundary failed with ${findings.length} finding(s).`);
    process.exitCode = 1;
    return;
  }
  console.log('Customer information boundary passed.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
