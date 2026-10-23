# HNW Client Home UI Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` according to the approved execution mode. Follow the task order and use checkbox tracking.

**Goal:** Upgrade the Flutter Home surface with a clearer action hierarchy, shared semantic components, and stronger responsive/accessibility guarantees without changing any service call, route, account calculation, or funding behavior.

**Architecture:** Keep `HomeDashboard` as the public stateful widget and keep its existing callback contract. Extract presentation-only section and action components into `widgets/home`, using the existing `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, and motion tokens. Tests remain widget-level and exercise real rendered behavior at narrow widths, large text scales, hidden balances, and failed data states.

**Tech Stack:** Dart, Flutter Material, existing HNW design-system widgets, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-10-22-hnw-ui-ux-foundation-design.md`

## Global Constraints

- Do not modify trading payloads, order callbacks, account calculations, authentication, KYC, deposit, withdrawal, or API service methods.
- Preserve the existing `HomeDashboard` constructor fields and callback meanings; adding a presentation callback is allowed only when it delegates to an existing navigation callback.
- Use semantic design tokens; do not add raw brand colors or arbitrary spacing values.
- Keep the layout usable at 320 logical pixels, landscape, keyboard-visible layouts, and 1.4x or larger text scaling.
- Amounts must continue to use the existing number formatters and hidden balances must never reveal authoritative values.
- New user-facing copy must pass through `tr()`/`AppText` or an existing CMS/localization path.

## Review Focus

- Hidden balances: tapping the visibility control must change only presentation and never expose the supplied amount; owned by Task 1 tests.
- Zero values: zero assets and zero P&L must remain visible as zero rather than becoming an empty state; owned by Task 1 tests.
- Narrow/high-scale layouts: actions, indices, news, and the bottom navigation must not overflow at 320px and large text; owned by Tasks 1 and 3.
- Failed or stale data: account/quote/news failures must remain distinguishable from valid zero/empty data; owned by Task 3 tests.
- Reduced motion: the full dashboard must remain visible when animations are disabled; owned by Task 3 tests.

---

### Task 1: Lock the Home action and sensitive-state contract with failing widget tests

**Files:**
- Modify: `apps/client/test/home_dashboard_phase_c1_test.dart`
- Create: `apps/client/test/home_dashboard_ui_upgrade_test.dart`
- Read-only reference: `apps/client/lib/widgets/home/home_dashboard.dart`

**Interfaces:**
- Consumes: the existing `HomeDashboard` constructor and callbacks `onDeposit`, `onWithdraw`, `onTrade`, `onToggleHideBalances`, `onRetryAccount`, `onRetryNews`, and `onRetryQuotes`.
- Produces: named widget behaviors that later tasks must preserve: three quick actions, no amount leakage, explicit unavailable states, and no overflow at target breakpoints.

- [ ] **Step 1: Add the failing action test.**

  Add `testWidgets('Home exposes deposit, withdrawal, and trade actions through existing callbacks', ...)` to the new test file. Pump a real `HomeDashboard` fixture, tap the three action labels, and assert each existing callback increments exactly once. Assert that no new service or HTTP mock is needed.

- [ ] **Step 2: Add the failing responsive/state tests.**

  Add tests named `home actions stack without overflow at 320 logical pixels`, `home action labels remain accessible at 1.5 text scale`, and `Home preserves hidden and zero financial states`. Assert `tester.takeException()` is null, hidden values are absent, zero values are present, and the semantic labels remain discoverable.

- [ ] **Step 3: Run the focused tests and verify the expected red state.**

  Run from `apps/client`:

  ```text
  flutter test test/home_dashboard_ui_upgrade_test.dart test/home_dashboard_phase_c1_test.dart
  ```

  Expected: FAIL because the current Home action row renders only the existing two action buttons and the new semantic assertions are not yet implemented. If the tests fail for a fixture or import error, fix the test before touching production code.

- [ ] **Step 4: Commit the red tests.**

  ```text
  git add apps/client/test/home_dashboard_ui_upgrade_test.dart apps/client/test/home_dashboard_phase_c1_test.dart
  git commit -m "test(client): define Home action and state contract"
  ```

### Task 2: Extract and implement the tokenized Home quick-action row

**Files:**
- Create: `apps/client/lib/widgets/home/home_quick_actions.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard_overview.dart`
- Test: `apps/client/test/home_dashboard_ui_upgrade_test.dart`

**Interfaces:**
- Consumes: `VoidCallback onDeposit`, `VoidCallback onWithdraw`, and `VoidCallback onTrade`.
- Produces: `HomeQuickActions({required onDeposit, required onWithdraw, required onTrade})`, a presentation-only widget that renders three `HomeActionButton` instances and invokes only the supplied callbacks.

