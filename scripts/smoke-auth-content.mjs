import assert from 'node:assert/strict';

const baseUrl = process.env.HNW_SMOKE_API_URL || 'http://127.0.0.1:3100';
const password = process.env.HNW_SMOKE_ADMIN_PASSWORD;
if (!password) throw new Error('HNW_SMOKE_ADMIN_PASSWORD is required');

async function call(path, { method = 'GET', token, cookie, body, origin } = {}) {
  const response = await fetch(new URL(path, baseUrl), {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(cookie ? { cookie } : {}),
      ...(origin ? { origin } : {}),
      'x-backend-role': 'ADMIN',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await response.json().catch(() => null);
  return { response, data };
}

const unauthorized = await call('/admin/app-content');
assert.equal(unauthorized.response.status, 401);

const cookieLogin = await call('/auth/login', {
  method: 'POST',
  origin: 'http://localhost:3002',
  body: { employeeNo: 'ADMIN001', password },
});
assert.equal(cookieLogin.response.status, 201);
assert.equal(cookieLogin.data?.accessToken, undefined);
const cookie = cookieLogin.response.headers.get('set-cookie')?.split(';', 1)[0];
assert.match(cookie ?? '', /^staff_access_admin=/);
const cookieList = await call('/admin/app-content?module=HOME', { cookie });
assert.equal(cookieList.response.status, 200, 'Staff cookie cannot read content');
const cookieLogout = await call('/auth/logout', {
  method: 'POST',
  cookie,
  origin: 'http://localhost:3002',
});
assert.equal(cookieLogout.response.status, 201);
const revokedCookie = await call('/admin/app-content', { cookie });
assert.equal(revokedCookie.response.status, 401, 'Staff cookie survived logout');

const login = await call('/auth/login', {
  method: 'POST',
  body: { employeeNo: 'ADMIN001', password },
});
assert.equal(login.response.status, 201, 'Staff login failed');
assert.ok(login.data?.accessToken && login.data?.refreshToken);

const key = `integration.smoke.${Date.now()}`;
let entryId;
let accessToken = login.data.accessToken;
try {

  const created = await call('/admin/app-content', {
    method: 'PUT',
    token: accessToken,
    body: { module: 'HOME', key, locale: 'en', body: 'Smoke content visible' },
  });
  assert.equal(created.response.status, 200, 'Content edit failed');
  entryId = created.data?.id;
  assert.ok(entryId);

  const unauthorizedHistory = await call(`/admin/app-content/${entryId}/history`);
  assert.equal(unauthorizedHistory.response.status, 401, 'Unauthenticated history read succeeded');
  const unauthorizedRestore = await call(`/admin/app-content/${entryId}/restore`, {
    method: 'POST',
    body: { revisionId: 'not-authorized', expectedUpdatedAt: created.data?.updatedAt },
  });
  assert.equal(unauthorizedRestore.response.status, 401, 'Unauthenticated restore succeeded');

  const createdAt = created.data?.updatedAt;
  assert.ok(createdAt);

  const updated = await call('/admin/app-content', {
    method: 'PUT',
    token: accessToken,
    body: { module: 'HOME', key, locale: 'en', body: 'Smoke content updated' },
  });
  assert.equal(updated.response.status, 200, 'Content update failed');

  const publicContent = await call('/app-content?locale=en');
  assert.equal(publicContent.response.status, 200);
  assert.equal(publicContent.data?.home?.[key]?.body, 'Smoke content updated');

  const history = await call(`/admin/app-content/${entryId}/history`, { token: accessToken });
  assert.equal(history.response.status, 200, 'Content history failed');
  const creationRevision = history.data?.find((item) => item.action === 'APP_CONTENT_CREATE');
  assert.ok(creationRevision?.id, 'Creation revision missing');
  const restored = await call(`/admin/app-content/${entryId}/restore`, {
    method: 'POST',
    token: accessToken,
    body: { revisionId: creationRevision.id, expectedUpdatedAt: updated.data?.updatedAt },
  });
  assert.equal(restored.response.status, 201, 'Content restore failed');
  const restoredPublic = await call('/app-content?locale=en');
  assert.equal(restoredPublic.data?.home?.[key]?.body, 'Smoke content visible');

  const refreshed = await call('/auth/refresh', {
    method: 'POST',
    body: { refreshToken: login.data.refreshToken },
  });
  assert.equal(refreshed.response.status, 201, 'Token refresh failed');
  accessToken = refreshed.data?.accessToken;
  assert.ok(accessToken);
} finally {
  if (entryId) {
    const removed = await call(`/admin/app-content/${entryId}`, {
      method: 'DELETE',
      token: accessToken,
    });
    assert.equal(removed.response.status, 200, 'Smoke content cleanup failed');
  }
}

const logout = await call('/auth/logout', { method: 'POST', token: accessToken });
assert.equal(logout.response.status, 201);
const revoked = await call('/admin/app-content', { token: accessToken });
assert.equal(revoked.response.status, 401, 'Logout did not revoke access');
console.log('Staff login, cookie, content edit, public read, refresh and logout passed');
