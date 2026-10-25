# HNW Enterprise Reliability & Pixel-Level UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade HNW to an enterprise-grade India stock application with pixel-level Flutter/Admin UI quality while preserving every protected registration, login, password recovery, manual deposit, trading, trade-page, and staff-authentication behavior.

**Architecture:** Keep the existing Flutter + Next.js + NestJS modular monolith and PostgreSQL source of truth. Establish immutable product-contract and visual baselines first; then improve UI states, concurrency integrity, reconciliation, reliable events, market-data recovery, multi-instance operations, observability, load/chaos verification, and staged rollout.

**Tech Stack:** Flutter/Dart, Next.js/React/TypeScript/Ant Design, NestJS/Node.js 24, Prisma 7, PostgreSQL 17, Redis 7, TimescaleDB-compatible PostgreSQL, Docker Compose/Coolify, Prometheus/Grafana, GitHub Actions, k6.

**Spec:** `docs/superpowers/specs/2026-10-25-hnw-india-stock-reliability-upgrade-design.md`

## Global Constraints

- Protected baseline: `main@8d0dcd3e55e65324dc5659e89a186c9acc49147d`.
- Preserve India phone + password + invite registration; phone + password login; support-issued recovery code; support/manual-credit deposit.
- Preserve BUY/SELL, MARKET/LIMIT, DAY/IOC/FOK, quantity, limit price, freeze, matching, cancellation, settlement, and idempotency semantics.
- Preserve staff employee number/password, mandatory authenticator setup, OTP login, and scoped reset.
- Trade-page visual hierarchy/copy may change; its fields, defaults, validation, confirmation, payload, and submission path may not.
- Customer App must not expose repository, stack, endpoints, environment names, DB fields, internal roles, vendor diagnostics, secrets, stack traces, test data, or internal IDs.
- PostgreSQL remains authoritative for balances, orders, trades, approvals, and audit. Redis/events/caches/replicas/time-series are never sole financial truth.
- No crypto, blockchain, wallet, GTT, basket, F&O, leverage, copy trading, or new product.
- UI changes use existing design tokens and localization. Flutter must work at 320 logical px, landscape, keyboard visible, and text scale 1.4.
- Every task is independently reviewed, tested, reversible, and committed once local verification passes.

## Review Focus

- A committed order whose response is lost must be found by clientOrderId, never resubmitted.
- Concurrent fill/cancel must produce one legal state and preserve cash/position invariants.
- Redis outage must fail closed only for the protected-write list and degrade read-only surfaces honestly.
- Duplicate/out-of-order events and quotes must never move state backward.
- Pixel-level polish must not introduce clipped text, inaccessible contrast, hidden fields, misleading defaults, or business-contract drift.

---

## Task 1: Lock protected business contracts in CI

**Files:**
- Create: `docs/contracts/protected-flows-v1.md`
- Create: `scripts/verify-protected-flows.ps1`
- Create: `scripts/verify-protected-flows.sh`
- Create: `apps/client/test/protected_flows_contract_test.dart`
- Modify: `apps/api/src/auth/auth-register.characterization.spec.ts`
- Modify: `apps/api/src/auth/auth-login.characterization.spec.ts`
- Modify: `apps/api/src/trading/trading-path.characterization.spec.ts`
- Modify: `apps/api/src/deposit/deposit-self-serve.http.spec.ts`
- Modify: `.github/workflows/api-ci.yml`
- Modify: `.github/workflows/flutter-ci.yml`

**Interfaces:**
- Consumes: Approved baseline routes, DTOs, database effects, and Flutter navigation.
- Produces: `verify-protected-flows` with exit 0 only when all protected contracts match.

- [ ] Write the contract table: method, route, required/forbidden fields, response, DB effect, and client flow.
- [ ] Add failing assertions for support-based reset, support/manual deposit, current order types/state behavior, and forbidden OTP/email/payment fields.
- [ ] Add Flutter assertions for visible fields and unchanged service payloads.
- [ ] Implement PowerShell/Bash gates and run them before broader CI suites.
- [ ] Verify focused suites, then full API/Flutter tests.
- [ ] Commit: `test: lock protected customer and trading flows`.

## Task 2: Establish the pixel-level visual system and screenshot baseline