- [ ] **Step 1: Implement `HomeQuickActions` minimally.**

  Add the component with the exact callback interface above. Use `tr()`/`AppText` for labels and existing semantic colors (`brandPrimary`, `gain`, and `info`/`buy` as appropriate). Do not add a service dependency, route lookup, or API call. Preserve the existing two action labels and add the Trade action as a navigation affordance to `onTrade`.

- [ ] **Step 2: Replace the private action implementation.**

  Remove the duplicated private `_HomeQuickActions` implementation from `home_dashboard_overview.dart`, import the new component in `home_dashboard.dart`, and pass `widget.onDeposit`, `widget.onWithdraw`, and `widget.onTrade`. Keep the existing `LayoutBuilder`/text-scale behavior, adapting it so three cards form a stable two-column grid on normal phone widths and a single column when the measured width cannot support two cards.

- [ ] **Step 3: Run the focused tests and verify green.**

  ```text
  flutter test test/home_dashboard_ui_upgrade_test.dart test/home_dashboard_phase_c1_test.dart
  ```

  Expected: PASS, including callback counts, no overflow, hidden-balance protection, and zero-value rendering.

- [ ] **Step 4: Commit the component extraction.**

  ```text
  git add apps/client/lib/widgets/home/home_quick_actions.dart apps/client/lib/widgets/home/home_dashboard.dart apps/client/lib/widgets/home/home_dashboard_overview.dart apps/client/test/home_dashboard_ui_upgrade_test.dart
  git commit -m "feat(client): refine Home quick actions"
  ```

### Task 3: Unify Home section headers and explicit data-state semantics

**Files:**
- Create: `apps/client/lib/widgets/home/home_section_header.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard_overview.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard_content.dart`
- Modify: `apps/client/lib/widgets/home/home_dashboard_movers.dart`
- Test: `apps/client/test/home_dashboard_ui_upgrade_test.dart`

**Interfaces:**
- Consumes: `String title`, optional `VoidCallback onViewAll`, existing market/news/account state values, and existing retry callbacks.
- Produces: `HomeSectionHeader({required title, onViewAll})` with a minimum 44dp action target and a consistent `Semantics` label; no data-loading behavior.

- [ ] **Step 1: Add failing section/state assertions.**

  Add tests named `section headers expose view-all semantics only when actionable`, `quote and news failure states expose retry actions`, and `reduced motion renders the complete Home hierarchy`. Assert the existing section order remains Account → Indices → Movers → News → Company → Trade, while unavailable data displays explicit copy and retry controls.

- [ ] **Step 2: Implement `HomeSectionHeader` and replace the private header.**

  Move the current `_SectionTitle` presentation into the new component, retain the current `View All` callback behavior, and route visible strings through `tr()`/`AppText`. Remove the private duplicate only after all call sites use the new component.

- [ ] **Step 3: Normalize state chrome without touching data sources.**

  Keep `homeQuoteFreshnessLabel`, `AccountDataStatus`, `_IndicesGrid`, `_NewsSection`, and mover filtering unchanged semantically. Update only their shared card/header/action styling and semantics to use the existing tokens. Do not convert a failed request into an empty list or zero amount.

- [ ] **Step 4: Run focused tests and the existing Home/Markets tests.**

  ```text
  flutter test test/home_dashboard_ui_upgrade_test.dart test/home_dashboard_phase_c1_test.dart test/markets_phase_c3_test.dart
  ```

  Expected: PASS with no overflow exceptions and no changed callback or data assertions.

- [ ] **Step 5: Commit the semantic presentation layer.**

  ```text
  git add apps/client/lib/widgets/home apps/client/test/home_dashboard_ui_upgrade_test.dart
  git commit -m "refactor(client): standardize Home section chrome"
  ```

### Task 4: Run the client verification gate

**Files:**
- Modify: only files already listed above if formatting requires it.
- Test: all existing Flutter tests.

- [ ] **Step 1: Format and analyze.**

  ```text
  dart format --set-exit-if-changed lib test
  flutter analyze
  ```

- [ ] **Step 2: Run the complete Flutter test suite.**

  ```text
  flutter test
  ```

  Expected: all tests pass; any pre-existing environment-only limitation must be recorded rather than hidden.

- [ ] **Step 3: Run the local web build validation.**

  ```text
  flutter build web --dart-define=API_BASE_URL=http://localhost:3000
  ```

- [ ] **Step 4: Review the diff for business-surface changes and commit verification notes.**

  Confirm no files under `apps/client/lib/services`, `trading`, `auth`, `deposit`, or `withdrawal` were changed by this plan. Commit only if the verification output is clean.
