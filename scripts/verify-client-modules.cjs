// Run against a built API tree: node scripts/verify-client-modules.cjs
// (cwd should be apps/api with dist/ present). Creates one isolated fixture
// account and removes only that account in finally.
const assert = require('node:assert/strict');
const { randomUUID, randomInt } = require('node:crypto');
const { PrismaClient } = require(process.cwd() + '/dist/generated/prisma/client.js');
const { PrismaPg } = require('@prisma/adapter-pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const OTPAuth = require('otpauth');
const sharp = require('sharp');
const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });
const id = randomUUID();
const email = `module-check-${id}@example.invalid`;
const phone = '9' + String(randomInt(0, 1_000_000_000)).padStart(9, '0');
const password = randomUUID();
let token;
async function request(path, method = 'GET', body, expected = 200, authenticated = true) {
  const response = await fetch('http://127.0.0.1:3000' + path, {
    method, headers: { 'Content-Type': 'application/json', ...(authenticated && token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const data = await response.json();
  assert.equal(response.status, expected, `${method} ${path}: ${data.message ?? response.status}`);
  return data;
}
async function main() {
  await db.user.create({ data: { id, email, phone, fullName: 'Module Verification', passwordHash: await bcrypt.hash(password, 12), role: 'CLIENT', status: 'ACTIVE', account: { create: { accountNumber: `TEST-${id}`, cashBalance: 100, buyingPower: 100, isLive: false } } } });
  token = jwt.sign({ sub: id, phone, role: 'CLIENT', version: 0 }, process.env.JWT_SECRET, { expiresIn: '10m' });
  const profile = await request('/client/profile');
  assert.equal(profile.clientTier, 'STANDARD');
  assert.equal(profile.email, undefined);
  await request(`/admin/clients/${id}/tier`, 'PATCH', { tier: 'GOLD' }, 403);
  await request('/client/preferences', 'PATCH', { language: 'hi', theme: 'highContrast' });
  const preferences = await request('/client/preferences');
  assert.equal(preferences.language, 'hi');
  assert.equal(preferences.theme, 'highContrast');
  const png = await sharp({ create: { width: 12, height: 12, channels: 3, background: '#009988' } }).png().toBuffer();
  await request('/client/profile/avatar', 'PATCH', { base64: png.toString('base64') });
  assert.ok((await request('/client/profile')).avatarData);
  const portfolio = await request('/client/portfolio/products?period=1M');
  assert.equal(portfolio.currentValue, 0);
  assert.equal(portfolio.positionCount, 0);
  assert.deepEqual(portfolio.categories.map(item => item.category), ['Institutional', 'OTC', 'IPO']);
  assert.equal(portfolio.history.points.at(-1).totalValue, 100);
  assert.equal(portfolio.history.points.at(-1).productValue, 0);
  const setup = await request('/client/security/two-factor/setup', 'POST', { currentPassword: password }, 201);
  const code = new OTPAuth.TOTP({ secret: OTPAuth.Secret.fromBase32(setup.secret) }).generate();
  const confirmed = await request('/client/security/two-factor/confirm', 'POST', { code }, 201);
  assert.equal(confirmed.recoveryCodes.length, 8);
  await request('/client/profile', 'GET', undefined, 401);
  const required = await request('/auth/login', 'POST', { phone, password }, 401, false);
  assert.equal(required.twoFactorRequired, true);
  const login = await request('/auth/login', 'POST', { phone, password, verificationCode: confirmed.recoveryCodes[0] }, 201, false);
  token = login.accessToken;
  assert.equal((await request('/client/security/two-factor')).recoveryCodesRemaining, 7);
  await request('/auth/login', 'POST', { phone, password, verificationCode: confirmed.recoveryCodes[0] }, 400, false);
  await request('/client/security/two-factor/disable', 'POST', { currentPassword: password, code: confirmed.recoveryCodes[1] }, 201);
  await request('/client/profile', 'GET', undefined, 401);
  const lastLogin = await request('/auth/login', 'POST', { phone, password }, 201, false);
  token = lastLogin.accessToken;
  assert.equal((await request('/client/security/two-factor')).enabled, false);
  console.log('PASS: profile, avatar, preferences, role restrictions, product portfolio, TOTP enrollment/login/recovery/disable and session revocation');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(async () => {
  const fixture = await db.user.findUnique({ where: { id }, select: { email: true } });
  if (fixture?.email === email) {
    await db.loginAudit.deleteMany({ where: { userId: id } });
    await db.user.delete({ where: { id } });
    console.log('Fixture account removed.');
  }
  await db.$disconnect();
});
