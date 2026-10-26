# HNW Production Hardening Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete and prove every repository-controlled enterprise hardening item while preserving HNW's protected customer, deposit, and trading contracts.

**Architecture:** Extend the existing modular monolith and CI/CD system with fail-closed governance checks, supply-chain evidence, repeatable resilience tests, visual contracts, and one commit-bound acceptance manifest. Production-only dependencies stay external and explicitly unverified until real evidence is supplied.

**Tech Stack:** GitHub Actions, PowerShell/Node.js verification scripts, Flutter/Dart, Playwright, NestJS/Jest, PostgreSQL, Redis, Docker Compose, Prometheus/Grafana.

**Spec:** `docs/superpowers/specs/2026-10-26-hnw-production-hardening-completion-design.md`

## Global Constraints

- Preserve all protected registration, login, recovery, deposit, trading, trade-screen, and staff-authenticator contracts verbatim from the spec.
- Do not add external providers or claim environment-backed success without real evidence.
- Tests and evidence must bind to one exact Git SHA.
- New production checks fail closed; local developer paths remain isolated and usable.
- No secrets, customer data, production credentials, or generated build outputs enter Git.

## Review Focus

- A missing or partially configured GitHub protection rule must be reported as incomplete, never silently accepted.
- A rerun against a different SHA must not reuse old evidence.
- A degraded Redis/outbox/database dependency must not be represented as a healthy financial path.
- Screenshot/visual checks must cover narrow and desktop layouts without altering order fields.
- Release evidence must distinguish repository automation from external provider, device, and legal evidence.

---

### Task 1: Governance and evidence verifier

**Files:**
- Create: `scripts/verify-github-governance.ps1`
- Create: `scripts/tests/github-governance.test.ps1`
- Modify: `docs/小白部署与运维手册.md`

**Interfaces:**
- Produces: a JSON governance report with `sha`, `repository`, `branchProtection`, `requiredChecks`, `securityAlerts`, `productionEnvironment`, and `complete`.

- [ ] Write fixture-driven tests for missing protection, missing checks, open alerts, and complete configuration.
- [ ] Run the tests and confirm the incomplete fixtures fail.
- [ ] Implement read-only GitHub API collection plus offline fixture mode.
- [ ] Verify tests pass and document required GitHub settings.
- [ ] Commit the task.

### Task 2: Supply-chain security workflow

**Files:**
- Create: `.github/workflows/supply-chain-security.yml`
- Create: `scripts/tests/supply-chain-workflow.test.mjs`
- Modify: `SECURITY.md`

**Interfaces:**
- Produces: API/Admin SBOM artifacts, secret-scan result, filesystem/container vulnerability results, and workflow provenance bound to the commit SHA.

- [ ] Write contract tests for least-privilege permissions, pinned tool configuration, artifact retention, and failure thresholds.
- [ ] Run the contract test and confirm it fails before the workflow exists.
- [ ] Add the workflow and security response documentation.
- [ ] Run the contract test and production-operation tests.
- [ ] Commit the task.

### Task 3: Capacity and resilience evidence

**Files:**
- Create: `scripts/enterprise-capacity.mjs`
- Create: `scripts/tests/enterprise-capacity.test.mjs`
- Modify: `docs/verification/enterprise-capacity-template.md`
- Modify: `compose.observability.yaml`

**Interfaces:**
- Produces: `enterprise-capacity-report.json` with exact SHA, scenario, duration, request totals, error rate, latency percentiles, dependency state, and pass/fail thresholds.

- [ ] Write tests for percentile math, SHA binding, threshold failure, timeout handling, and safe no-production defaults.
- [ ] Run tests and confirm failure.
- [ ] Implement the bounded runner and report schema without changing application behavior.
- [ ] Verify tests and documented local invocation.
- [ ] Commit the task.

### Task 4: Recovery and reconciliation evidence hardening

