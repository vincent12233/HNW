// Run inside the API container; all writes are isolated to disposable fixtures.
const assert = require('node:assert/strict');
const { randomUUID, randomBytes } = require('node:crypto');
const bcrypt = require('bcrypt');
const { PrismaClient } = require('/app/dist/src/generated/prisma/client.js');
const { PrismaPg } = require('@prisma/adapter-pg');
const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });
const ids = [];
const suffix = randomUUID().slice(0, 8).toUpperCase();
const password = randomBytes(3).toString('hex');
async function request(path, token, body, expected = 200, method) {
  const response = await fetch(`http://localhost:3000${path}`, {
    method: method ?? (body === undefined ? 'GET' : 'POST'),
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  assert.equal(response.status, expected, `${path}: unexpected HTTP status`);
  return response.json();
}
async function login(employeeNo) {
  return (await request('/auth/login', null, { employeeNo, password }, 201)).accessToken;
}
async function create(token, employeeNo, role) {
  const user = await request('/team', token, { employeeNo, fullName: 'Invite Pool Verification', password }, 201);
  ids.push(user.id);
  assert.equal(user.role, role);
  return { id: user.id, token: await login(employeeNo) };
}
(async () => {
  try {
    const rootNo = `CHECK_ROOT_${suffix}`;
    const root = await db.user.create({ data: {
      email: `${rootNo}@test.invalid`, fullName: 'Invite Pool Verification', role: 'ADMIN',
      passwordHash: await bcrypt.hash(password, 12), businessProfile: { create: { employeeNo: rootNo, isActive: true } },
    } });
    ids.push(root.id);
    const rootToken = await login(rootNo);
    const manager = await create(rootToken, `CHECK_MGR_${suffix}`, 'MANAGER');
    const other = await create(rootToken, `CHECK_OTHER_${suffix}`, 'MANAGER');
    const business = await create(manager.token, `CHECK_BIZ_${suffix}`, 'BUSINESS');
    await request('/business', rootToken, { employeeNo: 'NO_CREATE', fullName: 'Denied', password }, 403);
    for (const token of [rootToken, business.token]) {
      await request(`/business/${business.id}/invite-codes`, token, { count: 2 }, 403);
    }
    await request(`/business/${business.id}/invite-codes`, other.token, { count: 2 }, 404);
    await request(`/business/${business.id}/invite-codes`, manager.token, { count: 101 }, 400);
    assert.equal((await request('/business/my-invite-code', business.token)).code, null);
    assert.deepEqual(await request(`/business/${business.id}/invite-codes`, manager.token, { count: 2 }, 201), { count: 2 });
    const first = (await request('/business/my-invite-code', business.token)).code;
    const second = (await request(`/business/my-invite-code?previousId=${first.id}`, business.token)).code;
    assert.notEqual(first.id, second.id);
    assert.equal(await db.inviteCode.count({ where: { businessProfile: { userId: business.id }, status: 'UNUSED' } }), 2);
    await request('/business/invite-codes', business.token, undefined, 403);
    await request(`/business/invite-codes/${first.id}/disable`, rootToken, {}, 200, 'PATCH');
    assert.equal((await request(`/business/my-invite-code?previousId=${second.id}`, business.token)).code.id, second.id);
    assert.equal((await request('/business/my-dashboard', business.token)).unusedInviteCodes, 1);
    assert.equal((await db.inviteCode.findUnique({ where: { id: first.id } })).status, 'DISABLED');
    await db.inviteCode.update({ where: { id: first.id }, data: { expiresAt: new Date(0) } });
    assert.equal((await request(`/business/my-invite-code?previousId=${second.id}`, business.token)).code.id, second.id);
    await db.inviteCode.update({ where: { id: second.id }, data: { status: 'USED' } });
    assert.equal((await request('/business/my-invite-code', business.token)).code, null);
    console.log('PASS: six-character staff login, hierarchy, scoped pools, forbidden roles, refresh, expiry and empty state');
  } finally {
    if (ids.length) {
      await db.auditLog.deleteMany({ where: { actorId: { in: ids } } });
      for (const id of [...ids].reverse()) await db.user.delete({ where: { id } });
    }
    await db.$disconnect();
    console.log('Disposable verification accounts and their invite pools removed');
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
