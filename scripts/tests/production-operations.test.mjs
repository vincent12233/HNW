import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const script = join(process.cwd(), 'scripts', 'production-preflight.mjs');
const base = {
  PUBLIC_API_URL: 'https://api.hnw.test', DATABASE_URL: 'postgresql://user:password@db:5432/hnw?schema=public',
  RATE_LIMIT_REDIS_URL: 'redis://redis:6379', PRIVATE_OBJECT_HOST_PATH: '/srv/hnw/private-objects',
  JWT_SECRET: 'a'.repeat(32), TWO_FACTOR_ENCRYPTION_KEY: 'b'.repeat(32),
  OTC_KEY_ENCRYPTION_SECRET: 'c'.repeat(32), OBJECT_SIGNING_SECRET: 'd'.repeat(32),
  ADMIN_FIXED_INVITE_CODE: 'INVITE-CODE-123', ADMIN_INITIAL_PASSWORD: 'Admin-pass-123',
  MANAGER_INITIAL_PASSWORD: 'Manager-pass-123', FINANCE_INITIAL_PASSWORD: 'Finance-pass-123',
  BUSINESS_INITIAL_PASSWORD: 'Business-pass-123', SUPPORT_INITIAL_PASSWORD: 'Support-pass-123',
  CORS_ORIGINS: 'https://admin.hnw.test,https://manager.hnw.test', MARKET_DATA_PROVIDER: 'LICENSED_TEST',
  VIRUS_SCAN_URL: 'https://scanner.hnw.test/scan', TRUST_PROXY_HOPS: '1',
};
const run = (overrides = {}) => {
  const directory = mkdtempSync(join(tmpdir(), 'hnw-preflight-'));
  const file = join(directory, '.env.production');
  writeFileSync(file, Object.entries({ ...base, ...overrides }).map(([key, value]) => `${key}=${value}`).join('\n'));
  return spawnSync(process.execPath, [script, file], { encoding: 'utf8', env: {} });
};

test('accepts a complete production configuration', () => assert.equal(run().status, 0));
test('rejects development market provider', () => assert.notEqual(run({ MARKET_DATA_PROVIDER: 'YAHOO' }).status, 0));
test('rejects reused secrets', () => assert.notEqual(run({ OBJECT_SIGNING_SECRET: 'a'.repeat(32) }).status, 0));
test('rejects non-HTTPS API URL', () => assert.notEqual(run({ PUBLIC_API_URL: 'http://localhost:3000' }).status, 0));

const readRepoFile = (path) => readFileSync(join(process.cwd(), path), 'utf8');

test('production Compose keeps operations explicit and containers hardened', () => {
  const compose = readRepoFile('compose.production.yaml');
  assert.ok(compose.includes('profiles: ["operations"]'));
  assert.ok(compose.includes('profiles: ["initialization"]'));
  assert.match(compose, /no-new-privileges:true/);
  assert.match(compose, /cap_drop:\s*\n\s*- ALL/);
  assert.doesNotMatch(compose, /ports:/);
});

test('production deployment requires manual dispatch and protected environment', () => {
  const workflow = readRepoFile('.github/workflows/production-deploy.yml');
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /environment: production/);
  assert.match(workflow, /confirm_sha/);
  assert.match(workflow, /COOLIFY_DEPLOY_WEBHOOK/);
  assert.match(workflow, /post-deploy-smoke\.mjs/);
  assert.doesNotMatch(workflow, /^\s*push:/m);
});

test('beginner guide documents approval, rollback, and restore drills', () => {
  const guide = readRepoFile('docs/小白部署与运维手册.md');
  assert.match(guide, /所有必需 CI 变绿/);
  assert.match(guide, /回滚到上一个成功版本/);
  assert.match(guide, /恢复演练/);
});
