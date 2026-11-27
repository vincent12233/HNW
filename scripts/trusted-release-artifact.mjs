import { appendFile, readFile, writeFile } from "node:fs/promises";
import { validateBuild } from "./release-verification.mjs";
// First invocation authenticates the source run before actions/download-artifact.
// Second invocation validates its content against that run and exports the build record.
const mode = process.env.RELEASE_OPERATION ?? "deploy";
const runId = process.env.SOURCE_RUN_ID;
if (
  !/^\d+$/.test(runId ?? "") ||
  process.env.GITHUB_REPOSITORY !== "vincent12233/HNW"
)
  throw new Error("Invalid source repository or run");
const response = await fetch(
  `https://api.github.com/repos/vincent12233/HNW/actions/runs/${runId}`,
  {
    headers: {
      authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      accept: "application/vnd.github+json",
    },
    signal: AbortSignal.timeout(10000),
    redirect: "error",
  },
);
if (!response.ok) throw new Error("Cannot authenticate source workflow run");
const run = await response.json();
const paths =
  mode === "rollback"
    ? [
        ".github/workflows/production-deploy.yml",
        ".github/workflows/production-rollback.yml",
      ]
    : [".github/workflows/release-build.yml"];
if (
  run.conclusion !== "success" ||
  run.head_branch !== "main" ||
  run.event !== "workflow_dispatch" ||
  run.repository?.full_name !== "vincent12233/HNW" ||
  !paths.includes(run.path)
)
  throw new Error("Untrusted or unsuccessful source workflow");
if (process.argv.includes("--verify-content")) {
  const record = JSON.parse(
    await readFile(
      mode === "rollback"
        ? "source-artifact/deployment.json"
        : "source-artifact/build.json",
      "utf8",
    ),
  );
  if (
    mode === "rollback" &&
    (record.status !== "VERIFIED" ||
      record.environment !== "production" ||
      String(record.ciRunId) !== runId ||
      !record.replicas?.length ||
      record.replicas.some((r) => r.actualCommit !== record.expectedCommit))
  )
    throw new Error("Rollback needs previously verified production evidence");
  const build = validateBuild(mode === "rollback" ? record.build : record);
  if (
    mode !== "rollback" &&
    (build.commit !== run.head_sha || String(build.buildRunId) !== runId)
  )
    throw new Error("Build artifact does not match source run");
  if (build.commit !== process.env.EXPECTED_COMMIT)
    throw new Error("Expected commit differs from trusted artifact");
  await writeFile("trusted-build.json", JSON.stringify(build));
} else {
  await appendFile(
    process.env.GITHUB_OUTPUT,
    `artifact_name=${mode === "rollback" ? "verified-production-release" : "api-build-record"}\n`,
  );
}
