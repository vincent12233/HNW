# Production operations

## Required security configuration

- Set a long random `JWT_SECRET` and a separate `OBJECT_SIGNING_SECRET`.
- Set `CORS_ORIGINS` to the exact HTTPS admin origins.
- Set `WEBSOCKET_ORIGINS` to the exact client origins.
- Set `VIRUS_SCAN_URL` to a service that accepts raw bytes and returns `CLEAN`. Production KYC uploads fail closed when it is missing.
- Keep `apps/api/private-objects` on an encrypted private volume. It must never be served as a static directory.

## Database migration

From `apps/api`, run `npm.cmd run db:migrate` before starting the updated API. The migration adds only the independent-approval queue; balance changes continue to use the existing account transaction records.

## Backup and recovery

Run `powershell -File scripts/backup-postgres.ps1` from the project root. Copy backups to encrypted off-site storage and test a restore regularly.

Restore requires an explicit safety switch:

`powershell -File scripts/restore-postgres.ps1 -BackupFile .\backups\india-trading-TIMESTAMP.sql -ConfirmRestore`

## Monitoring

The API emits one-line JSON HTTP and exception events containing request ID, status and duration. Send stdout/stderr to the log platform, alert on readiness failure, HTTP 5xx rate, repeated 401/429 responses, KYC scan failures, and approval failures. Never record passwords, JWTs, Aadhaar contents or uploaded bytes.
