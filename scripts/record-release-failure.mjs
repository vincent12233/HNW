import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
// Catch failures before the platform verifier starts (source run/artifact validation).
mkdirSync('release-evidence', { recursive: true });
if (!existsSync('release-evidence/failure.json')) {
  writeFileSync('release-evidence/failure.json', JSON.stringify({
    status: 'FAILED', environment: 'production', ciRunId: process.env.GITHUB_RUN_ID,
    checkedAt: new Date().toISOString(), summary: 'Release validation failed before verified deployment; inspect failed workflow step',
  }, null, 2));
}