**Files:**
- Create: `docs/ui/HNW_VISUAL_ACCEPTANCE_MATRIX.md`
- Create: `docs/ui/reference-screens/README.md`
- Create: `apps/client/test/goldens/auth_golden_test.dart`
- Create: `apps/client/test/goldens/trading_golden_test.dart`
- Create: `apps/client/test/goldens/markets_portfolio_golden_test.dart`
- Create: `apps/client/test/goldens/profile_support_golden_test.dart`
- Create: `apps/admin/tests/visual-layout-contracts.test.mjs`
- Create: `scripts/capture-admin-visuals.mjs`
- Modify: `apps/client/lib/theme/app_colors.dart`
- Modify: `apps/client/lib/theme/app_typography.dart`
- Modify: `apps/client/lib/theme/app_spacing.dart`
- Modify: `apps/client/lib/theme/app_radius.dart`
- Modify: `apps/client/lib/theme/app_shadows.dart`
- Modify: `apps/client/lib/theme/app_motion.dart`
- Modify: `apps/admin/app/globals.css`

**Interfaces:**
- Produces: One shared token inventory, approved viewport matrix, Flutter golden images, and Admin screenshot artifacts.
- Visual matrix: 320×640, 360×800, 390×844, 412×915, landscape phone, tablet; Admin 1280×720, 1440×900, 1920×1080.

- [ ] Inventory every raw color/font/spacing/radius/shadow and map it to semantic tokens.
- [ ] Define pixel acceptance: 8 px rhythm, typography hierarchy, 44/48 px touch targets, focus ring, contrast, table density, skeleton/error/empty states.
- [ ] Add failing Flutter goldens for English, Hindi, text scale 1.0/1.4, reduced motion, light/dark only where already supported.
- [ ] Add Admin layout assertions and deterministic screenshot capture for all five roles.
- [ ] Normalize tokens without changing navigation or business behavior.
- [ ] Review every diff manually; intentional baseline updates require an attached before/after note.
- [ ] Verify Flutter goldens, Admin lint/test/build, accessibility, and protected flows.
- [ ] Commit: `feat: establish pixel-level visual acceptance system`.

## Task 3: Enforce the customer-app information boundary

**Files:**
- Create: `apps/client/test/client_information_boundary_test.dart`
- Create: `scripts/check-client-information-boundary.mjs`
- Modify: `apps/client/lib/utils/client_error_message.dart`
- Modify: `apps/client/lib/services/error_telemetry.dart`
- Modify: `apps/client/lib/pages/legal_page_content.dart`
- Modify: `apps/client/lib/l10n/app_language.dart`
- Modify: `apps/client/lib/l10n/hindi_language.dart`
- Modify: `.github/workflows/flutter-ci.yml`

**Interfaces:**
- Produces: `ClientSafeError(message, requestId)` and redacted telemetry.

- [ ] Add failing tests for internal paths, stack/SQL, hosts, environments, DB fields, roles, vendor details, fixtures, and raw third-party errors.
- [ ] Implement a production-source scanner with narrow approved legal-copy exceptions.
- [ ] Map known business codes to localized actionable copy; unknown errors show generic copy + requestId.
- [ ] Redact tokens, phone, bank, identity, URLs, stack paths, and bodies before telemetry.
- [ ] Run scanner, focused tests, full Flutter analyze/tests, and protected gate.
- [ ] Commit: `security: enforce customer app information boundary`.

## Task 4: Pixel-polish the protected authentication and support flows

**Files:**
- Modify: `apps/client/lib/pages/register_page.dart`
- Modify: `apps/client/lib/pages/register_page_content.dart`
- Modify: `apps/client/lib/pages/login_page.dart`
- Modify: `apps/client/lib/pages/forgot_password_page.dart`
- Modify: `apps/client/lib/pages/deposit_page.dart`
- Modify: `apps/client/lib/widgets/onboarding_auth_widgets.dart`
- Modify: `apps/client/lib/theme/auth_layout.dart`
- Modify: `apps/client/test/auth_ui_phase_a_test.dart`
- Modify: `apps/client/test/k3_auth_responsive_test.dart`
- Modify: `apps/client/test/deposit_history_j1_test.dart`

**Interfaces:**
- Consumes and produces exactly the protected AuthService/deposit-support payloads.

