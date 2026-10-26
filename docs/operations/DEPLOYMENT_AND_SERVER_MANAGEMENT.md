# HNW deployment and server management

Production changes are performed only by approved CI environments against an
exact commit SHA and immutable image digest. The Admin browser is read-only for
health, deployment evidence, reconciliation, and audit data; it never exposes a
host shell, credentials, deploy, rollback, database, or balance controls.

## Routine workflow

1. Complete protected-flow, API, Admin, Flutter, Web/PWA, container, migration,
   dependency, and security checks for one SHA.
2. Verify UTC/NTP time, TLS validity, at least 10 GB free disk, dependency
   health, and a restore-tested backup less than 24 hours old.
3. Record image digests and migration compatibility in release evidence.
4. Obtain the GitHub `production` environment approval, deploy expand-compatible
   migrations, start services, and run authenticated smoke tests.
5. Stop rollout on any authentication, funding, order, balance, reconciliation,
   or error-budget anomaly.

Use `scripts/ops/hnw-ops.ps1` or `.sh` for preflight, status, bounded logs and
backup checks. Local deploy/rollback commands reject production. Production
rollback redeploys a previously approved image; it never reverses committed
financial records or applies destructive database rollback.

## Maintenance and incident access

- Renew certificates through the managed ingress and verify the full chain.
- Scale stateless API/Admin/Web replicas only after Redis and scheduler leases
  are healthy. PostgreSQL and TimescaleDB follow provider runbooks.
- Run quarterly restore drills into an isolated database and record checksums,
  RPO, RTO, row counts, constraints, and reconciliation output.
- Use time-bounded, individually attributed incident access. Preserve correlated
  request IDs and sanitized logs; never paste secrets or customer documents.
- Handover must include the environment inventory, current digests, backup owner,
  certificate owner, alert routing, incident contacts, and last restore drill.
