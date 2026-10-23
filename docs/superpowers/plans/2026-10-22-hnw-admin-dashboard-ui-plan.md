# HNW Admin Dashboard UI Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` according to the approved execution mode. Follow the task order and use checkbox tracking.

**Goal:** Make the Admin Dashboard visually consistent, role-aware, responsive, and explicit about unknown data while preserving every existing role permission, route, endpoint, funding instruction, and operational action.

**Architecture:** Extract the two duplicated dashboard presentation primitives into typed shared components. Move tone and spacing decisions into `globals.css` variables/classes, keep role and business branching in the page, and add pure formatting helpers that distinguish `0` from an unavailable value. The current endpoint calls and role allowlists remain unchanged in this plan.

**Tech Stack:** Next.js 16.4.2 App Router, React 19, TypeScript, Ant Design 6, CSS variables, Node test runner.

**Spec:** `docs/superpowers/specs/2026-10-22-hnw-ui-ux-foundation-design.md`

## Global Constraints

- Read the relevant guides in `apps/admin/node_modules/next/dist/docs/` before writing Next.js code.
- Do not change `AdminShell` role menus, deployment-role isolation, API permissions, or write-action routes.
- Keep `/business/my-dashboard`, `/business/my-risk-dashboard`, `/admin/login-risk-summary`, `/deposits`, `/withdrawals`, and all existing product links unchanged.
- Do not turn an absent/invalid value into numeric zero; valid zero must remain visible as zero.
- Do not log phone numbers, account numbers, tokens, stack traces, bank details, or other PII.
- Preserve reduced-motion, keyboard focus, `aria-label`, 390px, 767px, and table overflow behavior already covered by the design-system tests.

## Review Focus

- Role isolation: visual extraction must not move or broaden menu/API permissions; owned by Task 1 and existing `admin-auth-menus`/`role-permissions` tests.
- Unknown versus zero metrics: `undefined`, `null`, and malformed numeric values render `—`, while numeric zero renders `0`; owned by Task 1 tests.
- Funding copy and links: deposit, credit, withdrawal, and finance actions remain the same; owned by Task 1 tests.
- Narrow layouts: metric/action grids and page headers must wrap without clipped text or inaccessible controls; owned by Task 3 CSS/source tests.
- Reduced motion and focus: new classes must not remove existing focus outlines or motion suppression; owned by Task 3 tests.

---

### Task 1: Define shared dashboard component and value-format contracts with failing tests

**Files:**
- Create: `apps/admin/tests/dashboard-ui.test.mjs`
- Read-only reference: `apps/admin/app/dashboard/page.tsx`
- Read-only reference: `apps/admin/tests/j5-design-system.test.mjs`

**Interfaces:**
- Consumes: existing dashboard source, role-specific route strings, and `formatInr` behavior.
- Produces: test-pinned contracts for `OpsMetricCard`, `OpsQuickAction`, `formatOpsCount`, tone classes, role links, and responsive CSS.

- [ ] **Step 1: Write the failing source/behavior tests.**

  Add tests named `dashboard uses shared metric and quick-action components`, `formatOpsCount distinguishes unknown from zero`, `dashboard keeps role workflow links and funding copy`, and `dashboard css keeps responsive and reduced-motion hooks`. Import `formatOpsCount` from `../lib/ops-dashboard.ts` so the test fails until the helper exists. Assert that the dashboard source no longer defines local `MetricCard`/`QuickAction`, still contains the existing endpoint paths and finance copy, and uses the shared component names.

- [ ] **Step 2: Run the focused test and verify the expected red state.**

  Run from `apps/admin`:

  ```text
  node --experimental-strip-types --test tests/dashboard-ui.test.mjs
  ```

  Expected: FAIL because the shared files and helper do not exist yet. Fix only test/import mistakes before writing production code.

- [ ] **Step 3: Commit the red tests.**

  ```text
  git add apps/admin/tests/dashboard-ui.test.mjs
  git commit -m "test(admin): define dashboard presentation contracts"
  ```

### Task 2: Add typed shared dashboard primitives and semantic value formatting

**Files:**
- Create: `apps/admin/components/OpsMetricCard.tsx`
- Create: `apps/admin/components/OpsQuickAction.tsx`
- Create: `apps/admin/lib/ops-dashboard.ts`
- Test: `apps/admin/tests/dashboard-ui.test.mjs`

**Interfaces:**
- Produces `OpsDashboardTone = "brand" | "success" | "info" | "warning" | "danger" | "violet"`.
- Produces `formatOpsCount(value?: number | null, empty?: string): string`, returning `empty` for `null`, `undefined`, or non-finite values and a localized integer string for valid numbers, including `0`.
- Produces `OpsMetricCard({ title, value, icon, tone, suffix? })` with `value: string | number` and `tone: OpsDashboardTone`.
- Produces `OpsQuickAction({ title, description, icon, tone, href })` with the same finite tone union and an unchanged Next `Link` destination.