- [ ] Add golden/semantic tests at every viewport and language before editing.
- [ ] Improve spacing, input hierarchy, keyboard behavior, focus/error placement, button states, support explanations, and visual consistency.
- [ ] Keep every current field and reset/deposit support step.
- [ ] Run protected gate, goldens, full Flutter suite, and real Android smoke.
- [ ] Commit: `feat: polish protected authentication and support screens`.

## Task 5: Pixel-polish the trading journey without core drift

**Files:**
- Modify: `apps/client/lib/widgets/trading/order_ticket.dart`
- Modify: `apps/client/lib/widgets/trading/order_estimate_card.dart`
- Modify: `apps/client/lib/widgets/trading/order_confirm_dialog.dart`
- Modify: `apps/client/lib/widgets/trading/order_card.dart`
- Modify: `apps/client/lib/pages/stock_detail_page_order_section.dart`
- Modify: `apps/client/lib/pages/trading_center_page_content_section.dart`
- Modify: `apps/client/lib/services/trading_service.dart`
- Modify: `apps/client/test/trade_order_ui_phase_d1_test.dart`
- Modify: `apps/client/test/trade_order_ui_phase_d2_test.dart`
- Modify: `apps/client/test/order_confirmation_test.dart`
- Modify: `apps/client/test/order_idempotency_test.dart`
- Modify: `apps/client/test/order_cancel_recovery_test.dart`

**Interfaces:**
- Same request payload and navigation; clearer layout and unknown-result recovery only.

- [ ] Pin fields, defaults, BUY/SELL, MARKET/LIMIT, DAY/IOC/FOK, quantity, price, confirmation, callbacks, and payload.
- [ ] Add lost-response test: display “check order status,” retain clientOrderId, never submit twice.
- [ ] Refine quote context, grouping, estimate/risk hierarchy, touch/focus order, and status timeline using tokens.
- [ ] Route unknown confirmation to existing order lookup by the same clientOrderId.
- [ ] Verify goldens, protected contracts, focused/full tests, and Android smoke.
- [ ] Commit: `feat: deliver pixel-level protected trade experience`.

## Task 6: Complete Home, Markets, Portfolio, Profile, and support visual/state consistency

**Files:**
- Modify: `apps/client/lib/models/async_data_state.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard.dart`
- Modify: `apps/client/lib/pages/markets_page.dart`
- Modify: `apps/client/lib/pages/stock_detail_page.dart`
- Modify: `apps/client/lib/pages/product_portfolio_page.dart`
- Modify: `apps/client/lib/pages/market_page_account_section.dart`
- Modify: `apps/client/lib/pages/support_chat_page.dart`
- Modify: `apps/client/lib/services/market_socket_service.dart`
- Create: `apps/client/test/network_failure_matrix_test.dart`
- Create: `apps/client/test/market_socket_recovery_test.dart`

**Interfaces:**
- Produces: shared state preserving last-known data, freshness, request generation, retryability.

- [ ] Test loading, empty, denied, offline, timeout, partial, stale, retry, background/resume, old-request race, socket duplicate/gap/out-of-order.
- [ ] Add freshness/request-generation metadata without converting failure to zero/empty.
- [ ] Normalize card/table/list spacing, typography, skeletons, empty/error/stale banners, and responsive layouts.
- [ ] Ensure every price and P&L displays source time/quality and INR formatting.
- [ ] Verify goldens, all Flutter tests, protected contracts, and low-end Android performance.
- [ ] Commit: `feat: unify resilient customer journeys`.

## Task 7: Pixel-polish and harden all five Admin roles

**Files:**
- Modify: `apps/admin/components/AdminShell.tsx`
- Modify: `apps/admin/components/OpsPageHeader.tsx`
- Modify: `apps/admin/components/OpsToolbar.tsx`
- Modify: `apps/admin/components/OpsModal.tsx`
- Modify: `apps/admin/components/OpsErrorState.tsx`
- Modify: `apps/admin/components/OpsOrderWorkspace.tsx`
- Modify: `apps/admin/components/OpsTradeWorkspace.tsx`
- Create: `apps/admin/components/OpsDataPage.tsx`
- Create: `apps/admin/lib/ops-page-registry.ts`
- Create: `apps/admin/lib/ops-mutation-contract.ts`
- Modify: `apps/admin/lib/admin-navigation.ts`
- Modify: `apps/admin/lib/role-permissions.ts`
- Modify: `apps/admin/app/deposits/page.tsx`
- Modify: `apps/admin/app/orders/page.tsx`
- Modify: `apps/admin/app/trades/page.tsx`
- Modify: `apps/admin/app/audit-logs/page.tsx`
- Create: `apps/admin/app/system-health/page.tsx`
- Create: `apps/admin/app/system-governance/page.tsx`
- Modify: `apps/admin/app/globals.css`
- Modify: `apps/admin/tests/role-permissions.test.mjs`
- Modify: `apps/admin/tests/g4-orders-trades.test.mjs`
- Create: `apps/admin/tests/ops-failure-states.test.mjs`
- Create: `apps/admin/tests/ops-page-registry.test.mjs`
- Create: `apps/admin/tests/ops-maintainability.test.mjs`
- Create: `docs/admin/ADMIN_MODULE_MAINTENANCE.md`

