# Dashboard Query Plan Verification

## Status

Deferred: no local/test PostgreSQL connection was configured during this run. The API workspace has no `.env`, and neither `DATABASE_URL` nor `SHADOW_DATABASE_URL` is present in the process environment. No database was contacted, no query plan was fabricated, and no schema or migration was changed.

## Schema-declared index inventory

This is a source-level inventory from `apps/api/prisma/schema.prisma`, not proof that a target database has applied the corresponding migrations.

| Read path | Relevant declared indexes |
| --- | --- |
| Assigned customers and account balance aggregate | `users(assignedBusinessId)`; `accounts(userId)` is unique |
| Completed admin-credit totals | `account_transactions(accountId, createdAt)`, `account_transactions(status)` |
| Withdrawal totals and pending counts | `withdrawal_requests(accountId)`, `withdrawal_requests(status)` |
| Pending deposit counts | `deposit_requests(accountId)`, `deposit_requests(status, createdAt)` |
| Pending IPO applications and open IPO debt | `ipo_applications` has no explicit secondary index; `ipo_debts(accountId)`, `ipo_debts(status)` |
| Outstanding loans | `loan_applications(accountId)`, `loan_applications(status)` |
| Failed login window and shared IP/device reads | `login_audits(userId)`, `login_audits(createdAt)` |

Single-column indexes may or may not be combined efficiently for the actual joins and predicates. This inventory alone is not a reason to add a composite index.

## Required local verification

When an isolated local/test PostgreSQL database is available:

1. Confirm its target explicitly and apply the repository migrations only to that disposable/test database.
2. Capture Prisma-generated SQL for the account aggregate, transaction and withdrawal totals, pending deposit/withdrawal/IPO counts, open debt and loan aggregates, and failed-login window counts. Redact bind values and returned rows before saving any output.
3. Run `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` for representative parameterized statements, recording table row counts and plan summaries without IDs, phone numbers, account numbers, IP addresses, user agents, credentials, or result rows.
4. Compare estimated/actual rows, loops, buffer reads/hits, and execution time against the schema-declared indexes and the existing deployed indexes.
5. Propose an additive index only when repeated before/after measurements show a material improvement on representative data. Record the exact migration rollback procedure and rerun the same plans and API tests.

Until those measurements exist, the account aggregation optimization remains the only database read-path change; no speculative index is proposed.
