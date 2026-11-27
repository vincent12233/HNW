// The adapter is a privileged deployment-platform integration, NOT a generic webhook.
// See docs/AUDIT_FIX_DELIVERY_2026-11-27.md for the mandatory adapter contract.
const digestPattern = /^sha256:[a-f0-9]{64}$/;
export function validateBuild(build) {
  if (
    build?.schema !== 1 ||
    !/^[a-f0-9]{40}$/.test(build.commit ?? "") ||
    !/^ghcr\.io\/vincent12233\/hnw-api$/.test(build.image ?? "") ||
    !digestPattern.test(build.digest ?? "") ||
    !/^\d+$/.test(String(build.buildRunId ?? "")) ||
    !Array.isArray(build.platforms) ||
    !build.platforms.length ||
    build.platforms.some(
      (p) =>
        !digestPattern.test(p.digest ?? "") ||
        !digestPattern.test(p.configDigest ?? "") ||
        !p.platform,
    )
  ) {
    throw new Error("Invalid trusted build record");
  }
  return build;
}

export function validateInventory(build, state, target) {
  validateBuild(build);
  if (
    state.deploymentId !== target.deploymentId ||
    state.environment !== target.environment ||
    state.service !== "hnw-api" ||
    state.status !== "SUCCEEDED" ||
    state.inventoryComplete !== true ||
    !Number.isInteger(state.desiredReplicas) ||
    state.desiredReplicas < 1 ||
    !Array.isArray(state.replicas) ||
    state.replicas.length !== state.desiredReplicas ||
    new Set(state.replicas.map((r) => r.id)).size !== state.replicas.length
  ) {
    throw new Error(
      "Deployment incomplete or replica inventory not authoritative",
    );
  }
  for (const replica of state.replicas) {
    const platform = build.platforms.find(
      (p) => p.platform === replica.platform,
    );
    if (
      !replica.id ||
      replica.ready !== true ||
      replica.image !== build.image ||
      !platform ||
      ![build.digest, platform.digest].includes(replica.digest) ||
      replica.configDigest !== platform.configDigest
    ) {
      throw new Error("Runtime image identity mismatch");
    }
  }
  return state.replicas;
}

export async function verifyDeployment({
  build,
  target,
  readInventory,
  readVersion,
  attempts = 30,
  wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  delayMs = 10000,
}) {
  let failure = "Deployment verification did not run";
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      const state = await readInventory();
      const replicas = validateInventory(build, state, target);
      const observed = [];
      for (const replica of replicas) {
        const version = await readVersion(replica);
        if (version.commit !== build.commit)
          throw new Error("Runtime commit mismatch");
        observed.push({
          id: replica.id,
          platform: replica.platform,
          actualCommit: version.commit,
          actualDigest: replica.digest,
          actualConfigDigest: replica.configDigest,
        });
      }
      // Re-read inventory after probing every replica: a rolling replacement invalidates the proof.
      const after = validateInventory(build, await readInventory(), target);
      const identity = (rows) =>
        rows
          .map((r) => `${r.id}:${r.digest}:${r.configDigest}`)
          .sort()
          .join("|");
      if (identity(after) !== identity(replicas))
        throw new Error("Replica inventory changed during verification");
      return {
        schema: 1,
        status: "VERIFIED",
        environment: target.environment,
        deploymentId: target.deploymentId,
        expectedCommit: build.commit,
        expectedDigest: build.digest,
        build,
        replicas: observed,
        ciRunId: target.ciRunId,
        verifiedAt: new Date().toISOString(),
      };
    } catch (error) {
      // Never include platform response bodies, URLs, headers or credential-bearing exception messages.
      const safe = new Set([
        "Deployment incomplete or replica inventory not authoritative",
        "Runtime image identity mismatch",
        "Runtime commit mismatch",
        "Replica inventory changed during verification",
        "Invalid trusted build record",
      ]);
      failure = safe.has(error.message)
        ? error.message
        : "Platform or replica version read failed/timed out";
      if (attempt + 1 < attempts) await wait(delayMs);
    }
  }
  throw new Error(failure);
}
