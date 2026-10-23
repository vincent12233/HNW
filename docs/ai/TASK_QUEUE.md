# HNW Task Queue

Statuses below are planning records, not authorization to execute. The detailed
delivery queue remains in `docs/STATUS.md`.

## P0 - Verify governance before production release

- Status: pending live verification before each production release
- Scope: branch protection, required checks, PR approvals, force-push/deletion
  restrictions, production environment reviewers, and deployment permissions
- Acceptance: settings are read from GitHub and tied to a timestamp; no claim
  relies only on workflow YAML

## P1 - Complete environment-backed production readiness

- Status: requires deployment-environment configuration
- Scope: commercial market data, KYC scanning, alert receivers, error-reporting
  credentials, and post-deploy smoke verification
- Acceptance: provider credentials remain outside Git; production preflight and
  smoke checks pass against the intended environment

## P1 - Execute true integration validation

- Status: CI foundations exist; environment-backed validation remains ongoing
- Scope: registration, KYC, deposit, trading, review, and mobile device flows
- Acceptance: results are tied to the exact application SHA and isolated test
  accounts/resources; trading and funding semantics are not altered to make
  tests pass

## P2 - Maintain persistent context

- Status: ongoing when durable architecture, constraints, or delivery state
  materially changes
- Acceptance: `CURRENT_STATE.md` and `SESSION_HANDOFF.md` contain verified,
  source-linked facts and do not duplicate volatile GitHub state unnecessarily
