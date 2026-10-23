# HNW Current State

## Verified delivery baseline

Verified on 2026-10-23 against GitHub and the local checkout:

- Default branch: `main`
- Verified `main` commit: `3bf7d49648c23452dfad59a51c42d247e287fc4a`
- PR #146 delivered staff authenticator enrollment/reset controls, security
  hardening, and the scoped UI/UX upgrade.
- PR #147 consolidated the pending Admin/API dependency updates. Its PR checks
  and the applicable post-merge `main` workflows passed.
- PR #142 was closed as superseded after its `follow-redirects` 1.16.1 change
  was confirmed already present on `main`.
- The repository did not contain
  `.github/workflows/financial-runtime-verification.yml` at verification time.

This is a dated checkpoint, not a permanent claim. Re-read GitHub and Git before
using branch, PR, commit, or CI state in a later task.

## Preserved product boundaries

- Trading rules and execution semantics remain unchanged by the 2026-10-23
  security/UI delivery.
- Customer registration and login flows remain unchanged.
- Deposit methods and funding semantics remain unchanged.
- Staff Google Authenticator enrollment and role-scoped reset are administrative
  security controls, not changes to customer authentication.

## Operational cautions

- Production credentials, customer data, and deployment secrets must never be
  recorded in these context files.
- Branch protection, required checks, production reviewers, and deployment
  state are remote facts and require a fresh authorized read.
- Use `docs/STATUS.md` as the canonical delivery and operations queue; avoid
  duplicating volatile status in multiple documents.

## Recovery entry

1. Run `git status --short --branch`, `git rev-parse HEAD`, and
   `git branch --show-current`.
2. Fetch/prune and compare the checkout with `origin/main` without discarding
   local changes.
3. Query current PRs and workflows for the exact head SHA.
4. Read `SESSION_HANDOFF.md`, then load only task-specific source and evidence.
