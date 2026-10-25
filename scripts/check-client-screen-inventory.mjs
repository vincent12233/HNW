import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pagesDir = path.join(root, 'apps/client/lib/pages');
const manifestPath = path.join(root, 'scripts/client-screen-inventory.json');

export async function verifyClientScreenInventory() {
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const actual = (await readdir(pagesDir))
    .filter((name) => name.endsWith('.dart'))
    .map((name) => `apps/client/lib/pages/${name}`)
    .sort();
  const registered = manifest.surfaces
    .map((name) => `apps/client/lib/pages/${name}`)
    .sort();
  const missing = actual.filter((item) => !registered.includes(item));
  const stale = registered.filter((item) => !actual.includes(item));
  if (missing.length || stale.length) {
    throw new Error(
      `Client screen inventory is out of date. Missing: ${missing.join(', ') || 'none'}. Stale: ${stale.join(', ') || 'none'}.`,
    );
  }
  return { count: actual.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  verifyClientScreenInventory()
    .then(({ count }) => console.log(`Client screen inventory verified: ${count} surfaces.`))
    .catch((error) => {
      console.error(error.message);
      process.exitCode = 1;
    });
}