**Files:**
- Modify: `scripts/recovery-drill.ps1`
- Modify: `scripts/recovery-drill.sh`
- Modify: `scripts/tests/recovery-drill.test.ps1`
- Modify: `.github/workflows/recovery-drill.yml`

**Interfaces:**
- Consumes: isolated source/restore database and private-object paths.
- Produces: SHA-bound report with checksums, row counts, reconciliation result, RPO/RTO observations, and explicit external-evidence status.

- [ ] Add failing tests for missing SHA, checksum mismatch, and non-zero reconciliation.
- [ ] Implement report hardening and CI artifact validation.
- [ ] Run recovery tests and plan-only workflow contract checks.
- [ ] Commit the task.

### Task 5: Critical visual contracts

**Files:**
- Create: `apps/client/test/enterprise_visual_states_test.dart`
- Create: `tests/web-pwa/enterprise-visual.spec.ts`
- Create: `apps/admin/tests/enterprise-visual-contract.test.mjs`
- Modify: `.github/workflows/flutter-ci.yml`
- Modify: `.github/workflows/web-pwa-ci.yml`
- Modify: `.github/workflows/admin-ci.yml`

**Interfaces:**
- Produces: deterministic critical-state checks and screenshot artifacts for 320/390/768/1440 widths.

- [ ] Add tests for loading, empty, offline/error, KYC pending, protected trade fields, and responsive navigation.
- [ ] Confirm focused tests expose any missing contracts.
- [ ] Make the smallest UI/test-fixture adjustments required without changing business requests.
- [ ] Run focused and complete Flutter/Admin/PWA suites.
- [ ] Commit the task.

### Task 6: Session-security regression matrix

**Files:**
- Create: `apps/api/src/auth/auth-enterprise-session-matrix.spec.ts`
- Modify only proven auth/session implementation gaps discovered by the test.
- Modify: `docs/上线准备与验收.md`

**Interfaces:**
- Verifies existing customer and staff credentials while testing logout, disable, password change, 2FA reset, refresh replay, and concurrent-device boundaries.

- [ ] Add characterization tests before implementation changes.
- [ ] Run and classify failures as missing behavior or documented current policy.
- [ ] Fix only security defects that do not add login steps or credentials.
- [ ] Run all auth tests and API suite.
- [ ] Commit the task.

### Task 7: Unified production acceptance gate

**Files:**
- Create: `scripts/production-acceptance.mjs`
- Create: `scripts/tests/production-acceptance.test.mjs`
- Create: `.github/workflows/enterprise-acceptance.yml`
- Modify: `scripts/verify-all.ps1`
- Modify: `scripts/verify-all.sh`

**Interfaces:**
- Consumes: exact SHA and component reports.
- Produces: `enterprise-acceptance.json` separating `repositoryComplete`, `environmentComplete`, and `externalComplete`; overall production complete is true only when all required real evidence exists.

- [ ] Write failing tests for stale SHA, missing artifacts, simulated evidence, and fully valid fixtures.
- [ ] Implement the manifest aggregator and workflow.
- [ ] Integrate it with repository verification without making local development require production credentials.
- [ ] Run all script contract tests.
- [ ] Commit the task.

### Task 8: Documentation, full verification, and delivery

**Files:**
- Modify: `README.md`
- Modify: `docs/STATUS.md`
- Modify: `docs/交付验收清单.md`
- Modify: `docs/ai/CURRENT_STATE.md`
- Modify: `docs/ai/SESSION_HANDOFF.md`

**Interfaces:**
- Records exact commit, commands, outputs, limitations, and external evidence still required.

- [ ] Update documentation from verified results only.
- [ ] Run formatting, lint, focused tests, full component suites, release checks, and complete repository verification.
- [ ] Review the full diff for secrets, generated output, unrelated changes, and protected-flow changes.
- [ ] Request independent whole-branch review and resolve Critical/Important findings through tests.
- [ ] Push once, create a PR, monitor every workflow, fix any failure locally, and verify GitHub governance.
- [ ] Merge only after checks and review are complete, then verify `main` and clean the worktree safely.

