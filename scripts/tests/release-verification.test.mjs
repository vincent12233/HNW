import test from "node:test";
import assert from "node:assert/strict";
import { validateBuild, verifyDeployment } from "../release-verification.mjs";
const d = (c) => `sha256:${c.repeat(64)}`;
const build = {
  schema: 1,
  commit: "a".repeat(40),
  image: "ghcr.io/vincent12233/hnw-api",
  digest: d("1"),
  buildRunId: "123",
  platforms: [
    { platform: "linux/amd64", digest: d("2"), configDigest: d("3") },
  ],
};
const target = {
  deploymentId: "deploy-1",
  environment: "test",
  ciRunId: "456",
};
const inventory = () => ({
  ...target,
  service: "hnw-api",
  status: "SUCCEEDED",
  inventoryComplete: true,
  desiredReplicas: 2,
  replicas: ["one", "two"].map((id) => ({
    id,
    ready: true,
    platform: "linux/amd64",
    image: build.image,
    digest: d("2"),
    configDigest: d("3"),
  })),
});
function verify(overrides = {}) {
  return verifyDeployment({
    build,
    target,
    readInventory: async () => inventory(),
    readVersion: async () => ({ commit: build.commit }),
    attempts: 1,
    ...overrides,
  });
}
test("records actual identity for every replica and OCI platform/config mapping", async () => {
  const result = await verify();
  assert.equal(result.status, "VERIFIED");
  assert.equal(result.replicas.length, 2);
  assert.equal(result.replicas[0].actualDigest, d("2"));
  assert.equal(result.expectedDigest, d("1"));
});
test("healthy old commit cannot pass", async () => {
  await assert.rejects(
    verify({ readVersion: async () => ({ commit: "b".repeat(40) }) }),
    /commit mismatch/,
  );
});
test("wrong digest or image config cannot pass", async () => {
  for (const field of ["digest", "configDigest"])
    await assert.rejects(
      verify({
        readInventory: async () => {
          const state = inventory();
          state.replicas[1][field] = d("4");
          return state;
        },
      }),
      /image identity mismatch/,
    );
});
test("rolling release, missing replicas, duplicate replicas and incomplete inventory cannot pass", async () => {
  for (const mutate of [
    (s) => (s.status = "DEPLOYING"),
    (s) => (s.desiredReplicas = 3),
    (s) => (s.inventoryComplete = false),
    (s) => (s.replicas[1].id = "one"),
  ]) {
    await assert.rejects(
      verify({
        readInventory: async () => {
          const state = inventory();
          mutate(state);
          return state;
        },
      }),
      /incomplete|inventory/,
    );
  }
});
test("version timeout is bounded and redacts potentially sensitive error text", async () => {
  let attempts = 0;
  await assert.rejects(
    verify({
      attempts: 3,
      wait: async () => {},
      readVersion: async () => {
        attempts++;
        throw new Error("secret-token-in-url");
      },
    }),
    /^Error: Platform or replica version read failed\/timed out$/,
  );
  assert.equal(attempts, 3);
});
test("replica replacement during probes invalidates evidence", async () => {
  let reads = 0;
  await assert.rejects(
    verify({
      readInventory: async () => {
        const s = inventory();
        if (reads++) s.replicas[1].id = "replacement";
        return s;
      },
    }),
    /changed during/,
  );
});
test("rollback to a healthy historical build uses the same verification", async () => {
  const historical = { ...build, commit: "b".repeat(40) };
  assert.equal(
    (
      await verify({
        build: historical,
        readVersion: async () => ({ commit: historical.commit }),
      })
    ).expectedCommit,
    historical.commit,
  );
});
test("rejects invalid build mapping", () => {
  assert.throws(() => validateBuild({ ...build, platforms: [] }));
});

test("deployment CLI fails closed without a configured platform adapter and produces no success evidence", async () => {
  const { mkdtemp, writeFile, readFile, access, rm } =
    await import("node:fs/promises");
  const { tmpdir } = await import("node:os");
  const { join, resolve } = await import("node:path");
  const { spawnSync } = await import("node:child_process");
  const directory = await mkdtemp(join(tmpdir(), "hnw-release-test-"));
  try {
    await writeFile(
      join(directory, "trusted-build.json"),
      JSON.stringify(build),
    );
    const result = spawnSync(
      process.execPath,
      [resolve("scripts/post-deploy-smoke.mjs")],
      {
        cwd: directory,
        encoding: "utf8",
        env: {
          APPROVED_IMAGE_DIGEST: build.digest,
          EXPECTED_COMMIT: build.commit,
          GITHUB_RUN_ID: "456",
        },
      },
    );
    assert.equal(result.status, 1);
    assert.equal(
      JSON.parse(
        await readFile(
          join(directory, "release-evidence/failure.json"),
          "utf8",
        ),
      ).status,
      "FAILED",
    );
    await assert.rejects(
      access(join(directory, "release-evidence/deployment.json")),
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("failure evidence creation is atomic and preserves existing detailed diagnostics", async () => {
  const { mkdtemp, readFile, writeFile, rm } = await import("node:fs/promises");
  const { tmpdir } = await import("node:os");
  const { join, resolve } = await import("node:path");
  const { spawnSync } = await import("node:child_process");
  const directory = await mkdtemp(join(tmpdir(), "hnw-failure-test-"));
  try {
    const run = () =>
      spawnSync(
        process.execPath,
        [resolve("scripts/record-release-failure.mjs")],
        { cwd: directory, env: { GITHUB_RUN_ID: "456" } },
      );
    assert.equal(run().status, 0);
    const path = join(directory, "release-evidence/failure.json");
    assert.equal(JSON.parse(await readFile(path, "utf8")).status, "FAILED");
    const specific = JSON.stringify({
      status: "FAILED",
      summary: "Specific platform failure",
    });
    await writeFile(path, specific);
    assert.equal(run().status, 0);
    assert.equal(await readFile(path, "utf8"), specific);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("deployment CLI rejects a manifest that differs from the approved digest before any platform call", async () => {
  const { mkdtemp, writeFile, readFile, rm } = await import("node:fs/promises");
  const { tmpdir } = await import("node:os");
  const { join, resolve } = await import("node:path");
  const { spawnSync } = await import("node:child_process");
  const directory = await mkdtemp(join(tmpdir(), "hnw-target-test-"));
  try {
    await writeFile(
      join(directory, "trusted-build.json"),
      JSON.stringify(build),
    );
    const result = spawnSync(
      process.execPath,
      [resolve("scripts/post-deploy-smoke.mjs")],
      {
        cwd: directory,
        encoding: "utf8",
        env: {
          EXPECTED_COMMIT: build.commit,
          APPROVED_IMAGE_DIGEST: d("9"),
          GITHUB_RUN_ID: "456",
        },
      },
    );
    assert.equal(result.status, 1);
    assert.equal(
      JSON.parse(
        await readFile(
          join(directory, "release-evidence/failure.json"),
          "utf8",
        ),
      ).summary,
      "Build digest confirmation mismatch",
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
