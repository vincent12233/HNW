import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));

test("reconciliation workspace is read-only except for audited acknowledgement", () => {
  const source = readFileSync(
    join(root, "../components/ReconciliationWorkspace.tsx"),
    "utf8",
  );
  assert.match(source, /\/admin\/reconciliation/);
  assert.match(source, /issues\/\$\{selectedIssue\.id\}\/acknowledge/);
  assert.match(source, /不会修改任何资金或持仓数据/);
  assert.doesNotMatch(source, /fix.balance|adjust.balance|position.update/i);
});

test("reconciliation is ADMIN-only through the audit permission", () => {
  const permissions = readFileSync(
    join(root, "../lib/role-permissions.ts"),
    "utf8",
  );
  const shell = readFileSync(
    join(root, "../components/AdminShell.tsx"),
    "utf8",
  );
  assert.match(permissions, /["']\/reconciliation["'], ["']audit\.read["']/);
  const adminBlock = shell.slice(
    shell.indexOf("ADMIN: ["),
    shell.indexOf("MANAGER: ["),
  );
  assert.match(adminBlock, /\/reconciliation/);
  assert.doesNotMatch(
    shell.slice(shell.indexOf("MANAGER: [")),
    /key: "\/reconciliation"/,
  );
});
