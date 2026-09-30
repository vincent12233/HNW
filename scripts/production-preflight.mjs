import { readFileSync } from 'node:fs';
import { isAbsolute, resolve } from 'node:path';

const envPath = resolve(process.argv[2] ?? '.env.production');
const parseEnv = (text) => Object.fromEntries(
  text.split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#') && line.includes('='))
    .map((line) => {
      const index = line.indexOf('=');
      return [line.slice(0, index).trim(), line.slice(index + 1).trim().replace(/^['"]|['"]$/g, '')];
    }),
);

const env = { ...parseEnv(readFileSync(envPath, 'utf8')), ...process.env };
const errors = [];
const required = [
  'PUBLIC_API_URL', 'DATABASE_URL', 'RATE_LIMIT_REDIS_URL', 'PRIVATE_OBJECT_HOST_PATH',
  'JWT_SECRET', 'TWO_FACTOR_ENCRYPTION_KEY', 'OTC_KEY_ENCRYPTION_SECRET',
  'OBJECT_SIGNING_SECRET', 'ADMIN_FIXED_INVITE_CODE', 'ADMIN_INITIAL_PASSWORD',
  'MANAGER_INITIAL_PASSWORD', 'FINANCE_INITIAL_PASSWORD', 'BUSINESS_INITIAL_PASSWORD',
  'SUPPORT_INITIAL_PASSWORD', 'CORS_ORIGINS', 'MARKET_DATA_PROVIDER', 'VIRUS_SCAN_URL',
  'TRUST_PROXY_HOPS',
];

for (const key of required) {
  const value = env[key]?.trim();
  if (!value || /GENERATE_|SET_BY_|your-domain|PASSWORD@PRIVATE|LICENSED_PROVIDER/.test(value)) {
    errors.push(`${key} is missing or still uses an example value`);
  }
}

const assertHttps = (key, value) => {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || ['localhost', '127.0.0.1', '::1'].includes(url.hostname)) {
      errors.push(`${key} must be a public HTTPS URL`);
    }
  } catch {
    errors.push(`${key} must be a valid URL`);
  }
};

if (env.PUBLIC_API_URL) assertHttps('PUBLIC_API_URL', env.PUBLIC_API_URL);
if (env.VIRUS_SCAN_URL) assertHttps('VIRUS_SCAN_URL', env.VIRUS_SCAN_URL);
for (const origin of (env.CORS_ORIGINS ?? '').split(',').map((item) => item.trim()).filter(Boolean)) {
  assertHttps('CORS_ORIGINS entry', origin);
}

if ((env.MARKET_DATA_PROVIDER ?? '').toUpperCase() === 'YAHOO') {
  errors.push('MARKET_DATA_PROVIDER must be a licensed production provider, not YAHOO');
}
if (!/^\d+$/.test(env.TRUST_PROXY_HOPS ?? '') || Number(env.TRUST_PROXY_HOPS) > 5) {
  errors.push('TRUST_PROXY_HOPS must be an integer from 0 to 5');
}
const privateObjectPath = env.PRIVATE_OBJECT_HOST_PATH ?? '';
if (!(privateObjectPath.startsWith('/') || isAbsolute(privateObjectPath))) {
  errors.push('PRIVATE_OBJECT_HOST_PATH must be an absolute host path');
}

const secretKeys = [
  'JWT_SECRET', 'TWO_FACTOR_ENCRYPTION_KEY', 'OTC_KEY_ENCRYPTION_SECRET', 'OBJECT_SIGNING_SECRET',
];
const passwordKeys = [
  'ADMIN_INITIAL_PASSWORD', 'MANAGER_INITIAL_PASSWORD', 'FINANCE_INITIAL_PASSWORD',
  'BUSINESS_INITIAL_PASSWORD', 'SUPPORT_INITIAL_PASSWORD',
];
for (const key of secretKeys) {
  if ((env[key] ?? '').length < 32) errors.push(`${key} must contain at least 32 characters`);
}
for (const key of passwordKeys) {
  if ((env[key] ?? '').length < 12) errors.push(`${key} must contain at least 12 characters`);
}
const uniqueKeys = [...secretKeys, ...passwordKeys, 'ADMIN_FIXED_INVITE_CODE'];
const values = uniqueKeys.map((key) => env[key]).filter(Boolean);
if (new Set(values).size !== values.length) errors.push('Secrets, passwords, and invite code must all be different');
if ((env.ADMIN_FIXED_INVITE_CODE ?? '').length < 12) errors.push('ADMIN_FIXED_INVITE_CODE must contain at least 12 characters');

if (errors.length) {
  console.error('Production preflight failed:');
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(`Production preflight passed for ${envPath}`);
