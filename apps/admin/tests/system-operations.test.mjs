import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { opsPageForRoute, opsPagesForRole } from '../lib/ops-page-registry.ts';
import { permissionForAdminRoute } from '../lib/role-permissions.ts';

const root = fileURLToPath(new URL('.', import.meta.url));
const read = (path) => readFileSync(join(root, path), 'utf8');

test('system operations routes are ADMIN-only and registered with owners', () => {
  for (const route of ['/system-health', '/system-governance', '/system-deployments']) {
    const page = opsPageForRoute(route);
    assert.equal(page?.roles.includes('ADMIN'), true);
    assert.ok(page?.owner);
    assert.ok(page?.apiDependencies.length);
    assert.equal(permissionForAdminRoute(route), 'audit.read');
  }
  assert.equal(opsPagesForRole('FINANCE').some((page) => page.route.startsWith('/system-')), false);
});

test('system pages are read-only and expose no shell or secret values', () => {
  for (const path of [
    '../app/system-health/page.tsx',
    '../app/system-governance/page.tsx',
    '../app/system-deployments/page.tsx',
  ]) {
    const source = read(path);
    assert.doesNotMatch(source, /api\.(post|put|patch|delete)\(/);
    assert.doesNotMatch(source, /terminal|powershell|cmd\.exe|DATABASE_URL|JWT_SECRET/i);
  }
  assert.match(read('../app/system-health/page.tsx'), /OpsHealthPanel/);
  assert.match(read('../app/system-deployments/page.tsx'), /\/health\/version/);
});