**Interfaces:**
- Existing Admin routes and permission matrix; no new role capability.

- [ ] Pin role menus/endpoints and add 403/409/429/timeout/partial/stale/unknown-result tests.
- [ ] Centralize every route, title, breadcrumb, menu item, required role, module owner, and API dependency in one typed registry.
- [ ] Introduce one reusable server-paginated data-page contract and one audited mutation contract; remove duplicated page-local implementations as each page migrates.
- [ ] Standardize grid, page width, sidebar, headers, filters, tables, drawers, confirmations, status tags, density, and responsive breakpoints.
- [ ] Require current/new value, impact, reason, requestId, and explicit confirmation for writes.
- [ ] Add governance and health views for audit, reconciliation, API/DB/Redis/market/worker health, deployment version, and configuration provenance; never display secret values.
- [ ] Add maintainability tests that fail on unregistered routes, duplicated permission logic, direct raw fetch in migrated pages, unbounded lists, or missing loading/error/denied states.
- [ ] Document each module's responsibility, API, permission boundary, data source, alert, common failure, and rollback.
- [ ] Capture and review every role at all Admin viewports.
- [ ] Run lint/tests/typecheck/build, accessibility, screenshot comparison, and protected API tests.
- [ ] Commit: `feat: deliver pixel-level role-scoped operations UI`.

## Task 8: Centralize transaction retry and order-state guards

**Files:**
- Create: `apps/api/src/common/transaction-retry.ts`
- Create: `apps/api/src/common/transaction-retry.spec.ts`
- Create: `apps/api/src/trading/order-state-machine.ts`
- Create: `apps/api/src/trading/order-state-machine.spec.ts`
- Modify: `apps/api/src/trading/order-submission.service.ts`
- Modify: `apps/api/src/trading/order-cancellation.service.ts`
- Modify: `apps/api/src/trading/settlement.service.ts`
- Modify: `apps/api/src/trading/day-order-expiry.scheduler.ts`
- Modify: `apps/api/src/trading/order-match-cancel-race.spec.ts`
- Create: `apps/api/src/database/order-concurrency.pg.spec.ts`

**Interfaces:**
- Produces: `runSerializableTransaction<T>(operation, options): Promise<T>`.
- Produces: `assertOrderTransition(from: OrderStatus, to: OrderStatus): void`.

- [ ] Test documented transitions, duplicate settlement, double cancellation, fill/cancel/expiry races, and money/position conservation.
- [ ] Run real disposable-PostgreSQL simultaneous-command tests.
- [ ] Retry only recognized transient DB errors with jitter and strict limit.
- [ ] Route transitions through the guard without public-contract change.
- [ ] Run protected gate and full API verification.
- [ ] Commit: `refactor: centralize order transaction integrity`.

