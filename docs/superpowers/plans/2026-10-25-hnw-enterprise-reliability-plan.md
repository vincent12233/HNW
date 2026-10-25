# HNW Enterprise Reliability & Pixel-Level UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade HNW to an enterprise-grade India stock application with pixel-level Flutter/Admin UI quality while preserving every protected registration, login, password recovery, manual deposit, trading, trade-page, and staff-authentication behavior.

**Architecture:** Keep the existing Flutter + Next.js + NestJS modular monolith and PostgreSQL source of truth. Establish immutable product-contract and visual baselines first; then improve UI states, concurrency integrity, reconciliation, reliable events, market-data recovery, multi-instance operations, observability, load/chaos verification, and staged rollout.

**Tech Stack:** Flutter/Dart, Next.js/React/TypeScript/Ant Design, NestJS/Node.js 24, Prisma 7, PostgreSQL 17, Redis 7, TimescaleDB-compatible PostgreSQL, Docker Compose/Coolify, Prometheus/Grafana, GitHub Actions, k6.

**Spec:** `docs/superpowers/specs/2026-10-25-hnw-india-stock-reliability-upgrade-design.md`

**Business Baseline:** `docs/HNW_MASTER_REQUIREMENTS_ZH.md`

## Global Constraints

- Protected baseline: `main@8d0dcd3e55e65324dc5659e89a186c9acc49147d`.
- Preserve India phone + password + invite registration; phone + password login; support-issued recovery code; support/manual-credit deposit.
- Preserve BUY/SELL, MARKET/LIMIT, DAY/IOC/FOK, quantity, limit price, freeze, matching, cancellation, settlement, and idempotency semantics.
- Preserve staff employee number/password, mandatory authenticator setup, OTP login, and scoped reset.
- Preserve customer-facing support/recovery/deposit entry behavior while consolidating all chat into SaleSmartly; remove the standalone HNW support console only after verified migration, without deleting required recovery/deposit business controls or historical records.
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
- Create: `apps/client/lib/widgets/app_status_scene.dart`
- Create: `apps/client/lib/widgets/app_status_timeline.dart`
- Create: `apps/client/test/app_status_scene_test.dart`
- Create: `apps/client/test/goldens/status_scenes_golden_test.dart`
- Create: `docs/client/CLIENT_SCREEN_INVENTORY.md`
- Create: `scripts/check-client-screen-inventory.mjs`
- Create: `scripts/client-screen-inventory.json`
- Create: `scripts/tests/client-screen-inventory.test.mjs`
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
- Visual matrix: 320×640, 360×800, 390×844, 412×915, landscape phone, tablet; customer Web/PWA 768×1024, 1024×768, 1280×720, 1440×900, 1920×1080; Admin 1280×720, 1440×900, 1920×1080.

- [ ] Inventory every raw color/font/spacing/radius/shadow and map it to semantic tokens.
- [ ] Define pixel acceptance: 8 px rhythm, typography hierarchy, 44/48 px touch targets, focus ring, contrast, table density, skeleton/error/empty states.
- [ ] Inventory every loading/submitting/pending/processing/success/rejected/error/empty/offline/stale/unknown-result surface in Flutter, Web/PWA and Admin; map each to one semantic presentation contract.
- [ ] Inventory every Flutter page, navigation destination, drawer, sheet and dialog with its entry point, tier, prerequisite, platform, protected-flow flag, state matrix and visual evidence; fail CI when a new surface is unregistered.
- [ ] Build shared enterprise status-scene and status-timeline components with title, explanation, status, freshness, next step and actions; eliminate oversized hourglasses, arbitrary standalone spinners and inconsistent result layouts as screens migrate.
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
- Modify: `apps/client/lib/pages/kyc_upload_page_submission_section.dart`
- Modify: `apps/client/lib/pages/account_settings_page_kyc_section.dart`
- Modify: `apps/client/lib/widgets/onboarding_auth_widgets.dart`
- Modify: `apps/client/lib/theme/auth_layout.dart`
- Modify: `apps/client/test/auth_ui_phase_a_test.dart`
- Modify: `apps/client/test/k3_auth_responsive_test.dart`
- Modify: `apps/client/test/deposit_history_j1_test.dart`

**Interfaces:**
- Consumes and produces exactly the protected AuthService/deposit-support payloads.

