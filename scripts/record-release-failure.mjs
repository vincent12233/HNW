import { mkdirSync, writeFileSync } from "node:fs";
// Catch failures before the platform verifier starts without replacing its more specific evidence.
mkdirSync("release-evidence", { recursive: true });
try {
  writeFileSync(
    "release-evidence/failure.json",
    JSON.stringify(
      {
        status: "FAILED",
        environment: "production",
        ciRunId: process.env.GITHUB_RUN_ID,
        checkedAt: new Date().toISOString(),
        summary:
          "Release validation failed before verified deployment; inspect failed workflow step",
      },
      null,
      2,
    ),
    { flag: "wx" },
  );
} catch (error) {
  if (error.code !== "EEXIST") throw error;
}
