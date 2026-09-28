import { readFile, readdir } from 'node:fs/promises';
import { extname, relative, resolve, sep } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const clientRoot = resolve(root, 'apps/client/lib');
const baseline = JSON.parse(
  await readFile(
    resolve(root, 'scripts/flutter-architecture-baseline.json'),
    'utf8',
  ),
);

const files = [];
async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (['generated', 'build'].includes(entry.name)) continue;
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) await visit(path);
    else if (entry.isFile() && extname(entry.name) === '.dart') files.push(path);
  }
}
await visit(clientRoot);

const normalized = (path) => relative(root, path).split(sep).join('/');
const directStorageAllowed = new Set([
  'apps/client/lib/services/secure_credential_store.dart',
]);
const visualExcluded = [
  '/theme/',
  '/painters/',
  'professional_chart_canvas.dart',
  'stock_history_chart.dart',
  'aadhaar_mark.dart',
];
const copyExcluded = ['/l10n/', '/models/', '/services/'];

const directSecureStorage = [];
let rawColorLines = 0;
let literalFontSizeLines = 0;
let userVisibleLiteralLines = 0;
for (const path of files) {
  const name = normalized(path);
  const source = await readFile(path, 'utf8');
  if (
    !directStorageAllowed.has(name) &&
    (source.includes('FlutterSecureStorage') ||
      source.includes('flutter_secure_storage/flutter_secure_storage.dart'))
  ) {
    directSecureStorage.push(name);
  }

  for (const line of source.split(/\r?\n/)) {
    const code = line.replace(/\/\/.*$/, '');
    if (!visualExcluded.some((part) => name.includes(part))) {
      if (/Color\(0x[0-9A-Fa-f]+\)|Colors\.(?!transparent\b)/.test(code)) {
        rawColorLines += 1;
      }
      if (/fontSize:\s*\d+(?:\.\d+)?\b/.test(code)) {
        literalFontSizeLines += 1;
      }
    }
    if (
      !copyExcluded.some((part) => name.includes(part)) &&
      /(?:\bText\(|labelText:|hintText:|helperText:|tooltip:|semanticLabel:)\s*(?:const\s+)?['"]/.test(
        code,
      ) &&
      !code.includes('AppText(') &&
      !code.includes('tr(')
    ) {
      userVisibleLiteralLines += 1;
    }
  }
}

const failures = [];
if (directSecureStorage.length) {
  failures.push(
    `FlutterSecureStorage must be accessed only through SecureCredentialStore:\n${directSecureStorage
      .map((path) => `  - ${path}`)
      .join('\n')}`,
  );
}
const counters = {
  rawColorLines,
  literalFontSizeLines,
  userVisibleLiteralLines,
};
for (const [key, current] of Object.entries(counters)) {
  const ceiling = baseline[key];
  if (!Number.isInteger(ceiling)) failures.push(`Missing integer baseline: ${key}`);
  else if (current > ceiling) failures.push(`${key} increased: ${current} > ${ceiling}`);
}

if (failures.length) {
  console.error('Flutter architecture guard failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log(
    `Flutter architecture guard passed (${Object.entries(counters)
      .map(([key, value]) => `${key}=${value}`)
      .join(', ')}).`,
  );
}
