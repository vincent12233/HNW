# HNW Session Handoff

## 2026-11-27 security audit checkpoint

- Base commit `cbee77c2c2f20ae1c4f744a06a9a479aeb0a5069`.
- Updated effect to 3.22.1 for CVE-2026-121707, updated API image PAM packages for CVE-2025-6020, and clarified deposit operator scope in README.
- API lint/build and all 679 tests passed using isolated PostgreSQL 17 and Redis 7. Admin 154 tests, lint/typecheck, and 39 tooling tests passed.
- Findings and verification limits are recorded in `docs/AUDIT_2026-11-27.md`. Newly identified business defects remain open.
- Repository Trivy scan including development dependencies passed with zero fixable HIGH/CRITICAL findings.
- AOCI tooling is unavailable in this environment. Index synchronization and remote CI status require verification.

## Checkpoint

- Date: 2026-10-26 UTC
- Repository: `vincent12233/HNW`
- Production-hardening branch: `codex/hnw-production-hardening-2026-10-26`
- Verified base before the hardening work:
  `6bad50399e30b604eae8f186937529cc23cafd5f`

## Completed delivery context

- The active branch adds repository governance verification, supply-chain
  evidence, bounded capacity and recovery evidence, critical responsive visual
  contracts, refresh-token replay protection, and commit-bound enterprise
  acceptance aggregation.
- Repository, environment, and external acceptance are deliberately separate.
  Missing KYC, licensed market-data, exchange/clearing, legal, production, or
  physical-device evidence must remain incomplete rather than simulated.
- Final full-suite verification, PR creation, remote CI, merge, governance
  enforcement, and safe worktree cleanup remained to be performed at this checkpoint.

- PR #146 delivered the scoped staff-authenticator security controls and UI/UX
  work without changing trading rules, customer registration/login, or deposit
  methods.
- PR #145 and PR #141 delivered isolated React and Supertest patch updates.
- PR #147 consolidated the remaining Admin/API dependency updates after local
  audits, lint, tests, and builds, followed by successful PR checks.
- Superseded dependency PRs and their remote branches were closed or deleted.
- The persistent context set was reviewed against the current repository; stale
  references to PR #142, the old `work` checkout, Prisma 7.10.0, and a missing
  financial-runtime workflow were removed.

## Context files

- `AGENTS.md`
- `docs/ai/PROJECT_OVERVIEW.md`
- `docs/ai/ARCHITECTURE.md`
- `docs/ai/DECISIONS.md`
- `docs/ai/CURRENT_STATE.md`
- `docs/ai/TASK_QUEUE.md`
- `docs/ai/SESSION_HANDOFF.md`
- `docs/ai/CONTEXT_PROTOCOL.md`

These files are operational memory, not a substitute for source, Git, GitHub,
CI, or deployment-environment verification.

## Resume instruction

```text
git status --short --branch
git rev-parse HEAD
git fetch --prune origin
# Then query current PR and workflow state for the exact HEAD before acting.
```

## Evidence rule

Do not treat this handoff as proof that a test, PR, workflow, or deployment is
still current. Re-run the corresponding read-only check and update this file
only when a durable checkpoint materially changes.
