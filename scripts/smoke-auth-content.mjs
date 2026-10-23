import assert from "node:assert/strict";

const baseUrl = process.env.HNW_SMOKE_API_URL || "http://127.0.0.1:3100";
const password = process.env.HNW_SMOKE_ADMIN_PASSWORD;
if (!password) throw new Error("HNW_SMOKE_ADMIN_PASSWORD is required");

async function call(
  path,
  { method = "GET", token, cookie, body, origin, backendRole = "ADMIN" } = {},
) {
  const response = await fetch(new URL(path, baseUrl), {
    method,
    headers: {
      ...(body ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(cookie ? { cookie } : {}),
      ...(origin ? { origin } : {}),
      "x-backend-role": backendRole,
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await response.json().catch(() => null);
  return { response, data };
}

const unauthorized = await call("/admin/app-content");
assert.equal(unauthorized.response.status, 401);

const clientOrigin = await call("/health/ready", {
  origin: "http://localhost:3000",
});
assert.equal(clientOrigin.response.status, 200, "API readiness failed");
assert.equal(
  clientOrigin.response.headers.get("access-control-allow-origin"),
  "http://localhost:3000",
  "Client origin is not allowed by CORS",
);

const enrollmentLogin = await call("/auth/login", {
  method: "POST",
  origin: "http://localhost:3002",
  body: { employeeNo: "ADMIN001", password },
});
assert.equal(
  enrollmentLogin.response.status,
  401,
  "First staff login did not require enrollment",
);
assert.equal(enrollmentLogin.data?.twoFactorSetupRequired, true);
assert.ok(
  enrollmentLogin.data?.setupToken,
  "Staff enrollment challenge is missing",
);
const setup = await call("/auth/staff-two-factor/setup", {
  method: "POST",
  token: enrollmentLogin.data.setupToken,
  body: {},
});
assert.equal(setup.response.status, 201, "Staff authenticator setup failed");
assert.ok(
  setup.data?.secret && setup.data?.uri,
  "Staff authenticator setup is incomplete",
);

const { createRequire } = await import("node:module");
const requireFromApi = createRequire(
  new URL("../apps/api/package.json", import.meta.url),
);
const OTPAuth = requireFromApi("otpauth");
const setupCode = new OTPAuth.TOTP({
  issuer: "Finvest",
  algorithm: "SHA1",
  digits: 6,
  period: 30,
  secret: OTPAuth.Secret.fromBase32(setup.data.secret),
}).generate();
const confirmed = await call("/auth/staff-two-factor/confirm", {
  method: "POST",
  token: enrollmentLogin.data.setupToken,
  body: { code: setupCode },
});
assert.equal(
  confirmed.response.status,
  201,
  "Staff authenticator confirmation failed",
);
assert.equal(
  confirmed.data?.recoveryCodes?.length,
  8,
  "Recovery codes were not issued",
);

const cookieLogin = await call("/auth/login", {
  method: "POST",
  origin: "http://localhost:3002",
  body: {
    employeeNo: "ADMIN001",
    password,
    verificationCode: confirmed.data.recoveryCodes[0],
  },
});
assert.equal(cookieLogin.response.status, 201);
assert.equal(cookieLogin.data?.accessToken, undefined);
const cookie = cookieLogin.response.headers.get("set-cookie")?.split(";", 1)[0];
assert.match(cookie ?? "", /^staff_access_admin=/);
const cookieList = await call("/admin/app-content?module=HOME", { cookie });
assert.equal(
  cookieList.response.status,
  200,
  "Staff cookie cannot read content",
);
const cookieLogout = await call("/auth/logout", {
  method: "POST",
  cookie,
  origin: "http://localhost:3002",
});
assert.equal(cookieLogout.response.status, 201);
const revokedCookie = await call("/admin/app-content", { cookie });
assert.equal(
  revokedCookie.response.status,
  401,
  "Staff cookie survived logout",
);

const login = await call("/auth/login", {
  method: "POST",
  body: {
    employeeNo: "ADMIN001",
    password,
    verificationCode: confirmed.data.recoveryCodes[1],
  },
});
assert.equal(login.response.status, 201, "Staff login failed");
assert.ok(login.data?.accessToken && login.data?.refreshToken);

const key = `integration.smoke.${Date.now()}`;
let entryId;
let accessToken = login.data.accessToken;
try {
  const created = await call("/admin/app-content", {
    method: "PUT",
    token: accessToken,
    body: { module: "HOME", key, locale: "en", body: "Smoke content visible" },
  });
  assert.equal(created.response.status, 200, "Content edit failed");
  entryId = created.data?.id;
  assert.ok(entryId);

  const unauthorizedHistory = await call(
    `/admin/app-content/${entryId}/history`,
  );
  assert.equal(
    unauthorizedHistory.response.status,
    401,
    "Unauthenticated history read succeeded",
  );
  const unauthorizedRestore = await call(
    `/admin/app-content/${entryId}/restore`,
    {
      method: "POST",
      body: {
        revisionId: "not-authorized",
        expectedUpdatedAt: created.data?.updatedAt,
      },
    },
  );
  assert.equal(
    unauthorizedRestore.response.status,
    401,
    "Unauthenticated restore succeeded",
  );

  const wrongRoleHistory = await call(`/admin/app-content/${entryId}/history`, {
    token: accessToken,
    backendRole: "SUPPORT",
  });
  assert.equal(
    wrongRoleHistory.response.status,
    403,
    "Wrong staff role read history",
  );
  const wrongRoleRestore = await call(`/admin/app-content/${entryId}/restore`, {
    method: "POST",
    token: accessToken,
    backendRole: "SUPPORT",
    body: {
      revisionId: "not-authorized",
      expectedUpdatedAt: created.data?.updatedAt,
    },
  });
  assert.equal(
    wrongRoleRestore.response.status,
    403,
    "Wrong staff role restored content",
  );

  const createdAt = created.data?.updatedAt;
  assert.ok(createdAt);

  const updated = await call("/admin/app-content", {
    method: "PUT",
    token: accessToken,
    body: { module: "HOME", key, locale: "en", body: "Smoke content updated" },
  });
  assert.equal(updated.response.status, 200, "Content update failed");

  const publicContent = await call("/app-content?locale=en");
  assert.equal(publicContent.response.status, 200);
  assert.equal(publicContent.data?.home?.[key]?.body, "Smoke content updated");

  const scheduled = await call("/admin/app-content", {
    method: "PUT",
    token: accessToken,
    body: {
      module: "HOME",
      key,
      locale: "en",
      body: "Smoke content scheduled",
      publicationStatus: "SCHEDULED",
      publishAt: new Date(Date.now() + 60_000).toISOString(),
    },
  });
  assert.equal(scheduled.response.status, 200, "Scheduled content edit failed");
  const beforePublish = await call("/app-content?locale=en");
  assert.equal(
    beforePublish.data?.home?.[key],
    undefined,
    "Scheduled content leaked before publishAt",
  );

  const expired = await call("/admin/app-content", {
    method: "PUT",
    token: accessToken,
    body: {
      module: "HOME",
      key,
      locale: "en",
      body: "Smoke content expired",
      publicationStatus: "PUBLISHED",
      expiresAt: new Date(Date.now() - 60_000).toISOString(),
    },
  });
  assert.equal(expired.response.status, 200, "Expiry content edit failed");
  const afterExpiry = await call("/app-content?locale=en");
  assert.equal(
    afterExpiry.data?.home?.[key],
    undefined,
    "Expired content remained public",
  );
  assert.ok(expired.data?.updatedAt, "Expiry update did not return updatedAt");
  const history = await call(`/admin/app-content/${entryId}/history`, {
    token: accessToken,
  });
  assert.equal(history.response.status, 200, "Content history failed");
  const creationRevision = history.data?.find(
    (item) => item.action === "APP_CONTENT_CREATE",
  );
  assert.ok(creationRevision?.id, "Creation revision missing");
  const restored = await call(`/admin/app-content/${entryId}/restore`, {
    method: "POST",
    token: accessToken,
    body: {
      revisionId: creationRevision.id,
      expectedUpdatedAt: expired.data?.updatedAt,
    },
  });
  assert.equal(restored.response.status, 201, "Content restore failed");
  const restoredPublic = await call("/app-content?locale=en");
  assert.equal(restoredPublic.data?.home?.[key]?.body, "Smoke content visible");

  const refreshed = await call("/auth/refresh", {
    method: "POST",
    body: { refreshToken: login.data.refreshToken },
  });
  assert.equal(refreshed.response.status, 201, "Token refresh failed");
  accessToken = refreshed.data?.accessToken;
  assert.ok(accessToken);
} finally {
  if (entryId) {
    const removed = await call(`/admin/app-content/${entryId}`, {
      method: "DELETE",
      token: accessToken,
    });
    assert.equal(removed.response.status, 200, "Smoke content cleanup failed");
  }
}

const logout = await call("/auth/logout", {
  method: "POST",
  token: accessToken,
});
assert.equal(logout.response.status, 201);
const revoked = await call("/admin/app-content", { token: accessToken });
assert.equal(revoked.response.status, 401, "Logout did not revoke access");
console.log(
  "Staff login, cookie, content edit, public read, refresh and logout passed",
);
