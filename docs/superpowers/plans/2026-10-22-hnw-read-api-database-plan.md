# HNW Read API and Database Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` for independent tasks or `superpowers:executing-plans` for single-agent execution. Follow `superpowers:test-driven-development` for each behavior change.

**Goal:** Reduce avoidable work on dashboard read paths while preserving API response shape, authentication and role scope, decimal behavior, risk thresholds, and all financial write behavior.

**Architecture:** Characterize existing read behavior first. Replace the business dashboard's account-row fetch and in-memory balance reduction with a database aggregate. Capture PostgreSQL query plans for the dashboard read queries and add only indexes supported by plan evidence. Keep all endpoint paths and write services unchanged.

**Tech Stack:** NestJS, Prisma 7, PostgreSQL, Jest, Supertest, Prisma Decimal.

**Spec:** `docs/superpowers/specs/2026-10-22-hnw-ui-ux-foundation-design.md`

## Global Constraints

- Work only on dashboard and risk-summary read paths. Do not edit trading/matching/order execution, authentication/registration/login, deposits, withdrawals, KYC review, or financial write code.
- Preserve endpoint paths, HTTP methods, role guards, response field names, and caller identity scopes.
- Preserve money as Prisma Decimal through aggregation and retain existing two-decimal string serialization.
- Preserve empty-result behavior (`0`, `0.00`, and empty arrays as currently returned), local start-of-day boundaries, 24-hour boundaries, and risk thresholds: 5 failed logins is MEDIUM; 10 is HIGH.
- Business/support reads must remain scoped to the authenticated operator's assigned customers.
- Do not add PII to logs, fixtures, or committed query-plan artifacts.
- Do not add an index until a read-only `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` comparison shows a worthwhile improvement. Any resulting migration must be additive and have a clear rollback procedure.
- Do not connect to or mutate production data. Run database checks only against the configured local/test database.

## Review Focus

- Assigned-business filters remain present on every business-scoped read.
- Decimal sums and zero/null behavior match the current response exactly.
- Risk counts include the same 24-hour window and preserve 5/10 thresholds.
- Any index is justified by before/after query-plan evidence and does not duplicate an existing index.
- No financial write, auth, trading, or deposit-method files appear in the diff.

## Tasks

### Task 1: Characterize business dashboard and risk behavior (RED)

**Files:**
- Create `apps/api/src/business/business-dashboard.service.spec.ts`
- Create `apps/api/src/business/business-risk.service.spec.ts`
- Extend `apps/api/src/admin/admin.service.spec.ts` only if needed to characterize the existing login-risk summary contract

**Steps:**
1. Add dashboard tests for response keys, two-decimal string totals, empty sums, zero counts, and the assigned-business relation predicates used by deposit, withdrawal, loan, IPO, and account reads.
2. Add risk tests for customer ownership isolation, 24-hour failed-login counts, and exact MEDIUM/HIGH transitions at 5 and 10 attempts.
3. Add admin summary characterization for total failed attempts, risk counts, and the existing recent-failure limit of 20 if that service is included in query-plan work.
4. Run from `apps/api`: `npm test -- --runInBand business/business-dashboard.service.spec.ts business/business-risk.service.spec.ts admin/admin.service.spec.ts`.
5. Confirm the new tests fail for the intended missing coverage or implementation expectation, then commit: `test(api): characterize dashboard read contracts`.

### Task 2: Aggregate business account balances in PostgreSQL

**Files:**
- Modify `apps/api/src/business/business-dashboard.service.ts`
- Modify `apps/api/src/business/business-dashboard.service.spec.ts`

**Steps:**
1. Replace `account.findMany` selecting each balance plus the JavaScript reduction with `account.aggregate` using `_sum` for `cashBalance` and `frozenBalance`, scoped through `user.assignedBusinessId`.
2. Add the two Prisma Decimal sums and preserve the existing `.toFixed(2)` response field.
3. Keep every other dashboard query, response key, and count unchanged.
4. Run the focused test command from Task 1 and confirm GREEN; then run the complete API test suite with `npm test -- --runInBand`.
5. Commit: `perf(api): aggregate business dashboard balances in database`.

### Task 3: Verify authenticated HTTP boundaries

**Files:**
- Create or extend `apps/api/src/business/business-dashboard.http.spec.ts`
- Reuse existing helpers in `apps/api/src/test/` and patterns from `apps/api/src/business/business-assignment.http.spec.ts`

**Steps:**
1. Exercise `GET /business/my-dashboard` and `GET /business/my-risk-dashboard` with an authenticated BUSINESS or SUPPORT identity and assert the service receives that identity's user ID.
2. Assert a CLIENT identity remains forbidden by existing role guards.
3. Assert response shapes are passed through unchanged; do not alter controller or guard behavior unless a characterization test exposes an existing regression directly relevant to this scope.
4. Run the focused HTTP spec and commit: `test(api): verify dashboard read access boundaries`.

### Task 4: Measure and optimize database read plans

**Files:**
- Potentially modify `apps/api/prisma/schema.prisma`
- Potentially add one Prisma migration under `apps/api/prisma/migrations/`
- Record sanitized before/after plan summaries in `docs/verification/2026-10-23-dashboard-query-plans.md` only if a schema change is proposed

**Steps:**
1. Identify the SQL generated for the characterized dashboard queries using local Prisma query logging or PostgreSQL `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`; keep parameters and returned rows out of logs.
2. Capture plans before any schema change for account aggregation, transaction totals, pending funding counts, and failed-login window queries.
3. Compare against current indexes in `apps/api/prisma/schema.prisma`; do not add duplicate or speculative indexes.
4. If evidence supports an index, add the smallest additive Prisma index and migration, then rerun the same plans and focused tests. If evidence does not support an index, leave schema and migrations unchanged and record that outcome in the final report.
5. Run `npx prisma validate` and commit any evidence-backed schema change separately: `perf(db): index measured dashboard read path`.

### Task 5: Full API verification and scope review

**Files:** No additional files unless verification reveals a directly related defect.

**Steps:**
1. Run `npm run lint`, `npm test -- --runInBand`, `npm run build`, and `npx prisma validate` from `apps/api`.
2. Review `git diff --check` and the full changed-file list.
3. Confirm there are no modifications under trading/order execution, auth, deposit/withdrawal writes, KYC review, or payment-method configuration.
4. Report test/build results and any local database/EXPLAIN limitation. Do not deploy or run a production migration.
