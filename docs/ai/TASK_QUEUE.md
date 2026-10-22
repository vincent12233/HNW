# HNW Task Queue

Statuses below are planning records, not authorization to execute.

## P0 — Verify governance before production release

- Status: pending live verification
- Dependencies: authorized GitHub administration read access
- Scope: main branch protection, required checks, PR approvals, force-push and
  deletion restrictions, production environment reviewers and branch rules
- Acceptance: settings are read from GitHub and recorded with URL/time; no
  claim relies only on workflow YAML.

## P1 — Complete API dependency remediation review

- Status: Draft PR #142 was open at the last live check
- Dependencies: current PR and CI re-check
- Scope: API lockfile `follow-redirects` 1.16.0 → 1.16.1 only
- Acceptance: exact head SHA has successful API CI, dependency audit, Docker CI,
  and CodeQL; human reviewer approves before merge.

## P1 — Decide the financial runtime workflow disposition

- Status: pending explicit owner decision
- Dependency: review `.github/workflows/financial-runtime-verification.yml`
- Scope: preserve or remove the untracked workflow; do not silently add it to
  required checks
- Acceptance: owner records whether it is retained, consolidated, or discarded.

## P2 — Maintain persistent context

- Status: ongoing
- Dependencies: every task start/end
- Acceptance: `CURRENT_STATE.md` and `SESSION_HANDOFF.md` contain only
  verified, source-linked facts and exact validation evidence.

## P2 — Operational readiness items

Refer to `docs/STATUS.md` for the existing product and operations queue,
including provider onboarding, recovery-drill execution, mobile release checks,
and production observability configuration. Do not duplicate that queue here.