## Task 9: Add read-only financial reconciliation and exception isolation

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/<timestamp>_financial_reconciliation/migration.sql`
- Create: `apps/api/src/reconciliation/reconciliation.module.ts`
- Create: `apps/api/src/reconciliation/reconciliation.service.ts`
- Create: `apps/api/src/reconciliation/reconciliation.controller.ts`
- Create: `apps/api/src/reconciliation/reconciliation.scheduler.ts`
- Create: `apps/api/src/reconciliation/reconciliation.pg.spec.ts`
- Create: `apps/admin/app/reconciliation/page.tsx`
- Create: `apps/admin/components/ReconciliationWorkspace.tsx`
- Modify: `apps/admin/lib/role-permissions.ts`
- Create: `apps/admin/tests/reconciliation-workspace.test.mjs`

**Interfaces:**
- Produces read-only `ReconciliationRun`/`ReconciliationIssue`; never auto-mutates balances.

- [ ] Model run/issue/audit fields and migration/upgrade tests.
- [ ] Check cash vs ledger, frozen cash vs buy orders, frozen quantity vs sell orders, trades vs fills, duplicate idempotency.
- [ ] Use PostgreSQL advisory lock for one scheduler; expose duration/count/failure metrics.
- [ ] Add scoped Admin list/detail/acknowledge, without “fix balance.”
- [ ] Verify migration, PG/API/Admin tests and builds.
- [ ] Commit: `feat: add auditable financial reconciliation`.

## Task 10: Add a transactional outbox for non-authoritative side effects

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/<timestamp>_transactional_outbox/migration.sql`
- Create: `apps/api/src/outbox/outbox.module.ts`
- Create: `apps/api/src/outbox/outbox.service.ts`
- Create: `apps/api/src/outbox/outbox.worker.ts`
- Create: `apps/api/src/outbox/outbox-event.ts`
- Create: `apps/api/src/outbox/outbox.pg.spec.ts`
- Modify: `apps/api/src/observability/metrics.ts`
- Modify: `apps/api/src/app.module.ts`

**Interfaces:**
- Produces: `enqueue(tx, event: OutboxEventInput): Promise<void>` with eventId/type/aggregate/version/schema/time/correlation/payload.
- Delivery is at least once; consumers deduplicate by eventId.

- [ ] Test transaction rollback, commit, duplicate event, lease expiry, worker crash, retry, and dead letter.
- [ ] Implement `FOR UPDATE SKIP LOCKED` bounded leasing.
- [ ] Move notifications/exports/audit replication first; never balance/order/matching authority.
- [ ] Add backlog/dead-letter metrics and alerts.
- [ ] Verify migrations and full API; commit `feat: add transactional outbox processing`.

## Task 11: Make market data sequence-aware and isolate time-series storage

**Files:**
- Modify: `apps/api/src/market-data/quote-ingestion.service.ts`
- Modify: `apps/api/src/market-data/streaming-market-data.service.ts`
- Modify: `apps/api/src/market-data/market-data-health.service.ts`
- Modify: `apps/api/src/market-data/websocket/market-data/market-data.gateway.ts`
- Create: `apps/api/src/market-timeseries/market-timeseries.module.ts`
- Create: `apps/api/src/market-timeseries/market-timeseries.service.ts`
- Create: `apps/api/src/market-timeseries/market-timeseries.interface.ts`
- Create: `docker/timescaledb/init/001_market_timeseries.sql`
- Modify: `apps/client/lib/services/market_socket_service.dart`
- Modify: `compose.local-test.yaml`
- Modify: `compose.production.yaml`
- Create: `apps/client/test/market_quote_quality_test.dart`

**Interfaces:**
- Quote: instrumentId/exchange/sequence/price/sourceTimestamp/receivedAt/quality.
- Quality: `LIVE | DELAYED | STALE | UNAVAILABLE`.
- Time-series: `appendTick` and `getCandles`; unavailable charts never block financial transactions.

- [ ] Test duplicate/gap/out-of-order/restart/stale behavior and IST candle boundaries/late ticks/corrections.
- [ ] Implement per-instrument sequence and authenticated snapshot resync.
- [ ] Create isolated hypertables, retention, compression, and aggregates.
- [ ] Buffer/retry time-series writes without blocking order paths.
- [ ] Show freshness everywhere without provider internals.
- [ ] Verify API/Flutter/Compose/failure-isolation tests.
- [ ] Commit: `feat: make market data recovery and history resilient`.

## Task 12: Harden Redis, multi-instance operation, and deployment edge

**Files:**
- Modify: `apps/api/src/common/rate-limit-store.ts`
- Create: `apps/api/src/common/redis-health.service.ts`
- Create: `apps/api/src/common/redis-lease.ts`
- Modify: `apps/api/src/auth/session-policy.ts`
- Modify: `apps/api/src/health/health.controller.ts`
- Create: `docker/gateway/envoy.yaml`
- Create: `docker/gateway/README.md`
- Modify: `compose.local-test.yaml`
- Modify: `compose.production.yaml`
- Modify: `scripts/verify-release-config.ps1`
- Create: `scripts/verify-release-config.sh`
- Modify: `.github/workflows/docker-ci.yml`
- Modify: `.github/workflows/production-deploy.yml`