- [ ] **Step 1: Implement `formatOpsCount` with no UI dependency.**

  Add the helper to `apps/admin/lib/ops-dashboard.ts`. Use `—` as the default empty value, reject `NaN`/infinite values, and preserve `0`. Keep INR formatting in the existing `formatInr` helper rather than duplicating currency logic.

- [ ] **Step 2: Implement `OpsMetricCard`.**

  Move the existing card structure from the page into the shared component. Replace inline tone background/color style objects with `className="ops-metric-icon"` and a finite `data-tone`/tone class. Preserve the Ant Design `Statistic` value and suffix semantics, keyboard behavior, and icon accessibility.

- [ ] **Step 3: Implement `OpsQuickAction`.**

  Move the existing `Link`/`Card` structure into the shared component. Preserve `hoverable`, the current description, the arrow affordance, and the exact `href` received from the page. Use the same finite tone contract as `OpsMetricCard`.

- [ ] **Step 4: Run the focused tests.**

  ```text
  node --experimental-strip-types --test tests/dashboard-ui.test.mjs
  ```

  Expected: the helper/component contract tests pass; dashboard source assertions that expect the page migration may still fail until Task 3.

- [ ] **Step 5: Commit the shared primitives.**

  ```text
  git add apps/admin/components/OpsMetricCard.tsx apps/admin/components/OpsQuickAction.tsx apps/admin/lib/ops-dashboard.ts apps/admin/tests/dashboard-ui.test.mjs
  git commit -m "feat(admin): add shared dashboard presentation primitives"
  ```

### Task 3: Migrate the Dashboard page and CSS without changing workflows

**Files:**
- Modify: `apps/admin/app/dashboard/page.tsx`
- Modify: `apps/admin/app/globals.css`
- Modify: `apps/admin/tests/dashboard-ui.test.mjs`
- Preserve unchanged: `apps/admin/components/AdminShell.tsx`, `apps/admin/lib/admin-navigation.ts`, role permission files

**Interfaces:**
- Consumes: `OpsMetricCard`, `OpsQuickAction`, `formatOpsCount`, and `formatInr`.
- Produces: the same role branches, endpoint requests, metric meanings, finance wording, and links with tokenized presentation.

- [ ] **Step 1: Migrate the page to shared components.**

  Remove the local `MetricCard` and `QuickAction` functions. Import the shared components and replace each call site. Keep the existing role conditions (`BUSINESS`, `SUPPORT`, `FINANCE`) and every route string exactly unchanged.

- [ ] **Step 2: Preserve unknown values explicitly.**

  Change count displays to use `formatOpsCount` and pass nullable monetary values directly through `formatInr`/`formatMoney` instead of `Number(value ?? 0)`. Ensure a valid API value of `0` still renders `0`, while a missing field renders `—`. Do not alter API response types or add a fallback that masks a failed request.

- [ ] **Step 3: Add CSS dashboard tokens and layout classes.**

  Add a small `--ops-tone-*` palette and shared `.ops-metric-icon`, `.ops-quick-icon`, `.ops-dashboard-grid`, and `.ops-dashboard-section` rules to `globals.css`. Keep existing role accent variables, focus outlines, and reduced-motion selectors. Replace dashboard-specific inline color/radius styles with classes or Ant Design token-compatible values; do not restyle unrelated operational pages in this task.

- [ ] **Step 4: Add responsive and accessibility assertions.**

  Extend `dashboard-ui.test.mjs` to assert that the page contains `aria-label="刷新工作台"`, shared component imports, all existing funding/product `href` values, and no dashboard-local hex tone values. Assert CSS contains the responsive grid rules and that the reduced-motion block still covers the dashboard cards.

- [ ] **Step 5: Run focused and full Admin tests.**

  ```text
  node --experimental-strip-types --test tests/dashboard-ui.test.mjs
  npm test
  ```

  Expected: PASS with no role/menu or governance regressions.

- [ ] **Step 6: Commit the Dashboard migration.**

  ```text
  git add apps/admin/app/dashboard/page.tsx apps/admin/app/globals.css apps/admin/tests/dashboard-ui.test.mjs
  git commit -m "refactor(admin): tokenise dashboard visual hierarchy"
  ```

### Task 4: Run the Admin verification gate

**Files:**
- Modify: only files already listed above if formatting requires it.
- Test: Admin test suite, lint, TypeScript check, and production build.

- [ ] **Step 1: Read the local Next.js guidance before final code review.**

  Re-read the relevant files under `apps/admin/node_modules/next/dist/docs/`, especially App Router structure, CSS, client components, and version-16 upgrade notes. Confirm no deprecated API was introduced.

- [ ] **Step 2: Run tests and lint.**

  ```text
  npm test
  npm run lint
  npx tsc --noEmit
  ```

- [ ] **Step 3: Build the production Admin bundle.**

  ```text
  npm run build
  ```

- [ ] **Step 4: Review the diff for permission and financial-surface changes.**

  Confirm no auth guard, role allowlist, API write path, deposit instruction, withdrawal action, or trading route changed. Record all commands and exit codes before handing off the branch.