- [ ] Add golden/semantic tests at every viewport and language before editing.
- [ ] Improve spacing, input hierarchy, keyboard behavior, focus/error placement, button states, support explanations, and visual consistency.
- [ ] Replace the KYC post-submit hourglass with the shared “documents received” result scene and Submitted → Manual review → Result timeline; show the real current status, review note when available, safe next action and support entry without inventing an ETA.
- [ ] Keep every current field and reset/deposit support step.
- [ ] Run protected gate, goldens, full Flutter suite, and real Android smoke.
- [ ] Commit: `feat: polish protected authentication and support screens`.

## Task 4A: Consolidate customer chat into SaleSmartly and retire the internal support console

**Files:**
- Modify: `apps/client/lib/pages/support_chat_page.dart`
- Modify: `apps/client/lib/widgets/support_chat_launcher.dart`
- Modify: `apps/client/lib/services/salesmartly_service.dart`
- Modify: `apps/client/lib/services/salesmartly_platform_web.dart`
- Modify: `apps/client/lib/services/salesmartly_platform_native.dart`
- Modify: `apps/client/lib/pages/forgot_password_page.dart`
- Modify: `apps/client/lib/pages/deposit_page.dart`
- Create: `apps/api/src/integrations/salesmartly/salesmartly.module.ts`
- Create: `apps/api/src/integrations/salesmartly/salesmartly.adapter.ts`
- Create: `apps/api/src/integrations/salesmartly/salesmartly-webhook.controller.ts`
- Create: `apps/api/src/integrations/salesmartly/salesmartly-signature.service.ts`
- Create: `apps/api/src/integrations/salesmartly/support-interaction-reference.service.ts`
- Create: `apps/api/src/integrations/salesmartly/salesmartly-integration.spec.ts`
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/<timestamp>_salesmartly_support_reference/migration.sql`
- Modify: `apps/api/src/support/account-recovery.controller.ts`
- Modify: `apps/api/src/support/account-recovery.service.ts`
- Modify: `apps/api/src/deposit/deposit.service.ts`
- Modify: `apps/admin/components/AdminShell.tsx`
- Modify: `apps/admin/app/operator-console/page.tsx`
- Create: `apps/admin/components/AccountRecoveryAction.tsx`
- Delete after migration gate: `apps/admin/app/support-console/page.tsx`
- Delete after migration gate: `apps/admin/components/RecoveryInbox.tsx`
- Retire after history/archive verification: `apps/api/src/support/support.gateway.ts`
- Retire after history/archive verification: `apps/api/src/support/support.controller.ts`
- Retire after history/archive verification: `apps/api/src/support/support.service.ts`
- Modify: `apps/admin/tests/admin-auth-menus.test.mjs`
- Create: `apps/admin/tests/no-internal-support-console.test.mjs`
- Create: `apps/client/test/salesmartly_support_contract_test.dart`
- Modify: `apps/client/test/password_recovery_lifecycle_test.dart`
- Create: `docs/operations/SALESMARTLY_SUPPORT_MIGRATION.md`

**Interfaces:**
- SaleSmartly owns chat, assignment, collaboration, tags and conversation history. HNW owns authentication, recovery-code issuance, manual-deposit records, financial data and audit.
- Customer-visible support, forgot-password and deposit entry steps remain unchanged. A minimal external customer/conversation reference may link systems; no sensitive financial or identity payload is copied into SaleSmartly.
- API/Webhook automation is enabled only when the subscribed SaleSmartly plan and official contract support it; otherwise use the supported SDK/widget and an audited manual handoff.

- [ ] Characterize the current customer support, forgot-password and manual-deposit journeys, plus every internal `/support-console`, WebSocket, SUPPORT-role and database dependency.
- [ ] Add failing tests proving all customer entries open SaleSmartly on Android/iOS/Web, logout clears identity, unavailable states are safe, and no HNW internal chat UI remains after cutover.
- [ ] Define a data minimization map and stable pseudonymous customer/conversation reference; prohibit password, recovery code, TOTP, PAN/Aadhaar evidence, bank details, balance and full order payloads.
- [ ] Verify the actual SaleSmartly subscription, SDK, JSSDK, API, Webhook, privacy and data-location capabilities against official documentation before enabling each integration path.
- [ ] Implement a server-side adapter with secret storage, signature/timestamp verification, replay protection, idempotency, rate limits, timeouts, audit and sanitized observability.
- [ ] Preserve recovery-code issuance and manual-deposit business behavior as HNW-controlled actions; SaleSmartly initiates communication/handoff but never mutates passwords, balances, orders, KYC or permissions directly.
- [ ] Replace the removed Recovery Inbox with a narrowly scoped, audited account-recovery action inside the appropriate existing operations workspace; it accepts only a verified SaleSmartly interaction reference and never renders chat history.
- [ ] Store only the external interaction reference, provider, purpose, actor, timestamps and audit status needed to correlate recovery/deposit work; keep message bodies and customer-service history in SaleSmartly.
- [ ] Archive existing internal conversation history read-only according to retention policy; do not delete records merely because the UI is removed.
- [ ] Shadow-test identity linking, conversation opening, recovery and deposit handoff, vendor outage and duplicate Webhook events; compare against the protected baseline.
- [ ] Remove `/support-console` navigation/page and stop new internal chat writes only after Android/iOS/Web and operational acceptance pass; keep rollback metadata until the observation window ends.
- [ ] Remove obsolete internal chat runtime code and credentials after the retention/rollback gate, while retaining required account-recovery/deposit endpoints and audit history.
- [ ] Document SaleSmartly configuration, agent access, privacy, incident response, vendor outage, export/deletion and exit migration.
- [ ] Run protected-flow, API/Admin/Flutter/Web, security and vendor-failure tests.
- [ ] Commit: `refactor: consolidate customer chat into salesmartly`.

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
- Modify: `apps/client/lib/pages/stock_search_page.dart`
- Modify: `apps/client/lib/pages/index_list_page.dart`
- Modify: `apps/client/lib/pages/index_detail_page.dart`
- Modify: `apps/client/lib/pages/movers_list_page.dart`
- Modify: `apps/client/lib/pages/market_news_page.dart`
- Modify: `apps/client/lib/pages/notifications_page.dart`
- Modify: `apps/client/lib/pages/withdrawal_page.dart`
- Modify: `apps/client/lib/pages/loan_page.dart`
- Modify: `apps/client/lib/pages/account_settings_page.dart`
- Modify: `apps/client/lib/pages/account_security_page.dart`
- Modify: `apps/client/lib/pages/bank_details_page.dart`
- Modify: `apps/client/lib/pages/language_page.dart`
- Modify: `apps/client/lib/pages/appearance_page.dart`
- Modify: `apps/client/lib/pages/legal_page.dart`
- Modify: `apps/client/lib/pages/account_content_page.dart`
- Modify: `apps/client/lib/widgets/record_detail_sheet.dart`
- Modify: `apps/client/lib/widgets/holding_detail_sheet.dart`
- Modify: `apps/client/lib/widgets/markets/news_article_sheet.dart`
- Modify: `apps/client/lib/widgets/trading/standard_order_details_sheet.dart`
- Create: `apps/client/test/secondary_surface_coverage_test.dart`
- Create: `apps/client/test/overlay_consistency_test.dart`
- Modify: `apps/client/lib/services/market_socket_service.dart`
- Create: `apps/client/test/network_failure_matrix_test.dart`
- Create: `apps/client/test/market_socket_recovery_test.dart`

**Interfaces:**
- Produces: shared state preserving last-known data, freshness, request generation, retryability.

- [ ] Test loading, empty, denied, offline, timeout, partial, stale, retry, background/resume, old-request race, socket duplicate/gap/out-of-order.
- [ ] Add freshness/request-generation metadata without converting failure to zero/empty.
- [ ] Normalize card/table/list spacing, typography, skeletons, empty/error/stale banners, and responsive layouts.
- [ ] Migrate order, deposit, withdrawal, IPO, KYC, support, security and portfolio state displays to the shared status system; distinguish business-pending, network-loading, unknown-result and terminal-failure semantics.
- [ ] Upgrade every registered secondary page, detail surface, drawer, sheet, dialog and result view to the shared scaffold, spacing, typography, status, motion and action hierarchy; no main-page-only acceptance.
- [ ] Verify navigation/back restoration, SafeArea, scrolling, keyboard avoidance, long localized text, destructive confirmations and input preservation on every registered secondary surface.
- [ ] Ensure every price and P&L displays source time/quality and INR formatting.
- [ ] Verify goldens, all Flutter tests, protected contracts, and low-end Android performance.
- [ ] Commit: `feat: unify resilient customer journeys`.

## Task 6A: Deliver the responsive Web and installable PWA client

**Files:**
- Modify: `apps/client/web/index.html`
- Modify: `apps/client/web/manifest.json`
- Replace: `apps/client/web/icons/Icon-192.png`
- Replace: `apps/client/web/icons/Icon-512.png`
- Replace: `apps/client/web/icons/Icon-maskable-192.png`
- Replace: `apps/client/web/icons/Icon-maskable-512.png`
- Create: `apps/client/web/flutter_bootstrap.js`
- Create: `apps/client/web/pwa_service_worker.js`
- Modify: `apps/client/lib/main.dart`
- Create: `apps/client/lib/widgets/web_responsive_shell.dart`
- Create: `apps/client/lib/services/web_update_service.dart`
- Create: `apps/client/lib/services/web_session_coordinator.dart`
- Create: `apps/client/test/web_manifest_contract_test.dart`
- Create: `apps/client/test/web_responsive_layout_test.dart`
- Create: `apps/client/test/web_offline_policy_test.dart`
- Create: `apps/client/integration_test/web_critical_flows_test.dart`
- Create: `docker/client-web.Dockerfile`
- Create: `docker/client-web.nginx.conf`
- Modify: `compose.production.yaml`
- Modify: `.env.production.example`
- Create: `.github/workflows/web-pwa-ci.yml`
- Create: `tests/web-pwa/package.json`
- Create: `tests/web-pwa/playwright.config.ts`
- Create: `tests/web-pwa/pwa.spec.ts`
- Create: `tests/web-pwa/security-and-cache.spec.ts`
- Create: `tests/web-pwa/lighthouse.config.cjs`
- Create: `docs/client/WEB_PWA_OPERATIONS.md`

**Interfaces:**
- Reuses the protected Flutter services, API DTOs, registration/login/recovery/deposit/trading contracts, and `clientOrderId`; no second business implementation.
- Production uses same-origin `/api` and `/ws` routing where possible. Service Worker precaches only the versioned App Shell/static allowlist and explicitly bypasses every API, WebSocket, auth, KYC, support, account, fund, order, and trade path.
- Offline mode never queues or replays a write. Unknown order results are resolved online through the existing idempotent lookup path.

- [ ] Add failing browser contract tests for manifest/installability, deep-link refresh, history, session expiry, logout across tabs, offline startup, stale shell, update available, write blocking, and unknown order result recovery.
- [ ] Replace Flutter template metadata, colors, descriptions, favicon and icons with approved customer branding; keep repository, stack, endpoint, environment and internal-version details out of the UI and manifest.
- [ ] Add responsive phone/tablet/desktop composition, keyboard navigation, visible focus, pointer/hover behavior, bounded desktop widths, wide data layouts, and safe-area handling without hiding or changing protected trade fields.
- [ ] Add a custom, versioned PWA bootstrap/update path. Cache only immutable/versioned static assets and the minimum shell; use network-only/no-store for sensitive and financial traffic and purge incompatible caches safely.
- [ ] Show explicit offline/stale/update states. Defer activation while an order form or write is in progress; never auto-refresh a financial workflow.
- [ ] Coordinate multi-tab sign-out/session expiry and prevent passwords, PINs, tokens, PII or financial responses from entering Cache Storage, logs, analytics payloads or public source maps.
- [ ] Serve the release build through a non-root, read-only container with SPA fallback, correct asset 404 behavior, compression, HTTPS-forwarding awareness, CSP, HSTS, frame-ancestors, Referrer-Policy and Permissions-Policy.
- [ ] Add Web CI for `flutter build web --release`, Chrome tests, Playwright critical journeys, manifest/service-worker/cache assertions, Lighthouse performance/PWA/accessibility budgets, and a secret/private-host/source-map artifact scan.
- [ ] Validate install/update/uninstall, online/offline/slow network, hard refresh and rollback on Chrome, Edge, Safari and Firefox at the full customer Web viewport matrix.
- [ ] Capture pixel-level Web/PWA screenshots in English/Hindi, text scale 1.0/1.4, reduced motion and existing themes; review alongside Android to prevent cross-platform drift.
- [ ] Run the same Web/PWA screenshot and interaction matrix for every registered secondary route and overlay, not only landing tabs.
- [ ] Document domains, same-origin proxy, cache headers, release retention, service-worker recovery, monitoring, rollback, and customer-support troubleshooting.
- [ ] Run protected-flow, Flutter, Web build, browser E2E, security-header, accessibility and container checks.
- [ ] Commit: `feat: deliver production web and pwa client`.

## Task 7: Pixel-polish and harden all five Admin roles

**Files:**
- Modify: `apps/admin/components/AdminShell.tsx`
- Modify: `apps/admin/components/OpsPageHeader.tsx`
- Modify: `apps/admin/components/OpsToolbar.tsx`
- Modify: `apps/admin/components/OpsModal.tsx`
- Modify: `apps/admin/components/OpsErrorState.tsx`
- Create: `apps/admin/components/OpsStatusScene.tsx`
- Create: `apps/admin/components/OpsStatusTimeline.tsx`
- Modify: `apps/admin/components/OpsOrderWorkspace.tsx`
- Modify: `apps/admin/components/OpsTradeWorkspace.tsx`
- Create: `apps/admin/components/OpsDataPage.tsx`
- Create: `apps/admin/lib/ops-page-registry.ts`
- Create: `apps/admin/lib/ops-mutation-contract.ts`
- Create: `apps/admin/lib/ops-action-registry.ts`
- Modify: `apps/admin/lib/admin-navigation.ts`
- Modify: `apps/admin/lib/role-permissions.ts`
- Modify: `apps/admin/components/KycReviewModal.tsx`
- Modify: `apps/admin/lib/kyc-review.ts`
- Modify: `apps/admin/app/deposits/page.tsx`
- Modify: `apps/admin/app/orders/page.tsx`
- Modify: `apps/admin/app/trades/page.tsx`
- Modify: `apps/admin/app/audit-logs/page.tsx`
- Create: `apps/admin/app/system-health/page.tsx`
- Create: `apps/admin/app/system-governance/page.tsx`
- Create: `apps/admin/app/system-deployments/page.tsx`
- Modify: `apps/admin/app/globals.css`
- Modify: `apps/admin/tests/role-permissions.test.mjs`
- Modify: `apps/admin/tests/g4-orders-trades.test.mjs`
- Create: `apps/admin/tests/ops-failure-states.test.mjs`
- Create: `apps/admin/tests/ops-status-scenes.test.mjs`
- Create: `apps/admin/tests/ops-page-registry.test.mjs`
- Create: `apps/admin/tests/ops-action-matrix.test.mjs`
- Create: `apps/admin/tests/ops-maintainability.test.mjs`
- Modify: `apps/admin/tests/kyc-review.test.mjs`
- Modify: `apps/admin/tests/g3-kyc-workspace.test.mjs`
- Modify: `apps/api/src/kyc/kyc.characterization.spec.ts`
- Create: `docs/admin/ADMIN_MODULE_MAINTENANCE.md`
- Create: `docs/admin/ADMIN_OPERATION_MATRIX.md`

**Interfaces:**
- Existing Admin routes and permission matrix; no new role capability.

- [ ] Pin role menus/endpoints and add 403/409/429/timeout/partial/stale/unknown-result tests.
- [ ] Centralize every route, title, breadcrumb, menu item, required role, module owner, and API dependency in one typed registry.
- [ ] Define a typed role × module × record-state × action registry covering view/list/filter/detail/create/edit/approve/reject/publish/reset/export/read-only boundaries; generate UI availability from it without replacing server authorization.
- [ ] Introduce one reusable server-paginated data-page contract and one audited mutation contract; remove duplicated page-local implementations as each page migrates.
- [ ] Standardize grid, page width, sidebar, headers, filters, tables, drawers, confirmations, status tags, density, and responsive breakpoints.
- [ ] Replace inconsistent Admin spinners, empty placeholders, success messages and pending/review displays with shared role-aware status scenes and timelines; preserve exact server state and never imply completion before the API confirms it.
- [ ] Require current/new value, impact, reason, requestId, and explicit confirmation for writes.
- [ ] Pin KYC review completeness: pending rows expose both approve and reject, rejection requires a meaningful note, both decisions show a confirmation summary, completed rows are view-only, and 403/409/timeout/unknown-result paths refresh safely without optimistic success.
- [ ] Audit customer/KYC, funding, orders/trades, products/content, support, personnel/2FA, governance and system modules against the operation matrix; add every missing in-scope action and state without expanding protected business behavior or role scope.
- [ ] Add governance, health, and read-only deployment views for audit, reconciliation, API/DB/Redis/market/worker health, current SHA/image/migration, recent release results, rollback readiness, and configuration provenance; never display secret values or expose a server shell.
- [ ] Add maintainability tests that fail on unregistered routes, duplicated permission logic, direct raw fetch in migrated pages, unbounded lists, or missing loading/error/denied states.
- [ ] Document each module's responsibility, API, permission boundary, data source, alert, common failure, and rollback.
- [ ] Document each module's complete operation inventory, eligible states, required reason/confirmation, idempotency key, audit event and recovery behavior; fail CI when a registered mutation lacks these controls.
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
- Modify: `docker/client-web.nginx.conf`
- Modify: `compose.local-test.yaml`
- Modify: `compose.production.yaml`
- Modify: `scripts/verify-release-config.ps1`
- Create: `scripts/verify-release-config.sh`
- Create: `scripts/ops/hnw-ops.ps1`
- Create: `scripts/ops/hnw-ops.sh`
- Create: `scripts/ops/lib/preflight.ps1`
- Create: `scripts/ops/lib/preflight.sh`
- Modify: `.github/workflows/docker-ci.yml`
- Modify: `.github/workflows/production-deploy.yml`
- Create: `.github/workflows/production-rollback.yml`
- Create: `docs/operations/DEPLOYMENT_AND_SERVER_MANAGEMENT.md`
- Create: `docs/operations/ENVIRONMENT_INVENTORY.template.md`
- Create: `docs/operations/RELEASE_EVIDENCE.template.md`

**Interfaces:**
- `RedisLease.acquire(resource, ttlMs, owner)`; release verifies owner token.
- Gateway forwards bounded trusted headers/WSS; API remains authorization boundary.
- `hnw-ops preflight|status|logs|backup-check|deploy|rollback --environment <name>` provides one audited operator interface; production mutations require CI environment approval and cannot be run from the Admin browser.

- [ ] Test disconnect/reconnect/failover/stale owner/two-instance shared limits.
- [ ] Add deadlines, jittered reconnect, and no infinite command queue.
- [ ] Apply the exact design `17 fail-closed list; read-only paths degrade honestly.
- [ ] Add opt-in Envoy profile, body/time/connection limits, WSS, trusted proxy validation, customer Web/PWA same-origin routing, and cache/header rules.
- [ ] Build idempotent Windows/Linux operator commands for preflight, status, correlated logs, backup verification, deploy, and rollback; default to read-only and reject missing/unknown environments.
- [ ] Validate required configuration, secret references, certificates, time sync, disk headroom, image digest, backup freshness, migration compatibility, and dependency health before deployment.
- [ ] Require exact SHA/image digest, protected gate, approved environment, deployment concurrency lock, expand/migrate/contract compatibility, smoke tests, release evidence, and rollback metadata.
- [ ] Make deployment and rollback workflows resumable, auditable, least-privileged, and safe against duplicate triggers; never print secrets or undo committed financial records.
- [ ] Publish sanitized deployment status for the Admin read-only view and alerts, with no credentials, host shell, or destructive controls.
- [ ] Document server inventory, routine maintenance, scaling, certificate renewal, backup/restore drill, incident access, and operator handover so deployment does not depend on one maintainer.
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

- [ ] Integrate in order 1 → 2 → 3 → 4 → 4A → 5/6 → 6A → 7 → 8 → 9 → 10 → 11 → 12 → 13.
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
flutter build web --release --dart-define=API_BASE_URL=/api
cd ..\..\tests\web-pwa
npm ci
npx playwright test
npm run lighthouse
```

Expected: exit code 0 for each affected application. PostgreSQL/Redis integration, migration, load, chaos, Docker, visual capture, and release checks additionally require their explicitly disposable environments; no test may point at production.