**Interfaces:**
- `RedisLease.acquire(resource, ttlMs, owner)`; release verifies owner token.
- Gateway forwards bounded trusted headers/WSS; API remains authorization boundary.

- [ ] Test disconnect/reconnect/failover/stale owner/two-instance shared limits.
- [ ] Add deadlines, jittered reconnect, and no infinite command queue.
- [ ] Apply the exact design `17 fail-closed list; read-only paths degrade honestly.
- [ ] Add opt-in Envoy profile, body/time/connection limits, WSS, trusted proxy validation.
- [ ] Require exact SHA, compatible migration, protected gate, smoke, and rollback metadata.
- [ ] Verify two-instance Compose, container/security/config tests.
- [ ] Commit: `ops: harden multi-instance deployment path`.

## Task 13: Complete observability, runbooks, load, soak, chaos, and release gates

**Files:**
- Modify: `apps/api/src/observability/metrics.ts`
- Modify: `docker/observability/alerts.yml`
- Modify: `docker/observability/hnw-api-dashboard.json`
- Create: `docker/observability/hnw-financial-integrity-dashboard.json`
- Create: `docs/runbooks/order-unknown-state.md`
- Create: `docs/runbooks/reconciliation-issue.md`
- Create: `docs/runbooks/market-data-stale.md`
- Create: `docs/runbooks/redis-unavailable.md`
- Create: `tests/load/k6-read-paths.js`
- Create: `tests/load/k6-order-idempotency.js`
- Create: `tests/load/k6-market-websocket.js`
- Create: `tests/chaos/run-failure-matrix.ps1`
- Create: `tests/chaos/run-failure-matrix.sh`
- Create: `docs/verification/enterprise-capacity-template.md`
- Create: `docs/rollout/enterprise-upgrade-rollout.md`
- Create: `docs/rollout/enterprise-upgrade-rollback.md`
- Modify: `scripts/verify-all.ps1`
- Modify: `scripts/verify-all.sh`
- Modify: `docs/交付验收清单.md`
- Modify: `docs/上线准备与验收.md`

**Interfaces:**
- Metrics use bounded labels and no customer/financial identifiers.
- Test report includes SHA, environment, hardware, dataset, duration, p50/p95/p99, errors, invariants, recovery.

- [ ] Test metrics and SLO rules for core market-hours journeys.
- [ ] Add runbooks with impact, checks, safe mitigation, rollback, escalation, and prohibited actions.
- [ ] Load-test reads, orders/idempotency, sockets, open burst, reconnect storm, and report coexistence.
- [ ] Chaos-test API loss, Redis loss, disposable Postgres failover, feed loss, and worker crash.
- [ ] Run a full simulated market-session soak and verify zero reconciliation differences.
- [ ] Define rollout internal → small cohort → increasing cohorts → full; stop on any protected/financial anomaly.
- [ ] Define rollback that never reverses committed financial facts.
- [ ] Run full Windows/Linux verification and security scans for one SHA.
- [ ] Commit: `test: add enterprise acceptance and rollout gates`.

## Final Integration Gate

- [ ] Integrate in order 1 → 2 → 3 → 4/5/6/7 → 8 → 9 → 10 → 11 → 12 → 13.
- [ ] Run protected-flow gate after every task; full verification at every workstream boundary.
- [ ] Use a fresh reviewer for every financial/data migration task and one whole-branch review before PR.
- [ ] Every pixel-level screen receives before/after evidence, golden/screenshot review, accessibility check, and real-device/browser verification.
- [ ] Push once after local verification, inspect every remote job, merge only when required checks pass, then verify post-merge `main`.

## Standard Verification Commands

Every task runs its focused tests first, observes the new test fail before implementation, then observes it pass after implementation. Workstream completion uses:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-protected-flows.ps1
cd apps\api
npm run lint
npm run build
npm test -- --runInBand
cd ..\admin
npm run lint
npm test
npx tsc --noEmit
$env:NEXT_PUBLIC_API_URL='https://build.invalid'
npm run build
cd ..\client
flutter analyze
flutter test
```

Expected: exit code 0 for each affected application. PostgreSQL/Redis integration, migration, load, chaos, Docker, visual capture, and release checks additionally require their explicitly disposable environments; no test may point at production.
