import { readFile, mkdir, writeFile } from "node:fs/promises";
import { validateBuild, verifyDeployment } from "./release-verification.mjs";

// Inputs are trusted artifacts downloaded by the workflow, never operator-supplied digest claims.
const environment = process.env.DEPLOY_ENVIRONMENT ?? "production";
const ciRunId = process.env.GITHUB_RUN_ID;
let deploymentId = null;
try {
  const build = validateBuild(
    JSON.parse(await readFile(process.env.BUILD_RECORD_PATH, "utf8")),
  );
  if (build.commit !== process.env.EXPECTED_COMMIT)
    throw new Error("Build commit confirmation mismatch");
  const adapter = new URL(process.env.DEPLOYMENT_ADAPTER_URL ?? "");
  if (
    adapter.protocol !== "https:" ||
    adapter.username ||
    adapter.password ||
    adapter.search ||
    adapter.hash ||
    !process.env.DEPLOYMENT_ADAPTER_TOKEN
  )
    throw new Error(
      "Verified version-bound deployment adapter is not configured",
    );
  async function call(path, body) {
    const response = await fetch(new URL(path, adapter), {
      method: body ? "POST" : "GET",
      redirect: "error",
      headers: {
        authorization: `Bearer ${process.env.DEPLOYMENT_ADAPTER_TOKEN}`,
        "content-type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error("Deployment platform request failed");
    return response.json();
  }
  const capabilities = await call("/v1/capabilities");
  if (
    capabilities.schema !== 1 ||
    capabilities.immutableImage !== true ||
    capabilities.completeReplicaInventory !== true ||
    capabilities.replicaVersionProxy !== true
  )
    throw new Error("Deployment adapter lacks required capabilities");
  const created = await call("/v1/deployments", {
    environment,
    service: "hnw-api",
    image: `${build.image}@${build.digest}`,
    commit: build.commit,
    operation: process.env.RELEASE_OPERATION ?? "deploy",
    requestId: `${ciRunId}:${process.env.GITHUB_RUN_ATTEMPT ?? "1"}`,
  });
  if (
    typeof created.deploymentId !== "string" ||
    !/^[a-zA-Z0-9_-]{1,120}$/.test(created.deploymentId)
  )
    throw new Error("Invalid deployment identity");
  deploymentId = created.deploymentId;
  const evidence = await verifyDeployment({
    build,
    target: { environment, deploymentId, ciRunId },
    readInventory: () => call(`/v1/deployments/${deploymentId}`),
    // Platform proxy must probe the named replica's /health/version, not the load balancer.
    readVersion: (replica) =>
      call(
        `/v1/deployments/${deploymentId}/replicas/${encodeURIComponent(replica.id)}/health/version`,
      ),
  });
  const endpoints = [
    `${process.env.PRODUCTION_API_URL ?? ""}/health/ready`,
    ...(process.env.PRODUCTION_ADMIN_URLS ?? "")
      .split(",")
      .filter(Boolean)
      .map((url) => `${url.replace(/\/$/, "")}/login`),
  ];
  if (endpoints.length < 2 || !process.env.PRODUCTION_API_URL)
    throw new Error("Readiness endpoints are not configured");
  for (const endpoint of endpoints) {
    if (new URL(endpoint).protocol !== "https:")
      throw new Error("Readiness endpoint must use HTTPS");
    const response = await fetch(endpoint, {
      redirect: "error",
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error("Readiness endpoint failed");
  }
  await mkdir("release-evidence", { recursive: true });
  await writeFile(
    "release-evidence/deployment.json",
    JSON.stringify(evidence, null, 2),
  );
  console.log("Commit and immutable image verified on all active API replicas");
} catch (error) {
  await mkdir("release-evidence", { recursive: true });
  const safe = new Set([
    "Build commit confirmation mismatch",
    "Verified version-bound deployment adapter is not configured",
    "Deployment adapter lacks required capabilities",
    "Invalid deployment identity",
    "Invalid trusted build record",
    "Deployment incomplete or replica inventory not authoritative",
    "Runtime image identity mismatch",
    "Runtime commit mismatch",
    "Replica inventory changed during verification",
    "Platform or replica version read failed/timed out",
    "Deployment platform request failed",
  ]);
  const summary = safe.has(error.message)
    ? error.message
    : "Missing configuration, invalid artifact or deployment platform unavailable";
  await writeFile(
    "release-evidence/failure.json",
    JSON.stringify(
      {
        status: "FAILED",
        environment,
        deploymentId,
        ciRunId,
        checkedAt: new Date().toISOString(),
        summary,
      },
      null,
      2,
    ),
  );
  console.error(summary);
  process.exitCode = 1;
}
